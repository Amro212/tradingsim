--[[
	init.client.luau — Main client entry point for 3D trading floor.
	Builds HUD UI, initializes controllers, wires StationController
	ProximityPrompts to open trade modal, connects all remotes.
	NEW: Wires candlestick chart remotes + timeframe switching.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer

-- Wait for remotes
local Remotes = ReplicatedStorage:WaitForChild("Remotes", 30)
if not Remotes then
	warn("[Client] Remotes not found!")
	return
end

-- Disable default UI clutter
pcall(function()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
end)

-- Get or create ScreenGui
local screenGui: ScreenGui = player.PlayerGui:WaitForChild("TradingUI", 10)
if not screenGui then
	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "TradingUI"
	screenGui.IgnoreGuiInset = true
	screenGui.ResetOnSpawn = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.DisplayOrder = 10
	screenGui.Parent = player.PlayerGui
end

-- Require controllers
local Ctrl = script.Controllers
local UIController = require(Ctrl.UIController)
local ChartRenderer = require(Ctrl.ChartRenderer)
local MarketController = require(Ctrl.MarketController)
local TradeController = require(Ctrl.TradeController)
local PortfolioController = require(Ctrl.PortfolioController)
local NewsController = require(Ctrl.NewsController)
local TutorialController = require(Ctrl.TutorialController)
local StationController = require(Ctrl.StationController)

-- Build HUD layout
UIController.BuildLayout(screenGui)

-- Initialize controllers
ChartRenderer.Init(UIController)
MarketController.Init(UIController, ChartRenderer)
TradeController.Init(UIController, MarketController)
PortfolioController.Init(UIController, MarketController, TradeController)
NewsController.Init(UIController)
TutorialController.Init(UIController)
StationController.Init(UIController)

-------------------------------------------------
-- Helper: request candle data from server
-------------------------------------------------
local function requestCandles(coinId: string, timeframe: string)
	local remote = Remotes:FindFirstChild("RequestCandles")
	if remote then
		remote:FireServer(coinId, timeframe, 200)
	end
end

-- Wire station interaction → open trade modal
StationController.OnInteract(function(coinId)
	MarketController.SelectCoin(coinId)
	TradeController.SetAction("BUY") -- reset to BUY on open
	TradeController.UpdateHoldingInfo()
	UIController.OpenTradeModal()

	-- Set coin on chart renderer and request candle data
	ChartRenderer.SetCoin(coinId)
	requestCandles(coinId, ChartRenderer.GetTimeframe())
end)

-- Wire timeframe change callback
ChartRenderer._onTimeframeChanged = function(newTf: string)
	local coinId = MarketController.GetSelectedCoinId()
	if coinId then
		ChartRenderer.Clear()
		requestCandles(coinId, newTf)
	end
end

-- Wire bottom panel toggle
local toggleBtn = UIController.GetElement("BottomToggle")
if toggleBtn then
	toggleBtn.MouseButton1Click:Connect(function()
		UIController.ToggleBottomPanel()
		PortfolioController.RefreshHoldings()
	end)
end

-- Wire tab switching
local function setupTabs()
	local tabBar = UIController.GetElement("BottomPanel.TabBar")
	local tabContent = UIController.GetElement("BottomPanel.TabContent")
	if not tabBar or not tabContent then return end
	local tabs = {
		tabContent:FindFirstChild("PortfolioTab"),
		tabContent:FindFirstChild("HistoryTab"),
		tabContent:FindFirstChild("NewsTab"),
	}
	local tabBtns = {}
	for _, c in tabBar:GetChildren() do
		if c:IsA("TextButton") then table.insert(tabBtns, c) end
	end
	table.sort(tabBtns, function(a, b) return a.LayoutOrder < b.LayoutOrder end)
	local C = UIController.Colors
	for i, btn in tabBtns do
		btn.MouseButton1Click:Connect(function()
			for j, t in tabs do if t then t.Visible = (j == i) end end
			for j, b in tabBtns do
				b.BackgroundColor3 = (j == i) and C.bgTertiary or C.bgSecondary
				b.TextColor3 = (j == i) and C.textPrimary or C.textSecondary
			end
			if i == 1 then PortfolioController.RefreshHoldings() end
		end)
	end
end
setupTabs()

-- Request initial state
print("[Client] Requesting initial state...")
local initRemote = Remotes:FindFirstChild("GetInitialState")
if initRemote then
	local ok, result = pcall(function() return initRemote:InvokeServer() end)
	if ok and result and not result.error then
		if result.playerState then
			TradeController.SetPlayerState(result.playerState)
			TutorialController.ShouldShow(result.playerState.tutorialDone)
			if result.playerState.tradeHistory then
				PortfolioController.SetTradeHistory(result.playerState.tradeHistory)
			end
		end
		if result.marketSnapshot then
			MarketController.UpdateMarket(result.marketSnapshot)
			StationController.UpdatePrices(result.marketSnapshot)
		end
		if result.recentEvents then
			NewsController.LoadEvents(result.recentEvents)
		end
		print("[Client] Initial state loaded!")
	else
		warn("[Client] Failed to get initial state:", result)
	end
end

-- =====================================
-- Connect remotes
-- =====================================

-- Market snapshots (existing)
Remotes:WaitForChild("MarketSnapshot").OnClientEvent:Connect(function(snapshot)
	MarketController.UpdateMarket(snapshot)
	StationController.UpdatePrices(snapshot)
	TradeController.UpdateTopBar()
end)

-- Legacy coin history (line chart — still used if chart hasn't switched to candles)
Remotes:WaitForChild("CoinHistory").OnClientEvent:Connect(function(coinId, history)
	-- Only draw legacy if no candle data has been received yet
	-- (this acts as a fallback)
	if coinId == MarketController.GetSelectedCoinId() then
		-- Don't override if we already have candle data
		-- ChartRenderer.Draw(history) -- disabled: candles take priority
	end
end)

-- OHLC Candle history batch (response to RequestCandles)
local candleHistoryRemote = Remotes:WaitForChild("CandleHistory", 10)
if candleHistoryRemote then
	candleHistoryRemote.OnClientEvent:Connect(function(coinId, timeframe, candles)
		-- Only process if matches current selection + timeframe
		if coinId ~= MarketController.GetSelectedCoinId() then return end
		if timeframe ~= ChartRenderer.GetTimeframe() then return end
		ChartRenderer.RenderCandles(candles)
	end)
end

-- Live candle update (current candle OHLC changing)
local candleUpdateRemote = Remotes:WaitForChild("CandleUpdate", 10)
if candleUpdateRemote then
	candleUpdateRemote.OnClientEvent:Connect(function(coinId, timeframe, candle)
		if coinId ~= MarketController.GetSelectedCoinId() then return end
		if timeframe ~= ChartRenderer.GetTimeframe() then return end
		-- Only update if modal is open (perf: skip rendering when hidden)
		if not UIController.IsTradeModalOpen() then return end
		ChartRenderer.UpdateLastCandle(candle)
	end)
end

-- Finalized candle append (new candle closed, pushed to history)
local candleAppendRemote = Remotes:WaitForChild("CandleAppend", 10)
if candleAppendRemote then
	candleAppendRemote.OnClientEvent:Connect(function(coinId, timeframe, candle)
		if coinId ~= MarketController.GetSelectedCoinId() then return end
		if timeframe ~= ChartRenderer.GetTimeframe() then return end
		ChartRenderer.AppendCandle(candle)
	end)
end

-- Trade results
Remotes:WaitForChild("TradeResult").OnClientEvent:Connect(function(result)
	TradeController.OnTradeResult(result)
	if result.ok and result.trade then
		PortfolioController.AddTradeEntry(result.trade)
	end
	PortfolioController.RefreshHoldings()
end)

Remotes:WaitForChild("PlayerState").OnClientEvent:Connect(function(state)
	TradeController.SetPlayerState(state)
	PortfolioController.RefreshHoldings()
end)

Remotes:WaitForChild("NewsEvent").OnClientEvent:Connect(function(eventData)
	NewsController.AddEvent(eventData)
end)

-- Periodic candle refresh while modal is open
-- (re-request full candle set every 10 seconds as a safety net)
task.spawn(function()
	while true do
		task.wait(10)
		if UIController.IsTradeModalOpen() then
			local coinId = MarketController.GetSelectedCoinId()
			if coinId then
				requestCandles(coinId, ChartRenderer.GetTimeframe())
			end
		end
	end
end)

-- Escape key to close modal + Shift to sprint
local WALK_SPEED = 20
local SPRINT_SPEED = 36

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == Enum.KeyCode.Escape then
		if UIController.IsTradeModalOpen() then
			UIController.CloseTradeModal()
		end
	elseif input.KeyCode == Enum.KeyCode.LeftShift then
		local char = player.Character
		if char then
			local hum = char:FindFirstChildOfClass("Humanoid")
			if hum then hum.WalkSpeed = SPRINT_SPEED end
		end
	end
end)

UserInputService.InputEnded:Connect(function(input, _processed)
	if input.KeyCode == Enum.KeyCode.LeftShift then
		local char = player.Character
		if char then
			local hum = char:FindFirstChildOfClass("Humanoid")
			if hum then hum.WalkSpeed = WALK_SPEED end
		end
	end
end)

-- Start tutorial
task.delay(2, function()
	TutorialController.Start()
end)

-- Initial refresh
task.defer(function()
	PortfolioController.RefreshHoldings()
end)

print("[Client] Trading floor UI ready! Walk to a station and press E.")
