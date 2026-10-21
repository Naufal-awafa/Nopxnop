--[[
    _   __                       ____                    
   / | / /___  ____  _  ______  / __ \____  ____  ____ _
  /  |/ / __ \/ __ \| |/_/ __ \/ / / / __ \/ __ \/ __ `/
 / /|  / /_/ / /_/ />  </ /_/ / /_/ / /_/ / /_/ / /_/ / 
/_/ |_/\____/ .___/_/|_/ .___/\____/ .___/ .___/\__,_/  
           /_/        /_/         /_/   /_/             
    
    [ Nopxnop v2.0 ] - Undetected & Lightweight Script for Fish It!
    Features: Venyx UI + Floating Pop-up Toggle + BAC Bypass
    Repository: https://github.com/Naufal-awafa/Nopxnop
--]]

-- Wait until game is loaded
if not game:IsLoaded() then
    game.Loaded:Wait()
end

-- Prevent duplicate instances & cleanup previous
if getgenv().NopxnopLoaded then
    warn("[Nopxnop] Reloading instance...")
    if getgenv().NopxnopCleanup then
        getgenv().NopxnopCleanup()
    end
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

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local Mouse = LocalPlayer:GetMouse()

-- ==========================================
-- 1. BAC ANTI-CHEAT & ANTI-KICK BYPASS
-- ==========================================
local function installAntiKickBypass()
    -- Layer 1: hookmetamethod __namecall
    pcall(function()
        if hookmetamethod then
            local oldNamecall
            oldNamecall = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
                local method = getnamecallmethod()
                local args = {...}
                local methodLower = tostring(method):lower()
                
                -- Block client-side Kick (CODE BAC-9228 prevention)
                if methodLower == "kick" and (self == LocalPlayer or tostring(self) == tostring(LocalPlayer)) then
                    warn("[Nopxnop Security] Blocked Kick attempt: " .. tostring(args[1] or "No reason provided"))
                    return nil
                end
                
                -- Block BAC Telemetry & Cheat Detection Reporting Remotes
                if methodLower == "fireserver" or methodLower == "invokeserver" then
                    local sName = tostring(self.Name):lower()
                    if sName:find("bac") or sName:find("ban") or sName:find("report") or sName:find("anticheat") or sName:find("security") or sName:find("detection") then
                        warn("[Nopxnop Security] Blocked BAC telemetry remote: " .. tostring(self.Name))
                        return nil
                    end
                end
                
                return oldNamecall(self, ...)
            end))
        end
    end)

    -- Layer 2: hookfunction on LocalPlayer.Kick
    pcall(function()
        if hookfunction and LocalPlayer.Kick then
            hookfunction(LocalPlayer.Kick, newcclosure(function(self, ...)
                warn("[Nopxnop Security] Direct LocalPlayer:Kick() suppressed!")
                return nil
            end))
        end
    end)

    -- Layer 3: Metatable Index WalkSpeed & JumpPower Spoofing
    -- Prevents BAC from detecting speed alterations via property change listeners
    pcall(function()
        if hookmetamethod and checkcaller then
            local oldIndex
            oldIndex = hookmetamethod(game, "__index", newcclosure(function(self, key)
                if not checkcaller() and typeof(self) == "Instance" and self:IsA("Humanoid") and self.Parent == LocalPlayer.Character then
                    if key == "WalkSpeed" then
                        return 16
                    elseif key == "JumpPower" then
                        return 50
                    end
                end
                return oldIndex(self, key)
            end))
        end
    end)
end

installAntiKickBypass()

-- ==========================================
-- 2. STATE & CONFIGURATION
-- ==========================================
local Config = {
    AutoCast = false,
    CastDelay = 1.2,
    AutoShake = false,
    AutoReel = false,
    AutoEquipRod = true,
    AutoSell = false,
    SellDelay = 60,
    WalkSpeed = 16,
    JumpPower = 50,
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
    return char:FindFirstChildOfClass("Humanoid")
end

local function getRootPart()
    local char = getCharacter()
    return char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso")
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
            task.wait(0.2)
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

    -- Natural tool activation (safe, no blind remote spam)
    pcall(function()
        rod:Activate()
    end)
    pcall(function()
        VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 1)
        task.wait(0.08)
        VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 1)
    end)
end

-- ==========================================
-- 3. EMBEDDED VENYX UI WITH FLOATING POP-UP
-- ==========================================

-- Protect GUI function across all executors
local function getSafeGuiParent()
    if gethui then
        return gethui()
    elseif syn and syn.protect_gui then
        local g = Instance.new("Folder")
        syn.protect_gui(g)
        g.Parent = CoreGui
        return g
    elseif CoreGui and pcall(function() return CoreGui.Name end) then
        return CoreGui
    end
    return PlayerGui
end

-- Clean old instances
local parentContainer = getSafeGuiParent()
local existing = parentContainer:FindFirstChild("Nopxnop_Venyx_Gui")
if existing then existing:Destroy() end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "Nopxnop_Venyx_Gui"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = parentContainer

-- Theme Colors (Venyx Aesthetic)
local Theme = {
    Background = Color3.fromRGB(20, 20, 26),
    Sidebar = Color3.fromRGB(15, 15, 20),
    Accent = Color3.fromRGB(0, 162, 255),
    AccentDark = Color3.fromRGB(0, 120, 200),
    Card = Color3.fromRGB(26, 26, 34),
    Text = Color3.fromRGB(240, 240, 250),
    SubText = Color3.fromRGB(150, 150, 165),
    ToggleOff = Color3.fromRGB(45, 45, 58),
    Border = Color3.fromRGB(35, 35, 48)
}

-- Make draggable helper
local function makeDraggable(frame, handle)
    handle = handle or frame
    local dragging, dragInput, dragStart, startPos
    
    handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = frame.Position
            
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)
    
    handle.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)
    
    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local delta = input.Position - dragStart
            frame.Position = UDim2.new(
                startPos.X.Scale,
                startPos.X.Offset + delta.X,
                startPos.Y.Scale,
                startPos.Y.Offset + delta.Y
            )
        end
    end)
end

-- ------------------------------------------
-- A. FLOATING MINI POP-UP TOGGLE BUTTON
-- ------------------------------------------
local FloatButton = Instance.new("TextButton")
FloatButton.Name = "Nopxnop_FloatButton"
FloatButton.Size = UDim2.new(0, 52, 0, 52)
FloatButton.Position = UDim2.new(0, 25, 0, 180)
FloatButton.BackgroundColor3 = Theme.Sidebar
FloatButton.Text = "🎣"
FloatButton.TextSize = 24
FloatButton.Font = Enum.Font.GothamBold
FloatButton.TextColor3 = Theme.Text
FloatButton.AutoButtonColor = false
FloatButton.ClipsDescendants = true
FloatButton.Parent = ScreenGui

local FloatCorner = Instance.new("UICorner")
FloatCorner.CornerRadius = UDim.new(0, 26)
FloatCorner.Parent = FloatButton

local FloatStroke = Instance.new("UIStroke")
FloatStroke.Color = Theme.Accent
FloatStroke.Thickness = 2
FloatStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
FloatStroke.Parent = FloatButton

local FloatBadge = Instance.new("TextLabel")
FloatBadge.Size = UDim2.new(0, 36, 0, 14)
FloatBadge.Position = UDim2.new(0.5, -18, 1, -14)
FloatBadge.BackgroundColor3 = Theme.Accent
FloatBadge.Text = "NOP"
FloatBadge.TextColor3 = Color3.fromRGB(255, 255, 255)
FloatBadge.Font = Enum.Font.GothamBlack
FloatBadge.TextSize = 9
FloatBadge.BorderSizePixel = 0
FloatBadge.Parent = FloatButton

local FloatBadgeCorner = Instance.new("UICorner")
FloatBadgeCorner.CornerRadius = UDim.new(0, 4)
FloatBadgeCorner.Parent = FloatBadge

makeDraggable(FloatButton, FloatButton)

-- ------------------------------------------
-- B. MAIN VENYX WINDOW
-- ------------------------------------------
local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 560, 0, 360)
MainFrame.Position = UDim2.new(0.5, -280, 0.5, -180)
MainFrame.BackgroundColor3 = Theme.Background
MainFrame.BorderSizePixel = 0
MainFrame.ClipsDescendants = true
MainFrame.Parent = ScreenGui

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 10)
MainCorner.Parent = MainFrame

local MainStroke = Instance.new("UIStroke")
MainStroke.Color = Theme.Border
MainStroke.Thickness = 1.2
MainStroke.Parent = MainFrame

-- Top Bar (Header)
local TopBar = Instance.new("Frame")
TopBar.Name = "TopBar"
TopBar.Size = UDim2.new(1, 0, 0, 40)
TopBar.BackgroundColor3 = Theme.Sidebar
TopBar.BorderSizePixel = 0
TopBar.Parent = MainFrame

local TopBarCorner = Instance.new("UICorner")
TopBarCorner.CornerRadius = UDim.new(0, 10)
TopBarCorner.Parent = TopBar

-- Fix bottom corners of TopBar
local TopBarBottomCover = Instance.new("Frame")
TopBarBottomCover.Size = UDim2.new(1, 0, 0, 10)
TopBarBottomCover.Position = UDim2.new(0, 0, 1, -10)
TopBarBottomCover.BackgroundColor3 = Theme.Sidebar
TopBarBottomCover.BorderSizePixel = 0
TopBarBottomCover.Parent = TopBar

local TitleLabel = Instance.new("TextLabel")
TitleLabel.Size = UDim2.new(0, 220, 1, 0)
TitleLabel.Position = UDim2.new(0, 15, 0, 0)
TitleLabel.BackgroundTransparency = 1
TitleLabel.Text = "Nopxnop <font color=\"#00a2ff\">Fish It!</font>"
TitleLabel.RichText = true
TitleLabel.TextColor3 = Theme.Text
TitleLabel.Font = Enum.Font.GothamBold
TitleLabel.TextSize = 16
TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
TitleLabel.Parent = TopBar

makeDraggable(MainFrame, TopBar)

-- Minimize Button (Turns window into floating pop-up)
local MinimizeBtn = Instance.new("TextButton")
MinimizeBtn.Size = UDim2.new(0, 30, 0, 30)
MinimizeBtn.Position = UDim2.new(1, -70, 0, 5)
MinimizeBtn.BackgroundColor3 = Theme.Card
MinimizeBtn.Text = "—"
MinimizeBtn.TextColor3 = Theme.SubText
MinimizeBtn.Font = Enum.Font.GothamBold
MinimizeBtn.TextSize = 14
MinimizeBtn.AutoButtonColor = false
MinimizeBtn.Parent = TopBar

local MinCorner = Instance.new("UICorner")
MinCorner.CornerRadius = UDim.new(0, 6)
MinCorner.Parent = MinimizeBtn

-- Close Button
local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0, 30, 0, 30)
CloseBtn.Position = UDim2.new(1, -36, 0, 5)
CloseBtn.BackgroundColor3 = Color3.fromRGB(180, 40, 50)
CloseBtn.Text = "✕"
CloseBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.TextSize = 13
CloseBtn.AutoButtonColor = false
CloseBtn.Parent = TopBar

local CloseCorner = Instance.new("UICorner")
CloseCorner.CornerRadius = UDim.new(0, 6)
CloseCorner.Parent = CloseBtn

-- Toggle Window Visibility Function
local function toggleUI(state)
    if state == nil then
        Config.MenuVisible = not Config.MenuVisible
    else
        Config.MenuVisible = state
    end
    
    if Config.MenuVisible then
        MainFrame.Visible = true
        MainFrame.Size = UDim2.new(0, 560, 0, 0)
        MainFrame.BackgroundTransparency = 1
        TweenService:Create(MainFrame, TweenInfo.new(0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
            Size = UDim2.new(0, 560, 0, 360),
            BackgroundTransparency = 0
        }):Play()
        FloatButton.BackgroundColor3 = Theme.Sidebar
    else
        local tween = TweenService:Create(MainFrame, TweenInfo.new(0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.In), {
            Size = UDim2.new(0, 560, 0, 0),
            BackgroundTransparency = 1
        })
        tween:Play()
        tween.Completed:Connect(function()
            if not Config.MenuVisible then
                MainFrame.Visible = false
            end
        end)
        FloatButton.BackgroundColor3 = Theme.Card
    end
end

MinimizeBtn.MouseButton1Click:Connect(function()
    toggleUI(false)
end)

CloseBtn.MouseButton1Click:Connect(function()
    toggleUI(false)
end)

FloatButton.MouseButton1Click:Connect(function()
    toggleUI()
end)

-- Sidebar for Tabs
local Sidebar = Instance.new("Frame")
Sidebar.Name = "Sidebar"
Sidebar.Size = UDim2.new(0, 130, 1, -40)
Sidebar.Position = UDim2.new(0, 0, 0, 40)
Sidebar.BackgroundColor3 = Theme.Sidebar
Sidebar.BorderSizePixel = 0
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

-- Content Container
local ContentContainer = Instance.new("Frame")
ContentContainer.Name = "ContentContainer"
ContentContainer.Size = UDim2.new(1, -135, 1, -45)
ContentContainer.Position = UDim2.new(0, 133, 0, 43)
ContentContainer.BackgroundTransparency = 1
ContentContainer.ClipsDescendants = true
ContentContainer.Parent = MainFrame

-- Tab System Architecture
local Tabs = {}
local TabButtons = {}
local activeTab = nil

local function createTab(tabName, iconText)
    local TabPage = Instance.new("ScrollingFrame")
    TabPage.Name = tabName .. "Page"
    TabPage.Size = UDim2.new(1, 0, 1, 0)
    TabPage.BackgroundTransparency = 1
    TabPage.BorderSizePixel = 0
    TabPage.ScrollBarThickness = 4
    TabPage.ScrollBarImageColor3 = Theme.Accent
    TabPage.CanvasSize = UDim2.new(0, 0, 0, 0)
    TabPage.Visible = false
    TabPage.Parent = ContentContainer

    local PageLayout = Instance.new("UIListLayout")
    PageLayout.Padding = UDim.new(0, 8)
    PageLayout.SortOrder = Enum.SortOrder.LayoutOrder
    PageLayout.Parent = TabPage

    local PagePadding = Instance.new("UIPadding")
    PagePadding.PaddingTop = UDim.new(0, 4)
    PagePadding.PaddingBottom = UDim.new(0, 8)
    PagePadding.PaddingLeft = UDim.new(0, 4)
    PagePadding.PaddingRight = UDim.new(0, 8)
    PagePadding.Parent = TabPage

    PageLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        TabPage.CanvasSize = UDim2.new(0, 0, 0, PageLayout.AbsoluteContentSize.Y + 16)
    end)

    -- Tab Button in Sidebar
    local TabBtn = Instance.new("TextButton")
    TabBtn.Name = tabName .. "Btn"
    TabBtn.Size = UDim2.new(1, 0, 0, 34)
    TabBtn.BackgroundColor3 = Theme.Sidebar
    TabBtn.Text = (iconText or "•") .. "  " .. tabName
    TabBtn.TextColor3 = Theme.SubText
    TabBtn.Font = Enum.Font.GothamMedium
    TabBtn.TextSize = 13
    TabBtn.TextXAlignment = Enum.TextXAlignment.Left
    TabBtn.AutoButtonColor = false
    TabBtn.Parent = Sidebar

    local TabBtnCorner = Instance.new("UICorner")
    TabBtnCorner.CornerRadius = UDim.new(0, 6)
    TabBtnCorner.Parent = TabBtn

    local TabBtnPadding = Instance.new("UIPadding")
    TabBtnPadding.PaddingLeft = UDim.new(0, 12)
    TabBtnPadding.Parent = TabBtn

    local function select()
        for name, page in pairs(Tabs) do
            page.Visible = false
        end
        for name, btn in pairs(TabButtons) do
            btn.BackgroundColor3 = Theme.Sidebar
            btn.TextColor3 = Theme.SubText
            btn.Font = Enum.Font.GothamMedium
        end
        TabPage.Visible = true
        TabBtn.BackgroundColor3 = Theme.Card
        TabBtn.TextColor3 = Theme.Accent
        TabBtn.Font = Enum.Font.GothamBold
        activeTab = tabName
    end

    TabBtn.MouseButton1Click:Connect(select)

    Tabs[tabName] = TabPage
    TabButtons[tabName] = TabBtn

    if activeTab == nil then
        select()
    end

    -- Tab Helpers for Section, Toggle, Slider, Button
    local tabObj = {}

    function tabObj:addSection(title)
        local SectionFrame = Instance.new("Frame")
        SectionFrame.Name = title .. "Section"
        SectionFrame.Size = UDim2.new(1, 0, 0, 24)
        SectionFrame.BackgroundColor3 = Theme.Card
        SectionFrame.BorderSizePixel = 0
        SectionFrame.Parent = TabPage

        local SecCorner = Instance.new("UICorner")
        SecCorner.CornerRadius = UDim.new(0, 6)
        SecCorner.Parent = SectionFrame

        local SecTitle = Instance.new("TextLabel")
        SecTitle.Size = UDim2.new(1, -12, 0, 22)
        SecTitle.Position = UDim2.new(0, 10, 0, 0)
        SecTitle.BackgroundTransparency = 1
        SecTitle.Text = title:upper()
        SecTitle.TextColor3 = Theme.Accent
        SecTitle.Font = Enum.Font.GothamBold
        SecTitle.TextSize = 11
        SecTitle.TextXAlignment = Enum.TextXAlignment.Left
        SecTitle.Parent = SectionFrame

        local secObj = {}

        function secObj:addToggle(name, default, callback)
            local ToggleFrame = Instance.new("Frame")
            ToggleFrame.Size = UDim2.new(1, 0, 0, 36)
            ToggleFrame.BackgroundColor3 = Theme.Card
            ToggleFrame.BorderSizePixel = 0
            ToggleFrame.Parent = TabPage

            local TCorner = Instance.new("UICorner")
            TCorner.CornerRadius = UDim.new(0, 6)
            TCorner.Parent = ToggleFrame

            local TLabel = Instance.new("TextLabel")
            TLabel.Size = UDim2.new(1, -60, 1, 0)
            TLabel.Position = UDim2.new(0, 12, 0, 0)
            TLabel.BackgroundTransparency = 1
            TLabel.Text = name
            TLabel.TextColor3 = Theme.Text
            TLabel.Font = Enum.Font.Gotham
            TLabel.TextSize = 13
            TLabel.TextXAlignment = Enum.TextXAlignment.Left
            TLabel.Parent = ToggleFrame

            local TSwitch = Instance.new("TextButton")
            TSwitch.Size = UDim2.new(0, 42, 0, 22)
            TSwitch.Position = UDim2.new(1, -52, 0.5, -11)
            TSwitch.BackgroundColor3 = default and Theme.Accent or Theme.ToggleOff
            TSwitch.Text = ""
            TSwitch.AutoButtonColor = false
            TSwitch.Parent = ToggleFrame

            local SCorner = Instance.new("UICorner")
            SCorner.CornerRadius = UDim.new(0, 11)
            SCorner.Parent = TSwitch

            local TCircle = Instance.new("Frame")
            TCircle.Size = UDim2.new(0, 16, 0, 16)
            TCircle.Position = default and UDim2.new(1, -19, 0.5, -8) or UDim2.new(0, 3, 0.5, -8)
            TCircle.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
            TCircle.BorderSizePixel = 0
            TCircle.Parent = TSwitch

            local CCorner = Instance.new("UICorner")
            CCorner.CornerRadius = UDim.new(0, 8)
            CCorner.Parent = TCircle

            local currState = default

            local function updateToggle(val)
                currState = val
                local targetPos = currState and UDim2.new(1, -19, 0.5, -8) or UDim2.new(0, 3, 0.5, -8)
                local targetColor = currState and Theme.Accent or Theme.ToggleOff
                TweenService:Create(TCircle, TweenInfo.new(0.18, Enum.EasingStyle.Quart), {Position = targetPos}):Play()
                TweenService:Create(TSwitch, TweenInfo.new(0.18, Enum.EasingStyle.Quart), {BackgroundColor3 = targetColor}):Play()
                if callback then pcall(callback, currState) end
            end

            TSwitch.MouseButton1Click:Connect(function()
                updateToggle(not currState)
            end)

            return {
                set = updateToggle
            }
        end

        function secObj:addSlider(name, default, min, max, callback)
            local SliderFrame = Instance.new("Frame")
            SliderFrame.Size = UDim2.new(1, 0, 0, 48)
            SliderFrame.BackgroundColor3 = Theme.Card
            SliderFrame.BorderSizePixel = 0
            SliderFrame.Parent = TabPage

            local SCorner = Instance.new("UICorner")
            SCorner.CornerRadius = UDim.new(0, 6)
            SCorner.Parent = SliderFrame

            local SLabel = Instance.new("TextLabel")
            SLabel.Size = UDim2.new(1, -80, 0, 20)
            SLabel.Position = UDim2.new(0, 12, 0, 6)
            SLabel.BackgroundTransparency = 1
            SLabel.Text = name
            SLabel.TextColor3 = Theme.Text
            SLabel.Font = Enum.Font.Gotham
            SLabel.TextSize = 13
            SLabel.TextXAlignment = Enum.TextXAlignment.Left
            SLabel.Parent = SliderFrame

            local SValue = Instance.new("TextLabel")
            SValue.Size = UDim2.new(0, 60, 0, 20)
            SValue.Position = UDim2.new(1, -70, 0, 6)
            SValue.BackgroundTransparency = 1
            SValue.Text = tostring(default)
            SValue.TextColor3 = Theme.Accent
            SValue.Font = Enum.Font.GothamBold
            SValue.TextSize = 13
            SValue.TextXAlignment = Enum.TextXAlignment.Right
            SValue.Parent = SliderFrame

            local BarTrack = Instance.new("TextButton")
            BarTrack.Size = UDim2.new(1, -24, 0, 6)
            BarTrack.Position = UDim2.new(0, 12, 0, 32)
            BarTrack.BackgroundColor3 = Theme.ToggleOff
            BarTrack.Text = ""
            BarTrack.AutoButtonColor = false
            BarTrack.Parent = SliderFrame

            local BCorner = Instance.new("UICorner")
            BCorner.CornerRadius = UDim.new(0, 3)
            BCorner.Parent = BarTrack

            local BarFill = Instance.new("Frame")
            local initPercent = math.clamp((default - min) / (max - min), 0, 1)
            BarFill.Size = UDim2.new(initPercent, 0, 1, 0)
            BarFill.BackgroundColor3 = Theme.Accent
            BarFill.BorderSizePixel = 0
            BarFill.Parent = BarTrack

            local FCorner = Instance.new("UICorner")
            FCorner.CornerRadius = UDim.new(0, 3)
            FCorner.Parent = BarFill

            local sliding = false

            local function updateSlider(input)
                local percent = math.clamp((input.Position.X - BarTrack.AbsolutePosition.X) / BarTrack.AbsoluteSize.X, 0, 1)
                local val = math.floor(min + (max - min) * percent)
                BarFill.Size = UDim2.new(percent, 0, 1, 0)
                SValue.Text = tostring(val)
                if callback then pcall(callback, val) end
            end

            BarTrack.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                    sliding = true
                    updateSlider(input)
                end
            end)

            UserInputService.InputEnded:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                    sliding = false
                end
            end)

            UserInputService.InputChanged:Connect(function(input)
                if sliding and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                    updateSlider(input)
                end
            end)
        end

        function secObj:addButton(name, callback)
            local BtnFrame = Instance.new("Frame")
            BtnFrame.Size = UDim2.new(1, 0, 0, 36)
            BtnFrame.BackgroundColor3 = Theme.Card
            BtnFrame.BorderSizePixel = 0
            BtnFrame.Parent = TabPage

            local BCorner = Instance.new("UICorner")
            BCorner.CornerRadius = UDim.new(0, 6)
            BCorner.Parent = BtnFrame

            local ActionBtn = Instance.new("TextButton")
            ActionBtn.Size = UDim2.new(1, -16, 1, -8)
            ActionBtn.Position = UDim2.new(0, 8, 0, 4)
            ActionBtn.BackgroundColor3 = Theme.Sidebar
            ActionBtn.Text = name
            ActionBtn.TextColor3 = Theme.Text
            ActionBtn.Font = Enum.Font.GothamMedium
            ActionBtn.TextSize = 13
            ActionBtn.AutoButtonColor = false
            ActionBtn.Parent = BtnFrame

            local ACorner = Instance.new("UICorner")
            ACorner.CornerRadius = UDim.new(0, 5)
            ACorner.Parent = ActionBtn

            ActionBtn.MouseButton1Click:Connect(function()
                TweenService:Create(ActionBtn, TweenInfo.new(0.1), {BackgroundColor3 = Theme.Accent}):Play()
                task.wait(0.1)
                TweenService:Create(ActionBtn, TweenInfo.new(0.15), {BackgroundColor3 = Theme.Sidebar}):Play()
                if callback then pcall(callback) end
            end)
        end

        return secObj
    end

    return tabObj
end

-- Create Application Pages
local PageFishing = createTab("Fishing", "🎣")
local PageTeleport = createTab("Teleport", "🏝️")
local PagePlayer = createTab("Player", "🏃")
local PageSettings = createTab("Settings", "⚙️")

-- ==========================================
-- 4. FISHING FEATURES IMPLEMENTATION
-- ==========================================
local SectionFishing = PageFishing:addSection("Automation")

SectionFishing:addToggle("Auto Cast Rod", Config.AutoCast, function(state)
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

SectionFishing:addSlider("Cast Delay (ms)", math.floor(Config.CastDelay * 1000), 500, 3500, function(value)
    Config.CastDelay = value / 1000
end)

SectionFishing:addToggle("Auto Shake (Minigame)", Config.AutoShake, function(state)
    Config.AutoShake = state
    if state then
        task.spawn(function()
            while Config.AutoShake do
                pcall(function()
                    -- Safely scan PlayerGui for active interactive buttons
                    for _, gui in ipairs(PlayerGui:GetChildren()) do
                        if gui:IsA("ScreenGui") and gui.Enabled then
                            local gName = gui.Name:lower()
                            if gName:find("shake") or gName:find("fish") or gName:find("minigame") or gName:find("reel") or gName:find("bar") then
                                for _, btn in ipairs(gui:GetDescendants()) do
                                    if (btn:IsA("ImageButton") or btn:IsA("TextButton")) and btn.Visible and btn.Active then
                                        -- Trigger via signals
                                        pcall(function()
                                            if getconnections then
                                                for _, conn in ipairs(getconnections(btn.MouseButton1Click)) do conn:Fire() end
                                                for _, conn in ipairs(getconnections(btn.Activated)) do conn:Fire() end
                                            end
                                        end)
                                        -- Trigger via safe screen coordinate tap
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
                task.wait(0.08)
            end
        end)
    end
end)

SectionFishing:addToggle("Auto Reel (Fast Catch)", Config.AutoReel, function(state)
    Config.AutoReel = state
    if state then
        task.spawn(function()
            while Config.AutoReel do
                pcall(function()
                    -- Simulates steady, natural rapid reeling clicks
                    local mousePos = UserInputService:GetMouseLocation()
                    VirtualInputManager:SendMouseButtonEvent(mousePos.X, mousePos.Y, 0, true, game, 1)
                    task.wait(0.04)
                    VirtualInputManager:SendMouseButtonEvent(mousePos.X, mousePos.Y, 0, false, game, 1)
                end)
                task.wait(0.07)
            end
        end)
    end
end)

SectionFishing:addToggle("Auto Equip Rod", Config.AutoEquipRod, function(state)
    Config.AutoEquipRod = state
    if state then
        equipRod()
    end
end)

local SectionEco = PageFishing:addSection("Economy & Selling")

local function sellFishSafely()
    pcall(function()
        -- Safe prompt interaction with Merchant NPCs
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

SectionEco:addButton("Sell All Fish (Merchant)", function()
    sellFishSafely()
end)

SectionEco:addToggle("Auto Sell (Loop)", Config.AutoSell, function(state)
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

SectionEco:addSlider("Auto Sell Interval (s)", Config.SellDelay, 15, 180, function(value)
    Config.SellDelay = value
end)

-- ==========================================
-- 5. TELEPORTS
-- ==========================================
local SectionTP = PageTeleport:addSection("Key Locations")

local Locations = {
    ["Starter Island / Spawn"] = Vector3.new(0, 15, 0),
    ["Sell Merchant / Shop"]   = Vector3.new(45, 12, -120),
    ["Coral Reef Island"]      = Vector3.new(-320, 10, 240),
    ["Volcano / Magma Zone"]   = Vector3.new(650, 20, 850),
    ["Deep Sunken Trench"]     = Vector3.new(-750, -50, -420),
    ["Ancient Shrine Isle"]    = Vector3.new(1200, 35, -600),
    ["Rod & Equipment Shop"]   = Vector3.new(80, 12, -90)
}

local function safeTeleport(targetPos)
    local root = getRootPart()
    if root then
        root.CFrame = CFrame.new(targetPos + Vector3.new(0, 3, 0))
        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
    end
end

for name, pos in pairs(Locations) do
    SectionTP:addButton(name, function()
        safeTeleport(pos)
    end)
end

local SectionPlatform = PageTeleport:addSection("AFK Sky Platform")

SectionPlatform:addToggle("Safe Sky Fishing Platform", Config.SafePlatform, function(state)
    Config.SafePlatform = state
    if state then
        local root = getRootPart()
        if root then
            if not SafePlatformPart or not SafePlatformPart.Parent then
                SafePlatformPart = Instance.new("Part")
                SafePlatformPart.Name = "Nopxnop_SkySafe"
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

-- ==========================================
-- 6. PLAYER & MOVEMENT
-- ==========================================
local SectionMove = PagePlayer:addSection("Movement (Undetected)")

SectionMove:addSlider("WalkSpeed", Config.WalkSpeed, 16, 120, function(value)
    Config.WalkSpeed = value
    local hum = getHumanoid()
    if hum then hum.WalkSpeed = value end
end)

SectionMove:addSlider("JumpPower", Config.JumpPower, 50, 220, function(value)
    Config.JumpPower = value
    local hum = getHumanoid()
    if hum then
        hum.UseJumpPower = true
        hum.JumpPower = value
    end
end)

SectionMove:addToggle("Infinite Jump", Config.InfJump, function(state)
    Config.InfJump = state
end)

Connections.InfJump = UserInputService.JumpRequest:Connect(function()
    if Config.InfJump then
        local hum = getHumanoid()
        if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
    end
end)

SectionMove:addToggle("Noclip", Config.Noclip, function(state)
    Config.Noclip = state
end)

Connections.Noclip = RunService.Stepped:Connect(function()
    if Config.Noclip then
        local char = LocalPlayer.Character
        if char then
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") and part.CanCollide then
                    part.CanCollide = false
                end
            end
        end
    end
end)

local SectionSurv = PagePlayer:addSection("Survival")

SectionSurv:addToggle("Infinite Oxygen", Config.InfOxygen, function(state)
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

SectionSurv:addToggle("Anti-AFK (Idle Kick Bypass)", Config.AntiAFK, function(state)
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

-- ==========================================
-- 7. SETTINGS & VISUALS
-- ==========================================
local SectionVisuals = PageSettings:addSection("Visuals")

SectionVisuals:addToggle("FullBright", Config.FullBright, function(state)
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

local SectionCtrl = PageSettings:addSection("Controls")

SectionCtrl:addButton("Rejoin Server", function()
    local ts = game:GetService("TeleportService")
    ts:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
end)

SectionCtrl:addButton("Unload Script", function()
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
    local hum = getHumanoid()
    if hum then
        hum.WalkSpeed = 16
        hum.JumpPower = 50
    end
    if SafePlatformPart and SafePlatformPart.Parent then
        SafePlatformPart:Destroy()
    end
    if ScreenGui and ScreenGui.Parent then
        ScreenGui:Destroy()
    end
    getgenv().NopxnopLoaded = false
end

-- Keybind to Toggle Menu (RightShift / LeftControl)
Connections.KeybindToggle = UserInputService.InputBegan:Connect(function(input, processed)
    if not processed and (input.KeyCode == Enum.KeyCode.RightShift or input.KeyCode == Enum.KeyCode.RightControl) then
        toggleUI()
    end
end)

print([[
======================================================
   [Nopxnop v2.0] Loaded & Running!
   - Anti-Cheat & BAC Bypass: Active
   - Venyx UI + Floating Pop-up Toggle: Active
   - Tap the Floating 🎣 Button or press RightShift
======================================================
]])
