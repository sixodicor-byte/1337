
            local Library = loadstring(game:HttpGet('https://raw.githubusercontent.com/sixodicor-byte/1337/refs/heads/main/NewLib.lua'))()
            local Toggles = getgenv().Toggles
            local Options = getgenv().Options
        
            local function ToggleEnabled(name)
                local toggle = Toggles and Toggles[name]
                return toggle and toggle.Value == true
            end
        
            local function OptionValue(name, default)
                local option = Options and Options[name]
                if option == nil then
                    return default
                end
                return option.Value
            end
            
            local PlayersService = game:GetService('Players')
            local RunService = game:GetService('RunService')
            local UserInputService = game:GetService('UserInputService')
            local ReplicatedStorage = game:GetService('ReplicatedStorage')
            local DebrisService = game:GetService('Debris')
            local SoundService = game:GetService('SoundService')
            local FrameScheduler = {
                heartbeat = {},
                render = {},
            }
            local function AddFrameTask(bucket, callback)
                local entry = { callback = callback }
                bucket[#bucket + 1] = entry
                local connection = { Connected = true }
                function connection:Disconnect()
                    if not self.Connected then
                        return
                    end
                    self.Connected = false
                    entry.callback = nil
                end
                return connection
            end
            local function RunFrameTasks(bucket, ...)
                for i = 1, #bucket do
                    local callback = bucket[i].callback
                    if callback then
                        callback(...)
                    end
                end
            end
            local HeartbeatDispatcher = RunService.Heartbeat:Connect(function(deltaTime)
                RunFrameTasks(FrameScheduler.heartbeat, deltaTime)
            end)
            local RenderDispatcher = RunService.RenderStepped:Connect(function(deltaTime)
                RunFrameTasks(FrameScheduler.render, deltaTime)
            end)
            Library:GiveSignal(HeartbeatDispatcher)
            Library:GiveSignal(RenderDispatcher)
        local LocalPlayer = PlayersService.LocalPlayer
        local HandleHitParl
        local HandleKillEffect
        local HandleBulletTracer
        local HandleRageHitParl
        local HandleLegitSilentRaycast
        local GetLegitSilentTarget
        local HandleInfAmmoNamecall
            local PlayHitSound
            local HitLogCleanup
            local HitLogControlsReady
            local KillEffectCleanup
            local NamecallCleanup
            local SharedNamecallState
            local ScriptEnvironment
            local GameRefs = {
                CurrentCamera = workspace.CurrentCamera,
                Events = nil,
                Weapons = nil,
                Debris = nil,
                RayIgnore = nil,
                Map = nil,
                MapClips = nil,
                MapSpawnPoints = nil,
            }
            local GameModules = setmetatable({}, { __mode = 'k' })
            local ClientEnvState = {
                playerGui = nil,
                client = nil,
                env = nil,
                resolved = false,
                guiAdded = nil,
                guiRemoved = nil,
            }

            local function SafeRequire(path)
                if not path then
                    return nil
                end
                local cached = GameModules[path]
                if cached ~= nil then
                    return cached.value
                end
                local ok, value = pcall(require, path)
                cached = { value = ok and value or nil }
                GameModules[path] = cached
                return cached.value
            end

            local function SetClientScript(client)
                if ClientEnvState.client == client then
                    return
                end
                ClientEnvState.client = client
                ClientEnvState.env = nil
                ClientEnvState.resolved = false
            end

            local function BindClientGui(playerGui)
                if ClientEnvState.playerGui == playerGui then
                    return
                end
                if ClientEnvState.guiAdded then
                    ClientEnvState.guiAdded:Disconnect()
                    ClientEnvState.guiAdded = nil
                end
                if ClientEnvState.guiRemoved then
                    ClientEnvState.guiRemoved:Disconnect()
                    ClientEnvState.guiRemoved = nil
                end
                ClientEnvState.playerGui = playerGui
                SetClientScript(playerGui and playerGui:FindFirstChild('Client'))
                if not playerGui then
                    return
                end
                ClientEnvState.guiAdded = playerGui.ChildAdded:Connect(function(child)
                    if child.Name == 'Client' then
                        SetClientScript(child)
                    end
                end)
                ClientEnvState.guiRemoved = playerGui.ChildRemoved:Connect(function(child)
                    if child == ClientEnvState.client then
                        SetClientScript(nil)
                    end
                end)
                Library:GiveSignal(ClientEnvState.guiAdded)
                Library:GiveSignal(ClientEnvState.guiRemoved)
            end

            local function GetClientEnv()
                BindClientGui(LocalPlayer.PlayerGui)
                if ClientEnvState.resolved then
                    return ClientEnvState.env
                end
                ClientEnvState.resolved = true
                local client = ClientEnvState.client
                if client and type(getsenv) == 'function' then
                    local ok, env = pcall(getsenv, client)
                    ClientEnvState.env = ok and env or nil
                end
                return ClientEnvState.env
            end

            Library:GiveSignal(workspace:GetPropertyChangedSignal('CurrentCamera'):Connect(function()
                GameRefs.CurrentCamera = workspace.CurrentCamera
            end))

            Library:GiveSignal(workspace.ChildRemoved:Connect(function(child)
                if child == GameRefs.Map then
                    GameRefs.Map = nil
                    GameRefs.MapClips = nil
                    GameRefs.MapSpawnPoints = nil
                elseif child == GameRefs.RayIgnore then
                    GameRefs.RayIgnore = nil
                elseif child == GameRefs.Debris then
                    GameRefs.Debris = nil
                end
            end))

            Library:GiveSignal(ReplicatedStorage.ChildRemoved:Connect(function(child)
                if child == GameRefs.Events then
                    GameRefs.Events = nil
                elseif child == GameRefs.Weapons then
                    GameRefs.Weapons = nil
                end
            end))

            local function GetCurrentCamera()
                return GameRefs.CurrentCamera
            end

            local function GetCachedPlayerParts(player, cache)
                local character = player.Character
                local cached = cache[player]
                if not cached then
                    cached = {}
                    cache[player] = cached
                end
                if cached.character ~= character then
                    cached.character = character
                    cached.root = character and character:FindFirstChild('HumanoidRootPart')
                    cached.humanoid = character and character:FindFirstChildOfClass('Humanoid')
                elseif character then
                    if not cached.root or cached.root.Parent ~= character then
                        cached.root = character:FindFirstChild('HumanoidRootPart')
                    end
                    if not cached.humanoid or cached.humanoid.Parent ~= character then
                        cached.humanoid = character:FindFirstChildOfClass('Humanoid')
                    end
                end
                return character, cached.root, cached.humanoid
            end

            local function GetOnceRef(key, finder)
                local cached = GameRefs[key]
                if cached ~= nil then
                    if typeof(cached) == 'Instance' and cached.Parent then
                        return cached
                    end
                    GameRefs[key] = nil
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
                    if typeof(cached) == 'Instance' and cached.Parent then
                        return cached
                    end
                    GameRefs.MapClips = nil
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
                    if typeof(cached) == 'Instance' and cached.Parent then
                        return cached
                    end
                    GameRefs.MapSpawnPoints = nil
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
                local connections = setmetatable({}, { __mode = 'k' })
                ScriptEnvironment.__ValenokRageCharacterCleanup = function(character)
                    local partCache = ScriptEnvironment.__ValenokRagePartCache
                    local ignoreCache = ScriptEnvironment.__ValenokRageIgnorePartsCache
                    if partCache then partCache[character] = nil end
                    if ignoreCache then ignoreCache[character] = nil end
                end
                ScriptEnvironment.__ValenokRageRemoveCharacterConnection = function(player)
                    local connection = connections[player]
                    if connection then
                        connection:Disconnect()
                        connections[player] = nil
                    end
                end
                ScriptEnvironment.__ValenokRageBindCharacterConnection = function(player)
                    if not player then
                        return
                    end
                    ScriptEnvironment.__ValenokRageRemoveCharacterConnection(player)
                    connections[player] = player.CharacterRemoving:Connect(function(character)
                        local cleanup = ScriptEnvironment.__ValenokRageCharacterCleanup
                        if cleanup then
                            cleanup(character)
                        end
                    end)
                end
                ScriptEnvironment.__ValenokRageClearCharacterConnections = function()
                    for _, connection in pairs(connections) do
                        connection:Disconnect()
                    end
                    table.clear(connections)
                end
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
            GetTrueName = SafeRequire(ReplicatedStorage:FindFirstChild('GetTrueName'))
            
            local Window = Library:CreateWindow({
                Title = 'ValenokRecode',
                Center = true,
                AutoShow = true,
            })
            local RageTab = Window:AddTab('Rage')
            local LegitTab = Window:AddTab('Legit')
            
            local VisualTab = Window:AddTab('Visual')
        local WorldTab = Window:AddTab('World')
        local SkinTab = Window:AddTab('Skin')
        local SkinCleanup
        local SkinChanger = {}
        do
            local Viewmodels = ReplicatedStorage:FindFirstChild('Viewmodels')
            local Skins = ReplicatedStorage:FindFirstChild('Skins')
            local Gloves = ReplicatedStorage:FindFirstChild('Gloves')
            local GloveModels = Gloves and Gloves:FindFirstChild('Models')
            local ExtraModels
            pcall(function()
                local objects = game:GetObjects('rbxassetid://7285197035')
                ExtraModels = objects[1]
                for i = 2, #objects do
                    objects[i]:Destroy()
                end
                table.clear(objects)
            end)
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
                armsApplyGeneration = 0, pendingArms = nil,
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
            local function DestroyLoadedObjects(objects, keep)
                if type(objects) ~= 'table' then
                    return
                end
                for i = 1, #objects do
                    local object = objects[i]
                    if typeof(object) == 'Instance' and object ~= keep then
                        local keepObject = typeof(keep) == 'Instance'
                        if not keepObject
                            or (not object:IsDescendantOf(keep) and not keep:IsDescendantOf(object))
                        then
                            pcall(function()
                                object:Destroy()
                            end)
                        end
                    end
                end
                table.clear(objects)
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
                        DestroyLoadedObjects(objects)
                        if generation == State.customWeaponGeneration[weapon] then State.customWeaponLoading[weapon] = nil end
                        return
                    end
                    local current = Viewmodels:FindFirstChild('v_' .. weapon)
                    if current then current:Destroy() end
                    model.Name, model.Parent = 'v_' .. weapon, Viewmodels
                    DestroyLoadedObjects(objects, model)
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
                            if model then model:Destroy() end
                            DestroyLoadedObjects(objects)
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
                        DestroyLoadedObjects(objects)
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
                if not arms or not arms.Parent then return end
                local armModel
                for _, model in ipairs(arms:GetChildren()) do
                    if model:IsA('Model') and (model:FindFirstChild('Right Arm') or model:FindFirstChild('Left Arm')) then armModel = model break end
                end
                if not armModel then return end
                if not enabled or not enabled.Value or not GloveModels or not gloveOption or not skinOption then
                    for _, armName in ipairs({ 'Right Arm', 'Left Arm' }) do
                        local arm = armModel:FindFirstChild(armName)
                        local old = arm and (arm:FindFirstChild('Glove') or arm:FindFirstChild('RGlove') or arm:FindFirstChild('LGlove'))
                        if old and old.Name == 'Glove' then old:Destroy() end
                    end
                    return
                end
                local glove, skin = gloveOption.Value, skinOption.Value
                local models = glove and GloveModels:FindFirstChild(glove)
                local textureData = glove and Gloves:FindFirstChild(glove) and Gloves[glove]:FindFirstChild(skin)
                local textures = textureData and textureData:FindFirstChild('Textures')
                local textureObject = textures and (textures:FindFirstChild('TextureId') or textures:FindFirstChildWhichIsA('StringValue'))
                local texture = textureObject and textureObject:IsA('StringValue') and textureObject.Value or nil
                if not models or not UsefulTexture(texture) then return end
                for _, data in ipairs({ { 'Right Arm', 'RGlove' }, { 'Left Arm', 'LGlove' } }) do
                    local arm, old, source = armModel:FindFirstChild(data[1]), nil, models:FindFirstChild(data[2])
                    if arm and source then
                        old = arm:FindFirstChild('Glove') or arm:FindFirstChild(data[2])
                        if old then old:Destroy() end
                        local clone = source:Clone()
                        clone.Name = 'Glove'
                        local mesh = clone:FindFirstChildWhichIsA('SpecialMesh', true) or clone:FindFirstChild('Mesh', true)
                        if mesh and mesh:IsA('SpecialMesh') then
                            mesh.TextureId = texture
                        elseif clone:IsA('MeshPart') then
                            clone.TextureID = texture
                        end
                        clone.Parent = arm
                        if clone:IsA('BasePart') then clone.Transparency = 0 end
                        local welded = clone:FindFirstChild('Welded', true)
                        if welded then welded.Part0 = arm end
                    end
                end
            end
            local function GetClientGun()
                local environment = GetClientEnv()
                local gun = environment and rawget(environment, 'gun')
                return typeof(gun) == 'Instance' and gun or nil
            end
            local function TryApplyArms(arms)
                if not arms or not arms.Parent then return true end
                ApplyGloves(arms)
                local gun = GetClientGun()
                if not gun then return false end
                local name = gun.Name
                if string.find(name, 'Grenade', 1, true) or string.find(name, 'Flashbang', 1, true) or string.find(name, 'Smoke', 1, true)
                    or string.find(name, 'Decoy', 1, true) or string.find(name, 'Molotov', 1, true) or string.find(name, 'Incendiary', 1, true) or name == 'C4' then return true end
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
                if not arms or State.pendingArms == arms then
                    return
                end
                State.pendingArms = arms
                local generation = State.armsApplyGeneration
                task.spawn(function()
                    for _ = 1, 80 do
                        if generation ~= State.armsApplyGeneration
                            or State.pendingArms ~= arms
                            or not arms.Parent
                        then
                            break
                        end
                        if TryApplyArms(arms) then
                            break
                        end
                        task.wait(0.1)
                    end
                    if State.pendingArms == arms then
                        State.pendingArms = nil
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
                RefreshCurrentArms()
            end)
            GloveBox:AddDropdown('Skin_Glove_Skin', { Text = 'Skin', Values = GloveSkins[AllGloves[1]] or { 'Default' }, Default = 'Default' }):OnChanged(function()
                SavePair(Options.Skin_Glove_Glove, Options.Skin_Glove_Skin, State.gloveSkins)
                RefreshCurrentArms()
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
                State.armsApplyGeneration = State.armsApplyGeneration + 1
                State.pendingArms = nil
                if State.armsConnection then State.armsConnection:Disconnect() end
                if State.cameraConnection then State.cameraConnection:Disconnect() end
                DisconnectSkin()
                RestoreKnives()
                for weapon in pairs(CustomWeaponModels) do RestoreCustomWeapon(weapon) end
                if State.originalCT then State.originalCT:Destroy(); State.originalCT = nil end
                if State.originalT then State.originalT:Destroy(); State.originalT = nil end
                for _, model in pairs(State.originalWeapons) do
                    if model then model:Destroy() end
                end
                table.clear(State.originalWeapons)
                if ExtraModels then ExtraModels:Destroy(); ExtraModels = nil end
                table.clear(State.customWeaponApplied)
                table.clear(State.customWeaponLoading)
                table.clear(State.customWeaponGeneration)
                table.clear(State.knifeSkins)
                table.clear(State.weaponSkins)
                table.clear(State.gloveSkins)
            end
        end
        local Players = VisualTab:AddLeftGroupbox('Players')
        local Removals = WorldTab:AddLeftGroupbox('Removals')
        local WorldAmbience = WorldTab:AddLeftGroupbox('Ambience')
        local KillEffect = WorldTab:AddLeftGroupbox('Kill effect')
        local WorldLighting = WorldTab:AddRightGroupbox('Lighting')
        local SelfChams = WorldTab:AddRightGroupbox('Self chams')
        local Misc = WorldTab:AddRightGroupbox('Misc')
        local ViewModel = VisualTab:AddRightGroupbox('View model')
    local CustomCrosshair = VisualTab:AddLeftGroupbox('Custom crosshair')
    local BulletTracer = VisualTab:AddLeftGroupbox('Bullet tracer')
    local CustomCrosshairCleanup
    local BulletTracerCleanup
        CustomCrosshair:AddToggle('CustomCrosshair_Enable', { Text = 'Enable', Default = false })
            :AddColorPicker('CustomCrosshair_Color', {
                Default = Color3.fromRGB(255, 255, 255),
                Transparency = 0,
                Title = 'Color',
            })
        CustomCrosshair:AddToggle('CustomCrosshair_HideGame', { Text = 'Hide game crosshair', Default = false })
        CustomCrosshair:AddToggle('CustomCrosshair_Spin', { Text = 'Spin', Default = false })
        CustomCrosshair:AddSlider('CustomCrosshair_SpinSpeed', {
            Text = 'Spin speed', Default = 25, Min = 1, Max = 50, Rounding = 0,
        })
        CustomCrosshair:AddSlider('CustomCrosshair_Width', {
            Text = 'Width', Default = 2, Min = 1, Max = 50, Rounding = 0,
        })
        CustomCrosshair:AddSlider('CustomCrosshair_Length', {
            Text = 'Length', Default = 6, Min = 1, Max = 50, Rounding = 0,
        })
        CustomCrosshair:AddSlider('CustomCrosshair_Gap', {
            Text = 'Gap', Default = 6, Min = 0, Max = 50, Rounding = 0,
        })
        CustomCrosshair:AddToggle('CustomCrosshair_Rounded', { Text = 'Rounded ends', Default = false })
        CustomCrosshair:AddSlider('CustomCrosshair_Roundness', {
            Text = 'End roundness', Default = 5, Min = 1, Max = 10, Rounding = 0,
        })
        CustomCrosshair:AddToggle('CustomCrosshair_Outline', { Text = 'Outline', Default = true })
            :AddColorPicker('CustomCrosshair_OutlineColor', {
                Default = Color3.fromRGB(0, 0, 0),
                Transparency = 0,
                Title = 'Outline color',
            })
        CustomCrosshair:AddSlider('CustomCrosshair_OutlineWidth', {
            Text = 'Outline thickness', Default = 1, Min = 1, Max = 50, Rounding = 0,
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
            Text = 'Amount', Default = 50, Min = 10, Max = 500, Rounding = 0,
        })
        KillEffect:AddSlider('KillEffect_Brightness', {
            Text = 'Brightness', Default = 5, Min = 1, Max = 10, Rounding = 0,
        })
        KillEffect:AddDropdown('KillEffect_Mode', {
            Text = 'Particle mode', Values = { 'Statik', 'Dynamic' }, Default = 'Dynamic',
        })
    KillEffect:AddDropdown('KillEffect_Shape', {
        Text = 'Particle shape', Values = { 'Circles', 'Snowflakes', 'Stars' }, Default = 'Circles',
    })
    BulletTracer:AddToggle('BulletTracer_Enable', { Text = 'Enable', Default = false })
    BulletTracer:AddDropdown('BulletTracer_Texture', {
        Text = 'Texture',
        Values = {
            'Solid', 'Lightning', 'Laser', 'Twisted Energy', 'Anime Lazer', 'Arrow',
            'Minecraft', 'Alien Energy Ray', 'Energy Ray', 'Matrix', 'Cartoony Eletric',
        },
        Default = 'Solid',
    })
    BulletTracer:AddSlider('BulletTracer_Thickness', {
        Text = 'Thickness', Default = 2, Min = 1, Max = 50, Rounding = 0,
    })
    BulletTracer:AddSlider('BulletTracer_Lifetime', {
        Text = 'Life time', Default = 2, Min = 1, Max = 10, Rounding = 0, Suffix = 's',
    })
        do
            local PendingKills, ActiveEffects = {}, {}
            local EffectAlive = true
            local EffectConnection
            local LastEffectUpdate = 0
            local EFFECT_UPDATE_INTERVAL = 1 / 60
            local FADE_STEPS = 24
            local MAX_ACTIVE_EFFECTS = 2
            local function NewPart(parent, size, shape)
                local part = Instance.new('Part')
                part.Anchored, part.CanCollide, part.CanTouch, part.CanQuery = true, false, false, false
                part.CastShadow, part.Material = false, Enum.Material.Neon
                part.Shape, part.Size = shape or Enum.PartType.Block, size
                part.Transparency = 1
                part.Parent = parent
                return part
            end
            local function BuildParticle(parent, shape, color)
                local parts = {}
                local function add(size, offset, angle, ball)
                    local part = NewPart(parent, size, ball and Enum.PartType.Ball or nil)
                    part.Color = color
                    parts[#parts + 1] = {
                        part = part,
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
            local function DestroyEffect(index)
                local effect = table.remove(ActiveEffects, index)
                local holder = effect and effect.holder
                if holder and holder.Parent then holder:Destroy() end
            end
            local function UpdateEffects()
                local now = os.clock()
                if now - LastEffectUpdate < EFFECT_UPDATE_INTERVAL then return end
                LastEffectUpdate = now
                local parts, cframes = {}, {}
                for index = #ActiveEffects, 1, -1 do
                    local effect = ActiveEffects[index]
                    local holder = effect.holder
                    local progress = (now - effect.started) / effect.lifetime
                    if progress >= 1 or not EffectAlive or not holder or not holder.Parent then
                        DestroyEffect(index)
                        continue
                    end
                    local rawTransparency = math.clamp((progress - 0.72) / 0.28, 0, 1)
                    local transparency = math.floor(rawTransparency * FADE_STEPS + 0.5) / FADE_STEPS
                    local transparencyChanged = effect.transparency ~= transparency
                    effect.transparency = transparency
                    local needsParticleUpdate = effect.dynamic or not effect.positioned or transparencyChanged
                    if needsParticleUpdate then
                        for _, particle in ipairs(effect.particles) do
                            local movePart = effect.dynamic or not particle.positioned
                            local frame
                            if movePart then
                                local position = particle.origin
                                if effect.dynamic then
                                    position = position + particle.direction * (particle.distance * progress)
                                        + Vector3.new(0, math.sin(progress * math.pi) * 1.8, 0)
                                end
                                frame = CFrame.new(position) * CFrame.Angles(
                                    0,
                                    effect.dynamic and progress * 8 + particle.phase or particle.phase,
                                    effect.dynamic and progress * 5 or 0
                                )
                                particle.positioned = true
                            end
                            for _, entry in ipairs(particle.parts) do
                                local part = entry.part
                                if part.Parent then
                                    if transparencyChanged then
                                        part.Transparency = transparency
                                    end
                                    if movePart then
                                        parts[#parts + 1] = part
                                        cframes[#cframes + 1] = frame * entry.offset
                                    end
                                end
                            end
                        end
                        effect.positioned = true
                    end
                end
                if #parts > 0 then
                    workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
                end
            end
            EffectConnection = AddFrameTask(FrameScheduler.render, UpdateEffects)
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
                while #ActiveEffects >= MAX_ACTIVE_EFFECTS do
                    DestroyEffect(1)
                end
                local holder = Instance.new('Folder')
                holder.Name, holder.Parent = 'ValenokKillEffect', workspace
                local particles, color = {}, Options.KillEffect_Color.Value
                local hue, saturation, value = color:ToHSV()
                local brightness = Options.KillEffect_Brightness.Value
                color = Color3.fromHSV(hue, saturation, math.clamp(value * (0.5 + brightness / 10), 0, 1))
                local shape = Options.KillEffect_Shape.Value
                local requestedAmount = math.clamp(math.floor(Options.KillEffect_Amount.Value), 1, 500)
                local amount = requestedAmount
                for i = 1, amount do
                    local hitbox = hitboxes[(i - 1) % #hitboxes + 1]
                    local size = hitbox.Size
                    local origin = hitbox.CFrame:PointToWorldSpace(Vector3.new(
                        (math.random() - 0.5) * size.X,
                        (math.random() - 0.5) * size.Y,
                        (math.random() - 0.5) * size.Z
                    ))
                    local angle = math.pi * 2 * i / amount + math.random() * 0.22
                    particles[#particles + 1] = {
                        parts = BuildParticle(holder, shape, color),
                        origin = origin,
                        direction = Vector3.new(
                            math.cos(angle),
                            0.25 + math.random() * 0.55,
                            math.sin(angle)
                        ).Unit,
                        phase = math.random() * math.pi * 2,
                        distance = 2.2 + math.random() * 2.6,
                        positioned = false,
                    }
                end
                local lifetime = Options.KillEffect_Lifetime.Value
                ActiveEffects[#ActiveEffects + 1] = {
                    holder = holder,
                    particles = particles,
                    started = os.clock(),
                    lifetime = lifetime,
                    dynamic = Options.KillEffect_Mode.Value == 'Dynamic',
                }
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
                if EffectConnection then
                    EffectConnection:Disconnect()
                    EffectConnection = nil
                end
                for _, pending in pairs(PendingKills) do
                    if pending.health then pending.health:Disconnect() end
                    if pending.died then pending.died:Disconnect() end
                end
                for index = #ActiveEffects, 1, -1 do
                    DestroyEffect(index)
                end
                table.clear(PendingKills)
                table.clear(ActiveEffects)
            end
    end
    do
        local TracerTextures = {
            Solid = 'rbxassetid://446111271',
            Lightning = 'rbxassetid://7216850022',
            Laser = 'rbxassetid://7136858729',
            ['Twisted Energy'] = 'rbxassetid://7071778278',
            ['Anime Lazer'] = 'rbxassetid://17441065350',
            Arrow = 'rbxassetid://1274378728',
            Minecraft = 'rbxassetid://152410036',
            ['Alien Energy Ray'] = 'rbxassetid://6091341618',
            ['Energy Ray'] = 'rbxassetid://13832105797',
            Matrix = 'rbxassetid://15097610754',
            ['Cartoony Eletric'] = 'rbxassetid://18722421816',
        }
        local tracerFolder
        local MAX_TRACERS = 128
        local function GetTracerTexture()
            return TracerTextures[Options.BulletTracer_Texture.Value] or TracerTextures.Solid
        end
        local function ApplyTracerTexture()
            if not tracerFolder or not tracerFolder.Parent then return end
            local texture = GetTracerTexture()
            for _, instance in ipairs(tracerFolder:GetDescendants()) do
                if instance:IsA('Beam') and instance:GetAttribute('ValenokKeepEffect') then
                    instance.Texture = texture
                end
            end
        end
        local function GetTracerFolder()
            if tracerFolder and tracerFolder.Parent then return tracerFolder end
            tracerFolder = Instance.new('Folder')
            tracerFolder.Name = 'ValenokBulletTracers'
            tracerFolder.Parent = workspace
            return tracerFolder
        end
        local function TrimTracers(folder)
            local children = folder:GetChildren()
            local removeCount = #children - MAX_TRACERS + 1
            for i = 1, removeCount do
                children[i]:Destroy()
            end
        end
        local function CreateBulletTracer(hitPosition, cameraPosition)
            if not Toggles.BulletTracer_Enable.Value or typeof(hitPosition) ~= 'Vector3' then
                return
            end
            local camera = workspace.CurrentCamera
            local origin = typeof(cameraPosition) == 'Vector3' and cameraPosition
                or (camera and camera.CFrame.Position)
            if not origin or (hitPosition - origin).Magnitude < 0.05 then
                return
            end
            local holder = Instance.new('Part')
            holder.Name = 'ValenokBulletTracer'
            holder.Anchored = true
            holder.CanCollide = false
            holder.CanTouch = false
            holder.CanQuery = false
            holder.Transparency = 1
            holder.Size = Vector3.new(0.05, 0.05, 0.05)
            holder.CFrame = CFrame.new(origin)
            local folder = GetTracerFolder()
            TrimTracers(folder)
            holder.Parent = folder
            local startAttachment = Instance.new('Attachment')
            startAttachment.Position = Vector3.zero
            startAttachment.Parent = holder
            local endAttachment = Instance.new('Attachment')
            endAttachment.Position = hitPosition - origin
            endAttachment.Parent = holder
            local beam = Instance.new('Beam')
            beam.Name = 'ValenokBulletTracerBeam'
            beam:SetAttribute('ValenokKeepEffect', true)
            beam.Attachment0 = startAttachment
            beam.Attachment1 = endAttachment
            beam.Texture = GetTracerTexture()
            beam.TextureMode = Enum.TextureMode.Wrap
            beam.TextureLength = 2
            beam.TextureSpeed = 0
            beam.FaceCamera = true
            beam.LightEmission = 1
            beam.Segments = 1
            local width = math.clamp(Options.BulletTracer_Thickness.Value, 1, 50) / 50
            beam.Width0 = width
            beam.Width1 = width
            beam.Parent = holder
            DebrisService:AddItem(holder, math.clamp(Options.BulletTracer_Lifetime.Value, 1, 10))
        end
        HandleBulletTracer = CreateBulletTracer
        Options.BulletTracer_Texture:OnChanged(ApplyTracerTexture)
        BulletTracerCleanup = function()
            HandleBulletTracer = nil
            if tracerFolder and tracerFolder.Parent then tracerFolder:Destroy() end
            tracerFolder = nil
        end
    end
    do
        local Lines, Outlines, Caps, OutlineCaps = {}, {}, {}, {}
            local GameCrosshair, GameCrosshairConnection
            local GameCrosshairProperties = setmetatable({}, { __mode = 'k' })
            local function EnsureLineSet(set, zIndex)
                for i = 1, 4 do
                    if not set[i] then
                        local ok, line = pcall(Drawing.new, 'Line')
                        if ok and line then
                            line.Visible, line.ZIndex = false, zIndex
                            set[i] = line
                        end
                    end
                end
            end
            local function EnsureCapSet(set, zIndex)
                for i = 1, 8 do
                    if not set[i] then
                        local ok, cap = pcall(Drawing.new, 'Circle')
                        if ok and cap then
                            cap.Filled, cap.Visible, cap.ZIndex = true, false, zIndex
                            set[i] = cap
                        end
                    end
                end
            end
            local function RemoveDrawingSet(set)
                for i = 1, #set do
                    if set[i] then
                        pcall(function() set[i]:Remove() end)
                        set[i] = nil
                    end
                end
            end
            local function RestoreGameCrosshair()
                for instance, properties in pairs(GameCrosshairProperties) do
                    if instance and instance.Parent then
                        for property, value in pairs(properties) do
                            pcall(function() instance[property] = value end)
                        end
                    end
                end
                table.clear(GameCrosshairProperties)
            end
            local function MakeGameCrosshairTransparent(crosshair)
                if not crosshair then return end
                local function hide(instance, property)
                    local ok, value = pcall(function() return instance[property] end)
                    if not ok then return end
                    local properties = GameCrosshairProperties[instance]
                    if not properties then
                        properties = {}
                        GameCrosshairProperties[instance] = properties
                    end
                    if properties[property] == nil then properties[property] = value end
                    pcall(function() instance[property] = 1 end)
                end
                hide(crosshair, 'BackgroundTransparency')
                for _, instance in ipairs(crosshair:GetDescendants()) do
                    hide(instance, 'BackgroundTransparency')
                    hide(instance, 'ImageTransparency')
                    hide(instance, 'TextTransparency')
                    hide(instance, 'Transparency')
                end
            end
            local function HideGameCrosshair()
                local shouldHide = Toggles.CustomCrosshair_Enable.Value and Toggles.CustomCrosshair_HideGame.Value
                if not shouldHide then
                    RestoreGameCrosshair()
                    return
                end
                local playerGui = LocalPlayer:FindFirstChildOfClass('PlayerGui')
                local gui = playerGui and playerGui:FindFirstChild('GUI')
                local crosshairs = gui and gui:FindFirstChild('Crosshairs')
                local crosshair = crosshairs and crosshairs:FindFirstChild('Crosshair')
                if crosshair ~= GameCrosshair then
                    RestoreGameCrosshair()
                    if GameCrosshairConnection then GameCrosshairConnection:Disconnect() end
                    GameCrosshair, GameCrosshairConnection = crosshair, nil
                    if crosshair then
                        GameCrosshairConnection = crosshair:GetPropertyChangedSignal('Visible'):Connect(function()
                            if Toggles.CustomCrosshair_Enable.Value and Toggles.CustomCrosshair_HideGame.Value then
                                crosshair.Visible = false
                                MakeGameCrosshairTransparent(crosshair)
                            end
                        end)
                    end
                end
                if crosshair then
                    crosshair.Visible = false
                    MakeGameCrosshairTransparent(crosshair)
                end
            end
            Library:GiveSignal(AddFrameTask(FrameScheduler.render, function()
                local enabled = ToggleEnabled('CustomCrosshair_Enable')
                if not enabled then
                    RemoveDrawingSet(Lines)
                    RemoveDrawingSet(Outlines)
                    RemoveDrawingSet(Caps)
                    RemoveDrawingSet(OutlineCaps)
                    return
                end
                local camera = workspace.CurrentCamera
                if not camera then return end
                local viewport = camera.ViewportSize
                if viewport.X <= 0 or viewport.Y <= 0 then return end
                local center = viewport * 0.5
                local width = OptionValue('CustomCrosshair_Width', 2)
                local length = OptionValue('CustomCrosshair_Length', 8)
                local gap = OptionValue('CustomCrosshair_Gap', 4)
                local angle = ToggleEnabled('CustomCrosshair_Spin')
                    and math.rad(os.clock() * OptionValue('CustomCrosshair_SpinSpeed', 50) * 3.6) or 0
                local x, y = math.cos(angle), math.sin(angle)
                local directions = {
                    Vector2.new(x, y), Vector2.new(-y, x), Vector2.new(-x, -y), Vector2.new(y, -x),
                }
                local color = OptionValue('CustomCrosshair_Color', Color3.new(1, 1, 1))
                local outlineOn = ToggleEnabled('CustomCrosshair_Outline')
                local outlineColor = OptionValue('CustomCrosshair_OutlineColor', Color3.new())
                local outlineWidth = OptionValue('CustomCrosshair_OutlineWidth', 1)
                local rounded = ToggleEnabled('CustomCrosshair_Rounded')
                local capRadius = math.max(width * 0.5, OptionValue('CustomCrosshair_Roundness', 2) * 0.5)
                EnsureLineSet(Lines, 2)
                if outlineOn then
                    EnsureLineSet(Outlines, 1)
                end
                if rounded then
                    EnsureCapSet(Caps, 2)
                    if outlineOn then
                        EnsureCapSet(OutlineCaps, 1)
                    end
                end
                for i = 1, 4 do
                    local from = center + directions[i] * gap
                    local to = center + directions[i] * (gap + length)
                    local line, outline = Lines[i], Outlines[i]
                    local firstCap, lastCap = Caps[(i - 1) * 2 + 1], Caps[(i - 1) * 2 + 2]
                    local firstOutlineCap, lastOutlineCap = OutlineCaps[(i - 1) * 2 + 1], OutlineCaps[(i - 1) * 2 + 2]
                    if line then
                        line.From, line.To, line.Color, line.Thickness, line.Visible = from, to, color, width, true
                    end
                    if outline then
                        outline.From, outline.To = from, to
                        outline.Color, outline.Thickness, outline.Visible = outlineColor, width + outlineWidth * 2, outlineOn
                    end
                    if firstCap then
                        firstCap.Position, firstCap.Radius, firstCap.Color, firstCap.Visible = from, capRadius, color, rounded
                    end
                    if lastCap then
                        lastCap.Position, lastCap.Radius, lastCap.Color, lastCap.Visible = to, capRadius, color, rounded
                    end
                    local outlineVisible = rounded and outlineOn
                    local outlineRadius = capRadius + outlineWidth
                    if firstOutlineCap then
                        firstOutlineCap.Position, firstOutlineCap.Radius, firstOutlineCap.Color, firstOutlineCap.Visible = from, outlineRadius, outlineColor, outlineVisible
                    end
                    if lastOutlineCap then
                        lastOutlineCap.Position, lastOutlineCap.Radius, lastOutlineCap.Color, lastOutlineCap.Visible = to, outlineRadius, outlineColor, outlineVisible
                    end
                end
            end))
            pcall(function()
                RunService:UnbindFromRenderStep('ValenokHideGameCrosshair')
                RunService:BindToRenderStep('ValenokHideGameCrosshair', Enum.RenderPriority.Last.Value, HideGameCrosshair)
            end)
            CustomCrosshairCleanup = function()
                pcall(function() RunService:UnbindFromRenderStep('ValenokHideGameCrosshair') end)
                if GameCrosshairConnection then
                    GameCrosshairConnection:Disconnect()
                    GameCrosshairConnection = nil
                end
                GameCrosshair = nil
                RestoreGameCrosshair()
                RemoveDrawingSet(Lines)
                RemoveDrawingSet(Outlines)
                RemoveDrawingSet(Caps)
                RemoveDrawingSet(OutlineCaps)
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
            local DisplayConnection, Header
            local Dragging, DragOffset = false, Vector2.new()
            local DragConnections = {}
            local HitLogPosition = Vector2.new(0, 300)
            local PositionInitialized = false
            local HitLogAlive = true
            local function SetHitLogPosition(position)
                local x, y
                if typeof(position) == 'Vector2' then
                    x, y = position.X, position.Y
                elseif type(position) == 'table' then
                    x, y = tonumber(position.x), tonumber(position.y)
                end
                if not x or not y then return end
                HitLogPosition = Vector2.new(x, y)
                PositionInitialized = true
                ScriptEnvironment.ValenokHitLogPosition = { x = x, y = y }
            end
            SetHitLogPosition(ScriptEnvironment.ValenokHitLogPosition)
            ScriptEnvironment.ValenokHitLogSetPosition = SetHitLogPosition
            local function GetHitbox(part)
                local name = part.Name
                if name == 'HeadHB' or name == 'FakeHead' or name == 'Head' then return 'Head' end
                if name == 'UpperTorso' or name == 'LowerTorso' or name == 'Torso' or name == 'HumanoidRootPart' then return 'Body' end
                if string.find(name, 'Arm', 1, true) or string.find(name, 'Hand', 1, true) then return 'Arms' end
                if string.find(name, 'Leg', 1, true) or string.find(name, 'Foot', 1, true) then return 'Legs' end
                return name
            end
            PlayHitSound = function()
                local soundOption = Options.HitLog_Sound
                local volumeOption = Options.HitLog_Volume
                if not soundOption or not volumeOption then return end
                local soundId = HitSounds[soundOption.Value]
                if type(soundId) == 'table' then soundId = soundId[math.random(1, #soundId)] end
                soundId = tonumber(soundId)
                if not soundId or soundId <= 0 then return end
                local sound = Instance.new('Sound')
                sound.SoundId = 'rbxassetid://' .. math.floor(soundId)
                sound.Volume = volumeOption.Value
                sound.Parent = SoundService
                sound:Play()
                DebrisService:AddItem(sound, 5)
            end
            local function PushLog(player, hitbox, damage)
                local displayToggle = Toggles.HitLog_DisplayEnable
                local lifetimeOption = Options.HitLog_Lifetime
                local colorOption = Options.HitLog_HitColor
                if not displayToggle or not lifetimeOption or not colorOption or not displayToggle.Value then return end
                table.insert(Entries, 1, {
                    text = string.format('Hit %s in %s (-%d HP)', player.Name, hitbox, math.floor(damage + 0.5)),
                    expires = os.clock() + lifetimeOption.Value,
                    color = colorOption.Value,
                })
                while #Entries > MaxEntries do table.remove(Entries) end
            end
            local function PushMiss(player, hitbox)
                local displayToggle = Toggles.HitLog_DisplayEnable
                local lifetimeOption = Options.HitLog_Lifetime
                local colorOption = Options.HitLog_MissColor
                if not displayToggle or not lifetimeOption or not colorOption or not displayToggle.Value then return end
                table.insert(Entries, 1, {
                    text = string.format('Missed %s in %s', player.Name, hitbox),
                    expires = os.clock() + lifetimeOption.Value,
                    color = colorOption.Value,
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
                    local soundToggle = Toggles.HitLog_Enable
                    if soundToggle and soundToggle.Value then PlayHitSound() end
                    PushLog(player, hitbox, health - current)
                end)
                Pending[userId] = connection
                task.delay(0.5, function()
                    if Pending[userId] == connection then
                        connection:Disconnect()
                        Pending[userId] = nil
                        PushMiss(player, hitbox)
                    end
                end)
            end
            HandleHitParl = function(hitPart)
                if not HitLogAlive then return end
                local soundToggle = Toggles.HitLog_Enable
                local displayToggle = Toggles.HitLog_DisplayEnable
                if not soundToggle or not displayToggle then return end
                if not soundToggle.Value and not displayToggle.Value then return end
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
            local function GetHeader()
                if Header then return Header end
                local ok, header = pcall(Drawing.new, 'Text')
                if not ok then return end
                header.Center, header.Outline, header.Size, header.Font = true, true, 13, 2
                header.Color, header.OutlineColor, header.Text, header.Visible = Color3.new(1, 1, 1), Color3.new(), 'Hitlog', false
                Header = header
                return header
            end
            local function IsMenuVisible()
                local ok, visible = pcall(Library.IsMenuVisible, Library)
                return ok and visible
            end
            local function UpdateDisplay()
                local now = os.clock()
                while Entries[#Entries] and Entries[#Entries].expires <= now do table.remove(Entries) end
                local camera = workspace.CurrentCamera
                if camera and not PositionInitialized then
                    SetHitLogPosition({ x = camera.ViewportSize.X / 2, y = 300 })
                end
                local menuOpen = IsMenuVisible()
                local displayEnabled = ToggleEnabled('HitLog_DisplayEnable')
                local header = Header or (menuOpen and GetHeader())
                if header then
                    header.Visible = menuOpen
                    header.Position = HitLogPosition - Vector2.new(0, 18)
                end
                for i = 1, MaxEntries do
                    local entry = Entries[i]
                    local text = Texts[i] or (entry and GetText(i))
                    if text then
                        text.Visible = displayEnabled and entry ~= nil
                        if entry then
                            text.Text = entry.text
                            text.Color = entry.color or OptionValue('HitLog_HitColor', Color3.fromRGB(80, 255, 120))
                            text.Position = HitLogPosition + Vector2.new(0, (i - 1) * 16)
                        end
                    end
                end
            end
            local function SetDisplayEnabled()
                local displayToggle = Toggles.HitLog_DisplayEnable
                if not displayToggle then return end
                if not DisplayConnection then
                    DisplayConnection = RunService.RenderStepped:Connect(UpdateDisplay)
                end
                if not displayToggle.Value then
                    for i = 1, #Texts do Texts[i].Visible = false end
                    Dragging = false
                end
            end
            DragConnections[#DragConnections + 1] = UserInputService.InputBegan:Connect(function(input)
                if input.UserInputType ~= Enum.UserInputType.MouseButton1 or not IsMenuVisible()
                then
                    return
                end
                local mouse = UserInputService:GetMouseLocation()
                local headerY = HitLogPosition.Y - 18
                if math.abs(mouse.X - HitLogPosition.X) <= 42 and mouse.Y >= headerY - 8 and mouse.Y <= headerY + 10 then
                    Dragging = true
                    DragOffset = HitLogPosition - mouse
                end
            end)
            DragConnections[#DragConnections + 1] = UserInputService.InputChanged:Connect(function(input)
                if Dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
                    SetHitLogPosition(UserInputService:GetMouseLocation() + DragOffset)
                end
            end)
            DragConnections[#DragConnections + 1] = UserInputService.InputEnded:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 then Dragging = false end
            end)
            if Toggles.HitLog_DisplayEnable then
                Toggles.HitLog_DisplayEnable:OnChanged(SetDisplayEnabled)
                SetDisplayEnabled()
            else
                HitLogControlsReady = function()
                    if Toggles.HitLog_DisplayEnable then
                        Toggles.HitLog_DisplayEnable:OnChanged(SetDisplayEnabled)
                        SetDisplayEnabled()
                    end
                    HitLogControlsReady = nil
                end
            end
            HitLogCleanup = function()
                HitLogAlive = false
                HandleHitParl = nil
                PlayHitSound = nil
                if DisplayConnection then
                    DisplayConnection:Disconnect()
                    DisplayConnection = nil
                end
                for _, connection in pairs(Pending) do connection:Disconnect() end
                for _, text in pairs(Texts) do text:Remove() end
                for i = 1, #DragConnections do DragConnections[i]:Disconnect() end
                if Header then Header:Remove(); Header = nil end
                table.clear(Pending)
                table.clear(Texts)
                table.clear(Entries)
                table.clear(DragConnections)
                if ScriptEnvironment.ValenokHitLogSetPosition == SetHitLogPosition then
                    ScriptEnvironment.ValenokHitLogSetPosition = nil
                end
            end
        end
        local AntiAimState = {
            pitchRandom = 0,
            pitchRandomAt = 0,
            pitchLastFire = 0,
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
                    if method == 'Raycast' and self == workspace and HandleLegitSilentRaycast
                        and (type(checkcaller) ~= 'function' or not checkcaller())
                    then
                        local origin, direction, params = ...
                        local redirected = HandleLegitSilentRaycast(origin, direction)
                        if redirected then
                            return oldNamecall(self, origin, redirected, params)
                        end
                    end
                    if (method == 'FireServer' or method == 'FireUnreliable')
                        and HandleInfAmmoNamecall and HandleInfAmmoNamecall(self, method, ...)
                    then
                        return nil
                    end
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
                    if (method == 'FireServer' or method == 'FireUnreliable')
                        and self.Name == 'ParticleRemote' and HandleBulletTracer
                    then
                        local request = ...
                        if type(request) == 'table'
                            and request[1] == 'createparticle'
                            and request[2] == 'bullethole'
                            and typeof(request[4]) == 'Vector3'
                        then
                            local camera = workspace.CurrentCamera
                            local origin = camera and camera.CFrame.Position
                            task.defer(HandleBulletTracer, request[4], origin)
                        end
                    end
                    local hitLogEnable = Toggles.HitLog_Enable
                    local hitLogDisplay = Toggles.HitLog_DisplayEnable
                    if not hitLogEnable or not hitLogDisplay then
                        return oldNamecall(self, ...)
                    end
                    if not hitLogEnable.Value
                        and not hitLogDisplay.Value
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
                        and (hitLogEnable.Value or hitLogDisplay.Value)
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
        Removals:AddToggle('Removals_NoScope', { Text = 'Remove Scope / Crosshair', Default = false })
        Removals:AddToggle('Removals_NoWeaponAnimation', { Text = 'Remove Weapon Animation', Default = false })
        Misc:AddToggle('SpreadVisualizer_Enable', {
            Text = 'Spread visualizer',
            Default = false,
        }):AddColorPicker('SpreadVisualizer_Color', {
            Default = Color3.fromRGB(255, 255, 0),
            Transparency = 0.65,
        })
        local ESPFontMap = {
            UI = 0,
            System = 1,
            Plex = 2,
            Monospace = 3,
        }
        local ESPFont = ESPFontMap.Plex
        local ESPFontSize = 13
        Players:AddDropdown('ESP_Font', {
            Text = 'ESP font',
            Values = { 'UI', 'System', 'Plex', 'Monospace' },
            Default = 'Plex',
        }):OnChanged(function(value)
            ESPFont = ESPFontMap[value] or ESPFontMap.Plex
        end)
        Players:AddSlider('ESP_FontSize', {
            Text = 'ESP font size',
            Default = 13,
            Min = 1,
            Max = 32,
            Rounding = 0,
        }):OnChanged(function(value)
            ESPFontSize = math.clamp(tonumber(value) or 13, 1, 32)
        end)
        Players:AddToggle('ESP_Enable', { Text = 'Enable', Default = false })
        Players:AddToggle('ESP_TeamCheck', { Text = 'TeamCheck', Default = false })
        local UnloadFns = {}
        local function AddUnload(fn)
            UnloadFns[#UnloadFns + 1] = fn
        end
        AddUnload(function()
            local leavePresence = Environment.__ValenokPresenceLeaveV2
            if type(leavePresence) == 'function' then
                leavePresence()
            end
        end)
        AddUnload(function()
            if CustomCrosshairCleanup then CustomCrosshairCleanup() end
        end)
        AddUnload(function()
            if KillEffectCleanup then KillEffectCleanup() end
        end)
        AddUnload(function()
            if BulletTracerCleanup then BulletTracerCleanup() end
        end)
        AddUnload(function()
            if SkinCleanup then
                SkinCleanup()
                SkinCleanup = nil
            end
        end)
        AddUnload(function()
            if ClientEnvState.guiAdded then
                ClientEnvState.guiAdded:Disconnect()
                ClientEnvState.guiAdded = nil
            end
            if ClientEnvState.guiRemoved then
                ClientEnvState.guiRemoved:Disconnect()
                ClientEnvState.guiRemoved = nil
            end
            ClientEnvState.playerGui = nil
            ClientEnvState.client = nil
            ClientEnvState.env = nil
            ClientEnvState.resolved = false
            table.clear(GameRefs)
            table.clear(GameModules)
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
            table.clear(UnloadFns)
            if ScriptEnvironment.__ValenokRecodeReloadCleanup == ReloadCleanup then
                ScriptEnvironment.__ValenokRecodeReloadCleanup = nil
            end
        end)
        do
            local SmokeConnections = {}
            local FlashState
            local CrosshairHudState = setmetatable({}, { __mode = 'k' })
            local ScopeTransparency = setmetatable({}, { __mode = 'k' })
            local NoScopeConnection
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
            local function GetCrosshairs()
                local gui = GetPlayerGui()
                local root = gui and (gui:FindFirstChild('GUI') or gui:FindFirstChild('Client'))
                return root and root:FindFirstChild('Crosshairs')
            end
            local function HideCrosshairHudObject(object)
                if not object then
                    return
                end
                if CrosshairHudState[object] == nil then
                    CrosshairHudState[object] = object.Visible
                end
                object.Visible = false
            end
            local function RestoreCrosshairHud()
                for object, visible in pairs(CrosshairHudState) do
                    if object.Parent then
                        object.Visible = visible
                    end
                    CrosshairHudState[object] = nil
                end
            end
            local function SetScopeTransparency(object, transparency)
                if ScopeTransparency[object] == nil then
                    ScopeTransparency[object] = object.ImageTransparency
                end
                object.ImageTransparency = transparency
            end
            local function RestoreScopeTransparency()
                for object, transparency in pairs(ScopeTransparency) do
                    if object.Parent then
                        object.ImageTransparency = transparency
                    end
                    ScopeTransparency[object] = nil
                end
            end
            local function UpdateNoScope()
                local crosshairs = GetCrosshairs()
                if not Toggles.Removals_NoScope.Value then
                    RestoreCrosshairHud()
                    RestoreScopeTransparency()
                    return
                end
                if not crosshairs then
                    return
                end
                for _, name in ipairs({ 'Crosshair', 'Frame1', 'Frame2', 'Frame3', 'Frame4', 'Iconhair' }) do
                    local child = crosshairs:FindFirstChild(name)
                    if child then
                        HideCrosshairHudObject(child)
                        for _, descendant in ipairs(child:GetDescendants()) do
                            if descendant:IsA('GuiObject') then
                                HideCrosshairHudObject(descendant)
                            end
                        end
                    end
                end
                local scope = crosshairs:FindFirstChild('Scope')
                if scope then
                    if scope:IsA('ImageLabel') or scope:IsA('ImageButton') then
                        SetScopeTransparency(scope, 1)
                    end
                    for _, item in ipairs(scope:GetDescendants()) do
                        if item:IsA('ImageLabel') or item:IsA('ImageButton') then
                            SetScopeTransparency(item, 1)
                        end
                    end
                end
            end
            local function RefreshNoScopeConnection()
                if Toggles.Removals_NoScope.Value then
                    if not NoScopeConnection then
                        NoScopeConnection = RunService.RenderStepped:Connect(UpdateNoScope)
                    end
                    UpdateNoScope()
                else
                    if NoScopeConnection then
                        NoScopeConnection:Disconnect()
                        NoScopeConnection = nil
                    end
                    RestoreCrosshairHud()
                    RestoreScopeTransparency()
                end
            end
            local function IsFireAnimation(track)
                local animation = track.Animation
                local name = animation and string.lower(animation.Name) or ''
                return name == 'fire' or name == 'fire2' or name == 'fire3'
                    or name == 'aimfire' or name == 'fastfire' or name == 'fire_juggernaut'
            end
            local function IsHoldingC4()
                local character = LocalPlayer.Character
                local gun = character and character:FindFirstChild('Gun')
                if gun and gun.Name == 'C4' then
                    return true
                end
                local environment = GetClientEnv()
                local clientGun = environment and rawget(environment, 'gun')
                if typeof(clientGun) == 'Instance' and clientGun.Name == 'C4' then
                    return true
                end
                local camera = workspace.CurrentCamera
                local arms = camera and camera:FindFirstChild('Arms')
                return arms ~= nil and arms:FindFirstChild('C4', true) ~= nil
            end
            local function BlockAnimation(track)
                if Toggles.Removals_NoWeaponAnimation.Value
                    and IsFireAnimation(track)
                    and not IsHoldingC4()
                then
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
            local function DisconnectAllAnimators()
                while true do
                    local animator = next(AnimationConnections)
                    if not animator then
                        break
                    end
                    DisconnectAnimator(animator)
                end
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
                UpdateWeaponAnimations()
            end
            local function RefreshPolling()
                local shouldPoll = Toggles.Removals_NoFlash.Value
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
                RefreshNoScopeConnection()
            end)
            Toggles.Removals_NoWeaponAnimation:OnChanged(function()
                if Toggles.Removals_NoWeaponAnimation.Value then
                    UpdateWeaponAnimations()
                else
                    DisconnectAllAnimators()
                end
                RefreshPolling()
            end)
            RefreshPolling()
            RefreshNoScopeConnection()
            AddUnload(function()
                if PollConnection then
                    PollConnection:Disconnect()
                    PollConnection = nil
                end
                if NoScopeConnection then
                    NoScopeConnection:Disconnect()
                    NoScopeConnection = nil
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
                RestoreCrosshairHud()
                RestoreScopeTransparency()
                DisconnectAllAnimators()
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
        AddUnload(function()
            table.clear(PlayerSnapshot)
            table.clear(PlayerSnapshotIndex)
        end)
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
            text.Font = ESPFont
            text.Size = ESPFontSize
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
        local SharedRaycastIgnoreRevision = 0
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
            SharedRaycastIgnoreRevision = SharedRaycastIgnoreRevision + 1
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
        local function AppendCombatRaycastIgnore(ignore, startIndex, camera)
            local previousCount = #ignore
            local count = startIndex - 1
            local seen = {}
            for i = 1, count do
                if ignore[i] then
                    seen[ignore[i]] = true
                end
            end
            local function add(instance)
                if instance and not seen[instance] then
                    count = count + 1
                    ignore[count] = instance
                    seen[instance] = true
                end
            end
            add(LocalPlayer.Character)
            add(camera)
            if camera then
                add(camera:FindFirstChild('Arms'))
                add(camera:FindFirstChild('Debris'))
                add(camera:FindFirstChild('GUI'))
            end
            local character = LocalPlayer.Character
            if character then
                add(character:FindFirstChild('Gun'))
                add(character:FindFirstChild('Gun2'))
                add(character:FindFirstChild('Knife'))
                add(character:FindFirstChild('BackC4'))
                add(character:FindFirstChild('Hitboxes'))
                add(character:FindFirstChild('FakeHead'))
                add(character:FindFirstChild('HeadHB'))
                for _, child in ipairs(character:GetChildren()) do
                    if child:IsA('Accessory')
                        or child:IsA('Hat')
                        or child:IsA('Tool')
                        or child:IsA('Model')
                        or child.Name:find('Valenok', 1, true) == 1
                    then
                        add(child)
                    end
                end
            end
            add(GetRayIgnoreRoot())
            add(GetDebrisRoot())
            add(GetMapClips())
            add(GetMapSpawnPoints())
            local shared = GetSharedRaycastIgnore()
            for i = 1, #shared do
                add(shared[i])
            end
            for i = count + 1, previousCount do
                ignore[i] = nil
            end
            return count
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
            Default = { 'Head', 'Body', 'Arms', 'Legs' },
            Multi = true,
        })
        RageBot:AddToggle('RageBot_TeamCheck', { Text = 'TeamCheck', Default = true })
        RageBot:AddToggle('RageBot_ShowFov', { Text = 'Show Fov', Default = false })
        RageBot:AddDropdown('RageBot_StartPoint', {
            Text = 'Start point',
            Values = { 'Camera', 'Character' },
            Default = 'Camera',
            Tooltip = 'Visible/wall rays only. Character = from local head. HitParl unchanged.',
        })
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
        RageBot:AddToggle('RageBot_MinDamage_Enable', { Text = 'Min damage', Default = false })
        RageBot:AddSlider('RageBot_MinDamage', {
            Text = 'Min damage',
            Default = 0.1,
            Min = 0.1,
            Max = 1,
            Rounding = 2,
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
        do
            local function UpdateMinDamageUI()
                local slider = Options.RageBot_MinDamage
                if type(slider.SetVisible) == 'function' then
                    slider:SetVisible(Toggles.RageBot_MinDamage_Enable.Value)
                end
            end
            Toggles.RageBot_MinDamage_Enable:OnChanged(UpdateMinDamageUI)
            UpdateMinDamageUI()
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
            local NextAntiAimUpdate = 0
            local ANTI_AIM_INTERVAL = 1 / 60
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
                local now = os.clock()
                if now < NextAntiAimUpdate then
                    return
                end
                NextAntiAimUpdate = now + ANTI_AIM_INTERVAL
                local pitchEnabled = ToggleEnabled('AntiAim_Pitch_Enable')
                local yawEnabled = ToggleEnabled('AntiAim_Yaw_Enable')
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
                    local now = os.clock()
                    if remote and now - AntiAimState.pitchLastFire >= 1 / 60 then
                        AntiAimState.pitchLastFire = now
                        pcall(function() remote:FireServer(GetAntiAimPitchValue()) end)
                    end
                end
                if not yawEnabled then return end
                local baseYaw = 0
                if OptionValue('AntiAim_Yaw_Type', 'None') == 'At target' then
                    local targetRoot = GetAntiAimTargetRoot(root.Position)
                    local direction = targetRoot and (targetRoot.Position - root.Position) * Vector3.new(1, 0, 1)
                    if direction and direction.Magnitude > 0.1 then
                        baseYaw = math.deg(math.atan2(direction.X, direction.Z))
                    end
                else
                    local camera = GetCurrentCamera()
                    if camera then
                        local look = camera.CFrame.LookVector
                        baseYaw = math.deg(math.atan2(look.X, look.Z))
                    end
                end
                local mode = OptionValue('AntiAim_Yaw_Mode', 'None')
                local yaw = baseYaw
                if mode == 'Forwards' then
                    yaw = yaw + 180
                elseif mode == 'Spin' then
                    local now = os.clock()
                    local speed = math.max(OptionValue('AntiAim_Yaw_SpinSpeed', 1), 1)
                    local elapsed = (now - AntiAimState.yawSpinAt) * 1000
                    AntiAimState.yawSpin = (AntiAimState.yawSpin + elapsed / speed * 360) % 360
                    AntiAimState.yawSpinAt = now
                    yaw = yaw + AntiAimState.yawSpin
                elseif mode == 'Custom' then
                    yaw = yaw + OptionValue('AntiAim_Yaw_CustomValue', 0)
                end
                root.CFrame = CFrame.new(root.Position, root.Position + Vector3.new(0, 0, -1))
                    * CFrame.Angles(0, math.rad(yaw), 0)
            end
            Library:GiveSignal(AddFrameTask(FrameScheduler.heartbeat, UpdateAntiAim))
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
        local function CreateRageFireHelpers(context)
            local function ValidateShot(shot)
                if context.isInjecting()
                    or not shot.target
                    or not shot.target.Parent
                    or not context.isSilentActive()
                    or not context.canFire()
                then
                    return false
                end
                if context.hasShield(shot.target:FindFirstAncestorOfClass('Model') or shot.target.Parent) then
                    return false
                end
                if not shot.gunName or not shot.characterGun then
                    shot.gunName, shot.characterGun, shot.gunData = context.getGunContext()
                end
                return shot.gunName and shot.characterGun and context.hasAmmo(shot.gunData) or false
            end
            local function ResolveResources(shot)
                shot.events = shot.events or context.getEvents()
                shot.hitParl = shot.events and shot.events:FindFirstChild('HitParl')
                if not shot.hitParl then
                    shot.hitParl = context.replicatedStorage:FindFirstChild('Events')
                    shot.hitParl = shot.hitParl and shot.hitParl:FindFirstChild('HitParl')
                end
                shot.camera = context.getCamera()
                return shot.hitParl and shot.hitParl:IsA('RemoteEvent') and shot.camera ~= nil
            end
            local function PrepareGeometry(shot)
                shot.hitPosition = typeof(shot.aimPoint) == 'Vector3' and shot.aimPoint or shot.target.Position
                shot.cameraPosition = shot.camera.CFrame.Position
                shot.direction = shot.hitPosition - shot.cameraPosition
                shot.distance = shot.direction.Magnitude
                if shot.distance < 0.001 then
                    return false
                end
                shot.direction = shot.direction / shot.distance
                shot.range = 4096
                if shot.gunData then
                    local rangeValue = shot.gunData:FindFirstChild('Range')
                    if rangeValue and type(rangeValue.Value) == 'number' and rangeValue.Value > 0 then
                        shot.range = rangeValue.Value
                    end
                end
                if shot.gunData and shot.gunData:FindFirstChild('Melee') then
                    shot.range = math.clamp(shot.range > 0 and shot.range or 64, 1, 64)
                    if shot.distance > shot.range then
                        return false
                    end
                end
                shot.walls = context.target.walls
                shot.maxWalls = context.maxWalls()
                if shot.walls > shot.maxWalls then
                    return false
                end
                shot.damageMod = 1
                if not context.isPenModeRage() then
                    shot.damageMod = type(context.target.damageMod) == 'number'
                        and math.clamp(context.target.damageMod, 0, 1) or 1
                end
                return context.meetsMinDamageMod(shot.damageMod)
            end
            local function PrepareState(shot)
                shot.flashed, shot.noScope, shot.smoke, shot.airborne = context.shotFlags(
                    shot.gunData,
                    shot.cameraPosition,
                    shot.hitPosition
                )
                if shot.smoke then
                    return false
                end
                shot.consumed, shot.ammoTable, shot.ammoKey = context.consumeAmmo(shot.gunData)
                return shot.consumed == true
            end
            local function PrepareShot(target, aimPoint, gunName, characterGun, gunData, events)
                local shot = {
                    target = target,
                    aimPoint = aimPoint,
                    gunName = gunName,
                    characterGun = characterGun,
                    gunData = gunData,
                    events = events,
                }
                if not ValidateShot(shot)
                    or not ResolveResources(shot)
                    or not PrepareGeometry(shot)
                    or not PrepareState(shot)
                then
                    return false
                end
                return shot
            end
            local function SendShot(shot)
                shot.position = { X = 0 / 0, Y = 0 / 0, Z = 0 / 0 }
                shot.serverTime = workspace:GetServerTimeNow()
                shot.previousRageHandler = context.getHitHandler()
                context.setHitHandler(nil)
                context.setInjecting(true)
                shot.fired = pcall(function()
                    shot.hitParl:FireServer(
                        shot.target,
                        shot.position,
                        shot.gunName,
                        shot.range,
                        shot.characterGun,
                        nil,
                        shot.damageMod,
                        shot.range == 48,
                        shot.walls > 0,
                        shot.cameraPosition,
                        shot.serverTime,
                        shot.direction,
                        shot.flashed,
                        shot.noScope,
                        shot.smoke,
                        shot.airborne,
                        true,
                        nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil
                    )
                end)
                context.setInjecting(false)
                context.setHitHandler(shot.previousRageHandler)
                if not shot.fired then
                    context.refundAmmo(shot.ammoTable, shot.ammoKey)
                end
                return shot.fired
            end
            return {
                FireHit = function(target, aimPoint, gunName, characterGun, gunData, events)
                    local shot = PrepareShot(target, aimPoint, gunName, characterGun, gunData, events)
                    if type(shot) ~= 'table' then
                        return false
                    end
                    return SendShot(shot)
                end,
            }
        end
        local function InitRageFeature()
        do
            local RageHitboxOrder = { 'Head', 'Body', 'Arms', 'Legs' }
            local RageHitboxParts = {
                Head = { 'HeadHB' },
                Body = { 'UpperTorso', 'LowerTorso' },
                Arms = {
                    'LeftUpperArm', 'LeftLowerArm', 'LeftHand',
                    'RightUpperArm', 'RightLowerArm', 'RightHand',
                },
                Legs = {
                    'LeftUpperLeg', 'LeftLowerLeg', 'LeftFoot',
                    'RightUpperLeg', 'RightLowerLeg', 'RightFoot',
                },
            }
            local RageEnemyIgnore = {
                HumanoidRootPart = true,
                Gun = true,
                Head = true,
                FakeHead = true,
                BackC4 = true,
                Hitboxes = true,
            }
            local RageEnemyIgnoreNames = {
                'HumanoidRootPart', 'Gun', 'Head', 'FakeHead', 'BackC4', 'Hitboxes',
            }
            for i = 1, 15 do
                local name = 'Hat' .. i
                RageEnemyIgnore[name] = true
                RageEnemyIgnoreNames[#RageEnemyIgnoreNames + 1] = name
            end
            local RageRayParams = RaycastParams.new()
            RageRayParams.FilterType = Enum.RaycastFilterType.Exclude
            RageRayParams.IgnoreWater = true
            local RageRayIgnore = {}
            local RageRayIgnoreSet = {}
            local RageRayIgnoreCount = 0
            local RageFrameState = { teamPlayers = {} }
            local RagePartCache = setmetatable({}, { __mode = 'k' })
            local RageIgnorePartsCache = setmetatable({}, { __mode = 'k' })
            local RageWallCache = setmetatable({}, { __mode = 'k' })
            ScriptEnvironment.__ValenokRagePartCache = RagePartCache
            ScriptEnvironment.__ValenokRageIgnorePartsCache = RageIgnorePartsCache
            local RageSmokeRayParams = RaycastParams.new()
            RageSmokeRayParams.FilterType = Enum.RaycastFilterType.Include
            local RageSmokeInclude = {}
            local RageTarget = { part = nil, point = nil, walls = math.huge, damageMod = 1 }
            local RageSilentActive = false
            local RageInjecting = false
            local RageLastFire = 0
            local function RageResetTarget()
                RageTarget.part, RageTarget.point = nil, nil
                RageTarget.walls, RageTarget.damageMod = math.huge, 1
            end
            local RageFireRate = 0.1
            local RageHeartbeat
            local RageFovConnection
            local RageFovCircle
            local RageFovViewportX = -1
            local RageFovViewportY = -1
            local RageKillAllRemote
            local RageKillAllLastRun = 0
            local RageKillAllPosition = { X = 0 / 0, Y = 0 / 0, Z = 0 / 0 }
            local RageKillAllDirection = Vector3.new(0, 1, 0)
            local function RageCamera()
                return workspace.CurrentCamera
            end
            local function RageGetVisibleOrigin(camera, character)
                camera = camera or RageCamera()
                character = character or LocalPlayer.Character
                local option = Options.RageBot_StartPoint
                local value = option and option.Value
                if type(value) == 'table' then
                    value = value.Character and 'Character' or value[1]
                end
                if tostring(value) == 'Character' then
                    local head = character and (
                        character:FindFirstChild('Head')
                        or character:FindFirstChild('HeadHB')
                        or character:FindFirstChild('HumanoidRootPart')
                    )
                    if head and head:IsA('BasePart') then
                        return head.Position
                    end
                end
                return camera and camera.CFrame.Position or nil
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
                local env = GetClientEnv()
                local equipped = character and character:FindFirstChild('EquippedTool')
                local gun = env and (rawget(env, 'fgun') or rawget(env, 'gun'))
                if typeof(gun) ~= 'Instance' then
                    gun = character and character:FindFirstChild('Gun')
                end
                local directPenetration = gun and gun:FindFirstChild('Penetration')
                if directPenetration and type(directPenetration.Value) == 'number' then
                    return math.max(directPenetration.Value, 0) * 0.01
                end
                local gunName = equipped and type(equipped.Value) == 'string' and equipped.Value ~= '' and equipped.Value
                    or (gun and gun.Name)
                local weapons = gunName and GetWeaponsFolder()
                local gunData = weapons and weapons:FindFirstChild(gunName)
                local copyFrom = gunData and gunData:FindFirstChild('CopyFrom')
                if copyFrom then
                    local reference = copyFrom.Value
                    if typeof(reference) == 'Instance' then
                        gunData = reference
                    elseif type(reference) == 'string' and reference ~= '' and weapons then
                        gunData = weapons:FindFirstChild(reference) or gunData
                    end
                end
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
                keepCount = math.max(0, math.min(keepCount or 0, RageRayIgnoreCount))
                for i = keepCount + 1, RageRayIgnoreCount do
                    RageRayIgnoreSet[RageRayIgnore[i]] = nil
                    RageRayIgnore[i] = nil
                end
                RageRayIgnoreCount = keepCount
            end
            local function RageAddRayIgnore(instance)
                if instance and not RageRayIgnoreSet[instance] then
                    RageRayIgnoreCount = RageRayIgnoreCount + 1
                    RageRayIgnore[RageRayIgnoreCount] = instance
                    RageRayIgnoreSet[instance] = true
                end
            end
            local function RageAddPiercedIgnore(instance)
                if not instance then
                    return
                end
                local parent = instance.Parent
                local grandParent = parent and parent.Parent
                local addParent = parent and (
                    parent.Name == 'Hitboxes'
                    or (grandParent and grandParent:FindFirstChild('Humanoid2'))
                    or parent:FindFirstChild('Humanoid2')
                    or (parent:FindFirstChildOfClass('Humanoid')
                        and instance.Transparency < 1
                        and parent:IsA('Model'))
                )
                RageAddRayIgnore(addParent and parent or instance)
            end
            local function RageAddLocalPlayerRayIgnore()
                local camera = RageCamera()
                local character = LocalPlayer.Character
                RageAddRayIgnore(camera)
                if camera then
                    RageAddRayIgnore(camera:FindFirstChild('Arms'))
                    RageAddRayIgnore(camera:FindFirstChild('Debris'))
                    RageAddRayIgnore(camera:FindFirstChild('GUI'))
                end
                RageAddRayIgnore(character)
                if character then
                    RageAddRayIgnore(character:FindFirstChild('Gun'))
                    RageAddRayIgnore(character:FindFirstChild('Gun2'))
                    RageAddRayIgnore(character:FindFirstChild('Knife'))
                    RageAddRayIgnore(character:FindFirstChild('BackC4'))
                    RageAddRayIgnore(character:FindFirstChild('Hitboxes'))
                    RageAddRayIgnore(character:FindFirstChild('FakeHead'))
                    RageAddRayIgnore(character:FindFirstChild('HeadHB'))
                    for _, child in ipairs(character:GetChildren()) do
                        if child:IsA('Accessory')
                            or child:IsA('Hat')
                            or child:IsA('Tool')
                            or child:IsA('Model')
                            or child.Name:find('Valenok', 1, true) == 1
                        then
                            RageAddRayIgnore(child)
                        end
                    end
                end
            end
            local function RageBuildFrameState(camera)
                local frame = RageFrameState
                table.clear(RageWallCache)
                local cameraCFrame = camera.CFrame
                local selectedHitboxes = Options.RageBot_Hitbox.Value
                local localStatus = LocalPlayer:FindFirstChild('Status')
                frame.camera = camera
                frame.active = true
                frame.origin = cameraCFrame.Position
                frame.rayOrigin = RageGetVisibleOrigin(camera, LocalPlayer.Character) or cameraCFrame.Position
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
                frame.gunRange = nil
                do
                    local character = LocalPlayer.Character
                    local env = GetClientEnv()
                    local equipped = character and character:FindFirstChild('EquippedTool')
                    local gun = env and (rawget(env, 'fgun') or rawget(env, 'gun'))
                    if typeof(gun) ~= 'Instance' then
                        gun = character and character:FindFirstChild('Gun')
                    end
                    local directRange = gun and gun:FindFirstChild('Range')
                    if directRange and type(directRange.Value) == 'number' then
                        frame.gunRange = math.clamp(directRange.Value, 1, 100)
                    end
                    local gunName = equipped and type(equipped.Value) == 'string' and equipped.Value ~= '' and equipped.Value
                        or (gun and gun.Name)
                    local weapons = gunName and GetWeaponsFolder()
                    local gunData = weapons and weapons:FindFirstChild(gunName)
                    local rangeValue = gunData and gunData:FindFirstChild('Range')
                    if not frame.gunRange then
                        frame.gunRange = rangeValue and type(rangeValue.Value) == 'number' and rangeValue.Value > 0 and math.clamp(rangeValue.Value, 1, 100) or 64
                    end
                end
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
                RageAddLocalPlayerRayIgnore()
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
            local function RageGetPenetrationThickness(instance, hitPosition, direction, range)
                local scale = (type(range) == 'number' and range > 0 and range or 64) * 0.0625
                local step = direction.Unit * scale
                RagePenetrationInclude[1] = instance
                RagePenetrationParams.FilterDescendantsInstances = RagePenetrationInclude
                local result = workspace:Raycast(hitPosition + step, step * -2, RagePenetrationParams)
                RagePenetrationInclude[1] = nil
                if result then
                    return (result.Position - hitPosition).Magnitude
                end
                return scale
            end
            local function RageFinishWallRay(frame)
                RageClearRayIgnore(frame.baseIgnoreCount)
                RageRayParams.FilterDescendantsInstances = RageRayIgnore
            end
            local function RageGetWallCount(frame, targetPosition, targetCharacter, targetPart)
                local cached = RageWallCache[targetPart]
                if cached and cached.position == targetPosition then
                    return cached.walls, cached.damageMod
                end
                local originPosition = frame.rayOrigin or frame.origin
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
                local reachedTarget = false
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
                    if frame.localCharacter and instance:IsDescendantOf(frame.localCharacter) then
                        RageAddRayIgnore(instance)
                        RageRayParams.FilterDescendantsInstances = RageRayIgnore
                        origin = result.Position + direction * 0.05
                        continue
                    end
                    local camera = frame.camera
                    if camera and instance:IsDescendantOf(camera) then
                        RageAddRayIgnore(instance)
                        RageRayParams.FilterDescendantsInstances = RageRayIgnore
                        origin = result.Position + direction * 0.05
                        continue
                    end
                    if instance == targetPart then
                        reachedTarget = true
                        break
                    end
                    if targetCharacter and instance:IsDescendantOf(targetCharacter) then
                        wallCount = maxWalls + 1
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
                            local thickness = RageGetPenetrationThickness(
                                instance,
                                result.Position,
                                direction,
                                frame.gunRange
                            )
                            penetrationUsed = penetrationUsed + thickness * factor
                            if penetrationBudget <= 0 then
                                wallCount = maxWalls + 1
                                break
                            end
                            if penetrationUsed >= penetrationBudget then
                                wallCount = maxWalls + 1
                                break
                            end
                            damageMod = 1 - penetrationUsed / penetrationBudget
                            if damageMod <= 0 then
                                wallCount = maxWalls + 1
                                break
                            end
                        end
                    end
                    RageAddPiercedIgnore(instance)
                    RageRayParams.FilterDescendantsInstances = RageRayIgnore
                    origin = result.Position + direction * 0.05
                end
                RageFinishWallRay(frame)
                if not reachedTarget then
                    RageWallCache[targetPart] = {
                        position = targetPosition,
                        walls = maxWalls + 1,
                        damageMod = 0,
                    }
                    return maxWalls + 1, 0
                end
                local finalDamageMod = penModeRage and 1 or math.clamp(damageMod, 0, 1)
                RageWallCache[targetPart] = {
                    position = targetPosition,
                    walls = wallCount,
                    damageMod = finalDamageMod,
                }
                return wallCount, finalDamageMod
            end
            local function RageGetMinDamageMod()
                if not Toggles.RageBot_MinDamage_Enable.Value then
                    return 0
                end
                return math.clamp(tonumber(Options.RageBot_MinDamage.Value) or 0.1, 0.1, 1)
            end
            local function RageMeetsMinDamageMod(damageMod)
                local mod = type(damageMod) == 'number' and damageMod or 1
                return mod >= RageGetMinDamageMod()
            end
            local function RageIsBetterCandidate(damageMod, walls, dot, bestDamageMod, bestWalls, bestDot)
                return damageMod > bestDamageMod
                    or (damageMod == bestDamageMod and walls < bestWalls)
                    or (damageMod == bestDamageMod and walls == bestWalls and dot > bestDot)
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
            local function RagePickGroupHitbox(frame, character, group)
                local names = RageHitboxParts[group]
                local bestPart, bestPoint, bestWalls, bestDot, bestDamageMod =
                    nil, nil, math.huge, -math.huge, 0
                for i = 1, #names do
                    local part = RageGetCachedPart(character, names[i])
                    if not part or not part:IsA('BasePart') then
                        continue
                    end
                    local point = part.Position
                    local dot = RageGetAimDot(point, frame.origin, frame.lookVector)
                    if not dot or dot < frame.minimumDot then
                        continue
                    end
                    local walls, damageMod = RageGetWallCount(frame, point, character, part)
                    if walls <= frame.maxWalls and RageMeetsMinDamageMod(damageMod) then
                        if RageIsBetterCandidate(
                            damageMod, walls, dot, bestDamageMod, bestWalls, bestDot
                        ) then
                            bestPart, bestPoint, bestWalls, bestDot, bestDamageMod =
                                part, point, walls, dot, damageMod
                        end
                    end
                end
                return bestPart, bestPoint, bestWalls, bestDot, bestDamageMod
            end
            local function RageScanTargets(frame)
                for groupIndex = 1, #RageHitboxOrder do
                    local group = RageHitboxOrder[groupIndex]
                    if not RageIsHitboxEnabled(frame, group) then
                        continue
                    end
                    local bestPart, bestPoint, bestWalls, bestDot, bestDamageMod =
                        nil, nil, math.huge, -math.huge, 0
                    for playerIndex = 1, #PlayerSnapshot do
                        local player = PlayerSnapshot[playerIndex]
                        if not RageIsEnemy(player, frame) then
                            continue
                        end
                        local character = player.Character
                        local humanoid = character and character:FindFirstChildOfClass('Humanoid')
                        local root = character and character:FindFirstChild('HumanoidRootPart')
                        if not character or not humanoid or humanoid.Health <= 0
                            or not root or RageHasShield(character)
                        then
                            continue
                        end
                        local part, point, walls, dot, damageMod =
                            RagePickGroupHitbox(frame, character, group)
                        if part and point and walls <= frame.maxWalls and dot
                            and RageIsBetterCandidate(
                                damageMod, walls, dot, bestDamageMod, bestWalls, bestDot
                            )
                        then
                            bestPart, bestPoint, bestWalls, bestDot, bestDamageMod =
                                part, point, walls, dot, damageMod
                        end
                    end
                    if bestPart then
                        RageTarget.part, RageTarget.point, RageTarget.walls, RageTarget.damageMod =
                            bestPart, bestPoint, bestWalls, bestDamageMod
                        return
                    end
                end
            end
            local function RageGetGunContext()
                local character = LocalPlayer.Character
                local gun = character and character:FindFirstChild('Gun')
                local equipped = character and character:FindFirstChild('EquippedTool')
                if not gun then
                    return nil, nil, nil, 0.1
                end
                local gunName = equipped and type(equipped.Value) == 'string' and equipped.Value ~= '' and equipped.Value or gun.Name
                local weapons = GetWeaponsFolder()
                local gunData = weapons and weapons:FindFirstChild(gunName)
                local fireRate = gunData and gunData:FindFirstChild('FireRate')
                local rate = fireRate and fireRate:IsA('NumberValue') and fireRate.Value > 0 and fireRate.Value or 0.1
                return gunName, gun, gunData, rate
            end
            local RageAmmoTable
            local RageClientEnv
            local RageClientScript
            local RageClientEnvResolved = false
            local RageNextGcScan = 0
            local function RageIsAmmoTable(obj)
                if type(obj) ~= 'table' then
                    return false
                end
                return type(rawget(obj, 'ammocount')) == 'number'
                    and type(rawget(obj, 'ammocount2')) == 'number'
                    and type(rawget(obj, 'ammocount3')) == 'number'
                    and type(rawget(obj, 'ammocount4')) == 'number'
                    and rawget(obj, 'DISABLED') ~= nil
                    and rawget(obj, 'reloading') ~= nil
            end
            local function RageGetClientEnv()
                local playerGui = LocalPlayer:FindFirstChild('PlayerGui')
                local client = playerGui and playerGui:FindFirstChild('Client')
                if client ~= RageClientScript then
                    RageClientScript = client
                    RageClientEnv = nil
                    RageAmmoTable = nil
                    RageClientEnvResolved = false
                    RageNextGcScan = 0
                end
                if RageClientEnvResolved then
                    return RageClientEnv
                end
                RageClientEnvResolved = true
                if not client or type(getsenv) ~= 'function' then
                    return nil
                end
                local ok, env = pcall(getsenv, client)
                RageClientEnv = ok and env or nil
                return RageClientEnv
            end
            local function RageGetAmmoTable()
                if RageAmmoTable and RageIsAmmoTable(RageAmmoTable) then
                    return RageAmmoTable
                end
                local client = RageGetClientEnv()
                if type(client) == 'table' then
                    if RageIsAmmoTable(client) then
                        RageAmmoTable = client
                        return RageAmmoTable
                    end
                    for _, obj in pairs(client) do
                        if RageIsAmmoTable(obj) then
                            RageAmmoTable = obj
                            return RageAmmoTable
                        end
                    end
                    if debug and type(debug.getupvalue) == 'function' then
                        local names = { 'usethatgun', 'loadammo', 'isgrenade', 'countammo', 'firebullet' }
                        for i = 1, #names do
                            local fn = rawget(client, names[i])
                            if type(fn) == 'function' then
                                local ok, found = pcall(function()
                                    for ui = 1, 64 do
                                        local _, val = debug.getupvalue(fn, ui)
                                        if RageIsAmmoTable(val) then
                                            return val
                                        end
                                    end
                                    return nil
                                end)
                                if ok and found then
                                    RageAmmoTable = found
                                    return RageAmmoTable
                                end
                            end
                        end
                    end
                end
                local now = os.clock()
                if type(getgc) == 'function' and now >= RageNextGcScan then
                    RageNextGcScan = now + 30
                    local ok, objects = pcall(getgc, true)
                    if ok and type(objects) == 'table' then
                        local found
                        for _, obj in ipairs(objects) do
                            if RageIsAmmoTable(obj) then
                                found = obj
                                break
                            end
                        end
                        table.clear(objects)
                        if found then
                            RageAmmoTable = found
                            return RageAmmoTable
                        end
                    end
                end
                return nil
            end
            local function RageGetEquippedSlot(ammo)
                local client = RageGetClientEnv()
                if type(client) == 'table' then
                    local equipped = rawget(client, 'equipped')
                    if type(equipped) == 'string' and equipped ~= '' and equipped ~= 'none' then
                        return equipped
                    end
                end
                if type(ammo) == 'table' then
                    local equipped = rawget(ammo, 'equipped')
                    if type(equipped) == 'string' and equipped ~= '' and equipped ~= 'none' then
                        return equipped
                    end
                end
                return nil
            end
            local function RageGetAmmoKey(slot)
                if slot == 'primary' then
                    return 'ammocount'
                end
                if slot == 'secondary' then
                    return 'ammocount2'
                end
                if slot == 'equipment' then
                    return 'ammocount3'
                end
                if slot == 'equipment2' then
                    return 'ammocount4'
                end
                return nil
            end
            local function RageHasAmmo(gunData)
                if gunData and gunData:FindFirstChild('Melee') then
                    return true
                end
                local ammo = RageGetAmmoTable()
                if not ammo then
                    return false
                end
                local key = RageGetAmmoKey(RageGetEquippedSlot(ammo))
                if key then
                    return (tonumber(ammo[key]) or 0) > 0
                end
                return (tonumber(ammo.ammocount) or 0) > 0
                    or (tonumber(ammo.ammocount2) or 0) > 0
                    or (tonumber(ammo.ammocount3) or 0) > 0
                    or (tonumber(ammo.ammocount4) or 0) > 0
            end
            local RageRefreshAmmo
            local function RageConsumeAmmo(gunData)
                if gunData and gunData:FindFirstChild('Melee') then
                    return true, nil, nil
                end
                local ammo = RageGetAmmoTable()
                if not ammo then
                    return false, nil, nil
                end
                local key = RageGetAmmoKey(RageGetEquippedSlot(ammo))
                if not key then
                    if (tonumber(ammo.ammocount) or 0) > 0 then
                        key = 'ammocount'
                    elseif (tonumber(ammo.ammocount2) or 0) > 0 then
                        key = 'ammocount2'
                    elseif (tonumber(ammo.ammocount3) or 0) > 0 then
                        key = 'ammocount3'
                    elseif (tonumber(ammo.ammocount4) or 0) > 0 then
                        key = 'ammocount4'
                    else
                        return false, nil, nil
                    end
                end
                local current = tonumber(ammo[key]) or 0
                if current <= 0 then
                    return false, nil, nil
                end
                ammo[key] = current - 1
                RageRefreshAmmo()
                return true, ammo, key
            end
            local function RageRefundAmmo(ammo, key)
                if ammo and key then
                    ammo[key] = (tonumber(ammo[key]) or 0) + 1
                    RageRefreshAmmo()
                end
            end
            local RageCountAmmo
            local RageCountAmmoScanAt = 0
            RageRefreshAmmo = function()
                local now = os.clock()
                if type(RageCountAmmo) ~= 'function' and now >= RageCountAmmoScanAt
                    and type(getgc) == 'function'
                    and debug and type(debug.getinfo) == 'function'
                then
                    RageCountAmmoScanAt = now + 30
                    local ok, objects = pcall(getgc, true)
                    if ok and type(objects) == 'table' then
                        for i = 1, #objects do
                            local object = objects[i]
                            if type(object) == 'function' then
                                local info = debug.getinfo(object)
                                if info and info.name == 'countammo' then
                                    RageCountAmmo = object
                                    break
                                end
                            end
                        end
                        table.clear(objects)
                    end
                end
                if type(RageCountAmmo) == 'function' then
                    pcall(RageCountAmmo)
                end
            end
            local function RageShotFlags(gunData, cameraPosition, hitPosition)
                local playerGui = LocalPlayer:FindFirstChild('PlayerGui')
                local blind = playerGui and playerGui:FindFirstChild('Blnd')
                blind = blind and blind:FindFirstChild('Blind')
                local flashed = blind and blind.BackgroundTransparency < 0.4 or false
                local noScope = false
                if gunData and gunData:FindFirstChild('snipo') then
                    local character = LocalPlayer.Character
                    noScope = not (character and character:FindFirstChild('AIMING'))
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
                local walls = RageTarget.walls
                local maxWalls = RageMaxWalls()
                if walls > maxWalls then
                    return args
                end
                local damageMod = 1
                if RageIsPenModeRage() then
                    damageMod = 1
                else
                    damageMod = type(RageTarget.damageMod) == 'number' and math.clamp(RageTarget.damageMod, 0, 1) or 1
                end
                if not RageMeetsMinDamageMod(damageMod) then
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
                    local cameraPosition = camera and camera.CFrame.Position
                    if cameraPosition and (hitPosition - cameraPosition).Magnitude > meleeRange then
                        return args
                    end
                    args[4] = meleeRange
                end
                args[1] = target
                args[2] = { X = 0 / 0, Y = 0 / 0, Z = 0 / 0 }
                if type(args[4]) ~= 'number' or args[4] <= 0 then
                    args[4] = 4096
                end
                args[7] = damageMod
                args[9] = walls > 0
                local camera = RageCamera()
                local cameraPosition = typeof(args[10]) == 'Vector3' and args[10]
                    or (camera and camera.CFrame.Position)
                if typeof(cameraPosition) == 'Vector3' then
                    args[10] = cameraPosition
                    local direction = hitPosition - cameraPosition
                    if direction.Magnitude > 0.001 then
                        args[12] = direction.Unit
                    end
                end
                return args
            end
            HandleRageHitParl = nil
            local RageFireHelpers = CreateRageFireHelpers({
                isInjecting = function() return RageInjecting end,
                setInjecting = function(value) RageInjecting = value end,
                isSilentActive = function() return RageSilentActive end,
                canFire = RageCanFire,
                hasShield = RageHasShield,
                getGunContext = RageGetGunContext,
                hasAmmo = RageHasAmmo,
                getEvents = GetEventsFolder,
                replicatedStorage = ReplicatedStorage,
                getCamera = RageCamera,
                target = RageTarget,
                maxWalls = RageMaxWalls,
                isPenModeRage = RageIsPenModeRage,
                meetsMinDamageMod = RageMeetsMinDamageMod,
                shotFlags = RageShotFlags,
                consumeAmmo = RageConsumeAmmo,
                refundAmmo = RageRefundAmmo,
                getHitHandler = function() return HandleRageHitParl end,
                setHitHandler = function(value) HandleRageHitParl = value end,
            })
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
                if not RageKillAllActive() or not RageCanFire() then return end
                local now = os.clock()
                if now - RageKillAllLastRun < 0.006 then return end
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
                    local head = targetCharacter and targetCharacter:FindFirstChild('HeadHB')
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
            local function RageUpdate()
                RageResetTarget()
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
                if RageFireHelpers.FireHit(target, point, gunName, characterGun, gunData, GetEventsFolder()) then
                    RageLastFire = now
                end
            end
            Environment.__ValenokRageMakeFovCircle = function()
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
            Environment.__ValenokRageGetFovRadius = function(camera)
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
            Environment.__ValenokRageUpdateFov = function(camera)
                local show = Toggles.RageBot_Enable.Value and Toggles.RageBot_ShowFov.Value
                if not show then
                    if RageFovCircle then
                        RageFovCircle.Visible = false
                    end
                    return
                end
                if not RageFovCircle then
                    RageFovCircle = Environment.__ValenokRageMakeFovCircle()
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
                RageFovCircle.Radius = math.min(Environment.__ValenokRageGetFovRadius(camera), 100000)
                RageFovCircle.Visible = true
            end
            Library:GiveSignal(PlayersService.PlayerRemoving:Connect(function(player)
                if ScriptEnvironment.__ValenokRageRemoveCharacterConnection then
                    ScriptEnvironment.__ValenokRageRemoveCharacterConnection(player)
                end
                local character = player.Character
                if character then
                    RagePartCache[character] = nil
                    RageIgnorePartsCache[character] = nil
                end
                RageFrameState.teamPlayers[player] = nil
            end))
            pcall(function()
                for i = 1, #PlayerSnapshot do
                    if ScriptEnvironment.__ValenokRageBindCharacterConnection then
                        ScriptEnvironment.__ValenokRageBindCharacterConnection(PlayerSnapshot[i])
                    end
                end
            end)
            Library:GiveSignal(PlayersService.PlayerAdded:Connect(function(player)
                if ScriptEnvironment.__ValenokRageBindCharacterConnection then
                    ScriptEnvironment.__ValenokRageBindCharacterConnection(player)
                end
            end))
            RageHeartbeat = AddFrameTask(FrameScheduler.heartbeat, RageUpdate)
            RageFovConnection = AddFrameTask(FrameScheduler.render, function()
                if not ToggleEnabled('RageBot_Enable') or not ToggleEnabled('RageBot_ShowFov') then
                    if RageFovCircle then
                        RageFovCircle.Visible = false
                    end
                    return
                end
                local camera = RageCamera()
                if camera then
                    Environment.__ValenokRageUpdateFov(camera)
                elseif RageFovCircle then
                    RageFovCircle.Visible = false
                end
            end)
            Library:GiveSignal(RageHeartbeat)
            Library:GiveSignal(RageFovConnection)
            AddUnload(function()
                HandleRageHitParl = nil
                ScriptEnvironment.__ValenokRageCharacterCleanup = nil
                ScriptEnvironment.__ValenokRagePartCache = nil
                ScriptEnvironment.__ValenokRageIgnorePartsCache = nil
                if ScriptEnvironment.__ValenokRageClearCharacterConnections then
                    ScriptEnvironment.__ValenokRageClearCharacterConnections()
                end
                ScriptEnvironment.__ValenokRageRemoveCharacterConnection = nil
                ScriptEnvironment.__ValenokRageBindCharacterConnection = nil
                ScriptEnvironment.__ValenokRageClearCharacterConnections = nil
                RageSilentActive = false
                RageInjecting = false
                RageResetTarget()
                RageClearRayIgnore(0)
                RageClearFrameState()
                RageSmokeInclude[1] = nil
                table.clear(RagePartCache)
                table.clear(RageIgnorePartsCache)
                table.clear(RageRayIgnore)
                table.clear(RageRayIgnoreSet)
                table.clear(RageFrameState.teamPlayers)
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
                Environment.__ValenokRageMakeFovCircle = nil
                Environment.__ValenokRageGetFovRadius = nil
                Environment.__ValenokRageUpdateFov = nil
            end)
        end
        end
        InitRageFeature()
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
                kickBlockUntil = 0,
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
                local env = GetClientEnv()
                if env ~= State.clientEnv then
                    State.clientEnv = env
                    State.ammoTable = nil
                end
                return env
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
                if getgc and now - State.lastGcScan >= 30 then
                    State.lastGcScan = now
                    local ok, objects = pcall(getgc, true)
                    if ok and type(objects) == 'table' then
                        local found
                        for _, obj in ipairs(objects) do
                            if isAmmoTable(obj) then
                                found = obj
                                break
                            end
                        end
                        table.clear(objects)
                        if found then
                            return found
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
                    return false
                end
                if type(State.originalAmmo) == 'table' then
                    for key, value in pairs(State.originalAmmo) do
                        local stored = string.find(key, 'stored', 1, true) ~= nil
                        local limit = stored and 999 or 150
                        if type(value) == 'number' and value >= 0 and value <= limit then
                            t[key] = value
                        end
                    end
                    State.originalAmmo = nil
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
                return true
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
            local function isKickPacket(first)
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
            local InfAmmoNamecallHandler = function(self, method, ...)
                if method ~= 'FireServer' and method ~= 'FireUnreliable' then
                    return false
                end
                local name = typeof(self) == 'Instance' and self.Name or nil
                if name == 'FallDamage' then
                    return Toggles.RageExploit_NoFallDamage.Value
                end
                if name == 'ohnoflames' then
                    return Toggles.RageExploit_NoFireDamage.Value
                end
                if name == 'ParticleRemote'
                    and (Toggles.RageExploit_InfAmmo.Value or os.clock() < State.kickBlockUntil)
                then
                    local first = ...
                    return isKickPacket(first)
                end
                return false
            end
            HandleInfAmmoNamecall = InfAmmoNamecallHandler
            Toggles.RageExploit_InfAmmo:OnChanged(function(enabled)
                if enabled then
                    State.kickBlockUntil = 0
                    State.ammoTable = nil
                    State.lastGcScan = 0
                    State.originalAmmo = nil
                    State.scanBackoff = 0.5
                    requestScan(true)
                    task.defer(applyAmmo)
                else
                    State.kickBlockUntil = os.clock() + 2
                    local restored = false
                    pcall(function() restored = restoreAmmoSafe() end)
                    if not restored then
                        task.spawn(function()
                            local deadline = os.clock() + 1.8
                            while os.clock() < deadline and not restoreAmmoSafe() do
                                task.wait(0.1)
                            end
                        end)
                    end
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
            State.heartbeat = AddFrameTask(FrameScheduler.heartbeat, function()
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
                pcall(restoreAmmoSafe)
                State.ammoTable = nil
                State.originalAmmo = nil
                State.clientScript = nil
                State.clientEnv = nil
                State.scanning = false
                if HandleInfAmmoNamecall == InfAmmoNamecallHandler then
                    HandleInfAmmoNamecall = nil
                end
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
        local GunMods = RageTab:AddRightGroupbox('GunMods')
        GunMods:AddToggle('GunMods_RemoveSpread', { Text = 'Remove spread', Default = false })
        GunMods:AddToggle('GunMods_RemoveRecoil', { Text = 'Remove recoil', Default = false })
        GunMods:AddToggle('GunMods_InfRange', { Text = 'Inf range', Default = false })
        GunMods:AddSlider('GunMods_RecoilValue', {
            Text = 'Recoil value',
            Default = 100,
            Min = 0,
            Max = 100,
            Rounding = 0,
            Suffix = '%',
        })
        GunMods:AddToggle('GunMods_RapidFire', { Text = 'RapidFire', Default = false })
        GunMods:AddSlider('GunMods_RapidFireRate', {
            Text = 'RapidFire multiplier',
            Default = 1,
            Min = 1,
            Max = 10,
            Rounding = 0,
        })
        GunMods:AddToggle('GunMods_FastEquip', { Text = 'Fast equip', Default = false })
        GunMods:AddToggle('GunMods_FastReload', { Text = 'Fast reload', Default = false })
        GunMods:AddToggle('GunMods_FullAuto', { Text = 'FullAuto', Default = false })
        local HitLog = RageTab:AddRightGroupbox('Hit Sound')
        local HitLogDisplay = RageTab:AddRightGroupbox('Hit Log')
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
        HitLogDisplay:AddLabel('Hit color'):AddColorPicker('HitLog_HitColor', {
            Default = Color3.fromRGB(80, 255, 120), Transparency = 0,
        })
        HitLogDisplay:AddLabel('Miss color'):AddColorPicker('HitLog_MissColor', {
            Default = Color3.fromRGB(255, 90, 90), Transparency = 0,
        })
        if HitLogControlsReady then
            HitLogControlsReady()
        end
        do
            local SavedValues = {
                Recoil = setmetatable({}, { __mode = 'k' }),
                Range = setmetatable({}, { __mode = 'k' }),
                FireRate = setmetatable({}, { __mode = 'k' }),
                EquipTime = setmetatable({}, { __mode = 'k' }),
                ReloadTime = setmetatable({}, { __mode = 'k' }),
                Auto = setmetatable({}, { __mode = 'k' }),
            }
            local SavedAccuracySd = nil
            local ClientEnvironment = nil
            local ClientScript = nil
            local WeaponsFolder
            local WeaponsDirty = true
            local WeaponConnections = {}
            local RootConnections = {}
            local ModConnection
            local RapidAmmoTable = nil
            local RecoilRestoreToken = 0
            local WeaponCache = {
                Recoil = {},
                Range = {},
                FireRate = {},
                EquipTime = {},
                ReloadTime = {},
                Auto = {},
            }
            local function GetClientEnvironment()
                local environment = GetClientEnv()
                if environment ~= ClientEnvironment then
                    ClientEnvironment = environment
                    RapidAmmoTable = nil
                end
                return environment
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
                    local range = weapon:FindFirstChild('Range')
                    local fireRate = ResolveFireRate(weapon)
                    local equipTime = weapon:FindFirstChild('EquipTime')
                    local reloadTime = weapon:FindFirstChild('ReloadTime')
                    local auto = weapon:FindFirstChild('Auto')
                    if recoil and recoil:IsA('NumberValue') then
                        WeaponCache.Recoil[#WeaponCache.Recoil + 1] = recoil
                    end
                    if range and (range:IsA('NumberValue') or range:IsA('IntValue')) then
                        WeaponCache.Range[#WeaponCache.Range + 1] = range
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
                RecoilRestoreToken = RecoilRestoreToken + 1
                local token = RecoilRestoreToken
                local restore = {}
                for object, value in pairs(SavedValues.Recoil) do
                    if object and object.Parent then
                        restore[#restore + 1] = { object = object, value = value }
                        pcall(function() object.Value = value end)
                    end
                end
                table.clear(SavedValues.Recoil)
                task.spawn(function()
                    for _ = 1, 3 do
                        task.wait(0.1)
                        if token ~= RecoilRestoreToken or Toggles.GunMods_RemoveRecoil.Value then return end
                        for i = 1, #restore do
                            local item = restore[i]
                            if item.object.Parent then pcall(function() item.object.Value = item.value end) end
                        end
                    end
                end)
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
            local function ApplyMultiplier(object, saved, multiplier)
                if not object or not object.Parent then return end
                if saved[object] == nil then saved[object] = object.Value end
                local original = saved[object]
                if type(original) ~= 'number' then return end
                local value = original / multiplier
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
                    or Toggles.GunMods_InfRange.Value
                    or Toggles.GunMods_RapidFire.Value
                    or Toggles.GunMods_FastEquip.Value
                    or Toggles.GunMods_FastReload.Value
                    or Toggles.GunMods_FullAuto.Value
                if not weaponModsEnabled then return end
                EnsureWeaponCache()
                if Toggles.GunMods_RemoveRecoil.Value then
                    local percent = math.clamp(tonumber(Options.GunMods_RecoilValue.Value) or 100, 0, 100)
                    local factor = 1 - percent / 100
                    for i = 1, #WeaponCache.Recoil do
                        local recoil = WeaponCache.Recoil[i]
                        if recoil and recoil.Parent then
                            if SavedValues.Recoil[recoil] == nil then
                                SavedValues.Recoil[recoil] = recoil.Value
                            end
                            local original = SavedValues.Recoil[recoil]
                            local value = math.max(0.001, original * factor)
                            if recoil.Value ~= value then recoil.Value = value end
                        end
                    end
                end
                if Toggles.GunMods_InfRange.Value then
                    for i = 1, #WeaponCache.Range do
                        ApplyValue(WeaponCache.Range[i], SavedValues.Range, 99999999)
                    end
                end
                if Toggles.GunMods_RapidFire.Value then
                    local multiplier = math.max(1, tonumber(Options.GunMods_RapidFireRate.Value) or 1)
                    for i = 1, #WeaponCache.FireRate do
                        ApplyMultiplier(WeaponCache.FireRate[i], SavedValues.FireRate, multiplier)
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
                if not Toggles.GunMods_RapidFire.Value or Options.GunMods_RapidFireRate.Value <= 1 then
                    return
                end
                local ammo = GetAmmoTable()
                if ammo and not rawget(ammo, 'reloading') and (rawget(ammo, 'Held') or rawget(ammo, 'Held2')) then
                    rawset(ammo, 'DISABLED', false)
                end
            end
            local function ModsEnabled()
                return Toggles.GunMods_RemoveSpread.Value or Toggles.GunMods_RemoveRecoil.Value
                    or Toggles.GunMods_InfRange.Value or Toggles.GunMods_RapidFire.Value
                    or Toggles.GunMods_FastEquip.Value
                    or Toggles.GunMods_FastReload.Value or Toggles.GunMods_FullAuto.Value
            end
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
                    local interval = (Toggles.GunMods_RemoveSpread.Value or Toggles.GunMods_RemoveRecoil.Value) and 0.5 or 10
                    NextWeaponModsApply = os.clock() + interval
                    if not ValuesTickConnection then
                        ValuesTickConnection = RunService.Heartbeat:Connect(function()
                            if not ModsEnabled() then
                                return
                            end
                            local now = os.clock()
                            if now < NextWeaponModsApply then
                                return
                            end
                            local interval = (Toggles.GunMods_RemoveSpread.Value or Toggles.GunMods_RemoveRecoil.Value) and 0.5 or 10
                            NextWeaponModsApply = now + interval
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
                            local multiplier = math.max(1, tonumber(Options.GunMods_RapidFireRate.Value) or 1)
                            nextRapid = now + math.max(1 / 120, 1 / (15 * multiplier))
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
                else
                    RecoilRestoreToken = RecoilRestoreToken + 1
                end
                RefreshModConnection()
            end)
            Toggles.GunMods_InfRange:OnChanged(function()
                if not Toggles.GunMods_InfRange.Value then
                    RestoreSaved(SavedValues.Range)
                end
                RefreshModConnection()
            end)
            Options.GunMods_RecoilValue:OnChanged(function()
                if Toggles.GunMods_RemoveRecoil.Value then
                    ApplyWeaponMods()
                end
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
            local environment = GetClientEnv()
            ClientEnvironment = environment
            return environment
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
        Library:GiveSignal(AddFrameTask(FrameScheduler.render, function()
            if not ToggleEnabled('SpreadVisualizer_Enable') then
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
            local camera = GetCurrentCamera()
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
        Aimbot:AddToggle('Aimbot_SilentAim', { Text = 'Silent aim', Default = false })
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
            local NextTargetUpdate = 0
            local SilentTarget = nil
            local AimTarget = nil
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
                AppendCombatRaycastIgnore(RaycastIgnore, 3, camera)
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
                    if needVisible and not IsVisible(character, part, camera) then
                        continue
                    end
                    bestDot = dot
                    bestPart = part
                    bestCharacter = character
                end
                return bestPart
            end
            local function SilentAimActive()
                local key = Options.Aimbot_Key
                return ToggleEnabled('Aimbot_Enable')
                    and ToggleEnabled('Aimbot_SilentAim')
                    and key ~= nil
                    and key:GetState()
            end
            local target = {
                enabled = false,
                position = nil,
            }
            local function GetSilentClosestTarget()
                local camera = GetCurrentCamera()
                return camera and GetTarget(camera) or nil
            end
            GetLegitSilentTarget = function()
                return SilentTarget
            end
            HandleLegitSilentRaycast = function(origin, direction)
                if not target.enabled or not target.position
                    or typeof(origin) ~= 'Vector3' or typeof(direction) ~= 'Vector3'
                then
                    return nil
                end
                local camera = GetCurrentCamera()
                if not camera then
                    return nil
                end
                local delta = target.position - camera.CFrame.Position
                if delta.Magnitude <= 1e-4 then
                    return nil
                end
                return delta.Unit * 200
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
            Library:GiveSignal(AddFrameTask(FrameScheduler.heartbeat, function()
                local now = os.clock()
                local camera = GetCurrentCamera()
                if not ToggleEnabled('Aimbot_Enable') or not camera then
                    SilentTarget = nil
                    AimTarget = nil
                    target.enabled = false
                    target.position = nil
                    return
                end

                local silentActive = SilentAimActive()
                target.enabled = silentActive and IsCombatRoundActive() and not HasCombatProtection(LocalPlayer.Character)
                if now >= NextTargetUpdate then
                    NextTargetUpdate = now + GetUpdateInterval()
                    if target.enabled then
                        SilentTarget = GetSilentClosestTarget()
                        AimTarget = nil
                    elseif Options.Aimbot_Key:GetState()
                        and IsCombatRoundActive()
                        and not HasCombatProtection(LocalPlayer.Character)
                    then
                        SilentTarget = nil
                        AimTarget = GetTarget(camera)
                    else
                        SilentTarget = nil
                        AimTarget = nil
                    end
                    target.position = SilentTarget and SilentTarget.Position or nil
                end
            end))
            Library:GiveSignal(AddFrameTask(FrameScheduler.render, function()
                if not ToggleEnabled('Aimbot_Enable') then
                    SilentTarget = nil
                    AimTarget = nil
                    if AimFovCircle then
                        AimFovCircle.Visible = false
                    end
                    return
                end
                local now = os.clock()
                local camera = GetCurrentCamera()
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
                if SilentAimActive() then
                    return
                end
                if now < NextUpdate then
                    return
                end
                NextUpdate = now + GetUpdateInterval()
                if not AimTarget or not AimTarget.Parent then
                    return
                end
                local goal = CFrame.new(camera.CFrame.Position, AimTarget.Position)
                local alpha = GetSmoothAlpha(Options.Aimbot_Smooth.Value)
                camera.CFrame = camera.CFrame:Lerp(goal, alpha)
            end))
            AddUnload(function()
                HandleLegitSilentRaycast = nil
                GetLegitSilentTarget = nil
                SilentTarget = nil
                AimTarget = nil
                target.enabled = false
                target.position = nil
                if AimFovCircle then
                    AimFovCircle.Visible = false
                    pcall(function()
                        AimFovCircle:Remove()
                    end)
                    AimFovCircle = nil
                end
            end)
        end
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
            local TriggerAmmoTable
            local TriggerAmmoScanAt = 0
            local TriggerCountAmmo
            local TriggerLoadAmmo
            local TriggerNativeScanAt = 0
            local function TriggerIsAmmoTable(object)
                return type(object) == 'table'
                    and type(rawget(object, 'ammocount')) == 'number'
                    and type(rawget(object, 'ammocount2')) == 'number'
                    and type(rawget(object, 'ammocount3')) == 'number'
                    and type(rawget(object, 'ammocount4')) == 'number'
                    and rawget(object, 'DISABLED') ~= nil
                    and rawget(object, 'reloading') ~= nil
            end
            local function TriggerGetNativeAmmo()
                if TriggerAmmoTable and TriggerIsAmmoTable(TriggerAmmoTable) then
                    return TriggerAmmoTable
                end
                local client = GetClientEnv()
                if type(client) == 'table' then
                    if TriggerIsAmmoTable(client) then
                        TriggerAmmoTable = client
                        return client
                    end
                    for _, object in pairs(client) do
                        if TriggerIsAmmoTable(object) then
                            TriggerAmmoTable = object
                            return object
                        end
                    end
                end
                local now = os.clock()
                if type(getgc) == 'function' and now >= TriggerAmmoScanAt then
                    TriggerAmmoScanAt = now + 30
                    local ok, objects = pcall(getgc, true)
                    if ok and type(objects) == 'table' then
                        for i = 1, #objects do
                            if TriggerIsAmmoTable(objects[i]) then
                                TriggerAmmoTable = objects[i]
                                break
                            end
                        end
                        table.clear(objects)
                    end
                end
                return TriggerAmmoTable
            end
            local function TriggerFindNativeFunctions()
                if TriggerCountAmmo and TriggerLoadAmmo then
                    return
                end
                local client = GetClientEnv()
                if type(client) == 'table' then
                    TriggerCountAmmo = TriggerCountAmmo or rawget(client, 'countammo')
                    TriggerLoadAmmo = TriggerLoadAmmo or rawget(client, 'loadammo')
                end
                local now = os.clock()
                if now < TriggerNativeScanAt then return end
                TriggerNativeScanAt = now + 30
                if (not TriggerCountAmmo or not TriggerLoadAmmo)
                    and type(getgc) == 'function' and debug and type(debug.getinfo) == 'function'
                then
                    local ok, objects = pcall(getgc, true)
                    if ok and type(objects) == 'table' then
                        for i = 1, #objects do
                            local object = objects[i]
                            if type(object) == 'function' then
                                local info = debug.getinfo(object)
                                if info and info.name == 'countammo' then
                                    TriggerCountAmmo = TriggerCountAmmo or object
                                elseif info and info.name == 'loadammo' then
                                    TriggerLoadAmmo = TriggerLoadAmmo or object
                                end
                                if TriggerCountAmmo and TriggerLoadAmmo then break end
                            end
                        end
                        table.clear(objects)
                    end
                end
            end
            local function TriggerGetAmmoKey(ammo, slot)
                slot = slot or rawget(ammo, 'equipped')
                return slot == 'primary' and 'ammocount'
                    or slot == 'secondary' and 'ammocount2'
                    or slot == 'equipment' and 'ammocount3'
                    or slot == 'equipment2' and 'ammocount4'
            end
            local function TriggerCanFire()
                local env = GetClientEnv()
                if type(env) == 'table' then
                    if rawget(env, 'DISABLED') == true or rawget(env, 'reloading') == true then
                        return false
                    end
                end
                local ammo = TriggerGetNativeAmmo()
                local character = LocalPlayer.Character
                local gun = character and character:FindFirstChild('Gun')
                if gun and gun:FindFirstChild('Melee') then
                    return true
                end
                if not ammo then
                    return true
                end
                local slot = type(env) == 'table' and rawget(env, 'equipped')
                local key = TriggerGetAmmoKey(ammo, slot)
                if key then
                    return (tonumber(ammo[key]) or 0) > 0
                end
                return (tonumber(ammo.ammocount) or 0) > 0
                    or (tonumber(ammo.ammocount2) or 0) > 0
                    or (tonumber(ammo.ammocount3) or 0) > 0
                    or (tonumber(ammo.ammocount4) or 0) > 0
            end
            local function TriggerIsBurst()
                local env = GetClientEnv()
                if type(env) ~= 'table' then return false end
                local gun = rawget(env, 'gun') or rawget(env, 'fgun')
                local slot = rawget(env, 'equipped')
                if typeof(gun) ~= 'Instance' or not gun:FindFirstChild('Switch') then
                    return false
                end
                return slot == 'primary' and rawget(env, 'special') == true
                    or slot == 'secondary' and rawget(env, 'special2') == true
            end
            local function TriggerFireInterval(rate)
                rate = math.max(tonumber(rate) or 0.1, 0.01)
                return TriggerIsBurst() and math.min(0.275, rate * 1.5) or rate
            end
            local function GetTriggerTeam(player)
                local status = player and player:FindFirstChild('Status')
                local team = status and status:FindFirstChild('Team')
                local value = team and team.Value
                if value ~= nil then
                    return value
                end
                local robloxTeam = player and player.Team
                return robloxTeam and robloxTeam.Name or nil
            end
            local function IsTriggerTeammate(player)
                if not Toggles.Triggerbot_TeamCheck.Value then
                    return false
                end
                local localTeam = GetTriggerTeam(LocalPlayer)
                local playerTeam = GetTriggerTeam(player)
                if localTeam == nil or playerTeam == nil then
                    return false
                end
                return localTeam == playerTeam
            end
            local function GetTriggerPenetrationBudget()
                local character = LocalPlayer.Character
                local env = GetClientEnv()
                local equipped = env and rawget(env, 'equipped')
                local gun = env and (rawget(env, 'fgun') or rawget(env, 'gun'))
                if typeof(gun) ~= 'Instance' then
                    gun = character and character:FindFirstChild('Gun')
                end
                local directPenetration = gun and gun:FindFirstChild('Penetration')
                if directPenetration and type(directPenetration.Value) == 'number' then
                    return math.max(directPenetration.Value, 0) * 0.01
                end
                if type(equipped) ~= 'string' or equipped == '' or equipped == 'none' then
                    local equippedValue = character and character:FindFirstChild('EquippedTool')
                    equipped = equippedValue and equippedValue.Value
                end
                local gunName = type(equipped) == 'string' and equipped ~= '' and equipped or (gun and gun.Name)
                local weapons = gunName and GetWeaponsFolder()
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
            local function GetTriggerWeaponRange()
                local character = LocalPlayer.Character
                local env = GetClientEnv()
                local equipped = env and rawget(env, 'equipped')
                local gun = env and (rawget(env, 'fgun') or rawget(env, 'gun'))
                if typeof(gun) ~= 'Instance' then
                    gun = character and character:FindFirstChild('Gun')
                end
                local directRange = gun and gun:FindFirstChild('Range')
                if directRange and type(directRange.Value) == 'number' then
                    return math.clamp(directRange.Value, 1, 100)
                end
                if type(equipped) ~= 'string' or equipped == '' or equipped == 'none' then
                    local equippedValue = character and character:FindFirstChild('EquippedTool')
                    equipped = equippedValue and equippedValue.Value
                end
                local gunName = type(equipped) == 'string' and equipped ~= '' and equipped or (gun and gun.Name)
                local weapons = gunName and GetWeaponsFolder()
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
                local range = weapon and weapon:FindFirstChild('Range')
                return range and type(range.Value) == 'number' and math.clamp(range.Value, 1, 100) or 64
            end
            local TriggerPenetrationParams = RaycastParams.new()
            TriggerPenetrationParams.FilterType = Enum.RaycastFilterType.Include
            TriggerPenetrationParams.IgnoreWater = true
            local TriggerPenetrationInclude = {}
            local function GetTriggerWallThickness(part, hitPosition, direction)
                TriggerPenetrationInclude[1] = part
                TriggerPenetrationParams.FilterDescendantsInstances = TriggerPenetrationInclude
                local probeDirection = direction.Unit * GetTriggerWeaponRange() * 0.0625
                local result = workspace:Raycast(
                    hitPosition + probeDirection,
                    probeDirection * -2,
                    TriggerPenetrationParams
                )
                TriggerPenetrationInclude[1] = nil
                if result then return (result.Position - hitPosition).Magnitude end
                return probeDirection.Magnitude
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
            local function GetTarget(camera)
                RaycastIgnore[1] = LocalPlayer.Character
                AppendCombatRaycastIgnore(RaycastIgnore, 2, camera)
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
                local hitPosition
                for _ = 1, 12 do
                    local result = workspace:Raycast(origin, rayEnd - origin, RayParams)
                    part = result and result.Instance
                    if not part or not part:IsA('BasePart') then
                        return nil
                    end
                    local character = part:FindFirstAncestorOfClass('Model')
                    if character and PlayersService:GetPlayerFromCharacter(character) then
                        hitPosition = result.Position
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
            local function GetSilentTarget()
                local part = GetLegitSilentTarget and GetLegitSilentTarget() or nil
                if not part or not part.Parent then
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
                return player, character, part
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
            Library:GiveSignal(AddFrameTask(FrameScheduler.heartbeat, function()
                local key = Options.Triggerbot_Key
                if not ToggleEnabled('Triggerbot_Enable') or not (key and key:GetState()) then
                    if DelayTarget then
                        ResetDelay()
                    end
                    return
                end
                local now = os.clock()
                local camera = GetCurrentCamera()
                if not camera then
                    ResetDelay()
                    return
                end
                if not IsCombatRoundActive() or HasCombatProtection(LocalPlayer.Character) then
                    ResetDelay()
                    return
                end
                TriggerFindNativeFunctions()
                if not TriggerCanFire() then
                    ResetDelay()
                    return
                end
                local player, _, part
                local aimKey = Options.Aimbot_Key
                if ToggleEnabled('Aimbot_Enable')
                    and ToggleEnabled('Aimbot_SilentAim')
                    and aimKey
                    and aimKey:GetState()
                then
                    player, _, part = GetSilentTarget()
                end
                if not player then
                    player, _, part = GetTarget(camera)
                end
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
                if now < DelayUntil then
                    return
                end
                if now - LastFireAt < TriggerFireInterval(GetFireRate()) then
                    return
                end
                if FireWeapon() then
                    LastFireAt = now
                    if type(TriggerCountAmmo) == 'function' then
                        pcall(TriggerCountAmmo)
                    end
                end
            end))
        end
        Players:AddToggle('ESP_Box', { Text = 'Box', Default = false })
            :AddColorPicker('ESP_Box_Color', { Default = Color3.fromRGB(255, 255, 255), Transparency = 0 })
        Players:AddToggle('ESP_Name', { Text = 'Name', Default = false })
            :AddColorPicker('ESP_Name_Color', { Default = Color3.fromRGB(255, 255, 255), Transparency = 0 })
        Players:AddToggle('ESP_Distance', { Text = 'Distance', Default = false })
            :AddColorPicker('ESP_Distance_Color', { Default = Color3.fromRGB(255, 255, 255), Transparency = 0 })
        Players:AddToggle('ESP_Weapon', { Text = 'Weapon', Default = false })
            :AddColorPicker('ESP_Weapon_Color', { Default = Color3.fromRGB(255, 255, 255), Transparency = 0 })
        Players:AddToggle('ESP_Bomb', { Text = 'Bomb ESP', Default = false })
            :AddColorPicker('ESP_Bomb_Color', { Default = Color3.fromRGB(255, 80, 60), Transparency = 0 })
        do
            local highlight
            local nameTag
            local cachedBomb, cachedPosition
            local nextPositionUpdate = 0
            local positionUpdateInterval = 1 / 30
            local function GetPlantedBomb()
                local bomb = workspace:FindFirstChild('C4')
                if not bomb then return nil end
                if bomb:IsA('Model') or bomb:IsA('BasePart') then return bomb end
                return bomb:FindFirstChildWhichIsA('BasePart', true)
            end
            local function GetBombPosition(bomb)
                if bomb:IsA('BasePart') then return bomb.Position end
                if bomb:IsA('Model') then return bomb:GetPivot().Position end
                local part = bomb:FindFirstChildWhichIsA('BasePart', true)
                return part and part.Position or nil
            end
            local function RemoveBombESP()
                cachedBomb, cachedPosition = nil, nil
                if highlight then
                    highlight:Destroy()
                    highlight = nil
                end
                if nameTag then
                    nameTag.Visible = false
                    nameTag:Remove()
                    nameTag = nil
                end
            end
            Library:GiveSignal(AddFrameTask(FrameScheduler.render, function()
                if not ToggleEnabled('ESP_Enable') or not ToggleEnabled('ESP_Bomb') then
                    RemoveBombESP()
                    return
                end
                local now = os.clock()
                if now >= nextPositionUpdate then
                    nextPositionUpdate = now + positionUpdateInterval
                    cachedBomb = GetPlantedBomb()
                    cachedPosition = cachedBomb and GetBombPosition(cachedBomb) or nil
                end
                local bomb = cachedBomb
                if not bomb or not bomb.Parent then
                    cachedBomb, cachedPosition = nil, nil
                    RemoveBombESP()
                    return
                end
                if not highlight then
                    highlight = Instance.new('Highlight')
                    highlight.Name = 'ValenokBombESP'
                    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                    highlight.FillTransparency = 0.35
                    highlight.OutlineTransparency = 0
                    highlight.Parent = workspace
                end
                local color = Options.ESP_Bomb_Color.Value
                local alpha = math.clamp(Options.ESP_Bomb_Color.Transparency or 0, 0, 1)
                highlight.Adornee = bomb
                highlight.FillColor, highlight.OutlineColor = color, color
                highlight.FillTransparency = math.clamp(0.35 + alpha * 0.65, 0, 1)
                highlight.OutlineTransparency = alpha
                highlight.Enabled = true
                local camera = GetCurrentCamera()
                local screen, visible = camera and cachedPosition and camera:WorldToViewportPoint(cachedPosition)
                if visible and screen.Z > 0 then
                        if not nameTag then
                            nameTag = MakeESPText()
                        if nameTag then
                            nameTag.Font = 2
                            nameTag.Size = 13
                        end
                    end
                    if nameTag then
                        nameTag.Font = 2
                        nameTag.Size = 13
                        nameTag.Text = 'C4'
                        nameTag.Color = Color3.fromRGB(255, 0, 0)
                        nameTag.Transparency = 1
                        nameTag.Position = Vector2.new(screen.X, screen.Y - 14)
                        nameTag.Visible = true
                    end
                elseif nameTag then
                    nameTag.Visible = false
                end
            end))
            AddUnload(RemoveBombESP)
        end
        do
            local Drawings = {} -- player -> { Box, BoxOutline, Name, Distance, Weapon, HealthOutline, HealthFill }
            local WeaponCache = setmetatable({}, { __mode = 'k' })
            local PlayerPartCache = setmetatable({}, { __mode = 'k' })
            local NextUpdate = 0
            local ESPWasVisible = false
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
            local function EnsureSquare(set, key, thickness, filled)
                if not set[key] then
                    set[key] = MakeSquare(thickness, filled)
                    local drawing = set[key]
                    if drawing and (key == 'BoxOutline' or key == 'HealthOutline') then
                        drawing.Color = Color3.fromRGB(0, 0, 0)
                    end
                    if drawing then
                        drawing.ZIndex = key == 'Box' and 2 or key == 'HealthFill' and 3 or 1
                    end
                end
                return set[key]
            end
            local function EnsureText(set, key)
                if not set[key] then
                    set[key] = MakeESPText()
                    if set[key] then set[key].ZIndex = 3 end
                end
                return set[key]
            end
            local function MakeDrawingSet()
                return {}
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
            local function RemoveDrawing(set, key)
                local drawing = set and set[key]
                if not drawing then
                    return
                end
                drawing.Visible = false
                pcall(function()
                    drawing:Remove()
                end)
                set[key] = nil
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
                while true do
                    local player = next(Drawings)
                    if not player then
                        break
                    end
                    RemovePlayer(player)
                end
            end
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
                return topScreen.X - width / 2, topScreen.Y, width, height
            end
            Library:GiveSignal(AddFrameTask(FrameScheduler.render, function()
                local now = os.clock()
                if now < NextUpdate then
                    return
                end
                NextUpdate = now + GetUpdateInterval()
                local showBox = ToggleEnabled('ESP_Box')
                local showName = ToggleEnabled('ESP_Name')
                local showDistance = ToggleEnabled('ESP_Distance')
                local showWeapon = ToggleEnabled('ESP_Weapon')
                local showHealthBar = ToggleEnabled('ESP_HealthBar')
                if not ToggleEnabled('ESP_Enable')
                    or (not showBox and not showName and not showDistance and not showWeapon and not showHealthBar)
                then
                    if ESPWasVisible then
                        RemoveAll()
                        ESPWasVisible = false
                    end
                    return
                end
                local camera = GetCurrentCamera()
                if not camera then
                    if ESPWasVisible then
                        HideAll()
                        ESPWasVisible = false
                    end
                    return
                end
                ESPWasVisible = true
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
                    local character, root, humanoid = GetCachedPlayerParts(player, PlayerPartCache)
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
                        Drawings[player] = set
                    end
                    local boxPos = Vector2.new(left, top)
                    local boxSize = Vector2.new(width, height)
                    local bottom = top + height
                    local centerX = left + width * 0.5
                    if showBox then
                        local boxOutline = EnsureSquare(set, 'BoxOutline', 3, false)
                        local box = EnsureSquare(set, 'Box', 1, false)
                        if boxOutline then
                            boxOutline.Size = boxSize
                            boxOutline.Position = boxPos
                            boxOutline.Transparency = boxAlpha
                            boxOutline.Visible = true
                        end
                        if box then
                            box.Size = boxSize
                            box.Position = boxPos
                            box.Color = boxColor
                            box.Transparency = boxAlpha
                            box.Visible = true
                        end
                    else
                        RemoveDrawing(set, 'Box')
                        RemoveDrawing(set, 'BoxOutline')
                    end
                    if showName then
                        local name = EnsureText(set, 'Name')
                        if name then
                            name.Font = ESPFont
                            name.Size = ESPFontSize
                            name.Text = player.DisplayName
                            name.Color = nameColor
                            name.Transparency = nameAlpha
                            name.Position = Vector2.new(centerX, top - 14)
                            name.Visible = true
                        end
                    else
                        RemoveDrawing(set, 'Name')
                    end
                    if showDistance then
                        local distance = EnsureText(set, 'Distance')
                        if distance then
                            distance.Font = ESPFont
                            distance.Size = ESPFontSize
                            local studs = Round((camPos - root.Position).Magnitude)
                            distance.Text = tostring(studs) .. 'm'
                            distance.Color = distColor
                            distance.Transparency = distAlpha
                            distance.Position = Vector2.new(centerX, bottom + 1)
                            distance.Visible = true
                        end
                    else
                        RemoveDrawing(set, 'Distance')
                    end
                    if showWeapon then
                        local weapon = EnsureText(set, 'Weapon')
                        local weaponName = GetWeaponDisplayName(character)
                        if weapon and weaponName then
                            local y = bottom + 1
                            if showDistance then
                                y = y + 13
                            end
                            weapon.Font = ESPFont
                            weapon.Size = ESPFontSize
                            weapon.Text = weaponName
                            weapon.Color = weaponColor
                            weapon.Transparency = weaponAlpha
                            weapon.Position = Vector2.new(centerX, y)
                            weapon.Visible = true
                        elseif weapon then
                            weapon.Visible = false
                        end
                    else
                        RemoveDrawing(set, 'Weapon')
                    end
                    if showHealthBar then
                        local healthOutline = EnsureSquare(set, 'HealthOutline', 1.5, false)
                        local healthFill = EnsureSquare(set, 'HealthFill', 0, true)
                        local barOuterW = 3
                        local gap = 1
                        local inset = 1
                        local barX = left - gap - barOuterW
                        local barSize = Vector2.new(barOuterW, height)
                        local barPos = Vector2.new(barX, top)
                        local innerH = math.max(1, height - inset * 2)
                        local ratio = math.clamp(humanoid.Health / humanoid.MaxHealth, 0, 1)
                        local fillH = math.max(1, innerH * ratio)
                        local fillW = barOuterW - inset * 2
                        local fillY = top + height - inset - fillH
                        if healthOutline then
                            healthOutline.Size = barSize
                            healthOutline.Position = barPos
                            healthOutline.Transparency = healthAlpha
                            healthOutline.Visible = true
                        end
                        if healthFill then
                            healthFill.Size = Vector2.new(fillW, fillH)
                            healthFill.Position = Vector2.new(barX + inset, fillY)
                            healthFill.Color = healthLow:Lerp(healthHigh, ratio)
                            healthFill.Transparency = healthAlpha
                            healthFill.Visible = true
                        end
                    else
                        RemoveDrawing(set, 'HealthOutline')
                        RemoveDrawing(set, 'HealthFill')
                    end
                end
            end))
            Library:GiveSignal(PlayersService.PlayerRemoving:Connect(function(player)
                RemovePlayer(player)
                PlayerPartCache[player] = nil
            end))
            AddUnload(function()
                RemoveAll()
                table.clear(WeaponCache)
                table.clear(PlayerPartCache)
            end)
        end
        Players:AddToggle('ESP_HealthBar', { Text = 'HealthBar', Default = false })
            :AddColorPicker('ESP_HealthBar_High', { Default = Color3.fromRGB(0, 255, 0), Transparency = 0 })
            :AddColorPicker('ESP_HealthBar_Low', { Default = Color3.fromRGB(255, 0, 0), Transparency = 0 })
        Players:AddToggle('ESP_Dropped', { Text = 'item ESP', Default = false })
            :AddColorPicker('ESP_Dropped_Color', {
                Default = Color3.fromRGB(255, 255, 255),
                Transparency = 0,
            })
        do
            local DropDrawings = {} -- instance -> Drawing.Text
            local DropNames = {}
            local DropNameRefs = {}
            local DropItems, DropIndex, DropPositions, DropRawNames = {}, {}, {}, {}
            local BoundDebris, DebrisConnections = nil, {}
            local NextPositionUpdate = 0
            local PositionUpdateInterval = 1 / 30
            local DropsVisible = false
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
                while true do
                    local item = next(DropDrawings)
                    if not item then
                        break
                    end
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
                local raw = DropRawNames[item]
                if raw then
                    local refs = (DropNameRefs[raw] or 1) - 1
                    if refs <= 0 then
                        DropNameRefs[raw] = nil
                        DropNames[raw] = nil
                    else
                        DropNameRefs[raw] = refs
                    end
                    DropRawNames[item] = nil
                end
                DropPositions[item] = nil
                RemoveDrop(item)
            end
            local function AddDropItem(item)
                if DropIndex[item] then
                    return
                end
                DropItems[#DropItems + 1] = item
                DropIndex[item] = #DropItems
                local raw = item.Name
                DropRawNames[item] = raw
                DropNameRefs[raw] = (DropNameRefs[raw] or 0) + 1
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
                table.clear(DropPositions)
                table.clear(DropRawNames)
                table.clear(DropNames)
                table.clear(DropNameRefs)
                BoundDebris = folder
                if not folder then return end
                local weapons = GetWeaponsFolder()
                for _, item in ipairs(folder:GetChildren()) do
                    if IsDroppedWeapon(item, weapons) then
                        AddDropItem(item)
                    end
                end
                DebrisConnections[#DebrisConnections + 1] = folder.ChildAdded:Connect(function(item)
                    if not DropIndex[item] and IsDroppedWeapon(item, GetWeaponsFolder()) then
                        AddDropItem(item)
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
            Library:GiveSignal(AddFrameTask(FrameScheduler.render, function()
                if not ToggleEnabled('ESP_Enable') or not ToggleEnabled('ESP_Dropped') then
                    if DropsVisible then
                        if BoundDebris then BindDebris(nil) end
                        RemoveAllDrops()
                        DropsVisible = false
                    end
                    return
                end
                local camera = GetCurrentCamera()
                local debris = GetDebrisRoot()
                local weapons = GetWeaponsFolder()
                if not camera or not debris or not weapons then
                    if DropsVisible then
                        if not debris and BoundDebris then BindDebris(nil) end
                        RemoveAllDrops()
                        DropsVisible = false
                    end
                    return
                end
                DropsVisible = true
                local color = Options.ESP_Dropped_Color.Value
                local alpha = math.clamp(1 - (Options.ESP_Dropped_Color.Transparency or 0), 0, 1)
                BindDebris(debris)
                local now = os.clock()
                if now >= NextPositionUpdate then
                    NextPositionUpdate = now + PositionUpdateInterval
                    for i = 1, #DropItems do
                        local item = DropItems[i]
                        DropPositions[item] = IsDroppedWeapon(item, weapons) and GetDropPosition(item) or nil
                    end
                end
                for i = #DropItems, 1, -1 do
                    local item = DropItems[i]
                    if item.Parent ~= BoundDebris or not IsDroppedWeapon(item, weapons) then
                        RemoveDropItem(item)
                        continue
                    end
                    local pos3 = DropPositions[item]
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
                    draw.Font = ESPFont
                    draw.Size = ESPFontSize
                    draw.Text = GetDropDisplayName(item)
                    draw.Color = color
                    draw.Transparency = alpha
                    draw.Position = Vector2.new(screen.X, screen.Y)
                    draw.Visible = true
                end
            end))
            AddUnload(function()
                for i = 1, #DebrisConnections do DebrisConnections[i]:Disconnect() end
                table.clear(DebrisConnections)
                BoundDebris = nil
                DropsVisible = false
                RemoveAllDrops()
                table.clear(DropItems)
                table.clear(DropIndex)
                table.clear(DropPositions)
                table.clear(DropRawNames)
                table.clear(DropNames)
                table.clear(DropNameRefs)
            end)
        end
        Players:AddToggle('ESP_Chams', { Text = 'Chams', Default = false })
            :AddColorPicker('ESP_Chams_Visible', {
                Default = Color3.fromRGB(255, 0, 0),
                Transparency = 0.3,
                Title = 'Visible',
            })
            :AddColorPicker('ESP_Chams_Wall', {
                Default = Color3.fromRGB(0, 0, 255),
                Transparency = 0.9,
                Title = 'Behind wall',
            })
        Players:AddDropdown('ESP_Chams_Type', {
            Text = 'Chams type',
            Values = { 'Highlight', 'Part' },
            Default = 'Highlight',
        })
        Players:AddToggle('ESP_ChamsOutline', { Text = 'Chams Outline', Default = false })
            :AddColorPicker('ESP_Chams_Outline', {
                Default = Color3.fromRGB(255, 255, 255),
                Transparency = 0,
                Title = 'Outline',
            })
        do
            local function SetupPartChams()
            local function DisconnectLegacyPartChamsLoops()
                local env = type(getgenv) == 'function' and getgenv() or _G
                local getConnections = rawget(env, 'getconnections')
                local getUpvalues = rawget(env, 'getupvalues')
                if type(getUpvalues) ~= 'function' and type(debug) == 'table' then
                    getUpvalues = debug.getupvalues
                end
                if type(getConnections) ~= 'function' or type(getUpvalues) ~= 'function' then
                    return
                end
                local ok, connections = pcall(getConnections, RunService.Heartbeat)
                if not ok or type(connections) ~= 'table' then return end
                for _, connection in ipairs(connections) do
                    local callback
                    pcall(function()
                        callback = connection.Function
                    end)
                    if type(callback) == 'function' then
                        local upvalueOk, upvalues = pcall(getUpvalues, callback)
                        if upvalueOk and type(upvalues) == 'table' then
                            for _, value in pairs(upvalues) do
                                if type(value) == 'table'
                                    and rawget(value, 'ESP_Enabled') ~= nil
                                    and rawget(value, 'Chams') ~= nil
                                    and rawget(value, 'Chams_Color') ~= nil
                                    and rawget(value, 'Chams_Glow_Color') ~= nil
                                    and rawget(value, 'Glow_Transparency') ~= nil
                                then
                                    pcall(function()
                                        if type(connection.Disable) == 'function' then
                                            connection:Disable()
                                        elseif type(connection.Disconnect) == 'function' then
                                            connection:Disconnect()
                                        end
                                    end)
                                    break
                                end
                            end
                        end
                    end
                end
            end

            DisconnectLegacyPartChamsLoops()
            local PartStates = setmetatable({}, { __mode = 'k' })
            local PartPlayerCache = setmetatable({}, { __mode = 'k' })
            local CreatedPartAdornments = {}
            local PartWasEnabled = false
            local PartUnloading = false
            local NextPartUpdate = 0
            local LastWallColor
            local LastVisibleColor
            local PartUpdateInterval = 1 / 30
            local PartScanInterval = 0.35
            local ChamsSizeOffset = Vector3.new(0.02, 0.02, 0.02)
            local GlowSizeOffset = Vector3.new(0.15, 0.15, 0.15)

            local function DestroyAdornment(adornment)
                if not adornment then return end
                CreatedPartAdornments[adornment] = nil
                pcall(function()
                    adornment:Destroy()
                end)
            end

            local function DestroyRecord(record)
                if not record then return end
                DestroyAdornment(record.chams)
                DestroyAdornment(record.glow)
            end

            local function DestroyNamedAdornments(part)
                for _, child in ipairs(part:GetChildren()) do
                    if child:IsA('HandleAdornment')
                        and (child.Name == '__ValenokPartChams'
                            or child.Name == '__ValenokPartGlow'
                            or child.Name == 'Chams'
                            or child.Name == 'Glow')
                    then
                        DestroyAdornment(child)
                    end
                end
            end

            local function DestroyCharacterChams(character)
                if not character then return end
                for _, part in ipairs(character:GetChildren()) do
                    if part:IsA('BasePart') then
                        DestroyNamedAdornments(part)
                    end
                end
            end

            local function RemovePartState(state, part)
                local record = state.parts[part]
                if record then
                    DestroyRecord(record)
                    state.parts[part] = nil
                end
            end

            local function RemovePlayerState(player)
                local state = PartStates[player]
                if not state then return end
                for part, record in pairs(state.parts) do
                    DestroyRecord(record)
                    state.parts[part] = nil
                end
                DestroyCharacterChams(state.character)
                PartStates[player] = nil
                PartPlayerCache[player] = nil
            end

            local function RemoveAllPartChams()
                while true do
                    local player = next(PartStates)
                    if not player then break end
                    RemovePlayerState(player)
                end
                for _, player in ipairs(PlayersService:GetPlayers()) do
                    if player ~= LocalPlayer and player.Character then
                        DestroyCharacterChams(player.Character)
                    end
                end
                while true do
                    local adornment = next(CreatedPartAdornments)
                    if not adornment then break end
                    DestroyAdornment(adornment)
                end
            end

            local function CreateRecord(part, wallColor, visibleColor)
                DestroyNamedAdornments(part)

                local chams = Instance.new('BoxHandleAdornment')
                chams.Name = '__ValenokPartChams'
                chams.AlwaysOnTop = true
                chams.ZIndex = 4
                chams.Adornee = part
                chams.Color3 = wallColor
                chams.Transparency = 0.9
                chams.Size = part.Size + ChamsSizeOffset
                chams.Parent = part
                CreatedPartAdornments[chams] = true

                local glow = Instance.new('BoxHandleAdornment')
                glow.Name = '__ValenokPartGlow'
                glow.AlwaysOnTop = false
                glow.ZIndex = 3
                glow.Adornee = part
                glow.Color3 = visibleColor
                glow.Transparency = 0.3
                glow.Size = part.Size + GlowSizeOffset
                glow.Parent = part
                CreatedPartAdornments[glow] = true

                return { chams = chams, glow = glow, size = part.Size }
            end

            local function UpdateRecord(state, part, wallColor, visibleColor)
                if part.Transparency == 1 then
                    RemovePartState(state, part)
                    return
                end

                local record = state.parts[part]
                if not record
                    or not record.chams.Parent
                    or not record.glow.Parent
                then
                    DestroyRecord(record)
                    record = CreateRecord(part, wallColor, visibleColor)
                    state.parts[part] = record
                    return
                end

                local chams, glow = record.chams, record.glow
                if chams.Adornee ~= part then chams.Adornee = part end
                if glow.Adornee ~= part then glow.Adornee = part end
                if chams.Color3 ~= wallColor then chams.Color3 = wallColor end
                if glow.Color3 ~= visibleColor then glow.Color3 = visibleColor end
                if chams.Transparency ~= 0.9 then chams.Transparency = 0.9 end
                if glow.Transparency ~= 0.3 then glow.Transparency = 0.3 end
                if record.size ~= part.Size then
                    record.size = part.Size
                    chams.Size = part.Size + ChamsSizeOffset
                    glow.Size = part.Size + GlowSizeOffset
                end
            end

            local function UpdatePlayerParts(player, character, wallColor, visibleColor, now, styleChanged)
                local state = PartStates[player]
                if not state or state.character ~= character then
                    RemovePlayerState(player)
                    DestroyCharacterChams(character)
                    state = {
                        character = character,
                        parts = setmetatable({}, { __mode = 'k' }),
                        nextScan = 0,
                    }
                    PartStates[player] = state
                end

                if now >= state.nextScan then
                    state.nextScan = now + PartScanInterval
                    for _, part in ipairs(character:GetChildren()) do
                        if part:IsA('BasePart') then
                            UpdateRecord(state, part, wallColor, visibleColor)
                        end
                    end
                    for part in pairs(state.parts) do
                        if part.Parent ~= character then
                            RemovePartState(state, part)
                        end
                    end
                elseif styleChanged then
                    for part in pairs(state.parts) do
                        if part.Parent == character then
                            UpdateRecord(state, part, wallColor, visibleColor)
                        else
                            RemovePartState(state, part)
                        end
                    end
                end
            end

            Library:GiveSignal(PlayersService.PlayerRemoving:Connect(function(player)
                RemovePlayerState(player)
                PartPlayerCache[player] = nil
            end))
            Library:GiveSignal(AddFrameTask(FrameScheduler.heartbeat, function()
                if PartUnloading then return end
                local now = os.clock()
                if now < NextPartUpdate then return end
                NextPartUpdate = now + PartUpdateInterval

                local enabled = ToggleEnabled('ESP_Enable')
                    and ToggleEnabled('ESP_Chams')
                    and Options.ESP_Chams_Type.Value == 'Part'
                if not enabled then
                    if PartWasEnabled then
                        RemoveAllPartChams()
                        PartWasEnabled = false
                    end
                    return
                end

                if not PartWasEnabled then
                    RemoveAllPartChams()
                    for _, child in ipairs(workspace:GetChildren()) do
                        if child:IsA('Folder') and child.Name == 'ValenokChams' then
                            child:Destroy()
                        end
                    end
                    PartWasEnabled = true
                end

                local wallColor = Options.ESP_Chams_Wall.Value
                local visibleColor = Options.ESP_Chams_Visible.Value
                local styleChanged = wallColor ~= LastWallColor or visibleColor ~= LastVisibleColor
                LastWallColor, LastVisibleColor = wallColor, visibleColor
                local teamCheck = ToggleEnabled('ESP_TeamCheck')

                for _, player in ipairs(PlayerSnapshot) do
                    if player == LocalPlayer
                        or (teamCheck and player.Team == LocalPlayer.Team)
                    then
                        RemovePlayerState(player)
                        continue
                    end
                    local character, root, humanoid = GetCachedPlayerParts(player, PartPlayerCache)
                    if not character or not root or not humanoid or humanoid.Health <= 0 then
                        RemovePlayerState(player)
                        continue
                    end
                    UpdatePlayerParts(player, character, wallColor, visibleColor, now, styleChanged)
                end
            end))
            AddUnload(function()
                PartUnloading = true
                pcall(function()
                    if Toggles.ESP_Chams.SetValue then
                        Toggles.ESP_Chams:SetValue(false)
                    else
                        Toggles.ESP_Chams.Value = false
                    end
                end)
                DisconnectLegacyPartChamsLoops()
                RemoveAllPartChams()
                table.clear(PartStates)
                table.clear(PartPlayerCache)
                table.clear(CreatedPartAdornments)
            end)
            end
            SetupPartChams()
        end
        do
            local Highlights = {}
            local HighlightStates = {}
            local VisCache = {}
            local PlayerPartCache = setmetatable({}, { __mode = 'k' })
            local CheckPartCache = setmetatable({}, { __mode = 'k' })
            local ChamsFolder
            local NextUpdate = 0
            local ChamsWasVisible = false
            local RayParams = RaycastParams.new()
            local RaycastIgnore = {}
            local RaycastIgnoreCount = 0
            local RaycastIgnoreRevision = -1
            local RaycastIgnoreCharacter = nil
            local RaycastIgnoreLocalCharacter = nil
            RayParams.FilterType = Enum.RaycastFilterType.Exclude
            local function GetChamsFolder()
                if ChamsFolder and ChamsFolder.Parent then return ChamsFolder end
                ChamsFolder = Instance.new('Folder')
                ChamsFolder.Name = 'ValenokChams'
                ChamsFolder.Parent = workspace
                return ChamsFolder
            end
            local function RemoveHighlight(player)
                local hl = Highlights[player]
                if hl then
                    pcall(function()
                        hl:Destroy()
                    end)
                    Highlights[player] = nil
                end
                HighlightStates[player] = nil
            end
            local function RemoveChams(player)
                RemoveHighlight(player)
                VisCache[player] = nil
            end
            local function RemoveAllChams()
                while true do
                    local player = next(Highlights)
                    if not player then break end
                    RemoveChams(player)
                end
                table.clear(VisCache)
                table.clear(RaycastIgnore)
                RaycastIgnoreCount = 0
                RaycastIgnoreRevision = -1
                RaycastIgnoreCharacter = nil
                RaycastIgnoreLocalCharacter = nil
                RayParams.FilterDescendantsInstances = {}
                if ChamsFolder then
                    pcall(function()
                        ChamsFolder:Destroy()
                    end)
                    ChamsFolder = nil
                end
                for _, child in ipairs(workspace:GetChildren()) do
                    if child:IsA('Folder') and child.Name == 'ValenokChams' then
                        pcall(function()
                            child:Destroy()
                        end)
                    end
                end
            end
            local function HideChams(player)
                local hl = Highlights[player]
                if hl then
                    local state = HighlightStates[player]
                    if not state or state.enabled ~= false then
                        hl.Enabled = false
                    end
                    if not state or state.adornee ~= nil then
                        hl.Adornee = nil
                    end
                    if state then
                        state.enabled = false
                        state.adornee = nil
                    end
                end
                VisCache[player] = nil
            end
            local function IsPlayerVisible(character, camera)
                local checkPart = CheckPartCache[character]
                if not checkPart or not checkPart.Parent then
                    checkPart = character:FindFirstChild('Head')
                        or character:FindFirstChild('UpperTorso')
                        or character:FindFirstChild('HumanoidRootPart')
                    CheckPartCache[character] = checkPart
                end
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
                local shared = GetSharedRaycastIgnore()
                local changed = false
                if RaycastIgnoreRevision ~= SharedRaycastIgnoreRevision then
                    RaycastIgnoreRevision = SharedRaycastIgnoreRevision
                    local count = 2
                    for i = 1, #shared do
                        count = count + 1
                        RaycastIgnore[count] = shared[i]
                    end
                    for i = count + 1, RaycastIgnoreCount do
                        RaycastIgnore[i] = nil
                    end
                    RaycastIgnoreCount = count
                    changed = true
                end
                local localCharacter = LocalPlayer.Character
                if RaycastIgnoreCharacter ~= character or RaycastIgnoreLocalCharacter ~= localCharacter then
                    RaycastIgnoreCharacter = character
                    RaycastIgnoreLocalCharacter = localCharacter
                    RaycastIgnore[1] = character
                    RaycastIgnore[2] = localCharacter
                    changed = true
                end
                if changed then
                    RayParams.FilterDescendantsInstances = RaycastIgnore
                end
                local result = workspace:Raycast(origin, dir, RayParams)
                return result == nil
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
            Library:GiveSignal(AddFrameTask(FrameScheduler.render, function()
                local now = os.clock()
                if now < NextUpdate then
                    return
                end
                NextUpdate = now + GetUpdateInterval()
                local chamsOn = ToggleEnabled('ESP_Chams')
                local outlineOn = ToggleEnabled('ESP_ChamsOutline')
                local partMode = Options.ESP_Chams_Type.Value == 'Part'
                if partMode then
                    if ChamsWasVisible or next(Highlights) or ChamsFolder then
                        RemoveAllChams()
                        ChamsWasVisible = false
                    end
                    return
                end
                if not ToggleEnabled('ESP_Enable') or (not chamsOn and not outlineOn) then
                    if ChamsWasVisible or next(Highlights) or ChamsFolder then
                        RemoveAllChams()
                        ChamsWasVisible = false
                    end
                    return
                end
                local camera = GetCurrentCamera()
                if not camera then
                    if ChamsWasVisible or next(Highlights) or ChamsFolder then
                        RemoveAllChams()
                        ChamsWasVisible = false
                    end
                    return
                end
                ChamsWasVisible = true
                local outlineColor = Options.ESP_Chams_Outline.Value
                local outlineTransparency = Options.ESP_Chams_Outline.Transparency
                for _, player in ipairs(PlayerSnapshot) do
                    if player == LocalPlayer or IsTeammate(player) then
                        HideChams(player)
                        continue
                    end
                    local character, root, humanoid = GetCachedPlayerParts(player, PlayerPartCache)
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
                        HighlightStates[player] = nil
                    end
                    local state = HighlightStates[player]
                    if not state then
                        state = {}
                        HighlightStates[player] = state
                    end
                    local fillAlpha = chamsOn and fillTransparency or 1
                    local outlineAlpha = outlineOn and outlineTransparency or 1
                    if state.enabled ~= true then hl.Enabled = true; state.enabled = true end
                    if state.adornee ~= character then hl.Adornee = character; state.adornee = character end
                    if state.fillColor ~= fillColor then hl.FillColor = fillColor; state.fillColor = fillColor end
                    if state.outlineColor ~= outlineColor then hl.OutlineColor = outlineColor; state.outlineColor = outlineColor end
                    if state.fillAlpha ~= fillAlpha then hl.FillTransparency = fillAlpha; state.fillAlpha = fillAlpha end
                    if state.outlineAlpha ~= outlineAlpha then hl.OutlineTransparency = outlineAlpha; state.outlineAlpha = outlineAlpha end
                end
            end))
            Library:GiveSignal(PlayersService.PlayerRemoving:Connect(function(player)
                RemoveChams(player)
                PlayerPartCache[player] = nil
            end))
            AddUnload(function()
                RemoveAllChams()
                table.clear(HighlightStates)
                table.clear(VisCache)
                table.clear(PlayerPartCache)
                table.clear(CheckPartCache)
                table.clear(RaycastIgnore)
                if ChamsFolder then
                    ChamsFolder:Destroy()
                    ChamsFolder = nil
                end
            end)
        end
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
                            NextRestore = now + 0.1
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
                Cache.Arms = nil
                Cache.Handle = nil
                table.clear(Cache.WeaponParts)
                table.clear(Cache.ArmItems)
                table.clear(CleanedParts)
            end)
        end
        do
            local FovChanger = VisualTab:AddRightGroupbox('FOV Changer')
            FovChanger:AddToggle('FovChanger_Enable', { Text = 'Enable', Default = false })
            FovChanger:AddToggle('FovChanger_IgnoreScopeFov', { Text = 'Ignore scope FOV', Default = false })
            FovChanger:AddSlider('FovChanger_Fov', {
                Text = 'FOV',
                Default = 80,
                Min = 50,
                Max = 120,
                Rounding = 0,
            })
            local FovChangerBindName = 'ValenokFovChanger'
            local function IsScopeVisible()
                local playerGui = LocalPlayer:FindFirstChildOfClass('PlayerGui')
                local root = playerGui and (playerGui:FindFirstChild('GUI') or playerGui:FindFirstChild('Client'))
                local crosshairs = root and root:FindFirstChild('Crosshairs')
                local scope = crosshairs and crosshairs:FindFirstChild('Scope')
                return scope and scope.Visible == true
            end
            local function UnbindFovChanger()
                pcall(function() RunService:UnbindFromRenderStep(FovChangerBindName) end)
            end
            Toggles.FovChanger_Enable:OnChanged(function(enabled)
                UnbindFovChanger()
                if enabled then
                    pcall(function()
                        RunService:BindToRenderStep(FovChangerBindName, 10, function()
                            local camera = workspace.CurrentCamera
                            if camera and (Toggles.FovChanger_IgnoreScopeFov.Value or not IsScopeVisible()) then
                                camera.FieldOfView = Options.FovChanger_Fov.Value
                            end
                        end)
                    end)
                else
                    local camera = workspace.CurrentCamera
                    if camera then
                        camera.FieldOfView = 80
                    end
                end
            end)
            AddUnload(function()
                UnbindFovChanger()
                local camera = workspace.CurrentCamera
                if camera then
                    camera.FieldOfView = 80
                end
            end)
        end
        local ThirdPerson = VisualTab:AddRightGroupbox('ThirdPerson')
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
                local key = Options.ThirdPerson_Key
                return ToggleEnabled('ThirdPerson_Enable') and key and key:GetState()
            end
            local function IsViewModelHidden()
                local keybind = Options.ThirdPerson_HideViewModel_Key
                return ToggleEnabled('ThirdPerson_HideViewModel')
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
                if not (IsThirdPersonActive() and ToggleEnabled('ThirdPerson_ThroughWalls')) then
                    return
                end
                RunService:BindToRenderStep(TP_NOCLIP_NAME, Enum.RenderPriority.Camera.Value + 1, function()
                    local now = os.clock()
                    if now < NextNoClipUpdate then
                        return
                    end
                    NextNoClipUpdate = now + GetUpdateInterval()
                    if not (IsThirdPersonActive() and ToggleEnabled('ThirdPerson_ThroughWalls')) then
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
            Library:GiveSignal(AddFrameTask(FrameScheduler.heartbeat, function()
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
            Library:GiveSignal(AddFrameTask(FrameScheduler.render, function(dt)
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
        WorldAmbience:AddToggle('World_CustomTime', { Text = 'Custom time', Default = false })
        WorldAmbience:AddSlider('World_Time', {
            Text = 'Time',
            Default = 12,
            Min = 0,
            Max = 24,
            Rounding = 1,
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
            local Lighting = game:GetService('Lighting')
            local staleBlur = Lighting:FindFirstChild('ValenokCameraBlur')
            if staleBlur then staleBlur:Destroy() end
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
                skies = setmetatable({}, { __mode = 'k' }),
                saturation = nil,
                saturationSnapshot = nil,
                ownsSaturation = false,
                technology = nil,
                originalSky = nil,
                customSky = nil,
                skyboxGeneration = 0,
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
            local function WorldActive()
                return Enabled('World_CustomTime')
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
                end
                Set(Lighting, 'Ambient', ambient)
                Set(Lighting, 'OutdoorAmbient', outdoor)
                Set(Lighting, 'ColorShift_Bottom', bottom)
                Set(Lighting, 'ColorShift_Top', top)
                Set(Lighting, 'FogColor', saved.FogColor)
                Set(Lighting, 'FogEnd', saved.FogEnd)
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
            local function DestroySkyboxObjects(objects, keep)
                if type(objects) ~= 'table' then
                    return
                end
                for i = 1, #objects do
                    local object = objects[i]
                    if typeof(object) == 'Instance' and object ~= keep then
                        pcall(function()
                            object:Destroy()
                        end)
                    end
                end
                table.clear(objects)
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
                            DestroySkyboxObjects(objects)
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
                        DestroySkyboxObjects(objects, State.customSky)
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
                'World_CustomTime', 'World_Time', 'World_NoShadows', 'World_BetterShadows',
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
            local updateAccumulator = 0
            Library:GiveSignal(AddFrameTask(FrameScheduler.heartbeat, function(deltaTime)
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
            end)
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
            :AddKeyPicker('SpeedHack_Key', {
                Default = 'None', Mode = 'Toggle', Text = 'SpeedHack',
            })
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
            :AddKeyPicker('Movement_Fly_Key', {
                Default = 'None', Mode = 'Toggle', Text = 'Fly',
            })
        MovementMisc:AddSlider('Movement_FlySpeed', {
            Text = 'Fly speed',
            Default = 1,
            Min = 1,
            Max = 50,
            Rounding = 2,
        })
        MovementMisc:AddToggle('Movement_NoClip', { Text = 'NoClip', Default = false })
        local function SnapMovementSlider(option, maxValue)
            option:OnChanged(function(value)
                local snapped = math.clamp(math.floor(value * 20 + 0.5) / 20, 1, maxValue)
                if math.abs(snapped - value) > 0.0001 then
                    option:SetValue(snapped)
                end
            end)
        end
        SnapMovementSlider(Options.Bhop_Multiplier, 10)
        SnapMovementSlider(Options.SpeedHack_Multiplier, 10)
        SnapMovementSlider(Options.Movement_FlySpeed, 50)
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
            local function DampenBhopInertia(root, deltaTime)
                local velocity = root.AssemblyLinearVelocity
                if velocity.X == 0 and velocity.Z == 0 then
                    return
                end
                local strafeHeld = UserInputService:IsKeyDown(Enum.KeyCode.A)
                    or UserInputService:IsKeyDown(Enum.KeyCode.D)
                local factor = math.exp(-(strafeHeld and 0.4 or 0.15) * math.min(deltaTime, 0.1))
                root.AssemblyLinearVelocity = Vector3.new(
                    velocity.X * factor,
                    velocity.Y,
                    velocity.Z * factor
                )
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
                if NoClipCharacter == character then
                    for _, item in ipairs(character:GetDescendants()) do SetNoClipPart(item) end
                    return
                end
                if NoClipConnection then NoClipConnection:Disconnect() end
                RestoreNoClip()
                NoClipCharacter = character
                for _, item in ipairs(character:GetDescendants()) do SetNoClipPart(item) end
                NoClipConnection = character.DescendantAdded:Connect(function(item)
                    if Toggles.Movement_NoClip.Value then SetNoClipPart(item) end
                end)
            end
            local function UpdateFly(root, humanoid, deltaTime)
                local keybind = Options.Movement_Fly_Key
                local flyEnabled = Toggles.Movement_Fly.Value
                    and (not keybind or keybind.Value == 'None' or keybind:GetState())
                if not flyEnabled then
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
                local speedKeybind = Options.SpeedHack_Key
                local speedActive = Toggles.SpeedHack_Enable.Value
                    and (not speedKeybind or speedKeybind.Value == 'None' or speedKeybind:GetState())
                local flyKeybind = Options.Movement_Fly_Key
                local flyEnabled = Toggles.Movement_Fly.Value
                    and (not flyKeybind or flyKeybind.Value == 'None' or flyKeybind:GetState())
                local movementEnabled = Toggles.Bhop_Enable.Value
                    or speedActive
                    or Toggles.Movement_AutoJump.Value
                    or Toggles.Movement_FakeDuck.Value
                    or flyEnabled
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
                        if not flyActive and not speedActive then humanoid.WalkSpeed = DEFAULT_SPEED end
                    elseif not flyActive then
                        humanoid.WalkSpeed = DEFAULT_SPEED * multiplier
                        if humanoid.FloorMaterial ~= Enum.Material.Air then humanoid.Jump = true end
                        if multiplier > 1 then
                            local camera = workspace.CurrentCamera
                            if camera then CameraMove(root, camera, DEFAULT_SPEED * (multiplier - 1), deltaTime) end
                        end
                        DampenBhopInertia(root, deltaTime)
                    end
                end
                if speedActive and not flyActive and not bhopActive then
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
                elseif not speedActive then
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
                'Skin_Knife_Skin', 'Skin_Weapon_Skin', 'Skin_Glove_Skin',
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
                local function ExportPosition(frame)
                    if not frame then return nil end
                    local position = frame.Position
                    return {
                        xScale = position.X.Scale, xOffset = position.X.Offset,
                        yScale = position.Y.Scale, yOffset = position.Y.Offset,
                    }
                end
                local function ImportPosition(frame, position)
                    if not frame or type(position) ~= 'table' then return end
                    local xs, xo = tonumber(position.xScale), tonumber(position.xOffset)
                    local ys, yo = tonumber(position.yScale), tonumber(position.yOffset)
                    if xs and xo and ys and yo then
                        frame.Position = UDim2.new(xs, xo, ys, yo)
                    end
                end
                SaveManager.Save = function(self, name, ...)
                    local success, err = OriginalSave(self, name, ...)
                    if not success then return false, err end
                    pcall(function()
                        local path = self.Folder .. '/settings/' .. name .. '.json'
                        if not isfile(path) then return end
                        local data = HttpService:JSONDecode(readfile(path))
                        data.skinChanger = SkinChanger.ExportConfig()
                        data.menuLayout = {
                            watermark = ExportPosition(Library.Watermark),
                            keybinds = ExportPosition(Library.KeybindFrame),
                            hitlog = ScriptEnvironment.ValenokHitLogPosition,
                        }
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
                        local layout = data.menuLayout
                        if type(layout) == 'table' then
                            ImportPosition(Library.Watermark, layout.watermark)
                            ImportPosition(Library.KeybindFrame, layout.keybinds)
                            if type(ScriptEnvironment.ValenokHitLogSetPosition) == 'function' then
                                ScriptEnvironment.ValenokHitLogSetPosition(layout.hitlog)
                            end
                        end
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
            
        
    
