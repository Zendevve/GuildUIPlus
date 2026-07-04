-- GuildUI+ Roster Module
-- Custom columns, search-as-you-type, sort, alt-grouping, multi-filter, right-click context

local ADDON = ...
local NS = _G.GuildUIPlus

local Roster = {
    name = "roster",
    label = "Roster",
    _pool = nil,
    _data = {},
    _filtered = {},
    _search = "",
    _sortCol = "name",
    _sortAsc = true,
    _rankFilter = -1,
    _classFilter = "",
    _showOffline = true,
    _showAlts = true,
    _selectedIdx = nil,
    _scrollOffset = 0,
    _rowHeight = 20,
    _visibleRows = 20,
}

-- Column definitions
local COLUMNS = {
    { key = "name",       label = "Name",         width = 140, align = "LEFT",  sortType = "string" },
    { key = "class",      label = "Class",        width = 90,  align = "LEFT",  sortType = "string" },
    { key = "level",      label = "Lv",           width = 45,  align = "CENTER", sortType = "number" },
    { key = "rank",       label = "Rank",         width = 100, align = "LEFT",  sortType = "number" },
    { key = "zone",       label = "Zone",         width = 130, align = "LEFT",  sortType = "string" },
    { key = "note",       label = "Note",         width = 150, align = "LEFT",  sortType = "string" },
    { key = "offNote",    label = "Officer Note", width = 130, align = "LEFT",  sortType = "string" },
    { key = "lastOnline", label = "Last Online",  width = 90,  align = "RIGHT", sortType = "number" },
    { key = "status",     label = "Status",       width = 60,  align = "CENTER", sortType = "string" },
    { key = "achievementPoints", label = "Achv",  width = 60,  align = "RIGHT", sortType = "number" },
}

local COLUMN_MAP = {}
for i, col in ipairs(COLUMNS) do COLUMN_MAP[col.key] = i end

NS.Loader:Register("roster", Roster)

-- Roster data refresh
function Roster:RefreshData()
    self._data = {}
    if not IsInGuild() then return end

    local numMembers = GetNumGuildMembers(true)
    for i = 1, numMembers do
        local name, rankName, rankIndex, level, classDisplayName, zone, publicNote, officerNote,
              isOnline, status, classFileName, achievementPoints, achievementRank = GetGuildRosterInfo(i)
        if name then
            local shortName = name:match("([^-]+)") or name
            local years, months, days, hours = GetGuildRosterLastOnline(i)
            self._data[#self._data + 1] = {
                idx = i,
                name = shortName,
                fullName = name,
                rank = rankName,
                rankIndex = rankIndex or 0,
                level = level or 0,
                class = classDisplayName or "",
                classToken = classFileName or "",
                zone = zone or "",
                note = publicNote or "",
                offNote = officerNote or "",
                online = isOnline,
                status = status or "",
                lastOnline = (years or 0) * 365 * 24 * 60 + (months or 0) * 30 * 24 * 60 + (days or 0) * 24 * 60 + (hours or 0) * 60,
                lastOnlineText = NS.Util.lastOnlineText(years, months, days, hours),
                achievementPoints = achievementPoints or 0,
                isAlt = Roster:_isAlt(name, rankName, officerNote, publicNote),
                mainName = Roster:_findMain(shortName, officerNote, publicNote),
            }
        end
    end

    self:_applyFilters()
end

function Roster:_isAlt(name, rank, offNote, pubNote)
    local lowerRank = rank:lower()
    if lowerRank:find("alt") then return true end
    if pubNote and pubNote:lower():match("^%w+'?s?%s?alt$") then return true end
    return false
end

function Roster:_findMain(shortName, offNote, pubNote)
    -- Try to find main from officer note (if it contains a name referencing main)
    if offNote and #offNote > 0 and not offNote:match("^[%d%s%-]+$") then
        return offNote
    end
    return nil
end

-- Filtering
function Roster:_applyFilters()
    local filtered = {}

    for _, member in ipairs(self._data) do
        -- Offline filter
        if not member.online and not self._showOffline then
            -- skip
        -- Alt filter
        elseif member.isAlt and not self._showAlts then
            -- skip
        -- Rank filter
        elseif self._rankFilter >= 0 and member.rankIndex ~= self._rankFilter then
            -- skip
        -- Class filter
        elseif self._classFilter ~= "" and member.classToken ~= self._classFilter then
            -- skip
        -- Search filter
        elseif self._search ~= "" then
            local s = self._search:lower()
            if member.name:lower():find(s, 1, true)
            or member.rank:lower():find(s, 1, true)
            or member.class:lower():find(s, 1, true)
            or member.zone:lower():find(s, 1, true)
            or member.note:lower():find(s, 1, true)
            or member.offNote:lower():find(s, 1, true) then
                filtered[#filtered + 1] = member
            end
        else
            filtered[#filtered + 1] = member
        end
    end

    -- Sort
    self:_sortData(filtered)
    self._filtered = filtered
end

function Roster:_sortData(data)
    local col = COLUMN_MAP[self._sortCol]
    if not col then return end
    local colDef = COLUMNS[col]
    local asc = self._sortAsc

    table.sort(data, function(a, b)
        local va, vb
        if colDef.sortType == "number" then
            va = a[self._sortCol] or 0
            vb = b[self._sortCol] or 0
        else
            va = tostring(a[self._sortCol] or ""):lower()
            vb = tostring(b[self._sortCol] or ""):lower()
        end
        if va == vb then
            return a.name < b.name
        end
        if asc then
            return va < vb
        else
            return va > vb
        end
    end)
end

function Roster:SetSearch(text)
    self._search = text
    self:_applyFilters()
    self:_updateDisplay()
end

function Roster:SetSortColumn(col)
    if self._sortCol == col then
        self._sortAsc = not self._sortAsc
    else
        self._sortCol = col
        self._sortAsc = true
    end
    self:_applyFilters()
    self:_updateDisplay()
end

function Roster:SetFilter(key, value)
    if key == "rank" then
        self._rankFilter = value
    elseif key == "class" then
        self._classFilter = value
    elseif key == "offline" then
        self._showOffline = value
    elseif key == "alts" then
        self._showAlts = value
    end
    self:_applyFilters()
    self:_updateDisplay()
end

-- UI Rendering
function Roster:BuildUI()
    local panel = NS.UI:GetModulePanel("roster")
    if not panel or panel._built then return end
    panel._built = true

    -- Search box
    local searchBox = CreateFrame("EditBox", "GuildUIPlusRosterSearch", panel, "InputBoxTemplate")
    searchBox:SetSize(200, 25)
    searchBox:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -50, -5)
    searchBox:SetAutoFocus(false)
    searchBox:SetScript("OnTextChanged", function(self)
        Roster:SetSearch(self:GetText())
    end)
    searchBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)

    local searchLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    searchLabel:SetPoint("RIGHT", searchBox, "LEFT", -10, 0)
    searchLabel:SetText("Search:")

    -- Filter bar
    local filterBar = CreateFrame("Frame", nil, panel)
    filterBar:SetHeight(25)
    filterBar:SetPoint("TOPLEFT", panel, "TOPLEFT", 5, -5)
    filterBar:SetPoint("RIGHT", searchLabel, "LEFT", -15, 0)

    -- Class filter dropdown (placeholder)
    local classFilterBtn = CreateFrame("Button", "GuildUIPlusRosterClassFilter", filterBar, "UIPanelButtonTemplate")
    classFilterBtn:SetSize(80, 22)
    classFilterBtn:SetPoint("LEFT", filterBar, "LEFT", 5, 0)
    classFilterBtn:SetText("All Class")
    classFilterBtn:SetScript("OnClick", function()
        -- Cycle through classes
        local classes = { "", "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "DEATHKNIGHT", "SHAMAN", "MAGE", "WARLOCK", "DRUID" }
        local labels = { "All Class", "Warrior", "Paladin", "Hunter", "Rogue", "Priest", "Death Knight", "Shaman", "Mage", "Warlock", "Druid" }
        local currentIdx = 1
        for i, c in ipairs(classes) do
            if c == Roster._classFilter then currentIdx = i; break end
        end
        local nextIdx = (currentIdx % #classes) + 1
        Roster:SetFilter("class", classes[nextIdx])
        classFilterBtn:SetText(labels[nextIdx])
    end)

    -- Offline toggle
    local offlineBtn = CreateFrame("Button", nil, filterBar, "UIPanelButtonTemplate")
    offlineBtn:SetSize(70, 22)
    offlineBtn:SetPoint("LEFT", classFilterBtn, "RIGHT", 5, 0)
    offlineBtn:SetText("Offline")
    offlineBtn:SetScript("OnClick", function()
        Roster:SetFilter("offline", not Roster._showOffline)
        offlineBtn:SetText(Roster._showOffline and "Offline" or "Online")
    end)

    -- Alt toggle
    local altBtn = CreateFrame("Button", nil, filterBar, "UIPanelButtonTemplate")
    altBtn:SetSize(50, 22)
    altBtn:SetPoint("LEFT", offlineBtn, "RIGHT", 5, 0)
    altBtn:SetText("Alts")
    altBtn:SetScript("OnClick", function()
        Roster:SetFilter("alts", not Roster._showAlts)
    end)

    -- Member count
    local countText = panel:CreateFontString("GuildUIPlusRosterCount", "OVERLAY", "GameFontNormal")
    countText:SetPoint("TOPLEFT", panel, "TOPLEFT", 5, -35)
    countText:SetText("0 members")

    -- Header row
    local headerY = -55
    local headerRow = CreateFrame("Frame", nil, panel)
    headerRow:SetHeight(22)
    headerRow:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, headerY)
    headerRow:SetPoint("RIGHT", panel, "RIGHT", 0, 0)

    local xOffset = 5
    for _, col in ipairs(COLUMNS) do
        local btn = CreateFrame("Button", nil, headerRow)
        btn:SetSize(col.width, 22)
        btn:SetPoint("TOPLEFT", headerRow, "TOPLEFT", xOffset, 0)

        local fs = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        fs:SetPoint("LEFT", btn, "LEFT", 3, 0)
        fs:SetText(col.label)

        btn:SetScript("OnClick", function()
            Roster:SetSortColumn(col.key)
            -- Update arrow indicators
            for _, child in ipairs({ headerRow:GetChildren() }) do
                if child._arrow then
                    if child._colKey == col.key then
                        child._arrow:SetText(Roster._sortAsc and " ^" or " v")
                    else
                        child._arrow:SetText("")
                    end
                end
            end
        end)

        local arrow = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        arrow:SetPoint("RIGHT", btn, "RIGHT", -3, 0)
        arrow:SetTextColor(1, 0.8, 0)
        btn._arrow = arrow
        btn._colKey = col.key

        xOffset = xOffset + col.width
    end

    -- Scroll frame + rows
    local scrollFrame = CreateFrame("ScrollFrame", "GuildUIPlusRosterScroll", panel, "FauxScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, headerY - 24)
    scrollFrame:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -25, 5)
    scrollFrame:SetScript("OnVerticalScroll", function(self, offset)
        FauxScrollFrame_OnVerticalScroll(self, offset, Roster._rowHeight, function() Roster:_updateDisplay() end)
    end)

    -- Create row buttons via frame pool
    self._pool = NS.Util.FramePool:New("Button", scrollFrame, self._visibleRows)
    self._scrollFrame = scrollFrame
    self._headerRow = headerRow
    self._countText = countText
end

function Roster:_updateDisplay()
    if not self._scrollFrame then return end

    local total = #self._filtered
    FauxScrollFrame_Update(self._scrollFrame, total, self._visibleRows, self._rowHeight)

    local offset = FauxScrollFrame_GetOffset(self._scrollFrame)
    self._countText:SetText(string.format("%d members", total))

    -- Release all pooled frames first
    self._pool:ReleaseAll()

    for i = 1, self._visibleRows do
        local idx = offset + i
        if idx <= total then
            local member = self._filtered[idx]
            local row = self._pool:Acquire()
            row:SetSize(self._scrollFrame:GetWidth() - 5, self._rowHeight)

            local xPos = 5
            for _, col in ipairs(COLUMNS) do
                local cellText = ""
                local cellR, cellG, cellB = 1, 1, 1

                if col.key == "name" then
                    cellText = member.name
                    cellR, cellG, cellB = 0, 1, 0
                elseif col.key == "class" then
                    cellText = member.class
                    local c = NS.CLASS_COLORS[member.classToken]
                    if c then cellR, cellG, cellB = c.r, c.g, c.b end
                elseif col.key == "level" then
                    cellText = tostring(member.level)
                elseif col.key == "rank" then
                    cellText = member.rank
                elseif col.key == "zone" then
                    cellText = member.zone
                elseif col.key == "note" then
                    cellText = member.note
                elseif col.key == "offNote" then
                    cellText = member.offNote
                elseif col.key == "lastOnline" then
                    cellText = member.online and "Online" or member.lastOnlineText
                    if not member.online then cellR, cellG, cellB = 0.5, 0.5, 0.5 end
                elseif col.key == "status" then
                    cellText = member.online and "ON" or ""
                    if member.online then cellR, cellG, cellB = 0, 1, 0 else cellR, cellG, cellB = 0.5, 0.5, 0.5 end
                elseif col.key == "achievementPoints" then
                    cellText = member.achievementPoints > 0 and tostring(member.achievementPoints) or ""
                end

                -- Create cell font string
                local fs = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                fs:SetPoint("TOPLEFT", row, "TOPLEFT", xPos, 0)
                fs:SetWidth(col.width - 4)
                fs:SetHeight(self._rowHeight)
                fs:SetJustifyH(col.align == "CENTER" and "CENTER" or col.align == "RIGHT" and "RIGHT" or "LEFT")
                fs:SetText(cellText or "")
                fs:SetTextColor(cellR, cellG, cellB)

                xPos = xPos + col.width
            end

            -- Dim offline
            if not member.online then
                row:SetAlpha(0.5)
            else
                row:SetAlpha(1)
            end

            -- Position row
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", self._scrollFrame, "TOPLEFT", 5, -((i - 1) * self._rowHeight))
            row:SetPoint("RIGHT", self._scrollFrame, "RIGHT", -5, 0)

            -- Click handler
            local memberCopy = member
            local idxCopy = idx
            row:SetScript("OnClick", function(self, button)
                if button == "LeftButton" then
                    Roster._selectedIdx = idxCopy
                    Roster:_showMemberDetail(memberCopy)
                end
            end)

            row:Show()
        end
    end
end

function Roster:_showMemberDetail(member)
    -- Detail frame (reusable)
    local detail = _G["GuildUIPlusRosterDetail"]
    if not detail then
        detail = NS.UI:CreateDialogFrame("GuildUIPlusRosterDetail", "Member Details", UIParent)
        detail:SetSize(300, 350)
        tinsert(UISpecialFrames, "GuildUIPlusRosterDetail")
    end

    detail:Show()
    detail.TitleText:SetText(member.name)

    -- Clear previous content
    for _, child in ipairs({ detail:GetChildren() }) do
        if child ~= detail.CloseButton and child:GetName() ~= "GuildUIPlusRosterDetailTitleText" then
            child:Hide()
        end
    end

    local yOff = -40
    local function AddLine(label, value, r, g, b)
        local fs = detail:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        fs:SetPoint("TOPLEFT", detail, "TOPLEFT", 20, yOff)
        fs:SetText(string.format("%s: |cffffffff%s", label, value))
        if r then fs:SetTextColor(r, g, b) end
        yOff = yOff - 18
    end

    local c = NS.CLASS_COLORS[member.classToken]
    AddLine("Name", member.name)
    AddLine("Class", member.class, c and c.r, c and c.g, c and c.b)
    AddLine("Level", tostring(member.level))
    AddLine("Rank", string.format("%s (%d)", member.rank, member.rankIndex))
    AddLine("Zone", member.zone ~= "" and member.zone or "Unknown")
    AddLine("Status", member.online and "|cff00ff00Online|r" or "|cff808080Offline|r")
    if member.note ~= "" then AddLine("Public Note", member.note) end
    if member.offNote ~= "" then AddLine("Officer Note", member.offNote) end
    AddLine("Achievement Points", tostring(member.achievementPoints))
    if member.lastOnline > 0 and not member.online then
        AddLine("Last Online", member.lastOnlineText)
    end
end

-- Module lifecycle
function Roster:OnLoad()
    -- Wire up comm handlers for ROSTER_REQUEST / ROSTER_DATA / ROSTER_DIFF
    NS.Comm:On(NS.Comm.OP.ROSTER_REQUEST, function(sender, payload)
        -- Respond with our roster snapshot (throttled)
        Roster:_broadcastRosterSnapshot()
    end)

    NS.Comm:On(NS.Comm.OP.ROSTER_DIFF, function(sender, payload)
        -- Apply incremental diff from another guild member
        Roster:_applyDiff(payload)
    end)
end

function Roster:_broadcastRosterSnapshot()
    -- Serialize current roster into compact format
    local count = 0
    local parts = {}
    for _, m in ipairs(self._data) do
        if m.online then
            count = count + 1
            parts[#parts + 1] = string.format("%s|%s|%d|%s|%s|%s",
                m.name, m.classToken, m.level, m.rankIndex, m.zone, m.note)
        end
    end
    local payload = string.format("%d:%s", count, table.concat(parts, "\n"))
    NS.Comm:Send(NS.Comm.OP.ROSTER_DATA, payload, "GUILD", nil)
end

function Roster:_applyDiff(payload)
    -- Stub: apply incremental roster change
end

-- Hook into ON_ROSTER event
NS.Loader:On("ON_ROSTER", function()
    Roster:RefreshData()
    Roster:_updateDisplay()
end)

NS.Loader:On("ON_READY", function()
    Roster:BuildUI()
    Roster:RefreshData()
    NS.UI:RegisterModuleTab("roster", "Roster", nil, 1)
end)
