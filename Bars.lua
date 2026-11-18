-- GearRack: the gear bar and the trinket bar (K4-K6, K10). Their buttons are
-- the stock action button's parts (FrameXML ActionButtonTemplate.xml) with a
-- native Cooldown that counts down, as on ActionBars' bars.
local _, GR = ...
local db = GearRackDB

local SIZE, STEP = 36, 40
local FLAT = "Interface\\Buttons\\WHITE8X8"
local SETS_ICON = "Interface\\Icons\\INV_Misc_Gear_01" -- UNVERIFIED: the icon's name in the 1.12 files
local hidden = CreateFrame("Frame")
hidden:Hide()

-- The countdown look of the action bars (### C_StringUtil.CreateNumericRuleFormatter).
local Up = Enum.NumericRuleFormatRounding.Up
GR.Countdown = C_StringUtil.CreateNumericRuleFormatter()
GR.Countdown:SetBreakpoints({
    { threshold = 0, step = 0.1, rounding = Up, format = "|cffff4444%.1f|r" },
    { threshold = 5, step = 1, rounding = Up, format = "|cffffff33%d|r" },
    { threshold = 10, step = 1, rounding = Up, format = "|cffffffff%d|r" },
    { threshold = 60, format = "|cffffffff%dm|r", components = { { div = 60, step = 1, rounding = Up } } },
    { threshold = 3600, format = "|cffffffff%dh|r", components = { { div = 3600, step = 1, rounding = Up } } },
})

-- The slots' own names (GetInventorySlotInfo), by slot number.
GR.SLOT_NAMES = { "HeadSlot", "NeckSlot", "ShoulderSlot", "ShirtSlot", "ChestSlot", "WaistSlot", "LegsSlot",
    "FeetSlot", "WristSlot", "HandsSlot", "Finger0Slot", "Finger1Slot", "Trinket0Slot", "Trinket1Slot",
    "BackSlot", "MainHandSlot", "SecondaryHandSlot", "RangedSlot", "TabardSlot" }
local empty = {}
for slot, name in ipairs(GR.SLOT_NAMES) do
    local _, texture = GetInventorySlotInfo(name)
    empty[slot] = texture
end

-- A 1 px edge: a frame round the button that draws only its border.
function GR.Edge(b)
    local edge = CreateFrame("Frame", nil, b)
    edge:SetPoint("TOPLEFT", b, "TOPLEFT", -1, 1)
    edge:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 1, -1)
    edge:SetBackdrop({ edgeFile = FLAT, edgeSize = 1 })
    edge:SetBackdropBorderColor(0, 0, 0)
    return edge
end

-- A cooldown on `b`, restarted only when its timing changes.
function GR.Timing(b, start, duration, enable)
    if start > 0 and duration > 0 and enable > 0 then
        if b.start ~= start or b.duration ~= duration then
            b.start, b.duration = start, duration
            b.cooldown:SetCooldown(start, duration)
        end
    elseif b.start then
        b.start, b.duration = nil, nil
        b.cooldown:Clear()
    end
end

-- The tooltip beside the button, filled again each second only while it counts
-- a cooldown (GameTooltip:SetInventoryItem returns hasItem, hasCooldown:
-- PaperDollFrame.lua:733), and only while the pointer stays.
local hovered, refill
local function Tip(b)
    GameTooltip:SetOwner(b, "ANCHOR_RIGHT")
    if b.slot then
        local hasItem, hasCooldown = GameTooltip:SetInventoryItem("player", b.slot)
        if not hasItem then GameTooltip:SetText(_G[string.upper(GR.SLOT_NAMES[b.slot])]) end
        return hasCooldown
    end
    GameTooltip:SetText("Gear sets")
    if b.wornSet then GameTooltip:AddLine(b.wornSet, 0, 1, 0) end
    GameTooltip:AddLine("Click: the sets on your character window.", 1, 1, 1)
    GameTooltip:Show()
end
local function Refill()
    if hovered and GameTooltip:IsOwned(hovered) then Tip(hovered) elseif refill then refill:Cancel(); refill = nil end
end
local function Unhover()
    if hovered and GameTooltip:IsOwned(hovered) then GameTooltip:Hide() end
    hovered = nil
    if refill then refill:Cancel(); refill = nil end
end

-- Which way a bar button's menu opens: away from the screen's nearer edge.
local function Way(b)
    local x, y = b:GetCenter()
    if not x then return "UP" end
    if db[b.bar.key] == "DOWN" then return x < UIParent:GetWidth() / 2 and "RIGHT" or "LEFT" end
    return y < UIParent:GetHeight() / 2 and "UP" or "DOWN"
end

local function OnEnter()
    hovered = this
    local counting = Tip(this)
    if counting and not refill then refill = C_Timer.NewTicker(1, Refill) end
    if this.slot then GR.OpenMenu(this, this.slot, Way(this)) else GR.OpenSets(this) end
end
local function OnLeave()
    Unhover()
    GR.MenuLeave()
end
local function OnClick()
    this:SetChecked(nil)
    if not this.slot then GR.OpenPanel()
    elseif IsShiftKeyDown() then
        if ChatFrameEditBox:IsVisible() then ChatFrameEditBox:Insert(GetInventoryItemLink("player", this.slot)) end
    else
        UseInventoryItem(this.slot)
    end
end

GR.buttons = {}
local function Button(name, bar, slot)
    local b = CreateFrame("CheckButton", name, bar.holder, "ActionButtonTemplate")
    b.icon, b.hotkey, b.bar, b.slot = _G[name .. "Icon"], _G[name .. "HotKey"], bar, slot
    _G[name .. "Cooldown"]:SetParent(hidden) -- the 1.12 Model; the native one counts down
    _G[name .. "NormalTexture"]:SetAlpha(0)
    b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    b.edge = GR.Edge(b)
    b.cooldown = CreateFrame("Cooldown", nil, b)
    b.cooldown:SetAllPoints(b)
    b.cooldown:SetCountdownFormatter(GR.Countdown)
    -- K8: the item that waits for this slot, in the corner.
    b.wait = b.edge:CreateTexture(nil, "OVERLAY")
    b.wait:SetSize(16, 16)
    b.wait:SetPoint("TOPRIGHT", b, "TOPRIGHT", 0, 0)
    b.wait:Hide()
    b:RegisterForClicks("LeftButtonUp")
    b:SetScript("OnEnter", OnEnter)
    b:SetScript("OnLeave", OnLeave)
    b:SetScript("OnClick", OnClick)
    GR.buttons[#GR.buttons + 1] = b
    return b
end

local function Draw(b)
    local slot = b.slot
    local texture = GetInventoryItemTexture("player", slot)
    b.icon:SetTexture(texture or empty[slot])
    local color = texture and ITEM_QUALITY_COLORS[GetInventoryItemQuality("player", slot) or -1]
    if color then b.edge:SetBackdropBorderColor(color.r, color.g, color.b) else b.edge:SetBackdropBorderColor(0, 0, 0) end
    local guid = GR.want[slot]
    if guid then b.wait:SetTexture(C_Item.GetItemIcon(guid)); b.wait:Show() else b.wait:Hide() end
    GR.Timing(b, GetInventoryItemCooldown("player", slot))
end

function GR.Redraw(slot)
    for _, b in ipairs(GR.buttons) do
        if b.slot == slot then Draw(b) end
    end
end

-- The bars: named holders, so the client saves where they are dragged
-- (### frame:SetDontSavePosition). x, y: the first button's place until then.
local gear = { key = "gearBar", label = "Gear", x = 478, y = 233, bySlot = {},
    holder = CreateFrame("Frame", "GearRackGearBar", UIParent) }
local trinket = { key = "trinketBar", label = "Trinkets", x = 431, y = 440,
    holder = CreateFrame("Frame", "GearRackTrinketBar", UIParent) }
for _, bar in ipairs({ gear, trinket }) do
    bar.holder:SetMovable(true)
    bar.holder:SetClampedToScreen(true)
end
trinket.list = { Button("GearRackTrinket13", trinket, 13), Button("GearRackTrinket14", trinket, 14) }
local setsButton = Button("GearRackSets", gear)

local function Layout(bar)
    local holder, way = bar.holder, db[bar.key]
    if way == "OFF" then holder:Hide(); return end
    for i, b in ipairs(bar.list) do
        b:ClearAllPoints()
        if way == "DOWN" then b:SetPoint("TOPLEFT", holder, "TOPLEFT", 0, (1 - i) * STEP)
        else b:SetPoint("TOPLEFT", holder, "TOPLEFT", (i - 1) * STEP, 0) end
        b:Show()
    end
    local long = #bar.list * STEP - (STEP - SIZE)
    holder:SetSize(way == "DOWN" and SIZE or long, way == "DOWN" and long or SIZE)
    if not holder:IsUserPlaced() then
        holder:ClearAllPoints()
        holder:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", bar.x, bar.y)
    end
    holder:Show()
end

-- The gear bar: db.slots in the order chosen, then the Sets button.
local function GearList()
    for _, b in pairs(gear.bySlot) do b:Hide() end
    gear.list = {}
    for _, slot in ipairs(db.slots) do
        local b = gear.bySlot[slot] or Button("GearRackGear" .. slot, gear, slot)
        gear.bySlot[slot] = b
        gear.list[#gear.list + 1] = b
        Draw(b)
    end
    gear.list[#gear.list + 1] = setsButton
end

function GR.Layout()
    GearList()
    Layout(gear)
    Layout(trinket)
end

-- K9: a slot goes to the end of the gear bar, or off it.
function GR.ToggleSlot(slot)
    for i, s in ipairs(db.slots) do
        if s == slot then table.remove(db.slots, i); GR.Layout(); return end
    end
    db.slots[#db.slots + 1] = slot
    GR.Layout()
end
function GR.OnBar(slot)
    for _, s in ipairs(db.slots) do
        if s == slot then return true end
    end
end

-- The Sets button shows the worn set's icon; once per frame of changes.
local setsDue
local function SetsIcon()
    setsDue = nil
    local ids = GR.Sets()
    local icon, name = SETS_ICON, nil
    for _, id in ipairs(ids) do
        local setName, setIcon, _, isEquipped = C_EquipmentSet.GetEquipmentSetInfo(id)
        if isEquipped then icon, name = GR.Icon(setIcon), setName; break end
    end
    setsButton.icon:SetTexture(icon)
    setsButton.wornSet = name
end

local function Keys()
    for _, b in ipairs(trinket.list) do
        local key = GetBindingKey(b.slot == 13 and "GEARRACK_USE_TOP_TRINKET_ITEM" or "GEARRACK_USE_BOTTOM_TRINKET_ITEM")
        b.hotkey:SetText(key and GetBindingText(key, "KEY_", 1) or "")
    end
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
events:RegisterEvent("BAG_UPDATE_COOLDOWN")
events:RegisterEvent("UPDATE_BINDINGS")
events:RegisterEvent("EQUIPMENT_SETS_CHANGED")
events:RegisterEvent("EQUIPMENT_SWAP_FINISHED")
events:SetScript("OnEvent", function()
    if event == "PLAYER_EQUIPMENT_CHANGED" then
        GR.Redraw(arg1)
    elseif event == "BAG_UPDATE_COOLDOWN" then
        for _, b in ipairs(GR.buttons) do
            if b.slot then GR.Timing(b, GetInventoryItemCooldown("player", b.slot)) end
        end
        return
    elseif event == "UPDATE_BINDINGS" then
        Keys()
        return
    elseif event == "PLAYER_ENTERING_WORLD" then
        GR.Layout()
        for _, b in ipairs(trinket.list) do Draw(b) end
        Keys()
    end
    if not setsDue then setsDue = true; C_Timer.After(0, SetsIcon) end
end)

-- K10: Ctrl+Shift shows a handle over each shown bar; dragging it moves the bar,
-- and the client saves the place. The left and right reads: the merged state
-- lags MODIFIER_STATE_CHANGED (CLASSICAPI_MASTER_REFERENCE "Modifier event state ordering").
local handles, held = {}, false
for _, bar in ipairs({ gear, trinket }) do
    local h = CreateFrame("Frame", nil, bar.holder)
    h:SetAllPoints(bar.holder)
    h:SetFrameStrata("DIALOG")
    h:SetBackdrop({ bgFile = FLAT })
    h:SetBackdropColor(0.2, 0.6, 1, 0.45)
    h:EnableMouse(true)
    local label = h:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetPoint("CENTER", h, "CENTER", 0, 0)
    label:SetText(bar.label)
    h:SetScript("OnMouseDown", function() h.moving = true; bar.holder:StartMoving() end)
    h:SetScript("OnMouseUp", function()
        if h.moving then h.moving = nil; bar.holder:StopMovingOrSizing() end
    end)
    h:Hide()
    handles[#handles + 1] = h
end
local keys = CreateFrame("Frame")
keys:RegisterEvent("MODIFIER_STATE_CHANGED")
keys:SetScript("OnEvent", function()
    local now = (IsLeftShiftKeyDown() or IsRightShiftKeyDown())
        and (IsLeftControlKeyDown() or IsRightControlKeyDown()) and true or false
    if now == held then return end
    held = now
    for _, h in ipairs(handles) do
        if held then h:Show() else h:GetScript("OnMouseUp")(); h:Hide() end
    end
end)
