-- GearRack: the sets panel beside the character window (K3). The sets by
-- name, a name, an icon, Equip, Save and Delete; the ticks on the slots say
-- which slots a set saves. Sets are ClassicAPI's (### EquipmentSet).
local _, GR = ...

local FLAT = "Interface\\Buttons\\WHITE8X8"
local ROW, TOP = 24, 30
local QUESTION = "INV_Misc_QuestionMark"

local panel = CreateFrame("Frame", "GearRackSetsPanel", PaperDollFrame)
panel:SetWidth(200)
panel:SetPoint("TOPLEFT", CharacterFrame, "TOPRIGHT", -34, -12) -- UNVERIFIED: where the window's art ends
panel:SetBackdrop({ bgFile = FLAT, edgeFile = FLAT, edgeSize = 1 })
panel:SetBackdropColor(0.06, 0.06, 0.06, 0.92)
panel:SetBackdropBorderColor(0, 0, 0)
panel:EnableMouse(true)
panel:Hide()
local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
title:SetPoint("TOPLEFT", panel, "TOPLEFT", 8, -8)
title:SetText("Gear sets")

local chosen, icon = nil, QUESTION -- the set the buttons act on, and the icon Save gives

local box = CreateFrame("EditBox", "GearRackSetName", panel, "InputBoxTemplate")
box:SetSize(144, 20)
box:SetAutoFocus(false)
box:SetMaxLetters(31) -- ### C_EquipmentSet.CreateEquipmentSet: shorter than 32
box:SetScript("OnEscapePressed", function() this:ClearFocus() end)
box:SetScript("OnEnterPressed", function() this:ClearFocus() end)

local iconButton = CreateFrame("Button", nil, panel)
iconButton:SetSize(24, 24)
iconButton:SetPoint("LEFT", box, "RIGHT", 6, 0)
iconButton.texture = iconButton:CreateTexture(nil, "ARTWORK")
iconButton.texture:SetAllPoints(iconButton)

local hint = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
hint:SetWidth(184)
hint:SetJustifyH("LEFT")
hint:SetText("Tick the slots the set saves. A new icon is kept when you press Save.")

local rows, buttons = {}, {}
local Draw

local function Choose(id)
    chosen = id
    if id then
        local name, setIcon = C_EquipmentSet.GetEquipmentSetInfo(id)
        box:SetText(name)
        icon = setIcon or QUESTION
        GR.SetTicks(C_EquipmentSet.GetIgnoredSlots(id))
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
        if not GR.Ticked(slot) then C_EquipmentSet.IgnoreSlotForSave(slot) end
    end
    local id = C_EquipmentSet.GetEquipmentSetID(name)
    if id then C_EquipmentSet.SaveEquipmentSet(id, icon) else id = C_EquipmentSet.CreateEquipmentSet(name, icon) end
    C_EquipmentSet.ClearIgnoredSlotsForSave()
    Choose(id)
end

StaticPopupDialogs.GEARRACK_DELETE = {
    text = 'Delete the set "%s"?',
    button1 = YES, button2 = NO,
    timeout = 0, whileDead = 1, hideOnEscape = 1,
    OnAccept = function(id) C_EquipmentSet.DeleteEquipmentSet(id) end,
}

local function PanelButton(text, x, onClick)
    local b = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    b:SetSize(58, 22)
    b:SetText(text)
    b:SetScript("OnClick", onClick)
    b.x = x
    buttons[#buttons + 1] = b
    return b
end
local equip = PanelButton("Equip", 8, function() GR.UseSet(chosen) end)
PanelButton("Save", 71, Save)
local delete = PanelButton("Delete", 134, function()
    StaticPopup_Show("GEARRACK_DELETE", C_EquipmentSet.GetEquipmentSetInfo(chosen), nil, chosen)
end)

-- A row: the set's icon and name, a tick when it is worn. Its tooltip names
-- what is missing (### GameTooltip:SetEquipmentSet); a drag puts it on an action bar.
local function Row(i)
    local r = rows[i]
    if r then return r end
    r = CreateFrame("Button", nil, panel)
    r:SetSize(184, ROW - 2)
    r:SetPoint("TOPLEFT", panel, "TOPLEFT", 8, -TOP - (i - 1) * ROW)
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
    r:SetScript("OnClick", function() Choose(this.id) end)
    r:SetScript("OnDragStart", function() C_EquipmentSet.PickupEquipmentSet(this.id) end)
    r:SetScript("OnEnter", function()
        GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
        GameTooltip:SetEquipmentSet(this.setName)
        GameTooltip:Show()
    end)
    r:SetScript("OnLeave", function() GameTooltip:Hide() end)
    rows[i] = r
    return r
end

Draw = function()
    local ids = GR.Sets()
    local known
    for i, id in ipairs(ids) do
        local r = Row(i)
        local name, setIcon, _, isEquipped = C_EquipmentSet.GetEquipmentSetInfo(id)
        r.id, r.setName = id, name
        r.icon:SetTexture(GR.Icon(setIcon))
        r.text:SetText(name)
        if isEquipped then r.worn:Show() else r.worn:Hide() end
        if id == chosen then r.mark:Show(); known = true else r.mark:Hide() end
        r:Show()
    end
    for i = #ids + 1, #rows do rows[i]:Hide() end
    if not known then chosen = nil end
    local y = -TOP - #ids * ROW - 8
    box:ClearAllPoints()
    box:SetPoint("TOPLEFT", panel, "TOPLEFT", 14, y)
    hint:ClearAllPoints()
    hint:SetPoint("TOPLEFT", panel, "TOPLEFT", 8, y - 26)
    for _, b in ipairs(buttons) do
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", panel, "TOPLEFT", b.x, y - 52)
    end
    if chosen then equip:Enable(); delete:Enable() else equip:Disable(); delete:Disable() end
    iconButton.texture:SetTexture(GR.Icon(icon))
    panel:SetHeight(TOP + #ids * ROW + 90)
end

-- Redrawn once per frame of changes, only while it shows.
local due
local function Due() due = nil; if panel:IsShown() then Draw() end end
panel:SetScript("OnEvent", function()
    if not due then due = true; C_Timer.After(0, Due) end
end)
panel:SetScript("OnShow", function()
    for _, e in ipairs({ "EQUIPMENT_SETS_CHANGED", "EQUIPMENT_SWAP_FINISHED", "PLAYER_EQUIPMENT_CHANGED" }) do
        this:RegisterEvent(e)
    end
    GR.Ticks(true)
    Draw()
    GR.AutoWatch() -- nothing changes by itself while the panel shows (K14)
end)
panel:SetScript("OnHide", function()
    this:UnregisterAllEvents()
    GR.Ticks(false)
    GR.AutoWatch()
end)
function GR.PanelShown() return panel:IsShown() end

function GR.OpenPanel()
    if not PaperDollFrame:IsVisible() then ToggleCharacter("PaperDollFrame") end
    panel:Show()
end
function GR.TogglePanel()
    if panel:IsShown() then panel:Hide() else panel:Show() end
end

-- The icon picker: the worn gear's icons first, then every spell and item icon
-- (### GetMacroIcons / GetMacroItemIcons, basenames), read at its first opening.
-- 64 buttons show a window of the list; the wheel and the slider move it.
local COLUMNS, LINES, CELL = 8, 8, 30
local picker = CreateFrame("Frame", nil, panel)
picker:SetSize(COLUMNS * CELL + 28, LINES * CELL + 12)
picker:SetPoint("TOPLEFT", panel, "TOPRIGHT", 2, 0)
picker:SetBackdrop({ bgFile = FLAT, edgeFile = FLAT, edgeSize = 1 })
picker:SetBackdropColor(0.06, 0.06, 0.06, 0.95)
picker:SetBackdropBorderColor(0, 0, 0)
picker:EnableMouse(true)
picker:EnableMouseWheel(true)
picker:Hide()

local icons, cells, offset = nil, {}, 0
local slider = CreateFrame("Slider", nil, picker)
slider:SetOrientation("VERTICAL")
slider:SetWidth(12)
slider:SetPoint("TOPRIGHT", picker, "TOPRIGHT", -4, -6)
slider:SetPoint("BOTTOMRIGHT", picker, "BOTTOMRIGHT", -4, 6)
slider:SetThumbTexture("Interface\\Buttons\\UI-ScrollBar-Knob")
slider:SetValueStep(1)

local function Cells()
    for i, cell in ipairs(cells) do
        local name = icons[offset * COLUMNS + i]
        cell.icon = name
        if name then cell:SetNormalTexture(GR.Icon(name)); cell:Show() else cell:Hide() end
    end
end
slider:SetScript("OnValueChanged", function() offset = math.floor(this:GetValue() + 0.5); Cells() end)
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
