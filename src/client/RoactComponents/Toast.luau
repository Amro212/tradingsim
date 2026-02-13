--[[
	Toast.luau — Animated toast notification component.
	Slides in from top, auto-dismisses after 3 seconds.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Roact = require(ReplicatedStorage.Packages.Roact)
local Theme = require(script.Parent.Theme)

local Toast = Roact.Component:extend("Toast")

function Toast:init()
	self.frameRef = Roact.createRef()
	self._lastVisible = false
end

function Toast:render()
	local state = self.props.store:getState()
	local C = Theme.colors
	local F = Theme.fonts
	local S = Theme.size

	local msg = state.toastMessage or ""
	local isSuccess = state.toastSuccess
	local bgColor = isSuccess and C.greenDim or C.redDim
	local borderColor = isSuccess and C.green or C.red

	return Roact.createElement("Frame", {
		Name = "Toast",
		Size = UDim2.new(0, 360, 0, 48),
		Position = UDim2.new(0.5, 0, 0, -60), -- starts offscreen
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = bgColor,
		BackgroundTransparency = 0.1,
		BorderSizePixel = 0,
		ZIndex = 100,
		[Roact.Ref] = self.frameRef,
	}, {
		Corner = Roact.createElement("UICorner", {
			CornerRadius = UDim.new(0, S.cornerRadius),
		}),
		Stroke = Roact.createElement("UIStroke", {
			Color = borderColor,
			Thickness = 1.5,
			Transparency = 0.3,
		}),
		Label = Roact.createElement("TextLabel", {
			Size = UDim2.new(1, -20, 1, 0),
			Position = UDim2.new(0, 10, 0, 0),
			BackgroundTransparency = 1,
			FontFace = F.medium,
			TextSize = S.textMd,
			TextColor3 = C.textPrimary,
			Text = msg,
			TextWrapped = true,
		}),
	})
end

function Toast:didUpdate()
	local state = self.props.store:getState()
	local frame = self.frameRef:getValue()
	if not frame then return end

	if state.toastVisible and not self._lastVisible then
		-- Slide in
		frame.Position = UDim2.new(0.5, 0, 0, -60)
		TweenService:Create(frame, Theme.animation.springy, {
			Position = UDim2.new(0.5, 0, 0, 16)
		}):Play()
	elseif not state.toastVisible and self._lastVisible then
		-- Slide out
		TweenService:Create(frame, Theme.animation.slideOut, {
			Position = UDim2.new(0.5, 0, 0, -60)
		}):Play()
	end
	self._lastVisible = state.toastVisible
end

return Toast
