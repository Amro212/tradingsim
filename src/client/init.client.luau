--[[
	init.client.luau — Main client entry point for 3D trading floor.
	Builds HUD UI, initializes controllers, wires StationController
	ProximityPrompts to open trade modal, connects all remotes.
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

-- Wire station interaction → open trade modal
StationController.OnInteract(function(coinId)
	MarketController.SelectCoin(coinId)
	TradeController.SetAction("BUY") -- reset to BUY on open
	TradeController.UpdateHoldingInfo()
	UIController.OpenTradeModal()
	-- Request chart data
	local hr = Remotes:FindFirstChild("CoinHistory")
	if hr then hr:FireServer(coinId) end
end)

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

-- Connect remotes
Remotes:WaitForChild("MarketSnapshot").OnClientEvent:Connect(function(snapshot)
	MarketController.UpdateMarket(snapshot)
	StationController.UpdatePrices(snapshot)
	TradeController.UpdateTopBar()
end)

Remotes:WaitForChild("CoinHistory").OnClientEvent:Connect(function(coinId, history)
	if coinId == MarketController.GetSelectedCoinId() then
		ChartRenderer.Draw(history)
	end
end)

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

-- Periodic chart refresh for selected coin (while modal is open)
task.spawn(function()
	while true do
		task.wait(2)
		if UIController.IsTradeModalOpen() then
			local coinId = MarketController.GetSelectedCoinId()
			if coinId then
				local hr = Remotes:FindFirstChild("CoinHistory")
				if hr then hr:FireServer(coinId) end
			end
		end
	end
end)

-- Escape key to close modal
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == Enum.KeyCode.Escape then
		if UIController.IsTradeModalOpen() then
			UIController.CloseTradeModal()
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
