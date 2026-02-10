--[[
	TradeService.luau — Server-authoritative trade execution.
	Validates all orders, applies fees/slippage, updates player holdings.
	Never trusts client-provided prices or balances.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local CoinsModule = require(ReplicatedStorage.Shared.Coins)
local Formatting = require(ReplicatedStorage.Shared.Formatting)

local TradeService = {}

-- Dependencies (injected)
local MarketService = nil
local PlayerService = nil
local tradeResultRemote: RemoteEvent = nil

-------------------------------------------------
-- Initialize
-------------------------------------------------
function TradeService.Init(remotes: {[string]: any}, marketSvc: any, playerSvc: any)
	tradeResultRemote = remotes.TradeResult
	MarketService = marketSvc
	PlayerService = playerSvc
end

-------------------------------------------------
-- Validate & execute a trade
-------------------------------------------------
function TradeService.ExecuteTrade(player: Player, action: string, coinId: string, qty: number)
	-- === VALIDATION LAYER ===

	-- Type checks
	if type(action) ~= "string" then
		return TradeService._reject(player, "Invalid action type.")
	end
	if type(coinId) ~= "string" then
		return TradeService._reject(player, "Invalid coin ID type.")
	end
	if type(qty) ~= "number" then
		return TradeService._reject(player, "Invalid quantity type.")
	end

	-- Action must be BUY or SELL
	action = string.upper(action)
	if action ~= "BUY" and action ~= "SELL" then
		return TradeService._reject(player, "Action must be BUY or SELL.")
	end

	-- Coin must exist
	local coinDef = CoinsModule.ById[coinId]
	if not coinDef then
		return TradeService._reject(player, "Unknown coin: " .. tostring(coinId))
	end

	-- Qty must be valid number
	if qty ~= qty then -- NaN check
		return TradeService._reject(player, "Quantity is NaN.")
	end
	if qty <= 0 then
		return TradeService._reject(player, "Quantity must be positive.")
	end
	if qty > Config.MAX_TRADE_QTY then
		return TradeService._reject(player, "Quantity exceeds maximum.")
	end
	if qty < Config.MIN_TRADE_QTY then
		return TradeService._reject(player, "Quantity below minimum.")
	end
	if qty == math.huge then
		return TradeService._reject(player, "Invalid quantity.")
	end

	-- Rate limit check
	if not PlayerService.CheckRateLimit(player) then
		return TradeService._reject(player, "Too many trades! Slow down.")
	end

	-- Get server price (NEVER from client)
	local price = MarketService.GetPrice(coinId)
	if not price or price <= 0 then
		return TradeService._reject(player, "Market unavailable for this coin.")
	end

	-- Get player state
	local pState = PlayerService.GetState(player)
	if not pState then
		return TradeService._reject(player, "Player data not loaded yet.")
	end

	-- === EXECUTION ===

	-- Calculate slippage: base + (qty / liquidity factor)
	local slippagePct = Config.SLIPPAGE_BASE_PCT + (qty * 0.000001) / math.max(coinDef.liquidity, 0.1)
	local feePct = Config.TRADE_FEE_PCT

	if action == "BUY" then
		local effectivePrice = price * (1 + slippagePct) -- pay slightly more
		local totalCost = qty * effectivePrice
		local fee = totalCost * feePct
		local grandTotal = totalCost + fee

		-- Check cash
		if pState.cash < grandTotal then
			return TradeService._reject(player,
				"Not enough cash. Need " .. Formatting.formatCash(grandTotal)
				.. " but you have " .. Formatting.formatCash(pState.cash))
		end

		-- Deduct cash
		pState.cash = pState.cash - grandTotal

		-- Update holdings
		local holding = pState.holdings[coinId]
		if not holding then
			holding = { qty = 0, avgEntry = 0, realizedPnL = 0 }
			pState.holdings[coinId] = holding
		end

		-- Recalculate average entry price
		local totalQty = holding.qty + qty
		holding.avgEntry = ((holding.avgEntry * holding.qty) + (effectivePrice * qty)) / totalQty
		holding.qty = totalQty

		-- Log trade
		local tradeEntry = {
			action = "BUY",
			coinId = coinId,
			qty = qty,
			price = effectivePrice,
			fee = fee,
			total = grandTotal,
			time = workspace:GetServerTimeNow(),
		}
		PlayerService.AddTradeLog(player, tradeEntry)

		-- Update volume
		MarketService.AddVolume(coinId, qty)

		-- Stats
		pState.stats.totalTrades = (pState.stats.totalTrades or 0) + 1

		-- Send result
		tradeResultRemote:FireClient(player, {
			ok = true,
			message = "Bought " .. Formatting.formatQty(qty) .. " " .. coinId
				.. " @ " .. Formatting.formatPrice(effectivePrice),
			action = "BUY",
			coinId = coinId,
			newCash = pState.cash,
			holding = { qty = holding.qty, avgEntry = holding.avgEntry },
			trade = tradeEntry,
		})

	elseif action == "SELL" then
		local holding = pState.holdings[coinId]
		if not holding or holding.qty <= 0 then
			return TradeService._reject(player, "You don't hold any " .. coinId .. ".")
		end
		if qty > holding.qty then
			return TradeService._reject(player,
				"Can't sell " .. Formatting.formatQty(qty)
				.. ". You hold " .. Formatting.formatQty(holding.qty) .. ".")
		end

		local effectivePrice = price * (1 - slippagePct) -- get slightly less
		local totalProceeds = qty * effectivePrice
		local fee = totalProceeds * feePct
		local netProceeds = totalProceeds - fee

		-- Realized PnL for this sale
		local costBasis = qty * holding.avgEntry
		local realizedPnL = netProceeds - costBasis

		-- Credit cash
		pState.cash = pState.cash + netProceeds

		-- Update holdings
		holding.qty = holding.qty - qty
		holding.realizedPnL = (holding.realizedPnL or 0) + realizedPnL

		-- Clean up if fully sold
		if holding.qty < Config.MIN_TRADE_QTY then
			holding.qty = 0
		end

		-- Log trade
		local tradeEntry = {
			action = "SELL",
			coinId = coinId,
			qty = qty,
			price = effectivePrice,
			fee = fee,
			total = netProceeds,
			pnl = realizedPnL,
			time = workspace:GetServerTimeNow(),
		}
		PlayerService.AddTradeLog(player, tradeEntry)

		-- Update volume
		MarketService.AddVolume(coinId, qty)

		-- Stats
		pState.stats.totalTrades = (pState.stats.totalTrades or 0) + 1
		pState.stats.totalPnL = (pState.stats.totalPnL or 0) + realizedPnL
		if realizedPnL > (pState.stats.bestTrade or 0) then
			pState.stats.bestTrade = realizedPnL
		end

		-- Send result
		tradeResultRemote:FireClient(player, {
			ok = true,
			message = "Sold " .. Formatting.formatQty(qty) .. " " .. coinId
				.. " @ " .. Formatting.formatPrice(effectivePrice)
				.. " (PnL: " .. Formatting.formatCash(realizedPnL) .. ")",
			action = "SELL",
			coinId = coinId,
			newCash = pState.cash,
			holding = { qty = holding.qty, avgEntry = holding.avgEntry },
			trade = tradeEntry,
		})
	end
end

-------------------------------------------------
-- Reject helper
-------------------------------------------------
function TradeService._reject(player: Player, message: string)
	if tradeResultRemote then
		tradeResultRemote:FireClient(player, {
			ok = false,
			message = message,
		})
	end
end

return TradeService
