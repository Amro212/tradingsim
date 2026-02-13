--[[
	TopBar.luau — Roact HUD component showing cash, portfolio value, and PnL.
	Floats at the top of the screen. Premium gradient background with centered layout.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Roact = require(ReplicatedStorage.Packages.Roact)

local Theme = require(script.Parent.Theme)
local Formatting = require(ReplicatedStorage.Shared.Formatting)

local TopBar = Roact.Component:extend("TopBar")

function TopBar:render()
	local state = self.props.store:getState()
	local C = Theme.colors
	local F = Theme.fonts
	local S = Theme.size

	return Roact.createElement("Frame", {
		Name = "TopBar",
		Size = UDim2.new(1, 0, 0, S.topBarHeight),
		Position = UDim2.new(0, 0, 0, 0),
		BackgroundColor3 = C.bg,
		BorderSizePixel = 0,
		ZIndex = 10,
	}, {
		-- Gradient overlay
		Gradient = Roact.createElement("UIGradient", Theme.gradients.topBar()),

		-- Bottom border glow
		Border = Roact.createElement("Frame", {
			Name = "Border",
			Size = UDim2.new(1, 0, 0, 1),
			Position = UDim2.new(0, 0, 1, 0),
			AnchorPoint = Vector2.new(0, 1),
			BackgroundColor3 = C.accent,
			BackgroundTransparency = 0.7,
			BorderSizePixel = 0,
		}),

		-- Centered content container
		Content = Roact.createElement("Frame", {
			Name = "Content",
			Size = UDim2.new(0, 720, 1, 0),
			Position = UDim2.new(0.5, 0, 0, 0),
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundTransparency = 1,
		}, {
			Layout = Roact.createElement("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				Padding = UDim.new(0, 16),
			}),

			-- Title
			Title = Roact.createElement("TextLabel", {
				Name = "Title",
				LayoutOrder = 1,
				Size = UDim2.new(0, 200, 0, 30),
				BackgroundTransparency = 1,
				FontFace = F.bold,
				TextSize = S.textXl,
				TextColor3 = C.gold,
				Text = "💹 MEMECOIN TRADER",
				TextXAlignment = Enum.TextXAlignment.Center,
			}),

			-- Divider
			Div1 = Roact.createElement("Frame", {
				LayoutOrder = 2,
				Size = UDim2.new(0, 1, 0, 24),
				BackgroundColor3 = C.border,
				BorderSizePixel = 0,
			}),

			-- Cash
			CashLabel = Roact.createElement("TextLabel", {
				LayoutOrder = 3,
				Size = UDim2.new(0, 55, 0, 24),
				BackgroundTransparency = 1,
				FontFace = F.light,
				TextSize = S.textSm,
				TextColor3 = C.textSecondary,
				Text = "💰 Cash",
				TextXAlignment = Enum.TextXAlignment.Right,
			}),
			CashValue = Roact.createElement("TextLabel", {
				LayoutOrder = 4,
				Size = UDim2.new(0, 110, 0, 24),
				BackgroundTransparency = 1,
				FontFace = F.bold,
				TextSize = S.textLg,
				TextColor3 = C.green,
				Text = Formatting.formatCash(state.cash),
				TextXAlignment = Enum.TextXAlignment.Left,
			}),

			-- Divider
			Div2 = Roact.createElement("Frame", {
				LayoutOrder = 5,
				Size = UDim2.new(0, 1, 0, 24),
				BackgroundColor3 = C.border,
				BorderSizePixel = 0,
			}),

			-- Portfolio
			PortLabel = Roact.createElement("TextLabel", {
				LayoutOrder = 6,
				Size = UDim2.new(0, 75, 0, 24),
				BackgroundTransparency = 1,
				FontFace = F.light,
				TextSize = S.textSm,
				TextColor3 = C.textSecondary,
				Text = "📊 Portfolio",
				TextXAlignment = Enum.TextXAlignment.Right,
			}),
			PortValue = Roact.createElement("TextLabel", {
				LayoutOrder = 7,
				Size = UDim2.new(0, 110, 0, 24),
				BackgroundTransparency = 1,
				FontFace = F.bold,
				TextSize = S.textLg,
				TextColor3 = C.textPrimary,
				Text = Formatting.formatCash(state.totalValue),
				TextXAlignment = Enum.TextXAlignment.Left,
			}),

			-- Divider
			Div3 = Roact.createElement("Frame", {
				LayoutOrder = 8,
				Size = UDim2.new(0, 1, 0, 24),
				BackgroundColor3 = C.border,
				BorderSizePixel = 0,
			}),

			-- PnL
			PnLLabel = Roact.createElement("TextLabel", {
				LayoutOrder = 9,
				Size = UDim2.new(0, 35, 0, 24),
				BackgroundTransparency = 1,
				FontFace = F.light,
				TextSize = S.textSm,
				TextColor3 = C.textSecondary,
				Text = "P&L",
				TextXAlignment = Enum.TextXAlignment.Right,
			}),
			PnLValue = Roact.createElement("TextLabel", {
				LayoutOrder = 10,
				Size = UDim2.new(0, 100, 0, 24),
				BackgroundTransparency = 1,
				FontFace = F.bold,
				TextSize = S.textLg,
				TextColor3 = state.totalPnL >= 0 and C.green or C.red,
				Text = Formatting.formatCash(state.totalPnL),
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
		}),
	})
end

return TopBar
