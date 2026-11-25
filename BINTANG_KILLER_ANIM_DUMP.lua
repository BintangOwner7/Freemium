--[[
  Bintang — ALL Killers Animation Dumper (VD)
  Watch semua player → log anim non-idle
  Jadi survivor juga bisa rekam anim killer yang ngejar
]]

local Players = game:GetService("Players")
local LP = Players.LocalPlayer

local SKIP = {
    idle = true, walk = true, run = true, jump = true, fall = true,
    climb = true, swim = true, sit = true, land = true,
}

local collected = {} -- [animationId] = {name, from}

local function shouldSkip(name)
    local n = string.lower(tostring(name or ""))
    for k in pairs(SKIP) do
        if n:find(k, 1, true) then return true end
    end
    return false
end

local function isLikelyKiller(plr)
    if plr == LP then
        -- local: cek team/attr
    end
    if LP.Team and plr.Team and LP.Team ~= plr.Team then
        return true
    end
    local role = plr:GetAttribute("Role") or plr:GetAttribute("role") or plr:GetAttribute("TeamRole")
    if role then
        local r = string.lower(tostring(role))
        if r:find("kill") then return true end
        if r:find("surv") or r:find("civil") then return false end
    end
    -- fallback: treat non-same-team / unknown as interesting
    return plr ~= LP or true
end

local function printTable()
    print("-------- TABLE SIAP COPY --------")
    print("local KILLER_ANIMS = {")
    for id, info in pairs(collected) do
        print(string.format('    ["%s"] = "%s", -- from %s', id, info.name, info.from))
    end
    print("}")
    print("---------------------------------")
end

local function log(plr, track)
    local anim = track.Animation
    local id = anim and anim.AnimationId or nil
    if not id then return end
    local name = (anim and anim.Name) or track.Name or "?"
    if shouldSkip(name) or shouldSkip(track.Name) then return end
    if collected[id] then return end

    collected[id] = {name = name, from = plr.Name}

    print("======== ANIM ========")
    print("Player    :", plr.DisplayName or plr.Name, "(" .. plr.Name .. ")")
    print("Name      :", name)
    print("Track     :", track.Name)
    print("AnimationId:", id)
    print("Length    :", string.format("%.2f", track.Length or 0))
    print("Speed     :", track.Speed)
    printTable()
end

local watching = {}

local function watchChar(plr, char)
    if not char then return end
    task.spawn(function()
        local hum = char:WaitForChild("Humanoid", 8)
        if not hum then return end
        local animator = hum:FindFirstChildOfClass("Animator")
        if not animator then
            pcall(function() animator = hum:WaitForChild("Animator", 5) end)
        end
        if not animator then return end

        local conn = animator.AnimationPlayed:Connect(function(track)
            pcall(log, plr, track)
        end)

        for _, t in ipairs(animator:GetPlayingAnimationTracks()) do
            pcall(log, plr, t)
        end

        -- tool log
        char.ChildAdded:Connect(function(c)
            if c:IsA("Tool") then
                print("[Tool]", plr.Name, "→", c.Name)
            end
        end)

        print("[Bintang] Watching:", plr.Name)
    end)
end

local function hookPlayer(plr)
    if watching[plr] then return end
    watching[plr] = true
    if plr.Character then watchChar(plr, plr.Character) end
    plr.CharacterAdded:Connect(function(char)
        watchChar(plr, char)
    end)
end

for _, plr in ipairs(Players:GetPlayers()) do
    hookPlayer(plr)
end
Players.PlayerAdded:Connect(hookPlayer)

print("==========================================")
print(" Bintang ALL-Killers Anim Dump")
print(" - Watch SEMUA player di server")
print(" - Swing/skill killer → F9 / Console")
print(" - Bisa survivor: biarkan killer serang")
print("==========================================")
