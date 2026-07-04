-- GuildUI+ Tutorial Module
-- Interactive overlay tour, dismissable

local ADDON, NS = ...

local Tutorial = {
    name = "tutorial",
    label = "Help",
    _currentStep = 0,
    _completed = false,
    _frame = nil,
}

NS.Loader:Register("tutorial", Tutorial)

local STEPS = {
    {
        title = "Welcome to GuildUI+!",
        text = "This addon replaces the default guild frame with a powerful, modern guild management system.\n\nClick Next to learn the basics.",
    },
    {
        title = "Module Rail",
        text = "The left sidebar shows all available modules.\n\nClick any module name to switch views. Your layout and settings are saved automatically.",
    },
    {
        title = "Roster",
        text = "The roster shows all guild members with custom columns.\n\n• Click column headers to sort\n• Use the search box to filter\n• Click a member to see details",
    },
    {
        title = "Forum",
        text = "The forum lets guild members communicate asynchronously.\n\nCreate threads, post replies, create polls, and mark important posts as sticky.",
    },
    {
        title = "Schedule",
        text = "Schedule events for raids, dungeons, or guild activities.\n\nMembers can sign up for roles (tank/healer/dps) and get reminders.",
    },
    {
        title = "Attendance",
        text = "Attendance is tracked automatically when you change zones.\n\nOfficers can view absence reports and weekly digests.",
    },
    {
        title = "Settings",
        text = "Access settings via /gg settings\n\nYou can customize the UI scale, font size, colorblind mode, and module preferences.",
    },
    {
        title = "You're Ready!",
        text = "Type /gg to open GuildUI+ at any time.\n\nEnjoy managing your guild!",
    },
}

function Tutorial:Show()
    self._currentStep = 1
    self:_showFrame()
end

function Tutorial:Next()
    self._currentStep = self._currentStep + 1
    if self._currentStep > #STEPS then
        self:Complete()
        return
    end
    self:_updateFrame()
end

function Tutorial:Prev()
    if self._currentStep > 1 then
        self._currentStep = self._currentStep - 1
        self:_updateFrame()
    end
end

function Tutorial:Complete()
    self._completed = true
    NS.Settings:Set("tutorial", "completed", true)
    if self._frame then
        self._frame:Hide()
    end
end

function Tutorial:_showFrame()
    if not self._frame then
        self._frame = CreateFrame("Frame", "GuildUIPlusTutorial", UIParent, "ButtonFrameTemplate")
        self._frame:SetSize(400, 250)
        self._frame:SetPoint("CENTER")
        self._frame:SetMovable(true)
        self._frame:EnableMouse(true)
        self._frame:RegisterForDrag("LeftButton")
        self._frame:SetScript("OnDragStart", self._frame.StartMoving)
        self._frame:SetScript("OnDragStop", self._frame.StopMovingOrSizing)
        self._frame:SetClampedToScreen(true)
        self._frame:SetFrameStrata("DIALOG")
        tinsert(UISpecialFrames, "GuildUIPlusTutorial")

        self._frame.TitleText:SetText("Tutorial")
        self._frame.CloseButton:SetScript("OnClick", function() Tutorial._frame:Hide() end)

        -- Content
        self._frame.title = self._frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        self._frame.title:SetPoint("TOP", self._frame, "TOP", 0, -40)

        self._frame.text = self._frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        self._frame.text:SetPoint("TOPLEFT", self._frame, "TOPLEFT", 20, -70)
        self._frame.text:SetPoint("BOTTOMRIGHT", self._frame, "BOTTOMRIGHT", -20, 60)
        self._frame.text:SetJustifyH("LEFT")
        self._frame.text:SetJustifyV("TOP")

        -- Navigation buttons
        self._frame.prevBtn = CreateFrame("Button", nil, self._frame, "UIPanelButtonTemplate")
        self._frame.prevBtn:SetSize(80, 25)
        self._frame.prevBtn:SetPoint("BOTTOMLEFT", self._frame, "BOTTOMLEFT", 20, 20)
        self._frame.prevBtn:SetText("Prev")
        self._frame.prevBtn:SetScript("OnClick", function() Tutorial:Prev() end)

        self._frame.nextBtn = CreateFrame("Button", nil, self._frame, "UIPanelButtonTemplate")
        self._frame.nextBtn:SetSize(80, 25)
        self._frame.nextBtn:SetPoint("BOTTOMRIGHT", self._frame, "BOTTOMRIGHT", -20, 20)
        self._frame.nextBtn:SetText("Next")
        self._frame.nextBtn:SetScript("OnClick", function() Tutorial:Next() end)

        -- Step counter
        self._frame.stepText = self._frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        self._frame.stepText:SetPoint("BOTTOM", self._frame, "BOTTOM", 0, 25)
    end

    self._frame:Show()
    self:_updateFrame()
end

function Tutorial:_updateFrame()
    local step = STEPS[self._currentStep]
    if not step then return end

    self._frame.title:SetText(step.title)
    self._frame.text:SetText(step.text)
    self._frame.stepText:SetText(string.format("%d / %d", self._currentStep, #STEPS))
end

-- Auto-show on first login
NS.Loader:On("ON_READY", function()
    if not NS.Settings:Get("tutorial", "completed") then
        C_Timer.After(2, function() Tutorial:Show() end)
    end
end)
