-- DrawingEngine v2.0.0
-- Compact pooled wrapper for Roblox/executor Drawing API.

local Engine = {
    Version = "2.0.0",
    _free = {},
    _live = setmetatable({}, { __mode = "k" }),
    _bound = setmetatable({}, { __mode = "k" }),
}

local Handle, Bundle, ObjectPool = {}, {}, {}
Handle.__index, Bundle.__index, ObjectPool.__index = Handle, Bundle, ObjectPool

local V0, WHITE, BLACK = Vector2.new(), Color3.new(1, 1, 1), Color3.new()
local COMMON = { Visible = false, Color = WHITE, Transparency = 1, ZIndex = 0 }
local DEFAULTS = {
    Line = { From = V0, To = V0, Thickness = 1 },
    Text = { Text = "", Position = V0, Size = 13, Center = false, Outline = false, OutlineColor = BLACK, Font = 2 },
    Square = { Position = V0, Size = V0, Thickness = 1, Filled = false },
    Circle = { Position = V0, Radius = 0, Thickness = 1, Filled = false, NumSides = 32 },
    Triangle = { PointA = V0, PointB = V0, PointC = V0, Thickness = 1, Filled = false },
    Quad = { PointA = V0, PointB = V0, PointC = V0, PointD = V0, Thickness = 1, Filled = false },
    Image = { Position = V0, Size = V0, Data = "", Rounding = 0 },
}

local function trySet(object, key, value)
    return pcall(function() object[key] = value end)
end

local function remove(object)
    if not object then return end
    pcall(function()
        object.Visible = false
        object:Remove()
    end)
end

local function newDrawing(kind)
    local ok, object = pcall(Drawing.new, kind)
    return ok and object or nil
end

function Handle:_set(key, value)
    if self._released or value == nil or self._cache[key] == value then return false end
    if not self._drawing or not trySet(self._drawing, key, value) then return false end
    self._cache[key] = value
    return true
end

function Handle:_reset()
    local defaults = DEFAULTS[self._kind]
    self:_set("Visible", false)

    for key in pairs(self._cache) do
        local value = defaults and defaults[key]
        if value == nil then value = COMMON[key] end
        if value ~= nil then self:_set(key, value) end
    end

    table.clear(self._cache)
end

function Handle:Patch(properties)
    if self._released or type(properties) ~= "table" then return self end
    for key, value in pairs(properties) do
        if type(key) == "string" then self:_set(key, value) end
    end
    return self
end

function Handle:Show(properties)
    if properties then self:Patch(properties) end
    self:_set("Visible", true)
    return self
end

function Handle:Hide()
    self:_set("Visible", false)
    return self
end

function Handle:Raw()
    return self._drawing
end

function Handle:Bind(parent, offset, targetProperty, sourceProperty)
    if not parent then return self:Unbind() end
    self._parent = parent
    self._offset = offset or V0
    self._targetProperty = targetProperty or "Position"
    self._sourceProperty = sourceProperty or "Position"
    Engine._bound[self] = true
    return self:Sync()
end

function Handle:Unbind()
    self._parent, self._offset = nil, nil
    Engine._bound[self] = nil
    return self
end

function Handle:Sync()
    if self._released or not self._parent then return self end

    local source = self._parent._drawing or self._parent
    local ok, base = pcall(function() return source[self._sourceProperty] end)
    if not ok then return self end

    local offset = self._offset
    if (typeof(base) == "Vector2" and typeof(offset) == "Vector2")
        or (type(base) == "number" and type(offset) == "number") then
        self:_set(self._targetProperty, base + offset)
    end
    return self
end

function Handle:Release()
    if self._released then return self end
    self:_reset()
    self._released = true
    self:Unbind()
    Engine._live[self] = nil

    local free = Engine._free[self._kind]
    if not free then
        free = {}
        Engine._free[self._kind] = free
    end
    free[#free + 1] = self
    return self
end

function Handle:Destroy()
    if self._destroyed then return self end
    self._destroyed, self._released = true, true
    self:Unbind()
    Engine._live[self] = nil
    remove(self._drawing)
    self._drawing = nil
    table.clear(self._cache)
    return self
end

function Engine:Acquire(kind, properties)
    assert(type(kind) == "string", "kind must be a string")

    local free = self._free[kind]
    local handle = free and free[#free]
    if handle then free[#free] = nil end

    if not handle or handle._destroyed or not handle._drawing then
        local drawing = newDrawing(kind)
        if not drawing then return nil end
        handle = setmetatable({
            _kind = kind,
            _drawing = drawing,
            _cache = {},
        }, Handle)
    end

    handle._released, handle._destroyed = false, false
    self._live[handle] = true
    handle:Patch(properties)
    return handle
end

Engine.New = Engine.Acquire

for _, kind in ipairs({ "Text", "Line", "Square", "Circle", "Triangle", "Quad", "Image" }) do
    Engine[kind] = function(self, properties)
        return self:Acquire(kind, properties)
    end
end

function Engine:Sync()
    for handle in pairs(self._bound) do handle:Sync() end
    return self
end

function Engine:Stats()
    local live, bound, free = 0, 0, 0
    for _ in pairs(self._live) do live += 1 end
    for _ in pairs(self._bound) do bound += 1 end
    for _, list in pairs(self._free) do free += #list end
    return { Live = live, Bound = bound, Free = free }
end

function Engine:Trim(kind, keep)
    keep = math.max(0, keep or 0)
    local function trim(list)
        while #list > keep do list[#list]:Destroy(); list[#list] = nil end
    end

    if kind then
        local list = self._free[kind]
        if list then trim(list) end
    else
        for _, list in pairs(self._free) do trim(list) end
    end
    return self
end

function Engine:Clear()
    local list = {}
    for handle in pairs(self._live) do list[#list + 1] = handle end
    for i = 1, #list do list[i]:Release() end
    return self
end

function Engine:Destroy()
    self:Clear()
    self:Trim(nil, 0)
    return self
end

function Bundle:Patch(values)
    if type(values) ~= "table" then return self end
    for name, properties in pairs(values) do
        local handle = self._items[name]
        if handle then handle:Patch(properties) end
    end
    return self
end

function Bundle:Show(name, properties)
    if name ~= nil then
        local handle = self._items[name]
        if handle then handle:Show(properties) end
    else
        for _, handle in pairs(self._items) do handle:Show() end
    end
    return self
end

function Bundle:Hide(name)
    if name ~= nil then
        local handle = self._items[name]
        if handle then handle:Hide() end
    else
        for _, handle in pairs(self._items) do handle:Hide() end
    end
    return self
end

function Bundle:Get(name)
    return self._items[name]
end

function Bundle:Bind(name, ...)
    local handle = self._items[name]
    if handle then handle:Bind(...) end
    return self
end

function Bundle:Release()
    if self._released then return self end
    self._released = true
    for _, handle in pairs(self._items) do handle:Release() end
    table.clear(self._items)
    return self
end

function Engine:Pool(blueprint)
    assert(type(blueprint) == "table", "blueprint must be a table")
    return setmetatable({ _engine = self, _blueprint = blueprint, _active = {} }, ObjectPool)
end

function ObjectPool:Get(key)
    assert(key ~= nil, "pool key cannot be nil")
    local bundle = self._active[key]
    if bundle and not bundle._released then return bundle end

    local items = {}
    for name, definition in pairs(self._blueprint) do
        local handle = self._engine:Acquire(definition[1], definition[2])
        if not handle then
            for _, made in pairs(items) do made:Release() end
            return nil
        end
        items[name] = handle
    end

    bundle = setmetatable({ _items = items, _released = false }, Bundle)
    self._active[key] = bundle
    return bundle
end

function ObjectPool:Release(key)
    local bundle = self._active[key]
    if bundle then
        bundle:Release()
        self._active[key] = nil
    end
    return self
end

function ObjectPool:Clear()
    local keys = {}
    for key in pairs(self._active) do keys[#keys + 1] = key end
    for i = 1, #keys do self:Release(keys[i]) end
    return self
end

function ObjectPool:ForEach(callback)
    if type(callback) ~= "function" then return self end
    for key, bundle in pairs(self._active) do callback(bundle, key, self) end
    return self
end

return Engine
