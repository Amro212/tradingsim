--[[
	StationController.luau — Manages SurfaceGuis on 3D station screens.
	Creates live displays (coin name, price, change) on each station.
	Handles ProximityPrompt interaction to open the trade panel.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Coins = require(ReplicatedStorage.Shared.Coins)
local Formatting = require(ReplicatedStorage.Shared.Formatting)

local StationController = {}

local UIController = nil
local screenGuis: {[string]: SurfaceGui} = {}
local priceLabels: {[string]: TextLabel} = {}
local changeLabels: {[string]: TextLabel} = {}
local lastPrices: {[string]: number} = {}
local onInteractCallbacks: {(string) -> ()} = {}

function StationController.Init(uiCtrl)
	UIController = uiCtrl

	-- Find all station screens in workspace
	local floor = workspace:WaitForChild("TradingFloor", 30)
	if not floor then
		warn("[StationController] TradingFloor not found!")
		return
	end

	for _, child in floor:GetDescendants() do
		if child:IsA("BasePart") and child:GetAttribute("CoinId") then
			local coinId = child:GetAttribute("CoinId")
			local coinDef = Coins.ById[coinId]
			if coinDef then
				StationController._createScreenGui(child, coinDef)
				StationController._wirePrompt(child, coinId)
			end
		end
	end
end

function StationController._createScreenGui(screenPart: Part, coinDef)
	local C = UIController.Colors
	local accentColor = Color3.new(coinDef.accentColor[1], coinDef.accentColor[2], coinDef.accentColor[3])

	local gui = Instance.new("SurfaceGui")
	gui.Name = "StationGui"
	gui.Adornee = screenPart
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 50
	gui.ClipsDescendants = true
	gui.Parent = screenPart

	-- Background
	local bg = Instance.new("Frame")
	bg.Name = "BG"
	bg.Size = UDim2.new(1, 0, 1, 0)
	bg.BackgroundColor3 = Color3.fromRGB(8, 8, 20)
	bg.BorderSizePixel = 0
	bg.Parent = gui

	-- Coin icon
	local icon = Instance.new("TextLabel")
	icon.Name = "Icon"
	icon.Size = UDim2.new(1, 0, 0, 80)
	icon.Position = UDim2.new(0, 0, 0, 20)
	icon.BackgroundTransparency = 1
	icon.FontFace = Font.fromName("GothamSSm", Enum.FontWeight.Bold)
	icon.TextSize = 60
	icon.TextColor3 = C.textPrimary
	icon.Text = coinDef.icon
	icon.Parent = bg

	-- Coin name
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "CoinName"
	nameLabel.Size = UDim2.new(1, 0, 0, 40)
	nameLabel.Position = UDim2.new(0, 0, 0, 100)
	nameLabel.BackgroundTransparency = 1
	nameLabel.FontFace = Font.fromName("GothamSSm", Enum.FontWeight.Bold)
	nameLabel.TextSize = 28
	nameLabel.TextColor3 = C.textPrimary
	nameLabel.Text = coinDef.name
	nameLabel.Parent = bg

	-- Ticker
	local ticker = Instance.new("TextLabel")
	ticker.Name = "Ticker"
	ticker.Size = UDim2.new(1, 0, 0, 24)
	ticker.Position = UDim2.new(0, 0, 0, 138)
	ticker.BackgroundTransparency = 1
	ticker.FontFace = Font.fromName("GothamSSm", Enum.FontWeight.Medium)
	ticker.TextSize = 18
	ticker.TextColor3 = accentColor
	ticker.Text = coinDef.ticker
	ticker.Parent = bg

	-- Price (large)
	local price = Instance.new("TextLabel")
	price.Name = "Price"
	price.Size = UDim2.new(1, 0, 0, 50)
	price.Position = UDim2.new(0, 0, 0, 175)
	price.BackgroundTransparency = 1
	price.FontFace = Font.fromName("GothamSSm", Enum.FontWeight.Bold)
	price.TextSize = 36
	price.TextColor3 = C.green
	price.Text = Formatting.formatPrice(coinDef.basePrice)
	price.Parent = bg
	priceLabels[coinDef.id] = price

	-- Change %
	local change = Instance.new("TextLabel")
	change.Name = "Change"
	change.Size = UDim2.new(1, 0, 0, 30)
	change.Position = UDim2.new(0, 0, 0, 225)
	change.BackgroundTransparency = 1
	change.FontFace = Font.fromName("GothamSSm", Enum.FontWeight.Medium)
	change.TextSize = 20
	change.TextColor3 = C.textSecondary
	change.Text = "+0.00%"
	change.Parent = bg
	changeLabels[coinDef.id] = change

	-- Risk tag
	local riskColors = { Low = C.green, Medium = C.gold, High = C.orange, Extreme = C.red }
	local risk = Instance.new("TextLabel")
	risk.Name = "Risk"
	risk.Size = UDim2.new(1, 0, 0, 22)
	risk.Position = UDim2.new(0, 0, 0, 260)
	risk.BackgroundTransparency = 1
	risk.FontFace = Font.fromName("GothamSSm", Enum.FontWeight.Medium)
	risk.TextSize = 14
	risk.TextColor3 = riskColors[coinDef.riskTag] or C.textSecondary
	risk.Text = coinDef.riskTag .. " Risk"
	risk.Parent = bg

	-- Accent line
	local accentLine = Instance.new("Frame")
	accentLine.Name = "AccentLine"
	accentLine.Size = UDim2.new(0.6, 0, 0, 3)
	accentLine.Position = UDim2.new(0.2, 0, 1, -10)
	accentLine.BackgroundColor3 = accentColor
	accentLine.BorderSizePixel = 0
	accentLine.Parent = bg

	screenGuis[coinDef.id] = gui
end

function StationController._wirePrompt(screenPart: Part, coinId: string)
	local prompt = screenPart:FindFirstChildOfClass("ProximityPrompt")
	if not prompt then return end

	prompt.Triggered:Connect(function()
		for _, cb in onInteractCallbacks do
			cb(coinId)
		end
	end)
end

-------------------------------------------------
-- Update prices from market snapshot
-------------------------------------------------
function StationController.UpdatePrices(snapshot: {})
	local C = UIController.Colors
	for _, coinData in snapshot.coins do
		local id = coinData.id
		local pl = priceLabels[id]
		if pl then
			pl.Text = Formatting.formatPrice(coinData.p)
			-- Flash color on change
			local lastP = lastPrices[id]
			if lastP and lastP ~= coinData.p then
				local flashColor = coinData.p > lastP and C.green or C.red
				pl.TextColor3 = flashColor
				task.delay(0.4, function()
					if pl.Parent then pl.TextColor3 = C.textPrimary end
				end)
			end
			lastPrices[id] = coinData.p
		end
		local cl = changeLabels[id]
		if cl then
			cl.Text = Formatting.formatPct(coinData.cp)
			cl.TextColor3 = coinData.cp >= 0 and C.green or C.red
		end
	end
end

function StationController.OnInteract(callback: (string) -> ())
	table.insert(onInteractCallbacks, callback)
end

return StationController
