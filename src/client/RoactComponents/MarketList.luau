--[[
	MarketList.luau — Full-screen market overview showing all coins.
	Opened when player interacts with a Trading Terminal (Station A).
	Shows: coin icon, name/ticker, meta, phase, price, 24h change, volume.
	Clicking a row opens the TradeModal for that coin.
	M1 core component: §4 Step 1, WORLD_SPEC Station A.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Roact = require(ReplicatedStorage.Packages.Roact)

local Theme = require(script.Parent.Theme)
local Formatting = require(ReplicatedStorage.Shared.Formatting)
local Coins = require(ReplicatedStorage.Shared.Coins)

local MarketList = Roact.Component:extend("MarketList")

-- Phase badge colors
local PHASE_COLORS = {
	STEALTH      = Color3.fromHex("#4F8EF7"),
	HYPE         = Color3.fromHex("#00D68F"),
	DISTRIBUTION = Color3.fromHex("#FF8C42"),
	DEAD         = Color3.fromHex("#7A84A0"),
	BLUECHIP     = Color3.fromHex("#FFD32A"),
}

-- Meta badge colors
local META_COLORS = {
	AI             = Color3.fromHex("#6BA3FF"),
	Animals        = Color3.fromHex("#FF8C42"),
	Gaming         = Color3.fromHex("#B388FF"),
	Memes          = Color3.fromHex("#00D68F"),
	ParodyPolitics = Color3.fromHex("#FF4757"),
	Seasonal       = Color3.fromHex("#FFD32A"),
}

-------------------------------------------------
-- Build a single coin row
-------------------------------------------------
function MarketList:_renderCoinRow(coinDef, coinData, layoutOrder: number)
	local C = Theme.colors
	local F = Theme.fonts
	local S = Theme.size
	local store = self.props.store

	local price = coinData and coinData.p or coinDef.basePrice
	local changePct = coinData and coinData.cp or 0
	local volume = coinData and coinData.v or 0
	local meta = coinData and coinData.m or coinDef.meta or "?"
	local phase = coinData and coinData.ph or coinDef.initialPhase or "HYPE"
	local changeColor = changePct >= 0 and C.green or C.red
	local phaseColor = PHASE_COLORS[phase] or C.textSecondary
	local metaColor = META_COLORS[meta] or C.textSecondary

	return Roact.createElement("TextButton", {
		Name = "Row_" .. coinDef.id,
		Size = UDim2.new(1, -8, 0, 44),
		BackgroundColor3 = C.bgElevated,
		BackgroundTransparency = 0.4,
		BorderSizePixel = 0,
		LayoutOrder = layoutOrder,
		AutoButtonColor = false,
		Text = "",
		[Roact.Event.MouseButton1Click] = function()
			store:selectCoin(coinDef.id)
		end,
		[Roact.Event.MouseEnter] = function(rbx)
			rbx.BackgroundTransparency = 0.1
		end,
		[Roact.Event.MouseLeave] = function(rbx)
			rbx.BackgroundTransparency = 0.4
		end,
	}, {
		Corner = Roact.createElement("UICorner", {
			CornerRadius = UDim.new(0, S.cornerRadiusSm),
		}),
		Padding = Roact.createElement("UIPadding", {
			PaddingLeft = UDim.new(0, 12),
			PaddingRight = UDim.new(0, 12),
		}),

		-- Icon + Name + Ticker (left section)
		CoinInfo = Roact.createElement("Frame", {
			Size = UDim2.new(0.28, 0, 1, 0),
			Position = UDim2.new(0, 0, 0, 0),
			BackgroundTransparency = 1,
		}, {
			Icon = Roact.createElement("TextLabel", {
				Size = UDim2.new(0, 26, 1, 0),
				Position = UDim2.new(0, 0, 0, 0),
				BackgroundTransparency = 1,
				FontFace = F.bold,
				TextSize = 18,
				TextColor3 = C.textPrimary,
				Text = coinDef.icon,
			}),
			NameTicker = Roact.createElement("TextLabel", {
				Size = UDim2.new(1, -30, 0, 22),
				Position = UDim2.new(0, 30, 0, 3),
				BackgroundTransparency = 1,
				FontFace = F.bold,
				TextSize = S.textMd,
				TextColor3 = C.textPrimary,
				Text = coinDef.name,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
			}),
			Ticker = Roact.createElement("TextLabel", {
				Size = UDim2.new(1, -30, 0, 16),
				Position = UDim2.new(0, 30, 0, 24),
				BackgroundTransparency = 1,
				FontFace = F.light,
				TextSize = S.textXs,
				TextColor3 = C.textSecondary,
				Text = coinDef.ticker,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
		}),

		-- Meta badge
		MetaBadge = Roact.createElement("Frame", {
			Size = UDim2.new(0.12, 0, 0, 22),
			Position = UDim2.new(0.28, 0, 0.5, 0),
			AnchorPoint = Vector2.new(0, 0.5),
			BackgroundColor3 = metaColor,
			BackgroundTransparency = 0.75,
			BorderSizePixel = 0,
		}, {
			MCorner = Roact.createElement("UICorner", {
				CornerRadius = UDim.new(0, 4),
			}),
			MStroke = Roact.createElement("UIStroke", {
				Color = metaColor,
				Thickness = 1,
				Transparency = 0.4,
			}),
			MLabel = Roact.createElement("TextLabel", {
				Size = UDim2.new(1, 0, 1, 0),
				BackgroundTransparency = 1,
				FontFace = F.medium,
				TextSize = S.textXs,
				TextColor3 = metaColor,
				Text = meta,
			}),
		}),

		-- Phase badge
		PhaseBadge = Roact.createElement("Frame", {
			Size = UDim2.new(0.12, 0, 0, 22),
			Position = UDim2.new(0.41, 0, 0.5, 0),
			AnchorPoint = Vector2.new(0, 0.5),
			BackgroundColor3 = phaseColor,
			BackgroundTransparency = 0.75,
			BorderSizePixel = 0,
		}, {
			PCorner = Roact.createElement("UICorner", {
				CornerRadius = UDim.new(0, 4),
			}),
			PStroke = Roact.createElement("UIStroke", {
				Color = phaseColor,
				Thickness = 1,
				Transparency = 0.4,
			}),
			PLabel = Roact.createElement("TextLabel", {
				Size = UDim2.new(1, 0, 1, 0),
				BackgroundTransparency = 1,
				FontFace = F.medium,
				TextSize = S.textXs,
				TextColor3 = phaseColor,
				Text = phase,
			}),
		}),

		-- Price
		PriceLabel = Roact.createElement("TextLabel", {
			Size = UDim2.new(0.15, 0, 1, 0),
			Position = UDim2.new(0.54, 0, 0, 0),
			BackgroundTransparency = 1,
			FontFace = F.mono,
			TextSize = S.textMd,
			TextColor3 = C.textPrimary,
			Text = Formatting.formatPrice(price),
			TextXAlignment = Enum.TextXAlignment.Right,
		}),

		-- Change %
		ChangeLabel = Roact.createElement("TextLabel", {
			Size = UDim2.new(0.13, 0, 1, 0),
			Position = UDim2.new(0.70, 0, 0, 0),
			BackgroundTransparency = 1,
			FontFace = F.bold,
			TextSize = S.textMd,
			TextColor3 = changeColor,
			Text = Formatting.formatPct(changePct),
			TextXAlignment = Enum.TextXAlignment.Right,
		}),

		-- Volume
		VolumeLabel = Roact.createElement("TextLabel", {
			Size = UDim2.new(0.14, 0, 1, 0),
			Position = UDim2.new(0.84, 0, 0, 0),
			BackgroundTransparency = 1,
			FontFace = F.medium,
			TextSize = S.textSm,
			TextColor3 = C.textSecondary,
			Text = Formatting.shortNumber(volume),
			TextXAlignment = Enum.TextXAlignment.Right,
		}),
	})
end

-------------------------------------------------
-- Render the full market list
-------------------------------------------------
function MarketList:render()
	local store = self.props.store
	local state = store:getState()
	local C = Theme.colors
	local F = Theme.fonts
	local S = Theme.size

	-- Only visible when trading UI is open (and no trade modal covering it)
	if not state.tradingUIOpen then
		return nil
	end

	-- Build sorted coin rows (top movers first)
	local sortedCoins = store:getSortedCoins()
	local rows = {}

	rows.Layout = Roact.createElement("UIListLayout", {
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 4),
	})
	rows.Pad = Roact.createElement("UIPadding", {
		PaddingTop = UDim.new(0, 4),
		PaddingLeft = UDim.new(0, 4),
		PaddingRight = UDim.new(0, 4),
	})

	for i, entry in sortedCoins do
		rows["Coin_" .. entry.def.id] = self:_renderCoinRow(entry.def, entry.data, i)
	end

	-- If no market data yet, show coins from definitions
	if #sortedCoins == 0 then
		for i, coinDef in Coins.List do
			rows["Coin_" .. coinDef.id] = self:_renderCoinRow(coinDef, nil, i)
		end
	end

	local rowCount = math.max(#sortedCoins, #Coins.List)

	return Roact.createElement("Frame", {
		Name = "MarketListOverlay",
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundColor3 = C.overlay,
		BackgroundTransparency = 0.3,
		BorderSizePixel = 0,
		ZIndex = 40,
	}, {
		Panel = Roact.createElement("Frame", {
			Name = "MarketPanel",
			Size = UDim2.new(0, 700, 0, 540),
			Position = UDim2.new(0.5, 0, 0.5, 0),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = C.bg,
			BorderSizePixel = 0,
			ZIndex = 41,
		}, {
			Corner = Roact.createElement("UICorner", {
				CornerRadius = UDim.new(0, S.cornerRadiusLg),
			}),
			Stroke = Roact.createElement("UIStroke", {
				Color = C.border,
				Thickness = S.strokeThickness,
				Transparency = 0.3,
			}),
			Gradient = Roact.createElement("UIGradient", Theme.gradients.card()),

			-- ═══════════════════════════════════════
			-- HEADER
			-- ═══════════════════════════════════════
			Header = Roact.createElement("Frame", {
				Name = "Header",
				Size = UDim2.new(1, 0, 0, 50),
				BackgroundTransparency = 1,
				ZIndex = 42,
			}, {
				Title = Roact.createElement("TextLabel", {
					Size = UDim2.new(0.5, 0, 0, 30),
					Position = UDim2.new(0, 20, 0, 10),
					BackgroundTransparency = 1,
					FontFace = F.bold,
					TextSize = S.textXl,
					TextColor3 = C.gold,
					Text = "MARKET",
					TextXAlignment = Enum.TextXAlignment.Left,
					ZIndex = 42,
				}),
				CloseBtn = Roact.createElement("TextButton", {
					Size = UDim2.new(0, 36, 0, 36),
					Position = UDim2.new(1, -14, 0, 8),
					AnchorPoint = Vector2.new(1, 0),
					BackgroundColor3 = C.bgElevated,
					BorderSizePixel = 0,
					FontFace = F.bold,
					TextSize = S.textLg,
					TextColor3 = C.textSecondary,
					Text = "\u{2715}",
					ZIndex = 42,
					[Roact.Event.MouseButton1Click] = function()
						store:closeTradingUI()
					end,
				}, {
					BtnCorner = Roact.createElement("UICorner", {
						CornerRadius = UDim.new(0, S.cornerRadius),
					}),
				}),
				Divider = Roact.createElement("Frame", {
					Size = UDim2.new(1, -24, 0, 1),
					Position = UDim2.new(0, 12, 1, 0),
					AnchorPoint = Vector2.new(0, 1),
					BackgroundColor3 = C.border,
					BackgroundTransparency = 0.5,
					BorderSizePixel = 0,
					ZIndex = 42,
				}),
			}),

			-- ═══════════════════════════════════════
			-- COLUMN HEADERS
			-- ═══════════════════════════════════════
			ColumnHeaders = Roact.createElement("Frame", {
				Name = "ColumnHeaders",
				Size = UDim2.new(1, -24, 0, 28),
				Position = UDim2.new(0, 12, 0, 52),
				BackgroundTransparency = 1,
				ZIndex = 42,
			}, {
				HPad = Roact.createElement("UIPadding", {
					PaddingLeft = UDim.new(0, 12),
					PaddingRight = UDim.new(0, 12),
				}),
				Col1 = Roact.createElement("TextLabel", {
					Size = UDim2.new(0.28, 0, 1, 0),
					Position = UDim2.new(0, 0, 0, 0),
					BackgroundTransparency = 1,
					FontFace = F.bold,
					TextSize = S.textXs,
					TextColor3 = C.textMuted,
					Text = "COIN",
					TextXAlignment = Enum.TextXAlignment.Left,
				}),
				Col2 = Roact.createElement("TextLabel", {
					Size = UDim2.new(0.12, 0, 1, 0),
					Position = UDim2.new(0.28, 0, 0, 0),
					BackgroundTransparency = 1,
					FontFace = F.bold,
					TextSize = S.textXs,
					TextColor3 = C.textMuted,
					Text = "META",
				}),
				Col3 = Roact.createElement("TextLabel", {
					Size = UDim2.new(0.12, 0, 1, 0),
					Position = UDim2.new(0.41, 0, 0, 0),
					BackgroundTransparency = 1,
					FontFace = F.bold,
					TextSize = S.textXs,
					TextColor3 = C.textMuted,
					Text = "PHASE",
				}),
				Col4 = Roact.createElement("TextLabel", {
					Size = UDim2.new(0.15, 0, 1, 0),
					Position = UDim2.new(0.54, 0, 0, 0),
					BackgroundTransparency = 1,
					FontFace = F.bold,
					TextSize = S.textXs,
					TextColor3 = C.textMuted,
					Text = "PRICE",
					TextXAlignment = Enum.TextXAlignment.Right,
				}),
				Col5 = Roact.createElement("TextLabel", {
					Size = UDim2.new(0.13, 0, 1, 0),
					Position = UDim2.new(0.70, 0, 0, 0),
					BackgroundTransparency = 1,
					FontFace = F.bold,
					TextSize = S.textXs,
					TextColor3 = C.textMuted,
					Text = "CHG %",
					TextXAlignment = Enum.TextXAlignment.Right,
				}),
				Col6 = Roact.createElement("TextLabel", {
					Size = UDim2.new(0.14, 0, 1, 0),
					Position = UDim2.new(0.84, 0, 0, 0),
					BackgroundTransparency = 1,
					FontFace = F.bold,
					TextSize = S.textXs,
					TextColor3 = C.textMuted,
					Text = "VOLUME",
					TextXAlignment = Enum.TextXAlignment.Right,
				}),
			}),

			-- ═══════════════════════════════════════
			-- SCROLLABLE COIN LIST
			-- ═══════════════════════════════════════
			CoinList = Roact.createElement("ScrollingFrame", {
				Name = "CoinList",
				Size = UDim2.new(1, -24, 1, -90),
				Position = UDim2.new(0, 12, 0, 82),
				BackgroundTransparency = 1,
				ScrollBarThickness = 4,
				ScrollBarImageColor3 = C.border,
				CanvasSize = UDim2.new(0, 0, 0, rowCount * 48 + 16),
				BorderSizePixel = 0,
				ZIndex = 42,
			}, rows),
		}),
	})
end

return MarketList
