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
    local HandleRageHitParl
    local PlayHitSound
    local HitLogCleanup
    local BulletTracerCleanup
    local SharedNamecallState
    local ScriptEnvironment
    local CachedRayIgnoreRoot

    local function GetRayIgnoreRoot()
        if CachedRayIgnoreRoot
            and CachedRayIgnoreRoot.Parent == workspace
            and CachedRayIgnoreRoot.Name == 'Ray_Ignore'
        then
            return CachedRayIgnoreRoot
        end
        CachedRayIgnoreRoot = workspace:FindFirstChild('Ray_Ignore')
        return CachedRayIgnoreRoot
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
    local Players = VisualTab:AddLeftGroupbox('Players')
    local Removals = VisualTab:AddRightGroupbox('Removals')
    local Misc = VisualTab:AddRightGroupbox('Misc')
    local ViewModel = VisualTab:AddRightGroupbox('View Model')
    local BulletTracer = VisualTab:AddRightGroupbox('Bullet Tracer')
    local HitLog = VisualTab:AddRightGroupbox('Hit Sound')
    local HitLogDisplay = VisualTab:AddRightGroupbox('Hit Log')
    
    BulletTracer:AddToggle('BulletTracer_Enable', {
        Text = 'Enable',
        Default = false,
    }):AddColorPicker('BulletTracer_Color', {
        Default = Color3.fromRGB(255, 80, 80),
        Transparency = 0,
    })
    
    BulletTracer:AddSlider('BulletTracer_Width', {
        Text = 'Width',
        Default = 1,
        Min = 1,
        Max = 5,
        Rounding = 1,
    })
    
    BulletTracer:AddDropdown('BulletTracer_Texture', {
        Text = 'Texture',
        Values = { 'Solid', 'Lightning', 'Laser', 'Twisted Energy', 'Arrow', 'Energy Ray', 'Matrix' },
        Default = 'Solid',
    })
    
    BulletTracer:AddSlider('BulletTracer_Lifetime', {
        Text = 'Lifetime',
        Default = 0.4,
        Min = 0.05,
        Max = 2,
        Rounding = 2,
        Suffix = 's',
    })
    
    BulletTracer:AddToggle('BulletTracer_FaceCamera', { Text = 'Face camera', Default = false })
    
    local function SnapBulletTracerValue(option, min, max, step)
        option:OnChanged(function(value)
            local snapped = math.clamp(math.floor(value / step + 0.5) * step, min, max)
            if math.abs(snapped - value) > 0.0001 then
                option:SetValue(snapped)
            end
        end)
    end
    
    SnapBulletTracerValue(Options.BulletTracer_Width, 1, 5, 0.1)
    SnapBulletTracerValue(Options.BulletTracer_Lifetime, 0.05, 2, 0.05)
    
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
    
    do
        local TextureIds = {
            Solid = '',
            Lightning = 'rbxassetid://7216850022',
            Laser = 'rbxassetid://7136858729',
            ['Twisted Energy'] = 'rbxassetid://7071778278',
            Arrow = 'rbxassetid://1274378728',
            ['Energy Ray'] = 'rbxassetid://13832105797',
            Matrix = 'rbxassetid://15097610754',
        }
        local Pool, PoolIndex = {}, 1
        local PoolSize = 24
        local TracerPartSize = Vector3.new(0.05, 0.05, 0.05)
        local Folder
        local UpdateConnection
        local HookActive = false
        local NamecallHandler
        local TracerAlive = true
    
        local function GetFolder()
            if Folder and Folder.Parent then return Folder end
            Folder = Instance.new('Folder')
            Folder.Name = 'ValenokBulletTracers'
            Folder.Parent = workspace.Terrain or workspace
            return Folder
        end
    
        local function NewSlot()
            local start = Instance.new('Part')
            local finish = Instance.new('Part')
            start.Name, finish.Name = 'TracerStart', 'TracerEnd'
            start.Anchored, finish.Anchored = true, true
            start.CanCollide, finish.CanCollide = false, false
            start.CanQuery, finish.CanQuery = false, false
            start.CanTouch, finish.CanTouch = false, false
            start.Transparency, finish.Transparency = 1, 1
            start.Size, finish.Size = TracerPartSize, TracerPartSize
            start.Parent, finish.Parent = GetFolder(), GetFolder()
    
            local beam = Instance.new('Beam')
            beam.Attachment0 = Instance.new('Attachment', start)
            beam.Attachment1 = Instance.new('Attachment', finish)
            beam.LightEmission, beam.LightInfluence = 1, 0
            beam.Segments = 1
            beam.Enabled = false
            beam.Parent = start
            return { start = start, finish = finish, beam = beam, expires = 0 }
        end
    
        local function GetSlot()
            local slot = Pool[PoolIndex]
            PoolIndex = PoolIndex % PoolSize + 1
            if not slot then
                slot = NewSlot()
                Pool[#Pool + 1] = slot
            end
            return slot
        end
    
        local function StopUpdater()
            if UpdateConnection then
                UpdateConnection:Disconnect()
                UpdateConnection = nil
            end
        end
    
        local function UpdatePool()
            local now = os.clock()
            local hasActiveTracer = false
            for i = 1, #Pool do
                local beam = Pool[i].beam
                if beam.Enabled then
                    if Pool[i].expires <= now then
                        beam.Enabled = false
                    else
                        hasActiveTracer = true
                    end
                end
            end
            if not hasActiveTracer then
                StopUpdater()
            end
        end
    
        local function EnsureUpdater()
            if not UpdateConnection then
                UpdateConnection = RunService.Heartbeat:Connect(UpdatePool)
            end
        end
    
        local function Clear()
            StopUpdater()
            for i = 1, #Pool do
                Pool[i].beam.Enabled = false
            end
            if Folder then Folder:Destroy(); Folder = nil end
            table.clear(Pool)
            PoolIndex = 1
        end
    
        local function Draw(startPosition, endPosition)
            if not TracerAlive or not Toggles.BulletTracer_Enable.Value then return end
            if (endPosition - startPosition).Magnitude < 0.15 then return end
    
            local slot = GetSlot()
            local beam = slot.beam
            local width = Options.BulletTracer_Width.Value
            local texture = TextureIds[Options.BulletTracer_Texture.Value] or ''
            slot.start.CFrame, slot.finish.CFrame = CFrame.new(startPosition), CFrame.new(endPosition)
            beam.Color = ColorSequence.new(Options.BulletTracer_Color.Value)
            beam.Width0, beam.Width1 = width, width * 0.35
            beam.Texture = texture
            beam.FaceCamera = Toggles.BulletTracer_FaceCamera.Value
            beam.Transparency = NumberSequence.new(0.05)
            beam.Enabled = true
            slot.expires = os.clock() + Options.BulletTracer_Lifetime.Value
            EnsureUpdater()
        end
    
        local function GetPosition(value)
            if typeof(value) == 'Vector3' then return value end
            if typeof(value) == 'CFrame' then return value.Position end
            if typeof(value) == 'Instance' and value:IsA('BasePart') then return value.Position end
        end
    
        local function DrawFromValues(startValue, endValue)
            if not TracerAlive then return end
            local startPosition = GetPosition(startValue)
            local endPosition = GetPosition(endValue)
            if startPosition and endPosition then
                Draw(startPosition, endPosition)
            end
        end
    
        if type(hookmetamethod) == 'function' and type(getnamecallmethod) == 'function' then
            NamecallHandler = function(oldNamecall, self, ...)
                if not HookActive then
                    return oldNamecall(self, ...)
                end
                if not Toggles.BulletTracer_Enable.Value
                    and not Toggles.HitLog_Enable.Value
                    and not Toggles.HitLog_DisplayEnable.Value
                    and not HandleRageHitParl
                then
                    return oldNamecall(self, ...)
                end
    
                local method = getnamecallmethod()
                local isRemoteCall = method == 'FireServer' or method == 'FireUnreliable'
                if not isRemoteCall then
                    return oldNamecall(self, ...)
                end
    
                local remoteName = self.Name
                if remoteName == 'Trail' then
                    if Toggles.BulletTracer_Enable.Value then
                        local startValue, endValue = ...
                        task.defer(DrawFromValues, startValue, endValue)
                    end
                elseif remoteName == 'HitParl' then
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
    
        Toggles.BulletTracer_Enable:OnChanged(function()
            if not Toggles.BulletTracer_Enable.Value then Clear() end
        end)
    
        BulletTracerCleanup = function()
            TracerAlive = false
            HookActive = false
            if SharedNamecallState.handler == NamecallHandler then
                SharedNamecallState.handler = nil
            end
            Clear()
        end
    end
    
    ViewModel:AddToggle('ViewModel_WeaponChams', {
        Text = 'Weapon Chams',
        Default = false,
    }):AddColorPicker('ViewModel_WeaponColor', {
        Default = Color3.fromRGB(255, 170, 0),
        Transparency = 0,
    })
    
    ViewModel:AddDropdown('ViewModel_WeaponMaterial', {
        Text = 'Weapon Material',
        Values = { 'SmoothPlastic', 'ForceField', 'Neon', 'Glass' },
        Default = 'Neon',
    })
    
    ViewModel:AddSlider('ViewModel_WeaponTransparency', {
        Text = 'Weapon Transparency',
        Default = 0,
        Min = 0,
        Max = 100,
        Rounding = 0,
        Suffix = '%',
    })
    
    ViewModel:AddToggle('ViewModel_ArmChams', {
        Text = 'Arm Chams',
        Default = false,
    }):AddColorPicker('ViewModel_ArmColor', {
        Default = Color3.fromRGB(0, 255, 255),
        Transparency = 0,
    })
    
    ViewModel:AddDropdown('ViewModel_ArmMaterial', {
        Text = 'Arm Material',
        Values = { 'SmoothPlastic', 'ForceField', 'Neon', 'Glass' },
        Default = 'ForceField',
    })
    
    ViewModel:AddSlider('ViewModel_ArmTransparency', {
        Text = 'Arm Transparency',
        Default = 0,
        Min = 0,
        Max = 100,
        Rounding = 0,
        Suffix = '%',
    })
    
    ViewModel:AddToggle('ViewModel_RemoveSleeves', { Text = 'Remove Sleeves', Default = false })
    ViewModel:AddToggle('ViewModel_RemoveGloves', { Text = 'Remove Gloves', Default = false })
    
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
    
    local function ReloadCleanup()
        if type(Library.Unload) == 'function' then
            Library:Unload()
        end
    end
    ScriptEnvironment.__ValenokRecodeReloadCleanup = ReloadCleanup
    
    AddUnload(function()
        unload()
        if HitLogCleanup then pcall(HitLogCleanup) end
        if BulletTracerCleanup then pcall(BulletTracerCleanup) end
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
        add(workspace:FindFirstChild('Debris'))
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

    RageBot:AddSlider('RageBot_MaxWalls', {
        Text = 'Max wall',
        Default = 3,
        Min = 1,
        Max = 4,
        Rounding = 0,
    })

    local RageExploit = RageTab:AddLeftGroupbox('Exploit')

    RageExploit:AddToggle('RageExploit_KillAll', { Text = 'Kill all', Default = false })
        :AddKeyPicker('RageExploit_KillAllKey', {
            Default = 'None',
            Mode = 'Hold',
            Text = 'Kill all',
        })
    
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
        local RagePenetrationParams = RaycastParams.new()
        RagePenetrationParams.FilterType = Enum.RaycastFilterType.Include
        RagePenetrationParams.IgnoreWater = true
        local RagePenetrationInclude = {}
        local RageFrameState = { teamPlayers = {} }
        local RagePartCache = setmetatable({}, { __mode = 'k' })
        local RageSmokeRayParams = RaycastParams.new()
        RageSmokeRayParams.FilterType = Enum.RaycastFilterType.Include
        local RageSmokeInclude = {}
    
        local RageTarget = { part = nil, point = nil, walls = math.huge }
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
            if not character then
                return true
            end
            return character:FindFirstChild('PF')
                or character:FindFirstChild('Shield')
                or character:FindFirstChildOfClass('ForceField') ~= nil
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
    
            local gameStatus = workspace:FindFirstChild('Status')
            local preparation = gameStatus and gameStatus:FindFirstChild('Preparation')
            if preparation and preparation.Value == true then
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
    
        local function RageMaxWalls()
            if not Toggles.RageBot_AutoPenetration.Value then
                return 0
            end
            return math.clamp(math.floor(tonumber(Options.RageBot_MaxWalls.Value) or 3), 0, 4)
        end

        local function RageGetPenetrationBudget()
            if not Toggles.RageBot_AutoPenetration.Value then
                return 0
            end
            local character = LocalPlayer.Character
            local equipped = character and character:FindFirstChild('EquippedTool')
            local gun = character and character:FindFirstChild('Gun')
            local gunName = equipped and type(equipped.Value) == 'string' and equipped.Value or (gun and gun.Name)
            local weapons = gunName and ReplicatedStorage:FindFirstChild('Weapons')
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
            local map = workspace:FindFirstChild('Map')
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
            frame.penetrationBudget = RageGetPenetrationBudget()
            frame.rayIgnoreRoot = GetRayIgnoreRoot()
            frame.debrisRoot = workspace:FindFirstChild('Debris')
            frame.clipsRoot = map and map:FindFirstChild('Clips')
            frame.spawnPointsRoot = map and map:FindFirstChild('SpawnPoints')
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
                            for j = 1, #RageEnemyIgnoreNames do
                                RageAddRayIgnore(character:FindFirstChild(RageEnemyIgnoreNames[j]))
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

        local function RageGetPenetrationFactor(instance)
            local modifier = instance:FindFirstChild('PartModifier')
            if modifier and type(modifier.Value) == 'number' then
                return math.max(modifier.Value, 0)
            end
            if instance.Name == 'nowallbang' then
                return math.huge
            end

            local material = instance.Material
            if instance.Name == 'Grate' or material == Enum.Material.Wood or material == Enum.Material.WoodPlanks then
                return 0.1
            end
            if material == Enum.Material.DiamondPlate then
                return 3
            end
            if material == Enum.Material.CorrodedMetal
                or material == Enum.Material.Metal
                or material == Enum.Material.Concrete
                or material == Enum.Material.Brick
            then
                return 2
            end
            return 1
        end

        local function RageGetPenetrationThickness(instance, hitPosition, direction)
            RagePenetrationInclude[1] = instance
            RagePenetrationParams.FilterDescendantsInstances = RagePenetrationInclude
            local result = workspace:Raycast(hitPosition + direction, direction * -2, RagePenetrationParams)
            RagePenetrationInclude[1] = nil
            return result and (result.Position - hitPosition).Magnitude or 1
        end
    
        local function RageFinishWallRay(frame)
            RageClearRayIgnore(frame.baseIgnoreCount)
            RageRayParams.FilterDescendantsInstances = RageRayIgnore
        end
    
        local function RageGetWallCount(frame, targetPosition, targetCharacter)
            local originPosition = frame.origin
            local delta = targetPosition - originPosition
            if delta.Magnitude < 0.001 then
                return 0
            end
    
            local maxWalls = frame.maxWalls
            local penetrationBudget = frame.penetrationBudget or 0
            local penetrationUsed = 0
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

                if parent and parent:FindFirstChildOfClass('Humanoid') then
                    if targetCharacter and parent == targetCharacter then
                        break
                    end
                elseif not RageShouldPierce(instance, frame) then
                    wallCount = wallCount + 1
                    if wallCount > maxWalls then
                        break
                    end

                    local factor = RageGetPenetrationFactor(instance)
                    local thickness = RageGetPenetrationThickness(instance, result.Position, direction)
                    penetrationUsed = penetrationUsed + thickness * factor
                    if penetrationUsed >= penetrationBudget then
                        wallCount = maxWalls + 1
                        break
                    end
                end
    
                RageAddRayIgnore(instance)
                RageRayParams.FilterDescendantsInstances = RageRayIgnore
                origin = result.Position + direction * 0.05
            end
    
            RageFinishWallRay(frame)
            return wallCount
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

        local function RageGetBestPossibleDot(frame, character)
            local bestDot = -math.huge
            for i = 1, #RageHitboxOrder do
                local group = RageHitboxOrder[i]
                if RageIsHitboxEnabled(frame, group) then
                    local names = HITBOX_PARTS[group]
                    for j = 1, #names do
                        local part = RageGetCachedPart(character, names[j])
                        if part and part:IsA('BasePart') then
                            local dot = RageGetAimDot(part.Position, frame.origin, frame.lookVector)
                            if dot and dot >= frame.minimumDot and dot > bestDot then
                                bestDot = dot
                            end
                        end
                    end
                end
            end
            return bestDot
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
                    local walls = RageGetWallCount(frame, bestPoint, character)
                    if walls <= frame.maxWalls then
                        return bestPart, bestPoint, walls, bestDot
                    end
                end
            end
            return nil, nil, math.huge, nil
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

                if RageGetBestPossibleDot(frame, character) <= bestDot then
                    continue
                end
    
                local part, point, walls, dot = RagePickHitbox(frame, character)
                if not part or not point or walls > frame.maxWalls then
                    continue
                end
    
                if dot and dot >= frame.minimumDot and dot > bestDot then
                    bestDot = dot
                    RageTarget.part, RageTarget.point, RageTarget.walls = part, point, walls
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
            local weapons = ReplicatedStorage:FindFirstChild('Weapons')
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
                local weapons = ReplicatedStorage:FindFirstChild('Weapons')
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
    
            events = events or ReplicatedStorage:FindFirstChild('Events')
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
                    1,
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
            events = events or ReplicatedStorage:FindFirstChild('Events')
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
            local events = ReplicatedStorage:FindFirstChild('Events')
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
            local weapons = ReplicatedStorage:FindFirstChild('Weapons')
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
    
        local function RageUpdate()
            RageTarget.part, RageTarget.point, RageTarget.walls = nil, nil, math.huge
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
    
            local events = ReplicatedStorage:FindFirstChild('Events')
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
            RageNextFovUpdate = now + 1 / 30
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
            RageTarget.part, RageTarget.point, RageTarget.walls = nil, nil, math.huge
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
                NextClientCheck = 0
            end
    
            if clientScript and not ClientEnvironment and type(getsenv) == 'function' then
                local ok, environment = pcall(getsenv, clientScript)
                ClientEnvironment = ok and environment or nil
            end
    
            return ClientEnvironment
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

        local function RebuildWeaponCache()
            for _, list in pairs(WeaponCache) do table.clear(list) end
            local folder = WeaponsFolder
            if not folder or folder.Parent ~= ReplicatedStorage then
                WeaponsDirty = false
                return
            end
            for _, weapon in ipairs(folder:GetChildren()) do
                local spread = weapon:FindFirstChild('Spread')
                local recoil = spread and spread:FindFirstChild('Recoil')
                local fireRate = weapon:FindFirstChild('FireRate')
                local equipTime = weapon:FindFirstChild('EquipTime')
                local reloadTime = weapon:FindFirstChild('ReloadTime')
                local auto = weapon:FindFirstChild('Auto')
                if recoil then WeaponCache.Recoil[#WeaponCache.Recoil + 1] = recoil end
                if fireRate then WeaponCache.FireRate[#WeaponCache.FireRate + 1] = fireRate end
                if equipTime then WeaponCache.EquipTime[#WeaponCache.EquipTime + 1] = equipTime end
                if reloadTime then WeaponCache.ReloadTime[#WeaponCache.ReloadTime + 1] = reloadTime end
                if auto then WeaponCache.Auto[#WeaponCache.Auto + 1] = auto end
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
            local folder = ReplicatedStorage:FindFirstChild('Weapons')
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
    
        local function ApplyGunMods()
            if Toggles.GunMods_RemoveSpread.Value then
                local client = GetClientEnvironment()
                if client then
                    local current = rawget(client, 'accuracy_sd')
                    if SavedAccuracySd == nil and type(current) == 'number' then
                        SavedAccuracySd = current
                    end
                    if current == 0.001 then
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
                local rapidRate = (tonumber(Options.GunMods_RapidFireRate.Value) or 10) / 1000
                for i = 1, #WeaponCache.FireRate do ApplyValue(WeaponCache.FireRate[i], SavedValues.FireRate, rapidRate) end
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

        local function ModsEnabled()
            return Toggles.GunMods_RemoveSpread.Value or Toggles.GunMods_RemoveRecoil.Value
                or Toggles.GunMods_RapidFire.Value or Toggles.GunMods_FastEquip.Value
                or Toggles.GunMods_FastReload.Value or Toggles.GunMods_FullAuto.Value
        end

        local function RefreshModConnection()
            if ModsEnabled() then
                ApplyGunMods()
                if not ModConnection then ModConnection = RunService.Heartbeat:Connect(ApplyGunMods) end
            elseif ModConnection then
                ModConnection:Disconnect()
                ModConnection = nil
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
                RefreshModConnection()
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
            if child.Name == 'Weapons' then BindWeaponsFolder(child) end
        end)
        RootConnections[#RootConnections + 1] = ReplicatedStorage.ChildRemoved:Connect(function(child)
            if child == WeaponsFolder then BindWeaponsFolder(nil) end
        end)
        BindWeaponsFolder(ReplicatedStorage:FindFirstChild('Weapons'))
        RefreshModConnection()
    
        AddUnload(function()
            if ModConnection then ModConnection:Disconnect(); ModConnection = nil end
            for i = 1, #RootConnections do RootConnections[i]:Disconnect() end
            table.clear(RootConnections)
            DisconnectWeaponConnections()
            RestoreAll()
        end)
    end
    
    local GetCurrentSpreadRadius
    
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
    
        GetCurrentSpreadRadius = function(camera)
            if not camera then
                return 0
            end
    
            local spreadAngle = GetSpreadAngle()
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
                if not character or not humanoid or humanoid.Health <= 0 then
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
                NextFovUpdate = now + 1 / 30
                UpdateFovCircle(camera)
            end
    
            if now < NextUpdate then
                return
            end
            NextUpdate = now + GetUpdateInterval()
    
            if not Options.Aimbot_Key:GetState() then
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
        local PenetrationParams = RaycastParams.new()
        local PenetrationInclude = {}
        local FireRemote
        local DelayTarget
        local DelayUntil = 0
        local LastFireAt = 0
        local NextUpdate = 0
        RayParams.FilterType = Enum.RaycastFilterType.Exclude
        PenetrationParams.FilterType = Enum.RaycastFilterType.Include
        PenetrationParams.IgnoreWater = true
    
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
        local HITBOX_CENTER_SCALE = 0.8
    
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
            local penetration = weapon and weapon:FindFirstChild('Penetration')
            return penetration and type(penetration.Value) == 'number' and math.max(penetration.Value, 0) * 0.01 or 0
        end

        local function GetTriggerWallFactor(part)
            local modifier = part:FindFirstChild('PartModifier')
            if modifier and type(modifier.Value) == 'number' then
                return math.max(modifier.Value, 0), true
            end

            local material = part.Material
            if part.Name == 'Grate' or material == Enum.Material.Wood or material == Enum.Material.WoodPlanks then
                return 0.1, false
            end
            if material == Enum.Material.DiamondPlate then
                return 3, false
            end
            if material == Enum.Material.CorrodedMetal
                or material == Enum.Material.Metal
                or material == Enum.Material.Concrete
                or material == Enum.Material.Brick
            then
                return 2, false
            end
            return 1, false
        end

        local function GetTriggerWallThickness(part, hitPosition, direction)
            PenetrationInclude[1] = part
            PenetrationParams.FilterDescendantsInstances = PenetrationInclude
            local result = workspace:Raycast(hitPosition + direction, direction * -2, PenetrationParams)
            PenetrationInclude[1] = nil
            return result and (result.Position - hitPosition).Magnitude or 1
        end

        local function CanTriggerPenetrate(part, hitPosition, direction, used, wallCount, budget)
            if part.Name == 'nowallbang' then
                return false, used, wallCount
            end
            if part.Transparency >= 1 or not part.CanCollide or part.Name == 'Glass' or part.Name == 'Cardboard' then
                return true, used, wallCount
            end

            local factor, hasModifier = GetTriggerWallFactor(part)
            local autoWall = Toggles.Triggerbot_AutoWall.Value
            if not autoWall and (hasModifier or factor ~= 0.1) then
                return false, used, wallCount
            end
            if factor <= 0 then
                return true, used, wallCount
            end
            if wallCount >= 4 then
                return false, used, wallCount
            end

            used = used + GetTriggerWallThickness(part, hitPosition, direction) * factor
            if used >= budget then
                return false, used, wallCount
            end
            return true, used, wallCount + 1
        end
    
        -- луч в локальном AABB части, ужатом к центру (scale)
        local function RayHitsPartCenter(part, origin, direction, scale)
            local half = part.Size * 0.5 * scale
            local localOrigin = part.CFrame:PointToObjectSpace(origin)
            local localDir = part.CFrame:VectorToObjectSpace(direction)
            local tMin = 0
            local tMax = 5000
            local ox, oy, oz = localOrigin.X, localOrigin.Y, localOrigin.Z
            local dx, dy, dz = localDir.X, localDir.Y, localDir.Z
            local hx, hy, hz = half.X, half.Y, half.Z
            if math.abs(dx) <= 1e-8 then
                if ox < -hx or ox > hx then return false end
            else
                local inv = 1 / dx
                local t1, t2 = (-hx - ox) * inv, (hx - ox) * inv
                if t1 > t2 then t1, t2 = t2, t1 end
                if t1 > tMin then tMin = t1 end
                if t2 < tMax then tMax = t2 end
                if tMin > tMax then return false end
            end
            if math.abs(dy) <= 1e-8 then
                if oy < -hy or oy > hy then return false end
            else
                local inv = 1 / dy
                local t1, t2 = (-hy - oy) * inv, (hy - oy) * inv
                if t1 > t2 then t1, t2 = t2, t1 end
                if t1 > tMin then tMin = t1 end
                if t2 < tMax then tMax = t2 end
                if tMin > tMax then return false end
            end
            if math.abs(dz) <= 1e-8 then
                if oz < -hz or oz > hz then return false end
            else
                local inv = 1 / dz
                local t1, t2 = (-hz - oz) * inv, (hz - oz) * inv
                if t1 > t2 then t1, t2 = t2, t1 end
                if t1 > tMin then tMin = t1 end
                if t2 < tMax then tMax = t2 end
                if tMin > tMax then return false end
            end
            return tMax >= 0 and tMin <= tMax
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
                or not humanoid or humanoid.Health <= 0
            then
                return nil
            end
    
            CollectSelectedParts(character, SelectedParts)
            if #SelectedParts == 0 then
                return nil
            end
    
            local cameraPosition = cameraCFrame.Position
            local lookVector = cameraCFrame.LookVector
            local bestPart, bestDot = nil, -2
    
            for i = 1, #SelectedParts do
                local selectedPart = SelectedParts[i]
                if RayHitsPartCenter(selectedPart, cameraPosition, lookVector, HITBOX_CENTER_SCALE) then
                    local direction = selectedPart.Position - cameraPosition
                    local magnitude = direction.Magnitude
                    if magnitude > 1e-4 then
                        local dot = lookVector:Dot(direction / magnitude)
                        if dot > bestDot then
                            bestDot = dot
                            bestPart = selectedPart
                        end
                    end
                end
            end
    
            if not bestPart then
                return nil
            end
    
            return player, character, bestPart
        end
    
        local function GetHitChance(part, camera)
            if not part then
                return 0
            end
    
            local spreadRadius = GetCurrentSpreadRadius and GetCurrentSpreadRadius(camera) or 0
            if spreadRadius <= 0 then
                return 100
            end
    
            local distance = (part.Position - camera.CFrame.Position).Magnitude
            if distance <= 1e-3 then
                return 100
            end
    
            local spreadAngle = math.rad(spreadRadius * 60 / camera.ViewportSize.Y)
            local partRadius = math.max(part.Size.X, part.Size.Y, part.Size.Z) * 0.5
            if part.Name == 'Head' or part.Name == 'HeadHB' or part.Name == 'FakeHead' then
                partRadius = math.max(partRadius, 0.6)
            end
    
            local targetAngle = math.atan(partRadius / distance)
            return math.clamp(targetAngle / math.max(spreadAngle, 1e-6) * 100, 0, 100)
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
    
            local player, _, part = GetTarget(camera)
            if not player then
                ResetDelay()
                return
            end
    
            if GetHitChance(part, camera) + 1e-3 < Options.Triggerbot_HitChance.Value then
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

        local function BindDebris(folder)
            if BoundDebris == folder then return end
            for i = 1, #DebrisConnections do DebrisConnections[i]:Disconnect() end
            table.clear(DebrisConnections)
            RemoveAllDrops()
            table.clear(DropItems)
            table.clear(DropIndex)
            BoundDebris = folder
            if not folder then return end
            for _, item in ipairs(folder:GetChildren()) do
                DropItems[#DropItems + 1] = item
                DropIndex[item] = #DropItems
            end
            DebrisConnections[#DebrisConnections + 1] = folder.ChildAdded:Connect(function(item)
                if not DropIndex[item] then
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
    
        local function IsDroppedWeapon(item, weapons)
            if not item or item:GetAttribute('RagDoll') then
                return false
            end
            return weapons and weapons:FindFirstChild(item.Name) ~= nil
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
            local debris = workspace:FindFirstChild('Debris')
            local weapons = ReplicatedStorage:FindFirstChild('Weapons')
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
                    RemoveDrop(item)
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
        local NextUpdate = 0
    
        local function DisconnectCache()
            for i = 1, #Connections do
                Connections[i]:Disconnect()
            end
            table.clear(Connections)
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
    
        local function EnsureCache(arms)
            if Cache.Arms == arms then
                return
            end
    
            DisconnectCache()
            RebuildCache(arms)
            Connections[#Connections + 1] = arms.DescendantAdded:Connect(function()
                if Cache.Arms == arms then
                    RebuildCache(arms)
                end
            end)
            Connections[#Connections + 1] = arms.DescendantRemoving:Connect(function()
                if Cache.Arms == arms then
                    RebuildCache(arms)
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
            local appearance = part:FindFirstChildOfClass('SurfaceAppearance')
            if appearance then
                appearance:Destroy()
            end
            if part.Name == 'StatClock' then
                part:ClearAllChildren()
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
            EnsureCache(arms)
    
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
    
        local function ApplyNow()
            UpdateViewModelVisuals()
        end
    
        for _, option in ipairs({
            Toggles.ViewModel_WeaponChams, Toggles.ViewModel_ArmChams, Toggles.ViewModel_RemoveSleeves, Toggles.ViewModel_RemoveGloves,
            Options.ViewModel_WeaponColor, Options.ViewModel_WeaponMaterial, Options.ViewModel_WeaponTransparency,
            Options.ViewModel_ArmColor, Options.ViewModel_ArmMaterial, Options.ViewModel_ArmTransparency,
        }) do
            option:OnChanged(ApplyNow)
        end
    
        Library:GiveSignal(RunService.RenderStepped:Connect(function()
            local now = os.clock()
            if now < NextUpdate then
                return
            end
            NextUpdate = now + 0.1
            UpdateViewModelVisuals()
        end))
    
        AddUnload(DisconnectCache)
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
    
        local function IsThirdPersonActive()
            return Toggles.ThirdPerson_Enable.Value and Options.ThirdPerson_Key:GetState()
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
    
        AddUnload(function()
            UnbindThroughWalls()
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
    
    Window:AddTab('World')
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
    
        MoveConnection = RunService.Heartbeat:Connect(function(deltaTime)
            local movementEnabled = Toggles.Bhop_Enable.Value
                or Toggles.SpeedHack_Enable.Value
                or Toggles.Movement_AutoJump.Value
                or Toggles.Movement_Fly.Value
                or Toggles.Movement_NoClip.Value
            if not movementEnabled then
                if FlyHumanoid and FlyHumanoid.Parent then FlyHumanoid.PlatformStand = false end
                FlyHumanoid = nil
                if SpeedHumanoid then RestoreSpeed() end
                if NoClipConnection then NoClipConnection:Disconnect(); NoClipConnection = nil end
                if NoClipCharacter then RestoreNoClip() end
                return
            end
            local character, humanoid, root = GetRig()
            if not character then return end
            UpdateNoClip(character)
    
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
    SaveManager:SetIgnoreIndexes({ 'MenuKeybind' })
    
    local CONFIG_FOLDER = 'ValenokRecode'
    if not isfolder(CONFIG_FOLDER) then
        makefolder(CONFIG_FOLDER)
    end
    
    ThemeManager:SetFolder(CONFIG_FOLDER)
    SaveManager:SetFolder(CONFIG_FOLDER)
    
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
    
