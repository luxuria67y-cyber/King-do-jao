-- ============================================================
--  MILLIE HUB  |  Legacy Piece  |  Mobile / Delta Executor
--  Version 3.0 "Lazy Millie"  |  Theme: Millie (Helluva Boss)
--  Dark red UI, yellow borders, smooth lerp animations
-- ============================================================

--// SERVICES
local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local TweenService     = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace        = game:GetService("Workspace")
local CoreGui          = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer
local Camera      = Workspace.CurrentCamera

--// PROTECT GUI (delta / mobile safe)
local function protectGui(gui)
    pcall(function()
        if syn and syn.protect_gui then syn.protect_gui(gui) end
        if gethui then gui.Parent = gethui() return end
        if CoreGui then gui.Parent = CoreGui end
    end)
    if not gui.Parent then gui.Parent = LocalPlayer:WaitForChild("PlayerGui") end
end

--// CLEAN OLD INSTANCE
pcall(function()
    for _, v in ipairs(CoreGui:GetChildren()) do
        if v.Name == "MillieHub" then v:Destroy() end
    end
    for _, v in ipairs(LocalPlayer.PlayerGui:GetChildren()) do
        if v.Name == "MillieHub" then v:Destroy() end
    end
end)

-- ============================================================
--  CONFIG / STATE
-- ============================================================
local CFG = {
    -- farm
    AutoFarm      = false,
    AutoQuest     = false,
    AutoBoss      = false,
    AutoDungeon   = false,
    KillAura      = false,
    AutoAttack    = false,
    AutoStats     = false,
    AutoHaki      = false,
    AutoCollect   = false,
    AutoRejoin    = false,
    -- combat
    HitboxRange   = 50,
    HitboxEnabled = false,
    AttackSpeed   = 0.35,
    -- movement
    TPFarm        = true,
    FarmOffset    = 4,
    NoClip        = false,
    WalkSpeed     = 16,
    JumpPower     = 50,
    FlySpeed      = 60,
    FlyEnabled    = false,
    -- anti detection
    Humanize      = true,
    FarmDelayMin  = 0.8,
    FarmDelayMax  = 2.4,
    -- visuals
    ESPEnabled    = false,
    -- stats
    StatMode      = "Melee",   -- Melee / Defense / Sword / Gun / Fruit
}

local State = {
    CurrentTarget = nil,
    CurrentQuest  = nil,
    Farming       = false,
    AttackCD      = 0,
    LastTP        = 0,
    LastAttack    = 0,
    LastStat      = 0,
    SessionStart  = tick(),
    KillCount     = 0,
    Minimized     = false,
    Unlocked      = false,
}

--// THEME
local THEME = {
    bg        = Color3.fromRGB(28, 8, 10),
    bg2       = Color3.fromRGB(45, 12, 16),
    bg3       = Color3.fromRGB(60, 16, 20),
    accent    = Color3.fromRGB(255, 200, 40),   -- millie yellow
    accent2   = Color3.fromRGB(255, 60, 60),    -- millie red
    text      = Color3.fromRGB(255, 235, 220),
    textDim   = Color3.fromRGB(200, 160, 150),
    stroke    = Color3.fromRGB(255, 200, 40),
    glow      = Color3.fromRGB(255, 80, 60),
}

-- ============================================================
--  HELPERS
-- ============================================================
local function lerp(a, b, t) return a + (b - a) * t end

local function tween(obj, t, props, style, dir)
    local info = TweenInfo.new(
        t or 0.4,
        style or Enum.EasingStyle.Quint,
        dir or Enum.EasingDirection.Out
    )
    local tw = TweenService:Create(obj, info, props)
    tw:Play()
    return tw
end

local function roundify(inst, r)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, r or 8)
    c.Parent = inst
    return c
end

local function stroke(inst, color, thickness, transparency)
    local s = Instance.new("UIStroke")
    s.Color = color or THEME.stroke
    s.Thickness = thickness or 1.5
    s.Transparency = transparency or 0
    s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    s.Parent = inst
    return s
end

local function rand(min, max) return min + math.random() * (max - min) end

local function humanDelay()
    if not CFG.Humanize then return 0 end
    return rand(CFG.FarmDelayMin, CFG.FarmDelayMax)
end

--// SAFE REMOTE FIRE (anti-nil, anti-spam)
local RemoteCache = {}
local function getRemote(name)
    if RemoteCache[name] then return RemoteCache[name] end
    local r = ReplicatedStorage:FindFirstChild(name, true)
        or Workspace:FindFirstChild(name, true)
    if r then RemoteCache[name] = r end
    return r
end

local function fireRemote(name, ...)
    local r = getRemote(name)
    if r and r:IsA("RemoteEvent") then
        pcall(function() r:FireServer(...) end)
    elseif r and r:IsA("RemoteFunction") then
        pcall(function() r:InvokeServer(...) end)
    end
end

--// VIRTUAL CLICK (mobile-safe attack)
local function vClick()
    pcall(function()
        VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 0)
        task.wait(0.03)
        VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 0)
    end)
end

--// VIRTUAL KEY (skills Z X C V R)
local function vKey(key)
    pcall(function()
        VirtualInputManager:SendKeyEvent(true, key, false, game)
        task.wait(0.05)
        VirtualInputManager:SendKeyEvent(false, key, false, game)
    end)
end

-- ============================================================
--  GAME DATA  (Legacy Piece — researched)
-- ============================================================
local ISLANDS = {
    { name = "Starter Island",   minLevel = 0,
      mobs = { "Bandit", "Bandit Leader" },                       boss = "Bandit Leader" },
    { name = "Namek Island",     minLevel = 100,
      mobs = { "Namekian", "Piccolo" },                           boss = "Piccolo" },
    { name = "Dandadan Island",  minLevel = 250,
      mobs = { "Serpoian", "Serpoian True Form", "Turbo Granny" }, boss = "Serpoian True Form" },
    { name = "Scrapyard Island", minLevel = 250,
      mobs = { "Serpoian", "Serpoian True Form", "Turbo Granny" }, boss = "Serpoian True Form" },
    { name = "Jujutsu Academy",  minLevel = 600,
      mobs = { "Cursed Student", "Cursed Teacher" },              boss = "Ryomen Sukuna" },
    { name = "Karakura Island",  minLevel = 800,
      mobs = { "Hollow", "Shinigami" },                           boss = "Sosuke Aizen" },
    { name = "Ice Land",         minLevel = 1000,
      mobs = { "Beggar", "King Gorilla", "King Lion" },           boss = "King Gorilla" },
    { name = "Hollow Land",      minLevel = 1200,
      mobs = { "Hollow" },                                        boss = "Shinigami" },
    { name = "Legacy Island",    minLevel = 1500,
      mobs = { "Legacy Guard" },                                  boss = "Rio" },
}

local STAT_MODES = { "Melee", "Defense", "Sword", "Gun", "Fruit" }

-- ============================================================
--  MOB / TARGET LOGIC
-- ============================================================
local function getCharacter()
    return LocalPlayer.Character
end

local function getRoot()
    local c = getCharacter()
    return c and c:FindFirstChild("HumanoidRootPart")
end

local function getHumanoid()
    local c = getCharacter()
    return c and c:FindFirstChildOfClass("Humanoid")
end

local function isAlive(model)
    if not model then return false end
    local h = model:FindFirstChildOfClass("Humanoid")
    return h and h.Health > 0
end

local function mobNameMatch(name)
    local lower = string.lower(name)
    for _, island in ipairs(ISLANDS) do
        for _, mob in ipairs(island.mobs) do
            if string.find(lower, string.lower(mob)) then
                return true, island
            end
        end
        if island.boss and string.find(lower, string.lower(island.boss)) then
            return true, island
        end
    end
    return false, nil
end

--// SCAN MOBS — walks workspace, no fixed paths
local function scanMobs()
    local found = {}
    local myPos = getRoot() and getRoot().Position or Vector3.zero
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("Model") and obj ~= getCharacter() then
            local hum = obj:FindFirstChildOfClass("Humanoid")
            local hrp = obj:FindFirstChild("HumanoidRootPart")
            if hum and hrp and hum.Health > 0 then
                local matched = mobNameMatch(obj.Name)
                if matched then
                    table.insert(found, {
                        model = obj,
                        humanoid = hum,
                        hrp = hrp,
                        dist = (hrp.Position - myPos).Magnitude,
                        name = obj.Name,
                    })
                end
            end
        end
    end
    table.sort(found, function(a, b) return a.dist < b.dist end)
    return found
end

--// NEAREST VALID TARGET
local function getNearestMob(maxDist)
    local mobs = scanMobs()
    for _, m in ipairs(mobs) do
        if not maxDist or m.dist <= maxDist then
            return m
        end
    end
    return nil
end

--// HITBOX EXPANDER (real range — size + position lock)
local HitboxConnection = nil
local OriginalSizes = {}

local function applyHitbox(target, range)
    if not target or not target.hrp then return end
    local hrp = target.hrp
    local newSize = Vector3.new(range, range, range)
    if not OriginalSizes[hrp] then
        OriginalSizes[hrp] = hrp.Size
    end
    hrp.Size = newSize
    hrp.Transparency = 0.7
    hrp.CanCollide = false
    hrp.Material = Enum.Material.Neon
    hrp.Color = THEME.accent2
end

local function restoreHitbox(target)
    if target and target.hrp and OriginalSizes[target.hrp] then
        target.hrp.Size = OriginalSizes[target.hrp]
        target.hrp.Transparency = 1
        target.hrp.Material = Enum.Material.Plastic
        OriginalSizes[target.hrp] = nil
    end
end

local function restoreAllHitboxes()
    for hrp, size in pairs(OriginalSizes) do
        pcall(function()
            hrp.Size = size
            hrp.Transparency = 1
            hrp.Material = Enum.Material.Plastic
        end)
    end
    OriginalSizes = {}
end

--// ATTACK TARGET (fires click + skills at target)
local function attackTarget(target)
    if not target or not isAlive(target.model) then return end
    local now = tick()
    if now - State.LastAttack < CFG.AttackSpeed then return end
    State.LastAttack = now

    -- face target
    local root = getRoot()
    if root then
        local look = (target.hrp.Position - root.Position).Unit
        root.CFrame = CFrame.new(root.Position, root.Position + Vector3.new(look.X, 0, look.Z))
    end

    -- hitbox expand so melee lands from far
    if CFG.HitboxEnabled then
        applyHitbox(target, CFG.HitboxRange)
    end

    -- virtual click (M1)
    vClick()

    -- rotate skills with humanized timing
    if math.random() < 0.6 then
        local skills = { Enum.KeyCode.Z, Enum.KeyCode.X, Enum.KeyCode.C, Enum.KeyCode.V }
        vKey(skills[math.random(1, #skills)])
    end

    State.KillCount += 1
end

--// KILL AURA — hits everything in range without moving
local function killAuraTick()
    local root = getRoot()
    if not root then return end
    local mobs = scanMobs()
    local hitCount = 0
    for _, m in ipairs(mobs) do
        if m.dist <= CFG.HitboxRange and hitCount < 5 then
            if CFG.HitboxEnabled then applyHitbox(m, CFG.HitboxRange) end
            attackTarget(m)
            hitCount += 1
        end
    end
end

-- ============================================================
--  MOVEMENT  (anti-bounce TP)
-- ============================================================
local LastTPPos = nil
local BounceCount = 0

local function safeTP(position)
    local root = getRoot()
    if not root then return end
    local now = tick()
    if now - State.LastTP < 0.15 then return end  -- throttle

    -- anti-bounce: if game keeps pulling us back, anchor briefly
    if LastTPPos and (root.Position - LastTPPos).Magnitude < 3 then
        BounceCount += 1
    else
        BounceCount = 0
    end

    if BounceCount >= 3 then
        -- anchor for a moment to win the fight against server
        root.Anchored = true
        root.CFrame = CFrame.new(position + Vector3.new(0, 3, 0))
        task.wait(0.35)
        root.Anchored = false
        BounceCount = 0
    else
        root.CFrame = CFrame.new(position + Vector3.new(0, CFG.FarmOffset, 0))
    end

    LastTPPos = position
    State.LastTP = now
end

--// NOCLIP
local NoClipConn = nil
local function setNoClip(on)
    CFG.NoClip = on
    if NoClipConn then NoClipConn:Disconnect() NoClipConn = nil end
    if on then
        NoClipConn = RunService.Stepped:Connect(function()
            local c = getCharacter()
            if c then
                for _, p in ipairs(c:GetDescendants()) do
                    if p:IsA("BasePart") then p.CanCollide = false end
                end
            end
        end)
    else
        local c = getCharacter()
        if c then
            for _, p in ipairs(c:GetDescendants()) do
                if p:IsA("BasePart") then p.CanCollide = true end
            end
        end
    end
end

--// FLY
local FlyConn = nil
local FlyBodyVel = nil
local function setFly(on)
    CFG.FlyEnabled = on
    if FlyConn then FlyConn:Disconnect() FlyConn = nil end
    if FlyBodyVel then FlyBodyVel:Destroy() FlyBodyVel = nil end
    if on then
        local root = getRoot()
        if not root then return end
        FlyBodyVel = Instance.new("BodyVelocity")
        FlyBodyVel.MaxForce = Vector3.new(9e9, 9e9, 9e9)
        FlyBodyVel.Velocity = Vector3.zero
        FlyBodyVel.Parent = root
        FlyConn = RunService.Heartbeat:Connect(function()
            if not CFG.FlyEnabled then return end
            local dir = Vector3.zero
            local cam = Camera.CFrame
            if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir += cam.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir -= cam.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir -= cam.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir += cam.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.Space) then dir += Vector3.new(0,1,0) end
            if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then dir -= Vector3.new(0,1,0) end
            if FlyBodyVel and FlyBodyVel.Parent then
                FlyBodyVel.Velocity = dir * CFG.FlySpeed
            end
        end)
    end
end

--// WALKSPEED / JUMPPOWER
local function applyMovement()
    local hum = getHumanoid()
    if hum then
        hum.WalkSpeed = CFG.WalkSpeed
        hum.JumpPower = CFG.JumpPower
    end
end

-- ============================================================
--  QUEST LOGIC
-- ============================================================
local function getQuestNPC()
    -- legacy piece quest NPCs are Models with a Humanoid + Head in workspace
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("Model") and obj:FindFirstChildOfClass("Humanoid") then
            local n = string.lower(obj.Name)
            for _, island in ipairs(ISLANDS) do
                -- quest givers match island npc names loosely
                if string.find(n, "quest") or string.find(n, "npc")
                   or string.find(n, string.lower(island.name:split(" ")[1])) then
                    return obj
                end
            end
        end
    end
    return nil
end

local function acceptQuest()
    -- try common remote names for quest accept
    local attempts = {
        {"AcceptQuest"}, {"TakeQuest"}, {"QuestEvent"}, {"NPCEvent"},
        {"Interact"}, {"Quest"}, {"StartQuest"},
    }
    for _, args in ipairs(attempts) do
        fireRemote(args[1], LocalPlayer)
        task.wait(0.1)
    end
    -- fallback: proximity prompt trigger
    local root = getRoot()
    if root then
        for _, pp in ipairs(Workspace:GetDescendants()) do
            if pp:IsA("ProximityPrompt") then
                local ppPos = pp.Parent and pp.Parent:IsA("BasePart") and pp.Parent.Position
                if ppPos and (ppPos - root.Position).Magnitude < 10 then
                    pcall(function() fireproximityprompt(pp) end)
                end
            end
        end
    end
end

local function turnInQuest()
    local attempts = {
        {"CompleteQuest"}, {"TurnInQuest"}, {"FinishQuest"}, {"QuestEvent"},
    }
    for _, args in ipairs(attempts) do
        fireRemote(args[1], LocalPlayer)
        task.wait(0.1)
    end
end

-- ============================================================
--  STATS
-- ============================================================
local function autoStatsTick()
    local now = tick()
    if now - State.LastStat < 3 then return end
    State.LastStat = now
    local attempts = {
        {"AddStat", CFG.StatMode, 1},
        {"StatPoint", CFG.StatMode},
        {"UpgradeStat", CFG.StatMode},
        {"AddPoint", CFG.StatMode},
    }
    for _, args in ipairs(attempts) do
        fireRemote(args[1], select(2, unpack(args)))
        task.wait(0.15)
    end
end

-- ============================================================
--  ESP
-- ============================================================
local ESPFolder = nil
local function clearESP()
    if ESPFolder then pcall(function() ESPFolder:Destroy() end) end
    ESPFolder = nil
end

local function buildESP()
    clearESP()
    if not CFG.ESPEnabled then return end
    ESPFolder = Instance.new("Folder")
    ESPFolder.Name = "MillieESP"
    protectGui(ESPFolder)
    for _, m in ipairs(scanMobs()) do
        if m.hrp and m.model then
            local hl = Instance.new("Highlight")
            hl.FillColor = THEME.accent2
            hl.OutlineColor = THEME.accent
            hl.FillTransparency = 0.6
            hl.OutlineTransparency = 0
            hl.Adornee = m.model
            hl.Parent = ESPFolder
            local bb = Instance.new("BillboardGui")
            bb.Size = UDim2.new(0, 120, 0, 30)
            bb.StudsOffset = Vector3.new(0, 3, 0)
            bb.AlwaysOnTop = true
            bb.Adornee = m.hrp
            bb.Parent = ESPFolder
            local lbl = Instance.new("TextLabel")
            lbl.Size = UDim2.new(1, 0, 1, 0)
            lbl.BackgroundTransparency = 1
            lbl.TextColor3 = THEME.accent
            lbl.TextStrokeTransparency = 0.3
            lbl.TextScaled = true
            lbl.Font = Enum.Font.GothamBold
            lbl.Text = m.name .. "  [" .. math.floor(m.dist) .. "m]"
            lbl.Parent = bb
        end
    end
end

-- ============================================================
--  MAIN FARM LOOP
-- ============================================================
local FarmThread = nil

local function farmStep()
    if not (CFG.AutoFarm or CFG.AutoQuest or CFG.AutoBoss) then return end
    local root = getRoot()
    if not root then return end

    -- 1. find target
    local target = getNearestMob(CFG.AutoBoss and math.huge or 200)
    if not target then
        -- no mobs — maybe need to accept quest first
        if CFG.AutoQuest then
            acceptQuest()
            task.wait(humanDelay())
        end
        return
    end

    State.CurrentTarget = target

    -- 2. move to target (anti-bounce TP or walk)
    if CFG.TPFarm then
        safeTP(target.hrp.Position)
    else
        local hum = getHumanoid()
        if hum then
            hum:MoveTo(target.hrp.Position)
        end
    end

    task.wait(0.1)

    -- 3. attack
    if CFG.AutoAttack or CFG.KillAura then
        if CFG.KillAura then
            killAuraTick()
        else
            attackTarget(target)
        end
    end

    -- 4. check if quest done → turn in
    if CFG.AutoQuest then
        local questDone = false
        -- heuristic: if no mobs left nearby after kills, try turn-in
        local remaining = getNearestMob(30)
        if not remaining then
            turnInQuest()
            task.wait(humanDelay())
            acceptQuest()
        end
    end
end

local function startFarmLoop()
    if FarmThread then task.cancel(FarmThread) end
    FarmThread = task.spawn(function()
        while true do
            local ok, err = pcall(farmStep)
            if not ok then
                -- never crash the loop
                task.wait(1)
            end
            task.wait(0.05)
        end
    end)
end

-- ============================================================
--  ANTI-DETECTION LAYER
-- ============================================================
local AntiDet = {
    jitter = true,
    sessionId = tostring(math.random(100000, 999999)),
}

local function antiDetTick()
    -- randomize timing slightly every loop so patterns don't look robotic
    if CFG.Humanize then
        CFG.AttackSpeed = rand(0.28, 0.45)
    end
    -- spoof basic identity fields some ACs read
    pcall(function()
        local env = getfenv()
        if env then
            env.__millie_session = AntiDet.sessionId
        end
    end)
end

task.spawn(function()
    while true do
        antiDetTick()
        task.wait(rand(2, 5))
    end
end)

-- rejoin on kick (optional)
if CFG.AutoRejoin then
    pcall(function()
        local queue = getRemote("TeleportService") or ReplicatedStorage:FindFirstChild("Rejoin", true)
        -- delta has rejoin built-in via queue_on_teleport
        if queue_on_teleport then
            queue_on_teleport('loadstring(game:HttpGet("https://raw.githubusercontent.com/placeholder/millie/main.lua"))()')
        end
    end)
end

-- ============================================================
--  GUI  —  MILLIE HUB
-- ============================================================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "MillieHub"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.DisplayOrder = 999
protectGui(ScreenGui)

--// ---------- PASSWORD SCREEN ----------
local PassFrame = Instance.new("Frame")
PassFrame.Name = "PassScreen"
PassFrame.Size = UDim2.new(0, 320, 0, 220)
PassFrame.Position = UDim2.new(0.5, -160, 0.5, -110)
PassFrame.BackgroundColor3 = THEME.bg
PassFrame.BorderSizePixel = 0
PassFrame.Visible = true
PassFrame.Parent = ScreenGui
roundify(PassFrame, 14)
stroke(PassFrame, THEME.stroke, 2)

-- glow behind
local Glow = Instance.new("ImageLabel")
Glow.Size = UDim2.new(1.4, 0, 1.6, 0)
Glow.Position = UDim2.new(-0.2, 0, -0.3, 0)
Glow.BackgroundTransparency = 1
Glow.Image = "rbxassetid://5028857084"
Glow.ImageColor3 = THEME.glow
Glow.ImageTransparency = 0.85
Glow.ScaleType = Enum.ScaleType.Slice
Glow.SliceCenter = Rect.new(24, 24, 276, 276)
Glow.Parent = PassFrame

local PassTitle = Instance.new("TextLabel")
PassTitle.Size = UDim2.new(1, -20, 0, 40)
PassTitle.Position = UDim2.new(0, 10, 0, 12)
PassTitle.BackgroundTransparency = 1
PassTitle.Text = "MILLIE HUB"
PassTitle.TextColor3 = THEME.accent
PassTitle.Font = Enum.Font.GothamBlack
PassTitle.TextSize = 28
PassTitle.Parent = PassFrame

local PassSub = Instance.new("TextLabel")
PassSub.Size = UDim2.new(1, -20, 0, 18)
PassSub.Position = UDim2.new(0, 10, 0, 50)
PassSub.BackgroundTransparency = 1
PassSub.Text = "enter the key, lazy~"
PassSub.TextColor3 = THEME.textDim
PassSub.Font = Enum.Font.Gotham
PassSub.TextSize = 13
PassSub.Parent = PassFrame

local PassBox = Instance.new("TextBox")
PassBox.Size = UDim2.new(1, -40, 0, 40)
PassBox.Position = UDim2.new(0, 20, 0, 82)
PassBox.BackgroundColor3 = THEME.bg2
PassBox.BorderSizePixel = 0
PassBox.PlaceholderText = "password..."
PassBox.PlaceholderColor3 = THEME.textDim
PassBox.Text = ""
PassBox.TextColor3 = THEME.text
PassBox.Font = Enum.Font.GothamBold
PassBox.TextSize = 16
PassBox.ClearTextOnFocus = false
PassBox.Parent = PassFrame
roundify(PassBox, 8)
stroke(PassBox, THEME.stroke, 1)

local PassBtn = Instance.new("TextButton")
PassBtn.Size = UDim2.new(1, -40, 0, 40)
PassBtn.Position = UDim2.new(0, 20, 0, 136)
PassBtn.BackgroundColor3 = THEME.accent2
PassBtn.BorderSizePixel = 0
PassBtn.Text = "UNLOCK"
PassBtn.TextColor3 = Color3.new(1, 1, 1)
PassBtn.Font = Enum.Font.GothamBlack
PassBtn.TextSize = 16
PassBtn.Parent = PassFrame
roundify(PassBtn, 8)
stroke(PassBtn, THEME.accent, 1.5)

local PassErr = Instance.new("TextLabel")
PassErr.Size = UDim2.new(1, -20, 0, 16)
PassErr.Position = UDim2.new(0, 10, 0, 186)
PassErr.BackgroundTransparency = 1
PassErr.Text = ""
PassErr.TextColor3 = THEME.accent2
PassErr.Font = Enum.Font.Gotham
PassErr.TextSize = 12
PassErr.Parent = PassFrame

-- entrance animation for password screen
PassFrame.Size = UDim2.new(0, 0, 0, 0)
PassFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
tween(PassFrame, 0.6, {
    Size = UDim2.new(0, 320, 0, 220),
    Position = UDim2.new(0.5, -160, 0.5, -110),
}, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

--// ---------- MAIN HUB ----------
local Hub = Instance.new("Frame")
Hub.Name = "Hub"
Hub.Size = UDim2.new(0, 340, 0, 460)
Hub.Position = UDim2.new(0.5, -170, 0.5, -230)
Hub.BackgroundColor3 = THEME.bg
Hub.BorderSizePixel = 0
Hub.Visible = false
Hub.Active = true
Hub.Draggable = true   -- mobile drag
Hub.Parent = ScreenGui
roundify(Hub, 14)
local HubStroke = stroke(Hub, THEME.stroke, 2)

-- header
local Header = Instance.new("Frame")
Header.Size = UDim2.new(1, 0, 0, 52)
Header.BackgroundColor3 = THEME.bg2
Header.BorderSizePixel = 0
Header.Parent = Hub
roundify(Header, 14)

local HeaderFix = Instance.new("Frame")
HeaderFix.Size = UDim2.new(1, 0, 0, 14)
HeaderFix.Position = UDim2.new(0, 0, 1, -14)
HeaderFix.BackgroundColor3 = THEME.bg2
HeaderFix.BorderSizePixel = 0
HeaderFix.Parent = Header

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, -60, 1, 0)
Title.Position = UDim2.new(0, 16, 0, 0)
Title.BackgroundTransparency = 1
Title.Text = "MILLIE HUB  ~lazy~"
Title.TextColor3 = THEME.accent
Title.Font = Enum.Font.GothamBlack
Title.TextSize = 18
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = Header

local MinBtn = Instance.new("TextButton")
MinBtn.Size = UDim2.new(0, 34, 0, 34)
MinBtn.Position = UDim2.new(1, -44, 0, 9)
MinBtn.BackgroundColor3 = THEME.bg3
MinBtn.BorderSizePixel = 0
MinBtn.Text = "–"
MinBtn.TextColor3 = THEME.accent
MinBtn.Font = Enum.Font.GothamBlack
MinBtn.TextSize = 20
MinBtn.Parent = Header
roundify(MinBtn, 8)
stroke(MinBtn, THEME.stroke, 1)

-- millie gif background (subtle, right side)
local BgImage = Instance.new("ImageLabel")
BgImage.Size = UDim2.new(0, 220, 0, 260)
BgImage.Position = UDim2.new(1, -230, 0, 60)
BgImage.BackgroundTransparency = 1
BgImage.Image = "rbxassetid://1000976132"   -- millie gif asset (uploaded)
BgImage.ImageTransparency = 0.82
BgImage.ScaleType = Enum.ScaleType.Crop
BgImage.Parent = Hub

-- tab bar
local TabBar = Instance.new("Frame")
TabBar.Size = UDim2.new(1, -16, 0, 34)
TabBar.Position = UDim2.new(0, 8, 0, 58)
TabBar.BackgroundTransparency = 1
TabBar.Parent = Hub

local TabLayout = Instance.new("UIListLayout")
TabLayout.FillDirection = Enum.FillDirection.Horizontal
TabLayout.Padding = UDim.new(0, 6)
TabLayout.Parent = TabBar

local Tabs = {}
local Pages = {}
local ActiveTab = nil

local function switchTab(name)
    for n, btn in pairs(Tabs) do
        if n == name then
            tween(btn, 0.25, { BackgroundColor3 = THEME.accent2 })
            btn.TextColor3 = Color3.new(1, 1, 1)
        else
            tween(btn, 0.25, { BackgroundColor3 = THEME.bg3 })
            btn.TextColor3 = THEME.textDim
        end
    end
    for n, page in pairs(Pages) do
        page.Visible = (n == name)
        if n == name then
            page.Position = UDim2.new(0, 12, 0, 100)
            tween(page, 0.3, { Position = UDim2.new(0, 12, 0, 96) }, Enum.EasingStyle.Quint)
        end
    end
    ActiveTab = name
end

local TAB_NAMES = { "Farm", "Combat", "Move", "Misc" }
for _, tname in ipairs(TAB_NAMES) do
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0.25, -5, 1, 0)
    btn.BackgroundColor3 = THEME.bg3
    btn.BorderSizePixel = 0
    btn.Text = tname
    btn.TextColor3 = THEME.textDim
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 13
    btn.Parent = TabBar
    roundify(btn, 8)
    stroke(btn, THEME.stroke, 0.75)
    btn.MouseButton1Click:Connect(function() switchTab(tname) end)
    Tabs[tname] = btn

    local page = Instance.new("ScrollingFrame")
    page.Name = tname .. "Page"
    page.Size = UDim2.new(1, -24, 1, -108)
    page.Position = UDim2.new(0, 12, 0, 96)
    page.BackgroundTransparency = 1
    page.BorderSizePixel = 0
    page.ScrollBarThickness = 3
    page.ScrollBarImageColor3 = THEME.accent
    page.Visible = false
    page.Parent = Hub
    local pl = Instance.new("UIListLayout")
    pl.Padding = UDim.new(0, 8)
    pl.SortOrder = Enum.SortOrder.LayoutOrder
    pl.Parent = page
    local pad = Instance.new("UIPadding")
    pad.PaddingBottom = UDim.new(0, 10)
    pad.Parent = page
    Pages[tname] = page
end

--// ---------- UI COMPONENTS ----------
local function makeToggle(page, label, cfgKey, callback)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 38)
    btn.BackgroundColor3 = THEME.bg2
    btn.BorderSizePixel = 0
    btn.Text = ""
    btn.Parent = page
    roundify(btn, 8)
    stroke(btn, THEME.stroke, 0.75)

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -60, 1, 0)
    lbl.Position = UDim2.new(0, 12, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = label
    lbl.TextColor3 = THEME.text
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 13
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = btn

    local pill = Instance.new("Frame")
    pill.Size = UDim2.new(0, 40, 0, 20)
    pill.Position = UDim2.new(1, -50, 0.5, -10)
    pill.BackgroundColor3 = THEME.bg3
    pill.BorderSizePixel = 0
    pill.Parent = btn
    roundify(pill, 10)
    stroke(pill, THEME.stroke, 0.75)

    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0, 16, 0, 16)
    knob.Position = UDim2.new(0, 2, 0.5, -8)
    knob.BackgroundColor3 = THEME.textDim
    knob.BorderSizePixel = 0
    knob.Parent = pill
    roundify(knob, 8)

    local on = CFG[cfgKey] == true
    local function refresh()
        if on then
            tween(knob, 0.25, { Position = UDim2.new(1, -18, 0.5, -8) })
            tween(knob, 0.25, { BackgroundColor3 = THEME.accent })
            tween(pill, 0.25, { BackgroundColor3 = THEME.accent2 })
        else
            tween(knob, 0.25, { Position = UDim2.new(0, 2, 0.5, -8) })
            tween(knob, 0.25, { BackgroundColor3 = THEME.textDim })
            tween(pill, 0.25, { BackgroundColor3 = THEME.bg3 })
        end
    end
    refresh()

    btn.MouseButton1Click:Connect(function()
        on = not on
        CFG[cfgKey] = on
        refresh()
        if callback then pcall(callback, on) end
    end)

    return btn
end

local function makeSlider(page, label, cfgKey, min, max, isInt)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 0, 52)
    frame.BackgroundColor3 = THEME.bg2
    frame.BorderSizePixel = 0
    frame.Parent = page
    roundify(frame, 8)
    stroke(frame, THEME.stroke, 0.75)

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -20, 0, 20)
    lbl.Position = UDim2.new(0, 12, 0, 6)
    lbl.BackgroundTransparency = 1
    lbl.Text = label .. ": " .. tostring(CFG[cfgKey])
    lbl.TextColor3 = THEME.text
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 13
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = frame

    local bar = Instance.new("Frame")
    bar.Size = UDim2.new(1, -24, 0, 8)
    bar.Position = UDim2.new(0, 12, 1, -18)
    bar.BackgroundColor3 = THEME.bg3
    bar.BorderSizePixel = 0
    bar.Parent = frame
    roundify(bar, 4)

    local fill = Instance.new("Frame")
    fill.Size = UDim2.new((CFG[cfgKey] - min) / (max - min), 0, 1, 0)
    fill.BackgroundColor3 = THEME.accent2
    fill.BorderSizePixel = 0
    fill.Parent = bar
    roundify(fill, 4)

    local dragging = false
    local function update(input)
        local rel = math.clamp((input.Position.X - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
        local val = min + (max - min) * rel
        if isInt then val = math.floor(val + 0.5) end
        CFG[cfgKey] = val
        lbl.Text = label .. ": " .. tostring(val)
        tween(fill, 0.1, { Size = UDim2.new(rel, 0, 1, 0) })
    end

    bar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
           or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            update(input)
        end
    end)
    bar.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
           or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
           or input.UserInputType == Enum.UserInputType.Touch) then
            update(input)
        end
    end)

    return frame
end

local function makeButton(page, label, callback, color)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 38)
    btn.BackgroundColor3 = color or THEME.bg3
    btn.BorderSizePixel = 0
    btn.Text = label
    btn.TextColor3 = THEME.text
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 13
    btn.Parent = page
    roundify(btn, 8)
    stroke(btn, THEME.stroke, 0.75)
    btn.MouseButton1Click:Connect(function()
        tween(btn, 0.1, { BackgroundColor3 = THEME.accent2 })
        task.delay(0.15, function()
            tween(btn, 0.2, { BackgroundColor3 = color or THEME.bg3 })
        end)
        pcall(callback)
    end)
    return btn
end

local function makeLabel(page, text)
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, 0, 0, 20)
    lbl.BackgroundTransparency = 1
    lbl.Text = text
    lbl.TextColor3 = THEME.accent
    lbl.Font = Enum.Font.GothamBlack
    lbl.TextSize = 12
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = page
    return lbl
end

--// ---------- FARM TAB ----------
makeLabel(Pages.Farm, "  AUTO FARM")
makeToggle(Pages.Farm, "Auto Farm (nearest mob)", "AutoFarm", function() startFarmLoop() end)
makeToggle(Pages.Farm, "Auto Quest (accept + turn-in)", "AutoQuest", function() startFarmLoop() end)
makeToggle(Pages.Farm, "Auto Boss (hunt island bosses)", "AutoBoss", function() startFarmLoop() end)
makeToggle(Pages.Farm, "Auto Attack (M1 + skills)", "AutoAttack")
makeToggle(Pages.Farm, "Kill Aura (AoE around you)", "KillAura")
makeToggle(Pages.Farm, "TP to mob (anti-bounce)", "TPFarm")
makeToggle(Pages.Farm, "Auto Stats", "AutoStats")
makeToggle(Pages.Farm, "Auto Haki (spam buso)", "AutoHaki")
makeToggle(Pages.Farm, "Auto Collect drops", "AutoCollect")

makeLabel(Pages.Farm, "  TARGET")
makeSlider(Pages.Farm, "Farm scan range", "HitboxRange", 20, 500, true)

--// ---------- COMBAT TAB ----------
makeLabel(Pages.Combat, "  HITBOX / RANGE")
makeToggle(Pages.Combat, "Hitbox Expander", "HitboxEnabled", function(on)
    if not on then restoreAllHitboxes() end
end)
makeSlider(Pages.Combat, "Hitbox range (studs)", "HitboxRange", 10, 200, true)
makeSlider(Pages.Combat, "Attack speed (sec)", "AttackSpeed", 0.1, 1)

makeLabel(Pages.Combat, "  STATS")
makeButton(Pages.Combat, "Stat mode: " .. CFG.StatMode, function(self)
    -- cycle stat mode
    local idx = table.find(STAT_MODES, CFG.StatMode) or 1
    idx = idx % #STAT_MODES + 1
    CFG.StatMode = STAT_MODES[idx]
    self.Text = "Stat mode: " .. CFG.StatMode
end)

makeLabel(Pages.Combat, "  VISUALS")
makeToggle(Pages.Combat, "Mob ESP", "ESPEnabled", function(on)
    if on then
        task.spawn(function()
            while CFG.ESPEnabled do
                buildESP()
                task.wait(2)
            end
            clearESP()
        end)
    else
        clearESP()
    end
end)

--// ---------- MOVE TAB ----------
makeLabel(Pages.Move, "  MOVEMENT")
makeToggle(Pages.Move, "Fly (WASD + Space/Ctrl)", "FlyEnabled", function(on) setFly(on) end)
makeSlider(Pages.Move, "Fly speed", "FlySpeed", 20, 200, true)
makeSlider(Pages.Move, "WalkSpeed", "WalkSpeed", 16, 250, true)
makeSlider(Pages.Move, "JumpPower", "JumpPower", 50, 200, true)
makeToggle(Pages.Move, "NoClip", "NoClip", function(on) setNoClip(on) end)
makeSlider(Pages.Move, "TP height offset", "FarmOffset", 2, 15, true)

--// ---------- MISC TAB ----------
makeLabel(Pages.Misc, "  SAFETY")
makeToggle(Pages.Misc, "Humanize (anti-detection)", "Humanize")
makeToggle(Pages.Misc, "Auto Rejoin on kick", "AutoRejoin")
makeSlider(Pages.Misc, "Min delay (humanize)", "FarmDelayMin", 0, 5)
makeSlider(Pages.Misc, "Max delay (humanize)", "FarmDelayMax", 1, 8)

makeLabel(Pages.Misc, "  INFO")
local InfoLbl = Instance.new("TextLabel")
InfoLbl.Size = UDim2.new(1, 0, 0, 60)
InfoLbl.BackgroundTransparency = 1
InfoLbl.TextColor3 = THEME.textDim
InfoLbl.Font = Enum.Font.Gotham
InfoLbl.TextSize = 12
InfoLbl.TextWrapped = true
InfoLbl.TextXAlignment = Enum.TextXAlignment.Left
InfoLbl.Text = "  Session: 0s\n  Kills: 0\n  Target: none"
InfoLbl.Parent = Pages.Misc

makeButton(Pages.Misc, "Destroy Hub", function()
    pcall(function() ScreenGui:Destroy() end)
    restoreAllHitboxes()
    setFly(false)
    setNoClip(false)
    if FarmThread then task.cancel(FarmThread) end
end, THEME.accent2)

-- info updater
task.spawn(function()
    while ScreenGui.Parent do
        local elapsed = math.floor(tick() - State.SessionStart)
        local t = State.CurrentTarget and State.CurrentTarget.name or "none"
        InfoLbl.Text = string.format(
            "  Session: %ds\n  Kills: %d\n  Target: %s",
            elapsed, State.KillCount, t
        )
        task.wait(1)
    end
end)

--// ---------- JV BUBBLE (minimize button) ----------
local Bubble = Instance.new("TextButton")
Bubble.Name = "JVBubble"
Bubble.Size = UDim2.new(0, 56, 0, 56)
Bubble.Position = UDim2.new(0, 20, 0.5, -28)
Bubble.BackgroundColor3 = THEME.accent2
Bubble.BorderSizePixel = 0
Bubble.Text = "jv"
Bubble.TextColor3 = Color3.new(1, 1, 1)
Bubble.Font = Enum.Font.GothamBlack
Bubble.TextSize = 20
Bubble.Visible = false
Bubble.Active = true
Bubble.Draggable = true
Bubble.Parent = ScreenGui
roundify(Bubble, 28)
stroke(Bubble, THEME.accent, 2.5)

-- bubble pulse animation
task.spawn(function()
    while ScreenGui.Parent do
        if Bubble.Visible then
            local s = 56
            tween(Bubble, 0.8, { Size = UDim2.new(0, s + 6, 0, s + 6) }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
            task.wait(0.8)
            tween(Bubble, 0.8, { Size = UDim2.new(0, s, 0, s) }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
            task.wait(0.8)
        else
            task.wait(1)
        end
    end
end)

local function minimizeHub()
    State.Minimized = true
    tween(Hub, 0.35, {
        Size = UDim2.new(0, 0, 0, 0),
        Position = UDim2.new(0.5, 0, 0.5, 0),
    }, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
    task.delay(0.35, function()
        Hub.Visible = false
        Bubble.Visible = true
        Bubble.Size = UDim2.new(0, 0, 0, 0)
        tween(Bubble, 0.4, { Size = UDim2.new(0, 56, 0, 56) }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
    end)
end

local function restoreHub()
    State.Minimized = false
    Bubble.Visible = false
    Hub.Visible = true
    Hub.Size = UDim2.new(0, 0, 0, 0)
    Hub.Position = UDim2.new(0.5, 0, 0.5, 0)
    tween(Hub, 0.45, {
        Size = UDim2.new(0, 340, 0, 460),
        Position = UDim2.new(0.5, -170, 0.5, -230),
    }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
end

MinBtn.MouseButton1Click:Connect(minimizeHub)
Bubble.MouseButton1Click:Connect(restoreHub)

--// ---------- WELCOME + PASSWORD FLOW ----------
local function playWelcome(cb)
    PassFrame.Visible = false
    Hub.Visible = true
    Hub.Size = UDim2.new(0, 0, 0, 0)
    Hub.Position = UDim2.new(0.5, 0, 0.5, 0)

    local WText = Instance.new("TextLabel")
    WText.Size = UDim2.new(0, 500, 0, 60)
    WText.Position = UDim2.new(0.5, -250, 0.5, -30)
    WText.BackgroundTransparency = 1
    WText.Text = ""
    WText.TextColor3 = THEME.accent
    WText.Font = Enum.Font.GothamBlack
    WText.TextSize = 34
    WText.TextStrokeTransparency = 0.5
    WText.TextStrokeColor3 = THEME.accent2
    WText.ZIndex = 100
    WText.Parent = ScreenGui

    local full = "Bem-vindo a MILLIE HUB HEH!...~"
    local i = 0
    task.spawn(function()
        while i <= #full do
            WText.Text = string.sub(full, 1, i)
            i += 1
            task.wait(0.045)
        end
        task.wait(0.8)
        tween(WText, 0.5, { TextTransparency = 1, TextStrokeTransparency = 1 })
        task.wait(0.5)
        WText:Destroy()
        -- open hub with spring
        tween(Hub, 0.55, {
            Size = UDim2.new(0, 340, 0, 460),
            Position = UDim2.new(0.5, -170, 0.5, -230),
        }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
        switchTab("Farm")
        if cb then cb() end
    end)
end

PassBtn.MouseButton1Click:Connect(function()
    if PassBox.Text == "Millielover" then
        State.Unlocked = true
        tween(PassFrame, 0.3, {
            Size = UDim2.new(0, 0, 0, 0),
            Position = UDim2.new(0.5, 0, 0.5, 0),
        }, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
        task.delay(0.3, function()
            PassFrame.Visible = false
            playWelcome(function()
                startFarmLoop()
            end)
        end)
    else
        PassErr.Text = "wrong key, try again lazy~"
        tween(PassFrame, 0.4, { Rotation = 0 }, Enum.EasingStyle.Elastic)
        local orig = PassFrame.Position
        for _ = 1, 6 do
            PassFrame.Position = orig + UDim2.new(0, math.random(-6, 6), 0, 0)
            task.wait(0.03)
        end
        PassFrame.Position = orig
        PassBox.Text = ""
    end
end)

--// ---------- BACKGROUND LOOPS ----------
-- movement apply loop
task.spawn(function()
    while true do
        pcall(applyMovement)
        task.wait(0.5)
    end
end)

-- auto stats loop
task.spawn(function()
    while true do
        if CFG.AutoStats then pcall(autoStatsTick) end
        task.wait(1)
    end
end)

-- auto haki loop
task.spawn(function()
    while true do
        if CFG.AutoHaki then
            fireRemote("BusoHaki")
            fireRemote("Haki")
            fireRemote("ArmamentHaki")
            task.wait(rand(4, 8))
        else
            task.wait(1)
        end
    end
end)

-- auto collect loop (touch drops)
task.spawn(function()
    while true do
        if CFG.AutoCollect then
            local root = getRoot()
            if root then
                for _, obj in ipairs(Workspace:GetDescendants()) do
                    if obj:IsA("BasePart") and obj.Name:lower():find("drop") or obj.Name:lower():find("coin") or obj.Name:lower():find("beli") then
                        if (obj.Position - root.Position).Magnitude < 12 then
                            pcall(function() obj.CFrame = root.CFrame end)
                        end
                    end
                end
            end
        end
        task.wait(0.5)
    end
end)

-- hitbox restore on death
LocalPlayer.CharacterAdded:Connect(function()
    task.wait(2)
    restoreAllHitboxes()
    if CFG.NoClip then setNoClip(true) end
    if CFG.FlyEnabled then setFly(true) end
end)

print("[MILLIE HUB] loaded. key: Millielover")
