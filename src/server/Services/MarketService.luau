--[[
	MarketService.luau — Server-authoritative market simulation.
	Owns all coin price state. Runs a tick loop updating prices via
	stochastic random walk with drift, volatility, and event modifiers.
	Broadcasts compressed snapshots to all clients at a controlled rate.

	NEW: OHLC candle aggregation per coin per timeframe.
	Server stores ring-buffered candle history and broadcasts live
	updates + finalized candles to subscribed clients.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local CoinsModule = require(ReplicatedStorage.Shared.Coins)

local MarketService = {}

-- Types
export type CoinState = {
	id: string,
	price: number,
	lastPrice: number,
	changePct: number,
	volume: number,
	high: number,
	low: number,
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
local rng = Random.new(os.time()) -- seeded RNG for determinism within session
local activeModifiers: {[string]: {drift: number, volMult: number, expiry: number}} = {}

-- Remote references (set during Init)
local marketSnapshotRemote: RemoteEvent = nil
local coinHistoryRemote: RemoteEvent = nil
local candleHistoryRemote: RemoteEvent = nil
local candleUpdateRemote: RemoteEvent = nil
local candleAppendRemote: RemoteEvent = nil
local requestCandlesRemote: RemoteEvent = nil

-- Timers
local simAccumulator = 0
local broadcastAccumulator = 0
local candleUpdateAccumulator = 0

-------------------------------------------------
-- OHLC Candle aggregation state
-------------------------------------------------
-- candlesHistory[coinId][timeframeKey] = { candles = {Candle}, head = number, count = number }
local candlesHistory: {[string]: {[string]: { candles: {Candle}, head: number, count: number }}} = {}
-- currentCandle[coinId][timeframeKey] = Candle
local currentCandle: {[string]: {[string]: Candle}} = {}

local TIMEFRAMES = Config.TIMEFRAMES
local MAX_CANDLE_HISTORY = Config.MAX_CANDLE_HISTORY

-- Helper: get server time in seconds (monotonic)
local function serverTime(): number
	return workspace:GetServerTimeNow()
end

-- Helper: compute candle start time for a given timeframe
local function candleStartTime(now: number, tfSeconds: number): number
	return math.floor(now / tfSeconds) * tfSeconds
end

-- Initialize candle buffers for all coins and timeframes
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
			-- currentCandle starts nil; created on first tick
			currentCandle[def.id][tfKey] = nil
		end
	end
end

-- Push a finalized candle into the ring buffer
local function pushCandleToHistory(coinId: string, tfKey: string, candle: Candle)
	local buf = candlesHistory[coinId][tfKey]
	if not buf then return end
	buf.candles[buf.head] = candle
	buf.head = (buf.head % MAX_CANDLE_HISTORY) + 1
	buf.count = math.min(buf.count + 1, MAX_CANDLE_HISTORY)
end

-- Get ordered candle history (oldest→newest) from ring buffer
local function getOrderedCandles(coinId: string, tfKey: string, limit: number): {Candle}
	local buf = candlesHistory[coinId][tfKey]
	if not buf or buf.count == 0 then return {} end

	local count = math.min(buf.count, limit)
	local result = table.create(count)
	-- start index: head points to where the NEXT candle will be written
	-- so oldest = head - count (wrapped)
	local startIdx = ((buf.head - count - 1) % MAX_CANDLE_HISTORY) + 1
	for i = 1, count do
		local idx = ((startIdx + i - 2) % MAX_CANDLE_HISTORY) + 1
		table.insert(result, buf.candles[idx])
	end
	return result
end

-- Process a price tick for OHLC candle aggregation
local function updateCandles(coinId: string, price: number, tickVolume: number)
	local now = serverTime()
	for tfKey, tfSeconds in TIMEFRAMES do
		local cStart = candleStartTime(now, tfSeconds)
		local cur = currentCandle[coinId][tfKey]

		if cur == nil or cur.tOpen ~= cStart then
			-- Finalize the old candle (if any) and push to history
			if cur then
				pushCandleToHistory(coinId, tfKey, cur)
				-- Broadcast finalized candle to all clients
				if candleAppendRemote then
					candleAppendRemote:FireAllClients(coinId, tfKey, cur)
				end
			end
			-- Create new candle
			currentCandle[coinId][tfKey] = {
				tOpen = cStart,
				open = price,
				high = price,
				low = price,
				close = price,
				volume = tickVolume,
			}
		else
			-- Update existing candle
			cur.high = math.max(cur.high, price)
			cur.low = math.min(cur.low, price)
			cur.close = price
			cur.volume = cur.volume + tickVolume
		end
	end
end

-------------------------------------------------
-- Initialize coin states from definitions
-------------------------------------------------
function MarketService.Init(remotes: {[string]: any})
	marketSnapshotRemote = remotes.MarketSnapshot
	coinHistoryRemote = remotes.CoinHistory

	-- New candle remotes (may be nil if not yet created; checked before use)
	candleHistoryRemote = remotes.CandleHistory
	candleUpdateRemote = remotes.CandleUpdate
	candleAppendRemote = remotes.CandleAppend
	requestCandlesRemote = remotes.RequestCandles

	for _, def in CoinsModule.List do
		local history = table.create(Config.MAX_HISTORY_POINTS, def.basePrice)
		coinStates[def.id] = {
			id = def.id,
			price = def.basePrice,
			lastPrice = def.basePrice,
			changePct = 0,
			volume = 0,
			high = def.basePrice,
			low = def.basePrice,
			priceHistory = history,
			historyIndex = 1,
		}
	end

	-- Initialize candle ring buffers
	initCandleBuffers()

	-- Listen for client requesting coin history (legacy line chart)
	coinHistoryRemote.OnServerEvent:Connect(function(player, coinId)
		if type(coinId) ~= "string" then return end
		local state = coinStates[coinId]
		if not state then return end
		-- Send ordered history from ring buffer
		local ordered = MarketService.GetOrderedHistory(coinId)
		coinHistoryRemote:FireClient(player, coinId, ordered)
	end)

	-- Listen for client requesting OHLC candle history
	if requestCandlesRemote then
		requestCandlesRemote.OnServerEvent:Connect(function(player, coinId, timeframe, limit)
			-- Validate inputs
			if type(coinId) ~= "string" then return end
			if type(timeframe) ~= "string" then return end
			if TIMEFRAMES[timeframe] == nil then return end
			if not coinStates[coinId] then return end

			limit = type(limit) == "number" and math.clamp(math.floor(limit), 1, Config.MAX_CANDLE_REQUEST) or Config.MAX_CANDLE_REQUEST

			local candles = getOrderedCandles(coinId, timeframe, limit)

			-- Append the current (live) candle as the newest element
			local cur = currentCandle[coinId][timeframe]
			if cur then
				table.insert(candles, cur)
			end

			if candleHistoryRemote then
				candleHistoryRemote:FireClient(player, coinId, timeframe, candles)
			end
		end)
	end
end

-------------------------------------------------
-- Price simulation tick
-------------------------------------------------
local function tickCoin(state: CoinState, def: any, dt: number)
	local vol = def.volatility
	local drift = def.trendBias

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

	-- Stochastic random walk: price * (1 + drift*dt + vol*sqrt(dt)*Z)
	local Z = rng:NextNumber() * 2 - 1  -- uniform approx of normal
	-- Add a second sample for better distribution
	Z = Z + (rng:NextNumber() * 2 - 1)
	Z = Z / 1.414 -- normalize

	local sqrtDt = math.sqrt(dt)
	local change = drift * dt + vol * sqrtDt * Z * 0.05 -- scale factor

	-- Liquidity dampening: high liquidity = less extreme moves
	change = change * (1 - def.liquidity * 0.3)

	local newPrice = state.price * (1 + change)

	-- Clamp to floor/ceiling
	local floor = def.basePrice * Config.PRICE_FLOOR_MULT
	local ceil = def.basePrice * Config.PRICE_CEIL_MULT
	newPrice = math.clamp(newPrice, floor, ceil)

	-- Simulate tick volume (proportional to volatility and random)
	local tickVolume = math.floor(rng:NextNumber() * 50 * def.volatility + 1)

	-- Update state
	state.lastPrice = state.price
	state.price = newPrice
	state.changePct = (newPrice - def.basePrice) / def.basePrice
	state.high = math.max(state.high, newPrice)
	state.low = math.min(state.low, newPrice)
	state.volume = state.volume + tickVolume

	-- Push to ring buffer (legacy line chart)
	state.priceHistory[state.historyIndex] = newPrice
	state.historyIndex = (state.historyIndex % Config.MAX_HISTORY_POINTS) + 1

	-- Update OHLC candles for all timeframes
	updateCandles(state.id, newPrice, tickVolume)
end

function MarketService.Tick(dt: number)
	for _, def in CoinsModule.List do
		local state = coinStates[def.id]
		if state then
			tickCoin(state, def, dt)
		end
	end
end

-------------------------------------------------
-- Broadcast snapshot to all clients
-------------------------------------------------
function MarketService.BroadcastSnapshot()
	local coins = {}
	for _, def in CoinsModule.List do
		local s = coinStates[def.id]
		if s then
			table.insert(coins, {
				id = s.id,
				p = math.floor(s.price * 10000) / 10000,  -- 4 decimals
				cp = math.floor(s.changePct * 10000) / 10000,
				v = math.floor(s.volume),
				lp = math.floor(s.lastPrice * 10000) / 10000,
			})
		end
	end

	local snapshot = {
		t = workspace:GetServerTimeNow(),
		coins = coins,
	}

	marketSnapshotRemote:FireAllClients(snapshot)
end

-------------------------------------------------
-- Broadcast live candle updates at controlled rate
-------------------------------------------------
function MarketService.BroadcastCandleUpdates()
	if not candleUpdateRemote then return end
	for _, def in CoinsModule.List do
		local coinCandles = currentCandle[def.id]
		if coinCandles then
			for tfKey, candle in coinCandles do
				candleUpdateRemote:FireAllClients(def.id, tfKey, candle)
			end
		end
	end
end

-------------------------------------------------
-- Start the update loop (called from init.server)
-------------------------------------------------
function MarketService.StartLoop()
	RunService.Heartbeat:Connect(function(dt)
		-- Sim tick
		simAccumulator = simAccumulator + dt
		while simAccumulator >= Config.SIM_TICK do
			MarketService.Tick(Config.SIM_TICK)
			simAccumulator = simAccumulator - Config.SIM_TICK
		end

		-- Broadcast tick (market snapshot)
		broadcastAccumulator = broadcastAccumulator + dt
		if broadcastAccumulator >= Config.BROADCAST_INTERVAL then
			MarketService.BroadcastSnapshot()
			broadcastAccumulator = broadcastAccumulator - Config.BROADCAST_INTERVAL
		end

		-- Candle update broadcast (live updates at controlled rate)
		candleUpdateAccumulator = candleUpdateAccumulator + dt
		if candleUpdateAccumulator >= Config.CANDLE_UPDATE_INTERVAL then
			MarketService.BroadcastCandleUpdates()
			candleUpdateAccumulator = candleUpdateAccumulator - Config.CANDLE_UPDATE_INTERVAL
		end
	end)
end

-------------------------------------------------
-- Public API for other services
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

-- Apply an event modifier to a coin
function MarketService.ApplyModifier(coinId: string, drift: number, volMult: number, duration: number)
	activeModifiers[coinId] = {
		drift = drift,
		volMult = volMult,
		expiry = os.clock() + duration,
	}
end

-- Get ordered history (unrolled from ring buffer) — legacy line chart
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

-- Get a compact snapshot for a single player (used on join)
function MarketService.GetFullSnapshot(): {}
	local coins = {}
	for _, def in CoinsModule.List do
		local s = coinStates[def.id]
		if s then
			table.insert(coins, {
				id = s.id,
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
	}
end

return MarketService
