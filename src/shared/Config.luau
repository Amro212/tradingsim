--[[
	Config.luau — Central configuration for the trading simulator.
	Lives in ReplicatedStorage so both server and client can read constants.
	Server is authoritative; client uses these only for display hints.
]]

local Config = {}

-- Economy
Config.STARTING_CASH = 10000
Config.TRADE_FEE_PCT = 0.001          -- 0.1% per trade
Config.SLIPPAGE_BASE_PCT = 0.0005     -- base slippage 0.05%
Config.MAX_TRADE_QTY = 100000         -- max units per order
Config.MIN_TRADE_QTY = 0.01           -- minimum fractional buy

-- Rate limiting
Config.MAX_TRADES_PER_SECOND = 4
Config.RATE_LIMIT_WINDOW = 1          -- seconds

-- Market simulation
Config.SIM_TICK = 1.0                 -- price update interval (seconds) §4.1: 1s base tick
Config.BROADCAST_INTERVAL = 0.5       -- market snapshot push rate (seconds) §4.1: 0.5–1.0s
Config.MAX_HISTORY_POINTS = 120       -- ring buffer size for line charts (legacy)
Config.PRICE_FLOOR_MULT = 0.01        -- coin can't drop below 1% of base
Config.PRICE_CEIL_MULT = 100          -- coin can't exceed 100x base

-- Events
Config.EVENT_MIN_INTERVAL = 15        -- seconds between events (min)
Config.EVENT_MAX_INTERVAL = 45        -- seconds between events (max)
Config.EVENT_DEFAULT_DURATION = 10    -- seconds an event lasts

-- Persistence
Config.AUTOSAVE_INTERVAL = 60         -- seconds between autosaves
Config.DATASTORE_KEY_PREFIX = "PlayerData_v1_"

-- Tutorial
Config.TUTORIAL_ENABLED = true

-- Cosmetics placeholder IDs
Config.COSMETIC_CATEGORIES = {"UITheme", "ChartSkin", "TitleBadge", "SoundPack"}
Config.DEFAULT_THEME = "Dark"

-- Trade history
Config.MAX_TRADE_HISTORY = 100

-------------------------------------------------
-- Candlestick chart configuration
-------------------------------------------------

-- Timeframe definitions: label → seconds
Config.TIMEFRAMES = {
	["1s"]  = 1,
	["5s"]  = 5,
	["15s"] = 15,
	["1m"]  = 60,
	["5m"]  = 300,
	["15m"] = 900,
}

-- Ordered list for UI buttons
Config.TIMEFRAME_ORDER = { "1s", "5s", "15s", "1m", "5m", "15m" }

-- Default timeframe on open
Config.DEFAULT_TIMEFRAME = "5s"

-- How many candles the server stores per coin+timeframe (ring buffer)
Config.MAX_CANDLE_HISTORY = 300

-- Max candles a client can request in one batch
Config.MAX_CANDLE_REQUEST = 200

-- How often the server broadcasts live candle updates (seconds)
Config.CANDLE_UPDATE_INTERVAL = 0.5

-- Chart visual sizing (pixels, used client-side)
Config.CHART = {
	MAX_VISIBLE_CANDLES = 120,      -- max candles shown at once
	CANDLE_BODY_WIDTH   = 7,        -- px
	CANDLE_GAP          = 3,        -- px between candles
	WICK_WIDTH          = 1,        -- px
	PADDING_LEFT        = 10,       -- px
	PADDING_RIGHT       = 65,       -- px for price axis labels
	PADDING_TOP         = 8,        -- px
	PADDING_BOTTOM      = 22,       -- px for time labels
	PRICE_PADDING_PCT   = 0.03,     -- 3% above/below high/low
	GRID_TARGET_LINES   = 6,        -- aim for ~6 horizontal grid lines
	VOLUME_HEIGHT_PCT   = 0.20,     -- 20% of chart area for volume pane
	TOOLTIP_WIDTH       = 160,      -- px
	TOOLTIP_HEIGHT      = 100,      -- px
}

return Config
