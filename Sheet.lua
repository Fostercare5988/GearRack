-- GearRack on the character window: a slot's menu on hover (K7), Alt+click
-- to put a slot on the gear bar (K9), and the ticks of the sets panel (K3).
local _, GR = ...

-- Menus open to the right, the weapons' downward, as GearRack 1.x opened them
-- (PaperDollFrame.xml: the weapons sit below the model).
local WAY = {}
for slot = 1, 19 do WAY[slot] = slot >= 16 and slot <= 18 and "DOWN" or "RIGHT" end

local sheet, ticks = {}, {}
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

-- K3: a tick on each slot while the sets panel shows; ticked slots are saved.
function GR.Ticks(on)
    for slot, b in ipairs(sheet) do
        local t = ticks[slot]
        if on and not t then
            t = CreateFrame("CheckButton", nil, b, "UICheckButtonTemplate")
            t:SetSize(18, 18)
            t:SetPoint("TOPLEFT", b, "TOPLEFT", -4, 4)
            t:SetFrameLevel(b:GetFrameLevel() + 2)
            t:SetChecked(1)
            ticks[slot] = t
        end
        if t then if on then t:Show() else t:Hide() end end
    end
end
function GR.Ticked(slot) return ticks[slot] and ticks[slot]:GetChecked() and true or false end
-- A set's ticks: every slot but those it leaves out (### C_EquipmentSet.GetIgnoredSlots).
function GR.SetTicks(ignored)
    for slot = 1, 19 do
        if ticks[slot] then ticks[slot]:SetChecked(1) end
    end
    for _, slot in ipairs(ignored or {}) do
        if ticks[slot] then ticks[slot]:SetChecked(nil) end
    end
end

-- The panel's opener, at the model's top right.
local opener = CreateFrame("Button", "GearRackSheetButton", PaperDollFrame)
opener:SetSize(24, 24)
opener:SetPoint("TOPRIGHT", CharacterModelFrame, "TOPRIGHT", -2, -2)
opener:SetFrameLevel(CharacterModelFrame:GetFrameLevel() + 2)
opener:SetNormalTexture("Interface\\Icons\\INV_Misc_Gear_01")
opener:SetScript("OnClick", function() GR.TogglePanel() end)
opener:SetScript("OnEnter", function()
    GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
    GameTooltip:SetText("Gear sets")
end)
opener:SetScript("OnLeave", function() GameTooltip:Hide() end)
