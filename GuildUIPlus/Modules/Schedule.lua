-- GuildUI+ Schedule Module
-- Calendar, recurring events, role sign-up, attendance roll-up

local ADDON = ...
local NS = _G.GuildUIPlus

local Schedule = {
    name = "schedule",
    label = "Schedule",
    _events = {},
    _nextId = 1,
}

NS.Loader:Register("schedule", Schedule)

-- Event structure:
-- { id, title, description, startTime, duration, recurrence, creator, roles, signups, maxRoles, recurringDays }

function Schedule:CreateEvent(title, description, startTime, duration, recurrence, creator, roles)
    local event = {
        id = self._nextId,
        title = title,
        description = description or "",
        startTime = startTime,
        duration = duration or 7200,
        recurrence = recurrence or "none",  -- none, daily, weekly
        recurringDays = {},  -- for weekly: which days (1=Sun..7=Sat)
        creator = creator,
        roles = roles or { tank = 0, healer = 0, dps = 0 },
        maxRoles = { tank = 2, healer = 4, dps = 14 },
        signups = {},
        attendees = {},
        notified = false,
    }
    self._events[self._nextId] = event
    self._nextId = self._nextId + 1

    self:_broadcastCreate(event)
    return event.id
end

function Schedule:CancelEvent(eventId)
    local event = self._events[eventId]
    if not event then return end
    event.cancelled = true
    self:_broadcastCancel(event)
end

function Schedule:Signup(eventId, playerName, role)
    local event = self._events[eventId]
    if not event or event.cancelled then return end
    if not event.signups[playerName] then
        event.signups[playerName] = { role = role, timestamp = time() }
        self:_broadcastSignup(event, playerName, role)
    end
end

function Schedule:Signoff(eventId, playerName)
    local event = self._events[eventId]
    if not event then return end
    event.signups[playerName] = nil
end

function Schedule:GetUpcoming()
    local now = time()
    local upcoming = {}
    for _, event in pairs(self._events) do
        if not event.cancelled and event.startTime > now then
            upcoming[#upcoming + 1] = event
        end
    end
    table.sort(upcoming, function(a, b) return a.startTime < b.startTime end)
    return upcoming
end

function Schedule:GetEventCounts(eventId)
    local event = self._events[eventId]
    if not event then return 0, 0, 0 end
    local tanks, healers, dps = 0, 0, 0
    for _, signup in pairs(event.signups) do
        if signup.role == "tank" then tanks = tanks + 1
        elseif signup.role == "healer" then healers = healers + 1
        else dps = dps + 1
        end
    end
    return tanks, healers, dps
end

function Schedule:CheckReminders()
    local now = time()
    for _, event in pairs(self._events) do
        if not event.cancelled and not event.notified then
            local minutesUntil = (event.startTime - now) / 60
            if minutesUntil > 0 and minutesUntil <= 30 then
                event.notified = true
                -- Fire notification
                local notifier = NS.Loader:Get("notifier")
                if notifier then
                    notifier:Fire("schedule_reminder", {
                        eventName = event.title,
                        minutesLeft = math.ceil(minutesUntil),
                    })
                end
            end
        end
    end
end

-- Comm
function Schedule:_broadcastCreate(event)
    local payload = string.format("%d|%s|%s|%d|%d|%s",
        event.id, event.title, event.creator, event.startTime, event.duration, event.recurrence)
    NS.Comm:Send(NS.Comm.OP.SCHED_CREATE, payload, "GUILD")
end

function Schedule:_broadcastSignup(event, player, role)
    local payload = string.format("%d|%s|%s", event.id, player, role)
    NS.Comm:Send(NS.Comm.OP.SCHED_SIGNUP, payload, "GUILD")
end

function Schedule:_broadcastCancel(event)
    NS.Comm:Send(NS.Comm.OP.SCHED_CANCEL, tostring(event.id), "GUILD")
end

NS.Comm:On(NS.Comm.OP.SCHED_CREATE, function(sender, payload)
    local id, title, creator, startTime, duration, rec = payload:match("^(%d+)|([^|]*)|([^|]*)|(%d+)|(%d+)|([^|]*)$")
    if not id then return end
    id = tonumber(id)
    startTime = tonumber(startTime)
    duration = tonumber(duration)
    if not Schedule._events[id] then
        Schedule._events[id] = {
            id = id, title = title, description = "", startTime = startTime, duration = duration,
            recurrence = rec, creator = creator, roles = {}, maxRoles = {},
            signups = {}, attendees = {}, notified = false,
        }
    end
end)

NS.Comm:On(NS.Comm.OP.SCHED_SIGNUP, function(sender, payload)
    local id, player, role = payload:match("^(%d+)|([^|]*)|([^|]*)$")
    if not id then return end
    id = tonumber(id)
    local event = Schedule._events[id]
    if event then
        event.signups[player] = { role = role, timestamp = time() }
    end
end)

NS.Comm:On(NS.Comm.OP.SCHED_CANCEL, function(sender, payload)
    local id = tonumber(payload)
    if id and Schedule._events[id] then
        Schedule._events[id].cancelled = true
    end
end)

-- Periodic reminder check
NS.Loader:On("ON_READY", function()
    NS.Util.NewTicker(60, function() Schedule:CheckReminders() end)
end)
