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
Config.SIM_TICK = 0.5                 -- price update interval (seconds)
Config.BROADCAST_INTERVAL = 0.25      -- market snapshot push rate (seconds)
Config.MAX_HISTORY_POINTS = 120       -- ring buffer size for charts
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

return Config
