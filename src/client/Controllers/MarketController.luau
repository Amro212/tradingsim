--[[
	MarketController.luau — Market data management for 3D mode.
	No coin list UI — just tracks data and handles coin selection
	triggered by StationController ProximityPrompts.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Coins = require(ReplicatedStorage.Shared.Coins)
local Formatting = require(ReplicatedStorage.Shared.Formatting)

local MarketController = {}

local UIController = nil
local _ChartRenderer = nil
local selectedCoinId: string? = nil
local latestMarketData: {[string]: {}} = {}
local onCoinSelectedCallbacks: {(string) -> ()} = {}

function MarketController.Init(uiCtrl, chartRend)
	UIController = uiCtrl
	ChartRenderer = chartRend
end

function MarketController.SelectCoin(coinId: string)
	selectedCoinId = coinId
	local coinDef = Coins.ById[coinId]
	if not coinDef then return end

	local _C = UIController.Colors
	-- Update modal header
	local overlay = UIController.GetElement("TradeOverlay")
	if overlay then
		local modal = overlay:FindFirstChild("TradeModal")
		if modal then
			local header = modal:FindFirstChild("ModalHeader")
			if header then
				local nameL = header:FindFirstChild("SelectedCoinName")
				if nameL then nameL.Text = coinDef.icon .. " " .. coinDef.name .. " (" .. coinDef.ticker .. ")" end
			end
		end
	end

	-- Update price display
	local data = latestMarketData[coinId]
	if data then MarketController._updateModalPrice(data.p, data.cp) end

	-- Request chart history
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	if remotes then
		local hr = remotes:FindFirstChild("CoinHistory")
		if hr then hr:FireServer(coinId) end
	end

	for _, cb in onCoinSelectedCallbacks do cb(coinId) end
end

function MarketController.GetSelectedCoinId(): string? return selectedCoinId end
function MarketController.OnCoinSelected(cb: (string) -> ()) table.insert(onCoinSelectedCallbacks, cb) end

function MarketController.UpdateMarket(snapshot: {})
	for _, coinData in snapshot.coins do
		latestMarketData[coinData.id] = coinData
	end
	-- Update modal price if open
	if selectedCoinId then
		local data = latestMarketData[selectedCoinId]
		if data then MarketController._updateModalPrice(data.p, data.cp) end
	end
end

function MarketController._updateModalPrice(price: number, changePct: number)
	local C = UIController.Colors
	local overlay = UIController.GetElement("TradeOverlay")
	if not overlay then return end
	local modal = overlay:FindFirstChild("TradeModal")
	if not modal then return end
	local header = modal:FindFirstChild("ModalHeader")
	if not header then return end
	local pl = header:FindFirstChild("SelectedCoinPrice")
	if pl then
		pl.Text = Formatting.formatPrice(price) .. "  " .. Formatting.formatPct(changePct)
		pl.TextColor3 = changePct >= 0 and C.green or C.red
	end
end

function MarketController.GetCoinPrice(coinId: string): number
	local data = latestMarketData[coinId]
	return data and data.p or 0
end

function MarketController.GetLatestData() return latestMarketData end

return MarketController
