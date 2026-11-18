-- GearRack: the ready alert (K11). A worn item used from anywhere (a bar, a
-- key, an action button) whose cooldown is over 30 seconds says so at 30
-- seconds left and when it is ready. Two one-shot timers per use, no watch.
local _, GR = ...
local db = GearRackDB

local armed = {} -- slot -> { start, soon, ready }

local function Alert(slot, text)
    if not db.readyAlert then return end
    local link = GetInventoryItemLink("player", slot)
    if not link then return end
    text = link .. text
    PlaySound("GnomeExploration")
    UIErrorsFrame:AddMessage(text, 0.2, 0.7, 0.9, 1, UIERRORS_HOLD_TIME)
    GR.Print(text)
end

local function Arm(slot)
    local a = armed[slot]
    local start, duration, enable = GetInventoryItemCooldown("player", slot)
    local running = start > 0 and duration > 30 and enable > 0 -- not the 30 s after putting a trinket on
    if a and (not running or a.start ~= start) then
        if a.soon then a.soon:Cancel() end
        a.ready:Cancel()
        armed[slot], a = nil, nil
    end
    if not running or a then return end
    local left = start + duration - GetTime()
    if left <= 0 then return end
    a = { start = start }
    if left > 30 then a.soon = C_Timer.NewTimer(left - 30, function() Alert(slot, " is ready in 30 seconds.") end) end
    a.ready = C_Timer.NewTimer(left, function() armed[slot] = nil; Alert(slot, " is ready.") end)
    armed[slot] = a
end

local events = CreateFrame("Frame")
events:RegisterEvent("BAG_UPDATE_COOLDOWN")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
events:SetScript("OnEvent", function()
    if event == "PLAYER_EQUIPMENT_CHANGED" then Arm(arg1); return end
    for slot = 1, 19 do Arm(slot) end
end)
