--[[
	Coins.luau — Definitions for all tradeable coins.
	Each coin has static properties used by MarketService to seed simulation.
	volatility / liquidity / trendBias shape how the price moves.
]]

export type CoinDef = {
	id: string,
	name: string,
	ticker: string,
	basePrice: number,
	volatility: number,   -- 0..1, higher = wilder swings
	liquidity: number,     -- 0..1, higher = less slippage
	trendBias: number,     -- negative = bearish, positive = bullish, 0 = neutral
	riskTag: string,       -- "Low" | "Medium" | "High" | "Extreme"
	icon: string,          -- emoji placeholder for UI
	description: string,
	accentColor: {number}, -- {R, G, B} 0-1 for station glow
}

local Coins: {CoinDef} = {
	{
		id = "BTC",
		name = "BlockBux",
		ticker = "BBX",
		basePrice = 420.00,
		volatility = 0.15,
		liquidity = 0.90,
		trendBias = 0.001,
		riskTag = "Low",
		icon = "🟡",
		description = "The OG. Stable and reliable.",
		accentColor = {0.94, 0.75, 0.0},
	},
	{
		id = "ETH",
		name = "EtherBlox",
		ticker = "ETB",
		basePrice = 210.00,
		volatility = 0.20,
		liquidity = 0.85,
		trendBias = 0.0005,
		riskTag = "Low",
		icon = "💎",
		description = "Smart contracts, smart gains.",
		accentColor = {0.38, 0.49, 0.92},
	},
	{
		id = "DOGE",
		name = "DogeRBX",
		ticker = "DGR",
		basePrice = 2.50,
		volatility = 0.45,
		liquidity = 0.60,
		trendBias = 0.002,
		riskTag = "Medium",
		icon = "🐕",
		description = "Much wow. Very coin. So trade.",
		accentColor = {0.76, 0.65, 0.20},
	},
	{
		id = "PEPE",
		name = "PepeCash",
		ticker = "PPC",
		basePrice = 0.50,
		volatility = 0.65,
		liquidity = 0.40,
		trendBias = 0.0,
		riskTag = "High",
		icon = "🐸",
		description = "Rare Pepe energy. Handle with care.",
		accentColor = {0.30, 0.69, 0.31},
	},
	{
		id = "MOON",
		name = "MoonShot",
		ticker = "MST",
		basePrice = 5.00,
		volatility = 0.55,
		liquidity = 0.50,
		trendBias = 0.003,
		riskTag = "High",
		icon = "🌙",
		description = "To the moon... or to zero.",
		accentColor = {0.61, 0.15, 0.69},
	},
	{
		id = "RUG",
		name = "RugPullInu",
		ticker = "RPI",
		basePrice = 0.10,
		volatility = 0.85,
		liquidity = 0.20,
		trendBias = -0.002,
		riskTag = "Extreme",
		icon = "🧶",
		description = "Will it rug? Probably. YOLO.",
		accentColor = {0.96, 0.26, 0.21},
	},
	{
		id = "CAT",
		name = "CatCoin",
		ticker = "CAT",
		basePrice = 1.20,
		volatility = 0.40,
		liquidity = 0.55,
		trendBias = 0.001,
		riskTag = "Medium",
		icon = "🐱",
		description = "Purrfect investment. Maybe.",
		accentColor = {1.0, 0.41, 0.71},
	},
	{
		id = "NOOB",
		name = "NoobToken",
		ticker = "NUB",
		basePrice = 0.05,
		volatility = 0.75,
		liquidity = 0.25,
		trendBias = -0.001,
		riskTag = "Extreme",
		icon = "💀",
		description = "Only noobs buy this. Or geniuses?",
		accentColor = {0.38, 0.49, 0.55},
	},
}

-- Build lookup table by id
local CoinById: {[string]: CoinDef} = {}
for _, coin in Coins do
	CoinById[coin.id] = coin
end

return {
	List = Coins,
	ById = CoinById,
}
