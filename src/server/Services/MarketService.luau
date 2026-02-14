--[[
	MarketService.luau — Server-authoritative market simulation.
	Owns all coin price state. Runs a tick loop updating prices via
	stochastic random walk with drift, volatility, and event modifiers.
	Broadcasts compressed snapshots to all clients at a controlled rate.

	CoinState includes: price, changePct, volume, meta, phase (per §1.1, §4 Step 1).
	OHLC candle aggregation per coin per timeframe (M2).
	Dynamic coin registration via RegisterCoin() for LaunchpadService (M3).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local CoinsModule = require(ReplicatedStorage.Shared.Coins)

local MarketService = {}

-- Types (§1.1 CoinState — fields relevant to M1+)
export type CoinState = {
	-- Identity
	id: string,
	symbol: string,
	name: string,
	icon: string,
	meta: string,
	phase: string,
	-- Market
	price: number,
	lastPrice: number,
	changePct: number,
	volume: number,
	high: number,
	low: number,
	-- Memecoin realism (seeded, active in later milestones)
	liquidity: number,
	volatility: number,
	drift: number,
	devTrust: number,
	communityStrength: number,
	whaleConcentration: number,
	devControl: number,
	hype: number,
	-- Lifecycle
	isTradable: boolean,
	isRuggable: boolean,
	eventModifiers: {},
	-- Legacy (ring buffer for line charts)
	priceHistory: {number},
	historyIndex: number,
}

export type Candle = {
	tOpen: number,
	open: number,
	high: number,
	low: number,
	close: number,
	volume: number,
}

-- Internal state
local coinStates: {[string]: CoinState} = {}
local rng = Random.new(os.time())
local activeModifiers: {[string]: {drift: number, volMult: number, expiry: number}} = {}

-- M3: allDefs contains both static (CoinsModule.List) and dynamic (launched) coin defs.
-- All iteration loops use allDefs instead of CoinsModule.List.
local allDefs: {any} = {}

-- Remote references (set during Init)
local marketSnapshotRemote: RemoteEvent = nil
local coinHistoryRemote: RemoteEvent = nil
local candleHistoryRemote: RemoteEvent = nil
local candleUpdateRemote: RemoteEvent = nil
local candleAppendRemote: RemoteEvent = nil
local requestCandlesRemote: RemoteEvent = nil
local requestMarketSnapshotRemote: RemoteEvent = nil

-- Timers
local simAccumulator = 0
local broadcastAccumulator = 0
local candleUpdateAccumulator = 0

-------------------------------------------------
-- OHLC Candle aggregation state
-------------------------------------------------
local candlesHistory: {[string]: {[string]: { candles: {Candle}, head: number, count: number }}} = {}
local currentCandle: {[string]: {[string]: Candle}} = {}

local TIMEFRAMES = Config.TIMEFRAMES
local MAX_CANDLE_HISTORY = Config.MAX_CANDLE_HISTORY

local function serverTime(): number
	return workspace:GetServerTimeNow()
end

local function candleStartTime(now: number, tfSeconds: number): number
	return math.floor(now / tfSeconds) * tfSeconds
end

local function initCandleBuffers()
	for _, def in CoinsModule.List do
		candlesHistory[def.id] = {}
		currentCandle[def.id] = {}
		for tfKey, _ in TIMEFRAMES do
			candlesHistory[def.id][tfKey] = {
				candles = table.create(MAX_CANDLE_HISTORY),
				head = 1,
				count = 0,
			}
			currentCandle[def.id][tfKey] = nil
		end
	end
end

local function pushCandleToHistory(coinId: string, tfKey: string, candle: Candle)
	local buf = candlesHistory[coinId][tfKey]
	if not buf then return end
	buf.candles[buf.head] = candle
	buf.head = (buf.head % MAX_CANDLE_HISTORY) + 1
	buf.count = math.min(buf.count + 1, MAX_CANDLE_HISTORY)
end

local function getOrderedCandles(coinId: string, tfKey: string, limit: number): {Candle}
	local buf = candlesHistory[coinId][tfKey]
	if not buf or buf.count == 0 then return {} end
	local count = math.min(buf.count, limit)
	local result = table.create(count)
	local startIdx = ((buf.head - count - 1) % MAX_CANDLE_HISTORY) + 1
	for i = 1, count do
		local idx = ((startIdx + i - 2) % MAX_CANDLE_HISTORY) + 1
		table.insert(result, buf.candles[idx])
	end
	return result
end

local function updateCandles(coinId: string, price: number, tickVolume: number)
	local now = serverTime()
	for tfKey, tfSeconds in TIMEFRAMES do
		local cStart = candleStartTime(now, tfSeconds)
		local cur = currentCandle[coinId][tfKey]
		if cur == nil or cur.tOpen ~= cStart then
			if cur then
				pushCandleToHistory(coinId, tfKey, cur)
				if candleAppendRemote then
					candleAppendRemote:FireAllClients(coinId, tfKey, cur)
				end
			end
			currentCandle[coinId][tfKey] = {
				tOpen = cStart,
				open = price,
				high = price,
				low = price,
				close = price,
				volume = tickVolume,
			}
		else
			cur.high = math.max(cur.high, price)
			cur.low = math.min(cur.low, price)
			cur.close = price
			cur.volume = cur.volume + tickVolume
		end
	end
end

-------------------------------------------------
-- Initialize coin states from definitions (§1.1 CoinState)
-------------------------------------------------
function MarketService.Init(remotes: {[string]: any})
	marketSnapshotRemote = remotes.MarketSnapshot
	coinHistoryRemote = remotes.CoinHistory
	candleHistoryRemote = remotes.CandleHistory
	candleUpdateRemote = remotes.CandleUpdate
	candleAppendRemote = remotes.CandleAppend
	requestCandlesRemote = remotes.RequestCandles
	requestMarketSnapshotRemote = remotes.RequestMarketSnapshot

	-- Populate allDefs from static coin definitions
	for _, def in CoinsModule.List do
		table.insert(allDefs, def)
	end

	for _, def in CoinsModule.List do
		local history = table.create(Config.MAX_HISTORY_POINTS, def.basePrice)
		coinStates[def.id] = {
			-- Identity
			id = def.id,
			symbol = def.ticker,
			name = def.name,
			icon = def.icon,
			meta = def.meta,
			phase = def.initialPhase or "HYPE",
			-- Market
			price = def.basePrice,
			lastPrice = def.basePrice,
			changePct = 0,
			volume = 0,
			high = def.basePrice,
			low = def.basePrice,
			-- Memecoin realism (seeded defaults, used in later milestones)
			liquidity = def.liquidity,
			volatility = def.volatility,
			drift = def.trendBias,
			devTrust = 60,
			communityStrength = 50,
			whaleConcentration = 30,
			devControl = 40,
			hype = 50,
			-- Lifecycle
			isTradable = true,
			isRuggable = false,
			eventModifiers = {},
			-- Legacy ring buffer
			priceHistory = history,
			historyIndex = 1,
		}
	end

	initCandleBuffers()

	-- Legacy line chart history request
	coinHistoryRemote.OnServerEvent:Connect(function(player, coinId)
		if type(coinId) ~= "string" then return end
		local state = coinStates[coinId]
		if not state then return end
		local ordered = MarketService.GetOrderedHistory(coinId)
		coinHistoryRemote:FireClient(player, coinId, ordered)
	end)

	-- OHLC candle history request
	if requestCandlesRemote then
		requestCandlesRemote.OnServerEvent:Connect(function(player, coinId, timeframe, limit)
			if type(coinId) ~= "string" then return end
			if type(timeframe) ~= "string" then return end
			if TIMEFRAMES[timeframe] == nil then return end
			if not coinStates[coinId] then return end
			limit = type(limit) == "number" and math.clamp(math.floor(limit), 1, Config.MAX_CANDLE_REQUEST) or Config.MAX_CANDLE_REQUEST
			local candles = getOrderedCandles(coinId, timeframe, limit)
			local cur = currentCandle[coinId][timeframe]
			if cur then
				table.insert(candles, cur)
			end
			if candleHistoryRemote then
				candleHistoryRemote:FireClient(player, coinId, timeframe, candles)
			end
		end)
	end

	-- RequestMarketSnapshot (§3.1 Client→Server)
	if requestMarketSnapshotRemote then
		requestMarketSnapshotRemote.OnServerEvent:Connect(function(player)
			marketSnapshotRemote:FireClient(player, MarketService.GetFullSnapshot())
		end)
	end
end

-------------------------------------------------
-- Phase Parameter Modifiers (§4.2)
-- Applied on top of base coin definition values.
-- liquidityMult: scales effective liquidity dampening
-- volatilityMult: scales noise amplitude
-- driftOffset: additive bias to baseline drift
-------------------------------------------------
local PHASE_MODIFIERS = {
	STEALTH = {
		liquidityMult  = 0.35,   -- low liquidity
		volatilityMult = 1.8,    -- high volatility
		driftOffset    = 0,      -- neutral drift
	},
	HYPE = {
		liquidityMult  = 0.8,    -- moderate liquidity
		volatilityMult = 1.3,    -- medium-high volatility
		driftOffset    = 0.001,  -- slight positive bias
	},
	DISTRIBUTION = {
		liquidityMult  = 0.6,    -- weakening liquidity
		volatilityMult = 1.5,    -- high volatility
		driftOffset    = -0.0005, -- neutral to slightly negative
	},
	DEAD = {
		liquidityMult  = 0.1,    -- extremely low liquidity
		volatilityMult = 0.3,    -- low volatility (nothing happening)
		driftOffset    = 0,      -- neutral
	},
	BLUECHIP = {
		liquidityMult  = 1.2,    -- high liquidity
		volatilityMult = 0.7,    -- moderate volatility
		driftOffset    = 0.0005, -- slight positive bias
	},
}

-------------------------------------------------
-- Price simulation tick (§4.1 + §4.2)
-------------------------------------------------
local function tickCoin(state: CoinState, def: any, dt: number)
	local vol = def.volatility
	local drift = def.trendBias
	local liq = def.liquidity

	-- §4.2: Apply phase parameter modifiers
	local phaseMod = PHASE_MODIFIERS[state.phase]
	if phaseMod then
		vol = vol * phaseMod.volatilityMult
		drift = drift + phaseMod.driftOffset
		liq = liq * phaseMod.liquidityMult
	end

	-- Apply event modifiers if active
	local mod = activeModifiers[state.id]
	if mod then
		if os.clock() > mod.expiry then
			activeModifiers[state.id] = nil
		else
			drift = drift + mod.drift
			vol = vol * mod.volMult
		end
	end

	-- §4.1: priceDelta = noise + drift + eventModifiers
	-- (netFlowAdjustment added in M6)
	local Z = rng:NextNumber() * 2 - 1
	Z = Z + (rng:NextNumber() * 2 - 1)
	Z = Z / 1.414

	local sqrtDt = math.sqrt(dt)
	local change = drift * dt + vol * sqrtDt * Z * 0.05

	-- Liquidity dampening (uses phase-adjusted liquidity)
	change = change * (1 - liq * 0.3)

	local newPrice = state.price * (1 + change)

	-- Clamp
	local floor = def.basePrice * Config.PRICE_FLOOR_MULT
	local ceil = def.basePrice * Config.PRICE_CEIL_MULT
	newPrice = math.clamp(newPrice, floor, ceil)

	-- Tick volume (phase-adjusted volatility affects volume)
	local tickVolume = math.floor(rng:NextNumber() * 50 * vol + 1)

	-- Update state
	state.lastPrice = state.price
	state.price = newPrice
	state.changePct = (newPrice - def.basePrice) / def.basePrice
	state.high = math.max(state.high, newPrice)
	state.low = math.min(state.low, newPrice)
	state.volume = state.volume + tickVolume

	-- Update effective liquidity on state (for TradeService slippage in M6)
	state.liquidity = liq

	-- Legacy ring buffer
	state.priceHistory[state.historyIndex] = newPrice
	state.historyIndex = (state.historyIndex % Config.MAX_HISTORY_POINTS) + 1

	-- OHLC candle update
	updateCandles(state.id, newPrice, tickVolume)
end

function MarketService.Tick(dt: number)
	for _, def in allDefs do
		local state = coinStates[def.id]
		if state then
			tickCoin(state, def, dt)
		end
	end
end

-------------------------------------------------
-- Build snapshot payload (§3.1 MarketSnapshot format)
-------------------------------------------------
local function buildSnapshotPayload(): {}
	local coins = {}
	for _, def in allDefs do
		local s = coinStates[def.id]
		if s then
			table.insert(coins, {
				id = s.id,
				s = s.symbol,    -- symbol (compact key)
				n = s.name,      -- name
				ic = s.icon,     -- icon (needed for dynamic coins on client)
				m = s.meta,      -- meta category
				ph = s.phase,    -- lifecycle phase
				p = math.floor(s.price * 10000) / 10000,
				cp = math.floor(s.changePct * 10000) / 10000,
				v = math.floor(s.volume),
				lp = math.floor(s.lastPrice * 10000) / 10000,
			})
		end
	end

	return {
		t = workspace:GetServerTimeNow(),
		coins = coins,
		mh = {},   -- metaHeat (placeholder for M5)
		hm = {},   -- hotMetas (placeholder for M5)
		news = {},  -- news (placeholder for M4)
	}
end

-------------------------------------------------
-- Broadcast snapshot to all clients
-------------------------------------------------
function MarketService.BroadcastSnapshot()
	marketSnapshotRemote:FireAllClients(buildSnapshotPayload())
end

-------------------------------------------------
-- Broadcast live candle updates
-------------------------------------------------
function MarketService.BroadcastCandleUpdates()
	if not candleUpdateRemote then return end
	for _, def in allDefs do
		local coinCandles = currentCandle[def.id]
		if coinCandles then
			for tfKey, candle in coinCandles do
				candleUpdateRemote:FireAllClients(def.id, tfKey, candle)
			end
		end
	end
end

-------------------------------------------------
-- Start the update loop
-------------------------------------------------
function MarketService.StartLoop()
	RunService.Heartbeat:Connect(function(dt)
		simAccumulator = simAccumulator + dt
		while simAccumulator >= Config.SIM_TICK do
			MarketService.Tick(Config.SIM_TICK)
			simAccumulator = simAccumulator - Config.SIM_TICK
		end

		broadcastAccumulator = broadcastAccumulator + dt
		if broadcastAccumulator >= Config.BROADCAST_INTERVAL then
			MarketService.BroadcastSnapshot()
			broadcastAccumulator = broadcastAccumulator - Config.BROADCAST_INTERVAL
		end

		candleUpdateAccumulator = candleUpdateAccumulator + dt
		if candleUpdateAccumulator >= Config.CANDLE_UPDATE_INTERVAL then
			MarketService.BroadcastCandleUpdates()
			candleUpdateAccumulator = candleUpdateAccumulator - Config.CANDLE_UPDATE_INTERVAL
		end
	end)
end

-------------------------------------------------
-- Public API
-------------------------------------------------
function MarketService.GetPrice(coinId: string): number?
	local state = coinStates[coinId]
	return state and state.price or nil
end

function MarketService.GetState(coinId: string): CoinState?
	return coinStates[coinId]
end

function MarketService.GetAllStates(): {[string]: CoinState}
	return coinStates
end

function MarketService.AddVolume(coinId: string, qty: number)
	local state = coinStates[coinId]
	if state then
		state.volume = state.volume + math.abs(qty)
	end
end

function MarketService.ApplyModifier(coinId: string, drift: number, volMult: number, duration: number)
	activeModifiers[coinId] = {
		drift = drift,
		volMult = volMult,
		expiry = os.clock() + duration,
	}
end

function MarketService.GetOrderedHistory(coinId: string): {number}
	local state = coinStates[coinId]
	if not state then return {} end
	local ordered = {}
	local idx = state.historyIndex
	for _ = 1, Config.MAX_HISTORY_POINTS do
		table.insert(ordered, state.priceHistory[idx])
		idx = (idx % Config.MAX_HISTORY_POINTS) + 1
	end
	return ordered
end

-- Full snapshot for single player (used on join via GetInitialState)
function MarketService.GetFullSnapshot(): {}
	return buildSnapshotPayload()
end

-------------------------------------------------
-- M3: Dynamic coin registration (LaunchpadService)
-------------------------------------------------

--- Register a newly launched coin into the simulation.
--- `def` must have: id, name, ticker, icon, basePrice, volatility, liquidity, trendBias, meta, initialPhase
function MarketService.RegisterCoin(def: any)
	if coinStates[def.id] then
		warn("[MarketService] Coin already registered: " .. def.id)
		return
	end

	-- Add to allDefs so loops pick it up
	table.insert(allDefs, def)

	-- Create coin state
	local history = table.create(Config.MAX_HISTORY_POINTS, def.basePrice)
	coinStates[def.id] = {
		id = def.id,
		symbol = def.ticker,
		name = def.name,
		icon = def.icon or "\u{1FA99}",
		meta = def.meta or "Memes",
		phase = def.initialPhase or "STEALTH",
		price = def.basePrice,
		lastPrice = def.basePrice,
		changePct = 0,
		volume = 0,
		high = def.basePrice,
		low = def.basePrice,
		liquidity = def.liquidity,
		volatility = def.volatility,
		drift = def.trendBias,
		devTrust = 40,
		communityStrength = 20,
		whaleConcentration = 50,
		devControl = 60,
		hype = 30,
		isTradable = true,
		isRuggable = true,
		eventModifiers = {},
		priceHistory = history,
		historyIndex = 1,
	}

	-- Initialize candle buffers for the new coin
	candlesHistory[def.id] = {}
	currentCandle[def.id] = {}
	for tfKey, _ in TIMEFRAMES do
		candlesHistory[def.id][tfKey] = {
			candles = table.create(MAX_CANDLE_HISTORY),
			head = 1,
			count = 0,
		}
		currentCandle[def.id][tfKey] = nil
	end

	print("[MarketService] Registered dynamic coin: " .. def.id .. " (" .. def.name .. ")")
end

--- Change a coin's phase (used by LaunchpadService for lifecycle transitions)
function MarketService.SetPhase(coinId: string, newPhase: string)
	local state = coinStates[coinId]
	if state then
		state.phase = newPhase
		print("[MarketService] " .. coinId .. " phase → " .. newPhase)
	end
end

return MarketService
