-- GuildUI+ Locator Module
-- World-map pins for guild members, same-zone whisper shortcuts

local ADDON, NS = ...

local Locator = {
    name = "locator",
    label = "Locator",
    _memberLocations = {},  -- [playerName] = { zone, subZone, x, y }
    _pins = {},
}

NS.Loader:Register("locator", Locator)

function Locator:UpdateLocation(playerName, zone, x, y)
    self._memberLocations[playerName] = {
        zone = zone,
        x = x or 0,
        y = y or 0,
        timestamp = time(),
    }
end

function Locator:GetMembersInZone(zone)
    local members = {}
    for name, loc in pairs(self._memberLocations) do
        if loc.zone == zone then
            members[#members + 1] = name
        end
    end
    return members
end

function Locator:GetAllLocations()
    return self._memberLocations
end

function Locator:RequestLocations()
    NS.Comm:Send(NS.Comm.OP.LOC_REQUEST, "", "GUILD")
end

-- Comm
NS.Comm:On(NS.Comm.OP.LOC_UPDATE, function(sender, payload)
    local zone, x, y = payload:match("^([^|]*)|([^|]*)|([^|]*)$")
    if zone then
        Locator:UpdateLocation(sender, zone, tonumber(x) or 0, tonumber(y) or 0)
    end
end)

NS.Comm:On(NS.Comm.OP.LOC_REQUEST, function(sender)
    local zone = GetRealZoneText()
    local x, y = GetPlayerMapPosition("player")
    NS.Comm:Send(NS.Comm.OP.LOC_UPDATE, string.format("%s|%.2f|%.2f", zone, x or 0, y or 0), "WHISPER", sender)
end)

-- Auto broadcast on zone change
NS.Loader:On("ON_ZONE", function()
    local zone = GetRealZoneText()
    local x, y = GetPlayerMapPosition("player")
    Locator:UpdateLocation(UnitName("player"), zone, x or 0, y or 0)
    NS.Comm:Send(NS.Comm.OP.LOC_UPDATE, string.format("%s|%.2f|%.2f", zone, x or 0, y or 0), "GUILD")
end)
