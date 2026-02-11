--[[
	TradeController.luau — Order panel logic for modal-based trading.
	Handles Buy/Sell toggle, qty input, quick %, fires RequestTrade,
	and shows result toasts. Works within the TradeModal popup.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Config = require(ReplicatedStorage.Shared.Config)
local Formatting = require(ReplicatedStorage.Shared.Formatting)

local TradeController = {}
local UIController = nil
local MarketController = nil
local currentAction = "BUY"
local playerCash = Config.STARTING_CASH
local playerHoldings: {[string]: {qty: number, avgEntry: number}} = {}

function TradeController.Init(uiCtrl, marketCtrl)
	UIController = uiCtrl
	MarketController = marketCtrl

	-- Find order panel inside TradeModal
	local op = UIController.GetElement("TradeOverlay.TradeModal.OrderPanel")
	if not op then return end

	local toggle = op:FindFirstChild("BuySellToggle")
	if toggle then
		local bb = toggle:FindFirstChild("BuyToggle")
		local sb = toggle:FindFirstChild("SellToggle")
		if bb then bb.MouseButton1Click:Connect(function() TradeController.SetAction("BUY") end) end
		if sb then sb.MouseButton1Click:Connect(function() TradeController.SetAction("SELL") end) end
	end

	local qb = op:FindFirstChild("QuickButtons")
	if qb then
		for _, btn in qb:GetChildren() do
			if btn:IsA("TextButton") then
				btn.MouseButton1Click:Connect(function()
					local pct = tonumber(btn.Text:gsub("%%",""))
					if pct then TradeController.SetQuickPercent(pct/100) end
				end)
			end
		end
	end

	local qi = op:FindFirstChild("QtyInput")
	if qi then qi:GetPropertyChangedSignal("Text"):Connect(function() TradeController.UpdateCostPreview() end) end

	local eb = op:FindFirstChild("ExecuteBtn")
	if eb then eb.MouseButton1Click:Connect(function() TradeController.ExecuteTrade() end) end

	-- Close button
	local header = UIController.GetElement("TradeOverlay.TradeModal.ModalHeader")
	if header then
		local cb = header:FindFirstChild("CloseBtn")
		if cb then cb.MouseButton1Click:Connect(function() UIController.CloseTradeModal() end) end
	end

	TradeController.SetAction("BUY")
end

function TradeController.SetAction(action: string)
	currentAction = action
	local C = UIController.Colors
	local op = UIController.GetElement("TradeOverlay.TradeModal.OrderPanel")
	if not op then return end
	local t = op:FindFirstChild("BuySellToggle")
	if t then
		local b, s = t:FindFirstChild("BuyToggle"), t:FindFirstChild("SellToggle")
		if b and s then
			if action=="BUY" then b.BackgroundColor3=C.green; s.BackgroundColor3=C.bgHover
			else b.BackgroundColor3=C.bgHover; s.BackgroundColor3=C.red end
		end
	end
	local eb = op:FindFirstChild("ExecuteBtn")
	if eb then
		eb.Text = action=="BUY" and "BUY NOW" or "SELL NOW"
		eb.BackgroundColor3 = action=="BUY" and C.green or C.red
	end
	TradeController.UpdateCostPreview()
	TradeController.UpdateHoldingInfo()
end

function TradeController.SetQuickPercent(pct: number)
	local cid = MarketController.GetSelectedCoinId()
	if not cid then return end
	local price = MarketController.GetCoinPrice(cid)
	if price <= 0 then return end
	local op = UIController.GetElement("TradeOverlay.TradeModal.OrderPanel")
	if not op then return end
	local qi = op:FindFirstChild("QtyInput")
	if not qi then return end
	if currentAction == "BUY" then
		local maxQ = (playerCash * pct) / (price * (1 + Config.TRADE_FEE_PCT + Config.SLIPPAGE_BASE_PCT))
		qi.Text = Formatting.formatQty(math.floor(maxQ * 100) / 100)
	else
		local h = playerHoldings[cid]
		qi.Text = (h and h.qty > 0) and Formatting.formatQty(math.floor(h.qty * pct * 100)/100) or "0"
	end
end

function TradeController.UpdateCostPreview()
	local op = UIController.GetElement("TradeOverlay.TradeModal.OrderPanel")
	if not op then return end
	local cp = op:FindFirstChild("CostPreview")
	local qi = op:FindFirstChild("QtyInput")
	if not cp or not qi then return end
	local cid = MarketController.GetSelectedCoinId()
	if not cid then cp.Text = ""; return end
	local qty = tonumber(qi.Text)
	if not qty or qty <= 0 then cp.Text = ""; return end
	local price = MarketController.GetCoinPrice(cid)
	if price <= 0 then return end
	if currentAction == "BUY" then
		cp.Text = "Est. cost: " .. Formatting.formatCash(qty * price * (1+Config.TRADE_FEE_PCT+Config.SLIPPAGE_BASE_PCT))
	else
		cp.Text = "Est. proceeds: " .. Formatting.formatCash(qty * price * (1-Config.TRADE_FEE_PCT-Config.SLIPPAGE_BASE_PCT))
	end
end

function TradeController.UpdateHoldingInfo()
	local op = UIController.GetElement("TradeOverlay.TradeModal.OrderPanel")
	if not op then return end
	local hi = op:FindFirstChild("HoldingInfo")
	if not hi then return end
	local cid = MarketController.GetSelectedCoinId()
	if not cid then hi.Text = ""; return end
	local h = playerHoldings[cid]
	if h and h.qty > 0 then
		local price = MarketController.GetCoinPrice(cid)
		local pnl = h.qty * (price - h.avgEntry)
		hi.Text = "Holding: " .. Formatting.formatQty(h.qty) .. " @ " .. Formatting.formatPrice(h.avgEntry)
			.. "\nPnL: " .. Formatting.formatCash(pnl)
		hi.TextColor3 = pnl >= 0 and UIController.Colors.green or UIController.Colors.red
	else
		hi.Text = "No holdings for this coin"
		hi.TextColor3 = UIController.Colors.textSecondary
	end
end

function TradeController.ExecuteTrade()
	local cid = MarketController.GetSelectedCoinId()
	if not cid then UIController.ShowToast("Select a coin first!", false); return end
	local op = UIController.GetElement("TradeOverlay.TradeModal.OrderPanel")
	if not op then return end
	local qi = op:FindFirstChild("QtyInput")
	if not qi then return end
	local qty = tonumber(qi.Text)
	if not qty or qty <= 0 then UIController.ShowToast("Enter a valid quantity!", false); return end
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	if remotes then
		local rt = remotes:FindFirstChild("RequestTrade")
		if rt then rt:FireServer(currentAction, cid, qty) end
	end
	local eb = op:FindFirstChild("ExecuteBtn")
	if eb then
		eb.Text = "⏳..."
		task.delay(0.5, function() if eb.Parent then eb.Text = currentAction=="BUY" and "BUY NOW" or "SELL NOW" end end)
	end
end

function TradeController.OnTradeResult(result: {})
	if result.ok then UIController.ShowToast("✅ " .. result.message, true)
	else UIController.ShowToast("❌ " .. result.message, false) end
	if result.newCash then playerCash = result.newCash; TradeController.UpdateTopBar() end
	if result.coinId and result.holding then playerHoldings[result.coinId] = result.holding end
	TradeController.UpdateHoldingInfo()
	if result.ok then
		local op = UIController.GetElement("TradeOverlay.TradeModal.OrderPanel")
		if op then local qi = op:FindFirstChild("QtyInput"); if qi then qi.Text = "" end end
	end
end

function TradeController.UpdateTopBar()
	local tb = UIController.GetElement("TopBar")
	if not tb then return end
	local C = UIController.Colors
	local cv = tb:FindFirstChild("CashValue", true)
	if cv then cv.Text = Formatting.formatCash(playerCash) end
	local totalVal, totalPnL = playerCash, 0
	for cid, h in playerHoldings do
		if h.qty > 0 then
			local p = MarketController.GetCoinPrice(cid)
			totalVal += h.qty * p
			totalPnL += h.qty * (p - h.avgEntry)
		end
	end
	local pv = tb:FindFirstChild("PortfolioValue", true)
	if pv then pv.Text = Formatting.formatCash(totalVal) end
	local pl = tb:FindFirstChild("PnLValue", true)
	if pl then pl.Text = Formatting.formatCash(totalPnL); pl.TextColor3 = totalPnL >= 0 and C.green or C.red end
end

function TradeController.SetPlayerState(state: {})
	if state.cash then playerCash = state.cash end
	if state.holdings then
		playerHoldings = {}
		for cid, h in state.holdings do
			playerHoldings[cid] = { qty = h.qty or 0, avgEntry = h.avgEntry or 0 }
		end
	end
	TradeController.UpdateTopBar()
end

function TradeController.GetCash(): number return playerCash end
function TradeController.GetHoldings() return playerHoldings end

return TradeController
