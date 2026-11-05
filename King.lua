-- ══════════════════════════════════════════════════════════════
--   MILLIE HUB v4.0 "LAZY"  ·  LEGACY PIECE  ·  MOBILE / DELTA
--   dark red · yellow borders · smooth lerp · premium build
-- ══════════════════════════════════════════════════════════════

local unpack = table.unpack or unpack

-- ── ERROR OVERLAY (se qualquer coisa quebrar, você VÊ o erro) ──
local ErrorGui = Instance.new("ScreenGui")
ErrorGui.Name = "MillieError"
ErrorGui.ResetOnSpawn = false
ErrorGui.DisplayOrder = 10000
local okParent, _ = pcall(function() ErrorGui.Parent = game:GetService("CoreGui") end)
if not okParent then ErrorGui.Parent = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui") end

local LOAD_OK, LOAD_ERR = pcall(function()

-- ═══════════════════════ SERVICES ═══════════════════════
local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local TweenService      = game:GetService("TweenService")
local UserInputService  = game:GetService("UserInputService")
local VIM               = game:GetService("VirtualInputManager")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace         = game:GetService("Workspace")
local Lighting          = game:GetService("Lighting")
local Stats             = game:GetService("Stats")

local LP      = Players.LocalPlayer
local Camera  = Workspace.CurrentCamera
local PlayerGui = LP:WaitForChild("PlayerGui")

-- ═══════════════════ EXECUTOR COMPAT ═══════════════════
local function protect(gui)
    local done = false
    pcall(function()
        if typeof(syn) == "table" and syn.protect_gui then
            syn.protect_gui(gui); gui.Parent = game:GetService("CoreGui"); done = true
        end
    end)
    if not done then
        pcall(function()
            if gethui then gui.Parent = gethui(); done = true end
        end)
    end
    if not done then
        pcall(function() gui.Parent = game:GetService("CoreGui"); done = true end)
    end
    if not done then gui.Parent = PlayerGui end
end

-- limpa instâncias antigas
pcall(function()
    for _, g in ipairs({game:GetService("CoreGui"), PlayerGui}) do
        for _, v in ipairs(g:GetChildren()) do
            if v.Name == "MillieHub" or v.Name == "MillieError" and v ~= ErrorGui then
                pcall(function() v:Destroy() end)
            end
        end
    end
end)

-- ═══════════════════════ THEME ═══════════════════════
local T = {
    bg0   = Color3.fromRGB(20, 5, 7),
    bg1   = Color3.fromRGB(32, 9, 12),
    bg2   = Color3.fromRGB(48, 14, 18),
    bg3   = Color3.fromRGB(66, 20, 25),
    red   = Color3.fromRGB(200, 40, 45),
    red2  = Color3.fromRGB(255, 70, 70),
    yel   = Color3.fromRGB(255, 200, 45),
    yel2  = Color3.fromRGB(255, 225, 120),
    txt   = Color3.fromRGB(255, 238, 225),
    dim   = Color3.fromRGB(190, 150, 140),
    dark  = Color3.fromRGB(12, 3, 4),
}

-- ═══════════════════════ CONFIG ═══════════════════════
local CFG = {
    -- farm
    AutoFarm     = false,
    AutoQuest    = false,
    AutoBoss     = false,
    KillAura     = false,
    AutoAttack   = true,
    AutoStats    = false,
    AutoHaki     = false,
    AutoCollect  = false,
    AutoRejoin   = false,
    AutoSkill    = true,
    -- combat
    HitboxEnabled= false,
    HitboxRange  = 55,
    AttackSpeed  = 0.35,
    TargetIsland = "Auto",      -- ou nome da ilha
    -- move
    TPFarm       = true,
    FarmOffset   = 5,
    NoClip       = false,
    WalkSpeed    = 16,
    JumpPower    = 50,
    FlyEnabled   = false,
    FlySpeed     = 60,
    -- safety
    Humanize     = true,
    -- visual
    ESP          = false,
    StatMode     = "Melee",
}

local S = {
    Unlocked    = false,
    Minimized   = false,
    KillCount   = 0,
    StartTime   = tick(),
    Target      = nil,
    MobCache    = {},
    CacheTime   = 0,
    LastAttack  = 0,
    LastTP      = 0,
    LastStat    = 0,
    LastQuest   = 0,
    Bounce      = 0,
    LastTPPos   = nil,
    CurrentTab  = nil,
    Dragging    = false,
}

-- ═══════════════════════ HELPERS ═══════════════════════
local function tw(obj, time, props, style, dir)
    local i = TweenInfo.new(time or 0.35, style or Enum.EasingStyle.Quint, dir or Enum.EasingDirection.Out)
    local t = TweenService:Create(obj, i, props)
    t:Play()
    return t
end

local function corner(p, r)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, r or 8)
    c.Parent = p
    return c
end

local function stroke(p, col, th, tr)
    local s = Instance.new("UIStroke")
    s.Color = col or T.yel
    s.Thickness = th or 1.5
    s.Transparency = tr or 0
    s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    s.Parent = p
    return s
end

local function grad(p, c1, c2, rot)
    local g = Instance.new("UIGradient")
    g.Color = ColorSequence.new{
        ColorSequenceKeypoint.new(0, c1),
        ColorSequenceKeypoint.new(1, c2),
    }
    g.Rotation = rot or 90
    g.Parent = p
    return g
end

local function pad(p, l, r, t, b)
    local pd = Instance.new("UIPadding")
    pd.PaddingLeft   = UDim.new(0, l or 0)
    pd.PaddingRight  = UDim.new(0, r or 0)
    pd.PaddingTop    = UDim.new(0, t or 0)
    pd.PaddingBottom = UDim.new(0, b or 0)
    pd.Parent = p
    return pd
end

local function rand(a, b) return a + math.random() * (b - a) end
local function hdel() return CFG.Humanize and rand(0.5, 1.8) or 0 end

-- drag próprio (Draggable foi REMOVIDO da roblox — aqui é o fix)
local function makeDraggable(handle, frame)
    local dragging = false
    local dragStart, startPos
    handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = frame.Position
            tw(frame, 0.15, { Size = frame.Size - UDim2.new(0,0,0,0) })
        end
    end)
    handle.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            frame.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y
            )
        end
    end)
end

-- ═══════════════════ REMOTE / NETWORK ═══════════════════
local RCache = {}
local function getRemote(name)
    if RCache[name] ~= nil then return RCache[name] end
    local r = ReplicatedStorage:FindFirstChild(name, true)
    RCache[name] = r or false
    return r or nil
end

local function fire(name, ...)
    local r = getRemote(name)
    if not r then return end
    if r:IsA("RemoteEvent") then
        pcall(function() r:FireServer(...) end)
    elseif r:IsA("RemoteFunction") then
        pcall(function() r:InvokeServer(...) end)
    end
end

-- nomes comuns de remotes em jogos estilo piece
local QUEST_ACCEPT = {"AcceptQuest","TakeQuest","StartQuest","GiveQuest","Quest","QuestAccept","NPCQuest","Accept"}
local QUEST_DONE   = {"CompleteQuest","TurnInQuest","FinishQuest","QuestDone","TurnQuest","Complete"}
local STAT_ADD     = {"AddStat","AddPoint","UpgradeStat","StatPoint","SpendPoint","AddStatPoint"}
local HAKI_NAMES   = {"BusoHaki","ArmamentHaki","Haki","KenHaki","ObservationHaki","EnableHaki"}

local function tryQuestAccept()
    for _, n in ipairs(QUEST_ACCEPT) do fire(n, "Bandit") task.wait(0.06) end
    fire("QuestEvent", "Accept")
    fire("NPCEvent", "Quest")
    -- proximity prompts por perto
    local root = S.Root()
    if root then
        for _, pp in ipairs(Workspace:GetDescendants()) do
            if pp:IsA("ProximityPrompt") and pp.Parent and pp.Parent:IsA("BasePart") then
                if (pp.Parent.Position - root.Position).Magnitude < 12 then
                    pcall(function() fireproximityprompt(pp) end)
                end
            end
        end
    end
end

local function tryQuestDone()
    for _, n in ipairs(QUEST_DONE) do fire(n) task.wait(0.06) end
    fire("QuestEvent", "Complete")
end

-- ═══════════════════ GAME DATA (Legacy Piece) ═══════════════════
local ISLANDS = {
    {n="Starter Island",  min=0,    mobs={"Bandit","Bandit Leader","Monkey"},           boss="Bandit Leader"},
    {n="Sand Island",     min=50,   mobs={"Sand Bandit","Desert Rogue"},                boss="Sand King"},
    {n="Namek Island",    min=100,  mobs={"Namekian","Evil Namekian","Piccolo"},        boss="Piccolo"},
    {n="Dandadan Island", min=250,  mobs={"Serpoian","Serpoian True Form","Turbo Granny"}, boss="Turbo Granny"},
    {n="Scrapyard",       min=400,  mobs={"Scrap Robot","Junk Golem"},                  boss="Scrap King"},
    {n="Jujutsu Academy", min=600,  mobs={"Cursed Student","Cursed Teacher","Curse"},    boss="Ryomen Sukuna"},
    {n="Karakura",        min=800,  mobs={"Hollow","Menos","Shinigami"},                boss="Sosuke Aizen"},
    {n="Ice Land",        min=1000, mobs={"Ice Bandit","Frost Soldier","Yeti"},          boss="Ice Queen"},
    {n="Hollow Land",     min=1200, mobs={"Hollow","Vasto Lorde"},                      boss="Vasto Lorde"},
    {n="Legacy Island",   min=1500, mobs={"Legacy Guard","Ancient Warrior"},            boss="Rio"},
}

local STAT_MODES = {"Melee","Defense","Sword","Gun","Fruit"}
local MOB_TAGS = {"Mob","Enemy","NPC","Boss"}

-- ═══════════════════ CHARACTER ACCESS ═══════════════════
function S.Root()
    local c = LP.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end
function S.Hum()
    local c = LP.Character
    return c and c:FindFirstChildOfClass("Humanoid")
end
local function alive(m)
    if not m then return false end
    local h = m:FindFirstChildOfClass("Humanoid")
    return h ~= nil and h.Health > 0
end

-- ═══════════════════ MOB SCAN (com cache) ═══════════════════
local function islandMatch(name)
    local l = string.lower(name)
    if CFG.TargetIsland ~= "Auto" then
        for _, isl in ipairs(ISLANDS) do
            if isl.n == CFG.TargetIsland then
                for _, m in ipairs(isl.mobs) do
                    if string.find(l, string.lower(m), 1, true) then return true end
                end
                if string.find(l, string.lower(isl.boss), 1, true) then return true end
            end
        end
        return false
    end
    for _, isl in ipairs(ISLANDS) do
        for _, m in ipairs(isl.mobs) do
            if string.find(l, string.lower(m), 1, true) then return true end
        end
        if string.find(l, string.lower(isl.boss), 1, true) then return true end
    end
    return false
end

local function refreshMobCache()
    local root = S.Root()
    local myPos = root and root.Position or Vector3.zero
    local out = {}
    for _, obj in ipairs(Workspace:GetChildren()) do
        -- varre primeiro nível + descendants só de pastas prováveis
        local models
        local okM, res = pcall(function()
            local t = {}
            for _, d in ipairs(obj:GetDescendants()) do
                if d:IsA("Model") then table.insert(t, d) end
            end
            return t
        end)
        models = okM and res or {}
        for _, m in ipairs(models) do
            if m ~= LP.Character and #out < 60 then
                local hum = m:FindFirstChildOfClass("Humanoid")
                local hrp = m:FindFirstChild("HumanoidRootPart")
                if hum and hrp and hum.Health > 0 and hum.MaxHealth > 15 then
                    local isPlayer = Players:GetPlayerFromCharacter(m) ~= nil
                    if not isPlayer and (islandMatch(m.Name) or m:FindFirstChild("Mob") or string.find(string.lower(m.Name), "boss", 1, true)) then
                        table.insert(out, {
                            model = m, hum = hum, hrp = hrp,
                            dist = (hrp.Position - myPos).Magnitude,
                            name = m.Name,
                        })
                    end
                end
            end
        end
    end
    table.sort(out, function(a,b) return a.dist < b.dist end)
    S.MobCache = out
    S.CacheTime = tick()
end

local function nearestMob(maxDist)
    if tick() - S.CacheTime > 0.4 then refreshMobCache() end
    for _, m in ipairs(S.MobCache) do
        if alive(m.model) and (not maxDist or m.dist <= maxDist) then
            if CFG.AutoBoss and not string.find(string.lower(m.name), "boss", 1, true)
               and not string.find(string.lower(m.name), "leader", 1, true)
               and not string.find(string.lower(m.name), "king", 1, true)
               and not string.find(string.lower(m.name), "queen", 1, true) then
                -- pula não-bosses quando AutoBoss
            else
                return m
            end
        end
    end
    -- fallback: se AutoBoss e não achou boss, pega qualquer um
    if CFG.AutoBoss then
        for _, m in ipairs(S.MobCache) do
            if alive(m.model) then return m end
        end
    end
    return nil
end

-- ═══════════════════ HITBOX EXPANDER ═══════════════════
local OrigSizes = {}
local function hitbox(target, range)
    if not target or not target.hrp then return end
    local hrp = target.hrp
    if not OrigSizes[hrp] then OrigSizes[hrp] = {hrp.Size, hrp.Transparency, hrp.Material, hrp.CanCollide} end
    hrp.Size = Vector3.new(range, range, range)
    hrp.Transparency = 0.75
    hrp.Material = Enum.Material.Neon
    hrp.Color = T.red2
    hrp.CanCollide = false
end

local function restoreOne(hrp)
    local o = OrigSizes[hrp]
    if o then
        pcall(function()
            hrp.Size = o[1]; hrp.Transparency = o[2]
            hrp.Material = o[3]; hrp.CanCollide = o[4]
        end)
        OrigSizes[hrp] = nil
    end
end

local function restoreAll()
    for hrp, _ in pairs(OrigSizes) do restoreOne(hrp) end
end

-- ═══════════════════ ATTACK ═══════════════════
local function vClick()
    pcall(function()
        VIM:SendMouseButtonEvent(0, 0, 0, true, game, 0)
        task.wait(0.03)
        VIM:SendMouseButtonEvent(0, 0, 0, false, game, 0)
    end)
end

local function vKey(kc)
    pcall(function()
        VIM:SendKeyEvent(true, kc, false, game)
        task.wait(0.05)
        VIM:SendKeyEvent(false, kc, false, game)
    end)
end

local SKILLS = {Enum.KeyCode.Z, Enum.KeyCode.X, Enum.KeyCode.C, Enum.KeyCode.V, Enum.KeyCode.R}

local function attack(target)
    if not target or not alive(target.model) then return false end
    local now = tick()
    local spd = CFG.Humanize and rand(0.25, 0.5) or CFG.AttackSpeed
    if now - S.LastAttack < spd then return true end
    S.LastAttack = now

    local root = S.Root()
    if root and target.hrp then
        local look = target.hrp.Position - root.Position
        if look.Magnitude > 0.1 then
            look = Vector3.new(look.X, 0, look.Z).Unit
            root.CFrame = CFrame.new(root.Position, root.Position + look)
        end
    end

    if CFG.HitboxEnabled then hitbox(target, CFG.HitboxRange) end

    vClick()

    if CFG.AutoSkill and math.random() < 0.55 then
        vKey(SKILLS[math.random(1, #SKILLS)])
    end

    S.KillCount = S.KillCount + 1
    return true
end

local function killAura()
    local root = S.Root()
    if not root then return end
    if tick() - S.CacheTime > 0.4 then refreshMobCache() end
    local hits = 0
    for _, m in ipairs(S.MobCache) do
        if hits >= 6 then break end
        if alive(m.model) and m.dist <= CFG.HitboxRange then
            attack(m)
            hits = hits + 1
        end
    end
end

-- ═══════════════════ MOVEMENT ═══════════════════
local function safeTP(pos)
    local root = S.Root()
    if not root then return end
    local now = tick()
    if now - S.LastTP < 0.2 then return end

    -- anti-bounce: se o servidor puxar de volta, ancora e força
    if S.LastTPPos and (root.Position - S.LastTPPos).Magnitude < 3 then
        S.Bounce = S.Bounce + 1
    else
        S.Bounce = 0
    end

    if S.Bounce >= 3 then
        root.Anchored = true
        root.CFrame = CFrame.new(pos + Vector3.new(0, CFG.FarmOffset + 2, 0))
        task.wait(0.4)
        root.Anchored = false
        S.Bounce = 0
    else
        root.CFrame = CFrame.new(pos + Vector3.new(0, CFG.FarmOffset, 0))
    end

    S.LastTPPos = pos
    S.LastTP = now
end

local NoClipConn = nil
local function setNoClip(on)
    if NoClipConn then NoClipConn:Disconnect() NoClipConn = nil end
    if on then
        NoClipConn = RunService.Stepped:Connect(function()
            local c = LP.Character
            if c then
                for _, p in ipairs(c:GetDescendants()) do
                    if p:IsA("BasePart") then p.CanCollide = false end
                end
            end
        end)
    else
        local c = LP.Character
        if c then
            for _, p in ipairs(c:GetDescendants()) do
                if p:IsA("BasePart") then p.CanCollide = true end
            end
        end
    end
end

local FlyConn, FlyVel = nil, nil
local function setFly(on)
    if FlyConn then FlyConn:Disconnect() FlyConn = nil end
    if FlyVel then pcall(function() FlyVel:Destroy() end) FlyVel = nil end
    if not on then return end
    local root = S.Root()
    if not root then return end
    FlyVel = Instance.new("BodyVelocity")
    FlyVel.MaxForce = Vector3.new(9e9, 9e9, 9e9)
    FlyVel.Velocity = Vector3.zero
    FlyVel.Parent = root
    FlyConn = RunService.Heartbeat:Connect(function()
        if not CFG.FlyEnabled or not FlyVel or not FlyVel.Parent then return end
        local dir = Vector3.zero
        local cf = Camera.CFrame
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir = dir + cf.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir = dir - cf.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir = dir - cf.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir = dir + cf.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then dir = dir + Vector3.new(0,1,0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then dir = dir - Vector3.new(0,1,0) end
        FlyVel.Velocity = dir * CFG.FlySpeed
    end)
end

local function applyMove()
    local h = S.Hum()
    if h then h.WalkSpeed = CFG.WalkSpeed; h.JumpPower = CFG.JumpPower end
end

-- ═══════════════════ ESP ═══════════════════
local ESPFolder = nil
local function clearESP()
    if ESPFolder then pcall(function() ESPFolder:Destroy() end) end
    ESPFolder = nil
end
local function buildESP()
    clearESP()
    if not CFG.ESP then return end
    ESPFolder = Instance.new("Folder")
    ESPFolder.Name = "MESP"
    pcall(function() ESPFolder.Parent = gethui and gethui() or game:GetService("CoreGui") end)
    if not ESPFolder.Parent then ESPFolder.Parent = PlayerGui end
    if tick() - S.CacheTime > 0.4 then refreshMobCache() end
    for _, m in ipairs(S.MobCache) do
        if alive(m.model) and m.hrp then
            local hl = Instance.new("Highlight")
            hl.FillColor = T.red2
            hl.OutlineColor = T.yel
            hl.FillTransparency = 0.65
            hl.Adornee = m.model
            hl.Parent = ESPFolder
            local bb = Instance.new("BillboardGui")
            bb.Size = UDim2.new(0, 130, 0, 32)
            bb.StudsOffset = Vector3.new(0, 3.2, 0)
            bb.AlwaysOnTop = true
            bb.Adornee = m.hrp
            bb.Parent = ESPFolder
            local hp = Instance.new("Frame")
            hp.Size = UDim2.new(1, 0, 0, 4)
            hp.Position = UDim2.new(0, 0, 1, -6)
            hp.BackgroundColor3 = T.dark
            hp.BorderSizePixel = 0
            hp.Parent = bb
            corner(hp, 2)
            local hpf = Instance.new("Frame")
            hpf.Size = UDim2.new(math.clamp(m.hum.Health / m.hum.MaxHealth, 0, 1), 0, 1, 0)
            hpf.BackgroundColor3 = T.red2
            hpf.BorderSizePixel = 0
            hpf.Parent = hp
            corner(hpf, 2)
            local lbl = Instance.new("TextLabel")
            lbl.Size = UDim2.new(1, 0, 1, -8)
            lbl.BackgroundTransparency = 1
            lbl.TextColor3 = T.yel
            lbl.TextStrokeTransparency = 0.4
            lbl.Font = Enum.Font.GothamBold
            lbl.TextScaled = true
            lbl.Text = m.name .. " [" .. math.floor(m.dist) .. "m]"
            lbl.Parent = bb
        end
    end
end

-- ══════════════════════════════════════════════════════════════
--   GUI
-- ══════════════════════════════════════════════════════════════
local GUI = Instance.new("ScreenGui")
GUI.Name = "MillieHub"
GUI.ResetOnSpawn = false
GUI.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
GUI.DisplayOrder = 999
protect(GUI)

-- ── notificações ──
local NotifHolder = Instance.new("Frame")
NotifHolder.Size = UDim2.new(0, 260, 1, -40)
NotifHolder.Position = UDim2.new(1, -270, 0, 20)
NotifHolder.BackgroundTransparency = 1
NotifHolder.Parent = GUI

local function notify(text, dur)
    local f = Instance.new("Frame")
    f.Size = UDim2.new(1, 0, 0, 44)
    f.BackgroundColor3 = T.bg2
    f.BorderSizePixel = 0
    f.Position = UDim2.new(1, 40, 0, 0)
    f.Parent = NotifHolder
    corner(f, 10)
    stroke(f, T.yel, 1.25)
    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(1, -16, 1, 0)
    l.Position = UDim2.new(0, 12, 0, 0)
    l.BackgroundTransparency = 1
    l.Text = text
    l.TextColor3 = T.txt
    l.Font = Enum.Font.GothamBold
    l.TextSize = 12
    l.TextWrapped = true
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.Parent = f
    tw(f, 0.4, { Position = UDim2.new(0, 0, 0, 0) }, Enum.EasingStyle.Back)
    task.delay(dur or 3, function()
        local t = tw(f, 0.3, { Position = UDim2.new(1, 40, 0, 0) })
        t.Completed:Wait()
        f:Destroy()
    end)
end

-- ── PASSWORD SCREEN ──
local Pass = Instance.new("Frame")
Pass.Name = "Pass"
Pass.Size = UDim2.new(0, 330, 0, 250)
Pass.Position = UDim2.new(0.5, -165, 0.5, -125)
Pass.BackgroundColor3 = T.bg1
Pass.BorderSizePixel = 0
Pass.Parent = GUI
corner(Pass, 16)
stroke(Pass, T.yel, 2)
grad(Pass, T.bg0, T.bg2, 115)

-- sombra/glow
local glow = Instance.new("ImageLabel")
glow.Size = UDim2.new(1.5, 0, 1.7, 0)
glow.Position = UDim2.new(-0.25, 0, -0.35, 0)
glow.BackgroundTransparency = 1
glow.Image = "rbxassetid://5028857084"
glow.ImageColor3 = T.red
glow.ImageTransparency = 0.8
glow.ScaleType = Enum.ScaleType.Slice
glow.SliceCenter = Rect.new(24, 24, 276, 276)
glow.Parent = Pass

-- mini "millie" silhouette: chifres + cabelo (formas simples)
local hornL = Instance.new("Frame")
hornL.Size = UDim2.new(0, 14, 0, 34)
hornL.Position = UDim2.new(0.5, -42, 0, -18)
hornL.BackgroundColor3 = T.dark
hornL.BorderSizePixel = 0
hornL.Rotation = -18
hornL.Parent = Pass
corner(hornL, 7)
local hornR = Instance.new("Frame")
hornR.Size = UDim2.new(0, 14, 0, 34)
hornR.Position = UDim2.new(0.5, 28, 0, -18)
hornR.BackgroundColor3 = T.dark
hornR.BorderSizePixel = 0
hornR.Rotation = 18
hornR.Parent = Pass
corner(hornR, 7)
stroke(hornL, T.yel, 1)
stroke(hornR, T.yel, 1)

local pTitle = Instance.new("TextLabel")
pTitle.Size = UDim2.new(1, -20, 0, 44)
pTitle.Position = UDim2.new(0, 10, 0, 20)
pTitle.BackgroundTransparency = 1
pTitle.Text = "MILLIE HUB"
pTitle.TextColor3 = T.yel
pTitle.Font = Enum.Font.GothamBlack
pTitle.TextSize = 30
pTitle.Parent = Pass

local pSub = Instance.new("TextLabel")
pSub.Size = UDim2.new(1, -20, 0, 18)
pSub.Position = UDim2.new(0, 10, 0, 62)
pSub.BackgroundTransparency = 1
pSub.Text = "key check · lazy edition"
pSub.TextColor3 = T.dim
pSub.Font = Enum.Font.Gotham
pSub.TextSize = 12
pSub.Parent = Pass

local pBox = Instance.new("TextBox")
pBox.Size = UDim2.new(1, -44, 0, 42)
pBox.Position = UDim2.new(0, 22, 0, 96)
pBox.BackgroundColor3 = T.bg0
pBox.BorderSizePixel = 0
pBox.PlaceholderText = "password..."
pBox.PlaceholderColor3 = T.dim
pBox.Text = ""
pBox.TextColor3 = T.txt
pBox.Font = Enum.Font.GothamBold
pBox.TextSize = 16
pBox.ClearTextOnFocus = false
pBox.Parent = Pass
corner(pBox, 10)
stroke(pBox, T.yel, 1.25)

local pBtn = Instance.new("TextButton")
pBtn.Size = UDim2.new(1, -44, 0, 42)
pBtn.Position = UDim2.new(0, 22, 0, 150)
pBtn.BackgroundColor3 = T.red
pBtn.BorderSizePixel = 0
pBtn.Text = "UNLOCK"
pBtn.TextColor3 = Color3.new(1,1,1)
pBtn.Font = Enum.Font.GothamBlack
pBtn.TextSize = 15
pBtn.Parent = Pass
corner(pBtn, 10)
stroke(pBtn, T.yel, 1.5)
grad(pBtn, T.red2, T.red, 90)

local pErr = Instance.new("TextLabel")
pErr.Size = UDim2.new(1, -20, 0, 16)
pErr.Position = UDim2.new(0, 10, 0, 202)
pErr.BackgroundTransparency = 1
pErr.Text = ""
pErr.TextColor3 = T.red2
pErr.Font = Enum.Font.GothamBold
pErr.TextSize = 12
pErr.Parent = Pass

-- entrada
Pass.Size = UDim2.new(0, 0, 0, 0)
Pass.Position = UDim2.new(0.5, 0, 0.5, 0)
tw(Pass, 0.65, {
    Size = UDim2.new(0, 330, 0, 250),
    Position = UDim2.new(0.5, -165, 0.5, -125),
}, Enum.EasingStyle.Back)

-- ── HUB ──
local Hub = Instance.new("Frame")
Hub.Name = "Hub"
Hub.Size = UDim2.new(0, 350, 0, 470)
Hub.Position = UDim2.new(0.5, -175, 0.5, -235)
Hub.BackgroundColor3 = T.bg1
Hub.BorderSizePixel = 0
Hub.Visible = false
Hub.Active = true
Hub.ClipsDescendants = true
Hub.Parent = GUI
corner(Hub, 16)
stroke(Hub, T.yel, 2)
grad(Hub, T.bg0, T.bg2, 100)

-- header
local Header = Instance.new("Frame")
Header.Size = UDim2.new(1, 0, 0, 54)
Header.BackgroundColor3 = T.bg2
Header.BorderSizePixel = 0
Header.Parent = Hub
corner(Header, 16)
local hfix = Instance.new("Frame")
hfix.Size = UDim2.new(1, 0, 0, 16)
hfix.Position = UDim2.new(0, 0, 1, -16)
hfix.BackgroundColor3 = T.bg2
hfix.BorderSizePixel = 0
hfix.Parent = Header

-- olhos da millie no header (detalhe temático)
for _, off in ipairs({-26, 10}) do
    local eye = Instance.new("Frame")
    eye.Size = UDim2.new(0, 16, 0, 18)
    eye.Position = UDim2.new(0, 14 + (off < 0 and 0 or 20), 0, 16)
    eye.BackgroundColor3 = T.yel
    eye.BorderSizePixel = 0
    eye.Parent = Header
    corner(eye, 8)
    local star = Instance.new("TextLabel")
    star.Size = UDim2.new(1, 0, 1, 0)
    star.BackgroundTransparency = 1
    star.Text = "★"
    star.TextColor3 = T.dark
    star.Font = Enum.Font.GothamBlack
    star.TextSize = 12
    star.Parent = eye
end

local hTitle = Instance.new("TextLabel")
hTitle.Size = UDim2.new(1, -110, 1, 0)
hTitle.Position = UDim2.new(0, 58, 0, 0)
hTitle.BackgroundTransparency = 1
hTitle.Text = "MILLIE HUB  ~lazy~"
hTitle.TextColor3 = T.yel
hTitle.Font = Enum.Font.GothamBlack
hTitle.TextSize = 17
hTitle.TextXAlignment = Enum.TextXAlignment.Left
hTitle.Parent = Header

local hMin = Instance.new("TextButton")
hMin.Size = UDim2.new(0, 36, 0, 36)
hMin.Position = UDim2.new(1, -46, 0, 9)
hMin.BackgroundColor3 = T.bg3
hMin.BorderSizePixel = 0
hMin.Text = "–"
hMin.TextColor3 = T.yel
hMin.Font = Enum.Font.GothamBlack
hMin.TextSize = 20
hMin.Parent = Header
corner(hMin, 9)
stroke(hMin, T.yel, 1)

makeDraggable(Header, Hub)

-- watermark theme (M grande)
local WM = Instance.new("TextLabel")
WM.Size = UDim2.new(0, 300, 0, 300)
WM.Position = UDim2.new(1, -290, 1, -300)
WM.BackgroundTransparency = 1
WM.Text = "M"
WM.TextColor3 = T.red
WM.TextTransparency = 0.88
WM.Font = Enum.Font.GothamBlack
WM.TextSize = 260
WM.Rotation = 12
WM.ZIndex = 1
WM.Parent = Hub

-- tab bar
local TabBar = Instance.new("Frame")
TabBar.Size = UDim2.new(1, -16, 0, 34)
TabBar.Position = UDim2.new(0, 8, 0, 60)
TabBar.BackgroundTransparency = 1
TabBar.ZIndex = 2
TabBar.Parent = Hub

local TabList = Instance.new("UIListLayout")
TabList.FillDirection = Enum.FillDirection.Horizontal
TabList.Padding = UDim.new(0, 6)
TabList.Parent = TabBar

local Tabs, Pages = {}, {}
local TAB_DEFS = {
    {n="Farm",   icon="⚔"},
    {n="Combat", icon="🎯"},
    {n="Move",   icon="✈"},
    {n="Misc",   icon="⚙"},
}

local function switchTab(name)
    S.CurrentTab = name
    for _, def in ipairs(TAB_DEFS) do
        local btn = Tabs[def.n]
        if def.n == name then
            tw(btn, 0.25, { BackgroundColor3 = T.red })
            btn.TextColor3 = Color3.new(1,1,1)
            btn.Text = def.icon .. " " .. def.n
        else
            tw(btn, 0.25, { BackgroundColor3 = T.bg3 })
            btn.TextColor3 = T.dim
            btn.Text = def.n
        end
        Pages[def.n].Visible = (def.n == name)
    end
    local pg = Pages[name]
    pg.Position = UDim2.new(0, 10, 0, 104)
    tw(pg, 0.32, { Position = UDim2.new(0, 10, 0, 98) })
end

for _, def in ipairs(TAB_DEFS) do
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0.25, -5, 1, 0)
    b.BackgroundColor3 = T.bg3
    b.BorderSizePixel = 0
    b.Text = def.n
    b.TextColor3 = T.dim
    b.Font = Enum.Font.GothamBold
    b.TextSize = 12
    b.ZIndex = 2
    b.Parent = TabBar
    corner(b, 9)
    stroke(b, T.yel, 0.75)
    b.MouseButton1Click:Connect(function() switchTab(def.n) end)
    Tabs[def.n] = b

    local pg = Instance.new("ScrollingFrame")
    pg.Name = def.n
    pg.Size = UDim2.new(1, -20, 1, -106)
    pg.Position = UDim2.new(0, 10, 0, 98)
    pg.BackgroundTransparency = 1
    pg.BorderSizePixel = 0
    pg.ScrollBarThickness = 3
    pg.ScrollBarImageColor3 = T.yel
    pg.CanvasSize = UDim2.new(0, 0, 0, 0)
    pg.AutomaticCanvasSize = Enum.AutomaticSize.Y
    pg.Visible = false
    pg.ZIndex = 2
    pg.Parent = Hub
    local pl = Instance.new("UIListLayout")
    pl.Padding = UDim.new(0, 7)
    pl.SortOrder = Enum.SortOrder.LayoutOrder
    pl.Parent = pg
    pad(pg, 2, 2, 2, 12)
    Pages[def.n] = pg
end

-- ═══════════ COMPONENTES ═══════════
local order = 0
local function nextOrder() order = order + 1 return order end

local function makeToggle(page, label, key, cb)
    local b = Instance.new("TextButton")
    b.LayoutOrder = nextOrder()
    b.Size = UDim2.new(1, 0, 0, 40)
    b.BackgroundColor3 = T.bg2
    b.BorderSizePixel = 0
    b.Text = ""
    b.ZIndex = 3
    b.Parent = page
    corner(b, 9)
    stroke(b, T.yel, 0.75)
    grad(b, T.bg2, T.bg1, 90)

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -62, 1, 0)
    lbl.Position = UDim2.new(0, 12, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = label
    lbl.TextColor3 = T.txt
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 12
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.ZIndex = 4
    lbl.Parent = b

    local pill = Instance.new("Frame")
    pill.Size = UDim2.new(0, 42, 0, 22)
    pill.Position = UDim2.new(1, -52, 0.5, -11)
    pill.BackgroundColor3 = T.bg3
    pill.BorderSizePixel = 0
    pill.ZIndex = 4
    pill.Parent = b
    corner(pill, 11)
    stroke(pill, T.yel, 0.75)

    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0, 16, 0, 16)
    knob.Position = UDim2.new(0, 3, 0.5, -8)
    knob.BackgroundColor3 = T.dim
    knob.BorderSizePixel = 0
    knob.ZIndex = 5
    knob.Parent = pill
    corner(knob, 8)

    local function refresh()
        local on = CFG[key] and true or false
        if on then
            tw(knob, 0.22, { Position = UDim2.new(1, -19, 0.5, -8), BackgroundColor3 = T.yel })
            tw(pill, 0.22, { BackgroundColor3 = T.red })
        else
            tw(knob, 0.22, { Position = UDim2.new(0, 3, 0.5, -8), BackgroundColor3 = T.dim })
            tw(pill, 0.22, { BackgroundColor3 = T.bg3 })
        end
    end
    refresh()

    b.MouseButton1Click:Connect(function()
        CFG[key] = not CFG[key]
        refresh()
        if cb then pcall(cb, CFG[key]) end
    end)
    return b
end

local function makeSlider(page, label, key, mn, mx, isInt)
    local f = Instance.new("Frame")
    f.LayoutOrder = nextOrder()
    f.Size = UDim2.new(1, 0, 0, 54)
    f.BackgroundColor3 = T.bg2
    f.BorderSizePixel = 0
    f.ZIndex = 3
    f.Parent = page
    corner(f, 9)
    stroke(f, T.yel, 0.75)

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -20, 0, 20)
    lbl.Position = UDim2.new(0, 12, 0, 6)
    lbl.BackgroundTransparency = 1
    lbl.Text = label .. ": " .. tostring(CFG[key])
    lbl.TextColor3 = T.txt
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 12
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.ZIndex = 4
    lbl.Parent = f

    local bar = Instance.new("Frame")
    bar.Size = UDim2.new(1, -24, 0, 9)
    bar.Position = UDim2.new(0, 12, 1, -19)
    bar.BackgroundColor3 = T.bg0
    bar.BorderSizePixel = 0
    bar.ZIndex = 4
    bar.Parent = f
    corner(bar, 5)

    local fill = Instance.new("Frame")
    fill.Size = UDim2.new(math.clamp((CFG[key]-mn)/(mx-mn),0,1), 0, 1, 0)
    fill.BackgroundColor3 = T.red2
    fill.BorderSizePixel = 0
    fill.ZIndex = 5
    fill.Parent = bar
    corner(fill, 5)
    grad(fill, T.yel, T.red2, 0)

    local dragging = false
    local function upd(input)
        local rel = math.clamp((input.Position.X - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
        local v = mn + (mx - mn) * rel
        if isInt then v = math.floor(v + 0.5) end
        CFG[key] = v
        lbl.Text = label .. ": " .. tostring(v)
        fill.Size = UDim2.new(rel, 0, 1, 0)
    end
    bar.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            dragging = true; upd(i)
        end
    end)
    bar.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
    UserInputService.InputChanged:Connect(function(i)
        if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
            upd(i)
        end
    end)
    return f
end

local function makeButton(page, text, cb, col)
    local b = Instance.new("TextButton")
    b.LayoutOrder = nextOrder()
    b.Size = UDim2.new(1, 0, 0, 40)
    b.BackgroundColor3 = col or T.bg3
    b.BorderSizePixel = 0
    b.Text = text
    b.TextColor3 = T.txt
    b.Font = Enum.Font.GothamBold
    b.TextSize = 12
    b.ZIndex = 3
    b.Parent = page
    corner(b, 9)
    stroke(b, T.yel, 0.75)
    b.MouseButton1Click:Connect(function()
        tw(b, 0.08, { BackgroundColor3 = T.red })
        task.delay(0.12, function() tw(b, 0.25, { BackgroundColor3 = col or T.bg3 }) end)
        pcall(cb, b)
    end)
    return b
end

local function makeLabel(page, text)
    local l = Instance.new("TextLabel")
    l.LayoutOrder = nextOrder()
    l.Size = UDim2.new(1, 0, 0, 20)
    l.BackgroundTransparency = 1
    l.Text = text
    l.TextColor3 = T.yel
    l.Font = Enum.Font.GothamBlack
    l.TextSize = 11
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.ZIndex = 3
    l.Parent = page
    return l
end

-- dropdown genérico
local function makeDropdown(page, label, options, get, set)
    local f = Instance.new("TextButton")
    f.Text = ""
    f.LayoutOrder = nextOrder()
    f.Size = UDim2.new(1, 0, 0, 40)
    f.BackgroundColor3 = T.bg2
    f.BorderSizePixel = 0
    f.ZIndex = 3
    f.ClipsDescendants = true
    f.Parent = page
    corner(f, 9)
    stroke(f, T.yel, 0.75)

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -20, 0, 40)
    lbl.Position = UDim2.new(0, 12, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = label .. ": " .. tostring(get())
    lbl.TextColor3 = T.txt
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 12
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.ZIndex = 4
    lbl.Parent = f

    local arrow = Instance.new("TextLabel")
    arrow.Size = UDim2.new(0, 24, 0, 40)
    arrow.Position = UDim2.new(1, -30, 0, 0)
    arrow.BackgroundTransparency = 1
    arrow.Text = "▾"
    arrow.TextColor3 = T.yel
    arrow.Font = Enum.Font.GothamBlack
    arrow.TextSize = 16
    arrow.ZIndex = 4
    arrow.Parent = f

    local optsF = Instance.new("Frame")
    optsF.Size = UDim2.new(1, 0, 0, #options * 30)
    optsF.Position = UDim2.new(0, 0, 0, 40)
    optsF.BackgroundTransparency = 1
    optsF.ZIndex = 4
    optsF.Parent = f

    local open = false
    for i, opt in ipairs(options) do
        local ob = Instance.new("TextButton")
        ob.Size = UDim2.new(1, -12, 0, 28)
        ob.Position = UDim2.new(0, 6, 0, (i-1)*30)
        ob.BackgroundColor3 = T.bg1
        ob.BorderSizePixel = 0
        ob.Text = tostring(opt)
        ob.TextColor3 = T.dim
        ob.Font = Enum.Font.GothamBold
        ob.TextSize = 11
        ob.ZIndex = 5
        ob.Parent = optsF
        corner(ob, 7)
        ob.MouseButton1Click:Connect(function()
            set(opt)
            lbl.Text = label .. ": " .. tostring(opt)
            open = false
            tw(f, 0.25, { Size = UDim2.new(1, 0, 0, 40) })
            arrow.Text = "▾"
        end)
    end

    f.MouseButton1Click:Connect(function()
        open = not open
        if open then
            tw(f, 0.28, { Size = UDim2.new(1, 0, 0, 40 + #options * 30) })
            arrow.Text = "▴"
        else
            tw(f, 0.28, { Size = UDim2.new(1, 0, 0, 40) })
            arrow.Text = "▾"
        end
    end)
    -- evita conflito: cliques nos botões internos também fecham (já tratado)
    return f
end

-- ═══════════ FARM TAB ═══════════
makeLabel(Pages.Farm, "  AUTO FARM")
makeToggle(Pages.Farm, "Auto Farm", "AutoFarm", function(on)
    if on then notify("auto farm on — go lazy~") else notify("auto farm off") end
end)
makeToggle(Pages.Farm, "Auto Quest (accept + turn in)", "AutoQuest")
makeToggle(Pages.Farm, "Auto Boss hunt", "AutoBoss")
makeToggle(Pages.Farm, "Auto Attack (M1 + skills)", "AutoAttack")
makeToggle(Pages.Farm, "Kill Aura (AoE)", "KillAura")
makeToggle(Pages.Farm, "TP to mob", "TPFarm")
makeToggle(Pages.Farm, "Auto Skill (Z X C V)", "AutoSkill")
makeToggle(Pages.Farm, "Auto Stats", "AutoStats")
makeToggle(Pages.Farm, "Auto Haki", "AutoHaki")
makeToggle(Pages.Farm, "Auto Collect drops", "AutoCollect")

makeLabel(Pages.Farm, "  TARGET")
local islandOpts = {"Auto"}
for _, isl in ipairs(ISLANDS) do table.insert(islandOpts, isl.n) end
makeDropdown(Pages.Farm, "Island", islandOpts,
    function() return CFG.TargetIsland end,
    function(v) CFG.TargetIsland = v; S.CacheTime = 0; notify("target: " .. v) end
)

-- ═══════════ COMBAT TAB ═══════════
makeLabel(Pages.Combat, "  HITBOX")
makeToggle(Pages.Combat, "Hitbox Expander", "HitboxEnabled", function(on)
    if not on then restoreAll() end
    notify(on and "hitbox on (" .. CFG.HitboxRange .. " studs)" or "hitbox off")
end)
makeSlider(Pages.Combat, "Hitbox range", "HitboxRange", 10, 200, true)
makeSlider(Pages.Combat, "Attack speed", "AttackSpeed", 0.1, 1.0, false)

makeLabel(Pages.Combat, "  STATS")
makeDropdown(Pages.Combat, "Stat mode", STAT_MODES,
    function() return CFG.StatMode end,
    function(v) CFG.StatMode = v; notify("stats -> " .. v) end
)

makeLabel(Pages.Combat, "  VISUAL")
makeToggle(Pages.Combat, "Mob ESP", "ESP", function(on)
    if on then notify("esp on") else clearESP() notify("esp off") end
end)

-- ═══════════ MOVE TAB ═══════════
makeLabel(Pages.Move, "  MOVEMENT")
makeToggle(Pages.Move, "Fly (WASD + Space/Ctrl)", "FlyEnabled", function(on)
    setFly(on)
    notify(on and "fly on" or "fly off")
end)
makeSlider(Pages.Move, "Fly speed", "FlySpeed", 20, 250, true)
makeSlider(Pages.Move, "WalkSpeed", "WalkSpeed", 16, 300, true)
makeSlider(Pages.Move, "JumpPower", "JumpPower", 50, 250, true)
makeToggle(Pages.Move, "NoClip", "NoClip", setNoClip)
makeSlider(Pages.Move, "TP height offset", "FarmOffset", 2, 18, true)
makeButton(Pages.Move, "Reset Walk/Jump", function()
    CFG.WalkSpeed = 16; CFG.JumpPower = 50; applyMove()
    notify("movement reset")
end)

-- ═══════════ MISC TAB ═══════════
makeLabel(Pages.Misc, "  SAFETY")
makeToggle(Pages.Misc, "Humanize (anti-detection)", "Humanize")
makeToggle(Pages.Misc, "Auto Rejoin on kick", "AutoRejoin")
makeSlider(Pages.Misc, "Min human delay", "FarmDelayMin2", 0, 5, false)

makeLabel(Pages.Misc, "  SESSION")
local InfoLbl = Instance.new("TextLabel")
InfoLbl.LayoutOrder = nextOrder()
InfoLbl.Size = UDim2.new(1, 0, 0, 64)
InfoLbl.BackgroundColor3 = T.bg2
InfoLbl.BorderSizePixel = 0
InfoLbl.TextColor3 = T.dim
InfoLbl.Font = Enum.Font.Gotham
InfoLbl.TextSize = 12
InfoLbl.TextWrapped = true
InfoLbl.TextXAlignment = Enum.TextXAlignment.Left
InfoLbl.ZIndex = 3
InfoLbl.Text = "  loading..."
InfoLbl.Parent = Pages.Misc
corner(InfoLbl, 9)
stroke(InfoLbl, T.yel, 0.75)
pad(InfoLbl, 8, 8, 8, 8)

makeButton(Pages.Misc, "Rejoin Server", function()
    pcall(function()
        local ts = game:GetService("TeleportService")
        ts:Teleport(game.PlaceId, LP)
    end)
end)

makeButton(Pages.Misc, "Destroy Hub", function()
    restoreAll(); setFly(false); setNoClip(false)
    pcall(function() GUI:Destroy() end)
end, T.red)

task.spawn(function()
    while GUI.Parent do
        local el = math.floor(tick() - S.StartTime)
        local t = S.Target and S.Target.name or "none"
        InfoLbl.Text = string.format(
            "  time: %dm %ds\n  kills: %d\n  target: %s\n  ping: %dms",
            math.floor(el/60), el%60, S.KillCount, t,
            math.floor(Stats.Network.ServerStatsItem["Data Ping"]:GetValue())
        )
        task.wait(1)
    end
end)

-- ═══════════ JV BUBBLE ═══════════
local Bubble = Instance.new("TextButton")
Bubble.Name = "JV"
Bubble.Size = UDim2.new(0, 58, 0, 58)
Bubble.Position = UDim2.new(0, 18, 0.55, -29)
Bubble.BackgroundColor3 = T.red
Bubble.BorderSizePixel = 0
Bubble.Text = "jv"
Bubble.TextColor3 = Color3.new(1,1,1)
Bubble.Font = Enum.Font.GothamBlack
Bubble.TextSize = 21
Bubble.Visible = false
Bubble.Active = true
Bubble.ZIndex = 10
Bubble.Parent = GUI
corner(Bubble, 29)
stroke(Bubble, T.yel, 2.5)
grad(Bubble, T.red2, T.red, 90)

makeDraggable(Bubble, Bubble)

task.spawn(function()
    while GUI.Parent do
        if Bubble.Visible then
            tw(Bubble, 0.85, { Size = UDim2.new(0, 64, 0, 64) }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
            task.wait(0.85)
            tw(Bubble, 0.85, { Size = UDim2.new(0, 58, 0, 58) }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
            task.wait(0.85)
        else
            task.wait(1)
        end
    end
end)

local function minimize()
    S.Minimized = true
    tw(Hub, 0.3, { Size = UDim2.new(0, 0, 0, 0), Position = UDim2.new(0.5, 0, 0.5, 0) }, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
    task.delay(0.3, function()
        Hub.Visible = false
        Bubble.Visible = true
        Bubble.Size = UDim2.new(0, 0, 0, 0)
        tw(Bubble, 0.4, { Size = UDim2.new(0, 58, 0, 58) }, Enum.EasingStyle.Back)
    end)
end

local function restore()
    S.Minimized = false
    Bubble.Visible = false
    Hub.Visible = true
    Hub.Size = UDim2.new(0, 0, 0, 0)
    Hub.Position = UDim2.new(0.5, 0, 0.5, 0)
    tw(Hub, 0.5, {
        Size = UDim2.new(0, 350, 0, 470),
        Position = UDim2.new(0.5, -175, 0.5, -235),
    }, Enum.EasingStyle.Back)
end

hMin.MouseButton1Click:Connect(minimize)
Bubble.MouseButton1Click:Connect(restore)

-- ═══════════ WELCOME FLOW ═══════════
local function playWelcome()
    local W = Instance.new("TextLabel")
    W.Size = UDim2.new(0, 600, 0, 70)
    W.Position = UDim2.new(0.5, -300, 0.42, -35)
    W.BackgroundTransparency = 1
    W.Text = ""
    W.TextColor3 = T.yel
    W.Font = Enum.Font.GothamBlack
    W.TextSize = 36
    W.TextStrokeTransparency = 0.55
    W.TextStrokeColor3 = T.red
    W.ZIndex = 50
    W.Parent = GUI

    local full = "Bem-vindo a MILLIE HUB HEH!...~"
    task.spawn(function()
        for i = 0, #full do
            W.Text = string.sub(full, 1, i)
            task.wait(0.04)
        end
        task.wait(0.9)
        -- slide up and fade
        tw(W, 0.5, { Position = UDim2.new(0.5, -300, 0.3, -35), TextTransparency = 1, TextStrokeTransparency = 1 })
        task.wait(0.5)
        W:Destroy()
        Hub.Visible = true
        Hub.Size = UDim2.new(0, 0, 0, 0)
        Hub.Position = UDim2.new(0.5, 0, 0.5, 0)
        tw(Hub, 0.55, {
            Size = UDim2.new(0, 350, 0, 470),
            Position = UDim2.new(0.5, -175, 0.5, -235),
        }, Enum.EasingStyle.Back)
        switchTab("Farm")
        notify("unlocked. go lazy~")
    end)
end

pBtn.MouseButton1Click:Connect(function()
    if string.lower(pBox.Text) == string.lower("Millielover") then
        S.Unlocked = true
        tw(Pass, 0.28, { Size = UDim2.new(0, 0, 0, 0), Position = UDim2.new(0.5, 0, 0.5, 0) }, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
        task.delay(0.28, function()
            Pass.Visible = false
            playWelcome()
        end)
    else
        pErr.Text = "wrong key, lazy~"
        local orig = Pass.Position
        for i = 1, 7 do
            Pass.Position = orig + UDim2.new(0, math.random(-7, 7), 0, math.random(-3, 3))
            task.wait(0.035)
        end
        Pass.Position = orig
        pBox.Text = ""
    end
end)

-- ═══════════ MAIN LOOPS ═══════════
-- farm loop
task.spawn(function()
    while GUI.Parent do
        local ok, err = pcall(function()
            if CFG.AutoFarm or CFG.AutoBoss then
                local root = S.Root()
                if root then
                    local t = nearestMob(CFG.AutoBoss and 400 or 250)
                    S.Target = t
                    if t and t.hrp then
                        if CFG.TPFarm then
                            safeTP(t.hrp.Position)
                        else
                            local h = S.Hum()
                            if h then h:MoveTo(t.hrp.Position) end
                        end
                        task.wait(0.08)
                        if CFG.KillAura then
                            killAura()
                        elseif CFG.AutoAttack then
                            attack(t)
                        end
                    elseif CFG.AutoQuest then
                        if tick() - S.LastQuest > 4 then
                            S.LastQuest = tick()
                            tryQuestAccept()
                        end
                    end
                end
            end
        end)
        if not ok then task.wait(0.8) end
        task.wait(0.05)
    end
end)

-- quest loop separada (turn-in)
task.spawn(function()
    while GUI.Parent do
        pcall(function()
            if CFG.AutoQuest then
                local t = nearestMob(35)
                if not t and (CFG.AutoFarm or tick() - S.LastQuest > 6) then
                    tryQuestDone()
                    task.wait(hdel())
                    tryQuestAccept()
                    S.LastQuest = tick()
                end
            end
        end)
        task.wait(2.5)
    end
end)

-- stats loop
task.spawn(function()
    while GUI.Parent do
        pcall(function()
            if CFG.AutoStats then
                if tick() - S.LastStat > 2.5 then
                    S.LastStat = tick()
                    for _, n in ipairs(STAT_ADD) do
                        fire(n, CFG.StatMode, 1)
                    end
                    fire("StatEvent", CFG.StatMode)
                    fire("PointsEvent", CFG.StatMode)
                end
            end
        end)
        task.wait(1)
    end
end)

-- haki loop
task.spawn(function()
    while GUI.Parent do
        pcall(function()
            if CFG.AutoHaki then
                for _, n in ipairs(HAKI_NAMES) do fire(n) end
            end
        end)
        task.wait(CFG.Humanize and rand(5, 9) or 5)
    end
end)

-- collect loop
task.spawn(function()
    while GUI.Parent do
        pcall(function()
            if CFG.AutoCollect then
                local root = S.Root()
                if root then
                    local names = {"drop","coin","beli","gem","chest","fragment"}
                    for _, obj in ipairs(Workspace:GetDescendants()) do
                        if obj:IsA("BasePart") then
                            local ln = string.lower(obj.Name)
                            for _, n in ipairs(names) do
                                if string.find(ln, n, 1, true) then
                                    if (obj.Position - root.Position).Magnitude < 14 then
                                        pcall(function() obj.CFrame = root.CFrame end)
                                    end
                                    break
                                end
                            end
                        end
                    end
                end
            end
        end)
        task.wait(0.6)
    end
end)

-- esp loop
task.spawn(function()
    while GUI.Parent do
        if CFG.ESP then pcall(buildESP) end
        task.wait(2)
    end
end)

-- movement loop
task.spawn(function()
    while GUI.Parent do
        pcall(applyMove)
        task.wait(0.6)
    end
end)

-- hitbox upkeep nos alvos atuais
task.spawn(function()
    while GUI.Parent do
        pcall(function()
            if CFG.HitboxEnabled and S.Target and alive(S.Target.model) then
                hitbox(S.Target, CFG.HitboxRange)
            end
            -- limpa hitboxes de mobs mortos
            for hrp, _ in pairs(OrigSizes) do
                if not (hrp.Parent and hrp.Parent:FindFirstChildOfClass("Humanoid")
                        and hrp.Parent:FindFirstChildOfClass("Humanoid").Health > 0) then
                    restoreOne(hrp)
                end
            end
        end)
        task.wait(0.5)
    end
end)

-- anti-detection: varia timing
task.spawn(function()
    while GUI.Parent do
        pcall(function()
            if CFG.Humanize then
                CFG.AttackSpeed = rand(0.28, 0.48)
            end
        end)
        task.wait(rand(2, 5))
    end
end)

-- respawn handling
LP.CharacterAdded:Connect(function()
    task.wait(2)
    pcall(function()
        restoreAll()
        if CFG.NoClip then setNoClip(true) end
        if CFG.FlyEnabled then setFly(true) end
        applyMove()
    end)
end)

-- auto rejoin
if CFG.AutoRejoin then
    pcall(function()
        if queue_on_teleport then
            queue_on_teleport('loadstring(game:HttpGet("https://example.invalid/millie.lua"))()')
        end
    end)
end

print("[MILLIE HUB] v4 loaded ok")

end) -- fim do pcall de load

if not LOAD_OK then
    local f = Instance.new("Frame")
    f.Size = UDim2.new(0, 320, 0, 120)
    f.Position = UDim2.new(0.5, -160, 0.2, 0)
    f.BackgroundColor3 = Color3.fromRGB(40, 10, 12)
    f.BorderSizePixel = 0
    f.Parent = ErrorGui
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 10); c.Parent = f
    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(1, -16, 1, -16)
    l.Position = UDim2.new(0, 8, 0, 8)
    l.BackgroundTransparency = 1
    l.TextColor3 = Color3.fromRGB(255, 200, 60)
    l.Font = Enum.Font.Code
    l.TextSize = 12
    l.TextWrapped = true
    l.Text = "MILLIE HUB error:\n" .. tostring(LOAD_ERR) .. "\n\nmanda esse erro pro cortex"
    l.Parent = f
end
