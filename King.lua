--[[
    MILLIE HUB  -  "Millie lazy"  v3.1   (Legacy Piece edition)
    Built for mobile executors (Delta). One file, no external dependencies.

    Password ............ Millielover
    Open / minimize ..... tap the round "jv" bubble (drag it anywhere)
    Background art ...... embedded (works offline). To use another image, paste a
                          direct png/jpg link in Settings -> Millie image URL, or
                          drop millie.png into your executor's workspace/MillieHub.

    Honest notes
    * Nothing here is "ban proof". Safe Mode keeps speeds, click rates and
      movement human-looking; use an alt account.
    * Legacy Piece changes its internals often, so mobs / quest NPCs / attack
      buttons are DISCOVERED at runtime. StreamingEnabled limits discovery to
      objects currently replicated to this client; the Scanner shows that scope
      and the last error of every module.
]]

local CFG = {
    KEY = "Millielover",
    VERSION = "3.1",
    FOLDER = "MillieHub",
    MILLIE_IMAGE_URL = "", -- optional direct png/jpg link (overrides the embedded art)
}

local ENV = (getgenv and getgenv()) or _G
if type(ENV.__MILLIE_HUB) == "table" and type(ENV.__MILLIE_HUB.Destroy) == "function" then
    pcall(ENV.__MILLIE_HUB.Destroy)
end

if not game:IsLoaded() then game.Loaded:Wait() end

----------------------------------------------------------------------
-- services
----------------------------------------------------------------------
local function svc(name)
    local ok, s = pcall(function() return game:GetService(name) end)
    if ok then return s end
    return nil
end

local Players = svc("Players")
local RunService = svc("RunService")
local UIS = svc("UserInputService")
local Lighting = svc("Lighting")
local HttpService = svc("HttpService")
local GuiService = svc("GuiService")
local TeleportService = svc("TeleportService")
local MarketplaceService = svc("MarketplaceService")
local Workspace = svc("Workspace")
local VirtualUser = svc("VirtualUser")
local VIM = svc("VirtualInputManager")

local LP = Players.LocalPlayer
while not LP do
    task.wait(0.1)
    LP = Players.LocalPlayer
end

-- executor functions (all optional; every use is guarded)
local X = {
    isfile = isfile, isfolder = isfolder, writefile = writefile, readfile = readfile,
    makefolder = makefolder,
    getasset = getcustomasset or getsynasset,
    fireprompt = fireproximityprompt, fireclick = fireclickdetector, firesignal = firesignal,
    getconns = getconnections, shp = sethiddenproperty, isowner = isnetworkowner,
    clip = setclipboard or toclipboard, hui = gethui, ident = identifyexecutor,
    http = (syn and syn.request) or request or http_request,
}

----------------------------------------------------------------------
-- settings
----------------------------------------------------------------------
local AUTO_NEAREST = "Auto (nearest)"
local AUTO_LEVEL = "Auto (by level)"
local AUTO_TOOL = "Auto (first tool)"
local AUTO_QUEST = "Auto (best match)"

local S = {
    -- farm
    AutoFarm = false, TargetMob = AUTO_NEAREST, FarmPos = "Behind", FarmDist = 4, TravelSpeed = 70, MoveMode = "Auto",
    AutoAttack = false, AttackMethod = "Auto", CPS = 6,
    SkillZ = false, SkillX = false, SkillC = false, SkillV = false, SkillG = false, SkillDelay = 1.6,
    BringMobs = false, BringRadius = 90, Hitbox = false, HitboxSize = 25, Reach = false, ReachSize = 16,
    AutoEquip = true, Weapon = AUTO_TOOL, EquipMode = "Tool", HotbarSlot = 1,
    -- quests
    AutoQuest = false, QuestNPC = AUTO_QUEST, QuestInterval = 90,
    -- misc
    AntiAFK = true, Noclip = false, WalkSpeedOn = false, WalkSpeed = 26, AutoLoot = false, LootRadius = 40,
    FPSBoost = false, Disable3D = false, AutoRejoin = false, InstantTP = false,
    TPIsland = "(pick one)", TPNPC = "(pick one)", TPPlayer = "(pick one)",
    -- safety
    SafeMode = true, PauseOnStaff = true, Notify = true,
    -- goals
    AutoPrestige = false, PrestigeLevel = 0, PrestigeRank = 0, PrestigeEvery = 8,
    AutoBoss = false, BossSel = "Any boss", BossIsland = true,
    ItemSel = "Auto-Katana", ItemRun = false, ItemAttempts = 25,
    SpyOn = false, SpyQuiet = true, MacroName = "", MacroSel = "(none)",
    -- ui
    UIScale = 1, MillieURL = "",
}

-- settings that are remembered between sessions (running toggles are NOT saved on purpose)
local PERSIST = {
    "TargetMob", "FarmPos", "FarmDist", "TravelSpeed", "MoveMode", "AttackMethod", "CPS", "SkillDelay",
    "BringRadius", "HitboxSize", "ReachSize", "AutoEquip", "Weapon", "EquipMode", "HotbarSlot",
    "QuestInterval", "AntiAFK", "WalkSpeed", "LootRadius", "SafeMode", "PauseOnStaff", "Notify",
    "UIScale", "MillieURL", "PrestigeRank", "PrestigeLevel", "PrestigeEvery", "BossSel", "BossIsland",
    "ItemSel", "ItemAttempts", "SpyQuiet", "MacroName",
}

-- Safe Mode caps (applied wherever a value is used)
local Limits = {}
function Limits.speed() return S.SafeMode and 220 or 320 end
function Limits.cps() return S.SafeMode and 9 or 16 end
function Limits.walk() return S.SafeMode and 30 or 80 end
function Limits.hitbox() return S.SafeMode and 40 or 90 end

----------------------------------------------------------------------
-- hub core
----------------------------------------------------------------------
local Hub = {
    alive = true, paused = false, pauseReason = "", unlocked = false,
    conns = {}, errors = {}, status = "Idle", noteT = {}, dirtyAt = nil, staff = {},
}

function Hub.track(c)
    Hub.conns[#Hub.conns + 1] = c
    return c
end

function Hub.err(tag, e)
    Hub.errors[tag] = tostring(e) .. "  [t=" .. string.format("%.0f", os.clock()) .. "]"
end

-- run fn forever (until the hub dies); fn returns the seconds to wait before the next run
function Hub.loop(tag, fn)
    task.spawn(function()
        while Hub.alive do
            local ok, w = pcall(fn)
            if not ok then
                Hub.err(tag, w)
                w = 1
            end
            if type(w) ~= "number" or w ~= w then w = 0.1 end
            task.wait(w)
        end
    end)
end

function Hub.dirty() Hub.dirtyAt = os.clock() end

-- toast (bound to the real UI later); rate-limited per tag
function Hub.note(tag, text, kind)
    if not S.Notify and kind ~= "force" then return end
    local now = os.clock()
    if tag and Hub.noteT[tag] and now - Hub.noteT[tag] < 6 then return end
    if tag then Hub.noteT[tag] = now end
    if Hub.toastFn then
        pcall(Hub.toastFn, text, kind)
    end
end

local function rname(n)
    local chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    local out = {}
    for i = 1, n or 10 do
        local k = math.random(1, #chars)
        out[i] = chars:sub(k, k)
    end
    return table.concat(out)
end

----------------------------------------------------------------------
-- utilities
----------------------------------------------------------------------
local Util = {}
local ZERO = Vector3.new(0, 0, 0)

function Util.clamp(v, a, b)
    if v < a then return a end
    if v > b then return b end
    return v
end
function Util.rand(a, b) return a + math.random() * (b - a) end
function Util.round(v, step)
    step = step or 1
    return math.floor(v / step + 0.5) * step
end
function Util.fmt(v)
    if type(v) ~= "number" then return tostring(v) end
    return string.format("%g", math.floor(v * 100 + 0.5) / 100)
end

function Util.char() return LP.Character end
function Util.hum()
    local c = LP.Character
    return c and c:FindFirstChildOfClass("Humanoid")
end
function Util.root()
    local c = LP.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end
function Util.alive()
    local h = Util.hum()
    return h ~= nil and h.Health > 0 and Util.root() ~= nil
end

function Util.guiVisible(obj)
    local p = obj
    while p do
        if p == Hub.gui then return false end
        if p:IsA("GuiObject") then
            if not p.Visible then return false end
        elseif p:IsA("ScreenGui") then
            if not p.Enabled then return false end
        end
        p = p.Parent
    end
    return true
end

-- position of any instance (prompt, part, attachment, model...)
function Util.posOf(inst)
    local p = inst
    while p and p ~= Workspace do
        if p:IsA("BasePart") then return p.Position end
        if p:IsA("Attachment") then return p.WorldPosition end
        p = p.Parent
    end
    local m = inst:FindFirstAncestorOfClass("Model")
    if m then
        local ok, cf = pcall(function() return m:GetPivot() end)
        if ok and cf then return cf.Position end
    end
    return nil
end

function Util.pivotPos(inst)
    if inst:IsA("BasePart") then return inst.Position end
    if inst:IsA("Model") then
        local ok, cf = pcall(function() return inst:GetPivot() end)
        if ok and cf then return cf.Position end
    end
    for _, d in ipairs(inst:GetDescendants()) do
        if d:IsA("BasePart") then return d.Position end
    end
    return nil
end

function Util.groundY(pos)
    local ok, y = pcall(function()
        local params = RaycastParams.new()
        params.FilterType = Enum.RaycastFilterType.Exclude
        params.FilterDescendantsInstances = { LP.Character }
        local res = Workspace:Raycast(pos + Vector3.new(0, 80, 0), Vector3.new(0, -400, 0), params)
        return res and res.Position.Y or nil
    end)
    if ok then return y end
    return nil
end

-- UI automation must never leave a synthetic mouse/touch button held.
-- Use the button's activation signal only; no screen-coordinate clicks.
function Util.fireButton(btn)
    if not btn or not btn:IsA("GuiButton") then return false end
    if not btn.Parent or not btn.Visible or not Util.guiVisible(btn) then return false end

    -- Prefer the executor's signal dispatcher: it invokes the Activated
    -- subscribers as a group instead of arbitrarily firing only one callback.
    if X.firesignal then
        local ok = pcall(function() X.firesignal(btn.Activated) end)
        if ok then return true end
    end

    -- Compatibility fallback for executors without firesignal. Run each
    -- connected callback; some buttons have separate UI and game listeners.
    if X.getconns then
        local ok, conns = pcall(function() return X.getconns(btn.Activated) end)
        if ok and type(conns) == "table" then
            local fired = false
            for _, c in ipairs(conns) do
                local okFire = pcall(function() c:Fire() end)
                fired = fired or okFire
            end
            if fired then return true end
        end
    end
    return false
end

-- Kept for older modules, but deliberately does not synthesize a mouse click.
function Util.tapGui(btn)
    return Util.fireButton(btn)
end

function Util.firePrompt(prompt)
    if X.fireprompt then
        local ok = pcall(X.fireprompt, prompt)
        if ok then return true end
    end
    local ok = pcall(function()
        prompt:InputHoldBegin()
        task.wait((prompt.HoldDuration or 0) + 0.12)
        prompt:InputHoldEnd()
    end)
    return ok
end

function Util.pressKey(kc, hold)
    if not VIM then return false end
    pcall(function() VIM:SendKeyEvent(true, kc, false, game) end)
    task.wait(hold or Util.rand(0.04, 0.09))
    pcall(function() VIM:SendKeyEvent(false, kc, false, game) end)
    return true
end

----------------------------------------------------------------------
-- animation engine (exponential lerp, frame-rate independent)
----------------------------------------------------------------------
local Anim = { list = {} }

function Anim.new(speed, apply, initial)
    local a = { v = initial or 0, t = initial or 0, speed = speed or 14, apply = apply, dead = false }
    Anim.list[#Anim.list + 1] = a
    pcall(apply, a.v)
    return a
end

function Anim.step(dt)
    local list = Anim.list
    local i = 1
    while i <= #list do
        local a = list[i]
        if a.dead then
            table.remove(list, i)
        else
            local d = a.t - a.v
            if d ~= 0 then
                if math.abs(d) < 0.0006 then
                    a.v = a.t
                else
                    a.v = a.v + d * (1 - math.exp(-a.speed * dt))
                end
                local ok, e = pcall(a.apply, a.v)
                if not ok then
                    a.dead = true
                    Hub.err("anim", e)
                end
            end
            i = i + 1
        end
    end
end

Hub.track(RunService.RenderStepped:Connect(function(dt)
    if dt > 0.1 then dt = 0.1 end
    Anim.step(dt)
end))

----------------------------------------------------------------------
-- Millie art: embedded jpg (base64) -> file -> getcustomasset
----------------------------------------------------------------------
local MILLIE_B64 = "/9j/4AAQSkZJRgABAQAAAQABAAD/2wBDAA4KCw0LCQ4NDA0QDw4RFiQXFhQUFiwgIRokNC43NjMuMjI6QVNGOj1OPjIySGJJTlZYXV5dOEVmbWVabFNbXVn/2wBDAQ8QEBYTFioXFypZOzI7WVlZWVlZWVlZWVlZWVlZWVlZWVlZWVlZWVlZWVlZWVlZWVlZWVlZWVlZWVlZWVlZWVn/wAARCACgAKADASIAAhEBAxEB/8QAGwAAAQUBAQAAAAAAAAAAAAAABQACAwQGAQf/xAA6EAACAQMCBAMFBwIGAwEAAAABAgMABBESIQUxQVETImEGMnGBkRQjQlKhscFy0TNDYmPh8BVT8YL/xAAaAQACAwEBAAAAAAAAAAAAAAACAwABBAUG/8QAJREAAgICAgICAgMBAAAAAAAAAAECEQMhEjETQQQiUWEFMkJx/9oADAMBAAIRAxEAPwCbhtrHPcKjnSDVnjVjDaOnhHmOVDkcqcg4NdllaQ5ZiT61m3Z0EtnLeEzzLGvNjiouIcFhT2ptoJJstPH7oXOM5x+1SG6PDwJgMy/gShc3HTL7RwcTuUKCJkDKu+yjfH1NGoypyE5ZK1EAOuh2T8rFfoaRZmAySQOVXJY1u7iSY6okd2YKcZAJJApwjto+UYY933rb5FRj4sH5HcV0c886IiZByRAP6RXC0L+9Eh+WKnl/ROAr2/l4hbwosBAiGCVGc0PI5qdj2NXGSNTqhZ4n7g5FTJdsyeHcxRzKdt/3HUH4VXk/ROIMhkCOpddS8mU9R1q1fWZtJU0trhlUSQv+ZT/IOxqnJC/2kRx5cvuKPcPjiv8AhknDDcJJdR5mttKkjUB5kz11AfUUpS4Sv0G1aoCkFcqRXCCADg4PI42NT2kIuZfMSEG7H+KM+1KqkPB1iULELTygcs6jmtDn9lEXx1Zn6Oez/D0kR72ddSodKKep70DrU+zmmaxFu5KGN9RB2yDQ521DQeGKlOmXSdTc8mitnw+Ka2LlvN+1TX9lbRWmYtKt370LjleJNCMQDzrm8nNfXRt6I3iIkZVBOntUb7Ix7A1MsjqSVYgsMH1pqwS3GuOCJpH0kkKOQ7ntTkCyIIcamIVe52qCW9jj2hGt/wAx5Ch8zvO2Xdj86Yq6RtWqHxktyFTzt6iOmdixeUnPUmqEkWhi8nvkkhfy/wDNE3d5VFxLyVfJ8PzH+KDT3StIQmXbstSc1LS6Qmq2x2o03NMXWdzhfTnT6EoVKlSqEFmlmlSqEILpmWIldtXlJ9Of8VWhneFw8bFWU5BBwRVu4XVA/oM0P5nahZaCVhcYDINt9VaDiK/bvZiCZd5OHyFXH+2/I/Ij9ay0VvcRMJGidVHPUMbfOtDwi+FtKRIokgkUxyxnk6nmKra2vRfei57H8Fs+KLNJdeYocBM0ziji19o0tfFH2dBpGnbHxofe29zwa4EllcP9lm/wpl/EPynsw6j50Ld3kcu7FnO5Y86bGDlJy5afoHlxrW0ai7uJY3ii1nLOFHw5n9BUq3DquNjWfteJeJeQi7JKQoQGHPJ7/KjSMku8LrID2pDhx0zXGSntFj7UQPdz8K1jNDwXhCQu2maRdUmkZZmPp+lY6N1hnid0LqrqSo64Najg8/8A5KSWa4XU0Z8Rz3J2UfAb1I6YM0YjFdXQHHiIXTmQDjPoT0FP01TmmV2KjeNTv/qP9q2zkkjMkWLi+lnU40LGeWFwB/SP5OT2oYwAJ0jn+tPllLmoqzJFtipUqVWUKlSpVCCpUqVQhxhlSO4xVMz+CNFvlejSfib+wq7Q2RcSMPXIqmWhh3OTuT1NEbWXVEp6jY1QCEkAAkmiSW5ghi1e8chvjzFCmEoNptegpaX+mJoZVWSF/ejcZU/8+o3qC7sISjzW0uhFBYpJ0+B6/Oqg2NR3skhRLZPM0pGw58+VFbjtFd9k3DODX17A1xFEvhNljI8iqqqOpydhXLIPHda4pNOg+8vI1fMHF7qyS2W3eOzhUZUYRNvxMSd/maq2CaiVyMlsZ6U7HbVNgPT0aBOKW88Ph3MQSTP+KoopZTrb8CvRbSq0k8qorA4wNO/6ZrLXdobaXQzqxxnynNReYR6A7BdWrHryzVPCu4jvK32T8Ql8GDSpw8mw9B1NC84GByFT8Sk13rjpGNA/c/8AfSq1A3Yt9naVcrtUUdpUhS6b1CCpVzUOmT8BmmkSSEqq6R1Lf2quSLUWxBiG0tzO4HpinHODjGfWnPD4bh9ZcuN2PcUwH71l9AaidoKceMqIzLIAQYWBOwIOauL9+EQ2owNgZWAApka6pB2Xf+381bhtpLy5S1hGWY70jLNR7H4k0v8ApV+7hkIj0nH4ol/k71OxWe3cL7yjODz2rc8P9n7O2hCtCkz48zOM5+HagvtHwZOHvHeWyaYidLqOQ/4rnw+bGc+KHq4rZlzhRqOy4zTLC2nuzc8RjOlLUqWx7yqdsgenX402/OB4K98H+KI8FuTw100hTzDq24cHmD6V1FK9owtU6Kt1NPNlXnlmiB8uonH05V2y/EK0I4bayWsqQMfs8zAxZ3KH/wBZPfseo9aGNaNaHw3GG61rx5Iy0gHFrbIznnzpupD1wexqTFNaMN8aa0VYIW48Rzr8rsSTnrmpaheNXXDD4VHmWD/cT9RWPost0qijnR+TYPY08Pn3QW/aoQlAzTyQgy3yHeuRKzE6mCgDO1EuBcJbil2c5EK7s3YdvjWbNmWNNsdDG2D0E8u0cWfgCTTwGi8skTJ8q9MtbGK1iEcEaoo7da7cWUVwhSaNZFPRhmuS/wCRd9aNSxpdM8zdNcZCkHO4PrVXT95rHYZ+v98VouJ8KjhuJjw5/F8LeWHqo7jvQnwQzhgMo4IPpn/5XSw51JWgJY+TG264jLH8TfoP+mtV7HQQkSzl0M78lzuF71nGiKW4UbkDFG7Sxl4Xx2zVAdLaMeuRhv5rL8tqUXGw64UjcogAqlxu3Wfg90jY9wsCehG9EBsKx/tLxgXZNjauBED95J0Y9hXKwwcpKgNtmIfQJi8jAY5Zphuogf8AEFWLi3jWUqRq2B3+dQGKMckX6V6bEnRmmqdMv2HFVhJAkQqwwytuGHYg86uuqT+eB9z/AJbtn6N/B+tA9KD8K/QVbtXCkAMqj44pquLtAp3plwoy+/HIvxU/uNq4SAcYORtjFXI+MrZmOK3kAlk/zjuIx3C9/U/SqySW54mySXpaMebxueo+ppkc7/0TgvQBVJHmEaKSew3yaTa1ONJGRnJ7Vp4LFYnkUx6VB0AHmwG2/pzOOud6A8Ql8a/nce6G0j4DalKVlyjSKT26OM5w3emqZ4T+dfrU4pwYKCScAVbQA6G4EgIxgkY/avSvZOzEPB43x5pSWPw5CvL1m8SUaFA+W9bHhPtDf2cMcDJFLGgwFOxUfEVy/m45TVRNWK60b0KKRUVnofauJtpbSVSNjoIYVOPaiyIyI7g//gf3rkPBNehlMGrYT2/tZqCt4cjM2rG2kioeOcHFtI11briJz94o/Ce/wojJ7UxFfubWRuxdgo/mhN9x26ukZCyRxsMFUHMepNasccvJOhkFIHwRq88auQF1rknoM1tX4rw+EajMjsOQQajWCMmDXfGOOdasvx/I02x0ocg7xXjkt6jRREwQHYgHzN8T0+FA2fCgDkKjaTNRls07FhUFSJGCj0VLls3Df0j+ahp0jB5nYbjOM/CkqkmuhFUjl5Xc2NxnmM1csbPxpVVYgzMcABedOht1HmlYIvrz+Q5mrSXiaDFbBo42GGc7O47f6R+p/Sr3LSKSrsbxW/hs7duHcPEYdtriZAN/9Cnt3PXlQa1tJbqTwoV1MelST25hmwR5TyNGvZ+NG4kpVSBjlTKWOOil9pbJbi/McEsr7sFJB7np+tZdASD6DJNXr+7W5jjijRlYnLD9qls7fwoDMy+QDXkj3iNx8v3pVcRkvs9AwAhjqGCDjFRMDO+kHCLzPc1ISzAnPmPX1rqjSmw8q0QokjCoukDbr61ajnQ6RNzU+Vs1TU5ANdDUMoKQcMjgwnJeBFOhgzc9ulWBNttQMuMaRuT0FXFuYzzbSezbUiWJI2Ys3Juy+ZfWmGTNQBs8jn4V3ftQqCNNjmlUHBO/PFIOGAKkEHqKjwqqQzkKTkgtgH+9PLqmFWNicZGVIGO/LJo6/AHPjuR1mwCScAcyarPKZdlOlD+I7E09sOQ0mtu3l0qPgCavWEkSSYkid422dGQMGH1pig1ujLkz8vrHSKcdvGQMyRgf1CphDakANMx9Iskn6bVJLBbx3cotn8SHIKMVwcHoc9RyqV0XICtqGOdPWK1dmW6dECBIdTWkbxFhpaRpCWYdtth+tWLJkt7iKWaFZo1PmQjOVPMVwsqYFPAyRp5+lXSSotGjvPZnht5EkttczRRsNS4w4x896itOCWXD21vd3ErDooCf81RsuKS8M+7nVmtWOSMbxnuPT0ojJPHcR+JBIsiHkVOapK1TGaXRj4OFyS28t5jNupwSa5cXC/ZJVVuaEVGsvEGtWgtNbx+86jlinJw6/mglDRaWRcuG2wDR6VqTE3+AYil2Cjmau5WO3cqjMqDY4/EeRP8AFR2Cpry5xtqxjOew/wC9qNTXdnL7NXuFP2t5FDE9TqFJdrdFmdHanZpqgty6cyelTKmBkfUj9hRKLekCxgXAyBgH9acEc8l+u1SqN/XvWr4Zw6Ca1jZ0JYjvRyjHGrkXFcujIxwF2YFANPvHkB86e6BRiPJPckgVuo+B2kTu8qMwAMmCeXw+lYy4nTw2mcHfcKCRjPICkKcGx0ccvTITfRAhhC2r1xt86KPxBpJ4G1s3j2yoVXYZGds9h1NCYYUEYMkal8nJIrsMxluXf8MY0r/P7Uvp2h7UpJKT7C0PhW5GnDP1cjcn+Ks30CG3jvLcBFZtEyKMAN0Yds9fWg+sk86M8Nb7RZ3Vr1kiJX+obj9qqMnGXIbkgpQ4pFJRVv7M4txMQNBOAapwvrwcbEZFXBr0AHOmt05fg5sUQyx6kLdqiikaGVZF5qcirR0yBY4iS7bEGnR8OdnkjbAdBk70hyXTGpUiK9v5buXxnC5O2ANqltuEXNzGJ+HyRnPvaJNJB7EGnRWQe0kYuo0nl1p3Dop1uCLcMsqjcr1Hr3FDGSitegmr7BksM/D+Dre290qmU6WjHPFUH4hdzIzSTsWYAMe4qOdWdAFycHlTRE4jxp3rWobbZmsVqMMd6hlzqYAnGc4FWoInV8lSKhZfO3xomlVFDkXAGR8B2p4NdC7DcVEyuzeUHFWkorRW2WI9zW/4HHGLGJid8d6wUEMvhlyvlFb3g0iLw6LK5OO1ZPly+qofiVF64EemUM4AMTDJbltXlLN4s0UecqgDGvQfaGRTwq6TBUyoI126k/8A2vPbzRaXWmAbaBnUc71kxDXKu+iaZykTt1xUNkdKN6tj9KVuWvJRC2FU7kjsKdeILJxHH5lcahqO4NN/QTyJy5eixmr3DLr7Pcxv0U5NBPtrY9wfWmm6kJ2OkelRxsZ54o0aKpllSIE6GONuYzt+lWpLt5bNU0gLHtyofwa+eNYgpGcNGfgd/wCKnkAV896NO+/Rn16EqkyeU4POr8MSNA7PLhxyH5qoRtplDNy61bZcctx3oZbDG9aLcJkCSEgjJGKFAZOKseG0E0Ykbw2P1FDLaopASG2tW4RLO9xpuVbyx96oBmojDw0afvW37CpRw+EHm2K3c0n2Z1Bg2PUWxmoWXzGjq20Ee+kfOnBYB+FfpVPKEsYGCbCmwSqHKv5d9qNv4Wg6UBPQAUMitdch8WPHYEVPJZOFDvFjCMquSSOQrQ8O4vBBaxxsTlRWfktzEY2VRq19B0o08UaN7q7gGk5OMlUg4pjfaPi0E3DNUeS6OrAHkeY/msPJI0kjO5yzHJrW8Vtkn4bMI1GsLqGPTesfS1GMf6gzu9k1vO1vMsi4JHQ9RXbm4a5l1sANsADoKgpVKV2BY5VY5wCcdq6FbPut9KdbtplHY7VczUsbCCkrHWLGAq8h0qGz65ApXNzJcyZGQo5AU04KEHkMH6UmOhw6DChvKabiSKyLjpBC2n8OILcZjcdGG9W4LxSQEkDAfhNCru5mvpfFnIL4AyBXJbeW2KlgcHcMKLxp99kWRoONMG90FepNDbu+uJGJIYIdgx5kV29juIIo0eVGEq6vKf3qCe9nlghglxohGFwKqGP2SU/SP//Z"

local B64CHARS = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local function b64decode(s)
    local lookup = {}
    for i = 1, #B64CHARS do lookup[B64CHARS:byte(i)] = i - 1 end
    local out, n = {}, 0
    local buf, bits = 0, 0
    for i = 1, #s do
        local v = lookup[s:byte(i)]
        if v then
            buf = bit32.bor(bit32.lshift(buf, 6), v)
            bits = bits + 6
            if bits >= 8 then
                bits = bits - 8
                n = n + 1
                out[n] = string.char(bit32.band(bit32.rshift(buf, bits), 255))
                buf = bit32.band(buf, bit32.lshift(1, bits) - 1)
            end
        end
    end
    return table.concat(out)
end

local Img = { asset = nil, targets = {} }

function Img.show(t)
    pcall(function()
        t.label.Image = Img.asset
        if t.face then t.face.Visible = false end
        local an = Anim.new(5, function(v) t.label.ImageTransparency = 1 + (t.final - 1) * v end, 0)
        an.t = 1
    end)
end

function Img.register(label, final, faceHolder)
    local t = { label = label, final = final, face = faceHolder }
    Img.targets[#Img.targets + 1] = t
    if Img.asset then Img.show(t) end
    return t
end

local function safeFile(fn, ...)
    if not fn then return false end
    local ok, r = pcall(fn, ...)
    return ok and r
end

function Img.resolve(url)
    if not (X.getasset and X.writefile) then return nil end
    safeFile(X.makefolder, CFG.FOLDER)
    -- 1) a link given by the user
    url = url or ((S.MillieURL ~= "" and S.MillieURL) or CFG.MILLIE_IMAGE_URL)
    if url and url ~= "" then
        local ok, data = pcall(function() return game:HttpGet(url) end)
        if ok and type(data) == "string" and #data > 200 then
            local ext
            if data:sub(1, 4) == "\137PNG" then ext = "png" elseif data:sub(1, 2) == "\255\216" then ext = "jpg" end
            if ext then
                local path = CFG.FOLDER .. "/millie_custom." .. ext
                if safeFile(X.writefile, path, data) ~= false then
                    local ok2, a = pcall(X.getasset, path)
                    if ok2 and a then return a end
                end
            end
        end
    end
    -- 2) a file the user dropped into the executor workspace
    for _, p in ipairs({ CFG.FOLDER .. "/millie.png", CFG.FOLDER .. "/millie.jpg", "millie.png", "millie.jpg" }) do
        if X.isfile and safeFile(X.isfile, p) then
            local ok2, a = pcall(X.getasset, p)
            if ok2 and a then return a end
        end
    end
    -- 3) the embedded art
    if #MILLIE_B64 > 100 then
        local path = CFG.FOLDER .. "/millie_embedded.jpg"
        local data = b64decode(MILLIE_B64)
        if #data > 100 then
            local exists = X.isfile and safeFile(X.isfile, path)
            local same = false
            if exists and X.readfile then
                local ok, cur = pcall(X.readfile, path)
                same = ok and type(cur) == "string" and #cur == #data
            end
            if not same then pcall(X.writefile, path, data) end
            local ok2, a = pcall(X.getasset, path)
            if ok2 and a then return a end
        end
    end
    return nil
end

function Img.load(url)
    task.spawn(function()
        local ok, a = pcall(Img.resolve, url)
        if not ok then Hub.err("image", a) end
        if ok and a then
            Img.asset = a
            for _, t in ipairs(Img.targets) do Img.show(t) end
        elseif url and url ~= "" then
            Hub.note("img", "Could not load that image link (needs a direct png/jpg).", "bad")
        end
    end)
end


----------------------------------------------------------------------
-- UI library  (dark red + yellow borders, lerp animations)
----------------------------------------------------------------------
local T = {
    bg = Color3.fromRGB(22, 5, 9),
    panel = Color3.fromRGB(46, 9, 16),
    panel2 = Color3.fromRGB(70, 14, 24),
    off = Color3.fromRGB(92, 36, 44),
    red = Color3.fromRGB(150, 20, 34),
    yellow = Color3.fromRGB(255, 205, 40),
    amber = Color3.fromRGB(255, 140, 30),
    text = Color3.fromRGB(255, 238, 222),
    muted = Color3.fromRGB(198, 152, 150),
    dark = Color3.fromRGB(40, 8, 12),
    ok = Color3.fromRGB(125, 232, 150),
    bad = Color3.fromRGB(255, 96, 96),
    skin = Color3.fromRGB(196, 38, 48),
    hair = Color3.fromRGB(62, 60, 74),
    horn = Color3.fromRGB(20, 15, 22),
    white = Color3.new(1, 1, 1),
    fTitle = Enum.Font.FredokaOne,
    fBody = Enum.Font.GothamMedium,
    fBold = Enum.Font.GothamBold,
}

local function mk(class, props, parent)
    local o = Instance.new(class)
    if props then
        for k, v in pairs(props) do o[k] = v end
    end
    if parent then o.Parent = parent end
    return o
end

local UI = {
    toggles = {}, sliders = {}, dropdowns = {}, tabs = {}, faces = {}, hooks = {},
    open = false, baseScale = 1, current = 1,
}

local WIN_W, WIN_H = 500, 316

function UI.hook(fn) UI.hooks[#UI.hooks + 1] = fn end

Hub.track(RunService.RenderStepped:Connect(function(dt)
    local t = os.clock()
    for _, fn in ipairs(UI.hooks) do
        local ok, e = pcall(fn, dt, t)
        if not ok then Hub.err("uihook", e) end
    end
end))

function UI.corner(o, r) return mk("UICorner", { CornerRadius = UDim.new(0, r) }, o) end
function UI.pill(o) return mk("UICorner", { CornerRadius = UDim.new(0.5, 0) }, o) end
function UI.stroke(o, color, th, tr)
    return mk("UIStroke", {
        Color = color or T.yellow, Thickness = th or 1, Transparency = tr or 0,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    }, o)
end

function UI.label(parent, text, props)
    local p = {
        BackgroundTransparency = 1, Text = text, TextColor3 = T.text, Font = T.fBody, TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, 0, 1, 0), BorderSizePixel = 0,
    }
    if props then
        for k, v in pairs(props) do p[k] = v end
    end
    return mk("TextLabel", p, parent)
end

local function isPress(i)
    return i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch
end

-- hover / press color lerp on a frame, driven by a transparent button on top of it
function UI.hoverFx(hit, frame, base, hi)
    local an = Anim.new(18, function(v) frame.BackgroundColor3 = base:Lerp(hi, v) end, 0)
    hit.MouseEnter:Connect(function() an.t = 0.45 end)
    hit.MouseLeave:Connect(function() an.t = 0 end)
    hit.InputBegan:Connect(function(i) if isPress(i) then an.t = 1 end end)
    hit.InputEnded:Connect(function(i) if isPress(i) then an.t = 0 end end)
    return an
end

function Hub.guiParent()
    if X.hui then
        local ok, p = pcall(X.hui)
        if ok and p then return p end
    end
    local ok, cg = pcall(function() return game:GetService("CoreGui") end)
    if ok and cg then
        local test = Instance.new("Folder")
        local ok2 = pcall(function() test.Parent = cg end)
        pcall(function() test:Destroy() end)
        if ok2 then return cg end
    end
    return LP:WaitForChild("PlayerGui")
end

function UI.viewport()
    local cam = Workspace.CurrentCamera
    local vp = cam and cam.ViewportSize
    if not vp or vp.X < 50 or vp.Y < 50 then vp = Vector2.new(800, 400) end
    return vp
end

----------------------------------------------------------------------
-- a tiny drawn Millie (used until the art loads, or when images are unsupported)
----------------------------------------------------------------------
function UI.drawFace(holder, px)
    local th = math.max(1, math.floor(px / 40))
    local f = {}
    local root = mk("Frame", { Name = "Face", Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1 }, holder)
    f.root = root
    local function horn(x, rot)
        local h = mk("Frame", {
            Size = UDim2.new(0.15, 0, 0.36, 0), Position = UDim2.new(x, 0, -0.14, 0), Rotation = rot,
            BackgroundColor3 = T.horn, BorderSizePixel = 0,
        }, root)
        UI.pill(h)
    end
    horn(0.14, -24)
    horn(0.71, 24)
    local disc = mk("Frame", { Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = T.skin, BorderSizePixel = 0 }, root)
    UI.pill(disc)
    UI.stroke(disc, T.yellow, th, 0)
    local hair = mk("Frame", {
        Position = UDim2.new(-0.04, 0, -0.05, 0), Size = UDim2.new(1.08, 0, 0.5, 0),
        BackgroundColor3 = T.hair, BorderSizePixel = 0,
    }, root)
    UI.corner(hair, math.max(4, math.floor(px * 0.2)))
    local eyes = {}
    for i, x in ipairs({ 0.16, 0.56 }) do
        local eye = mk("Frame", {
            Size = UDim2.new(0.28, 0, 0.24, 0), Position = UDim2.new(x, 0, 0.465, 0),
            BackgroundColor3 = Color3.fromRGB(255, 214, 40), BorderSizePixel = 0,
        }, root)
        UI.pill(eye)
        UI.stroke(eye, T.amber, th, 0.25)
        local pupil = mk("Frame", {
            Size = UDim2.new(0.34, 0, 0.62, 0), Position = UDim2.new(0.33, 0, 0.19, 0),
            BackgroundColor3 = Color3.fromRGB(20, 12, 16), BorderSizePixel = 0,
        }, eye)
        UI.pill(pupil)
        eyes[i] = { eye = eye, x = x }
    end
    local mouth = mk("Frame", {
        Size = UDim2.new(0.14, 0, 0.05, 0), Position = UDim2.new(0.43, 0, 0.82, 0),
        BackgroundColor3 = Color3.fromRGB(105, 12, 22), BorderSizePixel = 0,
    }, root)
    UI.pill(mouth)
    f.blink = Anim.new(40, function(v)
        local h = 0.24 * (1 - v) + 0.03 * v
        for _, e in ipairs(eyes) do
            e.eye.Size = UDim2.new(0.28, 0, h, 0)
            e.eye.Position = UDim2.new(e.x, 0, 0.585 - h / 2, 0)
        end
    end, 0)
    UI.faces[#UI.faces + 1] = f
    return f
end

-- round avatar: drawn face first, real art fades in over it when available
function UI.avatar(parent, px, pos, anchor)
    local av = mk("Frame", {
        Size = UDim2.new(0, px, 0, px), Position = pos, AnchorPoint = anchor or Vector2.new(0, 0),
        BackgroundTransparency = 1,
    }, parent)
    local face = UI.drawFace(av, px)
    local art = mk("ImageLabel", {
        Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, ImageTransparency = 1,
        ScaleType = Enum.ScaleType.Crop, ZIndex = 2, BorderSizePixel = 0, Image = "",
    }, av)
    UI.pill(art)
    local st = UI.stroke(art, T.yellow, math.max(1.5, px / 28), 0)
    Img.register(art, 0, face.root)
    return av, st, art
end

----------------------------------------------------------------------
-- pages and widgets
----------------------------------------------------------------------
local Page = {}
Page.__index = Page

function UI.newPage(name)
    local frame = mk("ScrollingFrame", {
        Name = name, Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, BorderSizePixel = 0,
        ScrollBarThickness = 3, ScrollBarImageColor3 = T.yellow, CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollingDirection = Enum.ScrollingDirection.Y,
        Visible = false,
    }, UI.pagesHolder)
    mk("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, frame)
    mk("UIPadding", {
        PaddingTop = UDim.new(0, 2), PaddingBottom = UDim.new(0, 10),
        PaddingLeft = UDim.new(0, 2), PaddingRight = UDim.new(0, 6),
    }, frame)
    return setmetatable({ frame = frame, order = 0, name = name }, Page)
end

function Page:_next()
    self.order = self.order + 1
    return self.order
end

function Page:_row(h)
    local row = mk("Frame", {
        Size = UDim2.new(1, -4, 0, h), BackgroundColor3 = T.panel, BackgroundTransparency = 0.08,
        BorderSizePixel = 0, LayoutOrder = self:_next(),
    }, self.frame)
    UI.corner(row, 8)
    UI.stroke(row, T.yellow, 1, 0.78)
    return row
end

function Page:Section(text)
    local row = mk("Frame", {
        Size = UDim2.new(1, -4, 0, 24), BackgroundTransparency = 1, LayoutOrder = self:_next(),
    }, self.frame)
    UI.label(row, text, {
        Position = UDim2.new(0, 4, 0, 0), Size = UDim2.new(1, -8, 1, -3),
        Font = T.fTitle, TextSize = 15, TextColor3 = T.yellow,
    })
    mk("Frame", {
        Position = UDim2.new(0, 4, 1, -2), Size = UDim2.new(1, -8, 0, 1),
        BackgroundColor3 = T.yellow, BackgroundTransparency = 0.7, BorderSizePixel = 0,
    }, row)
end

function Page:Paragraph(text, color)
    local lbl = mk("TextLabel", {
        Size = UDim2.new(1, -4, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = T.panel, BackgroundTransparency = 0.25, BorderSizePixel = 0,
        Text = text, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top, Font = T.fBody, TextSize = 12,
        TextColor3 = color or T.muted, LayoutOrder = self:_next(),
    }, self.frame)
    UI.corner(lbl, 8)
    mk("UIPadding", {
        PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8),
        PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10),
    }, lbl)
    local h = {}
    function h.Set(t) lbl.Text = t end
    return h
end

function Page:Toggle(text, key, cb)
    local row = self:_row(34)
    local lbl = UI.label(row, text, { Position = UDim2.new(0, 10, 0, 0), Size = UDim2.new(1, -66, 1, 0) })
    local sw = mk("Frame", {
        Size = UDim2.new(0, 40, 0, 20), Position = UDim2.new(1, -50, 0.5, -10),
        BackgroundColor3 = T.off, BorderSizePixel = 0,
    }, row)
    UI.pill(sw)
    local knob = mk("Frame", {
        Size = UDim2.new(0, 16, 0, 16), Position = UDim2.new(0, 2, 0.5, -8),
        BackgroundColor3 = T.text, BorderSizePixel = 0,
    }, sw)
    UI.pill(knob)
    local hit = mk("TextButton", {
        Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Text = "", ZIndex = 5,
    }, row)
    UI.hoverFx(hit, row, T.panel, T.panel2)
    local an = Anim.new(16, function(v)
        knob.Position = UDim2.new(0, 2 + 20 * v, 0.5, -8)
        sw.BackgroundColor3 = T.off:Lerp(T.yellow, v)
        lbl.TextColor3 = T.muted:Lerp(T.text, 0.35 + 0.65 * v)
    end, S[key] and 1 or 0)
    local h = {}
    function h.Set(v, silent)
        v = v and true or false
        S[key] = v
        an.t = v and 1 or 0
        Hub.dirty()
        if cb and not silent then
            local ok, e = pcall(cb, v)
            if not ok then Hub.err("ui:" .. key, e) end
        end
    end
    hit.Activated:Connect(function() h.Set(not S[key]) end)
    UI.toggles[key] = h
    return h
end

function Page:Chips(text, items)
    local row = self:_row(54)
    UI.label(row, text, { Position = UDim2.new(0, 10, 0, 3), Size = UDim2.new(1, -20, 0, 20) })
    local holder = mk("Frame", {
        Position = UDim2.new(0, 10, 0, 26), Size = UDim2.new(1, -20, 0, 22), BackgroundTransparency = 1,
    }, row)
    mk("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, holder)
    for idx, it in ipairs(items) do
        local chip = mk("TextButton", {
            Size = UDim2.new(0, 44, 1, 0), LayoutOrder = idx, Text = it.label, Font = T.fBold, TextSize = 13,
            AutoButtonColor = false, BackgroundColor3 = T.off, TextColor3 = T.muted, BorderSizePixel = 0,
        }, holder)
        UI.corner(chip, 6)
        local key = it.key
        local an = Anim.new(18, function(v)
            chip.BackgroundColor3 = T.off:Lerp(T.yellow, v)
            chip.TextColor3 = T.muted:Lerp(T.dark, v)
        end, S[key] and 1 or 0)
        local h = {}
        function h.Set(v)
            S[key] = v and true or false
            an.t = S[key] and 1 or 0
            Hub.dirty()
        end
        chip.Activated:Connect(function() h.Set(not S[key]) end)
        UI.toggles[key] = h
    end
end

function Page:Slider(text, key, min, max, step, suffix, cb)
    local row = self:_row(46)
    UI.label(row, text, { Position = UDim2.new(0, 10, 0, 4), Size = UDim2.new(1, -96, 0, 18) })
    local valLbl = UI.label(row, "", {
        Position = UDim2.new(1, -90, 0, 4), Size = UDim2.new(0, 80, 0, 18),
        TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = T.yellow, Font = T.fBold,
    })
    local track = mk("Frame", {
        Position = UDim2.new(0, 12, 0, 31), Size = UDim2.new(1, -24, 0, 6),
        BackgroundColor3 = T.off, BorderSizePixel = 0,
    }, row)
    UI.pill(track)
    local fill = mk("Frame", { Size = UDim2.new(0, 0, 1, 0), BackgroundColor3 = T.yellow, BorderSizePixel = 0 }, track)
    UI.pill(fill)
    local knob = mk("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, 0, 0.5, 0),
        Size = UDim2.new(0, 16, 0, 16), BackgroundColor3 = T.text, BorderSizePixel = 0,
    }, track)
    UI.pill(knob)
    UI.stroke(knob, T.yellow, 2, 0)
    local hit = mk("TextButton", {
        Position = UDim2.new(0, 0, 0, 20), Size = UDim2.new(1, 0, 0, 26),
        BackgroundTransparency = 1, Text = "", ZIndex = 5,
    }, row)
    local function frac(v) return (v - min) / (max - min) end
    local an = Anim.new(22, function(f)
        fill.Size = UDim2.new(f, 0, 1, 0)
        knob.Position = UDim2.new(f, 0, 0.5, 0)
    end, Util.clamp(frac(S[key]), 0, 1))
    local function show() valLbl.Text = Util.fmt(S[key]) .. (suffix or "") end
    show()
    local h = {}
    function h.Set(v, silent)
        v = Util.clamp(Util.round(v, step), min, max)
        S[key] = v
        an.t = frac(v)
        show()
        Hub.dirty()
        if cb and not silent then
            local ok, e = pcall(cb, v)
            if not ok then Hub.err("ui:" .. key, e) end
        end
    end
    local dragging, dragInput = false, nil
    local function fromX(x)
        local w = track.AbsoluteSize.X
        if w <= 0 then return end
        local f = Util.clamp((x - track.AbsolutePosition.X) / w, 0, 1)
        h.Set(min + f * (max - min))
    end
    hit.InputBegan:Connect(function(i)
        if isPress(i) then
            dragging, dragInput = true, i
            self.frame.ScrollingEnabled = false
            fromX(i.Position.X)
        end
    end)
    Hub.track(UIS.InputChanged:Connect(function(i)
        if dragging and (i == dragInput or i.UserInputType == Enum.UserInputType.MouseMovement) then
            fromX(i.Position.X)
        end
    end))
    Hub.track(UIS.InputEnded:Connect(function(i)
        if dragging and (i == dragInput or i.UserInputType == Enum.UserInputType.MouseButton1) then
            dragging = false
            self.frame.ScrollingEnabled = true
        end
    end))
    UI.sliders[key] = h
    return h
end

function Page:Dropdown(text, key, getOpts, cb)
    local row = self:_row(34)
    row.ClipsDescendants = true
    UI.label(row, text, { Position = UDim2.new(0, 10, 0, 0), Size = UDim2.new(1, -176, 0, 34) })
    local box = mk("TextButton", {
        Position = UDim2.new(1, -160, 0, 5), Size = UDim2.new(0, 150, 0, 24),
        BackgroundColor3 = T.panel2, Text = "", AutoButtonColor = false, BorderSizePixel = 0,
    }, row)
    UI.corner(box, 6)
    UI.stroke(box, T.yellow, 1, 0.55)
    local val = UI.label(box, tostring(S[key]), {
        Position = UDim2.new(0, 8, 0, 0), Size = UDim2.new(1, -26, 1, 0), TextSize = 12,
        TextTruncate = Enum.TextTruncate.AtEnd,
    })
    local arrow = UI.label(box, "v", {
        Position = UDim2.new(1, -20, 0, 0), Size = UDim2.new(0, 16, 1, 0),
        TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = T.yellow, Font = T.fBold, TextSize = 12,
    })
    local list = mk("ScrollingFrame", {
        Position = UDim2.new(0, 8, 0, 38), Size = UDim2.new(1, -16, 0, 0),
        BackgroundColor3 = T.bg, BackgroundTransparency = 0.25, BorderSizePixel = 0,
        ScrollBarThickness = 3, ScrollBarImageColor3 = T.yellow, CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y, Visible = false,
    }, row)
    UI.corner(list, 6)
    mk("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder }, list)
    mk("UIPadding", {
        PaddingTop = UDim.new(0, 2), PaddingBottom = UDim.new(0, 2),
        PaddingLeft = UDim.new(0, 2), PaddingRight = UDim.new(0, 4),
    }, list)
    local listH = 0
    local isOpen = false
    local an = Anim.new(18, function(v)
        row.Size = UDim2.new(1, -4, 0, 34 + (listH + 8) * v)
        arrow.Rotation = 180 * v
        list.Visible = v > 0.02
    end, 0)
    local h = {}
    local NONE = "(nothing found)"
    local function build()
        for _, c in ipairs(list:GetChildren()) do
            if c:IsA("TextButton") then c:Destroy() end
        end
        local opts = {}
        local ok, r = pcall(getOpts)
        if ok and type(r) == "table" then opts = r end
        if #opts == 0 then opts = { NONE } end
        for i, o in ipairs(opts) do
            local sel = (o == S[key])
            local b = mk("TextButton", {
                Size = UDim2.new(1, 0, 0, 24), LayoutOrder = i, BackgroundColor3 = T.panel2,
                BackgroundTransparency = sel and 0 or 0.6, Text = tostring(o), Font = T.fBody, TextSize = 12,
                TextColor3 = sel and T.yellow or T.text, AutoButtonColor = false,
                TextTruncate = Enum.TextTruncate.AtEnd, BorderSizePixel = 0,
            }, list)
            UI.corner(b, 5)
            b.Activated:Connect(function()
                if o ~= NONE then h.Set(o) end
                h.Close()
            end)
        end
        local n = math.min(#opts, 5)
        listH = n * 24 + (n - 1) * 2 + 4
        list.Size = UDim2.new(1, -16, 0, listH)
        list.CanvasPosition = Vector2.new(0, 0)
    end
    function h.Set(v, silent)
        S[key] = v
        val.Text = tostring(v)
        Hub.dirty()
        if cb and not silent then
            local ok, e = pcall(cb, v)
            if not ok then Hub.err("ui:" .. key, e) end
        end
    end
    function h.Open()
        build()
        isOpen = true
        an.t = 1
    end
    function h.Close()
        isOpen = false
        an.t = 0
    end
    box.Activated:Connect(function()
        if isOpen then h.Close() else h.Open() end
    end)
    UI.dropdowns[key] = h
    return h
end

function Page:Button(text, cb, accent)
    local row = self:_row(34)
    local base = accent and T.yellow or T.panel2
    local hi = accent and Color3.fromRGB(255, 232, 120) or T.red
    row.BackgroundColor3 = base
    local btn = mk("TextButton", {
        Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Text = text, Font = T.fBold, TextSize = 13,
        TextColor3 = accent and T.dark or T.text, AutoButtonColor = false, ZIndex = 5,
    }, row)
    UI.hoverFx(btn, row, base, hi)
    btn.Activated:Connect(function()
        local ok, e = pcall(cb)
        if not ok then Hub.err("btn:" .. text, e) end
    end)
    return btn
end

function Page:Input(text, placeholder, initial, cb)
    local row = self:_row(34)
    UI.label(row, text, { Position = UDim2.new(0, 10, 0, 0), Size = UDim2.new(0, 104, 1, 0) })
    local box = mk("TextBox", {
        Position = UDim2.new(0, 116, 0, 5), Size = UDim2.new(1, -168, 0, 24), BackgroundColor3 = T.bg,
        Text = initial or "", PlaceholderText = placeholder or "", PlaceholderColor3 = T.muted,
        TextColor3 = T.text, Font = T.fBody, TextSize = 12, ClearTextOnFocus = false,
        TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, BorderSizePixel = 0,
    }, row)
    UI.corner(box, 6)
    UI.stroke(box, T.yellow, 1, 0.5)
    local go = mk("TextButton", {
        Position = UDim2.new(1, -46, 0, 5), Size = UDim2.new(0, 38, 0, 24), BackgroundColor3 = T.yellow,
        Text = "OK", Font = T.fBold, TextSize = 12, TextColor3 = T.dark, AutoButtonColor = false, BorderSizePixel = 0,
    }, row)
    UI.corner(go, 6)
    local function submit()
        local ok, e = pcall(cb, box.Text)
        if not ok then Hub.err("input", e) end
    end
    go.Activated:Connect(submit)
    box.FocusLost:Connect(function(enter) if enter then submit() end end)
    return box
end

----------------------------------------------------------------------
-- toast
----------------------------------------------------------------------
function UI.buildToast(gui)
    local f = mk("Frame", {
        Name = "Toast", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, -60),
        Size = UDim2.new(0, 300, 0, 34), BackgroundColor3 = T.bg, BorderSizePixel = 0, ZIndex = 50,
    }, gui)
    UI.corner(f, 10)
    local st = UI.stroke(f, T.yellow, 1.5, 0)
    local lbl = UI.label(f, "", {
        ZIndex = 51, TextXAlignment = Enum.TextXAlignment.Center, TextSize = 12, Font = T.fBold,
        Position = UDim2.new(0, 8, 0, 0), Size = UDim2.new(1, -16, 1, 0), TextTruncate = Enum.TextTruncate.AtEnd,
    })
    local an = Anim.new(14, function(v) f.Position = UDim2.new(0.5, 0, 0, -60 + 76 * v) end, 0)
    local token = 0
    Hub.toastFn = function(text, kind)
        token = token + 1
        local mine = token
        text = tostring(text)
        lbl.Text = text
        f.Size = UDim2.new(0, Util.clamp(#text * 7 + 40, 190, 520), 0, 34)
        local col = T.yellow
        if kind == "bad" then col = T.bad elseif kind == "ok" then col = T.ok end
        st.Color = col
        lbl.TextColor3 = (kind == "bad" or kind == "ok") and col or T.text
        an.t = 1
        task.delay(3.4, function()
            if token == mine then an.t = 0 end
        end)
    end
end

----------------------------------------------------------------------
-- main window
----------------------------------------------------------------------
function UI.fit()
    local vp = UI.viewport()
    local s = math.min(vp.X * 0.94 / WIN_W, vp.Y * 0.92 / WIN_H, 1.25) * S.UIScale
    UI.baseScale = Util.clamp(s, 0.45, 1.6)
    if UI.winAnim then pcall(UI.winAnim.apply, UI.winAnim.v) end
end

function UI.setOpen(open)
    UI.open = open and true or false
    if UI.winAnim then UI.winAnim.t = UI.open and 1 or 0 end
end

function UI.toggleOpen() UI.setOpen(not UI.open) end

function UI.select(idx)
    UI.current = idx
    for i, t in ipairs(UI.tabs) do
        t.sel.t = (i == idx) and 1 or 0
        if i == idx then
            t.page.frame.Visible = true
            t.slide.v = 0
            t.slide.t = 1
        else
            t.page.frame.Visible = false
        end
    end
end

function UI.addTab(name)
    local idx = #UI.tabs + 1
    local btn = mk("TextButton", {
        Size = UDim2.new(1, -6, 0, 26), LayoutOrder = idx, BackgroundColor3 = T.panel2,
        BackgroundTransparency = 1, Text = "", AutoButtonColor = false, BorderSizePixel = 0,
    }, UI.sidebar)
    UI.corner(btn, 8)
    local lbl = UI.label(btn, name, { Position = UDim2.new(0, 14, 0, 0), Size = UDim2.new(1, -16, 1, 0), Font = T.fBold, TextSize = 13 })
    local bar = mk("Frame", {
        AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 3, 0.5, 0), Size = UDim2.new(0, 3, 0, 0),
        BackgroundColor3 = T.yellow, BorderSizePixel = 0,
    }, btn)
    UI.pill(bar)
    local page = UI.newPage(name)
    local sel = Anim.new(16, function(v)
        btn.BackgroundTransparency = 1 - 0.8 * v
        lbl.TextColor3 = T.muted:Lerp(T.yellow, v)
        bar.Size = UDim2.new(0, 3, 0, 18 * v)
    end, 0)
    local slide = Anim.new(14, function(v)
        page.frame.Position = UDim2.new(0.07 * (1 - v), 0, 0, 0)
    end, 1)
    UI.tabs[idx] = { btn = btn, lbl = lbl, page = page, sel = sel, slide = slide, name = name }
    btn.Activated:Connect(function() UI.select(idx) end)
    return page
end

function UI.build()
    local gui = mk("ScreenGui", {
        Name = "mh" .. rname(8), ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 999,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    }, nil)
    gui.Parent = Hub.guiParent()
    Hub.gui = gui
    UI.gui = gui

    UI.buildToast(gui)

    local win = mk("Frame", {
        Name = "Win", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 0),
        Size = UDim2.new(0, WIN_W, 0, WIN_H), BackgroundTransparency = 1, Visible = false, ZIndex = 5,
    }, gui)
    UI.win = win
    local uiScale = mk("UIScale", { Scale = 1 }, win)
    local group = mk("CanvasGroup", {
        Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, GroupTransparency = 1, BorderSizePixel = 0,
    }, win)
    local body = mk("Frame", {
        Position = UDim2.new(0, 3, 0, 3), Size = UDim2.new(1, -6, 1, -6),
        BackgroundColor3 = T.white, BorderSizePixel = 0,
    }, group)
    UI.corner(body, 16)
    mk("UIGradient", {
        Color = ColorSequence.new(Color3.fromRGB(62, 10, 19), Color3.fromRGB(14, 3, 6)), Rotation = 60,
    }, body)
    local edge = UI.stroke(body, T.white, 2.5, 0)
    local edgeGrad = mk("UIGradient", {
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, T.yellow),
            ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 120, 30)),
            ColorSequenceKeypoint.new(1, T.yellow),
        }),
        Rotation = 0,
    }, edge)
    UI.hook(function(dt, t) edgeGrad.Rotation = (t * 45) % 360 end)

    -- faint Millie art behind everything
    local art = mk("ImageLabel", {
        Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, ImageTransparency = 1,
        ScaleType = Enum.ScaleType.Crop, BorderSizePixel = 0, Image = "", ZIndex = 1,
    }, body)
    UI.corner(art, 16)
    Img.register(art, 0.84, nil)

    -- header
    local header = mk("Frame", {
        Size = UDim2.new(1, 0, 0, 44), BackgroundTransparency = 1, Active = true, ZIndex = 2,
    }, body)
    UI.avatar(header, 30, UDim2.new(0, 12, 0, 7))
    UI.label(header, "MILLIE HUB", {
        Position = UDim2.new(0, 52, 0, 3), Size = UDim2.new(0, 200, 0, 24), Font = T.fTitle, TextSize = 21,
        TextColor3 = T.yellow, ZIndex = 3,
    })
    UI.subtitle = UI.label(header, "Legacy Piece  |  v" .. CFG.VERSION, {
        Position = UDim2.new(0, 53, 0, 26), Size = UDim2.new(0, 300, 0, 14), TextSize = 10, TextColor3 = T.muted, ZIndex = 3,
    })
    mk("Frame", {
        Position = UDim2.new(0, 10, 1, -1), Size = UDim2.new(1, -20, 0, 1),
        BackgroundColor3 = T.yellow, BackgroundTransparency = 0.6, BorderSizePixel = 0,
    }, header)

    local function headBtn(txt, xoff)
        local b = mk("TextButton", {
            Position = UDim2.new(1, xoff, 0, 8), Size = UDim2.new(0, 28, 0, 28), BackgroundColor3 = T.panel2,
            Text = txt, Font = T.fBold, TextSize = 16, TextColor3 = T.text, AutoButtonColor = false,
            BorderSizePixel = 0, ZIndex = 4,
        }, header)
        UI.pill(b)
        UI.stroke(b, T.yellow, 1.5, 0.3)
        UI.hoverFx(b, b, T.panel2, T.red)
        return b
    end
    local minBtn = headBtn("-", -72)
    local closeBtn = headBtn("x", -38)
    minBtn.Activated:Connect(function() UI.setOpen(false) end)
    local armed = 0
    closeBtn.Activated:Connect(function()
        if os.clock() - armed < 2 then
            Hub.Destroy()
        else
            armed = os.clock()
            closeBtn.Text = "?"
            Hub.note("closehint", "Tap x again to unload the hub.", "force")
            task.delay(2, function()
                if closeBtn.Parent then closeBtn.Text = "x" end
            end)
        end
    end)

    -- window dragging (header)
    UI.wx = Anim.new(20, function() end, 0)
    UI.wy = Anim.new(20, function() end, 0)
    local function applyPos() win.Position = UDim2.new(0.5, UI.wx.v, 0.5, UI.wy.v) end
    UI.wx.apply = applyPos
    UI.wy.apply = applyPos
    local dragging, dragInput, startPos, startX, startY = false, nil, nil, 0, 0
    header.InputBegan:Connect(function(i)
        if isPress(i) then
            dragging, dragInput, startPos = true, i, i.Position
            startX, startY = UI.wx.t, UI.wy.t
        end
    end)
    Hub.track(UIS.InputChanged:Connect(function(i)
        if dragging and (i == dragInput or i.UserInputType == Enum.UserInputType.MouseMovement) then
            local d = i.Position - startPos
            local vp = UI.viewport()
            local lx = vp.X / 2 - 60
            local ly = vp.Y / 2 - 30
            UI.wx.t = Util.clamp(startX + d.X, -lx, lx)
            UI.wy.t = Util.clamp(startY + d.Y, -ly, ly)
        end
    end))
    Hub.track(UIS.InputEnded:Connect(function(i)
        if dragging and (i == dragInput or i.UserInputType == Enum.UserInputType.MouseButton1) then dragging = false end
    end))
    function UI.resetPos()
        UI.wx.t = 0
        UI.wy.t = 0
    end

    -- sidebar
    UI.sidebar = mk("ScrollingFrame", {
        Position = UDim2.new(0, 8, 0, 48), Size = UDim2.new(0, 100, 1, -54), BackgroundTransparency = 1,
        BorderSizePixel = 0, ScrollBarThickness = 0, CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y, ZIndex = 2,
    }, body)
    mk("UIListLayout", { Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder }, UI.sidebar)

    -- pages + status bar
    UI.pagesHolder = mk("Frame", {
        Position = UDim2.new(0, 116, 0, 50), Size = UDim2.new(1, -124, 1, -78), BackgroundTransparency = 1,
        ClipsDescendants = true, ZIndex = 2,
    }, body)
    local status = mk("Frame", {
        Position = UDim2.new(0, 116, 1, -26), Size = UDim2.new(1, -124, 0, 20), BackgroundColor3 = T.panel,
        BackgroundTransparency = 0.3, BorderSizePixel = 0, ZIndex = 2,
    }, body)
    UI.corner(status, 6)
    UI.statusLbl = UI.label(status, "Idle", {
        Position = UDim2.new(0, 8, 0, 0), Size = UDim2.new(1, -16, 1, 0), TextSize = 11, TextColor3 = T.muted,
        TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 3,
    })
    local lastStatus = ""
    UI.hook(function()
        if Hub.status ~= lastStatus then
            lastStatus = Hub.status
            UI.statusLbl.Text = lastStatus
        end
    end)

    -- open / close animation
    UI.winAnim = Anim.new(13, function(v)
        win.Visible = v > 0.01
        group.GroupTransparency = 1 - v
        uiScale.Scale = UI.baseScale * (0.86 + 0.14 * v)
    end, 0)
    UI.fit()
    local lastVp = UI.viewport()
    UI.hook(function()
        local vp = UI.viewport()
        if vp ~= lastVp then
            lastVp = vp
            UI.fit()
        end
    end)
end

----------------------------------------------------------------------
-- floating "jv" bubble (tap = open / minimize, drag = move)
----------------------------------------------------------------------
function UI.buildBubble()
    local gui = UI.gui
    local vp = UI.viewport()
    local b = mk("Frame", {
        Name = "Bubble", Size = UDim2.new(0, 54, 0, 54), Position = UDim2.new(0, 12, 0, math.floor(vp.Y * 0.4)),
        BackgroundTransparency = 1, Visible = false, ZIndex = 20,
    }, gui)
    UI.bubble = b
    local ring = mk("Frame", {
        Position = UDim2.new(0, -8, 0, -8), Size = UDim2.new(1, 16, 1, 16), BackgroundColor3 = T.yellow,
        BackgroundTransparency = 0.82, BorderSizePixel = 0, ZIndex = 20,
    }, b)
    UI.pill(ring)
    local core = mk("Frame", {
        Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = T.white, BorderSizePixel = 0, ZIndex = 21,
    }, b)
    UI.pill(core)
    mk("UIGradient", {
        Color = ColorSequence.new(Color3.fromRGB(150, 22, 36), Color3.fromRGB(62, 8, 16)), Rotation = 90,
    }, core)
    UI.stroke(core, T.yellow, 2.5, 0)
    local btn = mk("TextButton", {
        Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Text = "jv", Font = T.fTitle, TextSize = 24,
        TextColor3 = T.yellow, AutoButtonColor = false, ZIndex = 22,
    }, b)
    UI.hook(function(dt, t)
        local p = (math.sin(t * 2.6) + 1) / 2
        ring.BackgroundTransparency = 0.9 - 0.12 * p
        ring.Size = UDim2.new(1, 12 + 8 * p, 1, 12 + 8 * p)
        ring.Position = UDim2.new(0, -(6 + 4 * p), 0, -(6 + 4 * p))
    end)

    local bx = Anim.new(18, function() end, 12)
    local by = Anim.new(18, function() end, math.floor(vp.Y * 0.4))
    local function applyPos() b.Position = UDim2.new(0, bx.v, 0, by.v) end
    bx.apply = applyPos
    by.apply = applyPos
    local pressAnim = Anim.new(22, function(v) core.Size = UDim2.new(1 - 0.12 * v, 0, 1 - 0.12 * v, 0)
        core.Position = UDim2.new(0.06 * v, 0, 0.06 * v, 0) end, 0)

    local dragging, dragInput, startPos, ox, oy, moved = false, nil, nil, 0, 0, false
    btn.InputBegan:Connect(function(i)
        if isPress(i) then
            dragging, dragInput, startPos, moved = true, i, i.Position, false
            ox, oy = bx.t, by.t
            pressAnim.t = 1
        end
    end)
    Hub.track(UIS.InputChanged:Connect(function(i)
        if dragging and (i == dragInput or i.UserInputType == Enum.UserInputType.MouseMovement) then
            local d = i.Position - startPos
            if d.Magnitude > 9 then moved = true end
            if moved then
                local v = UI.viewport()
                bx.t = Util.clamp(ox + d.X, 4, v.X - 58)
                by.t = Util.clamp(oy + d.Y, 4, v.Y - 58)
            end
        end
    end))
    Hub.track(UIS.InputEnded:Connect(function(i)
        if dragging and (i == dragInput or i.UserInputType == Enum.UserInputType.MouseButton1) then
            dragging = false
            pressAnim.t = 0
            if moved then
                local v = UI.viewport()
                bx.t = (bx.t + 27 < v.X / 2) and 8 or (v.X - 62)
            else
                UI.toggleOpen()
            end
        end
    end))
    function UI.showBubble(on) b.Visible = on and true or false end
end


----------------------------------------------------------------------
-- forward declarations (all modules exist before any function body is compiled)
----------------------------------------------------------------------
local Prompts = { set = setmetatable({}, { __mode = "k" }) }
local Mobs = { set = {}, known = {}, pending = setmetatable({}, { __mode = "k" }), cache = nil, cacheT = 0 }
Mobs.black = setmetatable({}, { __mode = "k" })
Mobs.retry = setmetatable({}, { __mode = "k" })
local Mover = { intent = nil, owner = nil, bv = nil }
local Equip = { lastKey = 0 }
local Attack = { methods = { "tool", "click", "button", "vuser" }, idx = 1, watch = {}, btn = nil, btnT = 0 }
local Farm = { target = nil, spot = nil, spotOff = 0 }
local Quest = { prompts = {}, last = 0, first = false, doneConsumed = false, progT = 0, progV = "none", info = "No quest run yet." }
local POI = { islands = {}, npcs = {} }
local TP = {}
local Misc = {}
local Scan = {}
local Hitbox = { orig = setmetatable({}, { __mode = "k" }) }
local Reach = { orig = setmetatable({}, { __mode = "k" }) }
local Bring = {}
local Cfg = {}
local DB, Spy, Items, Boss, Prestige = {}, {}, {}, {}, {}

local KEYS = {
    Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three, Enum.KeyCode.Four, Enum.KeyCode.Five,
    Enum.KeyCode.Six, Enum.KeyCode.Seven, Enum.KeyCode.Eight, Enum.KeyCode.Nine,
}

function Util.cfAt(pos)
    local r = Util.root()
    if r then return CFrame.new(pos) * (r.CFrame - r.CFrame.Position) end
    return CFrame.new(pos)
end

function Util.owned(part)
    if not X.isowner then return true end
    local ok, r = pcall(X.isowner, part)
    return ok and r == true
end

function UI.rects()
    local out = {}
    for _, o in ipairs({ UI.win, UI.bubble }) do
        if o and o.Visible then
            local p, s = o.AbsolutePosition, o.AbsoluteSize
            out[#out + 1] = { p.X, p.Y, p.X + s.X, p.Y + s.Y }
        end
    end
    return out
end

-- a screen point that is not covered by this hub's own window / bubble
function Util.freeClickPoint()
    local vp = UI.viewport()
    local rects = UI.rects()
    for _ = 1, 12 do
        local x = vp.X * Util.rand(0.3, 0.7)
        local y = vp.Y * Util.rand(0.25, 0.6)
        local free = true
        for _, r in ipairs(rects) do
            if x >= r[1] - 12 and x <= r[3] + 12 and y >= r[2] - 12 and y <= r[4] + 12 then
                free = false
                break
            end
        end
        if free then return x, y end
    end
    return vp.X * 0.5, vp.Y * 0.4
end

----------------------------------------------------------------------
-- player level (best effort)
----------------------------------------------------------------------
function Util.playerLevel()
    local function numOf(inst)
        if inst and inst:IsA("ValueBase") and type(inst.Value) == "number" then return inst.Value end
        return nil
    end
    local ls = LP:FindFirstChild("leaderstats")
    if ls then
        local v = numOf(ls:FindFirstChild("Level")) or numOf(ls:FindFirstChild("Lvl")) or numOf(ls:FindFirstChild("level"))
        if v then return v end
    end
    local a = LP:GetAttribute("Level") or LP:GetAttribute("Lvl")
    if type(a) == "number" then return a end
    for _, fn in ipairs({ "Data", "PlayerData", "Stats", "Profile" }) do
        local f = LP:FindFirstChild(fn)
        if f then
            local v = numOf(f:FindFirstChild("Level")) or numOf(f:FindFirstChild("Lvl"))
            if v then return v end
        end
    end
    local c = LP.Character
    if c then
        local ca = c:GetAttribute("Level")
        if type(ca) == "number" then return ca end
    end
    return Util.guiLevel()
end

----------------------------------------------------------------------
-- mobs registry (incremental, works with StreamingEnabled)
----------------------------------------------------------------------
local NPC_WORDS = {
    "shop", "merchant", "dealer", "trainer", "quest", "vendor", "seller", "banker", "blacksmith", "guide",
    "mission", "gacha", "prestige", "fisherman", "reroll", "teacher", "tracker", "rewards",
}

function Mobs.normBase(name)
    local n = name
    n = n:gsub("%b[]", "")
    n = n:gsub("%b()", "")
    n = n:gsub("[Ll][Vv][Ll]?[%.%s:]*%d+", "")
    n = n:gsub("%d+$", "")
    n = n:gsub("^%s+", "")
    n = n:gsub("%s+$", "")
    if n == "" then n = name end
    return n
end

function Mobs.parseLevel(model, hum)
    local lv = model:GetAttribute("Level") or model:GetAttribute("Lvl")
    if type(lv) == "number" then return lv end
    local v = model:FindFirstChild("Level") or model:FindFirstChild("Lvl")
    if v and v:IsA("ValueBase") and type(v.Value) == "number" then return v.Value end
    for _, s in ipairs({ model.Name, (hum and hum.DisplayName) or "" }) do
        local n = s:match("[Ll][Vv][Ll]?[%.%s:]*(%d+)") or s:match("[Ll]evel[%s:]*(%d+)") or s:match("%[(%d+)%]")
        if n then return tonumber(n) end
    end
    -- Fallbacks are limited to the matching experience PlaceId; never apply
    -- a public level list to a different game with similarly named enemies.
    if DB.mobLevelsPlaceId == game.PlaceId and type(DB.mobLevels) == "table" then
        local key = model.Name:lower():gsub("[^%w]+", " "):gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
        local fallback = DB.mobLevels[key]
        if type(fallback) == "number" then return fallback end
    end
    return nil
end

function Mobs.looksLikeNPC(model)
    local l = model.Name:lower()
    for _, w in ipairs(NPC_WORDS) do
        if l:find(w, 1, true) then return true end
    end

    -- Use prompt intent, not prompt existence. A mob/boss can also have a prompt.
    local prompt = model:FindFirstChildWhichIsA("ProximityPrompt", true)
    if prompt then
        local action = (tostring(prompt.ActionText or "") .. " " .. tostring(prompt.ObjectText or "")):lower()
        if action:find("attack", 1, true) or action:find("fight", 1, true)
            or action:find("challenge", 1, true) or action:find("boss", 1, true) then
            return false
        end
        if action:find("talk", 1, true) or action:find("interact", 1, true)
            or action:find("quest", 1, true) or action:find("shop", 1, true)
            or action:find("buy", 1, true) or action:find("sell", 1, true)
            or action:find("claim", 1, true) or action:find("spawn", 1, true) then
            return true
        end
    end
    return false
end

function Mobs.register(hum)
    local model = hum.Parent
    if not model or not model:IsA("Model") or Mobs.set[model] then return end
    if model == LP.Character or Players:GetPlayerFromCharacter(model) then return end
    local root = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
        or model:FindFirstChild("Torso") or model:FindFirstChild("UpperTorso")
    if not (root and root:IsA("BasePart")) then
        local n = (Mobs.retry[model] or 0) + 1
        Mobs.retry[model] = n
        if n <= 4 then
            task.delay(1.2, function()
                if Hub.alive and hum.Parent == model then Mobs.register(hum) end
            end)
        end
        return
    end
    Mobs.set[model] = {
        model = model, hum = hum, root = root, base = Mobs.normBase(model.Name),
        level = Mobs.parseLevel(model, hum), npc = Mobs.looksLikeNPC(model),
        off = Vector3.new(Util.rand(-2.5, 2.5), 0, Util.rand(-2.5, 2.5)),
    }
    Mobs.cache = nil
end

function Mobs.scanAll()
    local n = 0
    for _, d in ipairs(Workspace:GetDescendants()) do
        if d:IsA("Humanoid") then
            Mobs.register(d)
        elseif d:IsA("ProximityPrompt") then
            Prompts.set[d] = true
        end
        n = n + 1
        if n % 600 == 0 then task.wait() end
    end
end

-- Keep the registry current after the initial scan. This also catches NPCs
-- that are streamed in later when the player moves to another island.
local function queueMobModel(model)
    if not model or not model:IsA("Model") or Mobs.pending[model] then return end
    Mobs.pending[model] = true
    task.defer(function()
        Mobs.pending[model] = nil
        if not Hub.alive or not model.Parent or not model:IsDescendantOf(Workspace) then return end
        local hum = model:FindFirstChildOfClass("Humanoid")
        if hum then Mobs.register(hum) end
    end)
end

Hub.track(Workspace.DescendantAdded:Connect(function(d)
    if not Hub.alive then return end
    if d:IsA("ProximityPrompt") then
        Prompts.set[d] = true
    elseif d:IsA("Humanoid") then
        queueMobModel(d.Parent)
    elseif d:IsA("BasePart") then
        queueMobModel(d:FindFirstAncestorOfClass("Model"))
    end
end))

Hub.track(Workspace.DescendantRemoving:Connect(function(d)
    if d:IsA("ProximityPrompt") then
        Prompts.set[d] = nil
    elseif d:IsA("Humanoid") then
        local model = d.Parent
        local entry = model and Mobs.set[model]
        if entry and entry.hum == d then
            Mobs.set[model] = nil
            Mobs.cache = nil
        end
    elseif d:IsA("BasePart") then
        local model = d:FindFirstAncestorOfClass("Model")
        local entry = model and Mobs.set[model]
        if entry and entry.root == d then
            Mobs.set[model] = nil
            Mobs.cache = nil
        end
    end
end))

function Mobs.isAlive(e)
    return e ~= nil and e.model.Parent ~= nil and e.hum.Parent ~= nil and e.root.Parent ~= nil
        and e.hum.Health > 0 and os.clock() >= (Mobs.black[e.model] or 0)
end

function Mobs.alive()
    local now = os.clock()
    if Mobs.cache and now - Mobs.cacheT < 0.2 then return Mobs.cache end
    local out = {}
    for model, e in pairs(Mobs.set) do
        if not model.Parent or not e.hum.Parent or not e.root.Parent then
            Mobs.set[model] = nil
            Mobs.cache = nil
        elseif e.hum.Health > 0 then
            if not e.level then e.level = Mobs.parseLevel(e.model, e.hum) end
            if now >= (Mobs.black[model] or 0) then out[#out + 1] = e end
            local k = Mobs.known[e.base]
            if not k then
                k = { npc = e.npc }
                Mobs.known[e.base] = k
            end
            k.level = e.level or k.level
            k.pos = e.root.Position
            k.seen = now
            if not e.npc then k.npc = false end
        else
            Mobs.set[model] = nil
            Mobs.cache = nil
        end
    end
    Mobs.cache, Mobs.cacheT = out, now
    return out
end

function Mobs.names()
    Mobs.alive()
    local out = { AUTO_NEAREST, AUTO_LEVEL }
    local arr = {}
    local now = os.clock()
    for base, k in pairs(Mobs.known) do
        if not k.seen or now - k.seen > 180 then Mobs.known[base] = nil end
    end
    for base, k in pairs(Mobs.known) do
        if not k.npc then arr[#arr + 1] = base end
    end
    table.sort(arr, function(a, b)
        local la = Mobs.known[a].level or 1e9
        local lb = Mobs.known[b].level or 1e9
        if la ~= lb then return la < lb end
        return a < b
    end)
    for _, n in ipairs(arr) do out[#out + 1] = n end
    return out
end

function Mobs.bestBaseForLevel()
    local pl = Util.playerLevel()
    if not pl then return nil end
    local best, bl = nil, -1
    local now = os.clock()
    for base, k in pairs(Mobs.known) do
        local fresh = k.seen and (now - k.seen) <= 45
        if fresh and not k.npc and k.level and k.level <= pl + 3 and k.level > bl then
            best, bl = base, k.level
        end
    end
    return best
end

function Mobs.pick()
    local root = Util.root()
    if not root then return nil end
    local p = root.Position
    local alive = Mobs.alive()
    local w = Mobs.want
    if w then
        local wb, wd = nil, math.huge
        for _, e in ipairs(alive) do
            if Util.nameMatchAny(e.model.Name, w.patterns) or Util.nameMatchAny(e.base, w.patterns) then
                local d = (e.root.Position - p).Magnitude
                if d < wd then wb, wd = e, d end
            end
        end
        if wb or w.exclusive then return wb end
    end

    local sel = S.TargetMob
    if sel == AUTO_LEVEL then
        local pl = Util.playerLevel()
        local best, bestLevel, bestDistance = nil, -math.huge, math.huge
        local hasLevelData = false
        if pl then
            for _, e in ipairs(alive) do
                if not e.npc and e.level then
                    hasLevelData = true
                    if e.level <= pl + 3 then
                        local d = (e.root.Position - p).Magnitude
                        if e.level > bestLevel or (e.level == bestLevel and d < bestDistance) then
                            best, bestLevel, bestDistance = e, e.level, d
                        end
                    end
                end
            end
        end
        if best then return best end
        -- When levels are readable, do not blindly attack a mob far above the player.
        -- Unknown-level mobs remain a fallback; if nothing is readable, use nearest.
        local nearest, nd = nil, math.huge
        for _, e in ipairs(alive) do
            if not e.npc and (not pl or not hasLevelData or not e.level) then
                local d = (e.root.Position - p).Magnitude
                if d < nd then nearest, nd = e, d end
            end
        end
        return nearest
    end

    local best, bd = nil, math.huge
    for _, e in ipairs(alive) do
        local ok = (sel == AUTO_NEAREST and not e.npc) or (sel ~= AUTO_NEAREST and e.base == sel)
        if ok then
            local d = (e.root.Position - p).Magnitude
            if d < bd then best, bd = e, d end
        end
    end
    return best
end

function Mobs.nearestWithin(radius)
    local root = Util.root()
    if not root then return nil end
    local p = root.Position
    local best, bd = nil, radius
    for _, e in ipairs(Mobs.alive()) do
        if not e.npc then
            local d = (e.root.Position - p).Magnitude
            if d <= bd then best, bd = e, d end
        end
    end
    return best
end

function Mobs.blacklist(e, secs)
    Mobs.black[e.model] = os.clock() + secs
    Mobs.cache = nil
end

function Mobs.group()
    -- the mob type the hub is currently working on (nil = any hostile mob)
    if S.TargetMob ~= AUTO_NEAREST and S.TargetMob ~= AUTO_LEVEL then return S.TargetMob end
    if Farm.target and Farm.target.base then return Farm.target.base end
    return nil
end

Hub.track(Workspace.DescendantAdded:Connect(function(d)
    if d:IsA("Humanoid") then
        task.defer(function()
            if Hub.alive then Mobs.register(d) end
        end)
    elseif d:IsA("ProximityPrompt") then
        Prompts.set[d] = true
    end
end))

----------------------------------------------------------------------
-- mover: ONE place that moves the character (so loops never fight each other).
-- Glide = capped-speed CFrame steps. If the server pulls us back, the hub slows
-- down by itself and finally falls back to real walking (Humanoid:MoveTo).
----------------------------------------------------------------------
local MIN_SPEED = 16

function Mover.reset()
    Mover.scale = 1
    Mover.mode = "glide"
    Mover.floorHits = 0
    Mover.rollbacks = 0
    Mover.lastDrop = 0
    Mover.lastEvent = "none"
    Mover.lastRB = os.clock()
    Mover.lastUp = 0
    Mover.lastPos = nil
    Mover.glided = false
end
Mover.reset()

function Mover.walking()
    return S.MoveMode == "Walk" or (S.MoveMode == "Auto" and Mover.mode == "walk")
end

function Mover.speed(it)
    local base = math.min((it and it.speed) or S.TravelSpeed, Limits.speed())
    local v = base * Mover.scale
    if v < MIN_SPEED then v = math.min(MIN_SPEED, base) end
    return v
end

function Mover.describe()
    if Mover.walking() then return "walking" end
    return string.format("gliding %.0f st/s", Mover.speed(nil))
end

-- kept for compatibility: BodyMovers are easy for games to detect, so none are used any more
function Mover.hold()
    if Mover.bv then
        pcall(function() Mover.bv:Destroy() end)
        Mover.bv = nil
    end
end

function Mover.release(owner)
    if owner == nil or Mover.owner == owner then
        local had = Mover.intent ~= nil
        Mover.intent = nil
        Mover.owner = nil
        Mover.lastPos = nil
        Mover.glided = false
        if had and Mover.walking() then
            local h, r = Util.hum(), Util.root()
            if h and r then pcall(function() h:MoveTo(r.Position) end) end
        end
    end
end

function Mover.follow(owner, goalFn, speed)
    if Mover.owner and Mover.owner ~= owner then return nil end
    local it = Mover.intent
    if it and it.kind == "follow" and Mover.owner == owner then
        it.goalFn = goalFn
        it.speed = speed
        return it
    end
    Mover.owner = owner
    Mover.intent = { kind = "follow", goalFn = goalFn, speed = speed, smooth = 12, owner = owner }
    return Mover.intent
end

-- blocking travel (yields until arrival / timeout / cancelled)
function Mover.travel(owner, goalCF, speed, timeout)
    Mover.owner = owner
    local it = { kind = "goto", goal = goalCF, speed = speed, owner = owner, done = false }
    Mover.intent = it
    if not timeout then
        local r = Util.root()
        local d = r and (goalCF.Position - r.Position).Magnitude or 100
        timeout = d / MIN_SPEED * 1.5 + 20
    end
    local t0 = os.clock()
    while Hub.alive and not it.done and Mover.intent == it do
        if os.clock() - t0 > timeout then break end
        task.wait(0.05)
    end
    local arrived = it.done
    if Mover.intent == it then Mover.release(owner) end
    return arrived
end

-- the server (or the game) moved us when we did not ask for it, or we are not getting anywhere
function Mover.onRollback(kind, amount)
    local now = os.clock()
    Mover.rollbacks = Mover.rollbacks + 1
    Mover.lastRB = now
    Mover.lastEvent = string.format("%s %.0f studs at t=%.0f", kind, amount or 0, now)
    if now - Mover.lastDrop < 1.0 or Mover.walking() then return end
    Mover.lastDrop = now
    if Mover.speed(nil) > MIN_SPEED + 0.5 then
        Mover.scale = math.max(Mover.scale * 0.55, 0.05)
        Hub.note("rb", string.format("Server pulled you back: slowing down to %.0f st/s", Mover.speed(nil)), "bad")
    else
        Mover.floorHits = Mover.floorHits + 1
        if Mover.floorHits >= 2 and S.MoveMode == "Auto" then
            Mover.mode = "walk"
            Hub.note("rb2", "Still pulled back at minimum speed: switching to real walking.", "bad")
        end
    end
end

function Mover.step(dt)
    local it = Mover.intent
    if not it then
        Mover.lastPos = nil
        return
    end
    local root, hum = Util.root(), Util.hum()
    if not root or not hum or hum.Health <= 0 then
        Mover.lastPos = nil
        return
    end
    local now = os.clock()
    local pos = root.Position
    if Mover.glided and Mover.lastPos then
        local err = (pos - Mover.lastPos).Magnitude
        if err > 7 then Mover.onRollback("snap", err) end
    end
    local goal
    if it.kind == "goto" then goal = it.goal else goal = it.goalFn and it.goalFn() end
    if not goal then
        Mover.lastPos = nil
        return
    end
    local gpos = goal.Position
    local dist = (gpos - pos).Magnitude
    it.dist = dist
    local walking = Mover.walking()
    -- slowly give the speed back after a quiet while (self-heals from a false alarm)
    if not walking and Mover.scale < 1 and now - Mover.lastRB > 30 and now - Mover.lastUp > 10 then
        Mover.lastUp = now
        Mover.scale = math.min(1, Mover.scale * 1.25)
    end
    -- progress watchdog (every 1.4s: did we get closer to the goal we had at the start of the window?)
    if not it.win or now - it.win.t > 1.4 then
        local w = it.win
        if w and w.d > 8 and dist > 8 and (gpos - w.g).Magnitude < 6 then
            local gained = w.d - (w.g - pos).Magnitude
            local expect = w.v * (now - w.t)
            if gained < expect * 0.25 then
                it.stall = (it.stall or 0) + 1
                Mover.onRollback("stall", expect - gained)
            else
                it.stall = 0
            end
        end
        it.win = { t = now, d = dist, g = gpos, v = walking and math.max(hum.WalkSpeed, 8) or Mover.speed(it) }
    end
    if walking then
        Mover.glided = false
        Mover.lastPos = nil
        if it.kind == "goto" and dist < 3.5 then it.done = true end
        if now - (it.mt or 0) > 0.12 then
            it.mt = now
            pcall(function() hum:MoveTo(gpos) end)
        end
        if (it.stall or 0) >= 1 and now - (it.jt or 0) > 1.2 then
            it.jt = now
            pcall(function() hum.Jump = true end)
        end
        return
    end
    root.AssemblyLinearVelocity = ZERO
    root.AssemblyAngularVelocity = ZERO
    local speed = Mover.speed(it)
    local step
    if it.kind == "goto" then
        step = math.min(dist, speed * dt)
    else
        step = math.min(dist * (1 - math.exp(-(it.smooth or 12) * dt)), speed * dt)
    end
    local newPos = pos
    if dist > 0.001 then newPos = pos + (gpos - pos).Unit * step end
    local cur = root.CFrame
    local a = 1 - math.exp(-14 * dt)
    local newRot = (cur - cur.Position):Lerp(goal - goal.Position, a)
    root.CFrame = CFrame.new(newPos) * newRot
    Mover.lastPos = newPos
    Mover.glided = true
    if it.kind == "goto" and dist < 1.5 then it.done = true end
end

Hub.track(RunService.Heartbeat:Connect(function(dt)
    local ok, e = pcall(Mover.step, dt)
    if not ok then Hub.err("mover", e) end
end))

Hub.track(RunService.Stepped:Connect(function()
    local gliding = Mover.intent ~= nil and not Mover.walking()
    if not (gliding or S.Noclip) then return end
    local c = LP.Character
    if not c then return end
    if gliding then
        local r = c:FindFirstChild("HumanoidRootPart")
        if r then r.AssemblyLinearVelocity = ZERO end
    end
    for _, p in ipairs(c:GetDescendants()) do
        if p:IsA("BasePart") and p.CanCollide then p.CanCollide = false end
    end
end))

Hub.track(LP.CharacterAdded:Connect(function()
    Mover.bv = nil
    Attack.watch = {}
end))

----------------------------------------------------------------------
-- equip
----------------------------------------------------------------------
function Equip.tools()
    local names, seen = {}, {}
    local function scan(container)
        if not container then return end
        for _, t in ipairs(container:GetChildren()) do
            if t:IsA("Tool") and not seen[t.Name] then
                seen[t.Name] = true
                names[#names + 1] = t.Name
            end
        end
    end
    scan(LP:FindFirstChildOfClass("Backpack"))
    scan(LP.Character)
    table.sort(names)
    return names
end

function Equip.current()
    local c = LP.Character
    return c and c:FindFirstChildOfClass("Tool")
end

function Equip.ensure()
    local hum = Util.hum()
    if not hum or hum.Health <= 0 then return end
    local cur = Equip.current()
    local now = os.clock()
    local bp = LP:FindFirstChildOfClass("Backpack")
    if S.EquipMode == "Hotbar slot" then
        if not cur and now - Equip.lastKey > 1.5 then
            Equip.lastKey = now
            Util.pressKey(KEYS[Util.clamp(math.floor(S.HotbarSlot), 1, 9)])
        end
        return
    end
    if S.Weapon ~= AUTO_TOOL then
        if cur and cur.Name == S.Weapon then return end
        local tool = bp and bp:FindFirstChild(S.Weapon)
        if tool and tool:IsA("Tool") then pcall(function() hum:EquipTool(tool) end) end
        return
    end
    if cur then return end
    if bp then
        for _, t in ipairs(bp:GetChildren()) do
            if t:IsA("Tool") then
                pcall(function() hum:EquipTool(t) end)
                return
            end
        end
    end
    -- no Tool objects at all (custom inventory): fall back to the first hotbar slot now and then
    if #Equip.tools() == 0 and now - Equip.lastKey > 8 then
        Equip.lastKey = now
        Util.pressKey(KEYS[1])
    end
end

Hub.loop("equip", function()
    if S.AutoEquip and (S.AutoFarm or S.AutoAttack) and not Hub.paused then Equip.ensure() end
    return 1.2
end)

----------------------------------------------------------------------
-- attack (adaptive: tries several input methods and keeps the one that lowers mob health)
----------------------------------------------------------------------
-- Auto attack is intentionally restricted to non-coordinate input methods.
-- Synthetic mouse/touch and VirtualUser were the source of stuck mobile clicks.
Attack.methods = { "tool", "button" }
Attack.stats = {}
Attack.lastMethodSwitch = 0
local METHOD_BY_NAME = { Tool = "tool", Button = "button" }
local NAME_BY_METHOD = { tool = "Tool", button = "Button" }

-- health of a mob (Humanoid, or an attribute / value some games use instead)
function Mobs.hp(e)
    if e.hpSrc == nil then
        e.hpSrc = false
        local m = e.model
        if type(m:GetAttribute("Health")) == "number" then
            e.hpSrc = { "attr", "Health" }
        elseif type(m:GetAttribute("HP")) == "number" then
            e.hpSrc = { "attr", "HP" }
        else
            local v = m:FindFirstChild("Health") or m:FindFirstChild("HP")
            if v and v:IsA("ValueBase") and type(v.Value) == "number" then e.hpSrc = { "val", v } end
        end
    end
    local s = e.hpSrc
    if s then
        if s[1] == "attr" then
            local a = e.model:GetAttribute(s[2])
            if type(a) == "number" then return a end
        elseif s[2].Parent then
            return s[2].Value
        end
    end
    return e.hum.Health
end

function Attack.findButton()
    if Attack.btn and Attack.btn.Parent and Attack.btn.Visible and os.clock() - Attack.btnT < 3 then
        return Attack.btn
    end
    Attack.btnT = os.clock()
    Attack.btn = nil
    local pg = LP:FindFirstChild("PlayerGui")
    if not pg then return nil end

    local exact = {
        m1 = true, attack = true, combat = true, punch = true,
        m1button = true, attackbutton = true, combatbutton = true,
        mobileattack = true, mobilecombat = true,
    }
    local function norm(v)
        return tostring(v or ""):lower():gsub("[^%w]", "")
    end
    local n = 0
    for _, d in ipairs(pg:GetDescendants()) do
        n = n + 1
        if n % 700 == 0 then task.wait() end
        if d:IsA("GuiButton") and d.Visible and d.Active and Util.guiVisible(d) then
            local nm = norm(d.Name)
            local tx = norm(d:IsA("TextButton") and d.Text or "")
            if exact[nm] or exact[tx] then
                Attack.btn = d
                break
            end
        end
    end
    return Attack.btn
end

-- turn towards the mob (rotation only, no position change)
function Attack.face(t)
    local root = Util.root()
    if not root then return end
    if Mover.intent and not Mover.walking() then return end
    local tp = t.root.Position
    local at = Vector3.new(tp.X, root.Position.Y, tp.Z)
    if (at - root.Position).Magnitude < 0.5 then return end
    root.CFrame = CFrame.lookAt(root.Position, at)
end

function Attack.swing()
    local m
    if S.AttackMethod == "Auto" then
        m = Attack.methods[Attack.idx]
    else
        m = METHOD_BY_NAME[S.AttackMethod] or "tool"
    end

    if m == "tool" then
        local t = Equip.current()
        if not t or not t.Enabled then return false end
        local ok = pcall(function() t:Activate() end)
        if not ok then return false end
        -- Explicitly close the activation window; this is not a mouse/touch hold.
        task.delay(0.04, function()
            if t and t.Parent == LP.Character then
                pcall(function() t:Deactivate() end)
            end
        end)
        return true
    elseif m == "button" then
        local b = Attack.findButton()
        return b and Util.fireButton(b) or false
    end
    return false
end

function Attack.step(t)
    local w = Attack.watch
    if w.target ~= t then
        w.target = t
        w.hp = Mobs.hp(t)
        w.n = 0
        w.total = 0
    end
    Attack.face(t)
    local m = (S.AttackMethod == "Auto") and Attack.methods[Attack.idx] or (METHOD_BY_NAME[S.AttackMethod] or "tool")
    local st = Attack.stats[m]
    if not st then
        st = { tries = 0, hits = 0 }
        Attack.stats[m] = st
    end
    if not Attack.swing() then
        if S.AttackMethod == "Auto" and os.clock() - (Attack.lastMethodSwitch or 0) >= 0.75 then
            Attack.idx = Attack.idx % #Attack.methods + 1
            Attack.lastMethodSwitch = os.clock()
        end
        return false
    end
    st.tries = st.tries + 1
    w.n = w.n + 1
    w.total = w.total + 1
    local hp = Mobs.hp(t)
    if hp < w.hp - 0.001 then
        st.hits = st.hits + 1
        w.hp = hp
        w.n = 0
        w.total = 0
        Attack.good = m
        if S.AttackMethod == "Auto" then
            for i, method in ipairs(Attack.methods) do
                if method == m then Attack.idx = i break end
            end
        end
    elseif w.n >= 8 then
        w.n = 0
        if S.AttackMethod == "Auto" and os.clock() - (Attack.lastMethodSwitch or 0) >= 0.75 then
            Attack.idx = Attack.idx % #Attack.methods + 1
            Attack.lastMethodSwitch = os.clock()
            Hub.note("attack", "No damage confirmed - trying safe method: " .. Attack.methods[Attack.idx])
        end
    end
    if Farm.spot and w.total >= 20 then
        Farm.spotOff = os.clock() + 40
        Farm.spot = nil
        Hub.note("bring", "Bring Mobs paused 40s: the server is not accepting moved mobs.", "bad")
    end
    if w.total >= 60 then
        w.total = 0
        if Attack.good then
            Mobs.blacklist(t, 25)
            w.target = nil
            Hub.note("stuck", "Could not damage " .. t.base .. " - skipping it for 25s.", "bad")
        else
            Hub.note("noatk", "No attack method has damaged anything yet. Stand next to a mob, equip your weapon and press Test attack methods.", "bad")
        end
    end
    return true
end

-- tries every input method on the nearest mob and reports which one really hurts it
function Attack.test()
    if not Util.alive() then return "You are not alive." end
    local t = Mobs.nearestWithin(150)
    if not t then return "No mob found within 150 studs. Walk near some mobs first." end
    Hub.stopAutomation("attack test")
    Attack.testing = true
    local saved = S.AttackMethod
    local chosen = nil
    local ok, res = pcall(function()
        Equip.ensure()
        task.wait(0.35)
        local tp = t.root.Position
        local stand = Vector3.new(tp.X, tp.Y, tp.Z - 4)
        Mover.travel("test", CFrame.lookAt(stand, tp), math.min(S.TravelSpeed, 45), 12)
        task.wait(0.25)
        local results = {}
        for _, m in ipairs(Attack.methods) do
            if not Mobs.isAlive(t) then t = Mobs.nearestWithin(40) end
            if not t then break end
            S.AttackMethod = NAME_BY_METHOD[m]
            local sent, hit = 0, false
            for _ = 1, 5 do
                if not Mobs.isAlive(t) then break end
                local hp0 = Mobs.hp(t)
                Attack.face(t)
                if Attack.swing() then sent = sent + 1 end
                task.wait(0.32)
                if Mobs.isAlive(t) and Mobs.hp(t) < hp0 - 0.001 then hit = true break end
                if not Mobs.isAlive(t) then hit = true break end
            end
            results[#results + 1] = m .. "=" .. (sent == 0 and "unavailable" or (hit and "HIT" or "no damage"))
            if sent > 0 and hit then chosen = m break end
        end
        if chosen then
            local nm = NAME_BY_METHOD[chosen]
            Attack.good = chosen
            for i, method in ipairs(Attack.methods) do
                if method == chosen then Attack.idx = i break end
            end
            return table.concat(results, "  ") .. "  ->  using " .. nm
        end
        return table.concat(results, "  ") .. "  ->  no safe method damaged the target; check the Scanner report and weapon state."
    end)
    S.AttackMethod = saved
    Attack.testing = false
    Mover.release("test")
    if not ok then
        Hub.err("attacktest", res)
        return "Test failed: " .. tostring(res)
    end
    if chosen and saved == "Auto" then Attack.idx = (chosen == "button") and 2 or 1 end
    Attack.lastTest = res
    return res
end

----------------------------------------------------------------------
-- farm
----------------------------------------------------------------------
function Farm.goal()
    local t = Farm.target
    if not t or not Mobs.isAlive(t) then return nil end
    local tp = Farm.spot or t.root.Position
    local look = t.root.CFrame.LookVector
    local flat = Vector3.new(look.X, 0, look.Z)
    if flat.Magnitude < 0.05 then flat = Vector3.new(0, 0, -1) else flat = flat.Unit end
    local d = Util.clamp(S.FarmDist, 2, 45)
    local pos
    if Mover.walking() then
        pos = tp - flat * math.min(d, 5)
    elseif S.FarmPos == "Above" then
        pos = tp + Vector3.new(0, d, 0) - flat * 1.5
    elseif S.FarmPos == "Behind" then
        pos = tp - flat * d
    else
        pos = tp + flat * d
    end
    if S.SafeMode and not Mover.walking() then
        local tt = os.clock()
        pos = pos + Vector3.new(math.sin(tt * 1.7) * 0.35, math.sin(tt * 2.3) * 0.2, math.cos(tt * 1.3) * 0.35)
    end
    return CFrame.lookAt(pos, tp)
end

function Farm.updateSpot(t)
    if not S.BringMobs or os.clock() < Farm.spotOff or not Util.owned(t.root) then
        Farm.spot = nil
        return
    end
    if Farm.spot and (t.root.Position - Farm.spot).Magnitude > S.BringRadius * 1.5 then Farm.spot = nil end
    if not Farm.spot then Farm.spot = t.root.Position end
end

function Farm.refPos()
    local base = S.TargetMob
    if base == AUTO_LEVEL then base = Mobs.bestBaseForLevel() end
    local k = base and Mobs.known[base]
    if k and k.pos and k.seen and os.clock() - k.seen <= 45 then return k.pos end
    if Farm.target and Mobs.isAlive(Farm.target) then return Farm.target.root.Position end
    local r = Util.root()
    return r and r.Position or nil
end

Hub.loop("farm", function()
    if not S.AutoFarm or Hub.paused then
        Mover.release("farm")
        Farm.target = nil
        Farm.spot = nil
        return 0.3
    end
    if not Util.alive() then
        Mover.release("farm")
        return 0.5
    end
    if Prestige.busy then
        Mover.release("farm")
        return 0.5
    end
    if Mover.owner and Mover.owner ~= "farm" then return 0.2 end
    if S.AutoQuest and Quest.due() then
        Mover.release("farm")
        Quest.run()
        return 0.1
    end
    local t = Farm.target
    if not (t and Mobs.isAlive(t)) then
        t = Mobs.pick()
        Farm.target = t
        Attack.watch = {}
    end
    if not t then
        Farm.spot = nil
        local targetBase = S.TargetMob == AUTO_LEVEL and Mobs.bestBaseForLevel() or S.TargetMob
        local k = targetBase and Mobs.known[targetBase]
        if k and k.pos and k.seen and os.clock() - k.seen <= 45 then
            Hub.status = "Heading to the " .. S.TargetMob .. " area..."
            local home = k.pos + Vector3.new(0, 4, 0)
            Mover.follow("farm", function() return Util.cfAt(home) end, S.TravelSpeed)
            return 0.5
        end
        Mover.release("farm")
        Hub.status = "Waiting for mobs..."
        Hub.note("nomobs", "No mobs found. Walk near them once so the hub can learn where they are.", "bad")
        return 0.8
    end
    Farm.updateSpot(t)
    Hub.status = string.format("Farming %s (%d alive) | %s", t.base, #Mobs.alive(), Mover.describe())
    Mover.follow("farm", Farm.goal, S.TravelSpeed)
    local it = Mover.intent
    if it and Mover.owner == "farm" and (it.stall or 0) >= 3 and Mover.walking() then
        it.stall = 0
        Mobs.blacklist(t, 20)
        Farm.target = nil
        Hub.note("unreach", "Cannot reach " .. t.base .. " (blocked) - trying another one.", "bad")
    end
    return 0.05
end)

Hub.loop("attack", function()
    if not S.AutoAttack or Hub.paused or Attack.testing or not Util.alive() then return 0.25 end
    local root = Util.root()
    local reach = S.FarmDist + 20 + (S.Hitbox and S.HitboxSize * 0.5 or 0)
    local t = Farm.target
    if not (S.AutoFarm and t and Mobs.isAlive(t)) then t = Mobs.nearestWithin(reach) end
    if not t then return 0.15 end
    if (t.root.Position - root.Position).Magnitude > reach then return 0.1 end
    Attack.step(t)
    local iv = 1 / Util.clamp(S.CPS, 1, Limits.cps())
    iv = iv * Util.rand(0.8, 1.25)
    if S.SafeMode and math.random() < 0.02 then iv = iv + Util.rand(0.4, 1.1) end
    return iv
end)

local SKILLS = {
    { "SkillZ", Enum.KeyCode.Z }, { "SkillX", Enum.KeyCode.X }, { "SkillC", Enum.KeyCode.C },
    { "SkillV", Enum.KeyCode.V }, { "SkillG", Enum.KeyCode.G },
}

Hub.loop("skills", function()
    if Hub.paused or not Util.alive() then return 0.4 end
    local any = false
    for _, s in ipairs(SKILLS) do
        if S[s[1]] then any = true end
    end
    if not any then return 0.4 end
    local root = Util.root()
    local reach = S.FarmDist + 22 + (S.Hitbox and S.HitboxSize * 0.5 or 0)
    local t = Farm.target
    if not (S.AutoFarm and t and Mobs.isAlive(t)) then t = Mobs.nearestWithin(reach) end
    if not t or (t.root.Position - root.Position).Magnitude > reach then return 0.3 end
    for _, s in ipairs(SKILLS) do
        if S[s[1]] and Hub.alive then
            Util.pressKey(s[2])
            task.wait(Util.rand(0.15, 0.32))
        end
    end
    return math.max(0.4, S.SkillDelay) * Util.rand(0.85, 1.2)
end)

----------------------------------------------------------------------
-- bring mobs / hitbox / reach
----------------------------------------------------------------------
function Bring.pull(e, anchor)
    local r = e.root
    r.CFrame = CFrame.new(anchor + e.off)
    r.AssemblyLinearVelocity = ZERO
    r.AssemblyAngularVelocity = ZERO
    r.CanCollide = false
    local h = e.hum
    if not e.pulled then
        e.pulled = true
        h.WalkSpeed = 0
        h.JumpPower = 0
        h.PlatformStand = true
    end
    local now = os.clock()
    if now - (e.psT or 0) > 0.6 then
        e.psT = now
        pcall(function() h:ChangeState(Enum.HumanoidStateType.PlatformStanding) end)
    end
end

Hub.loop("bring", function()
    if not S.BringMobs or Hub.paused or not Util.alive() then return 0.3 end
    if not Farm.spot and Farm.target and S.AutoFarm and os.clock() < Farm.spotOff then return 0.3 end
    local root = Util.root()
    local anchor = Farm.spot
    if not anchor then anchor = (root.CFrame * CFrame.new(0, -1.5, -6)).Position end
    local group = Mobs.group()
    local n = 0
    for _, e in ipairs(Mobs.alive()) do
        if not e.npc and (group == nil or e.base == group)
            and (e.root.Position - root.Position).Magnitude <= S.BringRadius then
            if Util.owned(e.root) then
                Bring.pull(e, anchor)
                n = n + 1
                if n >= 14 then break end
            end
        end
    end
    return 0.06
end)

Hub.loop("simradius", function()
    if S.BringMobs or S.Hitbox then
        if X.shp then pcall(X.shp, LP, "SimulationRadius", 1e9) end
        pcall(function() LP.MaximumSimulationRadius = 1e9 end)
    end
    return 1.5
end)

function Hitbox.apply(e)
    local r = e.root
    local sz = Util.clamp(S.HitboxSize, 2, Limits.hitbox())
    if not Hitbox.orig[r] then
        Hitbox.orig[r] = { size = r.Size, transp = r.Transparency, collide = r.CanCollide, massless = r.Massless }
    end
    local want = Vector3.new(sz, sz, sz)
    if r.Size ~= want then r.Size = want end
    r.Transparency = 0.9
    r.CanCollide = false
    r.Massless = true
end

function Hitbox.restoreAll()
    for r, o in pairs(Hitbox.orig) do
        if r.Parent then
            pcall(function()
                r.Size = o.size
                r.Transparency = o.transp
                r.CanCollide = o.collide
                r.Massless = o.massless
            end)
        end
        Hitbox.orig[r] = nil
    end
end

Hub.loop("hitbox", function()
    if not S.Hitbox or Hub.paused then
        if next(Hitbox.orig) then Hitbox.restoreAll() end
        return 0.5
    end
    local root = Util.root()
    if not root then return 0.5 end
    local group = Mobs.group()
    for _, e in ipairs(Mobs.alive()) do
        if not e.npc and (group == nil or e.base == group) and (e.root.Position - root.Position).Magnitude <= 260 then
            Hitbox.apply(e)
        end
    end
    return 0.35
end)

function Reach.restore()
    for h, o in pairs(Reach.orig) do
        if h.Parent then
            pcall(function()
                h.Size = o.size
                h.Massless = o.massless
                h.CanCollide = o.collide
            end)
        end
        Reach.orig[h] = nil
    end
end

Hub.loop("reach", function()
    if not S.Reach or Hub.paused then
        if next(Reach.orig) then Reach.restore() end
        return 0.6
    end
    local tool = Equip.current()
    local h = tool and tool:FindFirstChild("Handle")
    if h and h:IsA("BasePart") then
        if not Reach.orig[h] then Reach.orig[h] = { size = h.Size, massless = h.Massless, collide = h.CanCollide } end
        local s = Util.clamp(S.ReachSize, 2, Limits.hitbox())
        h.Size = Vector3.new(s, s, s)
        h.Massless = true
        h.CanCollide = false
    end
    return 0.5
end)

----------------------------------------------------------------------
-- quests (discover quest NPCs, walk there, interact, click accept-like buttons)
----------------------------------------------------------------------
local QUEST_WORDS = { "quest", "mission", "bounty", "task", "assignment" }
local GOOD_BTN = { "accept", "start", "begin", "continue", "next", "yes", "confirm", "claim", "complete", "finish", "okay", "agree", "take", "turn in", "ok", "prestige", "ascend", "unlock" }
local BAD_BTN = { "buy", "sell", "purchase", "reset", "shop", "close", "cancel", "decline", "exit", "leave", "reject", "no", "robux", "trade", "delete", "abandon" }

function Quest.scan()
    local list = {}
    local seen = {}
    for d in pairs(Prompts.set) do
        if d.Parent and d:IsDescendantOf(Workspace) then
            local model = d:FindFirstAncestorOfClass("Model")
            local nm = (model and model.Name) or (d.Parent and d.Parent.Name) or "?"
            local text = ((d.ActionText or "") .. " " .. (d.ObjectText or "") .. " " .. nm .. " " .. d.Name):lower()
            local score = 0
            for _, w in ipairs(QUEST_WORDS) do
                if text:find(w, 1, true) then score = score + 2 end
            end
            if text:find("talk", 1, true) then score = score + 1 end
            local pos = Util.posOf(d)
            if pos then
                local label = nm
                if d.ActionText and d.ActionText ~= "" then label = nm .. " (" .. d.ActionText .. ")" end
                local key = label .. string.format("%.0f,%.0f", pos.X, pos.Z)
                if not seen[key] then
                    seen[key] = true
                    local required = text:match("[Ll][Vv][Ll]?%s*[:%-]?%s*(%d+)") or text:match("[Ll]evel%s*[:%-]?%s*(%d+)")
                    list[#list + 1] = { prompt = d, name = nm, score = score, pos = pos, label = label, hasModel = model ~= nil, requiredLevel = required and tonumber(required) or nil }
                end
            end
        end
    end
    Quest.prompts = list
    return list
end

local SHOP_WORDS = {
    "shop", "merchant", "dealer", "trainer", "vendor", "seller", "banker", "blacksmith", "gacha", "prestige",
    "reroll", "fisherman", "teacher", "tracker",
}

function Quest.isShop(name)
    local l = name:lower()
    for _, w in ipairs(SHOP_WORDS) do
        if l:find(w, 1, true) then return true end
    end
    return false
end

function Quest.labels()
    local root = Util.root()
    local arr = {}
    for _, c in ipairs(Quest.prompts) do
        if c.hasModel then
            arr[#arr + 1] = { label = c.label, d = root and (c.pos - root.Position).Magnitude or 0, score = c.score }
        end
    end
    table.sort(arr, function(a, b)
        if a.score ~= b.score then return a.score > b.score end
        return a.d < b.d
    end)
    local out, seen = { AUTO_QUEST }, {}
    for _, a in ipairs(arr) do
        if not seen[a.label] then
            seen[a.label] = true
            out[#out + 1] = a.label
            if #out >= 40 then break end
        end
    end
    return out
end

function Quest.pick()
    local list = Quest.scan()
    if #list == 0 then return nil end
    local playerLevel = Util.playerLevel()
    if S.QuestNPC ~= AUTO_QUEST then
        for _, c in ipairs(list) do
            if c.label == S.QuestNPC and (not c.requiredLevel or not playerLevel or c.requiredLevel <= playerLevel) then
                return c
            end
        end
    end
    local ref = Farm.refPos()
    local best, bs = nil, -math.huge
    for _, c in ipairs(list) do
        local levelOK = not c.requiredLevel or not playerLevel or c.requiredLevel <= playerLevel
        if c.hasModel and levelOK and (c.score >= 1 or not Quest.isShop(c.name)) then
            local d = ref and (c.pos - ref).Magnitude or 0
            local score = c.score * 1000 - d
            if score > bs then best, bs = c, score end
        end
    end
    return best
end

function Quest.badText(t)
    t = (t or ""):lower()
    for _, w in ipairs(BAD_BTN) do
        if t == w or t:find("%f[%a]" .. w .. "%f[%A]") then return true end
    end
    return false
end

function Quest.goodText(t)
    t = (t or ""):lower()
    if t == "" or Quest.badText(t) then return false end
    for _, w in ipairs(GOOD_BTN) do
        if t:find(w, 1, true) then return true end
    end
    return false
end

-- every visible button with a short, harmless label  ->  { button = text }
function Quest.visible()
    local out = {}
    local pg = LP:FindFirstChild("PlayerGui")
    if not pg then return out end
    local n = 0
    for _, d in ipairs(pg:GetDescendants()) do
        n = n + 1
        if n % 700 == 0 then task.wait() end
        if d:IsA("GuiButton") then
            local tx = d:IsA("TextButton") and d.Text or ""
            if tx == "" then
                local lbl = d:FindFirstChildWhichIsA("TextLabel", true)
                tx = lbl and lbl.Text or ""
            end
            if tx ~= "" and #tx <= 28 and not Quest.badText(tx) and Util.guiVisible(d) then out[d] = tx end
        end
    end
    return out
end

function Quest.interact(c)
    local before = Quest.visible()
    Util.firePrompt(c.prompt)
    local clicked, idle = 0, 0
    local key = c.prompt.KeyboardKeyCode
    if not key or key == Enum.KeyCode.Unknown then key = Enum.KeyCode.E end
    for i = 1, 9 do
        task.wait(0.5)
        local now = Quest.visible()
        local pickB, pickScore = nil, 0
        for b, tx in pairs(now) do
            if not before[b] then
                if Quest.goodText(tx) then
                    local sc = 2
                    if sc > pickScore then pickB, pickScore = b, sc end
                end
            end
        end
        if pickB then
            idle = 0
            before[pickB] = true
            if Util.fireButton(pickB) then clicked = clicked + 1 end
        else
            idle = idle + 1
            if clicked > 0 and idle >= 3 then break end
            if clicked == 0 then
                -- nothing opened yet: interact like a real player (hold the prompt key / hold the prompt)
                if i == 2 or i == 6 then
                    Util.pressKey(key, (c.prompt.HoldDuration or 0) + 0.25)
                elseif i == 4 or i == 8 then
                    pcall(function()
                        c.prompt:InputHoldBegin()
                        task.wait((c.prompt.HoldDuration or 0) + 0.15)
                        c.prompt:InputHoldEnd()
                    end)
                end
            end
        end
    end
    return clicked
end

function Quest.readProgress()
    local now = os.clock()
    if now - Quest.progT < 2.5 then return Quest.progV end
    Quest.progT = now
    local pg = LP:FindFirstChild("PlayerGui")
    local res = "none"
    if pg then
        local n = 0
        for _, d in ipairs(pg:GetDescendants()) do
            n = n + 1
            if n % 700 == 0 then task.wait() end
            if d:IsA("TextLabel") and d.Visible and #d.Text < 90 then
                local inQuest = false
                local p = d
                for _ = 1, 8 do
                    if not p or p == pg then break end
                    local nm = p.Name:lower()
                    if nm:find("quest", 1, true) or nm:find("mission", 1, true)
                        or nm:find("task", 1, true) or nm:find("objective", 1, true) then
                        inQuest = true
                        break
                    end
                    p = p.Parent
                end
                if inQuest then
                    local textLower = d.Text:lower()
                    if textLower:find("quest completed", 1, true)
                        or textLower:find("quest complete", 1, true)
                        or textLower:find("objective complete", 1, true)
                        or textLower:find("mission completed", 1, true) then
                        res = "done"
                        break
                    end
                    local a, b = d.Text:match("(%d+)%s*/%s*(%d+)")
                    if a then
                        res = "active"
                        if tonumber(b) and tonumber(b) > 0 and tonumber(a) >= tonumber(b) then
                            res = "done"
                            break
                        end
                    elseif res == "none" then
                        res = "active"
                    end
                end
            end
        end
    end
    Quest.progV = res
    return res
end

function Quest.due()
    local now = os.clock()
    if Quest.first then
        Quest.first = false
        Quest.doneConsumed = true
        return true
    end
    if now - Quest.last < 6 then return false end
    local st = Quest.readProgress()
    if st == "active" then
        Quest.doneConsumed = false
        return false
    end
    if st == "done" then
        if Quest.doneConsumed then return false end
        Quest.doneConsumed = true
        return true
    end
    return now - Quest.last >= S.QuestInterval
end

function Quest.run()
    Quest.doneConsumed = true
    Hub.status = "Quest: looking for a quest NPC..."
    local c = Quest.pick()
    Quest.last = os.clock()
    if not c then
        Quest.info = "No quest NPC found nearby. Walk to an island, press Scan quest NPCs, or pick one in the list."
        Hub.note("noquest", "Auto Quest: no quest NPC found. Use Scan quest NPCs.", "bad")
        return false
    end
    local root = Util.root()
    if not root then return false end
    Hub.status = "Quest: walking to " .. c.name
    local pos = c.pos
    local dir = root.Position - pos
    dir = Vector3.new(dir.X, 0, dir.Z)
    if dir.Magnitude > 0.1 then dir = dir.Unit else dir = Vector3.new(0, 0, 1) end
    local stand = pos + dir * 4
    local gy = Util.groundY(stand)
    if gy then stand = Vector3.new(stand.X, gy + 3.2, stand.Z) end
    local arrived = Mover.travel("quest", CFrame.lookAt(stand, Vector3.new(pos.X, stand.Y, pos.Z)), S.TravelSpeed)
    if not arrived then
        Quest.info = "Could not reach " .. c.name .. " (blocked or cancelled)."
        return false
    end
    Hub.status = "Quest: talking to " .. c.name
    local n = Quest.interact(c)
    Quest.last = os.clock()
    Quest.info = string.format("Talked to %s, pressed %d dialog button(s).", c.name, n)
    return true
end

Hub.loop("questscan", function()
    Quest.scan()
    return 3
end)

----------------------------------------------------------------------
-- map points (islands / spawns / NPCs / players) + safe teleport
----------------------------------------------------------------------
local ISLAND_WORDS = {
    "island", "town", "village", "city", "academy", "baratie", "arlong", "harbor", "port", "base", "castle",
    "legacy", "jungle", "iceland", "hollow", "fusha", "alvida", "shimotsuki", "orange", "mink", "namek",
    "karakura", "scrapyard", "dandadan", "sailor", "starter", "spawn",
}
local ISLAND_CONTAINERS = { "island", "map", "world", "zone", "area", "location", "spawn", "teleport", "region" }

function POI.scan()
    local isl, seen = {}, {}
    local function add(name, pos)
        if not pos then return end
        local key = name .. string.format("%.0f,%.0f", pos.X, pos.Z)
        if seen[key] then return end
        seen[key] = true
        isl[#isl + 1] = { name = name, pos = pos }
    end
    local n = 0
    for _, d in ipairs(Workspace:GetDescendants()) do
        n = n + 1
        if n % 700 == 0 then task.wait() end
        if d:IsA("SpawnLocation") then
            local par = d.Parent
            local nm = (par and par ~= Workspace and par.Name ~= "Workspace") and par.Name or d.Name
            add("Spawn: " .. nm, d.Position)
        end
    end
    for _, ch in ipairs(Workspace:GetChildren()) do
        local ln = ch.Name:lower()
        local isCont = false
        for _, w in ipairs(ISLAND_CONTAINERS) do
            if ln:find(w, 1, true) then isCont = true end
        end
        if isCont and (ch:IsA("Folder") or ch:IsA("Model")) then
            for _, sub in ipairs(ch:GetChildren()) do
                if sub:IsA("Model") or sub:IsA("Folder") or sub:IsA("BasePart") then
                    add(sub.Name, Util.pivotPos(sub))
                end
            end
        elseif ch:IsA("Model") or ch:IsA("Folder") then
            for _, w in ipairs(ISLAND_WORDS) do
                if ln:find(w, 1, true) then
                    add(ch.Name, Util.pivotPos(ch))
                    break
                end
            end
        end
    end
    table.sort(isl, function(a, b) return a.name < b.name end)
    while #isl > 70 do table.remove(isl) end
    POI.islands = isl

    local npcs, nseen = {}, {}
    for _, c in ipairs(Quest.prompts) do
        if c.hasModel and not nseen[c.name] then
            nseen[c.name] = true
            npcs[#npcs + 1] = { name = c.name, pos = c.pos }
        end
    end
    table.sort(npcs, function(a, b) return a.name < b.name end)
    while #npcs > 80 do table.remove(npcs) end
    POI.npcs = npcs
end

function POI.names(list)
    local out = {}
    for _, p in ipairs(list) do out[#out + 1] = p.name end
    return out
end

function POI.find(list, name)
    for _, p in ipairs(list) do
        if p.name == name then return p end
    end
    return nil
end

function POI.players()
    local out = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP then out[#out + 1] = p.Name end
    end
    table.sort(out)
    return out
end

function Hub.stopAutomation(why)
    local stopped = false
    for _, k in ipairs({ "AutoFarm", "AutoQuest" }) do
        if S[k] then
            stopped = true
            if UI.toggles[k] then UI.toggles[k].Set(false) else S[k] = false end
        end
    end
    Mover.release()
    if stopped then Hub.note("autooff", "Auto Farm / Quest turned off (" .. why .. ").") end
end

function TP.go(pos, label, standOff)
    if not pos then
        Hub.note("tp", "Pick a destination first.", "bad")
        return
    end
    if not Util.alive() then
        Hub.note("tp", "You are not alive yet.", "bad")
        return
    end
    Hub.stopAutomation("teleport")
    task.spawn(function()
        local root = Util.root()
        if not root then return end
        local dest = pos
        if standOff then
            local d = root.Position - pos
            d = Vector3.new(d.X, 0, d.Z)
            if d.Magnitude > 0.1 then dest = pos + d.Unit * 4 end
        end
        local gy = Util.groundY(dest)
        if gy then dest = Vector3.new(dest.X, gy + 3.4, dest.Z) else dest = dest + Vector3.new(0, 4, 0) end
        Hub.status = "Teleporting to " .. tostring(label)
        if S.InstantTP then
            root.CFrame = CFrame.new(dest)
            root.AssemblyLinearVelocity = ZERO
        else
            local ok = Mover.travel("tp", Util.cfAt(dest), S.TravelSpeed)
            if not ok then
                Hub.note("tp", "Teleport interrupted.", "bad")
                Hub.status = "Idle"
                return
            end
        end
        Hub.status = "Idle"
        Hub.note("tp", "Arrived: " .. tostring(label), "ok")
    end)
end

----------------------------------------------------------------------
-- misc
----------------------------------------------------------------------
Hub.track(LP.Idled:Connect(function()
    if not S.AntiAFK or not VirtualUser or (UIS and UIS.TouchEnabled) then return end
    pcall(function()
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new(0, 0))
    end)
end))

Hub.loop("walkspeed", function()
    if not S.WalkSpeedOn or Hub.paused then return 0.5 end
    local h = Util.hum()
    if h then h.WalkSpeed = Util.clamp(S.WalkSpeed, 8, Limits.walk()) end
    return 0.25
end)

local LOOT_WORDS = { "chest", "loot", "collect", "pick", "grab", "drop", "treasure", "crate", "meteor", "fragment" }
local LOOT_SKIP = { "quest", "talk", "shop", "buy", "sell", "trade", "mission", "prestige", "reroll" }

Hub.loop("autoloot", function()
    if not S.AutoLoot or Hub.paused or not Util.alive() then return 0.8 end
    local root = Util.root()
    local fired = 0
    for d in pairs(Prompts.set) do
        if d.Parent and d.Enabled and d:IsDescendantOf(Workspace) then
            local pos = Util.posOf(d)
            if pos and (pos - root.Position).Magnitude <= S.LootRadius then
                local text = ((d.ActionText or "") .. " " .. (d.ObjectText or "") .. " " .. d.Name .. " " .. ((d.Parent and d.Parent.Name) or "")):lower()
                local good, bad = false, false
                for _, w in ipairs(LOOT_WORDS) do
                    if text:find(w, 1, true) then good = true end
                end
                for _, w in ipairs(LOOT_SKIP) do
                    if text:find(w, 1, true) then bad = true end
                end
                if good and not bad then
                    Util.firePrompt(d)
                    fired = fired + 1
                    task.wait(0.25)
                    if fired >= 4 then break end
                end
            end
        end
    end
    return 1.2
end)

function Misc.fps(on)
    if not on then return end
    task.spawn(function()
        pcall(function() Lighting.GlobalShadows = false end)
        pcall(function() Lighting.FogEnd = 9e9 end)
        pcall(function() settings().Rendering.QualityLevel = Enum.QualityLevel.Level01 end)
        local n = 0
        for _, d in ipairs(Workspace:GetDescendants()) do
            n = n + 1
            if n % 400 == 0 then task.wait() end
            pcall(function()
                if d:IsA("ParticleEmitter") or d:IsA("Trail") or d:IsA("Smoke") or d:IsA("Fire") or d:IsA("Sparkles") then
                    d.Enabled = false
                elseif d:IsA("BasePart") then
                    d.Material = Enum.Material.SmoothPlastic
                    d.CastShadow = false
                elseif d:IsA("Decal") or d:IsA("Texture") then
                    d.Transparency = 1
                end
            end)
        end
        Hub.note("fps", "FPS boost applied (rejoin to undo).", "ok")
    end)
end

function Misc.render3d(on)
    pcall(function() RunService:Set3dRenderingEnabled(not on) end)
end

function Misc.rejoin()
    pcall(function()
        if #Players:GetPlayers() <= 1 then
            TeleportService:Teleport(game.PlaceId, LP)
        else
            TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LP)
        end
    end)
end

function Misc.hop()
    task.spawn(function()
        Hub.note("hop", "Looking for another server...", "force")
        local url = "https://games.roblox.com/v1/games/" .. tostring(game.PlaceId) .. "/servers/Public?sortOrder=Asc&limit=100"
        local ok, body = pcall(function() return game:HttpGet(url) end)
        if not ok or type(body) ~= "string" then
            Hub.note("hop", "Server list request failed on this executor.", "bad")
            return
        end
        local ok2, data = pcall(function() return HttpService:JSONDecode(body) end)
        if not ok2 or type(data) ~= "table" or type(data.data) ~= "table" then
            Hub.note("hop", "Could not read the server list.", "bad")
            return
        end
        local pool = {}
        for _, sv in ipairs(data.data) do
            if sv.id ~= game.JobId and type(sv.playing) == "number" and type(sv.maxPlayers) == "number"
                and sv.playing < sv.maxPlayers - 1 then
                pool[#pool + 1] = sv.id
            end
        end
        if #pool == 0 then
            Hub.note("hop", "No free server found right now.", "bad")
            return
        end
        pcall(function() TeleportService:TeleportToPlaceInstance(game.PlaceId, pool[math.random(1, #pool)], LP) end)
    end)
end

Hub.track(GuiService.ErrorMessageChanged:Connect(function(msg)
    if S.AutoRejoin and type(msg) == "string" and msg ~= "" then
        task.delay(5, function()
            if Hub.alive and S.AutoRejoin then Misc.rejoin() end
        end)
    end
end))

-- staff alert: if someone with a high rank in the game's owner group is in the server, pause automation
local STAFF_RANK = 200
function Hub.checkStaff(p)
    if not S.PauseOnStaff or p == LP then return end
    if game.CreatorType ~= Enum.CreatorType.Group then return end
    task.spawn(function()
        local ok, rank = pcall(function() return p:GetRankInGroup(game.CreatorId) end)
        if ok and type(rank) == "number" and rank >= STAFF_RANK and Hub.alive then
            Hub.staff[p] = true
            Hub.paused = true
            Hub.pauseReason = p.Name .. " (group rank " .. string.format("%.0f", rank) .. ")"
            Hub.status = "PAUSED - staff in server: " .. p.Name
            Hub.note("staff", "Possible staff in server (" .. p.Name .. "). Automation paused.", "bad")
        end
    end)
end

function Hub.resume()
    Hub.paused = false
    Hub.pauseReason = ""
    Hub.status = "Idle"
    for p in pairs(Hub.staff) do Hub.staff[p] = nil end
end

Hub.track(Players.PlayerAdded:Connect(Hub.checkStaff))
Hub.track(Players.PlayerRemoving:Connect(function(p)
    if Hub.staff[p] then
        Hub.staff[p] = nil
        if next(Hub.staff) == nil and Hub.paused then
            Hub.resume()
            Hub.note("staff", "Staff left. Automation resumed.", "ok")
        end
    end
end))

----------------------------------------------------------------------
-- scanner report
----------------------------------------------------------------------
function Scan.capabilities()
    local function yn(v) return v and "yes" or "no" end
    local ex = "unknown"
    if X.ident then
        local ok, a, b = pcall(X.ident)
        if ok then ex = tostring(a) .. (b and (" " .. tostring(b)) or "") end
    end
    return string.format(
        "Executor: %s\nfiles %s | asset %s | prompt %s | signal %s | connections %s | netowner %s | VIM %s | VUser %s",
        ex, yn(X.writefile and X.readfile), yn(X.getasset), yn(X.fireprompt), yn(X.firesignal),
        yn(X.getconns), yn(X.isowner), yn(VIM), yn(VirtualUser))
end

function Scan.report()
    local lines = {}
    local function add(s) lines[#lines + 1] = s end
    local gname = "?"
    pcall(function() gname = MarketplaceService:GetProductInfo(game.PlaceId).Name end)
    add("MILLIE HUB v" .. CFG.VERSION .. " scan")
    add("Game: " .. tostring(gname) .. "  (place " .. tostring(game.PlaceId) .. ")")
    add("StreamingEnabled: " .. tostring(Workspace.StreamingEnabled) .. " | Scanner scope: objects currently replicated to this client")
    add(Scan.capabilities())
    add("Player level guess: " .. tostring(Util.playerLevel() or "not found"))
    local alive = Mobs.alive()
    add("Mobs alive in memory: " .. #alive .. "   known types: " .. (function()
        local c = 0
        for _ in pairs(Mobs.known) do c = c + 1 end
        return c
    end)())
    local rows = {}
    for base, k in pairs(Mobs.known) do
        rows[#rows + 1] = string.format("  %s%s%s", base, k.level and (" [lv " .. string.format("%.0f", k.level) .. "]") or "", k.npc and " (npc-like)" or "")
    end
    table.sort(rows)
    for i = 1, math.min(#rows, 14) do add(rows[i]) end
    local root = Util.root()
    if root then
        local near = {}
        for _, e in ipairs(alive) do near[#near + 1] = { e = e, d = (e.root.Position - root.Position).Magnitude } end
        table.sort(near, function(a, b) return a.d < b.d end)
        add("Nearest mobs:")
        for i = 1, math.min(#near, 5) do
            add(string.format("  %s  %.0f studs  hp %.0f", near[i].e.base, near[i].d, near[i].e.hum.Health))
        end
    end
    add("Quest NPC candidates: " .. #Quest.prompts .. "   (progress tracker: " .. Quest.progV .. ")")
    local shown = 0
    for _, c in ipairs(Quest.prompts) do
        if c.score >= 1 and shown < 8 then
            shown = shown + 1
            add("  " .. c.label .. "  score " .. c.score)
        end
    end
    local b = Attack.findButton()
    add("Attack button found: " .. (b and b:GetFullName() or "no") .. "   method now: " .. Attack.methods[Attack.idx] .. "   last good: " .. tostring(Attack.good))
    add("Tools: " .. table.concat(Equip.tools(), ", "))
    add(string.format("Movement: %s | setting %s | pull-backs %d | last: %s", Mover.describe(), S.MoveMode, Mover.rollbacks, Mover.lastEvent))
    local st = {}
    for m, v in pairs(Attack.stats) do st[#st + 1] = string.format("%s %d/%d", m, v.hits, v.tries) end
    table.sort(st)
    add("Attack hits/tries: " .. (#st == 0 and "none yet" or table.concat(st, ", ")) .. "  | last test: " .. tostring(Attack.lastTest or "-"))
    add(string.format("Spy: %s (%d logged) | macros: %d | prestige rank %d, next level %d | item engine: %s", tostring(Spy.hooked or "no hook"), Spy.count, #Spy.macroNames(), S.PrestigeRank, Prestige.required(), Items.statusText))
    local rem = {}
    pcall(function()
        for _, d in ipairs(game:GetService("ReplicatedStorage"):GetDescendants()) do
            if d:IsA("RemoteEvent") or d:IsA("RemoteFunction") then
                local l = d.Name:lower()
                for _, w in ipairs({ "quest", "combat", "attack", "m1", "hit", "damage", "skill", "equip", "weapon" }) do
                    if l:find(w, 1, true) then
                        rem[#rem + 1] = d.Name
                        break
                    end
                end
            end
            if #rem >= 20 then break end
        end
    end)
    add("Interesting remotes (" .. #rem .. "): " .. table.concat(rem, ", "))
    local errs = {}
    for k, v in pairs(Hub.errors) do errs[#errs + 1] = k .. ": " .. v end
    table.sort(errs)
    add("Module errors: " .. (#errs == 0 and "none" or ""))
    for _, e in ipairs(errs) do add("  " .. e) end
    return table.concat(lines, "\n")
end

----------------------------------------------------------------------
-- config save / load (running toggles are never restored)
----------------------------------------------------------------------
function Cfg.save()
    if not (X.writefile and HttpService) then return false end
    local data = {}
    for _, k in ipairs(PERSIST) do data[k] = S[k] end
    local ok, json = pcall(function() return HttpService:JSONEncode(data) end)
    if not ok then return false end
    pcall(X.makefolder, CFG.FOLDER)
    return pcall(X.writefile, CFG.FOLDER .. "/settings.json", json)
end

function Cfg.load()
    if not (X.readfile and X.isfile and HttpService) then return false end
    local path = CFG.FOLDER .. "/settings.json"
    local okf, exists = pcall(X.isfile, path)
    if not (okf and exists) then return false end
    local ok, raw = pcall(X.readfile, path)
    if not ok or type(raw) ~= "string" then return false end
    local ok2, data = pcall(function() return HttpService:JSONDecode(raw) end)
    if not ok2 or type(data) ~= "table" then return false end
    for _, k in ipairs(PERSIST) do
        local v = data[k]
        if v ~= nil and type(v) == type(S[k]) then S[k] = v end
    end
    return true
end

Hub.loop("saver", function()
    if Hub.dirtyAt and os.clock() - Hub.dirtyAt > 2 then
        Hub.dirtyAt = nil
        Cfg.save()
    end
    return 1
end)

Hub.loop("staffscan", function()
    for _, p in ipairs(Players:GetPlayers()) do Hub.checkStaff(p) end
    return 45
end)

----------------------------------------------------------------------
-- shutdown / panic
----------------------------------------------------------------------
function Hub.disableAll()
    for _, k in ipairs({ "AutoFarm", "AutoQuest", "BringMobs", "Hitbox", "Reach", "AutoLoot", "Noclip", "WalkSpeedOn", "AutoAttack", "AutoPrestige", "AutoBoss", "ItemRun", "SpyOn" }) do
        S[k] = false
        if UI.toggles[k] then pcall(UI.toggles[k].Set, false, true) end
    end
    for _, k in ipairs({ "SkillZ", "SkillX", "SkillC", "SkillV", "SkillG" }) do S[k] = false end
    pcall(Hitbox.restoreAll)
    pcall(Reach.restore)
    pcall(Items.stop)
    Mobs.want = nil
    Spy.on = false
    Mover.release()
end

function Hub.Destroy()
    if not Hub.alive then return end
    Hub.alive = false
    Spy.on = false
    if ENV.__MH_SPY_CAPTURE == Spy.capture then ENV.__MH_SPY_CAPTURE = nil end
    pcall(Hitbox.restoreAll)
    pcall(Reach.restore)
    pcall(Misc.render3d, false)
    pcall(Mover.release)
    for _, c in ipairs(Hub.conns) do
        pcall(function() c:Disconnect() end)
    end
    if Hub.gui then pcall(function() Hub.gui:Destroy() end) end
    if ENV.__MILLIE_HUB == Hub then ENV.__MILLIE_HUB = nil end
end

function Hub.panic()
    Hub.disableAll()
    Hub.Destroy()
end


----------------------------------------------------------------------
-- game data (from public guides; every name is matched fuzzily at runtime)
----------------------------------------------------------------------
DB.islands = {
    { "Starter Island", { "starter", "foosha", "fusha" } },
    { "Legacy Island", { "legacy" } },
    { "Namek Island", { "namek" } },
    { "Dandadan Island", { "dandadan" } },
    { "Scrapyard Island", { "scrapyard" } },
    { "Karakura Island", { "karakura" } },
    { "Jungle Island", { "jungle" } },
    { "Ice Land", { "iceland", "ice land", "ice island" } },
    { "A City", { "a city", "acity" } },
    { "Slayer Mansion", { "slayer", "mansion" } },
    { "Jujutsu Academy", { "jujutsu", "jiujutsu", "jiu jitsu", "jujitsu", "academy", "jujutsu high" } },
    { "Jujutsu High", { "jujutsu high" } },
    { "Tokyo Ghoul Island", { "ghoul", "tokyo" } },
    { "WOO Island", { "woo", "hollow", "hueco" } },
    { "June Island", { "june" } },
    { "Seventh Company Island", { "seventh", "fire force" } },
    { "Foosha Island", { "foosha" } },
    { "Shells Town", { "shells" } },
    { "Orange Town", { "orange" } },
    { "Shimotsuki Village", { "shimotsuki" } },
    { "Alvida Island", { "alvida" } },
    { "Baratie", { "baratie" } },
    { "Mink Island", { "mink" } },
    { "Arlong Park", { "arlong" } },
    { "Haki Island", { "haki island" } },
}

function DB.aliases(name)
    local l = name:lower()
    for _, i in ipairs(DB.islands) do
        if i[1]:lower() == l then return i[2] end
    end
    return { l }
end

-- { name, aliases, island }
DB.bosses = {
    { "Gojo", { "gojo" }, "Jujutsu High" },
    { "Sukuna", { "sukuna" }, "Jujutsu High" },
    { "Aizen", { "aizen" }, "WOO Island" },
    { "Ichigo", { "ichigo" }, "WOO Island" },
    { "Rudo", { "rudo" }, "A City" },
    { "Garou", { "garou" }, "A City" },
    { "Blast", { "blast" }, "A City" },
    { "Akaza", { "akaza", "aaza" }, "Slayer Mansion" },
    { "Kaneki", { "kaneki" }, "Tokyo Ghoul Island" },
    { "Turbo Granny", { "turbo granny", "granny" }, "Jungle Island" },
    { "Crimson Owl", { "crimson owl" }, nil },
    { "Sid Kaganu", { "kaganu" }, nil },
    { "Uta", { "uta" }, nil },
    { "Yeti", { "yeti" }, "Shimotsuki Village" },
    { "Buggy", { "buggy" }, "Orange Town" },
    { "Johji", { "johji" }, "Orange Town" },
    { "Axe Hand Morgan", { "morgan", "axe hand" }, "Shells Town" },
    { "Alvida", { "alvida" }, "Alvida Island" },
}

function DB.boss(name)
    for _, b in ipairs(DB.bosses) do
        if b[1] == name then return b end
    end
    return nil
end

-- Level fallback for the Gwynn's Shrine Legacy Piece experience only.
-- Snapshot source: public wiki mirror of the game's Trello board (25 Aug 2026).
-- Runtime Humanoid/Attribute/Value data always takes priority over this table.
DB.mobLevelsPlaceId = 111097829542198
DB.mobLevels = {
    ["bandit"] = 5,
    ["bandit leader"] = 200,
    ["namekian"] = 250,
    ["piccolo"] = 500,
    ["serpoian"] = 750,
    ["serpoian true form"] = 1000,
    ["turbo granny"] = 1000,
    ["beggar"] = 1350,
    ["aristocrat"] = 1750,
    ["dungeon demon"] = 2000,
    ["cursed student"] = 2250,
    ["cursed teacher"] = 2750,
    ["hollow"] = 3250,
    ["shinigami"] = 3850,
    ["demon slayer"] = 4500,
    ["cursed student high tier"] = 4500,
    ["nameless pillar"] = 5250,
    ["cursed teacher high tier"] = 5250,
    ["ghoul investigator"] = 6000,
    ["ghoul"] = 6750,
}

-- level needed for each next prestige rank (Iron IV ... Silver I); later ranks are extrapolated
DB.prestige = { 1500, 1750, 2000, 2250, 2500, 2850, 3200, 3550, 3900, 4300, 4700, 5100 }

-- kind: shop | boss | bossnpc | world | raid | pass | spec | meteor
DB.items = {}
local function I(n, c, k, t)
    t = t or {}
    t.n, t.c, t.k = n, c, k
    DB.items[#DB.items + 1] = t
end
I("Katana", "Weapon", "shop", { npc = { "katana seller", "katana" }, how = "Buy it from the Katana Seller." })
I("Saber", "Weapon", "shop", { npc = { "shanks" }, isl = "Starter Island", how = "Buy it from Shanks on Starter Island." })
I("Ace", "Weapon", "shop", { npc = { "shanks" }, isl = "Starter Island", how = "Buy it from Shanks on Starter Island." })
I("Pipe", "Weapon", "shop", { npc = { "pipe" }, isl = "Jungle Island", how = "Buy it from the Pipe NPC on Jungle Island." })
I("Hakuoki Katana", "Weapon", "shop", { alias = { "hakuouki", "hakuoki" }, npc = { "sword", "weapon", "seller", "shop" }, isl = "Foosha Island", how = "Sea 1 shop weapon (850 Beli) on Foosha Island." })
I("Crude Cutlass", "Weapon", "shop", { npc = { "sword", "weapon", "seller", "shop" }, isl = "Foosha Island", how = "Sea 1 shop weapon (850 Beli) on Foosha Island." })
I("Dororo Katana", "Weapon", "shop", { npc = { "sword", "weapon", "seller", "shop" }, isl = "Shells Town", how = "Sea 1 shop weapon (850 Beli) in Shells Town." })
I("Rurouni Katana", "Weapon", "shop", { npc = { "sword", "weapon", "seller", "shop" }, isl = "Shells Town", how = "Sea 1 shop weapon (850 Beli) in Shells Town." })
I("Bazooka", "Weapon", "shop", { npc = { "weapon", "seller", "shop" }, isl = "Shells Town", how = "Sea 1 shop weapon (1,000 Beli) in Shells Town." })
I("Axe Hand", "Weapon", "boss", { boss = { "morgan", "axe hand" }, isl = "Shells Town", kills = 12, how = "Boss drop (about 5%): Axe Hand Morgan, Shells Town." })
I("Frost Blade", "Weapon", "boss", { boss = { "yeti" }, isl = "Shimotsuki Village", kills = 15, how = "Boss drop (about 3%): Yeti, Shimotsuki Village." })
I("Whip", "Weapon", "boss", { boss = { "johji" }, isl = "Orange Town", kills = 12, how = "Boss drop (about 5%): Johji, Orange Town." })
I("Buggy's Knife", "Weapon", "boss", { alias = { "buggy" }, boss = { "buggy" }, isl = "Orange Town", kills = 14, how = "Boss drop (about 4%): Buggy, Orange Town." })
I("Zangetsu", "Weapon", "bossnpc", { boss = { "ichigo" }, npc = { "rukia" }, isl = "WOO Island", kills = 3, how = "Ichigo boss drops, then Rukia on WOO Island (needs Shinigami race)." })
I("First Espada", "Weapon", "bossnpc", { boss = { "aizen" }, npc = { "starrk", "stark" }, isl = "WOO Island", kills = 3, how = "Hoyoku from the Aizen boss, then Starrk on WOO Island." })
I("Mind Master", "Weapon", "bossnpc", { boss = { "aizen" }, npc = { "aizen" }, isl = "WOO Island", kills = 3, how = "Aizen boss drops, then the Aizen NPC on WOO Island." })
I("Thunder", "Weapon", "shop", { npc = { "zenitsu" }, isl = "Slayer Mansion", how = "Buy the gourds from Zenitsu at Slayer Mansion (costly, repeat)." })
I("Pure Love", "Weapon", "raid", { npc = { "yuta" }, isl = "Jujutsu High", how = "Raid weapon: finish the raid, then claim from Yuta. The raid itself is not automated." })
I("Black Knight", "Weapon", "world", { boss = { "kaganu" }, kills = 40, how = "Chance drop from the Sid Kaganu world boss (random island)." })
I("Nightblade", "Weapon", "pass", { how = "Gamepass only: nothing to automate." })
I("Strongest Saiyan", "Spec", "spec", { npc = { "goku" }, isl = "Jungle Island", manual = true, how = "Goku NPC on Jungle Island (Saiyan race + Dragon Ball)." })
I("Turbo Spirit", "Spec", "bossnpc", { boss = { "turbo granny", "granny" }, npc = { "okarun" }, isl = "Jungle Island", kills = 3, manual = true, how = "Turbo Granny drops, then Okarun on Jungle Island (Yokai race)." })
I("Scrap Brawler", "Spec", "bossnpc", { boss = { "rudo" }, npc = { "rudo" }, isl = "A City", kills = 3, manual = true, how = "Rudo boss drops, then the seller in A City." })
I("Destructive Moon", "Spec", "bossnpc", { boss = { "akaza", "aaza" }, npc = { "akaza", "kyuki" }, isl = "Slayer Mansion", kills = 8, manual = true, how = "Slayer Mansion questline: Akaza boss kills, then Akaza / Kyuki." })
I("One Eyed Ghoul", "Spec", "bossnpc", { boss = { "kaneki" }, npc = { "kaneki", "ghoul" }, isl = "Tokyo Ghoul Island", kills = 3, manual = true, how = "Kaneki boss drops, then the seller on Tokyo Ghoul Island (Ghoul race)." })
I("Hero Hunter", "Spec", "bossnpc", { boss = { "garou" }, npc = { "hero" }, isl = "A City", kills = 3, manual = true, how = "Garou boss drops, then the hero NPC in A City (Human race)." })
I("Storm Esper", "Spec", "meteor", { npc = { "tatsumaki", "storm esper" }, isl = "Legacy Island", manual = true, how = "Collect meteor fragments on Jungle Island (event every ~15 min), then the Tatsumaki seller on Legacy Island." })
I("First Hero", "Spec", "bossnpc", { boss = { "blast" }, npc = { "hero", "first hero" }, isl = "A City", kills = 3, manual = true, how = "Blast boss materials, then the hero NPC in A City." })
I("Cursed King Sukuna", "Spec", "bossnpc", { boss = { "gojo" }, npc = { "sukuna" }, isl = "Jujutsu High", kills = 10, manual = true, how = "Needs 4 Sukuna Fingers + money first; then 10 Gojo boss kills, then the Sukuna NPC." })
I("Limitless Gojo", "Spec", "bossnpc", { boss = { "sukuna" }, npc = { "gojo" }, isl = "Jujutsu High", kills = 12, manual = true, how = "Needs Six Eyes + money first; then Sukuna boss kills, then the Gojo NPC." })



----------------------------------------------------------------------
-- remote spy + recorder + macros (learn how the game talks to the server, then replay it)
----------------------------------------------------------------------
Spy.log, Spy.rate, Spy.muted, Spy.macros = {}, {}, {}, {}
Spy.on, Spy.count, Spy.rec, Spy.hooked = false, 0, nil, nil
local NOISE_WORDS = { "ping", "heartbeat", "mouse", "camera", "cframe", "position", "movement", "replicate", "tick", "sync", "fps" }

function Spy.ser(v, depth)
    depth = depth or 0
    local t = typeof(v)
    if t == "string" then
        if #v > 44 then v = v:sub(1, 41) .. "..." end
        return string.format("%q", v)
    elseif t == "number" then
        return Util.fmt(v)
    elseif t == "boolean" or t == "nil" then
        return tostring(v)
    elseif t == "Instance" then
        local ok, n = pcall(function() return v:GetFullName() end)
        return "<" .. (ok and n or "?") .. ">"
    elseif t == "Vector3" then
        return string.format("V3(%.0f,%.0f,%.0f)", v.X, v.Y, v.Z)
    elseif t == "CFrame" then
        local p = v.Position
        return string.format("CF(%.0f,%.0f,%.0f)", p.X, p.Y, p.Z)
    elseif t == "table" then
        if depth >= 2 then return "{...}" end
        local out, n = {}, 0
        for k, x in pairs(v) do
            n = n + 1
            if n > 8 then
                out[#out + 1] = "..."
                break
            end
            out[#out + 1] = (type(k) == "string" and (k .. "=") or "") .. Spy.ser(x, depth + 1)
        end
        return "{" .. table.concat(out, ", ") .. "}"
    end
    return "<" .. t .. ">"
end

function Spy.line(e)
    local a = {}
    for i = 1, e.args.n do a[i] = Spy.ser(e.args[i]) end
    local verb = e.dir == "in" and "RECV" or (e.m == "InvokeServer" and "INVOKE" or "FIRE")
    return string.format("%6.1f %s%s %s(%s)", e.t % 10000, e.mine and "[hub] " or "", verb, e.path, table.concat(a, ", "))
end

function Spy.push(e)
    Spy.log[#Spy.log + 1] = e
    if #Spy.log > 150 then table.remove(Spy.log, 1) end
    Spy.count = Spy.count + 1
    if Spy.rec and e.dir == "out" and not e.mine then Spy.rec.steps[#Spy.rec.steps + 1] = e end
end

local function noisy(path)
    local now = os.clock()
    local r = Spy.rate[path]
    if not r or now - r.t > 1 then
        r = { t = now, n = 0 }
        Spy.rate[path] = r
    end
    r.n = r.n + 1
    if not S.SpyQuiet then return false end
    if Spy.muted[path] then return true end
    if r.n > 8 then
        Spy.muted[path] = true
        return true
    end
    local l = path:lower()
    for _, w in ipairs(NOISE_WORDS) do
        if l:find(w, 1, true) then return true end
    end
    return false
end

function Spy.capture(remote, method, args, mine)
    if not Spy.on then return end
    local cn = remote.ClassName
    if cn ~= "RemoteEvent" and cn ~= "RemoteFunction" and cn ~= "UnreliableRemoteEvent" then return end
    local path = remote:GetFullName()
    if noisy(path) then return end
    Spy.push({ t = os.clock(), path = path, m = method, args = args, mine = mine and true or false, dir = "out" })
end

function Spy.captureIn(remote, args)
    if not Spy.on then return end
    local path = remote:GetFullName()
    if noisy("<" .. path) then return end
    Spy.push({ t = os.clock(), path = path, m = "OnClientEvent", args = args, mine = false, dir = "in" })
end

-- hooks are installed once per executor session; every new hub instance just re-binds the capture function
function Spy.install()
    if Spy.hooked then return true end
    ENV.__MH_SPY_CAPTURE = Spy.capture
    if ENV.__MH_SPY_HOOKED then
        Spy.hooked = ENV.__MH_SPY_HOOKED
        return true
    end
    local newcc = newcclosure or function(f) return f end
    local function mineNow()
        local ok, r = pcall(function() return checkcaller and checkcaller() end)
        return ok and r or false
    end
    if hookmetamethod and getnamecallmethod then
        local old
        local ok = pcall(function()
            old = hookmetamethod(game, "__namecall", newcc(function(self, ...)
                local m = getnamecallmethod()
                if m == "FireServer" or m == "InvokeServer" then
                    local f = ENV.__MH_SPY_CAPTURE
                    if f then
                        -- logging runs in its own thread so the game's namecall state is never disturbed
                        task.defer(f, self, m, table.pack(...), mineNow())
                    end
                end
                return old(self, ...)
            end))
        end)
        if ok and old then
            Spy.hooked = "__namecall"
            ENV.__MH_SPY_HOOKED = "__namecall"
            return true
        end
    end
    if hookfunction then
        local ok = pcall(function()
            local re, rf = Instance.new("RemoteEvent"), Instance.new("RemoteFunction")
            local oldFS, oldIS
            oldFS = hookfunction(re.FireServer, newcc(function(self, ...)
                local f = ENV.__MH_SPY_CAPTURE
                if f then task.defer(f, self, "FireServer", table.pack(...), mineNow()) end
                return oldFS(self, ...)
            end))
            oldIS = hookfunction(rf.InvokeServer, newcc(function(self, ...)
                local f = ENV.__MH_SPY_CAPTURE
                if f then task.defer(f, self, "InvokeServer", table.pack(...), mineNow()) end
                return oldIS(self, ...)
            end))
        end)
        if ok then
            Spy.hooked = "hookfunction"
            ENV.__MH_SPY_HOOKED = "hookfunction"
            return true
        end
    end
    return false
end

function Spy.watchIncoming()
    if Spy.watching then return end
    Spy.watching = true
    local n = 0
    pcall(function()
        for _, d in ipairs(game:GetService("ReplicatedStorage"):GetDescendants()) do
            if d:IsA("RemoteEvent") and n < 60 then
                n = n + 1
                Hub.track(d.OnClientEvent:Connect(function(...) Spy.captureIn(d, table.pack(...)) end))
            end
        end
    end)
end

function Spy.setOn(on)
    Spy.on = on and true or false
    if Spy.on then
        local ok = Spy.install()
        Spy.watchIncoming()
        if ok then
            Hub.note("spy", "Remote Spy on (" .. tostring(Spy.hooked) .. "). Use the game normally.", "ok")
        else
            Hub.note("spy", "No remote hook on this executor: only server-to-you messages are logged.", "bad")
        end
    end
end

function Spy.text(n)
    if #Spy.log == 0 then
        if not Spy.on then return "Spy is off. Turn it on, then use the game: buy something, open the island teleport, prestige..." end
        return "Spy is on. Nothing logged yet (noisy remotes are hidden)."
    end
    local out = {}
    for i = math.max(1, #Spy.log - n + 1), #Spy.log do out[#out + 1] = Spy.line(Spy.log[i]) end
    return table.concat(out, "\n")
end

-- macro (de)serialisation -------------------------------------------------
function Spy.encode(v)
    local t = typeof(v)
    if t == "string" or t == "number" or t == "boolean" then return v end
    if t == "nil" then return { __t = "nil" } end
    if t == "Vector3" then return { __t = "v3", v = { v.X, v.Y, v.Z } } end
    if t == "CFrame" then return { __t = "cf", v = { v:GetComponents() } } end
    if t == "Instance" then
        if v == LP.Character then return { __t = "me", k = "char" } end
        if v == LP then return { __t = "me", k = "player" } end
        local ok, p = pcall(function() return v:GetFullName() end)
        return { __t = "inst", p = ok and p or "" }
    end
    if t == "table" then
        if #v > 0 then
            local a = {}
            for i, x in ipairs(v) do a[i] = Spy.encode(x) end
            return { __t = "arr", v = a }
        end
        local o = {}
        for k, x in pairs(v) do o[tostring(k)] = Spy.encode(x) end
        return { __t = "map", v = o }
    end
    return { __t = "str", v = tostring(v) }
end

function Spy.resolve(path)
    local cur = game
    for part in tostring(path):gmatch("[^%.]+") do
        cur = cur and cur:FindFirstChild(part)
        if not cur then return nil end
    end
    return cur
end

function Spy.decode(v)
    if type(v) ~= "table" then return v end
    local t = v.__t
    if t == "nil" then return nil end
    if t == "v3" then return Vector3.new(v.v[1], v.v[2], v.v[3]) end
    if t == "cf" then return CFrame.new(table.unpack(v.v)) end
    if t == "me" then return v.k == "char" and LP.Character or LP end
    if t == "inst" then return Spy.resolve(v.p) end
    if t == "arr" then
        local a = {}
        for i, x in ipairs(v.v) do a[i] = Spy.decode(x) end
        return a
    end
    if t == "map" then
        local o = {}
        for k, x in pairs(v.v) do o[k] = Spy.decode(x) end
        return o
    end
    if t == "str" then return v.v end
    return nil
end

function Spy.macroNames()
    local out = {}
    for n in pairs(Spy.macros) do out[#out + 1] = n end
    table.sort(out)
    return out
end

function Spy.save()
    if not (X.writefile and HttpService) then return false end
    local ok, json = pcall(function() return HttpService:JSONEncode(Spy.macros) end)
    if not ok then return false end
    pcall(X.makefolder, CFG.FOLDER)
    return pcall(X.writefile, CFG.FOLDER .. "/macros.json", json)
end

function Spy.load()
    if not (X.readfile and X.isfile and HttpService) then return end
    local path = CFG.FOLDER .. "/macros.json"
    local okf, ex = pcall(X.isfile, path)
    if not (okf and ex) then return end
    local ok, raw = pcall(X.readfile, path)
    if not ok or type(raw) ~= "string" then return end
    local ok2, data = pcall(function() return HttpService:JSONDecode(raw) end)
    if ok2 and type(data) == "table" then Spy.macros = data end
end

function Spy.delete(name)
    Spy.macros[name] = nil
    Spy.save()
end

function Spy.record(seconds, name)
    if Spy.rec then
        Hub.note("rec", "Already recording.", "bad")
        return
    end
    if not Spy.install() then
        Hub.note("rec", "This executor cannot hook remotes (no hookmetamethod / hookfunction).", "bad")
        return
    end
    Spy.on = true
    if UI.toggles.SpyOn then UI.toggles.SpyOn.Set(true, true) end
    if not name or name == "" then
        local n = 1
        while Spy.macros["Macro " .. n] do n = n + 1 end
        name = "Macro " .. n
    end
    Spy.rec = { steps = {} }
    Hub.note("recst", "Recording " .. seconds .. "s: do the action in the game NOW.", "force")
    Hub.status = "Recording '" .. name .. "'..."
    task.delay(seconds, function()
        local rec = Spy.rec
        Spy.rec = nil
        Hub.status = "Idle"
        if not rec or #rec.steps == 0 then
            Hub.note("recend", "Nothing recorded: the game sent no remote calls (or they were muted).", "bad")
            return
        end
        local steps, prev = {}, rec.steps[1].t
        for i, e in ipairs(rec.steps) do
            if i > 40 then break end
            local a = {}
            for j = 1, e.args.n do a[tostring(j)] = Spy.encode(e.args[j]) end
            steps[#steps + 1] = { p = e.path, m = e.m, n = e.args.n, a = a, d = Util.clamp(e.t - prev, 0.05, 2) }
            prev = e.t
        end
        Spy.macros[name] = steps
        Spy.save()
        S.MacroSel = name
        if UI.dropdowns.MacroSel then UI.dropdowns.MacroSel.Set(name, true) end
        Hub.note("recend", "Saved macro '" .. name .. "' (" .. #steps .. " calls).", "ok")
    end)
end

function Spy.play(name)
    local steps = Spy.macros[name]
    if not steps then return 0 end
    local fired = 0
    for _, st in ipairs(steps) do
        task.wait(st.d or 0.1)
        local r = Spy.resolve(st.p)
        if not r then
            Hub.note("macrofail", "Macro '" .. name .. "': remote not found (" .. tostring(st.p) .. ")", "bad")
            return fired
        end
        local args = {}
        for i = 1, st.n or 0 do args[i] = Spy.decode(st.a and st.a[tostring(i)]) end
        local ok = pcall(function()
            if st.m == "InvokeServer" then
                r:InvokeServer(table.unpack(args, 1, st.n or 0))
            else
                r:FireServer(table.unpack(args, 1, st.n or 0))
            end
        end)
        if ok then fired = fired + 1 end
    end
    return fired
end

function Spy.describe(name)
    local steps = Spy.macros[name]
    if not steps then return "No macro selected." end
    local out = { name .. ": " .. #steps .. " call(s)" }
    for i, st in ipairs(steps) do
        if i > 6 then
            out[#out + 1] = "..."
            break
        end
        out[#out + 1] = string.format("%d. %s %s (%d arg)", i, st.m == "InvokeServer" and "INVOKE" or "FIRE", st.p, st.n or 0)
    end
    return table.concat(out, "\n")
end



----------------------------------------------------------------------
-- shared helpers for the goal modules
----------------------------------------------------------------------
local BOSS_ANY = "Any boss"

function Util.nameHas(name, alias)
    local l = tostring(name):lower()
    local padded = " " .. l:gsub("[^%w]+", " ") .. " "
    if padded:find(" " .. alias .. " ", 1, true) then return true end
    if #alias >= 5 and l:find(alias, 1, true) then return true end
    return false
end

function Util.nameMatchAny(name, list)
    for _, a in ipairs(list) do
        if Util.nameHas(name, a) then return true end
    end
    return false
end

function Util.btnText(b)
    local tx = b:IsA("TextButton") and b.Text or ""
    if tx == "" then
        local lbl = b:FindFirstChildWhichIsA("TextLabel", true)
        tx = lbl and lbl.Text or ""
    end
    return tx
end

-- the player's level read from the HUD (fallback when no leaderstats / attribute exists)
function Util.guiLevel()
    local now = os.clock()
    if Util._glT and now - Util._glT < 5 then return Util._gl end
    Util._glT = now
    local pg = LP:FindFirstChild("PlayerGui")
    local best, bestPref
    if pg then
        local n = 0
        for _, d in ipairs(pg:GetDescendants()) do
            n = n + 1
            if n % 700 == 0 then task.wait() end
            if d:IsA("TextLabel") and d.Visible and #d.Text < 24 then
                local lv = d.Text:match("^%s*[Ll][Vv][Ll]?%.?%s*:?%s*(%d+)%s*$") or d.Text:match("^%s*[Ll]evel%s*:?%s*(%d+)%s*$")
                lv = lv and tonumber(lv)
                if lv and lv > 0 and lv < 20000 then
                    local pref = false
                    local p = d
                    for _ = 1, 6 do
                        p = p and p.Parent
                        if not p or p == pg then break end
                        local nm = p.Name:lower()
                        if nm:find("exp", 1, true) or nm:find("xp", 1, true) or nm:find("level", 1, true) or nm:find("stat", 1, true) or nm:find("player", 1, true) then
                            pref = true
                            break
                        end
                    end
                    if pref then
                        if not bestPref or lv > bestPref then bestPref = lv end
                    elseif not best or lv > best then
                        best = lv
                    end
                end
            end
        end
    end
    Util._gl = bestPref or best
    return Util._gl
end

----------------------------------------------------------------------
-- islands: fast travel macro > discovered position
----------------------------------------------------------------------
function POI.findIsland(name)
    local aliases = DB.aliases(name)
    for _, p in ipairs(POI.islands) do
        for _, a in ipairs(aliases) do
            if Util.nameHas(p.name, a) then return p end
        end
    end
    return nil
end

function TP.goBlocking(pos)
    local dest = pos
    local gy = Util.groundY(dest)
    if gy then dest = Vector3.new(dest.X, gy + 3.4, dest.Z) else dest = dest + Vector3.new(0, 4, 0) end
    if S.InstantTP then
        local r = Util.root()
        if r then r.CFrame = Util.cfAt(dest) end
        return true
    end
    return Mover.travel("tp", Util.cfAt(dest), S.TravelSpeed)
end

function TP.toIsland(name)
    local mac = "TP: " .. name
    if Spy.macros[mac] then
        Hub.status = "Fast travel: " .. name
        Spy.play(mac)
        task.wait(3.5)
        return true
    end
    local p = POI.findIsland(name)
    if not p then
        POI.scan()
        p = POI.findIsland(name)
    end
    if p then
        Hub.status = "Travelling to " .. name
        return TP.goBlocking(p.pos)
    end
    return false
end

function TP.islandGo(name)
    Hub.stopAutomation("teleport")
    task.spawn(function()
        local ok = TP.toIsland(name)
        if ok then
            Hub.note("tpi", "Done: " .. name, "ok")
        else
            Hub.note("tpi", "Island not loaded. Record a macro named 'TP: " .. name .. "' in Spy while you use the game's own teleport.", "bad")
        end
        Hub.status = "Idle"
    end)
end

----------------------------------------------------------------------
-- NPC interaction for shops / claims (clicks the item's own buy button)
----------------------------------------------------------------------
Items.running, Items.token, Items.statusText, Items.farmOn = false, 0, "Idle.", false
local SHOP_BAD = { "cancel", "close", "no", "decline", "exit", "leave", "delete", "reset", "robux", "abandon", "back", "sell" }
local BUY_WORDS = { "buy", "purchase", "unlock", "get", "claim", "craft", "equip", "select", "confirm", "yes", "accept" }
local GOOD_WORDS = { "accept", "continue", "next", "yes", "confirm", "claim", "buy", "purchase", "unlock", "get", "equip", "craft", "okay", "start", "prestige", "summon", "spawn", "ascend", "rank" }

function Items.setStatus(t)
    Items.statusText = t
    Hub.status = t
end

function Items.labels()
    local out = {}
    for _, r in ipairs(DB.items) do out[#out + 1] = "Auto-" .. r.n end
    return out
end

function Items.byLabel(l)
    for _, r in ipairs(DB.items) do
        if "Auto-" .. r.n == l then return r end
    end
    return nil
end

function Items.describe(l)
    local r = Items.byLabel(l)
    if not r then return "Pick an item." end
    return string.format("%s  [%s]\n%s", r.n, r.c, r.how or "")
end

function Items.has(r)
    local names = { r.n:lower() }
    for _, a in ipairs(r.alias or {}) do names[#names + 1] = a end
    for _, cont in ipairs({ LP.Character, LP:FindFirstChildOfClass("Backpack") }) do
        if cont then
            for _, t in ipairs(cont:GetChildren()) do
                if t:IsA("Tool") then
                    local l = t.Name:lower()
                    for _, n in ipairs(names) do
                        if l:find(n, 1, true) then return true end
                    end
                end
            end
        end
    end
    return false
end

function Items.findNPC(names)
    Quest.scan()
    local root = Util.root()
    local best, bd = nil, math.huge
    for _, c in ipairs(Quest.prompts) do
        if c.hasModel then
            for _, n in ipairs(names) do
                if Util.nameHas(c.name, n) or Util.nameHas(c.label, n) then
                    local d = root and (c.pos - root.Position).Magnitude or 0
                    if d < bd then best, bd = c, d end
                    break
                end
            end
        end
    end
    return best
end

function Items.goNPC(c)
    local root = Util.root()
    if not root then return false end
    local pos = c.pos
    local dir = root.Position - pos
    dir = Vector3.new(dir.X, 0, dir.Z)
    if dir.Magnitude > 0.1 then dir = dir.Unit else dir = Vector3.new(0, 0, 1) end
    local stand = pos + dir * 4
    local gy = Util.groundY(stand)
    if gy then stand = Vector3.new(stand.X, gy + 3.2, stand.Z) end
    return Mover.travel("items", CFrame.lookAt(stand, Vector3.new(pos.X, stand.Y, pos.Z)), S.TravelSpeed)
end

function Items.visibleAll()
    local out = {}
    local pg = LP:FindFirstChild("PlayerGui")
    if not pg then return out end
    local n = 0
    for _, d in ipairs(pg:GetDescendants()) do
        n = n + 1
        if n % 700 == 0 then task.wait() end
        if d:IsA("GuiButton") then
            local tx = Util.btnText(d)
            if tx ~= "" and #tx <= 40 and Util.guiVisible(d) then
                local l = tx:lower()
                local bad = false
                for _, w in ipairs(SHOP_BAD) do
                    if l == w or l:find("%f[%a]" .. w .. "%f[%A]") then
                        bad = true
                        break
                    end
                end
                if not bad then out[d] = tx end
            end
        end
    end
    return out
end

function Items.goodWord(l)
    for _, w in ipairs(GOOD_WORDS) do
        if l:find(w, 1, true) then return true end
    end
    return false
end

-- a shop card shows the item name next to its own Buy button: find that button (never climb into big lists)
function Items.buyFor(w, skip)
    local pg = LP:FindFirstChild("PlayerGui")
    if not pg then return nil end
    local now = os.clock()
    local n = 0
    for _, d in ipairs(pg:GetDescendants()) do
        n = n + 1
        if n % 700 == 0 then task.wait() end
        if (d:IsA("TextLabel") or d:IsA("TextButton")) and #d.Text <= 40 and d.Text:lower():find(w, 1, true)
            and Util.guiVisible(d) and not (skip and skip[d]) then
            local a = d
            for _ = 1, 5 do
                if not a.Parent or a.Parent == pg then break end
                a = a.Parent
                if a:IsA("ScreenGui") then break end
                local btns = {}
                for _, b in ipairs(a:GetDescendants()) do
                    if b:IsA("GuiButton") then btns[#btns + 1] = b end
                end
                if #btns > 6 then break end
                for _, b in ipairs(btns) do
                    if b ~= d and Util.guiVisible(b) then
                        local l = Util.btnText(b):lower()
                        for _, bw in ipairs(BUY_WORDS) do
                            if l == bw or l:find("%f[%a]" .. bw .. "%f[%A]") then
                                if not (Items.lastBuy == b and now - Items.lastBuyT < 2.5) then
                                    Items.lastBuy, Items.lastBuyT = b, now
                                    return b
                                end
                            end
                        end
                    end
                end
            end
            if d:IsA("TextButton") and not (Items.lastBuy == d and now - Items.lastBuyT < 2.5) then
                Items.lastBuy, Items.lastBuyT = d, now
                return d
            end
        end
    end
    return nil
end

-- visible labels / buttons that already contain one of the names (so we only react to NEW ones)
function Items.nameHits(names)
    local out = {}
    local pg = LP:FindFirstChild("PlayerGui")
    if not pg then return out end
    local n = 0
    for _, d in ipairs(pg:GetDescendants()) do
        n = n + 1
        if n % 700 == 0 then task.wait() end
        if (d:IsA("TextLabel") or d:IsA("TextButton")) and #d.Text <= 40 then
            local l = d.Text:lower()
            for _, w in ipairs(names) do
                if l:find(w, 1, true) and Util.guiVisible(d) then
                    out[d] = true
                    break
                end
            end
        end
    end
    return out
end

-- talk to an NPC and click what we want (item name first, then accept/confirm-style buttons)
function Items.talk(c, wanted, doneFn, names)
    names = names or { wanted[1] }
    local before = Items.visibleAll()
    local pre = Items.nameHits(names)
    Util.firePrompt(c.prompt)
    local idle, clicks = 0, 0
    local key = c.prompt.KeyboardKeyCode
    if not key or key == Enum.KeyCode.Unknown then key = Enum.KeyCode.E end
    for i = 1, 14 do
        task.wait(0.55)
        if doneFn and doneFn() then return clicks end
        local now = Items.visibleAll()
        local target
        for _, w in ipairs(names) do
            target = Items.buyFor(w, pre)
            if target then break end
        end
        if not target then
            local bestScore = 0
            for b, tx in pairs(now) do
                if not before[b] then
                    local l = tx:lower()
                    local sc = 1
                    for _, w in ipairs(wanted) do
                        if l:find(w, 1, true) then
                            sc = 4
                            break
                        end
                    end
                    if sc == 1 and Items.goodWord(l) then sc = 2 end
                    if sc > bestScore then target, bestScore = b, sc end
                end
            end
            if target then before[target] = true end
        end
        if target then
            idle = 0
            if Util.fireButton(target) then clicks = clicks + 1 end
        else
            idle = idle + 1
            if clicks > 0 and idle >= 3 then break end
            if clicks == 0 and (i == 2 or i == 6) then
                Util.pressKey(key, (c.prompt.HoldDuration or 0) + 0.25)
            elseif clicks == 0 and (i == 4 or i == 9) then
                pcall(function()
                    c.prompt:InputHoldBegin()
                    task.wait((c.prompt.HoldDuration or 0) + 0.15)
                    c.prompt:InputHoldEnd()
                end)
            end
        end
    end
    return clicks
end

----------------------------------------------------------------------
-- bosses
----------------------------------------------------------------------
function Boss.labels()
    local out = { BOSS_ANY }
    for _, b in ipairs(DB.bosses) do out[#out + 1] = b[1] end
    return out
end

function Boss.patterns(sel)
    if sel == BOSS_ANY then
        local out = {}
        for _, b in ipairs(DB.bosses) do
            for _, a in ipairs(b[2]) do out[#out + 1] = a end
        end
        return out
    end
    local b = DB.boss(sel)
    return b and b[2] or { tostring(sel):lower() }
end

function Boss.byAlias(a)
    for _, b in ipairs(DB.bosses) do
        for _, x in ipairs(b[2]) do
            if x == a then return b end
        end
    end
    return nil
end

function Boss.find(pats)
    local root = Util.root()
    if not root then return nil end
    local best, bd = nil, math.huge
    for _, e in ipairs(Mobs.alive()) do
        if Util.nameMatchAny(e.model.Name, pats) or Util.nameMatchAny(e.base, pats) then
            local d = (e.root.Position - root.Position).Magnitude
            if d < bd then best, bd = e, d end
        end
    end
    return best
end

function Boss.summon(name, pats)
    local mac = "Summon: " .. name
    if Spy.macros[mac] then
        Spy.play(mac)
        return true
    end
    local c = Items.findNPC({ "summon" })
    if not c or not Items.goNPC(c) then return false end
    Items.talk(c, { name:lower(), "summon", "spawn" }, function() return Boss.find(pats) ~= nil end, { name:lower() })
    return true
end

-- make sure the boss is on screen: remembered position > its island > summon
function Boss.ensure(pats, isl, name)
    local e = Boss.find(pats)
    if e then return e end
    for base, k in pairs(Mobs.known) do
        if k.pos and Util.nameMatchAny(base, pats) then
            Hub.status = "Heading to the last seen " .. base
            TP.goBlocking(k.pos)
            task.wait(2)
            e = Boss.find(pats)
            if e then return e end
            break
        end
    end
    if isl then
        Hub.status = "Going to " .. isl .. " for the boss..."
        TP.toIsland(isl)
        task.wait(3)
        e = Boss.find(pats)
        if e then return e end
    end
    if name and Boss.summon(name, pats) then
        for _ = 1, 10 do
            task.wait(1)
            e = Boss.find(pats)
            if e then return e end
        end
    end
    return nil
end

function Boss.kill(e, pats, alive)
    Mobs.want = { patterns = pats, exclusive = true }
    Items.engageFarm(true)
    local t0 = os.clock()
    while alive() and Mobs.isAlive(e) and os.clock() - t0 < 420 do task.wait(0.5) end
    return not Mobs.isAlive(e)
end

Boss.lastTravel = 0
Hub.loop("boss", function()
    if not S.AutoBoss or Hub.paused or Prestige.busy or Items.running then return 1.5 end
    local pats = Boss.patterns(S.BossSel)
    local e = Boss.find(pats)
    if e then
        Mobs.want = { patterns = pats, exclusive = false }
        if not S.AutoFarm and UI.toggles.AutoFarm then UI.toggles.AutoFarm.Set(true) end
        Hub.status = "Boss: " .. e.base
        return 1
    end
    Mobs.want = nil
    local now = os.clock()
    if S.BossIsland and S.BossSel ~= BOSS_ANY and now - Boss.lastTravel > 120 then
        local b = DB.boss(S.BossSel)
        if b and b[3] and not Mover.owner then
            Boss.lastTravel = now
            Hub.status = "Boss: travelling to " .. b[3]
            TP.toIsland(b[3])
        end
    end
    return 3
end)

----------------------------------------------------------------------
-- Auto-Item engine
----------------------------------------------------------------------
function Items.engageFarm(on)
    if on then
        if not S.AutoFarm and UI.toggles.AutoFarm then
            UI.toggles.AutoFarm.Set(true, true)
            Farm.target = nil
        end
        if not S.AutoAttack and UI.toggles.AutoAttack then UI.toggles.AutoAttack.Set(true, true) end
        Items.farmOn = true
    elseif Items.farmOn then
        Items.farmOn = false
        Mobs.want = nil
        if UI.toggles.AutoFarm then UI.toggles.AutoFarm.Set(false, true) end
        Mover.release("farm")
        Farm.target = nil
    end
end

function Items.bossPhase(r, alive)
    local b = Boss.byAlias(r.boss[1])
    local sname = b and b[1] or r.boss[1]
    for k = 1, (r.kills or 1) do
        if not alive() then return end
        local e
        for _ = 1, 8 do
            e = Boss.ensure(r.boss, r.isl, sname)
            if e or not alive() then break end
            Items.setStatus("Waiting for " .. sname .. " to spawn...")
            Items.engageFarm(false)
            for _ = 1, 20 do
                if not alive() then return end
                task.wait(1)
            end
        end
        if not e then return end
        Items.setStatus(string.format("Killing %s (%d/%d)", sname, k, r.kills or 1))
        Boss.kill(e, r.boss, alive)
        task.wait(1.5)
        if Items.has(r) then return end
    end
end

function Items.npcPhase(r, alive)
    Items.engageFarm(false)
    local c = Items.findNPC(r.npc)
    if not c and r.isl then
        Items.setStatus("Going to " .. r.isl .. " to find " .. r.npc[1] .. "...")
        TP.toIsland(r.isl)
        task.wait(3)
        c = Items.findNPC(r.npc)
    end
    if not c then
        Items.setStatus("Could not find the NPC (" .. r.npc[1] .. "). Walk near it once, or record a macro in Spy.")
        Hub.note("npcnf", "NPC not found: " .. r.npc[1], "bad")
        for _ = 1, 5 do
            if not alive() then return false end
            task.wait(1)
        end
        return false
    end
    Items.setStatus("Walking to " .. c.name)
    if not Items.goNPC(c) then return false end
    local wanted = { r.n:lower() }
    for _, a in ipairs(r.alias or {}) do wanted[#wanted + 1] = a end
    Items.setStatus("Talking to " .. c.name)
    Items.talk(c, wanted, function() return Items.has(r) end, wanted)
    return true
end

function Items.meteorWait(r, alive)
    Items.engageFarm(false)
    Items.setStatus("Going to Jungle Island for meteor fragments...")
    TP.toIsland("Jungle Island")
    local oldLoot, oldRad = S.AutoLoot, S.LootRadius
    S.AutoLoot, S.LootRadius = true, 150
    for i = 1, 960 do
        if not alive() then break end
        Items.setStatus(string.format("Waiting for a meteor event (%d s left)...", 960 - i))
        task.wait(1)
    end
    S.AutoLoot, S.LootRadius = oldLoot, oldRad
end

function Items.run(r, token)
    local function alive() return Hub.alive and Items.running and Items.token == token end
    if r.k == "pass" then
        Items.setStatus(r.n .. " is gamepass-only: nothing to automate.")
        return
    end
    for attempt = 1, S.ItemAttempts do
        if not alive() then return end
        if Items.has(r) then
            Items.setStatus("You have " .. r.n .. "!")
            Hub.note("itemok", "Got " .. r.n .. "!", "ok")
            return
        end
        Items.setStatus(string.format("Auto-%s: attempt %d/%d", r.n, attempt, S.ItemAttempts))
        local mac = "Get: " .. r.n
        if Spy.macros[mac] then
            Items.setStatus("Replaying your macro '" .. mac .. "'")
            Spy.play(mac)
            task.wait(1.5)
        end
        if alive() and not Items.has(r) and r.k == "meteor" then Items.meteorWait(r, alive) end
        if alive() and not Items.has(r) and r.boss then Items.bossPhase(r, alive) end
        if alive() and not Items.has(r) and r.npc then Items.npcPhase(r, alive) end
        if not alive() then return end
        if Items.has(r) then
            Items.setStatus("You have " .. r.n .. "!")
            Hub.note("itemok", "Got " .. r.n .. "!", "ok")
            return
        end
        if r.k == "raid" then
            Items.setStatus(r.n .. ": the raid part is not automated. Do the raid, then run this again.")
            return
        end
        if r.manual then
            Items.setStatus("Finished one full cycle for " .. r.n .. ". Check in-game if you got it (cannot be auto-detected).")
            return
        end
        if r.k == "shop" and attempt >= 3 then
            Items.setStatus("Could not buy " .. r.n .. " (money? wrong NPC?). Record 'Get: " .. r.n .. "' in Spy while buying it by hand.")
            return
        end
        task.wait(1)
    end
    Items.setStatus("Stopped after " .. S.ItemAttempts .. " attempts.")
end

function Items.start()
    local r = Items.byLabel(S.ItemSel)
    if not r then
        Hub.note("item", "Pick an item first.", "bad")
        if UI.toggles.ItemRun then UI.toggles.ItemRun.Set(false, true) end
        return
    end
    if Items.running then return end
    Items.running = true
    Items.token = Items.token + 1
    local my = Items.token
    task.spawn(function()
        local ok, err = pcall(Items.run, r, my)
        if not ok then
            Hub.err("items", err)
            Items.setStatus("Error: " .. tostring(err))
        end
        if Items.token == my then
            Items.running = false
            if UI.toggles.ItemRun then UI.toggles.ItemRun.Set(false, true) end
        end
        Items.engageFarm(false)
        Mover.release("items")
    end)
end

function Items.stop()
    Items.token = Items.token + 1
    Items.running = false
    Items.engageFarm(false)
    Mover.release("items")
    Items.setStatus("Stopped.")
end

----------------------------------------------------------------------
-- auto prestige
----------------------------------------------------------------------
Prestige.busy, Prestige.nextTry, Prestige.lastTry = false, 0, 0

function Prestige.required()
    if S.PrestigeLevel > 0 then return S.PrestigeLevel end
    local r = DB.prestige[S.PrestigeRank + 1]
    if r then return r end
    return DB.prestige[#DB.prestige] + 400 * (S.PrestigeRank + 1 - #DB.prestige)
end

function Prestige.findNPC()
    Quest.scan()
    local root = Util.root()
    local best, bd
    for _, c in ipairs(Quest.prompts) do
        if c.hasModel and (Util.nameHas(c.name, "prestige") or Util.nameHas(c.label, "prestige") or Util.nameHas(c.name, "overseer")) then
            local d = root and (c.pos - root.Position).Magnitude or 0
            if not bd or d < bd then best, bd = c, d end
        end
    end
    return best
end

function Prestige.run()
    if Prestige.busy then return end
    Prestige.busy = true
    Prestige.lastTry = os.clock()
    Mover.release("farm")
    Farm.target = nil
    local lvl0 = Util.playerLevel()
    Hub.status = "Prestige: starting..."
    local ok, err = pcall(function()
        if Spy.macros["Prestige"] then
            Hub.status = "Prestige: replaying your macro"
            Spy.play("Prestige")
            return
        end
        local c = Prestige.findNPC()
        if not c then
            Hub.status = "Prestige: going to Legacy Island..."
            TP.toIsland("Legacy Island")
            task.wait(3)
            c = Prestige.findNPC()
        end
        if not c then error("Prestige Overseer not found (walk to Legacy Island once, or record a 'Prestige' macro in Spy)") end
        Hub.status = "Prestige: walking to " .. c.name
        if not Items.goNPC(c) then error("could not reach " .. c.name) end
        Hub.status = "Prestige: talking to " .. c.name
        Items.talk(c, { "prestige", "confirm", "yes", "accept", "rank", "ascend" }, nil, { "prestige" })
    end)
    task.wait(2.5)
    local lvl1 = Util.playerLevel()
    if lvl0 and lvl1 and lvl1 < lvl0 - 5 then
        S.PrestigeRank = S.PrestigeRank + 1
        Hub.dirty()
        Prestige.nextTry = 0
        if UI.sliders.PrestigeRank then UI.sliders.PrestigeRank.Set(S.PrestigeRank, true) end
        Hub.note("prest", "Prestige done! Rank " .. S.PrestigeRank .. ". Back to farming.", "ok")
    else
        Prestige.nextTry = os.clock() + (lvl0 and 240 or S.PrestigeEvery * 60)
        if not ok then
            Hub.err("prestige", err)
            Hub.note("prest", "Prestige: " .. tostring(err), "bad")
        else
            Hub.note("prest", "Prestige not accepted yet (requirements?). Will retry later.", "bad")
        end
    end
    Prestige.busy = false
    Hub.status = "Idle"
end

Hub.loop("prestige", function()
    if not S.AutoPrestige or Hub.paused or Items.running or Prestige.busy then return 2 end
    local lvl = Util.playerLevel()
    local now = os.clock()
    local due
    if lvl then
        due = lvl >= Prestige.required() and now >= Prestige.nextTry
    else
        due = now >= Prestige.nextTry and now - Prestige.lastTry > S.PrestigeEvery * 60
    end
    if due then Prestige.run() end
    return 3
end)



----------------------------------------------------------------------
-- extra pages: Items, Auto (prestige / boss), Spy
----------------------------------------------------------------------
function UI.pagesItems()
    local p = UI.addTab("Items")
    p:Section("Auto-Items")
    p:Paragraph("Pick Auto-<item> and turn the switch on. The hub buys it from the NPC, or farms the boss / questline that gives it, and stops when the item is in your backpack. Specs and abilities cannot be detected, so those stop after one full cycle. If it cannot figure a step out, record the real steps once in the Spy tab as 'Get: <item>'.")
    local info
    p:Dropdown("Item", "ItemSel", Items.labels, function() info.Set(Items.describe(S.ItemSel)) end)
    info = p:Paragraph(Items.describe(S.ItemSel))
    p:Toggle("Run Auto-Item", "ItemRun", function(on)
        if on then Items.start() else Items.stop() end
    end)
    p:Slider("Max attempts", "ItemAttempts", 3, 60, 1)
    local st = p:Paragraph("Idle.")
    local idx, last = #UI.tabs, ""
    UI.hook(function()
        if UI.current == idx and Items.statusText ~= last then
            last = Items.statusText
            st.Set(last)
        end
    end)
end

function UI.pagesAuto()
    local p = UI.addTab("Auto")
    p:Section("Auto Prestige")
    p:Paragraph("When your level reaches the requirement, the hub goes to the Prestige Overseer on Legacy Island, confirms, then goes back to farming. Set 'Prestige rank done' to the rank you already have (0 = none). A macro named 'Prestige' recorded in Spy is used instead of walking.")
    p:Toggle("Auto Prestige", "AutoPrestige", function(on)
        if on then
            Prestige.lastTry = os.clock()
            Prestige.nextTry = 0
        end
    end)
    p:Slider("Prestige rank done", "PrestigeRank", 0, 24, 1)
    p:Slider("Prestige at level (0 = auto)", "PrestigeLevel", 0, 11300, 50)
    p:Slider("Retry every (no level info)", "PrestigeEvery", 2, 30, 1, " min")
    p:Button("Prestige now", function() task.spawn(Prestige.run) end, true)
    p:Section("Auto Boss")
    p:Paragraph("Fights the selected boss whenever it is spawned (it has priority over normal mobs). It can travel to the boss island first. Gojo / Sukuna also auto-spawn; manual summons use the summoner NPC (boss tickets) or your 'Summon: <boss>' macro.")
    p:Toggle("Auto Boss", "AutoBoss", function(on)
        if not on then Mobs.want = nil end
    end)
    p:Dropdown("Boss", "BossSel", Boss.labels)
    p:Toggle("Travel to the boss island", "BossIsland")
    p:Button("Summon selected boss", function()
        task.spawn(function()
            local b = DB.boss(S.BossSel)
            if not b then
                Hub.note("sum", "Pick a specific boss first.", "bad")
                return
            end
            Hub.note("sum", Boss.summon(b[1], b[2]) and "Summon sent." or "No summoner NPC / macro found.", "force")
        end)
    end)
end

function UI.pagesSpy()
    local p = UI.addTab("Spy")
    p:Section("Remote Spy")
    p:Paragraph("Shows what the game sends to the server. Turn it on, use the game (buy something, open the island teleport, prestige...), then read or copy the log. Needs hookmetamethod or hookfunction on your executor.")
    p:Toggle("Remote Spy", "SpyOn", function(on) Spy.setOn(on) end)
    p:Toggle("Hide noisy remotes", "SpyQuiet")
    local log = p:Paragraph(Spy.text(25))
    p:Button("Copy log", function()
        if X.clip then
            pcall(X.clip, Spy.text(150))
            Hub.note("copy", "Spy log copied.", "ok")
        else
            Hub.note("copy", "This executor has no clipboard function.", "bad")
        end
    end)
    p:Button("Clear log", function()
        Spy.log = {}
        Spy.muted = {}
        log.Set(Spy.text(25))
    end)
    p:Section("Record & replay")
    p:Paragraph("Type a name, press Record, then do the action once in the game. Special names: 'TP: <island>' (fast travel, shown in Teleport), 'Get: <item>' (used by Auto-Items), 'Prestige', 'Summon: <boss>'.")
    p:Input("Macro name", "e.g. TP: Jungle Island", S.MacroName, function(t)
        S.MacroName = t
        Hub.dirty()
    end)
    p:Button("Record next action (8s)", function() Spy.record(8, S.MacroName) end, true)
    local minfo
    p:Dropdown("Macros", "MacroSel", Spy.macroNames, function(v) minfo.Set(Spy.describe(v)) end)
    minfo = p:Paragraph("No macro selected.")
    p:Button("Play selected macro", function()
        task.spawn(function()
            local n = Spy.play(S.MacroSel)
            Hub.note("play", "Fired " .. n .. " call(s).", "ok")
        end)
    end)
    p:Button("Delete selected macro", function()
        Spy.delete(S.MacroSel)
        S.MacroSel = "(none)"
        if UI.dropdowns.MacroSel then UI.dropdowns.MacroSel.Set("(none)", true) end
        minfo.Set("Deleted.")
    end)
    local idx, lastN, lastT = #UI.tabs, -1, 0
    UI.hook(function(dt, t)
        if UI.current == idx and t - lastT > 0.7 then
            lastT = t
            if Spy.count ~= lastN then
                lastN = Spy.count
                log.Set(Spy.text(25))
            end
        end
    end)
end



----------------------------------------------------------------------
-- pages
----------------------------------------------------------------------
function UI.buildPages()
    ------------------------------------------------------------ FARM
    local p = UI.addTab("Farm")
    p:Section("Auto Farm")
    p:Toggle("Auto Farm", "AutoFarm", function(on)
        if on then
            Farm.target = nil
            Attack.watch = {}
            if not S.AutoAttack and UI.toggles.AutoAttack then UI.toggles.AutoAttack.Set(true) end
            if not next(Mobs.known) then
                Hub.note("tip", "Tip: stand near some mobs once so the hub can learn them.", "force")
            end
        else
            Mover.release("farm")
            Farm.target, Farm.spot = nil, nil
            Hub.status = "Idle"
        end
    end)
    p:Dropdown("Target Mob", "TargetMob", Mobs.names, function()
        Farm.target = nil
        Farm.spot = nil
    end)
    p:Dropdown("Farm Position", "FarmPos", function() return { "Above", "Behind", "Front" } end)
    p:Slider("Farm Distance", "FarmDist", 2, 40, 1, " st")
    p:Slider("Travel Speed", "TravelSpeed", 20, 260, 5, " st/s")
    p:Dropdown("Movement", "MoveMode", function() return { "Auto", "Glide", "Walk" } end, function() Mover.reset() end)
    p:Button("Reset movement tuning", function()
        Mover.reset()
        Hub.note("mv", "Movement tuning reset.", "ok")
    end)

    p:Section("Combat")
    p:Toggle("Auto Attack", "AutoAttack")
    p:Dropdown("Attack Method", "AttackMethod", function()
        return { "Auto", "Tool", "Button" }
    end, function() Attack.watch = {} end)
    p:Slider("Attack Speed", "CPS", 1, 14, 1, " cps")
    local atest = p:Paragraph("Mobile-safe attack: uses Tool:Activate() or a detected M1/Combat button signal. It never sends synthetic mouse/touch presses.")
    p:Button("Test attack methods", function()
        task.spawn(function()
            atest.Set("Testing the available safe attack methods...")
            local r = Attack.test()
            atest.Set("Attack test: " .. r)
            Hub.note("atest", "Attack test finished.", "ok")
        end)
    end, true)
    p:Chips("Auto Skills", {
        { label = "Z", key = "SkillZ" }, { label = "X", key = "SkillX" }, { label = "C", key = "SkillC" },
        { label = "V", key = "SkillV" }, { label = "G", key = "SkillG" },
    })
    p:Slider("Skill Delay", "SkillDelay", 0.5, 6, 0.1, " s")

    p:Section("Mob Control")
    p:Toggle("Bring Mobs", "BringMobs", function(on)
        if not on then Farm.spot = nil end
    end)
    p:Slider("Bring Radius", "BringRadius", 20, 200, 5, " st")
    p:Toggle("Hitbox Expander", "Hitbox", function(on)
        if not on then Hitbox.restoreAll() end
    end)
    p:Slider("Hitbox Size", "HitboxSize", 5, 60, 1)
    p:Toggle("Weapon Reach", "Reach", function(on)
        if not on then Reach.restore() end
    end)
    p:Slider("Reach Size", "ReachSize", 4, 40, 1)

    p:Section("Equip")
    p:Toggle("Auto Equip", "AutoEquip")
    p:Dropdown("Weapon", "Weapon", function()
        local t = Equip.tools()
        table.insert(t, 1, AUTO_TOOL)
        return t
    end)
    p:Dropdown("Equip Mode", "EquipMode", function() return { "Tool", "Hotbar slot" } end)
    p:Slider("Hotbar Slot", "HotbarSlot", 1, 9, 1)

    ---------------------------------------------------------- QUESTS
    local q = UI.addTab("Quests")
    q:Section("Auto Quest")
    q:Paragraph("Finds quest NPCs (prompts called quest / mission / bounty / task), glides to the one closest to the mobs you farm, talks to it and presses accept-style buttons. It watches the quest tracker and repeats when the quest is done. Runs together with Auto Farm.")
    q:Toggle("Auto Quest", "AutoQuest", function(on)
        if on then
            Quest.first = true
            if not S.AutoFarm then Hub.note("quest2", "Auto Quest works while Auto Farm is on.", "force") end
        else
            Mover.release("quest")
        end
    end)
    q:Dropdown("Quest NPC", "QuestNPC", Quest.labels)
    q:Slider("Re-check every", "QuestInterval", 30, 240, 5, " s")
    local qinfo = q:Paragraph(Quest.info)
    q:Button("Scan quest NPCs", function()
        task.spawn(function()
            local l = Quest.scan()
            local qn = #Quest.labels() - 1
            Hub.note("qscan", "Found " .. #l .. " prompts (" .. qn .. " quest-like).", "ok")
        end)
    end)
    q:Button("Run one quest cycle now", function()
        task.spawn(function()
            if not Util.alive() then return end
            Quest.run()
            qinfo.Set(Quest.info)
            Hub.status = "Idle"
        end)
    end, true)
    UI.hook(function()
        if qinfo and UI.current == 2 then qinfo.Set(Quest.info) end
    end)

    -------------------------------------------------------- TELEPORT
    UI.pagesItems()
    UI.pagesAuto()
    local t = UI.addTab("Teleport")
    t:Section("Safe teleport")
    t:Paragraph("Glides you there at a capped speed (it slows itself down if the server pulls you back, then falls back to real walking; see Movement in the Farm tab). Auto Farm / Quest switch off while you travel.")
    t:Button("Rescan map (islands, NPCs)", function()
        task.spawn(function()
            Quest.scan()
            POI.scan()
            Hub.note("poi", "Map scanned: " .. #POI.islands .. " places, " .. #POI.npcs .. " NPCs.", "ok")
        end)
    end)
    t:Dropdown("Island / Spawn", "TPIsland", function()
        local seen, out = {}, {}
        local function add(n)
            if not seen[n] then
                seen[n] = true
                out[#out + 1] = n
            end
        end
        for mname in pairs(Spy.macros) do
            if mname:sub(1, 4) == "TP: " then add(mname:sub(5)) end
        end
        for _, i in ipairs(DB.islands) do add(i[1]) end
        for _, n in ipairs(POI.names(POI.islands)) do add(n) end
        return out
    end)
    t:Button("Teleport to island", function()
        local pt = POI.find(POI.islands, S.TPIsland)
        if pt and not Spy.macros["TP: " .. S.TPIsland] then
            TP.go(pt.pos, S.TPIsland)
        else
            TP.islandGo(S.TPIsland)
        end
    end, true)
    t:Dropdown("NPC", "TPNPC", function() return POI.names(POI.npcs) end)
    t:Button("Teleport to NPC", function()
        local pt = POI.find(POI.npcs, S.TPNPC)
        TP.go(pt and pt.pos, S.TPNPC, true)
    end, true)
    t:Dropdown("Player", "TPPlayer", POI.players)
    t:Button("Teleport to player", function()
        local pl = Players:FindFirstChild(S.TPPlayer)
        local r = pl and pl.Character and pl.Character:FindFirstChild("HumanoidRootPart")
        TP.go(r and r.Position, S.TPPlayer, true)
    end, true)
    t:Button("Go to the selected mob's area", function()
        local k = Mobs.known[S.TargetMob]
        if not k then
            for _, v in pairs(Mobs.known) do
                if v.pos and not v.npc then
                    k = v
                    break
                end
            end
        end
        TP.go(k and k.pos, "mob area")
    end)
    t:Toggle("Instant teleport (risky)", "InstantTP")

    ----------------------------------------------------------- MISC
    UI.pagesSpy()
    local m = UI.addTab("Misc")
    m:Section("Safety")
    m:Toggle("Safe Mode (human-like limits)", "SafeMode")
    m:Toggle("Pause when staff joins", "PauseOnStaff")
    m:Button("Resume automation", function()
        Hub.resume()
        Hub.note("resume", "Automation resumed.", "ok")
    end)
    m:Section("Utility")
    m:Toggle("Anti-AFK", "AntiAFK")
    m:Toggle("Noclip", "Noclip")
    m:Toggle("Walk Speed", "WalkSpeedOn", function(on)
        if not on then
            local h = Util.hum()
            if h then h.WalkSpeed = 16 end
        end
    end)
    m:Slider("Walk Speed value", "WalkSpeed", 16, 80, 1)
    m:Toggle("Auto Loot / Chests", "AutoLoot")
    m:Slider("Loot Radius", "LootRadius", 10, 120, 5, " st")
    m:Section("Performance")
    m:Toggle("FPS Boost (potato mode)", "FPSBoost", function(on)
        if on then Misc.fps(true) end
    end)
    m:Toggle("Disable 3D (AFK saver)", "Disable3D", function(on) Misc.render3d(on) end)
    m:Section("Server")
    m:Toggle("Auto Rejoin on disconnect", "AutoRejoin")
    m:Button("Rejoin server", Misc.rejoin)
    m:Button("Server hop", Misc.hop)

    ------------------------------------------------------- SCANNER
    local sc = UI.addTab("Scanner")
    sc:Section("What the hub sees")
    local rep = sc:Paragraph("Press Scan now: it lists mobs, quest NPCs, tools, the attack button and the last error of every module. If something does not work, copy this report.")
    local lastReport = ""
    sc:Button("Scan now", function()
        task.spawn(function()
            rep.Set("Scanning...")
            Quest.scan()
            POI.scan()
            lastReport = Scan.report()
            rep.Set(lastReport)
        end)
    end, true)
    sc:Button("Copy report", function()
        if lastReport == "" then lastReport = Scan.report() end
        if X.clip then
            pcall(X.clip, lastReport)
            Hub.note("copy", "Report copied.", "ok")
        else
            Hub.note("copy", "This executor has no clipboard function.", "bad")
        end
    end)

    ----------------------------------------------------- SETTINGS
    local st = UI.addTab("Settings")
    st:Section("Interface")
    st:Slider("UI Scale", "UIScale", 0.6, 1.4, 0.05, "x", function() UI.fit() end)
    st:Button("Reset window position", function() UI.resetPos() end)
    st:Toggle("Notifications", "Notify")
    st:Input("Millie image", "direct png/jpg link", S.MillieURL, function(txt)
        txt = txt:gsub("^%s+", ""):gsub("%s+$", "")
        S.MillieURL = txt
        Hub.dirty()
        if txt ~= "" then
            Hub.note("img", "Loading image...", "force")
            Img.load(txt)
        end
    end)
    st:Section("Config")
    st:Button("Save settings now", function()
        Hub.note("cfg", Cfg.save() and "Settings saved." or "Could not save (no file access).", Cfg.save and "ok" or "bad")
    end)
    st:Button("Load saved settings", function()
        if Cfg.load() then
            Hub.note("cfg", "Loaded. Reopen the hub to refresh every slider.", "ok")
        else
            Hub.note("cfg", "No saved settings found.", "bad")
        end
    end)
    st:Section("Danger zone")
    st:Button("PANIC: stop everything and unload", function() Hub.panic() end)
    st:Button("Unload hub", function() Hub.Destroy() end)
    st:Paragraph("Millie Hub v" .. CFG.VERSION .. "  -  Legacy Piece edition. Not ban-proof: use an alt account and keep Safe Mode on.")
end


----------------------------------------------------------------------
-- entry screen: welcome animation + password
----------------------------------------------------------------------
function UI.runEntry(onUnlocked)
    local gui = UI.gui
    local WELCOME = "Bem-vindo a MILLIE HUB HEH!...~"
    local SUB = "Legacy Piece edition  |  mobile"

    local overlay = mk("Frame", {
        Name = "Entry", Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = T.white, BorderSizePixel = 0,
        BackgroundTransparency = 1, Active = true, ZIndex = 30,
    }, gui)
    local bgGrad = mk("UIGradient", {
        Color = ColorSequence.new(Color3.fromRGB(46, 7, 14), Color3.fromRGB(10, 2, 4)), Rotation = 90,
    }, overlay)
    UI.hook(function(dt, t)
        if overlay.Parent then bgGrad.Rotation = 90 + math.sin(t * 0.35) * 25 end
    end)

    local art = mk("ImageLabel", {
        Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, ImageTransparency = 1,
        ScaleType = Enum.ScaleType.Crop, BorderSizePixel = 0, Image = "", ZIndex = 31,
    }, overlay)
    Img.register(art, 0.78, nil)

    -- yellow bokeh lights drifting up (like the snowy lights in Millie's art)
    local dots = {}
    for i = 1, 18 do
        local sz = math.random(4, 11)
        local d = mk("Frame", {
            Size = UDim2.new(0, sz, 0, sz), BackgroundColor3 = T.yellow, BackgroundTransparency = 1,
            BorderSizePixel = 0, ZIndex = 32,
        }, overlay)
        UI.pill(d)
        dots[i] = {
            f = d, x = math.random(), y = math.random(), s = Util.rand(0.02, 0.06), ph = math.random() * 6.28,
            amp = Util.rand(0.004, 0.012), base = Util.rand(0.7, 0.92),
        }
    end

    -- card (group fades as one piece)
    local card = mk("CanvasGroup", {
        AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 0), Size = UDim2.new(0, 360, 0, 250),
        BackgroundTransparency = 1, GroupTransparency = 1, BorderSizePixel = 0, ZIndex = 33,
    }, overlay)
    local cardScale = mk("UIScale", { Scale = 1 }, card)
    local body = mk("Frame", {
        Position = UDim2.new(0, 3, 0, 3), Size = UDim2.new(1, -6, 1, -6), BackgroundColor3 = T.white, BorderSizePixel = 0,
    }, card)
    UI.corner(body, 18)
    mk("UIGradient", { Color = ColorSequence.new(Color3.fromRGB(60, 10, 19), Color3.fromRGB(22, 4, 8)), Rotation = 90 }, body)
    local edge = UI.stroke(body, T.white, 2.5, 0)
    local edgeGrad = mk("UIGradient", {
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, T.yellow),
            ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 120, 30)),
            ColorSequenceKeypoint.new(1, T.yellow),
        }),
    }, edge)
    UI.hook(function(dt, t)
        if card.Parent then edgeGrad.Rotation = (t * 60) % 360 end
    end)

    local av, ring = UI.avatar(body, 92, UDim2.new(0.5, 0, 0, 14), Vector2.new(0.5, 0))
    UI.hook(function(dt, t)
        if ring.Parent then ring.Thickness = 3 + math.sin(t * 3) * 1.2 end
    end)
    local welcome = UI.label(body, "", {
        Position = UDim2.new(0, 10, 0, 112), Size = UDim2.new(1, -20, 0, 30), Font = T.fTitle, TextSize = 21,
        TextColor3 = T.yellow, TextXAlignment = Enum.TextXAlignment.Center,
    })
    local sub = UI.label(body, SUB, {
        Position = UDim2.new(0, 10, 0, 144), Size = UDim2.new(1, -20, 0, 16), TextSize = 11, TextColor3 = T.muted,
        TextXAlignment = Enum.TextXAlignment.Center,
    })

    -- form (kept outside the CanvasGroup so text input is a plain GUI tree)
    local form = mk("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 96), Size = UDim2.new(0, 280, 0, 70),
        BackgroundTransparency = 1, Visible = false, ZIndex = 40,
    }, overlay)
    local formScale = mk("UIScale", { Scale = 1 }, form)
    local box = mk("TextBox", {
        Size = UDim2.new(1, 0, 0, 32), BackgroundColor3 = T.bg, Text = "", PlaceholderText = "enter password",
        PlaceholderColor3 = T.muted, TextColor3 = T.text, Font = T.fBold, TextSize = 14, ClearTextOnFocus = false,
        BorderSizePixel = 0, ZIndex = 41,
    }, form)
    UI.corner(box, 9)
    local boxStroke = UI.stroke(box, T.yellow, 1.5, 0.1)
    local go = mk("TextButton", {
        Position = UDim2.new(0, 0, 0, 38), Size = UDim2.new(1, 0, 0, 30), BackgroundColor3 = T.yellow,
        Text = "UNLOCK", Font = T.fTitle, TextSize = 16, TextColor3 = T.dark, AutoButtonColor = false,
        BorderSizePixel = 0, ZIndex = 41,
    }, form)
    UI.corner(go, 9)
    UI.hoverFx(go, go, T.yellow, Color3.fromRGB(255, 235, 130))

    -- animations
    local shakeDx = 0
    local function place()
        card.Position = UDim2.new(0.5, shakeDx, 0.5, 0)
        form.Position = UDim2.new(0.5, shakeDx, 0.5, 96 - 0)
    end
    local shake = Anim.new(5, function(v)
        shakeDx = math.sin(v * 38) * 14 * v
        place()
    end, 0)
    local ovAnim = Anim.new(5, function(v)
        overlay.BackgroundTransparency = 1 - v
        card.GroupTransparency = 1 - v
        cardScale.Scale = 0.9 + 0.1 * v
        formScale.Scale = 0.9 + 0.1 * v
        if Img.asset then art.ImageTransparency = 1 - (1 - 0.78) * v end
    end, 0)
    local formAnim = Anim.new(10, function(v)
        form.Visible = v > 0.02
        form.Position = UDim2.new(0.5, shakeDx, 0.5, 96 + 14 * (1 - v))
    end, 0)

    UI.hook(function(dt, t)
        if not overlay.Parent then return end
        for _, p in ipairs(dots) do
            p.y = p.y - p.s * dt
            if p.y < -0.05 then
                p.y = 1.05
                p.x = math.random()
            end
            p.f.Position = UDim2.new(p.x + math.sin(t * 0.8 + p.ph) * p.amp, 0, p.y, 0)
            p.f.BackgroundTransparency = 1 - (1 - p.base) * ovAnim.v
        end
    end)

    local unlocked = false
    local function submit()
        if unlocked then return end
        local txt = box.Text:gsub("^%s+", ""):gsub("%s+$", "")
        if txt == CFG.KEY then
            unlocked = true
            Hub.unlocked = true
            sub.Text = "Access granted ~"
            sub.TextColor3 = T.ok
            boxStroke.Color = T.ok
            task.spawn(function()
                task.wait(0.55)
                formAnim.t = 0
                task.wait(0.25)
                ovAnim.t = 0
                task.wait(0.9)
                pcall(function() overlay:Destroy() end)
                onUnlocked()
            end)
        else
            sub.Text = "Wrong password. Try again~"
            sub.TextColor3 = T.bad
            boxStroke.Color = T.bad
            shake.v = 1
            shake.t = 0
            task.delay(2.2, function()
                if not unlocked and sub.Parent then
                    sub.Text = SUB
                    sub.TextColor3 = T.muted
                    boxStroke.Color = T.yellow
                end
            end)
        end
    end
    go.Activated:Connect(submit)
    box.FocusLost:Connect(function(enter) if enter then submit() end end)

    task.spawn(function()
        ovAnim.t = 1
        task.wait(0.55)
        for i = 1, #WELCOME do
            if not Hub.alive or not overlay.Parent then return end
            welcome.Text = WELCOME:sub(1, i) .. ((i < #WELCOME) and "|" or "")
            task.wait(0.048)
        end
        welcome.Text = WELCOME
        task.wait(0.15)
        formAnim.t = 1
    end)
end

----------------------------------------------------------------------
-- startup
----------------------------------------------------------------------
local function stage(name, fn, ...)
    local ok, e = pcall(fn, ...)
    if not ok then
        Hub.err("start:" .. name, e)
        warn("[MillieHub] " .. name .. " failed: " .. tostring(e))
    end
    return ok
end

Cfg.load()
if S.AttackMethod ~= "Auto" and S.AttackMethod ~= "Tool" and S.AttackMethod ~= "Button" then
    S.AttackMethod = "Auto"
end
Spy.load()
local builtOk = stage("ui", UI.build)
if builtOk then
    stage("pages", UI.buildPages)
    stage("bubble", UI.buildBubble)
    UI.select(1)
end
Img.load()
Hub.status = "Idle"

Hub.loop("blink", function()
    for _, f in ipairs(UI.faces) do f.blink.t = 1 end
    task.wait(0.09)
    for _, f in ipairs(UI.faces) do f.blink.t = 0 end
    return Util.rand(2.4, 5.5)
end)

-- learn the world in the background (mobs, prompts, islands) and name the game in the header
task.spawn(function()
    task.wait(1)
    stage("scan", function()
        Mobs.scanAll()
        Quest.scan()
        POI.scan()
    end)
end)
task.spawn(function()
    local ok, name = pcall(function() return MarketplaceService:GetProductInfo(game.PlaceId).Name end)
    if ok and type(name) == "string" and UI.subtitle then
        if name:lower():find("legacy", 1, true) then
            UI.subtitle.Text = "Legacy Piece  |  v" .. CFG.VERSION
        else
            UI.subtitle.Text = "v" .. CFG.VERSION .. "  |  generic mode: " .. name
        end
    end
end)

ENV.__MILLIE_HUB = Hub

if builtOk then
    UI.runEntry(function()
        UI.showBubble(true)
        UI.setOpen(true)
        Hub.note("welcome", "Welcome, babe~  Tap the jv bubble to hide / show the hub.", "ok")
    end)
else
    warn("[MillieHub] the interface could not be built; check Hub.errors via the executor console.")
end
