-- GuildUI+ Utility Library
-- Pure-Lua helpers, zero external deps

local ADDON = ...
local NS = _G.GuildUIPlus
NS.Util = {}

-- Class colors (WotLK API)
NS.CLASS_COLORS = {}
do
    for classToken, color in pairs(RAID_CLASS_COLORS) do
        NS.CLASS_COLORS[classToken] = {
            r = color.r, g = color.g, b = color.b,
            hex = string.format("|cff%02x%02x%02x", color.r * 255, color.g * 255, color.b * 255),
        }
    end
end

NS.CLASS_LOCALIZED = {}
NS.CLASS_TOKEN_BY_NAME = {}
do
    -- In 3.3.5a, GetClassInfo(index) takes a 1-based index (1..10)
    -- Returns: localizedClassName, classToken
    for i = 1, 10 do
        local localized, token = GetClassInfo(i)
        if localized and token then
            NS.CLASS_LOCALIZED[token] = localized
            NS.CLASS_TOKEN_BY_NAME[localized] = token
        end
    end
end

-- Table utilities
function NS.Util.copy(t)
    if type(t) ~= "table" then return t end
    local o = {}
    for k, v in pairs(t) do o[NS.Util.copy(k)] = NS.Util.copy(v) end
    return o
end

function NS.Util.merge(defaults, overrides)
    local o = NS.Util.copy(defaults)
    if type(overrides) == "table" then
        for k, v in pairs(overrides) do o[k] = v end
    end
    return o
end

function NS.Util.deepMerge(target, source)
    if type(source) ~= "table" then return target end
    for k, v in pairs(source) do
        if type(v) == "table" and type(target[k]) == "table" then
            NS.Util.deepMerge(target[k], v)
        else
            target[k] = NS.Util.copy(v)
        end
    end
    return target
end

function NS.Util.size(t)
    local n = 0
    for _ in pairs(t) do n = n + 1 end
    return n
end

function NS.Util.keys(t)
    local k = {}
    for key in pairs(t) do k[#k + 1] = key end
    return k
end

function NS.Util.sortedKeys(t, comp)
    local k = NS.Util.keys(t)
    table.sort(k, comp or function(a, b) return tostring(a) < tostring(b) end)
    return k
end

-- String utilities
function NS.Util.trim(s)
    return s:match("^%s*(.-)%s*$")
end

function NS.Util.split(str, delim)
    local parts = {}
    for part in str:gmatch("[^" .. delim .. "]+") do
        parts[#parts + 1] = part
    end
    return parts
end

function NS.Util.startsWith(str, prefix)
    return str:sub(1, #prefix) == prefix
end

function NS.Util.escapePattern(s)
    return s:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1")
end

-- Time utilities
function NS.Util.secondsToTime(secs)
    if secs <= 0 then return "0s" end
    local d = math.floor(secs / 86400)
    local h = math.floor((secs % 86400) / 3600)
    local m = math.floor((secs % 3600) / 60)
    local s = math.floor(secs % 60)
    if d > 0 then return string.format("%dd %dh %dm", d, h, m) end
    if h > 0 then return string.format("%dh %dm", h, m) end
    if m > 0 then return string.format("%dm %ds", m, s) end
    return string.format("%ds", s)
end

function NS.Util.timeSince(timestamp)
    return (time() or 0) - (timestamp or 0)
end

function NS.Util.lastOnlineText(years, months, days, hours)
    years, months, days, hours = years or 0, months or 0, days or 0, hours or 0
    local total = years * 365 + months * 30 + days
    if total > 0 then
        return string.format("%dy %dm %dd", years, months, days)
    end
    if hours > 0 then
        return string.format("%dh", hours)
    end
    return "Just now"
end

-- Number utilities
function NS.Util.clamp(val, min, max)
    return math.min(math.max(val, min), max)
end

-- Color utilities
function NS.Util.classColorToken(classToken)
    local c = NS.CLASS_COLORS[classToken]
    if c then return c.hex end
    return "|cffffffff"
end

function NS.Util.colorText(text, r, g, b)
    return string.format("|cff%02x%02x%02x%s|r", r * 255, g * 255, b * 255, text)
end

-- CRC32 (pure Lua, no bit library dependency — for audit chain)
-- Uses modular arithmetic instead of bit.* functions for 3.3.5a compatibility
do
    local CRC_TABLE = {}
    for i = 0, 255 do
        local c = i
        for _ = 1, 8 do
            if c % 2 == 1 then
                c = math.floor(c / 2)
                -- XOR with 0xEDB88320 using modular arithmetic
                -- In Lua 5.1, we use the fact that 0xEDB88320 fits in 32 bits
                -- and XOR can be done via string manipulation or manual bit ops
                local xor_val = 0xEDB88320
                local result = 0
                local bit_c = c
                local bit_v = xor_val
                local pow = 1
                for _ = 1, 32 do
                    local c_bit = bit_c % 2
                    local v_bit = bit_v % 2
                    if c_bit ~= v_bit then
                        result = result + pow
                    end
                    bit_c = math.floor(bit_c / 2)
                    bit_v = math.floor(bit_v / 2)
                    pow = pow * 2
                end
                c = result
            else
                c = math.floor(c / 2)
            end
        end
        CRC_TABLE[i] = c % 0x100000000
    end

    function NS.Util.crc32(data)
        local crc = 0xFFFFFFFF
        for i = 1, #data do
            local byte = string.byte(data, i)
            -- XOR crc with byte, mask to 8 bits → index
            local index = (crc % 256) ~ byte
            -- Manual XOR for 8-bit values
            local xored = 0
            local a = crc
            local b = byte
            local pow = 1
            for _ = 1, 8 do
                local a_bit = a % 2
                local b_bit = b % 2
                if a_bit ~= b_bit then
                    xored = xored + pow
                end
                a = math.floor(a / 2)
                b = math.floor(b / 2)
                pow = pow * 2
            end
            local table_val = CRC_TABLE[xored]
            -- crc = table_val XOR floor(crc / 256)
            local shifted = math.floor(crc / 256)
            local result = 0
            local a2 = table_val
            local b2 = shifted
            local pow2 = 1
            for _ = 1, 32 do
                local a_bit = a2 % 2
                local b_bit = b2 % 2
                if a_bit ~= b_bit then
                    result = result + pow2
                end
                a2 = math.floor(a2 / 2)
                b2 = math.floor(b2 / 2)
                pow2 = pow2 * 2
            end
            crc = result % 0x100000000
        end
        -- XOR with 0xFFFFFFFF (bitwise NOT for 32-bit)
        local not_crc = 0
        local a3 = crc
        local pow3 = 1
        for _ = 1, 32 do
            if a3 % 2 == 0 then
                not_crc = not_crc + pow3
            end
            a3 = math.floor(a3 / 2)
            pow3 = pow3 * 2
        end
        return not_crc
    end
end

-- Frame pool
NS.Util.FramePool = {}
NS.Util.FramePool.__index = NS.Util.FramePool

function NS.Util.FramePool:New(template, parent, initialSize)
    local pool = setmetatable({ frames = {}, active = {}, template = template, parent = parent }, NS.Util.FramePool)
    for _ = 1, (initialSize or 10) do
        pool.frames[#pool.frames + 1] = CreateFrame("Button", nil, parent, template)
    end
    return pool
end

function NS.Util.FramePool:Acquire()
    local f
    if #self.frames > 0 then
        f = table.remove(self.frames)
    else
        f = CreateFrame("Button", nil, self.parent, self.template)
    end
    self.active[f] = true
    f:Show()
    return f
end

function NS.Util.FramePool:Release(frame)
    if not self.active[frame] then return end
    self.active[frame] = nil
    frame:Hide()
    frame:ClearAllPoints()
    self.frames[#self.frames + 1] = frame
end

function NS.Util.FramePool:ReleaseAll()
    for frame in pairs(self.active) do
        frame:Hide()
        frame:ClearAllPoints()
        self.frames[#self.frames + 1] = frame
    end
    wipe(self.active)
end

function NS.Util.FramePool:GetCount()
    local n = 0
    for _ in pairs(self.active) do n = n + 1 end
    return n
end

-- Throttle/debounce
function NS.Util.throttle(interval, fn)
    local lastRun = 0
    return function(...)
        local now = GetTime()
        if now - lastRun >= interval then
            lastRun = now
            return fn(...)
        end
    end
end

function NS.Util.debounce(delay, fn)
    local timer
    return function(...)
        if timer then
            NS.Util.CancelTimer(timer)
        end
        local args = { ... }
        timer = NS.Util.AfterTimer(delay, function()
            fn(unpack(args))
            timer = nil
        end)
    end
end

-- WotLK 3.3.5a-compatible timer system (replaces C_Timer which doesn't exist)
-- Uses a single hidden frame with OnUpdate to manage timers
do
    local timerFrame = CreateFrame("Frame", "GuildUIPlusTimerFrame")
    local timers = {}
    local nextId = 1

    timerFrame:SetScript("OnUpdate", function()
        local now = GetTime()
        local toRemove = {}
        for id, timer in pairs(timers) do
            if now >= timer.expires then
                local ok, err = pcall(timer.func)
                if not ok then
                    print(string.format("|cffff0000[GUI+]|r Timer error: %s", err))
                end
                toRemove[#toRemove + 1] = id
                if timer.repeating then
                    timer.expires = now + timer.interval
                    toRemove[#toRemove] = nil
                end
            end
        end
        for _, id in ipairs(toRemove) do
            timers[id] = nil
        end
    end)

    -- Schedule a one-shot callback after `delay` seconds
    function NS.Util.AfterTimer(delay, func)
        local id = nextId
        nextId = nextId + 1
        timers[id] = {
            expires = GetTime() + delay,
            func = func,
            repeating = false,
        }
        return id
    end

    -- Schedule a repeating callback every `interval` seconds
    function NS.Util.NewTicker(interval, func)
        local id = nextId
        nextId = nextId + 1
        timers[id] = {
            expires = GetTime() + interval,
            func = func,
            repeating = true,
            interval = interval,
        }
        return id
    end

    -- Cancel a timer by id
    function NS.Util.CancelTimer(id)
        timers[id] = nil
    end
end
