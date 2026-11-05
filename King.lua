-- ============================================================
-- MILLIE HUB | LEGACY PIECE | DELTA MOBILE
-- Tema: Millie (Helluva Boss) | Vermelho Escuro + Amarelo
-- ============================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()

-- ==================== PROTEÇÃO ANTI-BAN ====================
local function protect()
    if syn and syn.protect_gui then
        local old; old = hookfunction(game.HttpGet, function(self, url, ...)
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

local function CriarBotao(parent, texto, y)
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
    wait(0.3)
    Tween(label, {TextTransparency = 0}, 0.5)
    wait(2)
    Tween(frame, {Size = UDim2.new(0, 0, 0, 0)}, 0.5)
    wait(0.5)
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
            wait(3)
            -- Abre o Hub principal
            -- (a função CriarHub será chamada aqui)
            CriarHub()
        else
            input.Text = ""
            input.PlaceholderText = "Senha incorreta!"
        end
    end)

    return gui
end

-- ==================== HUB PRINCIPAL ====================
function CriarHub()
    local gui = Instance.new("ScreenGui")
    gui.Name = "MillieHub"
    gui.ResetOnSpawn = false
    gui.Parent = game:GetService("CoreGui")

    -- Botão bolha "jv" para minimizar/restaurar
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
    main.Size = UDim2.new(0, 320, 0, 400)
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

    -- Abas (simplificado: Auto Farm, Teleportes, Player)
    local tabFrame = Instance.new("Frame")
    tabFrame.Size = UDim2.new(1, 0, 1, -40)
    tabFrame.Position = UDim2.new(0, 0, 0, 40)
    tabFrame.BackgroundTransparency = 1
    tabFrame.Parent = main

    -- ===== AUTO FARM =====
    local autoFarmBtn = CriarBotao(tabFrame, "Ativar Auto Farm", 10)
    local statusLabel = Instance.new("TextLabel")
    statusLabel.Size = UDim2.new(0.9, 0, 0, 20)
    statusLabel.Position = UDim2.new(0.05, 0, 0, 50)
    statusLabel.BackgroundTransparency = 1
    statusLabel.TextColor3 = Config.Tema.Texto
    statusLabel.Font = Enum.Font.Gotham
    statusLabel.TextSize = 12
    statusLabel.Text = "Status: OFF"
    statusLabel.Parent = tabFrame

    autoFarmBtn.MouseButton1Click:Connect(function()
        Config.AutoFarm = not Config.AutoFarm
        autoFarmBtn.Text = Config.AutoFarm and "Desativar Auto Farm" or "Ativar Auto Farm"
        statusLabel.Text = "Status: " .. (Config.AutoFarm and "ON" or "OFF")
    end)

    -- ===== AUTO QUEST =====
    local autoQuestBtn = CriarBotao(tabFrame, "Ativar Auto Quest", 80)
    autoQuestBtn.MouseButton1Click:Connect(function()
        Config.AutoQuest = not Config.AutoQuest
        autoQuestBtn.Text = Config.AutoQuest and "Desativar Auto Quest" or "Ativar Auto Quest"
    end)

    -- ===== HITBOX =====
    local hitboxBtn = CriarBotao(tabFrame, "Aumentar Hitbox (50)", 150)
    hitboxBtn.MouseButton1Click:Connect(function()
        for _, v in pairs(Workspace:GetDescendants()) do
            if v:IsA("BasePart") and v.Parent and v.Parent:FindFirstChild("Humanoid") and v.Parent ~= LocalPlayer.Character then
                if v.Name == "Hitbox" or v.Name == "Torso" or v.Name == "UpperTorso" then
                    v.Size = Vector3.new(Config.HitboxRange, Config.HitboxRange, Config.HitboxRange)
                    v.Transparency = 0.7
                end
            end
        end
    end)

    -- ===== TELEPORTE PARA MOBS =====
    local tpMobBtn = CriarBotao(tabFrame, "Teleportar para Mobs", 220)
    tpMobBtn.MouseButton1Click:Connect(function()
        local char = LocalPlayer.Character
        if not char then return end
        local root = char:FindFirstChild("HumanoidRootPart")
        if not root then return end
        for _, v in pairs(Workspace:GetDescendants()) do
            if v:IsA("Model") and v:FindFirstChild("Humanoid") and v ~= char then
                if v.Humanoid.Health > 0 then
                    local target = v:FindFirstChild("HumanoidRootPart") or v:FindFirstChild("Torso")
                    if target then
                        root.CFrame = target.CFrame + Vector3.new(0, 5, 0)
                        wait(Config.TeleportDelay)
                        break
                    end
                end
            end
        end
    end)

    -- ===== MINIMIZAR / RESTAURAR =====
    local minimizado = false
    bolha.MouseButton1Click:Connect(function()
        minimizado = not minimizado
        if minimizado then
            Tween(main, {Size = UDim2.new(0, 0, 0, 0)}, 0.3)
        else
            Tween(main, {Size = UDim2.new(0, 320, 0, 400)}, 0.3)
        end
    end)

    -- Fechar (opcional)
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

-- ==================== LÓGICA DE AUTO FARM ====================
local function AutoFarmLoop()
    while wait(0.1) do
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
                -- Teleporte suave (corrige o bug de voltar)
                root.CFrame = targetPart.CFrame + Vector3.new(0, 5, 0)
                wait(0.2)
                -- Ataque automático (simula clique)
                local tool = char:FindFirstChildOfClass("Tool")
                if tool then
                    tool:Activate()
                else
                    -- Tenta usar skill (tecla Z)
                    local VirtualUser = game:GetService("VirtualUser")
                    VirtualUser:CaptureController()
                    VirtualUser:Button1Down(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
                end
                wait(Config.AttackDelay)
            end
        end
    end
end

-- ==================== LÓGICA DE AUTO QUEST ====================
local function AutoQuestLoop()
    while wait(1) do
        if not Config.AutoQuest then continue end
        local char = LocalPlayer.Character
        if not char then continue end
        local root = char:FindFirstChild("HumanoidRootPart")
        if not root then continue end

        -- Procura NPCs de quest (nomes comuns)
        for _, v in pairs(Workspace:GetDescendants()) do
            if v:IsA("Model") and v:FindFirstChild("Humanoid") then
                local name = v.Name:lower()
                if name:find("quest") or name:find("giver") or name:find("mission") then
                    local hrp = v:FindFirstChild("HumanoidRootPart") or v:FindFirstChild("Torso")
                    if hrp then
                        root.CFrame = hrp.CFrame + Vector3.new(0, 5, 0)
                        wait(0.5)
                        -- Interage (ProximityPrompt)
                        local prompt = v:FindFirstChildOfClass("ProximityPrompt")
                        if prompt then
                            prompt:InputHoldBegin()
                            wait(0.2)
                            prompt:InputHoldEnd()
                        end
                        break
                    end
                end
            end
        end
    end
end

-- ==================== INICIALIZAÇÃO ====================
-- Inicia loops em segundo plano
spawn(AutoFarmLoop)
spawn(AutoQuestLoop)

-- Inicia tela de senha
VerificarSenha()
