-- GearRack on the character window: a slot's menu on hover (K7), Alt+click
-- to put a slot on the gear bar (K9). No button of ours on the window: it hid
-- the arcane resistance (second play); Gear sets opens from the bar and minimap.
local _, GR = ...

-- Menus open to the right, the weapons' downward, as GearRack 1.x opened them
-- (PaperDollFrame.xml: the weapons sit below the model).
local WAY = {}
for slot = 1, 19 do WAY[slot] = slot >= 16 and slot <= 18 and "DOWN" or "RIGHT" end

for slot, name in ipairs(GR.SLOT_NAMES) do
    local b = _G["Character" .. name]
    -- The menu when the pointer comes onto the slot. A hook on the script, not on
    -- PaperDollItemSlotButton_OnEnter: the slot's OnUpdate calls that each frame
    -- while it owns the tooltip (PaperDollFrame.lua:750), and a slot with nothing
    -- to offer read the bags each frame. Their scripts are inline XML.
    b:HookScript("OnEnter", function() GR.OpenMenu(b, slot, WAY[slot]) end)
    b:HookScript("OnLeave", GR.MenuLeave)
    -- K9: Alt+click puts the slot at the end of the gear bar or takes it off;
    -- any other click is the slot's own (PaperDollItemSlotButton_OnClick). A
    -- wrapper, not HookScript: the stock click must not run with Alt.
    local stock = b:GetScript("OnClick")
    b:SetScript("OnClick", function(...)
        if not IsAltKeyDown() then return stock(...) end
        local on = GR.ToggleSlot(slot)
        GR.Print((_G[string.upper(name)] or name) .. (on and " is on the gear bar." or " is off the gear bar."))
    end)
end
