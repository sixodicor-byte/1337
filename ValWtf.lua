-- services

setfpscap(300)

if getgenv().ValenokUnload then pcall(getgenv().ValenokUnload) end

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Camera = game:GetService("Workspace").CurrentCamera
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")
local VirtualInputManager = game:GetService("VirtualInputManager")


-- constants

local CONSTANTS = {
    DEFAULT_WALK_SPEED = 16,
    SC_MODELS_ASSET_ID = "rbxassetid://7285197035",
    SKIN_FILE = "Valenok/skins.json",
    GITHUB_LIB_URL = "https://raw.githubusercontent.com/bdimka251212-del/NewLib/refs/heads/main/NewLib.lua",
    GITHUB_THEME_URL = "https://raw.githubusercontent.com/bdimka251212-del/NewLib/refs/heads/main/addons/ThemeManager.lua",
    GITHUB_SAVE_URL = "https://raw.githubusercontent.com/bdimka251212-del/NewLib/refs/heads/main/addons/SaveManager.lua",
    FOV_LINE_COUNT = 164,
    MAX_HIT_CHAMS_CLONES = 20,
    ESP_HEIGHT_STUDS = 6.2,
    ESP_WIDTH_STUDS = 3.5,
    TracerTextureMap = {
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
    },
    HitSounds = {
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
        },
    },
    AimHitboxFallbacks = {
        Head = { "HeadHB", "Head", "FakeHead" },
        Body = { "UpperTorso", "LowerTorso", "Torso", "HumanoidRootPart" },
    },
    RealHitboxNames = {
        "Head", "HeadHB", "FakeHead",
        "UpperTorso", "LowerTorso", "HumanoidRootPart",
        "LeftUpperArm", "LeftLowerArm", "LeftHand",
        "RightUpperArm", "RightLowerArm", "RightHand",
        "LeftUpperLeg", "LeftLowerLeg", "LeftFoot",
        "RightUpperLeg", "RightLowerLeg", "RightFoot",
    },
    RealHitboxLookup = {},
    RAPID_FIRE_MULTIPLIERS = {
        AWP = 5, Scout = 5, G3SG1 = 4, USP = 2, DesertEagle = 1.8, ["AK-47"] = 2,
    },
    GRENADE_PARAMS = {
        LOOK_SPEED = 100,
        PLR_FACTOR = 1.0,
        UP_BIAS = 12,
        default = { maxBounces = 3, bounceDamping = 0.42 },
        molotov = { maxBounces = 5, bounceDamping = 0.4 },
        he = { maxBounces = 4, bounceDamping = 0.55 },
        smoke = { maxBounces = 3, bounceDamping = 0.38 },
        flash = { maxBounces = 4, bounceDamping = 0.55 },
        decoy = { maxBounces = 3, bounceDamping = 0.42 },
    },
}

for _, name in ipairs(CONSTANTS.RealHitboxNames) do
    CONSTANTS.RealHitboxLookup[name] = true
end

local Library, ThemeManager, SaveManager
pcall(function()
    Library = loadstring(game:HttpGet(CONSTANTS.GITHUB_LIB_URL))()
end)
pcall(function()
    ThemeManager = loadstring(game:HttpGet(CONSTANTS.GITHUB_THEME_URL))()
end)
pcall(function()
    SaveManager = loadstring(game:HttpGet(CONSTANTS.GITHUB_SAVE_URL))()
end)




-- helpers

local Cache = {}
local CacheData = {}
local CacheExpiry = {}

function Cache:get(key)
    local expiry = CacheExpiry[key]
    if expiry == nil then return nil end
    if expiry ~= 0 and tick() > expiry then
        CacheData[key] = nil
        CacheExpiry[key] = nil
        return nil
    end
    return CacheData[key]
end

function Cache:set(key, value, ttl)
    CacheData[key] = value
    CacheExpiry[key] = (ttl and ttl > 0) and (tick() + ttl) or 0
end

function Cache:invalidate(key)
    CacheData[key] = nil
    CacheExpiry[key] = nil
end

function Cache:clear()
    table.clear(CacheData)
    table.clear(CacheExpiry)
end

function Cache:getOrSet(key, ttl, factoryFn)
    local value = Cache:get(key)
    if value ~= nil then return value end
    value = factoryFn()
    if value ~= nil then
        Cache:set(key, value, ttl)
    end
    return value
end


local EspRuntime = {
    Drawings = {},
    ItemDrawings = {},
    Highlights = {},
    Connections = {},
}

local VisibilityParams = RaycastParams.new()
VisibilityParams.FilterType = Enum.RaycastFilterType.Exclude
VisibilityParams.IgnoreWater = true

local RayIgnoreList = {Camera, nil, nil}


local function getCamera()
    Camera = Workspace.CurrentCamera
    return Camera
end

local function getWeaponsFolder()
    return ReplicatedStorage:FindFirstChild("Weapons")
end


local function getCachedClient()
    return Cache:getOrSet("Client", 5, function()
        local pg = LocalPlayer:FindFirstChild("PlayerGui")
        local cg = pg and pg:FindFirstChild("Client")
        if not cg then return nil end
        local success, client = pcall(getsenv, cg)
        if success then return client end
        return nil
    end)
end

local function getCachedRayIgnore()
    return Cache:getOrSet("RayIgnore", 1.5, function()
        return Workspace:FindFirstChild("Ray_Ignore")
    end)
end


local _controlTurnRemote = nil
local function getControlTurnRemote()
    if _controlTurnRemote and _controlTurnRemote.Parent then return _controlTurnRemote end
    _controlTurnRemote = ReplicatedStorage:FindFirstChild("ControlTurn")
        or (ReplicatedStorage:FindFirstChild("Remotes") and ReplicatedStorage.Remotes:FindFirstChild("ControlTurn"))
        or Workspace:FindFirstChild("ControlTurn")
    return _controlTurnRemote
end


local function isKeybindActive(keybindState)
    if not keybindState or type(keybindState) ~= "table" then return false end

    local mode = keybindState.Mode

    if mode == "Always" then return true end
    if mode == "Toggle" then return keybindState.Toggled == true end

    -- Hold
    local key = keybindState.Value
    if key == "None" then return false end

    if key == "MB1" or key == "MB2" or key == "MB3" then
        return (key == "MB1" and UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1))
            or (key == "MB2" and UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2))
            or (key == "MB3" and UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton3))
    end

    return UserInputService:IsKeyDown(Enum.KeyCode[key])
end


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

local function isEnemy(player)
    if player == LocalPlayer then return false end

    if Toggles.AimbotTeamCheck and Toggles.AimbotTeamCheck.Value then
        local myTeam, theirTeam = LocalPlayer.Team, player.Team
        local myTeamColor, theirTeamColor = LocalPlayer.TeamColor, player.TeamColor

        if myTeam ~= nil and theirTeam ~= nil and theirTeam == myTeam then
            return false
        end

        if myTeamColor ~= nil and theirTeamColor ~= nil and theirTeamColor == myTeamColor then
            return false
        end
    end

    return true
end

local function isTriggerEnemy(player)
    if player == LocalPlayer then return false end

    if Toggles.TriggerbotTeamCheck and Toggles.TriggerbotTeamCheck.Value then
        local myTeam, theirTeam = LocalPlayer.Team, player.Team
        local myTeamColor, theirTeamColor = LocalPlayer.TeamColor, player.TeamColor

        if myTeam ~= nil and theirTeam ~= nil and theirTeam == myTeam then
            return false
        end

        if myTeamColor ~= nil and theirTeamColor ~= nil and theirTeamColor == myTeamColor then
            return false
        end
    end

    return true
end


local function hasShield(character)
    if not character then return false end
    local shield = character:FindFirstChild("Shield") or character:FindFirstChild("ForceField")
    return shield ~= nil
end

local function findCharacterPart(character, partName)
    local part = character:FindFirstChild(partName)
    if part and part:IsA("BasePart") then
        return part
    end
end


local function getOptionColor(optionName, fallback)
    local option = Options[optionName]
    if type(option) == "table" and option.Value then
        return option.Value
    end
    return fallback
end

local function getChamsTransparency()
    local sliderValue = Options.ESPChamsTransparency
    if type(sliderValue) ~= "table" then
        return 0.35
    end
    return math.clamp(sliderValue.Value / 100, 0, 1)
end


local function createSquare(thickness, color)
    local square = Drawing.new("Square")
    square.Visible = false
    square.Filled = false
    square.Thickness = thickness
    square.Transparency = 1
    square.Color = color
    return square
end

local function createText(size)
    local text = Drawing.new("Text")
    text.Visible = false
    text.Center = true
    text.Outline = true
    text.Transparency = 1
    text.Size = 13
    text.Font = Drawing.Fonts.Plex
    return text
end

local function createLine(thickness, color)
    local line = Drawing.new("Line")
    line.Visible = false
    line.Thickness = thickness
    line.Transparency = 1
    line.Color = color
    return line
end


local function getCharacterParts(player)
    local character = player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local rootPart = character and character:FindFirstChild("HumanoidRootPart")
    return character, humanoid, rootPart
end


local function getCharacterScreenBox(character, humanoid, rootPart)
    if not rootPart then return nil end

    local rootPos = rootPart.Position
    local screenPos, onScreen = Camera:WorldToViewportPoint(rootPos)

    if not onScreen then return nil end

    local topWorld = rootPos + Vector3.new(0, CONSTANTS.ESP_HEIGHT_STUDS / 2, 0)
    local bottomWorld = rootPos - Vector3.new(0, CONSTANTS.ESP_HEIGHT_STUDS / 2, 0)

    local topScreen = Camera:WorldToViewportPoint(topWorld)
    local bottomScreen = Camera:WorldToViewportPoint(bottomWorld)

    local height = math.abs(topScreen.Y - bottomScreen.Y)
    local width = height * (CONSTANTS.ESP_WIDTH_STUDS / CONSTANTS.ESP_HEIGHT_STUDS)

    return screenPos.X - width / 2, screenPos.Y - height / 2, width, height
end


local function isStrictRayVisible(targetPart)
    if not targetPart or not targetPart.Parent then return false end

    local origin = Camera.CFrame.Position
    local direction = targetPart.Position - origin
    if direction.Magnitude <= 1e-4 then return false end

    RayIgnoreList[2] = LocalPlayer.Character
    RayIgnoreList[3] = getCachedRayIgnore()
    VisibilityParams.FilterDescendantsInstances = RayIgnoreList

    getgenv().IgnoreRaycastHook = true
    local success, result = pcall(function() return Workspace:Raycast(origin, direction, VisibilityParams) end)
    getgenv().IgnoreRaycastHook = false
    local raycastResult = success and result or nil

    if not raycastResult or not raycastResult.Instance then return false end

    local hitInst = raycastResult.Instance

    if hitInst == targetPart then
        return true
    end

    local hitParent = hitInst.Parent
    if hitParent and hitParent:IsA("Accessory") and hitParent.Parent == targetPart.Parent then
        return true
    end

    local hitName = hitInst.Name
    local isSmoke = hitName == "Smoke" or hitName:find("Smoke") or (hitInst.Material and hitInst.Material.Name == "Smoke")
    if isSmoke then
        return true
    end

    return false
end

local function isVisibleTarget(character)
    if not character then return false end

    local selectedHitbox = Options.AimbotHitbox and Options.AimbotHitbox.Value or "Head"
    local fallbacks = CONSTANTS.AimHitboxFallbacks[selectedHitbox] or CONSTANTS.AimHitboxFallbacks.Head

    for _, partName in ipairs(fallbacks) do
        local part = findCharacterPart(character, partName)
        if part then
            return isStrictRayVisible(part)
        end
    end

    return false
end


local function drawBulletTracer(startPos, endPos)
    if not Toggles.MiscBulletTracer or not Toggles.MiscBulletTracer.Value then return end

    local color = getOptionColor("MiscBulletTracerColor", Color3.fromRGB(255, 0, 0))
    local tracerMode = Options.MiscBulletTracerTexture and Options.MiscBulletTracerTexture.Value or "Laser"
    local textureId = CONSTANTS.TracerTextureMap[tracerMode] or CONSTANTS.TracerTextureMap["Laser"]

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


local _hitSoundObj = nil
local PlayHitSound = nil
local ShowHitMarker = nil

local _hmOutlineLines = {}
local _hmFillLines = {}
local _hmActive = false
local _hmCreated = false

local function ensureHitMarkerLines()
    if _hmCreated then return end
    for i = 1, 4 do
        local success1, outlineLine = pcall(Drawing.new, "Line")
        if success1 and outlineLine then
            outlineLine.Thickness = 5
            outlineLine.Visible = false
            _hmOutlineLines[i] = outlineLine
        end
        local success2, fillLine = pcall(Drawing.new, "Line")
        if success2 and fillLine then
            fillLine.Thickness = 3
            fillLine.Visible = false
            _hmFillLines[i] = fillLine
        end
    end
    _hmCreated = true
end

ShowHitMarker = function()
    ensureHitMarkerLines()
    if _hmActive then return end

    local cam = getCamera()
    if not cam then return end
    local viewportSize = cam.ViewportSize
    if not viewportSize then return end
    local centerX, centerY = viewportSize.X / 2, viewportSize.Y / 2

    _hmActive = true
    local gap, len = 4, 10
    local color = nil
    pcall(function() color = Options.MiscHitMarkerColor.Value end)
    color = color or Color3.fromRGB(255, 255, 255)
    local outlineColor = Color3.fromRGB(0, 0, 0)

    local segs = {
        {Vector2.new(centerX - gap - len, centerY - gap - len), Vector2.new(centerX - gap, centerY - gap)},
        {Vector2.new(centerX + gap, centerY - gap), Vector2.new(centerX + gap + len, centerY - gap - len)},
        {Vector2.new(centerX - gap - len, centerY + gap + len), Vector2.new(centerX - gap, centerY + gap)},
        {Vector2.new(centerX + gap, centerY + gap), Vector2.new(centerX + gap + len, centerY + gap + len)},
    }

    for i, seg in ipairs(segs) do
        if _hmOutlineLines[i] then
            pcall(function()
                _hmOutlineLines[i].From = seg[1]
                _hmOutlineLines[i].To = seg[2]
                _hmOutlineLines[i].Color = outlineColor
                _hmOutlineLines[i].Transparency = 1
                _hmOutlineLines[i].Visible = true
            end)
        end
        if _hmFillLines[i] then
            pcall(function()
                _hmFillLines[i].From = seg[1]
                _hmFillLines[i].To = seg[2]
                _hmFillLines[i].Color = color
                _hmFillLines[i].Transparency = 1
                _hmFillLines[i].Visible = true
            end)
        end
    end

    task.spawn(function()
        local lifetime = 3
        pcall(function() lifetime = Options.MiscHitMarkerLifetime.Value end)
        lifetime = lifetime or 3
        local allObjs = {}
        for _, obj in ipairs(_hmOutlineLines) do
            if obj then table.insert(allObjs, obj) end
        end
        for _, obj in ipairs(_hmFillLines) do
            if obj then table.insert(allObjs, obj) end
        end
        if #allObjs == 0 then _hmActive = false return end

        local fadeTime = 0.3
        local holdTime = lifetime - fadeTime
        if holdTime < 0 then holdTime = 0; fadeTime = lifetime end

        task.delay(holdTime, function()
            local steps = 10
            local stepTime = fadeTime / steps
            for step = 1, steps do
                local alpha = 1 - (step / steps)
                for _, obj in ipairs(allObjs) do
                    pcall(function() obj.Transparency = alpha end)
                end
                task.wait(stepTime)
            end
            for _, obj in ipairs(allObjs) do
                pcall(function() obj.Visible = false; obj.Transparency = 1 end)
            end
            _hmActive = false
        end)
    end)
end

PlayHitSound = function()
    if not Toggles.MiscHitSound or not Toggles.MiscHitSound.Value then return end
    if not _hitSoundObj then return end
    local soundType = Options.MiscHitSoundType and Options.MiscHitSoundType.Value or "Skeet"
    local sndId = CONSTANTS.HitSounds[soundType]
    if type(sndId) == "table" then
        sndId = sndId[math.random(1, #sndId)]
    end
    _hitSoundObj.SoundId = sndId or "rbxassetid://3124331820"
    _hitSoundObj.Volume = Options.MiscHitSoundVolume and Options.MiscHitSoundVolume.Value or 5
    _hitSoundObj:Play()
end


local function isAnyEspEnabled()
    return (Toggles.ESPEnable and Toggles.ESPEnable.Value)
        or (Toggles.ESPBox and Toggles.ESPBox.Value)
        or (Toggles.ESPBoxFill and Toggles.ESPBoxFill.Value)
        or (Toggles.ESPName and Toggles.ESPName.Value)
        or (Toggles.ESPWeapon and Toggles.ESPWeapon.Value)
        or (Toggles.ESPHealthBar and Toggles.ESPHealthBar.Value)
        or (Toggles.ESPChams and Toggles.ESPChams.Value)
end


-- forward declarations
local updateRCS, updateRapidFire, updateFullAuto
local restoreAllRapidFireRates, restoreAllFullAutoValues
local applyNoRecoil, applyNoSpread, applyInstaEquip, applyInstaReload
local fireSingleShot
local updateBhop, updateLegitBhop, updateThirdPerson
local onAutoJumpChanged
local updateHitChams
local updateGrenadePrediction, updateNoScope, updateNoFlash, applyNoScope, setupNoSmoke
local ensureCrosshair, updateCrosshair
local unloadValenok




-- combat

local AimRuntime = {
    FovLines = {},
}

local TriggerbotState = {
    AwaitingRelease = false,
    NextFireTime = 0,
    StopTime = 0,
    WasMoving = false,
    Holding = false,
    DelayUntil = 0,
    DelayActive = false,
}

local RagebotState = {
    NextFireTime = 0,
    Firing = false,
}

local RapidFireState = { SavedFireRates = {} }
local FullAutoState = { SavedAutoValues = {} }
local InstaWeaponState = { SavedEquipTimes = {}, SavedReloadTimes = {} }
local SavedRecoilValues = {}
local OriginalAccuracySd = nil
local RCSOriginalValues = {}


local function getAimFov()
    local fovValue = Options.AimbotFOV and Options.AimbotFOV.Value
    if type(fovValue) ~= "number" then return 45 end
    return math.clamp(fovValue, 1, 180)
end

local function getAimSmooth()
    local smoothValue = Options.AimbotSmooth and Options.AimbotSmooth.Value
    if type(smoothValue) ~= "number" then return 4 end
    return math.clamp(smoothValue, 1, 10)
end

local function getAimFovRadius()
    local aimFov = getAimFov()
    local cam = getCamera()
    local key = "AimFovRadius_" .. aimFov .. "_" .. cam.FieldOfView .. "_" .. cam.ViewportSize.Y
    return Cache:getOrSet(key, 0, function()
        if aimFov >= 180 then return 999999 end
        local halfViewport = cam.ViewportSize.Y * 0.5
        local camFovHalfRad = math.rad(cam.FieldOfView * 0.5)
        local aimFovHalfRad = math.rad(aimFov * 0.5)
        return (math.tan(aimFovHalfRad) / math.tan(camFovHalfRad)) * halfViewport
    end)
end


local function getAimHitboxPart(character, humanoid)
    local selectedHitbox = Options.AimbotHitbox and Options.AimbotHitbox.Value or "Head"

    if selectedHitbox == "Nearest" then
        local allParts = {}
        for _, part in ipairs(character:GetChildren()) do
            if part:IsA("BasePart") and CONSTANTS.RealHitboxLookup[part.Name] then
                table.insert(allParts, part)
            end
        end

        local bestPart = nil
        local bestDistance = math.huge
        local screenCenter = Vector2.new(Camera.ViewportSize.X * 0.5, Camera.ViewportSize.Y * 0.5)

        for _, part in ipairs(allParts) do
            local screenPoint = Camera:WorldToViewportPoint(part.Position)
            if screenPoint.Z > 0 then
                local distance = (Vector2.new(screenPoint.X, screenPoint.Y) - screenCenter).Magnitude
                if distance < bestDistance then
                    bestDistance = distance
                    bestPart = part
                end
            end
        end

        return bestPart
    end

    local fallbacks = CONSTANTS.AimHitboxFallbacks[selectedHitbox] or CONSTANTS.AimHitboxFallbacks.Head

    for _, partName in ipairs(fallbacks) do
        local part = findCharacterPart(character, partName)
        if part then
            return part
        end
    end

    return nil
end

local function isBaimKeyActive()
    if not Toggles.AimbotBaim or not Toggles.AimbotBaim.Value then return false end
    return isKeybindActive(Options.AimbotBaimKeybind)
end


local function getClosestAimTarget(screenCenter, fovRadius)
    local bestPart = nil
    local bestMetric = math.huge
    local useVisible = Toggles.AimbotVisibleCheck and Toggles.AimbotVisibleCheck.Value
    local isFullCircle = getAimFov() >= 180
    local camLook = Camera.CFrame.LookVector
    local camPos = Camera.CFrame.Position

    local function evaluatePart(targetPart, character)
        if isFullCircle then
            local delta = targetPart.Position - camPos
            if delta.Magnitude < 1e-4 then return end
            local dir = delta.Unit
            local angle = math.acos(math.clamp(camLook:Dot(dir), -1, 1))
            if useVisible and not isVisibleTarget(character) then return end
            if angle < bestMetric then
                bestMetric = angle
                bestPart = targetPart
            end
        else
            local screenPoint = Camera:WorldToViewportPoint(targetPart.Position)
            if screenPoint.Z <= 0 then return end
            local distanceFromCrosshair = (Vector2.new(screenPoint.X, screenPoint.Y) - screenCenter).Magnitude
            if distanceFromCrosshair > fovRadius then return end
            if useVisible and not isVisibleTarget(character) then return end
            if distanceFromCrosshair < bestMetric then
                bestMetric = distanceFromCrosshair
                bestPart = targetPart
            end
        end
    end

    for _, player in ipairs(Players:GetPlayers()) do
        if not isEnemy(player) then continue end

        local character = player.Character
        if not character then continue end
        if hasShield(character) then continue end

        local humanoid = character:FindFirstChildOfClass("Humanoid")
        local rootPart = character:FindFirstChild("HumanoidRootPart")
        if not humanoid or humanoid.Health <= 0 or not rootPart then continue end

        local targetPart

        if isBaimKeyActive() then
            local bodyFallbacks = { "UpperTorso", "LowerTorso", "Torso", "HumanoidRootPart" }
            for _, bName in ipairs(bodyFallbacks) do
                local bPart = findCharacterPart(character, bName)
                if bPart then
                    targetPart = bPart
                    break
                end
            end
        else
            targetPart = getAimHitboxPart(character, humanoid)
        end

        if not targetPart then continue end

        evaluatePart(targetPart, character)
    end

    return bestPart
end

local function isPartTargetable(targetPart, screenCenter, fovRadius)
    if not targetPart or not targetPart.Parent then return false end

    local character = targetPart.Parent
    if not character or not character.Parent then return false end
    if hasShield(character) then return false end

    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.Health <= 0 then return false end

    if Toggles.AimbotVisibleCheck and Toggles.AimbotVisibleCheck.Value then
        if not isVisibleTarget(character) then return false end
    end

    if getAimFov() >= 180 then return true end

    local screenPoint = Camera:WorldToViewportPoint(targetPart.Position)
    if screenPoint.Z <= 0 then return false end

    local distanceFromCrosshair = (Vector2.new(screenPoint.X, screenPoint.Y) - screenCenter).Magnitude
    if distanceFromCrosshair > (fovRadius * 1.15) then return false end

    return true
end


local function updateAimBot()
    local cam = getCamera()
    local aimShouldRun = Toggles.AimbotEnable and Toggles.AimbotEnable.Value and isKeybindActive(Options.AimbotKeybind)
    if not cam or not aimShouldRun then
        Cache:invalidate("AimTarget")
        return
    end

    local viewport = cam.ViewportSize
    local screenCenter = Vector2.new(viewport.X * 0.5, viewport.Y * 0.5)
    local fovRadius = getAimFovRadius()

    local targetPart = Cache:get("AimTarget")
    if not isPartTargetable(targetPart, screenCenter, fovRadius) then
        targetPart = getClosestAimTarget(screenCenter, fovRadius)
        Cache:set("AimTarget", targetPart, 1/30)
    end

    if not targetPart then return end

    local smoothValue = getAimSmooth()
    local aimPos = targetPart.Position
    local camPos = cam.CFrame.Position
    local aimDelta = aimPos - camPos
    if aimDelta.Magnitude < 1e-4 then return end
    local targetCFrame = CFrame.lookAt(camPos, aimPos)

    if smoothValue <= 1 then
        cam.CFrame = targetCFrame
    else
        local speed = 32 - ((smoothValue - 1) * 3)
        local lerpAlpha = math.clamp(0.016 * speed, 0.05, 0.9)
        cam.CFrame = cam.CFrame:Lerp(targetCFrame, lerpAlpha)
    end
end


local function getRagebotFovRadius()
    local fovValue = Options.RagebotFOV and Options.RagebotFOV.Value or 1
    fovValue = math.clamp(fovValue, 1, 180)
    local cam = getCamera()
    local key = "RageFovRadius_" .. fovValue .. "_" .. cam.FieldOfView .. "_" .. cam.ViewportSize.Y
    return Cache:getOrSet(key, 0, function()
        if fovValue >= 180 then return 999999 end
        local halfViewport = cam.ViewportSize.Y * 0.5
        local camFovHalfRad = math.rad(cam.FieldOfView * 0.5)
        local rageFovHalfRad = math.rad(fovValue * 0.5)
        return (math.tan(rageFovHalfRad) / math.tan(camFovHalfRad)) * halfViewport
    end)
end

local function isRagebotBaimKeyActive()
    if not Toggles.RagebotBaim or not Toggles.RagebotBaim.Value then return false end
    return isKeybindActive(Options.RagebotBaimKeybind)
end


local function findRagebotHeadPart(character)
    local headParts = { "HeadHB", "Head", "FakeHead" }
    for _, hName in ipairs(headParts) do
        local hPart = findCharacterPart(character, hName)
        if hPart then return hPart end
    end
    return nil
end

local function findRagebotBodyPart(character, screenCenter)
    local bestPart = nil
    local bestDistance = math.huge

    local priorityGroups = {
        { "UpperTorso", "LowerTorso", "HumanoidRootPart", "LeftUpperArm", "LeftLowerArm", "LeftHand", "RightUpperArm", "RightLowerArm", "RightHand" },
        { "LeftUpperLeg", "LeftLowerLeg", "LeftFoot", "RightUpperLeg", "RightLowerLeg", "RightFoot" },
    }

    for _, group in ipairs(priorityGroups) do
        bestPart = nil
        bestDistance = math.huge
        for _, partName in ipairs(group) do
            local part = findCharacterPart(character, partName)
            if part then
                local screenPoint = Camera:WorldToViewportPoint(part.Position)
                if screenPoint.Z > 0 then
                    local distance = (Vector2.new(screenPoint.X, screenPoint.Y) - screenCenter).Magnitude
                    if distance < bestDistance then
                        bestDistance = distance
                        bestPart = part
                    end
                end
            end
        end
        if bestPart then break end
    end

    return bestPart
end


local function getRagebotTarget()
    local bestPart = nil
    local bestMetric = math.huge
    local useVisible = Toggles.RagebotVisCheck and Toggles.RagebotVisCheck.Value
    local isFullCircle = (Options.RagebotFOV and Options.RagebotFOV.Value or 1) >= 180
    local camLook = Camera.CFrame.LookVector
    local camPos = Camera.CFrame.Position

    local function evaluatePart(targetPart, character)
        if isFullCircle then
            local delta = targetPart.Position - camPos
            if delta.Magnitude < 1e-4 then return end
            local dir = delta.Unit
            local angle = math.acos(math.clamp(camLook:Dot(dir), -1, 1))
            if useVisible and not isVisibleTarget(character) then return end
            if angle < bestMetric then
                bestMetric = angle
                bestPart = targetPart
            end
        else
            local screenPoint = Camera:WorldToViewportPoint(targetPart.Position)
            if screenPoint.Z <= 0 then return end
            local distanceFromCrosshair = (Vector2.new(screenPoint.X, screenPoint.Y) - Vector2.new(Camera.ViewportSize.X * 0.5, Camera.ViewportSize.Y * 0.5)).Magnitude
            if distanceFromCrosshair > getRagebotFovRadius() then return end
            if useVisible and not isVisibleTarget(character) then return end
            if distanceFromCrosshair < bestMetric then
                bestMetric = distanceFromCrosshair
                bestPart = targetPart
            end
        end
    end

    for _, player in ipairs(Players:GetPlayers()) do
        if player == LocalPlayer then continue end

        if Toggles.RagebotTeamCheck and Toggles.RagebotTeamCheck.Value then
            local myTeam, theirTeam = LocalPlayer.Team, player.Team
            if myTeam ~= nil and theirTeam ~= nil and theirTeam == myTeam then
                continue
            end
        end

        local character = player.Character
        if not character then continue end
        if hasShield(character) then continue end

        local humanoid = character:FindFirstChildOfClass("Humanoid")
        local rootPart = character:FindFirstChild("HumanoidRootPart")
        if not humanoid or humanoid.Health <= 0 or not rootPart then continue end

        local targetPart

        if isRagebotBaimKeyActive() then
            local bodyFallbacks = { "UpperTorso", "LowerTorso", "Torso", "HumanoidRootPart" }
            for _, bName in ipairs(bodyFallbacks) do
                local bPart = findCharacterPart(character, bName)
                if bPart then
                    targetPart = bPart
                    break
                end
            end
        else
            -- head priority
            targetPart = findRagebotHeadPart(character)

            -- body fallback
            if not targetPart then
                local screenCenter = Vector2.new(Camera.ViewportSize.X * 0.5, Camera.ViewportSize.Y * 0.5)
                targetPart = findRagebotBodyPart(character, screenCenter)
            end
        end

        if not targetPart then continue end

        evaluatePart(targetPart, character)

        -- camera resolver
        if Toggles.RagebotCameraResolver and Toggles.RagebotCameraResolver.Value then
            local cameraCF = player:FindFirstChild("CameraCF")
            if cameraCF and cameraCF.Value then
                local camPos = cameraCF.Value.Position
                if camPos == camPos and (camPos - rootPart.Position).Magnitude > 8 then
                    local fakePart = setmetatable({}, {__index = function(_, k)
                        if k == "Position" then return camPos end
                        return rootPart[k]
                    end})
                    evaluatePart(fakePart, character)
                end
            end
        end
    end

    return bestPart
end


local function updateRagebot()
    local cam = getCamera()
    if not cam then return end
    local ragebotEnabled = Toggles.RagebotEnable and Toggles.RagebotEnable.Value
    local keyActive = isKeybindActive(Options.RagebotKeybind)

    if not ragebotEnabled or not keyActive then
        getgenv().PSilentTargetPos = nil
        Cache:invalidate("RageTarget")
        return
    end

    local now = tick()
    local targetPart = Cache:get("RageTarget")

    if not targetPart or not targetPart.Parent then
        targetPart = getRagebotTarget()
        Cache:set("RageTarget", targetPart, 1/30)
    else
        -- validate cached target still alive
        local character = targetPart:FindFirstAncestorOfClass('Model')
        local humanoid = character and character:FindFirstChildOfClass('Humanoid')
        if not humanoid or humanoid.Health <= 0 then
            targetPart = getRagebotTarget()
            Cache:set("RageTarget", targetPart, 1/30)
        end
    end

    if targetPart then
        getgenv().PSilentTargetPos = targetPart.Position

        -- auto fire
        if Toggles.RagebotAutoFire and Toggles.RagebotAutoFire.Value then
            local character = LocalPlayer.Character
            local humanoid = character and character:FindFirstChildOfClass("Humanoid")
            if character and humanoid and humanoid.Health > 0 then
                if now >= RagebotState.NextFireTime and not RagebotState.Firing then
                    RagebotState.NextFireTime = now + 0.13
                    RagebotState.Firing = true
                    task.spawn(function()
                        local mouse = LocalPlayer:GetMouse()
                        local mouseX = mouse.X
                        local mouseY = mouse.Y
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


local function checkTriggerbotConditions(character, humanoid)
    if not Toggles.TriggerbotEnable or not Toggles.TriggerbotEnable.Value then return false end
    if not isKeybindActive(Options.TriggerbotKeybind) then return false end
    if not character or not humanoid or humanoid.Health <= 0 then return false end

    if Toggles.TriggerbotJumpCheck and Toggles.TriggerbotJumpCheck.Value then
        if humanoid:GetState() == Enum.HumanoidStateType.Jumping or humanoid.FloorMaterial == Enum.Material.Air then
            return false
        end
    end

    return true
end

local function findTriggerbotTarget(cam)
    local targetPart = nil
    local mouse = LocalPlayer:GetMouse()
    local hitInstance = mouse.Target

    -- raycast fallback if no mouse target
    if (not hitInstance or not hitInstance.Parent) and not (Toggles.TriggerbotSmokeCheck and Toggles.TriggerbotSmokeCheck.Value) then
        local mousePos = UserInputService:GetMouseLocation()
        local ray = cam:ViewportPointToRay(mousePos.X, mousePos.Y)
        RayIgnoreList[2] = LocalPlayer.Character
        RayIgnoreList[3] = getCachedRayIgnore()
        VisibilityParams.FilterDescendantsInstances = RayIgnoreList
        local rayResult = Workspace:Raycast(ray.Origin, ray.Direction * 5000, VisibilityParams)
        if rayResult and rayResult.Instance then
            local resultName = rayResult.Instance.Name
            if resultName == "Smoke" or resultName:find("Smoke") or (rayResult.Instance.Material and rayResult.Instance.Material.Name == "Smoke") then
                local smokeIgnore = {Camera, LocalPlayer.Character, getCachedRayIgnore(), rayResult.Instance}
                local smokeParams = RaycastParams.new()
                smokeParams.FilterType = Enum.RaycastFilterType.Exclude
                smokeParams.FilterDescendantsInstances = smokeIgnore
                smokeParams.IgnoreWater = true
                local ray2 = Workspace:Raycast(ray.Origin, ray.Direction * 5000, smokeParams)
                if ray2 and ray2.Instance then
                    hitInstance = ray2.Instance
                end
            end
        end
    end

    if hitInstance and hitInstance.Parent then
        local hitChar = hitInstance:FindFirstAncestorOfClass("Model")
        if hitChar then
            local hitPlayer = Players:GetPlayerFromCharacter(hitChar)

            if hitPlayer and Toggles.TriggerbotTeamCheck and Toggles.TriggerbotTeamCheck.Value then
                local myTeam, theirTeam = LocalPlayer.Team, hitPlayer.Team
                local myTeamColor, theirTeamColor = LocalPlayer.TeamColor, hitPlayer.TeamColor
                if (myTeam ~= nil and theirTeam ~= nil and theirTeam == myTeam) or
                   (myTeamColor ~= nil and theirTeamColor ~= nil and theirTeamColor == myTeamColor) then
                    return nil
                end
            end

            if hitPlayer and isTriggerEnemy(hitPlayer) then
                local humanoid = hitChar:FindFirstChildOfClass("Humanoid")
                if humanoid and humanoid.Health > 0 then
                    if isStrictRayVisible(hitInstance) then
                        -- smoke check
                        if Toggles.TriggerbotSmokeCheck and Toggles.TriggerbotSmokeCheck.Value then
                            local origin = cam.CFrame.Position
                            local direction = hitInstance.Position - origin
                            RayIgnoreList[2] = LocalPlayer.Character
                            RayIgnoreList[3] = getCachedRayIgnore()
                            VisibilityParams.FilterDescendantsInstances = RayIgnoreList
                            local rayResult = Workspace:Raycast(origin, direction, VisibilityParams)
                            if rayResult and rayResult.Instance then
                                local resultName = rayResult.Instance.Name
                                if resultName == "Smoke" or resultName:find("Smoke") or (rayResult.Instance.Material and rayResult.Instance.Material.Name == "Smoke") then
                                    return nil
                                end
                            end
                        end
                        targetPart = hitInstance
                    end
                end
            end
        end
    end

    return targetPart
end

local function applyTriggerbotMagnet(cam, now)
    if not Toggles.TriggerbotMagnet or not Toggles.TriggerbotMagnet.Value then return end

    local magnetFov = 25
    local smooth = math.clamp(5, 1, 10)
    local mousePos = UserInputService:GetMouseLocation()
    local magnetTarget = nil
    local bestDistance = math.huge

    local cached = Cache:get("MagnetTarget")
    if cached then
        magnetTarget = cached
    else
        if now - (TriggerbotState.LastMagnetScan or 0) >= (1/30) then
            TriggerbotState.LastMagnetScan = now
            for _, player in ipairs(Players:GetPlayers()) do
                if player == LocalPlayer then continue end
                if not isTriggerEnemy(player) then continue end

                local character = player.Character
                if not character then continue end
                local humanoid = character:FindFirstChildOfClass("Humanoid")
                if not humanoid or humanoid.Health <= 0 then continue end

                local magnetHitboxes = {"Head", "HeadHB", "HumanoidRootPart", "UpperTorso", "Torso"}
                for _, partName in ipairs(magnetHitboxes) do
                    local part = character:FindFirstChild(partName)
                    if part and part:IsA("BasePart") then
                        local screenPoint = cam:WorldToViewportPoint(part.Position)
                        if screenPoint.Z > 0 then
                            local dist = (Vector2.new(screenPoint.X, screenPoint.Y) - mousePos).Magnitude
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
            Cache:set("MagnetTarget", magnetTarget, 1/30)
        end
    end

    if magnetTarget then
        local targetPosition = magnetTarget.Position
        local smoothFactor = smooth / 15
        local targetCF = CFrame.new(cam.CFrame.Position, targetPosition)
        cam.CFrame = cam.CFrame:Lerp(targetCF, smoothFactor)
    end
end


fireSingleShot = function()
    local character = LocalPlayer.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if not character or not humanoid or humanoid.Health <= 0 then return end

    local mouse = LocalPlayer:GetMouse()
    local mouseX = mouse.X
    local mouseY = mouse.Y

    pcall(function()
        VirtualInputManager:SendMouseButtonEvent(mouseX, mouseY, 0, true, game, 1)
        task.wait(0.1)
        VirtualInputManager:SendMouseButtonEvent(mouseX, mouseY, 0, false, game, 1)
    end)
    TriggerbotState.NextFireTime = tick() + 0.01
end


local function updateTriggerbot()
    local cam = getCamera()
    if not cam then return end

    local character = LocalPlayer.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if not checkTriggerbotConditions(character, humanoid) then return end

    local now = tick()

    -- on stop only
    if Toggles.TriggerbotOnStopOnly and Toggles.TriggerbotOnStopOnly.Value then
        local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
        if humanoidRootPart then
            local velocity = humanoidRootPart.AssemblyLinearVelocity
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

    local targetPart = findTriggerbotTarget(cam)

    -- validate target alive
    if targetPart and targetPart.Parent then
        local hitChar = targetPart:FindFirstAncestorOfClass("Model")
        local humanoid = hitChar and hitChar:FindFirstChildOfClass("Humanoid")
        if not humanoid or humanoid.Health <= 0 then
            targetPart = nil
        end
    end

    applyTriggerbotMagnet(cam, now)

    if targetPart then
        local currentTime = tick()
        if TriggerbotState.NextFireTime - currentTime > 2 then
            TriggerbotState.NextFireTime = 0
        end
        local delayMs = Options.TriggerbotDelay.Value or 0
        if not TriggerbotState.DelayActive then
            TriggerbotState.DelayActive = true
            TriggerbotState.DelayUntil = currentTime + (delayMs / 1000)
        end
        if currentTime >= TriggerbotState.DelayUntil and currentTime >= TriggerbotState.NextFireTime then
            fireSingleShot()
        end
    else
        TriggerbotState.DelayActive = false
    end
end


local function updateAntiAimPitch(cam, character, humanoid, rootPart)
    local pitchEnabled = Toggles.AntiAimPitch and Toggles.AntiAimPitch.Value
    local pitchMode = Options.AntiAimPitchMode and Options.AntiAimPitchMode.Value or "None"

    if pitchEnabled then
        getgenv().ValenokPitchDownEnabled = true
        if pitchMode == "Up" then
            getgenv().ValenokPitchValue = 100
        elseif pitchMode == "Down" then
            getgenv().ValenokPitchValue = -100
        elseif pitchMode == "Random" then
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
end

local function updateAntiAimYaw(cam, character, humanoid, rootPart)
    local yawEnabled = Toggles.AntiAimYaw and Toggles.AntiAimYaw.Value
    local yawMode = Options.AntiAimYawMode and Options.AntiAimYawMode.Value or "Local"
    local yawValue = Options.AntiAimYawValue and Options.AntiAimYawValue.Value or 0
    local pitchEnabled = Toggles.AntiAimPitch and Toggles.AntiAimPitch.Value
    local pitchMode = Options.AntiAimPitchMode and Options.AntiAimPitchMode.Value or "None"

    if yawEnabled then
        humanoid.AutoRotate = false

        local yawRad = math.rad(yawValue)
        local lookVector = Vector3.new(0, 0, -1)

        if yawMode == "At target" then
            local closestPlayer = nil
            local closestDist = math.huge

            for _, player in pairs(Players:GetPlayers()) do
                if player == LocalPlayer then continue end
                local pTeam = player.Team
                local lpTeam = LocalPlayer.Team
                if pTeam and lpTeam and pTeam == lpTeam then continue end

                local char = player.Character
                if not char then continue end
                local humanoidRootPart = char:FindFirstChild("HumanoidRootPart")
                if not humanoidRootPart then continue end
                local hum = char:FindFirstChildOfClass("Humanoid")
                if not hum or hum.Health <= 0 then continue end

                local dist = (humanoidRootPart.Position - rootPart.Position).Magnitude
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
                    if pitchEnabled then
                        if pitchMode == "Down" then
                            yawRad = math.rad(-180)
                        elseif pitchMode == "Up" then
                            yawRad = math.rad(0)
                        end
                    end
                end
            else
                local camLook = cam.CFrame.LookVector
                local flatMag = math.sqrt(camLook.X ^ 2 + camLook.Z ^ 2)
                if flatMag > 1e-4 then
                    lookVector = Vector3.new(camLook.X / flatMag, 0, camLook.Z / flatMag)
                end
            end
        elseif yawMode == "Random" then
            if tick() - (getgenv().LastRandomYaw or 0) > (1/60) then
                getgenv().LastRandomYaw = tick()
                getgenv().RandomYawValue = math.random(-180, 180)
            end
            yawRad = math.rad(getgenv().RandomYawValue or 0)
            local camLook = cam.CFrame.LookVector
            local flatMag = math.sqrt(camLook.X ^ 2 + camLook.Z ^ 2)
            if flatMag > 1e-4 then
                lookVector = Vector3.new(camLook.X / flatMag, 0, camLook.Z / flatMag)
            end
        else
            local camLook = cam.CFrame.LookVector
            local flatMag = math.sqrt(camLook.X ^ 2 + camLook.Z ^ 2)
            if flatMag > 1e-4 then
                lookVector = Vector3.new(camLook.X / flatMag, 0, camLook.Z / flatMag)
            end
        end

        if lookVector.Magnitude > 0 then
            rootPart.CFrame = CFrame.lookAt(rootPart.Position, rootPart.Position + lookVector) * CFrame.Angles(0, yawRad, 0)
        end
    else
        humanoid.AutoRotate = true
    end
end

local function updateAntiAim()
    local cam = getCamera()
    if not cam then return end
    local pitchEnabled = Toggles.AntiAimPitch and Toggles.AntiAimPitch.Value
    local yawEnabled = Toggles.AntiAimYaw and Toggles.AntiAimYaw.Value

    local character = LocalPlayer.Character
    if not character then return end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if not (humanoid and rootPart) or humanoid.Health <= 0 then return end

    if not pitchEnabled and not yawEnabled then
        humanoid.AutoRotate = true
        getgenv().ValenokPitchDownEnabled = false
        return
    end

    updateAntiAimPitch(cam, character, humanoid, rootPart)
    updateAntiAimYaw(cam, character, humanoid, rootPart)
end


applyNoRecoil = function(enabled)
    local weapons = getWeaponsFolder()
    if not weapons then return end
    for _, weaponFolder in ipairs(weapons:GetChildren()) do
        if not weaponFolder:IsA("Folder") then continue end
        local spread = weaponFolder:FindFirstChild("Spread")
        if not spread then continue end
        local recoil = spread:FindFirstChild("Recoil")
        if not recoil or not recoil:IsA("NumberValue") then continue end
        if enabled then
            if SavedRecoilValues[weaponFolder.Name] == nil then
                SavedRecoilValues[weaponFolder.Name] = recoil.Value
            end
            recoil.Value = 1
        else
            local original = SavedRecoilValues[weaponFolder.Name]
            if original ~= nil then
                recoil.Value = original
                SavedRecoilValues[weaponFolder.Name] = nil
            end
        end
    end
end

applyNoSpread = function(enabled)
    local client = getCachedClient()
    if not client then return end
    if enabled then
        if OriginalAccuracySd == nil then
            OriginalAccuracySd = client.accuracy_sd
        end
        client.accuracy_sd = 0
    else
        if OriginalAccuracySd ~= nil then
            client.accuracy_sd = OriginalAccuracySd
        end
    end
end

applyInstaEquip = function(enabled)
    local weapons = getWeaponsFolder()
    if not weapons then return end
    if enabled then
        for _, weaponFolder in ipairs(weapons:GetChildren()) do
            if weaponFolder:IsA("Folder") then
                local equipTime = weaponFolder:FindFirstChild("EquipTime")
                if equipTime and equipTime:IsA("NumberValue") then
                    if InstaWeaponState.SavedEquipTimes[weaponFolder.Name] == nil then
                        InstaWeaponState.SavedEquipTimes[weaponFolder.Name] = equipTime.Value
                    end
                    equipTime.Value = 0
                end
            end
        end
    else
        for weaponName, original in pairs(InstaWeaponState.SavedEquipTimes) do
            local weaponFolder = weapons:FindFirstChild(weaponName)
            local equipTime = weaponFolder and weaponFolder:FindFirstChild("EquipTime")
            if equipTime and equipTime:IsA("NumberValue") then equipTime.Value = original end
        end
        table.clear(InstaWeaponState.SavedEquipTimes)
    end
end

applyInstaReload = function(enabled)
    local weapons = getWeaponsFolder()
    if not weapons then return end
    if enabled then
        for _, weaponFolder in ipairs(weapons:GetChildren()) do
            if weaponFolder:IsA("Folder") then
                local reloadTime = weaponFolder:FindFirstChild("ReloadTime")
                if reloadTime and reloadTime:IsA("NumberValue") then
                    if InstaWeaponState.SavedReloadTimes[weaponFolder.Name] == nil then
                        InstaWeaponState.SavedReloadTimes[weaponFolder.Name] = reloadTime.Value
                    end
                    reloadTime.Value = 0.1
                end
            end
        end
    else
        for weaponName, original in pairs(InstaWeaponState.SavedReloadTimes) do
            local weaponFolder = weapons:FindFirstChild(weaponName)
            local reloadTime = weaponFolder and weaponFolder:FindFirstChild("ReloadTime")
            if reloadTime and reloadTime:IsA("NumberValue") then reloadTime.Value = original end
        end
        table.clear(InstaWeaponState.SavedReloadTimes)
    end
end


local function getCurrentWeaponFireRateObject()
    local character = LocalPlayer.Character
    if not character then return nil, nil end

    local weaponName = nil
    local equippedToolValue = character:FindFirstChild("EquippedTool")
    if equippedToolValue then
        weaponName = tostring(equippedToolValue.Value)
    end

    if not weaponName then return nil, nil end

    local weapons = getWeaponsFolder()
    if not weapons then return nil, nil end

    local weaponFolder = weapons:FindFirstChild(weaponName)
    if not weaponFolder then return nil, nil end

    local fireRate = weaponFolder:FindFirstChild("FireRate")
    if fireRate and fireRate:IsA("NumberValue") then
        return fireRate, weaponName
    end

    return nil, nil
end


restoreAllRapidFireRates = function()
    local weapons = getWeaponsFolder()
    if weapons then
        for weaponName, original in pairs(RapidFireState.SavedFireRates) do
            local weaponFolder = weapons:FindFirstChild(weaponName)
            local fireRate = weaponFolder and weaponFolder:FindFirstChild("FireRate")
            if fireRate and fireRate:IsA("NumberValue") then
                fireRate.Value = original
            end
        end
    end
    table.clear(RapidFireState.SavedFireRates)
end

updateRapidFire = function()
    if not Toggles.GunModsRapidFire or not Toggles.GunModsRapidFire.Value then return end

    local fireRate, weaponName = getCurrentWeaponFireRateObject()
    if not fireRate or not weaponName then return end

    if RapidFireState.SavedFireRates[weaponName] == nil then
        RapidFireState.SavedFireRates[weaponName] = fireRate.Value
    end

    local original = RapidFireState.SavedFireRates[weaponName]
    local multiplier = CONSTANTS.RAPID_FIRE_MULTIPLIERS[weaponName] or 3
    local targetValue = original / multiplier
    if fireRate.Value ~= targetValue then
        fireRate.Value = targetValue
    end
end


restoreAllFullAutoValues = function()
    local weapons = getWeaponsFolder()
    if weapons then
        for weaponName, originalValue in pairs(FullAutoState.SavedAutoValues) do
            local weaponFolder = weapons:FindFirstChild(weaponName)
            if weaponFolder then
                local autoValue = weaponFolder:FindFirstChild("Auto")
                if autoValue and autoValue:IsA("BoolValue") then
                    autoValue.Value = originalValue
                end
            end
        end
    end
    table.clear(FullAutoState.SavedAutoValues)
end

updateFullAuto = function()
    local weapons = getWeaponsFolder()
    if not weapons then return end

    if Toggles.MiscFullAuto and Toggles.MiscFullAuto.Value then
        for _, weaponFolder in ipairs(weapons:GetChildren()) do
            local autoValue = weaponFolder:FindFirstChild("Auto")
            if autoValue and autoValue:IsA("BoolValue") then
                if FullAutoState.SavedAutoValues[weaponFolder.Name] == nil then
                    FullAutoState.SavedAutoValues[weaponFolder.Name] = autoValue.Value
                end
                autoValue.Value = true
            end
        end
    else
        for weaponName, originalValue in pairs(FullAutoState.SavedAutoValues) do
            local weaponFolder = weapons:FindFirstChild(weaponName)
            if weaponFolder then
                local autoValue = weaponFolder:FindFirstChild("Auto")
                if autoValue and autoValue:IsA("BoolValue") then
                    autoValue.Value = originalValue
                end
            end
            FullAutoState.SavedAutoValues[weaponName] = nil
        end
    end
end


updateRCS = function()
    local weapons = getWeaponsFolder()
    if not weapons then return end

    local rcsEnabled = Toggles.RCSEnable and Toggles.RCSEnable.Value
    local rcsValue = Options.RCSValue and Options.RCSValue.Value or 0

    for _, weaponFolder in ipairs(weapons:GetChildren()) do
        if not weaponFolder:IsA("Folder") then continue end
        local spread = weaponFolder:FindFirstChild("Spread")
        if not spread then continue end
        local recoil = spread:FindFirstChild("Recoil")
        if not recoil or not recoil:IsA("NumberValue") then continue end

        if rcsEnabled and rcsValue > 0 then
            if RCSOriginalValues[weaponFolder.Name] == nil then
                RCSOriginalValues[weaponFolder.Name] = recoil.Value
            end
            local original = RCSOriginalValues[weaponFolder.Name]
            local reductionPercent = rcsValue / 100
            local newValue = original * (1 - reductionPercent)
            recoil.Value = math.max(newValue, 1)
        else
            local original = RCSOriginalValues[weaponFolder.Name]
            if original ~= nil then
                recoil.Value = original
                RCSOriginalValues[weaponFolder.Name] = nil
            end
        end
    end
end


-- KillAll remote
local KillAllHitRemote = nil
for _, obj in pairs(ReplicatedStorage:GetDescendants()) do
    if obj:IsA("RemoteEvent") and obj.Name:lower():find("hit") then
        KillAllHitRemote = obj
        break
    end
end

local function updateKillAll()
    local autoEnabled = Toggles.ExploitKillAll and Toggles.ExploitKillAll.Value
    local keyActive = isKeybindActive(Options.ExploitKillAllKeybind)

    if not autoEnabled or not keyActive then return end

    local character = LocalPlayer.Character
    if not character then return end
    local humanoid = character:FindFirstChild("Humanoid")
    if not humanoid or humanoid.Health <= 0 then return end

    local gun = character:FindFirstChild("Gun")
    local equippedToolValue = character:FindFirstChild("EquippedTool")
    if not gun or not equippedToolValue then return end

    local gunName = "AWP"
    local gunRef = gun
    local replicatedStorageWeapons = getWeaponsFolder()
    local awpFolder = replicatedStorageWeapons and replicatedStorageWeapons:FindFirstChild("AWP")
    if awpFolder then gunRef = awpFolder end

    local cam = getCamera()
    if not cam then return end
    local camPos = cam.CFrame.p
    local serverTime = Workspace:GetServerTimeNow()
    local burstCount = 2
    local nanBypass = true

    for _, plr in pairs(Players:GetPlayers()) do
        if plr == LocalPlayer then continue end

        local myTeam = LocalPlayer.Team
        local theirTeam = plr.Team
        if myTeam ~= nil and theirTeam ~= nil and theirTeam == myTeam then continue end

        local playerCharacter = plr.Character
        if not playerCharacter then continue end

        local head = playerCharacter:FindFirstChild("Head") or playerCharacter:FindFirstChild("HeadHB")
        local playerHumanoid = playerCharacter:FindFirstChild("Humanoid")
        if not head or not playerHumanoid or playerHumanoid.Health <= 0 then continue end

        if not KillAllHitRemote then continue end

        for burst = 1, burstCount do
            pcall(function()
                local posArg = nanBypass and {X = 0/0, Y = 0/0, Z = 0/0} or {X = head.Position.X, Y = head.Position.Y, Z = head.Position.Z}
                KillAllHitRemote:FireServer(
                    head, posArg, gunName, 4096, gunRef, nil, 1, false, true,
                    camPos, serverTime, Vector3.new(0, 1, 0),
                    true, true, true, true, true,
                    nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil
                )
            end)
        end
    end
end




-- movement

local BhopState = { Conn = nil }
local LegitBhopState = { Conn = nil, JumpCount = 0, WasInAir = false, DefaultSpeed = 16 }
local AutoJumpConn = nil


updateBhop = function()
    if BhopState.Conn then
        BhopState.Conn:Disconnect()
        BhopState.Conn = nil
    end
    local character = LocalPlayer.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if humanoid then
        humanoid.WalkSpeed = CONSTANTS.DEFAULT_WALK_SPEED
    end
    if not (Toggles.BhopEnable and Toggles.BhopEnable.Value) then return end

    BhopState.Conn = RunService.RenderStepped:Connect(function()
        pcall(function()
            local char = LocalPlayer.Character
            if not char then return end
            local rootPart = char:FindFirstChild("HumanoidRootPart")
            local hum = char:FindFirstChildOfClass("Humanoid")
            if not (rootPart and hum) or hum.Health <= 0 then return end

            if UserInputService:IsKeyDown(Enum.KeyCode.Space) and hum.FloorMaterial ~= Enum.Material.Air then
                hum.Jump = true
            end

            local multiplier = Options.BhopMultiplier and Options.BhopMultiplier.Value or 1
            if not multiplier or multiplier <= 0 then multiplier = 1 end
            local targetSpeed = CONSTANTS.DEFAULT_WALK_SPEED * multiplier
            hum.WalkSpeed = targetSpeed

            local w = UserInputService:IsKeyDown(Enum.KeyCode.W)
            local s = UserInputService:IsKeyDown(Enum.KeyCode.S)
            local a = UserInputService:IsKeyDown(Enum.KeyCode.A)
            local d = UserInputService:IsKeyDown(Enum.KeyCode.D)

            local currentVel = rootPart.AssemblyLinearVelocity
            local cam = getCamera()
            if cam then
                local camLook = cam.CFrame.LookVector
                local camRight = cam.CFrame.RightVector
                local mx, mz = 0, 0
                if w then mx = mx + camLook.X; mz = mz + camLook.Z end
                if s then mx = mx - camLook.X; mz = mz - camLook.Z end
                if a then mx = mx - camRight.X; mz = mz - camRight.Z end
                if d then mx = mx + camRight.X; mz = mz + camRight.Z end
                local mag = math.sqrt(mx * mx + mz * mz)
                if mag > 0 then
                    local inv = targetSpeed / mag
                    rootPart.AssemblyLinearVelocity = Vector3.new(mx * inv, currentVel.Y, mz * inv)
                else
                    rootPart.AssemblyLinearVelocity = Vector3.new(0, currentVel.Y, 0)
                end
            end
        end)
    end)
end


updateLegitBhop = function()
    if LegitBhopState.Conn then
        LegitBhopState.Conn:Disconnect()
        LegitBhopState.Conn = nil
    end
    LegitBhopState.JumpCount = 0
    LegitBhopState.WasInAir = false
    local character = LocalPlayer.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if humanoid then
        humanoid.WalkSpeed = LegitBhopState.DefaultSpeed
    end
    if not (Toggles.LegitBhopEnable and Toggles.LegitBhopEnable.Value) then return end

    LegitBhopState.Conn = RunService.RenderStepped:Connect(function()
        pcall(function()
            local char = LocalPlayer.Character
            if not char then return end
            local hum = char:FindFirstChildOfClass("Humanoid")
            if not hum or hum.Health <= 0 then return end

            local inAir = hum.FloorMaterial == Enum.Material.Air

            if not inAir and LegitBhopState.WasInAir then
                if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
                    LegitBhopState.JumpCount = LegitBhopState.JumpCount + 1
                    hum.Jump = true
                else
                    LegitBhopState.JumpCount = 0
                end
            end

            LegitBhopState.WasInAir = inAir

            local maxMult = Options.LegitBhopMultiplier and Options.LegitBhopMultiplier.Value or 2
            local multiplier = 1 + (math.min(LegitBhopState.JumpCount, 5) / 5) * (maxMult - 1)
            local targetSpeed = LegitBhopState.DefaultSpeed * multiplier
            hum.WalkSpeed = targetSpeed

            local rootPart = char:FindFirstChild("HumanoidRootPart")
            if rootPart then
                local cam = getCamera()
                if cam then
                    local camLook = cam.CFrame.LookVector
                    local mx, mz = 0, 0
                    if UserInputService:IsKeyDown(Enum.KeyCode.W) then mx = mx + camLook.X; mz = mz + camLook.Z end
                    if UserInputService:IsKeyDown(Enum.KeyCode.S) then mx = mx - camLook.X; mz = mz - camLook.Z end
                    local currentVel = rootPart.AssemblyLinearVelocity
                    local mag = math.sqrt(mx * mx + mz * mz)
                    if mag > 0 then
                        local inv = targetSpeed / mag
                        local targetVel = Vector3.new(mx * inv, currentVel.Y, mz * inv)
                        rootPart.AssemblyLinearVelocity = currentVel:Lerp(targetVel, 0.15)
                    end
                end
            end
        end)
    end)
end


local function updateStrafe()
    if not Toggles.StrafeEnable or not Toggles.StrafeEnable.Value then return end
    if Toggles.BhopEnable and Toggles.BhopEnable.Value then return end

    local character = LocalPlayer.Character
    if not character then return end
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not (rootPart and humanoid) or humanoid.Health <= 0 then return end
    if humanoid.FloorMaterial == Enum.Material.Air then return end

    local cam = getCamera()
    if not cam then return end
    local camLook = cam.CFrame.LookVector
    local camRight = cam.CFrame.RightVector
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

    local cam = getCamera()
    if not cam then return end
    local camLook = cam.CFrame.LookVector
    local camRight = cam.CFrame.RightVector
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


updateThirdPerson = function()
    local thirdPersonEnabled = Toggles.ThirdPersonEnable and Toggles.ThirdPersonEnable.Value
    local isKeyActive = isKeybindActive(Options.ThirdPersonKeybind)

    local isThirdPersonActive = thirdPersonEnabled and isKeyActive
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


onAutoJumpChanged = function()
    if AutoJumpConn then
        AutoJumpConn:Disconnect()
        AutoJumpConn = nil
    end
    if not (Toggles.MiscAutoJump and Toggles.MiscAutoJump.Value) then return end

    AutoJumpConn = UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        if input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == Enum.KeyCode.Space then
            local character = LocalPlayer.Character
            local humanoid = character and character:FindFirstChildOfClass("Humanoid")
            if humanoid and humanoid.Health > 0 then
                humanoid.Jump = true
            end
        end
    end)
end




-- visuals

local HitChamsState = {
    ChamsFolder = nil,
    PlayerConns = {},
    ObservedPlayers = {},
}

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

local AmbienceSavedLighting = nil
local GrenadeHidden = false


local function hideDrawingSet(drawingSet, resetRect)
    if not drawingSet then return end

    drawingSet.Box.Visible = false
    drawingSet.BoxOutline.Visible = false
    drawingSet.BoxFill.Visible = false
    drawingSet.Name.Visible = false
    drawingSet.Weapon.Visible = false
    drawingSet.HealthBarOutline.Visible = false
    drawingSet.HealthBarFill.Visible = false
    drawingSet.HealthText.Visible = false
    for i = 1, 4 do drawingSet.CornerLines[i].Visible = false end

    if resetRect then
        drawingSet.Rect = nil
    end
end


local function removeDrawingSet(player)
    local drawingSet = EspRuntime.Drawings[player]
    if not drawingSet then return end

    for _, item in drawingSet do
        if type(item) == "userdata" and item.Remove then
            pcall(function() item.Visible = false; item:Remove() end)
        elseif type(item) == "table" then
            for _, subItem in ipairs(item) do
                if type(subItem) == "userdata" and subItem.Remove then
                    pcall(function() subItem.Visible = false; subItem:Remove() end)
                end
            end
        end
    end

    EspRuntime.Drawings[player] = nil
end


local function removeHighlight(player)
    local highlight = EspRuntime.Highlights[player]
    if not highlight then return end

    pcall(function() highlight:Destroy() end)
    EspRuntime.Highlights[player] = nil
end


local function getDrawingSet(player)
    local drawingSet = EspRuntime.Drawings[player]
    if drawingSet then return drawingSet end

    drawingSet = {
        Box = createSquare(1, Color3.fromRGB(255, 255, 255)),
        BoxOutline = createSquare(3, Color3.fromRGB(0, 0, 0)),
        BoxFill = createSquare(1, Color3.fromRGB(255, 255, 255)),
        Name = createText(13),
        Weapon = createText(13),
        Rect = nil,
        HealthBarOutline = createSquare(2, Color3.fromRGB(0, 0, 0)),
        HealthBarFill = createSquare(1, Color3.fromRGB(0, 255, 0)),
        HealthText = createText(13),
        CornerLines = {createLine(2, Color3.fromRGB(255,255,255)), createLine(2, Color3.fromRGB(255,255,255)), createLine(2, Color3.fromRGB(255,255,255)), createLine(2, Color3.fromRGB(255,255,255))},
    }
    drawingSet.BoxFill.Filled = true

    EspRuntime.Drawings[player] = drawingSet
    return drawingSet
end


local function updatePlayerChams(player, character)
    if player == LocalPlayer or not character then
        removeHighlight(player)
        return
    end

    local showChams = Toggles.ESPChams and Toggles.ESPChams.Value
    if not showChams then
        local highlight = EspRuntime.Highlights[player]
        if highlight then highlight.Enabled = false end
        return
    end

    local highlight = EspRuntime.Highlights[player]
    if not highlight then
        highlight = Instance.new("Highlight")
        highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        highlight.OutlineTransparency = 1
        EspRuntime.Highlights[player] = highlight
    end

    highlight.Adornee = character
    highlight.Parent = character
    highlight.FillColor = getOptionColor("ESPChamsColor", Color3.fromRGB(255, 255, 255))
    highlight.FillTransparency = getChamsTransparency()
    if Toggles.ESPChamsOutline and Toggles.ESPChamsOutline.Value then
        highlight.OutlineTransparency = 0
        highlight.OutlineColor = getOptionColor("ESPChamsOutlineColor", Color3.fromRGB(255, 255, 255))
    else
        highlight.OutlineTransparency = 1
    end
    highlight.Enabled = true
end


local function updatePlayerEsp(player)
    if not player or not player.Parent then return end

    if player == LocalPlayer then
        local drawingSet = EspRuntime.Drawings[player]
        if drawingSet then hideDrawingSet(drawingSet, true) end
        return
    end

    if not isAnyEspEnabled() then
        local drawingSet = EspRuntime.Drawings[player]
        if drawingSet then hideDrawingSet(drawingSet, true) end
        updatePlayerChams(player, nil)
        return
    end

    local drawingSet = getDrawingSet(player)

    if Toggles.ESPTeamCheck and Toggles.ESPTeamCheck.Value then
        local myTeam, theirTeam = LocalPlayer.Team, player.Team
        if myTeam ~= nil and theirTeam ~= nil and theirTeam == myTeam then
            hideDrawingSet(drawingSet, true)
            updatePlayerChams(player, nil)
            return
        end
    end

    local character, humanoid, rootPart = getCharacterParts(player)
    if not character then
        updatePlayerChams(player, nil)
        hideDrawingSet(drawingSet, true)
        return
    end

    local left, top, width, height = getCharacterScreenBox(character, humanoid, rootPart)
    if not left then
        hideDrawingSet(drawingSet, true)
        updatePlayerChams(player, nil)
        return
    end

    local rect = drawingSet.Rect
    if not rect then
        rect = {}
        drawingSet.Rect = rect
    end
    rect.Left = left; rect.Top = top; rect.Width = width; rect.Height = height

    local bottom = top + height
    local centerX = left + width * 0.5

    local showBox = Toggles.ESPBox and Toggles.ESPBox.Value
    local showName = Toggles.ESPName and Toggles.ESPName.Value
    local boxType = Options.ESPBoxType and Options.ESPBoxType.Value or "Full"
    local showBoxFill = Toggles.ESPBoxFill and Toggles.ESPBoxFill.Value

    local boxColor = getOptionColor("ESPBoxColor", Color3.fromRGB(255, 255, 255))
    local nameColor = getOptionColor("ESPNameColor", Color3.fromRGB(255, 255, 255))

    if boxType == "Corner" then
        drawingSet.Box.Visible = false
        drawingSet.BoxOutline.Visible = false
        local cornerLen = math.min(width, height) * 0.25
        local cl = cornerLen
        local tl = Vector2.new(left, top)
        local tr = Vector2.new(left + width, top)
        local bl = Vector2.new(left, top + height)
        local br = Vector2.new(left + width, top + height)
        drawingSet.CornerLines[1].From = tl; drawingSet.CornerLines[1].To = tl + Vector2.new(cl, 0)
        drawingSet.CornerLines[1].Color = boxColor; drawingSet.CornerLines[1].Visible = showBox
        drawingSet.CornerLines[2].From = tl; drawingSet.CornerLines[2].To = tl + Vector2.new(0, cl)
        drawingSet.CornerLines[2].Color = boxColor; drawingSet.CornerLines[2].Visible = showBox
        drawingSet.CornerLines[3].From = tr; drawingSet.CornerLines[3].To = tr + Vector2.new(-cl, 0)
        drawingSet.CornerLines[3].Color = boxColor; drawingSet.CornerLines[3].Visible = showBox
        drawingSet.CornerLines[4].From = tr; drawingSet.CornerLines[4].To = tr + Vector2.new(0, cl)
        drawingSet.CornerLines[4].Color = boxColor; drawingSet.CornerLines[4].Visible = showBox
    else
        for i = 1, 4 do drawingSet.CornerLines[i].Visible = false end
        drawingSet.BoxOutline.Visible = false

        drawingSet.Box.Position = Vector2.new(left, top)
        drawingSet.Box.Size = Vector2.new(width, height)
        drawingSet.Box.Color = boxColor
        drawingSet.Box.Visible = showBox
    end

    if showBoxFill then
        drawingSet.BoxFill.Position = Vector2.new(left, top)
        drawingSet.BoxFill.Size = Vector2.new(width, height)
        drawingSet.BoxFill.Color = getOptionColor("ESPBoxFillColor", Color3.fromRGB(255, 255, 255))
        local fillOpt = Options.ESPBoxFillColor
        local fillTrans = 1
        if fillOpt and fillOpt.Transparency then fillTrans = math.clamp(1 - fillOpt.Transparency, 0, 1) end
        drawingSet.BoxFill.Transparency = fillTrans
        drawingSet.BoxFill.Visible = true
    else
        drawingSet.BoxFill.Visible = false
    end

    drawingSet.Name.Text = player.Name
    drawingSet.Name.Position = Vector2.new(centerX, top - 15)
    drawingSet.Name.Color = nameColor
    drawingSet.Name.Visible = showName

    local showWeapon = Toggles.ESPWeapon and Toggles.ESPWeapon.Value
    local weaponColor = getOptionColor("ESPWeaponColor", Color3.fromRGB(255, 255, 255))
    local weaponName = ""
    if character and character:FindFirstChild("EquippedTool") then
        weaponName = tostring(character.EquippedTool.Value)
    end
    drawingSet.Weapon.Text = weaponName
    drawingSet.Weapon.Position = Vector2.new(centerX, bottom + 5)
    drawingSet.Weapon.Color = weaponColor
    drawingSet.Weapon.Visible = showWeapon and weaponName ~= ""

    local showHealthBar = Toggles.ESPHealthBar and Toggles.ESPHealthBar.Value
    if showHealthBar and humanoid then
        local hpPercent = math.clamp(humanoid.Health / humanoid.MaxHealth, 0, 1)
        local barWidth = 4
        local barHeight = height
        local barX = left - barWidth - 2
        local barY = top

        drawingSet.HealthBarOutline.Position = Vector2.new(barX, barY)
        drawingSet.HealthBarOutline.Size = Vector2.new(barWidth, barHeight)
        drawingSet.HealthBarOutline.Color = Color3.fromRGB(0, 0, 0)
        drawingSet.HealthBarOutline.Visible = true

        local fillHeight = barHeight * hpPercent
        local fillY = barY + (barHeight - fillHeight)
        drawingSet.HealthBarFill.Position = Vector2.new(barX + 1, fillY)
        drawingSet.HealthBarFill.Size = Vector2.new(barWidth - 2, fillHeight)
        drawingSet.HealthBarFill.Color = getOptionColor("ESPHealthBarColor", Color3.fromRGB(0, 255, 0))
        drawingSet.HealthBarFill.Filled = true
        drawingSet.HealthBarFill.Visible = true

        local hp = math.floor(humanoid.Health)
        if hp < 100 then
            drawingSet.HealthText.Text = tostring(hp)
            drawingSet.HealthText.Position = Vector2.new(barX - 8, barY)
            drawingSet.HealthText.Color = Color3.fromRGB(255, 255, 255)
            drawingSet.HealthText.Visible = true
        else
            drawingSet.HealthText.Visible = false
        end
    else
        drawingSet.HealthBarOutline.Visible = false
        drawingSet.HealthBarFill.Visible = false
        drawingSet.HealthText.Visible = false
    end

    updatePlayerChams(player, character)
end


local function updateItemEsp()
    if not Toggles.ESPItemESP or not Toggles.ESPItemESP.Value then
        for item, text in pairs(EspRuntime.ItemDrawings) do
            text.Visible = false
        end
        return
    end

    local debris = Workspace:FindFirstChild("Debris")
    if not debris then return end

    local itemColor = getOptionColor("ESPItemColor", Color3.fromRGB(255, 255, 255))
    local seenItems = {}

    for _, item in ipairs(debris:GetChildren()) do
        if ReplicatedStorage.Weapons:FindFirstChild(item.Name) then
            seenItems[item] = true
            local text = EspRuntime.ItemDrawings[item]
            if not text then
                text = Drawing.new("Text")
                text.Visible = false
                text.Center = true
                text.Outline = true
                text.Size = 13
                text.Font = Drawing.Fonts.Plex
                EspRuntime.ItemDrawings[item] = text
            end

            local screenPos = Camera:WorldToViewportPoint(item.Position)
            if screenPos.Z > 0 then
                text.Text = item.Name
                text.Position = Vector2.new(screenPos.X, screenPos.Y)
                text.Color = itemColor
                text.Visible = true
            else
                text.Visible = false
            end
        end
    end

    for item, text in pairs(EspRuntime.ItemDrawings) do
        if not seenItems[item] or not item.Parent then
            pcall(function() text.Visible = false; text:Remove() end)
            EspRuntime.ItemDrawings[item] = nil
        end
    end
end


local function updateFovCircle()
    if not Toggles.AimbotFOVCircle or not Toggles.AimbotFOVCircle.Value then
        for _, line in ipairs(AimRuntime.FovLines) do
            pcall(function() line.Visible = false end)
        end
        return
    end

    local cam = getCamera()
    if not cam then return end
    local viewport = cam.ViewportSize
    local centerX, centerY = viewport.X / 2, viewport.Y / 2
    local radius = getAimFovRadius()
    local lineCount = #AimRuntime.FovLines
    local color = getOptionColor("AimbotFOVColor", Color3.fromRGB(255, 255, 255))

    for i = 1, lineCount do
        local angle = (i - 1) * (math.pi * 2 / lineCount)
        local x1 = centerX + math.cos(angle) * radius
        local y1 = centerY + math.sin(angle) * radius
        local angle2 = i * (math.pi * 2 / lineCount)
        local x2 = centerX + math.cos(angle2) * radius
        local y2 = centerY + math.sin(angle2) * radius
        local line = AimRuntime.FovLines[i]
        pcall(function()
            line.From = Vector2.new(x1, y1)
            line.To = Vector2.new(x2, y2)
            line.Color = color
            line.Visible = true
        end)
    end
end


-- crosshair
local _crosshairCircle = nil
local _crosshairCreated = false

ensureCrosshair = function()
    if _crosshairCreated then return end
    local success, circle = pcall(Drawing.new, "Circle")
    if success and circle then
        circle.Visible = false
        circle.Radius = 3
        circle.Color = Color3.fromRGB(255, 255, 255)
        circle.Thickness = 1
        circle.NumSides = 12
        circle.Filled = false
        _crosshairCircle = circle
    end
    _crosshairCreated = true
end

updateCrosshair = function()
    ensureCrosshair()
    if not _crosshairCircle then return end

    local enabled = Toggles.MiscCenterDot and Toggles.MiscCenterDot.Value
    if not enabled then
        _crosshairCircle.Visible = false
        return
    end

    local cam = getCamera()
    if not cam then return end
    local viewport = cam.ViewportSize
    _crosshairCircle.Position = Vector2.new(viewport.X / 2, viewport.Y / 2)
    _crosshairCircle.Color = getOptionColor("MiscCenterDotColor", Color3.fromRGB(255, 255, 255))
    _crosshairCircle.Visible = true
end


-- hit chams
local function getHitChamsFolder()
    if HitChamsState.ChamsFolder and HitChamsState.ChamsFolder.Parent then
        return HitChamsState.ChamsFolder
    end
    local folder = Instance.new("Folder")
    folder.Name = "ValenokHitChams"
    folder.Parent = workspace
    HitChamsState.ChamsFolder = folder
    return folder
end

local function cleanupHitChams()
    if HitChamsState.ChamsFolder then
        pcall(function() HitChamsState.ChamsFolder:Destroy() end)
        HitChamsState.ChamsFolder = nil
    end
end

local function runHitChamsOptimized(character)
    if not Toggles.MiscHitChams or not Toggles.MiscHitChams.Value then return end
    if not character then return end

    local folder = getHitChamsFolder()
    local clones = folder:GetChildren()
    if #clones >= CONSTANTS.MAX_HIT_CHAMS_CLONES then
        for i = 1, #clones - CONSTANTS.MAX_HIT_CHAMS_CLONES + 1 do
            pcall(function() clones[i]:Destroy() end)
        end
    end

    local highlight = character:FindFirstChildOfClass("Highlight")
    if highlight then return end

    local newHighlight = Instance.new("Highlight")
    newHighlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    newHighlight.FillTransparency = 0.5
    newHighlight.FillColor = getOptionColor("MiscHitChamsColor", Color3.fromRGB(255, 0, 0))
    newHighlight.OutlineTransparency = 1
    newHighlight.Parent = character
    newHighlight.Adornee = character

    task.delay(0.5, function()
        pcall(function() newHighlight:Destroy() end)
    end)
end

local function observePlayerForHitChams(player)
    if HitChamsState.ObservedPlayers[player] then return end
    HitChamsState.ObservedPlayers[player] = true

    local function onCharacterAdded(character)
        local conns = {}
        local humanoid = character:WaitForChild("Humanoid", 5)
        if humanoid then
            table.insert(conns, humanoid.Died:Connect(function()
                if Toggles.MiscHitChams and Toggles.MiscHitChams.Value then
                    runHitChamsOptimized(character)
                end
            end))
        end
        HitChamsState.PlayerConns[player] = conns
    end

    if player.Character then
        task.spawn(onCharacterAdded, player.Character)
    end
    local charAddedConn = player.CharacterAdded:Connect(onCharacterAdded)
    table.insert(HitChamsState.PlayerConns[player] or {}, charAddedConn)
end

updateHitChams = function()
    if not Toggles.MiscHitChams or not Toggles.MiscHitChams.Value then
        cleanupHitChams()
        return
    end
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            observePlayerForHitChams(player)
        end
    end
end


-- ambience
local function updateAmbience()
    local lighting = game:GetService('Lighting')

    local customTime = Toggles.AmbienceCustomTime and Toggles.AmbienceCustomTime.Value
    local customSkybox = Toggles.AmbienceCustomSkybox and Toggles.AmbienceCustomSkybox.Value
    local noShadow = Toggles.AmbienceNoShadow and Toggles.AmbienceNoShadow.Value
    local brightnessVal = Options.AmbienceBrightness and Options.AmbienceBrightness.Value or 0
    local brightnessEnabled = brightnessVal ~= 0

    local anyEnabled = customTime or customSkybox or noShadow or brightnessEnabled

    if not anyEnabled then
        if AmbienceSavedLighting then
            pcall(function()
                lighting.ClockTime = AmbienceSavedLighting.ClockTime
                lighting.GlobalShadows = AmbienceSavedLighting.GlobalShadows
                lighting.Brightness = AmbienceSavedLighting.Brightness
                lighting.Ambient = AmbienceSavedLighting.Ambient
                lighting.OutdoorAmbient = AmbienceSavedLighting.OutdoorAmbient
                lighting.ColorShift_Bottom = AmbienceSavedLighting.ColorShift_Bottom
                lighting.ColorShift_Top = AmbienceSavedLighting.ColorShift_Top
                if AmbienceSavedLighting.Skybox and not AmbienceSavedLighting.Skybox.Parent then
                    AmbienceSavedLighting.Skybox.Parent = lighting
                end
            end)
            AmbienceSavedLighting = nil
        end
        return
    end

    if not AmbienceSavedLighting then
        AmbienceSavedLighting = {
            ClockTime = lighting.ClockTime,
            GlobalShadows = lighting.GlobalShadows,
            Brightness = lighting.Brightness,
            Ambient = lighting.Ambient,
            OutdoorAmbient = lighting.OutdoorAmbient,
            ColorShift_Bottom = lighting.ColorShift_Bottom,
            ColorShift_Top = lighting.ColorShift_Top,
            Skybox = lighting:FindFirstChildOfClass('Sky'),
        }
    end

    if customTime then
        lighting.ClockTime = Options.AmbienceTime and Options.AmbienceTime.Value or 12
    else
        lighting.ClockTime = AmbienceSavedLighting.ClockTime
    end

    if customSkybox then
        local existingSky = lighting:FindFirstChildOfClass('Sky')
        if existingSky then existingSky.Parent = nil end
        local skyColor = Options.AmbienceSkyboxColor and Options.AmbienceSkyboxColor.Value or Color3.fromRGB(0, 0, 0)
        lighting.Ambient = skyColor
        lighting.OutdoorAmbient = skyColor
        lighting.ColorShift_Bottom = skyColor
        lighting.ColorShift_Top = skyColor
    else
        if AmbienceSavedLighting.Skybox and not AmbienceSavedLighting.Skybox.Parent then
            AmbienceSavedLighting.Skybox.Parent = lighting
        end
        lighting.Ambient = AmbienceSavedLighting.Ambient
        lighting.OutdoorAmbient = AmbienceSavedLighting.OutdoorAmbient
        lighting.ColorShift_Bottom = AmbienceSavedLighting.ColorShift_Bottom
        lighting.ColorShift_Top = AmbienceSavedLighting.ColorShift_Top
    end

    if noShadow then
        lighting.GlobalShadows = false
    else
        lighting.GlobalShadows = AmbienceSavedLighting.GlobalShadows
    end

    if brightnessEnabled then
        lighting.Brightness = 2 + brightnessVal
    else
        lighting.Brightness = AmbienceSavedLighting.Brightness
    end
end


-- no scope
applyNoScope = function(enabled)
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

updateNoScope = function()
    if not Toggles.RemovalsNoScope or not Toggles.RemovalsNoScope.Value then
        applyNoScope(false)
        return
    end
    applyNoScope(true)
end


-- no flash
updateNoFlash = function()
    local blnd = LocalPlayer.PlayerGui and LocalPlayer.PlayerGui:FindFirstChild("Blnd")
    if blnd then
        blnd.Enabled = not (Toggles.RemovalsNoFlash and Toggles.RemovalsNoFlash.Value)
    end
end


-- no smoke
local _noSmokeConn = nil

setupNoSmoke = function()
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


-- grenade prediction
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

updateGrenadePrediction = function(dt)
    local cam = getCamera()
    if not cam then return end
    if not Toggles.GrenadesPrediction or not Toggles.GrenadesPrediction.Value then
        if not GrenadeHidden then
            for _, b in pairs(GrenadeRuntime.Beams) do b.Enabled = false end
            GrenadeRuntime.Sphere.Transparency = 1
            GrenadeHidden = true
        end
        return
    end

    if not isHoldingNade() or not (GrenadeRuntime.LmbDown or GrenadeRuntime.RmbDown) then
        if not GrenadeHidden then
            for _, b in pairs(GrenadeRuntime.Beams) do b.Enabled = false end
            GrenadeRuntime.Sphere.Transparency = 1
            GrenadeHidden = true
        end
        return
    end
    GrenadeHidden = false

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
    local params = CONSTANTS.GRENADE_PARAMS[nadeType] or CONSTANTS.GRENADE_PARAMS.default
    local maxBounces = params.maxBounces
    local bounceDamping = params.bounceDamping
    local velocity = cam.CFrame.LookVector * CONSTANTS.GRENADE_PARAMS.LOOK_SPEED + plrVel * CONSTANTS.GRENADE_PARAMS.PLR_FACTOR + Vector3.new(0, CONSTANTS.GRENADE_PARAMS.UP_BIAS, 0)
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

        local rayOk, ray = pcall(function() return workspace:Raycast(currentPos, nextPos - currentPos, rp) end)
        ray = rayOk and ray or nil
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




-- skin changer

local SC_Viewmodels = ReplicatedStorage:WaitForChild("Viewmodels", 10)
local SC_Skins = ReplicatedStorage:WaitForChild("Skins", 10)
local SC_Gloves = ReplicatedStorage:FindFirstChild("Gloves") or ReplicatedStorage:WaitForChild("Gloves", 10)
local SC_GloveModels = SC_Gloves and SC_Gloves:FindFirstChild("Models")
local SC_Models = nil
pcall(function() SC_Models = game:GetObjects("rbxassetid://7285197035")[1] end)
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
local SC_SavedGloveSkins = {}
local SC_skinFile = "Valenok/skins.json"
local HttpService = game:GetService("HttpService")

local function SC_SaveSkins()
    pcall(function()
        local data = { knife = SC_SavedKnifeSkins, weapon = SC_SavedWeaponSkins, glove = SC_SavedGloveSkins }
        writefile(SC_skinFile, HttpService:JSONEncode(data))
    end)
end

local function SC_LoadSkins()
    pcall(function()
        if isfile(SC_skinFile) then
            local data = HttpService:JSONDecode(readfile(SC_skinFile))
            SC_SavedKnifeSkins = data.knife or {}
            SC_SavedWeaponSkins = data.weapon or {}
            SC_SavedGloveSkins = data.glove or {}
        end
    end)
end
SC_LoadSkins()

local SC_AllGloveNames = {}
local SC_AllGloves = {}
if SC_Gloves then
    for _, fldr in pairs(SC_Gloves:GetChildren()) do
        if fldr:IsA("Folder") and fldr ~= SC_GloveModels and fldr.Name ~= "Racer" and fldr.Name ~= "Models" then
            table.insert(SC_AllGloveNames, fldr.Name)
        end
    end
    table.sort(SC_AllGloveNames, function(a, b) return a < b end)
    for _, gName in ipairs(SC_AllGloveNames) do
        SC_AllGloves[gName] = {"Default"}
        for _, modl in pairs(SC_Gloves[gName]:GetChildren()) do
            table.insert(SC_AllGloves[gName], modl.Name)
        end
    end
end

local SC_lastGlove = nil
local SC_lastGloveSkin = nil


local function SC_SwapKnifeModel(knifeName)
    if not SC_Viewmodels then return end
    if SC_swapping then return end
    if SC_currentKnife == knifeName then return end
    SC_swapping = true
    pcall(function()
        if SC_Viewmodels:FindFirstChild("v_CT Knife") then SC_Viewmodels:FindFirstChild("v_CT Knife"):Destroy() end
        if SC_Viewmodels:FindFirstChild("v_T Knife") then SC_Viewmodels:FindFirstChild("v_T Knife"):Destroy() end
    end)
    if knifeName == "CT Knife" or knifeName == "T Knife" then
        if SC_OriginalCTKnife then pcall(function() SC_OriginalCTKnife:Clone().Parent = SC_Viewmodels end) end
        if SC_OriginalTKnife then pcall(function() SC_OriginalTKnife:Clone().Parent = SC_Viewmodels end) end
    else
        local sourceVM = nil
        if SC_Viewmodels:FindFirstChild("v_" .. knifeName) then
            sourceVM = SC_Viewmodels:FindFirstChild("v_" .. knifeName)
        elseif SC_Models and SC_Models:FindFirstChild("Knives") then
            local km = SC_Models.Knives:FindFirstChild(knifeName)
            if km then sourceVM = km end
        end
        if sourceVM then
            local ct = sourceVM:Clone(); ct.Name = "v_CT Knife"; pcall(function() ct.Parent = SC_Viewmodels end)
            local tt = sourceVM:Clone(); tt.Name = "v_T Knife"; pcall(function() tt.Parent = SC_Viewmodels end)
        else
            if SC_OriginalCTKnife then pcall(function() SC_OriginalCTKnife:Clone().Parent = SC_Viewmodels end) end
            if SC_OriginalTKnife then pcall(function() SC_OriginalTKnife:Clone().Parent = SC_Viewmodels end) end
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
    local escName = targetPart.Name:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")
    for _, Data in next, SkinData:GetDescendants() do
        if wm and Data:IsDescendantOf(wm) then continue end
        local n = Data.Name:gsub("^#%s*", "")
        if n == targetPart.Name or string.match(n, "^" .. escName .. "%d*$") or (targetPart.Name == "Main" and (n == "Part1" or n == "Part")) then
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
            if n == targetPart.Name or string.match(n, "^" .. escName .. "%d*$") or (targetPart.Name == "Main" and (n == "Part1" or n == "Part")) then
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
    if not armsObj or not armsObj.Parent then return end
    if (gunname == "CT Knife" or gunname == "T Knife") and not SC_Skins:FindFirstChild(gunname) then gunname = "M9 Bayonet" end
    if not SC_Skins:FindFirstChild(gunname) then return end
    local SkinData = SC_Skins[gunname]:FindFirstChild(selectedSkin)
    if not SkinData or SkinData:FindFirstChild("Animated") then return end
    for _, targetPart in next, armsObj:GetDescendants() do
        if targetPart and targetPart.Parent then
            SC_applySkinToPart(targetPart, SkinData)
        end
    end
    local skinConn
    skinConn = armsObj.DescendantAdded:Connect(function(part)
        if part and part.Parent then pcall(SC_applySkinToPart, part, SkinData) end
    end)
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
            if not Client or Client.gun == "none" or typeof(Client.gun) ~= "Instance" then return end
            local isMelee = Client.gun:FindFirstChild("Melee")
            local gunname = Client.gun.Name
            if gunname:match("Grenade") or gunname:match("Flashbang") or gunname:match("Smoke") or gunname:match("Decoy") or gunname:match("Molotov") or gunname:match("Incendiary") or gunname:match("C4") then
                return
            end
            if Toggles.SkinGloveChanger and Toggles.SkinGloveChanger.Value then
                pcall(function()
                    if not SC_lastGlove or SC_lastGlove == "None" then return end
                    if not SC_GloveModels or not SC_GloveModels:FindFirstChild(SC_lastGlove) then return end
                    local Model
                    for _, v in pairs(obj:GetChildren()) do
                        if v:IsA("Model") and (v:FindFirstChild("Right Arm") or v:FindFirstChild("Left Arm")) then
                            Model = v
                        end
                    end
                    if not Model then return end
                    local RArm = Model:FindFirstChild("Right Arm")
                    local LArm = Model:FindFirstChild("Left Arm")
                    local gloveTexData = SC_Gloves:FindFirstChild(SC_lastGlove) and SC_Gloves[SC_lastGlove]:FindFirstChild(SC_lastGloveSkin or "Default")
                    local gloveTex = ""
                    if gloveTexData and gloveTexData:FindFirstChild("Textures") then
                        gloveTex = gloveTexData.Textures.TextureId or ""
                    end
                    if RArm and SC_GloveModels:FindFirstChild(SC_lastGlove) then
                        local RGlove = RArm:FindFirstChild("Glove") or RArm:FindFirstChild("RGlove")
                        if RGlove then RGlove:Destroy() end
                        local newRG = SC_GloveModels[SC_lastGlove].RGlove:Clone()
                        if newRG:FindFirstChild("Mesh") then
                            newRG.Mesh.TextureId = gloveTex
                        else
                            pcall(function() newRG.TextureID = gloveTex end)
                        end
                        newRG.Parent = RArm
                        newRG.Transparency = 0
                        pcall(function() newRG.Welded.Part0 = RArm end)
                    end
                    if LArm and SC_GloveModels:FindFirstChild(SC_lastGlove) then
                        local LGlove = LArm:FindFirstChild("Glove") or LArm:FindFirstChild("LGlove")
                        if LGlove then LGlove:Destroy() end
                        local newLG = SC_GloveModels[SC_lastGlove].LGlove:Clone()
                        if newLG:FindFirstChild("Mesh") then
                            newLG.Mesh.TextureId = gloveTex
                        else
                            pcall(function() newLG.TextureID = gloveTex end)
                        end
                        newLG.Transparency = 0
                        newLG.Parent = LArm
                        pcall(function() newLG.Welded.Part0 = LArm end)
                    end
                end)
            end
            if Toggles.SkinKnifeChanger and Toggles.SkinKnifeChanger.Value and isMelee then
                local wantedKnife = Options.SkinKnifeModel and Options.SkinKnifeModel.Value
                if wantedKnife and SC_currentKnife ~= wantedKnife then
                    SC_SwapKnifeModel(wantedKnife)
                    if obj and obj.Parent then obj:Destroy() end
                    return
                end
                task.spawn(function()
                    pcall(function()
                        if not obj or not obj.Parent then return end
                        local kn = wantedKnife or "M9 Bayonet"
                        if not SC_Skins:FindFirstChild(kn) then kn = "M9 Bayonet" end
                        SC_applySkinToArms(obj, kn, SC_SavedKnifeSkins[wantedKnife] or "Inventory")
                    end)
                end)
            elseif Toggles.SkinWeaponChanger and Toggles.SkinWeaponChanger.Value and not isMelee then
                task.spawn(function()
                    pcall(function()
                        if not obj or not obj.Parent then return end
                        SC_applySkinToArms(obj, gunname, SC_SavedWeaponSkins[gunname] or "Inventory")
                    end)
                end)
            end
        end)
    end)
end




-- ui

local Window = Library:CreateWindow({
    Title = 'Valenok',
    Center = true,
    AutoShow = true,
})

local Tabs = {
    Rage = Window:AddTab('Rage'),
    Legit = Window:AddTab('Legit'),
    Visual = Window:AddTab('Visual'),
    Skin = Window:AddTab('Skin'),
    Movement = Window:AddTab('Movement'),
    Config = Window:AddTab('Config'),
}

local RageSections = {
    Ragebot = Tabs.Rage:AddLeftGroupbox('Ragebot'),
    PeekAssist = Tabs.Rage:AddRightGroupbox('Peek assist'),
    AntiAim = Tabs.Rage:AddLeftGroupbox('Anti aim'),
    GunMods = Tabs.Rage:AddRightGroupbox('Gun mods'),
    Misc = Tabs.Rage:AddRightGroupbox('Misc'),
    Exploit = Tabs.Rage:AddRightGroupbox('Exploit'),
}

local LegitSections = {
    Aimbot = Tabs.Legit:AddLeftGroupbox('Aim bot'),
    Triggerbot = Tabs.Legit:AddRightGroupbox('Trigger bot'),
    RCS = Tabs.Legit:AddRightGroupbox('RCS'),
}

LegitSections.Aimbot:AddToggle('AimbotEnable', {Text = 'Enable', Default = false})
LegitSections.Aimbot:AddLabel('Keybind'):AddKeyPicker('AimbotKeybind', {Default = 'None', Mode = 'Hold', Text = 'Aimbot'})
LegitSections.Aimbot:AddToggle('AimbotVisibleCheck', {Text = 'Visible check', Default = false})
LegitSections.Aimbot:AddToggle('AimbotTeamCheck', {Text = 'Team check', Default = false})
LegitSections.Aimbot:AddToggle('AimbotShowFOV', {Text = 'Show FOV', Default = false})
LegitSections.Aimbot:AddDropdown('AimbotHitbox', {Values = { 'Head', 'Body', 'Nearest' }, Default = 'Head', Text = 'Hit box'})
LegitSections.Aimbot:AddToggle('AimbotBaim', {Text = 'Baim', Default = false})
LegitSections.Aimbot:AddLabel('Baim keybind'):AddKeyPicker('AimbotBaimKeybind', {Default = 'None', Mode = 'Toggle', Text = 'Baim'})
LegitSections.Aimbot:AddSlider('AimbotFOV', {Text = 'FOV', Default = 45, Min = 1, Max = 180, Rounding = 0})
LegitSections.Aimbot:AddSlider('AimbotSmooth', {Text = 'Smooth', Default = 4, Min = 1, Max = 10, Rounding = 0})

LegitSections.Triggerbot:AddToggle('TriggerbotEnable', {Text = 'Enable', Default = false})
LegitSections.Triggerbot:AddToggle('TriggerbotTeamCheck', {Text = 'Team check', Default = false})
LegitSections.Triggerbot:AddToggle('TriggerbotOnStopOnly', {Text = 'On stop only', Default = false})
LegitSections.Triggerbot:AddToggle('TriggerbotSmokeCheck', {Text = 'Smoke check', Default = false})
LegitSections.Triggerbot:AddToggle('TriggerbotJumpCheck', {Text = 'Jump check', Default = false})
LegitSections.Triggerbot:AddToggle('TriggerbotMagnet', {Text = 'Magnet', Default = false})
LegitSections.Triggerbot:AddSlider('TriggerbotDelay', {Text = 'Trigger bot delay', Default = 0, Min = 0, Max = 300, Rounding = 0})
LegitSections.Triggerbot:AddLabel('Keybind'):AddKeyPicker('TriggerbotKeybind', {Default = 'None', Mode = 'Toggle', Text = 'Trigger bot'})

LegitSections.RCS:AddToggle('RCSEnable', {Text = 'Enable', Default = false, Callback = function() updateRCS() end})
LegitSections.RCS:AddSlider('RCSValue', {Text = 'RCS', Default = 0, Min = 0, Max = 100, Rounding = 0, Callback = function() updateRCS() end})

local VisualSections = {
    ESP = Tabs.Visual:AddLeftGroupbox('ESP'),
    ThirdPerson = Tabs.Visual:AddLeftGroupbox('Third person'),
    Menu = Tabs.Visual:AddLeftGroupbox('Menu'),
    Removals = Tabs.Visual:AddRightGroupbox('Removals'),
    Grenades = Tabs.Visual:AddRightGroupbox('Grenades'),
    Ambience = Tabs.Visual:AddRightGroupbox('Ambience'),
    Self = Tabs.Visual:AddRightGroupbox('Self'),
    Misc = Tabs.Visual:AddLeftGroupbox('Misc'),
}

local SkinSections = {
    Knife = Tabs.Skin:AddLeftGroupbox('Knife Changer'),
    Weapon = Tabs.Skin:AddRightGroupbox('Weapon Skins'),
    Glove = Tabs.Skin:AddRightGroupbox('Glove Changer'),
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
    if kn and sk then SC_SavedKnifeSkins[kn] = sk; SC_SaveSkins() end
end})
SkinSections.Weapon:AddToggle('SkinWeaponChanger', {Text = 'Enable', Default = false})
local _SC_prevWeapon = SC_AllWeapons[1]
SkinSections.Weapon:AddDropdown('SkinWeaponModel', {Text = 'Weapon', Values = #SC_AllWeapons > 0 and SC_AllWeapons or {"AK-47"}, Default = SC_AllWeapons[1] or "AK-47", Callback = function()
    local weaponName = Options.SkinWeaponModel and Options.SkinWeaponModel.Value
    if _SC_prevWeapon and _SC_prevWeapon ~= weaponName then
        local curSkin = Options.SkinWeaponSkin and Options.SkinWeaponSkin.Value
        if curSkin then SC_SavedWeaponSkins[_SC_prevWeapon] = curSkin; SC_SaveSkins() end
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
    if wn and sk then SC_SavedWeaponSkins[wn] = sk; SC_SaveSkins() end
end})
SkinSections.Glove:AddToggle('SkinGloveChanger', {Text = 'Enable', Default = false})
if #SC_AllGloveNames > 0 then
    SkinSections.Glove:AddDropdown('SkinGloveModel', {Text = 'Glove', Values = SC_AllGloveNames, Default = SC_AllGloveNames[1], Callback = function()
        local gloveName = Options.SkinGloveModel and Options.SkinGloveModel.Value
        if gloveName then
            local skins = SC_AllGloves[gloveName] or {"Default"}
            Options.SkinGloveSkin.Values = skins
            Options.SkinGloveSkin:SetValues()
            Options.SkinGloveSkin:SetValue(SC_SavedGloveSkins[gloveName] or skins[1])
            SC_lastGlove = gloveName
            SC_lastGloveSkin = SC_SavedGloveSkins[gloveName] or skins[1]
        end
    end})
    SkinSections.Glove:AddDropdown('SkinGloveSkin', {Text = 'Glove Skin', Values = SC_AllGloves[SC_AllGloveNames[1]] or {"Default"}, Default = "Default", Callback = function()
        SC_lastGlove = Options.SkinGloveModel and Options.SkinGloveModel.Value
        SC_lastGloveSkin = Options.SkinGloveSkin and Options.SkinGloveSkin.Value
        if SC_lastGlove and SC_lastGloveSkin then
            SC_SavedGloveSkins[SC_lastGlove] = SC_lastGloveSkin
            SC_SaveSkins()
        end
    end})
end
SkinSections.Knife:AddButton('Random Skin', function()
    for _, knifeName in ipairs(SC_AllKnives) do
        local skins = SC_KnifeSkins[knifeName]
        if skins and #skins > 0 then
            SC_SavedKnifeSkins[knifeName] = skins[math.random(1, #skins)]
        end
    end
    SC_SaveSkins()
    local curKnife = Options.SkinKnifeModel and Options.SkinKnifeModel.Value
    if curKnife and SC_KnifeSkins[curKnife] then
        Options.SkinKnifeSkin:SetValue(SC_SavedKnifeSkins[curKnife] or "Inventory")
    end
end)
SkinSections.Weapon:AddButton('Random Skin', function()
    for _, weaponName in ipairs(SC_AllWeapons) do
        local skins = SC_AllSkins[weaponName]
        if skins and #skins > 0 then
            SC_SavedWeaponSkins[weaponName] = skins[math.random(1, #skins)]
        end
    end
    SC_SaveSkins()
    local curWeapon = Options.SkinWeaponModel and Options.SkinWeaponModel.Value
    if curWeapon and SC_AllSkins[curWeapon] then
        Options.SkinWeaponSkin:SetValue(SC_SavedWeaponSkins[curWeapon] or "Inventory")
    end
end)
SkinSections.Glove:AddButton('Random Skin', function()
    for _, gloveName in ipairs(SC_AllGloveNames) do
        local skins = SC_AllGloves[gloveName]
        if skins and #skins > 0 then
            SC_SavedGloveSkins[gloveName] = skins[math.random(1, #skins)]
        end
    end
    SC_SaveSkins()
    local curGlove = Options.SkinGloveModel and Options.SkinGloveModel.Value
    if curGlove and SC_AllGloves[curGlove] then
        Options.SkinGloveSkin:SetValue(SC_SavedGloveSkins[curGlove] or "Default")
        SC_lastGlove = curGlove
        SC_lastGloveSkin = SC_SavedGloveSkins[curGlove]
    end
end)
SC_setupArmsWatcher()
do
    local defaultKnife = "Butterfly Knife"
    local ks = SC_KnifeSkins[defaultKnife] or {"Inventory"}
    Options.SkinKnifeSkin.Values = ks
    Options.SkinKnifeSkin:SetValues()
    Options.SkinKnifeSkin:SetValue(SC_SavedKnifeSkins[defaultKnife] or "Inventory")
    if #SC_AllWeapons > 0 then
        local firstWeapon = SC_AllWeapons[1]
        local ws = SC_AllSkins[firstWeapon] or {"Inventory"}
        Options.SkinWeaponSkin.Values = ws
        Options.SkinWeaponSkin:SetValues()
        Options.SkinWeaponSkin:SetValue(SC_SavedWeaponSkins[firstWeapon] or "Inventory")
    end
end

local MovementSections = {
    Bhop = Tabs.Movement:AddLeftGroupbox('Bhop'),
    Strafe = Tabs.Movement:AddLeftGroupbox('Strafe'),
    LegitBhop = Tabs.Movement:AddRightGroupbox('Legit Bhop'),
}
MovementSections.LegitBhop:AddToggle('LegitBhopEnable', {Text = 'Enable', Default = false, Callback = function() updateLegitBhop() end})
MovementSections.LegitBhop:AddSlider('LegitBhopMultiplier', {Text = 'Multiplier', Default = 2, Min = 1, Max = 3, Rounding = 1})
MovementSections.Bhop:AddToggle('BhopEnable', {Text = 'Enable', Default = false, Callback = function() updateBhop() end})
MovementSections.Bhop:AddSlider('BhopMultiplier', {Text = 'Bhop multiplier', Default = 1, Min = 1, Max = 5, Rounding = 2})
MovementSections.Bhop:AddToggle('BhopAutoJump', {Text = 'Auto jump', Default = false, Callback = function()
    if AutoJumpConn then AutoJumpConn:Disconnect(); AutoJumpConn = nil end
    if not (Toggles.BhopAutoJump and Toggles.BhopAutoJump.Value) then return end
    AutoJumpConn = RunService.RenderStepped:Connect(function()
        if not (Toggles.BhopAutoJump and Toggles.BhopAutoJump.Value) then return end
        if not UserInputService:IsKeyDown(Enum.KeyCode.Space) then return end
        local character = LocalPlayer.Character
        if not character then return end
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        if not humanoid or humanoid.Health <= 0 then return end
        if humanoid.FloorMaterial ~= Enum.Material.Air then
            humanoid.Jump = true
        end
    end)
end})
MovementSections.Strafe:AddToggle('StrafeEnable', {Text = 'Strafe', Default = false})
MovementSections.Strafe:AddToggle('AirStrafeEnable', {Text = 'Air strafe', Default = false})

RageSections.Ragebot:AddToggle('RagebotEnable', {Text = 'Enable', Default = false})
RageSections.Ragebot:AddLabel('Keybind'):AddKeyPicker('RagebotKeybind', {Default = 'None', Mode = 'Hold', Text = 'Ragebot'})
RageSections.Ragebot:AddToggle('RagebotAutoFire', {Text = 'Automatic fire', Default = false})
RageSections.Ragebot:AddToggle('RagebotTeamCheck', {Text = 'Team check', Default = false})
RageSections.Ragebot:AddToggle('RagebotVisCheck', {Text = 'Vis check', Default = false})
RageSections.Ragebot:AddToggle('RagebotCameraResolver', {Text = 'Camera resolver', Default = false})
RageSections.Ragebot:AddToggle('RagebotShowFOV', {Text = 'Show FOV', Default = false})
RageSections.Ragebot:AddSlider('RagebotFOV', {Text = 'FOV', Default = 1, Min = 1, Max = 180, Rounding = 0})
RageSections.Ragebot:AddDropdown('RagebotHitbox', {Values = { 'Head', 'Body', 'Nearest' }, Default = 'Head', Text = 'Hit box'})
RageSections.Ragebot:AddToggle('RagebotBaim', {Text = 'Baim', Default = false})
RageSections.Ragebot:AddLabel('Baim keybind'):AddKeyPicker('RagebotBaimKeybind', {Default = 'None', Mode = 'Toggle', Text = 'Baim'})

RageSections.PeekAssist:AddToggle('PeekAssistEnable', {Text = 'Enable', Default = false})
RageSections.PeekAssist:AddLabel('Keybind'):AddKeyPicker('PeekAssistKeybind', {Default = 'None', Mode = 'Hold', Text = 'Peek Assist'})
RageSections.PeekAssist:AddDropdown('PeekAssistRetreatMode', {Values = { 'On Key', 'On Shot' }, Default = 'On Key', Text = 'Retreat Mode'})

RageSections.AntiAim:AddToggle('AntiAimEnable', {Text = 'Enable', Default = false})
RageSections.AntiAim:AddToggle('AntiAimPitch', {Text = 'Pitch', Default = false})
RageSections.AntiAim:AddDropdown('AntiAimPitchMode', {Values = { 'None', 'Up', 'Down', 'Random' }, Default = 'None', Text = 'Pitch mode'})
RageSections.AntiAim:AddToggle('AntiAimYaw', {Text = 'Yaw', Default = false})
RageSections.AntiAim:AddDropdown('AntiAimYawMode', {Values = { 'Local', 'At target', 'Random' }, Default = 'Local', Text = 'Yaw mode'})
RageSections.AntiAim:AddSlider('AntiAimYawValue', {Text = 'Yaw value', Default = 0, Min = -180, Max = 180, Rounding = 0})

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
RageSections.GunMods:AddToggle('GunModsNoSpread', {Text = 'No spread', Default = false, Callback = function(Value)
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
RageSections.GunMods:AddToggle('GunModsRapidFire', {Text = 'Rapid fire', Default = false, Callback = function(Value) if not Value then restoreAllRapidFireRates() else updateRapidFire() end end})
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

VisualSections.Misc:AddToggle('MiscBulletTracer', {Text = 'Bullet tracer', Default = false})
VisualSections.Misc:AddDropdown('MiscBulletTracerTexture', {
    Text = 'Tracer texture',
    Values = {"Solid","Lightning","Laser","Twisted Energy","Anime Lazer","Arrow","Minecraft","Alien Energy Ray","Energy Ray","Matrix","Cartoony Eletric"},
    Default = "Laser",
})
VisualSections.Misc:AddToggle('MiscHitSound', {Text = 'Hit sound', Default = false})
VisualSections.Misc:AddDropdown('MiscHitSoundType', {Values = { 'Skeet', 'Neverlose', 'Bameware', 'Bell', 'Bubble', 'Pick', 'Pop', 'Rust', 'Sans', 'Fart', 'Big', 'Vine', 'Bruh', 'Fatality', 'Bonk', 'Minecraft', 'Moan' }, Default = 'Skeet', Text = 'Hit sound type'})
VisualSections.Misc:AddSlider('MiscHitSoundVolume', {Text = 'Volume', Default = 5, Min = 1, Max = 10, Rounding = 0})
VisualSections.Misc:AddToggle('MiscHitChams', {Text = 'Hit chams', Default = false})
VisualSections.Misc:AddToggle('MiscHitMarker', {Text = 'Hit marker', Default = false})
VisualSections.Misc:AddSlider('MiscHitMarkerLifetime', {Text = 'Hit marker lifetime', Default = 3, Min = 1, Max = 10, Rounding = 0})
VisualSections.Misc:AddLabel('Bullet tracer color'):AddColorPicker('MiscBulletTracerColor', {Default = Color3.fromRGB(255, 0, 0), Title = 'Bullet tracer color'})
VisualSections.Misc:AddLabel('Hit chams color'):AddColorPicker('MiscHitChamsColor', {Default = Color3.fromRGB(255, 0, 0), Title = 'Hit chams color'})
VisualSections.Misc:AddLabel('Hit marker color'):AddColorPicker('MiscHitMarkerColor', {Default = Color3.fromRGB(255, 255, 255), Title = 'Hit marker color'})
VisualSections.Misc:AddToggle('MiscCustomCrosshair', {Text = 'Custom crosshair', Default = false})
VisualSections.Misc:AddToggle('MiscHideCrosshair', {Text = 'Hide game crosshair', Default = false})
VisualSections.Misc:AddSlider('MiscCrosshairGap', {Text = 'Crosshair gap', Default = 6, Min = 1, Max = 20, Rounding = 0})
VisualSections.Misc:AddSlider('MiscCrosshairSize', {Text = 'Crosshair dot size', Default = 2, Min = 1, Max = 5, Rounding = 0})
VisualSections.Misc:AddLabel('Crosshair color'):AddColorPicker('MiscCrosshairColor', {Default = Color3.fromRGB(255, 255, 255), Title = 'Crosshair color'})

RageSections.Misc:AddToggle('MiscFullAuto', {Text = 'Full auto', Default = false, Callback = function() updateFullAuto() end})

RageSections.Exploit:AddToggle('ExploitKillAll', {Text = 'Kill all', Default = false})
RageSections.Exploit:AddLabel('Keybind'):AddKeyPicker('ExploitKillAllKeybind', {Default = 'None', Mode = 'Hold', Text = 'Kill All'})
RageSections.Exploit:AddToggle('ExploitNoFallDamage', {Text = 'No fall damage', Default = false})

VisualSections.ESP:AddToggle('ESPEnable', {Text = 'Enable', Default = false})
VisualSections.ESP:AddToggle('ESPTeamCheck', {Text = 'Team check', Default = false})
VisualSections.ESP:AddToggle('ESPBox', {Text = 'Box', Default = false})
VisualSections.ESP:AddDropdown('ESPBoxType', {Values = {'Full', 'Corner'}, Default = 'Full', Text = 'Box type'})
VisualSections.ESP:AddToggle('ESPBoxFill', {Text = 'Box fill', Default = false})
VisualSections.ESP:AddToggle('ESPItemESP', {Text = 'Item ESP', Default = false})
VisualSections.ESP:AddToggle('ESPName', {Text = 'Name', Default = false})
VisualSections.ESP:AddToggle('ESPHealthBar', {Text = 'Health bar', Default = false})
VisualSections.ESP:AddToggle('ESPWeapon', {Text = 'Weapon ESP', Default = false})
VisualSections.ESP:AddToggle('ESPChams', {Text = 'Chams', Default = false})
VisualSections.ESP:AddToggle('ESPChamsOutline', {Text = 'Chams outline', Default = false})
VisualSections.ESP:AddLabel('Chams outline color'):AddColorPicker('ESPChamsOutlineColor', {Default = Color3.fromRGB(255, 255, 255), Title = 'Chams outline color'})
VisualSections.ESP:AddDropdown('ESPFont', {Values = { 'UI', 'System', 'Plex', 'Monospace' }, Default = 'Plex', Text = 'Font'})
VisualSections.ESP:AddSlider('ESPChamsTransparency', {Text = 'Chams transparency', Default = 35, Min = 0, Max = 100, Rounding = 0})
VisualSections.ESP:AddLabel('Box color'):AddColorPicker('ESPBoxColor', {Default = Color3.fromRGB(255, 255, 255), Title = 'Box color'})
VisualSections.ESP:AddLabel('Name color'):AddColorPicker('ESPNameColor', {Default = Color3.fromRGB(255, 255, 255), Title = 'Name color'})
VisualSections.ESP:AddLabel('Weapon color'):AddColorPicker('ESPWeaponColor', {Default = Color3.fromRGB(255, 255, 255), Title = 'Weapon color'})
VisualSections.ESP:AddLabel('Chams color'):AddColorPicker('ESPChamsColor', {Default = Color3.fromRGB(255, 255, 255), Title = 'Chams color'})
VisualSections.ESP:AddLabel('Health bar color'):AddColorPicker('ESPHealthBarColor', {Default = Color3.fromRGB(0, 255, 0), Title = 'Health bar color'})
VisualSections.ESP:AddLabel('Box fill color'):AddColorPicker('ESPBoxFillColor', {Default = Color3.fromRGB(255, 255, 255), Transparency = 0.5, Title = 'Box fill color'})
VisualSections.ESP:AddLabel('Item color'):AddColorPicker('ESPItemColor', {Default = Color3.fromRGB(255, 255, 255), Title = 'Item color'})

VisualSections.Menu:AddToggle('MenuBindList', {Text = 'Bind list', Default = true, Callback = function(Value) if Library.KeybindFrame then Library.KeybindFrame.Visible = Value end end})
VisualSections.Menu:AddToggle('MenuWatermark', {Text = 'Watermark', Default = true, Callback = function(Value) Library:SetWatermarkVisibility(Value) end})

VisualSections.Removals:AddToggle('RemovalsNoSmoke', {Text = 'No smoke', Default = false})
VisualSections.Removals:AddToggle('RemovalsNoFlash', {Text = 'No flash', Default = false, Callback = function() updateNoFlash() end})
VisualSections.Removals:AddToggle('RemovalsNoScope', {Text = 'No scope', Default = false, Callback = function() updateNoScope() end})

VisualSections.Grenades:AddToggle('GrenadesPrediction', {Text = 'Grenade prediction', Default = false})
VisualSections.Grenades:AddLabel('Prediction color'):AddColorPicker('GrenadesPredictionColor', {Default = Color3.fromRGB(255, 0, 0), Title = 'Prediction color'})

VisualSections.ThirdPerson:AddToggle('ThirdPersonEnable', {Text = 'Enable', Default = false})
VisualSections.ThirdPerson:AddLabel('Keybind'):AddKeyPicker('ThirdPersonKeybind', {Default = 'None', Mode = 'Toggle', Text = 'Third person'})
VisualSections.ThirdPerson:AddSlider('ThirdPersonDistance', {Text = 'Distance', Default = 5, Min = 1, Max = 10, Rounding = 0})

VisualSections.Ambience:AddToggle('AmbienceCustomTime', {Text = 'Custom time', Default = false})
VisualSections.Ambience:AddSlider('AmbienceTime', {Text = 'Time', Default = 12, Min = 0, Max = 24, Rounding = 1})
VisualSections.Ambience:AddToggle('AmbienceCustomSkybox', {Text = 'Custom skybox', Default = false})
VisualSections.Ambience:AddLabel('Skybox color'):AddColorPicker('AmbienceSkyboxColor', {Default = Color3.fromRGB(0, 0, 0), Title = 'Skybox color'})
VisualSections.Ambience:AddToggle('AmbienceNoShadow', {Text = 'No shadow', Default = false})
VisualSections.Ambience:AddSlider('AmbienceBrightness', {Text = 'Brightness', Default = 0, Min = -10, Max = 10, Rounding = 1})

VisualSections.Self:AddToggle('SelfFOVEnable', {Text = 'FOV', Default = false})
VisualSections.Self:AddSlider('SelfFOV', {Text = 'FOV value', Default = 70, Min = 30, Max = 120, Rounding = 0})

ThemeManager:SetLibrary(Library)
SaveManager:SetLibrary(Library)
SaveManager:IgnoreThemeSettings()
ThemeManager:SetFolder('Valenok')
SaveManager:SetFolder('Valenok')


-- hooks & ecosystem

-- custom crosshair
do
    local _chCenter = nil
    local _chDots = {}
    local _chCreated = false

    local function ensureCustomCrosshair()
        if _chCreated then return end
        local ok1, c = pcall(Drawing.new, "Circle")
        if ok1 and c then
            c.Filled = true
            c.Visible = false
            _chCenter = c
        end
        for i = 1, 4 do
            local ok, d = pcall(Drawing.new, "Circle")
            if ok and d then
                d.Filled = true
                d.Visible = false
                _chDots[i] = d
            end
        end
        _chCreated = true
    end

    local function updateCustomCrosshair()
        ensureCustomCrosshair()
        local enabled = Toggles.MiscCustomCrosshair and Toggles.MiscCustomCrosshair.Value
        if not enabled then
            if _chCenter then pcall(function() _chCenter.Visible = false end) end
            for _, d in ipairs(_chDots) do
                if d then pcall(function() d.Visible = false end) end
            end
            return
        end
        local cam = nil
        pcall(function() cam = getCamera() end)
        if not cam then return end
        local vp = cam.ViewportSize
        if not vp then return end
        local cx, cy = vp.X / 2, vp.Y / 2
        local col = Color3.fromRGB(255, 255, 255)
        pcall(function() col = Options.MiscCrosshairColor.Value end)
        local gap = 6
        pcall(function() gap = Options.MiscCrosshairGap.Value end)
        local sz = 2
        pcall(function() sz = Options.MiscCrosshairSize.Value end)
        if _chCenter then
            pcall(function()
                _chCenter.Position = Vector2.new(cx, cy)
                _chCenter.Radius = sz
                _chCenter.Color = col
                _chCenter.Transparency = 1
                _chCenter.Visible = true
            end)
        end
        local positions = {
            Vector2.new(cx, cy - gap),
            Vector2.new(cx, cy + gap),
            Vector2.new(cx - gap, cy),
            Vector2.new(cx + gap, cy),
        }
        for i, pos in ipairs(positions) do
            if _chDots[i] then
                pcall(function()
                    _chDots[i].Position = pos
                    _chDots[i].Radius = sz
                    _chDots[i].Color = col
                    _chDots[i].Transparency = 1
                    _chDots[i].Visible = true
                end)
            end
        end
    end

    task.spawn(function()
        while task.wait(0.03) do
            pcall(updateCustomCrosshair)
            if Toggles.MiscHideCrosshair and Toggles.MiscHideCrosshair.Value then
                pcall(function()
                    local gui = LocalPlayer.PlayerGui:FindFirstChild("GUI")
                    if gui then
                        local ch = gui:FindFirstChild("Crosshairs")
                        if ch then
                            for _, frameName in ipairs({"Frame1", "Frame2", "Frame3", "Frame4"}) do
                                local f = ch:FindFirstChild(frameName)
                                if f then f.Transparency = 1 end
                            end
                        end
                    end
                end)
            end
        end
    end)
end


-- namecall hook
local _oldNamecall = nil

local function restoreNamecallHook()
    pcall(function()
        if _oldNamecall then
            hookmetamethod(game, "__namecall", _oldNamecall)
            _oldNamecall = nil
        end
    end)
end


getgenv().ValenokPitchDownEnabled = false
getgenv().ValenokPitchValue = 0
getgenv().LastControlTurnArgs = {0, false}
getgenv().LastRandomPitch = 0
getgenv().LastPitchUpdate = 0
getgenv().LastSentPitch = nil

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
                pcall(function()
                    if Toggles.MiscHitSound and Toggles.MiscHitSound.Value then
                        PlayHitSound()
                    end
                end)
                pcall(function()
                    if Toggles.MiscHitMarker and Toggles.MiscHitMarker.Value then
                        ShowHitMarker()
                    end
                end)
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
                    pcall(function()
                        if Toggles.MiscHitSound and Toggles.MiscHitSound.Value then
                            PlayHitSound()
                        end
                    end)
                    pcall(function()
                        if Toggles.MiscHitMarker and Toggles.MiscHitMarker.Value then
                            ShowHitMarker()
                        end
                    end)
                end
                oldDamage = newVal
            end)
        end
    end
end)


-- FOV circle init
if getgenv().ValenokFovLines then
    for _, ln in ipairs(getgenv().ValenokFovLines) do
        pcall(function() ln.Visible = false; ln:Remove() end)
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


_hitSoundObj = Instance.new("Sound")
_hitSoundObj.Parent = workspace


-- unload
unloadValenok = function()
    restoreNamecallHook()
    getgenv().PSilentTargetPos = nil

    for _, Line in ipairs(AimRuntime.FovLines) do
        pcall(function() Line.Visible = false; Line:Remove() end)
    end
    table.clear(AimRuntime.FovLines)

    applyNoScope(false)

    local blnd = LocalPlayer.PlayerGui and LocalPlayer.PlayerGui:FindFirstChild("Blnd")
    if blnd then blnd.Enabled = true end

    for Player, DrawingSet in pairs(EspRuntime.Drawings) do
        for _, Item in DrawingSet do
            if type(Item) == "userdata" and Item.Remove then
                pcall(function() Item.Visible = false; Item:Remove() end)
            elseif type(Item) == "table" then
                for _, SubItem in ipairs(Item) do
                    if type(SubItem) == "userdata" and SubItem.Remove then
                        pcall(function() SubItem.Visible = false; SubItem:Remove() end)
                    end
                end
            end
        end
        EspRuntime.Drawings[Player] = nil
    end

    for item, text in pairs(EspRuntime.ItemDrawings) do
        pcall(function() text.Visible = false; text:Remove() end)
    end
    EspRuntime.ItemDrawings = {}

    for Player, Highlight in pairs(EspRuntime.Highlights) do
        pcall(function() Highlight:Destroy() end)
        EspRuntime.Highlights[Player] = nil
    end

    for _, Connection in pairs(EspRuntime.Connections) do
        pcall(function() Connection:Disconnect() end)
    end

    if GrenadeRuntime and GrenadeRuntime.Folder then
        pcall(function() GrenadeRuntime.Folder:Destroy() end)
    end

    if _hitSoundObj then pcall(function() _hitSoundObj:Destroy() end) end

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

    pcall(function()
        LocalPlayer.CameraMaxZoomDistance = 0.5
        LocalPlayer.CameraMinZoomDistance = 0.5
        local character = LocalPlayer.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        if humanoid then humanoid.AutoRotate = true end
    end)

    TriggerbotState = {
        AwaitingRelease = false,
        NextFireTime = 0,
        StopTime = 0,
        WasMoving = false,
        Holding = false,
        DelayUntil = 0,
        DelayActive = false,
    }

    local Client = getCachedClient()
    if Client then
        if OriginalAccuracySd ~= nil then Client.accuracy_sd = OriginalAccuracySd end
    end

    restoreAllRapidFireRates()
    restoreAllFullAutoValues()

    local Weapons = getWeaponsFolder()
    if Weapons then
        for weaponName, original in pairs(RCSOriginalValues) do
            local weaponFolder = Weapons:FindFirstChild(weaponName)
            local spread = weaponFolder and weaponFolder:FindFirstChild("Spread")
            local recoil = spread and spread:FindFirstChild("Recoil")
            if recoil and recoil:IsA("NumberValue") then recoil.Value = original end
        end
        table.clear(RCSOriginalValues)

        for weaponName, original in pairs(SavedRecoilValues) do
            local weaponFolder = Weapons:FindFirstChild(weaponName)
            local spread = weaponFolder and weaponFolder:FindFirstChild("Spread")
            local recoil = spread and spread:FindFirstChild("Recoil")
            if recoil and recoil:IsA("NumberValue") then recoil.Value = original end
        end
        table.clear(SavedRecoilValues)

        for weaponName, original in pairs(InstaWeaponState.SavedEquipTimes) do
            local weaponFolder = Weapons:FindFirstChild(weaponName)
            local EquipTime = weaponFolder and weaponFolder:FindFirstChild("EquipTime")
            if EquipTime and EquipTime:IsA("NumberValue") then EquipTime.Value = original end
        end
        for weaponName, original in pairs(InstaWeaponState.SavedReloadTimes) do
            local weaponFolder = Weapons:FindFirstChild(weaponName)
            local ReloadTime = weaponFolder and weaponFolder:FindFirstChild("ReloadTime")
            if ReloadTime and ReloadTime:IsA("NumberValue") then ReloadTime.Value = original end
        end
    end
    table.clear(InstaWeaponState.SavedEquipTimes)
    table.clear(InstaWeaponState.SavedReloadTimes)

    if AmbienceSavedLighting then
        pcall(function()
            local Lighting = game:GetService('Lighting')
            Lighting.ClockTime = AmbienceSavedLighting.ClockTime
            Lighting.GlobalShadows = AmbienceSavedLighting.GlobalShadows
            Lighting.Brightness = AmbienceSavedLighting.Brightness
            Lighting.Ambient = AmbienceSavedLighting.Ambient
            Lighting.OutdoorAmbient = AmbienceSavedLighting.OutdoorAmbient
            Lighting.ColorShift_Bottom = AmbienceSavedLighting.ColorShift_Bottom
            Lighting.ColorShift_Top = AmbienceSavedLighting.ColorShift_Top
            if AmbienceSavedLighting.Skybox and not AmbienceSavedLighting.Skybox.Parent then
                AmbienceSavedLighting.Skybox.Parent = Lighting
            end
        end)
        AmbienceSavedLighting = nil
    end

    if AutoJumpConn then AutoJumpConn:Disconnect(); AutoJumpConn = nil end

    if BhopState and BhopState.Conn then
        BhopState.Conn:Disconnect()
        BhopState.Conn = nil
    end
    pcall(function()
        local char = LocalPlayer.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if hum then hum.WalkSpeed = 16 end
    end)

    if LegitBhopState and LegitBhopState.Conn then
        LegitBhopState.Conn:Disconnect()
        LegitBhopState.Conn = nil
    end
    pcall(function()
        local char = LocalPlayer.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if hum then hum.WalkSpeed = 16 end
    end)

    Library:Unload()
end
getgenv().ValenokUnload = unloadValenok


-- weapon change listener for RapidFire
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


-- main loop
local lastEspUpdate = 0
local watermarkFps = 0
local watermarkFrames = 0
local watermarkLastUpdate = 0
local lastRemovalsCheck = 0
local lastAmbienceUpdate = 0

EspRuntime.Connections.RenderStepped = RunService.RenderStepped:Connect(function(dt)
    pcall(function()
        local now = tick()
        watermarkFrames = watermarkFrames + 1

        if now - lastEspUpdate >= (1 / 180) then
            lastEspUpdate = now
            local plist = Players:GetPlayers()
            for i = 1, #plist do
                updatePlayerEsp(plist[i])
            end
            updateItemEsp()
        end

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
        if now - lastAmbienceUpdate >= (1 / 60) then
            lastAmbienceUpdate = now
            updateAmbience()
        end
        updateTriggerbot()
        updateAntiAim()
        updateStrafe()
        updateAirStrafe()
        updateGrenadePrediction(dt)
        updateHitChams()
    end)
end)


-- kill all heartbeat
EspRuntime.Connections.KillAllHeartbeat = RunService.Heartbeat:Connect(function()
    pcall(function()
        updateKillAll()
    end)
end)

print("Valenok")
print("version: recode")
print("open/close menu end")

Library:OnUnload(function()
    getgenv().ValenokUnload = nil
    if SC_armsConn then SC_armsConn:Disconnect(); SC_armsConn = nil end
    pcall(function()
        if SC_Viewmodels then
            if SC_Viewmodels:FindFirstChild("v_CT Knife") then SC_Viewmodels:FindFirstChild("v_CT Knife"):Destroy() end
            if SC_Viewmodels:FindFirstChild("v_T Knife") then SC_Viewmodels:FindFirstChild("v_T Knife"):Destroy() end
            if SC_OriginalCTKnife then SC_OriginalCTKnife:Clone().Parent = SC_Viewmodels end
            if SC_OriginalTKnife then SC_OriginalTKnife:Clone().Parent = SC_Viewmodels end
        end
    end)
end)


local ConfigSection = Tabs.Config:AddLeftGroupbox('Menu')
ConfigSection:AddButton('Unload', unloadValenok)
ConfigSection:AddLabel('Menu bind'):AddKeyPicker('MenuKeybind', { Default = 'End', NoUI = true, Text = 'Menu' })

Library.ToggleKeybind = Options.MenuKeybind
Library.KeybindFrame.Visible = true

SaveManager:BuildConfigSection(Tabs.Config)
ThemeManager:ApplyToTab(Tabs.Config)
