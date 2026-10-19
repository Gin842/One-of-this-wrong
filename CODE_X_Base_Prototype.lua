-- CODE X | BASE PROTOTYPE v1
-- Put this Script in ServerScriptService and press Play.
-- It only creates/refreshes Workspace.CODE_X_BASE_PROTOTYPE.
-- Built from Roblox parts only: no external assets required.

local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")

local ROOT_NAME = "CODE_X_BASE_PROTOTYPE"
local old = Workspace:FindFirstChild(ROOT_NAME)
if old then old:Destroy() end

local root = Instance.new("Model")
root.Name = ROOT_NAME
root.Parent = Workspace

local C = {
    obsidian = Color3.fromRGB(25, 24, 34),
    stone = Color3.fromRGB(66, 61, 74),
    stoneLight = Color3.fromRGB(105, 97, 116),
    paleStone = Color3.fromRGB(143, 133, 150),
    red = Color3.fromRGB(224, 42, 73),
    redDark = Color3.fromRGB(105, 24, 46),
    purple = Color3.fromRGB(156, 91, 255),
    purpleDark = Color3.fromRGB(67, 43, 105),
    gold = Color3.fromRGB(239, 191, 96),
    metal = Color3.fromRGB(123, 128, 145),
    white = Color3.fromRGB(236, 231, 245),
    floor = Color3.fromRGB(49, 46, 59),
    warm = Color3.fromRGB(255, 130, 65),
}

local function part(name, size, cf, color, material, parent, shape)
    local p = Instance.new("Part")
    p.Name = name
    p.Anchored = true
    p.Size = size
    p.CFrame = cf
    p.Color = color or C.stone
    p.Material = material or Enum.Material.Slate
    p.TopSurface = Enum.SurfaceType.Smooth
    p.BottomSurface = Enum.SurfaceType.Smooth
    p.CastShadow = true
    if shape then p.Shape = shape end
    p.Parent = parent or root
    return p
end

local function box(name, x, y, z, sx, sy, sz, color, material, parent)
    return part(name, Vector3.new(sx, sy, sz), CFrame.new(x, y, z), color, material, parent)
end

local function localBox(name, center, x, y, z, sx, sy, sz, color, material, parent, yaw)
    local cf = center * CFrame.new(x, y, z) * CFrame.Angles(0, math.rad(yaw or 0), 0)
    return part(name, Vector3.new(sx, sy, sz), cf, color, material, parent)
end

local function glow(name, x, y, z, sx, sy, sz, color, parent, material)
    local p = box(name, x, y, z, sx, sy, sz, color, material or Enum.Material.Neon, parent)
    p.CastShadow = false
    return p
end

local function lightOn(p, color, brightness, range)
    local l = Instance.new("PointLight")
    l.Color = color
    l.Brightness = brightness or 1.2
    l.Range = range or 18
    l.Shadows = false
    l.Parent = p
    return l
end

local function label(name, text, pos, width, height, color)
    local anchor = box(name .. "_Anchor", pos.X, pos.Y, pos.Z, 0.2, 0.2, 0.2, C.obsidian, Enum.Material.SmoothPlastic)
    anchor.Transparency = 1
    anchor.CanCollide = false
    anchor.CastShadow = false
    local gui = Instance.new("BillboardGui")
    gui.Name = name .. "_Billboard"
    gui.Size = UDim2.fromOffset(width or 280, height or 60)
    gui.StudsOffset = Vector3.new(0, 0, 0)
    gui.AlwaysOnTop = false
    gui.MaxDistance = 220
    gui.Parent = anchor
    local txt = Instance.new("TextLabel")
    txt.Size = UDim2.fromScale(1, 1)
    txt.BackgroundTransparency = 1
    txt.Text = text
    txt.TextColor3 = color or C.white
    txt.TextStrokeColor3 = C.obsidian
    txt.TextStrokeTransparency = 0.2
    txt.Font = Enum.Font.GothamBlack
    txt.TextScaled = true
    txt.Parent = gui
    return anchor
end

local function pillar(name, x, z, height, width, color)
    box(name .. "_Foot", x, 0.9, z, width + 1.2, 1.2, width + 1.2, C.obsidian, Enum.Material.Slate)
    box(name .. "_Shaft", x, 1.2 + height/2, z, width, height, width, color or C.stoneLight, Enum.Material.Slate)
    box(name .. "_BaseBand", x, 1.8, z, width + 0.45, 0.55, width + 0.45, C.metal, Enum.Material.Metal)
    box(name .. "_Cap", x, height + 1.8, z, width + 1.1, 0.85, width + 1.1, C.stoneLight, Enum.Material.Slate)
    glow(name .. "_Rune", x, height/2 + 1.2, z - width/2 - 0.035, 0.16, height*0.48, 0.08, C.purple)
end

local function signPanel(name, text, x, y, z, width, color)
    box(name .. "_Backing", x, y, z, width, 5, 1, C.obsidian, Enum.Material.Metal)
    box(name .. "_TrimTop", x, y + 2.65, z - 0.56, width + 0.8, 0.22, 0.18, C.gold, Enum.Material.Metal)
    box(name .. "_TrimBottom", x, y - 2.65, z - 0.56, width + 0.8, 0.22, 0.18, C.gold, Enum.Material.Metal)
    label(name, text, Vector3.new(x, y, z - 0.7), width * 14, 70, color or C.white)
end

-- Ground and foundation -------------------------------------------------------
box("Foundation_Shadow", 0, -1.2, 0, 116, 2.5, 104, C.obsidian, Enum.Material.Basalt)
box("Foundation_Main", 0, 0, 0, 112, 2, 100, C.stone, Enum.Material.Slate)
box("Foundation_Inset", 0, 1.05, 0, 106, 0.25, 94, C.floor, Enum.Material.Concrete)

-- Edge bands, corner caps and floor inlay
for _, z in ipairs({-47, 47}) do
    box("Perimeter_GoldLine", 0, 1.22, z, 103, 0.12, 0.35, C.gold, Enum.Material.Metal)
    box("Perimeter_RedLine", 0, 1.24, z + (z < 0 and 0.65 or -0.65), 100, 0.08, 0.18, C.red, Enum.Material.Neon)
end
for _, x in ipairs({-53, 53}) do
    box("Perimeter_SideTrim", x, 1.22, 0, 0.35, 0.12, 91, C.gold, Enum.Material.Metal)
end
for _, x in ipairs({-51, 51}) do
    for _, z in ipairs({-45, 45}) do
        box("Corner_Inset", x, 1.24, z, 3.5, 0.14, 3.5, C.redDark, Enum.Material.Metal)
        box("Corner_Gem", x, 1.38, z, 1.1, 0.16, 1.1, C.purple, Enum.Material.Neon)
    end
end

-- Large central crest / floor medallion --------------------------------------
local medallion = part("Floor_Crest_Base", Vector3.new(27, 0.18, 27), CFrame.new(0, 1.24, 13), C.obsidian, Enum.Material.Metal, root, Enum.PartType.Cylinder)
medallion.Orientation = Vector3.new(0, 0, 90)
-- Diamond rings around the crest
for i, s in ipairs({23, 18, 12}) do
    local col = (i == 2) and C.gold or C.red
    local barLen = s
    local t = 0.22
    local y = 1.42 + i*0.015
    local a = box("Crest_DiamondA", 0, y, 13, barLen, t, 0.22, col, Enum.Material.Neon)
    a.CFrame = a.CFrame * CFrame.Angles(0, math.rad(45), 0)
    local b = box("Crest_DiamondB", 0, y + 0.01, 13, barLen, t, 0.22, col, Enum.Material.Neon)
    b.CFrame = b.CFrame * CFrame.Angles(0, math.rad(-45), 0)
end
box("Crest_Core", 0, 1.55, 13, 3.8, 0.24, 3.8, C.purpleDark, Enum.Material.Metal)
local core = box("Crest_Core_Glow", 0, 1.7, 13, 1.8, 0.16, 1.8, C.purple, Enum.Material.Neon)
lightOn(core, C.purple, 1.1, 20)

-- Entrance gate on the front (positive Z) ------------------------------------
box("Gate_Threshold", 0, 1.35, 43, 24, 0.5, 5, C.obsidian, Enum.Material.Metal)
box("Gate_Threshold_Glow", 0, 1.62, 43, 19, 0.12, 2.8, C.red, Enum.Material.Neon)
pillar("Gate_Left", -12, 40, 15, 3.5, C.stoneLight)
pillar("Gate_Right", 12, 40, 15, 3.5, C.stoneLight)
box("Gate_Lintel", 0, 17.2, 40, 29, 3.5, 4.5, C.stoneLight, Enum.Material.Slate)
box("Gate_Lintel_Upper", 0, 19.4, 40, 25, 1, 3.8, C.obsidian, Enum.Material.Metal)
box("Gate_Lintel_Gold", 0, 17.5, 37.7, 23, 0.24, 0.16, C.gold, Enum.Material.Neon)
box("Gate_Crest_Back", 0, 17.5, 37.5, 5.2, 4.8, 0.7, C.redDark, Enum.Material.Metal)
box("Gate_Crest_Core", 0, 17.5, 37.05, 2.5, 2.5, 0.25, C.purple, Enum.Material.Neon)
lightOn(Workspace:FindFirstChild(ROOT_NAME):FindFirstChild("Gate_Crest_Core"), C.purple, 1.8, 24)
signPanel("Main_Sign", "CODE X  •  PRIVATE SANCTUM", 0, 12.5, 36.9, 22, C.white)

-- Entrance torches ------------------------------------------------------------
for _, x in ipairs({-17, 17}) do
    local sconce = box("Gate_Sconce", x, 6.2, 35.5, 1.3, 2.2, 1.3, C.obsidian, Enum.Material.Metal)
    box("Gate_Flame", x, 7.8, 35.5, 0.7, 1.1, 0.7, C.warm, Enum.Material.Neon)
    lightOn(sconce, C.warm, 1.3, 16)
end

-- Forge zone, left side --------------------------------------------------------
box("Forge_Platform", -31, 1.42, -9, 34, 0.55, 31, C.obsidian, Enum.Material.Metal)
box("Forge_Floor", -31, 1.73, -9, 31, 0.18, 28, C.stoneLight, Enum.Material.Slate)
for _, x in ipairs({-44, -18}) do
    pillar("Forge_Pillar", x, -21, 8, 2.3, C.stoneLight)
end
box("Forge_BackWall", -31, 7.2, -22.5, 29, 11, 1.6, C.stone, Enum.Material.Slate)
box("Forge_Wall_Inset", -31, 7.2, -21.55, 20, 7, 0.18, C.obsidian, Enum.Material.Metal)
box("Forge_Rune_Line", -31, 7.2, -21.4, 16, 0.18, 0.12, C.gold, Enum.Material.Neon)
-- furnace body and glowing opening
box("Forge_Furnace_Base", -31, 3.1, -18, 8, 3.2, 5.5, C.obsidian, Enum.Material.Basalt)
box("Forge_Furnace_Stone", -31, 5.3, -18, 7, 2.2, 5, C.stoneLight, Enum.Material.Slate)
box("Forge_Furnace_Opening", -31, 4.6, -15.42, 3.8, 2.5, 0.18, C.warm, Enum.Material.Neon)
box("Forge_Furnace_Mouth", -31, 4.6, -15.25, 2.2, 1.25, 0.1, C.redDark, Enum.Material.Metal)
local forgeGlow = box("Forge_Ember", -31, 4.6, -15.12, 1.1, 0.55, 0.08, C.warm, Enum.Material.Neon)
lightOn(forgeGlow, C.warm, 2.2, 22)
box("Forge_Chimney", -31, 10.2, -20.1, 3.5, 5.5, 3.5, C.stone, Enum.Material.Slate)
box("Forge_Chimney_Cap", -31, 13.1, -20.1, 4.5, 0.6, 4.5, C.obsidian, Enum.Material.Metal)
-- Anvil and work table
box("Forge_Workbench", -24.5, 2.9, -6.5, 7, 1.2, 2.6, C.stone, Enum.Material.WoodPlanks)
box("Forge_Anvil_Stand", -24.5, 3.65, -6.5, 1.8, 1.1, 1.8, C.obsidian, Enum.Material.Metal)
box("Forge_Anvil", -24.5, 4.35, -6.5, 3.3, 0.6, 1.5, C.metal, Enum.Material.Metal)
box("Forge_Anvil_Horn", -22.4, 4.4, -6.5, 1.2, 0.35, 0.6, C.metal, Enum.Material.Metal)
-- Weapon display wall
for i = 1, 5 do
    local x = -40 + (i-1)*4.4
    box("Weapon_Rack", x, 4.8, -22.0, 0.22, 4.4, 0.28, C.gold, Enum.Material.Metal)
    local blade = box("Display_Sword_Blade", x, 5.4, -21.65, 0.32, 2.7, 0.12, (i%2==0) and C.purple or C.metal, Enum.Material.Metal)
    blade.CFrame = blade.CFrame * CFrame.Angles(0, 0, math.rad((i%2==0) and 10 or -10))
    box("Display_Sword_Handle", x, 3.8, -21.65, 0.38, 0.85, 0.2, C.redDark, Enum.Material.Wood)
end
signPanel("Forge_Sign", "FORGE  /  UPGRADE", -31, 12.8, -21.2, 15, C.gold)

-- Armour mannequins / display stands -----------------------------------------
for i, x in ipairs({-43, -35, -27, -19}) do
    local z = 3
    local pedestal = part("Armour_Pedestal", Vector3.new(3.8, 0.8, 3.8), CFrame.new(x, 2.2, z), C.obsidian, Enum.Material.Metal, root, Enum.PartType.Cylinder)
    pedestal.Orientation = Vector3.new(0, 0, 90)
    box("Armour_Bust", x, 4.2, z, 1.8, 2.1, 1.1, (i%2==0) and C.purpleDark or C.redDark, Enum.Material.Metal)
    box("Armour_ShoulderL", x-1.1, 4.8, z, 0.9, 0.8, 1.25, C.metal, Enum.Material.Metal)
    box("Armour_ShoulderR", x+1.1, 4.8, z, 0.9, 0.8, 1.25, C.metal, Enum.Material.Metal)
    box("Armour_Chest_Gem", x, 4.4, z-0.62, 0.4, 0.55, 0.16, C.gold, Enum.Material.Neon)
end

-- Obby zone, right side --------------------------------------------------------
box("Obby_Platform", 29, 1.42, -10, 42, 0.55, 69, C.obsidian, Enum.Material.Metal)
box("Obby_Floor", 29, 1.73, -10, 39, 0.18, 66, C.floor, Enum.Material.Concrete)
-- Framed boundary, leaves an open top so it doesn't feel boxed in
for _, x in ipairs({8.5, 49.5}) do
    box("Obby_Edge_Trim", x, 2.0, -10, 0.3, 0.25, 65, C.gold, Enum.Material.Metal)
end
for _, z in ipairs({-43, 23}) do
    box("Obby_Edge_Trim", 29, 2.0, z, 40, 0.25, 0.3, C.gold, Enum.Material.Metal)
end
signPanel("Obby_Sign", "TRIAL OF THE VOID", 29, 10.5, 22.5, 16, C.purple)
-- Starting dais
box("Obby_Start_Base", 29, 2.25, 17, 10, 0.9, 7, C.stoneLight, Enum.Material.Slate)
box("Obby_Start_Glow", 29, 2.75, 17, 7, 0.12, 4.5, C.purple, Enum.Material.Neon)
-- Parkour path with alternating steps and rune marks
local obbySteps = {
    {29, 3.5, 9, 7, 0.9, 5, C.purpleDark},
    {22, 4.8, 2, 6, 0.8, 5, C.stoneLight},
    {35, 6.1, -5, 6, 0.8, 5, C.redDark},
    {25, 7.4, -12, 5.5, 0.8, 5, C.purpleDark},
    {37, 8.7, -19, 5.5, 0.8, 5, C.stoneLight},
    {27, 10.0, -26, 5.5, 0.8, 5, C.redDark},
    {36, 11.3, -33, 6, 0.8, 5, C.purpleDark},
}
for i, v in ipairs(obbySteps) do
    box("Obby_Step_"..i, v[1], v[2], v[3], v[4], v[5], v[6], v[7], Enum.Material.Slate)
    box("Obby_Step_Rune_"..i, v[1], v[2] + v[5]/2 + 0.08, v[3], v[4]*0.62, 0.08, 0.12, (i%2==0) and C.gold or C.purple, Enum.Material.Neon)
end
-- Goal platform and reward marker
box("Obby_Goal_Base", 29, 12.5, -41, 12, 1, 8, C.stoneLight, Enum.Material.Slate)
box("Obby_Goal_Rune", 29, 13.1, -41, 8, 0.14, 5, C.gold, Enum.Material.Neon)
for _, x in ipairs({24, 34}) do
    pillar("Obby_Goal_Pillar", x, -41, 7, 1.5, C.stoneLight)
end
local reward = box("Obby_Reward_Crystal", 29, 16.3, -41, 2, 4.2, 2, C.purple, Enum.Material.Neon)
reward.CFrame = reward.CFrame * CFrame.Angles(0, 0, math.rad(45))
lightOn(reward, C.purple, 1.4, 18)

-- Upper Code Gallery at the back ----------------------------------------------
-- Two supporting towers, rear wall, balcony and raised floor
for _, x in ipairs({-23, 23}) do
    pillar("Gallery_Support", x, -35, 12, 3.2, C.stoneLight)
end
box("Gallery_Floor_Shadow", 0, 13.2, -32, 51, 1.6, 26, C.obsidian, Enum.Material.Metal)
box("Gallery_Floor", 0, 14.1, -32, 48, 0.35, 23, C.stoneLight, Enum.Material.Slate)
box("Gallery_BackWall", 0, 21, -44, 47, 13.5, 1.8, C.stone, Enum.Material.Slate)
box("Gallery_Wall_Inset", 0, 21, -42.95, 36, 9.5, 0.2, C.obsidian, Enum.Material.Metal)
box("Gallery_Rune_Line", 0, 21, -42.78, 30, 0.2, 0.12, C.purple, Enum.Material.Neon)
box("Gallery_Balcony_Front", 0, 15.3, -20.8, 47, 1.3, 1.2, C.obsidian, Enum.Material.Metal)
box("Gallery_Balcony_Gold", 0, 16.0, -20.1, 45, 0.16, 0.15, C.gold, Enum.Material.Neon)
-- Staircase rising from the front court to the gallery
for i = 1, 8 do
    local y = 2.0 + i*1.45
    local z = -8 - i*1.55
    box("Gallery_Stair_"..i, 0, y, z, 12, 0.55, 2.4, (i%2==0) and C.stoneLight or C.stone, Enum.Material.Slate)
    box("Gallery_Stair_Rune_"..i, 0, y+0.3, z-0.9, 8, 0.07, 0.12, C.purple, Enum.Material.Neon)
end
-- Display plinths for future owned Codes
for i, x in ipairs({-17, -8.5, 0, 8.5, 17}) do
    local plinth = part("Code_Display_Plinth", Vector3.new(4.5, 0.8, 4.5), CFrame.new(x, 14.75, -31), C.obsidian, Enum.Material.Metal, root, Enum.PartType.Cylinder)
    plinth.Orientation = Vector3.new(0, 0, 90)
    box("Code_Display_Rim", x, 15.2, -31, 3.7, 0.16, 3.7, C.gold, Enum.Material.Metal)
    local crystal = box("Code_Display_Crystal", x, 17.1, -31, 1.4, 3.2, 1.4, (i%2==0) and C.red or C.purple, Enum.Material.Neon)
    crystal.CFrame = crystal.CFrame * CFrame.Angles(0, math.rad(45), math.rad(8))
    lightOn(crystal, (i%2==0) and C.red or C.purple, 0.7, 12)
end
signPanel("Gallery_Sign", "CODE GALLERY  /  EQUIP", 0, 23.8, -42.5, 20, C.gold)

-- Small side shrines and decorative crystals ---------------------------------
for _, data in ipairs({{-49,-17,C.red},{-49,18,C.purple},{49,-17,C.purple},{49,18,C.red}}) do
    local x, z, col = data[1], data[2], data[3]
    box("Side_Shrine_Base", x, 2.0, z, 4.8, 1.1, 4.8, C.obsidian, Enum.Material.Metal)
    box("Side_Shrine_Stone", x, 3.2, z, 3.4, 1.8, 3.4, C.stoneLight, Enum.Material.Slate)
    local gem = box("Side_Shrine_Gem", x, 5.1, z, 1.1, 2.6, 1.1, col, Enum.Material.Neon)
    gem.CFrame = gem.CFrame * CFrame.Angles(0, 0, math.rad(45))
    lightOn(gem, col, 0.65, 12)
end

-- Light poles around the base (low-cost point lights, no shadows) -------------
for _, x in ipairs({-49, -8, 8, 49}) do
    for _, z in ipairs({-3, 30}) do
        box("Lantern_Post", x, 4.0, z, 0.75, 5.2, 0.75, C.obsidian, Enum.Material.Metal)
        box("Lantern_Cap", x, 6.6, z, 1.5, 0.55, 1.5, C.gold, Enum.Material.Metal)
        local lamp = box("Lantern_Glow", x, 5.8, z, 0.55, 0.75, 0.55, (z < 0) and C.purple or C.red, Enum.Material.Neon)
        lightOn(lamp, (z < 0) and C.purple or C.red, 0.65, 13)
    end
end

-- Spawn point for testing; move this when the final game flow is added ---------
local spawn = Instance.new("SpawnLocation")
spawn.Name = "PrototypeSpawn"
spawn.Size = Vector3.new(5, 0.5, 5)
spawn.CFrame = CFrame.new(0, 2.4, 34)
spawn.Anchored = true
spawn.Neutral = true
spawn.Duration = 0
spawn.Material = Enum.Material.Metal
spawn.Color = C.gold
spawn.Transparency = 0.15
spawn.Parent = root

-- Soft, readable atmosphere. These settings are global while this prototype runs.
Lighting.ClockTime = 18.3
Lighting.Brightness = 2.4
Lighting.Ambient = Color3.fromRGB(100, 88, 119)
Lighting.OutdoorAmbient = Color3.fromRGB(76, 69, 91)
Lighting.EnvironmentDiffuseScale = 0.55
Lighting.EnvironmentSpecularScale = 0.45
Lighting.FogColor = Color3.fromRGB(82, 61, 101)
Lighting.FogStart = 180
Lighting.FogEnd = 650

local atmosphere = Lighting:FindFirstChild("CODE_X_Atmosphere")
if not atmosphere then
    atmosphere = Instance.new("Atmosphere")
    atmosphere.Name = "CODE_X_Atmosphere"
    atmosphere.Parent = Lighting
end
atmosphere.Density = 0.22
atmosphere.Offset = 0.05
atmosphere.Color = Color3.fromRGB(190, 163, 220)
atmosphere.Decay = Color3.fromRGB(85, 42, 88)
atmosphere.Glare = 0.08
atmosphere.Haze = 1.1

print("CODE X Base Prototype generated. Model: Workspace." .. ROOT_NAME)
