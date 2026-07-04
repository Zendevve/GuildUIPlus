-- GuildUI+ Main UI Framework
-- Frame pool, main frame, module rail, tab switching

local ADDON, NS = ...

NS.UI = {
    mainFrame = nil,
    moduleTabs = {},
    activeModule = nil,
    modulePanels = {},
    pool = nil,
}

-- Constants
local FRAME_WIDTH = 800
local FRAME_HEIGHT = 600
local RAIL_WIDTH = 120
local HEADER_HEIGHT = 40
local TAB_HEIGHT = 24

function NS.UI:CreateMainFrame()
    if self.mainFrame then return self.mainFrame end

    local f = CreateFrame("Frame", "GuildUIPlusFrame", UIParent, "ButtonFrameTemplate")
    f:SetSize(FRAME_WIDTH, FRAME_HEIGHT)
    f:SetPoint("CENTER")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetClampedToScreen(true)
    f:SetFrameStrata("DIALOG")
    tinsert(UISpecialFrames, "GuildUIPlusFrame")

    -- Title
    f.TitleText:SetText("GuildUI+")
    f.TitleText:SetFontObject(GameFontNormalLarge)

    -- Close button
    f.CloseButton:SetScript("OnClick", function() f:Hide() end)

    -- Module rail (left sidebar)
    f.rail = CreateFrame("Frame", nil, f)
    f.rail:SetWidth(RAIL_WIDTH)
    f.rail:SetPoint("TOPLEFT", f, "TOPLEFT", 70, -65)
    f.rail:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 70, 25)

    -- Content area
    f.content = CreateFrame("Frame", nil, f)
    f.content:SetPoint("TOPLEFT", f.rail, "TOPRIGHT", 5, 0)
    f.content:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -17, 25)

    self.mainFrame = f
    return f
end

function NS.UI:RegisterModuleTab(name, label, icon, order)
    self.moduleTabs[name] = {
        label = label,
        icon = icon,
        order = order or #self.moduleTabs + 1,
        panel = nil,
    }
end

function NS.UI:BuildRail()
    local f = self.mainFrame
    if not f then return end

    -- Clear existing rail buttons
    for _, child in ipairs({ f.rail:GetChildren() }) do
        child:Hide()
        child:SetParent(nil)
    end

    -- Sort tabs by order
    local sorted = {}
    for name, data in pairs(self.moduleTabs) do
        sorted[#sorted + 1] = { name = name, label = data.label, icon = data.icon, order = data.order }
    end
    table.sort(sorted, function(a, b) return a.order < b.order end)

    -- Create rail buttons
    local prev = nil
    for i, tab in ipairs(sorted) do
        local btn = CreateFrame("Button", nil, f.rail, "UIPanelButtonTemplate")
        btn:SetHeight(TAB_HEIGHT)
        btn:SetText(tab.label)
        btn:SetPoint("TOPLEFT", f.rail, "TOPLEFT", 0, -(i - 1) * (TAB_HEIGHT + 2))
        btn:SetPoint("RIGHT", f.rail, "RIGHT", 0, 0)
        btn:SetScript("OnClick", function() self:SwitchModule(tab.name) end)
        btn.moduleName = tab.name
        btn._order = i
    end
end

function NS.UI:CreateModulePanel(name)
    local f = self.mainFrame
    if not f then return end

    local panel = CreateFrame("Frame", "GuildUIPlusPanel_" .. name, f.content)
    panel:SetPoint("TOPLEFT", f.content, "TOPLEFT", 0, 0)
    panel:SetPoint("BOTTOMRIGHT", f.content, "BOTTOMRIGHT", 0, 0)
    panel:Hide()

    self.modulePanels[name] = panel
    return panel
end

function NS.UI:GetModulePanel(name)
    return self.modulePanels[name]
end

function NS.UI:SwitchModule(name)
    -- Hide current
    if self.activeModule and self.modulePanels[self.activeModule] then
        self.modulePanels[self.activeModule]:Hide()
    end

    -- Show new
    self.activeModule = name
    local panel = self.modulePanels[name]
    if panel then
        panel:Show()
    end

    -- Refresh rail button states
    local f = self.mainFrame
    if f then
        for _, child in ipairs({ f.rail:GetChildren() }) do
            if child.moduleName then
                if child.moduleName == name then
                    child:SetButtonState("PUSHED", true)
                else
                    child:SetButtonState("NORMAL")
                end
            end
        end
    end
end

function NS.UI:Toggle()
    local f = self.mainFrame
    if not f then return end
    if f:IsShown() then
        f:Hide()
    else
        f:Show()
        if not self.activeModule then
            self:SwitchModule("roster")
        end
    end
end

function NS.UI:Show()
    self:CreateMainFrame()
    self.mainFrame:Show()
end

function NS.UI:Hide()
    if self.mainFrame then
        self.mainFrame:Hide()
    end
end

-- Bootstrap: create main frame + slash commands on ON_READY
NS.Loader:On("ON_READY", function()
    NS.UI:CreateMainFrame()
    NS.UI:BuildRail()
    NS.UI:CreateModulePanel("roster")
    NS.UI:CreateModulePanel("forum")
    NS.UI:CreateModulePanel("schedule")
    NS.UI:CreateModulePanel("recruitment")
    NS.UI:CreateModulePanel("attendance")
    NS.UI:CreateModulePanel("banker")
    NS.UI:CreateModulePanel("ledger")
    NS.UI:CreateModulePanel("dashboard")
    NS.UI:CreateModulePanel("locator")
    NS.UI:CreateModulePanel("motd")
    NS.UI:CreateModulePanel("tutorial")
end)

-- Slash commands
SLASH_GUILDUIPLUS1 = "/gg"
SLASH_GUILDUIPLUS2 = "/guilduiplus"
SlashCmdList["GUILDUIPLUS"] = function(msg)
    msg = NS.Util.trim(msg or "")
    if msg == "" then
        NS.UI:Toggle()
    elseif msg == "help" then
        print("|cff00ff00[GUI+]|r Commands:")
        print("  /gg - Toggle main window")
        print("  /gg roster - Open roster")
        print("  /gg forum - Open forum")
        print("  /gg settings - Open settings")
        print("  /gg help - Show this help")
    else
        NS.UI:CreateMainFrame()
        NS.UI:Show()
        NS.UI:SwitchModule(msg)
    end
end
