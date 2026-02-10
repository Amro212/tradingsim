--[[
	PlayerService.luau — In-memory player state management.
	Caches loaded data, manages holdings, trade logs, and rate limiting.
	Syncs state to client on join and on changes.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local PlayerService = {}

-- Dependencies (injected)
local SaveService = nil
local playerStateRemote: RemoteEvent = nil

-- In-memory state per player
local states: {[number]: {}} = {}     -- userId -> data
local rateLimits: {[number]: {}} = {} -- userId -> {tokens, lastRefill}

-------------------------------------------------
-- Initialize
-------------------------------------------------
function PlayerService.Init(remotes: {[string]: any}, saveSvc: any)
	playerStateRemote = remotes.PlayerState
	SaveService = saveSvc
end

-------------------------------------------------
-- Player join: load data, cache, sync to client
-------------------------------------------------
function PlayerService.OnPlayerAdded(player: Player)
	local userId = player.UserId

	-- Load from DataStore
	local ok, data = SaveService.LoadPlayerData(userId)
	if not ok then
		warn("[PlayerService] Load failed for " .. player.Name .. ", using defaults")
	end

	-- Cache
	states[userId] = data

	-- Init rate limiter
	rateLimits[userId] = {
		tokens = Config.MAX_TRADES_PER_SECOND,
		lastRefill = os.clock(),
	}

	-- Sync full state to client
	task.defer(function()
		if player.Parent then
			playerStateRemote:FireClient(player, {
				cash = data.cash,
				holdings = data.holdings,
				stats = data.stats,
				cosmetics = data.cosmetics,
				tutorialDone = data.tutorialDone,
			})
		end
	end)
end

-------------------------------------------------
-- Player leave: save data, cleanup
-------------------------------------------------
function PlayerService.OnPlayerRemoving(player: Player)
	local userId = player.UserId
	local data = states[userId]

	if data then
		SaveService.SavePlayerData(userId, data)
		states[userId] = nil
	end

	rateLimits[userId] = nil
end

-------------------------------------------------
-- Autosave all online players
-------------------------------------------------
function PlayerService.AutosaveAll()
	for _, player in Players:GetPlayers() do
		local data = states[player.UserId]
		if data then
			task.spawn(function()
				SaveService.SavePlayerData(player.UserId, data)
			end)
		end
	end
end

-- Start autosave loop
function PlayerService.StartAutosave()
	task.spawn(function()
		while true do
			task.wait(Config.AUTOSAVE_INTERVAL)
			PlayerService.AutosaveAll()
		end
	end)
end

-------------------------------------------------
-- State accessors
-------------------------------------------------
function PlayerService.GetState(player: Player): {}?
	return states[player.UserId]
end

function PlayerService.SyncState(player: Player)
	local data = states[player.UserId]
	if data and player.Parent then
		playerStateRemote:FireClient(player, {
			cash = data.cash,
			holdings = data.holdings,
			stats = data.stats,
			cosmetics = data.cosmetics,
			tutorialDone = data.tutorialDone,
		})
	end
end

-------------------------------------------------
-- Trade log management
-------------------------------------------------
function PlayerService.AddTradeLog(player: Player, entry: {})
	local data = states[player.UserId]
	if not data then return end

	-- Prepend to history
	table.insert(data.tradeHistory, 1, entry)

	-- Trim to max
	while #data.tradeHistory > Config.MAX_TRADE_HISTORY do
		table.remove(data.tradeHistory)
	end
end

function PlayerService.GetTradeHistory(player: Player): {}
	local data = states[player.UserId]
	if not data then return {} end
	return data.tradeHistory or {}
end

-------------------------------------------------
-- Rate limiting (token bucket)
-------------------------------------------------
function PlayerService.CheckRateLimit(player: Player): boolean
	local userId = player.UserId
	local rl = rateLimits[userId]
	if not rl then return false end

	local now = os.clock()
	local elapsed = now - rl.lastRefill

	-- Refill tokens
	if elapsed >= Config.RATE_LIMIT_WINDOW then
		rl.tokens = Config.MAX_TRADES_PER_SECOND
		rl.lastRefill = now
	end

	-- Consume token
	if rl.tokens > 0 then
		rl.tokens = rl.tokens - 1
		return true
	end

	return false
end

-------------------------------------------------
-- Game shutdown: save all
-------------------------------------------------
function PlayerService.OnServerShutdown()
	for _, player in Players:GetPlayers() do
		local data = states[player.UserId]
		if data then
			SaveService.SavePlayerData(player.UserId, data)
		end
	end
end

return PlayerService
