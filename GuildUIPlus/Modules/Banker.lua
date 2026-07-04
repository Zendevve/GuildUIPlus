-- GuildUI+ Banker Module
-- Tab filters (class/quality/subtype), Auctioneer value-floor, multi-pass

local ADDON, NS = ...

local Banker = {
    name = "banker",
    label = "Bank",
    _tabRules = {},  -- [tabIdx] = { quality, subtype, class, minValue }
}

NS.Loader:Register("banker", Banker)

function Banker:SetTabRule(tabIdx, rule)
    self._tabRules[tabIdx] = rule
end

function Banker:GetTabRule(tabIdx)
    return self._tabRules[tabIdx]
end

function Banker:ClearTabRule(tabIdx)
    self._tabRules[tabIdx] = nil
end

function Banker:GetAllRules()
    return self._tabRules
end

function Banker:SortBank(tabIdx)
    local rule = self._tabRules[tabIdx]
    if not rule then return end

    -- Get bank tab info (requires guild bank open)
    local numTabs = GetNumGuildBankTabs()
    if tabIdx > numTabs then return end

    -- Multi-pass: first pass moves matching items, second pass fills gaps
    for pass = 1, 2 do
        for bag = tabIdx, tabIdx do
            local numSlots = GetNumGuildBankSlots(bag)
            for slot = 1, numSlots do
                local link = GetGuildBankItemLink(bag, slot)
                if link then
                    local itemName, _, itemQuality, itemLevel, _, itemType, itemSubType = GetItemInfo(link)
                    if itemName then
                        local matches = self:_matchesRule(rule, itemQuality, itemType, itemSubType, link)
                        if pass == 1 and matches then
                            -- Item matches this tab, keep it here
                        elseif pass == 2 and not matches then
                            -- Move unmatched item to a tab without rules
                            self:_moveToFreeTab(bag, slot)
                        end
                    end
                end
            end
        end
    end
end

function Banker:_matchesRule(rule, quality, itemType, itemSubType, link)
    -- Quality filter
    if rule.quality and rule.quality > 0 and quality ~= rule.quality then
        return false
    end

    -- Subtype filter
    if rule.subtype and rule.subtype ~= "" and itemSubType ~= rule.subtype then
        return false
    end

    -- Class filter (item type)
    if rule.class and rule.class ~= "" and itemType ~= rule.class then
        return false
    end

    -- Minimum value (Auctioneer integration)
    if rule.minValue and rule.minValue > 0 then
        local price = self:GetItemAuctionValue(link)
        if price < rule.minValue then
            return false
        end
    end

    return true
end

function Banker:GetItemAuctionValue(link)
    -- Attempt Auctioneer integration if available
    if Auctioneer and Auctioneer.GetAuctionValue then
        return Auctioneer.GetAuctionValue(link) or 0
    end
    return 0
end

function Banker:_moveToFreeTab(fromBag, fromSlot)
    -- Find a tab with no rules configured
    local numTabs = GetNumGuildBankTabs()
    for tab = 1, numTabs do
        if not self._tabRules[tab] then
            -- Move item to this tab
            PickupGuildBankItem(fromBag, fromSlot)
            for slot = 1, GetNumGuildBankSlots(tab) do
                if not GetGuildBankItemLink(tab, slot) then
                    PlaceGuildBankItem(tab, slot)
                    return
                end
            end
        end
    end
end

function Banker:AutoSortAll()
    local numTabs = GetNumGuildBankTabs()
    for tab = 1, numTabs do
        if self._tabRules[tab] then
            self:SortBank(tab)
        end
    end
end
