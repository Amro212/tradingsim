--[[
	Store.luau — Centralized state container for the trading UI.
	All Roact components read from this store and subscribe to changes.
	Remote events dispatch actions into this store.
	M1: Added tradingUIOpen for market list screen flow.
	M3: Added launchpad state, dynamic coin support, deep-link.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local Formatting = require(ReplicatedStorage.Shared.Formatting)
local Coins = require(ReplicatedStorage.Shared.Coins)

local Store = {}
Store.__index = Store

function Store.new()
	local self = setmetatable({}, Store)

	self._listeners = {}

	self._state = {
		-- Player
		cash = Config.STARTING_CASH,
		holdings = {},
		totalValue = Config.STARTING_CASH,
		totalPnL = 0,
		tutorialDone = false,
		tradeHistory = {},

		-- Market
		marketData = {},      -- { [coinId]: { id, s, n, m, ph, p, cp, v, ... } }

		-- UI state
		tradingUIOpen = false,     -- M1: whether market list screen is open
		selectedCoinId = nil,
		tradeModalOpen = false,
		bottomPanelOpen = false,
		activeTab = 1,
		currentAction = "BUY",
		qtyText = "",

		-- News
		newsEvents = {},

		-- Launchpad (M3)
		launchpadUIOpen = false,
		launchCountdown = 0,
		launchCurrentCoinId = nil,
		launchRecentLaunches = {},

		-- Toast
		toastMessage = nil,
		toastSuccess = false,
		toastVisible = false,
	}

	return self
end

function Store:getState()
	return self._state
end

function Store:subscribe(listener: () -> ())
	table.insert(self._listeners, listener)
	return function()
		for i, l in self._listeners do
			if l == listener then
				table.remove(self._listeners, i)
				break
			end
		end
	end
end

function Store:_notify()
	for _, listener in self._listeners do
		task.spawn(listener)
	end
end

function Store:_recomputePortfolio()
	local totalVal = self._state.cash
	local totalPnL = 0
	for coinId, h in self._state.holdings do
		if h.qty > 0 then
			local data = self._state.marketData[coinId]
			local price = data and data.p or 0
			totalVal += h.qty * price
			totalPnL += h.qty * (price - h.avgEntry)
		end
	end
	self._state.totalValue = totalVal
	self._state.totalPnL = totalPnL
end

-- ═══════════════════════════════════════════
-- ACTIONS
-- ═══════════════════════════════════════════

function Store:setPlayerState(state)
	if state.cash then self._state.cash = state.cash end
	if state.holdings then
		self._state.holdings = {}
		for coinId, h in state.holdings do
			self._state.holdings[coinId] = { qty = h.qty or 0, avgEntry = h.avgEntry or 0 }
		end
	end
	if state.tutorialDone ~= nil then
		self._state.tutorialDone = state.tutorialDone
	end
	if state.tradeHistory then
		self._state.tradeHistory = state.tradeHistory
	end
	self:_recomputePortfolio()
	self:_notify()
end

function Store:updateMarket(snapshot)
	if snapshot and snapshot.coins then
		for _, coinData in snapshot.coins do
			self._state.marketData[coinData.id] = coinData
		end
	end
	self:_recomputePortfolio()
	self:_notify()
end

-- M1: Open the Trading UI (market list screen)
function Store:openTradingUI()
	self._state.tradingUIOpen = true
	self._state.tradeModalOpen = false
	self._state.selectedCoinId = nil
	self:_notify()
end

-- M1: Close the entire Trading UI
function Store:closeTradingUI()
	self._state.tradingUIOpen = false
	self._state.tradeModalOpen = false
	self._state.selectedCoinId = nil
	self._state.qtyText = ""
	self:_notify()
end

-- Select a coin from market list → open trade modal
function Store:selectCoin(coinId: string)
	self._state.selectedCoinId = coinId
	self._state.currentAction = "BUY"
	self._state.qtyText = ""
	self._state.tradeModalOpen = true
	self:_notify()
end

-- Close trade modal → back to market list
function Store:closeModal()
	self._state.tradeModalOpen = false
	self._state.selectedCoinId = nil
	self._state.qtyText = ""
	self:_notify()
end

function Store:toggleBottomPanel()
	self._state.bottomPanelOpen = not self._state.bottomPanelOpen
	self:_notify()
end

function Store:setActiveTab(tab: number)
	self._state.activeTab = tab
	self:_notify()
end

function Store:setAction(action: string)
	self._state.currentAction = action
	self:_notify()
end

function Store:setQtyText(text: string)
	self._state.qtyText = text
	self:_notify()
end

function Store:onTradeResult(result)
	if result.ok then
		self:showToast(result.message, true)
	else
		self:showToast(result.message, false)
	end
	if result.newCash then self._state.cash = result.newCash end
	if result.coinId and result.holding then
		self._state.holdings[result.coinId] = result.holding
	end
	if result.trade then
		table.insert(self._state.tradeHistory, 1, result.trade)
		if #self._state.tradeHistory > 50 then
			table.remove(self._state.tradeHistory)
		end
	end
	self._state.qtyText = ""
	self:_recomputePortfolio()
	self:_notify()
end

function Store:addNewsEvent(eventData)
	table.insert(self._state.newsEvents, 1, eventData)
	if #self._state.newsEvents > 25 then
		table.remove(self._state.newsEvents)
	end
	self:_notify()
end

function Store:loadNewsEvents(events)
	for i = #events, 1, -1 do
		table.insert(self._state.newsEvents, 1, events[i])
	end
	self:_notify()
end

function Store:showToast(message: string, isSuccess: boolean)
	self._state.toastMessage = message
	self._state.toastSuccess = isSuccess
	self._state.toastVisible = true
	self:_notify()
	task.delay(3, function()
		self._state.toastVisible = false
		self:_notify()
	end)
end

function Store:setTutorialDone()
	self._state.tutorialDone = true
	self:_notify()
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	if remotes then
		local td = remotes:FindFirstChild("TutorialDone")
		if td then td:FireServer() end
	end
end

-- ═══════════════════════════════════════════
-- HELPERS for components
-- ═══════════════════════════════════════════

function Store:getSelectedCoinDef()
	local id = self._state.selectedCoinId
	if not id then return nil end

	-- Try static coin first
	local def = Coins.ById[id]
	if def then return def end

	-- Fall back to dynamic coin from market data
	local data = self._state.marketData[id]
	if data then
		return {
			id = id,
			name = data.n or id,
			ticker = data.s or id,
			icon = data.ic or "\u{1FA99}",
			meta = data.m or "?",
			initialPhase = data.ph or "STEALTH",
			basePrice = data.p or 1,
			volatility = 0.5,
			liquidity = 0.3,
			trendBias = 0,
			riskTag = "High",
			description = "Newly launched coin",
			accentColor = {0.5, 0.5, 0.5},
		}
	end
	return nil
end

function Store:getSelectedCoinPrice(): number
	local id = self._state.selectedCoinId
	if not id then return 0 end
	local data = self._state.marketData[id]
	return data and data.p or 0
end

function Store:getCoinPrice(coinId: string): number
	local data = self._state.marketData[coinId]
	return data and data.p or 0
end

function Store:getSelectedCoinChange(): number
	local id = self._state.selectedCoinId
	if not id then return 0 end
	local data = self._state.marketData[id]
	return data and data.cp or 0
end

-- Get all coins sorted by absolute changePct (top movers)
-- M3: supports both static (Coins.List) and dynamic (launched) coins
function Store:getSortedCoins(): {{}}
	local list = {}
	local seen: {[string]: boolean} = {}

	-- First include static coins with their full CoinDef
	for _, coinDef in Coins.List do
		local data = self._state.marketData[coinDef.id]
		if data then
			seen[coinDef.id] = true
			table.insert(list, {
				def = coinDef,
				data = data,
			})
		end
	end

	-- Then include dynamic coins (from market data but not in Coins.List)
	for coinId, data in self._state.marketData do
		if not seen[coinId] then
			-- Construct a def-like object from snapshot data
			local dynDef = {
				id = coinId,
				name = data.n or coinId,
				ticker = data.s or coinId,
				icon = data.ic or "\u{1FA99}",
				meta = data.m or "?",
				initialPhase = data.ph or "STEALTH",
				basePrice = data.p or 1,
				volatility = 0.5,
				liquidity = 0.3,
				trendBias = 0,
				riskTag = "High",
				description = "Newly launched coin",
				accentColor = {0.5, 0.5, 0.5},
			}
			table.insert(list, {
				def = dynDef,
				data = data,
			})
		end
	end

	table.sort(list, function(a, b)
		return math.abs(a.data.cp or 0) > math.abs(b.data.cp or 0)
	end)
	return list
end

-- ═══════════════════════════════════════════
-- LAUNCHPAD ACTIONS (M3)
-- ═══════════════════════════════════════════

function Store:openLaunchpadUI()
	self._state.launchpadUIOpen = true
	self._state.tradingUIOpen = false
	self._state.tradeModalOpen = false
	self:_notify()
end

function Store:closeLaunchpadUI()
	self._state.launchpadUIOpen = false
	self:_notify()
end

function Store:updateLaunchpadState(lpState)
	if lpState.countdown ~= nil then
		self._state.launchCountdown = lpState.countdown
	end
	if lpState.currentCoinId ~= nil then
		self._state.launchCurrentCoinId = lpState.currentCoinId
	end
	if lpState.recentLaunches then
		self._state.launchRecentLaunches = lpState.recentLaunches
	end
	self:_notify()
end

--- Deep-link: open Trading UI directly to a specific coin's chart
function Store:deepLinkCoin(coinId: string)
	self._state.launchpadUIOpen = false
	self._state.tradingUIOpen = true
	self._state.selectedCoinId = coinId
	self._state.currentAction = "BUY"
	self._state.qtyText = ""
	self._state.tradeModalOpen = true
	self:_notify()
end

function Store:setQuickPercent(pct: number)
	local coinId = self._state.selectedCoinId
	if not coinId then return end
	local price = self:getSelectedCoinPrice()
	if price <= 0 then return end

	if self._state.currentAction == "BUY" then
		local maxQ = (self._state.cash * pct) / (price * (1 + Config.TRADE_FEE_PCT + Config.SLIPPAGE_BASE_PCT))
		self._state.qtyText = Formatting.formatQty(math.floor(maxQ * 100) / 100)
	else
		local h = self._state.holdings[coinId]
		if h and h.qty > 0 then
			self._state.qtyText = Formatting.formatQty(math.floor(h.qty * pct * 100) / 100)
		else
			self._state.qtyText = "0"
		end
	end
	self:_notify()
end

function Store:executeTrade()
	local coinId = self._state.selectedCoinId
	if not coinId then return end
	local qty = tonumber(self._state.qtyText)
	if not qty or qty <= 0 then return end

	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	if remotes then
		local rt = remotes:FindFirstChild("RequestTrade")
		if rt then rt:FireServer(self._state.currentAction, coinId, qty) end
	end
end

return Store
