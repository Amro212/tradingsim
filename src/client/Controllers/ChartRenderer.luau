--[[
	ChartRenderer.luau — TradingView-style candlestick chart renderer.
	Uses pooled UI Frames for candle bodies, wicks, volume bars,
	gridlines, price axis labels, time labels, and crosshair+tooltip.
	Receives OHLC candle data from the server (via MarketController).
	Event-driven rendering: only redraws on new data or timeframe change.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Formatting = require(ReplicatedStorage.Shared.Formatting)

local ChartRenderer = {}

-- Dependencies (set during Init)
local UIController = nil

-- State
local chartContainer: Frame? = nil
local isInitialized = false

-- Active candle data
local visibleCandles: {any} = {}
local activeTimeframe: string = Config.DEFAULT_TIMEFRAME
local _activeCoinId: string? = nil

-- Chart config shortcuts
local CHART = Config.CHART
local MAX_VISIBLE = CHART.MAX_VISIBLE_CANDLES

-------------------------------------------------
-- Cached layout values (recomputed on render)
-------------------------------------------------
local chartW = 0
local chartH = 0
local bodyWidth = CHART.CANDLE_BODY_WIDTH
local gap = CHART.CANDLE_GAP
local wickWidth = CHART.WICK_WIDTH
local padL = CHART.PADDING_LEFT
local padR = CHART.PADDING_RIGHT
local padT = CHART.PADDING_TOP
local padB = CHART.PADDING_BOTTOM
local volumeH = 0  -- computed from chartH

-------------------------------------------------
-- UI object pools
-------------------------------------------------
-- Candle pool: each entry = { container: Frame, wick: Frame, body: Frame }
local candlePool: {{ container: Frame, wick: Frame, body: Frame }} = {}
-- Volume bar pool
local volumePool: {Frame} = {}
-- Grid line pool (horizontal)
local gridLinePool: {Frame} = {}
-- Price label pool (right axis)
local priceLabelPool: {TextLabel} = {}
-- Time label pool (bottom axis)
local timeLabelPool: {TextLabel} = {}
-- Crosshair elements
local crosshairV: Frame = nil :: any
local crosshairH: Frame = nil :: any
local tooltip: Frame = nil :: any
local tooltipLabels: {[string]: TextLabel} = {}

-- Chart layers
local gridLayer: Frame = nil :: any
local candleLayer: Frame = nil :: any
local volumeLayer: Frame = nil :: any
local crosshairLayer: Frame = nil :: any
local axisLayerRight: Frame = nil :: any
local axisLayerBottom: Frame = nil :: any

-- Timeframe bar
local timeframeBar: Frame = nil :: any

-- Mouse tracking
local mouseConnection: RBXScriptConnection? = nil

-------------------------------------------------
-- Colors (from UIController, cached for perf)
-------------------------------------------------
local Colors = nil
local GREEN: Color3
local RED: Color3
local GRID_COLOR: Color3
local TEXT_DIM: Color3

-------------------------------------------------
-- NiceStep: pick a "pretty" step for gridlines
-------------------------------------------------
local NICE_STEPS = {
	0.00001, 0.00002, 0.00005,
	0.0001, 0.0002, 0.0005,
	0.001, 0.002, 0.005,
	0.01, 0.02, 0.05,
	0.1, 0.2, 0.5,
	1, 2, 5,
	10, 20, 50,
	100, 200, 500,
	1000, 2000, 5000,
}

local function niceStep(range: number, targetLines: number): number
	if range <= 0 then return 1 end
	local rough = range / targetLines
	for _, s in NICE_STEPS do
		if s >= rough then return s end
	end
	return NICE_STEPS[#NICE_STEPS]
end

-------------------------------------------------
-- Price → Y coordinate mapping
-------------------------------------------------
local scaleMinPrice = 0
local scaleMaxPrice = 1
local priceRange = 1
local candleAreaH = 0  -- chartH - padT - padB - volumeH

local function priceToY(price: number): number
	if priceRange <= 0 then return padT end
	return padT + candleAreaH * (1.0 - (price - scaleMinPrice) / priceRange)
end

-------------------------------------------------
-- Time formatting for labels
-------------------------------------------------
local function formatTimeLabel(tOpen: number, tfKey: string): string
	local tfSec = Config.TIMEFRAMES[tfKey] or 5
	if tfSec < 60 then
		-- seconds: show HH:MM:SS
		return Formatting.formatTime(tOpen)
	else
		-- minutes+: show HH:MM
		local h = math.floor(tOpen / 3600) % 24
		local m = math.floor(tOpen / 60) % 60
		return string.format("%02d:%02d", h, m)
	end
end

-------------------------------------------------
-- Create layered structure inside chartContainer
-------------------------------------------------
local function createLayers()
	if not chartContainer then return end
	local C = Colors

	-- Grid layer
	gridLayer = Instance.new("Frame")
	gridLayer.Name = "GridLayer"
	gridLayer.Size = UDim2.new(1, 0, 1, 0)
	gridLayer.BackgroundTransparency = 1
	gridLayer.ZIndex = 1
	gridLayer.Parent = chartContainer

	-- Volume layer (bottom region)
	volumeLayer = Instance.new("Frame")
	volumeLayer.Name = "VolumeLayer"
	volumeLayer.Size = UDim2.new(1, 0, 1, 0)
	volumeLayer.BackgroundTransparency = 1
	volumeLayer.ZIndex = 2
	volumeLayer.Parent = chartContainer

	-- Candle layer
	candleLayer = Instance.new("Frame")
	candleLayer.Name = "CandleLayer"
	candleLayer.Size = UDim2.new(1, 0, 1, 0)
	candleLayer.BackgroundTransparency = 1
	candleLayer.ZIndex = 3
	candleLayer.Parent = chartContainer

	-- Right axis (price labels)
	axisLayerRight = Instance.new("Frame")
	axisLayerRight.Name = "AxisRight"
	axisLayerRight.Size = UDim2.new(0, padR, 1, 0)
	axisLayerRight.Position = UDim2.new(1, -padR, 0, 0)
	axisLayerRight.BackgroundTransparency = 1
	axisLayerRight.ZIndex = 5
	axisLayerRight.Parent = chartContainer

	-- Bottom axis (time labels)
	axisLayerBottom = Instance.new("Frame")
	axisLayerBottom.Name = "AxisBottom"
	axisLayerBottom.Size = UDim2.new(1, -padR, 0, padB)
	axisLayerBottom.Position = UDim2.new(0, 0, 1, -padB)
	axisLayerBottom.BackgroundTransparency = 1
	axisLayerBottom.ZIndex = 5
	axisLayerBottom.Parent = chartContainer

	-- Crosshair layer
	crosshairLayer = Instance.new("Frame")
	crosshairLayer.Name = "CrosshairLayer"
	crosshairLayer.Size = UDim2.new(1, 0, 1, 0)
	crosshairLayer.BackgroundTransparency = 1
	crosshairLayer.ZIndex = 6
	crosshairLayer.Parent = chartContainer

	-- Vertical crosshair line
	crosshairV = Instance.new("Frame")
	crosshairV.Name = "CrossV"
	crosshairV.Size = UDim2.new(0, 1, 1, 0)
	crosshairV.BackgroundColor3 = C.textSecondary
	crosshairV.BackgroundTransparency = 0.5
	crosshairV.BorderSizePixel = 0
	crosshairV.Visible = false
	crosshairV.ZIndex = 7
	crosshairV.Parent = crosshairLayer

	-- Horizontal crosshair line
	crosshairH = Instance.new("Frame")
	crosshairH.Name = "CrossH"
	crosshairH.Size = UDim2.new(1, 0, 0, 1)
	crosshairH.BackgroundColor3 = C.textSecondary
	crosshairH.BackgroundTransparency = 0.5
	crosshairH.BorderSizePixel = 0
	crosshairH.Visible = false
	crosshairH.ZIndex = 7
	crosshairH.Parent = crosshairLayer

	-- Tooltip frame
	tooltip = Instance.new("Frame")
	tooltip.Name = "Tooltip"
	tooltip.Size = UDim2.new(0, CHART.TOOLTIP_WIDTH, 0, CHART.TOOLTIP_HEIGHT)
	tooltip.BackgroundColor3 = C.bgTertiary
	tooltip.BackgroundTransparency = 0.05
	tooltip.BorderSizePixel = 0
	tooltip.Visible = false
	tooltip.ZIndex = 10
	tooltip.Parent = crosshairLayer
	Instance.new("UICorner", tooltip).CornerRadius = UDim.new(0, 6)
	local ts = Instance.new("UIStroke", tooltip)
	ts.Color = C.border
	ts.Thickness = 1

	-- Tooltip labels
	local tooltipFields = { "Time", "Open", "High", "Low", "Close", "Change", "Volume" }
	for i, field in tooltipFields do
		local lbl = Instance.new("TextLabel")
		lbl.Name = field
		lbl.Size = UDim2.new(1, -12, 0, 13)
		lbl.Position = UDim2.new(0, 6, 0, 4 + (i - 1) * 13)
		lbl.BackgroundTransparency = 1
		lbl.FontFace = UIController.FONT_LIGHT
		lbl.TextSize = 10
		lbl.TextColor3 = C.textPrimary
		lbl.TextXAlignment = Enum.TextXAlignment.Left
		lbl.Text = ""
		lbl.ZIndex = 11
		lbl.Parent = tooltip
		tooltipLabels[field] = lbl
	end
end

-------------------------------------------------
-- Object pool creation
-------------------------------------------------
local function createCandlePool()
	if not candleLayer then return end
	local C = Colors
	for i = 1, MAX_VISIBLE do
		-- Container (transparent, positions the group)
		local container = Instance.new("Frame")
		container.Name = "C" .. i
		container.BackgroundTransparency = 1
		container.BorderSizePixel = 0
		container.Size = UDim2.new(0, bodyWidth, 0, 0)
		container.Visible = false
		container.ZIndex = 3
		container.Parent = candleLayer

		-- Wick
		local wick = Instance.new("Frame")
		wick.Name = "W"
		wick.BackgroundColor3 = C.green
		wick.BorderSizePixel = 0
		wick.AnchorPoint = Vector2.new(0.5, 0)
		wick.ZIndex = 3
		wick.Parent = container

		-- Body
		local body = Instance.new("Frame")
		body.Name = "B"
		body.BackgroundColor3 = C.green
		body.BorderSizePixel = 0
		body.AnchorPoint = Vector2.new(0, 0)
		body.ZIndex = 4
		body.Parent = container

		table.insert(candlePool, { container = container, wick = wick, body = body })
	end
end

local function createVolumePool()
	if not volumeLayer then return end
	local C = Colors
	for i = 1, MAX_VISIBLE do
		local bar = Instance.new("Frame")
		bar.Name = "V" .. i
		bar.BackgroundColor3 = C.green
		bar.BackgroundTransparency = 0.6
		bar.BorderSizePixel = 0
		bar.Visible = false
		bar.ZIndex = 2
		bar.Parent = volumeLayer
		table.insert(volumePool, bar)
	end
end

local function createGridPool()
	if not gridLayer then return end
	local MAX_GRID = 12
	for i = 1, MAX_GRID do
		local gl = Instance.new("Frame")
		gl.Name = "G" .. i
		gl.BackgroundColor3 = GRID_COLOR
		gl.BackgroundTransparency = 0.82
		gl.BorderSizePixel = 0
		gl.Size = UDim2.new(1, -padR, 0, 1)
		gl.Visible = false
		gl.ZIndex = 1
		gl.Parent = gridLayer
		table.insert(gridLinePool, gl)
	end
end

local function createPriceLabelPool()
	if not axisLayerRight then return end
	local MAX_LABELS = 12
	for i = 1, MAX_LABELS do
		local pl = Instance.new("TextLabel")
		pl.Name = "PL" .. i
		pl.Size = UDim2.new(1, -4, 0, 12)
		pl.BackgroundTransparency = 1
		pl.FontFace = UIController.FONT_LIGHT
		pl.TextSize = 9
		pl.TextColor3 = TEXT_DIM
		pl.TextXAlignment = Enum.TextXAlignment.Right
		pl.Text = ""
		pl.Visible = false
		pl.ZIndex = 5
		pl.Parent = axisLayerRight
		table.insert(priceLabelPool, pl)
	end
end

local function createTimeLabelPool()
	if not axisLayerBottom then return end
	local MAX_TIME_LABELS = 20
	for i = 1, MAX_TIME_LABELS do
		local tl = Instance.new("TextLabel")
		tl.Name = "TL" .. i
		tl.Size = UDim2.new(0, 50, 1, 0)
		tl.BackgroundTransparency = 1
		tl.FontFace = UIController.FONT_LIGHT
		tl.TextSize = 8
		tl.TextColor3 = TEXT_DIM
		tl.TextXAlignment = Enum.TextXAlignment.Center
		tl.Text = ""
		tl.Visible = false
		tl.ZIndex = 5
		tl.Parent = axisLayerBottom
		table.insert(timeLabelPool, tl)
	end
end

-------------------------------------------------
-- Build timeframe switcher bar (top of chart)
-------------------------------------------------
local function createTimeframeBar()
	if not chartContainer then return end
	local C = Colors

	timeframeBar = Instance.new("Frame")
	timeframeBar.Name = "TimeframeBar"
	timeframeBar.Size = UDim2.new(1, 0, 0, 22)
	timeframeBar.Position = UDim2.new(0, 0, 0, 0)
	timeframeBar.BackgroundColor3 = C.bgSecondary
	timeframeBar.BackgroundTransparency = 0.3
	timeframeBar.BorderSizePixel = 0
	timeframeBar.ZIndex = 8
	timeframeBar.Parent = chartContainer

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Padding = UDim.new(0, 2)
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Parent = timeframeBar

	-- Small L padding
	local padFrame = Instance.new("Frame")
	padFrame.Size = UDim2.new(0, 4, 1, 0)
	padFrame.BackgroundTransparency = 1
	padFrame.LayoutOrder = 0
	padFrame.Parent = timeframeBar

	for idx, tfKey in Config.TIMEFRAME_ORDER do
		local btn = Instance.new("TextButton")
		btn.Name = "TF_" .. tfKey
		btn.Size = UDim2.new(0, 36, 0, 18)
		btn.BackgroundColor3 = (tfKey == activeTimeframe) and C.accent or C.bgTertiary
		btn.BackgroundTransparency = (tfKey == activeTimeframe) and 0.1 or 0.5
		btn.BorderSizePixel = 0
		btn.FontFace = UIController.FONT
		btn.TextSize = 9
		btn.TextColor3 = (tfKey == activeTimeframe) and C.textPrimary or C.textSecondary
		btn.Text = tfKey
		btn.AutoButtonColor = false
		btn.ZIndex = 9
		btn.LayoutOrder = idx
		btn.Parent = timeframeBar
		Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)

		btn.MouseButton1Click:Connect(function()
			ChartRenderer.SetTimeframe(tfKey)
		end)
	end
end

-- Update timeframe button visuals
local function highlightTimeframeButton(tfKey: string)
	if not timeframeBar then return end
	local C = Colors
	for _, child in timeframeBar:GetChildren() do
		if child:IsA("TextButton") then
			local isSel = child.Name == "TF_" .. tfKey
			child.BackgroundColor3 = isSel and C.accent or C.bgTertiary
			child.BackgroundTransparency = isSel and 0.1 or 0.5
			child.TextColor3 = isSel and C.textPrimary or C.textSecondary
		end
	end
end

-------------------------------------------------
-- Initialize
-------------------------------------------------
function ChartRenderer.Init(uiCtrl)
	UIController = uiCtrl
	Colors = UIController.Colors
	GREEN = Colors.green
	RED = Colors.red
	GRID_COLOR = Colors.border
	TEXT_DIM = Colors.textSecondary

	chartContainer = UIController.GetElement("TradeOverlay.TradeModal.ChartContainer")
	if not chartContainer then
		warn("[ChartRenderer] ChartContainer not found!")
		return
	end

	-- Enable clipping
	chartContainer.ClipsDescendants = true

	-- Build internal layers and pools
	createLayers()
	createCandlePool()
	createVolumePool()
	createGridPool()
	createPriceLabelPool()
	createTimeLabelPool()
	createTimeframeBar()

	-- Wire mouse move for crosshair + tooltip
	setupCrosshair()

	isInitialized = true
end

-------------------------------------------------
-- Main rendering
-------------------------------------------------
function ChartRenderer.RenderCandles(candles: {any})
	if not isInitialized or not chartContainer then return end
	if not candles or #candles < 1 then
		ChartRenderer.Clear()
		return
	end

	-- Store visible candles (cap to MAX_VISIBLE)
	local count = math.min(#candles, MAX_VISIBLE)
	local startIdx = math.max(1, #candles - count + 1)
	visibleCandles = {}
	for i = startIdx, #candles do
		table.insert(visibleCandles, candles[i])
	end
	count = #visibleCandles

	-- Recompute chart dimensions
	local containerSize = chartContainer.AbsoluteSize
	chartW = containerSize.X
	chartH = containerSize.Y

	-- Adjust padT to account for timeframe bar
	local effectivePadT = padT + 24 -- timeframe bar height + gap
	volumeH = math.floor((chartH - effectivePadT - padB) * CHART.VOLUME_HEIGHT_PCT)
	candleAreaH = chartH - effectivePadT - padB - volumeH

	-- Dynamically size candle width based on available space
	local usableW = chartW - padL - padR
	local totalCandleWidth = count * (bodyWidth + gap) - gap
	if totalCandleWidth > usableW and count > 1 then
		-- Shrink to fit
		bodyWidth = math.max(3, math.floor((usableW - (count - 1) * 1) / count))
		gap = math.max(1, math.floor((usableW - count * bodyWidth) / math.max(count - 1, 1)))
	else
		bodyWidth = CHART.CANDLE_BODY_WIDTH
		gap = CHART.CANDLE_GAP
	end

	-- Compute min/max price with padding
	local minP, maxP = math.huge, -math.huge
	local maxVol = 0
	for _, c in visibleCandles do
		if c.low < minP then minP = c.low end
		if c.high > maxP then maxP = c.high end
		if c.volume > maxVol then maxVol = c.volume end
	end

	local range = maxP - minP
	if range < 0.000001 then range = maxP * 0.01; if range < 0.000001 then range = 1 end end
	local pad_price = range * CHART.PRICE_PADDING_PCT
	scaleMinPrice = minP - pad_price
	scaleMaxPrice = maxP + pad_price
	priceRange = scaleMaxPrice - scaleMinPrice

	-- Use the effective padT for price mapping
	local savedPadT = padT
	padT = effectivePadT

	-- ===== Draw gridlines + price labels =====
	drawGrid()

	-- ===== Draw candles =====
	for i = 1, count do
		local c = visibleCandles[i]
		local poolEntry = candlePool[i]
		if not poolEntry or not c then continue end

		local isBullish = c.close >= c.open
		local color = isBullish and GREEN or RED

		-- X position
		local x = padL + (i - 1) * (bodyWidth + gap)

		-- Wick: high → low
		local wickTop = priceToY(c.high)
		local wickBot = priceToY(c.low)
		local wickH = math.max(1, wickBot - wickTop)

		-- Body: open/close
		local bodyTopPrice = math.max(c.open, c.close)
		local bodyBotPrice = math.min(c.open, c.close)
		local bodyTop = priceToY(bodyTopPrice)
		local bodyBot = priceToY(bodyBotPrice)
		local bodyH = math.max(1, bodyBot - bodyTop)

		-- Container
		local cont = poolEntry.container
		cont.Position = UDim2.new(0, x, 0, 0)
		cont.Size = UDim2.new(0, bodyWidth, 1, 0)
		cont.Visible = true

		-- Wick
		local wick = poolEntry.wick
		wick.Size = UDim2.new(0, wickWidth, 0, wickH)
		wick.Position = UDim2.new(0.5, 0, 0, wickTop)
		wick.BackgroundColor3 = color

		-- Body
		local body = poolEntry.body
		body.Size = UDim2.new(1, 0, 0, bodyH)
		body.Position = UDim2.new(0, 0, 0, bodyTop)
		body.BackgroundColor3 = color
	end

	-- Hide unused candle pool entries
	for i = count + 1, MAX_VISIBLE do
		local entry = candlePool[i]
		if entry then entry.container.Visible = false end
	end

	-- ===== Draw volume bars =====
	drawVolume(count, maxVol)

	-- ===== Draw time labels =====
	drawTimeLabels(count)

	-- Restore padT
	padT = savedPadT
end

-------------------------------------------------
-- Draw horizontal gridlines + price labels
-------------------------------------------------
function drawGrid()
	local step = niceStep(priceRange, CHART.GRID_TARGET_LINES)
	local firstLine = math.ceil(scaleMinPrice / step) * step

	local lineIdx = 0
	local price = firstLine
	while price <= scaleMaxPrice and lineIdx < #gridLinePool do
		lineIdx = lineIdx + 1
		local gl = gridLinePool[lineIdx]
		local pl = priceLabelPool[lineIdx]
		local y = priceToY(price)

		gl.Position = UDim2.new(0, 0, 0, y)
		gl.Visible = true

		if pl then
			-- Format based on price magnitude
			local text
			if price >= 100 then
				text = string.format("%.2f", price)
			elseif price >= 1 then
				text = string.format("%.4f", price)
			else
				text = string.format("%.6f", price)
			end
			pl.Text = text
			pl.Position = UDim2.new(0, 0, 0, y - 6)
			pl.Visible = true
		end

		price = price + step
	end

	-- Hide unused
	for i = lineIdx + 1, #gridLinePool do
		gridLinePool[i].Visible = false
	end
	for i = lineIdx + 1, #priceLabelPool do
		priceLabelPool[i].Visible = false
	end
end

-------------------------------------------------
-- Draw volume bars aligned below candles
-------------------------------------------------
function drawVolume(count: number, maxVol: number)
	if maxVol <= 0 then
		for i = 1, MAX_VISIBLE do
			if volumePool[i] then volumePool[i].Visible = false end
		end
		return
	end

	local volTop = chartH - padB - volumeH
	for i = 1, count do
		local c = visibleCandles[i]
		local bar = volumePool[i]
		if not bar or not c then continue end

		local barH = math.max(1, math.floor((c.volume / maxVol) * volumeH))
		local x = padL + (i - 1) * (bodyWidth + gap)
		local isBullish = c.close >= c.open

		bar.Position = UDim2.new(0, x, 0, volTop + volumeH - barH)
		bar.Size = UDim2.new(0, bodyWidth, 0, barH)
		bar.BackgroundColor3 = isBullish and GREEN or RED
		bar.BackgroundTransparency = 0.65
		bar.Visible = true
	end

	for i = count + 1, MAX_VISIBLE do
		if volumePool[i] then volumePool[i].Visible = false end
	end
end

-------------------------------------------------
-- Draw bottom time labels
-------------------------------------------------
function drawTimeLabels(count: number)
	-- Determine label interval based on timeframe and candle count
	local labelEvery
	if count <= 30 then
		labelEvery = 5
	elseif count <= 60 then
		labelEvery = 10
	else
		labelEvery = 15
	end

	local labelIdx = 0
	for i = 1, count do
		if (i - 1) % labelEvery == 0 then
			labelIdx = labelIdx + 1
			local tl = timeLabelPool[labelIdx]
			if not tl then break end
			local c = visibleCandles[i]
			if c then
				tl.Text = formatTimeLabel(c.tOpen, activeTimeframe)
				local x = padL + (i - 1) * (bodyWidth + gap) + bodyWidth * 0.5 - 25
				tl.Position = UDim2.new(0, x, 0, 0)
				tl.Visible = true
			end
		end
	end

	for i = labelIdx + 1, #timeLabelPool do
		timeLabelPool[i].Visible = false
	end
end

-------------------------------------------------
-- Crosshair + Tooltip
-------------------------------------------------
function setupCrosshair()
	if not chartContainer then return end

	mouseConnection = chartContainer.InputChanged:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseMovement then return end
		if #visibleCandles == 0 then
			hideCrosshair()
			return
		end

		local absPos = chartContainer.AbsolutePosition
		local localX = input.Position.X - absPos.X
		local localY = input.Position.Y - absPos.Y

		-- Determine which candle is hovered
		local candleIdx = math.floor((localX - padL) / (bodyWidth + gap)) + 1
		candleIdx = math.clamp(candleIdx, 1, #visibleCandles)

		local candle = visibleCandles[candleIdx]
		if not candle then
			hideCrosshair()
			return
		end

		-- Vertical crosshair at candle center
		local cx = padL + (candleIdx - 1) * (bodyWidth + gap) + bodyWidth * 0.5
		if crosshairV then
			crosshairV.Position = UDim2.new(0, cx, 0, 0)
			crosshairV.Visible = true
		end

		-- Horizontal crosshair at mouse Y
		if crosshairH then
			crosshairH.Position = UDim2.new(0, 0, 0, localY)
			crosshairH.Visible = true
		end

		-- Update tooltip
		showTooltip(candle, cx, localY)
	end)

	-- Hide crosshair on mouse leave
	chartContainer.MouseLeave:Connect(function()
		hideCrosshair()
	end)
end

function showTooltip(candle: any, cx: number, cy: number)
	if not tooltip then return end

	-- Position tooltip (avoid going off-screen)
	local tx = cx + 12
	local ty = cy - 10
	if tx + CHART.TOOLTIP_WIDTH > chartW then
		tx = cx - CHART.TOOLTIP_WIDTH - 12
	end
	if ty + CHART.TOOLTIP_HEIGHT > chartH then
		ty = chartH - CHART.TOOLTIP_HEIGHT - 4
	end
	if ty < 0 then ty = 4 end

	tooltip.Position = UDim2.new(0, tx, 0, ty)
	tooltip.Visible = true

	-- Fill labels
	local changePct = candle.open ~= 0 and ((candle.close - candle.open) / candle.open) or 0
	local changeStr = Formatting.formatPct(changePct)

	tooltipLabels.Time.Text = "T: " .. formatTimeLabel(candle.tOpen, activeTimeframe)
	tooltipLabels.Open.Text = "O: " .. Formatting.formatPrice(candle.open)
	tooltipLabels.High.Text = "H: " .. Formatting.formatPrice(candle.high)
	tooltipLabels.Low.Text = "L: " .. Formatting.formatPrice(candle.low)
	tooltipLabels.Close.Text = "C: " .. Formatting.formatPrice(candle.close)

	local isUp = candle.close >= candle.open
	tooltipLabels.Change.Text = "Δ: " .. changeStr
	tooltipLabels.Change.TextColor3 = isUp and GREEN or RED

	tooltipLabels.Volume.Text = "Vol: " .. Formatting.shortNumber(candle.volume)
end

function hideCrosshair()
	if crosshairV then crosshairV.Visible = false end
	if crosshairH then crosshairH.Visible = false end
	if tooltip then tooltip.Visible = false end
end

-------------------------------------------------
-- Timeframe switching
-------------------------------------------------
function ChartRenderer.SetTimeframe(tfKey: string)
	if not Config.TIMEFRAMES[tfKey] then return end
	if tfKey == activeTimeframe then return end
	activeTimeframe = tfKey
	highlightTimeframeButton(tfKey)

	-- Request new candle data from server (via callback)
	if ChartRenderer._onTimeframeChanged then
		ChartRenderer._onTimeframeChanged(tfKey)
	end
end

function ChartRenderer.GetTimeframe(): string
	return activeTimeframe
end

-- Callback slot for init.client to wire
ChartRenderer._onTimeframeChanged = nil

-- Called when coin changes — resets state
function ChartRenderer.SetCoin(coinId: string)
	_activeCoinId = coinId
	visibleCandles = {}
	ChartRenderer.Clear()
end

-------------------------------------------------
-- Update only the last (live) candle (perf)
-------------------------------------------------
function ChartRenderer.UpdateLastCandle(candle: any)
	if not isInitialized or #visibleCandles == 0 then return end

	-- Replace the last candle in visibleCandles
	visibleCandles[#visibleCandles] = candle

	-- Full re-render since scaling might change
	-- (If perf becomes an issue, optimize to only update the last candle frame)
	ChartRenderer.RenderCandles(visibleCandles)
end

-------------------------------------------------
-- Append a finalized candle
-------------------------------------------------
function ChartRenderer.AppendCandle(candle: any)
	if not isInitialized then return end
	table.insert(visibleCandles, candle)
	-- Trim to max
	while #visibleCandles > MAX_VISIBLE do
		table.remove(visibleCandles, 1)
	end
	ChartRenderer.RenderCandles(visibleCandles)
end

-------------------------------------------------
-- Legacy Draw method — compatibility shim
-- Converts flat price array to fake candles for
-- any code still calling ChartRenderer.Draw(data)
-------------------------------------------------
function ChartRenderer.Draw(data: {number})
	if not isInitialized then return end
	if not data or #data < 2 then
		ChartRenderer.Clear()
		return
	end
	-- Convert to simple candles: each point becomes open=close=price, no wick spread
	local candles = {}
	for i, price in data do
		table.insert(candles, {
			tOpen = i,
			open = price,
			high = price,
			low = price,
			close = price,
			volume = 0,
		})
	end
	ChartRenderer.RenderCandles(candles)
end

-------------------------------------------------
-- Clear chart
-------------------------------------------------
function ChartRenderer.Clear()
	for _, entry in candlePool do
		entry.container.Visible = false
	end
	for _, bar in volumePool do
		bar.Visible = false
	end
	for _, gl in gridLinePool do
		gl.Visible = false
	end
	for _, pl in priceLabelPool do
		pl.Visible = false
	end
	for _, tl in timeLabelPool do
		tl.Visible = false
	end
	hideCrosshair()
end

-------------------------------------------------
-- Cleanup (call if switching screens, etc.)
-------------------------------------------------
function ChartRenderer.Cleanup()
	if mouseConnection then
		mouseConnection:Disconnect()
		mouseConnection = nil
	end
end

return ChartRenderer
