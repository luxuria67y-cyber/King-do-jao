--[[
  LEGACY FORTENESS v2  |  King Legacy  |  Roblox Mobile (Delta)
  Password: 180125
  Level farm follows the quest tracker on your screen ("Name [Lv. N]" + "Progress (0/1)"),
  the same thing the paid hubs read. Mobs are matched by name WITHOUT the [Lv. N] tag.
  If something does not detect: Misc > Copy debug dump.
]]

local env = (getgenv and getgenv()) or _G
if env.LF_Cleanup then pcall(env.LF_Cleanup) end

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local VirtualUser = game:GetService("VirtualUser")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local GuiService = game:GetService("GuiService")
local StatsService = game:GetService("Stats")
local CoreGui = game:GetService("CoreGui")
local VIM
pcall(function() VIM = game:GetService("VirtualInputManager") end)

local LP = Players.LocalPlayer
local rnd = Random.new()
local running = true
local conns = {}
local function bind(sig, fn)
	local c = sig:Connect(fn)
	conns[#conns + 1] = c
	return c
end

local gui -- created in the UI section
local notify = function() end -- replaced in the UI section

---------------------------------------------------------------- CONFIG
local cfg = {
	Farm = false, Mode = "Level", AutoQuest = true, QuestNPC = "", AutoEquip = true, Weapon = "Auto",
	MobName = "", BossName = "", Pos = "Above", Height = 9, Speed = 120,
	AttackMethod = "Both", AttackDelay = 0.12, Hitbox = false, HitboxSize = 14, Bring = false, BringRange = 40,
	SkZ = false, SkX = false, SkC = false, SkV = false, SkF = false, SkillDelay = 3,
	Noclip = false, InfJump = false, SpeedHack = false, WalkSpeed = 24, ESP = false, Safe = true,
	AntiVoid = true, Sniper = false, AutoHop = false,
}
local SAVE = { "Mode", "AutoQuest", "AutoEquip", "Weapon", "Pos", "Height", "Speed", "AttackMethod", "AttackDelay",
	"Hitbox", "HitboxSize", "Bring", "BringRange", "SkZ", "SkX", "SkC", "SkV", "SkF", "SkillDelay", "WalkSpeed",
	"Safe", "AntiVoid", "AutoHop" }
local FILE = "LegacyFortress_cfg.json"

local function saveCfg()
	if not writefile then return false end
	local t = {}
	for _, k in ipairs(SAVE) do t[k] = cfg[k] end
	return pcall(function() writefile(FILE, HttpService:JSONEncode(t)) end)
end
local function loadCfg()
	if not (isfile and readfile) then return false end
	local ok = pcall(function()
		if not isfile(FILE) then error("nofile") end
		local t = HttpService:JSONDecode(readfile(FILE))
		for _, k in ipairs(SAVE) do
			if t[k] ~= nil and type(t[k]) == type(cfg[k]) then cfg[k] = t[k] end
		end
	end)
	return ok
end
loadCfg()

---------------------------------------------------------------- STATE
local status = "Idle"
local lockCF, busy, pauseFarm = nil, false, false
local mobCache, origSize, espList = {}, {}, {}
local blacklist, lastPos = {}, {}
local questInfo, questPauseUntil, questFails = nil, 0, 0
local noMobSince = nil
local kills, sessionStart = 0, os.clock()
local islands = {}
local tpToken = 0
local lastGood = nil

---------------------------------------------------------------- HELPERS
local function jit(a, b) return rnd:NextNumber(a, b) end
local function pause(a, b) task.wait(jit(a, b) * (cfg.Safe and 1.35 or 1)) end
local function hrp() local c = LP.Character return c and c:FindFirstChild("HumanoidRootPart") end
local function hum() local c = LP.Character return c and c:FindFirstChildOfClass("Humanoid") end
local function alive() local h, r = hum(), hrp() if h and r and h.Health > 0 then return r end end
local lastDbg = ""
local function dbg(e) lastDbg = tostring(e) end
local function farmOn() return cfg.Farm and not pauseFarm end

local function toN(s) return tonumber((tostring(s):gsub(",", ""):gsub("%.", ""))) end
local function stripTags(s) return (tostring(s):gsub("<[^>]+>", "")) end
local function lvOf(s)
	local n = tostring(s):match("%[[Ll][Vv]%.?%s*([%d,%.]+)%]") or tostring(s):match("[Ll][Vv]%.?%s*([%d,]+)")
	return n and toN(n) or nil
end
local function cleanName(s)
	s = stripTags(s):gsub("%[.-%]", ""):gsub("^[^%w]+", ""):gsub("%s+$", ""):gsub("^%s+", "")
	return s
end
local function keyOf(m) return cleanName(m.Name):lower() end

local function visibleChain(o)
	local p = o
	while p and p ~= game do
		if p:IsA("GuiObject") and not p.Visible then return false end
		if p:IsA("ScreenGui") and not p.Enabled then return false end
		p = p.Parent
	end
	return true
end

local function goTo(pos, active)
	busy = true
	local t0 = os.clock()
	local r0 = alive()
	local limit = 30
	if r0 then limit = math.max(30, (pos - r0.Position).Magnitude / math.max(cfg.Speed, 20) * 1.6 + 8) end
	local ok = false
	while running and active() do
		local r = alive()
		if not r then break end
		local d = pos - r.Position
		local dist = d.Magnitude
		if dist < 3 then ok = true break end
		local dt = RunService.Heartbeat:Wait()
		local sp = math.min(cfg.Speed, cfg.Safe and 110 or 220)
		local step = math.min(dist, sp * dt)
		r.CFrame = CFrame.new(r.Position + d.Unit * step) * (r.CFrame - r.CFrame.Position)
		r.AssemblyLinearVelocity = Vector3.zero
		if os.clock() - t0 > limit then break end
	end
	busy = false
	return ok
end

---------------------------------------------------------------- PLAYER LEVEL
local lvCache, lvCacheT = nil, -1e9
local function getLevel()
	if os.clock() - lvCacheT < 3 then return lvCache end
	lvCacheT = os.clock()
	local found
	local v = LP:GetAttribute("Level")
	if type(v) == "number" then found = v end
	if not found then
		for _, d in ipairs(LP:GetDescendants()) do
			if (d:IsA("IntValue") or d:IsA("NumberValue")) and d.Name:lower():find("level") and not d.Name:lower():find("max") then
				found = d.Value
				break
			elseif d:IsA("StringValue") and d.Name:lower() == "level" then
				found = toN(d.Value)
				if found then break end
			end
		end
	end
	lvCache = found
	return found
end

---------------------------------------------------------------- QUEST TRACKER
local function readQuest()
	local pg = LP:FindFirstChild("PlayerGui")
	if not pg then return nil end
	for _, l in ipairs(pg:GetDescendants()) do
		if l:IsA("TextLabel") and l.Text ~= "" and not (gui and l:IsDescendantOf(gui)) then
			local t = stripTags(l.Text)
			local cur, need = t:match("[Pp]rogress.-%(%s*([%d,]+)%s*/%s*([%d,]+)%s*%)")
			if cur and visibleChain(l) then
				local c = l.Parent
				for _ = 1, 3 do
					if not c then break end
					for _, x in ipairs(c:GetDescendants()) do
						if x:IsA("TextLabel") and x ~= l then
							local tt = stripTags(x.Text)
							if tt:find("%[[Ll][Vv]") then
								local nm = cleanName(tt):gsub("^[Qq]uest:%s*", ""):gsub("^[Kk]ill%s+%d+%s+", "")
								return { name = nm, level = lvOf(tt), cur = toN(cur) or 0, need = toN(need) or 1, raw = tt }
							end
						end
					end
					c = c.Parent
				end
			end
		end
	end
	return nil
end

---------------------------------------------------------------- MOBS
local FOLDERS = { "monster", "monsters", "enemies", "enemy", "mobs", "mob", "npcs" }

local function isMob(m)
	if not m:IsA("Model") then return false end
	local h = m:FindFirstChildOfClass("Humanoid")
	if not h or h.Health <= 0 then return false end
	if Players:GetPlayerFromCharacter(m) then return false end
	if not m:FindFirstChild("HumanoidRootPart") then return false end
	if m:FindFirstChildWhichIsA("ProximityPrompt", true) or m:FindFirstChildWhichIsA("ClickDetector", true) then return false end
	return true
end

local function scanContainer(c, depth, out)
	for _, o in ipairs(c:GetChildren()) do
		if o:IsA("Model") then
			if isMob(o) then out[#out + 1] = o elseif depth > 0 then scanContainer(o, depth - 1, out) end
		elseif o:IsA("Folder") and depth > 0 then
			scanContainer(o, depth - 1, out)
		end
	end
end

local function refreshMobs()
	local out, found = {}, false
	for _, c in ipairs(Workspace:GetChildren()) do
		if (c:IsA("Folder") or c:IsA("Model")) and table.find(FOLDERS, c.Name:lower()) then
			scanContainer(c, 2, out)
			found = true
		end
	end
	if not found then scanContainer(Workspace, 2, out) end
	mobCache = out
	for _, m in ipairs(out) do
		local r = m:FindFirstChild("HumanoidRootPart")
		local k = keyOf(m)
		if r and k ~= "" then lastPos[k] = r.Position end
	end
end

local function matches(m, want)
	if not want then return true end
	local k = keyOf(m)
	if k == "" then return false end
	return k == want or k:find(want, 1, true) ~= nil or want:find(k, 1, true) ~= nil
end

local function mobNames()
	local seen, list = {}, {}
	for _, m in ipairs(mobCache) do
		local n = cleanName(m.Name)
		if n ~= "" and not seen[n] then seen[n] = true list[#list + 1] = n end
	end
	table.sort(list)
	return list
end

local function bossList()
	local hps = {}
	for _, m in ipairs(mobCache) do
		local h = m:FindFirstChildOfClass("Humanoid")
		if h then hps[#hps + 1] = h.MaxHealth end
	end
	table.sort(hps)
	local median = hps[math.max(1, math.floor(#hps / 2))] or 0
	local seen, list = {}, {}
	for _, m in ipairs(mobCache) do
		local h = m:FindFirstChildOfClass("Humanoid")
		local n = cleanName(m.Name)
		local isBoss = m.Name:lower():find("boss") or (#hps >= 5 and median > 0 and h and h.MaxHealth >= median * 8)
		if isBoss and n ~= "" and not seen[n] then seen[n] = true list[#list + 1] = n end
	end
	table.sort(list)
	return list
end

local function bestLevelKey()
	local L = getLevel()
	if not L then return nil end
	local best, bl
	for _, m in ipairs(mobCache) do
		local lv = lvOf(m.Name)
		if lv and lv <= L and (not bl or lv > bl) then best, bl = keyOf(m), lv end
	end
	return best
end

local function getWant()
	if cfg.Mode == "Selected" then return cfg.MobName ~= "" and cfg.MobName:lower() or nil end
	if cfg.Mode == "Boss" then return cfg.BossName ~= "" and cfg.BossName:lower() or nil end
	if cfg.Mode == "Nearest" then return nil end
	local q = questInfo
	if q and q.cur < q.need and q.name ~= "" then return q.name:lower() end
	return bestLevelKey()
end

local function pickTarget(want)
	local r = alive()
	if not r then return end
	local best, bd
	for _, m in ipairs(mobCache) do
		local mr = m.Parent and m:FindFirstChild("HumanoidRootPart")
		local h = m:FindFirstChildOfClass("Humanoid")
		if mr and h and h.Health > 0 and (blacklist[m] or 0) < os.clock() and matches(m, want) then
			local d = (mr.Position - r.Position).Magnitude
			if not bd or d < bd then best, bd = m, d end
		end
	end
	return best
end

local function restoreHitboxes()
	for part, sz in pairs(origSize) do
		if part.Parent then pcall(function() part.Size = sz end) end
	end
	origSize = {}
end

local function applyHitbox()
	local r = alive()
	if not r then return end
	local size = cfg.Safe and math.min(cfg.HitboxSize, 15) or cfg.HitboxSize
	for _, m in ipairs(mobCache) do
		local mr = m:FindFirstChild("HumanoidRootPart")
		if mr then
			if (mr.Position - r.Position).Magnitude < 250 then
				if not origSize[mr] then origSize[mr] = mr.Size end
				mr.Size = Vector3.new(size, size, size)
				mr.CanCollide = false
			elseif origSize[mr] then
				mr.Size = origSize[mr]
				origSize[mr] = nil
			end
		end
	end
end

local function clearESP()
	for _, h in ipairs(espList) do pcall(function() h:Destroy() end) end
	espList = {}
end

local function applyESP()
	clearESP()
	local r = alive()
	if not r then return end
	local sorted = {}
	for _, m in ipairs(mobCache) do
		local mr = m:FindFirstChild("HumanoidRootPart")
		if mr then sorted[#sorted + 1] = { m, (mr.Position - r.Position).Magnitude } end
	end
	table.sort(sorted, function(a, b) return a[2] < b[2] end)
	for i = 1, math.min(#sorted, 25) do
		local h = Instance.new("Highlight")
		h.FillTransparency = 0.7
		h.FillColor = Color3.fromRGB(140, 100, 255)
		h.OutlineColor = Color3.new(1, 1, 1)
		h.Adornee = sorted[i][1]
		h.Parent = sorted[i][1]
		espList[#espList + 1] = h
	end
end

local function bringMobs(target, pos, want)
	local range = cfg.Safe and math.min(cfg.BringRange, 40) or cfg.BringRange
	for _, m in ipairs(mobCache) do
		if m ~= target and m.Parent then
			local r = m:FindFirstChild("HumanoidRootPart")
			local h = m:FindFirstChildOfClass("Humanoid")
			if r and h and h.Health > 0 and matches(m, want) and (r.Position - pos).Magnitude <= range then
				r.CFrame = CFrame.new(pos + Vector3.new(jit(-3, 3), 0, jit(-3, 3)))
				r.AssemblyLinearVelocity = Vector3.zero
			end
		end
	end
end

---------------------------------------------------------------- TOOLS / INPUT
local function toolList()
	local t = {}
	for _, c in ipairs({ LP.Backpack, LP.Character }) do
		if c then
			for _, x in ipairs(c:GetChildren()) do
				if x:IsA("Tool") then t[#t + 1] = x end
			end
		end
	end
	return t
end

local function weaponNames()
	local l = { "Auto" }
	for _, t in ipairs(toolList()) do l[#l + 1] = t.Name end
	return l
end

local function equip()
	if not cfg.AutoEquip then return end
	local c, h = LP.Character, hum()
	if not c or not h then return end
	local cur = c:FindFirstChildOfClass("Tool")
	if cur and (cfg.Weapon == "Auto" or cur.Name == cfg.Weapon) then return end
	for _, t in ipairs(toolList()) do
		if t.Parent == LP.Backpack and (cfg.Weapon == "Auto" or t.Name == cfg.Weapon) then
			pcall(function() h:EquipTool(t) end)
			break
		end
	end
end

local function swing()
	local m = cfg.AttackMethod
	local c = LP.Character
	local t = c and c:FindFirstChildOfClass("Tool")
	if t and m ~= "Click" then pcall(function() t:Activate() end) end
	if m ~= "Tool" then
		pcall(function()
			VirtualUser:CaptureController()
			VirtualUser:ClickButton1(Vector2.new(0, 0))
		end)
	end
end

local function pressKey(kc)
	if not VIM then return end
	pcall(function() VIM:SendKeyEvent(true, kc, false, game) end)
	task.wait(0.06)
	pcall(function() VIM:SendKeyEvent(false, kc, false, game) end)
end

local function pressButton(b)
	local done = false
	if firesignal then
		pcall(function() firesignal(b.MouseButton1Click) done = true end)
		pcall(function() firesignal(b.Activated) done = true end)
	end
	if not done and getconnections then
		for _, sig in ipairs({ b.MouseButton1Click, b.Activated }) do
			pcall(function() for _, c in ipairs(getconnections(sig)) do c:Fire() done = true end end)
		end
	end
	if not done and VIM then
		pcall(function()
			local p = b.AbsolutePosition + b.AbsoluteSize / 2
			local inset = GuiService:GetGuiInset()
			VIM:SendMouseButtonEvent(p.X, p.Y + inset.Y, 0, true, game, 0)
			task.wait(0.05)
			VIM:SendMouseButtonEvent(p.X, p.Y + inset.Y, 0, false, game, 0)
		end)
	end
end

local ACCEPT = { "accept", "yes", "take", "start", "confirm", "ok" }
local function pressDialog()
	local pg = LP:FindFirstChild("PlayerGui")
	if not pg then return false end
	for _, b in ipairs(pg:GetDescendants()) do
		if b:IsA("TextButton") and not (gui and b:IsDescendantOf(gui)) and b.Text ~= "" and visibleChain(b) then
			local t = stripTags(b.Text):lower()
			for _, w in ipairs(ACCEPT) do
				if t == w or t:find("^" .. w .. "%f[%W]") then
					pressButton(b)
					return true
				end
			end
		end
	end
	return false
end

local function interact(obj)
	if obj:IsA("ProximityPrompt") then
		pcall(function() obj.HoldDuration = 0 end)
		if fireproximityprompt then
			pcall(fireproximityprompt, obj)
		elseif VIM then
			pressKey(Enum.KeyCode.E)
		end
	elseif obj:IsA("ClickDetector") and fireclickdetector then
		pcall(fireclickdetector, obj)
	end
end

---------------------------------------------------------------- QUEST NPCs
local npcCache, npcCacheT = {}, -1e9
local function questNPCs(force)
	if not force and os.clock() - npcCacheT < 120 then return npcCache end
	local list = {}
	for _, o in ipairs(Workspace:GetDescendants()) do
		if o:IsA("ProximityPrompt") or o:IsA("ClickDetector") then
			local holder = o:FindFirstAncestorOfClass("Model")
			local hn = (holder and holder.Name) or (o.Parent and o.Parent.Name) or ""
			local at = o:IsA("ProximityPrompt") and (o.ActionText .. " " .. o.ObjectText) or ""
			if hn:lower():find("quest") or at:lower():find("quest") then
				local pos
				local p = o.Parent
				if p and p:IsA("BasePart") then pos = p.Position elseif holder then pos = holder:GetPivot().Position end
				if pos then
					list[#list + 1] = { name = hn, pos = pos, obj = o, lv = lvOf(hn) or lvOf(at) }
				end
			end
		end
	end
	table.sort(list, function(a, b) return a.name < b.name end)
	npcCache, npcCacheT = list, os.clock()
	return list
end

local function acceptQuest(act)
	act = act or farmOn
	local list = questNPCs()
	if #list == 0 then
		status = "No quest NPC found"
		questPauseUntil = os.clock() + 30
		return
	end
	local L = getLevel()
	local pick
	if cfg.QuestNPC ~= "" then
		for _, n in ipairs(list) do if n.name == cfg.QuestNPC then pick = n break end end
	end
	if not pick and L then
		for _, n in ipairs(list) do
			if n.lv and n.lv <= L and (not pick or n.lv > pick.lv) then pick = n end
		end
	end
	if not pick then
		local ref = lastPos[bestLevelKey() or ""] or (alive() and alive().Position)
		local bd
		for _, n in ipairs(list) do
			local d = ref and (n.pos - ref).Magnitude or 0
			if not bd or d < bd then pick, bd = n, d end
		end
	end
	if not pick then return end
	status = "Quest NPC: " .. pick.name
	lockCF = nil
	if not goTo(pick.pos + Vector3.new(0, 3, 0), act) then return end
	pause(0.4, 0.8)
	interact(pick.obj)
	for _ = 1, 4 do
		pause(0.5, 0.9)
		if not pressDialog() then break end
	end
	pause(0.8, 1.3)
	questInfo = readQuest()
	if questInfo and questInfo.cur < questInfo.need then
		questFails = 0
		notify("Quest accepted: " .. questInfo.name)
	else
		questFails = questFails + 1
		if questFails >= 3 then
			questFails = 0
			questPauseUntil = os.clock() + 90
			notify("Quest accept failed. Use Misc > Copy debug dump", true)
		end
	end
end

---------------------------------------------------------------- SERVER HOP
local function hop()
	notify("Searching for a server...")
	local ok, res = pcall(function()
		return HttpService:JSONDecode(game:HttpGet("https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100"))
	end)
	if ok and res and res.data then
		for _, s in ipairs(res.data) do
			if s.playing < s.maxPlayers - 1 and s.id ~= game.JobId then
				TeleportService:TeleportToPlaceInstance(game.PlaceId, s.id, LP)
				return
			end
		end
	end
	notify("No server found", true)
end

---------------------------------------------------------------- FARM LOOP
local function holdPos(tr)
	if cfg.Pos == "Behind" then
		return (tr.CFrame * CFrame.new(0, 2, cfg.Height * 0.6)).Position
	end
	return tr.Position + Vector3.new(0, cfg.Height, 0)
end

local function farmStep()
	equip()
	if cfg.Mode == "Level" and cfg.AutoQuest and os.clock() > questPauseUntil then
		local q = questInfo
		if not (q and q.cur < q.need) then acceptQuest() end
		if not farmOn() then return end
	end
	local want = getWant()
	local target = pickTarget(want)
	if not target then
		lockCF = nil
		noMobSince = noMobSince or os.clock()
		local r = alive()
		local lp = want and lastPos[want]
		if r and lp and (lp - r.Position).Magnitude > 30 then
			status = "Roaming to " .. want
			goTo(lp + Vector3.new(0, cfg.Height, 0), farmOn)
			pause(0.6, 1.0)
		else
			status = "Waiting for mobs"
			task.wait(0.6)
		end
		if cfg.AutoHop and os.clock() - noMobSince > 25 then
			noMobSince = os.clock() + 60
			hop()
		end
		return
	end
	noMobSince = nil
	local th = target:FindFirstChildOfClass("Humanoid")
	status = "Farming: " .. cleanName(target.Name)
	local lastHp, lastChange = th.Health, os.clock()
	while running and farmOn() and target.Parent and th and th.Health > 0 do
		local r = alive()
		if not r then break end
		local tr = target:FindFirstChild("HumanoidRootPart")
		if not tr then break end
		local desired = holdPos(tr)
		if (desired - r.Position).Magnitude > 9 then
			lockCF = nil
			goTo(desired, function() return farmOn() and target.Parent and th.Health > 0 end)
		else
			lockCF = CFrame.lookAt(desired, Vector3.new(tr.Position.X, desired.Y, tr.Position.Z))
			if cfg.Bring then bringMobs(target, tr.Position, want) end
			swing()
			pause(cfg.AttackDelay, cfg.AttackDelay * 1.5)
		end
		if th.Health ~= lastHp then lastHp, lastChange = th.Health, os.clock() end
		if os.clock() - lastChange > 7 then
			blacklist[target] = os.clock() + 25
			break
		end
		equip()
	end
	if th and th.Health <= 0 then kills = kills + 1 end
	lockCF = nil
	pause(0.05, 0.15)
end

task.spawn(function()
	while running do
		if farmOn() and alive() then
			local ok, err = pcall(farmStep)
			if not ok then dbg(err) task.wait(1) end
		else
			lockCF = nil
			task.wait(0.3)
		end
		task.wait()
	end
end)

task.spawn(function()
	while running do
		pcall(refreshMobs)
		local ok, q = pcall(readQuest)
		if ok then questInfo = q end
		if cfg.Hitbox then pcall(applyHitbox) end
		if cfg.ESP then pcall(applyESP) end
		task.wait(1.5)
	end
end)

task.spawn(function()
	while running do
		if cfg.Farm and lockCF and VIM then
			for _, k in ipairs({ "Z", "X", "C", "V", "F" }) do
				if cfg["Sk" .. k] then
					pressKey(Enum.KeyCode[k])
					task.wait(jit(0.15, 0.3))
				end
			end
			task.wait(cfg.SkillDelay)
		else
			task.wait(0.4)
		end
	end
end)

-- fruit sniper
local function findFruit()
	local r = alive()
	if not r then return end
	local best, bd
	local function consider(o)
		local nm = o.Name:lower()
		if nm:find("fruit") and (o:IsA("Tool") or o:IsA("Model") or o:IsA("BasePart")) then
			if o:IsA("Model") and Players:GetPlayerFromCharacter(o) then return end
			local part = o:IsA("BasePart") and o or o:FindFirstChildWhichIsA("BasePart", true)
			if part then
				local d = (part.Position - r.Position).Magnitude
				if not bd or d < bd then best, bd = { o, part }, d end
			end
		end
	end
	for _, o in ipairs(Workspace:GetChildren()) do
		consider(o)
		if o:IsA("Folder") and o.Name:lower():find("fruit") then
			for _, c in ipairs(o:GetChildren()) do consider(c) end
		end
	end
	return best
end

task.spawn(function()
	while running do
		if cfg.Sniper and alive() and not pauseFarm then
			local f = findFruit()
			if f then
				notify("Fruit found: " .. f[1].Name)
				pauseFarm = true
				lockCF = nil
				goTo(f[2].Position + Vector3.new(0, 2, 0), function() return cfg.Sniper end)
				local r = alive()
				if r then
					pcall(function()
						if firetouchinterest then
							firetouchinterest(r, f[2], 0)
							task.wait(0.1)
							firetouchinterest(r, f[2], 1)
						end
					end)
					local pp = f[1]:FindFirstChildWhichIsA("ProximityPrompt", true)
					if pp then interact(pp) end
				end
				task.wait(1)
				pauseFarm = false
			end
		end
		task.wait(3)
	end
end)

task.spawn(function()
	while running do
		local r = alive()
		if r and r.Position.Y > -100 and not busy then lastGood = r.CFrame end
		task.wait(1)
	end
end)

bind(RunService.Heartbeat, function()
	local r = alive()
	if r and lockCF then
		r.CFrame = lockCF
		r.AssemblyLinearVelocity = Vector3.zero
		r.AssemblyAngularVelocity = Vector3.zero
	end
	if r and cfg.AntiVoid and lastGood and r.Position.Y < -300 then
		r.CFrame = lastGood
		r.AssemblyLinearVelocity = Vector3.zero
	end
end)

bind(RunService.Stepped, function()
	if (cfg.Noclip or cfg.Farm or busy) and LP.Character then
		for _, p in ipairs(LP.Character:GetDescendants()) do
			if p:IsA("BasePart") and p.CanCollide then p.CanCollide = false end
		end
	end
	if cfg.SpeedHack then
		local h = hum()
		if h then h.WalkSpeed = cfg.Safe and math.min(cfg.WalkSpeed, 40) or cfg.WalkSpeed end
	end
end)

bind(UserInputService.JumpRequest, function()
	if cfg.InfJump then
		local h = hum()
		if h then h:ChangeState(Enum.HumanoidStateType.Jumping) end
	end
end)

bind(LP.Idled, function()
	pcall(function()
		VirtualUser:CaptureController()
		VirtualUser:ClickButton2(Vector2.new())
	end)
end)

---------------------------------------------------------------- ISLANDS / TELEPORT
local function scanIslands()
	local out, seen = {}, {}
	local function add(name, pos)
		if pos and not seen[name] and #out < 70 then
			seen[name] = true
			out[#out + 1] = { name, pos }
		end
	end
	for _, c in ipairs(Workspace:GetChildren()) do
		local n = c.Name:lower()
		if (c:IsA("Folder") or c:IsA("Model")) and (n:find("island") or n == "map" or n:find("location") or n:find("spawn")) then
			for _, i in ipairs(c:GetChildren()) do
				local ok, p = pcall(function()
					if i:IsA("BasePart") then return i.Position end
					if i:IsA("Model") then return i:GetPivot().Position end
				end)
				if ok then add(i.Name, p) end
			end
		end
	end
	for _, o in ipairs(Workspace:GetDescendants()) do
		if o:IsA("SpawnLocation") then add(o.Name, o.Position) end
	end
	table.sort(islands, function(a, b) return a[1] < b[1] end)
	islands = out
	table.sort(islands, function(a, b) return a[1] < b[1] end)
	return #out
end

local function tpTo(pos)
	tpToken = tpToken + 1
	local my = tpToken
	task.spawn(function()
		local was = pauseFarm
		pauseFarm = true
		lockCF = nil
		goTo(pos + Vector3.new(0, 6, 0), function() return tpToken == my end)
		pauseFarm = was
	end)
end

---------------------------------------------------------------- UI
local C = {
	bg = Color3.fromRGB(14, 14, 22), side = Color3.fromRGB(20, 20, 32), card = Color3.fromRGB(28, 28, 44),
	accent = Color3.fromRGB(125, 92, 255), off = Color3.fromRGB(60, 60, 84), text = Color3.fromRGB(236, 236, 248),
	dim = Color3.fromRGB(150, 150, 178), bad = Color3.fromRGB(255, 80, 100),
}

local function make(class, props, parent)
	local o = Instance.new(class)
	for k, v in pairs(props) do o[k] = v end
	o.Parent = parent
	return o
end
local function corner(o, r) make("UICorner", { CornerRadius = UDim.new(0, r) }, o) end
local function tw(o, t, props, style, dir)
	return TweenService:Create(o, TweenInfo.new(t, style or Enum.EasingStyle.Quint, dir or Enum.EasingDirection.Out), props)
end

local orderOf = {}
local function nxt(p)
	orderOf[p] = (orderOf[p] or 0) + 1
	return orderOf[p]
end

local animators = {}
local fps = 60
bind(RunService.RenderStepped, function(dt)
	fps = fps + (1 / math.max(dt, 1e-4) - fps) * 0.05
	for _, f in ipairs(animators) do f(dt) end
end)

local function randName()
	local s = ""
	for _ = 1, 12 do s = s .. string.char(rnd:NextInteger(97, 122)) end
	return s
end

gui = Instance.new("ScreenGui")
gui.Name = randName()
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.DisplayOrder = 999
do
	local parent
	if gethui then pcall(function() parent = gethui() end) end
	if not parent then
		local ok = pcall(function() gui.Parent = CoreGui end)
		if ok and gui.Parent then parent = CoreGui end
	end
	gui.Parent = parent or LP:WaitForChild("PlayerGui")
end

notify = function(text, bad)
	local f = make("Frame", {
		Size = UDim2.new(0, 280, 0, 34), Position = UDim2.new(0.5, -140, 0, -50),
		BackgroundColor3 = C.card, BorderSizePixel = 0, ZIndex = 50,
	}, gui)
	corner(f, 10)
	make("UIStroke", { Color = bad and C.bad or C.accent, Thickness = 1.2 }, f)
	make("TextLabel", {
		Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = text, TextColor3 = C.text,
		Font = Enum.Font.GothamMedium, TextSize = 13, ZIndex = 51, TextTruncate = Enum.TextTruncate.AtEnd,
	}, f)
	tw(f, 0.45, { Position = UDim2.new(0.5, -140, 0, 14) }, Enum.EasingStyle.Back):Play()
	task.delay(2.6, function()
		local t = tw(f, 0.35, { Position = UDim2.new(0.5, -140, 0, -50) })
		t:Play()
		t.Completed:Wait()
		f:Destroy()
	end)
end

local function makeDrag(handle, frame, onTap)
	local dragging, moved, startIn, startPos = false, false, nil, nil
	local goal = nil
	bind(handle.InputBegan, function(i)
		if i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging, moved, startIn, startPos = true, false, i.Position, frame.Position
			goal = frame.Position
			i.Changed:Connect(function()
				if i.UserInputState == Enum.UserInputState.End then
					dragging = false
					if not moved and onTap then onTap() end
				end
			end)
		end
	end)
	bind(UserInputService.InputChanged, function(i)
		if dragging and (i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseMovement) then
			local d = i.Position - startIn
			if d.Magnitude > 7 then moved = true end
			if moved then
				goal = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
			end
		end
	end)
	animators[#animators + 1] = function(dt)
		if goal then
			frame.Position = frame.Position:Lerp(goal, 1 - math.exp(-dt * 22))
			if not dragging and (frame.Position.X.Offset - goal.X.Offset) ^ 2 + (frame.Position.Y.Offset - goal.Y.Offset) ^ 2 < 1 then
				frame.Position = goal
				goal = nil
			end
		end
	end
end

------ widgets (every widget gets a LayoutOrder so the list never scrambles)
local function Section(page, text)
	make("TextLabel", {
		Size = UDim2.new(1, -4, 0, 22), BackgroundTransparency = 1, Text = text, TextColor3 = C.text,
		Font = Enum.Font.GothamBold, TextSize = 15, TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = nxt(page),
	}, page)
end

local function Info(page, title, sub)
	local f = make("Frame", { Size = UDim2.new(1, -4, 0, 56), BackgroundColor3 = C.card, BorderSizePixel = 0, LayoutOrder = nxt(page) }, page)
	corner(f, 8)
	local t = make("TextLabel", {
		Size = UDim2.new(1, -20, 0, 20), Position = UDim2.new(0, 10, 0, 6), BackgroundTransparency = 1, Text = title,
		TextColor3 = C.text, Font = Enum.Font.GothamMedium, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
	}, f)
	local s = make("TextLabel", {
		Size = UDim2.new(1, -20, 0, 24), Position = UDim2.new(0, 10, 0, 26), BackgroundTransparency = 1, Text = sub or "",
		TextColor3 = C.dim, Font = Enum.Font.Gotham, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top, TextWrapped = true,
	}, f)
	return function(a, b)
		if a then t.Text = a end
		if b then s.Text = b end
	end
end

local function Toggle(page, text, def, cb)
	local f = make("Frame", { Size = UDim2.new(1, -4, 0, 38), BackgroundColor3 = C.card, BorderSizePixel = 0, LayoutOrder = nxt(page) }, page)
	corner(f, 8)
	make("TextLabel", {
		Size = UDim2.new(1, -64, 1, 0), Position = UDim2.new(0, 10, 0, 0), BackgroundTransparency = 1, Text = text,
		TextColor3 = C.text, Font = Enum.Font.GothamMedium, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left,
	}, f)
	local track = make("Frame", { Size = UDim2.new(0, 40, 0, 20), Position = UDim2.new(1, -50, 0.5, -10), BackgroundColor3 = C.off, BorderSizePixel = 0 }, f)
	corner(track, 10)
	local knob = make("Frame", { Size = UDim2.new(0, 16, 0, 16), Position = UDim2.new(0, 2, 0.5, -8), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0 }, track)
	corner(knob, 8)
	local btn = make("TextButton", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "" }, f)
	local state = false
	local function set(v, silent)
		state = v
		tw(track, 0.2, { BackgroundColor3 = v and C.accent or C.off }):Play()
		tw(knob, 0.25, { Position = v and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8) }, Enum.EasingStyle.Back):Play()
		if not silent then task.spawn(cb, v) end
	end
	bind(btn.Activated, function() set(not state) end)
	set(def, not def)
	return set
end

local function Button(page, text, cb)
	local b = make("TextButton", {
		Size = UDim2.new(1, -4, 0, 36), BackgroundColor3 = C.card, BorderSizePixel = 0, Text = text,
		TextColor3 = C.text, Font = Enum.Font.GothamMedium, TextSize = 13, AutoButtonColor = false, LayoutOrder = nxt(page),
	}, page)
	corner(b, 8)
	bind(b.MouseButton1Down, function() tw(b, 0.1, { BackgroundColor3 = C.accent }):Play() end)
	bind(b.MouseButton1Up, function() tw(b, 0.25, { BackgroundColor3 = C.card }):Play() end)
	bind(b.MouseLeave, function() tw(b, 0.25, { BackgroundColor3 = C.card }):Play() end)
	if cb then bind(b.Activated, function() task.spawn(cb, b) end) end
	return b
end

local function Dropdown(page, text, getList, cb, getCur)
	local head = Button(page, text .. ": " .. tostring(getCur() or "-"))
	local box = make("Frame", {
		Size = UDim2.new(1, -4, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = C.side,
		BorderSizePixel = 0, Visible = false, LayoutOrder = nxt(page),
	}, page)
	corner(box, 8)
	make("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, box)
	make("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4), PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 4) }, box)
	local isOpen = false
	local function rebuild()
		for _, c in ipairs(box:GetChildren()) do
			if c:IsA("TextButton") then c:Destroy() end
		end
		local l = getList()
		if #l == 0 then l = { "(empty)" } end
		for i, v in ipairs(l) do
			if i > 60 then break end
			local label = type(v) == "table" and (v.label or v[1]) or v
			local b = make("TextButton", {
				Size = UDim2.new(1, 0, 0, 28), BackgroundColor3 = C.card, Text = tostring(label), TextColor3 = C.text,
				Font = Enum.Font.Gotham, TextSize = 12, BorderSizePixel = 0, LayoutOrder = i, AutoButtonColor = true,
			}, box)
			corner(b, 6)
			b.Activated:Connect(function()
				if v == "(empty)" then box.Visible = false isOpen = false return end
				head.Text = text .. ": " .. tostring(label)
				box.Visible = false
				isOpen = false
				cb(v)
			end)
		end
	end
	bind(head.Activated, function()
		isOpen = not isOpen
		if isOpen then rebuild() end
		box.Visible = isOpen
	end)
	return head
end

local function Slider(page, text, mn, mx, def, cb)
	local f = make("Frame", { Size = UDim2.new(1, -4, 0, 48), BackgroundColor3 = C.card, BorderSizePixel = 0, LayoutOrder = nxt(page) }, page)
	corner(f, 8)
	local lbl = make("TextLabel", {
		Size = UDim2.new(1, -20, 0, 22), Position = UDim2.new(0, 10, 0, 3), BackgroundTransparency = 1,
		Text = text .. ": " .. def, TextColor3 = C.text, Font = Enum.Font.GothamMedium, TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, f)
	local track = make("Frame", { Size = UDim2.new(1, -20, 0, 6), Position = UDim2.new(0, 10, 1, -15), BackgroundColor3 = C.off, BorderSizePixel = 0 }, f)
	corner(track, 3)
	local fill = make("Frame", { Size = UDim2.new(0, 0, 1, 0), BackgroundColor3 = C.accent, BorderSizePixel = 0 }, track)
	corner(fill, 3)
	local knob = make("Frame", { Size = UDim2.new(0, 14, 0, 14), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0 }, track)
	corner(knob, 7)
	local hit = make("TextButton", { Size = UDim2.new(1, 0, 0, 30), Position = UDim2.new(0, 0, 1, -30), BackgroundTransparency = 1, Text = "" }, f)
	local shown = math.clamp((def - mn) / (mx - mn), 0, 1)
	local goalA = shown
	local dragging = false
	local function upd(x)
		local a = math.clamp((x - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1)
		goalA = a
		local v = math.floor(mn + (mx - mn) * a + 0.5)
		lbl.Text = text .. ": " .. v
		cb(v)
	end
	bind(hit.InputBegan, function(i)
		if i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = true
			page.ScrollingEnabled = false
			upd(i.Position.X)
			i.Changed:Connect(function()
				if i.UserInputState == Enum.UserInputState.End then
					dragging = false
					page.ScrollingEnabled = true
				end
			end)
		end
	end)
	bind(UserInputService.InputChanged, function(i)
		if dragging and (i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseMovement) then
			upd(i.Position.X)
		end
	end)
	animators[#animators + 1] = function(dt)
		shown = shown + (goalA - shown) * (1 - math.exp(-dt * 18))
		fill.Size = UDim2.new(shown, 0, 1, 0)
		knob.Position = UDim2.new(shown, -7, 0.5, -7)
	end
end

------ window
local cam = Workspace.CurrentCamera
local vp = cam and cam.ViewportSize or Vector2.new(800, 400)
local W = math.clamp(math.floor(vp.X * 0.66), 430, 700)
local H = math.clamp(math.floor(vp.Y * 0.84), 250, 430)
local SIDE = 116

local win = make("Frame", {
	Size = UDim2.new(0, W, 0, H), Position = UDim2.new(0.5, -math.floor(W / 2), 0.5, -math.floor(H / 2)),
	BackgroundColor3 = C.bg, BorderSizePixel = 0, Visible = false,
}, gui)
corner(win, 14)
make("UIStroke", { Color = C.accent, Thickness = 1.4, Transparency = 0.35 }, win)
local winScale = make("UIScale", { Scale = 0.01 }, win)

local title = make("Frame", { Size = UDim2.new(1, 0, 0, 36), BackgroundTransparency = 1 }, win)
make("TextLabel", {
	Size = UDim2.new(1, -60, 1, 0), Position = UDim2.new(0, 14, 0, 0), BackgroundTransparency = 1,
	Text = "LEGACY FORTENESS  <font color=\"#7d5cff\">| King Legacy</font>", RichText = true, TextColor3 = C.text,
	Font = Enum.Font.GothamBold, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left,
}, title)
local minBtn = make("TextButton", {
	Size = UDim2.new(0, 30, 0, 22), Position = UDim2.new(1, -40, 0, 7), BackgroundColor3 = C.card, Text = "-",
	TextColor3 = C.text, Font = Enum.Font.GothamBold, TextSize = 16, BorderSizePixel = 0,
}, title)
corner(minBtn, 6)
makeDrag(title, win)

local tabCol = make("ScrollingFrame", {
	Size = UDim2.new(0, SIDE, 1, -66), Position = UDim2.new(0, 8, 0, 40), BackgroundColor3 = C.side, BorderSizePixel = 0,
	ScrollBarThickness = 0, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
}, win)
corner(tabCol, 10)
make("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, tabCol)
make("UIPadding", { PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6), PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6) }, tabCol)
local pageHolder = make("Frame", {
	Size = UDim2.new(1, -(SIDE + 24), 1, -66), Position = UDim2.new(0, SIDE + 16, 0, 40), BackgroundTransparency = 1, ClipsDescendants = true,
}, win)
local statusLbl = make("TextLabel", {
	Size = UDim2.new(1, -24, 0, 20), Position = UDim2.new(0, 12, 1, -24), BackgroundTransparency = 1,
	Text = "Status: Idle", TextColor3 = C.dim, Font = Enum.Font.Gotham, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left,
}, win)

local pages, tabBtns, bars, curTab = {}, {}, {}, nil
local function selectTab(name)
	if curTab == name then return end
	for n, p in pairs(pages) do
		p.Visible = (n == name)
		tw(tabBtns[n], 0.25, { BackgroundColor3 = n == name and C.card or C.side, TextColor3 = n == name and C.text or C.dim }):Play()
		tw(bars[n], 0.25, { BackgroundTransparency = n == name and 0 or 1 }):Play()
	end
	local page = pages[name]
	page.Position = UDim2.new(0, 14, 0, 0)
	tw(page, 0.3, { Position = UDim2.new(0, 0, 0, 0) }):Play()
	curTab = name
end

local tabCount = 0
local function newTab(name)
	tabCount = tabCount + 1
	local page = make("ScrollingFrame", {
		Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 3,
		ScrollBarImageColor3 = C.accent, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, Visible = false,
	}, pageHolder)
	make("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, page)
	make("UIPadding", { PaddingRight = UDim.new(0, 5), PaddingBottom = UDim.new(0, 8) }, page)
	local b = make("TextButton", {
		Size = UDim2.new(1, 0, 0, 32), BackgroundColor3 = C.side, Text = "   " .. name, TextColor3 = C.dim,
		Font = Enum.Font.GothamMedium, TextSize = 12, BorderSizePixel = 0, AutoButtonColor = false,
		TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = tabCount,
	}, tabCol)
	corner(b, 8)
	local bar = make("Frame", { Size = UDim2.new(0, 3, 0, 16), Position = UDim2.new(0, 0, 0.5, -8), BackgroundColor3 = C.accent, BackgroundTransparency = 1, BorderSizePixel = 0 }, b)
	corner(bar, 2)
	pages[name], tabBtns[name], bars[name] = page, b, bar
	bind(b.Activated, function() selectTab(name) end)
	return page
end

local tHome, tMain, tQuest, tCombat, tBoss, tTP, tFruit, tPlayer, tMisc =
	newTab("Home"), newTab("Main"), newTab("Quest"), newTab("Combat"), newTab("Bosses"),
	newTab("Teleport"), newTab("Fruits"), newTab("Player"), newTab("Misc")

local function T(page, text, key, after)
	return Toggle(page, text, cfg[key], function(v)
		cfg[key] = v
		if after then after(v) end
	end)
end

------ HOME
Section(tHome, "Overview")
local infoPlayer = Info(tHome, "Player", "")
local infoQuest = Info(tHome, "Quest", "")
local infoFarm = Info(tHome, "Farm", "")
local infoSess = Info(tHome, "Session", "")

------ MAIN
Section(tMain, "Auto farm")
local setFarm = Toggle(tMain, "Auto Farm", false, function(v)
	cfg.Farm = v
	if not v then lockCF = nil end
end)
Dropdown(tMain, "Mode", function() return { "Level", "Selected", "Nearest", "Boss" } end, function(v) cfg.Mode = v end, function() return cfg.Mode end)
T(tMain, "Auto Quest (Level mode)", "AutoQuest", function() questPauseUntil = 0 end)
Dropdown(tMain, "Mob (Selected mode)", mobNames, function(v) cfg.MobName = v end, function() return cfg.MobName ~= "" and cfg.MobName or "Nearest" end)
T(tMain, "Auto Equip Weapon", "AutoEquip")
Dropdown(tMain, "Weapon", weaponNames, function(v) cfg.Weapon = v end, function() return cfg.Weapon end)
Dropdown(tMain, "Position", function() return { "Above", "Behind" } end, function(v) cfg.Pos = v end, function() return cfg.Pos end)
Slider(tMain, "Hover distance", 4, 18, cfg.Height, function(v) cfg.Height = v end)
Slider(tMain, "Move speed", 40, 220, cfg.Speed, function(v) cfg.Speed = v end)

------ QUEST
Section(tQuest, "Quest")
local infoQ2 = Info(tQuest, "Active quest", "")
Dropdown(tQuest, "Quest NPC", function()
	local l = { { label = "Auto", name = "" } }
	for _, n in ipairs(questNPCs()) do l[#l + 1] = { label = n.name .. (n.lv and (" (Lv " .. n.lv .. "+)") or ""), name = n.name } end
	return l
end, function(v) cfg.QuestNPC = v.name end, function() return cfg.QuestNPC ~= "" and cfg.QuestNPC or "Auto" end)
Button(tQuest, "Accept quest now", function()
	if not alive() then return end
	task.spawn(function()
		local was = pauseFarm
		pauseFarm = true
		lockCF = nil
		local ok, err = pcall(acceptQuest, function() return pauseFarm end)
		if not ok then dbg(err) end
		pauseFarm = was
	end)
end)
Button(tQuest, "Rescan quest NPCs", function() notify("Found " .. #questNPCs(true) .. " quest NPCs") end)

------ COMBAT
Section(tCombat, "Attack")
Dropdown(tCombat, "Attack method", function() return { "Both", "Tool", "Click" } end, function(v) cfg.AttackMethod = v end, function() return cfg.AttackMethod end)
Slider(tCombat, "Attack delay (ms)", 50, 400, math.floor(cfg.AttackDelay * 1000), function(v) cfg.AttackDelay = v / 1000 end)
Section(tCombat, "Skills (while farming)")
T(tCombat, "Skill Z", "SkZ")
T(tCombat, "Skill X", "SkX")
T(tCombat, "Skill C", "SkC")
T(tCombat, "Skill V", "SkV")
T(tCombat, "Skill F", "SkF")
Slider(tCombat, "Skill interval (s)", 1, 10, cfg.SkillDelay, function(v) cfg.SkillDelay = v end)
Section(tCombat, "Mobs")
T(tCombat, "Hitbox Expander", "Hitbox", function(v) if not v then restoreHitboxes() end end)
Slider(tCombat, "Hitbox size", 6, 40, cfg.HitboxSize, function(v) cfg.HitboxSize = v end)
T(tCombat, "Bring Mobs", "Bring")
Slider(tCombat, "Bring range", 15, 120, cfg.BringRange, function(v) cfg.BringRange = v end)
T(tCombat, "Mob ESP", "ESP", function(v) if not v then clearESP() end end)

------ BOSSES
Section(tBoss, "Bosses")
Info(tBoss, "How it works", "Bosses are detected by name or by very high HP. Only bosses currently loaded near you appear.")
Dropdown(tBoss, "Boss", bossList, function(v) cfg.BossName = v end, function() return cfg.BossName ~= "" and cfg.BossName or "-" end)
Button(tBoss, "Farm selected boss", function()
	if cfg.BossName == "" then notify("Pick a boss first", true) return end
	cfg.Mode = "Boss"
	setFarm(true)
	notify("Boss farm: " .. cfg.BossName)
end)
T(tBoss, "Auto Hop when nothing to farm", "AutoHop")

------ TELEPORT
Section(tTP, "Islands")
Button(tTP, "Scan islands", function() notify("Found " .. scanIslands() .. " locations") end)
local selIsland
Dropdown(tTP, "Location", function() return islands end, function(v) selIsland = v end, function() return "-" end)
Button(tTP, "Teleport to location", function()
	if not selIsland then notify("Scan and pick a location first", true) return end
	notify("Heading to " .. selIsland[1])
	tpTo(selIsland[2])
end)
Section(tTP, "NPCs / mobs")
local selNPC
Dropdown(tTP, "Quest NPC", function()
	local l = {}
	for _, n in ipairs(questNPCs()) do l[#l + 1] = { label = n.name, pos = n.pos } end
	return l
end, function(v) selNPC = v end, function() return "-" end)
Button(tTP, "Teleport to NPC", function()
	if not selNPC then notify("Pick an NPC first", true) return end
	tpTo(selNPC.pos)
end)
Button(tTP, "Teleport to nearest mob", function()
	local m = pickTarget(nil)
	if m and m:FindFirstChild("HumanoidRootPart") then tpTo(m.HumanoidRootPart.Position + Vector3.new(0, cfg.Height, 0)) else notify("No mobs nearby", true) end
end)
Button(tTP, "Cancel teleport", function() tpToken = tpToken + 1 busy = false end)

------ FRUITS
Section(tFruit, "Fruits")
T(tFruit, "Fruit Sniper (dropped fruits)", "Sniper")
Button(tFruit, "Check dropped fruits now", function()
	local f = findFruit()
	if f then notify("Found: " .. f[1].Name) else notify("No dropped fruit found") end
end)

------ PLAYER
Section(tPlayer, "Player")
T(tPlayer, "Noclip", "Noclip")
T(tPlayer, "Infinite Jump", "InfJump")
T(tPlayer, "Speed boost", "SpeedHack", function(v)
	if not v then local h = hum() if h then h.WalkSpeed = 16 end end
end)
Slider(tPlayer, "Walk speed", 16, 80, cfg.WalkSpeed, function(v) cfg.WalkSpeed = v end)
T(tPlayer, "Anti-void (return from falling)", "AntiVoid")

------ MISC
Section(tMisc, "Misc")
local origLight = { Lighting.Brightness, Lighting.ClockTime, Lighting.FogEnd, Lighting.GlobalShadows }
T(tMisc, "Safe Mode (lower risk caps)", "Safe")
Toggle(tMisc, "Fullbright", false, function(v)
	if v then
		Lighting.Brightness, Lighting.ClockTime, Lighting.FogEnd, Lighting.GlobalShadows = 2, 14, 1e6, false
	else
		Lighting.Brightness, Lighting.ClockTime, Lighting.FogEnd, Lighting.GlobalShadows = origLight[1], origLight[2], origLight[3], origLight[4]
	end
end)
Button(tMisc, "FPS boost", function()
	pcall(function() settings().Rendering.QualityLevel = Enum.QualityLevel.Level01 end)
	Lighting.GlobalShadows = false
	notify("FPS boost applied")
end)
Button(tMisc, "Server hop", hop)
Button(tMisc, "Rejoin", function() pcall(function() TeleportService:Teleport(game.PlaceId, LP) end) end)
Button(tMisc, "Save config", function() notify(saveCfg() and "Config saved" or "Cannot save here", false) end)
Button(tMisc, "Load config (reload script after)", function() notify(loadCfg() and "Config loaded" or "No config found", false) end)
Button(tMisc, "Copy debug dump", function()
	local lines = { "PlaceId: " .. game.PlaceId, "Level: " .. tostring(getLevel()), "Last error: " .. lastDbg }
	lines[#lines + 1] = "Quest tracker: " .. (questInfo and (questInfo.raw .. " " .. questInfo.cur .. "/" .. questInfo.need) or "none")
	lines[#lines + 1] = "Mobs seen:"
	for i, n in ipairs(mobNames()) do if i <= 30 then lines[#lines + 1] = "  " .. n end end
	lines[#lines + 1] = "Tools:"
	for _, t in ipairs(toolList()) do lines[#lines + 1] = "  " .. t.Name end
	lines[#lines + 1] = "Quest NPCs:"
	for i, n in ipairs(questNPCs(true)) do
		if i <= 25 then lines[#lines + 1] = "  " .. n.name .. " [" .. n.obj.ClassName .. "] " .. n.obj:GetFullName() end
	end
	lines[#lines + 1] = "Islands: " .. #islands
	local txt = table.concat(lines, "\n")
	if setclipboard then setclipboard(txt) notify("Dump copied") else print(txt) notify("Dump printed in console") end
end)
Button(tMisc, "Unload script", function() if env.LF_Cleanup then env.LF_Cleanup() end end)

task.spawn(function()
	while running do
		local pingTxt = "?"
		pcall(function() pingTxt = math.floor(StatsService.Network.ServerStatsItem["Data Ping"]:GetValue()) .. " ms" end)
		local L = getLevel()
		infoPlayer("Player: " .. LP.DisplayName, "Level: " .. (L and tostring(L) or "not detected"))
		local q = questInfo
		local qtxt = q and (q.name .. (q.level and (" [Lv. " .. q.level .. "]") or "") .. "  (" .. q.cur .. "/" .. q.need .. ")") or "No active quest detected"
		infoQuest("Quest", qtxt)
		infoQ2("Active quest", qtxt)
		infoFarm("Farm: " .. (cfg.Farm and "ON" or "OFF") .. "  (" .. cfg.Mode .. ")", status .. "  |  Mobs loaded: " .. #mobCache .. "  |  Kills: " .. kills)
		local t = math.floor(os.clock() - sessionStart)
		infoSess("Session", string.format("%02d:%02d:%02d  |  %d FPS  |  Ping %s", math.floor(t / 3600), math.floor(t / 60) % 60, t % 60, math.floor(fps), pingTxt))
		statusLbl.Text = "Status: " .. (cfg.Farm and status or "Idle")
		task.wait(0.6)
	end
end)

selectTab("Home")

------ bubble
local bubble = make("TextButton", {
	Size = UDim2.new(0, 50, 0, 50), Position = UDim2.new(0, 14, 0.5, -25), BackgroundColor3 = C.bg, Text = "jv",
	TextColor3 = Color3.new(1, 1, 1), Font = Enum.Font.GothamBold, TextSize = 18, BorderSizePixel = 0,
	AutoButtonColor = false, Visible = false, ZIndex = 20,
}, gui)
corner(bubble, 25)
local bStroke = make("UIStroke", { Color = C.accent, Thickness = 2 }, bubble)
local bScale = make("UIScale", { Scale = 0.01 }, bubble)
local pulse = 0
animators[#animators + 1] = function(dt)
	pulse = pulse + dt * 2.4
	bStroke.Transparency = 0.15 + (math.sin(pulse) * 0.5 + 0.5) * 0.5
end

local isOpen = false
local function setOpen(v)
	isOpen = v
	if v then
		win.Visible = true
		tw(winScale, 0.4, { Scale = 1 }, Enum.EasingStyle.Back):Play()
	else
		local t = tw(winScale, 0.25, { Scale = 0.01 }, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
		t:Play()
		t.Completed:Connect(function() if not isOpen then win.Visible = false end end)
	end
end
makeDrag(bubble, bubble, function() setOpen(not isOpen) end)
bind(minBtn.Activated, function() setOpen(false) end)

------ intro + password
local PASSWORD = "180125"
local intro = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, ZIndex = 30 }, gui)
local welcome = make("TextLabel", {
	Size = UDim2.new(1, 0, 0, 60), Position = UDim2.new(0, 0, 0.5, -30), BackgroundTransparency = 1, Text = "",
	TextColor3 = Color3.new(1, 1, 1), Font = Enum.Font.GothamBold, TextSize = 24, ZIndex = 31,
}, intro)
make("UIStroke", { Color = C.accent, Thickness = 1.5, Transparency = 0.2 }, welcome)

local panel = make("Frame", {
	Size = UDim2.new(0, 280, 0, 170), Position = UDim2.new(0.5, -140, 0.5, -85), BackgroundColor3 = C.bg,
	BorderSizePixel = 0, Visible = false, ZIndex = 32,
}, intro)
corner(panel, 14)
make("UIStroke", { Color = C.accent, Thickness = 1.4 }, panel)
local pScale = make("UIScale", { Scale = 0.6 }, panel)
make("TextLabel", {
	Size = UDim2.new(1, 0, 0, 40), Position = UDim2.new(0, 0, 0, 8), BackgroundTransparency = 1, Text = "ACESSO RESTRITO",
	TextColor3 = C.text, Font = Enum.Font.GothamBold, TextSize = 16, ZIndex = 33,
}, panel)
local box = make("TextBox", {
	Size = UDim2.new(1, -40, 0, 38), Position = UDim2.new(0, 20, 0, 54), BackgroundColor3 = C.card, Text = "",
	PlaceholderText = "Digite a senha", PlaceholderColor3 = C.dim, TextColor3 = C.text, Font = Enum.Font.GothamMedium,
	TextSize = 15, ClearTextOnFocus = false, BorderSizePixel = 0, ZIndex = 33,
}, panel)
corner(box, 8)
local enter = make("TextButton", {
	Size = UDim2.new(1, -40, 0, 38), Position = UDim2.new(0, 20, 0, 106), BackgroundColor3 = C.accent, Text = "Entrar",
	TextColor3 = Color3.new(1, 1, 1), Font = Enum.Font.GothamBold, TextSize = 15, BorderSizePixel = 0, ZIndex = 33,
}, panel)
corner(enter, 8)

local unlocked = false
local function unlock()
	unlocked = true
	tw(pScale, 0.3, { Scale = 0.01 }, Enum.EasingStyle.Quint, Enum.EasingDirection.In):Play()
	task.wait(0.3)
	panel.Visible = false
	tw(intro, 0.5, { BackgroundTransparency = 1 }):Play()
	task.wait(0.5)
	intro:Destroy()
	bubble.Visible = true
	tw(bScale, 0.45, { Scale = 1 }, Enum.EasingStyle.Back):Play()
	setOpen(true)
	notify("Bem-vindo à LEGACY FORTENESS")
end

local function tryPass()
	if unlocked then return end
	if box.Text == PASSWORD then
		task.spawn(unlock)
	else
		box.Text = ""
		local base = panel.Position
		tw(box, 0.15, { BackgroundColor3 = C.bad }):Play()
		for i = 1, 6 do
			panel.Position = base + UDim2.new(0, (i % 2 == 0 and 1 or -1) * (12 - i * 1.5), 0, 0)
			task.wait(0.04)
		end
		panel.Position = base
		tw(box, 0.4, { BackgroundColor3 = C.card }):Play()
		notify("Senha incorreta", true)
	end
end
bind(enter.Activated, tryPass)
bind(box.FocusLost, function(enterPressed) if enterPressed then tryPass() end end)

task.spawn(function()
	local msg = "Bem-vindo à LEGACY FORTENESS"
	task.wait(0.4)
	local len = utf8.len(msg)
	for i = 1, len do
		welcome.Text = string.sub(msg, 1, utf8.offset(msg, i + 1) - 1)
		task.wait(0.05)
	end
	task.wait(0.9)
	tw(welcome, 0.5, { TextTransparency = 1, Position = UDim2.new(0, 0, 0.5, -70) }):Play()
	task.wait(0.5)
	panel.Visible = true
	tw(pScale, 0.45, { Scale = 1 }, Enum.EasingStyle.Back):Play()
end)

---------------------------------------------------------------- CLEANUP
env.LF_Cleanup = function()
	running = false
	cfg.Farm = false
	cfg.Sniper = false
	lockCF = nil
	for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
	pcall(restoreHitboxes)
	pcall(clearESP)
	local h = hum()
	if h and cfg.SpeedHack then h.WalkSpeed = 16 end
	pcall(function() gui:Destroy() end)
	env.LF_Cleanup = nil
end
