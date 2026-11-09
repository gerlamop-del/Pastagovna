-- FuzerV2 | Rayfield UI + Drawing ESP + Hook-based SilentAim
-- Fixed: UI creation moved to end, added unique flags, fixed Hitbox callback

-- Сначала грузим библиотеку безопасно
local success, Rayfield = pcall(function()
    return loadstring(game:HttpGet("https://github.com/UnknownDeveloper-sqd/UnknownSquad-RayField-Lib/raw/refs/heads/main/Rayfield/CustomRayfield.luau"))()
end)

if not success or not Rayfield then
    return warn("Ошибка загрузки Rayfield UI. Проверь интернет или инжектор.")
end

local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local UserInputService  = game:GetService("UserInputService")
local Lighting          = game:GetService("Lighting")
local CollectionService = game:GetService("CollectionService")
local Camera            = workspace.CurrentCamera
local LocalPlayer       = Players.LocalPlayer

local IsTouchDevice = UserInputService.TouchEnabled

-- ================= SETTINGS =================
local Settings = {
    Aimbot = {
        Enabled = true, Key = "MouseButton2", MobileMode = "Auto",
        FOV = 150, FOVColor = Color3.fromRGB(0, 255, 120), Smoothness = 0.30,
        TargetPart = "Head", TeamCheck = true, WallCheck = false,
        Prediction = 0.15, PredictionMode = "Smoothed", VelocitySmooth = 0.35,
        ShowFOV = true, ShowAimTracer = false,
    },
    SilentAim = {
        Enabled = false, TeamCheck = true, TargetPart = "Head",
        FOV = 300, ShowFOV = false, FOVColor = Color3.fromRGB(255, 100, 100),
        Prediction = 0.04, Gravity = true, Melee = true,
    },
    ESP = {
        Enabled = true, Boxes = true, BoxStyle = "2D Box",
        BoxColor = Color3.fromRGB(0, 255, 120), BoxTransparency = 1, BoxThickness = 1,
        Names = true, NameColor = Color3.fromRGB(255, 255, 255), TextSize = 13,
        Health = true, HealthColor = Color3.fromRGB(0, 255, 120),
        Distance = true, DistanceColor = Color3.fromRGB(200, 200, 200),
        Tracers = false, TracerColor = Color3.fromRGB(0, 255, 120),
        TeamCheck = true, MaxDistance = 1500,
    },
    Chams = { Enabled = true, Color = Color3.fromRGB(255, 50, 50), Transparency = 0.3, TeamCheck = true },
    FastZoom = { Enabled = false, ZoomFOV = 40 },
    Hitbox = { Enabled = false, Size = 2, ShowVisual = false },
    Appearance = {
        HandsEnabled = false, HandsMode = "Solid",
        HandsColor = Color3.fromRGB(0, 200, 255), HandsSpeed = 1,
        SkyEnabled = false, SkyMode = "Solid",
        SkyColor = Color3.fromRGB(120, 160, 255), SkySpeed = 1,
    },
}

local ESPCache, ChamsCache, VelocityCache = {}, {}, {}
local HitboxCache = {}
local AimTarget = nil
local aimingViaButton = false
local HandsOrigColors, HandsOrigMaterials, HandsLights = {}, {}, {}
local SkyBackup = nil

local HAND_PARTS = {
    "Left Arm", "Right Arm", "LeftHand", "RightHand",
    "LeftLowerArm", "RightLowerArm", "LeftUpperArm", "RightUpperArm",
}

local newc = newcclosure or function(f) return f end
local check = checkcaller or function() return false end

-- =====================================================================
-- ФУНКЦИИ (Объявлены ДО меню, чтобы меню их видело)
-- =====================================================================

-- ================= HITBOX =================
local function clearHitbox(player)
    local s = HitboxCache[player]
    if not s then return end
    if s.head and s.head.Parent then
        pcall(function()
            s.head.Size = s.origSize
            s.head.CanCollide = s.origCanCollide
            s.head.Massless = s.origMassless
            s.head.Transparency = s.origTransparency
        end)
    end
    if s.extra and s.extra.Parent then pcall(function() s.extra:Destroy() end) end
    HitboxCache[player] = nil
end

local function ensureHitbox(player)
    if player == LocalPlayer then return end
    local char = player.Character
    if not char then clearHitbox(player); return end
    local head = char:FindFirstChild("Head")
    if not head or not head:IsA("BasePart") then return end
    local s = HitboxCache[player]
    if s and (s.head ~= head or s.char ~= char) then clearHitbox(player); s = nil end
    if not s then
        s = { char = char, head = head,
            origSize = head.Size, origCanCollide = head.CanCollide,
            origMassless = head.Massless, origTransparency = head.Transparency, extra = nil }
        HitboxCache[player] = s
    end
    local mult = Settings.Hitbox.Size
    local targetSize = s.origSize * mult
    if head.Size ~= targetSize then
        head.Size = targetSize
        head.CanCollide = false
        head.Massless = true
        head.Transparency = Settings.Hitbox.ShowVisual and 0.5 or s.origTransparency
    end
    if not s.extra or not s.extra.Parent then
        local extra = Instance.new("Part")
        extra.Name = "Head"
        extra.Size = targetSize
        extra.CFrame = head.CFrame
        extra.Transparency = Settings.Hitbox.ShowVisual and 0.5 or 1
        extra.Color = Color3.fromRGB(255,50,50)
        extra.Material = Enum.Material.Neon
        extra.CanCollide = false
        extra.CanTouch = true
        extra.CanQuery = true
        extra.Massless = true
        extra.Anchored = true
        extra.Locked = true
        extra.Parent = char
        s.extra = extra
    else
        s.extra.Size = targetSize
        s.extra.CFrame = head.CFrame
        s.extra.Transparency = Settings.Hitbox.ShowVisual and 0.5 or 1
    end
end

function applyHitboxAll()
    if not Settings.Hitbox.Enabled then
        for _, p in ipairs(Players:GetPlayers()) do clearHitbox(p) end
        return
    end
    for _, p in ipairs(Players:GetPlayers()) do ensureHitbox(p) end
end

-- ================= APPEARANCE =================
local function getHandsColor(baseColor, t)
    local mode = Settings.Appearance.HandsMode
    if mode == "Rainbow" or mode == "Rainbow Glow" then
        return Color3.fromHSV((t * Settings.Appearance.HandsSpeed * 0.3) % 1, 1, 1)
    end
    return baseColor
end

function applyHandsColor()
    local char = LocalPlayer.Character
    if not char then return end
    local mode = Settings.Appearance.HandsMode
    local isGlow = (mode == "Glow" or mode == "Rainbow Glow")
    local t = tick()
    for _, name in ipairs(HAND_PARTS) do
        local part = char:FindFirstChild(name)
        if part and part:IsA("BasePart") then
            if not HandsOrigColors[part] then
                HandsOrigColors[part] = part.Color
                HandsOrigMaterials[part] = part.Material
            end
            if HandsLights[part] then HandsLights[part]:Destroy(); HandsLights[part] = nil end
            if Settings.Appearance.HandsEnabled then
                local newColor = getHandsColor(Settings.Appearance.HandsColor, t)
                part.Color = newColor
                if isGlow then
                    part.Material = Enum.Material.Neon
                    local light = Instance.new("PointLight")
                    light.Color = newColor
                    light.Brightness = 3
                    light.Range = 8
                    light.Parent = part
                    HandsLights[part] = light
                else
                    part.Material = HandsOrigMaterials[part] or Enum.Material.Plastic
                end
            else
                part.Color = HandsOrigColors[part] or part.Color
                part.Material = HandsOrigMaterials[part] or part.Material
            end
        end
    end
end

function applySkyColor()
    if Settings.Appearance.SkyEnabled then
        if not SkyBackup then
            local atm = Lighting:FindFirstChildOfClass("Atmosphere")
            if atm then
                SkyBackup = { obj = atm, Color = atm.Color, Decay = atm.Decay, Density = atm.Density, Haze = atm.Haze }
            else
                SkyBackup = { created = true }
                local newAtm = Instance.new("Atmosphere")
                newAtm.Density = 0.3; newAtm.Offset = 0.25; newAtm.Glare = 0; newAtm.Haze = 0
                newAtm.Parent = Lighting
                SkyBackup.obj = newAtm
            end
        end
        local atm = SkyBackup.obj
        if atm then
            local mode = Settings.Appearance.SkyMode
            local t = tick()
            if mode == "Rainbow" then
                local rc = Color3.fromHSV((t * Settings.Appearance.SkySpeed * 0.3) % 1, 0.7, 1)
                atm.Color = rc; atm.Decay = rc
            elseif mode == "Pulse" then
                local pulse = (math.sin(t * Settings.Appearance.SkySpeed * 2) + 1) / 2
                local base = Settings.Appearance.SkyColor
                atm.Color = base:Lerp(Color3.new(1,1,1), pulse * 0.5)
                atm.Decay = base:Lerp(Color3.new(1,1,1), pulse * 0.5)
            else
                atm.Color = Settings.Appearance.SkyColor
                atm.Decay = Settings.Appearance.SkyColor
            end
        end
    else
        if SkyBackup then
            if SkyBackup.created and SkyBackup.obj then SkyBackup.obj:Destroy()
            elseif SkyBackup.obj then
                SkyBackup.obj.Color = SkyBackup.Color
                SkyBackup.obj.Decay = SkyBackup.Decay
                SkyBackup.obj.Density = SkyBackup.Density
                SkyBackup.obj.Haze = SkyBackup.Haze
            end
            SkyBackup = nil
        end
    end
end

LocalPlayer.CharacterAdded:Connect(function()
    task.wait(0.5)
    HandsOrigColors, HandsOrigMaterials, HandsLights = {}, {}, {}
    if Settings.Appearance.HandsEnabled then applyHandsColor() end
end)

-- ================= TARGETS =================
local function hasGunEquipped()
    local c = LocalPlayer.Character
    if not c then return false end
    local tool = c:FindFirstChildWhichIsA("Tool")
    return tool and (tool:FindFirstChild("ClientGun") ~= nil or tool:GetAttribute("GunName") ~= nil)
end

local function getCrosshair()
    local vp = Camera and Camera.ViewportSize or Vector2.new(800,600)
    if UserInputService.TouchEnabled or not UserInputService.MouseEnabled
    or UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter then
        return Vector2.new(vp.X * 0.5, vp.Y * 0.5)
    end
    return UserInputService:GetMouseLocation()
end

local function getMeleeTarget()
    local c = LocalPlayer.Character
    local root = c and c:FindFirstChild("HumanoidRootPart")
    if not root then return nil end
    local best, minD = nil, 72
    local rPos = root.Position
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then
            local char = p.Character
            local hum = char and char:FindFirstChild("Humanoid")
            local head = char and char:FindFirstChild("Head")
            if head and hum and hum.Health > 0 then
                local dx = rPos.X - head.Position.X
                local dy = rPos.Y - head.Position.Y
                local dz = rPos.Z - head.Position.Z
                local dSq = dx*dx + dy*dy + dz*dz
                if dSq < minD then minD = dSq; best = head end
            end
        end
    end
    return best
end

local function getGunTarget()
    if not Camera then return nil end
    local vp = Camera.ViewportSize
    local maxDist = math.min(vp.X, vp.Y) * 0.4
    local curPos = getCrosshair()
    local best = nil

    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then
            if not (Settings.SilentAim.TeamCheck and p.Team == LocalPlayer.Team) then
                local char = p.Character
                local hum = char and char:FindFirstChild("Humanoid")
                local part = char and (char:FindFirstChild(Settings.SilentAim.TargetPart) or char:FindFirstChild("Head"))
                if part and hum and hum.Health > 0 then
                    local sPos = Camera:WorldToViewportPoint(part.Position)
                    if sPos.Z > 0 then
                        local dx = sPos.X - curPos.X
                        local dy = sPos.Y - curPos.Y
                        local d = math.sqrt(dx*dx + dy*dy)
                        if d < maxDist then maxDist = d; best = part end
                    end
                end
            end
        end
    end

    local drones = CollectionService:GetTagged("BriskRuntimeSentinel")
    for _, d in ipairs(drones) do
        if d:IsDescendantOf(workspace) and d:GetAttribute("SentinelDead") ~= true then
            local part = d:FindFirstChild("BodyHitBox") or d.PrimaryPart or d:FindFirstChildWhichIsA("BasePart")
            if part then
                local sPos = Camera:WorldToViewportPoint(part.Position)
                if sPos.Z > 0 then
                    local dx = sPos.X - curPos.X
                    local dy = sPos.Y - curPos.Y
                    local d2 = math.sqrt(dx*dx + dy*dy)
                    if d2 < maxDist then maxDist = d2; best = part end
                end
            end
        end
    end
    return best
end

-- ================= ESP DRAWING =================
local function createESP(player)
    if player == LocalPlayer or ESPCache[player] then return end
    local e = {}
    e.Box = Drawing.new("Square"); e.Box.Filled = false; e.Box.Visible = false
    e.BoxFill = Drawing.new("Square"); e.BoxFill.Filled = true; e.BoxFill.Visible = false
    e.CornerLines = {}
    for i = 1, 8 do
        local line = Drawing.new("Line"); line.Thickness = 1; line.Visible = false
        e.CornerLines[i] = line
    end
    e.Name = Drawing.new("Text"); e.Name.Center = true; e.Name.Outline = true; e.Name.Visible = false
    e.Health = Drawing.new("Text"); e.Health.Outline = true; e.Health.Visible = false
    e.Distance = Drawing.new("Text"); e.Distance.Center = true; e.Distance.Outline = true; e.Distance.Visible = false
    e.Tracer = Drawing.new("Line"); e.Tracer.Thickness = 1; e.Tracer.Visible = false
    ESPCache[player] = e
end

local function removeESP(player)
    local e = ESPCache[player]
    if not e then return end
    for k, v in pairs(e) do
        if k ~= "CornerLines" then pcall(function() v:Remove() end) end
    end
    for _, l in ipairs(e.CornerLines) do pcall(function() l:Remove() end) end
    ESPCache[player] = nil
end

local function hideESP(e)
    e.Box.Visible = false; e.BoxFill.Visible = false
    e.Name.Visible = false; e.Health.Visible = false
    e.Distance.Visible = false; e.Tracer.Visible = false
    for _, l in ipairs(e.CornerLines) do l.Visible = false end
end

local function drawCornerBox(e, x, y, w, h)
    local len = math.min(w, h) * 0.25
    local corners = {
        {x, y, x + len, y},         {x, y, x, y + len},
        {x + w, y, x + w - len, y}, {x + w, y, x + w, y + len},
        {x, y + h, x + len, y + h}, {x, y + h, x, y + h - len},
        {x + w, y + h, x + w - len, y + h}, {x + w, y + h, x + w, y + h - len}
    }
    for i, c in ipairs(corners) do
        local l = e.CornerLines[i]
        l.From = Vector2.new(c[1], c[2]); l.To = Vector2.new(c[3], c[4])
        l.Color = Settings.ESP.BoxColor
        l.Thickness = Settings.ESP.BoxThickness
        l.Transparency = Settings.ESP.BoxTransparency
        l.Visible = true
    end
end

local function updateESP()
    for player, e in pairs(ESPCache) do
        local char = player.Character
        if not Settings.ESP.Enabled or not char then hideESP(e); continue end
        if Settings.ESP.TeamCheck and player.Team == LocalPlayer.Team then hideESP(e); continue end
        local hum = char:FindFirstChildOfClass("Humanoid")
        local root = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Head")
        if not hum or not root or hum.Health <= 0 then hideESP(e); continue end
        local dist = (Camera.CFrame.Position - root.Position).Magnitude
        if dist > Settings.ESP.MaxDistance then hideESP(e); continue end
        local sp, onScreen = Camera:WorldToViewportPoint(root.Position)
        if not onScreen then hideESP(e); continue end
        local head = char:FindFirstChild("Head")
        local top = head and Camera:WorldToViewportPoint(head.Position + Vector3.new(0,1,0)) or sp
        local bot = Camera:WorldToViewportPoint(root.Position - Vector3.new(0,3,0))
        local h = math.abs(top.Y - bot.Y)
        local w = h * 0.5
        local x, y = sp.X - w/2, sp.Y - h/2

        e.Box.Visible = false; e.BoxFill.Visible = false
        for _, l in ipairs(e.CornerLines) do l.Visible = false end

        if Settings.ESP.Boxes then
            if Settings.ESP.BoxStyle == "2D Box" then
                e.Box.Size = Vector2.new(w, h); e.Box.Position = Vector2.new(x, y)
                e.Box.Color = Settings.ESP.BoxColor
                e.Box.Thickness = Settings.ESP.BoxThickness
                e.Box.Transparency = Settings.ESP.BoxTransparency
                e.Box.Visible = true
            elseif Settings.ESP.BoxStyle == "Filled Box" then
                e.BoxFill.Size = Vector2.new(w, h); e.BoxFill.Position = Vector2.new(x, y)
                e.BoxFill.Color = Settings.ESP.BoxColor
                e.BoxFill.Transparency = math.max(0.3, Settings.ESP.BoxTransparency * 0.6)
                e.BoxFill.Visible = true
                e.Box.Size = Vector2.new(w, h); e.Box.Position = Vector2.new(x, y)
                e.Box.Color = Settings.ESP.BoxColor
                e.Box.Thickness = Settings.ESP.BoxThickness
                e.Box.Transparency = Settings.ESP.BoxTransparency
                e.Box.Visible = true
            elseif Settings.ESP.BoxStyle == "Corner Box" then
                drawCornerBox(e, x, y, w, h)
            end
        end

        e.Name.Text = player.Name; e.Name.Size = Settings.ESP.TextSize
        e.Name.Color = Settings.ESP.NameColor
        e.Name.Position = Vector2.new(sp.X, y - Settings.ESP.TextSize - 2)
        e.Name.Visible = Settings.ESP.Names

        e.Health.Text = math.floor(hum.Health).."/"..math.floor(hum.MaxHealth)
        e.Health.Size = math.max(Settings.ESP.TextSize - 2, 9)
        e.Health.Color = Settings.ESP.HealthColor
        e.Health.Position = Vector2.new(x - 38, y)
        e.Health.Visible = Settings.ESP.Health

        e.Distance.Text = math.floor(dist).."m"
        e.Distance.Size = math.max(Settings.ESP.TextSize - 2, 9)
        e.Distance.Color = Settings.ESP.DistanceColor
        e.Distance.Position = Vector2.new(sp.X, y + h + 3)
        e.Distance.Visible = Settings.ESP.Distance

        if Settings.ESP.Tracers then
            e.Tracer.From = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y)
            e.Tracer.To = Vector2.new(sp.X, sp.Y)
            e.Tracer.Color = Settings.ESP.TracerColor
            e.Tracer.Visible = true
        else
            e.Tracer.Visible = false
        end
    end
end

-- ================= CHAMS =================
local function applyChams(player)
    if player == LocalPlayer then return end
    if not Settings.Chams.Enabled
    or (Settings.Chams.TeamCheck and player.Team == LocalPlayer.Team) then
        local h = ChamsCache[player]
        if h then h:Destroy(); ChamsCache[player] = nil end
        return
    end
    local char = player.Character
    if not char then return end
    local h = ChamsCache[player]
    if h and h.Parent == char then
        h.FillColor = Settings.Chams.Color
        h.FillTransparency = Settings.Chams.Transparency
        return
    end
    if h then h:Destroy() end
    local hl = Instance.new("Highlight")
    hl.Name = "FuzerChams"; hl.Adornee = char
    hl.FillColor = Settings.Chams.Color
    hl.FillTransparency = Settings.Chams.Transparency
    hl.OutlineColor = Color3.new(1,1,1); hl.OutlineTransparency = 0.5
    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    hl.Parent = char
    ChamsCache[player] = hl
end

-- ================= SILENT AIM HOOKS =================
local oldNamecall, oldIndex

local GUN_REMOTES = { GunFire = true, Fire = true, FireWeapon = true, Shoot = true, ProjectileFire = true }
local MELEE_REMOTES = { HammerMeleeRemote = true, MeleeAttack = true, Attack = true, Swing = true }

local function namecallHook(self, ...)
    if check() then return oldNamecall(self, ...) end
    local rawMethod = getnamecallmethod and getnamecallmethod()
    local method = rawMethod and rawMethod:lower() or ""

    if method == "fireserver" and Settings.SilentAim.Enabled then
        if GUN_REMOTES[self.Name] then
            local target = getGunTarget()
            if target then
                local weaponName, origin, _, timeStamp = ...
                if typeof(origin) == "Vector3" then
                    local dist = (target.Position - origin).Magnitude
                    local t = dist / 700
                    local grav = (Settings.SilentAim.Gravity and workspace.Gravity > 0) and workspace.Gravity or 0
                    local drop = 0.5 * grav * t * t
                    local vel = target.AssemblyLinearVelocity or Vector3.zero
                    local aimPos = target.Position + vel * (Settings.SilentAim.Prediction + t) + Vector3.new(0, drop, 0)
                    local newDir = (aimPos - origin).Unit
                    if setnamecallmethod and rawMethod then setnamecallmethod(rawMethod) end
                    return oldNamecall(self, weaponName, origin, newDir, timeStamp)
                end
            end
        elseif Settings.SilentAim.Melee and MELEE_REMOTES[self.Name] then
            local target = getMeleeTarget()
            if target then
                local toolName, origin, _, timeStamp = ...
                if typeof(origin) == "Vector3" then
                    local vel = target.AssemblyLinearVelocity or Vector3.zero
                    local newDir = (target.Position + vel * 0.04 - origin).Unit
                    if setnamecallmethod and rawMethod then setnamecallmethod(rawMethod) end
                    return oldNamecall(self, toolName, origin, newDir, timeStamp)
                end
            end
        end
    end

    if setnamecallmethod and rawMethod then setnamecallmethod(rawMethod) end
    return oldNamecall(self, ...)
end

local function indexHook(self, key)
    if not check() and Settings.SilentAim.Enabled
    and (key == "Hit" or key == "Target") and hasGunEquipped() and self:IsA("Mouse") then
        local target = getGunTarget()
        if target then
            return (key == "Hit" and CFrame.new(target.Position)) or target
        end
    end
    return oldIndex(self, key)
end

pcall(function()
    if hookmetamethod then
        oldNamecall = hookmetamethod(game, "__namecall", newc(namecallHook))
        oldIndex = hookmetamethod(game, "__index", newc(indexHook))
    else
        local mt = getrawmetatable(game)
        oldNamecall = mt.__namecall
        oldIndex = mt.__index
        setreadonly(mt, false)
        mt.__namecall = newc(namecallHook)
        mt.__index = newc(indexHook)
        setreadonly(mt, true)
    end
end)

-- ================= AIMBOT & FOV =================
local fovDraw = Drawing.new("Circle")
fovDraw.NumSides = 60; fovDraw.Thickness = 1.5; fovDraw.Filled = false
fovDraw.Color = Settings.Aimbot.FOVColor; fovDraw.Visible = false

local aimTracerDraw = Drawing.new("Line")
aimTracerDraw.Thickness = 1; aimTracerDraw.Color = Settings.Aimbot.FOVColor
aimTracerDraw.Visible = false

local silentFovDraw = Drawing.new("Circle")
silentFovDraw.NumSides = 60; silentFovDraw.Thickness = 1.5; silentFovDraw.Filled = false
silentFovDraw.Color = Settings.SilentAim.FOVColor; silentFovDraw.Visible = false

local function getPredictedPosition(player, part, velocity)
    local pred = Settings.Aimbot.Prediction
    if pred <= 0 then return part.Position end
    if velocity.Magnitude < 1 then return part.Position end
    if Settings.Aimbot.PredictionMode == "Simple" then
        return part.Position + velocity * pred
    end
    local last = VelocityCache[player]
    if not last then VelocityCache[player] = velocity; return part.Position + velocity * pred end
    if (velocity - last).Magnitude > 200 then
        VelocityCache[player] = velocity; return part.Position + velocity * pred
    end
    local smoothed = last:Lerp(velocity, Settings.Aimbot.VelocitySmooth)
    VelocityCache[player] = smoothed
    return part.Position + smoothed * pred
end

local KeyMap = {
    MouseButton1 = Enum.UserInputType.MouseButton1,
    MouseButton2 = Enum.UserInputType.MouseButton2,
    Q = Enum.KeyCode.Q, E = Enum.KeyCode.E, F = Enum.KeyCode.F,
}

local function isKeyHeld()
    local key = Settings.Aimbot.Key
    if key == "MouseButton1" or key == "MouseButton2" then
        return UserInputService:IsMouseButtonPressed(KeyMap[key])
    else
        return UserInputService:IsKeyDown(KeyMap[key])
    end
end

local function getClosest()
    local closest, shortest = nil, Settings.Aimbot.FOV
    local center
    if IsTouchDevice then
        center = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)
    else
        center = UserInputService:GetMouseLocation()
    end
    for _, p in ipairs(Players:GetPlayers()) do
        if p == LocalPlayer then continue end
        if Settings.Aimbot.TeamCheck and p.Team == LocalPlayer.Team then continue end
        local char = p.Character
        if not char then continue end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not hum or hum.Health <= 0 then continue end
        local part = char:FindFirstChild(Settings.Aimbot.TargetPart)
        if not part then continue end
        local root = char:FindFirstChild("HumanoidRootPart")
        local vel = root and root.AssemblyLinearVelocity or Vector3.zero
        local predicted = getPredictedPosition(p, part, vel)
        local sp, onScreen = Camera:WorldToViewportPoint(predicted)
        if not onScreen then continue end
        local d = (Vector2.new(sp.X, sp.Y) - center).Magnitude
        if d < shortest then
            if Settings.Aimbot.WallCheck then
                local ray = Ray.new(Camera.CFrame.Position, part.Position - Camera.CFrame.Position)
                if workspace:FindPartOnRayWithIgnoreList(ray, {LocalPlayer.Character, char}) then continue end
            end
            shortest = d
            closest = { player = p, part = part, velocity = vel }
        end
    end
    return closest
end

local function aimAt(t)
    if not t or not t.part or not t.part.Parent then return end
    local predicted = getPredictedPosition(t.player, t.part, t.velocity)
    Camera.CFrame = Camera.CFrame:Lerp(
        CFrame.new(Camera.CFrame.Position, predicted),
        Settings.Aimbot.Smoothness
    )
end

-- ================= FAST ZOOM =================
local zoomState = { pressing = false, returning = false, baseFOV = Camera.FieldOfView }

UserInputService.InputBegan:Connect(function(input, gp)
    if gp or IsTouchDevice then return end
    if input.KeyCode == Enum.KeyCode.Z and Settings.FastZoom.Enabled then
        if not zoomState.pressing then
            zoomState.baseFOV = Camera.FieldOfView
            zoomState.pressing = true
            zoomState.returning = false
        end
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if IsTouchDevice then return end
    if input.KeyCode == Enum.KeyCode.Z then
        if zoomState.pressing then
            zoomState.pressing = false
            zoomState.returning = true
        end
    end
end)

-- =====================================================================
-- СОЗДАНИЕ МЕНЮ (Теперь в самом конце, когда все функции готовы)
-- =====================================================================

local Window = Rayfield:CreateWindow({
    Name = "FuzerV2 | Brisk Surv",
    LoadingTitle = "FuzerV2",
    LoadingSubtitle = "By KAI",
    Theme = "Amethyst",
    Width = 460,
    Height = 360,
    Font = "Code",
    ConfigurationSaving = { Enabled = false },
    KeySystem = false,
})

local AimTab    = Window:CreateTab("Aimbot", 4483362458)
local SilentTab = Window:CreateTab("Silent", 4483362458)
local ESPTab    = Window:CreateTab("ESP", 4483362458)
local ChamsTab  = Window:CreateTab("Chams", 4483362458)
local MiscTab   = Window:CreateTab("Misc", 4483362458)
local AppTab    = Window:CreateTab("Appearance", 4483362458)

-- ============ AIMBOT ============
AimTab:CreateSection("Core")
AimTab:CreateToggle({ Name = "Aimbot Enabled", Flag = "Aim_Enabled", CurrentValue = Settings.Aimbot.Enabled,
    Callback = function(v) Settings.Aimbot.Enabled = v end })
AimTab:CreateToggle({ Name = "Show FOV Circle", Flag = "Aim_ShowFOV", CurrentValue = Settings.Aimbot.ShowFOV,
    Callback = function(v) Settings.Aimbot.ShowFOV = v end })
AimTab:CreateToggle({ Name = "Show Aim Tracer", Flag = "Aim_Tracer", CurrentValue = Settings.Aimbot.ShowAimTracer,
    Callback = function(v) Settings.Aimbot.ShowAimTracer = v end })

AimTab:CreateSection("Targeting")
AimTab:CreateDropdown({ Name = "Target Part", Flag = "Aim_Part",
    Options = {"Head","Torso","UpperTorso","LowerTorso","HumanoidRootPart"},
    CurrentOption = Settings.Aimbot.TargetPart,
    Callback = function(v) Settings.Aimbot.TargetPart = v end })
AimTab:CreateDropdown({ Name = "Aim Key", Flag = "Aim_Key",
    Options = {"MouseButton2","MouseButton1","Q","E","F"},
    CurrentOption = Settings.Aimbot.Key,
    Callback = function(v) Settings.Aimbot.Key = v end })

AimTab:CreateSection("Tuning")
AimTab:CreateSlider({ Name = "FOV Range", Flag = "Aim_FOV", Range = {40, 500}, Increment = 5,
    CurrentValue = Settings.Aimbot.FOV, Callback = function(v) Settings.Aimbot.FOV = v end })
AimTab:CreateSlider({ Name = "Smoothness %", Flag = "Aim_Smooth", Range = {1, 100}, Increment = 1,
    CurrentValue = math.floor(Settings.Aimbot.Smoothness * 100),
    Callback = function(v) Settings.Aimbot.Smoothness = v / 100 end })

AimTab:CreateSection("Prediction")
AimTab:CreateSlider({ Name = "Predict Time (ms)", Flag = "Aim_Pred", Range = {0, 500}, Increment = 10,
    CurrentValue = math.floor(Settings.Aimbot.Prediction * 1000),
    Callback = function(v) Settings.Aimbot.Prediction = v / 1000 end })
AimTab:CreateDropdown({ Name = "Mode", Flag = "Aim_PredMode", Options = {"Simple","Smoothed"},
    CurrentOption = Settings.Aimbot.PredictionMode,
    Callback = function(v) Settings.Aimbot.PredictionMode = v end })
AimTab:CreateSlider({ Name = "Velocity Smooth %", Flag = "Aim_VelSmooth", Range = {5, 95}, Increment = 5,
    CurrentValue = math.floor(Settings.Aimbot.VelocitySmooth * 100),
    Callback = function(v) Settings.Aimbot.VelocitySmooth = v / 100 end })

AimTab:CreateSection("Filters")
AimTab:CreateToggle({ Name = "Team Check", Flag = "Aim_Team", CurrentValue = Settings.Aimbot.TeamCheck,
    Callback = function(v) Settings.Aimbot.TeamCheck = v end })
AimTab:CreateToggle({ Name = "Wall Check", Flag = "Aim_Wall", CurrentValue = Settings.Aimbot.WallCheck,
    Callback = function(v) Settings.Aimbot.WallCheck = v end })

AimTab:CreateSection("Mobile")
AimTab:CreateDropdown({ Name = "Mobile Mode", Flag = "Aim_MobileMode", Options = {"Auto","Hold Button","Off"},
    CurrentOption = Settings.Aimbot.MobileMode,
    Callback = function(v) Settings.Aimbot.MobileMode = v end })

-- ============ SILENT ============
SilentTab:CreateSection("Silent Aim (Hook-based)")
SilentTab:CreateToggle({ Name = "Silent Aim Enabled", Flag = "Sil_Enabled", CurrentValue = Settings.SilentAim.Enabled,
    Callback = function(v) Settings.SilentAim.Enabled = v end })
SilentTab:CreateToggle({ Name = "Team Check", Flag = "Sil_Team", CurrentValue = Settings.SilentAim.TeamCheck,
    Callback = function(v) Settings.SilentAim.TeamCheck = v end })
SilentTab:CreateToggle({ Name = "Show FOV", Flag = "Sil_ShowFOV", CurrentValue = Settings.SilentAim.ShowFOV,
    Callback = function(v) Settings.SilentAim.ShowFOV = v end })

SilentTab:CreateSection("Targeting")
SilentTab:CreateDropdown({ Name = "Target Part", Flag = "Sil_Part",
    Options = {"Head","Torso","UpperTorso","LowerTorso","HumanoidRootPart"},
    CurrentOption = Settings.SilentAim.TargetPart,
    Callback = function(v) Settings.SilentAim.TargetPart = v end })

SilentTab:CreateSection("Prediction / Ballistics")
SilentTab:CreateSlider({ Name = "Predict (×0.01s)", Flag = "Sil_Pred", Range = {0, 20}, Increment = 1,
    CurrentValue = math.floor(Settings.SilentAim.Prediction * 100),
    Callback = function(v) Settings.SilentAim.Prediction = v / 100 end })
SilentTab:CreateToggle({ Name = "Gravity Drop", Flag = "Sil_Gravity", CurrentValue = Settings.SilentAim.Gravity,
    Callback = function(v) Settings.SilentAim.Gravity = v end })
SilentTab:CreateToggle({ Name = "Melee Silent", Flag = "Sil_Melee", CurrentValue = Settings.SilentAim.Melee,
    Callback = function(v) Settings.SilentAim.Melee = v end })

-- ============ ESP ============
ESPTab:CreateSection("General")
ESPTab:CreateToggle({ Name = "ESP Enabled", Flag = "Esp_Enabled", CurrentValue = Settings.ESP.Enabled,
    Callback = function(v) Settings.ESP.Enabled = v end })
ESPTab:CreateToggle({ Name = "Team Check", Flag = "Esp_Team", CurrentValue = Settings.ESP.TeamCheck,
    Callback = function(v) Settings.ESP.TeamCheck = v end })
ESPTab:CreateSlider({ Name = "Max Distance", Flag = "Esp_Dist", Range = {100, 5000}, Increment = 50,
    CurrentValue = Settings.ESP.MaxDistance, Callback = function(v) Settings.ESP.MaxDistance = v end })
ESPTab:CreateSlider({ Name = "Text Size", Flag = "Esp_TextSize", Range = {8, 20}, Increment = 1,
    CurrentValue = Settings.ESP.TextSize, Callback = function(v) Settings.ESP.TextSize = v end })

ESPTab:CreateSection("Boxes")
ESPTab:CreateToggle({ Name = "Show Boxes", Flag = "Esp_Boxes", CurrentValue = Settings.ESP.Boxes,
    Callback = function(v) Settings.ESP.Boxes = v end })
ESPTab:CreateDropdown({ Name = "Box Style", Flag = "Esp_BoxStyle", Options = {"2D Box","Corner Box","Filled Box"},
    CurrentOption = Settings.ESP.BoxStyle, Callback = function(v) Settings.ESP.BoxStyle = v end })
ESPTab:CreateSlider({ Name = "Thickness", Flag = "Esp_Thick", Range = {1, 4}, Increment = 1,
    CurrentValue = Settings.ESP.BoxThickness, Callback = function(v) Settings.ESP.BoxThickness = v end })
ESPTab:CreateSlider({ Name = "Transparency %", Flag = "Esp_Transp", Range = {0, 100}, Increment = 5,
    CurrentValue = math.floor(Settings.ESP.BoxTransparency * 100),
    Callback = function(v) Settings.ESP.BoxTransparency = v / 100 end })
ESPTab:CreateColorPicker({ Name = "Box Color", Flag = "Esp_BoxColor", Color = Settings.ESP.BoxColor,
    Callback = function(c) Settings.ESP.BoxColor = c end })

ESPTab:CreateSection("Elements")
ESPTab:CreateToggle({ Name = "Names", Flag = "Esp_Names", CurrentValue = Settings.ESP.Names,
    Callback = function(v) Settings.ESP.Names = v end })
ESPTab:CreateColorPicker({ Name = "Name Color", Flag = "Esp_NameColor", Color = Settings.ESP.NameColor,
    Callback = function(c) Settings.ESP.NameColor = c end })
ESPTab:CreateToggle({ Name = "Health", Flag = "Esp_Health", CurrentValue = Settings.ESP.Health,
    Callback = function(v) Settings.ESP.Health = v end })
ESPTab:CreateColorPicker({ Name = "Health Color", Flag = "Esp_HealthColor", Color = Settings.ESP.HealthColor,
    Callback = function(c) Settings.ESP.HealthColor = c end })
ESPTab:CreateToggle({ Name = "Distance", Flag = "Esp_Distance", CurrentValue = Settings.ESP.Distance,
    Callback = function(v) Settings.ESP.Distance = v end })
ESPTab:CreateToggle({ Name = "Tracers", Flag = "Esp_Tracers", CurrentValue = Settings.ESP.Tracers,
    Callback = function(v) Settings.ESP.Tracers = v end })
ESPTab:CreateColorPicker({ Name = "Tracer Color", Flag = "Esp_TracerColor", Color = Settings.ESP.TracerColor,
    Callback = function(c) Settings.ESP.TracerColor = c end })

-- ============ CHAMS ============
ChamsTab:CreateToggle({ Name = "Chams Enabled", Flag = "Chams_Enabled", CurrentValue = Settings.Chams.Enabled,
    Callback = function(v) Settings.Chams.Enabled = v end })
ChamsTab:CreateToggle({ Name = "Team Check", Flag = "Chams_Team", CurrentValue = Settings.Chams.TeamCheck,
    Callback = function(v) Settings.Chams.TeamCheck = v end })
ChamsTab:CreateSlider({ Name = "Transparency %", Flag = "Chams_Transp", Range = {0, 100}, Increment = 5,
    CurrentValue = math.floor(Settings.Chams.Transparency * 100),
    Callback = function(v) Settings.Chams.Transparency = v / 100 end })
ChamsTab:CreateColorPicker({ Name = "Chams Color", Flag = "Chams_Color", Color = Settings.Chams.Color,
    Callback = function(c) Settings.Chams.Color = c end })

-- ============ MISC ============
MiscTab:CreateSection("Fast Zoom (Hold Z on PC)")
MiscTab:CreateToggle({ Name = "Fast Zoom Enabled", Flag = "Zoom_Enabled", CurrentValue = Settings.FastZoom.Enabled,
    Callback = function(v) Settings.FastZoom.Enabled = v end })
MiscTab:CreateSlider({ Name = "Zoom FOV", Flag = "Zoom_FOV", Range = {20, 80}, Increment = 1,
    CurrentValue = Settings.FastZoom.ZoomFOV, Callback = function(v) Settings.FastZoom.ZoomFOV = v end })

MiscTab:CreateSection("Head Hitbox")
MiscTab:CreateToggle({ Name = "Hitbox Enabled", Flag = "Hitbox_Enabled", CurrentValue = Settings.Hitbox.Enabled,
    Callback = function(v) Settings.Hitbox.Enabled = v; applyHitboxAll() end })
MiscTab:CreateToggle({ Name = "Show Visual", Flag = "Hitbox_Visual", CurrentValue = Settings.Hitbox.ShowVisual,
    Callback = function(v) Settings.Hitbox.ShowVisual = v; applyHitboxAll() end })
MiscTab:CreateDropdown({ Name = "Size", Flag = "Hitbox_Size",
    Options = {"1.5x","2x","3x","4x","5x","6x","7x","8x"},
    CurrentOption = tostring(Settings.Hitbox.Size).."x",
    Callback = function(v)
        Settings.Hitbox.Size = tonumber(v:gsub("x","")) or 2
        applyHitboxAll()
    end })

-- ============ APPEARANCE ============
AppTab:CreateSection("Hands")
AppTab:CreateToggle({ Name = "Hands Enabled", Flag = "App_HandsEn", CurrentValue = Settings.Appearance.HandsEnabled,
    Callback = function(v) Settings.Appearance.HandsEnabled = v; applyHandsColor() end })
AppTab:CreateDropdown({ Name = "Hands Mode", Flag = "App_HandsMode", Options = {"Solid","Rainbow","Glow","Rainbow Glow"},
    CurrentOption = Settings.Appearance.HandsMode,
    Callback = function(v) Settings.Appearance.HandsMode = v; applyHandsColor() end })
AppTab:CreateColorPicker({ Name = "Hands Color", Flag = "App_HandsCol", Color = Settings.Appearance.HandsColor,
    Callback = function(c) Settings.Appearance.HandsColor = c end })
AppTab:CreateSlider({ Name = "Rainbow Speed (×0.1)", Flag = "App_HandsSpd", Range = {1, 50}, Increment = 1,
    CurrentValue = math.floor(Settings.Appearance.HandsSpeed * 10),
    Callback = function(v) Settings.Appearance.HandsSpeed = v / 10 end })

AppTab:CreateSection("Sky")
AppTab:CreateToggle({ Name = "Sky Enabled", Flag = "App_SkyEn", CurrentValue = Settings.Appearance.SkyEnabled,
    Callback = function(v) Settings.Appearance.SkyEnabled = v; applySkyColor() end })
AppTab:CreateDropdown({ Name = "Sky Mode", Flag = "App_SkyMode", Options = {"Solid","Rainbow","Pulse"},
    CurrentOption = Settings.Appearance.SkyMode,
    Callback = function(v) Settings.Appearance.SkyMode = v; applySkyColor() end })
AppTab:CreateColorPicker({ Name = "Sky Color", Flag = "App_SkyCol", Color = Settings.Appearance.SkyColor,
    Callback = function(c) Settings.Appearance.SkyColor = c end })
AppTab:CreateSlider({ Name = "Sky Speed (×0.1)", Flag = "App_SkySpd", Range = {1, 50}, Increment = 1,
    CurrentValue = math.floor(Settings.Appearance.SkySpeed * 10),
    Callback = function(v) Settings.Appearance.SkySpeed = v / 10 end })

-- ================= MOBILE AIM BUTTON =================
if IsTouchDevice then
    local guiParent = (gethui and gethui()) or game:GetService("CoreGui")
    local aimGui = Instance.new("ScreenGui")
    aimGui.Name = "FuzerAimBtn"
    aimGui.ResetOnSpawn = false
    aimGui.Parent = guiParent

    local aimBtn = Instance.new("TextButton")
    aimBtn.Size = UDim2.new(0, 84, 0, 84)
    aimBtn.Position = UDim2.new(1, -110, 0.62, -42)
    aimBtn.BackgroundColor3 = Color3.fromRGB(0, 200, 120)
    aimBtn.BackgroundTransparency = 0.35
    aimBtn.Text = "AIM"
    aimBtn.TextColor3 = Color3.new(1,1,1)
    aimBtn.Font = Enum.Font.GothamBold
    aimBtn.TextSize = 16
    aimBtn.Parent = aimGui
    local uc = Instance.new("UICorner", aimBtn); uc.CornerRadius = UDim.new(1,0)

    aimBtn.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            aimingViaButton = true
            aimBtn.BackgroundTransparency = 0.1
        end
    end)
    aimBtn.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            aimingViaButton = false
            aimBtn.BackgroundTransparency = 0.35
        end
    end)
end

-- ================= MAIN LOOPS =================
RunService.RenderStepped:Connect(function()
    pcall(updateESP)
    for _, p in ipairs(Players:GetPlayers()) do pcall(applyChams, p) end

    if not IsTouchDevice and Settings.FastZoom.Enabled then
        if zoomState.pressing then
            Camera.FieldOfView = Camera.FieldOfView + (Settings.FastZoom.ZoomFOV - Camera.FieldOfView) * 0.3
        elseif zoomState.returning then
            Camera.FieldOfView = Camera.FieldOfView + (zoomState.baseFOV - Camera.FieldOfView) * 0.3
            if math.abs(Camera.FieldOfView - zoomState.baseFOV) < 0.3 then
                Camera.FieldOfView = zoomState.baseFOV
                zoomState.returning = false
            end
        end
    end

    if Settings.Aimbot.Enabled and Settings.Aimbot.ShowFOV then
        fovDraw.Visible = true
        fovDraw.Position = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)
        fovDraw.Radius = Settings.Aimbot.FOV
        fovDraw.Color = AimTarget and Color3.fromRGB(255, 80, 80) or Settings.Aimbot.FOVColor
    else fovDraw.Visible = false end

    if Settings.SilentAim.Enabled and Settings.SilentAim.ShowFOV then
        silentFovDraw.Visible = true
        silentFovDraw.Position = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)
        silentFovDraw.Radius = Settings.SilentAim.FOV
        silentFovDraw.Color = Settings.SilentAim.FOVColor
    else silentFovDraw.Visible = false end

    local shouldAim = false
    if Settings.Aimbot.Enabled then
        if IsTouchDevice and Settings.Aimbot.MobileMode == "Auto" then shouldAim = true end
        if Settings.Aimbot.MobileMode == "Hold Button" and aimingViaButton then shouldAim = true end
        if isKeyHeld() then shouldAim = true end
    end

    if shouldAim then
        local t = getClosest()
        if t then
            AimTarget = t.player
            aimAt(t)
            if Settings.Aimbot.ShowAimTracer then
                local sp = Camera:WorldToViewportPoint(t.part.Position)
                aimTracerDraw.From = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)
                aimTracerDraw.To = Vector2.new(sp.X, sp.Y)
                aimTracerDraw.Color = Settings.Aimbot.FOVColor
                aimTracerDraw.Visible = true
            else aimTracerDraw.Visible = false end
        else AimTarget = nil; aimTracerDraw.Visible = false end
    else AimTarget = nil; aimTracerDraw.Visible = false end
end)

RunService.Heartbeat:Connect(function()
    if Settings.Hitbox.Enabled then
        for _, p in ipairs(Players:GetPlayers()) do pcall(ensureHitbox, p) end
    end
    if Settings.Appearance.HandsEnabled then pcall(applyHandsColor) end
    if Settings.Appearance.SkyEnabled then pcall(applySkyColor) end
end)

-- ================= PLAYER MGMT =================
local function onPlayerAdded(p)
    pcall(createESP, p)
    pcall(applyChams, p)
    p.CharacterAdded:Connect(function()
        task.wait(0.3)
        if Settings.Chams.Enabled then pcall(applyChams, p) end
        if ESPCache[p] then hideESP(ESPCache[p]) end
        VelocityCache[p] = nil
        clearHitbox(p)
    end)
    p.CharacterRemoving:Connect(function() clearHitbox(p) end)
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(function(p)
    pcall(removeESP, p)
    local h = ChamsCache[p]; if h then h:Destroy(); ChamsCache[p] = nil end
    VelocityCache[p] = nil
    clearHitbox(p)
end)
for _, p in ipairs(Players:GetPlayers()) do onPlayerAdded(p) end
