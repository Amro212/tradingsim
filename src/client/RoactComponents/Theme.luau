--[[
	Theme.luau — Design system for the trading terminal UI.
	Colors, fonts, spacing, and gradient presets used by all Roact components.
]]

local Theme = {}

-- ═══════════════════════════════════════════
-- COLOR PALETTE — Premium dark trading terminal
-- ═══════════════════════════════════════════
Theme.colors = {
	-- Backgrounds (layered depth)
	bg          = Color3.fromHex("#0B0E14"),
	bgCard      = Color3.fromHex("#131720"),
	bgElevated  = Color3.fromHex("#1A1F2E"),
	bgHover     = Color3.fromHex("#242B3D"),
	bgInput     = Color3.fromHex("#0F1219"),

	-- Borders & dividers
	border      = Color3.fromHex("#2A3042"),
	borderLight = Color3.fromHex("#3A4258"),

	-- Text
	textPrimary   = Color3.fromHex("#E8ECF4"),
	textSecondary = Color3.fromHex("#7A84A0"),
	textMuted     = Color3.fromHex("#4A526A"),

	-- Accents
	accent      = Color3.fromHex("#4F8EF7"),
	accentDim   = Color3.fromHex("#2D5BB5"),
	accentGlow  = Color3.fromHex("#6BA3FF"),

	-- Semantic
	green       = Color3.fromHex("#00D68F"),
	greenDim    = Color3.fromHex("#00A86B"),
	greenGlow   = Color3.fromHex("#33FFB0"),
	red         = Color3.fromHex("#FF4757"),
	redDim      = Color3.fromHex("#CC2233"),
	redGlow     = Color3.fromHex("#FF6B7A"),
	gold        = Color3.fromHex("#FFD32A"),
	goldDim     = Color3.fromHex("#E6B800"),
	orange      = Color3.fromHex("#FF8C42"),

	-- Special
	overlay     = Color3.fromHex("#000000"),
	white       = Color3.fromHex("#FFFFFF"),
}

-- ═══════════════════════════════════════════
-- FONTS
-- ═══════════════════════════════════════════
Theme.fonts = {
	bold   = Font.fromName("GothamSSm", Enum.FontWeight.Bold),
	medium = Font.fromName("GothamSSm", Enum.FontWeight.Medium),
	light  = Font.fromName("GothamSSm", Enum.FontWeight.Regular),
	mono   = Font.fromName("RobotoMono", Enum.FontWeight.Medium),
}

-- ═══════════════════════════════════════════
-- SIZING
-- ═══════════════════════════════════════════
Theme.size = {
	topBarHeight = 52,
	cornerRadius = 8,
	cornerRadiusLg = 12,
	cornerRadiusSm = 6,
	borderThickness = 1,
	strokeThickness = 1.5,

	-- Text sizes
	textXs = 10,
	textSm = 12,
	textMd = 14,
	textLg = 16,
	textXl = 18,
	text2xl = 22,
	text3xl = 28,

	-- Modal
	modalWidth = 740,
	modalHeight = 480,

	-- Bottom panel
	panelHeight = 300,
}

-- ═══════════════════════════════════════════
-- ANIMATION
-- ═══════════════════════════════════════════
Theme.animation = {
	fast      = TweenInfo.new(0.15, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
	normal    = TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
	smooth    = TweenInfo.new(0.4, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
	springy   = TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
	slideIn   = TweenInfo.new(0.35, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
	slideOut  = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
}

-- ═══════════════════════════════════════════
-- GRADIENT PRESETS (returned as props tables)
-- ═══════════════════════════════════════════
function Theme.gradient(colorA: Color3, colorB: Color3, rotation: number?): {}
	return {
		Color = ColorSequence.new(colorA, colorB),
		Rotation = rotation or 90,
	}
end

Theme.gradients = {
	topBar = function()
		return Theme.gradient(
			Color3.fromHex("#0B0E14"),
			Color3.fromHex("#111625"),
			90
		)
	end,
	card = function()
		return Theme.gradient(
			Color3.fromHex("#131720"),
			Color3.fromHex("#0F1219"),
			90
		)
	end,
	greenButton = function()
		return Theme.gradient(
			Color3.fromHex("#00D68F"),
			Color3.fromHex("#00A86B"),
			90
		)
	end,
	redButton = function()
		return Theme.gradient(
			Color3.fromHex("#FF4757"),
			Color3.fromHex("#CC2233"),
			90
		)
	end,
	accent = function()
		return Theme.gradient(
			Color3.fromHex("#4F8EF7"),
			Color3.fromHex("#2D5BB5"),
			90
		)
	end,
}

return Theme
