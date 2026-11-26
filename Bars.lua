-- GearRack: the gear bar and the trinket bar (K4-K6, K10). Their buttons are
-- the stock action button's parts (FrameXML ActionButtonTemplate.xml) with a
-- native Cooldown that counts down, as on ActionBars' bars.
local _, GR = ...
local db = GearRackDB

local SIZE, STEP = 36, 40
local FLAT = "Interface\\Buttons\\WHITE8X8"
local SETS_ICON = GR.MEDIA .. "GearRack-Icon"
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
empty[0] = select(2, GetInventorySlotInfo("AmmoSlot"))
GR.EMPTY = empty

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
-- The tooltip sits on the side away from the button's menu.
local hovered, refill
local TIP = { UP = "ANCHOR_BOTTOMRIGHT", DOWN = "ANCHOR_RIGHT", RIGHT = "ANCHOR_LEFT", LEFT = "ANCHOR_RIGHT" }
local function Tip(b)
    GameTooltip:SetOwner(b, TIP[b.way or "UP"])
    if b.slot then
        local hasItem, hasCooldown = GameTooltip:SetInventoryItem("player", b.slot)
        if not hasItem then GameTooltip:SetText(_G[string.upper(GR.SLOT_NAMES[b.slot])]) end
        return hasCooldown
    end
    GameTooltip:SetText("Gear sets")
    if b.wornSet then GameTooltip:AddLine(b.wornSet, 0, 1, 0) end
    GameTooltip:AddLine("Click: the Gear sets window.", 1, 1, 1)
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
    if db[b.bar.key] == "DOWN" and b.slot then return x < UIParent:GetWidth() / 2 and "RIGHT" or "LEFT" end
    return y < UIParent:GetHeight() / 2 and "UP" or "DOWN"
end

-- K21: the trinket bar opens the drawer, every carried trinket.
local function OnEnter()
    hovered = this
    this.way = Way(this)
    local counting = Tip(this)
    if counting and not refill then refill = C_Timer.NewTicker(1, Refill) end
    if not this.slot then GR.OpenSets(this, this.way)
    else GR.OpenMenu(this, this.slot, this.way, this.bar.drawer) end
end
local function OnLeave()
    Unhover()
    GR.MenuLeave()
end
-- A trinket: right-click opens the Trinkets window, Alt-click turns its queue on or off.
local function OnClick()
    this:SetChecked(nil)
    local trinket = this.slot == 13 or this.slot == 14
    if not this.slot then GR.ToggleWindow()
    elseif trinket and arg1 == "RightButton" then GR.ToggleTrinkets(this.slot)
    elseif trinket and IsAltKeyDown() then GR.QueueToggle(this.slot)
    elseif arg1 == "RightButton" then return
    elseif SpellIsTargeting() then PickupInventoryItem(this.slot) -- a poison or stone in hand: apply it here
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
    -- K20: a small gear while the slot's queue is on, grey while it holds.
    b.queue = b.edge:CreateTexture(nil, "OVERLAY")
    b.queue:SetSize(14, 14)
    b.queue:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", 1, 1)
    b.queue:SetTexture(GR.MEDIA .. "GearRack-Icon")
    b.queue:Hide()
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
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
    local queue = db.queue[slot] and GR.QueueState(slot)
    if queue and queue ~= "off" then b.queue:SetDesaturated(queue == "hold"); b.queue:Show() else b.queue:Hide() end
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
local trinket = { key = "trinketBar", label = "Trinkets", x = 431, y = 440, drawer = true,
    holder = CreateFrame("Frame", "GearRackTrinketBar", UIParent) }
for _, bar in ipairs({ gear, trinket }) do
    bar.holder:SetMovable(true)
    bar.holder:SetClampedToScreen(true)
end
trinket.list = { Button("GearRackTrinket13", trinket, 13), Button("GearRackTrinket14", trinket, 14) }
local setsButton = Button("GearRackSets", gear)
-- Events: lit while Automatic sets or Sets by target is on; a click switches both.
local eventsButton = Button("GearRackEvents", gear)
eventsButton.icon:SetTexture("Interface\\Icons\\INV_Misc_PocketWatch_01")
eventsButton:SetScript("OnEnter", function()
    GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
    GameTooltip:SetText((db.auto or db.byTarget) and "Events: on" or "Events: off")
    GameTooltip:AddLine("Automatic sets and Sets by target.", 1, 1, 1)
    GameTooltip:AddLine("Click: on or off. Right-click: their settings.", 1, 1, 1)
    GameTooltip:Show()
end)
eventsButton:SetScript("OnLeave", function() GameTooltip:Hide() end)
eventsButton:SetScript("OnClick", function()
    this:SetChecked(nil)
    if arg1 == "RightButton" then GR.OpenPage() else GearRack.ToggleEvents() end
    if GameTooltip:IsOwned(this) then this:GetScript("OnEnter")() end
end)
function GR.DrawEvents()
    local on = db.auto or db.byTarget
    eventsButton.icon:SetDesaturated(not on)
    eventsButton.icon:SetAlpha(on and 1 or 0.4)
end

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

-- The gear bar: db.slots in the order chosen, then the Sets and Events buttons.
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
    gear.list[#gear.list + 1] = eventsButton
end

function GR.Layout()
    GearList()
    Layout(gear)
    Layout(trinket)
    if GR.Poisons then GR.Poisons() end
end

-- K9: a slot goes to the end of the gear bar, or off it. The list is made
-- new each time: table.remove counts with Lua 5.0's stored size, `#` does
-- not (KP-65), and the two together broke Claude's list on 2026-11-18.
function GR.ToggleSlot(slot)
    local kept, found = {}, false
    for _, s in ipairs(db.slots) do
        if s == slot then found = true else kept[#kept + 1] = s end
    end
    if not found then kept[#kept + 1] = slot end
    db.slots = kept
    GR.Layout()
    return not found
end

-- The Sets button shows the set last put on by hand, by icon and by name below
-- it (white while all of it is worn, grey when not), as 1.x did. When it is not
-- all worn and a set of as many slots or more is (the player changed by hand),
-- that one instead; a weapons-only set never takes over a full one.
-- Once per frame of changes.
setsButton.label = setsButton:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
setsButton.label:SetPoint("TOP", setsButton, "BOTTOM", 0, -2)
function GR.CurrentSet()
    local mine, mineWhole, mineSize, best, most
    local ids = GR.Sets() -- one value: Lua 5.0's ipairs takes a second as a step
    for _, id in ipairs(ids) do
        local name, _, _, isEquipped, _, _, _, _, ignored = C_EquipmentSet.GetEquipmentSetInfo(id)
        local size = 19 - ignored
        if name == db.current then mine, mineWhole, mineSize = id, isEquipped, size end
        if isEquipped and (not most or size > most) then best, most = id, size end
    end
    if mine and (mineWhole or not best or most < mineSize) then return mine end
    return best
end
local setsDue
local function SetsIcon()
    setsDue = nil
    local id = GR.CurrentSet()
    local name, icon, _, whole = nil, nil, nil, nil
    if id then name, icon, _, whole = C_EquipmentSet.GetEquipmentSetInfo(id) end
    setsButton.icon:SetTexture(id and GR.Icon(icon) or SETS_ICON)
    setsButton.label:SetText(name or "")
    if whole then setsButton.label:SetTextColor(1, 1, 1) else setsButton.label:SetTextColor(0.6, 0.6, 0.6) end
    setsButton.wornSet = name
end
function GR.SetsChanged() if not setsDue then setsDue = true; C_Timer.After(0, SetsIcon) end end

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
    GR.SetsChanged()
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
