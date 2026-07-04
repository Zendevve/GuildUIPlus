-- GuildUI+ Webhook Module
-- Discord outbound via officer channel, retry queue, templates

local ADDON, NS = ...

local Webhook = {
    name = "webhook",
    label = "Webhook",
    _queue = {},    -- messages waiting to send
    _lastSend = 0,
    _throttle = 5,  -- seconds between sends
}

NS.Loader:Register("webhook", Webhook)

-- Message templates
local TEMPLATES = {
    KICK       = "**%s** was removed from the guild by %s. Reason: %s",
    PROMOTE    = "**%s** was promoted to %s by %s.",
    DEMOTE     = "**%s** was demoted to %s by %s.",
    JOIN       = "**%s** has joined the guild!",
    LEDGER     = "%s %d points: %s → %s (%s)",
    EVENT      = "Event **%s** created by %s, starting %s",
    RECRUIT    = "New application from **%s**",
    FORUM_POST = "New forum post: *%s* by %s",
    ATTENDANCE = "Weekly attendance digest posted.",
}

function Webhook:SetEnabled(enabled)
    NS.Settings:Set("webhook", "enabled", enabled)
end

function Webhook:SetURL(url)
    NS.Settings:Set("webhook", "url", url)
end

function Webhook:SendMessage(template, ...)
    if not NS.Settings:Get("webhook", "enabled") then return end
    local url = NS.Settings:Get("webhook", "url")
    if not url or url == "" then return end

    local msg = string.format(TEMPLATES[template] or template, ...)
    self:_queueMessage(msg)
end

function Webhook:_queueMessage(msg)
    self._queue[#self._queue + 1] = {
        text = msg,
        timestamp = time(),
        retries = 0,
    }
    self:_processQueue()
end

function Webhook:_processQueue()
    if #self._queue == 0 then return end
    local now = GetTime()
    if (now - self._lastSend) < self._throttle then return end

    local entry = table.remove(self._queue, 1)
    if entry then
        -- In WoW 3.3.5a, we send via officer chat as proxy to external bot
        -- The external bot listens to officer channel and forwards to Discord
        local payload = string.format("WEBHOOK|%s", entry.text)
        SendAddonMessage(NS.COMM_PREFIX, payload, "OFFICER")
        self._lastSend = now
    end
end

function Webhook:OnEvent(event, ...)
    if event == "GUILD_ROSTER_UPDATE" then
        -- Nothing for now
    end
end
