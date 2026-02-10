--[[
	TutorialController.luau — First-time onboarding for 3D trading floor.
	Shows tooltip popups explaining the trading floor experience.
]]

local TweenService = game:GetService("TweenService")

local TutorialController = {}
local UIController = nil
local tutorialDone = false

local STEPS = {
	{ title = "Welcome to Memecoin Trader! 💹", body = "Walk around the trading floor and trade virtual memecoins. Grow your portfolio and become the ultimate degen!" },
	{ title = "🏪 Trading Stations", body = "Walk up to any glowing station to see a coin's live price. Press E to open the trading panel!" },
	{ title = "💰 Your Cash", body = "You start with $10,000. Check your balance in the top bar. Spend wisely!" },
	{ title = "📈 Buy & Sell", body = "Use the trade panel to Buy or Sell. Use the quick % buttons to fill amounts fast." },
	{ title = "📰 Watch the News!", body = "Events like whale dumps and influencer tweets move prices. Open Portfolio at the bottom to see news, holdings, and trade history." },
	{ title = "🚀 Let's Trade!", body = "Walk to a station and place your first trade. Good luck, trader!" },
}

function TutorialController.Init(uiCtrl)
	UIController = uiCtrl
end

function TutorialController.ShouldShow(isDone: boolean)
	tutorialDone = isDone
end

function TutorialController.Start()
	if tutorialDone then return end
	local gui = UIController.GetElement("TopBar")
	if not gui then return end
	local parent = gui.Parent -- the ScreenGui
	local C = UIController.Colors

	local overlay = UIController.makeFrame({
		name = "TutorialOverlay", size = UDim2.new(1, 0, 1, 0),
		bg = Color3.new(0, 0, 0), parent = parent,
	})
	overlay.BackgroundTransparency = 0.5
	overlay.ZIndex = 200

	local stepIdx = 1
	local function showStep()
		for _, c in overlay:GetChildren() do c:Destroy() end
		local step = STEPS[stepIdx]
		if not step then overlay:Destroy(); return end

		local card = UIController.makeFrame({
			name = "Card", size = UDim2.new(0, 420, 0, 170),
			pos = UDim2.new(0.5, 0, 0.5, 0), anchor = Vector2.new(0.5, 0.5),
			bg = C.bgSecondary, corner = 12, stroke = 2, strokeColor = C.accent, parent = overlay,
		})
		card.ZIndex = 201

		UIController.makeLabel({ name = "T", text = step.title,
			font = UIController.FONT_BOLD, textSize = 18, color = C.gold,
			size = UDim2.new(1, -24, 0, 28), pos = UDim2.new(0, 12, 0, 14),
			alignX = Enum.TextXAlignment.Center, parent = card,
		}).ZIndex = 202

		local body = UIController.makeLabel({ name = "B", text = step.body,
			font = UIController.FONT_LIGHT, textSize = 14, color = C.textPrimary,
			size = UDim2.new(1, -32, 0, 50), pos = UDim2.new(0, 16, 0, 48),
			alignX = Enum.TextXAlignment.Center, parent = card,
		})
		body.TextWrapped = true; body.ZIndex = 202

		UIController.makeLabel({ name = "Ct", text = stepIdx .. " / " .. #STEPS,
			textSize = 11, color = C.textSecondary,
			size = UDim2.new(1, 0, 0, 16), pos = UDim2.new(0, 0, 0, 108),
			alignX = Enum.TextXAlignment.Center, parent = card,
		}).ZIndex = 202

		local isLast = stepIdx == #STEPS
		local nb = UIController.makeButton({ name = "Next",
			text = isLast and "Start Trading! 🚀" or "Next →",
			size = UDim2.new(0, 160, 0, 34), pos = UDim2.new(0.5, 0, 1, -42),
			anchor = Vector2.new(0.5, 0), bg = C.accent, hoverBg = C.accentDim,
			corner = 8, parent = card,
		})
		nb.ZIndex = 202
		nb.MouseButton1Click:Connect(function() stepIdx += 1; showStep() end)

		card.Size = UDim2.new(0, 0, 0, 0)
		TweenService:Create(card, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Size = UDim2.new(0, 420, 0, 170)
		}):Play()
	end
	showStep()
end

return TutorialController
