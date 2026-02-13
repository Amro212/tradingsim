--[[
	init.client.luau — Main client entry point (Roact version).
	Mounts Roact app tree, wires remotes to Store, handles stations.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")

local Roact = require(ReplicatedStorage.Packages.Roact)
local Coins = require(ReplicatedStorage.Shared.Coins)
local _Config = require(ReplicatedStorage.Shared.Config)

local player = Players.LocalPlayer

-- Roact components
local Components = script.RoactComponents
local App = require(Components.App)
local StationScreen = require(Components.StationScreen)
local StoreModule = require(Components.Store)

-- ChartRenderer (stays imperative, lives in Controllers/)
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

-- ═══════════════════════════════════════════════
-- Create Store (centralized state)
-- ═══════════════════════════════════════════════
local store = StoreModule.new()

-- ═══════════════════════════════════════════════
-- Initialize ChartRenderer (colors/fonts only, no container yet)
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

-- Callback: chart container ready from TradeModal Roact component
local function onChartReady(containerFrame: Frame)
	ChartRenderer.SetContainer(containerFrame)
	-- If we already have a coin selected, request candles
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
-- Station SurfaceGuis (Roact mounted on each 3D screen)
-- ═══════════════════════════════════════════════
local stationTrees = {}

local function mountStations()
	local floor = workspace:WaitForChild("TradingFloor", 30)
	if not floor then
		warn("[Client] TradingFloor not found!")
		return
	end

	for _, coinDef in Coins.List do
		local stationModel = floor:WaitForChild("Station_" .. coinDef.id, 15)
		if stationModel then
			local screen = stationModel:WaitForChild("Screen", 10)
			if screen and screen:GetAttribute("CoinId") then
				-- Mount Roact SurfaceGui
				local tree = Roact.mount(
					Roact.createElement(StationScreen, {
						store = store,
						coinDef = coinDef,
					}),
					screen,
					"StationGui"
				)
				table.insert(stationTrees, tree)

				-- Wire ProximityPrompt
				local prompt = screen:FindFirstChildOfClass("ProximityPrompt")
				if prompt then
					prompt.Triggered:Connect(function()
						store:selectCoin(coinDef.id)
						ChartRenderer.SetCoin(coinDef.id)
						requestCandles(coinDef.id, ChartRenderer.GetTimeframe())
					end)
				end
			else
				warn("[Client] Screen not found for station: " .. coinDef.id)
			end
		else
			warn("[Client] Station model not found: Station_" .. coinDef.id)
		end
	end
end

task.spawn(mountStations)

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

-- Legacy coin history (kept for backwards compat, unused with candles)
Remotes:WaitForChild("CoinHistory").OnClientEvent:Connect(function(_coinId, _history)
	-- No-op: candles take priority
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
-- Input handling
-- ═══════════════════════════════════════════════
local WALK_SPEED = 20
local SPRINT_SPEED = 36

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == Enum.KeyCode.Escape then
		if store:getState().tradeModalOpen then
			store:closeModal()
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
-- Start tutorial (delayed for initial load)
-- ═══════════════════════════════════════════════
task.delay(2, function()
	local state = store:getState()
	if not state.tutorialDone then
		tutorialStarted = true
		-- Re-render app with tutorial started
		Roact.update(appTree,
			Roact.createElement(App, {
				store = store,
				onChartReady = onChartReady,
				tutorialStarted = true,
			})
		)
	end
end)

-- ═══════════════════════════════════════════════
-- Bottom panel toggle (visible from start, positioned below screen)
-- ═══════════════════════════════════════════════
-- The toggle button is built into the BottomPanel Roact component.
-- No manual wiring needed — it dispatches store:toggleBottomPanel() directly.

print("[Client] Roact trading floor UI ready! Walk to a station and press E.")
