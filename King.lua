--[[
    ██╗     ███████╗ ██████╗  █████╗  ██████╗██╗   ██╗    ███████╗ ██████╗ ██████╗ ████████╗███████╗███╗   ██╗███████╗███████╗███████╗
    ██║     ██╔════╝██╔════╝ ██╔══██╗██╔════╝╚██╗ ██╔╝    ██╔════╝██╔═══██╗██╔══██╗╚══██╔══╝██╔════╝████╗  ██║██╔════╝██╔════╝██╔════╝
    ██║     █████╗  ██║  ███╗███████║██║      ╚████╔╝     █████╗  ██║   ██║██████╔╝   ██║   █████╗  ██╔██╗ ██║█████╗  ███████╗███████╗
    ██║     ██╔══╝  ██║   ██║██╔══██║██║       ╚██╔╝      ██╔══╝  ██║   ██║██╔══██╗   ██║   ██╔══╝  ██║╚██╗██║██╔══╝  ╚════██║╚════██║
    ███████╗███████╗╚██████╔╝██║  ██║╚██████╗   ██║       ██║     ╚██████╔╝██║  ██║   ██║   ███████╗██║ ╚████║███████╗███████║███████║
    ╚══════╝╚══════╝ ╚═════╝ ╚═╝  ╚═╝ ╚═════╝   ╚═╝       ╚═╝      ╚═════╝ ╚═╝  ╚═╝   ╚═╝   ╚══════╝╚═╝  ╚═══╝╚══════╝╚══════╝╚══════╝

    King Legacy | UPD 10 | Mobile + PC | Delta Compatible
    Senha: 180125
    v1.0 — Build Completa
--]]
task.wait(2)
-- ═══════════════════════════════════════════════════════════
--  SERVICES
-- ═══════════════════════════════════════════════════════════
local Players         = game:GetService("Players")
local RunService      = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService    = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")

local lp   = Players.LocalPlayer
local pg   = lp:WaitForChild("PlayerGui")
local char, hum, root

local function refreshChar(c)
    char = c or lp.Character
    if not char then return end
    hum  = char:WaitForChild("Humanoid", 5)
    root = char:WaitForChild("HumanoidRootPart", 5)
end
refreshChar()
lp.CharacterAdded:Connect(refreshChar)

-- ═══════════════════════════════════════════════════════════
--  CONFIG
-- ═══════════════════════════════════════════════════════════
local CFG = {
    farm = {
        enabled     = false,
        autoQuest   = true,
        autoStats   = false,
        statTarget  = "STR",
        hitboxSize  = 18,
        farmRange   = 80,
        attackDelay = 0.12,
        seaBeast    = false,
        fruitSniper = false,
    },
    esp = {
        players = false,
        mobs    = false,
        fruits  = false,
    },
    misc = {
        speedOn    = false,
        speedVal   = 36,
        flyOn      = false,
        flySpeed   = 60,
        noClip     = false,
        godMode    = false,
    },
    anti = {
        minDelay = 0.06,
        maxDelay = 0.22,
        jitter   = 2.5,
        humanize = true,
    },
}

local STATE = {
    auth        = false,
    farmActive  = false,
    farmThread  = nil,
    esps        = {},
    hitboxed    = {},
    flyBodies   = {},
    godConn     = nil,
    noclipConn  = nil,
}

-- ═══════════════════════════════════════════════════════════
--  ANTI-DETECTION UTILITIES
-- ═══════════════════════════════════════════════════════════
local function rnd(a, b) return a + math.random() * (b - a) end

local function wait_hum()
    task.wait(rnd(CFG.anti.minDelay, CFG.anti.maxDelay))
end

local function jitter(pos)
    local j = CFG.anti.jitter
    return pos + Vector3.new(rnd(-j, j), 0, rnd(-j, j))
end

local function safeTP(pos)
    if not root then return end
    pcall(function()
        root.CFrame = CFrame.new(jitter(pos) + Vector3.new(0, 3.5, 0))
    end)
    task.wait(rnd(0.08, 0.2))
end

-- ═══════════════════════════════════════════════════════════
--  ISLAND DATA  (First Sea + Second Sea + TP positions)
-- ═══════════════════════════════════════════════════════════
local ISLANDS = {
    -- name, approx coords (fallback if not found in workspace), level range, mob pattern
    { n="Starter Island",  pos=Vector3.new(-500,20,100),  lv={0,50},   mob="Soldier|Clown Pirate|Smoky|Tashi" },
    { n="Pirate Island",   pos=Vector3.new(-200,20,500),  lv={50,100},  mob="Pirate Swordsman|Clown" },
    { n="Soldier Island",  pos=Vector3.new(300,20,400),   lv={100,180}, mob="Commander|Captain|Barbaric" },
    { n="Shark Island",    pos=Vector3.new(700,20,200),   lv={180,250}, mob="Fishman|Karate Fishman|Shark Man" },
    { n="Chef Ship",       pos=Vector3.new(1200,20,0),    lv={250,400}, mob="Trainer Chef|Dark Leg|Weapon Man" },
    { n="Snow Island",     pos=Vector3.new(1600,20,-300), lv={400,525}, mob="Snow Soldier|King Snow|Little Dear" },
    { n="Sand Kingdom",    pos=Vector3.new(2200,20,100),  lv={525,800}, mob="Candle Man|Desert Bandit|Bomb Man|King of Sand" },
    { n="Sky Island",      pos=Vector3.new(2800,20,500),  lv={800,1000},mob="Sky Soldier|Ball Man|Cloud Warrior|Rumble Man" },
    { n="Bubble Island",   pos=Vector3.new(3200,20,200),  lv={1000,1250},mob="Bubble Pirate|Bubble Soldier" },
    { n="Lobby Island",    pos=Vector3.new(3700,20,0),    lv={1250,1500},mob="Lobby Guard|Lobby Warrior" },
    { n="Zombie Island",   pos=Vector3.new(4200,20,-300), lv={1500,1700},mob="Zombie Pirate|Shadow Master" },
    { n="War Island",      pos=Vector3.new(4800,20,200),  lv={1700,2000},mob="War Soldier|War Commander" },
    { n="Fishland",        pos=Vector3.new(5400,20,500),  lv={2000,2250},mob="Fishman King|Deep Fishman" },
    -- Second Sea
    { n="S2 - Beast Island",  pos=Vector3.new(-2000,20,3000), lv={2250,2700},mob="Elite Beast Pirate|Bear Man" },
    { n="S2 - Skull Island",  pos=Vector3.new(-1500,20,3500), lv={2700,3000},mob="Skull Pirate|Elite Skeleton" },
    { n="S2 - Navy HQ",       pos=Vector3.new(-1000,20,4000), lv={3000,3400},mob="Vice Admiral|Pondre" },
    { n="S2 - Dark Base",     pos=Vector3.new(-500,20,4500),  lv={3400,3800},mob="Dark Beard Servant|Sally" },
    -- Third Sea
    { n="S3 - Unearthly",     pos=Vector3.new(500,20,8000),   lv={3800,4200},mob="Fugitive|Deep One" },
    { n="S3 - Chaos Island",  pos=Vector3.new(1000,20,8500),  lv={4200,4400},mob="Veyzor|Chaos Crab|Craberno" },
}

local function getIslandByLevel(lvl)
    for i = #ISLANDS, 1, -1 do
        local is = ISLANDS[i]
        if lvl >= is.lv[1] then return is end
    end
    return ISLANDS[1]
end

local function findIslandPosInWorkspace(name)
    local kw = name:match("^(%a+)"):lower()
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj.Name:lower():find(kw) then
            if obj:IsA("SpawnLocation") or obj:IsA("BasePart") then
                return obj.Position
            elseif obj:IsA("Model") then
                local pp = obj.PrimaryPart or obj:FindFirstChildOfClass("BasePart")
                if pp then return pp.Position end
            end
        end
    end
    return nil
end

local function tpToIsland(island)
    local pos = findIslandPosInWorkspace(island.n) or island.pos
    safeTP(pos)
end

-- ═══════════════════════════════════════════════════════════
--  PLAYER LEVEL
-- ═══════════════════════════════════════════════════════════
local function getLevel()
    local ls = lp:FindFirstChild("leaderstats")
    if ls then
        for _, k in ipairs({"Level","Lv","LV","level"}) do
            local v = ls:FindFirstChild(k)
            if v then return tonumber(v.Value) or 1 end
        end
    end
    local gui_check = pg:FindFirstChild("LevelFrame", true)
        or pg:FindFirstChild("PlayerInfo", true)
    if gui_check then
        for _, lbl in ipairs(gui_check:GetDescendants()) do
            if lbl:IsA("TextLabel") then
                local n = tonumber(lbl.Text:match("(%d+)"))
                if n and n > 0 then return n end
            end
        end
    end
    return 1
end

-- ═══════════════════════════════════════════════════════════
--  MOB DETECTION
-- ═══════════════════════════════════════════════════════════
local function isMob(m)
    if not m or not m:IsA("Model") then return false end
    local h = m:FindFirstChildOfClass("Humanoid")
    if not h or h.Health <= 0 then return false end
    if m == char then return false end
    if Players:GetPlayerFromCharacter(m) then return false end
    return true
end

local function mobRoot(m)
    return m:FindFirstChild("HumanoidRootPart")
        or m:FindFirstChild("Root")
        or m.PrimaryPart
        or m:FindFirstChildOfClass("BasePart")
end

local function nearestMob(range)
    if not root then return nil end
    range = range or CFG.farm.farmRange
    local best, bestD = nil, range
    for _, obj in ipairs(workspace:GetDescendants()) do
        if isMob(obj) then
            local r = mobRoot(obj)
            if r then
                local d = (root.Position - r.Position).Magnitude
                if d < bestD then bestD = d; best = obj end
            end
        end
    end
    return best
end

local function mobsByPattern(pattern, range)
    if not root then return {} end
    range = range or 500
    local list = {}
    local pats = {}
    for p in pattern:gmatch("[^|]+") do
        table.insert(pats, p:lower():gsub("^%s+",""):gsub("%s+$",""))
    end
    for _, obj in ipairs(workspace:GetDescendants()) do
        if isMob(obj) then
            local nm = obj.Name:lower()
            for _, p in ipairs(pats) do
                if nm:find(p, 1, true) then
                    local r = mobRoot(obj)
                    if r then
                        local d = (root.Position - r.Position).Magnitude
                        if d < range then
                            table.insert(list, obj)
                        end
                    end
                    break
                end
            end
        end
    end
    return list
end

-- ═══════════════════════════════════════════════════════════
--  HITBOX EXPANSION (fix dano não registrando de longe)
-- ═══════════════════════════════════════════════════════════
local function expandHitbox(mob)
    if STATE.hitboxed[mob] then return end
    STATE.hitboxed[mob] = true
    local sz = CFG.farm.hitboxSize
    pcall(function()
        for _, p in ipairs(mob:GetDescendants()) do
            if p:IsA("BasePart") then
                p.Size       = Vector3.new(sz, sz, sz)
                p.CanCollide = false
                p.Transparency = 0.9
            end
        end
    end)
end

-- ═══════════════════════════════════════════════════════════
--  ATTACK  (multi-layer: RemoteEvent + tool + touch + click)
-- ═══════════════════════════════════════════════════════════
local function getEvFolder()
    for _, n in ipairs({"Events","RE","Remotes","GameEvents","Network","KLEvents"}) do
        local f = ReplicatedStorage:FindFirstChild(n)
        if f then return f end
    end
    return ReplicatedStorage
end

local function fireRemoteAttack(mob)
    local ev_folder = getEvFolder()
    local r = mobRoot(mob)
    if not r then return end
    for _, name in ipairs({
        "Attack","NormalAttack","BasicAttack","M1","Hit",
        "DamageEnemy","AttackEnemy","MeleeHit","Combat",
        "Damage","DealDamage","HitEnemy","AutoAttack"
    }) do
        local ev = ev_folder:FindFirstChild(name, true)
        if ev and ev:IsA("RemoteEvent") then
            pcall(function() ev:FireServer(mob, r.Position) end)
            return
        end
    end
end

local function fireTouchOnMob(mob)
    local r = mobRoot(mob)
    if not r or not root then return end
    pcall(function()
        firetouchinterest(root, r, 0)
        task.wait(0.04)
        firetouchinterest(root, r, 1)
    end)
    -- also try limbs
    pcall(function()
        for _, p in ipairs(mob:GetDescendants()) do
            if p:IsA("BasePart") then
                firetouchinterest(root, p, 0)
                task.wait(0.02)
                firetouchinterest(root, p, 1)
                return
            end
        end
    end)
end

local function fireClickOnMob(mob)
    pcall(function()
        for _, p in ipairs(mob:GetDescendants()) do
            if p:IsA("ClickDetector") then
                fireclickdetector(p)
                return
            end
        end
    end)
end

local function activateTool()
    pcall(function()
        local tool = char and char:FindFirstChildOfClass("Tool")
        if tool then
            tool:Activate()
        end
    end)
end

local function attackMob(mob)
    if not mob or not root or not isMob(mob) then return end
    local r = mobRoot(mob)
    if not r then return end

    -- Face mob
    pcall(function()
        root.CFrame = CFrame.lookAt(root.Position, r.Position)
    end)

    fireRemoteAttack(mob)
    fireTouchOnMob(mob)
    fireClickOnMob(mob)
    activateTool()
end

-- ═══════════════════════════════════════════════════════════
--  QUEST NPC INTERACTION
-- ═══════════════════════════════════════════════════════════
local function findQuestNPC()
    if not root then return nil end
    local best, bestR, bestD = nil, nil, 120
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("Model") or obj:IsA("Part") then
            local nm = obj.Name:lower()
            if nm:find("quest") or nm:find("npc") or nm:find("giver") then
                local rp = (obj:IsA("Model") and (obj:FindFirstChild("HumanoidRootPart") or obj.PrimaryPart or obj:FindFirstChildOfClass("BasePart")))
                        or (obj:IsA("BasePart") and obj)
                if rp then
                    local d = (root.Position - rp.Position).Magnitude
                    if d < bestD then bestD = d; best = obj; bestR = rp end
                end
            end
        end
    end
    return best, bestR
end

local function talkToNPC(npc, npcRoot)
    if not npc or not npcRoot then return end
    safeTP(npcRoot.Position + Vector3.new(3,0,0))
    task.wait(0.3)
    pcall(function()
        local cd = npc:FindFirstChildOfClass("ClickDetector") or npc:FindFirstChildWhichIsA("ClickDetector", true)
        if cd then fireclickdetector(cd) end
    end)
    pcall(function()
        firetouchinterest(root, npcRoot, 0)
        task.wait(0.1)
        firetouchinterest(root, npcRoot, 1)
    end)
    local evf = getEvFolder()
    for _, en in ipairs({"AcceptQuest","Quest","GetQuest","TalkNPC","Interact","NPCTalk","StartQuest"}) do
        local ev = evf:FindFirstChild(en, true)
        if ev and ev:IsA("RemoteEvent") then
            pcall(function() ev:FireServer(npc) end)
            break
        end
    end
    task.wait(0.4)
end

-- ═══════════════════════════════════════════════════════════
--  AUTO STATS
-- ═══════════════════════════════════════════════════════════
local function distributeStats()
    local evf = getEvFolder()
    local statNames = {"AddStat","StatUp","UpgradeStat","Stats","AddPoints","StatPoint","PointUp"}
    for _, sn in ipairs(statNames) do
        local ev = evf:FindFirstChild(sn, true)
        if ev and ev:IsA("RemoteEvent") then
            pcall(function() ev:FireServer(CFG.farm.statTarget) end)
            return
        end
    end
end

-- ═══════════════════════════════════════════════════════════
--  DEVIL FRUIT SNIPER
-- ═══════════════════════════════════════════════════════════
local FRUIT_PATTERNS = {
    "fruit","devil","logia","paramecia","zoan",
    "gomu","mera","hie","goro","suna","doku",
    "tori","inu","neko","uma","hebi","kame"
}

local function isFruitObj(obj)
    if not (obj:IsA("BasePart") or obj:IsA("MeshPart") or obj:IsA("SpecialMesh") or obj:IsA("Model")) then return false end
    local nm = obj.Name:lower()
    for _, p in ipairs(FRUIT_PATTERNS) do
        if nm:find(p) then return true end
    end
    return false
end

local function findFruits()
    if not root then return {} end
    local list = {}
    for _, obj in ipairs(workspace:GetDescendants()) do
        if isFruitObj(obj) then
            local pos
            if obj:IsA("BasePart") or obj:IsA("MeshPart") then
                pos = obj.Position
            elseif obj:IsA("Model") and obj.PrimaryPart then
                pos = obj.PrimaryPart.Position
            end
            if pos then
                table.insert(list, {
                    obj  = obj,
                    pos  = pos,
                    dist = (root.Position - pos).Magnitude,
                    name = obj.Name,
                })
            end
        end
    end
    table.sort(list, function(a,b) return a.dist < b.dist end)
    return list
end

local function snipeFruit()
    local fruits = findFruits()
    if #fruits == 0 then return false end
    local f = fruits[1]
    safeTP(f.pos)
    task.wait(0.3)
    pcall(function()
        if f.obj:IsA("BasePart") or f.obj:IsA("MeshPart") then
            firetouchinterest(root, f.obj, 0)
            task.wait(0.08)
            firetouchinterest(root, f.obj, 1)
        end
        local cd = f.obj:FindFirstChildOfClass("ClickDetector", true)
            or (f.obj.Parent and f.obj.Parent:FindFirstChildOfClass("ClickDetector", true))
        if cd then fireclickdetector(cd) end
    end)
    return true, f.name
end

-- ═══════════════════════════════════════════════════════════
--  MAIN FARM LOOP
-- ═══════════════════════════════════════════════════════════
local function farmLoop()
    while STATE.farmActive do
        -- Respawn check
        if not char or not root or not hum or hum.Health <= 0 then
            task.wait(1)
            char = lp.Character
            if char then
                hum  = char:FindFirstChildOfClass("Humanoid")
                root = char:FindFirstChild("HumanoidRootPart")
            end
            task.wait(2)
            goto continue
        end

        local lvl    = getLevel()
        local island = getIslandByLevel(lvl)

        -- Try to find target mobs
        local mobs = {}
        if CFG.farm.autoQuest then
            mobs = mobsByPattern(island.mob, 600)
        end
        if #mobs == 0 then
            mobs = {}
            local nm = nearestMob()
            if nm then table.insert(mobs, nm) end
        end

        if #mobs == 0 then
            -- No mobs nearby, go to island
            tpToIsland(island)
            task.wait(2)
            goto continue
        end

        -- Shuffle for anti-pattern detection
        if CFG.anti.humanize and #mobs > 1 then
            for i = #mobs, 2, -1 do
                local j = math.random(i)
                mobs[i], mobs[j] = mobs[j], mobs[i]
            end
        end

        for _, mob in ipairs(mobs) do
            if not STATE.farmActive then break end
            if not isMob(mob) then goto next_mob end

            local mr = mobRoot(mob)
            if not mr then goto next_mob end

            expandHitbox(mob)
            safeTP(mr.Position)

            -- Attack until mob dies or we stop
            local attempts = 0
            while isMob(mob) and STATE.farmActive and attempts < 120 do
                attackMob(mob)
                wait_hum()
                attempts = attempts + 1
            end

            -- Short human-ish pause between mobs
            if CFG.anti.humanize then
                task.wait(rnd(0.1, 0.4))
            end

            ::next_mob::
        end

        -- Auto quest NPC interaction
        if CFG.farm.autoQuest then
            local npc, npcR = findQuestNPC()
            if npc and npcR then
                pcall(function() talkToNPC(npc, npcR) end)
            end
        end

        -- Auto stats
        if CFG.farm.autoStats then
            pcall(distributeStats)
        end

        -- Fruit sniper
        if CFG.farm.fruitSniper then
            pcall(snipeFruit)
        end

        wait_hum()
        ::continue::
    end
end

local function startFarm()
    if STATE.farmActive then return end
    STATE.farmActive = true
    STATE.farmThread = task.spawn(farmLoop)
end

local function stopFarm()
    STATE.farmActive = false
end

-- ═══════════════════════════════════════════════════════════
--  SEA BEAST FARM
-- ═══════════════════════════════════════════════════════════
local seaBeastThread = nil

local function seaBeastLoop()
    while CFG.farm.seaBeast do
        for _, obj in ipairs(workspace:GetDescendants()) do
            local nm = obj.Name:lower()
            if (nm:find("sea beast") or nm:find("sea king") or nm:find("hydra")
                or nm:find("leviathan") or nm:find("seabeast") or nm:find("seamonster"))
                and isMob(obj) then
                local mr = mobRoot(obj)
                if mr then
                    expandHitbox(obj)
                    safeTP(mr.Position)
                    task.wait(0.2)
                    for i = 1, 30 do
                        if not isMob(obj) then break end
                        attackMob(obj)
                        task.wait(0.15)
                    end
                end
            end
        end
        task.wait(1)
    end
end

-- ═══════════════════════════════════════════════════════════
--  SPEED / FLY / GOD / NOCLIP
-- ═══════════════════════════════════════════════════════════
local function setWalkSpeed(v)
    pcall(function()
        if hum then hum.WalkSpeed = v end
    end)
end

local function enableFly()
    if not root then return end
    pcall(function()
        local bg = Instance.new("BodyGyro")
        bg.P          = 9e4
        bg.MaxTorque  = Vector3.new(9e9,9e9,9e9)
        bg.CFrame     = root.CFrame
        bg.Parent     = root
        STATE.flyBodies.gyro = bg

        local bv = Instance.new("BodyVelocity")
        bv.Velocity  = Vector3.zero
        bv.MaxForce  = Vector3.new(9e9,9e9,9e9)
        bv.Parent    = root
        STATE.flyBodies.vel = bv

        STATE.flyBodies.conn = RunService.Heartbeat:Connect(function()
            if not CFG.misc.flyOn then
                if STATE.flyBodies.gyro  and STATE.flyBodies.gyro.Parent  then STATE.flyBodies.gyro:Destroy()  end
                if STATE.flyBodies.vel   and STATE.flyBodies.vel.Parent   then STATE.flyBodies.vel:Destroy()   end
                if STATE.flyBodies.conn  then STATE.flyBodies.conn:Disconnect() end
                STATE.flyBodies = {}
                return
            end
            if not root or not hum then return end
            local cam   = workspace.CurrentCamera
            local spd   = CFG.misc.flySpeed
            local md    = hum.MoveDirection
            if md.Magnitude > 0 then
                local flat = Vector3.new(md.X, 0, md.Z)
                STATE.flyBodies.vel.Velocity = (cam.CFrame.RightVector * flat.X
                    + cam.CFrame.LookVector * -flat.Z) * spd
            else
                STATE.flyBodies.vel.Velocity = Vector3.new(
                    STATE.flyBodies.vel.Velocity.X * 0.6,
                    0,
                    STATE.flyBodies.vel.Velocity.Z * 0.6
                )
            end
            STATE.flyBodies.gyro.CFrame = cam.CFrame
        end)
    end)
end

local function disableFly()
    CFG.misc.flyOn = false
    pcall(function()
        if STATE.flyBodies.gyro  and STATE.flyBodies.gyro.Parent  then STATE.flyBodies.gyro:Destroy()  end
        if STATE.flyBodies.vel   and STATE.flyBodies.vel.Parent   then STATE.flyBodies.vel:Destroy()   end
        if STATE.flyBodies.conn  then STATE.flyBodies.conn:Disconnect() end
    end)
    STATE.flyBodies = {}
end

local function enableGod()
    STATE.godConn = RunService.Heartbeat:Connect(function()
        pcall(function()
            if hum and hum.Health < hum.MaxHealth then
                hum.Health = hum.MaxHealth
            end
        end)
    end)
end

local function disableGod()
    if STATE.godConn then STATE.godConn:Disconnect(); STATE.godConn = nil end
end

local function enableNoClip()
    STATE.noclipConn = RunService.Stepped:Connect(function()
        if not char then return end
        pcall(function()
            for _, p in ipairs(char:GetDescendants()) do
                if p:IsA("BasePart") then p.CanCollide = false end
            end
        end)
    end)
end

local function disableNoClip()
    if STATE.noclipConn then STATE.noclipConn:Disconnect(); STATE.noclipConn = nil end
    if char then
        pcall(function()
            for _, p in ipairs(char:GetDescendants()) do
                if p:IsA("BasePart") then p.CanCollide = true end
            end
        end)
    end
end

-- Anti-AFK
task.spawn(function()
    while true do
        task.wait(55 + math.random()*25)
        pcall(function()
            if hum then
                hum.Jump = true
                task.wait(0.15)
                hum.Jump = false
            end
        end)
    end
end)

-- CharacterAdded: re-apply misc
lp.CharacterAdded:Connect(function(c)
    task.wait(1)
    refreshChar(c)
    STATE.hitboxed = {}
    if CFG.misc.speedOn   then setWalkSpeed(CFG.misc.speedVal) end
    if CFG.misc.noClip    then enableNoClip() end
    if CFG.misc.godMode   then enableGod() end
end)

-- ═══════════════════════════════════════════════════════════
--  ESP
-- ═══════════════════════════════════════════════════════════
local function makeESP(model, color, label)
    if STATE.esps[model] then return end
    local rp = model:IsA("Model") and (model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart or model:FindFirstChildOfClass("BasePart"))
            or (model:IsA("BasePart") and model)
    if not rp then return end

    local bb = Instance.new("BillboardGui")
    bb.AlwaysOnTop  = true
    bb.Size         = UDim2.new(0,100,0,100)
    bb.StudsOffset  = Vector3.new(0,2.5,0)
    bb.Parent       = rp

    local frm = Instance.new("Frame")
    frm.Size = UDim2.fromScale(1,1)
    frm.BackgroundTransparency = 1
    frm.Parent = bb

    local function corner(anchor, pos, size)
        local f = Instance.new("Frame")
        f.AnchorPoint = anchor
        f.Position    = pos
        f.Size        = size
        f.BackgroundColor3 = color
        f.BorderSizePixel  = 0
        f.Parent = frm
    end
    corner(Vector2.new(0,0),UDim2.fromOffset(0,0),   UDim2.fromOffset(14,2))
    corner(Vector2.new(0,0),UDim2.fromOffset(0,0),   UDim2.fromOffset(2,14))
    corner(Vector2.new(1,0),UDim2.new(1,0,0,0),      UDim2.fromOffset(14,2))
    corner(Vector2.new(1,0),UDim2.new(1,0,0,0),      UDim2.fromOffset(2,14))
    corner(Vector2.new(0,1),UDim2.new(0,0,1,0),      UDim2.fromOffset(14,2))
    corner(Vector2.new(0,1),UDim2.new(0,0,1,0),      UDim2.fromOffset(2,14))
    corner(Vector2.new(1,1),UDim2.new(1,0,1,0),      UDim2.fromOffset(14,2))
    corner(Vector2.new(1,1),UDim2.new(1,0,1,0),      UDim2.fromOffset(2,14))

    local lbl = Instance.new("TextLabel")
    lbl.Size       = UDim2.new(1,0,0,16)
    lbl.Position   = UDim2.new(0,0,-0.25,0)
    lbl.BackgroundTransparency = 1
    lbl.Text       = label or model.Name
    lbl.TextColor3 = color
    lbl.TextStrokeTransparency = 0
    lbl.TextScaled = true
    lbl.Font       = Enum.Font.GothamBold
    lbl.Parent     = bb

    STATE.esps[model] = bb
end

local function clearESP()
    for m, bb in pairs(STATE.esps) do
        if bb and bb.Parent then bb:Destroy() end
    end
    STATE.esps = {}
end

-- ESP heartbeat
RunService.Heartbeat:Connect(function()
    if not STATE.auth then return end
    if CFG.esp.players then
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= lp and p.Character and not STATE.esps[p.Character] then
                makeESP(p.Character, Color3.fromRGB(255,80,80), p.Name)
            end
        end
    end
    if CFG.esp.mobs then
        for _, obj in ipairs(workspace:GetDescendants()) do
            if isMob(obj) and not STATE.esps[obj] then
                makeESP(obj, Color3.fromRGB(255,165,0), obj.Name)
            end
        end
    end
    if CFG.misc.speedOn and hum then
        pcall(function() hum.WalkSpeed = CFG.misc.speedVal end)
    end
    if CFG.misc.godMode and hum then
        pcall(function()
            if hum.Health < hum.MaxHealth then hum.Health = hum.MaxHealth end
        end)
    end
end)

-- ═══════════════════════════════════════════════════════════
--  TWEEN / UI HELPERS
-- ═══════════════════════════════════════════════════════════
local function tw(obj, props, t, style, dir)
    return TweenService:Create(obj, TweenInfo.new(
        t or 0.2,
        style or Enum.EasingStyle.Quad,
        dir   or Enum.EasingDirection.Out
    ), props)
end

local function corner(parent, r)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, r or 8)
    c.Parent = parent
    return c
end

local function pad(parent, v, h)
    local p = Instance.new("UIPadding")
    p.PaddingTop    = UDim.new(0, v or 8)
    p.PaddingBottom = UDim.new(0, v or 8)
    p.PaddingLeft   = UDim.new(0, h or 8)
    p.PaddingRight  = UDim.new(0, h or 8)
    p.Parent = parent
    return p
end

local function shadow(parent)
    local s = Instance.new("ImageLabel")
    s.AnchorPoint       = Vector2.new(0.5,0.5)
    s.BackgroundTransparency = 1
    s.Position          = UDim2.new(0.5,0,0.5,6)
    s.Size              = UDim2.new(1,28,1,28)
    s.ZIndex            = parent.ZIndex - 1
    s.Image             = "rbxassetid://6014261993"
    s.ImageColor3       = Color3.new(0,0,0)
    s.ImageTransparency = 0.55
    s.ScaleType         = Enum.ScaleType.Slice
    s.SliceCenter       = Rect.new(49,49,450,450)
    s.Parent            = parent
    return s
end

-- ═══════════════════════════════════════════════════════════
--  COLORS
-- ═══════════════════════════════════════════════════════════
local C = {
    bg       = Color3.fromRGB(10,10,18),
    panel    = Color3.fromRGB(16,16,28),
    card     = Color3.fromRGB(22,22,38),
    accent   = Color3.fromRGB(255,210,0),
    accent2  = Color3.fromRGB(255,140,0),
    text     = Color3.fromRGB(235,235,250),
    sub      = Color3.fromRGB(150,150,180),
    on       = Color3.fromRGB(80,220,120),
    off      = Color3.fromRGB(55,55,85),
    danger   = Color3.fromRGB(255,65,65),
    btn      = Color3.fromRGB(28,28,46),
}

-- ═══════════════════════════════════════════════════════════
--  SCREEN GUI ROOT
-- ═══════════════════════════════════════════════════════════
pcall(function()
    local old = pg:FindFirstChild("LEGACYFORTENESS_GUI")
    if old then old:Destroy() end
end)

local SG = Instance.new("ScreenGui")
SG.Name              = "LEGACYFORTENESS_GUI"
SG.ResetOnSpawn      = false
SG.IgnoreGuiInset    = true
SG.DisplayOrder      = 999
SG.ZIndexBehavior    = Enum.ZIndexBehavior.Sibling
SG.Parent            = pg

-- ═══════════════════════════════════════════════════════════
--  NOTIFICATION TOAST
-- ═══════════════════════════════════════════════════════════
local function toast(msg, color)
    color = color or C.accent
    local t = Instance.new("Frame")
    t.Size              = UDim2.new(0,220,0,40)
    t.AnchorPoint       = Vector2.new(0.5,0)
    t.Position          = UDim2.new(0.5,0,-0.1,0)
    t.BackgroundColor3  = C.panel
    t.BorderSizePixel   = 0
    t.ZIndex            = 500
    t.Parent            = SG
    corner(t, 10)
    shadow(t)

    local stroke = Instance.new("UIStroke")
    stroke.Color     = color
    stroke.Thickness = 1.5
    stroke.Parent    = t

    local lbl = Instance.new("TextLabel")
    lbl.Size       = UDim2.fromScale(1,1)
    lbl.BackgroundTransparency = 1
    lbl.Text       = msg
    lbl.TextColor3 = color
    lbl.TextScaled = true
    lbl.Font       = Enum.Font.GothamSemibold
    lbl.ZIndex     = 501
    lbl.Parent     = t

    tw(t, {Position=UDim2.new(0.5,0,0,8)}, 0.35, Enum.EasingStyle.Back):Play()
    task.delay(2.2, function()
        tw(t, {Position=UDim2.new(0.5,0,-0.08,0), BackgroundTransparency=1}, 0.3):Play()
        task.wait(0.35)
        t:Destroy()
    end)
end

-- ═══════════════════════════════════════════════════════════
--  DRAG SYSTEM (mobile-safe)
-- ═══════════════════════════════════════════════════════════
local function makeDraggable(handle, frame)
    local dragging, dStart, fStart = false, nil, nil

    local function onInputBegan(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1
        or inp.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dStart   = inp.Position
            fStart   = frame.Position
            inp.Changed:Connect(function()
                if inp.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end

    handle.InputBegan:Connect(onInputBegan)

    UserInputService.InputChanged:Connect(function(inp)
        if not dragging then return end
        if inp.UserInputType ~= Enum.UserInputType.MouseMovement
        and inp.UserInputType ~= Enum.UserInputType.Touch then return end
        local delta = inp.Position - dStart
        frame.Position = UDim2.new(
            fStart.X.Scale, fStart.X.Offset + delta.X,
            fStart.Y.Scale, fStart.Y.Offset + delta.Y
        )
    end)
end

-- ═══════════════════════════════════════════════════════════
--  WELCOME / PASSWORD SCREEN
-- ═══════════════════════════════════════════════════════════
local WS = Instance.new("Frame")
WS.Name                 = "WelcomeScreen"
WS.Size                 = UDim2.fromScale(1,1)
WS.BackgroundColor3     = Color3.new(0,0,0)
WS.BorderSizePixel      = 0
WS.ZIndex               = 200
WS.Parent               = SG

-- Particle sparkles (decorative)
local function spawnSparkle()
    local sp = Instance.new("Frame")
    sp.Size = UDim2.new(0,4,0,4)
    sp.Position = UDim2.new(math.random(), 0, math.random(), 0)
    sp.BackgroundColor3 = C.accent
    sp.BackgroundTransparency = 0.3
    sp.BorderSizePixel = 0
    sp.ZIndex = 201
    sp.Parent = WS
    corner(sp, 2)
    local tgt = UDim2.new(sp.Position.X.Scale, 0, sp.Position.Y.Scale - 0.3, 0)
    tw(sp, {Position=tgt, BackgroundTransparency=1}, 2+math.random()*2):Play()
    task.delay(4, function() pcall(function() sp:Destroy() end) end)
end

task.spawn(function()
    while WS and WS.Parent do
        spawnSparkle()
        task.wait(0.18)
    end
end)

-- Title
local WTitle = Instance.new("TextLabel")
WTitle.Size                 = UDim2.new(0.9,0,0,70)
WTitle.AnchorPoint          = Vector2.new(0.5,0.5)
WTitle.Position             = UDim2.new(0.5,0,0.3,0)
WTitle.BackgroundTransparency = 1
WTitle.Text                 = ""
WTitle.TextColor3           = C.accent
WTitle.TextScaled           = true
WTitle.Font                 = Enum.Font.GothamBold
WTitle.TextTransparency     = 1
WTitle.ZIndex               = 202
WTitle.Parent               = WS

local WSub = Instance.new("TextLabel")
WSub.Size                   = UDim2.new(0.8,0,0,26)
WSub.AnchorPoint            = Vector2.new(0.5,0.5)
WSub.Position               = UDim2.new(0.5,0,0.44,0)
WSub.BackgroundTransparency = 1
WSub.Text                   = "King Legacy ⚔️  |  UPD 10  |  Mobile Ready"
WSub.TextColor3             = C.sub
WSub.TextScaled             = true
WSub.Font                   = Enum.Font.Gotham
WSub.TextTransparency        = 1
WSub.ZIndex                 = 202
WSub.Parent                 = WS

-- Password panel
local PP = Instance.new("Frame")
PP.Name                     = "PassPanel"
PP.Size                     = UDim2.new(0.82,0,0,170)
PP.AnchorPoint              = Vector2.new(0.5,0.5)
PP.Position                 = UDim2.new(0.5,0,0.72,0)
PP.BackgroundColor3         = C.panel
PP.BackgroundTransparency   = 0.08
PP.BorderSizePixel          = 0
PP.ZIndex                   = 202
PP.Visible                  = false
PP.Parent                   = WS
corner(PP, 18)
shadow(PP)

local PPStroke = Instance.new("UIStroke")
PPStroke.Color     = C.accent
PPStroke.Thickness = 1.5
PPStroke.Parent    = PP

local PPLayout = Instance.new("UIListLayout")
PPLayout.SortOrder          = Enum.SortOrder.LayoutOrder
PPLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
PPLayout.Padding            = UDim.new(0,8)
PPLayout.Parent             = PP
pad(PP, 12, 16)

local PPTitle = Instance.new("TextLabel")
PPTitle.Size                = UDim2.new(1,0,0,22)
PPTitle.BackgroundTransparency = 1
PPTitle.Text                = "🔐  Digite a senha de acesso"
PPTitle.TextColor3          = C.sub
PPTitle.TextScaled          = true
PPTitle.Font                = Enum.Font.Gotham
PPTitle.LayoutOrder         = 1
PPTitle.ZIndex              = 203
PPTitle.Parent              = PP

local PPInput = Instance.new("TextBox")
PPInput.Size                = UDim2.new(1,0,0,46)
PPInput.BackgroundColor3    = C.btn
PPInput.TextColor3          = C.text
PPInput.PlaceholderText     = "Senha..."
PPInput.PlaceholderColor3   = C.sub
PPInput.Text                = ""
PPInput.TextScaled          = true
PPInput.Font                = Enum.Font.GothamBold
PPInput.ClearTextOnFocus    = true
PPInput.LayoutOrder         = 2
PPInput.ZIndex              = 204
PPInput.Parent              = PP
corner(PPInput, 10)
local PPInputStroke = Instance.new("UIStroke")
PPInputStroke.Color     = C.accent
PPInputStroke.Thickness = 1.5
PPInputStroke.Parent    = PPInput

local PPBtn = Instance.new("TextButton")
PPBtn.Size              = UDim2.new(0.65,0,0,42)
PPBtn.BackgroundColor3  = C.accent
PPBtn.TextColor3        = Color3.new(0,0,0)
PPBtn.Text              = "⚔️  ENTRAR"
PPBtn.TextScaled        = true
PPBtn.Font              = Enum.Font.GothamBold
PPBtn.LayoutOrder       = 3
PPBtn.ZIndex            = 203
PPBtn.Parent            = PP
corner(PPBtn, 11)

local PPErr = Instance.new("TextLabel")
PPErr.Size              = UDim2.new(1,0,0,18)
PPErr.BackgroundTransparency = 1
PPErr.Text              = ""
PPErr.TextColor3        = C.danger
PPErr.TextScaled        = true
PPErr.Font              = Enum.Font.Gotham
PPErr.LayoutOrder       = 4
PPErr.ZIndex            = 203
PPErr.Parent            = PP

-- Typewriter
local function typewrite(lbl, text, spd)
    spd = spd or 0.055
    lbl.Text = ""
    for i = 1, #text do
        lbl.Text = text:sub(1,i)
        task.wait(spd)
    end
end

-- Shake frame
local function shakeFrame(frm)
    local base = frm.Position
    for i = 1, 7 do
        local off = (i%2==0) and 10 or -10
        tw(frm, {Position = base + UDim2.fromOffset(off,0)}, 0.045):Play()
        task.wait(0.05)
    end
    tw(frm, {Position = base}, 0.1):Play()
end

-- Intro animation
task.spawn(function()
    task.wait(0.4)
    tw(WTitle, {TextTransparency = 0}, 0.5):Play()
    task.wait(0.3)
    typewrite(WTitle, "⚔️ Bem-vindo a LEGACY FORTENESS")
    task.wait(0.2)
    tw(WSub, {TextTransparency = 0}, 0.6):Play()
    task.wait(0.7)
    PP.Visible  = true
    PP.Position = UDim2.new(0.5,0,1.1,0)
    tw(PP, {Position = UDim2.new(0.5,0,0.72,0)}, 0.5, Enum.EasingStyle.Back):Play()
    task.wait(0.1)
    for _, c in ipairs(PP:GetDescendants()) do
        pcall(function()
            if c:IsA("TextLabel") or c:IsA("TextBox") or c:IsA("TextButton") then
                c.TextTransparency = 1
                tw(c, {TextTransparency=0}, 0.4):Play()
            end
        end)
    end
end)

-- ═══════════════════════════════════════════════════════════
--  MAIN UI FRAME (hidden until authenticated)
-- ═══════════════════════════════════════════════════════════
local MF = Instance.new("Frame")
MF.Name             = "MainFrame"
MF.Size             = UDim2.new(0,370,0,490)
MF.AnchorPoint      = Vector2.new(0.5,0.5)
MF.Position         = UDim2.new(0.5,0,0.5,0)
MF.BackgroundColor3 = C.bg
MF.BorderSizePixel  = 0
MF.Visible          = false
MF.ZIndex           = 10
MF.Parent           = SG
corner(MF, 16)
shadow(MF)

-- Header
local HD = Instance.new("Frame")
HD.Size             = UDim2.new(1,0,0,54)
HD.BackgroundColor3 = C.panel
HD.BorderSizePixel  = 0
HD.ZIndex           = 11
HD.Parent           = MF
corner(HD, 16)

-- fix bottom of header corners
local HDFix = Instance.new("Frame")
HDFix.Size = UDim2.new(1,0,0.5,0)
HDFix.Position = UDim2.new(0,0,0.5,0)
HDFix.BackgroundColor3 = C.panel
HDFix.BorderSizePixel = 0
HDFix.ZIndex = 11
HDFix.Parent = HD

local HDTitle = Instance.new("TextLabel")
HDTitle.Size = UDim2.new(0.65,0,1,0)
HDTitle.Position = UDim2.new(0.04,0,0,0)
HDTitle.BackgroundTransparency = 1
HDTitle.Text = "⚔️  LEGACY FORTENESS"
HDTitle.TextColor3 = C.accent
HDTitle.TextScaled = true
HDTitle.Font = Enum.Font.GothamBold
HDTitle.TextXAlignment = Enum.TextXAlignment.Left
HDTitle.ZIndex = 12
HDTitle.Parent = HD

-- Status indicator
local StatusRow = Instance.new("Frame")
StatusRow.Size = UDim2.new(0.3,0,0.55,0)
StatusRow.AnchorPoint = Vector2.new(1,0.5)
StatusRow.Position = UDim2.new(0.97,0,0.5,0)
StatusRow.BackgroundTransparency = 1
StatusRow.ZIndex = 12
StatusRow.Parent = HD

local Dot = Instance.new("Frame")
Dot.Size = UDim2.new(0,10,0,10)
Dot.AnchorPoint = Vector2.new(0,0.5)
Dot.Position = UDim2.new(0.1,0,0.5,0)
Dot.BackgroundColor3 = C.on
Dot.BorderSizePixel = 0
Dot.ZIndex = 13
Dot.Parent = StatusRow
corner(Dot, 5)

local DotLabel = Instance.new("TextLabel")
DotLabel.Size = UDim2.new(0.7,0,1,0)
DotLabel.Position = UDim2.new(0.3,0,0,0)
DotLabel.BackgroundTransparency = 1
DotLabel.Text = "ACTIVE"
DotLabel.TextColor3 = C.on
DotLabel.TextScaled = true
DotLabel.Font = Enum.Font.GothamBold
DotLabel.ZIndex = 13
DotLabel.Parent = StatusRow

-- Pulsing dot
task.spawn(function()
    while true do
        tw(Dot, {BackgroundTransparency=0.55}, 0.5):Play()
        task.wait(0.6)
        tw(Dot, {BackgroundTransparency=0}, 0.5):Play()
        task.wait(0.6)
    end
end)

makeDraggable(HD, MF)

-- ── TAB BAR ────────────────────────────────────────────────
local TB = Instance.new("Frame")
TB.Size = UDim2.new(1,-16,0,42)
TB.Position = UDim2.new(0,8,0,58)
TB.BackgroundColor3 = C.panel
TB.BorderSizePixel = 0
TB.ZIndex = 11
TB.Parent = MF
corner(TB, 10)

local TBLayout = Instance.new("UIListLayout")
TBLayout.FillDirection = Enum.FillDirection.Horizontal
TBLayout.SortOrder = Enum.SortOrder.LayoutOrder
TBLayout.Padding = UDim.new(0,3)
TBLayout.VerticalAlignment = Enum.VerticalAlignment.Center
TBLayout.Parent = TB
pad(TB, 4, 4)

-- ── CONTENT AREA ───────────────────────────────────────────
local CA = Instance.new("Frame")
CA.Name = "ContentArea"
CA.Size = UDim2.new(1,-16,1,-114)
CA.Position = UDim2.new(0,8,0,106)
CA.BackgroundTransparency = 1
CA.BorderSizePixel = 0
CA.ZIndex = 11
CA.ClipsDescendants = true
CA.Parent = MF

-- ═══════════════════════════════════════════════════════════
--  TAB SYSTEM
-- ═══════════════════════════════════════════════════════════
local TAB_DEFS = {
    {key="Farm",     label="🌾 Farm"},
    {key="Teleport", label="🗺️ TP"},
    {key="ESP",      label="👁️ ESP"},
    {key="Misc",     label="⚡ Misc"},
    {key="Config",   label="⚙️"},
}

local tabBtns   = {}
local tabPages  = {}
local curTab    = "Farm"

local function switchTab(key)
    curTab = key
    for k, page in pairs(tabPages) do
        page.Visible = (k == key)
    end
    for k, btn in pairs(tabBtns) do
        local active = (k == key)
        tw(btn, {
            BackgroundColor3 = active and C.accent or C.btn,
            TextColor3       = active and Color3.new(0,0,0) or C.sub,
        }, 0.15):Play()
    end
end

-- Create tab buttons + scrolling pages
for i, td in ipairs(TAB_DEFS) do
    -- button
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1/#TAB_DEFS, -4, 1, 0)
    btn.BackgroundColor3 = i == 1 and C.accent or C.btn
    btn.TextColor3 = i == 1 and Color3.new(0,0,0) or C.sub
    btn.Text = td.label
    btn.TextScaled = true
    btn.Font = Enum.Font.GothamSemibold
    btn.BorderSizePixel = 0
    btn.ZIndex = 12
    btn.LayoutOrder = i
    btn.Parent = TB
    corner(btn, 8)
    tabBtns[td.key] = btn

    -- scrolling page
    local page = Instance.new("ScrollingFrame")
    page.Size = UDim2.fromScale(1,1)
    page.BackgroundTransparency = 1
    page.BorderSizePixel = 0
    page.ScrollBarThickness = 3
    page.ScrollBarImageColor3 = C.accent
    page.AutomaticCanvasSize = Enum.AutomaticSize.Y
    page.CanvasSize = UDim2.new(0,0,0,0)
    page.Visible = (i == 1)
    page.ZIndex = 11
    page.Parent = CA

    local pageLayout = Instance.new("UIListLayout")
    pageLayout.SortOrder = Enum.SortOrder.LayoutOrder
    pageLayout.Padding = UDim.new(0,6)
    pageLayout.Parent = page
    pad(page, 4, 0)

    tabPages[td.key] = page

    btn.MouseButton1Click:Connect(function()
        switchTab(td.key)
    end)
end

-- ═══════════════════════════════════════════════════════════
--  COMPONENT BUILDERS
-- ═══════════════════════════════════════════════════════════
local function mkSection(parent, title, order)
    local s = Instance.new("Frame")
    s.Size = UDim2.new(1,0,0,0)
    s.AutomaticSize = Enum.AutomaticSize.Y
    s.BackgroundColor3 = C.card
    s.BorderSizePixel = 0
    s.ZIndex = 12
    s.LayoutOrder = order or 1
    s.Parent = parent
    corner(s, 10)

    local sl = Instance.new("UIListLayout")
    sl.SortOrder = Enum.SortOrder.LayoutOrder
    sl.Padding = UDim.new(0,2)
    sl.Parent = s
    pad(s, 8, 10)

    local tl = Instance.new("TextLabel")
    tl.Size = UDim2.new(1,0,0,22)
    tl.BackgroundTransparency = 1
    tl.Text = title
    tl.TextColor3 = C.accent
    tl.TextScaled = true
    tl.Font = Enum.Font.GothamBold
    tl.TextXAlignment = Enum.TextXAlignment.Left
    tl.ZIndex = 13
    tl.LayoutOrder = 0
    tl.Parent = s

    local div = Instance.new("Frame")
    div.Size = UDim2.new(1,0,0,1)
    div.BackgroundColor3 = C.accent
    div.BackgroundTransparency = 0.65
    div.BorderSizePixel = 0
    div.ZIndex = 13
    div.LayoutOrder = 1
    div.Parent = s

    return s
end

local function mkToggle(parent, label, desc, default, cb, order)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1,0,0,52)
    row.BackgroundTransparency = 1
    row.LayoutOrder = order or 2
    row.ZIndex = 13
    row.Parent = parent

    local lblEl = Instance.new("TextLabel")
    lblEl.Size = UDim2.new(0.68,0,0.48,0)
    lblEl.BackgroundTransparency = 1
    lblEl.Text = label
    lblEl.TextColor3 = C.text
    lblEl.TextScaled = true
    lblEl.Font = Enum.Font.GothamSemibold
    lblEl.TextXAlignment = Enum.TextXAlignment.Left
    lblEl.ZIndex = 14
    lblEl.Parent = row

    if desc then
        local descEl = Instance.new("TextLabel")
        descEl.Size = UDim2.new(0.68,0,0.44,0)
        descEl.Position = UDim2.new(0,0,0.5,0)
        descEl.BackgroundTransparency = 1
        descEl.Text = desc
        descEl.TextColor3 = C.sub
        descEl.TextScaled = true
        descEl.Font = Enum.Font.Gotham
        descEl.TextXAlignment = Enum.TextXAlignment.Left
        descEl.ZIndex = 14
        descEl.Parent = row
    end

    local track = Instance.new("Frame")
    track.Size = UDim2.new(0,52,0,28)
    track.AnchorPoint = Vector2.new(1,0.5)
    track.Position = UDim2.new(1,0,0.5,0)
    track.BackgroundColor3 = default and C.on or C.off
    track.BorderSizePixel = 0
    track.ZIndex = 14
    track.Parent = row
    corner(track, 14)

    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0,22,0,22)
    knob.AnchorPoint = Vector2.new(0.5,0.5)
    knob.Position = default and UDim2.new(0.73,0,0.5,0) or UDim2.new(0.27,0,0.5,0)
    knob.BackgroundColor3 = Color3.new(1,1,1)
    knob.BorderSizePixel = 0
    knob.ZIndex = 15
    knob.Parent = track
    corner(knob, 11)

    local state = default or false

    local hitbox = Instance.new("TextButton")
    hitbox.Size = UDim2.fromScale(1,1)
    hitbox.BackgroundTransparency = 1
    hitbox.Text = ""
    hitbox.ZIndex = 15
    hitbox.Parent = track

    local handle
    handle = hitbox.MouseButton1Click:Connect(function()
        state = not state
        tw(track, {BackgroundColor3 = state and C.on or C.off}, 0.15):Play()
        tw(knob,  {Position = state and UDim2.new(0.73,0,0.5,0) or UDim2.new(0.27,0,0.5,0)}, 0.15):Play()
        cb(state)
    end)

    return {
        get = function() return state end,
        set = function(v)
            state = v
            tw(track, {BackgroundColor3 = state and C.on or C.off}, 0.15):Play()
            tw(knob,  {Position = state and UDim2.new(0.73,0,0.5,0) or UDim2.new(0.27,0,0.5,0)}, 0.15):Play()
        end
    }
end

local function mkButton(parent, label, color, cb, order)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1,0,0,40)
    btn.BackgroundColor3 = color or C.btn
    btn.TextColor3 = C.text
    btn.Text = label
    btn.TextScaled = true
    btn.Font = Enum.Font.GothamBold
    btn.BorderSizePixel = 0
    btn.ZIndex = 14
    btn.LayoutOrder = order or 10
    btn.Parent = parent
    corner(btn, 8)

    btn.MouseButton1Click:Connect(function()
        tw(btn, {BackgroundColor3 = C.accent, TextColor3 = Color3.new(0,0,0)}, 0.08):Play()
        task.wait(0.12)
        tw(btn, {BackgroundColor3 = color or C.btn, TextColor3 = C.text}, 0.15):Play()
        task.spawn(cb)
    end)
    return btn
end

local function mkSlider(parent, label, min_, max_, default_, cb, order)
    local cont = Instance.new("Frame")
    cont.Size = UDim2.new(1,0,0,58)
    cont.BackgroundTransparency = 1
    cont.LayoutOrder = order or 5
    cont.ZIndex = 13
    cont.Parent = parent

    local lblEl = Instance.new("TextLabel")
    lblEl.Size = UDim2.new(0.68,0,0.4,0)
    lblEl.BackgroundTransparency = 1
    lblEl.Text = label
    lblEl.TextColor3 = C.text
    lblEl.TextScaled = true
    lblEl.Font = Enum.Font.GothamSemibold
    lblEl.TextXAlignment = Enum.TextXAlignment.Left
    lblEl.ZIndex = 14
    lblEl.Parent = cont

    local valLbl = Instance.new("TextLabel")
    valLbl.Size = UDim2.new(0.3,0,0.4,0)
    valLbl.Position = UDim2.new(0.7,0,0,0)
    valLbl.BackgroundTransparency = 1
    valLbl.Text = tostring(default_)
    valLbl.TextColor3 = C.accent
    valLbl.TextScaled = true
    valLbl.Font = Enum.Font.GothamBold
    valLbl.TextXAlignment = Enum.TextXAlignment.Right
    valLbl.ZIndex = 14
    valLbl.Parent = cont

    local track = Instance.new("Frame")
    track.Size = UDim2.new(1,0,0,8)
    track.Position = UDim2.new(0,0,0.65,0)
    track.BackgroundColor3 = C.off
    track.BorderSizePixel = 0
    track.ZIndex = 14
    track.Parent = cont
    corner(track, 4)

    local pct0 = (default_ - min_) / (max_ - min_)
    local fill = Instance.new("Frame")
    fill.Size = UDim2.new(pct0,0,1,0)
    fill.BackgroundColor3 = C.accent
    fill.BorderSizePixel = 0
    fill.ZIndex = 15
    fill.Parent = track
    corner(fill, 4)

    local knob2 = Instance.new("Frame")
    knob2.Size = UDim2.new(0,20,0,20)
    knob2.AnchorPoint = Vector2.new(0.5,0.5)
    knob2.Position = UDim2.new(pct0,0,0.5,0)
    knob2.BackgroundColor3 = Color3.new(1,1,1)
    knob2.BorderSizePixel = 0
    knob2.ZIndex = 16
    knob2.Parent = track
    corner(knob2, 10)

    local curVal = default_
    local slDragging = false

    local function update(inputPos)
        local ap  = track.AbsolutePosition
        local as_ = track.AbsoluteSize
        local rel = math.clamp((inputPos.X - ap.X) / as_.X, 0, 1)
        curVal = math.floor(min_ + rel * (max_ - min_))
        fill.Size = UDim2.new(rel, 0, 1, 0)
        knob2.Position = UDim2.new(rel, 0, 0.5, 0)
        valLbl.Text = tostring(curVal)
        cb(curVal)
    end

    track.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1
        or inp.UserInputType == Enum.UserInputType.Touch then
            slDragging = true
            update(inp.Position)
        end
    end)
    track.InputEnded:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1
        or inp.UserInputType == Enum.UserInputType.Touch then
            slDragging = false
        end
    end)
    UserInputService.InputChanged:Connect(function(inp)
        if slDragging and (inp.UserInputType == Enum.UserInputType.MouseMovement
        or inp.UserInputType == Enum.UserInputType.Touch) then
            update(inp.Position)
        end
    end)

    return cont
end

local function mkDropdown(parent, label, options, default_, cb, order)
    local cont = Instance.new("Frame")
    cont.Size = UDim2.new(1,0,0,46)
    cont.BackgroundTransparency = 1
    cont.LayoutOrder = order or 5
    cont.ZIndex = 13
    cont.Parent = parent

    local lbl2 = Instance.new("TextLabel")
    lbl2.Size = UDim2.new(0.47,0,1,0)
    lbl2.BackgroundTransparency = 1
    lbl2.Text = label
    lbl2.TextColor3 = C.text
    lbl2.TextScaled = true
    lbl2.Font = Enum.Font.GothamSemibold
    lbl2.TextXAlignment = Enum.TextXAlignment.Left
    lbl2.ZIndex = 14
    lbl2.Parent = cont

    local idx = 1
    for i, o in ipairs(options) do
        if o == default_ then idx = i; break end
    end

    local dbtn = Instance.new("TextButton")
    dbtn.Size = UDim2.new(0.5,0,0.72,0)
    dbtn.AnchorPoint = Vector2.new(1,0.5)
    dbtn.Position = UDim2.new(1,0,0.5,0)
    dbtn.BackgroundColor3 = C.btn
    dbtn.TextColor3 = C.accent
    dbtn.Text = options[idx] .. " ▾"
    dbtn.TextScaled = true
    dbtn.Font = Enum.Font.GothamSemibold
    dbtn.BorderSizePixel = 0
    dbtn.ZIndex = 14
    dbtn.Parent = cont
    corner(dbtn, 8)

    dbtn.MouseButton1Click:Connect(function()
        idx = idx % #options + 1
        dbtn.Text = options[idx] .. " ▾"
        cb(options[idx])
    end)

    return cont
end

local function mkLabel(parent, text, clr, order)
    local lbl3 = Instance.new("TextLabel")
    lbl3.Size = UDim2.new(1,0,0,22)
    lbl3.BackgroundTransparency = 1
    lbl3.Text = text
    lbl3.TextColor3 = clr or C.sub
    lbl3.TextScaled = true
    lbl3.Font = Enum.Font.Gotham
    lbl3.TextXAlignment = Enum.TextXAlignment.Left
    lbl3.ZIndex = 14
    lbl3.LayoutOrder = order or 99
    lbl3.Parent = parent
    return lbl3
end

-- ═══════════════════════════════════════════════════════════
--  FARM TAB
-- ═══════════════════════════════════════════════════════════
do
    local pg2 = tabPages["Farm"]

    local s1 = mkSection(pg2, "🌾 Auto Farm", 1)
    mkToggle(s1, "Auto Farm",   "Matar mobs e farmar XP/Beli", false, function(v)
        CFG.farm.enabled = v
        if v then startFarm(); toast("🌾 Auto Farm: ON", C.on)
        else      stopFarm();  toast("🌾 Auto Farm: OFF", C.danger) end
    end, 2)
    mkToggle(s1, "Auto Quest",  "Aceitar e completar quests", true, function(v)
        CFG.farm.autoQuest = v
        toast("📜 Auto Quest: " .. (v and "ON" or "OFF"), v and C.on or C.danger)
    end, 3)
    mkToggle(s1, "Auto Stats",  "Distribuir pontos automático", false, function(v)
        CFG.farm.autoStats = v
        toast("📊 Auto Stats: " .. (v and "ON" or "OFF"), v and C.on or C.danger)
    end, 4)
    mkDropdown(s1, "Stat Alvo", {"STR","DEF","AGI","INT"}, "STR", function(v)
        CFG.farm.statTarget = v
        toast("📊 Stat: " .. v, C.accent)
    end, 5)
    mkSlider(s1, "Hitbox Range (studs)", 5, 50, 18, function(v)
        CFG.farm.hitboxSize = v
    end, 6)
    mkSlider(s1, "Farm Radius (studs)", 20, 300, 80, function(v)
        CFG.farm.farmRange = v
    end, 7)
    mkSlider(s1, "Delay de Ataque (ms)", 60, 500, 120, function(v)
        CFG.farm.attackDelay = v / 1000
    end, 8)

    local s2 = mkSection(pg2, "🏴‍☠️ Bosses & Sea Beasts", 2)
    mkToggle(s2, "Sea Beast Farm", "Matar Hidra / Sea King auto", false, function(v)
        CFG.farm.seaBeast = v
        if v then
            seaBeastThread = task.spawn(seaBeastLoop)
            toast("🌊 Sea Beast: ON", C.on)
        else
            toast("🌊 Sea Beast: OFF", C.danger)
        end
    end, 2)
    mkButton(s2, "⚔️ Atacar Boss Mais Próximo", C.btn, function()
        local best, bestH = nil, 0
        for _, obj in ipairs(workspace:GetDescendants()) do
            if isMob(obj) then
                local h = obj:FindFirstChildOfClass("Humanoid")
                if h and h.MaxHealth > 50000 and h.MaxHealth > bestH then
                    bestH = h.MaxHealth; best = obj
                end
            end
        end
        if best then
            expandHitbox(best)
            local mr = mobRoot(best)
            if mr then
                safeTP(mr.Position)
                for i = 1, 60 do
                    if not isMob(best) then break end
                    attackMob(best)
                    task.wait(0.15)
                end
                toast("⚔️ Boss atacado!", C.accent)
            end
        else
            toast("Nenhum boss encontrado", C.danger)
        end
    end, 3)

    local s3 = mkSection(pg2, "🍈 Devil Fruit", 3)
    mkToggle(s3, "Fruit Sniper", "Pegar fruits automaticamente", false, function(v)
        CFG.farm.fruitSniper = v
        if v then
            task.spawn(function()
                while CFG.farm.fruitSniper do
                    pcall(snipeFruit)
                    task.wait(2.5 + math.random()*2)
                end
            end)
            toast("🍈 Fruit Sniper: ON", C.on)
        else
            toast("🍈 Fruit Sniper: OFF", C.danger)
        end
    end, 2)
    mkButton(s3, "🍈 Pegar Fruit Mais Próximo", C.btn, function()
        local ok, name = snipeFruit()
        if ok then toast("🍈 Fruit pego: " .. (name or "?"), C.on)
        else       toast("Nenhum fruit encontrado", C.danger) end
    end, 3)
end

-- ═══════════════════════════════════════════════════════════
--  TELEPORT TAB
-- ═══════════════════════════════════════════════════════════
do
    local pg3 = tabPages["Teleport"]

    local s1 = mkSection(pg3, "🗺️ Primeira Mar", 1)
    local firstSea = {}
    local secondSea = {}
    for _, isl in ipairs(ISLANDS) do
        if isl.n:sub(1,2) == "S2" or isl.n:sub(1,2) == "S3" then
            table.insert(secondSea, isl)
        else
            table.insert(firstSea, isl)
        end
    end

    for i, isl in ipairs(firstSea) do
        mkButton(s1, "→ " .. isl.n .. "  [Lv " .. isl.lv[1] .. "+]", C.btn, function()
            tpToIsland(isl)
            toast("🗺️ TP: " .. isl.n, C.accent)
        end, i+1)
    end

    local s2 = mkSection(pg3, "🗺️ Segunda / Terceira Mar", 2)
    for i, isl in ipairs(secondSea) do
        mkButton(s2, "→ " .. isl.n .. "  [Lv " .. isl.lv[1] .. "+]", C.btn, function()
            tpToIsland(isl)
            toast("🗺️ TP: " .. isl.n, C.accent)
        end, i+1)
    end

    local s3 = mkSection(pg3, "⚡ TP Especial", 3)
    mkButton(s3, "📜 Ir ao NPC de Quest", C.btn, function()
        local npc, r = findQuestNPC()
        if npc and r then
            safeTP(r.Position + Vector3.new(3,0,0))
            toast("📜 NPC Quest encontrado!", C.on)
        else
            toast("Nenhum Quest NPC próximo", C.danger)
        end
    end, 1)
    mkButton(s3, "🔵 Bubble Island (Armament Haki)", C.btn, function()
        local isl = nil
        for _, i in ipairs(ISLANDS) do
            if i.n == "Bubble Island" then isl = i; break end
        end
        if isl then tpToIsland(isl); toast("🔵 Bubble Island!", C.on) end
    end, 2)
    mkButton(s3, "☁️ Sky Island (Observation Haki)", C.btn, function()
        local isl = nil
        for _, i in ipairs(ISLANDS) do
            if i.n == "Sky Island" then isl = i; break end
        end
        if isl then tpToIsland(isl); toast("☁️ Sky Island!", C.on) end
    end, 3)
    mkButton(s3, "👤 TP ao Jogador Mais Próximo", C.btn, function()
        if not root then return end
        local best, bestD = nil, math.huge
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= lp and p.Character then
                local r2 = p.Character:FindFirstChild("HumanoidRootPart")
                if r2 then
                    local d = (root.Position - r2.Position).Magnitude
                    if d < bestD then bestD = d; best = r2 end
                end
            end
        end
        if best then
            safeTP(best.Position + Vector3.new(3,0,0))
            toast("👤 TP ao jogador!", C.on)
        else
            toast("Nenhum jogador encontrado", C.danger)
        end
    end, 4)
    mkButton(s3, "🚀 TP à Ilha Recomendada (Nível)", C.accent2, function()
        local lvl = getLevel()
        local isl = getIslandByLevel(lvl)
        tpToIsland(isl)
        toast("🚀 → " .. isl.n .. " (Lv " .. lvl .. ")", C.accent)
    end, 5)
end

-- ═══════════════════════════════════════════════════════════
--  ESP TAB
-- ═══════════════════════════════════════════════════════════
do
    local pg4 = tabPages["ESP"]

    local s1 = mkSection(pg4, "👁️ ESP", 1)
    mkToggle(s1, "ESP Players",       "Ver jogadores através das paredes", false, function(v)
        CFG.esp.players = v
        if not v then
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= lp and p.Character and STATE.esps[p.Character] then
                    STATE.esps[p.Character]:Destroy()
                    STATE.esps[p.Character] = nil
                end
            end
        end
        toast("👤 Player ESP: " .. (v and "ON" or "OFF"), v and C.on or C.danger)
    end, 2)
    mkToggle(s1, "ESP Mobs",          "Ver mobs com caixas coloridas", false, function(v)
        CFG.esp.mobs = v
        if not v then
            for obj, bb in pairs(STATE.esps) do
                if isMob(obj) and bb and bb.Parent then
                    bb:Destroy()
                    STATE.esps[obj] = nil
                end
            end
        end
        toast("🟠 Mob ESP: " .. (v and "ON" or "OFF"), v and C.on or C.danger)
    end, 3)
    mkToggle(s1, "ESP Devil Fruits",  "Destacar fruits no mapa", false, function(v)
        CFG.esp.fruits = v
        toast("🍈 Fruit ESP: " .. (v and "ON" or "OFF"), v and C.on or C.danger)
    end, 4)
    mkButton(s1, "🔄 Atualizar ESP Agora", C.btn, function()
        clearESP()
        if CFG.esp.players then
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= lp and p.Character then
                    makeESP(p.Character, Color3.fromRGB(255,80,80), p.Name)
                end
            end
        end
        if CFG.esp.mobs then
            for _, obj in ipairs(workspace:GetDescendants()) do
                if isMob(obj) then
                    makeESP(obj, Color3.fromRGB(255,165,0), obj.Name)
                end
            end
        end
        if CFG.esp.fruits then
            for _, f in ipairs(findFruits()) do
                local part = f.obj:IsA("BasePart") and f.obj
                    or (f.obj:IsA("Model") and (f.obj.PrimaryPart or f.obj:FindFirstChildOfClass("BasePart")))
                if part then makeESP(f.obj, Color3.fromRGB(100,255,100), f.name) end
            end
        end
        toast("👁️ ESP Atualizado!", C.accent)
    end, 5)
    mkButton(s1, "❌ Limpar ESP", C.danger, function()
        clearESP()
        toast("❌ ESP Limpo", C.sub)
    end, 6)
end

-- ═══════════════════════════════════════════════════════════
--  MISC TAB
-- ═══════════════════════════════════════════════════════════
do
    local pg5 = tabPages["Misc"]

    local s1 = mkSection(pg5, "⚡ Movimento", 1)
    mkToggle(s1, "Speed Hack", "Aumentar velocidade", false, function(v)
        CFG.misc.speedOn = v
        if v then setWalkSpeed(CFG.misc.speedVal)
        else      setWalkSpeed(16) end
        toast("⚡ Speed: " .. (v and "ON" or "OFF"), v and C.on or C.danger)
    end, 2)
    mkSlider(s1, "Velocidade", 16, 250, 36, function(v)
        CFG.misc.speedVal = v
        if CFG.misc.speedOn then setWalkSpeed(v) end
    end, 3)
    mkToggle(s1, "Voar / Fly", "Voar livremente", false, function(v)
        CFG.misc.flyOn = v
        if v then enableFly() else disableFly() end
        toast("🕊️ Fly: " .. (v and "ON" or "OFF"), v and C.on or C.danger)
    end, 4)
    mkSlider(s1, "Velocidade do Voo", 10, 350, 60, function(v)
        CFG.misc.flySpeed = v
    end, 5)
    mkToggle(s1, "No Clip", "Atravessar paredes", false, function(v)
        CFG.misc.noClip = v
        if v then enableNoClip() else disableNoClip() end
        toast("👻 NoClip: " .. (v and "ON" or "OFF"), v and C.on or C.danger)
    end, 6)

    local s2 = mkSection(pg5, "🛡️ Combate", 2)
    mkToggle(s2, "God Mode", "Vida regenera automaticamente", false, function(v)
        CFG.misc.godMode = v
        if v then enableGod() else disableGod() end
        toast("🛡️ God Mode: " .. (v and "ON" or "OFF"), v and C.on or C.danger)
    end, 2)
    mkButton(s2, "💊 Heal Instantâneo", C.on, function()
        pcall(function()
            if hum then hum.Health = hum.MaxHealth end
        end)
        toast("💊 Vida cheia!", C.on)
    end, 3)
    mkButton(s2, "⚔️ Burst de Skills", C.btn, function()
        local evf = getEvFolder()
        for _, sn in ipairs({"Skill1","Skill2","Skill3","Skill4","Skill5","Q","E","R","T","F","UseSkill","Skill"}) do
            local ev = evf:FindFirstChild(sn, true)
            if ev and ev:IsA("RemoteEvent") then
                pcall(function() ev:FireServer() end)
                task.wait(0.1)
            end
        end
        toast("⚔️ Skills disparadas!", C.accent)
    end, 4)
    mkButton(s2, "🔮 Expandir Hitbox Global", C.btn, function()
        STATE.hitboxed = {}
        for _, obj in ipairs(workspace:GetDescendants()) do
            if isMob(obj) then expandHitbox(obj) end
        end
        toast("🔮 Hitbox expandida: todos mobs!", C.accent)
    end, 5)

    local s3 = mkSection(pg5, "🌊 Servidor", 3)
    mkButton(s3, "🔄 Server Hop", C.btn, function()
        pcall(function()
            TeleportService:Teleport(game.PlaceId, lp)
        end)
        toast("🔄 Trocando servidor...", C.sub)
    end, 1)
    mkButton(s3, "🏃 Rejoin", C.btn, function()
        pcall(function()
            TeleportService:Teleport(game.PlaceId, lp)
        end)
    end, 2)
end

-- ═══════════════════════════════════════════════════════════
--  CONFIG TAB
-- ═══════════════════════════════════════════════════════════
do
    local pg6 = tabPages["Config"]

    local s1 = mkSection(pg6, "🛡️ Anti-Detecção", 1)
    mkSlider(s1, "Delay Mínimo (ms)", 20, 300, 60, function(v)
        CFG.anti.minDelay = v / 1000
    end, 1)
    mkSlider(s1, "Delay Máximo (ms)", 100, 600, 220, function(v)
        CFG.anti.maxDelay = v / 1000
    end, 2)
    mkSlider(s1, "TP Jitter (studs)", 0, 10, 2, function(v)
        CFG.anti.jitter = v
    end, 3)
    mkToggle(s1, "Humanize Movimentos", "Padrões aleatórios de ação", true, function(v)
        CFG.anti.humanize = v
    end, 4)

    local s2 = mkSection(pg6, "ℹ️ Sobre", 2)
    mkLabel(s2, "⚔️  LEGACY FORTENESS v1.0", C.accent, 1)
    mkLabel(s2, "Jogo:  King Legacy  [UPD 10]", C.sub, 2)
    mkLabel(s2, "Executor:  Delta Mobile", C.sub, 3)
    mkLabel(s2, "Anti-Det:  ATIVO ✅", C.on, 4)
    mkLabel(s2, "Plataforma:  Mobile + PC", C.sub, 5)
    mkLabel(s2, "Nível Atual:  " .. tostring(getLevel()), C.accent, 6)

    mkButton(s2, "🔄 Atualizar Info", C.btn, function()
        -- rebuild label
        for _, c in ipairs(s2:GetChildren()) do
            if c:IsA("TextLabel") and c.Text:find("Nível Atual") then
                c.Text = "Nível Atual:  " .. tostring(getLevel())
            end
        end
    end, 7)
end

-- ═══════════════════════════════════════════════════════════
--  JV BUBBLE
-- ═══════════════════════════════════════════════════════════
local JV = Instance.new("TextButton")
JV.Name             = "JVBubble"
JV.Size             = UDim2.new(0,56,0,56)
JV.Position         = UDim2.new(0,12,0.5,-28)
JV.BackgroundColor3 = C.accent
JV.TextColor3       = Color3.new(0,0,0)
JV.Text             = "jv"
JV.TextScaled       = true
JV.Font             = Enum.Font.GothamBold
JV.BorderSizePixel  = 0
JV.ZIndex           = 300
JV.Visible          = false
JV.Parent           = SG
corner(JV, 28)
shadow(JV)

-- Pulsing animation for JV bubble
task.spawn(function()
    while JV and JV.Parent do
        tw(JV, {Size=UDim2.new(0,60,0,60)}, 0.35, Enum.EasingStyle.Sine):Play()
        task.wait(0.4)
        tw(JV, {Size=UDim2.new(0,56,0,56)}, 0.35, Enum.EasingStyle.Sine):Play()
        task.wait(0.4)
    end
end)

-- JV drag
local jvDrag, jvDStart, jvFStart = false, nil, nil
JV.InputBegan:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.MouseButton1
    or inp.UserInputType == Enum.UserInputType.Touch then
        jvDrag  = true
        jvDStart = inp.Position
        jvFStart = JV.Position
        inp.Changed:Connect(function()
            if inp.UserInputState == Enum.UserInputState.End then
                jvDrag = false
            end
        end)
    end
end)
UserInputService.InputChanged:Connect(function(inp)
    if not jvDrag then return end
    if inp.UserInputType ~= Enum.UserInputType.MouseMovement
    and inp.UserInputType ~= Enum.UserInputType.Touch then return end
    local delta = inp.Position - jvDStart
    JV.Position = UDim2.new(
        jvFStart.X.Scale, jvFStart.X.Offset + delta.X,
        jvFStart.Y.Scale, jvFStart.Y.Offset + delta.Y
    )
end)

local mainOpen = true
local didDrag  = false

JV.InputEnded:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.Touch then
        local delta = inp.Position - (jvDStart or inp.Position)
        if delta.Magnitude > 8 then didDrag = true end
    end
end)

JV.MouseButton1Click:Connect(function()
    if didDrag then didDrag = false; return end
    mainOpen = not mainOpen
    if mainOpen then
        MF.Visible = true
        MF.Size    = UDim2.new(0,0,0,0)
        tw(MF, {Size=UDim2.new(0,370,0,490)}, 0.3, Enum.EasingStyle.Back):Play()
        tw(JV, {BackgroundColor3=C.accent}, 0.15):Play()
    else
        tw(MF, {Size=UDim2.new(0,0,0,0)}, 0.2):Play()
        tw(JV, {BackgroundColor3=C.accent2}, 0.15):Play()
        task.wait(0.22)
        MF.Visible = false
    end
end)

-- ═══════════════════════════════════════════════════════════
--  PASSWORD HANDLER → show main UI
-- ═══════════════════════════════════════════════════════════
local function tryLogin()
    local pw = PPInput.Text:gsub("%s+","")
    if pw == "180125" then
        STATE.auth = true
        PPErr.Text = ""

        tw(PP,       {BackgroundColor3 = C.on}, 0.18):Play()
        task.wait(0.3)
        tw(WS,       {BackgroundTransparency=1}, 0.5):Play()
        for _, c in ipairs(WS:GetDescendants()) do
            pcall(function()
                if c:IsA("GuiObject") then
                    tw(c, {BackgroundTransparency=1}, 0.4):Play()
                end
                if c:IsA("TextLabel") or c:IsA("TextBox") or c:IsA("TextButton") then
                    tw(c, {TextTransparency=1}, 0.4):Play()
                end
            end)
        end
        task.wait(0.55)
        WS:Destroy()

        -- Reveal main
        MF.Visible  = true
        JV.Visible  = true
        MF.Size     = UDim2.new(0,0,0,0)
        tw(MF, {Size=UDim2.new(0,370,0,490)}, 0.45, Enum.EasingStyle.Back):Play()
        task.wait(0.1)
        toast("⚔️ LEGACY FORTENESS Carregado!", C.accent)
    else
        PPErr.Text = "❌  Senha incorreta!"
        task.spawn(function() shakeFrame(PP) end)
        tw(PPInput, {BackgroundColor3 = C.danger}, 0.1):Play()
        task.wait(0.6)
        tw(PPInput, {BackgroundColor3 = C.btn},    0.3):Play()
        PPErr.Text = ""
    end
end

PPBtn.MouseButton1Click:Connect(tryLogin)
PPInput.FocusLost:Connect(function(enter) if enter then tryLogin() end end)

-- ═══════════════════════════════════════════════════════════
print("[LEGACY FORTENESS] ⚔️  Pronto. Aguardando autenticação...")
-- ═══════════════════════════════════════════════════════════
