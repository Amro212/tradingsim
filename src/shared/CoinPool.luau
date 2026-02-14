--[[
	CoinPool.luau — Pool of coin name/icon/ticker combos for LaunchpadService.
	Used to generate new dynamically launched coins. Each entry is used at most
	once; when the pool is exhausted, entries are recycled with a suffix.
	Lives in shared so the server can pick from it during launches.
]]

local CoinPool = {}

-- Pre-defined coin templates (name, ticker, icon, description)
local POOL = {
	{ name = "ApeChain",      ticker = "APE",  icon = "\u{1F98D}", desc = "Apes together strong." },
	{ name = "RocketFuel",    ticker = "RKT",  icon = "\u{1F680}", desc = "Next stop: the moon." },
	{ name = "DiamondHands",  ticker = "DMH",  icon = "\u{1F48E}", desc = "Never selling. Ever." },
	{ name = "ShibaSwap",     ticker = "SHB",  icon = "\u{1F436}", desc = "The flippening is real." },
	{ name = "FrogFinance",   ticker = "FRG",  icon = "\u{1F438}", desc = "Ribbiting returns." },
	{ name = "MoonDAO",       ticker = "MND",  icon = "\u{1F315}", desc = "Decentralized lunar vibes." },
	{ name = "FlameToken",    ticker = "FLM",  icon = "\u{1F525}", desc = "This one's on fire." },
	{ name = "StarLink",      ticker = "STR",  icon = "\u{2B50}",  desc = "Reaching for the stars." },
	{ name = "BearTrap",      ticker = "BRT",  icon = "\u{1F43B}", desc = "Don't get caught." },
	{ name = "BullRun",       ticker = "BUL",  icon = "\u{1F402}", desc = "Unstoppable momentum." },
	{ name = "WhaleAlert",    ticker = "WHL",  icon = "\u{1F40B}", desc = "Big money incoming." },
	{ name = "GemHunter",     ticker = "GEM",  icon = "\u{1F4A0}", desc = "Finding hidden alpha." },
	{ name = "NyanCat",       ticker = "NYN",  icon = "\u{1F431}", desc = "Rainbow gains." },
	{ name = "PixelPunk",     ticker = "PXP",  icon = "\u{1F47E}", desc = "Retro revolution." },
	{ name = "ZenCoin",       ticker = "ZEN",  icon = "\u{262F}",  desc = "Inner peace, outer gains." },
	{ name = "ThunderBolt",   ticker = "TBT",  icon = "\u{26A1}",  desc = "Lightning fast." },
	{ name = "CobraVenom",    ticker = "CBV",  icon = "\u{1F40D}", desc = "Dangerously addictive." },
	{ name = "PhoenixRise",   ticker = "PHX",  icon = "\u{1F31F}", desc = "Born from the ashes." },
	{ name = "SamuraiDAO",    ticker = "SMR",  icon = "\u{2694}",  desc = "Honor among degens." },
	{ name = "OctopusNet",    ticker = "OCT",  icon = "\u{1F419}", desc = "Eight arms of alpha." },
	{ name = "LazerEyes",     ticker = "LZR",  icon = "\u{1F440}", desc = "We are all gonna make it." },
	{ name = "ChadToken",     ticker = "CHD",  icon = "\u{1F4AA}", desc = "Only Chads buy this." },
	{ name = "GoblinMode",    ticker = "GOB",  icon = "\u{1F47A}", desc = "Goblin mode activated." },
	{ name = "YoloSwap",      ticker = "YOL",  icon = "\u{1F3B2}", desc = "You only launch once." },
	{ name = "WagmiCoin",     ticker = "WGM",  icon = "\u{1F91D}", desc = "We're all gonna make it." },
	{ name = "CopiumMax",     ticker = "CPM",  icon = "\u{1F6AC}", desc = "Maximum copium supply." },
	{ name = "MegaPump",      ticker = "MGP",  icon = "\u{1F4C8}", desc = "Only up from here." },
	{ name = "RugGuard",      ticker = "RGD",  icon = "\u{1F6E1}", desc = "Definitely not a rug. Probably." },
	{ name = "AlphaLeaks",    ticker = "ALF",  icon = "\u{1F50D}", desc = "Insider info (not really)." },
	{ name = "HodlHero",      ticker = "HDL",  icon = "\u{1F9B8}", desc = "Diamond hands since day one." },
}

-- Accent color presets (one per meta category)
local META_ACCENT_COLORS = {
	AI             = {0.42, 0.64, 1.0},
	Animals        = {1.0, 0.55, 0.26},
	Gaming         = {0.70, 0.53, 1.0},
	Memes          = {0.0, 0.84, 0.56},
	ParodyPolitics = {1.0, 0.28, 0.34},
	Seasonal       = {1.0, 0.83, 0.16},
}

-- Available metas
local METAS = { "AI", "Animals", "Gaming", "Memes", "ParodyPolitics" }

-- Track which pool entries have been used
local usedIndices: {[number]: boolean} = {}
local recycleCount = 0

--- Pick a random entry from the pool, avoiding duplicates.
--- Returns: { id, name, ticker, icon, desc, meta, accentColor }
function CoinPool.Pick(rng: Random, hotMeta: string?): {[string]: any}
	-- Find available indices
	local available = {}
	for i = 1, #POOL do
		if not usedIndices[i] then
			table.insert(available, i)
		end
	end

	-- If all used, recycle with suffix
	if #available == 0 then
		recycleCount += 1
		usedIndices = {}
		for i = 1, #POOL do
			table.insert(available, i)
		end
	end

	local idx = available[rng:NextInteger(1, #available)]
	usedIndices[idx] = true

	local entry = POOL[idx]

	-- Pick meta: prefer hotMeta if provided, else random
	local meta = hotMeta
	if not meta or not META_ACCENT_COLORS[meta] then
		meta = METAS[rng:NextInteger(1, #METAS)]
	end

	-- Generate unique ID
	local suffix = if recycleCount > 0 then "_" .. recycleCount else ""
	local coinId = entry.ticker .. suffix

	-- Random low base price (0.01 – 2.00) for STEALTH launch
	local basePrice = math.floor(rng:NextNumber() * 199 + 1) / 100

	return {
		id = coinId,
		name = entry.name .. (if recycleCount > 0 then " " .. tostring(recycleCount + 1) else ""),
		ticker = entry.ticker .. (if recycleCount > 0 then tostring(recycleCount + 1) else ""),
		icon = entry.icon,
		desc = entry.desc,
		meta = meta,
		accentColor = META_ACCENT_COLORS[meta] or {0.5, 0.5, 0.5},
		basePrice = basePrice,
	}
end

--- Get the count of entries in the pool
function CoinPool.GetPoolSize(): number
	return #POOL
end

return CoinPool
