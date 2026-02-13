--[[
	TradeModal.luau — Full trade modal overlay with header, chart area, and order panel.
	Opens when player interacts with station. Contains coin info, candlestick chart,
	buy/sell toggle, quantity input, and execute button.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Roact = require(ReplicatedStorage.Packages.Roact)

local Theme = require(script.Parent.Theme)
local Formatting = require(ReplicatedStorage.Shared.Formatting)
local Config = require(ReplicatedStorage.Shared.Config)

local TradeModal = Roact.Component:extend("TradeModal")

function TradeModal:init()
	self.overlayRef = Roact.createRef()
	self.modalRef = Roact.createRef()
	self.chartContainerRef = Roact.createRef()
	self._wasOpen = false
end

function TradeModal:didMount()
	-- Expose chart container ref for external ChartRenderer
	if self.props.onChartReady then
		local container = self.chartContainerRef:getValue()
		if container then
			self.props.onChartReady(container)
		end
	end
end

function TradeModal:didUpdate()
	local state = self.props.store:getState()
	local overlay = self.overlayRef:getValue()
	local modal = self.modalRef:getValue()
	if not overlay or not modal then return end

	if state.tradeModalOpen and not self._wasOpen then
		-- Open animation
		overlay.Visible = true
		overlay.BackgroundTransparency = 1
		modal.Position = UDim2.new(0.5, 0, 0.55, 0)
		modal.Size = UDim2.new(0, Theme.size.modalWidth * 0.9, 0, Theme.size.modalHeight * 0.9)

		TweenService:Create(overlay, Theme.animation.fast, {
			BackgroundTransparency = 0.4
		}):Play()
		TweenService:Create(modal, Theme.animation.springy, {
			Position = UDim2.new(0.5, 0, 0.5, 0),
			Size = UDim2.new(0, Theme.size.modalWidth, 0, Theme.size.modalHeight),
		}):Play()

		-- Notify chart container is ready
		if self.props.onChartReady then
			local container = self.chartContainerRef:getValue()
			if container then
				self.props.onChartReady(container)
			end
		end
	elseif not state.tradeModalOpen and self._wasOpen then
		-- Close animation
		local tween = TweenService:Create(overlay, Theme.animation.slideOut, {
			BackgroundTransparency = 1
		})
		TweenService:Create(modal, Theme.animation.slideOut, {
			Position = UDim2.new(0.5, 0, 0.55, 0),
			Size = UDim2.new(0, Theme.size.modalWidth * 0.9, 0, Theme.size.modalHeight * 0.9),
		}):Play()
		tween:Play()
		tween.Completed:Connect(function()
			if overlay.Parent then overlay.Visible = false end
		end)
	end

	self._wasOpen = state.tradeModalOpen
end

function TradeModal:render()
	local store = self.props.store
	local state = store:getState()
	local C = Theme.colors
	local F = Theme.fonts
	local S = Theme.size

	local coinDef = store:getSelectedCoinDef()
	local price = store:getSelectedCoinPrice()
	local change = store:getSelectedCoinChange()
	local isBuy = state.currentAction == "BUY"

	-- Holding info
	local holdingInfo = ""
	if coinDef then
		local h = state.holdings[coinDef.id]
		if h and h.qty > 0 then
			holdingInfo = "Holding: " .. Formatting.formatQty(h.qty)
				.. " @ " .. Formatting.formatPrice(h.avgEntry)
		else
			holdingInfo = "No position"
		end
	end

	-- Compute cost preview
	local qty = tonumber(state.qtyText) or 0
	local cost = qty * price
	local fee = cost * Config.TRADE_FEE_PCT
	local totalCost = isBuy and (cost + fee) or (cost - fee)

	-- Quick % buttons
	local quickBtns = {}
	local percentages = { 0.25, 0.50, 0.75, 1.0 }
	local pctLabels = { "25%", "50%", "75%", "MAX" }
	for i, pct in percentages do
		quickBtns["Q" .. i] = Roact.createElement("TextButton", {
			LayoutOrder = i,
			Size = UDim2.new(0.235, 0, 0, 26),
			BackgroundColor3 = C.bgElevated,
			BorderSizePixel = 0,
			FontFace = F.medium,
			TextSize = S.textXs,
			TextColor3 = C.textSecondary,
			Text = pctLabels[i],
			[Roact.Event.MouseButton1Click] = function()
				store:setQuickPercent(pct)
			end,
		}, {
			Corner = Roact.createElement("UICorner", {
				CornerRadius = UDim.new(0, S.cornerRadiusSm),
			}),
		})
	end
	quickBtns.Layout = Roact.createElement("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 4),
		VerticalAlignment = Enum.VerticalAlignment.Center,
	})

	return Roact.createElement("Frame", {
		Name = "TradeOverlay",
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundColor3 = C.overlay,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 50,
		[Roact.Ref] = self.overlayRef,
	}, {
		Modal = Roact.createElement("Frame", {
			Name = "TradeModal",
			Size = UDim2.new(0, S.modalWidth, 0, S.modalHeight),
			Position = UDim2.new(0.5, 0, 0.5, 0),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = C.bgCard,
			BorderSizePixel = 0,
			ZIndex = 51,
			[Roact.Ref] = self.modalRef,
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
				Size = UDim2.new(1, 0, 0, 52),
				BackgroundTransparency = 1,
				ZIndex = 52,
			}, {
				CoinName = Roact.createElement("TextLabel", {
					Name = "CoinName",
					Size = UDim2.new(0.6, -20, 0, 24),
					Position = UDim2.new(0, 16, 0, 8),
					BackgroundTransparency = 1,
					FontFace = F.bold,
					TextSize = S.textLg,
					TextColor3 = C.textPrimary,
					Text = coinDef and (coinDef.icon .. " " .. coinDef.name .. " (" .. coinDef.ticker .. ")") or "",
					TextXAlignment = Enum.TextXAlignment.Left,
					ZIndex = 52,
				}),
				CoinPrice = Roact.createElement("TextLabel", {
					Name = "CoinPrice",
					Size = UDim2.new(0.6, -20, 0, 20),
					Position = UDim2.new(0, 16, 0, 30),
					BackgroundTransparency = 1,
					FontFace = F.mono,
					TextSize = S.textMd,
					TextColor3 = change >= 0 and C.green or C.red,
					Text = Formatting.formatPrice(price) .. "  " .. Formatting.formatPct(change),
					TextXAlignment = Enum.TextXAlignment.Left,
					ZIndex = 52,
				}),
				CloseBtn = Roact.createElement("TextButton", {
					Name = "CloseBtn",
					Size = UDim2.new(0, 36, 0, 36),
					Position = UDim2.new(1, -14, 0, 8),
					AnchorPoint = Vector2.new(1, 0),
					BackgroundColor3 = C.bgElevated,
					BorderSizePixel = 0,
					FontFace = F.bold,
					TextSize = S.textLg,
					TextColor3 = C.textSecondary,
					Text = "✕",
					ZIndex = 52,
					[Roact.Event.MouseButton1Click] = function()
						store:closeModal()
					end,
				}, {
					Corner = Roact.createElement("UICorner", {
						CornerRadius = UDim.new(0, S.cornerRadius),
					}),
				}),
				-- Header divider line
				Divider = Roact.createElement("Frame", {
					Size = UDim2.new(1, -24, 0, 1),
					Position = UDim2.new(0, 12, 1, 0),
					AnchorPoint = Vector2.new(0, 1),
					BackgroundColor3 = C.border,
					BackgroundTransparency = 0.5,
					BorderSizePixel = 0,
					ZIndex = 52,
				}),
			}),

			-- ═══════════════════════════════════════
			-- BODY: Chart + Order Panel side by side
			-- ═══════════════════════════════════════
			Body = Roact.createElement("Frame", {
				Name = "Body",
				Size = UDim2.new(1, -16, 1, -60),
				Position = UDim2.new(0, 8, 0, 54),
				BackgroundTransparency = 1,
				ZIndex = 51,
			}, {
				BodyLayout = Roact.createElement("UIListLayout", {
					FillDirection = Enum.FillDirection.Horizontal,
					Padding = UDim.new(0, 8),
				}),

				-- Chart container (will be managed by ChartRenderer)
				ChartArea = Roact.createElement("Frame", {
					Name = "ChartArea",
					Size = UDim2.new(0.58, 0, 1, -8),
					BackgroundColor3 = C.bgInput,
					BorderSizePixel = 0,
					LayoutOrder = 1,
					ZIndex = 51,
					[Roact.Ref] = self.chartContainerRef,
				}, {
					Corner = Roact.createElement("UICorner", {
						CornerRadius = UDim.new(0, S.cornerRadius),
					}),
					Stroke = Roact.createElement("UIStroke", {
						Color = C.border,
						Thickness = 1,
						Transparency = 0.5,
					}),
				}),

				-- Order panel
				OrderPanel = Roact.createElement("Frame", {
					Name = "OrderPanel",
					Size = UDim2.new(0.42, -8, 1, -8),
					BackgroundColor3 = C.bgElevated,
					BorderSizePixel = 0,
					LayoutOrder = 2,
					ZIndex = 51,
				}, {
					Corner = Roact.createElement("UICorner", {
						CornerRadius = UDim.new(0, S.cornerRadius),
					}),
					Stroke = Roact.createElement("UIStroke", {
						Color = C.border,
						Thickness = 1,
						Transparency = 0.6,
					}),
					Padding = Roact.createElement("UIPadding", {
						PaddingTop = UDim.new(0, 10),
						PaddingBottom = UDim.new(0, 10),
						PaddingLeft = UDim.new(0, 10),
						PaddingRight = UDim.new(0, 10),
					}),
					PanelLayout = Roact.createElement("UIListLayout", {
						SortOrder = Enum.SortOrder.LayoutOrder,
						Padding = UDim.new(0, 8),
					}),

					-- Buy/Sell Toggle
					Toggle = Roact.createElement("Frame", {
						Name = "Toggle",
						Size = UDim2.new(1, 0, 0, 36),
						BackgroundColor3 = C.bgInput,
						BorderSizePixel = 0,
						LayoutOrder = 1,
					}, {
						ToggleCorner = Roact.createElement("UICorner", {
							CornerRadius = UDim.new(0, S.cornerRadius),
						}),
						BuyBtn = Roact.createElement("TextButton", {
							Name = "BuyBtn",
							Size = UDim2.new(0.5, -2, 1, -4),
							Position = UDim2.new(0, 2, 0, 2),
							BackgroundColor3 = isBuy and C.green or C.bgInput,
							BackgroundTransparency = isBuy and 0 or 1,
							BorderSizePixel = 0,
							FontFace = F.bold,
							TextSize = S.textMd,
							TextColor3 = isBuy and C.white or C.textSecondary,
							Text = "BUY",
							[Roact.Event.MouseButton1Click] = function()
								store:setAction("BUY")
							end,
						}, {
							Corner = Roact.createElement("UICorner", {
								CornerRadius = UDim.new(0, S.cornerRadiusSm),
							}),
						}),
						SellBtn = Roact.createElement("TextButton", {
							Name = "SellBtn",
							Size = UDim2.new(0.5, -2, 1, -4),
							Position = UDim2.new(0.5, 0, 0, 2),
							BackgroundColor3 = not isBuy and C.red or C.bgInput,
							BackgroundTransparency = not isBuy and 0 or 1,
							BorderSizePixel = 0,
							FontFace = F.bold,
							TextSize = S.textMd,
							TextColor3 = not isBuy and C.white or C.textSecondary,
							Text = "SELL",
							[Roact.Event.MouseButton1Click] = function()
								store:setAction("SELL")
							end,
						}, {
							Corner = Roact.createElement("UICorner", {
								CornerRadius = UDim.new(0, S.cornerRadiusSm),
							}),
						}),
					}),

					-- Quantity Label
					QtyLabel = Roact.createElement("TextLabel", {
						Name = "QtyLabel",
						Size = UDim2.new(1, 0, 0, 18),
						BackgroundTransparency = 1,
						FontFace = F.medium,
						TextSize = S.textSm,
						TextColor3 = C.textSecondary,
						Text = "Quantity",
						TextXAlignment = Enum.TextXAlignment.Left,
						LayoutOrder = 2,
					}),

					-- Quantity Input
					QtyInput = Roact.createElement("TextBox", {
						Name = "QtyInput",
						Size = UDim2.new(1, 0, 0, 38),
						BackgroundColor3 = C.bgInput,
						BorderSizePixel = 0,
						FontFace = F.mono,
						TextSize = S.textLg,
						TextColor3 = C.textPrimary,
						PlaceholderText = "Enter qty...",
						PlaceholderColor3 = C.textMuted,
						Text = state.qtyText,
						ClearTextOnFocus = false,
						LayoutOrder = 3,
						[Roact.Event.FocusLost] = function(rbx)
							store:setQtyText(rbx.Text)
						end,
						[Roact.Change.Text] = function(rbx)
							store:setQtyText(rbx.Text)
						end,
					}, {
						Corner = Roact.createElement("UICorner", {
							CornerRadius = UDim.new(0, S.cornerRadiusSm),
						}),
						Stroke = Roact.createElement("UIStroke", {
							Color = C.border,
							Thickness = 1,
						}),
						InputPad = Roact.createElement("UIPadding", {
							PaddingLeft = UDim.new(0, 10),
							PaddingRight = UDim.new(0, 10),
						}),
					}),

					-- Quick % buttons
					QuickBtns = Roact.createElement("Frame", {
						Name = "QuickBtns",
						Size = UDim2.new(1, 0, 0, 26),
						BackgroundTransparency = 1,
						LayoutOrder = 4,
					}, quickBtns),

					-- Cost preview
					CostPreview = Roact.createElement("Frame", {
						Name = "CostPreview",
						Size = UDim2.new(1, 0, 0, 50),
						BackgroundColor3 = C.bgInput,
						BorderSizePixel = 0,
						LayoutOrder = 5,
					}, {
						Corner = Roact.createElement("UICorner", {
							CornerRadius = UDim.new(0, S.cornerRadiusSm),
						}),
						CostLabel = Roact.createElement("TextLabel", {
							Size = UDim2.new(0.5, -4, 0, 20),
							Position = UDim2.new(0, 8, 0, 4),
							BackgroundTransparency = 1,
							FontFace = F.light,
							TextSize = S.textXs,
							TextColor3 = C.textSecondary,
							Text = isBuy and "Total Cost" or "Total Receive",
							TextXAlignment = Enum.TextXAlignment.Left,
						}),
						CostValue = Roact.createElement("TextLabel", {
							Size = UDim2.new(0.5, -4, 0, 20),
							Position = UDim2.new(0.5, 4, 0, 4),
							BackgroundTransparency = 1,
							FontFace = F.bold,
							TextSize = S.textSm,
							TextColor3 = C.textPrimary,
							Text = Formatting.formatCash(totalCost),
							TextXAlignment = Enum.TextXAlignment.Right,
						}),
						FeeLabel = Roact.createElement("TextLabel", {
							Size = UDim2.new(0.5, -4, 0, 16),
							Position = UDim2.new(0, 8, 0, 26),
							BackgroundTransparency = 1,
							FontFace = F.light,
							TextSize = S.textXs,
							TextColor3 = C.textMuted,
							Text = "Fee (" .. (Config.TRADE_FEE_PCT * 100) .. "%)",
							TextXAlignment = Enum.TextXAlignment.Left,
						}),
						FeeValue = Roact.createElement("TextLabel", {
							Size = UDim2.new(0.5, -4, 0, 16),
							Position = UDim2.new(0.5, 4, 0, 26),
							BackgroundTransparency = 1,
							FontFace = F.light,
							TextSize = S.textXs,
							TextColor3 = C.textMuted,
							Text = Formatting.formatCash(fee),
							TextXAlignment = Enum.TextXAlignment.Right,
						}),
					}),

					-- Execute button
					ExecuteBtn = Roact.createElement("TextButton", {
						Name = "ExecuteBtn",
						Size = UDim2.new(1, 0, 0, 40),
						BackgroundColor3 = isBuy and C.green or C.red,
						BorderSizePixel = 0,
						FontFace = F.bold,
						TextSize = S.textLg,
						TextColor3 = C.white,
						Text = (isBuy and "⬆ BUY" or "⬇ SELL") .. (coinDef and (" " .. coinDef.ticker) or ""),
						LayoutOrder = 6,
						[Roact.Event.MouseButton1Click] = function()
							store:executeTrade()
						end,
					}, {
						Corner = Roact.createElement("UICorner", {
							CornerRadius = UDim.new(0, S.cornerRadius),
						}),
						ExecuteGradient = Roact.createElement("UIGradient",
							isBuy and Theme.gradients.greenButton() or Theme.gradients.redButton()
						),
					}),

					-- Holding info
					HoldingInfo = Roact.createElement("TextLabel", {
						Name = "HoldingInfo",
						Size = UDim2.new(1, 0, 0, 18),
						BackgroundTransparency = 1,
						FontFace = F.light,
						TextSize = S.textXs,
						TextColor3 = C.textSecondary,
						Text = holdingInfo,
						TextXAlignment = Enum.TextXAlignment.Center,
						LayoutOrder = 7,
					}),
				}),
			}),
		}),
	})
end

return TradeModal
