-- GuildUI+ Forum Module
-- Reddit-style threads, sticky, polls, edit-history, subscriptions

local ADDON, NS = ...

local Forum = {
    name = "forum",
    label = "Forum",
    _posts = {},       -- flat array of posts
    _threads = {},     -- thread indices (top-level posts)
    _polls = {},       -- poll data keyed by postId
    _editHistory = {}, -- keyed by postId
    _subscriptions = {}, -- posts user is subscribed to
    _nextId = 1,
    _selectedThread = nil,
}

NS.Loader:Register("forum", Forum)

-- Post structure:
-- { id, parentId, author, title, content, timestamp, isSticky, isPoll, pollOptions, pollVotes, isDeleted, editCount }

function Forum:CreatePost(parentId, author, title, content, isSticky, isPoll, pollOptions)
    local post = {
        id = self._nextId,
        parentId = parentId,
        author = author,
        title = title or "",
        content = content,
        timestamp = time(),
        isSticky = isSticky or false,
        isPoll = isPoll or false,
        pollOptions = pollOptions or {},
        pollVotes = {},
        isDeleted = false,
        editCount = 0,
    }
    self._posts[self._nextId] = post
    self._nextId = self._nextId + 1

    if not parentId then
        self._threads[#self._threads + 1] = post.id
    end

    -- Broadcast
    self:_broadcastPost(post)
    self:_updateDisplay()
    return post.id
end

function Forum:EditPost(postId, newContent, editor)
    local post = self._posts[postId]
    if not post or post.isDeleted then return end
    if post.author ~= editor then return end

    -- Save history
    if not self._editHistory[postId] then
        self._editHistory[postId] = {}
    end
    self._editHistory[postId][#self._editHistory[postId] + 1] = {
        content = post.content,
        editedBy = editor,
        timestamp = time(),
    }

    post.content = newContent
    post.editCount = post.editCount + 1
    self:_broadcastEdit(post)
    self:_updateDisplay()
end

function Forum:DeletePost(postId, deleter)
    local post = self._posts[postId]
    if not post then return end
    -- Only author or guild master can delete
    if post.author ~= deleter and not IsGuildLeader() then return end

    post.isDeleted = true
    post.content = "[deleted]"
    self:_broadcastDelete(post)
    self:_updateDisplay()
end

function Forum:StickyPost(postId, state, author)
    local post = self._posts[postId]
    if not post then return end
    if not IsGuildLeader() then return end
    post.isSticky = state
    self:_broadcastPost(post)
    self:_updateDisplay()
end

function Forum:VotePoll(postId, optionIdx, voter)
    local post = self._posts[postId]
    if not post or not post.isPoll then return end
    if not post.pollVotes[voter] then
        post.pollVotes[voter] = optionIdx
    end
    self:_updateDisplay()
end

function Forum:GetThread(postId)
    local post = self._posts[postId]
    if not post then return nil end
    local children = {}
    for _, p in pairs(self._posts) do
        if p.parentId == postId and not p.isDeleted then
            children[#children + 1] = p
        end
    end
    table.sort(children, function(a, b) return a.timestamp < b.timestamp end)
    return post, children
end

function Forum:GetThreads()
    local threads = {}
    for _, id in ipairs(self._threads) do
        local post = self._posts[id]
        if post and not post.isDeleted then
            threads[#threads + 1] = post
        end
    end
    -- Sort: stickies first, then by timestamp desc
    table.sort(threads, function(a, b)
        if a.isSticky and not b.isSticky then return true end
        if not a.isSticky and b.isSticky then return false end
        return a.timestamp > b.timestamp
    end)
    return threads
end

-- Comm
function Forum:_broadcastPost(post)
    local payload = string.format("%d|%s|%s|%s|%d|%d",
        post.id, post.parentId or "", post.author, post.title, post.isSticky and 1 or 0, post.timestamp)
    NS.Comm:Send(NS.Comm.OP.FORUM_POST, payload, "GUILD")
end

function Forum:_broadcastEdit(post)
    local payload = string.format("%d|%s", post.id, post.content)
    NS.Comm:Send(NS.Comm.OP.FORUM_REPLY, payload, "GUILD")
end

function Forum:_broadcastDelete(post)
    NS.Comm:Send(NS.Comm.OP.FORUM_DELETE, tostring(post.id), "GUILD")
end

-- Comm handlers
NS.Comm:On(NS.Comm.OP.FORUM_POST, function(sender, payload)
    local id, parentId, author, title, sticky, ts = payload:match("^(%d+)|([^|]*)|([^|]*)|([^|]*)|(%d+)|(%d+)$")
    if not id then return end
    id = tonumber(id)
    parentId = parentId ~= "" and tonumber(parentId) or nil
    sticky = tonumber(sticky) == 1
    ts = tonumber(ts)

    if not Forum._posts[id] then
        Forum._posts[id] = {
            id = id,
            parentId = parentId,
            author = author,
            title = title,
            content = "",
            timestamp = ts or time(),
            isSticky = sticky,
            isPoll = false,
            pollOptions = {},
            pollVotes = {},
            isDeleted = false,
            editCount = 0,
        }
        if not parentId then
            Forum._threads[#Forum._threads + 1] = id
        end
    end
end)

NS.Comm:On(NS.Comm.OP.FORUM_REPLY, function(sender, payload)
    local id, content = payload:match("^(%d+)|(.*)$")
    if not id then return end
    id = tonumber(id)
    local post = Forum._posts[id]
    if post then
        post.content = content
    end
end)

NS.Comm:On(NS.Comm.OP.FORUM_DELETE, function(sender, payload)
    local id = tonumber(payload)
    if id and Forum._posts[id] then
        Forum._posts[id].isDeleted = true
        Forum._posts[id].content = "[deleted]"
    end
end)

NS.Loader:On("ON_LOAD", function()
    -- Register OP handlers (already done via NS.Comm:On above)
end)
