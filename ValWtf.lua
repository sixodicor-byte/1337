-- FPS unlock
setfpscap(300)


-- Re-execute protection (before library load)
if getgenv().ValenokUnload then pcall(getgenv().ValenokUnload) end

-- Library load
local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/bdimka251212-del/NewLib/refs/heads/main/NewLib.lua"))()
local ThemeManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/bdimka251212-del/NewLib/refs/heads/main/addons/ThemeManager.lua"))()
local SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/bdimka251212-del/NewLib/refs/heads/main/addons/SaveManager.lua"))()

-- Services
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Camera = game:GetService("Workspace").CurrentCamera
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")
local VirtualInputManager = game:GetService("VirtualInputManager")

-- Camera/weapons helpers
local function getCamera()
    Camera = Workspace.CurrentCamera
    return Camera
end
local function getWeaponsFolder()
    return ReplicatedStorage:FindFirstChild("Weapons")
end

-- Forward declarations
local updateBhop
local restoreAllRapidFireRates
local updateRCS
local updateFullAuto
local updateRapidFire
local updateNoScope
local updateNoFlash

-- Runtime states (must be declared before UI)
local RapidFireState = {
    SavedFireRates = {},
}

local FullAutoState = {
    SavedAutoValues = {}
}

local InstaWeaponState = {
    SavedEquipTimes = {},
    SavedReloadTimes = {},
}

local SavedRecoilValues = {}
local OriginalAccuracySd = nil

local RCSOriginalValues = {}


-- Main window
local Window = Library:CreateWindow({
    Title = 'Valenok',
    Center = true,
    AutoShow = true,
})


-- Tabs
local Tabs = {
    Rage = Window:AddTab('Rage'),
    Legit = Window:AddTab('Legit'),
    Visual = Window:AddTab('Visual'),
    Skin = Window:AddTab('Skin'),
    Movement = Window:AddTab('Movement'),
    Config = Window:AddTab('Config'),
}


-- Rage sections
local RageSections = {
    Ragebot = Tabs.Rage:AddLeftGroupbox('Ragebot'),
    PeekAssist = Tabs.Rage:AddRightGroupbox('Peek assist'),
    AntiAim = Tabs.Rage:AddLeftGroupbox('Anti aim'),
    GunMods = Tabs.Rage:AddRightGroupbox('Gun mods'),
    Misc = Tabs.Rage:AddRightGroupbox('Misc'),
    Exploit = Tabs.Rage:AddRightGroupbox('Exploit'),
}





-- Legit sections
local LegitSections = {
    Aimbot = Tabs.Legit:AddLeftGroupbox('Aim bot'),
    Triggerbot = Tabs.Legit:AddRightGroupbox('Trigger bot'),
    RCS = Tabs.Legit:AddRightGroupbox('RCS'),
}

-- Aimbot UI
LegitSections.Aimbot:AddToggle('AimbotEnable', {Text = 'Enable', Default = false})


-- Aimbot keybind
LegitSections.Aimbot:AddLabel('Keybind'):AddKeyPicker('AimbotKeybind', {Default = 'None', Mode = 'Hold', Text = 'Aimbot'})


-- Aimbot checks
LegitSections.Aimbot:AddToggle('AimbotVisibleCheck', {Text = 'Visible check', Default = false})


LegitSections.Aimbot:AddToggle('AimbotTeamCheck', {Text = 'Team check', Default = false})


-- Aimbot FOV
LegitSections.Aimbot:AddToggle('AimbotShowFOV', {Text = 'Show FOV', Default = false})


-- Aimbot hitbox
LegitSections.Aimbot:AddDropdown('AimbotHitbox', {Values = { 'Head', 'Body', 'Nearest' }, Default = 'Head', Text = 'Hit box'})


-- Aimbot baim
LegitSections.Aimbot:AddToggle('AimbotBaim', {Text = 'Baim', Default = false})


-- Baim keybind
LegitSections.Aimbot:AddLabel('Baim keybind'):AddKeyPicker('AimbotBaimKeybind', {Default = 'None', Mode = 'Toggle', Text = 'Baim'})


-- Aimbot sliders
LegitSections.Aimbot:AddSlider('AimbotFOV', {Text = 'FOV', Default = 45, Min = 1, Max = 180, Rounding = 0})


LegitSections.Aimbot:AddSlider('AimbotSmooth', {Text = 'Smooth', Default = 4, Min = 1, Max = 10, Rounding = 0})

-- Triggerbot UI
LegitSections.Triggerbot:AddToggle('TriggerbotEnable', {Text = 'Enable', Default = false})


LegitSections.Triggerbot:AddToggle('TriggerbotTeamCheck', {Text = 'Team check', Default = false})


LegitSections.Triggerbot:AddToggle('TriggerbotOnStopOnly', {Text = 'On stop only', Default = false})


LegitSections.Triggerbot:AddToggle('TriggerbotMagnet', {Text = 'Magnet', Default = false})


-- Triggerbot delay
LegitSections.Triggerbot:AddSlider('TriggerbotDelay', {Text = 'Trigger bot delay', Default = 0, Min = 0, Max = 300, Rounding = 0})


-- Triggerbot keybind
LegitSections.Triggerbot:AddLabel('Keybind'):AddKeyPicker('TriggerbotKeybind', {Default = 'None', Mode = 'Toggle', Text = 'Trigger bot'})


-- RCS UI
LegitSections.RCS:AddToggle('RCSEnable', {Text = 'Enable', Default = false, Callback = function() updateRCS() end})


-- RCS slider
LegitSections.RCS:AddSlider('RCSValue', {Text = 'RCS', Default = 0, Min = 0, Max = 100, Rounding = 0, Callback = function() updateRCS() end})


-- Visual sections
local VisualSections = {
    ESP = Tabs.Visual:AddLeftGroupbox('ESP'),
    ThirdPerson = Tabs.Visual:AddLeftGroupbox('Third person'),
    Menu = Tabs.Visual:AddLeftGroupbox('Menu'),
    Removals = Tabs.Visual:AddRightGroupbox('Removals'),
    Grenades = Tabs.Visual:AddRightGroupbox('Grenades'),
    Ambience = Tabs.Visual:AddRightGroupbox('Ambience'),
    Self = Tabs.Visual:AddRightGroupbox('Self'),
}

-- Skin changer data
local SC_Viewmodels = ReplicatedStorage:WaitForChild("Viewmodels", 10)
local SC_Skins = ReplicatedStorage:WaitForChild("Skins", 10)
local SC_Models = nil
pcall(function() SC_Models = game:GetObjects("rbxassetid://7285197035")[1] end)
if SC_Models then repeat task.wait() until SC_Models ~= nil end
local SC_OriginalCTKnife = SC_Viewmodels and SC_Viewmodels:FindFirstChild("v_CT Knife") and SC_Viewmodels:FindFirstChild("v_CT Knife"):Clone()
local SC_OriginalTKnife = SC_Viewmodels and SC_Viewmodels:FindFirstChild("v_T Knife") and SC_Viewmodels:FindFirstChild("v_T Knife"):Clone()
local SC_AllKnives = { "CT Knife", "T Knife", "Banana", "Bayonet", "Bearded Axe", "Butterfly Knife", "Cleaver", "Crowbar", "Falchion Knife", "Flip Knife", "Gut Knife", "Huntsman Knife", "Karambit", "M9 Bayonet", "Sickle" }
if SC_Models and SC_Models:FindFirstChild("Knives") then
    for _, v in pairs(SC_Models.Knives:GetChildren()) do table.insert(SC_AllKnives, v.Name) end
end
local SC_AllWeapons = {}
local SC_AllSkins = {}
local SC_KnifeSkins = {}
if SC_Skins then
    for _, v in pairs(SC_Skins:GetChildren()) do
        local isKnife = false
        for _, knife in ipairs(SC_AllKnives) do
            local cl = knife:gsub(" Knife", ""):gsub(" Classic", ""):lower()
            if v.Name:lower() == cl or v.Name:lower():sub(1, #cl + 1) == cl .. " " then isKnife = true; break end
        end
        if not isKnife then table.insert(SC_AllWeapons, v.Name) end
    end
    table.sort(SC_AllWeapons, function(a, b) return a < b end)
    for _, v in ipairs(SC_AllWeapons) do
        SC_AllSkins[v] = {"Inventory"}
        for _, v2 in pairs(SC_Skins[v]:GetChildren()) do table.insert(SC_AllSkins[v], v2.Name) end
    end
    for _, knifeName in ipairs(SC_AllKnives) do
        SC_KnifeSkins[knifeName] = {"Inventory"}
        if SC_Skins:FindFirstChild(knifeName) then
            for _, skin in pairs(SC_Skins[knifeName]:GetChildren()) do table.insert(SC_KnifeSkins[knifeName], skin.Name) end
        end
    end
end
local SC_currentKnife = nil
local SC_swapping = false
local SC_armsConn = nil
local SC_SavedKnifeSkins = {}
local SC_SavedWeaponSkins = {}
local function SC_SwapKnifeModel(knifeName)
    if not SC_Viewmodels then return end
    if SC_swapping then return end
    if SC_currentKnife == knifeName then return end
    SC_swapping = true
    if SC_Viewmodels:FindFirstChild("v_CT Knife") then SC_Viewmodels:FindFirstChild("v_CT Knife"):Destroy() end
    if SC_Viewmodels:FindFirstChild("v_T Knife") then SC_Viewmodels:FindFirstChild("v_T Knife"):Destroy() end
    wait()
    if knifeName == "CT Knife" or knifeName == "T Knife" then
        if SC_OriginalCTKnife then SC_OriginalCTKnife:Clone().Parent = SC_Viewmodels end
        if SC_OriginalTKnife then SC_OriginalTKnife:Clone().Parent = SC_Viewmodels end
    else
        local sourceVM = nil
        if SC_Viewmodels:FindFirstChild("v_" .. knifeName) then
            sourceVM = SC_Viewmodels:FindFirstChild("v_" .. knifeName)
        elseif SC_Models and SC_Models:FindFirstChild("Knives") then
            local km = SC_Models.Knives:FindFirstChild(knifeName)
            if km then sourceVM = km end
        end
        if sourceVM then
            local ct = sourceVM:Clone(); ct.Name = "v_CT Knife"; ct.Parent = SC_Viewmodels
            local tt = sourceVM:Clone(); tt.Name = "v_T Knife"; tt.Parent = SC_Viewmodels
        else
            if SC_OriginalCTKnife then SC_OriginalCTKnife:Clone().Parent = SC_Viewmodels end
            if SC_OriginalTKnife then SC_OriginalTKnife:Clone().Parent = SC_Viewmodels end
        end
    end
    SC_currentKnife = knifeName
    SC_swapping = false
end
local function SC_applySkinToPart(targetPart, SkinData)
    if not (targetPart:IsA("BasePart") or targetPart:IsA("MeshPart")) then return end
    if targetPart.Transparency == 1 then return end
    local tex = nil
    local wm = SkinData:FindFirstChild("WorldModel")
    for _, Data in next, SkinData:GetDescendants() do
        if wm and Data:IsDescendantOf(wm) then continue end
        local n = Data.Name:gsub("^#%s*", "")
        if n == targetPart.Name or string.match(n, "^" .. targetPart.Name .. "%d*$") or (targetPart.Name == "Main" and (n == "Part1" or n == "Part")) then
            if Data:IsA("StringValue") then tex = Data.Value
            elseif Data:IsA("MeshPart") then tex = Data.TextureID
            elseif Data:IsA("Decal") or Data:IsA("Texture") then tex = Data.Texture
            elseif Data:IsA("SurfaceAppearance") then tex = Data end
            if tex and tex ~= "" and tex ~= "rbxassetid://0" then break end
        end
    end
    if (not tex or tex == "") then
        for _, Data in next, SkinData:GetDescendants() do
            if wm and Data:IsDescendantOf(wm) then continue end
            local n = Data.Name:gsub("^#%s*", "")
            if n == "Handle" and (targetPart.Name == "Blade" or targetPart.Name == "Main") then
                if Data:IsA("StringValue") then tex = Data.Value
                elseif Data:IsA("MeshPart") then tex = Data.TextureID
                elseif Data:IsA("Decal") or Data:IsA("Texture") then tex = Data.Texture
                elseif Data:IsA("SurfaceAppearance") then tex = Data end
                if tex and tex ~= "" and tex ~= "rbxassetid://0" then break end
            end
        end
    end
    if (not tex or tex == "") and wm then
        for _, Data in next, wm:GetDescendants() do
            local n = Data.Name:gsub("^#%s*", "")
            if n == targetPart.Name or string.match(n, "^" .. targetPart.Name .. "%d*$") or (targetPart.Name == "Main" and (n == "Part1" or n == "Part")) then
                if Data:IsA("StringValue") then tex = Data.Value
                elseif Data:IsA("MeshPart") then tex = Data.TextureID
                elseif Data:IsA("Decal") or Data:IsA("Texture") then tex = Data.Texture
                elseif Data:IsA("SurfaceAppearance") then tex = Data end
                if tex and tex ~= "" and tex ~= "rbxassetid://0" then break end
            end
        end
    end
    if (not tex or tex == "") and wm then
        for _, Data in next, wm:GetDescendants() do
            local n = Data.Name:gsub("^#%s*", "")
            if n == "Handle" and (targetPart.Name == "Blade" or targetPart.Name == "Main") then
                if Data:IsA("StringValue") then tex = Data.Value
                elseif Data:IsA("MeshPart") then tex = Data.TextureID
                elseif Data:IsA("Decal") or Data:IsA("Texture") then tex = Data.Texture
                elseif Data:IsA("SurfaceAppearance") then tex = Data end
                if tex and tex ~= "" and tex ~= "rbxassetid://0" then break end
            end
        end
    end
    if tex then
        if typeof(tex) == "Instance" and tex:IsA("SurfaceAppearance") then
            if targetPart:FindFirstChildWhichIsA("SurfaceAppearance") then targetPart:FindFirstChildWhichIsA("SurfaceAppearance"):Destroy() end
            tex:Clone().Parent = targetPart
        elseif targetPart:IsA("MeshPart") then targetPart.TextureID = tex
        elseif targetPart:FindFirstChild("Mesh") then targetPart.Mesh.TextureId = tex
        else pcall(function() targetPart.TextureID = tex end) end
    end
end
local function SC_applySkinToArms(armsObj, gunname, selectedSkin)
    if not SC_Skins then return end
    if not selectedSkin or selectedSkin == "Inventory" then return end
    if (gunname == "CT Knife" or gunname == "T Knife") and not SC_Skins:FindFirstChild(gunname) then gunname = "M9 Bayonet" end
    if not SC_Skins:FindFirstChild(gunname) then return end
    local SkinData = SC_Skins[gunname]:FindFirstChild(selectedSkin)
    if not SkinData or SkinData:FindFirstChild("Animated") then return end
    for _, targetPart in next, armsObj:GetDescendants() do SC_applySkinToPart(targetPart, SkinData) end
    local skinConn
    skinConn = armsObj.DescendantAdded:Connect(function(part) SC_applySkinToPart(part, SkinData) end)
    armsObj.AncestryChanged:Connect(function(_, newParent)
        if not newParent and skinConn then skinConn:Disconnect(); skinConn = nil end
    end)
end
local function SC_setupArmsWatcher()
    if SC_armsConn then SC_armsConn:Disconnect() end
    SC_armsConn = Camera.ChildAdded:Connect(function(obj)
        RunService.RenderStepped:Wait()
        if obj.Name ~= "Arms" then return end
        pcall(function()
            local Client = nil
            pcall(function() Client = getsenv(LocalPlayer.PlayerGui.Client) end)
            if not Client or Client.gun == "none" then return end
            local isMelee = Client.gun:FindFirstChild("Melee")
            local gunname = Client.gun.Name
            if Toggles.SkinKnifeChanger and Toggles.SkinKnifeChanger.Value and isMelee then
                local wantedKnife = Options.SkinKnifeModel and Options.SkinKnifeModel.Value
                if wantedKnife and SC_currentKnife ~= wantedKnife then
                    SC_SwapKnifeModel(wantedKnife)
                    wait()
                    obj:Destroy()
                    return
                end
                local kn = wantedKnife or "M9 Bayonet"
                if not SC_Skins:FindFirstChild(kn) then kn = "M9 Bayonet" end
                SC_applySkinToArms(obj, kn, SC_SavedKnifeSkins[wantedKnife] or "Inventory")
            elseif Toggles.SkinWeaponChanger and Toggles.SkinWeaponChanger.Value and not isMelee then
                SC_applySkinToArms(obj, gunname, SC_SavedWeaponSkins[gunname] or "Inventory")
            end
        end)
    end)
end

-- Skin sections
local SkinSections = {
    Knife = Tabs.Skin:AddLeftGroupbox('Knife Changer'),
    Weapon = Tabs.Skin:AddRightGroupbox('Weapon Skins'),
}
SkinSections.Knife:AddToggle('SkinKnifeChanger', {Text = 'Enable', Default = false, Callback = function()
    if Toggles.SkinKnifeChanger.Value then
        local wantedKnife = Options.SkinKnifeModel and Options.SkinKnifeModel.Value
        if wantedKnife then SC_SwapKnifeModel(wantedKnife) end
    elseif SC_Viewmodels then
        if SC_Viewmodels:FindFirstChild("v_CT Knife") then SC_Viewmodels:FindFirstChild("v_CT Knife"):Destroy() end
        if SC_Viewmodels:FindFirstChild("v_T Knife") then SC_Viewmodels:FindFirstChild("v_T Knife"):Destroy() end
        wait()
        if SC_OriginalCTKnife then SC_OriginalCTKnife:Clone().Parent = SC_Viewmodels end
        if SC_OriginalTKnife then SC_OriginalTKnife:Clone().Parent = SC_Viewmodels end
        SC_currentKnife = nil
    end
end})
SkinSections.Knife:AddDropdown('SkinKnifeModel', {Text = 'Knife', Values = #SC_AllKnives > 0 and SC_AllKnives or {"CT Knife"}, Default = 'Butterfly Knife', Callback = function()
    local wantedKnife = Options.SkinKnifeModel and Options.SkinKnifeModel.Value
    if wantedKnife then
        local skins = SC_KnifeSkins[wantedKnife] or {"Inventory"}
        Options.SkinKnifeSkin.Values = skins
        Options.SkinKnifeSkin:SetValues()
        Options.SkinKnifeSkin:SetValue(SC_SavedKnifeSkins[wantedKnife] or "Inventory")
        if Toggles.SkinKnifeChanger and Toggles.SkinKnifeChanger.Value then SC_SwapKnifeModel(wantedKnife) end
    end
end})
SkinSections.Knife:AddDropdown('SkinKnifeSkin', {Text = 'Knife Skin', Values = {'Inventory'}, Default = 'Inventory', Callback = function()
    local kn = Options.SkinKnifeModel and Options.SkinKnifeModel.Value
    local sk = Options.SkinKnifeSkin and Options.SkinKnifeSkin.Value
    if kn and sk then SC_SavedKnifeSkins[kn] = sk end
end})
SkinSections.Weapon:AddToggle('SkinWeaponChanger', {Text = 'Enable', Default = false})
local _SC_prevWeapon = SC_AllWeapons[1]
SkinSections.Weapon:AddDropdown('SkinWeaponModel', {Text = 'Weapon', Values = #SC_AllWeapons > 0 and SC_AllWeapons or {"AK-47"}, Default = SC_AllWeapons[1] or "AK-47", Callback = function()
    local weaponName = Options.SkinWeaponModel and Options.SkinWeaponModel.Value
    if _SC_prevWeapon and _SC_prevWeapon ~= weaponName then
        local curSkin = Options.SkinWeaponSkin and Options.SkinWeaponSkin.Value
        if curSkin then SC_SavedWeaponSkins[_SC_prevWeapon] = curSkin end
    end
    _SC_prevWeapon = weaponName
    if weaponName then
        local skins = SC_AllSkins[weaponName] or {"Inventory"}
        Options.SkinWeaponSkin.Values = skins
        Options.SkinWeaponSkin:SetValues()
        Options.SkinWeaponSkin:SetValue(SC_SavedWeaponSkins[weaponName] or "Inventory")
    end
end})
SkinSections.Weapon:AddDropdown('SkinWeaponSkin', {Text = 'Weapon Skin', Values = {'Inventory'}, Default = 'Inventory', Callback = function()
    local wn = Options.SkinWeaponModel and Options.SkinWeaponModel.Value
    local sk = Options.SkinWeaponSkin and Options.SkinWeaponSkin.Value
    if wn and sk then SC_SavedWeaponSkins[wn] = sk end
end})
SC_setupArmsWatcher()
do
    local ks = SC_KnifeSkins["Butterfly Knife"] or {"Inventory"}
    Options.SkinKnifeSkin.Values = ks
    Options.SkinKnifeSkin:SetValues()
    Options.SkinKnifeSkin:SetValue("Inventory")
    if #SC_AllWeapons > 0 then
        local ws = SC_AllSkins[SC_AllWeapons[1]] or {"Inventory"}
        Options.SkinWeaponSkin.Values = ws
        Options.SkinWeaponSkin:SetValues()
        Options.SkinWeaponSkin:SetValue("Inventory")
    end
end

local MovementSections = {
    Bhop = Tabs.Movement:AddLeftGroupbox('Bhop'),
    Movement = Tabs.Movement:AddRightGroupbox('Movement'),
    Strafe = Tabs.Movement:AddLeftGroupbox('Strafe'),
}

-- Bhop UI
MovementSections.Bhop:AddToggle('BhopEnable', {Text = 'Enable', Default = false, Callback = function() updateBhop() end})


-- Bhop slider
MovementSections.Bhop:AddSlider('BhopMultiplier', {Text = 'Bhop multiplier', Default = 1, Min = 1, Max = 3, Rounding = 2})


-- Strafe UI
MovementSections.Strafe:AddToggle('StrafeEnable', {Text = 'Strafe', Default = false})


MovementSections.Strafe:AddToggle('AirStrafeEnable', {Text = 'Air strafe', Default = false})


-- Ragebot UI
RageSections.Ragebot:AddToggle('RagebotEnable', {Text = 'Enable', Default = false})


-- Ragebot keybind
RageSections.Ragebot:AddLabel('Keybind'):AddKeyPicker('RagebotKeybind', {Default = 'None', Mode = 'Hold', Text = 'Ragebot'})


-- Ragebot options
RageSections.Ragebot:AddToggle('RagebotAutoFire', {Text = 'Automatic fire', Default = false})


RageSections.Ragebot:AddToggle('RagebotTeamCheck', {Text = 'Team check', Default = false})


RageSections.Ragebot:AddToggle('RagebotVisCheck', {Text = 'Vis check', Default = false})


RageSections.Ragebot:AddToggle('RagebotShowFOV', {Text = 'Show FOV', Default = false})


-- Ragebot FOV
RageSections.Ragebot:AddSlider('RagebotFOV', {Text = 'FOV', Default = 1, Min = 1, Max = 180, Rounding = 0})


-- Ragebot hitbox
RageSections.Ragebot:AddDropdown('RagebotHitbox', {Values = { 'Head', 'Body', 'Nearest' }, Default = 'Head', Text = 'Hit box'})


-- Ragebot baim
RageSections.Ragebot:AddToggle('RagebotBaim', {Text = 'Baim', Default = false})


-- Ragebot baim keybind
RageSections.Ragebot:AddLabel('Baim keybind'):AddKeyPicker('RagebotBaimKeybind', {Default = 'None', Mode = 'Toggle', Text = 'Baim'})


-- Peek Assist UI
RageSections.PeekAssist:AddToggle('PeekAssistEnable', {Text = 'Enable', Default = false})


-- Peek Assist keybind
RageSections.PeekAssist:AddLabel('Keybind'):AddKeyPicker('PeekAssistKeybind', {Default = 'None', Mode = 'Hold', Text = 'Peek Assist'})


-- Peek Assist mode
RageSections.PeekAssist:AddDropdown('PeekAssistRetreatMode', {Values = { 'On Key', 'On Shot' }, Default = 'On Key', Text = 'Retreat Mode'})


-- Anti Aim UI
RageSections.AntiAim:AddToggle('AntiAimEnable', {Text = 'Enable', Default = false})


-- Anti Aim pitch
RageSections.AntiAim:AddToggle('AntiAimPitch', {Text = 'Pitch', Default = false})


RageSections.AntiAim:AddDropdown('AntiAimPitchMode', {Values = { 'None', 'Up', 'Down', 'Random' }, Default = 'None', Text = 'Pitch mode'})


-- Anti Aim yaw
RageSections.AntiAim:AddToggle('AntiAimYaw', {Text = 'Yaw', Default = false})


RageSections.AntiAim:AddDropdown('AntiAimYawMode', {Values = { 'Local', 'At target', 'Random' }, Default = 'Local', Text = 'Yaw mode'})


RageSections.AntiAim:AddSlider('AntiAimYawValue', {Text = 'Yaw value', Default = 0, Min = -180, Max = 180, Rounding = 0})


-- Gun Mods UI
RageSections.GunMods:AddToggle('GunModsNoRecoil', {Text = 'No recoil', Default = false, Callback = function(Value)
        local Weapons = getWeaponsFolder()
        if not Weapons then return end
        for _, weaponFolder in ipairs(Weapons:GetChildren()) do
            if not weaponFolder:IsA("Folder") then continue end
            local spread = weaponFolder:FindFirstChild("Spread")
            if not spread then continue end
            local recoil = spread:FindFirstChild("Recoil")
            if not recoil or not recoil:IsA("NumberValue") then continue end
            if Value then
                if SavedRecoilValues[weaponFolder.Name] == nil then SavedRecoilValues[weaponFolder.Name] = recoil.Value end
                recoil.Value = 1
            else
                local original = SavedRecoilValues[weaponFolder.Name]
                if original ~= nil then recoil.Value = original; SavedRecoilValues[weaponFolder.Name] = nil end
            end
        end
    end})


-- No spread
RageSections.GunMods:AddToggle('GunModsNoSpread', {Text = 'No spread', Default = false, Callback = function(Value)
        local Players = game:GetService("Players")
        local LocalPlayer = Players.LocalPlayer
        local clientGui = LocalPlayer.PlayerGui:WaitForChild("Client", 5)
        if not clientGui then return end
        local success, Client = pcall(function() return getsenv(clientGui) end)
        if success and Client then
            if Value then
                if OriginalAccuracySd == nil then OriginalAccuracySd = Client.accuracy_sd end
                Client.accuracy_sd = 0
            else
                if OriginalAccuracySd ~= nil then Client.accuracy_sd = OriginalAccuracySd end
            end
        end
    end})


-- Rapid fire
RageSections.GunMods:AddToggle('GunModsRapidFire', {Text = 'Rapid fire', Default = false, Callback = function(Value) if not Value then restoreAllRapidFireRates() else updateRapidFire() end end})


-- Insta equip
RageSections.GunMods:AddToggle('GunModsInstaEquip', {Text = 'Insta equip', Default = false, Callback = function(Value)
        local Weapons = getWeaponsFolder()
        if not Weapons then return end
        if Value then
            for _, weaponFolder in ipairs(Weapons:GetChildren()) do
                if weaponFolder:IsA("Folder") then
                    local EquipTime = weaponFolder:FindFirstChild("EquipTime")
                    if EquipTime and EquipTime:IsA("NumberValue") then
                        if InstaWeaponState.SavedEquipTimes[weaponFolder.Name] == nil then InstaWeaponState.SavedEquipTimes[weaponFolder.Name] = EquipTime.Value end
                        EquipTime.Value = 0
                    end
                end
            end
        else
            for weaponName, original in pairs(InstaWeaponState.SavedEquipTimes) do
                local weaponFolder = Weapons:FindFirstChild(weaponName)
                local EquipTime = weaponFolder and weaponFolder:FindFirstChild("EquipTime")
                if EquipTime and EquipTime:IsA("NumberValue") then EquipTime.Value = original end
            end
            table.clear(InstaWeaponState.SavedEquipTimes)
        end
    end})


-- Insta reload
RageSections.GunMods:AddToggle('GunModsInstaReload', {Text = 'Insta reload', Default = false, Callback = function(Value)
        local Weapons = getWeaponsFolder()
        if not Weapons then return end
        if Value then
            for _, weaponFolder in ipairs(Weapons:GetChildren()) do
                if weaponFolder:IsA("Folder") then
                    local ReloadTime = weaponFolder:FindFirstChild("ReloadTime")
                    if ReloadTime and ReloadTime:IsA("NumberValue") then
                        if InstaWeaponState.SavedReloadTimes[weaponFolder.Name] == nil then InstaWeaponState.SavedReloadTimes[weaponFolder.Name] = ReloadTime.Value end
                        ReloadTime.Value = 0.1
                    end
                end
            end
        else
            for weaponName, original in pairs(InstaWeaponState.SavedReloadTimes) do
                local weaponFolder = Weapons:FindFirstChild(weaponName)
                local ReloadTime = weaponFolder and weaponFolder:FindFirstChild("ReloadTime")
                if ReloadTime and ReloadTime:IsA("NumberValue") then ReloadTime.Value = original end
            end
            table.clear(InstaWeaponState.SavedReloadTimes)
        end
    end})


-- Misc UI
RageSections.Misc:AddToggle('MiscBulletTracer', {Text = 'Bullet tracer', Default = false})


-- Bullet tracer color
RageSections.Misc:AddLabel('Bullet tracer color'):AddColorPicker('MiscBulletTracerColor', {Default = Color3.fromRGB(255, 0, 0), Title = 'Bullet tracer color'})


-- Bullet tracer texture
RageSections.Misc:AddDropdown('MiscBulletTracerTexture', {
    Text = 'Tracer texture',
    Values = {"Solid","Lightning","Laser","Twisted Energy","Anime Lazer","Arrow","Minecraft","Alien Energy Ray","Energy Ray","Matrix","Cartoony Eletric"},
    Default = "Laser",
})


-- Hit sound
RageSections.Misc:AddToggle('MiscHitSound', {Text = 'Hit sound', Default = false})


RageSections.Misc:AddDropdown('MiscHitSoundType', {Values = { 'Skeet', 'Neverlose', 'Bameware', 'Bell', 'Bubble', 'Pick', 'Pop', 'Rust', 'Sans', 'Fart', 'Big', 'Vine', 'Bruh', 'Fatality', 'Bonk', 'Minecraft', 'Moan' }, Default = 'Skeet', Text = 'Hit sound type'})


RageSections.Misc:AddSlider('MiscHitSoundVolume', {Text = 'Volume', Default = 5, Min = 1, Max = 10, Rounding = 0})


-- Full auto
RageSections.Misc:AddToggle('MiscFullAuto', {Text = 'Full auto', Default = false, Callback = function() updateFullAuto() end})


-- Hit chams
RageSections.Misc:AddToggle('MiscHitChams', {Text = 'Hit chams', Default = false})


-- Hit chams color
RageSections.Misc:AddLabel('Hit chams color'):AddColorPicker('MiscHitChamsColor', {Default = Color3.fromRGB(255, 0, 0), Title = 'Hit chams color'})


-- Exploit UI
RageSections.Exploit:AddToggle('ExploitKillAll', {Text = 'Kill all', Default = false})


-- Kill All keybind
RageSections.Exploit:AddLabel('Keybind'):AddKeyPicker('ExploitKillAllKeybind', {Default = 'None', Mode = 'Hold', Text = 'Kill All'})


-- No fall damage
RageSections.Exploit:AddToggle('ExploitNoFallDamage', {Text = 'No fall damage', Default = false})


-- ESP UI
VisualSections.ESP:AddToggle('ESPEnable', {Text = 'Enable', Default = false})


VisualSections.ESP:AddToggle('ESPTeamCheck', {Text = 'Team check', Default = false})


VisualSections.ESP:AddToggle('ESPBox', {Text = 'Box', Default = false})


VisualSections.ESP:AddToggle('ESPName', {Text = 'Name', Default = false})


VisualSections.ESP:AddToggle('ESPHealthBar', {Text = 'Health bar', Default = false})


VisualSections.ESP:AddToggle('ESPWeapon', {Text = 'Weapon ESP', Default = false})


VisualSections.ESP:AddToggle('ESPChams', {Text = 'Chams', Default = false})


VisualSections.ESP:AddToggle('ESPChamsOutline', {Text = 'Chams outline', Default = false})


VisualSections.ESP:AddLabel('Chams outline color'):AddColorPicker('ESPChamsOutlineColor', {Default = Color3.fromRGB(255, 255, 255), Title = 'Chams outline color'})


VisualSections.ESP:AddDropdown('ESPFont', {Values = { 'UI', 'System', 'Plex', 'Monospace' }, Default = 'Plex', Text = 'Font'})


-- Chams transparency
VisualSections.ESP:AddSlider('ESPChamsTransparency', {Text = 'Chams transparency', Default = 35, Min = 0, Max = 100, Rounding = 0})


-- ESP colors
VisualSections.ESP:AddLabel('Box color'):AddColorPicker('ESPBoxColor', {Default = Color3.fromRGB(255, 255, 255), Title = 'Box color'})

VisualSections.ESP:AddLabel('Name color'):AddColorPicker('ESPNameColor', {Default = Color3.fromRGB(255, 255, 255), Title = 'Name color'})

VisualSections.ESP:AddLabel('Weapon color'):AddColorPicker('ESPWeaponColor', {Default = Color3.fromRGB(255, 255, 255), Title = 'Weapon color'})

VisualSections.ESP:AddLabel('Chams color'):AddColorPicker('ESPChamsColor', {Default = Color3.fromRGB(255, 255, 255), Title = 'Chams color'})

VisualSections.ESP:AddLabel('Health bar color'):AddColorPicker('ESPHealthBarColor', {Default = Color3.fromRGB(0, 255, 0), Title = 'Health bar color'})


-- Menu UI
VisualSections.Menu:AddToggle('MenuBindList', {Text = 'Bind list', Default = true, Callback = function(Value) if Library.KeybindFrame then Library.KeybindFrame.Visible = Value end end})
VisualSections.Menu:AddToggle('MenuWatermark', {Text = 'Watermark', Default = true, Callback = function(Value) Library:SetWatermarkVisibility(Value) end})


-- Removals UI
VisualSections.Removals:AddToggle('RemovalsNoSmoke', {Text = 'No smoke', Default = false})


VisualSections.Removals:AddToggle('RemovalsNoFlash', {Text = 'No flash', Default = false, Callback = function() updateNoFlash() end})


VisualSections.Removals:AddToggle('RemovalsNoScope', {Text = 'No scope', Default = false, Callback = function() updateNoScope() end})


-- Grenades UI
VisualSections.Grenades:AddToggle('GrenadesPrediction', {Text = 'Grenade prediction', Default = false})


-- Grenade color
VisualSections.Grenades:AddLabel('Prediction color'):AddColorPicker('GrenadesPredictionColor', {Default = Color3.fromRGB(255, 0, 0), Title = 'Prediction color'})


-- Self UI
VisualSections.Self:AddToggle('SelfFOVEnable', {Text = 'FOV', Default = false})


-- FOV slider
VisualSections.Self:AddSlider('SelfFOV', {Text = 'FOV value', Default = 70, Min = 30, Max = 120, Rounding = 0})


-- Third Person UI
VisualSections.ThirdPerson:AddToggle('ThirdPersonEnable', {Text = 'Enable', Default = false})


-- Third Person keybind
VisualSections.ThirdPerson:AddLabel('Keybind'):AddKeyPicker('ThirdPersonKeybind', {Default = 'None', Mode = 'Toggle', Text = 'Third person'})


-- Third Person distance
VisualSections.ThirdPerson:AddSlider('ThirdPersonDistance', {Text = 'Distance', Default = 5, Min = 1, Max = 10, Rounding = 0})


-- Theme & Save
ThemeManager:SetLibrary(Library)
SaveManager:SetLibrary(Library)
SaveManager:IgnoreThemeSettings()
ThemeManager:SetFolder('Valenok')
SaveManager:SetFolder('Valenok')


-- ESP runtime
local EspRuntime = {
    Drawings = {},
    Highlights = {},
    Connections = {},
}


-- Aim runtime
local AimRuntime = {
    FovLines = {},
    CurrentTarget = nil,
}


-- Hit Chams runtime
local HitChamsState = {
    ObservedPlayers = {},
    PlayerConns = {},
    ChamsFolder = nil,
    ActiveClones = 0,
    MaxClones = 20,
}


-- Hitbox fallbacks
local AimHitboxFallbacks = {
    Head = { "HeadHB", "Head", "FakeHead" },
    Body = { "UpperTorso", "LowerTorso", "Torso", "HumanoidRootPart" },
}

-- Real body hitbox names (no weapons, accessories, C4, etc.)
local RealHitboxNames = {
    "Head", "HeadHB", "FakeHead",
    "UpperTorso", "LowerTorso", "HumanoidRootPart",
    "LeftUpperArm", "LeftLowerArm", "LeftHand",
    "RightUpperArm", "RightLowerArm", "RightHand",
    "LeftUpperLeg", "LeftLowerLeg", "LeftFoot",
    "RightUpperLeg", "RightLowerLeg", "RightFoot",
}
local RealHitboxLookup = {}
for _, name in ipairs(RealHitboxNames) do RealHitboxLookup[name] = true end


-- Triggerbot state
local TriggerbotState = {
    AwaitingRelease = false,
    NextFireTime = 0,
    StopTime = 0,
    WasMoving = false,
    Holding = false,
    DelayUntil = 0,
    DelayActive = false,
}


-- Raycast params
local VisibilityParams = RaycastParams.new()
VisibilityParams.FilterType = Enum.RaycastFilterType.Exclude
VisibilityParams.IgnoreWater = true


-- Bullet tracer texture map
local TracerTextureMap = {
    ["Solid"] = "rbxassetid://446111271",
    ["Lightning"] = "rbxassetid://7216850022",
    ["Laser"] = "rbxassetid://7136858729",
    ["Twisted Energy"] = "rbxassetid://7071778278",
    ["Anime Lazer"] = "rbxassetid://17441065350",
    ["Arrow"] = "rbxassetid://1274378728",
    ["Minecraft"] = "rbxassetid://152410036",
    ["Alien Energy Ray"] = "rbxassetid://6091341618",
    ["Energy Ray"] = "rbxassetid://13832105797",
    ["Matrix"] = "rbxassetid://15097610754",
    ["Cartoony Eletric"] = "rbxassetid://18722421816",
}


-- Forward declaration (getOptionColor is defined later)
local getOptionColor

-- Draw bullet tracer beam
local function drawBulletTracer(startPos, endPos)
    if not Toggles.MiscBulletTracer or not Toggles.MiscBulletTracer.Value then return end

    local color = getOptionColor("MiscBulletTracerColor", Color3.fromRGB(255, 0, 0))
    local tracerMode = Options.MiscBulletTracerTexture and Options.MiscBulletTracerTexture.Value or "Laser"
    local textureId = TracerTextureMap[tracerMode] or TracerTextureMap["Laser"]

    local holderPart = Instance.new("Part")
    holderPart.Size = Vector3.new(0.1, 0.1, 0.1)
    holderPart.Transparency = 1
    holderPart.CanCollide = false
    holderPart.Anchored = true
    holderPart.Position = startPos
    holderPart.Parent = workspace

    local attachment0 = Instance.new("Attachment", holderPart)

    local targetPart = Instance.new("Part")
    targetPart.Size = Vector3.new(0.1, 0.1, 0.1)
    targetPart.Transparency = 1
    targetPart.CanCollide = false
    targetPart.Anchored = true
    targetPart.Position = endPos
    targetPart.Parent = workspace

    local attachment1 = Instance.new("Attachment", targetPart)

    local beam = Instance.new("Beam")
    beam.Color = ColorSequence.new(color)
    beam.LightEmission = 1
    beam.LightInfluence = 0
    beam.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.3),
        NumberSequenceKeypoint.new(1, 0.3),
    })
    beam.Width0 = 0.25
    beam.Width1 = 0.25
    beam.Attachment0 = attachment0
    beam.Attachment1 = attachment1
    beam.FaceCamera = true
    beam.Texture = textureId
    beam.Parent = holderPart

    task.defer(function()
        Debris:AddItem(holderPart, 1.4)
        Debris:AddItem(targetPart, 1.4)
    end)
end


-- Namecall hook
local PlayHitSound
local _oldNamecall = nil
local function restoreNamecallHook()
    pcall(function()
        if _oldNamecall then
            hookmetamethod(game, "__namecall", _oldNamecall)
            _oldNamecall = nil
        end
    end)
end


-- Team check
local function teamCheck(player, allowTeam)
    if not player then return false end
    local myTeam = LocalPlayer.Team
    local theirTeam = player.Team
    if myTeam == nil or theirTeam == nil then return true end
    if allowTeam then
        return true
    else
        return theirTeam ~= myTeam
    end
end


-- Anti Aim globals
getgenv().ValenokPitchDownEnabled = false
getgenv().ValenokPitchValue = 0
getgenv().LastControlTurnArgs = {0, false}
getgenv().LastRandomPitch = 0
getgenv().LastPitchUpdate = 0
getgenv().LastSentPitch = nil

-- Get ControlTurn remote
local _controlTurnRemote = nil
local function getControlTurnRemote()
    if _controlTurnRemote and _controlTurnRemote.Parent then return _controlTurnRemote end
    if not ReplicatedStorage then return nil end
    _controlTurnRemote = ReplicatedStorage:FindFirstChild("ControlTurn")
        or (ReplicatedStorage:FindFirstChild("Remotes") and ReplicatedStorage.Remotes:FindFirstChild("ControlTurn"))
        or Workspace:FindFirstChild("ControlTurn")
    return _controlTurnRemote
end

pcall(function()
    _oldNamecall = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
        if checkcaller() then return _oldNamecall(self, ...) end

        local method = getnamecallmethod()

        if method == "FireServer" and self.Name == "ControlTurn" then
            if getgenv().IgnoreHook then return _oldNamecall(self, ...) end
            if getgenv().ValenokPitchDownEnabled == true then
                local args = {...}
                local pitchValue = tonumber(getgenv().ValenokPitchValue) or 0
                local pitch = math.clamp((pitchValue / 100) * (math.pi / 2), -1.57, 1.57)
                args[1] = pitch
                getgenv().LastControlTurnArgs = args
                return _oldNamecall(self, unpack(args))
            end
        end

        if method == "FireServer" then
            local args = table.pack(...)
            if args[1] == "HitParl" then
                if Toggles.MiscHitSound and Toggles.MiscHitSound.Value then
                    PlayHitSound()
                end
            end

            if self.Name == "ReplicateShot" and Toggles.MiscBulletTracer and Toggles.MiscBulletTracer.Value then
                local originPos = getgenv().LastBulletTracerOrigin
                local targetPos = getgenv().LastBulletTracerTarget

                if not originPos or not targetPos then
                    local Cam = Workspace.CurrentCamera
                    originPos = Cam.CFrame.Position - Vector3.new(0, 0.4, 0)
                    if typeof(args[2]) == "Vector3" then
                        targetPos = args[2]
                    elseif typeof(args[1]) == "Instance" and args[1]:IsA("BasePart") then
                        targetPos = args[1].Position
                    else
                        targetPos = Cam.CFrame.Position + (Cam.CFrame.LookVector * 500)
                    end
                end

                drawBulletTracer(originPos, targetPos)

                getgenv().LastBulletTracerOrigin = nil
                getgenv().LastBulletTracerTarget = nil
            end
        end

        if method == "Raycast" and self == Workspace and not getgenv().IgnoreRaycastHook then
            local targetPos = getgenv().PSilentTargetPos
            if targetPos then
                local Cam = Workspace.CurrentCamera
                local camPos = Cam and Cam.CFrame.Position
                if camPos then
                    local delta = targetPos - camPos
                    if delta.Magnitude > 1e-4 then
                        local args = {...}
                        getgenv().LastBulletTracerOrigin = camPos
                        getgenv().LastBulletTracerTarget = targetPos
                        args[2] = delta.Unit * 200
                        return _oldNamecall(self, unpack(args))
                    end
                end
            end
        end

        return _oldNamecall(self, ...)
    end))
end)


pcall(function()
    local additionals = LocalPlayer:WaitForChild("Additionals", 5)
    if additionals then
        local totalDamage = additionals:FindFirstChild("TotalDamage")
        if totalDamage then
            local oldDamage = totalDamage.Value
            EspRuntime.Connections.TotalDamageChanged = totalDamage.Changed:Connect(function(newVal)
                if newVal > oldDamage then
                    if Toggles.MiscHitSound and Toggles.MiscHitSound.Value then
                        PlayHitSound()
                    end
                end
                oldDamage = newVal
            end)
        end
    end
end)


-- Create FOV circle
if getgenv().ValenokFovLines then
    for _, ln in ipairs(getgenv().ValenokFovLines) do
        pcall(function() ln:Remove() end)
    end
end
getgenv().ValenokFovLines = AimRuntime.FovLines

for i = 1, 164 do
    local ln = Drawing.new("Line")
    ln.Visible = false
    ln.Thickness = 1
    ln.Transparency = 1
    ln.Color = Color3.fromRGB(255, 255, 255)
    AimRuntime.FovLines[i] = ln
end


-- Find KillAll remote
local KillAllHitRemote = nil
for _, obj in pairs(ReplicatedStorage:GetDescendants()) do
    if obj:IsA("RemoteEvent") and obj.Name:lower():find("hit") then
        KillAllHitRemote = obj
        break
    end
end


-- Hit sounds
local HitSounds = {
    ["Skeet"] = "rbxassetid://5633695679",
    ["Neverlose"] = "rbxassetid://6534948092",
    ["Bameware"] = "rbxassetid://3124331820",
    ["Bell"] = "rbxassetid://6534947240",
    ["Bubble"] = "rbxassetid://6534947588",
    ["Pick"] = "rbxassetid://1347140027",
    ["Pop"] = "rbxassetid://198598793",
    ["Rust"] = "rbxassetid://1255040462",
    ["Sans"] = "rbxassetid://3188795283",
    ["Fart"] = "rbxassetid://130833677",
    ["Big"] = "rbxassetid://5332005053",
    ["Vine"] = "rbxassetid://5332680810",
    ["Bruh"] = "rbxassetid://4578740568",
    ["Fatality"] = "rbxassetid://6534947869",
    ["Bonk"] = "rbxassetid://5766898159",
    ["Minecraft"] = "rbxassetid://4018616850",
    ["Moan"] = {
        "rbxassetid://2440888376", "rbxassetid://2440889605",
        "rbxassetid://2440889869", "rbxassetid://2440889381", "rbxassetid://2440891382"
    }
}

local _hitSoundObj = Instance.new("Sound")
_hitSoundObj.Parent = workspace
PlayHitSound = function()
    if not Toggles.MiscHitSound or not Toggles.MiscHitSound.Value then return end
    local soundType = Options.MiscHitSoundType and Options.MiscHitSoundType.Value or "Skeet"
    local sndId = HitSounds[soundType]
    if type(sndId) == "table" then
        sndId = sndId[math.random(1, #sndId)]
    end
    _hitSoundObj.SoundId = sndId or "rbxassetid://3124331820"
    _hitSoundObj.Volume = Options.MiscHitSoundVolume and Options.MiscHitSoundVolume.Value or 5
    _hitSoundObj:Play()
end


-- Hit Chams functions
local function getHitChamsFolder()
    if not HitChamsState.ChamsFolder or not HitChamsState.ChamsFolder.Parent then
        HitChamsState.ChamsFolder = Instance.new("Folder")
        HitChamsState.ChamsFolder.Name = "HitChamsFolder_" .. tostring(tick())
        HitChamsState.ChamsFolder.Parent = workspace
    end
    return HitChamsState.ChamsFolder
end

local function cleanupHitChams()
    if HitChamsState.ActiveClones > HitChamsState.MaxClones then
        local folder = getHitChamsFolder()
        local clones = folder:GetChildren()
        if #clones > HitChamsState.MaxClones then
            for i = 1, #clones - HitChamsState.MaxClones do
                if clones[i] then clones[i]:Destroy() end
            end
            HitChamsState.ActiveClones = HitChamsState.MaxClones
        end
    end
end

local _hitChamsIgnoreParts = { ["HumanoidRootPart"] = true, ["FakeHead"] = true, ["C4"] = true, ["Gun"] = true }

local function runHitChamsOptimized(playerObj, color, material)
    if not playerObj or not playerObj.Character then return end
    if HitChamsState.ActiveClones >= HitChamsState.MaxClones then
        cleanupHitChams()
    end

    local chamsFolder = getHitChamsFolder()

    for _, part in ipairs(playerObj.Character:GetChildren()) do
        if HitChamsState.ActiveClones >= HitChamsState.MaxClones then break end
        if (part:IsA("MeshPart") and part.Transparency ~= 1) or part.Name == "Head" then
            if not _hitChamsIgnoreParts[part.Name] then
                local clone = part:Clone()
                if clone then
                    clone:ClearAllChildren()
                    clone.CFrame = part.CFrame
                    clone.Material = material
                    clone.Color = color
                    clone.CanCollide = false
                    clone.Anchored = true
                    clone.CastShadow = false
                    clone.Transparency = material == Enum.Material.ForceField and 0 or 0.5
                    clone.Parent = chamsFolder
                    HitChamsState.ActiveClones = HitChamsState.ActiveClones + 1

                    task.delay(0.7, function()
                        if clone and clone.Parent then
                            clone.Transparency = 1
                            clone:Destroy()
                            HitChamsState.ActiveClones = math.max(0, HitChamsState.ActiveClones - 1)
                        end
                    end)
                end
            end
        end
    end
end

local function observePlayerForHitChams(player)
    if player == LocalPlayer then return end
    if HitChamsState.ObservedPlayers[player] then return end
    HitChamsState.ObservedPlayers[player] = true
    HitChamsState.PlayerConns[player] = HitChamsState.PlayerConns[player] or {}

    local function setupCharacter(character)
        local humanoid = character:WaitForChild("Humanoid", 3)
        if humanoid then
            local lastHealth = humanoid.Health

            local conn = humanoid.HealthChanged:Connect(function(currentHealth)
                if currentHealth < lastHealth and Toggles.MiscHitChams and Toggles.MiscHitChams.Value then
                    local color = Options.MiscHitChamsColor and Options.MiscHitChamsColor.Value or Color3.fromRGB(255, 0, 0)
                    local material = Enum.Material.ForceField
                    runHitChamsOptimized(player, color, material)
                end
                lastHealth = currentHealth
            end)
            table.insert(HitChamsState.PlayerConns[player], conn)
        end
    end

    if player.Character then setupCharacter(player.Character) end
    local charConn = player.CharacterAdded:Connect(setupCharacter)
    table.insert(HitChamsState.PlayerConns[player], charConn)
end

local function updateHitChams()
    if not Toggles.MiscHitChams or not Toggles.MiscHitChams.Value then return end

    for _, player in ipairs(Players:GetPlayers()) do
        observePlayerForHitChams(player)
    end
end


-- Gun Mods helpers
local CachedClient = nil
local function getCachedClient()
    if CachedClient then return CachedClient end
    local ok, client = pcall(function()
        local pg = LocalPlayer:FindFirstChild("PlayerGui")
        local cg = pg and pg:FindFirstChild("Client")
        return cg and getsenv(cg)
    end)
    if ok and client then
        CachedClient = client
        return client
    end
    return nil
end


-- Get weapon fire rate
local function getCurrentWeaponFireRateObject()
    local character = LocalPlayer.Character
    if not character then return nil, nil end

    local weaponName = nil
    if character:FindFirstChild("EquippedTool") then
        weaponName = tostring(character.EquippedTool.Value)
    end

    if not weaponName then return nil, nil end

    local Weapons = getWeaponsFolder()
    if not Weapons then return nil, nil end

    local weaponFolder = Weapons:FindFirstChild(weaponName)
    if not weaponFolder then return nil, nil end

    local FireRate = weaponFolder:FindFirstChild("FireRate")
    if FireRate and FireRate:IsA("NumberValue") then
        return FireRate, weaponName
    end

    return nil, nil
end


-- Restore rapid fire
restoreAllRapidFireRates = function()
    local Weapons = getWeaponsFolder()
    if Weapons then
        for weaponName, original in pairs(RapidFireState.SavedFireRates) do
            local weaponFolder = Weapons:FindFirstChild(weaponName)
            local FireRate = weaponFolder and weaponFolder:FindFirstChild("FireRate")
            if FireRate and FireRate:IsA("NumberValue") then
                FireRate.Value = original
            end
        end
    end
    table.clear(RapidFireState.SavedFireRates)
end


-- Restore full auto
local function restoreAllFullAutoValues()
    local Weapons = getWeaponsFolder()
    if Weapons then
        for weaponName, originalValue in pairs(FullAutoState.SavedAutoValues) do
            local weaponFolder = Weapons:FindFirstChild(weaponName)
            if weaponFolder then
                local AutoValue = weaponFolder:FindFirstChild("Auto")
                if AutoValue and AutoValue:IsA("BoolValue") then
                    AutoValue.Value = originalValue
                end
            end
        end
    end
    table.clear(FullAutoState.SavedAutoValues)
end


-- Aimbot helpers
local function hasShield(Character)
    if not Character then return false end
    local shield = Character:FindFirstChild("Shield") or Character:FindFirstChild("ForceField")
    return shield ~= nil
end


-- Find character part
local function findCharacterPart(Character, PartName)
    local Part = Character:FindFirstChild(PartName)
    if Part and Part:IsA("BasePart") then
        return Part
    end
end


-- Get aim hitbox
local function getAimHitboxPart(Character, Humanoid)
    local SelectedHitbox = Options.AimbotHitbox and Options.AimbotHitbox.Value or "Head"
    
    if SelectedHitbox == "Nearest" then
        local AllParts = {}
        for _, part in ipairs(Character:GetChildren()) do
            if part:IsA("BasePart") and RealHitboxLookup[part.Name] then
                table.insert(AllParts, part)
            end
        end
        
        local BestPart = nil
        local BestDistance = math.huge
        local ScreenCenter = Vector2.new(Camera.ViewportSize.X * 0.5, Camera.ViewportSize.Y * 0.5)
        
        for _, part in ipairs(AllParts) do
            local screenPoint = Camera:WorldToViewportPoint(part.Position)
            if screenPoint.Z > 0 then
                local distance = (Vector2.new(screenPoint.X, screenPoint.Y) - ScreenCenter).Magnitude
                if distance < BestDistance then
                    BestDistance = distance
                    BestPart = part
                end
            end
        end
        
        return BestPart
    end
    
    local Fallbacks = AimHitboxFallbacks[SelectedHitbox] or AimHitboxFallbacks.Head

    for _, PartName in ipairs(Fallbacks) do
        local Part = findCharacterPart(Character, PartName)
        if Part then
            return Part
        end
    end

    return nil
end


-- Check aim key
local function isAimKeyActive()
    local KeybindState = Options.AimbotKeybind
    if not KeybindState or type(KeybindState) ~= "table" then return false end

    local mode = KeybindState.Mode
    if mode == "Always" then
        return true
    elseif mode == "Hold" then
        local key = KeybindState.Value
        if key == 'None' then
            return false
        elseif key == 'MB1' or key == 'MB2' or key == 'MB3' then
            return key == 'MB1' and UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
                or key == 'MB2' and UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
                or key == 'MB3' and UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton3)
        else
            return UserInputService:IsKeyDown(Enum.KeyCode[key])
        end
    else -- Toggle
        return KeybindState.Toggled == true
    end
end


-- Check baim key
local function isBaimKeyActive()
    if not Toggles.AimbotBaim or not Toggles.AimbotBaim.Value then return false end
    
    local KeybindState = Options.AimbotBaimKeybind
    if not KeybindState or type(KeybindState) ~= "table" then return false end

    local mode = KeybindState.Mode
    if mode == "Always" then
        return true
    elseif mode == "Hold" then
        local key = KeybindState.Value
        if key == 'None' then
            return false
        elseif key == 'MB1' or key == 'MB2' or key == 'MB3' then
            return key == 'MB1' and UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
                or key == 'MB2' and UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
                or key == 'MB3' and UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton3)
        else
            return UserInputService:IsKeyDown(Enum.KeyCode[key])
        end
    else -- Toggle
        return KeybindState.Toggled == true
    end
end


-- Visible check helper
local function shouldUseVisibleCheck()
    return Toggles.AimbotVisibleCheck and Toggles.AimbotVisibleCheck.Value
end


-- Get aim FOV
local function getAimFov()
    local FovValue = Options.AimbotFOV and Options.AimbotFOV.Value
    if type(FovValue) ~= "number" then
        return 45
    end
    return math.clamp(FovValue, 1, 180)
end


-- Get aim smooth
local function getAimSmooth()
    local SmoothValue = Options.AimbotSmooth and Options.AimbotSmooth.Value
    if type(SmoothValue) ~= "number" then
        return 4
    end
    return math.clamp(SmoothValue, 1, 10)
end


-- Get FOV radius
local _cachedAimFovRadius = nil
local _cachedAimFovKey = nil
local function getAimFovRadius()
    local AimFov = getAimFov()
    local key = AimFov .. "_" .. Camera.FieldOfView .. "_" .. Camera.ViewportSize.Y
    if _cachedAimFovKey == key then return _cachedAimFovRadius end
    _cachedAimFovKey = key
    local Viewport = Camera.ViewportSize
    local HalfViewport = Viewport.Y * 0.5
    local CamFovHalfRad = math.rad(Camera.FieldOfView * 0.5)
    local AimFovHalfRad = math.rad(AimFov * 0.5)

    if AimFov >= 180 then
        _cachedAimFovRadius = 999999
        return 999999
    end
    _cachedAimFovRadius = (math.tan(AimFovHalfRad) / math.tan(CamFovHalfRad)) * HalfViewport
    return _cachedAimFovRadius
end


-- Strict visibility check
local RayIgnoreList = {Camera, nil, nil}
local function isStrictRayVisible(TargetPart)
    if not TargetPart or not TargetPart.Parent then return false end

    local Origin = Camera.CFrame.Position
    local Direction = TargetPart.Position - Origin

    RayIgnoreList[2] = LocalPlayer.Character
    RayIgnoreList[3] = Workspace:FindFirstChild("Ray_Ignore")
    VisibilityParams.FilterDescendantsInstances = RayIgnoreList

    getgenv().IgnoreRaycastHook = true
    local ok, result = pcall(function() return Workspace:Raycast(Origin, Direction, VisibilityParams) end)
    getgenv().IgnoreRaycastHook = false
    local RaycastResult = ok and result or nil

    if not RaycastResult or not RaycastResult.Instance then return false end

    local hitInst = RaycastResult.Instance

    if hitInst == TargetPart then
        return true
    end

    if hitInst.Parent:IsA("Accessory") and hitInst.Parent.Parent == TargetPart.Parent then
        return true
    end

    local isSmoke = hitInst.Name == "Smoke" or hitInst.Name:find("Smoke") or (hitInst.Material and hitInst.Material.Name == "Smoke")
    if isSmoke then
        return true
    end

    return false
end


-- Is target visible
local function isVisibleTarget(Character)
    if not Character then return false end

    local SelectedHitbox = Options.AimbotHitbox and Options.AimbotHitbox.Value or "Head"
    local Fallbacks = AimHitboxFallbacks[SelectedHitbox] or AimHitboxFallbacks.Head

    for _, PartName in ipairs(Fallbacks) do
        local Part = findCharacterPart(Character, PartName)
        if Part then
            return isStrictRayVisible(Part)
        end
    end

    return false
end


-- Is enemy player
local function isEnemy(Player)
    if Player == LocalPlayer then return false end

    if Toggles.AimbotTeamCheck and Toggles.AimbotTeamCheck.Value then
        local MyTeam, TheirTeam = LocalPlayer.Team, Player.Team
        local MyTeamColor, TheirTeamColor = LocalPlayer.TeamColor, Player.TeamColor
        
        if MyTeam ~= nil and TheirTeam ~= nil and TheirTeam == MyTeam then
            return false
        end
        
        if MyTeamColor ~= nil and TheirTeamColor ~= nil and TheirTeamColor == MyTeamColor then
            return false
        end
    end

    return true
end


-- Get closest aim target
local function getClosestAimTarget(ScreenCenter, FovRadius)
    local BestPart = nil
    local BestMetric = math.huge
    local UseVisible = shouldUseVisibleCheck()
    local IsFullCircle = getAimFov() >= 180
    local CamLook = Camera.CFrame.LookVector
    local CamPos = Camera.CFrame.Position

    local function evaluatePart(TargetPart, Character)
        if IsFullCircle then
            local Dir = (TargetPart.Position - CamPos).Unit
            local Angle = math.acos(math.clamp(CamLook:Dot(Dir), -1, 1))
            if UseVisible and not isVisibleTarget(Character) then return end
            if Angle < BestMetric then
                BestMetric = Angle
                BestPart = TargetPart
            end
        else
            local ScreenPoint = Camera:WorldToViewportPoint(TargetPart.Position)
            if ScreenPoint.Z <= 0 then return end
            local DistanceFromCrosshair = (Vector2.new(ScreenPoint.X, ScreenPoint.Y) - ScreenCenter).Magnitude
            if DistanceFromCrosshair > FovRadius then return end
            if UseVisible and not isVisibleTarget(Character) then return end
            if DistanceFromCrosshair < BestMetric then
                BestMetric = DistanceFromCrosshair
                BestPart = TargetPart
            end
        end
    end

    local playerList = Players:GetPlayers()
    for _, Player in ipairs(playerList) do
        if not isEnemy(Player) then continue end

        local Character = Player.Character
        if not Character then continue end
        
        if hasShield(Character) then continue end

        local Humanoid = Character:FindFirstChildOfClass("Humanoid")
        local RootPart = Character:FindFirstChild("HumanoidRootPart")
        if not Humanoid or Humanoid.Health <= 0 or not RootPart then continue end

        local TargetPart
        
        if isBaimKeyActive() then
            local bodyFallbacks = { "UpperTorso", "LowerTorso", "Torso", "HumanoidRootPart" }
            for _, bName in ipairs(bodyFallbacks) do
                local bPart = findCharacterPart(Character, bName)
                if bPart then
                    TargetPart = bPart
                    break
                end
            end
        else
            TargetPart = getAimHitboxPart(Character, Humanoid)
        end

        if not TargetPart then continue end

        evaluatePart(TargetPart, Character)
    end

    return BestPart
end


-- Check part targetable
local function isPartTargetable(TargetPart, ScreenCenter, FovRadius)
    if not TargetPart or not TargetPart.Parent then return false end

    local Character = TargetPart.Parent
    if not Character or not Character.Parent then return false end

    if hasShield(Character) then return false end

    local Humanoid = Character:FindFirstChildOfClass("Humanoid")
    if not Humanoid or Humanoid.Health <= 0 then return false end

    if shouldUseVisibleCheck() and not isVisibleTarget(Character) then
        return false
    end

    if getAimFov() >= 180 then
        return true
    end

    local ScreenPoint = Camera:WorldToViewportPoint(TargetPart.Position)
    if ScreenPoint.Z <= 0 then return false end

    local DistanceFromCrosshair = (Vector2.new(ScreenPoint.X, ScreenPoint.Y) - ScreenCenter).Magnitude
    if DistanceFromCrosshair > (FovRadius * 1.15) then return false end

    return true
end


-- Ragebot FOV radius (moved before updateFovCircle)
local _cachedRageFovRadius = nil
local _cachedRageFovKey = nil
local function getRagebotFovRadius()
    local FovValue = Options.RagebotFOV and Options.RagebotFOV.Value
    if type(FovValue) ~= "number" then
        FovValue = 1
    end
    FovValue = math.clamp(FovValue, 1, 180)

    local key = FovValue .. "_" .. Camera.FieldOfView .. "_" .. Camera.ViewportSize.Y
    if _cachedRageFovKey == key then return _cachedRageFovRadius end
    _cachedRageFovKey = key

    local Viewport = Camera.ViewportSize
    local HalfViewport = Viewport.Y * 0.5
    local CamFovHalfRad = math.rad(Camera.FieldOfView * 0.5)
    local AimFovHalfRad = math.rad(FovValue * 0.5)

    if FovValue >= 180 then
        _cachedRageFovRadius = 999999
        return 999999
    end
    _cachedRageFovRadius = (math.tan(AimFovHalfRad) / math.tan(CamFovHalfRad)) * HalfViewport
    return _cachedRageFovRadius
end


-- Update FOV circle
local FovSinCos = {}
local FovSinCosCount = 0
local function updateFovCircle()
    local Camera = getCamera()
    if not Camera then return end
    local ShowAimFov = Toggles.AimbotShowFOV and Toggles.AimbotShowFOV.Value
    local ShowRageFov = Toggles.RagebotShowFOV and Toggles.RagebotShowFOV.Value
    local RadiusAim = ShowAimFov and getAimFovRadius() or 0
    local RadiusRage = ShowRageFov and getRagebotFovRadius() or 0

    if not Camera or (not ShowAimFov and not ShowRageFov) then
        for _, Line in ipairs(AimRuntime.FovLines) do
            Line.Visible = false
        end
        return
    end

    local Viewport = Camera.ViewportSize
    local Center = Vector2.new(Viewport.X * 0.5, Viewport.Y * 0.5)
    local PartLines = math.floor(#AimRuntime.FovLines / 2)

    if FovSinCosCount ~= PartLines then
        FovSinCosCount = PartLines
        local Step = (math.pi * 2) / PartLines
        for i = 1, PartLines do
            local Angle = (i - 1) * Step
            FovSinCos[i] = {math.cos(Angle), math.sin(Angle), math.cos(Angle + Step), math.sin(Angle + Step)}
        end
    end

    -- Aimbot FOV (first half of lines)
    if ShowAimFov and RadiusAim > 0 then
        local White = Color3.fromRGB(255, 255, 255)
        for i = 1, PartLines do
            local Line = AimRuntime.FovLines[i]
            local sc = FovSinCos[i]
            Line.From = Vector2.new(Center.X + sc[1] * RadiusAim, Center.Y + sc[2] * RadiusAim)
            Line.To = Vector2.new(Center.X + sc[3] * RadiusAim, Center.Y + sc[4] * RadiusAim)
            Line.Color = White
            Line.Visible = true
        end
    else
        for i = 1, PartLines do
            AimRuntime.FovLines[i].Visible = false
        end
    end

    -- Ragebot FOV (second half of lines)
    if ShowRageFov and RadiusRage > 0 then
        local White = Color3.fromRGB(255, 255, 255)
        for i = 1, PartLines do
            local Line = AimRuntime.FovLines[PartLines + i]
            local sc = FovSinCos[i]
            Line.From = Vector2.new(Center.X + sc[1] * RadiusRage, Center.Y + sc[2] * RadiusRage)
            Line.To = Vector2.new(Center.X + sc[3] * RadiusRage, Center.Y + sc[4] * RadiusRage)
            Line.Color = White
            Line.Visible = true
        end
    else
        for i = 1, PartLines do
            if AimRuntime.FovLines[PartLines + i] then
                AimRuntime.FovLines[PartLines + i].Visible = false
            end
        end
    end
end


-- Update aimbot
local function updateAimBot()
    local Camera = getCamera()
    local aimShouldRun = Toggles.AimbotEnable and Toggles.AimbotEnable.Value and isAimKeyActive()
    if not Camera or not aimShouldRun then
        AimRuntime.CurrentTarget = nil
        return
    end

    local Viewport = Camera.ViewportSize
    local ScreenCenter = Vector2.new(Viewport.X * 0.5, Viewport.Y * 0.5)
    local FovRadius = getAimFovRadius()

    local TargetPart = AimRuntime.CurrentTarget
    if not isPartTargetable(TargetPart, ScreenCenter, FovRadius) then
        TargetPart = getClosestAimTarget(ScreenCenter, FovRadius)
        AimRuntime.CurrentTarget = TargetPart
    end

    if not TargetPart then return end

    local SmoothValue = getAimSmooth()
    local aimPos = TargetPart.Position
    local TargetCFrame = CFrame.lookAt(Camera.CFrame.Position, aimPos)

    if SmoothValue <= 1 then
        Camera.CFrame = TargetCFrame
    else
        local Speed = 32 - ((SmoothValue - 1) * 3)
        local LerpAlpha = math.clamp(0.016 * Speed, 0.05, 0.9)
        Camera.CFrame = Camera.CFrame:Lerp(TargetCFrame, LerpAlpha)
    end
end


-- Removals helpers
local function applyNoScope(enabled)
    local gui = LocalPlayer.PlayerGui:FindFirstChild("GUI")
    if not gui then return end
    local crosshairs = gui:FindFirstChild("Crosshairs")
    if not crosshairs then return end

    local scope = crosshairs:FindFirstChild("Scope")
    if scope then
        pcall(function() scope.ImageTransparency = enabled and 1 or 0 end)
        local innerScope = scope:FindFirstChild("Scope")
        if innerScope then
            pcall(function()
                innerScope.ImageTransparency = enabled and 1 or 0
                if enabled then
                    innerScope.Size = UDim2.new(2, 0, 2, 0)
                    innerScope.Position = UDim2.new(-0.5, 0, -0.5, 0)
                else
                    innerScope.Size = UDim2.new(1, 0, 1, 0)
                    innerScope.Position = UDim2.new(0, 0, 0, 0)
                end
            end)
            local blur = innerScope:FindFirstChild("Blur")
            if blur then
                pcall(function() blur.ImageTransparency = enabled and 1 or 0 end)
                local blur2 = blur:FindFirstChild("Blur")
                if blur2 then
                    pcall(function() blur2.ImageTransparency = enabled and 1 or 0 end)
                end
            end
        end
    end

    for _, frameName in ipairs({"Frame1", "Frame2", "Frame3", "Frame4"}) do
        local frame = crosshairs:FindFirstChild(frameName)
        if frame then
            pcall(function() frame.Transparency = enabled and 1 or 0 end)
        end
    end
end


-- Update no scope
updateNoScope = function()
    if not Toggles.RemovalsNoScope or not Toggles.RemovalsNoScope.Value then
        applyNoScope(false)
        return
    end
    applyNoScope(true)
end


-- Update no flash
updateNoFlash = function()
    local blnd = LocalPlayer.PlayerGui and LocalPlayer.PlayerGui:FindFirstChild("Blnd")
    if blnd then
        blnd.Enabled = not (Toggles.RemovalsNoFlash and Toggles.RemovalsNoFlash.Value)
    end
end


-- Update FOV
local OriginalFOV = Camera.FieldOfView
local LastFOV = Camera.FieldOfView
local function updateFOV()
    local Camera = getCamera()
    if not Camera then return end
    local target = (Toggles.SelfFOVEnable and Toggles.SelfFOVEnable.Value)
        and (Options.SelfFOV and Options.SelfFOV.Value or 70)
        or OriginalFOV
    if target ~= LastFOV then
        Camera.FieldOfView = target
        LastFOV = target
    end
end


-- No smoke via ChildAdded
local _noSmokeConn = nil
local function setupNoSmoke()
    if _noSmokeConn then return end
    local rayIgnore = Workspace:FindFirstChild("Ray_Ignore")
    if not rayIgnore then
        if not EspRuntime.Connections.NoSmokeRetry then
            EspRuntime.Connections.NoSmokeRetry = Workspace.ChildAdded:Connect(function(child)
                if child.Name == "Ray_Ignore" then
                    if EspRuntime.Connections.NoSmokeRetry then
                        EspRuntime.Connections.NoSmokeRetry:Disconnect()
                        EspRuntime.Connections.NoSmokeRetry = nil
                    end
                    setupNoSmoke()
                end
            end)
        end
        return
    end
    local smokesFolder = rayIgnore:FindFirstChild("Smokes")
    if not smokesFolder then
        if not EspRuntime.Connections.NoSmokeRetry then
            EspRuntime.Connections.NoSmokeRetry = rayIgnore.ChildAdded:Connect(function(child)
                if child.Name == "Smokes" then
                    if EspRuntime.Connections.NoSmokeRetry then
                        EspRuntime.Connections.NoSmokeRetry:Disconnect()
                        EspRuntime.Connections.NoSmokeRetry = nil
                    end
                    setupNoSmoke()
                end
            end)
        end
        return
    end
    _noSmokeConn = smokesFolder.ChildAdded:Connect(function(child)
        if Toggles.RemovalsNoSmoke and Toggles.RemovalsNoSmoke.Value then
            child:Destroy()
        end
    end)
    EspRuntime.Connections.NoSmokeChildAdded = _noSmokeConn
end
setupNoSmoke()


-- RCS helpers
updateRCS = function()
    local Weapons = getWeaponsFolder()
    if not Weapons then return end

    local rcsEnabled = Toggles.RCSEnable and Toggles.RCSEnable.Value
    local rcsValue = Options.RCSValue and Options.RCSValue.Value or 0

    for _, weaponFolder in ipairs(Weapons:GetChildren()) do
        if not weaponFolder:IsA("Folder") then continue end
        local spread = weaponFolder:FindFirstChild("Spread")
        if not spread then continue end
        local recoil = spread:FindFirstChild("Recoil")
        if not recoil or not recoil:IsA("NumberValue") then continue end

        if rcsEnabled and rcsValue > 0 then
            -- Сохраняем оригинальное значение если еще не сохранено
            if RCSOriginalValues[weaponFolder.Name] == nil then
                RCSOriginalValues[weaponFolder.Name] = recoil.Value
            end

            local original = RCSOriginalValues[weaponFolder.Name]
            local reductionPercent = rcsValue / 100
            local newValue = original * (1 - reductionPercent)
            recoil.Value = math.max(newValue, 1)
        else
            -- Восстанавливаем оригинальное значение
            local original = RCSOriginalValues[weaponFolder.Name]
            if original ~= nil then
                recoil.Value = original
                RCSOriginalValues[weaponFolder.Name] = nil
            end
        end
    end
end


-- Ragebot helpers
local function isRagebotKeyActive()
    local KeybindState = Options.RagebotKeybind
    if not KeybindState or type(KeybindState) ~= "table" then return false end

    local mode = KeybindState.Mode
    if mode == "Always" then
        return true
    elseif mode == "Hold" then
        local key = KeybindState.Value
        if key == 'None' then
            return false
        elseif key == 'MB1' or key == 'MB2' or key == 'MB3' then
            return key == 'MB1' and UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
                or key == 'MB2' and UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
                or key == 'MB3' and UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton3)
        else
            return UserInputService:IsKeyDown(Enum.KeyCode[key])
        end
    else -- Toggle
        return KeybindState.Toggled == true
    end
end


-- Ragebot baim key
local function isRagebotBaimKeyActive()
    if not Toggles.RagebotBaim or not Toggles.RagebotBaim.Value then return false end

    local KeybindState = Options.RagebotBaimKeybind
    if not KeybindState or type(KeybindState) ~= "table" then return false end

    local mode = KeybindState.Mode
    if mode == "Always" then
        return true
    elseif mode == "Hold" then
        local key = KeybindState.Value
        if key == 'None' then
            return false
        elseif key == 'MB1' or key == 'MB2' or key == 'MB3' then
            return key == 'MB1' and UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
                or key == 'MB2' and UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
                or key == 'MB3' and UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton3)
        else
            return UserInputService:IsKeyDown(Enum.KeyCode[key])
        end
    else -- Toggle
        return KeybindState.Toggled == true
    end
end


-- Get ragebot target
local function getRagebotTarget()
    local BestPart = nil
    local BestMetric = math.huge
    local UseVisible = Toggles.RagebotVisCheck and Toggles.RagebotVisCheck.Value
    local IsFullCircle = (Options.RagebotFOV and Options.RagebotFOV.Value or 1) >= 180
    local CamLook = Camera.CFrame.LookVector
    local CamPos = Camera.CFrame.Position

    local function evaluatePart(TargetPart, Character)
        if IsFullCircle then
            local Dir = (TargetPart.Position - CamPos).Unit
            local Angle = math.acos(math.clamp(CamLook:Dot(Dir), -1, 1))
            if UseVisible and not isVisibleTarget(Character) then return end
            if Angle < BestMetric then
                BestMetric = Angle
                BestPart = TargetPart
            end
        else
            local ScreenPoint = Camera:WorldToViewportPoint(TargetPart.Position)
            if ScreenPoint.Z <= 0 then return end
            local DistanceFromCrosshair = (Vector2.new(ScreenPoint.X, ScreenPoint.Y) - Vector2.new(Camera.ViewportSize.X * 0.5, Camera.ViewportSize.Y * 0.5)).Magnitude
            if DistanceFromCrosshair > getRagebotFovRadius() then return end
            if UseVisible and not isVisibleTarget(Character) then return end
            if DistanceFromCrosshair < BestMetric then
                BestMetric = DistanceFromCrosshair
                BestPart = TargetPart
            end
        end
    end

    local playerList = Players:GetPlayers()
    for _, Player in ipairs(playerList) do
        if Player == LocalPlayer then continue end

        if Toggles.RagebotTeamCheck and Toggles.RagebotTeamCheck.Value then
            local MyTeam, TheirTeam = LocalPlayer.Team, Player.Team
            if MyTeam ~= nil and TheirTeam ~= nil and TheirTeam == MyTeam then
                continue
            end
        end

        local Character = Player.Character
        if not Character then continue end
        
        if hasShield(Character) then continue end

        local Humanoid = Character:FindFirstChildOfClass("Humanoid")
        local RootPart = Character:FindFirstChild("HumanoidRootPart")
        if not Humanoid or Humanoid.Health <= 0 or not RootPart then continue end

        local TargetPart

        if isRagebotBaimKeyActive() then
            local bodyFallbacks = { "UpperTorso", "LowerTorso", "Torso", "HumanoidRootPart" }
            for _, bName in ipairs(bodyFallbacks) do
                local bPart = findCharacterPart(Character, bName)
                if bPart then
                    TargetPart = bPart
                    break
                end
            end
        else
            -- Head priority: try head hitboxes first
            local headParts = { "HeadHB", "Head", "FakeHead" }
            for _, hName in ipairs(headParts) do
                local hPart = findCharacterPart(Character, hName)
                if hPart then
                    TargetPart = hPart
                    break
                end
            end

            -- If no head found, fall back to priority hierarchy: body/arms → legs
            if not TargetPart then
                local ScreenCenter = Vector2.new(Camera.ViewportSize.X * 0.5, Camera.ViewportSize.Y * 0.5)
                local BestPart = nil
                local BestDistance = math.huge

                local priorityGroups = {
                    { "UpperTorso", "LowerTorso", "HumanoidRootPart", "LeftUpperArm", "LeftLowerArm", "LeftHand", "RightUpperArm", "RightLowerArm", "RightHand" },
                    { "LeftUpperLeg", "LeftLowerLeg", "LeftFoot", "RightUpperLeg", "RightLowerLeg", "RightFoot" },
                }

                for _, group in ipairs(priorityGroups) do
                    BestPart = nil
                    BestDistance = math.huge
                    for _, partName in ipairs(group) do
                        local part = findCharacterPart(Character, partName)
                        if part then
                            local screenPoint = Camera:WorldToViewportPoint(part.Position)
                            if screenPoint.Z > 0 then
                                local distance = (Vector2.new(screenPoint.X, screenPoint.Y) - ScreenCenter).Magnitude
                                if distance < BestDistance then
                                    BestDistance = distance
                                    BestPart = part
                                end
                            end
                        end
                    end
                    if BestPart then break end
                end

                TargetPart = BestPart
            end
        end

        if not TargetPart then continue end

        evaluatePart(TargetPart, Character)
    end

    return BestPart
end


-- Ragebot state
local RagebotState = {
    NextFireTime = 0,
}


-- Update ragebot
local function updateRagebot()
    local Camera = getCamera()
    if not Camera then return end
    local ragebotEnabled = Toggles.RagebotEnable and Toggles.RagebotEnable.Value
    local keyActive = isRagebotKeyActive()

    if not ragebotEnabled or not keyActive then
        getgenv().PSilentTargetPos = nil
        return
    end

    local targetPart = getRagebotTarget()

    if targetPart then
        getgenv().PSilentTargetPos = targetPart.Position

        -- Auto fire
        if Toggles.RagebotAutoFire and Toggles.RagebotAutoFire.Value then
            local character = LocalPlayer.Character
            local humanoid = character and character:FindFirstChildOfClass("Humanoid")
            if character and humanoid and humanoid.Health > 0 then
                local now = tick()
                if now >= RagebotState.NextFireTime and not RagebotState.Firing then
                    RagebotState.NextFireTime = now + 0.13
                    RagebotState.Firing = true
                    task.spawn(function()
                        local Mouse = LocalPlayer:GetMouse()
                        local mouseX = Mouse.X
                        local mouseY = Mouse.Y
                        pcall(function()
                            VirtualInputManager:SendMouseButtonEvent(mouseX, mouseY, 0, true, game, 1)
                            task.wait(0.1)
                            VirtualInputManager:SendMouseButtonEvent(mouseX, mouseY, 0, false, game, 1)
                        end)
                        RagebotState.Firing = false
                    end)
                end
            end
        end
    else
        getgenv().PSilentTargetPos = nil
    end
end


-- Храним оригинальную скорость
local originalWalkSpeed = 16

-- Anti Aim helpers
local function updateAntiAim()
    local Camera = getCamera()
    if not Camera then return end
    local PitchEnabled = Toggles.AntiAimPitch and Toggles.AntiAimPitch.Value
    local YawEnabled = Toggles.AntiAimYaw and Toggles.AntiAimYaw.Value
    local YawMode = Options.AntiAimYawMode and Options.AntiAimYawMode.Value or "Local"
    local YawValue = Options.AntiAimYawValue and Options.AntiAimYawValue.Value or 0
    local PitchMode = Options.AntiAimPitchMode and Options.AntiAimPitchMode.Value or "None"

    local character = LocalPlayer.Character
    if not character then return end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if not (humanoid and rootPart) or humanoid.Health <= 0 then return end

    if not PitchEnabled and not YawEnabled then
        humanoid.AutoRotate = true
        getgenv().ValenokPitchDownEnabled = false
        return
    end

    if PitchEnabled then
        getgenv().ValenokPitchDownEnabled = true
        if PitchMode == "Up" then
            getgenv().ValenokPitchValue = 100
        elseif PitchMode == "Down" then
            getgenv().ValenokPitchValue = -100
        elseif PitchMode == "Random" then
            if tick() - getgenv().LastPitchUpdate > 0.15 then
                getgenv().LastRandomPitch = math.random(-100, 100)
                getgenv().LastPitchUpdate = tick()
            end
            getgenv().ValenokPitchValue = getgenv().LastRandomPitch
        else
            getgenv().ValenokPitchValue = 0
        end

        local remote = getControlTurnRemote()
        if remote then
            local pitchValue = tonumber(getgenv().ValenokPitchValue) or 0
            local pitch = math.clamp((pitchValue / 100) * (math.pi / 2), -1.57, 1.57)
            if pitch ~= getgenv().LastSentPitch then
                getgenv().LastSentPitch = pitch
                getgenv().IgnoreHook = true
                remote:FireServer(pitch)
                getgenv().IgnoreHook = false
            end
        end
    else
        getgenv().ValenokPitchDownEnabled = false
    end

    if YawEnabled then
        humanoid.AutoRotate = false

        local yawRad = math.rad(YawValue)
        local lookVector = Vector3.new(0, 0, -1)

        if YawMode == "At target" then
            local closestPlayer = nil
            local closestDist = math.huge

            for _, player in pairs(Players:GetPlayers()) do
                if player == LocalPlayer then continue end
                local pTeam = player.Team
                local lpTeam = LocalPlayer.Team
                if pTeam and lpTeam and pTeam == lpTeam then continue end

                local char = player.Character
                if not char then continue end
                local hrp = char:FindFirstChild("HumanoidRootPart")
                if not hrp then continue end
                local hum = char:FindFirstChildOfClass("Humanoid")
                if not hum or hum.Health <= 0 then continue end

                local dist = (hrp.Position - rootPart.Position).Magnitude
                if dist < closestDist then
                    closestDist = dist
                    closestPlayer = player
                end
            end

            if closestPlayer and closestPlayer.Character then
                local targetHrp = closestPlayer.Character:FindFirstChild("HumanoidRootPart")
                if targetHrp then
                    local toTarget = targetHrp.Position - rootPart.Position
                    local flatDist = math.sqrt(toTarget.X ^ 2 + toTarget.Z ^ 2)
                    if flatDist > 0.01 then
                        lookVector = Vector3.new(toTarget.X / flatDist, 0, toTarget.Z / flatDist)
                    end
                    if PitchEnabled then
                        if PitchMode == "Down" then
                            yawRad = math.rad(-180)
                        elseif PitchMode == "Up" then
                            yawRad = math.rad(0)
                        end
                    end
                end
            else
                local camLook = Camera.CFrame.LookVector
                lookVector = Vector3.new(camLook.X, 0, camLook.Z).Unit
            end
        elseif YawMode == "Random" then
            if tick() - (getgenv().LastRandomYaw or 0) > (1/60) then
                getgenv().LastRandomYaw = tick()
                getgenv().RandomYawValue = math.random(-180, 180)
            end
            yawRad = math.rad(getgenv().RandomYawValue or 0)
            local camLook = Camera.CFrame.LookVector
            lookVector = Vector3.new(camLook.X, 0, camLook.Z).Unit
        else
            local camLook = Camera.CFrame.LookVector
            lookVector = Vector3.new(camLook.X, 0, camLook.Z).Unit
        end

        if lookVector.Magnitude > 0 then
            rootPart.CFrame = CFrame.lookAt(rootPart.Position, rootPart.Position + lookVector) * CFrame.Angles(0, yawRad, 0)
        end
    else
        humanoid.AutoRotate = true
    end

end

-- Bhop helpers
local BhopState = { Conn = nil }

updateBhop = function()
    if BhopState.Conn then
        BhopState.Conn:Disconnect()
        BhopState.Conn = nil
    end
    if not (Toggles.BhopEnable and Toggles.BhopEnable.Value) then return end
    BhopState.Conn = RunService.RenderStepped:Connect(function()
        local character = LocalPlayer.Character
        if not character then return end
        local rootPart = character:FindFirstChild("HumanoidRootPart")
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        if not (rootPart and humanoid) or humanoid.Health <= 0 then return end

        local Camera = getCamera()
        if not Camera then return end

        if UserInputService:IsKeyDown(Enum.KeyCode.Space) and humanoid.FloorMaterial ~= Enum.Material.Air then
            humanoid.Jump = true
        end

        local camLook = Camera.CFrame.LookVector
        local camRight = Camera.CFrame.RightVector
        local mx, mz = 0, 0
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then mx = mx + camLook.X; mz = mz + camLook.Z end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then mx = mx - camLook.X; mz = mz - camLook.Z end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then mx = mx - camRight.X; mz = mz - camRight.Z end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then mx = mx + camRight.X; mz = mz + camRight.Z end

        local multiplier = Options.BhopMultiplier and Options.BhopMultiplier.Value or 1
        if not multiplier or multiplier <= 0 then multiplier = 1 end
        local targetSpeed = 16 * multiplier
        local currentVel = rootPart.AssemblyLinearVelocity

        local mag = math.sqrt(mx * mx + mz * mz)
        if mag > 0 then
            local inv = targetSpeed / mag
            rootPart.AssemblyLinearVelocity = Vector3.new(mx * inv, currentVel.Y, mz * inv)
        else
            rootPart.AssemblyLinearVelocity = Vector3.new(0, currentVel.Y, 0)
        end
    end)
end


-- Strafe helpers
local function updateStrafe()
    if not Toggles.StrafeEnable or not Toggles.StrafeEnable.Value then return end
    if Toggles.BhopEnable and Toggles.BhopEnable.Value then return end

    local character = LocalPlayer.Character
    if not character then return end
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not (rootPart and humanoid) or humanoid.Health <= 0 then return end
    if humanoid.FloorMaterial == Enum.Material.Air then return end

    local camLook = Camera.CFrame.LookVector
    local camRight = Camera.CFrame.RightVector
    local mx, mz = 0, 0
    if UserInputService:IsKeyDown(Enum.KeyCode.W) then mx = mx + camLook.X; mz = mz + camLook.Z end
    if UserInputService:IsKeyDown(Enum.KeyCode.S) then mx = mx - camLook.X; mz = mz - camLook.Z end
    if UserInputService:IsKeyDown(Enum.KeyCode.A) then mx = mx - camRight.X; mz = mz - camRight.Z end
    if UserInputService:IsKeyDown(Enum.KeyCode.D) then mx = mx + camRight.X; mz = mz + camRight.Z end

    local currentVel = rootPart.AssemblyLinearVelocity
    local mag = math.sqrt(mx * mx + mz * mz)
    if mag > 0 then
        local targetSpeed = humanoid.WalkSpeed
        local inv = targetSpeed / mag
        rootPart.AssemblyLinearVelocity = Vector3.new(mx * inv, currentVel.Y, mz * inv)
    else
        rootPart.AssemblyLinearVelocity = Vector3.new(0, currentVel.Y, 0)
    end
end


local function updateAirStrafe()
    if not Toggles.AirStrafeEnable or not Toggles.AirStrafeEnable.Value then return end
    if Toggles.BhopEnable and Toggles.BhopEnable.Value then return end

    local character = LocalPlayer.Character
    if not character then return end
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not (rootPart and humanoid) or humanoid.Health <= 0 then return end
    if humanoid.FloorMaterial ~= Enum.Material.Air then return end

    local camLook = Camera.CFrame.LookVector
    local camRight = Camera.CFrame.RightVector
    local mx, mz = 0, 0
    if UserInputService:IsKeyDown(Enum.KeyCode.W) then mx = mx + camLook.X; mz = mz + camLook.Z end
    if UserInputService:IsKeyDown(Enum.KeyCode.S) then mx = mx - camLook.X; mz = mz - camLook.Z end
    if UserInputService:IsKeyDown(Enum.KeyCode.A) then mx = mx - camRight.X; mz = mz - camRight.Z end
    if UserInputService:IsKeyDown(Enum.KeyCode.D) then mx = mx + camRight.X; mz = mz + camRight.Z end

    local currentVel = rootPart.AssemblyLinearVelocity
    local mag = math.sqrt(mx * mx + mz * mz)
    if mag > 0 then
        local targetSpeed = humanoid.WalkSpeed
        local inv = targetSpeed / mag
        rootPart.AssemblyLinearVelocity = Vector3.new(mx * inv, currentVel.Y, mz * inv)
    else
        rootPart.AssemblyLinearVelocity = Vector3.new(0, currentVel.Y, 0)
    end
end


-- Kill All helpers
local function isKillAllKeyActive()
    local KeybindState = Options.ExploitKillAllKeybind
    if not KeybindState or type(KeybindState) ~= "table" then return false end

    local mode = KeybindState.Mode
    if mode == "Always" then
        return true
    elseif mode == "Hold" then
        local key = KeybindState.Value
        if key == 'None' then
            return false
        elseif key == 'MB1' or key == 'MB2' or key == 'MB3' then
            return key == 'MB1' and UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
                or key == 'MB2' and UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
                or key == 'MB3' and UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton3)
        else
            return UserInputService:IsKeyDown(Enum.KeyCode[key])
        end
    else -- Toggle
        return KeybindState.Toggled == true
    end
end


-- Update Kill All
local function updateKillAll()
    local autoEnabled = Toggles.ExploitKillAll and Toggles.ExploitKillAll.Value
    local keyActive = isKillAllKeyActive()

    if not autoEnabled or not keyActive then return end

    local char = LocalPlayer.Character
    if not char then return end

    local hum = char:FindFirstChild("Humanoid")
    if not hum or hum.Health <= 0 then return end

    local gun = char:FindFirstChild("Gun")
    local eqTool = char:FindFirstChild("EquippedTool")
    if not gun or not eqTool then return end

    local gunName = "AWP"
    local gunRef = gun
    local rsWeapons = getWeaponsFolder()
    local awpFolder = rsWeapons and rsWeapons:FindFirstChild("AWP")
    if awpFolder then gunRef = awpFolder end

    local camPos = Camera.CFrame.p
    local srvTime = Workspace:GetServerTimeNow()
    local burstCount = 2
    local nanBypass = true

    for _, plr in pairs(Players:GetPlayers()) do
        if plr == LocalPlayer then continue end

        local myTeam = LocalPlayer.Team
        local theirTeam = plr.Team
        if myTeam ~= nil and theirTeam ~= nil and theirTeam == myTeam then continue end

        local pChar = plr.Character
        if not pChar then continue end

        local head = pChar:FindFirstChild("Head") or pChar:FindFirstChild("HeadHB")
        local pHum = pChar:FindFirstChild("Humanoid")
        if not head or not pHum or pHum.Health <= 0 then continue end

        if not KillAllHitRemote then continue end

        for burst = 1, burstCount do
            pcall(function()
                local posArg = nanBypass and {X = 0/0, Y = 0/0, Z = 0/0} or {X = head.Position.X, Y = head.Position.Y, Z = head.Position.Z}
                KillAllHitRemote:FireServer(
                    head,
                    posArg,
                    gunName,
                    4096,
                    gunRef,
                    nil,
                    1,
                    false,
                    true,
                    camPos,
                    srvTime,
                    Vector3.new(0, 1, 0),
                    true,
                    true,
                    true,
                    true,
                    true,
                    nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil
                )
            end)
        end
    end
end


-- Update rapid fire
updateRapidFire = function()
    if not Toggles.GunModsRapidFire or not Toggles.GunModsRapidFire.Value then
        return
    end

    local FireRate, weaponName = getCurrentWeaponFireRateObject()
    if not FireRate or not weaponName then
        return
    end

    if RapidFireState.SavedFireRates[weaponName] == nil then
        RapidFireState.SavedFireRates[weaponName] = FireRate.Value
    end

    local original = RapidFireState.SavedFireRates[weaponName]
    local multiplier = 3
    if weaponName == "AWP" or weaponName == "Scout" then
        multiplier = 5
    elseif weaponName == "G3SG1" then
        multiplier = 4
    elseif weaponName == "USP" then
        multiplier = 2
    elseif weaponName == "DesertEagle" then
        multiplier = 1.8
    elseif weaponName == "AK-47" then
        multiplier = 2
    end
    local targetValue = original / multiplier
    if FireRate.Value ~= targetValue then
        FireRate.Value = targetValue
    end
end


-- Update full auto
updateFullAuto = function()
    local Weapons = getWeaponsFolder()
    if not Weapons then return end

    if Toggles.MiscFullAuto and Toggles.MiscFullAuto.Value then
        for _, weaponFolder in ipairs(Weapons:GetChildren()) do
            local AutoValue = weaponFolder:FindFirstChild("Auto")
            if AutoValue and AutoValue:IsA("BoolValue") then
                if FullAutoState.SavedAutoValues[weaponFolder.Name] == nil then
                    FullAutoState.SavedAutoValues[weaponFolder.Name] = AutoValue.Value
                end
                AutoValue.Value = true
            end
        end
    else
        for weaponName, originalValue in pairs(FullAutoState.SavedAutoValues) do
            local weaponFolder = Weapons:FindFirstChild(weaponName)
            if weaponFolder then
                local AutoValue = weaponFolder:FindFirstChild("Auto")
                if AutoValue and AutoValue:IsA("BoolValue") then
                    AutoValue.Value = originalValue
                end
            end
            FullAutoState.SavedAutoValues[weaponName] = nil
        end
    end
end


-- Config section
local ConfigSection = Tabs.Config:AddLeftGroupbox('Menu')
local function unloadValenok()
    -- Restore namecall hook
    restoreNamecallHook()
    getgenv().PSilentTargetPos = nil

    -- Cleanup Aimbot FOV lines
    for _, Line in ipairs(AimRuntime.FovLines) do
        pcall(function()
            Line:Remove()
        end)
    end
    table.clear(AimRuntime.FovLines)

    -- Reset NoScope
    applyNoScope(false)

    -- Reset NoFlash
    local blnd = LocalPlayer.PlayerGui and LocalPlayer.PlayerGui:FindFirstChild("Blnd")
    if blnd then
        blnd.Enabled = true
    end

    -- Cleanup ESP
    for Player, DrawingSet in pairs(EspRuntime.Drawings) do
        for _, Item in DrawingSet do
            if type(Item) == "userdata" and Item.Remove then
                pcall(function()
                    Item:Remove()
                end)
            end
        end
        EspRuntime.Drawings[Player] = nil
    end

    for Player, Highlight in pairs(EspRuntime.Highlights) do
        pcall(function()
            Highlight:Destroy()
        end)
        EspRuntime.Highlights[Player] = nil
    end

    for _, Connection in pairs(EspRuntime.Connections) do
        pcall(function()
            Connection:Disconnect()
        end)
    end

    -- Cleanup Grenade Prediction
    if GrenadeRuntime and GrenadeRuntime.Folder then
        pcall(function() GrenadeRuntime.Folder:Destroy() end)
    end

    -- Cleanup HitSound
    if _hitSoundObj then pcall(function() _hitSoundObj:Destroy() end) end

    -- Cleanup Hit Chams
    if HitChamsState.ChamsFolder then
        HitChamsState.ChamsFolder:Destroy()
    end
    for _, conns in pairs(HitChamsState.PlayerConns) do
        for _, conn in ipairs(conns) do
            pcall(function() conn:Disconnect() end)
        end
    end
    table.clear(HitChamsState.PlayerConns)
    table.clear(HitChamsState.ObservedPlayers)

    -- Reset Third Person
    pcall(function()
        LocalPlayer.CameraMaxZoomDistance = 0.5
        LocalPlayer.CameraMinZoomDistance = 0.5

        local character = LocalPlayer.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        if humanoid then
            humanoid.AutoRotate = true
        end
    end)

    -- Reset Triggerbot
    TriggerbotState = {
        AwaitingRelease = false,
        NextFireTime = 0,
        StopTime = 0,
        WasMoving = false,
        Holding = false,
        DelayUntil = 0,
        DelayActive = false,
    }

    -- Reset Gun Mods
    local Client = getCachedClient()
    if Client then
        if OriginalAccuracySd ~= nil then Client.accuracy_sd = OriginalAccuracySd end
    end

    restoreAllRapidFireRates()
    restoreAllFullAutoValues()

    -- Reset RCS
    local Weapons = getWeaponsFolder()
    if Weapons then
        for weaponName, original in pairs(RCSOriginalValues) do
            local weaponFolder = Weapons:FindFirstChild(weaponName)
            local spread = weaponFolder and weaponFolder:FindFirstChild("Spread")
            local recoil = spread and spread:FindFirstChild("Recoil")
            if recoil and recoil:IsA("NumberValue") then
                recoil.Value = original
            end
        end
        table.clear(RCSOriginalValues)

        for weaponName, original in pairs(SavedRecoilValues) do
            local weaponFolder = Weapons:FindFirstChild(weaponName)
            local spread = weaponFolder and weaponFolder:FindFirstChild("Spread")
            local recoil = spread and spread:FindFirstChild("Recoil")
            if recoil and recoil:IsA("NumberValue") then
                recoil.Value = original
            end
        end
        table.clear(SavedRecoilValues)

        for weaponName, original in pairs(InstaWeaponState.SavedEquipTimes) do
            local weaponFolder = Weapons:FindFirstChild(weaponName)
            local EquipTime = weaponFolder and weaponFolder:FindFirstChild("EquipTime")
            if EquipTime and EquipTime:IsA("NumberValue") then
                EquipTime.Value = original
            end
        end
        for weaponName, original in pairs(InstaWeaponState.SavedReloadTimes) do
            local weaponFolder = Weapons:FindFirstChild(weaponName)
            local ReloadTime = weaponFolder and weaponFolder:FindFirstChild("ReloadTime")
            if ReloadTime and ReloadTime:IsA("NumberValue") then
                ReloadTime.Value = original
            end
        end
    end
    table.clear(InstaWeaponState.SavedEquipTimes)
    table.clear(InstaWeaponState.SavedReloadTimes)

    Library:Unload()
end
getgenv().ValenokUnload = unloadValenok
ConfigSection:AddButton('Unload', unloadValenok)
ConfigSection:AddLabel('Menu bind'):AddKeyPicker('MenuKeybind', { Default = 'End', NoUI = true, Text = 'Menu' })

Library.ToggleKeybind = Options.MenuKeybind
Library.KeybindFrame.Visible = true


-- Drawing helpers
local DrawingFont = Drawing.Fonts.Plex

-- Triggerbot helpers
local function isTriggerEnemy(Player)
    if Player == LocalPlayer then return false end

    if Toggles.TriggerbotTeamCheck and Toggles.TriggerbotTeamCheck.Value then
        local MyTeam, TheirTeam = LocalPlayer.Team, Player.Team
        local MyTeamColor, TheirTeamColor = LocalPlayer.TeamColor, Player.TeamColor
        
        if MyTeam ~= nil and TheirTeam ~= nil and TheirTeam == MyTeam then
            return false
        end
        
        if MyTeamColor ~= nil and TheirTeamColor ~= nil and TheirTeamColor == MyTeamColor then
            return false
        end
    end

    return true
end



-- Fire single shot
local function fireSingleShot()
    local character = LocalPlayer.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if not character or not humanoid or humanoid.Health <= 0 then
        return
    end
    
    local Mouse = LocalPlayer:GetMouse()
    local mouseX = Mouse.X
    local mouseY = Mouse.Y
    
    pcall(function()
        VirtualInputManager:SendMouseButtonEvent(mouseX, mouseY, 0, true, game, 1)
        task.wait(0.1)
        VirtualInputManager:SendMouseButtonEvent(mouseX, mouseY, 0, false, game, 1)
    end)
    TriggerbotState.NextFireTime = tick() + 0.01
end


-- Update triggerbot
-- Triggerbot keybind check
local function isTriggerbotKeyActive()
    local KeybindState = Options.TriggerbotKeybind
    if not KeybindState or type(KeybindState) ~= "table" then return false end

    local mode = KeybindState.Mode
    if mode == "Always" then
        return true
    elseif mode == "Hold" then
        local key = KeybindState.Value
        if key == 'None' then
            return false
        elseif key == 'MB1' or key == 'MB2' or key == 'MB3' then
            return key == 'MB1' and UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
                or key == 'MB2' and UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
                or key == 'MB3' and UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton3)
        else
            return UserInputService:IsKeyDown(Enum.KeyCode[key])
        end
    else -- Toggle
        return KeybindState.Toggled == true
    end
end

local function updateTriggerbot()
    local Camera = getCamera()
    if not Camera then return end
    if not Toggles.TriggerbotEnable or not Toggles.TriggerbotEnable.Value then
        return
    end

    if not isTriggerbotKeyActive() then
        return
    end

    local character = LocalPlayer.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if not character or not humanoid or humanoid.Health <= 0 then
        return
    end

    local now = tick()

    if Toggles.TriggerbotOnStopOnly and Toggles.TriggerbotOnStopOnly.Value then
        local hrp = character:FindFirstChild("HumanoidRootPart")
        if hrp then
            local velocity = hrp.AssemblyLinearVelocity
            if velocity and velocity.Magnitude >= 10 then
                TriggerbotState.WasMoving = true
                TriggerbotState.StopTime = 0
                return
            else
                if TriggerbotState.StopTime == 0 then
                    TriggerbotState.StopTime = now
                    return
                elseif now - TriggerbotState.StopTime < 0.002 then
                    return
                end
            end
        end
    end

    local targetPart = nil
    local Mouse = LocalPlayer:GetMouse()
    local hitInstance = Mouse.Target

    if hitInstance and hitInstance.Parent then
        local hitChar = hitInstance:FindFirstAncestorOfClass("Model")
        if hitChar then
            local hitPlayer = Players:GetPlayerFromCharacter(hitChar)

            -- Team check
            if hitPlayer and Toggles.TriggerbotTeamCheck and Toggles.TriggerbotTeamCheck.Value then
                local MyTeam, TheirTeam = LocalPlayer.Team, hitPlayer.Team
                local MyTeamColor, TheirTeamColor = LocalPlayer.TeamColor, hitPlayer.TeamColor
                
                if (MyTeam ~= nil and TheirTeam ~= nil and TheirTeam == MyTeam) or
                   (MyTeamColor ~= nil and TheirTeamColor ~= nil and TheirTeamColor == MyTeamColor) then
                    return
                end
            end
            
            if hitPlayer and isTriggerEnemy(hitPlayer) then
                local hum = hitChar:FindFirstChildOfClass("Humanoid")
                if hum and hum.Health > 0 then
                    if isStrictRayVisible(hitInstance) then
                        targetPart = hitInstance
                    end
                end
            end
        end
    end

    if targetPart and targetPart.Parent then
        local char = targetPart:FindFirstAncestorOfClass("Model")
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if not hum or hum.Health <= 0 then
            targetPart = nil
        end
    end

    if Toggles.TriggerbotMagnet and Toggles.TriggerbotMagnet.Value then
        local magnetFov = 25
        local smooth = 5
        smooth = math.clamp(smooth, 1, 10)

        local MousePos = UserInputService:GetMouseLocation()
        local magnetTarget = nil
        local bestDistance = math.huge

        for _, Player in ipairs(Players:GetPlayers()) do
            if Player == LocalPlayer then continue end
            if not isTriggerEnemy(Player) then continue end

            local Character = Player.Character
            if not Character then continue end
            local hum = Character:FindFirstChildOfClass("Humanoid")
            if not hum or hum.Health <= 0 then continue end

            local magnetHitboxes = {"Head", "HeadHB", "HumanoidRootPart", "UpperTorso", "Torso"}
            for _, partName in ipairs(magnetHitboxes) do
                local part = Character:FindFirstChild(partName)
                if part and part:IsA("BasePart") then
                    local screenPoint = Camera:WorldToViewportPoint(part.Position)
                    if screenPoint.Z > 0 then
                        local dist = (Vector2.new(screenPoint.X, screenPoint.Y) - MousePos).Magnitude
                        if dist <= magnetFov and dist < bestDistance then
                            if isStrictRayVisible(part) then
                                bestDistance = dist
                                magnetTarget = part
                            end
                        end
                    end
                end
            end
        end

        if magnetTarget then
            local targetPosition = magnetTarget.Position
            local smoothFactor = smooth / 15
            local targetCF = CFrame.new(Camera.CFrame.Position, targetPosition)
            Camera.CFrame = Camera.CFrame:Lerp(targetCF, smoothFactor)
        end
    end

    if targetPart then
        local now2 = tick()
        if TriggerbotState.NextFireTime - now2 > 2 then
            TriggerbotState.NextFireTime = 0
        end
        local delayMs = Options.TriggerbotDelay.Value or 0
        if not TriggerbotState.DelayActive then
            TriggerbotState.DelayActive = true
            TriggerbotState.DelayUntil = now2 + (delayMs / 1000)
        end
        if now2 >= TriggerbotState.DelayUntil and now2 >= TriggerbotState.NextFireTime then
            fireSingleShot()
        end
    else
        TriggerbotState.DelayActive = false
    end
end


-- Create square
local function createSquare(Thickness, Color)
    local Square = Drawing.new("Square")
    Square.Visible = false
    Square.Filled = false
    Square.Thickness = Thickness
    Square.Transparency = 1
    Square.Color = Color
    return Square
end


-- Create text
local function createText(Size)
    local Text = Drawing.new("Text")
    Text.Visible = false
    Text.Center = true
    Text.Outline = true
    Text.Transparency = 1
    Text.Size = 13
    Text.Font = Drawing.Fonts.Plex
    return Text
end


-- Create line
local function createLine(Thickness, Color)
    local Line = Drawing.new("Line")
    Line.Visible = false
    Line.Thickness = Thickness
    Line.Transparency = 1
    Line.Color = Color
    return Line
end


-- Hide drawing set
local function hideDrawingSet(DrawingSet, ResetRect)
    if not DrawingSet then
        return
    end

    DrawingSet.Box.Visible = false
    DrawingSet.BoxOutline.Visible = false
    DrawingSet.Name.Visible = false
    DrawingSet.Weapon.Visible = false
    DrawingSet.HealthBarOutline.Visible = false
    DrawingSet.HealthBarFill.Visible = false
    DrawingSet.HealthText.Visible = false

    if ResetRect then
        DrawingSet.Rect = nil
    end
end


-- Remove drawing set
local function removeDrawingSet(Player)
    local DrawingSet = EspRuntime.Drawings[Player]
    if not DrawingSet then
        return
    end

    for _, Item in DrawingSet do
        if type(Item) == "userdata" and Item.Remove then
            pcall(function()
                Item:Remove()
            end)
        end
    end

    EspRuntime.Drawings[Player] = nil
end


-- Remove highlight
local function removeHighlight(Player)
    local Highlight = EspRuntime.Highlights[Player]
    if not Highlight then
        return
    end

    pcall(function()
        Highlight:Destroy()
    end)

    EspRuntime.Highlights[Player] = nil
end


-- Get drawing set
local function getDrawingSet(Player)
    local DrawingSet = EspRuntime.Drawings[Player]
    if DrawingSet then
        return DrawingSet
    end

    DrawingSet = {
        Box = createSquare(1.5, Color3.fromRGB(255, 255, 255)),
        BoxOutline = createSquare(1, Color3.fromRGB(0, 0, 0)),
        Name = createText(13),
        Weapon = createText(13),
        Rect = nil,
        HealthBarOutline = createSquare(2, Color3.fromRGB(0, 0, 0)),
        HealthBarFill = createSquare(1, Color3.fromRGB(0, 255, 0)),
        HealthText = createText(13),
    }

    EspRuntime.Drawings[Player] = DrawingSet
    return DrawingSet
end


-- Get option color
function getOptionColor(OptionName, Fallback)
    local Option = Options[OptionName]
    if type(Option) == "table" and Option.Value then
        return Option.Value
    end

    return Fallback
end


-- Get chams transparency
local function getChamsTransparency()
    local SliderValue = Options.ESPChamsTransparency
    if type(SliderValue) ~= "table" then
        return 0.35
    end

    return math.clamp(SliderValue.Value / 100, 0, 1)
end


-- Get character parts
local function getCharacterParts(Player)
    local Character = Player.Character
    local Humanoid = Character and Character:FindFirstChildOfClass("Humanoid")
    local RootPart = Character and Character:FindFirstChild("HumanoidRootPart")
    return Character, Humanoid, RootPart
end


-- Update player chams
local function updatePlayerChams(Player, Character)
    if Player == LocalPlayer or not Character then
        removeHighlight(Player)
        return
    end

    local ShowChams = Toggles.ESPChams and Toggles.ESPChams.Value
    if not ShowChams then
        local Highlight = EspRuntime.Highlights[Player]
        if Highlight then Highlight.Enabled = false end
        return
    end

    local Highlight = EspRuntime.Highlights[Player]
    if not Highlight then
        Highlight = Instance.new("Highlight")
        Highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        Highlight.OutlineTransparency = 1
        EspRuntime.Highlights[Player] = Highlight
    end

    Highlight.Adornee = Character
    Highlight.Parent = Character
    Highlight.FillColor = getOptionColor("ESPChamsColor", Color3.fromRGB(255, 255, 255))
    Highlight.FillTransparency = getChamsTransparency()
    if Toggles.ESPChamsOutline and Toggles.ESPChamsOutline.Value then
        Highlight.OutlineTransparency = 0
        Highlight.OutlineColor = getOptionColor("ESPChamsOutlineColor", Color3.fromRGB(255, 255, 255))
    else
        Highlight.OutlineTransparency = 1
    end
    Highlight.Enabled = true
end


-- Get character screen box
local function getCharacterScreenBox(Character, Humanoid, RootPart)
    if not RootPart then return nil end

    local HEIGHT_STUDS = 6.2
    local WIDTH_STUDS = 3.5

    local rootPos = RootPart.Position
    local screenPos, onScreen = Camera:WorldToViewportPoint(rootPos)

    if not onScreen then return nil end

    local topWorld = rootPos + Vector3.new(0, HEIGHT_STUDS / 2, 0)
    local bottomWorld = rootPos - Vector3.new(0, HEIGHT_STUDS / 2, 0)

    local topScreen = Camera:WorldToViewportPoint(topWorld)
    local bottomScreen = Camera:WorldToViewportPoint(bottomWorld)

    local height = math.abs(topScreen.Y - bottomScreen.Y)

    local width = height * (WIDTH_STUDS / HEIGHT_STUDS)

    return screenPos.X - width / 2, screenPos.Y - height / 2, width, height
end


-- Update player ESP
local function updatePlayerEsp(Player)
    if not Player or not Player.Parent then return end
    local DrawingSet = getDrawingSet(Player)

    if Player == LocalPlayer then
        hideDrawingSet(DrawingSet, true)
        return
    end

    if Toggles.ESPTeamCheck and Toggles.ESPTeamCheck.Value then
        local MyTeam, TheirTeam = LocalPlayer.Team, Player.Team
        if MyTeam ~= nil and TheirTeam ~= nil and TheirTeam == MyTeam then
            hideDrawingSet(DrawingSet, true)
            updatePlayerChams(Player, nil)
            return
        end
    end

    local Character, Humanoid, RootPart = getCharacterParts(Player)
    if not Character then
        updatePlayerChams(Player, nil)
        hideDrawingSet(DrawingSet, true)
        return
    end

    if not Toggles.ESPEnable or not Toggles.ESPEnable.Value then
        hideDrawingSet(DrawingSet, true)
        updatePlayerChams(Player, nil)
        return
    end

    local Left, Top, Width, Height = getCharacterScreenBox(Character, Humanoid, RootPart)
    if not Left then
        hideDrawingSet(DrawingSet, true)
        updatePlayerChams(Player, nil)
        return
    end

    local Rect = DrawingSet.Rect
    if not Rect then
        Rect = {}
        DrawingSet.Rect = Rect
    end
    Rect.Left = Left; Rect.Top = Top; Rect.Width = Width; Rect.Height = Height

    local Bottom = Top + Height
    local CenterX = Left + Width * 0.5

    local ShowBox = Toggles.ESPBox and Toggles.ESPBox.Value
    local ShowName = Toggles.ESPName and Toggles.ESPName.Value

    local BoxColor = getOptionColor("ESPBoxColor", Color3.fromRGB(255, 255, 255))
    local NameColor = getOptionColor("ESPNameColor", Color3.fromRGB(255, 255, 255))

    DrawingSet.BoxOutline.Position = Vector2.new(Left - 1, Top - 1)
    DrawingSet.BoxOutline.Size = Vector2.new(Width + 2, Height + 2)
    DrawingSet.BoxOutline.Visible = ShowBox

    DrawingSet.Box.Position = Vector2.new(Left, Top)
    DrawingSet.Box.Size = Vector2.new(Width, Height)
    DrawingSet.Box.Color = BoxColor
    DrawingSet.Box.Visible = ShowBox

    DrawingSet.Name.Text = Player.Name
    DrawingSet.Name.Position = Vector2.new(CenterX, Top - 15)
    DrawingSet.Name.Color = NameColor
    DrawingSet.Name.Visible = ShowName

    local ShowWeapon = Toggles.ESPWeapon and Toggles.ESPWeapon.Value
    local WeaponColor = getOptionColor("ESPWeaponColor", Color3.fromRGB(255, 255, 255))
    local WeaponName = ""
    if Character and Character:FindFirstChild("EquippedTool") then
        WeaponName = tostring(Character.EquippedTool.Value)
    end
    DrawingSet.Weapon.Text = WeaponName
    DrawingSet.Weapon.Position = Vector2.new(CenterX, Bottom + 5)
    DrawingSet.Weapon.Color = WeaponColor
    DrawingSet.Weapon.Visible = ShowWeapon and WeaponName ~= ""

    local ShowHealthBar = Toggles.ESPHealthBar and Toggles.ESPHealthBar.Value
    if ShowHealthBar and Humanoid then
        local hpPercent = math.clamp(Humanoid.Health / Humanoid.MaxHealth, 0, 1)
        local barWidth = 4
        local barHeight = Height
        local barX = Left - barWidth - 2
        local barY = Top

        DrawingSet.HealthBarOutline.Position = Vector2.new(barX, barY)
        DrawingSet.HealthBarOutline.Size = Vector2.new(barWidth, barHeight)
        DrawingSet.HealthBarOutline.Color = Color3.fromRGB(0, 0, 0)
        DrawingSet.HealthBarOutline.Visible = true

        local fillHeight = barHeight * hpPercent
        local fillY = barY + (barHeight - fillHeight)
        DrawingSet.HealthBarFill.Position = Vector2.new(barX + 1, fillY)
        DrawingSet.HealthBarFill.Size = Vector2.new(barWidth - 2, fillHeight)
        DrawingSet.HealthBarFill.Color = getOptionColor("ESPHealthBarColor", Color3.fromRGB(0, 255, 0))
        DrawingSet.HealthBarFill.Filled = true
        DrawingSet.HealthBarFill.Visible = true

        local hp = math.floor(Humanoid.Health)
        if hp < 100 then
            DrawingSet.HealthText.Text = tostring(hp)
            DrawingSet.HealthText.Position = Vector2.new(barX - 8, barY)
            DrawingSet.HealthText.Color = Color3.fromRGB(255, 255, 255)
            DrawingSet.HealthText.Visible = true
        else
            DrawingSet.HealthText.Visible = false
        end
    else
        DrawingSet.HealthBarOutline.Visible = false
        DrawingSet.HealthBarFill.Visible = false
        DrawingSet.HealthText.Visible = false
    end

    updatePlayerChams(Player, Character)
end


-- ESP player removing
EspRuntime.Connections.PlayerRemoving = Players.PlayerRemoving:Connect(function(Player)
    removeDrawingSet(Player)
    removeHighlight(Player)
    HitChamsState.ObservedPlayers[Player] = nil
    if HitChamsState.PlayerConns[Player] then
        for _, conn in ipairs(HitChamsState.PlayerConns[Player]) do
            pcall(function() conn:Disconnect() end)
        end
        HitChamsState.PlayerConns[Player] = nil
    end
end)


-- Third Person
local function updateThirdPerson()
    local ThirdPersonEnabled = Toggles.ThirdPersonEnable and Toggles.ThirdPersonEnable.Value
    local KeybindState = Options.ThirdPersonKeybind
    local IsKeyActive = false

    if KeybindState then
        local mode = KeybindState.Mode
        if mode == "Always" then
            IsKeyActive = true
        elseif mode == "Hold" then
            local key = KeybindState.Value
            if key == 'None' then
                IsKeyActive = false
            elseif key == 'MB1' or key == 'MB2' or key == 'MB3' then
                IsKeyActive = key == 'MB1' and game:GetService("UserInputService"):IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
                    or key == 'MB2' and game:GetService("UserInputService"):IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
                    or key == 'MB3' and game:GetService("UserInputService"):IsMouseButtonPressed(Enum.UserInputType.MouseButton3)
            else
                IsKeyActive = game:GetService("UserInputService"):IsKeyDown(Enum.KeyCode[key])
            end
        else -- Toggle
            IsKeyActive = KeybindState.Toggled == true
        end
    end

    local isThirdPersonActive = ThirdPersonEnabled and IsKeyActive
    local targetDist = isThirdPersonActive and (Options.ThirdPersonDistance.Value or 5) or 0.5

    pcall(function()
        LocalPlayer.CameraMaxZoomDistance = targetDist
        LocalPlayer.CameraMinZoomDistance = targetDist

        local character = LocalPlayer.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")

        if humanoid then
            if not (Toggles.AntiAimYaw and Toggles.AntiAimYaw.Value) then
                if isThirdPersonActive then
                    humanoid.AutoRotate = false
                else
                    humanoid.AutoRotate = true
                end
            end
        end
    end)
end


-- Grenade Prediction (3D Beam-based, ported from Main_script.lua)

-- Grenade runtime
local GrenadeRuntime = {
    Folder = nil,
    Attachments = {},
    Beams = {},
    Sphere = nil,
    PulseDir = 1,
    PulseVal = 1.0,
    LmbDown = false,
    RmbDown = false,
}

-- Create prediction objects
do
    local PredictionFolder = Instance.new("Folder")
    PredictionFolder.Name = "CW_GrenadePredictor"
    GrenadeRuntime.Folder = PredictionFolder
    pcall(function() PredictionFolder.Parent = workspace.Terrain end)

    for i = 1, 40 do
        local att = Instance.new("Attachment", PredictionFolder)
        GrenadeRuntime.Attachments[i] = att
        if i > 1 then
            local beam = Instance.new("Beam", PredictionFolder)
            beam.Attachment0 = GrenadeRuntime.Attachments[i-1]
            beam.Attachment1 = att
            beam.Width0 = 0.2
            beam.Width1 = 0.2
            beam.FaceCamera = true
            beam.Segments = 1
            beam.LightEmission = 1
            beam.LightInfluence = 0
            beam.Transparency = NumberSequence.new(0.2)
            beam.Enabled = false
            GrenadeRuntime.Beams[i-1] = beam
        end
    end

    local sphere = Instance.new("Part")
    sphere.Shape = Enum.PartType.Ball
    sphere.Size = Vector3.new(1.2, 1.2, 1.2)
    sphere.Material = Enum.Material.Neon
    sphere.Anchored = true
    sphere.CanCollide = false
    sphere.Parent = PredictionFolder
    sphere.CastShadow = false
    sphere.Transparency = 1
    GrenadeRuntime.Sphere = sphere
end

-- Grenade helpers
local function isHoldingNade()
    local lp = LocalPlayer
    if not lp or not lp.Character then return false end
    local gun = lp.Character:FindFirstChild("Gun")
    if gun and gun:FindFirstChild("Grenade") then return true end
    local eqVal = lp.Character:FindFirstChild("EquippedTool")
    if eqVal and type(eqVal.Value) == "string" then
        local weaponDef = getWeaponsFolder()
        if weaponDef then
            local w = weaponDef:FindFirstChild(eqVal.Value)
            if w and w:FindFirstChild("Grenade") then return true end
        end
        local n = eqVal.Value:lower()
        if n:find("flash") or n:find("hegren") or n:find("smoke") or n:find("molotov") or n:find("incen") or n:find("decoy") or n:find("grenade") or n:find("nade") then
            return true
        end
    end
    return false
end

local function getNadePosition()
    return (Camera.CFrame * CFrame.new(0.1, -0.4, -2.5)).Position
end

local function getNadeType()
    local lp = LocalPlayer
    if not lp or not lp.Character then return "default" end
    local eqVal = lp.Character:FindFirstChild("EquippedTool")
    if not eqVal or type(eqVal.Value) ~= "string" then return "default" end
    local v = eqVal.Value
    if v == "Molotov" or v == "Incendiary Grenade" then return "molotov" end
    if v == "HE Grenade" then return "he" end
    if v == "Smoke Grenade" then return "smoke" end
    if v == "Flashbang" then return "flash" end
    if v == "Decoy Grenade" then return "decoy" end
    local lv = v:lower()
    if lv:find("molotov") or lv:find("incen") then return "molotov" end
    if lv:find("hegren") or lv == "he grenade" then return "he" end
    if lv:find("smoke") then return "smoke" end
    if lv:find("flash") then return "flash" end
    if lv:find("decoy") then return "decoy" end
    return "default"
end

-- Input tracking for grenade prediction
EspRuntime.Connections.GrenadeInputBegan = UserInputService.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then GrenadeRuntime.LmbDown = true end
    if input.UserInputType == Enum.UserInputType.MouseButton2 then GrenadeRuntime.RmbDown = true end
end)
EspRuntime.Connections.GrenadeInputEnded = UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then GrenadeRuntime.LmbDown = false end
    if input.UserInputType == Enum.UserInputType.MouseButton2 then GrenadeRuntime.RmbDown = false end
end)

local function updateGrenadePrediction(dt)
    local Camera = getCamera()
    if not Camera then return end
    if not Toggles.GrenadesPrediction or not Toggles.GrenadesPrediction.Value then
        for _, b in pairs(GrenadeRuntime.Beams) do b.Enabled = false end
        GrenadeRuntime.Sphere.Transparency = 1
        return
    end

    if not isHoldingNade() or not (GrenadeRuntime.LmbDown or GrenadeRuntime.RmbDown) then
        for _, b in pairs(GrenadeRuntime.Beams) do b.Enabled = false end
        GrenadeRuntime.Sphere.Transparency = 1
        return
    end

    local rgb = Options.GrenadesPredictionColor and Options.GrenadesPredictionColor.Value or Color3.fromRGB(255, 50, 50)
    local c3 = typeof(rgb) == "Color3" and rgb or Color3.new(1, 0.2, 0.2)

    for _, b in pairs(GrenadeRuntime.Beams) do
        b.Color = ColorSequence.new(c3)
        b.Enabled = true
    end
    GrenadeRuntime.Sphere.Color = c3

    GrenadeRuntime.PulseVal = GrenadeRuntime.PulseVal + (GrenadeRuntime.PulseDir * (dt or 0.016) * 2.5)
    if GrenadeRuntime.PulseVal >= 1.6 then GrenadeRuntime.PulseDir = -1 end
    if GrenadeRuntime.PulseVal <= 0.7 then GrenadeRuntime.PulseDir = 1 end
    GrenadeRuntime.Sphere.Size = Vector3.new(GrenadeRuntime.PulseVal, GrenadeRuntime.PulseVal, GrenadeRuntime.PulseVal)

    local lp = LocalPlayer
    local hrp = lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
    local plrVel = hrp and hrp.AssemblyLinearVelocity or Vector3.new()
    local nadeType = getNadeType()
    local LOOK_SPEED = 100
    local PLR_FACTOR = 1.0
    local UP_BIAS = 12
    local maxBounces, bounceDamping = 3, 0.42
    if nadeType == "molotov" then
        maxBounces, bounceDamping = 5, 0.4
    elseif nadeType == "he" then
        maxBounces, bounceDamping = 4, 0.55
    elseif nadeType == "smoke" then
        maxBounces, bounceDamping = 3, 0.38
    elseif nadeType == "flash" then
        maxBounces, bounceDamping = 4, 0.55
    elseif nadeType == "decoy" then
        maxBounces, bounceDamping = 3, 0.42
    end
    local velocity = Camera.CFrame.LookVector * LOOK_SPEED + plrVel * PLR_FACTOR + Vector3.new(0, UP_BIAS, 0)
    local startPos = getNadePosition()
    local grav = Vector3.new(0, -workspace.Gravity, 0)

    local tStep = 1/60
    local maxSteps = 240
    local currentPos = startPos
    if not GrenadeRuntime.RP then
        local rp = RaycastParams.new()
        rp.FilterType = Enum.RaycastFilterType.Exclude
        GrenadeRuntime.RP = rp
        GrenadeRuntime.FilterList = {lp.Character, workspace:FindFirstChild("Ray_Ignore"), GrenadeRuntime.Folder}
        local mapObj = workspace:FindFirstChild("Map")
        if mapObj then
            local clips = mapObj:FindFirstChild("Clips")
            if clips then table.insert(GrenadeRuntime.FilterList, clips) end
        end
    end
    GrenadeRuntime.FilterList[1] = lp.Character
    GrenadeRuntime.RP.FilterDescendantsInstances = GrenadeRuntime.FilterList
    local rp = GrenadeRuntime.RP

    local bounces = 0
    local pointCount = 1
    GrenadeRuntime.Attachments[1].WorldPosition = startPos

    local samplePeriod = 3
    local stepIdx = 0
    for s = 1, maxSteps do
        local nextVel = velocity + (grav * tStep)
        local moveDelta = (velocity + nextVel) * 0.5 * tStep
        local nextPos = currentPos + moveDelta

        local ray = workspace:Raycast(currentPos, nextPos - currentPos, rp)
        if ray then
            bounces = bounces + 1
            nextPos = ray.Position + ray.Normal * 0.05
            local normal = ray.Normal
            local reflected = nextVel - (2 * nextVel:Dot(normal) * normal)
            velocity = reflected * bounceDamping
            local isFloor = normal.Y > 0.6
            if (nadeType == "molotov" and isFloor) or bounces >= maxBounces or velocity.Magnitude < 5 then
                pointCount = pointCount + 1
                if pointCount <= 40 then
                    GrenadeRuntime.Attachments[pointCount].WorldPosition = nextPos
                    GrenadeRuntime.Beams[pointCount-1].Transparency = NumberSequence.new(0.15 + (pointCount/40)*0.85)
                end
                currentPos = nextPos
                break
            end
        else
            velocity = nextVel
        end

        currentPos = nextPos
        stepIdx = stepIdx + 1
        if stepIdx % samplePeriod == 0 or ray then
            pointCount = pointCount + 1
            if pointCount > 40 then break end
            GrenadeRuntime.Attachments[pointCount].WorldPosition = nextPos
            GrenadeRuntime.Beams[pointCount-1].Transparency = NumberSequence.new(0.15 + (pointCount/40)*0.85)
        end
    end

    for j = pointCount, 39 do
        if GrenadeRuntime.Beams[j] then GrenadeRuntime.Beams[j].Enabled = false end
    end

    GrenadeRuntime.Sphere.CFrame = CFrame.new(currentPos)
    GrenadeRuntime.Sphere.Transparency = 0.3
end


-- Weapon change listener for RapidFire
local function setupWeaponChangeListener(character)
    if not character then return end
    local eqTool = character:WaitForChild("EquippedTool", 5)
    if not eqTool then return end
    if EspRuntime.Connections.EquippedToolChanged then
        pcall(function() EspRuntime.Connections.EquippedToolChanged:Disconnect() end)
    end
    EspRuntime.Connections.EquippedToolChanged = eqTool.Changed:Connect(function()
        if Toggles.GunModsRapidFire and Toggles.GunModsRapidFire.Value then
            updateRapidFire()
        end
    end)
    if Toggles.GunModsRapidFire and Toggles.GunModsRapidFire.Value then
        updateRapidFire()
    end
end

if LocalPlayer.Character then
    task.spawn(setupWeaponChangeListener, LocalPlayer.Character)
end
EspRuntime.Connections.WeaponCharAdded = LocalPlayer.CharacterAdded:Connect(setupWeaponChangeListener)


-- Main loop
local lastEspUpdate = 0
local watermarkFps = 0
local watermarkFrames = 0
local watermarkLastUpdate = 0
local lastRemovalsCheck = 0

EspRuntime.Connections.RenderStepped = RunService.RenderStepped:Connect(function(dt)
    local now = tick()
    watermarkFrames = watermarkFrames + 1

    if now - lastEspUpdate >= (1 / 180) then
        lastEspUpdate = now
        local plist = Players:GetPlayers()
        for i = 1, #plist do
            updatePlayerEsp(plist[i])
        end
    end

    -- Update watermark every 0.5s
    if Toggles.MenuWatermark and Toggles.MenuWatermark.Value then
        if now - watermarkLastUpdate >= 0.3 then
            watermarkFps = math.floor(watermarkFrames / (now - watermarkLastUpdate))
            watermarkFrames = 0
            watermarkLastUpdate = now

            local ping = math.floor(LocalPlayer:GetNetworkPing() * 1000)

            local timeStr = os.date("%H:%M:%S")
            Library:SetWatermark(string.format("Valenok  |  %d fps  |  %d ms  |  %s", watermarkFps, ping, timeStr))
        end
    end

    if now - lastRemovalsCheck >= 2 then
        lastRemovalsCheck = now
        if Toggles.RemovalsNoScope and Toggles.RemovalsNoScope.Value then updateNoScope() end
        if Toggles.RemovalsNoFlash and Toggles.RemovalsNoFlash.Value then updateNoFlash() end
    end

    updateFovCircle()
    updateAimBot()
    updateRagebot()
    updateThirdPerson()
    updateTriggerbot()
    updateAntiAim()
    updateStrafe()
    updateAirStrafe()
    updateGrenadePrediction(dt)
    updateHitChams()
    updateFOV()
end)


-- Kill All heartbeat
EspRuntime.Connections.KillAllHeartbeat = RunService.Heartbeat:Connect(function()
    for i = 1, 3 do
        updateKillAll()
    end
end)
print("Valenok")
print("version: recode")
print("open/close menu end")
-- Build coАnfig
SaveManager:BuildConfigSection(Tabs.Config)
ThemeManager:ApplyToTab(Tabs.Config)


