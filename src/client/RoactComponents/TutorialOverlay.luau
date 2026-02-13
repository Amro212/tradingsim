--[[
	TutorialOverlay.luau — First-time player tutorial cards.
	Shows step-by-step instructions, marks complete via store.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Roact = require(ReplicatedStorage.Packages.Roact)
local Theme = require(script.Parent.Theme)

local STEPS = {
	{ title = "Welcome, Trader!", body = "You've entered the Memecoin Trading Floor. Walk around and explore the hub!" },
	{ title = "Sprint", body = "Hold LEFT SHIFT to sprint between stations faster." },
	{ title = "Trading Terminals", body = "Walk up to any terminal in the Trading Row and press E to open the Market." },
	{ title = "Market List", body = "Browse all coins — sorted by top movers. Click any coin to open the trading view." },
	{ title = "Make Your First Trade", body = "Use BUY/SELL buttons, enter a quantity, and hit Execute!" },
	{ title = "Your Cash", body = "You start with $10,000. Check your balance in the top bar." },
	{ title = "Portfolio & History", body = "Toggle the bottom panel for your holdings, trade history, and market news." },
	{ title = "Good Luck!", body = "Trade smart, watch the charts, and may your memecoins moon!" },
}

local TutorialOverlay = Roact.Component:extend("TutorialOverlay")

function TutorialOverlay:init()
	self:setState({ step = 1 })
	self.overlayRef = Roact.createRef()
end

function TutorialOverlay:render()
	local store = self.props.store
	local storeState = store:getState()

	-- Don't show if tutorial done or not started yet
	if storeState.tutorialDone or not self.props.started then
		return nil
	end

	local C = Theme.colors
	local F = Theme.fonts
	local S = Theme.size
	local step = STEPS[self.state.step]
	if not step then return nil end

	local isLast = (self.state.step == #STEPS)
	local progress = self.state.step .. " / " .. #STEPS

	return Roact.createElement("Frame", {
		Name = "TutorialOverlay",
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundColor3 = C.overlay,
		BackgroundTransparency = 0.5,
		BorderSizePixel = 0,
		ZIndex = 200,
		[Roact.Ref] = self.overlayRef,
	}, {
		Card = Roact.createElement("Frame", {
			Name = "Card",
			Size = UDim2.new(0, 420, 0, 220),
			Position = UDim2.new(0.5, 0, 0.5, 0),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = C.bgCard,
			BorderSizePixel = 0,
		}, {
			Corner = Roact.createElement("UICorner", {
				CornerRadius = UDim.new(0, S.cornerRadiusLg),
			}),
			Stroke = Roact.createElement("UIStroke", {
				Color = C.accent,
				Thickness = 1.5,
				Transparency = 0.4,
			}),
			Gradient = Roact.createElement("UIGradient", Theme.gradients.card()),

			Title = Roact.createElement("TextLabel", {
				Name = "Title",
				Size = UDim2.new(1, -40, 0, 36),
				Position = UDim2.new(0, 20, 0, 24),
				BackgroundTransparency = 1,
				FontFace = F.bold,
				TextSize = S.text2xl,
				TextColor3 = C.gold,
				Text = step.title,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),

			Body = Roact.createElement("TextLabel", {
				Name = "Body",
				Size = UDim2.new(1, -40, 0, 60),
				Position = UDim2.new(0, 20, 0, 68),
				BackgroundTransparency = 1,
				FontFace = F.light,
				TextSize = S.textMd,
				TextColor3 = C.textPrimary,
				Text = step.body,
				TextWrapped = true,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Top,
			}),

			Progress = Roact.createElement("TextLabel", {
				Name = "Progress",
				Size = UDim2.new(0, 60, 0, 20),
				Position = UDim2.new(0, 20, 1, -44),
				BackgroundTransparency = 1,
				FontFace = F.light,
				TextSize = S.textSm,
				TextColor3 = C.textSecondary,
				Text = progress,
			}),

			NextBtn = Roact.createElement("TextButton", {
				Name = "NextBtn",
				Size = UDim2.new(0, 120, 0, 36),
				Position = UDim2.new(1, -20, 1, -44),
				AnchorPoint = Vector2.new(1, 0),
				BackgroundColor3 = isLast and C.green or C.accent,
				BorderSizePixel = 0,
				FontFace = F.bold,
				TextSize = S.textMd,
				TextColor3 = C.white,
				Text = isLast and "Start Trading!" or "Next →",
				[Roact.Event.MouseButton1Click] = function()
					if isLast then
						store:setTutorialDone()
					else
						self:setState({ step = self.state.step + 1 })
					end
				end,
			}, {
				Corner = Roact.createElement("UICorner", {
					CornerRadius = UDim.new(0, S.cornerRadius),
				}),
			}),
		}),
	})
end

return TutorialOverlay
