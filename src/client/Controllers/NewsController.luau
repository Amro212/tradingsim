--[[
	NewsController.luau — News/events feed tab.
	Listens to NewsEvent remote and renders scrolling headlines.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Formatting = require(ReplicatedStorage.Shared.Formatting)

local NewsController = {}
local UIController = nil
local newsItems: {Frame} = {}
local MAX_VISIBLE = 25

function NewsController.Init(uiCtrl)
	UIController = uiCtrl
end

function NewsController.AddEvent(eventData: {})
	local tab = UIController.GetElement("BottomPanel.TabContent.NewsTab")
	if not tab then return end
	local C = UIController.Colors

	local magColors = {
		pump = C.green, dump = C.red, crash = C.red, stabilize = C.accent,
	}

	local row = UIController.makeFrame({
		name = "News" .. #newsItems + 1,
		size = UDim2.new(1, -8, 0, 36), bg = C.bgTertiary, corner = 4,
	})
	row.LayoutOrder = -#newsItems

	UIController.makeLabel({
		name = "Headline", text = eventData.headline or "???",
		textSize = 11, color = magColors[eventData.magnitude] or C.textPrimary,
		size = UDim2.new(1, -8, 0, 20), pos = UDim2.new(0, 4, 0, 2), parent = row,
	})
	local timeStr = eventData.timestamp and Formatting.formatTime(eventData.timestamp) or ""
	UIController.makeLabel({
		name = "Time", text = timeStr .. " • " .. (eventData.coinId or ""),
		textSize = 9, color = C.textSecondary,
		size = UDim2.new(1, -8, 0, 14), pos = UDim2.new(0, 4, 0, 20), parent = row,
	})

	row.Parent = tab
	table.insert(newsItems, 1, row)
	while #newsItems > MAX_VISIBLE do
		local old = table.remove(newsItems)
		if old then old:Destroy() end
	end
end

function NewsController.LoadEvents(events: {})
	for i = #events, 1, -1 do
		NewsController.AddEvent(events[i])
	end
end

return NewsController
