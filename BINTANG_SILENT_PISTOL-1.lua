--[[
  BintangHub — Silent Pistol Only (Twist of Fate)
  UI minimal + logic silent aim
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")

local LP = Players.LocalPlayer
local Camera = workspace.CurrentCamera

local S = {
    Enabled = false,
    Prediction = true,
    Laser = false,
    InfAmmo = false,
    BulletSpeed = 200,
    TargetPart = "Torso", -- Head / Torso / HumanoidRootPart
    TargetMode = "Killer", -- Killer / Survivor / All
    LaserColor = Color3.fromRGB(255, 50, 50),
}

local Cache = {
    TargetPos = nil,
    LookVector = nil,
    IsAiming = false,
    CurrentMuzzle = nil,
    LaserBeam = nil,
}


-- ===== INF AMMO / ALWAYS LOADED (ToF) =====
-- VD: loaded shot = reliable; unloaded = jam risk. Force loaded + ammo values.

local BOOL_TRUE_KEYS = {
    "HasBullet", "hasBullet", "Loaded", "loaded", "IsLoaded", "isLoaded",
    "HasAmmo", "hasAmmo", "Bullet", "bullet", "CanShoot", "canShoot",
}
local NUM_KEYS = {
    "Ammo", "ammo", "Bullets", "bullets", "Clip", "clip",
    "Charges", "charges", "Uses", "uses", "BulletCount", "bulletCount",
}

local function forceAmmoOn(inst)
    if not inst then return end
    pcall(function()
        for _, key in ipairs(BOOL_TRUE_KEYS) do
            local a = inst:GetAttribute(key)
            if a ~= nil then
                inst:SetAttribute(key, true)
            end
        end
        for _, key in ipairs(NUM_KEYS) do
            local a = inst:GetAttribute(key)
            if typeof(a) == "number" then
                inst:SetAttribute(key, 99)
            end
        end
        for _, ch in ipairs(inst:GetDescendants()) do
            if ch:IsA("BoolValue") then
                local n = string.lower(ch.Name)
                if n:find("load") or n:find("bullet") or n:find("ammo") or n:find("shoot") then
                    ch.Value = true
                end
            elseif ch:IsA("IntValue") or ch:IsA("NumberValue") then
                local n = string.lower(ch.Name)
                if n:find("ammo") or n:find("bullet") or n:find("clip") or n:find("charge") or n:find("use") then
                    ch.Value = 99
                end
            end
        end
    end)
end

local function findToF()
    local char = LP.Character
    if char then
        for _, t in ipairs(char:GetChildren()) do
            if t:IsA("Tool") then
                local n = t.Name
                if n:find("Twist") or n:find("Fate") or n:lower():find("tof") or n:lower():find("pistol") then
                    return t
                end
            end
        end
    end
    local bag = LP:FindFirstChild("Backpack")
    if bag then
        for _, t in ipairs(bag:GetChildren()) do
            if t:IsA("Tool") then
                local n = t.Name
                if n:find("Twist") or n:find("Fate") or n:lower():find("tof") or n:lower():find("pistol") then
                    return t
                end
            end
        end
    end
    return nil
end

-- GetAttribute spoof: selalu bilang loaded / punya bullet
pcall(function()
    if type(hookmetamethod) ~= "function" then return end
    local oldIndex
    oldIndex = hookmetamethod(game, "__namecall", function(self, ...)
        -- handled in other hook; keep separate below
        return oldIndex(self, ...)
    end)
end)

-- Primary: spoof GetAttribute on player/character/tool
pcall(function()
    local mt_ok, mt = pcall(getrawmetatable, game)
    -- use hookfunction on Instance.GetAttribute if available
    if type(hookfunction) == "function" then
        local oldGA
        oldGA = hookfunction(game.GetAttribute, function(self, key)
            if S.InfAmmo and type(key) == "string" then
                local k = key
                for _, b in ipairs(BOOL_TRUE_KEYS) do
                    if k == b then return true end
                end
                for _, n in ipairs(NUM_KEYS) do
                    if k == n then return 99 end
                end
            end
            return oldGA(self, key)
        end)
    end
end)

-- Also attribute listen + force loop
task.spawn(function()
    while true do
        if S.InfAmmo then
            local tool = findToF()
            forceAmmoOn(tool)
            forceAmmoOn(LP)
            forceAmmoOn(LP.Character)
            -- common player attrs
            pcall(function()
                for _, key in ipairs(BOOL_TRUE_KEYS) do
                    LP:SetAttribute(key, true)
                    if LP.Character then LP.Character:SetAttribute(key, true) end
                end
                for _, key in ipairs(NUM_KEYS) do
                    LP:SetAttribute(key, 99)
                    if LP.Character then LP.Character:SetAttribute(key, 99) end
                end
            end)
        end
        task.wait(0.08)
    end
end)

local function getPartPos(char)
    if not char then return nil end
    local name = S.TargetPart
    local p = char:FindFirstChild(name) or char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso")
    return p and p.Position or nil
end

local function isAlive(plr)
    local char = plr.Character
    if not char then return false end
    local hum = char:FindFirstChildOfClass("Humanoid")
    return hum and hum.Health > 0
end

local function teamOf(plr)
    local t = plr.Team and string.lower(plr.Team.Name) or ""
    if t == "" then
        local role = plr:GetAttribute("Role") or plr:GetAttribute("role")
        if role then t = string.lower(tostring(role)) end
    end
    return t
end

local function pickTarget()
    local myChar = LP.Character
    local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
    if not myRoot then return nil, nil end

    local best, bestDist, bestPos = nil, math.huge, nil
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LP and isAlive(plr) then
            local tn = teamOf(plr)
            local ok = false
            if S.TargetMode == "All" then
                ok = true
            elseif S.TargetMode == "Killer" then
                ok = tn:find("killer") ~= nil
            elseif S.TargetMode == "Survivor" then
                ok = tn:find("survivor") ~= nil or tn == ""
            end
            if ok then
                local pos = getPartPos(plr.Character)
                if pos then
                    local d = (pos - myRoot.Position).Magnitude
                    if d < bestDist then
                        bestDist = d
                        best = plr
                        bestPos = pos
                    end
                end
            end
        end
    end
    return best, bestPos
end

local function toolEquippedToF()
    local char = LP.Character
    if not char then return false, nil end
    for _, t in ipairs(char:GetChildren()) do
        if t:IsA("Tool") and (t.Name:find("Twist") or t.Name:find("Fate") or t.Name:lower():find("pistol") or t.Name:lower():find("tof")) then
            return true, t
        end
    end
    -- backpack equipped check via Character tool
    local tool = char:FindFirstChildOfClass("Tool")
    if tool then
        local n = tool.Name:lower()
        if n:find("twist") or n:find("fate") or n:find("pistol") or n:find("tof") or n:find("gun") then
            return true, tool
        end
    end
    return false, nil
end

local function updateAim()
    if not S.Enabled then
        Cache.TargetPos = nil
        Cache.LookVector = nil
        if Cache.LaserBeam then Cache.LaserBeam.Transparency = 1 end
        return
    end

    local equipped, tool = toolEquippedToF()
    local myRoot = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
    if not equipped or not myRoot then
        Cache.TargetPos = nil
        Cache.LookVector = nil
        if Cache.LaserBeam then Cache.LaserBeam.Transparency = 1 end
        return
    end

    Cache.IsAiming = true
    local target, pos = pickTarget()
    if not target or not pos then
        Cache.TargetPos = nil
        Cache.LookVector = nil
        if Cache.LaserBeam then Cache.LaserBeam.Transparency = 1 end
        return
    end

    if S.Prediction then
        local hrp = target.Character and target.Character:FindFirstChild("HumanoidRootPart")
        if hrp then
            local vel = hrp.AssemblyLinearVelocity or hrp.Velocity or Vector3.zero
            local dist = (pos - myRoot.Position).Magnitude
            local t = dist / math.max(S.BulletSpeed, 50)
            pos = pos + vel * t
        end
    end

    Cache.TargetPos = pos
    Cache.LookVector = (pos - myRoot.Position).Unit

    -- muzzle approx
    local handle = tool and (tool:FindFirstChild("Handle") or tool:FindFirstChildWhichIsA("BasePart"))
    Cache.CurrentMuzzle = handle

    if S.Laser and Cache.TargetPos and handle then
        if not Cache.LaserBeam then
            local p = Instance.new("Part")
            p.Name = "BintangSilentLaser"
            p.Anchored = true
            p.CanCollide = false
            p.CanTouch = false
            p.CastShadow = false
            p.Material = Enum.Material.Neon
            p.Color = S.LaserColor
            p.Size = Vector3.new(0.08, 0.08, 1)
            p.Transparency = 0.25
            p.Parent = workspace
            Cache.LaserBeam = p
        end
        local a = handle.Position
        local b = Cache.TargetPos
        local mid = (a + b) / 2
        local dist = (b - a).Magnitude
        Cache.LaserBeam.Size = Vector3.new(0.08, 0.08, dist)
        Cache.LaserBeam.CFrame = CFrame.lookAt(mid, b)
        Cache.LaserBeam.Color = S.LaserColor
        Cache.LaserBeam.Transparency = 0.2
    elseif Cache.LaserBeam then
        Cache.LaserBeam.Transparency = 1
    end
end

RunService.RenderStepped:Connect(function()
    pcall(updateAim)
end)

-- namecall hook ToF Fire / VisualizeBullet
pcall(function()
    if type(hookmetamethod) ~= "function" or type(getnamecallmethod) ~= "function" then return end
    local old
    old = hookmetamethod(game, "__namecall", function(self, ...)
        local method = getnamecallmethod()
        local args = {...}
        if method == "FireServer" and typeof(self) == "Instance" then
            if S.InfAmmo then
                local sn = string.lower(tostring(self.Name))
                local pn = self.Parent and string.lower(tostring(self.Parent.Name)) or ""
                -- jangan block Fire/VisualizeBullet (perlu buat nembak)
                if sn ~= "fire" and sn ~= "visualizebullet" then
                    if sn:find("ammo") or sn:find("reload") or sn:find("consume")
                        or sn:find("unload") or sn:find("useitem") or sn:find("spend") then
                        return nil
                    end
                end
                -- kalau remote ToF kirim flag loaded di table args, force true
                if pn:find("twist") or pn:find("fate") or pn:find("tof") then
                    for i = 1, #args do
                        if typeof(args[i]) == "boolean" then
                            -- keep
                        elseif typeof(args[i]) == "table" then
                            local tb = args[i]
                            for k, v in pairs(tb) do
                                local ks = string.lower(tostring(k))
                                if ks:find("load") or ks:find("bullet") or ks:find("ammo") then
                                    if typeof(v) == "boolean" then tb[k] = true end
                                    if typeof(v) == "number" then tb[k] = 99 end
                                end
                            end
                        end
                    end
                end
            end
        end
        if method == "FireServer" and typeof(self) == "Instance" and S.Enabled then
            if typeof(Cache.LookVector) == "Vector3" and typeof(Cache.TargetPos) == "Vector3" then
                local parent = self.Parent
                local okParent = parent and (tostring(parent.Name):find("Twist") or tostring(parent.Name):find("Fate") or tostring(parent.Name):lower():find("tof") or tostring(parent.Name):lower():find("pistol"))
                if okParent or tostring(self.Name) == "Fire" or tostring(self.Name) == "VisualizeBullet" then
                    if self.Name == "Fire" then
                        for i = 1, #args do
                            if typeof(args[i]) == "Vector3" then args[i] = Cache.LookVector end
                        end
                        return old(self, unpack(args))
                    elseif self.Name == "VisualizeBullet" then
                        for i = 1, #args do
                            if typeof(args[i]) == "Vector3" then
                                if args[i].Magnitude > 10 then
                                    args[i] = Cache.TargetPos
                                else
                                    args[i] = Cache.LookVector
                                end
                            elseif typeof(args[i]) == "CFrame" then
                                local myRoot = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
                                if myRoot then args[i] = CFrame.lookAt(myRoot.Position, Cache.TargetPos) end
                            end
                        end
                        return old(self, unpack(args))
                    end
                end
            end
        end
        return old(self, ...)
    end)
end)

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

local function corner(p, r)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, r or 8)
    c.Parent = p
end
local function stroke(p, col, th)
    local s = Instance.new("UIStroke")
    s.Color = col or C.border
    s.Thickness = th or 1
    s.Parent = p
end
local function tween(o, t, props)
    TweenService:Create(o, TweenInfo.new(t or 0.12, Enum.EasingStyle.Quad), props):Play()
end

pcall(function()
    if CoreGui:FindFirstChild("BintangSilentPistol") then CoreGui.BintangSilentPistol:Destroy() end
    if CoreGui:FindFirstChild("BintangSilentPistolIcon") then CoreGui.BintangSilentPistolIcon:Destroy() end
end)

local gui = Instance.new("ScreenGui")
gui.Name = "BintangSilentPistol"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = CoreGui

local win = Instance.new("Frame")
win.Size = UDim2.new(0, 280, 0, 320)
win.Position = UDim2.new(0.5, -140, 0.5, -160)
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
title.Text = "Silent Pistol"
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
    b.MouseEnter:Connect(function()
        tween(b, 0.1, {BackgroundColor3 = danger and C.danger or C.border, TextColor3 = C.text})
    end)
    b.MouseLeave:Connect(function()
        tween(b, 0.1, {BackgroundColor3 = C.row, TextColor3 = C.muted})
    end)
    return b
end
local minBtn = topBtn("−", -64, false)
local closeBtn = topBtn("×", -32, true)

local body = Instance.new("Frame")
body.Position = UDim2.new(0, 0, 0, 40)
body.Size = UDim2.new(1, 0, 1, -40)
body.BackgroundTransparency = 1
body.Parent = win
local pad = Instance.new("UIPadding")
pad.PaddingTop = UDim.new(0, 10)
pad.PaddingLeft = UDim.new(0, 12)
pad.PaddingRight = UDim.new(0, 12)
pad.Parent = body
local list = Instance.new("UIListLayout")
list.Padding = UDim.new(0, 6)
list.Parent = body

local function addToggle(key, label, default)
    S[key] = S[key]
    if default ~= nil and S[key] == nil then S[key] = default end
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 36)
    row.BackgroundColor3 = C.row
    row.BorderSizePixel = 0
    row.Parent = body
    corner(row, 8)
    local lbl = Instance.new("TextLabel")
    lbl.BackgroundTransparency = 1
    lbl.Position = UDim2.new(0, 10, 0, 0)
    lbl.Size = UDim2.new(1, -56, 1, 0)
    lbl.Font = Enum.Font.Gotham
    lbl.TextSize = 12
    lbl.TextColor3 = C.text
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Text = label
    lbl.Parent = row
    local track = Instance.new("TextButton")
    track.Size = UDim2.new(0, 40, 0, 22)
    track.Position = UDim2.new(1, -48, 0.5, -11)
    track.BackgroundColor3 = S[key] and C.on or C.off
    track.Text = ""
    track.AutoButtonColor = false
    track.Parent = row
    corner(track, 11)
    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0, 18, 0, 18)
    knob.Position = S[key] and UDim2.new(1, -20, 0.5, -9) or UDim2.new(0, 2, 0.5, -9)
    knob.BackgroundColor3 = Color3.new(1, 1, 1)
    knob.BorderSizePixel = 0
    knob.Parent = track
    corner(knob, 9)
    track.MouseButton1Click:Connect(function()
        S[key] = not S[key]
        tween(track, 0.12, {BackgroundColor3 = S[key] and C.on or C.off})
        tween(knob, 0.12, {Position = S[key] and UDim2.new(1, -20, 0.5, -9) or UDim2.new(0, 2, 0.5, -9)})
    end)
end

local function addDropdown(key, label, options)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 36)
    row.BackgroundColor3 = C.row
    row.BorderSizePixel = 0
    row.Parent = body
    corner(row, 8)
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
    btn.Size = UDim2.new(0, 120, 0, 26)
    btn.Position = UDim2.new(1, -128, 0.5, -13)
    btn.BackgroundColor3 = C.panel
    btn.Text = tostring(S[key]) .. " ▼"
    btn.Font = Enum.Font.Gotham
    btn.TextSize = 11
    btn.TextColor3 = C.text
    btn.AutoButtonColor = false
    btn.Parent = row
    corner(btn, 6)
    stroke(btn, C.border, 1)
    local open = false
    local menu
    btn.MouseButton1Click:Connect(function()
        if open and menu then menu:Destroy() open = false return end
        open = true
        menu = Instance.new("Frame")
        menu.Size = UDim2.new(0, 120, 0, #options * 28)
        menu.Position = UDim2.new(1, -128, 1, 2)
        menu.BackgroundColor3 = C.panel
        menu.BorderSizePixel = 0
        menu.ZIndex = 40
        menu.Parent = row
        corner(menu, 6)
        stroke(menu, C.border, 1)
        local lay = Instance.new("UIListLayout")
        lay.Parent = menu
        for _, opt in ipairs(options) do
            local o = Instance.new("TextButton")
            o.Size = UDim2.new(1, 0, 0, 28)
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

addToggle("Enabled", "Silent Aim", false)
addToggle("Prediction", "Auto Prediction", true)
addToggle("Laser", "Show Laser", false)
addToggle("InfAmmo", "Unlimited Ammo", false)
addDropdown("TargetMode", "Target", {"Killer", "Survivor", "All"})
addDropdown("TargetPart", "Hit Part", {"Head", "Torso", "HumanoidRootPart"})

local note = Instance.new("TextLabel")
note.Size = UDim2.new(1, 0, 0, 36)
note.BackgroundTransparency = 1
note.Font = Enum.Font.Gotham
note.TextSize = 10
note.TextColor3 = C.muted
note.TextXAlignment = Enum.TextXAlignment.Left
note.TextWrapped = true
note.Text = "Equip Twist of Fate / pistol, toggle ON, shoot."
note.Parent = body

-- drag
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
iconGui.Name = "BintangSilentPistolIcon"
iconGui.ResetOnSpawn = false
iconGui.Enabled = false
iconGui.Parent = CoreGui
local iconBtn = Instance.new("TextButton")
iconBtn.Size = UDim2.new(0, 48, 0, 48)
iconBtn.Position = UDim2.new(0, 14, 0.45, 0)
iconBtn.BackgroundColor3 = C.panel
iconBtn.Text = "SP"
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
    S.Enabled = false
    if Cache.LaserBeam then Cache.LaserBeam:Destroy() end
    gui:Destroy()
    iconGui:Destroy()
end)

print("[BintangHub] Silent Pistol only loaded")
