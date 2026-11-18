--[[
  BintangHub — BloxStrike FULL
  Combat · ESP · Weapon · Visual · Misc
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local CoreGui = game:GetService("CoreGui")

local LP = Players.LocalPlayer
local Camera = workspace.CurrentCamera

local S = {
    -- Combat
    Aimbot = false,
    SilentAim = false,
    Triggerbot = false,
    AimbotFOV = 160,
    SilentFOV = 200,
    AimbotSmooth = 0.22,
    TriggerDelay = 0.05,
    AimPart = "Head",
    TeamCheck = true,
    VisibleCheck = false,
    ShowFOV = true,
    FOVMode = "Aimbot", -- Aimbot / Silent
    -- Weapon
    NoRecoil = false,
    NoSpread = false,
    -- ESP
    ESP = true,
    ESPBox = true,
    ESPName = true,
    ESPDistance = true,
    ESPHealth = true,
    ESPTracer = false,
    ESPSkeleton = false,
    ESPWeapon = false,
    ESPMaxDist = 1000,
    BombESP = true,
    ESPColorEnemy = Color3.fromRGB(255, 70, 70),
    ESPColorTeam = Color3.fromRGB(80, 180, 255),
    ESPColorBomb = Color3.fromRGB(255, 200, 40),
    -- Visual
    Fullbright = false,
    NoFog = false,
    -- Misc
    Bhop = false,
    SpeedBoost = false,
    SpeedValue = 22,
}

local Drawings = {}
local BombDraw = nil
local FOVCircle = nil
local lastTrigger = 0
local savedCam = nil
local lightState = {}

local function corner(p, r)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, r or 8)
    c.Parent = p
end
local function stroke(p, col, th)
    local s = Instance.new("UIStroke")
    s.Color = col or Color3.fromRGB(40, 40, 48)
    s.Thickness = th or 1
    s.Parent = p
end
local function tween(o, t, props)
    TweenService:Create(o, TweenInfo.new(t or 0.12, Enum.EasingStyle.Quad), props):Play()
end

local function isAlive(plr)
    local char = plr.Character
    if not char then return false end
    local hum = char:FindFirstChildOfClass("Humanoid")
    local root = char:FindFirstChild("HumanoidRootPart")
    return hum and hum.Health > 0 and root ~= nil
end

local function sameTeam(plr)
    if not S.TeamCheck then return false end
    if LP.Team and plr.Team then return LP.Team == plr.Team end
    local a = LP:GetAttribute("Team") or LP:GetAttribute("team")
    local b = plr:GetAttribute("Team") or plr:GetAttribute("team")
    if a ~= nil and b ~= nil then return a == b end
    return false
end

local function getPart(char)
    local n = S.AimPart
    return char:FindFirstChild(n) or char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart")
end

local function isVisible(part)
    if not S.VisibleCheck then return true end
    local origin = Camera.CFrame.Position
    local dir = part.Position - origin
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {LP.Character, Camera}
    local res = workspace:Raycast(origin, dir, params)
    if not res then return true end
    return res.Instance and part.Parent and res.Instance:IsDescendantOf(part.Parent)
end

local function worldToScreen(pos)
    local v, on = Camera:WorldToViewportPoint(pos)
    return Vector2.new(v.X, v.Y), on, v.Z
end

-- FOV
local function ensureFOV()
    if FOVCircle and FOVCircle.Parent then return end
    local g = Instance.new("ScreenGui")
    g.Name = "BintangBS_FOV"
    g.IgnoreGuiInset = true
    g.ResetOnSpawn = false
    pcall(function() g.Parent = gethui and gethui() or CoreGui end)
    if not g.Parent then g.Parent = LP:WaitForChild("PlayerGui") end
    local f = Instance.new("Frame")
    f.AnchorPoint = Vector2.new(0.5, 0.5)
    f.BackgroundTransparency = 1
    f.Parent = g
    local s = Instance.new("UIStroke")
    s.Thickness = 1.5
    s.Color = Color3.fromRGB(155, 89, 255)
    s.Transparency = 0.3
    s.Parent = f
    Instance.new("UICorner", f).CornerRadius = UDim.new(1, 0)
    FOVCircle = f
end

local function updateFOV()
    ensureFOV()
    local show = S.ShowFOV and (S.Aimbot or S.SilentAim or S.Triggerbot)
    FOVCircle.Visible = show
    if not show then return end
    local r = (S.FOVMode == "Silent" and S.SilentFOV or S.AimbotFOV) * 2
    FOVCircle.Size = UDim2.fromOffset(r, r)
    local vp = Camera.ViewportSize
    FOVCircle.Position = UDim2.fromOffset(vp.X / 2, vp.Y / 2)
end

-- target pick
local function getClosest(fov)
    local best, bestD = nil, fov or S.AimbotFOV
    local center = Camera.ViewportSize / 2
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LP and isAlive(plr) and not sameTeam(plr) then
            local part = getPart(plr.Character)
            if part and isVisible(part) then
                local sp, on = worldToScreen(part.Position)
                if on then
                    local d = (Vector2.new(sp.X, sp.Y) - center).Magnitude
                    if d < bestD then
                        bestD = d
                        best = part
                    end
                end
            end
        end
    end
    return best
end

-- Aimbot camera
local function updateAimbot()
    if not S.Aimbot then return end
    local hold = UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
        or UserInputService:IsKeyDown(Enum.KeyCode.LeftAlt)
    if not hold then return end
    local t = getClosest(S.AimbotFOV)
    if not t then return end
    local goal = CFrame.new(Camera.CFrame.Position, t.Position)
    Camera.CFrame = Camera.CFrame:Lerp(goal, math.clamp(S.AimbotSmooth, 0.05, 1))
end

-- Silent: snap camera briefly / mouse style via Camera
local function updateSilent()
    if not S.SilentAim then return end
    local shooting = UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
    if not shooting then return end
    local t = getClosest(S.SilentFOV)
    if not t then return end
    -- soft silent: aim camera at target while firing
    Camera.CFrame = CFrame.new(Camera.CFrame.Position, t.Position)
end

-- Triggerbot
local function updateTrigger()
    if not S.Triggerbot then return end
    local t = getClosest(S.AimbotFOV * 0.35)
    if not t then return end
    local sp, on = worldToScreen(t.Position)
    if not on then return end
    local center = Camera.ViewportSize / 2
    if (Vector2.new(sp.X, sp.Y) - center).Magnitude > 18 then return end
    local now = tick()
    if now - lastTrigger < S.TriggerDelay then return end
    lastTrigger = now
    pcall(function()
        if mouse1click then mouse1click()
        elseif mouse1press then
            mouse1press()
            task.delay(0.03, function() pcall(mouse1release) end)
        end
    end)
end

-- No recoil: damp camera kick
local lastCF = nil
local function updateNoRecoil()
    if not S.NoRecoil then
        lastCF = nil
        return
    end
    if not UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
        lastCF = Camera.CFrame
        return
    end
    if lastCF then
        local cur = Camera.CFrame
        -- pull pitch back toward last
        local lp = lastCF.LookVector
        local cp = cur.LookVector
        local blended = lp:Lerp(cp, 0.15)
        Camera.CFrame = CFrame.new(cur.Position, cur.Position + blended)
    end
    lastCF = Camera.CFrame
end

-- ESP players
local function destroyESP(plr)
    local d = Drawings[plr]
    if not d then return end
    for _, v in pairs(d) do
        if typeof(v) == "Instance" then v:Destroy() end
    end
    Drawings[plr] = nil
end

local function ensureESP(plr)
    if Drawings[plr] then return Drawings[plr] end
    local gui = Instance.new("ScreenGui")
    gui.Name = "BintangBS_ESP_" .. plr.Name
    gui.IgnoreGuiInset = true
    gui.ResetOnSpawn = false
    pcall(function() gui.Parent = gethui and gethui() or CoreGui end)
    if not gui.Parent then gui.Parent = LP:WaitForChild("PlayerGui") end
    local box = Instance.new("Frame")
    box.BackgroundTransparency = 1
    box.Visible = false
    box.Parent = gui
    local st = Instance.new("UIStroke")
    st.Thickness = 1.5
    st.Parent = box
    local nameL = Instance.new("TextLabel")
    nameL.BackgroundTransparency = 1
    nameL.Size = UDim2.new(0, 140, 0, 14)
    nameL.Font = Enum.Font.GothamBold
    nameL.TextSize = 12
    nameL.TextStrokeTransparency = 0.5
    nameL.Visible = false
    nameL.Parent = gui
    local distL = Instance.new("TextLabel")
    distL.BackgroundTransparency = 1
    distL.Size = UDim2.new(0, 80, 0, 12)
    distL.Font = Enum.Font.Gotham
    distL.TextSize = 11
    distL.TextColor3 = Color3.fromRGB(200, 200, 210)
    distL.TextStrokeTransparency = 0.5
    distL.Visible = false
    distL.Parent = gui
    local hpBar = Instance.new("Frame")
    hpBar.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
    hpBar.BorderSizePixel = 0
    hpBar.Visible = false
    hpBar.Parent = gui
    local hpFill = Instance.new("Frame")
    hpFill.BorderSizePixel = 0
    hpFill.Size = UDim2.new(1, 0, 1, 0)
    hpFill.Parent = hpBar
    local tracer = Instance.new("Frame")
    tracer.AnchorPoint = Vector2.new(0.5, 0)
    tracer.BorderSizePixel = 0
    tracer.Visible = false
    tracer.Parent = gui
    Drawings[plr] = {gui = gui, box = box, stroke = st, name = nameL, dist = distL, hpBar = hpBar, hpFill = hpFill, tracer = tracer}
    return Drawings[plr]
end

local function updateESP()
    if not S.ESP then
        for plr in pairs(Drawings) do destroyESP(plr) end
        return
    end
    local myRoot = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr == LP or not isAlive(plr) then
            destroyESP(plr)
        else
            local char = plr.Character
            local root = char:FindFirstChild("HumanoidRootPart")
            local head = char:FindFirstChild("Head")
            local hum = char:FindFirstChildOfClass("Humanoid")
            if not root or not head then
                destroyESP(plr)
            else
                local dist = myRoot and (root.Position - myRoot.Position).Magnitude or 0
                if dist > S.ESPMaxDist then
                    destroyESP(plr)
                else
                    local col = sameTeam(plr) and S.ESPColorTeam or S.ESPColorEnemy
                    local top, on1 = worldToScreen(head.Position + Vector3.new(0, 0.5, 0))
                    local bot, on2 = worldToScreen(root.Position - Vector3.new(0, 2.4, 0))
                    if not (on1 or on2) then
                        local d = Drawings[plr]
                        if d then
                            d.box.Visible = false
                            d.name.Visible = false
                            d.dist.Visible = false
                            d.hpBar.Visible = false
                            d.tracer.Visible = false
                        end
                    else
                        local d = ensureESP(plr)
                        d.stroke.Color = col
                        local h = math.max(math.abs(bot.Y - top.Y), 8)
                        local w = h * 0.55
                        local cx = (top.X + bot.X) / 2
                        local y1 = math.min(top.Y, bot.Y)
                        if S.ESPBox then
                            d.box.Visible = true
                            d.box.Size = UDim2.fromOffset(w, h)
                            d.box.Position = UDim2.fromOffset(cx - w / 2, y1)
                        else
                            d.box.Visible = false
                        end
                        if S.ESPName then
                            d.name.Visible = true
                            local wpn = ""
                            if S.ESPWeapon then
                                local tool = char:FindFirstChildOfClass("Tool")
                                if tool then wpn = " | " .. tool.Name end
                            end
                            d.name.Text = (plr.DisplayName or plr.Name) .. wpn
                            d.name.TextColor3 = col
                            d.name.Position = UDim2.fromOffset(cx - 70, y1 - 16)
                        else
                            d.name.Visible = false
                        end
                        if S.ESPDistance then
                            d.dist.Visible = true
                            d.dist.Text = string.format("[%dm]", math.floor(dist))
                            d.dist.Position = UDim2.fromOffset(cx - 40, y1 + h + 2)
                        else
                            d.dist.Visible = false
                        end
                        if S.ESPHealth and hum then
                            local pct = math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1)
                            d.hpBar.Visible = true
                            d.hpBar.Size = UDim2.fromOffset(3, h)
                            d.hpBar.Position = UDim2.fromOffset(cx - w / 2 - 5, y1)
                            d.hpFill.Size = UDim2.new(1, 0, pct, 0)
                            d.hpFill.Position = UDim2.new(0, 0, 1 - pct, 0)
                            d.hpFill.BackgroundColor3 = Color3.fromRGB(255 * (1 - pct), 220 * pct, 50)
                        else
                            d.hpBar.Visible = false
                        end
                        if S.ESPTracer then
                            local vp = Camera.ViewportSize
                            local from = Vector2.new(vp.X / 2, vp.Y)
                            local to = Vector2.new(cx, y1 + h)
                            local mid = (from + to) / 2
                            local len = (to - from).Magnitude
                            local ang = math.deg(math.atan2(to.Y - from.Y, to.X - from.X))
                            d.tracer.Visible = true
                            d.tracer.BackgroundColor3 = col
                            d.tracer.Size = UDim2.fromOffset(len, 1)
                            d.tracer.Position = UDim2.fromOffset(mid.X, mid.Y)
                            d.tracer.Rotation = ang
                        else
                            d.tracer.Visible = false
                        end
                    end
                end
            end
        end
    end
end

-- Bomb ESP (heuristic)
local function updateBombESP()
    if not S.BombESP then
        if BombDraw then BombDraw:Destroy() BombDraw = nil end
        return
    end
    local bomb = nil
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("BasePart") or obj:IsA("Model") then
            local n = string.lower(obj.Name)
            if n:find("c4") or n:find("bomb") or n:find("planted") or n == "weapon_c4" then
                bomb = obj:IsA("Model") and (obj:FindFirstChildWhichIsA("BasePart") or obj.PrimaryPart) or obj
                if bomb then break end
            end
        end
    end
    if not bomb then
        if BombDraw then BombDraw.Enabled = false end
        return
    end
    if not BombDraw then
        local g = Instance.new("ScreenGui")
        g.Name = "BintangBS_Bomb"
        g.IgnoreGuiInset = true
        g.ResetOnSpawn = false
        pcall(function() g.Parent = gethui and gethui() or CoreGui end)
        if not g.Parent then g.Parent = LP:WaitForChild("PlayerGui") end
        local l = Instance.new("TextLabel")
        l.BackgroundColor3 = Color3.fromRGB(30, 20, 10)
        l.BackgroundTransparency = 0.3
        l.Size = UDim2.new(0, 100, 0, 22)
        l.Font = Enum.Font.GothamBold
        l.TextSize = 12
        l.TextColor3 = S.ESPColorBomb
        l.Text = "BOMB"
        l.Parent = g
        Instance.new("UICorner", l).CornerRadius = UDim.new(0, 4)
        BombDraw = g
        BombDraw.Label = l
    end
    local pos = bomb.Position
    local sp, on = worldToScreen(pos)
    local lab = BombDraw.Label
    if on then
        BombDraw.Enabled = true
        lab.Position = UDim2.fromOffset(sp.X - 50, sp.Y - 30)
        lab.Visible = true
    else
        lab.Visible = false
    end
end

-- Visual
local function applyVisual()
    if S.Fullbright then
        if not lightState.saved then
            lightState.Ambient = Lighting.Ambient
            lightState.Brightness = Lighting.Brightness
            lightState.saved = true
        end
        Lighting.Ambient = Color3.new(1, 1, 1)
        Lighting.Brightness = 2
    elseif lightState.saved then
        Lighting.Ambient = lightState.Ambient
        Lighting.Brightness = lightState.Brightness
        lightState.saved = false
    end
    if S.NoFog then
        Lighting.FogEnd = 1e6
        pcall(function()
            local atm = Lighting:FindFirstChildOfClass("Atmosphere")
            if atm then atm.Density = 0 end
        end)
    end
end

-- Misc movement
local function updateMisc()
    local char = LP.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    local root = char:FindFirstChild("HumanoidRootPart")
    if not hum or not root then return end
    if S.SpeedBoost then
        hum.WalkSpeed = S.SpeedValue
    end
    if S.Bhop and hum.FloorMaterial ~= Enum.Material.Air then
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
            hum.Jump = true
        end
    end
end

RunService.RenderStepped:Connect(function()
    pcall(updateFOV)
    pcall(updateESP)
    pcall(updateBombESP)
    pcall(updateAimbot)
    pcall(updateSilent)
    pcall(updateTrigger)
    pcall(updateNoRecoil)
    pcall(applyVisual)
    pcall(updateMisc)
end)

Players.PlayerRemoving:Connect(destroyESP)

-- ===== UI =====
local C = {
    bg = Color3.fromRGB(16, 16, 18),
    panel = Color3.fromRGB(22, 22, 26),
    row = Color3.fromRGB(28, 28, 32),
    border = Color3.fromRGB(42, 42, 50),
    accent = Color3.fromRGB(155, 89, 255),
    text = Color3.fromRGB(245, 245, 248),
    muted = Color3.fromRGB(130, 130, 140),
    on = Color3.fromRGB(155, 89, 255),
    off = Color3.fromRGB(50, 50, 58),
    danger = Color3.fromRGB(210, 55, 65),
}

pcall(function()
    if CoreGui:FindFirstChild("BintangBloxStrike") then CoreGui.BintangBloxStrike:Destroy() end
    if CoreGui:FindFirstChild("BintangBloxStrikeIcon") then CoreGui.BintangBloxStrikeIcon:Destroy() end
end)

local gui = Instance.new("ScreenGui")
gui.Name = "BintangBloxStrike"
gui.ResetOnSpawn = false
gui.Parent = CoreGui

local win = Instance.new("Frame")
win.Size = UDim2.new(0, 320, 0, 480)
win.Position = UDim2.new(0.5, -160, 0.5, -240)
win.BackgroundColor3 = C.bg
win.BorderSizePixel = 0
win.Parent = gui
corner(win, 12)
stroke(win, C.border, 1)

local top = Instance.new("Frame")
top.Size = UDim2.new(1, 0, 0, 40)
top.BackgroundColor3 = C.panel
top.BorderSizePixel = 0
top.Parent = win

local title = Instance.new("TextLabel")
title.BackgroundTransparency = 1
title.Position = UDim2.new(0, 12, 0, 0)
title.Size = UDim2.new(1, -80, 1, 0)
title.Font = Enum.Font.GothamBold
title.Text = "Bintang · BloxStrike"
title.TextSize = 14
title.TextColor3 = C.text
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = top

local function topBtn(txt, ox, danger)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0, 28, 0, 28)
    b.Position = UDim2.new(1, ox, 0.5, -14)
    b.BackgroundColor3 = C.row
    b.Text = txt
    b.Font = Enum.Font.GothamBold
    b.TextSize = 14
    b.TextColor3 = C.muted
    b.AutoButtonColor = false
    b.Parent = top
    corner(b, 6)
    return b
end
local minBtn = topBtn("−", -64, false)
local closeBtn = topBtn("×", -32, true)

local scroll = Instance.new("ScrollingFrame")
scroll.Position = UDim2.new(0, 0, 0, 40)
scroll.Size = UDim2.new(1, 0, 1, -40)
scroll.BackgroundTransparency = 1
scroll.BorderSizePixel = 0
scroll.ScrollBarThickness = 3
scroll.ScrollBarImageColor3 = C.accent
scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
scroll.Parent = win
local pad = Instance.new("UIPadding")
pad.PaddingTop = UDim.new(0, 8)
pad.PaddingLeft = UDim.new(0, 12)
pad.PaddingRight = UDim.new(0, 12)
pad.PaddingBottom = UDim.new(0, 12)
pad.Parent = scroll
local list = Instance.new("UIListLayout")
list.Padding = UDim.new(0, 5)
list.Parent = scroll

local function section(t)
    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(1, 0, 0, 18)
    l.BackgroundTransparency = 1
    l.Font = Enum.Font.GothamBold
    l.TextSize = 11
    l.TextColor3 = C.accent
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.Text = t
    l.Parent = scroll
end

local function addToggle(key, label)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 32)
    row.BackgroundColor3 = C.row
    row.BorderSizePixel = 0
    row.Parent = scroll
    corner(row, 7)
    local lbl = Instance.new("TextLabel")
    lbl.BackgroundTransparency = 1
    lbl.Position = UDim2.new(0, 10, 0, 0)
    lbl.Size = UDim2.new(1, -54, 1, 0)
    lbl.Font = Enum.Font.Gotham
    lbl.TextSize = 12
    lbl.TextColor3 = C.text
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Text = label
    lbl.Parent = row
    local track = Instance.new("TextButton")
    track.Size = UDim2.new(0, 38, 0, 20)
    track.Position = UDim2.new(1, -46, 0.5, -10)
    track.BackgroundColor3 = S[key] and C.on or C.off
    track.Text = ""
    track.AutoButtonColor = false
    track.Parent = row
    corner(track, 10)
    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0, 16, 0, 16)
    knob.Position = S[key] and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8)
    knob.BackgroundColor3 = Color3.new(1, 1, 1)
    knob.BorderSizePixel = 0
    knob.Parent = track
    corner(knob, 8)
    track.MouseButton1Click:Connect(function()
        S[key] = not S[key]
        tween(track, 0.12, {BackgroundColor3 = S[key] and C.on or C.off})
        tween(knob, 0.12, {Position = S[key] and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8)})
    end)
end

local function addDropdown(key, label, options)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 32)
    row.BackgroundColor3 = C.row
    row.BorderSizePixel = 0
    row.Parent = scroll
    corner(row, 7)
    local lbl = Instance.new("TextLabel")
    lbl.BackgroundTransparency = 1
    lbl.Position = UDim2.new(0, 10, 0, 0)
    lbl.Size = UDim2.new(0.4, 0, 1, 0)
    lbl.Font = Enum.Font.Gotham
    lbl.TextSize = 12
    lbl.TextColor3 = C.text
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Text = label
    lbl.Parent = row
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 120, 0, 22)
    btn.Position = UDim2.new(1, -128, 0.5, -11)
    btn.BackgroundColor3 = C.panel
    btn.Text = tostring(S[key]) .. " ▼"
    btn.Font = Enum.Font.Gotham
    btn.TextSize = 11
    btn.TextColor3 = C.text
    btn.AutoButtonColor = false
    btn.Parent = row
    corner(btn, 6)
    local open, menu = false, nil
    btn.MouseButton1Click:Connect(function()
        if open and menu then menu:Destroy() open = false return end
        open = true
        menu = Instance.new("Frame")
        menu.Size = UDim2.new(0, 120, 0, #options * 24)
        menu.Position = UDim2.new(1, -128, 1, 2)
        menu.BackgroundColor3 = C.panel
        menu.ZIndex = 40
        menu.Parent = row
        corner(menu, 6)
        stroke(menu, C.border, 1)
        Instance.new("UIListLayout", menu)
        for _, opt in ipairs(options) do
            local o = Instance.new("TextButton")
            o.Size = UDim2.new(1, 0, 0, 24)
            o.BackgroundTransparency = 1
            o.Text = opt
            o.Font = Enum.Font.Gotham
            o.TextSize = 11
            o.TextColor3 = (S[key] == opt) and C.accent or C.text
            o.ZIndex = 41
            o.Parent = menu
            o.MouseButton1Click:Connect(function()
                S[key] = opt
                btn.Text = opt .. " ▼"
                if menu then menu:Destroy() end
                open = false
            end)
        end
    end)
end

section("COMBAT")
addToggle("Aimbot", "Aimbot (hold RMB / Alt)")
addToggle("SilentAim", "Silent Aim (on fire)")
addToggle("Triggerbot", "Triggerbot")
addToggle("ShowFOV", "Show FOV")
addToggle("TeamCheck", "Team Check")
addToggle("VisibleCheck", "Visible Check")
addDropdown("AimPart", "Aim Part", {"Head", "HumanoidRootPart", "UpperTorso"})
addDropdown("FOVMode", "FOV Mode", {"Aimbot", "Silent"})

section("WEAPON")
addToggle("NoRecoil", "No Recoil (soft)")
addToggle("NoSpread", "No Spread (flag)")

section("ESP")
addToggle("ESP", "Enable ESP")
addToggle("ESPBox", "Box")
addToggle("ESPName", "Name")
addToggle("ESPDistance", "Distance")
addToggle("ESPHealth", "Health")
addToggle("ESPTracer", "Tracer")
addToggle("ESPWeapon", "Show Weapon")
addToggle("BombESP", "Bomb ESP")

section("VISUAL")
addToggle("Fullbright", "Fullbright")
addToggle("NoFog", "No Fog")

section("MISC")
addToggle("Bhop", "Bunny Hop")
addToggle("SpeedBoost", "Speed Boost")

local note = Instance.new("TextLabel")
note.Size = UDim2.new(1, 0, 0, 36)
note.BackgroundTransparency = 1
note.Font = Enum.Font.Gotham
note.TextSize = 10
note.TextColor3 = C.muted
note.TextXAlignment = Enum.TextXAlignment.Left
note.TextWrapped = true
note.Text = "Silent = aim kamera saat LMB.\nNo Spread butuh hook senjata (flag only)."
note.Parent = scroll

do
    local dragging, dragStart, startPos
    top.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = win.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local d = input.Position - dragStart
            win.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end)
end

local iconGui = Instance.new("ScreenGui")
iconGui.Name = "BintangBloxStrikeIcon"
iconGui.ResetOnSpawn = false
iconGui.Enabled = false
iconGui.Parent = CoreGui
local iconBtn = Instance.new("TextButton")
iconBtn.Size = UDim2.new(0, 48, 0, 48)
iconBtn.Position = UDim2.new(0, 14, 0.45, 0)
iconBtn.BackgroundColor3 = C.panel
iconBtn.Text = "BS"
iconBtn.Font = Enum.Font.GothamBold
iconBtn.TextSize = 13
iconBtn.TextColor3 = C.accent
iconBtn.AutoButtonColor = false
iconBtn.Parent = iconGui
corner(iconBtn, 24)
stroke(iconBtn, C.accent, 1.5)

minBtn.MouseButton1Click:Connect(function()
    win.Visible = false
    iconGui.Enabled = true
end)
iconBtn.MouseButton1Click:Connect(function()
    win.Visible = true
    iconGui.Enabled = false
end)
closeBtn.MouseButton1Click:Connect(function()
    for plr in pairs(Drawings) do destroyESP(plr) end
    if FOVCircle and FOVCircle.Parent then FOVCircle.Parent:Destroy() end
    if BombDraw then BombDraw:Destroy() end
    gui:Destroy()
    iconGui:Destroy()
end)

print("[BintangHub] BloxStrike FULL loaded")
