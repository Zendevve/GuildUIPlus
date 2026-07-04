-- GuildUI+ Communication Protocol
-- Versioned text protocol on GUILD/WHISPER/CHANNEL
-- Prefix: GG1 (3 chars), body carries: version(1) + OP(1) + flags(1) + msgid(2) + payload(...)

local ADDON = ...
local NS = _G.GuildUIPlus

NS.Comm = {
    MSG_ID_MAX = 65535,
    _msgId = 0,
    _seenIds = {},   -- ring buffer for dedup
    _ringPos = 0,
    _ringSize = 512,
    _handlers = {},
    _throttle = {},  -- per-OP throttle timestamps
}

-- OP codes (stable table, append-only)
NS.Comm.OP = {
    -- Roster sync
    ROSTER_REQUEST  = 0x01,
    ROSTER_DATA     = 0x02,
    ROSTER_DIFF     = 0x03,

    -- Forum sync
    FORUM_REQUEST   = 0x10,
    FORUM_POST      = 0x11,
    FORUM_DELETE    = 0x12,
    FORUM_REPLY     = 0x13,
    FORUM_STICKY    = 0x14,
    FORUM_POLL      = 0x15,
    FORUM_VOTE      = 0x16,

    -- Schedule
    SCHED_CREATE    = 0x20,
    SCHED_UPDATE    = 0x21,
    SCHED_CANCEL    = 0x22,
    SCHED_SIGNUP    = 0x23,
    SCHED_SIGNOFF   = 0x24,

    -- Recruitment
    RECRUIT_APPLY   = 0x30,
    RECRUIT_STATUS  = 0x31,
    RECRUIT_AD      = 0x32,

    -- Attendance
    ATTEND_CHECKIN  = 0x40,
    ATTEND_CHECKOUT = 0x41,
    ATTEND_DIGEST   = 0x42,

    -- Ledger
    LEDGER_ENTRY    = 0x50,
    LEDGER_REVOKE   = 0x51,

    -- Notifier
    NOTIFY_EVENT    = 0x60,

    -- Locator
    LOC_UPDATE      = 0x70,
    LOC_REQUEST     = 0x71,

    -- MOTD
    MOTD_SYNC       = 0x80,

    -- Admin
    ADMIN_PING      = 0xF0,
    ADMIN_VERSION   = 0xF1,
    ADMIN_KICKLOG   = 0xF2,
}

-- Flag bits
NS.Comm.FLAG_URGENT  = 0x01
NS.Comm.FLAG_BCAST   = 0x02
NS.Comm.FLAG_WHISPER = 0x04

-- Init ring buffer
for i = 1, NS.Comm._ringSize do
    NS.Comm._seenIds[i] = 0
end

function NS.Comm:NextMsgId()
    self._msgId = (self._msgId + 1) % self.MSG_ID_MAX
    return self._msgId
end

function NS.Comm:IsDupe(sender, msgId)
    for i = 1, self._ringSize do
        if self._seenIds[i] == sender .. ":" .. msgId then
            return true
        end
    end
    return false
end

function NS.Comm:RecordMsg(sender, msgId)
    local key = sender .. ":" .. msgId
    self._ringPos = (self._ringPos % self._ringSize) + 1
    self._seenIds[self._ringPos] = key
end

-- Encode: version(1) + OP(1) + flags(1) + msgid(2, little-endian) + payload(...)
function NS.Comm:Encode(op, flags, payload)
    local msgId = self:NextMsgId()
    local hi = math.floor(msgId / 256)
    local lo = msgId % 256
    local header = string.char(
        NS.PROTOCOL_VERSION,
        op,
        flags or 0,
        lo,
        hi
    )
    return header .. (payload or ""), msgId
end

-- Decode
function NS.Comm:Decode(data)
    if #data < 5 then return nil end
    local version = string.byte(data, 1)
    local op = string.byte(data, 2)
    local flags = string.byte(data, 3)
    local lo = string.byte(data, 4)
    local hi = string.byte(data, 5)
    local msgId = hi * 256 + lo
    local payload = data:sub(6)
    return {
        version = version,
        op = op,
        flags = flags,
        msgId = msgId,
        payload = payload,
    }
end

-- Register handler for an OP
function NS.Comm:On(op, handler)
    if not self._handlers[op] then
        self._handlers[op] = {}
    end
    self._handlers[op][#self._handlers[op] + 1] = handler
end

-- Send to channel
function NS.Comm:Send(op, payload, channel, target, flags)
    flags = flags or 0
    local data, msgId = self:Encode(op, flags, payload)
    local fullMsg = NS.COMM_PREFIX .. data

    if channel == "WHISPER" then
        SendAddonMessage(NS.COMM_PREFIX, data, "WHISPER", target)
    elseif channel == "CHANNEL" then
        SendAddonMessage(NS.COMM_PREFIX, data, "CHANNEL", target)
    else
        SendAddonMessage(NS.COMM_PREFIX, data, "GUILD")
    end
end

-- Handle incoming
function NS.Comm:HandleIncoming(prefix, data, channel, sender)
    if prefix ~= NS.COMM_PREFIX then return end
    if sender == UnitName("player") then return end

    local msg = self:Decode(data)
    if not msg then return end

    -- Version check (reject future protocol versions)
    if msg.version > NS.PROTOCOL_VERSION then return end

    -- Dedup
    if self:IsDupe(sender, msg.msgId) then return end
    self:RecordMsg(sender, msg.msgId)

    -- Dispatch
    local handlers = self._handlers[msg.op]
    if handlers then
        for i = 1, #handlers do
            local ok, err = pcall(handlers[i], sender, msg.payload, channel, msg)
            if not ok then
                print(string.format("|cffff0000[GUI+]|r Comm handler error (OP 0x%02x): %s", msg.op, err))
            end
        end
    end
end

-- Bootstrap
NS.Loader:On("ON_LOAD", function()
    RegisterAddonMessagePrefix(NS.COMM_PREFIX)
end)

NS.Loader:On("ON_COMM", function(sender, data, channel)
    NS.Comm:HandleIncoming(NS.COMM_PREFIX, data, channel, sender)
end)
