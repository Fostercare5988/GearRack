-- GearRack: the automatic trinket swap (K20), TrinketMenu's queue rules. Each
-- trinket slot has a list in priority order with a stop line; a slot whose
-- queue is on wears the first listed trinket above the line that is ready
-- (30 seconds or less left: putting a trinket on starts 30 seconds anyway).
-- A worn trinket that is ready, or has no use, is only replaced by a High
-- priority one. A worn trinket stays while it pauses the queue, while its swap
-- delay runs after a use, and while its own buff is on you. Nothing is
-- decided in combat, dead, casting or during a set swap. It wakes on events
-- and at one timer, the next moment a listed trinket gets ready; it sleeps
-- while no queue is on.
local _, GR = ...
local db = GearRackDB

local NAMES = { [13] = "Upper trinket", [14] = "Lower trinket" }
local hold = {} -- slot -> true while the worn trinket keeps the queue waiting
local events = CreateFrame("Frame")
local timer, nextAt, buffHold

local function WornID(s) return tonumber(string.match(GetInventoryItemLink("player", s) or "", "item:(%d+)")) end
local function Near(start, duration) return start == 0 or start + duration - GetTime() <= 30 end
local function Later(at) if at > GetTime() and (not nextAt or at < nextAt) then nextAt = at end end

-- A carried copy of `id` in the bags, not chosen for the other slot
-- (### GetInventoryItemsForSlot, the bag codes as Menu.lua reads them).
local found, inBag = {}, {}
local function Carried(id, s)
    table.wipe(found)
    GetInventoryItemsForSlot(s, found)
    for at, link in pairs(found) do
        if math.floor(at / ITEM_INVENTORY_LOCATION_BAGS) % 2 == 1 and tonumber(string.match(link, "item:(%d+)")) == id then
            inBag.bagID, inBag.slotIndex = math.floor(at / 256) % 256, at % 256
            local guid = C_Item.GetItemGUID(inBag)
            if guid and GR.want[27 - s] ~= guid then return guid end
        end
    end
end

-- Whether the worn trinket keeps its slot for now (pause, swap delay, its buff).
local function Keeps(id, start, duration)
    local stats = db.trinkets[id]
    if stats and stats.pause then return true end
    local used = start > 0 and start + duration - GetTime() > 30 and GetTime() - start
    if stats and stats.delay then
        if used and used < stats.delay then Later(start + stats.delay); return true end
        return false
    end
    if used and used < 1 then Later(start + 1); return true end -- the buff is not on yet
    local spell = C_Item.GetItemSpell(id)
    if spell and C_UnitAuras.GetAuraDataBySpellName("player", spell, "HELPFUL") then buffHold = true; return true end
end

local function Decide(s)
    hold[s] = nil
    local q = db.queue[s]
    if not q.on or GR.want[s] or db.before then return end -- a choice waits, or a situation's set is worn
    local id = WornID(s)
    local start, duration, enable = GetInventoryItemCooldown("player", s)
    if id and Keeps(id, start, duration) then hold[s] = true; return end
    local ready = id and Near(start, duration)
    if id and not ready then Later(start + duration - 30) end
    for _, c in ipairs(q.list) do
        if c == 0 or (ready and c == id) then return end
        local stats = db.trinkets[c]
        if not ready or enable == 0 or (stats and stats.priority) then
            local cs, cd = GetItemCooldown(c)
            if Near(cs, cd) then
                local guid = Carried(c, s)
                if guid then GR.Choose(s, guid, true); return end
            else
                Later(cs + cd - 30)
            end
        end
    end
end

local function Run()
    if timer then timer:Cancel(); timer = nil end
    nextAt, buffHold = nil, nil
    if UnitAffectingCombat("player") or UnitIsDeadOrGhost("player") or not C_EquipmentSet.CanUseEquipmentSets() then return end
    local cast = select(5, C_Spell.CastingInfo()) or select(5, C_Spell.ChannelInfo())
    if cast then Later(cast / 1000 + 0.1); timer = C_Timer.NewTimer(nextAt - GetTime(), Run); return end
    for s = 13, 14 do Decide(s); GR.Redraw(s) end
    if buffHold then events:RegisterUnitEvent("UNIT_AURA", "player") else events:UnregisterEvent("UNIT_AURA") end
    if nextAt then timer = C_Timer.NewTimer(nextAt - GetTime(), Run) end
end
local due
local function Due() due = nil; Run() end
function GR.QueueAsk() if not due then due = true; C_Timer.After(0, Due) end end

-- The events, only while a queue is on.
local WAKE = { "BAG_UPDATE_COOLDOWN", "PLAYER_EQUIPMENT_CHANGED", "BAG_UPDATE_DELAYED", "PLAYER_REGEN_ENABLED",
    "PLAYER_ALIVE", "PLAYER_UNGHOST", "EQUIPMENT_SWAP_FINISHED", "PLAYER_ENTERING_WORLD" }
local function Watch()
    local on = db.queue[13].on or db.queue[14].on
    for _, e in ipairs(WAKE) do
        if on then events:RegisterEvent(e) else events:UnregisterEvent(e) end
    end
    if on then GR.QueueAsk() else
        events:UnregisterEvent("UNIT_AURA")
        if timer then timer:Cancel(); timer = nil end
        hold[13], hold[14] = nil, nil
    end
    GR.Redraw(13)
    GR.Redraw(14)
end
GR.QueueWatch = Watch
events:SetScript("OnEvent", function()
    if event == "PLAYER_EQUIPMENT_CHANGED" and arg1 ~= 13 and arg1 ~= 14 then return end
    GR.QueueAsk()
end)

-- "off", "on" or "hold", for the mark on the trinket buttons.
function GR.QueueState(s) return not db.queue[s].on and "off" or hold[s] and "hold" or "on" end

function GR.QueueSwitch(s, on)
    db.queue[s].on = on and true or false
    Watch()
    if GR.TrinketsChanged then GR.TrinketsChanged() end
end
function GR.QueueToggle(s)
    GR.QueueSwitch(s, not db.queue[s].on)
    GR.Print(NAMES[s] .. (db.queue[s].on and ": automatic swap on." or ": automatic swap off."))
end
-- A trinket chosen by hand stops its slot's queue (TrinketMenu's manual choices).
function GR.QueueOff(s)
    if not db.queue[s].on then return end
    GR.QueueSwitch(s, false)
    GR.Print(NAMES[s] .. ": automatic swap off, since you chose one. Alt-click the trinket to turn it on again.")
end
-- A set worn by hand that holds a trinket slot does the same.
function GR.QueueSet(id)
    local ignored = {}
    for _, slot in ipairs(C_EquipmentSet.GetIgnoredSlots(id) or {}) do ignored[slot] = true end
    for s = 13, 14 do if not ignored[s] then GR.QueueOff(s) end end
end

-- The list: the worn and carried trinkets by item ID; new ones join at the end,
-- below the stop line (0), so they are never worn until moved up (TrinketMenu).
function GR.QueueFill(s)
    local list, have = db.queue[s].list, {}
    for _, c in ipairs(list) do have[c] = true end
    local function Add(c) if c and not have[c] then have[c] = true; list[#list + 1] = c end end
    Add(WornID(s))
    Add(WornID(27 - s))
    table.wipe(found)
    GetInventoryItemsForSlot(s, found)
    for _, link in pairs(found) do Add(tonumber(string.match(link, "item:(%d+)"))) end
    Add(0)
    return list
end

local login = CreateFrame("Frame")
login:RegisterEvent("PLAYER_ENTERING_WORLD")
login:SetScript("OnEvent", function() this:UnregisterAllEvents(); Watch() end)
