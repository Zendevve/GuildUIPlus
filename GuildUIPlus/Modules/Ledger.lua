-- GuildUI+ Ledger Module
-- DKP/EPGP/item-ledger, undo-window, immutable audit

local ADDON, NS = ...

local Ledger = {
    name = "ledger",
    label = "Ledger",
    _pendingRevokes = {}, -- undo window: [entryId] = { entry, expiresAt }
    _undoWindow = 60,     -- seconds
}

NS.Loader:Register("ledger", Ledger)

function Ledger:GetSystem()
    local db = NS.Settings:Get("ledger")
    return db.system or "dkp"
end

function Ledger:SetSystem(system)
    local db = NS.Settings:Get("ledger")
    db.system = system
end

function Ledger:GetEntries()
    local db = NS.Settings:Get("ledger")
    return db.entries or {}
end

function Ledger:AddEntry(actor, action, amount, target, reason)
    local db = NS.Settings:Get("ledger")
    if not db.entries then db.entries = {} end

    local entry = {
        id = #db.entries + 1,
        actor = actor,
        action = action,
        amount = amount,
        target = target,
        reason = reason or "",
        timestamp = time(),
        hash = "",  -- computed below
    }

    -- Compute hash chain (previous entry hash + this entry data)
    local prevHash = #db.entries > 0 and db.entries[#db.entries].hash or "00000000"
    local dataStr = string.format("%s|%s|%s|%d|%s|%s|%d",
        prevHash, actor, action, amount, target, entry.reason, entry.timestamp)
    entry.hash = string.format("%08x", NS.Util.crc32(dataStr))

    db.entries[#db.entries + 1] = entry

    -- Broadcast
    self:_broadcastEntry(entry)

    -- Fire notifier
    local notifier = NS.Loader:Get("notifier")
    if notifier then
        notifier:Fire("ledger_event", {
            actor = actor,
            action = action,
            amount = amount,
            target = target,
        })
    end

    return entry.id
end

function Ledger:RevokeEntry(entryId, revoactor)
    local db = NS.Settings:Get("ledger")
    if not db.entries then return end

    local entry = db.entries[entryId]
    if not entry then return end

    -- Add to undo window
    self._pendingRevokes[entryId] = {
        entry = entry,
        expiresAt = time() + self._undoWindow,
        revoactor = revoactor,
    }

    -- Broadcast revoke
    local payload = string.format("%d|%s", entryId, revoactor)
    NS.Comm:Send(NS.Comm.OP.LEDGER_REVOKE, payload, "GUILD")

    -- Mark entry as revoked (not deleted — immutable audit)
    entry.revoked = true
    entry.revokedBy = revoactor
    entry.revokedAt = time()
end

function Ledger:ConfirmRevoke(entryId)
    self._pendingRevokes[entryId] = nil
end

function Ledger:UndoRevoke(entryId)
    local pending = self._pendingRevokes[entryId]
    if not pending then return end
    if time() > pending.expiresAt then
        self._pendingRevokes[entryId] = nil
        return
    end
    pending.entry.revoked = false
    pending.entry.revokedBy = nil
    pending.entry.revokedAt = nil
    self._pendingRevokes[entryId] = nil
end

function Ledger:GetPlayerBalance(playerName)
    local db = NS.Settings:Get("ledger")
    if not db.entries then return 0 end

    local balance = 0
    for _, entry in ipairs(db.entries) do
        if not entry.revoked and entry.target == playerName then
            if entry.action == "credit" or entry.action == "award" then
                balance = balance + entry.amount
            elseif entry.action == "spend" or entry.action == "bid" then
                balance = balance - entry.amount
            end
        end
    end
    return balance
end

function Ledger:VerifyIntegrity()
    local db = NS.Settings:Get("ledger")
    if not db.entries then return true end

    local prevHash = "00000000"
    for i, entry in ipairs(db.entries) do
        local dataStr = string.format("%s|%s|%s|%d|%s|%s|%d",
            prevHash, entry.actor, entry.action, entry.amount, entry.target, entry.reason, entry.timestamp)
        local expected = string.format("%08x", NS.Util.crc32(dataStr))
        if expected ~= entry.hash then
            return false, i
        end
        prevHash = entry.hash
    end
    return true
end

function Ledger:_broadcastEntry(entry)
    local payload = string.format("%d|%s|%s|%d|%s|%s|%d|%s",
        entry.id, entry.actor, entry.action, entry.amount, entry.target, entry.reason, entry.timestamp, entry.hash)
    NS.Comm:Send(NS.Comm.OP.LEDGER_ENTRY, payload, "GUILD")
end

NS.Comm:On(NS.Comm.OP.LEDGER_ENTRY, function(sender, payload)
    local id, actor, action, amount, target, reason, ts, hash = payload:match(
        "^(%d+)|([^|]*)|([^|]*)|(%d+)|([^|]*)|([^|]*)|(%d+)|([^|]*)$")
    if not id then return end
    -- Store incoming entry (handled by settings merge)
end)

NS.Comm:On(NS.Comm.OP.LEDGER_REVOKE, function(sender, payload)
    local id, revoactor = payload:match("^(%d+)|([^|]*)$")
    if not id then return end
    id = tonumber(id)
    local db = NS.Settings:Get("ledger")
    if db.entries and db.entries[id] then
        db.entries[id].revoked = true
        db.entries[id].revokedBy = revoactor
        db.entries[id].revokedAt = time()
    end
end)
