--[[
╔══════════════════════════════════════════════════════════════════╗
║          MILLIE HUB  ·  LEGACY PIECE  ·  v3.0 MEGA UPDATE       ║
║          Mobile Ready  ·  Delta Compatible  ·  Sem Bugs          ║
║          Senha: Millielover  ·  By dj                            ║
╠══════════════════════════════════════════════════════════════════╣
║  FIXES v3.0:                                                     ║
║  ✓ Hitbox: Part separada - NÃO buga mais no chão               ║
║  ✓ Auto Ataque: simula botão "Bater" do jogo (funciona!)        ║
║  ✓ Auto Quest: detecta progresso 0/5, ciclo completo            ║
║  ✓ Mob TP: traz mobs até você                                   ║
║  ✓ Kill Aura: mata todos em volta                               ║
║  ✓ ESP de mobs                                                   ║
║  ✓ Hub maior, mais bonito e mais completo                       ║
╚══════════════════════════════════════════════════════════════════╝
--]]

-- ════════════════════════════════════════════════════
-- [1] SERVIÇOS
-- ════════════════════════════════════════════════════
local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local TweenService     = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui       = game:GetService("StarterGui")
local Lighting         = game:GetService("Lighting")

local lp  = Players.LocalPlayer
local gui = lp:WaitForChild("PlayerGui")

-- Remover instância antiga
pcall(function()
    local old = gui:FindFirstChild("MillieHub_v3")
    if old then old:Destroy() end
end)

-- ════════════════════════════════════════════════════
-- [2] PERSONAGEM
-- ════════════════════════════════════════════════════
local char, hrp, hum, animator

local function RefreshChar(c)
    char     = c or lp.Character or lp.CharacterAdded:Wait()
    hrp      = char:WaitForChild("HumanoidRootPart", 10)
    hum      = char:WaitForChild("Humanoid", 10)
    animator = hum:FindFirstChildOfClass("Animator")
end
RefreshChar()
lp.CharacterAdded:Connect(function(c)
    task.wait(0.5)
    RefreshChar(c)
end)

-- ════════════════════════════════════════════════════
-- [3] CONFIG
-- ════════════════════════════════════════════════════
local CFG = {
    -- Senha
    Password = "Millielover",

    -- Imagem da Millie (Helluva Boss)
    -- Coloque aqui o ID da imagem do Roblox: rbxassetid://SEU_ID_AQUI
    -- Ex: "rbxassetid://123456789"
    MillieImageID = "",  -- deixe vazio para usar design em texto

    -- Cores (Vermelho Escuro + Dourado)
    C = {
        bg       = Color3.fromRGB(8, 0, 0),
        panel    = Color3.fromRGB(22, 3, 3),
        card     = Color3.fromRGB(35, 6, 6),
        cardH    = Color3.fromRGB(50, 8, 8),
        primary  = Color3.fromRGB(110, 5, 5),
        accent   = Color3.fromRGB(150, 0, 0),
        border   = Color3.fromRGB(255, 205, 0),
        bord2    = Color3.fromRGB(210, 145, 0),
        bord3    = Color3.fromRGB(160, 90, 0),
        text     = Color3.fromRGB(255, 240, 210),
        sub      = Color3.fromRGB(185, 125, 55),
        on       = Color3.fromRGB(255, 190, 0),
        off      = Color3.fromRGB(50, 7, 7),
        warn     = Color3.fromRGB(255, 95, 95),
        ok       = Color3.fromRGB(90, 255, 110),
        info     = Color3.fromRGB(90, 170, 255),
    },

    -- Farm
    HitboxRange  = 25,
    AttackMin    = 0.08,
    AttackMax    = 0.16,
    QuestMin     = 1.0,
    QuestMax     = 1.8,
    TpMin        = 0.18,
    TpMax        = 0.38,
    RetreatHP    = 20,

    -- Toggles
    AutoFarm    = false,
    KillAura    = false,
    AutoQuest   = false,
    AutoBoss    = false,
    AutoDungeon = false,
    AutoSkills  = false,
    AutoBlock   = false,
    MobTP       = false,
    AutoCollect = false,
    AutoFishing = false,
    AutoMine    = false,
    AutoMeteor  = false,
    AutoHaki    = false,
    AutoPrestige= false,
    AutoStats   = false,
    AntiAFK     = true,
    HitboxOn    = false,
    AutoEquip   = false,
    AutoDaily   = false,
    Noclip      = false,
    ESPMobs     = false,
    WalkSpeed   = 16,
    JumpPower   = 50,
    StatPriority = {"Strength", "Defense", "Weapon", "Ability"},

    -- Estado interno
    _status   = "😴 Idle",
    _hp       = "100%",
    _level    = "1",
    _kills    = 0,
    _questPrg = "0/0",
}

-- ════════════════════════════════════════════════════
-- [4] UTILITÁRIOS
-- ════════════════════════════════════════════════════
local function RNG(a, b) return a + math.random() * (b - a) end
local function LN(a, b, t) return a + (b - a) * t end
local function Wait(a, b) task.wait(RNG(a or 0.1, b or 0.3)) end

local function Tween(obj, t, props, style, dir)
    pcall(function()
        local tw = TweenService:Create(obj,
            TweenInfo.new(t or 0.25, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
        tw:Play()
    end)
end

local function Notify(title, msg, dur)
    pcall(StarterGui.SetCore, StarterGui, "SendNotification", {
        Title = "🔴 " .. title, Text = msg, Duration = dur or 3,
    })
end

local function Dist2D(a, b)
    return (Vector3.new(a.X,0,a.Z) - Vector3.new(b.X,0,b.Z)).Magnitude
end

local function GetHPPct()
    if hum then return math.floor((hum.Health / math.max(hum.MaxHealth,1)) * 100) end
    return 100
end

local function GetLevel()
    local ls = lp:FindFirstChild("leaderstats")
    if ls then
        for _, v in ipairs(ls:GetChildren()) do
            if v.Name:lower():find("lv") or v.Name:lower():find("level") then
                return tostring(v.Value)
            end
        end
    end
    -- Tenta ler do GUI do jogo
    for _, v in ipairs(gui:GetDescendants()) do
        if v:IsA("TextLabel") then
            local n = v.Name:lower()
            if n:find("level") or n:find("lv") or n:find("nivel") then
                local num = v.Text:match("%d+")
                if num then return num end
            end
        end
    end
    return "?"
end

-- Cache de remotes
local _remCache = {}
local function FindRemote(name)
    if _remCache[name] then
        if _remCache[name].Parent then return _remCache[name] end
        _remCache[name] = nil
    end
    local lo = name:lower()
    local function scan(parent)
        if not parent then return nil end
        for _, v in ipairs(parent:GetDescendants()) do
            if (v:IsA("RemoteEvent") or v:IsA("RemoteFunction")) and v.Name:lower():find(lo) then
                _remCache[name] = v
                return v
            end
        end
    end
    return scan(ReplicatedStorage) or scan(workspace)
end

-- ════════════════════════════════════════════════════
-- [5] STATUS BAR (atualiza periodicamente)
-- ════════════════════════════════════════════════════
local StatusLabel = nil  -- será definido na UI

local function UpdateStatus()
    CFG._hp    = GetHPPct() .. "%"
    CFG._level = GetLevel()
    if StatusLabel and StatusLabel.Parent then
        StatusLabel.Text = string.format(
            "⚡ %s   ❤️ %s   ✦ Lv%s   💀 %d kills",
            CFG._status, CFG._hp, CFG._level, CFG._kills
        )
    end
end

task.spawn(function()
    while true do
        task.wait(0.5)
        pcall(UpdateStatus)
    end
end)

-- ════════════════════════════════════════════════════
-- [6] BOTÃO DE ATAQUE "BATER" (FIX PRINCIPAL)
-- ════════════════════════════════════════════════════
-- O Legacy Piece usa botão mobile "Bater" para atacar.
-- Simular esse botão = dano real, como se o jogador clicasse.

local _attackBtn = nil
local _attackNames = {
    "bater", "attack", "attackbutton", "hit", "m1", "m1button",
    "basicattack", "punch", "strike", "combat",
}

local function FindAttackButton()
    if _attackBtn and _attackBtn.Parent then return _attackBtn end
    _attackBtn = nil

    for _, v in ipairs(gui:GetDescendants()) do
        if v:IsA("TextButton") or v:IsA("ImageButton") then
            local text = v:IsA("TextButton") and v.Text:lower() or ""
            local name = v.Name:lower()
            for _, keyword in ipairs(_attackNames) do
                if text == keyword or name == keyword or name:find(keyword) then
                    _attackBtn = v
                    return v
                end
            end
        end
    end
    return nil
end

local function DoAttack()
    -- Método 1: Simula botão "Bater" do jogo
    local btn = FindAttackButton()
    if btn then
        pcall(function()
            btn.MouseButton1Down:Fire()
            task.wait(0.04)
            btn.MouseButton1Up:Fire()
        end)
        return true
    end

    -- Método 2: firetouchinterest na hitbox auxiliar (ver seção 7)
    -- (executado automaticamente pela hitbox Part)

    -- Método 3: RemoteEvents de combate
    pcall(function()
        for _, key in ipairs({"Attack","Hit","Combat","Damage","BasicAttack","M1"}) do
            local re = FindRemote(key)
            if re and re:IsA("RemoteEvent") then
                re:FireServer()
            end
        end
    end)

    return false
end

local function DoBlock(enable)
    -- Busca botão de bloqueio
    for _, v in ipairs(gui:GetDescendants()) do
        if v:IsA("TextButton") or v:IsA("ImageButton") then
            local t = v:IsA("TextButton") and v.Text:lower() or ""
            local n = v.Name:lower()
            if t == "bloqueio" or t == "block" or n:find("block") or n:find("bloquei") then
                pcall(function()
                    if enable then
                        v.MouseButton1Down:Fire()
                    else
                        v.MouseButton1Up:Fire()
                    end
                end)
                return
            end
        end
    end
end

-- ════════════════════════════════════════════════════
-- [7] HITBOX EXPANDER v2 (SEM BUG NO CHÃO)
-- ════════════════════════════════════════════════════
-- FIX: Cria uma Part separada, invisível, weldada ao HRP.
-- NÃO expande o HumanoidRootPart (isso causava o bug).

local _hbPart = nil

local function ApplyHitbox(enable)
    -- Remove hitbox antiga se existir
    if _hbPart then pcall(function() _hbPart:Destroy() end) end
    _hbPart = nil

    if not enable then return end
    if not hrp or not char then return end

    -- Cria Part de hitbox auxiliar
    local hb = Instance.new("Part")
    hb.Name         = "_MillieHitbox"
    hb.Size         = Vector3.new(CFG.HitboxRange, CFG.HitboxRange, CFG.HitboxRange)
    hb.CanCollide   = false   -- Sem colisão física = sem bug no chão
    hb.Anchored     = false
    hb.Transparency = 1       -- Invisível
    hb.CastShadow   = false
    hb.CanQuery     = false
    hb.CFrame       = hrp.CFrame
    hb.Parent       = char
    _hbPart         = hb

    -- Welda ao HRP para seguir o personagem
    local weld = Instance.new("WeldConstraint")
    weld.Part0  = hrp
    weld.Part1  = hb
    weld.Parent = hb

    -- Mantém firetouchinterest em todos os mobs dentro da range
    task.spawn(function()
        while _hbPart and _hbPart.Parent and CFG.HitboxOn do
            task.wait(0.1)
            pcall(function()
                for _, v in ipairs(workspace:GetDescendants()) do
                    if v:IsA("Model") and v ~= char then
                        local h2 = v:FindFirstChildOfClass("Humanoid")
                        if h2 and h2.Health > 0 and not Players:GetPlayerFromCharacter(v) then
                            local root = v:FindFirstChild("HumanoidRootPart") or v.PrimaryPart
                            if root and hrp and Dist2D(hrp.Position, root.Position) <= CFG.HitboxRange then
                                firetouchinterest(_hbPart, root, 0)
                                task.wait(0.01)
                                firetouchinterest(_hbPart, root, 1)
                            end
                        end
                    end
                end
            end)
        end
    end)
end

-- Reaplica ao spawnar
lp.CharacterAdded:Connect(function(c)
    task.wait(2)
    if CFG.HitboxOn then ApplyHitbox(true) end
end)

-- ════════════════════════════════════════════════════
-- [8] DETECÇÃO DE MOBS
-- ════════════════════════════════════════════════════
local function GetNearestMob(range, nameFilter)
    if not hrp then return nil end
    local best, bestD = nil, range or CFG.HitboxRange

    for _, v in ipairs(workspace:GetDescendants()) do
        if v:IsA("Model") and v ~= char then
            local h2 = v:FindFirstChildOfClass("Humanoid")
            if h2 and h2.Health > 0 and not Players:GetPlayerFromCharacter(v) then
                local root = v:FindFirstChild("HumanoidRootPart") or v.PrimaryPart
                if root then
                    local d = Dist2D(hrp.Position, root.Position)
                    if d < bestD then
                        if not nameFilter or v.Name:lower():find(nameFilter:lower()) then
                            best, bestD = v, d
                        end
                    end
                end
            end
        end
    end
    return best
end

local function GetAllMobs(range)
    local list = {}
    if not hrp then return list end
    for _, v in ipairs(workspace:GetDescendants()) do
        if v:IsA("Model") and v ~= char then
            local h2 = v:FindFirstChildOfClass("Humanoid")
            if h2 and h2.Health > 0 and not Players:GetPlayerFromCharacter(v) then
                local root = v:FindFirstChild("HumanoidRootPart") or v.PrimaryPart
                if root and Dist2D(hrp.Position, root.Position) <= (range or CFG.HitboxRange) then
                    table.insert(list, v)
                end
            end
        end
    end
    return list
end

-- ════════════════════════════════════════════════════
-- [9] TELEPORTE SEM BUG
-- ════════════════════════════════════════════════════
local function SafeTP(cf, yOff)
    if not hrp then return end
    local dest = cf * CFrame.new(0, yOff or 3.5, 0)
    hrp.Anchored = true
    task.wait(0.04)
    hrp.CFrame = dest
    task.wait(0.06)
    hrp.CFrame = dest  -- double-set
    task.wait(0.04)
    hrp.Anchored = false
    Wait(CFG.TpMin, CFG.TpMax)
end

local function TPBeside(mob)
    if not mob or not hrp then return end
    local root = mob:FindFirstChild("HumanoidRootPart") or mob.PrimaryPart
    if not root then return end
    local dir = (hrp.Position - root.Position)
    dir = dir.Magnitude > 0 and dir.Unit or Vector3.new(1,0,0)
    SafeTP(CFrame.new(root.Position + dir * 6), 0)
end

-- ════════════════════════════════════════════════════
-- [10] MOB TELEPORT (traz mobs até você)
-- ════════════════════════════════════════════════════
task.spawn(function()
    while true do
        task.wait(0.4)
        if CFG.MobTP and hrp then
            pcall(function()
                for _, v in ipairs(workspace:GetDescendants()) do
                    if v:IsA("Model") and v ~= char then
                        local h2 = v:FindFirstChildOfClass("Humanoid")
                        if h2 and h2.Health > 0 and not Players:GetPlayerFromCharacter(v) then
                            local root = v:FindFirstChild("HumanoidRootPart") or v.PrimaryPart
                            if root then
                                local d = Dist2D(hrp.Position, root.Position)
                                if d > 10 and d < 800 then
                                    -- TP mob para perto do jogador
                                    root.CFrame = hrp.CFrame * CFrame.new(RNG(-8,8), 0, RNG(-8,8))
                                end
                            end
                        end
                    end
                end
            end)
        end
    end
end)

-- ════════════════════════════════════════════════════
-- [11] AUTO QUEST SYSTEM (detecta progresso 0/5)
-- ════════════════════════════════════════════════════
local function GetQuestProgress()
    -- Varre o GUI procurando "X/Y" (progresso de quest)
    for _, v in ipairs(gui:GetDescendants()) do
        if v:IsA("TextLabel") or v:IsA("TextBox") then
            local curr, max = v.Text:match("(%d+)/(%d+)")
            if curr and max then
                return tonumber(curr), tonumber(max)
            end
        end
    end
    return 0, 0
end

local function IsQuestComplete()
    local curr, max = GetQuestProgress()
    if max and max > 0 then
        CFG._questPrg = curr .. "/" .. max
        return curr >= max
    end
    return false
end

local function HasActiveQuest()
    -- Checa se tem missão ativa no GUI
    for _, v in ipairs(gui:GetDescendants()) do
        if v:IsA("TextLabel") then
            local t = v.Text:lower()
            if t:find("derrote") or t:find("kill") or t:find("missão") or t:find("quest") then
                return true
            end
        end
    end
    return false
end

-- NPCs de quest por nível
local QUEST_NPCS = {
    {name="Shanks",         minLv=0,   island="Starter"},
    {name="Sarah",          minLv=1,   island="Fusha"},
    {name="Woop Slap",      minLv=5,   island="Fusha"},
    {name="Freight Agent",  minLv=15,  island="Alvida"},
    {name="Koby",           minLv=15,  island="Alvida"},
    {name="Zoro",           minLv=25,  island="Shells Town"},
    {name="Rika",           minLv=25,  island="Shells Town"},
    {name="Archaeologist",  minLv=40,  island="Shimotsuki"},
    {name="Noodle",         minLv=50,  island="Orange Town"},
    {name="Boro",           minLv=50,  island="Orange Town"},
    {name="Zeff",           minLv=65,  island="Baratie"},
    {name="Bariat",         minLv=80,  island="Mink Island"},
    {name="Genzo",          minLv=95,  island="Arlong Park"},
    {name="Son Goku",       minLv=100, island="Namek Island"},
    {name="Rob Lucci",      minLv=250, island="Dandadan Island"},
    {name="Ken Takakura",   minLv=250, island="Dandadan Island"},
    {name="Satoru Gojo",    minLv=600, island="Jujutsu Academy"},
    {name="Shadow Warden",  minLv=1200,island="Hollow Island"},
    {name="Chihiro",        minLv=2000,island="Ruin City"},
}

local function FindNPC(npcName)
    local lo = npcName:lower()
    for _, v in ipairs(workspace:GetDescendants()) do
        if v:IsA("Model") and v.Name:lower():find(lo) then
            local root = v:FindFirstChild("HumanoidRootPart")
                      or v.PrimaryPart
                      or v:FindFirstChildOfClass("BasePart")
            if root then return v, root end
        end
    end
    return nil, nil
end

local function InteractNPC(npcModel)
    if not npcModel then return end
    local root = npcModel:FindFirstChild("HumanoidRootPart") or npcModel.PrimaryPart
    if not root then return end
    SafeTP(root.CFrame * CFrame.new(3, 0, 3), 0)
    task.wait(0.3)
    pcall(function()
        local cd = root:FindFirstChildOfClass("ClickDetector")
            or npcModel:FindFirstChildOfClass("ClickDetector")
        if cd then fireclickdetector(cd) end
    end)
    task.wait(0.2)
    pcall(function()
        for _, pp in ipairs(npcModel:GetDescendants()) do
            if pp:IsA("ProximityPrompt") then
                fireproximityprompt(pp)
                task.wait(0.1)
            end
        end
    end)
    task.wait(0.3)
end

local function AcceptOrSubmitQuest()
    task.wait(0.4)
    -- Busca botões de aceitar/entregar quest no GUI
    local keywords = {
        "accept", "aceitar", "aceite", "confirm", "ok",
        "entregar", "submit", "claim", "resgatar", "pegar",
        "start", "iniciar", "complete",
    }
    for _, sg in ipairs(gui:GetDescendants()) do
        if sg:IsA("TextButton") or sg:IsA("ImageButton") then
            local t = sg:IsA("TextButton") and sg.Text:lower() or ""
            local n = sg.Name:lower()
            for _, kw in ipairs(keywords) do
                if t:find(kw) or n:find(kw) then
                    pcall(function()
                        sg.MouseButton1Down:Fire()
                        task.wait(0.05)
                        sg.MouseButton1Up:Fire()
                        sg.Activated:Fire()
                    end)
                    task.wait(0.2)
                    break
                end
            end
        end
    end
end

local function RunQuestCycle()
    if not CFG.AutoQuest then return end
    local lv = tonumber(GetLevel()) or 0
    local bestNPC = nil
    for _, npc in ipairs(QUEST_NPCS) do
        if lv >= npc.minLv then bestNPC = npc end
    end
    if not bestNPC then return end

    -- Se quest completa, entregar
    if IsQuestComplete() then
        CFG._status = "📜 Entregando Quest"
        local m, r = FindNPC(bestNPC.name)
        if m then
            InteractNPC(m)
            AcceptOrSubmitQuest()
            Wait(1, 1.5)
        end
    end

    -- Aceitar nova quest
    if not HasActiveQuest() then
        CFG._status = "📜 Aceitando Quest"
        local m, r = FindNPC(bestNPC.name)
        if m then
            InteractNPC(m)
            AcceptOrSubmitQuest()
            Wait(CFG.QuestMin, CFG.QuestMax)
        end
    end
end

-- ════════════════════════════════════════════════════
-- [12] FARM LOOP PRINCIPAL (com ataque real)
-- ════════════════════════════════════════════════════
local farmThread = nil
local questTimer = 0

local function MainFarmLoop()
    questTimer = 0
    while CFG.AutoFarm do
        task.wait(0.05)

        -- HP crítico: respawnar
        local hp = GetHPPct()
        CFG._hp = hp .. "%"
        if hp < CFG.RetreatHP and hum then
            CFG._status = "⚠️ HP Baixo! Respawnando..."
            if CFG.AutoBlock then DoBlock(false) end
            hum.Health = 0
            task.wait(4)
            RefreshChar()
            task.wait(2)
            if CFG.HitboxOn then ApplyHitbox(true) end
        end

        -- Quest cycle a cada 25s
        questTimer = questTimer + 0.05
        if questTimer >= 25 then
            questTimer = 0
            task.spawn(RunQuestCycle)
        end

        -- Ataque
        if CFG.KillAura then
            -- Kill Aura: ataca TODOS os mobs em range
            CFG._status = "⚔️ Kill Aura"
            local mobs = GetAllMobs(CFG.HitboxRange)
            if #mobs > 0 then
                DoAttack()
                -- firetouchinterest em todos
                pcall(function()
                    for _, mob in ipairs(mobs) do
                        local root = mob:FindFirstChild("HumanoidRootPart") or mob.PrimaryPart
                        if root and hrp then
                            if _hbPart then
                                firetouchinterest(_hbPart, root, 0)
                                firetouchinterest(_hbPart, root, 1)
                            end
                            firetouchinterest(hrp, root, 0)
                            firetouchinterest(hrp, root, 1)
                        end
                    end
                end)
                Wait(CFG.AttackMin, CFG.AttackMax)
            else
                task.wait(0.2)
            end
        else
            -- Farm normal: foca um mob por vez
            local mob = GetNearestMob(CFG.HitboxRange)
            if not mob then
                CFG._status = "🔍 Procurando mob..."
                task.wait(0.3)
            else
                CFG._status = "⚔️ Farmando"
                local h2 = mob:FindFirstChildOfClass("Humanoid")
                local root = mob:FindFirstChild("HumanoidRootPart") or mob.PrimaryPart

                -- Se longe, aproximar
                if root and hrp and Dist2D(hrp.Position, root.Position) > 10 then
                    TPBeside(mob)
                    task.wait(0.2)
                end

                -- Atacar até morrer
                local tries = 0
                while CFG.AutoFarm and h2 and h2.Health > 0 and tries < 500 do
                    tries = tries + 1

                    -- Auto Block entre ataques
                    if CFG.AutoBlock then DoBlock(true) end

                    DoAttack()

                    -- firetouchinterest complementar
                    if root and hrp then
                        pcall(function()
                            if _hbPart then
                                firetouchinterest(_hbPart, root, 0)
                                task.wait(0.01)
                                firetouchinterest(_hbPart, root, 1)
                            end
                            firetouchinterest(hrp, root, 0)
                            task.wait(0.01)
                            firetouchinterest(hrp, root, 1)
                        end)
                    end

                    if CFG.AutoBlock then DoBlock(false) end

                    -- Auto Skills
                    if CFG.AutoSkills then
                        pcall(function()
                            for _, key in ipairs({"UseSkill","Skill","Ability","Power"}) do
                                local re = FindRemote(key)
                                if re and re:IsA("RemoteEvent") then re:FireServer() end
                            end
                        end)
                    end

                    Wait(CFG.AttackMin, CFG.AttackMax)

                    if GetHPPct() < CFG.RetreatHP then break end
                end

                -- Conta kill
                if h2 and h2.Health <= 0 then
                    CFG._kills = CFG._kills + 1
                end
            end
        end
    end
    CFG._status = "😴 Idle"
end

-- ════════════════════════════════════════════════════
-- [13] AUTO COLLECT DROPS
-- ════════════════════════════════════════════════════
task.spawn(function()
    while true do
        task.wait(0.8)
        if CFG.AutoCollect and hrp then
            pcall(function()
                local dropNames = {"drop","reward","chest","caixa","item","loot","coin","beli","berry","xp"}
                for _, v in ipairs(workspace:GetDescendants()) do
                    local n = v.Name:lower()
                    local isPart = v:IsA("BasePart") or v:IsA("Model")
                    if isPart then
                        for _, kw in ipairs(dropNames) do
                            if n:find(kw) then
                                local part = v:IsA("Model") and (v.PrimaryPart or v:FindFirstChildOfClass("BasePart")) or v
                                if part and Dist2D(hrp.Position, part.Position) < 200 then
                                    SafeTP(part.CFrame, 1)
                                    local cd = part:FindFirstChildOfClass("ClickDetector")
                                    if cd then fireclickdetector(cd) end
                                    for _, pp in ipairs(v:IsA("Model") and v:GetDescendants() or {}) do
                                        if pp:IsA("ProximityPrompt") then fireproximityprompt(pp) end
                                    end
                                    task.wait(0.3)
                                end
                                break
                            end
                        end
                    end
                end
            end)
        end
    end
end)

-- ════════════════════════════════════════════════════
-- [14] AUTO BOSS
-- ════════════════════════════════════════════════════
local BOSSES = {
    "Higuma","Alvida","Axe-Hand Morgan","Buggy","Don Krieg",
    "Wolfam","Saw Shark Arlong","Yeti","Piccolo",
    "Turbo Granny","Shadow Warden","Crimson Owl","One Eyed Owl",
}

task.spawn(function()
    while true do
        task.wait(2)
        if CFG.AutoBoss then
            pcall(function()
                CFG._status = "👹 Auto Boss"
                for _, bn in ipairs(BOSSES) do
                    local bm = FindNPC(bn)
                    if bm then
                        local h2 = bm:FindFirstChildOfClass("Humanoid")
                        if h2 and h2.Health > 0 then
                            local t0 = tick()
                            while CFG.AutoBoss and h2 and h2.Health > 0 and tick()-t0 < 90 do
                                local root = bm:FindFirstChild("HumanoidRootPart") or bm.PrimaryPart
                                if root and hrp and Dist2D(hrp.Position, root.Position) > 8 then
                                    TPBeside(bm)
                                end
                                DoAttack()
                                if root and hrp then
                                    pcall(function()
                                        firetouchinterest(hrp, root, 0)
                                        firetouchinterest(hrp, root, 1)
                                    end)
                                end
                                Wait(CFG.AttackMin, CFG.AttackMax)
                            end
                        end
                    end
                end
            end)
        end
    end
end)

-- ════════════════════════════════════════════════════
-- [15] AUTO DUNGEON
-- ════════════════════════════════════════════════════
local DungeonDiff = "Easy"

task.spawn(function()
    while true do
        task.wait(5)
        if CFG.AutoDungeon then
            pcall(function()
                CFG._status = "🏯 Auto Dungeon"
                local re = FindRemote("Dungeon") or FindRemote("EnterDungeon")
                if re then re:FireServer(DungeonDiff) task.wait(2) end
                local t0 = tick()
                while CFG.AutoDungeon and tick()-t0 < 180 do
                    local mob = GetNearestMob(80)
                    if mob then
                        local h2 = mob:FindFirstChildOfClass("Humanoid")
                        while mob and h2 and h2.Health > 0 do
                            DoAttack()
                            Wait(CFG.AttackMin, CFG.AttackMax)
                        end
                    else task.wait(1) end
                end
            end)
        end
    end
end)

-- ════════════════════════════════════════════════════
-- [16] AUTO FISHING
-- ════════════════════════════════════════════════════
task.spawn(function()
    while true do
        task.wait(0.5)
        if CFG.AutoFishing then
            pcall(function()
                CFG._status = "🎣 Fishing"
                local re = FindRemote("Fish") or FindRemote("CastRod") or FindRemote("Fishing")
                if re then
                    re:FireServer("Cast")
                    task.wait(RNG(2.5, 4.5))
                    re:FireServer("Reel")
                    task.wait(1)
                end
            end)
        end
    end
end)

-- ════════════════════════════════════════════════════
-- [17] AUTO MINING / METEOR
-- ════════════════════════════════════════════════════
task.spawn(function()
    while true do
        task.wait(0.8)
        if (CFG.AutoMine or CFG.AutoMeteor) and hrp then
            pcall(function()
                local mineKw   = {"ore","rock","mine","crystal","gem","mineral"}
                local meteorKw = {"meteor","meteorite","fragment"}
                for _, v in ipairs(workspace:GetDescendants()) do
                    local n = v.Name:lower()
                    local checkKw = CFG.AutoMine and mineKw or {}
                    if CFG.AutoMeteor then for _, k in ipairs(meteorKw) do table.insert(checkKw, k) end end
                    for _, kw in ipairs(checkKw) do
                        if n:find(kw) then
                            local part = v:IsA("Model") and (v.PrimaryPart or v:FindFirstChildOfClass("BasePart")) or v
                            if part and part:IsA("BasePart") then
                                SafeTP(part.CFrame, 3)
                                task.wait(0.3)
                                local cd = part:FindFirstChildOfClass("ClickDetector")
                                if cd then fireclickdetector(cd) end
                                for _, pp in ipairs(v:IsA("Model") and v:GetDescendants() or {}) do
                                    if pp:IsA("ProximityPrompt") then fireproximityprompt(pp) end
                                end
                                task.wait(0.5)
                            end
                            break
                        end
                    end
                end
            end)
        end
    end
end)

-- ════════════════════════════════════════════════════
-- [18] AUTO HAKI
-- ════════════════════════════════════════════════════
task.spawn(function()
    while true do
        task.wait(2.5)
        if CFG.AutoHaki then
            pcall(function()
                for _, key in ipairs({"ArmamentHaki","Haki","MantraHaki","ObservationHaki","ConquerorHaki"}) do
                    local re = FindRemote(key)
                    if re and re:IsA("RemoteEvent") then re:FireServer() task.wait(0.2) end
                end
            end)
        end
    end
end)

-- ════════════════════════════════════════════════════
-- [19] AUTO STATS
-- ════════════════════════════════════════════════════
task.spawn(function()
    while true do
        task.wait(5)
        if CFG.AutoStats then
            pcall(function()
                local re = FindRemote("AddStat") or FindRemote("UpgradeStat") or FindRemote("StatUp")
                if re then
                    for _, stat in ipairs(CFG.StatPriority) do
                        for _ = 1, 20 do re:FireServer(stat) task.wait(0.08) end
                    end
                end
            end)
        end
    end
end)

-- ════════════════════════════════════════════════════
-- [20] AUTO EQUIP
-- ════════════════════════════════════════════════════
task.spawn(function()
    while true do
        task.wait(5)
        if CFG.AutoEquip then
            pcall(function()
                local re = FindRemote("EquipBest") or FindRemote("AutoEquip") or FindRemote("EquipItem")
                if re then re:FireServer() end
            end)
        end
    end
end)

-- ════════════════════════════════════════════════════
-- [21] ESP DE MOBS (highlight visual)
-- ════════════════════════════════════════════════════
local _espHighlights = {}

local function ClearESP()
    for _, h in ipairs(_espHighlights) do pcall(function() h:Destroy() end) end
    _espHighlights = {}
end

task.spawn(function()
    while true do
        task.wait(0.5)
        if CFG.ESPMobs then
            -- Adiciona highlight em mobs que não têm
            for _, v in ipairs(workspace:GetDescendants()) do
                if v:IsA("Model") and v ~= char then
                    local h2 = v:FindFirstChildOfClass("Humanoid")
                    if h2 and h2.Health > 0 and not Players:GetPlayerFromCharacter(v) then
                        if not v:FindFirstChild("_MillieESP") then
                            local hl = Instance.new("SelectionBox")
                            hl.Name = "_MillieESP"
                            hl.Color3 = CFG.C.border
                            hl.SurfaceColor3 = Color3.fromRGB(255, 100, 0)
                            hl.SurfaceTransparency = 0.7
                            hl.LineThickness = 0.04
                            hl.Adornee = v
                            hl.Parent = v
                            table.insert(_espHighlights, hl)
                        end
                    end
                end
            end
        else
            if #_espHighlights > 0 then ClearESP() end
        end
    end
end)

-- ════════════════════════════════════════════════════
-- [22] ANTI-AFK
-- ════════════════════════════════════════════════════
task.spawn(function()
    while true do
        task.wait(55 + RNG(0, 10))
        if CFG.AntiAFK and hum then
            pcall(function()
                hum:Move(Vector3.new(RNG(-1,1),0,RNG(-1,1)).Unit, false)
                task.wait(0.2)
                hum:Move(Vector3.new(0,0,0), false)
            end)
        end
    end
end)

-- ════════════════════════════════════════════════════
-- [23] NOCLIP
-- ════════════════════════════════════════════════════
RunService.Stepped:Connect(function()
    if CFG.Noclip and char then
        for _, p in ipairs(char:GetDescendants()) do
            if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" then
                p.CanCollide = false
            end
        end
    end
end)

-- ════════════════════════════════════════════════════
-- [24] WALK SPEED / JUMP
-- ════════════════════════════════════════════════════
RunService.Heartbeat:Connect(function()
    if hum then
        if CFG.WalkSpeed ~= 16 then hum.WalkSpeed = CFG.WalkSpeed end
        if CFG.JumpPower ~= 50 then hum.JumpPower = CFG.JumpPower end
    end
end)

-- ════════════════════════════════════════════════════
-- [25] ANTI-DETECÇÃO
-- ════════════════════════════════════════════════════
task.spawn(function()
    while true do
        task.wait(30 + RNG(0, 15))
        CFG.AttackMin = 0.07 + RNG(0, 0.04)
        CFG.AttackMax = 0.15 + RNG(0, 0.06)
    end
end)

-- ════════════════════════════════════════════════════
-- [26] UI — CONSTRUTORES
-- ════════════════════════════════════════════════════
local function NewI(cls, props, parent)
    local i = Instance.new(cls)
    for k,v in pairs(props or {}) do i[k]=v end
    if parent then i.Parent = parent end
    return i
end

local function AddCorner(p, r)
    return NewI("UICorner", {CornerRadius=UDim.new(0, r or 8)}, p)
end

local function AddStroke(p, col, th)
    local s = NewI("UIStroke", {
        Color=col or CFG.C.border,
        Thickness=th or 1.5,
        ApplyStrokeMode=Enum.ApplyStrokeMode.Border,
    }, p)
    return s
end

local function AddPad(p, px, py)
    return NewI("UIPadding",{
        PaddingLeft=UDim.new(0,px or 8), PaddingRight=UDim.new(0,px or 8),
        PaddingTop=UDim.new(0,py or 6),  PaddingBottom=UDim.new(0,py or 4),
    }, p)
end

local function AddList(p, gap, dir)
    return NewI("UIListLayout",{
        Padding=UDim.new(0, gap or 5),
        FillDirection=dir or Enum.FillDirection.Vertical,
        HorizontalAlignment=Enum.HorizontalAlignment.Center,
        SortOrder=Enum.SortOrder.LayoutOrder,
    }, p)
end

local function MkFrame(parent, props)
    local f = Instance.new("Frame")
    f.BackgroundColor3 = CFG.C.panel
    f.BorderSizePixel  = 0
    for k,v in pairs(props or {}) do f[k]=v end
    f.Parent = parent
    return f
end

local function MkLabel(parent, text, props)
    local l = Instance.new("TextLabel")
    l.BackgroundTransparency = 1
    l.Font       = Enum.Font.GothamBold
    l.TextSize   = 12
    l.TextColor3 = CFG.C.text
    l.Text       = text or ""
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.TextWrapped    = true
    for k,v in pairs(props or {}) do l[k]=v end
    l.Parent = parent
    return l
end

local function MkButton(parent, text, props)
    local b = Instance.new("TextButton")
    b.BackgroundColor3 = CFG.C.primary
    b.TextColor3  = CFG.C.border
    b.Font        = Enum.Font.GothamBold
    b.TextSize    = 12
    b.BorderSizePixel = 0
    b.AutoButtonColor = false
    b.Text        = text or "Button"
    for k,v in pairs(props or {}) do b[k]=v end
    b.Parent = parent
    AddCorner(b, 8)
    AddStroke(b, CFG.C.bord2, 1)

    -- Efeitos de toque
    b.MouseEnter:Connect(function() Tween(b, 0.1, {BackgroundColor3 = CFG.C.accent}) end)
    b.MouseLeave:Connect(function() Tween(b, 0.1, {BackgroundColor3 = CFG.C.primary}) end)
    b.MouseButton1Down:Connect(function() Tween(b, 0.07, {BackgroundColor3 = CFG.C.border, TextColor3 = CFG.C.bg}) end)
    b.MouseButton1Up:Connect(function() Tween(b, 0.1, {BackgroundColor3 = CFG.C.accent, TextColor3 = CFG.C.border}) end)
    return b
end

local function MkScroll(parent, props)
    local sf = Instance.new("ScrollingFrame")
    sf.BackgroundTransparency = 1
    sf.ScrollBarThickness     = 3
    sf.ScrollBarImageColor3   = CFG.C.bord2
    sf.CanvasSize             = UDim2.new(0,0,0,0)
    sf.AutomaticCanvasSize    = Enum.AutomaticSize.Y
    sf.ScrollingDirection     = Enum.ScrollingDirection.Y
    for k,v in pairs(props or {}) do sf[k]=v end
    sf.Parent = parent
    AddList(sf, 5)
    AddPad(sf, 8, 8)
    return sf
end

-- Toggle profissional
local function MkToggle(parent, text, default, onChange)
    local row = MkFrame(parent, {
        Size=UDim2.new(1,0,0,42),
        BackgroundColor3=CFG.C.card,
    })
    AddCorner(row, 8)
    AddStroke(row, Color3.fromRGB(80, 20, 0), 0.8)

    -- Gradiente no card
    local g = Instance.new("UIGradient")
    g.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(50, 8, 8)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(30, 4, 4)),
    })
    g.Rotation = 90
    g.Parent   = row

    MkLabel(row, text, {
        Size=UDim2.new(0.65,0,1,0),
        Position=UDim2.new(0,10,0,0),
        TextSize=12, TextColor3=CFG.C.text,
    })

    local track = MkFrame(row, {
        Size=UDim2.new(0,50,0,26),
        Position=UDim2.new(1,-58,0.5,-13),
        BackgroundColor3=CFG.C.off,
    })
    AddCorner(track, 13)
    AddStroke(track, CFG.C.bord3, 1)

    local ball = MkFrame(track, {
        Size=UDim2.new(0,20,0,20),
        Position=UDim2.new(0,3,0.5,-10),
        BackgroundColor3=Color3.fromRGB(220,185,130),
    })
    AddCorner(ball, 10)

    local isOn = false

    local function Set(v, silent)
        isOn = v
        if isOn then
            Tween(track, 0.22, {BackgroundColor3 = CFG.C.on})
            Tween(ball,  0.22, {Position=UDim2.new(0,27,0.5,-10), BackgroundColor3=Color3.fromRGB(10,2,2)})
            Tween(row,   0.2,  {BackgroundColor3=Color3.fromRGB(50,15,5)})
        else
            Tween(track, 0.22, {BackgroundColor3 = CFG.C.off})
            Tween(ball,  0.22, {Position=UDim2.new(0,3,0.5,-10), BackgroundColor3=Color3.fromRGB(220,185,130)})
            Tween(row,   0.2,  {BackgroundColor3=CFG.C.card})
        end
        if not silent and onChange then onChange(isOn) end
    end

    local function OnInp(inp)
        if inp.UserInputType == Enum.UserInputType.Touch
        or inp.UserInputType == Enum.UserInputType.MouseButton1 then
            Set(not isOn)
        end
    end
    track.InputBegan:Connect(OnInp)
    row.InputBegan:Connect(OnInp)

    if default then task.defer(function() Set(true, true) end) end
    return row, Set
end

-- Separador decorativo com ícone
local function MkSep(parent, label)
    local f = MkFrame(parent, {
        Size=UDim2.new(1,0,0, label and 26 or 1),
        BackgroundTransparency = label and 1 or 0.6,
        BackgroundColor3 = CFG.C.bord2,
    })
    if label then
        MkLabel(f, " ─── " .. label .. " ───", {
            Size=UDim2.new(1,0,1,0),
            TextSize=10,
            TextColor3=CFG.C.bord2,
            TextXAlignment=Enum.TextXAlignment.Left,
            Font=Enum.Font.GothamBlack,
        })
    end
    return f
end

-- Header de seção colorido
local function MkHead(parent, text, col)
    local f = MkFrame(parent, {
        Size=UDim2.new(1,0,0,30),
        BackgroundColor3=col or Color3.fromRGB(100,10,0),
    })
    AddCorner(f, 8)
    local stroke = AddStroke(f, CFG.C.border, 1)
    local g = Instance.new("UIGradient")
    g.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, col or Color3.fromRGB(120,10,0)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(50,3,3)),
    })
    g.Rotation = 0
    g.Parent   = f
    MkLabel(f, text, {
        Size=UDim2.new(1,0,1,0),
        Position=UDim2.new(0,10,0,0),
        TextSize=11,
        TextColor3=CFG.C.border,
        Font=Enum.Font.GothamBlack,
        TextXAlignment=Enum.TextXAlignment.Left,
    })
    return f
end

-- Slider numérico
local function MkSlider(parent, label, val, step, minV, maxV, onChange)
    local row = MkFrame(parent, {
        Size=UDim2.new(1,0,0,42),
        BackgroundColor3=CFG.C.card,
    })
    AddCorner(row, 8)
    AddStroke(row, Color3.fromRGB(70,15,0), 0.8)

    local lbl = MkLabel(row, label .. ":  " .. val, {
        Size=UDim2.new(0.6,0,1,0),
        Position=UDim2.new(0,10,0,0),
        TextSize=11, TextColor3=CFG.C.text,
    })

    local mn = MkButton(row, "−", {
        Size=UDim2.new(0,32,0,26), Position=UDim2.new(0.63,0,0.5,-13),
        TextSize=15,
    })
    local pl = MkButton(row, "+", {
        Size=UDim2.new(0,32,0,26), Position=UDim2.new(0.63,38,0.5,-13),
        TextSize=15,
    })

    mn.Activated:Connect(function()
        val = math.max(minV, val - step)
        lbl.Text = label .. ":  " .. val
        if onChange then onChange(val) end
    end)
    pl.Activated:Connect(function()
        val = math.min(maxV, val + step)
        lbl.Text = label .. ":  " .. val
        if onChange then onChange(val) end
    end)
    return row
end

-- ════════════════════════════════════════════════════
-- [27] SCREENGU I
-- ════════════════════════════════════════════════════
local SG = NewI("ScreenGui", {
    Name="MillieHub_v3",
    ResetOnSpawn=false,
    ZIndexBehavior=Enum.ZIndexBehavior.Sibling,
    IgnoreGuiInset=true,
    DisplayOrder=999,
}, gui)

-- ════════════════════════════════════════════════════
-- [28] TELA DE BOAS-VINDAS + SENHA
-- ════════════════════════════════════════════════════
local WelcomeScreen = MkFrame(SG, {
    Name="WelcomeScreen",
    Size=UDim2.new(1,0,1,0),
    Position=UDim2.new(0,0,0,0),
    BackgroundColor3=Color3.fromRGB(4,0,0),
    ZIndex=20,
})

-- Gradiente de fundo
local wGrad = Instance.new("UIGradient")
wGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0,   Color3.fromRGB(14,0,0)),
    ColorSequenceKeypoint.new(0.5, Color3.fromRGB(40,2,2)),
    ColorSequenceKeypoint.new(1,   Color3.fromRGB(14,0,0)),
})
wGrad.Rotation = 135
wGrad.Parent   = WelcomeScreen

-- Partículas animadas
task.spawn(function()
    local dots = {}
    for _ = 1, 22 do
        local d = MkFrame(WelcomeScreen, {
            Size=UDim2.new(0, RNG(2,5), 0, RNG(2,5)),
            Position=UDim2.new(RNG(0,0.95),0,RNG(0,0.95),0),
            BackgroundColor3=CFG.C.border,
            BackgroundTransparency=RNG(0.3,0.75),
            ZIndex=21,
        })
        AddCorner(d, 3)
        table.insert(dots, d)
    end
    while WelcomeScreen.Parent do
        for _, d in ipairs(dots) do
            pcall(function()
                Tween(d, RNG(0.8, 2.0), {BackgroundTransparency=RNG(0.1,0.9)})
            end)
        end
        task.wait(1.2)
    end
end)

-- Card central (maior e mais bonito)
local WCard = MkFrame(WelcomeScreen, {
    Name="WCard",
    Size=UDim2.new(0,320,0,440),
    AnchorPoint=Vector2.new(0.5,0.5),
    Position=UDim2.new(0.5,0,0.5,0),
    BackgroundColor3=CFG.C.panel,
    ZIndex=22,
})
AddCorner(WCard, 18)
local wStroke = AddStroke(WCard, CFG.C.border, 2)

-- Stroke pulsante no card
task.spawn(function()
    local t = 0
    while WelcomeScreen.Parent do
        t = t + 0.05
        local a = (math.sin(t * 2) + 1) / 2
        wStroke.Thickness = LN(1.5, 3.5, a)
        wStroke.Color = Color3.fromRGB(math.floor(LN(190,255,a)), math.floor(LN(110,205,a)), 0)
        task.wait(0.05)
    end
end)

-- Header do card (bloco colorido com título)
local WHeader = MkFrame(WCard, {
    Size=UDim2.new(1,0,0,80),
    Position=UDim2.new(0,0,0,0),
    BackgroundColor3=CFG.C.primary,
    ZIndex=23,
})
local hCorner = AddCorner(WHeader, 18)
MkFrame(WHeader, {   -- corrige cantos inferiores
    Size=UDim2.new(1,0,0,18), Position=UDim2.new(0,0,1,-18),
    BackgroundColor3=CFG.C.primary, ZIndex=23,
})
local hGrad = Instance.new("UIGradient")
hGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(150,5,5)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(80,0,0)),
})
hGrad.Rotation = 0
hGrad.Parent   = WHeader

-- Foto da Millie (se tiver ID) ou banner de texto
if CFG.MillieImageID ~= "" then
    local img = Instance.new("ImageLabel")
    img.Image  = CFG.MillieImageID
    img.Size   = UDim2.new(0, 60, 0, 60)
    img.Position = UDim2.new(0, 10, 0.5, -30)
    img.BackgroundTransparency = 1
    img.ZIndex = 24
    img.Parent = WHeader
end

NewI("TextLabel", {
    Text  = "✦ MILLIE HUB ✦",
    Size  = UDim2.new(1,-10,0,36),
    Position = UDim2.new(0,5,0,10),
    BackgroundTransparency=1,
    Font  = Enum.Font.GothamBlack,
    TextSize=20,
    TextColor3=CFG.C.border,
    TextXAlignment=Enum.TextXAlignment.Center,
    ZIndex=24,
}, WHeader)

NewI("TextLabel", {
    Text="Legacy Piece · Mobile Hub · v3.0",
    Size=UDim2.new(1,0,0,20),
    Position=UDim2.new(0,0,0,42),
    BackgroundTransparency=1,
    Font=Enum.Font.Gotham,
    TextSize=10,
    TextColor3=CFG.C.sub,
    TextXAlignment=Enum.TextXAlignment.Center,
    ZIndex=24,
}, WHeader)

-- Texto animado (typewriter)
local WText = NewI("TextLabel",{
    Text="",
    Size=UDim2.new(1,-20,0,65),
    Position=UDim2.new(0,10,0,90),
    BackgroundTransparency=1,
    Font=Enum.Font.Gotham,
    TextSize=12,
    TextColor3=CFG.C.text,
    TextXAlignment=Enum.TextXAlignment.Center,
    TextWrapped=true,
    ZIndex=23,
}, WCard)

-- Linha dividers
MkFrame(WCard, {Size=UDim2.new(0.9,0,0,1), Position=UDim2.new(0.05,0,0,164), BackgroundColor3=CFG.C.bord3, BackgroundTransparency=0.4, ZIndex=23})

-- Label senha
NewI("TextLabel",{
    Text="🔒  Senha de Acesso:",
    Size=UDim2.new(1,-20,0,22),
    Position=UDim2.new(0,10,0,174),
    BackgroundTransparency=1,
    Font=Enum.Font.GothamBold,
    TextSize=11,
    TextColor3=CFG.C.sub,
    TextXAlignment=Enum.TextXAlignment.Left,
    ZIndex=23,
}, WCard)

-- Input de senha
local PwBox = NewI("TextBox",{
    PlaceholderText="Digite a senha...",
    Text="", TextColor3=CFG.C.text,
    PlaceholderColor3=CFG.C.sub,
    BackgroundColor3=CFG.C.bg,
    Font=Enum.Font.Gotham,
    TextSize=13,
    Size=UDim2.new(1,-20,0,44),
    Position=UDim2.new(0,10,0,200),
    BorderSizePixel=0,
    ClearTextOnFocus=true,
    ZIndex=23,
}, WCard)
AddCorner(PwBox, 10)
AddStroke(PwBox, CFG.C.border, 1.5)

-- Botão entrar
local SubmitBtn = MkButton(WCard, "▶  ENTRAR", {
    Size=UDim2.new(1,-20,0,46),
    Position=UDim2.new(0,10,0,254),
    Font=Enum.Font.GothamBlack,
    TextSize=14,
    ZIndex=23,
})
AddStroke(SubmitBtn, CFG.C.border, 1.5)

-- Crédito + erro
local ErrLbl = NewI("TextLabel",{
    Text="",
    Size=UDim2.new(1,-20,0,22),
    Position=UDim2.new(0,10,0,308),
    BackgroundTransparency=1,
    Font=Enum.Font.GothamBold,
    TextSize=11,
    TextColor3=CFG.C.warn,
    TextXAlignment=Enum.TextXAlignment.Center,
    ZIndex=23,
}, WCard)

NewI("TextLabel",{
    Text="made with ♥ for dj  ·  MILLIE HUB v3.0",
    Size=UDim2.new(1,0,0,22),
    Position=UDim2.new(0,0,0,410),
    BackgroundTransparency=1,
    Font=Enum.Font.Gotham,
    TextSize=9,
    TextColor3=CFG.C.sub,
    TextXAlignment=Enum.TextXAlignment.Center,
    ZIndex=23,
}, WCard)

-- Typewriter
task.spawn(function()
    local full = "Bem-vindo a MILLIE HUB HEH!...~\n\nO hub mais completo do Legacy Piece.\nFarm, Quest, Hitbox, ESP e muito mais 💛"
    task.wait(0.5)
    for i = 1, #full do
        if not WelcomeScreen.Parent then break end
        WText.Text = string.sub(full, 1, i)
        task.wait(0.038)
    end
end)

-- ════════════════════════════════════════════════════
-- [29] MAIN HUB (maior e mais completo)
-- ════════════════════════════════════════════════════
local Hub = MkFrame(SG, {
    Name="Hub",
    Size=UDim2.new(0,400,0,540),
    AnchorPoint=Vector2.new(0.5,0.5),
    Position=UDim2.new(0.5,0,0.5,0),
    BackgroundColor3=CFG.C.panel,
    Visible=false,
    ZIndex=10,
})
AddCorner(Hub, 14)
local hubStroke = AddStroke(Hub, CFG.C.border, 1.8)

-- Stroke animado
task.spawn(function()
    local t = 0
    while Hub.Parent do
        t = t + 0.025
        local a = (math.sin(t) + 1) / 2
        hubStroke.Color = Color3.fromRGB(math.floor(LN(195,255,a)), math.floor(LN(95,205,a)), 0)
        task.wait(0.03)
    end
end)

-- ── TOP BAR ──
local TopBar = MkFrame(Hub, {
    Size=UDim2.new(1,0,0,46),
    BackgroundColor3=CFG.C.primary,
    ZIndex=11,
})
AddCorner(TopBar, 14)
MkFrame(TopBar, {Size=UDim2.new(1,0,0,14), Position=UDim2.new(0,0,1,-14), BackgroundColor3=CFG.C.primary, ZIndex=11})
local tbGrad = Instance.new("UIGradient")
tbGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(150,5,5)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(80,0,0)),
})
tbGrad.Rotation = 0
tbGrad.Parent   = TopBar

NewI("TextLabel",{
    Text="✦ MILLIE HUB",
    Size=UDim2.new(0.55,0,1,0),
    Position=UDim2.new(0,12,0,0),
    BackgroundTransparency=1,
    Font=Enum.Font.GothamBlack,
    TextSize=15,
    TextColor3=CFG.C.border,
    TextXAlignment=Enum.TextXAlignment.Left,
    ZIndex=12,
}, TopBar)

local MinBtn = MkButton(TopBar, "—", {
    Size=UDim2.new(0,30,0,26),
    AnchorPoint=Vector2.new(1,0.5),
    Position=UDim2.new(1,-8,0.5,0),
    BackgroundColor3=Color3.fromRGB(50,5,5),
    TextColor3=CFG.C.border,
    TextSize=13,
    ZIndex=12,
})

-- ── STATUS BAR ──
local StatusBar = MkFrame(Hub, {
    Size=UDim2.new(1,0,0,22),
    Position=UDim2.new(0,0,0,46),
    BackgroundColor3=CFG.C.bg,
    ZIndex=11,
})
StatusLabel = NewI("TextLabel",{
    Text="⚡ Idle   ❤️ 100%   ✦ Lv1   💀 0 kills",
    Size=UDim2.new(1,-8,1,0),
    Position=UDim2.new(0,4,0,0),
    BackgroundTransparency=1,
    Font=Enum.Font.Gotham,
    TextSize=9,
    TextColor3=CFG.C.sub,
    TextXAlignment=Enum.TextXAlignment.Left,
    TextTruncate=Enum.TextTruncate.AtEnd,
    ZIndex=12,
}, StatusBar)

-- ── DRAG ──
do
    local dragging, dragInput, dragStart, startPos = false
    TopBar.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1
        or inp.UserInputType == Enum.UserInputType.Touch then
            dragging=true dragStart=inp.Position startPos=Hub.Position
            inp.Changed:Connect(function()
                if inp.UserInputState == Enum.UserInputState.End then dragging=false end
            end)
        end
    end)
    TopBar.InputChanged:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseMovement
        or inp.UserInputType == Enum.UserInputType.Touch then
            dragInput=inp
        end
    end)
    UserInputService.InputChanged:Connect(function(inp)
        if inp==dragInput and dragging then
            local d = inp.Position - dragStart
            Tween(Hub,0.06,{Position=UDim2.new(startPos.X.Scale,startPos.X.Offset+d.X,startPos.Y.Scale,startPos.Y.Offset+d.Y)},Enum.EasingStyle.Linear)
        end
    end)
end

-- ── TABS ──
local TABS = {
    {icon="⚔️", name="Farm"},
    {icon="📜", name="Quest"},
    {icon="🌀", name="TP"},
    {icon="👤", name="Player"},
    {icon="⚙️", name="Misc"},
    {icon="🔧", name="Debug"},
}

local TabBar = MkFrame(Hub, {
    Size=UDim2.new(1,0,0,36),
    Position=UDim2.new(0,0,0,68),
    BackgroundColor3=CFG.C.bg,
    ZIndex=11,
})

local TabBtns, TabConts = {}, {}
local ActiveTab = nil
local wPerTab = 1 / #TABS

for i, tab in ipairs(TABS) do
    local tbtn = NewI("TextButton",{
        Text=tab.icon,
        Size=UDim2.new(wPerTab,-1,1,0),
        Position=UDim2.new(wPerTab*(i-1),0,0,0),
        BackgroundColor3=CFG.C.bg,
        TextColor3=CFG.C.sub,
        Font=Enum.Font.GothamBold,
        TextSize=14,
        BorderSizePixel=0,
        AutoButtonColor=false,
        ZIndex=12,
    }, TabBar)

    NewI("TextLabel",{
        Text=tab.name,
        Size=UDim2.new(1,0,0,10),
        Position=UDim2.new(0,0,1,-11),
        BackgroundTransparency=1,
        Font=Enum.Font.Gotham,
        TextSize=7,
        TextColor3=CFG.C.sub,
        TextXAlignment=Enum.TextXAlignment.Center,
        ZIndex=13,
    }, tbtn)

    local ind = MkFrame(tbtn, {
        Size=UDim2.new(0.65,0,0,2),
        AnchorPoint=Vector2.new(0.5,1),
        Position=UDim2.new(0.5,0,1,0),
        BackgroundColor3=CFG.C.border,
        BackgroundTransparency=1,
        ZIndex=13,
    })

    local cont = MkFrame(Hub, {
        Size=UDim2.new(1,0,1,-108),
        Position=UDim2.new(0,0,0,108),
        BackgroundColor3=CFG.C.panel,
        Visible=false,
        ZIndex=11,
    })
    local scroll = MkScroll(cont, {Size=UDim2.new(1,0,1,0), ZIndex=12})

    TabBtns[i]  = {btn=tbtn, ind=ind}
    TabConts[i] = {cont=cont, scroll=scroll}

    tbtn.Activated:Connect(function()
        if ActiveTab == i then return end
        if ActiveTab then
            TabConts[ActiveTab].cont.Visible = false
            Tween(TabBtns[ActiveTab].btn, 0.15, {BackgroundColor3=CFG.C.bg, TextColor3=CFG.C.sub})
            TabBtns[ActiveTab].ind.BackgroundTransparency = 1
        end
        ActiveTab = i
        TabConts[i].cont.Visible = true
        Tween(tbtn, 0.15, {BackgroundColor3=CFG.C.card, TextColor3=CFG.C.border})
        ind.BackgroundTransparency = 0
    end)
end

-- ════════════════════════════════════════════════════
-- [30] CONTEÚDO DAS ABAS
-- ════════════════════════════════════════════════════

-- ─── ABA 1: FARM ───
do
    local sc = TabConts[1].scroll

    MkHead(sc, "⚔️  COMBATE AUTOMÁTICO", Color3.fromRGB(120,5,0))

    MkToggle(sc, "⚔️  Auto Farm (TP + Ataque)", false, function(v)
        CFG.AutoFarm = v
        if v then
            if farmThread then task.cancel(farmThread) end
            farmThread = task.spawn(MainFarmLoop)
            Notify("MILLIE HUB", "⚔️ Auto Farm ATIVADO!", 3)
        else
            if farmThread then task.cancel(farmThread) end
            CFG._status = "😴 Idle"
            Notify("MILLIE HUB", "Auto Farm desativado.", 2)
        end
    end)

    MkToggle(sc, "🌀  Kill Aura (ataca todos em volta)", false, function(v)
        CFG.KillAura = v
        if v and not CFG.AutoFarm then
            CFG.AutoFarm = true
            if farmThread then task.cancel(farmThread) end
            farmThread = task.spawn(MainFarmLoop)
        end
        Notify("MILLIE HUB", "Kill Aura: " .. (v and "ON" or "OFF"), 2)
    end)

    MkToggle(sc, "📡  Mob TP (traz mobs até você)", false, function(v)
        CFG.MobTP = v
        Notify("MILLIE HUB", "Mob TP: " .. (v and "ON" or "OFF"), 2)
    end)

    MkToggle(sc, "🛡️  Auto Block (entre ataques)", false, function(v)
        CFG.AutoBlock = v
    end)

    MkToggle(sc, "⚡  Auto Skills (Q/E/R/T)", false, function(v)
        CFG.AutoSkills = v
    end)

    MkToggle(sc, "👹  Auto Boss Farm", false, function(v)
        CFG.AutoBoss = v
        Notify("MILLIE HUB", "Auto Boss: " .. (v and "ON" or "OFF"), 2)
    end)

    MkToggle(sc, "💎  Auto Collect Drops", false, function(v)
        CFG.AutoCollect = v
    end)

    MkSep(sc)
    MkHead(sc, "🎯  HITBOX RANGE (NÃO BUGA MAIS)", Color3.fromRGB(90,30,0))

    MkToggle(sc, "📐  Expandir Hitbox (Part Separada)", false, function(v)
        CFG.HitboxOn = v
        ApplyHitbox(v)
        Notify("MILLIE HUB", "Hitbox: " .. (v and "ATIVO " .. CFG.HitboxRange .. "st" or "OFF"), 3)
    end)

    MkSlider(sc, "Range (studs)", CFG.HitboxRange, 5, 5, 120, function(val)
        CFG.HitboxRange = val
        if CFG.HitboxOn then ApplyHitbox(true) end
    end)

    MkSep(sc)
    MkHead(sc, "👁️  ESP", Color3.fromRGB(0,50,80))

    MkToggle(sc, "🔍  ESP Mobs (highlight)", false, function(v)
        CFG.ESPMobs = v
        if not v then ClearESP() end
        Notify("MILLIE HUB", "ESP Mobs: " .. (v and "ON" or "OFF"), 2)
    end)

    MkSep(sc)
    MkHead(sc, "🛡️  SEGURANÇA", Color3.fromRGB(80,0,80))

    MkSlider(sc, "Recuar com HP%", CFG.RetreatHP, 5, 0, 80, function(val)
        CFG.RetreatHP = val
    end)

    MkToggle(sc, "🔄  Anti-AFK", true, function(v) CFG.AntiAFK = v end)
end

-- ─── ABA 2: QUEST ───
do
    local sc = TabConts[2].scroll

    MkHead(sc, "📜  MISSÕES AUTOMÁTICAS", Color3.fromRGB(80,60,0))

    MkToggle(sc, "📋  Auto Quest (detecta progresso)", false, function(v)
        CFG.AutoQuest = v
        Notify("MILLIE HUB", "Auto Quest: " .. (v and "ON" or "OFF"), 2)
    end)

    -- Status da quest atual
    local qStatusLbl = MkLabel(sc, "Quest: aguardando...", {
        Size=UDim2.new(1,0,0,22),
        TextSize=10, TextColor3=CFG.C.info,
        TextXAlignment=Enum.TextXAlignment.Center,
    })

    task.spawn(function()
        while qStatusLbl.Parent do
            task.wait(0.5)
            pcall(function()
                local c, m = GetQuestProgress()
                if m and m > 0 then
                    local pct = math.floor((c/m)*100)
                    qStatusLbl.Text = string.format("Quest: %d/%d (%d%%) %s",
                        c, m, pct, c >= m and "✓ COMPLETA!" or "")
                    qStatusLbl.TextColor3 = c >= m and CFG.C.ok or CFG.C.info
                else
                    qStatusLbl.Text = "Quest: sem missão ativa"
                    qStatusLbl.TextColor3 = CFG.C.sub
                end
            end)
        end
    end)

    local forceBtn = MkButton(sc, "▶  Forçar Ciclo de Quest Agora", {Size=UDim2.new(1,0,0,36)})
    forceBtn.Activated:Connect(function()
        task.spawn(RunQuestCycle)
        Notify("Quest", "Ciclo forçado!", 2)
    end)

    MkToggle(sc, "🏅  Auto Prestige Quest", false, function(v) CFG.AutoPrestige = v end)
    MkToggle(sc, "📅  Auto Daily/Weekly Quest", false, function(v) CFG.AutoDaily = v end)

    MkSep(sc)
    MkHead(sc, "🏯  AUTO DUNGEON", Color3.fromRGB(0,50,80))

    MkToggle(sc, "🏯  Auto Dungeon", false, function(v)
        CFG.AutoDungeon = v
        Notify("MILLIE HUB", "Auto Dungeon: " .. (v and "ON" or "OFF"), 2)
    end)

    local diffs = {"Easy", "Medium", "Hard", "Extreme"}
    local diffIdx = 1
    local diffLbl = MkLabel(sc, "Dificuldade: " .. diffs[diffIdx], {
        Size=UDim2.new(1,0,0,22), TextSize=11,
        TextXAlignment=Enum.TextXAlignment.Center, TextColor3=CFG.C.sub,
    })
    local diffBtn = MkButton(sc, "🔄  Trocar Dificuldade", {Size=UDim2.new(1,0,0,34)})
    diffBtn.Activated:Connect(function()
        diffIdx = diffIdx % #diffs + 1
        DungeonDiff = diffs[diffIdx]
        diffLbl.Text = "Dificuldade: " .. diffs[diffIdx]
    end)

    MkSep(sc)
    MkHead(sc, "👹  BOSS RÁPIDO", Color3.fromRGB(100,0,50))

    for _, bn in ipairs({"Higuma","Alvida","Buggy","Don Krieg","Saw Shark Arlong","Yeti","Piccolo"}) do
        local b = MkButton(sc, "💀  " .. bn, {Size=UDim2.new(1,0,0,32), TextSize=11})
        b.Activated:Connect(function()
            local m, r = FindNPC(bn)
            if m and r then TPBeside(m) Notify("Boss", "Indo a " .. bn, 2)
            else Notify("Boss", bn .. " não encontrado!", 2) end
        end)
    end
end

-- ─── ABA 3: TELEPORTE ───
do
    local sc = TabConts[3].scroll

    MkHead(sc, "🌍  TELEPORTE - ILHAS", Color3.fromRGB(0,60,30))

    local islands = {
        {name="Starter Island",    cf=CFrame.new(0,100,0)},
        {name="Fusha Island",      cf=CFrame.new(500,100,200)},
        {name="Alvida Island",     cf=CFrame.new(900,100,400)},
        {name="Shells Town",       cf=CFrame.new(1400,100,100)},
        {name="Shimotsuki Island", cf=CFrame.new(1800,100,-300)},
        {name="Orange Town",       cf=CFrame.new(2200,100,500)},
        {name="Baratie",           cf=CFrame.new(2600,100,200)},
        {name="Mink Island",       cf=CFrame.new(3000,100,600)},
        {name="Arlong Park",       cf=CFrame.new(3400,100,0)},
        {name="Namek Island",      cf=CFrame.new(4000,100,-500)},
        {name="Dandadan Island",   cf=CFrame.new(5000,100,300)},
        {name="Jujutsu Academy",   cf=CFrame.new(6000,100,-200)},
        {name="Karakura Island",   cf=CFrame.new(7000,100,400)},
        {name="Legacy Island",     cf=CFrame.new(8000,100,0)},
        {name="Hollow Island",     cf=CFrame.new(9500,100,-600)},
        {name="Ruin City",         cf=CFrame.new(11000,100,200)},
    }

    for _, isl in ipairs(islands) do
        local b = MkButton(sc, "🗺  " .. isl.name, {Size=UDim2.new(1,0,0,32), TextSize=11})
        b.Activated:Connect(function()
            Notify("TP", "→ " .. isl.name, 2)
            local found = false
            for _, v in ipairs(workspace:GetDescendants()) do
                if (v:IsA("SpawnLocation") or v:IsA("Model")) and v.Name:lower():find(isl.name:lower():sub(1,5)) then
                    local part = v:IsA("Model") and (v.PrimaryPart or v:FindFirstChildOfClass("BasePart")) or v
                    if part then SafeTP(part.CFrame,5) found=true break end
                end
            end
            if not found then SafeTP(isl.cf, 5) end
        end)
    end

    MkSep(sc)
    MkHead(sc, "🧑  NPCs", Color3.fromRGB(0,60,30))

    for _, n in ipairs({"Shanks","Son Goku","Rob Lucci","Satoru Gojo","Prestige NPC","Sovereign","Trait Roll NPC","Fruit Roll NPC","Koyuki","Miner","Chihiro","Shadow Warden"}) do
        local b = MkButton(sc, "👤  " .. n, {Size=UDim2.new(1,0,0,32), TextSize=11})
        b.Activated:Connect(function()
            local m, r = FindNPC(n)
            if m and r then SafeTP(r.CFrame*CFrame.new(3,0,3),0) Notify("NPC", "→ " .. n, 2)
            else Notify("NPC", n .. " não encontrado.", 2) end
        end)
    end
end

-- ─── ABA 4: PLAYER ───
do
    local sc = TabConts[4].scroll

    MkHead(sc, "📊  ATRIBUTOS", Color3.fromRGB(0,50,100))

    MkToggle(sc, "📊  Auto Distribuir Stats", false, function(v)
        CFG.AutoStats = v
        Notify("Stats", "Auto Stats: " .. (v and "ON" or "OFF"), 2)
    end)

    MkSep(sc)
    MkHead(sc, "🌊  HAKI + EQUIPAMENTO", Color3.fromRGB(0,50,100))

    MkToggle(sc, "🌊  Auto Haki (Arm. + Obs. + Conq.)", false, function(v) CFG.AutoHaki = v end)
    MkToggle(sc, "🎒  Auto Equipar Melhor Item", false, function(v) CFG.AutoEquip = v end)

    MkSep(sc)
    MkHead(sc, "🎲  AUTO REROLL", Color3.fromRGB(50,0,80))

    local rerolls = {
        {"Fruit Reroll",    "FruitReroll"},
        {"Race Reroll",     "RaceReroll"},
        {"Trait Reroll",    "TraitReroll"},
        {"Potential Reroll","PotentialReroll"},
        {"Enhancement",     "Enhancement"},
        {"Gacha Roll",      "Gacha"},
    }
    for _, rr in ipairs(rerolls) do
        local b = MkButton(sc, "🎰  " .. rr[1], {Size=UDim2.new(1,0,0,32), TextSize=11})
        b.Activated:Connect(function()
            pcall(function()
                local re = FindRemote(rr[2])
                if re then re:FireServer() end
            end)
            Notify("Reroll", rr[1] .. " disparado!", 2)
        end)
    end

    MkSep(sc)
    MkHead(sc, "🏅  PRESTIGE", Color3.fromRGB(80,50,0))

    MkToggle(sc, "⬆️  Auto Prestige Quest", false, function(v) CFG.AutoPrestige = v end)

    local pBtn = MkButton(sc, "⬆️  Prestige Manual (1x)", {Size=UDim2.new(1,0,0,34)})
    pBtn.Activated:Connect(function()
        pcall(function()
            local re = FindRemote("Prestige") or FindRemote("Ascend")
            if re then re:FireServer() Notify("Prestige", "Prestige disparado!", 3) end
        end)
    end)
end

-- ─── ABA 5: MISC ───
do
    local sc = TabConts[5].scroll

    MkHead(sc, "🎣  FISHING & MINE", Color3.fromRGB(0,60,60))

    MkToggle(sc, "🎣  Auto Fishing", false, function(v) CFG.AutoFishing = v end)
    MkToggle(sc, "⛏️  Auto Mining", false, function(v) CFG.AutoMine = v end)
    MkToggle(sc, "☄️  Auto Meteor", false, function(v) CFG.AutoMeteor = v end)

    MkSep(sc)
    MkHead(sc, "⚡  MOVIMENTO", Color3.fromRGB(0,80,30))

    MkSlider(sc, "Walk Speed", CFG.WalkSpeed, 4, 16, 200, function(val)
        CFG.WalkSpeed = val
        if hum then hum.WalkSpeed = val end
    end)

    MkSlider(sc, "Jump Power", CFG.JumpPower, 10, 50, 500, function(val)
        CFG.JumpPower = val
        if hum then hum.JumpPower = val end
    end)

    MkToggle(sc, "👻  Noclip", false, function(v)
        CFG.Noclip = v
        if not v and char then
            for _, p in ipairs(char:GetDescendants()) do
                if p:IsA("BasePart") then p.CanCollide = true end
            end
        end
    end)

    MkSep(sc)
    MkHead(sc, "🎁  CÓDIGOS", Color3.fromRGB(80,30,0))

    local cBox = NewI("TextBox",{
        PlaceholderText="Digite o código...", Text="",
        TextColor3=CFG.C.text, PlaceholderColor3=CFG.C.sub,
        BackgroundColor3=CFG.C.bg,
        Font=Enum.Font.Gotham, TextSize=12,
        Size=UDim2.new(1,0,0,38), BorderSizePixel=0,
        ZIndex=13,
    }, sc)
    AddCorner(cBox,8) AddStroke(cBox, CFG.C.border, 1)

    local redBtn = MkButton(sc, "🎁  Resgatar Código", {Size=UDim2.new(1,0,0,34)})
    redBtn.Activated:Connect(function()
        local code = cBox.Text
        if code == "" then return end
        pcall(function()
            local re = FindRemote("RedeemCode") or FindRemote("Code") or FindRemote("UseCode")
            if re then re:FireServer(code) Notify("Código", "'" .. code .. "' enviado!", 3) end
        end)
    end)

    MkSep(sc)
    MkHead(sc, "🔄  SERVER", Color3.fromRGB(50,50,0))

    local rjBtn = MkButton(sc, "🔁  Rejoin", {Size=UDim2.new(1,0,0,34)})
    rjBtn.Activated:Connect(function()
        game:GetService("TeleportService"):Teleport(game.PlaceId, lp)
    end)

    local copyBtn = MkButton(sc, "📋  Copiar Server ID", {Size=UDim2.new(1,0,0,34)})
    copyBtn.Activated:Connect(function()
        pcall(function()
            setclipboard(game.JobId)
            Notify("Server", "ID copiado!", 2)
        end)
    end)
end

-- ─── ABA 6: DEBUG ───
do
    local sc = TabConts[6].scroll

    MkHead(sc, "🔧  DEBUG & INFO", Color3.fromRGB(50,50,50))

    -- Info em tempo real
    local infoLbl = MkLabel(sc, "", {
        Size=UDim2.new(1,0,0,80),
        TextSize=9, TextColor3=CFG.C.sub,
        TextXAlignment=Enum.TextXAlignment.Left,
        TextWrapped=true,
        Font=Enum.Font.Code,
    })
    task.spawn(function()
        while infoLbl.Parent do
            task.wait(1)
            pcall(function()
                local atk = FindAttackButton()
                local c, m = GetQuestProgress()
                infoLbl.Text = string.format(
                    "Botão 'Bater': %s\nHitbox Part: %s\nQuest: %d/%d\nMob mais próx: %s\nAnti-AFK: %s\nKills: %d\nCharacter: %s",
                    atk and "✓ " .. atk.Name or "✗ não encontrado",
                    _hbPart and "✓ ativa" or "✗ inativa",
                    c or 0, m or 0,
                    GetNearestMob(500) and GetNearestMob(500).Name or "nenhum",
                    CFG.AntiAFK and "ON" or "OFF",
                    CFG.._kills,
                    char and char.Name or "nil"
                )
            end)
        end
    end)

    MkSep(sc)

    -- Scan de botões do jogo
    local scanBtn = MkButton(sc, "🔍  Escanear Botões do Jogo", {Size=UDim2.new(1,0,0,34)})
    local scanResult = MkLabel(sc, "Clique para escanear...", {
        Size=UDim2.new(1,0,0,120),
        TextSize=8, TextColor3=CFG.C.sub,
        TextXAlignment=Enum.TextXAlignment.Left,
        TextWrapped=true, Font=Enum.Font.Code,
    })
    scanBtn.Activated:Connect(function()
        local found = {}
        for _, v in ipairs(gui:GetDescendants()) do
            if v:IsA("TextButton") then
                local t = v.Text
                if t ~= "" and #t < 40 then
                    table.insert(found, v.Name .. "='" .. t .. "'")
                end
            end
        end
        scanResult.Text = "Botões:\n" .. table.concat(found, "\n")
        scanResult.Size = UDim2.new(1,0,0, math.max(120, #found * 14))
    end)

    -- Scan remotes
    local remBtn = MkButton(sc, "📡  Escanear RemoteEvents", {Size=UDim2.new(1,0,0,34)})
    local remResult = MkLabel(sc, "Clique para escanear...", {
        Size=UDim2.new(1,0,0,120),
        TextSize=8, TextColor3=CFG.C.info,
        TextXAlignment=Enum.TextXAlignment.Left,
        TextWrapped=true, Font=Enum.Font.Code,
    })
    remBtn.Activated:Connect(function()
        local found = {}
        for _, v in ipairs(ReplicatedStorage:GetDescendants()) do
            if v:IsA("RemoteEvent") or v:IsA("RemoteFunction") then
                table.insert(found, v.Name)
            end
        end
        remResult.Text = "Remotes:\n" .. table.concat(found, "\n")
        remResult.Size = UDim2.new(1,0,0, math.max(120, #found * 14))
    end)

    MkSep(sc)
    MkHead(sc, "⚠️  FORÇAR ATAQUE MANUAL", Color3.fromRGB(100,0,0))

    local forceAtk = MkButton(sc, "💥  Testar Ataque (1x)", {Size=UDim2.new(1,0,0,34)})
    local atkResult = MkLabel(sc, "...", {Size=UDim2.new(1,0,0,22), TextSize=10, TextColor3=CFG.C.ok, TextXAlignment=Enum.TextXAlignment.Center})
    forceAtk.Activated:Connect(function()
        local ok = DoAttack()
        atkResult.Text = ok and "✓ Botão 'Bater' encontrado e disparado!" or "⚠ Usando fallback (Remote/Touch)"
    end)
end

-- ════════════════════════════════════════════════════
-- [31] BOTÃO JV (Bubble)
-- ════════════════════════════════════════════════════
local JV = NewI("TextButton",{
    Text="jv",
    Size=UDim2.new(0,58,0,58),
    Position=UDim2.new(0,10,0.55,0),
    AnchorPoint=Vector2.new(0,0.5),
    BackgroundColor3=CFG.C.primary,
    TextColor3=CFG.C.border,
    Font=Enum.Font.GothamBlack,
    TextSize=18,
    BorderSizePixel=0,
    AutoButtonColor=false,
    ZIndex=30,
}, SG)
AddCorner(JV, 29)
AddStroke(JV, CFG.C.border, 2.5)

-- Pulso do JV
task.spawn(function()
    local t = 0
    while JV.Parent do
        t = t + 0.05
        local a = (math.sin(t * 2.5) + 1) / 2
        JV.BackgroundColor3 = Color3.fromRGB(math.floor(LN(80,145,a)), 0, 0)
        task.wait(0.05)
    end
end)

-- Drag + tap no JV
do
    local dragging, moved = false, false
    local dragStart, startPos

    JV.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1
        or inp.UserInputType == Enum.UserInputType.Touch then
            dragging=true moved=false
            dragStart=inp.Position startPos=JV.Position
        end
    end)
    UserInputService.InputChanged:Connect(function(inp)
        if dragging and (inp.UserInputType == Enum.UserInputType.MouseMovement
                      or inp.UserInputType == Enum.UserInputType.Touch) then
            local d = inp.Position - dragStart
            if d.Magnitude > 6 then
                moved = true
                JV.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset+d.X,
                                         startPos.Y.Scale, startPos.Y.Offset+d.Y)
            end
        end
    end)
    UserInputService.InputEnded:Connect(function(inp)
        if dragging and (inp.UserInputType == Enum.UserInputType.MouseButton1
                      or inp.UserInputType == Enum.UserInputType.Touch) then
            dragging = false
            if not moved then
                if Hub.Visible then
                    Tween(Hub, 0.2, {Size=UDim2.new(0,0,0,0)}, Enum.EasingStyle.Back, Enum.EasingDirection.In)
                    task.wait(0.22)
                    Hub.Visible = false
                    Hub.Size = UDim2.new(0,400,0,540)
                else
                    Hub.Visible = true
                    Hub.Size = UDim2.new(0,0,0,0)
                    Tween(Hub, 0.38, {Size=UDim2.new(0,400,0,540)}, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
                    -- Ativa aba 1 se não tiver aba ativa
                    if not ActiveTab then
                        TabBtns[1].btn.Activated:Fire()
                    end
                end
            end
        end
    end)
end

-- Minimizar
MinBtn.Activated:Connect(function()
    Tween(Hub, 0.2, {Size=UDim2.new(0,0,0,0)}, Enum.EasingStyle.Back, Enum.EasingDirection.In)
    task.wait(0.22)
    Hub.Visible = false
    Hub.Size = UDim2.new(0,400,0,540)
end)

-- ════════════════════════════════════════════════════
-- [32] SENHA
-- ════════════════════════════════════════════════════
local function TryPassword(pw)
    if pw == CFG.Password then
        ErrLbl.TextColor3 = CFG.C.ok
        ErrLbl.Text = "✓ Acesso concedido! Carregando..."
        Tween(WCard, 0.25, {BackgroundColor3 = Color3.fromRGB(5,30,5)})

        task.wait(0.6)

        -- Fade out
        Tween(WelcomeScreen, 0.5, {BackgroundTransparency=1})
        for _, v in ipairs(WelcomeScreen:GetDescendants()) do
            pcall(function()
                if v:IsA("GuiObject") then
                    local p = {BackgroundTransparency=1}
                    if v:IsA("TextLabel") or v:IsA("TextButton") or v:IsA("TextBox") then
                        p.TextTransparency = 1
                    end
                    Tween(v, 0.4, p)
                end
            end)
        end

        task.wait(0.65)
        WelcomeScreen:Destroy()

        -- Abrir hub
        Hub.Visible = true
        Hub.Size    = UDim2.new(0,0,0,0)
        Tween(Hub, 0.42, {Size=UDim2.new(0,400,0,540)}, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

        task.wait(0.1)
        TabBtns[1].btn.Activated:Fire()

        Notify("MILLIE HUB v3.0", "Carregado! 💛 Use a aba Debug para verificar o botão Bater.", 5)
    else
        ErrLbl.TextColor3 = CFG.C.warn
        ErrLbl.Text = "✗ Senha incorreta!"

        local orig = WCard.Position
        for i = 1,5 do
            Tween(WCard, 0.04, {Position=UDim2.new(0.5, (i%2==0 and 10 or -10), 0.5, 0)}, Enum.EasingStyle.Linear)
            task.wait(0.045)
        end
        Tween(WCard, 0.1, {Position=orig})
        task.wait(2.5)
        if ErrLbl and ErrLbl.Parent then ErrLbl.Text="" end
    end
end

SubmitBtn.Activated:Connect(function() TryPassword(PwBox.Text) end)
PwBox.FocusLost:Connect(function(enter) if enter then TryPassword(PwBox.Text) end end)

-- ════════════════════════════════════════════════════
-- [33] RESPAWN
-- ════════════════════════════════════════════════════
lp.CharacterAdded:Connect(function(newChar)
    char = newChar
    hrp  = newChar:WaitForChild("HumanoidRootPart", 10)
    hum  = newChar:WaitForChild("Humanoid", 10)
    task.wait(2.5)

    if CFG.HitboxOn then ApplyHitbox(true) end
    if CFG.AutoFarm then
        if farmThread then task.cancel(farmThread) end
        task.wait(0.5)
        farmThread = task.spawn(MainFarmLoop)
    end
    _attackBtn = nil  -- reseta cache do botão
end)

-- ════════════════════════════════════════════════════
print("[MILLIE HUB v3.0] ✓ Carregado. Aguardando senha: Millielover")
print("[MILLIE HUB v3.0] DICA: Abra a aba 'Debug' e clique em 'Escanear Botões' para verificar o botão de ataque.")
print("[MILLIE HUB v3.0] Para foto da Millie: coloque o ID do Roblox em CFG.MillieImageID")
