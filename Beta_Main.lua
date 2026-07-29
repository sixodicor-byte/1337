-- fps

local Environment = type(getgenv) == 'function' and getgenv() or _G
    if type(Environment.ValenokFPSBoostUnload) == 'function' then
        pcall(Environment.ValenokFPSBoostUnload)
    end
    
    local Lighting = game:GetService('Lighting')
    local Workspace = game:GetService('Workspace')
    local Terrain = Workspace.Terrain
    local FastFlagSetter = type(setfflag) == 'function' and setfflag
        or rawget(Environment, 'setfflag')
        or rawget(_G, 'setfflag')
    local SetFpsCap = type(setfpscap) == 'function' and setfpscap
        or rawget(Environment, 'setfpscap')
        or rawget(_G, 'setfpscap')
    local AlwaysDisabledClasses = {
        BlurEffect = true,
        DepthOfFieldEffect = true,
    }
    local ParticleClasses = {
        ParticleEmitter = true,
        Trail = true,
        Beam = true,
        Fire = true,
        Smoke = true,
        Sparkles = true,
    }
    local LightClasses = {
        PointLight = true,
        SpotLight = true,
        SurfaceLight = true,
    }
    
    local Config = {
        FPSCap = 360,
        QualityLevel = 15,
        DisableGlobalShadows = true,
        DisableLightShadows = true,
        DisableParticles = true,
        DisableBloom = true,
        DisableSunRays = true,
        DisableWaterEffects = true,
        UseTaskSchedulerFlag = true,
    }
    
    local State = {
        unloaded = false,
        connections = {},
        enabled = setmetatable({}, { __mode = 'k' }),
        lightShadows = setmetatable({}, { __mode = 'k' }),
        lighting = {},
        terrain = {},
        rendering = {},
        gameSettings = {},
    }
    
    local function remember(object, property, storage)
        if storage[property] ~= nil then
            return true
        end
        local ok, value = pcall(function()
            return object[property]
        end)
        if ok then
            storage[property] = value
        end
        return ok
    end
    
    local function setProperty(object, property, value, storage)
        if remember(object, property, storage) then
            pcall(function()
                object[property] = value
            end)
        end
    end
    
    local function disable(object)
        if State.enabled[object] == nil then
            local ok, enabled = pcall(function()
                return object.Enabled
            end)
            if not ok then
                return
            end
            State.enabled[object] = enabled and 1 or 0
        end
        pcall(function()
            object.Enabled = false
        end)
    end
    
    local function disableLightShadows(light)
        if State.lightShadows[light] == nil then
            local ok, shadows = pcall(function()
                return light.Shadows
            end)
            if not ok then
                return
            end
            State.lightShadows[light] = shadows and 1 or 0
        end
        pcall(function()
            light.Shadows = false
        end)
    end
    
    local function optimizeInstance(instance)
        local parent = instance.Parent
        if parent then
            local root = instance
            while root.Parent and root.Parent ~= Workspace do
                root = root.Parent
            end
            if root.Name == 'Debris' then
                return
            end
            if root:FindFirstChildOfClass('Humanoid') then
                return
            end
        end

        local className = instance.ClassName
        if AlwaysDisabledClasses[className] then
            disable(instance)
            return
        end
    
        if Config.DisableBloom and className == 'BloomEffect' then
            disable(instance)
            return
        end
        if Config.DisableSunRays and className == 'SunRaysEffect' then
            disable(instance)
            return
        end
    
        if Config.DisableParticles and ParticleClasses[className] then
            disable(instance)
            return
        end
    
        if Config.DisableLightShadows and LightClasses[className] then
            disableLightShadows(instance)
        end
    end
    
    local function optimizeTree(root)
        optimizeInstance(root)
        for _, instance in ipairs(root:GetDescendants()) do
            optimizeInstance(instance)
        end
    end
    
    local function trySetFastFlag(name, value)
        if type(FastFlagSetter) == 'function' then
            pcall(FastFlagSetter, name, tostring(value))
        end
    end
    
    local function applyQualityLevel()
        if type(Config.QualityLevel) ~= 'number' then
            return
        end
    
        local level = math.clamp(math.floor(Config.QualityLevel), 1, 21)
        local enumName = string.format('Level%02d', level)
        local quality = Enum.QualityLevel[enumName]
        local savedQuality
        pcall(function()
            savedQuality = Enum.SavedQualitySetting['QualityLevel' .. level]
        end)
    
        local ok, rendering = pcall(function()
            return settings().Rendering
        end)
        if ok and rendering and quality then
            setProperty(rendering, 'QualityLevel', quality, State.rendering)
        end
    
        local gameSettingsOk, gameSettings = pcall(function()
            return UserSettings():GetService('UserGameSettings')
        end)
        if gameSettingsOk and gameSettings and savedQuality then
            setProperty(gameSettings, 'SavedQualityLevel', savedQuality, State.gameSettings)
        end
    end
    
    local function apply()
        if type(SetFpsCap) == 'function' then
            pcall(SetFpsCap, Config.FPSCap)
        end
        if Config.UseTaskSchedulerFlag then
            trySetFastFlag('DFIntTaskSchedulerTargetFps', Config.FPSCap)
            trySetFastFlag('FIntTaskSchedulerTargetFps', Config.FPSCap)
        end
    
        applyQualityLevel()
    
        if Config.DisableGlobalShadows then
            setProperty(Lighting, 'GlobalShadows', false, State.lighting)
        end
        if Config.DisableWaterEffects and Terrain then
            setProperty(Terrain, 'WaterWaveSize', 0, State.terrain)
            setProperty(Terrain, 'WaterWaveSpeed', 0, State.terrain)
            setProperty(Terrain, 'WaterReflectance', 0, State.terrain)
        end
    
        optimizeTree(Lighting)
        optimizeTree(Workspace)
    
        State.connections[#State.connections + 1] = Lighting.DescendantAdded:Connect(optimizeInstance)
        State.connections[#State.connections + 1] = Workspace.DescendantAdded:Connect(optimizeInstance)
        State.connections[#State.connections + 1] = Workspace:GetPropertyChangedSignal('CurrentCamera'):Connect(function()
            local camera = Workspace.CurrentCamera
            if camera then
                optimizeTree(camera)
            end
        end)
    end
    
    local function restoreProperties(object, storage)
        for property, value in pairs(storage) do
            pcall(function()
                object[property] = value
            end)
        end
    end
    
    local function unload()
        if State.unloaded then
            return
        end
        State.unloaded = true
    
        for i = 1, #State.connections do
            State.connections[i]:Disconnect()
        end
        table.clear(State.connections)
    
        for instance, wasEnabled in pairs(State.enabled) do
            if instance.Parent then
                pcall(function()
                    instance.Enabled = wasEnabled == 1
                end)
            end
        end
        for light, hadShadows in pairs(State.lightShadows) do
            if light.Parent then
                pcall(function()
                    light.Shadows = hadShadows == 1
                end)
            end
        end
    
        restoreProperties(Lighting, State.lighting)
        if Terrain then
            restoreProperties(Terrain, State.terrain)
        end
    
        local ok, rendering = pcall(function()
            return settings().Rendering
        end)
        if ok and rendering then
            restoreProperties(rendering, State.rendering)
        end
        local gameSettingsOk, gameSettings = pcall(function()
            return UserSettings():GetService('UserGameSettings')
        end)
        if gameSettingsOk and gameSettings then
            restoreProperties(gameSettings, State.gameSettings)
        end
    
        if Environment.ValenokFPSBoostUnload == unload then
            Environment.ValenokFPSBoostUnload = nil
        end
    end
    
    Environment.ValenokFPSBoostUnload = unload
    apply()
    
    local Library = loadstring(game:HttpGet('https://raw.githubusercontent.com/sixodicor-byte/1337/refs/heads/main/NewLib.lua'))()
    
    local PlayersService = game:GetService('Players')
    local RunService = game:GetService('RunService')
    local UserInputService = game:GetService('UserInputService')
    local ReplicatedStorage = game:GetService('ReplicatedStorage')
    local DebrisService = game:GetService('Debris')
    local SoundService = game:GetService('SoundService')
    local LocalPlayer = PlayersService.LocalPlayer
    local HandleHitParl
    local HandleKillEffect
    local HandleRageHitParl
    local PlayHitSound
    local HitLogCleanup
    local KillEffectCleanup
    local NamecallCleanup
    local SharedNamecallState
    local ScriptEnvironment
    local GameRefs = {
        Events = nil,
        Weapons = nil,
        Debris = nil,
        RayIgnore = nil,
        Map = nil,
        MapClips = nil,
        MapSpawnPoints = nil,
    }

    local function GetOnceRef(key, finder)
        local cached = GameRefs[key]
        if cached ~= nil then
            if typeof(cached) == 'Instance' and cached.Parent then
                return cached
            end
            return nil
        end
        local found = finder()
        if found then
            GameRefs[key] = found
            return found
        end
        return nil
    end

    local function GetRayIgnoreRoot()
        return GetOnceRef('RayIgnore', function()
            return workspace:FindFirstChild('Ray_Ignore')
        end)
    end

    local function GetEventsFolder()
        return GetOnceRef('Events', function()
            return ReplicatedStorage:FindFirstChild('Events')
        end)
    end

    local function GetWeaponsFolder()
        return GetOnceRef('Weapons', function()
            return ReplicatedStorage:FindFirstChild('Weapons')
        end)
    end

    local function GetDebrisRoot()
        return GetOnceRef('Debris', function()
            return workspace:FindFirstChild('Debris')
        end)
    end

    local function GetMapRoot()
        return GetOnceRef('Map', function()
            return workspace:FindFirstChild('Map')
        end)
    end

    local function GetMapClips()
        local cached = GameRefs.MapClips
        if cached ~= nil then
            return typeof(cached) == 'Instance' and cached.Parent and cached or nil
        end
        local map = GetMapRoot()
        if not map then
            return nil
        end
        local clips = map:FindFirstChild('Clips')
        if clips then
            GameRefs.MapClips = clips
        end
        return clips
    end

    local function GetMapSpawnPoints()
        local cached = GameRefs.MapSpawnPoints
        if cached ~= nil then
            return typeof(cached) == 'Instance' and cached.Parent and cached or nil
        end
        local map = GetMapRoot()
        if not map then
            return nil
        end
        local spawnPoints = map:FindFirstChild('SpawnPoints')
        if spawnPoints then
            GameRefs.MapSpawnPoints = spawnPoints
        end
        return spawnPoints
    end
    
    do
        local environment = type(getgenv) == 'function' and getgenv() or _G
        local previousCleanup = environment.__ValenokRecodeReloadCleanup
        if type(previousCleanup) == 'function' then
            pcall(previousCleanup)
        end
        environment.__ValenokRecodeReloadCleanup = nil
    
        local state = environment.__ValenokRecodeNamecallState
        if type(state) ~= 'table' then
            state = {}
            environment.__ValenokRecodeNamecallState = state
        end
        ScriptEnvironment = environment
        environment.__ValenokHitCallbackSupported = true
        SharedNamecallState = state
    end
    
    do
        local function EnsureFiresFolder(rayIgnore)
            if rayIgnore and not rayIgnore:FindFirstChild('Fires') then
                local fires = Instance.new('Folder')
                fires.Name = 'Fires'
                fires.Parent = rayIgnore
            end
        end
    
        EnsureFiresFolder(workspace:FindFirstChild('Ray_Ignore'))
        Library:GiveSignal(workspace.ChildAdded:Connect(function(child)
            if child.Name == 'Ray_Ignore' then
                EnsureFiresFolder(child)
            end
        end))
    end
    
    local GetTrueName
    pcall(function()
        GetTrueName = require(ReplicatedStorage:FindFirstChild('GetTrueName'))
    end)
    
    local Window = Library:CreateWindow({
        Title = 'ValenokRecode',
        Center = true,
        AutoShow = true,
    })
    local RageTab = Window:AddTab('Rage')
    local LegitTab = Window:AddTab('Legit')
    
    local VisualTab = Window:AddTab('Visual')
    local SkinTab = Window:AddTab('Skin')
    local SkinCleanup

    local SkinChanger = {}
    do
        local Viewmodels = ReplicatedStorage:FindFirstChild('Viewmodels')
        local Skins = ReplicatedStorage:FindFirstChild('Skins')
        local Gloves = ReplicatedStorage:FindFirstChild('Gloves')
        local GloveModels = Gloves and Gloves:FindFirstChild('Models')
        local ExtraModels
        pcall(function() ExtraModels = game:GetObjects('rbxassetid://7285197035')[1] end)

        local function CloneViewmodel(name)
            local viewmodel = Viewmodels and Viewmodels:FindFirstChild(name)
            return viewmodel and viewmodel:Clone() or nil
        end
        local CustomWeaponModels = {
            AWP = { ['CSGO AWP'] = 'rbxassetid://7161319343' },
            Scout = { ['CSGO Scout'] = 'rbxassetid://7161407697' },
        }
        local CustomKnifeModels = {
            ['CSGO M9 Autotronic'] = 'rbxassetid://6590565396',
            ['CSGO M9 Nebula'] = 'rbxassetid://6597109573',
            ['Bayonet Brave Warrior'] = 'rbxassetid://134702266012551',
        }
        -- Catalog accessories have no viewmodel rig.  Mount them on this knife's real rig.
        local AccessoryKnifeBases = {
            ['Bayonet Brave Warrior'] = 'Bayonet',
        }
        local State = {
            knifeSkins = {}, weaponSkins = {}, gloveSkins = {},
            currentKnife = nil, swapping = false, armsConnection = nil,
            skinConnection = nil, ancestryConnection = nil, cameraConnection = nil,
            originalCT = CloneViewmodel('v_CT Knife'), originalT = CloneViewmodel('v_T Knife'),
            originalWeapons = { AWP = CloneViewmodel('v_AWP'), Scout = CloneViewmodel('v_Scout') },
            customWeaponApplied = {}, customWeaponLoading = {}, customWeaponGeneration = {},
            customKnifeGeneration = 0, pendingKnife = nil,
        }
        local KnifeNames = {
            'CT Knife', 'T Knife', 'Banana', 'Bayonet', 'Bearded Axe', 'Butterfly Knife', 'Cleaver',
            'Crowbar', 'Falchion Knife', 'Flip Knife', 'Gut Knife', 'Huntsman Knife', 'Karambit',
            'M9 Bayonet', 'Sickle', 'Falchion Classic', 'Sickle Classic',
        }
        local function AddUnique(list, value)
            if not table.find(list, value) then list[#list + 1] = value end
        end
        if ExtraModels and ExtraModels:FindFirstChild('Knives') then
            for _, model in ipairs(ExtraModels.Knives:GetChildren()) do AddUnique(KnifeNames, model.Name) end
        end
        AddUnique(KnifeNames, 'CSGO M9 Autotronic')
        AddUnique(KnifeNames, 'CSGO M9 Nebula')
        AddUnique(KnifeNames, 'Bayonet Brave Warrior')

        local function KnifeShort(name)
            return name:gsub(' Knife', ''):gsub(' Classic', '')
        end
        local function KnifeMatches(folderName, knifeName)
            local folder, short, full = string.lower(folderName), string.lower(KnifeShort(knifeName)), string.lower(knifeName)
            return folder == short or folder == full or string.sub(folder, 1, #short + 1) == short .. ' '
        end
        local function FindKnifeFolder(knifeName)
            if not Skins then return nil end
            local direct = Skins:FindFirstChild(knifeName) or Skins:FindFirstChild(KnifeShort(knifeName))
            if direct then return direct end
            for _, folder in ipairs(Skins:GetChildren()) do
                if KnifeMatches(folder.Name, knifeName) then return folder end
            end
        end
        local function ChildNames(folder, fallback)
            local values = { fallback }
            if folder then
                for _, child in ipairs(folder:GetChildren()) do AddUnique(values, child.Name) end
            end
            return values
        end

        local AllWeapons, WeaponSkins, KnifeSkins = {}, {}, {}
        if Skins then
            for _, folder in ipairs(Skins:GetChildren()) do
                local knife = false
                for _, name in ipairs(KnifeNames) do
                    if KnifeMatches(folder.Name, name) then knife = true break end
                end
                if not knife then AllWeapons[#AllWeapons + 1] = folder.Name end
            end
            table.sort(AllWeapons)
            for _, weapon in ipairs(AllWeapons) do WeaponSkins[weapon] = ChildNames(Skins:FindFirstChild(weapon), 'Inventory') end
            for _, knife in ipairs(KnifeNames) do KnifeSkins[knife] = ChildNames(FindKnifeFolder(knife), 'Inventory') end
        end
        for weapon, models in pairs(CustomWeaponModels) do
            if Viewmodels and Viewmodels:FindFirstChild('v_' .. weapon) then
                if not table.find(AllWeapons, weapon) then AllWeapons[#AllWeapons + 1] = weapon end
                WeaponSkins[weapon] = WeaponSkins[weapon] or { 'Inventory' }
                for modelName in pairs(models) do AddUnique(WeaponSkins[weapon], modelName) end
            end
        end
        KnifeSkins['CSGO M9 Autotronic'] = { 'Inventory' }
        KnifeSkins['CSGO M9 Nebula'] = { 'Inventory' }
        KnifeSkins['Bayonet Brave Warrior'] = { 'Inventory' }
        table.sort(AllWeapons)
        local AllGloves, GloveSkins = {}, {}
        if Gloves then
            for _, folder in ipairs(Gloves:GetChildren()) do
                if folder:IsA('Folder') and folder ~= GloveModels and folder.Name ~= 'Models' and folder.Name ~= 'Racer' then
                    AllGloves[#AllGloves + 1] = folder.Name
                end
            end
            table.sort(AllGloves)
            for _, glove in ipairs(AllGloves) do GloveSkins[glove] = ChildNames(Gloves:FindFirstChild(glove), 'Default') end
        end

        local function CopyMap(source)
            local result = {}
            if type(source) == 'table' then
                for model, skin in pairs(source) do
                    if type(model) == 'string' and type(skin) == 'string' then result[model] = skin end
                end
            end
            return result
        end
        function SkinChanger.ExportConfig()
            return { knife = CopyMap(State.knifeSkins), weapon = CopyMap(State.weaponSkins), glove = CopyMap(State.gloveSkins) }
        end
        function SkinChanger.ImportConfig(data)
            if type(data) ~= 'table' then return end
            State.knifeSkins, State.weaponSkins, State.gloveSkins = CopyMap(data.knife), CopyMap(data.weapon), CopyMap(data.glove)
        end

        local function RestoreKnives()
            State.customKnifeGeneration = State.customKnifeGeneration + 1
            State.pendingKnife, State.swapping = nil, false
            if not Viewmodels then return end
            local ct, tt = Viewmodels:FindFirstChild('v_CT Knife'), Viewmodels:FindFirstChild('v_T Knife')
            if ct then ct:Destroy() end
            if tt then tt:Destroy() end
            if State.originalCT then State.originalCT:Clone().Parent = Viewmodels end
            if State.originalT then State.originalT:Clone().Parent = Viewmodels end
        end

        local function GetAssetModel(asset)
            local ok, objects = pcall(game.GetObjects, game, asset)
            if not ok or type(objects) ~= 'table' then return nil, objects end
            local source = objects[1]
            local model = source and (source:IsA('Model') and source or source:FindFirstChildOfClass('Model'))
            if not model and source and source:FindFirstChildWhichIsA('BasePart', true) then
                model = Instance.new('Model')
                model.Name = source.Name
                source.Parent = model
            end
            return ok and model or nil, objects
        end

        local function MountAccessoryKnife(model, baseName)
            local base = Viewmodels and Viewmodels:FindFirstChild('v_' .. baseName)
            local handle = model and (model:FindFirstChild('Handle', true) or model:FindFirstChildWhichIsA('BasePart', true))
            if not base or not handle then return model end
            local rig = base:Clone()
            local root = rig.PrimaryPart or rig:FindFirstChildWhichIsA('BasePart', true)
            if not root then rig:Destroy(); return model end
            rig.PrimaryPart = root
            for _, part in ipairs(rig:GetDescendants()) do
                if part:IsA('BasePart') and part ~= root then part.Transparency = 1 end
            end
            local visual = handle:Clone()
            visual.Name = 'BraveWarriorBlade'
            visual.CFrame = root.CFrame * CFrame.Angles(math.rad(90), 0, 0)
            visual.Anchored, visual.CanCollide, visual.Massless = false, false, true
            visual.Parent = rig
            local weld = Instance.new('WeldConstraint')
            weld.Part0, weld.Part1, weld.Parent = root, visual, root
            model:Destroy()
            return rig
        end

        local function RestoreCustomWeapon(weapon)
            State.customWeaponGeneration[weapon] = (State.customWeaponGeneration[weapon] or 0) + 1
            State.customWeaponLoading[weapon], State.customWeaponApplied[weapon] = nil, nil
            local original = State.originalWeapons[weapon]
            if not Viewmodels or not original then return end
            local current = Viewmodels:FindFirstChild('v_' .. weapon)
            if current then current:Destroy() end
            original:Clone().Parent = Viewmodels
        end

        local function SetCustomWeapon(weapon, skin)
            local asset = CustomWeaponModels[weapon] and CustomWeaponModels[weapon][skin]
            if not asset then
                if State.customWeaponApplied[weapon] or State.customWeaponLoading[weapon] then RestoreCustomWeapon(weapon) end
                return true
            end
            if State.customWeaponApplied[weapon] and Viewmodels and Viewmodels:FindFirstChild('v_' .. weapon) then return true end
            if State.customWeaponLoading[weapon] or not Viewmodels then return false end

            State.customWeaponLoading[weapon] = true
            State.customWeaponGeneration[weapon] = (State.customWeaponGeneration[weapon] or 0) + 1
            local generation = State.customWeaponGeneration[weapon]
            task.spawn(function()
                local model, objects = GetAssetModel(asset)
                if generation ~= State.customWeaponGeneration[weapon] or not model or not Viewmodels then
                    if type(objects) == 'table' then for _, object in ipairs(objects) do object:Destroy() end end
                    if generation == State.customWeaponGeneration[weapon] then State.customWeaponLoading[weapon] = nil end
                    return
                end
                local current = Viewmodels:FindFirstChild('v_' .. weapon)
                if current then current:Destroy() end
                model.Name, model.Parent = 'v_' .. weapon, Viewmodels
                local root = model:FindFirstChild('HumanoidRootPart', true)
                if root and root:IsA('BasePart') then root.Transparency = 1 end
                State.customWeaponLoading[weapon], State.customWeaponApplied[weapon] = nil, skin
                local arms = workspace.CurrentCamera and workspace.CurrentCamera:FindFirstChild('Arms')
                if arms then arms:Destroy() end
            end)
            return false
        end

        local function UpdateCustomWeapons()
            local enabled = Toggles.Skin_Weapon_Enable
            local weapon = Options.Skin_Weapon_Weapon
            local skin = Options.Skin_Weapon_Skin
            for name in pairs(CustomWeaponModels) do
                SetCustomWeapon(name, enabled and enabled.Value and weapon and weapon.Value == name and skin and skin.Value or nil)
            end
        end
        
        local function SwapKnife(knifeName)
            if not Viewmodels then return false end
            local asset = CustomKnifeModels[knifeName]
            if State.swapping then
                if State.pendingKnife == knifeName then return false end
                State.customKnifeGeneration = State.customKnifeGeneration + 1
                State.swapping, State.pendingKnife = false, nil
            end
            if State.currentKnife == knifeName then return true end
            if asset then
                State.swapping, State.pendingKnife = true, knifeName
                State.customKnifeGeneration = State.customKnifeGeneration + 1
                local generation = State.customKnifeGeneration
                task.spawn(function()
                    local model, objects = GetAssetModel(asset)
                    if model and AccessoryKnifeBases[knifeName] then
                        model = MountAccessoryKnife(model, AccessoryKnifeBases[knifeName])
                    end
                    if generation ~= State.customKnifeGeneration or not model then
                        if type(objects) == 'table' then for _, object in ipairs(objects) do object:Destroy() end end
                        if generation == State.customKnifeGeneration then State.swapping, State.pendingKnife = false, nil end
                        return
                    end
                    RestoreKnives()
                    local ct, tt = Viewmodels:FindFirstChild('v_CT Knife'), Viewmodels:FindFirstChild('v_T Knife')
                    if ct then ct:Destroy() end
                    if tt then tt:Destroy() end
                    local first, second = model:Clone(), model:Clone()
                    first.Name, second.Name = 'v_CT Knife', 'v_T Knife'
                    first.Parent, second.Parent = Viewmodels, Viewmodels
                    model:Destroy()
                    State.currentKnife, State.swapping, State.pendingKnife = knifeName, false, nil
                    local arms = workspace.CurrentCamera and workspace.CurrentCamera:FindFirstChild('Arms')
                    if arms then arms:Destroy() end
                end)
                return false
            end
            State.swapping = true
            RestoreKnives()
            if knifeName ~= 'CT Knife' and knifeName ~= 'T Knife' then
                local source = Viewmodels:FindFirstChild('v_' .. knifeName)
                    or (ExtraModels and ExtraModels:FindFirstChild('Knives') and ExtraModels.Knives:FindFirstChild(knifeName))
                if source then
                    local ct, tt = Viewmodels:FindFirstChild('v_CT Knife'), Viewmodels:FindFirstChild('v_T Knife')
                    if ct then ct:Destroy() end
                    if tt then tt:Destroy() end
                    local first, second = source:Clone(), source:Clone()
                    first.Name, second.Name, first.Parent, second.Parent = 'v_CT Knife', 'v_T Knife', Viewmodels, Viewmodels
                end
            end
            State.currentKnife, State.swapping = knifeName, false
            return true
        end

        local TextureCache = setmetatable({}, { __mode = 'k' })
        local function UsefulTexture(texture)
            return texture and texture ~= '' and texture ~= 'rbxassetid://0'
        end
        local function GetTexture(data)
            if data:IsA('StringValue') then return data.Value end
            if data:IsA('MeshPart') then return data.TextureID end
            if data:IsA('Decal') or data:IsA('Texture') then return data.Texture end
            if data:IsA('SurfaceAppearance') then return data end
        end
        local function TextureIndex(skinData)
            local cached = TextureCache[skinData]
            if cached then return cached end
            local index, worldModel = { byName = {}, handle = nil }, skinData:FindFirstChild('WorldModel')
            local function AddTexture(data)
                local texture, name = GetTexture(data), data.Name:gsub('^#%s*', '')
                if not UsefulTexture(texture) then return end
                if not index.byName[name] then index.byName[name] = texture end
                if name == 'Handle' and not index.handle then index.handle = texture end
            end
            for _, data in ipairs(skinData:GetDescendants()) do
                if not (worldModel and data:IsDescendantOf(worldModel)) then AddTexture(data) end
            end
            if worldModel then for _, data in ipairs(worldModel:GetDescendants()) do AddTexture(data) end end
            TextureCache[skinData] = index
            return index
        end
        local function FindTexture(index, part)
            local name, direct = part.Name, index.byName[part.Name]
            if UsefulTexture(direct) then return direct end
            if name == 'Main' and UsefulTexture(index.byName.Part1 or index.byName.Part) then return index.byName.Part1 or index.byName.Part end
            for candidate, texture in pairs(index.byName) do
                local suffix = string.sub(candidate, #name + 1)
                if string.sub(candidate, 1, #name) == name and (suffix == '' or string.match(suffix, '^%d+$')) and UsefulTexture(texture) then return texture end
            end
            if (name == 'Blade' or name == 'Main') and UsefulTexture(index.handle) then return index.handle end
        end
        local function ApplyPart(part, skinData)
            if not part:IsA('BasePart') or part.Transparency == 1 then return end
            local texture = FindTexture(TextureIndex(skinData), part)
            if not texture then return end
            if typeof(texture) == 'Instance' and texture:IsA('SurfaceAppearance') then
                local old = part:FindFirstChildWhichIsA('SurfaceAppearance')
                if old then old:Destroy() end
                texture:Clone().Parent = part
            elseif part:IsA('MeshPart') then
                part.TextureID = texture
            elseif part:FindFirstChild('Mesh') then
                part.Mesh.TextureId = texture
            end
        end
        local function DisconnectSkin()
            if State.skinConnection then State.skinConnection:Disconnect(); State.skinConnection = nil end
            if State.ancestryConnection then State.ancestryConnection:Disconnect(); State.ancestryConnection = nil end
            table.clear(TextureCache)
        end
        local function ApplySkin(arms, itemName, skinName)
            if not Skins or not skinName or skinName == 'Inventory' or not arms.Parent then return end
            if (itemName == 'CT Knife' or itemName == 'T Knife') and not Skins:FindFirstChild(itemName) then itemName = 'M9 Bayonet' end
            local folder = Skins:FindFirstChild(itemName)
            local skinData = folder and folder:FindFirstChild(skinName)
            if not skinData or skinData:FindFirstChild('Animated') then return end
            DisconnectSkin()
            for _, part in ipairs(arms:GetDescendants()) do ApplyPart(part, skinData) end
            State.skinConnection = arms.DescendantAdded:Connect(function(part)
                task.defer(function() if part.Parent then ApplyPart(part, skinData) end end)
            end)
            State.ancestryConnection = arms.AncestryChanged:Connect(function(_, parent)
                if not parent then DisconnectSkin() end
            end)
        end
        local function ApplyGloves(arms)
            local enabled = Toggles.Skin_Glove_Enable
            local gloveOption, skinOption = Options.Skin_Glove_Glove, Options.Skin_Glove_Skin
            if not enabled or not enabled.Value or not GloveModels or not gloveOption or not skinOption then return end
            local glove, skin = gloveOption.Value, skinOption.Value
            local models = glove and GloveModels:FindFirstChild(glove)
            local textureData = glove and Gloves:FindFirstChild(glove) and Gloves[glove]:FindFirstChild(skin)
            local textures = textureData and textureData:FindFirstChild('Textures')
            local textureObject = textures and (textures:FindFirstChild('TextureId') or textures:FindFirstChildWhichIsA('StringValue'))
            local texture = textureObject and textureObject:IsA('StringValue') and textureObject.Value or nil
            if not models or not UsefulTexture(texture) then return end
            local armModel
            for _, model in ipairs(arms:GetChildren()) do
                if model:IsA('Model') and (model:FindFirstChild('Right Arm') or model:FindFirstChild('Left Arm')) then armModel = model break end
            end
            if not armModel then return end
            for _, data in ipairs({ { 'Right Arm', 'RGlove' }, { 'Left Arm', 'LGlove' } }) do
                local arm, old, source = armModel:FindFirstChild(data[1]), nil, models:FindFirstChild(data[2])
                if arm and source then
                    old = arm:FindFirstChild('Glove') or arm:FindFirstChild(data[2])
                    if old then old:Destroy() end
                    local clone = source:Clone()
                    if clone:FindFirstChild('Mesh') then
                        clone.Mesh.TextureId = texture
                    elseif clone:IsA('MeshPart') then
                        clone.TextureID = texture
                    end
                    clone.Transparency, clone.Parent = 0, arm
                    if clone:FindFirstChild('Welded') then clone.Welded.Part0 = arm end
                end
            end
        end
        local function GetClientGun()
            local gui = LocalPlayer:FindFirstChild('PlayerGui')
            local client = gui and gui:FindFirstChild('Client')
            if not client or type(getsenv) ~= 'function' then return nil end
            local ok, environment = pcall(getsenv, client)
            local gun = ok and environment and rawget(environment, 'gun')
            return typeof(gun) == 'Instance' and gun or nil
        end
        local function TryApplyArms(arms)
            if not arms or not arms.Parent then return true end
            local gun = GetClientGun()
            if not gun then return false end
            local name = gun.Name
            if string.find(name, 'Grenade', 1, true) or string.find(name, 'Flashbang', 1, true) or string.find(name, 'Smoke', 1, true)
                or string.find(name, 'Decoy', 1, true) or string.find(name, 'Molotov', 1, true) or string.find(name, 'Incendiary', 1, true) or name == 'C4' then return true end
            ApplyGloves(arms)
            local knifeToggle = Toggles.Skin_Knife_Enable
            local weaponToggle = Toggles.Skin_Weapon_Enable
            if knifeToggle and knifeToggle.Value and gun:FindFirstChild('Melee') then
                local knifeOption = Options.Skin_Knife_Knife
                local knife = knifeOption and knifeOption.Value
                if knife then
                    if State.currentKnife ~= knife then SwapKnife(knife) end
                    ApplySkin(arms, knife, State.knifeSkins[knife] or 'Inventory')
                end
            elseif weaponToggle and weaponToggle.Value and not gun:FindFirstChild('Melee') then
                local skin = State.weaponSkins[name] or 'Inventory'
                if CustomWeaponModels[name] and CustomWeaponModels[name][skin] then
                    return SetCustomWeapon(name, skin)
                end
                if CustomWeaponModels[name] then SetCustomWeapon(name, nil) end
                ApplySkin(arms, name, skin)
            end
            return true
        end
        local function QueueArmsApply(arms)
            task.spawn(function()
                for _ = 1, 80 do
                    if TryApplyArms(arms) then return end
                    task.wait(0.1)
                end
            end)
        end
        local function SetupArmsWatcher()
            if State.armsConnection then State.armsConnection:Disconnect() end
            local camera = workspace.CurrentCamera
            if not camera then return end
            State.armsConnection = camera.ChildAdded:Connect(function(arms)
                if arms.Name == 'Arms' then QueueArmsApply(arms) end
            end)
            local arms = camera:FindFirstChild('Arms')
            if arms then QueueArmsApply(arms) end
        end
        local function RefreshCurrentArms()
            local camera = workspace.CurrentCamera
            local arms = camera and camera:FindFirstChild('Arms')
            if arms then QueueArmsApply(arms) end
        end

        local function SetDropdown(option, values, value)
            if not option then return end
            option:SetValues(values)
            option:SetValue(value)
        end
        local function SyncSkin(modelOption, skinOption, skinMap, saved, fallback)
            local model = modelOption and modelOption.Value
            if not model or not skinOption then return end
            local values = skinMap[model] or { fallback }
            local selected = saved[model]
            if not table.find(values, selected) then selected = values[1] or fallback end
            SetDropdown(skinOption, values, selected)
        end
        local function SavePair(modelOption, skinOption, saved)
            local model, skin = modelOption and modelOption.Value, skinOption and skinOption.Value
            if model and skin then saved[model] = skin end
        end
        local function RandomizeSkins(items, skinMap, saved)
            for _, item in ipairs(items) do
                local values = skinMap[item]
                if values and #values > 1 then
                    saved[item] = values[math.random(2, #values)]
                elseif values and values[1] then
                    saved[item] = values[1]
                end
            end
        end

        local KnifeBox = SkinTab:AddLeftGroupbox('Knife changer')
        KnifeBox:AddToggle('Skin_Knife_Enable', { Text = 'Enable', Default = false }):OnChanged(function()
            if Toggles.Skin_Knife_Enable.Value then SwapKnife(Options.Skin_Knife_Knife.Value) else RestoreKnives(); State.currentKnife = nil end
            RefreshCurrentArms()
        end)
        KnifeBox:AddDropdown('Skin_Knife_Knife', { Text = 'Knife', Values = KnifeNames, Default = KnifeNames[1] }):OnChanged(function()
            SyncSkin(Options.Skin_Knife_Knife, Options.Skin_Knife_Skin, KnifeSkins, State.knifeSkins, 'Inventory')
            if Toggles.Skin_Knife_Enable.Value then SwapKnife(Options.Skin_Knife_Knife.Value) end
        end)
        KnifeBox:AddDropdown('Skin_Knife_Skin', { Text = 'Skin', Values = KnifeSkins[KnifeNames[1]] or { 'Inventory' }, Default = 'Inventory' }):OnChanged(function()
            SavePair(Options.Skin_Knife_Knife, Options.Skin_Knife_Skin, State.knifeSkins)
        end)
        KnifeBox:AddButton('Random skin', function()
            RandomizeSkins(KnifeNames, KnifeSkins, State.knifeSkins)
            SyncSkin(Options.Skin_Knife_Knife, Options.Skin_Knife_Skin, KnifeSkins, State.knifeSkins, 'Inventory')
        end)

        local WeaponBox = SkinTab:AddRightGroupbox('Weapon changer')
        WeaponBox:AddToggle('Skin_Weapon_Enable', { Text = 'Enable', Default = false }):OnChanged(function()
            UpdateCustomWeapons()
            RefreshCurrentArms()
        end)
        WeaponBox:AddDropdown('Skin_Weapon_Weapon', { Text = 'Weapon', Values = #AllWeapons > 0 and AllWeapons or { 'None' }, Default = AllWeapons[1] or 'None' }):OnChanged(function()
            SyncSkin(Options.Skin_Weapon_Weapon, Options.Skin_Weapon_Skin, WeaponSkins, State.weaponSkins, 'Inventory')
            UpdateCustomWeapons()
        end)
        WeaponBox:AddDropdown('Skin_Weapon_Skin', { Text = 'Skin', Values = WeaponSkins[AllWeapons[1]] or { 'Inventory' }, Default = 'Inventory' }):OnChanged(function()
            SavePair(Options.Skin_Weapon_Weapon, Options.Skin_Weapon_Skin, State.weaponSkins)
            UpdateCustomWeapons()
            RefreshCurrentArms()
        end)
        WeaponBox:AddButton('Random skin', function()
            RandomizeSkins(AllWeapons, WeaponSkins, State.weaponSkins)
            SyncSkin(Options.Skin_Weapon_Weapon, Options.Skin_Weapon_Skin, WeaponSkins, State.weaponSkins, 'Inventory')
        end)

        local GloveBox = SkinTab:AddLeftGroupbox('Glove changer')
        GloveBox:AddToggle('Skin_Glove_Enable', { Text = 'Enable', Default = false }):OnChanged(RefreshCurrentArms)
        GloveBox:AddDropdown('Skin_Glove_Glove', { Text = 'Glove', Values = #AllGloves > 0 and AllGloves or { 'None' }, Default = AllGloves[1] or 'None' }):OnChanged(function()
            SyncSkin(Options.Skin_Glove_Glove, Options.Skin_Glove_Skin, GloveSkins, State.gloveSkins, 'Default')
        end)
        GloveBox:AddDropdown('Skin_Glove_Skin', { Text = 'Skin', Values = GloveSkins[AllGloves[1]] or { 'Default' }, Default = 'Default' }):OnChanged(function()
            SavePair(Options.Skin_Glove_Glove, Options.Skin_Glove_Skin, State.gloveSkins)
        end)
        GloveBox:AddButton('Random skin', function()
            RandomizeSkins(AllGloves, GloveSkins, State.gloveSkins)
            SyncSkin(Options.Skin_Glove_Glove, Options.Skin_Glove_Skin, GloveSkins, State.gloveSkins, 'Default')
        end)

        function SkinChanger.RefreshConfig()
            SyncSkin(Options.Skin_Knife_Knife, Options.Skin_Knife_Skin, KnifeSkins, State.knifeSkins, 'Inventory')
            SyncSkin(Options.Skin_Weapon_Weapon, Options.Skin_Weapon_Skin, WeaponSkins, State.weaponSkins, 'Inventory')
            SyncSkin(Options.Skin_Glove_Glove, Options.Skin_Glove_Skin, GloveSkins, State.gloveSkins, 'Default')
            if Toggles.Skin_Knife_Enable.Value then SwapKnife(Options.Skin_Knife_Knife.Value) end
        end
        SetupArmsWatcher()
        State.cameraConnection = workspace:GetPropertyChangedSignal('CurrentCamera'):Connect(SetupArmsWatcher)
        SkinCleanup = function()
            if State.armsConnection then State.armsConnection:Disconnect() end
            if State.cameraConnection then State.cameraConnection:Disconnect() end
            DisconnectSkin()
            RestoreKnives()
            for weapon in pairs(CustomWeaponModels) do RestoreCustomWeapon(weapon) end
        end
    end

    local Players = VisualTab:AddLeftGroupbox('Players')
    local Removals = VisualTab:AddRightGroupbox('Removals')
    local Misc = VisualTab:AddRightGroupbox('Misc')
    local SelfChams = VisualTab:AddRightGroupbox('Self chams')
    local ViewModel = VisualTab:AddRightGroupbox('View model')
    local HitLog = VisualTab:AddRightGroupbox('Hit Sound')
    local HitLogDisplay = VisualTab:AddRightGroupbox('Hit Log')
    local CustomCrosshair = VisualTab:AddLeftGroupbox('Custom crosshair')
    local KillEffect = VisualTab:AddLeftGroupbox('Kill effect')
    local CustomCrosshairCleanup
    
    HitLog:AddToggle('HitLog_Enable', { Text = 'Enable', Default = false })
    HitLog:AddDropdown('HitLog_Sound', {
        Text = 'Hit sound',
        Values = {
            'Skeet', 'Neverlose', 'Bameware', 'Bell', 'Bubble', 'Pick', 'Pop', 'Rust', 'Sans', 'Fart',
            'Big', 'Vine', 'Bruh', 'Fatality', 'Bonk', 'Minecraft', 'Moan',
        },
        Default = 'Skeet',
    })
    HitLog:AddSlider('HitLog_Volume', {
        Text = 'Volume',
        Default = 2,
        Min = 1,
        Max = 10,
        Rounding = 0,
    })
    HitLog:AddButton('Play hit sound', function()
        if PlayHitSound then PlayHitSound() end
    end)
    
    HitLogDisplay:AddToggle('HitLog_DisplayEnable', { Text = 'Enable', Default = false })
    HitLogDisplay:AddSlider('HitLog_Lifetime', {
        Text = 'Life time',
        Default = 3,
        Min = 1,
        Max = 5,
        Rounding = 0,
        Suffix = 's',
    })

    CustomCrosshair:AddToggle('CustomCrosshair_Enable', { Text = 'Enable', Default = false })
        :AddColorPicker('CustomCrosshair_Color', {
            Default = Color3.fromRGB(255, 255, 255),
            Transparency = 0,
            Title = 'Color',
        })
    CustomCrosshair:AddToggle('CustomCrosshair_HideGame', { Text = 'Hide game crosshair', Default = false })
    CustomCrosshair:AddToggle('CustomCrosshair_Spin', { Text = 'Spin', Default = false })
    CustomCrosshair:AddSlider('CustomCrosshair_SpinSpeed', {
        Text = 'Spin speed', Default = 25, Min = 1, Max = 100, Rounding = 0,
    })
    CustomCrosshair:AddSlider('CustomCrosshair_Width', {
        Text = 'Width', Default = 2, Min = 1, Max = 10, Rounding = 0,
    })
    CustomCrosshair:AddSlider('CustomCrosshair_Length', {
        Text = 'Length', Default = 6, Min = 1, Max = 10, Rounding = 0,
    })
    CustomCrosshair:AddToggle('CustomCrosshair_Outline', { Text = 'Outline', Default = true })
        :AddColorPicker('CustomCrosshair_OutlineColor', {
            Default = Color3.fromRGB(0, 0, 0),
            Transparency = 0,
            Title = 'Outline color',
        })
    CustomCrosshair:AddSlider('CustomCrosshair_OutlineWidth', {
        Text = 'Outline thickness', Default = 1, Min = 1, Max = 10, Rounding = 0,
    })

    KillEffect:AddToggle('KillEffect_Enable', { Text = 'Enable', Default = false })
        :AddColorPicker('KillEffect_Color', {
            Default = Color3.fromRGB(255, 210, 70),
            Transparency = 0,
            Title = 'Color',
        })
    KillEffect:AddSlider('KillEffect_Lifetime', {
        Text = 'Life time', Default = 4, Min = 1, Max = 15, Rounding = 0, Suffix = 's',
    })
    KillEffect:AddSlider('KillEffect_Amount', {
        Text = 'Amount', Default = 50, Min = 10, Max = 300, Rounding = 0,
    })
    KillEffect:AddDropdown('KillEffect_Mode', {
        Text = 'Particle mode', Values = { 'Statik', 'Dynamic' }, Default = 'Dynamic',
    })
    KillEffect:AddDropdown('KillEffect_Shape', {
        Text = 'Particle shape', Values = { 'Circles', 'Snowflakes', 'Stars' }, Default = 'Circles',
    })

    do
        local PendingKills, ActiveEffects = {}, {}
        local EffectAlive = true

        local function NewPart(parent, size, shape)
            local part = Instance.new('Part')
            part.Anchored, part.CanCollide, part.CanTouch, part.CanQuery = true, false, false, false
            part.CastShadow, part.Material = false, Enum.Material.Neon
            part.Shape, part.Size = shape or Enum.PartType.Block, size
            part.Parent = parent
            return part
        end

        local function BuildParticle(parent, shape)
            local parts = {}
            local function add(size, offset, angle, ball)
                parts[#parts + 1] = {
                    part = NewPart(parent, size, ball and Enum.PartType.Ball or nil),
                    offset = CFrame.new(offset or Vector3.new()) * CFrame.Angles(0, 0, angle or 0),
                }
            end
            if shape == 'Snowflakes' then
                for i = 0, 2 do add(Vector3.new(0.78, 0.055, 0.055), nil, math.rad(i * 60)) end
            elseif shape == 'Stars' then
                for i = 0, 4 do add(Vector3.new(0.7, 0.06, 0.06), nil, math.rad(i * 72)) end
            else
                add(Vector3.new(0.28, 0.28, 0.28), nil, nil, true)
            end
            return parts
        end

        local function CreateEffect(character)
            if not EffectAlive or not Toggles.KillEffect_Enable.Value then return end
            local root = character and (character:FindFirstChild('HumanoidRootPart') or character:FindFirstChild('UpperTorso'))
            if not root or not root:IsA('BasePart') then return end
            local hitboxes = {}
            for _, part in ipairs(character:GetChildren()) do
                if part:IsA('BasePart') and part ~= root and part.Name ~= 'HumanoidRootPart' then
                    hitboxes[#hitboxes + 1] = part
                end
            end
            if #hitboxes == 0 then hitboxes[1] = root end

            while #ActiveEffects >= 3 do
                local old = table.remove(ActiveEffects, 1)
                if old and old.Parent then old:Destroy() end
            end
            local holder = Instance.new('Folder')
            holder.Name, holder.Parent = 'ValenokKillEffect', workspace
            ActiveEffects[#ActiveEffects + 1] = holder

            local particles, color = {}, Options.KillEffect_Color.Value
            local shape, amount = Options.KillEffect_Shape.Value, Options.KillEffect_Amount.Value
            for i = 1, amount do
                local hitbox = hitboxes[(i - 1) % #hitboxes + 1]
                local size = hitbox.Size
                local origin = hitbox.CFrame:PointToWorldSpace(Vector3.new(
                    (math.random() - 0.5) * size.X,
                    (math.random() - 0.5) * size.Y,
                    (math.random() - 0.5) * size.Z
                ))
                local angle = math.pi * 2 * i / amount + math.random() * 0.22
                local direction = Vector3.new(math.cos(angle), 0.25 + math.random() * 0.55, math.sin(angle)).Unit
                particles[#particles + 1] = {
                    parts = BuildParticle(holder, shape),
                    origin = origin,
                    direction = direction,
                    phase = math.random() * math.pi * 2,
                    distance = 2.2 + math.random() * 2.6,
                }
            end

            local started, lifetime = os.clock(), Options.KillEffect_Lifetime.Value
            local dynamic = Options.KillEffect_Mode.Value == 'Dynamic'
            local connection
            connection = RunService.RenderStepped:Connect(function()
                local progress = (os.clock() - started) / lifetime
                if progress >= 1 or not EffectAlive or not holder.Parent then
                    connection:Disconnect()
                    if holder.Parent then holder:Destroy() end
                    return
                end
                local transparency = math.clamp((progress - 0.72) / 0.28, 0, 1)
                for _, particle in ipairs(particles) do
                    local position = particle.origin
                    if dynamic then
                        position = position + particle.direction * (particle.distance * progress)
                            + Vector3.new(0, math.sin(progress * math.pi) * 1.8, 0)
                    end
                    local frame = CFrame.new(position) * CFrame.Angles(0, progress * 8 + particle.phase, progress * 5)
                    for _, entry in ipairs(particle.parts) do
                        entry.part.Color, entry.part.Transparency = color, transparency
                        entry.part.CFrame = frame * entry.offset
                    end
                end
            end)
            DebrisService:AddItem(holder, lifetime + 0.2)
        end

        local function WatchKill(player)
            if not EffectAlive or not Toggles.KillEffect_Enable.Value then return end
            local character = player.Character
            local humanoid = character and character:FindFirstChildOfClass('Humanoid')
            if not humanoid or humanoid.Health <= 0 then return end
            local userId = player.UserId
            local pending = PendingKills[userId]
            if pending then pending.expires = os.clock() + 1.5 return end

            pending = { expires = os.clock() + 1.5 }
            PendingKills[userId] = pending
            local function confirm()
                if PendingKills[userId] ~= pending or os.clock() > pending.expires then return end
                PendingKills[userId] = nil
                if pending.health then pending.health:Disconnect() end
                if pending.died then pending.died:Disconnect() end
                CreateEffect(character)
            end
            pending.health = humanoid.HealthChanged:Connect(function(health)
                if health <= 0 then confirm() end
            end)
            pending.died = humanoid.Died:Connect(confirm)
            task.delay(1.6, function()
                if PendingKills[userId] ~= pending then return end
                PendingKills[userId] = nil
                if pending.health then pending.health:Disconnect() end
                if pending.died then pending.died:Disconnect() end
            end)
        end

        HandleKillEffect = function(hitPart)
            if typeof(hitPart) ~= 'Instance' or not hitPart:IsA('BasePart') then return end
            local character = hitPart:FindFirstAncestorOfClass('Model')
            local player = character and PlayersService:GetPlayerFromCharacter(character)
            if player and player ~= LocalPlayer
                and (not player.Team or player.Team ~= LocalPlayer.Team)
            then
                WatchKill(player)
            end
        end

        KillEffectCleanup = function()
            EffectAlive = false
            HandleKillEffect = nil
            for _, pending in pairs(PendingKills) do
                if pending.health then pending.health:Disconnect() end
                if pending.died then pending.died:Disconnect() end
            end
            for _, holder in ipairs(ActiveEffects) do
                if holder and holder.Parent then holder:Destroy() end
            end
        end
    end

    do
        local Lines, Outlines = {}, {}
        local GameCrosshair, GameCrosshairConnection
        for i = 1, 4 do
            local okLine, line = pcall(Drawing.new, 'Line')
            local okOutline, outline = pcall(Drawing.new, 'Line')
            if okLine then line.Visible, line.ZIndex = false, 2 end
            if okOutline then outline.Visible, outline.ZIndex = false, 1 end
            Lines[i], Outlines[i] = line, outline
        end

        local function SetVisible(set, visible)
            for i = 1, #set do
                if set[i] then set[i].Visible = visible end
            end
        end

        local function HideGameCrosshair()
            if not Toggles.CustomCrosshair_Enable.Value or not Toggles.CustomCrosshair_HideGame.Value then
                return
            end
            local playerGui = LocalPlayer:FindFirstChildOfClass('PlayerGui')
            local gui = playerGui and playerGui:FindFirstChild('GUI')
            local crosshairs = gui and gui:FindFirstChild('Crosshairs')
            local crosshair = crosshairs and crosshairs:FindFirstChild('Crosshair')
            if crosshair ~= GameCrosshair then
                if GameCrosshairConnection then GameCrosshairConnection:Disconnect() end
                GameCrosshair, GameCrosshairConnection = crosshair, nil
                if crosshair then
                    GameCrosshairConnection = crosshair:GetPropertyChangedSignal('Visible'):Connect(function()
                        if Toggles.CustomCrosshair_Enable.Value and Toggles.CustomCrosshair_HideGame.Value then
                            crosshair.Visible = false
                        end
                    end)
                end
            end
            if crosshair then crosshair.Visible = false end
        end

        Library:GiveSignal(RunService.RenderStepped:Connect(function()
            local enabled = Toggles.CustomCrosshair_Enable.Value
            if not enabled then
                SetVisible(Lines, false)
                SetVisible(Outlines, false)
                return
            end

            local camera = workspace.CurrentCamera
            if not camera then return end
            local viewport = camera.ViewportSize
            if viewport.X <= 0 or viewport.Y <= 0 then return end
            local center = viewport * 0.5
            local width = Options.CustomCrosshair_Width.Value
            local length = Options.CustomCrosshair_Length.Value
            local gap = 5 + width * 0.5
            local angle = Toggles.CustomCrosshair_Spin.Value
                and math.rad(os.clock() * Options.CustomCrosshair_SpinSpeed.Value * 3.6) or 0
            local x, y = math.cos(angle), math.sin(angle)
            local directions = {
                Vector2.new(x, y), Vector2.new(-y, x), Vector2.new(-x, -y), Vector2.new(y, -x),
            }
            local color = Options.CustomCrosshair_Color.Value
            local outlineOn = Toggles.CustomCrosshair_Outline.Value
            local outlineColor = Options.CustomCrosshair_OutlineColor.Value
            local outlineWidth = Options.CustomCrosshair_OutlineWidth.Value

            for i = 1, 4 do
                local from = center + directions[i] * gap
                local to = center + directions[i] * (gap + length)
                local line, outline = Lines[i], Outlines[i]
                if line then
                    line.From, line.To, line.Color, line.Thickness, line.Visible = from, to, color, width, true
                end
                if outline then
                    outline.From, outline.To = from, to
                    outline.Color, outline.Thickness, outline.Visible = outlineColor, width + outlineWidth * 2, outlineOn
                end
            end
        end))

        pcall(function()
            RunService:UnbindFromRenderStep('ValenokHideGameCrosshair')
            RunService:BindToRenderStep('ValenokHideGameCrosshair', Enum.RenderPriority.Last.Value, HideGameCrosshair)
        end)

        CustomCrosshairCleanup = function()
            pcall(function() RunService:UnbindFromRenderStep('ValenokHideGameCrosshair') end)
            if GameCrosshairConnection then GameCrosshairConnection:Disconnect() end
            for _, set in ipairs({ Lines, Outlines }) do
                for i = 1, #set do
                    if set[i] then pcall(function() set[i]:Remove() end) end
                end
            end
        end
    end
    
    do
        local HitSounds = {
            Skeet = 5633695679, Neverlose = 6534948092, Bameware = 3124331820, Bell = 6534947240,
            Bubble = 6534947588, Pick = 1347140027, Pop = 198598793, Rust = 1255040462,
            Sans = 3188795283, Fart = 130833677, Big = 5332005053, Vine = 5332680810,
            Bruh = 4578740568, Fatality = 6534947869, Bonk = 5766898159, Minecraft = 4018616850,
            Moan = { 2440888376, 2440889605, 2440889869, 2440889381, 2440891382 },
        }
        local Entries, Pending, Texts = {}, {}, {}
        local MaxEntries = 5
        local DisplayConnection
        local HitLogAlive = true
    
        local function GetHitbox(part)
            local name = part.Name
            if name == 'HeadHB' or name == 'FakeHead' or name == 'Head' then return 'Head' end
            if name == 'UpperTorso' or name == 'LowerTorso' or name == 'Torso' or name == 'HumanoidRootPart' then return 'Body' end
            if string.find(name, 'Arm', 1, true) or string.find(name, 'Hand', 1, true) then return 'Arms' end
            if string.find(name, 'Leg', 1, true) or string.find(name, 'Foot', 1, true) then return 'Legs' end
            return name
        end
    
        PlayHitSound = function()
            local soundId = HitSounds[Options.HitLog_Sound.Value]
            if type(soundId) == 'table' then soundId = soundId[math.random(1, #soundId)] end
            if not soundId then return end
    
            local sound = Instance.new('Sound')
            sound.SoundId = 'rbxassetid://' .. soundId
            sound.Volume = Options.HitLog_Volume.Value
            sound.Parent = SoundService
            sound:Play()
            DebrisService:AddItem(sound, 5)
        end
    
        local function PushLog(player, hitbox, damage)
            if not Toggles.HitLog_DisplayEnable.Value then return end
            table.insert(Entries, 1, {
                text = string.format('Hit %s in %s (-%d HP)', player.Name, hitbox, math.floor(damage + 0.5)),
                expires = os.clock() + Options.HitLog_Lifetime.Value,
            })
            while #Entries > MaxEntries do table.remove(Entries) end
        end
    
        local function WatchDamage(player, hitbox)
            if not HitLogAlive then return end
            local character = player.Character
            local humanoid = character and character:FindFirstChildOfClass('Humanoid')
            if not humanoid or humanoid.Health <= 0 then return end
    
            local userId = player.UserId
            local previous = Pending[userId]
            if previous then previous:Disconnect() end
    
            local health = humanoid.Health
            local connection
            connection = humanoid.HealthChanged:Connect(function(current)
                if current >= health then return end
                connection:Disconnect()
                Pending[userId] = nil
                if Toggles.HitLog_Enable.Value then PlayHitSound() end
                PushLog(player, hitbox, health - current)
            end)
            Pending[userId] = connection
            task.delay(0.5, function()
                if Pending[userId] == connection then
                    connection:Disconnect()
                    Pending[userId] = nil
                end
            end)
        end
    
        HandleHitParl = function(hitPart)
            if not HitLogAlive then return end
            if not Toggles.HitLog_Enable.Value and not Toggles.HitLog_DisplayEnable.Value then return end
            if typeof(hitPart) ~= 'Instance' or not hitPart:IsA('BasePart') then return end
            local character = hitPart:FindFirstAncestorOfClass('Model')
            local player = character and PlayersService:GetPlayerFromCharacter(character)
            if not player or player == LocalPlayer then return end
            WatchDamage(player, GetHitbox(hitPart))
        end
    
        local function GetText(index)
            if Texts[index] then return Texts[index] end
            local ok, text = pcall(Drawing.new, 'Text')
            if not ok then return end
            text.Center, text.Outline, text.Size, text.Font = true, true, 13, 2
            text.Color, text.OutlineColor, text.Visible = Color3.fromRGB(80, 255, 120), Color3.new(), false
            Texts[index] = text
            return text
        end
    
        local function UpdateDisplay()
            local now = os.clock()
            while Entries[#Entries] and Entries[#Entries].expires <= now do table.remove(Entries) end
            local camera = workspace.CurrentCamera
            local center = camera and camera.ViewportSize.X / 2 or 0
            for i = 1, MaxEntries do
                local entry = Entries[i]
                local text = Texts[i] or (entry and GetText(i))
                if text then
                    text.Visible = entry ~= nil
                    if entry then
                        text.Text = entry.text
                        text.Position = Vector2.new(center, 300 + (i - 1) * 16)
                    end
                end
            end
        end
    
        local function SetDisplayEnabled()
            if Toggles.HitLog_DisplayEnable.Value then
                if not DisplayConnection then
                    DisplayConnection = RunService.RenderStepped:Connect(UpdateDisplay)
                end
                return
            end
    
            if DisplayConnection then
                DisplayConnection:Disconnect()
                DisplayConnection = nil
            end
            for i = 1, #Texts do
                Texts[i].Visible = false
            end
        end
    
        Toggles.HitLog_DisplayEnable:OnChanged(SetDisplayEnabled)
        SetDisplayEnabled()
    
        HitLogCleanup = function()
            HitLogAlive = false
            if DisplayConnection then
                DisplayConnection:Disconnect()
                DisplayConnection = nil
            end
            for _, connection in pairs(Pending) do connection:Disconnect() end
            for _, text in pairs(Texts) do text:Remove() end
        end
    end
    
    local AntiAimState = {
        pitchRandom = 0,
        pitchRandomAt = 0,
        yawSpin = 0,
        yawSpinAt = 0,
        targetAt = 0,
        targetRoot = nil,
    }
    local function GetAntiAimPitchValue()
        local mode = Options.AntiAim_Pitch_Mode and Options.AntiAim_Pitch_Mode.Value or 'Up'
        if mode == 'Down' then return -1 end
        if mode == 'Up' then return 1 end
        if mode == 'Custom' then
            return Options.AntiAim_Pitch_CustomValue and Options.AntiAim_Pitch_CustomValue.Value or 0
        end
        if mode == 'Random' then
            local now = os.clock()
            local speed = Options.AntiAim_Pitch_RandomSpeed and Options.AntiAim_Pitch_RandomSpeed.Value or 1
            if (now - AntiAimState.pitchRandomAt) * 1000 >= speed then
                local value = math.random(-10, 10) / 10
                while math.abs(value - AntiAimState.pitchRandom) < 0.2 do value = math.random(-10, 10) / 10 end
                AntiAimState.pitchRandom, AntiAimState.pitchRandomAt = value, now
            end
            return AntiAimState.pitchRandom
        end
        return 0
    end

    do
        local HookActive = false
        local NamecallHandler

        if type(hookmetamethod) == 'function' and type(getnamecallmethod) == 'function' then
            NamecallHandler = function(oldNamecall, self, ...)
                if not HookActive then
                    return oldNamecall(self, ...)
                end
                local method = getnamecallmethod()
                if (method == 'FireServer' or method == 'FireUnreliable')
                    and typeof(self) == 'Instance'
                    and self.Name == 'ControlTurn'
                    and Toggles.AntiAim_Pitch_Enable
                    and Toggles.AntiAim_Pitch_Enable.Value
                then
                    local args = table.pack(...)
                    args[1] = GetAntiAimPitchValue()
                    return oldNamecall(self, unpack(args, 1, args.n))
                end
                if (method == 'SetPrimaryPartCFrame' or method == 'PivotTo' or method == 'pivotTo')
                    and Toggles.ViewModel_Offset_Enable.Value
                    and self.Name ~= 'HumanoidRootPart' then
                    local node, isArms = self, false
                    local camera = workspace.CurrentCamera
                    while node do
                        if node.Name == 'Arms' and node.Parent == camera then
                            isArms = true
                            break
                        end
                        node = node.Parent
                    end
                    if isArms then
                        local args = table.pack(...)
                        if typeof(args[1]) == 'CFrame' then
                            local offset = CFrame.new(
                                Options.ViewModel_Offset_X.Value / 10,
                                Options.ViewModel_Offset_Y.Value / 10,
                                -Options.ViewModel_Offset_Z.Value / 10
                            ) * CFrame.Angles(0, 0, math.rad(Options.ViewModel_Offset_Roll.Value))
                            args[1] = args[1] * offset
                            return oldNamecall(self, unpack(args, 1, args.n))
                        end
                    end
                end
                if (method == 'FireServer' or method == 'FireUnreliable') and self.Name == 'HitParl' then
                    local callbacks = ScriptEnvironment and ScriptEnvironment.__ValenokHitCallbacks
                    if type(callbacks) == 'table' then
                        local hitPart, hitPosition = ...
                        for _, callback in pairs(callbacks) do
                            if type(callback) == 'function' then
                                task.defer(callback, hitPart, hitPosition)
                            end
                        end
                    end
                    if HandleKillEffect then
                        local hitPart = ...
                        task.defer(HandleKillEffect, hitPart)
                    end
                end
                if not Toggles.HitLog_Enable.Value
                    and not Toggles.HitLog_DisplayEnable.Value
                    and not HandleRageHitParl
                then
                    return oldNamecall(self, ...)
                end

                if method ~= 'FireServer' and method ~= 'FireUnreliable' then
                    return oldNamecall(self, ...)
                end
                if self.Name ~= 'HitParl' then
                    return oldNamecall(self, ...)
                end

                if HandleHitParl
                    and (Toggles.HitLog_Enable.Value or Toggles.HitLog_DisplayEnable.Value)
                then
                    local hitPart = ...
                    task.defer(HandleHitParl, hitPart)
                end
                if HandleRageHitParl then
                    local args = table.pack(...)
                    args = HandleRageHitParl(args)
                    return oldNamecall(self, unpack(args, 1, args.n))
                end
                return oldNamecall(self, ...)
            end

            local state = SharedNamecallState
            state.handler = NamecallHandler
            if not state.oldNamecall then
                local function NamecallDispatcher(self, ...)
                    local handler = state.handler
                    local oldNamecall = state.oldNamecall
                    if handler then
                        return handler(oldNamecall, self, ...)
                    end
                    return oldNamecall(self, ...)
                end

                local wrapper = type(newcclosure) == 'function'
                    and newcclosure(NamecallDispatcher)
                    or NamecallDispatcher
                local hookOk, oldNamecall = pcall(hookmetamethod, game, '__namecall', wrapper)
                if hookOk and oldNamecall then
                    state.oldNamecall = oldNamecall
                elseif state.handler == NamecallHandler then
                    state.handler = nil
                end
            end
            HookActive = state.oldNamecall ~= nil
        end

        NamecallCleanup = function()
            HookActive = false
            if SharedNamecallState.handler == NamecallHandler then
                SharedNamecallState.handler = nil
            end
        end
    end

    SelfChams:AddToggle('ViewModel_WeaponChams', {
        Text = 'Weapon Chams',
        Default = false,
    }):AddColorPicker('ViewModel_WeaponColor', {
        Default = Color3.fromRGB(255, 170, 0),
        Transparency = 0,
    })
    
    SelfChams:AddDropdown('ViewModel_WeaponMaterial', {
        Text = 'Weapon Material',
        Values = { 'SmoothPlastic', 'ForceField', 'Neon', 'Glass' },
        Default = 'Neon',
    })
    
    SelfChams:AddSlider('ViewModel_WeaponTransparency', {
        Text = 'Weapon Transparency',
        Default = 0,
        Min = 0,
        Max = 100,
        Rounding = 0,
        Suffix = '%',
    })
    
    SelfChams:AddToggle('ViewModel_ArmChams', {
        Text = 'Arm Chams',
        Default = false,
    }):AddColorPicker('ViewModel_ArmColor', {
        Default = Color3.fromRGB(0, 255, 255),
        Transparency = 0,
    })
    
    SelfChams:AddDropdown('ViewModel_ArmMaterial', {
        Text = 'Arm Material',
        Values = { 'SmoothPlastic', 'ForceField', 'Neon', 'Glass' },
        Default = 'ForceField',
    })
    
    SelfChams:AddSlider('ViewModel_ArmTransparency', {
        Text = 'Arm Transparency',
        Default = 0,
        Min = 0,
        Max = 100,
        Rounding = 0,
        Suffix = '%',
    })
    
    SelfChams:AddToggle('ViewModel_RemoveSleeves', { Text = 'Remove Sleeves', Default = false })
    SelfChams:AddToggle('ViewModel_RemoveGloves', { Text = 'Remove Gloves', Default = false })

    ViewModel:AddToggle('ViewModel_Offset_Enable', {
        Text = 'Viewmodel offset', Default = false,
        Tooltip = 'Включает изменение позиции рук и оружия.',
    })
    ViewModel:AddSlider('ViewModel_Offset_X', {
        Text = 'X', Default = 0, Min = -25, Max = 25, Rounding = 1,
        Tooltip = 'Двигает руки влево или вправо.',
    })
    ViewModel:AddSlider('ViewModel_Offset_Y', {
        Text = 'Y', Default = 0, Min = -25, Max = 25, Rounding = 1,
        Tooltip = 'Двигает руки вниз или вверх.',
    })
    ViewModel:AddSlider('ViewModel_Offset_Z', {
        Text = 'Z', Default = 0, Min = -25, Max = 25, Rounding = 1,
        Tooltip = 'Двигает руки ближе или дальше от камеры.',
    })
    ViewModel:AddSlider('ViewModel_Offset_Roll', {
        Text = 'Roll', Default = 0, Min = 0, Max = 360, Rounding = 1, Suffix = '°',
        Tooltip = 'Наклоняет руки и оружие вокруг экрана.',
    })

    Removals:AddToggle('Removals_NoSmoke', { Text = 'Remove Smoke', Default = false })
    Removals:AddToggle('Removals_NoFlash', { Text = 'Remove Flash', Default = false })
    Removals:AddToggle('Removals_NoScope', { Text = 'Remove Scope', Default = false })
    Removals:AddToggle('Removals_NoWeaponAnimation', { Text = 'Remove Weapon Animation', Default = false })
    
    Misc:AddToggle('SpreadVisualizer_Enable', {
        Text = 'Spread visualizer',
        Default = false,
    }):AddColorPicker('SpreadVisualizer_Color', {
        Default = Color3.fromRGB(255, 255, 0),
        Transparency = 0.65,
    })
    
    -- Enable
    Players:AddToggle('ESP_Enable', { Text = 'Enable', Default = false })
    
    -- TeamCheck
    Players:AddToggle('ESP_TeamCheck', { Text = 'TeamCheck', Default = false })
    
    local UnloadFns = {}
    local function AddUnload(fn)
        UnloadFns[#UnloadFns + 1] = fn
    end

    AddUnload(function()
        if CustomCrosshairCleanup then CustomCrosshairCleanup() end
    end)

    AddUnload(function()
        if KillEffectCleanup then KillEffectCleanup() end
    end)

    AddUnload(function()
        if SkinCleanup then
            SkinCleanup()
            SkinCleanup = nil
        end
    end)

    local function ReloadCleanup()
        if type(Library.Unload) == 'function' then
            Library:Unload()
        end
    end
    ScriptEnvironment.__ValenokRecodeReloadCleanup = ReloadCleanup
    
    AddUnload(function()
        unload()
        if HitLogCleanup then pcall(HitLogCleanup) end
        if NamecallCleanup then pcall(NamecallCleanup) end
    end)
    
    Library:OnUnload(function()
        for i = 1, #UnloadFns do
            pcall(UnloadFns[i])
        end
        if ScriptEnvironment.__ValenokRecodeReloadCleanup == ReloadCleanup then
            ScriptEnvironment.__ValenokRecodeReloadCleanup = nil
        end
    end)
    
    -- Removals
    do
        local SmokeConnections = {}
        local FlashState
        local ScopeTransparency = setmetatable({}, { __mode = 'k' })
        local AnimationConnections = {}
        local NextAnimationCheck = 0
        local PollConnection
    
        local function DisconnectSmokes()
            for i = 1, #SmokeConnections do
                SmokeConnections[i]:Disconnect()
            end
            table.clear(SmokeConnections)
        end
    
        local function DestroySmoke(smoke)
            if smoke and smoke.Parent then
                smoke:Destroy()
            end
        end
    
        local function SetupNoSmoke()
            DisconnectSmokes()
            if not Toggles.Removals_NoSmoke.Value then
                return
            end
    
            local function WatchSmokes(folder)
                for _, smoke in ipairs(folder:GetChildren()) do
                    DestroySmoke(smoke)
                end
                SmokeConnections[#SmokeConnections + 1] = folder.ChildAdded:Connect(DestroySmoke)
            end
    
            local function WatchRayIgnore(rayIgnore)
                local smokes = rayIgnore:FindFirstChild('Smokes')
                if smokes then
                    WatchSmokes(smokes)
                else
                    SmokeConnections[#SmokeConnections + 1] = rayIgnore.ChildAdded:Connect(function(child)
                        if child.Name == 'Smokes' and Toggles.Removals_NoSmoke.Value then
                            DisconnectSmokes()
                            WatchSmokes(child)
                        end
                    end)
                end
            end
    
            local rayIgnore = workspace:FindFirstChild('Ray_Ignore')
            if rayIgnore then
                WatchRayIgnore(rayIgnore)
            else
                SmokeConnections[#SmokeConnections + 1] = workspace.ChildAdded:Connect(function(child)
                    if child.Name == 'Ray_Ignore' and Toggles.Removals_NoSmoke.Value then
                        DisconnectSmokes()
                        WatchRayIgnore(child)
                    end
                end)
            end
        end
    
        local function GetPlayerGui()
            return LocalPlayer:FindFirstChildOfClass('PlayerGui')
        end
    
        local function UpdateNoFlash()
            local gui = GetPlayerGui()
            local blind = gui and gui:FindFirstChild('Blnd')
            if not blind then
                return
            end
            if Toggles.Removals_NoFlash.Value then
                if FlashState == nil then
                    FlashState = blind.Enabled
                end
                blind.Enabled = false
            elseif FlashState ~= nil then
                blind.Enabled = FlashState
                FlashState = nil
            end
        end
    
        local function SetScopeTransparency(object, transparency)
            if ScopeTransparency[object] == nil then
                ScopeTransparency[object] = object.ImageTransparency
            end
            object.ImageTransparency = transparency
        end
    
        local function RestoreScope()
            for object, transparency in pairs(ScopeTransparency) do
                if object.Parent then
                    object.ImageTransparency = transparency
                end
                ScopeTransparency[object] = nil
            end
        end
    
        local function UpdateNoScope()
            local gui = GetPlayerGui()
            local root = gui and (gui:FindFirstChild('GUI') or gui:FindFirstChild('Client'))
            local crosshairs = root and root:FindFirstChild('Crosshairs')
            local scope = crosshairs and crosshairs:FindFirstChild('Scope')
    
            if Toggles.Removals_NoScope.Value then
                if not scope then
                    return
                end
                if scope:IsA('ImageLabel') or scope:IsA('ImageButton') then
                    SetScopeTransparency(scope, 1)
                end
                for _, item in ipairs(scope:GetDescendants()) do
                    if item:IsA('ImageLabel') or item:IsA('ImageButton') then
                        SetScopeTransparency(item, 1)
                    end
                end
            else
                RestoreScope()
            end
        end
    
        local function IsFireAnimation(track)
            local animation = track.Animation
            local name = animation and string.lower(animation.Name) or ''
            return name == 'fire' or name == 'fire2' or name == 'fire3'
                or name == 'aimfire' or name == 'fastfire' or name == 'fire_juggernaut'
        end
    
        local function BlockAnimation(track)
            if Toggles.Removals_NoWeaponAnimation.Value and IsFireAnimation(track) then
                track:Stop(0)
            end
        end
    
        local function DisconnectAnimator(animator)
            local connections = AnimationConnections[animator]
            if not connections then return end
            connections.played:Disconnect()
            connections.ancestry:Disconnect()
            AnimationConnections[animator] = nil
        end
    
        local function WatchAnimator(animator)
            if AnimationConnections[animator] then
                return
            end
    
            local connections = {}
            connections.played = animator.AnimationPlayed:Connect(BlockAnimation)
            connections.ancestry = animator.AncestryChanged:Connect(function(_, parent)
                if not parent then
                    DisconnectAnimator(animator)
                end
            end)
            AnimationConnections[animator] = connections
        end
    
        local function UpdateWeaponAnimations()
            if not Toggles.Removals_NoWeaponAnimation.Value then
                return
            end
            local camera = workspace.CurrentCamera
            local arms = camera and camera:FindFirstChild('Arms')
            if not arms then
                return
            end
            for _, item in ipairs(arms:GetDescendants()) do
                if item:IsA('Animator') then
                    WatchAnimator(item)
                    for _, track in ipairs(item:GetPlayingAnimationTracks()) do
                        BlockAnimation(track)
                    end
                end
            end
        end
    
        local function PollRemovals()
            local now = os.clock()
            if now < NextAnimationCheck then
                return
            end
            NextAnimationCheck = now + 0.1
            UpdateNoFlash()
            UpdateNoScope()
            UpdateWeaponAnimations()
        end
    
        local function RefreshPolling()
            local shouldPoll = Toggles.Removals_NoFlash.Value
                or Toggles.Removals_NoScope.Value
                or Toggles.Removals_NoWeaponAnimation.Value
            if shouldPoll then
                if not PollConnection then
                    NextAnimationCheck = 0
                    PollConnection = RunService.Heartbeat:Connect(PollRemovals)
                end
            elseif PollConnection then
                PollConnection:Disconnect()
                PollConnection = nil
            end
        end
    
        Toggles.Removals_NoSmoke:OnChanged(SetupNoSmoke)
        Toggles.Removals_NoFlash:OnChanged(function()
            UpdateNoFlash()
            RefreshPolling()
        end)
        Toggles.Removals_NoScope:OnChanged(function()
            UpdateNoScope()
            RefreshPolling()
        end)
        Toggles.Removals_NoWeaponAnimation:OnChanged(function()
            if Toggles.Removals_NoWeaponAnimation.Value then
                UpdateWeaponAnimations()
            else
                for animator in pairs(AnimationConnections) do
                    DisconnectAnimator(animator)
                end
            end
            RefreshPolling()
        end)
        RefreshPolling()
    
        AddUnload(function()
            if PollConnection then
                PollConnection:Disconnect()
                PollConnection = nil
            end
            DisconnectSmokes()
            if FlashState ~= nil then
                local gui = GetPlayerGui()
                local blind = gui and gui:FindFirstChild('Blnd')
                if blind then
                    blind.Enabled = FlashState
                end
                FlashState = nil
            end
            RestoreScope()
            for animator in pairs(AnimationConnections) do
                DisconnectAnimator(animator)
            end
        end)
    end
    
    local function Round(n)
        return math.floor(n + 0.5)
    end
    
    local UpdateInterval = 1 / 200
    local function SetUpdateRate(value)
        local rate = tonumber(value) or 200
        UpdateInterval = 1 / math.clamp(rate, 1, 600)
    end
    
    local function GetUpdateInterval()
        return UpdateInterval
    end
    
    local function Round2(v)
        if typeof(v) == 'Vector2' then
            return Vector2.new(Round(v.X), Round(v.Y))
        end
        return Round(v)
    end
    
    local PlayerSnapshot = PlayersService:GetPlayers()
    local PlayerSnapshotIndex = {}
    for i = 1, #PlayerSnapshot do
        PlayerSnapshotIndex[PlayerSnapshot[i]] = i
    end
    
    Library:GiveSignal(PlayersService.PlayerAdded:Connect(function(player)
        if PlayerSnapshotIndex[player] then return end
        PlayerSnapshot[#PlayerSnapshot + 1] = player
        PlayerSnapshotIndex[player] = #PlayerSnapshot
    end))
    
    Library:GiveSignal(PlayersService.PlayerRemoving:Connect(function(player)
        local index = PlayerSnapshotIndex[player]
        if not index then return end
    
        local last = PlayerSnapshot[#PlayerSnapshot]
        PlayerSnapshot[index] = last
        PlayerSnapshot[#PlayerSnapshot] = nil
        PlayerSnapshotIndex[player] = nil
        if last ~= player then
            PlayerSnapshotIndex[last] = index
        end
    end))

    local function IsCombatRoundActive()
        local status = workspace:FindFirstChild('Status')
        local preparation = status and status:FindFirstChild('Preparation')
        local gameOver = status and status:FindFirstChild('GameOver')
        return not (preparation and preparation.Value == true)
            and not (gameOver and gameOver.Value == true)
    end

    local function HasCombatProtection(character)
        return not character
            or character:FindFirstChild('PF') ~= nil
            or character:FindFirstChild('Shield') ~= nil
            or character:FindFirstChildOfClass('ForceField') ~= nil
    end
    
    local function MakeESPText()
        local ok, text = pcall(Drawing.new, 'Text')
        if not ok or not text then
            return nil
        end
        text.Visible = false
        text.Center = true
        text.Outline = true
        text.OutlineColor = Color3.new(0, 0, 0)
        text.Font = 2
        text.Size = 13
        text.Transparency = 1
        text.Color = Color3.new(1, 1, 1)
        text.Text = ''
        return text
    end
    
    local function IsTeammate(player)
        if not Toggles.ESP_TeamCheck.Value then
            return false
        end
    
        local localStatus = LocalPlayer:FindFirstChild('Status')
        local playerStatus = player:FindFirstChild('Status')
        if localStatus and playerStatus then
            local localTeam = localStatus:FindFirstChild('Team')
            local playerTeam = playerStatus:FindFirstChild('Team')
            if localTeam and playerTeam then
                return localTeam.Value == playerTeam.Value
            end
        end
    
        local lt, pt = LocalPlayer.Team, player.Team
        return lt ~= nil and pt ~= nil and lt == pt
    end

    local SharedRaycastIgnore = {}
    local NextSharedRaycastIgnoreUpdate = 0

    local function IsRaycastIgnoredTeammate(player)
        local localTeam, playerTeam = LocalPlayer.Team, player.Team
        if localTeam and playerTeam and localTeam == playerTeam then
            return true
        end
        if LocalPlayer.TeamColor and player.TeamColor and LocalPlayer.TeamColor == player.TeamColor then
            return true
        end

        local localStatus = LocalPlayer:FindFirstChild('Status')
        local playerStatus = player:FindFirstChild('Status')
        local localStatusTeam = localStatus and localStatus:FindFirstChild('Team')
        local playerStatusTeam = playerStatus and playerStatus:FindFirstChild('Team')
        return localStatusTeam and playerStatusTeam
            and localStatusTeam.Value ~= nil
            and playerStatusTeam.Value ~= nil
            and localStatusTeam.Value ~= ''
            and localStatusTeam.Value == playerStatusTeam.Value
    end

    local function GetSharedRaycastIgnore()
        local now = os.clock()
        if now < NextSharedRaycastIgnoreUpdate then
            return SharedRaycastIgnore
        end
        NextSharedRaycastIgnoreUpdate = now + 0.25
        table.clear(SharedRaycastIgnore)

        local count = 0
        local function add(instance)
            if instance then
                count = count + 1
                SharedRaycastIgnore[count] = instance
            end
        end

        add(GetRayIgnoreRoot())
        add(GetDebrisRoot())
        for i = 1, #PlayerSnapshot do
            local player = PlayerSnapshot[i]
            local character = player.Character
            local humanoid = character and character:FindFirstChildOfClass('Humanoid')
            if character and player ~= LocalPlayer
                and (IsRaycastIgnoredTeammate(player) or (humanoid and humanoid.Health <= 0))
            then
                add(character)
            end
        end
        return SharedRaycastIgnore
    end

    local function AppendSharedRaycastIgnore(ignore, startIndex)
        local shared = GetSharedRaycastIgnore()
        for i = 1, #shared do
            ignore[startIndex + i - 1] = shared[i]
        end
        local clearFrom = startIndex + #shared
        for i = clearFrom, #ignore do
            ignore[i] = nil
        end
    end
    
    local HITBOX_PRIORITY = { 'Head', 'Body', 'Arms', 'Legs' }
    local HITBOX_PARTS = {
        Head = { 'HeadHB', 'Head', 'FakeHead' },
        Body = { 'UpperTorso', 'LowerTorso', 'Torso', 'HumanoidRootPart' },
        Arms = {
            'LeftUpperArm', 'LeftLowerArm', 'LeftHand',
            'RightUpperArm', 'RightLowerArm', 'RightHand',
        },
        Legs = {
            'LeftUpperLeg', 'LeftLowerLeg', 'LeftFoot',
            'RightUpperLeg', 'RightLowerLeg', 'RightFoot',
        },
    }
    
    -- RageBot
    local GetShotHitChance
    local RageBot = RageTab:AddLeftGroupbox('RageBot')
    
    RageBot:AddToggle('RageBot_Enable', { Text = 'Enable', Default = false })
        :AddKeyPicker('RageBot_Key', {
            Default = 'None',
            Mode = 'Hold',
            Text = 'RageBot',
        })

    RageBot:AddToggle('RageBot_AutoFire', { Text = 'Auto fire', Default = true })
    
    RageBot:AddDropdown('RageBot_Hitbox', {
        Text = 'Hitbox',
        Values = { 'Head', 'Body', 'Arms', 'Legs' },
        Default = { 'Head' },
        Multi = true,
    })

    RageBot:AddToggle('RageBot_TeamCheck', { Text = 'TeamCheck', Default = true })
    RageBot:AddToggle('RageBot_ShowFov', { Text = 'Show Fov', Default = false })
    
    RageBot:AddSlider('RageBot_Fov', {
        Text = 'Fov',
        Default = 90,
        Min = 1,
        Max = 360,
        Rounding = 0,
    })

    RageBot:AddToggle('RageBot_AutoPenetration', { Text = 'AutoPenetration', Default = true })

    RageBot:AddDropdown('RageBot_PenMode', {
        Text = 'Penetration mode',
        Values = { 'Rage', 'Normal' },
        Default = 'Rage',
    })

    RageBot:AddSlider('RageBot_MaxWalls', {
        Text = 'Max wall (Rage)',
        Default = 3,
        Min = 1,
        Max = 15,
        Rounding = 0,
    })

    do
        local function UpdatePenModeUI()
            local isRage = Options.RageBot_PenMode.Value == 'Rage'
            local rageWalls = Options.RageBot_MaxWalls
            if type(rageWalls.SetVisible) == 'function' then
                rageWalls:SetVisible(isRage)
            end
        end
        Options.RageBot_PenMode:OnChanged(UpdatePenModeUI)
        UpdatePenModeUI()
    end

    local AntiAim = RageTab:AddLeftTabbox('Anti aim')
    local AntiAimPitch = AntiAim:AddTab('Pitch')
    AntiAimPitch:AddToggle('AntiAim_Pitch_Enable', { Text = 'Enable', Default = false })
    AntiAimPitch:AddDropdown('AntiAim_Pitch_Mode', {
        Text = 'Pitch mode',
        Values = { 'Up', 'Down', 'Custom', 'Random' },
        Default = 'Up',
    })
    AntiAimPitch:AddSlider('AntiAim_Pitch_RandomSpeed', {
        Text = 'Random speed',
        Default = 1,
        Min = 1,
        Max = 1000,
        Rounding = 0,
    })
    AntiAimPitch:AddSlider('AntiAim_Pitch_CustomValue', {
        Text = 'Custom value',
        Default = 0,
        Min = -1,
        Max = 1,
        Rounding = 2,
    })

    local AntiAimYaw = AntiAim:AddTab('Yaw')
    AntiAimYaw:AddToggle('AntiAim_Yaw_Enable', { Text = 'Enable', Default = false })
    AntiAimYaw:AddDropdown('AntiAim_Yaw_Type', {
        Text = 'Yaw type',
        Values = { 'Local', 'At target' },
        Default = 'Local',
    })
    AntiAimYaw:AddDropdown('AntiAim_Yaw_Mode', {
        Text = 'Yaw mode',
        Values = { 'Backwards', 'Forwards', 'Spin', 'Custom' },
        Default = 'Backwards',
    })
    AntiAimYaw:AddSlider('AntiAim_Yaw_SpinSpeed', {
        Text = 'Spin speed',
        Default = 1,
        Min = 1,
        Max = 1000,
        Rounding = 0,
    })
    AntiAimYaw:AddSlider('AntiAim_Yaw_CustomValue', {
        Text = 'Custom value',
        Default = 0,
        Min = -180,
        Max = 180,
        Rounding = 0,
    })

    do
        local function SetVisible(option, visible)
            if option and type(option.SetVisible) == 'function' then option:SetVisible(visible) end
        end
        local function UpdateAntiAimUI()
            SetVisible(Options.AntiAim_Pitch_RandomSpeed, Options.AntiAim_Pitch_Mode.Value == 'Random')
            SetVisible(Options.AntiAim_Pitch_CustomValue, Options.AntiAim_Pitch_Mode.Value == 'Custom')
            SetVisible(Options.AntiAim_Yaw_SpinSpeed, Options.AntiAim_Yaw_Mode.Value == 'Spin')
            SetVisible(Options.AntiAim_Yaw_CustomValue, Options.AntiAim_Yaw_Mode.Value == 'Custom')
        end
        Options.AntiAim_Pitch_Mode:OnChanged(UpdateAntiAimUI)
        Options.AntiAim_Yaw_Mode:OnChanged(UpdateAntiAimUI)
        UpdateAntiAimUI()
    end

    do
        local ControlTurnRemote
        local function GetControlTurnRemote()
            if ControlTurnRemote and ControlTurnRemote.Parent then return ControlTurnRemote end
            local events = GetEventsFolder()
            ControlTurnRemote = (events and events:FindFirstChild('ControlTurn'))
                or ReplicatedStorage:FindFirstChild('ControlTurn')
            return ControlTurnRemote
        end
        local function IsAntiAimTeammate(player)
            local localTeam, targetTeam = LocalPlayer.Team, player.Team
            if localTeam and targetTeam then return localTeam == targetTeam end
            local localStatus, targetStatus = LocalPlayer:FindFirstChild('Status'), player:FindFirstChild('Status')
            local localValue = localStatus and localStatus:FindFirstChild('Team')
            local targetValue = targetStatus and targetStatus:FindFirstChild('Team')
            return localValue and targetValue and localValue.Value == targetValue.Value
        end
        local function GetAntiAimTargetRoot(origin)
            local now = os.clock()
            if now - AntiAimState.targetAt >= 1 / 30 then
                AntiAimState.targetAt = now
                local bestRoot, bestDistance = nil, math.huge
                for i = 1, #PlayerSnapshot do
                    local player = PlayerSnapshot[i]
                    if player ~= LocalPlayer and (not Toggles.RageBot_TeamCheck.Value or not IsAntiAimTeammate(player)) then
                        local character = player.Character
                        local humanoid = character and character:FindFirstChildOfClass('Humanoid')
                        local root = character and character:FindFirstChild('HumanoidRootPart')
                        if root and humanoid and humanoid.Health > 0 and not HasCombatProtection(character) then
                            local distance = (root.Position - origin).Magnitude
                            if distance < bestDistance then bestRoot, bestDistance = root, distance end
                        end
                    end
                end
                AntiAimState.targetRoot = bestRoot
            end
            local root = AntiAimState.targetRoot
            return root and root.Parent and root or nil
        end
        local function UpdateAntiAim()
            local pitchEnabled = Toggles.AntiAim_Pitch_Enable.Value
            local yawEnabled = Toggles.AntiAim_Yaw_Enable.Value
            local character = LocalPlayer.Character
            local humanoid = character and character:FindFirstChildOfClass('Humanoid')
            local root = character and character:FindFirstChild('HumanoidRootPart')
            if not humanoid or not root then return end
            if not pitchEnabled and not yawEnabled then
                humanoid.AutoRotate = true
                return
            end
            if not IsCombatRoundActive() or HasCombatProtection(character) then
                humanoid.AutoRotate = true
                return
            end
            humanoid.AutoRotate = not yawEnabled

            if pitchEnabled then
                local remote = GetControlTurnRemote()
                if remote then pcall(function() remote:FireServer(GetAntiAimPitchValue()) end) end
            end
            if not yawEnabled then return end

            local baseYaw = 0
            if Options.AntiAim_Yaw_Type.Value == 'At target' then
                local targetRoot = GetAntiAimTargetRoot(root.Position)
                local direction = targetRoot and (targetRoot.Position - root.Position) * Vector3.new(1, 0, 1)
                if direction and direction.Magnitude > 0.1 then
                    baseYaw = math.deg(math.atan2(direction.X, direction.Z))
                end
            else
                local camera = workspace.CurrentCamera
                if camera then
                    local look = camera.CFrame.LookVector
                    baseYaw = math.deg(math.atan2(look.X, look.Z))
                end
            end

            local mode = Options.AntiAim_Yaw_Mode.Value
            local yaw = baseYaw
            if mode == 'Forwards' then
                yaw = yaw + 180
            elseif mode == 'Spin' then
                local now = os.clock()
                local speed = math.max(Options.AntiAim_Yaw_SpinSpeed.Value, 1)
                local elapsed = (now - AntiAimState.yawSpinAt) * 1000
                AntiAimState.yawSpin = (AntiAimState.yawSpin + elapsed / speed * 360) % 360
                AntiAimState.yawSpinAt = now
                yaw = yaw + AntiAimState.yawSpin
            elseif mode == 'Custom' then
                yaw = yaw + Options.AntiAim_Yaw_CustomValue.Value
            end
            root.CFrame = CFrame.new(root.Position, root.Position + Vector3.new(0, 0, -1))
                * CFrame.Angles(0, math.rad(yaw), 0)
        end
        Library:GiveSignal(RunService.RenderStepped:Connect(UpdateAntiAim))
        AddUnload(function()
            local humanoid = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass('Humanoid')
            if humanoid then humanoid.AutoRotate = true end
        end)
    end

    local RageExploit = RageTab:AddRightGroupbox('Exploit')

    RageExploit:AddToggle('RageExploit_KillAll', { Text = 'Kill all', Default = false })
        :AddKeyPicker('RageExploit_KillAllKey', {
            Default = 'None',
            Mode = 'Hold',
            Text = 'Kill all',
        })

    RageExploit:AddToggle('RageExploit_InfAmmo', { Text = 'Inf ammo', Default = false })
    RageExploit:AddToggle('RageExploit_NoFallDamage', { Text = 'No fall damage', Default = false })
    RageExploit:AddToggle('RageExploit_NoFireDamage', { Text = 'No fire damage', Default = false })
    
    do
        local RageHitboxOrder = { 'Head', 'Body', 'Arms', 'Legs' }
        local RageEnemyIgnore = {
            HumanoidRootPart = true,
            Gun = true,
            Head = true,
            BackC4 = true,
        }
        local RageEnemyIgnoreNames = { 'HumanoidRootPart', 'Gun', 'Head', 'BackC4' }
        for i = 1, 15 do
            local name = 'Hat' .. i
            RageEnemyIgnore[name] = true
            RageEnemyIgnoreNames[#RageEnemyIgnoreNames + 1] = name
        end
    
        -- Reused only during current scan. Dynamic ray hits cleared after every ray.
        local RageRayParams = RaycastParams.new()
        RageRayParams.FilterType = Enum.RaycastFilterType.Exclude
        RageRayParams.IgnoreWater = true
        local RageRayIgnore = {}
        local RageRayIgnoreCount = 0
        local RageFrameState = { teamPlayers = {} }
        local RagePartCache = setmetatable({}, { __mode = 'k' })
        local RageIgnorePartsCache = setmetatable({}, { __mode = 'k' })
        local RageSmokeRayParams = RaycastParams.new()
        RageSmokeRayParams.FilterType = Enum.RaycastFilterType.Include
        local RageSmokeInclude = {}
    
        local RageTarget = { part = nil, point = nil, walls = math.huge, damageMod = 1 }
        local RageSilentActive = false
        local RageInjecting = false
        local RageLastFire = 0
        local RageFireRate = 0.1
        local RageHeartbeat
        local RageFovConnection
        local RageFovCircle
        local RageNextFovUpdate = 0
        local RageFovViewportX = -1
        local RageFovViewportY = -1
        local RageKillAllRemote
        local RageKillAllLastRun = 0
        local RageKillAllPosition = { X = 0 / 0, Y = 0 / 0, Z = 0 / 0 }
        local RageKillAllDirection = Vector3.new(0, 1, 0)

        local function RageCamera()
            return workspace.CurrentCamera
        end
    
        local function RageSameTeam(player, frame)
            if not player or player == LocalPlayer then
                return false
            end
    
            local localTeam = frame and frame.localTeam or LocalPlayer.Team
            local playerTeam = player.Team
            if localTeam and playerTeam and localTeam == playerTeam then
                return true
            end
            local localTeamColor = frame and frame.localTeamColor or LocalPlayer.TeamColor
            local playerTeamColor = player.TeamColor
            if localTeamColor and playerTeamColor and localTeamColor == playerTeamColor then
                return true
            end
    
            local localStatus = frame and frame.localStatus or LocalPlayer:FindFirstChild('Status')
            local playerStatus = player:FindFirstChild('Status')
            local localStatusTeam = frame and frame.localStatusTeam
                or (localStatus and localStatus:FindFirstChild('Team'))
            local playerStatusTeam = playerStatus and playerStatus:FindFirstChild('Team')
            return localStatusTeam and playerStatusTeam
                and localStatusTeam.Value ~= nil
                and playerStatusTeam.Value ~= nil
                and localStatusTeam.Value ~= ''
                and localStatusTeam.Value == playerStatusTeam.Value
        end

        local function RageIsCachedTeammate(player, frame)
            local teamPlayers = frame and frame.teamPlayers
            if teamPlayers and teamPlayers[player] ~= nil then
                return teamPlayers[player]
            end
            return RageSameTeam(player, frame)
        end
    
        local function RageIsActive()
            return Toggles.RageBot_Enable.Value and Options.RageBot_Key:GetState()
        end
    
        local function RageIsEnemy(player, frame)
            local teamCheck = frame and frame.teamCheck or Toggles.RageBot_TeamCheck.Value
            if player == LocalPlayer then return false end
            if not teamCheck then return true end
            return not RageIsCachedTeammate(player, frame)
        end
    
        local function RageHasShield(character)
            return HasCombatProtection(character)
        end
    
        local function RageCanFire()
            local character = LocalPlayer.Character
            if not character then
                return false
            end
            if character:FindFirstChild('PF') or character:FindFirstChild('GroundSmashing') then
                return false
            end
    
            local humanoid = character:FindFirstChildOfClass('Humanoid')
            if not humanoid or humanoid.Health <= 0 or character:FindFirstChildOfClass('ForceField') then
                return false
            end
    
            local status = LocalPlayer:FindFirstChild('Status')
            local alive = status and status:FindFirstChild('Alive')
            if alive and alive.Value == false then
                return false
            end
    
            if not IsCombatRoundActive() then
                return false
            end
    
            local playerGui = LocalPlayer:FindFirstChild('PlayerGui')
            local defusal = playerGui and playerGui:FindFirstChild('GUI')
            defusal = defusal and defusal:FindFirstChild('Defusal')
            if defusal and defusal.Visible then
                return false
            end
    
            return not workspace:FindFirstChild('Cutscene')
                and not ReplicatedStorage:FindFirstChild('Cutscene')
        end
    
        local function RageIsPenModeRage()
            return (Options.RageBot_PenMode.Value or 'Rage') ~= 'Normal'
        end

        local function RageMaxWalls()
            if not Toggles.RageBot_AutoPenetration.Value then
                return 0
            end
            if RageIsPenModeRage() then
                return math.clamp(math.floor(tonumber(Options.RageBot_MaxWalls.Value) or 3), 0, 15)
            end
            return 4
        end

        local function RageGetPenetrationBudget()
            if not Toggles.RageBot_AutoPenetration.Value then
                return 0
            end
            local character = LocalPlayer.Character
            local equipped = character and character:FindFirstChild('EquippedTool')
            local gun = character and character:FindFirstChild('Gun')
            local gunName = equipped and type(equipped.Value) == 'string' and equipped.Value ~= '' and equipped.Value
                or (gun and gun.Name)
            local weapons = gunName and GetWeaponsFolder()
            local gunData = weapons and weapons:FindFirstChild(gunName)
            local penetration = gunData and gunData:FindFirstChild('Penetration')
            return penetration and type(penetration.Value) == 'number' and math.max(penetration.Value, 0) * 0.01 or 0
        end
    
        local function RageHitboxOn(name, selected)
            selected = selected == nil and Options.RageBot_Hitbox.Value or selected
            if type(selected) ~= 'table' then
                return selected == name
            end
            if selected[name] == true then
                return true
            end
            for i = 1, #selected do
                if selected[i] == name then
                    return true
                end
            end
            return false
        end
    
        local function RageIsSmokeLike(instance)
            if not instance then
                return false
            end
            local name = instance.Name
            if name == 'Smoke'
                or name:find('Smoke')
                or name:find('Fire')
                or name:find('Flame')
                or name:find('Molotov')
                or name:find('Burn')
            then
                return true
            end
            if instance.Material == Enum.Material.Glass and instance.Transparency > 0.5 then
                return true
            end
            return instance.Transparency >= 0.9 and not instance.CanCollide
        end
    
        local function RageClearRayIgnore(keepCount)
            for i = keepCount + 1, RageRayIgnoreCount do
                RageRayIgnore[i] = nil
            end
            RageRayIgnoreCount = keepCount
        end
    
        local function RageAddRayIgnore(instance)
            if instance then
                RageRayIgnoreCount = RageRayIgnoreCount + 1
                RageRayIgnore[RageRayIgnoreCount] = instance
            end
        end
    
        local function RageBuildFrameState(camera)
            local frame = RageFrameState
            local cameraCFrame = camera.CFrame
            local selectedHitboxes = Options.RageBot_Hitbox.Value
            local localStatus = LocalPlayer:FindFirstChild('Status')
    
            frame.camera = camera
            frame.active = true
            frame.origin = cameraCFrame.Position
            frame.lookVector = cameraCFrame.LookVector
            frame.localCharacter = LocalPlayer.Character
            frame.localTeam = LocalPlayer.Team
            frame.localTeamColor = LocalPlayer.TeamColor
            frame.localStatus = localStatus
            frame.localStatusTeam = localStatus and localStatus:FindFirstChild('Team')
            frame.teamCheck = Toggles.RageBot_TeamCheck.Value
            frame.maxWalls = RageMaxWalls()
            frame.penModeRage = RageIsPenModeRage()
            frame.penetrationBudget = frame.penModeRage and 0 or RageGetPenetrationBudget()
            frame.rayIgnoreRoot = GetRayIgnoreRoot()
            frame.debrisRoot = GetDebrisRoot()
            frame.clipsRoot = GetMapClips()
            frame.spawnPointsRoot = GetMapSpawnPoints()
            frame.hitboxHead = RageHitboxOn('Head', selectedHitboxes)
            frame.hitboxBody = RageHitboxOn('Body', selectedHitboxes)
            frame.hitboxArms = RageHitboxOn('Arms', selectedHitboxes)
            frame.hitboxLegs = RageHitboxOn('Legs', selectedHitboxes)
    
            local fov = math.clamp(tonumber(Options.RageBot_Fov.Value) or 90, 1, 360)
            frame.minimumDot = fov >= 360 and -1 or math.cos(math.rad(fov * 0.5))
    
            RageClearRayIgnore(0)
            RageAddRayIgnore(camera)
            RageAddRayIgnore(frame.localCharacter)
            RageAddRayIgnore(frame.rayIgnoreRoot)
            RageAddRayIgnore(frame.debrisRoot)
            RageAddRayIgnore(frame.clipsRoot)
            RageAddRayIgnore(frame.spawnPointsRoot)
    
            local teamPlayers = frame.teamPlayers
            table.clear(teamPlayers)
            for i = 1, #PlayerSnapshot do
                local player = PlayerSnapshot[i]
                if player ~= LocalPlayer then
                    local isTeammate = IsRaycastIgnoredTeammate(player)
                    teamPlayers[player] = isTeammate
                    local character = player.Character
                    if character then
                        local humanoid = character:FindFirstChildOfClass('Humanoid')
                        if isTeammate or (humanoid and humanoid.Health <= 0) then
                            RageAddRayIgnore(character)
                        else
                            local ignoreParts = RageIgnorePartsCache[character]
                            if not ignoreParts then
                                ignoreParts = {}
                                for j = 1, #RageEnemyIgnoreNames do
                                    local part = character:FindFirstChild(RageEnemyIgnoreNames[j])
                                    if part then
                                        ignoreParts[#ignoreParts + 1] = part
                                    end
                                end
                                RageIgnorePartsCache[character] = ignoreParts
                            end
                            for j = 1, #ignoreParts do
                                RageAddRayIgnore(ignoreParts[j])
                            end
                        end
                    end
                end
            end
    
            frame.baseIgnoreCount = RageRayIgnoreCount
            RageRayParams.FilterDescendantsInstances = RageRayIgnore
            return frame
        end
    
        local function RageClearFrameState()
            local frame = RageFrameState
            if not frame.active then
                return
            end
            frame.active = false
            frame.camera = nil
            frame.localCharacter = nil
            frame.localTeam = nil
            frame.localTeamColor = nil
            frame.localStatus = nil
            frame.localStatusTeam = nil
            frame.rayIgnoreRoot = nil
            frame.debrisRoot = nil
            frame.clipsRoot = nil
            frame.spawnPointsRoot = nil
            if frame.teamPlayers then
                table.clear(frame.teamPlayers)
            end
        end

        local function RageGetPlayerFromHit(instance)
            local current = instance
            while current and current ~= workspace do
                if current:IsA('Model') then
                    local player = PlayersService:GetPlayerFromCharacter(current)
                    if player then return player end
                end
                current = current.Parent
            end
        end
    
        local function RageShouldPierce(instance, frame)
            if not instance then
                return false
            end
            local modifier = instance:FindFirstChild('PartModifier')
            if modifier and type(modifier.Value) == 'number' then
                return modifier.Value <= 0
            end
            if instance.Name == 'nowallbang' then
                return false
            end
            if RageIsSmokeLike(instance) or instance.CanQuery == false or instance.Transparency >= 1 then
                return true
            end
            if instance.Name == 'Glass' or instance.Name == 'Cardboard' or not instance.CanCollide then
                return true
            end
    
            local root = frame.rayIgnoreRoot
            if root and (instance == root or instance:IsDescendantOf(root)) then return true end
            root = frame.debrisRoot
            if root and (instance == root or instance:IsDescendantOf(root)) then return true end
            root = frame.clipsRoot
            if root and (instance == root or instance:IsDescendantOf(root)) then return true end
            root = frame.spawnPointsRoot
            if root and (instance == root or instance:IsDescendantOf(root)) then return true end
            root = frame.camera
            if root and (instance == root or instance:IsDescendantOf(root)) then return true end
            root = frame.localCharacter
            if root and (instance == root or instance:IsDescendantOf(root)) then return true end
    
            if RageEnemyIgnore[instance.Name] then
                if RageGetPlayerFromHit(instance) then
                    return true
                end
            end
    
            if frame.teamCheck then
                local player = RageGetPlayerFromHit(instance)
                if player and RageIsCachedTeammate(player, frame) then
                    return true
                end
            end
            return false
        end

        local function RageGetPenetrationFactor(instance, frame)
            if not instance then
                return 1
            end

            local factor = 1
            local material = instance.Material
            if material == Enum.Material.DiamondPlate then
                factor = 3
            end
            if material == Enum.Material.CorrodedMetal
                or material == Enum.Material.Metal
                or material == Enum.Material.Concrete
                or material == Enum.Material.Brick
            then
                factor = 2
            end

            local parent = instance.Parent
            if instance.Name == 'Grate'
                or material == Enum.Material.Wood
                or material == Enum.Material.WoodPlanks
                or (parent and parent:FindFirstChildOfClass('Humanoid'))
            then
                factor = 0.1
            end

            if instance.Transparency == 1
                or instance.CanCollide == false
                or instance.Name == 'Glass'
                or instance.Name == 'Cardboard'
                or (frame.rayIgnoreRoot and instance:IsDescendantOf(frame.rayIgnoreRoot))
                or (frame.debrisRoot and instance:IsDescendantOf(frame.debrisRoot))
                or (parent and parent.Name == 'Hitboxes')
            then
                factor = 0
            end

            if instance.Name == 'nowallbang' then
                factor = 100
            end

            local modifier = instance:FindFirstChild('PartModifier')
            if modifier and type(modifier.Value) == 'number' then
                factor = modifier.Value
            end

            return factor
        end

        local RagePenetrationParams = RaycastParams.new()
        RagePenetrationParams.FilterType = Enum.RaycastFilterType.Include
        RagePenetrationParams.IgnoreWater = true
        local RagePenetrationInclude = {}

        local function RageGetPenetrationThickness(instance, hitPosition, direction)
            RagePenetrationInclude[1] = instance
            RagePenetrationParams.FilterDescendantsInstances = RagePenetrationInclude
            local result = workspace:Raycast(hitPosition + direction, direction * -2, RagePenetrationParams)
            RagePenetrationInclude[1] = nil
            if result then
                return (result.Position - hitPosition).Magnitude
            end
            return ((hitPosition + direction) + direction * -2 - hitPosition).Magnitude
        end

        local function RageFinishWallRay(frame)
            RageClearRayIgnore(frame.baseIgnoreCount)
            RageRayParams.FilterDescendantsInstances = RageRayIgnore
        end
    
        local function RageGetWallCount(frame, targetPosition, targetCharacter)
            local originPosition = frame.origin
            local delta = targetPosition - originPosition
            if delta.Magnitude < 0.001 then
                return 0, 1
            end
    
            local maxWalls = frame.maxWalls
            local penModeRage = frame.penModeRage
            local penetrationBudget = frame.penetrationBudget or 0
            local penetrationUsed = 0
            local damageMod = 1
            local direction = delta.Unit
            local wallCount = 0
            local origin = originPosition
            for _ = 1, maxWalls + 8 do
                local remaining = targetPosition - origin
                if remaining.Magnitude < 0.05 then
                    break
                end
    
                local result = workspace:Raycast(origin, remaining, RageRayParams)
                if not result or not result.Instance then
                    break
                end
    
                local instance = result.Instance
                local parent = instance.Parent
                if instance == targetCharacter or (targetCharacter and instance:IsDescendantOf(targetCharacter)) then
                    break
                end

                if penModeRage then
                    if parent and parent:FindFirstChildOfClass('Humanoid') then
                        if targetCharacter and parent == targetCharacter then
                            break
                        end
                    elseif not RageShouldPierce(instance, frame) then
                        wallCount = wallCount + 1
                        if wallCount > maxWalls then
                            break
                        end
                    end
                else
                    local factor = RageGetPenetrationFactor(instance, frame)
                    if factor > 0 then
                        wallCount = wallCount + 1
                        if wallCount > maxWalls then
                            wallCount = maxWalls + 1
                            break
                        end

                        local thickness = RageGetPenetrationThickness(instance, result.Position, direction)
                        penetrationUsed = math.min(penetrationBudget, penetrationUsed + thickness * factor)
                        if penetrationBudget <= 0 then
                            wallCount = maxWalls + 1
                            break
                        end
                        damageMod = 1 - penetrationUsed / penetrationBudget
                        if penetrationUsed >= penetrationBudget or damageMod <= 0 then
                            wallCount = maxWalls + 1
                            break
                        end
                    end
                end
    
                RageAddRayIgnore(instance)
                RageRayParams.FilterDescendantsInstances = RageRayIgnore
                origin = result.Position + direction * 0.05
            end
    
            RageFinishWallRay(frame)
            return wallCount, penModeRage and 1 or math.clamp(damageMod, 0, 1)
        end
    
        local function RageGetAimDot(position, origin, lookVector)
            local delta = position - origin
            local magnitude = delta.Magnitude
            if magnitude <= 1e-4 then
                return nil
            end
            return lookVector:Dot(delta / magnitude)
        end

        local function RageGetCachedPart(character, name)
            local cache = RagePartCache[character]
            if not cache then
                cache = {}
                RagePartCache[character] = cache
            end

            local part = cache[name]
            if part and part.Parent == character then
                return part
            end

            part = character:FindFirstChild(name)
            cache[name] = part
            return part
        end

        local function RageIsHitboxEnabled(frame, group)
            return group == 'Head' and frame.hitboxHead
                or group == 'Body' and frame.hitboxBody
                or group == 'Arms' and frame.hitboxArms
                or group == 'Legs' and frame.hitboxLegs
        end
    
        local function RagePickHitbox(frame, character)
            for i = 1, #RageHitboxOrder do
                local group = RageHitboxOrder[i]
                if not RageIsHitboxEnabled(frame, group) then
                    continue
                end
    
                local names = HITBOX_PARTS[group]
                local bestPart, bestPoint, bestDot = nil, nil, -math.huge
                for j = 1, #names do
                    local part = RageGetCachedPart(character, names[j])
                    if not part or not part:IsA('BasePart') then
                        continue
                    end
                    local point = part.Position
                    local dot = RageGetAimDot(point, frame.origin, frame.lookVector)
                    if not dot or dot < frame.minimumDot or dot <= bestDot then
                        continue
                    end
                    bestPart, bestPoint, bestDot = part, point, dot
                end

                -- One wall raycast path per hitbox group; AutoFire/HitParl reuse RageTarget.walls.
                if bestPart then
                    local walls, damageMod = RageGetWallCount(frame, bestPoint, character)
                    if walls <= frame.maxWalls then
                        return bestPart, bestPoint, walls, bestDot, damageMod
                    end
                end
            end
            return nil, nil, math.huge, nil, 1
        end
    
        local function RageScanTargets(frame)
            local bestDot = -math.huge
    
            for i = 1, #PlayerSnapshot do
                local player = PlayerSnapshot[i]
                if not RageIsEnemy(player, frame) then
                    continue
                end
    
                local character = player.Character
                local humanoid = character and character:FindFirstChildOfClass('Humanoid')
                local root = character and character:FindFirstChild('HumanoidRootPart')
                if not character or not humanoid or humanoid.Health <= 0 or not root or RageHasShield(character) then
                    continue
                end
    
                local part, point, walls, dot, damageMod = RagePickHitbox(frame, character)
                if not part or not point or walls > frame.maxWalls then
                    continue
                end
                if dot and dot >= frame.minimumDot and dot > bestDot then
                    bestDot = dot
                    RageTarget.part, RageTarget.point, RageTarget.walls, RageTarget.damageMod =
                        part, point, walls, damageMod or 1
                end
            end
        end
    
        local function RageGetGunContext()
            local character = LocalPlayer.Character
            local gun = character and character:FindFirstChild('Gun')
            local equipped = character and character:FindFirstChild('EquippedTool')
            if not gun or not equipped then
                return nil, nil, nil, 0.1
            end
    
            local gunName = type(equipped.Value) == 'string' and equipped.Value ~= '' and equipped.Value or gun.Name
            local weapons = GetWeaponsFolder()
            local gunData = weapons and weapons:FindFirstChild(gunName)
            local fireRate = gunData and gunData:FindFirstChild('FireRate')
            local rate = fireRate and fireRate:IsA('NumberValue') and fireRate.Value > 0 and fireRate.Value or 0.1
            return gunName, gun, gunData, rate
        end

        local function RageShotFlags(gunData, cameraPosition, hitPosition)
            local playerGui = LocalPlayer:FindFirstChild('PlayerGui')
            local blind = playerGui and playerGui:FindFirstChild('Blnd')
            blind = blind and blind:FindFirstChild('Blind')
            local flashed = blind and blind.BackgroundTransparency < 0.4 or false
    
            local noScope = false
            if gunData and gunData:FindFirstChild('snipo') then
                local gui = playerGui and (playerGui:FindFirstChild('GUI') or playerGui:FindFirstChild('Client'))
                local crosshairs = gui and gui:FindFirstChild('Crosshairs')
                local scope = crosshairs and crosshairs:FindFirstChild('Scope')
                noScope = not (scope and scope.Visible)
            end
    
            local airborne = false
            local humanoid = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass('Humanoid')
            if humanoid then
                local state = humanoid:GetState()
                airborne = state == Enum.HumanoidStateType.Freefall
                    or state == Enum.HumanoidStateType.Jumping
                    or humanoid.FloorMaterial == Enum.Material.Air
            end
    
            local smoke = false
            local rayIgnore = GetRayIgnoreRoot()
            local smokes = rayIgnore and rayIgnore:FindFirstChild('Smokes')
            if smokes and typeof(hitPosition) == 'Vector3' then
                RageSmokeInclude[1] = smokes
                RageSmokeRayParams.FilterDescendantsInstances = RageSmokeInclude
                local result = workspace:Raycast(cameraPosition, hitPosition - cameraPosition, RageSmokeRayParams)
                smoke = result and result.Instance and result.Instance:GetAttribute('Enabled') == true or false
                RageSmokeInclude[1] = nil
            end
            return flashed, noScope, smoke, airborne
        end
    
        local function RageApplyHitParl(args)
            if RageInjecting or not RageSilentActive or not RageIsActive() or not RageCanFire() then
                return args
            end
    
            local target = RageTarget.part
            local hitPosition = RageTarget.point
            if not target or not target.Parent then
                return args
            end
    
            local targetCharacter = target:FindFirstAncestorOfClass('Model') or target.Parent
            if RageHasShield(targetCharacter) then
                return args
            end
            if typeof(hitPosition) ~= 'Vector3' then
                hitPosition = target.Position
            end
    
            -- Reuse scan raycast result (no second wall ray for silent/autofire).
            local walls = RageTarget.walls
            local maxWalls = RageMaxWalls()
            if walls > maxWalls then
                return args
            end
    
            local fireGun = args[5]
            if typeof(fireGun) == 'Instance' and fireGun:FindFirstChild('Melee') then
                local meleeRange = 64
                local weapons = GetWeaponsFolder()
                local weapon = weapons and type(args[3]) == 'string' and weapons:FindFirstChild(args[3])
                local range = weapon and weapon:FindFirstChild('Range')
                if range and type(range.Value) == 'number' then
                    meleeRange = math.clamp(range.Value, 1, 64)
                end
    
                local camera = RageCamera()
                if camera and (hitPosition - camera.CFrame.Position).Magnitude > meleeRange then
                    return args
                end
                args[4] = meleeRange
            end
    
            args[1] = target
            args[2] = { X = 0 / 0, Y = 0 / 0, Z = 0 / 0 }
            if type(args[4]) ~= 'number' or args[4] <= 0 then
                args[4] = 4096
            end
            if not RageIsPenModeRage() then
                local damageMod = RageTarget.damageMod
                args[7] = type(damageMod) == 'number' and math.clamp(damageMod, 0, 1) or 1
            end
            args[9] = walls > 0
    
            local cameraPosition = typeof(args[10]) == 'Vector3' and args[10] or nil
            if not cameraPosition then
                local camera = RageCamera()
                cameraPosition = camera and camera.CFrame.Position
                if cameraPosition then
                    args[10] = cameraPosition
                end
            end
            if cameraPosition then
                local direction = hitPosition - cameraPosition
                if direction.Magnitude > 0.001 then
                    args[12] = direction.Unit
                end
            end
            return args
        end
    
        HandleRageHitParl = nil
    
        local function RageFireHit(target, aimPoint, gunName, characterGun, gunData, events)
            if RageInjecting or not target or not target.Parent or not RageSilentActive or not RageCanFire() then
                return false
            end
    
            local targetCharacter = target:FindFirstAncestorOfClass('Model') or target.Parent
            if RageHasShield(targetCharacter) then
                return false
            end
    
            if not gunName or not characterGun then
                gunName, characterGun, gunData = RageGetGunContext()
            end
            if not gunName or not characterGun then
                return false
            end
    
            events = events or GetEventsFolder()
            local hitParl = events and events:FindFirstChild('HitParl')
            if not hitParl then
                return false
            end
    
            local camera = RageCamera()
            if not camera then
                return false
            end
    
            local hitPosition = typeof(aimPoint) == 'Vector3' and aimPoint or target.Position
            local cameraPosition = camera.CFrame.Position
            local direction = hitPosition - cameraPosition
            local distance = direction.Magnitude
            if distance < 0.001 then
                return false
            end
            direction = direction / distance
    
            local range = 4096
            if gunData then
                local rangeValue = gunData:FindFirstChild('Range')
                if rangeValue and type(rangeValue.Value) == 'number' and rangeValue.Value > 0 then
                    range = rangeValue.Value
                end
            end
            if gunData and gunData:FindFirstChild('Melee') then
                range = math.clamp(range > 0 and range or 64, 1, 64)
                if distance > range then
                    return false
                end
            end
    
            -- Reuse scan raycast result (no second wall ray for autofire).
            local walls = RageTarget.walls
            local maxWalls = RageMaxWalls()
            if walls > maxWalls then
                return false
            end
    
            local damageMod = 1
            if not RageIsPenModeRage() then
                damageMod = type(RageTarget.damageMod) == 'number' and math.clamp(RageTarget.damageMod, 0, 1) or 1
            end

            local flashed, noScope, smoke, airborne = RageShotFlags(gunData, cameraPosition, hitPosition)
            if smoke then
                return false
            end
    
            local position = { X = 0 / 0, Y = 0 / 0, Z = 0 / 0 }
            local serverTime = workspace:GetServerTimeNow()
            local previousRageHandler = HandleRageHitParl
            HandleRageHitParl = nil
            RageInjecting = true
            local fired = pcall(function()
                hitParl:FireServer(
                    target,
                    position,
                    gunName,
                    range,
                    characterGun,
                    nil,
                    damageMod,
                    range == 48,
                    walls > 0,
                    cameraPosition,
                    serverTime,
                    direction,
                    flashed,
                    noScope,
                    smoke,
                    airborne,
                    true,
                    nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil
                )
            end)
            RageInjecting = false
            HandleRageHitParl = previousRageHandler
            return fired
        end
    
        local function RageFireWeapon(events)
            events = events or GetEventsFolder()
            local weapon = events and events:FindFirstChild('weap')
            if not weapon then
                return false
            end
            return pcall(function()
                weapon:Fire()
            end)
        end

        local function RageKillAllActive()
            return Toggles.RageExploit_KillAll.Value and Options.RageExploit_KillAllKey:GetState()
        end

        local function RageGetKillAllRemote()
            if RageKillAllRemote and RageKillAllRemote.Parent then
                return RageKillAllRemote
            end
            local events = GetEventsFolder()
            local remote = events and events:FindFirstChild('HitParl')
            RageKillAllRemote = remote and remote:IsA('RemoteEvent') and remote or nil
            return RageKillAllRemote
        end

        local function RageUpdateKillAll()
            if not RageKillAllActive() then return end

            local now = os.clock()
            if now - RageKillAllLastRun < 0.05 then return end
            RageKillAllLastRun = now

            local character = LocalPlayer.Character
            local humanoid = character and character:FindFirstChildOfClass('Humanoid')
            local gun = character and character:FindFirstChild('Gun')
            local equipped = character and character:FindFirstChild('EquippedTool')
            if not humanoid or humanoid.Health <= 0 or not gun or not equipped then return end

            local remote = RageGetKillAllRemote()
            local camera = RageCamera()
            if not remote or not camera then return end

            local gunName = 'AWP'
            local weapons = GetWeaponsFolder()
            local gunReference = weapons and weapons:FindFirstChild(gunName) or gun
            local cameraPosition = camera.CFrame.Position
            local serverTime = workspace:GetServerTimeNow()
            local teamCheck = Toggles.RageBot_TeamCheck.Value

            RageInjecting = true
            for i = 1, #PlayerSnapshot do
                local player = PlayerSnapshot[i]
                if player == LocalPlayer or (teamCheck and RageSameTeam(player)) then
                    continue
                end

                local targetCharacter = player.Character
                local targetHumanoid = targetCharacter and targetCharacter:FindFirstChildOfClass('Humanoid')
                local head = targetCharacter and (targetCharacter:FindFirstChild('Head') or targetCharacter:FindFirstChild('HeadHB'))
                if not head or not targetHumanoid or targetHumanoid.Health <= 0 or RageHasShield(targetCharacter) then
                    continue
                end

                for _ = 1, 2 do
                    pcall(function()
                        remote:FireServer(
                            head,
                            RageKillAllPosition,
                            gunName,
                            4096,
                            gunReference,
                            nil,
                            1,
                            false,
                            true,
                            cameraPosition,
                            serverTime,
                            RageKillAllDirection,
                            true, true, true, true, true,
                            nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil
                        )
                    end)
                end
            end
            RageInjecting = false
        end
    
        local RageNextUpdate = 0
        local RAGE_UPDATE_INTERVAL = 1 / 144

        local function RageUpdate()
            local now = os.clock()
            if now < RageNextUpdate then
                return
            end
            RageNextUpdate = now + RAGE_UPDATE_INTERVAL

            RageTarget.part, RageTarget.point, RageTarget.walls, RageTarget.damageMod = nil, nil, math.huge, 1
            RageSilentActive = RageIsActive() and RageCanFire()
            HandleRageHitParl = RageSilentActive and RageApplyHitParl or nil
            RageUpdateKillAll()
            if not RageSilentActive then
                RageClearRayIgnore(0)
                RageClearFrameState()
                return
            end
    
            local camera = RageCamera()
            if not camera then
                HandleRageHitParl = nil
                RageClearRayIgnore(0)
                RageClearFrameState()
                return
            end
    
            local frame = RageBuildFrameState(camera)
            RageScanTargets(frame)
            if not Toggles.RageBot_AutoFire.Value then
                return
            end
    
            local target, point = RageTarget.part, RageTarget.point
            if not target or not target.Parent or typeof(point) ~= 'Vector3' then
                return
            end
            local targetCharacter = target:FindFirstAncestorOfClass('Model') or target.Parent
            if RageHasShield(targetCharacter) then
                return
            end
    
            local now = os.clock()
            local gunName, characterGun, gunData, rate = RageGetGunContext()
            RageFireRate = rate
            if now - RageLastFire < RageFireRate then
                return
            end
    
            local events = GetEventsFolder()
            if RageFireWeapon(events) then
                RageLastFire = now
                RageFireHit(target, point, gunName, characterGun, gunData, events)
            end
        end
    
        local function RageMakeFovCircle()
            local ok, circle = pcall(Drawing.new, 'Circle')
            if not ok or not circle then
                return nil
            end
            circle.Visible = false
            circle.Thickness = 1.5
            circle.NumSides = 48
            circle.Filled = false
            circle.Color = Color3.fromRGB(255, 255, 255)
            return circle
        end
    
        local function RageGetFovRadius(camera)
            local fov = math.clamp(tonumber(Options.RageBot_Fov.Value) or 90, 1, 360)
            if fov >= 180 then
                return 100000
            end
            local halfViewport = camera.ViewportSize.Y * 0.5
            local cameraHalfAngle = math.tan(math.rad(camera.FieldOfView * 0.5))
            if cameraHalfAngle <= 0 then
                return 0
            end
            return math.tan(math.rad(fov * 0.5)) / cameraHalfAngle * halfViewport
        end
    
        local function RageUpdateFov(camera)
            local show = Toggles.RageBot_Enable.Value and Toggles.RageBot_ShowFov.Value
            if not show then
                if RageFovCircle then
                    RageFovCircle.Visible = false
                end
                return
            end
    
            if not RageFovCircle then
                RageFovCircle = RageMakeFovCircle()
                RageFovViewportX, RageFovViewportY = -1, -1
            end
            if not RageFovCircle then
                return
            end
    
            local viewport = camera.ViewportSize
            if viewport.X ~= RageFovViewportX or viewport.Y ~= RageFovViewportY then
                RageFovViewportX, RageFovViewportY = viewport.X, viewport.Y
                RageFovCircle.Position = Vector2.new(viewport.X * 0.5, viewport.Y * 0.5)
            end
            RageFovCircle.Radius = math.min(RageGetFovRadius(camera), 100000)
            RageFovCircle.Visible = true
        end
    
        Library:GiveSignal(PlayersService.PlayerRemoving:Connect(function(player)
            local character = player.Character
            if character then
                RagePartCache[character] = nil
                RageIgnorePartsCache[character] = nil
            end
            RageFrameState.teamPlayers[player] = nil
        end))

        local function RageBindCharacterCache(player)
            Library:GiveSignal(player.CharacterRemoving:Connect(function(character)
                RagePartCache[character] = nil
                RageIgnorePartsCache[character] = nil
            end))
        end

        for i = 1, #PlayerSnapshot do
            RageBindCharacterCache(PlayerSnapshot[i])
        end
        Library:GiveSignal(PlayersService.PlayerAdded:Connect(RageBindCharacterCache))

        RageHeartbeat = RunService.Heartbeat:Connect(RageUpdate)
        RageFovConnection = RunService.RenderStepped:Connect(function()
            if not Toggles.RageBot_Enable.Value or not Toggles.RageBot_ShowFov.Value then
                if RageFovCircle then
                    RageFovCircle.Visible = false
                end
                return
            end
    
            local now = os.clock()
            if now < RageNextFovUpdate then
                return
            end
            RageNextFovUpdate = now + 1 / 60
            local camera = RageCamera()
            if camera then
                RageUpdateFov(camera)
            elseif RageFovCircle then
                RageFovCircle.Visible = false
            end
        end)
        Library:GiveSignal(RageHeartbeat)
        Library:GiveSignal(RageFovConnection)
    
        AddUnload(function()
            HandleRageHitParl = nil
            RageSilentActive = false
            RageInjecting = false
            RageTarget.part, RageTarget.point, RageTarget.walls, RageTarget.damageMod = nil, nil, math.huge, 1
            RageClearRayIgnore(0)
            RageClearFrameState()
            RageSmokeInclude[1] = nil

            if RageHeartbeat then
                RageHeartbeat:Disconnect()
                RageHeartbeat = nil
            end
            if RageFovConnection then
                RageFovConnection:Disconnect()
                RageFovConnection = nil
            end

            if RageFovCircle then
                RageFovCircle.Visible = false
                pcall(function()
                    RageFovCircle:Remove()
                end)
                RageFovCircle = nil
                RageFovViewportX, RageFovViewportY = -1, -1
            end
        end)
    end

    -- Inf ammo (from InfAmmo.lua — blocks ParticleRemote kick on ammocount > 150)
    do
        local State = {
            ammoTable = nil,
            lastScan = 0,
            scanBackoff = 0.5,
            scanning = false,
            lastGcScan = 0,
            clientScript = nil,
            clientEnv = nil,
            originalAmmo = nil,
            heartbeat = nil,
            charConn = nil,
            oldNamecall = nil,
            hooked = false,
        }

        local function isAmmoTable(obj)
            if type(obj) ~= 'table' then
                return false
            end
            local a1 = rawget(obj, 'ammocount')
            local a2 = rawget(obj, 'ammocount2')
            local a3 = rawget(obj, 'ammocount3')
            local a4 = rawget(obj, 'ammocount4')
            return type(a1) == 'number'
                and type(a2) == 'number'
                and type(a3) == 'number'
                and type(a4) == 'number'
                and rawget(obj, 'DISABLED') ~= nil
                and rawget(obj, 'reloading') ~= nil
        end

        local function getClientEnv()
            local pg = LocalPlayer:FindFirstChild('PlayerGui')
            local cg = pg and pg:FindFirstChild('Client')
            if not cg then
                State.clientScript = nil
                State.clientEnv = nil
                return nil
            end
            if State.clientScript == cg and State.clientEnv ~= nil then
                return State.clientEnv
            end
            State.clientScript = cg
            if type(getsenv) ~= 'function' then
                State.clientEnv = nil
                return nil
            end
            local ok, env = pcall(getsenv, cg)
            State.clientEnv = ok and env or nil
            return State.clientEnv
        end

        local function findAmmoTable()
            local client = getClientEnv()
            if type(client) == 'table' then
                if isAmmoTable(client) then
                    return client
                end
                for _, obj in pairs(client) do
                    if isAmmoTable(obj) then
                        return obj
                    end
                end
                if debug and type(debug.getupvalue) == 'function' then
                    local names = { 'usethatgun', 'loadammo', 'isgrenade', 'updatesilencer', 'resetguns', 'countammo' }
                    for i = 1, #names do
                        local fn = rawget(client, names[i])
                        if type(fn) == 'function' then
                            local ok, found = pcall(function()
                                for ui = 1, 64 do
                                    local name, val = debug.getupvalue(fn, ui)
                                    if name == nil and val == nil then
                                        break
                                    end
                                    if isAmmoTable(val) then
                                        return val
                                    end
                                end
                                return nil
                            end)
                            if ok and found then
                                return found
                            end
                        end
                    end
                end
            end

            local now = tick()
            if getgc and now - State.lastGcScan >= 5 then
                State.lastGcScan = now
                local ok, objects = pcall(getgc, true)
                if ok and type(objects) == 'table' then
                    for _, obj in ipairs(objects) do
                        if isAmmoTable(obj) then
                            return obj
                        end
                    end
                end
            end

            return nil
        end

        local function requestScan(force)
            if State.scanning then
                return
            end
            local now = tick()
            if not force and now - State.lastScan < State.scanBackoff then
                return
            end
            State.lastScan = now
            State.scanning = true
            task.spawn(function()
                local ok, result = pcall(findAmmoTable)
                State.scanning = false
                if ok and result then
                    State.ammoTable = result
                    State.scanBackoff = 2
                else
                    State.scanBackoff = math.min((State.scanBackoff or 0.5) * 2, 30)
                end
            end)
        end

        local function restoreAmmoSafe()
            local t = State.ammoTable
            if not isAmmoTable(t) then
                t = findAmmoTable()
                if t then
                    State.ammoTable = t
                end
            end
            if not t then
                return
            end

            if type(State.originalAmmo) == 'table' then
                for key, value in pairs(State.originalAmmo) do
                    if type(value) == 'number' then
                        t[key] = value
                    end
                end
                State.originalAmmo = nil
                return
            end

            local weapons = ReplicatedStorage:FindFirstChild('Weapons')
            local client = getClientEnv()
            local function ammoOf(name, fallback)
                if weapons and type(name) == 'string' and name ~= '' and name ~= 'none' then
                    local folder = weapons:FindFirstChild(name)
                    local ammo = folder and folder:FindFirstChild('Ammo')
                    if ammo and type(ammo.Value) == 'number' and ammo.Value > 0 and ammo.Value <= 150 then
                        return math.floor(ammo.Value)
                    end
                end
                return fallback
            end

            local a1 = ammoOf(client and (client.realgun or client.primary), 30)
            local a2 = ammoOf(client and client.secondary, 12)

            local function fixMag(key, fallback)
                local value = rawget(t, key)
                if type(value) == 'number' and (value > 150 or value ~= value or value == math.huge) then
                    t[key] = fallback
                end
            end
            local function fixStored(key, fallback)
                local value = rawget(t, key)
                if type(value) == 'number' and (value > 999 or value ~= value or value == math.huge) then
                    t[key] = fallback
                end
            end

            fixMag('ammocount', a1)
            fixMag('ammocount2', a2)
            fixMag('ammocount3', 1)
            fixMag('ammocount4', 1)
            fixStored('primarystored', a1 * 2)
            fixStored('secondarystored', a2 * 2)
            fixStored('equipmentstored', 1)
            fixStored('equipment2stored', 1)
        end

        local function applyAmmo()
            if not Toggles.RageExploit_InfAmmo.Value then
                return
            end
            local t = State.ammoTable
            if not isAmmoTable(t) then
                State.ammoTable = nil
                requestScan(false)
                return
            end

            if not State.originalAmmo then
                State.originalAmmo = {}
                local keys = { 'ammocount', 'ammocount2', 'ammocount3', 'ammocount4', 'primarystored', 'secondarystored', 'equipmentstored', 'equipment2stored' }
                for i = 1, #keys do
                    local key = keys[i]
                    local value = rawget(t, key)
                    if type(value) == 'number' then
                        State.originalAmmo[key] = value
                    end
                end
            end

            local v = 9999999
            t.ammocount = v
            t.ammocount2 = v
            t.ammocount3 = v
            t.ammocount4 = v
            if rawget(t, 'primarystored') ~= nil then
                t.primarystored = v
            end
            if rawget(t, 'secondarystored') ~= nil then
                t.secondarystored = v
            end
            if rawget(t, 'equipmentstored') ~= nil then
                t.equipmentstored = v
            end
            if rawget(t, 'equipment2stored') ~= nil then
                t.equipment2stored = v
            end
        end

        local function isKickPacket(args)
            local first = args[1]
            if type(first) ~= 'table' then
                return false
            end
            local a, b = first[1], first[2]
            if a == 'kick' then
                return true
            end
            if type(a) == 'string' and string.lower(a) == 'kick' then
                return true
            end
            if b == 'error 2' or b == 'error2' then
                return true
            end
            return false
        end

        local function installKickBlock()
            if State.hooked then
                return
            end
            if type(hookmetamethod) ~= 'function' or type(getnamecallmethod) ~= 'function' then
                return
            end

            local events = GetEventsFolder()
            local particleRemote = events and events:FindFirstChild('ParticleRemote')

            local old
            local handler = function(self, ...)
                local method = getnamecallmethod()
                if method ~= 'FireServer' and method ~= 'FireUnreliable' then
                    return old(self, ...)
                end

                local name = typeof(self) == 'Instance' and self.Name or nil
                if name ~= 'ParticleRemote' and name ~= 'FallDamage' and name ~= 'ohnoflames' then
                    return old(self, ...)
                end

                if name == 'FallDamage' and Toggles.RageExploit_NoFallDamage.Value then
                    return
                end
                if name == 'ohnoflames' and Toggles.RageExploit_NoFireDamage.Value then
                    return
                end
                if Toggles.RageExploit_InfAmmo.Value then
                    local isParticle = self == particleRemote or name == 'ParticleRemote'
                    if isParticle then
                        local args = { ... }
                        if isKickPacket(args) then
                            return
                        end
                    end
                end
                return old(self, ...)
            end
            old = hookmetamethod(game, '__namecall', (newcclosure and newcclosure(handler)) or handler)

            State.oldNamecall = old
            State.hooked = true
        end

        installKickBlock()

        Toggles.RageExploit_InfAmmo:OnChanged(function(enabled)
            if enabled then
                State.ammoTable = nil
                State.lastGcScan = 0
                State.originalAmmo = nil
                State.scanBackoff = 0.5
                requestScan(true)
                task.defer(applyAmmo)
            else
                -- Restore normal ammo first while kick-block still active.
                pcall(restoreAmmoSafe)
                State.ammoTable = nil
            end
        end)

        State.charConn = LocalPlayer.CharacterAdded:Connect(function()
            State.ammoTable = nil
            State.lastGcScan = 0
            State.originalAmmo = nil
            State.clientScript = nil
            State.clientEnv = nil
            State.scanBackoff = 1
            if Toggles.RageExploit_InfAmmo.Value then
                task.defer(function()
                    requestScan(true)
                    applyAmmo()
                end)
            end
        end)
        Library:GiveSignal(State.charConn)

        local nextAmmoApply = 0
        State.heartbeat = RunService.Heartbeat:Connect(function()
            if not Toggles.RageExploit_InfAmmo.Value then
                return
            end
            local now = os.clock()
            if now < nextAmmoApply then
                return
            end
            nextAmmoApply = now + 0.05
            applyAmmo()
        end)
        Library:GiveSignal(State.heartbeat)

        if Toggles.RageExploit_InfAmmo.Value then
            requestScan(true)
        end

        AddUnload(function()
            -- Ammo normal first, then disable (kick block becomes no-op).
            pcall(restoreAmmoSafe)
            State.ammoTable = nil
            if State.heartbeat then
                State.heartbeat:Disconnect()
                State.heartbeat = nil
            end
            if State.charConn then
                State.charConn:Disconnect()
                State.charConn = nil
            end
        end)
    end

    -- GunMods
    local GunMods = RageTab:AddRightGroupbox('GunMods')
    
    GunMods:AddToggle('GunMods_RemoveSpread', { Text = 'Remove spread', Default = false })
    GunMods:AddToggle('GunMods_RemoveRecoil', { Text = 'Remove recoil', Default = false })
    GunMods:AddToggle('GunMods_RapidFire', { Text = 'RapidFire', Default = false })
    GunMods:AddSlider('GunMods_RapidFireRate', {
        Text = 'RapidFire rate',
        Default = 10,
        Min = 1,
        Max = 50,
        Rounding = 0,
    })
    GunMods:AddToggle('GunMods_FastEquip', { Text = 'Fast equip', Default = false })
    GunMods:AddToggle('GunMods_FastReload', { Text = 'Fast reload', Default = false })
    GunMods:AddToggle('GunMods_FullAuto', { Text = 'FullAuto', Default = false })
    
    do
        local SavedValues = {
            Recoil = setmetatable({}, { __mode = 'k' }),
            FireRate = setmetatable({}, { __mode = 'k' }),
            EquipTime = setmetatable({}, { __mode = 'k' }),
            ReloadTime = setmetatable({}, { __mode = 'k' }),
            Auto = setmetatable({}, { __mode = 'k' }),
        }
        local SavedAccuracySd = nil
        local ClientEnvironment = nil
        local ClientScript = nil
        local NextClientCheck = 0
        local WeaponsFolder
        local WeaponsDirty = true
        local WeaponConnections = {}
        local RootConnections = {}
        local ModConnection
        local RapidAmmoTable = nil
        local RapidLastUnlock = 0
        local WeaponCache = {
            Recoil = {},
            FireRate = {},
            EquipTime = {},
            ReloadTime = {},
            Auto = {},
        }
    
        local function GetClientEnvironment()
            local now = os.clock()
            if now < NextClientCheck then
                return ClientEnvironment
            end
            NextClientCheck = now + 0.25
    
            local playerGui = LocalPlayer:FindFirstChild('PlayerGui')
            local clientScript = playerGui and playerGui:FindFirstChild('Client')
            if clientScript ~= ClientScript then
                ClientScript = clientScript
                ClientEnvironment = nil
                RapidAmmoTable = nil
                NextClientCheck = 0
            end
    
            if clientScript and not ClientEnvironment and type(getsenv) == 'function' then
                local ok, environment = pcall(getsenv, clientScript)
                ClientEnvironment = ok and environment or nil
            end
    
            return ClientEnvironment
        end

        local function IsAmmoTable(obj)
            if type(obj) ~= 'table' then return false end
            return type(rawget(obj, 'ammocount')) == 'number'
                and type(rawget(obj, 'ammocount2')) == 'number'
                and rawget(obj, 'DISABLED') ~= nil
                and rawget(obj, 'reloading') ~= nil
        end

        local function GetAmmoTable()
            if RapidAmmoTable and rawget(RapidAmmoTable, 'DISABLED') ~= nil then
                return RapidAmmoTable
            end
            local client = GetClientEnvironment()
            if type(client) ~= 'table' then return nil end
            if IsAmmoTable(client) then
                RapidAmmoTable = client
                return client
            end
            for _, obj in pairs(client) do
                if IsAmmoTable(obj) then
                    RapidAmmoTable = obj
                    return obj
                end
            end
            if debug and type(debug.getupvalue) == 'function' then
                local names = { 'usethatgun', 'loadammo', 'countammo', 'resetguns' }
                for i = 1, #names do
                    local fn = rawget(client, names[i])
                    if type(fn) == 'function' then
                        local ok, found = pcall(function()
                            for ui = 1, 64 do
                                local name, val = debug.getupvalue(fn, ui)
                                if name == nil and val == nil then break end
                                if IsAmmoTable(val) then return val end
                            end
                            return nil
                        end)
                        if ok and found then
                            RapidAmmoTable = found
                            return found
                        end
                    end
                end
            end
            return nil
        end
    
        local function RestoreSaved(saved)
            for object, value in pairs(saved) do
                if object.Parent then
                    pcall(function() object.Value = value end)
                end
            end
            table.clear(saved)
        end
    
        local function RestoreAllSaved()
            for _, saved in pairs(SavedValues) do
                RestoreSaved(saved)
            end
        end
    
        local function RestoreObject(object)
            for _, saved in pairs(SavedValues) do
                if saved[object] ~= nil then
                    pcall(function() object.Value = saved[object] end)
                    saved[object] = nil
                end
            end
        end

        local function DisconnectWeaponConnections()
            for i = 1, #WeaponConnections do
                WeaponConnections[i]:Disconnect()
            end
            table.clear(WeaponConnections)
        end

        local function ResolveFireRate(weapon)
            if not weapon then return nil end
            -- Client wait uses fgun = getref(gun): CopyFrom base if present
            local source = weapon
            local copyFrom = weapon:FindFirstChild('CopyFrom')
            if copyFrom then
                local ref = copyFrom.Value
                if typeof(ref) == 'Instance' then
                    source = ref
                elseif type(ref) == 'string' and ref ~= '' then
                    source = (WeaponsFolder and WeaponsFolder:FindFirstChild(ref)) or weapon
                end
            end
            local fireRate = source:FindFirstChild('FireRate')
            if fireRate and fireRate:IsA('NumberValue') then return fireRate end
            fireRate = weapon:FindFirstChild('FireRate')
            if fireRate and fireRate:IsA('NumberValue') then return fireRate end
            return nil
        end

        local function RebuildWeaponCache()
            for _, list in pairs(WeaponCache) do table.clear(list) end
            local folder = WeaponsFolder
            if not folder or folder.Parent ~= ReplicatedStorage then
                WeaponsDirty = false
                return
            end
            local seenFireRate = {}
            for _, weapon in ipairs(folder:GetChildren()) do
                local spread = weapon:FindFirstChild('Spread')
                local recoil = spread and spread:FindFirstChild('Recoil')
                local fireRate = ResolveFireRate(weapon)
                local equipTime = weapon:FindFirstChild('EquipTime')
                local reloadTime = weapon:FindFirstChild('ReloadTime')
                local auto = weapon:FindFirstChild('Auto')
                if recoil and recoil:IsA('NumberValue') then
                    WeaponCache.Recoil[#WeaponCache.Recoil + 1] = recoil
                end
                if fireRate and not seenFireRate[fireRate] then
                    seenFireRate[fireRate] = true
                    WeaponCache.FireRate[#WeaponCache.FireRate + 1] = fireRate
                end
                if equipTime and equipTime:IsA('NumberValue') then
                    WeaponCache.EquipTime[#WeaponCache.EquipTime + 1] = equipTime
                end
                if reloadTime and reloadTime:IsA('NumberValue') then
                    WeaponCache.ReloadTime[#WeaponCache.ReloadTime + 1] = reloadTime
                end
                if auto and auto:IsA('BoolValue') then
                    WeaponCache.Auto[#WeaponCache.Auto + 1] = auto
                end
            end
            WeaponsDirty = false
        end

        local function BindWeaponsFolder(folder)
            if WeaponsFolder == folder then return end
            RestoreAllSaved()
            DisconnectWeaponConnections()
            WeaponsFolder = folder
            WeaponsDirty = true
            if not folder then return end
            WeaponConnections[#WeaponConnections + 1] = folder.DescendantAdded:Connect(function()
                WeaponsDirty = true
            end)
            WeaponConnections[#WeaponConnections + 1] = folder.DescendantRemoving:Connect(function(object)
                RestoreObject(object)
                WeaponsDirty = true
            end)
        end

        local function EnsureWeaponCache()
            local folder = GetWeaponsFolder() or ReplicatedStorage:FindFirstChild('Weapons')
            if folder ~= WeaponsFolder then BindWeaponsFolder(folder) end
            if WeaponsDirty then RebuildWeaponCache() end
        end
    
        local function RestoreAccuracySd()
            local client = GetClientEnvironment()
            if client and SavedAccuracySd ~= nil then
                rawset(client, 'accuracy_sd', SavedAccuracySd)
            end
            SavedAccuracySd = nil
        end
    
        local function RestoreRecoils()
            RestoreSaved(SavedValues.Recoil)
        end
    
        local function RestoreFireRates()
            RestoreSaved(SavedValues.FireRate)
        end
    
        local function RestoreEquipTimes()
            RestoreSaved(SavedValues.EquipTime)
        end
    
        local function RestoreReloadTimes()
            RestoreSaved(SavedValues.ReloadTime)
        end
    
        local function RestoreAutos()
            RestoreSaved(SavedValues.Auto)
        end
    
        local function RestoreAll()
            RestoreAccuracySd()
            RestoreAllSaved()
        end

        local function ApplyValue(object, saved, value)
            if not object or not object.Parent then return end
            if saved[object] == nil then saved[object] = object.Value end
            if object.Value ~= value then object.Value = value end
        end
    
        local function ApplyWeaponMods()
            if Toggles.GunMods_RemoveSpread.Value then
                local client = GetClientEnvironment()
                if client then
                    local current = rawget(client, 'accuracy_sd')
                    if SavedAccuracySd == nil and type(current) == 'number' then
                        SavedAccuracySd = current
                    end
                    if type(current) == 'number' and current ~= 0 then
                        rawset(client, 'accuracy_sd', 0)
                    end
                end
            end

            local weaponModsEnabled = Toggles.GunMods_RemoveRecoil.Value
                or Toggles.GunMods_RapidFire.Value
                or Toggles.GunMods_FastEquip.Value
                or Toggles.GunMods_FastReload.Value
                or Toggles.GunMods_FullAuto.Value
            if not weaponModsEnabled then return end
            EnsureWeaponCache()
            if Toggles.GunMods_RemoveRecoil.Value then
                for i = 1, #WeaponCache.Recoil do ApplyValue(WeaponCache.Recoil[i], SavedValues.Recoil, 1) end
            end
            if Toggles.GunMods_RapidFire.Value then
                local rapidRate = math.clamp((tonumber(Options.GunMods_RapidFireRate.Value) or 10) / 1000, 0.001, 0.05)
                for i = 1, #WeaponCache.FireRate do
                    ApplyValue(WeaponCache.FireRate[i], SavedValues.FireRate, rapidRate)
                end
            end
            if Toggles.GunMods_FastEquip.Value then
                for i = 1, #WeaponCache.EquipTime do ApplyValue(WeaponCache.EquipTime[i], SavedValues.EquipTime, 0.1) end
            end
            if Toggles.GunMods_FastReload.Value then
                for i = 1, #WeaponCache.ReloadTime do ApplyValue(WeaponCache.ReloadTime[i], SavedValues.ReloadTime, 0.1) end
            end
            if Toggles.GunMods_FullAuto.Value then
                for i = 1, #WeaponCache.Auto do ApplyValue(WeaponCache.Auto[i], SavedValues.Auto, true) end
            end
        end

        local function RapidFireTick()
            if not Toggles.GunMods_RapidFire.Value then
                return
            end
            local ammo = GetAmmoTable()
            if ammo and not rawget(ammo, 'reloading') and (rawget(ammo, 'Held') or rawget(ammo, 'Held2')) then
                rawset(ammo, 'DISABLED', false)
            end
        end

        local function ModsEnabled()
            return Toggles.GunMods_RemoveSpread.Value or Toggles.GunMods_RemoveRecoil.Value
                or Toggles.GunMods_RapidFire.Value or Toggles.GunMods_FastEquip.Value
                or Toggles.GunMods_FastReload.Value or Toggles.GunMods_FullAuto.Value
        end

        -- Forward declarations used by BindWeaponsFolder (Lua local scoping).
        -- BindWeaponsFolder above references ModsEnabled/ApplyWeaponMods; redefine bindings after defs:
        local function RebindWeaponsFolderHandlers()
            local folder = WeaponsFolder
            if not folder then return end
            DisconnectWeaponConnections()
            WeaponConnections[#WeaponConnections + 1] = folder.DescendantAdded:Connect(function()
                WeaponsDirty = true
                if ModsEnabled() then
                    ApplyWeaponMods()
                end
            end)
            WeaponConnections[#WeaponConnections + 1] = folder.DescendantRemoving:Connect(function(object)
                RestoreObject(object)
                WeaponsDirty = true
            end)
        end

        local NextWeaponModsApply = 0
        local RapidTickConnection
        local ValuesTickConnection

        local function StopRapidTick()
            if RapidTickConnection then
                RapidTickConnection:Disconnect()
                RapidTickConnection = nil
            end
        end

        local function StopValuesTick()
            if ValuesTickConnection then
                ValuesTickConnection:Disconnect()
                ValuesTickConnection = nil
            end
        end

        local function RefreshModConnection()
            if ModsEnabled() then
                ApplyWeaponMods()
                NextWeaponModsApply = os.clock() + 10
                if not ValuesTickConnection then
                    ValuesTickConnection = RunService.Heartbeat:Connect(function()
                        if not ModsEnabled() then
                            return
                        end
                        local now = os.clock()
                        if now < NextWeaponModsApply then
                            return
                        end
                        NextWeaponModsApply = now + 10
                        ApplyWeaponMods()
                    end)
                end
            else
                StopValuesTick()
            end

            if Toggles.GunMods_RapidFire.Value then
                if not RapidTickConnection then
                    local nextRapid = 0
                    RapidTickConnection = RunService.Heartbeat:Connect(function()
                        local now = os.clock()
                        if now < nextRapid then
                            return
                        end
                        nextRapid = now + 1 / 15
                        RapidFireTick()
                    end)
                end
            else
                StopRapidTick()
            end
        end
    
        Toggles.GunMods_RemoveSpread:OnChanged(function()
            if not Toggles.GunMods_RemoveSpread.Value then
                RestoreAccuracySd()
            end
            RefreshModConnection()
        end)
        Toggles.GunMods_RemoveRecoil:OnChanged(function()
            if not Toggles.GunMods_RemoveRecoil.Value then
                RestoreRecoils()
            end
            RefreshModConnection()
        end)
        Toggles.GunMods_RapidFire:OnChanged(function()
            if not Toggles.GunMods_RapidFire.Value then
                RestoreFireRates()
            end
            RefreshModConnection()
        end)
        Options.GunMods_RapidFireRate:OnChanged(function()
            if Toggles.GunMods_RapidFire.Value then
                ApplyWeaponMods()
            end
        end)
        Toggles.GunMods_FastEquip:OnChanged(function()
            if not Toggles.GunMods_FastEquip.Value then
                RestoreEquipTimes()
            end
            RefreshModConnection()
        end)
        Toggles.GunMods_FastReload:OnChanged(function()
            if not Toggles.GunMods_FastReload.Value then
                RestoreReloadTimes()
            end
            RefreshModConnection()
        end)
        Toggles.GunMods_FullAuto:OnChanged(function()
            if not Toggles.GunMods_FullAuto.Value then
                RestoreAutos()
            end
            RefreshModConnection()
        end)

        RootConnections[#RootConnections + 1] = ReplicatedStorage.ChildAdded:Connect(function(child)
            if child.Name == 'Weapons' then
                BindWeaponsFolder(child)
                RebindWeaponsFolderHandlers()
                if ModsEnabled() then
                    ApplyWeaponMods()
                end
            end
        end)
        RootConnections[#RootConnections + 1] = ReplicatedStorage.ChildRemoved:Connect(function(child)
            if child == WeaponsFolder then BindWeaponsFolder(nil) end
        end)
        BindWeaponsFolder(GetWeaponsFolder() or ReplicatedStorage:FindFirstChild('Weapons'))
        RebindWeaponsFolderHandlers()

        Library:GiveSignal(LocalPlayer.CharacterAdded:Connect(function()
            if ModsEnabled() then
                task.defer(ApplyWeaponMods)
            end
        end))

        RefreshModConnection()
    
        AddUnload(function()
            StopRapidTick()
            StopValuesTick()
            if ModConnection then ModConnection:Disconnect(); ModConnection = nil end
            for i = 1, #RootConnections do RootConnections[i]:Disconnect() end
            table.clear(RootConnections)
            DisconnectWeaponConnections()
            RestoreAll()
        end)
    end
    
    local GetCurrentSpreadRadius
    local GetCurrentSpreadAngle
    
    do
        local SpreadCircle
        local ClientEnvironment
        local ClientScript
        local WeaponsFolder
        local NextEnvironmentCheck = 0
        local NextUpdate = 0
    
        local ACCURACY_SCALE_DEFAULT = 0.001
        local DEFAULT_MAX_SPEED = 256
        local SPEED_START = 0.34 * 0.0625
        local SPEED_END = 0.61 * 0.0625
        local VISUAL_SCALE = 10
    
        local function MakeSpreadCircle()
            local ok, circle = pcall(Drawing.new, 'Circle')
            if not ok or not circle then
                return nil
            end
    
            circle.Visible = false
            circle.Filled = true
            circle.NumSides = 64
            circle.Thickness = 1
            circle.Color = Color3.fromRGB(255, 255, 0)
            circle.Transparency = 0.35
            return circle
        end
    
        local function HideSpreadCircle()
            if SpreadCircle then
                SpreadCircle.Visible = false
            end
        end
    
        local function GetClientEnvironment()
            local now = os.clock()
            if now < NextEnvironmentCheck then
                return ClientEnvironment
            end
            NextEnvironmentCheck = now + 0.25
    
            local playerGui = LocalPlayer:FindFirstChild('PlayerGui')
            local clientScript = playerGui and playerGui:FindFirstChild('Client')
    
            if clientScript ~= ClientScript then
                ClientScript = clientScript
                ClientEnvironment = nil
                NextEnvironmentCheck = 0
            end
    
            if clientScript and not ClientEnvironment and type(getsenv) == 'function' then
                local ok, environment = pcall(getsenv, clientScript)
                ClientEnvironment = ok and environment or nil
            end
    
            return ClientEnvironment
        end
    
        local function GetWeapon()
            local character = LocalPlayer.Character
            local equipped = character and character:FindFirstChild('EquippedTool')
            if not equipped then
                return nil
            end
    
            local weaponName = tostring(equipped.Value)
            if weaponName == '' or weaponName == 'nil' then
                return nil
            end
    
            if not WeaponsFolder or WeaponsFolder.Parent ~= ReplicatedStorage then
                WeaponsFolder = ReplicatedStorage:FindFirstChild('Weapons')
            end
            local weapon = WeaponsFolder and WeaponsFolder:FindFirstChild(weaponName)
            if not weapon or weapon:FindFirstChild('Melee') then
                return nil
            end
            return weapon
        end
    
        local function GetFallbackSpread(weapon, character, client)
            local spread = weapon:FindFirstChild('Spread')
            if not spread then
                return 0
            end
    
            local standingSpread = spread:FindFirstChild('Stand')
            local baseSpread = (tonumber(spread.Value) or 0)
                + (tonumber(standingSpread and standingSpread.Value) or 0)
    
            if baseSpread <= 20 and not weapon:FindFirstChild('SMGThing') then
                baseSpread /= 10
            end
    
            local rootPart = character and character:FindFirstChild('HumanoidRootPart')
            local velocity = rootPart and rootPart.AssemblyLinearVelocity or Vector3.zero
            local horizontalSpeed = math.sqrt(velocity.X ^ 2 + velocity.Z ^ 2)
            local maximumSpeed = tonumber(client and rawget(client, 'curspd')) or DEFAULT_MAX_SPEED
            local movementFactor = math.clamp(
                (horizontalSpeed - maximumSpeed * SPEED_START)
                    / (maximumSpeed * SPEED_END),
                0,
                1
            )
    
            local movementSpread = spread:FindFirstChild('Move')
            local moveValue = tonumber(movementSpread and movementSpread.Value) or 0
            return baseSpread + moveValue * movementFactor
        end
    
        local function GetSpreadAngle()
            local character = LocalPlayer.Character
            local weapon = GetWeapon()
            local spread = weapon and weapon:FindFirstChild('Spread')
            if not spread then
                return 0
            end
    
            local client = GetClientEnvironment()
            local accuracyScale = client
                and tonumber(rawget(client, 'accuracy_sd'))
                or ACCURACY_SCALE_DEFAULT
            local currentSpread = client and tonumber(rawget(client, 'spread'))
    
            if currentSpread then
                local movementSpread = tonumber(rawget(client, 'spread2')) or 0
                return math.max(0, currentSpread + movementSpread) * accuracyScale
            end
    
            return GetFallbackSpread(weapon, character, client) * accuracyScale
        end
    
        GetCurrentSpreadAngle = function()
            return math.max(GetSpreadAngle(), 0)
        end

        GetShotHitChance = function(part, camera, origin)
            if not part or not camera then
                return 0
            end

            local spreadAngle = GetCurrentSpreadAngle()
            if spreadAngle <= 0 then
                return 100
            end

            origin = typeof(origin) == 'Vector3' and origin or camera.CFrame.Position
            local distance = (part.Position - origin).Magnitude
            if distance <= 1e-3 then
                return 100
            end

            local radius = math.max(part.Size.X, part.Size.Y, part.Size.Z) * 0.5
            if part.Name == 'Head' or part.Name == 'HeadHB' or part.Name == 'FakeHead' then
                radius = math.max(radius, 0.6)
            end

            return math.clamp(math.atan(radius / distance) / math.max(spreadAngle, 1e-6) * 100, 0, 100)
        end

        GetCurrentSpreadRadius = function(camera)
            if not camera then
                return 0
            end
    
            local spreadAngle = GetCurrentSpreadAngle()
            return math.max(
                0,
                math.deg(spreadAngle) * VISUAL_SCALE * camera.ViewportSize.Y / 600
            )
        end
    
        Library:GiveSignal(RunService.RenderStepped:Connect(function()
            if not Toggles.SpreadVisualizer_Enable.Value then
                HideSpreadCircle()
                return
            end
    
            local now = os.clock()
            if now < NextUpdate then
                return
            end
            NextUpdate = now + GetUpdateInterval()
    
            if not SpreadCircle then
                SpreadCircle = MakeSpreadCircle()
            end
            if not SpreadCircle then
                return
            end
    
            local camera = workspace.CurrentCamera
            local radius = GetCurrentSpreadRadius(camera)
            if not camera or radius <= 0 then
                HideSpreadCircle()
                return
            end
    
            SpreadCircle.Position = Vector2.new(
                camera.ViewportSize.X * 0.5,
                camera.ViewportSize.Y * 0.5
            )
            SpreadCircle.Radius = radius
            SpreadCircle.Color = Options.SpreadVisualizer_Color.Value
            SpreadCircle.Transparency = math.clamp(
                1 - (Options.SpreadVisualizer_Color.Transparency or 0),
                0,
                1
            )
            SpreadCircle.Visible = true
        end))
    
        AddUnload(function()
            if SpreadCircle then
                HideSpreadCircle()
                pcall(function()
                    SpreadCircle:Remove()
                end)
                SpreadCircle = nil
            end
        end)
    end
    
    -- Aimbot
    local Aimbot = LegitTab:AddLeftGroupbox('Aimbot')
    
    Aimbot:AddToggle('Aimbot_Enable', { Text = 'Enable', Default = false })
        :AddKeyPicker('Aimbot_Key', {
            Default = 'None',
            Mode = 'Hold',
            Text = 'Aimbot',
        })
    
    Aimbot:AddDropdown('Aimbot_Hitbox', {
        Text = 'Hitbox',
        Values = { 'Head', 'Body', 'Arms', 'Legs' },
        Default = { 'Head' },
        Multi = true,
    })
    
    Aimbot:AddToggle('Aimbot_VisibleCheck', { Text = 'VisibleCheck', Default = false })
    Aimbot:AddToggle('Aimbot_TeamCheck', { Text = 'TeamCheck', Default = false })
    
    Aimbot:AddToggle('Aimbot_ShowFov', { Text = 'ShowFov', Default = false })
        :AddColorPicker('Aimbot_FovColor', {
            Default = Color3.fromRGB(255, 255, 255),
            Transparency = 0,
            Title = 'FOV',
        })
    
    Aimbot:AddSlider('Aimbot_FOV', {
        Text = 'FOV',
        Default = 90,
        Min = 1,
        Max = 360,
        Rounding = 0,
    })
    
    Aimbot:AddSlider('Aimbot_Smooth', {
        Text = 'Smooth',
        Default = 1,
        Min = 1,
        Max = 10,
        Rounding = 0,
    })
    
    do
        local RayParams = RaycastParams.new()
        local RaycastIgnore = {}
        RayParams.FilterType = Enum.RaycastFilterType.Exclude
    
        local AimFovCircle = nil
        local NextUpdate = 0
        local NextFovUpdate = 0
    
        local function MakeFovCircle()
            local ok, c = pcall(Drawing.new, 'Circle')
            if not ok or not c then
                return nil
            end
            c.Visible = false
            c.Thickness = 1.5
            c.NumSides = 48
            c.Filled = false
            c.Color = Color3.fromRGB(255, 255, 255)
            return c
        end
    
        local function EnsureFovCircle()
            if not AimFovCircle then
                AimFovCircle = MakeFovCircle()
            end
            return AimFovCircle
        end
    
        local function IsAimbotTeammate(player)
            if not Toggles.Aimbot_TeamCheck.Value then
                return false
            end
            local lt, pt = LocalPlayer.Team, player.Team
            return lt ~= nil and pt ~= nil and lt == pt
        end
    
        local function GetSelectedHitboxes()
            local value = Options.Aimbot_Hitbox.Value
            return value, type(value) == 'table'
        end
    
        local function GetHitPart(character, selected, isMultiple)
            for i = 1, #HITBOX_PRIORITY do
                local group = HITBOX_PRIORITY[i]
                if (isMultiple and not selected[group]) or (not isMultiple and selected ~= group) then
                    continue
                end
    
                local names = HITBOX_PARTS[group]
                for j = 1, #names do
                    local part = character:FindFirstChild(names[j])
                    if part and part:IsA('BasePart') then
                        return part
                    end
                end
            end
            return nil
        end
    
        local function IsVisible(character, part, camera)
            local origin = camera.CFrame.Position
            local target = part.Position
            local dir = target - origin
            if dir.Magnitude <= 1e-4 then
                return false
            end
    
            RaycastIgnore[1] = character
            RaycastIgnore[2] = LocalPlayer.Character
            AppendSharedRaycastIgnore(RaycastIgnore, 3)
            RayParams.FilterDescendantsInstances = RaycastIgnore
    
            local result = workspace:Raycast(origin, dir, RayParams)
            if not result then
                return true
            end
            return result.Instance:IsDescendantOf(character)
        end
    
        local function GetAimDot(position, cameraPosition, lookVector)
            local dir = position - cameraPosition
            local magnitude = dir.Magnitude
            if magnitude <= 1e-4 then
                return nil
            end
            return lookVector:Dot(dir / magnitude)
        end
    
        local function GetFov()
            local v = Options.Aimbot_FOV.Value
            if type(v) ~= 'number' then
                return 45
            end
            return math.clamp(v, 1, 360)
        end
    
        local function GetFovRadius(camera)
            local aimFov = GetFov()
            if aimFov >= 180 then
                return 999999
            end
            if not camera then
                return 0
            end
            local halfViewport = camera.ViewportSize.Y * 0.5
            local camFovHalfRad = math.rad(camera.FieldOfView * 0.5)
            local aimFovHalfRad = math.rad(aimFov * 0.5)
            return (math.tan(aimFovHalfRad) / math.tan(camFovHalfRad)) * halfViewport
        end
    
        local function GetSmoothAlpha(smooth)
            return 1 / smooth
        end
    
        local function GetTarget(camera)
            local fov = GetFov()
            local fullFov = fov >= 360
            local minimumDot = fullFov and -1 or math.cos(math.rad(fov * 0.5))
            local selectedHitboxes, isMultiple = GetSelectedHitboxes()
            local bestPart, bestCharacter, bestDot = nil, nil, -2
            local cameraCFrame = camera.CFrame
            local cameraPosition = cameraCFrame.Position
            local lookVector = cameraCFrame.LookVector
            local needVisible = Toggles.Aimbot_VisibleCheck.Value

            for _, player in ipairs(PlayerSnapshot) do
                if player == LocalPlayer or IsAimbotTeammate(player) then
                    continue
                end

                local character = player.Character
                local humanoid = character and character:FindFirstChildOfClass('Humanoid')
                if not character or not humanoid or humanoid.Health <= 0 or HasCombatProtection(character) then
                    continue
                end

                local part = GetHitPart(character, selectedHitboxes, isMultiple)
                if not part then
                    continue
                end

                local dot = GetAimDot(part.Position, cameraPosition, lookVector)
                if not dot or dot < minimumDot or dot <= bestDot then
                    continue
                end

                bestDot = dot
                bestPart = part
                bestCharacter = character
            end

            -- One visibility raycast for the FOV-best target only.
            if needVisible and bestPart and not IsVisible(bestCharacter, bestPart, camera) then
                return nil
            end

            return bestPart
        end
    
        local function UpdateFovCircle(camera)
            local show = Toggles.Aimbot_ShowFov.Value
                and Toggles.Aimbot_Enable.Value
                and GetFov() < 180
    
            if not show then
                if AimFovCircle then
                    AimFovCircle.Visible = false
                end
                return
            end
    
            local circle = EnsureFovCircle()
            if not circle then
                return
            end
    
            local center = Vector2.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y / 2)
            circle.Position = center
            circle.Radius = math.min(GetFovRadius(camera), 100000)
            circle.Color = Options.Aimbot_FovColor.Value
            circle.Visible = true
        end
    
        Library:GiveSignal(RunService.RenderStepped:Connect(function()
            if not Toggles.Aimbot_Enable.Value then
                if AimFovCircle then
                    AimFovCircle.Visible = false
                end
                return
            end
    
            local now = os.clock()
            local camera = workspace.CurrentCamera
            if not camera then
                if AimFovCircle then
                    AimFovCircle.Visible = false
                end
                return
            end
    
            if now >= NextFovUpdate then
                NextFovUpdate = now + 1 / 60
                UpdateFovCircle(camera)
            end
    
            if now < NextUpdate then
                return
            end
            NextUpdate = now + GetUpdateInterval()
    
            if not Options.Aimbot_Key:GetState() then
                return
            end

            if not IsCombatRoundActive() or HasCombatProtection(LocalPlayer.Character) then
                return
            end
    
            local target = GetTarget(camera)
            if not target then
                return
            end
    
            local goal = CFrame.new(camera.CFrame.Position, target.Position)
            local alpha = GetSmoothAlpha(Options.Aimbot_Smooth.Value)
            camera.CFrame = camera.CFrame:Lerp(goal, alpha)
        end))
    
        AddUnload(function()
            if AimFovCircle then
                AimFovCircle.Visible = false
                pcall(function()
                    AimFovCircle:Remove()
                end)
                AimFovCircle = nil
            end
        end)
    end
    
    -- Triggerbot
    local Triggerbot = LegitTab:AddRightGroupbox('Triggerbot')
    
    Triggerbot:AddToggle('Triggerbot_Enable', { Text = 'Enable', Default = false })
        :AddKeyPicker('Triggerbot_Key', {
            Default = 'None',
            Mode = 'Hold',
            Text = 'Triggerbot',
        })
    
    Triggerbot:AddDropdown('Triggerbot_Hitbox', {
        Text = 'Hitbox',
        Values = { 'Head', 'Body', 'Arms', 'Legs' },
        Default = { 'Head' },
        Multi = true,
    })
    
    Triggerbot:AddToggle('Triggerbot_TeamCheck', { Text = 'TeamCheck', Default = false })
    Triggerbot:AddToggle('Triggerbot_AutoWall', { Text = 'Auto wall', Default = false })
    
    Triggerbot:AddSlider('Triggerbot_Delay', {
        Text = 'Delay',
        Default = 30,
        Min = 0,
        Max = 300,
        Rounding = 0,
        Suffix = 'ms',
    })
    
    Triggerbot:AddSlider('Triggerbot_HitChance', {
        Text = 'Hit chance',
        Default = 50,
        Min = 0,
        Max = 100,
        Rounding = 0,
        Suffix = '%',
    })
    
    do
        local RayParams = RaycastParams.new()
        local RaycastIgnore = {}
        local FireRemote
        local DelayTarget
        local DelayUntil = 0
        local LastFireAt = 0
        local NextUpdate = 0
        RayParams.FilterType = Enum.RaycastFilterType.Exclude
    
        local function ResetDelay()
            DelayTarget = nil
            DelayUntil = 0
        end
    
        local function IsHitboxGroupSelected(group)
            local selected = Options.Triggerbot_Hitbox.Value
            if type(selected) == 'table' then
                return selected[group] == true
            end
            return selected == group
        end
    
        local function CollectSelectedParts(character, into)
            for i = #into, 1, -1 do
                into[i] = nil
            end
            for i = 1, #HITBOX_PRIORITY do
                local group = HITBOX_PRIORITY[i]
                if IsHitboxGroupSelected(group) then
                    local names = HITBOX_PARTS[group]
                    for j = 1, #names do
                        local part = character:FindFirstChild(names[j])
                        if part and part:IsA('BasePart') then
                            into[#into + 1] = part
                        end
                    end
                end
            end
            return into
        end
    
        local SelectedParts = {}
        local function IsTriggerTeammate(player)
            if not Toggles.Triggerbot_TeamCheck.Value then
                return false
            end
    
            local localStatus = LocalPlayer:FindFirstChild('Status')
            local playerStatus = player:FindFirstChild('Status')
            local localTeam = localStatus and localStatus:FindFirstChild('Team')
            local playerTeam = playerStatus and playerStatus:FindFirstChild('Team')
            if localTeam and playerTeam then
                return localTeam.Value == playerTeam.Value
            end
    
            return LocalPlayer.Team ~= nil and LocalPlayer.Team == player.Team
        end

        local function GetTriggerPenetrationBudget()
            local character = LocalPlayer.Character
            local equipped = character and character:FindFirstChild('EquippedTool')
            local gun = character and character:FindFirstChild('Gun')
            local gunName = equipped and type(equipped.Value) == 'string' and equipped.Value or (gun and gun.Name)
            local weapons = gunName and ReplicatedStorage:FindFirstChild('Weapons')
            local weapon = weapons and weapons:FindFirstChild(gunName)
            local copyFrom = weapon and weapon:FindFirstChild('CopyFrom')
            if copyFrom then
                local reference = copyFrom.Value
                if typeof(reference) == 'Instance' then
                    weapon = reference
                elseif type(reference) == 'string' and reference ~= '' and weapons then
                    weapon = weapons:FindFirstChild(reference) or weapon
                end
            end
            local penetration = weapon and weapon:FindFirstChild('Penetration')
            return penetration and type(penetration.Value) == 'number' and math.max(penetration.Value, 0) * 0.01 or 0
        end

        local function GetTriggerWallFactor(part)
            local factor = 1
            local material = part.Material
            if material == Enum.Material.DiamondPlate then
                factor = 3
            end
            if material == Enum.Material.CorrodedMetal
                or material == Enum.Material.Metal
                or material == Enum.Material.Concrete
                or material == Enum.Material.Brick
            then
                factor = 2
            end
            if part.Name == 'Grate' or material == Enum.Material.Wood or material == Enum.Material.WoodPlanks
                or (part.Parent and part.Parent:FindFirstChildOfClass('Humanoid'))
            then
                factor = 0.1
            end
            local rayIgnore = GetRayIgnoreRoot()
            local debris = GetDebrisRoot()
            if part.Transparency == 1 or part.CanCollide == false or part.Name == 'Glass' or part.Name == 'Cardboard'
                or (rayIgnore and part:IsDescendantOf(rayIgnore))
                or (debris and part:IsDescendantOf(debris))
                or (part.Parent and part.Parent.Name == 'Hitboxes')
            then
                factor = 0
            end
            local modifier = part:FindFirstChild('PartModifier')
            if modifier and type(modifier.Value) == 'number' then
                return math.max(modifier.Value, 0), true
            end
            return factor, false
        end

        local TriggerPenetrationParams = RaycastParams.new()
        TriggerPenetrationParams.FilterType = Enum.RaycastFilterType.Include
        TriggerPenetrationParams.IgnoreWater = true
        local TriggerPenetrationInclude = {}
        local function GetTriggerWallThickness(part, hitPosition, direction)
            TriggerPenetrationInclude[1] = part
            TriggerPenetrationParams.FilterDescendantsInstances = TriggerPenetrationInclude
            local probe = direction.Unit * math.max(part.Size.Magnitude * 2, 2)
            local result = workspace:Raycast(hitPosition + probe, probe * -2, TriggerPenetrationParams)
            TriggerPenetrationInclude[1] = nil
            if result then return (result.Position - hitPosition).Magnitude end
            return probe.Magnitude
        end

        local function CanTriggerPenetrate(part, hitPosition, direction, used, wallCount, budget)
            if part.Name == 'nowallbang' then
                return false, used, wallCount
            end
            local factor = GetTriggerWallFactor(part)
            if factor <= 0 then
                return true, used, wallCount
            end
            if not Toggles.Triggerbot_AutoWall.Value then
                return false, used, wallCount
            end
            if wallCount >= 4 then
                return false, used, wallCount
            end
            if budget <= 0 then
                return false, used, wallCount
            end
            used = math.min(budget, used + GetTriggerWallThickness(part, hitPosition, direction) * factor)
            if used >= budget then
                return false, used, wallCount
            end
            return true, used, wallCount + 1
        end
    
        -- любой хит по персу, но стрельба только если aim в 80% от центра hitbox
        local function GetTarget(camera)
            RaycastIgnore[1] = LocalPlayer.Character
            AppendSharedRaycastIgnore(RaycastIgnore, 2)
            RayParams.FilterDescendantsInstances = RaycastIgnore

            local cameraCFrame = camera.CFrame
            local direction = cameraCFrame.LookVector
            local rayEnd = cameraCFrame.Position + direction * 5000
            local origin = cameraCFrame.Position
            local ignoreCount = #RaycastIgnore
            local penetrationUsed = 0
            local wallCount = 0
            local penetrationBudget = GetTriggerPenetrationBudget()
            local part
            for _ = 1, 12 do
                local result = workspace:Raycast(origin, rayEnd - origin, RayParams)
                part = result and result.Instance
                if not part or not part:IsA('BasePart') then
                    return nil
                end

                local character = part:FindFirstAncestorOfClass('Model')
                if character and PlayersService:GetPlayerFromCharacter(character) then
                    break
                end

                local canPass
                canPass, penetrationUsed, wallCount = CanTriggerPenetrate(
                    part,
                    result.Position,
                    direction,
                    penetrationUsed,
                    wallCount,
                    penetrationBudget
                )
                if not canPass then
                    return nil
                end
                ignoreCount = ignoreCount + 1
                RaycastIgnore[ignoreCount] = part
                RayParams.FilterDescendantsInstances = RaycastIgnore
                origin = result.Position + direction * 0.05
            end
            if not part or not part:IsA('BasePart') then
                return nil
            end
    
            local character = part:FindFirstAncestorOfClass('Model')
            local player = character and PlayersService:GetPlayerFromCharacter(character)
            local humanoid = character and character:FindFirstChildOfClass('Humanoid')
            if not player or player == LocalPlayer or IsTriggerTeammate(player)
                or not humanoid or humanoid.Health <= 0 or HasCombatProtection(character)
            then
                return nil
            end
    
            CollectSelectedParts(character, SelectedParts)
            if #SelectedParts == 0 then
                return nil
            end
    
            for i = 1, #SelectedParts do
                local selectedPart = SelectedParts[i]
                if part == selectedPart then
                    return player, character, selectedPart
                end
            end
            return nil
        end
    
        local function GetFireRate()
            local character = LocalPlayer.Character
            local equipped = character and character:FindFirstChild('EquippedTool')
            local weaponName = equipped and tostring(equipped.Value)
            local weapons = ReplicatedStorage:FindFirstChild('Weapons')
            local weapon = weapons and weaponName and weapons:FindFirstChild(weaponName)
            local fireRate = weapon and weapon:FindFirstChild('FireRate')
            return fireRate and tonumber(fireRate.Value) or 0.1
        end
    
        local function FireWeapon()
            if not FireRemote or not FireRemote.Parent then
                local events = ReplicatedStorage:FindFirstChild('Events')
                FireRemote = events and events:FindFirstChild('weap')
            end
            if not FireRemote then
                return false
            end
            return pcall(function()
                FireRemote:Fire()
            end)
        end
    
        Library:GiveSignal(RunService.RenderStepped:Connect(function()
            if not Toggles.Triggerbot_Enable.Value or not Options.Triggerbot_Key:GetState() then
                if DelayTarget then
                    ResetDelay()
                end
                return
            end
    
            local now = os.clock()
            if now < NextUpdate then
                return
            end
            NextUpdate = now + GetUpdateInterval()
    
            local camera = workspace.CurrentCamera
            if not camera then
                ResetDelay()
                return
            end

            if not IsCombatRoundActive() or HasCombatProtection(LocalPlayer.Character) then
                ResetDelay()
                return
            end
    
            local player, _, part = GetTarget(camera)
            if not player then
                ResetDelay()
                return
            end
    
            if GetShotHitChance(part, camera) + 1e-3 < Options.Triggerbot_HitChance.Value then
                ResetDelay()
                return
            end
    
            if DelayTarget ~= player then
                DelayTarget = player
                DelayUntil = now + Options.Triggerbot_Delay.Value / 1000
            end
            if now < DelayUntil or now - LastFireAt < GetFireRate() then
                return
            end
    
            if FireWeapon() then
                LastFireAt = now
            end
        end))
    end
    
    -- RCS
    local RCS = LegitTab:AddRightGroupbox('RCS')
    
    RCS:AddToggle('RCS_Enable', { Text = 'Enable', Default = false })
    
    RCS:AddSlider('RCS_Strength', {
        Text = 'RCS',
        Default = 1,
        Min = 1,
        Max = 100,
        Rounding = 0,
    })
    
    do
        local SavedRecoil = setmetatable({}, { __mode = 'k' })
        local AppliedWeapon = nil
        local EquippedConn = nil
        local HookGeneration = 0
    
        local function GetEquippedWeaponName()
            local character = LocalPlayer.Character
            local eq = character and character:FindFirstChild('EquippedTool')
            if not eq then
                return nil
            end
            local name = tostring(eq.Value)
            if name == '' or name == 'nil' then
                return nil
            end
            return name
        end
    
        local function GetRecoilObject(weaponName)
            local weapons = ReplicatedStorage:FindFirstChild('Weapons')
            local weapon = weapons and weapons:FindFirstChild(weaponName)
            local spread = weapon and weapon:FindFirstChild('Spread')
            return spread and spread:FindFirstChild('Recoil') or nil
        end
    
        local function GetRecoilValue(original, strength)
            strength = math.clamp(strength or 1, 1, 100)
            if strength <= 1 then
                return original
            end
            -- 1 = оригинал, 100 = Recoil = 1 (ниже 1 лагает)
            local factor = (strength - 1) / 99
            local value = original + (1 - original) * factor
            return math.max(1, value)
        end
    
        local function SaveOriginal(recoil)
            if not recoil then
                return
            end
            if SavedRecoil[recoil] == nil then
                SavedRecoil[recoil] = recoil.Value
            end
        end
    
        local function RestoreRecoil(recoil)
            if not recoil then
                return
            end
            if SavedRecoil[recoil] ~= nil then
                pcall(function() recoil.Value = SavedRecoil[recoil] end)
            end
        end
    
        local function RestoreAll()
            for recoil in pairs(SavedRecoil) do
                RestoreRecoil(recoil)
            end
            table.clear(SavedRecoil)
            AppliedWeapon = nil
        end
    
        local function ApplyRCS()
            if not Toggles.RCS_Enable.Value then
                if AppliedWeapon then
                    RestoreRecoil(GetRecoilObject(AppliedWeapon))
                end
                AppliedWeapon = nil
                return
            end
    
            local weaponName = GetEquippedWeaponName()
            if not weaponName then
                return
            end
    
            if AppliedWeapon and AppliedWeapon ~= weaponName then
                RestoreRecoil(GetRecoilObject(AppliedWeapon))
            end
    
            local recoil = GetRecoilObject(weaponName)
            if not recoil then
                return
            end
    
            SaveOriginal(recoil)
            recoil.Value = GetRecoilValue(SavedRecoil[recoil], Options.RCS_Strength.Value)
            AppliedWeapon = weaponName
        end
    
        local function HookEquippedTool(character)
            HookGeneration = HookGeneration + 1
            local generation = HookGeneration
            if EquippedConn then
                EquippedConn:Disconnect()
                EquippedConn = nil
            end
            if not character then
                return
            end
    
            local eq = character:FindFirstChild('EquippedTool')
            if not eq then
                task.spawn(function()
                    eq = character:WaitForChild('EquippedTool', 5)
                    if generation == HookGeneration and eq and character == LocalPlayer.Character then
                        EquippedConn = eq:GetPropertyChangedSignal('Value'):Connect(ApplyRCS)
                        ApplyRCS()
                    end
                end)
                return
            end
    
            EquippedConn = eq:GetPropertyChangedSignal('Value'):Connect(ApplyRCS)
            ApplyRCS()
        end
    
        Toggles.RCS_Enable:OnChanged(ApplyRCS)
        Options.RCS_Strength:OnChanged(ApplyRCS)
    
        HookEquippedTool(LocalPlayer.Character)
        Library:GiveSignal(LocalPlayer.CharacterAdded:Connect(HookEquippedTool))
    
        AddUnload(function()
            HookGeneration = HookGeneration + 1
            if EquippedConn then
                EquippedConn:Disconnect()
                EquippedConn = nil
            end
            RestoreAll()
        end)
    end
    
    -- Box
    Players:AddToggle('ESP_Box', { Text = 'Box', Default = false })
        :AddColorPicker('ESP_Box_Color', { Default = Color3.fromRGB(255, 255, 255), Transparency = 0 })
    
    -- Name
    Players:AddToggle('ESP_Name', { Text = 'Name', Default = false })
        :AddColorPicker('ESP_Name_Color', { Default = Color3.fromRGB(255, 255, 255), Transparency = 0 })
    
    -- Distance
    Players:AddToggle('ESP_Distance', { Text = 'Distance', Default = false })
        :AddColorPicker('ESP_Distance_Color', { Default = Color3.fromRGB(255, 255, 255), Transparency = 0 })
    
    -- Weapon
    Players:AddToggle('ESP_Weapon', { Text = 'Weapon', Default = false })
        :AddColorPicker('ESP_Weapon_Color', { Default = Color3.fromRGB(255, 255, 255), Transparency = 0 })
    
    do
        local Drawings = {} -- player -> { Box, BoxOutline, Name, Distance, Weapon, HealthOutline, HealthBar, HealthFill }
        local WeaponCache = setmetatable({}, { __mode = 'k' })
        local NextUpdate = 0
    
        local function MakeSquare(thickness, filled)
            local ok, sq = pcall(Drawing.new, 'Square')
            if not ok or not sq then
                return nil
            end
            sq.Visible = false
            sq.Filled = filled == true
            sq.Thickness = filled and 0 or thickness
            sq.Transparency = 1
            sq.Color = Color3.fromRGB(255, 255, 255)
            return sq
        end
    
        local function MakeDrawingSet()
            local box = MakeSquare(1, false)
            local outline = MakeSquare(3, false)
            local healthOutline = MakeSquare(1.5, false)
            local healthBar = MakeSquare(1, false)
            local healthFill = MakeSquare(0, true)
            local name = MakeESPText()
            local distance = MakeESPText()
            local weapon = MakeESPText()
            if not box or not outline or not healthOutline or not healthBar or not healthFill or not name or not distance or not weapon then
                for _, d in ipairs({ box, outline, healthOutline, healthBar, healthFill, name, distance, weapon }) do
                    if d then
                        pcall(function()
                            d:Remove()
                        end)
                    end
                end
                return nil
            end
            outline.Color = Color3.fromRGB(0, 0, 0)
            healthOutline.Color = Color3.fromRGB(0, 0, 0)
            healthBar.Color = Color3.fromRGB(0, 0, 0)
            outline.ZIndex = 1
            box.ZIndex = 2
            healthOutline.ZIndex = 1
            healthBar.ZIndex = 2
            healthFill.ZIndex = 3
            name.ZIndex = 3
            distance.ZIndex = 3
            weapon.ZIndex = 3
            return {
                Box = box,
                BoxOutline = outline,
                HealthOutline = healthOutline,
                HealthBar = healthBar,
                HealthFill = healthFill,
                Name = name,
                Distance = distance,
                Weapon = weapon,
            }
        end
    
        local function RemoveDrawingSet(set)
            if not set then
                return
            end
            for _, d in pairs(set) do
                d.Visible = false
                pcall(function()
                    d:Remove()
                end)
            end
        end
    
        local function HideDrawingSet(set)
            if not set then return end
            for _, drawing in pairs(set) do
                drawing.Visible = false
            end
        end
    
        local function HidePlayer(player)
            HideDrawingSet(Drawings[player])
        end
    
        local function HideAll()
            for _, set in pairs(Drawings) do
                HideDrawingSet(set)
            end
        end
    
        local function RemovePlayer(player)
            RemoveDrawingSet(Drawings[player])
            Drawings[player] = nil
        end
    
        local function RemoveAll()
            for player in pairs(Drawings) do
                RemovePlayer(player)
            end
        end
    
        -- client.lua: EquippedTool / Character.Gun + GetTrueName.getName
        local function GetEquippedWeaponRaw(character)
            local eq = character:FindFirstChild('EquippedTool')
            if eq then
                local name = tostring(eq.Value)
                if name ~= '' and name ~= 'nil' then
                    return name
                end
            end
    
            local gun = character:FindFirstChild('Gun')
            if gun and gun.Name ~= '' and gun.Name ~= 'Gun' then
                return gun.Name
            end
    
            return nil
        end
    
        local function GetWeaponDisplayName(character)
            local raw = GetEquippedWeaponRaw(character)
            if not raw then
                WeaponCache[character] = nil
                return nil
            end
    
            local cached = WeaponCache[character]
            if cached and cached.raw == raw then
                return cached.name
            end
    
            local name = raw
            if GetTrueName and GetTrueName.getName then
                local ok, pretty = pcall(GetTrueName.getName, raw)
                if ok and pretty and tostring(pretty) ~= '' then
                    name = tostring(pretty)
                end
            end
    
            WeaponCache[character] = { raw = raw, name = name }
            return name
        end
    
        -- dynamic 2D box от HRP Y-offsets, не 3D corners
        local function getCharacterScreenBox(rootPart, camera)
            if not rootPart or not camera then
                return nil
            end
    
            local rootPos = rootPart.Position
            local top = Vector3.new(rootPos.X, rootPos.Y + 2.45, rootPos.Z)
            local bottom = Vector3.new(rootPos.X, rootPos.Y - 3.1, rootPos.Z)
    
            local topScreen, topOn = camera:WorldToViewportPoint(top)
            local bottomScreen, bottomOn = camera:WorldToViewportPoint(bottom)
            if not topOn and not bottomOn then
                return nil
            end
    
            local height = bottomScreen.Y - topScreen.Y
            local width = height / 2
            return Round(topScreen.X - width / 2), Round(topScreen.Y), Round(width), Round(height)
        end
    
        Library:GiveSignal(RunService.RenderStepped:Connect(function()
            local now = os.clock()
            if now < NextUpdate then
                return
            end
            NextUpdate = now + GetUpdateInterval()
    
            local showBox = Toggles.ESP_Box.Value
            local showName = Toggles.ESP_Name.Value
            local showDistance = Toggles.ESP_Distance.Value
            local showWeapon = Toggles.ESP_Weapon.Value
            local showHealthBar = Toggles.ESP_HealthBar.Value
    
            if not Toggles.ESP_Enable.Value
                or (not showBox and not showName and not showDistance and not showWeapon and not showHealthBar)
            then
                HideAll()
                return
            end
    
            local camera = workspace.CurrentCamera
            if not camera then
                HideAll()
                return
            end
    
            local boxColor = Options.ESP_Box_Color.Value
            local boxAlpha = math.clamp(1 - (Options.ESP_Box_Color.Transparency or 0), 0, 1)
            local nameColor = Options.ESP_Name_Color.Value
            local nameAlpha = math.clamp(1 - (Options.ESP_Name_Color.Transparency or 0), 0, 1)
            local distColor = Options.ESP_Distance_Color.Value
            local distAlpha = math.clamp(1 - (Options.ESP_Distance_Color.Transparency or 0), 0, 1)
            local weaponColor = Options.ESP_Weapon_Color.Value
            local weaponAlpha = math.clamp(1 - (Options.ESP_Weapon_Color.Transparency or 0), 0, 1)
            local healthHigh = Options.ESP_HealthBar_High.Value
            local healthLow = Options.ESP_HealthBar_Low.Value
            local healthAlpha = math.clamp(1 - (Options.ESP_HealthBar_High.Transparency or 0), 0, 1)
            local camPos = camera.CFrame.Position
            for _, player in ipairs(PlayerSnapshot) do
                if player == LocalPlayer or IsTeammate(player) then
                    HidePlayer(player)
                    continue
                end
    
                local character = player.Character
                local root = character and character:FindFirstChild('HumanoidRootPart')
                local humanoid = character and character:FindFirstChildOfClass('Humanoid')
                if not root or not humanoid or humanoid.Health <= 0 then
                    HidePlayer(player)
                    continue
                end
    
                local left, top, width, height = getCharacterScreenBox(root, camera)
                if not left then
                    HidePlayer(player)
                    continue
                end
    
                local set = Drawings[player]
                if not set then
                    set = MakeDrawingSet()
                    if not set then
                        continue
                    end
                    Drawings[player] = set
                end
    
                local boxPos = Vector2.new(left, top)
                local boxSize = Vector2.new(width, height)
                local bottom = top + height
                local centerX = left + width * 0.5
    
                if showBox then
                    set.BoxOutline.Size = boxSize
                    set.BoxOutline.Position = boxPos
                    set.BoxOutline.Transparency = boxAlpha
                    set.BoxOutline.Visible = true
    
                    set.Box.Size = boxSize
                    set.Box.Position = boxPos
                    set.Box.Color = boxColor
                    set.Box.Transparency = boxAlpha
                    set.Box.Visible = true
                else
                    set.Box.Visible = false
                    set.BoxOutline.Visible = false
                end
    
                if showName then
                    set.Name.Text = player.DisplayName
                    set.Name.Color = nameColor
                    set.Name.Transparency = nameAlpha
                    set.Name.Position = Round2(Vector2.new(centerX, top - 14))
                    set.Name.Visible = true
                else
                    set.Name.Visible = false
                end
    
                if showDistance then
                    local studs = Round((camPos - root.Position).Magnitude)
                    set.Distance.Text = tostring(studs) .. 'm'
                    set.Distance.Color = distColor
                    set.Distance.Transparency = distAlpha
                    set.Distance.Position = Round2(Vector2.new(centerX, bottom + 1))
                    set.Distance.Visible = true
                else
                    set.Distance.Visible = false
                end
    
                if showWeapon then
                    local weaponName = GetWeaponDisplayName(character)
                    if weaponName then
                        local y = bottom + 1
                        if showDistance then
                            y = y + 13
                        end
                        set.Weapon.Text = weaponName
                        set.Weapon.Color = weaponColor
                        set.Weapon.Transparency = weaponAlpha
                        set.Weapon.Position = Round2(Vector2.new(centerX, y))
                        set.Weapon.Visible = true
                    else
                        set.Weapon.Visible = false
                    end
                else
                    set.Weapon.Visible = false
                end
    
                if showHealthBar then
                    local barOuterW = 3
                    local gap = 1
                    local inset = 1
                    local barX = left - gap - barOuterW
                    local barSize = Round2(Vector2.new(barOuterW, height))
                    local barPos = Round2(Vector2.new(barX, top))
                    local innerH = math.max(1, height - inset * 2)
                    local ratio = math.clamp(humanoid.Health / humanoid.MaxHealth, 0, 1)
                    local fillH = math.max(1, Round(innerH * ratio))
                    local fillW = barOuterW - inset * 2
                    local fillY = top + height - inset - fillH
    
                    set.HealthOutline.Size = barSize
                    set.HealthOutline.Position = barPos
                    set.HealthOutline.Transparency = healthAlpha
                    set.HealthOutline.Visible = true
    
                    set.HealthBar.Size = barSize
                    set.HealthBar.Position = barPos
                    set.HealthBar.Transparency = healthAlpha
                    set.HealthBar.Visible = true
    
                    set.HealthFill.Size = Round2(Vector2.new(fillW, fillH))
                    set.HealthFill.Position = Round2(Vector2.new(barX + inset, fillY))
                    set.HealthFill.Color = healthLow:Lerp(healthHigh, ratio)
                    set.HealthFill.Transparency = healthAlpha
                    set.HealthFill.Visible = true
                else
                    set.HealthOutline.Visible = false
                    set.HealthBar.Visible = false
                    set.HealthFill.Visible = false
                end
    
            end
        end))
    
        Library:GiveSignal(PlayersService.PlayerRemoving:Connect(function(player)
            RemovePlayer(player)
        end))
    
        AddUnload(function()
            RemoveAll()
        end)
    end
    
    -- HealthBar
    Players:AddToggle('ESP_HealthBar', { Text = 'HealthBar', Default = false })
        :AddColorPicker('ESP_HealthBar_High', { Default = Color3.fromRGB(0, 255, 0), Transparency = 0 })
        :AddColorPicker('ESP_HealthBar_Low', { Default = Color3.fromRGB(255, 0, 0), Transparency = 0 })
    
    -- Dropped
    Players:AddToggle('ESP_Dropped', { Text = 'Dropped item', Default = false })
        :AddColorPicker('ESP_Dropped_Color', {
            Default = Color3.fromRGB(255, 255, 255),
            Transparency = 0,
        })
    
    do
        local DropDrawings = {} -- instance -> Drawing.Text
        local DropNames = {}
        local DropItems, DropIndex = {}, {}
        local BoundDebris, DebrisConnections = nil, {}
        local NextUpdate = 0
    
        local function RemoveDrop(item)
            local draw = DropDrawings[item]
            if draw then
                draw.Visible = false
                pcall(function()
                    draw:Remove()
                end)
                DropDrawings[item] = nil
            end
        end
    
        local function RemoveAllDrops()
            for item in pairs(DropDrawings) do
                RemoveDrop(item)
            end
        end

        local function RemoveDropItem(item)
            local index = DropIndex[item]
            if index then
                local last = DropItems[#DropItems]
                DropItems[index] = last
                DropItems[#DropItems] = nil
                DropIndex[item] = nil
                if last ~= item then DropIndex[last] = index end
            end
            RemoveDrop(item)
        end

        local function IsDroppedWeapon(item, weapons)
            if not item or item:GetAttribute('RagDoll') then
                return false
            end
            return weapons and weapons:FindFirstChild(item.Name) ~= nil
        end

        local function BindDebris(folder)
            if BoundDebris == folder then return end
            for i = 1, #DebrisConnections do DebrisConnections[i]:Disconnect() end
            table.clear(DebrisConnections)
            RemoveAllDrops()
            table.clear(DropItems)
            table.clear(DropIndex)
            BoundDebris = folder
            if not folder then return end
            local weapons = GetWeaponsFolder()
            for _, item in ipairs(folder:GetChildren()) do
                if IsDroppedWeapon(item, weapons) then
                    DropItems[#DropItems + 1] = item
                    DropIndex[item] = #DropItems
                end
            end
            DebrisConnections[#DebrisConnections + 1] = folder.ChildAdded:Connect(function(item)
                if not DropIndex[item] and IsDroppedWeapon(item, GetWeaponsFolder()) then
                    DropItems[#DropItems + 1] = item
                    DropIndex[item] = #DropItems
                end
            end)
            DebrisConnections[#DebrisConnections + 1] = folder.ChildRemoved:Connect(RemoveDropItem)
        end
    
        local function GetDropPosition(item)
            if item:IsA('BasePart') then
                return item.Position
            end
            if item:IsA('Model') then
                return item:GetPivot().Position
            end
            local part = item:FindFirstChildWhichIsA('BasePart', true)
            return part and part.Position or nil
        end
    
        local function GetDropDisplayName(item)
            local raw = item.Name
            local cached = DropNames[raw]
            if cached then
                return cached
            end
    
            local name = raw
            if GetTrueName and GetTrueName.getName then
                local ok, pretty = pcall(GetTrueName.getName, raw)
                if ok and pretty and tostring(pretty) ~= '' then
                    name = tostring(pretty)
                end
            end
            DropNames[raw] = name
            return name
        end
    
        Library:GiveSignal(RunService.RenderStepped:Connect(function()
            local now = os.clock()
            if now < NextUpdate then
                return
            end
            NextUpdate = now + GetUpdateInterval()
    
            if not Toggles.ESP_Enable.Value or not Toggles.ESP_Dropped.Value then
                if BoundDebris then BindDebris(nil) end
                RemoveAllDrops()
                return
            end
    
            local camera = workspace.CurrentCamera
            local debris = GetDebrisRoot()
            local weapons = GetWeaponsFolder()
            if not camera or not debris or not weapons then
                if not debris and BoundDebris then BindDebris(nil) end
                RemoveAllDrops()
                return
            end
    
            local color = Options.ESP_Dropped_Color.Value
            local alpha = math.clamp(1 - (Options.ESP_Dropped_Color.Transparency or 0), 0, 1)
            BindDebris(debris)
            for i = 1, #DropItems do
                local item = DropItems[i]
                if not IsDroppedWeapon(item, weapons) then
                    continue
                end
    
                local pos3 = GetDropPosition(item)
                if not pos3 then
                    RemoveDrop(item)
                    continue
                end
    
                local screen, onScreen = camera:WorldToViewportPoint(pos3)
                if not onScreen or screen.Z <= 0 then
                    local draw = DropDrawings[item]
                    if draw then draw.Visible = false end
                    continue
                end
    
                local draw = DropDrawings[item]
                if not draw then
                    draw = MakeESPText()
                    if not draw then
                        continue
                    end
                    DropDrawings[item] = draw
                end
    
                draw.Text = GetDropDisplayName(item)
                draw.Color = color
                draw.Transparency = alpha
                draw.Position = Round2(Vector2.new(screen.X, screen.Y))
                draw.Visible = true
            end
        end))
    
        AddUnload(function()
            for i = 1, #DebrisConnections do DebrisConnections[i]:Disconnect() end
            table.clear(DebrisConnections)
            table.clear(DropItems)
            table.clear(DropIndex)
            RemoveAllDrops()
        end)
    end
    
    -- Chams
    Players:AddToggle('ESP_Chams', { Text = 'Chams', Default = false })
        :AddColorPicker('ESP_Chams_Visible', {
            Default = Color3.fromRGB(0, 255, 0),
            Transparency = 0.5,
            Title = 'Visible',
        })
        :AddColorPicker('ESP_Chams_Wall', {
            Default = Color3.fromRGB(255, 0, 0),
            Transparency = 0.5,
            Title = 'Behind wall',
        })
    
    Players:AddToggle('ESP_ChamsOutline', { Text = 'Chams Outline', Default = false })
        :AddColorPicker('ESP_Chams_Outline', {
            Default = Color3.fromRGB(255, 255, 255),
            Transparency = 0,
            Title = 'Outline',
        })

    do
        local Highlights = {}
        local VisCache = {}
        local ChamsFolder
        local NextUpdate = 0
        local RayParams = RaycastParams.new()
        local RaycastIgnore = {}
        RayParams.FilterType = Enum.RaycastFilterType.Exclude
        local function GetChamsFolder()
            if ChamsFolder and ChamsFolder.Parent then return ChamsFolder end
            ChamsFolder = Instance.new('Folder')
            ChamsFolder.Name = 'ValenokChams'
            ChamsFolder.Parent = workspace
            return ChamsFolder
        end
    
        local function RemoveChams(player)
            local hl = Highlights[player]
            if hl then
                pcall(function()
                    hl:Destroy()
                end)
                Highlights[player] = nil
            end
            VisCache[player] = nil
        end
    
        local function RemoveAllChams()
            for player in pairs(Highlights) do
                RemoveChams(player)
            end
        end
    
        local function HideChams(player)
            local hl = Highlights[player]
            if hl then
                hl.Enabled = false
                hl.Adornee = nil
            end
            VisCache[player] = nil
        end
    
        local function HideAllChams()
            for player in pairs(Highlights) do
                HideChams(player)
            end
        end
    
        local function IsPlayerVisible(character, camera)
            local checkPart = character:FindFirstChild('Head')
                or character:FindFirstChild('UpperTorso')
                or character:FindFirstChild('HumanoidRootPart')
            if not checkPart then
                return false
            end
    
            local _, onScreen = camera:WorldToViewportPoint(checkPart.Position)
            if not onScreen then
                return false
            end
    
            local origin = camera.CFrame.Position
            local target = checkPart.Position
            local dir = target - origin
            if dir.Magnitude <= 1e-4 then
                return false
            end
    
            RaycastIgnore[1] = character
            RaycastIgnore[2] = LocalPlayer.Character
            AppendSharedRaycastIgnore(RaycastIgnore, 3)
            RayParams.FilterDescendantsInstances = RaycastIgnore
    
            local result = workspace:Raycast(origin, dir, RayParams)
            if not result then
                return true
            end
            return result.Instance:IsDescendantOf(character)
        end
    
        local function GetChamsStyle(player, character, camera, now)
            local cached = VisCache[player]
            if cached and cached.character == character and (now - cached.t) < 0.06 then
                return cached.color, cached.transparency
            end
    
            local visible = IsPlayerVisible(character, camera)
            local opt = visible and Options.ESP_Chams_Visible or Options.ESP_Chams_Wall
            local color, transparency = opt.Value, opt.Transparency
    
            cached = cached or {}
            cached.character = character
            cached.t = now
            cached.color = color
            cached.transparency = transparency
            VisCache[player] = cached
    
            return color, transparency
        end

        Library:GiveSignal(RunService.RenderStepped:Connect(function()
            local now = os.clock()
            if now < NextUpdate then
                return
            end
            NextUpdate = now + GetUpdateInterval()
    
            local chamsOn = Toggles.ESP_Chams.Value
            local outlineOn = Toggles.ESP_ChamsOutline.Value

            if not Toggles.ESP_Enable.Value or (not chamsOn and not outlineOn) then
                HideAllChams()
                return
            end
    
            local camera = workspace.CurrentCamera
            if not camera then
                HideAllChams()
                return
            end
    
            local outlineColor = Options.ESP_Chams_Outline.Value
            local outlineTransparency = Options.ESP_Chams_Outline.Transparency
            for _, player in ipairs(PlayerSnapshot) do
                if player == LocalPlayer or IsTeammate(player) then
                    HideChams(player)
                    continue
                end
    
                local character = player.Character
                local root = character and character:FindFirstChild('HumanoidRootPart')
                local humanoid = character and character:FindFirstChildOfClass('Humanoid')
                if not root or not humanoid or humanoid.Health <= 0 then
                    HideChams(player)
                    continue
                end
    
                local fillColor, fillTransparency
                if chamsOn then
                    fillColor, fillTransparency = GetChamsStyle(player, character, camera, now)
                else
                    fillColor, fillTransparency = Color3.new(), 1
                end
    
                local hl = Highlights[player]
                if not hl or not hl.Parent then
                    hl = Instance.new('Highlight')
                    hl.Name = '__ValenokChams'
                    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                    hl.Parent = GetChamsFolder()
                    Highlights[player] = hl
                end
    
                hl.Enabled = true
                hl.Adornee = character
                hl.FillColor = fillColor
                hl.OutlineColor = outlineColor
                hl.FillTransparency = chamsOn and fillTransparency or 1
                hl.OutlineTransparency = outlineOn and outlineTransparency or 1
            end
        end))
    
        Library:GiveSignal(PlayersService.PlayerRemoving:Connect(function(player)
            RemoveChams(player)
        end))
    
        AddUnload(function()
            RemoveAllChams()
            if ChamsFolder then
                ChamsFolder:Destroy()
                ChamsFolder = nil
            end
        end)
    end
    
    -- View Model
    do
        local FORCEFIELD_TEXTURE = 'rbxassetid://4573037993'
        local Cache = { Arms = nil, WeaponParts = {}, ArmItems = {}, IsKnife = false, Handle = nil }
        local Connections = {}
        local CameraConnection
        local RestoreConnection
        local NextRestore = 0
        local CleanedParts = setmetatable({}, { __mode = 'k' })

        local function DisconnectCache()
            for i = 1, #Connections do
                Connections[i]:Disconnect()
            end
            table.clear(Connections)
        end

        local function ViewModelEnabled()
            return Toggles.ViewModel_WeaponChams.Value
                or Toggles.ViewModel_ArmChams.Value
                or Toggles.ViewModel_RemoveSleeves.Value
                or Toggles.ViewModel_RemoveGloves.Value
        end

        local function IsWeaponPart(part)
            local name = part.Name
            local lower = string.lower(name)
            if lower == 'shoot' or lower == 'sshoot' or string.find(lower, 'flash', 1, true) or string.find(lower, 'muzzle', 1, true) then
                return false
            end
            return part:IsA('MeshPart')
                or (part:IsA('BasePart') and (name == 'Part' or name == 'Handle' or name == 'Handle2' or name == 'Blade'
                    or name == 'Suppressed' or name == 'StatClock' or string.find(name, 'Silencer', 1, true)))
        end

        local function RebuildCache(arms)
            Cache.Arms = arms
            table.clear(Cache.WeaponParts)
            table.clear(Cache.ArmItems)
            Cache.IsKnife = false
            Cache.Handle = nil

            for _, child in ipairs(arms:GetChildren()) do
                if child:IsA('Model') then
                    for _, item in ipairs(child:GetDescendants()) do
                        local name = item.Name
                        local lower = string.lower(name)
                        Cache.ArmItems[#Cache.ArmItems + 1] = {
                            item = item,
                            isSleeve = name == 'Sleeve',
                            isGlove = name == 'Glove' or name == 'RGlove' or name == 'LGlove'
                                or string.find(lower, 'glove', 1, true) ~= nil,
                        }
                    end
                elseif IsWeaponPart(child) then
                    Cache.WeaponParts[#Cache.WeaponParts + 1] = child
                    local name = child.Name
                    if string.find(name, 'Knife', 1, true) or name == 'Handle2' or name == 'Blade' then
                        Cache.IsKnife = true
                    end
                    if name == 'Handle' then
                        Cache.Handle = child
                    end
                end
            end
        end

        local EnsureCache

        local function ApplyWeaponPart(part, color, material, transparency)
            if not part.Parent then
                return
            end
            part.Color = color
            part.Material = material
            if part.Transparency < 1 then
                part.Transparency = transparency
            end
            if part:IsA('MeshPart') then
                part.TextureID = ''
            end
            if not CleanedParts[part] then
                CleanedParts[part] = true
                local appearance = part:FindFirstChildOfClass('SurfaceAppearance')
                if appearance then
                    appearance:Destroy()
                end
                if part.Name == 'StatClock' then
                    part:ClearAllChildren()
                end
            end
        end

        local function UpdateViewModelVisuals()
            local weaponOn = Toggles.ViewModel_WeaponChams.Value
            local armOn = Toggles.ViewModel_ArmChams.Value
            local removeSleeves = Toggles.ViewModel_RemoveSleeves.Value
            local removeGloves = Toggles.ViewModel_RemoveGloves.Value
            if not weaponOn and not armOn and not removeSleeves and not removeGloves then
                return
            end

            local camera = workspace.CurrentCamera
            local arms = camera and camera:FindFirstChild('Arms')
            if not arms then
                return
            end
            if Cache.Arms ~= arms then
                EnsureCache(arms)
            end
    
            if weaponOn then
                local color = Options.ViewModel_WeaponColor.Value
                local material = Enum.Material[Options.ViewModel_WeaponMaterial.Value] or Enum.Material.SmoothPlastic
                local transparency = Options.ViewModel_WeaponTransparency.Value / 100
                for i = 1, #Cache.WeaponParts do
                    ApplyWeaponPart(Cache.WeaponParts[i], color, material, transparency)
                end
                if Cache.IsKnife and Cache.Handle and Cache.Handle.Parent then
                    Cache.Handle.Transparency = 1
                end
            end

            if armOn or removeSleeves or removeGloves then
                local armColor = Options.ViewModel_ArmColor.Value
                local armMaterialName = Options.ViewModel_ArmMaterial.Value
                local armMaterial = Enum.Material[armMaterialName] or Enum.Material.SmoothPlastic
                local armTransparency = Options.ViewModel_ArmTransparency.Value / 100
                local vertexColor = Vector3.new(armColor.R, armColor.G, armColor.B)
                for i = 1, #Cache.ArmItems do
                    local entry = Cache.ArmItems[i]
                    local item = entry.item
                    if item.Parent then
                        if removeSleeves and entry.isSleeve and not item:GetAttribute('CW_Applied') then
                            item:Destroy()
                        elseif removeGloves and entry.isGlove then
                            item:Destroy()
                        elseif armOn then
                            if item:IsA('SpecialMesh') then
                                item.VertexColor = vertexColor
                                if armMaterialName == 'ForceField' then item.TextureId = FORCEFIELD_TEXTURE end
                            elseif item:IsA('BasePart') then
                                item.Color = armColor
                                item.Material = armMaterial
                                item.Transparency = armTransparency
                                item.CastShadow = false
                            end
                        end
                    end
                end
            end
        end

        function EnsureCache(arms)
            if Cache.Arms == arms then
                return
            end

            DisconnectCache()
            RebuildCache(arms)
            Connections[#Connections + 1] = arms.DescendantAdded:Connect(function()
                if Cache.Arms == arms then
                    RebuildCache(arms)
                    UpdateViewModelVisuals()
                end
            end)
            Connections[#Connections + 1] = arms.DescendantRemoving:Connect(function()
                if Cache.Arms == arms then
                    RebuildCache(arms)
                    UpdateViewModelVisuals()
                end
            end)
            Connections[#Connections + 1] = arms.AncestryChanged:Connect(function(_, parent)
                if not parent and Cache.Arms == arms then
                    Cache.Arms = nil
                    table.clear(Cache.WeaponParts)
                    table.clear(Cache.ArmItems)
                end
            end)
        end

        local function RefreshRestoreConnection()
            if ViewModelEnabled() then
                if not RestoreConnection then
                    RestoreConnection = RunService.Heartbeat:Connect(function()
                        local now = os.clock()
                        if now < NextRestore then
                            return
                        end
                        NextRestore = now + 0.25
                        if ViewModelEnabled() then
                            UpdateViewModelVisuals()
                        end
                    end)
                    Library:GiveSignal(RestoreConnection)
                end
            elseif RestoreConnection then
                RestoreConnection:Disconnect()
                RestoreConnection = nil
            end
        end

        local function BindCamera(camera)
            if CameraConnection then
                CameraConnection:Disconnect()
                CameraConnection = nil
            end
            if not camera then
                return
            end
            CameraConnection = camera.ChildAdded:Connect(function(child)
                if child.Name == 'Arms' then
                    EnsureCache(child)
                end
            end)
            Library:GiveSignal(CameraConnection)
            local arms = camera:FindFirstChild('Arms')
            if arms then
                EnsureCache(arms)
            end
        end

        local function ApplyNow()
            UpdateViewModelVisuals()
            RefreshRestoreConnection()
        end

        for _, option in ipairs({
            Toggles.ViewModel_WeaponChams, Toggles.ViewModel_ArmChams, Toggles.ViewModel_RemoveSleeves, Toggles.ViewModel_RemoveGloves,
            Options.ViewModel_WeaponColor, Options.ViewModel_WeaponMaterial, Options.ViewModel_WeaponTransparency,
            Options.ViewModel_ArmColor, Options.ViewModel_ArmMaterial, Options.ViewModel_ArmTransparency,
        }) do
            option:OnChanged(ApplyNow)
        end

        BindCamera(workspace.CurrentCamera)
        Library:GiveSignal(workspace:GetPropertyChangedSignal('CurrentCamera'):Connect(function()
            DisconnectCache()
            Cache.Arms = nil
            table.clear(Cache.WeaponParts)
            table.clear(Cache.ArmItems)
            BindCamera(workspace.CurrentCamera)
            UpdateViewModelVisuals()
        end))

        RefreshRestoreConnection()

        AddUnload(function()
            DisconnectCache()
            if CameraConnection then
                CameraConnection:Disconnect()
                CameraConnection = nil
            end
            if RestoreConnection then
                RestoreConnection:Disconnect()
                RestoreConnection = nil
            end
        end)
    end

    -- FOV Changer
    do
        local camera = workspace.CurrentCamera
        local SavedFov = camera and camera.FieldOfView or 70
        local DefaultFov = math.clamp(math.floor(SavedFov + 0.5), 30, 120)

        local FovChanger = VisualTab:AddLeftGroupbox('FOV Changer')
        FovChanger:AddToggle('FovChanger_Enable', { Text = 'Enable', Default = false })
        FovChanger:AddSlider('FovChanger_Fov', {
            Text = 'FOV',
            Default = DefaultFov,
            Min = 30,
            Max = 120,
            Rounding = 0,
        })

        local function IsSpectating()
            local status = LocalPlayer:FindFirstChild('Status')
            local team = status and status:FindFirstChild('Team')
            local alive = status and status:FindFirstChild('Alive')
            return (team and tostring(team.Value) == 'Spectator') or (alive and alive.Value == false)
        end

        local function ApplyFov()
            local cam = workspace.CurrentCamera
            if not cam then
                return
            end
            if IsSpectating() then
                return
            end
            if Toggles.FovChanger_Enable.Value then
                cam.FieldOfView = Options.FovChanger_Fov.Value
            else
                cam.FieldOfView = SavedFov
            end
        end

        Toggles.FovChanger_Enable:OnChanged(ApplyFov)
        Options.FovChanger_Fov:OnChanged(function()
            if Toggles.FovChanger_Enable.Value then
                ApplyFov()
            end
        end)

        Library:GiveSignal(RunService.Heartbeat:Connect(function()
            if Toggles.FovChanger_Enable.Value and not IsSpectating() then
                local cam = workspace.CurrentCamera
                if cam and cam.FieldOfView ~= Options.FovChanger_Fov.Value then
                    cam.FieldOfView = Options.FovChanger_Fov.Value
                end
            end
        end))

        Library:GiveSignal(workspace:GetPropertyChangedSignal('CurrentCamera'):Connect(function()
            local cam = workspace.CurrentCamera
            if cam and not Toggles.FovChanger_Enable.Value and not IsSpectating() then
                SavedFov = cam.FieldOfView
            end
            ApplyFov()
        end))

        AddUnload(function()
            local cam = workspace.CurrentCamera
            if cam and not IsSpectating() then
                cam.FieldOfView = SavedFov
            end
        end)
    end

    -- ThirdPerson
    local ThirdPerson = VisualTab:AddLeftGroupbox('ThirdPerson')
    
    ThirdPerson:AddToggle('ThirdPerson_Enable', {
        Text = 'Enable',
        Default = false,
    }):AddKeyPicker('ThirdPerson_Key', {
        Default = 'None',
        Mode = 'Toggle',
        Text = 'ThirdPerson',
    })
    
    ThirdPerson:AddSlider('ThirdPerson_Distance', {
        Text = 'Distance',
        Default = 10,
        Min = 1,
        Max = 100,
        Rounding = 0,
    })

    ThirdPerson:AddToggle('ThirdPerson_HideViewModel', {
        Text = 'Hide viewmodel',
        Default = true,
    }):AddKeyPicker('ThirdPerson_HideViewModel_Key', {
        Default = 'None',
        Mode = 'Toggle',
        Text = 'Hide viewmodel',
    })
    
    ThirdPerson:AddToggle('ThirdPerson_ThroughWalls', {
        Text = 'Through walls',
        Default = false,
    })
    
    do
        local TP_NOCLIP_NAME = 'ValenokTPNoClip'
        local NoClipBound = false
        local lastActive = false
        local NextUpdate = 0
        local NextNoClipUpdate = 0
        local ViewModelCache = {
            arms = nil,
            parts = nil,
            hideState = nil,
        }
    
        local function IsThirdPersonActive()
            return Toggles.ThirdPerson_Enable.Value and Options.ThirdPerson_Key:GetState()
        end

        local function IsViewModelHidden()
            local keybind = Options.ThirdPerson_HideViewModel_Key
            return Toggles.ThirdPerson_HideViewModel.Value
                and (not keybind or keybind.Value == 'None' or keybind:GetState())
        end

        local function RestoreViewModel()
            for _, part in ipairs(ViewModelCache.parts or {}) do
                if part and part.Parent then
                    part.LocalTransparencyModifier = 0
                end
            end

            ViewModelCache.arms = nil
            ViewModelCache.parts = nil
            ViewModelCache.hideState = nil
        end

        local function UpdateViewModelVisibility(isThirdPerson)
            local camera = workspace.CurrentCamera
            local arms = camera and camera:FindFirstChild('Arms')

            if arms ~= ViewModelCache.arms then
                RestoreViewModel()
                if not arms then
                    return
                end

                local parts = {}
                for _, part in ipairs(arms:GetDescendants()) do
                    if part:IsA('BasePart') then
                        parts[#parts + 1] = part
                    end
                end

                ViewModelCache.arms = arms
                ViewModelCache.parts = parts
            end

            local hideState = isThirdPerson and IsViewModelHidden()
            if ViewModelCache.hideState == hideState then
                return
            end

            ViewModelCache.hideState = hideState
            for _, part in ipairs(ViewModelCache.parts or {}) do
                if part and part.Parent then
                    part.LocalTransparencyModifier = hideState and 1 or 0
                end
            end
        end
    
        local function SetFirstPerson()
            LocalPlayer.CameraMode = Enum.CameraMode.LockFirstPerson
            LocalPlayer.CameraMaxZoomDistance = 0.5
            LocalPlayer.CameraMinZoomDistance = 0.5
        end
    
        local function SetThirdPerson()
            LocalPlayer.CameraMode = Enum.CameraMode.Classic
            local dist = Options.ThirdPerson_Distance.Value
            LocalPlayer.CameraMaxZoomDistance = dist
            LocalPlayer.CameraMinZoomDistance = dist
        end
    
        local function UnbindThroughWalls()
            if not NoClipBound then
                return
            end
            pcall(function()
                RunService:UnbindFromRenderStep(TP_NOCLIP_NAME)
            end)
            NoClipBound = false
        end
    
        local function BindThroughWalls()
            UnbindThroughWalls()
    
            if not (IsThirdPersonActive() and Toggles.ThirdPerson_ThroughWalls.Value) then
                return
            end
    
            RunService:BindToRenderStep(TP_NOCLIP_NAME, Enum.RenderPriority.Camera.Value + 1, function()
                local now = os.clock()
                if now < NextNoClipUpdate then
                    return
                end
                NextNoClipUpdate = now + GetUpdateInterval()
    
                if not (IsThirdPersonActive() and Toggles.ThirdPerson_ThroughWalls.Value) then
                    return
                end
    
                local camera = workspace.CurrentCamera
                local character = LocalPlayer.Character
                if not camera or not character then
                    return
                end
    
                local root = character:FindFirstChild('HumanoidRootPart')
                local humanoid = character:FindFirstChildOfClass('Humanoid')
                if not root or not humanoid or humanoid.Health <= 0 then
                    return
                end
    
                local dist = Options.ThirdPerson_Distance.Value
                local lookDir = camera.CFrame.LookVector
                local camPos = root.Position - lookDir * dist + Vector3.new(0, 2, 0)
                camera.CFrame = CFrame.new(camPos) * camera.CFrame.Rotation
            end)
    
            NoClipBound = true
        end
    
        local function ApplyThirdPerson()
            local active = IsThirdPersonActive()
            UpdateViewModelVisibility(active)
    
            if active then
                SetThirdPerson()
            else
                SetFirstPerson()
            end
    
            lastActive = active
            BindThroughWalls()
        end
    
        Library:GiveSignal(RunService.RenderStepped:Connect(function()
            local now = os.clock()
            if now < NextUpdate then
                return
            end
            NextUpdate = now + GetUpdateInterval()
    
            local active = IsThirdPersonActive()
            UpdateViewModelVisibility(active)
            if active ~= lastActive then
                ApplyThirdPerson()
            elseif active then
                local dist = Options.ThirdPerson_Distance.Value
                if LocalPlayer.CameraMaxZoomDistance ~= dist then
                    LocalPlayer.CameraMaxZoomDistance = dist
                    LocalPlayer.CameraMinZoomDistance = dist
                end
            end
        end))
    
        Toggles.ThirdPerson_Enable:OnChanged(ApplyThirdPerson)
        Options.ThirdPerson_Distance:OnChanged(function()
            if IsThirdPersonActive() then
                SetThirdPerson()
            end
        end)
        Toggles.ThirdPerson_ThroughWalls:OnChanged(BindThroughWalls)
        Toggles.ThirdPerson_HideViewModel:OnChanged(function()
            UpdateViewModelVisibility(IsThirdPersonActive())
        end)
        Options.ThirdPerson_HideViewModel_Key:OnChanged(function()
            UpdateViewModelVisibility(IsThirdPersonActive())
        end)
    
        AddUnload(function()
            UnbindThroughWalls()
            RestoreViewModel()
            SetFirstPerson()
        end)
    end
    
    local Menu = VisualTab:AddLeftGroupbox('Menu')
    
    Menu:AddToggle('Menu_Watermark', { Text = 'Watermark', Default = true })
    Menu:AddToggle('Menu_Keybinds', { Text = 'Keybinds', Default = true })
    
    do
        local fpsAccum = 0
        local fpsFrames = 0
        local lastUpdate = 0
    
        local function SetKeybindsVisible(state)
            if Library.KeybindFrame then
                Library.KeybindFrame.Visible = state
            end
        end
    
        Toggles.Menu_Watermark:OnChanged(function()
            if not Toggles.Menu_Watermark.Value then
                Library:SetWatermarkVisibility(false)
            end
        end)
    
        Toggles.Menu_Keybinds:OnChanged(SetKeybindsVisible)
        SetKeybindsVisible(Toggles.Menu_Keybinds.Value)
    
        Library:GiveSignal(RunService.RenderStepped:Connect(function(dt)
            fpsAccum = fpsAccum + dt
            fpsFrames = fpsFrames + 1
    
            local now = os.clock()
            if now - lastUpdate < 0.5 then
                return
            end
            lastUpdate = now
    
            if not Toggles.Menu_Watermark.Value then
                return
            end
    
            local fps = fpsFrames / fpsAccum
            fpsFrames = 0
            fpsAccum = 0
    
            Library:SetWatermark(string.format(
                'ValenokRecode | FPS %d | %d ms | %s',
                Round(fps),
                Round(LocalPlayer:GetNetworkPing() * 1000),
                os.date('%H:%M')
            ))
        end))
    
        AddUnload(function()
            Library:SetWatermarkVisibility(false)
            SetKeybindsVisible(false)
        end)
    end
    
    local WorldTab = Window:AddTab('World')
    local WorldAmbience = WorldTab:AddLeftGroupbox('Ambience')
    local WorldLighting = WorldTab:AddRightGroupbox('Lighting')
    local WorldCustomPlayer = WorldTab:AddLeftGroupbox('Custom Player')
    local WorldCameraFX = WorldTab:AddRightGroupbox('Camera effects')

    WorldAmbience:AddToggle('World_CustomTime', { Text = 'Custom time', Default = false })
    WorldAmbience:AddSlider('World_Time', {
        Text = 'Time',
        Default = 12,
        Min = 0,
        Max = 24,
        Rounding = 1,
    })
    WorldAmbience:AddToggle('World_SkyboxAmbient', {
        Text = 'Custom skybox',
        Default = false,
    }):AddColorPicker('World_SkyboxAmbientColor', {
        Default = Color3.fromRGB(0, 0, 0),
        Transparency = 0,
    })
    WorldAmbience:AddToggle('World_SkyColor', {
        Text = 'Sky color',
        Default = false,
    }):AddColorPicker('World_SkyColorValue', {
        Default = Color3.fromRGB(0, 0, 0),
        Transparency = 0,
    })
    WorldAmbience:AddToggle('World_NoShadows', { Text = 'No shadows', Default = false })
    WorldAmbience:AddToggle('World_SkyboxChanger', { Text = 'Skybox changer', Default = false })
    WorldAmbience:AddDropdown('World_SkyboxPreset', {
        Text = 'Skybox preset',
        Values = {
            "Game's Sky", 'Purple Nebula', 'Night Sky', 'Pink Daylight', 'Morning Glow',
            'Setting Sun', 'Fade Blue', 'Elegant Morning', 'Neptune', 'Redshift',
            'Aesthetic Night', 'Gloomy Gray', 'Light Within Dark', 'Green Space',
            'The Winter', 'Oblivion', 'Final Bloodmoon', 'Clouds', 'Twilight',
            'Red Mountain', 'Cloudy Skies', 'Dark Blue',
        },
        Default = "Game's Sky",
    })
    WorldAmbience:AddInput('World_SkyboxAsset', {
        Text = 'Custom asset ID',
        Default = '',
        Placeholder = 'e.g. 159454299',
    })

    WorldLighting:AddToggle('World_BetterShadows', { Text = 'Better shadows', Default = false })
    WorldLighting:AddToggle('World_Ambient', {
        Text = 'Ambient',
        Default = false,
    }):AddColorPicker('World_AmbientColor', {
        Default = Color3.fromRGB(128, 128, 128),
        Transparency = 0,
    })
    WorldLighting:AddSlider('World_Brightness', {
        Text = 'Brightness',
        Default = 2,
        Min = 0,
        Max = 10,
        Rounding = 1,
    })
    WorldLighting:AddToggle('World_Gradient', {
        Text = 'Gradient color 1',
        Default = false,
    }):AddColorPicker('World_GradientColor1', {
        Default = Color3.fromRGB(90, 90, 90),
        Transparency = 0,
    })
    WorldLighting:AddToggle('World_GradientColor2Enabled', {
        Text = 'Gradient color 2',
        Default = false,
    }):AddColorPicker('World_GradientColor2', {
        Default = Color3.fromRGB(150, 150, 150),
        Transparency = 0,
    })
    WorldLighting:AddToggle('World_Saturation', { Text = 'Saturation', Default = false })
    WorldLighting:AddSlider('World_SaturationValue', {
        Text = 'Saturation value',
        Default = 10,
        Min = 0,
        Max = 100,
        Rounding = 0,
    })
    WorldCustomPlayer:AddToggle('World_CustomPlayer_Enable', { Text = 'Enable', Default = false })
    WorldCustomPlayer:AddDropdown('World_CustomPlayer_Model', {
        Text = 'Model',
        Values = {
            'Normal', 'Puzati', 'Jhon Pork', 'Pigeon', 'Patrik',
            'Biggers_Gal', 'Among us', 'Skipper', 'Old Lester', 'Pibble', 'Big guy',
            'Skeleton', 'Fat guy 1',
        },
        Default = 'Normal',
    })
    WorldCustomPlayer:AddSlider('World_CustomPlayer_Scale', {
        Text = 'Scale',
        Default = 1.6,
        Min = 0.5,
        Max = 3,
        Rounding = 1,
    })
    WorldCameraFX:AddToggle('World_CameraBlur', { Text = 'Camera blur', Default = false })
    WorldCameraFX:AddSlider('World_CameraBlurIntensity', {
        Text = 'Blur intensity',
        Default = 100,
        Min = 0,
        Max = 100,
        Rounding = 0,
    })
    do
        local Lighting = game:GetService('Lighting')
        local SkyFaces = { 'SkyboxBk', 'SkyboxDn', 'SkyboxFt', 'SkyboxLf', 'SkyboxRt', 'SkyboxUp' }
        local SkyProperties = {
            'SkyboxBk', 'SkyboxDn', 'SkyboxFt', 'SkyboxLf', 'SkyboxRt', 'SkyboxUp',
            'StarCount', 'SunTextureId', 'MoonTextureId',
        }
        local SkyboxPresets = {
            ['Purple Nebula'] = { 159454299, 159454296, 159454293, 159454286, 159454300, 159454288 },
            ['Night Sky'] = { 12064107, 12064152, 12064121, 12063984, 12064115, 12064131 },
            ['Pink Daylight'] = { 271042516, 271077243, 271042556, 271042310, 271042467, 271077958 },
            ['Morning Glow'] = { 1417494030, 1417494146, 1417494253, 1417494402, 1417494499, 1417494643 },
            ['Setting Sun'] = { 626460377, 626460216, 626460513, 626473032, 626458639, 626460625 },
            ['Fade Blue'] = { 153695414, 153695352, 153695452, 153695320, 153695383, 153695471 },
            ['Elegant Morning'] = { 153767241, 153767216, 153767266, 153767200, 153767231, 153767288 },
            ['Neptune'] = { 218955819, 218953419, 218954524, 218958493, 218957134, 218950090 },
            ['Redshift'] = { 401664839, 401664862, 401664960, 401664881, 401664901, 401664936 },
            ['Aesthetic Night'] = { 1045964490, 1045964368, 1045964655, 1045964655, 1045964655, 1045962969 },
            ['Gloomy Gray'] = { 4495864450, 4495864887, 4495865458, 4495866035, 4495866584, 4495867486 },
            ['Light Within Dark'] = { 15502511288, 15502508460, 15502510289, 15502507918, 15502509398, 15502511911 },
            ['Green Space'] = { 16823270864, 16823272150, 16823273508, 16823274898, 16823276281, 16823277547 },
            ['The Winter'] = { 7307273436, 7307275898, 7307282434, 7307284944, 7307287254, 7307290025 },
            ['Oblivion'] = { 16642312709, 16642313526, 16642314757, 16642307918, 16642313526, 16642314708 },
            ['Final Bloodmoon'] = { 15493709538, 15493710499, 15493711616, 15493712720, 15493712397, 15493711792 },
            ['Clouds'] = { 570557514, 570557775, 570557559, 570557620, 570557672, 570557727 },
            ['Twilight'] = { 264908339, 264907909, 264909420, 264909758, 264908886, 264907379 },
            ['Red Mountain'] = { 6636457509, 6636457509, 6636457509, 6636457509, 6636457509, 6636457509 },
            ['Cloudy Skies'] = { 252760981, 252763035, 252761439, 252760980, 252762652, 252762652 },
            ['Dark Blue'] = { 30306692, 25901058, 30306730, 30306626, 30306665, 30306603 },
        }
        local State = {
            snapshot = nil,
            skies = {},
            saturation = nil,
            saturationSnapshot = nil,
            ownsSaturation = false,
            technology = nil,
            originalSky = nil,
            customSky = nil,
            skyboxGeneration = 0,
            cameraBlur = nil,
            lastCameraCFrame = nil,
            blurSize = 0,
        }

        local function Enabled(id)
            local toggle = Toggles[id]
            return toggle and toggle.Value == true
        end

        local function Value(id, fallback)
            local option = Options[id]
            return option and option.Value ~= nil and option.Value or fallback
        end

        local function Set(object, property, value)
            object[property] = value
        end

        local function CaptureSky(sky)
            if not sky or State.skies[sky] then
                return
            end
            local snapshot = {}
            for i = 1, #SkyProperties do
                local property = SkyProperties[i]
                snapshot[property] = sky[property]
            end
            State.skies[sky] = snapshot
        end

        local function CaptureWorld()
            if State.snapshot then
                return
            end
            State.snapshot = {
                ClockTime = Lighting.ClockTime,
                GlobalShadows = Lighting.GlobalShadows,
                Brightness = Lighting.Brightness,
                Ambient = Lighting.Ambient,
                OutdoorAmbient = Lighting.OutdoorAmbient,
                ColorShift_Bottom = Lighting.ColorShift_Bottom,
                ColorShift_Top = Lighting.ColorShift_Top,
                FogColor = Lighting.FogColor,
                FogEnd = Lighting.FogEnd,
            }
            CaptureSky(Lighting:FindFirstChildOfClass('Sky'))
        end

        local function RestoreWorld()
            local snapshot = State.snapshot
            if not snapshot then
                return
            end
            pcall(function()
                for property, value in pairs(snapshot) do
                    Lighting[property] = value
                end
                if State.technology ~= nil and type(sethiddenproperty) == 'function' then
                    sethiddenproperty(Lighting, 'Technology', State.technology)
                end
                for sky, values in pairs(State.skies) do
                    if sky and sky.Parent then
                        for property, value in pairs(values) do
                            sky[property] = value
                        end
                    end
                end
                if State.saturation and State.saturation.Parent then
                    if State.ownsSaturation then
                        State.saturation:Destroy()
                    elseif State.saturationSnapshot then
                        for property, value in pairs(State.saturationSnapshot) do
                            State.saturation[property] = value
                        end
                    end
                end
            end)
            State.snapshot, State.technology = nil, nil
            State.saturation, State.saturationSnapshot, State.ownsSaturation = nil, nil, false
            table.clear(State.skies)
        end

        local function SetSkyColor(sky, color)
            if not sky then
                return
            end
            local white = 'rbxasset://textures/white.png'
            for i = 1, #SkyFaces do
                Set(sky, SkyFaces[i], white)
            end
            Set(sky, 'StarCount', 0)
            Set(sky, 'SunTextureId', '')
            Set(sky, 'MoonTextureId', '')
            Set(Lighting, 'FogColor', color)
            Set(Lighting, 'FogEnd', 9e9)
        end

        local function WorldActive()
            return Enabled('World_CustomTime')
                or Enabled('World_SkyboxAmbient')
                or Enabled('World_SkyColor')
                or Enabled('World_NoShadows')
                or Enabled('World_BetterShadows')
                or Enabled('World_Ambient')
                or Enabled('World_Gradient')
                or Enabled('World_Saturation')
        end

        local function ApplyWorld()
            if not WorldActive() then
                RestoreWorld()
                return
            end
            CaptureWorld()
            local saved = State.snapshot
            local sky = Lighting:FindFirstChildOfClass('Sky')
            CaptureSky(sky)

            Set(Lighting, 'ClockTime', Enabled('World_CustomTime') and Value('World_Time', 12) or saved.ClockTime)
            local ambient, outdoor, bottom, top = saved.Ambient, saved.OutdoorAmbient, saved.ColorShift_Bottom, saved.ColorShift_Top
            if Enabled('World_Gradient') then
                ambient = Value('World_GradientColor1', Color3.fromRGB(90, 90, 90))
                outdoor = Value('World_GradientColor2', Color3.fromRGB(150, 150, 150))
            elseif Enabled('World_Ambient') then
                ambient = Value('World_AmbientColor', Color3.fromRGB(128, 128, 128))
            elseif Enabled('World_SkyboxAmbient') then
                ambient = Value('World_SkyboxAmbientColor', Color3.new())
                outdoor, bottom, top = ambient, ambient, ambient
            end
            Set(Lighting, 'Ambient', ambient)
            Set(Lighting, 'OutdoorAmbient', outdoor)
            Set(Lighting, 'ColorShift_Bottom', bottom)
            Set(Lighting, 'ColorShift_Top', top)

            if Enabled('World_SkyColor') then
                SetSkyColor(sky, Value('World_SkyColorValue', Color3.new()))
            else
                Set(Lighting, 'FogColor', saved.FogColor)
                Set(Lighting, 'FogEnd', saved.FogEnd)
            end
            Set(Lighting, 'GlobalShadows', Enabled('World_NoShadows') and false or saved.GlobalShadows)

            if Enabled('World_BetterShadows') and State.technology == nil and type(gethiddenproperty) == 'function' then
                pcall(function()
                    State.technology = gethiddenproperty(Lighting, 'Technology')
                end)
            end
            if Enabled('World_BetterShadows') and type(sethiddenproperty) == 'function' then
                pcall(function()
                    sethiddenproperty(Lighting, 'Technology', Enum.Technology.ShadowMap)
                end)
            end

            local brightnessOn = Enabled('World_Ambient') or Enabled('World_Gradient')
                or Enabled('World_BetterShadows') or Enabled('World_Saturation')
            Set(Lighting, 'Brightness', brightnessOn and Value('World_Brightness', 2) or saved.Brightness)

            if Enabled('World_Saturation') then
                if not State.saturation or not State.saturation.Parent then
                    local existing = Lighting:FindFirstChild('ValenokWorldSaturation')
                    State.saturation = existing or Instance.new('ColorCorrectionEffect')
                    State.ownsSaturation = not existing
                    State.saturation.Name = 'ValenokWorldSaturation'
                    if not State.ownsSaturation then
                        State.saturationSnapshot = {
                            Saturation = State.saturation.Saturation,
                            Enabled = State.saturation.Enabled,
                        }
                    end
                    State.saturation.Parent = Lighting
                end
                Set(State.saturation, 'Enabled', true)
                Set(State.saturation, 'Saturation', Value('World_SaturationValue', 10) / 50)
            elseif State.saturation then
                if State.ownsSaturation then
                    State.saturation:Destroy()
                elseif State.saturationSnapshot and State.saturation.Parent then
                    for property, value in pairs(State.saturationSnapshot) do
                        State.saturation[property] = value
                    end
                end
                State.saturation, State.saturationSnapshot, State.ownsSaturation = nil, nil, false
            end
        end

        local function UpdateCameraBlur(deltaTime)
            if not Enabled('World_CameraBlur') then
                if State.cameraBlur then
                    State.cameraBlur:Destroy()
                    State.cameraBlur = nil
                end
                State.lastCameraCFrame, State.blurSize = nil, 0
                return
            end

            local camera = workspace.CurrentCamera
            if not camera then return end
            if not State.cameraBlur or not State.cameraBlur.Parent then
                State.cameraBlur = Instance.new('BlurEffect')
                State.cameraBlur.Name = 'ValenokCameraBlur'
                State.cameraBlur.Parent = Lighting
            end

            local current, previous = camera.CFrame, State.lastCameraCFrame
            local target = 0
            if previous then
                local move = (current.Position - previous.Position).Magnitude
                local turn = math.acos(math.clamp(current.LookVector:Dot(previous.LookVector), -1, 1))
                local intensity = math.clamp(Value('World_CameraBlurIntensity', 50), 0, 100) / 100
                target = math.clamp((move * 260 + turn * 3000) * intensity, 0, 56)
            end
            State.lastCameraCFrame = current
            local blend = math.clamp((deltaTime or 1 / 60) * (target > State.blurSize and 40 or 16), 0, 1)
            State.blurSize = State.blurSize + (target - State.blurSize) * blend
            State.cameraBlur.Size = State.blurSize
        end

        local function RemoveCustomSky()
            if State.customSky then
                State.customSky:Destroy()
                State.customSky = nil
            end
        end

        local function RestoreSkybox()
            RemoveCustomSky()
            if State.originalSky and not State.originalSky.Parent then
                State.originalSky.Parent = Lighting
            end
            State.originalSky = nil
        end

        local function ApplySkyboxChanger()
            State.skyboxGeneration = State.skyboxGeneration + 1
            local generation = State.skyboxGeneration
            if not Enabled('World_SkyboxChanger') then
                RestoreSkybox()
                return
            end

            local currentSky = Lighting:FindFirstChildOfClass('Sky')
            if not State.originalSky and currentSky and currentSky ~= State.customSky then
                State.originalSky = currentSky
            end
            if currentSky and currentSky ~= State.customSky then
                currentSky.Parent = nil
            end
            RemoveCustomSky()

            local assetId = tostring(Value('World_SkyboxAsset', '')):match('%d+')
            if assetId then
                task.spawn(function()
                    local ok, objects = pcall(game.GetObjects, game, 'rbxassetid://' .. assetId)
                    if not ok or type(objects) ~= 'table' or generation ~= State.skyboxGeneration
                        or not Enabled('World_SkyboxChanger')
                    then
                        if type(objects) == 'table' then
                            for _, object in ipairs(objects) do
                                object:Destroy()
                            end
                        end
                        return
                    end
                    local object = objects and objects[1]
                    local sky = object and (object:IsA('Sky') and object or object:FindFirstChildOfClass('Sky'))
                    if sky then
                        State.customSky = sky:IsA('Sky') and (sky.Parent and sky:Clone() or sky) or nil
                        if State.customSky then
                            State.customSky.Name = 'ValenokWorldSky'
                            State.customSky.Parent = Lighting
                        end
                    end
                    if object and object ~= State.customSky then
                        object:Destroy()
                    end
                end)
                return
            end

            local faces = SkyboxPresets[Value('World_SkyboxPreset', "Game's Sky")]
            if not faces then
                if State.originalSky and not State.originalSky.Parent then
                    State.originalSky.Parent = Lighting
                end
                return
            end
            local sky = Instance.new('Sky')
            sky.Name, sky.StarCount, sky.SunTextureId, sky.MoonTextureId = 'ValenokWorldSky', 0, '', ''
            for i = 1, #SkyFaces do
                sky[SkyFaces[i]] = 'rbxassetid://' .. faces[i]
            end
            sky.Parent = Lighting
            State.customSky = sky
        end

        Library:GiveSignal(Lighting.ChildAdded:Connect(function(child)
            if child:IsA('Sky') and State.customSky and child ~= State.customSky then
                task.defer(function()
                    if State.customSky and State.customSky.Parent and child.Parent then
                        child.Parent = nil
                    end
                end)
            end
        end))

        local WorldControls = {
            'World_CustomTime', 'World_Time', 'World_SkyboxAmbient', 'World_SkyboxAmbientColor',
            'World_SkyColor', 'World_SkyColorValue', 'World_NoShadows', 'World_BetterShadows',
            'World_Ambient', 'World_AmbientColor', 'World_Brightness', 'World_Gradient',
            'World_GradientColor1', 'World_GradientColor2Enabled', 'World_GradientColor2',
            'World_Saturation', 'World_SaturationValue',
        }
        for i = 1, #WorldControls do
            local option = Toggles[WorldControls[i]] or Options[WorldControls[i]]
            if option then
                option:OnChanged(ApplyWorld)
            end
        end
        for _, id in ipairs({ 'World_SkyboxChanger', 'World_SkyboxPreset', 'World_SkyboxAsset' }) do
            local option = Toggles[id] or Options[id]
            if option then
                option:OnChanged(ApplySkyboxChanger)
            end
        end
        for _, id in ipairs({ 'World_CameraBlur', 'World_CameraBlurIntensity' }) do
            local option = Toggles[id] or Options[id]
            if option then option:OnChanged(function() UpdateCameraBlur() end) end
        end

        pcall(function()
            RunService:UnbindFromRenderStep('ValenokCameraBlur')
            RunService:BindToRenderStep('ValenokCameraBlur', Enum.RenderPriority.Camera.Value + 1, UpdateCameraBlur)
        end)
        local updateAccumulator = 0
        Library:GiveSignal(RunService.Heartbeat:Connect(function(deltaTime)
            updateAccumulator = updateAccumulator + math.min(deltaTime, 0.25)
            if updateAccumulator < 1 / 60 then
                return
            end
            updateAccumulator = updateAccumulator % (1 / 60)
            ApplyWorld()
        end))

        AddUnload(function()
            State.skyboxGeneration = State.skyboxGeneration + 1
            RestoreSkybox()
            RestoreWorld()
            if State.cameraBlur then State.cameraBlur:Destroy() end
            pcall(function() RunService:UnbindFromRenderStep('ValenokCameraBlur') end)
        end)
    end

    do
        local BodyModels = {
            Normal = {
                Torso = 135121131602727,
                LeftArm = 72804473226768,
                RightArm = 130351594552744,
                LeftLeg = 80105694195753,
                RightLeg = 116476819182032,
                Head = 118449923967495,
            },
            ['Jhon Pork'] = {
                Torso = 132501585490463,
                LeftArm = 88579015441753,
                RightArm = 129842318757424,
                LeftLeg = 100518704070331,
                RightLeg = 92476775553785,
                Head = 132721839382745,
            },
            Pigeon = {
                Torso = 108606139451045,
                LeftArm = 134006789505304,
                RightArm = 85828897541190,
                LeftLeg = 101883175743454,
                RightLeg = 75417153810267,
                Head = 127070584433499,
            },
            Patrik = {
                Torso = 121429497485946,
                LeftArm = 122232068641236,
                RightArm = 93214372185918,
                LeftLeg = 83875412970369,
                RightLeg = 97452562708405,
                Head = 137097755853616,
            },
            Biggers_Gal = {
                Torso = 74673279267276,
                LeftArm = 87018689087283,
                RightArm = 132244196035713,
                LeftLeg = 78760826287024,
                RightLeg = 90291349193488,
                Head = 93996073470815,
            },
            ['Among us'] = {
                Torso = 107534460257855,
                LeftArm = 77139673169857,
                RightArm = 102635380480202,
                LeftLeg = 115538462928796,
                RightLeg = 126976948352037,
                Head = 116779639423299,
            },
            Skipper = {
                Torso = 130680650819430,
                LeftArm = 81187641328514,
                RightArm = 89085745510917,
                LeftLeg = 121808135909788,
                RightLeg = 77179784244521,
                Head = 71903529157347,
            },
            ['Old Lester'] = {
                Torso = 80859767821450,
                LeftArm = 113667126099629,
                RightArm = 112687265686668,
                LeftLeg = 72818113233736,
                RightLeg = 104423736812413,
                Head = 77778446802448,
            },
            Pibble = {
                Torso = 90696558840318,
                LeftArm = 129050007743892,
                RightArm = 130571043270887,
                LeftLeg = 119969744556383,
                RightLeg = 90886442487050,
                Head = 93917690139663,
            },
            ['Big guy'] = {
                Torso = 97885715091333,
                LeftArm = 95372012633334,
                RightArm = 80393387074127,
                LeftLeg = 121169273294866,
                RightLeg = 124328247767549,
                Head = 83615494348795,
            },
            Skeleton = {
                Torso = 127308046551037,
                LeftArm = 90220814519470,
                RightArm = 118877569125424,
                LeftLeg = 135318822971898,
                RightLeg = 86639514084572,
                Head = 114932814714863,
            },
            ['Fat guy 1'] = {
                Torso = 133205357743878,
                LeftArm = 112483999219995,
                RightArm = 92347775435494,
                LeftLeg = 103791733575787,
                RightLeg = 98800327125866,
                Head = 132588947314373,
            },
        }
        local State = {
            fake = nil,
            hidden = {},
            generation = 0,
            hideConnection = nil,
            hideRender = nil,
            visualParts = {},
        }

        local function ClearCustomPlayer()
            if State.hideConnection then
                State.hideConnection:Disconnect()
                State.hideConnection = nil
            end
            if State.hideRender then
                State.hideRender:Disconnect()
                State.hideRender = nil
            end
            if State.fake then
                State.fake:Destroy()
                State.fake = nil
            end
            for part, transparency in pairs(State.hidden) do
                if part and part.Parent then part.LocalTransparencyModifier = transparency end
            end
            table.clear(State.hidden)
            table.clear(State.visualParts)
        end

        local function HideOriginal(part)
            if part:IsA('BasePart') then
                if State.hidden[part] == nil then
                    State.hidden[part] = part.LocalTransparencyModifier
                end
                part.LocalTransparencyModifier = 1
            end
        end

        local function UprightRoot(root)
            local forward = root.CFrame.LookVector
            forward = Vector3.new(forward.X, 0, forward.Z)
            if forward.Magnitude < 1e-3 then
                local right = root.CFrame.RightVector
                forward = Vector3.yAxis:Cross(Vector3.new(right.X, 0, right.Z))
            end
            if forward.Magnitude < 1e-3 then forward = Vector3.new(0, 0, -1) end
            return CFrame.lookAt(root.Position, root.Position + forward.Unit)
        end

        local function HideCharacter(character)
            for _, part in ipairs(character:GetDescendants()) do
                if part:IsA('BasePart') and not (State.fake and part:IsDescendantOf(State.fake)) then
                    HideOriginal(part)
                end
            end
            State.hideConnection = character.DescendantAdded:Connect(function(part)
                if part:IsA('BasePart') and not (State.fake and part:IsDescendantOf(State.fake)) then
                    HideOriginal(part)
                end
            end)
            State.hideRender = RunService.RenderStepped:Connect(function()
                if not Toggles.World_CustomPlayer_Enable.Value or character ~= LocalPlayer.Character then
                    return
                end
                for part, data in pairs(State.visualParts) do
                    if part.Parent and data.target and data.target.Parent then
                        part.CFrame = data.target.CFrame
                    elseif part.Parent and data.root and data.root.Parent then
                        part.CFrame = UprightRoot(data.root) * data.offset
                    else
                        State.visualParts[part] = nil
                    end
                end
                for _, part in ipairs(character:GetDescendants()) do
                    if part:IsA('BasePart') and not (State.fake and part:IsDescendantOf(State.fake)) then
                        HideOriginal(part)
                    end
                end
            end)
        end

        local function ApplyCustomPlayer()
            State.generation = State.generation + 1
            local generation = State.generation
            ClearCustomPlayer()
            if not Toggles.World_CustomPlayer_Enable.Value then return end

            local character = LocalPlayer.Character
            local humanoid = character and character:FindFirstChildOfClass('Humanoid')
            if not character or not humanoid or humanoid.RigType ~= Enum.HumanoidRigType.R15 then return end
            HideCharacter(character)

            task.spawn(function()
                local scale = Options.World_CustomPlayer_Scale.Value
                local selectedModel = Options.World_CustomPlayer_Model.Value
                if selectedModel == 'Puzati' then
                    local ok, objects = pcall(game.GetObjects, game, 'rbxassetid://104619471286143')
                    local source = type(objects) == 'table' and objects[1] or nil
                    local visual = typeof(source) == 'Instance' and (
                        source:IsA('BasePart') and source
                        or source:FindFirstChildWhichIsA('BasePart', true)
                    )
                    if not ok or not visual or generation ~= State.generation then
                        if type(objects) == 'table' then
                            for _, object in ipairs(objects) do object:Destroy() end
                        end
                        if generation == State.generation then warn('Puzati model failed to load') end
                        return
                    end

                    local torso = character:FindFirstChild('UpperTorso')
                    local root = character:FindFirstChild('HumanoidRootPart')
                    local fake = Instance.new('Model')
                    fake.Name = 'ValenokPuzati'
                    local belly = visual:Clone()
                    for _, object in ipairs(objects) do object:Destroy() end
                    if not torso or not root or generation ~= State.generation then
                        fake:Destroy()
                        return
                    end

                    State.fake = fake
                    fake.Parent = character
                    belly.Name = 'PuzatiBelly'
                    local uprightRoot = UprightRoot(root)
                    local torsoOffset = uprightRoot:ToObjectSpace(torso.CFrame)
                    local bellyOffset = CFrame.new(torsoOffset.Position)
                        * CFrame.new(0, -0.15, -0.7)
                    belly.CFrame = uprightRoot * bellyOffset
                    belly.Size = belly.Size * scale
                    belly.Anchored, belly.CanCollide, belly.CanTouch, belly.CanQuery, belly.Massless = true, false, false, false, true
                    local mesh = belly:FindFirstChildOfClass('SpecialMesh')
                    if mesh then mesh.Scale = mesh.Scale * scale end
                    belly.Parent = fake
                    State.visualParts[belly] = { root = root, offset = bellyOffset }
                    return
                end

                local description = Instance.new('HumanoidDescription')
                for property, assetId in pairs(BodyModels[selectedModel] or BodyModels.Normal) do
                    description[property] = assetId
                end
                local ok, fake = pcall(
                    PlayersService.CreateHumanoidModelFromDescription,
                    PlayersService,
                    description,
                    Enum.HumanoidRigType.R15
                )
                description:Destroy()
                if not ok or typeof(fake) ~= 'Instance'
                    or generation ~= State.generation or character ~= LocalPlayer.Character
                then
                    if typeof(fake) == 'Instance' then fake:Destroy() end
                    return
                end

                fake.Name = 'Valenok' .. selectedModel:gsub('%s+', '')
                local fakeHumanoid = fake:FindFirstChildOfClass('Humanoid')
                if fakeHumanoid then fakeHumanoid:Destroy() end
                for _, item in ipairs(fake:GetDescendants()) do
                    if item:IsA('Motor6D') or item:IsA('Script') or item:IsA('LocalScript') then
                        item:Destroy()
                    end
                end

                State.fake = fake
                fake.Parent = character
                local root = character:FindFirstChild('HumanoidRootPart')
                if not root then
                    fake:Destroy()
                    return
                end
                local uprightRoot = UprightRoot(root)
                for _, part in ipairs(fake:GetDescendants()) do
                    if part:IsA('BasePart') then
                        local target = character:FindFirstChild(part.Name)
                        if target and target:IsA('BasePart') and part.Name ~= 'HumanoidRootPart' then
                            -- The real limbs animate independently.  Keep the visual rig in
                            -- one neutral pose, attached only to the upright root part.
                            -- Scale only the mesh size.  Scaling offsets can put a visual body
                            -- beneath the floor when the root is close to the ground.
                            local offset = CFrame.new(uprightRoot:ToObjectSpace(target.CFrame).Position)
                            part.CFrame = part.Name == 'Head' and target.CFrame or uprightRoot * offset
                            part.Size = part.Size * scale
                            part.Anchored, part.CanCollide, part.CanTouch, part.CanQuery, part.Massless = true, false, false, false, true
                            local mesh = part:FindFirstChildOfClass('SpecialMesh')
                            if mesh then mesh.Scale = mesh.Scale * scale end
                            State.visualParts[part] = part.Name == 'Head'
                                and { target = target }
                                or { root = root, offset = offset }
                        else
                            part:Destroy()
                        end
                    end
                end

                if generation ~= State.generation or not Toggles.World_CustomPlayer_Enable.Value then
                    fake:Destroy()
                    return
                end
            end)
        end

        Toggles.World_CustomPlayer_Enable:OnChanged(ApplyCustomPlayer)
        Options.World_CustomPlayer_Scale:OnChanged(function()
            if Toggles.World_CustomPlayer_Enable.Value then ApplyCustomPlayer() end
        end)
        Options.World_CustomPlayer_Model:OnChanged(function()
            if Toggles.World_CustomPlayer_Enable.Value then ApplyCustomPlayer() end
        end)
        Library:GiveSignal(LocalPlayer.CharacterAdded:Connect(function()
            if Toggles.World_CustomPlayer_Enable.Value then
                task.delay(1, ApplyCustomPlayer)
            end
        end))
        AddUnload(ClearCustomPlayer)
    end

    local MovementTab = Window:AddTab('Movement')
    local Bhop = MovementTab:AddLeftGroupbox('Bhop')
    local SpeedHack = MovementTab:AddLeftGroupbox('SpeedHack')
    local MovementMisc = MovementTab:AddRightGroupbox('Misc')
    
    Bhop:AddToggle('Bhop_Enable', { Text = 'Enable', Default = false })
    Bhop:AddSlider('Bhop_Multiplier', {
        Text = 'Multiplier',
        Default = 1,
        Min = 1,
        Max = 10,
        Rounding = 2,
    })
    
    SpeedHack:AddToggle('SpeedHack_Enable', { Text = 'Enable', Default = false })
    SpeedHack:AddSlider('SpeedHack_Multiplier', {
        Text = 'Multiplier',
        Default = 1,
        Min = 1,
        Max = 10,
        Rounding = 2,
    })
    
    MovementMisc:AddToggle('Movement_AutoJump', { Text = 'Auto Jump', Default = false })
    MovementMisc:AddToggle('Movement_FakeDuck', { Text = 'FakeDuck', Default = false })
        :AddKeyPicker('Movement_FakeDuck_Key', {
            Default = 'V',
            Mode = 'Hold',
            Text = 'FakeDuck',
        })
    MovementMisc:AddToggle('Movement_Fly', { Text = 'Fly', Default = false })
    MovementMisc:AddSlider('Movement_FlySpeed', {
        Text = 'Fly speed',
        Default = 1,
        Min = 1,
        Max = 10,
        Rounding = 2,
    })
    MovementMisc:AddToggle('Movement_NoClip', { Text = 'NoClip', Default = false })
    
    local function SnapMovementSlider(option)
        option:OnChanged(function(value)
            local snapped = math.clamp(math.floor(value * 20 + 0.5) / 20, 1, 10)
            if math.abs(snapped - value) > 0.0001 then
                option:SetValue(snapped)
            end
        end)
    end
    
    SnapMovementSlider(Options.Bhop_Multiplier)
    SnapMovementSlider(Options.SpeedHack_Multiplier)
    SnapMovementSlider(Options.Movement_FlySpeed)
    
    do
        local DEFAULT_SPEED = 16
        local MoveConnection
        local SpeedHumanoid, SavedSpeed
        local FlyHumanoid
        local NoClipCharacter, NoClipConnection
        local NoClipSaved = {}
        local FakeDuckTrack, FakeDuckHumanoid
    
        local function GetRig()
            local character = LocalPlayer.Character
            local root = character and character:FindFirstChild('HumanoidRootPart')
            local humanoid = character and character:FindFirstChildOfClass('Humanoid')
            if not root or not humanoid or humanoid.Health <= 0 then return end
            return character, humanoid, root
        end
    
        local function CameraDirection(camera)
            local forward = (UserInputService:IsKeyDown(Enum.KeyCode.W) and 1 or 0)
                - (UserInputService:IsKeyDown(Enum.KeyCode.S) and 1 or 0)
            local strafe = (UserInputService:IsKeyDown(Enum.KeyCode.D) and 1 or 0)
                - (UserInputService:IsKeyDown(Enum.KeyCode.A) and 1 or 0)
            if forward == 0 and strafe == 0 then return end
    
            local look, right = camera.CFrame.LookVector, camera.CFrame.RightVector
            local direction = Vector3.new(
                look.X * forward + right.X * strafe,
                0,
                look.Z * forward + right.Z * strafe
            )
            local magnitude = direction.Magnitude
            return magnitude > 0.01 and direction / magnitude
        end
    
        local function CameraMove(root, camera, speed, deltaTime)
            local direction = CameraDirection(camera)
            if direction then
                root.CFrame = root.CFrame + direction * speed * deltaTime
            end
        end
    
        local function RestoreSpeed()
            if SpeedHumanoid and SpeedHumanoid.Parent and SavedSpeed then
                SpeedHumanoid.WalkSpeed = SavedSpeed
            end
            SpeedHumanoid, SavedSpeed = nil, nil
        end
    
        local function SetNoClipPart(part)
            if not part:IsA('BasePart') then return end
            if NoClipSaved[part] == nil then NoClipSaved[part] = part.CanCollide end
            part.CanCollide = false
        end
    
        local function RestoreNoClip()
            for part, canCollide in pairs(NoClipSaved) do
                if part.Parent then part.CanCollide = canCollide end
            end
            table.clear(NoClipSaved)
            NoClipCharacter = nil
        end
    
        local function UpdateNoClip(character)
            if not Toggles.Movement_NoClip.Value then
                if NoClipConnection then NoClipConnection:Disconnect(); NoClipConnection = nil end
                if NoClipCharacter then RestoreNoClip() end
                return
            end
            if NoClipCharacter == character then return end
    
            if NoClipConnection then NoClipConnection:Disconnect() end
            RestoreNoClip()
            NoClipCharacter = character
            for _, item in ipairs(character:GetDescendants()) do SetNoClipPart(item) end
            NoClipConnection = character.DescendantAdded:Connect(function(item)
                if Toggles.Movement_NoClip.Value then SetNoClipPart(item) end
            end)
        end
    
        local function UpdateFly(root, humanoid, deltaTime)
            if not Toggles.Movement_Fly.Value then
                if FlyHumanoid and FlyHumanoid.Parent and FlyHumanoid.PlatformStand then
                    FlyHumanoid.PlatformStand = false
                end
                FlyHumanoid = nil
                return false
            end
    
            humanoid.PlatformStand = true
            FlyHumanoid = humanoid
            local camera = workspace.CurrentCamera
            if not camera then return true end
    
            local direction = CameraDirection(camera)
            local vertical = (UserInputService:IsKeyDown(Enum.KeyCode.Space) and 1 or 0)
                - ((UserInputService:IsKeyDown(Enum.KeyCode.LeftShift)
                    or UserInputService:IsKeyDown(Enum.KeyCode.LeftControl)) and 1 or 0)
            if direction or vertical ~= 0 then
                local move = direction or Vector3.zero
                move = Vector3.new(move.X, vertical, move.Z)
                move = move.Unit
                root.CFrame = root.CFrame + move * DEFAULT_SPEED * Options.Movement_FlySpeed.Value * deltaTime
            end
            root.AssemblyLinearVelocity = Vector3.zero
            return true
        end

        local function StopFakeDuck()
            if FakeDuckTrack then pcall(function() FakeDuckTrack:Stop() end) end
            FakeDuckTrack, FakeDuckHumanoid = nil, nil
        end

        local function UpdateFakeDuck(humanoid)
            if not Toggles.Movement_FakeDuck.Value or not Options.Movement_FakeDuck_Key:GetState() or not humanoid then
                StopFakeDuck()
                return
            end
            if FakeDuckTrack and FakeDuckHumanoid == humanoid then
                if not FakeDuckTrack.IsPlaying then pcall(function() FakeDuckTrack:Play() end) end
                return
            end
            StopFakeDuck()
            local gui = LocalPlayer:FindFirstChild('PlayerGui')
            local client = gui and gui:FindFirstChild('Client')
            local idle = client and client:FindFirstChild('Idle')
            if not idle or not idle:IsA('Animation') then return end
            local ok, track = pcall(function() return humanoid:LoadAnimation(idle) end)
            if ok and track then
                FakeDuckTrack, FakeDuckHumanoid = track, humanoid
                pcall(function() track:Play() end)
            end
        end

        Toggles.Movement_FakeDuck:OnChanged(function()
            if not Toggles.Movement_FakeDuck.Value then StopFakeDuck() end
        end)

        MoveConnection = RunService.Heartbeat:Connect(function(deltaTime)
            local movementEnabled = Toggles.Bhop_Enable.Value
                or Toggles.SpeedHack_Enable.Value
                or Toggles.Movement_AutoJump.Value
                or Toggles.Movement_FakeDuck.Value
                or Toggles.Movement_Fly.Value
                or Toggles.Movement_NoClip.Value
            if not movementEnabled then
                StopFakeDuck()
                if FlyHumanoid and FlyHumanoid.Parent then FlyHumanoid.PlatformStand = false end
                FlyHumanoid = nil
                if SpeedHumanoid then RestoreSpeed() end
                if NoClipConnection then NoClipConnection:Disconnect(); NoClipConnection = nil end
                if NoClipCharacter then RestoreNoClip() end
                return
            end
            local character, humanoid, root = GetRig()
            if not character then StopFakeDuck(); return end
            UpdateNoClip(character)
            UpdateFakeDuck(humanoid)
    
            local spaceHeld = UserInputService:IsKeyDown(Enum.KeyCode.Space)
            local bhopActive = Toggles.Bhop_Enable.Value and spaceHeld
            local flyActive = UpdateFly(root, humanoid, deltaTime)
    
            if Toggles.Bhop_Enable.Value then
                local multiplier = Options.Bhop_Multiplier.Value
                if not spaceHeld then
                    if not flyActive and not Toggles.SpeedHack_Enable.Value then humanoid.WalkSpeed = DEFAULT_SPEED end
                elseif not flyActive and not Toggles.SpeedHack_Enable.Value then
                    humanoid.WalkSpeed = DEFAULT_SPEED * multiplier
                    if humanoid.FloorMaterial ~= Enum.Material.Air then humanoid.Jump = true end
                    if multiplier > 1 then
                        local camera = workspace.CurrentCamera
                        if camera then CameraMove(root, camera, DEFAULT_SPEED * (multiplier - 1), deltaTime) end
                    end
                end
            end
    
            if Toggles.SpeedHack_Enable.Value and not flyActive and not bhopActive then
                if SpeedHumanoid ~= humanoid then
                    RestoreSpeed()
                    SpeedHumanoid, SavedSpeed = humanoid, humanoid.WalkSpeed
                end
                local targetSpeed = DEFAULT_SPEED * Options.SpeedHack_Multiplier.Value
                humanoid.WalkSpeed = targetSpeed
                if targetSpeed > DEFAULT_SPEED then
                    local camera = workspace.CurrentCamera
                    if camera then CameraMove(root, camera, targetSpeed - DEFAULT_SPEED, deltaTime) end
                end
            elseif not Toggles.SpeedHack_Enable.Value then
                RestoreSpeed()
            end
    
            if Toggles.Movement_AutoJump.Value and spaceHeld and not bhopActive
                and humanoid.FloorMaterial ~= Enum.Material.Air then
                humanoid.Jump = true
            end
        end)
    
        AddUnload(function()
            if MoveConnection then MoveConnection:Disconnect() end
            RestoreSpeed()
            StopFakeDuck()
            if NoClipConnection then NoClipConnection:Disconnect() end
            RestoreNoClip()
            local _, humanoid = GetRig()
            if humanoid then humanoid.PlatformStand, humanoid.WalkSpeed = false, DEFAULT_SPEED end
        end)
    end
    
    local ConfigTab = Window:AddTab('Config')
    local ThemeManager = Library.ThemeManager
    local SaveManager = Library.SaveManager
    
    ThemeManager:SetLibrary(Library)
    SaveManager:SetLibrary(Library)
    SaveManager:IgnoreThemeSettings()
    SaveManager:SetIgnoreIndexes({
        'MenuKeybind', 'Skin_Knife_Skin', 'Skin_Weapon_Skin', 'Skin_Glove_Skin',
    })
    
    local CONFIG_FOLDER = 'ValenokRecode'
    if not isfolder(CONFIG_FOLDER) then
        makefolder(CONFIG_FOLDER)
    end
    
    ThemeManager:SetFolder(CONFIG_FOLDER)
    SaveManager:SetFolder(CONFIG_FOLDER)

    do
        local HttpService = game:GetService('HttpService')
        local OriginalSave, OriginalLoad = SaveManager.Save, SaveManager.Load
        SaveManager.Save = function(self, name, ...)
            local success, err = OriginalSave(self, name, ...)
            if not success then return false, err end
            pcall(function()
                local path = self.Folder .. '/settings/' .. name .. '.json'
                if not isfile(path) then return end
                local data = HttpService:JSONDecode(readfile(path))
                data.skinChanger = SkinChanger.ExportConfig()
                writefile(path, HttpService:JSONEncode(data))
            end)
            return true
        end
        SaveManager.Load = function(self, name, ...)
            local success, err = OriginalLoad(self, name, ...)
            if not success then return false, err end
            pcall(function()
                local path = self.Folder .. '/settings/' .. name .. '.json'
                if not isfile(path) then return end
                local data = HttpService:JSONDecode(readfile(path))
                SkinChanger.ImportConfig(data.skinChanger)
                task.delay(0.1, SkinChanger.RefreshConfig)
            end)
            return true
        end
    end
    
    -- Menu сверху слева
    local MenuGroup = ConfigTab:AddLeftGroupbox('Menu')
    
    MenuGroup:AddLabel('Menu Key'):AddKeyPicker('MenuKeybind', {
        Default = 'End',
        NoUI = true,
        Text = 'Menu Key',
    })
    
    MenuGroup:AddSlider('Update_Rate', {
        Text = 'Update Rate',
        Default = 200,
        Min = 1,
        Max = 600,
        Rounding = 0,
        Suffix = 'Hz',
    })
    Options.Update_Rate:OnChanged(SetUpdateRate)
    SetUpdateRate(Options.Update_Rate.Value)
    
    MenuGroup:AddButton('Unload', function()
        Library:Unload()
    end)
    
    Library.ToggleKeybind = Options.MenuKeybind
    
    -- Themes слева под Menu
    ThemeManager:ApplyToGroupbox(ConfigTab:AddLeftGroupbox('Themes'))
    
    -- Config справа
    SaveManager:BuildConfigSection(ConfigTab)
    SaveManager:LoadAutoloadConfig()
    
