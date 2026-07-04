-- GuildUI+ Dashboard Module
-- Class distribution, level histogram, online trend, recruitment snapshot

local ADDON, NS = ...

local Dashboard = {
    name = "dashboard",
    label = "Dashboard",
    _classCounts = {},
    _levelCounts = {},
    _onlineHistory = {},
}

NS.Loader:Register("dashboard", Dashboard)

function Dashboard:Refresh()
    self._classCounts = {}
    self._levelCounts = {}
    local numMembers = GetNumGuildMembers(true)
    local totalOnline = 0

    for i = 1, numMembers do
        local name, _, _, level, _, _, _, _, isOnline, _, classFileName = GetGuildRosterInfo(i)
        if name then
            -- Class distribution
            self._classCounts[classFileName] = (self._classCounts[classFileName] or 0) + 1

            -- Level histogram (brackets: 1-10, 11-20, ... 71-80)
            local bracket = math.floor((level or 1) / 10) * 10
            if bracket == 0 then bracket = 10 end
            self._levelCounts[bracket] = (self._levelCounts[bracket] or 0) + 1

            if isOnline then totalOnline = totalOnline + 1 end
        end
    end

    -- Record online count for trend
    local timeStr = date("%H:%M")
    self._onlineHistory[#self._onlineHistory + 1] = { time = timeStr, count = totalOnline }
    if #self._onlineHistory > 24 then
        table.remove(self._onlineHistory, 1)
    end
end

function Dashboard:GetClassDistribution()
    return self._classCounts
end

function Dashboard:GetLevelHistogram()
    return self._levelCounts
end

function Dashboard:GetOnlineTrend()
    return self._onlineHistory
end

function Dashboard:GetRecruitmentSnapshot()
    local recruitment = NS.Loader:Get("recruitment")
    if recruitment then
        local all = recruitment:GetAll()
        local counts = { applied = 0, trial = 0, raider = 0, rejected = 0 }
        for _, app in ipairs(all) do
            counts[app.status] = (counts[app.status] or 0) + 1
        end
        return counts
    end
    return {}
end

-- Refresh on roster update
NS.Loader:On("ON_ROSTER", function()
    Dashboard:Refresh()
end)
