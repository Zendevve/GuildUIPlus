-- GuildUI+ MOTD Module
-- Synced MOTD, refresh intervals, first-of-day re-prompt

local ADDON = ...
local NS = _G.GuildUIPlus

local MOTD = {
    name = "motd",
    label = "MOTD",
    _lastMOTD = "",
    _lastPromptDate = "",
}

NS.Loader:Register("motd", MOTD)

function MOTD:GetMOTD()
    return GetGuildRosterMOTD()
end

function MOTD:SetMOTD(text)
    SetGuildRosterMOTD(text)
end

function MOTD:CheckForNewDay()
    local today = date("%Y-%m-%d")
    if today ~= self._lastPromptDate then
        self._lastPromptDate = today
        local motd = self:GetMOTD()
        if motd and motd ~= "" and motd ~= self._lastMOTD then
            self._lastMOTD = motd
            -- Re-prompt in chat
            DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[GUI+]|r Guild MOTD: " .. motd)
        end
    end
end

function MOTD:Sync()
    local motd = self:GetMOTD()
    if motd then
        NS.Comm:Send(NS.Comm.OP.MOTD_SYNC, motd, "GUILD")
    end
end

NS.Comm:On(NS.Comm.OP.MOTD_SYNC, function(sender, payload)
    -- Another guild member synced their MOTD view
    -- We don't overwrite — MOTD is authoritative from server
end)

NS.Loader:On("ON_READY", function()
    NS.Util.NewTicker(300, function() MOTD:CheckForNewDay() end)
end)
