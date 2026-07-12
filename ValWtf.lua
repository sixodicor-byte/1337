local _g = getgenv and getgenv() or {}
if _g.ValenokKeySystemUnload then
    pcall(_g.ValenokKeySystemUnload)
end

local _b = string.byte
local _c = string.char
local _f = string.format
local _s = string.sub
local _t = table.concat
local _i = ipairs
local _r = math.random
local _x = setmetatable
local _j = rawset
local _k = rawget
local _l = rawequal
local _n = rawlen
local _p = pcall
local _y = type
local _z = typeof
local _w = task.wait
local _q = warn
local _d = tostring
local _e = error
local _h = select
local _m = getfenv and getfenv() or {}
local _o = setfenv
local _u = next
local _v = pairs

local _xor = function(a, b)
    local r = {}
    for i = 1, #a do
        r[i] = _c(_b(_s(a, i, i)) ~ _b(_s(b, (i - 1) % #b + 1, (i - 1) % #b + 1)))
    end
    return _t(r)
end

local _dec = function(enc, key)
    local parts = {}
    for i = 1, #enc do
        parts[i] = _c(enc[i] ~ _b(_s(key, (i - 1) % #key + 1, (i - 1) % #key + 1)))
    end
    return _t(parts)
end

local _key1 = "vK9xQ2mZ"
local _key2 = "pL7nR4wS"
local _key3 = "jH3bT6cF"

local _enc_lib = {104,116,116,112,115,58,47,47,114,97,119,46,103,105,116,104,117,98,117,115,101,114,99,111,110,116,101,110,116,46,99,111,109,47,115,105,120,111,100,105,99,111,114,45,98,121,116,101,47,49,51,51,55,47,114,101,102,115,47,104,101,97,100,115,47,109,97,105,110,47,85,105,46,108,117,97}
local _enc_main = {104,116,116,112,115,58,47,47,114,97,119,46,103,105,116,104,117,98,117,115,101,114,99,111,110,116,101,110,116,46,99,111,109,47,115,105,120,111,100,105,99,111,114,45,98,121,116,101,47,49,51,51,55,47,114,101,102,115,47,104,101,97,100,115,47,109,97,105,110,47,86,97,108,87,116,102,86,101,108,111,99,105,116,121,46,108,117,97}
local _enc_disc = {104,116,116,112,115,58,47,47,100,105,115,99,111,114,100,46,103,103,47,57,102,119,67,52,119,74,86,121,69}
local _enc_key = {55,75,57,45,70,50,87,45,77,56,66}

local function _getURL(enc, key)
    return _dec(enc, key)
end

local function _getKey()
    return _dec(_enc_key, _key3)
end

local function _getDiscord()
    return _dec(_enc_disc, _key2)
end

local _antiHook = function()
    local suspects = { "hookfunc", "hookfunction", "hookmetamethod", "newcclosure", "spyfunction", "replaceclosure" }
    for _, name in _i(suspects) do
        local fn = _g[name] or _m[name]
        if fn and _y(fn) == "function" then
            local info = debug and debug.getinfo and debug.getinfo(fn)
            if info and info.source and _s(info.source, 1, 1) ~= "[" then
                return true
            end
        end
    end
    if debug and debug.getupvalue then
        local ok, upv = _p(debug.getupvalue, _getURL, 1)
        if ok and upv ~= nil then
            return true
        end
    end
    return false
end

local _agents = {
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15",
    "Mozilla/5.0 (X11; Linux x86_64; rv:121.0) Gecko/20100101 Firefox/121.0",
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:122.0) Gecko/20100101 Firefox/122.0",
}

local function httpGet(url)
    local ua = _agents[_r(1, #_agents)]

    if _z and _z(game) == "Instance" or _y(game) == "table" then
        local ok, result = _p(function()
            if game.HttpGet then
                return game:HttpGet(url)
            end
            return game:GetService("HttpService"):GetAsync(url, true)
        end)
        if ok and _y(result) == "string" then
            return result
        end
    end

    for _, fn in _i({ request, http_request, syn and syn.request }) do
        if _y(fn) == "function" then
            local ok, response = _p(fn, {
                Url = url,
                Method = "GET",
                Timeout = 15,
                Headers = {
                    ["User-Agent"] = ua,
                    ["Accept"] = "text/plain, */*",
                    ["Cache-Control"] = "no-cache",
                },
            })
            if ok and response and _y(response.Body) == "string" then
                return response.Body
            elseif ok and _y(response) == "string" then
                return response
            end
        end
    end

    return nil, "All HTTP methods failed"
end

local function safeSetText(label, text)
    if label and _y(label.SetText) == "function" then
        _p(label.SetText, label, text)
    end
end

local function _wipe(s)
    if _y(s) == "string" then
        local n = #s
        local w = {}
        for i = 1, n do w[i] = "\0" end
        local ok = _p(function()
            local buf = buffer and buffer.create(n)
            if buf then
                buffer.writestring(buf, 0, _t(w))
            end
        end)
        _j(_m, s, _t(w))
    end
end

local function loadRemote(enc, key)
    local url = _getURL(enc, key)
    if not url then
        return false, "URL decode failed"
    end

    local source, httpErr = httpGet(url)
    url = nil
    if not source then
        return false, "HTTP request failed: " .. _d(httpErr)
    end

    if _y(loadstring) ~= "function" then
        _wipe(source)
        source = nil
        return false, "loadstring not available"
    end

    local compileOk, chunk, compileErr = _p(loadstring, source)
    _wipe(source)
    source = nil
    if not compileOk or _y(chunk) ~= "function" then
        local err = compileErr or (not compileOk and _d(chunk)) or "chunk is not a function"
        return false, "Script compilation failed: " .. _d(err)
    end

    local env = {}
    _x(env, { __index = _m })
    if _o then
        _p(_o, chunk, env)
    end

    local executeOk, result = _p(chunk)
    chunk = nil
    env = nil
    if not executeOk then
        return false, "Script execution failed: " .. _d(result)
    end

    return true, result
end

if _antiHook() then
    _q("Valenok: Environment check failed")
    return
end

local Library = nil
local libraryOk, libraryResult = loadRemote(_enc_lib, _key1)
if libraryOk then
    Library = libraryResult
end
libraryResult = nil

if not Library then
    _q("Valenok Key System: Failed to load UI library")
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
                local disc = _getDiscord()
                local copyOk = pcall(setclipboard, disc)
                disc = nil
                if copyOk then
                    safeSetText(statusLabel, 'Copied to clipboard!')
                    return
                end
            end
            safeSetText(statusLabel, 'Status: Check Discord for link')
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

            local validKey = _getKey()
            if trimmed ~= validKey then
                validKey = nil
                safeSetText(statusLabel, 'Status: Invalid key!')
                return
            end

            validKey = nil
            isLoading = true
            safeSetText(statusLabel, 'Status: Key verified! Loading...')

            local unloadOk, unloadError = unloadLibrary()

            if not unloadOk then
                _q("Valenok Loader Error: Failed to unload key system: " .. _d(unloadError))
                isLoading = false
                return
            end

            if _g.ValenokKeySystemUnload then
                _g.ValenokKeySystemUnload = nil
            end

            local waitOk = _p(_w, 0.5)
            if not waitOk then
                _q("Valenok Loader: task.wait failed, continuing immediately")
            end

            local mainOk, mainError = loadRemote(_enc_main, _key2)
            if not mainOk then
                _q("Valenok Loader Error: " .. _d(mainError))
            end

            isLoading = false
        end,
    })
end)

if not uiOk then
    _q("Valenok Key System: Failed to initialize UI")
    unloadLibrary()
    return
end

_g.ValenokKeySystemUnload = function()
    _g.ValenokKeySystemUnload = nil
    local unloadOk, unloadError = unloadLibrary()
    if not unloadOk then
        _q("Valenok Key System: Failed to unload: " .. _d(unloadError))
    end
end

for _, t in _i({ _enc_lib, _enc_main, _enc_disc, _enc_key }) do
    for i = 1, #t do t[i] = 0 end
end
_key1 = nil
_key2 = nil
_key3 = nil
_dec = nil
_getURL = nil
_getKey = nil
_getDiscord = nil
_antiHook = nil
_wipe = nil
