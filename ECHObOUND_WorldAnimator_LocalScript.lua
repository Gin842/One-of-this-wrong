--[[
	ECHObOUND: CARD MASTER - WORLD ANIMATOR (client-side)
	-----------------------------------------------------
	INSTALL: In Studio, create a LocalScript inside
	         StarterPlayer > StarterPlayerScripts, name it "WorldAnimator",
	         and paste this whole file into it.

	- Runs only on each player's own device: zero server cost, no replication.
	- Only animates things NEAR the camera (clouds/floating rocks are throttled).
	- Mobile (touch, no keyboard) gets a shorter range and a lower update rate.
	- Works with StreamingEnabled (objects are picked up as they stream in).
	- Turn everything off at runtime:  workspace:SetAttribute("ECHO_AnimationsEnabled", false)
	  (all animated parts snap back to their original look)

	Animated:
	  Statue .......... 7 summoned cards orbit the raised hand and bob; summon ring,
	                    book sigil and halo glow pulse
	  Giant card ...... magic circle turns (rings counter-rotate), runes orbit, stars twinkle
	  Signs ........... A1-A4 floating signs bob gently
	  Tables .......... floating magic cards hover and spin; rune discs pulse
	  Castle .......... display cards hover/spin, chandelier cores + candle flames flicker,
	                    lottery balls jiggle inside their domes, gem/orb pulses
	  Waterfalls ...... foam streaks shimmer, sheets breathe
	  Sky ............. clouds drift around the island, floating rock fragments bob
]]

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")

------------------------------------------------------------------ CONFIG
local CFG = {
	StatueHandAxisXZ = Vector2.new(-10, 0.5), -- x,z of the statue's raised hand (matches the builder)
	NearRange = 170,         -- studs (PC)
	MobileNearRange = 90,    -- studs (phones/tablets)
	NearHz = 60,             -- update rate for nearby animation (PC)
	MobileNearHz = 30,
	FarHz = 10,              -- clouds + floating rocks (PC)
	MobileFarHz = 5,
	CloudDriftRadPerSec = 0.004,
	Folders = { "FloatingIsland", "FloatingCliffs", "WaterfallsAndPools", "OuterBridges", "RoyalCastle_LastArcana",
		"GiantSacredMonsterCard", "CentralPlaza", "CardMasterStatue", "MonsterCardGallery", "TournamentArena_1v1",
		"TournamentArena_2v2", "TournamentArena_3v3", "TournamentArena_4v4", "Leaderboard_West", "Leaderboard_East",
		"SpawnEntrance", "GardensAndLandscaping", "LightingAndEffects" },
}

local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
local NEAR = isMobile and CFG.MobileNearRange or CFG.NearRange
local NEAR2 = NEAR * NEAR
local nearStep = 1 / (isMobile and CFG.MobileNearHz or CFG.NearHz)
local farStep = 1 / (isMobile and CFG.MobileFarHz or CFG.FarHz)

------------------------------------------------------------------ REGISTRY
local items = {}                       -- [part] = item
local nearList, farList = {}, {}       -- active lists (rebuilt by refresh)
local phases = setmetatable({}, { __mode = "k" })

local function phaseFor(inst)
	local key = inst.Parent or inst
	if not phases[key] then phases[key] = math.random() * 6.2832 end
	return phases[key]
end

-- name -> { amplitude, frequency } for simple transparency pulses
local PULSE = {
	SummonRing = { 0.15, 1.4 }, BookSigil = { 0.2, 1.8 }, HaloGlow = { 0.2, 1.2 }, RuneDisc = { 0.15, 1.6 },
	DisplayHalo = { 0.2, 1.5 }, GateOrb = { 0.15, 1.3 }, SpireGem = { 0.2, 1.5 }, SpireOrb = { 0.15, 1.4 },
	ShrineOrb = { 0.2, 1.5 }, SideOrb = { 0.15, 1.3 }, FinialGem = { 0.2, 1.6 }, BuckleGem = { 0.2, 1.6 },
	ChestGem = { 0.2, 1.6 }, CornerJewel = { 0.2, 1.2 }, BackCard = { 0.15, 1.1 }, Core = { 0.15, 1.8 },
}

local function classify(inst)
	if items[inst] or not inst:IsA("BasePart") then return end
	local n = inst.Name
	local par = inst.Parent
	local pn = par and par.Name or ""
	local it

	if n == "Puff" or n == "EdgeCloud" or n == "CloudSea" then
		it = { mode = "cloud", far = true }
	elseif pn == "FloatingFragment" then
		it = { mode = "bob", far = true, amp = 1.3, spd = 0.45, phase = phaseFor(inst) }
	elseif pn == "FloatingCard" and inst:FindFirstAncestor("CardMasterStatue_Model") then
		it = { mode = "orbit", phase = phaseFor(inst) }
	elseif pn == "FloatingSign" then
		it = { mode = "bob", amp = 0.45, spd = 0.9, phase = phaseFor(inst) }
	elseif n == "MagicCard" or n == "MagicCardBorder" then
		it = { mode = "spinbob", amp = 0.2, spd = 1.3, rot = 0.8, phase = phaseFor(inst) }
	elseif n:sub(1, 15) == "FloatingDisplay" then
		it = { mode = "spinbob", amp = 0.25, spd = 1.1, rot = 0.5, phase = phaseFor(inst) }
	elseif n == "CapsuleBall" then
		it = { mode = "jiggle", phase = math.random() * 6.2832 }
	elseif pn == "GiantSacredMonsterCard" and n == "MagicCircleOuter" then
		it = { mode = "ring", dir = 1, spd = 0.25 }
	elseif pn == "GiantSacredMonsterCard" and n == "MagicCircleInner" then
		it = { mode = "ring", dir = -1, spd = 0.35 }
	elseif pn == "GiantSacredMonsterCard" and n == "CircleRune" then
		it = { mode = "runeorbit", spd = 0.25 }
	elseif pn == "GiantSacredMonsterCard" and n == "Star" then
		it = { mode = "twinkle", phase = math.random() * 6.2832, freq = 1.5 + math.random() * 2 }
	elseif n == "Flame" or n == "CandleFlame" then
		it = { mode = "flicker", phase = math.random() * 6.2832 }
	elseif pn == "Waterfall" and n == "Foam" then
		it = { mode = "pulse", amp = 0.2, freq = 4, phase = math.random() * 6.2832 }
	elseif pn == "Waterfall" and n == "Sheet" then
		it = { mode = "pulse", amp = 0.05, freq = 1.1, phase = math.random() * 6.2832 }
	elseif n:sub(1, 9) == "RuneInlay" then
		it = { mode = "pulse", amp = 0.15, freq = 1.2, phase = math.random() * 6.2832 }
	elseif PULSE[n] then
		it = { mode = "pulse", amp = PULSE[n][1], freq = PULSE[n][2], phase = math.random() * 6.2832 }
	end

	if it then
		it.part = inst; it.orig = inst.CFrame; it.pos = inst.Position; it.base = inst.Transparency
		items[inst] = it
	end
end

local function restore(it)
	local p = it.part
	if p.Parent then p.CFrame = it.orig; p.Transparency = it.base end
	if it.light then it.light.Brightness = it.lightBase end
end

------------------------------------------------------------------ ANIMATION STEP
local ax, az = CFG.StatueHandAxisXZ.X, CFG.StatueHandAxisXZ.Y
local axisCF = CFrame.new(ax, 0, az)
local axisInv = CFrame.new(-ax, 0, -az)

local function step(list, t)
	local parts, cfs, n = {}, {}, 0
	for i = 1, #list do
		local it = list[i]
		local p = it.part
		if p.Parent then
			local m, cf = it.mode, nil
			if m == "orbit" then
				cf = CFrame.new(0, math.sin(t * 1.1 + it.phase) * 0.35, 0) * axisCF * CFrame.Angles(0, t * 0.35, 0) * axisInv * it.orig
			elseif m == "bob" then
				cf = CFrame.new(0, math.sin(t * it.spd + it.phase) * it.amp, 0) * it.orig
			elseif m == "spinbob" then
				local pos = it.pos
				cf = CFrame.new(0, math.sin(t * it.spd + it.phase) * it.amp, 0) * CFrame.new(pos) * CFrame.Angles(0, t * it.rot + it.phase, 0) * CFrame.new(-pos) * it.orig
			elseif m == "jiggle" then
				local ph = it.phase
				cf = CFrame.new(math.sin(t * 2 + ph) * 0.35, math.cos(t * 2.6 + ph * 1.3) * 0.3, math.cos(t * 1.8 + ph) * 0.35) * it.orig
			elseif m == "cloud" then
				cf = CFrame.Angles(0, t * CFG.CloudDriftRadPerSec, 0) * it.orig
			elseif m == "ring" then
				cf = it.orig * CFrame.Angles(it.dir * t * it.spd, 0, 0)
			elseif m == "runeorbit" then
				local c = p.Parent:FindFirstChild("MagicCircleOuter")
				if c then
					local cp = c.Position
					cf = CFrame.new(cp) * CFrame.Angles(0, 0, -t * it.spd) * CFrame.new(-cp) * it.orig
				end
			elseif m == "pulse" then
				p.Transparency = math.clamp(it.base + math.sin(t * it.freq + it.phase) * it.amp, 0, 1)
				if p.Name == "Core" then
					if not it.light then
						it.light = p:FindFirstChildOfClass("PointLight")
						if it.light then it.lightBase = it.light.Brightness end
					end
					if it.light then it.light.Brightness = it.lightBase * (0.85 + 0.15 * math.sin(t * 2.3 + it.phase)) end
				end
			elseif m == "twinkle" then
				p.Transparency = 0.7 * (0.5 + 0.5 * math.sin(t * it.freq + it.phase))
			elseif m == "flicker" then
				p.Transparency = math.clamp(it.base + 0.2 + math.sin(t * 9 + it.phase) * math.sin(t * 5.3 + it.phase) * 0.2, 0, 1)
			end
			if cf then n += 1; parts[n] = p; cfs[n] = cf end
		end
	end
	if n > 0 then Workspace:BulkMoveTo(parts, cfs, Enum.BulkMoveMode.FireCFrameChanged) end
end

------------------------------------------------------------------ RANGE MANAGEMENT
local enabled = true
local function refresh()
	local on = Workspace:GetAttribute("ECHO_AnimationsEnabled") ~= false
	local cam = Workspace.CurrentCamera
	local cpos = cam and cam.CFrame.Position
	local nl, fl = {}, {}
	for part, it in pairs(items) do
		if not part.Parent then
			items[part] = nil
		else
			local active
			if not on then active = false
			elseif it.far then active = true
			elseif cpos then
				local d = it.pos - cpos
				active = d.X * d.X + d.Y * d.Y + d.Z * d.Z < NEAR2
			else active = false end

			if active then
				if it.far then fl[#fl + 1] = it else nl[#nl + 1] = it end
				it.wasActive = true
			elseif it.wasActive then
				restore(it); it.wasActive = false -- leave no part displaced when out of range
			end
		end
	end
	nearList, farList = nl, fl
	enabled = on
end

------------------------------------------------------------------ START
for _, name in ipairs(CFG.Folders) do
	local f = Workspace:FindFirstChild(name)
	if f then for _, d in ipairs(f:GetDescendants()) do classify(d) end end
end
Workspace.DescendantAdded:Connect(function(d) classify(d) end) -- picks up streamed-in parts
Workspace.DescendantRemoving:Connect(function(d) items[d] = nil end)

local accNear, accFar, accScan = 0, 0, 1
RunService.Heartbeat:Connect(function(dt)
	accScan += dt
	if accScan >= 0.4 then accScan = 0; refresh() end
	if not enabled then return end
	accNear += dt; accFar += dt
	local t = os.clock()
	if accNear >= nearStep then accNear = 0; step(nearList, t) end
	if accFar >= farStep then accFar = 0; step(farList, t) end
end)
