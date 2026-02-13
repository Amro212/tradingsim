--[[
	BottomPanel.luau — Toggleable bottom panel with Portfolio, History, and News tabs.
	Slides up/down with animation. Contains tab bar and tab content.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Roact = require(ReplicatedStorage.Packages.Roact)

local Theme = require(script.Parent.Theme)
local Formatting = require(ReplicatedStorage.Shared.Formatting)
local Coins = require(ReplicatedStorage.Shared.Coins)

local BottomPanel = Roact.Component:extend("BottomPanel")

function BottomPanel:init()
	self.panelRef = Roact.createRef()
	self._wasOpen = false
end

function BottomPanel:didUpdate()
	local state = self.props.store:getState()
	local panel = self.panelRef:getValue()
	if not panel then return end

	if state.bottomPanelOpen and not self._wasOpen then
		-- Slide up to reveal entire panel
		TweenService:Create(panel, Theme.animation.slideIn, {
			Position = UDim2.new(0, 0, 1, -Theme.size.panelHeight - 40),
		}):Play()
	elseif not state.bottomPanelOpen and self._wasOpen then
		-- Slide back down, but keep toggle button visible
		TweenService:Create(panel, Theme.animation.slideOut, {
			Position = UDim2.new(0, 0, 1, -40),
		}):Play()
	end
	self._wasOpen = state.bottomPanelOpen
end

-------------------------------------------------
-- Portfolio tab content
-------------------------------------------------
function BottomPanel:_renderPortfolioTab(state, C, F, S)
	local children = {}
	children.Layout = Roact.createElement("UIListLayout", {
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 3),
	})
	children.Pad = Roact.createElement("UIPadding", {
		PaddingTop = UDim.new(0, 4),
		PaddingLeft = UDim.new(0, 4),
		PaddingRight = UDim.new(0, 4),
	})

	-- Header row
	local cols = { "Coin", "Qty", "Avg Entry", "Price", "Value", "PnL" }
	local headerChildren = {}
	headerChildren.HLayout = Roact.createElement("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
	})
	for i, col in cols do
		headerChildren["H" .. i] = Roact.createElement("TextLabel", {
			LayoutOrder = i,
			Size = UDim2.new(1 / #cols, 0, 1, 0),
			BackgroundTransparency = 1,
			FontFace = F.bold,
			TextSize = S.textXs,
			TextColor3 = C.textSecondary,
			Text = col,
		})
	end

	children.Header = Roact.createElement("Frame", {
		Name = "Header",
		Size = UDim2.new(1, 0, 0, 22),
		BackgroundColor3 = C.bgElevated,
		BackgroundTransparency = 0.5,
		BorderSizePixel = 0,
		LayoutOrder = 0,
	}, headerChildren)

	-- Holdings rows
	local store = self.props.store
	local order = 1
	local hasHoldings = false
	for coinId, h in state.holdings do
		if h.qty <= 0.001 then continue end
		hasHoldings = true
		local def = Coins.ById[coinId]
		if not def then continue end
		local price = store:getCoinPrice(coinId)
		local value = h.qty * price
		local pnl = h.qty * (price - h.avgEntry)

		local vals = {
			def.icon .. " " .. def.ticker,
			Formatting.formatQty(h.qty),
			Formatting.formatPrice(h.avgEntry),
			Formatting.formatPrice(price),
			Formatting.formatCash(value),
			Formatting.formatCash(pnl),
		}
		local pnlColor = pnl >= 0 and C.green or C.red

		local rowChildren = {}
		rowChildren.RLayout = Roact.createElement("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
		})
		for i, val in vals do
			rowChildren["C" .. i] = Roact.createElement("TextLabel", {
				LayoutOrder = i,
				Size = UDim2.new(1 / #cols, 0, 1, 0),
				BackgroundTransparency = 1,
				FontFace = F.medium,
				TextSize = S.textSm - 1,
				TextColor3 = i == 6 and pnlColor or C.textPrimary,
				Text = val,
			})
		end

		children["Row_" .. coinId] = Roact.createElement("Frame", {
			Name = "Row_" .. coinId,
			Size = UDim2.new(1, 0, 0, 26),
			BackgroundColor3 = C.bgElevated,
			BackgroundTransparency = 0.7,
			BorderSizePixel = 0,
			LayoutOrder = order,
		}, rowChildren)

		order += 1
	end

	if not hasHoldings then
		children.Empty = Roact.createElement("TextLabel", {
			Size = UDim2.new(1, 0, 0, 40),
			BackgroundTransparency = 1,
			FontFace = F.light,
			TextSize = S.textSm,
			TextColor3 = C.textSecondary,
			Text = "No holdings yet. Walk to a station and start trading!",
			LayoutOrder = 1,
		})
	end

	return Roact.createElement("ScrollingFrame", {
		Name = "PortfolioTab",
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1,
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = C.border,
		CanvasSize = UDim2.new(0, 0, 0, math.max(200, order * 29 + 30)),
		BorderSizePixel = 0,
		Visible = state.activeTab == 1,
	}, children)
end

-------------------------------------------------
-- History tab content
-------------------------------------------------
function BottomPanel:_renderHistoryTab(state, C, F, S)
	local children = {}
	children.Layout = Roact.createElement("UIListLayout", {
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 2),
	})
	children.Pad = Roact.createElement("UIPadding", {
		PaddingTop = UDim.new(0, 4),
		PaddingLeft = UDim.new(0, 4),
		PaddingRight = UDim.new(0, 4),
	})

	for i, entry in state.tradeHistory do
		if i > 30 then break end
		local pnlStr = entry.pnl and (" PnL:" .. Formatting.formatCash(entry.pnl)) or ""
		local isBuy = entry.action == "BUY"
		local text = (isBuy and "🟢" or "🔴") .. " " .. entry.action .. " "
			.. Formatting.formatQty(entry.qty) .. " " .. (entry.coinId or "?")
			.. " @ " .. Formatting.formatPrice(entry.price or 0) .. pnlStr

		children["Trade" .. i] = Roact.createElement("TextLabel", {
			Size = UDim2.new(1, 0, 0, 22),
			BackgroundTransparency = 1,
			FontFace = F.medium,
			TextSize = S.textSm - 1,
			TextColor3 = isBuy and C.green or C.red,
			Text = text,
			TextXAlignment = Enum.TextXAlignment.Left,
			LayoutOrder = i,
		})
	end

	if #state.tradeHistory == 0 then
		children.Empty = Roact.createElement("TextLabel", {
			Size = UDim2.new(1, 0, 0, 40),
			BackgroundTransparency = 1,
			FontFace = F.light,
			TextSize = S.textSm,
			TextColor3 = C.textSecondary,
			Text = "No trades yet.",
			LayoutOrder = 1,
		})
	end

	return Roact.createElement("ScrollingFrame", {
		Name = "HistoryTab",
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1,
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = C.border,
		CanvasSize = UDim2.new(0, 0, 0, math.max(200, #state.tradeHistory * 24 + 10)),
		BorderSizePixel = 0,
		Visible = state.activeTab == 2,
	}, children)
end

-------------------------------------------------
-- News tab content
-------------------------------------------------
function BottomPanel:_renderNewsTab(state, C, F, S)
	local children = {}
	children.Layout = Roact.createElement("UIListLayout", {
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 3),
	})
	children.Pad = Roact.createElement("UIPadding", {
		PaddingTop = UDim.new(0, 4),
		PaddingLeft = UDim.new(0, 4),
		PaddingRight = UDim.new(0, 4),
	})

	local magColors = {
		pump = C.green, dump = C.red, crash = C.red, stabilize = C.accent,
	}

	for i, ev in state.newsEvents do
		if i > 25 then break end
		children["News" .. i] = Roact.createElement("Frame", {
			Name = "News" .. i,
			Size = UDim2.new(1, 0, 0, 38),
			BackgroundColor3 = C.bgElevated,
			BackgroundTransparency = 0.6,
			BorderSizePixel = 0,
			LayoutOrder = i,
		}, {
			NCorner = Roact.createElement("UICorner", {
				CornerRadius = UDim.new(0, Theme.size.cornerRadiusSm),
			}),
			Headline = Roact.createElement("TextLabel", {
				Size = UDim2.new(1, -8, 0, 20),
				Position = UDim2.new(0, 6, 0, 2),
				BackgroundTransparency = 1,
				FontFace = F.medium,
				TextSize = S.textSm - 1,
				TextColor3 = magColors[ev.magnitude] or C.textPrimary,
				Text = ev.headline or "???",
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
			TimeCoin = Roact.createElement("TextLabel", {
				Size = UDim2.new(1, -8, 0, 14),
				Position = UDim2.new(0, 6, 0, 22),
				BackgroundTransparency = 1,
				FontFace = F.light,
				TextSize = S.textXs,
				TextColor3 = C.textMuted,
				Text = (ev.timestamp and Formatting.formatTime(ev.timestamp) or "")
					.. " • " .. (ev.coinId or ""),
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
		})
	end

	if #state.newsEvents == 0 then
		children.Empty = Roact.createElement("TextLabel", {
			Size = UDim2.new(1, 0, 0, 40),
			BackgroundTransparency = 1,
			FontFace = F.light,
			TextSize = S.textSm,
			TextColor3 = C.textSecondary,
			Text = "No market events yet...",
			LayoutOrder = 1,
		})
	end

	return Roact.createElement("ScrollingFrame", {
		Name = "NewsTab",
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1,
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = C.border,
		CanvasSize = UDim2.new(0, 0, 0, math.max(200, #state.newsEvents * 41 + 10)),
		BorderSizePixel = 0,
		Visible = state.activeTab == 3,
	}, children)
end

function BottomPanel:render()
	local store = self.props.store
	local state = store:getState()
	local C = Theme.colors
	local F = Theme.fonts
	local S = Theme.size

	local tabNames = { "📊 Portfolio", "📜 History", "📰 News" }

	-- Tab buttons
	local tabBtns = {}
	tabBtns.TabLayout = Roact.createElement("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 2),
	})

	for i, name in tabNames do
		local isActive = state.activeTab == i
		tabBtns["Tab" .. i] = Roact.createElement("TextButton", {
			LayoutOrder = i,
			Size = UDim2.new(1 / #tabNames, -2, 1, -4),
			BackgroundColor3 = isActive and C.bgElevated or C.bgCard,
			BackgroundTransparency = isActive and 0 or 0.5,
			BorderSizePixel = 0,
			FontFace = isActive and F.bold or F.medium,
			TextSize = S.textSm,
			TextColor3 = isActive and C.textPrimary or C.textSecondary,
			Text = name,
			[Roact.Event.MouseButton1Click] = function()
				store:setActiveTab(i)
			end,
		}, {
			Corner = Roact.createElement("UICorner", {
				CornerRadius = UDim.new(0, S.cornerRadiusSm),
			}),
		})
	end

	return Roact.createElement("Frame", {
		Name = "BottomPanelWrapper",
		Size = UDim2.new(1, 0, 0, S.panelHeight + 40), -- extra for toggle button
		Position = UDim2.new(0, 0, 1, -40), -- only toggle button visible
		BackgroundTransparency = 1,
		ZIndex = 20,
		[Roact.Ref] = self.panelRef,
	}, {
		-- Toggle button (always visible above panel)
		ToggleBtn = Roact.createElement("TextButton", {
			Name = "ToggleBtn",
			Size = UDim2.new(0, 140, 0, 32),
			Position = UDim2.new(0.5, 0, 0, 0),
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundColor3 = C.bgCard,
			BorderSizePixel = 0,
			FontFace = F.medium,
			TextSize = S.textSm,
			TextColor3 = C.textSecondary,
			Text = state.bottomPanelOpen and "▼ Close Panel" or "▲ Portfolio",
			[Roact.Event.MouseButton1Click] = function()
				store:toggleBottomPanel()
			end,
		}, {
			Corner = Roact.createElement("UICorner", {
				CornerRadius = UDim.new(0, S.cornerRadius),
			}),
			Stroke = Roact.createElement("UIStroke", {
				Color = C.border,
				Thickness = 1,
				Transparency = 0.4,
			}),
		}),

		-- Main panel
		Panel = Roact.createElement("Frame", {
			Name = "Panel",
			Size = UDim2.new(1, 0, 0, S.panelHeight),
			Position = UDim2.new(0, 0, 0, 36),
			BackgroundColor3 = C.bg,
			BorderSizePixel = 0,
		}, {
			Corner = Roact.createElement("UICorner", {
				CornerRadius = UDim.new(0, S.cornerRadiusLg),
			}),
			Stroke = Roact.createElement("UIStroke", {
				Color = C.border,
				Thickness = 1,
				Transparency = 0.3,
			}),
			Gradient = Roact.createElement("UIGradient", Theme.gradients.topBar()),

			-- Top border accent
			TopBorder = Roact.createElement("Frame", {
				Size = UDim2.new(0.6, 0, 0, 2),
				Position = UDim2.new(0.2, 0, 0, 0),
				BackgroundColor3 = C.accent,
				BackgroundTransparency = 0.6,
				BorderSizePixel = 0,
			}),

			-- Tab bar
			TabBar = Roact.createElement("Frame", {
				Name = "TabBar",
				Size = UDim2.new(1, -16, 0, 32),
				Position = UDim2.new(0, 8, 0, 8),
				BackgroundTransparency = 1,
			}, tabBtns),

			-- Tab content area
			TabContent = Roact.createElement("Frame", {
				Name = "TabContent",
				Size = UDim2.new(1, -16, 1, -50),
				Position = UDim2.new(0, 8, 0, 44),
				BackgroundTransparency = 1,
				ClipsDescendants = true,
			}, {
				PortfolioTab = self:_renderPortfolioTab(state, C, F, S),
				HistoryTab = self:_renderHistoryTab(state, C, F, S),
				NewsTab = self:_renderNewsTab(state, C, F, S),
			}),
		}),
	})
end

return BottomPanel
