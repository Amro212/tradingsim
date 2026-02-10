--[[
	EventService.luau — Generates timed news events that affect coin prices.
	Events: InfluencerTweet (pump), WhaleSell (dump), ExchangeListing (pump),
	RugPull (crash), DevUpdate (stabilize).
	Broadcasts headlines to clients for the news feed.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local CoinsModule = require(ReplicatedStorage.Shared.Coins)

local EventService = {}

-- Dependencies (injected)
local MarketService = nil
local newsEventRemote: RemoteEvent = nil

-- RNG
local rng = Random.new(os.time() + 12345)

-- Event definitions
local EVENT_TYPES = {
	{
		type = "InfluencerTweet",
		headline = "🔥 Influencer just tweeted about %s! \"This is the future!\"",
		drift = 0.015,
		volMult = 1.8,
		duration = 12,
		magnitude = "pump",
	},
	{
		type = "WhaleSell",
		headline = "🐳 Whale alert! Massive %s sell-off detected!",
		drift = -0.02,
		volMult = 2.0,
		duration = 10,
		magnitude = "dump",
	},
	{
		type = "ExchangeListing",
		headline = "📈 BREAKING: %s listed on major exchange!",
		drift = 0.025,
		volMult = 1.5,
		duration = 15,
		magnitude = "pump",
	},
	{
		type = "RugPull",
		headline = "⚠️ ALERT: %s devs went silent. Liquidity dropping fast!",
		drift = -0.04,
		volMult = 3.0,
		duration = 8,
		magnitude = "crash",
	},
	{
		type = "DevUpdate",
		headline = "🛠️ %s team ships major update. Community bullish.",
		drift = 0.005,
		volMult = 0.5,
		duration = 20,
		magnitude = "stabilize",
	},
	{
		type = "CommunityHype",
		headline = "🚀 %s trending on social media! FOMO incoming!",
		drift = 0.012,
		volMult = 2.2,
		duration = 10,
		magnitude = "pump",
	},
	{
		type = "RegulationFUD",
		headline = "📋 Rumor: Regulators eyeing %s. Market nervous.",
		drift = -0.01,
		volMult = 1.6,
		duration = 14,
		magnitude = "dump",
	},
}

-- Active event log (for news feed history)
local eventLog = {} -- last N events
local MAX_EVENT_LOG = 30

-------------------------------------------------
-- Initialize
-------------------------------------------------
function EventService.Init(remotes: {[string]: any}, marketSvc: any)
	newsEventRemote = remotes.NewsEvent
	MarketService = marketSvc
end

-------------------------------------------------
-- Generate a random event
-------------------------------------------------
local function generateEvent()
	-- Pick random coin
	local coinList = CoinsModule.List
	local coin = coinList[rng:NextInteger(1, #coinList)]

	-- Pick random event type
	local evtDef = EVENT_TYPES[rng:NextInteger(1, #EVENT_TYPES)]

	-- Scale magnitude slightly randomly
	local scale = 0.7 + rng:NextNumber() * 0.6 -- 0.7 to 1.3

	-- Apply modifier to market
	MarketService.ApplyModifier(
		coin.id,
		evtDef.drift * scale,
		evtDef.volMult,
		evtDef.duration
	)

	-- Build event data
	local headline = string.format(evtDef.headline, coin.name)
	local eventData = {
		type = evtDef.type,
		coinId = coin.id,
		coinName = coin.name,
		headline = headline,
		magnitude = evtDef.magnitude,
		timestamp = workspace:GetServerTimeNow(),
	}

	-- Log it
	table.insert(eventLog, 1, eventData)
	if #eventLog > MAX_EVENT_LOG then
		table.remove(eventLog)
	end

	-- Broadcast to all clients
	newsEventRemote:FireAllClients(eventData)
end

-------------------------------------------------
-- Start event loop
-------------------------------------------------
function EventService.StartLoop()
	task.spawn(function()
		-- Initial delay before first event
		task.wait(5)
		while true do
			generateEvent()
			local interval = rng:NextInteger(
				Config.EVENT_MIN_INTERVAL,
				Config.EVENT_MAX_INTERVAL
			)
			task.wait(interval)
		end
	end)
end

-------------------------------------------------
-- Get recent events (for player joining mid-session)
-------------------------------------------------
function EventService.GetRecentEvents(): {}
	return eventLog
end

return EventService
