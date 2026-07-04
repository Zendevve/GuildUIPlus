-- GuildUI+ Module Loader
-- Registry-based lazy-load system

local ADDON, NS = ...

NS.Loader = {
    modules = {},
    loaded = {},
    order = {},
    callbacks = {
        ON_LOAD = {},    -- fires once after all registered modules load
        ON_READY = {},   -- fires after PLAYER_ENTERING_WORLD
        ON_ROSTER = {},  -- fires on GUILD_ROSTER_UPDATE
        ON_COMM = {},    -- fires on CHAT_MSG_ADDON (filter: our prefix)
        ON_ZONE = {},    -- fires on ZONE_CHANGED_NEW_AREA
        ON_CHAT = {},    -- fires on GUILD_CHAT / GUILD_MOTD
        ON_BANK = {},    -- fires on GUILDBANKFRAME_OPENED / etc
    },
}

function NS.Loader:Register(name, tbl)
    self.modules[name] = tbl
    self.order[#self.order + 1] = name
end

function NS.Loader:Get(name)
    return self.modules[name]
end

function NS.Loader:IsLoaded(name)
    return self.loaded[name] == true
end

function NS.Loader:Fire(event, ...)
    local list = self.callbacks[event]
    if not list then return end
    for i = 1, #list do
        local ok, err = pcall(list[i], ...)
        if not ok then
            print(string.format("|cffff0000[GUI+]|r %s callback error: %s", event, err))
        end
    end
end

function NS.Loader:On(event, fn)
    if not self.callbacks[event] then
        self.callbacks[event] = {}
    end
    self.callbacks[event][#self.callbacks[event] + 1] = fn
end

function NS.Loader:LoadAll()
    for _, name in ipairs(self.order) do
        if not self.loaded[name] then
            local mod = self.modules[name]
            if mod and type(mod.OnLoad) == "function" then
                local ok, err = pcall(mod.OnLoad, mod)
                if ok then
                    self.loaded[name] = true
                else
                    print(string.format("|cffff0000[GUI+]|r Failed to load module '%s': %s", name, err))
                end
            elseif mod then
                self.loaded[name] = true
            end
        end
    end
    self:Fire("ON_LOAD")
end

function NS.Loader:OnEvent(event, ...)
    if event == "PLAYER_ENTERING_WORLD" then
        self:Fire("ON_READY", ...)
    elseif event == "GUILD_ROSTER_UPDATE" then
        self:Fire("ON_ROSTER", ...)
    elseif event == "CHAT_MSG_ADDON" then
        local prefix = ...
        if prefix == NS.COMM_PREFIX then
            self:Fire("ON_COMM", select(2, ...))
        end
    elseif event == "ZONE_CHANGED_NEW_AREA" then
        self:Fire("ON_ZONE", ...)
    elseif event == "GUILD_MOTD_CHANGED" then
        self:Fire("ON_CHAT", ...)
    end
end
