-- GearRack: the Gear sets window (K17, K22). The 20 slots laid out as on the
-- character window, each lit when the set saves it; the sets by name between
-- them; a name, an icon, Equip, Save and Delete. Sets are ClassicAPI's
-- (### EquipmentSet); a set's ammo is GearRack's own (GearRackDB.ammo).
local _, GR = ...
local db = GearRackDB

local FLAT = "Interface\\Buttons\\WHITE8X8"
local QUESTION = "INV_Misc_QuestionMark"
local SIZE, STEP, ROW, VISIBLE, WIDTH = 36, 40, 24, 13, 304

local window = CreateFrame("Frame", "GearRackSetsWindow", UIParent)
window:SetSize(WIDTH, 528)
window:SetPoint("CENTER", UIParent, "CENTER", 0, 40) -- until moved; the client keeps its place then
window:SetFrameStrata("HIGH")
window:SetMovable(true)
window:SetClampedToScreen(true)
window:EnableMouse(true)
window:SetBackdrop({ bgFile = FLAT, edgeFile = FLAT, edgeSize = 1 })
window:SetBackdropColor(0.06, 0.06, 0.06, 0.94)
window:SetBackdropBorderColor(0, 0, 0)
window:Hide()
UISpecialFrames[#UISpecialFrames + 1] = "GearRackSetsWindow" -- Escape closes it

-- The title bar moves the window; the close button, as on every window.
function GR.TitleBar(w, text)
    local bar = CreateFrame("Frame", nil, w)
    bar:SetPoint("TOPLEFT", w, "TOPLEFT", 0, 0)
    bar:SetPoint("TOPRIGHT", w, "TOPRIGHT", -24, 0)
    bar:SetHeight(24)
    bar:EnableMouse(true)
    bar:SetScript("OnMouseDown", function() w:StartMoving() end)
    bar:SetScript("OnMouseUp", function() w:StopMovingOrSizing() end)
    local title = bar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("LEFT", bar, "LEFT", 10, 0)
    title:SetText(text)
    local close = CreateFrame("Button", nil, w, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", w, "TOPRIGHT", 2, 2)
    close:SetScript("OnClick", function() w:Hide() end)
end
GR.TitleBar(window, "Gear sets")

local chosen, icon = nil, QUESTION -- the set the window shows, and the icon Save gives
local lit = {}                     -- slot -> true while the set saves it (0 is the ammo)
for slot = 0, 19 do lit[slot] = true end

-- The slots: the character window's two columns, the weapons and the ammo below.
-- A slot's menu opens away from the window (Menu.lua), its tooltip on the other side.
local LEFT, RIGHT, BOTTOM = { 1, 2, 3, 15, 5, 4, 19, 9 }, { 10, 6, 7, 8, 11, 12, 13, 14 }, { 16, 17, 18, 0 }
local TIP = { LEFT = "ANCHOR_RIGHT", RIGHT = "ANCHOR_LEFT", DOWN = "ANCHOR_RIGHT" }
local slots = {}

local function DrawSlot(b)
    local slot = b.slot
    local texture = GetInventoryItemTexture("player", slot)
    b.icon:SetTexture(texture or GR.EMPTY[slot])
    b.icon:SetDesaturated(not lit[slot])
    b.icon:SetAlpha(lit[slot] and 1 or 0.35)
    if lit[slot] then b.out:Hide() else b.out:Show() end
    local color = texture and lit[slot] and ITEM_QUALITY_COLORS[GetInventoryItemQuality("player", slot) or -1]
    if color then b.edge:SetBackdropBorderColor(color.r, color.g, color.b) else b.edge:SetBackdropBorderColor(0, 0, 0) end
end

local function SlotTip(b)
    GameTooltip:SetOwner(b, TIP[b.way])
    if not GameTooltip:SetInventoryItem("player", b.slot) then
        GameTooltip:SetText(b.slot == 0 and "Ammo" or _G[string.upper(GR.SLOT_NAMES[b.slot])])
    end
    GameTooltip:AddLine(lit[b.slot] and "Saved in the set. Click to leave it out." or "Left out of the set. Click to save it.",
        1, 1, 1)
    if b.slot > 0 then GameTooltip:AddLine("The menu puts another item in this slot.", 1, 1, 1) end
    GameTooltip:Show()
end

local function Slot(slot, way, x, y)
    local b = CreateFrame("Button", nil, window)
    b.slot, b.way = slot, way
    b:SetSize(SIZE, SIZE)
    b:SetPoint("TOPLEFT", window, "TOPLEFT", x, y)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetAllPoints(b)
    b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    b.edge = GR.Edge(b)
    -- A slot left out of the set: dark, with a red cross.
    b.out = b.edge:CreateTexture(nil, "OVERLAY")
    b.out:SetSize(18, 18)
    b.out:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 1, -1)
    b.out:SetTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Up")
    b:SetScript("OnClick", function()
        lit[this.slot] = not lit[this.slot]
        DrawSlot(this)
        SlotTip(this)
    end)
    b:SetScript("OnEnter", function()
        SlotTip(this)
        if this.slot > 0 then GR.OpenMenu(this, this.slot, this.way) end
    end)
    b:SetScript("OnLeave", function()
        if GameTooltip:IsOwned(this) then GameTooltip:Hide() end
        GR.MenuLeave()
    end)
    slots[#slots + 1] = b
end
for i = 1, 8 do
    Slot(LEFT[i], "LEFT", 8, -32 - (i - 1) * STEP)
    Slot(RIGHT[i], "RIGHT", WIDTH - 8 - SIZE, -32 - (i - 1) * STEP)
end
for i, slot in ipairs(BOTTOM) do Slot(slot, "DOWN", (WIDTH - 4 * STEP + 4) / 2 + (i - 1) * STEP, -32 - 8 * STEP) end

-- The name, the icon, and the three buttons below the slots.
local box = CreateFrame("EditBox", "GearRackSetName", window, "InputBoxTemplate")
box:SetSize(200, 20)
box:SetPoint("TOPLEFT", window, "TOPLEFT", 16, -32 - 9 * STEP - 8)
box:SetAutoFocus(false)
box:SetMaxLetters(31) -- ### C_EquipmentSet.CreateEquipmentSet: shorter than 32
box:SetScript("OnEscapePressed", function() this:ClearFocus() end)
box:SetScript("OnEnterPressed", function() this:ClearFocus() end)

local iconButton = CreateFrame("Button", nil, window)
iconButton:SetSize(26, 26)
iconButton:SetPoint("LEFT", box, "RIGHT", 10, 0)
iconButton.texture = iconButton:CreateTexture(nil, "ARTWORK")
iconButton.texture:SetAllPoints(iconButton)
iconButton:SetScript("OnEnter", function()
    GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
    GameTooltip:SetText("The set's icon")
    GameTooltip:AddLine("Click to pick another. It is kept when you press Save.", 1, 1, 1)
    GameTooltip:Show()
end)
iconButton:SetScript("OnLeave", function() GameTooltip:Hide() end)

local Draw
local function Named() return C_EquipmentSet.GetEquipmentSetID(box:GetText() or "") end

local function Choose(id)
    chosen = id
    if id then
        local name, setIcon = C_EquipmentSet.GetEquipmentSetInfo(id)
        box:SetText(name)
        icon = setIcon or QUESTION
        for slot = 1, 19 do lit[slot] = true end
        for _, slot in ipairs(C_EquipmentSet.GetIgnoredSlots(id)) do lit[slot] = false end
        lit[0] = db.ammo[name] ~= nil
    end
    Draw()
end

local function Save()
    local name = box:GetText() or ""
    if name == "" then return end
    if #name >= 32 or string.find(name, "\n", 1, true) then
        GR.Print("A set's name is one line of up to 31 letters.")
        return
    end
    C_EquipmentSet.ClearIgnoredSlotsForSave()
    for slot = 1, 19 do
        if not lit[slot] then C_EquipmentSet.IgnoreSlotForSave(slot) end
    end
    local id = C_EquipmentSet.GetEquipmentSetID(name)
    if id then C_EquipmentSet.SaveEquipmentSet(id, icon) else id = C_EquipmentSet.CreateEquipmentSet(name, icon) end
    GR.SetsStale()
    C_EquipmentSet.ClearIgnoredSlotsForSave()
    if not id then return end
    db.ammo[(C_EquipmentSet.GetEquipmentSetInfo(id))] = lit[0] and GR.AmmoID() or nil
    Choose(id)
end

StaticPopupDialogs.GEARRACK_DELETE = {
    text = 'Delete the set "%s"?',
    button1 = YES, button2 = NO,
    timeout = 0, whileDead = 1, hideOnEscape = 1,
    OnAccept = function(id)
        local name = C_EquipmentSet.GetEquipmentSetInfo(id) or ""
        db.ammo[name], db.hidden[name] = nil, nil
        if db.current == name then db.current = nil end
        C_EquipmentSet.DeleteEquipmentSet(id)
        GR.SetsStale()
    end,
}

local function WindowButton(text, x, onClick, tip)
    local b = CreateFrame("Button", nil, window, "UIPanelButtonTemplate")
    b:SetSize(66, 22)
    b:SetPoint("TOPLEFT", window, "TOPLEFT", x, -32 - 9 * STEP - 40)
    b:SetText(text)
    b:SetScript("OnClick", onClick)
    b:SetScript("OnEnter", function()
        GameTooltip:SetOwner(this, "ANCHOR_BOTTOM")
        GameTooltip:SetText(tip)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return b
end
-- New: an empty name, every slot lit, the question mark; type a name, then Save.
local function New()
    chosen, icon = nil, QUESTION
    for slot = 0, 19 do lit[slot] = true end
    box:SetText("")
    box:SetFocus()
    Draw()
end
WindowButton("New", 12, New, "Start a new set from what you wear: type its name, then press Save.")
local equip = WindowButton("Equip", 84, function() GR.UseSet(Named()) end, "Put on the set with this name.")
local save = WindowButton("Save", 156, Save,
    "Save what you wear in the lit slots under this name. A new name makes a new set.")
local delete = WindowButton("Delete", 228, function()
    local id = Named()
    StaticPopup_Show("GEARRACK_DELETE", C_EquipmentSet.GetEquipmentSetInfo(id), nil, id)
end, "Delete the set with this name.")

-- 1.x's hide mark: a hidden set stays out of the Sets button's menu (Alt shows it).
local hide = CreateFrame("CheckButton", nil, window, "UICheckButtonTemplate")
hide:SetSize(24, 24)
hide:SetPoint("TOPLEFT", window, "TOPLEFT", 10, -32 - 9 * STEP - 66)
hide.label = hide:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
hide.label:SetPoint("LEFT", hide, "RIGHT", 2, 0)
hide.label:SetText("Hide from the Sets menu (hold Alt to see it)")
hide:SetScript("OnClick", function()
    local name = C_EquipmentSet.GetEquipmentSetInfo(Named() or 0)
    if name then db.hidden[name] = this:GetChecked() and true or nil end
    Draw()
end)
local hint = window:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
hint:SetPoint("TOPLEFT", window, "TOPLEFT", 14, -32 - 9 * STEP - 94)
hint:SetWidth(WIDTH - 28)
hint:SetJustifyH("LEFT")
hint:SetText("The slots show what you wear. Lit slots go into the set when you press Save; "
    .. "click a slot to leave it out (a red cross) or take it in again.")

-- The sets between the slot columns: icon and name, a tick when worn. Its tooltip
-- names what is missing (### GameTooltip:SetEquipmentSet); a drag puts it on an
-- action bar (### C_EquipmentSet.PickupEquipmentSet). The wheel scrolls a long list.
local rows, offset = {}, 0
for i = 1, VISIBLE do
    local r = CreateFrame("Button", nil, window)
    r:SetSize(WIDTH - 2 * (8 + SIZE + 8), ROW - 2)
    r:SetPoint("TOPLEFT", window, "TOPLEFT", 8 + SIZE + 8, -32 - (i - 1) * ROW)
    r.icon = r:CreateTexture(nil, "ARTWORK")
    r.icon:SetSize(ROW - 2, ROW - 2)
    r.icon:SetPoint("LEFT", r, "LEFT", 0, 0)
    r.text = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    r.text:SetPoint("LEFT", r.icon, "RIGHT", 6, 0)
    r.worn = r:CreateTexture(nil, "OVERLAY")
    r.worn:SetSize(16, 16)
    r.worn:SetPoint("RIGHT", r, "RIGHT", -2, 0)
    r.worn:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
    r.mark = r:CreateTexture(nil, "BACKGROUND")
    r.mark:SetAllPoints(r)
    r.mark:SetTexture(FLAT)
    r.mark:SetVertexColor(1, 0.82, 0, 0.2)
    r:RegisterForDrag("LeftButton")
    -- A click puts the set on and shows it, as 1.x's set list did.
    r:SetScript("OnClick", function() Choose(this.id); GR.UseSet(this.id) end)
    r:SetScript("OnDragStart", function() C_EquipmentSet.PickupEquipmentSet(this.id) end)
    r:SetScript("OnEnter", function()
        GameTooltip:SetOwner(this, "ANCHOR_TOP")
        GameTooltip:SetEquipmentSet(this.setName)
        GameTooltip:AddLine("Click to put it on. Drag it onto an action bar.", 1, 1, 1)
        GameTooltip:Show()
    end)
    r:SetScript("OnLeave", function() GameTooltip:Hide() end)
    rows[i] = r
end
window:EnableMouseWheel(true)
window:SetScript("OnMouseWheel", function()
    offset = math.max(0, math.min(offset - arg1, #GR.Sets() - VISIBLE))
    Draw()
end)

Draw = function()
    local ids = GR.Sets()
    local known
    offset = math.max(0, math.min(offset, #ids - VISIBLE))
    for i, r in ipairs(rows) do
        local id = ids[offset + i]
        if id then
            local name, setIcon, _, isEquipped = C_EquipmentSet.GetEquipmentSetInfo(id)
            r.id, r.setName = id, name
            r.icon:SetTexture(GR.Icon(setIcon))
            r.text:SetText(name)
            if db.hidden[name] then r.text:SetTextColor(0.55, 0.55, 0.55) else r.text:SetTextColor(1, 1, 1) end
            if isEquipped then r.worn:Show() else r.worn:Hide() end
            if id == chosen then r.mark:Show() else r.mark:Hide() end
            r:Show()
        else
            r:Hide()
        end
    end
    for _, id in ipairs(ids) do if id == chosen then known = true end end
    if not known then chosen = nil end
    for _, b in ipairs(slots) do DrawSlot(b) end
    local named = Named()
    if named then equip:Enable(); delete:Enable(); hide:Enable() else equip:Disable(); delete:Disable(); hide:Disable() end
    hide:SetChecked(named and db.hidden[C_EquipmentSet.GetEquipmentSetInfo(named)])
    if (box:GetText() or "") ~= "" then save:Enable() else save:Disable() end
    iconButton.texture:SetTexture(GR.Icon(icon))
end
box:SetScript("OnTextChanged", function() if window:IsShown() then Draw() end end)

-- Redrawn once per frame of changes, only while it shows.
local due
local function Due() due = nil; if window:IsShown() then Draw() end end
window:SetScript("OnEvent", function()
    if event == "PLAYER_ENTERING_WORLD" then
        this:UnregisterEvent(event)
        if C_EquipmentSet.GetNumEquipmentSets() == 0 then return end -- not read yet, or none: keep all
        for name in pairs(db.ammo) do
            if not C_EquipmentSet.GetEquipmentSetID(name) then db.ammo[name] = nil end
        end
        for name in pairs(db.hidden) do
            if not C_EquipmentSet.GetEquipmentSetID(name) then db.hidden[name] = nil end
        end
        if db.current and not C_EquipmentSet.GetEquipmentSetID(db.current) then db.current = nil end
    elseif not due then due = true; C_Timer.After(0, Due) end
end)
window:SetScript("OnShow", function()
    for _, e in ipairs({ "EQUIPMENT_SETS_CHANGED", "EQUIPMENT_SWAP_FINISHED", "PLAYER_EQUIPMENT_CHANGED" }) do
        this:RegisterEvent(e)
    end
    -- At opening, the set the Sets button names; else the one shown last.
    Choose(GR.CurrentSet() or chosen)
    GR.AutoWatch() -- nothing changes by itself while the window shows (K14)
end)
window:SetScript("OnHide", function()
    this:UnregisterAllEvents()
    GR.AutoWatch()
end)
-- KP-64: the ammo, hide mark and `current` of a set that is gone, cleared once at login.
window:RegisterEvent("PLAYER_ENTERING_WORLD")
function GR.WindowShown() return window:IsShown() end
function GR.ToggleWindow() if window:IsShown() then window:Hide() else window:Show() end end

-- The icon picker: the worn gear's icons first, then every spell and item icon
-- (### GetMacroIcons / GetMacroItemIcons, basenames), read at its first opening.
-- 64 buttons show a window of the list; the wheel and the slider move it.
local COLUMNS, LINES, CELL = 8, 8, 30
local picker = CreateFrame("Frame", nil, window)
picker:SetSize(COLUMNS * CELL + 28, LINES * CELL + 12)
picker:SetPoint("TOPLEFT", window, "TOPRIGHT", 2, 0)
picker:SetBackdrop({ bgFile = FLAT, edgeFile = FLAT, edgeSize = 1 })
picker:SetBackdropColor(0.06, 0.06, 0.06, 0.95)
picker:SetBackdropBorderColor(0, 0, 0)
picker:EnableMouse(true)
picker:EnableMouseWheel(true)
picker:Hide()

local icons, cells, first = nil, {}, 0
local slider = CreateFrame("Slider", nil, picker)
slider:SetOrientation("VERTICAL")
slider:SetWidth(12)
slider:SetPoint("TOPRIGHT", picker, "TOPRIGHT", -4, -6)
slider:SetPoint("BOTTOMRIGHT", picker, "BOTTOMRIGHT", -4, 6)
slider:SetThumbTexture("Interface\\Buttons\\UI-ScrollBar-Knob")
slider:SetValueStep(1)

local function Cells()
    for i, cell in ipairs(cells) do
        local name = icons[first * COLUMNS + i]
        cell.icon = name
        if name then cell:SetNormalTexture(GR.Icon(name)); cell:Show() else cell:Hide() end
    end
end
slider:SetScript("OnValueChanged", function() first = math.floor(this:GetValue() + 0.5); Cells() end)
picker:SetScript("OnMouseWheel", function() slider:SetValue(slider:GetValue() - arg1) end)

for i = 1, COLUMNS * LINES do
    local cell = CreateFrame("Button", nil, picker)
    cell:SetSize(CELL - 2, CELL - 2)
    cell:SetPoint("TOPLEFT", picker, "TOPLEFT", 6 + (i - 1) % COLUMNS * CELL, -6 - math.floor((i - 1) / COLUMNS) * CELL)
    cell:SetScript("OnClick", function()
        icon = this.icon
        iconButton.texture:SetTexture(GR.Icon(icon))
        picker:Hide()
    end)
    cells[i] = cell
end

local function Icons()
    icons = {}
    for slot = 1, 19 do
        local texture = GetInventoryItemTexture("player", slot)
        if texture then icons[#icons + 1] = string.gsub(texture, "^[Ii]nterface\\[Ii]cons\\", "") end
    end
    GetMacroIcons(icons)
    GetMacroItemIcons(icons)
    slider:SetMinMaxValues(0, math.max(0, math.ceil(#icons / COLUMNS) - LINES))
end

iconButton:SetScript("OnClick", function()
    if picker:IsShown() then picker:Hide(); return end
    if not icons then Icons() end
    picker:Show()
    slider:SetValue(0)
    Cells()
end)
