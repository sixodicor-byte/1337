if getgenv().ValenokKeySystemUnload then
    pcall(getgenv().ValenokKeySystemUnload)
end

local CONSTANTS = {
    GITHUB_LIB_URL = "https://raw.githubusercontent.com/sixodicor-byte/1337/refs/heads/main/NewLib.lua",
    DISCORD_URL = "https://discord.gg/8GRGXy742u",
    MAIN_SCRIPT = "https://raw.githubusercontent.com/sixodicor-byte/1337/refs/heads/main/Main_Script.lua",
    VALID_KEY = "7K9-F2W-M8B",
    KEY_FILE = "Key/key.json",
}

local Library
local HttpService = game:GetService("HttpService")

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
        return value:gsub("^%s+", ""):gsub("%s+$", "")
    end

    return ""
end

local function safeSaveKey(key)
    if type(writefile) ~= "function" then
        return false
    end

    local success = pcall(function()
        if type(makefolder) == "function" and (type(isfolder) ~= "function" or not isfolder("Key")) then
            makefolder("Key")
        end

        writefile(CONSTANTS.KEY_FILE, HttpService:JSONEncode({ key = key }))
    end)

    return success
end

local savedKey = safeReadKey()
if savedKey ~= CONSTANTS.VALID_KEY then
    savedKey = ""
end

pcall(function()
    local source = game:HttpGet(CONSTANTS.GITHUB_LIB_URL)
    local loader = loadstring(source)
    if type(loader) == "function" then
        Library = loader()
    end
end)

if not Library then
    warn("Valenok Key System: Failed to load UI library")
    return
end

local windowSuccess, Window = pcall(function()
    return Library:CreateWindow({
        Title = 'Valenok | Key System',
        Center = true,
        AutoShow = true,
    })
end)

if not windowSuccess or not Window then
    warn("Valenok Key System: Failed to create window")
    return
end

local MainTab = Window:AddTab('Key System')
local KeyGroupbox = MainTab:AddLeftGroupbox('Authentication')
local InfoGroupbox = MainTab:AddRightGroupbox('Information')

InfoGroupbox:AddLabel('Join Discord for key', true)
InfoGroupbox:AddLabel('Click "Get key" to copy the Discord link to clipboard.')
InfoGroupbox:AddLabel('Then join the Discord and get the key.')
InfoGroupbox:AddLabel('Paste the key below and click "Verify key" to load the script.')

local keyInput = KeyGroupbox:AddInput('KeyInput', {
    Text = 'Enter key',
    Default = savedKey,
    Placeholder = 'XXXX-XXX-XXX',
    Finished = false,
})

local statusLabel = KeyGroupbox:AddLabel('Status: Waiting for key...')
local isLoading = false

KeyGroupbox:AddButton({
    Text = 'Get key',
    Func = function()
        if type(setclipboard) == "function" then
            local success = pcall(setclipboard, CONSTANTS.DISCORD_URL)
            if success then
                statusLabel.Text = 'Status: Link copied to clipboard!'
            else
                statusLabel.Text = 'Status: Copy this link: ' .. CONSTANTS.DISCORD_URL
            end
        else
            statusLabel.Text = 'Status: Copy this link: ' .. CONSTANTS.DISCORD_URL
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
            statusLabel.Text = 'Status: Unable to read key input.'
            return
        end

        local trimmed = tostring(enteredKey):gsub("^%s+", ""):gsub("%s+$", "")

        if trimmed == CONSTANTS.VALID_KEY then
            isLoading = true
            safeSaveKey(CONSTANTS.VALID_KEY)
            statusLabel.Text = 'Status: Key verified! Loading...'

            -- Полностью и корректно выгружаем интерфейс кей-системы
            if Library then
                pcall(function()
                    Library:Unload()
                end)
            end

            task.wait(0.5)

            -- Безопасный запуск основного скрипта
            local success, err = pcall(function()
                local source = game:HttpGet(CONSTANTS.MAIN_SCRIPT)
                local loader = loadstring(source)
                if type(loader) ~= "function" then
                    error("Main script did not return executable code")
                end
                loader()
            end)

            if not success then
                warn("Valenok Loader Error: " .. tostring(err))
            end
        else
            statusLabel.Text = 'Status: Invalid key!'
        end
    end,
})

getgenv().ValenokKeySystemUnload = function()
    pcall(function()
        if Library then Library:Unload() end
    end)
end
