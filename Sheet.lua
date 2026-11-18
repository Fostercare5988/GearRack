-- GearRack on the character window: a slot's menu on hover (K7), Alt+click
-- to put a slot on the gear bar (K9), and a button that opens Gear sets (K17).
local _, GR = ...

-- Menus open to the right, the weapons' downward, as GearRack 1.x opened them
-- (PaperDollFrame.xml: the weapons sit below the model).
local WAY = {}
for slot = 1, 19 do WAY[slot] = slot >= 16 and slot <= 18 and "DOWN" or "RIGHT" end

local sheet = {}
for slot, name in ipairs(GR.SLOT_NAMES) do
    local b = _G["Character" .. name]
    sheet[slot] = b
    b:HookScript("OnLeave", GR.MenuLeave) -- their OnLeave is inline XML
    -- K9: Alt+click puts the slot at the end of the gear bar or takes it off;
    -- any other click is the slot's own (PaperDollItemSlotButton_OnClick).
    local stock = b:GetScript("OnClick")
    b:SetScript("OnClick", function(...)
        if not IsAltKeyDown() then return stock(...) end
        local on = GR.ToggleSlot(slot)
        GR.Print((_G[string.upper(name)] or name) .. (on and " is on the gear bar." or " is off the gear bar."))
    end)
end

-- PaperDollItemSlotButton_OnEnter also runs each frame while the slot owns the
-- tooltip (PaperDollFrame.lua:750); an open menu returns at once.
hooksecurefunc("PaperDollItemSlotButton_OnEnter", function()
    local slot = this:GetID()
    if sheet[slot] == this then GR.OpenMenu(this, slot, WAY[slot]) end
end)

-- The Gear sets window's opener, at the model's top right.
local opener = CreateFrame("Button", "GearRackSheetButton", PaperDollFrame)
opener:SetSize(24, 24)
opener:SetPoint("TOPRIGHT", CharacterModelFrame, "TOPRIGHT", -2, -2)
opener:SetFrameLevel(CharacterModelFrame:GetFrameLevel() + 2)
opener:SetNormalTexture(GR.MEDIA .. "GearRack-Icon")
opener:SetScript("OnClick", function() GR.ToggleWindow() end)
opener:SetScript("OnEnter", function()
    GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
    GameTooltip:SetText("Gear sets")
end)
opener:SetScript("OnLeave", function() GameTooltip:Hide() end)
