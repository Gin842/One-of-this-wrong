--[[
	FLOATING CARD CASINO KINGDOM  -  procedural Roblox map generator
	-----------------------------------------------------------------
	HOW TO USE
	  1. Roblox Studio -> ServerScriptService -> Insert a normal "Script".
	  2. Paste this whole file in. Press Play (or Run). The map builds in ~10-20 s.
	  3. Optional: delete the default Baseplate. Spawn is at the front entrance.
	  4. Replace procedural art with your own images: paste asset ids into CFG.CardImages / CFG.FloorImages
	     (format "rbxassetid://123456789").

	LAYOUT (top view, camera looks toward -Z, castle is at the rear)

	                [ CASTLE + BOOK ]
	      Arena1 (Fire)            Arena2 (Ice)
	                 [ CARD MASTER STATUE ]
	      Arena3 (Shadow)          Arena4 (Gold)
	                [ FRONT ENTRANCE / SPAWN ]
]]

local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")

-- ============================================================ CONFIG
local CFG = {
	BaseY = 260,          -- height of the island above the world origin
	Seed = 2026,
	ArenaX = 72,          -- arena centre offsets from the statue
	ArenaZ = 62,
	CardImages  = { Fire = "", Ice = "", Shadow = "", Gold = "" },
	FloorImages = { Fire = "", Ice = "", Shadow = "", Gold = "" },
}

local C3 = Color3.fromRGB
local V3 = Vector3.new
local MAT = Enum.Material
local TAU = math.pi * 2

local PAL = {
	STONE = C3(48, 48, 58), STONE2 = C3(34, 34, 42), STONE3 = C3(66, 64, 76), BLACK = C3(16, 16, 20),
	MARBLE = C3(24, 24, 30), TILE = C3(150, 150, 162), TILE2 = C3(122, 122, 136),
	RED = C3(150, 18, 34), DRED = C3(92, 10, 24), GOLD = C3(226, 174, 54), AMBER = C3(255, 178, 72),
	IVORY = C3(245, 236, 210), WATER = C3(120, 205, 255), GREEN = C3(46, 108, 52),
	BURG = C3(128, 24, 46), WOOD = C3(92, 62, 40), CLOUD = C3(250, 250, 255),
}
local ROCKS = { C3(40, 40, 48), C3(54, 54, 64), C3(30, 30, 38), C3(66, 64, 74), C3(22, 22, 28) }

local THEMES = {
	Fire   = { key = "Fire",   name = "FIRE DRAGON",         emoji = "🐉", accent = C3(255, 70, 40),  c1 = C3(70, 6, 10),  c2 = C3(225, 85, 20) },
	Ice    = { key = "Ice",    name = "ICE DRAGON",          emoji = "🐲", accent = C3(110, 200, 255), c1 = C3(8, 22, 72),  c2 = C3(165, 228, 255) },
	Shadow = { key = "Shadow", name = "SHADOW BEAST",        emoji = "🦇", accent = C3(200, 60, 255),  c1 = C3(28, 6, 52),  c2 = C3(150, 30, 205) },
	Gold   = { key = "Gold",   name = "GOLDEN LIGHT DRAGON", emoji = "🐉", accent = C3(255, 205, 90),  c1 = C3(30, 22, 10), c2 = C3(255, 232, 150) },
}

local rng = Random.new(CFG.Seed)

-- ============================================================ SCENE ROOTS
local old = Workspace:FindFirstChild("FloatingCardCasinoKingdom")
if old then old:Destroy() end
local ROOT = Instance.new("Model")
ROOT.Name = "FloatingCardCasinoKingdom"
ROOT.Parent = Workspace

local F = {}
for _, n in ipairs({ "Island", "Castle", "Statue", "Plaza", "Bridges", "Arenas", "Decor", "Water", "Sky" }) do
	local f = Instance.new("Folder")
	f.Name = n
	f.Parent = ROOT
	F[n] = f
end

-- ============================================================ BASIC HELPERS
local partCount = 0
local function W(x, y, z) return V3(x, CFG.BaseY + y, z) end

local function mk(parent, name, size, cf, color, mat, extra, class)
	local p = Instance.new(class or "Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = mat or MAT.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if extra then
		for k, v in pairs(extra) do p[k] = v end
	end
	p.Parent = parent
	partCount = partCount + 1
	if partCount % 250 == 0 then task.wait() end
	return p
end

-- vertical cylinder: diameter, height, centre position (Vector3)
local function cyl(parent, name, diam, h, pos, color, mat, extra)
	local p = mk(parent, name, V3(h, diam, diam), CFrame.new(pos) * CFrame.Angles(0, 0, math.pi / 2), color, mat, extra)
	p.Shape = Enum.PartType.Cylinder
	return p
end

local function ball(parent, name, diam, pos, color, mat, extra)
	local p = mk(parent, name, V3(diam, diam, diam), CFrame.new(pos), color, mat, extra)
	p.Shape = Enum.PartType.Ball
	return p
end

-- block between two points
local function limb(parent, name, a, b, t, color, mat)
	local len = (b - a).Magnitude
	return mk(parent, name, V3(t, t, len), CFrame.lookAt((a + b) / 2, b), color, mat)
end

local function ang(dx, dz) return math.atan2(dz, dx) end
local function angDiff(a, b)
	local d = (a - b + math.pi) % TAU - math.pi
	return math.abs(d)
end
local function blocked(a, gaps)
	for _, g in ipairs(gaps) do
		if angDiff(a, g[1]) < g[2] then return true end
	end
	return false
end

local function label(part, face, text, color, font)
	local sg = Instance.new("SurfaceGui")
	sg.Face = face
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = 24
	sg.LightInfluence = 0
	sg.Brightness = 1.4
	sg.Parent = part
	local t = Instance.new("TextLabel")
	t.Size = UDim2.new(1, 0, 1, 0)
	t.BackgroundTransparency = 1
	t.TextScaled = true
	t.Text = text
	t.TextColor3 = color or PAL.GOLD
	t.Font = font or Enum.Font.GothamBlack
	t.Parent = sg
	return sg
end

local function addLight(part, color, range, bright)
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range
	l.Brightness = bright
	l.Shadows = false
	l.Parent = part
	return l
end

-- ============================================================ PROPS
local function lamp(parent, pos, h)
	h = h or 6
	mk(parent, "LampBase", V3(1.6, 0.8, 1.6), CFrame.new(pos + V3(0, 0.4, 0)), PAL.BLACK, MAT.Metal, { CanCollide = false })
	cyl(parent, "LampPole", 0.6, h, pos + V3(0, h / 2, 0), PAL.BLACK, MAT.Metal, { CanCollide = false })
	local lan = mk(parent, "LampGlass", V3(1.5, 1.8, 1.5), CFrame.new(pos + V3(0, h + 0.9, 0)), PAL.AMBER, MAT.Neon, { Transparency = 0.12, CanCollide = false })
	addLight(lan, PAL.AMBER, 13, 0.9)
	mk(parent, "LampCap", V3(2.1, 0.4, 2.1), CFrame.new(pos + V3(0, h + 1.9, 0)), PAL.GOLD, MAT.Metal, { CanCollide = false })
	ball(parent, "LampFinial", 0.7, pos + V3(0, h + 2.4, 0), PAL.GOLD, MAT.Metal, { CanCollide = false })
end

-- pole banner facing dir (horizontal unit vector); pos = ground position
local function banner(parent, pos, dir, symbol, w, h, cloth)
	w = w or 4
	h = h or 10
	cloth = cloth or PAL.RED
	local cf = CFrame.lookAt(pos, pos + dir)
	cyl(parent, "BannerPole", 0.5, h + 4, pos + V3(0, (h + 4) / 2, 0), PAL.BLACK, MAT.Metal, { CanCollide = false })
	mk(parent, "BannerBar", V3(w + 1.4, 0.4, 0.4), cf * CFrame.new(0, h + 3.4, 0), PAL.GOLD, MAT.Metal, { CanCollide = false })
	mk(parent, "BannerTrim", V3(w + 0.6, h + 0.6, 0.2), cf * CFrame.new(0, 3 + h / 2, -0.15), PAL.GOLD, MAT.Metal, { CanCollide = false })
	local c = mk(parent, "BannerCloth", V3(w, h, 0.3), cf * CFrame.new(0, 3 + h / 2, -0.4), cloth, MAT.Fabric, { CanCollide = false })
	label(c, Enum.NormalId.Front, symbol, PAL.GOLD)
	label(c, Enum.NormalId.Back, symbol, PAL.GOLD)
	return c
end

-- flat wall panel facing +Z (castle fronts). cf = centre
local function wallPanel(parent, cf, w, h, symbol, cloth, face)
	mk(parent, "PanelTrim", V3(w + 1, h + 1, 0.5), cf * CFrame.new(0, 0, 0.05), PAL.GOLD, MAT.Metal, { CanCollide = false })
	local p = mk(parent, "Panel", V3(w, h, 0.6), cf * CFrame.new(0, 0, 0), cloth, MAT.Fabric, { CanCollide = false })
	label(p, face or Enum.NormalId.Back, symbol, PAL.GOLD)
	return p
end

-- big framed monster-card display. cf: centre, local -Z faces the viewer.
local function cardDisplay(parent, cf, w, h, T, legH)
	mk(parent, "CardFrame", V3(w + 1.8, h + 1.8, 0.9), cf * CFrame.new(0, 0, 0.35), PAL.GOLD, MAT.Metal)
	mk(parent, "CardFrameInner", V3(w + 0.7, h + 0.7, 0.7), cf * CFrame.new(0, 0, 0.2), PAL.BLACK, MAT.SmoothPlastic)
	local art = mk(parent, "CardArt", V3(w, h, 0.3), cf * CFrame.new(0, 0, -0.05), T.c1, MAT.SmoothPlastic)
	local sg = Instance.new("SurfaceGui")
	sg.Face = Enum.NormalId.Front
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = 30
	sg.LightInfluence = 0
	sg.Brightness = 1.6
	sg.Parent = art
	local img = CFG.CardImages[T.key]
	if img and img ~= "" then
		local il = Instance.new("ImageLabel")
		il.Size = UDim2.new(1, 0, 1, 0)
		il.BackgroundTransparency = 1
		il.Image = img
		il.Parent = sg
	else
		local bg = Instance.new("Frame")
		bg.Size = UDim2.new(1, 0, 1, 0)
		bg.BorderSizePixel = 0
		bg.BackgroundColor3 = Color3.new(1, 1, 1)
		bg.Parent = sg
		local gr = Instance.new("UIGradient")
		gr.Color = ColorSequence.new(T.c1, T.c2)
		gr.Rotation = 90
		gr.Parent = bg
		local st = Instance.new("UIStroke")
		st.Color = PAL.GOLD
		st.Thickness = 8
		st.Parent = bg
		local em = Instance.new("TextLabel")
		em.Size = UDim2.new(0.9, 0, 0.68, 0)
		em.Position = UDim2.new(0.05, 0, 0.05, 0)
		em.BackgroundTransparency = 1
		em.TextScaled = true
		em.Text = T.emoji
		em.Parent = bg
		local tt = Instance.new("TextLabel")
		tt.Size = UDim2.new(0.9, 0, 0.16, 0)
		tt.Position = UDim2.new(0.05, 0, 0.79, 0)
		tt.BackgroundTransparency = 1
		tt.TextScaled = true
		tt.Font = Enum.Font.GothamBlack
		tt.TextColor3 = T.accent
		tt.Text = T.name
		tt.Parent = bg
	end
	mk(parent, "CardGlow", V3(w + 0.2, 0.35, 0.4), cf * CFrame.new(0, h / 2 + 0.1, -0.25), T.accent, MAT.Neon, { CanCollide = false })
	if legH and legH > 0 then
		for _, s in ipairs({ -1, 1 }) do
			mk(parent, "CardLeg", V3(1.4, legH, 1.4), cf * CFrame.new(s * (w / 2 + 0.9), -(h / 2 + legH / 2), 0.35), PAL.STONE2, MAT.Slate)
			mk(parent, "CardLegCap", V3(1.9, 0.5, 1.9), cf * CFrame.new(s * (w / 2 + 0.9), -(h / 2) + 0.1, 0.35), PAL.GOLD, MAT.Metal)
		end
	end
end

-- enchanted open book. centre: world Vector3, faces +Z. s = scale
local function book(parent, centre, s, glowRange)
	local cf = CFrame.new(centre)
	local th = math.rad(18)
	local spine = mk(parent, "BookSpine", V3(0.6 * s, 8.8 * s, 0.7 * s), cf, PAL.AMBER, MAT.Neon, { CanCollide = false })
	addLight(spine, PAL.AMBER, glowRange or 45, 2.2)
	local em = Instance.new("ParticleEmitter")
	em.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	em.Rate = 10
	em.Lifetime = NumberRange.new(2, 3.5)
	em.Speed = NumberRange.new(1, 3)
	em.Size = NumberSequence.new(0.5 * s, 0)
	em.LightEmission = 1
	em.Color = ColorSequence.new(PAL.AMBER)
	em.SpreadAngle = Vector2.new(60, 60)
	em.Parent = spine
	for _, sgn in ipairs({ -1, 1 }) do
		local rot = cf * CFrame.Angles(0, -sgn * th, 0)
		mk(parent, "BookCover", V3(6.5 * s, 8.8 * s, 0.3 * s), rot * CFrame.new(sgn * 3.25 * s, 0, -0.5 * s), PAL.DRED, MAT.Fabric, { CanCollide = false })
		mk(parent, "BookBorder", V3(6.3 * s, 8.5 * s, 0.2 * s), rot * CFrame.new(sgn * 3.15 * s, 0, -0.28 * s), PAL.GOLD, MAT.Metal, { CanCollide = false })
		local pg = mk(parent, "BookPage", V3(5.7 * s, 7.9 * s, 0.3 * s), rot * CFrame.new(sgn * 3.15 * s, 0, -0.1 * s), PAL.IVORY, MAT.SmoothPlastic, { CanCollide = false })
		label(pg, Enum.NormalId.Back, sgn < 0 and "♠\n♦ ♣\n♥" or "♣\n♥ ♠\n♦", C3(150, 90, 20), Enum.Font.GothamBlack)
		local g = mk(parent, "PageGlow", V3(5.2 * s, 0.25 * s, 0.4 * s), rot * CFrame.new(sgn * 3.1 * s, 4.1 * s, 0.1 * s), PAL.AMBER, MAT.Neon, { CanCollide = false, Transparency = 0.3 })
	end
end

local function tree(parent, pos, sc, red)
	sc = sc or 1
	cyl(parent, "TrunkLow", 0.9 * sc, 3 * sc, pos + V3(0, 1.5 * sc, 0), PAL.WOOD, MAT.Wood, { CanCollide = false })
	if red then
		ball(parent, "Foliage", 5.2 * sc, pos + V3(0, 4.6 * sc, 0), PAL.BURG, MAT.Grass, { CanCollide = false })
		ball(parent, "Foliage", 3.4 * sc, pos + V3(1.1 * sc, 6.2 * sc, 0.4 * sc), C3(160, 32, 58), MAT.Grass, { CanCollide = false })
	else
		for i = 0, 2 do
			cyl(parent, "Pine", (5 - i * 1.5) * sc, 2.2 * sc, pos + V3(0, (3 + i * 1.7) * sc, 0), PAL.GREEN, MAT.Grass, { CanCollide = false })
		end
	end
end

local function planter(parent, pos, red)
	mk(parent, "Planter", V3(3.4, 1.4, 3.4), CFrame.new(pos + V3(0, 0.7, 0)), PAL.STONE2, MAT.Slate)
	mk(parent, "PlanterLip", V3(3.8, 0.3, 3.8), CFrame.new(pos + V3(0, 1.5, 0)), PAL.GOLD, MAT.Metal)
	ball(parent, "Shrub", 3, pos + V3(0, 2.7, 0), red and PAL.BURG or PAL.GREEN, MAT.Grass, { CanCollide = false })
end

-- ============================================================ ISLAND PARTS
local function rockUnder(cx, cz, r)
	local par = F.Island
	local y = -6
	local layers = 9
	for i = 1, layers do
		local f = 1 - (i - 1) / layers
		local rr = r * f * (0.9 + rng:NextNumber() * 0.15)
		local h = 7 + rng:NextNumber() * 5
		local ox = (rng:NextNumber() - 0.5) * r * 0.1
		local oz = (rng:NextNumber() - 0.5) * r * 0.1
		local cf = CFrame.new(W(cx + ox, y - h / 2, cz + oz)) * CFrame.Angles(0, rng:NextNumber() * TAU, 0)
		mk(par, "RockLayer", V3(rr * 2, h, rr * 1.85), cf, ROCKS[rng:NextInteger(1, #ROCKS)], MAT.Slate)
		y = y - h * 0.78
	end
	local spikes = math.floor(r / 4)
	for i = 1, spikes do
		local a = rng:NextNumber() * TAU
		local d = rng:NextNumber() * r * 0.5
		local s = 4 + rng:NextNumber() * 7
		local yy = -14 - rng:NextNumber() * (r * 1.1)
		local cf = CFrame.new(W(cx + math.cos(a) * d, yy, cz + math.sin(a) * d))
			* CFrame.Angles(0, rng:NextNumber() * TAU, 0) * CFrame.Angles(math.rad(35.26), 0, math.rad(45))
		mk(par, "RockSpike", V3(s, s * 1.8, s), cf, ROCKS[rng:NextInteger(1, #ROCKS)], MAT.Slate)
	end
	-- jutting ledges around the rim
	for i = 1, math.floor(r / 6) do
		local a = rng:NextNumber() * TAU
		local d = r * (0.8 + rng:NextNumber() * 0.2)
		local cf = CFrame.new(W(cx + math.cos(a) * d, -9 - rng:NextNumber() * 8, cz + math.sin(a) * d)) * CFrame.Angles(0, a, 0)
		mk(par, "RockLedge", V3(5 + rng:NextNumber() * 5, 6 + rng:NextNumber() * 4, 7), cf, ROCKS[rng:NextInteger(1, #ROCKS)], MAT.Slate)
	end
end

local function waterfall(cx, cz, r, a, w, h)
	local par = F.Water
	local out = V3(math.cos(a), 0, math.sin(a))
	local pos = W(cx + out.X * (r + 0.4), -1 - h / 2, cz + out.Z * (r + 0.4))
	local cf = CFrame.lookAt(pos, pos + out)
	mk(par, "Waterfall", V3(w, h, 1.6), cf, PAL.WATER, MAT.Neon, { Transparency = 0.4, CanCollide = false, CastShadow = false })
	mk(par, "WaterfallHaze", V3(w * 1.6, h, 0.8), cf * CFrame.new(0, 0, -0.4), C3(220, 245, 255), MAT.SmoothPlastic, { Transparency = 0.82, CanCollide = false, CastShadow = false })
	mk(par, "WaterSpill", V3(w, 0.5, 3), CFrame.lookAt(W(cx + out.X * (r - 0.8), 0.3, cz + out.Z * (r - 0.8)), W(cx + out.X * r, 0.3, cz + out.Z * r)), C3(200, 240, 255), MAT.Neon, { Transparency = 0.2, CanCollide = false })
	local m = mk(par, "WaterMist", V3(w, 0.5, 2), cf * CFrame.new(0, -h / 2, 0), PAL.WATER, MAT.SmoothPlastic, { Transparency = 1, CanCollide = false })
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/smoke_main.dds"
	e.Rate = 8
	e.Lifetime = NumberRange.new(3, 5)
	e.Speed = NumberRange.new(2, 4)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Size = NumberSequence.new(10, 20)
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.7), NumberSequenceKeypoint.new(1, 1) })
	e.LightEmission = 0.3
	e.Color = ColorSequence.new(Color3.new(1, 1, 1))
	e.Parent = m
end

local function waterfalls(cx, cz, r, n, gaps)
	for i = 1, n do
		local a = rng:NextNumber() * TAU
		local tries = 0
		while blocked(a, gaps) and tries < 20 do
			a = rng:NextNumber() * TAU
			tries = tries + 1
		end
		waterfall(cx, cz, r, a, 3 + rng:NextNumber() * 7, 70 + rng:NextNumber() * 90)
	end
end

-- round platform with gold trim, marble tile, ring wall and rock underside
local function platform(name, cx, cz, r, gaps, wallH, wallR)
	local par = F.Island
	cyl(par, name .. "_Base", 2 * r, 6, W(cx, -3, cz), PAL.STONE, MAT.Slate)
	cyl(par, name .. "_Trim", 2 * r + 0.8, 0.6, W(cx, -1.2, cz), PAL.GOLD, MAT.Metal)
	cyl(par, name .. "_Tile", 2 * r - 3, 0.4, W(cx, 0.2, cz), PAL.TILE, MAT.Marble)
	rockUnder(cx, cz, r)
	wallH = wallH or 2
	wallR = wallR or (r - 1.2)
	local count = math.floor(TAU * wallR / 3.2)
	for i = 0, count - 1 do
		local a = i / count * TAU
		if not blocked(a, gaps) then
			local pos = W(cx + math.cos(a) * wallR, wallH / 2, cz + math.sin(a) * wallR)
			local cf = CFrame.lookAt(pos, W(cx, wallH / 2, cz))
			mk(par, name .. "_Wall", V3(3.4, wallH, 0.9), cf, PAL.STONE2, MAT.Slate)
			mk(par, name .. "_WallCap", V3(3.5, 0.3, 1.2), cf * CFrame.new(0, wallH / 2 + 0.15, 0), PAL.GOLD, MAT.Metal)
			if i % 4 == 0 then
				mk(par, name .. "_Post", V3(1.3, wallH + 1.2, 1.3), cf * CFrame.new(0, 0.6, 0), PAL.BLACK, MAT.Marble)
				ball(par, name .. "_PostBall", 1.1, pos + V3(0, wallH / 2 + 1.5, 0), PAL.GOLD, MAT.Metal)
			end
		end
	end
end

-- ============================================================ BRIDGES & GATES
local function gateArch(par, pos, dir, width, symbol)
	local cf = CFrame.lookAt(pos, pos + dir)
	for _, s in ipairs({ -1, 1 }) do
		local lp = cf * CFrame.new(s * (width / 2 + 1.4), 0, 0)
		mk(par, "ArchPillar", V3(2.4, 14, 2.4), lp * CFrame.new(0, 7, 0), PAL.STONE2, MAT.Slate)
		mk(par, "ArchBase", V3(3.4, 1.2, 3.4), lp * CFrame.new(0, 0.6, 0), PAL.GOLD, MAT.Metal)
		mk(par, "ArchCap", V3(3.2, 0.9, 3.2), lp * CFrame.new(0, 14.4, 0), PAL.GOLD, MAT.Metal)
		mk(par, "ArchGlow", V3(0.4, 9, 0.4), lp * CFrame.new(0, 7.5, -1.25), PAL.RED, MAT.Neon, { CanCollide = false })
		local lt = mk(par, "ArchLight", V3(1, 1.4, 1), lp * CFrame.new(0, 11.8, -1.5), PAL.AMBER, MAT.Neon, { CanCollide = false })
		addLight(lt, PAL.AMBER, 14, 0.8)
	end
	local top = cf * CFrame.new(0, 15.8, 0)
	mk(par, "ArchBeam", V3(width + 5.6, 2.2, 3), top, PAL.STONE2, MAT.Slate)
	mk(par, "ArchGold", V3(width + 5.8, 0.5, 3.2), top * CFrame.new(0, -1.2, 0), PAL.GOLD, MAT.Metal)
	mk(par, "ArchRed", V3(width + 4, 0.3, 0.3), top * CFrame.new(0, 0.2, -1.6), PAL.RED, MAT.Neon, { CanCollide = false })
	local d = mk(par, "ArchEmblem", V3(3.6, 3.6, 0.6), top * CFrame.new(0, 3, 0) * CFrame.Angles(0, 0, math.rad(45)), PAL.RED, MAT.Fabric, { CanCollide = false })
	local face = mk(par, "ArchSymbol", V3(2.6, 2.6, 0.2), top * CFrame.new(0, 3, -0.4), PAL.RED, MAT.Fabric, { CanCollide = false, Transparency = 1 })
	label(face, Enum.NormalId.Front, symbol or "♦", PAL.GOLD)
end

local function bridge(ax, az, bx, bz, w, cw)
	local par = F.Bridges
	local a = V3(ax, 0, az)
	local b = V3(bx, 0, bz)
	local len = (b - a).Magnitude
	local dir = (b - a).Unit
	local mid = (a + b) / 2
	local p0 = W(mid.X, 0, mid.Z)
	local cf = CFrame.lookAt(p0, p0 + dir)
	mk(par, "BridgeDeck", V3(w, 1.2, len), cf * CFrame.new(0, -0.1, 0), PAL.TILE2, MAT.Marble)
	mk(par, "BridgeKeel1", V3(w * 0.8, 7, len * 0.97), cf * CFrame.new(0, -4.2, 0), PAL.STONE, MAT.Slate)
	mk(par, "BridgeKeel2", V3(w * 0.5, 9, len * 0.82), cf * CFrame.new(0, -11, 0), PAL.STONE2, MAT.Slate)
	mk(par, "BridgeKeel3", V3(w * 0.25, 9, len * 0.6), cf * CFrame.new(0, -19, 0), ROCKS[3], MAT.Slate)
	mk(par, "BridgeGoldEdge", V3(w + 0.4, 0.4, len), cf * CFrame.new(0, -0.9, 0), PAL.GOLD, MAT.Metal)
	mk(par, "BridgeCarpet", V3(cw, 0.1, len), cf * CFrame.new(0, 0.55, 0), PAL.RED, MAT.Fabric)
	for _, s in ipairs({ -1, 1 }) do
		mk(par, "CarpetBorder", V3(0.35, 0.12, len), cf * CFrame.new(s * (cw / 2 + 0.2), 0.57, 0), PAL.GOLD, MAT.Metal, { CanCollide = false })
		mk(par, "BridgeRail", V3(0.8, 2.6, len), cf * CFrame.new(s * (w / 2 - 0.4), 1.8, 0), PAL.STONE2, MAT.Slate)
		mk(par, "BridgeRailCap", V3(1.1, 0.35, len), cf * CFrame.new(s * (w / 2 - 0.4), 3.2, 0), PAL.GOLD, MAT.Metal)
	end
	local side = V3(-dir.Z, 0, dir.X)
	local n = 0
	local d = 6
	while d < len - 3 do
		for _, s in ipairs({ -1, 1 }) do
			local p = a + dir * d + side * s * (w / 2 - 0.4)
			if n % 2 == 0 then
				lamp(par, W(p.X, 3.4, p.Z), 4.5)
			elseif n % 6 == 1 then
				banner(par, W(p.X, 3.4, p.Z), side * -s, "♦", 3, 7)
			end
		end
		n = n + 1
		d = d + 12
	end
end

-- ============================================================ CENTRAL PLAZA + CARD MASTER
local plazaDirs = {}      -- angles of the 6 bridges leaving the plaza

local function buildPlaza()
	local par = F.Plaza
	local gaps = {}
	for _, a in ipairs(plazaDirs) do gaps[#gaps + 1] = { a, 0.3 } end
	platform("Plaza", 0, 0, 34, gaps, 2, 33)

	-- floor medallion rings
	cyl(par, "PlazaBlack", 63, 0.1, W(0, 0.45, 0), PAL.MARBLE, MAT.Marble)
	cyl(par, "PlazaGold", 61.6, 0.1, W(0, 0.5, 0), PAL.GOLD, MAT.Metal)
	cyl(par, "PlazaTile", 60.4, 0.1, W(0, 0.55, 0), PAL.TILE, MAT.Marble)
	for i = 0, 11 do
		local a = i / 12 * TAU
		mk(par, "PlazaInlay", V3(0.5, 0.06, 20), CFrame.new(W(math.cos(a) * 20, 0.6, math.sin(a) * 20)) * CFrame.Angles(0, -a + math.pi / 2, 0), PAL.GOLD, MAT.Metal, { CanCollide = false })
	end

	-- carpets leaving the pedestal
	for _, a in ipairs(plazaDirs) do
		local w = (math.abs(math.sin(a)) > 0.99) and 10 or 8
		local cf = CFrame.new(W(math.cos(a) * 27, 0.62, math.sin(a) * 27)) * CFrame.Angles(0, -a + math.pi / 2, 0)
		mk(par, "PlazaCarpet", V3(w, 0.1, 14), cf, PAL.RED, MAT.Fabric)
	end

	-- concentric steps and tall pedestal
	local steps = { { 24, 1 }, { 21, 2 }, { 18, 3 }, { 15, 4 } }
	for _, s in ipairs(steps) do
		cyl(par, "PedestalStep", s[1] * 2, s[2], W(0, s[2] / 2, 0), PAL.STONE3, MAT.Marble)
		cyl(par, "PedestalStepTrim", s[1] * 2 + 0.6, 0.25, W(0, s[2] - 0.1, 0), PAL.GOLD, MAT.Metal, { CanCollide = false })
	end
	cyl(par, "PedestalLower", 24, 6, W(0, 7, 0), PAL.MARBLE, MAT.Marble)
	cyl(par, "PedestalGoldBand", 25.2, 0.8, W(0, 4.4, 0), PAL.GOLD, MAT.Metal)
	cyl(par, "PedestalMid", 19, 6, W(0, 11, 0), PAL.STONE2, MAT.Slate)
	cyl(par, "PedestalRedGlow", 19.4, 0.4, W(0, 9.6, 0), PAL.RED, MAT.Neon, { CanCollide = false })
	cyl(par, "PedestalTop", 21, 1.2, W(0, 14.6, 0), PAL.GOLD, MAT.Metal)
	-- spade plaque facing the front
	local pl = mk(par, "PedestalPlaque", V3(7, 8, 0.6), CFrame.new(W(0, 8.4, 9.9)), PAL.DRED, MAT.Fabric, { CanCollide = false })
	label(pl, Enum.NormalId.Back, "♠", PAL.GOLD)
	mk(par, "PedestalPlaqueTrim", V3(8, 9, 0.4), CFrame.new(W(0, 8.4, 9.7)), PAL.GOLD, MAT.Metal, { CanCollide = false })

	-- statue (faces +Z). T = pedestal top
	local S = F.Statue
	local T = 15.2
	local function sp(x, y, z) return W(x, T + y, z) end
	local armor = C3(34, 34, 46)
	for _, s in ipairs({ -1, 1 }) do
		mk(S, "Leg", V3(3, 9, 3), CFrame.new(sp(s * 2.1, 4.5, 0)), armor, MAT.Metal)
		mk(S, "Boot", V3(3.4, 2.2, 4.4), CFrame.new(sp(s * 2.1, 1.1, 0.5)), PAL.GOLD, MAT.Metal)
		mk(S, "Knee", V3(3.3, 1.2, 0.8), CFrame.new(sp(s * 2.1, 5.5, 1.7)), PAL.GOLD, MAT.Metal)
	end
	mk(S, "Skirt", V3(8.6, 3, 4.8), CFrame.new(sp(0, 10.4, 0)), armor, MAT.Metal)
	mk(S, "Belt", V3(8, 1, 4.6), CFrame.new(sp(0, 12.4, 0)), PAL.GOLD, MAT.Metal)
	mk(S, "Torso", V3(7.6, 8.6, 4.2), CFrame.new(sp(0, 17, 0)), armor, MAT.Metal)
	mk(S, "ChestPlate", V3(5, 5.4, 0.7), CFrame.new(sp(0, 17.6, 2.3)), PAL.GOLD, MAT.Metal)
	mk(S, "ChestGem", V3(2, 2, 0.5), CFrame.new(sp(0, 17.6, 2.8)) * CFrame.Angles(0, 0, math.rad(45)), PAL.RED, MAT.Neon, { CanCollide = false })
	for _, s in ipairs({ -1, 1 }) do
		ball(S, "Shoulder", 4.8, sp(s * 5.4, 20.6, 0), PAL.GOLD, MAT.Metal)
		mk(S, "ShoulderSpike", V3(0.9, 2.6, 0.9), CFrame.new(sp(s * 6.6, 23, 0)) * CFrame.Angles(0, 0, math.rad(-s * 20)), PAL.GOLD, MAT.Metal)
	end
	cyl(S, "Neck", 2, 1.6, sp(0, 22, 0), armor, MAT.Metal)
	ball(S, "Head", 4.6, sp(0, 24.4, 0), C3(190, 150, 100), MAT.SmoothPlastic)
	mk(S, "FaceMask", V3(3.2, 2.2, 0.5), CFrame.new(sp(0, 24.1, 2.1)), PAL.GOLD, MAT.Metal)
	for _, s in ipairs({ -1, 1 }) do
		mk(S, "Eye", V3(0.8, 0.35, 0.3), CFrame.new(sp(s * 0.9, 24.5, 2.4)), PAL.RED, MAT.Neon, { CanCollide = false })
	end
	cyl(S, "CrownBand", 4.9, 0.9, sp(0, 26.2, 0), PAL.GOLD, MAT.Metal)
	for i = 0, 7 do
		local a = i / 8 * TAU
		local h = (i % 2 == 0) and 2.8 or 1.8
		mk(S, "CrownSpike", V3(0.8, h, 0.8), CFrame.new(sp(math.cos(a) * 2.1, 26.6 + h / 2, math.sin(a) * 2.1)), PAL.GOLD, MAT.Metal)
	end
	ball(S, "CrownRuby", 1, sp(0, 27, 2.2), PAL.RED, MAT.Neon, { CanCollide = false })

	-- cape
	local red = C3(150, 16, 32)
	mk(S, "CapeBack", V3(11.5, 19, 1), CFrame.new(sp(0, 14, -2.9)) * CFrame.Angles(math.rad(-8), 0, 0), red, MAT.Fabric)
	mk(S, "CapeRight", V3(3.4, 17, 0.9), CFrame.new(sp(-7.3, 12.5, -2)) * CFrame.Angles(0, math.rad(-20), math.rad(14)), red, MAT.Fabric)
	mk(S, "CapeLeft", V3(3.4, 15, 0.9), CFrame.new(sp(7.3, 12.5, -2.2)) * CFrame.Angles(0, math.rad(25), math.rad(-10)), red, MAT.Fabric)
	mk(S, "CapeHem", V3(15, 2.4, 1), CFrame.new(sp(0, 3.2, -4)) * CFrame.Angles(math.rad(-12), 0, 0), PAL.DRED, MAT.Fabric)
	mk(S, "CapeTrim", V3(15.4, 0.4, 1.2), CFrame.new(sp(0, 2, -4.2)), PAL.GOLD, MAT.Metal, { CanCollide = false })

	-- raised arm (book hand)
	local sh = sp(5.4, 20.6, 0)
	local el = sp(9.6, 25.5, 1.4)
	local hd = sp(11, 31, 2.6)
	limb(S, "UpperArmR", sh, el, 2.4, armor, MAT.Metal)
	ball(S, "ElbowR", 2.8, el, PAL.GOLD, MAT.Metal)
	limb(S, "ForearmR", el, hd, 2.2, armor, MAT.Metal)
	ball(S, "HandR", 2.8, hd, PAL.GOLD, MAT.Metal)
	book(S, sp(11, 39, 3), 2.1, 70)

	-- commanding arm
	local sh2 = sp(-5.4, 20.6, 0)
	local el2 = sp(-10.5, 22, 1.8)
	local hd2 = sp(-16.5, 24.5, 4.2)
	limb(S, "UpperArmL", sh2, el2, 2.4, armor, MAT.Metal)
	ball(S, "ElbowL", 2.8, el2, PAL.GOLD, MAT.Metal)
	limb(S, "ForearmL", el2, hd2, 2.2, armor, MAT.Metal)
	ball(S, "HandL", 2.8, hd2, PAL.GOLD, MAT.Metal)
	local orb = ball(S, "PalmOrb", 2.6, sp(-17.5, 27, 4.4), PAL.RED, MAT.Neon, { CanCollide = false })
	addLight(orb, C3(255, 70, 60), 24, 1.5)

	-- statue lighting
	local sl = mk(S, "StatueGlow", V3(1, 1, 1), CFrame.new(sp(0, 22, 8)), PAL.GOLD, MAT.Neon, { Transparency = 1, CanCollide = false })
	addLight(sl, C3(255, 220, 140), 60, 1.6)

	-- floating monster cards orbiting the statue
	local cards = {}
	local cardColors = { THEMES.Fire.accent, THEMES.Ice.accent, THEMES.Shadow.accent, THEMES.Gold.accent }
	local suits = { "♠", "♦", "♣", "♥" }
	local orbitCentre = W(0, T + 15, 0)
	for i = 0, 13 do
		local a = i / 14 * TAU
		local r = 15.5
		local y = (i - 7) * 0.9
		local cf = CFrame.lookAt(orbitCentre + V3(math.cos(a) * r, y, math.sin(a) * r), orbitCentre + V3(0, y, 0))
		local c = mk(S, "FloatingCard", V3(3.2, 4.6, 0.18), cf, PAL.IVORY, MAT.SmoothPlastic, { CanCollide = false })
		local edge = mk(S, "FloatingCardGlow", V3(3.6, 5, 0.1), cf * CFrame.new(0, 0, 0.1), cardColors[(i % 4) + 1], MAT.Neon, { CanCollide = false, Transparency = 0.15 })
		label(c, Enum.NormalId.Front, suits[(i % 4) + 1], cardColors[(i % 4) + 1])
		label(c, Enum.NormalId.Back, suits[(i % 4) + 1], cardColors[(i % 4) + 1])
		cards[#cards + 1] = { c, edge, cf, cf * CFrame.new(0, 0, 0.1) }
	end
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc = acc + dt
		if acc < 0.05 then return end
		local t = os.clock() * 0.25
		local rot = CFrame.new(orbitCentre) * CFrame.Angles(0, t, 0) * CFrame.new(-orbitCentre)
		for _, c in ipairs(cards) do
			c[1].CFrame = rot * c[3]
			c[2].CFrame = rot * c[4]
		end
		acc = 0
	end)

	-- plaza dressing: lamps, planters, trees
	for i = 0, 11 do
		local a = (i + 0.5) / 12 * TAU
		if not blocked(a, gaps) then
			lamp(par, W(math.cos(a) * 28.5, 0.5, math.sin(a) * 28.5), 6)
			if i % 2 == 0 then
				planter(par, W(math.cos(a) * 31.5, 0.5, math.sin(a) * 31.5), i % 4 == 0)
			end
		end
	end
	for _, a in ipairs(plazaDirs) do
		gateArch(par, W(math.cos(a) * 31.5, 0.6, math.sin(a) * 31.5), V3(math.cos(a), 0, math.sin(a)) * -1, 12, "♠")
	end
	waterfalls(0, 0, 34, 4, gaps)
end

-- ============================================================ CASTLE
local function tower(par, x, z, y0, r, topY, glowFront)
	local h = topY - y0
	cyl(par, "TowerShaft", 2 * r, h, W(x, y0 + h / 2, z), PAL.STONE, MAT.Slate)
	local bands = math.floor(h / 14)
	for i = 1, bands do
		cyl(par, "TowerBand", 2 * r + 0.8, 0.8, W(x, y0 + i * 14, z), PAL.GOLD, MAT.Metal)
	end
	-- windows
	for i = 1, math.max(1, bands) do
		local wy = y0 + i * 14 - 6
		local win = mk(par, "TowerWindow", V3(0.9, 3.6, 0.5), CFrame.new(W(x, wy, z + r - 0.1)), PAL.AMBER, MAT.Neon, { CanCollide = false })
		if i == 1 then addLight(win, PAL.AMBER, 18, 0.7) end
	end
	if glowFront then
		mk(par, "TowerRedLine", V3(0.5, h, 0.4), CFrame.new(W(x + r * 0.7, y0 + h / 2, z + r * 0.7)), PAL.RED, MAT.Neon, { CanCollide = false })
		mk(par, "TowerRedLine", V3(0.5, h, 0.4), CFrame.new(W(x - r * 0.7, y0 + h / 2, z + r * 0.7)), PAL.RED, MAT.Neon, { CanCollide = false })
	end
	cyl(par, "TowerDeck", 2 * r + 2.4, 1.6, W(x, topY + 0.8, z), PAL.STONE2, MAT.Slate)
	for i = 0, 9 do
		local a = i / 10 * TAU
		mk(par, "Crenel", V3(1.4, 1.6, 1.4), CFrame.new(W(x + math.cos(a) * (r + 0.8), topY + 2.4, z + math.sin(a) * (r + 0.8))), PAL.STONE3, MAT.Slate)
	end
	-- stepped spire
	local layers = 9
	local lh = r * 1.1
	for i = 1, layers do
		local d = math.max(0.5, 2 * r * (1 - (i - 1) / layers) * 1.05)
		cyl(par, "Spire", d, lh, W(x, topY + 1.6 + (i - 0.5) * lh, z), (i % 2 == 0) and PAL.RED or PAL.BLACK, MAT.SmoothPlastic)
	end
	local ty = topY + 1.6 + layers * lh
	cyl(par, "SpireNeedle", 0.4, 4, W(x, ty + 2, z), PAL.GOLD, MAT.Metal)
	ball(par, "SpireFinial", 1.4, W(x, ty + 4.3, z), PAL.GOLD, MAT.Metal)
end

local function buildCastle()
	local par = F.Castle
	local z0 = -130
	local f = z0 + 14               -- front edge of the terrace
	local zf = f - 4                -- front face of the keep
	local gaps = { { math.pi / 2, 0.35 } }
	platform("Castle", 0, z0, 48, gaps, 2, 46.5)

	-- raised terrace with grand staircase
	mk(par, "Terrace", V3(66, 6, 36), CFrame.new(W(0, 3, f - 18)), PAL.STONE, MAT.Slate)
	mk(par, "TerraceTrim", V3(66.6, 0.6, 36.6), CFrame.new(W(0, 5.7, f - 18)), PAL.GOLD, MAT.Metal)
	mk(par, "TerraceFloor", V3(64, 0.3, 34), CFrame.new(W(0, 6.15, f - 18)), PAL.TILE2, MAT.Marble)
	for i = 1, 6 do
		mk(par, "GrandStair", V3(24, i, 2), CFrame.new(W(0, i / 2, f + (7 - i) * 2 - 1)), PAL.TILE, MAT.Marble)
		mk(par, "StairCarpet", V3(12, 0.1, 2.02), CFrame.new(W(0, i + 0.05, f + (7 - i) * 2 - 1)), PAL.RED, MAT.Fabric, { CanCollide = false })
	end
	for _, s in ipairs({ -1, 1 }) do
		mk(par, "StairWall", V3(1.6, 3, 13), CFrame.new(W(s * 12.8, 1.5, f + 6)), PAL.STONE2, MAT.Slate)
		mk(par, "StairWallCap", V3(2, 0.4, 13.4), CFrame.new(W(s * 12.8, 3.2, f + 6)), PAL.GOLD, MAT.Metal)
		lamp(par, W(s * 12.8, 3.4, f + 11), 6)
		lamp(par, W(s * 12.8, 3.4, f + 1), 6)
	end
	for x = -31, 31, 4 do
		if math.abs(x) > 13 then
			mk(par, "TerraceCrenel", V3(2.2, 1.6, 1.2), CFrame.new(W(x, 6.9, f - 0.8)), PAL.STONE3, MAT.Slate)
		end
	end

	-- keep: 3 tiers
	local kc = zf - 10
	mk(par, "Keep1", V3(40, 40, 20), CFrame.new(W(0, 26, kc)), PAL.STONE, MAT.Slate)
	mk(par, "Keep1Gold", V3(41, 0.8, 21), CFrame.new(W(0, 46, kc)), PAL.GOLD, MAT.Metal)
	mk(par, "Keep2", V3(30, 24, 16), CFrame.new(W(0, 58, kc - 2)), PAL.STONE, MAT.Slate)
	mk(par, "Keep2Gold", V3(31, 0.8, 17), CFrame.new(W(0, 70, kc - 2)), PAL.GOLD, MAT.Metal)
	mk(par, "Keep3", V3(18, 18, 12), CFrame.new(W(0, 79.5, kc - 2)), PAL.STONE2, MAT.Slate)
	for i = 1, 6 do
		mk(par, "Roof", V3(22 - i * 3, 3, 14 - i * 2), CFrame.new(W(0, 88.5 + (i - 0.5) * 3, kc - 2)), (i % 2 == 1) and PAL.BLACK or PAL.RED, MAT.SmoothPlastic)
	end
	mk(par, "RoofRidge", V3(2, 1.2, 4), CFrame.new(W(0, 107.5, kc - 2)), PAL.GOLD, MAT.Metal)
	-- wings joining towers
	for _, s in ipairs({ -1, 1 }) do
		mk(par, "Wing", V3(16, 26, 16), CFrame.new(W(s * 24, 19, kc - 1)), PAL.STONE3, MAT.Slate)
		mk(par, "WingRoof", V3(17, 1.2, 17), CFrame.new(W(s * 24, 32.6, kc - 1)), PAL.GOLD, MAT.Metal)
	end

	-- neon edge lines
	for _, s in ipairs({ -1, 1 }) do
		mk(par, "RedEdge", V3(0.6, 40, 0.6), CFrame.new(W(s * 20, 26, zf + 0.2)), PAL.RED, MAT.Neon, { CanCollide = false })
		mk(par, "RedEdge", V3(0.6, 24, 0.6), CFrame.new(W(s * 15, 58, kc - 2 + 8.2)), PAL.RED, MAT.Neon, { CanCollide = false })
	end
	mk(par, "RedLineH", V3(40, 0.5, 0.5), CFrame.new(W(0, 45.4, zf + 0.2)), PAL.RED, MAT.Neon, { CanCollide = false })
	mk(par, "RedLineH2", V3(30, 0.5, 0.5), CFrame.new(W(0, 69.4, kc + 6.2)), PAL.RED, MAT.Neon, { CanCollide = false })

	-- pointed gothic gate (rect + rotated diamond)
	local gy = 6
	local gh = 14
	mk(par, "GateFrameRect", V3(12.4, gh, 0.8), CFrame.new(W(0, gy + gh / 2, zf - 0.1)), PAL.GOLD, MAT.Metal, { CanCollide = false })
	mk(par, "GateFrameDia", V3(8.8, 8.8, 0.8), CFrame.new(W(0, gy + gh, zf - 0.1)) * CFrame.Angles(0, 0, math.rad(45)), PAL.GOLD, MAT.Metal, { CanCollide = false })
	mk(par, "GateRect", V3(10, gh, 1.2), CFrame.new(W(0, gy + gh / 2, zf + 0.1)), C3(12, 8, 10), MAT.SmoothPlastic, { CanCollide = false })
	mk(par, "GateDia", V3(7.07, 7.07, 1.2), CFrame.new(W(0, gy + gh, zf + 0.1)) * CFrame.Angles(0, 0, math.rad(45)), C3(12, 8, 10), MAT.SmoothPlastic, { CanCollide = false })
	local glow = mk(par, "GateGlow", V3(8, gh, 0.3), CFrame.new(W(0, gy + gh / 2, zf + 0.7)), PAL.AMBER, MAT.Neon, { CanCollide = false, Transparency = 0.45 })
	addLight(glow, PAL.AMBER, 40, 1.4)
	-- real walkable passage into the keep
	for _, s in ipairs({ -1, 1 }) do
		mk(par, "GateJamb", V3(1.2, gh + 2, 4), CFrame.new(W(s * 5.8, gy + (gh + 2) / 2, zf + 1)), PAL.GOLD, MAT.Metal)
	end

	-- emblem panels
	wallPanel(par, CFrame.new(W(0, 34, zf - 0.6)), 14, 16, "♠", PAL.DRED, Enum.NormalId.Back)
	mk(par, "SpadeGlow", V3(15.4, 0.4, 0.4), CFrame.new(W(0, 42.2, zf - 0.3)), PAL.RED, MAT.Neon, { CanCollide = false })
	mk(par, "SpadeGlow", V3(15.4, 0.4, 0.4), CFrame.new(W(0, 25.8, zf - 0.3)), PAL.RED, MAT.Neon, { CanCollide = false })
	wallPanel(par, CFrame.new(W(-13, 31, zf - 0.6)), 7, 10, "♣", PAL.BLACK, Enum.NormalId.Back)
	wallPanel(par, CFrame.new(W(13, 31, zf - 0.6)), 7, 10, "♣", PAL.BLACK, Enum.NormalId.Back)
	wallPanel(par, CFrame.new(W(-15, 14, zf - 0.6)), 4.5, 12, "♦", PAL.RED, Enum.NormalId.Back)
	wallPanel(par, CFrame.new(W(15, 14, zf - 0.6)), 4.5, 12, "♦", PAL.RED, Enum.NormalId.Back)
	wallPanel(par, CFrame.new(W(-9, 60, kc - 2 + 8.4)), 4.5, 14, "♦", PAL.RED, Enum.NormalId.Back)
	wallPanel(par, CFrame.new(W(9, 60, kc - 2 + 8.4)), 4.5, 14, "♦", PAL.RED, Enum.NormalId.Back)
	wallPanel(par, CFrame.new(W(0, 60, kc - 2 + 8.4)), 8, 12, "♠", PAL.DRED, Enum.NormalId.Back)

	-- windows
	for _, row in ipairs({ { 22, 3 }, { 40, 3 } }) do
		for _, x in ipairs({ -17, -8, 8, 17 }) do
			if not (row[1] == 40 and math.abs(x) < 10) then
				local w = mk(par, "KeepWindow", V3(1.6, 5, 0.5), CFrame.new(W(x, row[1], zf + 0.1)), PAL.AMBER, MAT.Neon, { CanCollide = false })
				mk(par, "WindowFrame", V3(2.4, 5.8, 0.4), CFrame.new(W(x, row[1], zf - 0.05)), PAL.GOLD, MAT.Metal, { CanCollide = false })
			end
		end
	end

	-- towers and turrets
	for _, s in ipairs({ -1, 1 }) do
		tower(par, s * 27, kc + 4, 6, 6, 80, true)
		tower(par, s * 13.5, kc + 6, 6, 3.4, 64, false)
		tower(par, s * 40, z0 + 4, 0, 3.6, 56, false)
	end

	-- MAGICAL BOOK high above the roofline
	cyl(par, "BookPillar", 3, 6, W(0, 111, kc - 2), PAL.GOLD, MAT.Metal)
	mk(par, "BookCradle", V3(18, 1.4, 4), CFrame.new(W(0, 113.7, kc - 2)) * CFrame.Angles(0, 0, 0), PAL.GOLD, MAT.Metal)
	book(par, W(0, 128, kc - 2), 2.9, 120)

	-- castle courtyard garden
	local zA = -88
	local zB = f + 14
	mk(par, "CourtCarpet", V3(10, 0.1, math.abs(zB - zA)), CFrame.new(W(0, 0.62, (zA + zB) / 2)), PAL.RED, MAT.Fabric)
	for _, s in ipairs({ -1, 1 }) do
		mk(par, "CourtCarpetEdge", V3(0.35, 0.12, math.abs(zB - zA)), CFrame.new(W(s * 5.2, 0.64, (zA + zB) / 2)), PAL.GOLD, MAT.Metal, { CanCollide = false })
	end
	local z = zA - 6
	while z > zB + 2 do
		for _, s in ipairs({ -1, 1 }) do
			lamp(par, W(s * 7, 0.5, z), 6)
			tree(par, W(s * 14, 0.4, z + 3), 1.1, (math.floor(z) % 2 == 0))
			planter(par, W(s * 20, 0.4, z), true)
		end
		z = z - 8
	end
	waterfalls(0, z0, 48, 7, gaps)
end

-- ============================================================ ARENAS
local function buildArena(A)
	local T = A.theme
	local par = Instance.new("Model")
	par.Name = A.name
	par.Parent = F.Arenas
	local cx, cz = A.x, A.z
	local inward = ang(-cx, -cz)
	local nb = ang(0, -cz)
	local gaps = { { inward, 0.3 }, { nb, 0.3 } }
	local out = ang(cx, cz)
	local fy = 0.7
	local centre = W(cx, fy, cz)

	platform(A.name, cx, cz, 52, gaps, 3, 50.8)

	-- ---------- floor + emblem
	cyl(par, "Floor", 72, 0.3, W(cx, 0.55, cz), PAL.MARBLE, MAT.Marble)
	cyl(par, "FloorGoldRing", 73.2, 0.3, W(cx, 0.52, cz), PAL.GOLD, MAT.Metal)
	local rings = {
		{ 38, 0.75, PAL.GOLD, MAT.Metal },
		{ 36.8, 0.8, PAL.BLACK, MAT.Marble },
		{ 34.4, 0.85, T.accent, MAT.Neon },
		{ 33.2, 0.9, PAL.BLACK, MAT.Marble },
		{ 30, 0.95, T.c1, MAT.SmoothPlastic },
	}
	for _, r in ipairs(rings) do
		cyl(par, "FloorRing", r[1], 0.05, W(cx, r[2] - 0.025, cz), r[3], r[4], { CanCollide = false })
	end
	for i = 0, 11 do
		local a = i / 12 * TAU
		mk(par, "FloorSpoke", V3(1, 0.05, 11), CFrame.new(W(cx + math.cos(a) * 10, 1.0, cz + math.sin(a) * 10)) * CFrame.Angles(0, -a + math.pi / 2, 0), (i % 2 == 0) and T.accent or T.c2, MAT.Neon, { CanCollide = false, Transparency = 0.15 })
	end
	mk(par, "Octagram1", V3(17, 0.05, 17), CFrame.new(W(cx, 1.03, cz)), T.accent, MAT.Neon, { CanCollide = false })
	mk(par, "Octagram2", V3(17, 0.05, 17), CFrame.new(W(cx, 1.06, cz)) * CFrame.Angles(0, math.rad(45), 0), T.accent, MAT.Neon, { CanCollide = false })
	cyl(par, "EmblemDisc", 16, 0.05, W(cx, 1.09, cz), PAL.BLACK, MAT.Marble, { CanCollide = false })
	cyl(par, "EmblemRing", 15, 0.05, W(cx, 1.12, cz), T.accent, MAT.Neon, { CanCollide = false })
	cyl(par, "EmblemCore", 14, 0.05, W(cx, 1.15, cz), T.c1, MAT.SmoothPlastic, { CanCollide = false })
	local art = mk(par, "EmblemArt", V3(11, 0.05, 11), CFrame.new(W(cx, 1.2, cz)), T.c1, MAT.SmoothPlastic, { CanCollide = false })
	local fimg = CFG.FloorImages[T.key]
	if fimg and fimg ~= "" then
		art.Size = V3(24, 0.05, 24)
		local d = Instance.new("Decal")
		d.Face = Enum.NormalId.Top
		d.Texture = fimg
		d.Parent = art
	else
		label(art, Enum.NormalId.Top, T.emoji, T.accent)
	end
	addLight(art, T.accent, 40, 0.9)

	-- ---------- gates on both entrances
	for _, g in ipairs(gaps) do
		local p = W(cx + math.cos(g[1]) * 36.5, fy, cz + math.sin(g[1]) * 36.5)
		gateArch(par, p, V3(math.cos(g[1]), 0, math.sin(g[1])) * -1, 12, "♦")
	end

	-- ---------- duel stations: N players per side (1v1, 2v2, 3v3, 4v4)
	local n = A.team
	local Ks = { 12, 10, 8, 6 }
	local K = Ks[n]
	local R = 25.5
	local L = math.max(6, n * 2.6 + 1.5)          -- table length grows with team size
	local skipR = (K <= 8) and 0.5 or 0.62
	for k = 0, K - 1 do
		local a = inward + (k + 0.5) * TAU / K
		local skip = false
		for _, g in ipairs(gaps) do
			if angDiff(a, g[1]) < skipR then skip = true end
		end
		if not skip then
			local tp = W(cx + math.cos(a) * R, fy, cz + math.sin(a) * R)
			local cf = CFrame.lookAt(tp, centre)      -- local X = long axis (tangent), -Z = towards emblem
			mk(par, "DuelTable", V3(L, 0.6, 4), cf * CFrame.new(0, 3.5, 0), PAL.BLACK, MAT.Marble)
			mk(par, "DuelTableRim", V3(L + 0.5, 0.5, 4.5), cf * CFrame.new(0, 3.1, 0), PAL.GOLD, MAT.Metal)
			local legs = (L > 8) and { -L / 4, L / 4 } or { 0 }
			for _, lx in ipairs(legs) do
				cyl(par, "DuelTableLeg", 1.6, 2.8, cf:PointToWorldSpace(V3(lx, 1.4, 0)), PAL.GOLD, MAT.Metal)
				cyl(par, "DuelTableBase", 3.4, 0.3, cf:PointToWorldSpace(V3(lx, 0.15, 0)), PAL.BLACK, MAT.Metal)
			end
			mk(par, "DuelMat", V3(L - 0.4, 0.06, 3.6), cf * CFrame.new(0, 3.83, 0), T.c1, MAT.Fabric, { CanCollide = false })
			mk(par, "DuelMatLine", V3(L - 0.4, 0.07, 0.12), cf * CFrame.new(0, 3.84, 0), PAL.GOLD, MAT.Metal, { CanCollide = false })
			cyl(par, "DuelZone", 1.4, 0.05, cf:PointToWorldSpace(V3(0, 3.87, 0)), PAL.GOLD, MAT.Metal, { CanCollide = false })
			for _, s in ipairs({ -1, 1 }) do
				for i = 1, n do
					local x = (i - (n + 1) / 2) * 2.6
					-- two monster cards in front of each player
					for c = -1, 1, 2 do
						mk(par, "MonsterCard", V3(1.0, 0.04, 0.85), cf * CFrame.new(x + c * 0.55, 3.88, s * 1.2),
							(c == -1) and T.accent or T.c2, MAT.Neon, { CanCollide = false })
					end
					-- chair directly across the table from its opponent
					local cp = cf:PointToWorldSpace(V3(x, 0, s * 4.3))
					local ccf = CFrame.lookAt(cp, cf:PointToWorldSpace(V3(x, 0, 0)))
					mk(par, "DuelSeat", V3(2, 0.5, 2), ccf * CFrame.new(0, 1.75, 0), PAL.RED, MAT.Fabric, nil, "Seat")
					mk(par, "ChairBack", V3(2, 2.4, 0.4), ccf * CFrame.new(0, 3.1, 0.9), PAL.RED, MAT.Fabric)
					mk(par, "ChairBackTrim", V3(2.1, 0.2, 0.5), ccf * CFrame.new(0, 4.35, 0.9), PAL.GOLD, MAT.Metal, { CanCollide = false })
					cyl(par, "ChairLeg", 1, 1.5, ccf:PointToWorldSpace(V3(0, 0.75, 0)), PAL.BLACK, MAT.Metal)
					cyl(par, "ChairFoot", 1.8, 0.2, ccf:PointToWorldSpace(V3(0, 0.1, 0)), PAL.GOLD, MAT.Metal)
				end
			end
		end
	end

	-- mode sign above the main entrance
	do
		local sp = W(cx + math.cos(inward) * 36.5, 22, cz + math.sin(inward) * 36.5)
		local dirIn = V3(math.cos(inward), 0, math.sin(inward))
		local sign = mk(par, "ModeSign", V3(14, 4, 0.6), CFrame.lookAt(sp, sp + dirIn), PAL.BLACK, MAT.Metal, { CanCollide = false })
		label(sign, Enum.NormalId.Front, n .. "v" .. n .. "  " .. T.name, T.accent)
		mk(par, "ModeSignTrim", V3(14.8, 4.8, 0.4), CFrame.lookAt(sp, sp + dirIn) * CFrame.new(0, 0, 0.3), PAL.GOLD, MAT.Metal, { CanCollide = false })
	end

	-- lamps on the floor rim
	for i = 0, 11 do
		local a = inward + i * TAU / 12
		if not blocked(a, { { inward, 0.45 }, { nb, 0.45 } }) then
			lamp(par, W(cx + math.cos(a) * 36.6, fy, cz + math.sin(a) * 36.6), 5)
		end
	end

	-- ---------- spectator tiers (curved rows of red seats)
	local N = 52
	local tiers = { { 38.8, 1.4 }, { 41.4, 2.8 }, { 44, 4.2 } }
	for ti, t in ipairs(tiers) do
		for i = 0, N - 1 do
			local a = i / N * TAU
			if not blocked(a, gaps) then
				local rt = t[1]
				local w = TAU * rt / N * 1.04
				local pos = W(cx + math.cos(a) * rt, 0, cz + math.sin(a) * rt)
				local cf = CFrame.lookAt(pos, W(cx, 0, cz))
				mk(par, "StandTier", V3(w, t[2], 2.6), cf * CFrame.new(0, t[2] / 2, 0), PAL.STONE2, MAT.Slate)
				mk(par, "SpectatorSeat", V3(w * 0.78, 0.5, 1.5), cf * CFrame.new(0, t[2] + 0.25, -0.2), PAL.RED, MAT.Fabric, { CanCollide = false })
				if ti < 3 or i % 2 == 0 then
					mk(par, "SeatBack", V3(w * 0.78, 1.2, 0.35), cf * CFrame.new(0, t[2] + 0.85, 0.85), PAL.DRED, MAT.Fabric, { CanCollide = false })
				end
				if i % 6 == 0 then
					mk(par, "TierGlow", V3(w, 0.2, 0.3), cf * CFrame.new(0, t[2] + 0.1, -1.3), T.accent, MAT.Neon, { CanCollide = false })
				end
			end
		end
	end

	-- ---------- monster card displays + banners
	local function at(a, r, y) return W(cx + math.cos(a) * r, y, cz + math.sin(a) * r) end
	local function facing(a, r, y) return CFrame.lookAt(at(a, r, y), at(a, 0, y)) end
	cardDisplay(par, facing(out, 47, 13.5), 22, 14, T, 6)
	for _, s in ipairs({ -1, 1 }) do
		cardDisplay(par, facing(out + s * 0.62, 48, 11), 7, 10, T, 4)
	end
	for _, s in ipairs({ -1, 1 }) do
		for _, o in ipairs({ 1.1, 1.65 }) do
			local a = out + s * o
			local p = at(a, 46.6, 0.4)
			local d = (at(a, 0, 0.4) - p).Unit
			banner(par, p, d, "♦", 4.4, 11)
		end
	end

	-- ---------- rim planting on the outside half
	for i = 0, 30 do
		local a = out + (i / 30 - 0.5) * 4.6
		if not blocked(a, gaps) and i % 2 == 0 then
			local p = at(a, 49, 0.4)
			if i % 4 == 0 then
				tree(par, p, 1, i % 8 == 0)
			else
				planter(par, p, i % 3 == 0)
			end
		end
	end
	waterfalls(cx, cz, 52, 5, gaps)
end

-- ============================================================ FRONT ENTRANCE
local function buildEntrance()
	local par = F.Decor
	local cz = 135
	local gaps = { { -math.pi / 2, 0.35 } }
	platform("Entrance", 0, cz, 34, gaps, 2, 32.8)
	cyl(par, "EntranceMedallion", 24, 0.1, W(0, 0.45, cz), PAL.MARBLE, MAT.Marble)
	cyl(par, "EntranceMedallionGold", 21, 0.1, W(0, 0.5, cz), PAL.GOLD, MAT.Metal)
	cyl(par, "EntranceMedallionRed", 19, 0.1, W(0, 0.55, cz), PAL.DRED, MAT.Fabric)
	local ml = mk(par, "EntranceSpade", V3(10, 0.05, 10), CFrame.new(W(0, 0.62, cz)), PAL.DRED, MAT.Fabric, { CanCollide = false })
	label(ml, Enum.NormalId.Top, "♠", PAL.GOLD)
	mk(par, "EntranceCarpet", V3(10, 0.1, 40), CFrame.new(W(0, 0.62, cz - 14)), PAL.RED, MAT.Fabric)
	for _, s in ipairs({ -1, 1 }) do
		mk(par, "EntranceCarpetEdge", V3(0.35, 0.12, 40), CFrame.new(W(s * 5.2, 0.64, cz - 14)), PAL.GOLD, MAT.Metal, { CanCollide = false })
	end
	-- spawn
	local sp = Instance.new("SpawnLocation")
	sp.Name = "KingdomSpawn"
	sp.Anchored = true
	sp.Size = V3(8, 0.6, 8)
	sp.CFrame = CFrame.new(W(0, 0.9, cz + 8))
	sp.Color = PAL.RED
	sp.Material = MAT.Neon
	sp.Transparency = 0.5
	sp.Neutral = true
	sp.Parent = par
	-- grand welcome gate with sign
	gateArch(par, W(0, 0.6, cz - 20), V3(0, 0, -1), 14, "♠")
	local sign = mk(par, "WelcomeSign", V3(26, 3.4, 0.6), CFrame.new(W(0, 22.6, cz - 19.9)) * CFrame.Angles(0, math.pi, 0), PAL.BLACK, MAT.Metal, { CanCollide = false })
	label(sign, Enum.NormalId.Front, "CARD CASINO KINGDOM", PAL.GOLD)
	label(sign, Enum.NormalId.Back, "CARD CASINO KINGDOM", PAL.GOLD)
	for i = 0, 9 do
		local a = i / 10 * TAU
		if not blocked(a, { { -math.pi / 2, 0.8 } }) then
			if i % 2 == 0 then
				tree(par, W(math.cos(a) * 26, 0.4, cz + math.sin(a) * 26), 1.2, i % 4 == 0)
			else
				lamp(par, W(math.cos(a) * 27, 0.5, cz + math.sin(a) * 27), 6)
			end
		end
	end
	for _, s in ipairs({ -1, 1 }) do
		banner(par, W(s * 12, 0.5, cz + 10), V3(0, 0, -1), "♦", 4.4, 11)
		banner(par, W(s * 12, 0.5, cz - 8), V3(0, 0, 1), "♠", 4.4, 11)
		planter(par, W(s * 18, 0.4, cz + 4), true)
		planter(par, W(s * 18, 0.4, cz - 8), false)
	end
	waterfalls(0, cz, 34, 5, gaps)
end

-- ============================================================ SKY, CLOUDS, LIGHTING
local function buildSky()
	local par = F.Sky
	for i = 1, 90 do
		local a = rng:NextNumber() * TAU
		local d = 90 + rng:NextNumber() * 700
		local y = -120 - rng:NextNumber() * 130
		local sz = V3(60 + rng:NextNumber() * 100, 12 + rng:NextNumber() * 14, 40 + rng:NextNumber() * 70)
		local c = mk(par, "CloudPuff", sz, CFrame.new(W(math.cos(a) * d, y, math.sin(a) * d)), PAL.CLOUD, MAT.SmoothPlastic, { CanCollide = false, CastShadow = false, Transparency = 0.2 })
		c.Shape = Enum.PartType.Ball
	end
	for i = 1, 14 do
		local a = rng:NextNumber() * TAU
		local d = 380 + rng:NextNumber() * 420
		local y = -40 + rng:NextNumber() * 160
		local x, z = math.cos(a) * d, math.sin(a) * d
		local r = 18 + rng:NextNumber() * 22
		for j = 1, 4 do
			local rr = r * (1 - (j - 1) / 4.5)
			mk(par, "FarRock", V3(rr * 2, 9, rr * 1.8), CFrame.new(W(x, y - j * 7, z)) * CFrame.Angles(0, rng:NextNumber() * TAU, 0), ROCKS[rng:NextInteger(1, #ROCKS)], MAT.Slate, { CanCollide = false })
		end
		mk(par, "FarGrass", V3(r * 2.1, 1.5, r * 1.9), CFrame.new(W(x, y + 0.5, z)), PAL.GREEN, MAT.Grass, { CanCollide = false })
		if i % 2 == 0 then
			cyl(par, "FarTower", 5, 22, W(x, y + 12, z), PAL.STONE, MAT.Slate, { CanCollide = false })
			cyl(par, "FarSpire", 3.6, 8, W(x, y + 27, z), PAL.RED, MAT.SmoothPlastic, { CanCollide = false })
		end
	end
end

local function buildLighting()
	Lighting.ClockTime = 15
	Lighting.Brightness = 3
	Lighting.GlobalShadows = true
	Lighting.Ambient = C3(95, 95, 118)
	Lighting.OutdoorAmbient = C3(125, 125, 145)
	Lighting.ColorShift_Top = C3(255, 235, 200)
	local atm = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
	atm.Density = 0.28
	atm.Offset = 0.25
	atm.Color = C3(199, 212, 238)
	atm.Decay = C3(150, 170, 225)
	atm.Glare = 0
	atm.Haze = 1.1
	atm.Parent = Lighting
	local bloom = Lighting:FindFirstChildOfClass("BloomEffect") or Instance.new("BloomEffect")
	bloom.Intensity = 0.35
	bloom.Size = 24
	bloom.Threshold = 1.6
	bloom.Parent = Lighting
	local cc = Lighting:FindFirstChildOfClass("ColorCorrectionEffect") or Instance.new("ColorCorrectionEffect")
	cc.Saturation = 0.15
	cc.Contrast = 0.08
	cc.Parent = Lighting
	local rays = Lighting:FindFirstChildOfClass("SunRaysEffect") or Instance.new("SunRaysEffect")
	rays.Intensity = 0.08
	rays.Spread = 0.6
	rays.Parent = Lighting
	local terrain = Workspace.Terrain
	local clouds = terrain:FindFirstChildOfClass("Clouds") or Instance.new("Clouds")
	clouds.Cover = 0.55
	clouds.Density = 0.6
	clouds.Color = Color3.new(1, 1, 1)
	clouds.Parent = terrain
end

-- ============================================================ BUILD
buildLighting()
buildSky()
task.wait()

local AX, AZ = CFG.ArenaX, CFG.ArenaZ
local arenas = {
	{ name = "Arena1_FireDragon",   x = -AX, z = -AZ, theme = THEMES.Fire, team = 1 },
	{ name = "Arena2_IceDragon",    x =  AX, z = -AZ, theme = THEMES.Ice, team = 2 },
	{ name = "Arena3_ShadowBeast",  x = -AX, z =  AZ, theme = THEMES.Shadow, team = 3 },
	{ name = "Arena4_GoldenLight",  x =  AX, z =  AZ, theme = THEMES.Gold, team = 4 },
}

-- bridge directions leaving the plaza
plazaDirs = { math.pi / 2, -math.pi / 2 }
for _, A in ipairs(arenas) do plazaDirs[#plazaDirs + 1] = ang(A.x, A.z) end

buildPlaza()
task.wait()
buildCastle()
task.wait()
buildEntrance()
task.wait()

-- bridges: front entrance, castle, four diagonals, two side links
bridge(0, 30, 0, 110, 16, 10)
bridge(0, -30, 0, -84, 14, 9)
for _, A in ipairs(arenas) do
	local d = V3(A.x, 0, A.z).Unit
	local a = d * 30
	local b = V3(A.x, 0, A.z) - d * 36
	bridge(a.X, a.Z, b.X, b.Z, 14, 8)
end
bridge(-AX, -AZ + 36, -AX, AZ - 36, 14, 8)
bridge( AX, -AZ + 36,  AX, AZ - 36, 14, 8)
task.wait()

for _, A in ipairs(arenas) do
	buildArena(A)
	task.wait()
end

print("Floating Card Casino Kingdom built: " .. partCount .. " parts")
