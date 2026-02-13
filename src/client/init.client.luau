--[[
	init.client.luau — Main client entry point (Roact version).
	Mounts Roact app tree, wires remotes to Store, handles terminal interactions.
	M1: Terminal Row opens MarketList; selecting a coin opens TradeModal.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")

local Roact = require(ReplicatedStorage.Packages.Roact)
local _Config = require(ReplicatedStorage.Shared.Config)

local player = Players.LocalPlayer

-- Roact components
local Components = script.RoactComponents
local App = require(Components.App)
local TerminalScreen = require(Components.TerminalScreen)
local StoreModule = require(Components.Store)

-- ChartRenderer (imperative, lives in Controllers/)
local ChartRenderer = require(script.Controllers.ChartRenderer)

-- ═══════════════════════════════════════════════
-- Wait for remotes
-- ═══════════════════════════════════════════════
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

-- ═══════════════════════════════════════════════
-- Create ScreenGui
-- ═══════════════════════════════════════════════
local screenGui = player.PlayerGui:WaitForChild("TradingUI", 10) :: ScreenGui
if not screenGui then
	local gui = Instance.new("ScreenGui")
	gui.Name = "TradingUI"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = 10
	gui.Parent = player.PlayerGui
	screenGui = gui
end

-- ═══════════════════════════════════════════════
-- Create Store (centralized state)
-- ═══════════════════════════════════════════════
local store = StoreModule.new()

-- ═══════════════════════════════════════════════
-- Initialize ChartRenderer
-- ═══════════════════════════════════════════════
ChartRenderer.Init()

-- ═══════════════════════════════════════════════
-- Candle request helper
-- ═══════════════════════════════════════════════
local function requestCandles(coinId: string, timeframe: string)
	local remote = Remotes:FindFirstChild("RequestCandles")
	if remote then
		remote:FireServer(coinId, timeframe, 200)
	end
end

-- Callback: chart container ready from TradeModal
local function onChartReady(containerFrame: Frame)
	ChartRenderer.SetContainer(containerFrame)
	local state = store:getState()
	if state.selectedCoinId then
		requestCandles(state.selectedCoinId, ChartRenderer.GetTimeframe())
	end
end

-- ═══════════════════════════════════════════════
-- Mount Roact App
-- ═══════════════════════════════════════════════
local tutorialStarted = false

local appTree = Roact.mount(
	Roact.createElement(App, {
		store = store,
		onChartReady = onChartReady,
		tutorialStarted = tutorialStarted,
	}),
	screenGui,
	"AppRoot"
)

-- ═══════════════════════════════════════════════
-- M1: Mount TerminalScreen SurfaceGuis on terminal monitors
-- Wire ProximityPrompts to open Trading UI (market list)
-- ═══════════════════════════════════════════════
local terminalScreenTrees = {}

local function mountTerminals()
	local floor = workspace:WaitForChild("TradingFloor", 30)
	if not floor then
		warn("[Client] TradingFloor not found!")
		return
	end

	-- Find all terminal models and their screens
	for _, child in floor:GetChildren() do
		if child:IsA("Model") and child.Name:match("^Terminal_") then
			-- Find the Screen part
			local screen = child:FindFirstChild("Screen")
			if screen and screen:GetAttribute("IsTerminal") then
				-- Mount SurfaceGui showing top movers
				local tree = Roact.mount(
					Roact.createElement(TerminalScreen, {
						store = store,
					}),
					screen,
					"TerminalGui"
				)
				table.insert(terminalScreenTrees, tree)

				-- Wire ProximityPrompt → open Trading UI (generic, not coin-specific)
				local prompt = screen:FindFirstChildOfClass("ProximityPrompt")
				if prompt then
					prompt.Triggered:Connect(function()
						store:openTradingUI()
					end)
				end
			end
		end
	end

	print("[Client] Mounted " .. #terminalScreenTrees .. " terminal screens")
end

task.spawn(mountTerminals)

-- ═══════════════════════════════════════════════
-- Wire timeframe switching
-- ═══════════════════════════════════════════════
ChartRenderer._onTimeframeChanged = function(newTf: string)
	local coinId = store:getState().selectedCoinId
	if coinId then
		ChartRenderer.Clear()
		requestCandles(coinId, newTf)
	end
end

-- ═══════════════════════════════════════════════
-- Watch for coin selection → request candles
-- ═══════════════════════════════════════════════
local lastSelectedCoinId = nil
store:subscribe(function()
	local state = store:getState()
	if state.selectedCoinId and state.selectedCoinId ~= lastSelectedCoinId then
		lastSelectedCoinId = state.selectedCoinId
		ChartRenderer.SetCoin(state.selectedCoinId)
		requestCandles(state.selectedCoinId, ChartRenderer.GetTimeframe())
	end
	if not state.tradeModalOpen then
		lastSelectedCoinId = nil
	end
end)

-- ═══════════════════════════════════════════════
-- Request initial state from server
-- ═══════════════════════════════════════════════
print("[Client] Requesting initial state...")
local initRemote = Remotes:FindFirstChild("GetInitialState")
if initRemote then
	local ok, result = pcall(function() return initRemote:InvokeServer() end)
	if ok and result and not result.error then
		if result.playerState then
			store:setPlayerState(result.playerState)
		end
		if result.marketSnapshot then
			store:updateMarket(result.marketSnapshot)
		end
		if result.recentEvents then
			store:loadNewsEvents(result.recentEvents)
		end
		print("[Client] Initial state loaded!")
	else
		warn("[Client] Failed to get initial state:", result)
	end
end

-- ═══════════════════════════════════════════════
-- Connect remotes → Store dispatches
-- ═══════════════════════════════════════════════

-- Market snapshots
Remotes:WaitForChild("MarketSnapshot").OnClientEvent:Connect(function(snapshot)
	store:updateMarket(snapshot)
end)

-- OHLC Candle history batch
local candleHistoryRemote = Remotes:WaitForChild("CandleHistory", 10)
if candleHistoryRemote then
	candleHistoryRemote.OnClientEvent:Connect(function(coinId, timeframe, candles)
		local state = store:getState()
		if coinId ~= state.selectedCoinId then return end
		if timeframe ~= ChartRenderer.GetTimeframe() then return end
		ChartRenderer.RenderCandles(candles)
	end)
end

-- Live candle update
local candleUpdateRemote = Remotes:WaitForChild("CandleUpdate", 10)
if candleUpdateRemote then
	candleUpdateRemote.OnClientEvent:Connect(function(coinId, timeframe, candle)
		local state = store:getState()
		if coinId ~= state.selectedCoinId then return end
		if timeframe ~= ChartRenderer.GetTimeframe() then return end
		if not state.tradeModalOpen then return end
		ChartRenderer.UpdateLastCandle(candle)
	end)
end

-- Finalized candle append
local candleAppendRemote = Remotes:WaitForChild("CandleAppend", 10)
if candleAppendRemote then
	candleAppendRemote.OnClientEvent:Connect(function(coinId, timeframe, candle)
		local state = store:getState()
		if coinId ~= state.selectedCoinId then return end
		if timeframe ~= ChartRenderer.GetTimeframe() then return end
		ChartRenderer.AppendCandle(candle)
	end)
end

-- Trade results
Remotes:WaitForChild("TradeResult").OnClientEvent:Connect(function(result)
	store:onTradeResult(result)
end)

-- Player state updates
Remotes:WaitForChild("PlayerState").OnClientEvent:Connect(function(state)
	store:setPlayerState(state)
end)

-- News events
Remotes:WaitForChild("NewsEvent").OnClientEvent:Connect(function(eventData)
	store:addNewsEvent(eventData)
end)

-- Legacy coin history (no-op, candles take priority)
Remotes:WaitForChild("CoinHistory").OnClientEvent:Connect(function(_coinId, _history)
end)

-- ═══════════════════════════════════════════════
-- Periodic candle refresh while modal is open
-- ═══════════════════════════════════════════════
task.spawn(function()
	while true do
		task.wait(10)
		local state = store:getState()
		if state.tradeModalOpen and state.selectedCoinId then
			requestCandles(state.selectedCoinId, ChartRenderer.GetTimeframe())
		end
	end
end)

-- ═══════════════════════════════════════════════
-- Input handling (ESC closes UI layers in order)
-- ═══════════════════════════════════════════════
local WALK_SPEED = 20
local SPRINT_SPEED = 36

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == Enum.KeyCode.Escape then
		local state = store:getState()
		if state.tradeModalOpen then
			-- Close trade modal → back to market list
			store:closeModal()
		elseif state.tradingUIOpen then
			-- Close market list → back to walking
			store:closeTradingUI()
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

-- ═══════════════════════════════════════════════
-- Tutorial (delayed for initial load)
-- ═══════════════════════════════════════════════
task.delay(2, function()
	local state = store:getState()
	if not state.tutorialDone then
		tutorialStarted = true
		Roact.update(appTree,
			Roact.createElement(App, {
				store = store,
				onChartReady = onChartReady,
				tutorialStarted = true,
			})
		)
	end
end)

print("[Client] TradingSim UI ready — walk to a terminal and press E.")
