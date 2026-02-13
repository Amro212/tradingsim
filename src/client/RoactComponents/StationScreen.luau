--[[
	StationScreen.luau — Roact SurfaceGui for each coin station's screen.
	Mounted on the 3D station Screen parts. Shows coin icon, name, price, change%.
	Wire ProximityPrompt → store dispatch.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Roact = require(ReplicatedStorage.Packages.Roact)

local Theme = require(script.Parent.Theme)
local Formatting = require(ReplicatedStorage.Shared.Formatting)

local StationScreen = Roact.Component:extend("StationScreen")

function StationScreen:render()
	local store = self.props.store
	local coinDef = self.props.coinDef
	local state = store:getState()
	local C = Theme.colors
	local F = Theme.fonts

	if not coinDef then return nil end

	local accentColor = Color3.new(
		coinDef.accentColor[1],
		coinDef.accentColor[2],
		coinDef.accentColor[3]
	)

	-- Get live price from store
	local data = state.marketData[coinDef.id]
	local price = data and data.p or coinDef.basePrice
	local changePct = data and data.cp or 0
	local priceColor = changePct >= 0 and C.green or C.red

	-- Risk tag colors
	local riskColors = { Low = C.green, Medium = C.gold, High = C.orange, Extreme = C.red }

	return Roact.createElement("SurfaceGui", {
		Name = "StationGui",
		Face = Enum.NormalId.Front,
		SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud,
		PixelsPerStud = 50,
		ClipsDescendants = true,
	}, {
		BG = Roact.createElement("Frame", {
			Size = UDim2.new(1, 0, 1, 0),
			BackgroundColor3 = Color3.fromHex("#0B0E14"),
			BorderSizePixel = 0,
		}, {
			-- Top accent line
			AccentTop = Roact.createElement("Frame", {
				Size = UDim2.new(0.8, 0, 0, 3),
				Position = UDim2.new(0.1, 0, 0, 8),
				BackgroundColor3 = accentColor,
				BorderSizePixel = 0,
			}),

			-- Coin Icon
			Icon = Roact.createElement("TextLabel", {
				Size = UDim2.new(1, 0, 0, 80),
				Position = UDim2.new(0, 0, 0, 20),
				BackgroundTransparency = 1,
				FontFace = F.bold,
				TextSize = 60,
				TextColor3 = C.textPrimary,
				Text = coinDef.icon,
			}),

			-- Coin Name
			CoinName = Roact.createElement("TextLabel", {
				Size = UDim2.new(1, 0, 0, 40),
				Position = UDim2.new(0, 0, 0, 100),
				BackgroundTransparency = 1,
				FontFace = F.bold,
				TextSize = 28,
				TextColor3 = C.textPrimary,
				Text = coinDef.name,
			}),

			-- Ticker
			Ticker = Roact.createElement("TextLabel", {
				Size = UDim2.new(1, 0, 0, 24),
				Position = UDim2.new(0, 0, 0, 138),
				BackgroundTransparency = 1,
				FontFace = F.medium,
				TextSize = 18,
				TextColor3 = accentColor,
				Text = coinDef.ticker,
			}),

			-- Price
			Price = Roact.createElement("TextLabel", {
				Size = UDim2.new(1, 0, 0, 50),
				Position = UDim2.new(0, 0, 0, 175),
				BackgroundTransparency = 1,
				FontFace = F.bold,
				TextSize = 36,
				TextColor3 = priceColor,
				Text = Formatting.formatPrice(price),
			}),

			-- Change %
			Change = Roact.createElement("TextLabel", {
				Size = UDim2.new(1, 0, 0, 30),
				Position = UDim2.new(0, 0, 0, 225),
				BackgroundTransparency = 1,
				FontFace = F.medium,
				TextSize = 20,
				TextColor3 = changePct >= 0 and C.green or C.red,
				Text = Formatting.formatPct(changePct),
			}),

			-- Risk tag
			Risk = Roact.createElement("TextLabel", {
				Size = UDim2.new(1, 0, 0, 22),
				Position = UDim2.new(0, 0, 0, 260),
				BackgroundTransparency = 1,
				FontFace = F.medium,
				TextSize = 14,
				TextColor3 = riskColors[coinDef.riskTag] or C.textSecondary,
				Text = coinDef.riskTag .. " Risk",
			}),

			-- Bottom accent line
			AccentBot = Roact.createElement("Frame", {
				Size = UDim2.new(0.6, 0, 0, 3),
				Position = UDim2.new(0.2, 0, 1, -10),
				BackgroundColor3 = accentColor,
				BorderSizePixel = 0,
			}),
		}),
	})
end

return StationScreen
