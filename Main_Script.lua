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

-- constants

local CONSTANTS = {
    DEFAULT_WALK_SPEED = 16,
    SKIN_FILE = "Valenok_skin/Skin.json",
    GITHUB_LIB_URL = "https://raw.githubusercontent.com/sixodicor-byte/1337/refs/heads/main/NewLib.lua",
    MAX_HIT_CHAMS_CLONES = 25,
    ESP_BOX_TOP_OFFSET = 2.45,
    ESP_BOX_BOTTOM_OFFSET = 3.1,
    ESP_BOX_THICKNESS = 1,
    ESP_BOX_OUTLINE_THICKNESS = 3,
    ESP_HEALTH_BAR_WIDTH = 3.5,
    ESP_HEALTH_BAR_OUTLINE_THICKNESS = 1,

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
        Arms = {
            "LeftUpperArm", "LeftLowerArm", "LeftHand",
            "RightUpperArm", "RightLowerArm", "RightHand",
        },
        Legs = {
            "LeftUpperLeg", "LeftLowerLeg", "LeftFoot",
            "RightUpperLeg", "RightLowerLeg", "RightFoot",
        },
    },
    RageHitboxPriority = { "Head", "Body", "Arms", "Legs" },
    RagebotFOVColor = Color3.fromRGB(255, 255, 255),
    RagebotDefaultHitboxes = { Head = true },
    RagebotDefaultMethod = "Ray redirect",
    RagebotDefaultMaxWalls = 3,
    RealHitboxNames = {
        "Head", "HeadHB", "FakeHead",
        "UpperTorso", "LowerTorso", "HumanoidRootPart",
        "LeftUpperArm", "LeftLowerArm", "LeftHand",
        "RightUpperArm", "RightLowerArm", "RightHand",
        "LeftUpperLeg", "LeftLowerLeg", "LeftFoot",
        "RightUpperLeg", "RightLowerLeg", "RightFoot",
    },
    RealHitboxLookup = {},
    RAPID_FIRE_MULTIPLIERS = {},
    RAPID_FIRE_DEFAULT_MULTIPLIER = 30,
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

ThemeManager = Library and Library.ThemeManager
SaveManager = Library and Library.SaveManager




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
    Chams = {},
    Connections = {},
}

local EspFrameCache = {
    tick = 0,
    anyEnabled = false,
    toggles = {},
    options = {},
    colors = {},
    boxFillTransparency = 1,
    chamsVisibleTransparency = 0.35,
    chamsWallTransparency = 0.35,
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

local VisibilityParams = RaycastParams.new()
VisibilityParams.FilterType = Enum.RaycastFilterType.Exclude
VisibilityParams.IgnoreWater = true

-- Silent aim / cache state packed to stay under Luau 200 main-chunk locals
local RuntimePack = {
    silentActive = false,
    HitpartSilent = {
        lastFire = 0,
        lastTargetScan = 0,
        lastCtxRefresh = 0,
        lastFireRateRefresh = 0,
        injecting = false,
        fireRate = 0.1,
        fireRateObj = nil,
        isHitpart = false,
        isRay = true,
        remote = nil,
        gunName = nil,
        charGun = nil,
        gunData = nil,
        flashed = false,
        noscope = false,
        airborne = false,
        smokeParams = nil,
        smokeFolder = nil,
        smokeFolderTick = 0,
    },

    mapFolder = nil,
    mapClips = nil,
    mapSpawns = nil,
    weaponsFolder = nil,
    playerGui = nil,
    guiFrame = nil,
}
local HitpartSilent = RuntimePack.HitpartSilent

local function getCamera()
    Camera = Workspace.CurrentCamera
    return Camera
end

local function getMapFolder()
    if RuntimePack.mapFolder and RuntimePack.mapFolder.Parent then return RuntimePack.mapFolder end
    RuntimePack.mapFolder = Workspace:FindFirstChild("Map")
    RuntimePack.mapClips = nil
    RuntimePack.mapSpawns = nil
    return RuntimePack.mapFolder
end

local function getMapClips()
    local map = getMapFolder()
    if not map then return nil end
    if RuntimePack.mapClips and RuntimePack.mapClips.Parent then return RuntimePack.mapClips end
    RuntimePack.mapClips = map:FindFirstChild("Clips")
    return RuntimePack.mapClips
end

local function getMapSpawns()
    local map = getMapFolder()
    if not map then return nil end
    if RuntimePack.mapSpawns and RuntimePack.mapSpawns.Parent then return RuntimePack.mapSpawns end
    RuntimePack.mapSpawns = map:FindFirstChild("SpawnPoints")
    return RuntimePack.mapSpawns
end


local function getWeaponsFolder()
    if RuntimePack.weaponsFolder and RuntimePack.weaponsFolder.Parent then return RuntimePack.weaponsFolder end
    RuntimePack.weaponsFolder = ReplicatedStorage:FindFirstChild("Weapons")
    return RuntimePack.weaponsFolder
end

local function getPlayerGui()
    if RuntimePack.playerGui and RuntimePack.playerGui.Parent then return RuntimePack.playerGui end
    RuntimePack.playerGui = LocalPlayer:FindFirstChild("PlayerGui")
    return RuntimePack.playerGui
end


local function getGuiFrame()
    local pg = getPlayerGui()
    if not pg then return nil end
    if RuntimePack.guiFrame and RuntimePack.guiFrame.Parent then return RuntimePack.guiFrame end
    RuntimePack.guiFrame = pg:FindFirstChild("GUI")
    return RuntimePack.guiFrame
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

local RayIgnoreListCache = { list = nil, t = 0 }
local EnemyRayIgnoreNames = {
    HumanoidRootPart = true,
    Gun = true,
    Head = true,
    BackC4 = true,
}
for i = 1, 15 do
    EnemyRayIgnoreNames["Hat" .. i] = true
end

local function isCompetitiveOrDeathmatch()
    local status = Workspace:FindFirstChild("Status")
    if not status then
        local lpStatus = LocalPlayer:FindFirstChild("Status")
        status = lpStatus
    end
    if not status then return false end

    local modeObj = status:FindFirstChild("Mode")
        or status:FindFirstChild("GameMode")
        or status:FindFirstChild("Gamemode")
        or status:FindFirstChild("Type")
        or status:FindFirstChild("GameType")
    if not modeObj then return false end

    local mode = tostring(modeObj.Value or modeObj):lower()
    if mode == "" then return false end
    if mode:find("comp", 1, true)
        or mode:find("death", 1, true)
        or mode == "dm"
        or mode:find("competitive", 1, true)
        or mode:find("deathmatch", 1, true)
    then
        return true
    end
    return false
end

local function isSameTeamPlayer(player)
    if not player or player == LocalPlayer then return false end
    local myTeam, theirTeam = LocalPlayer.Team, player.Team
    if myTeam ~= nil and theirTeam ~= nil and myTeam == theirTeam then
        return true
    end
    local myTeamColor, theirTeamColor = LocalPlayer.TeamColor, player.TeamColor
    if myTeamColor ~= nil and theirTeamColor ~= nil and myTeamColor == theirTeamColor then
        return true
    end

    local myStatus = LocalPlayer:FindFirstChild("Status")
    local theirStatus = player:FindFirstChild("Status")
    local myStatusTeam = myStatus and myStatus:FindFirstChild("Team")
    local theirStatusTeam = theirStatus and theirStatus:FindFirstChild("Team")
    if myStatusTeam and theirStatusTeam then
        local a, b = myStatusTeam.Value, theirStatusTeam.Value
        if a ~= nil and b ~= nil and a ~= "" and b ~= "" and a == b then
            return true
        end
    end
    return false
end

local function appendEnemyRayIgnoreParts(list, character)
    if not character then return end
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if hrp then table.insert(list, hrp) end
    local gun = character:FindFirstChild("Gun")
    if gun then table.insert(list, gun) end
    local head = character:FindFirstChild("Head")
    if head then table.insert(list, head) end
    local backC4 = character:FindFirstChild("BackC4")
    if backC4 then table.insert(list, backC4) end
    for i = 1, 15 do
        local hat = character:FindFirstChild("Hat" .. i)
        if hat then table.insert(list, hat) end
    end
end

local function buildRayIgnoreList()
    local now = tick()
    local cached = RayIgnoreListCache.list
    if cached and (now - RayIgnoreListCache.t) < 0.005 then
        return cached
    end

    local cam = getCamera() or Workspace.CurrentCamera
    local char = LocalPlayer.Character
    local rayIgnore = Workspace:FindFirstChild("Ray_Ignore") or getCachedRayIgnore()
    local debris = Workspace:FindFirstChild("Debris")
    local list = { cam, char, rayIgnore, debris }

    local clips = getMapClips()
    if clips then table.insert(list, clips) end
    local spawns = getMapSpawns()
    if spawns then table.insert(list, spawns) end
    if GrenadeRuntime and GrenadeRuntime.Folder then table.insert(list, GrenadeRuntime.Folder) end
    if HitChamsState and HitChamsState.Folder then table.insert(list, HitChamsState.Folder) end

    local ignoreFullTeammates = not isCompetitiveOrDeathmatch()
    for _, player in ipairs(Players:GetPlayers()) do
        if player == LocalPlayer then continue end
        local pChar = player.Character
        if not pChar then continue end

        if ignoreFullTeammates and isSameTeamPlayer(player) then
            table.insert(list, pChar)
        else
            appendEnemyRayIgnoreParts(list, pChar)
        end
    end

    RayIgnoreListCache.list = list
    RayIgnoreListCache.t = now
    return list
end

local function isUnderRayIgnore(inst)
    if not inst then return false end
    local rayIgnore = Workspace:FindFirstChild("Ray_Ignore") or getCachedRayIgnore()
    if rayIgnore and inst:IsDescendantOf(rayIgnore) then return true end
    local debris = Workspace:FindFirstChild("Debris")
    if debris and inst:IsDescendantOf(debris) then return true end

    local clips = getMapClips()
    if clips and inst:IsDescendantOf(clips) then return true end
    local spawns = getMapSpawns()
    if spawns and inst:IsDescendantOf(spawns) then return true end

    local cam = getCamera() or Workspace.CurrentCamera
    if cam and (inst == cam or inst:IsDescendantOf(cam)) then return true end

    local localChar = LocalPlayer.Character
    if localChar and inst:IsDescendantOf(localChar) then return true end

    if EnemyRayIgnoreNames[inst.Name] then
        local model = inst:FindFirstAncestorOfClass("Model")
        if model and Players:GetPlayerFromCharacter(model) then
            return true
        end
    end

    if not isCompetitiveOrDeathmatch() then
        local model = inst:FindFirstAncestorOfClass("Model")
        local plr = model and Players:GetPlayerFromCharacter(model)
        if plr and isSameTeamPlayer(plr) then
            return true
        end
    end

    return false
end

local function isSmokeLikePart(inst)
    if not inst then return false end
    local name = inst.Name
    if name == "Smoke" or name:find("Smoke") or name:find("Fire") or name:find("Flame") or name:find("Molotov") or name:find("Burn") then
        return true
    end
    if inst.Material == Enum.Material.Glass and inst.Transparency > 0.5 then return true end
    if inst.Transparency >= 0.9 and not inst.CanCollide then return true end
    return false
end

local function copyRayIgnoreList()
    local base = buildRayIgnoreList()
    local out = table.create(#base + 16)
    for i = 1, #base do
        out[i] = base[i]
    end
    return out
end

local function shouldPierceRayHit(inst)
    if not inst then return false end
    if isUnderRayIgnore(inst) or isSmokeLikePart(inst) then return true end
    if inst.CanQuery == false then return true end
    if inst.Transparency >= 1 then return true end
    return false
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

local function getChamsTransparency(optionName, fallback)
    local opt = Options[optionName]
    if type(opt) == "table" and type(opt.Transparency) == "number" then
        return math.clamp(opt.Transparency, 0, 1)
    end
    return fallback or 0.35
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

local ESP_FONT_MAP = {
    UI = 0,
    System = 1,
    Plex = 2,
    Monospace = 3,
}

local function getEspDrawingFont()
    local name = Options.ESPFont and Options.ESPFont.Value or "Plex"
    local id = ESP_FONT_MAP[name]
    if id == nil then id = 2 end
    if Drawing and Drawing.Fonts then
        if name == "UI" and Drawing.Fonts.UI then return Drawing.Fonts.UI end
        if name == "System" and Drawing.Fonts.System then return Drawing.Fonts.System end
        if name == "Plex" and Drawing.Fonts.Plex then return Drawing.Fonts.Plex end
        if name == "Monospace" and Drawing.Fonts.Monospace then return Drawing.Fonts.Monospace end
    end
    return id
end

local function getEspFontSize()
    local opt = Options.ESPFontSize
    if type(opt) == "table" and type(opt.Value) == "number" then
        return math.clamp(math.floor(opt.Value + 0.5), 1, 30)
    end
    return 13
end

local function createText(size)
    local text = Drawing.new("Text")
    text.Visible = false
    text.Center = true
    text.Outline = true
    text.Transparency = 1
    text.Size = size or getEspFontSize()
    text.Font = getEspDrawingFont()
    return text
end

local function createTriangle(filled, thickness, color)
    local triangle = Drawing.new("Triangle")
    triangle.Visible = false
    triangle.Filled = filled and true or false
    triangle.Thickness = thickness or 1
    triangle.Transparency = 1
    triangle.Color = color or Color3.fromRGB(255, 255, 255)
    return triangle
end


EspRuntime.RemoveDrawingValue = function(value, seen)
    if value == nil then return end

    local valueType = type(value)
    if valueType == "table" then
        seen = seen or {}
        if seen[value] then return end
        seen[value] = true

        local hasRemove = false
        pcall(function() hasRemove = type(value.Remove) == "function" end)
        if hasRemove then
            pcall(function()
                value.Visible = false
                value:Remove()
            end)
            return
        end

        for _, child in pairs(value) do
            EspRuntime.RemoveDrawingValue(child, seen)
        end
    elseif valueType == "userdata" then
        pcall(function()
            value.Visible = false
            value:Remove()
        end)
    end
end

local function getCharacterScreenBox(character, humanoid, rootPart)
    if not rootPart then return nil end

    local camera = getCamera()
    if not camera then return nil end

    local rootPos = rootPart.Position
    local topWorld = Vector3.new(rootPos.X, rootPos.Y + CONSTANTS.ESP_BOX_TOP_OFFSET, rootPos.Z)
    local bottomWorld = Vector3.new(rootPos.X, rootPos.Y - CONSTANTS.ESP_BOX_BOTTOM_OFFSET, rootPos.Z)

    local topScreen, topOn = camera:WorldToViewportPoint(topWorld)
    local bottomScreen, bottomOn = camera:WorldToViewportPoint(bottomWorld)
    if not topOn and not bottomOn then return nil end

    local height = bottomScreen.Y - topScreen.Y
    local width = height * 0.5
    local left = topScreen.X - width * 0.5
    local top = topScreen.Y

    return math.floor(left + 0.5), math.floor(top + 0.5), math.floor(width + 0.5), math.floor(height + 0.5)
end


local function isStrictRayVisible(targetPart)
    if not targetPart or not targetPart.Parent then return false end

    local cam = getCamera()
    if not cam then return false end

    local targetPos = targetPart.Position
    local origin = cam.CFrame.Position
    if (targetPos - origin).Magnitude <= 1e-4 then return false end

    local ignore = copyRayIgnoreList()
    VisibilityParams.FilterDescendantsInstances = ignore

    for _ = 1, 12 do
        local dir = targetPos - origin
        if dir.Magnitude <= 1e-4 then return false end

        getgenv().IgnoreRaycastHook = true
        local success, result = pcall(function()
            return Workspace:Raycast(origin, dir, VisibilityParams)
        end)
        getgenv().IgnoreRaycastHook = false

        if not success or not result or not result.Instance then
            return false
        end

        local hitInst = result.Instance
        if hitInst == targetPart then
            return true
        end

        local hitParent = hitInst.Parent
        if hitParent and hitParent:IsA("Accessory") and hitParent.Parent == targetPart.Parent then
            return true
        end
        if hitParent == targetPart.Parent and hitInst:IsA("BasePart") then
            return true
        end

        if shouldPierceRayHit(hitInst) then
            table.insert(ignore, hitInst)
            VisibilityParams.FilterDescendantsInstances = ignore
            origin = result.Position + dir.Unit * 0.05
        else
            return false
        end
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

    getgenv().IgnoreRaycastHook = true
    local ok, err = pcall(function()
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
    end)
    getgenv().IgnoreRaycastHook = false
    if not ok then return 0 end
    
    return wallCount
end

-- Enhanced visibility check with wall penetration
local function isVisibleWithWalls(targetPart, maxWalls)
    local cam = getCamera()
    if not cam then return false end
    local originPos = cam.CFrame.Position
    local targetPos = targetPart.Position
    
    local walls = getWallCount(originPos, targetPos, maxWalls)
    return walls <= maxWalls
end

do
    local function encodeHitPosSilent(pos)
        return Vector3.new(
            ((pos.X - 156325) * 13 + 17854) * 16,
            (pos.Y + 64000) * 7 - 142657,
            (pos.Z * 9 - 47000) * 6
        )
    end

    local function getHitParlRemote()
        local remote = HitpartSilent.remote
        if remote and remote.Parent then return remote end
        local events = ReplicatedStorage:FindFirstChild("Events")
        remote = events and events:FindFirstChild("HitParl") or nil
        HitpartSilent.remote = remote
        return remote
    end

    local function refreshHitpartContext(now)
        if now - HitpartSilent.lastCtxRefresh < 0.2 then return end
        HitpartSilent.lastCtxRefresh = now

        local char = LocalPlayer.Character
        local gun = char and char:FindFirstChild("Gun")
        local eq = char and char:FindFirstChild("EquippedTool")
        if gun and eq then
            local gunName = (type(eq.Value) == "string" and eq.Value ~= "" and eq.Value) or gun.Name
            if gunName ~= HitpartSilent.gunName or HitpartSilent.charGun ~= gun then
                HitpartSilent.gunName = gunName
                HitpartSilent.charGun = gun
                local weapons = getWeaponsFolder()
                HitpartSilent.gunData = weapons and weapons:FindFirstChild(gunName) or nil
                HitpartSilent.fireRateObj = nil
                HitpartSilent.lastFireRateRefresh = 0
            end
        else
            HitpartSilent.gunName = nil
            HitpartSilent.charGun = nil
            HitpartSilent.gunData = nil
            HitpartSilent.fireRateObj = nil
            HitpartSilent.fireRate = 0.1
        end


        local pg = getPlayerGui()
        local blnd = pg and pg:FindFirstChild("Blnd")
        local blind = blnd and blnd:FindFirstChild("Blind")
        HitpartSilent.flashed = blind and blind.BackgroundTransparency < 0.4 or false

        local gunData = HitpartSilent.gunData
        if gunData and gunData:FindFirstChild("snipo") then
            local gui = pg and (pg:FindFirstChild("GUI") or pg:FindFirstChild("Client"))
            local scope = nil
            if gui then
                local ch = gui:FindFirstChild("Crosshairs")
                scope = ch and ch:FindFirstChild("Scope")
            end
            HitpartSilent.noscope = not (scope and scope.Visible)
        else
            HitpartSilent.noscope = false
        end

        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if hum then
            local state = hum:GetState()
            HitpartSilent.airborne = state == Enum.HumanoidStateType.Freefall
                or state == Enum.HumanoidStateType.Jumping
                or hum.FloorMaterial == Enum.Material.Air
        else
            HitpartSilent.airborne = false
        end

        if now - HitpartSilent.smokeFolderTick > 1 then
            HitpartSilent.smokeFolderTick = now
            local rayIgnore = Workspace:FindFirstChild("Ray_Ignore")
            HitpartSilent.smokeFolder = rayIgnore and rayIgnore:FindFirstChild("Smokes") or nil
            if HitpartSilent.smokeFolder then
                if not HitpartSilent.smokeParams then
                    HitpartSilent.smokeParams = RaycastParams.new()
                    HitpartSilent.smokeParams.FilterType = Enum.RaycastFilterType.Include
                    HitpartSilent.smokeParams.IgnoreWater = false
                end
                HitpartSilent.smokeParams.FilterDescendantsInstances = { HitpartSilent.smokeFolder }
            end
        end
    end

    local function isHitpartThroughSmoke(camPos, hitPos)
        local smokes = HitpartSilent.smokeFolder
        local params = HitpartSilent.smokeParams
        if not smokes or not params then return false end
        local hit = Workspace:Raycast(camPos, hitPos - camPos, params)
        return hit and hit.Instance and hit.Instance:GetAttribute("Enabled") and true or false
    end

    HitpartSilent.refreshMethod = function()
        local hitpartOn = Toggles and Toggles.RagebotHitPart and Toggles.RagebotHitPart.Value == true
        HitpartSilent.isHitpart = hitpartOn
        HitpartSilent.isRay = not hitpartOn
    end

    HitpartSilent.isHitpartMethod = function()
        -- always re-sync from toggle so mode can't stick on ray
        local hitpartOn = Toggles and Toggles.RagebotHitPart and Toggles.RagebotHitPart.Value == true
        HitpartSilent.isHitpart = hitpartOn
        HitpartSilent.isRay = not hitpartOn
        return hitpartOn
    end

    HitpartSilent.getFireRate = function()
        local now = tick()
        if now - HitpartSilent.lastFireRateRefresh >= 0.1 then
            HitpartSilent.lastFireRateRefresh = now
            local char = LocalPlayer.Character
            local gun = char and char:FindFirstChild("Gun")
            local eq = char and char:FindFirstChild("EquippedTool")
            if gun and eq then
                local gunName = (type(eq.Value) == "string" and eq.Value ~= "" and eq.Value) or gun.Name
                if gunName ~= HitpartSilent.gunName or HitpartSilent.charGun ~= gun or not HitpartSilent.gunData or not HitpartSilent.gunData.Parent then
                    HitpartSilent.gunName = gunName
                    HitpartSilent.charGun = gun
                    local weapons = getWeaponsFolder()
                    HitpartSilent.gunData = weapons and weapons:FindFirstChild(gunName) or nil
                    HitpartSilent.fireRateObj = nil
                end
            else
                HitpartSilent.gunName = nil
                HitpartSilent.charGun = nil
                HitpartSilent.gunData = nil
                HitpartSilent.fireRateObj = nil
            end
            local fr = HitpartSilent.fireRateObj
            if not fr or not fr.Parent then
                local gunData = HitpartSilent.gunData
                fr = gunData and gunData:FindFirstChild("FireRate") or nil
                HitpartSilent.fireRateObj = fr
            end
            if fr and fr:IsA("NumberValue") and fr.Value > 0 then
                HitpartSilent.fireRate = fr.Value
            else
                HitpartSilent.fireRate = 0.1
            end
        end
        local rate = HitpartSilent.fireRate
        if type(rate) == "number" and rate > 0 then return rate end
        return 0.1
    end


    HitpartSilent.fire = function(target)

        if HitpartSilent.injecting then return end
        if not target or not target.Parent then return end

        local now = tick()
        refreshHitpartContext(now)

        local gunName = HitpartSilent.gunName
        local charGun = HitpartSilent.charGun
        local gunData = HitpartSilent.gunData
        if not gunName then return end
        local fireGun = charGun or gunData
        if not fireGun then return end

        local hitParl = getHitParlRemote()
        if not hitParl then return end

        local cam = getCamera()
        if not cam then return end

        local hitPos = target.CFrame and target.CFrame.Position or target.Position
        local camPos = cam.CFrame.Position
        local dir = hitPos - camPos
        local mag = dir.Magnitude
        if mag < 0.001 then return end
        local normal = dir / mag

        -- Force wallbang when Auto Penetration is on (like working backup2 hitpart pen).
        local wallbang = false
        if Toggles.RagebotAutoPenetration and Toggles.RagebotAutoPenetration.Value then
            wallbang = true
        end

        local smoke = isHitpartThroughSmoke(camPos, hitPos)
        local srvTime = Workspace:GetServerTimeNow()
        local rangeArg = 4096
        local posArg = encodeHitPosSilent(hitPos)

        HitpartSilent.injecting = true
        pcall(function()
            hitParl:FireServer(
                target,
                posArg,
                gunName,
                rangeArg,
                fireGun,
                nil,
                1,
                false,
                wallbang,
                camPos,
                srvTime,
                normal,
                HitpartSilent.flashed,
                HitpartSilent.noscope,
                smoke,
                HitpartSilent.airborne,
                true,
                nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil
            )
        end)
        HitpartSilent.injecting = false
    end
end



-- Find nearest target for silent aim with FOV and wall penetration check

local function getRageHitboxSelection()
    local opt = Options.RagebotHitbox
    local value = opt and opt.Value
    if type(value) == "table" then
        return value
    end
    return CONSTANTS.RagebotDefaultHitboxes
end

local function isRageHitboxSelected(name)
    local selected = getRageHitboxSelection()
    if selected[name] == true then return true end
    for _, v in pairs(selected) do
        if v == name then return true end
    end
    return false
end

local function getRageTargetPart(character, head, rootPart)
    if not character then return nil end

    local aimPos = UserInputService:GetMouseLocation()
    local cam = getCamera()
    local bestPart, bestDist = nil, math.huge
    local anySelected = false

    for _, group in ipairs(CONSTANTS.RageHitboxPriority) do
        if isRageHitboxSelected(group) then
            anySelected = true
            local names = CONSTANTS.AimHitboxFallbacks[group]
            if names then
                for i = 1, #names do
                    local part = findCharacterPart(character, names[i])
                    if part then
                        if not cam then
                            return part
                        end
                        local screenPos, onScreen = cam:WorldToViewportPoint(part.Position)
                        if onScreen then
                            local dist = (Vector2.new(screenPos.X, screenPos.Y) - aimPos).Magnitude
                            if dist < bestDist then
                                bestDist = dist
                                bestPart = part
                            end
                        elseif not bestPart then
                            bestPart = part
                        end
                    end
                end
            end
        end
    end

    if bestPart then return bestPart end
    return head or rootPart
end

local function getNearestSilentTarget()
    local camera = getCamera()
    if not camera then return nil end

    local aimPos = UserInputService:GetMouseLocation()
    local fovValue = Options.RagebotFOV and Options.RagebotFOV.Value or 180
    local fovPixels = fovValue * (camera.ViewportSize.Y / camera.FieldOfView)
    local myTeam = LocalPlayer.Team

    local wallPenEnabled = Toggles.RagebotAutoPenetration and Toggles.RagebotAutoPenetration.Value
    local maxWalls = wallPenEnabled and (Options.SilentAimMaxWalls and Options.SilentAimMaxWalls.Value or CONSTANTS.RagebotDefaultMaxWalls) or 0
    local useTeamCheck = Toggles.RagebotTeamCheck and Toggles.RagebotTeamCheck.Value

    local nearestPart = nil
    local nearestDist = math.huge

    for _, player in ipairs(Players:GetPlayers()) do
        if player == LocalPlayer then continue end

        if useTeamCheck then
            local theirTeam = player.Team
            local theirTeamColor = player.TeamColor
            if myTeam and theirTeam and theirTeam == myTeam then continue end
            if LocalPlayer.TeamColor and theirTeamColor and theirTeamColor == LocalPlayer.TeamColor then continue end
        end

        local character = player.Character
        if not character then continue end

        local _, humanoid, rootPart = getCachedCharacterParts(player)
        local head = getCachedHead(player, character)
        if not humanoid or humanoid.Health <= 0 or not rootPart then continue end

        if character:FindFirstChildOfClass("ForceField") then continue end

        local targetPart = getRageTargetPart(character, head, rootPart)
        if not targetPart then continue end

        local screenPos, onScreen = camera:WorldToViewportPoint(targetPart.Position)
        if not onScreen then continue end

        if wallPenEnabled then
            if not isVisibleWithWalls(targetPart, maxWalls) then continue end
        end

        local dist = (Vector2.new(screenPos.X, screenPos.Y) - aimPos).Magnitude
        if dist < nearestDist and dist <= fovPixels then
            nearestDist = dist
            nearestPart = targetPart
        end
    end

    return nearestPart
end

local AutoScopeState = { lastWant = false }

local function isScopedGun(gun)
    return typeof(gun) == "Instance" and gun:FindFirstChild("Scoped") ~= nil
end

local function setADS(client, on)
    if not client or type(client.updateads) ~= "function" then return end
    pcall(debug.setupvalue, client.updateads, 1, on == true)
    if on == false then
        rawset(client, "doublezoom", false)
    end
    pcall(client.updateads)
end

local function isADS()
    local char = LocalPlayer.Character
    return char and char:FindFirstChild("AIMING") ~= nil
end

local ScopeLookParams = RaycastParams.new()
ScopeLookParams.FilterType = Enum.RaycastFilterType.Exclude
ScopeLookParams.IgnoreWater = true

local function lookingAtEnemyForScope()
    local cam = getCamera()
    if not cam then return false end

    local origin = cam.CFrame.Position
    local dir = cam.CFrame.LookVector * 2000
    local base = buildRayIgnoreList()
    local debris = Workspace:FindFirstChild("Debris")
    if debris then
        local ignore = table.create(#base + 1)
        for i = 1, #base do
            ignore[i] = base[i]
        end
        ignore[#base + 1] = debris
        ScopeLookParams.FilterDescendantsInstances = ignore
    else
        ScopeLookParams.FilterDescendantsInstances = base
    end

    getgenv().IgnoreRaycastHook = true
    local result = Workspace:Raycast(origin, dir, ScopeLookParams)
    getgenv().IgnoreRaycastHook = false
    if not result or not result.Instance then return false end

    local model = result.Instance:FindFirstAncestorOfClass("Model")
    if not model then return false end
    local plr = Players:GetPlayerFromCharacter(model)
    if not plr or not isEnemy(plr) then return false end

    local _, humanoid = getCachedCharacterParts(plr)
    if not humanoid or humanoid.Health <= 0 then return false end
    if hasShield(model) then return false end
    return true
end

local function updateAutoScope()
    local legitOn = Toggles.AimbotAutoScope and Toggles.AimbotAutoScope.Value
    local rageOn = Toggles.RagebotAutoScope and Toggles.RagebotAutoScope.Value
    if not legitOn and not rageOn then
        if AutoScopeState.lastWant then
            setADS(getCachedClient(), false)
            AutoScopeState.lastWant = false
        end
        return
    end

    local client = getCachedClient()
    if not client then return end

    local gun = rawget(client, "gun")
    if not isScopedGun(gun) then
        if AutoScopeState.lastWant then
            setADS(client, false)
            AutoScopeState.lastWant = false
        end
        return
    end

    local want = false
    if legitOn and lookingAtEnemyForScope() then
        want = true
    elseif rageOn then
        local tgt = getgenv().PSilentTarget
        if tgt and tgt.Parent then
            want = true
        elseif not RuntimePack.silentActive then
            want = getNearestSilentTarget() ~= nil
        end
    end

    if want == AutoScopeState.lastWant then
        if want and not isADS() then
            setADS(client, true)
        end
        return
    end

    AutoScopeState.lastWant = want
    setADS(client, want)
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
local DebrisService = game:GetService("Debris")

local function ensureHitChamsFolder()
    if not HitChamsState.Folder or not HitChamsState.Folder.Parent then
        local folder = Instance.new("Folder")
        folder.Name = "ValenokHitChams"
        folder.Parent = workspace
        HitChamsState.Folder = folder
    end
    return HitChamsState.Folder
end

local function clearHitChamsFolder()
    if HitChamsState.Folder then
        pcall(function() HitChamsState.Folder:Destroy() end)
        HitChamsState.Folder = nil
    end
    HitChamsState.ActiveChams = 0
    HitChamsState.Cooldown = false
    local leftover = workspace:FindFirstChild("ValenokHitChams")
    if leftover then pcall(function() leftover:Destroy() end) end
end



local HIT_CHAMS_IGNORE = {
    HumanoidRootPart = true,
    FakeHead = true,
    C4 = true,
    Gun = true
}

local function hitChams(player, customColor, transparency, lifetime)
    if not player or not player.Character or HitChamsState.Cooldown then return end
    
    HitChamsState.Cooldown = true
    
    task.delay(0.05, function()
        HitChamsState.Cooldown = false
    end)
    
    local color = customColor or getOptionColor("MiscHitChamsColor", Color3.fromRGB(200, 30, 80))
    local fadeTime = lifetime or (Options.MiscHitChamsLifetime and Options.MiscHitChamsLifetime.Value or 1.3)
    
    for _, part in ipairs(player.Character:GetChildren()) do
        if (part:IsA("MeshPart") and part.Transparency ~= 1) or part.Name == "Head" then
            if not HIT_CHAMS_IGNORE[part.Name] then
                if HitChamsState.ActiveChams >= CONSTANTS.MAX_HIT_CHAMS_CLONES then continue end
                HitChamsState.ActiveChams = HitChamsState.ActiveChams + 1
                local clone = part:Clone()
                clone:ClearAllChildren()
                clone.Material = Enum.Material.ForceField
                clone.CFrame = part.CFrame
                clone.Size = part.Name == "Head" and Vector3.new(1.18, 1.18, 1.18) or clone.Size
                clone.CanCollide = false
                clone.CanQuery = false
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

                DebrisService:AddItem(clone, fadeTime)
                task.delay(fadeTime, function()
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
            local att = GrenadeRuntime.Attachments[j]
            if att then att.WorldPosition = pt.pos end
            if j > 1 and GrenadeRuntime.Beams[j - 1] then
                GrenadeRuntime.Beams[j - 1].Transparency = NumberSequence.new(pt.transparency)
                GrenadeRuntime.Beams[j - 1].Enabled = true
            end
        end
        for j = numPoints, 39 do
            if GrenadeRuntime.Beams[j] then GrenadeRuntime.Beams[j].Enabled = false end
        end
        if GrenadeRuntime.Sphere then
            GrenadeRuntime.Sphere.CFrame = CFrame.new(GrenadeRuntime.TrajectoryCache.cachedSpherePos)
            GrenadeRuntime.Sphere.Transparency = 0.3
        end
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

    local tStep = 1 / 60
    local maxSteps = 240
    local currentPos = startPos

    if not GrenadeRuntime.RP then
        local rp = RaycastParams.new()
        rp.FilterType = Enum.RaycastFilterType.Exclude
        GrenadeRuntime.RP = rp
        GrenadeRuntime.FilterList = { lp.Character, getCachedRayIgnore(), GrenadeRuntime.Folder }
        local clips = getMapClips()
        if clips then table.insert(GrenadeRuntime.FilterList, clips) end
        local spawns = getMapSpawns()
        if spawns then table.insert(GrenadeRuntime.FilterList, spawns) end
    end
    GrenadeRuntime.FilterList[1] = lp.Character
    GrenadeRuntime.FilterList[3] = GrenadeRuntime.Folder
    if HitChamsState and HitChamsState.Folder then
        if not table.find(GrenadeRuntime.FilterList, HitChamsState.Folder) then
            table.insert(GrenadeRuntime.FilterList, HitChamsState.Folder)
        end
    end
    GrenadeRuntime.RP.FilterDescendantsInstances = GrenadeRuntime.FilterList
    local rp = GrenadeRuntime.RP

    local bounces = 0
    local pointCount = 1
    local firstAtt = GrenadeRuntime.Attachments[1]
    if not firstAtt then return end
    firstAtt.WorldPosition = startPos

    local samplePeriod = 2
    local stepIdx = 0
    for _ = 1, maxSteps do
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
                if pointCount < 40 then
                    pointCount = pointCount + 1
                    local att = GrenadeRuntime.Attachments[pointCount]
                    local beam = GrenadeRuntime.Beams[pointCount - 1]
                    if att then att.WorldPosition = nextPos end
                    if beam then beam.Transparency = NumberSequence.new(0.15 + (pointCount / 40) * 0.85) end
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
            if pointCount >= 40 then break end
            pointCount = pointCount + 1
            local att = GrenadeRuntime.Attachments[pointCount]
            local beam = GrenadeRuntime.Beams[pointCount - 1]
            if not att then
                pointCount = pointCount - 1
                break
            end
            att.WorldPosition = nextPos
            if beam then beam.Transparency = NumberSequence.new(0.15 + (pointCount / 40) * 0.85) end
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
        local att = GrenadeRuntime.Attachments[j]
        if att then
            cachedPoints[#cachedPoints + 1] = {
                pos = att.WorldPosition,
                transparency = 0.15 + (j / 40) * 0.85,
            }
        end
    end
    GrenadeRuntime.TrajectoryCache.cachedPoints = cachedPoints
    GrenadeRuntime.TrajectoryCache.cachedSpherePos = currentPos

    if GrenadeRuntime.Sphere then
        GrenadeRuntime.Sphere.CFrame = CFrame.new(currentPos)
        GrenadeRuntime.Sphere.Transparency = 0.3
    end
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
        or (Toggles.ESPOofArrows and Toggles.ESPOofArrows.Value)
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
        chams = Toggles.ESPEnable and Toggles.ESPEnable.Value and Toggles.ESPChams and Toggles.ESPChams.Value,
        oof = Toggles.ESPOofArrows and Toggles.ESPOofArrows.Value,
    }

    EspFrameCache.options = {
        font = getEspDrawingFont(),
        fontSize = getEspFontSize(),
        oofSize = (Options.ESPOofSize and Options.ESPOofSize.Value) or 12,
        oofDistance = (Options.ESPOofDistance and Options.ESPOofDistance.Value) or 40,
    }

    EspFrameCache.colors = {
        box = getOptionColor("ESPBoxColor", Color3.fromRGB(255, 255, 255)),
        name = getOptionColor("ESPNameColor", Color3.fromRGB(255, 255, 255)),
        weapon = getOptionColor("ESPWeaponColor", Color3.fromRGB(255, 255, 255)),
        healthBar = getOptionColor("ESPHealthBarColor", Color3.fromRGB(0, 255, 0)),
        boxFill = getOptionColor("ESPBoxFillColor", Color3.fromRGB(255, 255, 255)),
        chamsVisible = getOptionColor("ESPChamsVisibleColor", Color3.fromRGB(0, 255, 120)),
        chamsWall = getOptionColor("ESPChamsWallColor", Color3.fromRGB(255, 60, 60)),
        oof = getOptionColor("ESPOofColor", Color3.fromRGB(255, 255, 255)),
    }

    local fillOpt = Options.ESPBoxFillColor
    EspFrameCache.boxFillTransparency = 1
    if fillOpt and fillOpt.Transparency then
        EspFrameCache.boxFillTransparency = math.clamp(1 - fillOpt.Transparency, 0, 1)
    end

    EspFrameCache.chamsVisibleTransparency = getChamsTransparency("ESPChamsVisibleColor", 0.35)
    EspFrameCache.chamsWallTransparency = getChamsTransparency("ESPChamsWallColor", 0.35)
end


-- forward declarations
local updateRCS, updateRapidFire, updateFullAuto, restoreAllRapidFireRates, restoreAllFullAutoValues, updateInfAmmo
local applyNoRecoil, applyNoSpread, applyInstaEquip, applyInstaReload, fireSingleShot
local InfAmmoState = { table = nil, lastScan = 0, lastApply = 0 }
local function findClientAmmoTable()
    if InfAmmoState.table and type(InfAmmoState.table) == "table" and type(rawget(InfAmmoState.table, "ammocount")) == "number" then
        return InfAmmoState.table
    end
    if not getgc then return nil end
    for _, obj in ipairs(getgc(true)) do
        if type(obj) == "table" then
            local a1, a2, a3, a4 = rawget(obj, "ammocount"), rawget(obj, "ammocount2"), rawget(obj, "ammocount3"), rawget(obj, "ammocount4")
            if type(a1) == "number" and type(a2) == "number" and type(a3) == "number" and type(a4) == "number"
                and rawget(obj, "DISABLED") ~= nil and rawget(obj, "reloading") ~= nil then
                InfAmmoState.table = obj
                return obj
            end
        end
    end
    return nil
end
updateInfAmmo = function()
    if not Toggles.ExploitInfAmmo or not Toggles.ExploitInfAmmo.Value then return end
    local now = tick()
    if now - InfAmmoState.lastApply < 0.05 then return end
    InfAmmoState.lastApply = now
    if not InfAmmoState.table or now - InfAmmoState.lastScan > 2 then
        InfAmmoState.lastScan = now
        findClientAmmoTable()
    end
    local t = InfAmmoState.table
    if not t then return end
    local v = 99999
    t.ammocount, t.ammocount2, t.ammocount3, t.ammocount4 = v, v, v, v
    if rawget(t, "primarystored") ~= nil then t.primarystored = v end
    if rawget(t, "secondarystored") ~= nil then t.secondarystored = v end
    if rawget(t, "equipmentstored") ~= nil then t.equipmentstored = v end
    if rawget(t, "equipment2stored") ~= nil then t.equipment2stored = v end
end

local updateBhop, updateLegitBhop, updateThirdPerson, updateThirdPersonNoClip, updateNoclip, updateFly, updateAutoJump, updateAutoCrouch, updateSpeedHack, updateFakeDuck
local updateNoScope, updateNoFlash, applyNoScope, setupNoSmoke
local ensureCrosshair, updateCrosshair, unloadValenok
local updateViewModelVisuals
local applySkyboxChanger




-- combat

local AimRuntime = {}

local TriggerbotState = {
    DelayUntil = 0,
    DelayActive = false,
    IsFiring = false,
    LastFire = 0,
    LastUpdate = 0,
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


local function getAimHitboxPart(character, humanoid, cam, screenCenter, selectedHitbox)
    selectedHitbox = selectedHitbox or (Options.AimbotHitbox and Options.AimbotHitbox.Value or "Head")

    if selectedHitbox == "Nearest" then
        local allParts = {}
        for _, part in ipairs(character:GetChildren()) do
            if part:IsA("BasePart") and CONSTANTS.RealHitboxLookup[part.Name] then
                table.insert(allParts, part)
            end
        end

        local bestPart = nil
        local bestDistance = math.huge
        cam = cam or getCamera()
        screenCenter = screenCenter or Vector2.new(cam.ViewportSize.X * 0.5, cam.ViewportSize.Y * 0.5)

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
    local baimActive = isBaimKeyActive()
    local selectedHitbox = Options.AimbotHitbox and Options.AimbotHitbox.Value or "Head"
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

        if baimActive then
            local bodyFallbacks = { "UpperTorso", "LowerTorso", "LeftUpperArm", "LeftLowerArm", "LeftHand", "RightUpperArm", "RightLowerArm", "RightHand" }
            for _, bName in ipairs(bodyFallbacks) do
                local bPart = findCharacterPart(character, bName)
                if bPart then
                    targetPart = bPart
                    break
                end
            end
        else
            targetPart = getAimHitboxPart(character, humanoid, cam, screenCenter, selectedHitbox)
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
    if not cam or not aimShouldRun then return end

    local viewport = cam.ViewportSize
    local screenCenter = Vector2.new(viewport.X * 0.5, viewport.Y * 0.5)
    local fovRadius = getAimFovRadius()

    local targetPart = getClosestAimTarget(screenCenter, fovRadius)

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

    local mousePos = UserInputService:GetMouseLocation()
    local ray = cam:ViewportPointToRay(mousePos.X, mousePos.Y)
    local ignore = copyRayIgnoreList()
    VisibilityParams.FilterDescendantsInstances = ignore
    local origin = ray.Origin
    local remain = ray.Direction.Unit * 5000
    local rayResult = nil

    getgenv().IgnoreRaycastHook = true
    for _ = 1, 12 do
        local ok, result = pcall(function()
            return Workspace:Raycast(origin, remain, VisibilityParams)
        end)
        if not ok or not result or not result.Instance then
            rayResult = nil
            break
        end
        rayResult = result
        local inst = result.Instance
        if shouldPierceRayHit(inst) then
            table.insert(ignore, inst)
            VisibilityParams.FilterDescendantsInstances = ignore
            origin = result.Position + remain.Unit * 0.05
        else
            break
        end
    end
    getgenv().IgnoreRaycastHook = false

    local hitInstance = rayResult and rayResult.Instance

    if hitInstance and hitInstance.Parent then
        local hitChar = hitInstance:FindFirstAncestorOfClass("Model")
        if hitChar then
            local hitPlayer = Players:GetPlayerFromCharacter(hitChar)

            if hitPlayer and isTriggerEnemy(hitPlayer) then
                local _, humanoid = getCachedCharacterParts(hitPlayer)
                if humanoid and humanoid.Health > 0 then
                    if isStrictRayVisible(hitInstance) then
                        if Toggles.TriggerbotSmokeCheck and Toggles.TriggerbotSmokeCheck.Value then
                            local rayIgnore = Workspace:FindFirstChild("Ray_Ignore")
                            local smokesFolder = rayIgnore and rayIgnore:FindFirstChild("Smokes")
                            if smokesFolder then
                                local smokeOrigin = cam.CFrame.Position
                                local direction = hitInstance.Position - smokeOrigin
                                local smokeParams = RaycastParams.new()
                                smokeParams.FilterType = Enum.RaycastFilterType.Include
                                smokeParams.FilterDescendantsInstances = { smokesFolder }
                                getgenv().IgnoreRaycastHook = true
                                local smokeRay = Workspace:Raycast(smokeOrigin, direction, smokeParams)
                                getgenv().IgnoreRaycastHook = false
                                if smokeRay and smokeRay.Instance then
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



local function applyTriggerbotMagnet(cam)
    if not Toggles.TriggerbotMagnet or not Toggles.TriggerbotMagnet.Value then return end

    local magnetFov = 25
    local smoothFactor = 0.15
    local mousePos = UserInputService:GetMouseLocation()
    local magnetTarget = nil
    local bestDistance = math.huge

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
        local targetPosition = magnetTarget.Position
        local targetCF = CFrame.new(cam.CFrame.Position, targetPosition)
        cam.CFrame = cam.CFrame:Lerp(targetCF, smoothFactor)
    end
end


local _weapRemote

local function getWeapRemote()
    if _weapRemote and _weapRemote.Parent then return _weapRemote end
    local events = ReplicatedStorage:FindFirstChild("Events")
    _weapRemote = events and events:FindFirstChild("weap") or nil
    return _weapRemote
end

local function fireWeapShot()
    local weap = getWeapRemote()
    if not weap then return false end
    local ok = pcall(function() weap:Fire() end)
    return ok
end


fireSingleShot = function()
    local character = LocalPlayer.Character
    local _, humanoid = getCachedCharacterParts(LocalPlayer)
    if not character or not humanoid or humanoid.Health <= 0 then return end
    if TriggerbotState.IsFiring then return end

    local now = tick()
    local rate = (HitpartSilent.getFireRate and HitpartSilent.getFireRate()) or 0.1
    if now - TriggerbotState.LastFire < rate then return end

    TriggerbotState.IsFiring = true
    local fired = fireWeapShot()
    TriggerbotState.IsFiring = false
    if fired then
        TriggerbotState.LastFire = now
    end
end


local function updateTriggerbot()
    local now = tick()
    if now - TriggerbotState.LastUpdate < 0.005 then return end
    TriggerbotState.LastUpdate = now

    if Library and Library.IsMenuVisible and Library:IsMenuVisible() then return end
    if TriggerbotState.IsFiring then return end
    local cam = getCamera()
    if not cam then return end

    local character, humanoid, rootPart = getCachedCharacterParts(LocalPlayer)
    if not checkTriggerbotConditions(character, humanoid) then return end

    local targetPart = findTriggerbotTarget(cam)

    if targetPart and targetPart.Parent then
        local hitChar = targetPart:FindFirstAncestorOfClass("Model")
        local hitHum = hitChar and hitChar:FindFirstChildOfClass("Humanoid")
        if not hitHum or hitHum.Health <= 0 then
            targetPart = nil
        end
    end

    applyTriggerbotMagnet(cam)

    if targetPart then
        local delayMs = (Options.TriggerbotDelay and Options.TriggerbotDelay.Value) or 0
        if not TriggerbotState.DelayActive then
            TriggerbotState.DelayActive = true
            TriggerbotState.DelayUntil = now + (delayMs / 1000)
        end
        if now >= TriggerbotState.DelayUntil then
            fireSingleShot()
        end
    else
        TriggerbotState.DelayActive = false
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
    YawSpinLastUpdate = 0,
    AtTargetLastScan = 0,
    AtTargetPart = nil,
}


local function updateAntiAim()
    local pitchEnabled = Toggles.AntiAimPitchEnable and Toggles.AntiAimPitchEnable.Value
    local yawEnabled = Toggles.AntiAimYawEnable and Toggles.AntiAimYawEnable.Value
    local character = LocalPlayer.Character
    if not character then return end
    local _, humanoid, rootPart = getCachedCharacterParts(LocalPlayer)
    if not humanoid or not rootPart or humanoid.Health <= 0 then return end

    if not pitchEnabled and not yawEnabled then
        humanoid.AutoRotate = true
        humanoid.HipHeight = 2
        return
    end

    humanoid.HipHeight = 2
    humanoid.AutoRotate = not yawEnabled

    if pitchEnabled then
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
    end

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
            local nowAt = tick()
            if nowAt - AntiAimState.AtTargetLastScan >= (1 / 60) then
                AntiAimState.AtTargetLastScan = nowAt
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
                AntiAimState.AtTargetPart = bestPart
            end
            local bestPart = AntiAimState.AtTargetPart
            if bestPart and bestPart.Parent then
                local dir = (bestPart.Position - rootPart.Position) * Vector3.new(1, 0, 1)
                if dir.Magnitude > 0.1 then
                    baseYaw = math.deg(math.atan2(dir.X, dir.Z))
                end
            else
                AntiAimState.AtTargetPart = nil
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
    if not weapons then
        if not enabled then table.clear(SavedRecoilValues) end
        return
    end
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
            end
            SavedRecoilValues[weaponFolder.Name] = nil
        end
    end
    if not enabled then table.clear(SavedRecoilValues) end
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
            OriginalAccuracySd = nil
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
    local multiplier = CONSTANTS.RAPID_FIRE_MULTIPLIERS[weaponName] or CONSTANTS.RAPID_FIRE_DEFAULT_MULTIPLIER or 2
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
    rootPart.CFrame = CFrame.new(newPos, newPos + direction)
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

local Shared = {}

;(function()
Shared.SpeedHackState = { Conn = nil, OrigSpeed = nil, Humanoid = nil }

Shared.restoreSpeedHackOriginal = function()
    local humanoid = Shared.SpeedHackState.Humanoid
    if (not humanoid or not humanoid.Parent) then
        humanoid = MoveUtil.getLocalHumanoid()
    end

    if humanoid and Shared.SpeedHackState.OrigSpeed ~= nil then
        humanoid.WalkSpeed = Shared.SpeedHackState.OrigSpeed
    end

    Shared.SpeedHackState.OrigSpeed = nil
    Shared.SpeedHackState.Humanoid = nil
end

updateSpeedHack = function()
    if Shared.SpeedHackState.Conn then
        Shared.SpeedHackState.Conn:Disconnect()
        Shared.SpeedHackState.Conn = nil
    end
    if not (Toggles.SpeedHackEnable and Toggles.SpeedHackEnable.Value) then
        pcall(Shared.restoreSpeedHackOriginal)
        return
    end

    Shared.SpeedHackState.Conn = RunService.RenderStepped:Connect(function(dt)
        if not isKeybindActive(Options.SpeedHackKeybind) then
            Shared.restoreSpeedHackOriginal()
            return
        end

        local _, hum, hrp = MoveUtil.getAliveMovementRig()
        if not hum or not hrp then return end

        if Shared.SpeedHackState.Humanoid ~= hum then
            if Shared.SpeedHackState.Humanoid and Shared.SpeedHackState.Humanoid.Parent and Shared.SpeedHackState.OrigSpeed ~= nil then
                Shared.SpeedHackState.Humanoid.WalkSpeed = Shared.SpeedHackState.OrigSpeed
            end
            Shared.SpeedHackState.Humanoid = hum
            Shared.SpeedHackState.OrigSpeed = hum.WalkSpeed
        elseif Shared.SpeedHackState.OrigSpeed == nil then
            Shared.SpeedHackState.OrigSpeed = hum.WalkSpeed
        end

        local speed = Options.SpeedHackSpeed and Options.SpeedHackSpeed.Value or 50
        hum.WalkSpeed = speed

        local cam = getCamera()
        if not cam then return end
        MoveUtil.applyCameraCFrameMove(hrp, cam, speed, dt)
    end)
end

Shared.AutoCrouchState = { Conn = nil, WasInAir = false }
Shared.FakeDuckState = { Conn = nil, Track = nil, Humanoid = nil }

local function stopFakeDuck()
    local track = Shared.FakeDuckState.Track
    if track then
        pcall(function() track:Stop() end)
        Shared.FakeDuckState.Track = nil
    end
    Shared.FakeDuckState.Humanoid = nil
end

updateFakeDuck = function()
    if Shared.FakeDuckState.Conn then
        Shared.FakeDuckState.Conn:Disconnect()
        Shared.FakeDuckState.Conn = nil
    end
    stopFakeDuck()
    if not (Toggles.FakeDuckEnable and Toggles.FakeDuckEnable.Value) then return end

    Shared.FakeDuckState.Conn = RunService.RenderStepped:Connect(function()
        if not (Toggles.FakeDuckEnable and Toggles.FakeDuckEnable.Value) then
            stopFakeDuck()
            return
        end

        local active = isKeybindActive(Options.FakeDuckKeybind)
        local _, hum = MoveUtil.getAliveMovementRig()
        if not active or not hum then
            stopFakeDuck()
            return
        end

        if Shared.FakeDuckState.Track and Shared.FakeDuckState.Humanoid == hum then
            if Shared.FakeDuckState.Track.IsPlaying == false then
                pcall(function() Shared.FakeDuckState.Track:Play() end)
            end
            return
        end

        stopFakeDuck()

        local pg = getPlayerGui()
        local client = pg and pg:FindFirstChild("Client")
        local idle = client and client:FindFirstChild("Idle")
        if not idle or not idle:IsA("Animation") then return end

        local ok, track = pcall(function()
            return hum:LoadAnimation(idle)
        end)
        if ok and track then
            Shared.FakeDuckState.Track = track
            Shared.FakeDuckState.Humanoid = hum
            pcall(function() track:Play() end)
        end
    end)
end

updateAutoCrouch = function()
    if Shared.AutoCrouchState.Conn then
        Shared.AutoCrouchState.Conn:Disconnect()
        Shared.AutoCrouchState.Conn = nil
    end
    Shared.AutoCrouchState.WasInAir = false
    if not (Toggles.AutoCrouchEnable and Toggles.AutoCrouchEnable.Value) then
        VirtualInputManager:SendKeyEvent(false, MoveUtil.MOVE_KEY_CTRL, false, game)
        return
    end

    Shared.AutoCrouchState.Conn = RunService.RenderStepped:Connect(function()
        local _, hum = MoveUtil.getAliveMovementRig()
        if not hum then return end
        local inAir = hum.FloorMaterial == MoveUtil.AIR_MATERIAL
        if inAir and not Shared.AutoCrouchState.WasInAir then
            VirtualInputManager:SendKeyEvent(true, MoveUtil.MOVE_KEY_CTRL, false, game)
            Shared.AutoCrouchState.WasInAir = true
        elseif not inAir and Shared.AutoCrouchState.WasInAir then
            VirtualInputManager:SendKeyEvent(false, MoveUtil.MOVE_KEY_CTRL, false, game)
            Shared.AutoCrouchState.WasInAir = false
        end
    end)
end

Shared.BhopState = { Conn = nil, LastWalkSpeed = nil }
Shared.LegitBhopState = { Conn = nil, JumpCount = 0, WasInAir = false, DefaultSpeed = 16, LastWalkSpeed = nil }
Shared.AutoJumpState = { Conn = nil }
Shared.NoclipState = { Conn = nil, DescendantConn = nil, Saved = {}, Parts = {}, Character = nil }
Shared.FlyState = { Conn = nil }

local function setWalkSpeedIfChanged(state, hum, speed)
    if state.LastWalkSpeed == speed and hum.WalkSpeed == speed then return end
    hum.WalkSpeed = speed
    state.LastWalkSpeed = speed
end

updateBhop = function()
    if Shared.BhopState.Conn then
        Shared.BhopState.Conn:Disconnect()
        Shared.BhopState.Conn = nil
    end
    Shared.BhopState.LastWalkSpeed = nil
    local humanoid = MoveUtil.getLocalHumanoid()
    if humanoid then
        humanoid.WalkSpeed = CONSTANTS.DEFAULT_WALK_SPEED
    end
    if not (Toggles.BhopEnable and Toggles.BhopEnable.Value) then return end

    -- Heartbeat: physics rate, not render FPS. Jump only when grounded.
    Shared.BhopState.Conn = RunService.Heartbeat:Connect(function(dt)
        local spaceHeld = UserInputService:IsKeyDown(MoveUtil.MOVE_KEY_SPACE)
        local _, hum, rootPart = MoveUtil.getAliveMovementRig()
        if not hum or not rootPart then return end

        if not spaceHeld then
            setWalkSpeedIfChanged(Shared.BhopState, hum, CONSTANTS.DEFAULT_WALK_SPEED)
            return
        end

        local grounded = hum.FloorMaterial ~= MoveUtil.AIR_MATERIAL
        if grounded then
            hum.Jump = true
        end

        local multiplier = Options.BhopMultiplier and Options.BhopMultiplier.Value or 1
        if not multiplier or multiplier <= 0 then multiplier = 1 end
        local targetSpeed = CONSTANTS.DEFAULT_WALK_SPEED * multiplier
        setWalkSpeedIfChanged(Shared.BhopState, hum, targetSpeed)

        if multiplier > 1 then
            local cam = getCamera()
            if cam then
                MoveUtil.applyCameraCFrameMove(rootPart, cam, targetSpeed - CONSTANTS.DEFAULT_WALK_SPEED, dt)
            end
        end
    end)
end


updateLegitBhop = function()
    if Shared.LegitBhopState.Conn then
        Shared.LegitBhopState.Conn:Disconnect()
        Shared.LegitBhopState.Conn = nil
    end
    Shared.LegitBhopState.JumpCount = 0
    Shared.LegitBhopState.WasInAir = false
    Shared.LegitBhopState.LastWalkSpeed = nil
    local humanoid = MoveUtil.getLocalHumanoid()
    if humanoid then
        humanoid.WalkSpeed = CONSTANTS.DEFAULT_WALK_SPEED
    end
    if not (Toggles.LegitBhopEnable and Toggles.LegitBhopEnable.Value) then return end

    -- Heartbeat + jump only on ground/landing (never spam Jump while airborne).
    Shared.LegitBhopState.Conn = RunService.Heartbeat:Connect(function()
        local spaceHeld = UserInputService:IsKeyDown(MoveUtil.MOVE_KEY_SPACE)
        local _, hum, rootPart = MoveUtil.getAliveMovementRig()
        if not hum or not rootPart then return end

        local inAir = hum.FloorMaterial == MoveUtil.AIR_MATERIAL

        if not spaceHeld then
            if Shared.LegitBhopState.JumpCount ~= 0 then
                Shared.LegitBhopState.JumpCount = 0
            end
            Shared.LegitBhopState.WasInAir = inAir
            setWalkSpeedIfChanged(Shared.LegitBhopState, hum, CONSTANTS.DEFAULT_WALK_SPEED)
            return
        end

        if inAir then
            Shared.LegitBhopState.WasInAir = true
        elseif Shared.LegitBhopState.WasInAir then
            hum.Jump = true
            Shared.LegitBhopState.JumpCount = math.min(Shared.LegitBhopState.JumpCount + 1, 15)
            Shared.LegitBhopState.WasInAir = false
        else
            -- grounded, holding space: one jump request per physics tick only while on floor
            hum.Jump = true
        end

        local maxMult = Options.LegitBhopMultiplier and Options.LegitBhopMultiplier.Value or 2
        if not maxMult or maxMult < 1 then maxMult = 1 end
        local multiplier = 1 + (Shared.LegitBhopState.JumpCount / 15) * (maxMult - 1)
        setWalkSpeedIfChanged(Shared.LegitBhopState, hum, CONSTANTS.DEFAULT_WALK_SPEED * multiplier)
    end)
end


Shared.clearNoclipRuntime = function()
    if Shared.NoclipState.DescendantConn then
        Shared.NoclipState.DescendantConn:Disconnect()
        Shared.NoclipState.DescendantConn = nil
    end
    Shared.NoclipState.Character = nil
    Shared.NoclipState.Parts = {}
end

Shared.restoreNoclipParts = function()
    for part, canCollide in pairs(Shared.NoclipState.Saved) do
        if part and part.Parent then part.CanCollide = canCollide end
    end
    Shared.NoclipState.Saved = {}
    Shared.clearNoclipRuntime()
end

local function trackNoclipPart(part)
    if not part:IsA("BasePart") then return end
    if Shared.NoclipState.Saved[part] == nil then
        Shared.NoclipState.Saved[part] = part.CanCollide
        Shared.NoclipState.Parts[#Shared.NoclipState.Parts + 1] = part
    end
    if part.CanCollide then
        part.CanCollide = false
    end
end

local function setNoclipCharacter(character)
    if Shared.NoclipState.Character == character then return end
    Shared.clearNoclipRuntime()
    Shared.NoclipState.Character = character

    for _, part in ipairs(character:GetDescendants()) do
        trackNoclipPart(part)
    end

    Shared.NoclipState.DescendantConn = character.DescendantAdded:Connect(trackNoclipPart)
end

updateNoclip = function()
    if Shared.NoclipState.Conn then
        Shared.NoclipState.Conn:Disconnect()
        Shared.NoclipState.Conn = nil
    end

    Shared.restoreNoclipParts()

    if not (Toggles.NoclipEnable and Toggles.NoclipEnable.Value) then return end

    Shared.NoclipState.Conn = RunService.Stepped:Connect(function()
        local character = LocalPlayer.Character
        if not character then return end

        setNoclipCharacter(character)
        local parts = Shared.NoclipState.Parts
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


Shared.restoreFlyPhysics = function()
    local hum = MoveUtil.getLocalHumanoid()
    if hum then hum.PlatformStand = false end
end

updateFly = function()
    if Shared.FlyState.Conn then
        Shared.FlyState.Conn:Disconnect()
        Shared.FlyState.Conn = nil
    end

    pcall(Shared.restoreFlyPhysics)

    if not (Toggles.FlyEnable and Toggles.FlyEnable.Value) then return end

    Shared.FlyState.Conn = RunService.RenderStepped:Connect(function(dt)
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


Shared.ThirdPersonCache = { arms = nil, parts = nil, lastHideState = nil }

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
        local yawOn = Toggles.AntiAimYawEnable and Toggles.AntiAimYawEnable.Value
        if yawOn then
            humanoid.AutoRotate = false
        else
            humanoid.AutoRotate = not isThirdPersonActive
        end
    end

    -- hide / show viewmodel (Arms)
    local cam = getCamera()
    if cam then
        local arms = cam:FindFirstChild("Arms")
        if arms then
            local hideVM = Toggles.ThirdPersonHideVM and Toggles.ThirdPersonHideVM.Value
            local hideState = isThirdPersonActive and hideVM
            if arms ~= Shared.ThirdPersonCache.arms then
                Shared.ThirdPersonCache.arms = arms
                Shared.ThirdPersonCache.parts = nil
                for _, part in ipairs(arms:GetDescendants()) do
                    if part:IsA("BasePart") or part:IsA("MeshPart") then
                        if not Shared.ThirdPersonCache.parts then Shared.ThirdPersonCache.parts = {} end
                        Shared.ThirdPersonCache.parts[#Shared.ThirdPersonCache.parts + 1] = part
                    end
                end
                Shared.ThirdPersonCache.lastHideState = nil
            end
            if Shared.ThirdPersonCache.parts and hideState ~= Shared.ThirdPersonCache.lastHideState then
                Shared.ThirdPersonCache.lastHideState = hideState
                local ltm = hideState and 1 or 0
                for i = 1, #Shared.ThirdPersonCache.parts do
                    Shared.ThirdPersonCache.parts[i].LocalTransparencyModifier = ltm
                end
            end
        end
    end

    -- camera through walls: manually position camera behind player, bypassing wall clipping
    -- (handled by Shared.ThirdPersonNoClipConn below)
end

Shared.ThirdPersonNoClipConn = nil
Shared.updateThirdPersonNoClip = function()
    if Shared.ThirdPersonNoClipConn then
        Shared.ThirdPersonNoClipConn:Disconnect()
        Shared.ThirdPersonNoClipConn = nil
    end
    if not (Toggles.ThirdPersonEnable and Toggles.ThirdPersonEnable.Value
        and Toggles.ThirdPersonNoClip and Toggles.ThirdPersonNoClip.Value) then return end

    Shared.ThirdPersonNoClipConn = RunService:BindToRenderStep("ValenokTPNoClip", Enum.RenderPriority.Camera.Value + 1, function()
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
    if Shared.AutoJumpState.Conn then
        Shared.AutoJumpState.Conn:Disconnect()
        Shared.AutoJumpState.Conn = nil
    end
    if not (Toggles.AutoJumpEnable and Toggles.AutoJumpEnable.Value) then return end

    -- Heartbeat + only jump when grounded: setting Jump every RenderStepped while airborne
    -- at high FPS spams humanoid state and tanks performance.
    Shared.AutoJumpState.Conn = RunService.Heartbeat:Connect(function()
        if not UserInputService:IsKeyDown(MoveUtil.MOVE_KEY_SPACE) then return end

        local _, humanoid = MoveUtil.getAliveMovementRig()
        if not humanoid then return end
        if humanoid.FloorMaterial == MoveUtil.AIR_MATERIAL then return end

        humanoid.Jump = true
    end)
end




-- visuals

Shared.AmbienceSavedLighting = nil
Shared.MiscState = { ambienceDirty = false }

-- Misc tab functions (ported from clarity.tk.lua General section)

Shared.applyRemoveRadio = function()
    if not Toggles.MiscRemoveRadio then return end
    local pg = getPlayerGui()
    if pg and pg:FindFirstChild("GUI") then
        local suitZoom = pg.GUI:FindFirstChild("SuitZoom")
        if suitZoom then suitZoom.Visible = not Toggles.MiscRemoveRadio.Value end
    end
end

Shared.FovChangerBound = false
Shared.applyFovChanger = function()
    local cam = getCamera()
    if not cam then return end
    if Toggles.VisualFovChanger and Toggles.VisualFovChanger.Value then
        if not Shared.FovChangerBound then
            pcall(function() RunService:UnbindFromRenderStep("ValenokFovChanger") end)
            RunService:BindToRenderStep("ValenokFovChanger", Enum.RenderPriority.Camera.Value + 1, function()
                local c = getCamera()
                if not c then return end
                if not (Toggles.VisualFovChanger and Toggles.VisualFovChanger.Value) then return end
                local pg = getPlayerGui()
                local scope = pg and pg:FindFirstChild("GUI") and pg.GUI:FindFirstChild("Crosshairs") and pg.GUI.Crosshairs:FindFirstChild("Scope")
                if not (scope and scope.Visible) then
                    local fovVal = Options.VisualFovValue and Options.VisualFovValue.Value or 80
                    if c.FieldOfView ~= fovVal then
                        c.FieldOfView = fovVal
                    end
                end
            end)
            Shared.FovChangerBound = true
        end
    else
        if Shared.FovChangerBound then
            pcall(function() RunService:UnbindFromRenderStep("ValenokFovChanger") end)
            Shared.FovChangerBound = false
        end
        cam.FieldOfView = 80
    end
end
Shared.unbindFovChanger = function()
    if Shared.FovChangerBound then
        pcall(function() RunService:UnbindFromRenderStep("ValenokFovChanger") end)
        Shared.FovChangerBound = false
    end
end


Shared.applyRemoveUIElements = function()
    local TARGET_GUIS = {
        "Game", "GUI", "HUDShading", "CBScoreboard",
        "SmokeGUI", "Performance", "Objective", "Crates",
        "NewItem", "BanBoi", "Blnd", "Winner", "RoundWin",
        "WinGui", "RoundEnd", "Win",
    }
    local function clearOriginalState()
        local conns = getgenv().HUD_Connections
        if conns then
            for _, data in pairs(conns) do
                if data.Connection then data.Connection:Disconnect() end
                if data.PropConns then
                    for _, pConn in pairs(data.PropConns) do pConn:Disconnect() end
                end
            end
        end
        getgenv().HUD_Connections = nil
        getgenv().HUD_OriginalState = nil
    end
    local function hideObject(instance)
        if not instance or (not instance:IsA("GuiObject") and not instance:IsA("UIStroke")) then return end
        if instance:IsA("ScreenGui") then return end
        local whitelist = {"BuyMenu", "Crosshair", "Crosshairs", "SuitZoom", "Scope", "Cursor", "Reticle"}
        for _, name in pairs(whitelist) do
            if instance.Name == name or instance:FindFirstAncestor(name) then return end
        end
        local cache = getgenv().HUD_OriginalState or {}
        getgenv().HUD_OriginalState = cache
        if not cache[instance] then
            local state = {
                Visible = instance:IsA("GuiObject") and instance.Visible or nil,
                BackgroundTransparency = instance:IsA("GuiObject") and instance.BackgroundTransparency or nil,
                BorderSizePixel = instance:IsA("GuiObject") and instance.BorderSizePixel or nil,
            }
            if instance:IsA("ImageLabel") or instance:IsA("ImageButton") then
                state.ImageTransparency = instance.ImageTransparency
            elseif instance:IsA("TextLabel") or instance:IsA("TextButton") or instance:IsA("TextBox") then
                state.TextTransparency = instance.TextTransparency
            elseif instance:IsA("UIStroke") then
                state.Transparency = instance.Transparency
                state.Enabled = instance.Enabled
            end
            cache[instance] = state
        end
        local propConns = {}
        local function applyHidden()
            if instance:IsA("GuiObject") then
                instance.Visible = false
                instance.BackgroundTransparency = 1
                instance.BorderSizePixel = 0
                if instance:IsA("ImageLabel") or instance:IsA("ImageButton") then
                    instance.ImageTransparency = 1
                elseif instance:IsA("TextLabel") or instance:IsA("TextButton") or instance:IsA("TextBox") then
                    instance.TextTransparency = 1
                end
            elseif instance:IsA("UIStroke") then
                instance.Enabled = false
                instance.Transparency = 1
            end
        end
        applyHidden()
        if instance:IsA("GuiObject") then
            table.insert(propConns, instance:GetPropertyChangedSignal("Visible"):Connect(applyHidden))
            table.insert(propConns, instance:GetPropertyChangedSignal("BackgroundTransparency"):Connect(applyHidden))
            if instance:IsA("ImageLabel") or instance:IsA("ImageButton") then
                table.insert(propConns, instance:GetPropertyChangedSignal("ImageTransparency"):Connect(applyHidden))
            elseif instance:IsA("TextLabel") or instance:IsA("TextButton") or instance:IsA("TextBox") then
                table.insert(propConns, instance:GetPropertyChangedSignal("TextTransparency"):Connect(applyHidden))
            end
        elseif instance:IsA("UIStroke") then
            table.insert(propConns, instance:GetPropertyChangedSignal("Enabled"):Connect(applyHidden))
            table.insert(propConns, instance:GetPropertyChangedSignal("Transparency"):Connect(applyHidden))
        end
        local conns = getgenv().HUD_Connections or {}
        getgenv().HUD_Connections = conns
        conns[instance] = {PropConns = propConns}
    end
    local function recursiveHide(parent)
        hideObject(parent)
        for _, child in pairs(parent:GetChildren()) do
            if child.Name == "BuyMenu" then continue end
            recursiveHide(child)
        end
    end
    local enabled = Toggles.MiscRemoveUI and Toggles.MiscRemoveUI.Value
    if enabled then
        clearOriginalState()
        getgenv().HUD_OriginalState = {}
        getgenv().HUD_Connections = {}
        local function processGui(gui)
            recursiveHide(gui)
            local conn = gui.DescendantAdded:Connect(function(child)
                hideObject(child)
            end)
            getgenv().HUD_Connections[gui] = getgenv().HUD_Connections[gui] or {}
            getgenv().HUD_Connections[gui].Connection = conn
        end
        local pg = getPlayerGui()
        if pg then
            for _, name in pairs(TARGET_GUIS) do
                local g = pg:FindFirstChild(name)
                if g and g:IsA("ScreenGui") then
                    processGui(g)
                end
            end
            local mainConn = pg.ChildAdded:Connect(function(child)
                for _, name in pairs(TARGET_GUIS) do
                    if child.Name == name and child:IsA("ScreenGui") then
                        processGui(child)
                    end
                end
            end)
            getgenv().HUD_Connections["Main"] = {Connection = mainConn}
        end
    else
        local cache = getgenv().HUD_OriginalState
        if cache then
            for inst, state in pairs(cache) do
                if inst and inst.Parent then
                    if inst:IsA("GuiObject") then
                        inst.Visible = state.Visible
                        inst.BackgroundTransparency = state.BackgroundTransparency
                        inst.BorderSizePixel = state.BorderSizePixel
                        if state.ImageTransparency then inst.ImageTransparency = state.ImageTransparency end
                        if state.TextTransparency then inst.TextTransparency = state.TextTransparency end
                    elseif inst:IsA("UIStroke") then
                        inst.Enabled = state.Enabled
                        inst.Transparency = state.Transparency
                    end
                end
            end
        end
        clearOriginalState()
    end
end



Shared.hideDrawingSet = function(drawingSet, resetRect)
    if not drawingSet then return end

    drawingSet.Box.Visible = false
    drawingSet.BoxOutline.Visible = false
    drawingSet.BoxFill.Visible = false
    drawingSet.Name.Visible = false
    drawingSet.Weapon.Visible = false
    drawingSet.HealthBarOutline.Visible = false
    drawingSet.HealthBarFill.Visible = false
    drawingSet.HealthText.Visible = false
    if drawingSet.OofArrow then drawingSet.OofArrow.Visible = false end
    if drawingSet.OofArrowOutline then drawingSet.OofArrowOutline.Visible = false end

    if resetRect then
        drawingSet.Rect = nil
    end
end


Shared.removeDrawingSet = function(player)
    local drawingSet = EspRuntime.Drawings[player]
    if not drawingSet then return end

    EspRuntime.RemoveDrawingValue(drawingSet)
    EspRuntime.Drawings[player] = nil
end


Shared.removeHighlight = function(player)
    local highlight = EspRuntime.Highlights[player]
    if not highlight then return end

    highlight:Destroy()
    EspRuntime.Highlights[player] = nil
end


Shared.getDrawingSet = function(player)
    local drawingSet = EspRuntime.Drawings[player]
    if drawingSet then return drawingSet end

    drawingSet = {
        Box = createSquare(CONSTANTS.ESP_BOX_THICKNESS, Color3.fromRGB(255, 255, 255)),
        BoxOutline = createSquare(CONSTANTS.ESP_BOX_OUTLINE_THICKNESS, Color3.fromRGB(0, 0, 0)),
        BoxFill = createSquare(1, Color3.fromRGB(255, 255, 255)),
        Name = createText(13),
        Weapon = createText(13),
        Rect = nil,
        HealthBarOutline = createSquare(1, Color3.fromRGB(0, 0, 0)),
        HealthBarFill = createSquare(3, Color3.fromRGB(0, 255, 0)),
        HealthText = createText(13),
        OofArrow = createTriangle(true, 1, Color3.fromRGB(255, 255, 255)),
        OofArrowOutline = createTriangle(false, 2, Color3.fromRGB(0, 0, 0)),
    }
    drawingSet.BoxFill.Filled = true
    drawingSet.BoxOutline.ZIndex = 1
    drawingSet.Box.ZIndex = 2

    EspRuntime.Drawings[player] = drawingSet
    return drawingSet
end


local function clearPartChams(state)
    if not state or not state.Parts then return end
    for part, pair in pairs(state.Parts) do
        if pair.inner then pcall(function() pair.inner:Destroy() end) end
        if pair.outer then pcall(function() pair.outer:Destroy() end) end
        state.Parts[part] = nil
    end
end

local function clearHighlightChams(player, state)
    if state and state.Highlight then
        pcall(function() state.Highlight:Destroy() end)
        state.Highlight = nil
    end
    local hl = EspRuntime.Highlights[player]
    if hl then
        pcall(function() hl:Destroy() end)
        EspRuntime.Highlights[player] = nil
    end
end

Shared.removePlayerChams = function(player)
    local state = EspRuntime.Chams[player]
    if state then
        clearPartChams(state)
        clearHighlightChams(player, state)
        EspRuntime.Chams[player] = nil
    else
        clearHighlightChams(player, nil)
    end
end

local function createChamsPair(part)
    local isHead = part.Name == "Head"
    local inner, outer
    if isHead then
        inner = Instance.new("CylinderHandleAdornment")
        outer = Instance.new("CylinderHandleAdornment")
        inner.CFrame = CFrame.Angles(math.rad(90), 0, 0)
        outer.CFrame = CFrame.Angles(math.rad(90), 0, 0)
        inner.Radius = 0.54
        outer.Radius = 0.62
        inner.Height = 1.12
        outer.Height = 1.3
    else
        inner = Instance.new("BoxHandleAdornment")
        outer = Instance.new("BoxHandleAdornment")
        inner.Size = part.Size + Vector3.new(0.02, 0.02, 0.02)
        outer.Size = part.Size + Vector3.new(0.12, 0.12, 0.12)
    end
    inner.Name = "inner"
    outer.Name = "outer"
    inner.Adornee = part
    outer.Adornee = part
    inner.AlwaysOnTop = true
    outer.AlwaysOnTop = false
    inner.ZIndex = 5
    outer.ZIndex = 1
    inner.Parent = part
    outer.Parent = part
    return {inner = inner, outer = outer}
end

local function isChamsPairValid(pair, part)
    return pair
        and pair.inner and pair.inner.Parent == part
        and pair.outer and pair.outer.Parent == part
        and pair.inner.Adornee == part
        and pair.outer.Adornee == part
end

local function updatePartChams(player, character, state)
    clearHighlightChams(player, state)
    if not state.Parts then state.Parts = {} end

    local seen = {}
    local visibleColor = EspFrameCache.colors.chamsVisible or Color3.fromRGB(0, 255, 120)
    local wallColor = EspFrameCache.colors.chamsWall or Color3.fromRGB(255, 60, 60)
    local visibleTransparency = EspFrameCache.chamsVisibleTransparency
    local wallTransparency = EspFrameCache.chamsWallTransparency
    if type(visibleTransparency) ~= "number" then visibleTransparency = 0.35 end
    if type(wallTransparency) ~= "number" then wallTransparency = 0.35 end
    visibleTransparency = math.clamp(visibleTransparency, 0, 1)
    wallTransparency = math.clamp(wallTransparency, 0, 1)

    for _, part in ipairs(character:GetChildren()) do
        if part:IsA("BasePart")
            and CONSTANTS.RealHitboxLookup[part.Name]
            and part.Name ~= "HumanoidRootPart"
            and part.Name ~= "HeadHB"
            and part.Name ~= "FakeHead"
        then
            seen[part] = true
            local pair = state.Parts[part]
            if not isChamsPairValid(pair, part) then
                if pair then
                    if pair.inner then pcall(function() pair.inner:Destroy() end) end
                    if pair.outer then pcall(function() pair.outer:Destroy() end) end
                end
                local existingInner = part:FindFirstChild("inner")
                local existingOuter = part:FindFirstChild("outer")
                if existingInner and existingOuter
                    and existingInner:IsA("HandleAdornment")
                    and existingOuter:IsA("HandleAdornment")
                then
                    pair = {inner = existingInner, outer = existingOuter}
                    pair.inner.Adornee = part
                    pair.outer.Adornee = part
                else
                    if existingInner then pcall(function() existingInner:Destroy() end) end
                    if existingOuter then pcall(function() existingOuter:Destroy() end) end
                    pair = createChamsPair(part)
                end
                state.Parts[part] = pair
            end

            if part.Name ~= "Head" then
                pair.inner.Size = part.Size + Vector3.new(0.02, 0.02, 0.02)
                pair.outer.Size = part.Size + Vector3.new(0.12, 0.12, 0.12)
            end
            pair.inner.Color3 = wallColor
            pair.outer.Color3 = visibleColor
            pair.inner.Transparency = wallTransparency
            pair.outer.Transparency = visibleTransparency
            pair.inner.AlwaysOnTop = true
            pair.outer.AlwaysOnTop = false
            pair.inner.Visible = true
            pair.outer.Visible = true
        end
    end

    for part, pair in pairs(state.Parts) do
        if not seen[part] or not part.Parent then
            if pair.inner then pcall(function() pair.inner:Destroy() end) end
            if pair.outer then pcall(function() pair.outer:Destroy() end) end
            state.Parts[part] = nil
        end
    end
end

Shared.updatePlayerChams = function(player, character)
    if not player or player == LocalPlayer or not character or not character.Parent then
        Shared.removePlayerChams(player)
        return
    end

    local myTeam, theirTeam = LocalPlayer.Team, player.Team
    local sameTeam = myTeam ~= nil and theirTeam ~= nil and myTeam == theirTeam
    if not EspFrameCache.toggles.chams or (EspFrameCache.toggles.teamCheck and sameTeam) then
        Shared.removePlayerChams(player)
        return
    end

    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if not rootPart then
        Shared.removePlayerChams(player)
        return
    end

    local state = EspRuntime.Chams[player]
    if state and state.Character ~= character then
        Shared.removePlayerChams(player)
        state = nil
    end
    if not state then
        state = {Character = character, Parts = {}, Highlight = nil}
        EspRuntime.Chams[player] = state
    end

    updatePartChams(player, character, state)
end


Shared.updatePlayerEsp = function(player)
    if not player or not player.Parent then return end

    Shared.updatePlayerChams(player, player.Character)

    if player == LocalPlayer then
        local drawingSet = EspRuntime.Drawings[player]
        if drawingSet then Shared.hideDrawingSet(drawingSet, true) end
        return
    end

    if not EspFrameCache.anyEnabled then
        local drawingSet = EspRuntime.Drawings[player]
        if drawingSet then Shared.hideDrawingSet(drawingSet, true) end
            return
    end

    local drawingSet = Shared.getDrawingSet(player)

    if EspFrameCache.toggles.teamCheck then
        local myTeam, theirTeam = LocalPlayer.Team, player.Team
        if myTeam ~= nil and theirTeam ~= nil and theirTeam == myTeam then
            Shared.hideDrawingSet(drawingSet, true)
            return
        end
    end

    local character, humanoid, rootPart = getCachedCharacterParts(player)
    if not character or not rootPart then
        Shared.hideDrawingSet(drawingSet, true)
        return
    end

    local camera = getCamera()
    if not camera then
        Shared.hideDrawingSet(drawingSet, true)
        return
    end

    local left, top, width, height = getCharacterScreenBox(character, humanoid, rootPart)
    local onScreen = left ~= nil

    if not onScreen then
        drawingSet.Box.Visible = false
        drawingSet.BoxOutline.Visible = false
        drawingSet.BoxFill.Visible = false
        drawingSet.Name.Visible = false
        drawingSet.Weapon.Visible = false
        drawingSet.HealthBarOutline.Visible = false
        drawingSet.HealthBarFill.Visible = false
        drawingSet.HealthText.Visible = false

        if EspFrameCache.toggles.oof and drawingSet.OofArrow and drawingSet.OofArrowOutline then
            local camCf = camera.CFrame
            local dir = camCf:PointToObjectSpace(rootPart.Position)
            if dir.Z >= 0 then dir = Vector3.new(dir.X, dir.Y, 0.001) end
            local angle = math.atan2(dir.Z, dir.X)
            local cx, sy = math.cos(angle), math.sin(angle)
            local cx1, sy1 = math.cos(angle + math.pi * 0.5), math.sin(angle + math.pi * 0.5)
            local cx2, sy2 = math.cos(angle + math.pi * 1.5), math.sin(angle + math.pi * 1.5)
            local viewport = camera.ViewportSize
            local bigger = math.max(viewport.X, viewport.Y)
            local smaller = math.min(viewport.X, viewport.Y)
            local arrowSize = math.clamp(EspFrameCache.options.oofSize or 12, 4, 40)
            local arrowPct = math.clamp(EspFrameCache.options.oofDistance or 40, 10, 100)
            local arrowOrigin = viewport * 0.5 + Vector2.new(cx * bigger * arrowPct / 200, sy * smaller * arrowPct / 200)
            local color = EspFrameCache.colors.oof or Color3.fromRGB(255, 255, 255)
            drawingSet.OofArrow.PointA = arrowOrigin + Vector2.new(arrowSize * 2 * cx, arrowSize * 2 * sy)
            drawingSet.OofArrow.PointB = arrowOrigin + Vector2.new(arrowSize * cx1, arrowSize * sy1)
            drawingSet.OofArrow.PointC = arrowOrigin + Vector2.new(arrowSize * cx2, arrowSize * sy2)
            drawingSet.OofArrow.Color = color
            drawingSet.OofArrow.Filled = true
            drawingSet.OofArrow.Visible = true
            drawingSet.OofArrowOutline.PointA = drawingSet.OofArrow.PointA
            drawingSet.OofArrowOutline.PointB = drawingSet.OofArrow.PointB
            drawingSet.OofArrowOutline.PointC = drawingSet.OofArrow.PointC
            drawingSet.OofArrowOutline.Color = Color3.new(color.R * 0.35, color.G * 0.35, color.B * 0.35)
            drawingSet.OofArrowOutline.Filled = false
            drawingSet.OofArrowOutline.Visible = true
        else
            if drawingSet.OofArrow then drawingSet.OofArrow.Visible = false end
            if drawingSet.OofArrowOutline then drawingSet.OofArrowOutline.Visible = false end
        end
        return
    end

    if drawingSet.OofArrow then drawingSet.OofArrow.Visible = false end
    if drawingSet.OofArrowOutline then drawingSet.OofArrowOutline.Visible = false end

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
    local showBoxFill = EspFrameCache.toggles.boxFill

    local boxColor = EspFrameCache.colors.box
    local nameColor = EspFrameCache.colors.name

    local boxPos = Vector2.new(left, top)
    local boxSize = Vector2.new(width, height)

    drawingSet.BoxOutline.Position = boxPos
    drawingSet.BoxOutline.Size = boxSize
    drawingSet.BoxOutline.Thickness = CONSTANTS.ESP_BOX_OUTLINE_THICKNESS
    drawingSet.BoxOutline.Color = Color3.fromRGB(0, 0, 0)
    drawingSet.BoxOutline.Visible = showBox

    drawingSet.Box.Position = boxPos
    drawingSet.Box.Size = boxSize
    drawingSet.Box.Color = boxColor
    drawingSet.Box.Thickness = CONSTANTS.ESP_BOX_THICKNESS
    drawingSet.Box.Visible = showBox

    if showBoxFill then
        drawingSet.BoxFill.Position = boxPos
        drawingSet.BoxFill.Size = boxSize
        drawingSet.BoxFill.Color = EspFrameCache.colors.boxFill
        drawingSet.BoxFill.Transparency = EspFrameCache.boxFillTransparency
        drawingSet.BoxFill.Visible = true
    else
        drawingSet.BoxFill.Visible = false
    end

    local espFont = EspFrameCache.options.font
    local espFontSize = EspFrameCache.options.fontSize or 13
    drawingSet.Name.Text = player.Name
    drawingSet.Name.Position = Vector2.new(centerX, top - 15)
    drawingSet.Name.Color = nameColor
    drawingSet.Name.Font = espFont
    drawingSet.Name.Size = espFontSize
    drawingSet.Name.Visible = showName

    local showWeapon = EspFrameCache.toggles.weapon
    local weaponColor = EspFrameCache.colors.weapon
    local weaponName = getCachedEquippedTool(player, character)
    drawingSet.Weapon.Text = weaponName
    drawingSet.Weapon.Position = Vector2.new(centerX, bottom + 3)
    drawingSet.Weapon.Color = weaponColor
    drawingSet.Weapon.Font = espFont
    drawingSet.Weapon.Size = espFontSize
    drawingSet.Weapon.Visible = showWeapon and weaponName ~= ""


    local showHealthBar = EspFrameCache.toggles.healthBar
    if showHealthBar and humanoid then
        local hpPercent = math.clamp(humanoid.Health / humanoid.MaxHealth, 0, 1)
        local barWidth = CONSTANTS.ESP_HEALTH_BAR_WIDTH
        local barHeight = height
        local barX = left - barWidth - 2
        local barY = top

        local showHealthOutline = EspFrameCache.toggles.healthBarOutline
        drawingSet.HealthBarOutline.Position = Vector2.new(barX, barY)
        drawingSet.HealthBarOutline.Size = Vector2.new(barWidth, barHeight)
        drawingSet.HealthBarOutline.Color = Color3.fromRGB(0, 0, 0)
        drawingSet.HealthBarOutline.Thickness = CONSTANTS.ESP_HEALTH_BAR_OUTLINE_THICKNESS
        drawingSet.HealthBarOutline.Visible = showHealthOutline

        local inset = showHealthOutline and CONSTANTS.ESP_HEALTH_BAR_OUTLINE_THICKNESS or 0
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
            drawingSet.HealthText.Font = espFont
            drawingSet.HealthText.Size = espFontSize
            drawingSet.HealthText.Visible = true
        else
            drawingSet.HealthText.Visible = false
        end
    else
        drawingSet.HealthBarOutline.Visible = false
        drawingSet.HealthBarFill.Visible = false
        drawingSet.HealthText.Visible = false
    end

end


Shared.updateItemEsp = function()
    if not Toggles.ESPItemESP or not Toggles.ESPItemESP.Value then
        for item, text in pairs(EspRuntime.ItemDrawings) do
            if text then
                pcall(function() text.Visible = false; text:Remove() end)
            end
            EspRuntime.ItemDrawings[item] = nil
        end
        return
    end

    local debris = Workspace:FindFirstChild("Debris")
    if not debris then return end

    local camera = getCamera()
    if not camera then return end

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
                text.Size = getEspFontSize()
                EspRuntime.ItemDrawings[item] = text
            end
            text.Font = getEspDrawingFont()
            text.Size = getEspFontSize()


            local screenPos = camera:WorldToViewportPoint(item.Position)
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


Shared.ensureFovCircles = function()
    if not AimRuntime.AimFovCircle then
        local ok, c = pcall(Drawing.new, "Circle")
        if ok and c then
            c.Visible = false
            c.Thickness = 1.5
            c.NumSides = 48
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
            c.NumSides = 48
            c.Filled = false
            c.Color = Color3.fromRGB(255, 255, 255)
            AimRuntime.RageFovCircle = c
        end
    end
end

Shared.updateFovCircle = function()
    Shared.ensureFovCircles()
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
        local show = Toggles.RagebotEnable and Toggles.RagebotEnable.Value
        if show then
            local fovValue = Options.RagebotFOV and Options.RagebotFOV.Value or 1
            local radius = fovValue * (viewport.Y / cam.FieldOfView)
            rageCircle.Position = center
            rageCircle.Radius = math.min(radius, 100000)
            rageCircle.Color = CONSTANTS.RagebotFOVColor
            rageCircle.Visible = true
        else
            rageCircle.Visible = false
        end
    end

end


-- crosshair
Shared.CrosshairState = { Circle = nil, Outline = nil, StateText = nil, Created = false }

ensureCrosshair = function()
    if Shared.CrosshairState.Created then return end
    local success, circle = pcall(Drawing.new, "Circle")
    if success and circle then
        circle.Visible = false
        circle.Radius = 2
        circle.Color = Color3.fromRGB(255, 255, 255)
        circle.Thickness = 1
        circle.NumSides = 16
        circle.Filled = true
        circle.ZIndex = 2
        Shared.CrosshairState.Circle = circle
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
        Shared.CrosshairState.Outline = outline
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
        Shared.CrosshairState.StateText = stateText
    end
    Shared.CrosshairState.Created = true
end

Shared.getMovementStateText = function()
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
    if not Shared.CrosshairState.Circle then return end

    local enabled = Toggles.MiscCenterDot and Toggles.MiscCenterDot.Value
    local showState = Toggles.MiscStateIndicator and Toggles.MiscStateIndicator.Value

    if not enabled and not showState then
        Shared.CrosshairState.Circle.Visible = false
        if Shared.CrosshairState.Outline then Shared.CrosshairState.Outline.Visible = false end
        if Shared.CrosshairState.StateText then Shared.CrosshairState.StateText.Visible = false end
        return
    end

    local cam = getCamera()
    if not cam then return end
    local viewport = cam.ViewportSize
    local center = Vector2.new(viewport.X / 2, viewport.Y / 2)

    if enabled then
        local col = getOptionColor("MiscCenterDotColor", Color3.fromRGB(255, 255, 255))
        Shared.CrosshairState.Circle.Position = center
        Shared.CrosshairState.Circle.Color = col
        Shared.CrosshairState.Circle.Visible = true
        if Shared.CrosshairState.Outline then
            Shared.CrosshairState.Outline.Position = center
            Shared.CrosshairState.Outline.Visible = true
        end
    else
        Shared.CrosshairState.Circle.Visible = false
        if Shared.CrosshairState.Outline then Shared.CrosshairState.Outline.Visible = false end
    end

    if showState and Shared.CrosshairState.StateText then
        local stateStr = Shared.getMovementStateText()
        if stateStr ~= "" then
            Shared.CrosshairState.StateText.Text = stateStr
            Shared.CrosshairState.StateText.Position = Vector2.new(center.X, center.Y + 20)
            Shared.CrosshairState.StateText.Color = getOptionColor("MiscStateIndicatorColor", Color3.fromRGB(255, 255, 255))
            Shared.CrosshairState.StateText.Visible = true
        else
            Shared.CrosshairState.StateText.Visible = false
        end
    else
        if Shared.CrosshairState.StateText then Shared.CrosshairState.StateText.Visible = false end
    end
end


-- hit log (ported from clarity.tk.lua, bottom-center notifications with progress bar)
local HitLogGui, HitLogContainer, HitLogNotifCount
HitLogNotifCount = 0

Shared.pushHitLog = function(text, color, duration)
    if not (Toggles.MiscHitLog and Toggles.MiscHitLog.Value) then return end
    duration = duration or 4
    color = color or Color3.fromRGB(76, 175, 80)

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
        HitLogContainer.AnchorPoint = Vector2.new(0.5, 1)
        HitLogContainer.Position = UDim2.new(0.5, 0, 1, -60)
        HitLogContainer.Size = UDim2.new(0, 340, 0, 300)
        HitLogContainer.Parent = HitLogGui

        local layout = Instance.new("UIListLayout")
        layout.Padding = UDim.new(0, 4)
        layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
        layout.SortOrder = Enum.SortOrder.LayoutOrder
        layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
        layout.Parent = HitLogContainer
    end

    HitLogNotifCount = HitLogNotifCount + 1
    local order = HitLogNotifCount

    local TweenService = game:GetService("TweenService")

    local bar = Instance.new("Frame")
    bar.Name = "Notif_" .. order
    bar.LayoutOrder = order
    bar.Size = UDim2.new(1, 0, 0, 0)
    bar.BackgroundColor3 = Color3.fromRGB(18, 18, 18)
    bar.BorderSizePixel = 0
    bar.ClipsDescendants = true
    bar.Parent = HitLogContainer

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 4)
    corner.Parent = bar

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(40, 40, 40)
    stroke.Thickness = 1
    stroke.Parent = bar

    local progress = Instance.new("Frame")
    progress.Name = "Progress"
    progress.Size = UDim2.new(1, 0, 0, 2)
    progress.Position = UDim2.new(0, 0, 0, 0)
    progress.BackgroundColor3 = color
    progress.BackgroundTransparency = 0
    progress.BorderSizePixel = 0
    progress.ZIndex = 2
    progress.Parent = bar

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -12, 1, 0)
    label.Position = UDim2.new(0, 6, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextSize = 13
    label.Font = Enum.Font.Code
    label.TextColor3 = Color3.fromRGB(220, 220, 220)
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.TextTruncate = Enum.TextTruncate.AtEnd
    label.ZIndex = 4
    label.Parent = bar

    TweenService:Create(bar, TweenInfo.new(0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
        Size = UDim2.new(1, 0, 0, 24)
    }):Play()
    TweenService:Create(progress, TweenInfo.new(duration, Enum.EasingStyle.Linear), {
        Size = UDim2.new(0, 0, 0, 2)
    }):Play()

    task.spawn(function()
        task.wait(duration)
        local fadeOut = TweenService:Create(bar, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
            Size = UDim2.new(1, 0, 0, 0),
            BackgroundTransparency = 1
        })
        TweenService:Create(label, TweenInfo.new(0.3), {TextTransparency = 1}):Play()
        TweenService:Create(progress, TweenInfo.new(0.3), {BackgroundTransparency = 1}):Play()
        fadeOut:Play()
        fadeOut.Completed:Wait()
        bar:Destroy()
        HitLogNotifCount = math.max(0, HitLogNotifCount - 1)
    end)
end


-- viewmodel visuals: no cache, full rescan every RenderStepped
Shared.VMState = {}

local FORCEFIELD_TEXTURES = {
    SmoothPlastic = "",
    ForceField = "rbxassetid://4573037993",
}

local function hasProperty(obj, prop)
    return pcall(function()
        local _ = obj[prop]
    end)
end

local function isWeaponViewPart(inst)
    if not inst then return false end
    local n = inst.Name
    if n == "Flash" or n == "FlashS" or n == "2Flash" or n == "Muzzle" then return false end

    if inst:IsA("MeshPart") then return true end
    if inst:IsA("BasePart") then
        return n == "Part"
            or n == "Silencer2"
            or n == "Silencer"
            or n == "Suppressed"
            or n == "Handle"
            or n == "Handle2"
            or n == "Blade"
            or n == "StatClock"
    end
    return false
end

local function applyWeaponPartChams(part, color, matEnum, transparency, reflectance, forceTransparency)
    if not part or not part:IsA("BasePart") then return end
    if part.Name == "StatClock" then part:ClearAllChildren() end
    part.Color = color
    part.Material = matEnum
    if forceTransparency or part.Transparency < 1 then
        part.Transparency = transparency
    end
    if hasProperty(part, "TextureID") then part.TextureID = "" end
    if hasProperty(part, "Reflectance") then part.Reflectance = reflectance end
    local surfaceAppearance = part:FindFirstChildOfClass("SurfaceAppearance")
    if surfaceAppearance then surfaceAppearance:Destroy() end
end

updateViewModelVisuals = function()
    local weaponChams = Toggles.VMWeaponChams and Toggles.VMWeaponChams.Value
    local armChams = Toggles.VMArmChams and Toggles.VMArmChams.Value
    local removeSleeves = Toggles.VMRemoveSleeves and Toggles.VMRemoveSleeves.Value
    local removeGloves = Toggles.VMRemoveGloves and Toggles.VMRemoveGloves.Value
    if not weaponChams and not armChams and not removeSleeves and not removeGloves then
        return
    end

    local cam = getCamera()
    local arms = cam and cam:FindFirstChild("Arms")
    if not arms then return end

    local weaponColor = getOptionColor("VMWeaponColor", Color3.fromRGB(255, 255, 255))
    local weaponMaterial = Options.VMWeaponMaterial and Options.VMWeaponMaterial.Value or "SmoothPlastic"
    local weaponTransparency = (Options.VMWeaponTransparency and Options.VMWeaponTransparency.Value or 0) / 100
    local weaponReflectance = (Options.VMWeaponReflectance and Options.VMWeaponReflectance.Value or 0) / 50
    local armColor = getOptionColor("VMArmColor", Color3.fromRGB(255, 255, 255))
    local armMaterial = Options.VMArmMaterial and Options.VMArmMaterial.Value or "SmoothPlastic"
    local armTransparency = (Options.VMArmTransparency and Options.VMArmTransparency.Value or 0) / 100
    local weaponMatEnum = Enum.Material[weaponMaterial] or Enum.Material.SmoothPlastic
    local armMatEnum = Enum.Material[armMaterial] or Enum.Material.SmoothPlastic
    local armVertex = Vector3.new(armColor.R, armColor.G, armColor.B)
    local ffTex = armMaterial == "ForceField" and FORCEFIELD_TEXTURES.ForceField or ""

    local knife = false
    local handle = nil

    for _, child in ipairs(arms:GetChildren()) do
        local name = child.Name

        if weaponChams and isWeaponViewPart(child) then
            local isSilencer = name == "Silencer2" or name == "Silencer" or name == "Suppressed"
            applyWeaponPartChams(child, weaponColor, weaponMatEnum, weaponTransparency, weaponReflectance, not isSilencer)
        end

        if string.find(name, "Knife", 1, true) or name == "Handle2" or name == "Blade" then
            knife = true
        end
        if name == "Handle" then handle = child end

        if (armChams or removeSleeves or removeGloves) and child:IsA("Model") then
            for _, desc in ipairs(child:GetDescendants()) do
                local dName = desc.Name
                if removeSleeves and dName == "Sleeve" and desc:GetAttribute("CW_Applied") == nil then
                    desc:Destroy()
                elseif removeGloves and (dName == "Glove" or dName == "RGlove" or dName == "LGlove" or string.find(string.lower(dName), "glove", 1, true)) then
                    pcall(function() desc:Destroy() end)
                elseif armChams then
                    if hasProperty(desc, "CastShadow") then desc.CastShadow = false end
                    if desc:IsA("SpecialMesh") then
                        desc.TextureId = ffTex
                        desc.VertexColor = armVertex
                    elseif desc:IsA("Part") then
                        desc.Material = armMatEnum
                        desc.Color = armColor
                        if desc.Transparency ~= 1 then
                            desc.Transparency = math.min(armTransparency + 0.01, 1)
                        end
                    end
                end
            end
        end
    end

    if weaponChams and knife and handle and handle.Parent then
        handle.Transparency = 1
    end
end

Shared.cleanupViewModelVisuals = function()
    Shared.VMState = {}
end

-- skybox changer
Shared.SKYBOX_PRESETS = {
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

Shared.SkyboxState = { customSky = nil, originalSky = nil, savedOriginal = false }

applySkyboxChanger = function()
    local lighting = game:GetService('Lighting')
    local enabled = Toggles.AmbienceSkyboxChanger and Toggles.AmbienceSkyboxChanger.Value

    -- Remove previous custom sky
    if Shared.SkyboxState.customSky then
        Shared.SkyboxState.customSky:Destroy()
        Shared.SkyboxState.customSky = nil
    end

    if not enabled then
        -- Restore original sky
        if Shared.SkyboxState.originalSky and not Shared.SkyboxState.originalSky.Parent then
            Shared.SkyboxState.originalSky.Parent = lighting
        end
        return
    end

    -- Save original sky on first enable
    if not Shared.SkyboxState.savedOriginal then
        local origSky = lighting:FindFirstChildOfClass('Sky')
        Shared.SkyboxState.originalSky = origSky
        Shared.SkyboxState.savedOriginal = true
    end

    -- Hide original sky
    local origSky = lighting:FindFirstChildOfClass('Sky')
    if origSky and origSky ~= Shared.SkyboxState.customSky then
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
                            if Shared.SkyboxState.customSky then Shared.SkyboxState.customSky:Destroy() end
                            Shared.SkyboxState.customSky = obj
                            obj.Name = "ValenokCustomSky"
                            obj.Parent = lighting
                            return
                        end
                        -- If it's a model/folder, search for Sky inside
                        local sky = obj:FindFirstChildOfClass("Sky")
                        if sky then
                            if Shared.SkyboxState.customSky then Shared.SkyboxState.customSky:Destroy() end
                            Shared.SkyboxState.customSky = sky:Clone()
                            Shared.SkyboxState.customSky.Name = "ValenokCustomSky"
                            Shared.SkyboxState.customSky.Parent = lighting
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
        if Shared.SkyboxState.originalSky and not Shared.SkyboxState.originalSky.Parent then
            Shared.SkyboxState.originalSky.Parent = lighting
        end
        return
    end

    local preset = Shared.SKYBOX_PRESETS[presetName]
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
    Shared.SkyboxState.customSky = newSky
end

Shared.SkyboxState.guardConn = nil
Shared.SkyboxState.setupGuard = function()
    if Shared.SkyboxState.guardConn then Shared.SkyboxState.guardConn:Disconnect() end
    local lighting = game:GetService('Lighting')
    Shared.SkyboxState.guardConn = lighting.ChildAdded:Connect(function(child)
        if child:IsA("Sky") and Shared.SkyboxState.customSky and Shared.SkyboxState.customSky.Parent then
            if child ~= Shared.SkyboxState.customSky then
                task.wait(0.2)
                if child and child.Parent then child.Parent = nil end
                if Shared.SkyboxState.customSky and not Shared.SkyboxState.customSky.Parent then
                    Shared.SkyboxState.customSky.Parent = lighting
                end
            end
        end
    end)
end
Shared.SkyboxState.setupGuard()

-- ambience
Shared.updateAmbience = function()
    local lighting = game:GetService('Lighting')

    local customTime = Toggles.AmbienceCustomTime and Toggles.AmbienceCustomTime.Value
    local customSkybox = Toggles.AmbienceCustomSkybox and Toggles.AmbienceCustomSkybox.Value
    local skyColorEnabled = Toggles.AmbienceSkyColor and Toggles.AmbienceSkyColor.Value
    local noShadow = Toggles.AmbienceNoShadow and Toggles.AmbienceNoShadow.Value

    local anyEnabled = customTime or customSkybox or skyColorEnabled or noShadow

    if not anyEnabled then
        if Shared.AmbienceSavedLighting then
            pcall(function()
                lighting.ClockTime = Shared.AmbienceSavedLighting.ClockTime
                lighting.GlobalShadows = Shared.AmbienceSavedLighting.GlobalShadows
                lighting.Brightness = Shared.AmbienceSavedLighting.Brightness
                lighting.Ambient = Shared.AmbienceSavedLighting.Ambient
                lighting.OutdoorAmbient = Shared.AmbienceSavedLighting.OutdoorAmbient
                lighting.ColorShift_Bottom = Shared.AmbienceSavedLighting.ColorShift_Bottom
                lighting.ColorShift_Top = Shared.AmbienceSavedLighting.ColorShift_Top
                if Shared.AmbienceSavedLighting.Skybox and not Shared.AmbienceSavedLighting.Skybox.Parent then
                    Shared.AmbienceSavedLighting.Skybox.Parent = lighting
                end
                if Shared.AmbienceSavedLighting.SkyTextures and Shared.AmbienceSavedLighting.Skybox then
                    local t = Shared.AmbienceSavedLighting.SkyTextures
                    local sky = Shared.AmbienceSavedLighting.Skybox
                    sky.SkyboxBk = t.SkyboxBk
                    sky.SkyboxDn = t.SkyboxDn
                    sky.SkyboxFt = t.SkyboxFt
                    sky.SkyboxLf = t.SkyboxLf
                    sky.SkyboxRt = t.SkyboxRt
                    sky.SkyboxUp = t.SkyboxUp
                    sky.StarCount = t.StarCount
                    sky.SunTextureId = t.SunTextureId
                    sky.MoonTextureId = t.MoonTextureId
                end
                if Shared.AmbienceSavedLighting.FogColor then
                    lighting.FogColor = Shared.AmbienceSavedLighting.FogColor
                    lighting.FogEnd = Shared.AmbienceSavedLighting.FogEnd
                end
            end)
            Shared.AmbienceSavedLighting = nil
        end
        return
    end

    if not Shared.AmbienceSavedLighting then
        local sky = lighting:FindFirstChildOfClass('Sky')
        Shared.AmbienceSavedLighting = {
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
            } or nil,
        }
    end


    if customTime then
        lighting.ClockTime = Options.AmbienceTime and Options.AmbienceTime.Value or 12
    else
        lighting.ClockTime = Shared.AmbienceSavedLighting.ClockTime
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
        if Shared.AmbienceSavedLighting.Skybox and not Shared.AmbienceSavedLighting.Skybox.Parent then
            Shared.AmbienceSavedLighting.Skybox.Parent = lighting
        end
        lighting.Ambient = Shared.AmbienceSavedLighting.Ambient
        lighting.OutdoorAmbient = Shared.AmbienceSavedLighting.OutdoorAmbient
        lighting.ColorShift_Bottom = Shared.AmbienceSavedLighting.ColorShift_Bottom
        lighting.ColorShift_Top = Shared.AmbienceSavedLighting.ColorShift_Top
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
        if Shared.AmbienceSavedLighting.SkyTextures and Shared.AmbienceSavedLighting.Skybox then
            local sky = Shared.AmbienceSavedLighting.Skybox
            local t = Shared.AmbienceSavedLighting.SkyTextures
            sky.SkyboxBk = t.SkyboxBk
            sky.SkyboxDn = t.SkyboxDn
            sky.SkyboxFt = t.SkyboxFt
            sky.SkyboxLf = t.SkyboxLf
            sky.SkyboxRt = t.SkyboxRt
            sky.SkyboxUp = t.SkyboxUp
            sky.StarCount = t.StarCount
            sky.SunTextureId = t.SunTextureId
            sky.MoonTextureId = t.MoonTextureId
        end
        if Shared.AmbienceSavedLighting.FogColor then
            lighting.FogColor = Shared.AmbienceSavedLighting.FogColor
            lighting.FogEnd = Shared.AmbienceSavedLighting.FogEnd
        end
    end

    if noShadow then
        lighting.GlobalShadows = false
    else
        lighting.GlobalShadows = Shared.AmbienceSavedLighting.GlobalShadows
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
    local ancestryConn
    ancestryConn = armsObj.AncestryChanged:Connect(function(_, newParent)
        if not newParent then
            if skinConn then skinConn:Disconnect(); skinConn = nil end
            if ancestryConn then ancestryConn:Disconnect(); ancestryConn = nil end
        end
    end)
end
SC.applySkinToArms = SC_applySkinToArms


local function SC_setupArmsWatcher()
    if SC.State.armsConn then SC.State.armsConn:Disconnect() end
    SC.State.armsConn = getCamera().ChildAdded:Connect(function(obj)
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
    World = Window:AddTab('World'),
    Skin = Window:AddTab('Skin'),
    Movement = Window:AddTab('Movement'),
    Misc = Window:AddTab('Misc'),
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
LegitSections.Aimbot:AddToggle('AimbotAutoScope', {Text = 'Auto scope', Default = false})

LegitSections.Triggerbot:AddToggle('TriggerbotEnable', {Text = 'Enable', Default = false, KeyPicker = {Idx = 'TriggerbotKeybind', Default = 'None', Mode = 'Toggle', Text = 'Trigger bot'}})
LegitSections.Triggerbot:AddToggle('TriggerbotTeamCheck', {Text = 'Team check', Default = false})
LegitSections.Triggerbot:AddToggle('TriggerbotOnStopOnly', {Text = 'On stop only', Default = false})
LegitSections.Triggerbot:AddToggle('TriggerbotSmokeCheck', {Text = 'Smoke check', Default = false})
LegitSections.Triggerbot:AddToggle('TriggerbotJumpCheck', {Text = 'Jump check', Default = false})
LegitSections.Triggerbot:AddToggle('TriggerbotMagnet', {Text = 'Magnet', Default = false})
LegitSections.Triggerbot:AddSlider('TriggerbotDelay', {Text = 'Trigger bot delay', Default = 0, Min = 0, Max = 300, Rounding = 0, Suffix = 'ms'})

LegitSections.RCS:AddToggle('RCSEnable', {Text = 'Enable', Default = false, Callback = function() updateRCS() end})
LegitSections.RCS:AddSlider('RCSValue', {Text = 'RCS', Default = 1, Min = 1, Max = 100, Rounding = 0, Callback = function() updateRCS() end})

local VisualTabbox = Tabs.Visual:AddLeftTabbox('ESP & Viewmodel')
local espTab = VisualTabbox:AddTab('ESP')
local fontsTab = VisualTabbox:AddTab('Fonts')
local viewmodelTab = VisualTabbox:AddTab('Viewmodel')


local WorldSections = {
    Ambience = Tabs.World:AddLeftGroupbox('Ambience'),
    Lighting = Tabs.World:AddRightGroupbox('Lighting'),
}

local MiscSections = {
    NameSpoofer = Tabs.Misc:AddLeftGroupbox('Name Spoofer'),
    General = Tabs.Misc:AddRightGroupbox('General'),
}

local VisualSections = {
    ThirdPerson = Tabs.Visual:AddLeftGroupbox('Third person'),
    Menu = Tabs.Visual:AddLeftGroupbox('Menu'),
    Removals = Tabs.Visual:AddRightGroupbox('Removals'),
    Grenades = Tabs.Visual:AddRightGroupbox('Grenades'),
    DamageIndicators = Tabs.Visual:AddRightGroupbox('Damage Indicators'),
    BulletImpact = Tabs.Visual:AddRightGroupbox('Bullet Impact'),
    Misc = Tabs.Visual:AddRightGroupbox('Misc'),
    FOVChanger = Tabs.Visual:AddLeftGroupbox('FOV Changer'),
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
MovementSections.Misc:AddToggle('FakeDuckEnable', {Text = 'Fake duck', Default = false, Callback = function() updateFakeDuck() end, KeyPicker = {Idx = 'FakeDuckKeybind', Default = 'V', Mode = 'Hold', Text = 'Fake duck'}})

RageSections.Ragebot:AddToggle('RagebotEnable', {Text = 'Enable', Default = false, KeyPicker = {Idx = 'RagebotKeybind', Default = 'None', Mode = 'Hold', Text = 'Ragebot'}})
RageSections.Ragebot:AddToggle('RagebotAutoFire', {Text = 'Auto Fire', Default = false})
RageSections.Ragebot:AddToggle('RagebotAutoScope', {Text = 'Auto Scope', Default = false})
RageSections.Ragebot:AddToggle('RagebotTeamCheck', {Text = 'Team Check', Default = false})
RageSections.Ragebot:AddToggle('RagebotHitPart', {
    Text = 'Hit Part',
    Default = false,
    Callback = function()
        if HitpartSilent.refreshMethod then HitpartSilent.refreshMethod() end
    end,
})
RageSections.Ragebot:AddToggle('RagebotAutoPenetration', {Text = 'Auto Penetration', Default = true})
RageSections.Ragebot:AddDropdown('RagebotHitbox', {
    Values = { 'Head', 'Body', 'Arms', 'Legs' },
    Default = 1,
    Multi = true,
    Text = 'Hitbox',
})
RageSections.Ragebot:AddSlider('RagebotFOV', {Text = 'FOV', Default = 1, Min = 1, Max = 180, Rounding = 0})
RageSections.Ragebot:AddSlider('SilentAimMaxWalls', {Text = 'Max Walls', Default = 3, Min = 1, Max = 15, Rounding = 0})

if HitpartSilent.refreshMethod then HitpartSilent.refreshMethod() end


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

RageSections.GunMods:AddToggle('GunModsNoRecoil', {Text = 'No recoil', Default = false, Callback = applyNoRecoil})
RageSections.GunMods:AddToggle('GunModsNoSpread', {Text = 'No spread', Default = false, Callback = applyNoSpread})
RageSections.GunMods:AddToggle('GunModsRapidFire', {Text = 'Rapid fire', Default = false, Callback = function(Value) if not Value then restoreAllRapidFireRates() else updateRapidFire() end end})
RageSections.GunMods:AddToggle('GunModsInstaEquip', {Text = 'Insta equip', Default = false, Callback = applyInstaEquip})
RageSections.GunMods:AddToggle('GunModsInstaReload', {Text = 'Insta reload', Default = false, Callback = applyInstaReload})
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
VisualSections.Misc:AddToggle('MiscHitLog', {Text = 'Hit log', Default = false})
VisualSections.Misc:AddToggle('MiscHideCrosshair', {Text = 'Hide game crosshair', Default = false})

-- Viewmodel tab
viewmodelTab:AddToggle('VMOffsetEnable', {Text = 'Viewmodel offset', Default = false})
viewmodelTab:AddSlider('VMOffsetX', {Text = 'X', Default = 0, Min = -25, Max = 25, Rounding = 1, Suffix = ''})
viewmodelTab:AddSlider('VMOffsetY', {Text = 'Y', Default = 0, Min = -25, Max = 25, Rounding = 1, Suffix = ''})
viewmodelTab:AddSlider('VMOffsetZ', {Text = 'Z', Default = 0, Min = -25, Max = 25, Rounding = 1, Suffix = ''})
viewmodelTab:AddSlider('VMRoll', {Text = 'Roll', Default = 0, Min = 0, Max = 360, Rounding = 1, Suffix = '°'})

viewmodelTab:AddToggle('VMWeaponChams', {Text = 'Weapon chams', Default = false, ColorPicker = {Idx = 'VMWeaponColor', Default = Color3.fromRGB(255, 255, 255), Title = 'Weapon color', Transparency = 0}, Callback = function() updateViewModelVisuals() end})
viewmodelTab:AddDropdown('VMWeaponMaterial', {Values = {'SmoothPlastic', 'Neon', 'ForceField', 'Glass'}, Default = 'SmoothPlastic', Text = 'Weapon material', Callback = function() updateViewModelVisuals() end})
viewmodelTab:AddSlider('VMWeaponTransparency', {Text = 'Weapon transparency', Default = 0, Min = 0, Max = 100, Rounding = 0, Suffix = '%', Callback = function() updateViewModelVisuals() end})
viewmodelTab:AddSlider('VMWeaponReflectance', {Text = 'Weapon reflectance', Default = 0, Min = 0, Max = 100, Rounding = 0, Suffix = '%', Callback = function() updateViewModelVisuals() end})

viewmodelTab:AddToggle('VMArmChams', {Text = 'Arm chams', Default = false, ColorPicker = {Idx = 'VMArmColor', Default = Color3.fromRGB(255, 255, 255), Title = 'Arm color', Transparency = 0}, Callback = function() updateViewModelVisuals() end})
viewmodelTab:AddDropdown('VMArmMaterial', {Values = {'SmoothPlastic', 'Neon', 'ForceField', 'Glass'}, Default = 'SmoothPlastic', Text = 'Arm material', Callback = function() updateViewModelVisuals() end})
viewmodelTab:AddSlider('VMArmTransparency', {Text = 'Arm transparency', Default = 0, Min = 0, Max = 100, Rounding = 0, Suffix = '%', Callback = function() updateViewModelVisuals() end})

viewmodelTab:AddToggle('VMRemoveSleeves', {Text = 'Remove sleeves', Default = false, Callback = function() updateViewModelVisuals() end})
viewmodelTab:AddToggle('VMRemoveGloves', {Text = 'Remove gloves', Default = false, Callback = function() updateViewModelVisuals() end})

RageSections.Exploit:AddToggle('ExploitKillAll', {Text = 'Kill all', Default = false, KeyPicker = {Idx = 'ExploitKillAllKeybind', Default = 'None', Mode = 'Hold', Text = 'Kill All'}})
RageSections.Exploit:AddToggle('ExploitNoFallDamage', {Text = 'No fall damage', Default = false})
RageSections.Exploit:AddToggle('ExploitNoFireDamage', {Text = 'No fire damage', Default = false})
RageSections.Exploit:AddToggle('ExploitInfAmmo', {Text = 'Inf ammo', Default = false})
espTab:AddToggle('ESPEnable', {Text = 'Enable', Default = false})

espTab:AddToggle('ESPTeamCheck', {Text = 'Team check', Default = false})
espTab:AddToggle('ESPBox', {Text = 'Box', Default = false, ColorPicker = {Idx = 'ESPBoxColor', Default = Color3.fromRGB(255, 255, 255), Title = 'Box color'}})
espTab:AddToggle('ESPBoxFill', {Text = 'Box fill', Default = false, ColorPicker = {Idx = 'ESPBoxFillColor', Default = Color3.fromRGB(255, 255, 255), Transparency = 0.5, Title = 'Box fill color'}})
espTab:AddToggle('ESPName', {Text = 'Name', Default = false, ColorPicker = {Idx = 'ESPNameColor', Default = Color3.fromRGB(255, 255, 255), Title = 'Name color'}})
espTab:AddToggle('ESPHealthBar', {Text = 'Health bar', Default = false, ColorPicker = {Idx = 'ESPHealthBarColor', Default = Color3.fromRGB(0, 255, 0), Title = 'Health bar color'}})
espTab:AddToggle('ESPHealthBarOutline', {Text = 'Health bar outline', Default = true})
espTab:AddToggle('ESPWeapon', {Text = 'Weapon ESP', Default = false, ColorPicker = {Idx = 'ESPWeaponColor', Default = Color3.fromRGB(255, 255, 255), Title = 'Weapon color'}})
do
    local chamsToggle = espTab:AddToggle('ESPChams', {
        Text = 'Chams',
        Default = false,
        ColorPicker = {
            Idx = 'ESPChamsVisibleColor',
            Default = Color3.fromRGB(0, 255, 120),
            Title = 'Visible',
            Transparency = 0.35,
        },
    })
    chamsToggle:AddColorPicker('ESPChamsWallColor', {
        Default = Color3.fromRGB(255, 60, 60),
        Title = 'Wall',
        Transparency = 0.35,
    })
end
espTab:AddToggle('ESPOofArrows', {Text = 'OOF arrows', Default = false, ColorPicker = {Idx = 'ESPOofColor', Default = Color3.fromRGB(255, 255, 255), Title = 'OOF color'}})
espTab:AddSlider('ESPOofSize', {Text = 'OOF size', Default = 12, Min = 4, Max = 30, Rounding = 0})
espTab:AddSlider('ESPOofDistance', {Text = 'OOF distance', Default = 40, Min = 10, Max = 100, Rounding = 0, Suffix = '%'})
espTab:AddToggle('ESPItemESP', {Text = 'Item ESP', Default = false, ColorPicker = {Idx = 'ESPItemColor', Default = Color3.fromRGB(255, 255, 255), Title = 'Item color'}})

fontsTab:AddDropdown('ESPFont', {
    Text = 'Font',
    Values = { 'UI', 'System', 'Plex', 'Monospace' },
    Default = 'Plex',
})
fontsTab:AddSlider('ESPFontSize', {Text = 'Font size', Default = 13, Min = 1, Max = 30, Rounding = 0})

VisualSections.Menu:AddToggle('MenuBindList', {Text = 'Bind list', Default = true, Callback = function(Value) if Library.KeybindFrame then Library.KeybindFrame.Visible = Value end end})

VisualSections.Menu:AddToggle('MenuWatermark', {Text = 'Watermark', Default = true, Callback = function(Value) Library:SetWatermarkVisibility(Value) end})

VisualSections.Removals:AddToggle('RemovalsNoSmoke', {Text = 'No smoke', Default = false, Callback = function() setupNoSmoke() end})
VisualSections.Removals:AddToggle('RemovalsNoFlash', {Text = 'No flash', Default = false, Callback = function() updateNoFlash() end})
VisualSections.Removals:AddToggle('RemovalsNoScope', {Text = 'No scope', Default = false, Callback = function() updateNoScope() end})

VisualSections.ThirdPerson:AddToggle('ThirdPersonEnable', {Text = 'Enable', Default = false, KeyPicker = {Idx = 'ThirdPersonKeybind', Default = 'None', Mode = 'Toggle', Text = 'Third person'}})
VisualSections.ThirdPerson:AddSlider('ThirdPersonDistance', {Text = 'Distance', Default = 5, Min = 1, Max = 100, Rounding = 0})
VisualSections.ThirdPerson:AddToggle('ThirdPersonHideVM', {Text = 'Hide viewmodel', Default = true})
VisualSections.ThirdPerson:AddToggle('ThirdPersonNoClip', {Text = 'Camera through walls', Default = false, Callback = function() Shared.updateThirdPersonNoClip() end})

WorldSections.Ambience:AddToggle('AmbienceCustomTime', {Text = 'Custom time', Default = false}):OnChanged(function() Shared.MiscState.ambienceDirty = true end)
WorldSections.Ambience:AddSlider('AmbienceTime', {Text = 'Time', Default = 12, Min = 0, Max = 24, Rounding = 1}):OnChanged(function() Shared.MiscState.ambienceDirty = true end)
WorldSections.Ambience:AddToggle('AmbienceCustomSkybox', {Text = 'Custom skybox', Default = false, ColorPicker = {Idx = 'AmbienceSkyboxColor', Default = Color3.fromRGB(0, 0, 0), Title = 'Skybox color', Callback = function() Shared.MiscState.ambienceDirty = true end}}):OnChanged(function() Shared.MiscState.ambienceDirty = true end)
WorldSections.Ambience:AddToggle('AmbienceSkyColor', {Text = 'Sky color', Default = false, ColorPicker = {Idx = 'AmbienceSkyColorValue', Default = Color3.fromRGB(0, 0, 0), Title = 'Sky color', Callback = function() Shared.MiscState.ambienceDirty = true end}}):OnChanged(function() Shared.MiscState.ambienceDirty = true end)
WorldSections.Ambience:AddToggle('AmbienceNoShadow', {Text = 'No shadow', Default = false}):OnChanged(function() Shared.MiscState.ambienceDirty = true end)

WorldSections.Ambience:AddToggle('AmbienceSkyboxChanger', {Text = 'Skybox changer', Default = false, Callback = function() applySkyboxChanger() end})
WorldSections.Ambience:AddDropdown('AmbienceSkyboxPreset', {
    Text = 'Skybox preset',
    Values = {"Game's Sky", "Purple Nebula", "Night Sky", "Pink Daylight", "Morning Glow", "Setting Sun", "Fade Blue", "Elegant Morning", "Neptune", "Redshift", "Aesthetic Night", "Gloomy Gray", "Light Within Dark", "Green Space", "The Winter", "Oblivion", "Final Bloodmoon", "Clouds", "Twilight", "Red Mountain", "Cloudy Skies", "Dark Blue"},
    Default = "Game's Sky",
    Callback = function() applySkyboxChanger() end,
})
WorldSections.Ambience:AddInput('AmbienceSkyboxAssetId', {Text = 'Custom asset ID', Default = '', Placeholder = 'e.g. 159454299', Callback = function() applySkyboxChanger() end})

-- Lighting section (ported from clarity.tk.lua)
WorldSections.Lighting:AddToggle('LightingBetterShadows', {Text = 'Better shadows', Default = false})
WorldSections.Lighting:AddToggle('LightingAmbient', {Text = 'Enabled ambient', Default = false, ColorPicker = {Idx = 'LightingAmbientColor', Default = Color3.fromRGB(128, 128, 128), Title = 'Ambient color'}})
WorldSections.Lighting:AddSlider('LightingBrightness', {Text = 'Brightness', Default = 2, Min = 0, Max = 10, Rounding = 1})
WorldSections.Lighting:AddToggle('LightingGradient', {Text = 'Gradient', Default = false, ColorPicker = {Idx = 'LightingGradientColor', Default = Color3.fromRGB(90, 90, 90), Title = 'Gradient color 1'}})
WorldSections.Lighting:AddToggle('LightingGradient2', {Text = 'Gradient color 2', Default = false, ColorPicker = {Idx = 'LightingGradientColor2', Default = Color3.fromRGB(150, 150, 150), Title = 'Gradient color 2'}})
WorldSections.Lighting:AddToggle('LightingSaturation', {Text = 'Saturation', Default = false})
WorldSections.Lighting:AddSlider('LightingSaturationValue', {Text = 'Saturation value', Default = 10, Min = 0, Max = 100, Rounding = 0})

-- Name Spoofer
MiscSections.NameSpoofer:AddToggle('MiscSpoofName', {Text = 'Enabled', Default = false})
MiscSections.NameSpoofer:AddInput('MiscSpoofedName', {Text = 'Spoofed name', Default = '', Placeholder = 'Enter name...'})

-- General (ported from clarity.tk.lua General section)
MiscSections.General:AddToggle('MiscRemoveRadio', {Text = 'Remove radio commands', Default = false})
MiscSections.General:AddToggle('MiscRemoveUI', {Text = 'Remove UI elements', Default = false, Callback = function() Shared.applyRemoveUIElements() end})
MiscSections.General:AddToggle('MiscSlideWalk', {Text = 'Slide walk', Default = false})

VisualSections.FOVChanger:AddToggle('VisualFovChanger', {Text = 'FOV changer', Default = false, Callback = function() Shared.applyFovChanger() end})
VisualSections.FOVChanger:AddSlider('VisualFovValue', {Text = 'FOV value', Default = 80, Min = 50, Max = 120, Rounding = 0, Callback = function() Shared.applyFovChanger() end})

ThemeManager:SetLibrary(Library)
SaveManager:SetLibrary(Library)
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({ 'SkinKnifeSkin', 'SkinWeaponSkin', 'SkinGloveSkin' })
ThemeManager:SetFolder('Valenok')
SaveManager:SetFolder('Valenok')

local MENU_FONT_MAP = {
    Code = Enum.Font.Code,
    Ubuntu = Enum.Font.Ubuntu,
    Gotham = Enum.Font.Gotham,
    GothamMedium = Enum.Font.GothamMedium,
    GothamBold = Enum.Font.GothamBold,
    SourceSans = Enum.Font.SourceSans,
    SourceSansBold = Enum.Font.SourceSansBold,
    Roboto = Enum.Font.Roboto,
    RobotoMono = Enum.Font.RobotoMono,
    Arcade = Enum.Font.Arcade,
    Legacy = Enum.Font.Legacy,
}

local MenuFontPreviewLabels = {}

local function styleMenuFontPreviewLabel(inst)
    if not inst or not inst.Parent then return end
    if not (inst:IsA("TextLabel") or inst:IsA("TextButton")) then return end
    local mapped = MENU_FONT_MAP[inst.Text]
    if not mapped then return end
    pcall(function()
        inst.Font = mapped
    end)
    MenuFontPreviewLabels[inst] = mapped
end

local function refreshMenuFontPreviews()
    for inst in pairs(MenuFontPreviewLabels) do
        if not inst or not inst.Parent then
            MenuFontPreviewLabels[inst] = nil
        end
    end

    if Library and Library.ScreenGui then
        for _, inst in ipairs(Library.ScreenGui:GetDescendants()) do
            styleMenuFontPreviewLabel(inst)
        end
    end

    for inst, mapped in pairs(MenuFontPreviewLabels) do
        if inst and inst.Parent then
            pcall(function()
                inst.Font = mapped
            end)
        end
    end
end

local function applyMenuFont(fontName)
    if not Library then return end
    local font = MENU_FONT_MAP[fontName] or Enum.Font.Code
    Library.Font = font

    local function applyTo(inst)
        if not inst then return end
        if MenuFontPreviewLabels[inst] then return end
        if inst:IsA("TextLabel") or inst:IsA("TextButton") or inst:IsA("TextBox") then
            -- keep font-name option labels as their own preview font
            if MENU_FONT_MAP[inst.Text] then
                styleMenuFontPreviewLabel(inst)
                return
            end
            pcall(function() inst.Font = font end)
        end
    end

    if Library.ScreenGui then
        for _, inst in ipairs(Library.ScreenGui:GetDescendants()) do
            applyTo(inst)
        end
    end

    if type(Library.Registry) == "table" then
        for _, data in pairs(Library.Registry) do
            if type(data) == "table" then
                applyTo(data.Instance)
            end
        end
    end

    if type(Library.HudRegistry) == "table" then
        for _, data in pairs(Library.HudRegistry) do
            if type(data) == "table" then
                applyTo(data.Instance)
            end
        end
    end

    refreshMenuFontPreviews()
end

do
    local ConfigSection = Tabs.Config:AddLeftGroupbox('Menu')
    ConfigSection:AddButton('Unload', function()
        if unloadValenok then unloadValenok() end
    end)
    ConfigSection:AddLabel('Menu bind'):AddKeyPicker('MenuKeybind', { Default = 'End', NoUI = true, Text = 'Menu' })
    ConfigSection:AddDropdown('MenuFont', {
        Text = 'Menu font',
        Values = {
            'Code', 'Ubuntu', 'Gotham', 'GothamMedium', 'GothamBold',
            'SourceSans', 'SourceSansBold', 'Roboto', 'RobotoMono', 'Arcade', 'Legacy',
        },
        Default = 'Code',
        Callback = function(value)
            applyMenuFont(value)
        end,
    })

    local menuFontOpt = Options.MenuFont
    if menuFontOpt then
        if type(menuFontOpt.SetValues) == "function" then
            local origSetValues = menuFontOpt.SetValues
            menuFontOpt.SetValues = function(self, ...)
                local result = origSetValues(self, ...)
                task.defer(refreshMenuFontPreviews)
                return result
            end
        end
        if type(menuFontOpt.OpenDropdown) == "function" then
            local origOpen = menuFontOpt.OpenDropdown
            menuFontOpt.OpenDropdown = function(self, ...)
                local result = origOpen(self, ...)
                task.defer(refreshMenuFontPreviews)
                return result
            end
        end
        if type(menuFontOpt.Display) == "function" then
            local origDisplay = menuFontOpt.Display
            menuFontOpt.Display = function(self, ...)
                local result = origDisplay(self, ...)
                task.defer(refreshMenuFontPreviews)
                return result
            end
        end
    end

    if Library.ScreenGui then
        Library:GiveSignal(Library.ScreenGui.DescendantAdded:Connect(function(inst)
            task.defer(function()
                styleMenuFontPreviewLabel(inst)
            end)
        end))
    end
end

Library.ToggleKeybind = Options.MenuKeybind
Library.KeybindFrame.Visible = true
applyMenuFont(Options.MenuFont and Options.MenuFont.Value or 'Code')
task.defer(refreshMenuFontPreviews)

-- When menu is open: capture mouse so game/camera don't receive clicks.
do
    local MenuInputLock = {
        active = false,
        modal = nil,
        savedMouseBehavior = nil,
        savedIconEnabled = nil,
    }

    local function ensureMenuModal()
        if MenuInputLock.modal and MenuInputLock.modal.Parent then
            return MenuInputLock.modal
        end
        local parent = Library.ScreenGui
        if not parent then return nil end

        local modal = Instance.new("TextButton")
        modal.Name = "ValenokMenuModal"
        modal.BackgroundTransparency = 1
        modal.BorderSizePixel = 0
        modal.Text = ""
        modal.AutoButtonColor = false
        modal.Size = UDim2.fromScale(1, 1)
        modal.Position = UDim2.fromScale(0, 0)
        modal.ZIndex = 0
        modal.Modal = false
        modal.Active = true
        modal.Selectable = false
        modal.Visible = false
        modal.Parent = parent
        MenuInputLock.modal = modal
        return modal
    end

    local function setMenuInputLock(open)
        open = open == true
        if MenuInputLock.active == open then
            -- still re-assert mouse state while open
            if open then
                pcall(function()
                    UserInputService.MouseBehavior = Enum.MouseBehavior.Default
                    UserInputService.MouseIconEnabled = true
                end)
            end
            return
        end
        MenuInputLock.active = open

        local modal = ensureMenuModal()
        if modal then
            modal.Visible = open
            modal.Modal = open
            -- keep under menu frames so UI stays clickable
            modal.ZIndex = 0
        end

        if open then
            MenuInputLock.savedMouseBehavior = UserInputService.MouseBehavior
            MenuInputLock.savedIconEnabled = UserInputService.MouseIconEnabled
            pcall(function()
                UserInputService.MouseBehavior = Enum.MouseBehavior.Default
                UserInputService.MouseIconEnabled = true
            end)
        else
            pcall(function()
                if MenuInputLock.savedMouseBehavior ~= nil then
                    UserInputService.MouseBehavior = MenuInputLock.savedMouseBehavior
                end
                if MenuInputLock.savedIconEnabled ~= nil then
                    UserInputService.MouseIconEnabled = MenuInputLock.savedIconEnabled
                end
            end)
            MenuInputLock.savedMouseBehavior = nil
            MenuInputLock.savedIconEnabled = nil
        end
    end

    local function isMenuOpen()
        return Library and Library.IsMenuVisible and Library:IsMenuVisible()
    end

    -- wrap Library.Toggle so lock updates immediately
    if type(Library.Toggle) == "function" then
        local origToggle = Library.Toggle
        Library.Toggle = function(...)
            local results = table.pack(origToggle(...))
            task.defer(function()
                setMenuInputLock(isMenuOpen())
            end)
            return table.unpack(results, 1, results.n)
        end
    end

    -- keep lock in sync (config load / external toggles)
    EspRuntime.Connections.MenuInputLock = RunService.RenderStepped:Connect(function()
        local open = isMenuOpen()
        setMenuInputLock(open)
        if open then
            -- hard-lock camera mouse every frame while menu is open
            pcall(function()
                if UserInputService.MouseBehavior ~= Enum.MouseBehavior.Default then
                    UserInputService.MouseBehavior = Enum.MouseBehavior.Default
                end
                if not UserInputService.MouseIconEnabled then
                    UserInputService.MouseIconEnabled = true
                end
            end)
        end
    end)

    -- sink mouse buttons from game-side when menu is open (menu UI still works via Gui)
    EspRuntime.Connections.MenuInputSink = UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if not isMenuOpen() then return end
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.MouseButton2
            or input.UserInputType == Enum.UserInputType.MouseButton3 then
            -- no-op sink marker for other systems; gameProcessed may already be true via Modal
            return
        end
    end)

    setMenuInputLock(isMenuOpen())
end


SaveManager:BuildConfigSection(Tabs.Config)
ThemeManager:ApplyToTab(Tabs.Config)
if HitpartSilent.refreshMethod then HitpartSilent.refreshMethod() end
end)()



-- hooks & ecosystem

-- hide game crosshair when center dot or hide crosshair is enabled
;(function()
local CrosshairHideState = { lastHideState = nil, conns = {}, originals = {} }

local function saveOriginal(child)
    if CrosshairHideState.originals[child] then return end

    local state = {}
    if child:IsA("Frame") then
        state.BackgroundTransparency = child.BackgroundTransparency
    elseif child:IsA("ImageLabel") or child:IsA("ImageButton") then
        state.ImageTransparency = child.ImageTransparency
    elseif child:IsA("TextLabel") or child:IsA("TextButton") then
        state.TextTransparency = child.TextTransparency
        state.TextStrokeTransparency = child.TextStrokeTransparency
    elseif child:IsA("UIStroke") then
        state.Transparency = child.Transparency
        state.Enabled = child.Enabled
    else
        return
    end

    CrosshairHideState.originals[child] = state
end

local function applyCrosshairHide(child)
    if not child or not child.Parent then return end
    saveOriginal(child)

    if child:IsA("Frame") then
        child.BackgroundTransparency = 1
    elseif child:IsA("ImageLabel") or child:IsA("ImageButton") then
        child.ImageTransparency = 1
    elseif child:IsA("TextLabel") or child:IsA("TextButton") then
        child.TextTransparency = 1
        child.TextStrokeTransparency = 1
    elseif child:IsA("UIStroke") then
        child.Transparency = 1
        child.Enabled = false
    end
end

local function restoreCrosshairHide()
    for child, state in pairs(CrosshairHideState.originals) do
        if child and child.Parent then
            pcall(function()
                if child:IsA("Frame") then
                    child.BackgroundTransparency = state.BackgroundTransparency
                elseif child:IsA("ImageLabel") or child:IsA("ImageButton") then
                    child.ImageTransparency = state.ImageTransparency
                elseif child:IsA("TextLabel") or child:IsA("TextButton") then
                    child.TextTransparency = state.TextTransparency
                    child.TextStrokeTransparency = state.TextStrokeTransparency
                elseif child:IsA("UIStroke") then
                    child.Transparency = state.Transparency
                    child.Enabled = state.Enabled
                end
            end)
        end
    end
    table.clear(CrosshairHideState.originals)
end

local function disconnectCrosshairHide()
    for _, conn in ipairs(CrosshairHideState.conns) do
        if conn then conn:Disconnect() end
    end
    CrosshairHideState.conns = {}
end

local function setupCrosshairHide()
    local hideEnabled = (Toggles.MiscHideCrosshair and Toggles.MiscHideCrosshair.Value)
        or (Toggles.MiscCenterDot and Toggles.MiscCenterDot.Value)

    if hideEnabled == CrosshairHideState.lastHideState then return end
    CrosshairHideState.lastHideState = hideEnabled
    disconnectCrosshairHide()

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
    else
        restoreCrosshairHide()
    end
end

getgenv().ValenokRestoreCrosshair = function()
    disconnectCrosshairHide()
    restoreCrosshairHide()
    CrosshairHideState.lastHideState = nil
end

Toggles.MiscHideCrosshair:OnChanged(setupCrosshairHide)
Toggles.MiscCenterDot:OnChanged(setupCrosshairHide)
task.spawn(setupCrosshairHide)
end)()


-- Ambience
Shared.AmbienceState = {
    OrigTime = nil,
    OrigSky = nil,
    OrigAtmColor = nil,
    OrigBrightness = nil,
    OrigShadows = nil,
    SkyObj = nil,
    OrigAmbient = nil,
    OrigOutdoorAmbient = nil,
    OrigTechnology = nil,
    OrigLightingBrightness = nil,
    SaturationCC = nil,
}
;(function()
local Lighting = game:GetService("Lighting")


local function ambienceRestoreSky()
    if Shared.AmbienceState.SkyObj then
        Shared.AmbienceState.SkyObj:Destroy()
        Shared.AmbienceState.SkyObj = nil
    end
    if Shared.AmbienceState.OrigSky then
        pcall(function() Shared.AmbienceState.OrigSky.Parent = Lighting end)
        Shared.AmbienceState.OrigSky = nil
    end
end

pcall(function()
    local folder = workspace:FindFirstChild("ValenokGrenadeAreas")
    if folder then folder:Destroy() end
    local rayIgnore = workspace:FindFirstChild("Ray_Ignore")
    local fires = rayIgnore and rayIgnore:FindFirstChild("Fires")
    if fires then
        for _, desc in ipairs(fires:GetDescendants()) do
            if desc.Name == "ValenokGrenadeArea" then
                pcall(function() desc:Destroy() end)
            end
        end
    end
end)

Shared.AmbienceState.LoopRunning = true
task.spawn(function()
    local lastBetterShadows = nil
    while Shared.AmbienceState.LoopRunning do
            task.wait(0.2)
            if not Shared.AmbienceState.LoopRunning then break end
            -- Better Shadows: ShadowMap (lighter than Future)
            local betterShadows = Toggles.LightingBetterShadows and Toggles.LightingBetterShadows.Value
            if betterShadows ~= lastBetterShadows then
                lastBetterShadows = betterShadows
                if betterShadows then
                    if Shared.AmbienceState.OrigTechnology == nil then
                        pcall(function() Shared.AmbienceState.OrigTechnology = gethiddenproperty(Lighting, "Technology") end)
                    end
                    pcall(function() sethiddenproperty(Lighting, "Technology", Enum.Technology.ShadowMap) end)
                else
                    if Shared.AmbienceState.OrigTechnology ~= nil then
                        pcall(function() sethiddenproperty(Lighting, "Technology", Shared.AmbienceState.OrigTechnology) end)
                        Shared.AmbienceState.OrigTechnology = nil
                    end
                end
            end

            -- Enabled Ambient
            if Toggles.LightingAmbient and Toggles.LightingAmbient.Value then
                if Shared.AmbienceState.OrigAmbient == nil then Shared.AmbienceState.OrigAmbient = Lighting.Ambient end
                Lighting.Ambient = getOptionColor("LightingAmbientColor", Color3.fromRGB(128, 128, 128))
            else
                if Shared.AmbienceState.OrigAmbient ~= nil then
                    Lighting.Ambient = Shared.AmbienceState.OrigAmbient
                    Shared.AmbienceState.OrigAmbient = nil
                end
            end

            -- Brightness (Lighting section)
            local anyLightingOn = (Toggles.LightingBetterShadows and Toggles.LightingBetterShadows.Value)
                or (Toggles.LightingAmbient and Toggles.LightingAmbient.Value)
                or (Toggles.LightingGradient and Toggles.LightingGradient.Value)
                or (Toggles.LightingSaturation and Toggles.LightingSaturation.Value)
            if anyLightingOn then
                local lbright = Options.LightingBrightness and Options.LightingBrightness.Value or 2
                if Shared.AmbienceState.OrigLightingBrightness == nil then Shared.AmbienceState.OrigLightingBrightness = Lighting.Brightness end
                Lighting.Brightness = lbright
            else
                if Shared.AmbienceState.OrigLightingBrightness ~= nil then
                    Lighting.Brightness = Shared.AmbienceState.OrigLightingBrightness
                    Shared.AmbienceState.OrigLightingBrightness = nil
                end
            end

            -- Gradient (overrides Enabled Ambient if both on)
            if Toggles.LightingGradient and Toggles.LightingGradient.Value then
                if Shared.AmbienceState.OrigAmbient == nil then Shared.AmbienceState.OrigAmbient = Lighting.Ambient end
                if Shared.AmbienceState.OrigOutdoorAmbient == nil then Shared.AmbienceState.OrigOutdoorAmbient = Lighting.OutdoorAmbient end
                Lighting.Ambient = getOptionColor("LightingGradientColor", Color3.fromRGB(90, 90, 90))
                Lighting.OutdoorAmbient = getOptionColor("LightingGradientColor2", Color3.fromRGB(150, 150, 150))
            else
                if Shared.AmbienceState.OrigOutdoorAmbient ~= nil then
                    Lighting.OutdoorAmbient = Shared.AmbienceState.OrigOutdoorAmbient
                    Shared.AmbienceState.OrigOutdoorAmbient = nil
                end
            end

            -- Saturation
            if Toggles.LightingSaturation and Toggles.LightingSaturation.Value then
                if not Shared.AmbienceState.SaturationCC or not Shared.AmbienceState.SaturationCC.Parent then
                    local existing = Lighting:FindFirstChild("ValenokSaturationCC")
                    if existing then
                        Shared.AmbienceState.SaturationCC = existing
                    else
                        Shared.AmbienceState.SaturationCC = Instance.new("ColorCorrectionEffect")
                        Shared.AmbienceState.SaturationCC.Name = "ValenokSaturationCC"
                        Shared.AmbienceState.SaturationCC.Parent = Lighting
                    end
                end
                local satVal = Options.LightingSaturationValue and Options.LightingSaturationValue.Value or 10
                Shared.AmbienceState.SaturationCC.Saturation = satVal / 50
            else
                if Shared.AmbienceState.SaturationCC then
                    Shared.AmbienceState.SaturationCC:Destroy()
                    Shared.AmbienceState.SaturationCC = nil
                end
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
    if type(args[4]) ~= "number" or args[4] <= 0 then
        args[4] = 4096
    end
    if Toggles.RagebotAutoPenetration and Toggles.RagebotAutoPenetration.Value then
        args[9] = true -- wallbang
    end
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
    local string_find = string.find
    local table_pack = table.pack

    _oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
        local method = getnamecallmethod()

        if method == "FindPartOnRay" or method == "FindPartOnRayWithIgnoreList" or method == "FindPartOnRayWithWhitelist" then
            if not HitpartSilent.injecting and HitpartSilent.isRay and not getgenv().IgnoreRaycastHook then
                local silentTarget = getgenv().PSilentTarget
                if silentTarget and silentTarget.Parent then
                    local rayArg = ...
                    if typeof(rayArg) == "Ray" then
                        local dir = rayArg.Direction
                        if dir.Magnitude > 0.001 and math.abs(dir.Unit.Y) > 0.85 then
                            return _oldNamecall(self, ...)
                        end
                    end
                    if method == "FindPartOnRayWithWhitelist" then
                        return _oldNamecall(self, ...)
                    end
                    local fakeRay = buildSilentRay(silentTarget)
                    return _oldNamecall(self, fakeRay, select(2, ...))
                end
            end
            return _oldNamecall(self, ...)
        end

        if method == "Raycast" and self == Workspace then
            if not HitpartSilent.injecting and HitpartSilent.isRay and not getgenv().IgnoreRaycastHook then
                local silentTarget = getgenv().PSilentTarget
                if silentTarget and silentTarget.Parent then
                    local origin, direction, params = ...
                    if typeof(origin) == "Vector3" and typeof(direction) == "Vector3" then
                        if typeof(params) == "RaycastParams" and params.FilterType == Enum.RaycastFilterType.Include then
                            return _oldNamecall(self, ...)
                        end
                        if direction.Magnitude > 0.001 and math.abs(direction.Unit.Y) > 0.85 then
                            return _oldNamecall(self, ...)
                        end
                        local _, rayOrigin, predicted = buildSilentRay(silentTarget)
                        local mag = direction.Magnitude
                        if mag < 0.001 then mag = 500 end
                        return _oldNamecall(self, rayOrigin, (predicted - rayOrigin).Unit * mag, select(3, ...))
                    end
                end
            end
            return _oldNamecall(self, ...)
        end

        if method == "SetPrimaryPartCFrame" or method == "PivotTo" or method == "pivotTo" then
            if Toggles.VMOffsetEnable and Toggles.VMOffsetEnable.Value and self.Name ~= "HumanoidRootPart" then
                local isArms = false
                local p = self
                while p do
                    if p.Name == "Arms" then isArms = true; break end
                    p = p.Parent
                end
                if isArms then
                    local cf = ...
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
            return _oldNamecall(self, ...)
        end

        if method == "FireServer" or method == "FireUnreliable" then
            local name = self.Name
            if name == "FallDamage" and Toggles.ExploitNoFallDamage and Toggles.ExploitNoFallDamage.Value then
                return
            end
            if name == "ohnoflames" and Toggles.ExploitNoFireDamage and Toggles.ExploitNoFireDamage.Value then
                return
            end
            -- AC report drops: ammo kick (3), no-recoil Boogers (4), executor error HaIIoooo (5)
            if name == "Boogers" or name == "HaIIoooooooooooo" or name == "Rem3" or name == "ewrtsjkwrslk" then
                return
            end
            if name == "ParticleRemote" then
                local a1 = ...
                if type(a1) == "table" and a1[1] == "kick" then
                    return
                end
            end
            if name == "ControlTurn" then

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
                return _oldNamecall(self, ...)
            end
            if name == "HitParl" then
                local args = table_pack(...)
                local hitPart = args[1]
                local silentTarget = getgenv().PSilentTarget
                local silentActive = silentTarget and silentTarget.Parent ~= nil
                if not HitpartSilent.injecting and silentActive then
                    args = applySilentHitParl(args)
                    hitPart = args[1]
                end
                if not hitPart or not hitPart.Parent then
                    return _oldNamecall(self, unpack(args, 1, args.n))
                end

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
                            if string_find(partName, "Head") then partName = "Head" end
                            local hitChar = hitPart and hitPart.Parent
                            local hitPlayer = hitChar and Players:GetPlayerFromCharacter(hitChar)
                            local hitName = hitPlayer and hitPlayer.Name or "?"
                            Shared.pushHitLog("Hit " .. hitName .. " in " .. partName)
                        end
                    end)
                end)
                return _oldNamecall(self, unpack(args, 1, args.n))
            end

            if name == "Trail" then
                if Toggles.MiscBulletTracer and Toggles.MiscBulletTracer.Value then
                    local args = table_pack(...)
                    task.spawn(function()
                        pcall(function()
                            local a1, a2 = args[1], args[2]
                            local startPos = nil
                            if typeof(a1) == "CFrame" then
                                startPos = a1.Position
                            elseif typeof(a1) == "Vector3" then
                                startPos = a1
                            elseif typeof(a1) == "Instance" and a1:IsA("BasePart") then
                                startPos = a1.Position
                            end
                            local endPos = typeof(a2) == "Vector3" and a2 or nil
                            if startPos and endPos then
                                drawBulletTracer(startPos, endPos)
                            end
                        end)
                    end)
                end
                return _oldNamecall(self, ...)
            end

            if name == "ReplicateShot" then
                pcall(function()
                    if Toggles.PeekAssistEnable and Toggles.PeekAssistEnable.Value then
                        peekAssistOnShot()
                    end
                end)
                return _oldNamecall(self, ...)
            end

            return _oldNamecall(self, ...)
        end

        if method == "LoadAnimation" then
            if Toggles.MiscSlideWalk and Toggles.MiscSlideWalk.Value then
                local animArg = ...
                if typeof(animArg) == "Instance" and (animArg.Name == "RunAnim" or animArg.Name == "JumpAnim") then
                    return
                end
            end
            return _oldNamecall(self, ...)
        end

        return _oldNamecall(self, ...)
    end)
end)
end)()


-- __newindex hook for name spoofer
_oldNewindex = nil

restoreNewindexHook = function()
    pcall(function()
        if _oldNewindex then
            hookmetamethod(game, "__newindex", _oldNewindex)
            _oldNewindex = nil
        end
    end)
end

pcall(function()
    _oldNewindex = hookmetamethod(game, "__newindex", function(obj, prop, value)
        if prop ~= "Text" and prop ~= "text" then
            return _oldNewindex(obj, prop, value)
        end
        if not (Toggles.MiscSpoofName and Toggles.MiscSpoofName.Value) then
            return _oldNewindex(obj, prop, value)
        end
        if type(value) ~= "string" or checkcaller() then
            return _oldNewindex(obj, prop, value)
        end
        local spoofName = Options.MiscSpoofedName and Options.MiscSpoofedName.Value
        if not spoofName or spoofName == "" then
            return _oldNewindex(obj, prop, value)
        end
        if not (obj:IsA("TextLabel") or obj:IsA("TextBox")) then
            return _oldNewindex(obj, prop, value)
        end
        local playerName = LocalPlayer.Name
        if playerName and playerName ~= "" and string.find(value, playerName, 1, true) then
            value = string.gsub(value, playerName, spoofName, 1)
        end
        local displayName = LocalPlayer.DisplayName
        if displayName and displayName ~= "" and displayName ~= playerName and string.find(value, displayName, 1, true) then
            value = string.gsub(value, displayName, spoofName, 1)
        end
        return _oldNewindex(obj, prop, value)
    end)
end)


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
Shared.ensureFovCircles()
getgenv().ValenokFovCircles = { AimRuntime.AimFovCircle, AimRuntime.RageFovCircle }


_hitSoundObj = Instance.new("Sound")
_hitSoundObj.Parent = workspace

-- unload
unloadValenok = function()
    restoreNamecallHook()
    restoreNewindexHook()
    getgenv().PSilentTarget = nil
    getgenv().IgnoreRaycastHook = false

    if Shared.cleanupNameSpoofer then
        pcall(Shared.cleanupNameSpoofer)
        Shared.cleanupNameSpoofer = nil
    end
    if Shared.cleanupViewModelVisuals then
        pcall(Shared.cleanupViewModelVisuals)
    end

    if Shared.AmbienceState then
        Shared.AmbienceState.LoopRunning = false
    end

    -- Restore original skybox
    if Shared.SkyboxState.guardConn then Shared.SkyboxState.guardConn:Disconnect(); Shared.SkyboxState.guardConn = nil end
    if Shared.SkyboxState.customSky then
        pcall(function() Shared.SkyboxState.customSky:Destroy() end)
        Shared.SkyboxState.customSky = nil
    end
    if Shared.SkyboxState.originalSky and not Shared.SkyboxState.originalSky.Parent then
        pcall(function() Shared.SkyboxState.originalSky.Parent = game:GetService('Lighting') end)
    end

    if HitMarkerState.HeartbeatConn then
        HitMarkerState.HeartbeatConn:Disconnect()
        HitMarkerState.HeartbeatConn = nil
    end

    if SC.Models then pcall(function() SC.Models:Destroy() end); SC.Models = nil end

    for _, Connection in pairs(EspRuntime.Connections) do
        pcall(function() Connection:Disconnect() end)
    end
    table.clear(EspRuntime.Connections)

    for _, c in ipairs({ AimRuntime.AimFovCircle, AimRuntime.RageFovCircle }) do
        pcall(function() c.Visible = false; c:Remove() end)
    end
    AimRuntime.AimFovCircle = nil
    AimRuntime.RageFovCircle = nil

    if Shared.CrosshairState.Circle then
        pcall(function() Shared.CrosshairState.Circle.Visible = false; Shared.CrosshairState.Circle:Remove() end)
        Shared.CrosshairState.Circle = nil
    end
    if Shared.CrosshairState.Outline then
        pcall(function() Shared.CrosshairState.Outline.Visible = false; Shared.CrosshairState.Outline:Remove() end)
        Shared.CrosshairState.Outline = nil
    end
    if Shared.CrosshairState.StateText then
        pcall(function() Shared.CrosshairState.StateText.Visible = false; Shared.CrosshairState.StateText:Remove() end)
        Shared.CrosshairState.StateText = nil
    end
    Shared.CrosshairState.Created = false

    if HitLogGui then
        pcall(function() HitLogGui:Destroy() end)
        HitLogGui = nil
        HitLogContainer = nil
        HitLogNotifCount = 0
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

    applyNoScope(false)

    local pg = getPlayerGui()
    local blnd = pg and pg:FindFirstChild("Blnd")
    if blnd then blnd.Enabled = true end

    for Player, DrawingSet in pairs(EspRuntime.Drawings) do
        EspRuntime.RemoveDrawingValue(DrawingSet)
        EspRuntime.Drawings[Player] = nil
    end

    for item, text in pairs(EspRuntime.ItemDrawings) do
        pcall(function() text.Visible = false; text:Remove() end)
    end
    EspRuntime.ItemDrawings = {}

    clearHitChamsFolder()
    for player in pairs(EspRuntime.Chams) do
        Shared.removePlayerChams(player)
    end
    for player in pairs(EspRuntime.Highlights) do
        Shared.removeHighlight(player)
    end
    table.clear(EspPlayerCache)
    if Shared.NoclipState then
        Shared.NoclipState.Saved = {}
        Shared.NoclipState.Parts = {}
        Shared.NoclipState.Character = nil
    end

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
        RunService:UnbindFromRenderStep("ValenokAntiAim")
    end)

    pcall(function()
        if Shared.unbindFovChanger then Shared.unbindFovChanger() end
        local cam = getCamera()
        if cam then cam.FieldOfView = 80 end
    end)

    pcall(function()
        if getgenv().HUD_OriginalState then
            for inst, state in pairs(getgenv().HUD_OriginalState) do
                if inst and inst.Parent then
                    if inst:IsA("GuiObject") then
                        inst.Visible = state.Visible
                        inst.BackgroundTransparency = state.BackgroundTransparency
                        inst.BorderSizePixel = state.BorderSizePixel
                        if state.ImageTransparency then inst.ImageTransparency = state.ImageTransparency end
                        if state.TextTransparency then inst.TextTransparency = state.TextTransparency end
                    elseif inst:IsA("UIStroke") then
                        inst.Enabled = state.Enabled
                        inst.Transparency = state.Transparency
                    end
                end
            end
        end
        if getgenv().HUD_Connections then
            for _, data in pairs(getgenv().HUD_Connections) do
                if data.Connection then data.Connection:Disconnect() end
                if data.PropConns then
                    for _, pConn in pairs(data.PropConns) do pConn:Disconnect() end
                end
            end
        end
        getgenv().HUD_Connections = nil
        getgenv().HUD_OriginalState = nil
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
        DelayUntil = 0,
        DelayActive = false,
        IsFiring = false,
        LastFire = 0,
        LastUpdate = 0,
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

    if Shared.AmbienceSavedLighting then
        pcall(function()
            local Lighting = game:GetService('Lighting')
            Lighting.ClockTime = Shared.AmbienceSavedLighting.ClockTime
            Lighting.GlobalShadows = Shared.AmbienceSavedLighting.GlobalShadows
            Lighting.Brightness = Shared.AmbienceSavedLighting.Brightness
            Lighting.Ambient = Shared.AmbienceSavedLighting.Ambient
            Lighting.OutdoorAmbient = Shared.AmbienceSavedLighting.OutdoorAmbient
            Lighting.ColorShift_Bottom = Shared.AmbienceSavedLighting.ColorShift_Bottom
            Lighting.ColorShift_Top = Shared.AmbienceSavedLighting.ColorShift_Top
            if Shared.AmbienceSavedLighting.Skybox and not Shared.AmbienceSavedLighting.Skybox.Parent then
                Shared.AmbienceSavedLighting.Skybox.Parent = Lighting
            end
            -- restore sky textures
            if Shared.AmbienceSavedLighting.SkyTextures and Shared.AmbienceSavedLighting.Skybox then
                local t = Shared.AmbienceSavedLighting.SkyTextures
                local sky = Shared.AmbienceSavedLighting.Skybox
                sky.SkyboxBk = t.SkyboxBk
                sky.SkyboxDn = t.SkyboxDn
                sky.SkyboxFt = t.SkyboxFt
                sky.SkyboxLf = t.SkyboxLf
                sky.SkyboxRt = t.SkyboxRt
                sky.SkyboxUp = t.SkyboxUp
                sky.StarCount = t.StarCount
                sky.SunTextureId = t.SunTextureId
                sky.MoonTextureId = t.MoonTextureId
            end
            -- restore fog
            if Shared.AmbienceSavedLighting.FogColor then
                Lighting.FogColor = Shared.AmbienceSavedLighting.FogColor
                Lighting.FogEnd = Shared.AmbienceSavedLighting.FogEnd
            end
        end)
        Shared.AmbienceSavedLighting = nil
    end


    -- restore game crosshair visibility
    pcall(function()
        if Shared.CrosshairState.Circle then Shared.CrosshairState.Circle.Visible = false; Shared.CrosshairState.Circle:Remove() end
        if Shared.CrosshairState.Outline then Shared.CrosshairState.Outline.Visible = false; Shared.CrosshairState.Outline:Remove() end
        if Shared.CrosshairState.StateText then Shared.CrosshairState.StateText.Visible = false; Shared.CrosshairState.StateText:Remove() end
        Shared.CrosshairState.Circle = nil
        Shared.CrosshairState.Outline = nil
        Shared.CrosshairState.StateText = nil
        Shared.CrosshairState.Created = false
    end)

    -- restore game crosshair
    pcall(function()
        if getgenv().ValenokRestoreCrosshair then
            getgenv().ValenokRestoreCrosshair()
        end
    end)

    -- cleanup GrenadeRuntime
    pcall(function()
        if GrenadeRuntime and GrenadeRuntime.Folder then
            GrenadeRuntime.Folder:Destroy()
        end
    end)

    -- cleanup Shared.AmbienceState (new runtime)
    pcall(function()
        local LightingSvc = game:GetService("Lighting")
        if Shared.AmbienceState then
            if Shared.AmbienceState.OrigTime ~= nil then LightingSvc.ClockTime = Shared.AmbienceState.OrigTime end
            if Shared.AmbienceState.OrigShadows ~= nil then LightingSvc.GlobalShadows = Shared.AmbienceState.OrigShadows end
            if Shared.AmbienceState.OrigBrightness ~= nil then LightingSvc.Brightness = Shared.AmbienceState.OrigBrightness end
            if Shared.AmbienceState.OrigAtmColor ~= nil then
                local atm = LightingSvc:FindFirstChildOfClass("Atmosphere")
                if atm then atm.Color = Shared.AmbienceState.OrigAtmColor end
            end
            local skyCC = LightingSvc:FindFirstChild("ValenokSkyCC")
            if skyCC then skyCC:Destroy() end
            local skyColorCC = LightingSvc:FindFirstChild("ValenokSkyColorCC")
            if skyColorCC then skyColorCC:Destroy() end
            if Shared.AmbienceState.SkyObj then
                pcall(function() Shared.AmbienceState.SkyObj:Destroy() end)
                Shared.AmbienceState.SkyObj = nil
            end
            if Shared.AmbienceState.OrigSky then
                pcall(function() Shared.AmbienceState.OrigSky.Parent = LightingSvc end)
                Shared.AmbienceState.OrigSky = nil
            end
            -- cleanup Lighting section
            if Shared.AmbienceState.OrigTechnology ~= nil then
                pcall(function() sethiddenproperty(LightingSvc, "Technology", Shared.AmbienceState.OrigTechnology) end)
            end
            if Shared.AmbienceState.OrigAmbient ~= nil then
                LightingSvc.Ambient = Shared.AmbienceState.OrigAmbient
            end
            if Shared.AmbienceState.OrigOutdoorAmbient ~= nil then
                LightingSvc.OutdoorAmbient = Shared.AmbienceState.OrigOutdoorAmbient
            end
            if Shared.AmbienceState.OrigLightingBrightness ~= nil then
                LightingSvc.Brightness = Shared.AmbienceState.OrigLightingBrightness
            end
            local satCC = LightingSvc:FindFirstChild("ValenokSaturationCC")
            if satCC then satCC:Destroy() end
        end
    end)

    if Shared.SpeedHackState and Shared.SpeedHackState.Conn then
        Shared.SpeedHackState.Conn:Disconnect()
        Shared.SpeedHackState.Conn = nil
    end
    pcall(Shared.restoreSpeedHackOriginal)

    if Shared.AutoJumpState and Shared.AutoJumpState.Conn then
        Shared.AutoJumpState.Conn:Disconnect()
        Shared.AutoJumpState.Conn = nil
    end
    if Shared.AutoCrouchState and Shared.AutoCrouchState.Conn then
        Shared.AutoCrouchState.Conn:Disconnect()
        Shared.AutoCrouchState.Conn = nil
    end
    pcall(function() VirtualInputManager:SendKeyEvent(false, MoveUtil.MOVE_KEY_CTRL, false, game) end)

    if Shared.FakeDuckState then
        if Shared.FakeDuckState.Conn then
            Shared.FakeDuckState.Conn:Disconnect()
            Shared.FakeDuckState.Conn = nil
        end
        if Shared.FakeDuckState.Track then
            pcall(function() Shared.FakeDuckState.Track:Stop() end)
            Shared.FakeDuckState.Track = nil
        end
        Shared.FakeDuckState.Humanoid = nil
    end

    if Shared.BhopState and Shared.BhopState.Conn then
        Shared.BhopState.Conn:Disconnect()
        Shared.BhopState.Conn = nil
    end
    pcall(function()
        local hum = MoveUtil.getLocalHumanoid()
        if hum then hum.WalkSpeed = CONSTANTS.DEFAULT_WALK_SPEED end
    end)

    if Shared.LegitBhopState and Shared.LegitBhopState.Conn then
        Shared.LegitBhopState.Conn:Disconnect()
        Shared.LegitBhopState.Conn = nil
    end
    pcall(function()
        local hum = MoveUtil.getLocalHumanoid()
        if hum then hum.WalkSpeed = CONSTANTS.DEFAULT_WALK_SPEED end
    end)

    if Shared.NoclipState and Shared.NoclipState.Conn then
        Shared.NoclipState.Conn:Disconnect()
        Shared.NoclipState.Conn = nil
    end
    pcall(Shared.restoreNoclipParts)

    if Shared.FlyState and Shared.FlyState.Conn then
        Shared.FlyState.Conn:Disconnect()
        Shared.FlyState.Conn = nil
    end
    pcall(Shared.restoreFlyPhysics)

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
        Shared.removeDrawingSet(player)
        Shared.removePlayerChams(player)
        EspRuntime.Drawings[player] = nil
        invalidateEspPlayerCache(player)
    end)
end)

EspRuntime.Connections.NoclipCharAdded = LocalPlayer.CharacterAdded:Connect(function()
    pcall(function()
        if Shared.NoclipState then
            Shared.NoclipState.Saved = {}
            Shared.clearNoclipRuntime()
        end
        invalidateEspPlayerCache(LocalPlayer)
    end)
end)

EspRuntime.Connections.PlayerCharAdded = Players.PlayerAdded:Connect(function(player)
    player.CharacterAdded:Connect(function()
        invalidateEspPlayerCache(player)
    end)
end)
for _, player in ipairs(Players:GetPlayers()) do
    if player ~= LocalPlayer then
        EspRuntime.Connections["CharAdded_" .. player.UserId] = player.CharacterAdded:Connect(function()
            invalidateEspPlayerCache(player)
        end)
    end
end


-- main loop: heavy work throttled to 6ms (~167 Hz) so high FPS doesn't multiply cost
local MAIN_UPDATE_INTERVAL = 0.0005
local LoopState = {
    espUpdate = 0,
    wFps = 0,
    wFrames = 0,
    wLastUpdate = 0,
    removalsCheck = 0,
    vmUpdate = 0,
    miscUpdate = 0,
    mainUpdate = 0,
    mainDt = 0,
}

local function updateRagebot()
    local myChar = LocalPlayer.Character
    local myHum = myChar and myChar:FindFirstChildOfClass("Humanoid")
    local isAlive = myHum and myHum.Health > 0 and myChar.Parent

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
        RuntimePack.silentActive = keybindActive
    else
        RuntimePack.silentActive = false
    end

    if RuntimePack.silentActive then
        local menuOpen = Library and Library.IsMenuVisible and Library:IsMenuVisible()
        local autoFire = Toggles.RagebotAutoFire and Toggles.RagebotAutoFire.Value and not menuOpen
        local silentTarget = getNearestSilentTarget()
        getgenv().PSilentTarget = silentTarget

        if autoFire and silentTarget and silentTarget.Parent then
            local fireNow = tick()
            local rate = HitpartSilent.getFireRate and HitpartSilent.getFireRate() or 0.1
            if fireNow - HitpartSilent.lastFire >= rate then
                HitpartSilent.lastFire = fireNow
                local hitpartMode = HitpartSilent.isHitpartMethod and HitpartSilent.isHitpartMethod()
                fireWeapShot()
                if hitpartMode then
                    HitpartSilent.fire(silentTarget)
                end
            end
        end
    else
        getgenv().PSilentTarget = nil
    end

    if isAlive then
        updateAutoScope()
    elseif AutoScopeState.lastWant then
        setADS(getCachedClient(), false)
        AutoScopeState.lastWant = false
    end
end

EspRuntime.Connections.RenderStepped = RunService.RenderStepped:Connect(function(dt)
    LoopState.wFrames = LoopState.wFrames + 1
    LoopState.mainDt = LoopState.mainDt + (dt or 0)

    local rageOk, rageErr = pcall(updateRagebot)
    if not rageOk then warn("[Valenok] Ragebot:", rageErr) end

    local now = tick()
    if now - LoopState.mainUpdate < MAIN_UPDATE_INTERVAL then
        return
    end

    local stepDt = LoopState.mainDt
    LoopState.mainDt = 0
    LoopState.mainUpdate = now

    local ok, err = pcall(function()
        local myChar = LocalPlayer.Character
        local myHum = myChar and myChar:FindFirstChildOfClass("Humanoid")
        local isAlive = myHum and myHum.Health > 0 and myChar.Parent

        if now - LoopState.removalsCheck >= 2 then
            LoopState.removalsCheck = now
            if Toggles.RemovalsNoScope and Toggles.RemovalsNoScope.Value then updateNoScope() end
            if Toggles.RemovalsNoFlash and Toggles.RemovalsNoFlash.Value then updateNoFlash() end
            if Toggles.RCSEnable and Toggles.RCSEnable.Value then updateRCS() end
        end

        Shared.updateFovCircle()

        if isAlive then
            updateAimBot(stepDt)
        end

        updateCrosshair()

        updateEspFrameCache()
        local plist = Players:GetPlayers()
        for i = 1, #plist do
            Shared.updatePlayerEsp(plist[i])
        end
        Shared.updateItemEsp()

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
        if Shared.MiscState.ambienceDirty then
            Shared.MiscState.ambienceDirty = false
            Shared.updateAmbience()
        end
        if isAlive then
            updateTriggerbot()
            updateAntiAim()
            updateGrenadePrediction(stepDt)
            updatePeekAssist()
        end

        local vmAnyEnabled = (Toggles.VMWeaponChams and Toggles.VMWeaponChams.Value)
            or (Toggles.VMArmChams and Toggles.VMArmChams.Value)
            or (Toggles.VMRemoveSleeves and Toggles.VMRemoveSleeves.Value)
            or (Toggles.VMRemoveGloves and Toggles.VMRemoveGloves.Value)
        if vmAnyEnabled then
            updateViewModelVisuals()
        end


        if now - LoopState.miscUpdate >= 2 then
            LoopState.miscUpdate = now
            if Toggles.MiscRemoveRadio and Toggles.MiscRemoveRadio.Value then Shared.applyRemoveRadio() end
        end
    end)
    if not ok then warn("[Valenok] RenderStepped:", err) end
end)


-- Name spoofer: event-driven cache (no full CoreGui:GetDescendants)
;(function()
    local CoreGui = game:GetService("CoreGui")
    local cachedObjects = {}
    local trackedGuis = {}
    local guiConns = {}
    local rootConns = {}

    local function trackText(obj)
        if not obj or cachedObjects[obj] then return end
        if obj:IsA("TextLabel") or obj:IsA("TextBox") then
            cachedObjects[obj] = true
        end
    end

    local function untrackText(obj)
        if obj then cachedObjects[obj] = nil end
    end

    local function scanGui(gui)
        if not gui then return end
        pcall(function()
            for _, v in ipairs(gui:GetDescendants()) do
                trackText(v)
            end
        end)
    end

    local function untrackGui(gui)
        local conns = guiConns[gui]
        if conns then
            for i = 1, #conns do
                pcall(function() conns[i]:Disconnect() end)
            end
            guiConns[gui] = nil
        end
        trackedGuis[gui] = nil
        pcall(function()
            for _, v in ipairs(gui:GetDescendants()) do
                untrackText(v)
            end
        end)
    end

    local function trackGui(gui)
        if not gui or trackedGuis[gui] then return end
        if not gui:IsA("LayerCollector") and not gui:IsA("ScreenGui") and not gui:IsA("BillboardGui") and not gui:IsA("SurfaceGui") then
            return
        end
        trackedGuis[gui] = true
        scanGui(gui)
        local conns = {}
        conns[#conns + 1] = gui.DescendantAdded:Connect(function(desc)
            trackText(desc)
        end)
        conns[#conns + 1] = gui.DescendantRemoving:Connect(function(desc)
            untrackText(desc)
        end)
        conns[#conns + 1] = gui.AncestryChanged:Connect(function(_, parent)
            if not parent then untrackGui(gui) end
        end)
        guiConns[gui] = conns
    end

    local function watchRoot(root)
        if not root or rootConns[root] then return end
        for _, child in ipairs(root:GetChildren()) do
            trackGui(child)
        end
        rootConns[root] = root.ChildAdded:Connect(function(child)
            trackGui(child)
        end)
    end

    local function bootstrap()
        pcall(function() watchRoot(CoreGui) end)
        local pg = LocalPlayer:FindFirstChild("PlayerGui")
        if pg then
            watchRoot(pg)
        else
            EspRuntime.Connections.SpoofPlayerGuiWait = LocalPlayer.ChildAdded:Connect(function(child)
                if child.Name == "PlayerGui" or child:IsA("PlayerGui") then
                    watchRoot(child)
                end
            end)
        end
    end

    local function applySpoof()
        if not Toggles.MiscSpoofName or not Toggles.MiscSpoofName.Value then return end
        local spoofName = Options.MiscSpoofedName and Options.MiscSpoofedName.Value or ""
        if spoofName == "" then return end
        local playerName = LocalPlayer.Name
        local displayName = LocalPlayer.DisplayName
        for obj in pairs(cachedObjects) do
            if not obj or not obj.Parent then
                cachedObjects[obj] = nil
            else
                local ok, text = pcall(function() return obj.Text end)
                if ok and type(text) == "string" then
                    local newText = text
                    if playerName ~= "" and string.find(newText, playerName, 1, true) then
                        newText = string.gsub(newText, playerName, spoofName, 1)
                    end
                    if displayName and displayName ~= "" and displayName ~= playerName and string.find(newText, displayName, 1, true) then
                        newText = string.gsub(newText, displayName, spoofName, 1)
                    end
                    if newText ~= text then
                        pcall(function() obj.Text = newText end)
                    end
                else
                    cachedObjects[obj] = nil
                end
            end
        end
    end

    local spoofRunning = true
    local spoofThread = nil

    Shared.cleanupNameSpoofer = function()
        spoofRunning = false
        if spoofThread then
            pcall(function() task.cancel(spoofThread) end)
            spoofThread = nil
        end
        for root, conn in pairs(rootConns) do
            pcall(function() conn:Disconnect() end)
            rootConns[root] = nil
        end
        for gui in pairs(trackedGuis) do
            untrackGui(gui)
        end
        table.clear(cachedObjects)
        table.clear(trackedGuis)
        table.clear(guiConns)
        table.clear(rootConns)
    end

    bootstrap()
    spoofThread = task.spawn(function()
        while spoofRunning do
            task.wait(1)
            if not spoofRunning then break end
            applySpoof()
        end
    end)
end)()


-- kill all heartbeat
local _killAllLastRun = 0
EspRuntime.Connections.KillAllHeartbeat = RunService.Heartbeat:Connect(function()
    pcall(function()
        local now = tick()
        if now - _killAllLastRun < 0.1 then return end
        _killAllLastRun = now
        updateKillAll()
        updateInfAmmo()
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
end)()  Library:GiveSignal(Library.KeybindFrame:GetPropertyChangedSignal('Position'):Connect(saveUiPositions))
    end
end)()
