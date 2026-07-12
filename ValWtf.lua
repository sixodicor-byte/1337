local _g = getgenv and getgenv() or {}
if _g.ValenokKeySystemUnload then
    pcall(_g.ValenokKeySystemUnload)
end

local CONSTANTS = {
    GITHUB_LIB_URL = "https://raw.githubusercontent.com/sixodicor-byte/1337/refs/heads/main/Ui.lua",
    DISCORD_URL = "https://discord.gg/9fwC4wJVyE",
    MAIN_SCRIPT = "https://raw.githubusercontent.com/sixodicor-byte/1337/refs/heads/main/ValWtfVelocity.lua",
    VALID_KEY = "7K9-F2W-M8B",
}

local function httpGet(url)
    if typeof and typeof(game) == "Instance" or type(game) == "table" then
        local ok, result = pcall(function()
            return game:HttpGet(url)
        end)
        if ok and type(result) == "string" then
            return result
        end
    end

    for _, fn in ipairs({ request, http_request, syn and syn.request }) do
        if type(fn) == "function" then
            local ok, response = pcall(fn, {
                Url = url,
                Method = "GET",
                Timeout = 15,
            })
            if ok and response and type(response.Body) == "string" then
                return response.Body
            elseif ok and type(response) == "string" then
                return response
            end
        end
    end

    return nil, "All HTTP methods failed"
end

local function safeSetText(label, text)
    if label and type(label.SetText) == "function" then
        pcall(label.SetText, label, text)
    end
end

local function loadRemote(url)
    local source, httpErr = httpGet(url)
    if not source then
        return false, "HTTP request failed: " .. tostring(httpErr)
    end

    if type(loadstring) ~= "function" then
        return false, "loadstring not available"
    end

    local compileOk, chunk, compileErr = pcall(loadstring, source)
    if not compileOk or type(chunk) ~= "function" then
        local err = compileErr or (not compileOk and tostring(chunk)) or "chunk is not a function"
        return false, "Script compilation failed: " .. tostring(err)
    end

    local executeOk, result = pcall(chunk)
    if not executeOk then
        return false, "Script execution failed: " .. tostring(result)
    end

    return true, result
end

local Library = nil
local libraryOk, libraryResult = loadRemote(CONSTANTS.GITHUB_LIB_URL)
if libraryOk then
    Library = libraryResult
end

if not Library then
    warn("Valenok Key System: Failed to load UI library: " .. tostring(libraryResult))
    return
end

local function unloadLibrary()
    local library = Library
    if not library then
        return true
    end

    local unloadOk, unloadError = pcall(function()
        library:Unload()
    end)

    if not unloadOk then
        return false, unloadError
    end

    Library = nil
    return true
end

local uiOk, uiError = pcall(function()
    local Window = Library:CreateWindow({
        Title = 'Valenok | Key System',
        Center = true,
        AutoShow = true,
    })

    local MainTab = Window:AddTab('Key System')
    local KeyGroupbox = MainTab:AddLeftGroupbox('Authentication')
    local InfoGroupbox = MainTab:AddRightGroupbox('Information')

    InfoGroupbox:AddLabel('Join Discord for key', true)
    InfoGroupbox:AddLabel('Click "Get key"')
    InfoGroupbox:AddLabel('to copy discord link')

    local keyInput = KeyGroupbox:AddInput('KeyInput', {
        Text = 'Enter key',
        Default = '',
        Placeholder = 'XXXX-XXX-XXX',
        Finished = false,
    })

    local statusLabel = KeyGroupbox:AddLabel('Status: Waiting for key...')
    local isLoading = false

    KeyGroupbox:AddButton({
        Text = 'Get key',
        Func = function()
            if type(setclipboard) == "function" then
                local copyOk = pcall(setclipboard, CONSTANTS.DISCORD_URL)
                if copyOk then
                    safeSetText(statusLabel, 'Copied to clipboard!')
                    return
                end
            end
            safeSetText(statusLabel, 'Status: Copy this link: ' .. CONSTANTS.DISCORD_URL)
        end,
    })

    KeyGroupbox:AddButton({
        Text = 'Verify key',
        Func = function()
            if isLoading then
                return
            end

            local enteredKey = ""
            if keyInput and type(keyInput.Value) == "string" then
                enteredKey = keyInput.Value
            end

            local trimOk, trimmed = pcall(function()
                return enteredKey:gsub("^%s+", ""):gsub("%s+$", "")
            end)
            if not trimOk then
                trimmed = enteredKey
            end

            if trimmed ~= CONSTANTS.VALID_KEY then
                safeSetText(statusLabel, 'Status: Invalid key!')
                return
            end

            isLoading = true
            safeSetText(statusLabel, 'Status: Key verified! Loading...')

            local unloadOk, unloadError = unloadLibrary()

            if not unloadOk then
                warn("Valenok Loader Error: Failed to unload key system: " .. tostring(unloadError))
                isLoading = false
                return
            end

            if _g.ValenokKeySystemUnload then
                _g.ValenokKeySystemUnload = nil
            end

            local waitOk = pcall(task.wait, 0.5)
            if not waitOk then
                warn("Valenok Loader: task.wait failed, continuing immediately")
            end

            local mainOk, mainError = loadRemote(CONSTANTS.MAIN_SCRIPT)
            if not mainOk then
                warn("Valenok Loader Error: " .. tostring(mainError))
            end

            isLoading = false
        end,
    })
end)

if not uiOk then
    warn("Valenok Key System: Failed to initialize UI: " .. tostring(uiError))
    unloadLibrary()
    return
end

_g.ValenokKeySystemUnload = function()
    _g.ValenokKeySystemUnload = nil
    local unloadOk, unloadError = unloadLibrary()
    if not unloadOk then
        warn("Valenok Key System: Failed to unload: " .. tostring(unloadError))
    end
end
