-- GearRack on the character window: a slot's menu on hover (K7), Alt-click
-- to put a slot on the gear bar (K9), and the ticks of the sets panel (K3).
local _, GR = ...

-- Menus open over the model, the weapons' downward (PaperDollFrame.xml: the
-- left column, the right column, the weapons below the model).
local WAY = {}
for _, slot in ipairs({ 1, 2, 3, 15, 5, 4, 19, 9 }) do WAY[slot] = "RIGHT" end
for _, slot in ipairs({ 10, 6, 7, 8, 11, 12, 13, 14 }) do WAY[slot] = "LEFT" end
for _, slot in ipairs({ 16, 17, 18 }) do WAY[slot] = "DOWN" end

local sheet, overlays, ticks, altShown = {}, {}, {}, false
for slot, name in ipairs(GR.SLOT_NAMES) do
    sheet[slot] = _G["Character" .. name]
    sheet[slot]:HookScript("OnLeave", GR.MenuLeave) -- their OnLeave is inline XML
end

-- PaperDollItemSlotButton_OnEnter also runs each frame while the slot owns the
-- tooltip (PaperDollFrame.lua:750); an open menu returns at once.
hooksecurefunc("PaperDollItemSlotButton_OnEnter", function()
    local slot = this:GetID()
    if sheet[slot] == this and not altShown then GR.OpenMenu(this, slot, WAY[slot]) end
end)

-- K9: while Alt is held with the window open, each slot shows whether it is on the bar.
local function Tint()
    for slot, o in pairs(overlays) do
        if GR.OnBar(slot) then o.tint:SetVertexColor(0.2, 0.9, 0.2, 0.45) else o.tint:SetVertexColor(0, 0, 0, 0.55) end
    end
end
local function Overlay(slot)
    local o = CreateFrame("Button", nil, sheet[slot])
    o:SetAllPoints(sheet[slot])
    o:SetFrameLevel(sheet[slot]:GetFrameLevel() + 3)
    o.tint = o:CreateTexture(nil, "OVERLAY")
    o.tint:SetAllPoints(o)
    o.tint:SetTexture("Interface\\Buttons\\WHITE8X8")
    o:SetScript("OnClick", function() GR.ToggleSlot(slot); Tint() end)
    overlays[slot] = o
end
local function ShowOverlays(on)
    altShown = on
    if on then
        GR.CloseMenu()
        if not overlays[1] then for slot in ipairs(sheet) do Overlay(slot) end end
        Tint()
    end
    for _, o in pairs(overlays) do
        if on then o:Show() else o:Hide() end
    end
end

local keys = CreateFrame("Frame")
keys:RegisterEvent("MODIFIER_STATE_CHANGED")
keys:SetScript("OnEvent", function()
    local on = (IsLeftAltKeyDown() or IsRightAltKeyDown()) and PaperDollFrame:IsVisible() and true or false
    if on ~= altShown then ShowOverlays(on) end
end)
PaperDollFrame:HookScript("OnHide", function() if altShown then ShowOverlays(false) end end)

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
