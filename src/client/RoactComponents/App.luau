--[[
	App.luau — Root Roact component that composes all UI elements.
	Mounted into the ScreenGui by init.client.luau.
	M1: Added MarketList for the global market overview.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Roact = require(ReplicatedStorage.Packages.Roact)

local TopBar          = require(script.Parent.TopBar)
local MarketList      = require(script.Parent.MarketList)
local TradeModal      = require(script.Parent.TradeModal)
local BottomPanel     = require(script.Parent.BottomPanel)
local Toast           = require(script.Parent.Toast)
local TutorialOverlay = require(script.Parent.TutorialOverlay)

local App = Roact.Component:extend("App")

function App:init()
	self._unsubscribe = self.props.store:subscribe(function()
		if self._isMounted then
			self:setState({})
		end
	end)
	self._isMounted = false
end

function App:didMount()
	self._isMounted = true
end

function App:willUnmount()
	self._isMounted = false
	if self._unsubscribe then
		self._unsubscribe()
	end
end

function App:render()
	local store = self.props.store

	return Roact.createElement("Frame", {
		Name = "AppRoot",
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, {
		TopBarEl = Roact.createElement(TopBar, {
			store = store,
		}),

		-- M1: Market list (opens when player interacts with terminal)
		MarketListEl = Roact.createElement(MarketList, {
			store = store,
		}),

		TradeModalEl = Roact.createElement(TradeModal, {
			store = store,
			onChartReady = self.props.onChartReady,
		}),

		BottomPanelEl = Roact.createElement(BottomPanel, {
			store = store,
		}),

		ToastEl = Roact.createElement(Toast, {
			store = store,
		}),

		TutorialEl = Roact.createElement(TutorialOverlay, {
			store = store,
			started = self.props.tutorialStarted,
		}),
	})
end

return App
