--[[
	UIController.luau — Master UI orchestrator for 3D trading floor mode.
	Builds: top bar HUD (always visible), trade popup modal (on interaction),
	bottom panel (toggleable), and toast notifications.
	No coin list — coin selection happens via 3D ProximityPrompts.
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local UIController = {}

-- Color palette — dark trading terminal
local Colors = {
	bg = Color3.fromHex("#0D1117"),
	bgSecondary = Color3.fromHex("#161B22"),
	bgTertiary = Color3.fromHex("#21262D"),
	bgHover = Color3.fromHex("#30363D"),
	border = Color3.fromHex("#30363D"),
	textPrimary = Color3.fromHex("#F0F6FC"),
	textSecondary = Color3.fromHex("#8B949E"),
	green = Color3.fromHex("#3FB950"),
	red = Color3.fromHex("#F85149"),
	accent = Color3.fromHex("#58A6FF"),
	accentDim = Color3.fromHex("#1F6FEB"),
	gold = Color3.fromHex("#F0C000"),
	orange = Color3.fromHex("#F0883E"),
}
UIController.Colors = Colors

local FONT = Font.fromName("GothamSSm", Enum.FontWeight.Medium)
local FONT_BOLD = Font.fromName("GothamSSm", Enum.FontWeight.Bold)
local FONT_LIGHT = Font.fromName("GothamSSm", Enum.FontWeight.Regular)
UIController.FONT = FONT
UIController.FONT_BOLD = FONT_BOLD
UIController.FONT_LIGHT = FONT_LIGHT

local screenGui: ScreenGui = nil

-------------------------------------------------
-- UI element factories
-------------------------------------------------
function UIController.makeFrame(props: {}): Frame
	local f = Instance.new("Frame")
	f.BackgroundColor3 = props.bg or Colors.bgSecondary
	f.BorderSizePixel = 0
	f.Size = props.size or UDim2.new(1, 0, 1, 0)
	f.Position = props.pos or UDim2.new(0, 0, 0, 0)
	f.AnchorPoint = props.anchor or Vector2.new(0, 0)
	f.Name = props.name or "Frame"
	if props.corner then
		Instance.new("UICorner", f).CornerRadius = UDim.new(0, props.corner)
	end
	if props.stroke then
		local s = Instance.new("UIStroke", f)
		s.Color = props.strokeColor or Colors.border
		s.Thickness = props.stroke
	end
	if props.parent then f.Parent = props.parent end
	return f
end

function UIController.makeLabel(props: {}): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = props.size or UDim2.new(1, 0, 0, 20)
	l.Position = props.pos or UDim2.new(0, 0, 0, 0)
	l.AnchorPoint = props.anchor or Vector2.new(0, 0)
	l.FontFace = props.font or FONT
	l.TextSize = props.textSize or 14
	l.TextColor3 = props.color or Colors.textPrimary
	l.Text = props.text or ""
	l.TextXAlignment = props.alignX or Enum.TextXAlignment.Left
	l.TextYAlignment = props.alignY or Enum.TextYAlignment.Center
	l.Name = props.name or "Label"
	l.TextTruncate = Enum.TextTruncate.AtEnd
	if props.parent then l.Parent = props.parent end
	return l
end

function UIController.makeButton(props: {}): TextButton
	local b = Instance.new("TextButton")
	b.BackgroundColor3 = props.bg or Colors.accent
	b.BorderSizePixel = 0
	b.Size = props.size or UDim2.new(0, 100, 0, 36)
	b.Position = props.pos or UDim2.new(0, 0, 0, 0)
	b.AnchorPoint = props.anchor or Vector2.new(0, 0)
	b.FontFace = props.font or FONT_BOLD
	b.TextSize = props.textSize or 14
	b.TextColor3 = props.textColor or Colors.textPrimary
	b.Text = props.text or "Button"
	b.Name = props.name or "Button"
	b.AutoButtonColor = false
	if props.corner then Instance.new("UICorner", b).CornerRadius = UDim.new(0, props.corner) end
	if props.parent then b.Parent = props.parent end
	b.MouseEnter:Connect(function()
		TweenService:Create(b, TweenInfo.new(0.15), {BackgroundColor3 = props.hoverBg or Colors.accentDim}):Play()
	end)
	b.MouseLeave:Connect(function()
		TweenService:Create(b, TweenInfo.new(0.15), {BackgroundColor3 = props.bg or Colors.accent}):Play()
	end)
	return b
end

function UIController.makeScrolling(props: {}): ScrollingFrame
	local s = Instance.new("ScrollingFrame")
	s.BackgroundColor3 = props.bg or Colors.bgSecondary
	s.BackgroundTransparency = props.bgTransparency or 0
	s.BorderSizePixel = 0
	s.Size = props.size or UDim2.new(1, 0, 1, 0)
	s.Position = props.pos or UDim2.new(0, 0, 0, 0)
	s.AnchorPoint = props.anchor or Vector2.new(0, 0)
	s.CanvasSize = UDim2.new(0, 0, 0, 0)
	s.AutomaticCanvasSize = Enum.AutomaticSize.Y
	s.ScrollBarThickness = 4
	s.ScrollBarImageColor3 = Colors.border
	s.Name = props.name or "ScrollFrame"
	if props.parent then s.Parent = props.parent end
	return s
end

-------------------------------------------------
-- Build main layout (HUD overlay on 3D world)
-------------------------------------------------
function UIController.BuildLayout(gui: ScreenGui)
	screenGui = gui

	-- ===== TOP BAR HUD (always visible, floats over 3D) =====
	local topBar = UIController.makeFrame({
		name = "TopBar",
		size = UDim2.new(1, 0, 0, 48),
		bg = Colors.bgSecondary,
		parent = gui,
	})
	topBar.BackgroundTransparency = 0.15
	UIController.makeFrame({
		name = "TopBorder", size = UDim2.new(1, 0, 0, 1),
		pos = UDim2.new(0, 0, 1, 0), anchor = Vector2.new(0, 1),
		bg = Colors.border, parent = topBar,
	})

	-- Center container for top bar content (avoids Roblox chat/menu overlap on left)
	local topBarContent = UIController.makeFrame({
		name = "TopBarContent",
		size = UDim2.new(0, 700, 1, 0),
		pos = UDim2.new(0.5, 0, 0, 0),
		anchor = Vector2.new(0.5, 0),
		bg = Colors.bgSecondary,
		parent = topBar,
	})
	topBarContent.BackgroundTransparency = 1

	-- Layout: centered items flow horizontally
	local topLayout = Instance.new("UIListLayout")
	topLayout.FillDirection = Enum.FillDirection.Horizontal
	topLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	topLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	topLayout.Padding = UDim.new(0, 12)
	topLayout.Parent = topBarContent

	-- Title
	UIController.makeLabel({ name = "Title", text = "💹 MEMECOIN TRADER",
		font = FONT_BOLD, textSize = 18, color = Colors.gold,
		size = UDim2.new(0, 210, 1, 0), parent = topBarContent,
	})

	-- Cash section
	UIController.makeLabel({ name = "CashLabel", text = "💰 Cash:",
		font = FONT_LIGHT, textSize = 14, color = Colors.textSecondary,
		size = UDim2.new(0, 70, 1, 0), parent = topBarContent,
	})
	UIController.makeLabel({ name = "CashValue", text = "$10,000.00",
		font = FONT_BOLD, textSize = 17, color = Colors.green,
		size = UDim2.new(0, 120, 1, 0), parent = topBarContent,
	})

	-- Portfolio section
	UIController.makeLabel({ name = "PortfolioLabel", text = "📊 Portfolio:",
		font = FONT_LIGHT, textSize = 14, color = Colors.textSecondary,
		size = UDim2.new(0, 90, 1, 0), parent = topBarContent,
	})
	UIController.makeLabel({ name = "PortfolioValue", text = "$10,000.00",
		font = FONT_BOLD, textSize = 17, color = Colors.textPrimary,
		size = UDim2.new(0, 120, 1, 0), parent = topBarContent,
	})

	-- P&L section
	UIController.makeLabel({ name = "PnLLabel", text = "P&L:",
		font = FONT_LIGHT, textSize = 14, color = Colors.textSecondary,
		size = UDim2.new(0, 35, 1, 0), parent = topBarContent,
	})
	UIController.makeLabel({ name = "PnLValue", text = "$0.00",
		font = FONT_BOLD, textSize = 17, color = Colors.textPrimary,
		size = UDim2.new(0, 100, 1, 0), parent = topBarContent,
	})

	-- ===== TRADE POPUP MODAL (centered, hidden initially) =====
	local tradeOverlay = UIController.makeFrame({
		name = "TradeOverlay",
		size = UDim2.new(1, 0, 1, 0),
		bg = Color3.new(0, 0, 0),
		parent = gui,
	})
	tradeOverlay.BackgroundTransparency = 0.5
	tradeOverlay.Visible = false
	tradeOverlay.ZIndex = 50

	local tradeModal = UIController.makeFrame({
		name = "TradeModal",
		size = UDim2.new(0, 700, 0, 460),
		pos = UDim2.new(0.5, 0, 0.5, 0),
		anchor = Vector2.new(0.5, 0.5),
		bg = Colors.bgSecondary,
		corner = 12,
		stroke = 2,
		strokeColor = Colors.accent,
		parent = tradeOverlay,
	})
	tradeModal.ZIndex = 51

	-- Modal header
	local modalHeader = UIController.makeFrame({
		name = "ModalHeader", size = UDim2.new(1, 0, 0, 44), bg = Colors.bgTertiary,
		corner = 12, parent = tradeModal,
	})
	modalHeader.ZIndex = 52
	UIController.makeLabel({ name = "SelectedCoinName", text = "Select a coin",
		font = FONT_BOLD, textSize = 16, color = Colors.textPrimary,
		size = UDim2.new(0.5, 0, 1, 0), pos = UDim2.new(0, 16, 0, 0), parent = modalHeader,
	}).ZIndex = 53
	UIController.makeLabel({ name = "SelectedCoinPrice", text = "",
		font = FONT_BOLD, textSize = 18, color = Colors.green,
		size = UDim2.new(0.4, 0, 1, 0), pos = UDim2.new(0.45, 0, 0, 0),
		alignX = Enum.TextXAlignment.Right, parent = modalHeader,
	}).ZIndex = 53

	-- Close button
	local closeBtn = UIController.makeButton({ name = "CloseBtn", text = "✕",
		size = UDim2.new(0, 36, 0, 36), pos = UDim2.new(1, -40, 0, 4),
		bg = Colors.bgHover, hoverBg = Colors.red, corner = 6,
		textSize = 16, parent = modalHeader,
	})
	closeBtn.ZIndex = 53

	-- Left side of modal: Chart
	local chartContainer = UIController.makeFrame({
		name = "ChartContainer", size = UDim2.new(0.58, -8, 1, -56),
		pos = UDim2.new(0, 8, 0, 50), bg = Colors.bgTertiary,
		corner = 8, parent = tradeModal,
	})
	chartContainer.ZIndex = 52

	-- Right side: Order panel
	local orderPanel = UIController.makeFrame({
		name = "OrderPanel", size = UDim2.new(0.42, -8, 1, -56),
		pos = UDim2.new(0.58, 4, 0, 50), bg = Colors.bgSecondary,
		parent = tradeModal,
	})
	orderPanel.ZIndex = 52

	-- Buy/Sell toggle
	local buySellToggle = UIController.makeFrame({
		name = "BuySellToggle", size = UDim2.new(1, -12, 0, 36),
		pos = UDim2.new(0, 6, 0, 4), bg = Colors.bgTertiary,
		corner = 6, parent = orderPanel,
	})
	buySellToggle.ZIndex = 53
	local buyBtn = UIController.makeButton({ name = "BuyToggle", text = "BUY",
		size = UDim2.new(0.5, -2, 1, -4), pos = UDim2.new(0, 2, 0, 2),
		bg = Colors.green, hoverBg = Color3.fromHex("#2EA043"), corner = 4, parent = buySellToggle,
	})
	buyBtn.ZIndex = 54
	local sellBtn = UIController.makeButton({ name = "SellToggle", text = "SELL",
		size = UDim2.new(0.5, -2, 1, -4), pos = UDim2.new(0.5, 0, 0, 2),
		bg = Colors.bgHover, hoverBg = Colors.red, corner = 4, parent = buySellToggle,
	})
	sellBtn.ZIndex = 54

	-- Qty label + input
	UIController.makeLabel({ name = "QtyLabel", text = "  Quantity",
		font = FONT_LIGHT, textSize = 13, color = Colors.textSecondary,
		size = UDim2.new(1, 0, 0, 20), pos = UDim2.new(0, 0, 0, 48), parent = orderPanel,
	}).ZIndex = 53
	local qtyInput = Instance.new("TextBox")
	qtyInput.Name = "QtyInput"
	qtyInput.Size = UDim2.new(1, -12, 0, 34)
	qtyInput.Position = UDim2.new(0, 6, 0, 68)
	qtyInput.BackgroundColor3 = Colors.bgTertiary
	qtyInput.BorderSizePixel = 0
	qtyInput.FontFace = FONT
	qtyInput.TextSize = 15
	qtyInput.TextColor3 = Colors.textPrimary
	qtyInput.PlaceholderText = "Enter amount..."
	qtyInput.PlaceholderColor3 = Colors.textSecondary
	qtyInput.Text = ""
	qtyInput.ClearTextOnFocus = false
	qtyInput.ZIndex = 53
	qtyInput.Parent = orderPanel
	Instance.new("UICorner", qtyInput).CornerRadius = UDim.new(0, 6)
	local qs = Instance.new("UIStroke", qtyInput)
	qs.Color = Colors.border; qs.Thickness = 1

	-- Quick % buttons
	local quickBtns = UIController.makeFrame({
		name = "QuickButtons", size = UDim2.new(1, -12, 0, 28),
		pos = UDim2.new(0, 6, 0, 110), bg = Colors.bgSecondary, parent = orderPanel,
	})
	quickBtns.ZIndex = 53
	local ql = Instance.new("UIListLayout", quickBtns)
	ql.FillDirection = Enum.FillDirection.Horizontal
	ql.Padding = UDim.new(0, 3)
	for _, pct in {25, 50, 75, 100} do
		local qb = UIController.makeButton({ name = "Quick"..pct, text = pct.."%",
			size = UDim2.new(0.25, -3, 1, 0), bg = Colors.bgTertiary,
			hoverBg = Colors.bgHover, corner = 4, textSize = 12, parent = quickBtns,
		})
		qb.ZIndex = 54
	end

	-- Cost preview
	UIController.makeLabel({ name = "CostPreview", text = "",
		font = FONT_LIGHT, textSize = 13, color = Colors.textSecondary,
		size = UDim2.new(1, -12, 0, 20), pos = UDim2.new(0, 6, 0, 146),
		alignX = Enum.TextXAlignment.Center, parent = orderPanel,
	}).ZIndex = 53

	-- Execute button
	local eb = UIController.makeButton({ name = "ExecuteBtn", text = "BUY NOW",
		size = UDim2.new(1, -12, 0, 42), pos = UDim2.new(0, 6, 0, 174),
		bg = Colors.green, hoverBg = Color3.fromHex("#2EA043"), corner = 8,
		textSize = 17, parent = orderPanel,
	})
	eb.ZIndex = 54

	-- Holdings summary in modal
	UIController.makeLabel({ name = "HoldingInfo", text = "",
		font = FONT_LIGHT, textSize = 13, color = Colors.textSecondary,
		size = UDim2.new(1, -12, 0, 40), pos = UDim2.new(0, 6, 0, 226),
		alignX = Enum.TextXAlignment.Center, parent = orderPanel,
	}).ZIndex = 53

	-- ===== BOTTOM PANEL (toggleable, starts HIDDEN below screen) =====
	local bottomToggle = UIController.makeButton({
		name = "BottomToggle", text = "📊 Portfolio",
		size = UDim2.new(0, 140, 0, 34), pos = UDim2.new(0, 12, 1, -46),
		bg = Colors.bgSecondary, hoverBg = Colors.bgTertiary, corner = 8,
		textSize = 14, parent = gui,
	})
	bottomToggle.BackgroundTransparency = 0.15

	local PANEL_HEIGHT = 280
	local bottomPanel = UIController.makeFrame({
		name = "BottomPanel",
		size = UDim2.new(0.85, 0, 0, PANEL_HEIGHT),
		pos = UDim2.new(0.5, 0, 1, PANEL_HEIGHT + 10), -- fully hidden below screen
		anchor = Vector2.new(0.5, 0),
		bg = Colors.bgSecondary,
		corner = 12,
		stroke = 1,
		parent = gui,
	})
	bottomPanel.BackgroundTransparency = 0.08

	-- Tab bar
	local tabBar = UIController.makeFrame({
		name = "TabBar", size = UDim2.new(1, 0, 0, 34),
		bg = Colors.bgSecondary, parent = bottomPanel,
	})
	local tl = Instance.new("UIListLayout", tabBar)
	tl.FillDirection = Enum.FillDirection.Horizontal
	for i, tn in {"📦 Portfolio", "📜 History", "📰 News"} do
		UIController.makeButton({ name = "Tab"..i, text = tn,
			size = UDim2.new(1/3, 0, 1, 0),
			bg = i==1 and Colors.bgTertiary or Colors.bgSecondary,
			hoverBg = Colors.bgTertiary, corner = 0, textSize = 13,
			textColor = i==1 and Colors.textPrimary or Colors.textSecondary,
			parent = tabBar,
		})
	end

	-- Tab content
	local tabContent = UIController.makeFrame({
		name = "TabContent", size = UDim2.new(1, -8, 1, -38),
		pos = UDim2.new(0, 4, 0, 36), bg = Colors.bgSecondary, parent = bottomPanel,
	})
	tabContent.BackgroundTransparency = 1

	for i, tn in {"PortfolioTab", "HistoryTab", "NewsTab"} do
		local tab = UIController.makeScrolling({
			name = tn, size = UDim2.new(1, 0, 1, 0),
			bg = Colors.bgSecondary, bgTransparency = 1, parent = tabContent,
		})
		tab.Visible = (i == 1)
		local ll = Instance.new("UIListLayout", tab)
		ll.SortOrder = Enum.SortOrder.LayoutOrder
		ll.Padding = UDim.new(0, 2)
	end

	-- ===== TOAST =====
	local toast = UIController.makeFrame({
		name = "TradeToast", size = UDim2.new(0.35, 0, 0, 48),
		pos = UDim2.new(0.5, 0, 0, -56), anchor = Vector2.new(0.5, 0),
		bg = Colors.bgTertiary, corner = 8, stroke = 1, strokeColor = Colors.accent,
		parent = gui,
	})
	toast.ZIndex = 100
	UIController.makeLabel({ name = "ToastText", text = "",
		font = FONT, textSize = 14, color = Colors.textPrimary,
		size = UDim2.new(1, -16, 1, 0), pos = UDim2.new(0, 8, 0, 0),
		alignX = Enum.TextXAlignment.Center, parent = toast,
	}).ZIndex = 101

	return gui
end

-------------------------------------------------
-- Get UI element by path
-------------------------------------------------
function UIController.GetElement(path: string): GuiObject?
	if not screenGui then return nil end
	local current: Instance = screenGui
	for segment in path:gmatch("[^%.]+") do
		-- Search in direct children first, then try nested TopBarContent
		local found = current:FindFirstChild(segment)
		if not found then
			-- Labels inside TopBarContent are accessed via "TopBar.CashValue" etc
			local tbc = current:FindFirstChild("TopBarContent")
			if tbc then
				found = tbc:FindFirstChild(segment)
			end
		end
		if not found then return nil end
		current = found
	end
	return current :: GuiObject
end

-------------------------------------------------
-- Trade modal open/close
-------------------------------------------------
function UIController.OpenTradeModal()
	local overlay = UIController.GetElement("TradeOverlay")
	if overlay then
		overlay.Visible = true
		local modal = overlay:FindFirstChild("TradeModal")
		if modal then
			modal.Size = UDim2.new(0, 0, 0, 0)
			TweenService:Create(modal, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
				Size = UDim2.new(0, 700, 0, 460)
			}):Play()
		end
	end
end

function UIController.CloseTradeModal()
	local overlay = UIController.GetElement("TradeOverlay")
	if overlay then
		local modal = overlay:FindFirstChild("TradeModal")
		if modal then
			TweenService:Create(modal, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				Size = UDim2.new(0, 0, 0, 0)
			}):Play()
		end
		task.delay(0.25, function()
			overlay.Visible = false
		end)
	end
end

function UIController.IsTradeModalOpen(): boolean
	local overlay = UIController.GetElement("TradeOverlay")
	return overlay and overlay.Visible or false
end

-------------------------------------------------
-- Bottom panel toggle (fixed: proper show/hide)
-------------------------------------------------
local PANEL_HEIGHT = 280
local bottomPanelOpen = false

function UIController.ToggleBottomPanel()
	bottomPanelOpen = not bottomPanelOpen
	local panel = UIController.GetElement("BottomPanel")
	if panel then
		local target
		if bottomPanelOpen then
			-- Slide up: position panel so its top edge appears above screen bottom
			target = UDim2.new(0.5, 0, 1, -(PANEL_HEIGHT + 10))
		else
			-- Slide down: fully hidden below screen edge
			target = UDim2.new(0.5, 0, 1, PANEL_HEIGHT + 10)
		end
		TweenService:Create(panel, TweenInfo.new(0.35, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
			Position = target
		}):Play()
	end
end

function UIController.IsBottomPanelOpen(): boolean
	return bottomPanelOpen
end

-------------------------------------------------
-- Toast
-------------------------------------------------
function UIController.ShowToast(message: string, isSuccess: boolean)
	local toast = UIController.GetElement("TradeToast")
	if not toast then return end
	local tt = toast:FindFirstChild("ToastText")
	if tt then tt.Text = message; tt.TextColor3 = isSuccess and Colors.green or Colors.red end
	local st = toast:FindFirstChildOfClass("UIStroke")
	if st then st.Color = isSuccess and Colors.green or Colors.red end
	TweenService:Create(toast, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.5, 0, 0, 12)
	}):Play()
	task.delay(3, function()
		TweenService:Create(toast, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Position = UDim2.new(0.5, 0, 0, -56)
		}):Play()
	end)
end

return UIController
