-- GuildUI+ Attendance Module
-- Zone-delta tracking, absence list, weekly digest

local ADDON = ...
local NS = _G.GuildUIPlus

local Attendance = {
    name = "attendance",
    label = "Attend",
    _checkins = {},   -- [playerName] = { zone, timestamp }
    _history = {},    -- [date][playerName] = { checkins, totalMinutes }
    _currentZone = nil,
}

NS.Loader:Register("attendance", Attendance)

function Attendance:CheckIn(playerName, zone)
    self._checkins[playerName] = { zone = zone, timestamp = time() }
end

function Attendance:CheckOut(playerName)
    if self._checkins[playerName] then
        local checkin = self._checkins[playerName]
        local duration = time() - checkin.timestamp
        self:_recordHistory(playerName, duration)
        self._checkins[playerName] = nil
    end
end

function Attendance:_recordHistory(playerName, minutes)
    local dateStr = date("%Y-%m-%d")
    if not self._history[dateStr] then self._history[dateStr] = {} end
    if not self._history[dateStr][playerName] then
        self._history[dateStr][playerName] = { totalMinutes = 0, sessions = 0 }
    end
    self._history[dateStr][playerName].totalMinutes = self._history[dateStr][playerName].totalMinutes + minutes
    self._history[dateStr][playerName].sessions = self._history[dateStr][playerName].sessions + 1
end

function Attendance:GetAbsences(daysBack)
    daysBack = daysBack or 7
    local cutoff = time() - (daysBack * 86400)
    local members = {}
    local numMembers = GetNumGuildMembers(true)

    for i = 1, numMembers do
        local name, _, _, _, _, _, _, _, isOnline = GetGuildRosterInfo(i)
        if name then
            local shortName = name:match("([^-]+)") or name
            local lastSeen = 0
            for dateStr, players in pairs(self._history) do
                if players[shortName] then
                    local d = time("*t")
                    d.year, d.month, d.day = dateStr:match("(%d+)-(%d+)-(%d+)")
                    local ts = time(d)
                    if ts > lastSeen then lastSeen = ts end
                end
            end
            if lastSeen < cutoff and not isOnline then
                members[#members + 1] = {
                    name = shortName,
                    lastSeen = lastSeen,
                    daysAbsent = math.floor((time() - lastSeen) / 86400),
                }
            end
        end
    end

    table.sort(members, function(a, b) return a.daysAbsent > b.daysAbsent end)
    return members
end

function Attendance:GenerateDigest(daysBack)
    daysBack = daysBack or 7
    local digest = {}
    local startDate = date("%Y-%m-%d", time() - (daysBack * 86400))

    for dateStr, players in pairs(self._history) do
        if dateStr >= startDate then
            for playerName, data in pairs(players) do
                if not digest[playerName] then
                    digest[playerName] = { totalMinutes = 0, sessions = 0 }
                end
                digest[playerName].totalMinutes = digest[playerName].totalMinutes + data.totalMinutes
                digest[playerName].sessions = digest[playerName].sessions + data.sessions
            end
        end
    end

    return digest
end

-- Comm
NS.Comm:On(NS.Comm.OP.ATTEND_CHECKIN, function(sender, payload)
    local zone = payload
    Attendance:CheckIn(sender, zone)
end)

NS.Comm:On(NS.Comm.OP.ATTEND_CHECKOUT, function(sender)
    Attendance:CheckOut(sender)
end)

-- Auto check-in on zone change
NS.Loader:On("ON_ZONE", function()
    local zone = GetRealZoneText()
    if zone ~= "" then
        local playerName = UnitName("player")
        Attendance:CheckIn(playerName, zone)
        NS.Comm:Send(NS.Comm.OP.ATTEND_CHECKIN, zone, "GUILD")
    end
end)
