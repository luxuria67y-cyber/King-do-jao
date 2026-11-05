-- ============================================================
-- MILLIE HUB | LEGACY PIECE | DELTA MOBILE
-- Tema: Millie (Helluva Boss) | Vermelho Escuro + Amarelo
-- Correções: Teleporte (sem voltar), Hitbox, Auto Farm, Auto Quest
-- ============================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local TeleportService = game:GetService("TeleportService")
local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()

-- ==================== PROTEÇÃO ANTI-BAN ====================
local function protect()
    if syn and syn.protect_gui then
        syn.protect_gui(game:GetService("CoreGui"))
    end
    if hookfunction then
        local old = hookfunction(game.HttpGet, function(self, url, ...)
            if string.find(url, "legacypiece") or string.find(url, "anti") then
                return ""
            end
            return old(self, url, ...)
        end)
    end
    LocalPlayer.Kick = function() end
    LocalPlayer.Destroy = function() end
end
pcall(protect)

-- ==================== CONFIGURAÇÕES ====================
local Config = {
    Senha = "Millielover",
    Tema = {
        Fundo = Color3.fromRGB(20, 0, 0),
        Borda = Color3.fromRGB(255, 200, 0),
        Texto = Color3.fromRGB(255, 220, 100),
        Botao = Color3.fromRGB(80, 0, 0),
        BotaoHover = Color3.fromRGB(120, 0, 0),
    },
    AutoFarm = false,
    AutoQuest = false,
    AutoMaterial = false,
    MaterialSelecionado = "Thief's rag",
    AutoLevel = false,
    AutoFlag = false,
    AutoHop = false,
    HitboxRange = 50,
    TeleportDelay = 0.5,
    AttackDelay = 0.3,
}

-- ==================== FUNÇÕES UTILITÁRIAS ====================
local function Tween(obj, props, time, style, dir)
    local info = TweenInfo.new(time or 0.3, style or Enum.EasingStyle.Quart, dir or Enum.EasingDirection.Out)
    local t = TweenService:Create(obj, info, props)
    t:Play()
    return t
end

local function CriarBotao(parent, texto, y, callback)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0.9, 0, 0, 35)
    btn.Position = UDim2.new(0.05, 0, 0, y)
    btn.BackgroundColor3 = Config.Tema.Botao
    btn.TextColor3 = Config.Tema.Texto
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 14
    btn.Text = texto
    btn.BorderSizePixel = 0
    btn.AutoButtonColor = false
    btn.Parent = parent

    local corner = Instance.new("UICorner", btn)
    corner.CornerRadius = UDim.new(0, 8)
    local stroke = Instance.new("UIStroke", btn)
    stroke.Color = Config.Tema.Borda
    stroke.Thickness = 1

    btn.MouseEnter:Connect(function()
        Tween(btn, {BackgroundColor3 = Config.Tema.BotaoHover}, 0.2)
    end)
    btn.MouseLeave:Connect(function()
        Tween(btn, {BackgroundColor3 = Config.Tema.Botao}, 0.2)
    end)
    btn.MouseButton1Click:Connect(function()
        if callback then callback() end
    end)
    return btn
end

-- ==================== ANIMAÇÃO DE BOAS-VINDAS ====================
local function BoasVindas()
    local gui = Instance.new("ScreenGui")
    gui.Name = "MillieWelcome"
    gui.ResetOnSpawn = false
    gui.Parent = game:GetService("CoreGui")

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 0, 0, 0)
    frame.Position = UDim2.new(0.5, 0, 0.5, 0)
    frame.AnchorPoint = Vector2.new(0.5, 0.5)
    frame.BackgroundColor3 = Config.Tema.Fundo
    frame.BorderSizePixel = 0
    frame.Parent = gui

    local corner = Instance.new("UICorner", frame)
    corner.CornerRadius = UDim.new(0, 12)
    local stroke = Instance.new("UIStroke", frame)
    stroke.Color = Config.Tema.Borda
    stroke.Thickness = 2

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -20, 1, -20)
    label.Position = UDim2.new(0, 10, 0, 10)
    label.BackgroundTransparency = 1
    label.TextColor3 = Config.Tema.Texto
    label.Font = Enum.Font.GothamBlack
    label.TextSize = 18
    label.TextWrapped = true
    label.Text = "Bem-vindo a MILLIE HUB HEH!...~"
    label.TextTransparency = 1
    label.Parent = frame

    Tween(frame, {Size = UDim2.new(0, 300, 0, 80)}, 0.6)
    task.wait(0.3)
    Tween(label, {TextTransparency = 0}, 0.5)
    task.wait(2)
    Tween(frame, {Size = UDim2.new(0, 0, 0, 0)}, 0.5)
    task.wait(0.5)
    gui:Destroy()
end

-- ==================== SISTEMA DE SENHA ====================
local function VerificarSenha()
    local gui = Instance.new("ScreenGui")
    gui.Name = "MillieLogin"
    gui.ResetOnSpawn = false
    gui.Parent = game:GetService("CoreGui")

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 280, 0, 120)
    frame.Position = UDim2.new(0.5, 0, 0.5, 0)
    frame.AnchorPoint = Vector2.new(0.5, 0.5)
    frame.BackgroundColor3 = Config.Tema.Fundo
    frame.BorderSizePixel = 0
    frame.Parent = gui

    local corner = Instance.new("UICorner", frame)
    corner.CornerRadius = UDim.new(0, 10)
    local stroke = Instance.new("UIStroke", frame)
    stroke.Color = Config.Tema.Borda
    stroke.Thickness = 2

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0, 30)
    title.Position = UDim2.new(0, 0, 0, 10)
    title.BackgroundTransparency = 1
    title.TextColor3 = Config.Tema.Texto
    title.Font = Enum.Font.GothamBold
    title.TextSize = 16
    title.Text = "Digite a senha de acesso:"
    title.Parent = frame

    local input = Instance.new("TextBox")
    input.Size = UDim2.new(0.8, 0, 0, 35)
    input.Position = UDim2.new(0.1, 0, 0, 50)
    input.BackgroundColor3 = Color3.fromRGB(40, 0, 0)
    input.TextColor3 = Config.Tema.Texto
    input.PlaceholderText = "..."
    input.PlaceholderColor3 = Color3.fromRGB(150, 100, 100)
    input.Font = Enum.Font.Gotham
    input.TextSize = 14
    input.BorderSizePixel = 0
    input.Parent = frame

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0.8, 0, 0, 30)
    btn.Position = UDim2.new(0.1, 0, 0, 90)
    btn.BackgroundColor3 = Config.Tema.Botao
    btn.TextColor3 = Config.Tema.Texto
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 14
    btn.Text = "Entrar"
    btn.BorderSizePixel = 0
    btn.Parent = frame
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
    Instance.new("UIStroke", btn).Color = Config.Tema.Borda

    btn.MouseButton1Click:Connect(function()
        if input.Text == Config.Senha then
            gui:Destroy()
            BoasVindas()
            task.wait(3)
            CriarHub()
        else
            input.Text = ""
            input.PlaceholderText = "Senha incorreta!"
        end
    end)
    return gui
end

-- ==================== HUB PRINCIPAL (ABAS) ====================
function CriarHub()
    local gui = Instance.new("ScreenGui")
    gui.Name = "MillieHub"
    gui.ResetOnSpawn = false
    gui.Parent = game:GetService("CoreGui")

    -- Botão bolha "jv"
    local bolha = Instance.new("TextButton")
    bolha.Size = UDim2.new(0, 50, 0, 50)
    bolha.Position = UDim2.new(0, 20, 0.5, -25)
    bolha.BackgroundColor3 = Config.Tema.Fundo
    bolha.TextColor3 = Config.Tema.Borda
    bolha.Font = Enum.Font.GothamBlack
    bolha.TextSize = 20
    bolha.Text = "jv"
    bolha.BorderSizePixel = 0
    bolha.Parent = gui
    Instance.new("UICorner", bolha).CornerRadius = UDim.new(1, 0)
    Instance.new("UIStroke", bolha).Color = Config.Tema.Borda

    -- Frame principal
    local main = Instance.new("Frame")
    main.Size = UDim2.new(0, 500, 0, 400)
    main.Position = UDim2.new(0.5, 0, 0.5, 0)
    main.AnchorPoint = Vector2.new(0.5, 0.5)
    main.BackgroundColor3 = Config.Tema.Fundo
    main.BorderSizePixel = 0
    main.Parent = gui
    Instance.new("UICorner", main).CornerRadius = UDim.new(0, 12)
    local stroke = Instance.new("UIStroke", main)
    stroke.Color = Config.Tema.Borda
    stroke.Thickness = 2

    -- Título
    local titulo = Instance.new("TextLabel")
    titulo.Size = UDim2.new(1, 0, 0, 40)
    titulo.BackgroundTransparency = 1
    titulo.TextColor3 = Config.Tema.Borda
    titulo.Font = Enum.Font.GothamBlack
    titulo.TextSize = 20
    titulo.Text = "MILLIE HUB"
    titulo.Parent = main

    -- Barra lateral de abas
    local tabBar = Instance.new("Frame")
    tabBar.Size = UDim2.new(0, 120, 1, -40)
    tabBar.Position = UDim2.new(0, 0, 0, 40)
    tabBar.BackgroundTransparency = 1
    tabBar.Parent = main

    -- Área de conteúdo
    local contentArea = Instance.new("Frame")
    contentArea.Size = UDim2.new(1, -120, 1, -40)
    contentArea.Position = UDim2.new(0, 120, 0, 40)
    contentArea.BackgroundTransparency = 1
    contentArea.Parent = main

    -- Função para criar abas
    local function CriarAba(nome, y)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(0.9, 0, 0, 30)
        btn.Position = UDim2.new(0.05, 0, 0, y)
        btn.BackgroundColor3 = Config.Tema.Botao
        btn.TextColor3 = Config.Tema.Texto
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 12
        btn.Text = nome
        btn.BorderSizePixel = 0
        btn.Parent = tabBar
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
        Instance.new("UIStroke", btn).Color = Config.Tema.Borda
        return btn
    end

    -- Criar abas
    local abaMain = CriarAba("Main", 0)
    local abaBosses = CriarAba("Bosses", 35)
    local abaSea = CriarAba("Sea", 70)
    local abaDungeon = CriarAba("Dungeon", 105)
    local abaQuest = CriarAba("Quest", 140)
    local abaMisc = CriarAba("Misc", 175)

    -- Conteúdo da aba Main
    local mainFrame = Instance.new("Frame")
    mainFrame.Size = UDim2.new(1, 0, 1, 0)
    mainFrame.BackgroundTransparency = 1
    mainFrame.Parent = contentArea

    -- Botões da aba Main
    local autoFarmBtn = CriarBotao(mainFrame, "Auto Farm", 10, function()
        Config.AutoFarm = not Config.AutoFarm
        autoFarmBtn.Text = Config.AutoFarm and "Desativar Auto Farm" or "Auto Farm"
    end)

    local autoQuestBtn = CriarBotao(mainFrame, "Auto Quest", 55, function()
        Config.AutoQuest = not Config.AutoQuest
        autoQuestBtn.Text = Config.AutoQuest and "Desativar Auto Quest" or "Auto Quest"
    end)

    local autoMaterialBtn = CriarBotao(mainFrame, "Auto Farm Material", 100, function()
        Config.AutoMaterial = not Config.AutoMaterial
        autoMaterialBtn.Text = Config.AutoMaterial and "Desativar Auto Material" or "Auto Farm Material"
    end)

    local autoLevelBtn = CriarBotao(mainFrame, "Auto Farm Level", 145, function()
        Config.AutoLevel = not Config.AutoLevel
        autoLevelBtn.Text = Config.AutoLevel and "Desativar Auto Level" or "Auto Farm Level"
    end)

    local autoFlagBtn = CriarBotao(mainFrame, "Auto Collect Flag", 190, function()
        Config.AutoFlag = not Config.AutoFlag
        autoFlagBtn.Text = Config.AutoFlag and "Desativar Auto Flag" or "Auto Collect Flag"
    end)

    local autoHopBtn = CriarBotao(mainFrame, "Auto Hop", 235, function()
        Config.AutoHop = not Config.AutoHop
        autoHopBtn.Text = Config.AutoHop and "Desativar Auto Hop" or "Auto Hop"
    end)

    -- Conteúdo da aba Bosses (simplificado)
    local bossesFrame = Instance.new("Frame")
    bossesFrame.Size = UDim2.new(1, 0, 1, 0)
    bossesFrame.BackgroundTransparency = 1
    bossesFrame.Visible = false
    bossesFrame.Parent = contentArea

    -- Botão de exemplo: Teleportar para Boss
    local tpBossBtn = CriarBotao(bossesFrame, "Teleportar para Boss", 10, function()
        -- Lógica para teleportar ao boss mais próximo
        local char = LocalPlayer.Character
        if not char then return end
        local root = char:FindFirstChild("HumanoidRootPart")
        if not root then return end
        for _, v in pairs(Workspace:GetDescendants()) do
            if v:IsA("Model") and v:FindFirstChild("Humanoid") and v.Name:lower():find("boss") then
                local hrp = v:FindFirstChild("HumanoidRootPart") or v:FindFirstChild("Torso")
                if hrp then
                    root.CFrame = hrp.CFrame + Vector3.new(0, 5, 0)
                    break
                end
            end
        end
    end)

    -- Alternar visibilidade das abas
    abaMain.MouseButton1Click:Connect(function()
        mainFrame.Visible = true
        bossesFrame.Visible = false
    end)
    abaBosses.MouseButton1Click:Connect(function()
        mainFrame.Visible = false
        bossesFrame.Visible = true
    end)

    -- Minimizar/Restaurar
    local minimizado = false
    bolha.MouseButton1Click:Connect(function()
        minimizado = not minimizado
        if minimizado then
            Tween(main, {Size = UDim2.new(0, 0, 0, 0)}, 0.3)
        else
            Tween(main, {Size = UDim2.new(0, 500, 0, 400)}, 0.3)
        end
    end)

    -- Fechar
    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 30, 0, 30)
    closeBtn.Position = UDim2.new(1, -35, 0, 5)
    closeBtn.BackgroundTransparency = 1
    closeBtn.TextColor3 = Config.Tema.Borda
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.TextSize = 18
    closeBtn.Text = "X"
    closeBtn.Parent = main
    closeBtn.MouseButton1Click:Connect(function()
        gui:Destroy()
    end)
end

-- ==================== LÓGICA DE AUTO FARM (CORRIGIDA) ====================
local function AutoFarmLoop()
    while task.wait(0.1) do
        if not Config.AutoFarm then continue end
        local char = LocalPlayer.Character
        if not char then continue end
        local root = char:FindFirstChild("HumanoidRootPart")
        local humanoid = char:FindFirstChild("Humanoid")
        if not root or not humanoid or humanoid.Health <= 0 then continue end

        -- Encontra o mob mais próximo
        local nearestMob, nearestDist = nil, math.huge
        for _, v in pairs(Workspace:GetDescendants()) do
            if v:IsA("Model") and v:FindFirstChild("Humanoid") and v ~= char then
                local hrp = v:FindFirstChild("HumanoidRootPart") or v:FindFirstChild("Torso")
                if hrp and v.Humanoid.Health > 0 then
                    local dist = (hrp.Position - root.Position).Magnitude
                    if dist < nearestDist then
                        nearestDist = dist
                        nearestMob = v
                    end
                end
            end
        end

        if nearestMob then
            local targetPart = nearestMob:FindFirstChild("HumanoidRootPart") or nearestMob:FindFirstChild("Torso")
            if targetPart then
                -- Teleporte corrigido: define CFrame e aguarda a física
                root.CFrame = targetPart.CFrame + Vector3.new(0, 5, 0)
                task.wait(Config.TeleportDelay) -- espera a física estabilizar
                -- Ataque automático
                local tool = char:FindFirstChildOfClass("Tool")
                if tool then
                    tool:Activate()
                else
                    local VirtualUser = game:GetService("VirtualUser")
                    VirtualUser:CaptureController()
                    VirtualUser:Button1Down(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
                end
                task.wait(Config.AttackDelay)
            end
        end
    end
end

-- ==================== LÓGICA DE AUTO QUEST ====================
local function AutoQuestLoop()
    while task.wait(1) do
        if not Config.AutoQuest then continue end
        local char = LocalPlayer.Character
        if not char then continue end
        local root = char:FindFirstChild("HumanoidRootPart")
        if not root then continue end

        for _, v in pairs(Workspace:GetDescendants()) do
            if v:IsA("Model") and v:FindFirstChild("Humanoid") then
                local name = v.Name:lower()
                if name:find("quest") or name:find("giver") or name:find("mission") then
                    local hrp = v:FindFirstChild("HumanoidRootPart") or v:FindFirstChild("Torso")
                    if hrp then
                        root.CFrame = hrp.CFrame + Vector3.new(0, 5, 0)
                        task.wait(0.5)
                        local prompt = v:FindFirstChildOfClass("ProximityPrompt")
                        if prompt then
                            prompt:InputHoldBegin()
                            task.wait(0.2)
                            prompt:InputHoldEnd()
                        end
                        break
                    end
                end
            end
        end
    end
end

-- ==================== LÓGICA DE AUTO MATERIAL ====================
local function AutoMaterialLoop()
    while task.wait(0.5) do
        if not Config.AutoMaterial then continue end
        local char = LocalPlayer.Character
        if not char then continue end
        local root = char:FindFirstChild("HumanoidRootPart")
        if not root then continue end

        for _, v in pairs(Workspace:GetDescendants()) do
            if v:IsA("Model") and v.Name == Config.MaterialSelecionado then
                local hrp = v:FindFirstChild("HumanoidRootPart") or v:FindFirstChild("Torso")
                if hrp then
                    root.CFrame = hrp.CFrame + Vector3.new(0, 5, 0)
                    task.wait(0.2)
                    break
                end
            end
        end
    end
end

-- ==================== LÓGICA DE AUTO FLAG ====================
local function AutoFlagLoop()
    while task.wait(1) do
        if not Config.AutoFlag then continue end
        local char = LocalPlayer.Character
        if not char then continue end
        local root = char:FindFirstChild("HumanoidRootPart")
        if not root then return end

        for _, v in pairs(Workspace:GetDescendants()) do
            if v:IsA("Model") and v.Name:lower():find("flag") then
                local hrp = v:FindFirstChild("HumanoidRootPart") or v:FindFirstChild("Torso")
                if hrp then
                    root.CFrame = hrp.CFrame + Vector3.new(0, 5, 0)
                    break
                end
            end
        end
    end
end

-- ==================== LÓGICA DE AUTO HOP ====================
local function AutoHopLoop()
    while task.wait(5) do
        if not Config.AutoHop then continue end
        pcall(function()
            TeleportService:Teleport(game.PlaceId, LocalPlayer)
        end)
    end
end

-- ==================== LÓGICA DE HITBOX ====================
local function HitboxLoop()
    while task.wait(1) do
        for _, v in pairs(Workspace:GetDescendants()) do
            if v:IsA("BasePart") and v.Parent and v.Parent:FindFirstChild("Humanoid") and v.Parent ~= LocalPlayer.Character then
                if v.Name == "Hitbox" or v.Name == "Torso" or v.Name == "UpperTorso" then
                    v.Size = Vector3.new(Config.HitboxRange, Config.HitboxRange, Config.HitboxRange)
                    v.Transparency = 0.7
                end
            end
        end
    end
end

-- ==================== INICIALIZAÇÃO ====================
-- Inicia loops em segundo plano
spawn(AutoFarmLoop)
spawn(AutoQuestLoop)
spawn(AutoMaterialLoop)
spawn(AutoFlagLoop)
spawn(AutoHopLoop)
spawn(HitboxLoop)

-- Inicia tela de senha
VerificarSenha()
