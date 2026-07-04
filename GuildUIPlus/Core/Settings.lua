-- GuildUI+ Settings + Migrations
-- Per-account with per-char override sections

local ADDON = ...
local NS = _G.GuildUIPlus

NS.Settings = {
    DEFAULTS = {
        version = 1,
        profile = "default",
        modules = {},
        roster = {
            columns = { "name", "class", "level", "rank", "zone", "note", "lastOnline" },
            columnWidths = { name = 120, class = 80, level = 50, rank = 100, zone = 120, note = 150, lastOnline = 80 },
            sortColumn = "name",
            sortAscending = true,
            showOffline = true,
            showAlts = true,
            searchFilter = "",
            rankFilter = -1,
            classFilter = "",
            splitByAlt = true,
        },
        forum = {},
        schedule = {},
        recruitment = {},
        attendance = {},
        banker = {},
        ledger = {
            system = "dkp",
            entries = {},
        },
        notifier = {
            rules = {},
        },
        webhook = {
            enabled = false,
            url = "",
            events = {},
        },
        dashboard = {},
        locator = {
            enabled = true,
        },
        motd = {
            interval = 300,
            enabled = true,
        },
        tutorial = {
            completed = false,
        },
        ui = {
            frameScale = 1,
            fontScale = 1,
            colorblindMode = false,
            attachToBlizzard = false,
            keybindToggle = "TOGGLE",
        },
    },

    -- Per-char overrides (same structure, only set keys override)
    charOverrides = {},
}

function NS.Settings:GetDB()
    return GuildUIPlusDB
end

function NS.Settings:Init()
    if not GuildUIPlusDB then
        GuildUIPlusDB = NS.Util.copy(self.DEFAULTS)
    end
    self:_migrate(GuildUIPlusDB)
    return GuildUIPlusDB
end

function NS.Settings:InitChar()
    local charKey = UnitName("player") .. "-" .. GetRealmName()
    if not GuildUIPlusDB._chars then
        GuildUIPlusDB._chars = {}
    end
    if not GuildUIPlusDB._chars[charKey] then
        GuildUIPlusDB._chars[charKey] = {}
    end
    self._charKey = charKey
end

function NS.Settings:Get(section, key)
    local db = self:GetDB()
    if key then
        local val = db[section] and db[section][key]
        if val ~= nil then return val end
        local charVal = self:GetChar(section, key)
        if charVal ~= nil then return charVal end
        return self.DEFAULTS[section] and self.DEFAULTS[section][key]
    end
    return db[section] or self.DEFAULTS[section]
end

function NS.Settings:GetChar(section, key)
    if not self._charKey then return nil end
    local chars = GuildUIPlusDB._chars
    if not chars or not chars[self._charKey] then return nil end
    if key then
        return chars[self._charKey][section] and chars[self._charKey][section][key]
    end
    return chars[self._charKey][section]
end

function NS.Settings:Set(section, key, value)
    local db = self:GetDB()
    if not db[section] then db[section] = {} end
    db[section][key] = value
end

function NS.Settings:SetChar(section, key, value)
    if not self._charKey then return end
    local chars = GuildUIPlusDB._chars
    if not chars[self._charKey] then chars[self._charKey] = {} end
    if not chars[self._charKey][section] then chars[self._charKey][section] = {} end
    chars[self._charKey][section][key] = value
end

function NS.Settings:IsModuleEnabled(name)
    local db = self:GetDB()
    if db.modules[name] ~= nil then return db.modules[name] end
    return true
end

function NS.Settings:SetModuleEnabled(name, enabled)
    local db = self:GetDB()
    db.modules[name] = enabled
end

function NS.Settings:Export()
    local db = self:GetDB()
    return NS.Util.copy(db)
end

function NS.Settings:Import(data)
    if type(data) ~= "table" then return false, "Invalid data" end
    local db = self:GetDB()
    NS.Util.deepMerge(db, data)
    self:_migrate(db)
    return true
end

-- Migrations
NS.Settings._migrations = {
    [1] = function(db)
        -- v1: initial schema, nothing to migrate
        db.version = 1
    end,
}

function NS.Settings:_migrate(db)
    local currentVersion = db.version or 0
    for i = currentVersion + 1, #self._migrations do
        local ok, err = pcall(self._migrations[i], db)
        if not ok then
            print(string.format("|cffff0000[GUI+]|r Migration v%d failed: %s", i, err))
            break
        end
        db.version = i
    end
end
