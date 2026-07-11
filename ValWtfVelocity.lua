-- services
setfpscap(600)
if getgenv().ValenokUnload then pcall(getgenv().ValenokUnload) end

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Camera = game:GetService("Workspace").CurrentCamera
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualInputManager = game:GetService("VirtualInputManager")

local ConnectionManager = {
    _conns = {},
}
function ConnectionManager:CleanupAll()
    for key, conn in pairs(self._conns) do
        if conn then conn:Disconnect() end
    end
    table.clear(self._conns)
end

-- constants

local CONSTANTS = {
    DEFAULT_WALK_SPEED = 16,
    SKIN_FILE = "Valenok/skins.json",
    GITHUB_LIB_URL = "https://raw.githubusercontent.com/sixodicor-byte/1337/refs/heads/main/Ui.lua",
    GITHUB_THEME_URL = "https://raw.githubusercontent.com/bdimka251212-del/NewLib/refs/heads/main/addons/ThemeManager.lua",
    GITHUB_SAVE_URL = "https://raw.githubusercontent.com/bdimka251212-del/NewLib/refs/heads/main/addons/SaveManager.lua",
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
    SkeletonBones = {
        { "Head",          "UpperTorso" },
        { "UpperTorso",    "LowerTorso" },
        { "UpperTorso",    "RightUpperArm" },
        { "RightUpperArm", "RightLowerArm" },
        { "RightLowerArm", "RightHand" },
        { "UpperTorso",    "LeftUpperArm" },
        { "LeftUpperArm",  "LeftLowerArm" },
        { "LeftLowerArm",  "LeftHand" },
        { "LowerTorso",    "RightUpperLeg" },
        { "RightUpperLeg", "RightLowerLeg" },
        { "RightLowerLeg", "RightFoot" },
        { "LowerTorso",    "LeftUpperLeg" },
        { "LeftUpperLeg",  "LeftLowerLeg" },
        { "LeftLowerLeg",  "LeftFoot" },
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
        AWP = 9, Scout = 10, G3SG1 = 8, USP = 7, DesertEagle = 7, ["AK-47"] = 8,
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
local CacheData, CacheExpiry = {}, {}

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

local EspFrameCache = {
    tick = 0,
    anyEnabled = false,
    toggles = {},
    options = {},
    colors = {},
    boxFillTransparency = 1,
    chamsTransparency = 0.35,
}

local EspPlayerCache = {}

local function invalidateEspPlayerCache(player)
    EspPlayerCache[player] = nil
end

local function getCachedCharacterParts(player)
    local cached = EspPlayerCache[player]
    local character = player.Character
    if not character or not character.Parent then
        EspPlayerCache[player] = nil
        return nil, nil, nil
    end
    if cached and cached.character == character then
        if cached.humanoid and cached.humanoid.Parent and cached.rootPart and cached.rootPart.Parent then
            return character, cached.humanoid, cached.rootPart
        end
    end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if not humanoid or not rootPart then
        EspPlayerCache[player] = nil
        return character, humanoid, rootPart
    end
    EspPlayerCache[player] = {
        character = character,
        humanoid = humanoid,
        rootPart = rootPart,
        boneParts = nil,
    }
    return character, humanoid, rootPart
end

local function getCachedHead(player, character)
    local cached = EspPlayerCache[player]
    if cached and cached.character == character then
        if cached.head and cached.head.Parent then return cached.head end
        if cached.head == false then return nil end
    end
    local head = character:FindFirstChild("Head") or character:FindFirstChild("HeadHB")
    if cached and cached.character == character then
        cached.head = head or false
    end
    return head
end

local function getCachedEquippedTool(player, character)
    local tool = character:FindFirstChild("EquippedTool")
    return tool and tostring(tool.Value) or ""
end

local function getCachedBoneParts(player, character)
    local cached = EspPlayerCache[player]
    if cached and cached.character == character then
        if cached.boneParts then
            local allValid = true
            for i = 1, #cached.boneParts do
                local bp = cached.boneParts[i]
                if (bp[1] and not bp[1].Parent) or (bp[2] and not bp[2].Parent) then
                    allValid = false
                    break
                end
            end
            if allValid then
                return cached.boneParts
            end
        end
        local boneParts = {}
        for i, bone in ipairs(CONSTANTS.SkeletonBones) do
            boneParts[i] = {
                character:FindFirstChild(bone[1]),
                character:FindFirstChild(bone[2]),
            }
        end
        cached.boneParts = boneParts
        return boneParts
    end
    local boneParts = {}
    for i, bone in ipairs(CONSTANTS.SkeletonBones) do
        boneParts[i] = {
            character:FindFirstChild(bone[1]),
            character:FindFirstChild(bone[2]),
        }
    end
    return boneParts
end

local VisibilityParams = RaycastParams.new()
VisibilityParams.FilterType = Enum.RaycastFilterType.Exclude
VisibilityParams.IgnoreWater = true

local RayIgnoreList = { nil, nil, nil, nil, nil, nil, nil }

-- Silent aim state
local silentActive = false


local function getCamera()
    Camera = Workspace.CurrentCamera
    return Camera
end

local _mapFolder, _mapClips, _mapSpawns, _weaponsFolder, _playerGui, _guiFrame

local function getMapFolder()
    if _mapFolder and _mapFolder.Parent then return _mapFolder end
    _mapFolder = Workspace:FindFirstChild("Map")
    _mapClips = nil
    _mapSpawns = nil
    return _mapFolder
end

local function getMapClips()
    local map = getMapFolder()
    if not map then return nil end
    if _mapClips and _mapClips.Parent then return _mapClips end
    _mapClips = map:FindFirstChild("Clips")
    return _mapClips
end

local function getMapSpawns()
    local map = getMapFolder()
    if not map then return nil end
    if _mapSpawns and _mapSpawns.Parent then return _mapSpawns end
    _mapSpawns = map:FindFirstChild("SpawnPoints")
    return _mapSpawns
end

local function getWeaponsFolder()
    if _weaponsFolder and _weaponsFolder.Parent then return _weaponsFolder end
    _weaponsFolder = ReplicatedStorage:FindFirstChild("Weapons")
    return _weaponsFolder
end

local function getPlayerGui()
    if _playerGui and _playerGui.Parent then return _playerGui end
    _playerGui = LocalPlayer:FindFirstChild("PlayerGui")
    return _playerGui
end

local function getGuiFrame()
    local pg = getPlayerGui()
    if not pg then return nil end
    if _guiFrame and _guiFrame.Parent then return _guiFrame end
    _guiFrame = pg:FindFirstChild("GUI")
    return _guiFrame
end


local function getCachedClient()
    return Cache:getOrSet("Client", 5, function()
        local pg = getPlayerGui()
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

local function buildRayIgnoreList()
    local cam = getCamera()
    local char = LocalPlayer.Character
    local rayIgnore = getCachedRayIgnore()
    RayIgnoreList[1] = cam
    RayIgnoreList[2] = char
    RayIgnoreList[3] = rayIgnore
    RayIgnoreList[4] = getMapClips()
    RayIgnoreList[5] = getMapSpawns()
    RayIgnoreList[6] = GrenadeRuntime and GrenadeRuntime.Folder or nil
    RayIgnoreList[7] = HitChamsState and HitChamsState.Folder or nil
    return RayIgnoreList
end


local _controlTurnRemote
local function getControlTurnRemote()
    if _controlTurnRemote and _controlTurnRemote.Parent then return _controlTurnRemote end
    local events = ReplicatedStorage:FindFirstChild("Events")
    if events then
        _controlTurnRemote = events:FindFirstChild("ControlTurn")
    end
    if not _controlTurnRemote then
        _controlTurnRemote = ReplicatedStorage:FindFirstChild("ControlTurn")
    end
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
    
    if character:FindFirstChild("Shield") then return true end
    if character:FindFirstChildOfClass("ForceField") then return true end
    
    return false
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
    return getCachedCharacterParts(player)
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

    local cam = getCamera()
    local origin = cam.CFrame.Position
    local direction = targetPart.Position - origin
    if direction.Magnitude <= 1e-4 then return false end

    VisibilityParams.FilterDescendantsInstances = buildRayIgnoreList()

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
    local isSmoke = hitName == "Smoke" or hitName:find("Smoke") or (hitInst.Material == Enum.Material.Glass and hitInst.Transparency > 0.5)
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
        if part and isStrictRayVisible(part) then
            return true
        end
    end

    return false
end


-- Check how many walls are between player and target

local function getWallCount(originPos, targetPos, maxWalls)
    local direction = (targetPos - originPos).Unit
    local distance = (targetPos - originPos).Magnitude
    local rayLength = math.min(distance, 500)

    local ignoreList = buildRayIgnoreList()

    local wallCount = 0
    local lastHitPos = originPos
    local remainingDistance = rayLength
    local maxIterations = maxWalls + 2
    local iterationCount = 0

    while remainingDistance > 0.1 and wallCount <= maxWalls + 1 and iterationCount < maxIterations do
        iterationCount = iterationCount + 1
        local checkRay = Ray.new(lastHitPos, direction * remainingDistance)
        local hitPart, hitPos = Workspace:FindPartOnRayWithIgnoreList(checkRay, ignoreList)
        
        if hitPart then
            local parent = hitPart.Parent
            if parent and not parent:FindFirstChildOfClass("Humanoid") and not (LocalPlayer.Character and parent:IsDescendantOf(LocalPlayer.Character)) then
                wallCount = wallCount + 1
                lastHitPos = hitPos + direction * 0.1
                remainingDistance = (targetPos - lastHitPos).Magnitude
            else
                lastHitPos = hitPos + direction * 0.1
                remainingDistance = (targetPos - lastHitPos).Magnitude
            end
        else
            break
        end
    end
    
    return wallCount
end

-- Enhanced visibility check with wall penetration
local function isVisibleWithWalls(targetPart, maxWalls)
    local originPos = Camera.CFrame.Position
    local targetPos = targetPart.Position
    
    local walls = getWallCount(originPos, targetPos, maxWalls)
    return walls <= maxWalls
end

-- Find nearest target for silent aim with FOV and wall penetration check
local function getNearestSilentTarget()
    local mousePos = UserInputService:GetMouseLocation()
    local aimPos = mousePos

    local fovValue = Options.RagebotFOV and Options.RagebotFOV.Value or 180
    local fovPixels = fovValue * (Camera.ViewportSize.Y / Camera.FieldOfView)
    
    local wallPenEnabled = Toggles.RagebotWallPenetration and Toggles.RagebotWallPenetration.Value
    local maxWalls = wallPenEnabled and (Options.SilentAimMaxWalls and Options.SilentAimMaxWalls.Value or 3) or 0
    local useVisibleCheck = Toggles.RagebotVisCheck and Toggles.RagebotVisCheck.Value
    local useTeamCheck = Toggles.RagebotTeamCheck and Toggles.RagebotTeamCheck.Value
    local selectedHitbox = Options.RagebotHitbox and Options.RagebotHitbox.Value or "Head"

    local baimActive = false
    if Toggles.RagebotBaim and Toggles.RagebotBaim.Value then
        local baimKey = Options.RagebotBaimKeybind
        if not baimKey or baimKey.Value == "None" or baimKey.Mode == "Always" then
            baimActive = true
        else
            baimActive = isKeybindActive(baimKey)
        end
    end

    local nearestPart = nil
    local nearestDist = math.huge

    for _, player in ipairs(Players:GetPlayers()) do
        if player == LocalPlayer then continue end
        
        if useTeamCheck then
            local myTeam = LocalPlayer.Team
            local theirTeam = player.Team
            if myTeam and theirTeam and theirTeam == myTeam then continue end
        end

        local character = player.Character
        if not character then continue end
        
        local _, humanoid, rootPart = getCachedCharacterParts(player)
        local head = getCachedHead(player, character)
        if not humanoid or humanoid.Health <= 0 or not rootPart then continue end

        if character:FindFirstChildOfClass("ForceField") then continue end

        -- Determine target part based on hitbox selection
        local targetPart
        if baimActive or selectedHitbox == "Body" then
            targetPart = rootPart
        else
            targetPart = head or rootPart
        end
        
        if not targetPart then continue end

        local screenPos, onScreen = Camera:WorldToViewportPoint(targetPart.Position)
        if not onScreen then continue end

        if useVisibleCheck and not isVisibleWithWalls(targetPart, maxWalls) then continue end

        local dist = (Vector2.new(screenPos.X, screenPos.Y) - aimPos).Magnitude
        if dist < nearestDist and dist <= fovPixels then
            nearestDist = dist
            nearestPart = targetPart
        end
    end

    return nearestPart
end


local TracerPool = {}

local function getTracerFromPool()
    for i = #TracerPool, 1, -1 do
        local set = TracerPool[i]
        if not set.inUse then
            set.inUse = true
            return set
        end
    end
    local set = {
        att0 = Instance.new("Attachment"),
        att1 = Instance.new("Attachment"),
        beam = Instance.new("Beam"),
        inUse = true,
    }
    set.att0.Parent = workspace.Terrain
    set.att1.Parent = workspace.Terrain
    set.beam.Attachment0 = set.att0
    set.beam.Attachment1 = set.att1
    set.beam.Width0 = 0.5
    set.beam.Width1 = 0.5
    set.beam.LightEmission = 1
    set.beam.LightInfluence = 0
    set.beam.Parent = workspace.Terrain
    return set
end

local function returnTracerToPool(set)
    set.inUse = false
    set.beam.Enabled = false
    set.att0.WorldPosition = Vector3.zero
    set.att1.WorldPosition = Vector3.zero
end

local function drawBulletTracer(startPos, endPos)
    if not Toggles.MiscBulletTracer or not Toggles.MiscBulletTracer.Value then return end

    local color = getOptionColor("MiscBulletTracerColor", Color3.fromRGB(150, 20, 60))
    local tracerMode = Options.MiscBulletTracerTexture and Options.MiscBulletTracerTexture.Value or "Solid"
    local textureId = CONSTANTS.TracerTextureMap[tracerMode] or CONSTANTS.TracerTextureMap["Solid"]
    local faceCamera = Toggles.MiscBulletTracerFaceCamera and Toggles.MiscBulletTracerFaceCamera.Value or false

    local set = getTracerFromPool()
    set.att0.WorldPosition = startPos
    set.att1.WorldPosition = endPos
    set.beam.Color = ColorSequence.new(color)
    set.beam.FaceCamera = faceCamera
    set.beam.Texture = textureId
    set.beam.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0),
        NumberSequenceKeypoint.new(1, 0),
    })
    set.beam.Enabled = true

    task.delay(1, function()
        returnTracerToPool(set)
    end)
end

local _hitSoundObj, PlayHitMarker

local HitMarkerState = {
    OutlineLines = {},
    FillLines = {},
    Gen = 0,
    Created = false,
    Fading = false,
    HoldUntil = 0,
    FadeStart = 0,
    FadeDuration = 0.3,
    HeartbeatConn = nil,
}

local HitChamsState = {
    Cooldown = false,
    ActiveChams = 0,
    Folder = nil,
}

local function ensureHitChamsFolder()
    if not HitChamsState.Folder or not HitChamsState.Folder.Parent then
        local folder = Instance.new("Folder")
        folder.Name = "ValenokHitChams"
        folder.Parent = workspace
        HitChamsState.Folder = folder
    end
    return HitChamsState.Folder
end

local HIT_CHAMS_IGNORE = {
    "HumanoidRootPart",
    "FakeHead",
    "C4",
    "Gun"
}

local function hitChams(player, customColor, transparency, lifetime)
    if not player or not player.Character or HitChamsState.Cooldown then return end
    if HitChamsState.ActiveChams >= CONSTANTS.MAX_HIT_CHAMS_CLONES then return end
    
    HitChamsState.Cooldown = true
    HitChamsState.ActiveChams = HitChamsState.ActiveChams + 1
    
    task.delay(0.05, function()
        HitChamsState.Cooldown = false
    end)
    
    local color = customColor or getOptionColor("MiscHitChamsColor", Color3.fromRGB(200, 30, 80))
    local fadeTime = lifetime or (Options.MiscHitChamsLifetime and Options.MiscHitChamsLifetime.Value or 1.3)
    
    for _, part in ipairs(player.Character:GetChildren()) do
        if (part:IsA("MeshPart") and part.Transparency ~= 1) or part.Name == "Head" then
            if not HIT_CHAMS_IGNORE[part.Name] then
                local clone = part:Clone()
                clone:ClearAllChildren()
                clone.Material = Enum.Material.ForceField
                clone.CFrame = part.CFrame
                clone.Size = part.Name == "Head" and Vector3.new(1.18, 1.18, 1.18) or clone.Size
                clone.CanCollide = false
                clone.Color = color
                clone.Anchored = true
                clone.Transparency = transparency or 0
                clone.Parent = ensureHitChamsFolder()
                
                if clone:FindFirstChild("TextureID") then
                    clone.TextureID = ""
                end
                if clone:FindFirstChild("UsePartColor") then
                    clone.UsePartColor = true
                end
                
                task.delay(fadeTime, function()
                    if clone and clone.Parent then
                        clone:Destroy()
                    end
                    HitChamsState.ActiveChams = math.max(0, HitChamsState.ActiveChams - 1)
                end)
            end
        end
    end
end

local GrenadeRuntime = {
    Folder = nil,
    Attachments = {},
    Beams = {},
    Sphere = nil,
    LmbDown = false,
    RmbDown = false,
    PulseVal = 1.0,
    PulseDir = 1,
    RP = nil,
    FilterList = nil,
    TrajectoryCache = {
        lastPos = nil,
        lastLook = nil,
        lastNadeType = nil,
        lastVel = nil,
        cachedPoints = nil,
        cachedSpherePos = nil,
    },
}

local function getLocalEquippedTool()
    local char = LocalPlayer.Character
    if not char then return nil end
    return char:FindFirstChild("EquippedTool")
end

local function isHoldingNade()
    local lp = LocalPlayer
    if not lp or not lp.Character then return false end
    local gun = lp.Character:FindFirstChild("Gun")
    if gun and gun:FindFirstChild("Grenade") then return true end
    local eqVal = getLocalEquippedTool()
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
    local cam = getCamera()
    if not cam then return Vector3.new() end
    return (cam.CFrame * CFrame.new(0.1, -0.4, -2.5)).Position
end

local function getNadeType()
    local lp = LocalPlayer
    if not lp or not lp.Character then return "default" end
    local eqVal = getLocalEquippedTool()
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

local function ensureGrenadePredictionObjects()
    if GrenadeRuntime.Folder then return end
    local folder = Instance.new("Folder")
    folder.Name = "ValenokGrenadePredictor"
    if workspace and workspace.Terrain then folder.Parent = workspace.Terrain end
    GrenadeRuntime.Folder = folder

    for i = 1, 40 do
        local att = Instance.new("Attachment", folder)
        GrenadeRuntime.Attachments[i] = att
        if i > 1 then
            local beam = Instance.new("Beam", folder)
            beam.Attachment0 = GrenadeRuntime.Attachments[i-1]
            beam.Attachment1 = att
            beam.Width0 = 0.08
            beam.Width1 = 0.08
            beam.FaceCamera = true
            beam.Segments = 10
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
    sphere.Parent = folder
    sphere.CastShadow = false
    sphere.Transparency = 1
    GrenadeRuntime.Sphere = sphere
end

local grenadeHidden = true

local function updateGrenadePrediction(dt)
    if not Toggles.GrenadesPrediction or not Toggles.GrenadesPrediction.Value then
        if not grenadeHidden then
            for _, b in pairs(GrenadeRuntime.Beams) do b.Enabled = false end
            if GrenadeRuntime.Sphere then GrenadeRuntime.Sphere.Transparency = 1 end
            grenadeHidden = true
        end
        return
    end

    ensureGrenadePredictionObjects()

    if not isHoldingNade() or not (GrenadeRuntime.LmbDown or GrenadeRuntime.RmbDown) then
        if not grenadeHidden then
            for _, b in pairs(GrenadeRuntime.Beams) do b.Enabled = false end
            if GrenadeRuntime.Sphere then GrenadeRuntime.Sphere.Transparency = 1 end
            grenadeHidden = true
        end
        return
    end
    grenadeHidden = false

    local cam = getCamera()
    if not cam then return end

    local rgb = Options.GrenadesPredictionColor and Options.GrenadesPredictionColor.Value or Color3.fromRGB(255, 50, 50)
    local c3 = typeof(rgb) == "Color3" and rgb or Color3.new(1, 0.2, 0.2)

    for _, b in pairs(GrenadeRuntime.Beams) do
        b.Color = ColorSequence.new(c3)
        b.Enabled = false
    end
    GrenadeRuntime.Sphere.Color = c3

    GrenadeRuntime.PulseVal = GrenadeRuntime.PulseVal + (GrenadeRuntime.PulseDir * (dt or 0.016) * 2.5)
    if GrenadeRuntime.PulseVal >= 1.6 then GrenadeRuntime.PulseDir = -1 end
    if GrenadeRuntime.PulseVal <= 0.7 then GrenadeRuntime.PulseDir = 1 end
    GrenadeRuntime.Sphere.Size = Vector3.new(GrenadeRuntime.PulseVal, GrenadeRuntime.PulseVal, GrenadeRuntime.PulseVal)

    local lp = LocalPlayer
    local _, _, hrp = getCachedCharacterParts(lp)
    local plrVel = hrp and hrp.AssemblyLinearVelocity or Vector3.new()
    local nadeType = getNadeType()
    local camLook = cam.CFrame.LookVector
    local startPos = getNadePosition()

    local needsRecalc = false
    if not GrenadeRuntime.TrajectoryCache.lastPos or (startPos - GrenadeRuntime.TrajectoryCache.lastPos).Magnitude > 0.5 then
        needsRecalc = true
    elseif not GrenadeRuntime.TrajectoryCache.lastLook or camLook:Dot(GrenadeRuntime.TrajectoryCache.lastLook) < 0.9994 then
        needsRecalc = true
    elseif nadeType ~= GrenadeRuntime.TrajectoryCache.lastNadeType then
        needsRecalc = true
    elseif not GrenadeRuntime.TrajectoryCache.lastVel or (plrVel - GrenadeRuntime.TrajectoryCache.lastVel).Magnitude > 5 then
        needsRecalc = true
    end

    if not needsRecalc and GrenadeRuntime.TrajectoryCache.cachedPoints then
        local numPoints = #GrenadeRuntime.TrajectoryCache.cachedPoints
        for j = 1, numPoints do
            local pt = GrenadeRuntime.TrajectoryCache.cachedPoints[j]
            GrenadeRuntime.Attachments[j].WorldPosition = pt.pos
            if j > 1 and GrenadeRuntime.Beams[j-1] then
                GrenadeRuntime.Beams[j-1].Transparency = NumberSequence.new(pt.transparency)
                GrenadeRuntime.Beams[j-1].Enabled = true
            end
        end
        for j = numPoints, 39 do
            if GrenadeRuntime.Beams[j] then GrenadeRuntime.Beams[j].Enabled = false end
        end
        GrenadeRuntime.Sphere.CFrame = CFrame.new(GrenadeRuntime.TrajectoryCache.cachedSpherePos)
        GrenadeRuntime.Sphere.Transparency = 0.3
        return
    end

    GrenadeRuntime.TrajectoryCache.lastPos = startPos
    GrenadeRuntime.TrajectoryCache.lastLook = camLook
    GrenadeRuntime.TrajectoryCache.lastNadeType = nadeType
    GrenadeRuntime.TrajectoryCache.lastVel = plrVel

    local params = CONSTANTS.GRENADE_PARAMS[nadeType] or CONSTANTS.GRENADE_PARAMS.default
    local maxBounces = params.maxBounces
    local bounceDamping = params.bounceDamping
    local velocity = cam.CFrame.LookVector * CONSTANTS.GRENADE_PARAMS.LOOK_SPEED + plrVel * CONSTANTS.GRENADE_PARAMS.PLR_FACTOR + Vector3.new(0, CONSTANTS.GRENADE_PARAMS.UP_BIAS, 0)
    local grav = Vector3.new(0, -workspace.Gravity, 0)

    local tStep = 1/60
    local maxSteps = 240
    local currentPos = startPos

    if not GrenadeRuntime.RP then
        local rp = RaycastParams.new()
        rp.FilterType = Enum.RaycastFilterType.Exclude
        GrenadeRuntime.RP = rp
        GrenadeRuntime.FilterList = {lp.Character, getCachedRayIgnore(), GrenadeRuntime.Folder}
        local clips = getMapClips()
        if clips then table.insert(GrenadeRuntime.FilterList, clips) end
        local spawns = getMapSpawns()
        if spawns then table.insert(GrenadeRuntime.FilterList, spawns) end
    end
    GrenadeRuntime.FilterList[1] = lp.Character
    GrenadeRuntime.FilterList[#GrenadeRuntime.FilterList + 1] = HitChamsState and HitChamsState.Folder or nil
    GrenadeRuntime.RP.FilterDescendantsInstances = GrenadeRuntime.FilterList
    local rp = GrenadeRuntime.RP

    local bounces = 0
    local pointCount = 1
    GrenadeRuntime.Attachments[1].WorldPosition = startPos

    local samplePeriod = 2
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

    for j = 1, math.min(pointCount - 1, 39) do
        if GrenadeRuntime.Beams[j] then
            GrenadeRuntime.Beams[j].Enabled = true
        end
    end
    for j = pointCount, 39 do
        if GrenadeRuntime.Beams[j] then GrenadeRuntime.Beams[j].Enabled = false end
    end

    local cachedPoints = {}
    for j = 1, pointCount do
        cachedPoints[j] = {
            pos = GrenadeRuntime.Attachments[j].WorldPosition,
            transparency = 0.15 + (j/40)*0.85,
        }
    end
    GrenadeRuntime.TrajectoryCache.cachedPoints = cachedPoints
    GrenadeRuntime.TrajectoryCache.cachedSpherePos = currentPos

    GrenadeRuntime.Sphere.CFrame = CFrame.new(currentPos)
    GrenadeRuntime.Sphere.Transparency = 0.3
end

EspRuntime.Connections.GrenadeInputBegan = UserInputService.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then GrenadeRuntime.LmbDown = true end
    if input.UserInputType == Enum.UserInputType.MouseButton2 then GrenadeRuntime.RmbDown = true end
end)
EspRuntime.Connections.GrenadeInputEnded = UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then GrenadeRuntime.LmbDown = false end
    if input.UserInputType == Enum.UserInputType.MouseButton2 then GrenadeRuntime.RmbDown = false end
end)

local function ensureHitMarkerLines()
    if HitMarkerState.Created then return end
    -- remove leftover drawings from a previous injection
    if getgenv().ValenokHitMarker then
        for _, d in ipairs(getgenv().ValenokHitMarker) do
            if d then d.Visible = false; d:Remove() end
        end
    end
    local all = {}
    for i = 1, 4 do
        local success1, outlineLine = pcall(Drawing.new, "Line")
        if success1 and outlineLine then
            outlineLine.Visible = false
            outlineLine.ZIndex = 1
            HitMarkerState.OutlineLines[i] = outlineLine
            table.insert(all, outlineLine)
        end
        local success2, fillLine = pcall(Drawing.new, "Line")
        if success2 and fillLine then
            fillLine.Visible = false
            fillLine.ZIndex = 2
            HitMarkerState.FillLines[i] = fillLine
            table.insert(all, fillLine)
        end
    end
    getgenv().ValenokHitMarker = all
    HitMarkerState.Created = true
end

ShowHitMarker = function()
    ensureHitMarkerLines()

    local cam = getCamera()
    if not cam then return end
    local viewportSize = cam.ViewportSize
    if not viewportSize then return end
    local centerX, centerY = viewportSize.X * 0.5, viewportSize.Y * 0.5

    local gap, len = 2, 5
    local thickness = 1
    local colorOpt = Options.MiscHitMarkerColor
    local color = colorOpt and colorOpt.Value or Color3.fromRGB(255, 255, 255)
    local outlineColor = Color3.fromRGB(0, 0, 0)

    local segs = {
        {Vector2.new(centerX - gap - len, centerY - gap - len), Vector2.new(centerX - gap, centerY - gap)},
        {Vector2.new(centerX + gap, centerY - gap), Vector2.new(centerX + gap + len, centerY - gap - len)},
        {Vector2.new(centerX - gap - len, centerY + gap + len), Vector2.new(centerX - gap, centerY + gap)},
        {Vector2.new(centerX + gap, centerY + gap), Vector2.new(centerX + gap + len, centerY + gap + len)},
    }

    for i, seg in ipairs(segs) do
        local from, to = seg[1], seg[2]
        local d = (to - from)
        local unit = d.Magnitude > 0 and d.Unit or Vector2.new(0, 0)
        local ol = HitMarkerState.OutlineLines[i]
        if ol then
            ol.From = from - unit * 1
            ol.To = to + unit * 1
            ol.Thickness = thickness + 2
            ol.Color = outlineColor
            ol.Transparency = 1
            ol.Visible = true
        end
        local fl = HitMarkerState.FillLines[i]
        if fl then
            fl.From = from
            fl.To = to
            fl.Thickness = thickness
            fl.Color = color
            fl.Transparency = 1
            fl.Visible = true
        end
    end

    -- re-trigger on each hit; generation guard prevents an old fade from hiding a fresh marker
    HitMarkerState.Gen = HitMarkerState.Gen + 1

    local lifetimeOpt = Options.MiscHitMarkerLifetime
    local lifetime = lifetimeOpt and lifetimeOpt.Value or 1
    local fadeTime = math.min(0.3, lifetime)
    local holdTime = lifetime - fadeTime

    HitMarkerState.HoldUntil = tick() + holdTime
    HitMarkerState.FadeDuration = fadeTime
    HitMarkerState.Fading = true

    if not HitMarkerState.HeartbeatConn then
        HitMarkerState.HeartbeatConn = RunService.Heartbeat:Connect(function()
            if not HitMarkerState.Fading then return end
            local now = tick()
            if now < HitMarkerState.HoldUntil then return end

            local elapsed = now - HitMarkerState.HoldUntil
            local alpha = 1 - math.clamp(elapsed / HitMarkerState.FadeDuration, 0, 1)

            for _, obj in ipairs(HitMarkerState.OutlineLines) do if obj then obj.Transparency = alpha end end
            for _, obj in ipairs(HitMarkerState.FillLines) do if obj then obj.Transparency = alpha end end

            if alpha <= 0 then
                for _, obj in ipairs(HitMarkerState.OutlineLines) do if obj then obj.Visible = false; obj.Transparency = 1 end end
                for _, obj in ipairs(HitMarkerState.FillLines) do if obj then obj.Visible = false; obj.Transparency = 1 end end
                HitMarkerState.Fading = false
            end
        end)
    end
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
        or (Toggles.ESPSkeleton and Toggles.ESPSkeleton.Value)
end


local function updateEspFrameCache()
    local now = tick()
    if now == EspFrameCache.tick then return end
    EspFrameCache.tick = now

    EspFrameCache.anyEnabled = isAnyEspEnabled()

    EspFrameCache.toggles = {
        teamCheck = Toggles.ESPTeamCheck and Toggles.ESPTeamCheck.Value,
        box = Toggles.ESPBox and Toggles.ESPBox.Value,
        name = Toggles.ESPName and Toggles.ESPName.Value,
        boxFill = Toggles.ESPBoxFill and Toggles.ESPBoxFill.Value,
        weapon = Toggles.ESPWeapon and Toggles.ESPWeapon.Value,
        healthBar = Toggles.ESPHealthBar and Toggles.ESPHealthBar.Value,
        healthBarOutline = Toggles.ESPHealthBarOutline and Toggles.ESPHealthBarOutline.Value,
        chams = Toggles.ESPChams and Toggles.ESPChams.Value,
        chamsOutline = Toggles.ESPChamsOutline and Toggles.ESPChamsOutline.Value,
        skeleton = Toggles.ESPSkeleton and Toggles.ESPSkeleton.Value,
    }

    EspFrameCache.options = {
        boxType = Options.ESPBoxType and Options.ESPBoxType.Value or "Full",
    }

    EspFrameCache.colors = {
        box = getOptionColor("ESPBoxColor", Color3.fromRGB(255, 255, 255)),
        name = getOptionColor("ESPNameColor", Color3.fromRGB(255, 255, 255)),
        weapon = getOptionColor("ESPWeaponColor", Color3.fromRGB(255, 255, 255)),
        healthBar = getOptionColor("ESPHealthBarColor", Color3.fromRGB(0, 255, 0)),
        boxFill = getOptionColor("ESPBoxFillColor", Color3.fromRGB(255, 255, 255)),
        skeleton = getOptionColor("ESPSkeletonColor", Color3.fromRGB(255, 255, 255)),
        chamsFill = getOptionColor("ESPChamsColor", Color3.fromRGB(255, 255, 255)),
        chamsOutline = getOptionColor("ESPChamsOutlineColor", Color3.fromRGB(255, 255, 255)),
    }

    local fillOpt = Options.ESPBoxFillColor
    EspFrameCache.boxFillTransparency = 1
    if fillOpt and fillOpt.Transparency then
        EspFrameCache.boxFillTransparency = math.clamp(1 - fillOpt.Transparency, 0, 1)
    end

    EspFrameCache.chamsTransparency = getChamsTransparency()
end


-- forward declarations
local updateRCS, updateRapidFire, updateFullAuto, restoreAllRapidFireRates, restoreAllFullAutoValues
local applyNoRecoil, applyNoSpread, applyInstaEquip, applyInstaReload, fireSingleShot
local updateBhop, updateLegitBhop, updateThirdPerson, updateThirdPersonNoClip, updateNoclip, updateFly, updateAutoJump, updateAutoCrouch, updateSpeedHack
local updateNoScope, updateNoFlash, applyNoScope, setupNoSmoke
local ensureCrosshair, updateCrosshair, unloadValenok
local updateViewModelVisuals
local applySkyboxChanger




-- combat

local AimRuntime = {
    FovLines = {},
}

local TriggerbotState = {
    NextFireTime = 0,
    StopTime = 0,
    WasMoving = false,
    DelayUntil = 0,
    DelayActive = false,
    IsFiring = false,
}

local PeekAssist = {
    SavedCFrame = nil,
    Active      = false,
    Returning   = false,
    LastBindOn  = false,
}

local PeekWallParams = RaycastParams.new()
PeekWallParams.FilterType  = Enum.RaycastFilterType.Exclude
PeekWallParams.IgnoreWater = true

local PEEK_CIRCLE_SEGMENTS = 96
local PEEK_FILL_LAYERS = 8
local PEEK_FILL_PER_LAYER = 24
local PEEK_FILL_SEGMENTS = PEEK_FILL_LAYERS * PEEK_FILL_PER_LAYER

local PeekDraw = {
    CircleLines = {},
    CircleOutlines = {},
    FillLines = {},
    FilterList = {},
    PulseVal = 0,
    PulseDir = 1,
}

for i = 1, PEEK_CIRCLE_SEGMENTS do
    local ln = Drawing.new("Line")
    ln.Visible      = false
    ln.Thickness    = 2
    ln.Transparency = 1
    ln.Color        = Color3.fromRGB(135, 206, 250)
    ln.ZIndex       = 2
    PeekDraw.CircleLines[i] = ln

    local ol = Drawing.new("Line")
    ol.Visible      = false
    ol.Thickness    = 4
    ol.Transparency = 1
    ol.Color        = Color3.fromRGB(0, 0, 0)
    ol.ZIndex       = 1
    PeekDraw.CircleOutlines[i] = ol
end

for i = 1, PEEK_FILL_SEGMENTS do
    local ln = Drawing.new("Line")
    ln.Visible      = false
    ln.Thickness    = 1
    ln.Transparency = 0.5
    ln.Color        = Color3.fromRGB(135, 206, 250)
    PeekDraw.FillLines[i] = ln
end

local function hidePeekCircle()
    for i = 1, PEEK_CIRCLE_SEGMENTS do
        PeekDraw.CircleLines[i].Visible = false
        if PeekDraw.CircleOutlines[i] then PeekDraw.CircleOutlines[i].Visible = false end
    end
    for i = 1, PEEK_FILL_SEGMENTS do
        PeekDraw.FillLines[i].Visible = false
    end
end

local function drawPeekCircle(cam, worldPos)
    local viewportSize = cam.ViewportSize
    local RADIUS = 2.4

    -- pulse animation
    PeekDraw.PulseVal = PeekDraw.PulseVal + (PeekDraw.PulseDir * 0.02)
    if PeekDraw.PulseVal >= 1 then PeekDraw.PulseVal = 1; PeekDraw.PulseDir = -1 end
    if PeekDraw.PulseVal <= 0.3 then PeekDraw.PulseVal = 0.3; PeekDraw.PulseDir = 1 end
    local pulseAlpha = PeekDraw.PulseVal

    -- circle outline (black, behind)
    for i = 1, PEEK_CIRCLE_SEGMENTS do
        local a1 = (i - 1) / PEEK_CIRCLE_SEGMENTS * math.pi * 2
        local a2 =  i      / PEEK_CIRCLE_SEGMENTS * math.pi * 2
        local p1 = worldPos + Vector3.new(math.cos(a1) * RADIUS, 0, math.sin(a1) * RADIUS)
        local p2 = worldPos + Vector3.new(math.cos(a2) * RADIUS, 0, math.sin(a2) * RADIUS)
        local s1 = cam:WorldToViewportPoint(p1)
        local s2 = cam:WorldToViewportPoint(p2)
        local ln = PeekDraw.CircleLines[i]
        local ol = PeekDraw.CircleOutlines[i]

        if s1.Z > 0 and s2.Z > 0 then
            local v1 = Vector2.new(s1.X, s1.Y)
            local v2 = Vector2.new(s2.X, s2.Y)
            ol.From = v1; ol.To = v2; ol.Visible = true
            ln.From = v1; ln.To = v2; ln.Visible = true
        else
            ln.Visible = false
            if ol then ol.Visible = false end
        end
    end

    -- fill lines with gradient transparency
    local center2d = cam:WorldToViewportPoint(worldPos)
    local fillIdx = 1
    for layer = 1, PEEK_FILL_LAYERS do
        local r = RADIUS * (layer / PEEK_FILL_LAYERS)
        local layerAlpha = (1 - layer / PEEK_FILL_LAYERS) * pulseAlpha
        for i = 1, PEEK_FILL_PER_LAYER do
            local angle = ((i - 1) / PEEK_FILL_PER_LAYER) * math.pi * 2
            local pw = worldPos + Vector3.new(math.cos(angle) * r, 0, math.sin(angle) * r)
            local sw = cam:WorldToViewportPoint(pw)
            local fl = PeekDraw.FillLines[fillIdx]

            if center2d.Z > 0 and sw.Z > 0 then
                fl.From    = Vector2.new(center2d.X, center2d.Y)
                fl.To      = Vector2.new(sw.X, sw.Y)
                fl.Transparency = 1 - layerAlpha
                fl.Visible = true
            else
                fl.Visible = false
            end

            fillIdx = fillIdx + 1
        end
    end
end

local function isPeekKeybindActive()
    if not Toggles.PeekAssistEnable or not Toggles.PeekAssistEnable.Value then return false end
    return isKeybindActive(Options.PeekAssistKeybind)
end

local function retreatToSaved(savedCF)
    PeekAssist.Returning = true
    task.spawn(function()
        local char = LocalPlayer.Character
        local _, hum, hrp = getCachedCharacterParts(LocalPlayer)
        if hrp then
            local baseSpeed = (hum and hum.WalkSpeed and hum.WalkSpeed > 0) and hum.WalkSpeed or 16
            local moveSpeed = baseSpeed * 4
            local targetPos = savedCF.Position
            local deadline  = tick() + 3
            local lastT     = tick()

            while PeekAssist.Returning and tick() < deadline do
                local c2 = LocalPlayer.Character
                local h2 = c2 and c2:FindFirstChild("HumanoidRootPart")
                if not h2 then break end

                local now = tick()
                local dt  = now - lastT
                lastT = now

                local cur      = h2.Position
                local toTarget = targetPos - cur
                local dist     = toTarget.Magnitude
                if dist < 0.5 then
                    if h2 then h2.CFrame = savedCF end
                    break
                end

                local step = moveSpeed * dt
                if step >= dist then
                    if h2 then h2.CFrame = savedCF end
                    break
                else
                    local newPos = cur + toTarget.Unit * step
                    if h2 then h2.CFrame = CFrame.new(newPos, newPos + h2.CFrame.lookVector) end
                end
                RunService.RenderStepped:Wait()
            end

            local c3 = LocalPlayer.Character
            local h3 = c3 and c3:FindFirstChild("HumanoidRootPart")
            if h3 then h3.CFrame = savedCF end
        end
        PeekAssist.Returning   = false
        PeekAssist.SavedCFrame = nil
        PeekAssist.Active      = false
    end)
end

local function updatePeekAssist()
    if not Toggles.PeekAssistEnable or not Toggles.PeekAssistEnable.Value then
        hidePeekCircle()
        PeekAssist.Active  = false
        PeekAssist.Returning = false
        return
    end

    local cam = getCamera()
    if not cam then return end

    local bindOn = isKeybindActive(Options.PeekAssistKeybind)

    local char     = LocalPlayer.Character
    local _, humanoid, hrp = getCachedCharacterParts(LocalPlayer)

    if bindOn and not PeekAssist.LastBindOn then
        if hrp then
            PeekAssist.SavedCFrame = hrp.CFrame
            PeekAssist.Active      = true
            PeekAssist.Returning   = false
        end
    elseif not bindOn and PeekAssist.LastBindOn then
        PeekAssist.Active = false
        if not PeekAssist.Returning and PeekAssist.SavedCFrame then
            local retreatMode = Options.PeekAssistRetreatMode and Options.PeekAssistRetreatMode.Value or "On Key"
            if retreatMode == "On Key" then
                retreatToSaved(PeekAssist.SavedCFrame)
            else
                PeekAssist.SavedCFrame = nil
            end
        end
    end
    PeekAssist.LastBindOn = bindOn

    if PeekAssist.Active and PeekAssist.SavedCFrame and hrp then
        local distance = (hrp.Position - PeekAssist.SavedCFrame.Position).Magnitude
        if distance > 50 then
            PeekAssist.SavedCFrame = nil
            PeekAssist.Active = false
            PeekAssist.Returning = false
        end
    end

    if PeekAssist.SavedCFrame and cam then
        local wallBlocked = false
        if hrp then
            local origin = hrp.Position
            local target = PeekAssist.SavedCFrame.Position
            local dir    = target - origin
            PeekWallParams.FilterDescendantsInstances = buildRayIgnoreList()
            local hit = Workspace:Raycast(origin, dir, PeekWallParams)
            if hit and hit.Instance and hit.Instance.CanCollide then
                local isPlayer = false
                local parent = hit.Instance.Parent
                while parent and parent ~= Workspace do
                    if parent:FindFirstChildOfClass("Humanoid") then
                        isPlayer = true
                        break
                    end
                    parent = parent.Parent
                end
                if not isPlayer then
                    wallBlocked = true
                    hidePeekCircle()
                end
            end
        end
        if not wallBlocked then
            local floorPos = PeekAssist.SavedCFrame.Position - Vector3.new(0, 2.8, 0)
            drawPeekCircle(cam, floorPos)
        end
    else
        hidePeekCircle()
    end
end

peekAssistOnShot = function()
    if not Toggles.PeekAssistEnable or not Toggles.PeekAssistEnable.Value then return end
    local retreatMode = Options.PeekAssistRetreatMode and Options.PeekAssistRetreatMode.Value or "On Key"
    if retreatMode ~= "On Shot" then return end
    if not PeekAssist.SavedCFrame then return end
    retreatToSaved(PeekAssist.SavedCFrame)
end

local RapidFireState = { SavedFireRates = {} }
local FullAutoState = { SavedAutoValues = {} }
local InstaWeaponState = { SavedEquipTimes = {}, SavedReloadTimes = {} }
local SavedRecoilValues, RCSOriginalValues = {}, {}
local OriginalAccuracySd


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
    return Cache:getOrSet(key, 10, function()
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
        local cam = getCamera()
        local screenCenter = Vector2.new(cam.ViewportSize.X * 0.5, cam.ViewportSize.Y * 0.5)

        for _, part in ipairs(allParts) do
            local screenPoint = cam:WorldToViewportPoint(part.Position)
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
    local cam = getCamera()
    local camLook = cam.CFrame.LookVector
    local camPos = cam.CFrame.Position

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
            local screenPoint = cam:WorldToViewportPoint(targetPart.Position)
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

        local _, humanoid, rootPart = getCachedCharacterParts(player)
        if not humanoid or humanoid.Health <= 0 or not rootPart then continue end

        local targetPart

        if isBaimKeyActive() then
            local bodyFallbacks = { "UpperTorso", "LowerTorso", "LeftUpperArm", "LeftLowerArm", "LeftHand", "RightUpperArm", "RightLowerArm", "RightHand" }
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

    local cam = getCamera()
    local screenPoint = cam:WorldToViewportPoint(targetPart.Position)
    if screenPoint.Z <= 0 then return false end

    local distanceFromCrosshair = (Vector2.new(screenPoint.X, screenPoint.Y) - screenCenter).Magnitude
    if distanceFromCrosshair > (fovRadius * 1.15) then return false end

    return true
end


local function updateAimBot(dt)
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
        Cache:set("AimTarget", targetPart, 0.15)
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
        dt = dt or (1 / 60)
        local alpha = math.clamp(1 / smoothValue * dt * 60, 0.01, 1)
        cam.CFrame = cam.CFrame:Lerp(targetCFrame, alpha)
    end
end






-- multipoint scan: check multiple points on a part's surface for visibility
local MultiPointState = { cache = {}, frame = 0, lastClean = 0 }

local function isPartVisibleMultiPoint(part, useMulti, scale)
    if not useMulti then
        return isStrictRayVisible(part)
    end

    local mpScale = scale or ((Options.RagebotMultiPointScale and Options.RagebotMultiPointScale.Value or 50) / 100)
    local mpPoints = Options.RagebotMultiPointPoints and Options.RagebotMultiPointPoints.Value or 10

    local cached = MultiPointState.cache[part]
    if cached then
        if MultiPointState.frame - cached.frame <= 3 then
            if (part.CFrame.Position - cached.pos).Magnitude < 0.1 then
                return cached.result
            end
        end
    end

    local pos = part.CFrame.Position

    -- center first
    if isStrictRayVisible(part) then
        MultiPointState.cache[part] = { result = true, frame = MultiPointState.frame, pos = pos }
        return true
    end

    -- multipoint: check points on the part's bounding box
    local origin = Camera.CFrame.Position
    VisibilityParams.FilterDescendantsInstances = buildRayIgnoreList()

    for _, target in ipairs(getMultipointPositions(part, mpScale, mpPoints)) do
        local dir = target - origin
        if dir.Magnitude > 0.1 then
            getgenv().IgnoreRaycastHook = true
            local result = Workspace:Raycast(origin, dir, VisibilityParams)
            getgenv().IgnoreRaycastHook = false
            if result and result.Instance then
                local hit = result.Instance
                if hit == part then
                    MultiPointState.cache[part] = { result = true, frame = MultiPointState.frame, pos = pos }
                    return true
                end
                local hitParent = hit.Parent
                if hitParent and hitParent:IsA("Accessory") and hitParent.Parent == part.Parent then
                    MultiPointState.cache[part] = { result = true, frame = MultiPointState.frame, pos = pos }
                    return true
                end
            end
        end
    end

    MultiPointState.cache[part] = { result = false, frame = MultiPointState.frame, pos = pos }
    return false
end

local MULTIPOINT_DIRS = {
    { 0, 0, 0 },
    { 1, 1, 1 }, { -1, 1, 1 }, { 1, -1, 1 }, { -1, -1, 1 },
    { 1, 1, -1 }, { -1, 1, -1 }, { 1, -1, -1 }, { -1, -1, -1 },
    { 0, 1, 0 }, { 0, -1, 0 }, { 1, 0, 0 }, { -1, 0, 0 }, { 0, 0, 1 }, { 0, 0, -1 },
    { 1, 1, 0 }, { -1, 1, 0 }, { 1, -1, 0 }, { -1, -1, 0 },
    { 1, 0, 1 }, { -1, 0, 1 }, { 1, 0, -1 }, { -1, 0, -1 },
    { 0, 1, 1 }, { 0, -1, 1 }, { 0, 1, -1 }, { 0, -1, -1 },
}

local function getMultipointPositions(part, scale, maxPoints)
    local size = part.Size
    local cf = part.CFrame
    local s = scale or 0.5
    local fullX = size.X * 0.5
    local fullY = size.Y * 0.5
    local fullZ = size.Z * 0.5
    local numDirs = #MULTIPOINT_DIRS
    local count = math.min(maxPoints or numDirs, 100)

    local allPoints = {}
    for i = 1, count do
        local dirIdx = ((i - 1) % numDirs) + 1
        local fracIdx = math.floor((i - 1) / numDirs)
        local baseFrac = (fracIdx + 1) / (math.floor(count / numDirs) + 1)
        local f = baseFrac * s
        local d = MULTIPOINT_DIRS[dirIdx]
        allPoints[i] = cf:PointToWorldSpace(Vector3.new(
            fullX * f * d[1],
            fullY * f * d[2],
            fullZ * f * d[3]
        ))
    end
    return allPoints
end

local RAGEBOT_ALL_HITBOXES = {
    "HeadHB", "Head", "FakeHead",
    "UpperTorso", "LowerTorso", "Torso", "HumanoidRootPart",
    "LeftUpperArm", "LeftLowerArm", "LeftHand",
    "RightUpperArm", "RightLowerArm", "RightHand",
    "LeftUpperLeg", "LeftLowerLeg", "LeftFoot",
    "RightUpperLeg", "RightLowerLeg", "RightFoot",
}





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
        VisibilityParams.FilterDescendantsInstances = buildRayIgnoreList()
        getgenv().IgnoreRaycastHook = true
        local rayResult = Workspace:Raycast(ray.Origin, ray.Direction * 5000, VisibilityParams)
        getgenv().IgnoreRaycastHook = false
        if rayResult and rayResult.Instance then
            local resultName = rayResult.Instance.Name
            if resultName == "Smoke" or resultName:find("Smoke") or (rayResult.Instance.Material == Enum.Material.Glass and rayResult.Instance.Transparency > 0.5) then
                local smokeIgnore = buildRayIgnoreList()
                table.insert(smokeIgnore, rayResult.Instance)
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

            if hitPlayer and isTriggerEnemy(hitPlayer) then
                local _, humanoid = getCachedCharacterParts(hitPlayer)
                if humanoid and humanoid.Health > 0 then
                    if isStrictRayVisible(hitInstance) then
                        -- smoke check
                        if Toggles.TriggerbotSmokeCheck and Toggles.TriggerbotSmokeCheck.Value then
                            local origin = cam.CFrame.Position
                            local direction = hitInstance.Position - origin
                            VisibilityParams.FilterDescendantsInstances = buildRayIgnoreList()
                            getgenv().IgnoreRaycastHook = true
                            local rayResult = Workspace:Raycast(origin, direction, VisibilityParams)
                            getgenv().IgnoreRaycastHook = false
                            if rayResult and rayResult.Instance then
                                local resultName = rayResult.Instance.Name
                                if resultName == "Smoke" or resultName:find("Smoke") or (rayResult.Instance.Material == Enum.Material.Glass and rayResult.Instance.Transparency > 0.5) then
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

local function isTriggerbotPointVisible(cam, character, part, targetPos)
    local origin = cam.CFrame.Position
    local direction = targetPos - origin
    if direction.Magnitude <= 0.1 then return false end

    VisibilityParams.FilterDescendantsInstances = buildRayIgnoreList()

    getgenv().IgnoreRaycastHook = true
    local ok, rayResult = pcall(function()
        return Workspace:Raycast(origin, direction, VisibilityParams)
    end)
    getgenv().IgnoreRaycastHook = false

    if not ok or not rayResult or not rayResult.Instance then return false end

    local hit = rayResult.Instance
    if Toggles.TriggerbotSmokeCheck and Toggles.TriggerbotSmokeCheck.Value then
        local hitName = hit.Name
        if hitName == "Smoke" or hitName:find("Smoke") or (hit.Material == Enum.Material.Glass and hit.Transparency > 0.5) then
            return false
        end
    end

    if hit == part then return true end
    local hitChar = hit:FindFirstAncestorOfClass("Model")
    return hitChar == character
end

local function findTriggerbotMultipointTarget(cam)
    if not (Toggles.TriggerbotMultiPoint and Toggles.TriggerbotMultiPoint.Value) then return nil end

    local mousePos = UserInputService:GetMouseLocation()
    local bestPart = nil
    local bestDistance = math.huge
    local triggerRadius = 7

    for _, player in ipairs(Players:GetPlayers()) do
        if player == LocalPlayer then continue end
        if not isTriggerEnemy(player) then continue end

        local character = player.Character
        if not character or hasShield(character) then continue end

        local _, humanoid = getCachedCharacterParts(player)
        if not humanoid or humanoid.Health <= 0 then continue end

        for _, partName in ipairs(RAGEBOT_ALL_HITBOXES) do
            local part = findCharacterPart(character, partName)
            if not part then continue end

            for _, point in ipairs(getMultipointPositions(part, (Options.TriggerbotMultiPointScale and Options.TriggerbotMultiPointScale.Value or 50) / 100, Options.TriggerbotMultiPointPoints and Options.TriggerbotMultiPointPoints.Value or 10)) do
                local screenPoint = cam:WorldToViewportPoint(point)
                if screenPoint.Z <= 0 then continue end

                local distance = (Vector2.new(screenPoint.X, screenPoint.Y) - mousePos).Magnitude
                if distance <= triggerRadius and distance < bestDistance then
                    if isTriggerbotPointVisible(cam, character, part, point) then
                        bestDistance = distance
                        bestPart = part
                    end
                end
            end
        end
    end

    return bestPart
end

local function applyTriggerbotMagnet(cam, now)
    if not Toggles.TriggerbotMagnet or not Toggles.TriggerbotMagnet.Value then return end

    local magnetFov = 25
    local smoothFactor = 0.15
    local mousePos = UserInputService:GetMouseLocation()
    local magnetTarget = nil
    local bestDistance = math.huge

    local cached = Cache:get("MagnetTarget")
    if cached ~= nil then
        -- validate cached target is still alive
        local cachedChar = cached and cached.Parent
        local cachedHum = cachedChar and cachedChar:FindFirstChildOfClass("Humanoid")
        if cachedChar and cachedHum and cachedHum.Health > 0 and cached.Parent then
            magnetTarget = cached
        else
            Cache:invalidate("MagnetTarget")
        end
    end
    if not magnetTarget then
        TriggerbotState.LastMagnetScan = now
        for _, player in ipairs(Players:GetPlayers()) do
            if player == LocalPlayer then continue end
            if not isTriggerEnemy(player) then continue end

            local character = player.Character
            if not character then continue end
            local _, humanoid = getCachedCharacterParts(player)
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
        if magnetTarget then
            Cache:set("MagnetTarget", magnetTarget, 0.15)
        else
            Cache:invalidate("MagnetTarget")
        end
    end

    if magnetTarget then
        local targetPosition = magnetTarget.Position
        local targetCF = CFrame.new(cam.CFrame.Position, targetPosition)
        cam.CFrame = cam.CFrame:Lerp(targetCF, smoothFactor)
    end
end


fireSingleShot = function()
    local character = LocalPlayer.Character
    local _, humanoid = getCachedCharacterParts(LocalPlayer)
    if not character or not humanoid or humanoid.Health <= 0 then return end
    if TriggerbotState.IsFiring then return end

    local mouse = LocalPlayer:GetMouse()
    local mouseX = mouse.X
    local mouseY = mouse.Y

    local holdMs = Options.TriggerbotHoldTime and Options.TriggerbotHoldTime.Value or 50
    local intervalMs = Options.TriggerbotInterval and Options.TriggerbotInterval.Value or 150
    TriggerbotState.NextFireTime = tick() + (intervalMs / 1000)
    TriggerbotState.IsFiring = true
    task.spawn(function()
        pcall(function()
            VirtualInputManager:SendMouseButtonEvent(mouseX, mouseY, 0, true, game, 1)
            task.wait(holdMs / 1000)
            VirtualInputManager:SendMouseButtonEvent(mouseX, mouseY, 0, false, game, 1)
        end)
        TriggerbotState.IsFiring = false
    end)
end


local function updateTriggerbot()
    if Library and Library.IsMenuVisible and Library:IsMenuVisible() then return end
    local cam = getCamera()
    if not cam then return end

    local character = LocalPlayer.Character
    local _, humanoid = getCachedCharacterParts(LocalPlayer)
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

    local targetPart = findTriggerbotTarget(cam) or findTriggerbotMultipointTarget(cam)

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
        local delayMs = (Options.TriggerbotDelay and Options.TriggerbotDelay.Value) or 0
        if not TriggerbotState.DelayActive then
            TriggerbotState.DelayActive = true
            TriggerbotState.DelayUntil = currentTime + (delayMs / 1000)
        end
        if currentTime >= TriggerbotState.DelayUntil and currentTime >= TriggerbotState.NextFireTime then
            fireSingleShot()
        end
    else
        TriggerbotState.DelayActive = false
        TriggerbotState.NextFireTime = 0
        TriggerbotState.IsFiring = false
    end
end


local AntiAimState = {
    CFrame = CFrame.new(),
    PitchRandomAngle = 0,
    PitchRandomLastSwitch = 0,
    YawBaseAngle = 0,
    YawCurrentAngle = 0,
    YawJitterPoints = {},
    YawJitterLastSwitch = 0,
    YawJitterFlip = false,
    YawJitterIndex = 1,
    YawRandomAngle = 0,
    YawRandomLastSwitch = 0,
    YawSpinAngle = 0,
    YawSpinLastUpdate = 0
}


local function updateAntiAim()
    local enabled = Toggles.AntiAimPitchEnable and Toggles.AntiAimPitchEnable.Value
    local character = LocalPlayer.Character
    if not character then return end
    local _, humanoid, rootPart = getCachedCharacterParts(LocalPlayer)
    if not humanoid or not rootPart or humanoid.Health <= 0 then return end

    if not enabled then
        humanoid.AutoRotate = true
        humanoid.HipHeight = 2
        return
    end

    humanoid.AutoRotate = false
    humanoid.HipHeight = 2

    local pitchMode = Options.AntiAimPitchMode and Options.AntiAimPitchMode.Value or "None"
    if pitchMode ~= "None" then
        local remote = getControlTurnRemote()
        if remote then
            local pitch = 0
            if pitchMode == "Down" then
                pitch = -1
            elseif pitchMode == "Up" then
                pitch = 1
            elseif pitchMode == "Custom" then
                pitch = Options.AntiAimPitchCustom and Options.AntiAimPitchCustom.Value or 0
            elseif pitchMode == "Random" then
                local pitchSpeedMs = Options.AntiAimPitchRandomSpeed and Options.AntiAimPitchRandomSpeed.Value or 1
                if (tick() - AntiAimState.PitchRandomLastSwitch) * 1000 >= pitchSpeedMs then
                    local newPitch = math.random(-10, 10) / 10
                    while math.abs(newPitch - AntiAimState.PitchRandomAngle) < 0.2 do
                        newPitch = math.random(-10, 10) / 10
                    end
                    AntiAimState.PitchRandomAngle = newPitch
                    AntiAimState.PitchRandomLastSwitch = tick()
                end
                pitch = AntiAimState.PitchRandomAngle
            end
            pcall(function() remote:FireServer(pitch) end)
        end
    end

    local yawEnabled = Toggles.AntiAimYawEnable and Toggles.AntiAimYawEnable.Value
    if yawEnabled then
        local yawTarget = Options.AntiAimYawMode and Options.AntiAimYawMode.Value or "Local"
        local baseYaw = 0
        if yawTarget == "Local" then
            local cam = Workspace.CurrentCamera
            if cam then
                local lookVector = cam.CFrame.LookVector
                baseYaw = math.deg(math.atan2(lookVector.X, lookVector.Z))
            end
        else
            local useTeamCheck = Toggles.RagebotTeamCheck and Toggles.RagebotTeamCheck.Value
            local bestPart, bestDist = nil, math.huge
            for _, plr in ipairs(Players:GetPlayers()) do
                if plr == LocalPlayer then continue end
                if useTeamCheck then
                    local myTeam, theirTeam = LocalPlayer.Team, plr.Team
                    if myTeam and theirTeam and theirTeam == myTeam then continue end
                end
                local ch = plr.Character
                local hrpTarget = ch and ch:FindFirstChild("HumanoidRootPart")
                local humTarget = ch and ch:FindFirstChildOfClass("Humanoid")
                if hrpTarget and humTarget and humTarget.Health > 0 then
                    local d = (hrpTarget.Position - rootPart.Position).Magnitude
                    if d < bestDist then bestDist = d; bestPart = hrpTarget end
                end
            end
            if bestPart then
                local dir = (bestPart.Position - rootPart.Position) * Vector3.new(1, 0, 1)
                if dir.Magnitude > 0.1 then
                    baseYaw = math.deg(math.atan2(dir.X, dir.Z))
                end
            end
        end
        AntiAimState.YawBaseAngle = baseYaw

        local yawType = Options.AntiAimYawType and Options.AntiAimYawType.Value or "None"
        local yawDirection = Options.AntiAimYawDirection and Options.AntiAimYawDirection.Value or "Backwards"
        local yawAngle = baseYaw

        if yawDirection == "Backwards" then
            yawAngle = baseYaw
        elseif yawDirection == "Forwards" then
            yawAngle = baseYaw + 180
        end

        if yawType == "Custom" then
            local customYaw = Options.AntiAimYawCustom and Options.AntiAimYawCustom.Value or 0
            yawAngle = yawAngle + customYaw
        elseif yawType == "Jitter" then
            local jitterValue = Options.AntiAimYawJitterAngle and Options.AntiAimYawJitterAngle.Value or 90
            local jitterSpeed = Options.AntiAimYawJitterDelay and Options.AntiAimYawJitterDelay.Value or 100

            if (tick() - AntiAimState.YawJitterLastSwitch) * 1000 >= jitterSpeed then
                AntiAimState.YawJitterFlip = not AntiAimState.YawJitterFlip
                AntiAimState.YawJitterLastSwitch = tick()
            end
            yawAngle = yawAngle + (AntiAimState.YawJitterFlip and jitterValue or -jitterValue)
        elseif yawType == "Jitter 3 way" then
            local jitterValue = Options.AntiAimYawJitterAngle and Options.AntiAimYawJitterAngle.Value or 90
            local jitterSpeed = Options.AntiAimYawJitterDelay and Options.AntiAimYawJitterDelay.Value or 100

            if #AntiAimState.YawJitterPoints ~= 3 then
                AntiAimState.YawJitterPoints = {}
                for i = 1, 3 do
                    AntiAimState.YawJitterPoints[i] = math.random(-jitterValue, jitterValue)
                end
                AntiAimState.YawJitterIndex = math.random(1, 3)
            end
            if (tick() - AntiAimState.YawJitterLastSwitch) * 1000 >= jitterSpeed then
                for i = 1, 3 do
                    AntiAimState.YawJitterPoints[i] = math.random(-jitterValue, jitterValue)
                end
                AntiAimState.YawJitterIndex = math.random(1, 3)
                AntiAimState.YawJitterLastSwitch = tick()
            end
            yawAngle = yawAngle + AntiAimState.YawJitterPoints[AntiAimState.YawJitterIndex]
        elseif yawType == "Jitter 5 way" then
            local jitterValue = Options.AntiAimYawJitterAngle and Options.AntiAimYawJitterAngle.Value or 90
            local jitterSpeed = Options.AntiAimYawJitterDelay and Options.AntiAimYawJitterDelay.Value or 100

            if #AntiAimState.YawJitterPoints ~= 5 then
                AntiAimState.YawJitterPoints = {}
                for i = 1, 5 do
                    AntiAimState.YawJitterPoints[i] = math.random(-jitterValue, jitterValue)
                end
                AntiAimState.YawJitterIndex = math.random(1, 5)
            end
            if (tick() - AntiAimState.YawJitterLastSwitch) * 1000 >= jitterSpeed then
                for i = 1, 5 do
                    AntiAimState.YawJitterPoints[i] = math.random(-jitterValue, jitterValue)
                end
                AntiAimState.YawJitterIndex = math.random(1, 5)
                AntiAimState.YawJitterLastSwitch = tick()
            end
            yawAngle = yawAngle + AntiAimState.YawJitterPoints[AntiAimState.YawJitterIndex]
        elseif yawType == "Random" then
            local randomSpeed = Options.AntiAimYawRandomDelay and Options.AntiAimYawRandomDelay.Value or 200
            if (tick() - AntiAimState.YawRandomLastSwitch) * 1000 >= randomSpeed then
                AntiAimState.YawRandomAngle = math.random(0, 360)
                AntiAimState.YawRandomLastSwitch = tick()
            end
            yawAngle = yawAngle + AntiAimState.YawRandomAngle
        elseif yawType == "Spin" then
            local spinSpeed = Options.AntiAimYawSpinDelay and Options.AntiAimYawSpinDelay.Value or 5
            local now = tick()
            if spinSpeed > 0 then
                local deltaTime = (now - AntiAimState.YawSpinLastUpdate) * 1000
                AntiAimState.YawSpinAngle = (AntiAimState.YawSpinAngle + (deltaTime / spinSpeed) * 360) % 360
                AntiAimState.YawSpinLastUpdate = now
            end
            yawAngle = yawAngle + AntiAimState.YawSpinAngle
        end

        rootPart.CFrame = CFrame.new(rootPart.Position, rootPart.Position + Vector3.new(0, 0, -1)) * CFrame.Angles(0, math.rad(yawAngle), 0)
    end


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
    local equippedToolValue = getLocalEquippedTool()
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

    -- No recoil takes precedence; avoid fighting over the same Recoil value
    if Toggles.GunModsNoRecoil and Toggles.GunModsNoRecoil.Value then return end

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
local KillAllHitRemote
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
    local _, humanoid = getCachedCharacterParts(LocalPlayer)
    if not humanoid or humanoid.Health <= 0 then return end

    local gun = character:FindFirstChild("Gun")
    local equippedToolValue = getLocalEquippedTool()
    if not gun or not equippedToolValue then return end

    local gunName = "AWP"
    local gunRef = gun
    local replicatedStorageWeapons = getWeaponsFolder()
    local awpFolder = replicatedStorageWeapons and replicatedStorageWeapons:FindFirstChild("AWP")
    if awpFolder then gunRef = awpFolder end

    local cam = getCamera()
    if not cam then return end
    local camPos = cam.CFrame.Position
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

        local head = getCachedHead(plr, playerCharacter)
        local _, playerHumanoid = getCachedCharacterParts(plr)
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

local MoveUtil = {}

;(function()
local MOVE_KEY_W = Enum.KeyCode.W
local MOVE_KEY_A = Enum.KeyCode.A
local MOVE_KEY_S = Enum.KeyCode.S
local MOVE_KEY_D = Enum.KeyCode.D
local MOVE_KEY_SPACE = Enum.KeyCode.Space
local MOVE_KEY_SHIFT = Enum.KeyCode.LeftShift
local MOVE_KEY_CTRL = Enum.KeyCode.LeftControl
local AIR_MATERIAL = Enum.Material.Air

local function getLocalHumanoid()
    local _, humanoid = getCachedCharacterParts(LocalPlayer)
    return humanoid
end

local function getAliveMovementRig()
    local character = LocalPlayer.Character
    if not character or not character.Parent then return nil end

    local _, humanoid, rootPart = getCachedCharacterParts(LocalPlayer)
    if not humanoid then return nil end
    
    -- Check if humanoid is dead (Health <= 0 or health is 0)
    if humanoid.Health <= 0 then return nil end
    
    -- Check if character is still in workspace (not destroyed)
    if not character:IsDescendantOf(Workspace) then return nil end

    if not rootPart then return nil end

    return character, humanoid, rootPart
end

local function getMoveAxes()
    local fwd = (UserInputService:IsKeyDown(MOVE_KEY_W) and 1 or 0) - (UserInputService:IsKeyDown(MOVE_KEY_S) and 1 or 0)
    local strafe = (UserInputService:IsKeyDown(MOVE_KEY_D) and 1 or 0) - (UserInputService:IsKeyDown(MOVE_KEY_A) and 1 or 0)
    return fwd, strafe
end

local function getHorizontalCameraDirection(camCFrame, fwd, strafe)
    if fwd == 0 and strafe == 0 then return nil, camCFrame.LookVector end

    local camLook = camCFrame.LookVector
    local camRight = camCFrame.RightVector
    local x = camLook.X * fwd + camRight.X * strafe
    local z = camLook.Z * fwd + camRight.Z * strafe
    local magSq = x * x + z * z
    if magSq <= 0.0001 then return nil, camLook end

    local invMag = 1 / math.sqrt(magSq)
    return Vector3.new(x * invMag, 0, z * invMag), camLook
end

MoveUtil.applyCameraCFrameMove = function(rootPart, cam, speed, dt)
    local fwd, strafe = getMoveAxes()
    local direction, camLook = getHorizontalCameraDirection(cam.CFrame, fwd, strafe)
    if not direction then return end

    local newPos = rootPart.Position + direction * (speed * dt)
    rootPart.CFrame = CFrame.new(newPos, newPos + camLook)
end

MoveUtil.applyFlyMove = function(rootPart, camCFrame, speed, dt)
    local fwd, strafe = getMoveAxes()
    local vert = (UserInputService:IsKeyDown(MOVE_KEY_SPACE) and 1 or 0) - (UserInputService:IsKeyDown(MOVE_KEY_SHIFT) and 1 or 0)
    if fwd == 0 and strafe == 0 and vert == 0 then return end

    local camLook = camCFrame.LookVector
    local camRight = camCFrame.RightVector
    local x = camLook.X * fwd + camRight.X * strafe
    local y = camLook.Y * fwd + camRight.Y * strafe + vert
    local z = camLook.Z * fwd + camRight.Z * strafe
    local magSq = x * x + y * y + z * z
    if magSq <= 0 then return end

    rootPart.CFrame = rootPart.CFrame + (Vector3.new(x, y, z) * (speed * dt / math.sqrt(magSq)))
end

MoveUtil.getLocalHumanoid = getLocalHumanoid
MoveUtil.getAliveMovementRig = getAliveMovementRig
MoveUtil.MOVE_KEY_SPACE = MOVE_KEY_SPACE
MoveUtil.MOVE_KEY_CTRL = MOVE_KEY_CTRL
MoveUtil.AIR_MATERIAL = AIR_MATERIAL
MoveUtil.ZERO_VECTOR = Vector3.new(0, 0, 0)
end)()

local SpeedHackState, BhopState, LegitBhopState, AutoCrouchState, NoclipState, FlyState, AutoJumpState
local CrosshairState, VMState, SkyboxState, SKYBOX_PRESETS, AmbienceSavedLighting, MiscState
local ThirdPersonNoClipConn, ThirdPersonCache
local restoreSpeedHackOriginal, restoreNoclipParts, restoreFlyPhysics, clearNoclipRuntime
local updateAmbience, updateFovCircle, ensureFovCircles, updateThirdPersonNoClip
local removeDrawingSet, removeHighlight, updatePlayerEsp, updateItemEsp, updatePlayerChams
local getMovementStateText, getDrawingSet, hideDrawingSet, setCornerSeg
local pushHitLog

;(function()
SpeedHackState = { Conn = nil, OrigSpeed = nil, Humanoid = nil }

restoreSpeedHackOriginal = function()
    local humanoid = SpeedHackState.Humanoid
    if (not humanoid or not humanoid.Parent) then
        humanoid = MoveUtil.getLocalHumanoid()
    end

    if humanoid and SpeedHackState.OrigSpeed ~= nil then
        humanoid.WalkSpeed = SpeedHackState.OrigSpeed
    end

    SpeedHackState.OrigSpeed = nil
    SpeedHackState.Humanoid = nil
end

updateSpeedHack = function()
    if SpeedHackState.Conn then
        SpeedHackState.Conn:Disconnect()
        SpeedHackState.Conn = nil
    end
    if not (Toggles.SpeedHackEnable and Toggles.SpeedHackEnable.Value) then
        pcall(restoreSpeedHackOriginal)
        return
    end

    SpeedHackState.Conn = RunService.RenderStepped:Connect(function(dt)
        if not isKeybindActive(Options.SpeedHackKeybind) then
            restoreSpeedHackOriginal()
            return
        end

        local _, hum, hrp = MoveUtil.getAliveMovementRig()
        if not hum or not hrp then return end

        if SpeedHackState.Humanoid ~= hum then
            if SpeedHackState.Humanoid and SpeedHackState.Humanoid.Parent and SpeedHackState.OrigSpeed ~= nil then
                SpeedHackState.Humanoid.WalkSpeed = SpeedHackState.OrigSpeed
            end
            SpeedHackState.Humanoid = hum
            SpeedHackState.OrigSpeed = hum.WalkSpeed
        elseif SpeedHackState.OrigSpeed == nil then
            SpeedHackState.OrigSpeed = hum.WalkSpeed
        end

        local speed = Options.SpeedHackSpeed and Options.SpeedHackSpeed.Value or 50
        hum.WalkSpeed = speed

        local cam = getCamera()
        if not cam then return end
        MoveUtil.applyCameraCFrameMove(hrp, cam, speed, dt)
    end)
end

AutoCrouchState = { Conn = nil, WasInAir = false }

updateAutoCrouch = function()
    if AutoCrouchState.Conn then
        AutoCrouchState.Conn:Disconnect()
        AutoCrouchState.Conn = nil
    end
    AutoCrouchState.WasInAir = false
    if not (Toggles.AutoCrouchEnable and Toggles.AutoCrouchEnable.Value) then
        VirtualInputManager:SendKeyEvent(false, MoveUtil.MOVE_KEY_CTRL, false, game)
        return
    end

    AutoCrouchState.Conn = RunService.RenderStepped:Connect(function()
        local _, hum = MoveUtil.getAliveMovementRig()
        if not hum then return end
        local inAir = hum.FloorMaterial == MoveUtil.AIR_MATERIAL
        if inAir and not AutoCrouchState.WasInAir then
            VirtualInputManager:SendKeyEvent(true, MoveUtil.MOVE_KEY_CTRL, false, game)
            AutoCrouchState.WasInAir = true
        elseif not inAir and AutoCrouchState.WasInAir then
            VirtualInputManager:SendKeyEvent(false, MoveUtil.MOVE_KEY_CTRL, false, game)
            AutoCrouchState.WasInAir = false
        end
    end)
end

BhopState = { Conn = nil }
LegitBhopState = { Conn = nil, JumpCount = 0, WasInAir = false, DefaultSpeed = 16 }
AutoJumpState = { Conn = nil }
NoclipState = { Conn = nil, DescendantConn = nil, Saved = {}, Parts = {}, Character = nil }
FlyState = { Conn = nil }

updateBhop = function()
    if BhopState.Conn then
        BhopState.Conn:Disconnect()
        BhopState.Conn = nil
    end
    local humanoid = MoveUtil.getLocalHumanoid()
    if humanoid then
        humanoid.WalkSpeed = CONSTANTS.DEFAULT_WALK_SPEED
    end
    if not (Toggles.BhopEnable and Toggles.BhopEnable.Value) then return end

    BhopState.Conn = RunService.RenderStepped:Connect(function(dt)
        local _, hum, rootPart = MoveUtil.getAliveMovementRig()
        if not rootPart then return end

        local spaceHeld = UserInputService:IsKeyDown(MoveUtil.MOVE_KEY_SPACE)

        if not spaceHeld then
            hum.WalkSpeed = CONSTANTS.DEFAULT_WALK_SPEED
            return
        end

        if hum.FloorMaterial ~= MoveUtil.AIR_MATERIAL then
            hum.Jump = true
        end

        local multiplier = Options.BhopMultiplier and Options.BhopMultiplier.Value or 1
        if not multiplier or multiplier <= 0 then multiplier = 1 end
        local targetSpeed = CONSTANTS.DEFAULT_WALK_SPEED * multiplier
        hum.WalkSpeed = targetSpeed

        if multiplier > 1 then
            local cam = getCamera()
            if cam then
                local boostSpeed = targetSpeed - CONSTANTS.DEFAULT_WALK_SPEED
                MoveUtil.applyCameraCFrameMove(rootPart, cam, boostSpeed, dt)
            end
        end
    end)
end


updateLegitBhop = function()
    if LegitBhopState.Conn then
        LegitBhopState.Conn:Disconnect()
        LegitBhopState.Conn = nil
    end
    LegitBhopState.JumpCount = 0
    LegitBhopState.WasInAir = false
    local humanoid = MoveUtil.getLocalHumanoid()
    if humanoid then
        humanoid.WalkSpeed = CONSTANTS.DEFAULT_WALK_SPEED
    end
    if not (Toggles.LegitBhopEnable and Toggles.LegitBhopEnable.Value) then return end

    LegitBhopState.Conn = RunService.RenderStepped:Connect(function()
        local _, hum, rootPart = MoveUtil.getAliveMovementRig()
        if not hum or not rootPart then return end

        if not UserInputService:IsKeyDown(MoveUtil.MOVE_KEY_SPACE) then
            LegitBhopState.JumpCount = 0
            LegitBhopState.WasInAir = hum.FloorMaterial == MoveUtil.AIR_MATERIAL
            hum.WalkSpeed = CONSTANTS.DEFAULT_WALK_SPEED
            return
        end

        local inAir = hum.FloorMaterial == MoveUtil.AIR_MATERIAL

        if inAir then
            LegitBhopState.WasInAir = true
        elseif LegitBhopState.WasInAir then
            hum.Jump = true
            LegitBhopState.JumpCount = math.min(LegitBhopState.JumpCount + 1, 15)
            LegitBhopState.WasInAir = false
        else
            hum.Jump = true
        end

        local maxMult = Options.LegitBhopMultiplier and Options.LegitBhopMultiplier.Value or 2
        if not maxMult or maxMult < 1 then maxMult = 1 end
        local multiplier = 1 + (LegitBhopState.JumpCount / 15) * (maxMult - 1)
        local targetSpeed = CONSTANTS.DEFAULT_WALK_SPEED * multiplier
        hum.WalkSpeed = targetSpeed
    end)
end


clearNoclipRuntime = function()
    if NoclipState.DescendantConn then
        NoclipState.DescendantConn:Disconnect()
        NoclipState.DescendantConn = nil
    end
    NoclipState.Character = nil
    NoclipState.Parts = {}
end

restoreNoclipParts = function()
    for part, canCollide in pairs(NoclipState.Saved) do
        if part and part.Parent then part.CanCollide = canCollide end
    end
    NoclipState.Saved = {}
    clearNoclipRuntime()
end

local function trackNoclipPart(part)
    if not part:IsA("BasePart") then return end
    if NoclipState.Saved[part] == nil then
        NoclipState.Saved[part] = part.CanCollide
        NoclipState.Parts[#NoclipState.Parts + 1] = part
    end
    if part.CanCollide then
        part.CanCollide = false
    end
end

local function setNoclipCharacter(character)
    if NoclipState.Character == character then return end
    clearNoclipRuntime()
    NoclipState.Character = character

    for _, part in ipairs(character:GetDescendants()) do
        trackNoclipPart(part)
    end

    NoclipState.DescendantConn = character.DescendantAdded:Connect(trackNoclipPart)
end

updateNoclip = function()
    if NoclipState.Conn then
        NoclipState.Conn:Disconnect()
        NoclipState.Conn = nil
    end

    restoreNoclipParts()

    if not (Toggles.NoclipEnable and Toggles.NoclipEnable.Value) then return end

    NoclipState.Conn = RunService.Stepped:Connect(function()
        local character = LocalPlayer.Character
        if not character then return end

        setNoclipCharacter(character)
        local parts = NoclipState.Parts
        for i = #parts, 1, -1 do
            local part = parts[i]
            if part and part.Parent then
                if part.CanCollide then
                    part.CanCollide = false
                end
            else
                table.remove(parts, i)
            end
        end
    end)
end


restoreFlyPhysics = function()
    local hum = MoveUtil.getLocalHumanoid()
    if hum then hum.PlatformStand = false end
end

updateFly = function()
    if FlyState.Conn then
        FlyState.Conn:Disconnect()
        FlyState.Conn = nil
    end

    pcall(restoreFlyPhysics)

    if not (Toggles.FlyEnable and Toggles.FlyEnable.Value) then return end

    FlyState.Conn = RunService.RenderStepped:Connect(function(dt)
        local _, humanoid, rootPart = MoveUtil.getAliveMovementRig()
        if not rootPart then
            if humanoid then humanoid.PlatformStand = false end
            return
        end

        humanoid.PlatformStand = true

        local cam = getCamera()
        if not cam then return end

        local speed = Options.FlySpeed and Options.FlySpeed.Value or 50
        MoveUtil.applyFlyMove(rootPart, cam.CFrame, speed, dt)
        rootPart.AssemblyLinearVelocity = MoveUtil.ZERO_VECTOR
    end)
end


ThirdPersonCache = { arms = nil, parts = nil, lastHideState = nil }

updateThirdPerson = function()
    local thirdPersonEnabled = Toggles.ThirdPersonEnable and Toggles.ThirdPersonEnable.Value
    local isKeyActive = isKeybindActive(Options.ThirdPersonKeybind)
    local isThirdPersonActive = thirdPersonEnabled and isKeyActive
    local targetDist = isThirdPersonActive and (Options.ThirdPersonDistance and Options.ThirdPersonDistance.Value or 5) or 0.5

    LocalPlayer.CameraMaxZoomDistance = targetDist
    LocalPlayer.CameraMinZoomDistance = targetDist

    local character = LocalPlayer.Character
    local _, humanoid = getCachedCharacterParts(LocalPlayer)
    if humanoid then
        humanoid.AutoRotate = not isThirdPersonActive
    end

    -- hide / show viewmodel (Arms)
    local cam = getCamera()
    if cam then
        local arms = cam:FindFirstChild("Arms")
        if arms then
            local hideVM = Toggles.ThirdPersonHideVM and Toggles.ThirdPersonHideVM.Value
            local hideState = isThirdPersonActive and hideVM
            if arms ~= ThirdPersonCache.arms then
                ThirdPersonCache.arms = arms
                ThirdPersonCache.parts = nil
                for _, part in ipairs(arms:GetDescendants()) do
                    if part:IsA("BasePart") or part:IsA("MeshPart") then
                        if not ThirdPersonCache.parts then ThirdPersonCache.parts = {} end
                        ThirdPersonCache.parts[#ThirdPersonCache.parts + 1] = part
                    end
                end
                ThirdPersonCache.lastHideState = nil
            end
            if ThirdPersonCache.parts and hideState ~= ThirdPersonCache.lastHideState then
                ThirdPersonCache.lastHideState = hideState
                local ltm = hideState and 1 or 0
                for i = 1, #ThirdPersonCache.parts do
                    ThirdPersonCache.parts[i].LocalTransparencyModifier = ltm
                end
            end
        end
    end

    -- camera through walls: manually position camera behind player, bypassing wall clipping
    -- (handled by ThirdPersonNoClipConn below)
end

ThirdPersonNoClipConn = nil
updateThirdPersonNoClip = function()
    if ThirdPersonNoClipConn then
        ThirdPersonNoClipConn:Disconnect()
        ThirdPersonNoClipConn = nil
    end
    if not (Toggles.ThirdPersonEnable and Toggles.ThirdPersonEnable.Value
        and Toggles.ThirdPersonNoClip and Toggles.ThirdPersonNoClip.Value) then return end

    ThirdPersonNoClipConn = RunService:BindToRenderStep("ValenokTPNoClip", Enum.RenderPriority.Camera.Value + 1, function()
        local tpEnabled = Toggles.ThirdPersonEnable and Toggles.ThirdPersonEnable.Value
        local isKeyActive = isKeybindActive(Options.ThirdPersonKeybind)
        if not (tpEnabled and isKeyActive) then return end

        local cam = getCamera()
        if not cam then return end
        local char = LocalPlayer.Character
        if not char then return end
        local _, hum, hrp = getCachedCharacterParts(LocalPlayer)
        if not hrp or not hum or hum.Health <= 0 then return end

        local dist = Options.ThirdPersonDistance and Options.ThirdPersonDistance.Value or 5
        local lookDir = cam.CFrame.LookVector
        local camPos = hrp.Position - lookDir * dist + Vector3.new(0, 2, 0)
        cam.CFrame = CFrame.new(camPos) * cam.CFrame.Rotation
    end)
end


updateAutoJump = function()
    if AutoJumpState.Conn then
        AutoJumpState.Conn:Disconnect()
        AutoJumpState.Conn = nil
    end
    if not (Toggles.AutoJumpEnable and Toggles.AutoJumpEnable.Value) then return end

    AutoJumpState.Conn = RunService.RenderStepped:Connect(function()
        if not UserInputService:IsKeyDown(MoveUtil.MOVE_KEY_SPACE) then return end

        local _, humanoid = MoveUtil.getAliveMovementRig()
        if not humanoid then return end

        humanoid.Jump = true
    end)
end




-- visuals

AmbienceSavedLighting = nil
MiscState = { ambienceDirty = false }



setCornerSeg = function(line, outline, fx, fy, tx, ty, color, visible)
    line.From = Vector2.new(fx, fy); line.To = Vector2.new(tx, ty)
    line.Color = color; line.Visible = visible
    outline.From = line.From; outline.To = line.To; outline.Visible = visible
end

hideDrawingSet = function(drawingSet, resetRect)
    if not drawingSet then return end

    drawingSet.Box.Visible = false
    drawingSet.BoxFill.Visible = false
    drawingSet.Name.Visible = false
    drawingSet.Weapon.Visible = false
    drawingSet.HealthBarOutline.Visible = false
    drawingSet.HealthBarFill.Visible = false
    drawingSet.HealthText.Visible = false
    for i = 1, 8 do
        if drawingSet.CornerLines[i] then drawingSet.CornerLines[i].Visible = false end
        if drawingSet.CornerOutlines and drawingSet.CornerOutlines[i] then drawingSet.CornerOutlines[i].Visible = false end
    end
    if drawingSet.SkeletonLines then
        for _, ln in ipairs(drawingSet.SkeletonLines) do ln.Visible = false end
    end
    if drawingSet.SkeletonOutlines then
        for _, ln in ipairs(drawingSet.SkeletonOutlines) do ln.Visible = false end
    end

    if resetRect then
        drawingSet.Rect = nil
    end
end


removeDrawingSet = function(player)
    local drawingSet = EspRuntime.Drawings[player]
    if not drawingSet then return end

    for _, item in drawingSet do
        if type(item) == "userdata" and item.Remove then
            item.Visible = false; item:Remove()
        elseif type(item) == "table" then
            for _, subItem in ipairs(item) do
                if type(subItem) == "userdata" and subItem.Remove then
                    subItem.Visible = false; subItem:Remove()
                end
            end
        end
    end

    EspRuntime.Drawings[player] = nil
end


removeHighlight = function(player)
    local highlight = EspRuntime.Highlights[player]
    if not highlight then return end

    highlight:Destroy()
    EspRuntime.Highlights[player] = nil
end


getDrawingSet = function(player)
    local drawingSet = EspRuntime.Drawings[player]
    if drawingSet then return drawingSet end

    drawingSet = {
        Box = createSquare(1.1, Color3.fromRGB(255, 255, 255)),
        BoxFill = createSquare(1, Color3.fromRGB(255, 255, 255)),
        Name = createText(13),
        Weapon = createText(13),
        Rect = nil,
        HealthBarOutline = createSquare(0.5, Color3.fromRGB(0, 0, 0)),
        HealthBarFill = createSquare(1, Color3.fromRGB(0, 255, 0)),
        HealthText = createText(13),
        CornerLines = {
            createLine(1.1, Color3.fromRGB(255,255,255)), createLine(1.1, Color3.fromRGB(255,255,255)),
            createLine(1.1, Color3.fromRGB(255,255,255)), createLine(1.1, Color3.fromRGB(255,255,255)),
            createLine(1.1, Color3.fromRGB(255,255,255)), createLine(1.1, Color3.fromRGB(255,255,255)),
            createLine(1.1, Color3.fromRGB(255,255,255)), createLine(1.1, Color3.fromRGB(255,255,255)),
        },
        CornerOutlines = {
            createLine(3, Color3.fromRGB(0,0,0)), createLine(3, Color3.fromRGB(0,0,0)),
            createLine(3, Color3.fromRGB(0,0,0)), createLine(3, Color3.fromRGB(0,0,0)),
            createLine(3, Color3.fromRGB(0,0,0)), createLine(3, Color3.fromRGB(0,0,0)),
            createLine(3, Color3.fromRGB(0,0,0)), createLine(3, Color3.fromRGB(0,0,0)),
        },
    }
    drawingSet.BoxFill.Filled = true

    -- set ZIndex so color lines render on top of outlines
    for i = 1, 8 do
        if drawingSet.CornerOutlines[i] then drawingSet.CornerOutlines[i].ZIndex = 1 end
        if drawingSet.CornerLines[i] then drawingSet.CornerLines[i].ZIndex = 2 end
    end

    local boneCount = #CONSTANTS.SkeletonBones
    drawingSet.SkeletonLines = {}
    drawingSet.SkeletonOutlines = {}
    for i = 1, boneCount do
        local sl = createLine(1, Color3.fromRGB(255, 255, 255))
        sl.ZIndex = 4
        drawingSet.SkeletonLines[i] = sl
        local so = createLine(3, Color3.fromRGB(0, 0, 0))
        so.ZIndex = 3
        drawingSet.SkeletonOutlines[i] = so
    end

    EspRuntime.Drawings[player] = drawingSet
    return drawingSet
end


updatePlayerChams = function(player, character)
    if player == LocalPlayer or not character then
        removeHighlight(player)
        return
    end

    local showChams = EspFrameCache.toggles.chams
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

    if highlight.Adornee ~= character then highlight.Adornee = character end
    if highlight.Parent ~= character then highlight.Parent = character end

    highlight.FillColor = EspFrameCache.colors.chamsFill
    highlight.FillTransparency = EspFrameCache.chamsTransparency
    if EspFrameCache.toggles.chamsOutline then
        highlight.OutlineTransparency = 0
        highlight.OutlineColor = EspFrameCache.colors.chamsOutline
    else
        highlight.OutlineTransparency = 1
    end
    highlight.Enabled = true
end


updatePlayerEsp = function(player)
    if not player or not player.Parent then return end

    if player == LocalPlayer then
        local drawingSet = EspRuntime.Drawings[player]
        if drawingSet then hideDrawingSet(drawingSet, true) end
        return
    end

    if not EspFrameCache.anyEnabled then
        local drawingSet = EspRuntime.Drawings[player]
        if drawingSet then hideDrawingSet(drawingSet, true) end
        updatePlayerChams(player, nil)
        return
    end

    local drawingSet = getDrawingSet(player)

    if EspFrameCache.toggles.teamCheck then
        local myTeam, theirTeam = LocalPlayer.Team, player.Team
        if myTeam ~= nil and theirTeam ~= nil and theirTeam == myTeam then
            hideDrawingSet(drawingSet, true)
            updatePlayerChams(player, nil)
            return
        end
    end

    local character, humanoid, rootPart = getCachedCharacterParts(player)
    if not character then
        updatePlayerChams(player, nil)
        hideDrawingSet(drawingSet, true)
        return
    end

    local left, top, width, height = getCharacterScreenBox(character, humanoid, rootPart)
    if not left then
        hideDrawingSet(drawingSet, true)
        local highlight = EspRuntime.Highlights[player]
        if highlight then highlight.Enabled = false end
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

    local showBox = EspFrameCache.toggles.box
    local showName = EspFrameCache.toggles.name
    local boxType = EspFrameCache.options.boxType
    local showBoxFill = EspFrameCache.toggles.boxFill

    local boxColor = EspFrameCache.colors.box
    local nameColor = EspFrameCache.colors.name

    if boxType == "Corner" then
        drawingSet.Box.Visible = false

        -- proportional corner length: 25% of min dimension, clamped 4-12px
        -- this ensures corners never merge together regardless of distance
        local cl = math.clamp(math.min(width, height) * 0.25, 4, 12)
        local right, bot = left + width, top + height
        local cl_, co_ = drawingSet.CornerLines, drawingSet.CornerOutlines

        setCornerSeg(cl_[1], co_[1], left, top, left + cl, top, boxColor, showBox)   -- top-left horizontal
        setCornerSeg(cl_[2], co_[2], left, top, left, top + cl, boxColor, showBox)   -- top-left vertical
        setCornerSeg(cl_[3], co_[3], right, top, right - cl, top, boxColor, showBox) -- top-right horizontal
        setCornerSeg(cl_[4], co_[4], right, top, right, top + cl, boxColor, showBox) -- top-right vertical
        setCornerSeg(cl_[5], co_[5], left, bot, left + cl, bot, boxColor, showBox)   -- bottom-left horizontal
        setCornerSeg(cl_[6], co_[6], left, bot, left, bot - cl, boxColor, showBox)   -- bottom-left vertical
        setCornerSeg(cl_[7], co_[7], right, bot, right - cl, bot, boxColor, showBox) -- bottom-right horizontal
        setCornerSeg(cl_[8], co_[8], right, bot, right, bot - cl, boxColor, showBox) -- bottom-right vertical
    else
        for i = 1, 8 do
            drawingSet.CornerLines[i].Visible = false
            drawingSet.CornerOutlines[i].Visible = false
        end

        drawingSet.Box.Position = Vector2.new(left, top)
        drawingSet.Box.Size = Vector2.new(width, height)
        drawingSet.Box.Color = boxColor
        drawingSet.Box.Visible = showBox
    end

    if showBoxFill then
        drawingSet.BoxFill.Position = Vector2.new(left, top)
        drawingSet.BoxFill.Size = Vector2.new(width, height)
        drawingSet.BoxFill.Color = EspFrameCache.colors.boxFill
        drawingSet.BoxFill.Transparency = EspFrameCache.boxFillTransparency
        drawingSet.BoxFill.Visible = true
    else
        drawingSet.BoxFill.Visible = false
    end

    drawingSet.Name.Text = player.Name
    drawingSet.Name.Position = Vector2.new(centerX, top - 15)
    drawingSet.Name.Color = nameColor
    drawingSet.Name.Visible = showName

    local showWeapon = EspFrameCache.toggles.weapon
    local weaponColor = EspFrameCache.colors.weapon
    local weaponName = getCachedEquippedTool(player, character)
    drawingSet.Weapon.Text = weaponName
    drawingSet.Weapon.Position = Vector2.new(centerX, bottom + 5)
    drawingSet.Weapon.Color = weaponColor
    drawingSet.Weapon.Visible = showWeapon and weaponName ~= ""

    local showHealthBar = EspFrameCache.toggles.healthBar
    if showHealthBar and humanoid then
        local hpPercent = math.clamp(humanoid.Health / humanoid.MaxHealth, 0, 1)
        local barWidth = 3.5
        local barHeight = height
        local barX = left - barWidth - 2
        local barY = top

        local showHealthOutline = EspFrameCache.toggles.healthBarOutline
        drawingSet.HealthBarOutline.Position = Vector2.new(barX, barY)
        drawingSet.HealthBarOutline.Size = Vector2.new(barWidth, barHeight)
        drawingSet.HealthBarOutline.Color = Color3.fromRGB(0, 0, 0)
        drawingSet.HealthBarOutline.Visible = showHealthOutline

        local inset = showHealthOutline and 1 or 0
        local fillHeight = (barHeight - inset * 2) * hpPercent
        local fillY = barY + inset + ((barHeight - inset * 2) - fillHeight)
        drawingSet.HealthBarFill.Position = Vector2.new(barX + inset, fillY)
        drawingSet.HealthBarFill.Size = Vector2.new(barWidth - inset * 2, fillHeight)
        drawingSet.HealthBarFill.Color = EspFrameCache.colors.healthBar
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

    local showSkeleton = EspFrameCache.toggles.skeleton
    local skeletonColor = EspFrameCache.colors.skeleton
    if showSkeleton and drawingSet.SkeletonLines then
        local boneParts = getCachedBoneParts(player, character)
        for i = 1, #CONSTANTS.SkeletonBones do
            local p1 = boneParts[i][1]
            local p2 = boneParts[i][2]
            local sl = drawingSet.SkeletonLines[i]
            local so = drawingSet.SkeletonOutlines[i]
            if p1 and p2 and sl and so then
                local s1 = Camera:WorldToViewportPoint(p1.Position)
                local s2 = Camera:WorldToViewportPoint(p2.Position)
                if s1.Z > 0 and s2.Z > 0 then
                    local v1 = Vector2.new(s1.X, s1.Y)
                    local v2 = Vector2.new(s2.X, s2.Y)
                    so.From = v1; so.To = v2; so.Visible = true
                    sl.From = v1; sl.To = v2; sl.Color = skeletonColor; sl.Visible = true
                else
                    sl.Visible = false; so.Visible = false
                end
            elseif sl and so then
                sl.Visible = false; so.Visible = false
            end
        end
    elseif drawingSet.SkeletonLines then
        for _, ln in ipairs(drawingSet.SkeletonLines) do ln.Visible = false end
        for _, ln in ipairs(drawingSet.SkeletonOutlines) do ln.Visible = false end
    end

    updatePlayerChams(player, character)
end


updateItemEsp = function()
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
            if text then text.Visible = false; text:Remove() end
            EspRuntime.ItemDrawings[item] = nil
        end
    end
end


ensureFovCircles = function()
    if not AimRuntime.AimFovCircle then
        local ok, c = pcall(Drawing.new, "Circle")
        if ok and c then
            c.Visible = false
            c.Thickness = 1.5
            c.NumSides = 120
            c.Filled = false
            c.Color = Color3.fromRGB(255, 255, 255)
            AimRuntime.AimFovCircle = c
        end
    end
    if not AimRuntime.RageFovCircle then
        local ok, c = pcall(Drawing.new, "Circle")
        if ok and c then
            c.Visible = false
            c.Thickness = 1.5
            c.NumSides = 120
            c.Filled = false
            c.Color = Color3.fromRGB(255, 255, 255)
            AimRuntime.RageFovCircle = c
        end
    end
end

updateFovCircle = function()
    ensureFovCircles()
    local cam = getCamera()
    if not cam then return end
    local viewport = cam.ViewportSize
    local center = Vector2.new(viewport.X / 2, viewport.Y / 2)

    local aimCircle = AimRuntime.AimFovCircle
    if aimCircle then
        local show = Toggles.AimbotShowFOV and Toggles.AimbotShowFOV.Value
            and Toggles.AimbotEnable and Toggles.AimbotEnable.Value
            and getAimFov() < 180
        if show then
            local radius = getAimFovRadius()
            local col = getOptionColor("AimbotFOVColor", Color3.fromRGB(255, 255, 255))
            aimCircle.Position = center
            aimCircle.Radius = math.min(radius, 100000)
            aimCircle.Color = col
            aimCircle.Visible = true
        else
            aimCircle.Visible = false
        end
    end

    local rageCircle = AimRuntime.RageFovCircle
    if rageCircle then
        local show = Toggles.RagebotShowFOV and Toggles.RagebotShowFOV.Value
            and Toggles.RagebotEnable and Toggles.RagebotEnable.Value
        if show then
            local fovValue = Options.RagebotFOV and Options.RagebotFOV.Value or 1
            local radius = fovValue * (viewport.Y / cam.FieldOfView)
            local col = getOptionColor("RagebotFOVColor", Color3.fromRGB(255, 255, 255))
            rageCircle.Position = center
            rageCircle.Radius = math.min(radius, 100000)
            rageCircle.Color = col
            rageCircle.Visible = true
        else
            rageCircle.Visible = false
        end
    end

end


-- crosshair
CrosshairState = { Circle = nil, Outline = nil, StateText = nil, Created = false }

ensureCrosshair = function()
    if CrosshairState.Created then return end
    local success, circle = pcall(Drawing.new, "Circle")
    if success and circle then
        circle.Visible = false
        circle.Radius = 2
        circle.Color = Color3.fromRGB(255, 255, 255)
        circle.Thickness = 1
        circle.NumSides = 16
        circle.Filled = true
        circle.ZIndex = 2
        CrosshairState.Circle = circle
    end
    local success2, outline = pcall(Drawing.new, "Circle")
    if success2 and outline then
        outline.Visible = false
        outline.Radius = 3
        outline.Color = Color3.fromRGB(0, 0, 0)
        outline.Thickness = 1
        outline.NumSides = 16
        outline.Filled = false
        outline.ZIndex = 1
        CrosshairState.Outline = outline
    end
    local success3, stateText = pcall(Drawing.new, "Text")
    if success3 and stateText then
        stateText.Visible = false
        stateText.Center = true
        stateText.Outline = true
        stateText.Transparency = 1
        stateText.Size = 13
        stateText.Font = Drawing.Fonts.Plex
        stateText.Color = Color3.fromRGB(255, 255, 255)
        stateText.ZIndex = 2
        CrosshairState.StateText = stateText
    end
    CrosshairState.Created = true
end

getMovementStateText = function()
    local _, humanoid, rootPart = MoveUtil.getAliveMovementRig()
    if not humanoid or not rootPart then return "" end

    local ctrlHeld = UserInputService:IsKeyDown(Enum.KeyCode.LeftControl)
    local hipHeight = humanoid.HipHeight
    local isCrouching = ctrlHeld or hipHeight < 1.5

    if isCrouching then
        if humanoid.FloorMaterial == Enum.Material.Air then
            return "Ducking"
        end
        return "Crouching"
    end

    if humanoid.FloorMaterial == Enum.Material.Air then
        return "In air"
    end

    local vel = rootPart.AssemblyLinearVelocity
    local horizMag = math.sqrt(vel.X * vel.X + vel.Z * vel.Z)

    if humanoid.Sit then
        return "Sitting"
    end

    if horizMag > 1 then
        if horizMag > 20 then return "Running" end
        return "Walking"
    end

    return "Standing"
end

updateCrosshair = function()
    ensureCrosshair()
    if not CrosshairState.Circle then return end

    local enabled = Toggles.MiscCenterDot and Toggles.MiscCenterDot.Value
    local showState = Toggles.MiscStateIndicator and Toggles.MiscStateIndicator.Value

    if not enabled and not showState then
        CrosshairState.Circle.Visible = false
        if CrosshairState.Outline then CrosshairState.Outline.Visible = false end
        if CrosshairState.StateText then CrosshairState.StateText.Visible = false end
        return
    end

    local cam = getCamera()
    if not cam then return end
    local viewport = cam.ViewportSize
    local center = Vector2.new(viewport.X / 2, viewport.Y / 2)

    if enabled then
        local col = getOptionColor("MiscCenterDotColor", Color3.fromRGB(255, 255, 255))
        CrosshairState.Circle.Position = center
        CrosshairState.Circle.Color = col
        CrosshairState.Circle.Visible = true
        if CrosshairState.Outline then
            CrosshairState.Outline.Position = center
            CrosshairState.Outline.Visible = true
        end
    else
        CrosshairState.Circle.Visible = false
        if CrosshairState.Outline then CrosshairState.Outline.Visible = false end
    end

    if showState and CrosshairState.StateText then
        local stateStr = getMovementStateText()
        if stateStr ~= "" then
            CrosshairState.StateText.Text = stateStr
            CrosshairState.StateText.Position = Vector2.new(center.X, center.Y + 20)
            CrosshairState.StateText.Color = getOptionColor("MiscStateIndicatorColor", Color3.fromRGB(255, 255, 255))
            CrosshairState.StateText.Visible = true
        else
            CrosshairState.StateText.Visible = false
        end
    else
        if CrosshairState.StateText then CrosshairState.StateText.Visible = false end
    end
end


-- hit log (ported from clarity.tk, uses Linoria-style notifications positioned below crosshair)
local HitLogGui, HitLogContainer, HitLogCount
HitLogCount = 0

pushHitLog = function(text)
    if not (Toggles.MiscHitLog and Toggles.MiscHitLog.Value) then return end

    if not HitLogGui then
        local coreGui = game:GetService("CoreGui")
        HitLogGui = Instance.new("ScreenGui")
        HitLogGui.Name = "ValenokHitLog"
        HitLogGui.ResetOnSpawn = false
        HitLogGui.IgnoreGuiInset = true
        HitLogGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
        pcall(function() HitLogGui.Parent = coreGui end)

        HitLogContainer = Instance.new("Frame")
        HitLogContainer.Name = "Container"
        HitLogContainer.BackgroundTransparency = 1
        HitLogContainer.AnchorPoint = Vector2.new(0.5, 0)
        HitLogContainer.Position = UDim2.new(0.5, 0, 0.5, 40)
        HitLogContainer.Size = UDim2.new(0, 400, 0, 200)
        HitLogContainer.Parent = HitLogGui

        local layout = Instance.new("UIListLayout")
        layout.Padding = UDim.new(0, 2)
        layout.FillDirection = Enum.FillDirection.Vertical
        layout.SortOrder = Enum.SortOrder.LayoutOrder
        layout.VerticalAlignment = Enum.VerticalAlignment.Top
        layout.Parent = HitLogContainer
    end

    HitLogCount = HitLogCount + 1
    if HitLogCount > 5 then
        local oldest = HitLogContainer:GetChildren()
        for _, child in ipairs(oldest) do
            if child:IsA("Frame") then
                child:Destroy()
                HitLogCount = HitLogCount - 1
                break
            end
        end
    end

    local XSize = Library.GetTextBounds and Library:GetTextBounds(text, Library.Font, 14) or {text:len() * 7, 20}
    local textWidth = type(XSize) == "table" and XSize[1] or 200
    local textHeight = type(XSize) == "table" and XSize[2] or 20

    local notifyFrame = Instance.new("Frame")
    notifyFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    notifyFrame.BackgroundTransparency = 0.1
    notifyFrame.BorderSizePixel = 0
    notifyFrame.Size = UDim2.new(0, 0, 0, textHeight + 8)
    notifyFrame.AnchorPoint = Vector2.new(0.5, 0)
    notifyFrame.Position = UDim2.new(0.5, 0, 0, 0)
    notifyFrame.ClipsDescendants = true
    notifyFrame.Parent = HitLogContainer

    local innerFrame = Instance.new("Frame")
    innerFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    innerFrame.BorderSizePixel = 0
    innerFrame.Size = UDim2.new(1, 0, 1, 0)
    innerFrame.Parent = notifyFrame

    local accentBar = Instance.new("Frame")
    accentBar.BackgroundColor3 = Color3.fromRGB(76, 175, 80)
    accentBar.BorderSizePixel = 0
    accentBar.Size = UDim2.new(0, 2, 1, 0)
    accentBar.Parent = notifyFrame

    local label = Instance.new("TextLabel")
    label.BackgroundTransparency = 1
    label.Position = UDim2.new(0, 6, 0, 0)
    label.Size = UDim2.new(1, -8, 1, 0)
    label.Font = Library.Font or Enum.Font.SourceSans
    label.TextSize = 14
    label.TextColor3 = Color3.fromRGB(255, 255, 255)
    label.TextXAlignment = Enum.TextXAlignment.Center
    label.Text = text
    label.Parent = notifyFrame

    pcall(function()
        notifyFrame:TweenSize(UDim2.new(0, textWidth + 16, 0, textHeight + 8), "Out", "Quad", 0.3, true)
    end)

    task.spawn(function()
        task.wait(3)
        pcall(function()
            notifyFrame:TweenSize(UDim2.new(0, 0, 0, textHeight + 8), "Out", "Quad", 0.4, true)
        end)
        task.wait(0.4)
        notifyFrame:Destroy()
        HitLogCount = HitLogCount - 1
    end)
end


-- viewmodel visuals (weapon chams, arm chams, remove sleeves)
VMState = { armsConn = nil }

updateViewModelVisuals = function()
    local cam = getCamera()
    if not cam then return end

    local arms = cam:FindFirstChild("Arms")
    if not arms then return end

    local weaponChams = Toggles.VMWeaponChams and Toggles.VMWeaponChams.Value
    local armChams = Toggles.VMArmChams and Toggles.VMArmChams.Value
    local removeSleeves = Toggles.VMRemoveSleeves and Toggles.VMRemoveSleeves.Value

    if not weaponChams and not armChams and not removeSleeves then return end

    local weaponColor = getOptionColor("VMWeaponColor", Color3.fromRGB(255, 255, 255))
    local weaponTransparencyOpt = Options.VMWeaponColor
    local weaponTransparency = (weaponTransparencyOpt and weaponTransparencyOpt.Transparency) or 0
    local weaponMaterial = Options.VMWeaponMaterial and Options.VMWeaponMaterial.Value or "SmoothPlastic"
    local weaponReflectance = (Options.VMWeaponReflectance and Options.VMWeaponReflectance.Value or 0) / 50

    local armColor = getOptionColor("VMArmColor", Color3.fromRGB(255, 255, 255))
    local armTransparencyOpt = Options.VMArmColor
    local armTransparency = (armTransparencyOpt and armTransparencyOpt.Transparency) or 0
    local armMaterial = Options.VMArmMaterial and Options.VMArmMaterial.Value or "SmoothPlastic"

    local isKnife = false
    for _, child in ipairs(arms:GetChildren()) do
        if string.find(child.Name, "Knife") or child.Name == "Handle2" or child.Name == "Blade" then
            isKnife = true
            break
        end
    end

    for _, obj in ipairs(arms:GetDescendants()) do
            -- Weapon chams
            if weaponChams and (obj:IsA("MeshPart") or (obj:IsA("BasePart") and obj.Name == "Part")) then
                if obj.Name == "StatClock" then
                    obj:ClearAllChildren()
                end
                if obj:IsA("BasePart") then obj.CastShadow = false end
                obj.Color = weaponColor
                obj.Transparency = 1 - weaponTransparency
                obj.Material = Enum.Material[weaponMaterial] or Enum.Material.SmoothPlastic
                if obj:IsA("MeshPart") then
                    obj.TextureID = ""
                end
                obj.Reflectance = weaponReflectance
                local sa = obj:FindFirstChild("SurfaceAppearance")
                if sa then sa:Destroy() end
            end

            -- Knife handle hide
            if weaponChams and isKnife and obj.Name == "Handle" and obj:IsA("BasePart") then
                obj.Transparency = 1
            end

            -- Silencer2 fix (hide in buy zone like clarity.tk)
            if weaponChams and obj.Name == "Silencer2" then
                pcall(function()
                    local welded = obj:FindFirstChild("Welded")
                    if welded and Workspace:FindFirstChild("Map") and Workspace.Map:FindFirstChild("SpawnPoints") then
                        local buyArea = Workspace.Map.SpawnPoints:FindFirstChild("BuyArea")
                        if buyArea then
                            welded.Part0 = buyArea
                        end
                    end
                end)
            end

            -- Remove sleeves
            if removeSleeves and obj.Name == "Sleeve" and obj:GetAttribute("CW_Applied") == nil then
                obj:Destroy()
            end

            -- Arm chams
            if armChams then
                if obj:IsA("BasePart") then
                    if obj.Name == "Sleeve" or obj.Name == "Glove" or string.find(obj.Name, "Arm") or string.find(obj.Name, "Hand") then
                        if obj.Transparency == 1 then continue end
                        obj.CastShadow = false
                        obj.Material = Enum.Material[armMaterial] or Enum.Material.SmoothPlastic
                        obj.Color = armColor
                        obj.Transparency = 1 - armTransparency
                    end
                end
                if obj:IsA("SpecialMesh") then
                    obj.TextureId = (armMaterial == "ForceField") and "rbxassetid://4573037993" or ""
                    obj.VertexColor = Vector3.new(armColor.R, armColor.G, armColor.B)
                end
            end
        end
end

-- skybox changer
SKYBOX_PRESETS = {
    ["Purple Nebula"] = {
        SkyboxBk = "rbxassetid://159454299", SkyboxDn = "rbxassetid://159454296",
        SkyboxFt = "rbxassetid://159454293", SkyboxLf = "rbxassetid://159454286",
        SkyboxRt = "rbxassetid://159454300", SkyboxUp = "rbxassetid://159454288",
    },
    ["Night Sky"] = {
        SkyboxBk = "rbxassetid://12064107", SkyboxDn = "rbxassetid://12064152",
        SkyboxFt = "rbxassetid://12064121", SkyboxLf = "rbxassetid://12063984",
        SkyboxRt = "rbxassetid://12064115", SkyboxUp = "rbxassetid://12064131",
    },
    ["Pink Daylight"] = {
        SkyboxBk = "rbxassetid://271042516", SkyboxDn = "rbxassetid://271077243",
        SkyboxFt = "rbxassetid://271042556", SkyboxLf = "rbxassetid://271042310",
        SkyboxRt = "rbxassetid://271042467", SkyboxUp = "rbxassetid://271077958",
    },
    ["Morning Glow"] = {
        SkyboxBk = "rbxassetid://1417494030", SkyboxDn = "rbxassetid://1417494146",
        SkyboxFt = "rbxassetid://1417494253", SkyboxLf = "rbxassetid://1417494402",
        SkyboxRt = "rbxassetid://1417494499", SkyboxUp = "rbxassetid://1417494643",
    },
    ["Setting Sun"] = {
        SkyboxBk = "rbxassetid://626460377", SkyboxDn = "rbxassetid://626460216",
        SkyboxFt = "rbxassetid://626460513", SkyboxLf = "rbxassetid://626473032",
        SkyboxRt = "rbxassetid://626458639", SkyboxUp = "rbxassetid://626460625",
    },
    ["Fade Blue"] = {
        SkyboxBk = "rbxassetid://153695414", SkyboxDn = "rbxassetid://153695352",
        SkyboxFt = "rbxassetid://153695452", SkyboxLf = "rbxassetid://153695320",
        SkyboxRt = "rbxassetid://153695383", SkyboxUp = "rbxassetid://153695471",
    },
    ["Elegant Morning"] = {
        SkyboxBk = "rbxassetid://153767241", SkyboxDn = "rbxassetid://153767216",
        SkyboxFt = "rbxassetid://153767266", SkyboxLf = "rbxassetid://153767200",
        SkyboxRt = "rbxassetid://153767231", SkyboxUp = "rbxassetid://153767288",
    },
    ["Neptune"] = {
        SkyboxBk = "rbxassetid://218955819", SkyboxDn = "rbxassetid://218953419",
        SkyboxFt = "rbxassetid://218954524", SkyboxLf = "rbxassetid://218958493",
        SkyboxRt = "rbxassetid://218957134", SkyboxUp = "rbxassetid://218950090",
    },
    ["Redshift"] = {
        SkyboxBk = "rbxassetid://401664839", SkyboxDn = "rbxassetid://401664862",
        SkyboxFt = "rbxassetid://401664960", SkyboxLf = "rbxassetid://401664881",
        SkyboxRt = "rbxassetid://401664901", SkyboxUp = "rbxassetid://401664936",
    },
    ["Aesthetic Night"] = {
        SkyboxBk = "rbxassetid://1045964490", SkyboxDn = "rbxassetid://1045964368",
        SkyboxFt = "rbxassetid://1045964655", SkyboxLf = "rbxassetid://1045964655",
        SkyboxRt = "rbxassetid://1045964655", SkyboxUp = "rbxassetid://1045962969",
    },
    ["Gloomy Gray"] = {
        SkyboxBk = "rbxassetid://4495864450", SkyboxDn = "rbxassetid://4495864887",
        SkyboxFt = "rbxassetid://4495865458", SkyboxLf = "rbxassetid://4495866035",
        SkyboxRt = "rbxassetid://4495866584", SkyboxUp = "rbxassetid://4495867486",
    },
    ["Light Within Dark"] = {
        SkyboxBk = "rbxassetid://15502511288", SkyboxDn = "rbxassetid://15502508460",
        SkyboxFt = "rbxassetid://15502510289", SkyboxLf = "rbxassetid://15502507918",
        SkyboxRt = "rbxassetid://15502509398", SkyboxUp = "rbxassetid://15502511911",
    },
    ["Green Space"] = {
        SkyboxBk = "rbxassetid://16823270864", SkyboxDn = "rbxassetid://16823272150",
        SkyboxFt = "rbxassetid://16823273508", SkyboxLf = "rbxassetid://16823274898",
        SkyboxRt = "rbxassetid://16823276281", SkyboxUp = "rbxassetid://16823277547",
    },
    ["The Winter"] = {
        SkyboxBk = "rbxassetid://7307273436", SkyboxDn = "rbxassetid://7307275898",
        SkyboxFt = "rbxassetid://7307282434", SkyboxLf = "rbxassetid://7307284944",
        SkyboxRt = "rbxassetid://7307287254", SkyboxUp = "rbxassetid://7307290025",
    },
    ["Oblivion"] = {
        SkyboxBk = "rbxassetid://16642312709", SkyboxDn = "rbxassetid://16642313526",
        SkyboxFt = "rbxassetid://16642314757", SkyboxLf = "rbxassetid://16642315809",
        SkyboxRt = "rbxassetid://16642317038", SkyboxUp = "rbxassetid://16642318139",
    },
    ["Final Bloodmoon"] = {
        SkyboxBk = "rbxassetid://15493709538", SkyboxDn = "rbxassetid://15493710499",
        SkyboxFt = "rbxassetid://15493711616", SkyboxLf = "rbxassetid://15493712720",
        SkyboxRt = "rbxassetid://15493713902", SkyboxUp = "rbxassetid://15493714708",
    },
    ["Clouds"] = {
        SkyboxBk = "rbxassetid://570557514", SkyboxDn = "rbxassetid://570557775",
        SkyboxFt = "rbxassetid://570557559", SkyboxLf = "rbxassetid://570557620",
        SkyboxRt = "rbxassetid://570557672", SkyboxUp = "rbxassetid://570557727",
    },
    ["Twilight"] = {
        SkyboxBk = "rbxassetid://264908339", SkyboxDn = "rbxassetid://264907909",
        SkyboxFt = "rbxassetid://264909420", SkyboxLf = "rbxassetid://264909758",
        SkyboxRt = "rbxassetid://264908886", SkyboxUp = "rbxassetid://264907379",
    },
    ["Red Mountain"] = {
        SkyboxBk = "rbxassetid://6636457509", SkyboxDn = "rbxassetid://6636457509",
        SkyboxFt = "rbxassetid://6636457509", SkyboxLf = "rbxassetid://6636457509",
        SkyboxRt = "rbxassetid://6636457509", SkyboxUp = "rbxassetid://6636457509",
    },
    ["Cloudy Skies"] = {
        SkyboxBk = "rbxassetid://252760981", SkyboxDn = "rbxassetid://252763035",
        SkyboxFt = "rbxassetid://252761439", SkyboxLf = "rbxassetid://252760980",
        SkyboxRt = "rbxassetid://252762652", SkyboxUp = "rbxassetid://252762652",
    },
    ["Dark Blue"] = {
        SkyboxBk = "rbxassetid://30306692", SkyboxDn = "rbxassetid://25901058",
        SkyboxFt = "rbxassetid://30306730", SkyboxLf = "rbxassetid://30306626",
        SkyboxRt = "rbxassetid://30306665", SkyboxUp = "rbxassetid://30306603",
    },
}

SkyboxState = { customSky = nil, originalSky = nil, savedOriginal = false }

applySkyboxChanger = function()
    local lighting = game:GetService('Lighting')
    local enabled = Toggles.AmbienceSkyboxChanger and Toggles.AmbienceSkyboxChanger.Value

    -- Remove previous custom sky
    if SkyboxState.customSky then
        SkyboxState.customSky:Destroy()
        SkyboxState.customSky = nil
    end

    if not enabled then
        -- Restore original sky
        if SkyboxState.originalSky and not SkyboxState.originalSky.Parent then
            SkyboxState.originalSky.Parent = lighting
        end
        return
    end

    -- Save original sky on first enable
    if not SkyboxState.savedOriginal then
        local origSky = lighting:FindFirstChildOfClass('Sky')
        SkyboxState.originalSky = origSky
        SkyboxState.savedOriginal = true
    end

    -- Hide original sky
    local origSky = lighting:FindFirstChildOfClass('Sky')
    if origSky and origSky ~= SkyboxState.customSky then
        origSky.Parent = nil
    end

    local presetName = Options.AmbienceSkyboxPreset and Options.AmbienceSkyboxPreset.Value or "Game's Sky"
    local customId = Options.AmbienceSkyboxAssetId and Options.AmbienceSkyboxAssetId.Value or ""

    -- If custom asset ID is provided, try to load skybox from that asset
    if customId and customId ~= "" then
        local idNum = tonumber(customId)
        if idNum then
            task.spawn(function()
                pcall(function()
                    local objects = game:GetObjects("rbxassetid://" .. tostring(idNum))
                    if objects and #objects > 0 then
                        local obj = objects[1]
                        if obj:IsA("Sky") then
                            if SkyboxState.customSky then SkyboxState.customSky:Destroy() end
                            SkyboxState.customSky = obj
                            obj.Name = "ValenokCustomSky"
                            obj.Parent = lighting
                            return
                        end
                        -- If it's a model/folder, search for Sky inside
                        local sky = obj:FindFirstChildOfClass("Sky")
                        if sky then
                            if SkyboxState.customSky then SkyboxState.customSky:Destroy() end
                            SkyboxState.customSky = sky:Clone()
                            SkyboxState.customSky.Name = "ValenokCustomSky"
                            SkyboxState.customSky.Parent = lighting
                        end
                        obj:Destroy()
                    end
                end)
            end)
            return
        end
    end

    -- Use preset
    if presetName == "Game's Sky" then
        if SkyboxState.originalSky and not SkyboxState.originalSky.Parent then
            SkyboxState.originalSky.Parent = lighting
        end
        return
    end

    local preset = SKYBOX_PRESETS[presetName]
    if not preset then return end

    local newSky = Instance.new("Sky")
    newSky.Name = "ValenokCustomSky"
    newSky.SunTextureId = ""
    newSky.MoonTextureId = ""
    newSky.StarCount = 0
    newSky.SkyboxBk = preset.SkyboxBk
    newSky.SkyboxDn = preset.SkyboxDn
    newSky.SkyboxFt = preset.SkyboxFt
    newSky.SkyboxLf = preset.SkyboxLf
    newSky.SkyboxRt = preset.SkyboxRt
    newSky.SkyboxUp = preset.SkyboxUp
    newSky.Parent = lighting
    SkyboxState.customSky = newSky
end

-- ambience
updateAmbience = function()
    local lighting = game:GetService('Lighting')

    local customTime = Toggles.AmbienceCustomTime and Toggles.AmbienceCustomTime.Value
    local customSkybox = Toggles.AmbienceCustomSkybox and Toggles.AmbienceCustomSkybox.Value
    local skyColorEnabled = Toggles.AmbienceSkyColor and Toggles.AmbienceSkyColor.Value
    local nightMode = Toggles.AmbienceNightMode and Toggles.AmbienceNightMode.Value
    local noShadow = Toggles.AmbienceNoShadow and Toggles.AmbienceNoShadow.Value
    local brightnessVal = Options.AmbienceBrightness and Options.AmbienceBrightness.Value or 0
    local brightnessEnabled = brightnessVal ~= 0

    local anyEnabled = customTime or customSkybox or skyColorEnabled or nightMode or noShadow or brightnessEnabled

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
                if AmbienceSavedLighting.SkyTextures and AmbienceSavedLighting.Skybox then
                    local t = AmbienceSavedLighting.SkyTextures
                    local sky = AmbienceSavedLighting.Skybox
                    sky.SkyboxBk = t.SkyboxBk
                    sky.SkyboxDn = t.SkyboxDn
                    sky.SkyboxFt = t.SkyboxFt
                    sky.SkyboxLf = t.SkyboxLf
                    sky.SkyboxRt = t.SkyboxRt
                    sky.SkyboxUp = t.SkyboxUp
                    sky.StarCount = t.StarCount
                    sky.SunTextureId = t.SunTextureId
                    sky.MoonTextureId = t.MoonTextureId
                    sky.CelestialBodiesSize = t.CelestialBodiesSize
                end
                if AmbienceSavedLighting.FogColor then
                    lighting.FogColor = AmbienceSavedLighting.FogColor
                    lighting.FogEnd = AmbienceSavedLighting.FogEnd
                end
            end)
            AmbienceSavedLighting = nil
        end
        return
    end

    if not AmbienceSavedLighting then
        local sky = lighting:FindFirstChildOfClass('Sky')
        AmbienceSavedLighting = {
            ClockTime = lighting.ClockTime,
            GlobalShadows = lighting.GlobalShadows,
            Brightness = lighting.Brightness,
            Ambient = lighting.Ambient,
            OutdoorAmbient = lighting.OutdoorAmbient,
            ColorShift_Bottom = lighting.ColorShift_Bottom,
            ColorShift_Top = lighting.ColorShift_Top,
            Skybox = sky,
            FogColor = lighting.FogColor,
            FogEnd = lighting.FogEnd,
            SkyTextures = sky and {
                SkyboxBk = sky.SkyboxBk,
                SkyboxDn = sky.SkyboxDn,
                SkyboxFt = sky.SkyboxFt,
                SkyboxLf = sky.SkyboxLf,
                SkyboxRt = sky.SkyboxRt,
                SkyboxUp = sky.SkyboxUp,
                StarCount = sky.StarCount,
                SunTextureId = sky.SunTextureId,
                MoonTextureId = sky.MoonTextureId,
                CelestialBodiesSize = sky.CelestialBodiesSize,
            } or nil,
        }
    end

    if customTime then
        lighting.ClockTime = Options.AmbienceTime and Options.AmbienceTime.Value or 12
    else
        lighting.ClockTime = AmbienceSavedLighting.ClockTime
    end

    -- Custom skybox: tints the whole world (Ambient + OutdoorAmbient + ColorShift) and removes Sky
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

    -- Night mode: overrides Ambient/OutdoorAmbient with wall color (works on top of customSkybox)
    if nightMode then
        local wallColor = Options.AmbienceNightColor and Options.AmbienceNightColor.Value or Color3.fromRGB(20, 20, 40)
        lighting.Ambient = wallColor
        lighting.OutdoorAmbient = wallColor
    end

    -- Sky color: replaces the actual sky textures with a solid color
    if skyColorEnabled then
        local sky = lighting:FindFirstChildOfClass('Sky')
        if sky then
            local c = Options.AmbienceSkyColorValue and Options.AmbienceSkyColorValue.Value or Color3.fromRGB(0, 0, 0)
            local colorTexture = "rbxasset://textures/white.png"
            sky.SkyboxBk = colorTexture
            sky.SkyboxDn = colorTexture
            sky.SkyboxFt = colorTexture
            sky.SkyboxLf = colorTexture
            sky.SkyboxRt = colorTexture
            sky.SkyboxUp = colorTexture
            sky.StarCount = 0
            sky.SunTextureId = ""
            sky.MoonTextureId = ""
            lighting.FogColor = c
            lighting.FogEnd = 9e9
        end
    else
        if AmbienceSavedLighting.SkyTextures and AmbienceSavedLighting.Skybox then
            local sky = AmbienceSavedLighting.Skybox
            local t = AmbienceSavedLighting.SkyTextures
            sky.SkyboxBk = t.SkyboxBk
            sky.SkyboxDn = t.SkyboxDn
            sky.SkyboxFt = t.SkyboxFt
            sky.SkyboxLf = t.SkyboxLf
            sky.SkyboxRt = t.SkyboxRt
            sky.SkyboxUp = t.SkyboxUp
            sky.StarCount = t.StarCount
            sky.SunTextureId = t.SunTextureId
            sky.MoonTextureId = t.MoonTextureId
            sky.CelestialBodiesSize = t.CelestialBodiesSize
        end
        if AmbienceSavedLighting.FogColor then
            lighting.FogColor = AmbienceSavedLighting.FogColor
            lighting.FogEnd = AmbienceSavedLighting.FogEnd
        end
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
    local gui = getGuiFrame()
    if not gui then return end
    local crosshairs = gui:FindFirstChild("Crosshairs")
    if not crosshairs then return end

    local scope = crosshairs:FindFirstChild("Scope")
    if scope then
        scope.ImageTransparency = enabled and 1 or 0
        local innerScope = scope:FindFirstChild("Scope")
        if innerScope then
            innerScope.ImageTransparency = enabled and 1 or 0
            if enabled then
                innerScope.Size = UDim2.new(2, 0, 2, 0)
                innerScope.Position = UDim2.new(-0.5, 0, -0.5, 0)
            else
                innerScope.Size = UDim2.new(1, 0, 1, 0)
                innerScope.Position = UDim2.new(0, 0, 0, 0)
            end
            local blur = innerScope:FindFirstChild("Blur")
            if blur then
                blur.ImageTransparency = enabled and 1 or 0
                local blur2 = blur:FindFirstChild("Blur")
                if blur2 then
                    blur2.ImageTransparency = enabled and 1 or 0
                end
            end
        end
    end

    for _, frameName in ipairs({"Frame1", "Frame2", "Frame3", "Frame4"}) do
        local frame = crosshairs:FindFirstChild(frameName)
        if frame then
            frame.Transparency = enabled and 1 or 0
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
    local pg = getPlayerGui()
    if not pg then return end
    local blnd = pg:FindFirstChild("Blnd")
    if blnd then
        blnd.Enabled = not (Toggles.RemovalsNoFlash and Toggles.RemovalsNoFlash.Value)
    end
end


-- no smoke
local _noSmokeConn

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
end)()


-- skin changer
local SC = {}
;(function()
SC.Viewmodels = ReplicatedStorage:WaitForChild("Viewmodels", 10)
SC.Skins = ReplicatedStorage:WaitForChild("Skins", 10)
SC.Gloves = ReplicatedStorage:FindFirstChild("Gloves") or ReplicatedStorage:WaitForChild("Gloves", 10)
SC.GloveModels = SC.Gloves and SC.Gloves:FindFirstChild("Models")
SC.Models = nil
pcall(function() SC.Models = game:GetObjects("rbxassetid://7285197035")[1] end)
SC.OriginalCTKnife = SC.Viewmodels and SC.Viewmodels:FindFirstChild("v_CT Knife") and SC.Viewmodels:FindFirstChild("v_CT Knife"):Clone()
SC.OriginalTKnife = SC.Viewmodels and SC.Viewmodels:FindFirstChild("v_T Knife") and SC.Viewmodels:FindFirstChild("v_T Knife"):Clone()
SC.AllKnives = { "CT Knife", "T Knife", "Banana", "Bayonet", "Bearded Axe", "Butterfly Knife", "Cleaver", "Crowbar", "Falchion Knife", "Flip Knife", "Gut Knife", "Huntsman Knife", "Karambit", "M9 Bayonet", "Sickle" }
if SC.Models and SC.Models:FindFirstChild("Knives") then
    for _, v in pairs(SC.Models.Knives:GetChildren()) do table.insert(SC.AllKnives, v.Name) end
end

SC.AllWeapons = {}
SC.AllSkins = {}
SC.KnifeSkins = {}
if SC.Skins then
    for _, v in pairs(SC.Skins:GetChildren()) do
        local isKnife = false
        for _, knife in ipairs(SC.AllKnives) do
            local cl = knife:gsub(" Knife", ""):gsub(" Classic", ""):lower()
            if v.Name:lower() == cl or v.Name:lower():sub(1, #cl + 1) == cl .. " " then isKnife = true; break end
        end
        if not isKnife then table.insert(SC.AllWeapons, v.Name) end
    end
    table.sort(SC.AllWeapons, function(a, b) return a < b end)
    for _, v in ipairs(SC.AllWeapons) do
        SC.AllSkins[v] = {"Inventory"}
        for _, v2 in pairs(SC.Skins[v]:GetChildren()) do table.insert(SC.AllSkins[v], v2.Name) end
    end
    for _, knifeName in ipairs(SC.AllKnives) do
        SC.KnifeSkins[knifeName] = {"Inventory"}
        if SC.Skins:FindFirstChild(knifeName) then
            for _, skin in pairs(SC.Skins[knifeName]:GetChildren()) do table.insert(SC.KnifeSkins[knifeName], skin.Name) end
        end
    end
end

SC.State = {
    currentKnife = nil,
    swapping = false,
    armsConn = nil,
    SavedKnifeSkins = {},
    SavedWeaponSkins = {},
    SavedGloveSkins = {},
    skinFile = "Valenok/skins.json",
}
local HttpService = game:GetService("HttpService")

local function SC_SaveSkins()
    pcall(function()
        local data = { knife = SC.State.SavedKnifeSkins, weapon = SC.State.SavedWeaponSkins, glove = SC.State.SavedGloveSkins }
        writefile(SC.State.skinFile, HttpService:JSONEncode(data))
    end)
end
SC.SaveSkins = SC_SaveSkins

local function SC_LoadSkins()
    pcall(function()
        if isfile(SC.State.skinFile) then
            local data = HttpService:JSONDecode(readfile(SC.State.skinFile))
            SC.State.SavedKnifeSkins = data.knife or {}
            SC.State.SavedWeaponSkins = data.weapon or {}
            SC.State.SavedGloveSkins = data.glove or {}
        end
    end)
end
SC_LoadSkins()

SC.AllGloveNames = {}
SC.AllGloves = {}
if SC.Gloves then
    for _, fldr in pairs(SC.Gloves:GetChildren()) do
        if fldr:IsA("Folder") and fldr ~= SC.GloveModels and fldr.Name ~= "Racer" and fldr.Name ~= "Models" then
            table.insert(SC.AllGloveNames, fldr.Name)
        end
    end
    table.sort(SC.AllGloveNames, function(a, b) return a < b end)
    for _, gName in ipairs(SC.AllGloveNames) do
        SC.AllGloves[gName] = {"Default"}
        for _, modl in pairs(SC.Gloves[gName]:GetChildren()) do
            table.insert(SC.AllGloves[gName], modl.Name)
        end
    end
end

SC.lastGlove = nil
SC.lastGloveSkin = nil


local function SC_SwapKnifeModel(knifeName)
    if not SC.Viewmodels then return end
    if SC.State.swapping then return end
    if SC.State.currentKnife == knifeName then return end
    SC.State.swapping = true
    if SC.Viewmodels:FindFirstChild("v_CT Knife") then SC.Viewmodels:FindFirstChild("v_CT Knife"):Destroy() end
    if SC.Viewmodels:FindFirstChild("v_T Knife") then SC.Viewmodels:FindFirstChild("v_T Knife"):Destroy() end
    if knifeName == "CT Knife" or knifeName == "T Knife" then
        if SC.OriginalCTKnife then SC.OriginalCTKnife:Clone().Parent = SC.Viewmodels end
        if SC.OriginalTKnife then SC.OriginalTKnife:Clone().Parent = SC.Viewmodels end
    else
        local sourceVM = nil
        if SC.Viewmodels:FindFirstChild("v_" .. knifeName) then
            sourceVM = SC.Viewmodels:FindFirstChild("v_" .. knifeName)
        elseif SC.Models and SC.Models:FindFirstChild("Knives") then
            local km = SC.Models.Knives:FindFirstChild(knifeName)
            if km then sourceVM = km end
        end
        if sourceVM then
            local ct = sourceVM:Clone(); ct.Name = "v_CT Knife"; ct.Parent = SC.Viewmodels
            local tt = sourceVM:Clone(); tt.Name = "v_T Knife"; tt.Parent = SC.Viewmodels
        else
            if SC.OriginalCTKnife then SC.OriginalCTKnife:Clone().Parent = SC.Viewmodels end
            if SC.OriginalTKnife then SC.OriginalTKnife:Clone().Parent = SC.Viewmodels end
        end
    end
    SC.State.currentKnife = knifeName
    SC.State.swapping = false
end
SC.SwapKnifeModel = SC_SwapKnifeModel


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
        else targetPart.TextureID = tex end
    end
end


local function SC_applySkinToArms(armsObj, gunname, selectedSkin)
    if not SC.Skins then return end
    if not selectedSkin or selectedSkin == "Inventory" then return end
    if not armsObj or not armsObj.Parent then return end
    if (gunname == "CT Knife" or gunname == "T Knife") and not SC.Skins:FindFirstChild(gunname) then gunname = "M9 Bayonet" end
    if not SC.Skins:FindFirstChild(gunname) then return end
    local SkinData = SC.Skins[gunname]:FindFirstChild(selectedSkin)
    if not SkinData or SkinData:FindFirstChild("Animated") then return end
    for _, targetPart in next, armsObj:GetDescendants() do
        if targetPart and targetPart.Parent then
            SC_applySkinToPart(targetPart, SkinData)
        end
    end
    local skinConn
    skinConn = armsObj.DescendantAdded:Connect(function(part)
        if part and part.Parent then SC_applySkinToPart(part, SkinData) end
    end)
    armsObj.AncestryChanged:Connect(function(_, newParent)
        if not newParent and skinConn then skinConn:Disconnect(); skinConn = nil end
    end)
end
SC.applySkinToArms = SC_applySkinToArms


local function SC_setupArmsWatcher()
    if SC.State.armsConn then SC.State.armsConn:Disconnect() end
    SC.State.armsConn = Camera.ChildAdded:Connect(function(obj)
        if obj.Name ~= "Arms" then return end
        RunService.RenderStepped:Wait()
        local Client = nil
        pcall(function() Client = getsenv(LocalPlayer.PlayerGui.Client) end)
        if not Client or Client.gun == "none" or typeof(Client.gun) ~= "Instance" then return end
        local isMelee = Client.gun:FindFirstChild("Melee")
        local gunname = Client.gun.Name
        if gunname:match("Grenade") or gunname:match("Flashbang") or gunname:match("Smoke") or gunname:match("Decoy") or gunname:match("Molotov") or gunname:match("Incendiary") or gunname:match("C4") then
            return
        end
        if Toggles.SkinGloveChanger and Toggles.SkinGloveChanger.Value then
            if not SC.lastGlove or SC.lastGlove == "None" then return end
            if not SC.GloveModels or not SC.GloveModels:FindFirstChild(SC.lastGlove) then return end
            local Model
                    for _, v in pairs(obj:GetChildren()) do
                        if v:IsA("Model") and (v:FindFirstChild("Right Arm") or v:FindFirstChild("Left Arm")) then
                            Model = v
                        end
                    end
                    if not Model then return end
                    local RArm = Model:FindFirstChild("Right Arm")
                    local LArm = Model:FindFirstChild("Left Arm")
                    local gloveTexData = SC.Gloves:FindFirstChild(SC.lastGlove) and SC.Gloves[SC.lastGlove]:FindFirstChild(SC.lastGloveSkin or "Default")
                    local gloveTex = ""
                    if gloveTexData and gloveTexData:FindFirstChild("Textures") then
                        gloveTex = gloveTexData.Textures.TextureId or ""
                    end
                    if RArm and SC.GloveModels:FindFirstChild(SC.lastGlove) then
                        local RGlove = RArm:FindFirstChild("Glove") or RArm:FindFirstChild("RGlove")
                        if RGlove then RGlove:Destroy() end
                        local newRG = SC.GloveModels[SC.lastGlove].RGlove:Clone()
                        if newRG:FindFirstChild("Mesh") then
                            newRG.Mesh.TextureId = gloveTex
                        else
                            newRG.TextureID = gloveTex
                        end
                        newRG.Parent = RArm
                        newRG.Transparency = 0
                        if newRG.Welded then newRG.Welded.Part0 = RArm end
                    end
                    if LArm and SC.GloveModels:FindFirstChild(SC.lastGlove) then
                        local LGlove = LArm:FindFirstChild("Glove") or LArm:FindFirstChild("LGlove")
                        if LGlove then LGlove:Destroy() end
                        local newLG = SC.GloveModels[SC.lastGlove].LGlove:Clone()
                        if newLG:FindFirstChild("Mesh") then
                            newLG.Mesh.TextureId = gloveTex
                        else
                            newLG.TextureID = gloveTex
                        end
                        newLG.Transparency = 0
                        newLG.Parent = LArm
                        if newLG.Welded then newLG.Welded.Part0 = LArm end
                    end
            end
            if Toggles.SkinKnifeChanger and Toggles.SkinKnifeChanger.Value and isMelee then
                local wantedKnife = Options.SkinKnifeModel and Options.SkinKnifeModel.Value
                if wantedKnife and SC.State.currentKnife ~= wantedKnife then
                    SC_SwapKnifeModel(wantedKnife)
                    if obj and obj.Parent then obj:Destroy() end
                    return
                end
                task.spawn(function()
                    if not obj or not obj.Parent then return end
                    local kn = wantedKnife or "M9 Bayonet"
                    if not SC.Skins:FindFirstChild(kn) then kn = "M9 Bayonet" end
                    SC_applySkinToArms(obj, kn, SC.State.SavedKnifeSkins[wantedKnife] or "Inventory")
                end)
            elseif Toggles.SkinWeaponChanger and Toggles.SkinWeaponChanger.Value and not isMelee then
                task.spawn(function()
                    if not obj or not obj.Parent then return end
                    SC_applySkinToArms(obj, gunname, SC.State.SavedWeaponSkins[gunname] or "Inventory")
                end)
            end
    end)
end
SC.setupArmsWatcher = SC_setupArmsWatcher
end)()




-- ui

;(function()
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
    GunMods = Tabs.Rage:AddRightGroupbox('Gun mods'),
    Exploit = Tabs.Rage:AddRightGroupbox('Exploit'),
}

local AntiAimTabbox = Tabs.Rage:AddLeftTabbox('AntiAim')
local antiAimPitchTab = AntiAimTabbox:AddTab('Pitch')
local antiAimYawTab = AntiAimTabbox:AddTab('Yaw')

local LegitSections = {
    Aimbot = Tabs.Legit:AddLeftGroupbox('Aim bot'),
    Triggerbot = Tabs.Legit:AddRightGroupbox('Trigger bot'),
    RCS = Tabs.Legit:AddRightGroupbox('RCS'),
}

LegitSections.Aimbot:AddToggle('AimbotEnable', {Text = 'Enable', Default = false, KeyPicker = {Idx = 'AimbotKeybind', Default = 'None', Mode = 'Hold', Text = 'Aimbot'}})
LegitSections.Aimbot:AddToggle('AimbotVisibleCheck', {Text = 'Visible check', Default = false})
LegitSections.Aimbot:AddToggle('AimbotTeamCheck', {Text = 'Team check', Default = false})
LegitSections.Aimbot:AddToggle('AimbotShowFOV', {Text = 'Show FOV', Default = false, ColorPicker = {Idx = 'AimbotFOVColor', Default = Color3.fromRGB(255, 255, 255), Title = 'FOV color'}})
LegitSections.Aimbot:AddDropdown('AimbotHitbox', {Values = { 'Head', 'Body', 'Nearest' }, Default = 'Head', Text = 'Hit box'})
LegitSections.Aimbot:AddToggle('AimbotBaim', {Text = 'Baim', Default = false, KeyPicker = {Idx = 'AimbotBaimKeybind', Default = 'None', Mode = 'Toggle', Text = 'Baim'}})
LegitSections.Aimbot:AddSlider('AimbotFOV', {Text = 'FOV', Default = 45, Min = 1, Max = 180, Rounding = 0})
LegitSections.Aimbot:AddSlider('AimbotSmooth', {Text = 'Smooth', Default = 4, Min = 1, Max = 10, Rounding = 0})

LegitSections.Triggerbot:AddToggle('TriggerbotEnable', {Text = 'Enable', Default = false, KeyPicker = {Idx = 'TriggerbotKeybind', Default = 'None', Mode = 'Toggle', Text = 'Trigger bot'}})
LegitSections.Triggerbot:AddToggle('TriggerbotTeamCheck', {Text = 'Team check', Default = false})
LegitSections.Triggerbot:AddToggle('TriggerbotOnStopOnly', {Text = 'On stop only', Default = false})
LegitSections.Triggerbot:AddToggle('TriggerbotSmokeCheck', {Text = 'Smoke check', Default = false})
LegitSections.Triggerbot:AddToggle('TriggerbotJumpCheck', {Text = 'Jump check', Default = false})
LegitSections.Triggerbot:AddToggle('TriggerbotMultiPoint', {Text = 'Multipoint', Default = false})
LegitSections.Triggerbot:AddSlider('TriggerbotMultiPointScale', {Text = 'Multipoint scale', Default = 50, Min = 1, Max = 100, Rounding = 0, Suffix = '%'})
LegitSections.Triggerbot:AddSlider('TriggerbotMultiPointPoints', {Text = 'Multipoint points', Default = 10, Min = 1, Max = 100, Rounding = 0})
LegitSections.Triggerbot:AddToggle('TriggerbotMagnet', {Text = 'Magnet', Default = false})
LegitSections.Triggerbot:AddSlider('TriggerbotDelay', {Text = 'Trigger bot delay', Default = 0, Min = 0, Max = 300, Rounding = 0, Suffix = 'ms'})
LegitSections.Triggerbot:AddSlider('TriggerbotHoldTime', {Text = 'Hold time', Default = 50, Min = 10, Max = 500, Rounding = 0, Suffix = 'ms'})
LegitSections.Triggerbot:AddSlider('TriggerbotInterval', {Text = 'Interval between shots', Default = 150, Min = 50, Max = 1000, Rounding = 0, Suffix = 'ms'})

LegitSections.RCS:AddToggle('RCSEnable', {Text = 'Enable', Default = false, Callback = function() updateRCS() end})
LegitSections.RCS:AddSlider('RCSValue', {Text = 'RCS', Default = 1, Min = 1, Max = 100, Rounding = 0, Callback = function() updateRCS() end})

local VisualTabbox = Tabs.Visual:AddLeftTabbox('ESP & Ambience')
local espTab = VisualTabbox:AddTab('ESP')
local ambienceTab = VisualTabbox:AddTab('Ambience')
local viewmodelTab = VisualTabbox:AddTab('Viewmodel')

local VisualSections = {
    ThirdPerson = Tabs.Visual:AddLeftGroupbox('Third person'),
    Menu = Tabs.Visual:AddLeftGroupbox('Menu'),
    Removals = Tabs.Visual:AddRightGroupbox('Removals'),
    Grenades = Tabs.Visual:AddRightGroupbox('Grenades'),
    DamageIndicators = Tabs.Visual:AddRightGroupbox('Damage Indicators'),
    BulletImpact = Tabs.Visual:AddRightGroupbox('Bullet Impact'),
    Misc = Tabs.Visual:AddRightGroupbox('Misc'),
}

local SkinSections = {
    Knife = Tabs.Skin:AddLeftGroupbox('Knife Changer'),
    Weapon = Tabs.Skin:AddRightGroupbox('Weapon Skins'),
    Glove = Tabs.Skin:AddRightGroupbox('Glove Changer'),
}
SkinSections.Knife:AddToggle('SkinKnifeChanger', {Text = 'Enable', Default = false, Callback = function()
    if Toggles.SkinKnifeChanger.Value then
        local wantedKnife = Options.SkinKnifeModel and Options.SkinKnifeModel.Value
        if wantedKnife then SC.SwapKnifeModel(wantedKnife) end
    elseif SC.Viewmodels then
        if SC.Viewmodels:FindFirstChild("v_CT Knife") then SC.Viewmodels:FindFirstChild("v_CT Knife"):Destroy() end
        if SC.Viewmodels:FindFirstChild("v_T Knife") then SC.Viewmodels:FindFirstChild("v_T Knife"):Destroy() end
        wait()
        if SC.OriginalCTKnife then SC.OriginalCTKnife:Clone().Parent = SC.Viewmodels end
        if SC.OriginalTKnife then SC.OriginalTKnife:Clone().Parent = SC.Viewmodels end
        SC.State.currentKnife = nil
    end
end})
SkinSections.Knife:AddDropdown('SkinKnifeModel', {Text = 'Knife', Values = #SC.AllKnives > 0 and SC.AllKnives or {"CT Knife"}, Default = 'Butterfly Knife', Callback = function()
    local wantedKnife = Options.SkinKnifeModel and Options.SkinKnifeModel.Value
    if wantedKnife then
        local skins = SC.KnifeSkins[wantedKnife] or {"Inventory"}
        Options.SkinKnifeSkin.Values = skins
        Options.SkinKnifeSkin:SetValues()
        Options.SkinKnifeSkin:SetValue(SC.State.SavedKnifeSkins[wantedKnife] or "Inventory")
        if Toggles.SkinKnifeChanger and Toggles.SkinKnifeChanger.Value then SC.SwapKnifeModel(wantedKnife) end
    end
end})
SkinSections.Knife:AddDropdown('SkinKnifeSkin', {Text = 'Knife Skin', Values = {'Inventory'}, Default = 'Inventory', Callback = function()
    local kn = Options.SkinKnifeModel and Options.SkinKnifeModel.Value
    local sk = Options.SkinKnifeSkin and Options.SkinKnifeSkin.Value
    if kn and sk then SC.State.SavedKnifeSkins[kn] = sk; SC.SaveSkins() end
end})
SkinSections.Weapon:AddToggle('SkinWeaponChanger', {Text = 'Enable', Default = false})
local _SC_prevWeapon = SC.AllWeapons[1]
SkinSections.Weapon:AddDropdown('SkinWeaponModel', {Text = 'Weapon', Values = #SC.AllWeapons > 0 and SC.AllWeapons or {"AK-47"}, Default = SC.AllWeapons[1] or "AK-47", Callback = function()
    local weaponName = Options.SkinWeaponModel and Options.SkinWeaponModel.Value
    if _SC_prevWeapon and _SC_prevWeapon ~= weaponName then
        local curSkin = Options.SkinWeaponSkin and Options.SkinWeaponSkin.Value
        if curSkin then SC.State.SavedWeaponSkins[_SC_prevWeapon] = curSkin; SC.SaveSkins() end
    end
    _SC_prevWeapon = weaponName
    if weaponName then
        local skins = SC.AllSkins[weaponName] or {"Inventory"}
        Options.SkinWeaponSkin.Values = skins
        Options.SkinWeaponSkin:SetValues()
        Options.SkinWeaponSkin:SetValue(SC.State.SavedWeaponSkins[weaponName] or "Inventory")
    end
end})
SkinSections.Weapon:AddDropdown('SkinWeaponSkin', {Text = 'Weapon Skin', Values = {'Inventory'}, Default = 'Inventory', Callback = function()
    local wn = Options.SkinWeaponModel and Options.SkinWeaponModel.Value
    local sk = Options.SkinWeaponSkin and Options.SkinWeaponSkin.Value
    if wn and sk then SC.State.SavedWeaponSkins[wn] = sk; SC.SaveSkins() end
end})
SkinSections.Glove:AddToggle('SkinGloveChanger', {Text = 'Enable', Default = false})
if #SC.AllGloveNames > 0 then
    SkinSections.Glove:AddDropdown('SkinGloveModel', {Text = 'Glove', Values = SC.AllGloveNames, Default = SC.AllGloveNames[1], Callback = function()
        local gloveName = Options.SkinGloveModel and Options.SkinGloveModel.Value
        if gloveName then
            local skins = SC.AllGloves[gloveName] or {"Default"}
            Options.SkinGloveSkin.Values = skins
            Options.SkinGloveSkin:SetValues()
            Options.SkinGloveSkin:SetValue(SC.State.SavedGloveSkins[gloveName] or skins[1])
            SC.lastGlove = gloveName
            SC.lastGloveSkin = SC.State.SavedGloveSkins[gloveName] or skins[1]
        end
    end})
    SkinSections.Glove:AddDropdown('SkinGloveSkin', {Text = 'Glove Skin', Values = SC.AllGloves[SC.AllGloveNames[1]] or {"Default"}, Default = "Default", Callback = function()
        SC.lastGlove = Options.SkinGloveModel and Options.SkinGloveModel.Value
        SC.lastGloveSkin = Options.SkinGloveSkin and Options.SkinGloveSkin.Value
        if SC.lastGlove and SC.lastGloveSkin then
            SC.State.SavedGloveSkins[SC.lastGlove] = SC.lastGloveSkin
            SC.SaveSkins()
        end
    end})
end
SkinSections.Knife:AddButton('Random Skin', function()
    for _, knifeName in ipairs(SC.AllKnives) do
        local skins = SC.KnifeSkins[knifeName]
        if skins and #skins > 0 then
            SC.State.SavedKnifeSkins[knifeName] = skins[math.random(1, #skins)]
        end
    end
    SC.SaveSkins()
    local curKnife = Options.SkinKnifeModel and Options.SkinKnifeModel.Value
    if curKnife and SC.KnifeSkins[curKnife] then
        Options.SkinKnifeSkin:SetValue(SC.State.SavedKnifeSkins[curKnife] or "Inventory")
    end
end)
SkinSections.Weapon:AddButton('Random Skin', function()
    for _, weaponName in ipairs(SC.AllWeapons) do
        local skins = SC.AllSkins[weaponName]
        if skins and #skins > 0 then
            SC.State.SavedWeaponSkins[weaponName] = skins[math.random(1, #skins)]
        end
    end
    SC.SaveSkins()
    local curWeapon = Options.SkinWeaponModel and Options.SkinWeaponModel.Value
    if curWeapon and SC.AllSkins[curWeapon] then
        Options.SkinWeaponSkin:SetValue(SC.State.SavedWeaponSkins[curWeapon] or "Inventory")
    end
end)
SkinSections.Glove:AddButton('Random Skin', function()
    for _, gloveName in ipairs(SC.AllGloveNames) do
        local skins = SC.AllGloves[gloveName]
        if skins and #skins > 0 then
            SC.State.SavedGloveSkins[gloveName] = skins[math.random(1, #skins)]
        end
    end
    SC.SaveSkins()
    local curGlove = Options.SkinGloveModel and Options.SkinGloveModel.Value
    if curGlove and SC.AllGloves[curGlove] then
        Options.SkinGloveSkin:SetValue(SC.State.SavedGloveSkins[curGlove] or "Default")
        SC.lastGlove = curGlove
        SC.lastGloveSkin = SC.State.SavedGloveSkins[curGlove]
    end
end)
SC.setupArmsWatcher()

local MovementSections = {
    Bhop = Tabs.Movement:AddLeftGroupbox('Bhop'),
    SpeedHack = Tabs.Movement:AddLeftGroupbox('Speed Hack'),
    LegitBhop = Tabs.Movement:AddRightGroupbox('Legit Bhop'),
    Misc = Tabs.Movement:AddRightGroupbox('Misc'),
    Exploits = Tabs.Movement:AddRightGroupbox('Exploits'),
}
MovementSections.SpeedHack:AddToggle('SpeedHackEnable', {Text = 'Enable', Default = false, Callback = function() updateSpeedHack() end, KeyPicker = {Idx = 'SpeedHackKeybind', Default = 'None', Mode = 'Hold', Text = 'Speed Hack'}})
MovementSections.SpeedHack:AddSlider('SpeedHackSpeed', {Text = 'Speed', Default = 50, Min = 16, Max = 500, Rounding = 0})
MovementSections.Exploits:AddToggle('NoclipEnable', {Text = 'Noclip', Default = false, Callback = function() updateNoclip() end})
MovementSections.Exploits:AddToggle('FlyEnable', {Text = 'Fly', Default = false, Callback = function() updateFly() end})
MovementSections.Exploits:AddSlider('FlySpeed', {Text = 'Fly speed', Default = 50, Min = 10, Max = 300, Rounding = 0})
MovementSections.LegitBhop:AddToggle('LegitBhopEnable', {Text = 'Enable', Default = false, Callback = function() updateLegitBhop() end})
MovementSections.LegitBhop:AddSlider('LegitBhopMultiplier', {Text = 'Multiplier', Default = 2, Min = 1, Max = 3, Rounding = 1})
MovementSections.Bhop:AddToggle('BhopEnable', {Text = 'Enable', Default = false, Callback = function() updateBhop() end})
MovementSections.Bhop:AddSlider('BhopMultiplier', {Text = 'Bhop multiplier', Default = 1, Min = 1, Max = 5, Rounding = 2})
MovementSections.Misc:AddToggle('AutoJumpEnable', {Text = 'Auto jump', Default = false, Callback = function() updateAutoJump() end})
MovementSections.Misc:AddToggle('AutoCrouchEnable', {Text = 'Auto crouch (on jump)', Default = false, Callback = function() updateAutoCrouch() end})

RageSections.Ragebot:AddToggle('RagebotEnable', {Text = 'Enable', Default = false, KeyPicker = {Idx = 'RagebotKeybind', Default = 'None', Mode = 'Hold', Text = 'Ragebot'}})
RageSections.Ragebot:AddToggle('RagebotAutoFire', {Text = 'Automatic fire', Default = false})
RageSections.Ragebot:AddToggle('RagebotTeamCheck', {Text = 'Team check', Default = false})
RageSections.Ragebot:AddToggle('RagebotVisCheck', {Text = 'Vis check', Default = false})
RageSections.Ragebot:AddToggle('RagebotShowFOV', {Text = 'Show FOV', Default = false, ColorPicker = {Idx = 'RagebotFOVColor', Default = Color3.fromRGB(255, 255, 255), Title = 'FOV color'}})
RageSections.Ragebot:AddSlider('RagebotFOV', {Text = 'FOV', Default = 1, Min = 1, Max = 180, Rounding = 0})
RageSections.Ragebot:AddDropdown('RagebotHitbox', {Values = { 'Head', 'Body', 'Nearest', 'All' }, Default = 'Head', Text = 'Hit box'})
RageSections.Ragebot:AddToggle('RagebotMultiPoint', {Text = 'Multipoint', Default = false})
RageSections.Ragebot:AddSlider('RagebotMultiPointScale', {Text = 'Multipoint scale', Default = 50, Min = 1, Max = 100, Rounding = 0, Suffix = '%'})
RageSections.Ragebot:AddSlider('RagebotMultiPointPoints', {Text = 'Multipoint points', Default = 10, Min = 1, Max = 100, Rounding = 0})
RageSections.Ragebot:AddToggle('RagebotBaim', {Text = 'Baim', Default = false, KeyPicker = {Idx = 'RagebotBaimKeybind', Default = 'None', Mode = 'Toggle', Text = 'Baim'}})
RageSections.Ragebot:AddToggle('RagebotWallPenetration', {Text = 'Wall penetration', Default = true})
RageSections.Ragebot:AddSlider('SilentAimMaxWalls', {Text = 'Max walls', Default = 3, Min = 1, Max = 10, Rounding = 0})

antiAimPitchTab:AddToggle('AntiAimPitchEnable', {Text = 'Enable', Default = false})
antiAimPitchTab:AddDropdown('AntiAimPitchMode', {Values = { 'None', 'Down', 'Up', 'Random', 'Custom' }, Default = 'None', Text = 'Pitch'})
antiAimPitchTab:AddSlider('AntiAimPitchCustom', {Text = 'Custom value', Default = 0, Min = -1, Max = 1, Rounding = 2})
antiAimPitchTab:AddSlider('AntiAimPitchRandomSpeed', {Text = 'Pitch random speed (ms)', Default = 1, Min = 1, Max = 1000, Rounding = 0})

antiAimYawTab:AddToggle('AntiAimYawEnable', {Text = 'Enable', Default = false})
antiAimYawTab:AddDropdown('AntiAimYawMode', {Values = { 'Local', 'At target' }, Default = 'Local', Text = 'Yaw mode'})
antiAimYawTab:AddDropdown('AntiAimYawDirection', {Values = { 'Backwards', 'Forwards' }, Default = 'Backwards', Text = 'Direction'})
antiAimYawTab:AddDropdown('AntiAimYawType', {Values = { 'None', 'Custom', 'Jitter', 'Jitter 3 way', 'Jitter 5 way', 'Random', 'Spin' }, Default = 'None', Text = 'Yaw type'})
antiAimYawTab:AddSlider('AntiAimYawCustom', {Text = 'Custom angle', Default = 0, Min = -180, Max = 180, Rounding = 0, Suffix = '°'})
antiAimYawTab:AddSlider('AntiAimYawJitterAngle', {Text = 'Jitter angle', Default = 90, Min = 0, Max = 180, Rounding = 0, Suffix = '°'})
antiAimYawTab:AddSlider('AntiAimYawJitterDelay', {Text = 'Jitter delay (ms)', Default = 100, Min = 1, Max = 1000, Rounding = 0})
antiAimYawTab:AddSlider('AntiAimYawRandomDelay', {Text = 'Random delay (ms)', Default = 200, Min = 1, Max = 1000, Rounding = 0})
antiAimYawTab:AddSlider('AntiAimYawSpinDelay', {Text = 'Spin delay (ms)', Default = 5, Min = 1, Max = 1000, Rounding = 0})

RageSections.PeekAssist:AddToggle('PeekAssistEnable', {Text = 'Enable', Default = false, KeyPicker = {Idx = 'PeekAssistKeybind', Default = 'None', Mode = 'Hold', Text = 'Peek Assist'}})
RageSections.PeekAssist:AddDropdown('PeekAssistRetreatMode', {Values = { 'On Key', 'On Shot' }, Default = 'On Key', Text = 'Retreat Mode'})

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
RageSections.GunMods:AddToggle('MiscFullAuto', {Text = 'Full auto', Default = false, Callback = function() updateFullAuto() end})

VisualSections.BulletImpact:AddToggle('MiscBulletTracer', {Text = 'Bullet tracer', Default = false, ColorPicker = {Idx = 'MiscBulletTracerColor', Default = Color3.fromRGB(150, 20, 60), Title = 'Bullet tracer color'}})
VisualSections.BulletImpact:AddToggle('MiscBulletTracerFaceCamera', {Text = 'Face camera', Default = false})
VisualSections.BulletImpact:AddDropdown('MiscBulletTracerTexture', {
    Text = 'Tracer texture',
    Values = {"Solid","Lightning","Laser","Twisted Energy","Anime Lazer","Arrow","Minecraft","Alien Energy Ray","Energy Ray","Matrix","Cartoony Eletric"},
    Default = "Solid",
})

VisualSections.Grenades:AddToggle('GrenadesPrediction', {Text = 'Grenade prediction', Default = false, ColorPicker = {Idx = 'GrenadesPredictionColor', Default = Color3.fromRGB(255, 50, 50), Title = 'Prediction color'}})

VisualSections.DamageIndicators:AddToggle('MiscHitSound', {Text = 'Hit sound', Default = false})
VisualSections.DamageIndicators:AddDropdown('MiscHitSoundType', {Values = { 'Skeet', 'Neverlose', 'Bameware', 'Bell', 'Bubble', 'Pick', 'Pop', 'Rust', 'Sans', 'Fart', 'Big', 'Vine', 'Bruh', 'Fatality', 'Bonk', 'Minecraft', 'Moan' }, Default = 'Skeet', Text = 'Hit sound type'})
VisualSections.DamageIndicators:AddSlider('MiscHitSoundVolume', {Text = 'Volume', Default = 5, Min = 1, Max = 10, Rounding = 0})
VisualSections.DamageIndicators:AddToggle('MiscHitChams', {Text = 'Hit chams', Default = false, ColorPicker = {Idx = 'MiscHitChamsColor', Default = Color3.fromRGB(200, 30, 80), Title = 'Hit chams color'}})
VisualSections.DamageIndicators:AddSlider('MiscHitChamsLifetime', {Text = 'Hit chams time (s)', Default = 1.3, Min = 1, Max = 5, Rounding = 1})
VisualSections.DamageIndicators:AddToggle('MiscHitMarker', {Text = 'Hit marker', Default = false, ColorPicker = {Idx = 'MiscHitMarkerColor', Default = Color3.fromRGB(255, 255, 255), Title = 'Hit marker color'}})
VisualSections.DamageIndicators:AddSlider('MiscHitMarkerLifetime', {Text = 'Hit marker time (s)', Default = 0.6, Min = 0.2, Max = 5, Rounding = 1})

VisualSections.Misc:AddToggle('MiscCenterDot', {Text = 'Center dot', Default = true, ColorPicker = {Idx = 'MiscCenterDotColor', Default = Color3.fromRGB(255, 255, 255), Title = 'Center dot color'}})
VisualSections.Misc:AddToggle('MiscStateIndicator', {Text = 'State indicator', Default = false, ColorPicker = {Idx = 'MiscStateIndicatorColor', Default = Color3.fromRGB(255, 255, 255), Title = 'State indicator color'}})
VisualSections.Misc:AddToggle('MiscHideCrosshair', {Text = 'Hide game crosshair', Default = false})
VisualSections.Misc:AddToggle('MiscHitLog', {Text = 'Hit log', Default = false})

-- Viewmodel tab
viewmodelTab:AddToggle('VMOffsetEnable', {Text = 'Viewmodel offset', Default = false})
viewmodelTab:AddSlider('VMOffsetX', {Text = 'X', Default = 0, Min = -25, Max = 25, Rounding = 1, Suffix = ''})
viewmodelTab:AddSlider('VMOffsetY', {Text = 'Y', Default = 0, Min = -25, Max = 25, Rounding = 1, Suffix = ''})
viewmodelTab:AddSlider('VMOffsetZ', {Text = 'Z', Default = 0, Min = -25, Max = 25, Rounding = 1, Suffix = ''})
viewmodelTab:AddSlider('VMRoll', {Text = 'Roll', Default = 0, Min = 0, Max = 360, Rounding = 1, Suffix = '°'})

viewmodelTab:AddToggle('VMWeaponChams', {Text = 'Weapon chams', Default = false, ColorPicker = {Idx = 'VMWeaponColor', Default = Color3.fromRGB(255, 255, 255), Title = 'Weapon color', Transparency = 0}, Callback = function() updateViewModelVisuals() end})
viewmodelTab:AddDropdown('VMWeaponMaterial', {Values = {'SmoothPlastic', 'Neon', 'ForceField', 'Glass'}, Default = 'SmoothPlastic', Text = 'Weapon material', Callback = function() updateViewModelVisuals() end})
viewmodelTab:AddSlider('VMWeaponReflectance', {Text = 'Weapon reflectance', Default = 0, Min = 0, Max = 100, Rounding = 0, Suffix = '%', Callback = function() updateViewModelVisuals() end})

viewmodelTab:AddToggle('VMArmChams', {Text = 'Arm chams', Default = false, ColorPicker = {Idx = 'VMArmColor', Default = Color3.fromRGB(255, 255, 255), Title = 'Arm color', Transparency = 0}, Callback = function() updateViewModelVisuals() end})
viewmodelTab:AddDropdown('VMArmMaterial', {Values = {'SmoothPlastic', 'Neon', 'ForceField', 'Glass'}, Default = 'SmoothPlastic', Text = 'Arm material', Callback = function() updateViewModelVisuals() end})

viewmodelTab:AddToggle('VMRemoveSleeves', {Text = 'Remove sleeves', Default = false, Callback = function() updateViewModelVisuals() end})

RageSections.Exploit:AddToggle('ExploitKillAll', {Text = 'Kill all', Default = false, KeyPicker = {Idx = 'ExploitKillAllKeybind', Default = 'None', Mode = 'Hold', Text = 'Kill All'}})
RageSections.Exploit:AddToggle('ExploitNoFallDamage', {Text = 'No fall damage', Default = false})
espTab:AddToggle('ESPEnable', {Text = 'Enable', Default = false})
espTab:AddToggle('ESPTeamCheck', {Text = 'Team check', Default = false})
espTab:AddToggle('ESPBox', {Text = 'Box', Default = false, ColorPicker = {Idx = 'ESPBoxColor', Default = Color3.fromRGB(255, 255, 255), Title = 'Box color'}})
espTab:AddDropdown('ESPBoxType', {Values = {'Full', 'Corner'}, Default = 'Full', Text = 'Box type'})
espTab:AddToggle('ESPBoxFill', {Text = 'Box fill', Default = false, ColorPicker = {Idx = 'ESPBoxFillColor', Default = Color3.fromRGB(255, 255, 255), Transparency = 0.5, Title = 'Box fill color'}})
espTab:AddToggle('ESPName', {Text = 'Name', Default = false, ColorPicker = {Idx = 'ESPNameColor', Default = Color3.fromRGB(255, 255, 255), Title = 'Name color'}})
espTab:AddToggle('ESPHealthBar', {Text = 'Health bar', Default = false, ColorPicker = {Idx = 'ESPHealthBarColor', Default = Color3.fromRGB(0, 255, 0), Title = 'Health bar color'}})
espTab:AddToggle('ESPHealthBarOutline', {Text = 'Health bar outline', Default = true})
espTab:AddToggle('ESPWeapon', {Text = 'Weapon ESP', Default = false, ColorPicker = {Idx = 'ESPWeaponColor', Default = Color3.fromRGB(255, 255, 255), Title = 'Weapon color'}})
espTab:AddToggle('ESPChams', {Text = 'Chams', Default = false, ColorPicker = {Idx = 'ESPChamsColor', Default = Color3.fromRGB(255, 255, 255), Title = 'Chams color'}})
espTab:AddToggle('ESPChamsOutline', {Text = 'Chams outline', Default = false, ColorPicker = {Idx = 'ESPChamsOutlineColor', Default = Color3.fromRGB(255, 255, 255), Title = 'Chams outline color'}})
espTab:AddSlider('ESPChamsTransparency', {Text = 'Chams transparency', Default = 35, Min = 0, Max = 100, Rounding = 0})
espTab:AddToggle('ESPSkeleton', {Text = 'Skeleton', Default = false, ColorPicker = {Idx = 'ESPSkeletonColor', Default = Color3.fromRGB(255, 255, 255), Title = 'Skeleton color'}})
espTab:AddToggle('ESPItemESP', {Text = 'Item ESP', Default = false, ColorPicker = {Idx = 'ESPItemColor', Default = Color3.fromRGB(255, 255, 255), Title = 'Item color'}})

VisualSections.Menu:AddToggle('MenuBindList', {Text = 'Bind list', Default = true, Callback = function(Value) if Library.KeybindFrame then Library.KeybindFrame.Visible = Value end end})
VisualSections.Menu:AddToggle('MenuWatermark', {Text = 'Watermark', Default = true, Callback = function(Value) Library:SetWatermarkVisibility(Value) end})

VisualSections.Removals:AddToggle('RemovalsNoSmoke', {Text = 'No smoke', Default = false, Callback = function() setupNoSmoke() end})
VisualSections.Removals:AddToggle('RemovalsNoFlash', {Text = 'No flash', Default = false, Callback = function() updateNoFlash() end})
VisualSections.Removals:AddToggle('RemovalsNoScope', {Text = 'No scope', Default = false, Callback = function() updateNoScope() end})

VisualSections.ThirdPerson:AddToggle('ThirdPersonEnable', {Text = 'Enable', Default = false, KeyPicker = {Idx = 'ThirdPersonKeybind', Default = 'None', Mode = 'Toggle', Text = 'Third person'}})
VisualSections.ThirdPerson:AddSlider('ThirdPersonDistance', {Text = 'Distance', Default = 5, Min = 1, Max = 100, Rounding = 0})
VisualSections.ThirdPerson:AddToggle('ThirdPersonHideVM', {Text = 'Hide viewmodel', Default = true})
VisualSections.ThirdPerson:AddToggle('ThirdPersonNoClip', {Text = 'Camera through walls', Default = false, Callback = function() updateThirdPersonNoClip() end})

ambienceTab:AddToggle('AmbienceCustomTime', {Text = 'Custom time', Default = false}):OnChanged(function() MiscState.ambienceDirty = true end)
ambienceTab:AddSlider('AmbienceTime', {Text = 'Time', Default = 12, Min = 0, Max = 24, Rounding = 1}):OnChanged(function() MiscState.ambienceDirty = true end)
ambienceTab:AddToggle('AmbienceCustomSkybox', {Text = 'Custom skybox', Default = false, ColorPicker = {Idx = 'AmbienceSkyboxColor', Default = Color3.fromRGB(0, 0, 0), Title = 'Skybox color', Callback = function() MiscState.ambienceDirty = true end}}):OnChanged(function() MiscState.ambienceDirty = true end)
ambienceTab:AddToggle('AmbienceSkyColor', {Text = 'Sky color', Default = false, ColorPicker = {Idx = 'AmbienceSkyColorValue', Default = Color3.fromRGB(0, 0, 0), Title = 'Sky color', Callback = function() MiscState.ambienceDirty = true end}}):OnChanged(function() MiscState.ambienceDirty = true end)
ambienceTab:AddToggle('AmbienceNightMode', {Text = 'Night mode (walls)', Default = false, ColorPicker = {Idx = 'AmbienceNightColor', Default = Color3.fromRGB(20, 20, 40), Title = 'Night mode color', Callback = function() MiscState.ambienceDirty = true end}}):OnChanged(function() MiscState.ambienceDirty = true end)
ambienceTab:AddToggle('AmbienceNoShadow', {Text = 'No shadow', Default = false}):OnChanged(function() MiscState.ambienceDirty = true end)
ambienceTab:AddSlider('AmbienceBrightness', {Text = 'Brightness', Default = 0, Min = -10, Max = 10, Rounding = 1}):OnChanged(function() MiscState.ambienceDirty = true end)

ambienceTab:AddToggle('AmbienceSkyboxChanger', {Text = 'Skybox changer', Default = false, Callback = function() applySkyboxChanger() end})
ambienceTab:AddDropdown('AmbienceSkyboxPreset', {
    Text = 'Skybox preset',
    Values = {"Game's Sky", "Purple Nebula", "Night Sky", "Pink Daylight", "Morning Glow", "Setting Sun", "Fade Blue", "Elegant Morning", "Neptune", "Redshift", "Aesthetic Night", "Gloomy Gray", "Light Within Dark", "Green Space", "The Winter", "Oblivion", "Final Bloodmoon", "Clouds", "Twilight", "Red Mountain", "Cloudy Skies", "Dark Blue"},
    Default = "Game's Sky",
    Callback = function() applySkyboxChanger() end,
})
ambienceTab:AddInput('AmbienceSkyboxAssetId', {Text = 'Custom asset ID', Default = '', Placeholder = 'e.g. 159454299', Callback = function() applySkyboxChanger() end})

ThemeManager:SetLibrary(Library)
SaveManager:SetLibrary(Library)
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({ 'SkinKnifeSkin', 'SkinWeaponSkin', 'SkinGloveSkin' })
ThemeManager:SetFolder('Valenok')
SaveManager:SetFolder('Valenok')

do
    local ConfigSection = Tabs.Config:AddLeftGroupbox('Menu')
    ConfigSection:AddButton('Unload', function()
        if unloadValenok then unloadValenok() end
    end)
    ConfigSection:AddLabel('Menu bind'):AddKeyPicker('MenuKeybind', { Default = 'End', NoUI = true, Text = 'Menu' })
end

Library.ToggleKeybind = Options.MenuKeybind
Library.KeybindFrame.Visible = true

SaveManager:BuildConfigSection(Tabs.Config)
ThemeManager:ApplyToTab(Tabs.Config)
end)()


-- hooks & ecosystem

-- hide game crosshair when center dot or hide crosshair is enabled
;(function()
local CrosshairHideState = { lastHideState = nil, conns = {} }

local function applyCrosshairHide(child)
    if child:IsA("Frame") then
        child.Transparency = 1
    elseif child:IsA("ImageLabel") or child:IsA("ImageButton") then
        child.ImageTransparency = 1
    elseif child:IsA("TextLabel") or child:IsA("TextButton") then
        child.TextTransparency = 1
        child.TextStrokeTransparency = 1
    end
end

local function setupCrosshairHide()
    local hideEnabled = (Toggles.MiscHideCrosshair and Toggles.MiscHideCrosshair.Value)
        or (Toggles.MiscCenterDot and Toggles.MiscCenterDot.Value)

    if hideEnabled == CrosshairHideState.lastHideState then return end
    CrosshairHideState.lastHideState = hideEnabled

    for _, conn in ipairs(CrosshairHideState.conns) do
        if conn then conn:Disconnect() end
    end
    CrosshairHideState.conns = {}

    if hideEnabled then
        local gui = getGuiFrame()
        if gui then
            local ch = gui:FindFirstChild("Crosshairs")
            if ch then
                for _, child in ipairs(ch:GetDescendants()) do
                    applyCrosshairHide(child)
                end
                table.insert(CrosshairHideState.conns, ch.DescendantAdded:Connect(function(child)
                    applyCrosshairHide(child)
                end))
            end
        end
    end
end

Toggles.MiscHideCrosshair:OnChanged(setupCrosshairHide)
Toggles.MiscCenterDot:OnChanged(setupCrosshairHide)
task.spawn(setupCrosshairHide)
end)()


-- Ambience
local AmbienceState = {
    OrigTime = nil,
    OrigSky = nil,
    OrigAtmColor = nil,
    OrigBrightness = nil,
    OrigShadows = nil,
    NightParts = {},
    NightOrigColors = {},
    SkyObj = nil,
    NightActive = false,
}
;(function()
local Lighting = game:GetService("Lighting")

local function ambienceRestoreSky()
    if AmbienceState.SkyObj then
        AmbienceState.SkyObj:Destroy()
        AmbienceState.SkyObj = nil
    end
    if AmbienceState.OrigSky then
        AmbienceState.OrigSky.Parent = Lighting
        AmbienceState.OrigSky = nil
    end
end

local function ambienceRestoreNight()
    if AmbienceState.NightActive then
        for _, part in ipairs(AmbienceState.NightParts) do
            local origColor = AmbienceState.NightOrigColors[part]
            if origColor and part and part.Parent then
                part.Color = origColor
            end
        end
        AmbienceState.NightParts = {}
        AmbienceState.NightOrigColors = {}
        AmbienceState.NightActive = false
    end
end

task.spawn(function()
    while task.wait(0.2) do
            -- Custom time
            if Toggles.AmbienceCustomTime and Toggles.AmbienceCustomTime.Value then
                if AmbienceState.OrigTime == nil then AmbienceState.OrigTime = Lighting.ClockTime end
                local t = Options.AmbienceTime and Options.AmbienceTime.Value or 12
                Lighting.ClockTime = t
            else
                if AmbienceState.OrigTime ~= nil then
                    Lighting.ClockTime = AmbienceState.OrigTime
                    AmbienceState.OrigTime = nil
                end
            end

            -- No shadow
            if Toggles.AmbienceNoShadow and Toggles.AmbienceNoShadow.Value then
                if AmbienceState.OrigShadows == nil then AmbienceState.OrigShadows = Lighting.GlobalShadows end
                Lighting.GlobalShadows = false
            else
                if AmbienceState.OrigShadows ~= nil then
                    Lighting.GlobalShadows = AmbienceState.OrigShadows
                    AmbienceState.OrigShadows = nil
                end
            end

            -- Brightness
            do
                local bval = Options.AmbienceBrightness and Options.AmbienceBrightness.Value or 0
                if bval ~= 0 then
                    if AmbienceState.OrigBrightness == nil then AmbienceState.OrigBrightness = Lighting.Brightness end
                    Lighting.Brightness = math.clamp(1 + bval * 0.1, 0, 5)
                else
                    if AmbienceState.OrigBrightness ~= nil then
                        Lighting.Brightness = AmbienceState.OrigBrightness
                        AmbienceState.OrigBrightness = nil
                    end
                end
            end

            -- Custom skybox
            if Toggles.AmbienceCustomSkybox and Toggles.AmbienceCustomSkybox.Value then
                local skyColor = getOptionColor("AmbienceSkyboxColor", Color3.fromRGB(0, 0, 0))
                if not AmbienceState.SkyObj then
                    -- stash original sky
                    local origSky = Lighting:FindFirstChildOfClass("Sky")
                    if origSky then
                        origSky.Parent = nil
                        AmbienceState.OrigSky = origSky
                    end
                    local s = Instance.new("Sky")
                    s.SkyboxBk = "rbxasset://sky/sky512_bk.tex"
                    s.SkyboxDn = "rbxasset://sky/sky512_dn.tex"
                    s.SkyboxFt = "rbxasset://sky/sky512_ft.tex"
                    s.SkyboxLf = "rbxasset://sky/sky512_lf.tex"
                    s.SkyboxRt = "rbxasset://sky/sky512_rt.tex"
                    s.SkyboxUp = "rbxasset://sky/sky512_up.tex"
                    s.Parent = Lighting
                    AmbienceState.SkyObj = s
                end
                -- tint via Atmosphere ColorCorrection workaround: use sky color override
                local atm = Lighting:FindFirstChildOfClass("ColorCorrectionEffect")
                if not atm then
                    atm = Instance.new("ColorCorrectionEffect")
                    atm.Name = "ValenokSkyCC"
                    atm.Parent = Lighting
                end
                atm.TintColor = skyColor
            else
                ambienceRestoreSky()
                local cc = Lighting:FindFirstChild("ValenokSkyCC")
                if cc then cc:Destroy() end
            end

            -- Sky color (Atmosphere)
            if Toggles.AmbienceSkyColor and Toggles.AmbienceSkyColor.Value then
                local skyCol = getOptionColor("AmbienceSkyColorValue", Color3.fromRGB(0, 0, 255))
                local atm = Lighting:FindFirstChildOfClass("Atmosphere")
                if atm then
                    if AmbienceState.OrigAtmColor == nil then AmbienceState.OrigAtmColor = atm.Color end
                    atm.Color = skyCol
                else
                    -- inject ColorCorrectionEffect if no Atmosphere
                    local cc = Lighting:FindFirstChild("ValenokSkyColorCC")
                    if not cc then
                        cc = Instance.new("ColorCorrectionEffect")
                        cc.Name = "ValenokSkyColorCC"
                        cc.Parent = Lighting
                    end
                    cc.TintColor = skyCol
                end
            else
                if AmbienceState.OrigAtmColor ~= nil then
                    local atm = Lighting:FindFirstChildOfClass("Atmosphere")
                    if atm then atm.Color = AmbienceState.OrigAtmColor end
                    AmbienceState.OrigAtmColor = nil
                end
                local cc = Lighting:FindFirstChild("ValenokSkyColorCC")
                if cc then cc:Destroy() end
            end

            -- Night mode (walls)
            if Toggles.AmbienceNightMode and Toggles.AmbienceNightMode.Value then
                if not AmbienceState.NightActive then
                    AmbienceState.NightActive = true
                    AmbienceState.NightParts = {}
                    AmbienceState.NightOrigColors = {}
                    local nightColor = getOptionColor("AmbienceNightColor", Color3.fromRGB(20, 20, 40))
                    for _, obj in ipairs(workspace:GetDescendants()) do
                        if obj:IsA("BasePart") and not obj:IsA("MeshPart") then
                            AmbienceState.NightOrigColors[obj] = obj.Color
                            obj.Color = nightColor
                            table.insert(AmbienceState.NightParts, obj)
                        end
                    end
                    AmbienceState.LastNightColor = nightColor
                else
                    -- update color if changed
                    local nightColor = getOptionColor("AmbienceNightColor", Color3.fromRGB(20, 20, 40))
                    if nightColor ~= AmbienceState.LastNightColor then
                        AmbienceState.LastNightColor = nightColor
                        for _, part in ipairs(AmbienceState.NightParts) do
                            if part and part.Parent then part.Color = nightColor end
                        end
                    end
                end
            else
                ambienceRestoreNight()
            end
    end
end)
end)()

local restoreNamecallHook

-- Silent aim helpers (ported from SilentAim.lua)
;(function()
local function buildSilentRay(targetPart)
    local targetPos = targetPart.Position
    local cam = getCamera()
    local rayOrigin = cam.CFrame.Position
    local dist = (rayOrigin - targetPos).Magnitude
    local predicted = targetPos + Vector3.new(0, dist / 500, 0)
    return Ray.new(rayOrigin, (predicted - rayOrigin).Unit * 500), rayOrigin, predicted
end

local function encodeHitPos(pos)
    return Vector3.new(
        ((pos.X - 156325) * 13 + 17854) * 16,
        (pos.Y + 64000) * 7 - 142657,
        (pos.Z * 9 - 47000) * 6
    )
end

local function applySilentHitParl(args)
    local tgt = getgenv().PSilentTarget
    if not tgt or not tgt.Parent then return args end
    local hitPos = tgt.CFrame and tgt.CFrame.Position or tgt.Position
    args[1] = tgt
    args[2] = encodeHitPos(hitPos)
    if typeof(args[10]) == "Vector3" and typeof(args[12]) == "Vector3" then
        local dir = hitPos - args[10]
        if dir.Magnitude > 0.001 then
            args[12] = dir.Unit
        end
    end
    return args
end

-- namecall hook
_oldNamecall = nil

restoreNamecallHook = function()
    pcall(function()
        if _oldNamecall then
            hookmetamethod(game, "__namecall", _oldNamecall)
            _oldNamecall = nil
        end
    end)
end


pcall(function()
    _oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
        local method = getnamecallmethod()
        local silentTarget = getgenv().PSilentTarget
        local silentActive = silentTarget and silentTarget.Parent ~= nil

        -- Redirect FindPartOnRay variants
        if silentActive and not getgenv().IgnoreRaycastHook and string.find(method, "FindPartOnRay") then
            local fakeRay = buildSilentRay(silentTarget)
            return _oldNamecall(self, fakeRay, select(2, ...))
        end

        -- Redirect workspace:Raycast
        if silentActive and not getgenv().IgnoreRaycastHook and method == "Raycast" and self == Workspace then
            local origin, direction = unpack({...})
            if typeof(origin) == "Vector3" and typeof(direction) == "Vector3" then
                local _, rayOrigin, predicted = buildSilentRay(silentTarget)
                local mag = direction.Magnitude
                if mag < 0.001 then mag = 500 end
                return _oldNamecall(self, rayOrigin, (predicted - rayOrigin).Unit * mag, select(3, ...))
            end
        end

        -- Viewmodel offset
        if (method == "SetPrimaryPartCFrame" or method == "PivotTo" or method == "pivotTo") then
            if Toggles.VMOffsetEnable and Toggles.VMOffsetEnable.Value and self.Name ~= "HumanoidRootPart" then
                local isArms = false
                local p = self
                while p do
                    if p.Name == "Arms" then isArms = true; break end
                    p = p.Parent
                end
                if isArms then
                    local args = {...}
                    local cf = args[1]
                    if typeof(cf) == "CFrame" then
                        local offX = (Options.VMOffsetX and Options.VMOffsetX.Value or 0) / 10
                        local offY = (Options.VMOffsetY and Options.VMOffsetY.Value or 0) / 10
                        local offZ = (Options.VMOffsetZ and Options.VMOffsetZ.Value or 0) / 10
                        local roll = math.rad(Options.VMRoll and Options.VMRoll.Value or 0)
                        cf = cf * CFrame.new(offX, offY, -offZ) * CFrame.Angles(0, 0, roll)
                        return _oldNamecall(self, cf, select(2, ...))
                    end
                end
            end
        end

        if method == "FireServer" then
            local args = table.pack(...)
            if self.Name == "ControlTurn" then
                if Toggles.AntiAimPitchEnable and Toggles.AntiAimPitchEnable.Value then
                    local pitchMode = Options.AntiAimPitchMode and Options.AntiAimPitchMode.Value or "None"
                    if pitchMode ~= "None" then
                        local hookArgs = {...}
                        if pitchMode == "Down" then
                            hookArgs[1] = -1
                        elseif pitchMode == "Up" then
                            hookArgs[1] = 1
                        elseif pitchMode == "Custom" then
                            hookArgs[1] = Options.AntiAimPitchCustom and Options.AntiAimPitchCustom.Value or 0
                        elseif pitchMode == "Random" then
                            hookArgs[1] = AntiAimState.PitchRandomAngle
                        end
                        return _oldNamecall(self, unpack(hookArgs))
                    end
                end
            end
            if self.Name == "HitParl" then
                local args = table.pack(...)
                local hitPart = args[1]
                -- Silent aim: redirect hit to PSilentTarget
                if silentActive then
                    args = applySilentHitParl(args)
                    hitPart = args[1]
                end
                if not hitPart or not hitPart.Parent then
                    return _oldNamecall(self, unpack(args, 1, args.n))
                end
                -- Hit feedback runs async (spawn) like clarity.tk to avoid blocking the remote
                task.spawn(function()
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
                    pcall(function()
                        if Toggles.MiscHitChams and Toggles.MiscHitChams.Value then
                            local targetChar = nil
                            if hitPart and hitPart.Parent and hitPart.Parent:FindFirstChildOfClass("Humanoid") then
                                targetChar = hitPart.Parent
                            elseif silentTarget then
                                if silentTarget.Parent and silentTarget.Parent:FindFirstChildOfClass("Humanoid") then
                                    targetChar = silentTarget.Parent
                                elseif silentTarget:FindFirstChildOfClass("Humanoid") then
                                    targetChar = silentTarget
                                end
                            end
                            if targetChar then
                                local targetPlayer = Players:GetPlayerFromCharacter(targetChar)
                                if targetPlayer then
                                    local lifetime = Options.MiscHitChamsLifetime and Options.MiscHitChamsLifetime.Value or 1.3
                                    hitChams(targetPlayer, nil, 0, lifetime)
                                end
                            end
                        end
                    end)
                    pcall(function()
                        if Toggles.MiscHitLog and Toggles.MiscHitLog.Value then
                            local partName = hitPart and hitPart.Name or "?"
                            if string.find(partName, "Head") then partName = "Head" end
                            local hitChar = hitPart and hitPart.Parent
                            local hitPlayer = hitChar and Players:GetPlayerFromCharacter(hitChar)
                            local name = hitPlayer and hitPlayer.Name or "?"
                            local weaponName = "?"
                            local char = LocalPlayer.Character
                            if char then
                                local eqTool = char:FindFirstChild("EquippedTool")
                                if eqTool and type(eqTool.Value) == "string" then
                                    weaponName = eqTool.Value
                                end
                            end
                            pushHitLog("Hit " .. name .. " in the " .. tostring(partName) .. " with a " .. tostring(weaponName))
                        end
                    end)
                end)
                return _oldNamecall(self, unpack(args, 1, args.n))
            end

            if self.Name == "Trail" then
                if Toggles.MiscBulletTracer and Toggles.MiscBulletTracer.Value then
                    task.spawn(function()
                        pcall(function()
                            local startPos = args[1].Position
                            local endPos = args[2]
                            if startPos and endPos then
                                drawBulletTracer(startPos, endPos)
                            end
                        end)
                    end)
                end
            end

            if self.Name == "ReplicateShot" then
                pcall(function()
                    if Toggles.PeekAssistEnable and Toggles.PeekAssistEnable.Value then
                        peekAssistOnShot()
                    end
                end)
            end
        end

        return _oldNamecall(self, ...)
    end)
end)
end)()


;(function()
    local function fireHitFeedback()
        pcall(function()
            if Toggles.MiscHitSound and Toggles.MiscHitSound.Value then PlayHitSound() end
        end)
        pcall(function()
            if Toggles.MiscHitMarker and Toggles.MiscHitMarker.Value then ShowHitMarker() end
        end)
    end

    local function bindTotalDamage()
        local additionals = LocalPlayer:FindFirstChild("Additionals")
        if not additionals then return false end
        local totalDamage = additionals:FindFirstChild("TotalDamage")
        if not totalDamage then return false end
        if EspRuntime.Connections.TotalDamageChanged then
            pcall(function() EspRuntime.Connections.TotalDamageChanged:Disconnect() end)
        end
        local oldDamage = totalDamage.Value
        EspRuntime.Connections.TotalDamageChanged = totalDamage.Changed:Connect(function(newVal)
            if newVal > oldDamage then fireHitFeedback() end
            oldDamage = newVal
        end)
        return true
    end

    task.spawn(function()
        local additionals = LocalPlayer:WaitForChild("Additionals", 10)
        if not bindTotalDamage() and additionals then
            -- TotalDamage may be created after Additionals
            EspRuntime.Connections.TotalDamageAdded = additionals.ChildAdded:Connect(function(child)
                if child.Name == "TotalDamage" then bindTotalDamage() end
            end)
        end
    end)
end)()


-- FOV circle init
if getgenv().ValenokFovCircles then
    for _, c in ipairs(getgenv().ValenokFovCircles) do
        pcall(function() c.Visible = false; c:Remove() end)
    end
end
ensureFovCircles()
getgenv().ValenokFovCircles = { AimRuntime.AimFovCircle, AimRuntime.RageFovCircle }


_hitSoundObj = Instance.new("Sound")
_hitSoundObj.Parent = workspace

-- unload
unloadValenok = function()
    restoreNamecallHook()
    getgenv().PSilentTarget = nil

    -- Restore original skybox
    if SkyboxState.customSky then
        pcall(function() SkyboxState.customSky:Destroy() end)
        SkyboxState.customSky = nil
    end
    if SkyboxState.originalSky and not SkyboxState.originalSky.Parent then
        pcall(function() SkyboxState.originalSky.Parent = game:GetService('Lighting') end)
    end

    if HitMarkerState.HeartbeatConn then
        HitMarkerState.HeartbeatConn:Disconnect()
        HitMarkerState.HeartbeatConn = nil
    end

    ConnectionManager:CleanupAll()

    for _, Connection in pairs(EspRuntime.Connections) do
        pcall(function() Connection:Disconnect() end)
    end
    table.clear(EspRuntime.Connections)

    for _, c in ipairs({ AimRuntime.AimFovCircle, AimRuntime.RageFovCircle }) do
        pcall(function() c.Visible = false; c:Remove() end)
    end
    AimRuntime.AimFovCircle = nil
    AimRuntime.RageFovCircle = nil

    if CrosshairState.Circle then
        pcall(function() CrosshairState.Circle.Visible = false; CrosshairState.Circle:Remove() end)
        CrosshairState.Circle = nil
    end
    if CrosshairState.Outline then
        pcall(function() CrosshairState.Outline.Visible = false; CrosshairState.Outline:Remove() end)
        CrosshairState.Outline = nil
    end
    if CrosshairState.StateText then
        pcall(function() CrosshairState.StateText.Visible = false; CrosshairState.StateText:Remove() end)
        CrosshairState.StateText = nil
    end
    CrosshairState.Created = false

    if HitLogGui then
        pcall(function() HitLogGui:Destroy() end)
        HitLogGui = nil
        HitLogContainer = nil
        HitLogCount = 0
    end

    if getgenv().ValenokHitMarker then
        for _, d in ipairs(getgenv().ValenokHitMarker) do
            pcall(function() d.Visible = false; d:Remove() end)
        end
        getgenv().ValenokHitMarker = nil
    end

    hidePeekCircle()
    for i = 1, PEEK_CIRCLE_SEGMENTS do
        pcall(function() PeekDraw.CircleLines[i]:Remove() end)
        if PeekDraw.CircleOutlines[i] then pcall(function() PeekDraw.CircleOutlines[i]:Remove() end) end
    end
    for i = 1, PEEK_FILL_SEGMENTS do
        pcall(function() PeekDraw.FillLines[i]:Remove() end)
    end

    for i = #TracerPool, 1, -1 do
        local set = TracerPool[i]
        pcall(function() set.beam:Destroy() end)
        pcall(function() set.att0:Destroy() end)
        pcall(function() set.att1:Destroy() end)
        TracerPool[i] = nil
    end

    applyNoScope(false)

    local pg = getPlayerGui()
    local blnd = pg and pg:FindFirstChild("Blnd")
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

    table.clear(EspPlayerCache)
    table.clear(EspFrameCache.toggles)
    table.clear(EspFrameCache.options)
    table.clear(EspFrameCache.colors)
    EspFrameCache.tick = 0
    EspFrameCache.anyEnabled = false

    if _hitSoundObj then pcall(function() _hitSoundObj:Destroy() end) end

    pcall(function()
        RunService:UnbindFromRenderStep("ValenokTPNoClip")
    end)

    pcall(function()
        LocalPlayer.CameraMaxZoomDistance = 0.5
        LocalPlayer.CameraMinZoomDistance = 0.5
        local character = LocalPlayer.Character
        local _, humanoid = getCachedCharacterParts(LocalPlayer)
        if humanoid then humanoid.AutoRotate = true end
        -- restore viewmodel
        local cam = getCamera()
        if cam then
            local arms = cam:FindFirstChild("Arms")
            if arms then
                for _, part in ipairs(arms:GetDescendants()) do
                    if part:IsA("BasePart") or part:IsA("MeshPart") then
                        part.LocalTransparencyModifier = 0
                    end
                end
            end
        end
    end)

    TriggerbotState = {
        NextFireTime = 0,
        StopTime = 0,
        WasMoving = false,
        DelayUntil = 0,
        DelayActive = false,
        IsFiring = false,
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
            -- restore sky textures
            if AmbienceSavedLighting.SkyTextures and AmbienceSavedLighting.Skybox then
                local t = AmbienceSavedLighting.SkyTextures
                local sky = AmbienceSavedLighting.Skybox
                sky.SkyboxBk = t.SkyboxBk
                sky.SkyboxDn = t.SkyboxDn
                sky.SkyboxFt = t.SkyboxFt
                sky.SkyboxLf = t.SkyboxLf
                sky.SkyboxRt = t.SkyboxRt
                sky.SkyboxUp = t.SkyboxUp
                sky.StarCount = t.StarCount
                sky.SunTextureId = t.SunTextureId
                sky.MoonTextureId = t.MoonTextureId
                sky.CelestialBodiesSize = t.CelestialBodiesSize
            end
            -- restore fog
            if AmbienceSavedLighting.FogColor then
                Lighting.FogColor = AmbienceSavedLighting.FogColor
                Lighting.FogEnd = AmbienceSavedLighting.FogEnd
            end
        end)
        AmbienceSavedLighting = nil
    end

    -- restore game crosshair visibility
    pcall(function()
        if CrosshairState.Circle then CrosshairState.Circle.Visible = false; CrosshairState.Circle:Remove() end
        if CrosshairState.Outline then CrosshairState.Outline.Visible = false; CrosshairState.Outline:Remove() end
        if CrosshairState.StateText then CrosshairState.StateText.Visible = false; CrosshairState.StateText:Remove() end
        CrosshairState.Circle = nil
        CrosshairState.Outline = nil
        CrosshairState.StateText = nil
        CrosshairState.Created = false
    end)

    -- restore game crosshair
    pcall(function()
        local gui = getGuiFrame()
        if gui then
            local ch = gui:FindFirstChild("Crosshairs")
            if ch then
                for _, child in ipairs(ch:GetDescendants()) do
                    if child:IsA("Frame") then
                        child.Transparency = 0
                    elseif child:IsA("ImageLabel") or child:IsA("ImageButton") then
                        child.ImageTransparency = 0
                    elseif child:IsA("TextLabel") or child:IsA("TextButton") then
                        child.TextTransparency = 0
                        child.TextStrokeTransparency = 0
                    end
                end
            end
        end
    end)

    -- cleanup GrenadeRuntime
    pcall(function()
        if GrenadeRuntime and GrenadeRuntime.Folder then
            GrenadeRuntime.Folder:Destroy()
        end
    end)

    -- cleanup AmbienceState (new runtime)
    pcall(function()
        local LightingSvc = game:GetService("Lighting")
        if AmbienceState then
            if AmbienceState.OrigTime ~= nil then LightingSvc.ClockTime = AmbienceState.OrigTime end
            if AmbienceState.OrigShadows ~= nil then LightingSvc.GlobalShadows = AmbienceState.OrigShadows end
            if AmbienceState.OrigBrightness ~= nil then LightingSvc.Brightness = AmbienceState.OrigBrightness end
            if AmbienceState.OrigAtmColor ~= nil then
                local atm = LightingSvc:FindFirstChildOfClass("Atmosphere")
                if atm then atm.Color = AmbienceState.OrigAtmColor end
            end
            local skyCC = LightingSvc:FindFirstChild("ValenokSkyCC")
            if skyCC then skyCC:Destroy() end
            local skyColorCC = LightingSvc:FindFirstChild("ValenokSkyColorCC")
            if skyColorCC then skyColorCC:Destroy() end
            if AmbienceState.SkyObj then
                pcall(function() AmbienceState.SkyObj:Destroy() end)
                AmbienceState.SkyObj = nil
            end
            if AmbienceState.OrigSky then
                pcall(function() AmbienceState.OrigSky.Parent = LightingSvc end)
                AmbienceState.OrigSky = nil
            end
            if AmbienceState.NightActive then
                for _, part in ipairs(AmbienceState.NightParts) do
                    local origColor = AmbienceState.NightOrigColors[part]
                    if origColor and part and part.Parent then
                        pcall(function() part.Color = origColor end)
                    end
                end
                AmbienceState.NightParts = {}
                AmbienceState.NightOrigColors = {}
                AmbienceState.NightActive = false
            end
        end
    end)

    if SpeedHackState and SpeedHackState.Conn then
        SpeedHackState.Conn:Disconnect()
        SpeedHackState.Conn = nil
    end
    pcall(restoreSpeedHackOriginal)

    if AutoJumpState and AutoJumpState.Conn then
        AutoJumpState.Conn:Disconnect()
        AutoJumpState.Conn = nil
    end
    if AutoCrouchState and AutoCrouchState.Conn then
        AutoCrouchState.Conn:Disconnect()
        AutoCrouchState.Conn = nil
    end
    pcall(function() VirtualInputManager:SendKeyEvent(false, MoveUtil.MOVE_KEY_CTRL, false, game) end)

    if BhopState and BhopState.Conn then
        BhopState.Conn:Disconnect()
        BhopState.Conn = nil
    end
    pcall(function()
        local hum = MoveUtil.getLocalHumanoid()
        if hum then hum.WalkSpeed = CONSTANTS.DEFAULT_WALK_SPEED end
    end)

    if LegitBhopState and LegitBhopState.Conn then
        LegitBhopState.Conn:Disconnect()
        LegitBhopState.Conn = nil
    end
    pcall(function()
        local hum = MoveUtil.getLocalHumanoid()
        if hum then hum.WalkSpeed = CONSTANTS.DEFAULT_WALK_SPEED end
    end)

    if NoclipState and NoclipState.Conn then
        NoclipState.Conn:Disconnect()
        NoclipState.Conn = nil
    end
    pcall(restoreNoclipParts)

    if FlyState and FlyState.Conn then
        FlyState.Conn:Disconnect()
        FlyState.Conn = nil
    end
    pcall(restoreFlyPhysics)

    Library:Unload()
end
getgenv().ValenokUnload = unloadValenok


-- weapon change listener for RapidFire
local function setupWeaponChangeListener(character)
    if not character then return end
    local eqTool = character:WaitForChild("EquippedTool", 5)
    if not eqTool then return end
    if EspRuntime.Connections.EquippedToolChanged then
        EspRuntime.Connections.EquippedToolChanged:Disconnect()
    end
    EspRuntime.Connections.EquippedToolChanged = eqTool.Changed:Connect(function()
        if Toggles.GunModsRapidFire and Toggles.GunModsRapidFire.Value then
            updateRapidFire()
        end
        if Toggles.RCSEnable and Toggles.RCSEnable.Value then
            updateRCS()
        end
    end)
    if Toggles.GunModsRapidFire and Toggles.GunModsRapidFire.Value then
        updateRapidFire()
    end
    if Toggles.RCSEnable and Toggles.RCSEnable.Value then
        updateRCS()
    end
end

if LocalPlayer.Character then
    task.spawn(setupWeaponChangeListener, LocalPlayer.Character)
end
EspRuntime.Connections.WeaponCharAdded = LocalPlayer.CharacterAdded:Connect(setupWeaponChangeListener)

EspRuntime.Connections.PlayerRemoving = Players.PlayerRemoving:Connect(function(player)
    pcall(function()
        removeDrawingSet(player)
        removeHighlight(player)

        if EspRuntime.Drawings[player] then
            for _, obj in pairs(EspRuntime.Drawings[player]) do
                pcall(function()
                    obj.Visible = false
                    obj:Remove()
                end)
            end
            EspRuntime.Drawings[player] = nil
        end

        if EspRuntime.Highlights[player] then
            pcall(function()
                EspRuntime.Highlights[player]:Destroy()
            end)
            EspRuntime.Highlights[player] = nil
        end

        invalidateEspPlayerCache(player)
    end)
end)


-- main loop
local LoopState = { espUpdate = 0, wFps = 0, wFrames = 0, wLastUpdate = 0, removalsCheck = 0, silentTargetUpdate = 0, vmUpdate = 0 }

EspRuntime.Connections.RenderStepped = RunService.RenderStepped:Connect(function(dt)
    pcall(function()
        local now = tick()
        LoopState.wFrames = LoopState.wFrames + 1
        MultiPointState.frame = MultiPointState.frame + 1

        local myChar = LocalPlayer.Character
        local myHum = myChar and myChar:FindFirstChildOfClass("Humanoid")
        local isAlive = myHum and myHum.Health > 0 and myChar.Parent

        if now - LoopState.removalsCheck >= 2 then
            LoopState.removalsCheck = now
            if Toggles.RemovalsNoScope and Toggles.RemovalsNoScope.Value then updateNoScope() end
            if Toggles.RemovalsNoFlash and Toggles.RemovalsNoFlash.Value then updateNoFlash() end
            if Toggles.RCSEnable and Toggles.RCSEnable.Value then updateRCS() end
        end

        if now - MultiPointState.lastClean >= 5 then
            MultiPointState.lastClean = now
            for part in pairs(MultiPointState.cache) do
                if not part or not part.Parent then
                    MultiPointState.cache[part] = nil
                end
            end
        end

        updateFovCircle()

        if isAlive then
            updateAimBot(dt)
        end

        -- Silent aim keybind handling
        local rageKey = Options.RagebotKeybind
        local keybindActive = false
        if rageKey then
            if rageKey.Value == "None" or rageKey.Mode == "Always" then
                keybindActive = true
            else
                keybindActive = isKeybindActive(rageKey)
            end
        end
        if Toggles.RagebotEnable and Toggles.RagebotEnable.Value and isAlive then
            silentActive = keybindActive
        else
            silentActive = false
        end
        
        -- Silent aim target update
        if silentActive then
            local mousePressed = UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
            local menuOpen = Library and Library.IsMenuVisible and Library:IsMenuVisible()
            local autoFire = Toggles.RagebotAutoFire and Toggles.RagebotAutoFire.Value and not menuOpen
            if mousePressed or autoFire then
                local silentTarget = getgenv().PSilentTarget
                if now - LoopState.silentTargetUpdate >= 0.006 then
                    LoopState.silentTargetUpdate = now
                    silentTarget = getNearestSilentTarget()
                end
                getgenv().PSilentTarget = silentTarget
                
                -- Auto fire functionality
                if autoFire and silentTarget then
                    -- Check if player is alive before auto firing
                    local _, myHumanoid = MoveUtil.getAliveMovementRig()
                    if not myHumanoid then
                        getgenv().PSilentTarget = nil
                        silentActive = false
                        return
                    end
                    
                    -- Check if we should auto fire (only if not already holding mouse button)
                    if not UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
                        local mouse = LocalPlayer:GetMouse()
                        local mouseX = mouse.X
                        local mouseY = mouse.Y
                        
                        -- Auto click to fire
                        task.spawn(function()
                            pcall(function()
                                VirtualInputManager:SendMouseButtonEvent(mouseX, mouseY, 0, true, game, 1)
                                task.wait(0.05)
                                VirtualInputManager:SendMouseButtonEvent(mouseX, mouseY, 0, false, game, 1)
                            end)
                        end)
                    end
                end
            else
                getgenv().PSilentTarget = nil
            end
        else
            getgenv().PSilentTarget = nil
        end
        
        updateCrosshair()

        -- ESP must be updated AFTER aimbot so it uses the final camera position
        if now - LoopState.espUpdate >= 1 / 180 then
            LoopState.espUpdate = now
            updateEspFrameCache()
            local plist = Players:GetPlayers()
            for i = 1, #plist do
                updatePlayerEsp(plist[i])
            end
            updateItemEsp()
        end

        if Toggles.MenuWatermark and Toggles.MenuWatermark.Value then
            if now - LoopState.wLastUpdate >= 0.3 then
                LoopState.wFps = math.floor(LoopState.wFrames / (now - LoopState.wLastUpdate))
                LoopState.wFrames = 0
                LoopState.wLastUpdate = now
                local ping = math.floor(LocalPlayer:GetNetworkPing() * 1000)
                local timeStr = os.date("%H:%M:%S")
                Library:SetWatermark(string.format("Valenok.lua  |  %d fps  |  %d ms  |  %s", LoopState.wFps, ping, timeStr))
            end
        end

        updateThirdPerson()
        if MiscState.ambienceDirty then
            MiscState.ambienceDirty = false
            updateAmbience()
        end
        if isAlive then
            updateTriggerbot()
            updateAntiAim()
            updateGrenadePrediction(dt)
            updatePeekAssist()
        end

        if now - LoopState.vmUpdate >= 0.5 then
            LoopState.vmUpdate = now
            local vmAnyEnabled = (Toggles.VMWeaponChams and Toggles.VMWeaponChams.Value)
                or (Toggles.VMArmChams and Toggles.VMArmChams.Value)
                or (Toggles.VMRemoveSleeves and Toggles.VMRemoveSleeves.Value)
            if vmAnyEnabled then
                updateViewModelVisuals()
            end
        end
    end)
end)


-- kill all heartbeat
EspRuntime.Connections.KillAllHeartbeat = RunService.Heartbeat:Connect(function()
    pcall(function()
        updateKillAll()
    end)
end)

print("Valenok")
print("version: 3.2")
print("open/close menu end")
print("status: discontinued")
Library:OnUnload(function()
    getgenv().ValenokUnload = nil
    if SC.State.armsConn then SC.State.armsConn:Disconnect(); SC.State.armsConn = nil end
    pcall(function()
        if SC.Viewmodels then
            if SC.Viewmodels:FindFirstChild("v_CT Knife") then SC.Viewmodels:FindFirstChild("v_CT Knife"):Destroy() end
            if SC.Viewmodels:FindFirstChild("v_T Knife") then SC.Viewmodels:FindFirstChild("v_T Knife"):Destroy() end
            if SC.OriginalCTKnife then SC.OriginalCTKnife:Clone().Parent = SC.Viewmodels end
            if SC.OriginalTKnife then SC.OriginalTKnife:Clone().Parent = SC.Viewmodels end
        end
    end)
end)


-- inject watermark & keybind position saving into SaveManager
;(function()
    local origSave = SaveManager.Save
    local origLoad = SaveManager.Load

    SaveManager.Save = function(self, name, ...)
        local success, err = origSave(self, name, ...)
        if not success then return false, err end

        -- append UI positions to the same config file
        pcall(function()
            local fullPath = self.Folder .. '/settings/' .. name .. '.json'
            if not isfile(fullPath) then return end
            local data = HttpService:JSONDecode(readfile(fullPath))
            data.uiPositions = {}
            if Library.Watermark then
                local p = Library.Watermark.Position
                data.uiPositions.Watermark = { p.X.Scale, p.X.Offset, p.Y.Scale, p.Y.Offset }
            end
            if Library.KeybindFrame then
                local p = Library.KeybindFrame.Position
                data.uiPositions.Keybind = { p.X.Scale, p.X.Offset, p.Y.Scale, p.Y.Offset }
            end
            writefile(fullPath, HttpService:JSONEncode(data))
        end)

        return true
    end

    SaveManager.Load = function(self, name, ...)
        local success, err = origLoad(self, name, ...)
        if not success then return false, err end

        -- Re-apply skybox after all options are loaded
        task.delay(0.1, function()
            pcall(function() applySkyboxChanger() end)
        end)

        -- restore UI positions from the same config file
        pcall(function()
            local fullPath = self.Folder .. '/settings/' .. name .. '.json'
            if not isfile(fullPath) then return end
            local data = HttpService:JSONDecode(readfile(fullPath))
            if not data.uiPositions then return end

            task.delay(0.1, function()
                pcall(function()
                    if data.uiPositions.Watermark and Library.Watermark then
                        local u = data.uiPositions.Watermark
                        Library.Watermark.Position = UDim2.new(u[1], u[2], u[3], u[4])
                    end
                    if data.uiPositions.Keybind and Library.KeybindFrame then
                        local u = data.uiPositions.Keybind
                        Library.KeybindFrame.Position = UDim2.new(u[1], u[2], u[3], u[4])
                    end
                end)
            end)
        end)

        return true
    end
end)()


-- Keybind list: only show currently active binds (Toggle on / Hold pressed)
;(function()
    local function refreshKeybindList()
        if not (Library and Library.KeybindContainer and Library.KeybindFrame) then return end

        -- build a map of option text -> is active
        local activeTexts = {}
        for _, opt in pairs(Options) do
            if type(opt) == 'table' and opt.Type == 'KeyPicker' then
                local key = opt.Value
                if key and key ~= "None" then
                    local mode = opt.Mode
                    if mode == "Toggle" or mode == "Hold" then
                        local isActive = isKeybindActive(opt)
                        if isActive then
                            -- store the Text label for matching
                            local labelText = opt.Text or ""
                            if labelText and labelText ~= "" then
                                activeTexts[labelText] = true
                            end
                        end
                    end
                end
            end
        end

        local YSize, XSize = 0, 0
        for _, lbl in next, Library.KeybindContainer:GetChildren() do
            if lbl:IsA('TextLabel') then
                -- hide Always, None, and header labels (no key in brackets)
                if string.find(lbl.Text, '%(Always%)') or string.find(lbl.Text, 'None') or not string.find(lbl.Text, '%[') then
                    lbl.Visible = false
                else
                    lbl.Visible = true
                end
                if lbl.Visible then
                    YSize = YSize + 18
                    if lbl.TextBounds.X > XSize then XSize = lbl.TextBounds.X end
                end
            end
        end
        Library.KeybindFrame.Size = UDim2.new(0, math.max(XSize + 10, 210), 0, YSize + 23)
    end

    -- hook into KeyPicker Update
    for _, opt in pairs(Options) do
        if type(opt) == 'table' and opt.Type == 'KeyPicker' and type(opt.Update) == 'function' then
            local orig = opt.Update
            opt.Update = function(self, ...)
                orig(self, ...)
                refreshKeybindList()
            end
        end
    end

    -- refresh every frame to catch Hold press/release and Toggle state changes
    EspRuntime.Connections.KeybindListRefresh = RunService.RenderStepped:Connect(function()
        pcall(refreshKeybindList)
    end)

    refreshKeybindList()
end)()


-- Persist watermark & keybind list positions (fallback: separate file for when config is not saved)
;(function()
    local UI_POS_FILE = "Valenok/ui_positions.json"
    pcall(function() if makefolder and not isfolder("Valenok") then makefolder("Valenok") end end)

    local function udimToTable(u)
        return { u.X.Scale, u.X.Offset, u.Y.Scale, u.Y.Offset }
    end
    local function tableToUDim(t)
        if type(t) ~= 'table' or #t < 4 then return nil end
        return UDim2.new(t[1], t[2], t[3], t[4])
    end

    local pending = false
    local function saveUiPositions()
        if pending then return end
        pending = true
        task.delay(0.4, function()
            pending = false
            pcall(function()
                local data = {}
                if Library.Watermark then data.Watermark = udimToTable(Library.Watermark.Position) end
                if Library.KeybindFrame then data.Keybind = udimToTable(Library.KeybindFrame.Position) end
                writefile(UI_POS_FILE, HttpService:JSONEncode(data))
            end)
        end)
    end

    -- load from fallback file on startup (config load will override if available)
    pcall(function()
        if not isfile(UI_POS_FILE) then return end
        local data = HttpService:JSONDecode(readfile(UI_POS_FILE))
        if data.Watermark and Library.Watermark then
            local u = tableToUDim(data.Watermark)
            if u then Library.Watermark.Position = u end
        end
        if data.Keybind and Library.KeybindFrame then
            local u = tableToUDim(data.Keybind)
            if u then Library.KeybindFrame.Position = u end
        end
    end)

    if Library.Watermark then
        Library:GiveSignal(Library.Watermark:GetPropertyChangedSignal('Position'):Connect(saveUiPositions))
    end
    if Library.KeybindFrame then
        Library:GiveSignal(Library.KeybindFrame:GetPropertyChangedSignal('Position'):Connect(saveUiPositions))
    end
end)()
