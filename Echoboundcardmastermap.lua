--[[
    ECHOBOUND x CASINO KINGDOM  (merged server builder)
    Echobound card island + the floating-casino features: themed dragon arenas, framed monster-card
    displays, red spectator grandstands, red carpets. See CONFIG.THEME to switch to the red/gold casino palette.
    (original header follows)
    ECHOBOUND - CARD ISLAND  v2  (server builder)
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
	CLOCK       = 19.2,   -- time of day (0 = midnight, 19 = purple dusk)
	THEME       = "ECHO", -- "ECHO" = purple night look, "CASINO" = red / gold casino look
	-- paste your own artwork here as "rbxassetid://123456789" (empty = built-in emoji art)
	CardImages  = { Fire = "", Ice = "", Shadow = "", Gold = "" },
	FloorImages = { Fire = "", Ice = "", Shadow = "", Gold = "" },
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
if CONFIG.THEME == "CASINO" then
	C.purple  = rgb(236, 54, 76)
	C.purpleD = rgb(72, 12, 30)
	C.violet  = rgb(212, 40, 70)
	C.plum    = rgb(46, 28, 38)
	C.plumD   = rgb(28, 16, 24)
	C.spire   = rgb(30, 20, 28)
	C.stone   = rgb(150, 146, 158)
	C.stoneD  = rgb(96, 92, 108)
end
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
local function Banner(parent, cf, w, h, suit, clothColor)
	local cloth = P(parent, "BannerCloth", V3(w, h, 0.4), cf, clothColor or C.purpleD, MAT.Fabric)
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
-- EXTRA HELPERS (v2)
------------------------------------------------------------------
-- cylinder "bone" between two points (arms, legs, vines, hair...)
local function Limb(parent, name, a, b, d, color, mat)
	local dir = b - a
	local len = dir.Magnitude
	if len < 0.01 then return nil end
	local up = (math.abs(dir.Unit.Y) > 0.98) and V3(0, 0, 1) or V3(0, 1, 0)
	local p = P(parent, name, V3(len, d, d), CFrame.lookAt((a + b) / 2, b, up) * CFA(0, rad(90), 0), color, mat)
	p.Shape = Enum.PartType.Cylinder
	return p
end

-- tapered spike made of 3 shrinking segments
local function Spike(parent, base, tip, d, color, mat, tipColor)
	for i = 0, 2 do
		local a, b = base:Lerp(tip, i / 3), base:Lerp(tip, (i + 1) / 3)
		local last = (i == 2) and tipColor or nil
		Limb(parent, "Spike", a, b, math.max(d * (1 - i / 3), 0.2), last or color, last and MAT.Neon or mat)
	end
end

-- rock that can never poke above maxTop (keeps the plaza clean)
local function RockLow(parent, pos, size, maxTop)
	local r = size * 1.05
	return Rock(parent, V3(pos.X, math.min(pos.Y, (maxTop or 0) - r), pos.Z), size)
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
Lighting.ClockTime = CONFIG.CLOCK
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
if CONFIG.THEME == "CASINO" then
	Lighting.Ambient = rgb(120, 78, 78)
	Lighting.OutdoorAmbient = rgb(140, 100, 96)
	Lighting.ColorShift_Top = rgb(255, 170, 120)
	atm.Color = rgb(236, 160, 150)
	atm.Decay = rgb(120, 54, 66)
	cc.TintColor = rgb(255, 236, 226)
end

------------------------------------------------------------------
-- 1. THE FLOATING ISLAND  (v2: clean cliffs, nothing pokes through the plaza)
------------------------------------------------------------------
local base = Folder("Island")

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

-- grass lip + rim rocks (rim rocks hang BELOW the edge now)
for e = 1, #OCT do
	local a, b = OCT[e], OCT[e % #OCT + 1]
	local d = b - a
	local mid = (a + b) / 2
	local inward = (-mid).Unit * 3.5
	local yaw = math.atan2(-d.Z, d.X)
	Ghost(P(base, "GrassLip", V3(d.Magnitude * 0.97, 0.3, 7), CF(mid.X + inward.X, 0.15, mid.Z + inward.Z) * CFA(0, yaw, 0), C.grass, MAT.Grass))
	-- gold edge trim so the rim looks royal
	P(base, "RimTrim", V3(d.Magnitude * 0.99, 0.5, 0.9), CF(mid.X, 0.05, mid.Z) * CFA(0, yaw, 0), C.goldD, MAT.Metal)
	local n = math.floor(d.Magnitude / 9)
	for k = 0, n - 1 do
		local p = a:Lerp(b, (k + 0.5) / n)
		RockLow(base, V3(p.X, -2, p.Z), rng:NextNumber(8, 13), 0.3)
	end
end

-- solid tapered core under the plaza (replaces the old giant random rocks)
for i = 1, 10 do
	local dia = 196 * (1 - i * 0.09) + 8
	Cyl(base, "CoreLayer", dia, 11, V3(0, -2 - i * 8, 0), (i % 2 == 0) and C.rock or C.rockL, MAT.Rock)
end

-- rocky underside, tapering to a point (all clamped below the plaza)
for i = 1, 8 do
	local s = 1 - i * 0.11
	local y = -6 - i * 10
	for e = 1, #OCT do
		local a, b = OCT[e] * s, OCT[e % #OCT + 1] * s
		local n = math.max(2, math.floor((b - a).Magnitude / 14))
		for k = 0, n - 1 do
			local p = a:Lerp(b, k / n)
			RockLow(base, V3(p.X, y + rng:NextNumber(-3, 3), p.Z), rng:NextNumber(14, 24) * (1.1 - i * 0.07), -2)
		end
	end
end
Rock(base, V3(0, -96, 0), 24)
Rock(base, V3(3, -104, -2), 14)

-- glowing crystals clinging to the cliffs
for i = 1, 26 do
	local e = rng:NextInteger(1, #OCT)
	local a, b = OCT[e], OCT[e % #OCT + 1]
	local p = a:Lerp(b, rng:NextNumber(0.1, 0.9))
	local out = p.Unit * rng:NextNumber(2, 6)
	Crystal(base, V3(p.X + out.X, rng:NextNumber(-30, -12), p.Z + out.Z), rng:NextNumber(1.2, 2.4), (i % 3 == 0) and C.cyan or C.purple)
end

-- hanging vines and leaves
for i = 1, 36 do
	local e = rng:NextInteger(1, #OCT)
	local a, b = OCT[e], OCT[e % #OCT + 1]
	local p = a:Lerp(b, rng:NextNumber(0.05, 0.95))
	local out = V3(p.X, 0, p.Z).Unit * 4
	local top = V3(p.X + out.X, -4, p.Z + out.Z)
	local len = rng:NextNumber(8, 26)
	local tip = top + V3(rng:NextNumber(-1, 1), -len, rng:NextNumber(-1, 1)) + out * 0.3
	Limb(base, "Vine", top, tip, 0.5, C.leaf1, MAT.Grass)
	for k = 1, 3 do
		local lp = top:Lerp(tip, k / 3.2)
		Ball(base, "VineLeaf", rng:NextNumber(1.6, 2.6), lp + V3(rng:NextNumber(-0.6, 0.6), 0, rng:NextNumber(-0.6, 0.6)), (k % 2 == 0) and C.leaf2 or C.leaf1, MAT.Grass)
	end
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
-- long red carpet from the spawn to the Card Master (casino picture)
P(paths, "RoyalRoadCarpet", V3(10, 0.12, 50), V3(0, 0.46, 57), C.red, MAT.Fabric)
for _, sx in ipairs({ -1, 1 }) do
	P(paths, "RoyalRoadTrim", V3(0.45, 0.14, 50), V3(sx * 5.2, 0.47, 57), C.gold, MAT.Metal)
end
for z = 38, 78, 20 do
	local medal = P(paths, "RoyalRoadMedallion", V3(6, 0.06, 6), CFrame.new(0, 0.54, z) * CFA(0, rad(45), 0), C.gold, MAT.Metal)
	medal.CanCollide = false
	Ghost(Neon(paths, "RoyalRoadMedallionCore", V3(3.4, 0.05, 3.4), CFrame.new(0, 0.58, z) * CFA(0, rad(45), 0), C.violet))
end

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
------------------------------------------------------------------
-- PERSONA-STYLE MONSTERS printed on Yu-Gi-Oh style cards (replace the old floating cards)
-- Every monster has a rarity from 1 to 9 stars. Higher rarity = bigger, glowier,
-- more features (wings, third eye, halo, orbs, crown, aura).
------------------------------------------------------------------
local RARITY = {
	{ "Pale Wisp",        rgb(196, 196, 212) },
	{ "Moss Imp",         rgb(100, 214, 124) },
	{ "Frost Phantom",    rgb(90, 160, 255) },
	{ "Hex Warden",       rgb(178, 100, 255) },
	{ "Rose Specter",     rgb(255, 100, 204) },
	{ "Ember Djinn",      rgb(255, 156, 60) },
	{ "Crimson Reaper",   rgb(255, 66, 80) },
	{ "Gilded Sovereign", rgb(255, 216, 88) },
	{ "Arcana Eternal",   rgb(150, 255, 246) },
}
local BODY = {
	{ rgb(40, 30, 70), rgb(84, 64, 138) },   -- 1: hooded wraith
	{ rgb(22, 44, 56), rgb(46, 96, 118) },   -- 2: horned winged beast
	{ rgb(58, 26, 40), rgb(128, 56, 82) },   -- 3: masked armored knight
}
local CARDCOL = { rgb(124, 86, 168), rgb(206, 112, 46), rgb(216, 178, 86) } -- fusion / effect / normal frame colors
local monsters = {} -- {model, anchor, speed, ph}  (animated at the end of the script)

local function BuildMonster(parent, rarity, kind, suitIdx)
	local acc = RARITY[rarity][2]
	local dark, light = BODY[kind][1], BODY[kind][2]
	local m = Instance.new("Model")
	m.Name = "Monster_" .. rarity .. "Star"
	m.Parent = parent
	-- front of the monster is -Z, built around the origin
	local root = P(m, "Root", V3(1, 1, 1), CF(0, 0, 0), C.black, MAT.SmoothPlastic, 1)
	m.PrimaryPart = root
	local function L(n, a, b, d, col, mat) return Limb(m, n, a, b, d, col, mat) end
	local function B(n, d, at, col, mat) return Ball(m, n, d, at, col, mat) end

	-- spectral tail (it hovers, no legs)
	Spike(m, V3(0, -0.4, 0.2), V3(0, -7, 1.4), 3.4, dark, MAT.Fabric, acc)
	-- torso
	P(m, "Torso", V3(3.6, 3.8, 2.2), CF(0, 1.5, 0), dark, MAT.Fabric)
	P(m, "TorsoTrim", V3(3.9, 0.4, 2.4), CF(0, 0.1, 0), light, MAT.Metal)
	-- the old card lives on as a chest emblem
	local suit = SUITS[(suitIdx - 1) % 4 + 1]
	local emblemGlow = Neon(m, "EmblemGlow", V3(1.9, 2.6, 0.1), CF(0, 1.7, -1.12), acc)
	local emb = P(m, "Emblem", V3(1.6, 2.3, 0.12), CF(0, 1.7, -1.2), C.cream, MAT.SmoothPlastic)
	SurfaceText(emb, Enum.NormalId.Front, suit, (suit == "♥" or suit == "♦") and rgb(200, 30, 54) or rgb(24, 20, 34), Enum.Font.SourceSansBold, 40)

	-- shoulders + arms (fists glow in the rarity color)
	for _, sx in ipairs({ -1, 1 }) do
		B("Pauldron", 2.2, V3(sx * 2.3, 3.2, 0), light, MAT.Metal)
		if rarity >= 3 then
			Spike(m, V3(sx * 2.3, 4.0, 0), V3(sx * 3.3, 6.0, 0.3), 1.1, light, MAT.Metal, acc)
		end
		L("UpperArm", V3(sx * 2.3, 3.0, 0), V3(sx * 3.2, 1.4, -0.9), 1.1, dark, MAT.Fabric)
		L("Forearm", V3(sx * 3.2, 1.4, -0.9), V3(sx * 2.2, 1.2, -3.0), 1.0, light, MAT.Metal)
		B("Fist", (kind == 3) and 2.0 or 1.4, V3(sx * 2.2, 1.2, -3.2), acc, MAT.Neon)
		if kind == 1 then -- wraith claws
			Spike(m, V3(sx * 2.2, 1.2, -3.6), V3(sx * 2.2, 1.0, -6.0), 0.7, light, MAT.Metal, acc)
		end
	end

	-- head (3 different looks)
	if kind == 1 then
		B("Hood", 3.6, V3(0, 4.9, 0.2), dark, MAT.Fabric)
		B("FaceVoid", 2.3, V3(0, 4.7, -0.7), C.black, MAT.SmoothPlastic)
		P(m, "Cloak", V3(4.6, 6.0, 0.4), CF(0, 1.0, 1.3) * CFA(rad(8), 0, 0), dark, MAT.Fabric)
	elseif kind == 2 then
		B("Head", 2.8, V3(0, 4.7, -0.2), dark, MAT.SmoothPlastic)
		P(m, "Snout", V3(1.6, 1.0, 1.2), CF(0, 4.3, -1.5), light, MAT.Metal)
		for _, sx in ipairs({ -1, 1 }) do
			Spike(m, V3(sx * 1.0, 5.6, 0), V3(sx * 2.6, 7.4, -0.8), 1.0, light, MAT.Metal, acc)
			P(m, "Fang", V3(0.2, 0.55, 0.2), CF(sx * 0.5, 3.75, -2.0), C.white, MAT.SmoothPlastic)
		end
	else
		B("Helm", 3.0, V3(0, 4.7, -0.1), light, MAT.Metal)
		P(m, "Mask", V3(2.2, 1.8, 0.35), CF(0, 4.6, -1.45), C.cream, MAT.Marble)
		Spike(m, V3(0, 6.0, 0.2), V3(0, 8.0, 1.6), 1.0, dark, MAT.Fabric, acc)
	end
	local ez = ({ -1.75, -1.55, -1.72 })[kind]
	for _, sx in ipairs({ -1, 1 }) do
		Neon(m, "Eye", V3(0.8, 0.24, 0.16), CF(sx * 0.6, 4.85, ez) * CFA(0, 0, rad(sx * 18)), acc)
	end
	if rarity >= 5 then
		Neon(m, "ThirdEye", V3(0.4, 0.4, 0.14), CF(0, 5.5, ez + 0.05) * CFA(0, 0, rad(45)), C.white)
	end

	-- energy wings
	local wings = (kind == 2 or rarity >= 4) and 3 or 0
	for _, sx in ipairs({ -1, 1 }) do
		for w = 1, wings do
			local f = L("Feather", V3(sx * 1.4, 3.4, 1.0), V3(sx * (3.4 + w * 1.3), 6.2 - w * 1.7, 2.2 + w * 0.4), 0.55, acc, MAT.Neon)
			if f then f.Transparency = 0.25 end
		end
	end

	-- halo(s)
	local function Halo(radius, n, thick, color)
		local arc = (2 * math.pi * radius / n) * 1.1
		for i = 1, n do
			local a = (i / n) * math.pi * 2
			Neon(m, "HaloSeg", V3(thick, arc, 0.22), CF(0, 4.9, 2.2) * CFA(0, 0, a) * CF(radius, 0, 0), color)
		end
	end
	if rarity >= 6 then Halo(3.2, 18, 0.4, acc) end
	if rarity >= 9 then Halo(4.3, 24, 0.3, C.white) end
	-- floating orbs
	if rarity >= 7 then
		for _, sx in ipairs({ -1, 1 }) do B("Orb", 1.2, V3(sx * 4.6, 6.4, -0.6), acc, MAT.Neon) end
	end
	-- golden crown
	if rarity >= 8 then
		for k = -2, 2 do
			L("Crown", V3(k * 0.55, 6.1, 0), V3(k * 0.75, 7.0 - math.abs(k) * 0.25, 0), 0.32, C.gold, MAT.Metal)
		end
	end
	-- aura bubble
	if rarity >= 9 then
		local au = B("Aura", 8, V3(0, 2.2, 0), acc, MAT.Neon)
		au.Transparency = 0.88
	end
	if rarity >= 8 and CONFIG.LAMP_LIGHTS then Light(emblemGlow, acc, 22, 1.2) end

	-- ===== YU-GI-OH STYLE CARD printed behind the monster =====
	local cy, cz = 0.5, 4.7
	local ink = rgb(30, 24, 40)
	P(m, "CardBody", V3(19, 29.2, 0.5), CF(0, cy, cz), CARDCOL[kind], MAT.SmoothPlastic)
	-- rarity-colored glowing rim
	Neon(m, "RimTop", V3(20, 0.35, 0.5), CF(0, cy + 14.775, cz), acc)
	Neon(m, "RimBottom", V3(20, 0.35, 0.5), CF(0, cy - 14.775, cz), acc)
	for _, sx in ipairs({ -1, 1 }) do
		Neon(m, "RimSide", V3(0.35, 29.9, 0.5), CF(sx * 9.675, cy, cz), acc)
	end
	-- card back (seen from behind)
	local back = P(m, "CardBack", V3(19, 29.2, 0.15), CF(0, cy, cz + 0.33), rgb(92, 50, 26), MAT.SmoothPlastic)
	SurfaceText(back, Enum.NormalId.Back, "♠ ♥\nARCANA\n♣ ♦", C.gold, Enum.Font.GothamBlack, 30)
	-- stars above the monster (1 to 9 = rarity)
	P(m, "StarBack", V3(17.4, 2.0, 0.12), CF(0, 13.2, 4.4), rgb(26, 20, 38), MAT.SmoothPlastic)
	local sp = P(m, "StarText", V3(16.8, 1.8, 0.05), CF(0, 13.2, 4.32), C.black, MAT.SmoothPlastic, 1)
	local st = SurfaceText(sp, Enum.NormalId.Front, string.rep("★", rarity), acc, Enum.Font.SourceSansBold, 40)
	if rarity == 9 then -- rainbow stars for the top tier
		st.TextColor3 = C.white
		local g = Instance.new("UIGradient")
		g.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, rgb(255, 90, 90)),
			ColorSequenceKeypoint.new(0.2, rgb(255, 220, 90)),
			ColorSequenceKeypoint.new(0.4, rgb(110, 255, 140)),
			ColorSequenceKeypoint.new(0.6, rgb(100, 220, 255)),
			ColorSequenceKeypoint.new(0.8, rgb(170, 120, 255)),
			ColorSequenceKeypoint.new(1, rgb(255, 110, 220)),
		})
		g.Parent = st
	end
	-- art window (the monster stands in front of it)
	P(m, "ArtFrame", V3(17.2, 19.8, 0.1), CF(0, 2.0, 4.42), C.gold, MAT.Metal)
	P(m, "ArtWindow", V3(16.4, 19, 0.15), CF(0, 2.0, 4.375), acc:Lerp(C.black, 0.82), MAT.SmoothPlastic)
	-- ATTACK / DEFENSE label (knight = defense, the others = attack)
	local isDef = (kind == 3)
	local lab = P(m, "TypeLabel", V3(17.4, 4.0, 0.12), CF(0, -11.0, 4.4), rgb(236, 224, 190), MAT.SmoothPlastic)
	SurfaceText(lab, Enum.NormalId.Front, isDef and "DEFENSE CARD" or "ATTACK CARD",
		isDef and rgb(30, 80, 190) or rgb(190, 30, 40), Enum.Font.GothamBlack, 40)

	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") then
			d.CanCollide = false
			d.CanTouch = false
			d.CanQuery = false
			d.CastShadow = false
		end
	end
	m:ScaleTo(0.45 + rarity * 0.04) -- rarer = bigger
	return m
end

local function AddMonster(parent, pos, anchor, rarity, kind, suitIdx, speed)
	local m = BuildMonster(parent, rarity, kind, suitIdx)
	local out = V3(pos.X - anchor.Position.X, 0, pos.Z - anchor.Position.Z)
	out = (out.Magnitude > 0.01) and out.Unit or V3(0, 0, -1)
	m:PivotTo(CFrame.lookAt(pos, pos + out)) -- faces outward
	table.insert(monsters, { model = m, anchor = anchor, speed = speed, ph = rng:NextNumber(0, 6.28) })
	return m
end

-- monsters orbiting the big castle book
for i = 1, 14 do
	local a = (i / 14) * math.pi * 2
	local r = 44 + (i % 3) * 5
	local pos = bookCenter + V3(cos(a) * r, rng:NextNumber(-16, 18), sin(a) * r * 0.9)
	AddMonster(cardsF, pos, bookAnchor, ((i * 4 - 1) % 9) + 1, (i % 3) + 1, i, 0.18 + (i % 3) * 0.03)
end

-- purple spotlights washing the castle front
for _, sx in ipairs({ -1, 1 }) do
	local sp = Ghost(P(castle, "FrontLight", V3(1, 1, 1), V3(sx * 30, 14, CZ + 34), C.black, MAT.SmoothPlastic, 1))
	if CONFIG.LAMP_LIGHTS then Light(sp, C.purple, 40, 1.6) end
end
Pill(castle, V3(0, 50, CZ + 28), 300, 70, "THE LAST ARCANA", "Royal Card Castle")

------------------------------------------------------------------
-- 4. THE CARD MASTER  (v2: giant anime hero holding his Book of Cards)
------------------------------------------------------------------
local floatScreens, screenCenter = {}, nil

do
local statueF = Folder("CardMasterStatue")
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
local function S(x, y, z) return V3(x, y0 + y, 7 + z) end

local skin  = rgb(246, 222, 206)
local hairW = rgb(240, 240, 255)
local coat, coatL = C.purpleD, rgb(88, 52, 160)

-- nameplate on the dais
local plate = P(statueF, "NamePlate", V3(10, 1.3, 0.4), CF(0, 3.9, 15.3), C.black, MAT.Metal)
SurfaceText(plate, Enum.NormalId.Back, "THE CARD MASTER", C.gold, Enum.Font.GothamBlack, 40)
P(statueF, "NamePlateGold", V3(10.6, 0.25, 0.5), V3(0, 4.65, 15.3), C.gold, MAT.Metal)

-- ===== LEGS, BOOTS, COAT FRONT, SHOULDERS, ARMS (mirrored) =====
for _, sx in ipairs({ -1, 1 }) do
	P(statueF, "Boot", V3(3.6, 2.6, 6.6), CF(S(sx * 2.8, 1.3, 1.0)), C.black, MAT.Metal)
	P(statueF, "BootCap", V3(3.8, 0.5, 6.8), CF(S(sx * 2.8, 2.6, 1.0)), C.gold, MAT.Metal)
	Limb(statueF, "Leg", S(sx * 2.8, 2.8, 0), S(sx * 2.7, 17, 0), 3.8, C.plumD, MAT.Fabric)
	Ball(statueF, "KneeGuard", 4, S(sx * 2.8, 10, 1.6), C.gold, MAT.Metal)
	-- long coat panels
	P(statueF, "CoatFront", V3(4.2, 12, 0.9), CF(S(sx * 3.1, 12, 2.8)) * CFA(rad(-6), rad(sx * -8), 0), coat, MAT.Fabric)
	P(statueF, "CoatFrontTrim", V3(0.5, 12.2, 1.1), CF(S(sx * 5.0, 12, 2.9)) * CFA(rad(-6), rad(sx * -8), 0), C.gold, MAT.Metal)
	-- card holsters on the hips
	P(statueF, "CardHolster", V3(2, 3, 1.2), CF(S(sx * 4.6, 17.2, 2.4)) * CFA(0, rad(sx * -25), 0), C.black, MAT.Metal)
	P(statueF, "HolsterCards", V3(1.6, 2.4, 0.4), CF(S(sx * 4.4, 18.2, 2.9)) * CFA(0, rad(sx * -25), 0), C.cream, MAT.SmoothPlastic)
	-- spiked golden pauldrons
	Ball(statueF, "Pauldron", 5.4, S(sx * 5.8, 30.4, 0), C.gold, MAT.Metal)
	Spike(statueF, S(sx * 5.8, 32.2, 0), S(sx * 8.2, 37.5, -0.5), 1.8, C.gold, MAT.Metal, C.violet)
	Spike(statueF, S(sx * 6.8, 31.4, 0), S(sx * 10.4, 34.8, -0.5), 1.4, C.gold, MAT.Metal, C.cyan)
	if sx == 1 then
		-- RIGHT arm reaches forward and holds the Book of Cards with ONE hand
		Limb(statueF, "UpperArm", S(sx * 5.8, 29.8, 0), S(sx * 8.4, 23.2, 2.6), 3, coat, MAT.Fabric)
		Ball(statueF, "Elbow", 3.2, S(sx * 8.4, 23.2, 2.6), C.gold, MAT.Metal)
		Limb(statueF, "Forearm", S(sx * 8.4, 23.2, 2.6), S(sx * 8.2, 18.8, 7.6), 2.7, C.silver, MAT.Marble)
		Ball(statueF, "Cuff", 3.3, S(sx * 8.2, 18.9, 7.4), C.gold, MAT.Metal)
		Ball(statueF, "Hand", 2.7, S(sx * 8.2, 18.2, 8.3), skin, MAT.SmoothPlastic)
	else
		-- LEFT arm rests relaxed, hand on his hip
		Limb(statueF, "UpperArm", S(-5.8, 29.8, 0), S(-9.6, 24.6, -0.4), 3, coat, MAT.Fabric)
		Ball(statueF, "Elbow", 3.2, S(-9.6, 24.6, -0.4), C.gold, MAT.Metal)
		Limb(statueF, "Forearm", S(-9.6, 24.6, -0.4), S(-5.6, 19.9, 1.9), 2.7, C.silver, MAT.Marble)
		Ball(statueF, "Cuff", 3.3, S(-5.9, 20.3, 1.6), C.gold, MAT.Metal)
		Ball(statueF, "Hand", 2.7, S(-5.2, 19.5, 2.6), skin, MAT.SmoothPlastic)
	end
end

-- ===== TORSO =====
P(statueF, "Hips", V3(9.4, 3, 5.4), CF(S(0, 17.5, 0)), C.plumD, MAT.Fabric)
P(statueF, "Belt", V3(9.8, 1.2, 5.8), CF(S(0, 19.4, 0)), C.gold, MAT.Metal)
Neon(statueF, "BeltBuckle", V3(2, 2, 0.5), CF(S(0, 19.4, 3.0)) * CFA(0, 0, rad(45)), C.cyan)
P(statueF, "Torso", V3(9, 11, 5), CF(S(0, 25.5, 0)), coat, MAT.Fabric)
P(statueF, "ChestPlate", V3(7.4, 6.6, 1), CF(S(0, 27.2, 2.7)), C.gold, MAT.Metal)
P(statueF, "ChestInlay", V3(5.6, 4.8, 0.3), CF(S(0, 27.2, 3.25)), C.plumD, MAT.Slate)
local chestGem = Neon(statueF, "ChestGem", V3(1.8, 1.8, 0.4), CF(S(0, 27.4, 3.5)) * CFA(0, 0, rad(45)), C.cyan)
if CONFIG.LAMP_LIGHTS then Light(chestGem, C.cyan, 30, 2) end
-- high collar + scarf
P(statueF, "Collar", V3(11, 3.4, 1.4), CF(S(0, 31.6, -2.2)) * CFA(rad(-14), 0, 0), coat, MAT.Fabric)
P(statueF, "CollarTrim", V3(11.4, 0.4, 1.6), CF(S(0, 33.2, -2.6)) * CFA(rad(-14), 0, 0), C.gold, MAT.Metal)
Cyl(statueF, "Neck", 2.4, 1.6, S(0, 32.4, 0.2), skin, MAT.SmoothPlastic)
Cyl(statueF, "ScarfRing", 5.6, 1.6, S(0, 31.5, 0), C.red, MAT.Fabric)
for i = 1, 5 do
	P(statueF, "ScarfTail", V3(2.2, 0.5, 3.4),
		CF(S(3.2, 31.2 - i * 0.9, -2.6 - i * 2.7)) * CFA(rad(8 + i * 3), rad(-8), rad(-6 + i * 2)),
		(i == 5) and C.gold or C.red, MAT.Fabric)
end

-- ===== CAPE =====
P(statueF, "Cape", V3(13, 27, 0.9), CF(S(0, 21, -3.6)) * CFA(rad(-6), 0, 0), C.purpleD, MAT.Fabric)
Neon(statueF, "CapeRune", V3(0.5, 20, 0.2), CF(S(0, 22, -4.1)) * CFA(rad(-6), 0, 0), C.violet)
for _, sx in ipairs({ -1, 1 }) do
	P(statueF, "CapeTrim", V3(0.5, 27.2, 1.1), CF(S(sx * 6.6, 21, -3.7)) * CFA(rad(-6), 0, 0), C.gold, MAT.Metal)
	P(statueF, "CapeWing", V3(8, 20, 0.7), CF(S(sx * 9.8, 22, -5.2)) * CFA(rad(-8), rad(sx * 28), rad(sx * 6)), coatL, MAT.Fabric)
end
for i = -3, 3 do
	P(statueF, "CapeTatter", V3(1.7, 6 + math.abs(i) * 0.4, 0.6),
		CF(S(i * 1.9, 6.4, -5.0 - (i % 2) * 0.6)) * CFA(rad(-14 - math.abs(i) * 2), 0, rad(i * 3)), C.purpleD, MAT.Fabric)
end

-- ===== HEAD (anime face) =====
Ball(statueF, "Head", 5.4, S(0, 36, 0.4), skin, MAT.SmoothPlastic)
for _, sx in ipairs({ -1, 1 }) do
	local ec = S(sx * 1.25, 36.3, 2.72)
	local tilt = CFA(0, 0, rad(sx * 8))
	P(statueF, "EyeWhite", V3(1.7, 1.0, 0.25), CF(ec) * tilt, C.white, MAT.SmoothPlastic)
	Neon(statueF, "Iris", V3(0.85, 0.95, 0.12), CF(ec + V3(sx * -0.05, -0.02, 0.17)) * tilt, C.cyan)
	P(statueF, "Pupil", V3(0.34, 0.76, 0.1), CF(ec + V3(sx * -0.05, -0.02, 0.24)) * tilt, C.black, MAT.SmoothPlastic)
	Neon(statueF, "EyeShine", V3(0.26, 0.26, 0.1), CF(ec + V3(0.2, 0.22, 0.3)), C.white)
	P(statueF, "Lash", V3(2.0, 0.2, 0.3), CF(ec + V3(sx * 0.1, 0.55, 0.12)) * tilt, C.black, MAT.SmoothPlastic)
	P(statueF, "LashWing", V3(0.9, 0.18, 0.25), CF(ec + V3(sx * 1.0, 0.75, 0.05)) * CFA(0, 0, rad(sx * 28)), C.black, MAT.SmoothPlastic)
	P(statueF, "Brow", V3(1.9, 0.3, 0.25), CF(S(sx * 1.35, 37.55, 2.62)) * CFA(0, 0, rad(sx * 14)), C.black, MAT.SmoothPlastic)
	Neon(statueF, "FaceMark", V3(0.9, 0.12, 0.1), CF(S(sx * 1.5, 35.3, 2.72)) * CFA(0, 0, rad(sx * -20)), C.violet)
end
P(statueF, "Nose", V3(0.35, 0.8, 0.5), CF(S(0, 35.3, 3.05)), rgb(226, 196, 180), MAT.SmoothPlastic)
P(statueF, "Smirk", V3(1.3, 0.2, 0.2), CF(S(0.2, 34.4, 2.62)) * CFA(0, 0, rad(6)), C.black, MAT.SmoothPlastic)

-- hair: cap, forehead bangs, swept-back anime spikes with glowing tips
Ball(statueF, "Hair", 6.2, S(0, 37.6, -0.7), hairW, MAT.SmoothPlastic)
for i = -3, 3 do
	local ai = math.abs(i)
	Spike(statueF, S(i * 0.85, 39.6, 1.6 - ai * 0.1), S(i * 0.95, 37.9, 2.9 - ai * 0.35), 1.5, hairW, MAT.SmoothPlastic, C.violet)
end
local hc = S(0, 37.8, -0.9)
for i = 1, 20 do
	local a = (i / 20) * math.pi * 2
	if not (a > rad(45) and a < rad(135)) then
		local o0 = V3(cos(a), rng:NextNumber(0.3, 1.0), sin(a)).Unit
		local bp = hc + o0 * 2.4
		local dir = (o0 + V3(0, 0.15, -0.6)).Unit
		Spike(statueF, bp, bp + dir * rng:NextNumber(5, 10), 1.7, hairW, MAT.SmoothPlastic, (i % 3 == 0) and C.cyan or C.violet)
	end
end
-- golden forehead gem
Neon(statueF, "ForeheadGem", V3(0.8, 0.8, 0.3), CF(S(0, 38.5, 2.95)) * CFA(0, 0, rad(45)), C.gold)

-- glowing halo behind the head
local function HaloRing(center, radius, n, thick, color)
	local arc = (2 * math.pi * radius / n) * 1.1
	for i = 1, n do
		local a = (i / n) * math.pi * 2
		Ghost(Neon(statueF, "HaloSeg", V3(thick, arc, 0.35), CF(center) * CFA(0, 0, a) * CF(radius, 0, 0), color))
	end
end
HaloRing(S(0, 37.5, -4.5), 8.5, 48, 0.7, C.cyan)
HaloRing(S(0, 37.5, -4.6), 7.4, 40, 0.5, C.gold)

-- ===== THE BOOK OF CARDS =====
local bookCF = CF(S(8.2, 23.6, 8.8)) * CFA(rad(8), rad(-12), 0) -- centered over his RIGHT hand
local PW, PH = 7.6, 10.4
local function bk(name, size, lcf, color, mat)
	return P(statueF, name, size, bookCF * lcf, color, mat)
end
for _, sg in ipairs({ -1, 1 }) do
	local swing = CFA(0, rad(-24) * sg, 0)
	local off = CF(sg * (PW / 2 + 0.3), 0, 0)
	bk("BookCover", V3(PW + 0.8, PH + 0.8, 0.7), swing * off * CF(0, 0, -0.75), C.plum, MAT.Fabric)
	bk("BookGoldTop", V3(PW + 1, 0.5, 0.9), swing * off * CF(0, PH / 2 + 0.45, -0.75), C.gold, MAT.Metal)
	bk("BookGoldBottom", V3(PW + 1, 0.5, 0.9), swing * off * CF(0, -PH / 2 - 0.45, -0.75), C.gold, MAT.Metal)
	bk("BookGoldOuter", V3(0.5, PH + 1, 0.9), swing * off * CF(sg * (PW / 2 + 0.45), 0, -0.75), C.gold, MAT.Metal)
	local pg = bk("BookPage", V3(PW, PH, 0.5), swing * off, C.cream, MAT.SmoothPlastic)
	SurfaceText(pg, Enum.NormalId.Back, (sg == -1) and "♦" or "♠", (sg == -1) and rgb(190, 30, 50) or rgb(20, 18, 28), Enum.Font.SourceSansBold, 40)
	for k = -1, 1 do
		bk("BookLine", V3(PW - 2, 0.15, 0.1), swing * off * CF(0, 3.6 + k * 0.5, 0.28), C.goldD, MAT.Metal)
	end
	if CONFIG.LAMP_LIGHTS then Light(pg, (sg == -1) and C.purple or C.cyan, 40, 2.5) end
end
Cyl(statueF, "BookSpine", 1.3, PH + 0.8, bookCF * CF(0, 0, -0.8), C.gold, MAT.Metal)
-- thumb over the front, fingers curled behind the book (one-handed grip)
P(statueF, "Thumb", V3(1.0, 2.0, 1.0), bookCF * CF(-1.3, -4.1, 0.7) * CFA(0, 0, rad(-18)), skin, MAT.SmoothPlastic)
for k = 0, 2 do
	Ball(statueF, "Finger", 1.1, (bookCF * CF(0.2 + k * 1.1, -4.5, -1.9)).Position, skin, MAT.SmoothPlastic)
end
Emitter(statueF, V3(12, 1, 3), S(8.2, 29, 9.5), {
	texture = "rbxasset://textures/particles/sparkles_main.dds", rate = 30, lifetime = NumberRange.new(2, 4),
	speed = NumberRange.new(2, 5), size = NumberSequence.new(0.8, 0.2), transparency = NumberSequence.new(0.1, 1),
	light = 1, accel = V3(0, 3, 0), spread = 25, box = true, color = ColorSequence.new(C.cyan, C.purple),
})

-- ===== MONSTERS: persona-style guardians in his aura + orbiting him (1-9 star rarity) =====
local statueAnchor = Ghost(P(statueF, "StatueCenter", V3(1, 1, 1), S(0, 24, 0), C.black, MAT.SmoothPlastic, 1))
-- three top-rarity guardians (9, 8 and 7 stars)
for k, d in ipairs({ { S(-19, 38, 8), 9 }, { S(19, 44, 6), 8 }, { S(0, 56, 2), 7 } }) do
	AddMonster(statueF, d[1], statueAnchor, d[2], k, k, 0.12)
end
for i = 1, 10 do
	local a = (i / 10) * math.pi * 2
	local pos = V3(cos(a) * 30, y0 + 12 + (i % 4) * 8, 7 + sin(a) * 30)
	AddMonster(statueF, pos, statueAnchor, ((i * 4 - 1) % 9) + 1, (i % 3) + 1, i, 0.25)
end
Emitter(statueF, V3(14, 1, 14), S(0, 1, 0), {
	texture = "rbxasset://textures/particles/sparkles_main.dds", rate = 40, lifetime = NumberRange.new(4, 7),
	speed = NumberRange.new(2, 5), size = NumberSequence.new(0.9, 0.2), transparency = NumberSequence.new(0.1, 1),
	light = 1, accel = V3(0, 3, 0), spread = 30, box = true, color = ColorSequence.new(C.cyan, C.purple),
})

-- lanterns around the plaza
for i = 1, 8 do
	local a = (i / 8) * math.pi * 2 + math.pi / 8
	Lantern(statueF, cos(a) * 23.5, 7 + sin(a) * 23.5, 7)
end

-- ===== FLOATING SCREENS ABOVE THE CARD MASTER =====
local screensF = Folder("FloatingScreens")
screenCenter = Ghost(P(screensF, "ScreenCenter", V3(1, 1, 1), S(0, 62, 0), C.black, MAT.SmoothPlastic, 1))

local function FloatScreen(idx, title, lines, accent, glyph)
	local m = Instance.new("Model")
	m.Name = "FloatingScreen" .. idx
	m.Parent = screensF
	local W, H = 22, 12.6
	local root = Ghost(P(m, "Root", V3(1, 1, 1), CF(0, 0, 0), C.black, MAT.SmoothPlastic, 1))
	m.PrimaryPart = root
	-- front of the screen is -Z
	P(m, "Back", V3(W + 1.6, H + 1.6, 0.9), CF(0, 0, 0.1), C.black, MAT.Metal)
	local scr = P(m, "Screen", V3(W, H, 0.3), CF(0, 0, -0.35), rgb(10, 8, 24), MAT.SmoothPlastic)
	for _, sy in ipairs({ -1, 1 }) do
		Neon(m, "Trim", V3(W + 2, 0.4, 0.6), CF(0, sy * (H / 2 + 0.9), -0.3), accent)
	end
	for _, sx in ipairs({ -1, 1 }) do
		Neon(m, "Trim", V3(0.4, H + 2, 0.6), CF(sx * (W / 2 + 0.9), 0, -0.3), accent)
		for _, sy in ipairs({ -1, 1 }) do
			Ball(m, "CornerGem", 1.4, CF(sx * (W / 2 + 0.9), sy * (H / 2 + 0.9), -0.4), C.gold, MAT.Metal)
		end
	end
	P(m, "Projector", V3(3, 1.6, 3), CF(0, -(H / 2 + 2.2), 0), C.gold, MAT.Metal)
	Neon(m, "ProjectorGlow", V3(1.6, 0.3, 1.6), CF(0, -(H / 2 + 3.1), 0), accent)
	for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do
		local sg = Instance.new("SurfaceGui")
		sg.Name = "ScreenGui"
		sg.Face = face
		sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		sg.PixelsPerStud = 40
		sg.LightInfluence = 0
		sg.Parent = scr
		local fr = Instance.new("Frame")
		fr.Size = UDim2.fromScale(1, 1)
		fr.BackgroundColor3 = C.purpleD
		fr.BorderSizePixel = 0
		fr.Parent = sg
		local grad = Instance.new("UIGradient")
		grad.Color = ColorSequence.new(rgb(70, 36, 130), rgb(14, 10, 34))
		grad.Rotation = 90
		grad.Parent = fr
		local gl = Instance.new("TextLabel")
		gl.BackgroundTransparency = 1
		gl.Size = UDim2.fromScale(0.34, 0.95)
		gl.Position = UDim2.fromScale(0.64, 0.03)
		gl.Text = glyph
		gl.TextScaled = true
		gl.Font = Enum.Font.SourceSansBold
		gl.TextColor3 = accent
		gl.TextTransparency = 0.8
		gl.Parent = fr
		local t = Instance.new("TextLabel")
		t.Name = "Title"
		t.BackgroundTransparency = 1
		t.Size = UDim2.fromScale(0.94, 0.2)
		t.Position = UDim2.fromScale(0.03, 0.05)
		t.Text = title
		t.TextScaled = true
		t.TextXAlignment = Enum.TextXAlignment.Left
		t.Font = Enum.Font.GothamBlack
		t.TextColor3 = accent
		t.Parent = fr
		for k, line in ipairs(lines) do
			local l = Instance.new("TextLabel")
			l.Name = "Line" .. k
			l.BackgroundTransparency = 1
			l.Size = UDim2.fromScale(0.94, 0.12)
			l.Position = UDim2.fromScale(0.03, 0.29 + (k - 1) * 0.13)
			l.Text = line
			l.TextScaled = true
			l.TextXAlignment = Enum.TextXAlignment.Left
			l.Font = Enum.Font.GothamBold
			l.TextColor3 = C.white
			l.Parent = fr
		end
		local stroke = Instance.new("UIStroke")
		stroke.Color = accent
		stroke.Thickness = 3
		stroke.Parent = fr
	end
	return m
end

local screenDefs = {
	{ "CARD MASTER", { "Welcome, Duelist!", "Pick a zone and take a seat.", "Let the cards decide.", "", "Yu-Gi-Oh!  •  Pokémon  •  more" }, C.gold, "♠" },
	{ "HOW TO DUEL", { "1  Choose 1v1, 2v2, 3v3 or 4v4", "2  Sit on a royal chair", "3  Lay your deck on your mat", "4  Draw... and duel!" }, C.cyan, "♦" },
	{ "DUEL ZONES", { "1v1  •  2 chairs per table", "2v2  •  4 chairs per table", "3v3  •  6 chairs per table", "4v4  •  8 chairs per table", "Fire • Ice • Shadow • Gold arenas" }, C.purple, "♣" },
	{ "TOP DUELISTS", { "#1   ----------   0", "#2   ----------   0", "#3   ----------   0", "#4   ----------   0", "#5   ----------   0" }, C.gold, "♥" },
}
for i, d in ipairs(screenDefs) do
	local m = FloatScreen(i, d[1], d[2], d[3], d[4])
	local ang = (i - 1) * math.pi / 2 + math.pi / 4
	local cpos = S(0, 62, 0)
	local pos = cpos + V3(cos(ang) * 27, 0, sin(ang) * 27)
	m:PivotTo(CFrame.lookAt(pos, pos + V3(cos(ang), 0, sin(ang))))
	table.insert(floatScreens, m)
end
end -- statue block


------------------------------------------------------------------
-- 5. THE FOUR DUEL ZONES  (v2: royal card tables, thrones, playmats)
------------------------------------------------------------------
local arenasF = Folder("DuelZones")

do
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
local TOP = Y0 + 3.55 -- table surface height
local mahogany = rgb(52, 28, 44)

-- royal throne chair; cf = floor point, -Z faces the table
local function RoyalChair(m, cf, suit)
	for _, lx in ipairs({ -1, 1 }) do
		for _, lz in ipairs({ -1, 1 }) do
			Cyl(m, "ChairLeg", 0.6, 2.0, cf * CF(lx * 1.05, 1.0, lz * 1.05), mahogany, MAT.Wood)
			Ball(m, "ChairFoot", 0.9, cf * CF(lx * 1.05, 0.2, lz * 1.05), C.gold, MAT.Metal)
		end
	end
	P(m, "ChairFrame", V3(2.9, 0.5, 2.9), cf * CF(0, 2.15, 0), mahogany, MAT.Wood)
	P(m, "ChairGoldTrim", V3(3.05, 0.16, 3.05), cf * CF(0, 2.0, 0), C.gold, MAT.Metal)
	P(m, "ChairCushion", V3(2.5, 0.55, 2.5), cf * CF(0, 2.55, 0), C.red, MAT.Fabric)
	for _, sx in ipairs({ -1, 1 }) do
		P(m, "ChairArm", V3(0.5, 0.4, 2.3), cf * CF(sx * 1.6, 3.9, 0.1), C.gold, MAT.Metal)
		P(m, "ChairArmPost", V3(0.4, 1.3, 0.4), cf * CF(sx * 1.6, 3.2, -0.8), mahogany, MAT.Wood)
		P(m, "ChairBackTrim", V3(0.28, 6.0, 0.8), cf * CF(sx * 1.55, 6.0, 1.25), C.gold, MAT.Metal)
		Ball(m, "ChairFinial", 0.8, cf * CF(sx * 1.55, 9.2, 1.25), C.gold, MAT.Metal)
	end
	P(m, "ChairBack", V3(2.9, 6.0, 0.6), cf * CF(0, 6.0, 1.25), mahogany, MAT.Wood)
	local inlay = P(m, "ChairInlay", V3(2.1, 4.4, 0.2), cf * CF(0, 5.8, 0.88), C.red, MAT.Fabric)
	SurfaceText(inlay, Enum.NormalId.Front, suit, C.gold, Enum.Font.SourceSansBold, 40)
	P(m, "ChairCrest", V3(3.3, 0.6, 0.9), cf * CF(0, 9.1, 1.25), C.gold, MAT.Metal)
	Neon(m, "ChairGem", V3(0.8, 0.8, 0.3), cf * CF(0, 9.9, 1.2) * CFA(0, 0, rad(45)), C.violet)
	local seat = Instance.new("Seat")
	seat.Name = "PlayerSeat"
	seat.Anchored = true
	seat.Size = V3(2.2, 0.3, 2.2)
	seat.CFrame = cf * CF(0, 2.9, 0)
	seat.Transparency = 1
	seat.CanCollide = false
	seat.Parent = m
end

-- one card slot: glowing gold outline + dark inner
local function Slot(m, cf, w, d)
	P(m, "SlotEdge", V3(w + 0.14, 0.03, d + 0.14), cf, C.gold, MAT.Neon, 0.45)
	P(m, "Slot", V3(w, 0.04, d), cf * CF(0, 0.012, 0), rgb(18, 10, 42), MAT.Fabric)
end

-- playmat in front of a seat. +Z = toward the player, -Z = toward the table center
local function PlayMat(m, mcf, big)
	if big then
		P(m, "MatBorder", V3(10.15, 0.06, 5.15), mcf * CF(0, -0.02, 0), C.gold, MAT.Metal)
		P(m, "PlayMat", V3(9.8, 0.08, 4.8), mcf, rgb(40, 22, 88), MAT.Fabric)
		for i = -2, 2 do
			Slot(m, mcf * CF(i * 1.45, 0.06, -1.1), 1.15, 1.6) -- monster zones
			Slot(m, mcf * CF(i * 1.45, 0.06, 1.1), 1.15, 1.6)  -- spell / trap zones
		end
		Slot(m, mcf * CF(-4.2, 0.06, -1.1), 1.1, 1.6)  -- field
		Slot(m, mcf * CF(-4.2, 0.06, 1.1), 1.1, 1.6)   -- graveyard
		Slot(m, mcf * CF(4.2, 0.06, -1.1), 1.1, 1.6)   -- extra deck
		Slot(m, mcf * CF(4.2, 0.06, 1.1), 1.1, 1.6)    -- deck
		P(m, "DeckStack", V3(1.0, 0.4, 1.45), mcf * CF(4.2, 0.28, 1.1), C.violet, MAT.SmoothPlastic)
	else
		P(m, "MatBorder", V3(4.55, 0.06, 3.25), mcf * CF(0, -0.02, 0), C.gold, MAT.Metal)
		P(m, "PlayMat", V3(4.2, 0.08, 2.9), mcf, rgb(40, 22, 88), MAT.Fabric)
		for i = -1, 1 do
			Slot(m, mcf * CF(i * 1.3, 0.06, -0.75), 1.05, 1.2)
			Slot(m, mcf * CF(i * 1.3, 0.06, 0.75), 1.05, 1.2)
		end
		P(m, "DeckStack", V3(0.9, 0.35, 1.1), mcf * CF(1.3, 0.26, 0.75), C.violet, MAT.SmoothPlastic)
	end
end

local function MakeTable(parent, center, chairs, suitIndex)
	local m = Instance.new("Model")
	m.Name = "DuelTable"
	m.Parent = parent
	local suit = SUITS[(suitIndex - 1) % 4 + 1]
	local duel1 = (chairs == 2)
	local per = chairs / 2
	local TL = duel1 and 15 or (per * 4.6 + 1.6) -- length along Z
	local TW = duel1 and 11.2 or 7               -- width along X
	local cx, cz = center.X, center.Z

	-- legs, apron, top
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1, 1 }) do
			local lx, lz = cx + sx * (TW / 2 - 0.9), cz + sz * (TL / 2 - 0.9)
			Cyl(m, "TableFoot", 2.2, 0.5, V3(lx, Y0 + 0.25, lz), C.gold, MAT.Metal)
			Cyl(m, "TableLeg", 1.2, 2.0, V3(lx, Y0 + 1.5, lz), mahogany, MAT.Wood)
			Cyl(m, "TableLegRing", 1.6, 0.25, V3(lx, Y0 + 1.5, lz), C.gold, MAT.Metal)
			Ball(m, "TableCapital", 1.7, V3(lx, Y0 + 2.5, lz), C.gold, MAT.Metal)
		end
	end
	P(m, "TableApron", V3(TW - 0.6, 0.9, TL - 0.6), V3(cx, Y0 + 2.35, cz), C.plumD, MAT.Wood)
	P(m, "TableTop", V3(TW, 0.8, TL), V3(cx, TOP - 0.4, cz), mahogany, MAT.Wood)
	P(m, "TableRimN", V3(TW + 0.4, 0.3, 0.45), V3(cx, TOP - 0.1, cz - TL / 2), C.gold, MAT.Metal)
	P(m, "TableRimS", V3(TW + 0.4, 0.3, 0.45), V3(cx, TOP - 0.1, cz + TL / 2), C.gold, MAT.Metal)
	P(m, "TableRimE", V3(0.45, 0.3, TL), V3(cx + TW / 2, TOP - 0.1, cz), C.gold, MAT.Metal)
	P(m, "TableRimW", V3(0.45, 0.3, TL), V3(cx - TW / 2, TOP - 0.1, cz), C.gold, MAT.Metal)
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1, 1 }) do
			Neon(m, "TableCornerGem", V3(0.8, 0.8, 0.8), V3(cx + sx * TW / 2, TOP + 0.1, cz + sz * TL / 2), C.violet)
		end
	end
	P(m, "TableFelt", V3(TW - 1.0, 0.1, TL - 1.0), V3(cx, TOP + 0.05, cz), rgb(30, 18, 66), MAT.Fabric)

	-- center divider + emblem
	if duel1 then
		Neon(m, "Divider", V3(TW - 1.6, 0.05, 0.22), V3(cx, TOP + 0.12, cz), C.purple)
	else
		Neon(m, "Divider", V3(0.22, 0.05, TL - 1.6), V3(cx, TOP + 0.12, cz), C.purple)
	end
	local pad = P(m, "EmblemPad", V3(2.6, 0.08, 2.6), V3(cx, TOP + 0.16, cz), C.violet, MAT.Neon, 0.35)
	pad.CanCollide = false
	SurfaceText(pad, Enum.NormalId.Top, suit, C.gold, Enum.Font.SourceSansBold, 40)

	-- mats + thrones
	if duel1 then
		for _, sz in ipairs({ -1, 1 }) do
			local mp = V3(cx, TOP + 0.16, cz + sz * 4.4)
			PlayMat(m, CFrame.lookAt(mp, V3(cx, mp.Y, cz)), true)
			local cp = V3(cx, Y0, cz + sz * (TL / 2 + 2.3))
			RoyalChair(m, CFrame.lookAt(cp, V3(cx, Y0, cz)), suit)
		end
	else
		for k = 0, per - 1 do
			local z = cz + (k - (per - 1) / 2) * 4.6
			for _, sx in ipairs({ -1, 1 }) do
				local mp = V3(cx + sx * 1.55, TOP + 0.16, z)
				PlayMat(m, CFrame.lookAt(mp, V3(cx, mp.Y, z)), false)
				local cp = V3(cx + sx * (TW / 2 + 2.5), Y0, z)
				RoyalChair(m, CFrame.lookAt(cp, V3(cx, Y0, z)), suit)
			end
		end
	end

	-- floating suit card marks the table from afar
	local fc = Ghost(P(m, "TableMarker", V3(3.4, 4.8, 0.15), V3(cx, Y0 + 14, cz), C.cream, MAT.SmoothPlastic))
	for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do
		SurfaceText(fc, face, suit, (suit == "♥" or suit == "♦") and rgb(200, 30, 54) or rgb(24, 20, 34), Enum.Font.SourceSansBold, 40)
	end
	Ghost(Neon(m, "TableMarkerGlow", V3(3.9, 5.3, 0.08), V3(cx, Y0 + 14, cz), C.purple, 0.45))
	fc:SetAttribute("Speed", 0.9)
	CollectionService:AddTag(fc, "EB_Spin")
end

-- ===== CASINO MERGE: themed arenas =====
local ZT = {
	Fire   = { key = "Fire",   name = "FIRE DRAGON",         emoji = "🐉", accent = rgb(255, 80, 45),  c1 = rgb(66, 8, 12),  c2 = rgb(225, 90, 25) },
	Ice    = { key = "Ice",    name = "ICE DRAGON",          emoji = "🐲", accent = rgb(120, 205, 255), c1 = rgb(8, 22, 72),  c2 = rgb(170, 230, 255) },
	Shadow = { key = "Shadow", name = "SHADOW BEAST",        emoji = "🦇", accent = rgb(205, 70, 255),  c1 = rgb(30, 8, 54),  c2 = rgb(150, 34, 205) },
	Gold   = { key = "Gold",   name = "GOLDEN LIGHT DRAGON", emoji = "🐉", accent = rgb(255, 208, 96),  c1 = rgb(34, 24, 10), c2 = rgb(255, 232, 150) },
}

-- framed monster-card display. cf = centre, its FRONT (-Z) faces the viewer
local function CardDisplay(parent, cf, w, h, T, legH)
	P(parent, "CardFrame", V3(w + 1.8, h + 1.8, 0.9), cf * CF(0, 0, 0.35), C.gold, MAT.Metal)
	P(parent, "CardFrameInner", V3(w + 0.7, h + 0.7, 0.7), cf * CF(0, 0, 0.2), C.black, MAT.SmoothPlastic)
	local art = P(parent, "CardArt", V3(w, h, 0.3), cf * CF(0, 0, -0.05), T.c1, MAT.SmoothPlastic)
	local sg = Instance.new("SurfaceGui")
	sg.Face = Enum.NormalId.Front
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = 40
	sg.LightInfluence = 0
	sg.Parent = art
	local img = CONFIG.CardImages[T.key]
	if img and img ~= "" then
		local il = Instance.new("ImageLabel")
		il.Size = UDim2.fromScale(1, 1)
		il.BackgroundTransparency = 1
		il.Image = img
		il.Parent = sg
	else
		local bg = Instance.new("Frame")
		bg.Size = UDim2.fromScale(1, 1)
		bg.BorderSizePixel = 0
		bg.BackgroundColor3 = Color3.new(1, 1, 1)
		bg.Parent = sg
		local gr = Instance.new("UIGradient")
		gr.Color = ColorSequence.new(T.c1, T.c2)
		gr.Rotation = 90
		gr.Parent = bg
		local st = Instance.new("UIStroke")
		st.Color = C.gold
		st.Thickness = 6
		st.Parent = bg
		local em = Instance.new("TextLabel")
		em.Size = UDim2.fromScale(0.9, 0.68)
		em.Position = UDim2.fromScale(0.05, 0.05)
		em.BackgroundTransparency = 1
		em.TextScaled = true
		em.Text = T.emoji
		em.Parent = bg
		local tt = Instance.new("TextLabel")
		tt.Size = UDim2.fromScale(0.9, 0.14)
		tt.Position = UDim2.fromScale(0.05, 0.8)
		tt.BackgroundTransparency = 1
		tt.TextScaled = true
		tt.Font = Enum.Font.GothamBlack
		tt.TextColor3 = T.accent
		tt.Text = T.name
		tt.Parent = bg
	end
	Ghost(Neon(parent, "CardGlowTop", V3(w + 0.2, 0.35, 0.4), cf * CF(0, h / 2 + 0.1, -0.25), T.accent))
	Ghost(Neon(parent, "CardGlowBottom", V3(w + 0.2, 0.35, 0.4), cf * CF(0, -h / 2 - 0.1, -0.25), T.accent))
	if legH and legH > 0 then
		for _, s in ipairs({ -1, 1 }) do
			P(parent, "CardLeg", V3(1.4, legH, 1.4), cf * CF(s * (w / 2 + 0.9), -(h / 2 + legH / 2), 0.35), C.plumD, MAT.Slate)
			P(parent, "CardLegCap", V3(1.9, 0.5, 1.9), cf * CF(s * (w / 2 + 0.9), -(h / 2) + 0.1, 0.35), C.gold, MAT.Metal)
		end
	end
end

local function MakeZone(name, cx, cz, chairs, info, signSuit, T)
	local f = Folder(name, arenasF)
	local W, Dp, c = 60, 50, 9
	OctagonFloor(f, "Plinth", cx, cz, W + 5, Dp + 5, c + 2, 0.4, 0.8, C.stoneD, MAT.Slate)
	OctagonFloor(f, "Floor", cx, cz, W, Dp, c, Y0 - 0.45, 0.9, rgb(212, 206, 224), MAT.Marble)
	local vOuter = OctVerts(cx, cz, W - 1.5, Dp - 1.5, c)
	local vInner = OctVerts(cx, cz, W - 4, Dp - 4, c - 1)
	EdgeStrips(f, vOuter, Y0 + 0.03, 0.5, C.gold, MAT.Neon)
	EdgeStrips(f, vInner, Y0 + 0.03, 0.3, T.accent, MAT.Neon)

	-- central medallion (peeks out around the middle table)
	local rings = {
		{ 26, 0.05, C.gold, MAT.Metal }, { 25, 0.07, C.black, MAT.Marble },
		{ 23.6, 0.09, T.accent, MAT.Neon }, { 22.4, 0.11, T.c1, MAT.SmoothPlastic },
	}
	for _, r in ipairs(rings) do
		local d = Cyl(f, "Medallion", r[1], 0.04, V3(cx, Y0 + r[2], cz), r[3], r[4])
		d.CanCollide = false
	end
	for i = 0, 11 do
		local a = i / 12 * math.pi * 2
		Ghost(Neon(f, "MedallionSpoke", V3(0.5, 0.04, 9), CF(cx, Y0 + 0.14, cz) * CFA(0, a, 0) * CF(0, 0, 6.5), (i % 2 == 0) and T.accent or T.c2))
	end

	-- two big monster seals on the free floor at both ends
	for _, sx in ipairs({ -1, 1 }) do
		local sp = V3(cx + sx * 24.2, Y0, cz)
		local sr = {
			{ 7.4, 0.05, C.gold, MAT.Metal }, { 6.9, 0.07, C.black, MAT.Marble },
			{ 6.4, 0.09, T.accent, MAT.Neon }, { 6.0, 0.11, T.c1, MAT.SmoothPlastic },
		}
		for _, r in ipairs(sr) do
			Cyl(f, "SealRing", r[1], 0.04, V3(sp.X, Y0 + r[2], sp.Z), r[3], r[4]).CanCollide = false
		end
		local art = Ghost(P(f, "SealArt", V3(4.6, 0.05, 4.6), V3(sp.X, Y0 + 0.15, sp.Z), T.c1, MAT.SmoothPlastic))
		local fimg = CONFIG.FloorImages[T.key]
		if fimg and fimg ~= "" then
			art.Size = V3(6, 0.05, 6)
			local d = Instance.new("Decal")
			d.Face = Enum.NormalId.Top
			d.Texture = fimg
			d.Parent = art
		else
			SurfaceText(art, Enum.NormalId.Top, T.emoji, T.accent, Enum.Font.SourceSansBold, 50)
		end
	end
	if CONFIG.LAMP_LIGHTS then
		local zl = Ghost(P(f, "ZoneLight", V3(1, 1, 1), V3(cx, 14, cz), C.black, MAT.SmoothPlastic, 1))
		Light(zl, T.accent, 60, 1.1)
	end

	-- ===== red spectator grandstand on the outer edge, facing the duel floor =====
	local outZ = (cz < 0) and -1 or 1
	local sgnX = (cx < 0) and -1 or 1
	local x0, x1 = 34, 80
	local xc, xl = sgnX * (x0 + x1) / 2, x1 - x0
	local zEdge = cz + outZ * (Dp / 2 + 2.5)
	local zTier3 = zEdge + outZ * (1.5 + 2 * 3)
	for k = 1, 3 do
		local top = Y0 + 0.9 * k
		local zc = zEdge + outZ * (1.5 + (k - 1) * 3)
		P(f, "StandTier", V3(xl, top, 3), V3(xc, top / 2, zc), C.stoneD, MAT.Slate)
		P(f, "StandCushion", V3(xl - 1, 0.5, 1.7), V3(xc, top + 0.25, zc - outZ * 0.35), C.red, MAT.Fabric)
		P(f, "StandBack", V3(xl - 1, 1.1, 0.4), V3(xc, top + 0.8, zc + outZ * 1.2), rgb(104, 14, 34), MAT.Fabric)
		Ghost(Neon(f, "StandGlow", V3(xl, 0.14, 0.25), V3(xc, top + 0.07, zc - outZ * 1.45), T.accent))
		P(f, "StandGold", V3(xl, 0.2, 0.3), V3(xc, top + 0.1, zc - outZ * 1.6), C.gold, MAT.Metal)
	end

	-- big framed monster card at the outer end + two portrait cards on the grandstand
	local px = cx + sgnX * 35
	CardDisplay(f, CFrame.lookAt(V3(px, 11, cz), V3(px - sgnX, 11, cz)), 16, 10, T, 6)
	for _, mx in ipairs({ sgnX * 46, sgnX * 68 }) do
		CardDisplay(f, CFrame.lookAt(V3(mx, Y0 + 2.7 + 3 + 3.5, zTier3), V3(mx, Y0 + 2.7 + 3 + 3.5, zTier3 - outZ)), 5, 7, T, 3)
	end
	-- red suit banners at both ends of the grandstand
	for _, bx in ipairs({ sgnX * 35.5, sgnX * 78.5 }) do
		P(f, "BannerPole", V3(0.6, 20, 0.6), V3(bx, 10, zTier3 + outZ * 0.9), C.gold, MAT.Metal)
		Banner(f, CFrame.lookAt(V3(bx, 14, zTier3), V3(bx, 14, zTier3 - outZ)), 4, 9, SUITS[signSuit], C.red)
	end
	-- 5 tables: 2 top, 1 center, 2 bottom
	local offs = { V3(-15, 0, -12), V3(15, 0, -12), V3(0, 0, 0), V3(-15, 0, 12), V3(15, 0, 12) }
	for i, o in ipairs(offs) do
		MakeTable(f, V3(cx + o.X, 0, cz + o.Z), chairs, signSuit + i - 1)
	end
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1, 1 }) do
			local mx, mz = cx + sx * (W / 2 - c / 2 + 3.2), cz + sz * (Dp / 2 - c / 2 + 3.2)
			Planter(f, CF(mx, 0, mz) * CFA(0, rad(sx * sz * 45), 0), 11, 2.6)
			Lantern(f, cx + sx * (W / 2 + 2.2), cz + sz * (Dp / 2 - c - 1), 7)
		end
	end
	local dirToPath = (cx > 0) and -1 or 1
	P(f, "Walkway", V3(16.4, 0.4, 8), V3(cx + dirToPath * (W / 2 + 8.2), 0.2, cz), C.path, MAT.Marble)
	P(f, "WalkStep", V3(2, 0.5, 8), V3(cx + dirToPath * (W / 2 + 1.5), 0.25, cz), C.stoneD, MAT.Slate)
	P(f, "WalkCarpet", V3(13.6, 0.12, 4.4), V3(cx + dirToPath * (W / 2 + 9.6), 0.46, cz), C.red, MAT.Fabric)
	Neon(f, "WalkGlow", V3(16, 0.1, 0.3), V3(cx + dirToPath * (W / 2 + 8.2), 0.42, cz + 3.8), C.purple)
	Neon(f, "WalkGlow", V3(16, 0.1, 0.3), V3(cx + dirToPath * (W / 2 + 8.2), 0.42, cz - 3.8), C.purple)
	-- royal entrance arch
	local ax = cx + dirToPath * (W / 2 + 5)
	for _, sz in ipairs({ -1, 1 }) do
		Cyl(f, "ArchPillar", 2.8, 16, V3(ax, 8, cz + sz * 6.4), C.plum, MAT.Slate)
		Cyl(f, "ArchPillarGold", 3.4, 0.7, V3(ax, 1, cz + sz * 6.4), C.gold, MAT.Metal)
		Cyl(f, "ArchPillarGold", 3.4, 0.7, V3(ax, 15, cz + sz * 6.4), C.gold, MAT.Metal)
		Ball(f, "ArchFinial", 2.4, V3(ax, 17.2, cz + sz * 6.4), C.gold, MAT.Neon)
	end
	P(f, "ArchBeam", V3(2.4, 2, 14.4), V3(ax, 16.2, cz), C.plumD, MAT.Slate)
	P(f, "ArchBeamGold", V3(2.8, 0.5, 14.8), V3(ax, 17.4, cz), C.gold, MAT.Metal)
	Neon(f, "ArchGem", V3(0.6, 2.2, 2.2), CF(ax, 16.2, cz) * CFA(rad(45), 0, 0), C.violet)
	Pill(f, V3(cx, 24, cz), 310, 100, info.title, T.name .. "  •  " .. info.sub, T.accent)
end

MakeZone("Zone_2v2", -54, -20, 4, { title = "2v2", sub = "4 CHAIRS / TABLE" }, 1, ZT.Fire)
MakeZone("Zone_3v3", 54, -20, 6, { title = "3v3", sub = "6 CHAIRS / TABLE" }, 2, ZT.Ice)
MakeZone("Zone_1v1", -54, 52, 2, { title = "1v1", sub = "2 CHAIRS / TABLE" }, 3, ZT.Shadow)
MakeZone("Zone_4v4", 54, 52, 8, { title = "4v4", sub = "8 CHAIRS / TABLE" }, 4, ZT.Gold)
end -- zones block


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
local FALL_H = 210
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
	local sheet = Ghost(P(waterF, "FallSheet", alongX and V3(w, FALL_H, 1) or V3(1, FALL_H, w), V3(x + dx * 0.5, -FALL_H / 2, z + dz * 0.5), C.water, MAT.Glass, 0.3))
	local core = Ghost(Neon(waterF, "FallCore", alongX and V3(w - 2, FALL_H, 0.4) or V3(0.4, FALL_H, w - 2), V3(x + dx * 0.9, -FALL_H / 2, z + dz * 0.9), C.cyan, 0.78))
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
	local mistPos = V3(x + dx * 3, -FALL_H + 4, z + dz * 3)
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
	{ -95, -34 }, { -97, -12 }, { -98, 24 }, { -90, 78 }, { -72, 100 }, { -86, -86 },
	{ 95, -34 }, { 97, -12 }, { 98, 24 }, { 90, 78 }, { 72, 100 }, { 86, -86 },
	{ -22, 84 }, { 22, 84 }, { -92, 100 }, { 92, 100 },
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
-- 13. EXTRAS (v2): echo core, floating rocks, clouds, royal arch, guardians
------------------------------------------------------------------
do
-- glowing Echo Core crystal hanging under the island
local coreF = Folder("EchoCore")
local cy = -112
for dir = -1, 1, 2 do
	for i = 0, 3 do
		local c = Cyl(coreF, "CoreCrystal", 15 * (1 - i / 4) + 1.5, 7, V3(0, cy + dir * (3.5 + i * 7), 0), C.violet, MAT.Neon)
		c.Transparency = 0.12
		c.CanCollide = false
	end
end
local coreLight = Ghost(P(coreF, "CoreLight", V3(1, 1, 1), V3(0, cy, 0), C.black, MAT.SmoothPlastic, 1))
if CONFIG.LAMP_LIGHTS then Light(coreLight, C.purple, 150, 3) end
RingSegs(coreF, V3(0, cy, 0), 24, 40, 0.8, C.cyan)
RingSegs(coreF, V3(0, cy, 0), 30, 48, 0.6, C.gold)
MakeRing(rings, V3(0, cy, 0), 27, 44, C.cyan, rad(60), rad(10), 0.3, 0.6)
MakeRing(rings, V3(0, cy, 0), 33, 52, C.purple, rad(-55), rad(-20), -0.25, 0.5)

-- small rocks drifting around the island
local fr = Folder("FloatingRocks")
for i = 1, 14 do
	local a = (i / 14) * math.pi * 2 + rng:NextNumber(-0.2, 0.2)
	local dist = rng:NextNumber(135, 190)
	local cx, cz = cos(a) * dist, sin(a) * dist
	if not (math.abs(cz + 5) < 30 and math.abs(math.abs(cx) - 142) < 35) then
		local y = rng:NextNumber(-40, 45)
		local s = rng:NextNumber(0.7, 1.5)
		local m = Instance.new("Model")
		m.Name = "FloatingRock"
		m.Parent = fr
		Rock(m, V3(cx, y, cz), 14 * s)
		Rock(m, V3(cx + 2, y - 9 * s, cz - 1), 10 * s)
		Rock(m, V3(cx - 1, y - 16 * s, cz + 1), 6 * s)
		Crystal(m, V3(cx, y + 8 * s, cz), 1.6 * s, (i % 2 == 0) and C.cyan or C.purple)
		m:SetAttribute("Phase", rng:NextNumber(0, 6.28))
		CollectionService:AddTag(m, "EB_Island")
	end
end

-- cloud banks between the island and the ocean
local cl = Folder("Clouds")
for i = 1, 40 do
	local a = rng:NextNumber(0, math.pi * 2)
	local dist = rng:NextNumber(150, 520)
	local y = rng:NextNumber(-150, -45)
	for k = 1, 5 do
		local b = Ball(cl, "Cloud", rng:NextNumber(26, 56),
			V3(cos(a) * dist + rng:NextNumber(-34, 34), y + rng:NextNumber(-6, 6), sin(a) * dist + rng:NextNumber(-34, 34)),
			rgb(236, 226, 255), MAT.SmoothPlastic)
		b.Transparency = 0.25
		b.CanCollide = false
		b.CastShadow = false
	end
end

-- royal arch over the main road
for _, sx in ipairs({ -1, 1 }) do
	Cyl(deco, "ArchPillar", 3, 18, V3(sx * 11.5, 9, 55), C.plum, MAT.Slate)
	Cyl(deco, "ArchPillarGold", 3.6, 0.7, V3(sx * 11.5, 1, 55), C.gold, MAT.Metal)
	Cyl(deco, "ArchPillarGold", 3.6, 0.7, V3(sx * 11.5, 17, 55), C.gold, MAT.Metal)
	Ball(deco, "ArchFinial", 2.6, V3(sx * 11.5, 19.4, 55), C.gold, MAT.Neon)
end
P(deco, "ArchBeam", V3(26, 2.2, 3), V3(0, 18.5, 55), C.plumD, MAT.Slate)
P(deco, "ArchBeamGold", V3(26.6, 0.5, 3.4), V3(0, 19.8, 55), C.gold, MAT.Metal)
Neon(deco, "ArchGem", V3(2.4, 2.4, 0.4), CF(0, 18.5, 56.8) * CFA(0, 0, rad(45)), C.violet)
Pill(deco, V3(0, 25, 55), 240, 56, "ROYAL CARD ROAD", nil)

-- two armored guardians flanking the castle stairs (face south)
local function Knight(x, z, suit)
	local function K(dx, dy, dz) return V3(x + dx, dy, z + dz) end
	Cyl(deco, "KnightPedestal", 9, 2, K(0, 1, 0), C.stoneD, MAT.Slate)
	Cyl(deco, "KnightPedestalGold", 9.6, 0.4, K(0, 2.1, 0), C.gold, MAT.Metal)
	for _, sx in ipairs({ -1, 1 }) do
		P(deco, "KnightBoot", V3(2, 1.6, 3.2), CF(K(sx * 1.4, 2.8, 0.4)), C.black, MAT.Metal)
		Limb(deco, "KnightLeg", K(sx * 1.4, 3.4, 0), K(sx * 1.4, 9.4, 0), 2.2, C.silver, MAT.Metal)
		Ball(deco, "KnightPauldron", 3.4, K(sx * 3.4, 17.2, 0), C.gold, MAT.Metal)
		Limb(deco, "KnightArm", K(sx * 3.4, 17, 0), K(sx * 0.7, 14.6, 3.2), 1.7, C.silver, MAT.Metal)
		Ball(deco, "KnightFist", 1.7, K(sx * 0.7, 14.6, 3.2), C.gold, MAT.Metal)
	end
	P(deco, "KnightHips", V3(4.8, 1.6, 3), CF(K(0, 9.8, 0)), C.plumD, MAT.Fabric)
	local torso = P(deco, "KnightTorso", V3(6, 7, 3.6), CF(K(0, 14, 0)), C.silver, MAT.Metal)
	SurfaceText(torso, Enum.NormalId.Back, suit, C.purpleD, Enum.Font.SourceSansBold, 40)
	P(deco, "KnightBelt", V3(6.2, 0.7, 3.8), CF(K(0, 10.9, 0)), C.gold, MAT.Metal)
	Cyl(deco, "KnightNeck", 1.6, 1, K(0, 17.8, 0), C.silver, MAT.Metal)
	Ball(deco, "KnightHelmet", 3.8, K(0, 19.4, 0), C.silver, MAT.Metal)
	Neon(deco, "KnightVisor", V3(2.4, 0.35, 0.3), CF(K(0, 19.4, 1.8)), C.cyan)
	Spike(deco, K(0, 21, 0), K(0, 24, -2.5), 1.4, C.red, MAT.Fabric, C.violet)
	-- greatsword planted in front, both hands on the pommel
	P(deco, "KnightBlade", V3(0.8, 13, 0.3), CF(K(0, 8.2, 3.6)), C.white, MAT.Metal)
	P(deco, "KnightGuard", V3(4.2, 0.6, 0.7), CF(K(0, 15, 3.6)), C.gold, MAT.Metal)
	Ball(deco, "KnightPommel", 1.0, K(0, 16.2, 3.6), C.gold, MAT.Metal)
	-- cape
	P(deco, "KnightCape", V3(6.4, 12, 0.5), CF(K(0, 12.5, -2.3)) * CFA(rad(-6), 0, 0), C.purpleD, MAT.Fabric)
end
Knight(-27, -52, "♠")
Knight(27, -52, "♥")
end -- extras block


------------------------------------------------------------------
-- FINISH: scale everything, build the ocean, start the screens
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

------------------------------------------------------------------
-- OCEAN far below the island (built in world units, after scaling)
------------------------------------------------------------------
local OCEAN_Y = -210 * CONFIG.SCALE
local oceanF = Folder("Ocean")
do
	local terrain = Workspace.Terrain
	terrain.WaterColor = rgb(34, 110, 180)
	terrain.WaterTransparency = 0.6
	terrain.WaterReflectance = 0.8
	terrain.WaterWaveSize = 0.45
	terrain.WaterWaveSpeed = 14
	terrain:FillBlock(CF(0, OCEAN_Y - 8, 0), V3(1600, 16, 1600), Enum.Material.Water)

	-- endless sea to the horizon
	for i = -2, 2 do
		for j = -2, 2 do
			local sea = P(oceanF, "Sea", V3(2048, 6, 2048), V3(i * 2048, OCEAN_Y - 3.2, j * 2048), rgb(26, 78, 140), MAT.SmoothPlastic)
			sea.Reflectance = 0.15
			sea.CastShadow = false
		end
	end

	-- falling into the ocean sends you back to spawn
	local ret = Ghost(P(oceanF, "OceanReturn", V3(2048, 6, 2048), V3(0, OCEAN_Y + 3, 0), C.black, MAT.SmoothPlastic, 1))
	ret.CanTouch = true
	ret.Touched:Connect(function(hit)
		local hum = hit.Parent and hit.Parent:FindFirstChildOfClass("Humanoid")
		if hum and hum.Health > 0 then hum.Health = 0 end
	end)

	-- sea stacks with grass caps and foam
	for i = 1, 18 do
		local a = rng:NextNumber(0, math.pi * 2)
		local dist = rng:NextNumber(260, 900)
		local x, z = cos(a) * dist, sin(a) * dist
		local d = rng:NextNumber(30, 70)
		local h = rng:NextNumber(50, 150)
		Cyl(oceanF, "SeaStack", d, h, V3(x, OCEAN_Y + h / 2 - 14, z), C.rock, MAT.Rock)
		Cyl(oceanF, "SeaStackUpper", d * 0.7, h * 0.5, V3(x, OCEAN_Y + h - 14 + h * 0.25, z), C.rockL, MAT.Rock)
		Cyl(oceanF, "SeaStackGrass", d * 0.62, 3, V3(x, OCEAN_Y + h * 1.5 - 14 + 1.5, z), C.grass, MAT.Grass)
		local foam = Cyl(oceanF, "Foam", d + 16, 0.5, V3(x, OCEAN_Y + 0.4, z), C.white, MAT.SmoothPlastic)
		foam.Transparency = 0.5
		foam.CanCollide = false
	end

	-- cyan glow on the water under the island
	local glow = Cyl(oceanF, "EchoReflection", 420, 0.3, V3(0, OCEAN_Y + 0.7, 0), C.cyan, MAT.Neon)
	glow.Transparency = 0.9
	glow.CanCollide = false
end

------------------------------------------------------------------
-- FLOATING SCREENS: orbit slowly around the Card Master
------------------------------------------------------------------
if screenCenter then
	local RunService = game:GetService("RunService")
	local cpos = screenCenter.Position
	local data = {}
	for _, m in ipairs(floatScreens) do
		local off = m:GetPivot().Position - cpos
		table.insert(data, {
			model = m,
			ang = math.atan2(off.Z, off.X),
			r = V3(off.X, 0, off.Z).Magnitude,
			dy = off.Y,
			ph = rng:NextNumber(0, 6.28),
		})
	end
	local t, acc = 0, 0
	RunService.Heartbeat:Connect(function(dt)
		t = t + dt
		acc = acc + dt
		if acc < 1 / 20 then return end
		acc = 0
		for _, s in ipairs(data) do
			local ang = s.ang + t * 0.12
			local pos = V3(cpos.X + cos(ang) * s.r, cpos.Y + s.dy + sin(t * 0.9 + s.ph) * 1.2 * CONFIG.SCALE, cpos.Z + sin(ang) * s.r)
			s.model:PivotTo(CFrame.lookAt(pos, pos + V3(cos(ang), 0, sin(ang))))
		end
	end)
end

------------------------------------------------------------------
-- PERSONA MONSTERS: weld each into ONE moving piece, then orbit + bob them
------------------------------------------------------------------
if #monsters > 0 then
	local RunService = game:GetService("RunService")
	local mdata = {}
	for _, md in ipairs(monsters) do
		local m = md.model
		local root = m.PrimaryPart
		for _, d in ipairs(m:GetDescendants()) do
			if d:IsA("BasePart") and d ~= root then
				d.Anchored = false
				d.Massless = true
				local w = Instance.new("WeldConstraint")
				w.Part0 = root
				w.Part1 = d
				w.Parent = d
			end
		end
		local c = md.anchor.Position
		local off = m:GetPivot().Position - c
		table.insert(mdata, {
			model = m, c = c, sp = md.speed, ph = md.ph,
			ang = math.atan2(off.Z, off.X),
			r = V3(off.X, 0, off.Z).Magnitude,
			dy = off.Y,
		})
	end
	local mt, macc = 0, 0
	RunService.Heartbeat:Connect(function(dt)
		mt = mt + dt
		macc = macc + dt
		if macc < 1 / 30 then return end
		macc = 0
		for _, s in ipairs(mdata) do
			local ang = s.ang + mt * s.sp
			local pos = V3(s.c.X + cos(ang) * s.r, s.c.Y + s.dy + sin(mt * 0.9 + s.ph) * 1.2 * CONFIG.SCALE, s.c.Z + sin(ang) * s.r)
			s.model:PivotTo(CFrame.lookAt(pos, pos + V3(cos(ang), 0, sin(ang))))
		end
	end)
end

map:SetAttribute("Built", true)
print("Echobound card island built ✔ (scale x" .. CONFIG.SCALE .. ")")
