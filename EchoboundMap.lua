--[[
    ECHOBOUND MAP BUILDER
    ---------------------
    Put this as a normal Script inside ServerScriptService and press Play
    (or run it in the Command Bar via a Plugin/Studio). It builds the whole
    map from code, with no manual building.

    Blueprint: 240 x 220 (meters). Units here: 1 unit = 1 meter, then the whole
    model is scaled by SCALE so it feels right for Roblox characters.
    North = -Z, East = +X.
]]

local SCALE = 2 -- change this to make the whole map bigger/smaller

local Workspace = game:GetService("Workspace")
local old = Workspace:FindFirstChild("EchoboundMap")
if old then old:Destroy() end

local map = Instance.new("Model")
map.Name = "EchoboundMap"
map.Parent = Workspace

------------------------------------------------------------------
-- Colors
------------------------------------------------------------------
local C = {
	stone    = Color3.fromRGB(196, 190, 180),
	stoneD   = Color3.fromRGB(150, 145, 138),
	path     = Color3.fromRGB(225, 220, 208),
	rock     = Color3.fromRGB(110, 104, 98),
	water    = Color3.fromRGB(110, 180, 230),
	leaf     = Color3.fromRGB(86, 140, 78),
	trunk    = Color3.fromRGB(105, 78, 52),
	hedge    = Color3.fromRGB(70, 120, 66),
	gold     = Color3.fromRGB(230, 190, 90),
	purple   = Color3.fromRGB(140, 90, 220),
	cyan     = Color3.fromRGB(80, 230, 255),
	wood     = Color3.fromRGB(120, 85, 55),
	dark     = Color3.fromRGB(30, 32, 40),
	white    = Color3.fromRGB(245, 245, 245),
}

------------------------------------------------------------------
-- Helpers
------------------------------------------------------------------
local function part(name, size, pos, color, material, parent, rotY)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = CFrame.new(pos) * CFrame.Angles(0, math.rad(rotY or 0), 0)
	p.Color = color or C.stone
	p.Material = material or Enum.Material.Slate
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent or map
	return p
end

-- vertical cylinder (diameter d, height h) centered at pos
local function cyl(name, d, h, pos, color, material, parent)
	local p = Instance.new("Part")
	p.Name = name
	p.Shape = Enum.PartType.Cylinder
	p.Anchored = true
	p.Size = Vector3.new(h, d, d)
	p.CFrame = CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90))
	p.Color = color or C.stone
	p.Material = material or Enum.Material.Slate
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent or map
	return p
end

local function ball(name, d, pos, color, material, parent)
	local p = Instance.new("Part")
	p.Name = name
	p.Shape = Enum.PartType.Ball
	p.Anchored = true
	p.Size = Vector3.new(d, d, d)
	p.Position = pos
	p.Color = color
	p.Material = material or Enum.Material.Grass
	p.Parent = parent or map
	return p
end

local function folder(name)
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = map
	return f
end

-- floating text label (Arabic + English supported)
local function label(parent, text, pos, w, h)
	local anchor = part("Label", Vector3.new(1, 1, 1), pos, C.white, Enum.Material.SmoothPlastic, parent)
	anchor.Transparency = 1
	anchor.CanCollide = false
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(w or 260, h or 110)
	bb.StudsOffset = Vector3.new(0, 0, 0)
	bb.AlwaysOnTop = false
	bb.MaxDistance = 250
	bb.Parent = anchor
	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Color3.fromRGB(250, 250, 250)
	frame.BackgroundTransparency = 0.1
	frame.BorderSizePixel = 2
	frame.Parent = bb
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 1
	t.RichText = true
	t.Text = text
	t.TextScaled = true
	t.Font = Enum.Font.GothamBold
	t.TextColor3 = Color3.fromRGB(20, 20, 20)
	t.Parent = frame
	return anchor
end

local function lamp(parent, x, z)
	local pos = Vector3.new(x, 0, z)
	part("LampPole", Vector3.new(0.5, 7, 0.5), pos + Vector3.new(0, 3.5, 0), C.dark, Enum.Material.Metal, parent)
	local bulb = ball("LampBulb", 1.6, pos + Vector3.new(0, 7.6, 0), Color3.fromRGB(255, 225, 150), Enum.Material.Neon, parent)
	local l = Instance.new("PointLight")
	l.Range = 22
	l.Brightness = 1.5
	l.Color = Color3.fromRGB(255, 220, 150)
	l.Parent = bulb
end

local function tree(parent, x, z, s)
	s = s or 1
	cyl("Trunk", 1.2 * s, 6 * s, Vector3.new(x, 3 * s, z), C.trunk, Enum.Material.Wood, parent)
	ball("Leaves", 8 * s, Vector3.new(x, 8.5 * s, z), C.leaf, Enum.Material.Grass, parent)
	ball("Leaves2", 5.5 * s, Vector3.new(x + 1.5 * s, 11 * s, z), C.leaf, Enum.Material.Grass, parent)
end

local function planter(parent, x, z, w, d)
	part("PlanterBox", Vector3.new(w, 1.6, d), Vector3.new(x, 0.8, z), C.stoneD, Enum.Material.Slate, parent)
	part("PlanterHedge", Vector3.new(w - 1, 1.2, d - 1), Vector3.new(x, 2.1, z), C.hedge, Enum.Material.Grass, parent)
end

-- stairs descending toward +Z (dir = 1) or -Z (dir = -1) from startZ
local function stairs(parent, x, startZ, width, steps, rise, run, dir, topH)
	for i = 1, steps do
		local h = topH - i * rise
		if h > 0.05 then
			part("Step", Vector3.new(width, h, run), Vector3.new(x, h / 2, startZ + dir * (i - 0.5) * run), C.stoneD, Enum.Material.Slate, parent)
		end
	end
end

------------------------------------------------------------------
-- 1) ISLAND BASE (floating island with chamfered corners + rocky underside)
------------------------------------------------------------------
local base = folder("Island")

part("PlazaA", Vector3.new(210, 6, 150), Vector3.new(0, -3, 0), C.stone, Enum.Material.Cobblestone, base)
part("PlazaB", Vector3.new(160, 6, 220), Vector3.new(0, -3, 0), C.stone, Enum.Material.Cobblestone, base)
for _, sx in ipairs({ -1, 1 }) do
	for _, sz in ipairs({ -1, 1 }) do
		part("Corner", Vector3.new(36, 6, 36), Vector3.new(sx * 78, -3, sz * 78), C.stone, Enum.Material.Cobblestone, base, 45)
	end
end

-- rocky underside (stepped layers)
for i = 1, 5 do
	local w, d = 200 - i * 28, 190 - i * 28
	part("Cliff" .. i, Vector3.new(w, 9, d), Vector3.new(0, -6 - i * 8, 0), C.rock, Enum.Material.Rock, base)
end
part("CliffTip", Vector3.new(40, 10, 30), Vector3.new(0, -52, 0), C.rock, Enum.Material.Rock, base)

------------------------------------------------------------------
-- 2) PATHS
------------------------------------------------------------------
local paths = folder("Paths")
-- main north-south path (palace -> spawn)
part("PathNS", Vector3.new(14, 0.4, 170), Vector3.new(0, 0.2, 25), C.path, Enum.Material.Marble, paths)
-- east-west path
part("PathEW", Vector3.new(208, 0.4, 14), Vector3.new(0, 0.2, 7), C.path, Enum.Material.Marble, paths)
-- paving trims
for _, sx in ipairs({ -1, 1 }) do
	part("TrimNS", Vector3.new(1, 0.6, 170), Vector3.new(sx * 7.5, 0.3, 25), C.stoneD, Enum.Material.Slate, paths)
end

------------------------------------------------------------------
-- 3) PALACE: "The Last Arcana" (north)
------------------------------------------------------------------
local palace = folder("LastArcanaPalace")
local pz = -86 -- palace center Z
part("PalaceFloor", Vector3.new(100, 3, 48), Vector3.new(0, 1.5, pz), C.path, Enum.Material.Marble, palace)
part("BackWall", Vector3.new(100, 26, 3), Vector3.new(0, 16, pz - 22.5), C.stone, Enum.Material.Concrete, palace)
for _, sx in ipairs({ -1, 1 }) do
	part("SideWall", Vector3.new(3, 26, 48), Vector3.new(sx * 48.5, 16, pz), C.stone, Enum.Material.Concrete, palace)
	part("FrontWing", Vector3.new(30, 26, 3), Vector3.new(sx * 33, 16, pz + 22.5), C.stone, Enum.Material.Concrete, palace)
	-- columns around entrance
	for _, cx in ipairs({ 13, 19 }) do
		cyl("Column", 3, 26, Vector3.new(sx * cx, 16, pz + 22.5), C.white, Enum.Material.Marble, palace)
	end
	-- hanging royal banners
	local b = part("Banner", Vector3.new(6, 16, 0.5), Vector3.new(sx * 30, 14, pz + 24.3), C.purple, Enum.Material.Fabric, palace)
	part("BannerEmblem", Vector3.new(2.6, 2.6, 0.3), Vector3.new(sx * 30, 14, pz + 24.7), C.gold, Enum.Material.Neon, palace, 45)
end
-- roof
part("Roof", Vector3.new(100, 3, 48), Vector3.new(0, 30.5, pz), C.stoneD, Enum.Material.Slate, palace)
part("RoofTrim", Vector3.new(104, 1.5, 52), Vector3.new(0, 32.7, pz), C.gold, Enum.Material.Metal, palace)

-- inner great hall
part("Carpet", Vector3.new(14, 0.3, 44), Vector3.new(0, 3.2, pz), Color3.fromRGB(110, 40, 140), Enum.Material.Fabric, palace)
for i = -1, 1, 2 do
	for k = 0, 2 do
		local z = pz - 14 + k * 12
		part("InnerPillar", Vector3.new(3, 24, 3), Vector3.new(i * 22, 15, z), C.white, Enum.Material.Marble, palace)
		local neon = part("NeonStrip", Vector3.new(0.5, 20, 0.5), Vector3.new(i * 20.2, 15, z), C.cyan, Enum.Material.Neon, palace)
	end
end
local hallLight = part("HallLight", Vector3.new(6, 1, 6), Vector3.new(0, 28, pz), C.gold, Enum.Material.Neon, palace)
local pl = Instance.new("PointLight")
pl.Range = 60; pl.Brightness = 2; pl.Color = Color3.fromRGB(190, 150, 255); pl.Parent = hallLight

-- giant book on the roof
local bookY = 48
local cover = part("BookCover", Vector3.new(38, 30, 3), Vector3.new(0, bookY, pz - 6), C.gold, Enum.Material.Metal, palace)
cover.CFrame = cover.CFrame * CFrame.Angles(math.rad(-12), 0, 0)
local face = part("BookFace", Vector3.new(34, 26, 0.6), Vector3.new(0, bookY, pz - 4.4), C.purple, Enum.Material.Fabric, palace)
face.CFrame = CFrame.new(0, bookY, pz - 4.4) * CFrame.Angles(math.rad(-12), 0, 0)
local diamond = part("BookDiamond", Vector3.new(9, 9, 0.6), Vector3.new(0, bookY, pz - 3.9), C.cyan, Enum.Material.Neon, palace)
diamond.CFrame = CFrame.new(0, bookY, pz - 3.9) * CFrame.Angles(math.rad(-12), 0, math.rad(45))
part("BookLeg", Vector3.new(4, 6, 4), Vector3.new(-12, 35, pz - 6), C.gold, Enum.Material.Metal, palace)
part("BookLeg", Vector3.new(4, 6, 4), Vector3.new(12, 35, pz - 6), C.gold, Enum.Material.Metal, palace)
local bl = Instance.new("PointLight"); bl.Range = 45; bl.Color = C.cyan; bl.Brightness = 2; bl.Parent = diamond

label(palace, "<b>قصر البطاقات الملكي</b>\nThe Last Arcana", Vector3.new(0, 62, pz), 340, 110)

-- grand stairs in front of the palace (down toward the plaza)
stairs(palace, 0, pz + 24, 26, 6, 0.5, 2, 1, 3)

------------------------------------------------------------------
-- 4) COMBAT ARENAS (2v2, 3v3, 1v1, 4v4)
------------------------------------------------------------------
local arenas = folder("Arenas")

local function makeTable(parent, center, chairs, isSquare)
	local m = Instance.new("Model"); m.Name = "DuelTable"; m.Parent = parent
	cyl("TableLeg", 1.2, 3, center + Vector3.new(0, 1.5, 0), C.dark, Enum.Material.Metal, m)
	cyl("TableTop", 7, 0.6, center + Vector3.new(0, 3.2, 0), C.wood, Enum.Material.Wood, m)
	cyl("TableFelt", 6, 0.2, center + Vector3.new(0, 3.55, 0), Color3.fromRGB(30, 90, 70), Enum.Material.Fabric, m)
	for i = 1, chairs do
		local a = (i / chairs) * math.pi * 2
		local pos = center + Vector3.new(math.cos(a) * 5.4, 0, math.sin(a) * 5.4)
		local cf = CFrame.lookAt(Vector3.new(pos.X, 0, pos.Z), Vector3.new(center.X, 0, center.Z))
		local seat = part("Seat", Vector3.new(2, 0.4, 2), pos + Vector3.new(0, 1.9, 0), C.wood, Enum.Material.Wood, m)
		seat.CFrame = cf * CFrame.new(0, 1.9, 0)
		local leg = part("ChairLeg", Vector3.new(0.5, 1.9, 0.5), pos + Vector3.new(0, 0.95, 0), C.dark, Enum.Material.Metal, m)
		leg.CFrame = cf * CFrame.new(0, 0.95, 0)
		local back = part("ChairBack", Vector3.new(2, 2.2, 0.4), pos, C.wood, Enum.Material.Wood, m)
		back.CFrame = cf * CFrame.new(0, 3.2, 1)
		-- a real Seat so players can sit (optional)
		local s = Instance.new("Seat")
		s.Name = "PlayerSeat"; s.Anchored = true; s.Size = Vector3.new(2, 0.2, 2)
		s.CFrame = cf * CFrame.new(0, 2.2, 0); s.Transparency = 1; s.Parent = m
	end
end

local function makeArena(name, cx, cz, chairs, arText, enText)
	local f = Instance.new("Folder"); f.Name = name; f.Parent = arenas
	-- raised border + floor
	part("ArenaBorder", Vector3.new(60, 0.8, 50), Vector3.new(cx, 0.4, cz), C.stoneD, Enum.Material.Slate, f)
	part("ArenaFloor", Vector3.new(57, 0.9, 47), Vector3.new(cx, 0.45, cz), Color3.fromRGB(214, 208, 196), Enum.Material.Marble, f)
	-- 5 tables: 2 top, 1 center, 2 bottom
	local offs = { Vector3.new(-15, 0.9, -12), Vector3.new(15, 0.9, -12), Vector3.new(0, 0.9, 0),
	               Vector3.new(-15, 0.9, 12), Vector3.new(15, 0.9, 12) }
	for _, o in ipairs(offs) do
		makeTable(f, Vector3.new(cx, 0, cz) + o, chairs)
	end
	label(f, string.format("<b>%s</b>\n%s", arText, enText), Vector3.new(cx, 22, cz - 8), 320, 120)
end

makeArena("Arena_2v2", -54, -20, 4, "منطقة مبارزات 2v2\n5 طاولات - 4 كراسي لكل طاولة", "2v2 Arena")
makeArena("Arena_3v3",  54, -20, 6, "منطقة مبارزات 3v3\n5 طاولات - 6 كراسي لكل طاولة", "3v3 Arena")
makeArena("Arena_1v1", -54,  52, 2, "منطقة مبارزات 1v1\n5 طاولات - كرسيان لكل طاولة", "1v1 Arena")
makeArena("Arena_4v4",  54,  52, 8, "منطقة مبارزات 4v4\n5 طاولات - 8 كراسي لكل طاولة", "4v4 Arena")

-- arena side stairs toward center paths
for _, sx in ipairs({ -1, 1 }) do
	stairs(arenas, sx * 22, 7 - 10, 8, 2, 0.4, 2, 1, 0.9)
end

------------------------------------------------------------------
-- 5) CENTER: Card Master Statue
------------------------------------------------------------------
local center = folder("CardMasterStatue")
cyl("OuterRing", 44, 0.8, Vector3.new(0, 0.4, 7), C.stoneD, Enum.Material.Marble, center)
cyl("InnerRing", 38, 1.0, Vector3.new(0, 0.5, 7), C.path, Enum.Material.Marble, center)
cyl("GoldRing", 30, 1.2, Vector3.new(0, 0.6, 7), C.gold, Enum.Material.Metal, center)
cyl("Pedestal", 24, 2.0, Vector3.new(0, 1.0, 7), C.white, Enum.Material.Marble, center)
cyl("PedestalTop", 14, 3, Vector3.new(0, 3.5, 7), C.stone, Enum.Material.Marble, center)
-- statue (robed figure)
cyl("Robe", 7, 11, Vector3.new(0, 10.5, 7), C.purple, Enum.Material.Fabric, center)
ball("Head", 3.2, Vector3.new(0, 17.6, 7), Color3.fromRGB(235, 215, 190), Enum.Material.SmoothPlastic, center)
part("Hood", Vector3.new(4, 3, 4), Vector3.new(0, 18.8, 7), C.purple, Enum.Material.Fabric, center)
part("Staff", Vector3.new(0.6, 24, 0.6), Vector3.new(5, 15, 7), C.gold, Enum.Material.Metal, center)
local orb = ball("StaffOrb", 2.2, Vector3.new(5, 27.5, 7), C.cyan, Enum.Material.Neon, center)
local ol = Instance.new("PointLight"); ol.Range = 40; ol.Color = C.cyan; ol.Brightness = 2; ol.Parent = orb
label(center, "<b>تمثال سيد البطاقات</b>\nCard Master Statue", Vector3.new(0, 33, 7), 280, 100)

------------------------------------------------------------------
-- 6) LEADERBOARD SCREENS (west & east)
------------------------------------------------------------------
local boards = folder("Leaderboards")
local function leaderboard(x, face)
	part("ScreenFrame", Vector3.new(3, 15, 27), Vector3.new(x, 8.5, 7), C.dark, Enum.Material.Metal, boards)
	local screen = part("Screen", Vector3.new(0.6, 12, 24), Vector3.new(x + (face == Enum.NormalId.Right and 1.5 or -1.5), 8.5, 7), Color3.fromRGB(15, 18, 28), Enum.Material.SmoothPlastic, boards)
	part("ScreenBase", Vector3.new(6, 1, 30), Vector3.new(x, 0.5, 7), C.stoneD, Enum.Material.Slate, boards)
	local sg = Instance.new("SurfaceGui")
	sg.Face = face
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = 40
	sg.Parent = screen
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 1
	t.TextScaled = true
	t.RichText = true
	t.Font = Enum.Font.GothamBold
	t.TextColor3 = C.cyan
	t.Text = "<b>LEADERBOARD</b>\nشاشة المتصدرين\n\n1. ---\n2. ---\n3. ---"
	t.Parent = sg
end
leaderboard(-88, Enum.NormalId.Right)  -- west board faces east
leaderboard(88, Enum.NormalId.Left)    -- east board faces west
label(boards, "<b>شاشة المتصدرين</b>\n(Leaderboard)", Vector3.new(-88, 20, 7), 240, 90)
label(boards, "<b>شاشة المتصدرين</b>\n(Leaderboard)", Vector3.new(88, 20, 7), 240, 90)

------------------------------------------------------------------
-- 7) WATER POOLS + WATERFALLS
------------------------------------------------------------------
local water = folder("Water")
local function pool(x, z, w, d, fallDir)
	part("PoolRim", Vector3.new(w + 3, 1.2, d + 3), Vector3.new(x, 0.6, z), C.stoneD, Enum.Material.Slate, water)
	local wp = part("Water", Vector3.new(w, 0.8, d), Vector3.new(x, 1.0, z), C.water, Enum.Material.Glass, water)
	wp.Transparency = 0.35
	wp.CanCollide = false
	if fallDir then
		-- thin waterfall plane running over the island edge
		local f = part("Waterfall", Vector3.new(fallDir.X ~= 0 and 1 or w - 2, 30, fallDir.Z ~= 0 and 1 or d - 2),
			Vector3.new(x + fallDir.X * (w / 2 + 1), -14, z + fallDir.Z * (d / 2 + 1)), Color3.fromRGB(220, 240, 255), Enum.Material.Glass, water)
		f.Transparency = 0.4
		f.CanCollide = false
	end
end
pool(-88, -72, 26, 22, Vector3.new(0, -1))  -- NW
pool( 88, -72, 26, 22, Vector3.new(0, -1))  -- NE
pool(-45,  96, 28, 14, Vector3.new(0, 1))   -- SW
pool( 45,  96, 28, 14, Vector3.new(0, 1))   -- SE
pool(-100, 52, 10, 30, Vector3.new(-1, 0))  -- W side
pool( 100, 52, 10, 30, Vector3.new(1, 0))   -- E side

------------------------------------------------------------------
-- 8) BRIDGES (west & east)
------------------------------------------------------------------
local bridges = folder("Bridges")
for _, sx in ipairs({ -1, 1 }) do
	local x0 = sx * 116
	part("BridgeDeck", Vector3.new(26, 1, 8), Vector3.new(x0, -0.5, -5), C.wood, Enum.Material.WoodPlanks, bridges)
	for _, sz in ipairs({ -4.2, 4.2 }) do
		part("BridgeRail", Vector3.new(26, 2.5, 0.6), Vector3.new(x0, 1.2, -5 + sz), C.wood, Enum.Material.Wood, bridges)
	end
	for i = -2, 2 do
		part("BridgePost", Vector3.new(0.8, 3.5, 0.8), Vector3.new(x0 + i * 6, 1.6, -9.2), C.dark, Enum.Material.Wood, bridges)
		part("BridgePost", Vector3.new(0.8, 3.5, 0.8), Vector3.new(x0 + i * 6, 1.6, -0.8), C.dark, Enum.Material.Wood, bridges)
	end
	lamp(bridges, sx * 128, -10)
end

------------------------------------------------------------------
-- 9) SPAWN POINT (south)
------------------------------------------------------------------
local spawnF = folder("Spawn")
cyl("SpawnDisc", 22, 0.6, Vector3.new(0, 0.3, 98), C.stoneD, Enum.Material.Marble, spawnF)
cyl("CompassRing", 17, 0.7, Vector3.new(0, 0.4, 98), C.gold, Enum.Material.Metal, spawnF)
cyl("CompassFloor", 15, 0.8, Vector3.new(0, 0.45, 98), C.path, Enum.Material.Marble, spawnF)
part("CompassNS", Vector3.new(1, 0.9, 14), Vector3.new(0, 0.5, 98), C.cyan, Enum.Material.Neon, spawnF)
part("CompassEW", Vector3.new(14, 0.9, 1), Vector3.new(0, 0.5, 98), C.cyan, Enum.Material.Neon, spawnF)
part("CompassNS2", Vector3.new(1, 0.9, 14), Vector3.new(0, 0.5, 98), C.cyan, Enum.Material.Neon, spawnF, 45)
part("CompassEW2", Vector3.new(14, 0.9, 1), Vector3.new(0, 0.5, 98), C.cyan, Enum.Material.Neon, spawnF, 45)

local spawn = Instance.new("SpawnLocation")
spawn.Name = "PlayerSpawn"
spawn.Anchored = true
spawn.Size = Vector3.new(8, 1, 8)
spawn.Position = Vector3.new(0, 1.2, 98)
spawn.Color = C.gold
spawn.Material = Enum.Material.Neon
spawn.Transparency = 0.5
spawn.Duration = 0
spawn.Parent = spawnF

-- arrow pointing north
part("ArrowShaft", Vector3.new(2, 0.3, 8), Vector3.new(0, 0.5, 82), C.dark, Enum.Material.SmoothPlastic, spawnF)
local head = Instance.new("WedgePart")
head.Anchored = true; head.Size = Vector3.new(6, 0.3, 4); head.Color = C.dark
head.CFrame = CFrame.new(0, 0.5, 76) * CFrame.Angles(0, math.rad(180), 0)
head.Parent = spawnF
label(spawnF, "<b>نقطة ظهور اللاعبين</b>\n(Spawn Point)", Vector3.new(0, 16, 98), 280, 100)

-- banners flanking spawn
for _, sx in ipairs({ -1, 1 }) do
	part("BannerPole", Vector3.new(0.6, 16, 0.6), Vector3.new(sx * 14, 8, 88), C.dark, Enum.Material.Metal, spawnF)
	part("Banner", Vector3.new(5, 10, 0.4), Vector3.new(sx * 14, 10, 88), C.purple, Enum.Material.Fabric, spawnF)
	part("BannerEmblem", Vector3.new(2, 2, 0.3), Vector3.new(sx * 14, 11, 88.3), C.gold, Enum.Material.Neon, spawnF, 45)
end

-- stairs near the spawn pools
for _, sx in ipairs({ -1, 1 }) do
	stairs(spawnF, sx * 12, 90, 8, 2, 0.3, 2, 1, 0.6)
end

------------------------------------------------------------------
-- 10) DECORATION: lamps, planters, trees
------------------------------------------------------------------
local deco = folder("Decoration")

-- lamps along the central path
for z = -45, 100, 18 do
	lamp(deco, -10, z)
	lamp(deco, 10, z)
end
-- lamps along the east-west path
for x = -90, 90, 20 do
	if math.abs(x) > 24 then lamp(deco, x, 15) end
end
-- palace corner lamps
for _, sx in ipairs({ -1, 1 }) do lamp(deco, sx * 52, -58) end

-- planters beside the central path (north of statue and south of statue)
for _, sx in ipairs({ -1, 1 }) do
	planter(deco, sx * 15, -40, 6, 22)
	planter(deco, sx * 15, 40, 6, 22)
	planter(deco, sx * 31, 25, 4, 10)
	planter(deco, sx * 31, -2, 4, 10)
end

-- trees
local treeSpots = {
	{-92,-45},{-80,-92},{-70,-95},{-96,-20},{-96, 10},{-90, 75},{-75,100},
	{ 92,-45},{ 80,-92},{ 70,-95},{ 96,-20},{ 96, 10},{ 90, 75},{ 75,100},
	{-22,-30},{ 22,-30},{-22, 35},{ 22, 35},{-24, 65},{ 24, 65},
}
for _, t in ipairs(treeSpots) do tree(deco, t[1], t[2], 0.9 + math.random() * 0.4) end

------------------------------------------------------------------
-- 11) TITLE SIGN + FINAL SCALE
------------------------------------------------------------------
label(map, "<b>ECHOBOUND</b>", Vector3.new(0, 78, pz), 360, 90)

-- Scale everything (spawn included) so it feels right for Roblox characters
map:ScaleTo(SCALE)

print("Echobound map built successfully ✔  (scale x" .. SCALE .. ")")
