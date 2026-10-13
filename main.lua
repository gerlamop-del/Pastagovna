-- Brisk Survival v1 | Menu + ESP + Aimbot
-- KAI online | Mobile Update

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Camera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer

local Settings = {
    ESP = {
        Enabled = true,
        Boxes = true,
        Names = true,
        Health = true,
        Distance = true,
        TeamCheck = false,
        MaxDistance = 1000,
        Color = Color3.fromRGB(0, 255, 0)
    },
    Aimbot = {
        Enabled = true,
        Key = Enum.UserInputType.MouseButton2,
        FOV = 120,
        Smoothness = 0.15,
        TargetPart = "Head",
        TeamCheck = false,
        WallCheck = false,
        VisibleCheck = true,
        ShowFOV = true,        -- новый: показывать FOV круг
        MobileMode = true      -- новый: авто-аим на мобиле
    },
    Menu = {
        Key = Enum.KeyCode.RightShift,
        Open = true
    }
}

-- Определяем мобильное устройство
local IsMobile = UserInputService.TouchEnabled and not UserInputService.MouseEnabled

local ESPCache = {}
local AimTarget = nil

-- GUI
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "BriskSurvivalMenu"
ScreenGui.ResetOnSpawn = false
ScreenGui.IgnoreGuiInset = true
ScreenGui.Parent = game:GetService("CoreGui")

-- FOV Circle (мобильный/десктоп)
local FOVCircleGui = Instance.new("ScreenGui")
FOVCircleGui.Name = "BriskFOVCircle"
FOVCircleGui.ResetOnSpawn = false
FOVCircleGui.IgnoreGuiInset = true
FOVCircleGui.Parent = game:GetService("CoreGui")

local FOVFrame = Instance.new("Frame")
FOVFrame.AnchorPoint = Vector2.new(0.5, 0.5)
FOVFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
FOVFrame.BackgroundTransparency = 1
FOVFrame.Parent = FOVCircleGui

local FOVCircle = Instance.new("ImageLabel")
FOVCircle.AnchorPoint = Vector2.new(0.5, 0.5)
FOVCircle.Position = UDim2.new(0.5, 0, 0.5, 0)
FOVCircle.BackgroundTransparency = 1
FOVCircle.Image = "rbxassetid://5028857084" -- круг
FOVCircle.ImageColor3 = Color3.fromRGB(0, 255, 0)
FOVCircle.ImageTransparency = 0.5
FOVCircle.Parent = FOVFrame

-- Main Frame
local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 320, 0, 500)
MainFrame.Position = UDim2.new(0.5, -160, 0.5, -250)
MainFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.Parent = ScreenGui

local UICorner = Instance.new("UICorner")
UICorner.CornerRadius = UDim.new(0, 8)
UICorner.Parent = MainFrame

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, 0, 0, 30)
Title.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
Title.Text = "Brisk Survival v1 | KAI"
Title.TextColor3 = Color3.fromRGB(0, 255, 0)
Title.Font = Enum.Font.SourceSansBold
Title.TextSize = 16
Title.Parent = MainFrame

-- Кнопка открытия/закрытия меню (для мобилы)
local OpenButton = Instance.new("TextButton")
OpenButton.Size = UDim2.new(0, 50, 0, 50)
OpenButton.Position = UDim2.new(0, 10, 0, 100)
OpenButton.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
OpenButton.Text = "KAI"
OpenButton.TextColor3 = Color3.fromRGB(0, 255, 0)
OpenButton.Font = Enum.Font.SourceSansBold
OpenButton.TextSize = 16
OpenButton.Visible = IsMobile
OpenButton.Parent = ScreenGui

local OpenCorner = Instance.new("UICorner")
OpenCorner.CornerRadius = UDim.new(0, 25)
OpenCorner.Parent = OpenButton

local function createToggle(name, parent, y, default, callback)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, -20, 0, 25)
    btn.Position = UDim2.new(0, 10, 0, y)
    btn.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    btn.Text = name .. ": " .. (default and "ON" or "OFF")
    btn.TextColor3 = default and Color3.fromRGB(0, 255, 0) or Color3.fromRGB(255, 60, 60)
    btn.Font = Enum.Font.SourceSans
    btn.TextSize = 14
    btn.Parent = parent
    btn.MouseButton1Click:Connect(function()
        default = not default
        btn.Text = name .. ": " .. (default and "ON" or "OFF")
        btn.TextColor3 = default and Color3.fromRGB(0, 255, 0) or Color3.fromRGB(255, 60, 60)
        callback(default)
    end)
    return btn
end

local function createSlider(name, parent, y, min, max, default, callback)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, -20, 0, 40)
    frame.Position = UDim2.new(0, 10, 0, y)
    frame.BackgroundTransparency = 1
    frame.Parent = parent

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 0, 15)
    label.BackgroundTransparency = 1
    label.Text = name .. ": " .. tostring(default)
    label.TextColor3 = Color3.fromRGB(200, 200, 200)
    label.Font = Enum.Font.SourceSans
    label.TextSize = 12
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = frame

    local bar = Instance.new("Frame")
    bar.Size = UDim2.new(1, 0, 0, 5)
    bar.Position = UDim2.new(0, 0, 0, 20)
    bar.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    bar.BorderSizePixel = 0
    bar.Parent = frame

    local fill = Instance.new("Frame")
    fill.Size = UDim2.new((default - min) / (max - min), 0, 1, 0)
    fill.BackgroundColor3 = Color3.fromRGB(0, 200, 0)
    fill.BorderSizePixel = 0
    fill.Parent = bar

    local dragging = false
    local function updateFromInput(posX)
        local barPos = bar.AbsolutePosition.X
        local barSize = bar.AbsoluteSize.X
        local alpha = math.clamp((posX - barPos) / barSize, 0, 1)
        local value = min + (max - min) * alpha
        fill.Size = UDim2.new(alpha, 0, 1, 0)
        label.Text = name .. ": " .. string.format("%.2f", value)
        callback(value)
    end

    bar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
        end
    end)
    bar.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch) then
            updateFromInput(input.Position.X)
        end
    end)
end

-- ESP Settings
local ESPFrame = Instance.new("Frame")
ESPFrame.Size = UDim2.new(1, 0, 0, 180)
ESPFrame.Position = UDim2.new(0, 0, 0, 35)
ESPFrame.BackgroundTransparency = 1
ESPFrame.Parent = MainFrame

local ESPTitle = Instance.new("TextLabel")
ESPTitle.Size = UDim2.new(1, 0, 0, 20)
ESPTitle.BackgroundTransparency = 1
ESPTitle.Text = "ESP Settings"
ESPTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
ESPTitle.Font = Enum.Font.SourceSansBold
ESPTitle.TextSize = 14
ESPTitle.Parent = ESPFrame

createToggle("ESP Enabled", ESPFrame, 25, Settings.ESP.Enabled, function(v) Settings.ESP.Enabled = v end)
createToggle("Boxes", ESPFrame, 55, Settings.ESP.Boxes, function(v) Settings.ESP.Boxes = v end)
createToggle("Names", ESPFrame, 85, Settings.ESP.Names, function(v) Settings.ESP.Names = v end)
createToggle("Health", ESPFrame, 115, Settings.ESP.Health, function(v) Settings.ESP.Health = v end)
createToggle("Distance", ESPFrame, 145, Settings.ESP.Distance, function(v) Settings.ESP.Distance = v end)

-- Aimbot Settings
local AimFrame = Instance.new("Frame")
AimFrame.Size = UDim2.new(1, 0, 0, 300)
AimFrame.Position = UDim2.new(0, 0, 0, 220)
AimFrame.BackgroundTransparency = 1
AimFrame.Parent = MainFrame

local AimTitle = Instance.new("TextLabel")
AimTitle.Size = UDim2.new(1, 0, 0, 20)
AimTitle.BackgroundTransparency = 1
AimTitle.Text = "Aimbot Settings"
AimTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
AimTitle.Font = Enum.Font.SourceSansBold
AimTitle.TextSize = 14
AimTitle.Parent = AimFrame

createToggle("Aimbot Enabled", AimFrame, 25, Settings.Aimbot.Enabled, function(v) Settings.Aimbot.Enabled = v end)
createSlider("FOV", AimFrame, 55, 20, 400, Settings.Aimbot.FOV, function(v) Settings.Aimbot.FOV = v end)
createSlider("Smoothness", AimFrame, 100, 0.01, 1, Settings.Aimbot.Smoothness, function(v) Settings.Aimbot.Smoothness = v end)
createToggle("Team Check", AimFrame, 145, Settings.Aimbot.TeamCheck, function(v) Settings.Aimbot.TeamCheck = v end)
createToggle("Wall Check", AimFrame, 175, Settings.Aimbot.WallCheck, function(v) Settings.Aimbot.WallCheck = v end)
createToggle("Show FOV", AimFrame, 205, Settings.Aimbot.ShowFOV, function(v) Settings.Aimbot.ShowFOV = v end)
createToggle("Mobile Mode", AimFrame, 235, Settings.Aimbot.MobileMode, function(v) Settings.Aimbot.MobileMode = v end)

-- ESP Functions
local function createESP(player)
    if player == LocalPlayer then return end
    local esp = {}
    esp.Box = Drawing.new("Square")
    esp.Box.Thickness = 1
    esp.Box.Color = Settings.ESP.Color
    esp.Box.Filled = false
    esp.Box.Visible = false
    esp.Name = Drawing.new("Text")
    esp.Name.Size = 14
    esp.Name.Center = true
    esp.Name.Outline = true
    esp.Name.Color = Color3.fromRGB(255, 255, 255)
    esp.Name.Visible = false
    esp.Health = Drawing.new("Text")
    esp.Health.Size = 12
    esp.Health.Center = false
    esp.Health.Outline = true
    esp.Health.Color = Color3.fromRGB(0, 255, 0)
    esp.Health.Visible = false
    esp.Distance = Drawing.new("Text")
    esp.Distance.Size = 12
    esp.Distance.Center = true
    esp.Distance.Outline = true
    esp.Distance.Color = Color3.fromRGB(200, 200, 200)
    esp.Distance.Visible = false
    ESPCache[player] = esp
end

local function removeESP(player)
    local esp = ESPCache[player]
    if esp then
        for _, v in pairs(esp) do
            v:Remove()
        end
        ESPCache[player] = nil
    end
end

local function hideESP(esp)
    esp.Box.Visible = false
    esp.Name.Visible = false
    esp.Health.Visible = false
    esp.Distance.Visible = false
end

local function updateESP()
    for player, esp in pairs(ESPCache) do
        local character = player.Character
        if not character or not Settings.ESP.Enabled then
            hideESP(esp)
            continue
        end
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        local root = character:FindFirstChild("HumanoidRootPart") or character:FindFirstChild("Head")
        if not humanoid or not root or humanoid.Health <= 0 then
            hideESP(esp)
            continue
        end
        local distance = (Camera.CFrame.Position - root.Position).Magnitude
        if distance > Settings.ESP.MaxDistance then
            hideESP(esp)
            continue
        end
        local screenPos, onScreen = Camera:WorldToViewportPoint(root.Position)
        if not onScreen then
            hideESP(esp)
            continue
        end
        local head = character:FindFirstChild("Head")
        local top = head and Camera:WorldToViewportPoint(head.Position + Vector3.new(0, 1, 0)) or screenPos
        local bottom = Camera:WorldToViewportPoint(root.Position - Vector3.new(0, 3, 0))
        local height = math.abs(top.Y - bottom.Y)
        local width = height * 0.5
        esp.Box.Size = Vector2.new(width, height)
        esp.Box.Position = Vector2.new(screenPos.X - width / 2, screenPos.Y - height / 2)
        esp.Box.Visible = Settings.ESP.Boxes
        esp.Name.Text = player.Name
        esp.Name.Position = Vector2.new(screenPos.X, screenPos.Y - height / 2 - 15)
        esp.Name.Visible = Settings.ESP.Names
        esp.Health.Text = math.floor(humanoid.Health) .. "/" .. math.floor(humanoid.MaxHealth)
        esp.Health.Position = Vector2.new(screenPos.X - width / 2 - 40, screenPos.Y - height / 2)
        esp.Health.Visible = Settings.ESP.Health
        esp.Distance.Text = math.floor(distance) .. " studs"
        esp.Distance.Position = Vector2.new(screenPos.X, screenPos.Y + height / 2 + 5)
        esp.Distance.Visible = Settings.ESP.Distance
    end
end

-- Aimbot Functions
local function getClosestPlayer()
    local closest = nil
    local shortest = Settings.Aimbot.FOV
    -- центр экрана (для мобилы) или позиция мыши
    local centerPos
    if IsMobile then
        local vp = Camera.ViewportSize
        centerPos = Vector2.new(vp.X / 2, vp.Y / 2)
    else
        centerPos = UserInputService:GetMouseLocation()
    end

    for _, player in pairs(Players:GetPlayers()) do
        if player == LocalPlayer then continue end
        if Settings.Aimbot.TeamCheck and player.Team == LocalPlayer.Team then continue end
        local character = player.Character
        if not character then continue end
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        if not humanoid or humanoid.Health <= 0 then continue end
        local part = character:FindFirstChild(Settings.Aimbot.TargetPart)
        if not part then continue end
        local screenPos, onScreen = Camera:WorldToViewportPoint(part.Position)
        if not onScreen then continue end
        local dist = (Vector2.new(screenPos.X, screenPos.Y) - centerPos).Magnitude
        if dist < shortest then
            if Settings.Aimbot.WallCheck then
                local ray = Ray.new(Camera.CFrame.Position, part.Position - Camera.CFrame.Position)
                local hit = workspace:FindPartOnRayWithIgnoreList(ray, {LocalPlayer.Character, character})
                if hit then continue end
            end
            shortest = dist
            closest = player
        end
    end
    return closest
end

local function aimAt(target)
    if not target or not target.Character then return end
    local part = target.Character:FindFirstChild(Settings.Aimbot.TargetPart)
    if not part then return end
    local targetPos = part.Position
    local currentCFrame = Camera.CFrame
    local newCFrame = CFrame.new(currentCFrame.Position, targetPos)
    Camera.CFrame = currentCFrame:Lerp(newCFrame, Settings.Aimbot.Smoothness)
end

-- FOV circle update
local function updateFOV()
    if not Settings.Aimbot.ShowFOV or not Settings.Aimbot.Enabled then
        FOVCircle.Visible = false
        return
    end
    FOVCircle.Visible = true
    local size = Settings.Aimbot.FOV * 2
    FOVCircle.Size = UDim2.new(0, size, 0, size)
    FOVCircle.Position = UDim2.new(0.5, 0, 0.5, 0)
    FOVCircle.ImageColor3 = AimTarget and Color3.fromRGB(255, 50, 50) or Color3.fromRGB(0, 255, 0)
end

-- Main Loops
RunService.RenderStepped:Connect(function()
    updateESP()
    updateFOV()

    local shouldAim = false
    if Settings.Aimbot.Enabled then
        if IsMobile and Settings.Aimbot.MobileMode then
            -- на мобиле аим работает всегда при включении
            shouldAim = true
        elseif UserInputService:IsMouseButtonPressed(Settings.Aimbot.Key) then
            shouldAim = true
        end
    end

    if shouldAim then
        local target = getClosestPlayer()
        if target then
            AimTarget = target
            aimAt(target)
        else
            AimTarget = nil
        end
    else
        AimTarget = nil
    end
end)

-- Player Events
Players.PlayerAdded:Connect(createESP)
Players.PlayerRemoving:Connect(removeESP)
for _, player in pairs(Players:GetPlayers()) do
    createESP(player)
end

-- Menu Toggle (ПК)
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Settings.Menu.Key then
        Settings.Menu.Open = not Settings.Menu.Open
        MainFrame.Visible = Settings.Menu.Open
    end
end)

-- Menu Toggle (мобила)
OpenButton.MouseButton1Click:Connect(function()
    Settings.Menu.Open = not Settings.Menu.Open
    MainFrame.Visible = Settings.Menu.Open
end)

MainFrame.Visible = Settings.Menu.Open
