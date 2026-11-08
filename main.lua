-- FuzerV2 | Fast Survival
-- + Appearance v2 (Rainbow / Glow / Pulse)
-- Silent Aim + Aimbot + ESP + Chams + Hitbox + Fast Zoom

local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local UserInputService  = game:GetService("UserInputService")
local Lighting          = game:GetService("Lighting")
local Camera            = workspace.CurrentCamera
local LocalPlayer       = Players.LocalPlayer

local IsTouchDevice = UserInputService.TouchEnabled
local IsMobile      = IsTouchDevice and not UserInputService.MouseEnabled

local ALPHA = { menu = 0.12, header = 0.18, panel = 0.22, widget = 0.26 }

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
        FOV = 250, Bind = "Always",
        ShowFOV = false, FOVColor = Color3.fromRGB(255, 100, 100)
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
    Hitbox   = { Enabled = false, Size = 2, ShowVisual = false },
    Appearance = {
        HandsEnabled = false,
        HandsMode    = "Solid",           -- Solid / Rainbow / Glow / Rainbow Glow
        HandsColor   = Color3.fromRGB(0, 200, 255),
        HandsSpeed   = 1,                 -- скорость rainbow (0.1 - 5)
        SkyEnabled   = false,
        SkyMode      = "Solid",           -- Solid / Rainbow / Pulse
        SkyColor     = Color3.fromRGB(120, 160, 255),
        SkySpeed     = 1,
    },
    Menu     = { Open = true, Key = Enum.KeyCode.K, Key2 = Enum.KeyCode.RightShift },
}

local ESPCache, ChamsCache, VelocityCache = {}, {}, {}
local HitboxCache = {}
local AimTarget = nil
local SilentTarget = nil
local aimingViaButton = false
local hookMouseOK = false
local hookRayOK = false
local SkyBackup = nil

local HAND_PARTS = {
    "Left Arm", "Right Arm",
    "LeftHand", "RightHand",
    "LeftLowerArm", "RightLowerArm",
    "LeftUpperArm", "RightUpperArm",
}

-- Для rainbow
local rainbowTime = 0
local skyTime = 0

-- ================= THEME =================
local C = {
    BG = Color3.fromRGB(15, 15, 20), BG2 = Color3.fromRGB(24, 24, 32),
    BG3 = Color3.fromRGB(45, 45, 55), BG4 = Color3.fromRGB(55, 55, 68),
    Accent = Color3.fromRGB(0, 220, 130), Text = Color3.fromRGB(225, 225, 235),
    Sub = Color3.fromRGB(150, 150, 165), Danger = Color3.fromRGB(255, 80, 80),
    AimBtn = Color3.fromRGB(0, 200, 120),
}

local function corner(obj, r)
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, r); c.Parent = obj; return c
end

local vp = Camera.ViewportSize
local menuWidth  = math.min(440, math.floor(vp.X * 0.92))
local menuHeight = math.min(540, math.floor(vp.Y * 0.88))

-- ================= ROOT =================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "FuzerV2_Menu"
ScreenGui.ResetOnSpawn = false
ScreenGui.IgnoreGuiInset = true
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.DisplayOrder = 999
ScreenGui.Parent = game:GetService("CoreGui")

local OpenBtn = Instance.new("TextButton")
OpenBtn.Size = UDim2.new(0, 60, 0, 60)
OpenBtn.Position = UDim2.new(0, 15, 0, 150)
OpenBtn.BackgroundColor3 = C.BG2; OpenBtn.BackgroundTransparency = 0.1
OpenBtn.Text = "FZ2"; OpenBtn.TextColor3 = C.Accent
OpenBtn.Font = Enum.Font.GothamBold; OpenBtn.TextSize = 15
OpenBtn.AutoButtonColor = true; OpenBtn.Visible = IsMobile; OpenBtn.ZIndex = 1000
OpenBtn.Parent = ScreenGui
corner(OpenBtn, 30)
local obs = Instance.new("UIStroke", OpenBtn); obs.Color = C.Accent; obs.Thickness = 1.5

local Menu = Instance.new("Frame")
Menu.Size = UDim2.new(0, menuWidth, 0, menuHeight)
Menu.Position = UDim2.new(0.5, -math.floor(menuWidth/2), 0.5, -math.floor(menuHeight/2))
Menu.BackgroundColor3 = C.BG; Menu.BackgroundTransparency = ALPHA.menu
Menu.BorderSizePixel = 0; Menu.Active = true; Menu.Parent = ScreenGui
corner(Menu, 10)
local mStroke = Instance.new("UIStroke", Menu)
mStroke.Color = C.BG3; mStroke.Thickness = 1; mStroke.Transparency = 0.3

local TitleBar = Instance.new("Frame")
TitleBar.Size = UDim2.new(1, 0, 0, 46)
TitleBar.BackgroundColor3 = C.BG2; TitleBar.BackgroundTransparency = ALPHA.header
TitleBar.BorderSizePixel = 0; TitleBar.Active = true; TitleBar.Parent = Menu
corner(TitleBar, 10)

local TBfix = Instance.new("Frame")
TBfix.Size = UDim2.new(1, 0, 0, 18); TBfix.Position = UDim2.new(0, 0, 1, -18)
TBfix.BackgroundColor3 = C.BG2; TBfix.BackgroundTransparency = ALPHA.header
TBfix.BorderSizePixel = 0; TBfix.Parent = TitleBar

local TitleLbl = Instance.new("TextLabel")
TitleLbl.Size = UDim2.new(1, -70, 1, 0); TitleLbl.Position = UDim2.new(0, 16, 0, 0)
TitleLbl.BackgroundTransparency = 1; TitleLbl.Text = "FUZER V2"
TitleLbl.TextColor3 = C.Accent; TitleLbl.Font = Enum.Font.GothamBold
TitleLbl.TextSize = 15; TitleLbl.TextXAlignment = Enum.TextXAlignment.Left
TitleLbl.Parent = TitleBar

local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0, 46, 0, 46); CloseBtn.Position = UDim2.new(1, -46, 0, 0)
CloseBtn.BackgroundColor3 = C.Danger; CloseBtn.BackgroundTransparency = 0.1
CloseBtn.Text = "✕"; CloseBtn.TextColor3 = Color3.new(1, 1, 1)
CloseBtn.Font = Enum.Font.GothamBold; CloseBtn.TextSize = 22
CloseBtn.AutoButtonColor = true; CloseBtn.ZIndex = 5; CloseBtn.Parent = TitleBar
corner(CloseBtn, 10)

local dragging, dragStart, startPos
TitleBar.InputBegan:Connect(function(input)
    if input.Target == CloseBtn then return end
    if input.UserInputType == Enum.UserInputType.MouseButton1
    or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true; dragStart = input.Position; startPos = Menu.Position
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if not dragging then return end
    if input.UserInputType == Enum.UserInputType.MouseMovement
    or input.UserInputType == Enum.UserInputType.Touch then
        local delta = input.Position - dragStart
        Menu.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X,
            startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)
UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
    or input.UserInputType == Enum.UserInputType.Touch then dragging = false end
end)

-- ================= TABS =================
local TabBar = Instance.new("Frame")
TabBar.Size = UDim2.new(1, -20, 0, 36)
TabBar.Position = UDim2.new(0, 10, 0, 54)
TabBar.BackgroundColor3 = C.BG2; TabBar.BackgroundTransparency = ALPHA.panel
TabBar.Parent = Menu
corner(TabBar, 8)

local function makeTab(name, index)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0.2, -1.5, 1, 0)
    b.Position = UDim2.new(index * 0.2, index * 1.5, 0, 0)
    b.BackgroundColor3 = C.BG2; b.BackgroundTransparency = ALPHA.panel
    b.Text = name; b.TextColor3 = C.Sub; b.Font = Enum.Font.GothamBold
    b.TextSize = 10; b.AutoButtonColor = false; b.Parent = TabBar
    corner(b, 8)
    return b
end
local TabAim  = makeTab("AIM",  0)
local TabSil  = makeTab("SILENT", 1)
local TabESP  = makeTab("ESP",  2)
local TabCham = makeTab("CHAMS",3)
local TabMisc = makeTab("MISC", 4)

-- ================= CONTENT =================
local ContentContainer = Instance.new("Frame")
ContentContainer.Size = UDim2.new(1, -20, 1, -100)
ContentContainer.Position = UDim2.new(0, 10, 0, 96)
ContentContainer.BackgroundTransparency = 1
ContentContainer.ClipsDescendants = true
ContentContainer.Parent = Menu

local function newPage()
    local s = Instance.new("ScrollingFrame")
    s.Size = UDim2.new(1, 0, 1, 0); s.BackgroundTransparency = 1
    s.BorderSizePixel = 0; s.ScrollBarThickness = 5
    s.ScrollBarImageColor3 = C.Accent; s.ScrollBarImageTransparency = 0.3
    s.CanvasSize = UDim2.new(0, 0, 0, 0)
    s.ScrollingDirection = Enum.ScrollingDirection.Y
    s.ScrollingEnabled = true
    s.ElasticBehavior = Enum.ElasticBehavior.WhenScrollable
    s.Parent = ContentContainer
    local lay = Instance.new("UIListLayout", s)
    lay.Padding = UDim.new(0, 6); lay.SortOrder = Enum.SortOrder.LayoutOrder
    local pad = Instance.new("UIPadding", s)
    pad.PaddingBottom = UDim.new(0, 20); pad.PaddingRight = UDim.new(0, 6)
    local function recalc() s.CanvasSize = UDim2.new(0, 0, 0, lay.AbsoluteContentSize.Y + 24) end
    lay:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(recalc)
    task.defer(recalc)
    return s
end

local PageAim, PageSilent, PageESP, PageChams, PageMisc = newPage(), newPage(), newPage(), newPage(), newPage()
PageSilent.Visible = false; PageESP.Visible = false; PageChams.Visible = false; PageMisc.Visible = false

-- ================= DROPDOWN =================
local DropdownOverlay = Instance.new("TextButton")
DropdownOverlay.Size = UDim2.new(1, 0, 1, 0); DropdownOverlay.BackgroundTransparency = 1
DropdownOverlay.Text = ""; DropdownOverlay.AutoButtonColor = false
DropdownOverlay.Visible = false; DropdownOverlay.ZIndex = 1500
DropdownOverlay.Parent = ScreenGui

local DropdownList = Instance.new("Frame")
DropdownList.BackgroundColor3 = C.BG3; DropdownList.BackgroundTransparency = 0.05
DropdownList.BorderSizePixel = 0; DropdownList.Visible = false
DropdownList.ZIndex = 1501; DropdownList.Parent = ScreenGui
corner(DropdownList, 6)
local dlStroke = Instance.new("UIStroke", DropdownList)
dlStroke.Color = C.BG4; dlStroke.Thickness = 1

local activeBtn = nil
local function closeDropdown()
    DropdownOverlay.Visible = false; DropdownList.Visible = false
    for _, c in ipairs(DropdownList:GetChildren()) do
        if c:IsA("TextButton") then c:Destroy() end
    end
    activeBtn = nil
end

local function openDropdown(btn, options, callback)
    if activeBtn == btn and DropdownOverlay.Visible then closeDropdown(); return end
    if activeBtn then closeDropdown() end
    activeBtn = btn
    local absPos, absSize = btn.AbsolutePosition, btn.AbsoluteSize
    local itemH = 36
    local listH = #options * itemH
    local listY = absPos.Y + absSize.Y + 2
    if listY + listH > vp.Y - 10 then listY = absPos.Y - listH - 2 end
    if listY < 10 then listY = 10 end
    DropdownList.Size = UDim2.new(0, absSize.X, 0, listH)
    DropdownList.Position = UDim2.new(0, absPos.X, 0, listY)
    for i, opt in ipairs(options) do
        local ob = Instance.new("TextButton")
        ob.Size = UDim2.new(1, 0, 0, itemH)
        ob.Position = UDim2.new(0, 0, 0, (i - 1) * itemH)
        ob.BackgroundColor3 = C.BG3; ob.BackgroundTransparency = 0.05
        ob.Text = opt; ob.TextColor3 = C.Text
        ob.Font = Enum.Font.GothamMedium; ob.TextSize = 13
        ob.AutoButtonColor = true; ob.ZIndex = 1502; ob.Parent = DropdownList
        ob.MouseButton1Click:Connect(function()
            btn.Text = opt .. "  ▼"
            if callback then callback(opt) end
            closeDropdown()
        end)
    end
    DropdownOverlay.Visible = true
    DropdownList.Visible = true
end
DropdownOverlay.MouseButton1Click:Connect(closeDropdown)

-- ================= WIDGETS =================
local function section(parent, txt)
    local f = Instance.new("Frame"); f.Size = UDim2.new(1, 0, 0, 22)
    f.BackgroundTransparency = 1; f.Parent = parent
    local l = Instance.new("TextLabel"); l.Size = UDim2.new(1, 0, 1, 0)
    l.BackgroundTransparency = 1; l.Text = string.upper(txt); l.TextColor3 = C.Sub
    l.Font = Enum.Font.GothamBold; l.TextSize = 10
    l.TextXAlignment = Enum.TextXAlignment.Left; l.Parent = f
end

local function label(parent, txt, color)
    local f = Instance.new("Frame")
    f.Size = UDim2.new(1, 0, 0, 28)
    f.BackgroundColor3 = C.BG2; f.BackgroundTransparency = ALPHA.widget
    f.Parent = parent; corner(f, 6)
    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(1, -20, 1, 0); l.Position = UDim2.new(0, 12, 0, 0)
    l.BackgroundTransparency = 1; l.Text = txt
    l.TextColor3 = color or C.Text
    l.Font = Enum.Font.Gotham; l.TextSize = 12
    l.TextXAlignment = Enum.TextXAlignment.Left; l.Parent = f
    return l
end

local function toggle(parent, txt, default, cb)
    local f = Instance.new("Frame")
    f.Size = UDim2.new(1, 0, 0, 42)
    f.BackgroundColor3 = C.BG2; f.BackgroundTransparency = ALPHA.widget
    f.Parent = parent; corner(f, 6)
    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(1, -70, 1, 0); l.Position = UDim2.new(0, 14, 0, 0)
    l.BackgroundTransparency = 1; l.Text = txt; l.TextColor3 = C.Text
    l.Font = Enum.Font.Gotham; l.TextSize = 13
    l.TextXAlignment = Enum.TextXAlignment.Left; l.Parent = f
    local sw = Instance.new("TextButton")
    sw.Size = UDim2.new(0, 50, 0, 26); sw.Position = UDim2.new(1, -64, 0.5, -13)
    sw.BackgroundColor3 = default and C.Accent or C.BG3
    sw.Text = ""; sw.AutoButtonColor = false; sw.Parent = f
    corner(sw, 13)
    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0, 20, 0, 20)
    knob.Position = default and UDim2.new(1, -22, 0.5, -10) or UDim2.new(0, 3, 0.5, -10)
    knob.BackgroundColor3 = Color3.new(1, 1, 1); knob.Parent = sw
    corner(knob, 10)
    local st = default
    sw.MouseButton1Click:Connect(function()
        st = not st
        sw.BackgroundColor3 = st and C.Accent or C.BG3
        knob.Position = st and UDim2.new(1, -22, 0.5, -10) or UDim2.new(0, 3, 0.5, -10)
        if cb then cb(st) end
    end)
end

local function slider(parent, txt, mn, mx, default, cb, fmt)
    local f = Instance.new("Frame")
    f.Size = UDim2.new(1, 0, 0, 52)
    f.BackgroundColor3 = C.BG2; f.BackgroundTransparency = ALPHA.widget
    f.Parent = parent; corner(f, 6)
    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(1, -80, 0, 20); l.Position = UDim2.new(0, 14, 0, 5)
    l.BackgroundTransparency = 1; l.Text = txt; l.TextColor3 = C.Text
    l.Font = Enum.Font.Gotham; l.TextSize = 13
    l.TextXAlignment = Enum.TextXAlignment.Left; l.Parent = f
    local v = Instance.new("TextLabel")
    v.Size = UDim2.new(0, 70, 0, 20); v.Position = UDim2.new(1, -78, 0, 5)
    v.BackgroundTransparency = 1
    v.Text = fmt and string.format(fmt, default) or tostring(default)
    v.TextColor3 = C.Accent; v.Font = Enum.Font.GothamBold; v.TextSize = 12
    v.TextXAlignment = Enum.TextXAlignment.Right; v.Parent = f
    local bar = Instance.new("Frame")
    bar.Size = UDim2.new(1, -28, 0, 8); bar.Position = UDim2.new(0, 14, 1, -18)
    bar.BackgroundColor3 = C.BG3; bar.Parent = f; corner(bar, 4)
    local fill = Instance.new("Frame")
    fill.Size = UDim2.new((default - mn) / (mx - mn), 0, 1, 0)
    fill.BackgroundColor3 = C.Accent; fill.Parent = bar; corner(fill, 4)
    local hit = Instance.new("TextButton")
    hit.Size = UDim2.new(1, -24, 0, 24); hit.Position = UDim2.new(0, 12, 1, -26)
    hit.BackgroundTransparency = 1; hit.Text = ""; hit.Parent = f
    local isDragging = false
    local function update(x)
        local a = math.clamp((x - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
        local val = mn + (mx - mn) * a
        fill.Size = UDim2.new(a, 0, 1, 0)
        v.Text = fmt and string.format(fmt, val) or tostring(math.floor(val * 100) / 100)
        if cb then cb(val) end
    end
    hit.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            isDragging = true; update(i.Position.X)
        end
    end)
    UserInputService.InputChanged:Connect(function(i)
        if isDragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then update(i.Position.X) end
    end)
    UserInputService.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then isDragging = false end
    end)
end

local function dropdown(parent, txt, options, default, cb)
    local f = Instance.new("Frame")
    f.Size = UDim2.new(1, 0, 0, 44)
    f.BackgroundColor3 = C.BG2; f.BackgroundTransparency = ALPHA.widget
    f.Parent = parent; corner(f, 6)
    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(0.42, 0, 1, 0); l.Position = UDim2.new(0, 14, 0, 0)
    l.BackgroundTransparency = 1; l.Text = txt; l.TextColor3 = C.Text
    l.Font = Enum.Font.Gotham; l.TextSize = 13
    l.TextXAlignment = Enum.TextXAlignment.Left; l.Parent = f
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0.55, -14, 0, 32); btn.Position = UDim2.new(0.42, 4, 0.5, -16)
    btn.BackgroundColor3 = C.BG3; btn.Text = default .. "  ▼"
    btn.TextColor3 = C.Accent; btn.Font = Enum.Font.GothamMedium
    btn.TextSize = 12; btn.AutoButtonColor = false; btn.Parent = f
    corner(btn, 4)
    btn.MouseButton1Click:Connect(function() openDropdown(btn, options, cb) end)
end

local PALETTE = {
    {c=Color3.fromRGB(0,255,120)}, {c=Color3.fromRGB(255,70,70)},
    {c=Color3.fromRGB(70,140,255)}, {c=Color3.fromRGB(0,220,255)},
    {c=Color3.fromRGB(255,80,220)}, {c=Color3.fromRGB(255,220,60)},
    {c=Color3.fromRGB(255,150,40)}, {c=Color3.fromRGB(255,255,255)},
    {c=Color3.fromRGB(160,80,255)}, {c=Color3.fromRGB(255,130,180)},
    {c=Color3.fromRGB(200,200,200)}, {c=Color3.fromRGB(255,200,150)},
}

local function colorPicker(parent, txt, default, cb)
    local f = Instance.new("Frame")
    f.Size = UDim2.new(1, 0, 0, 86)
    f.BackgroundColor3 = C.BG2; f.BackgroundTransparency = ALPHA.widget
    f.Parent = parent; corner(f, 6)
    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(1, -60, 0, 22); l.Position = UDim2.new(0, 14, 0, 5)
    l.BackgroundTransparency = 1; l.Text = txt; l.TextColor3 = C.Text
    l.Font = Enum.Font.Gotham; l.TextSize = 13
    l.TextXAlignment = Enum.TextXAlignment.Left; l.Parent = f
    local prev = Instance.new("Frame")
    prev.Size = UDim2.new(0, 26, 0, 26); prev.Position = UDim2.new(1, -40, 0, 4)
    prev.BackgroundColor3 = default; prev.Parent = f; corner(prev, 5)
    local grid = Instance.new("Frame")
    grid.Size = UDim2.new(1, -28, 0, 36); grid.Position = UDim2.new(0, 14, 0, 40)
    grid.BackgroundTransparency = 1; grid.Parent = f
    local gl = Instance.new("UIListLayout", grid)
    gl.FillDirection = Enum.FillDirection.Horizontal; gl.Padding = UDim.new(0, 5)
    for _, item in ipairs(PALETTE) do
        local sw = Instance.new("TextButton")
        sw.Size = UDim2.new(0, 28, 0, 28)
        sw.BackgroundColor3 = item.c; sw.Text = ""; sw.AutoButtonColor = true
        sw.Parent = grid; corner(sw, 5)
        sw.MouseButton1Click:Connect(function()
            prev.BackgroundColor3 = item.c
            if cb then cb(item.c) end
        end)
    end
end

-- ========== AIMBOT ==========
section(PageAim, "Core Aimbot")
toggle(PageAim, "Aimbot Enabled", Settings.Aimbot.Enabled, function(v) Settings.Aimbot.Enabled = v end)
toggle(PageAim, "Show FOV Circle", Settings.Aimbot.ShowFOV, function(v) Settings.Aimbot.ShowFOV = v end)
toggle(PageAim, "Show Aim Tracer", Settings.Aimbot.ShowAimTracer, function(v) Settings.Aimbot.ShowAimTracer = v end)

section(PageAim, "📱 Mobile")
dropdown(PageAim, "Mobile Mode", {"Auto","Hold Button","Off"}, Settings.Aimbot.MobileMode,
    function(v)
        Settings.Aimbot.MobileMode = v
        if AimBtn then AimBtn.Visible = IsTouchDevice and v == "Hold Button" end
    end)

section(PageAim, "Targeting")
dropdown(PageAim, "Target Part", {"Head","Torso","UpperTorso","LowerTorso","HumanoidRootPart"},
    Settings.Aimbot.TargetPart, function(v) Settings.Aimbot.TargetPart = v end)
dropdown(PageAim, "Aim Key (PC)", {"MouseButton2","MouseButton1","Q","E","F"},
    Settings.Aimbot.Key, function(v) Settings.Aimbot.Key = v end)

section(PageAim, "⚡ Prediction")
slider(PageAim, "Predict Time (s)", 0, 0.5, Settings.Aimbot.Prediction,
    function(v) Settings.Aimbot.Prediction = v end, "%.3f")
dropdown(PageAim, "Mode", {"Simple","Smoothed"}, Settings.Aimbot.PredictionMode,
    function(v) Settings.Aimbot.PredictionMode = v end)
slider(PageAim, "Velocity Smooth", 0.05, 0.95, Settings.Aimbot.VelocitySmooth,
    function(v) Settings.Aimbot.VelocitySmooth = v end, "%.2f")

section(PageAim, "Tuning")
slider(PageAim, "FOV Range", 40, 500, Settings.Aimbot.FOV, function(v) Settings.Aimbot.FOV = v end)
slider(PageAim, "Smoothness", 0.01, 1, Settings.Aimbot.Smoothness,
    function(v) Settings.Aimbot.Smoothness = v end, "%.2f")

section(PageAim, "Filters")
toggle(PageAim, "Team Check", Settings.Aimbot.TeamCheck, function(v) Settings.Aimbot.TeamCheck = v end)
toggle(PageAim, "Wall Check", Settings.Aimbot.WallCheck, function(v) Settings.Aimbot.WallCheck = v end)

section(PageAim, "Style")
colorPicker(PageAim, "FOV Color", Settings.Aimbot.FOVColor, function(c) Settings.Aimbot.FOVColor = c end)

-- ========== SILENT ==========
section(PageSilent, "🔧 Hook Status")
local statusLabel = label(PageSilent, "Installing hooks...", C.Text)
local targetLabel = label(PageSilent, "Target: None", C.Sub)

section(PageSilent, "🎯 Silent Aim")
toggle(PageSilent, "Silent Aim Enabled", Settings.SilentAim.Enabled, function(v) Settings.SilentAim.Enabled = v end)
toggle(PageSilent, "Team Check", Settings.SilentAim.TeamCheck, function(v) Settings.SilentAim.TeamCheck = v end)
toggle(PageSilent, "Show Silent FOV", Settings.SilentAim.ShowFOV, function(v) Settings.SilentAim.ShowFOV = v end)

section(PageSilent, "Binds")
dropdown(PageSilent, "Activation Bind", {"Always","MouseButton1","MouseButton2","Q","E","F"}, Settings.SilentAim.Bind,
    function(v) Settings.SilentAim.Bind = v end)

section(PageSilent, "Targeting")
dropdown(PageSilent, "Target Part", {"Head","Torso","UpperTorso","LowerTorso","HumanoidRootPart"},
    Settings.SilentAim.TargetPart, function(v) Settings.SilentAim.TargetPart = v end)
slider(PageSilent, "Silent FOV (radius)", 50, 800, Settings.SilentAim.FOV,
    function(v) Settings.SilentAim.FOV = v end)

section(PageSilent, "Style")
colorPicker(PageSilent, "FOV Color", Settings.SilentAim.FOVColor, function(c) Settings.SilentAim.FOVColor = c end)

-- ========== ESP ==========
section(PageESP, "General")
toggle(PageESP, "ESP Enabled", Settings.ESP.Enabled, function(v) Settings.ESP.Enabled = v end)
toggle(PageESP, "Team Check", Settings.ESP.TeamCheck, function(v) Settings.ESP.TeamCheck = v end)
slider(PageESP, "Max Distance", 100, 5000, Settings.ESP.MaxDistance, function(v) Settings.ESP.MaxDistance = v end)
slider(PageESP, "Text Size", 8, 20, Settings.ESP.TextSize, function(v) Settings.ESP.TextSize = v end)

section(PageESP, "Boxes")
toggle(PageESP, "Show Boxes", Settings.ESP.Boxes, function(v) Settings.ESP.Boxes = v end)
dropdown(PageESP, "Style", {"2D Box","Corner Box","Filled Box"}, Settings.ESP.BoxStyle,
    function(v) Settings.ESP.BoxStyle = v end)
slider(PageESP, "Thickness", 1, 4, Settings.ESP.BoxThickness, function(v) Settings.ESP.BoxThickness = v end)
slider(PageESP, "Transparency", 0, 1, Settings.ESP.BoxTransparency,
    function(v) Settings.ESP.BoxTransparency = v end, "%.2f")
colorPicker(PageESP, "Box Color", Settings.ESP.BoxColor, function(c) Settings.ESP.BoxColor = c end)

section(PageESP, "Elements")
toggle(PageESP, "Names", Settings.ESP.Names, function(v) Settings.ESP.Names = v end)
colorPicker(PageESP, "Name Color", Settings.ESP.NameColor, function(c) Settings.ESP.NameColor = c end)
toggle(PageESP, "Health", Settings.ESP.Health, function(v) Settings.ESP.Health = v end)
colorPicker(PageESP, "Health Color", Settings.ESP.HealthColor, function(c) Settings.ESP.HealthColor = c end)
toggle(PageESP, "Distance", Settings.ESP.Distance, function(v) Settings.ESP.Distance = v end)
toggle(PageESP, "Tracers", Settings.ESP.Tracers, function(v) Settings.ESP.Tracers = v end)
colorPicker(PageESP, "Tracer Color", Settings.ESP.TracerColor, function(c) Settings.ESP.TracerColor = c end)

-- ========== CHAMS ==========
section(PageChams, "Highlight")
toggle(PageChams, "Chams Enabled", Settings.Chams.Enabled, function(v) Settings.Chams.Enabled = v end)
toggle(PageChams, "Team Check", Settings.Chams.TeamCheck, function(v) Settings.Chams.TeamCheck = v end)
slider(PageChams, "Transparency", 0, 1, Settings.Chams.Transparency,
    function(v) Settings.Chams.Transparency = v end, "%.2f")
colorPicker(PageChams, "Chams Color", Settings.Chams.Color,
    function(c) Settings.Chams.Color = c; refreshAllChams() end)

-- ========== MISC ==========
section(PageMisc, "🎨 Hands Appearance")
toggle(PageMisc, "Hands Enabled", Settings.Appearance.HandsEnabled,
    function(v) Settings.Appearance.HandsEnabled = v; applyHandsColor() end)
dropdown(PageMisc, "Hands Mode", {"Solid","Rainbow","Glow","Rainbow Glow"},
    Settings.Appearance.HandsMode,
    function(v) Settings.Appearance.HandsMode = v; applyHandsColor() end)
colorPicker(PageMisc, "Hands Color (Solid)", Settings.Appearance.HandsColor,
    function(c) Settings.Appearance.HandsColor = c end)
slider(PageMisc, "Rainbow Speed", 0.1, 5, Settings.Appearance.HandsSpeed,
    function(v) Settings.Appearance.HandsSpeed = v end, "%.1f")

section(PageMisc, "🌌 Sky Appearance")
toggle(PageMisc, "Sky Enabled", Settings.Appearance.SkyEnabled,
    function(v) Settings.Appearance.SkyEnabled = v; applySkyColor() end)
dropdown(PageMisc, "Sky Mode", {"Solid","Rainbow","Pulse"},
    Settings.Appearance.SkyMode,
    function(v) Settings.Appearance.SkyMode = v; applySkyColor() end)
colorPicker(PageMisc, "Sky Color (Solid)", Settings.Appearance.SkyColor,
    function(c) Settings.Appearance.SkyColor = c end)
slider(PageMisc, "Sky Speed", 0.1, 5, Settings.Appearance.SkySpeed,
    function(v) Settings.Appearance.SkySpeed = v end, "%.1f")

section(PageMisc, "🔍 Fast Zoom (PC, hold Z)")
toggle(PageMisc, "Fast Zoom Enabled", Settings.FastZoom.Enabled,
    function(v) Settings.FastZoom.Enabled = v end)
slider(PageMisc, "Zoom FOV", 20, 80, Settings.FastZoom.ZoomFOV,
    function(v) Settings.FastZoom.ZoomFOV = v end)

section(PageMisc, "🎯 Head Hitbox (UNIVERSAL)")
toggle(PageMisc, "Head Hitbox Enabled", Settings.Hitbox.Enabled,
    function(v) Settings.Hitbox.Enabled = v; applyHitboxAll() end)
toggle(PageMisc, "Show Visual (red box)", Settings.Hitbox.ShowVisual,
    function(v) Settings.Hitbox.ShowVisual = v; applyHitboxAll() end)
dropdown(PageMisc, "Size",
    {"1.5x","2x","3x","4x","5x","6x","7x","8x"},
    tostring(Settings.Hitbox.Size) .. "x",
    function(v)
        Settings.Hitbox.Size = tonumber(v:gsub("x","")) or 2
        applyHitboxAll()
    end)

local function setTab(page)
    PageAim.Visible   = (page == PageAim)
    PageSilent.Visible= (page == PageSilent)
    PageESP.Visible   = (page == PageESP)
    PageChams.Visible = (page == PageChams)
    PageMisc.Visible  = (page == PageMisc)
    TabAim.TextColor3  = (page == PageAim)   and C.Accent or C.Sub
    TabSil.TextColor3  = (page == PageSilent) and C.Accent or C.Sub
    TabESP.TextColor3  = (page == PageESP)   and C.Accent or C.Sub
    TabCham.TextColor3 = (page == PageChams) and C.Accent or C.Sub
    TabMisc.TextColor3 = (page == PageMisc)  and C.Accent or C.Sub
end
TabAim.MouseButton1Click:Connect(function() setTab(PageAim) end)
TabSil.MouseButton1Click:Connect(function() setTab(PageSilent) end)
TabESP.MouseButton1Click:Connect(function() setTab(PageESP) end)
TabCham.MouseButton1Click:Connect(function() setTab(PageChams) end)
TabMisc.MouseButton1Click:Connect(function() setTab(PageMisc) end)
setTab(PageAim)

-- ================= MOBILE AIM BUTTON =================
local AimBtn = Instance.new("TextButton")
AimBtn.Size = UDim2.new(0, 84, 0, 84)
AimBtn.Position = UDim2.new(1, -114, 0.62, -42)
AimBtn.BackgroundColor3 = C.AimBtn; AimBtn.BackgroundTransparency = 0.35
AimBtn.Text = "AIM"; AimBtn.TextColor3 = Color3.new(1, 1, 1)
AimBtn.Font = Enum.Font.GothamBold; AimBtn.TextSize = 16
AimBtn.AutoButtonColor = false
AimBtn.Visible = IsTouchDevice and Settings.Aimbot.MobileMode == "Hold Button"
AimBtn.ZIndex = 1000; AimBtn.Parent = ScreenGui
corner(AimBtn, 42)
local aimStroke = Instance.new("UIStroke", AimBtn)
aimStroke.Color = Color3.new(1, 1, 1); aimStroke.Thickness = 2

AimBtn.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
    or input.UserInputType == Enum.UserInputType.Touch then
        aimingViaButton = true; AimBtn.BackgroundTransparency = 0.1
    end
end)
AimBtn.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
    or input.UserInputType == Enum.UserInputType.Touch then
        aimingViaButton = false; AimBtn.BackgroundTransparency = 0.35
    end
end)

-- ================= MENU OPEN/CLOSE =================
local function setMenu(open)
    Settings.Menu.Open = open
    Menu.Visible = open
    OpenBtn.Visible = IsMobile and not open
    if not open then closeDropdown() end
end
setMenu(Settings.Menu.Open)

CloseBtn.MouseButton1Click:Connect(function() setMenu(false) end)
OpenBtn.MouseButton1Click:Connect(function() setMenu(true) end)

UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == Settings.Menu.Key or input.KeyCode == Settings.Menu.Key2 then
        setMenu(not Settings.Menu.Open)
    end
end)

-- ================= FAST ZOOM =================
local zoomState = { pressing = false, returning = false, baseFOV = Camera.FieldOfView }

UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if IsTouchDevice then return end
    if input.KeyCode == Enum.KeyCode.Z and Settings.FastZoom.Enabled then
        if not zoomState.pressing then
            zoomState.baseFOV   = Camera.FieldOfView
            zoomState.pressing  = true
            zoomState.returning = false
        end
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if IsTouchDevice then return end
    if input.KeyCode == Enum.KeyCode.Z then
        if zoomState.pressing then
            zoomState.pressing  = false
            zoomState.returning = true
        end
    end
end)

-- =====================================================================
-- 🎨 APPEARANCE v2 (Rainbow / Glow / Pulse)
-- =====================================================================
local HandsOrigColors = {}
local HandsOrigMaterials = {}
local HandsLights = {}

-- Цвет по режиму
local function getHandsColor(baseColor, t)
    local mode = Settings.Appearance.HandsMode
    if mode == "Rainbow" or mode == "Rainbow Glow" then
        local hue = (t * Settings.Appearance.HandsSpeed * 0.3) % 1
        return Color3.fromHSV(hue, 1, 1)
    end
    return baseColor
end

local function applyHandsColor()
    local char = LocalPlayer.Character
    if not char then return end
    local mode = Settings.Appearance.HandsMode
    local isGlow = (mode == "Glow" or mode == "Rainbow Glow")
    local isRainbow = (mode == "Rainbow" or mode == "Rainbow Glow")
    local t = tick()

    for _, name in ipairs(HAND_PARTS) do
        local part = char:FindFirstChild(name)
        if part and part:IsA("BasePart") then
            -- Сохраняем оригиналы
            if not HandsOrigColors[part] then
                HandsOrigColors[part] = part.Color
                HandsOrigMaterials[part] = part.Material
            end

            -- Убираем старый свет
            if HandsLights[part] then
                HandsLights[part]:Destroy()
                HandsLights[part] = nil
            end

            if Settings.Appearance.HandsEnabled then
                local newColor = getHandsColor(Settings.Appearance.HandsColor, t)
                part.Color = newColor
                if isGlow then
                    part.Material = Enum.Material.Neon
                    -- Добавляем PointLight для настоящего свечения
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
                -- Возвращаем оригинал
                part.Color = HandsOrigColors[part] or part.Color
                part.Material = HandsOrigMaterials[part] or part.Material
            end
        end
    end
end

-- Небо
local function applySkyColor()
    if Settings.Appearance.SkyEnabled then
        if not SkyBackup then
            local atm = Lighting:FindFirstChildOfClass("Atmosphere")
            if atm then
                SkyBackup = {
                    obj = atm,
                    Color = atm.Color,
                    Decay = atm.Decay,
                    Density = atm.Density,
                    Haze = atm.Haze,
                }
            else
                SkyBackup = { created = true }
                local newAtm = Instance.new("Atmosphere")
                newAtm.Density = 0.3
                newAtm.Offset = 0.25
                newAtm.Glare = 0
                newAtm.Haze = 0
                newAtm.Parent = Lighting
                SkyBackup.obj = newAtm
            end
        end
        local atm = SkyBackup.obj
        if atm then
            local mode = Settings.Appearance.SkyMode
            local t = tick()
            if mode == "Rainbow" then
                local hue = (t * Settings.Appearance.SkySpeed * 0.3) % 1
                local rc = Color3.fromHSV(hue, 0.7, 1)
                atm.Color = rc
                atm.Decay = rc
            elseif mode == "Pulse" then
                -- Пульсирует между исходным цветом и белым
                local pulse = (math.sin(t * Settings.Appearance.SkySpeed * 2) + 1) / 2
                local base = Settings.Appearance.SkyColor
                atm.Color = base:Lerp(Color3.new(1, 1, 1), pulse * 0.5)
                atm.Decay = base:Lerp(Color3.new(1, 1, 1), pulse * 0.5)
            else
                atm.Color = Settings.Appearance.SkyColor
                atm.Decay = Settings.Appearance.SkyColor
            end
        end
    else
        if SkyBackup then
            if SkyBackup.created and SkyBackup.obj then
                SkyBackup.obj:Destroy()
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
    HandsOrigColors = {}
    HandsOrigMaterials = {}
    HandsLights = {}
    if Settings.Appearance.HandsEnabled then
        applyHandsColor()
    end
end)

-- =====================================================================
-- 🎯 SILENT AIM (Triple Hook)
-- =====================================================================
local silentMouse = LocalPlayer:GetMouse()

local function isSilentKeyHeld()
    local bind = Settings.SilentAim.Bind
    if bind == "Always" then return true end
    if bind == "MouseButton1" then return UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) end
    if bind == "MouseButton2" then return UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) end
    if bind == "Q" then return UserInputService:IsKeyDown(Enum.KeyCode.Q) end
    if bind == "E" then return UserInputService:IsKeyDown(Enum.KeyCode.E) end
    if bind == "F" then return UserInputService:IsKeyDown(Enum.KeyCode.F) end
    return false
end

local function getPredictedPosition(player, part, velocity)
    local pred = Settings.Aimbot.Prediction
    if pred <= 0 then return part.Position end
    if velocity.Magnitude < 1 then return part.Position end
    if Settings.Aimbot.PredictionMode == "Simple" then
        return part.Position + velocity * pred
    end
    local last = VelocityCache[player]
    if not last then
        VelocityCache[player] = velocity
        return part.Position + velocity * pred
    end
    if (velocity - last).Magnitude > 200 then
        VelocityCache[player] = velocity
        return part.Position + velocity * pred
    end
    local smoothed = last:Lerp(velocity, Settings.Aimbot.VelocitySmooth)
    VelocityCache[player] = smoothed
    return part.Position + smoothed * pred
end

local function updateSilentTarget()
    if not Settings.SilentAim.Enabled or not isSilentKeyHeld() then
        SilentTarget = nil
        if targetLabel then targetLabel.Text = "Target: None (disabled)"; targetLabel.TextColor3 = C.Sub end
        return
    end

    local closest, shortest = nil, Settings.SilentAim.FOV
    local center = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    local closestName = nil

    for _, p in ipairs(Players:GetPlayers()) do
        if p == LocalPlayer then continue end
        if Settings.SilentAim.TeamCheck and p.Team == LocalPlayer.Team then continue end
        local char = p.Character
        if not char then continue end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not hum or hum.Health <= 0 then continue end
        local part = char:FindFirstChild(Settings.SilentAim.TargetPart)
        if not part then continue end
        local root = char:FindFirstChild("HumanoidRootPart")
        local vel = root and root.AssemblyLinearVelocity or Vector3.zero

        local predicted = getPredictedPosition(p, part, vel)
        local sp, onScreen = Camera:WorldToViewportPoint(predicted)
        if not onScreen then continue end

        local d = (Vector2.new(sp.X, sp.Y) - center).Magnitude
        if d < shortest then
            shortest = d
            closest = part
            closestName = p.Name
        end
    end
    SilentTarget = closest
    if targetLabel then
        if closest then
            targetLabel.Text = "🎯 Target: " .. closestName
            targetLabel.TextColor3 = C.Accent
        else
            targetLabel.Text = "Target: Searching..."
            targetLabel.TextColor3 = C.Sub
        end
    end
end

pcall(function()
    local mt = getrawmetatable(game)
    local oldIndex = mt.__index
    setreadonly(mt, false)
    local newIndex = function(self, key)
        if not checkcaller() and self == silentMouse and Settings.SilentAim.Enabled then
            if SilentTarget and SilentTarget.Parent then
                if key == "Hit" then return CFrame.new(SilentTarget.Position)
                elseif key == "Target" then return SilentTarget
                elseif key == "UnitRay" then
                    local origin = Camera.CFrame.Position
                    local target = SilentTarget.Position
                    return Ray.new(origin, (target - origin).Unit * (target - origin).Magnitude)
                end
            end
        end
        return oldIndex(self, key)
    end
    if typeof(newcclosure) == "function" then newIndex = newcclosure(newIndex) end
    mt.__index = newIndex
    setreadonly(mt, true)
    hookMouseOK = true
end)

pcall(function()
    local oldNamecall
    oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
        local method = getnamecallmethod()
        if not checkcaller() and Settings.SilentAim.Enabled then
            if SilentTarget and SilentTarget.Parent then
                if method == "ScreenPointToRay" and self == Camera then
                    local origin = Camera.CFrame.Position
                    local target = SilentTarget.Position
                    return Ray.new(origin, (target - origin).Unit * (target - origin).Magnitude)
                elseif method == "Raycast" and self == workspace then
                    local args = {...}
                    local origin, direction, params = args[1], args[2], args[3]
                    if typeof(origin) == "Vector3" and typeof(direction) == "Vector3" then
                        local target = SilentTarget.Position
                        local newDir = target - origin
                        return workspace:Raycast(origin, newDir.Unit * math.max(newDir.Magnitude, 1), params)
                    end
                end
            end
        end
        return oldNamecall(self, ...)
    end)
    hookRayOK = true
end)

task.defer(function()
    task.wait(0.5)
    if statusLabel then
        local parts = {}
        table.insert(parts, hookMouseOK and "Mouse: ✅" or "Mouse: ❌")
        table.insert(parts, hookRayOK and "Ray: ✅" or "Ray: ❌")
        statusLabel.Text = "Hooks: " .. table.concat(parts, " | ")
        statusLabel.TextColor3 = (hookMouseOK or hookRayOK) and C.Accent or C.Danger
    end
end)

-- =====================================================================
-- 🎯 UNIVERSAL HITBOX
-- =====================================================================
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

local function ensureHitboxForPlayer(player)
    if player == LocalPlayer then return end
    local char = player.Character
    if not char then clearHitbox(player); return end
    local head = char:FindFirstChild("Head")
    if not head or not head:IsA("BasePart") then return end

    local s = HitboxCache[player]
    if s and (s.head ~= head or s.char ~= char) then
        clearHitbox(player); s = nil
    end

    if not s then
        s = {
            char = char, head = head,
            origSize = head.Size, origCanCollide = head.CanCollide,
            origMassless = head.Massless, origTransparency = head.Transparency,
            extra = nil,
        }
        HitboxCache[player] = s
    end

    local mult = Settings.Hitbox.Size
    local targetSize = s.origSize * mult

    if head.Size ~= targetSize then
        head.Size = targetSize
        head.CanCollide = false
        head.Massless = true
        if Settings.Hitbox.ShowVisual then head.Transparency = 0.5 else head.Transparency = s.origTransparency end
    end

    if not s.extra or not s.extra.Parent then
        local extra = Instance.new("Part")
        extra.Name = "Head"
        extra.Size = targetSize
        extra.CFrame = head.CFrame
        extra.Transparency = Settings.Hitbox.ShowVisual and 0.5 or 1
        extra.Color = Color3.fromRGB(255, 50, 50)
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

local function applyHitboxAll()
    if not Settings.Hitbox.Enabled then
        for _, p in ipairs(Players:GetPlayers()) do clearHitbox(p) end
        return
    end
    for _, p in ipairs(Players:GetPlayers()) do ensureHitboxForPlayer(p) end
end

-- ================= FOV DRAW =================
local fovDraw = Drawing.new("Circle")
fovDraw.NumSides = 60; fovDraw.Thickness = 1.5; fovDraw.Filled = false
fovDraw.Color = Settings.Aimbot.FOVColor; fovDraw.Visible = false

local aimTracerDraw = Drawing.new("Line")
aimTracerDraw.Thickness = 1; aimTracerDraw.Color = Settings.Aimbot.FOVColor
aimTracerDraw.Visible = false

local silentFovDraw = Drawing.new("Circle")
silentFovDraw.NumSides = 60; silentFovDraw.Thickness = 1.5; silentFovDraw.Filled = false
silentFovDraw.Color = Settings.SilentAim.FOVColor; silentFovDraw.Visible = false

-- ================= ESP =================
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
        local top = head and Camera:WorldToViewportPoint(head.Position + Vector3.new(0, 1, 0)) or sp
        local bot = Camera:WorldToViewportPoint(root.Position - Vector3.new(0, 3, 0))
        local h = math.abs(top.Y - bot.Y)
        local w = h * 0.5
        local x, y = sp.X - w / 2, sp.Y - h / 2

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

        e.Health.Text = math.floor(hum.Health) .. "/" .. math.floor(hum.MaxHealth)
        e.Health.Size = math.max(Settings.ESP.TextSize - 2, 9)
        e.Health.Color = Settings.ESP.HealthColor
        e.Health.Position = Vector2.new(x - 38, y); e.Health.Visible = Settings.ESP.Health

        e.Distance.Text = math.floor(dist) .. "m"
        e.Distance.Size = math.max(Settings.ESP.TextSize - 2, 9)
        e.Distance.Color = Settings.ESP.DistanceColor
        e.Distance.Position = Vector2.new(sp.X, y + h + 3)
        e.Distance.Visible = Settings.ESP.Distance

        if Settings.ESP.Tracers then
            e.Tracer.From = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)
            e.Tracer.To = Vector2.new(sp.X, sp.Y)
            e.Tracer.Color = Settings.ESP.TracerColor; e.Tracer.Visible = true
        else
            e.Tracer.Visible = false
        end
    end
end

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
    hl.OutlineColor = Color3.new(1, 1, 1); hl.OutlineTransparency = 0.5
    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    hl.Parent = char
    ChamsCache[player] = hl
end

function refreshAllChams()
    for _, p in ipairs(Players:GetPlayers()) do applyChams(p) end
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
        center = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
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
                local hit = workspace:FindPartOnRayWithIgnoreList(ray, {LocalPlayer.Character, char})
                if hit then continue end
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

-- ================= MAIN LOOP =================
RunService.RenderStepped:Connect(function()
    updateSilentTarget()
    updateESP()
    for _, p in ipairs(Players:GetPlayers()) do applyChams(p) end

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
        fovDraw.Position = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
        fovDraw.Radius = Settings.Aimbot.FOV
        fovDraw.Color = AimTarget and C.Danger or Settings.Aimbot.FOVColor
    else
        fovDraw.Visible = false
    end

    if Settings.SilentAim.Enabled and Settings.SilentAim.ShowFOV then
        silentFovDraw.Visible = true
        silentFovDraw.Position = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
        silentFovDraw.Radius = Settings.SilentAim.FOV
        silentFovDraw.Color = SilentTarget and C.Danger or Settings.SilentAim.FOVColor
    else
        silentFovDraw.Visible = false
    end

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
                aimTracerDraw.From = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
                aimTracerDraw.To = Vector2.new(sp.X, sp.Y)
                aimTracerDraw.Color = Settings.Aimbot.FOVColor
                aimTracerDraw.Visible = true
            else
                aimTracerDraw.Visible = false
            end
        else
            AimTarget = nil; aimTracerDraw.Visible = false
        end
    else
        AimTarget = nil; aimTracerDraw.Visible = false
    end
end)

-- Отдельный быстрый цикл для анимации rainbow/glow
RunService.Heartbeat:Connect(function()
    if Settings.Hitbox.Enabled then
        for _, p in ipairs(Players:GetPlayers()) do ensureHitboxForPlayer(p) end
    end
    if Settings.Appearance.HandsEnabled then
        applyHandsColor()
    end
    if Settings.Appearance.SkyEnabled then
        applySkyColor()
    end
end)

-- ================= PLAYER MANAGEMENT =================
local function onPlayer(p)
    createESP(p)
    applyChams(p)
    p.CharacterAdded:Connect(function()
        task.wait(0.3)
        applyChams(p)
        if ESPCache[p] then hideESP(ESPCache[p]) end
        VelocityCache[p] = nil
        clearHitbox(p)
    end)
    p.CharacterRemoving:Connect(function() clearHitbox(p) end)
end

Players.PlayerAdded:Connect(onPlayer)
Players.PlayerRemoving:Connect(function(p)
    removeESP(p)
    local h = ChamsCache[p]
    if h then h:Destroy(); ChamsCache[p] = nil end
    VelocityCache[p] = nil
    clearHitbox(p)
end)
for _, p in ipairs(Players:GetPlayers()) do onPlayer(p) end
