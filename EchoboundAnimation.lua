--[[
    ECHOBOUND - ANIMATION  (client)
    ===============================
    Put this file in StarterPlayer > StarterPlayerScripts as a LocalScript.
    It animates the card island on each player's own screen (so it costs the server nothing):
      - floating cards orbit the giant book and the Card Master statue
      - magic rings spin around the book
      - the Card Master's card spins
      - distant islands drift up and down
      - waterfalls flow
      - lanterns flicker softly
]]

local RunService        = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local Workspace         = game:GetService("Workspace")

local map = Workspace:WaitForChild("EchoboundMap", 120)
if not map then return end
while not map:GetAttribute("Built") do task.wait(0.25) end

local rings, cards, spins, isles, flows, flames = {}, {}, {}, {}, {}, {}

local function collect(tag, fn)
	for _, obj in ipairs(CollectionService:GetTagged(tag)) do
		if obj:IsDescendantOf(map) then fn(obj) end
	end
end

collect("EB_Ring", function(m)
	table.insert(rings, { m = m, base = m:GetPivot(), speed = m:GetAttribute("Speed") or 0.3 })
end)

collect("EB_Card", function(p)
	local center = p:GetAttribute("Center")
	if center then
		table.insert(cards, {
			p = p, cf0 = p.CFrame, center = center,
			speed = p:GetAttribute("Speed") or 0.2,
			phase = p:GetAttribute("Phase") or 0,
			amp = p:GetAttribute("Amp") or 3,
		})
	end
end)

collect("EB_Spin", function(p)
	table.insert(spins, { p = p, cf0 = p.CFrame, speed = p:GetAttribute("Speed") or 1 })
end)

collect("EB_Island", function(m)
	table.insert(isles, { m = m, base = m:GetPivot(), phase = m:GetAttribute("Phase") or 0 })
end)

collect("EB_Flow", function(tx)
	table.insert(flows, { tx = tx, speed = tx:GetAttribute("Speed") or 12 })
end)

collect("EB_Flame", function(l)
	table.insert(flames, { l = l, base = l:GetAttribute("Base") or l.Brightness, ph = math.random() * 100 })
end)

local t0 = os.clock()
RunService.Heartbeat:Connect(function()
	local t = os.clock() - t0

	for _, r in ipairs(rings) do
		r.m:PivotTo(r.base * CFrame.Angles(0, t * r.speed, 0))
	end

	for _, c in ipairs(cards) do
		local orbit = CFrame.new(c.center) * CFrame.Angles(0, t * c.speed, 0) * CFrame.new(-c.center)
		c.p.CFrame = CFrame.new(0, math.sin(t * 1.1 + c.phase) * c.amp, 0) * orbit * c.cf0
	end

	for _, s in ipairs(spins) do
		s.p.CFrame = CFrame.new(0, math.sin(t * 1.4) * 0.8, 0) * s.cf0 * CFrame.Angles(0, t * s.speed, 0)
	end

	for _, i in ipairs(isles) do
		i.m:PivotTo(i.base * CFrame.new(0, math.sin(t * 0.35 + i.phase) * 4, 0))
	end

	for _, f in ipairs(flows) do
		local tile = f.tx.StudsPerTileV
		f.tx.OffsetStudsV = -((t * f.speed) % tile)
	end

	for _, f in ipairs(flames) do
		f.l.Brightness = f.base * (0.9 + 0.2 * math.noise(t * 3, f.ph))
	end
end)
