-- GuildUI+ Utility Library
-- Pure-Lua helpers, zero external deps

local ADDON, NS = ...
NS.Util = {}

-- Constants
NS.ADDON_NAME = ADDON
NS.VERSION = "1.0.0"
NS.PROTOCOL_VERSION = 1
NS.COMM_PREFIX = "GG1"

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
    local localizedClasses = { GetClassInfo() }
    for i = 1, #localizedClasses do
        local localized, token = localizedClasses[i], localizedClasses[i + 1]
        NS.CLASS_LOCALIZED[token] = localized
        NS.CLASS_TOKEN_BY_NAME[localized] = token
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

-- CRC32 (lightweight, for audit chain)
do
    local CRC_TABLE = {}
    for i = 0, 255 do
        local c = i
        for _ = 1, 8 do
            if c % 2 == 1 then
                c = bit.rshift(c, 1) - bit.band(0xEDB88320, 0xFFFFFFFF)
            else
                c = bit.rshift(c, 1)
            end
        end
        CRC_TABLE[i] = bit.band(c, 0xFFFFFFFF)
    end

    function NS.Util.crc32(data)
        local crc = 0xFFFFFFFF
        for i = 1, #data do
            local byte = string.byte(data, i)
            crc = bit.bxor(CRC_TABLE[bit.band(bit.bxor(crc, byte), 0xFF)], bit.rshift(crc, 8))
        end
        return bit.band(bit.bnot(crc), 0xFFFFFFFF)
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
            CancelTimer(timer)
        end
        local args = { ... }
        timer = C_Timer.After(delay, function()
            fn(unpack(args))
            timer = nil
        end)
    end
end
