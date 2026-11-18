-- GearRack: gear sets in ClassicAPI's set store, sets that put themselves on,
-- and two bars of the gear you wear. Doc headings are ClassicAPI's docs/API.md;
-- "FrameXML" is the client's own code.
if not CLASSIC_API_VERSION then error("GearRack needs ClassicAPI.", 0) end

local _, GR = ...
GearRack = {}
GearRackDB = GearRackDB or {} -- restored first: LoadSavedVariablesFirst
local db = GearRackDB

-- The bars and the switches start before the page registers, so their
-- defaults are written here; `when` and `target` are the pages' (Auto.lua).
GR.DEFAULTS = { gearBar = "ACROSS", trinketBar = "DOWN", readyAlert = true, auto = false, byTarget = false, minimap = true }
for key, value in pairs(GR.DEFAULTS) do
    if db[key] == nil then db[key] = value end
end
db.when, db.target, db.slots = db.when or {}, db.target or {}, db.slots or { 16, 17, 18 }
db.ammo, db.trinkets, db.angles, db.hidden = db.ammo or {}, db.trinkets or {}, db.angles or {}, db.hidden or {}
db.queue = db.queue or {}
for slot = 13, 14 do db.queue[slot] = db.queue[slot] or { on = false, list = {} } end
-- KP-64: one sweep clears every saved key nothing owns.
local OWNED = { gearBar = 1, trinketBar = 1, readyAlert = 1, auto = 1, byTarget = 1, minimap = 1, when = 1, target = 1, slots = 1,
    before = 1, ammo = 1, trinkets = 1, angles = 1, queue = 1, hidden = 1, current = 1 }
for key in pairs(db) do
    if not OWNED[key] then db[key] = nil end
end

GR.WEAPON = { [16] = true, [17] = true, [18] = true } -- what changes in combat
GR.OTHER = { [11] = 12, [12] = 11, [13] = 14, [14] = 13 } -- right-click: the other ring or trinket

GR.MEDIA = "Interface\\AddOns\\GearRack\\media\\" -- GearRack-Icon: the purple gear of 1.x

function GR.Print(text) DEFAULT_CHAT_FRAME:AddMessage("|cffff9e38GearRack|r: " .. text) end

-- The GUID of the item worn in a slot (### C_Item.GetItemGUID).
local worn = {}
function GR.Worn(slot)
    worn.equipmentSlotIndex = slot
    return C_Item.GetItemGUID(worn)
end

-- A set's icon as the store keeps it (a basename) or a full path.
function GR.Icon(icon)
    if icon and not string.find(icon, "\\", 1, true) then return "Interface\\Icons\\" .. icon end
    return icon
end

-- The sets by name, read again after EQUIPMENT_SETS_CHANGED.
local sorted, names, stale = {}, {}, true
local function ByName(a, b) return names[a] < names[b] end
function GR.SetsStale() stale = true end -- after our own change, before its event
function GR.Sets()
    if stale then
        stale = false
        table.wipe(sorted)
        table.wipe(names)
        for _, id in ipairs(C_EquipmentSet.GetEquipmentSetIDs()) do
            names[id] = C_EquipmentSet.GetEquipmentSetInfo(id)
            sorted[#sorted + 1] = id
        end
        table.sort(sorted, ByName)
    end
    return sorted, names
end

-- What waits: one item per slot (K8) and a set to finish (K2).
local want, tries, pending = {}, {}, nil
GR.want = want

local events = CreateFrame("Frame")
local WAITING = { "ITEM_LOCK_CHANGED", "PLAYER_ALIVE", "PLAYER_UNGHOST", "BAG_UPDATE_DELAYED" }
local function Listen()
    local on = pending or next(want)
    for _, e in ipairs(WAITING) do
        if on then events:RegisterEvent(e) else events:UnregisterEvent(e) end
    end
end

-- Whether a slot of the set other than the weapons is not in place yet
-- (### C_EquipmentSet.GetItemLocations: 0 saved empty, 1 ignored, -1 missing).
local function Rest(id)
    for slot, at in pairs(C_EquipmentSet.GetItemLocations(id)) do
        if not GR.WEAPON[slot] and at ~= 1 and at ~= -1 then
            if at == 0 then
                if GetInventoryItemLink("player", slot) then return true end
            elseif at ~= ITEM_INVENTORY_LOCATION_PLAYER + slot then
                return true
            end
        end
    end
end

-- K22: the set's ammo, which ClassicAPI's sets do not hold (slots 1-19), by item ID.
-- UNVERIFIED: that EquipItemByName without dstSlot (the cursor path) equips ammo.
function GR.AmmoID() return tonumber(string.match(GetInventoryItemLink("player", 0) or "", "item:(%d+)")) end
local function Wear(id)
    C_EquipmentSet.UseEquipmentSet(id)
    local ammo = db.ammo[C_EquipmentSet.GetEquipmentSetInfo(id)]
    if ammo and GR.AmmoID() ~= ammo and C_Item.GetItemCount(ammo) > 0 then C_Item.EquipItemByName(ammo) end
end

-- K2: in combat the weapons change at once and the rest when combat ends;
-- dead, all of it waits. `once`: a set for a target, not finished later.
-- A set worn by hand (not `once`, not a `situation`) is the one the Sets
-- button names (`current`, as 1.x's CurrentSet), and it stops the queues of
-- the trinket slots it holds, as TrinketMenu's manual choices do.
local function ByHand(id)
    db.current = C_EquipmentSet.GetEquipmentSetInfo(id)
    GR.QueueSet(id)
    GR.SetsChanged()
end
function GR.UseSet(id, once, situation)
    pending = nil
    if not once and not situation then ByHand(id) end
    if UnitIsDeadOrGhost("player") then
        if not once then pending = id end
    else
        Wear(id)
        if not once and UnitAffectingCombat("player") and Rest(id) then
            pending = id
            GR.Print("The rest of the set follows when combat ends.")
        end
    end
    Listen()
end

local function Finish()
    if not pending or UnitIsDeadOrGhost("player") or UnitAffectingCombat("player") then return end
    local id = pending
    pending = nil
    Wear(id)
    Listen()
end

-- K8: a choice is tried now, or when what stops it is over: combat for
-- armor, death, a lock, a set swap. Done when the slot shows the item.
local function Try(slot)
    local guid = want[slot]
    if GR.Worn(slot) == guid then want[slot] = nil; return end
    if UnitIsDeadOrGhost("player") or (UnitAffectingCombat("player") and not GR.WEAPON[slot])
        or not C_EquipmentSet.CanUseEquipmentSets() or C_Item.IsLocked(guid) then return end
    if tries[slot] == 3 then
        want[slot] = nil
        GR.Print("Could not put on " .. (C_Item.GetItemLink(guid) or "the item") .. ".")
        return
    end
    tries[slot] = tries[slot] + 1
    C_Item.EquipItemByName(guid, slot)
end

local function TryAll()
    for slot in pairs(want) do
        Try(slot)
        if not want[slot] then GR.Redraw(slot) end
    end
    Listen()
end

-- A choice by hand (`auto` nil) while a situation holds is kept for its end (K14).
-- The same choice again, while it waits, cancels it.
-- A trinket chosen by hand stops that slot's queue (K20).
function GR.Choose(slot, guid, auto)
    if not auto and db.before then db.before[slot] = guid end
    if not auto and db.queue[slot] then GR.QueueOff(slot) end
    if want[slot] == guid and not auto then
        want[slot] = nil
    else
        want[slot], tries[slot] = guid, 0
        Try(slot)
    end
    GR.Redraw(slot)
    Listen()
end

events:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:RegisterEvent("EQUIPMENT_SWAP_FINISHED")
events:RegisterEvent("EQUIPMENT_SETS_CHANGED")
events:RegisterEvent("WEAR_EQUIPMENT_SET")
events:SetScript("OnEvent", function()
    if event == "PLAYER_EQUIPMENT_CHANGED" then
        if want[arg1] and GR.Worn(arg1) == want[arg1] then want[arg1] = nil; Listen() end
    elseif event == "EQUIPMENT_SETS_CHANGED" then
        stale = true
    elseif event == "WEAR_EQUIPMENT_SET" then
        -- ClassicAPI's own handler swaps what it can (Util/EquipmentManager.lua).
        ByHand(arg1)
        if UnitAffectingCombat("player") or UnitIsDeadOrGhost("player") then pending = arg1; Listen() end
    elseif event == "BAG_UPDATE_DELAYED" then
        for slot, guid in pairs(want) do
            if not C_Item.IsItemGUIDInInventory(guid) then want[slot] = nil; GR.Redraw(slot) end
        end
        Listen()
    else -- combat or death over, a lock changed, a set swap ended
        Finish()
        TryAll()
    end
end)

-- The public function: the three /gr equip macros and other addons.
function GearRack.EquipSet(name)
    local id = C_EquipmentSet.GetEquipmentSetID(name)
    if id then GR.UseSet(id) else GR.Print('No set is named "' .. name .. '".') end
end

BINDING_HEADER_GEARRACK = "GearRack"
BINDING_NAME_GEARRACK_USE_TOP_TRINKET_ITEM = "Use Trinket 1 (Upper slot)"
BINDING_NAME_GEARRACK_USE_BOTTOM_TRINKET_ITEM = "Use Trinket 2 (Lower slot)"

SLASH_GEARRACK1 = "/gr"
SlashCmdList.GEARRACK = function(msg)
    msg = msg or ""
    local name = string.match(msg, "^%s*equip%s+(.-)%s*$")
    if name then GearRack.EquipSet(name)
    elseif string.find(msg, "^%s*sets%s*$") then GR.ToggleWindow()
    elseif string.find(msg, "^%s*trinkets%s*$") then GR.ToggleTrinkets(13)
    else GR.OpenPage() end
end
