-- GuildUI+ Notifier Module
-- Rule engine: officer online, crafter, same-zone, achievement cap, ledger event

local ADDON = ...
local NS = _G.GuildUIPlus

local Notifier = {
    name = "notifier",
    label = "Notify",
    _onlineMembers = {},
    _lastZone = "",
    _cooldowns = {},
}

NS.Loader:Register("notifier", Notifier)

-- Rule types
local RULE_TYPES = {
    OFFICER_ONLINE    = "officer_online",
    CRAFTER_ONLINE    = "crafter_online",
    SAME_ZONE         = "same_zone",
    ACHIEVEMENT_CAP   = "achievement_cap",
    LEDGER_EVENT      = "ledger_event",
    SCHEDULE_REMINDER = "schedule_reminder",
    NEW_POST          = "new_post",
}

local PROFESSIONS = {
    "Alchemy", "Blacksmithing", "Enchanting", "Engineering",
    "Inscription", "Jewelcrafting", "Leatherworking", "Tailoring",
    "Mining", "Herbalism", "Skinning", "Cooking", "First Aid", "Fishing",
}

function Notifier:AddRule(ruleType, params)
    local db = NS.Settings:Get("notifier")
    if not db.rules then db.rules = {} end
    local rule = {
        id = #db.rules + 1,
        type = ruleType,
        params = params or {},
        enabled = true,
        cooldownSeconds = params.cooldownSeconds or 60,
    }
    db.rules[rule.id] = rule
    return rule.id
end

function Notifier:RemoveRule(ruleId)
    local db = NS.Settings:Get("notifier")
    if db.rules and db.rules[ruleId] then
        db.rules[ruleId].enabled = false
    end
end

function Notifier:Fire(ruleType, data)
    local db = NS.Settings:Get("notifier")
    if not db.rules then return end

    for _, rule in pairs(db.rules) do
        if rule.enabled and rule.type == ruleType then
            if self:_checkCooldown(rule.id, rule.cooldownSeconds) then
                self:_formatAndSend(rule, data)
            end
        end
    end
end

function Notifier:_checkCooldown(ruleId, duration)
    local now = time()
    if self._cooldowns[ruleId] and (now - self._cooldowns[ruleId]) < duration then
        return false
    end
    self._cooldowns[ruleId] = now
    return true
end

function Notifier:_formatAndSend(rule, data)
    local guildName = GetGuildInfo("player") or "Guild"
    local prefix = string.format("[%s]", guildName)
    local msg = ""

    if rule.type == RULE_TYPES.OFFICER_ONLINE then
        msg = string.format("%s Officer %s is now online.", prefix, data.name)
    elseif rule.type == RULE_TYPES.CRAFTER_ONLINE then
        msg = string.format("%s %s (%s) is now online.", prefix, data.name, data.profession)
    elseif rule.type == RULE_TYPES.SAME_ZONE then
        if data.count == 1 then
            msg = string.format("%s %s is in %s", prefix, data.names[1], data.zone)
        else
            msg = string.format("%s %d guild members are in %s", prefix, data.count, data.zone)
        end
    elseif rule.type == RULE_TYPES.ACHIEVEMENT_CAP then
        msg = string.format("%s %s reached %d achievement points!", prefix, data.name, data.points)
    elseif rule.type == RULE_TYPES.LEDGER_EVENT then
        msg = string.format("%s %s: %s %d points to %s", prefix, data.actor, data.action, data.amount, data.target)
    elseif rule.type == RULE_TYPES.SCHEDULE_REMINDER then
        msg = string.format("%s %s starting in %d minutes", prefix, data.eventName, data.minutesLeft)
    elseif rule.type == RULE_TYPES.NEW_POST then
        msg = string.format("%s New forum post: '%s' by %s", prefix, data.title, data.author)
    end

    if msg ~= "" then
        DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[GUI+]|r " .. msg)
        -- Also fire to webhook if configured
        local wh = NS.Settings:Get("webhook")
        if wh and wh.enabled and wh.url and wh.url ~= "" then
            NS.Comm:Send(NS.Comm.OP.NOTIFY_EVENT, msg, "GUILD")
        end
    end
end

-- Detection hooks
function Notifier:OnGuildRosterUpdate()
    local numMembers = GetNumGuildMembers(true)
    local newOnline = {}
    local guildName = GetGuildInfo("player") or ""
    local myRankIndex = select(3, GetGuildInfo("player")) or 99

    for i = 1, numMembers do
        local name, _, rankIndex, _, _, _, _, _, isOnline = GetGuildRosterInfo(i)
        if isOnline then
            local shortName = name:match("([^-]+)") or name
            newOnline[shortName] = true

            -- Officer online check
            if not self._onlineMembers[shortName] and rankIndex <= 2 then
                self:Fire(RULE_TYPES.OFFICER_ONLINE, { name = shortName })
            end

            -- Crafter online check
            if not self._onlineMembers[shortName] then
                local note = select(7, GetGuildRosterInfo(i))
                for _, prof in ipairs(PROFESSIONS) do
                    if note and note:find(prof) then
                        self:Fire(RULE_TYPES.CRAFTER_ONLINE, { name = shortName, profession = prof })
                        break
                    end
                end
            end
        end
    end

    self._onlineMembers = newOnline
end

function Notifier:OnZoneChanged()
    local currentZone = GetRealZoneText()
    if currentZone == self._lastZone or currentZone == "" then return end
    self._lastZone = currentZone

    local count = 0
    local names = {}
    local numMembers = GetNumGuildMembers(true)

    for i = 1, numMembers do
        local name, _, _, _, _, zone, _, _, isOnline = GetGuildRosterInfo(i)
        if isOnline and zone == currentZone then
            count = count + 1
            names[#names + 1] = name:match("([^-]+)") or name
        end
    end

    if count > 0 then
        self:Fire(RULE_TYPES.SAME_ZONE, {
            zone = currentZone,
            count = count,
            names = names,
        })
    end
end

NS.Loader:On("ON_ROSTER", function()
    Notifier:OnGuildRosterUpdate()
end)

NS.Loader:On("ON_ZONE", function()
    Notifier:OnZoneChanged()
end)
