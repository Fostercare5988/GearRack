-- GearRack: sets that put themselves on (K14) and sets by target (K15).
-- Each situation is read from its own event, and only while its row names a
-- set and the switch is on. The first true situation with a set is worn; when
-- none is left, the gear worn before comes back.
local _, GR = ...
local db = GearRackDB

local function Instance() local _, kind = GetInstanceInfo(); return kind end
local function Aura(name) return C_UnitAuras.GetAuraDataBySpellName("player", name, "HELPFUL") ~= nil end
local function Class() local _, class = UnitClass("player"); return class end
local under -- MIRROR_TIMER_START / _STOP "BREATH" (MirrorTimer.lua:74)
local PLACE = { "ZONE_CHANGED_NEW_AREA" }

-- K14's order. key: the saved key; label: the page's; events: what wakes it.
-- UNVERIFIED on OctoWoW: that its own foods and drinks name their aura "Food" or "Drink".
GR.SITUATIONS = {
    { key = "mounted", label = "Mounted", events = { "PLAYER_MOUNT_DISPLAY_CHANGED", "ZONE_CHANGED_NEW_AREA" },
        read = function() return IsMounted() and Instance() ~= "raid" end },
    { key = "water", label = "Under water", events = { "MIRROR_TIMER_START", "MIRROR_TIMER_STOP" },
        read = function() return under end },
    { forms = true },
    { key = "food", label = "Eating or drinking", events = { "UNIT_AURA" },
        read = function() return Aura("Food") or Aura("Drink") end },
    { key = "evocation", label = "Evocation", class = "MAGE", events = { "UNIT_AURA" },
        read = function() return Aura("Evocation") end },
    { key = "spiritTap", label = "Spirit Tap", class = "PRIEST", events = { "UNIT_AURA" },
        read = function() return Aura("Spirit Tap") end },
    { key = "lowMana", label = "Low on mana", mana = true, events = { "UNIT_POWER_UPDATE" },
        read = function(row) -- on under half, off over three quarters
            local max = UnitManaMax("player")
            if max == 0 then return false end
            return UnitMana("player") / max < (row.on and 0.75 or 0.5)
        end },
    { key = "resting", label = "City or inn", where = true, events = { "PLAYER_UPDATE_RESTING" },
        read = function() return IsResting() end },
    { key = "pvp", label = "Battleground", where = true, events = PLACE, read = function() return Instance() == "pvp" end },
    { key = "raid", label = "Raid", where = true, events = PLACE, read = function() return Instance() == "raid" end },
    { key = "party", label = "Dungeon", where = true, events = PLACE, read = function() return Instance() == "party" end },
}

-- The forms the character has, by name (a druid learns them in another order
-- than the bar's index), made at the first call after login.
local rows
function GR.Rows()
    if rows then return rows end
    rows = {}
    for _, row in ipairs(GR.SITUATIONS) do
        if row.forms then
            for i = 1, GetNumShapeshiftForms() do
                local _, name = GetShapeshiftFormInfo(i)
                if name then
                    rows[#rows + 1] = { key = "form " .. name, label = name, events = { "UPDATE_SHAPESHIFT_FORM" },
                        read = function()
                            local now = GetShapeshiftForm()
                            return now > 0 and select(2, GetShapeshiftFormInfo(now)) == name
                        end }
                end
            end
        elseif (not row.class or row.class == Class()) and (not row.mana or UnitPowerType("player") == 0) then
            rows[#rows + 1] = row
        end
    end
    return rows
end

-- K15: a set per enemy creature type; Critter, Totem and the rest are "other".
GR.TYPES = { "Beast", "Demon", "Dragonkin", "Elemental", "Giant", "Humanoid", "Mechanical", "Undead" }
local isType = {}
for _, kind in ipairs(GR.TYPES) do isType[kind] = true end

-- A set name to its ID; "" or a deleted set is Off.
local function SetID(name) return name and name ~= "" and C_EquipmentSet.GetEquipmentSetID(name) end

-- The one look per frame: the first true situation with a set.
local current -- the situation's set now worn
local function Snapshot()
    local before = {}
    for slot = 1, 19 do before[slot] = GR.Worn(slot) end
    return before
end
local function Look()
    if GR.WindowShown() then return end
    local name -- none while the switch is off: then the gear from before comes back
    if db.auto then
        for _, row in ipairs(GR.Rows()) do
            if row.on and SetID(db.when[row.key]) then name = db.when[row.key]; break end
        end
    end
    if name == current and (name or not db.before) then return end
    current = name
    if name then
        db.before = db.before or Snapshot()
        GR.UseSet(SetID(name), nil, true)
    else -- the gear worn before; a slot then empty stays as it is
        for slot, guid in pairs(db.before) do
            if GR.Worn(slot) ~= guid and C_Item.IsItemGUIDInInventory(guid) then GR.Choose(slot, guid, true) end
        end
        db.before = nil
    end
end
local lookDue
local function LookDue() lookDue = nil; Look() end
local function Ask() if not lookDue then lookDue = true; C_Timer.After(0, LookDue) end end

-- The target's set until it is worn: a swap refused (another one running, a
-- locked item) or ended with a weapon out of place (### EQUIPMENT_SWAP_FINISHED:
-- success nil) is tried again when the swap or the lock is over; three tries,
-- as Core's Try (the MC play, 2026-11-22: one of two weapons changed).
-- Done when what can go on is on: in combat the weapons; a missing item is not
-- waited for (a set that lacked one swapped three times at every target).
local aim, tries
local again = CreateFrame("Frame")
local function Aim()
    if GR.Calling() then return end
    local name = C_EquipmentSet.GetEquipmentSetInfo(aim or 0)
    if not name or not GR.OutOfPlace(aim, UnitAffectingCombat("player") and "weapons") then
        aim = nil
    elseif UnitIsDeadOrGhost("player") or not C_EquipmentSet.CanUseEquipmentSets()
        or C_EquipmentSet.EquipmentSetContainsLockedItems(aim) then
        -- waits for the swap's end or the lock
    elseif tries == 3 then
        aim = nil
        GR.Print("Could not put on all of " .. name .. ".")
    else
        tries = tries + 1
        GR.UseSet(aim, true)
    end
    if aim then
        again:RegisterEvent("EQUIPMENT_SWAP_FINISHED")
        again:RegisterEvent("ITEM_LOCK_CHANGED")
    else
        again:UnregisterAllEvents()
    end
end
again:SetScript("OnEvent", Aim)

-- The target, a fifth of a second after the last change (tabbing swaps once).
local wait
local function Target()
    wait = nil
    if not UnitCanAttack("player", "target") or UnitIsDead("target") then return end
    local kind = UnitCreatureType("target")
    aim = isType[kind] and SetID(db.target[kind]) or SetID(db.target.other) -- a type left Off is "other"
    tries = 0
    Aim()
end

-- KP-64, at the first login: the rows' keys only; a form's while the character
-- has it, or while the forms are not known yet.
local swept
local function Sweep()
    swept = true
    local owned = { other = true }
    for _, kind in ipairs(GR.TYPES) do owned[kind] = true end
    for key in pairs(db.target) do if not owned[key] then db.target[key] = nil end end
    for _, row in ipairs(GR.SITUATIONS) do if row.key then owned[row.key] = true end end
    for _, row in ipairs(GR.Rows()) do owned[row.key] = true end
    local unknown = GetNumShapeshiftForms() == 0
    for key in pairs(db.when) do
        if not owned[key] and not (unknown and string.find(key, "^form ")) then db.when[key] = nil end
    end
end

local events = CreateFrame("Frame")
local function Read(e)
    local changed
    for _, row in ipairs(GR.Rows()) do
        if row.listens and (not e or row.listens[e]) then
            local on = row.read(row) and true or false
            if on ~= row.on then row.on, changed = on, true end
        end
    end
    if changed or not e then Ask() end
end

-- Only the events of rows in use, with their page's switch on and the Gear sets
-- window closed. Sets by target has its own switch (the second play: a switch
-- on another page left its rows grey with no reason shown).
function GR.AutoWatch()
    GR.DrawEvents()
    events:UnregisterAllEvents()
    events:RegisterEvent("PLAYER_ENTERING_WORLD")
    if GR.WindowShown() then return end
    if db.byTarget then
        for _, name in pairs(db.target) do
            if SetID(name) then events:RegisterEvent("PLAYER_TARGET_CHANGED"); break end
        end
    end
    if not db.auto then Ask(); return end
    for _, row in ipairs(GR.Rows()) do
        row.listens = nil
        if SetID(db.when[row.key]) then
            row.listens = {}
            for _, e in ipairs(row.events) do
                row.listens[e] = true
                if e == "UNIT_AURA" or e == "UNIT_POWER_UPDATE" then events:RegisterUnitEvent(e, "player")
                else events:RegisterEvent(e) end
            end
        end
    end
    Read()
end

-- Events, as 1.x called them: Automatic sets and Sets by target together, on
-- when either is (the gear bar's Events button, its key, /gr events). Off when
-- either is on, else both on; the pages' checkboxes follow.
function GearRack.ToggleEvents()
    local on = not (db.auto or db.byTarget)
    for variable, key in pairs({ GearRack_auto = "auto", GearRack_byTarget = "byTarget" }) do
        local setting = Settings.GetSetting(variable)
        if setting then setting:SetValue(on) else db[key] = on end
    end
    GR.AutoWatch()
    GR.Print(on and "Events on: Automatic sets and Sets by target." or "Events off.")
end

events:SetScript("OnEvent", function()
    if event == "PLAYER_TARGET_CHANGED" then
        if wait then wait:Cancel() end
        wait = C_Timer.NewTimer(0.2, Target)
        return
    elseif event == "PLAYER_ENTERING_WORLD" then
        if not swept then Sweep() end
        GR.AutoWatch()
        return
    elseif string.find(event, "^MIRROR_TIMER") then
        if arg1 ~= "BREATH" then return end
        under = event == "MIRROR_TIMER_START"
    elseif event == "UNIT_POWER_UPDATE" and arg2 ~= "MANA" then
        return
    end
    Read(event)
end)
events:RegisterEvent("PLAYER_ENTERING_WORLD")
