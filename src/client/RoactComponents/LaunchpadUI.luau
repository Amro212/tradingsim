--[[
	LaunchpadUI.luau — Full-screen launchpad overlay (ScreenGui).
	Shows countdown, recent launches list, and deep-link to coin chart.
	Opened when player interacts with Station B (Launchpad Stage).
	WORLD_SPEC Station B: "Interact with stage: opens Launchpad UI."
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Roact = require(ReplicatedStorage.Packages.Roact)

local Theme = require(script.Parent.Theme)
local Formatting = require(ReplicatedStorage.Shared.Formatting)

local LaunchpadUI = Roact.Component:extend("LaunchpadUI")

local ACCENT = Color3.fromHex("#FF5078")

local PHASE_COLORS = {
	STEALTH      = Color3.fromHex("#4F8EF7"),
	HYPE         = Color3.fromHex("#00D68F"),
	DISTRIBUTION = Color3.fromHex("#FF8C42"),
	DEAD         = Color3.fromHex("#7A84A0"),
	BLUECHIP     = Color3.fromHex("#FFD32A"),
}

local META_COLORS = {
	AI             = Color3.fromHex("#6BA3FF"),
	Animals        = Color3.fromHex("#FF8C42"),
	Gaming         = Color3.fromHex("#B388FF"),
	Memes          = Color3.fromHex("#00D68F"),
	ParodyPolitics = Color3.fromHex("#FF4757"),
	Seasonal       = Color3.fromHex("#FFD32A"),
}

local function formatCountdown(seconds: number): string
	if seconds <= 0 then return "LAUNCHING..." end
	local m = math.floor(seconds / 60)
	local s = seconds % 60
	if m > 0 then
		return string.format("%d:%02d", m, s)
	end
	return string.format("0:%02d", s)
end

function LaunchpadUI:_renderLaunchRow(entry: any, layoutOrder: number)
	local C = Theme.colors
	local F = Theme.fonts
	local S = Theme.size
	local store = self.props.store
	local state = store:getState()

	local coinId = entry.coinId
	local data = state.marketData[coinId]
	local price = data and data.p or entry.basePrice or 0
	local changePct = data and data.cp or 0
	local phase = data and data.ph or "STEALTH"
	local changeColor = changePct >= 0 and C.green or C.red
	local metaColor = META_COLORS[entry.meta] or C.textSecondary
	local phaseColor = PHASE_COLORS[phase] or C.textSecondary

	return Roact.createElement("TextButton", {
		Name = "Launch_" .. coinId,
		Size = UDim2.new(1, -8, 0, 52),
		BackgroundColor3 = C.bgElevated,
		BackgroundTransparency = 0.4,
		BorderSizePixel = 0,
		LayoutOrder = layoutOrder,
		AutoButtonColor = false,
		Text = "",
		[Roact.Event.MouseButton1Click] = function()
			store:deepLinkCoin(coinId)
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

		-- Icon
		Icon = Roact.createElement("TextLabel", {
			Size = UDim2.new(0, 28, 1, 0),
			Position = UDim2.new(0, 0, 0, 0),
			BackgroundTransparency = 1,
			FontFace = F.bold,
			TextSize = 20,
			TextColor3 = C.textPrimary,
			Text = entry.icon or "\u{1FA99}",
		}),

		-- Name + ticker
		CoinInfo = Roact.createElement("Frame", {
			Size = UDim2.new(0.28, 0, 1, 0),
			Position = UDim2.new(0, 32, 0, 0),
			BackgroundTransparency = 1,
		}, {
			Name = Roact.createElement("TextLabel", {
				Size = UDim2.new(1, 0, 0, 22),
				Position = UDim2.new(0, 0, 0, 6),
				BackgroundTransparency = 1,
				FontFace = F.bold,
				TextSize = S.textMd,
				TextColor3 = C.textPrimary,
				Text = entry.name or "???",
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
			}),
			Ticker = Roact.createElement("TextLabel", {
				Size = UDim2.new(1, 0, 0, 16),
				Position = UDim2.new(0, 0, 0, 28),
				BackgroundTransparency = 1,
				FontFace = F.light,
				TextSize = S.textXs,
				TextColor3 = C.textSecondary,
				Text = "$" .. (entry.ticker or "?"),
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
		}),

		-- Meta badge
		MetaBadge = Roact.createElement("Frame", {
			Size = UDim2.new(0.12, 0, 0, 22),
			Position = UDim2.new(0.38, 0, 0.5, 0),
			AnchorPoint = Vector2.new(0, 0.5),
			BackgroundColor3 = metaColor,
			BackgroundTransparency = 0.75,
			BorderSizePixel = 0,
		}, {
			MCorner = Roact.createElement("UICorner", { CornerRadius = UDim.new(0, 4) }),
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
				Text = entry.meta or "?",
			}),
		}),

		-- Phase badge
		PhaseBadge = Roact.createElement("Frame", {
			Size = UDim2.new(0.12, 0, 0, 22),
			Position = UDim2.new(0.52, 0, 0.5, 0),
			AnchorPoint = Vector2.new(0, 0.5),
			BackgroundColor3 = phaseColor,
			BackgroundTransparency = 0.75,
			BorderSizePixel = 0,
		}, {
			PCorner = Roact.createElement("UICorner", { CornerRadius = UDim.new(0, 4) }),
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
			Size = UDim2.new(0.14, 0, 1, 0),
			Position = UDim2.new(0.66, 0, 0, 0),
			BackgroundTransparency = 1,
			FontFace = F.mono,
			TextSize = S.textMd,
			TextColor3 = C.textPrimary,
			Text = Formatting.formatPrice(price),
			TextXAlignment = Enum.TextXAlignment.Right,
		}),

		-- Change %
		ChangeLabel = Roact.createElement("TextLabel", {
			Size = UDim2.new(0.14, 0, 1, 0),
			Position = UDim2.new(0.82, 0, 0, 0),
			BackgroundTransparency = 1,
			FontFace = F.bold,
			TextSize = S.textMd,
			TextColor3 = changeColor,
			Text = Formatting.formatPct(changePct),
			TextXAlignment = Enum.TextXAlignment.Right,
		}),
	})
end

function LaunchpadUI:render()
	local store = self.props.store
	local state = store:getState()
	local C = Theme.colors
	local F = Theme.fonts
	local S = Theme.size

	if not state.launchpadUIOpen then
		return nil
	end

	local countdown = state.launchCountdown or 0
	local recentLaunches = state.launchRecentLaunches or {}

	-- Build launch rows
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

	for i, entry in recentLaunches do
		rows["Launch_" .. (entry.coinId or i)] = self:_renderLaunchRow(entry, i)
	end

	local rowCount = math.max(#recentLaunches, 1)

	return Roact.createElement("Frame", {
		Name = "LaunchpadOverlay",
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundColor3 = C.overlay,
		BackgroundTransparency = 0.3,
		BorderSizePixel = 0,
		ZIndex = 40,
	}, {
		Panel = Roact.createElement("Frame", {
			Name = "LaunchpadPanel",
			Size = UDim2.new(0, 650, 0, 520),
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
				Color = ACCENT,
				Thickness = S.strokeThickness,
				Transparency = 0.5,
			}),
			Gradient = Roact.createElement("UIGradient", Theme.gradients.card()),

			-- Header
			Header = Roact.createElement("Frame", {
				Size = UDim2.new(1, 0, 0, 54),
				BackgroundTransparency = 1,
				ZIndex = 42,
			}, {
				Title = Roact.createElement("TextLabel", {
					Size = UDim2.new(0.5, 0, 0, 30),
					Position = UDim2.new(0, 20, 0, 12),
					BackgroundTransparency = 1,
					FontFace = F.bold,
					TextSize = S.textXl,
					TextColor3 = ACCENT,
					Text = "LAUNCHPAD",
					TextXAlignment = Enum.TextXAlignment.Left,
					ZIndex = 42,
				}),
				CloseBtn = Roact.createElement("TextButton", {
					Size = UDim2.new(0, 36, 0, 36),
					Position = UDim2.new(1, -14, 0, 10),
					AnchorPoint = Vector2.new(1, 0),
					BackgroundColor3 = C.bgElevated,
					BorderSizePixel = 0,
					FontFace = F.bold,
					TextSize = S.textLg,
					TextColor3 = C.textSecondary,
					Text = "\u{2715}",
					ZIndex = 42,
					[Roact.Event.MouseButton1Click] = function()
						store:closeLaunchpadUI()
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
					BackgroundColor3 = ACCENT,
					BackgroundTransparency = 0.6,
					BorderSizePixel = 0,
					ZIndex = 42,
				}),
			}),

			-- Countdown section
			CountdownSection = Roact.createElement("Frame", {
				Size = UDim2.new(1, -24, 0, 80),
				Position = UDim2.new(0, 12, 0, 56),
				BackgroundColor3 = C.bgElevated,
				BackgroundTransparency = 0.5,
				BorderSizePixel = 0,
				ZIndex = 42,
			}, {
				CCorner = Roact.createElement("UICorner", { CornerRadius = UDim.new(0, 8) }),
				CLabel = Roact.createElement("TextLabel", {
					Size = UDim2.new(0.5, 0, 0, 20),
					Position = UDim2.new(0, 16, 0, 10),
					BackgroundTransparency = 1,
					FontFace = F.bold,
					TextSize = S.textSm,
					TextColor3 = C.textMuted,
					Text = "NEXT LAUNCH IN",
					TextXAlignment = Enum.TextXAlignment.Left,
					ZIndex = 42,
				}),
				CValue = Roact.createElement("TextLabel", {
					Size = UDim2.new(0.5, 0, 0, 50),
					Position = UDim2.new(0, 16, 0, 26),
					BackgroundTransparency = 1,
					FontFace = F.mono,
					TextSize = 38,
					TextColor3 = if countdown <= 10 then Color3.fromHex("#FF4757") else C.textPrimary,
					Text = formatCountdown(countdown),
					TextXAlignment = Enum.TextXAlignment.Left,
					ZIndex = 42,
				}),
				CInfo = Roact.createElement("TextLabel", {
					Size = UDim2.new(0.4, 0, 0, 16),
					Position = UDim2.new(0.58, 0, 0.5, 0),
					AnchorPoint = Vector2.new(0, 0.5),
					BackgroundTransparency = 1,
					FontFace = F.light,
					TextSize = S.textXs,
					TextColor3 = C.textMuted,
					Text = "New coins launch periodically.\nAll start in STEALTH phase.",
					TextWrapped = true,
					TextXAlignment = Enum.TextXAlignment.Left,
					ZIndex = 42,
				}),
			}),

			-- Column headers
			ColumnHeaders = Roact.createElement("Frame", {
				Size = UDim2.new(1, -24, 0, 24),
				Position = UDim2.new(0, 12, 0, 142),
				BackgroundTransparency = 1,
				ZIndex = 42,
			}, {
				HPad = Roact.createElement("UIPadding", {
					PaddingLeft = UDim.new(0, 12),
					PaddingRight = UDim.new(0, 12),
				}),
				Col1 = Roact.createElement("TextLabel", {
					Size = UDim2.new(0.36, 0, 1, 0),
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
					Position = UDim2.new(0.38, 0, 0, 0),
					BackgroundTransparency = 1,
					FontFace = F.bold,
					TextSize = S.textXs,
					TextColor3 = C.textMuted,
					Text = "META",
				}),
				Col3 = Roact.createElement("TextLabel", {
					Size = UDim2.new(0.12, 0, 1, 0),
					Position = UDim2.new(0.52, 0, 0, 0),
					BackgroundTransparency = 1,
					FontFace = F.bold,
					TextSize = S.textXs,
					TextColor3 = C.textMuted,
					Text = "PHASE",
				}),
				Col4 = Roact.createElement("TextLabel", {
					Size = UDim2.new(0.14, 0, 1, 0),
					Position = UDim2.new(0.66, 0, 0, 0),
					BackgroundTransparency = 1,
					FontFace = F.bold,
					TextSize = S.textXs,
					TextColor3 = C.textMuted,
					Text = "PRICE",
					TextXAlignment = Enum.TextXAlignment.Right,
				}),
				Col5 = Roact.createElement("TextLabel", {
					Size = UDim2.new(0.14, 0, 1, 0),
					Position = UDim2.new(0.82, 0, 0, 0),
					BackgroundTransparency = 1,
					FontFace = F.bold,
					TextSize = S.textXs,
					TextColor3 = C.textMuted,
					Text = "CHG %",
					TextXAlignment = Enum.TextXAlignment.Right,
				}),
			}),

			-- Recent launches list (scrollable)
			LaunchList = Roact.createElement("ScrollingFrame", {
				Name = "LaunchList",
				Size = UDim2.new(1, -24, 1, -180),
				Position = UDim2.new(0, 12, 0, 168),
				BackgroundTransparency = 1,
				ScrollBarThickness = 4,
				ScrollBarImageColor3 = ACCENT,
				CanvasSize = UDim2.new(0, 0, 0, rowCount * 56 + 16),
				BorderSizePixel = 0,
				ZIndex = 42,
			}, rows),

			-- Footer hint
			FooterHint = Roact.createElement("TextLabel", {
				Size = UDim2.new(1, 0, 0, 18),
				Position = UDim2.new(0, 0, 1, -6),
				AnchorPoint = Vector2.new(0, 1),
				BackgroundTransparency = 1,
				FontFace = F.light,
				TextSize = S.textXs,
				TextColor3 = C.textMuted,
				Text = "Click a coin to open its chart  |  ESC to close",
				ZIndex = 42,
			}),
		}),
	})
end

return LaunchpadUI
