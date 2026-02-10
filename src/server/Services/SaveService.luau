--[[
	SaveService.luau — DataStore persistence for player data.
	Handles load (with fallback), save (on leave + autosave),
	and type-safe validation of loaded data.
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local SaveService = {}

-- DataStore reference
local dataStore = nil

-- Default player data template
local DEFAULT_DATA = {
	cash = Config.STARTING_CASH,
	holdings = {},
	stats = {
		totalTrades = 0,
		totalPnL = 0,
		bestTrade = 0,
	},
	cosmetics = {
		owned = {},
		equipped = {
			UITheme = Config.DEFAULT_THEME,
		},
	},
	tutorialDone = false,
	tradeHistory = {},
}

-------------------------------------------------
-- Initialize
-------------------------------------------------
function SaveService.Init()
	-- pcall DataStore in case we're in Studio without API access
	local ok, store = pcall(function()
		return DataStoreService:GetDataStore("TradingSimData")
	end)
	if ok then
		dataStore = store
	else
		warn("[SaveService] DataStore unavailable: " .. tostring(store))
	end
end

-------------------------------------------------
-- Deep copy utility
-------------------------------------------------
local function deepCopy(original)
	if type(original) ~= "table" then return original end
	local copy = {}
	for k, v in original do
		copy[k] = deepCopy(v)
	end
	return copy
end

-------------------------------------------------
-- Validate loaded data against template
-------------------------------------------------
local function validateData(data: any): {}
	if type(data) ~= "table" then
		return deepCopy(DEFAULT_DATA)
	end

	local validated = deepCopy(DEFAULT_DATA)

	-- Cash
	if type(data.cash) == "number" and data.cash == data.cash and data.cash >= 0 then
		validated.cash = data.cash
	end

	-- Holdings
	if type(data.holdings) == "table" then
		for coinId, holding in data.holdings do
			if type(coinId) == "string" and type(holding) == "table" then
				if type(holding.qty) == "number" and holding.qty >= 0
					and type(holding.avgEntry) == "number" and holding.avgEntry >= 0
				then
					validated.holdings[coinId] = {
						qty = holding.qty,
						avgEntry = holding.avgEntry,
						realizedPnL = type(holding.realizedPnL) == "number" and holding.realizedPnL or 0,
					}
				end
			end
		end
	end

	-- Stats
	if type(data.stats) == "table" then
		if type(data.stats.totalTrades) == "number" then
			validated.stats.totalTrades = data.stats.totalTrades
		end
		if type(data.stats.totalPnL) == "number" then
			validated.stats.totalPnL = data.stats.totalPnL
		end
		if type(data.stats.bestTrade) == "number" then
			validated.stats.bestTrade = data.stats.bestTrade
		end
	end

	-- Cosmetics
	if type(data.cosmetics) == "table" then
		if type(data.cosmetics.owned) == "table" then
			validated.cosmetics.owned = data.cosmetics.owned
		end
		if type(data.cosmetics.equipped) == "table" then
			validated.cosmetics.equipped = data.cosmetics.equipped
		end
	end

	-- Tutorial
	if type(data.tutorialDone) == "boolean" then
		validated.tutorialDone = data.tutorialDone
	end

	-- Trade history
	if type(data.tradeHistory) == "table" then
		-- Only keep up to max
		local count = math.min(#data.tradeHistory, Config.MAX_TRADE_HISTORY)
		validated.tradeHistory = {}
		for i = 1, count do
			table.insert(validated.tradeHistory, data.tradeHistory[i])
		end
	end

	return validated
end

-------------------------------------------------
-- Load player data
-------------------------------------------------
function SaveService.LoadPlayerData(userId: number): (boolean, {})
	if not dataStore then
		warn("[SaveService] No DataStore, using defaults for user " .. tostring(userId))
		return true, deepCopy(DEFAULT_DATA)
	end

	local key = Config.DATASTORE_KEY_PREFIX .. tostring(userId)
	local ok, result = pcall(function()
		return dataStore:GetAsync(key)
	end)

	if not ok then
		warn("[SaveService] Load failed for " .. key .. ": " .. tostring(result))
		return false, deepCopy(DEFAULT_DATA)
	end

	if result == nil then
		-- New player, use defaults
		return true, deepCopy(DEFAULT_DATA)
	end

	return true, validateData(result)
end

-------------------------------------------------
-- Save player data
-------------------------------------------------
function SaveService.SavePlayerData(userId: number, data: {}): boolean
	if not dataStore then
		warn("[SaveService] No DataStore, skipping save for user " .. tostring(userId))
		return false
	end

	local key = Config.DATASTORE_KEY_PREFIX .. tostring(userId)

	-- Prepare save data (strip non-persistent fields)
	local saveData = {
		cash = data.cash,
		holdings = data.holdings,
		stats = data.stats,
		cosmetics = data.cosmetics,
		tutorialDone = data.tutorialDone,
		tradeHistory = data.tradeHistory,
	}

	local ok, err = pcall(function()
		dataStore:SetAsync(key, saveData)
	end)

	if not ok then
		warn("[SaveService] Save failed for " .. key .. ": " .. tostring(err))
		return false
	end

	return true
end

-------------------------------------------------
-- Get default data (for reference)
-------------------------------------------------
function SaveService.GetDefaults(): {}
	return deepCopy(DEFAULT_DATA)
end

return SaveService
