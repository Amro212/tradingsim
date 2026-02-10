--[[
	ChartRenderer.luau — Draws a line chart using Frame segments.
	Input: array of price points. Scales Y to min/max with padding.
	Redraws on new data; uses object pooling for performance.
]]

local TweenService = game:GetService("TweenService")

local ChartRenderer = {}

-- Dependencies
local UIController = nil

-- State
local chartContainer: Frame? = nil
local lineSegments: {Frame} = {}
local gridLines: {Frame} = {}
local priceLabels: {TextLabel} = {}
local currentData: {number} = {}

local MAX_SEGMENTS = 120
local LINE_THICKNESS = 2

-------------------------------------------------
-- Initialize
-------------------------------------------------
function ChartRenderer.Init(uiCtrl)
	UIController = uiCtrl
	chartContainer = UIController.GetElement("TradeOverlay.TradeModal.ChartContainer")

	if not chartContainer then
		warn("[ChartRenderer] ChartContainer not found!")
		return
	end

	-- Pre-create pooled line segments
	for i = 1, MAX_SEGMENTS do
		local seg = Instance.new("Frame")
		seg.Name = "Seg" .. i
		seg.BackgroundColor3 = UIController.Colors.accent
		seg.BorderSizePixel = 0
		seg.AnchorPoint = Vector2.new(0, 0.5)
		seg.Visible = false
		seg.ZIndex = 3
		seg.Parent = chartContainer
		table.insert(lineSegments, seg)
	end

	-- Create horizontal grid lines (5 levels)
	for i = 1, 5 do
		local gl = Instance.new("Frame")
		gl.Name = "Grid" .. i
		gl.BackgroundColor3 = UIController.Colors.border
		gl.BackgroundTransparency = 0.7
		gl.BorderSizePixel = 0
		gl.Size = UDim2.new(1, 0, 0, 1)
		gl.ZIndex = 1
		gl.Visible = false
		gl.Parent = chartContainer
		table.insert(gridLines, gl)

		-- Price label for each grid line
		local pl = UIController.makeLabel({
			name = "GridPrice" .. i,
			text = "",
			font = UIController.FONT_LIGHT,
			textSize = 9,
			color = UIController.Colors.textSecondary,
			size = UDim2.new(0, 60, 0, 14),
			pos = UDim2.new(1, -62, 0, 0),
			alignX = Enum.TextXAlignment.Right,
			parent = chartContainer,
		})
		pl.ZIndex = 4
		pl.Visible = false
		table.insert(priceLabels, pl)
	end
end

-------------------------------------------------
-- Draw the chart from price history data
-------------------------------------------------
function ChartRenderer.Draw(data: {number})
	if not chartContainer then return end
	if not data or #data < 2 then
		-- Hide all segments
		for _, seg in lineSegments do
			seg.Visible = false
		end
		return
	end

	currentData = data
	local Colors = UIController.Colors

	-- Calculate bounds
	local minP, maxP = math.huge, -math.huge
	for _, p in data do
		minP = math.min(minP, p)
		maxP = math.max(maxP, p)
	end

	-- Add padding (10%)
	local range = maxP - minP
	if range < 0.0001 then range = 1 end
	local padding = range * 0.1
	minP = minP - padding
	maxP = maxP + padding
	range = maxP - minP

	local containerSize = chartContainer.AbsoluteSize
	local w = containerSize.X - 70 -- leave room for price labels
	local h = containerSize.Y - 20  -- top/bottom margin

	local numPoints = math.min(#data, MAX_SEGMENTS + 1)
	local stepX = w / math.max(numPoints - 1, 1)

	-- Determine chart color based on trend
	local startPrice = data[math.max(1, #data - numPoints + 1)]
	local endPrice = data[#data]
	local chartColor = endPrice >= startPrice and Colors.green or Colors.red

	-- Draw line segments
	local startIdx = math.max(1, #data - numPoints + 1)
	for i = 1, numPoints - 1 do
		local seg = lineSegments[i]
		if not seg then break end

		local p1 = data[startIdx + i - 1]
		local p2 = data[startIdx + i]

		local x1 = (i - 1) * stepX + 10
		local y1 = h - ((p1 - minP) / range) * h + 10
		local x2 = i * stepX + 10
		local y2 = h - ((p2 - minP) / range) * h + 10

		local dx = x2 - x1
		local dy = y2 - y1
		local length = math.sqrt(dx * dx + dy * dy)
		local angle = math.atan2(dy, dx)

		seg.Size = UDim2.new(0, length, 0, LINE_THICKNESS)
		seg.Position = UDim2.new(0, x1, 0, y1)
		seg.Rotation = math.deg(angle)
		seg.BackgroundColor3 = chartColor
		seg.Visible = true
	end

	-- Hide unused segments
	for i = numPoints, MAX_SEGMENTS do
		lineSegments[i].Visible = false
	end

	-- Draw grid lines
	for i = 1, 5 do
		local gl = gridLines[i]
		local pl = priceLabels[i]
		local yFrac = (i - 1) / 4
		local price = minP + yFrac * range
		local yPos = h - yFrac * h + 10

		gl.Position = UDim2.new(0, 10, 0, yPos)
		gl.Size = UDim2.new(1, -80, 0, 1)
		gl.Visible = true

		pl.Text = string.format("%.4f", price)
		pl.Position = UDim2.new(1, -62, 0, yPos - 7)
		pl.Visible = true
	end
end

-------------------------------------------------
-- Clear chart
-------------------------------------------------
function ChartRenderer.Clear()
	for _, seg in lineSegments do
		seg.Visible = false
	end
	for _, gl in gridLines do
		gl.Visible = false
	end
	for _, pl in priceLabels do
		pl.Visible = false
	end
end

return ChartRenderer
