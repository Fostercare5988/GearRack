-- GearRack: one menu for every owner (K7). For a slot: the carried items that
-- fit it and that the character can wear, each copy on its own, and an empty
-- button that takes the worn item off. For the Sets button: every set by name.
local _, GR = ...
local db = GearRackDB

local SIZE, STEP, PAD = 36, 40, 4
local FLAT = "Interface\\Buttons\\WHITE8X8"

local menu = CreateFrame("Frame", "GearRackMenu", UIParent)
menu:SetFrameStrata("DIALOG")
menu:SetClampedToScreen(true)
menu:EnableMouse(true)
menu:SetBackdrop({ bgFile = FLAT, edgeFile = FLAT, edgeSize = 1 })
menu:SetBackdropColor(0.06, 0.06, 0.06, 0.92)
menu:SetBackdropBorderColor(0, 0, 0)
menu:Hide()

local GOLD = { r = 1, g = 0.82, b = 0 } -- the worn set's edge
local owner, slot, sets, drawer -- what the menu shows
local entries, list, found = {}, {}, {}

-- A location code of GetInventoryItemsForSlot to the item's GUID (### C_EquipmentSet.GetItemLocations:
-- bits 0-7 the slot, 8-15 the bag, BAGS set for a bag).
local inBag, worn = {}, {}
local function Locate(at)
    local inside = at % 256
    if math.floor(at / ITEM_INVENTORY_LOCATION_BAGS) % 2 == 1 then
        inBag.bagID, inBag.slotIndex = math.floor(at / 256) % 256, inside
        return C_Item.GetItemGUID(inBag), GetContainerItemCooldown(inBag.bagID, inside)
    end
    if drawer then return end -- the drawer lists the bags only
    worn.equipmentSlotIndex = inside
    return C_Item.GetItemGUID(worn), GetInventoryItemCooldown("player", inside)
end

local function Entry(n)
    local e = entries[n] or {}
    entries[n] = e
    list[n] = e
    return e
end
local function Better(a, b)
    if a.off or b.off then return b.off and not a.off end
    if a.quality ~= b.quality then return a.quality > b.quality end
    if a.name ~= b.name then return a.name < b.name end
    return a.guid < b.guid -- two copies keep their order
end

-- The items for `s`: bags and the other slots; never the one worn there.
local function FillItems(s)
    table.wipe(found)
    table.wipe(list)
    GetInventoryItemsForSlot(s, found)
    local here, n = GR.Worn(s), 0
    for at, link in pairs(found) do
        local guid, start, duration, enable = Locate(at)
        local _, _, _, equipLoc = C_Item.GetItemInfoInstant(link)
        if guid and guid ~= here and C_PlayerInfo.CanUseItem(link)
            and (s ~= 17 or equipLoc ~= "INVTYPE_WEAPON" or CanDualWield()) then
            n = n + 1
            local e = Entry(n)
            e.guid, e.off, e.set, e.worn = guid, nil, nil, nil
            e.name = string.match(link, "%[(.-)%]") or ""
            e.quality = C_Item.GetItemQuality(guid) or 1
            e.icon = C_Item.GetItemIcon(guid)
            e.start, e.duration, e.enable = start, duration, enable
        end
    end
    if here and not drawer then
        n = n + 1
        local e = Entry(n)
        e.guid, e.off, e.set, e.worn, e.icon, e.enable = nil, true, nil, nil, nil, 0
    end
    table.sort(list, Better)
    return n
end

-- The sets by name, the one the Sets button names in gold; a hidden one only
-- while Alt is held (1.x's hide mark).
local function FillSets()
    table.wipe(list)
    local n, current, ids = 0, GR.CurrentSet(), GR.Sets()
    for _, id in ipairs(ids) do
        local name, icon = C_EquipmentSet.GetEquipmentSetInfo(id)
        if not db.hidden[name] or IsAltKeyDown() then
            n = n + 1
            local e = Entry(n)
            e.guid, e.off, e.set, e.name, e.icon, e.worn, e.enable = nil, nil, id, name, GR.Icon(icon), id == current, 0
        end
    end
    return n
end

-- The menu's buttons: an item's icon, or a set's icon and name.
local pool = {}
local function Click()
    local e = this.entry
    if e.set then GR.UseSet(e.set)
    elseif e.off then GR.TakeOff(slot)
    elseif drawer then GR.Choose(arg1 == "RightButton" and 14 or 13, e.guid) -- K21: left upper, right lower
    else GR.Choose(arg1 == "RightButton" and GR.OTHER[slot] or slot, e.guid) end
    GR.CloseMenu()
end
local function Enter()
    local e = this.entry
    GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
    if e.set then GameTooltip:SetEquipmentSet(e.name); GameTooltip:Show()
    elseif e.off then GameTooltip:SetText("Take off")
    else GameTooltip:SetItemByGUID(e.guid) end
end
local function Leave()
    if GameTooltip:IsOwned(this) then GameTooltip:Hide() end
    GR.MenuLeave()
end
local function Pooled(i)
    local b = pool[i]
    if b then return b end
    b = CreateFrame("Button", nil, menu)
    b:SetHeight(SIZE)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetSize(SIZE, SIZE)
    b.icon:SetPoint("TOPLEFT", b, "TOPLEFT", 0, 0)
    b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    b.edge = GR.Edge(b)
    b.edge:SetAllPoints(b.icon)
    b.cooldown = CreateFrame("Cooldown", nil, b)
    b.cooldown:SetAllPoints(b.icon)
    b.cooldown:SetCountdownFormatter(GR.Countdown)
    b.label = b:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    b.label:SetPoint("LEFT", b.icon, "RIGHT", 6, 0)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b:SetScript("OnClick", Click)
    b:SetScript("OnEnter", Enter)
    b:SetScript("OnLeave", Leave)
    pool[i] = b
    return b
end

-- A narrow column away from the owner, as GearRack 1.x drew it: one item wide up
-- to 4, two up to 12, three up to 18, four up to 24, then five. Sets one under
-- the other with their names.
local function Across(n) return n <= 4 and 1 or n <= 12 and 2 or n <= 18 and 3 or n <= 24 and 4 or 5 end
local way
local function Show(n)
    local per, width = Across(n), SIZE
    if sets then per, width = 1, 170 end
    local across, lines = math.min(n, per), math.ceil(n / per)
    local sideways = way == "LEFT" or way == "RIGHT"
    for i = 1, n do
        local b, e = Pooled(i), list[i]
        b.entry = e
        b:SetWidth(width)
        b.icon:SetTexture(e.icon or "Interface\\Buttons\\UI-Quickslot")
        local color = e.worn and GOLD or e.quality and ITEM_QUALITY_COLORS[e.quality]
        if color and not e.off then b.edge:SetBackdropBorderColor(color.r, color.g, color.b)
        else b.edge:SetBackdropBorderColor(0, 0, 0) end
        b.label:SetText(sets and e.name or "")
        GR.Timing(b, e.start or 0, e.duration or 0, e.enable)
        local line, at = math.floor((i - 1) / per), (i - 1) % per
        local x, y = PAD + at * STEP, PAD + line * STEP
        if sideways then x, y = PAD + line * STEP, PAD + at * STEP end
        b:ClearAllPoints()
        if way == "UP" then b:SetPoint("BOTTOMLEFT", menu, "BOTTOMLEFT", x, y)
        elseif way == "LEFT" then b:SetPoint("TOPRIGHT", menu, "TOPRIGHT", -x, -y)
        else b:SetPoint("TOPLEFT", menu, "TOPLEFT", x, -y) end
        b:Show()
    end
    for i = n + 1, #pool do pool[i]:Hide() end
    local w, h = PAD * 2 + (across - 1) * STEP + width, PAD * 2 + lines * STEP - (STEP - SIZE)
    if sideways then w, h = PAD * 2 + lines * STEP - (STEP - SIZE), PAD * 2 + (across - 1) * STEP + width end
    menu:SetSize(w, h)
    menu:ClearAllPoints()
    if way == "UP" then menu:SetPoint("BOTTOMLEFT", owner, "TOPLEFT", -PAD, 0)
    elseif way == "DOWN" then menu:SetPoint("TOPLEFT", owner, "BOTTOMLEFT", -PAD, 0)
    elseif way == "RIGHT" then menu:SetPoint("TOPLEFT", owner, "TOPRIGHT", 0, PAD)
    else menu:SetPoint("TOPRIGHT", owner, "TOPLEFT", 0, PAD) end
    menu:Show()
end

local function Refresh()
    local n = sets and FillSets() or FillItems(slot)
    if n == 0 then GR.CloseMenu() else Show(n) end
end

-- Redrawn while open only (BAG_UPDATE_DELAYED, the worn gear, the sets).
local OPEN = { "BAG_UPDATE_DELAYED", "PLAYER_EQUIPMENT_CHANGED", "EQUIPMENT_SETS_CHANGED", "EQUIPMENT_SWAP_FINISHED" }
menu:SetScript("OnEvent", Refresh)
local function Open(o, s, w, d)
    if (menu:IsShown() and owner == o) or CursorHasItem() then return end
    owner, slot, sets, way, drawer = o, s, s == nil, w, d
    Refresh()
    if menu:IsShown() then
        for _, e in ipairs(OPEN) do menu:RegisterEvent(e) end
    end
end
GR.OpenMenu = Open
function GR.OpenSets(o, w) Open(o, nil, w) end

function GR.CloseMenu()
    menu:UnregisterAllEvents()
    menu:Hide()
    owner = nil
end

-- Closed when the pointer is on neither the owner nor the menu: one check
-- a tenth of a second after each leave (### region:IsMouseOver).
local function Check()
    if menu:IsShown() and not (owner and owner:IsMouseOver()) and not menu:IsMouseOver() then GR.CloseMenu() end
end
function GR.MenuLeave() C_Timer.After(0.1, Check) end
menu:SetScript("OnLeave", GR.MenuLeave)

-- GAP: no DLL takes an item off without the cursor; C_Item.UnequipItem(slot) into a
-- free bag slot should, as C_EquipmentSet.UseEquipmentSet does for a slot a set saved empty.
function GR.TakeOff(s)
    if CursorHasItem() then return end
    if UnitAffectingCombat("player") and not GR.WEAPON[s] then GR.Print("Armor comes off after combat."); return end
    for bag = 0, 4 do
        local free, family = C_Container.GetContainerNumFreeSlots(bag)
        if free > 0 and family == 0 then
            PickupInventoryItem(s)
            if bag == 0 then PutItemInBackpack() else PutItemInBag(ContainerIDToInventoryID(bag)) end
            return
        end
    end
    GR.Print("Your bags are full.")
end
