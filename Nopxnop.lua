--[[
    _   __                       ____                    
   / | / /___  ____  _  ______  / __ \____  ____  ____ _
  /  |/ / __ \/ __ \| |/_/ __ \/ / / / __ \/ __ \/ __ `/
 / /|  / /_/ / /_/ />  </ /_/ / /_/ / /_/ / /_/ / /_/ / 
/_/ |_/\____/ .___/_/|_/ .___/\____/ .___/ .___/\__,_/  
           /_/        /_/         /_/   /_/             
    
    [ Nopxnop ] - Lightweight Script for Fish It! (Roblox)
    UI Style: Venyx Interface
    Repository: https://github.com/Naufal-awafa/Nopxnop
--]]

-- Wait until game is fully loaded
if not game:IsLoaded() then
    game.Loaded:Wait()
end

-- Prevent multiple instances
if getgenv().NopxnopLoaded then
    warn("[Nopxnop] Already loaded! Unloading previous instance...")
    if getgenv().NopxnopCleanup then
        getgenv().NopxnopCleanup()
    end
end
getgenv().NopxnopLoaded = true

-- Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local VirtualUser = game:GetService("VirtualUser")
local VirtualInputManager = game:GetService("VirtualInputManager")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local GuiService = game:GetService("GuiService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local Mouse = LocalPlayer:GetMouse()

-- State & Configuration
local Config = {
    AutoCast = false,
    CastDelay = 1.2,
    AutoShake = false,
    AutoReel = false,
    AutoEquipRod = false,
    AutoSell = false,
    SellDelay = 60,
    WalkSpeed = 16,
    JumpPower = 50,
    InfJump = false,
    InfOxygen = false,
    Noclip = false,
    AntiAFK = true,
    FullBright = false,
    SafePlatform = false
}

-- Cleanup Registry
local Connections = {}
local SafePlatformPart = nil
local OriginalLighting = {
    Ambient = Lighting.Ambient,
    OutdoorAmbient = Lighting.OutdoorAmbient,
    Brightness = Lighting.Brightness,
    ClockTime = Lighting.ClockTime,
    FogEnd = Lighting.FogEnd
}

-- Helper Functions
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

-- Find Fishing Rod in Character or Backpack
local function findRod()
    local char = LocalPlayer.Character
    if char then
        for _, item in ipairs(char:GetChildren()) do
            if item:IsA("Tool") and (item.Name:lower():find("rod") or item:FindFirstChild("Bobber") or item:FindFirstChild("Cast") or item:FindFirstChild("Values")) then
                return item, true -- Already equipped
            end
        end
    end
    
    local backpack = LocalPlayer:FindFirstChild("Backpack")
    if backpack then
        for _, item in ipairs(backpack:GetChildren()) do
            if item:IsA("Tool") and (item.Name:lower():find("rod") or item:FindFirstChild("Bobber") or item:FindFirstChild("Cast") or item:FindFirstChild("Values")) then
                return item, false -- In backpack
            end
        end
    end
    
    -- Fallback to any tool
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

-- Equip Rod
local function equipRod()
    local rod, isEquipped = findRod()
    if rod and not isEquipped then
        local hum = getHumanoid()
        if hum then
            hum:EquipTool(rod)
            task.wait(0.3)
        end
    end
    return rod
end

-- Cast Rod Logic
local function performCast()
    local rod, isEquipped = findRod()
    if not rod then return end
    if not isEquipped then
        rod = equipRod()
    end
    if not rod or not rod.Parent or rod.Parent ~= LocalPlayer.Character then return end

    -- Method 1: Direct Tool Activation
    pcall(function()
        rod:Activate()
    end)

    -- Method 2: Fire standard Rod Remotes if available
    pcall(function()
        local events = rod:FindFirstChild("events") or rod:FindFirstChild("Events")
        if events then
            local castRemote = events:FindFirstChild("cast") or events:FindFirstChild("Cast")
            if castRemote and castRemote:IsA("RemoteEvent") then
                castRemote:FireServer(100) -- Full power cast
            end
        end
    end)

    -- Method 3: Simulate Left Click via VirtualInput
    pcall(function()
        VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 1)
        task.wait(0.1)
        VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 1)
    end)
end

-- Load Venyx UI Library (with graceful fallback)
local VenyxLibrary = nil

local function loadUI()
    -- Attempt 1: Load requested Venyx UI path
    local success1, result1 = pcall(function()
        return loadstring(game:HttpGet("https://raw.githubusercontent.com/tienkhanh1/Venyx/main/VenyxHub"))()
    end)
    
    if success1 and type(result1) == "table" and (result1.new or result1.Init) then
        return result1
    end

    -- Attempt 2: Load authentic Stefanuk12 Venyx UI Library
    local success2, result2 = pcall(function()
        return loadstring(game:HttpGet("https://raw.githubusercontent.com/Stefanuk12/Venyx-UI-Library/master/source.lua"))()
    end)
    
    if success2 and type(result2) == "table" and result2.new then
        return result2
    end

    -- Attempt 3: Alternative reliable Venyx CDN
    local success3, result3 = pcall(function()
        return loadstring(game:HttpGet("https://raw.githubusercontent.com/GreenDuro/Azure-Library/main/Test.lua"))()
    end)
    
    if success3 and type(result3) == "table" and result3.new then
        return result3
    end

    error("[Nopxnop] Failed to load Venyx UI library from all sources!")
end

VenyxLibrary = loadUI()
local UI = VenyxLibrary.new("Nopxnop | Fish It!", 5013109572)

-- Create Pages
local PageFishing = UI:addPage("Fishing", 5012544693)
local PageTeleport = UI:addPage("Teleports", 5012543481)
local PagePlayer = UI:addPage("Player", 5012544131)
local PageVisuals = UI:addPage("Visuals", 5012543787)
local PageSettings = UI:addPage("Settings", 5012544833)

-- ==========================================
-- 1. FISHING AUTOMATION TAB
-- ==========================================
local SectionMain = PageFishing:addSection("Auto Fishing")

SectionMain:addToggle("Auto Cast Rod", Config.AutoCast, function(state)
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

SectionMain:addSlider("Cast Delay (Seconds)", math.floor(Config.CastDelay * 10), 5, 50, function(value)
    Config.CastDelay = value / 10
end)

SectionMain:addToggle("Auto Shake (Minigame)", Config.AutoShake, function(state)
    Config.AutoShake = state
    if state then
        task.spawn(function()
            while Config.AutoShake do
                pcall(function()
                    -- Scan PlayerGui for shake/click targets
                    for _, gui in ipairs(PlayerGui:GetChildren()) do
                        if gui:IsA("ScreenGui") and gui.Enabled then
                            local name = gui.Name:lower()
                            if name:find("shake") or name:find("minigame") or name:find("fish") or name:find("reel") then
                                for _, btn in ipairs(gui:GetDescendants()) do
                                    if (btn:IsA("ImageButton") or btn:IsA("TextButton")) and btn.Visible then
                                        -- Click via GuiObject events
                                        if btn.Active then
                                            pcall(function()
                                                if getconnections then
                                                    for _, conn in ipairs(getconnections(btn.MouseButton1Click)) do
                                                        conn:Fire()
                                                    end
                                                    for _, conn in ipairs(getconnections(btn.Activated)) do
                                                        conn:Fire()
                                                    end
                                                end
                                            end)
                                            -- Also simulate position click
                                            local pos = btn.AbsolutePosition + (btn.AbsoluteSize / 2)
                                            VirtualInputManager:SendMouseButtonEvent(pos.X, pos.Y, 0, true, game, 1)
                                            task.wait(0.02)
                                            VirtualInputManager:SendMouseButtonEvent(pos.X, pos.Y, 0, false, game, 1)
                                        end
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

SectionMain:addToggle("Auto Reel / Fast Catch", Config.AutoReel, function(state)
    Config.AutoReel = state
    if state then
        task.spawn(function()
            while Config.AutoReel do
                pcall(function()
                    -- Fish It reel mechanism: rapid click / bar follow
                    local mousePos = UserInputService:GetMouseLocation()
                    VirtualInputManager:SendMouseButtonEvent(mousePos.X, mousePos.Y, 0, true, game, 1)
                    task.wait(0.03)
                    VirtualInputManager:SendMouseButtonEvent(mousePos.X, mousePos.Y, 0, false, game, 1)
                    
                    -- Check for standard reel remotes
                    for _, remote in ipairs(ReplicatedStorage:GetDescendants()) do
                        if remote:IsA("RemoteEvent") then
                            local rName = remote.Name:lower()
                            if rName:find("reelfinished") or rName:find("reelcompleted") or rName:find("catch") then
                                remote:FireServer(100, true)
                            end
                        end
                    end
                end)
                task.wait(0.05)
            end
        end)
    end
end)

SectionMain:addToggle("Auto Equip Rod", Config.AutoEquipRod, function(state)
    Config.AutoEquipRod = state
    if state then
        equipRod()
    end
end)

local SectionEconomy = PageFishing:addSection("Economy & Sell")

local function sellFishNow()
    pcall(function()
        -- Method 1: Look for Sell Remote in ReplicatedStorage
        for _, obj in ipairs(ReplicatedStorage:GetDescendants()) do
            if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
                local name = obj.Name:lower()
                if name:find("sellall") or name:find("sell_all") or name:find("sellfish") or (name:find("merchant") and name:find("sell")) then
                    if obj:IsA("RemoteEvent") then
                        obj:FireServer()
                    else
                        obj:InvokeServer()
                    end
                end
            end
        end

        -- Method 2: Fire proximity prompt on Sell Merchant
        for _, npc in ipairs(workspace:GetDescendants()) do
            if npc:IsA("ProximityPrompt") then
                local action = npc.ActionText:lower()
                local object = npc.ObjectText:lower()
                if action:find("sell") or object:find("sell") or object:find("merchant") then
                    fireproximityprompt(npc)
                end
            end
        end
    end)
end

SectionEconomy:addButton("Sell All Fish Now", function()
    sellFishNow()
end)

SectionEconomy:addToggle("Auto Sell Fish (Loop)", Config.AutoSell, function(state)
    Config.AutoSell = state
    if state then
        task.spawn(function()
            while Config.AutoSell do
                task.wait(Config.SellDelay)
                if not Config.AutoSell then break end
                sellFishNow()
            end
        end)
    end
end)

SectionEconomy:addSlider("Sell Interval (Seconds)", Config.SellDelay, 10, 180, function(value)
    Config.SellDelay = value
end)

-- ==========================================
-- 2. TELEPORTS TAB
-- ==========================================
local SectionTP = PageTeleport:addSection("Islands & Key Locations")

local Locations = {
    ["Starter Island / Spawn"] = Vector3.new(0, 15, 0),
    ["Merchant / Sell Shop"]  = Vector3.new(45, 12, -120),
    ["Coral Reef Zone"]        = Vector3.new(-320, 10, 240),
    ["Volcano / Magma Zone"]   = Vector3.new(650, 20, 850),
    ["Sunken Deep Trench"]     = Vector3.new(-750, -50, -420),
    ["Mystic Ancient Island"]  = Vector3.new(1200, 35, -600),
    ["Rod & Bait Vendor"]      = Vector3.new(80, 12, -90)
}

local function teleportTo(targetPos)
    local root = getRootPart()
    if root then
        -- Safe teleport with zero velocity
        root.CFrame = CFrame.new(targetPos + Vector3.new(0, 3, 0))
        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
    end
end

for locName, locPos in pairs(Locations) do
    SectionTP:addButton(locName, function()
        teleportTo(locPos)
    end)
end

local SectionPlayerTP = PageTeleport:addSection("Player Teleport")
local PlayerNames = {}
for _, p in ipairs(Players:GetPlayers()) do
    if p ~= LocalPlayer then
        table.insert(PlayerNames, p.DisplayName .. " (@" .. p.Name .. ")")
    end
end
if #PlayerNames == 0 then table.insert(PlayerNames, "No other players") end

local selectedPlayerName = nil
SectionPlayerTP:addDropdown("Select Player", PlayerNames, function(selection)
    for _, p in ipairs(Players:GetPlayers()) do
        if selection:find(p.Name) then
            selectedPlayerName = p
            break
        end
    end
end)

SectionPlayerTP:addButton("Teleport to Selected Player", function()
    if selectedPlayerName and selectedPlayerName.Character then
        local targetRoot = selectedPlayerName.Character:FindFirstChild("HumanoidRootPart")
        if targetRoot then
            teleportTo(targetRoot.Position)
        end
    end
end)

-- Safe Fishing Platform
local SectionSafeSpot = PageTeleport:addSection("AFK Safe Platform")

SectionSafeSpot:addToggle("Spawn Safe Sky Platform", Config.SafePlatform, function(state)
    Config.SafePlatform = state
    if state then
        local root = getRootPart()
        if root then
            if not SafePlatformPart or not SafePlatformPart.Parent then
                SafePlatformPart = Instance.new("Part")
                SafePlatformPart.Name = "Nopxnop_SafePlatform"
                SafePlatformPart.Size = Vector3.new(20, 2, 20)
                SafePlatformPart.Anchored = true
                SafePlatformPart.CanCollide = true
                SafePlatformPart.Material = Enum.Material.ForceField
                SafePlatformPart.Color = Color3.fromRGB(0, 180, 255)
                SafePlatformPart.Transparency = 0.3
                SafePlatformPart.Parent = workspace
            end
            
            local highPos = root.Position + Vector3.new(0, 75, 0)
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
-- 3. PLAYER & MOVEMENT TAB
-- ==========================================
local SectionMovement = PagePlayer:addSection("Movement")

SectionMovement:addSlider("WalkSpeed", Config.WalkSpeed, 16, 150, function(value)
    Config.WalkSpeed = value
    local hum = getHumanoid()
    if hum then hum.WalkSpeed = value end
end)

SectionMovement:addSlider("JumpPower", Config.JumpPower, 50, 250, function(value)
    Config.JumpPower = value
    local hum = getHumanoid()
    if hum then
        hum.UseJumpPower = true
        hum.JumpPower = value
    end
end)

SectionMovement:addToggle("Infinite Jump", Config.InfJump, function(state)
    Config.InfJump = state
end)

-- Infinite Jump Listener
Connections.InfJump = UserInputService.JumpRequest:Connect(function()
    if Config.InfJump then
        local hum = getHumanoid()
        if hum then
            hum:ChangeState(Enum.HumanoidStateType.Jumping)
        end
    end
end)

SectionMovement:addToggle("Noclip (Walk through walls)", Config.Noclip, function(state)
    Config.Noclip = state
end)

-- Noclip Stepped Loop
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

local SectionSurvival = PagePlayer:addSection("Survival & Utility")

SectionSurvival:addToggle("Infinite Oxygen / Anti-Drown", Config.InfOxygen, function(state)
    Config.InfOxygen = state
    if state then
        task.spawn(function()
            while Config.InfOxygen do
                pcall(function()
                    local char = LocalPlayer.Character
                    if char then
                        -- Check for oxygen attributes or objects
                        if char:GetAttribute("Oxygen") ~= nil then
                            char:SetAttribute("Oxygen", 100)
                        end
                        if char:GetAttribute("Air") ~= nil then
                            char:SetAttribute("Air", 100)
                        end
                        local oxy = char:FindFirstChild("Oxygen") or char:FindFirstChild("Air")
                        if oxy and oxy:IsA("NumberValue") or oxy:IsA("IntValue") then
                            oxy.Value = 100
                        end
                    end
                end)
                task.wait(1)
            end
        end)
    end
end)

SectionSurvival:addToggle("Anti-AFK (20min Kick Prevention)", Config.AntiAFK, function(state)
    Config.AntiAFK = state
end)

-- Anti AFK Connection
Connections.AntiAFK = LocalPlayer.Idled:Connect(function()
    if Config.AntiAFK then
        pcall(function()
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new())
        end)
    end
end)

-- ==========================================
-- 4. VISUALS TAB
-- ==========================================
local SectionVisuals = PageVisuals:addSection("Lighting & Atmosphere")

SectionVisuals:addToggle("FullBright / No Fog", Config.FullBright, function(state)
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

-- ==========================================
-- 5. SETTINGS TAB
-- ==========================================
local SectionSettings = PageSettings:addSection("Configuration")

SectionSettings:addKeybind("Toggle UI Keybind", Enum.KeyCode.RightShift, function()
    UI:toggle()
end)

SectionSettings:addButton("Rejoin Server", function()
    local ts = game:GetService("TeleportService")
    ts:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
end)

SectionSettings:addButton("Unload Nopxnop", function()
    -- Disconnect all events
    for _, conn in pairs(Connections) do
        if conn and conn.Disconnect then
            conn:Disconnect()
        end
    end
    -- Reset lighting
    Lighting.Ambient = OriginalLighting.Ambient
    Lighting.OutdoorAmbient = OriginalLighting.OutdoorAmbient
    Lighting.Brightness = OriginalLighting.Brightness
    Lighting.FogEnd = OriginalLighting.FogEnd
    -- Reset character stats
    local hum = getHumanoid()
    if hum then
        hum.WalkSpeed = 16
        hum.JumpPower = 50
    end
    -- Destroy safe platform
    if SafePlatformPart and SafePlatformPart.Parent then
        SafePlatformPart:Destroy()
    end
    -- Reset loaded flag
    getgenv().NopxnopLoaded = false
    
    -- Close and remove GUI
    local coreGui = game:GetService("CoreGui")
    local venyxGui = coreGui:FindFirstChild("Venyx") or PlayerGui:FindFirstChild("Venyx")
    if venyxGui then
        venyxGui:Destroy()
    end
end)

-- Cleanup handler for reloads
getgenv().NopxnopCleanup = function()
    for _, conn in pairs(Connections) do
        if conn and conn.Disconnect then
            conn:Disconnect()
        end
    end
    if SafePlatformPart and SafePlatformPart.Parent then
        SafePlatformPart:Destroy()
    end
    getgenv().NopxnopLoaded = false
end

-- Select Initial Page
UI:SelectPage(PageFishing, true)

-- Notifications / Load Banner
print([[
=============================================
   [Nopxnop] Loaded successfully!
   Game: Fish It!
   UI: Venyx Interface
   Keybind: Press RightShift to Toggle UI
=============================================
]])
