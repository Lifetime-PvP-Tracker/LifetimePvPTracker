local UI = {}
LifetimePvPTrackerUI = UI

-- Colors
local GREEN    = "|cff33ff33"
local RED   = "|cffff3333"
local GRAY   = "|cffb0b0b0"
local WHITE  = "|cffffffff"
local TEAL   = "|cff00d1d1"
local RESET    = "|r"

local CLASS_COLORS = RAID_CLASS_COLORS

function SetTitleText()
    local name = UnitName("Player")
    local class = UnitClassBase("Player")
    local text = ClassColorText(name, class)
    return text
end

function SetSubtitleText()
    local guildName, guildRankName, guildRankIndex, realm = GetGuildInfo("Player")
    local text = "" .. TEAL .. guildRankName .. RESET .. " of " .. GRAY .. "<" .. GREEN .. tostring(guildName) .. GRAY .. ">"
    return text
end

function ClassColorText(text, classToken)
    text = tostring(text or "")
    local c = (classToken and CLASS_COLORS[classToken]) or { r = 1, g = 1, b = 1 }
    return string.format("|cff%02x%02x%02x%s|r", c.r * 255, c.g * 255, c.b * 255, text)
end

-- ========================
-- Main Frame
-- ========================
UI.frame = CreateFrame("Frame", "LifetimePvPTrackerFrame", UIParent, "BackdropTemplate")
UI.frame:SetSize(800, 460)
UI.frame:SetPoint("CENTER")
UI.frame:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    edgeSize = 32,
    insets = { left = 8, right = 8, top = 8, bottom = 8 }
})
UI.frame:SetMovable(true)
UI.frame:EnableMouse(true)
UI.frame:RegisterForDrag("LeftButton")
UI.frame:SetScript("OnDragStart", UI.frame.StartMoving)
UI.frame:SetScript("OnDragStop", UI.frame.StopMovingOrSizing)
UI.frame:Hide()

-- ========================
-- Title (moved down slightly)
-- ========================
UI.title = UI.frame:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
UI.title:SetPoint("TOP", 0, -13) -- was -8; moved down
UI.title:SetText(SetTitleText())

UI.subtitle = UI.frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
UI.subtitle:SetPoint("TOP", 0, -35) -- was -8; moved down
C_Timer.After(5, function()
    UI.subtitle:SetText(SetSubtitleText())
end)

-- Close button (top right)
UI.close = CreateFrame("Button", nil, UI.frame, "UIPanelCloseButton")
UI.close:SetPoint("TOPRIGHT", -5, -5)

-- ========================
-- Settings button (mimic close button, but cog icon)
-- ========================
-- UI.settingsBtn = CreateFrame("Button", nil, UI.frame, "UIPanelInfoButton")
-- UI.settingsBtn:SetPoint("TOPLEFT", 10, -10)

-- ========================
-- Dividers around nav (moved down a touch)
-- ========================
UI.navBottomLine = UI.frame:CreateTexture(nil, "BACKGROUND")
UI.navBottomLine:SetHeight(1)
UI.navBottomLine:SetPoint("TOPLEFT", 12, -76) -- moved down from -60
UI.navBottomLine:SetPoint("TOPRIGHT", -12, -76)
UI.navBottomLine:SetColorTexture(1, 1, 1, 0.12)

-- ========================
-- Tabs (centered) - moved down slightly
-- ========================
UI.tabs = {}
UI.activeTab = "Home"

-- local tabNames = { "Home", "Battlegrounds", "Arenas", "World PvP", "Duels", "Activity" }
local tabNames = { "Home", "Battlegrounds", "World PvP", "Duels"}

local TAB_W = 110
local TAB_H = 20
local TAB_GAP = 10
local totalWidth = (#tabNames * TAB_W) + ((#tabNames - 1) * TAB_GAP)
local startX = (UI.frame:GetWidth() - totalWidth) / 2

local function SetTabTextColor(tab, r, g, b)
    local fs = tab:GetFontString()
    if fs then fs:SetTextColor(r, g, b) end
end

function UI:UpdateTabHighlights()
    for name, tab in pairs(self.tabs) do
        if name == self.activeTab then
            tab:LockHighlight()
            tab:SetAlpha(1.0)
            SetTabTextColor(tab, 1, 0.82, 0)
        else
            tab:UnlockHighlight()
            tab:SetAlpha(0.85)
            SetTabTextColor(tab, 1, 1, 1)
        end
    end
end

for i, name in ipairs(tabNames) do
    local tab = CreateFrame("Button", nil, UI.frame, "UIPanelButtonTemplate")
    tab:SetSize(TAB_W, TAB_H)
    tab:SetPoint("TOPLEFT", startX + (i - 1) * (TAB_W + TAB_GAP), -52) -- was -42; moved down
    tab:SetText(name)

    if name == "Home" then
        tab.icon = tab:CreateTexture(nil, "OVERLAY")
        tab.icon:SetSize(14, 14)
        tab.icon:SetPoint("LEFT", 10, 0)
        tab.icon:SetTexture("Interface\\GroupFrame\\UI-Group-LeaderIcon")
        tab.icon:SetAlpha(0.95)

        local fs = tab:GetFontString()
        if fs then
            fs:ClearAllPoints()
            fs:SetPoint("CENTER", 6, 0)
        end
    end

    tab:SetScript("OnClick", function()
        UI.activeTab = name
        UI:Refresh()
    end)

    UI.tabs[name] = tab
end

-- ========================
-- Shared Scroll Area (moved down slightly to match nav spacing)
-- ========================
UI.scroll = CreateFrame("ScrollFrame", nil, UI.frame, "UIPanelScrollFrameTemplate")
UI.scroll:SetPoint("TOPLEFT", 16, -84) -- was -74; moved down
UI.scroll:SetPoint("BOTTOMRIGHT", -32, 16)

UI.content = CreateFrame("Frame", nil, UI.scroll)
UI.content:SetSize(1, 1)
UI.scroll:SetScrollChild(UI.content)

-- ========================
-- Settings window (sliders)
-- ========================
local function ApplyUISettings()
    if not LifetimePvPTrackerDB or not LifetimePvPTrackerDB.settings then return end
    local s = LifetimePvPTrackerDB.settings
    UI.frame:SetScale(s.uiScale or 1.0)
    UI.frame:SetAlpha(s.uiAlpha or 1.0)
end

local function EnsureSettingsFrame()
    if UI.settingsFrame then return end

    UI.settingsFrame = CreateFrame("Frame", "LifetimePvPTrackerSettingsFrame", UIParent, "BackdropTemplate")
    UI.settingsFrame:SetSize(340, 180)
    UI.settingsFrame:SetPoint("CENTER")
    UI.settingsFrame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        edgeSize = 32,
        insets = { left = 8, right = 8, top = 8, bottom = 8 }
    })
    UI.settingsFrame:Hide()

    UI.settingsFrame.title = UI.settingsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    UI.settingsFrame.title:SetPoint("TOP", 0, -12)
    UI.settingsFrame.title:SetText("Settings")

    UI.settingsFrame.close = CreateFrame("Button", nil, UI.settingsFrame, "UIPanelCloseButton")
    UI.settingsFrame.close:SetPoint("TOPRIGHT", -5, -5)

    -- Transparency slider
    UI.settingsFrame.alphaText = UI.settingsFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    UI.settingsFrame.alphaText:SetPoint("TOPLEFT", 18, -44)
    UI.settingsFrame.alphaText:SetText("UI Transparency")

    UI.settingsFrame.alpha = CreateFrame("Slider", nil, UI.settingsFrame, "OptionsSliderTemplate")
    UI.settingsFrame.alpha:SetPoint("TOPLEFT", 18, -64)
    UI.settingsFrame.alpha:SetWidth(300)
    UI.settingsFrame.alpha:SetMinMaxValues(0.3, 1.0)
    UI.settingsFrame.alpha:SetValueStep(0.05)
    UI.settingsFrame.alpha:SetObeyStepOnDrag(true)
    _G[UI.settingsFrame.alpha:GetName() .. "Low"]:SetText("30%")
    _G[UI.settingsFrame.alpha:GetName() .. "High"]:SetText("100%")
    _G[UI.settingsFrame.alpha:GetName() .. "Text"]:SetText("")

    -- Scale slider
    UI.settingsFrame.scaleText = UI.settingsFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    UI.settingsFrame.scaleText:SetPoint("TOPLEFT", 18, -100)
    UI.settingsFrame.scaleText:SetText("UI Scale")

    UI.settingsFrame.scale = CreateFrame("Slider", nil, UI.settingsFrame, "OptionsSliderTemplate")
    UI.settingsFrame.scale:SetPoint("TOPLEFT", 18, -120)
    UI.settingsFrame.scale:SetWidth(300)
    UI.settingsFrame.scale:SetMinMaxValues(0.8, 1.3)
    UI.settingsFrame.scale:SetValueStep(0.05)
    UI.settingsFrame.scale:SetObeyStepOnDrag(true)
    _G[UI.settingsFrame.scale:GetName() .. "Low"]:SetText("80%")
    _G[UI.settingsFrame.scale:GetName() .. "High"]:SetText("130%")
    _G[UI.settingsFrame.scale:GetName() .. "Text"]:SetText("")

    UI.settingsFrame.alpha:SetScript("OnValueChanged", function(self, value)
        value = tonumber(value) or 1
        LifetimePvPTrackerDB.settings.uiAlpha = value
        ApplyUISettings()
    end)

    UI.settingsFrame.scale:SetScript("OnValueChanged", function(self, value)
        value = tonumber(value) or 1
        LifetimePvPTrackerDB.settings.uiScale = value
        ApplyUISettings()
    end)

    table.insert(UISpecialFrames, "LifetimePvPTrackerSettingsFrame")
end

-- UI.settingsBtn:SetScript("OnClick", function()
--     EnsureSettingsFrame()
--     if UI.settingsFrame:IsShown() then
--         UI.settingsFrame:Hide()
--     else
--         UI.settingsFrame.alpha:SetValue(LifetimePvPTrackerDB.settings.uiAlpha or 1.0)
--         UI.settingsFrame.scale:SetValue(LifetimePvPTrackerDB.settings.uiScale or 1.0)
--         UI.settingsFrame:Show()
--     end
-- end)

-- ========================
-- Clear / Refresh
-- ========================
function UI:ClearAllTabRows()
    if self.bgRows then for _, r in ipairs(self.bgRows) do r:Hide() end end
    if self.worldRows then for _, r in ipairs(self.worldRows) do r:Hide() end end
    if self.duelRows then for _, r in ipairs(self.duelRows) do r:Hide() end end
    if self.statsRows then for _, r in ipairs(self.statsRows) do r:Hide() end end
    if self.oppButtons then for _, b in ipairs(self.oppButtons) do b:Hide() end end
    if self.arenaRows then for _, r in ipairs(self.arenaRows) do r:Hide() end end
    if self.activityRows then for _, r in ipairs(self.activityRows) do r:Hide() end end

    if self.bgLeftScroll then self.bgLeftScroll:Hide() end
    if self.bgRightPanel then self.bgRightPanel:Hide() end

    -- ✅ NEW: World PvP layout panels
    if self.worldLeftScroll then self.worldLeftScroll:Hide() end
    if self.worldRightPanel then self.worldRightPanel:Hide() end

    if self.homePanel then self.homePanel:Hide() end

    self.content:SetHeight(1)
end

function UI:Refresh()
    ApplyUISettings()
    self:ClearAllTabRows()
    self:UpdateTabHighlights()

    if self.activeTab == "Home" then
        if UI_RenderHome then UI_RenderHome() end
    elseif self.activeTab == "Battlegrounds" then
        if UI_RenderBattlegrounds then UI_RenderBattlegrounds() end
    elseif self.activeTab == "Arenas" then
        if UI_RenderArenas then UI_RenderArenas() end
    elseif self.activeTab == "World PvP" then
        if UI_RenderWorldPvP then UI_RenderWorldPvP() end
    elseif self.activeTab == "Duels" then
        if UI_RenderDuels then UI_RenderDuels() end
    elseif self.activeTab == "Activity" then
        if UI_RenderActivity then UI_RenderActivity() end
    end
end

function LifetimePvPTracker_ToggleUI()
    if UI.frame:IsShown() then
        UI.frame:Hide()
    else
        UI.activeTab = UI.activeTab or "Home"
        UI:Refresh()
        UI.frame:Show()
    end
end

table.insert(UISpecialFrames, "LifetimePvPTrackerFrame")

SLASH_LPVPT1 = "/lpvp"
SLASH_LPVPT2 = "/lifetimepvp"
SlashCmdList.LPVPT = function()
    LifetimePvPTracker_ToggleUI()
end
