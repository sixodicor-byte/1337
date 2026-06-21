local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()

local Library = {
    Connections = {};
}

local function CreateSquare(props)
    local sq = Drawing.new("Square")
    sq.Filled = true
    sq.Visible = false
    sq.Thickness = 1
    sq.Color = Color3.fromRGB(0, 0, 0)
    for k, v in pairs(props or {}) do
        sq[k] = v
    end
    return sq
end

local function CreateText(props)
    local txt = Drawing.new("Text")
    txt.Visible = false
    txt.Color = Color3.fromRGB(255, 255, 255)
    txt.Center = false
    txt.Outline = false
    txt.Font = 2
    txt.Size = 16
    for k, v in pairs(props or {}) do
        txt[k] = v
    end
    return txt
end

local function CreateLine(props)
    local ln = Drawing.new("Line")
    ln.Visible = false
    ln.Thickness = 1
    ln.Transparency = 1
    for k, v in pairs(props or {}) do
        ln[k] = v
    end
    return ln
end

local function MouseInBounds(bx, by, bw, bh)
    return Mouse.X >= bx and Mouse.X <= bx + bw and Mouse.Y >= by and Mouse.Y <= by + bh
end

function Library:CreateWindow(config)
    config = config or {}

    local Window = {}
    Window.Tabs = {}
    Window.ActiveTab = nil

    local state = {
        X = config.X or 200,
        Y = config.Y or 200,
        W = config.W or 600,
        H = config.H or 400,
        Title = config.Title or "UILib",
        TabHeight = 30,
        Visible = true,
    }

    local drawings = {}

    drawings.Bg = CreateSquare({
        Size = Vector2.new(state.W, state.H),
        Position = Vector2.new(state.X, state.Y),
        Color = Color3.fromRGB(15, 15, 15),
        Filled = true,
        Visible = true,
    })

    drawings.Outline = CreateSquare({
        Size = Vector2.new(state.W, state.H),
        Position = Vector2.new(state.X, state.Y),
        Color = Color3.fromRGB(40, 40, 40),
        Filled = false,
        Thickness = 1,
        Visible = true,
    })

    drawings.TabBarBg = CreateSquare({
        Size = Vector2.new(state.W, state.TabHeight),
        Position = Vector2.new(state.X, state.Y),
        Color = Color3.fromRGB(25, 25, 25),
        Filled = true,
        Visible = true,
    })

    drawings.TitleText = CreateText({
        Text = state.Title,
        Position = Vector2.new(state.X + 10, state.Y + 6),
        Size = 16,
        Color = Color3.fromRGB(255, 255, 255),
        Font = 2,
        Visible = true,
    })

    drawings.TabBarLine = CreateLine({
        From = Vector2.new(state.X, state.Y + state.TabHeight),
        To = Vector2.new(state.X + state.W, state.Y + state.TabHeight),
        Color = Color3.fromRGB(40, 40, 40),
        Thickness = 1,
        Visible = true,
    })

    local dragging = false
    local dragOffset = Vector2.new(0, 0)

    local function GetTabStartX()
        return state.X + 10 + drawings.TitleText.TextBounds.X + 20
    end

    function Window:AddTab(name)
        local tab = {
            Name = name,
            Drawings = {},
        }

        local measureText = CreateText({ Text = name, Size = 16, Font = 2 })
        local tabW = measureText.TextBounds.X + 24
        measureText:Remove()

        tab.W = tabW

        tab.Drawings.Bg = CreateSquare({
            Size = Vector2.new(tabW, state.TabHeight),
            Color = Color3.fromRGB(25, 25, 25),
            Filled = true,
            Visible = true,
        })

        tab.Drawings.Label = CreateText({
            Text = name,
            Size = 16,
            Color = Color3.fromRGB(170, 170, 170),
            Font = 2,
            Center = true,
            Visible = true,
        })

        tab.ClickConnection = UserInputService.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 and state.Visible then
                local tx = GetTabStartX()
                for _, t in ipairs(Window.Tabs) do
                    if t == tab then
                        if MouseInBounds(tx, state.Y, tab.W, state.TabHeight) then
                            Window:SelectTab(tab)
                        end
                        break
                    end
                    tx = tx + t.W
                end
            end
        end)

        table.insert(Window.Tabs, tab)

        if #Window.Tabs == 1 then
            Window:SelectTab(tab)
        end

        return tab
    end

    function Window:SelectTab(tab)
        for _, t in ipairs(Window.Tabs) do
            t.Drawings.Bg.Color = Color3.fromRGB(25, 25, 25)
            t.Drawings.Label.Color = Color3.fromRGB(170, 170, 170)
        end
        tab.Drawings.Bg.Color = Color3.fromRGB(15, 15, 15)
        tab.Drawings.Label.Color = Color3.fromRGB(255, 255, 255)
        Window.ActiveTab = tab
    end

    function Window:SetVisible(visible)
        state.Visible = visible
        for _, d in pairs(drawings) do
            d.Visible = visible
        end
        for _, tab in ipairs(Window.Tabs) do
            for _, d in pairs(tab.Drawings) do
                d.Visible = visible
            end
        end
    end

    -- Dragging
    table.insert(Library.Connections, UserInputService.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 and state.Visible then
            if MouseInBounds(state.X, state.Y, state.W, state.TabHeight) then
                dragging = true
                dragOffset = Vector2.new(Mouse.X - state.X, Mouse.Y - state.Y)
            end
        end
    end))

    table.insert(Library.Connections, UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end))

    -- Render loop
    table.insert(Library.Connections, RunService.RenderStepped:Connect(function()
        if dragging then
            state.X = Mouse.X - dragOffset.X
            state.Y = Mouse.Y - dragOffset.Y
        end

        drawings.Bg.Position = Vector2.new(state.X, state.Y)
        drawings.Outline.Position = Vector2.new(state.X, state.Y)
        drawings.TabBarBg.Position = Vector2.new(state.X, state.Y)
        drawings.TitleText.Position = Vector2.new(state.X + 10, state.Y + 6)
        drawings.TabBarLine.From = Vector2.new(state.X, state.Y + state.TabHeight)
        drawings.TabBarLine.To = Vector2.new(state.X + state.W, state.Y + state.TabHeight)

        local tx = GetTabStartX()
        for _, tab in ipairs(Window.Tabs) do
            tab.Drawings.Bg.Position = Vector2.new(tx, state.Y)
            tab.Drawings.Label.Position = Vector2.new(tx + tab.W / 2, state.Y + 6)
            tx = tx + tab.W
        end
    end))

    return Window
end

function Library:Unload()
    for _, c in ipairs(Library.Connections) do
        c:Disconnect()
    end
    Library.Connections = {}
end

getgenv().UILib = Library
return Library
