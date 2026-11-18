-- GearRack: the Trinkets window (K19). Per slot, the trinkets in priority order
-- with the stop line, Up, Down and Remove, and the slot's queue switch; per
-- trinket High priority, Pause the queue while worn, and a swap delay.
local _, GR = ...
local db = GearRackDB

local FLAT = "Interface\\Buttons\\WHITE8X8"
local ROW, VISIBLE, WIDTH = 22, 12, 280
local STOP = "Interface\\Buttons\\UI-GroupLoot-Pass-Up"

local window = CreateFrame("Frame", "GearRackTrinkets", UIParent)
window:SetSize(WIDTH, 470)
window:SetPoint("CENTER", UIParent, "CENTER", 320, 40) -- until moved
window:SetFrameStrata("HIGH")
window:SetMovable(true)
window:SetClampedToScreen(true)
window:EnableMouse(true)
window:SetBackdrop({ bgFile = FLAT, edgeFile = FLAT, edgeSize = 1 })
window:SetBackdropColor(0.06, 0.06, 0.06, 0.94)
window:SetBackdropBorderColor(0, 0, 0)
window:Hide()
UISpecialFrames[#UISpecialFrames + 1] = "GearRackTrinkets"
GR.TitleBar(window, "Trinkets")

local slot, picked, offset = 13, nil, 0 -- the slot shown, the picked row's index, the scroll
local Draw

local function Button(text, x, y, w, onClick)
    local b = CreateFrame("Button", nil, window, "UIPanelButtonTemplate")
    b:SetSize(w, 22)
    b:SetPoint("TOPLEFT", window, "TOPLEFT", x, y)
    b:SetText(text)
    b:SetScript("OnClick", onClick)
    return b
end
local function Check(text, x, y, onClick, tip)
    local c = CreateFrame("CheckButton", nil, window, "UICheckButtonTemplate")
    c:SetSize(24, 24)
    c:SetPoint("TOPLEFT", window, "TOPLEFT", x, y)
    c.label = c:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    c.label:SetPoint("LEFT", c, "RIGHT", 2, 0)
    c.label:SetText(text)
    c:SetScript("OnClick", onClick)
    c:SetScript("OnEnter", function()
        GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
        GameTooltip:SetText(text)
        GameTooltip:AddLine(tip, 1, 1, 1, 1)
        GameTooltip:Show()
    end)
    c:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return c
end

local upper = Button("Upper", 10, -30, 84, function() GR.OpenTrinkets(13) end)
local lower = Button("Lower", 98, -30, 84, function() GR.OpenTrinkets(14) end)
local auto = Check("Swap automatically", 8, -56, function() GR.QueueSwitch(slot, this:GetChecked()) end,
    "Wear the first ready trinket above the stop line. Choosing a trinket or a set by hand turns it off; "
    .. "Alt-click the trinket on the trinket bar to turn it on again.")

local list = function() return db.queue[slot].list end
local function Stats(make)
    local id = picked and list()[picked]
    if not id or id == 0 then return end
    if make then db.trinkets[id] = db.trinkets[id] or {} end
    return db.trinkets[id], id
end
-- A trinket's settings table goes when nothing is left in it.
local function Tidy()
    local stats, id = Stats()
    if stats and not next(stats) then db.trinkets[id] = nil end
end

-- The rows: icon, name (grey when not carried), and the trinket's marks.
local rows = {}
for i = 1, VISIBLE do
    local r = CreateFrame("Button", nil, window)
    r:SetSize(WIDTH - 16, ROW - 2)
    r:SetPoint("TOPLEFT", window, "TOPLEFT", 8, -84 - (i - 1) * ROW)
    r.icon = r:CreateTexture(nil, "ARTWORK")
    r.icon:SetSize(ROW - 2, ROW - 2)
    r.icon:SetPoint("LEFT", r, "LEFT", 0, 0)
    r.text = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    r.text:SetPoint("LEFT", r.icon, "RIGHT", 6, 0)
    r.marks = r:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    r.marks:SetPoint("RIGHT", r, "RIGHT", -4, 0)
    r.mark = r:CreateTexture(nil, "BACKGROUND")
    r.mark:SetAllPoints(r)
    r.mark:SetTexture(FLAT)
    r.mark:SetVertexColor(1, 0.82, 0, 0.2)
    r:SetScript("OnClick", function()
        picked = picked ~= this.index and this.index or nil
        Draw()
    end)
    r:SetScript("OnEnter", function()
        if this.id == 0 then return end
        GameTooltip:SetOwner(this, "ANCHOR_LEFT")
        GameTooltip:SetHyperlink("item:" .. this.id)
        GameTooltip:Show()
    end)
    r:SetScript("OnLeave", function() GameTooltip:Hide() end)
    rows[i] = r
end
window:EnableMouseWheel(true)
window:SetScript("OnMouseWheel", function()
    offset = math.max(0, math.min(offset - arg1, #list() - VISIBLE))
    Draw()
end)

-- Up and Down swap two neighbours; Remove shifts the rest up (KP-65: no table.remove).
local function Move(by)
    local l, to = list(), picked and picked + by
    if not to or to < 1 or to > #l then return end
    l[picked], l[to] = l[to], l[picked]
    picked = to
    if picked <= offset then offset = picked - 1 elseif picked > offset + VISIBLE then offset = picked - VISIBLE end
    GR.QueueAsk()
    Draw()
end
local y = -84 - VISIBLE * ROW - 6
local up = Button("Up", 10, y, 80, function() Move(-1) end)
local down = Button("Down", 98, y, 80, function() Move(1) end)
local remove = Button("Remove", 186, y, 84, function()
    local l = list()
    if not picked or l[picked] == 0 then return end
    for j = picked, #l do l[j] = l[j + 1] end
    picked = nil
    Draw()
end)

local priority = Check("High priority", 8, y - 28, function()
    Stats(true).priority = this:GetChecked() and true or nil
    Tidy(); GR.QueueAsk(); Draw()
end, "Put it on even when the worn trinket is ready to use.")
local pause = Check("Pause the queue while worn", 8, y - 50, function()
    Stats(true).pause = this:GetChecked() and true or nil
    Tidy(); GR.QueueAsk(); Draw()
end, "While this trinket is worn, nothing replaces it (a mount trinket, say).")

local delayLabel = window:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
delayLabel:SetPoint("TOPLEFT", window, "TOPLEFT", 14, y - 82)
delayLabel:SetText("Swap delay")
local delay = CreateFrame("EditBox", nil, window, "InputBoxTemplate")
delay:SetSize(36, 20)
delay:SetPoint("LEFT", delayLabel, "RIGHT", 10, 0)
delay:SetAutoFocus(false)
delay:SetNumeric(true)
delay:SetMaxLetters(3)
local delayHint = window:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
delayHint:SetPoint("LEFT", delay, "RIGHT", 6, 0)
delayHint:SetText("seconds kept on after a use")
local function SetDelay()
    this:ClearFocus()
    local stats = Stats(true)
    if not stats then return end
    local n = tonumber(this:GetText() or "")
    stats.delay = n and n > 0 and n or nil
    Tidy(); GR.QueueAsk(); Draw()
end
delay:SetScript("OnEnterPressed", SetDelay)
delay:SetScript("OnEditFocusLost", SetDelay)
delay:SetScript("OnEscapePressed", function() this:ClearFocus() end)

local function Marks(stats)
    if not stats then return "" end
    local out = {}
    if stats.priority then out[#out + 1] = "High" end
    if stats.pause then out[#out + 1] = "Pause" end
    if stats.delay then out[#out + 1] = stats.delay .. " s" end
    return table.concat(out, ", ")
end

Draw = function()
    local l = list()
    if picked and not l[picked] then picked = nil end
    offset = math.max(0, math.min(offset, #l - VISIBLE))
    for i, r in ipairs(rows) do
        local index = offset + i
        local id = l[index]
        r.index, r.id = index, id
        if id == 0 then
            r.icon:SetTexture(STOP)
            r.text:SetText("Stop here: nothing below goes on by itself")
            r.text:SetTextColor(1, 0.82, 0)
            r.marks:SetText("")
        elseif id then
            r.icon:SetTexture(C_Item.GetItemIconByID(id))
            r.text:SetText(C_Item.GetItemNameByID(id) or ("item " .. id))
            if C_Item.GetItemCount(id) > 0 then r.text:SetTextColor(1, 1, 1) else r.text:SetTextColor(0.5, 0.5, 0.5) end
            r.marks:SetText(Marks(db.trinkets[id]))
        end
        if index == picked then r.mark:Show() else r.mark:Hide() end
        if id then r:Show() else r:Hide() end
    end
    if slot == 13 then upper:Disable(); lower:Enable() else upper:Enable(); lower:Disable() end
    auto:SetChecked(db.queue[slot].on)
    local stats, id = Stats()
    local trinket = id ~= nil
    for _, b in ipairs({ up, down }) do if picked then b:Enable() else b:Disable() end end
    for _, c in ipairs({ remove, priority, pause }) do if trinket then c:Enable() else c:Disable() end end
    priority:SetChecked(stats and stats.priority)
    pause:SetChecked(stats and stats.pause)
    delay:SetText(stats and stats.delay and tostring(stats.delay) or "")
    if trinket then delay:Show(); delayLabel:Show(); delayHint:Show() else delay:Hide(); delayLabel:Hide(); delayHint:Hide() end
end
GR.TrinketsChanged = function() if window:IsShown() then Draw() end end

-- New trinkets join the list while it shows (BAG_UPDATE_DELAYED).
window:SetScript("OnEvent", function() GR.QueueFill(slot); Draw() end)
window:SetScript("OnShow", function() this:RegisterEvent("BAG_UPDATE_DELAYED") end)
window:SetScript("OnHide", function() this:UnregisterAllEvents() end)

function GR.OpenTrinkets(s)
    if s ~= slot then slot, picked, offset = s, nil, 0 end
    GR.QueueFill(slot)
    window:Show()
    Draw()
end
function GR.ToggleTrinkets(s)
    if window:IsShown() and s == slot then window:Hide() else GR.OpenTrinkets(s) end
end
