--[[
	ECHObOUND: CARD MASTER - PART 1: WORLD & ENVIRONMENT BUILDER
	-------------------------------------------------------------
	HOW TO RUN (Edit mode, NOT Play):
	  1. Open your project in Roblox Studio.
	  2. View > Command Bar, paste this whole script, press Enter.
	  3. Wait for "[ECHObOUND] DONE" in Output, then File > Save.
	Re-running is safe: it only deletes/rebuilds its own 18 folders.
	Unrelated objects and scripts are never deleted.

	Layout (Roblox: North = -Z, South = +Z, West = -X, East = +X)
	  North  : Last Arcana Castle       Center: Statue + plaza
	  NW A2  : 2v2    NE A3 : 3v3       SW A1 : 1v1    SE A4 : 4v4
	  South  : Spawn + gate (faces north)
	  West/East : Leaderboard monuments
]]

local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local CollectionService = game:GetService("CollectionService")
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

------------------------------------------------------------------ CONFIG
local CFG = {
	BaseY = 250,          -- island surface height (studs above origin)
	Seed = 1337,
	LightEvery = 3,       -- only every Nth lantern gets a PointLight (perf)
	HideBaseplate = true, -- makes an existing "Baseplate" invisible so the island floats
	WestBoard = { Type = "CollectionValue", Title = "COLLECTION LEADERBOARD",
		Sub = "Ranked by value of currently owned cards (duplicates included)" },
	EastBoard = { Type = "TournamentWins", Title = "TOURNAMENT LEADERBOARD",
		Sub = "Top duelists of the island (change BoardType later)" },
}

local G = CFG.BaseY
local rng = Random.new(CFG.Seed)
local rad, pi, sin, cos, abs, sqrt, floor = math.rad, math.pi, math.sin, math.cos, math.abs, math.sqrt, math.floor
local V3, CF = Vector3.new, CFrame.new
local M = Enum.Material
local function rr(a, b) return rng:NextNumber(a, b) end
local function at(x, y, z, ry) return CF(x, G + y, z) * CFrame.Angles(0, rad(ry or 0), 0) end

local C = {
	marble = Color3.fromRGB(238, 234, 224), marble2 = Color3.fromRGB(206, 206, 214), marbleDark = Color3.fromRGB(150, 150, 164),
	gold = Color3.fromRGB(205, 168, 86), silver = Color3.fromRGB(188, 194, 208),
	water = Color3.fromRGB(22, 64, 138), grass = Color3.fromRGB(74, 124, 60), leaf = Color3.fromRGB(60, 110, 56),
	blossom = Color3.fromRGB(236, 168, 200), dirt = Color3.fromRGB(96, 74, 58),
	rock = Color3.fromRGB(104, 100, 112), rockDark = Color3.fromRGB(64, 60, 76), moss = Color3.fromRGB(72, 112, 60),
	violet = Color3.fromRGB(146, 96, 226), purple = Color3.fromRGB(52, 32, 86), deepBlue = Color3.fromRGB(34, 44, 98),
	cyan = Color3.fromRGB(96, 222, 240), warm = Color3.fromRGB(255, 206, 120), wood = Color3.fromRGB(86, 58, 46),
	roof = Color3.fromRGB(46, 50, 112), rose = Color3.fromRGB(214, 90, 130), white = Color3.new(1, 1, 1),
	blueSilver = Color3.fromRGB(110, 150, 255),
}
local NOC = { CanCollide = false, CanTouch = false, CanQuery = false }

------------------------------------------------------------------ INSPECT EXISTING PROJECT
print("[ECHObOUND] Inspecting existing Workspace (nothing unrelated will be deleted):")
for _, c in ipairs(Workspace:GetChildren()) do print("   existing:", c.ClassName, c.Name) end

local FOLDER_NAMES = { "FloatingIsland", "FloatingCliffs", "WaterfallsAndPools", "OuterBridges", "RoyalCastle_LastArcana",
	"GiantSacredMonsterCard", "CentralPlaza", "CardMasterStatue", "MonsterCardGallery", "TournamentArena_1v1",
	"TournamentArena_2v2", "TournamentArena_3v3", "TournamentArena_4v4", "Leaderboard_West", "Leaderboard_East",
	"SpawnEntrance", "GardensAndLandscaping", "LightingAndEffects" }
local F = {}
for _, n in ipairs(FOLDER_NAMES) do
	local old = Workspace:FindFirstChild(n)
	if old and old:IsA("Folder") then old:Destroy() end -- only our own folders are rebuilt
	local f = Instance.new("Folder"); f.Name = n; f.Parent = Workspace; F[n] = f
end

local bp = Workspace:FindFirstChild("Baseplate")
if bp and bp:IsA("BasePart") and CFG.HideBaseplate then
	bp:SetAttribute("ECHO_OriginalTransparency", bp.Transparency)
	bp.Transparency = 1 -- reversible: island must not look connected to ground
	print("[ECHObOUND] Baseplate made invisible (original value stored in attribute).")
end

------------------------------------------------------------------ HELPERS
local function part(parent, name, size, cf, color, mat, opts)
	local p = Instance.new((opts and opts.Class) or "Part")
	p.Name = name; p.Anchored = true; p.Size = size; p.CFrame = cf
	p.Color = color; p.Material = mat or M.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth; p.BottomSurface = Enum.SurfaceType.Smooth
	if opts then for k, v in pairs(opts) do if k ~= "Class" then p[k] = v end end end
	p.Parent = parent
	return p
end
local function cyl(parent, name, d, h, cf, color, mat, opts) -- vertical cylinder, centre at cf
	local p = part(parent, name, V3(h, d, d), cf * CFrame.Angles(0, 0, pi / 2), color, mat, opts)
	p.Shape = Enum.PartType.Cylinder; return p
end
local function cylZ(parent, name, d, h, cf, color, mat, opts) -- cylinder whose axis is local Z
	local p = part(parent, name, V3(h, d, d), cf * CFrame.Angles(0, pi / 2, 0), color, mat, opts)
	p.Shape = Enum.PartType.Cylinder; return p
end
local function ball(parent, name, d, cf, color, mat, opts)
	local p = part(parent, name, V3(d, d, d), cf, color, mat, opts)
	p.Shape = Enum.PartType.Ball; return p
end
local function ell(parent, name, size, cf, color, mat, opts) -- ellipsoid
	local p = part(parent, name, size, cf, color, mat, opts)
	local sm = Instance.new("SpecialMesh"); sm.MeshType = Enum.MeshType.Sphere; sm.Parent = p; return p
end
local function model(parent, name)
	local m = Instance.new("Model"); m.Name = name; m.Parent = parent; return m
end
local function label(p, face, text, color, ppu)
	local sg = Instance.new("SurfaceGui"); sg.Face = face
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud; sg.PixelsPerStud = ppu or 50; sg.Parent = p
	local t = Instance.new("TextLabel"); t.Size = UDim2.fromScale(1, 1); t.BackgroundTransparency = 1
	t.Text = text; t.TextColor3 = color; t.TextScaled = true; t.Font = Enum.Font.GothamBold; t.Parent = sg
	return t
end

-- gothic pointed arch in local XY plane (span 2h, springline at baseCF origin)
local function arch(parent, baseCF, h, thick, depth, color, mat, n)
	n = n or 6
	local function seg(cx, sa, ea)
		for i = 0, n - 1 do
			local a1 = sa + (ea - sa) * i / n; local a2 = sa + (ea - sa) * (i + 1) / n
			local x1, y1 = cx + 2 * h * cos(a1), 2 * h * sin(a1)
			local x2, y2 = cx + 2 * h * cos(a2), 2 * h * sin(a2)
			local len = sqrt((x2 - x1) ^ 2 + (y2 - y1) ^ 2)
			part(parent, "ArchSeg", V3(len + 0.15, thick, depth),
				baseCF * CF((x1 + x2) / 2, (y1 + y2) / 2, 0) * CFrame.Angles(0, 0, math.atan2(y2 - y1, x2 - x1)), color, mat)
		end
	end
	seg(-h, 0, rad(60)); seg(h, rad(180), rad(120))
end

local emitters = 0
local function emitter(parent, pos, size, rate, c1, c2, speed, life, tex)
	local p = part(parent, "Emitter", size, CF(pos), C.white, M.SmoothPlastic, { Transparency = 1, CanCollide = false, CanTouch = false, CanQuery = false })
	local e = Instance.new("ParticleEmitter")
	e.Rate = rate; e.Lifetime = NumberRange.new(life * 0.7, life); e.Speed = NumberRange.new(speed * 0.5, speed)
	e.Color = ColorSequence.new(c1, c2)
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.3, tex and 5 or 0.4), NumberSequenceKeypoint.new(1, 0) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.2, tex and 0.75 or 0.3), NumberSequenceKeypoint.new(1, 1) })
	e.LightEmission = tex and 0 or 0.6; e.Acceleration = V3(0, tex and 0 or 0.5, 0)
	e.Shape = Enum.ParticleEmitterShape.Box; e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	if tex then e.Texture = "rbxasset://textures/particles/smoke_main.dds" end
	e.Parent = p; emitters += 1
	return p
end

local lanternCount = 0
local function lantern(parent, x, z, y)
	y = y or 0
	local m = model(parent, "Lantern")
	cyl(m, "Base", 1.3, 0.6, at(x, y + 0.3, z), C.marbleDark, M.Marble)
	cyl(m, "Pole", 0.45, 5, at(x, y + 3.1, z), C.silver, M.Metal)
	local head = part(m, "Glass", V3(1.1, 1.4, 1.1), at(x, y + 6.2, z), C.warm, M.Neon, { CanCollide = false, Transparency = 0.15 })
	cyl(m, "Cap", 1.7, 0.3, at(x, y + 7.1, z), C.gold, M.Metal)
	ball(m, "Finial", 0.5, at(x, y + 7.5, z), C.gold, M.Metal, NOC)
	lanternCount += 1
	if lanternCount % CFG.LightEvery == 0 then
		local l = Instance.new("PointLight"); l.Color = C.warm; l.Range = 14; l.Brightness = 1; l.Shadows = false; l.Parent = head
	end
	return m
end

local function banner(parent, cf, color, h)
	h = h or 7
	local m = model(parent, "Banner")
	part(m, "Pole", V3(3.6, 0.3, 0.3), cf * CF(0, h / 2 + 0.2, 0), C.gold, M.Metal, NOC)
	part(m, "Cloth", V3(2.8, h, 0.15), cf * CF(0, 0, 0.1), color, M.Fabric, NOC)
	part(m, "TrimL", V3(0.2, h, 0.2), cf * CF(-1.3, 0, 0.12), C.gold, M.Metal, NOC)
	part(m, "TrimR", V3(0.2, h, 0.2), cf * CF(1.3, 0, 0.12), C.gold, M.Metal, NOC)
	ell(m, "Emblem", V3(1.2, 1.6, 0.2), cf * CF(0, h / 4, 0.22), C.gold, M.Metal, NOC)
	ball(m, "Gem", 0.5, cf * CF(0, h / 4, 0.35), C.cyan, M.Neon, NOC)
	part(m, "Tail", V3(2.8, 0.2, 0.2), cf * CF(0, -h / 2, 0.1), C.gold, M.Metal, NOC)
	return m
end

local PATHS = {}
local function distSeg(px, pz, s)
	local ax, az, bx, bz = s[1], s[2], s[3], s[4]
	local dx, dz = bx - ax, bz - az
	local t = math.clamp(((px - ax) * dx + (pz - az) * dz) / (dx * dx + dz * dz), 0, 1)
	return sqrt((px - (ax + t * dx)) ^ 2 + (pz - (az + t * dz)) ^ 2)
end
local function path(parent, ax, az, bx, bz, w)
	PATHS[#PATHS + 1] = { ax, az, bx, bz }
	local len = sqrt((bx - ax) ^ 2 + (bz - az) ^ 2)
	local cf = CF(V3((ax + bx) / 2, G, (az + bz) / 2), V3(bx, G, bz))
	part(parent, "Path", V3(w, 0.6, len), cf * CF(0, 0.3, 0), C.marble2, M.Cobblestone)
	for _, s in ipairs({ -1, 1 }) do
		part(parent, "PathInlay", V3(0.25, 0.04, len), cf * CF(s * (w / 2 - 0.35), 0.62, 0), C.gold, M.Metal, NOC)
		part(parent, "PathCurb", V3(0.5, 0.7, len), cf * CF(s * (w / 2 + 0.2), 0.35, 0), C.marbleDark, M.Marble)
	end
end

local function bridge(parent, cx, cz, dx, dz, len, w, top, name)
	local m = model(parent, name or "Bridge")
	local base = CF(V3(cx, G + top, cz), V3(cx + dx, G + top, cz + dz))
	part(m, "Deck", V3(w, 0.6, len), base * CF(0, -0.3, 0), C.marble, M.Marble)
	part(m, "Walkway", V3(w - 1.8, 0.08, len - 0.6), base * CF(0, 0.04, 0), C.wood, M.WoodPlanks, NOC)
	part(m, "Underarch", V3(w - 1.2, 1.2, len * 0.7), base * CF(0, -1.2, 0), C.marble2, M.Marble)
	for _, s in ipairs({ -1, 1 }) do
		local ox = s * (w / 2 - 0.3)
		part(m, "HandRail", V3(0.4, 0.4, len), base * CF(ox, 2.5, 0), C.gold, M.Metal, { CanCollide = false })
		part(m, "LowRail", V3(0.25, 0.25, len), base * CF(ox, 1.4, 0), C.silver, M.Metal, { CanCollide = false })
		local n = math.max(2, floor(len / 2.5))
		for i = 0, n do cyl(m, "Baluster", 0.45, 2.4, base * CF(ox, 1.2, -len / 2 + len * i / n), C.marble, M.Marble, { CanCollide = false }) end
		for _, e in ipairs({ -1, 1 }) do
			cyl(m, "EndPillar", 1.2, 4.4, base * CF(ox, 2.2, e * len / 2), C.marble, M.Marble)
			ball(m, "Finial", 1.0, base * CF(ox, 4.7, e * len / 2), C.gold, M.Metal, NOC)
		end
	end
	return m
end

local function tree(parent, x, z, s)
	s = s or 1
	local m = model(parent, "Tree")
	cyl(m, "Trunk", 1.4 * s, 7 * s, at(x, 3.5 * s, z), C.wood, M.Wood)
	local col = (rng:NextNumber() < 0.3) and C.blossom or C.leaf:Lerp(C.grass, rr(0, 1))
	ball(m, "Crown", 9 * s, at(x, 9.5 * s, z), col, M.Grass, { CanCollide = false })
	ball(m, "CrownB", 6.5 * s, at(x + 2.6 * s, 7.8 * s, z + 1 * s), col, M.Grass, { CanCollide = false })
	ball(m, "CrownC", 6 * s, at(x - 2.4 * s, 8 * s, z - 1.4 * s), col, M.Grass, { CanCollide = false })
	return m
end

------------------------------------------------------------------ 1. FLOATING ISLAND
local R = 112
do
	local P, K = F.FloatingIsland, F.FloatingCliffs
	cyl(P, "IslandTop", 2 * R, 6, at(0, -3, 0), C.grass, M.Grass)
	cyl(P, "StoneRim", 2 * R + 1, 1.6, at(0, -5.2, 0), C.marbleDark, M.Slate)
	cyl(P, "DirtLayer", 2 * R, 8, at(0, -10, 0), C.dirt, M.Ground)

	local BUMPS = { 20, 45, 135, 160, 225, 250, 270, 290, 315 } -- irregular coastline (symmetric, avoids bridges/waterfalls)
	for i, deg in ipairs(BUMPS) do
		local a = rad(deg); local r = R - 10 + rr(0, 6); local d = rr(26, 36)
		local x, z = cos(a) * r, sin(a) * r
		cyl(P, "Bump" .. i, d, 5.9, at(x, -3, z), C.grass, M.Grass)
		cyl(P, "BumpDirt" .. i, d * 0.92, 8, at(x, -9.95, z), C.dirt, M.Ground)
		cyl(K, "BumpRock" .. i, d * 0.6, 18, at(x, -18, z), C.rock, M.Rock)
	end

	local noRock = { 69, 111, 339, 201 } -- waterfall angles
	for i = 1, 48 do
		local deg = rr(0, 360); local ok = true
		for _, w in ipairs(noRock) do if abs(deg - w) < 10 then ok = false end end
		if ok then
			local a = rad(deg)
			part(K, "EdgeRock", V3(rr(3, 7), rr(3, 6), rr(3, 7)),
				at(cos(a) * (R + 0.5), -4.5 + rr(-1, 1), sin(a) * (R + 0.5)) * CFrame.Angles(rr(-0.4, 0.4), rr(0, pi), rr(-0.4, 0.4)),
				C.rock:Lerp(C.rockDark, rr(0, 1)), M.Rock)
		end
	end

	-- layered rocky underside
	local layers = { { 206, 10 }, { 186, 12 }, { 162, 14 }, { 136, 16 }, { 110, 18 }, { 84, 18 }, { 58, 16 }, { 34, 14 }, { 16, 12 } }
	local y = -14
	local body = {}
	for i, l in ipairs(layers) do
		local d, h = l[1], l[2]
		local ox, oz = rr(-3, 3), rr(-3, 3)
		local even = i % 2 == 0
		cyl(K, "Layer" .. i, d, h, at(ox, y - h / 2, oz), even and C.rock or C.rockDark, even and M.Slate or M.Basalt)
		body[#body + 1] = { top = y, bot = y - h, r = d / 2 }
		for k = 1, math.max(4, floor(d / 12)) do -- protruding rock masses
			local a = rr(0, 2 * pi); local rd = d / 2 * rr(0.85, 1.02)
			local sx, sy, sz = rr(5, 12), h * rr(0.8, 1.3), rr(5, 12)
			part(K, "Rock", V3(sx, sy, sz), at(ox + cos(a) * rd, y - h / 2, oz + sin(a) * rd) * CFrame.Angles(rr(-0.3, 0.3), rr(0, pi), rr(-0.3, 0.3)),
				C.rock:Lerp(C.rockDark, rr(0, 1)), M.Rock)
		end
		for k = 1, 3 do
			local a = rr(0, 2 * pi); local rd = d / 2
			local px, pz = ox + cos(a) * rd, oz + sin(a) * rd
			local face = CFrame.lookAt(V3(px, G + y - h / 2, pz), V3(px + cos(a), G + y - h / 2, pz + sin(a)))
			part(K, "MossPatch", V3(rr(3, 7), rr(2, 5), 0.4), face * CF(0, rr(-1, 2), -0.1), C.moss, M.Grass, NOC)
			part(K, "Crack", V3(0.5, h * 0.9, 0.3), face * CF(rr(-3, 3), 0, -0.1), C.rockDark:Lerp(Color3.new(0, 0, 0), 0.5), M.Slate, NOC)
			local lx, lz = ox + cos(a + 0.3) * (rd + 2), oz + sin(a + 0.3) * (rd + 2) -- ledge slab with moss
			local ledge = part(K, "Ledge", V3(rr(8, 14), 1.2, rr(4, 7)), at(lx, y - h * 0.6, lz) * CFrame.Angles(0, -a, 0), C.rock, M.Rock)
			part(K, "LedgeMoss", V3(ledge.Size.X * 0.9, 0.3, ledge.Size.Z * 0.9), ledge.CFrame * CF(0, 0.7, 0), C.moss, M.Grass, NOC)
			local vx, vz = ox + cos(a + 1) * (rd - 1), oz + sin(a + 1) * (rd - 1)
			part(K, "Vine", V3(0.4, rr(4, 9), 0.4), at(vx, y - h - 2, vz), C.leaf, M.Grass, NOC)
		end
		y = y - h
	end
	local function bodyRadius(yy)
		for _, b in ipairs(body) do if yy <= b.top and yy >= b.bot then return b.r end end
		return 0
	end
	-- small floating rock fragments beneath the island
	for i = 1, 16 do
		local fy = -rr(45, 190)
		local br = bodyRadius(fy); if br == 0 then br = 20 end
		local a = rr(0, 2 * pi); local rd = br + rr(14, 48)
		local fx, fz = cos(a) * rd, sin(a) * rd
		local m = model(K, "FloatingFragment")
		local s = rr(5, 13)
		part(m, "Main", V3(s, s * 0.8, s * 1.1), at(fx, fy, fz) * CFrame.Angles(rr(-.4, .4), rr(0, pi), rr(-.4, .4)), C.rock:Lerp(C.rockDark, rr(0, 1)), M.Rock)
		part(m, "Under", V3(s * 0.6, s * 0.9, s * 0.6), at(fx + rr(-1, 1), fy - s * 0.7, fz + rr(-1, 1)) * CFrame.Angles(rr(-.5, .5), rr(0, pi), rr(-.5, .5)), C.rockDark, M.Rock)
		part(m, "Tip", V3(s * 0.3, s * 0.7, s * 0.3), at(fx, fy - s * 1.3, fz) * CFrame.Angles(0, rr(0, pi), 0), C.rockDark, M.Rock)
		part(m, "Moss", V3(s * 0.8, 0.5, s * 0.9), at(fx, fy + s * 0.42, fz), C.moss, M.Grass, NOC)
	end
end

------------------------------------------------------------------ LAYOUT DATA
local ARENAS = {
	{ id = "A1", x = -70, z = 48, chairs = 2, tr = 2.4, color = C.cyan, folder = "TournamentArena_1v1", sign = "A1 · 1v1" },
	{ id = "A2", x = -70, z = -28, chairs = 4, tr = 3.0, color = C.violet, folder = "TournamentArena_2v2", sign = "A2 · 2v2" },
	{ id = "A3", x = 70, z = -28, chairs = 6, tr = 3.6, color = C.warm, folder = "TournamentArena_3v3", sign = "A3 · 3v3" },
	{ id = "A4", x = 70, z = 48, chairs = 8, tr = 4.0, color = C.blueSilver, folder = "TournamentArena_4v4", sign = "A4 · 4v4" },
}
local POOLS = { { -40, -58, 7 }, { 40, -58, 7 }, { -24, 72, 6 }, { 24, 72, 6 }, { -98, -37, 5 }, { 98, -37, 5 } }

------------------------------------------------------------------ 6. WATER: POOLS, CHANNELS, WATERFALLS
do
	local P = F.WaterfallsAndPools
	local function pool(x, z, r, fountain)
		local m = model(P, "Pool")
		cyl(m, "Base", 2 * r + 3, 0.6, at(x, 0.3, z), C.marble2, M.Marble)
		cyl(m, "Water", 2 * r + 0.2, 0.3, at(x, 0.8, z), C.water, M.Glass, { CanCollide = false, Transparency = 0.12, Reflectance = 0.1 })
		local n = math.max(12, floor(r * 3))
		for i = 0, n - 1 do
			local a = 2 * pi * i / n; local rx = r + 1.1
			part(m, "RimStone", V3(2 * pi * rx / n + 0.2, 1.3, 1.4), CF(x + cos(a) * rx, G + 1.25, z + sin(a) * rx) * CFrame.Angles(0, -a - pi / 2, 0), C.marble, M.Marble)
		end
		if fountain then
			cyl(m, "FountainColumn", 1.4, 3, at(x, 2.1, z), C.marble, M.Marble)
			cyl(m, "FountainBowl", 4, 0.5, at(x, 3.7, z), C.gold, M.Metal)
			cyl(m, "FountainWater", 3.4, 0.2, at(x, 4.0, z), C.water, M.Glass, { CanCollide = false, Transparency = 0.2 })
			emitter(m, V3(x, G + 5, z), V3(0.6, 0.6, 0.6), 8, C.cyan, C.white, 3, 1.2)
		end
		return m
	end
	local function channel(x1, z1, x2, z2, w)
		local len = sqrt((x2 - x1) ^ 2 + (z2 - z1) ^ 2)
		local cf = CF(V3((x1 + x2) / 2, G, (z1 + z2) / 2), V3(x2, G, z2))
		part(P, "ChannelBed", V3(w + 3, 0.3, len), cf * CF(0, 0.15, 0), C.marble2, M.Marble)
		part(P, "ChannelWater", V3(w, 0.4, len), cf * CF(0, 0.5, 0), C.water, M.Glass, { CanCollide = false, Transparency = 0.1, Reflectance = 0.1 })
		for _, s in ipairs({ -1, 1 }) do
			part(P, "ChannelCurb", V3(1, 0.8, len), cf * CF(s * (w / 2 + 1), 0.4, 0), C.marble, M.Marble)
		end
	end
	local function waterfall(x, z, w, hgt)
		local len = sqrt(x * x + z * z); local ux, uz = x / len, z / len
		local m = model(P, "Waterfall")
		local face = CFrame.lookAt(V3(x, G, z), V3(x + ux, G, z + uz))
		part(m, "Gutter", V3(w + 1.6, 0.8, 4), face * CF(0, 0.4, -0.5), C.marble, M.Marble)
		part(m, "Corbel", V3(w, 2.6, 3), face * CF(0, -1.4, -0.6), C.rock, M.Rock)
		part(m, "Sheet", V3(w, hgt, 0.8), face * CF(0, 0.7 - hgt / 2, -2.6), C.water, M.Glass, { CanCollide = false, Transparency = 0.35 })
		for _, s in ipairs({ -1, 0, 1 }) do
			part(m, "Foam", V3(0.35, hgt * 0.9, 0.3), face * CF(s * w / 3.2, 0.7 - hgt * 0.47, -3.1), C.white, M.SmoothPlastic, { CanCollide = false, Transparency = 0.5 })
		end
		emitter(m, V3(x + ux * 4, G + 0.7 - hgt, z + uz * 4), V3(w, 2, 3), 5, C.white, C.marble2, 1.5, 3, true)
	end

	for _, s in ipairs({ -1, 1 }) do
		pool(s * 40, -58, 7, false)                -- channel heads by the castle
		pool(s * 24, 72, 6, true)                  -- decorative fountain pools by the spawn
		pool(s * 98, -37, 5, false)                -- feeds the edge waterfalls
		channel(s * 40, -50, s * 40, 100, 5)       -- long channel to the south edge
		channel(s * 30, 72, s * 38, 72, 3)         -- fountain pool feeder
		waterfall(s * 40, 103.5, 5, 95)
		local ex, ez = 98 + 7.2, -37 * 1.09
		waterfall(s * ex, ez, 5, 95)
	end
end

------------------------------------------------------------------ 2/6. CENTRAL PLAZA, AVENUE, PATHS, BRIDGES
do
	local P = F.CentralPlaza
	cyl(P, "StepRing", 70, 0.8, at(0, 0.4, 0), C.marble2, M.Marble)
	cyl(P, "PlazaBase", 66, 1.2, at(0, 0.6, 0), C.marble, M.Marble)
	local rings = { { 58, 56, 1.3 }, { 44, 43.5, 1.36 }, { 30, 29.5, 1.42 } }
	for _, r in ipairs(rings) do
		cyl(P, "GoldInlay", r[1], 0.1, at(0, r[3] - 0.05, 0), C.gold, M.Metal)
		cyl(P, "MarbleDisc", r[2], 0.12, at(0, r[3] - 0.04, 0), C.marble, M.Marble)
	end
	for i = 0, 7 do -- star-compass inlay lines
		part(P, "StarLine", V3(0.7, 0.05, 14), at(0, 1.46, 0, i * 45) * CF(0, 0, -21), (i % 2 == 0) and C.gold or C.silver, M.Metal, NOC)
	end
	for i = 0, 7 do -- benches
		local a = rad(22.5 + i * 45)
		local bx, bz = cos(a) * 36.5, sin(a) * 36.5
		local face = CFrame.lookAt(V3(bx, G + 0.8, bz), V3(0, G + 0.8, 0))
		part(P, "BenchSeat", V3(5, 0.4, 1.6), face * CF(0, 0.9, 0), C.wood, M.Wood)
		part(P, "BenchBack", V3(5, 1.1, 0.3), face * CF(0, 1.7, 0.7), C.wood, M.Wood)
		for _, sx in ipairs({ -2.2, 2.2 }) do part(P, "BenchLeg", V3(0.5, 0.9, 1.4), face * CF(sx, 0.45, 0), C.marble, M.Marble) end
		lantern(P, cos(a + rad(22.5)) * 34, sin(a + rad(22.5)) * 34, 0.8)
	end
	for _, s in ipairs({ -1, 1 }) do for _, z in ipairs({ 35, -35 }) do end end

	-- main avenue (south spawn -> statue -> north castle)
	local A = F.CentralPlaza
	local function avenue(z1, z2)
		local len = abs(z2 - z1); local cz = (z1 + z2) / 2
		part(A, "AvenueFloor", V3(14, 0.6, len), at(0, 0.3, cz), C.marble, M.Marble)
		for _, s in ipairs({ -1, 1 }) do
			part(A, "AvenueGold", V3(0.3, 0.04, len), at(s * 6.2, 0.62, cz), C.gold, M.Metal, NOC)
			part(A, "AvenueCurb", V3(0.7, 0.8, len), at(s * 7.3, 0.4, cz), C.marbleDark, M.Marble)
		end
		for z = math.min(z1, z2) + 3, math.max(z1, z2) - 1, 6 do
			part(A, "AvenueSeam", V3(13, 0.04, 0.2), at(0, 0.62, z), C.marble2, M.Marble, NOC)
		end
	end
	avenue(34, 92); avenue(-34, -62)
	PATHS[#PATHS + 1] = { 0, 34, 0, 92 }; PATHS[#PATHS + 1] = { 0, -34, 0, -62 }
	for _, z in ipairs({ 42, 54, 66, 78 }) do
		lantern(A, -8.6, z); lantern(A, 8.6, z)
		if z % 24 == 6 then end
	end
	for _, z in ipairs({ -42, -52 }) do lantern(A, -8.6, z); lantern(A, 8.6, z) end
	for _, z in ipairs({ 48, 72 }) do for _, s in ipairs({ -1, 1 }) do banner(A, at(s * 8.6, 11, z, 90 * s), (s == 1) and C.purple or C.deepBlue, 6) end end

	-- castle entrance steps
	for i = 1, 4 do
		part(A, "CastleStep", V3(18 + i, 0.5 * i, 1.3), at(0, 0.25 * i, -62.6 - 1.3 * i + 0.6), C.marble, M.Marble)
	end

	-- secondary paths, bridges (over channels at x = +-40), walkways
	local OB = F.OuterBridges
	local function crossBridge(ax, az, bx, bz)
		for _, xc in ipairs({ -40, 40 }) do
			local t = (xc - ax) / (bx - ax)
			if t > 0 and t < 1 then
				local z = az + (bz - az) * t
				local dx, dz = bx - ax, bz - az; local l = sqrt(dx * dx + dz * dz)
				bridge(OB, xc, z, dx / l, dz / l, 13, 8.5, 1.0, "ChannelBridge")
			end
		end
	end
	for _, a in ipairs(ARENAS) do
		local l = sqrt(a.x * a.x + a.z * a.z); local ux, uz = a.x / l, a.z / l
		local sx, sz = ux * 32, uz * 32
		local ex, ez = a.x - ux * 28, a.z - uz * 28
		path(A, sx, sz, ex, ez, 7)
		crossBridge(sx, sz, ex, ez)
	end
	for _, s in ipairs({ -1, 1 }) do
		path(A, s * 32, 0, s * 106, 0, 7)          -- outer-bridge axis
		crossBridge(s * 32, 0, s * 106, 0)
		path(A, s * 52, 0, s * 88, 17, 5)           -- to leaderboard monument
		path(A, s * 70, -4, s * 70, 24, 4)         -- walkway linking neighbouring arenas
		for _, z in ipairs({ 4, 12, 20 }) do lantern(A, s * 74, z) end
	end
end

------------------------------------------------------------------ 4. CARD MASTER STATUE
do
	local P = F.CardMasterStatue
	local tiers = { { 30, 1.2, 2.4 }, { 24, 1.4, 3.8 }, { 18, 1.4, 5.2 }, { 12, 1.5, 6.7 } } -- dia, height, top
	for i, t in ipairs(tiers) do
		cyl(P, "Tier" .. i, t[1], t[2], at(0, t[3] - t[2] / 2, 0), (i % 2 == 1) and C.marble or C.marble2, M.Marble)
		cyl(P, "GoldBand" .. i, t[1] + 0.4, 0.3, at(0, t[3] - 0.15, 0), C.gold, M.Metal)
		cyl(P, "RuneInlay" .. i, t[1] - 2.2, 0.04, at(0, t[3] + 0.02, 0), (i % 2 == 1) and C.violet or C.cyan, M.Neon, { CanCollide = false, Transparency = 0.45 })
		cyl(P, "TopDisc" .. i, t[1] - 2.8, 0.06, at(0, t[3] + 0.03, 0), C.marble, M.Marble, NOC)
	end
	for i = 0, 23 do -- carved runes around tier 2
		local f = at(0, 3.1, 0, i * 15) * CF(0, 0, -12.05)
		part(P, "RuneBar", V3(0.22, 1.1, 0.12), f, C.cyan, M.Neon, { CanCollide = false, Transparency = 0.25 })
		part(P, "RuneDiag", V3(0.18, 0.7, 0.12), f * CF(0.3, 0.2, 0) * CFrame.Angles(0, 0, rad(35)), C.cyan, M.Neon, { CanCollide = false, Transparency = 0.25 })
		if i % 2 == 0 then part(P, "RuneDot", V3(0.25, 0.25, 0.12), f * CF(-0.3, -0.4, 0), C.violet, M.Neon, { CanCollide = false, Transparency = 0.25 }) end
	end
	for i = 0, 3 do -- silver star inlay on tier 3 top
		part(P, "TierStar", V3(0.5, 0.05, 15), at(0, 5.26, 0, i * 45), C.silver, M.Metal, NOC)
	end
	-- stairs on the south side (statue faces south) with railings
	for i, t in ipairs(tiers) do
		local prev = (i == 1) and 1.2 or tiers[i - 1][3]
		local r = t[1] / 2
		local midTop = (prev + t[3]) / 2
		part(P, "StairLip" .. i, V3(8, t[3] - 1.2, 1.2), at(0, (1.2 + t[3]) / 2, r + 0.6), C.marble, M.Marble)
		part(P, "StairStep" .. i, V3(8, midTop - 1.2, 1.2), at(0, (1.2 + midTop) / 2, r + 1.8), C.marble, M.Marble)
		for _, s in ipairs({ -1, 1 }) do
			for _, dz in ipairs({ 0.3, 2.1 }) do
				cyl(P, "RailPost", 0.5, 2.4, at(s * 4.4, t[3] + 1.0, r + dz), C.marble, M.Marble, { CanCollide = false })
				ball(P, "RailFinial", 0.6, at(s * 4.4, t[3] + 2.3, r + dz), C.gold, M.Metal, NOC)
			end
			part(P, "RailBar", V3(0.3, 0.3, 2.4), at(s * 4.4, t[3] + 1.9, r + 1.2), C.gold, M.Metal, { CanCollide = false })
		end
	end

	-- the statue itself: faces +Z (south). Local y is measured from the feet.
	local ST = model(P, "CardMasterStatue_Model")
	local Y0 = 6.7
	local function s(name, size, x, y, z, color, mat, rx, ry, rz, shape)
		local cf = at(x, Y0 + y, z) * CFrame.Angles(rad(rx or 0), rad(ry or 0), rad(rz or 0))
		local p = (shape == "ell") and ell(ST, name, size, cf, color, mat) or part(ST, name, size, cf, color, mat)
		return p
	end
	for _, sx in ipairs({ -1, 1 }) do s("Boot", V3(2.8, 1.4, 3), sx * 2, 0.7, 4.6, C.marble, M.Marble); s("BootTrim", V3(2.9, 0.3, 3.1), sx * 2, 1.4, 4.6, C.gold, M.Metal) end
	cyl(ST, "RobeLower", 11, 5, at(0, Y0 + 2.5, 0), C.marble, M.Marble)
	cyl(ST, "RobeHem", 11.3, 0.5, at(0, Y0 + 0.25, 0), C.gold, M.Metal)
	cyl(ST, "RobeMid", 9, 5, at(0, Y0 + 7.5, 0), C.marble2, M.Marble)
	cyl(ST, "RobeUpper", 7, 3, at(0, Y0 + 11.5, 0), C.marble, M.Marble)
	cyl(ST, "Belt", 7.4, 1, at(0, Y0 + 11, 0), C.gold, M.Metal)
	s("SashPanel", V3(2.4, 9, 0.3), 0, 6, 4.5, C.violet, M.SmoothPlastic)
	s("SashTrimL", V3(0.2, 9, 0.35), -1.3, 6, 4.5, C.gold, M.Metal); s("SashTrimR", V3(0.2, 9, 0.35), 1.3, 6, 4.5, C.gold, M.Metal)
	s("Buckle", V3(1.6, 1.6, 0.5), 0, 11, 3.8, C.gold, M.Metal, 0, 0, 45)
	ball(ST, "BuckleGem", 0.8, at(0, Y0 + 11, 4.1), C.cyan, M.Neon, NOC)
	s("Torso", V3(7.6, 8, 4.6), 0, 17, 0, C.marble, M.Marble)
	s("Shoulders", V3(11, 1.6, 5), 0, 21, 0, C.marble, M.Marble)
	s("ChestEmblem", V3(2.2, 2.2, 0.3), 0, 17.5, 2.4, C.gold, M.Metal, 0, 0, 45)
	ball(ST, "ChestGem", 0.9, at(0, Y0 + 17.5, 2.7), C.violet, M.Neon, NOC)
	for _, sx in ipairs({ -1, 1 }) do
		s("ShoulderPad", V3(3.4, 2.2, 3.6), sx * 5.2, 21.2, 0, C.silver, M.Metal, 0, 0, 0, "ell")
		ball(ST, "Clasp", 0.8, at(sx * 3, Y0 + 21, -2.6), C.gold, M.Metal, NOC)
	end
	cyl(ST, "Neck", 2.2, 1.6, at(0, Y0 + 22.6, 0), C.marble, M.Marble)
	ball(ST, "Head", 5.4, at(0, Y0 + 25.6, 0), C.marble, M.Marble)
	s("Hair", V3(6.2, 6, 6), 0, 26, -0.7, C.purple, M.SmoothPlastic, 0, 0, 0, "ell")
	for i = -2, 2 do s("Bangs", V3(1.4, 2.2, 0.8), i * 1.15, 27.4, 2.3, C.purple, M.SmoothPlastic, rr(-10, 10), 0, i * 8) end
	for _, sx in ipairs({ -1, 1 }) do
		s("HairLock", V3(1, 5, 1), sx * 3.2, 24, 0.5, C.purple, M.SmoothPlastic, 0, 0, sx * 6)
		s("Eye", V3(1, 0.55, 0.3), sx * 1.1, 25.7, 2.55, C.cyan, M.Neon, 0, 0, 0, "ell")
	end
	cylZ(ST, "HaloRing", 9, 0.35, at(0, Y0 + 26, -3.4), C.gold, M.Metal, NOC)
	cylZ(ST, "HaloGlow", 8.2, 0.1, at(0, Y0 + 26, -3.2), C.violet, M.Neon, { CanCollide = false, Transparency = 0.55 })
	s("Cape", V3(9.5, 15, 0.8), 0, 16.5, -3.2, C.marble2, M.Marble)
	for _, sx in ipairs({ -1, 1 }) do
		s("CapeFlare", V3(3, 13, 0.7), sx * 5.4, 15.5, -2.6, C.marble2, M.Marble, 0, -sx * 25, 0)
		s("CapeEdge", V3(0.4, 15, 0.9), sx * 4.9, 16.5, -3.2, C.gold, M.Metal)
	end
	-- statue's left (east) arm holds the monster encyclopedia
	s("LeftUpperArm", V3(1.9, 5.2, 1.9), 5.6, 17.8, 0.5, C.marble, M.Marble, 0, 0, 6)
	s("LeftCuff", V3(2.3, 0.6, 2.3), 5.8, 15.3, 0.7, C.gold, M.Metal)
	s("LeftForearm", V3(1.8, 1.8, 5), 5.8, 15.7, 3.2, C.marble, M.Marble)
	ball(ST, "LeftHand", 2, at(5.8, Y0 + 15.5, 6.2), C.marble, M.Marble)
	local bookCF = at(5.8, Y0 + 16.8, 6.4) * CFrame.Angles(rad(-18), 0, 0)
	part(ST, "BookCover", V3(5, 0.7, 6.6), bookCF, C.purple, M.Fabric)
	part(ST, "BookPages", V3(4.5, 0.55, 6), bookCF * CF(0, 0.6, 0), C.marble, M.SmoothPlastic)
	part(ST, "BookSpine", V3(0.7, 0.9, 6.6), bookCF * CF(-2.5, 0.1, 0), C.gold, M.Metal)
	for _, cx in ipairs({ -2.2, 2.2 }) do for _, cz in ipairs({ -3, 3 }) do part(ST, "BookCorner", V3(0.9, 0.2, 0.9), bookCF * CF(cx, 0.4, cz), C.gold, M.Metal, NOC) end end
	cyl(ST, "BookSigil", 3, 0.05, bookCF * CF(0, 3.2, 0), C.violet, M.Neon, { CanCollide = false, Transparency = 0.45 })
	-- raised right (west) arm summoning floating cards
	s("RightUpperArm", V3(1.9, 5.5, 1.9), -7.0, 22.75, 0.5, C.marble, M.Marble, 0, 0, 35)
	s("RightForearm", V3(1.7, 5, 1.7), -9.25, 27.4, 0.5, C.marble, M.Marble, 0, 0, 15)
	s("RightCuff", V3(2.1, 0.6, 2.1), -9.8, 29.6, 0.5, C.gold, M.Metal, 0, 0, 15)
	ball(ST, "RightHand", 2.2, at(-10.0, Y0 + 30.6, 0.5), C.marble, M.Marble)
	local hx, hz = -10, 0.5
	local accents = { C.violet, C.cyan, C.warm }
	for i = 1, 7 do
		local a = i * 0.95 + 0.5; local r = 3.2 + 0.25 * i
		local pos = V3(hx + cos(a) * r, G + Y0 + 33.5 + i * 1.35, hz + sin(a) * r)
		local cm = model(ST, "FloatingCard")
		local cf = CFrame.lookAt(pos, V3(hx, pos.Y + 0.6, hz))
		part(cm, "Border", V3(2.6, 3.6, 0.1), cf, C.gold, M.Metal, NOC)
		part(cm, "Face", V3(2.2, 3.2, 0.14), cf, C.purple:Lerp(accents[(i - 1) % 3 + 1], 0.35), M.SmoothPlastic, NOC)
		ell(cm, "Art", V3(0.9, 1.2, 0.16), cf * CF(0, 0.2, 0), accents[(i - 1) % 3 + 1], M.Neon, { CanCollide = false, Transparency = 0.3 })
	end
	cyl(ST, "SummonRing", 9, 0.04, at(hx, Y0 + 36, hz), C.violet, M.Neon, { CanCollide = false, Transparency = 0.6 })
	emitter(ST, V3(hx, G + Y0 + 38, hz), V3(7, 10, 7), 5, C.violet, C.cyan, 2, 3)
	emitter(ST, V3(0, G + 8, 0), V3(20, 2, 20), 4, C.cyan, C.warm, 2, 4)
end

------------------------------------------------------------------ 3. THE LAST ARCANA CASTLE
local lotteryMachines = {}
do
	local P = F.RoyalCastle_LastArcana
	local fx = -71 -- front wall z
	-- terrace
	part(P, "Terrace", V3(76, 2, 38), at(0, 1, -85), C.marble, M.Marble)
	part(P, "TerraceTrim", V3(76.6, 0.4, 38.6), at(0, 1.9, -85), C.gold, M.Metal, NOC)
	for _, s in ipairs({ -1, 1 }) do -- front balustrades
		part(P, "TerraceRail", V3(20, 0.4, 0.4), at(s * 28, 3.4, -66.4), C.gold, M.Metal, { CanCollide = false })
		for i = 0, 6 do cyl(P, "TerraceBaluster", 0.5, 1.6, at(s * (19 + i * 3), 2.8, -66.4), C.marble, M.Marble, { CanCollide = false }) end
		part(P, "TerraceRailSide", V3(0.4, 0.4, 30), at(s * 37.8, 3.4, -85), C.gold, M.Metal, { CanCollide = false })
	end
	-- walls (outer x +-26, z -100..-70, y 2..32)
	part(P, "WallBack", V3(52, 30, 2), at(0, 17, -99), C.marble, M.Marble)
	for _, s in ipairs({ -1, 1 }) do
		part(P, "WallSide", V3(2, 30, 26), at(s * 25, 17, -85), C.marble, M.Marble)
		part(P, "WallFront", V3(20, 30, 2), at(s * 16, 17, fx), C.marble, M.Marble)
	end
	-- gothic doorway (stepped opening matched by a pointed arch frame)
	do
		local h, apex, bands = 6, 6 * sqrt(3), 8
		for i = 1, bands do
			local y1, y2 = apex * (i - 1) / bands, apex * i / bands; local ym = (y1 + y2) / 2
			local w = sqrt(4 * h * h - ym * ym) - h; local fw = h - w
			if fw > 0.05 then for _, s in ipairs({ -1, 1 }) do
				part(P, "DoorSpandrel", V3(fw, y2 - y1, 2), at(s * (w + fw / 2), 10 + ym, fx), C.marble, M.Marble)
			end end
		end
		part(P, "DoorHead", V3(12, 32 - (10 + apex), 2), at(0, (10 + apex + 32) / 2, fx), C.marble, M.Marble)
		arch(P, at(0, 10, -70.2), 6.3, 1.3, 1.4, C.marble2, M.Marble, 8)
		arch(P, at(0, 10, -69.9), 6.9, 0.35, 1.7, C.gold, M.Metal, 8)
		arch(P, at(0, 10, -71.9), 6.3, 1.3, 1.4, C.marble2, M.Marble, 8)
	end
	-- carved pillars flanking the entrance + buttresses
	for _, s in ipairs({ -1, 1 }) do
		local x = s * 9.8
		cyl(P, "EntrancePillar", 2.4, 20, at(x, 12, -68.6), C.marble, M.Marble)
		cyl(P, "PillarBase", 3.4, 1, at(x, 2.5, -68.6), C.marble2, M.Marble)
		cyl(P, "PillarCapital", 3.4, 1.2, at(x, 22.6, -68.6), C.gold, M.Metal)
		for i = 0, 5 do cyl(P, "PillarFlute", 0.3, 18, at(x + cos(i * pi / 3) * 1.25, 12, -68.6 + sin(i * pi / 3) * 1.25), C.marble2, M.Marble, NOC) end
		cyl(P, "PillarBand", 2.7, 0.5, at(x, 8, -68.6), C.gold, M.Metal)
		cyl(P, "PillarBand", 2.7, 0.5, at(x, 16, -68.6), C.gold, M.Metal)
		for _, z in ipairs({ -78, -85, -92 }) do
			cyl(P, "Buttress", 2.2, 28, at(s * 27.2, 16, z), C.marble2, M.Marble)
			cyl(P, "ButtressCap", 2.8, 0.8, at(s * 27.2, 30.4, z), C.gold, M.Metal)
		end
		for _, bx in ipairs({ 10, 20 }) do cyl(P, "Buttress", 2.2, 28, at(s * bx, 16, -100.6), C.marble2, M.Marble) end
		-- front balconies
		local bf = at(s * 16, 9, -68.6)
		part(P, "Balcony", V3(8, 0.6, 3), bf, C.marble, M.Marble)
		part(P, "BalconyRail", V3(8, 0.3, 0.3), bf * CF(0, 2.2, 1.3), C.gold, M.Metal, { CanCollide = false })
		for i = -3, 3 do cyl(P, "BalconyBaluster", 0.4, 2, bf * CF(i * 1.25, 1.2, 1.3), C.marble, M.Marble, { CanCollide = false }) end
		for _, cx in ipairs({ -3, 3 }) do part(P, "Corbel", V3(1, 1.4, 2), bf * CF(cx, -1, -0.4), C.marble2, M.Marble) end
	end
	-- stained glass windows
	local glassCols = { C.violet, C.cyan, C.warm, C.rose, C.blueSilver }
	local function window(cf, w, h, withArch)
		part(P, "WindowFrame", V3(w + 1, h + 1, 0.5), cf * CF(0, 0, 0), C.gold, M.Metal, NOC)
		local rows, cols = 3, 2
		for r = 0, rows - 1 do for c = 0, cols - 1 do
			part(P, "StainedGlass", V3(w / cols - 0.25, h / rows - 0.25, 0.3), cf * CF(-w / 2 + (c + 0.5) * w / cols, -h / 2 + (r + 0.5) * h / rows, 0.2),
				glassCols[(r * cols + c) % #glassCols + 1], M.Glass, { CanCollide = false, Transparency = 0.2 })
		end end
		if withArch then arch(P, cf * CF(0, h / 2, 0), w / 2 + 0.3, 0.7, 0.9, C.marble2, M.Marble, 5) end
	end
	for _, s in ipairs({ -1, 1 }) do
		window(at(s * 16, 16, -70, 0) * CF(0, 0, -0.9) * CFrame.Angles(0, pi, 0), 4.4, 11, true)
		window(at(s * 16, 16, -71.6, 0), 4.4, 11, false)
		for _, z in ipairs({ -78, -85, -92 }) do
			window(at(s * 26.2, 17, z, 90 * s) * CFrame.Angles(0, 0, 0), 3.6, 12, true)
			window(at(s * 23.9, 17, z, -90 * s), 3.6, 12, false)
		end
	end
	-- floor, carpet, pillars, ceiling
	part(P, "HallFloor", V3(48, 0.4, 26), at(0, 2.2, -85), C.marble, M.Marble, { Reflectance = 0.15 })
	for i = -3, 3 do part(P, "FloorTile", V3(0.15, 0.05, 26), at(i * 6, 2.42, -85), C.marble2, M.Marble, NOC) end
	part(P, "Carpet", V3(8, 0.06, 26), at(0, 2.43, -85), C.purple, M.Fabric, NOC)
	for _, s in ipairs({ -1, 1 }) do part(P, "CarpetGold", V3(0.4, 0.07, 26), at(s * 4.2, 2.44, -85), C.gold, M.Metal, NOC) end
	for _, s in ipairs({ -1, 1 }) do for _, z in ipairs({ -76, -85, -94 }) do
		cyl(P, "HallPillar", 2.6, 29.6, at(s * 16, 17.2, z), C.marble, M.Marble)
		cyl(P, "HallPillarBase", 3.8, 0.8, at(s * 16, 2.8, z), C.marble2, M.Marble)
		cyl(P, "HallPillarCap", 3.8, 0.8, at(s * 16, 31.6, z), C.gold, M.Metal)
		cyl(P, "HallPillarBand", 2.9, 0.4, at(s * 16, 12, z), C.gold, M.Metal)
	end end
	part(P, "RoofSlab", V3(54, 2, 32), at(0, 33, -85), C.roof, M.Slate)
	for i = 0, 12 do for _, z in ipairs({ -69.8, -100.2 }) do part(P, "Crenel", V3(2, 2, 1.4), at(-24 + i * 4, 35, z), C.marble, M.Marble) end end
	for i = 0, 6 do for _, s in ipairs({ -1, 1 }) do part(P, "Crenel", V3(1.4, 2, 2), at(s * 26.2, 35, -73 - i * 4), C.marble, M.Marble) end end
	local rl = { { 46, 24 }, { 38, 18 }, { 30, 12 }, { 20, 7 } }
	for i, r in ipairs(rl) do
		part(P, "HipRoof" .. i, V3(r[1], 4, r[2]), at(0, 34 + 2 + (i - 1) * 4, -85), C.roof, M.Slate)
		part(P, "HipTrim" .. i, V3(r[1] + 0.4, 0.4, r[2] + 0.4), at(0, 34 + (i - 1) * 4 + 0.2, -85), C.gold, M.Metal, NOC)
	end
	part(P, "RoofRidge", V3(14, 1, 3), at(0, 51, -85), C.gold, M.Metal)

	-- grand entrance pediment (front gable that carries the giant card)
	part(P, "Pediment", V3(26, 18, 2), at(0, 39, fx), C.marble, M.Marble)
	for i, st in ipairs({ { 20, 4 }, { 14, 4 }, { 8, 4 } }) do
		part(P, "Gable" .. i, V3(st[1], st[2], 2), at(0, 50 + (i - 1) * 4, fx), C.marble, M.Marble)
		part(P, "GableGold" .. i, V3(st[1] + 0.4, 0.35, 2.2), at(0, 48 + (i - 1) * 4, fx), C.gold, M.Metal, NOC)
	end
	cyl(P, "SpireFinial", 0.8, 6, at(0, 63, fx), C.gold, M.Metal)
	ball(P, "SpireGem", 1.6, at(0, 66.4, fx), C.cyan, M.Neon, NOC)

	-- towers with pointed roofs
	local function tower(x, z, r, h)
		local m = model(P, "Tower")
		cyl(m, "Shaft", 2 * r, h, at(x, h / 2, z), C.marble, M.Marble)
		for _, ty in ipairs({ 0.25, 0.55, 0.8 }) do cyl(m, "GoldBand", 2 * r + 0.6, 0.6, at(x, h * ty, z), C.gold, M.Metal) end
		cyl(m, "Collar", 2 * r + 1.8, 1.5, at(x, h + 0.75, z), C.marble2, M.Marble)
		local n, base = 8, 2 * r + 2.2
		for i = 1, n do
			cyl(m, "RoofLayer", base * (1 - (i - 1) / n), 3, at(x, h + 1.5 + (i - 0.5) * 3, z), (i % 3 == 0) and C.gold or C.roof, (i % 3 == 0) and M.Metal or M.Slate)
		end
		cyl(m, "Spire", 0.5, 5, at(x, h + 1.5 + n * 3 + 2.5, z), C.gold, M.Metal)
		ball(m, "SpireOrb", 1.1, at(x, h + 1.5 + n * 3 + 5.4, z), C.violet, M.Neon, NOC)
		for _, ty in ipairs({ 0.4, 0.7 }) do for k = 0, 3 do
			local a = k * pi / 2 + pi / 4
			local px, pz = x + cos(a) * (r + 0.1), z + sin(a) * (r + 0.1)
			local f = CFrame.lookAt(V3(px, G + h * ty, pz), V3(px + cos(a), G + h * ty, pz + sin(a)))
			part(m, "SlitFrame", V3(1.8, 4.2, 0.3), f, C.gold, M.Metal, NOC)
			part(m, "SlitGlass", V3(1.2, 3.6, 0.3), f * CF(0, 0, -0.15), (k % 2 == 0) and C.cyan or C.warm, M.Glass, { CanCollide = false, Transparency = 0.2 })
		end end
	end
	tower(-26, -73, 6.5, 42); tower(26, -73, 6.5, 42)
	tower(-27, -98, 6, 40); tower(27, -98, 6, 40)
	tower(0, -100, 7.5, 54)
	for _, s in ipairs({ -1, 1 }) do
		banner(P, at(s * 17, 25, -69.6, 0), C.purple, 8)
		banner(P, at(s * 5.4, 15, -68.6, 0), C.deepBlue, 7)
		banner(P, at(s * 26, 28, -66.3, 0), C.purple, 8)
	end

	-- INTERIOR: balconies (stairs on both side walls + upper gallery balcony across the back)
	part(P, "UpperBalcony", V3(48, 0.8, 8), at(0, 15.6, -94), C.marble, M.Marble)
	part(P, "UpperBalconyTrim", V3(48, 0.3, 0.4), at(0, 15.2, -89.9), C.gold, M.Metal, NOC)
	part(P, "BalconyRailTop", V3(40, 0.3, 0.3), at(0, 18.3, -90.2), C.gold, M.Metal, { CanCollide = false })
	for i = -9, 9 do cyl(P, "UpperBaluster", 0.4, 2.2, at(i * 2.2, 17.1, -90.2), C.marble, M.Marble, { CanCollide = false }) end
	for _, s in ipairs({ -1, 1 }) do
		for i = 1, 20 do
			part(P, "GrandStair", V3(3, 0.68 * i, 0.9), at(s * 22.5, 2.4 + 0.34 * i, -73 - 0.9 * (i - 0.5)), C.marble, M.Marble)
		end
		local a, b = V3(s * 21, G + 5.5, -73), V3(s * 21, G + 18.6, -91)
		local len = (b - a).Magnitude
		part(P, "StairRail", V3(0.3, 0.3, len), CF((a + b) / 2, b), C.gold, M.Metal, { CanCollide = false })
		part(P, "StairRailLow", V3(0.2, 0.2, len), CF((a + b) / 2 - V3(0, 1, 0), b - V3(0, 1, 0)), C.silver, M.Metal, { CanCollide = false })
	end

	-- throne + Card Master NPC location
	part(P, "ThroneDais1", V3(14, 0.7, 10), at(0, 2.75, -93), C.marble, M.Marble)
	part(P, "ThroneDais2", V3(10, 0.7, 7), at(0, 3.45, -94.5), C.marble2, M.Marble)
	part(P, "DaisTrim1", V3(14.2, 0.2, 10.2), at(0, 3.0, -93), C.gold, M.Metal, NOC)
	local T = model(P, "CardMasterThrone")
	part(T, "SeatBase", V3(5, 2, 4), at(0, 4.8, -95), C.marble, M.Marble)
	part(T, "Cushion", V3(4.2, 0.6, 3.4), at(0, 6.1, -94.8), C.purple, M.Fabric)
	part(T, "BackPanel", V3(5.6, 12, 1.4), at(0, 9.8, -96.6), C.marble, M.Marble)
	part(T, "BackStep1", V3(4, 2, 1.2), at(0, 16.8, -96.6), C.marble, M.Marble)
	part(T, "BackStep2", V3(2.4, 2, 1.2), at(0, 18.8, -96.6), C.marble, M.Marble)
	part(T, "BackTip", V3(0.9, 2.2, 1.2), at(0, 20.9, -96.6), C.gold, M.Metal)
	part(T, "BackFrame", V3(3, 5, 0.3), at(0, 10.2, -95.8), C.gold, M.Metal, NOC)
	part(T, "BackCard", V3(2.4, 4.2, 0.3), at(0, 10.2, -95.65), C.violet, M.Neon, { CanCollide = false, Transparency = 0.4 })
	for _, s in ipairs({ -1, 1 }) do
		part(T, "Armrest", V3(0.9, 2.6, 3.4), at(s * 2.7, 5.2, -95), C.marble, M.Marble)
		part(T, "ArmrestCap", V3(1.1, 0.3, 3.6), at(s * 2.7, 6.6, -95), C.gold, M.Metal)
		part(T, "BackTrim", V3(0.4, 12, 1.5), at(s * 2.9, 9.8, -96.6), C.gold, M.Metal)
		cyl(P, "CandleStand", 1, 6, at(s * 7.4, 6.4, -90.5), C.gold, M.Metal)
		ball(P, "CandleFlame", 0.9, at(s * 7.4, 9.7, -90.5), C.warm, M.Neon, NOC)
	end
	local npc = part(P, "CardMasterNPC_Location", V3(2, 5, 2), at(0, 9, -94.8), C.white, M.SmoothPlastic, { Transparency = 1, CanCollide = false, CanQuery = false })
	npc:SetAttribute("Role", "CardMaster"); CollectionService:AddTag(npc, "CardMasterNPCLocation")
	cyl(P, "AssistantPad", 4, 0.15, at(0, 2.52, -86.5), C.marble2, M.Marble)
	cyl(P, "AssistantPadRing", 4.4, 0.1, at(0, 2.5, -86.5), C.gold, M.Metal)
	local ass = part(P, "AssistantNPC_Location", V3(2, 5, 2), at(0, 5.2, -86.5), C.white, M.SmoothPlastic, { Transparency = 1, CanCollide = false, CanQuery = false })
	ass:SetAttribute("Role", "Assistant"); CollectionService:AddTag(ass, "AssistantNPCLocation")

	-- chandeliers and magical card displays
	for _, z in ipairs({ -77, -85, -93 }) do
		local m = model(P, "Chandelier")
		part(m, "Chain", V3(0.2, 9, 0.2), at(0, 27.5, z), C.silver, M.Metal, NOC)
		cyl(m, "Ring", 8, 0.4, at(0, 22.8, z), C.gold, M.Metal, NOC)
		for i = 0, 7 do
			local a = i * pi / 4
			cyl(m, "Candle", 0.4, 1.2, at(cos(a) * 3.8, 23.6, z + sin(a) * 3.8), C.marble, M.Marble, NOC)
			ball(m, "Flame", 0.5, at(cos(a) * 3.8, 24.4, z + sin(a) * 3.8), C.warm, M.Neon, NOC)
		end
		ball(m, "Core", 1.4, at(0, 22.8, z), C.violet, M.Neon, { CanCollide = false, Transparency = 0.3 })
		local l = Instance.new("PointLight"); l.Color = C.warm; l.Range = 30; l.Brightness = 0.8; l.Shadows = false; l.Parent = m:FindFirstChild("Core")
	end
	for _, s in ipairs({ -1, 1 }) do
		local x, z = s * 6.2, -75
		cyl(P, "DisplayPlinth", 1.8, 3, at(x, 3.9, z), C.marble, M.Marble)
		cyl(P, "DisplayPlinthTop", 2.4, 0.3, at(x, 5.55, z), C.gold, M.Metal)
		local cf = at(x, 8.4, z, s * 20)
		part(P, "FloatingDisplayCardBorder", V3(2.2, 3.1, 0.1), cf, C.gold, M.Metal, NOC)
		part(P, "FloatingDisplayCard", V3(1.8, 2.7, 0.14), cf, C.purple, M.SmoothPlastic, NOC)
		ell(P, "FloatingDisplayArt", V3(0.8, 1.1, 0.16), cf * CF(0, 0.2, 0), s == 1 and C.cyan or C.violet, M.Neon, { CanCollide = false, Transparency = 0.3 })
		cyl(P, "DisplayHalo", 3, 0.04, at(x, 6.2, z), C.cyan, M.Neon, { CanCollide = false, Transparency = 0.6 })
	end

	-- SIX LOTTERY MACHINES (physical machines, ONE shared opening system)
	local function lotteryMachine(id, x, z)
		local m = model(P, "LotteryMachine_" .. id)
		local base = CFrame.lookAt(V3(x, G + 2.4, z), V3(0, G + 2.4, z)) -- front (-Z local) faces the carpet
		local function lp(n, size, off, color, mat, opts) return part(m, n, size, base * off, color, mat, opts) end
		lp("Base", V3(4.4, 1.2, 4.4), CF(0, 0.6, 0), C.marbleDark, M.Marble)
		lp("BaseTrim", V3(4.7, 0.3, 4.7), CF(0, 1.35, 0), C.gold, M.Metal)
		lp("Body", V3(3.6, 5, 3.6), CF(0, 4, 0), C.purple, M.SmoothPlastic)
		for _, sx in ipairs({ -1.8, 1.8 }) do for _, sz in ipairs({ -1.8, 1.8 }) do lp("CornerTrim", V3(0.25, 5, 0.25), CF(sx, 4, sz), C.gold, M.Metal) end end
		local panel = lp("Panel", V3(2.6, 2.2, 0.2), CF(0, 3.9, -1.85), C.deepBlue, M.SmoothPlastic)
		lp("PanelGlow", V3(2.2, 0.15, 0.1), CF(0, 4.8, -1.97), C.cyan, M.Neon, { CanCollide = false, Transparency = 0.3 })
		lp("CoinSlot", V3(0.7, 0.15, 0.1), CF(0, 3.3, -1.97), C.gold, M.Metal, NOC)
		lp("PrizeTray", V3(2, 0.5, 1), CF(0, 2.1, -2.3), C.gold, M.Metal)
		local plate = lp("NumberPlate", V3(2.4, 0.8, 0.12), CF(0, 5.5, -1.85), C.gold, M.Metal)
		label(plate, Enum.NormalId.Front, "LOTTERY " .. id, C.purple, 60)
		lp("LeverPivot", V3(0.6, 0.6, 0.6), CF(2, 4, -0.9), C.silver, M.Metal)
		lp("LeverArm", V3(0.25, 0.25, 1.8), CF(2.1, 4.6, -1.4) * CFrame.Angles(rad(-35), 0, 0), C.silver, M.Metal, NOC)
		ball(m, "LeverKnob", 0.8, base * CF(2.1, 5.2, -2.2), C.rose, M.SmoothPlastic, NOC)
		lp("DomeRing", V3(3.8, 0.4, 3.8), CF(0, 6.7, 0), C.gold, M.Metal)
		ball(m, "Dome", 4, base * CF(0, 8.1, 0), C.white, M.Glass, { CanCollide = false, Transparency = 0.55 })
		local cols = { C.violet, C.cyan, C.warm, C.rose, C.white }
		for i = 1, 8 do
			ball(m, "CapsuleBall", 0.7, base * CF(rr(-1.1, 1.1), 7.5 + rr(0, 1.4), rr(-1.1, 1.1)), cols[i % #cols + 1], M.SmoothPlastic, NOC)
		end
		cyl(m, "Finial", 1, 0.9, base * CF(0, 10.4, 0), C.gold, M.Metal)
		ball(m, "FinialGem", 0.8, base * CF(0, 11.1, 0), C.violet, M.Neon, NOC)
		local pp = Instance.new("ProximityPrompt")
		pp.ActionText = "Open Lottery"; pp.ObjectText = "Lottery Machine " .. id
		pp.HoldDuration = 0.3; pp.MaxActivationDistance = 10; pp.RequiresLineOfSight = false; pp.Parent = panel
		m:SetAttribute("MachineId", id); m:SetAttribute("SharedSystem", "LotteryOpen")
		CollectionService:AddTag(m, "LotteryMachine")
		lotteryMachines[#lotteryMachines + 1] = m
	end
	for i, z in ipairs({ -78, -85, -92 }) do lotteryMachine(i, 9, z); lotteryMachine(i + 3, -9, z) end

	-- castle gardens
	local Gd = F.GardensAndLandscaping
	for _, s in ipairs({ -1, 1 }) do
		for k, z in ipairs({ -62, -57 }) do
			part(Gd, "CastleHedge", V3(16, 1.8, 2.4), at(s * 21, 0.9, z), C.leaf, M.Grass)
			for i = 1, 10 do
				ball(Gd, "CastleFlower", 0.9, at(s * (14 + i * 1.4), 2.2 + 0.1, z + rr(-0.8, 0.8)), glassCols[(i + k) % #glassCols + 1], M.SmoothPlastic, NOC)
			end
		end
		tree(Gd, s * 33, -62, 1.1); tree(Gd, s * 12, -57, 0.9)
		lantern(Gd, s * 12, -64)
	end
end

------------------------------------------------------------------ 3b. GIANT SACRED MONSTER CARD
do
	local P = F.GiantSacredMonsterCard
	local cx, cy, cz = 0, 35, -69.4
	local function L(dz) return at(cx, cy, cz + dz) end -- layers stack toward +Z (toward the plaza)
	part(P, "OuterFrame", V3(17.5, 23.5, 1.2), L(0), C.gold, M.Metal)
	part(P, "InnerFrame", V3(15.8, 21.8, 1.3), L(0.2), C.silver, M.Metal)
	part(P, "ArtBackground", V3(13.8, 19.8, 1.4), L(0.35), C.purple, M.SmoothPlastic)
	part(P, "ArtSkyGlow", V3(13, 12, 1.45), L(0.4), C.deepBlue, M.SmoothPlastic, NOC)
	for _, s in ipairs({ -1, 1 }) do for _, t in ipairs({ -1, 1 }) do
		ball(P, "CornerJewel", 1.1, at(cx + s * 8.2, cy + t * 11.2, cz + 0.7), C.cyan, M.Neon, NOC)
	end end
	ball(P, "Moon", 8, L(0.9), C.cyan, M.Neon, { CanCollide = false, Transparency = 0.5 }); P:FindFirstChild("Moon").CFrame = at(cx, cy + 3.5, cz + 0.9)
	cylZ(P, "MagicCircleOuter", 12, 0.25, at(cx, cy + 0.5, cz + 1.0), C.gold, M.Metal, NOC)
	cylZ(P, "MagicCircleInner", 10.6, 0.2, at(cx, cy + 0.5, cz + 1.1), C.deepBlue, M.SmoothPlastic, NOC)
	for i = 0, 7 do part(P, "CircleRune", V3(0.4, 1.2, 0.15), at(cx, cy + 0.5, cz + 1.2) * CFrame.Angles(0, 0, rad(i * 45)) * CF(0, 4.6, 0), C.violet, M.Neon, NOC) end
	-- monster silhouette: winged arcane beast
	for _, s in ipairs({ -1, 1 }) do
		for i = 1, 3 do
			part(P, "Wing", V3(7 - i, 0.9, 0.35), at(cx + s * (3.2 + i * 1.1), cy + 1 + i * 1.2, cz + 1.5) * CFrame.Angles(0, 0, rad(s * (20 + i * 18))), C.purple:Lerp(C.violet, 0.35), M.SmoothPlastic, NOC)
			part(P, "WingEdge", V3(7 - i, 0.15, 0.4), at(cx + s * (3.2 + i * 1.1), cy + 1.4 + i * 1.2, cz + 1.55) * CFrame.Angles(0, 0, rad(s * (20 + i * 18))), C.gold, M.Metal, NOC)
		end
		part(P, "Horn", V3(0.7, 3, 0.5), at(cx + s * 1.5, cy + 6.8, cz + 1.7) * CFrame.Angles(0, 0, rad(-s * 25)), C.silver, M.Metal, { CanCollide = false, Class = "WedgePart" })
		ell(P, "Eye", V3(0.95, 0.5, 0.3), at(cx + s * 0.9, cy + 4.9, cz + 2.0), C.cyan, M.Neon, NOC)
		part(P, "Claw", V3(0.5, 1.6, 0.4), at(cx + s * 1.6, cy - 4.2, cz + 1.9) * CFrame.Angles(0, 0, rad(s * 15)), C.silver, M.Metal, NOC)
	end
	ell(P, "MonsterBody", V3(6, 9, 0.8), at(cx, cy, cz + 1.6), C.purple:Lerp(C.deepBlue, 0.4), M.SmoothPlastic, NOC)
	ell(P, "MonsterChest", V3(3, 4, 0.5), at(cx, cy + 0.5, cz + 2.0), C.violet, M.Neon, { CanCollide = false, Transparency = 0.35 })
	ell(P, "MonsterHead", V3(4, 3.4, 0.9), at(cx, cy + 4.9, cz + 1.8), C.purple, M.SmoothPlastic, NOC)
	for i = 1, 14 do ball(P, "Star", 0.35, at(cx + rr(-6, 6), cy + rr(-5, 9), cz + 1.0), C.warm, M.Neon, NOC) end
	local plate = part(P, "TitlePlate", V3(12, 2, 0.3), at(cx, cy - 8, cz + 1.0), C.purple, M.SmoothPlastic, NOC)
	label(plate, Enum.NormalId.Back, "✦ ARCANA SOVEREIGN ✦", C.gold, 60)
	part(P, "TitleTrim", V3(12.4, 0.2, 0.35), at(cx, cy - 9.1, cz + 1.0), C.gold, M.Metal, NOC)
	part(P, "TitleTrimTop", V3(12.4, 0.2, 0.35), at(cx, cy - 6.9, cz + 1.0), C.gold, M.Metal, NOC)
	emitter(P, V3(cx, G + cy, cz + 3), V3(14, 20, 2), 4, C.violet, C.cyan, 1.5, 3)
end

------------------------------------------------------------------ 5. TOURNAMENT AREAS (20 tables, 100 chairs)
local function buildChair(parent, x, z, tx, tz, y0, accent)
	local m = model(parent, "Chair")
	local base = CFrame.lookAt(V3(x, G + y0, z), V3(tx, G + y0, tz)) -- front faces the table
	local function cp(n, size, off, color, mat, opts) return part(m, n, size, base * off, color, mat, opts) end
	for _, sx in ipairs({ -0.75, 0.75 }) do for _, sz in ipairs({ -0.75, 0.75 }) do
		cp("Leg", V3(0.28, 1.5, 0.28), CF(sx, 0.75, sz), C.wood, M.Wood)
	end end
	cp("SeatFrame", V3(2, 0.3, 2), CF(0, 1.65, 0), C.wood, M.Wood)
	cp("Seat", V3(1.8, 0.3, 1.8), CF(0, 1.95, 0), accent:Lerp(C.purple, 0.55), M.Fabric, { Class = "Seat" })
	for _, sx in ipairs({ -0.8, 0.8 }) do cp("BackPost", V3(0.26, 2.8, 0.26), CF(sx, 3.0, 0.85), C.wood, M.Wood) end
	cp("BackRail", V3(1.9, 0.3, 0.34), CF(0, 4.45, 0.85), C.gold, M.Metal)
	cp("BackPanel", V3(1.3, 1.8, 0.18), CF(0, 3.3, 0.85), accent:Lerp(C.purple, 0.55), M.Fabric)
	return m
end

local function buildTable(parent, id, idx, cx, cz, tr, nChairs, accent)
	local y0 = 1.2
	local m = model(parent, "Table_" .. id .. "_" .. idx); m:SetAttribute("Area", id)
	cyl(m, "Foot", tr * 0.9, 0.5, at(cx, y0 + 0.25, cz), C.marbleDark, M.Marble)
	cyl(m, "Column", tr * 0.45, 2.0, at(cx, y0 + 1.5, cz), C.marble, M.Marble)
	cyl(m, "Collar", tr * 0.7, 0.3, at(cx, y0 + 2.6, cz), C.gold, M.Metal)
	cyl(m, "GoldRim", tr * 2 + 0.3, 0.3, at(cx, y0 + 2.85, cz), C.gold, M.Metal)
	cyl(m, "Top", tr * 2, 0.4, at(cx, y0 + 2.9, cz), C.wood, M.Wood)
	cyl(m, "Felt", tr * 1.7, 0.08, at(cx, y0 + 3.12, cz), C.purple, M.Fabric, NOC)
	cyl(m, "RuneDisc", tr * 1.3, 0.04, at(cx, y0 + 3.17, cz), accent, M.Neon, { CanCollide = false, Transparency = 0.5 })
	cyl(m, "InnerFelt", tr * 1.0, 0.04, at(cx, y0 + 3.19, cz), C.purple, M.Fabric, NOC)
	local cf = at(cx, y0 + 4.6, cz, idx * 37) * CFrame.Angles(rad(12), 0, 0)
	part(m, "MagicCardBorder", V3(1.4, 0.06, 2), cf, C.gold, M.Metal, NOC)
	part(m, "MagicCard", V3(1.15, 0.08, 1.7), cf, accent, M.SmoothPlastic, { CanCollide = false, Transparency = 0.15 })
	local cr = tr + 1.5
	for i = 0, nChairs - 1 do
		local a = 2 * pi * i / nChairs + ((nChairs == 2) and pi / 2 or 0)
		buildChair(m, cx + cos(a) * cr, cz + sin(a) * cr, cx, cz, y0, accent)
	end
	return m
end

local function sign(parent, text, x, y, z, accent)
	local m = model(parent, "FloatingSign")
	local board = part(m, "Board", V3(11, 3.2, 0.6), at(x, y, z), C.purple, M.SmoothPlastic, { CanCollide = false })
	part(m, "FrameTop", V3(11.6, 0.3, 0.8), at(x, y + 1.6, z), C.gold, M.Metal, NOC)
	part(m, "FrameBottom", V3(11.6, 0.3, 0.8), at(x, y - 1.6, z), C.gold, M.Metal, NOC)
	for _, s in ipairs({ -1, 1 }) do
		part(m, "FrameSide", V3(0.3, 3.4, 0.8), at(x + s * 5.65, y, z), C.gold, M.Metal, NOC)
		ball(m, "Orb", 1.1, at(x + s * 6.8, y, z), accent, M.Neon, { CanCollide = false, Transparency = 0.25 })
	end
	label(board, Enum.NormalId.Front, text, C.white, 50)
	label(board, Enum.NormalId.Back, text, C.white, 50)
	return m
end

do
	for _, a in ipairs(ARENAS) do
		local P = F[a.folder]
		local rimColor = (a.id == "A4") and C.silver or C.gold
		cyl(P, "Platform", 48, 1.2, at(a.x, 0.6, a.z), C.marble, M.Marble)
		cyl(P, "PlatformRim", 48.6, 0.4, at(a.x, 1.0, a.z), rimColor, M.Metal)
		for _, r in ipairs({ { 44, 43, 1.23 }, { 32, 31, 1.23 } }) do
			cyl(P, "AccentInlay", r[1], 0.03, at(a.x, r[3] - 0.015, a.z), a.color, M.Neon, { CanCollide = false, Transparency = 0.45 })
			cyl(P, "InlayDisc", r[2], 0.035, at(a.x, r[3] - 0.01, a.z), C.marble, M.Marble, NOC)
		end
		-- stairs + gate toward the plaza
		local l = sqrt(a.x * a.x + a.z * a.z); local ux, uz = -a.x / l, -a.z / l
		local face = CFrame.lookAt(V3(a.x, G, a.z), V3(a.x + ux, G, a.z + uz))
		part(P, "StairLower", V3(8, 0.4, 1.8), face * CF(0, 0.2, -26.7), C.marble, M.Marble)
		part(P, "StairUpper", V3(8, 0.8, 1.8), face * CF(0, 0.4, -24.9), C.marble, M.Marble)
		for _, s in ipairs({ -1, 1 }) do
			cyl(P, "GatePillar", 1.4, 9, face * CF(s * 4.8, 4.5, -25.6), C.marble, M.Marble)
			cyl(P, "GateCap", 1.9, 0.6, face * CF(s * 4.8, 9.2, -25.6), rimColor, M.Metal)
			ball(P, "GateOrb", 1, face * CF(s * 4.8, 10.1, -25.6), a.color, M.Neon, { CanCollide = false, Transparency = 0.2 })
		end
		arch(P, face * CF(0, 9, -25.6), 4.8, 0.8, 1.1, rimColor, M.Metal, 6)
		-- distinct themed pillars around the rim (skip the stair side)
		local toPlaza = math.atan2(uz, ux)
		for i = 0, 7 do
			local ang = i * pi / 4
			local dAng = abs(((ang - toPlaza + pi) % (2 * pi)) - pi)
			if dAng > 0.6 then
				local px, pz = a.x + cos(ang) * 22, a.z + sin(ang) * 22
				if a.id == "A1" then -- crystal spires
					cyl(P, "Shaft", 1.1, 8, at(px, 5.2, pz), C.silver, M.Metal)
					ball(P, "Crystal", 2, at(px, 10.2, pz), C.cyan, M.Glass, { CanCollide = false, Transparency = 0.3 })
					cyl(P, "Base", 2.2, 0.8, at(px, 1.6, pz), C.marble2, M.Marble)
				elseif a.id == "A2" then -- twin columns with hanging banners
					for _, o in ipairs({ -0.9, 0.9 }) do cyl(P, "Shaft", 0.9, 9, at(px + o, 5.7, pz), C.marble, M.Marble) end
					part(P, "Lintel", V3(3.2, 0.6, 1.2), at(px, 10.4, pz), C.gold, M.Metal)
					banner(P, at(px, 6.4, pz + 0.8, 0), C.purple, 6)
				elseif a.id == "A3" then -- gilded columns with sun discs
					cyl(P, "Shaft", 1.8, 9, at(px, 5.7, pz), C.gold:Lerp(C.marble, 0.4), M.Marble)
					cyl(P, "Capital", 2.6, 0.8, at(px, 10.6, pz), C.gold, M.Metal)
					cylZ(P, "SunDisc", 2.4, 0.2, at(px, 12.2, pz), C.warm, M.Neon, { CanCollide = false, Transparency = 0.3 })
				else -- A4 silver obelisks
					for k = 1, 4 do part(P, "Obelisk", V3(2.2 - k * 0.4, 2.2, 2.2 - k * 0.4), at(px, 2.2 + (k - 1) * 2.2, pz), C.silver, M.Metal) end
					ball(P, "Tip", 1, at(px, 11.4, pz), C.blueSilver, M.Neon, { CanCollide = false, Transparency = 0.2 })
				end
			end
		end
		-- 5 tables per area: four corners + centre
		local off = 11.5
		local spots = { { -off, -off }, { off, -off }, { -off, off }, { off, off }, { 0, 0 } }
		for i, sp in ipairs(spots) do buildTable(P, a.id, i, a.x + sp[1], a.z + sp[2], a.tr, a.chairs, a.color) end
		sign(P, a.sign, a.x, 17, a.z, a.color)
		lantern(P, a.x + ux * 22 - uz * 7, a.z + uz * 22 + ux * 7, 1.2)
		lantern(P, a.x + ux * 22 + uz * 7, a.z + uz * 22 - ux * 7, 1.2)
	end
end

------------------------------------------------------------------ 6. SPAWN ENTRANCE
do
	local P = F.SpawnEntrance
	cyl(P, "SpawnPlaza", 30, 0.6, at(0, 0.3, 90), C.marble, M.Marble)
	cyl(P, "SpawnRingGold", 26, 0.1, at(0, 0.65, 90), C.gold, M.Metal)
	cyl(P, "SpawnDisc", 25, 0.12, at(0, 0.66, 90), C.marble2, M.Marble)
	-- star / compass emblem (north tip points toward the castle)
	part(P, "CompassNS", V3(1.6, 0.1, 22), at(0, 0.74, 90), C.gold, M.Metal, NOC)
	part(P, "CompassEW", V3(22, 0.1, 1.6), at(0, 0.74, 90), C.gold, M.Metal, NOC)
	part(P, "CompassDiagA", V3(1.1, 0.1, 15), at(0, 0.75, 90, 45), C.silver, M.Metal, NOC)
	part(P, "CompassDiagB", V3(1.1, 0.1, 15), at(0, 0.75, 90, -45), C.silver, M.Metal, NOC)
	cyl(P, "CompassHub", 4.2, 0.14, at(0, 0.78, 90), C.violet, M.Glass, { CanCollide = false, Transparency = 0.2 })
	cyl(P, "CompassHubRing", 4.8, 0.1, at(0, 0.76, 90), C.gold, M.Metal, NOC)
	local nTip = part(P, "NorthMark", V3(2.4, 0.1, 2.4), at(0, 0.78, 78.5), C.deepBlue, M.SmoothPlastic, NOC)
	label(nTip, Enum.NormalId.Top, "N", C.cyan, 60)
	-- spawn point (reuse an existing SpawnLocation instead of duplicating)
	local sp = Workspace:FindFirstChildWhichIsA("SpawnLocation", true)
	if not sp then sp = Instance.new("SpawnLocation"); sp.Name = "MainSpawn"; sp.Parent = P end
	sp.Anchored = true; sp.Size = V3(10, 0.4, 10); sp.CFrame = at(0, 1.0, 93); sp.Neutral = true
	sp.Transparency = 1; sp.CanCollide = true
	for _, d in ipairs(sp:GetChildren()) do if d:IsA("Decal") then d:Destroy() end end
	-- stone steps, gate platform, gate
	part(P, "GatePlatform", V3(34, 1.2, 8), at(0, 0.6, 104), C.marble, M.Marble)
	for i = 1, 3 do part(P, "SpawnStep", V3(16, 0.2 * i + 0.6, 1.2), at(0, (0.2 * i + 0.6) / 2, 99.4 - 1.2 * (i - 1) + 0.6 - 3.6 + 3.6), C.marble, M.Marble) end
	for _, s in ipairs({ -1, 1 }) do
		cyl(P, "GatePillar", 3.2, 20, at(s * 9, 11.2, 104), C.marble, M.Marble)
		cyl(P, "GatePillarBase", 4.4, 1.2, at(s * 9, 1.8, 104), C.marble2, M.Marble)
		cyl(P, "GatePillarCap", 4.2, 1.2, at(s * 9, 21.4, 104), C.gold, M.Metal)
		for k = 0, 5 do cyl(P, "Flute", 0.4, 18, at(s * 9 + cos(k * pi / 3) * 1.6, 11.2, 104 + sin(k * pi / 3) * 1.6), C.marble2, M.Marble, NOC) end
		ball(P, "GateOrb", 2, at(s * 9, 23.2, 104), C.violet, M.Neon, { CanCollide = false, Transparency = 0.25 })
		banner(P, at(s * 9, 14, 102.3, 0) * CFrame.Angles(0, pi, 0), (s == 1) and C.purple or C.deepBlue, 9)
		lantern(P, s * 15, 100, 0.8); lantern(P, s * 15, 108, 0.8)
		cyl(P, "StepPillar", 1.6, 4, at(s * 8.6, 2.6, 98.6), C.marble, M.Marble)
		ball(P, "StepPillarOrb", 1, at(s * 8.6, 4.9, 98.6), C.gold, M.Metal, NOC)
		for i = 0, 2 do part(P, "GateWingWall", V3(5, 3 + i * 0.01, 1.4), at(s * (13.5 + i * 0), 2.7, 104), C.marble, M.Marble) end
		for _, z in ipairs({ 74, 82 }) do lantern(P, s * 11, z) end
	end
	arch(P, at(0, 14, 104), 9, 1.6, 2, C.marble, M.Marble, 10)
	arch(P, at(0, 14, 102.9), 9.4, 0.4, 2.3, C.gold, M.Metal, 10)
	-- crest at the apex: 4-point star
	local ap = at(0, 14 + 9 * sqrt(3) + 2.2, 102.9)
	part(P, "CrestV", V3(0.7, 4.6, 0.5), ap, C.gold, M.Metal, NOC); part(P, "CrestH", V3(4.6, 0.7, 0.5), ap, C.gold, M.Metal, NOC)
	part(P, "CrestDA", V3(0.5, 3.2, 0.4), ap * CFrame.Angles(0, 0, rad(45)), C.silver, M.Metal, NOC); part(P, "CrestDB", V3(0.5, 3.2, 0.4), ap * CFrame.Angles(0, 0, rad(-45)), C.silver, M.Metal, NOC)
	ball(P, "CrestGem", 1, ap * CF(0, 0, 0.3), C.cyan, M.Neon, NOC)
	local wb = part(P, "WelcomePlate", V3(12, 2, 0.3), at(0, 11, 102.5), C.purple, M.SmoothPlastic, NOC)
	label(wb, Enum.NormalId.Front, "ECHObOUND", C.gold, 60)
	local wb2 = part(P, "WelcomePlateBack", V3(12, 2, 0.3), at(0, 11, 105.5), C.purple, M.SmoothPlastic, NOC)
	label(wb2, Enum.NormalId.Back, "ECHObOUND", C.gold, 60)
end

------------------------------------------------------------------ 7. LEADERBOARD MONUMENTS
do
	local function monument(P, x, z, faceX, cfg)
		local face = CFrame.lookAt(V3(x, G, z), V3(x + faceX, G, z))
		cyl(P, "MonumentBase", 16, 1.0, at(x, 0.5, z), C.marble2, M.Marble)
		cyl(P, "MonumentBaseGold", 16.4, 0.3, at(x, 0.9, z), C.gold, M.Metal)
		part(P, "Plinth", V3(13, 1.4, 4.4), face * CF(0, 1.7, 0), C.marble, M.Marble)
		part(P, "PlinthTrim", V3(13.4, 0.3, 4.8), face * CF(0, 2.5, 0), C.gold, M.Metal)
		part(P, "BackSlab", V3(13, 15, 1.6), face * CF(0, 10, 0.8), C.marbleDark, M.Slate)
		part(P, "FrameGold", V3(11.6, 12.6, 0.5), face * CF(0, 10, -0.15), C.gold, M.Metal)
		local board = part(P, "DisplaySurface", V3(10.4, 11.4, 0.3), face * CF(0, 10, -0.5), C.purple, M.SmoothPlastic)
		board:SetAttribute("BoardType", cfg.Type); board:SetAttribute("MaxRows", 10)
		CollectionService:AddTag(board, "Leaderboard")
		for _, s in ipairs({ -1, 1 }) do
			cyl(P, "SidePillar", 1.8, 16, face * CF(s * 7.4, 9.5, 0), C.marble, M.Marble)
			cyl(P, "SidePillarCap", 2.4, 0.8, face * CF(s * 7.4, 17.6, 0), C.gold, M.Metal)
			ball(P, "SideOrb", 1.4, face * CF(s * 7.4, 18.8, 0), C.cyan, M.Neon, { CanCollide = false, Transparency = 0.25 })
			lantern(P, x + 0, z + s * 9.5, 0.8)
		end
		arch(P, face * CF(0, 16.4, -0.1), 5.2, 0.8, 1.2, C.gold, M.Metal, 6)
		-- functional display UI (rows are updated later by the leaderboard script)
		local sg = Instance.new("SurfaceGui"); sg.Name = "BoardGui"; sg.Face = Enum.NormalId.Front
		sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud; sg.PixelsPerStud = 50; sg.Parent = board
		local bg = Instance.new("Frame"); bg.Size = UDim2.fromScale(1, 1); bg.BackgroundColor3 = Color3.fromRGB(26, 18, 44); bg.BorderSizePixel = 0; bg.Parent = sg
		local function lbl(par, name, text, px, py, sx, sy, col, xa)
			local t = Instance.new("TextLabel"); t.Name = name; t.Position = UDim2.fromScale(px, py); t.Size = UDim2.fromScale(sx, sy)
			t.BackgroundTransparency = 1; t.Text = text; t.TextColor3 = col; t.TextScaled = true; t.Font = Enum.Font.GothamBold
			t.TextXAlignment = xa or Enum.TextXAlignment.Center; t.Parent = par; return t
		end
		lbl(bg, "Title", cfg.Title, 0, 0.01, 1, 0.09, C.gold)
		lbl(bg, "Subtitle", cfg.Sub, 0.03, 0.10, 0.94, 0.05, C.silver)
		lbl(bg, "HeaderRank", "#", 0.03, 0.165, 0.12, 0.045, C.cyan); lbl(bg, "HeaderName", "PLAYER", 0.17, 0.165, 0.5, 0.045, C.cyan, Enum.TextXAlignment.Left)
		lbl(bg, "HeaderValue", "VALUE", 0.68, 0.165, 0.29, 0.045, C.cyan, Enum.TextXAlignment.Right)
		for i = 1, 10 do
			local row = Instance.new("Frame"); row.Name = "Row" .. i; row.Position = UDim2.fromScale(0.02, 0.215 + (i - 1) * 0.077)
			row.Size = UDim2.fromScale(0.96, 0.07); row.BorderSizePixel = 0
			row.BackgroundColor3 = (i % 2 == 0) and Color3.fromRGB(48, 34, 76) or Color3.fromRGB(38, 26, 62); row.Parent = bg
			lbl(row, "Rank", tostring(i), 0.01, 0.1, 0.12, 0.8, (i <= 3) and C.gold or C.white)
			lbl(row, "PlayerName", "---", 0.15, 0.1, 0.52, 0.8, C.white, Enum.TextXAlignment.Left)
			lbl(row, "Value", "0", 0.68, 0.1, 0.3, 0.8, C.warm, Enum.TextXAlignment.Right)
		end
	end
	monument(F.Leaderboard_West, -96, 20, 1, CFG.WestBoard)  -- faces east (toward the plaza)
	monument(F.Leaderboard_East, 96, 20, -1, CFG.EastBoard)  -- faces west
end

------------------------------------------------------------------ 6b. OUTER BRIDGES + SATELLITE ISLETS
do
	local P = F.OuterBridges
	for _, s in ipairs({ -1, 1 }) do
		bridge(P, s * 118, 0, s, 0, 24, 7, 0.6, "OuterBridge")
		local ix = s * 142
		cyl(P, "IsletTop", 26, 6, at(ix, -3, 0), C.grass, M.Grass)
		cyl(P, "IsletDirt", 25, 6, at(ix, -9, 0), C.dirt, M.Ground)
		cyl(P, "IsletRock1", 22, 8, at(ix, -16, 0), C.rock, M.Slate)
		cyl(P, "IsletRock2", 15, 8, at(ix, -24, 0), C.rockDark, M.Basalt)
		cyl(P, "IsletRock3", 8, 8, at(ix, -32, 0), C.rock, M.Rock)
		cyl(P, "IsletPlaza", 12, 0.5, at(ix, 0.25, 0), C.marble, M.Marble)
		cyl(P, "IsletGold", 12.4, 0.2, at(ix, 0.2, 0), C.gold, M.Metal)
		tree(P, ix + s * 4, 4, 1.1); tree(P, ix + s * 5, -5, 0.9)
		lantern(P, ix - s * 2, 5, 0.5); lantern(P, ix - s * 2, -5, 0.5)
		local gem = part(P, "IsletShrine", V3(2, 3, 2), at(ix + s * 1, 2, 0), C.marble, M.Marble)
		ball(P, "ShrineOrb", 1.8, at(ix + s * 1, 4.4, 0), C.violet, M.Neon, { CanCollide = false, Transparency = 0.3 })
		for _, z in ipairs({ -6, 6 }) do cyl(P, "IsletBridgePillar", 1.6, 5, at(s * 129.5, 2.5, z), C.marble, M.Marble) end
	end
end

------------------------------------------------------------------ 6c. GARDENS & LANDSCAPING (scatter)
do
	local P = F.GardensAndLandscaping
	local function free(x, z)
		local d2 = x * x + z * z
		if d2 > 100 * 100 or d2 < 40 * 40 then return false end
		if abs(x) < 11 then return false end
		if abs(abs(x) - 40) < 7 and z > -62 and z < 104 then return false end
		if z < -64 or (z > 82 and abs(x) < 34) then return false end
		for _, a in ipairs(ARENAS) do if (x - a.x) ^ 2 + (z - a.z) ^ 2 < 31 ^ 2 then return false end end
		for _, p in ipairs(POOLS) do if (x - p[1]) ^ 2 + (z - p[2]) ^ 2 < (p[3] + 6) ^ 2 then return false end end
		if abs(abs(x) - 96) < 13 and abs(z - 20) < 13 then return false end
		if abs(x) > 100 and abs(z) < 8 then return false end
		for _, s in ipairs(PATHS) do if distSeg(x, z, s) < 6 then return false end end
		return true
	end
	local placed, tries = 0, 0
	while placed < 42 and tries < 1500 do
		tries += 1
		local x, z = rr(-102, 102), rr(-100, 100)
		if free(x, z) then tree(P, x, z, rr(0.8, 1.3)); placed += 1 end
	end
	local flowerCols = { C.rose, C.violet, C.warm, C.white, C.cyan, C.blossom }
	placed, tries = 0, 0
	while placed < 40 and tries < 1500 do
		tries += 1
		local x, z = rr(-102, 102), rr(-100, 100)
		if free(x, z) then
			placed += 1
			local m = model(P, "FlowerPatch")
			cyl(m, "Bed", 2.8, 0.25, at(x, 0.12, z), C.leaf, M.Grass, NOC)
			for i = 1, 5 do ball(m, "Bloom", 0.9, at(x + rr(-1, 1), 0.6, z + rr(-1, 1)), flowerCols[rng:NextInteger(1, #flowerCols)], M.SmoothPlastic, NOC) end
		end
	end
	-- garden bushes along the avenue
	for _, s in ipairs({ -1, 1 }) do for _, z in ipairs({ 36, 48, 60, 72, 84 }) do
		ball(P, "AvenueBush", 2.6, at(s * 11, 1.2, z), C.leaf, M.Grass)
		ball(P, "AvenueBloom", 0.8, at(s * 11 + rr(-.5, .5), 2.5, z + rr(-.5, .5)), C.rose, M.SmoothPlastic, NOC)
	end end
	-- fireflies / magic motes (low rates)
	for _, v in ipairs({ { -60, 4, 0 }, { 60, 4, 0 }, { -55, 4, 85 }, { 55, 4, 85 }, { -30, 4, -52 }, { 30, 4, -52 } }) do
		emitter(F.LightingAndEffects, V3(v[1], G + v[2], v[3]), V3(18, 6, 18), 2, C.warm, C.cyan, 0.8, 8)
	end
end

------------------------------------------------------------------ LIGHTING, SKY, CLOUDS, EFFECTS
do
	local P = F.LightingAndEffects
	Lighting.ClockTime = 17.3; Lighting.Brightness = 2.2; Lighting.GlobalShadows = true
	Lighting.Ambient = Color3.fromRGB(70, 60, 95); Lighting.OutdoorAmbient = Color3.fromRGB(110, 100, 140)
	Lighting.ColorShift_Top = Color3.fromRGB(255, 220, 180)
	Lighting.EnvironmentDiffuseScale = 0.6; Lighting.EnvironmentSpecularScale = 0.4
	local function eff(class, props)
		local o = Lighting:FindFirstChildOfClass(class) or Instance.new(class)
		for k, v in pairs(props) do o[k] = v end
		o.Parent = Lighting; return o
	end
	eff("Atmosphere", { Density = 0.3, Offset = 0.25, Color = Color3.fromRGB(210, 200, 235), Decay = Color3.fromRGB(255, 190, 150), Glare = 0.2, Haze = 1.2 })
	eff("BloomEffect", { Intensity = 0.25, Size = 20, Threshold = 1.4 })          -- restrained bloom
	eff("ColorCorrectionEffect", { Saturation = 0.1, Contrast = 0.05, TintColor = Color3.fromRGB(255, 248, 240) })
	eff("SunRaysEffect", { Intensity = 0.05, Spread = 0.6 })
	if not Lighting:FindFirstChildOfClass("Sky") then Instance.new("Sky").Parent = Lighting end

	-- clouds around and beneath the island (non-colliding, cheap)
	for i = 1, 34 do
		local a = rr(0, 2 * pi); local rd = rr(125, 270); local y = -rr(10, 120)
		local m = model(P, "Cloud")
		local bx, bz = cos(a) * rd, sin(a) * rd
		for k = 1, rng:NextInteger(3, 5) do
			ball(m, "Puff", rr(18, 38), at(bx + rr(-16, 16), y + rr(-3, 3), bz + rr(-16, 16)), Color3.fromRGB(246, 242, 255), M.SmoothPlastic,
				{ CanCollide = false, CanTouch = false, CanQuery = false, Transparency = 0.3, CastShadow = false })
		end
	end
	for i = 1, 14 do -- cloud sea far below
		local a = rr(0, 2 * pi); local rd = rr(0, 220)
		cyl(P, "CloudSea", rr(80, 150), 8, at(cos(a) * rd, -rr(215, 250), sin(a) * rd), Color3.fromRGB(236, 230, 250), M.SmoothPlastic,
			{ CanCollide = false, CanTouch = false, CanQuery = false, Transparency = 0.25, CastShadow = false })
	end
	for i = 1, 14 do -- low clouds drifting around the island edge
		local a = rr(0, 2 * pi); local rd = rr(118, 150)
		ball(P, "EdgeCloud", rr(16, 26), at(cos(a) * rd, -rr(18, 40), sin(a) * rd), Color3.fromRGB(246, 242, 255), M.SmoothPlastic,
			{ CanCollide = false, CanTouch = false, CanQuery = false, Transparency = 0.4, CastShadow = false })
	end
	P:SetAttribute("EmitterCount", emitters); P:SetAttribute("EmitterRateCap", 8)
end

------------------------------------------------------------------ SHARED LOTTERY OPENING SYSTEM (one for all six machines)
do
	local ev = ReplicatedStorage:FindFirstChild("OpenLotteryEvent")
	if not ev then ev = Instance.new("RemoteEvent"); ev.Name = "OpenLotteryEvent"; ev.Parent = ReplicatedStorage end
	local old = ServerScriptService:FindFirstChild("LotteryOpenController")
	if old then old:Destroy() end
	local sc = Instance.new("Script"); sc.Name = "LotteryOpenController"
	local ok = pcall(function()
		sc.Source = [[
-- ONE shared opening system for all six physical Lottery machines.
local CS = game:GetService("CollectionService")
local RS = game:GetService("ReplicatedStorage")
local ev = RS:WaitForChild("OpenLotteryEvent")
local function hook(machine)
	local pp = machine:FindFirstChildWhichIsA("ProximityPrompt", true)
	if pp then
		pp.Triggered:Connect(function(player)
			ev:FireClient(player, machine:GetAttribute("MachineId")) -- Part 2 hooks the lottery UI here
		end)
	end
end
for _, m in ipairs(CS:GetTagged("LotteryMachine")) do hook(m) end
CS:GetInstanceAddedSignal("LotteryMachine"):Connect(hook)
]]
	end)
	sc.Parent = ServerScriptService
	if not ok then warn("[ECHObOUND] Could not write Script.Source from this context; paste the LotteryOpenController code manually (see comment in file).") end
end

------------------------------------------------------------------ VALIDATION
do
	local tablesN, chairsN = 0, 0
	for _, a in ipairs(ARENAS) do
		local t, c = 0, 0
		for _, d in ipairs(F[a.folder]:GetDescendants()) do
			if d:IsA("Model") then
				if d.Name:sub(1, 6) == "Table_" then t += 1 elseif d.Name == "Chair" then c += 1 end
			end
		end
		print(string.format("[ECHObOUND] %s: %d tables, %d chairs", a.id, t, c))
		tablesN += t; chairsN += c
	end
	assert(tablesN == 20 and chairsN == 100, "Table/chair count mismatch!")
	print(string.format("[ECHObOUND] Totals OK: %d tables, %d chairs, %d lottery machines, %d particle emitters", tablesN, chairsN, #lotteryMachines, emitters))
	local parts = 0
	for _, n in ipairs(FOLDER_NAMES) do
		local c = 0
		for _, d in ipairs(F[n]:GetDescendants()) do if d:IsA("BasePart") then c += 1 end end
		parts += c; print(string.format("   %-26s %5d parts", n, c))
	end
	print("[ECHObOUND] Total parts:", parts, "(tip: enable StreamingEnabled for mobile)")
	print("[ECHObOUND] DONE. Save the place (File > Save), then test: spawn -> avenue -> statue -> castle -> arenas.")
end
