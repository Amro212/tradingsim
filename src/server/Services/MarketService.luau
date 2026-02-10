--[[
	MarketService.luau — Server-authoritative market simulation.
	Owns all coin price state. Runs a tick loop updating prices via
	stochastic random walk with drift, volatility, and event modifiers.
	Broadcasts compressed snapshots to all clients at a controlled rate.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

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

-- Internal state
local coinStates: {[string]: CoinState} = {}
local rng = Random.new(os.time()) -- seeded RNG for determinism within session
local activeModifiers: {[string]: {drift: number, volMult: number, expiry: number}} = {}

-- Remote references (set during Init)
local marketSnapshotRemote: RemoteEvent = nil
local coinHistoryRemote: RemoteEvent = nil

-- Timers
local simAccumulator = 0
local broadcastAccumulator = 0

-------------------------------------------------
-- Initialize coin states from definitions
-------------------------------------------------
function MarketService.Init(remotes: {[string]: any})
	marketSnapshotRemote = remotes.MarketSnapshot
	coinHistoryRemote = remotes.CoinHistory

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

	-- Listen for client requesting coin history (on coin selection)
	coinHistoryRemote.OnServerEvent:Connect(function(player, coinId)
		if type(coinId) ~= "string" then return end
		local state = coinStates[coinId]
		if not state then return end
		-- Send ordered history from ring buffer
		local ordered = MarketService.GetOrderedHistory(coinId)
		coinHistoryRemote:FireClient(player, coinId, ordered)
	end)
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

	-- Update state
	state.lastPrice = state.price
	state.price = newPrice
	state.changePct = (newPrice - def.basePrice) / def.basePrice
	state.high = math.max(state.high, newPrice)
	state.low = math.min(state.low, newPrice)

	-- Push to ring buffer
	state.priceHistory[state.historyIndex] = newPrice
	state.historyIndex = (state.historyIndex % Config.MAX_HISTORY_POINTS) + 1
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

		-- Broadcast tick
		broadcastAccumulator = broadcastAccumulator + dt
		if broadcastAccumulator >= Config.BROADCAST_INTERVAL then
			MarketService.BroadcastSnapshot()
			broadcastAccumulator = broadcastAccumulator - Config.BROADCAST_INTERVAL
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

-- Get ordered history (unrolled from ring buffer)
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
