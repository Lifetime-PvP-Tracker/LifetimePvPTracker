local UI = LifetimePvPTrackerUI
if not UI then return end

local TEAL  = "|cff00d1d1"
local GRAY  = "|cffb0b0b0"
local WHITE = "|cffffffff"
local WIN   = "|cff33ff33"
local LOSS  = "|cffff3333"
local RESET = "|r"

local DESERTER_ICON = "|TInterface\\Icons\\Ability_Druid_Cower:14:14:0:0|t"

local BG_RANK_BADGES = {
    [0] = {
        [1] = "|TInterface\\PvPRankBadges\\PvPRank01:14:14:0:0|t",
        [2] = "|TInterface\\PvPRankBadges\\PvPRank02:14:14:0:0|t",
        [3] = "|TInterface\\PvPRankBadges\\PvPRank03:14:14:0:0|t",
        [4] = "|TInterface\\PvPRankBadges\\PvPRank04:14:14:0:0|t",
        [5] = "|TInterface\\PvPRankBadges\\PvPRank05:14:14:0:0|t",
        [6] = "|TInterface\\PvPRankBadges\\PvPRank06:14:14:0:0|t",
        [7] = "|TInterface\\PvPRankBadges\\PvPRank07:14:14:0:0|t",
        [8] = "|TInterface\\PvPRankBadges\\PvPRank08:14:14:0:0|t",
        [9] = "|TInterface\\PvPRankBadges\\PvPRank09:14:14:0:0|t",
        [10] = "|TInterface\\PvPRankBadges\\PvPRank10:14:14:0:0|t",
        [11] = "|TInterface\\PvPRankBadges\\PvPRank11:14:14:0:0|t",
        [12] = "|TInterface\\PvPRankBadges\\PvPRank12:14:14:0:0|t",
        [13] = "|TInterface\\PvPRankBadges\\PvPRank13:14:14:0:0|t",
        [14] = "|TInterface\\PvPRankBadges\\PvPRank14:14:14:0:0|t",
    },
    [1] = {
        [1] = "|TInterface\\PvPRankBadges\\PvPRank01:14:14:0:0|t",
        [2] = "|TInterface\\PvPRankBadges\\PvPRank02:14:14:0:0|t",
        [3] = "|TInterface\\PvPRankBadges\\PvPRank03:14:14:0:0|t",
        [4] = "|TInterface\\PvPRankBadges\\PvPRank04:14:14:0:0|t",
        [5] = "|TInterface\\PvPRankBadges\\PvPRank05:14:14:0:0|t",
        [6] = "|TInterface\\PvPRankBadges\\PvPRank06:14:14:0:0|t",
        [7] = "|TInterface\\PvPRankBadges\\PvPRank07:14:14:0:0|t",
        [8] = "|TInterface\\PvPRankBadges\\PvPRank08:14:14:0:0|t",
        [9] = "|TInterface\\PvPRankBadges\\PvPRank09:14:14:0:0|t",
        [10] = "|TInterface\\PvPRankBadges\\PvPRank10:14:14:0:0|t",
        [11] = "|TInterface\\PvPRankBadges\\PvPRank11:14:14:0:0|t",
        [12] = "|TInterface\\PvPRankBadges\\PvPRank12:14:14:0:0|t",
        [13] = "|TInterface\\PvPRankBadges\\PvPRank13:14:14:0:0|t",
        [14] = "|TInterface\\PvPRankBadges\\PvPRank14:14:14:0:0|t",
    }
}

local function EscapePattern(s)
    return (s:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1"))
end

local function BuildDuelPattern(globalString)
    local s = globalString
    if not s or s == "" then return nil end
    s = EscapePattern(s)
    s = s:gsub("%%s", "(.+)")
    return "^" .. s .. "$"
end

local function BackdropFrame(parent)
    local f = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    f:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 }
    })
    f:SetBackdropColor(0, 0, 0, 0.15)
    return f
end

local function SetKV(panel, idx, leftText, rightText)
    if panel.linesL and panel.linesL[idx] then
        panel.linesL[idx]:SetText(leftText or "")
    end
    if panel.linesR and panel.linesR[idx] then
        panel.linesR[idx]:SetText(rightText or "")
    end
end

local function MakePanel(parent, titleText)
    local f = BackdropFrame(parent)

    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    f.title:SetPoint("TOPLEFT", 10, -8)
    f.title:SetText(TEAL .. titleText .. RESET)

    f.div = f:CreateTexture(nil, "BACKGROUND")
    f.div:SetHeight(1)
    f.div:SetPoint("TOPLEFT", f.title, "BOTTOMLEFT", 0, -6)
    f.div:SetPoint("TOPRIGHT", f, "TOPRIGHT", -10, -30)
    f.div:SetColorTexture(1, 1, 1, 0.10)

    f.linesL, f.linesR = {}, {}
    for i = 1, 9 do
        local y = -36 - (i - 1) * 14

        local fsL = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        fsL:SetPoint("TOPLEFT", 10, y)
        fsL:SetJustifyH("LEFT")
        fsL:SetText("")
        f.linesL[i] = fsL

        local fsR = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        fsR:SetPoint("TOPRIGHT", -10, y)
        fsR:SetJustifyH("RIGHT")
        fsR:SetText("")
        f.linesR[i] = fsR
    end

    return f
end

local function SetLine(panel, idx, text)
    if panel.lines and panel.lines[idx] then panel.lines[idx]:SetText(text or "") end
end

local function MyFactionToken()
    return (UnitFactionGroup("player") == "Alliance") and 1 or 0
end

local function GetProfile()
    return LifetimePvPTracker_GetProfile()
end

local function GetRankIcon(faction, id)
    return BG_RANK_BADGES[faction][id]
end

local function IsWinBG(bg)
    if bg.winner == nil then return false end
    if type(bg.winner) == "number" then
        return bg.winner == MyFactionToken()
    elseif type(bg.winner) == "string" then
        return bg.winner == UnitFactionGroup("player")
    end
    return false
end

local function pct(w, l)
    local d = w + l
    return (d > 0) and math.floor((w / d) * 100 + 0.5) or 0
end

local function AggregateAll(profile)
    local me = UnitName("player") or ""
    local totalKills, totalDeaths, totalHonor = 0, 0, 0

    -- BG: scoreboard row
    for _, bg in ipairs(profile.battlegrounds or {}) do
        if bg.players then
            for _, p in ipairs(bg.players) do
                if p.name and string.sub(p.name, 1, #me) == me then
                    totalKills = totalKills + (tonumber(p.killingBlows) or 0)
                    totalDeaths = totalDeaths + (tonumber(p.deaths) or 0)
                    totalHonor = totalHonor + (tonumber(p.honor) or 0)
                    break
                end
            end
        end
    end

    -- WorldPvP
    for _, e in ipairs(profile.worldPvP or {}) do
        if e.result == "you_killed" then
            totalKills = totalKills + 1
            totalHonor = totalHonor + (tonumber(e.honor) or 0)
        elseif e.result == "killed_you" then
            totalDeaths = totalDeaths + 1
        end
    end

    return totalKills, totalDeaths, totalHonor
end

local function WL_BG(profile)
    local w, l, a = 0, 0, 0
    local byBG = {}
    for _, bg in ipairs(profile.battlegrounds or {}) do
        local z = bg.zone or "Unknown"
        byBG[z] = byBG[z] or { w = 0, l = 0, a = 0 }
        if bg.abandoned then
            a = a + 1; l = l + 1
            byBG[z].a = byBG[z].a + 1
            byBG[z].l = byBG[z].l + 1
        else
            if IsWinBG(bg) then w = w + 1; byBG[z].w = byBG[z].w + 1
            else l = l + 1; byBG[z].l = byBG[z].l + 1 end
        end
    end
    return w, l, a, #profile.battlegrounds, byBG
end

local function BestWorstBG(byBG, minGames)
    minGames = minGames or 3
    local bestZ, bestP, bestN = nil, -1, 0
    local worstZ, worstP, worstN = nil, 101, 0

    for z, s in pairs(byBG or {}) do
        local d = s.w + s.l
        if d >= minGames then
            local p = math.floor((s.w / d) * 100 + 0.5)
            if p > bestP or (p == bestP and d > bestN) then
                bestP, bestZ, bestN = p, z, d
            end
            if p < worstP or (p == worstP and d > worstN) then
                worstP, worstZ, worstN = p, z, d
            end
        end
    end

    return bestZ, bestP, bestN, worstZ, worstP, worstN
end

local function WL_Arena(profile)
    local w, l = 0, 0
    local bestRating = 0
    local bestBracket = "-"
    for _, a in ipairs(profile.arenas or {}) do
        local res = a.result
        if res == "win" or a.win == true then w = w + 1
        elseif res == "loss" or a.win == false then l = l + 1 end

        local r = tonumber(a.ratingAfter) or tonumber(a.highestRating) or 0
        if r > bestRating then
            bestRating = r
            bestBracket = a.bracket or "-"
        end
    end
    return w, l, pct(w, l), bestRating, bestBracket
end

local function WL_Duels(profile)
    local me = UnitName("player") or ""
    local w, l = 0, 0
    local rec = {} -- opp -> {w,l}
    for a, d in ipairs(profile.duels or {}) do
        local opp
    
        DBG("Winner: %s", d.winner)
        if d.winner and string.sub(d.winner, 1, #me) == me then
            w = w + 1
            opp = d.loser
            if opp then
                rec[opp] = rec[opp] or { w = 0, l = 0 }
                rec[opp].w = rec[opp].w + 1
            end
        else
            l = l + 1
            opp = d.winner
            if opp then
                rec[opp] = rec[opp] or { w = 0, l = 0 }
                rec[opp].l = rec[opp].l + 1
            end
        end
    end

    -- Rival: most wins by you vs them
    local rival, rivalW, rivalL = nil, -1, 0
    -- Nemesis: most losses to them
    local nem, nemL, nemW = nil, -1, 0

    for opp, s in pairs(rec) do
        if s.w > rivalW then rival, rivalW, rivalL = opp, s.w, s.l end
        if s.l > nemL then nem, nemL, nemW = opp, s.l, s.w end
    end

    -- DBG("LOG: %d %d %d %s %d %d %d %s %d %d", w, l, pct(w, l), nem, nemW, nemL, rival, rivalW, rivalL)

    return w, l, pct(w, l), nem, nemW, nemL, rival, rivalW, rivalL
end

local function DailyWorldPvP(profile, dayOffset)
    -- dayOffset = 0 today, 1 yesterday
    local target = date("%Y-%m-%d", time() - (dayOffset * 86400))
    local k, d, h = 0, 0, 0
    for _, e in ipairs(profile.worldPvP or {}) do
        local day = date("%Y-%m-%d", e.time or time())
        if day == target then
            if e.result == "you_killed" then k = k + 1; h = h + (tonumber(e.honor) or 0)
            elseif e.result == "killed_you" then d = d + 1 end
        end
    end
    return k, d, h
end

function UI_RenderHome()
    if UI.scroll then UI.scroll:Hide() end

    local PAD = 10

    if not UI.homePanel then
        UI.homePanel = CreateFrame("Frame", nil, UI.frame)
        UI.homePanel:SetPoint("TOPLEFT", 16, -82)
        UI.homePanel:SetPoint("BOTTOMRIGHT", -16, 16)

        -- 6 panels
        UI.homeOverall = MakePanel(UI.homePanel, "Overall")
        UI.homeBG = MakePanel(UI.homePanel, "Battlegrounds")
        UI.homeArena = MakePanel(UI.homePanel, "Arenas")
        UI.homeWorld = MakePanel(UI.homePanel, "World PvP")
        UI.homeDuels = MakePanel(UI.homePanel, "Duels")
        UI.homeSearch = MakePanel(UI.homePanel, "Search Players")

        -- Grid divider lines (these ensure Duels/Search get same divider feel)
        UI.homeVLine = UI.homePanel:CreateTexture(nil, "BACKGROUND")
        UI.homeVLine:SetWidth(1)
        UI.homeVLine:SetPoint("TOP", UI.homePanel, "TOP", 0, 0)
        UI.homeVLine:SetPoint("BOTTOM", UI.homePanel, "BOTTOM", 0, 0)
        UI.homeVLine:SetColorTexture(1, 1, 1, 0.10)

        UI.homeHLine1 = UI.homePanel:CreateTexture(nil, "BACKGROUND")
        UI.homeHLine1:SetHeight(1)
        UI.homeHLine1:SetPoint("TOPLEFT", UI.homePanel, "TOPLEFT", 0, 0)
        UI.homeHLine1:SetPoint("TOPRIGHT", UI.homePanel, "TOPRIGHT", 0, 0)
        UI.homeHLine1:SetColorTexture(1, 1, 1, 0.10)

        UI.homeHLine2 = UI.homePanel:CreateTexture(nil, "BACKGROUND")
        UI.homeHLine2:SetHeight(1)
        UI.homeHLine2:SetPoint("LEFT", UI.homePanel, "LEFT", 0, 0)
        UI.homeHLine2:SetPoint("RIGHT", UI.homePanel, "RIGHT", 0, 0)
        UI.homeHLine2:SetColorTexture(1, 1, 1, 0.10)
    end

    UI.homePanel:Show()

    local H = UI.homePanel:GetHeight()
    local rowH = H / 3

    -- Place panels (2 columns x 3 rows)
    local function place(panel, col, row)
        panel:ClearAllPoints()

        local leftAnchor = (col == 1) and "TOPLEFT" or "TOP"
        local rightAnchor = (col == 1) and "TOP" or "TOPRIGHT"
        local xL = (col == 1) and 0 or (PAD/2)
        local xR = (col == 1) and (-PAD/2) or 0

        local topY = -((row - 1) * rowH) - ((row > 1) and (PAD/2) or 0)
        local botY = -(row * rowH) + (PAD/2)
        if row == 3 then botY = 0 end

        panel:SetPoint("TOPLEFT", UI.homePanel, leftAnchor, xL, topY)
        panel:SetPoint("TOPRIGHT", UI.homePanel, rightAnchor, xR, topY)

        if row < 3 then
            panel:SetPoint("BOTTOMLEFT", UI.homePanel, leftAnchor, xL, botY)
            panel:SetPoint("BOTTOMRIGHT", UI.homePanel, rightAnchor, xR, botY)
        else
            panel:SetPoint("BOTTOMLEFT", UI.homePanel, (col == 1) and "BOTTOMLEFT" or "BOTTOM", xL, 0)
            panel:SetPoint("BOTTOMRIGHT", UI.homePanel, (col == 1) and "BOTTOM" or "BOTTOMRIGHT", xR, 0)
        end
    end

    place(UI.homeOverall, 1, 1)
    place(UI.homeBG, 2, 1)
    place(UI.homeArena, 1, 2)
    place(UI.homeWorld, 2, 2)
    place(UI.homeDuels, 1, 3)
    place(UI.homeSearch, 2, 3)

    -- Position grid divider lines
    UI.homeVLine:SetPoint("TOP", UI.homePanel, "TOP", 0, 0)
    UI.homeVLine:SetPoint("BOTTOM", UI.homePanel, "BOTTOM", 0, 0)

    UI.homeHLine1:SetPoint("TOP", UI.homePanel, "TOP", 0, -rowH)
    UI.homeHLine1:SetPoint("LEFT", UI.homePanel, "LEFT", 0, 0)
    UI.homeHLine1:SetPoint("RIGHT", UI.homePanel, "RIGHT", 0, 0)

    UI.homeHLine2:SetPoint("TOP", UI.homePanel, "TOP", 0, -(2 * rowH))
    UI.homeHLine2:SetPoint("LEFT", UI.homePanel, "LEFT", 0, 0)
    UI.homeHLine2:SetPoint("RIGHT", UI.homePanel, "RIGHT", 0, 0)

    local profile = GetProfile()

    local faction = MyFactionToken()
    local totalKills, totalDeaths, totalHonor = AggregateAll(profile)
    local honorableKills, dishonorableKills, highestRank = GetPVPLifetimeStats()
    local currentHonor = C_CurrencyInfo.GetCurrencyInfo(1901).quantity
    local currentArenaPoints = C_CurrencyInfo.GetCurrencyInfo(1900).quantity
    local rankName, rankNumber = GetPVPRankInfo(highestRank)
    if not rankName then
        rankName = 'N/A'
    end
    local rankIcon = ''
    if rankName ~= 'N/A' then
        rankIcon = GetRankIcon(faction, rankNumber)
    end
    local bgW, bgL, bgAb, bgCount, byBG = WL_BG(profile)
    local bgPct = pct(bgW, bgL)
    local bestZ, bestP, bestN, worstZ, worstP, worstN = BestWorstBG(byBG, 3)

    local aW, aL, aPct, bestRating, bestBracket = WL_Arena(profile)
    local dW, dL, dPct, nem, nemW, nemL, riv, rivW, rivL = WL_Duels(profile)

    -- Overall grid (requested)
    SetKV(UI.homeOverall, 1, 
        WHITE .. "Highest BG Rank:" .. RESET,
        rankIcon .. " " .. RESET .. rankName .. RESET  
    )
    SetKV(UI.homeOverall, 2, 
        WHITE .. "Lifetime Honorable Kills:" .. RESET,
        honorableKills .. RESET  
    )
    SetKV(UI.homeOverall, 3, 
        WHITE .. "Lifetime Dishonorable Kills:" .. RESET,
        dishonorableKills .. RESET  
    )
    SetKV(UI.homeOverall, 4, 
        WHITE .. "Current Honor:" .. RESET,
        currentHonor
    )
    SetKV(UI.homeOverall, 5, 
        WHITE .. "Current Arena Points:" .. RESET,
        currentArenaPoints
    )

    -- Battlegrounds grid (requested)
    SetKV(UI.homeBG, 1, 
        WHITE .. "W/L:" .. RESET,
        WIN .. bgW .. RESET .. GRAY .. "/" .. RESET .. LOSS .. bgL .. RESET
    )
    SetKV(UI.homeBG, 2, 
        WHITE .. "Win %:" .. RESET,
        ((bgPct >= 50) and WIN or LOSS) .. bgPct .. "%" .. RESET
    )
    SetKV(UI.homeBG, 3, 
        WHITE .. "Matches:" .. RESET,
        bgCount .. GRAY .. " | " .. RESET .. DESERTER_ICON .. " " .. bgAb
    )

    local bestText = bestZ and (bestZ .. " (" .. bestP .. "%, " .. bestN .. ")") or "- (need 3+)"
    local worstText = worstZ and (worstZ .. " (" .. worstP .. "%, " .. worstN .. ")") or "- (need 3+)"

    SetKV(UI.homeBG, 4, 
        WHITE .. "Best BG:" .. RESET,
        bestText
    )
    SetKV(UI.homeBG, 5, 
        WHITE .. "Worst BG:" .. RESET,
        worstText
    )

    -- Arenas grid (requested)
    SetKV(UI.homeArena, 1, 
        GRAY .. "Future feature..." .. RESET
    )
    -- SetKV(UI.homeArena, 1, 
    --     WHITE .. "W/L:" .. RESET,
    --     WIN .. aW .. RESET .. GRAY .. "/" .. RESET .. LOSS .. aL .. RESET
    -- )
    -- SetKV(UI.homeArena, 2, 
    --     WHITE .. "Win %:" .. RESET,
    --     ((aPct >= 50) and WIN or LOSS) .. aPct .. "%" .. RESET
    -- )
    -- SetKV(UI.homeArena, 3, 
    --     WHITE .. "Highest Rating:" .. RESET,
    --     bestRating .. GRAY .. " (" .. bestBracket .. ")" .. RESET
    -- )

    -- World PvP grid (daily stats only)
    local tK, tD, tH = DailyWorldPvP(profile, 0)
    local yK, yD, yH = DailyWorldPvP(profile, 1)
    SetKV(UI.homeWorld, 1, 
        WHITE .. "[Today] Kills/Deaths/Honor:" .. RESET,
        tK .. GRAY .. "/" .. RESET .. tD .. GRAY .. " (" .. RESET .. tH .. GRAY .. ")" .. RESET
    )
    SetKV(UI.homeWorld, 2, 
        WHITE .. "[Yesterday] Kills/Deaths/Honor:" .. RESET,
        yK .. GRAY .. "/" .. RESET .. yD .. GRAY .. " (" .. RESET .. yH .. GRAY .. ")" .. RESET
    )

    -- Duels grid (Nemesis/Rival)
    SetKV(UI.homeDuels, 1, 
        WHITE .. "W/L:" .. RESET,
        WIN .. dW .. RESET .. GRAY .. "/" .. RESET .. LOSS .. dL .. RESET
    )
    SetKV(UI.homeDuels, 2, 
        WHITE .. "Win %:" .. RESET,
        ((dPct >= 50) and WIN or LOSS) .. dPct .. "%" .. RESET
    )

    if nem then
        SetKV(UI.homeDuels, 3, 
            WHITE .. "Nemesis:" .. nem .. RESET,
            nem .. GRAY .. " (" .. nemW .. "-" .. nemL .. ")" .. RESET)

    else
        SetKV(UI.homeDuels, 3, 
            WHITE .. "Nemesis:",
            " -"
        )
    end

    if riv then
        SetKV(UI.homeDuels, 4, 
            WHITE .. "Rival:" .. riv .. RESET,
            riv .. GRAY .. " (" .. rivW .. "-" .. rivL .. ")" .. RESET
        )
    else
        SetKV(UI.homeDuels, 4, 
            WHITE .. "Rival:" .. RESET,
            " -"
        )
    end

    -- Search placeholder
    SetKV(UI.homeSearch, 1, 
        GRAY .. "Future feature..." .. RESET
    )
end
