local Library = loadstring(httpget("https://raw.githubusercontent.com/sixodicor-byte/1337/refs/heads/main/GameSexV2.lua?v=" .. tostring(os.time())))()




do
    local originalRound = Library.Round
    if type(originalRound) == "function" then
        function Library:Round(num, float)
            if type(num) == "string" then
                num = tonumber(num:match("%-?%d+%.?%d*")) or 0
            end
            return originalRound(self, num, float)
        end
    end
end

local Window = Library:Window({ Name = "RaySense" })

local Tabs = {
    Rage = Window:Tab({ Icon = "rbxassetid://8547236654" }),
    Aiming = Window:Tab({ Icon = "rbxassetid://8547249956" }),
    Visuals = Window:Tab({ Icon = "rbxassetid://8547254518" }),
    Settings = Window:Tab({ Icon = "rbxassetid://8547256547" }),
    Skins = Window:Tab({ Icon = "rbxassetid://8547258459" }),
    Configs = Window:Tab({ Icon = "rbxassetid://107672994153530" }),
}

local function noop(...) end

local function setRowVisible(element, visible)
    local items = element and element.Items
    if not items then return end
    local row = items.Toggle or items.Dropdown or items.Slider or items.List or items.Button or items.Label or items.ColorpickerObject
    if row then
        row.Visible = visible
    end
end

local function fixSliderRow(slider, pickers, afterTitle)
    slider.Items.Slider.Size = UDim2.new(1, 0, 0, 22)
    if not pickers then
        return
    end

    if afterTitle then
        local title = slider.Items.Title
        local width = 40
        pcall(function()
            local size = game:GetService("TextService"):GetTextSize(title.Text, 13, Enum.Font.SourceSans, Vector2.new(10000, 10000))
            width = size.X
        end)
        for _, picker in ipairs(pickers) do
            local obj = picker.Items.ColorpickerObject
            obj.Parent = slider.Items.Slider
            obj.AnchorPoint = Vector2.new(0, 0)
            obj.Position = UDim2.new(0, 21 + width + 6, 0, 0)
        end
        return
    end

    local components = Instance.new("Frame")
    components.Name = "\0"
    components.Position = UDim2.new(1, 0, 0, 0)
    components.Size = UDim2.new(0, 0, 1, 0)
    components.BorderSizePixel = 0
    components.BackgroundTransparency = 1
    components.Parent = slider.Items.Slider
    local layout = Instance.new("UIListLayout")
    layout.FillDirection = Enum.FillDirection.Horizontal
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Right
    layout.Padding = UDim.new(0, 3)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = components
    for _, picker in ipairs(pickers) do
        picker.Items.ColorpickerObject.Parent = components
    end
end

Tabs.Rage:Section({ Name = "Ragebot", Side = "Left", Size = 1 })
Tabs.Rage:Section({ Name = "Misc", Side = "Right", Size = 0.5 })
Tabs.Rage:Section({ Name = "Anti aim", Side = "Right", Size = 0.5 })

local Legitbot = Tabs.Aiming:Section({ Name = "Legitbot", Side = "Left", Size = 1 })
local Triggerbot = Tabs.Aiming:Section({ Name = "Triggerbot", Side = "Right", Size = 1 })

local Player = Tabs.Visuals:Section({ Name = "Player", Side = "Left", Size = 1 })
Tabs.Visuals:Section({ Name = "World", Side = "Right", Size = 1 })

local SettingsMisc = Tabs.Settings:Section({ Name = "Misc", Side = "Left", Size = 0.5 })
Tabs.Settings:Section({ Name = "Movement", Side = "Left", Size = 0.5 })
local SettingsInterface = Tabs.Settings:Section({ Name = "Interface", Side = "Right", Size = 1 })

Tabs.Skins:Section({ Name = "Skins", Side = "Left", Size = 1 })
Tabs.Skins:Section({ Name = "Knife", Side = "Right", Size = 1 })

local HitboxOptions = { "Head", "Body", "Arms", "Legs" }

local LegitEnable
local legitRows = {}

local function refreshLegit()
    for _, element in ipairs(legitRows) do
        setRowVisible(element, LegitEnable and LegitEnable.Enabled)
    end
end

LegitEnable = Legitbot:Toggle({ Name = "Enable", Flag = "Legit_Enable", Default = false, Callback = refreshLegit })
LegitEnable:Keybind({ Name = "Aim key", Flag = "Legit_Key", Mode = "Hold" })
local LegitHitbox = Legitbot:Dropdown({ Name = "Hitbox", Flag = "Legit_Hitbox", Multi = true, Options = HitboxOptions, Default = {}, Callback = noop })
local LegitChecks = Legitbot:Dropdown({ Name = "Checks", Flag = "Legit_Checks", Multi = true, Options = { "team", "visible", "smoke", "flash" }, Default = {}, Callback = noop })
local LegitFov = Legitbot:Slider({ Name = "FOV", Flag = "Legit_Fov", Min = 1, Max = 180, Default = 90, Suffix = "°", Callback = noop })
local LegitFovColor = Legitbot:Colorpicker({ Name = "FOV color", Flag = "Legit_FovColor", Color = Color3.fromRGB(255, 255, 255), Callback = noop })
local LegitSmooth = Legitbot:Slider({ Name = "Smooth", Flag = "Legit_Smooth", Min = 1, Max = 10, Default = 5, Callback = noop })
local LegitAutoWall = Legitbot:Toggle({ Name = "Auto wall", Flag = "Legit_AutoWall", Default = false, Callback = noop })
legitRows = { LegitHitbox, LegitChecks, LegitFov, LegitFovColor, LegitSmooth, LegitAutoWall }
fixSliderRow(LegitFov, { LegitFovColor }, true)
fixSliderRow(LegitSmooth)

local TriggerEnable
local trigRows = {}

local function refreshTrig()
    for _, element in ipairs(trigRows) do
        setRowVisible(element, TriggerEnable and TriggerEnable.Enabled)
    end
end

TriggerEnable = Triggerbot:Toggle({ Name = "Enable", Flag = "Trig_Enable", Default = false, Callback = refreshTrig })
TriggerEnable:Keybind({ Name = "Trigger key", Flag = "Trig_Key", Mode = "Hold" })
local TrigHitbox = Triggerbot:Dropdown({ Name = "Hitbox", Flag = "Trig_Hitbox", Multi = true, Options = HitboxOptions, Default = {}, Callback = noop })
local TrigChecks = Triggerbot:Dropdown({ Name = "Checks", Flag = "Trig_Checks", Multi = true, Options = { "team", "visible", "smoke", "flash" }, Default = {}, Callback = noop })
local TrigAutoWall = Triggerbot:Toggle({ Name = "Auto wall", Flag = "Trig_AutoWall", Default = false, Callback = noop })
trigRows = { TrigHitbox, TrigChecks, TrigAutoWall }

refreshLegit()
refreshTrig()

local menuScale = Instance.new("UIScale")
menuScale.Parent = Window.Items.Window
local menuScaleSlider = SettingsMisc:Slider({ Name = "Menu scale", Flag = "Cfg_MenuScale", Min = 50, Max = 300, Default = 100, Suffix = "%", Callback = function(v)
    menuScale.Scale = v / 100
end })
fixSliderRow(menuScaleSlider)

local MenuScalePresets = {
    ["Small"] = 75,
    ["Normal"] = 100,
    ["Big"] = 115,
    ["Very Big"] = 150,
    ["Ultra"] = 200,
}

SettingsMisc:Dropdown({
    Name = "Menu scale preset",
    Flag = "Cfg_MenuScale_Preset",
    Options = { "Small", "Normal", "Big", "Very Big", "Ultra" },
    Default = "Normal",
    Callback = function(selected)
        local value = MenuScalePresets[selected]
        if value then
            menuScale.Scale = value / 100
            menuScaleSlider.Set(value)
        end
    end
})

local mainRows = {}
local chamsRows = {}
local boxRows = {}
local Enable
local Chams
local Box

local function refreshVisuals()
    local on = Enable and Enable.Enabled
    for _, element in ipairs(mainRows) do
        setRowVisible(element, on)
    end
    for _, element in ipairs(chamsRows) do
        setRowVisible(element, on and Chams and Chams.Enabled)
    end
    for _, element in ipairs(boxRows) do
        setRowVisible(element, on and Box and Box.Enabled)
    end
end

Enable = Player:Toggle({ Name = "Enable", Flag = "Vis_Enable", Default = false, Callback = refreshVisuals })

local TeamCheck = Player:Toggle({ Name = "Team check", Flag = "Vis_TeamCheck", Callback = noop })

Box = Player:Toggle({ Name = "Box", Flag = "Vis_Box", Callback = refreshVisuals })
Box:Colorpicker({ Name = "Box", Flag = "Vis_BoxColor", Color = Color3.fromRGB(255, 255, 255), Callback = noop })
local BoxMode = Player:Dropdown({ Name = "Box style", Flag = "Vis_BoxMode", Options = { "Normal", "Corner" }, Default = "Normal", Callback = noop })

local Name = Player:Toggle({ Name = "Name", Flag = "Vis_Name", Callback = noop })
Name:Colorpicker({ Name = "Name", Flag = "Vis_NameColor", Color = Color3.fromRGB(255, 255, 255), Callback = noop })

local Distance = Player:Toggle({ Name = "Distance", Flag = "Vis_Distance", Callback = noop })
Distance:Colorpicker({ Name = "Distance", Flag = "Vis_DistanceColor", Color = Color3.fromRGB(255, 255, 255), Callback = noop })

local HealthBar = Player:Toggle({ Name = "Health bar", Flag = "Vis_HealthBar", Callback = noop })
HealthBar:Colorpicker({ Name = "Health high", Flag = "Vis_HealthHigh", Color = Color3.fromRGB(0, 255, 0), Callback = noop })
HealthBar:Colorpicker({ Name = "Health low", Flag = "Vis_HealthLow", Color = Color3.fromRGB(255, 0, 0), Callback = noop })

Chams = Player:Toggle({ Name = "Chams", Flag = "Vis_Chams", Callback = refreshVisuals })
Chams:Colorpicker({ Name = "Chams visible", Flag = "Vis_ChamsVisible", Color = Color3.fromRGB(0, 255, 120), Callback = noop })
Chams:Colorpicker({ Name = "Chams wall", Flag = "Vis_ChamsWall", Color = Color3.fromRGB(255, 60, 60), Callback = noop })

local ChamsMode = Player:Dropdown({ Name = "Chams mode", Flag = "Vis_ChamsMode", Options = { "Highlight", "Part" }, Default = "Highlight", Callback = noop })

local HeldWeapon = Player:Toggle({ Name = "Held Weapon", Flag = "Vis_HeldWeapon", Callback = noop })
HeldWeapon:Colorpicker({ Name = "Held Weapon", Flag = "Vis_HeldWeaponColor", Color = Color3.fromRGB(255, 255, 255), Callback = noop })

local DroppedWeapon = Player:Toggle({ Name = "Dropped Weapon", Flag = "Vis_DroppedWeapon", Callback = noop })
DroppedWeapon:Colorpicker({ Name = "Dropped Weapon", Flag = "Vis_DroppedWeaponColor", Color = Color3.fromRGB(255, 255, 255), Callback = noop })

mainRows = { TeamCheck, Box, Name, Distance, HealthBar, Chams, HeldWeapon, DroppedWeapon }
chamsRows = { ChamsMode }
boxRows = { BoxMode }

refreshVisuals()

local watermarkRows = {}
local Watermark

local function refreshSettings()
    for _, element in ipairs(watermarkRows) do
        setRowVisible(element, Watermark and Watermark.Enabled)
    end
end

Watermark = SettingsInterface:Toggle({ Name = "Watermark", Flag = "Cfg_Watermark", Default = false, Callback = function(v)
    Library:ToggleWatermark(v)
    refreshSettings()
end })

local WatermarkElements = SettingsInterface:Dropdown({
    Name = "Watermark elements",
    Flag = "Cfg_Watermark_Elements",
    Options = { "gamesense", "fps", "ping", "time", "config name" },
    Multi = true,
    Default = {},
    Callback = function(selected)
        local opts = Library.WatermarkOptions
        opts.gamesense = table.find(selected, "gamesense") ~= nil
        opts.fps = table.find(selected, "fps") ~= nil
        opts.ping = table.find(selected, "ping") ~= nil
        opts.time = table.find(selected, "time") ~= nil
        opts.config = table.find(selected, "config name") ~= nil
    end
})

SettingsInterface:Toggle({ Name = "Bind list", Flag = "Cfg_BindList", Default = false, Callback = function(v)
    Library:ToggleKeybindList(v)
end })

watermarkRows = { WatermarkElements }
refreshSettings()

local ConfigsLeft = Tabs.Configs:Section({ Name = "Config", Side = "Left", Size = 1 })
local ConfigsRight = Tabs.Configs:Section({ Name = "Info", Side = "Right", Size = 1 })

ConfigsRight:Button({ Name = "Unload", Callback = function()
    Library:Unload()
end })

local CFG_DIR = "gamesense/configs"

local function cfgPath(name)
    return CFG_DIR .. "/" .. tostring(name) .. ".json"
end

local function listConfigs()
    local names = {}
    local ok, files = pcall(listfiles, CFG_DIR)
    if ok and type(files) == "table" then
        for _, path in ipairs(files) do
            local name = tostring(path):match("([^/\\]+)%.json$")
            if name then
                table.insert(names, name)
            end
        end
        table.sort(names)
    end
    return names
end

local function textboxName()
    local name = Library.Flags["Cfg_Name"]
    return type(name) == "string" and name or ""
end

local function selectedName()
    local name = Library.Flags["Cfg_List"]
    return type(name) == "string" and name or ""
end

local function copyToClipboard(text)
    local fn = setclipboard or toclipboard or writeclipboard
    if fn then
        pcall(fn, text)
    end
end

local function readClipboard()
    if not getclipboard then
        return nil
    end
    local ok, text = pcall(getclipboard)
    return ok and text or nil
end

local ConfigList

local function refreshConfigList(select)
    local names = listConfigs()
    ConfigList.RefreshOptions(names)
    if select then
        ConfigList.Set(select)
    end
end

ConfigsLeft:Textbox({ Name = "Config name", Flag = "Cfg_Name", PlaceHolder = "default", Callback = noop })

ConfigList = ConfigsLeft:Dropdown({
    Name = "Config list",
    Flag = "Cfg_List",
    Options = listConfigs(),
    Callback = function(selected)
        local name = tostring(selected)
        if isfile(cfgPath(name)) then
            Library:LoadConfig(readfile(cfgPath(name)))
            Library.ConfigName = name
        end
    end,
})

Library.ConfigFlags["Cfg_List"] = nil

ConfigsLeft:Button({ Name = "Create", Callback = function()
    local name = textboxName()
    if name == "" then return end
    writefile(cfgPath(name), Library:GetConfig())
    Library.ConfigName = name
    refreshConfigList(name)
end })

ConfigsLeft:Button({ Name = "Update", Callback = function()
    local name = selectedName()
    if name == "" then name = textboxName() end
    if name == "" then return end
    writefile(cfgPath(name), Library:GetConfig())
    Library.ConfigName = name
    refreshConfigList(name)
end })

ConfigsLeft:Button({ Name = "Delete", Callback = function()
    local name = selectedName()
    if name == "" then name = textboxName() end
    if name == "" then return end
    if isfile(cfgPath(name)) then
        delfile(cfgPath(name))
    end
    refreshConfigList()
end })

ConfigsLeft:Button({ Name = "Import", Callback = function()
    local data = readClipboard()
    if not data then return end
    local ok = pcall(Library.LoadConfig, Library, data)
    if ok then
        local name = textboxName()
        if name ~= "" then
            writefile(cfgPath(name), data)
            Library.ConfigName = name
            refreshConfigList(name)
        end
    end
end })

ConfigsLeft:Button({ Name = "Export", Callback = function()
    copyToClipboard(Library:GetConfig())
end })

return Library
