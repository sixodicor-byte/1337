if getgenv().ValenokKeySystemUnload then
    pcall(getgenv().ValenokKeySystemUnload)
end

local CONSTANTS = {
    -- После деплоя Worker вставь свой URL:
    -- https://violity-key-api.<твой-сабдомен>.workers.dev/verify
    API_URL = "https://violity.bdimka251212.workers.dev/verify",
    TIME_URL = "https://violity.bdimka251212.workers.dev/time",

    -- Если задал API_SECRET в Cloudflare — впиши тот же сюда. Иначе оставь "".
    API_SECRET = "",

    GITHUB_LIB_URL = "https://raw.githubusercontent.com/sixodicor-byte/1337/refs/heads/main/NewLib.lua",
    DISCORD_URL = "https://discord.gg/8GRGXy742u",
    KEY_FILE = "Key/key.json",
}

local Library
local HttpService = game:GetService("HttpService")
local RbxAnalyticsService = game:GetService("RbxAnalyticsService")

local function trim(s)
    return tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function getHWID()
    if type(gethwid) == "function" then
        return tostring(gethwid())
    elseif type(get_hwid) == "function" then
        return tostring(get_hwid())
    end
    return tostring(RbxAnalyticsService:GetClientId())
end

local function httpRequest(opts)
    local req = (syn and syn.request)
        or (http and http.request)
        or http_request
        or request
        or (fluxus and fluxus.request)

    if type(req) ~= "function" then
        error("Executor does not support custom HTTP requests")
    end

    return req(opts)
end

local function safeReadKey()
    if type(isfile) ~= "function" or type(readfile) ~= "function" then
        return ""
    end

    local success, value = pcall(function()
        if not isfile(CONSTANTS.KEY_FILE) then
            return ""
        end

        local decoded = HttpService:JSONDecode(readfile(CONSTANTS.KEY_FILE))
        return type(decoded) == "table" and decoded.key or ""
    end)

    if success and type(value) == "string" then
        return trim(value)
    end

    return ""
end

local function safeSaveKey(key)
    if type(writefile) ~= "function" then
        return false
    end

    return pcall(function()
        if type(makefolder) == "function" and (type(isfolder) ~= "function" or not isfolder("Key")) then
            makefolder("Key")
        end
        writefile(CONSTANTS.KEY_FILE, HttpService:JSONEncode({ key = key }))
    end)
end

local function mapApiError(err, status)
    local msg = trim(err)
    if msg == "" then
        msg = "Unknown error"
    end

    local lower = msg:lower()
    if lower:find("expired", 1, true) or msg:find("не действителен", 1, true) or msg:find("истёк", 1, true) then
        return "Ключ больше не действителен (истёк срок)"
    end
    if lower:find("banned", 1, true) or msg:find("заблокирован", 1, true) then
        if lower:find("hwid", 1, true) or msg:find("HWID", 1, true) then
            return "Ваш HWID заблокирован"
        end
        return "Ключ заблокирован"
    end
    if lower:find("invalid key", 1, true) or msg:find("Неверный ключ", 1, true) then
        return "Неверный ключ"
    end
    if lower:find("another key", 1, true) or msg:find("другому ключу", 1, true) then
        return "Ваш HWID привязан к другому ключу"
    end
    if lower:find("another device", 1, true) or msg:find("другом устройстве", 1, true) then
        return "Этот ключ уже активирован на другом устройстве"
    end
    if lower:find("unauthorized", 1, true) then
        return "Нет доступа (API secret)"
    end
    if status == 404 then
        return "API не найден (проверь URL)"
    end
    if status == 500 then
        return "Ошибка сервера: " .. msg
    end
    return msg
end

local function verifyWithApi(key, hwid)
    local headers = {
        ["Content-Type"] = "application/json",
    }
    if CONSTANTS.API_SECRET ~= "" then
        headers["X-Api-Secret"] = CONSTANTS.API_SECRET
    end

    local res = httpRequest({
        Url = CONSTANTS.API_URL,
        Method = "POST",
        Headers = headers,
        Body = HttpService:JSONEncode({
            key = key,
            hwid = hwid,
        }),
    })

    local status = tonumber(res.StatusCode or res.Status or res.status_code or 0) or 0
    local body = res.Body or res.body or ""

    local decoded
    local ok = pcall(function()
        decoded = HttpService:JSONDecode(body)
    end)

    if not ok or type(decoded) ~= "table" then
        error("Плохой ответ API (" .. tostring(status) .. ")")
    end

    return decoded, status
end

local function checkKeyTimeWithApi(key)
    local headers = {
        ["Content-Type"] = "application/json",
    }
    if CONSTANTS.API_SECRET ~= "" then
        headers["X-Api-Secret"] = CONSTANTS.API_SECRET
    end

    local res = httpRequest({
        Url = CONSTANTS.TIME_URL,
        Method = "POST",
        Headers = headers,
        Body = HttpService:JSONEncode({
            key = key,
        }),
    })

    local status = tonumber(res.StatusCode or res.Status or res.status_code or 0) or 0
    local body = res.Body or res.body or ""

    local decoded
    local ok = pcall(function()
        decoded = HttpService:JSONDecode(body)
    end)

    if not ok or type(decoded) ~= "table" then
        error("Плохой ответ API (" .. tostring(status) .. ")")
    end

    return decoded, status
end

local function formatTimeLeftLocal(expiresAt, fallbackText)
    local exp = tonumber(expiresAt)
    if not exp then
        return fallbackText or "lifetime"
    end

    local left = math.floor(exp - os.time())
    if left <= 0 then
        return "истёк"
    end

    local days = math.floor(left / 86400)
    local hours = math.floor((left % 86400) / 3600)
    local mins = math.floor((left % 3600) / 60)
    local secs = left % 60

    if days > 0 then
        return ("%dд %dч"):format(days, hours)
    end
    if hours > 0 then
        return ("%dч %dм"):format(hours, mins)
    end
    if mins > 0 then
        return ("%dм %dс"):format(mins, secs)
    end
    return ("%dс"):format(math.max(1, secs))
end

pcall(function()
    local source = game:HttpGet(CONSTANTS.GITHUB_LIB_URL)
    local loader = loadstring(source)
    if type(loader) == "function" then
        Library = loader()
    end
end)

if not Library then
    warn("Violity Key System: Failed to load UI library")
    return
end

local windowSuccess, Window = pcall(function()
    return Library:CreateWindow({
        Title = 'Violity | Loader',
        Center = true,
        AutoShow = true,
    })
end)

if not windowSuccess or not Window then
    warn("Violity Loader: Failed to create window")
    return
end

local MainTab = Window:AddTab('Key System')

local KeyGroupbox = MainTab:AddLeftGroupbox('Authentication')
local InfoGroupbox = MainTab:AddRightGroupbox('Credits')

InfoGroupbox:AddLabel('Join Discord for key', true)
InfoGroupbox:AddLabel('1) Check time / Verify  2) Inject', true)
InfoGroupbox:AddLabel('Verify key before Inject', true)
InfoGroupbox:AddLabel('Made by SkyQred and Petrosyanhvh')

local KeyInfoBox = MainTab:AddRightGroupbox('Key info')
local keyInfoKeyLabel = KeyInfoBox:AddLabel('Key: —', true)
local keyInfoTypeLabel = KeyInfoBox:AddLabel('Type: —', true)
local keyInfoDurationLabel = KeyInfoBox:AddLabel('Duration: —', true)
local keyInfoTimeLabel = KeyInfoBox:AddLabel('Time left: —', true)
local keyInfoActivatedLabel = KeyInfoBox:AddLabel('Activated: —', true)
local keyInfoStatusLabel = KeyInfoBox:AddLabel('Status: waiting', true)

local savedKey = safeReadKey()

local keyInput = KeyGroupbox:AddInput('KeyInput', {
    Text = 'Enter key',
    Default = savedKey,
    Placeholder = 'XXXX-XXX-XXX',
    Finished = false,
})

local statusLabel = KeyGroupbox:AddLabel('Waiting for key...', true)
local isBusy = false
local pendingScript = nil
local pendingMeta = nil
local lastKeyInfo = nil
local timeLeftLoop = true

local function setLabel(label, text)
    if label and label.SetText then
        label:SetText(tostring(text or ""):gsub("\n", "<br/>"))
    end
end

local function setInfo(text)
    setLabel(statusLabel, text)
end

local function setError(text)
    setLabel(statusLabel, "Error: " .. tostring(text or "Unknown error"))
    setLabel(keyInfoStatusLabel, "Status: error")
end

local function isExpiredMeta(meta)
    if type(meta) ~= "table" then
        return false
    end
    local exp = tonumber(meta.expiresAt)
    if not exp then
        return false
    end
    return (exp - os.time()) <= 0
end

local function resolveTimeLeftText(meta)
    if type(meta) ~= "table" then
        return "—"
    end
    if isExpiredMeta(meta) or meta.expired then
        return "Expired"
    end
    if meta.activated == false then
        return meta.timeLeftText or "не активирован"
    end
    if meta.expiresAt then
        local text = formatTimeLeftLocal(meta.expiresAt, meta.timeLeftText)
        if text == "истёк" then
            return "Expired"
        end
        return text
    end
    return meta.timeLeftText or "lifetime"
end

local function updateKeyInfoPanel(meta, statusText)
    lastKeyInfo = type(meta) == "table" and meta or nil

    if type(meta) ~= "table" then
        setLabel(keyInfoKeyLabel, "Key: —")
        setLabel(keyInfoTypeLabel, "Type: —")
        setLabel(keyInfoDurationLabel, "Duration: —")
        setLabel(keyInfoTimeLabel, "Time left: —")
        setLabel(keyInfoActivatedLabel, "Activated: —")
        setLabel(keyInfoStatusLabel, "Status: " .. tostring(statusText or "waiting"))
        return
    end

    local expired = isExpiredMeta(meta) or meta.expired
    local activatedText
    if expired then
        activatedText = "Yes"
    elseif meta.activated == false then
        activatedText = "No"
    elseif meta.activated == true or meta.expiresAt then
        activatedText = "Yes"
    else
        activatedText = "—"
    end

    setLabel(keyInfoKeyLabel, "Key: " .. tostring(meta.key or "—"))
    setLabel(keyInfoTypeLabel, "Type: " .. tostring(meta.type or "—"))
    setLabel(keyInfoDurationLabel, "Duration: " .. tostring(meta.duration or "—"))
    setLabel(keyInfoTimeLabel, "Time left: " .. resolveTimeLeftText(meta))
    setLabel(keyInfoActivatedLabel, "Activated: " .. activatedText)
    setLabel(
        keyInfoStatusLabel,
        "Status: " .. tostring(statusText or (expired and "Expired" or "ok"))
    )
end

local function updateInfoPanel()
    if type(pendingMeta) ~= "table" then
        updateKeyInfoPanel(nil, "waiting")
        return
    end
    updateKeyInfoPanel(pendingMeta, "verified — press Inject")
end

local function runInject()
    if isBusy then
        return
    end
    if type(pendingScript) ~= "string" or pendingScript == "" then
        setError("Сначала нажми Verify key")
        return
    end

    isBusy = true
    setInfo("Injecting...")
    updateKeyInfoPanel(pendingMeta or lastKeyInfo, "injecting")

    local scriptSource = pendingScript
    pendingScript = nil

    task.wait(0.2)

    if Library then
        pcall(function()
            Library:Unload()
        end)
    end

    task.wait(0.2)

    local runOk, runErr = pcall(function()
        local chunk = loadstring(scriptSource)
        if type(chunk) ~= "function" then
            error("Script did not return executable code")
        end
        chunk()
    end)

    if not runOk then
        warn("Violity Loader Error: " .. tostring(runErr))
        setError(tostring(runErr))
        isBusy = false
    end
end

KeyGroupbox:AddButton({
    Text = 'Get key',
    Func = function()
        if type(setclipboard) == "function" and pcall(setclipboard, CONSTANTS.DISCORD_URL) then
            setInfo('Discord link copied')
        else
            setError('Не удалось скопировать ссылку')
        end
    end,
})

KeyGroupbox:AddButton({
    Text = 'Verify key',
    Func = function()
        if isBusy then
            return
        end

        local enteredKey = keyInput and keyInput.Value
        if enteredKey == nil then
            setError('Не удалось прочитать ключ')
            return
        end

        local trimmed = trim(enteredKey)
        if trimmed == "" then
            setError('Сначала введи ключ')
            return
        end

        if CONSTANTS.API_URL:find("YOUR_SUBDOMAIN", 1, true) then
            setError('API URL не задан')
            return
        end

        isBusy = true
        pendingScript = nil
        pendingMeta = nil
        setInfo('Verifying...')
        updateKeyInfoPanel({ key = trimmed }, "verifying")

        local hwid = getHWID()
        local callOk, decoded, httpStatus = pcall(verifyWithApi, trimmed, hwid)

        if not callOk then
            isBusy = false
            setError(tostring(decoded))
            warn("Violity Loader Error: " .. tostring(decoded))
            return
        end

        if type(decoded) ~= "table" then
            isBusy = false
            setError("Плохой ответ API")
            return
        end

        if not decoded.ok then
            isBusy = false
            local errText = tostring(decoded.error or "")
            local lower = errText:lower()
            local info = {
                key = trimmed,
                type = decoded.type,
                duration = decoded.duration,
                expiresAt = decoded.expiresAt,
                timeLeftText = decoded.timeLeftText,
                activated = decoded.activated,
                expired = false,
            }
            if lower:find("expired", 1, true)
                or errText:find("не действителен", 1, true)
                or errText:find("истёк", 1, true)
            then
                info.expired = true
                info.timeLeftText = "Expired"
                updateKeyInfoPanel(info, "Expired")
                setError("Expired")
            else
                updateKeyInfoPanel(info, "error")
                setError(mapApiError(decoded.error, httpStatus))
            end
            return
        end

        if type(decoded.script) ~= "string" or decoded.script == "" then
            isBusy = false
            setError("Пустой скрипт от API")
            return
        end

        safeSaveKey(trimmed)
        pendingScript = decoded.script
        pendingMeta = {
            key = trimmed,
            type = decoded.type or "Unknown",
            duration = decoded.duration or "lifetime",
            expiresAt = decoded.expiresAt,
            timeLeftText = decoded.timeLeftText or "lifetime",
            activated = decoded.expiresAt ~= nil or decoded.duration == "lifetime" or decoded.duration == nil,
        }

        updateInfoPanel()
        setInfo("Key verified. Press Inject")
        isBusy = false
    end,
})

KeyGroupbox:AddButton({
    Text = 'Inject',
    Func = runInject,
})

KeyGroupbox:AddButton({
    Text = 'Check time left',
    Func = function()
        if isBusy then
            return
        end

        local enteredKey = keyInput and keyInput.Value
        if enteredKey == nil then
            setError('Не удалось прочитать ключ')
            return
        end

        local trimmed = trim(enteredKey)
        if trimmed == "" then
            setError('Сначала введи ключ')
            return
        end

        isBusy = true
        setInfo('Checking time...')
        updateKeyInfoPanel({ key = trimmed }, "checking time")

        local callOk, decoded, httpStatus = pcall(checkKeyTimeWithApi, trimmed)

        if not callOk then
            isBusy = false
            setError(tostring(decoded))
            return
        end

        if type(decoded) ~= "table" then
            isBusy = false
            setError("Плохой ответ API")
            return
        end

        local info = {
            key = trimmed,
            type = decoded.type,
            duration = decoded.duration,
            expiresAt = decoded.expiresAt,
            timeLeftText = decoded.timeLeftText,
            activated = decoded.activated,
            expired = false,
        }

        if not decoded.ok then
            isBusy = false
            local errText = tostring(decoded.error or "")
            local lower = errText:lower()
            if lower:find("expired", 1, true)
                or errText:find("не действителен", 1, true)
                or errText:find("истёк", 1, true)
                or decoded.timeLeftText == "истёк"
            then
                info.expired = true
                info.timeLeftText = "Expired"
                updateKeyInfoPanel(info, "Expired")
                setError("Expired")
            else
                updateKeyInfoPanel(info, "error")
                setError(mapApiError(decoded.error, httpStatus))
            end
            return
        end

        if info.activated == false then
            info.timeLeftText = decoded.timeLeftText or "не активирован"
        elseif info.expiresAt and (tonumber(info.expiresAt) - os.time()) <= 0 then
            info.expired = true
            info.timeLeftText = "Expired"
        end

        updateKeyInfoPanel(info, info.expired and "Expired" or (info.activated and "activated" or "not activated"))
        setInfo("Time left: " .. resolveTimeLeftText(info))
        isBusy = false
    end,
})

task.spawn(function()
    while timeLeftLoop do
        local meta = pendingMeta or lastKeyInfo
        if type(meta) == "table" and meta.expiresAt and not meta.expired then
            local left = tonumber(meta.expiresAt) - os.time()
            if left <= 0 then
                pendingScript = nil
                meta.expired = true
                meta.timeLeftText = "Expired"
                if pendingMeta == meta then
                    pendingMeta = nil
                end
                updateKeyInfoPanel(meta, "Expired")
                setError("Expired")
            else
                setLabel(keyInfoTimeLabel, "Time left: " .. formatTimeLeftLocal(meta.expiresAt, meta.timeLeftText))
            end
        end
        task.wait(1)
    end
end)

getgenv().ValenokKeySystemUnload = function()
    timeLeftLoop = false
    pcall(function()
        if Library then
            Library:Unload()
        end
    end)
end
