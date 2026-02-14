--[[
	TradingFloor.luau — Builds the 3D trading hub environment.
	Station A: Trading Terminal Row (WORLD_SPEC §1 Station A)
	Station B: Launchpad Stage (WORLD_SPEC §1 Station B) — M3
	- 8 trading terminals with monitors, ProximityPrompts
	- Ticker strip above the terminals
	- Launchpad stage with countdown screen, hologram pedestal, meta panels
	- Central atrium with spawn facing terminals
	Future stations (C–F) will be added in later milestones.
]]

local Lighting = game:GetService("Lighting")

local TradingFloor = {}

-- Layout constants
local FLOOR_SIZE = 200
local FLOOR_COLOR = Color3.fromRGB(18, 18, 28)
local DESK_COLOR = Color3.fromRGB(26, 26, 46)
local MONITOR_COLOR = Color3.fromRGB(10, 10, 25)
local PILLAR_COLOR = Color3.fromRGB(22, 33, 62)
local ACCENT_COLOR = Color3.fromRGB(88, 166, 255) -- blue neon
local TICKER_COLOR = Color3.fromRGB(8, 8, 20)

-- Terminal Row config
local TERMINAL_COUNT = 8
local TERMINAL_SPACING = 11    -- studs between terminal centers
local TERMINAL_ROW_Z = -55     -- Z position of terminal row
local TERMINAL_Y = 0           -- floor level

-- Launchpad Stage config (Station B — to the right of terminals)
local LAUNCH_POS = Vector3.new(65, 0, -30)  -- center of stage
local LAUNCH_STAGE_COLOR = Color3.fromRGB(12, 14, 26)
local LAUNCH_ACCENT = Color3.fromRGB(255, 80, 120)  -- pink/magenta neon
local LAUNCH_SCREEN_COLOR = Color3.fromRGB(8, 8, 18)

-- Meta category colors for light panels
local META_PANEL_COLORS = {
	{ label = "AI",      color = Color3.fromRGB(107, 163, 255) },
	{ label = "Animals", color = Color3.fromRGB(255, 140, 66)  },
	{ label = "Gaming",  color = Color3.fromRGB(179, 136, 255) },
	{ label = "Memes",   color = Color3.fromRGB(0, 214, 143)   },
	{ label = "Parody",  color = Color3.fromRGB(255, 71, 87)   },
}

-------------------------------------------------
-- Helper: create a Part with properties
-------------------------------------------------
local function makePart(props): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = if props.canCollide ~= nil then props.canCollide else true
	p.Locked = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = props.material or Enum.Material.SmoothPlastic
	p.Color = props.color or FLOOR_COLOR
	p.Size = props.size or Vector3.new(4, 1, 4)
	p.CFrame = props.cframe or CFrame.new(0, 0, 0)
	p.Name = props.name or "Part"
	p.Transparency = props.transparency or 0
	p.CastShadow = if props.castShadow ~= nil then props.castShadow else true
	if props.parent then
		p.Parent = props.parent
	end
	return p
end

-------------------------------------------------
-- Build the floor, environment, and atmosphere
-------------------------------------------------
function TradingFloor.BuildEnvironment(parent: Model)
	-- Main floor
	makePart({
		name = "Floor",
		size = Vector3.new(FLOOR_SIZE, 2, FLOOR_SIZE),
		cframe = CFrame.new(0, -1, 0),
		color = FLOOR_COLOR,
		parent = parent,
	})

	-- Back wall behind terminals
	makePart({
		name = "BackWall",
		size = Vector3.new(FLOOR_SIZE * 0.6, 20, 2),
		cframe = CFrame.new(0, 10, TERMINAL_ROW_Z - 6),
		color = Color3.fromRGB(14, 14, 24),
		parent = parent,
	})

	-- Accent line along back wall base
	makePart({
		name = "WallAccent",
		size = Vector3.new(TERMINAL_COUNT * TERMINAL_SPACING + 10, 0.15, 0.15),
		cframe = CFrame.new(0, 0.1, TERMINAL_ROW_Z - 4.9),
		color = ACCENT_COLOR,
		material = Enum.Material.Neon,
		canCollide = false,
		castShadow = false,
		parent = parent,
	})

	-- Floor glow strip in front of terminals
	makePart({
		name = "FloorGlowStrip",
		size = Vector3.new(TERMINAL_COUNT * TERMINAL_SPACING + 20, 0.05, 3),
		cframe = CFrame.new(0, 0.025, TERMINAL_ROW_Z + 5),
		color = ACCENT_COLOR,
		material = Enum.Material.Neon,
		transparency = 0.8,
		canCollide = false,
		castShadow = false,
		parent = parent,
	})

	-- SpawnLocation facing terminals
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "CenterSpawn"
	spawn.Size = Vector3.new(8, 0.2, 8)
	spawn.CFrame = CFrame.new(0, 0.1, 15)
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.Transparency = 1
	spawn.Duration = 0
	spawn.Parent = parent

	-- Atmosphere
	local atmo = Instance.new("Atmosphere")
	atmo.Density = 0.3
	atmo.Offset = 0.25
	atmo.Color = Color3.fromRGB(20, 20, 40)
	atmo.Decay = Color3.fromRGB(30, 30, 50)
	atmo.Glare = 0
	atmo.Haze = 2
	atmo.Parent = Lighting

	-- Bloom
	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = 0.5
	bloom.Size = 24
	bloom.Threshold = 0.8
	bloom.Parent = Lighting

	-- Color correction
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Brightness = -0.05
	cc.Contrast = 0.1
	cc.Saturation = 0.15
	cc.TintColor = Color3.fromRGB(230, 230, 255)
	cc.Parent = Lighting
end

-------------------------------------------------
-- Build a single trading terminal (desk + monitor)
-------------------------------------------------
function TradingFloor.BuildTerminal(index: number, posX: number, parent: Instance): Model
	local model = Instance.new("Model")
	model.Name = "Terminal_" .. index
	model.Parent = parent

	local baseY = TERMINAL_Y
	local baseZ = TERMINAL_ROW_Z

	-- Desk
	makePart({
		name = "Desk",
		size = Vector3.new(8, 1.4, 3.5),
		cframe = CFrame.new(posX, baseY + 0.7, baseZ),
		color = DESK_COLOR,
		parent = model,
	})

	-- Desk front accent strip (neon)
	makePart({
		name = "DeskAccent",
		size = Vector3.new(8, 0.12, 0.12),
		cframe = CFrame.new(posX, baseY + 1.4, baseZ + 1.75),
		color = ACCENT_COLOR,
		material = Enum.Material.Neon,
		canCollide = false,
		castShadow = false,
		parent = model,
	})

	-- Keyboard detail on desk
	makePart({
		name = "Keyboard",
		size = Vector3.new(3, 0.1, 1.2),
		cframe = CFrame.new(posX, baseY + 1.45, baseZ + 0.5),
		color = Color3.fromRGB(30, 30, 50),
		canCollide = false,
		parent = model,
	})

	-- Monitor back stand
	makePart({
		name = "MonitorStand",
		size = Vector3.new(0.4, 2.5, 0.4),
		cframe = CFrame.new(posX, baseY + 2.65, baseZ - 0.8),
		color = PILLAR_COLOR,
		parent = model,
	})

	-- Monitor screen (SurfaceGui target, faces +Z toward player)
	-- rotated 180 so Front face faces +Z
	local monitor = makePart({
		name = "Screen",
		size = Vector3.new(7, 4.5, 0.25),
		cframe = CFrame.new(posX, baseY + 4.65, baseZ - 0.8)
			* CFrame.Angles(math.rad(-5), math.pi, 0), -- tilt + face toward player
		color = MONITOR_COLOR,
		parent = model,
	})
	-- Tag monitor as terminal screen
	monitor:SetAttribute("IsTerminal", true)
	monitor:SetAttribute("TerminalIndex", index)

	-- Monitor bezel accent (top)
	makePart({
		name = "BezelTop",
		size = Vector3.new(7.2, 0.12, 0.35),
		cframe = CFrame.new(posX, baseY + 6.92, baseZ - 0.8)
			* CFrame.Angles(math.rad(-5), math.pi, 0),
		color = ACCENT_COLOR,
		material = Enum.Material.Neon,
		canCollide = false,
		castShadow = false,
		parent = model,
	})

	-- Under-desk glow
	makePart({
		name = "UnderGlow",
		size = Vector3.new(8.5, 0.05, 4),
		cframe = CFrame.new(posX, baseY + 0.025, baseZ),
		color = ACCENT_COLOR,
		material = Enum.Material.Neon,
		transparency = 0.8,
		canCollide = false,
		castShadow = false,
		parent = model,
	})

	-- Spotlight from above
	local lightAnchor = makePart({
		name = "LightAnchor",
		size = Vector3.new(1, 1, 1),
		cframe = CFrame.new(posX, baseY + 16, baseZ - 2),
		transparency = 1,
		canCollide = false,
		castShadow = false,
		parent = model,
	})
	local spot = Instance.new("SpotLight")
	spot.Brightness = 2
	spot.Range = 20
	spot.Angle = 35
	spot.Color = ACCENT_COLOR
	spot.Face = Enum.NormalId.Bottom
	spot.Parent = lightAnchor

	-- ProximityPrompt on monitor (§Station A: ProximityPrompt on any terminal)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Trade"
	prompt.ObjectText = "Trading Terminal"
	prompt.MaxActivationDistance = 12
	prompt.HoldDuration = 0
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.RequiresLineOfSight = false
	prompt.Parent = monitor

	return model
end

-------------------------------------------------
-- Build the ticker strip above all terminals
-------------------------------------------------
function TradingFloor.BuildTickerStrip(parent: Instance): Part
	local totalWidth = TERMINAL_COUNT * TERMINAL_SPACING + 10
	local baseZ = TERMINAL_ROW_Z

	-- Ticker backing
	local ticker = makePart({
		name = "TickerStrip",
		size = Vector3.new(totalWidth, 2.5, 0.3),
		cframe = CFrame.new(0, TERMINAL_Y + 9, baseZ - 0.8)
			* CFrame.Angles(0, math.pi, 0), -- face toward player
		color = TICKER_COLOR,
		parent = parent,
	})
	ticker:SetAttribute("IsTicker", true)

	-- Ticker accent lines
	makePart({
		name = "TickerAccentTop",
		size = Vector3.new(totalWidth + 2, 0.1, 0.35),
		cframe = CFrame.new(0, TERMINAL_Y + 10.3, baseZ - 0.8),
		color = ACCENT_COLOR,
		material = Enum.Material.Neon,
		canCollide = false,
		castShadow = false,
		parent = parent,
	})
	makePart({
		name = "TickerAccentBot",
		size = Vector3.new(totalWidth + 2, 0.1, 0.35),
		cframe = CFrame.new(0, TERMINAL_Y + 7.7, baseZ - 0.8),
		color = ACCENT_COLOR,
		material = Enum.Material.Neon,
		canCollide = false,
		castShadow = false,
		parent = parent,
	})

	return ticker
end

-------------------------------------------------
-- Build all terminals in a row
-------------------------------------------------
function TradingFloor.BuildTerminalRow(parent: Instance): {Model}
	local terminals = {}
	local startX = -(TERMINAL_COUNT - 1) * TERMINAL_SPACING / 2

	for i = 1, TERMINAL_COUNT do
		local posX = startX + (i - 1) * TERMINAL_SPACING
		local terminal = TradingFloor.BuildTerminal(i, posX, parent)
		table.insert(terminals, terminal)
	end

	return terminals
end

-------------------------------------------------
-- Station B: Launchpad Stage (WORLD_SPEC §1 Station B)
-------------------------------------------------
function TradingFloor.BuildLaunchpadStage(parent: Instance): { stage: Model, screen: Part, hologram: Part }
	local model = Instance.new("Model")
	model.Name = "LaunchpadStage"
	model.Parent = parent

	local cx, cy, cz = LAUNCH_POS.X, LAUNCH_POS.Y, LAUNCH_POS.Z

	-- Raised platform (stage)
	makePart({
		name = "StagePlatform",
		size = Vector3.new(28, 1.5, 20),
		cframe = CFrame.new(cx, cy + 0.75, cz),
		color = LAUNCH_STAGE_COLOR,
		parent = model,
	})

	-- Stage edge accent (neon strip around top edge)
	for _, offset in {
		{ Vector3.new(cx, cy + 1.55, cz + 10), Vector3.new(28, 0.12, 0.12) },  -- front
		{ Vector3.new(cx, cy + 1.55, cz - 10), Vector3.new(28, 0.12, 0.12) },  -- back
		{ Vector3.new(cx - 14, cy + 1.55, cz), Vector3.new(0.12, 0.12, 20) },  -- left
		{ Vector3.new(cx + 14, cy + 1.55, cz), Vector3.new(0.12, 0.12, 20) },  -- right
	} do
		makePart({
			name = "StageAccent",
			size = offset[2],
			cframe = CFrame.new(offset[1]),
			color = LAUNCH_ACCENT,
			material = Enum.Material.Neon,
			canCollide = false,
			castShadow = false,
			parent = model,
		})
	end

	-- Back wall / backdrop
	makePart({
		name = "StageBackdrop",
		size = Vector3.new(28, 16, 1.5),
		cframe = CFrame.new(cx, cy + 9.5, cz - 9.5),
		color = Color3.fromRGB(10, 10, 22),
		parent = model,
	})

	-- Giant countdown screen (SurfaceGui target, faces +Z)
	local screen = makePart({
		name = "LaunchScreen",
		size = Vector3.new(20, 10, 0.3),
		cframe = CFrame.new(cx, cy + 10, cz - 8.6)
			* CFrame.Angles(0, math.pi, 0),
		color = LAUNCH_SCREEN_COLOR,
		parent = model,
	})
	screen:SetAttribute("IsLaunchScreen", true)

	-- Screen bezel accent (top + bottom)
	makePart({
		name = "ScreenBezelTop",
		size = Vector3.new(20.4, 0.15, 0.4),
		cframe = CFrame.new(cx, cy + 15.1, cz - 8.6),
		color = LAUNCH_ACCENT,
		material = Enum.Material.Neon,
		canCollide = false,
		castShadow = false,
		parent = model,
	})
	makePart({
		name = "ScreenBezelBot",
		size = Vector3.new(20.4, 0.15, 0.4),
		cframe = CFrame.new(cx, cy + 4.9, cz - 8.6),
		color = LAUNCH_ACCENT,
		material = Enum.Material.Neon,
		canCollide = false,
		castShadow = false,
		parent = model,
	})

	-- Hologram pedestal (center of stage)
	local pedestal = makePart({
		name = "HologramPedestal",
		size = Vector3.new(4, 2, 4),
		cframe = CFrame.new(cx, cy + 2.5, cz + 2),
		color = Color3.fromRGB(20, 20, 40),
		parent = model,
	})

	-- Hologram display (transparent neon cylinder above pedestal)
	local hologram = makePart({
		name = "Hologram",
		size = Vector3.new(3, 5, 3),
		cframe = CFrame.new(cx, cy + 6, cz + 2),
		color = LAUNCH_ACCENT,
		material = Enum.Material.Neon,
		transparency = 0.7,
		canCollide = false,
		castShadow = false,
		parent = model,
	})
	hologram:SetAttribute("IsHologram", true)

	-- Hologram ring (glow around pedestal base)
	makePart({
		name = "HologramRing",
		size = Vector3.new(5, 0.1, 5),
		cframe = CFrame.new(cx, cy + 3.55, cz + 2),
		color = LAUNCH_ACCENT,
		material = Enum.Material.Neon,
		transparency = 0.5,
		canCollide = false,
		castShadow = false,
		parent = model,
	})

	-- ProximityPrompt on hologram for deep-link
	local holoPrompt = Instance.new("ProximityPrompt")
	holoPrompt.ActionText = "View Coin"
	holoPrompt.ObjectText = "Latest Launch"
	holoPrompt.MaxActivationDistance = 14
	holoPrompt.HoldDuration = 0
	holoPrompt.KeyboardKeyCode = Enum.KeyCode.F
	holoPrompt.RequiresLineOfSight = false
	holoPrompt.Parent = hologram

	-- ProximityPrompt on pedestal for launchpad UI
	local stagePrompt = Instance.new("ProximityPrompt")
	stagePrompt.ActionText = "Launchpad"
	stagePrompt.ObjectText = "Coin Launchpad"
	stagePrompt.MaxActivationDistance = 18
	stagePrompt.HoldDuration = 0
	stagePrompt.KeyboardKeyCode = Enum.KeyCode.E
	stagePrompt.RequiresLineOfSight = false
	stagePrompt.Parent = pedestal

	-- Meta tag light panels (along back wall sides)
	for i, meta in META_PANEL_COLORS do
		local panelX = cx - 12 + (i - 1) * 6
		local panelY = cy + 4.5
		local panelZ = cz - 8.3

		-- Panel backing
		makePart({
			name = "MetaPanel_" .. meta.label,
			size = Vector3.new(4.5, 2.5, 0.2),
			cframe = CFrame.new(panelX, panelY, panelZ)
				* CFrame.Angles(0, math.pi, 0),
			color = meta.color,
			material = Enum.Material.Neon,
			transparency = 0.6,
			canCollide = false,
			castShadow = false,
			parent = model,
		})
	end

	-- Spotlights on stage
	local lightAnchor = makePart({
		name = "StageLightAnchor",
		size = Vector3.new(1, 1, 1),
		cframe = CFrame.new(cx, cy + 22, cz),
		transparency = 1,
		canCollide = false,
		castShadow = false,
		parent = model,
	})
	local spot = Instance.new("SpotLight")
	spot.Brightness = 3
	spot.Range = 30
	spot.Angle = 45
	spot.Color = LAUNCH_ACCENT
	spot.Face = Enum.NormalId.Bottom
	spot.Parent = lightAnchor

	-- Point light on hologram
	local holoLight = Instance.new("PointLight")
	holoLight.Brightness = 2
	holoLight.Range = 12
	holoLight.Color = LAUNCH_ACCENT
	holoLight.Parent = hologram

	return {
		stage = model,
		screen = screen,
		hologram = hologram,
		pedestal = pedestal,
	}
end

-------------------------------------------------
-- Main build function
-------------------------------------------------
function TradingFloor.Build()
	local floorModel = Instance.new("Model")
	floorModel.Name = "TradingFloor"
	floorModel.Parent = workspace

	-- Remove default baseplate if it exists
	local baseplate = workspace:FindFirstChild("Baseplate")
	if baseplate then
		baseplate:Destroy()
	end

	-- Build environment (floor, walls, lighting, spawn)
	TradingFloor.BuildEnvironment(floorModel)

	-- Build Station A: Trading Terminal Row
	local terminals = TradingFloor.BuildTerminalRow(floorModel)

	-- Build ticker strip above terminals
	local tickerStrip = TradingFloor.BuildTickerStrip(floorModel)

	-- Build Station B: Launchpad Stage
	local launchpad = TradingFloor.BuildLaunchpadStage(floorModel)

	print("[TradingFloor] Built Station A: " .. #terminals .. " terminals + ticker strip")
	print("[TradingFloor] Built Station B: Launchpad Stage")

	return floorModel, terminals, tickerStrip, launchpad
end

return TradingFloor
