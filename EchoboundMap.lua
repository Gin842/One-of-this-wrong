--[[
    ECHOBOUND - CARD ISLAND  (server builder)
    =========================================
    SETUP
      1. Put THIS file in ServerScriptService as a normal Script.
      2. Put EchoboundAnimation.lua in StarterPlayer > StarterPlayerScripts as a LocalScript
         (it makes the cards orbit, rings spin, islands drift, water flow, lanterns flicker).
      3. Press Play.

    Everything is built from code. 1 unit = 1 meter of the blueprint, then the whole
    model is scaled by CONFIG.SCALE so it feels right for Roblox characters.
    North = -Z, East = +X.  Spawn is in the south, the castle in the north.
]]

local CONFIG = {
	SCALE       = 2,      -- overall size of the map
	LAMP_LIGHTS = true,   -- set false on weak devices (lanterns keep their glow, lose real lights)
	STARS       = 6000,
	SEED        = 11,
}

local Workspace         = game:GetService("Workspace")
local Lighting          = game:GetService("Lighting")
local CollectionService = game:GetService("CollectionService")

local V3, CF, CFA = Vector3.new, CFrame.new, CFrame.Angles
local rad, sin, cos = math.rad, math.sin, math.cos
local MAT = Enum.Material
local rng = Random.new(CONFIG.SEED)

local old = Workspace:FindFirstChild("EchoboundMap")
if old then old:Destroy() end
local map = Instance.new("Model")
map.Name = "EchoboundMap"
map.Parent = Workspace

------------------------------------------------------------------
-- COLORS
------------------------------------------------------------------
local function rgb(r, g, b) return Color3.fromRGB(r, g, b) end
local C = {
	stone   = rgb(168, 162, 182), stoneD = rgb(112, 106, 130), path = rgb(205, 198, 218),
	rock    = rgb(62, 56, 80),    rockL  = rgb(92, 84, 116),
	plum    = rgb(50, 36, 78),    plumD  = rgb(30, 22, 52),   spire = rgb(36, 30, 62),
	gold    = rgb(240, 196, 96),  goldD  = rgb(186, 140, 58),
	purple  = rgb(150, 80, 255),  purpleD = rgb(54, 28, 96),  violet = rgb(110, 60, 200),
	red     = rgb(150, 24, 44),   cream  = rgb(244, 234, 208),
	water   = rgb(96, 176, 255),  cyan   = rgb(110, 225, 255),
	grass   = rgb(44, 96, 64),    leaf1  = rgb(36, 84, 58),   leaf2 = rgb(50, 112, 72),
	autumn  = rgb(176, 52, 62),   hedge  = rgb(30, 76, 50),
	wood    = rgb(70, 44, 36),    black  = rgb(18, 16, 26),   lamp  = rgb(255, 196, 110),
	white   = rgb(250, 250, 255), silver = rgb(196, 192, 210),
}
local SUITS = { "♠", "♥", "♣", "♦" }

------------------------------------------------------------------
-- BASIC HELPERS
------------------------------------------------------------------
local function Folder(name, parent)
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent or map
	return f
end

local function P(parent, name, size, at, color, mat, transp)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	if typeof(at) == "CFrame" then p.CFrame = at else p.Position = at end
	p.Color = color
	p.Material = mat or MAT.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if transp then p.Transparency = transp end
	p.Parent = parent
	return p
end

-- vertical cylinder by default (axis "Y"); "X" or "Z" for sideways
local function Cyl(parent, name, diameter, height, at, color, mat, axis)
	local cf = (typeof(at) == "CFrame") and at or CF(at)
	local turn = CFA(0, 0, rad(90))
	if axis == "Z" then turn = CFA(0, rad(90), 0) elseif axis == "X" then turn = CFA(0, 0, 0) end
	local p = P(parent, name, V3(height, diameter, diameter), cf * turn, color, mat)
	p.Shape = Enum.PartType.Cylinder
	return p
end

local function Ball(parent, name, d, at, color, mat)
	local p = P(parent, name, V3(d, d, d), at, color, mat)
	p.Shape = Enum.PartType.Ball
	return p
end

local function Neon(parent, name, size, at, color, transp)
	local p = P(parent, name, size, at, color, MAT.Neon, transp)
	p.CastShadow = false
	return p
end

local function Ghost(p) -- decorative, no collision
	p.CanCollide = false
	return p
end

local function Light(part, color, range, brightness, flicker)
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range
	l.Brightness = brightness
	l.Shadows = false
	l.Parent = part
	if flicker then
		l:SetAttribute("Base", brightness)
		CollectionService:AddTag(l, "EB_Flame")
	end
	return l
end

local function SurfaceText(part, face, text, color, font, size)
	local sg = Instance.new("SurfaceGui")
	sg.Face = face
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = size or 50
	sg.LightInfluence = 0
	sg.Parent = part
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 1
	t.Text = text
	t.TextScaled = true
	t.Font = font or Enum.Font.SourceSansBold
	t.TextColor3 = color
	t.Parent = sg
	return t, sg
end

-- floating pill sign (English only)
local function Pill(parent, pos, w, h, title, sub, accent)
	local anchor = Ghost(P(parent, "Sign", V3(1, 1, 1), pos, C.black, MAT.SmoothPlastic, 1))
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(w, h)
	bb.MaxDistance = 800
	bb.LightInfluence = 0
	bb.Parent = anchor
	local f = Instance.new("Frame")
	f.Size = UDim2.fromScale(1, 1)
	f.BackgroundColor3 = C.purpleD
	f.BackgroundTransparency = 0.08
	f.Parent = bb
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.22, 0)
	corner.Parent = f
	local stroke = Instance.new("UIStroke")
	stroke.Color = accent or C.gold
	stroke.Thickness = 2
	stroke.Parent = f
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = sub and UDim2.fromScale(1, 0.62) or UDim2.fromScale(1, 1)
	t.Text = title
	t.TextScaled = true
	t.Font = Enum.Font.GothamBlack
	t.TextColor3 = C.white
	t.Parent = f
	if sub then
		local s = Instance.new("TextLabel")
		s.BackgroundTransparency = 1
		s.Position = UDim2.fromScale(0, 0.62)
		s.Size = UDim2.fromScale(1, 0.3)
		s.Text = sub
		s.TextScaled = true
		s.Font = Enum.Font.GothamBold
		s.TextColor3 = accent or C.gold
		s.Parent = f
	end
	return anchor
end

-- gold lantern post
local function Lantern(parent, x, z, h)
	h = h or 8
	P(parent, "LanternBase", V3(1.8, 1, 1.8), V3(x, 0.5, z), C.black, MAT.Metal)
	P(parent, "LanternPole", V3(0.6, h, 0.6), V3(x, h / 2 + 0.5, z), C.black, MAT.Metal)
	P(parent, "LanternCradle", V3(2.2, 0.4, 2.2), V3(x, h + 0.7, z), C.gold, MAT.Metal)
	local glass = Neon(parent, "LanternGlass", V3(1.5, 2.2, 1.5), V3(x, h + 1.9, z), C.lamp, 0.1)
	P(parent, "LanternCap", V3(2.4, 0.4, 2.4), V3(x, h + 3.1, z), C.gold, MAT.Metal)
	P(parent, "LanternTip", V3(0.8, 0.8, 0.8), CF(x, h + 3.7, z) * CFA(0, rad(45), 0), C.gold, MAT.Metal)
	if CONFIG.LAMP_LIGHTS then Light(glass, C.lamp, 20, 1.2, true) end
end

local function Tree(parent, x, z, s, autumn)
	s = s or 1
	Ghost(Cyl(parent, "TreeGrass", 14 * s, 0.3, V3(x, 0.2, z), C.grass, MAT.Grass))
	Cyl(parent, "Trunk", 1.6 * s, 7 * s, V3(x, 3.5 * s, z), C.wood, MAT.Wood)
	local a = autumn and C.autumn or C.leaf1
	local b = autumn and rgb(200, 90, 60) or C.leaf2
	Ball(parent, "Leaves", 9 * s, V3(x, 10 * s, z), a, MAT.Grass)
	Ball(parent, "Leaves", 6.5 * s, V3(x + 3 * s, 8.6 * s, z + 1.5 * s), b, MAT.Grass)
	Ball(parent, "Leaves", 6 * s, V3(x - 3 * s, 8.8 * s, z - 1.5 * s), b, MAT.Grass)
	Ball(parent, "Leaves", 5 * s, V3(x, 14 * s, z), a, MAT.Grass)
end

local function Planter(parent, cf, w, d)
	P(parent, "PlanterBox", V3(w, 1.6, d), cf * CF(0, 0.8, 0), C.stoneD, MAT.Slate)
	P(parent, "PlanterTrim", V3(w + 0.4, 0.3, d + 0.4), cf * CF(0, 1.6, 0), C.gold, MAT.Metal)
	P(parent, "Hedge", V3(w - 0.8, 1.8, d - 0.8), cf * CF(0, 2.4, 0), C.hedge, MAT.Grass)
	for i = 1, 5 do
		local fx = rng:NextNumber(-w / 2 + 1, w / 2 - 1)
		local fz = rng:NextNumber(-d / 2 + 1, d / 2 - 1)
		Neon(parent, "Bloom", V3(0.5, 0.5, 0.5), cf * CF(fx, 3.4, fz), (i % 2 == 0) and C.purple or C.gold)
	end
end

-- stairs descending toward dir (+1 = +Z, -1 = -Z) from z0; optional red carpet
local function Stairs(parent, x, z0, width, steps, rise, run, dir, topH, carpetW)
	for i = 1, steps do
		local h = topH - i * rise
		if h > 0.05 then
			local zc = z0 + dir * (i - 0.5) * run
			P(parent, "Step", V3(width, h, run), V3(x, h / 2, zc), C.stoneD, MAT.Slate)
			P(parent, "StepEdge", V3(width, 0.12, 0.35), V3(x, h + 0.02, zc + dir * (run / 2 - 0.2)), C.gold, MAT.Metal)
			if carpetW then
				P(parent, "Carpet", V3(carpetW, 0.12, run), V3(x, h + 0.08, zc), C.red, MAT.Fabric)
			end
		end
	end
end

-- hanging banner; cf = center, its FRONT (-Z) face is the visible side (use CFrame.lookAt)
local function Banner(parent, cf, w, h, suit)
	local cloth = P(parent, "BannerCloth", V3(w, h, 0.4), cf, C.purpleD, MAT.Fabric)
	P(parent, "BannerEdgeL", V3(0.5, h, 0.5), cf * CF(-w / 2, 0, -0.05), C.gold, MAT.Metal)
	P(parent, "BannerEdgeR", V3(0.5, h, 0.5), cf * CF(w / 2, 0, -0.05), C.gold, MAT.Metal)
	P(parent, "BannerBottom", V3(w, 0.5, 0.5), cf * CF(0, -h / 2, -0.05), C.gold, MAT.Metal)
	P(parent, "BannerRod", V3(w + 2, 0.7, 0.7), cf * CF(0, h / 2 + 0.3, -0.1), C.gold, MAT.Metal)
	Neon(parent, "BannerGem", V3(w * 0.5, w * 0.5, 0.2), cf * CF(0, h * 0.18, -0.3) * CFA(0, 0, rad(45)), C.violet, 0.35)
	SurfaceText(cloth, Enum.NormalId.Front, suit, C.gold, Enum.Font.SourceSansBold, 40)
	return cloth
end

-- thin neon strips along a closed polygon
local function EdgeStrips(parent, verts, y, width, color, mat)
	for i = 1, #verts do
		local a, b = verts[i], verts[i % #verts + 1]
		local d = b - a
		local mid = (a + b) / 2
		local yaw = math.atan2(-d.Z, d.X)
		P(parent, "Strip", V3(d.Magnitude + width, 0.12, width), CF(mid.X, y, mid.Z) * CFA(0, yaw, 0), color, mat or MAT.Neon)
	end
end

-- ring of small segments
local function RingSegs(parent, center, radius, n, thick, color, ang0)
	local arc = (2 * math.pi * radius / n) * 1.05
	for i = 1, n do
		local a = (i / n) * 2 * math.pi + (ang0 or 0)
		local s = Neon(parent, "RuneSeg", V3(thick, 0.15, arc), CF(center) * CFA(0, a, 0) * CF(radius, 0, 0), color)
		s.CanCollide = false
	end
end

local function Emitter(parent, size, pos, cfg)
	local a = Ghost(P(parent, "Emitter", size, pos, C.black, MAT.SmoothPlastic, 1))
	local e = Instance.new("ParticleEmitter")
	e.Texture = cfg.texture or "rbxasset://textures/particles/smoke_main.dds"
	e.Color = cfg.color or ColorSequence.new(C.white)
	e.Size = cfg.size or NumberSequence.new(2)
	e.Transparency = cfg.transparency or NumberSequence.new(0.5, 1)
	e.Lifetime = cfg.lifetime or NumberRange.new(3, 5)
	e.Rate = cfg.rate or 20
	e.Speed = cfg.speed or NumberRange.new(1, 3)
	e.SpreadAngle = Vector2.new(cfg.spread or 30, cfg.spread or 30)
	e.EmissionDirection = cfg.dir or Enum.NormalId.Top
	e.LightEmission = cfg.light or 0.3
	e.Acceleration = cfg.accel or V3(0, 0, 0)
	e.RotSpeed = NumberRange.new(-20, 20)
	if cfg.box then
		e.Shape = Enum.ParticleEmitterShape.Box
		e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	end
	e.Parent = a
	return e
end

local function Rock(parent, pos, size)
	return P(parent, "Rock",
		V3(size, size * rng:NextNumber(0.7, 1.2), size * rng:NextNumber(0.8, 1.3)),
		CF(pos) * CFA(rad(rng:NextInteger(0, 360)), rad(rng:NextInteger(0, 360)), rad(rng:NextInteger(0, 360))),
		(rng:NextInteger(0, 1) == 0) and C.rock or C.rockL, MAT.Rock)
end

local function Crystal(parent, pos, s, color)
	local c = Neon(parent, "Crystal", V3(s * 0.8, s * 2.6, s * 0.8),
		CF(pos) * CFA(rad(rng:NextInteger(-25, 25)), rad(rng:NextInteger(0, 90)), rad(rng:NextInteger(-25, 25))), color, 0.1)
	c.CanCollide = false
	if CONFIG.LAMP_LIGHTS then Light(c, color, 18, 1) end
	return c
end

------------------------------------------------------------------
-- 0. NIGHT SKY & ATMOSPHERE
------------------------------------------------------------------
local function ensure(class, name)
	local o = Lighting:FindFirstChild(name)
	if not o then
		o = Instance.new(class)
		o.Name = name
		o.Parent = Lighting
	end
	return o
end

for _, ch in ipairs(Lighting:GetChildren()) do
	if ch:IsA("Sky") and ch.Name ~= "EchoSky" then ch:Destroy() end
end
Lighting.ClockTime = 0
Lighting.Brightness = 1
Lighting.Ambient = rgb(78, 60, 130)
Lighting.OutdoorAmbient = rgb(92, 74, 160)
Lighting.ColorShift_Top = rgb(150, 100, 255)
Lighting.EnvironmentDiffuseScale = 0.6
Lighting.EnvironmentSpecularScale = 0.6
Lighting.ExposureCompensation = 0.35
local sky = ensure("Sky", "EchoSky")
sky.StarCount = CONFIG.STARS
sky.CelestialBodiesShown = true
local atm = ensure("Atmosphere", "EchoAtmosphere")
atm.Density = 0.32
atm.Offset = 0.25
atm.Color = rgb(120, 90, 210)
atm.Decay = rgb(46, 24, 100)
atm.Glare = 0
atm.Haze = 1.6
local bloom = ensure("BloomEffect", "EchoBloom")
bloom.Intensity = 0.9
bloom.Size = 30
bloom.Threshold = 0.85
local cc = ensure("ColorCorrectionEffect", "EchoColor")
cc.Saturation = 0.15
cc.Contrast = 0.08
cc.TintColor = rgb(238, 226, 255)
local rays = ensure("SunRaysEffect", "EchoRays")
rays.Intensity = 0.04

------------------------------------------------------------------
-- 1. THE FLOATING ISLAND
------------------------------------------------------------------
local base = Folder("Island")

-- octagon outline (also used for rocks, grass lip)
local OCT = {
	V3(-75, 0, -110), V3(75, 0, -110), V3(105, 0, -80), V3(105, 0, 80),
	V3(75, 0, 110), V3(-75, 0, 110), V3(-105, 0, 80), V3(-105, 0, -80),
}

P(base, "PlazaA", V3(210, 6, 160), V3(0, -3, 0), C.stone, MAT.Cobblestone)
P(base, "PlazaB", V3(150, 6, 220), V3(0, -2.99, 0), C.stone, MAT.Cobblestone)
for _, sx in ipairs({ -1, 1 }) do
	for _, sz in ipairs({ -1, 1 }) do
		P(base, "PlazaCorner", V3(42.5, 6, 42.5), CF(sx * 75, -2.98, sz * 80) * CFA(0, rad(45), 0), C.stone, MAT.Cobblestone)
	end
end

-- grass lip + jagged rim rocks along the outline
for e = 1, #OCT do
	local a, b = OCT[e], OCT[e % #OCT + 1]
	local d = b - a
	local mid = (a + b) / 2
	local inward = (-mid).Unit * 3.5
	local yaw = math.atan2(-d.Z, d.X)
	Ghost(P(base, "GrassLip", V3(d.Magnitude * 0.97, 0.3, 7), CF(mid.X + inward.X, 0.15, mid.Z + inward.Z) * CFA(0, yaw, 0), C.grass, MAT.Grass))
	local n = math.floor(d.Magnitude / 9)
	for k = 0, n - 1 do
		local p = a:Lerp(b, (k + 0.5) / n)
		Rock(base, V3(p.X, -3 + rng:NextNumber(-1.5, 1.5), p.Z), rng:NextNumber(8, 13))
	end
end

-- rocky underside, tapering to a point
for i = 1, 7 do
	local s = 1 - i * 0.12
	local y = -6 - i * 9
	for e = 1, #OCT do
		local a, b = OCT[e] * s, OCT[e % #OCT + 1] * s
		local n = math.max(2, math.floor((b - a).Magnitude / 14))
		for k = 0, n - 1 do
			local p = a:Lerp(b, k / n)
			Rock(base, V3(p.X, y + rng:NextNumber(-3, 3), p.Z), rng:NextNumber(14, 24) * (1.1 - i * 0.07))
		end
	end
end
for i = 1, 9 do
	Rock(base, V3(rng:NextNumber(-25, 25), -10 - i * 7, rng:NextNumber(-25, 25)), math.max(18, 58 - i * 4.5))
end
Rock(base, V3(0, -82, 0), 26)
Rock(base, V3(4, -92, -3), 16)
-- glowing crystals clinging to the cliffs
for i = 1, 22 do
	local e = rng:NextInteger(1, #OCT)
	local a, b = OCT[e], OCT[e % #OCT + 1]
	local p = a:Lerp(b, rng:NextNumber(0.1, 0.9))
	local out = p.Unit * rng:NextNumber(2, 6)
	Crystal(base, V3(p.X + out.X, rng:NextNumber(-12, -30), p.Z + out.Z), rng:NextNumber(1.2, 2.4), (i % 3 == 0) and C.cyan or C.purple)
end

------------------------------------------------------------------
-- 2. PATHS
------------------------------------------------------------------
local paths = Folder("Paths")
P(paths, "PathNS", V3(16, 0.4, 150.4), V3(0, 0.2, 34.8), C.path, MAT.Marble)
P(paths, "PathEW", V3(208, 0.4, 16), V3(0, 0.2, 7), C.path, MAT.Marble)
for _, sx in ipairs({ -1, 1 }) do
	P(paths, "TrimNS", V3(0.8, 0.5, 150.4), V3(sx * 8.4, 0.25, 34.8), C.gold, MAT.Metal)
	Neon(paths, "GlowNS", V3(0.3, 0.12, 150.4), V3(sx * 7.2, 0.42, 34.8), C.purple)
	P(paths, "TrimEW", V3(208, 0.5, 0.8), V3(0, 0.25, 7 + sx * 8.4), C.gold, MAT.Metal)
end
-- central red carpet from the castle stairs to the statue plaza
P(paths, "CastleCarpet", V3(12, 0.12, 24), V3(0, 0.46, -28.4), C.red, MAT.Fabric)
P(paths, "CarpetTrimL", V3(0.5, 0.14, 24), V3(-6.2, 0.47, -28.4), C.gold, MAT.Metal)
P(paths, "CarpetTrimR", V3(0.5, 0.14, 24), V3(6.2, 0.47, -28.4), C.gold, MAT.Metal)

------------------------------------------------------------------
-- 3. THE LAST ARCANA  (castle + giant book)
------------------------------------------------------------------
local castle = Folder("LastArcana")
local CZ = -84
local BY = 4.4 -- hall floor height
local WH = 31.6 -- wall height
local WY = BY + WH / 2

P(castle, "Foundation", V3(122, 4, 52), V3(0, 2, CZ), C.stoneD, MAT.Slate)
P(castle, "HallFloor", V3(116, 0.4, 50), V3(0, 4.2, CZ), rgb(58, 46, 84), MAT.Marble)
P(castle, "Carpet", V3(12, 0.12, 50), V3(0, BY + 0.06, CZ), C.red, MAT.Fabric)
P(castle, "CarpetTrimL", V3(0.5, 0.14, 50), V3(-6.2, BY + 0.07, CZ), C.gold, MAT.Metal)
P(castle, "CarpetTrimR", V3(0.5, 0.14, 50), V3(6.2, BY + 0.07, CZ), C.gold, MAT.Metal)

-- walls
P(castle, "BackWall", V3(122, WH, 3), V3(0, WY, CZ - 24.5), C.plum, MAT.Slate)
for _, sx in ipairs({ -1, 1 }) do
	P(castle, "SideWall", V3(3, WH, 50), V3(sx * 58.5, WY, CZ), C.plum, MAT.Slate)
	P(castle, "FrontWall", V3(51, WH, 3), V3(sx * 32.5, WY, CZ + 24.5), C.plum, MAT.Slate)
	P(castle, "GoldBandFront", V3(51, 0.8, 3.4), V3(sx * 32.5, 13, CZ + 24.5), C.gold, MAT.Metal)
	P(castle, "GoldBandTop", V3(51, 0.8, 3.4), V3(sx * 32.5, 35, CZ + 24.5), C.gold, MAT.Metal)
end
P(castle, "BackBand", V3(122, 0.8, 3.4), V3(0, 13, CZ - 24.5), C.gold, MAT.Metal)
P(castle, "Lintel", V3(14, 14, 3), V3(0, 29, CZ + 24.5), C.plum, MAT.Slate)
P(castle, "LintelBand", V3(14, 0.8, 3.4), V3(0, 35, CZ + 24.5), C.gold, MAT.Metal)

-- gothic gate: glowing portal, arch, gold frame
local portal = Neon(castle, "PortalGlow", V3(14, 17.6, 0.4), V3(0, BY + 8.8, CZ + 24.6), C.lamp, 0.55)
portal.CanCollide = false
local arch = Cyl(castle, "PortalArch", 14, 2.6, V3(0, 22, CZ + 24.6), C.lamp, MAT.Neon, "Z")
arch.Transparency = 0.55
arch.CanCollide = false
for _, sx in ipairs({ -1, 1 }) do
	P(castle, "DoorPost", V3(1.2, 18, 3.6), V3(sx * 7.6, BY + 9, CZ + 24.5), C.gold, MAT.Metal)
	Neon(castle, "GateCrystal", V3(1, 26, 0.5), V3(sx * 9.6, 18, CZ + 26.2), C.purple)
end
P(castle, "ArchFrame", V3(16.4, 1, 3.6), V3(0, 22.6, CZ + 24.5), C.gold, MAT.Metal)
Neon(castle, "GateEmblem", V3(5, 5, 0.5), CF(0, 30, CZ + 26.3) * CFA(0, 0, rad(45)), C.violet, 0.1)
P(castle, "GateEmblemFrame", V3(6.6, 6.6, 0.4), CF(0, 30, CZ + 26.1) * CFA(0, 0, rad(45)), C.gold, MAT.Metal)

-- roof + battlements
P(castle, "Roof", V3(122, 3, 52), V3(0, 37.5, CZ), C.plumD, MAT.Slate)
P(castle, "RoofTrim", V3(124, 0.8, 54), V3(0, 39.3, CZ), C.gold, MAT.Metal)
for x = -58, 58, 5 do
	P(castle, "Crenel", V3(3, 2.6, 2), V3(x, 40.7, CZ + 25), C.plum, MAT.Slate)
	P(castle, "Crenel", V3(3, 2.6, 2), V3(x, 40.7, CZ - 25), C.plum, MAT.Slate)
end

-- towers with spires, glowing windows, gold bands
local function Tower(x, z, r, h)
	local d = r * 2
	Cyl(castle, "TowerBody", d, h, V3(x, BY + h / 2, z), C.plum, MAT.Slate)
	for _, f in ipairs({ 0.22, 0.5, 0.8 }) do
		Cyl(castle, "TowerBand", d + 0.8, 0.8, V3(x, BY + h * f, z), C.gold, MAT.Metal)
	end
	Cyl(castle, "TowerLedge", d + 2.2, 1.4, V3(x, BY + h, z), C.stoneD, MAT.Slate)
	local n, sh = 10, r * 3.4
	for i = 1, n do
		local dd = (d + 1.2) * (1 - (i - 1) / n)
		Cyl(castle, "Spire", dd, sh / n + 0.05, V3(x, BY + h + 0.7 + (i - 0.5) * sh / n, z), C.spire, MAT.Metal)
	end
	local tip = Ball(castle, "SpireTip", 1.4, V3(x, BY + h + 0.9 + sh, z), C.gold, MAT.Neon)
	tip.CanCollide = false
	for k, ang in ipairs({ -50, 0, 50 }) do
		local nrm = V3(sin(rad(ang)), 0, cos(rad(ang)))
		local pos = V3(x, 0, z) + nrm * (r + 0.05)
		for j, f in ipairs({ 0.38, 0.66 }) do
			local col = ((k + j) % 2 == 0) and C.purple or C.lamp
			Neon(castle, "TowerWindow", V3(1.3, 4.6, 0.4), CFrame.lookAt(V3(pos.X, BY + h * f, pos.Z), V3(pos.X, BY + h * f, pos.Z) + nrm), col)
		end
	end
end
local towers = {
	{ 55, -59, 7, 52 }, { -55, -59, 7, 52 }, { 41, -59, 4.5, 40 }, { -41, -59, 4.5, 40 },
	{ 14, -59, 5.5, 60 }, { -14, -59, 5.5, 60 },
	{ 58.5, CZ, 5, 44 }, { -58.5, CZ, 5, 44 },
	{ 55, -107, 7, 62 }, { -55, -107, 7, 62 }, { 30, -108, 5, 48 }, { -30, -108, 5, 48 },
}
for _, t in ipairs(towers) do Tower(t[1], t[2], t[3], t[4]) end

-- front windows and banners
for _, sx in ipairs({ -1, 1 }) do
	for _, wx in ipairs({ 22, 34 }) do
		Neon(castle, "Window", V3(1.8, 9, 0.4), V3(sx * wx, 18, CZ + 26.2), C.lamp)
		Neon(castle, "WindowTop", V3(1.8, 1.8, 0.4), CF(sx * wx, 23.4, CZ + 26.2) * CFA(0, 0, rad(45)), C.lamp)
		Neon(castle, "WindowHigh", V3(1.6, 4.5, 0.4), V3(sx * wx, 29.5, CZ + 26.2), C.purple)
	end
end
local bannerSuits = { "♦", "♣", "♥", "♠" }
for i, sx in ipairs({ -1, 1 }) do
	local pos = V3(sx * 28, 24, CZ + 26.6)
	Banner(castle, CFrame.lookAt(pos, pos + V3(0, 0, 1)), 7, 20, bannerSuits[i])
	local pos2 = V3(sx * 50, 25, CZ + 26.6)
	Banner(castle, CFrame.lookAt(pos2, pos2 + V3(0, 0, 1)), 6, 17, bannerSuits[i + 2])
end

-- grand stairs with the red carpet
Stairs(castle, 0, CZ + 26, 34, 8, 0.55, 2.2, 1, BY, 12)
P(castle, "StairsLanding", V3(34, 0.2, 0.6), V3(0, BY, CZ + 26.2), C.gold, MAT.Metal)
for _, sx in ipairs({ -1, 1 }) do
	P(castle, "StairWall", V3(2, 3.2, 18.5), V3(sx * 18, 1.6, CZ + 35), C.stoneD, MAT.Slate)
	Lantern(castle, sx * 18, CZ + 28.5, 6)
	Lantern(castle, sx * 18, CZ + 42, 4)
end

-- interior: pillars, chandeliers, throne, stained glass
for _, sx in ipairs({ -1, 1 }) do
	for k = 0, 3 do
		local pz = CZ - 18 + k * 11
		Cyl(castle, "HallPillar", 3.2, 31.6, V3(sx * 22, WY, pz), C.silver, MAT.Marble)
		Cyl(castle, "PillarBase", 4.4, 1.2, V3(sx * 22, BY + 0.6, pz), C.gold, MAT.Metal)
		Neon(castle, "PillarGlow", V3(0.4, 24, 0.4), V3(sx * 22, WY, pz + 1.7), C.purple)
	end
end
for k = 0, 2 do
	local pz = CZ - 14 + k * 14
	Cyl(castle, "ChandelierRing", 9, 0.7, V3(0, 31, pz), C.gold, MAT.Metal)
	Neon(castle, "ChandelierInner", V3(5, 0.3, 5), V3(0, 30.6, pz), C.lamp, 0.2)
	for b = 1, 6 do
		local a = (b / 6) * math.pi * 2
		Neon(castle, "ChandelierBulb", V3(0.9, 1.4, 0.9), V3(cos(a) * 4.2, 30, pz + sin(a) * 4.2), C.lamp)
	end
	P(castle, "ChandelierChain", V3(0.3, 4, 0.3), V3(0, 34, pz), C.gold, MAT.Metal)
	local lp = Ghost(P(castle, "ChandelierLight", V3(1, 1, 1), V3(0, 29, pz), C.black, MAT.SmoothPlastic, 1))
	if CONFIG.LAMP_LIGHTS then Light(lp, C.lamp, 42, 1.6) end
end
-- throne dais at the back
for i = 1, 3 do
	P(castle, "ThroneStep", V3(24 - i * 4, 0.7, 12 - i * 2), V3(0, BY + i * 0.7 - 0.2, CZ - 20 + i * 0.5), i % 2 == 0 and C.gold or C.plumD, MAT.Marble)
end
P(castle, "ThroneSeat", V3(6, 1.2, 5), V3(0, BY + 3.2, CZ - 19), C.black, MAT.Metal)
P(castle, "ThroneCushion", V3(5, 0.5, 4), V3(0, BY + 4.1, CZ - 18.6), C.red, MAT.Fabric)
P(castle, "ThroneBack", V3(6, 14, 1.2), V3(0, BY + 10, CZ - 21.5), C.black, MAT.Metal)
P(castle, "ThroneBackGold", V3(4.2, 11, 0.5), V3(0, BY + 9.5, CZ - 20.8), C.gold, MAT.Metal)
Neon(castle, "ThroneGem", V3(2.4, 2.4, 0.4), CF(0, BY + 13, CZ - 20.5) * CFA(0, 0, rad(45)), C.violet)
local glass = Neon(castle, "StainedGlass", V3(14, 24, 0.4), V3(0, 22, CZ - 22.8), C.violet, 0.3)
glass.CanCollide = false
SurfaceText(glass, Enum.NormalId.Front, "♠", C.gold, Enum.Font.SourceSansBold, 30)
Neon(castle, "GlassFrame", V3(15.4, 0.8, 0.5), V3(0, 34.2, CZ - 22.7), C.gold)

-- THE GIANT BOOK ---------------------------------------------------
local pedZ = CZ - 4
Cyl(castle, "BookPedestal", 42, 2, V3(0, 41, pedZ), C.plumD, MAT.Slate)
Cyl(castle, "BookPedestalRing", 43, 0.5, V3(0, 42.2, pedZ), C.gold, MAT.Metal)
Neon(castle, "PedestalGlow", V3(0.5, 0.3, 0.5), V3(0, 42.5, pedZ), C.violet)
RingSegs(castle, V3(0, 42.5, pedZ), 19, 56, 0.6, C.purple)

local bookCenter = V3(0, 42 + 19, pedZ)
local bookCF = CF(bookCenter) * CFA(rad(-12), 0, 0)
local book = Folder("GiantBook", castle)
local function bookPart(name, size, localCF, color, mat)
	return P(book, name, size, bookCF * localCF, color, mat)
end
local function bookSide(sign, suit, suitColor)
	local swing = CFA(0, rad(25) * sign, 0)
	local at = CF(sign * -13.6, 0, 0)
	-- sign: +1 = left page (outer edge swings toward the viewer), -1 = right
	local cover = bookPart("Cover", V3(28.6, 36.2, 1.2), swing * at * CF(0, 0, -1.3), C.plum, MAT.Fabric)
	bookPart("CoverGoldTop", V3(29, 0.7, 1.4), swing * at * CF(0, 18.2, -1.3), C.gold, MAT.Metal)
	bookPart("CoverGoldBottom", V3(29, 0.7, 1.4), swing * at * CF(0, -18.2, -1.3), C.gold, MAT.Metal)
	bookPart("CoverGoldOuter", V3(0.7, 36.6, 1.4), swing * at * CF(sign * -14.3, 0, -1.3), C.gold, MAT.Metal)
	local page = bookPart("Page", V3(27, 34, 1), swing * at, C.cream, MAT.SmoothPlastic)
	bookPart("PageEdge", V3(27, 0.4, 1.4), swing * at * CF(0, 17.1, 0.1), C.goldD, MAT.Metal)
	SurfaceText(page, Enum.NormalId.Back, suit, suitColor, Enum.Font.SourceSansBold, 30)
	-- gold filigree lines
	for i = -2, 2 do
		bookPart("Filigree", V3(20, 0.25, 0.2), swing * at * CF(0, 14 + i * 0.6 - 3, 0.55), C.goldD, MAT.Metal).Transparency = 0.5
	end
	return page
end
bookSide(1, "♦", rgb(190, 30, 50))
bookSide(-1, "♠", rgb(20, 18, 28))
bookPart("Spine", V3(2.2, 37, 2.2), CF(0, 0, -0.8), C.gold, MAT.Metal).Shape = Enum.PartType.Cylinder
-- supports on the roof
for _, sx in ipairs({ -1, 1 }) do
	P(castle, "BookStand", V3(5, 14, 5), V3(sx * 10, 49, pedZ - 7), C.plumD, MAT.Slate)
end
local bookGlow = Ghost(P(castle, "BookGlow", V3(2, 2, 2), bookCenter + V3(0, 0, 8), C.black, MAT.SmoothPlastic, 1))
if CONFIG.LAMP_LIGHTS then
	Light(bookGlow, C.purple, 80, 3)
	Light(bookGlow, C.cyan, 55, 1.5)
end
local bookAnchor = Ghost(P(castle, "BookCenter", V3(1, 1, 1), bookCenter, C.black, MAT.SmoothPlastic, 1))

-- magic rings spinning around the book + cards orbiting it
local function MakeRing(parent, center, radius, n, color, tiltX, tiltZ, speed, thick)
	local m = Instance.new("Model")
	m.Name = "MagicRing"
	m.Parent = parent
	local pivot = Ghost(P(m, "Pivot", V3(0.2, 0.2, 0.2), center, C.black, MAT.SmoothPlastic, 1))
	m.PrimaryPart = pivot
	local arc = (2 * math.pi * radius / n) * 1.08
	for i = 1, n do
		local a = (i / n) * 2 * math.pi
		Ghost(Neon(m, "Seg", V3(thick, thick, arc), CF(center) * CFA(0, a, 0) * CF(radius, 0, 0), color))
	end
	m:PivotTo(CF(center) * CFA(tiltX, 0, tiltZ))
	m:SetAttribute("Speed", speed)
	CollectionService:AddTag(m, "EB_Ring")
	return m
end
local rings = Folder("MagicRings", castle)
MakeRing(rings, bookCenter, 30, 54, C.purple, rad(70), rad(8), 0.35, 0.5)
MakeRing(rings, bookCenter, 35, 60, C.gold, rad(-62), rad(-14), -0.28, 0.4)
MakeRing(rings, bookCenter, 40, 66, C.cyan, rad(80), rad(30), 0.2, 0.35)

local cardsF = Folder("FloatingCards", castle)
local orbitCards = {} -- {part, centerPart}
local function MakeCard(parent, pos, centerPos, centerPart, suitIndex, size)
	size = size or 1
	local suit = SUITS[(suitIndex - 1) % 4 + 1]
	local red = (suit == "♥" or suit == "♦")
	local cf = CFrame.lookAt(pos, V3(centerPos.X, pos.Y, centerPos.Z)) * CFA(0, 0, rad(rng:NextInteger(-18, 18)))
	local card = Ghost(P(parent, "Card", V3(6 * size, 8.4 * size, 0.25), cf, C.cream, MAT.SmoothPlastic))
	local glow = Ghost(Neon(parent, "CardGlow", V3(6.7 * size, 9.1 * size, 0.12), cf * CF(0, 0, 0.05), C.purple, 0.25))
	for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do
		SurfaceText(card, face, suit, red and rgb(200, 30, 54) or rgb(24, 20, 34), Enum.Font.SourceSansBold, 40)
	end
	return card, glow
end
for i = 1, 14 do
	local a = (i / 14) * math.pi * 2
	local r = 36 + (i % 3) * 5
	local pos = bookCenter + V3(cos(a) * r, rng:NextNumber(-16, 18), sin(a) * r * 0.9)
	local card, glow = MakeCard(cardsF, pos, bookCenter, bookAnchor, i, 1.1)
	table.insert(orbitCards, { card, bookAnchor, 0.18 + (i % 3) * 0.03 })
	table.insert(orbitCards, { glow, bookAnchor, 0.18 + (i % 3) * 0.03 })
end

-- purple spotlights washing the castle front
for _, sx in ipairs({ -1, 1 }) do
	local sp = Ghost(P(castle, "FrontLight", V3(1, 1, 1), V3(sx * 30, 14, CZ + 34), C.black, MAT.SmoothPlastic, 1))
	if CONFIG.LAMP_LIGHTS then Light(sp, C.purple, 40, 1.6) end
end
Pill(castle, V3(0, 50, CZ + 28), 300, 70, "THE LAST ARCANA", "Royal Card Castle")

------------------------------------------------------------------
-- 4. CARD MASTER STATUE + PLAZA
------------------------------------------------------------------
local statueF = Folder("CardMasterStatue")
local SXZ = V3(0, 0, 7)
Cyl(statueF, "PlazaOuter", 50, 0.7, V3(0, 0.35, 7), C.stoneD, MAT.Slate)
Cyl(statueF, "PlazaInner", 46, 0.9, V3(0, 0.45, 7), C.path, MAT.Marble)
RingSegs(statueF, V3(0, 0.95, 7), 21, 56, 0.6, C.purple)
RingSegs(statueF, V3(0, 0.95, 7), 17, 44, 0.5, C.gold)
for i = 1, 8 do
	local a = (i / 8) * math.pi * 2 + math.pi / 8
	Ghost(Neon(statueF, "Rune", V3(1.6, 0.2, 1.6), CF(cos(a) * 19, 0.97, 7 + sin(a) * 19) * CFA(0, a, 0) * CFA(0, rad(45), 0), C.violet))
end
Cyl(statueF, "Dais1", 28, 1.4, V3(0, 1.4, 7), C.black, MAT.Slate)
Cyl(statueF, "Dais1Gold", 28.6, 0.25, V3(0, 1.9, 7), C.gold, MAT.Metal)
Cyl(statueF, "Dais2", 22, 1.4, V3(0, 2.6, 7), C.stoneD, MAT.Marble)
Cyl(statueF, "Dais2Gold", 22.6, 0.25, V3(0, 3.2, 7), C.gold, MAT.Metal)
Cyl(statueF, "Dais3", 16, 1.2, V3(0, 3.8, 7), C.black, MAT.Slate)
RingSegs(statueF, V3(0, 4.45, 7), 7.2, 28, 0.4, C.purple)
local y0 = 4.4

-- the robed Card Master
local robe = { { 9.5, 4 }, { 8.0, 4 }, { 6.5, 4 }, { 5.2, 3 } }
local ry = y0
for _, rr in ipairs(robe) do
	Cyl(statueF, "Robe", rr[1], rr[2], V3(0, ry + rr[2] / 2, 7), C.silver, MAT.Marble)
	ry = ry + rr[2]
end
Cyl(statueF, "RobeHem", 9.9, 0.5, V3(0, y0 + 0.3, 7), C.gold, MAT.Metal)
Cyl(statueF, "Belt", 5.5, 0.5, V3(0, y0 + 11.8, 7), C.gold, MAT.Metal)
P(statueF, "Shoulders", V3(7.8, 1.8, 3.8), V3(0, y0 + 15.4, 7), C.silver, MAT.Marble)
Cyl(statueF, "Neck", 1.6, 1, V3(0, y0 + 16.8, 7), C.silver, MAT.Marble)
Ball(statueF, "Head", 3.4, V3(0, y0 + 18.4, 7), rgb(232, 224, 238), MAT.Marble)
Ball(statueF, "Hair", 3.9, V3(0, y0 + 18.6, 6.5), C.white, MAT.Marble)
Cyl(statueF, "CrownBase", 3.8, 0.5, V3(0, y0 + 19.9, 7), C.gold, MAT.Metal)
for i = 1, 5 do
	local a = (i / 5) * math.pi * 2
	P(statueF, "CrownSpike", V3(0.4, 1.6, 0.4), V3(cos(a) * 1.5, y0 + 20.9, 7 + sin(a) * 1.5), C.gold, MAT.Metal)
	Neon(statueF, "CrownGem", V3(0.35, 0.35, 0.35), V3(cos(a) * 1.5, y0 + 21.8, 7 + sin(a) * 1.5), C.cyan)
end
-- cloak
P(statueF, "CloakBack", V3(10, 18, 0.8), CF(0, y0 + 9.5, 3.9) * CFA(rad(-4), 0, 0), C.purpleD, MAT.Fabric)
P(statueF, "CloakEdge", V3(10.4, 0.5, 1), V3(0, y0 + 0.9, 3.7), C.gold, MAT.Metal)
for _, sx in ipairs({ -1, 1 }) do
	P(statueF, "CloakSide", V3(2, 14, 5.5), CF(sx * 5.2, y0 + 8, 6.4) * CFA(0, rad(sx * 14), 0), C.purpleD, MAT.Fabric)
	P(statueF, "CloakSideGold", V3(0.4, 14.4, 5.8), CF(sx * 6.2, y0 + 8, 6.4) * CFA(0, rad(sx * 14), 0), C.gold, MAT.Metal)
end
-- right arm + golden staff
P(statueF, "ArmR", V3(1.5, 6, 1.5), CF(4.5, y0 + 13.4, 7.8) * CFA(rad(-30), 0, rad(-12)), C.silver, MAT.Marble)
Ball(statueF, "HandR", 1.7, V3(5.4, y0 + 10.8, 9), rgb(232, 224, 238), MAT.Marble)
P(statueF, "Staff", V3(0.6, 34, 0.6), V3(5.6, y0 + 15, 9), C.gold, MAT.Metal)
Cyl(statueF, "StaffRing", 4.4, 0.6, V3(5.6, y0 + 32, 9), C.gold, MAT.Metal, "Z")
for i = 1, 4 do
	local a = (i / 4) * math.pi * 2
	P(statueF, "StaffSpike", V3(0.4, 1.6, 0.4), CF(5.6 + cos(a) * 2.6, y0 + 32 + sin(a) * 2.6, 9) * CFA(0, 0, a - math.pi / 2), C.gold, MAT.Metal)
end
local orb = Ball(statueF, "StaffOrb", 2.8, V3(5.6, y0 + 32, 9), C.violet, MAT.Neon)
orb.CanCollide = false
if CONFIG.LAMP_LIGHTS then
	Light(orb, C.purple, 55, 2.5)
end
-- left arm raised, holding a spinning card
P(statueF, "ArmL", V3(1.5, 6, 1.5), CF(-4.6, y0 + 14, 8) * CFA(rad(-50), 0, rad(18)), C.silver, MAT.Marble)
Ball(statueF, "HandL", 1.7, V3(-5.6, y0 + 16.6, 10), rgb(232, 224, 238), MAT.Marble)
local spinCard = Ghost(P(statueF, "SpinCard", V3(4.2, 5.9, 0.2), V3(-5.6, y0 + 20.5, 10), C.cream, MAT.SmoothPlastic))
for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do
	SurfaceText(spinCard, face, "♠", rgb(24, 20, 34), Enum.Font.SourceSansBold, 40)
end
Ghost(Neon(statueF, "SpinCardGlow", V3(4.8, 6.5, 0.1), V3(-5.6, y0 + 20.5, 10), C.purple, 0.3))
spinCard:SetAttribute("Speed", 1.2)
CollectionService:AddTag(spinCard, "EB_Spin")
-- cards orbiting the statue
local statueAnchor = Ghost(P(statueF, "StatueCenter", V3(1, 1, 1), V3(0, y0 + 14, 7), C.black, MAT.SmoothPlastic, 1))
for i = 1, 6 do
	local a = (i / 6) * math.pi * 2
	local pos = V3(cos(a) * 14, y0 + 8 + (i % 3) * 7, 7 + sin(a) * 14)
	local card, glow = MakeCard(statueF, pos, V3(0, 0, 7), statueAnchor, i, 0.8)
	table.insert(orbitCards, { card, statueAnchor, 0.3 })
	table.insert(orbitCards, { glow, statueAnchor, 0.3 })
end
-- lanterns around the plaza
for i = 1, 8 do
	local a = (i / 8) * math.pi * 2 + math.pi / 8
	Lantern(statueF, cos(a) * 23.5, 7 + sin(a) * 23.5, 7)
end
Pill(statueF, V3(0, 46, 7), 240, 60, "CARD MASTER", nil)

------------------------------------------------------------------
-- 5. THE FOUR DUEL ZONES
------------------------------------------------------------------
local arenasF = Folder("DuelZones")

local function OctagonFloor(parent, name, cx, cz, w, d, c, y, h, color, mat)
	P(parent, name .. "A", V3(w, h, d - 2 * c), V3(cx, y, cz), color, mat)
	P(parent, name .. "B", V3(w - 2 * c, h, d), V3(cx, y + 0.002, cz), color, mat)
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1, 1 }) do
			P(parent, name .. "C", V3(c * 1.4142, h, c * 1.4142), CF(cx + sx * (w / 2 - c), y + 0.004, cz + sz * (d / 2 - c)) * CFA(0, rad(45), 0), color, mat)
		end
	end
end
local function OctVerts(cx, cz, w, d, c)
	local hx, hz = w / 2, d / 2
	return {
		V3(cx - hx + c, 0, cz - hz), V3(cx + hx - c, 0, cz - hz), V3(cx + hx, 0, cz - hz + c), V3(cx + hx, 0, cz + hz - c),
		V3(cx + hx - c, 0, cz + hz), V3(cx - hx + c, 0, cz + hz), V3(cx - hx, 0, cz + hz - c), V3(cx - hx, 0, cz - hz + c),
	}
end

local Y0 = 1.0 -- arena floor top

local function MakeTable(parent, center, chairs, suitIndex)
	local D = 5 + chairs * 0.5
	local m = Instance.new("Model")
	m.Name = "DuelTable"
	m.Parent = parent
	Cyl(m, "TableFoot", D * 0.5, 0.5, V3(center.X, Y0 + 0.25, center.Z), C.gold, MAT.Metal)
	Cyl(m, "TableColumn", 2.2, 2.4, V3(center.X, Y0 + 1.5, center.Z), C.black, MAT.Metal)
	Cyl(m, "TableTop", D, 0.7, V3(center.X, Y0 + 2.9, center.Z), C.black, MAT.Metal)
	Cyl(m, "TableGoldRim", D + 0.3, 0.25, V3(center.X, Y0 + 3.0, center.Z), C.gold, MAT.Metal)
	Cyl(m, "TableGlowRing", D - 0.7, 0.12, V3(center.X, Y0 + 3.29, center.Z), C.purple, MAT.Neon)
	local felt = Cyl(m, "TableFelt", D - 1.4, 0.16, V3(center.X, Y0 + 3.31, center.Z), C.violet, MAT.Fabric)
	SurfaceText(felt, Enum.NormalId.Right, SUITS[(suitIndex - 1) % 4 + 1], C.gold, Enum.Font.SourceSansBold, 30)
	for i = 1, 3 do
		local a = rng:NextNumber(0, math.pi * 2)
		P(m, "TableCard", V3(1.3, 0.05, 1.9), CF(center.X + cos(a) * D * 0.28, Y0 + 3.42, center.Z + sin(a) * D * 0.28) * CFA(0, rng:NextNumber(0, 6), 0), C.cream, MAT.SmoothPlastic)
	end
	for i = 1, chairs do
		local a = (i / chairs) * math.pi * 2 + math.pi / chairs
		local r = D / 2 + 2.4
		local pos = V3(center.X + cos(a) * r, Y0, center.Z + sin(a) * r)
		local cf = CFrame.lookAt(pos, V3(center.X, Y0, center.Z))
		P(m, "ChairBase", V3(2, 1.6, 2), cf * CF(0, 0.8, 0), C.black, MAT.Metal)
		P(m, "ChairSeat", V3(2.6, 0.5, 2.6), cf * CF(0, 1.9, 0), C.black, MAT.Metal)
		P(m, "ChairCushion", V3(2.1, 0.4, 2.1), cf * CF(0, 2.3, 0), C.red, MAT.Fabric)
		P(m, "ChairBack", V3(2.6, 5, 0.5), cf * CF(0, 4.4, 1.2), C.black, MAT.Metal)
		P(m, "ChairBackInlay", V3(1.7, 3.4, 0.2), cf * CF(0, 4.4, 0.9), C.red, MAT.Fabric)
		P(m, "ChairCrest", V3(2.9, 0.4, 0.7), cf * CF(0, 7, 1.2), C.gold, MAT.Metal)
		P(m, "ChairTrim", V3(2.7, 0.2, 2.7), cf * CF(0, 2.2, 0), C.gold, MAT.Metal)
		local seat = Instance.new("Seat")
		seat.Name = "PlayerSeat"
		seat.Anchored = true
		seat.Size = Vector3.new(2.2, 0.3, 2.2)
		seat.CFrame = cf * CF(0, 2.75, 0)
		seat.Transparency = 1
		seat.CanCollide = false
		seat.Parent = m
	end
end

local function MakeZone(name, cx, cz, chairs, info, signSuit)
	local f = Folder(name, arenasF)
	local W, Dp, c = 60, 50, 9
	OctagonFloor(f, "Plinth", cx, cz, W + 5, Dp + 5, c + 2, 0.4, 0.8, C.stoneD, MAT.Slate)
	OctagonFloor(f, "Floor", cx, cz, W, Dp, c, Y0 - 0.45, 0.9, rgb(212, 206, 224), MAT.Marble)
	local vOuter = OctVerts(cx, cz, W - 1.5, Dp - 1.5, c)
	local vInner = OctVerts(cx, cz, W - 4, Dp - 4, c - 1)
	EdgeStrips(f, vOuter, Y0 + 0.03, 0.5, C.gold, MAT.Neon)
	EdgeStrips(f, vInner, Y0 + 0.03, 0.3, C.purple, MAT.Neon)
	-- faint emblem in the middle of the floor
	local emblem = Cyl(f, "FloorEmblem", 24, 0.06, V3(cx, Y0 + 0.04, cz), C.purple, MAT.Neon)
	emblem.Transparency = 0.88
	emblem.CanCollide = false
	-- 5 tables: 2 top, 1 center, 2 bottom
	local offs = { V3(-15, 0, -12), V3(15, 0, -12), V3(0, 0, 0), V3(-15, 0, 12), V3(15, 0, 12) }
	for i, o in ipairs(offs) do
		MakeTable(f, V3(cx + o.X, 0, cz + o.Z), chairs, signSuit + i - 1)
	end
	-- chamfer hedges, lanterns
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1, 1 }) do
			local mx, mz = cx + sx * (W / 2 - c / 2 + 3.2), cz + sz * (Dp / 2 - c / 2 + 3.2)
			Planter(f, CF(mx, 0, mz) * CFA(0, rad(sx * sz * 45), 0), 11, 2.6)
			Lantern(f, cx + sx * (W / 2 + 2.2), cz + sz * (Dp / 2 - c - 1), 7)
		end
	end
	-- walkway from the central path with a small stair up
	local dirToPath = (cx > 0) and -1 or 1
	P(f, "Walkway", V3(16.4, 0.4, 8), V3(cx + dirToPath * (W / 2 + 8.2), 0.2, cz), C.path, MAT.Marble)
	P(f, "WalkStep", V3(2, 0.5, 8), V3(cx + dirToPath * (W / 2 + 1.5), 0.25, cz), C.stoneD, MAT.Slate)
	Neon(f, "WalkGlow", V3(16, 0.1, 0.3), V3(cx + dirToPath * (W / 2 + 8.2), 0.42, cz + 3.8), C.purple)
	Neon(f, "WalkGlow", V3(16, 0.1, 0.3), V3(cx + dirToPath * (W / 2 + 8.2), 0.42, cz - 3.8), C.purple)
	-- floating zone sign
	Pill(f, V3(cx, 24, cz), 210, 90, info.title, info.sub, C.gold)
end

MakeZone("Zone_2v2", -54, -20, 4, { title = "2v2", sub = "5 TABLES • 4 CHAIRS EACH" }, 1)
MakeZone("Zone_3v3", 54, -20, 6, { title = "3v3", sub = "5 TABLES • 6 CHAIRS EACH" }, 2)
MakeZone("Zone_1v1", -54, 52, 2, { title = "1v1", sub = "5 TABLES • 2 CHAIRS EACH" }, 3)
MakeZone("Zone_4v4", 54, 52, 8, { title = "4v4", sub = "5 TABLES • 8 CHAIRS EACH" }, 4)

------------------------------------------------------------------
-- 6. LEADERBOARD SCREENS
------------------------------------------------------------------
local boards = Folder("Leaderboards")
local function Leaderboard(x, face)
	local dirIn = (x < 0) and 1 or -1 -- screen faces the map center
	P(boards, "BoardBase", V3(7, 2, 34), V3(x, 1, 7), C.stoneD, MAT.Slate)
	P(boards, "BoardBaseGold", V3(7.4, 0.4, 34.4), V3(x, 2.1, 7), C.gold, MAT.Metal)
	P(boards, "BoardFrame", V3(3, 18, 30), V3(x, 11.5, 7), C.black, MAT.Metal)
	for _, sz in ipairs({ -1, 1 }) do
		P(boards, "BoardPillar", V3(3.4, 22, 3.4), V3(x, 13, 7 + sz * 16), C.plumD, MAT.Slate)
		Neon(boards, "BoardPillarGlow", V3(0.4, 18, 0.4), V3(x + dirIn * 1.8, 13, 7 + sz * 16), C.purple)
		Lantern(boards, x, 7 + sz * 19, 9)
	end
	P(boards, "BoardCrest", V3(3.4, 2, 36), V3(x, 24.5, 7), C.gold, MAT.Metal)
	Neon(boards, "BoardCrestGem", V3(0.6, 4, 4), CF(x + dirIn * 1.8, 27, 7) * CFA(0, 0, rad(45)), C.violet)
	local screen = P(boards, "Screen", V3(0.6, 15, 26), V3(x + dirIn * 1.6, 11.5, 7), rgb(12, 10, 24), MAT.SmoothPlastic)
	local sg = Instance.new("SurfaceGui")
	sg.Name = "LeaderboardGui"
	sg.Face = face
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = 50
	sg.LightInfluence = 0
	sg.Parent = screen
	local title = Instance.new("TextLabel")
	title.Size = UDim2.fromScale(1, 0.16)
	title.BackgroundTransparency = 1
	title.Text = "♠  LEADERBOARD  ♦"
	title.TextScaled = true
	title.Font = Enum.Font.GothamBlack
	title.TextColor3 = C.gold
	title.Parent = sg
	for i = 1, 8 do
		local row = Instance.new("TextLabel")
		row.Name = "Row" .. i
		row.Size = UDim2.fromScale(0.9, 0.09)
		row.Position = UDim2.fromScale(0.05, 0.17 + (i - 1) * 0.1)
		row.BackgroundColor3 = C.purpleD
		row.BackgroundTransparency = 0.35
		row.Text = string.format("  #%d    ----------    0", i)
		row.TextXAlignment = Enum.TextXAlignment.Left
		row.TextScaled = true
		row.Font = Enum.Font.GothamBold
		row.TextColor3 = (i <= 3) and C.gold or C.white
		row.Parent = sg
	end
end
Leaderboard(-91, Enum.NormalId.Right)
Leaderboard(91, Enum.NormalId.Left)

------------------------------------------------------------------
-- 7. WATERFALLS ALL AROUND THE ISLAND
------------------------------------------------------------------
local waterF = Folder("Waterfalls")
local function Waterfall(x, z, w, dx, dz)
	local alongX = (dz ~= 0)
	local edge = V3(x, 0, z)
	local dir = V3(dx, 0, dz)
	local c = edge - dir * 5.9
	P(waterF, "PoolBase", alongX and V3(w + 3, 0.6, 16) or V3(16, 0.6, w + 3), V3(c.X, 0.3, c.Z), C.stoneD, MAT.Slate)
	local pool = Ghost(P(waterF, "PoolWater", alongX and V3(w, 0.9, 13) or V3(13, 0.9, w), V3(c.X, 1.05, c.Z), C.water, MAT.Glass, 0.3))
	for _, s in ipairs({ -1, 1 }) do
		local sideSize = alongX and V3(1.2, 2.2, 15) or V3(15, 2.2, 1.2)
		local off = alongX and V3(s * (w / 2 + 0.9), 1.1, 0) or V3(0, 1.1, s * (w / 2 + 0.9))
		P(waterF, "PoolWall", sideSize, c + off, C.stoneD, MAT.Slate)
		P(waterF, "PoolWallGold", alongX and V3(1.4, 0.3, 15.2) or V3(15.2, 0.3, 1.4), c + off + V3(0, 1.2, 0), C.gold, MAT.Metal)
	end
	P(waterF, "PoolBack", alongX and V3(w + 3, 2.2, 1.2) or V3(1.2, 2.2, w + 3), c - dir * 7.2 + V3(0, 1.1, 0), C.stoneD, MAT.Slate)
	Neon(waterF, "PoolGlow", alongX and V3(w - 2, 0.1, 10) or V3(10, 0.1, w - 2), V3(c.X, 1.52, c.Z), C.cyan, 0.7).CanCollide = false
	-- the falling sheet
	local sheet = Ghost(P(waterF, "FallSheet", alongX and V3(w, 75, 1) or V3(1, 75, w), V3(x + dx * 0.5, -36, z + dz * 0.5), C.water, MAT.Glass, 0.3))
	local core = Ghost(Neon(waterF, "FallCore", alongX and V3(w - 2, 75, 0.4) or V3(0.4, 75, w - 2), V3(x + dx * 0.9, -36, z + dz * 0.9), C.cyan, 0.78))
	for _, face in ipairs(alongX and { Enum.NormalId.Front, Enum.NormalId.Back } or { Enum.NormalId.Left, Enum.NormalId.Right }) do
		local tx = Instance.new("Texture")
		tx.Texture = "rbxasset://textures/particles/smoke_main.dds"
		tx.Face = face
		tx.StudsPerTileU = 6
		tx.StudsPerTileV = 14
		tx.Transparency = 0.45
		tx.Color3 = C.white
		tx.Parent = sheet
		tx:SetAttribute("Speed", 14)
		CollectionService:AddTag(tx, "EB_Flow")
	end
	-- spray at the lip, mist at the bottom, glow
	Emitter(waterF, alongX and V3(w, 1, 2) or V3(2, 1, w), V3(x + dx * 1.2, 2, z + dz * 1.2), {
		rate = 14, lifetime = NumberRange.new(1, 2), speed = NumberRange.new(2, 5), size = NumberSequence.new(1.5, 3),
		transparency = NumberSequence.new(0.6, 1), light = 0.5, accel = V3(dx * 2, -4, dz * 2), spread = 40, box = true,
	})
	local mistPos = V3(x + dx * 3, -72, z + dz * 3)
	Emitter(waterF, alongX and V3(w, 1, 6) or V3(6, 1, w), mistPos, {
		rate = 26, lifetime = NumberRange.new(4, 7), speed = NumberRange.new(2, 6), size = NumberSequence.new(10, 28),
		transparency = NumberSequence.new(0.55, 1), light = 0.6, spread = 60, box = true,
		color = ColorSequence.new(rgb(200, 230, 255)),
	})
	local gl = Ghost(P(waterF, "MistGlow", V3(1, 1, 1), mistPos + V3(0, 4, 0), C.black, MAT.SmoothPlastic, 1))
	if CONFIG.LAMP_LIGHTS then Light(gl, C.cyan, 40, 1.5) end
end
-- west & east edges
Waterfall(-105, -62, 22, -1, 0)
Waterfall(-105, 52, 26, -1, 0)
Waterfall(105, -62, 22, 1, 0)
Waterfall(105, 52, 26, 1, 0)
-- north corners and south
Waterfall(-62, -110, 20, 0, -1)
Waterfall(62, -110, 20, 0, -1)
Waterfall(-45, 110, 26, 0, 1)
Waterfall(45, 110, 26, 0, 1)

------------------------------------------------------------------
-- 8. BRIDGES + SMALL ISLETS (west & east)
------------------------------------------------------------------
local bridges = Folder("Bridges")
for _, sx in ipairs({ -1, 1 }) do
	local bx = sx * 118
	P(bridges, "BridgeDeck", V3(26, 1, 9), V3(bx, -0.5, -5), C.wood, MAT.WoodPlanks)
	for _, sz in ipairs({ -4.6, 4.6 }) do
		P(bridges, "BridgeRail", V3(26, 0.5, 0.6), V3(bx, 2.6, -5 + sz), C.gold, MAT.Metal)
		P(bridges, "BridgeRailLow", V3(26, 0.4, 0.5), V3(bx, 1.2, -5 + sz), C.black, MAT.Metal)
	end
	for i = -2, 2 do
		for _, sz in ipairs({ -4.6, 4.6 }) do
			P(bridges, "BridgePost", V3(0.7, 3.2, 0.7), V3(bx + i * 6, 1.6, -5 + sz), C.black, MAT.Metal)
		end
	end
	Lantern(bridges, sx * 107, -10.5, 7)
	Lantern(bridges, sx * 107, 0.5, 7)
	-- islet at the end of the bridge
	local ix = sx * 142
	Cyl(bridges, "IsletTop", 26, 3, V3(ix, -1.5, -5), C.grass, MAT.Grass)
	for i = 1, 6 do
		Cyl(bridges, "IsletRock", 26 * (1 - i / 7), 6, V3(ix, -3 - i * 5.5, -5), C.rock, MAT.Rock)
	end
	Rock(bridges, V3(ix + 5, -8, -5), 8)
	Rock(bridges, V3(ix - 5, -14, -3), 7)
	Tree(bridges, ix + sx * 4, -2, 0.9, true)
	Lantern(bridges, ix - sx * 6, -10, 7)
	Lantern(bridges, ix - sx * 6, 0, 7)
	Crystal(bridges, V3(ix, -20, -5), 1.8, C.purple)
end

------------------------------------------------------------------
-- 9. SPAWN POINT (south)
------------------------------------------------------------------
local spawnF = Folder("Spawn")
local SZ = 94
Cyl(spawnF, "SpawnDisc", 24, 0.7, V3(0, 0.35, SZ), C.stoneD, MAT.Slate)
Cyl(spawnF, "SpawnGoldRing", 21, 0.8, V3(0, 0.4, SZ), C.gold, MAT.Metal)
Cyl(spawnF, "SpawnFloor", 19.4, 0.9, V3(0, 0.45, SZ), C.path, MAT.Marble)
for i = 0, 3 do
	Ghost(Neon(spawnF, "CompassPoint", V3(1.4, 0.15, 17), CF(0, 0.93, SZ) * CFA(0, rad(i * 45), 0), C.gold))
end
RingSegs(spawnF, V3(0, 0.95, SZ), 6, 24, 0.5, C.purple)
local Nmark = P(spawnF, "NorthMark", V3(3, 0.15, 3), V3(0, 0.95, SZ - 7.8), C.black, MAT.SmoothPlastic)
SurfaceText(Nmark, Enum.NormalId.Top, "N", C.gold, Enum.Font.GothamBlack, 40)
local spawn = Instance.new("SpawnLocation")
spawn.Name = "PlayerSpawn"
spawn.Anchored = true
spawn.Neutral = true
spawn.Duration = 0
spawn.Size = V3(8, 0.4, 8)
spawn.Position = V3(0, 1.1, SZ)
spawn.Color = C.gold
spawn.Material = MAT.Neon
spawn.Transparency = 0.8
spawn.Parent = spawnF
-- arrow pointing north
P(spawnF, "ArrowShaft", V3(2, 0.15, 7), V3(0, 0.5, SZ - 17), C.black, MAT.SmoothPlastic)
P(spawnF, "ArrowHead", V3(4.4, 0.15, 4.4), CF(0, 0.5, SZ - 22) * CFA(0, rad(45), 0), C.black, MAT.SmoothPlastic)
-- gate pillars + banners
for _, sx in ipairs({ -1, 1 }) do
	Cyl(spawnF, "GatePillar", 4, 16, V3(sx * 11, 8, 107), C.plum, MAT.Slate)
	Cyl(spawnF, "GatePillarGold", 4.6, 0.8, V3(sx * 11, 14, 107), C.gold, MAT.Metal)
	Cyl(spawnF, "GatePillarGold", 4.6, 0.8, V3(sx * 11, 2, 107), C.gold, MAT.Metal)
	for i = 1, 6 do
		Cyl(spawnF, "GateSpire", 4.4 * (1 - (i - 1) / 6), 1.1, V3(sx * 11, 16.5 + i, 107), C.spire, MAT.Metal)
	end
	Ball(spawnF, "GateTip", 1.2, V3(sx * 11, 23.7, 107), C.gold, MAT.Neon)
	local pos = V3(sx * 15, 11, 88)
	Banner(spawnF, CFrame.lookAt(pos, pos + V3(0, 0, -1)), 5, 12, SUITS[(sx == -1) and 1 or 3])
	P(spawnF, "BannerPoleL", V3(0.6, 18, 0.6), V3(sx * 18, 9, 88), C.gold, MAT.Metal)
	P(spawnF, "BannerPoleR", V3(0.6, 18, 0.6), V3(sx * 12, 9, 88), C.gold, MAT.Metal)
	Lantern(spawnF, sx * 7, 100, 7)
end
Pill(spawnF, V3(0, 30, 107), 280, 80, "ECHOBOUND", "SPAWN POINT")

------------------------------------------------------------------
-- 10. DECORATION: lanterns, planters, trees
------------------------------------------------------------------
local deco = Folder("Decoration")
for z = -36, 104, 14 do
	if math.abs(z - 7) > 28 or z > 40 then
		Lantern(deco, -10.5, z, 8)
		Lantern(deco, 10.5, z, 8)
	end
end
for x = -100, 100, 20 do
	if math.abs(x) > 28 and math.abs(math.abs(x) - 91) > 6 then
		Lantern(deco, x, 16, 7)
		Lantern(deco, x, -2, 7)
	end
end
for _, sx in ipairs({ -1, 1 }) do
	for _, pz in ipairs({ -34, 60, 82 }) do
		Planter(deco, CF(sx * 14.5, 0, pz), 5, 14)
	end
	Planter(deco, CF(sx * 14, 0, 44), 5, 10)
	for _, tp in ipairs({ { 17, -36 }, { 17, 40 }, { 17, 70 } }) do
		Tree(deco, sx * tp[1], tp[2], 0.9, false)
	end
end
local treeSpots = {
	{ -95, -34 }, { -97, -12 }, { -98, 24 }, { -90, 78 }, { -72, 100 }, { -86, -86 }, { -74, -50 },
	{ 95, -34 }, { 97, -12 }, { 98, 24 }, { 90, 78 }, { 72, 100 }, { 86, -86 }, { 74, -50 },
	{ -48, -52 }, { 48, -52 }, { -22, 84 }, { 22, 84 }, { -92, 100 }, { 92, 100 },
}
for i, t in ipairs(treeSpots) do
	Tree(deco, t[1], t[2], 0.9 + rng:NextNumber(0, 0.5), (i % 5 == 0))
end

------------------------------------------------------------------
-- 11. DISTANT FLOATING ISLANDS
------------------------------------------------------------------
local isles = Folder("FloatingIslands")
local function MiniIsland(x, y, z, s)
	local m = Instance.new("Model")
	m.Name = "FloatingIsland"
	m.Parent = isles
	local r = 30 * s
	Cyl(m, "Top", r, 3, V3(x, y, z), C.grass, MAT.Grass)
	for i = 1, 8 do
		Cyl(m, "RockLayer", r * (1 - i / 9) + 1, 7 * s, V3(x, y - 1.5 - (i - 0.5) * 7 * s, z), (i % 2 == 0) and C.rock or C.rockL, MAT.Rock)
		Rock(m, V3(x + rng:NextNumber(-r / 3, r / 3), y - i * 6 * s, z + rng:NextNumber(-r / 3, r / 3)), rng:NextNumber(6, 12) * s)
	end
	for i = 1, rng:NextInteger(1, 3) do
		Tree(m, x + rng:NextNumber(-r / 3, r / 3), z + rng:NextNumber(-r / 3, r / 3), 0.8 * s + 0.4, i == 2)
	end
	if s > 0.9 then -- tiny tower
		local tx = x + r * 0.15
		Cyl(m, "MiniTower", 5 * s, 16 * s, V3(tx, y + 8 * s + 1.5, z), C.plum, MAT.Slate)
		for i = 1, 8 do
			Cyl(m, "MiniSpire", (5 * s + 1) * (1 - (i - 1) / 8), 1.3 * s, V3(tx, y + 16 * s + 2.5 + i * 1.3 * s, z), C.spire, MAT.Metal)
		end
		Neon(m, "MiniWindow", V3(1, 3, 0.4), V3(tx, y + 10 * s, z + 2.6 * s), C.lamp)
	end
	for i = 1, 3 do
		Crystal(m, V3(x + rng:NextNumber(-r / 2.6, r / 2.6), y + 2.5, z + rng:NextNumber(-r / 2.6, r / 2.6)), 1.2 * s, (i % 2 == 0) and C.cyan or C.purple)
	end
	-- thin waterfall off the edge
	local wx = x + r / 2
	local sheet = Ghost(P(m, "MiniFall", V3(1, 60 * s, 0.6 * s + 2), V3(wx, y - 28 * s, z), C.water, MAT.Glass, 0.3))
	Ghost(Neon(m, "MiniFallCore", V3(0.4, 60 * s, 1), V3(wx + 0.4, y - 28 * s, z), C.cyan, 0.7))
	m:SetAttribute("Phase", rng:NextNumber(0, 6.28))
	CollectionService:AddTag(m, "EB_Island")
end
for i = 1, 18 do
	local a = (i / 18) * math.pi * 2 + rng:NextNumber(-0.15, 0.15)
	local dist = rng:NextNumber(230, 520)
	MiniIsland(math.cos(a) * dist, rng:NextNumber(-70, 110), math.sin(a) * dist, rng:NextNumber(0.6, 1.6))
end

------------------------------------------------------------------
-- 12. LIVING AMBIENCE: floating sparkles over the whole island
------------------------------------------------------------------
Emitter(map, V3(230, 1, 240), V3(0, 6, 0), {
	texture = "rbxasset://textures/particles/sparkles_main.dds", rate = 70, lifetime = NumberRange.new(8, 14),
	speed = NumberRange.new(0.5, 2), size = NumberSequence.new(0.5, 0.15), transparency = NumberSequence.new(0.2, 1),
	light = 1, accel = V3(0, 0.4, 0), spread = 180, box = true,
	color = ColorSequence.new(rgb(190, 140, 255), rgb(255, 220, 140)),
})
Emitter(castle, V3(110, 1, 50), V3(0, 44, CZ), {
	texture = "rbxasset://textures/particles/sparkles_main.dds", rate = 50, lifetime = NumberRange.new(6, 10),
	speed = NumberRange.new(1, 3), size = NumberSequence.new(0.7, 0.2), transparency = NumberSequence.new(0.1, 1),
	light = 1, accel = V3(0, 1.2, 0), spread = 60, box = true, color = ColorSequence.new(C.cyan, C.purple),
})

------------------------------------------------------------------
-- FINISH: scale everything, then hand the animation data to clients
------------------------------------------------------------------
map:ScaleTo(CONFIG.SCALE)

for _, oc in ipairs(orbitCards) do
	local p, centerPart, speed = oc[1], oc[2], oc[3]
	p:SetAttribute("Center", centerPart.Position)
	p:SetAttribute("Speed", speed)
	p:SetAttribute("Phase", rng:NextNumber(0, 6.28))
	p:SetAttribute("Amp", 1.5 * CONFIG.SCALE)
	CollectionService:AddTag(p, "EB_Card")
end
map:SetAttribute("Built", true)
print("Echobound card island built ✔ (scale x" .. CONFIG.SCALE .. ")")
