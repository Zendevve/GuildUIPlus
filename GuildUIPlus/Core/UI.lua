-- GuildUI+ Main UI Framework
-- Frame pool, main frame, module rail, tab switching

local ADDON = ...
local NS = _G.GuildUIPlus

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

-- Creates a basic dialog frame with backdrop, title, and close button.
-- 3.3.5a doesn't have "ButtonFrameTemplate" (added in Cataclysm), so we
-- build a drop-in equivalent with the WoW-standard backdrop blizzard texture.
function NS.UI:CreateDialogFrame(name, title, parent)
    parent = parent or UIParent
    local f = CreateFrame("Frame", name, parent)
    f:SetSize(400, 300)
    f:SetPoint("CENTER")
    f:SetMovable(true)
    f:SetResizable(false)
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(self) self:StartMoving() end)
    f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    f:SetFrameStrata("DIALOG")

    -- Backdrop (4.0+ widget system uses BackdropTemplate; 3.3.5a doesn't have
    -- it either, so we use SetBackdrop() with explicit file/edge files)
    f:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 16, edgeSize = 32,
        insets = { left = 11, right = 11, top = 11, bottom = 11 },
    })
    f:SetBackdropColor(0, 0, 0, 0.8)

    -- Title bar background
    local titleBg = f:CreateTexture(nil, "BACKGROUND")
    titleBg:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header")
    titleBg:SetPoint("TOP", 0, 12)
    titleBg:SetSize(300, 64)

    -- Title text
    f.TitleText = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    f.TitleText:SetPoint("TOP", f, "TOP", 0, -3)
    f.TitleText:SetText(title or "GuildUI+")
    f.TitleText:SetTextColor(1, 0.82, 0)

    -- Close button (X) — top-right corner
    f.CloseButton = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    f.CloseButton:SetPoint("TOPRIGHT", f, "TOPRIGHT", -3, -3)
    f.CloseButton:SetSize(32, 32)
    f.CloseButton:SetScript("OnClick", function(self) self:GetParent():Hide() end)

    return f
end

function NS.UI:CreateMainFrame()
    if self.mainFrame then return self.mainFrame end

    local f = self:CreateDialogFrame("GuildUIPlusFrame", "GuildUI+", UIParent)
    f:SetSize(FRAME_WIDTH, FRAME_HEIGHT)
    tinsert(UISpecialFrames, "GuildUIPlusFrame")

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
    NS.UI._panelsBuilt = true
    -- Rebuild the rail after a short delay so module tabs registered
    -- by other ON_READY callbacks (e.g., Roster) are included.
    NS.Util.AfterTimer(0, function()
        NS.UI:BuildRail()
    end)
end)

-- Slash commands
SLASH_GUILDUIPLUS1 = "/gg"
SLASH_GUILDUIPLUS2 = "/guilduiplus"
SlashCmdList["GUILDUIPLUS"] = function(msg)
    -- Wrap in pcall so errors are visible instead of silently swallowed
    local ok, err = pcall(function()
        msg = NS.Util.trim(msg or "")
        if msg == "" then
            -- Ensure the main frame exists before toggling (ON_READY may not have fired yet)
            NS.UI:CreateMainFrame()
            NS.UI:Toggle()
        elseif msg == "help" then
            print("|cff00ff00[GUI+]|r Commands:")
            print("  /gg - Toggle main window")
            print("  /gg roster - Open roster")
            print("  /gg forum - Open forum")
            print("  /gg settings - Open settings")
            print("  /gg help - Show this help")
        else
            -- Ensure frame + panels exist, then switch to the requested module
            NS.UI:CreateMainFrame()
            if not NS.UI._panelsBuilt then
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
                NS.UI._panelsBuilt = true
            end
            NS.UI:Show()
            NS.UI:SwitchModule(msg)
        end
    end)
    if not ok then
        print(string.format("|cffff0000[GUI+]|r Slash command error: %s", tostring(err)))
    end
end
