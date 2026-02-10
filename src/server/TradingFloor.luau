--[[
	TradingFloor.luau — Builds the 3D trading floor environment.
	Creates coin stations arranged in a circle, each with a screen Part
	for SurfaceGui, ProximityPrompt, and accent lighting.
	Runs server-side; Parts replicate to all clients.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")

local CoinsModule = require(ReplicatedStorage.Shared.Coins)

local TradingFloor = {}

local STATION_RADIUS = 45
local FLOOR_SIZE = 200
local FLOOR_COLOR = Color3.fromRGB(18, 18, 28)
local STATION_BASE_COLOR = Color3.fromRGB(26, 26, 46)
local SCREEN_COLOR = Color3.fromRGB(12, 12, 30)
local PILLAR_COLOR = Color3.fromRGB(22, 33, 62)

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
-- Build the floor and environment
-------------------------------------------------
function TradingFloor.BuildEnvironment()
	local floorModel = Instance.new("Model")
	floorModel.Name = "TradingFloor"
	floorModel.Parent = workspace

	-- Main floor
	makePart({
		name = "Floor",
		size = Vector3.new(FLOOR_SIZE, 2, FLOOR_SIZE),
		cframe = CFrame.new(0, -1, 0),
		color = FLOOR_COLOR,
		parent = floorModel,
	})

	-- Center platform (cylinder)
	local centerPlatform = makePart({
		name = "CenterPlatform",
		size = Vector3.new(20, 0.4, 20),
		cframe = CFrame.new(0, 0.2, 0),
		color = Color3.fromRGB(25, 25, 40),
		parent = floorModel,
	})
	-- Make it a cylinder shape
	local mesh = Instance.new("CylinderMesh")
	mesh.Parent = centerPlatform

	-- Center glow ring
	local glowRing = makePart({
		name = "GlowRing",
		size = Vector3.new(22, 0.1, 22),
		cframe = CFrame.new(0, 0.05, 0),
		color = Color3.fromRGB(88, 166, 255),
		material = Enum.Material.Neon,
		transparency = 0.6,
		canCollide = false,
		castShadow = false,
		parent = floorModel,
	})
	local glowMesh = Instance.new("CylinderMesh")
	glowMesh.Parent = glowRing

	-- Floor guide lines from center to each station
	for i = 1, #CoinsModule.List do
		local angle = (i - 1) * (2 * math.pi / #CoinsModule.List)
		local midX = math.sin(angle) * (STATION_RADIUS / 2)
		local midZ = math.cos(angle) * (STATION_RADIUS / 2)
		local lineAngle = math.atan2(math.sin(angle), math.cos(angle))

		local line = makePart({
			name = "GuideLine_" .. i,
			size = Vector3.new(0.3, 0.05, STATION_RADIUS - 12),
			cframe = CFrame.new(midX, 0.025, midZ)
				* CFrame.Angles(0, lineAngle, 0),
			color = Color3.fromRGB(40, 40, 65),
			material = Enum.Material.Neon,
			transparency = 0.7,
			canCollide = false,
			castShadow = false,
			parent = floorModel,
		})
	end

	-- SpawnLocation at center
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "CenterSpawn"
	spawn.Size = Vector3.new(6, 0.2, 6)
	spawn.CFrame = CFrame.new(0, 0.1, 0)
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.Transparency = 1
	spawn.Duration = 0
	spawn.Parent = floorModel

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

	-- Color correction for mood
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Brightness = -0.05
	cc.Contrast = 0.1
	cc.Saturation = 0.15
	cc.TintColor = Color3.fromRGB(230, 230, 255)
	cc.Parent = Lighting

	return floorModel
end

-------------------------------------------------
-- Build a single coin station
-------------------------------------------------
function TradingFloor.BuildStation(coinDef, stationCF: CFrame, parent: Instance): Model
	local accentColor = Color3.new(
		coinDef.accentColor[1],
		coinDef.accentColor[2],
		coinDef.accentColor[3]
	)

	local model = Instance.new("Model")
	model.Name = "Station_" .. coinDef.id
	model.Parent = parent

	-- Base pedestal
	makePart({
		name = "Base",
		size = Vector3.new(10, 1.2, 5),
		cframe = stationCF * CFrame.new(0, 0.6, 0),
		color = STATION_BASE_COLOR,
		parent = model,
	})

	-- Base front accent strip (neon glow)
	makePart({
		name = "BaseAccent",
		size = Vector3.new(10, 0.12, 0.12),
		cframe = stationCF * CFrame.new(0, 1.2, -2.5),
		color = accentColor,
		material = Enum.Material.Neon,
		canCollide = false,
		castShadow = false,
		parent = model,
	})

	-- Left support pillar
	makePart({
		name = "PillarL",
		size = Vector3.new(0.5, 4, 0.4),
		cframe = stationCF * CFrame.new(-4.2, 3.2, 0),
		color = PILLAR_COLOR,
		parent = model,
	})

	-- Right support pillar
	makePart({
		name = "PillarR",
		size = Vector3.new(0.5, 4, 0.4),
		cframe = stationCF * CFrame.new(4.2, 3.2, 0),
		color = PILLAR_COLOR,
		parent = model,
	})

	-- Main screen
	local screen = makePart({
		name = "Screen",
		size = Vector3.new(9.5, 6, 0.3),
		cframe = stationCF * CFrame.new(0, 6.2, 0)
			* CFrame.Angles(math.rad(-5), 0, 0), -- slight tilt
		color = SCREEN_COLOR,
		parent = model,
	})
	-- Tag screen with coin ID so client can find it
	screen:SetAttribute("CoinId", coinDef.id)

	-- Screen top bezel (neon accent)
	makePart({
		name = "BezelTop",
		size = Vector3.new(9.8, 0.15, 0.5),
		cframe = stationCF * CFrame.new(0, 9.25, 0)
			* CFrame.Angles(math.rad(-5), 0, 0),
		color = accentColor,
		material = Enum.Material.Neon,
		canCollide = false,
		castShadow = false,
		parent = model,
	})

	-- Screen bottom bezel (neon accent)
	makePart({
		name = "BezelBottom",
		size = Vector3.new(9.8, 0.15, 0.5),
		cframe = stationCF * CFrame.new(0, 3.2, 0)
			* CFrame.Angles(math.rad(-5), 0, 0),
		color = accentColor,
		material = Enum.Material.Neon,
		canCollide = false,
		castShadow = false,
		parent = model,
	})

	-- Floor glow pad
	makePart({
		name = "FloorGlow",
		size = Vector3.new(12, 0.05, 7),
		cframe = stationCF * CFrame.new(0, 0.025, 0),
		color = accentColor,
		material = Enum.Material.Neon,
		transparency = 0.75,
		canCollide = false,
		castShadow = false,
		parent = model,
	})

	-- SpotLight pointing down at station
	local lightAnchor = makePart({
		name = "LightAnchor",
		size = Vector3.new(1, 1, 1),
		cframe = stationCF * CFrame.new(0, 14, -3),
		transparency = 1,
		canCollide = false,
		castShadow = false,
		parent = model,
	})
	local spot = Instance.new("SpotLight")
	spot.Brightness = 3
	spot.Range = 25
	spot.Angle = 45
	spot.Color = accentColor
	spot.Face = Enum.NormalId.Bottom
	spot.Parent = lightAnchor

	-- PointLight for ambient glow in base
	local pointLight = Instance.new("PointLight")
	pointLight.Color = accentColor
	pointLight.Brightness = 1.5
	pointLight.Range = 12
	pointLight.Parent = model.Base

	-- ProximityPrompt on screen
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Trade"
	prompt.ObjectText = coinDef.icon .. " " .. coinDef.name
	prompt.MaxActivationDistance = 14
	prompt.HoldDuration = 0
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.RequiresLineOfSight = false
	prompt.Parent = screen

	return model
end

-------------------------------------------------
-- Build all stations in a circle
-------------------------------------------------
function TradingFloor.BuildAllStations(parent: Instance)
	local stations = {}
	local numCoins = #CoinsModule.List

	for i, coinDef in CoinsModule.List do
		local angle = (i - 1) * (2 * math.pi / numCoins)
		local x = math.sin(angle) * STATION_RADIUS
		local z = math.cos(angle) * STATION_RADIUS
		local pos = Vector3.new(x, 0, z)

		-- Face toward center
		local stationCF = CFrame.lookAt(pos, Vector3.new(0, 0, 0))

		local stationModel = TradingFloor.BuildStation(coinDef, stationCF, parent)
		stations[coinDef.id] = stationModel
	end

	return stations
end

-------------------------------------------------
-- Main build function
-------------------------------------------------
function TradingFloor.Build()
	local floorModel = TradingFloor.BuildEnvironment()
	local stations = TradingFloor.BuildAllStations(floorModel)

	-- Remove default baseplate if it exists
	local baseplate = workspace:FindFirstChild("Baseplate")
	if baseplate then
		baseplate:Destroy()
	end

	return floorModel, stations
end

return TradingFloor
