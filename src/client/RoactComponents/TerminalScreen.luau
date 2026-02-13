--[[
	TerminalScreen.luau — Roact SurfaceGui for trading terminal monitors.
	Shows top movers from the market snapshot (read-only display).
	Mounted on each terminal's Screen part in the Trading Terminal Row.
	WORLD_SPEC Station A: "Terminal screens show top movers."
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Roact = require(ReplicatedStorage.Packages.Roact)

local Theme = require(script.Parent.Theme)
local Formatting = require(ReplicatedStorage.Shared.Formatting)
local Coins = require(ReplicatedStorage.Shared.Coins)

local TerminalScreen = Roact.Component:extend("TerminalScreen")

local MAX_MOVERS = 4

function TerminalScreen:render()
	local store = self.props.store
	local state = store:getState()
	local C = Theme.colors
	local F = Theme.fonts

	-- Get top movers sorted by absolute change
	local sortedCoins = store:getSortedCoins()

	local children = {}

	-- Title bar
	children.Title = Roact.createElement("TextLabel", {
		Size = UDim2.new(1, 0, 0, 30),
		Position = UDim2.new(0, 0, 0, 8),
		BackgroundTransparency = 1,
		FontFace = F.bold,
		TextSize = 20,
		TextColor3 = C.gold,
		Text = "TOP MOVERS",
	})

	-- Accent line
	children.AccentLine = Roact.createElement("Frame", {
		Size = UDim2.new(0.7, 0, 0, 2),
		Position = UDim2.new(0.15, 0, 0, 40),
		BackgroundColor3 = C.accent,
		BorderSizePixel = 0,
	})

	-- Mover rows
	for i = 1, math.min(MAX_MOVERS, #sortedCoins) do
		local entry = sortedCoins[i]
		local coinDef = entry.def
		local data = entry.data
		local price = data.p or 0
		local changePct = data.cp or 0
		local changeColor = changePct >= 0 and C.green or C.red
		local yPos = 50 + (i - 1) * 48

		children["Mover_" .. i] = Roact.createElement("Frame", {
			Name = "Mover" .. i,
			Size = UDim2.new(0.9, 0, 0, 42),
			Position = UDim2.new(0.05, 0, 0, yPos),
			BackgroundColor3 = C.bgElevated,
			BackgroundTransparency = 0.5,
			BorderSizePixel = 0,
		}, {
			RCorner = Roact.createElement("UICorner", {
				CornerRadius = UDim.new(0, 4),
			}),
			-- Icon + Ticker
			CoinIcon = Roact.createElement("TextLabel", {
				Size = UDim2.new(0, 30, 0, 30),
				Position = UDim2.new(0, 6, 0.5, 0),
				AnchorPoint = Vector2.new(0, 0.5),
				BackgroundTransparency = 1,
				FontFace = F.bold,
				TextSize = 18,
				TextColor3 = C.textPrimary,
				Text = coinDef.icon,
			}),
			CoinTicker = Roact.createElement("TextLabel", {
				Size = UDim2.new(0, 60, 0, 20),
				Position = UDim2.new(0, 38, 0.5, 0),
				AnchorPoint = Vector2.new(0, 0.5),
				BackgroundTransparency = 1,
				FontFace = F.bold,
				TextSize = 14,
				TextColor3 = C.textPrimary,
				Text = coinDef.ticker,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
			-- Price
			PriceVal = Roact.createElement("TextLabel", {
				Size = UDim2.new(0.35, 0, 0, 18),
				Position = UDim2.new(0.38, 0, 0, 4),
				BackgroundTransparency = 1,
				FontFace = F.mono,
				TextSize = 13,
				TextColor3 = C.textPrimary,
				Text = Formatting.formatPrice(price),
				TextXAlignment = Enum.TextXAlignment.Right,
			}),
			-- Change %
			ChangeVal = Roact.createElement("TextLabel", {
				Size = UDim2.new(0.35, 0, 0, 16),
				Position = UDim2.new(0.38, 0, 0, 22),
				BackgroundTransparency = 1,
				FontFace = F.bold,
				TextSize = 12,
				TextColor3 = changeColor,
				Text = Formatting.formatPct(changePct),
				TextXAlignment = Enum.TextXAlignment.Right,
			}),
		})
	end

	-- "Press E to Trade" footer
	children.Footer = Roact.createElement("TextLabel", {
		Size = UDim2.new(1, 0, 0, 24),
		Position = UDim2.new(0, 0, 1, -30),
		BackgroundTransparency = 1,
		FontFace = F.medium,
		TextSize = 12,
		TextColor3 = C.accent,
		Text = "[E] Open Market",
	})

	return Roact.createElement("SurfaceGui", {
		Name = "TerminalGui",
		Face = Enum.NormalId.Front,
		SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud,
		PixelsPerStud = 50,
		ClipsDescendants = true,
	}, {
		BG = Roact.createElement("Frame", {
			Size = UDim2.new(1, 0, 1, 0),
			BackgroundColor3 = Color3.fromHex("#0B0E14"),
			BorderSizePixel = 0,
		}, children),
	})
end

return TerminalScreen
