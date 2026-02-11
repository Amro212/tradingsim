--[[
	init.server.luau — Main server entry point.
	Creates RemoteEvents, initializes all services, builds 3D trading floor,
	wires remote handlers, and starts simulation loops.
	Characters are FREE to walk around the trading floor.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

-- =============================================
-- 1) Create Remotes folder and events
-- =============================================
local Remotes = Instance.new("Folder")
Remotes.Name = "Remotes"
Remotes.Parent = ReplicatedStorage

local function makeRemote(className: string, name: string): Instance
	local r = Instance.new(className)
	r.Name = name
	r.Parent = Remotes
	return r
end

local remotes = {
	RequestTrade    = makeRemote("RemoteEvent", "RequestTrade"),
	MarketSnapshot  = makeRemote("RemoteEvent", "MarketSnapshot"),
	CoinHistory     = makeRemote("RemoteEvent", "CoinHistory"),
	TradeResult     = makeRemote("RemoteEvent", "TradeResult"),
	NewsEvent       = makeRemote("RemoteEvent", "NewsEvent"),
	PlayerState     = makeRemote("RemoteEvent", "PlayerState"),
	GetInitialState = makeRemote("RemoteFunction", "GetInitialState"),
	-- Candlestick chart remotes
	RequestCandles  = makeRemote("RemoteEvent", "RequestCandles"),
	CandleHistory   = makeRemote("RemoteEvent", "CandleHistory"),
	CandleUpdate    = makeRemote("RemoteEvent", "CandleUpdate"),
	CandleAppend    = makeRemote("RemoteEvent", "CandleAppend"),
	-- Tutorial
	TutorialDone    = makeRemote("RemoteEvent", "TutorialDone"),
}

-- =============================================
-- 2) Require services
-- =============================================
local Services = ServerScriptService.Server.Services
local SaveService   = require(Services.SaveService)
local PlayerService = require(Services.PlayerService)
local MarketService = require(Services.MarketService)
local EventService  = require(Services.EventService)
local TradeService  = require(Services.TradeService)
local TradingFloor  = require(ServerScriptService.Server.TradingFloor)

-- =============================================
-- 3) Initialize services (dependency order)
-- =============================================
SaveService.Init()
PlayerService.Init(remotes, SaveService)
MarketService.Init(remotes)
EventService.Init(remotes, MarketService)
TradeService.Init(remotes, MarketService, PlayerService)

print("[Server] All services initialized.")

-- Wally proof: verify package management works
local wallyProof = require(ReplicatedStorage.Shared.WallyProof)
print("[Server] ✓ Wally packages loaded successfully:", wallyProof)

-- =============================================
-- 4) Build the 3D trading floor
-- =============================================
local _floorModel, _stations = TradingFloor.Build()
print("[Server] Trading floor built.")

-- =============================================
-- 5) Wire remote handlers
-- =============================================

-- Trade requests: validate and execute server-side
remotes.RequestTrade.OnServerEvent:Connect(function(player, action, coinId, qty)
	TradeService.ExecuteTrade(player, action, coinId, qty)
end)

-- Tutorial done: client tells server when tutorial is completed
remotes.TutorialDone.OnServerEvent:Connect(function(player)
	local state = PlayerService.GetState(player)
	if state then
		state.tutorialDone = true
	end
end)

-- Initial state request: client calls once on load
remotes.GetInitialState.OnServerInvoke = function(player)
	local retries = 0
	while not PlayerService.GetState(player) and retries < 20 do
		task.wait(0.25)
		retries = retries + 1
	end

	local pState = PlayerService.GetState(player)
	if not pState then
		return { error = "Data not ready" }
	end

	return {
		playerState = {
			cash = pState.cash,
			holdings = pState.holdings,
			stats = pState.stats,
			cosmetics = pState.cosmetics,
			tutorialDone = pState.tutorialDone,
			tradeHistory = pState.tradeHistory,
		},
		marketSnapshot = MarketService.GetFullSnapshot(),
		recentEvents = EventService.GetRecentEvents(),
	}
end

-- =============================================
-- 6) Player lifecycle — characters walk freely
-- =============================================
Players.PlayerAdded:Connect(function(player)
	PlayerService.OnPlayerAdded(player)

	-- Set up character for trading floor
	player.CharacterAdded:Connect(function(character)
		task.defer(function()
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if humanoid then
				humanoid.WalkSpeed = 20   -- normal walk speed
				humanoid.JumpPower = 50   -- normal jump
			end
		end)
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	PlayerService.OnPlayerRemoving(player)
end)

-- Handle existing players (if script loads late)
for _, player in Players:GetPlayers() do
	task.spawn(function()
		PlayerService.OnPlayerAdded(player)
	end)
end

-- =============================================
-- 7) Shutdown handler
-- =============================================
game:BindToClose(function()
	PlayerService.OnServerShutdown()
end)

-- =============================================
-- 8) Start loops
-- =============================================
MarketService.StartLoop()
EventService.StartLoop()
PlayerService.StartAutosave()

print("[Server] Trading simulator running! Walk around and trade!")
