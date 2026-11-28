--[[
  BintangKiller
  Frenzy | Silent Veil
  Hidden
  Tracker + ESP + body lock
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")

local LP = Players.LocalPlayer
print("[BINTANG_BOOT] script start")
local _firesignal = (_firesignal and firesignal) or nil
local _gethui = (type(gethui) == "function" and gethui) or nil
local _hookmm = (_hookmm and hookmetamethod) or nil
local _getncm = (type(getnamecallmethod) == "function" and getnamecallmethod) or nil
local _checkcaller = (type(checkcaller) == "function" and checkcaller) or function() return false end

local Camera = workspace.CurrentCamera


-- logo (simple — no huge b64)
local LOGO_IMAGE = ""
pcall(function()
    if typeof(getcustomasset) == "function" and typeof(isfile) == "function" then
        if isfile("BintangHubLogo.png") then
            LOGO_IMAGE = getcustomasset("BintangHubLogo.png")
        end
    end
end)



local S = {
    Frenzy = true,
    SilentVeil = true,
    Hidden = true,
    Butcher = false,
    ShowFOV = true,
    ShowCross = true,
    ShowESP = true,
    ShowTracker = true,
    AutoParry = false,
    SpearPrediction = true,
    ParryDist = 12,
    ParryAggressive = true,
    ShowParryRadius = false,
    ShowItemESP = true,
    SilentPistol = false,
    PistolLaser = true,
    PistolFOV = 180,
    PistolPredict = true,
    PistolBulletSpeed = 200,
    ParryFloating = true,
    FOV = 130,
    MaxDist = 50,
    VeilRange = 280,   -- spear jauh
    HiddenRange = 41,
    Sticky = 0.55,
    Predict = 0.18,
    CrossSize = 14,
    CrossStyle = 1,
    CrossColor = Color3.fromRGB(255, 255, 255),
}

local FRENZY_IDS = {
    ["rbxassetid://104540716539347"] = true, -- frenzylungehold
    ["rbxassetid://79310600168078"] = true,  -- attackfr
}

local HIDDEN_IDS = {
    ["rbxassetid://113255068724446"] = true,
    ["rbxassetid://73681849513551"] = true,  -- WipeMachete
    ["rbxassetid://139830743437188"] = true,
    ["rbxassetid://98163597193511"] = true,
    ["rbxassetid://12380926872645"] = true,
    ["rbxassetid://111816962746891"] = true,
    ["rbxassetid://104228973542429"] = true,
    ["rbxassetid://126526181422628"] = true,
}
local HIDDEN_NAME_PATTERNS = { "wipemachete", "wipe", "machete", "lungehold", "mark", "hidden" }

-- Silent Veil (spear / throw)
local VEIL_IDS = {
    -- tambah ID dump spear di sini
}
local VEIL_NAME_PATTERNS = { "spear", "veil", "throw", "throwspear", "throwveil", "pierce", "vow" }

local BUTCHER_IDS = {
    ["rbxassetid://134450878841800"] = true,
}

local locking = false
local lockSource = ""
local stickyTarget = nil
local FOVFrame, CrossGui, TrackLine, TrackDot, ESPFolder

local C = {
    bg = Color3.fromRGB(14, 12, 20),
    top = Color3.fromRGB(22, 16, 36),
    row = Color3.fromRGB(28, 22, 42),
    accent = Color3.fromRGB(155, 89, 255),
    accentDim = Color3.fromRGB(90, 50, 160),
    text = Color3.fromRGB(248, 245, 255),
    muted = Color3.fromRGB(150, 140, 170),
    on = Color3.fromRGB(155, 89, 255),
    off = Color3.fromRGB(45, 40, 58),
}


-- EARLY UI (muncul dulu, biar ga blank kalau logic error)
task.defer(function()
    pcall(function()
        if game:GetService("CoreGui"):FindFirstChild("BintangKillerEarly") then return end
        local pg = LP:FindFirstChild("PlayerGui") or LP:WaitForChild("PlayerGui", 3)
        local parent = pg
        pcall(function()
            if _gethui then parent = _gethui() end
        end)
        local g = Instance.new("ScreenGui")
        g.Name = "BintangKillerEarly"
        g.ResetOnSpawn = false
        g.DisplayOrder = 1000
        g.Parent = parent or pg
        local f = Instance.new("Frame")
        f.Name = "Main"
        f.Size = UDim2.fromOffset(280, 120)
        f.Position = UDim2.new(0, 20, 0.3, 0)
        f.BackgroundColor3 = Color3.fromRGB(14, 12, 20)
        f.BorderSizePixel = 0
        f.Parent = g
        Instance.new("UICorner", f).CornerRadius = UDim.new(0, 12)
        local tl = Instance.new("TextLabel")
        tl.BackgroundTransparency = 1
        tl.Size = UDim2.new(1, -20, 0, 30)
        tl.Position = UDim2.fromOffset(10, 10)
        tl.Font = Enum.Font.GothamBold
        tl.TextSize = 16
        tl.TextColor3 = Color3.fromRGB(248, 245, 255)
        tl.TextXAlignment = Enum.TextXAlignment.Left
        tl.Text = "BintangKiller"
        tl.Parent = f
        local st = Instance.new("TextLabel")
        st.BackgroundTransparency = 1
        st.Size = UDim2.new(1, -20, 0, 40)
        st.Position = UDim2.fromOffset(10, 45)
        st.Font = Enum.Font.Gotham
        st.TextSize = 12
        st.TextColor3 = Color3.fromRGB(150, 140, 170)
        st.TextXAlignment = Enum.TextXAlignment.Left
        st.TextWrapped = true
        st.Text = "Loading panel...\nKalau ini doang yang muncul, ada error di bawah."
        st.Parent = f
        print("[BintangKiller] early UI ok")
        -- destroy when real UI appears
        task.spawn(function()
            for i = 1, 50 do
                task.wait(0.2)
                local real = (parent and parent:FindFirstChild("BintangKiller"))
                    or (pg and pg:FindFirstChild("BintangKiller"))
                    or game:GetService("CoreGui"):FindFirstChild("BintangKiller")
                if real then
                    g:Destroy()
                    return
                end
            end
        end)
    end)
end)

local function corner(p, r)
    Instance.new("UICorner", p).CornerRadius = UDim.new(0, r or 8)
end
local function tween(o, t, props)
    TweenService:Create(o, TweenInfo.new(t or 0.12, Enum.EasingStyle.Quad), props):Play()
end

local function normalizeId(id)
    if not id then return nil end
    local num = tostring(id):match("(%d+)")
    return num and ("rbxassetid://" .. num) or tostring(id)
end

local function isSurvivor(plr)
    if plr == LP then return false end
    if LP.Team and plr.Team and LP.Team == plr.Team then return false end
    local role = plr:GetAttribute("Role") or plr:GetAttribute("role")
    if role and string.lower(tostring(role)):find("kill") then return false end
    return true
end

local function alive(plr)
    local c = plr.Character
    if not c then return false end
    local h = c:FindFirstChildOfClass("Humanoid")
    local r = c:FindFirstChild("HumanoidRootPart")
    return h and h.Health > 0 and r
end

local function isKnocked(plr)
    local c = plr.Character
    if not c then return false end
    local h = c:FindFirstChildOfClass("Humanoid")
    if not h then return false end
    if h.Health <= 0 then return true end
    local st = h:GetState()
    if st == Enum.HumanoidStateType.Physics or st == Enum.HumanoidStateType.Ragdoll then return true end
    if c:GetAttribute("Downed") or c:GetAttribute("Knocked") or c:GetAttribute("DBNO") then return true end
    if plr:GetAttribute("Downed") or plr:GetAttribute("Knocked") then return true end
    return h.Health > 0 and h.Health <= (h.MaxHealth * 0.15) and h.WalkSpeed < 1
end

local function targetPos(plr)
    local char = plr.Character
    if not char then return nil end
    local part = char:FindFirstChild("HumanoidRootPart")
        or char:FindFirstChild("Torso")
        or char:FindFirstChild("UpperTorso")
        or char:FindFirstChild("Head")
    if not part then return nil end
    return part.Position + (part.AssemblyLinearVelocity or Vector3.zero) * S.Predict, part
end

local function matchLock(id, track)
    id = normalizeId(id)
    local blob = ""
    if track then
        local anim = track.Animation
        blob = string.lower(table.concat({
            tostring(track.Name or ""),
            tostring(anim and anim.Name or ""),
            tostring(id or ""),
        }, " "))
    end
    if S.Frenzy then
        if id and FRENZY_IDS[id] then return "Frenzy" end
        if blob:find("frenzy", 1, true) then return "Frenzy" end
    end
    if S.SilentVeil then
        if id and VEIL_IDS[id] then return "Veil" end
        for _, pat in ipairs(VEIL_NAME_PATTERNS) do
            if blob:find(pat, 1, true) then return "Veil" end
        end
    end
    if S.Butcher and id and BUTCHER_IDS[id] then return "Butcher" end
    if S.Hidden then
        if id and HIDDEN_IDS[id] then return "Hidden" end
        for _, pat in ipairs(HIDDEN_NAME_PATTERNS) do
            if blob:find(pat, 1, true) then return "Hidden" end
        end
    end
    return nil
end

local function getLockTarget(rangeOverride)
    local maxDist = rangeOverride or S.MaxDist
    local bestPlr, bestPos, bestScore = nil, nil, S.FOV
    local center = Camera.ViewportSize / 2
    local camPos = Camera.CFrame.Position

    if stickyTarget and alive(stickyTarget) and isSurvivor(stickyTarget) then
        local pos = targetPos(stickyTarget)
        if pos then
            local dist3 = (pos - camPos).Magnitude
            if dist3 <= maxDist then
                local v, on = Camera:WorldToViewportPoint(pos)
                if on and v.Z > 0 then
                    local d = (Vector2.new(v.X, v.Y) - center).Magnitude
                    local stickMul = (lockSource == "Hidden" or lockSource == "Veil") and 0.12 or (1 - S.Sticky)
                    if d < S.FOV * ((lockSource == "Hidden" or lockSource == "Veil") and 1.45 or 1.15) then
                        bestPlr, bestPos, bestScore = stickyTarget, pos, d * stickMul
                    end
                end
            end
        else
            stickyTarget = nil
        end
    end

    for _, plr in ipairs(Players:GetPlayers()) do
        if isSurvivor(plr) and alive(plr) then
            local pos = targetPos(plr)
            if pos then
                local dist3 = (pos - camPos).Magnitude
                if dist3 <= maxDist then
                    local v, on = Camera:WorldToViewportPoint(pos)
                    if on and v.Z > 0 then
                        local d = (Vector2.new(v.X, v.Y) - center).Magnitude
                        if d < S.FOV then
                            local score = d + dist3 * 0.12
                            if plr == stickyTarget then score = score * (1 - S.Sticky) end
                            if score < bestScore then
                                bestScore, bestPlr, bestPos = score, plr, pos
                            end
                        end
                    end
                end
            end
        end
    end
    if bestPlr then stickyTarget = bestPlr end
    return bestPlr, bestPos
end

local function ensureVisual()
    if FOVFrame and FOVFrame.Parent then return end
    local g = Instance.new("ScreenGui")
    g.Name = "BintangKillerVis"
    g.IgnoreGuiInset = true
    g.ResetOnSpawn = false
    pcall(function() g.Parent = _gethui and _gethui() or CoreGui end)
    if not g.Parent then g.Parent = LP:WaitForChild("PlayerGui") end

    FOVFrame = Instance.new("Frame")
    FOVFrame.AnchorPoint = Vector2.new(0.5, 0.5)
    FOVFrame.BackgroundTransparency = 1
    FOVFrame.Parent = g
    local s = Instance.new("UIStroke")
    s.Color = C.accent
    s.Thickness = 1.4
    s.Transparency = 0.35
    s.Parent = FOVFrame
    Instance.new("UICorner", FOVFrame).CornerRadius = UDim.new(1, 0)

    CrossGui = Instance.new("Frame")
    CrossGui.AnchorPoint = Vector2.new(0.5, 0.5)
    CrossGui.BackgroundTransparency = 1
    CrossGui.Parent = g

    TrackLine = Instance.new("Frame")
    TrackLine.AnchorPoint = Vector2.new(0.5, 0.5)
    TrackLine.BorderSizePixel = 0
    TrackLine.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    TrackLine.BackgroundTransparency = 0.15
    TrackLine.Visible = false
    TrackLine.Parent = g

    TrackDot = Instance.new("Frame")
    TrackDot.AnchorPoint = Vector2.new(0.5, 0.5)
    TrackDot.Size = UDim2.fromOffset(8, 8)
    TrackDot.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    TrackDot.BorderSizePixel = 0
    TrackDot.Visible = false
    TrackDot.Parent = g
    Instance.new("UICorner", TrackDot).CornerRadius = UDim.new(1, 0)

    ESPFolder = Instance.new("Folder")
    ESPFolder.Name = "BKESP"
    ESPFolder.Parent = g
end

local function rebuildCross()
    if not CrossGui then return end
    for _, c in ipairs(CrossGui:GetChildren()) do c:Destroy() end
    local sz = S.CrossSize
    CrossGui.Size = UDim2.fromOffset(sz, sz)
    local col = S.CrossColor
    local style = S.CrossStyle
    local function arm(ax, ay, w, h)
        local f = Instance.new("Frame")
        f.AnchorPoint = Vector2.new(0.5, 0.5)
        f.Position = UDim2.fromScale(ax, ay)
        f.Size = UDim2.fromOffset(w, h)
        f.BackgroundColor3 = col
        f.BorderSizePixel = 0
        f.Parent = CrossGui
    end
    if style == 1 then
        local t = math.max(2, math.floor(sz * 0.12))
        local l = math.floor(sz * 0.35)
        arm(0.5, 0.15, t, l); arm(0.5, 0.85, t, l); arm(0.15, 0.5, l, t); arm(0.85, 0.5, l, t)
    elseif style == 2 then
        for _, rot in ipairs({45, -45}) do
            local f = Instance.new("Frame")
            f.AnchorPoint = Vector2.new(0.5, 0.5)
            f.Position = UDim2.fromScale(0.5, 0.5)
            f.Size = UDim2.fromOffset(math.max(2, sz * 0.12), sz * 0.7)
            f.BackgroundColor3 = col
            f.BorderSizePixel = 0
            f.Rotation = rot
            f.Parent = CrossGui
        end
    elseif style == 3 then
        local d = Instance.new("Frame")
        d.AnchorPoint = Vector2.new(0.5, 0.5)
        d.Position = UDim2.fromScale(0.5, 0.5)
        d.Size = UDim2.fromOffset(math.max(4, sz * 0.35), math.max(4, sz * 0.35))
        d.BackgroundColor3 = col
        d.BorderSizePixel = 0
        d.Parent = CrossGui
        Instance.new("UICorner", d).CornerRadius = UDim.new(1, 0)
    else
        local d = Instance.new("Frame")
        d.AnchorPoint = Vector2.new(0.5, 0.5)
        d.Position = UDim2.fromScale(0.5, 0.5)
        d.Size = UDim2.fromOffset(sz, sz)
        d.BackgroundTransparency = 1
        d.Parent = CrossGui
        Instance.new("UICorner", d).CornerRadius = UDim.new(1, 0)
        local st = Instance.new("UIStroke")
        st.Color = col
        st.Thickness = math.max(1.5, sz * 0.1)
        st.Parent = d
    end
end

RunService.RenderStepped:Connect(function()
    ensureVisual()
    local vp = Camera.ViewportSize
    local cx, cy = vp.X / 2, vp.Y / 2
    local any = S.Frenzy or S.SilentVeil or S.Hidden or S.Butcher

    if S.ShowFOV and any then
        FOVFrame.Visible = true
        FOVFrame.Size = UDim2.fromOffset(S.FOV * 2, S.FOV * 2)
        FOVFrame.Position = UDim2.fromOffset(cx, cy)
        local st = FOVFrame:FindFirstChildOfClass("UIStroke")
        if st then
            st.Color = locking and Color3.fromRGB(255, 80, 120) or C.accent
            st.Transparency = locking and 0.1 or 0.35
        end
    else
        FOVFrame.Visible = false
    end

    CrossGui.Visible = any and S.ShowCross
    CrossGui.Position = UDim2.fromOffset(cx, cy)
    if CrossGui and #CrossGui:GetChildren() == 0 then rebuildCross() end

    local lockPlr, lockPos = nil, nil
    if locking then
        local range = S.MaxDist
        if lockSource == "Hidden" then range = S.HiddenRange
        elseif lockSource == "Veil" then range = S.VeilRange end
        lockPlr, lockPos = getLockTarget(range)
        if lockPos then
            local str = 0.55
            if lockSource == "Frenzy" then str = 0.62
            elseif lockSource == "Veil" then str = 0.95
            elseif lockSource == "Hidden" then str = 0.92
            elseif lockSource == "Butcher" then str = 0.75 end
            Camera.CFrame = Camera.CFrame:Lerp(CFrame.new(Camera.CFrame.Position, lockPos), str)
        end
    end

    -- tracker KHUSUS Silent Veil
    if TrackLine and TrackDot then
        local tp = nil
        if S.ShowTracker and S.SilentVeil then
            if lockSource == "Veil" and lockPos then
                tp = lockPos
            else
                local _, np = getLockTarget(S.VeilRange)
                tp = np
            end
        end
        if tp then
            local sp, on = Camera:WorldToViewportPoint(tp)
            if on and sp.Z > 0 then
                local from = Vector2.new(cx, cy + 36)
                local to = Vector2.new(sp.X, sp.Y)
                local mid = (from + to) / 2
                local len = (to - from).Magnitude
                local ang = math.deg(math.atan2(to.Y - from.Y, to.X - from.X))
                TrackLine.Visible = true
                TrackDot.Visible = true
                TrackLine.BackgroundColor3 = locking and Color3.fromRGB(255, 90, 120) or Color3.fromRGB(255, 255, 255)
                TrackLine.Size = UDim2.fromOffset(math.max(1, len), locking and 2 or 1.2)
                TrackLine.Position = UDim2.fromOffset(mid.X, mid.Y)
                TrackLine.Rotation = ang
                TrackDot.BackgroundColor3 = TrackLine.BackgroundColor3
                TrackDot.Position = UDim2.fromOffset(sp.X, sp.Y)
            else
                TrackLine.Visible = false
                TrackDot.Visible = false
            end
        else
            TrackLine.Visible = false
            TrackDot.Visible = false
        end
    end
end)

-- ESP labels
local espBox = {}
local function statusOf(plr, hum, char)
    if isKnocked(plr) then return "DOWNED", Color3.fromRGB(255, 55, 55) end
    local hp = hum.Health / math.max(1, hum.MaxHealth)
    if hp <= 0.5 then return "INJURED", Color3.fromRGB(255, 170, 40) end
    return "HEALTHY", Color3.fromRGB(80, 255, 120)
end

RunService.RenderStepped:Connect(function()
    if not S.ShowESP then
        for _, g in pairs(espBox) do if g then g.Enabled = false end end
        return
    end
    ensureVisual()
    local camPos = Camera.CFrame.Position
    for _, plr in ipairs(Players:GetPlayers()) do
        if isSurvivor(plr) and alive(plr) then
            local char = plr.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            if hrp and hum then
                local bill = espBox[plr]
                if not bill or not bill.Parent then
                    bill = Instance.new("BillboardGui")
                    bill.Name = "BK_" .. plr.Name
                    bill.AlwaysOnTop = true
                    bill.Size = UDim2.fromOffset(150, 46)
                    bill.StudsOffset = Vector3.new(0, 3.2, 0)
                    bill.Adornee = hrp
                    bill.Parent = ESPFolder or CoreGui
                    local status = Instance.new("TextLabel")
                    status.Name = "Status"
                    status.BackgroundTransparency = 1
                    status.Size = UDim2.new(1, 0, 0, 15)
                    status.Font = Enum.Font.GothamBold
                    status.TextSize = 13
                    status.TextStrokeTransparency = 0.4
                    status.TextXAlignment = Enum.TextXAlignment.Center
                    status.Parent = bill
                    local info = Instance.new("TextLabel")
                    info.Name = "Info"
                    info.BackgroundTransparency = 1
                    info.Size = UDim2.new(1, 0, 0, 14)
                    info.Position = UDim2.fromOffset(0, 15)
                    info.Font = Enum.Font.Gotham
                    info.TextSize = 11
                    info.TextStrokeTransparency = 0.5
                    info.TextXAlignment = Enum.TextXAlignment.Center
                    info.Parent = bill
                    local name = Instance.new("TextLabel")
                    name.Name = "PName"
                    name.BackgroundTransparency = 1
                    name.Size = UDim2.new(1, 0, 0, 14)
                    name.Position = UDim2.fromOffset(0, 28)
                    name.Font = Enum.Font.Gotham
                    name.TextSize = 11
                    name.TextColor3 = Color3.fromRGB(200, 200, 210)
                    name.TextStrokeTransparency = 0.55
                    name.TextXAlignment = Enum.TextXAlignment.Center
                    name.Parent = bill
                    espBox[plr] = bill
                end
                bill.Enabled = true
                bill.Adornee = hrp
                local st, col = statusOf(plr, hum, char)
                local dist = math.floor((hrp.Position - camPos).Magnitude + 0.5)
                local a = bill:FindFirstChild("Status")
                local b = bill:FindFirstChild("Info")
                local c = bill:FindFirstChild("PName")
                if a then a.Text = st; a.TextColor3 = col end
                if b then b.Text = dist .. "m"; b.TextColor3 = col end
                if c then c.Text = plr.DisplayName or plr.Name end
            elseif espBox[plr] then
                espBox[plr].Enabled = false
            end
        elseif espBox[plr] then
            espBox[plr].Enabled = false
        end
    end
end)

local function hookAnimator(animator)
    animator.AnimationPlayed:Connect(function(track)
        local id = track.Animation and track.Animation.AnimationId
        local src = matchLock(id, track)
        if not src then return end
        locking = true
        lockSource = src
        print("[BintangKiller] LOCK", src, normalizeId(id))
        task.spawn(function()
            while track.IsPlaying do task.wait(0.016) end
            locking = false
            lockSource = ""
            stickyTarget = nil
        end)
    end)
end

local function hookChar(char)
    task.spawn(function()
        local hum = char:WaitForChild("Humanoid", 8)
        if not hum then return end
        local animator = hum:FindFirstChildOfClass("Animator") or hum:WaitForChild("Animator", 5)
        if animator then hookAnimator(animator) end
    end)
end
if LP.Character then hookChar(LP.Character) end
LP.Charac
-- ===== AUTO PARRY (PerryNew · anim + anti fake hit) =====
local ParryLast = 0
local ActiveAttackers = {}
local KillerAttackAnims = {
    ["rbxassetid://78432063483146"] = "attack", ["rbxassetid://121216847022485"] = "attack",
    ["rbxassetid://74968262036854"] = "attack", ["rbxassetid://132817836308238"] = "attack",
    ["rbxassetid://82666958311998"] = "attack", ["rbxassetid://111920872708571"] = "attack",
    ["rbxassetid://106871536134254"] = "attack", ["rbxassetid://109402730355822"] = "attack",
    ["rbxassetid://130593238885843"] = "attack", ["rbxassetid://138720291317243"] = "attack",
    ["rbxassetid://139369275981139"] = "attack", ["rbxassetid://133963973694098"] = "attack",
    ["rbxassetid://78935059863801"] = "attack", ["rbxassetid://118907603246885"] = "lungehold",
    ["rbxassetid://135002183282873"] = "lungehold", ["rbxassetid://113255068724446"] = "lungehold",
    ["rbxassetid://129784271201071"] = "lungehold", ["rbxassetid://105374834496520"] = "lungehold",
    ["rbxassetid://117070354890871"] = "lungehold", ["rbxassetid://115244153053858"] = "lungehold",
    ["rbxassetid://110355011987939"] = "lungehold", ["rbxassetid://117042998468241"] = "lungehold",
    ["rbxassetid://122812055447896"] = "lungehold",
    -- frenzy / common
    ["rbxassetid://104540716539347"] = "lungehold",
    ["rbxassetid://79310600168078"] = "attack",
}

local function normAnim(id)
    if not id then return nil end
    local n = tostring(id):match("(%d+)")
    return n and ("rbxassetid://" .. n) or tostring(id)
end

local function ExecuteParry()
    if tick() - ParryLast < 0.2 then return end
    ParryLast = tick()
    local pGui = LP:FindFirstChild("PlayerGui")
    local mobBtn = pGui and pGui:FindFirstChild("Survivor-mob")
        and pGui["Survivor-mob"]:FindFirstChild("Controls")
        and pGui["Survivor-mob"].Controls:FindFirstChild("Gui-mob")
    if mobBtn and _firesignal then
        pcall(function()
            _firesignal(mobBtn.MouseButton1Down)
            task.delay(0.05, function()
                if mobBtn and mobBtn.Parent then _firesignal(mobBtn.MouseButton1Up) end
            end)
        end)
        return
    end
    local rep = game:GetService("ReplicatedStorage")
    local parryRemote = rep:FindFirstChild("Remotes")
        and rep.Remotes:FindFirstChild("Items")
        and rep.Remotes.Items:FindFirstChild("Parrying Dagger")
        and rep.Remotes.Items["Parrying Dagger"]:FindFirstChild("parry")
    if parryRemote then
        pcall(function() parryRemote:FireServer() end)
        return
    end
    local vim = game:GetService("VirtualInputManager")
    pcall(function()
        vim:SendMouseButtonEvent(0, 0, 1, true, game, 0)
        task.wait(0.05)
        vim:SendMouseButtonEvent(0, 0, 1, false, game, 0)
    end)
end

local function CheckAndParry(killerChar)
    local myChar = LP.Character
    local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
    local killerRoot = killerChar and killerChar:FindFirstChild("HumanoidRootPart")
    if not myRoot or not killerRoot then return end
    local dist = (myRoot.Position - killerRoot.Position).Magnitude
    if S.ParryAggressive then
        local ping = 0.08
        pcall(function() ping = math.clamp(LP:GetNetworkPing(), 0, 0.3) end)
        local killerVel = killerRoot.AssemblyLinearVelocity
        local flatVel = Vector3.new(killerVel.X, 0, killerVel.Z)
        local predictedPos = killerRoot.Position + (flatVel * ping)
        local predictedDist = (myRoot.Position - predictedPos).Magnitude
        if predictedDist <= (S.ParryDist + 2) then
            local toMe = myRoot.Position - killerRoot.Position
            if toMe.Magnitude > 0.1 then
                local dirToMe = toMe.Unit
                if flatVel.Magnitude > 8 and flatVel.Unit:Dot(dirToMe) > 0.5 then
                    ExecuteParry()
                    return
                end
            end
        end
    end
    if dist <= S.ParryDist then
        ExecuteParry()
    end
end

local function HookKillerAnimation(killerPlayer)
    if killerPlayer == LP then return end
    local function onCharacterAdded(char)
        task.spawn(function()
            task.wait(0.5)
            local hum = char:WaitForChild("Humanoid", 5)
            if not hum then return end
            local animator = hum:FindFirstChildOfClass("Animator") or hum:WaitForChild("Animator", 3)
            if not animator then return end
            animator.AnimationPlayed:Connect(function(track)
                if not S.AutoParry then return end
                if not track or not track.Animation then return end
                local id = normAnim(track.Animation.AnimationId)
                local animType = KillerAttackAnims[id]
                if animType then
                    -- anti fake: only register known attack/lungehold IDs
                    ActiveAttackers[killerPlayer] = { char = char, track = track, type = animType }
                end
            end)
        end)
    end
    if killerPlayer.Character then onCharacterAdded(killerPlayer.Character) end
    killerPlayer.CharacterAdded:Connect(onCharacterAdded)
end

for _, plr in ipairs(Players:GetPlayers()) do HookKillerAnimation(plr) end
Players.PlayerAdded:Connect(HookKillerAnimation)

-- Show radius circle (optional)
local ParryAdorn = nil
local function updateParryRadius()
    if not S.ShowParryRadius or not S.AutoParry then
        if ParryAdorn then ParryAdorn.Visible = false end
        return
    end
    local myRoot = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
    if not myRoot then return end
    if not ParryAdorn or not ParryAdorn.Parent then
        local a = Instance.new("CylinderHandleAdornment")
        a.Name = "BintangParryRadius"
        a.AlwaysOnTop = true
        a.ZIndex = 1
        a.Height = 0.15
        a.Transparency = 0.55
        a.Color3 = Color3.fromRGB(170, 0, 255)
        a.Adornee = workspace.Terrain
        pcall(function() a.Parent = _gethui and _gethui() or game:GetService("CoreGui") end)
        if not a.Parent then a.Parent = LP:WaitForChild("PlayerGui") end
        ParryAdorn = a
    end
    ParryAdorn.Visible = true
    ParryAdorn.Radius = S.ParryDist
    ParryAdorn.CFrame = CFrame.new(myRoot.Position) * CFrame.Angles(0, 0, math.rad(90))
end

RunService.Heartbeat:Connect(function()
    if not S.AutoParry then
        for k in pairs(ActiveAttackers) do ActiveAttackers[k]=nil end
        if ParryAdorn then ParryAdorn.Visible = false end
        return
    end
    updateParryRadius()
    for plr, data in pairs(ActiveAttackers) do
        if not plr or not plr.Parent or not data.track or not data.track.IsPlaying then
            ActiveAttackers[plr] = nil
        else
            -- anti fake hit: attack hanya di awal swing (<0.25s), lungehold full
            if data.type == "attack" and data.track.TimePosition < 0.25 then
                CheckAndParry(data.char)
            elseif data.type == "lungehold" then
                CheckAndParry(data.char)
            end
        end
    end
end)

d
        end
    end
end)



-- ===== SILENT PISTOL (Twist of Fate · Ganz style) ===== SilentPistolLogic
local PistolCache = {
    TargetPos = nil,
    LookVector = nil,
    Muzzle = nil,
    LaserBeam = nil,
    IsAiming = false,
}

local function GetPistolTargetPart(char)
    if not char then return nil end
    local part = char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso") or char:FindFirstChild("HumanoidRootPart")
    return part and part.Position or nil
end

local function GetMuzzlePos()
    local myChar = LP.Character
    if not myChar then return nil end
    local tool = myChar:FindFirstChild("Twist of Fate")
    if not tool then return nil end
    local muzzle = tool:FindFirstChild("Muzzle", true) or tool:FindFirstChild("gun", true) or tool:FindFirstChild("Handle")
    if muzzle and muzzle:IsA("BasePart") then return muzzle.Position end
    local arm = myChar:FindFirstChild("Right Arm") or myChar:FindFirstChild("RightHand")
    return arm and arm.Position or nil
end

local function isKillerTeam(plr)
    if plr == LP then return false end
    if plr.Team and string.lower(plr.Team.Name):find("iller") then return true end
    local role = plr:GetAttribute("Role") or plr:GetAttribute("role")
    if role and string.lower(tostring(role)):find("kill") then return true end
    return false
end

local function UpdateSilentPistol()
    local equipped = LP:GetAttribute("EquippedItem") == "Twist of Fate"
        or (LP.Character and LP.Character:FindFirstChild("Twist of Fate") ~= nil)
    if not S.SilentPistol or not equipped then
        PistolCache.TargetPos = nil
        PistolCache.LookVector = nil
        if PistolCache.LaserBeam then PistolCache.LaserBeam.Transparency = 1 end
        return
    end
    local myRoot = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
    if not myRoot then return end

    local bestDist, bestPlr = math.huge, nil
    local center = Camera.ViewportSize / 2
    for _, plr in ipairs(Players:GetPlayers()) do
        if isKillerTeam(plr) and plr.Character then
            local hum = plr.Character:FindFirstChildOfClass("Humanoid")
            local pos = GetPistolTargetPart(plr.Character)
            if hum and hum.Health > 0 and pos then
                local sp, on = Camera:WorldToViewportPoint(pos)
                if on and sp.Z > 0 then
                    local d2 = (Vector2.new(sp.X, sp.Y) - center).Magnitude
                    local d3 = (pos - myRoot.Position).Magnitude
                    if d2 <= S.PistolFOV and d3 < bestDist then
                        bestDist = d3
                        bestPlr = plr
                    end
                end
            end
        end
    end

    if bestPlr and bestPlr.Character then
        local bestPos = GetPistolTargetPart(bestPlr.Character)
        local muzzle = GetMuzzlePos() or Camera.CFrame.Position
        local aimPoint = bestPos
        if S.PistolPredict and bestPos then
            local hrp = bestPlr.Character:FindFirstChild("HumanoidRootPart")
            local vel = hrp and hrp.AssemblyLinearVelocity or Vector3.zero
            local flat = Vector3.new(vel.X, 0, vel.Z)
            local dist = (bestPos - muzzle).Magnitude
            local travel = dist / math.max(S.PistolBulletSpeed, 1)
            local ping = 0.05
            pcall(function() ping = math.clamp(LP:GetNetworkPing(), 0, 0.2) end)
            aimPoint = bestPos + flat * (travel + ping)
        end
        if aimPoint then
            PistolCache.TargetPos = aimPoint
            PistolCache.LookVector = (aimPoint - muzzle).Unit
            PistolCache.Muzzle = muzzle
        end
    else
        PistolCache.TargetPos = nil
        PistolCache.LookVector = nil
    end

    -- laser ke killer saat hold / aim
    if S.PistolLaser and PistolCache.TargetPos and PistolCache.Muzzle and (PistolCache.IsAiming or true) then
        if not PistolCache.LaserBeam or not PistolCache.LaserBeam.Parent then
            local beam = Instance.new("Part")
            beam.Name = "BintangPistolLaser"
            beam.Anchored = true
            beam.CanCollide = false
            beam.CanTouch = false
            beam.CanQuery = false
            beam.CastShadow = false
            beam.Material = Enum.Material.Neon
            beam.Color = Color3.fromRGB(255, 50, 50)
            beam.Parent = workspace
            PistolCache.LaserBeam = beam
        end
        local mPos = PistolCache.Muzzle
        local tPos = PistolCache.TargetPos
        local dist = (mPos - tPos).Magnitude
        PistolCache.LaserBeam.Size = Vector3.new(0.04, 0.04, dist)
        PistolCache.LaserBeam.CFrame = CFrame.lookAt(mPos, tPos) * CFrame.new(0, 0, -dist / 2)
        PistolCache.LaserBeam.Transparency = 0.35
    else
        if PistolCache.LaserBeam then PistolCache.LaserBeam.Transparency = 1 end
    end
end

UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.UserInputType == Enum.UserInputType.MouseButton2 then
        if LP.Character and LP.Character:FindFirstChild("Twist of Fate") then
            PistolCache.IsAiming = true
        end
    end
end)
UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton2 then
        PistolCache.IsAiming = false
    end
end)

-- FOV circle for pistol
local PistolFOVFrame = nil
RunService.RenderStepped:Connect(function()
    pcall(UpdateSilentPistol)
    local equipped = LP.Character and LP.Character:FindFirstChild("Twist of Fate")
    if S.SilentPistol and equipped and S.ShowFOV then
        ensureVisual()
        if FOVFrame then
            local vp = Camera.ViewportSize
            FOVFrame.Visible = true
            FOVFrame.Size = UDim2.fromOffset(S.PistolFOV * 2, S.PistolFOV * 2)
            FOVFrame.Position = UDim2.fromOffset(vp.X / 2, vp.Y / 2)
        end
    end
end)

task.spawn(function()
    pcall(function()
        if not _hookmm then return end
        local old
        old = _hookmm(game, "__namecall", function(self, ...)
            local method = (_getncm and _getncm() or "")
            local args = {...}
            if not _checkcaller() and method == "FireServer" and typeof(self) == "Instance" then
                if S.SilentPistol and typeof(PistolCache.LookVector) == "Vector3" and typeof(PistolCache.TargetPos) == "Vector3" then
                    if self.Parent and self.Parent.Name == "Twist of Fate" then
                        local sName = self.Name
                        if sName == "Fire" then
                            for i = 1, #args do
                                if typeof(args[i]) == "Vector3" then args[i] = PistolCache.LookVector end
                            end
                            return old(self, unpack(args))
                        elseif sName == "VisualizeBullet" then
                            for i = 1, #args do
                                if typeof(args[i]) == "Vector3" then
                                    if args[i].Magnitude > 10 then args[i] = PistolCache.TargetPos
                                    else args[i] = PistolCache.LookVector end
                                elseif typeof(args[i]) == "CFrame" then
                                    local myRoot = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
                                    if myRoot then args[i] = CFrame.lookAt(myRoot.Position, PistolCache.TargetPos) end
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
end)

-- ===== UI =====
pcall(function()
    if CoreGui:FindFirstChild("BintangKiller") then CoreGui.BintangKiller:Destroy() end
    if CoreGui:FindFirstChild("BintangKillerIcon") then CoreGui.BintangKillerIcon:Destroy() end
end)

print("[BintangKiller] building UI...")
local gui = Instance.new("ScreenGui")
gui.Name = "BintangKiller"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.DisplayOrder = 999
local function parentGui(g)
    local ok = pcall(function()
        if _gethui then g.Parent = _gethui() return end
    end)
    if g.Parent then return end
    ok = pcall(function() g.Parent = CoreGui end)
    if g.Parent then return end
    pcall(function() g.Parent = LP:WaitForChild("PlayerGui", 5) end)
end
parentGui(gui)
if not gui.Parent then
    warn("[BintangKiller] UI parent FAILED")
else
    print("[BintangKiller] UI parent =", gui.Parent:GetFullName())
end

local WIN_W = 310
local win = Instance.new("Frame")
win.Name = "Main"
win.Size = UDim2.fromOffset(WIN_W, 400)
win.Position = UDim2.new(0, 14, 0.25, 0)
win.BackgroundColor3 = C.bg
win.BorderSizePixel = 0
win.Parent = gui
corner(win, 12)
local ws = Instance.new("UIStroke")
ws.Color = C.accentDim
ws.Thickness = 1.2
ws.Transparency = 0.3
ws.Parent = win

local top = Instance.new("Frame")
top.Size = UDim2.new(1, 0, 0, 40)
top.BackgroundColor3 = C.top
top.BorderSizePixel = 0
top.Parent = win
corner(top, 12)
local topFix = Instance.new("Frame")
topFix.Size = UDim2.new(1, 0, 0, 12)
topFix.Position = UDim2.new(0, 0, 1, -12)
topFix.BackgroundColor3 = C.top
topFix.BorderSizePixel = 0
topFix.Parent = top

local logo = Instance.new("ImageLabel")
logo.Size = UDim2.fromOffset(26, 26)
logo.Position = UDim2.fromOffset(10, 7)
logo.BackgroundColor3 = C.row
logo.Image = LOGO_IMAGE
logo.ScaleType = Enum.ScaleType.Fit
logo.Parent = top
corner(logo, 13)
if LOGO_IMAGE == "" then
    local fb = Instance.new("TextLabel")
    fb.BackgroundTransparency = 1
    fb.Size = UDim2.fromScale(1, 1)
    fb.Font = Enum.Font.GothamBold
    fb.TextSize = 13
    fb.TextColor3 = C.accent
    fb.Text = "B"
    fb.Parent = logo
end

local title = Instance.new("TextLabel")
title.BackgroundTransparency = 1
title.Position = UDim2.fromOffset(42, 0)
title.Size = UDim2.new(1, -110, 1, 0)
title.Font = Enum.Font.GothamBold
title.TextSize = 14
title.TextColor3 = C.text
title.TextXAlignment = Enum.TextXAlignment.Left
title.Text = "BintangKiller"
title.Parent = top

local function topBtn(txt, x)
    local b = Instance.new("TextButton")
    b.Size = UDim2.fromOffset(28, 28)
    b.Position = UDim2.new(1, x, 0.5, -14)
    b.BackgroundColor3 = C.row
    b.Text = txt
    b.Font = Enum.Font.GothamBold
    b.TextSize = 16
    b.TextColor3 = C.text
    b.AutoButtonColor = false
    b.Parent = top
    corner(b, 8)
    return b
end
local btnMin = topBtn("−", -64)
local btnClose = topBtn("×", -32)

-- Tabs: Survivor | Killer
local tabBar = Instance.new("Frame")
tabBar.Size = UDim2.new(1, -20, 0, 28)
tabBar.Position = UDim2.fromOffset(10, 46)
tabBar.BackgroundTransparency = 1
tabBar.Parent = win

local pages = {}
local tabBtns = {}
local function makePage(name)
    local sc = Instance.new("ScrollingFrame")
    sc.Name = name
    sc.Size = UDim2.new(1, -20, 1, -86)
    sc.Position = UDim2.fromOffset(10, 80)
    sc.BackgroundTransparency = 1
    sc.BorderSizePixel = 0
    sc.ScrollBarThickness = 3
    sc.ScrollBarImageColor3 = C.accent
    sc.CanvasSize = UDim2.fromOffset(0, 0)
    sc.Visible = false
    sc.Parent = win
    pages[name] = sc
    return sc
end
makePage("Survivor")
makePage("Killer")

local function showTab(name)
    for n, p in pairs(pages) do p.Visible = (n == name) end
    for n, b in pairs(tabBtns) do
        b.BackgroundColor3 = (n == name) and C.accent or C.row
        b.TextColor3 = (n == name) and Color3.new(1,1,1) or C.muted
    end
end

for i, name in ipairs({"Survivor", "Killer"}) do
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0.5, -4, 1, 0)
    b.Position = UDim2.new((i - 1) * 0.5, i == 2 and 4 or 0, 0, 0)
    b.BackgroundColor3 = C.row
    b.Text = name
    b.Font = Enum.Font.GothamBold
    b.TextSize = 12
    b.TextColor3 = C.muted
    b.AutoButtonColor = false
    b.Parent = tabBar
    corner(b, 7)
    tabBtns[name] = b
    b.MouseButton1Click:Connect(function() showTab(name) end)
end

local function pad(page)
    local y = 4
    local function ny(h)
        local c = y
        y = y + h + 6
        page.CanvasSize = UDim2.fromOffset(0, y + 10)
        return c
    end
    local function section(text)
        local l = Instance.new("TextLabel")
        l.BackgroundTransparency = 1
        l.Size = UDim2.new(1, 0, 0, 16)
        l.Position = UDim2.fromOffset(0, ny(16))
        l.Font = Enum.Font.GothamBold
        l.TextSize = 11
        l.TextColor3 = C.accent
        l.TextXAlignment = Enum.TextXAlignment.Left
        l.Text = text
        l.Parent = page
    end
    local function note(text, h)
        local l = Instance.new("TextLabel")
        l.BackgroundTransparency = 1
        l.Size = UDim2.new(1, 0, 0, h or 36)
        l.Position = UDim2.fromOffset(0, ny(h or 36))
        l.Font = Enum.Font.Gotham
        l.TextSize = 10
        l.TextColor3 = C.muted
        l.TextXAlignment = Enum.TextXAlignment.Left
        l.TextYAlignment = Enum.TextYAlignment.Top
        l.TextWrapped = true
        l.Text = text
        l.Parent = page
    end
    local function addToggle(key, label)
        local yy = ny(32)
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, 0, 0, 32)
        row.Position = UDim2.fromOffset(0, yy)
        row.BackgroundColor3 = C.row
        row.BorderSizePixel = 0
        row.Parent = page
        corner(row, 8)
        local lbl = Instance.new("TextLabel")
        lbl.BackgroundTransparency = 1
        lbl.Position = UDim2.fromOffset(10, 0)
        lbl.Size = UDim2.new(1, -52, 1, 0)
        lbl.Font = Enum.Font.Gotham
        lbl.TextSize = 12
        lbl.TextColor3 = C.text
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.Text = label
        lbl.Parent = row
        local track = Instance.new("TextButton")
        track.Size = UDim2.fromOffset(38, 20)
        track.Position = UDim2.new(1, -46, 0.5, -10)
        track.BackgroundColor3 = S[key] and C.on or C.off
        track.Text = ""
        track.AutoButtonColor = false
        track.Parent = row
        corner(track, 10)
        local knob = Instance.new("Frame")
        knob.Size = UDim2.fromOffset(16, 16)
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
    local function addSlider(label, get, set, minV, maxV)
        local yy = ny(36)
        local lbl = Instance.new("TextLabel")
        lbl.BackgroundTransparency = 1
        lbl.Size = UDim2.new(1, 0, 0, 14)
        lbl.Position = UDim2.fromOffset(0, yy)
        lbl.Font = Enum.Font.Gotham
        lbl.TextSize = 11
        lbl.TextColor3 = C.muted
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.Text = label .. "  " .. tostring(get())
        lbl.Parent = page
        local bar = Instance.new("Frame")
        bar.Size = UDim2.new(1, 0, 0, 8)
        bar.Position = UDim2.fromOffset(0, yy + 16)
        bar.BackgroundColor3 = C.row
        bar.BorderSizePixel = 0
        bar.Parent = page
        corner(bar, 4)
        local a0 = math.clamp((get() - minV) / (maxV - minV), 0, 1)
        local fill = Instance.new("Frame")
        fill.Size = UDim2.new(a0, 0, 1, 0)
        fill.BackgroundColor3 = C.accent
        fill.BorderSizePixel = 0
        fill.Parent = bar
        corner(fill, 4)
        local knob = Instance.new("TextButton")
        knob.Size = UDim2.fromOffset(14, 14)
        knob.AnchorPoint = Vector2.new(0.5, 0.5)
        knob.Position = UDim2.new(a0, 0, 0.5, 0)
        knob.BackgroundColor3 = Color3.new(1, 1, 1)
        knob.Text = ""
        knob.AutoButtonColor = false
        knob.Parent = bar
        corner(knob, 7)
        local sliding = false
        local function apply(x)
            local a = math.clamp((x - bar.AbsolutePosition.X) / math.max(bar.AbsoluteSize.X, 1), 0, 1)
            local v = math.floor(minV + a * (maxV - minV) + 0.5)
            set(v)
            fill.Size = UDim2.new(a, 0, 1, 0)
            knob.Position = UDim2.new(a, 0, 0.5, 0)
            lbl.Text = label .. "  " .. tostring(v)
        end
        knob.InputBegan:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then sliding = true end
        end)
        bar.InputBegan:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
                sliding = true; apply(i.Position.X)
            end
        end)
        UserInputService.InputEnded:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then sliding = false end
        end)
        UserInputService.InputChanged:Connect(function(i)
            if sliding and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
                apply(i.Position.X)
            end
        end)
    end
    return { section = section, note = note, addToggle = addToggle, addSlider = addSlider }
end

-- SURVIVOR (atas)
pcall(function()
    local u = pad(pages.Survivor)
    u.section("COMBAT")
    u.addToggle("AutoParry", "Enable Parry")
    u.addToggle("ParryAggressive", "Aggressive")
    u.addToggle("ShowParryRadius", "Show Radius")
    u.addToggle("ParryFloating", "Floating Parry Button")
    u.addToggle("SpearPrediction", "Spear Veil Prediction")
    u.section("SILENT PISTOL")
    u.addToggle("SilentPistol", "Silent Pistol")
    u.addToggle("PistolLaser", "Laser")
    u.addToggle("PistolPredict", "Predict")
    u.addSlider("Pistol FOV", function() return S.PistolFOV end, function(v) S.PistolFOV = v end, 40, 400)
    u.addToggle("ShowItemESP", "Item Tracker")
    u.addSlider("Parry distance", function() return S.ParryDist end, function(v) S.ParryDist = v end, 6, 25)
    u.note("Auto parry saat killer masuk jarak / ngejar (logic Ganz).", 40)
end)

-- KILLER
do
    local u = pad(pages.Killer)
    u.section("LOCK")
    u.addToggle("Frenzy", "Frenzy Lock")
    u.addToggle("SilentVeil", "Silent Veil")
    u.addToggle("Hidden", "Hidden Mark / S1")
    u.section("TRACKER VEIL")
    u.addToggle("ShowTracker", "Show Tracker")
    u.note("Garis ke target = arah tombak silent. Kalo line nempel di badan survi → kemungkinan kena. Kalau lewat / jauh → miss.", 56)
    u.section("VISUAL")
    u.addToggle("ShowESP", "ESP Labels")
    u.addToggle("ShowFOV", "Show FOV")
    u.addToggle("ShowCross", "Crosshair")
    u.section("RANGE")
    u.addSlider("FOV", function() return S.FOV end, function(v) S.FOV = v end, 40, 300)
    u.addSlider("Lock range", function() return S.MaxDist end, function(v) S.MaxDist = v end, 15, 120)
    u.addSlider("Veil range", function() return S.VeilRange end, function(v) S.VeilRange = v end, 50, 350)
    u.addSlider("Hidden range", function() return S.HiddenRange end, function(v) S.HiddenRange = v end, 15, 80)
end

showTab("Killer")

-- icon
local iconGui = Instance.new("ScreenGui")
iconGui.Name = "BintangKillerIcon"
iconGui.ResetOnSpawn = false
iconGui.Enabled = false
pcall(function() iconGui.Parent = _gethui and _gethui() or CoreGui end)
if not iconGui.Parent then iconGui.Parent = CoreGui end
local icon = Instance.new("ImageButton")
icon.Size = UDim2.fromOffset(44, 44)
icon.Position = UDim2.new(0, 12, 0.45, 0)
icon.BackgroundColor3 = C.top
icon.Image = LOGO_IMAGE
icon.ScaleType = Enum.ScaleType.Fit
icon.AutoButtonColor = false
icon.Parent = iconGui
corner(icon, 22)
local ist = Instance.new("UIStroke")
ist.Color = C.accent
ist.Thickness = 1.5
ist.Parent = icon

btnMin.MouseButton1Click:Connect(function()
    win.Visible = false
    iconGui.Enabled = true
end)
btnClose.MouseButton1Click:Connect(function()
    gui.Enabled = false
    iconGui.Enabled = false
end)
icon.MouseButton1Click:Connect(function()
    win.Visible = true
    iconGui.Enabled = false
end)

do
    local drag, start, pos
    top.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            drag = true; start = i.Position; pos = win.Position
            i.Changed:Connect(function() if i.UserInputState == Enum.UserInputState.End then drag = false end end)
        end
    end)
    UserInputService.InputChanged:Connect(function(i)
        if drag and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
            local d = i.Position - start
            win.Position = UDim2.new(pos.X.Scale, pos.X.Offset + d.X, pos.Y.Scale, pos.Y.Offset + d.Y)
        end
    end)
end
do
    local drag, start, pos
    icon.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            drag = true; start = i.Position; pos = icon.Position
            i.Changed:Connect(function() if i.UserInputState == Enum.UserInputState.End then drag = false end end)
        end
    end)
    UserInputService.InputChanged:Connect(function(i)
        if drag and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
            local d = i.Position - start
            icon.Position = UDim2.new(pos.X.Scale, pos.X.Offset + d.X, pos.Y.Scale, pos.Y.Offset + d.Y)
        end
    end)
end


-- Floating Parry ON/OFF button
do
    local floatGui = Instance.new("ScreenGui")
    floatGui.Name = "BintangParryFloat"
    floatGui.ResetOnSpawn = false
    floatGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    pcall(function() floatGui.Parent = _gethui and _gethui() or CoreGui end)
    if not floatGui.Parent then floatGui.Parent = CoreGui end

    local btn = Instance.new("TextButton")
    btn.Name = "ParryFloat"
    btn.Size = UDim2.fromOffset(72, 72)
    btn.Position = UDim2.new(1, -90, 0.55, 0)
    btn.BackgroundColor3 = S.AutoParry and Color3.fromRGB(80, 220, 130) or Color3.fromRGB(45, 40, 58)
    btn.Text = S.AutoParry and "PARRY\nON" or "PARRY\nOFF"
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 13
    btn.TextColor3 = Color3.new(1, 1, 1)
    btn.AutoButtonColor = false
    btn.Parent = floatGui
    corner(btn, 16)
    local st = Instance.new("UIStroke")
    st.Color = S.AutoParry and Color3.fromRGB(80, 220, 130) or C.accentDim
    st.Thickness = 2
    st.Parent = btn

    local function refresh()
        local on = S.AutoParry
        btn.BackgroundColor3 = on and Color3.fromRGB(80, 220, 130) or Color3.fromRGB(45, 40, 58)
        btn.Text = on and "PARRY\nON" or "PARRY\nOFF"
        st.Color = on and Color3.fromRGB(80, 220, 130) or C.accentDim
        floatGui.Enabled = S.ParryFloating == true
    end

    btn.MouseButton1Click:Connect(function()
        S.AutoParry = not S.AutoParry
        refresh()
    end)

    -- drag
    do
        local drag, start, pos
        btn.InputBegan:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
                drag = true; start = i.Position; pos = btn.Position
                i.Changed:Connect(function()
                    if i.UserInputState == Enum.UserInputState.End then drag = false end
                end)
            end
        end)
        UserInputService.InputChanged:Connect(function(i)
            if drag and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
                local d = i.Position - start
                btn.Position = UDim2.new(pos.X.Scale, pos.X.Offset + d.X, pos.Y.Scale, pos.Y.Offset + d.Y)
            end
        end)
    end

    RunService.Heartbeat:Connect(function()
        floatGui.Enabled = S.ParryFloating == true
        -- keep text in sync if toggled from main UI
        local want = S.AutoParry and "PARRY\nON" or "PARRY\nOFF"
        if btn.Text ~= want then refresh() end
    end)

    refresh()
end

print("[BintangKiller] Survivor(AutoParry) | Killer · Tracker Veil = arah tombak")


-- ===== ITEM ESP (auto detect tool di tangan) =====
local ITEM_ICONS = {
    ["Parrying Dagger"] = "⚔",
    ["Flashlight"] = "🔦",
    ["Medkit"] = "➕",
    ["Toolbox"] = "🔧",
    ["Map"] = "🗺",
    ["Key"] = "🔑",
}
local itemEspBox = {}

local function getEquippedItem(char)
    if not char then return nil end
    -- Tool in character
    for _, c in ipairs(char:GetChildren()) do
        if c:IsA("Tool") then return c.Name end
    end
    -- sometimes held as model
    local hand = char:FindFirstChild("RightHand") or char:FindFirstChild("Right Arm")
    if hand then
        for _, c in ipairs(hand:GetChildren()) do
            if c:IsA("Tool") or c:IsA("Model") then
                local n = c.Name
                if n ~= "" and n ~= "Handle" then return n end
            end
        end
    end
    -- backpack equipped attribute
    return char:GetAttribute("HeldItem") or char:GetAttribute("EquippedItem")
end

RunService.RenderStepped:Connect(function()
    if not S.ShowItemESP then
        for _, g in pairs(itemEspBox) do if g then g.Enabled = false end end
        return
    end
    ensureVisual()
    local camPos = Camera.CFrame.Position
    for _, plr in ipairs(Players:GetPlayers()) do
        if isSurvivor(plr) and alive(plr) then
            local char = plr.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            if hrp then
                local itemName = getEquippedItem(char)
                local bill = itemEspBox[plr]
                if not bill or not bill.Parent then
                    bill = Instance.new("BillboardGui")
                    bill.Name = "BKItem_" .. plr.Name
                    bill.AlwaysOnTop = true
                    bill.Size = UDim2.fromOffset(160, 36)
                    bill.StudsOffset = Vector3.new(0, 4.6, 0)
                    bill.Adornee = hrp
                    bill.Parent = ESPFolder or CoreGui
                    local lbl = Instance.new("TextLabel")
                    lbl.Name = "Item"
                    lbl.BackgroundTransparency = 1
                    lbl.Size = UDim2.fromScale(1, 1)
                    lbl.Font = Enum.Font.GothamBold
                    lbl.TextSize = 13
                    lbl.TextStrokeTransparency = 0.4
                    lbl.TextColor3 = Color3.fromRGB(200, 180, 255)
                    lbl.TextXAlignment = Enum.TextXAlignment.Center
                    lbl.Parent = bill
                    itemEspBox[plr] = bill
                end
                bill.Adornee = hrp
                local dist = math.floor((hrp.Position - camPos).Magnitude + 0.5)
                local lbl = bill:FindFirstChild("Item")
                if itemName and itemName ~= "" then
                    bill.Enabled = true
                    local icon = ITEM_ICONS[itemName] or "•"
                    if lbl then
                        lbl.Text = string.format("%s  %s\n%dm", icon, itemName, dist)
                        -- highlight parry dagger
                        if itemName:lower():find("parry") or itemName:lower():find("dagger") then
                            lbl.TextColor3 = Color3.fromRGB(180, 120, 255)
                        elseif itemName:lower():find("flash") then
                            lbl.TextColor3 = Color3.fromRGB(255, 230, 120)
                        else
                            lbl.TextColor3 = Color3.fromRGB(200, 180, 255)
                        end
                    end
                else
                    bill.Enabled = false
                end
            elseif itemEspBox[plr] then
                itemEspBox[plr].Enabled = false
            end
        elseif itemEspBox[plr] then
            itemEspBox[plr].Enabled = false
        end
    end
end)


-- ===== SPEAR VEIL PREDICTION (arc mirip video) =====
do
    local predGui = Instance.new("ScreenGui")
    predGui.Name = "BintangSpearArc"
    predGui.IgnoreGuiInset = true
    predGui.ResetOnSpawn = false
    predGui.DisplayOrder = 50
    pcall(function() predGui.Parent = _gethui and _gethui() or CoreGui end)
    if not predGui.Parent then predGui.Parent = CoreGui end

    local worldFolder = Instance.new("Folder")
    worldFolder.Name = "BintangSpearWorld"
    pcall(function() worldFolder.Parent = workspace.CurrentCamera end)
    if not worldFolder.Parent then worldFolder.Parent = workspace end

    local segs = {}
    local landRing = nil
    local silBill = nil

    local function clear()
        for _, s in ipairs(segs) do s:Destroy() end
        for i=#segs,1,-1 do segs[i]=nil end
        if landRing then landRing:Destroy(); landRing = nil end
        if silBill then silBill:Destroy(); silBill = nil end
    end

    local function makeSeg(a, b, col, thick)
        local mid = (a + b) * 0.5
        local len = (b - a).Magnitude
        if len < 0.05 then return end
        local p = Instance.new("Part")
        p.Anchored = true
        p.CanCollide = false
        p.CanQuery = false
        p.CanTouch = false
        p.CastShadow = false
        p.Material = Enum.Material.Neon
        p.Color = col
        p.Size = Vector3.new(thick or 0.055, thick or 0.055, len)
        p.CFrame = CFrame.new(mid, b)
        p.Transparency = 0.08
        p.Parent = worldFolder
        table.insert(segs, p)
    end

    local function drawLanding(pos, danger)
        local ring = Instance.new("Part")
        ring.Anchored = true
        ring.CanCollide = false
        ring.CanQuery = false
        ring.CanTouch = false
        ring.CastShadow = false
        ring.Shape = Enum.PartType.Cylinder
        ring.Material = Enum.Material.Neon
        ring.Color = danger and Color3.fromRGB(255, 40, 40) or Color3.fromRGB(255, 255, 255)
        ring.Size = Vector3.new(0.12, danger and 4 or 2.8, danger and 4 or 2.8)
        ring.CFrame = CFrame.new(pos + Vector3.new(0, 0.06, 0)) * CFrame.Angles(0, 0, math.rad(90))
        ring.Transparency = 0.25
        ring.Parent = worldFolder
        landRing = ring
    end

    local function drawSilhouette(plr, danger)
        if not plr or not plr.Character then return end
        local hrp = plr.Character:FindFirstChild("HumanoidRootPart")
        if not hrp then return end
        local bill = Instance.new("BillboardGui")
        bill.AlwaysOnTop = true
        bill.Size = UDim2.fromOffset(70, 90)
        bill.StudsOffset = Vector3.new(0, 1.5, 0)
        bill.Adornee = hrp
        bill.Parent = predGui
        local img = Instance.new("TextLabel")
        img.BackgroundTransparency = 1
        img.Size = UDim2.fromScale(1, 1)
        img.Font = Enum.Font.GothamBold
        img.TextSize = 48
        img.Text = "👤"
        img.TextColor3 = danger and Color3.fromRGB(255, 50, 80) or Color3.fromRGB(255, 180, 180)
        img.TextTransparency = 0.15
        img.Parent = bill
        silBill = bill
    end

    local function sampleArc(origin, velocity)
        local g = Vector3.new(0, -96.05, 0)
        local pts = {}
        local pos, vel = origin, velocity
        local dt = 0.04
        local land = nil
        for i = 1, 100 do
            table.insert(pts, pos)
            local nextPos = pos + vel * dt + 0.5 * g * dt * dt
            local nextVel = vel + g * dt
            local ray = workspace:Raycast(pos, nextPos - pos)
            if ray then
                table.insert(pts, ray.Position)
                land = ray.Position
                break
            end
            if nextPos.Y < origin.Y - 150 then
                table.insert(pts, nextPos)
                land = nextPos
                break
            end
            pos, vel = nextPos, nextVel
        end
        return pts, land
    end

    local function findFlyingSpear()
        for _, obj in ipairs(workspace:GetDescendants()) do
            if obj:IsA("BasePart") and not obj.Anchored then
                local n = string.lower(obj.Name)
                if n:find("spear") or n:find("projectile") or n:find("veilthrow") or n:find("throwable") then
                    local v = obj.AssemblyLinearVelocity
                    if v.Magnitude > 35 then
                        return obj, v
                    end
                end
            end
        end
        return nil
    end

    if S.SpearPrediction == nil then S.SpearPrediction = true end
    local lastClear = 0

    RunService.RenderStepped:Connect(function()
        if not S.SpearPrediction then
            if #segs > 0 or landRing or silBill then clear() end
            return
        end

        local myRoot = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
        local spear, vel = findFlyingSpear()

        if spear and vel then
            local pts, land = sampleArc(spear.Position, vel)
            clear()
            local danger = false
            if myRoot and land and (land - myRoot.Position).Magnitude < 18 then
                danger = true
            end
            local col = danger and Color3.fromRGB(255, 45, 45) or Color3.fromRGB(255, 255, 255)
            for i = 1, #pts - 1 do
                makeSeg(pts[i], pts[i + 1], col, danger and 0.09 or 0.055)
            end
            if land then drawLanding(land, danger) end
            lastClear = tick()
            return
        end

        local char = LP.Character
        if char and char:GetAttribute("spearmode") == true and S.SilentVeil then
            local hrp = char:FindFirstChild("HumanoidRootPart")
            local hand = char:FindFirstChild("RightHand") or char:FindFirstChild("Right Arm") or hrp
            if hand then
                local tgtPlr, tgtPos = getLockTarget(S.VeilRange)
                if tgtPos then
                    local origin = hand.Position
                    local dir = tgtPos - origin
                    local flat = Vector3.new(dir.X, 0, dir.Z)
                    local speed = 180
                    local g = 96.05
                    local D = math.max(flat.Magnitude, 0.1)
                    local dy = dir.Y
                    local s2 = speed * speed
                    local disc = s2 * s2 - g * (g * D * D + 2 * dy * s2)
                    if disc < 0 then disc = 0 end
                    local theta = math.atan((s2 - math.sqrt(disc)) / (g * D))
                    local vel2
                    if flat.Magnitude > 0.1 then
                        vel2 = flat.Unit * (speed * math.cos(theta)) + Vector3.new(0, speed * math.sin(theta), 0)
                    else
                        vel2 = dir.Unit * speed
                    end
                    local pts, land = sampleArc(origin, vel2)
                    clear()
                    local col = Color3.fromRGB(255, 220, 90)
                    for i = 1, #pts - 1 do
                        makeSeg(pts[i], pts[i + 1], col, 0.06)
                    end
                    if land then drawLanding(land, false) end
                    if tgtPlr then drawSilhouette(tgtPlr, false) end
                    lastClear = tick()
                    return
                end
            end
        end

        if tick() - lastClear > 0.35 then
            clear()
        end
    end)
end

end

-- FORCE_UI_VISIBLE
pcall(function()
    local g = (_gethui and _gethui() or CoreGui):FindFirstChild("BintangKiller")
        or (LP:FindFirstChild("PlayerGui") and LP.PlayerGui:FindFirstChild("BintangKiller"))
    if g then
        g.Enabled = true
        local main = g:FindFirstChild("Main") or g:FindFirstChildWhichIsA("Frame")
        if main then main.Visible = true end
        print("[BintangKiller] force visible ok")
    else
        warn("[BintangKiller] gui not found after build")
    end
end)
