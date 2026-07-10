if getgenv().ValenokKeySystemUnload then 
    pcall(getgenv().ValenokKeySystemUnload) 
end

local CONSTANTS = {
    GITHUB_LIB_URL = "https://raw.githubusercontent.com/sixodicor-byte/1337/refs/heads/main/Ui.lua",
    GITHUB_THEME_URL = "https://raw.githubusercontent.com/bdimka251212-del/NewLib/refs/heads/main/addons/ThemeManager.lua",
    GITHUB_SAVE_URL = "https://raw.githubusercontent.com/bdimka251212-del/NewLib/refs/heads/main/addons/SaveManager.lua",
    DISCORD_URL = "https://discord.gg/9fwC4wJVyE",
    MAIN_SCRIPT = "https://raw.githubusercontent.com/bdimka251212-del/ValenokRecode/refs/heads/main/Loader.lua",
    VALID_KEY = "7K9-F2W-M8B",
}

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

if not Library then
    warn("Valenok Key System: Failed to load UI library")
    return
end

local Window = Library:CreateWindow({
    Title = 'Valenok | Key System',
    Center = true,
    AutoShow = true,
})

local MainTab = Window:AddTab('Key System')
local KeyGroupbox = MainTab:AddLeftGroupbox('Authentication')
local InfoGroupbox = MainTab:AddRightGroupbox('Information')

InfoGroupbox:AddLabel('Join Discord for key', true)
InfoGroupbox:AddLabel('Click "Get key" to copy the Discord link to clipboard.')
InfoGroupbox:AddLabel('Then join the Discord and get the key.')
InfoGroupbox:AddLabel('Paste the key below and click "Verify key" to load the script.')

local keyInput = KeyGroupbox:AddInput('KeyInput', {
    Text = 'Enter key',
    Default = '',
    Placeholder = 'XXXX-XXX-XXX',
    Finished = false,
})

local statusLabel = KeyGroupbox:AddLabel('Status: Waiting for key...')

KeyGroupbox:AddButton({
    Text = 'Get key',
    Func = function()
        if setclipboard then
            setclipboard(CONSTANTS.DISCORD_URL)
            statusLabel.Text = 'Status: Link copied to clipboard!'
        else
            statusLabel.Text = 'Status: Copy this link: ' .. CONSTANTS.DISCORD_URL
        end
    end,
})

KeyGroupbox:AddButton({
    Text = 'Verify key',
    Func = function()
        local enteredKey = keyInput.Value or ""
        local trimmed = enteredKey:gsub("^%s+", ""):gsub("%s+$", "")
        
        if trimmed == CONSTANTS.VALID_KEY then
            statusLabel.Text = 'Status: Key verified! Loading...'
            
            -- Полностью и корректно выгружаем интерфейс кей-системы
            if Library then
                Library:Unload()
            end
            
            task.wait(0.5)
            
            -- Безопасный запуск основного скрипта
            local success, err = pcall(function()
                loadstring(game:HttpGet(CONSTANTS.MAIN_SCRIPT))()
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
