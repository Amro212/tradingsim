--[[
	PortfolioController.luau — Holdings table and trade history.
	Renders portfolio positions with unrealized PnL, and trade log entries.
	Bottom panel tabs (shared with NewsController).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Coins = require(ReplicatedStorage.Shared.Coins)
local Formatting = require(ReplicatedStorage.Shared.Formatting)

local PortfolioController = {}
local UIController = nil
local MarketController = nil
local TradeController = nil
local holdingRows: {[string]: Frame} = {}
local tradeHistory: {} = {}

function PortfolioController.Init(uiCtrl, marketCtrl, tradeCtrl)
	UIController = uiCtrl
	MarketController = marketCtrl
	TradeController = tradeCtrl
end

function PortfolioController.RefreshHoldings()
	local tab = UIController.GetElement("BottomPanel.TabContent.PortfolioTab")
	if not tab then return end
	local C = UIController.Colors
	local holdings = TradeController.GetHoldings()

	for _, row in holdingRows do row:Destroy() end
	holdingRows = {}

	local header = UIController.makeFrame({ name = "Header", size = UDim2.new(1,-4,0,24), bg = C.bgTertiary, corner = 4 })
	header.LayoutOrder = 0
	header.Parent = tab
	holdingRows["__header"] = header

	local cols = {"Coin","Qty","Avg Entry","Price","Value","PnL"}
	local widths = {0.15, 0.15, 0.17, 0.17, 0.18, 0.18}
	local xOff = 0
	for i, col in cols do
		UIController.makeLabel({
			name = "H"..i, text = col, font = UIController.FONT_BOLD, textSize = 10,
			color = C.textSecondary, size = UDim2.new(widths[i],0,1,0),
			pos = UDim2.new(xOff, 4, 0, 0), alignX = Enum.TextXAlignment.Center, parent = header,
		})
		xOff += widths[i]
	end

	local order = 1
	for coinId, h in holdings do
		if h.qty <= 0.001 then continue end
		local def = Coins.ById[coinId]
		if not def then continue end
		local price = MarketController.GetCoinPrice(coinId)
		local value = h.qty * price
		local pnl = h.qty * (price - h.avgEntry)
		local row = UIController.makeFrame({ name = "Row_"..coinId, size = UDim2.new(1,-4,0,28), bg = C.bgTertiary, corner = 4 })
		row.LayoutOrder = order
		order += 1
		local vals = {def.icon.." "..def.ticker, Formatting.formatQty(h.qty), Formatting.formatPrice(h.avgEntry), Formatting.formatPrice(price), Formatting.formatCash(value), Formatting.formatCash(pnl)}
		local colors = {C.textPrimary, C.textPrimary, C.textSecondary, C.textPrimary, C.textPrimary, pnl >= 0 and C.green or C.red}
		xOff = 0
		for i, val in vals do
			UIController.makeLabel({
				name = "C"..i, text = val, textSize = 11, color = colors[i],
				size = UDim2.new(widths[i],0,1,0), pos = UDim2.new(xOff,4,0,0),
				alignX = Enum.TextXAlignment.Center, parent = row,
			})
			xOff += widths[i]
		end
		row.Parent = tab
		holdingRows[coinId] = row
	end

	if order == 1 then
		local empty = UIController.makeLabel({
			name = "EmptyMsg", text = "No holdings yet. Walk to a station and start trading!", textSize = 13,
			color = C.textSecondary, size = UDim2.new(1,0,0,40),
			alignX = Enum.TextXAlignment.Center, parent = tab,
		})
		empty.LayoutOrder = 1
	end
end

function PortfolioController.AddTradeEntry(entry: {})
	table.insert(tradeHistory, 1, entry)
	if #tradeHistory > 50 then table.remove(tradeHistory) end
	PortfolioController.RefreshHistory()
end

function PortfolioController.RefreshHistory()
	local tab = UIController.GetElement("BottomPanel.TabContent.HistoryTab")
	if not tab then return end
	local C = UIController.Colors
	for _, child in tab:GetChildren() do
		if child:IsA("Frame") or child:IsA("TextLabel") then child:Destroy() end
	end
	for i, entry in tradeHistory do
		if i > 30 then break end
		local pnlStr = entry.pnl and " PnL:"..Formatting.formatCash(entry.pnl) or ""
		local text = (entry.action=="BUY" and "🟢" or "🔴") .. " " .. entry.action .. " "
			.. Formatting.formatQty(entry.qty) .. " " .. (entry.coinId or "?")
			.. " @ " .. Formatting.formatPrice(entry.price or 0) .. pnlStr
		local row = UIController.makeLabel({
			name = "Trade"..i, text = text, textSize = 11,
			color = entry.action == "BUY" and C.green or C.red,
			size = UDim2.new(1,-8,0,22), parent = tab,
		})
		row.LayoutOrder = i
	end
end

function PortfolioController.SetTradeHistory(history: {})
	tradeHistory = history or {}
	PortfolioController.RefreshHistory()
end

return PortfolioController
