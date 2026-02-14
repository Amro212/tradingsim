--[[
	LaunchpadService.luau — Server-authoritative coin launchpad system (§5).
	Spawns new coins at configurable intervals, assigns meta, initializes
	STEALTH phase with low liquidity/high volatility, manages lifecycle
	phase transitions, and broadcasts launchpad state to clients.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local CoinPool = require(ReplicatedStorage.Shared.CoinPool)

local LaunchpadService = {}

-- Dependencies (injected via Init)
local MarketService = nil
local newsEventRemote: RemoteEvent = nil
local launchpadStateRemote: RemoteEvent = nil
local coinLaunchedRemote: RemoteEvent = nil

-- State
local rng = Random.new(os.time() + 12345)
local nextLaunchTime: number = 0
local launchHistory: {{}} = {}  -- recent launches (newest first)
local currentCoinId: string? = nil  -- coin currently on hologram pedestal

-- Phase transition schedule: { [coinId]: { nextTime: number, nextPhase: string } }
local phaseSchedule: {[string]: { nextTime: number, nextPhase: string }} = {}

-- Count dynamic coins (to enforce MAX_DYNAMIC_COINS)
local dynamicCoinCount = 0

-------------------------------------------------
-- Internal: schedule the next phase for a coin
-------------------------------------------------
local function scheduleNextPhase(coinId: string, currentPhase: string)
	local now = workspace:GetServerTimeNow()
	local min, max, nextPhase

	if currentPhase == "STEALTH" then
		min = Config.PHASE_STEALTH_DURATION_MIN
		max = Config.PHASE_STEALTH_DURATION_MAX
		nextPhase = "HYPE"
	elseif currentPhase == "HYPE" then
		min = Config.PHASE_HYPE_DURATION_MIN
		max = Config.PHASE_HYPE_DURATION_MAX
		nextPhase = "DISTRIBUTION"
	elseif currentPhase == "DISTRIBUTION" then
		min = Config.PHASE_DISTRIBUTION_DURATION_MIN
		max = Config.PHASE_DISTRIBUTION_DURATION_MAX
		-- Roll: BLUECHIP or DEAD
		if rng:NextNumber() < Config.BLUECHIP_CHANCE then
			nextPhase = "BLUECHIP"
		else
			nextPhase = "DEAD"
		end
	else
		-- DEAD or BLUECHIP: no more transitions
		return
	end

	local delay = rng:NextInteger(min, max)
	phaseSchedule[coinId] = {
		nextTime = now + delay,
		nextPhase = nextPhase,
	}
end

-------------------------------------------------
-- Internal: process phase transitions
-------------------------------------------------
local function processPhases()
	local now = workspace:GetServerTimeNow()
	local toRemove = {}

	for coinId, schedule in phaseSchedule do
		if now >= schedule.nextTime then
			local newPhase = schedule.nextPhase
			MarketService.SetPhase(coinId, newPhase)

			-- Emit news event for phase transition
			if newsEventRemote then
				local state = MarketService.GetState(coinId)
				local headline = ""
				if newPhase == "HYPE" then
					headline = (state and state.name or coinId) .. " is heating up! Entering HYPE phase."
				elseif newPhase == "DISTRIBUTION" then
					headline = (state and state.name or coinId) .. " entering DISTRIBUTION — whales may sell."
				elseif newPhase == "DEAD" then
					headline = (state and state.name or coinId) .. " has DIED. RIP."
				elseif newPhase == "BLUECHIP" then
					headline = (state and state.name or coinId) .. " achieved BLUECHIP status!"
				end
				if headline ~= "" then
					newsEventRemote:FireAllClients({
						time = now,
						type = "PhaseChange",
						coinId = coinId,
						headline = headline,
					})
				end
			end

			-- Schedule the next phase
			table.insert(toRemove, coinId)
			scheduleNextPhase(coinId, newPhase)
		end
	end

	-- Remove processed entries (scheduleNextPhase may have re-added them)
	-- No-op since scheduleNextPhase overwrites the key
end

-------------------------------------------------
-- Internal: launch a new coin
-------------------------------------------------
local function launchCoin()
	if dynamicCoinCount >= Config.MAX_DYNAMIC_COINS then
		print("[LaunchpadService] Max dynamic coins reached, skipping launch.")
		return
	end

	-- Pick a coin from the pool
	local coinInfo = CoinPool.Pick(rng, nil) -- hotMeta integration in M5

	-- Build a def compatible with MarketService.RegisterCoin
	local def = {
		id = coinInfo.id,
		name = coinInfo.name,
		ticker = coinInfo.ticker,
		icon = coinInfo.icon,
		basePrice = coinInfo.basePrice,
		volatility = 0.70,   -- high (STEALTH)
		liquidity = 0.15,    -- low (STEALTH)
		trendBias = 0,       -- neutral
		riskTag = "Extreme",
		meta = coinInfo.meta,
		initialPhase = "STEALTH",
		description = coinInfo.desc,
		accentColor = coinInfo.accentColor,
	}

	-- Register with MarketService (creates state + candle buffers)
	MarketService.RegisterCoin(def)
	dynamicCoinCount += 1

	-- Schedule first phase transition (STEALTH → HYPE)
	scheduleNextPhase(def.id, "STEALTH")

	-- Update hologram
	currentCoinId = def.id

	-- Add to launch history
	local launchEntry = {
		coinId = def.id,
		name = def.name,
		ticker = def.ticker,
		icon = coinInfo.icon,
		meta = def.meta,
		basePrice = def.basePrice,
		launchedAt = workspace:GetServerTimeNow(),
	}
	table.insert(launchHistory, 1, launchEntry)
	if #launchHistory > Config.LAUNCH_HISTORY_SIZE then
		table.remove(launchHistory)
	end

	-- Broadcast launch event to all clients
	if coinLaunchedRemote then
		coinLaunchedRemote:FireAllClients(launchEntry)
	end

	-- Emit news event
	if newsEventRemote then
		newsEventRemote:FireAllClients({
			time = workspace:GetServerTimeNow(),
			type = "CoinLaunched",
			coinId = def.id,
			headline = def.icon .. " NEW LAUNCH: " .. def.name .. " ($" .. def.ticker .. ") — " .. def.meta .. " meta!",
		})
	end

	print("[LaunchpadService] Launched: " .. def.name .. " ($" .. def.ticker .. ") [" .. def.meta .. "] @ $" .. string.format("%.2f", def.basePrice))
end

-------------------------------------------------
-- Public API
-------------------------------------------------

function LaunchpadService.Init(remotes: {[string]: any}, marketSvc: any)
	MarketService = marketSvc
	newsEventRemote = remotes.NewsEvent
	launchpadStateRemote = remotes.LaunchpadState
	coinLaunchedRemote = remotes.CoinLaunched

	-- Schedule first launch
	nextLaunchTime = workspace:GetServerTimeNow() + Config.LAUNCH_FIRST_DELAY

	-- Handle client requests for launchpad state
	local reqRemote = remotes.RequestLaunchpadState
	if reqRemote then
		reqRemote.OnServerEvent:Connect(function(player)
			if launchpadStateRemote then
				launchpadStateRemote:FireClient(player, LaunchpadService.GetState())
			end
		end)
	end

	print("[LaunchpadService] Initialized. First launch in " .. Config.LAUNCH_FIRST_DELAY .. "s")
end

function LaunchpadService.StartLoop()
	RunService.Heartbeat:Connect(function(_dt)
		local now = workspace:GetServerTimeNow()

		-- Check if it's time to launch
		if now >= nextLaunchTime then
			launchCoin()
			-- Schedule next launch
			local interval = rng:NextInteger(Config.LAUNCH_INTERVAL_MIN, Config.LAUNCH_INTERVAL_MAX)
			nextLaunchTime = now + interval
		end

		-- Process phase transitions
		processPhases()

		-- Broadcast launchpad state periodically (piggybacked on market snapshot interval)
		-- (Clients also get state on request)
	end)
end

--- Get current launchpad state for a client
function LaunchpadService.GetState(): {}
	local now = workspace:GetServerTimeNow()
	return {
		countdown = math.max(0, math.floor(nextLaunchTime - now)),
		currentCoinId = currentCoinId,
		recentLaunches = launchHistory,
	}
end

--- Broadcast launchpad state to all clients
function LaunchpadService.BroadcastState()
	if launchpadStateRemote then
		launchpadStateRemote:FireAllClients(LaunchpadService.GetState())
	end
end

return LaunchpadService
