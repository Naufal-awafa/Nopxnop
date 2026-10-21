--[[
    _   __                       ____                    
   / | / /___  ____  _  ______  / __ \____  ____  ____ _
  /  |/ / __ \/ __ \| |/_/ __ \/ / / / __ \/ __ \/ __ `/
 / /|  / /_/ / /_/ />  </ /_/ / /_/ / /_/ / /_/ / /_/ / 
/_/ |_/\____/ .___/_/|_/ .___/\____/ .___/ .___/\__,_/  
           /_/        /_/         /_/   /_/             
    
    [ Nopxnop v3.0 ] - Undetected, Lightweight Script for Fish It!
    Features: Venyx Modern UI + Floating Pop-up Toggle + Anti-Kick Engine
    Repository: https://github.com/Naufal-awafa/Nopxnop
--]]

-- Ensure game is fully loaded
if not game:IsLoaded() then
    game.Loaded:Wait()
end

-- Prevent duplicate script execution
if getgenv().NopxnopLoaded then
    pcall(function()
        if getgenv().NopxnopCleanup then
            getgenv().NopxnopCleanup()
        end
    end)
end
getgenv().NopxnopLoaded = true

-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local VirtualUser = game:GetService("VirtualUser")
local VirtualInputManager = game:GetService("VirtualInputManager")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local CoreGui = game:GetService("CoreGui")
local GuiService = game:GetService("GuiService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

-- ==============================================================================
-- 1. ERROR & DISCONNECT SUPPRESSION (Prevents Error Code 267)
-- ==============================================================================
pcall(function()
    GuiService.ErrorMessageChanged:Connect(function()
        pcall(function()
            GuiService:ClearError()
        end)
    end)
end)

-- Safe function hook on Kick without touching DataModel metamethods
pcall(function()
    if hookfunction and LocalPlayer.Kick then
        hookfunction(LocalPlayer.Kick, function(...)
            return nil
        end)
    end
end)

-- ==============================================================================
-- 2. CONFIGURATION & STATE
-- ==============================================================================
local Config = {
    AutoCast = false,
    CastDelay = 1.5,
    AutoShake = false,
    AutoReel = false,
    AutoEquipRod = true,
    AutoSell = false,
    SellDelay = 60,
    SpeedBoost = 1,
    InfJump = false,
    InfOxygen = false,
    Noclip = false,
    AntiAFK = true,
    FullBright = false,
    SafePlatform = false,
    MenuVisible = true
}

local Connections = {}
local SafePlatformPart = nil
local OriginalLighting = {
    Ambient = Lighting.Ambient,
    OutdoorAmbient = Lighting.OutdoorAmbient,
    Brightness = Lighting.Brightness,
    ClockTime = Lighting.ClockTime,
    FogEnd = Lighting.FogEnd
}

-- Character Helpers
local function getCharacter()
    return LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
end

local function getHumanoid()
    local char = getCharacter()
    return char and char:FindFirstChildOfClass("Humanoid")
end

local function getRootPart()
    local char = getCharacter()
    return char and (char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso"))
end

-- Find Fishing Rod Tool
local function findRod()
    local char = LocalPlayer.Character
    if char then
        for _, item in ipairs(char:GetChildren()) do
            if item:IsA("Tool") and (item.Name:lower():find("rod") or item:FindFirstChild("Bobber") or item:FindFirstChild("Cast") or item:FindFirstChild("Values")) then
                return item, true
            end
        end
    end
    
    local backpack = LocalPlayer:FindFirstChild("Backpack")
    if backpack then
        for _, item in ipairs(backpack:GetChildren()) do
            if item:IsA("Tool") and (item.Name:lower():find("rod") or item:FindFirstChild("Bobber") or item:FindFirstChild("Cast") or item:FindFirstChild("Values")) then
                return item, false
            end
        end
    end
    
    if char then
        local tool = char:FindFirstChildOfClass("Tool")
        if tool then return tool, true end
    end
    if backpack then
        local tool = backpack:FindFirstChildOfClass("Tool")
        if tool then return tool, false end
    end
    
    return nil, false
end

local function equipRod()
    local rod, isEquipped = findRod()
    if rod and not isEquipped then
        local hum = getHumanoid()
        if hum then
            hum:EquipTool(rod)
            task.wait(0.25)
        end
    end
    return rod
end

local function performCast()
    local rod, isEquipped = findRod()
    if not rod then return end
    if not isEquipped then
        rod = equipRod()
    end
    if not rod or not rod.Parent or rod.Parent ~= LocalPlayer.Character then return end

    -- Safe natural activation (Never spams blind network remotes)
    pcall(function()
        rod:Activate()
    end)
    pcall(function()
        VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 1)
        task.wait(0.08)
        VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 1)
    end)
end

-- ==============================================================================
-- 3. STEALTH GUI SYSTEM (HIGH PRIORITY DISPLAY & FLOATING POP-UP)
-- ==============================================================================

local function createProtectedGui()
    local gui = Instance.new("ScreenGui")
    gui.ResetOnSpawn = false
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.DisplayOrder = 999999
    gui.IgnoreGuiInset = true
    gui.Name = "Nopxnop_UI_" .. tostring(math.random(10000, 99999))

    local attached = false

    -- 1. gethui() (Safest executor hidden container)
    if not attached and gethui then
        pcall(function()
            gui.Parent = gethui()
            attached = true
        end)
    end

    -- 2. CoreGui directly
    if not attached and CoreGui then
        pcall(function()
            gui.Parent = CoreGui
            attached = true
        end)
    end

    -- 3. Fallback: PlayerGui
    if not attached then
        gui.Parent = PlayerGui
    end

    return gui
end

local ScreenGui = createProtectedGui()

-- Theme Palette (Venyx Sleek Dark)
local Theme = {
    Background = Color3.fromRGB(18, 18, 24),
    Sidebar = Color3.fromRGB(13, 13, 18),
    Accent = Color3.fromRGB(0, 162, 255),
    AccentDark = Color3.fromRGB(0, 120, 200),
    Card = Color3.fromRGB(25, 25, 34),
    Text = Color3.fromRGB(245, 245, 252),
    SubText = Color3.fromRGB(145, 145, 160),
    ToggleOff = Color3.fromRGB(42, 42, 54),
    Border = Color3.fromRGB(34, 34, 46)
}

-- ------------------------------------------------------------------------------
-- A. FLOATING MINI POP-UP TOGGLE BUTTON
-- ------------------------------------------------------------------------------
local FloatWidget = Instance.new("Frame")
FloatWidget.Name = "FloatWidget"
FloatWidget.Size = UDim2.new(0, 56, 0, 56)
FloatWidget.Position = UDim2.new(0, 24, 0, 160)
FloatWidget.BackgroundColor3 = Theme.Sidebar
FloatWidget.BorderSizePixel = 0
FloatWidget.ZIndex = 100
FloatWidget.Parent = ScreenGui

local FloatCorner = Instance.new("UICorner")
FloatCorner.CornerRadius = UDim.new(0, 28)
FloatCorner.Parent = FloatWidget

local FloatStroke = Instance.new("UIStroke")
FloatStroke.Color = Theme.Accent
FloatStroke.Thickness = 2.5
FloatStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
FloatStroke.Parent = FloatWidget

local FloatIcon = Instance.new("TextLabel")
FloatIcon.Size = UDim2.new(1, 0, 1, 0)
FloatIcon.BackgroundTransparency = 1
FloatIcon.Text = "🎣"
FloatIcon.TextSize = 26
FloatIcon.Font = Enum.Font.GothamBold
FloatIcon.TextColor3 = Theme.Text
FloatIcon.ZIndex = 101
FloatIcon.Parent = FloatWidget

local FloatPill = Instance.new("TextLabel")
FloatPill.Size = UDim2.new(0, 42, 0, 14)
FloatPill.Position = UDim2.new(0.5, -21, 1, -8)
FloatPill.BackgroundColor3 = Theme.Accent
FloatPill.Text = "NOP"
FloatPill.TextColor3 = Color3.fromRGB(255, 255, 255)
FloatPill.Font = Enum.Font.GothamBlack
FloatPill.TextSize = 9
FloatPill.BorderSizePixel = 0
FloatPill.ZIndex = 102
FloatPill.Parent = FloatWidget

local FloatPillCorner = Instance.new("UICorner")
FloatPillCorner.CornerRadius = UDim.new(0, 7)
FloatPillCorner.Parent = FloatPill

local FloatBtn = Instance.new("TextButton")
FloatBtn.Size = UDim2.new(1, 0, 1, 0)
FloatBtn.BackgroundTransparency = 1
FloatBtn.Text = ""
FloatBtn.ZIndex = 105
FloatBtn.Active = true
FloatBtn.Parent = FloatWidget

-- ------------------------------------------------------------------------------
-- B. MAIN VENYX MENU CONTAINER
-- ------------------------------------------------------------------------------
local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 560, 0, 360)
MainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
MainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
MainFrame.BackgroundColor3 = Theme.Background
MainFrame.BorderSizePixel = 0
MainFrame.ClipsDescendants = true
MainFrame.Visible = true
MainFrame.ZIndex = 10
MainFrame.Parent = ScreenGui

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 10)
MainCorner.Parent = MainFrame

local MainStroke = Instance.new("UIStroke")
MainStroke.Color = Theme.Border
MainStroke.Thickness = 1.2
MainStroke.Parent = MainFrame

-- Header Bar
local Header = Instance.new("Frame")
Header.Name = "Header"
Header.Size = UDim2.new(1, 0, 0, 42)
Header.BackgroundColor3 = Theme.Sidebar
Header.BorderSizePixel = 0
Header.ZIndex = 11
Header.Parent = MainFrame

local HeaderCorner = Instance.new("UICorner")
HeaderCorner.CornerRadius = UDim.new(0, 10)
HeaderCorner.Parent = Header

local HeaderCover = Instance.new("Frame")
HeaderCover.Size = UDim2.new(1, 0, 0, 10)
HeaderCover.Position = UDim2.new(0, 0, 1, -10)
HeaderCover.BackgroundColor3 = Theme.Sidebar
HeaderCover.BorderSizePixel = 0
HeaderCover.ZIndex = 11
HeaderCover.Parent = Header

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(0, 260, 1, 0)
Title.Position = UDim2.new(0, 15, 0, 0)
Title.BackgroundTransparency = 1
Title.Text = "Nopxnop <font color=\"#00a2ff\">Fish It!</font> <font color=\"#777788\">v3.0</font>"
Title.RichText = true
Title.TextColor3 = Theme.Text
Title.Font = Enum.Font.GothamBold
Title.TextSize = 15
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.ZIndex = 12
Title.Parent = Header

-- Minimize Button (Shrinks Main Menu into Floating Pop-Up)
local MinimizeBtn = Instance.new("TextButton")
MinimizeBtn.Size = UDim2.new(0, 32, 0, 32)
MinimizeBtn.Position = UDim2.new(1, -74, 0, 5)
MinimizeBtn.BackgroundColor3 = Theme.Card
MinimizeBtn.Text = "—"
MinimizeBtn.TextColor3 = Theme.SubText
MinimizeBtn.Font = Enum.Font.GothamBold
MinimizeBtn.TextSize = 14
MinimizeBtn.AutoButtonColor = false
MinimizeBtn.ZIndex = 13
MinimizeBtn.Parent = Header

local MinCorner = Instance.new("UICorner")
MinCorner.CornerRadius = UDim.new(0, 6)
MinCorner.Parent = MinimizeBtn

-- Close Button
local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0, 32, 0, 32)
CloseBtn.Position = UDim2.new(1, -38, 0, 5)
CloseBtn.BackgroundColor3 = Color3.fromRGB(180, 45, 55)
CloseBtn.Text = "✕"
CloseBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.TextSize = 13
CloseBtn.AutoButtonColor = false
CloseBtn.ZIndex = 13
CloseBtn.Parent = Header

local CloseCorner = Instance.new("UICorner")
CloseCorner.CornerRadius = UDim.new(0, 6)
CloseCorner.Parent = CloseBtn

-- Toggle Menu Function (Smooth Pop-Up Switch)
local function toggleMenu(forceState)
    if forceState ~= nil then
        Config.MenuVisible = forceState
    else
        Config.MenuVisible = not Config.MenuVisible
    end

    if Config.MenuVisible then
        MainFrame.Visible = true
        MainFrame.Size = UDim2.new(0, 560, 0, 0)
        MainFrame.BackgroundTransparency = 1
        TweenService:Create(MainFrame, TweenInfo.new(0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
            Size = UDim2.new(0, 560, 0, 360),
            BackgroundTransparency = 0
        }):Play()
        FloatStroke.Color = Theme.Accent
        FloatWidget.BackgroundTransparency = 0.2
    else
        local tw = TweenService:Create(MainFrame, TweenInfo.new(0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.In), {
            Size = UDim2.new(0, 560, 0, 0),
            BackgroundTransparency = 1
        })
        tw:Play()
        tw.Completed:Connect(function()
            if not Config.MenuVisible then
                MainFrame.Visible = false
            end
        end)
        FloatStroke.Color = Theme.Border
        FloatWidget.BackgroundTransparency = 0
    end
end

MinimizeBtn.MouseButton1Click:Connect(function()
    toggleMenu(false)
end)

CloseBtn.MouseButton1Click:Connect(function()
    toggleMenu(false)
end)

-- Drag vs Tap handler for Floating Button
local isDragging = false
local dragStartPos = nil
local frameStartPos = nil
local hasMoved = false

FloatBtn.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        isDragging = true
        hasMoved = false
        dragStartPos = input.Position
        frameStartPos = FloatWidget.Position

        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                isDragging = false
                if not hasMoved then
                    toggleMenu()
                end
            end
        end)
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if isDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - dragStartPos
        if delta.Magnitude > 5 then
            hasMoved = true
            FloatWidget.Position = UDim2.new(
                frameStartPos.X.Scale,
                frameStartPos.X.Offset + delta.X,
                frameStartPos.Y.Scale,
                frameStartPos.Y.Offset + delta.Y
            )
        end
    end
end)

-- Make Main Window draggable by Header
local isWinDragging = false
local winDragStart = nil
local winStartPos = nil

Header.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        isWinDragging = true
        winDragStart = input.Position
        winStartPos = MainFrame.Position

        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                isWinDragging = false
            end
        end)
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if isWinDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - winDragStart
        MainFrame.Position = UDim2.new(
            winStartPos.X.Scale,
            winStartPos.X.Offset + delta.X,
            winStartPos.Y.Scale,
            winStartPos.Y.Offset + delta.Y
        )
    end
end)

-- Sidebar for Venyx Tabs
local Sidebar = Instance.new("Frame")
Sidebar.Name = "Sidebar"
Sidebar.Size = UDim2.new(0, 130, 1, -42)
Sidebar.Position = UDim2.new(0, 0, 0, 42)
Sidebar.BackgroundColor3 = Theme.Sidebar
Sidebar.BorderSizePixel = 0
Sidebar.ZIndex = 11
Sidebar.Parent = MainFrame

local SidebarLayout = Instance.new("UIListLayout")
SidebarLayout.Padding = UDim.new(0, 4)
SidebarLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
SidebarLayout.SortOrder = Enum.SortOrder.LayoutOrder
SidebarLayout.Parent = Sidebar

local SidebarPadding = Instance.new("UIPadding")
SidebarPadding.PaddingTop = UDim.new(0, 10)
SidebarPadding.PaddingBottom = UDim.new(0, 10)
SidebarPadding.PaddingLeft = UDim.new(0, 6)
SidebarPadding.PaddingRight = UDim.new(0, 6)
SidebarPadding.Parent = Sidebar

-- Content Display
local Content = Instance.new("Frame")
Content.Name = "Content"
Content.Size = UDim2.new(1, -136, 1, -48)
Content.Position = UDim2.new(0, 133, 0, 45)
Content.BackgroundTransparency = 1
Content.ClipsDescendants = true
Content.ZIndex = 11
Content.Parent = MainFrame

-- Tab System Builder
local Tabs = {}
local TabButtons = {}
local activeTab = nil

local function addTab(tabName, icon)
    local Page = Instance.new("ScrollingFrame")
    Page.Name = tabName .. "Page"
    Page.Size = UDim2.new(1, 0, 1, 0)
    Page.BackgroundTransparency = 1
    Page.BorderSizePixel = 0
    Page.ScrollBarThickness = 4
    Page.ScrollBarImageColor3 = Theme.Accent
    Page.CanvasSize = UDim2.new(0, 0, 0, 0)
    Page.Visible = false
    Page.ZIndex = 12
    Page.Parent = Content

    local Layout = Instance.new("UIListLayout")
    Layout.Padding = UDim.new(0, 8)
    Layout.SortOrder = Enum.SortOrder.LayoutOrder
    Layout.Parent = Page

    local Padding = Instance.new("UIPadding")
    Padding.PaddingTop = UDim.new(0, 4)
    Padding.PaddingBottom = UDim.new(0, 8)
    Padding.PaddingLeft = UDim.new(0, 4)
    Padding.PaddingRight = UDim.new(0, 8)
    Padding.Parent = Page

    Layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        Page.CanvasSize = UDim2.new(0, 0, 0, Layout.AbsoluteContentSize.Y + 16)
    end)

    local TabBtn = Instance.new("TextButton")
    TabBtn.Size = UDim2.new(1, 0, 0, 34)
    TabBtn.BackgroundColor3 = Theme.Sidebar
    TabBtn.Text = (icon or "•") .. "  " .. tabName
    TabBtn.TextColor3 = Theme.SubText
    TabBtn.Font = Enum.Font.GothamMedium
    TabBtn.TextSize = 13
    TabBtn.TextXAlignment = Enum.TextXAlignment.Left
    TabBtn.AutoButtonColor = false
    TabBtn.ZIndex = 12
    TabBtn.Parent = Sidebar

    local TabBtnCorner = Instance.new("UICorner")
    TabBtnCorner.CornerRadius = UDim.new(0, 6)
    TabBtnCorner.Parent = TabBtn

    local TabBtnPad = Instance.new("UIPadding")
    TabBtnPad.PaddingLeft = UDim.new(0, 12)
    TabBtnPad.Parent = TabBtn

    local function selectTab()
        for _, p in pairs(Tabs) do p.Visible = false end
        for _, b in pairs(TabButtons) do
            b.BackgroundColor3 = Theme.Sidebar
            b.TextColor3 = Theme.SubText
            b.Font = Enum.Font.GothamMedium
        end
        Page.Visible = true
        TabBtn.BackgroundColor3 = Theme.Card
        TabBtn.TextColor3 = Theme.Accent
        TabBtn.Font = Enum.Font.GothamBold
        activeTab = tabName
    end

    TabBtn.MouseButton1Click:Connect(selectTab)
    Tabs[tabName] = Page
    TabButtons[tabName] = TabBtn

    if activeTab == nil then selectTab() end

    local tabMethods = {}

    function tabMethods:addSection(title)
        local SecFrame = Instance.new("Frame")
        SecFrame.Size = UDim2.new(1, 0, 0, 24)
        SecFrame.BackgroundColor3 = Theme.Card
        SecFrame.BorderSizePixel = 0
        SecFrame.ZIndex = 13
        SecFrame.Parent = Page

        local SC = Instance.new("UICorner")
        SC.CornerRadius = UDim.new(0, 6)
        SC.Parent = SecFrame

        local ST = Instance.new("TextLabel")
        ST.Size = UDim2.new(1, -12, 1, 0)
        ST.Position = UDim2.new(0, 10, 0, 0)
        ST.BackgroundTransparency = 1
        ST.Text = title:upper()
        ST.TextColor3 = Theme.Accent
        ST.Font = Enum.Font.GothamBold
        ST.TextSize = 11
        ST.TextXAlignment = Enum.TextXAlignment.Left
        ST.ZIndex = 14
        ST.Parent = SecFrame

        local secMethods = {}

        function secMethods:addToggle(name, default, callback)
            local Frame = Instance.new("Frame")
            Frame.Size = UDim2.new(1, 0, 0, 36)
            Frame.BackgroundColor3 = Theme.Card
            Frame.BorderSizePixel = 0
            Frame.ZIndex = 13
            Frame.Parent = Page

            local FC = Instance.new("UICorner")
            FC.CornerRadius = UDim.new(0, 6)
            FC.Parent = Frame

            local Label = Instance.new("TextLabel")
            Label.Size = UDim2.new(1, -60, 1, 0)
            Label.Position = UDim2.new(0, 12, 0, 0)
            Label.BackgroundTransparency = 1
            Label.Text = name
            Label.TextColor3 = Theme.Text
            Label.Font = Enum.Font.Gotham
            Label.TextSize = 13
            Label.TextXAlignment = Enum.TextXAlignment.Left
            Label.ZIndex = 14
            Label.Parent = Frame

            local Switch = Instance.new("TextButton")
            Switch.Size = UDim2.new(0, 42, 0, 22)
            Switch.Position = UDim2.new(1, -52, 0.5, -11)
            Switch.BackgroundColor3 = default and Theme.Accent or Theme.ToggleOff
            Switch.Text = ""
            Switch.AutoButtonColor = false
            Switch.ZIndex = 14
            Switch.Parent = Frame

            local SwitchCorner = Instance.new("UICorner")
            SwitchCorner.CornerRadius = UDim.new(0, 11)
            SwitchCorner.Parent = Switch

            local Circle = Instance.new("Frame")
            Circle.Size = UDim2.new(0, 16, 0, 16)
            Circle.Position = default and UDim2.new(1, -19, 0.5, -8) or UDim2.new(0, 3, 0.5, -8)
            Circle.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
            Circle.BorderSizePixel = 0
            Circle.ZIndex = 15
            Circle.Parent = Switch

            local CC = Instance.new("UICorner")
            CC.CornerRadius = UDim.new(0, 8)
            CC.Parent = Circle

            local state = default

            local function setState(v)
                state = v
                local targetPos = state and UDim2.new(1, -19, 0.5, -8) or UDim2.new(0, 3, 0.5, -8)
                local targetColor = state and Theme.Accent or Theme.ToggleOff
                TweenService:Create(Circle, TweenInfo.new(0.18, Enum.EasingStyle.Quart), {Position = targetPos}):Play()
                TweenService:Create(Switch, TweenInfo.new(0.18, Enum.EasingStyle.Quart), {BackgroundColor3 = targetColor}):Play()
                if callback then pcall(callback, state) end
            end

            Switch.MouseButton1Click:Connect(function()
                setState(not state)
            end)
        end

        function secMethods:addSlider(name, default, min, max, callback)
            local SFrame = Instance.new("Frame")
            SFrame.Size = UDim2.new(1, 0, 0, 48)
            SFrame.BackgroundColor3 = Theme.Card
            SFrame.BorderSizePixel = 0
            SFrame.ZIndex = 13
            SFrame.Parent = Page

            local SC = Instance.new("UICorner")
            SC.CornerRadius = UDim.new(0, 6)
            SC.Parent = SFrame

            local SLabel = Instance.new("TextLabel")
            SLabel.Size = UDim2.new(1, -80, 0, 20)
            SLabel.Position = UDim2.new(0, 12, 0, 6)
            SLabel.BackgroundTransparency = 1
            SLabel.Text = name
            SLabel.TextColor3 = Theme.Text
            SLabel.Font = Enum.Font.Gotham
            SLabel.TextSize = 13
            SLabel.TextXAlignment = Enum.TextXAlignment.Left
            SLabel.ZIndex = 14
            SLabel.Parent = SFrame

            local SVal = Instance.new("TextLabel")
            SVal.Size = UDim2.new(0, 60, 0, 20)
            SVal.Position = UDim2.new(1, -70, 0, 6)
            SVal.BackgroundTransparency = 1
            SVal.Text = tostring(default)
            SVal.TextColor3 = Theme.Accent
            SVal.Font = Enum.Font.GothamBold
            SVal.TextSize = 13
            SVal.TextXAlignment = Enum.TextXAlignment.Right
            SVal.ZIndex = 14
            SVal.Parent = SFrame

            local Track = Instance.new("TextButton")
            Track.Size = UDim2.new(1, -24, 0, 6)
            Track.Position = UDim2.new(0, 12, 0, 32)
            Track.BackgroundColor3 = Theme.ToggleOff
            Track.Text = ""
            Track.AutoButtonColor = false
            Track.ZIndex = 14
            Track.Parent = SFrame

            local TC = Instance.new("UICorner")
            TC.CornerRadius = UDim.new(0, 3)
            TC.Parent = Track

            local Fill = Instance.new("Frame")
            local initPct = math.clamp((default - min) / (max - min), 0, 1)
            Fill.Size = UDim2.new(initPct, 0, 1, 0)
            Fill.BackgroundColor3 = Theme.Accent
            Fill.BorderSizePixel = 0
            Fill.ZIndex = 15
            Fill.Parent = Track

            local FC = Instance.new("UICorner")
            FC.CornerRadius = UDim.new(0, 3)
            FC.Parent = Fill

            local sliding = false

            local function update(input)
                local pct = math.clamp((input.Position.X - Track.AbsolutePosition.X) / Track.AbsoluteSize.X, 0, 1)
                local val = math.floor(min + (max - min) * pct)
                Fill.Size = UDim2.new(pct, 0, 1, 0)
                SVal.Text = tostring(val)
                if callback then pcall(callback, val) end
            end

            Track.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                    sliding = true
                    update(input)
                end
            end)

            UserInputService.InputEnded:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                    sliding = false
                end
            end)

            UserInputService.InputChanged:Connect(function(input)
                if sliding and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                    update(input)
                end
            end)
        end

        function secMethods:addButton(name, callback)
            local BFrame = Instance.new("Frame")
            BFrame.Size = UDim2.new(1, 0, 0, 36)
            BFrame.BackgroundColor3 = Theme.Card
            BFrame.BorderSizePixel = 0
            BFrame.ZIndex = 13
            BFrame.Parent = Page

            local BC = Instance.new("UICorner")
            BC.CornerRadius = UDim.new(0, 6)
            BC.Parent = BFrame

            local ActionBtn = Instance.new("TextButton")
            ActionBtn.Size = UDim2.new(1, -16, 1, -8)
            ActionBtn.Position = UDim2.new(0, 8, 0, 4)
            ActionBtn.BackgroundColor3 = Theme.Sidebar
            ActionBtn.Text = name
            ActionBtn.TextColor3 = Theme.Text
            ActionBtn.Font = Enum.Font.GothamMedium
            ActionBtn.TextSize = 13
            ActionBtn.AutoButtonColor = false
            ActionBtn.ZIndex = 14
            ActionBtn.Parent = BFrame

            local AC = Instance.new("UICorner")
            AC.CornerRadius = UDim.new(0, 5)
            AC.Parent = ActionBtn

            ActionBtn.MouseButton1Click:Connect(function()
                TweenService:Create(ActionBtn, TweenInfo.new(0.1), {BackgroundColor3 = Theme.Accent}):Play()
                task.wait(0.1)
                TweenService:Create(ActionBtn, TweenInfo.new(0.15), {BackgroundColor3 = Theme.Sidebar}):Play()
                if callback then pcall(callback) end
            end)
        end

        return secMethods
    end

    return tabMethods
end

-- Create Pages
local PageFishing = addTab("Fishing", "🎣")
local PageTeleport = addTab("Teleport", "🏝️")
local PagePlayer = addTab("Player", "🏃")
local PageSettings = addTab("Settings", "⚙️")

-- ==============================================================================
-- 4. FISHING FEATURES
-- ==============================================================================
local SecFish = PageFishing:addSection("Automation")

SecFish:addToggle("Auto Cast Rod", Config.AutoCast, function(state)
    Config.AutoCast = state
    if state then
        task.spawn(function()
            while Config.AutoCast do
                if Config.AutoEquipRod then
                    equipRod()
                end
                performCast()
                task.wait(Config.CastDelay)
            end
        end)
    end
end)

SecFish:addSlider("Cast Delay (ms)", math.floor(Config.CastDelay * 1000), 800, 3500, function(value)
    Config.CastDelay = value / 1000
end)

SecFish:addToggle("Auto Shake (Minigame)", Config.AutoShake, function(state)
    Config.AutoShake = state
    if state then
        task.spawn(function()
            while Config.AutoShake do
                pcall(function()
                    for _, gui in ipairs(PlayerGui:GetChildren()) do
                        if gui:IsA("ScreenGui") and gui.Enabled then
                            local gName = gui.Name:lower()
                            if gName:find("shake") or gName:find("fish") or gName:find("minigame") or gName:find("reel") or gName:find("bar") then
                                for _, btn in ipairs(gui:GetDescendants()) do
                                    if (btn:IsA("ImageButton") or btn:IsA("TextButton")) and btn.Visible and btn.Active then
                                        pcall(function()
                                            if getconnections then
                                                for _, conn in ipairs(getconnections(btn.MouseButton1Click)) do conn:Fire() end
                                                for _, conn in ipairs(getconnections(btn.Activated)) do conn:Fire() end
                                            end
                                        end)
                                        local center = btn.AbsolutePosition + (btn.AbsoluteSize / 2)
                                        VirtualInputManager:SendMouseButtonEvent(center.X, center.Y, 0, true, game, 1)
                                        task.wait(0.02)
                                        VirtualInputManager:SendMouseButtonEvent(center.X, center.Y, 0, false, game, 1)
                                    end
                                end
                            end
                        end
                    end
                end)
                task.wait(0.12)
            end
        end)
    end
end)

SecFish:addToggle("Auto Reel (Natural CPS)", Config.AutoReel, function(state)
    Config.AutoReel = state
    if state then
        task.spawn(function()
            while Config.AutoReel do
                pcall(function()
                    -- Natural human-like reeling rate (8-9 clicks/sec)
                    local mousePos = UserInputService:GetMouseLocation()
                    VirtualInputManager:SendMouseButtonEvent(mousePos.X, mousePos.Y, 0, true, game, 1)
                    task.wait(0.05)
                    VirtualInputManager:SendMouseButtonEvent(mousePos.X, mousePos.Y, 0, false, game, 1)
                end)
                task.wait(0.08)
            end
        end)
    end
end)

SecFish:addToggle("Auto Equip Rod", Config.AutoEquipRod, function(state)
    Config.AutoEquipRod = state
    if state then equipRod() end
end)

local SecEco = PageFishing:addSection("Economy & Selling")

local function sellFishSafely()
    pcall(function()
        for _, obj in ipairs(workspace:GetDescendants()) do
            if obj:IsA("ProximityPrompt") then
                local aText = tostring(obj.ActionText):lower()
                local oText = tostring(obj.ObjectText):lower()
                if aText:find("sell") or oText:find("sell") or oText:find("merchant") then
                    fireproximityprompt(obj)
                end
            end
        end
    end)
end

SecEco:addButton("Sell All Fish (Merchant)", function()
    sellFishSafely()
end)

SecEco:addToggle("Auto Sell (Loop)", Config.AutoSell, function(state)
    Config.AutoSell = state
    if state then
        task.spawn(function()
            while Config.AutoSell do
                task.wait(Config.SellDelay)
                if not Config.AutoSell then break end
                sellFishSafely()
            end
        end)
    end
end)

SecEco:addSlider("Auto Sell Interval (s)", Config.SellDelay, 20, 180, function(value)
    Config.SellDelay = value
end)

-- ==============================================================================
-- 5. TELEPORTS
-- ==============================================================================
local SecTP = PageTeleport:addSection("Islands & Zones")

local Locations = {
    ["Starter Island / Spawn"] = Vector3.new(0, 15, 0),
    ["Sell Merchant / Shop"]   = Vector3.new(45, 12, -120),
    ["Coral Reef Island"]      = Vector3.new(-320, 10, 240),
    ["Volcano / Magma Zone"]   = Vector3.new(650, 20, 850),
    ["Deep Sunken Trench"]     = Vector3.new(-750, -50, -420),
    ["Ancient Shrine Isle"]    = Vector3.new(1200, 35, -600),
    ["Rod & Equipment Shop"]   = Vector3.new(80, 12, -90)
}

local function safeTeleport(pos)
    local root = getRootPart()
    if root then
        root.CFrame = CFrame.new(pos + Vector3.new(0, 3, 0))
        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
    end
end

for name, pos in pairs(Locations) do
    SecTP:addButton(name, function()
        safeTeleport(pos)
    end)
end

local SecSky = PageTeleport:addSection("AFK Sky Platform")

SecSky:addToggle("Safe Sky Fishing Platform", Config.SafePlatform, function(state)
    Config.SafePlatform = state
    if state then
        local root = getRootPart()
        if root then
            if not SafePlatformPart or not SafePlatformPart.Parent then
                SafePlatformPart = Instance.new("Part")
                SafePlatformPart.Name = "SkySafe_Part"
                SafePlatformPart.Size = Vector3.new(24, 2, 24)
                SafePlatformPart.Anchored = true
                SafePlatformPart.CanCollide = true
                SafePlatformPart.Material = Enum.Material.ForceField
                SafePlatformPart.Color = Color3.fromRGB(0, 162, 255)
                SafePlatformPart.Transparency = 0.35
                SafePlatformPart.Parent = workspace
            end
            local highPos = root.Position + Vector3.new(0, 80, 0)
            SafePlatformPart.Position = highPos - Vector3.new(0, 2, 0)
            root.CFrame = CFrame.new(highPos + Vector3.new(0, 2, 0))
            root.AssemblyLinearVelocity = Vector3.zero
        end
    else
        if SafePlatformPart and SafePlatformPart.Parent then
            SafePlatformPart:Destroy()
            SafePlatformPart = nil
        end
    end
end)

-- ==============================================================================
-- 6. PLAYER & MOVEMENT (STEALTH VELOCITY TRANSLATION)
-- ==============================================================================
local SecMove = PagePlayer:addSection("Stealth Movement")

SecMove:addSlider("Speed Boost", 1, 1, 4, function(value)
    Config.SpeedBoost = value
end)

Connections.StealthSpeed = RunService.RenderStepped:Connect(function()
    if Config.SpeedBoost > 1 then
        local hum = getHumanoid()
        local root = getRootPart()
        if hum and root and hum.MoveDirection.Magnitude > 0 then
            local boostFactor = (Config.SpeedBoost - 1) * 0.25
            root.CFrame = root.CFrame + (hum.MoveDirection * boostFactor)
        end
    end
end)

SecMove:addToggle("Infinite Jump", Config.InfJump, function(state)
    Config.InfJump = state
end)

Connections.InfJump = UserInputService.JumpRequest:Connect(function()
    if Config.InfJump then
        local hum = getHumanoid()
        if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
    end
end)

SecMove:addToggle("Noclip", Config.Noclip, function(state)
    Config.Noclip = state
end)

Connections.Noclip = RunService.Stepped:Connect(function()
    if Config.Noclip then
        local char = LocalPlayer.Character
        if char then
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" and part.CanCollide then
                    part.CanCollide = false
                end
            end
        end
    end
end)

local SecSurv = PagePlayer:addSection("Survival")

SecSurv:addToggle("Infinite Oxygen", Config.InfOxygen, function(state)
    Config.InfOxygen = state
    if state then
        task.spawn(function()
            while Config.InfOxygen do
                pcall(function()
                    local char = LocalPlayer.Character
                    if char then
                        if char:GetAttribute("Oxygen") ~= nil then char:SetAttribute("Oxygen", 100) end
                        if char:GetAttribute("Air") ~= nil then char:SetAttribute("Air", 100) end
                        local o = char:FindFirstChild("Oxygen") or char:FindFirstChild("Air")
                        if o and (o:IsA("NumberValue") or o:IsA("IntValue")) then o.Value = 100 end
                    end
                end)
                task.wait(1)
            end
        end)
    end
end)

SecSurv:addToggle("Anti-AFK (Idle Kick Bypass)", Config.AntiAFK, function(state)
    Config.AntiAFK = state
end)

Connections.AntiAFK = LocalPlayer.Idled:Connect(function()
    if Config.AntiAFK then
        pcall(function()
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new())
        end)
    end
end)

-- ==============================================================================
-- 7. SETTINGS & VISUALS
-- ==============================================================================
local SecVis = PageSettings:addSection("Visuals")

SecVis:addToggle("FullBright", Config.FullBright, function(state)
    Config.FullBright = state
    if state then
        Lighting.Ambient = Color3.fromRGB(255, 255, 255)
        Lighting.OutdoorAmbient = Color3.fromRGB(255, 255, 255)
        Lighting.Brightness = 2
        Lighting.FogEnd = 100000
    else
        Lighting.Ambient = OriginalLighting.Ambient
        Lighting.OutdoorAmbient = OriginalLighting.OutdoorAmbient
        Lighting.Brightness = OriginalLighting.Brightness
        Lighting.FogEnd = OriginalLighting.FogEnd
    end
end)

local SecCtrl = PageSettings:addSection("Controls")

SecCtrl:addButton("Rejoin Server", function()
    local ts = game:GetService("TeleportService")
    ts:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
end)

SecCtrl:addButton("Unload Script", function()
    if getgenv().NopxnopCleanup then
        getgenv().NopxnopCleanup()
    end
end)

-- Cleanup Routine
getgenv().NopxnopCleanup = function()
    for _, conn in pairs(Connections) do
        if conn and conn.Disconnect then conn:Disconnect() end
    end
    Lighting.Ambient = OriginalLighting.Ambient
    Lighting.OutdoorAmbient = OriginalLighting.OutdoorAmbient
    Lighting.Brightness = OriginalLighting.Brightness
    Lighting.FogEnd = OriginalLighting.FogEnd
    if SafePlatformPart and SafePlatformPart.Parent then
        SafePlatformPart:Destroy()
    end
    if ScreenGui and ScreenGui.Parent then
        ScreenGui:Destroy()
    end
    getgenv().NopxnopLoaded = false
end

-- Keyboard Shortcut: RightShift or RightControl
Connections.KeybindToggle = UserInputService.InputBegan:Connect(function(input, processed)
    if not processed and (input.KeyCode == Enum.KeyCode.RightShift or input.KeyCode == Enum.KeyCode.RightControl) then
        toggleMenu()
    end
end)

print([[
======================================================
   [Nopxnop v3.0] Running & Undetected!
   - Floating Pop-up Widget: Active
   - Venyx Menu: Centered & High Priority
   - Tap 🎣 or press RightShift to Toggle
======================================================
]])
