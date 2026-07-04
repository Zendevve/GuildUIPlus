-- GuildUI+ Recruitment Module
-- Applicant → Trial → Raider pipeline, trade-channel rotation, auto-DM

local ADDON = ...
local NS = _G.GuildUIPlus

local Recruitment = {
    name = "recruitment",
    label = "Recruit",
    _applicants = {},  -- [playerName] = { status, appliedAt, notes, reviewedBy }
    _ads = {},         -- trade-channel ad rotation
    _nextAdIdx = 0,
    _lastAdTime = 0,
    _adCooldown = 300, -- seconds between ads
}

NS.Loader:Register("recruitment", Recruitment)

-- Pipeline statuses
local STATUS = {
    APPLIED  = "applied",
    TRIAL    = "trial",
    RAIDER   = "raider",
    REJECTED = "rejected",
    WITHDRAWN = "withdrawn",
}

Recruitment.STATUS = STATUS

function Recruitment:Apply(playerName, notes)
    self._applicants[playerName] = {
        status = STATUS.APPLIED,
        appliedAt = time(),
        notes = notes or "",
        reviewedBy = nil,
    }
    self:_broadcastStatus(playerName, STATUS.APPLIED)
end

function Recruitment:SetStatus(playerName, newStatus, officer)
    local app = self._applicants[playerName]
    if not app then return end
    app.status = newStatus
    app.reviewedBy = officer
    app.reviewedAt = time()
    self:_broadcastStatus(playerName, newStatus)

    -- Auto-welcome DM for accepted trials
    if newStatus == STATUS.TRIAL then
        SendChatMessage(string.format("Welcome to the guild trial program, %s! Please check the guild info tab for expectations.", playerName), "WHISPER", nil, playerName)
    end
end

function Recruitment:GetByStatus(status)
    local list = {}
    for name, app in pairs(self._applicants) do
        if app.status == status then
            list[#list + 1] = { name = name, appliedAt = app.appliedAt, notes = app.notes }
        end
    end
    return list
end

function Recruitment:GetAll()
    local list = {}
    for name, app in pairs(self._applicants) do
        list[#list + 1] = {
            name = name,
            status = app.status,
            appliedAt = app.appliedAt,
            notes = app.notes,
            reviewedBy = app.reviewedBy,
        }
    end
    return list
end

function Recruitment:AddAd(message, author)
    self._ads[#self._ads + 1] = {
        message = message,
        author = author,
        createdAt = time(),
    }
end

function Recruitment:RemoveAd(index)
    table.remove(self._ads, index)
end

function Recruitment:PostAd()
    if #self._ads == 0 then return end
    local now = time()
    if (now - self._lastAdTime) < self._adCooldown then return end

    self._nextAdIdx = (self._nextAdIdx % #self._ads) + 1
    local ad = self._ads[self._nextAdIdx]
    if ad then
        SendChatMessage(ad.message, "CHANNEL", nil, 1) -- trade channel
        self._lastAdTime = now

        -- Broadcast cooldown to other guild members with addon
        NS.Comm:Send(NS.Comm.OP.RECRUIT_AD, tostring(now), "GUILD")
    end
end

function Recruitment:_broadcastStatus(playerName, status)
    local payload = string.format("%s|%s", playerName, status)
    NS.Comm:Send(NS.Comm.OP.RECRUIT_STATUS, payload, "GUILD")
end

NS.Comm:On(NS.Comm.OP.RECRUIT_STATUS, function(sender, payload)
    local name, status = payload:match("^([^|]*)|([^|]*)$")
    if not name then return end
    if not Recruitment._applicants[name] then
        Recruitment._applicants[name] = {
            status = status,
            appliedAt = time(),
            notes = "",
            reviewedBy = sender,
        }
    else
        Recruitment._applicants[name].status = status
    end
end)

NS.Comm:On(NS.Comm.OP.RECRUIT_AD, function(sender, payload)
    local adTime = tonumber(payload) or 0
    if adTime > Recruitment._lastAdTime then
        Recruitment._lastAdTime = adTime
    end
end)
