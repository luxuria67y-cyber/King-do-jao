--[[
  LEGACY FORTENESS  |  King Legacy  |  Roblox Mobile (Delta)
  Paste into Delta and execute. Password: 180125
  Everything game-specific (mobs, quest NPCs, islands, weapons) is discovered
  at runtime, so it does not depend on hardcoded remote names that break on updates.
  Use the "Copy debug dump" button in Misc if something does not detect.
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
local CoreGui = game:GetService("CoreGui")

local LP = Players.LocalPlayer
local rnd = Random.new()
local running = true
local conns = {}
local function bind(sig, fn)
	local c = sig:Connect(fn)
	conns[#conns + 1] = c
	return c
end

--------------------------------------------------------------------- CONFIG
local cfg = {
	Farm = false, AutoQuest = false, AutoEquip = true, Weapon = "Auto", MobName = "Any",
	Height = 9, Speed = 120, Hitbox = false, HitboxSize = 14, Bring = false, BringRange = 40,
	Noclip = false, InfJump = false, SpeedHack = false, WalkSpeed = 24, ESP = false,
	Fullbright = false, Safe = true, QuestEvery = 75,
}
local status = "Idle"
local lockCF, busy = nil, false
local mobCache, origSize, espList = {}, {}, {}
local lastQuest = -1e9
local islands, islandIdx = {}, 0
local tpToken = 0

--------------------------------------------------------------------- HELPERS
local function jit(a, b) return rnd:NextNumber(a, b) end
local function pause(a, b) task.wait(jit(a, b) * (cfg.Safe and 1.35 or 1)) end
local function hrp() local c = LP.Character return c and c:FindFirstChild("HumanoidRootPart") end
local function hum() local c = LP.Character return c and c:FindFirstChildOfClass("Humanoid") end
local function alive() local h, r = hum(), hrp() if h and r and h.Health > 0 then return r end end
local lastDbg = ""
local function dbg(e) lastDbg = tostring(e) end

local function goTo(pos, active)
	busy = true
	local t0 = os.clock()
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
		if os.clock() - t0 > 45 then break end
	end
	busy = false
	return ok
end

--------------------------------------------------------------------- MOBS
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

local function baseName(n) return (n:gsub("%s*%d+$", ""):gsub("^%s+", ""):gsub("%s+$", "")) end

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
end

local function nameMatch(m)
	return cfg.MobName == "Any" or baseName(m.Name):lower() == cfg.MobName:lower()
end

local function mobNames()
	local seen, list = {}, { "Any" }
	for _, m in ipairs(mobCache) do
		local n = baseName(m.Name)
		if not seen[n] then seen[n] = true list[#list + 1] = n end
	end
	return list
end

local function pickTarget()
	local r = alive()
	if not r then return end
	local best, bd
	for _, m in ipairs(mobCache) do
		local mr = m.Parent and m:FindFirstChild("HumanoidRootPart")
		local h = m:FindFirstChildOfClass("Humanoid")
		if mr and h and h.Health > 0 and nameMatch(m) then
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

local function bringMobs(target, pos)
	local range = cfg.Safe and math.min(cfg.BringRange, 40) or cfg.BringRange
	for _, m in ipairs(mobCache) do
		if m ~= target and m.Parent then
			local r = m:FindFirstChild("HumanoidRootPart")
			local h = m:FindFirstChildOfClass("Humanoid")
			if r and h and h.Health > 0 and nameMatch(m) and (r.Position - pos).Magnitude <= range then
				r.CFrame = CFrame.new(pos + Vector3.new(jit(-3, 3), 0, jit(-3, 3)))
				r.AssemblyLinearVelocity = Vector3.zero
			end
		end
	end
end

--------------------------------------------------------------------- TOOLS / COMBAT
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
	local c = LP.Character
	local t = c and c:FindFirstChildOfClass("Tool")
	if t then pcall(function() t:Activate() end) end
	pcall(function()
		VirtualUser:CaptureController()
		VirtualUser:ClickButton1(Vector2.new(0, 0))
	end)
end

--------------------------------------------------------------------- QUESTS
local questCache, questCacheT = {}, -1e9
local function questPrompts()
	if os.clock() - questCacheT < 120 then return questCache end
	local list = {}
	for _, o in ipairs(Workspace:GetDescendants()) do
		if o:IsA("ProximityPrompt") or o:IsA("ClickDetector") then
			local holder = o:FindFirstAncestorOfClass("Model")
			local nm = ((holder and holder.Name) or (o.Parent and o.Parent.Name) or ""):lower()
			local at = o:IsA("ProximityPrompt") and (o.ActionText .. o.ObjectText):lower() or ""
			if nm:find("quest") or at:find("quest") then list[#list + 1] = o end
		end
	end
	questCache, questCacheT = list, os.clock()
	return list
end

local function posOf(o)
	local p = o.Parent
	if p and p:IsA("BasePart") then return p.Position end
	local m = o:FindFirstAncestorOfClass("Model")
	if m then return m:GetPivot().Position end
end

local function doQuest()
	lastQuest = os.clock()
	local prompts = questPrompts()
	if #prompts == 0 then status = "No quest NPC found" return end
	local ref = pickTarget()
	local refPos = ref and ref:FindFirstChild("HumanoidRootPart") and ref.HumanoidRootPart.Position
	local best, bd
	for _, o in ipairs(prompts) do
		local p = posOf(o)
		if p then
			local d = refPos and (p - refPos).Magnitude or (p - hrp().Position).Magnitude
			if not bd or d < bd then best, bd = o, d end
		end
	end
	if not best then return end
	status = "Going to quest NPC"
	lockCF = nil
	if goTo(posOf(best) + Vector3.new(0, 3, 0), function() return cfg.Farm end) then
		pause(0.4, 0.8)
		if best:IsA("ProximityPrompt") and fireproximityprompt then
			best.HoldDuration = 0
			pcall(fireproximityprompt, best)
		elseif best:IsA("ClickDetector") and fireclickdetector then
			pcall(fireclickdetector, best)
		end
		pause(0.8, 1.4)
	end
end

--------------------------------------------------------------------- FARM LOOP
local function farmStep()
	equip()
	if cfg.AutoQuest and os.clock() - lastQuest > cfg.QuestEvery then doQuest() end
	local target = pickTarget()
	if not target then
		lockCF = nil
		status = "No mobs found"
		task.wait(0.6)
		return
	end
	local th = target:FindFirstChildOfClass("Humanoid")
	status = "Farming: " .. baseName(target.Name)
	while running and cfg.Farm and target.Parent and th and th.Health > 0 do
		local r = alive()
		if not r then break end
		local tr = target:FindFirstChild("HumanoidRootPart")
		if not tr then break end
		local desired = tr.Position + Vector3.new(0, cfg.Height, 0)
		if (desired - r.Position).Magnitude > 8 then
			lockCF = nil
			goTo(desired, function() return cfg.Farm and target.Parent and th.Health > 0 end)
		else
			lockCF = CFrame.lookAt(desired, Vector3.new(tr.Position.X, desired.Y, tr.Position.Z))
			if cfg.Bring then bringMobs(target, tr.Position) end
			swing()
			pause(0.1, 0.19)
		end
		equip()
	end
	lockCF = nil
	pause(0.05, 0.15)
end

task.spawn(function()
	while running do
		if cfg.Farm and alive() then
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
		if cfg.Hitbox then pcall(applyHitbox) end
		if cfg.ESP then pcall(applyESP) end
		task.wait(2)
	end
end)

bind(RunService.Heartbeat, function()
	local r = alive()
	if r and lockCF then
		r.CFrame = lockCF
		r.AssemblyLinearVelocity = Vector3.zero
		r.AssemblyAngularVelocity = Vector3.zero
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

--------------------------------------------------------------------- ISLANDS
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
	table.sort(out, function(a, b) return a[1] < b[1] end)
	islands = out
	return #out
end

--------------------------------------------------------------------- UI
local C = {
	bg = Color3.fromRGB(16, 16, 26), card = Color3.fromRGB(28, 28, 44), accent = Color3.fromRGB(125, 92, 255),
	off = Color3.fromRGB(60, 60, 84), text = Color3.fromRGB(236, 236, 248), dim = Color3.fromRGB(150, 150, 178),
	bad = Color3.fromRGB(255, 80, 100),
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

local animators = {}
bind(RunService.RenderStepped, function(dt)
	for _, f in ipairs(animators) do f(dt) end
end)

local function randName()
	local s = ""
	for _ = 1, 12 do s = s .. string.char(rnd:NextInteger(97, 122)) end
	return s
end

local gui = Instance.new("ScreenGui")
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

local function notify(text, bad)
	local f = make("Frame", {
		Size = UDim2.new(0, 260, 0, 34), Position = UDim2.new(0.5, -130, 0, -50),
		BackgroundColor3 = C.card, BorderSizePixel = 0, ZIndex = 50,
	}, gui)
	corner(f, 10)
	make("UIStroke", { Color = bad and C.bad or C.accent, Thickness = 1.2 }, f)
	make("TextLabel", {
		Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = text, TextColor3 = C.text,
		Font = Enum.Font.GothamMedium, TextSize = 13, ZIndex = 51,
	}, f)
	tw(f, 0.45, { Position = UDim2.new(0.5, -130, 0, 14) }, Enum.EasingStyle.Back):Play()
	task.delay(2.4, function()
		local t = tw(f, 0.35, { Position = UDim2.new(0.5, -130, 0, -50) })
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
			if not dragging then goal = nil end
		end
	end
end

-- widgets
local function Section(page, text)
	make("TextLabel", {
		Size = UDim2.new(1, -4, 0, 20), BackgroundTransparency = 1, Text = string.upper(text), TextColor3 = C.accent,
		Font = Enum.Font.GothamBold, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left,
	}, page)
end

local function Toggle(page, text, def, cb)
	local f = make("Frame", { Size = UDim2.new(1, -4, 0, 38), BackgroundColor3 = C.card, BorderSizePixel = 0 }, page)
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
		TextColor3 = C.text, Font = Enum.Font.GothamMedium, TextSize = 13, AutoButtonColor = false,
	}, page)
	corner(b, 8)
	bind(b.MouseButton1Down, function() tw(b, 0.1, { BackgroundColor3 = C.accent }):Play() end)
	bind(b.MouseButton1Up, function() tw(b, 0.25, { BackgroundColor3 = C.card }):Play() end)
	bind(b.MouseLeave, function() tw(b, 0.25, { BackgroundColor3 = C.card }):Play() end)
	bind(b.Activated, function() task.spawn(cb, b) end)
	return b
end

local function Cycler(page, text, getList, cb, start)
	local idx = 1
	local b = Button(page, text .. ": " .. tostring(start or "-"), function() end)
	local conn
	b.Activated:Connect(function()
		local l = getList()
		if #l == 0 then notify("List is empty", true) return end
		idx = (idx % #l) + 1
		local v = l[idx]
		b.Text = text .. ": " .. tostring(type(v) == "table" and v[1] or v)
		cb(v)
	end)
	return b
end

local function Slider(page, text, mn, mx, def, cb)
	local f = make("Frame", { Size = UDim2.new(1, -4, 0, 48), BackgroundColor3 = C.card, BorderSizePixel = 0 }, page)
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
	local shown = (def - mn) / (mx - mn)
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

-- main window
local win = make("Frame", {
	Size = UDim2.new(0, 360, 0, 270), Position = UDim2.new(0.5, -180, 0.5, -135),
	BackgroundColor3 = C.bg, BorderSizePixel = 0, Visible = false,
}, gui)
corner(win, 14)
make("UIStroke", { Color = C.accent, Thickness = 1.4, Transparency = 0.35 }, win)
local winScale = make("UIScale", { Scale = 0.01 }, win)

local title = make("Frame", { Size = UDim2.new(1, 0, 0, 34), BackgroundTransparency = 1 }, win)
make("TextLabel", {
	Size = UDim2.new(1, -50, 1, 0), Position = UDim2.new(0, 14, 0, 0), BackgroundTransparency = 1,
	Text = "LEGACY FORTENESS  <font color=\"#7d5cff\">• King Legacy</font>", RichText = true, TextColor3 = C.text,
	Font = Enum.Font.GothamBold, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left,
}, title)
local minBtn = make("TextButton", {
	Size = UDim2.new(0, 28, 0, 22), Position = UDim2.new(1, -38, 0, 6), BackgroundColor3 = C.card, Text = "–",
	TextColor3 = C.text, Font = Enum.Font.GothamBold, TextSize = 16, BorderSizePixel = 0,
}, title)
corner(minBtn, 6)
makeDrag(title, win)

local tabCol = make("Frame", { Size = UDim2.new(0, 78, 1, -64), Position = UDim2.new(0, 8, 0, 38), BackgroundTransparency = 1 }, win)
make("UIListLayout", { Padding = UDim.new(0, 5) }, tabCol)
local pageHolder = make("Frame", { Size = UDim2.new(1, -96, 1, -64), Position = UDim2.new(0, 88, 0, 38), BackgroundTransparency = 1, ClipsDescendants = true }, win)
local statusLbl = make("TextLabel", {
	Size = UDim2.new(1, -20, 0, 20), Position = UDim2.new(0, 12, 1, -24), BackgroundTransparency = 1,
	Text = "Status: Idle", TextColor3 = C.dim, Font = Enum.Font.Gotham, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left,
}, win)

local pages, tabBtns, curTab = {}, {}, nil
local function newTab(name)
	local page = make("ScrollingFrame", {
		Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 3,
		ScrollBarImageColor3 = C.accent, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, Visible = false,
	}, pageHolder)
	make("UIListLayout", { Padding = UDim.new(0, 6) }, page)
	make("UIPadding", { PaddingRight = UDim.new(0, 4), PaddingBottom = UDim.new(0, 6) }, page)
	local b = make("TextButton", {
		Size = UDim2.new(1, 0, 0, 30), BackgroundColor3 = C.card, Text = name, TextColor3 = C.dim,
		Font = Enum.Font.GothamMedium, TextSize = 12, BorderSizePixel = 0, AutoButtonColor = false,
	}, tabCol)
	corner(b, 8)
	pages[name], tabBtns[name] = page, b
	bind(b.Activated, function()
		if curTab == name then return end
		for n, p in pairs(pages) do
			p.Visible = (n == name)
			tw(tabBtns[n], 0.25, { BackgroundColor3 = n == name and C.accent or C.card, TextColor3 = n == name and Color3.new(1, 1, 1) or C.dim }):Play()
		end
		page.Position = UDim2.new(0, 14, 0, 0)
		tw(page, 0.3, { Position = UDim2.new(0, 0, 0, 0) }):Play()
		curTab = name
	end)
	return page
end

local tFarm, tCombat, tTP, tPlayer, tMisc = newTab("Farm"), newTab("Combat"), newTab("Teleport"), newTab("Player"), newTab("Misc")

-- FARM
Section(tFarm, "Auto farm")
Toggle(tFarm, "Auto Farm", false, function(v) cfg.Farm = v if not v then lockCF = nil end end)
Toggle(tFarm, "Auto Quest (nearest NPC)", false, function(v) cfg.AutoQuest = v lastQuest = -1e9 end)
Toggle(tFarm, "Auto Equip Weapon", true, function(v) cfg.AutoEquip = v end)
Cycler(tFarm, "Weapon", weaponNames, function(v) cfg.Weapon = v end, "Auto")
Cycler(tFarm, "Mob", mobNames, function(v) cfg.MobName = v end, "Any")
Slider(tFarm, "Height above mob", 4, 18, cfg.Height, function(v) cfg.Height = v end)
Slider(tFarm, "Move speed", 40, 220, cfg.Speed, function(v) cfg.Speed = v end)

-- COMBAT
Section(tCombat, "Combat")
Toggle(tCombat, "Hitbox Expander", false, function(v)
	cfg.Hitbox = v
	if not v then restoreHitboxes() end
end)
Slider(tCombat, "Hitbox size", 6, 40, cfg.HitboxSize, function(v) cfg.HitboxSize = v end)
Toggle(tCombat, "Bring Mobs", false, function(v) cfg.Bring = v end)
Slider(tCombat, "Bring range", 15, 120, cfg.BringRange, function(v) cfg.BringRange = v end)
Toggle(tCombat, "Mob ESP", false, function(v) cfg.ESP = v if not v then clearESP() end end)

-- TELEPORT
Section(tTP, "Islands / spawns")
Button(tTP, "Scan islands", function() notify("Found " .. scanIslands() .. " locations") end)
Cycler(tTP, "Location", function() return islands end, function(v) islandIdx = table.find(islands, v) or 1 end, "-")
Button(tTP, "Teleport (smooth)", function()
	local v = islands[islandIdx]
	if not v then notify("Scan and pick a location first", true) return end
	tpToken = tpToken + 1
	local my = tpToken
	notify("Heading to " .. v[1])
	task.spawn(function()
		local r = alive()
		if not r then return end
		local wasFarm = cfg.Farm
		cfg.Farm = false
		lockCF = nil
		goTo(v[2] + Vector3.new(0, 8, 0), function() return tpToken == my end)
		cfg.Farm = wasFarm
	end)
end)
Button(tTP, "Cancel teleport", function() tpToken = tpToken + 1 busy = false end)

-- PLAYER
Section(tPlayer, "Player")
Toggle(tPlayer, "Noclip", false, function(v) cfg.Noclip = v end)
Toggle(tPlayer, "Infinite Jump", false, function(v) cfg.InfJump = v end)
Toggle(tPlayer, "Speed boost", false, function(v)
	cfg.SpeedHack = v
	if not v then local h = hum() if h then h.WalkSpeed = 16 end end
end)
Slider(tPlayer, "Walk speed", 16, 80, cfg.WalkSpeed, function(v) cfg.WalkSpeed = v end)

-- MISC
Section(tMisc, "Misc")
local origLight = { Lighting.Brightness, Lighting.ClockTime, Lighting.FogEnd, Lighting.GlobalShadows }
Toggle(tMisc, "Safe Mode (lower risk caps)", true, function(v) cfg.Safe = v end)
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
Button(tMisc, "Server hop", function()
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
end)
Button(tMisc, "Copy debug dump", function()
	local lines = { "PlaceId: " .. game.PlaceId, "Last error: " .. lastDbg, "Mobs seen:" }
	for i, n in ipairs(mobNames()) do if i <= 30 then lines[#lines + 1] = "  " .. n end end
	lines[#lines + 1] = "Tools:"
	for _, t in ipairs(toolList()) do lines[#lines + 1] = "  " .. t.Name end
	lines[#lines + 1] = "Quest prompts:"
	for i, o in ipairs(questPrompts()) do
		if i <= 20 then lines[#lines + 1] = "  " .. o:GetFullName() end
	end
	lines[#lines + 1] = "Islands: " .. #islands
	local txt = table.concat(lines, "\n")
	if setclipboard then setclipboard(txt) notify("Dump copied") else print(txt) notify("Dump printed in console") end
end)
Button(tMisc, "Unload script", function() if env.LF_Cleanup then env.LF_Cleanup() end end)

task.spawn(function()
	while running do
		statusLbl.Text = "Status: " .. (cfg.Farm and status or "Idle") .. "  |  Mobs: " .. #mobCache
		task.wait(0.5)
	end
end)

-- first tab
do
	curTab = nil
	pages.Farm.Visible = true
	tabBtns.Farm.BackgroundColor3 = C.accent
	tabBtns.Farm.TextColor3 = Color3.new(1, 1, 1)
	curTab = "Farm"
end

-- bubble
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

local open = false
local function setOpen(v)
	open = v
	if v then
		win.Visible = true
		tw(winScale, 0.4, { Scale = 1 }, Enum.EasingStyle.Back):Play()
	else
		local t = tw(winScale, 0.25, { Scale = 0.01 }, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
		t:Play()
		t.Completed:Connect(function() if not open then win.Visible = false end end)
	end
end
makeDrag(bubble, bubble, function() setOpen(not open) end)
bind(minBtn.Activated, function() setOpen(false) end)

-- intro + password
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

--------------------------------------------------------------------- CLEANUP
env.LF_Cleanup = function()
	running = false
	cfg.Farm = false
	lockCF = nil
	for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
	pcall(restoreHitboxes)
	pcall(clearESP)
	local h = hum()
	if h and cfg.SpeedHack then h.WalkSpeed = 16 end
	pcall(function() gui:Destroy() end)
	env.LF_Cleanup = nil
end
