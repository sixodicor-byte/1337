if getgenv().ValenokKeySystemUnload then
    pcall(getgenv().ValenokKeySystemUnload)
end

local CONSTANTS = {
    -- После деплоя Worker вставь свой URL:
    -- https://violity-key-api.<твой-сабдомен>.workers.dev/verify
    API_URL = "https://violity.bdimka251212.workers.dev/verify",

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
        error("Bad API response (" .. tostring(status) .. "): " .. tostring(body))
    end

    return decoded, status
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
local InfoGroupbox = MainTab:AddRightGroupbox('Information')

InfoGroupbox:AddLabel('Join Discord for key', true)
InfoGroupbox:AddLabel('Click "Get key" to copy the Discord link to clipboard.')
InfoGroupbox:AddLabel('Made by SkyQred and Petrosyanhvh')

local savedKey = safeReadKey()

local keyInput = KeyGroupbox:AddInput('KeyInput', {
    Text = 'Enter key',
    Default = savedKey,
    Placeholder = 'XXXX-XXX-XXX',
    Finished = false,
})

local statusLabel = KeyGroupbox:AddLabel('Waiting for key...', true)
local isLoading = false

local function setInfo(text)
    if statusLabel and statusLabel.SetText then
        statusLabel:SetText(tostring(text or ""))
    end
end

local function setError(text)
    if statusLabel and statusLabel.SetText then
        statusLabel:SetText("Error: " .. tostring(text or "Unknown error"))
    end
end

KeyGroupbox:AddButton({
    Text = 'Get key',
    Func = function()
        if type(setclipboard) == "function" and pcall(setclipboard, CONSTANTS.DISCORD_URL) then
            setInfo('Link copied to clipboard')
        else
            setError('No link')
        end
    end,
})

KeyGroupbox:AddButton({
    Text = 'Verify key',
    Func = function()
        if isLoading then
            return
        end

        local enteredKey = keyInput and keyInput.Value
        if enteredKey == nil then
            setError('Unable to read key input')
            return
        end

        local trimmed = trim(enteredKey)
        if trimmed == "" then
            setError('Enter a key first')
            return
        end

        if CONSTANTS.API_URL:find("YOUR_SUBDOMAIN", 1, true) then
            setError('API URL is not set')
            return
        end

        isLoading = true
        setInfo('Loading...')

        local hwid = getHWID()
        local ok, result = pcall(verifyWithApi, trimmed, hwid)

        if not ok then
            isLoading = false
            setError(tostring(result))
            warn("Violity Loader Error: " .. tostring(result))
            return
        end

        if not result.ok then
            isLoading = false
            setError(tostring(result.error or "Invalid key"))
            return
        end

        if type(result.script) ~= "string" or result.script == "" then
            isLoading = false
            setError('Empty script from API')
            return
        end

        safeSaveKey(trimmed)
        setInfo('Success')

        task.wait(0.8)

        if Library then
            pcall(function()
                Library:Unload()
            end)
        end

        task.wait(0.2)

        local runOk, runErr = pcall(function()
            local chunk = loadstring(result.script)
            if type(chunk) ~= "function" then
                error("Script did not return executable code")
            end
            chunk()
        end)

        if not runOk then
            warn("Violity Loader Error: " .. tostring(runErr))
            setError(tostring(runErr))
        end

        isLoading = false
    end,
})

getgenv().ValenokKeySystemUnload = function()
    pcall(function()
        if Library then
            Library:Unload()
        end
    end)
end
