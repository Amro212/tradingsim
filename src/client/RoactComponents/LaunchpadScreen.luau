--[[
	LaunchpadScreen.luau — Roact SurfaceGui for the Launchpad Stage screen.
	Shows countdown to next launch + recently launched coin info.
	Mounted on the LaunchScreen Part in Station B.
	WORLD_SPEC Station B: "Countdown to next launch, recently launched coin info."
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Roact = require(ReplicatedStorage.Packages.Roact)

local Theme = require(script.Parent.Theme)
local Formatting = require(ReplicatedStorage.Shared.Formatting)

local LaunchpadScreen = Roact.Component:extend("LaunchpadScreen")

local ACCENT = Color3.fromHex("#FF5078")

local function formatCountdown(seconds: number): string
	if seconds <= 0 then return "LAUNCHING..." end
	local m = math.floor(seconds / 60)
	local s = seconds % 60
	if m > 0 then
		return string.format("%d:%02d", m, s)
	end
	return string.format("0:%02d", s)
end

function LaunchpadScreen:render()
	local store = self.props.store
	local state = store:getState()
	local C = Theme.colors
	local F = Theme.fonts

	local countdown = state.launchCountdown or 0
	local recentLaunches = state.launchRecentLaunches or {}
	local latest = recentLaunches[1] -- most recent launch

	local children = {}

	-- Title
	children.Title = Roact.createElement("TextLabel", {
		Size = UDim2.new(1, 0, 0, 36),
		Position = UDim2.new(0, 0, 0, 10),
		BackgroundTransparency = 1,
		FontFace = F.bold,
		TextSize = 28,
		TextColor3 = ACCENT,
		Text = "LAUNCHPAD",
	})

	-- Divider
	children.Divider = Roact.createElement("Frame", {
		Size = UDim2.new(0.6, 0, 0, 2),
		Position = UDim2.new(0.2, 0, 0, 50),
		BackgroundColor3 = ACCENT,
		BorderSizePixel = 0,
	})

	-- Countdown section
	children.CountdownLabel = Roact.createElement("TextLabel", {
		Size = UDim2.new(1, 0, 0, 20),
		Position = UDim2.new(0, 0, 0, 60),
		BackgroundTransparency = 1,
		FontFace = F.medium,
		TextSize = 14,
		TextColor3 = C.textSecondary,
		Text = "NEXT LAUNCH IN",
	})

	children.CountdownValue = Roact.createElement("TextLabel", {
		Size = UDim2.new(1, 0, 0, 64),
		Position = UDim2.new(0, 0, 0, 80),
		BackgroundTransparency = 1,
		FontFace = F.mono,
		TextSize = 52,
		TextColor3 = if countdown <= 10 then Color3.fromHex("#FF4757") else C.textPrimary,
		Text = formatCountdown(countdown),
	})

	-- Latest launch info
	if latest then
		children.LatestLabel = Roact.createElement("TextLabel", {
			Size = UDim2.new(1, 0, 0, 18),
			Position = UDim2.new(0, 0, 0, 155),
			BackgroundTransparency = 1,
			FontFace = F.bold,
			TextSize = 12,
			TextColor3 = C.textMuted,
			Text = "LATEST LAUNCH",
		})

		children.LatestCoin = Roact.createElement("Frame", {
			Size = UDim2.new(0.8, 0, 0, 44),
			Position = UDim2.new(0.1, 0, 0, 178),
			BackgroundColor3 = C.bgElevated,
			BackgroundTransparency = 0.4,
			BorderSizePixel = 0,
		}, {
			Corner = Roact.createElement("UICorner", { CornerRadius = UDim.new(0, 6) }),
			Icon = Roact.createElement("TextLabel", {
				Size = UDim2.new(0, 30, 0, 30),
				Position = UDim2.new(0, 10, 0.5, 0),
				AnchorPoint = Vector2.new(0, 0.5),
				BackgroundTransparency = 1,
				FontFace = F.bold,
				TextSize = 20,
				TextColor3 = C.textPrimary,
				Text = latest.icon or "\u{1FA99}",
			}),
			Name = Roact.createElement("TextLabel", {
				Size = UDim2.new(0.5, 0, 0, 20),
				Position = UDim2.new(0, 44, 0, 4),
				BackgroundTransparency = 1,
				FontFace = F.bold,
				TextSize = 14,
				TextColor3 = C.textPrimary,
				Text = (latest.name or "???") .. " ($" .. (latest.ticker or "?") .. ")",
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
			}),
			Meta = Roact.createElement("TextLabel", {
				Size = UDim2.new(0.4, 0, 0, 16),
				Position = UDim2.new(0, 44, 0, 24),
				BackgroundTransparency = 1,
				FontFace = F.light,
				TextSize = 11,
				TextColor3 = ACCENT,
				Text = latest.meta or "?",
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
			Price = Roact.createElement("TextLabel", {
				Size = UDim2.new(0.3, 0, 1, 0),
				Position = UDim2.new(0.68, 0, 0, 0),
				BackgroundTransparency = 1,
				FontFace = F.mono,
				TextSize = 13,
				TextColor3 = C.textPrimary,
				Text = Formatting.formatPrice(latest.basePrice or 0),
				TextXAlignment = Enum.TextXAlignment.Right,
			}),
		})
	else
		children.NoLaunches = Roact.createElement("TextLabel", {
			Size = UDim2.new(1, 0, 0, 30),
			Position = UDim2.new(0, 0, 0, 165),
			BackgroundTransparency = 1,
			FontFace = F.medium,
			TextSize = 14,
			TextColor3 = C.textMuted,
			Text = "No launches yet...",
		})
	end

	-- Footer
	children.Footer = Roact.createElement("TextLabel", {
		Size = UDim2.new(1, 0, 0, 24),
		Position = UDim2.new(0, 0, 1, -30),
		BackgroundTransparency = 1,
		FontFace = F.medium,
		TextSize = 12,
		TextColor3 = ACCENT,
		Text = "[E] Open Launchpad",
	})

	return Roact.createElement("SurfaceGui", {
		Name = "LaunchpadGui",
		Face = Enum.NormalId.Front,
		SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud,
		PixelsPerStud = 50,
		ClipsDescendants = true,
	}, {
		BG = Roact.createElement("Frame", {
			Size = UDim2.new(1, 0, 1, 0),
			BackgroundColor3 = Color3.fromHex("#080812"),
			BorderSizePixel = 0,
		}, children),
	})
end

return LaunchpadScreen
