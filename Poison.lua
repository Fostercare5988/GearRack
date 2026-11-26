-- GearRack: the poison on each weapon (the user's two "very important" 1.x
-- features after the third play). A weapon button shows its temporary
-- enchant's icon and time left, or its charges when 10 or fewer are left;
-- a weapon in a menu shows the same. The time counts down in the engine, with
-- no timer of ours (### C_DurationUtil.CreateDurationTextBinding). Applying a
-- poison: use it, then click the weapon on the bar (Bars.lua).
-- ### C_Item.GetItemTempEnchantInfo, ### C_Item.GetEnchantInfo, ### WEAPON_ENCHANT_CHANGED event.
local _, GR = ...

local FALLBACK = "Interface\\Icons\\Trade_BrewPoison" -- an oil or stone whose spell has no icon
-- Each poison has its own icon and ring colour, to tell them apart at a glance (the
-- user: Dissolvent showed Instant's icon, since its enchant has none of its own).
-- By the enchant's name, rank left off; the eight are OctoWoW's (EasyPoisons'
-- list), the icons the 1.12 client's. UNVERIFIED: the enchant names on OctoWoW.
local POISONS = {
    ["Instant Poison"] = { "Ability_Poisons", 1, 0.82, 0 },
    ["Dissolvent Poison"] = { "Spell_Nature_Acid_01", 0.1, 0.9, 0.8 },
    ["Crippling Poison"] = { "Ability_PoisonSting", 0.7, 0.3, 1 },
    ["Mind-numbing Poison"] = { "Spell_Nature_NullifyDisease", 0.3, 0.55, 1 },
    ["Deadly Poison"] = { "Ability_Rogue_DualWeild", 0.2, 0.9, 0.2 },
    ["Corrosive Poison"] = { "Spell_Nature_CorrosiveBreath", 1, 0.5, 0 },
    ["Wound Poison"] = { "INV_Misc_Herb_16", 1, 0.15, 0.15 },
    ["Agitating Poison"] = { "Spell_Nature_NullifyPoison", 1, 0.4, 0.8 },
}

-- An enchant's icon and ring colour, read once: a poison's own, else its spell's
-- icon in a black ring.
local looks = {}
local function Look(enchantID)
    local look = looks[enchantID]
    if not look then
        local info = C_Item.GetEnchantInfo(enchantID)
        local poison = info and POISONS[(string.gsub(info.name or "", "%s+[IVX]+$", ""))]
        if poison then
            look = { "Interface\\Icons\\" .. poison[1], poison[2], poison[3], poison[4] }
        else
            look = { info and info.spellID and C_Spell.GetSpellTexture(info.spellID) or FALLBACK, 0, 0, 0 }
        end
        looks[enchantID] = look
    end
    return look
end

-- "2h", "28m", "45s"; red under two minutes (### C_StringUtil.CreateNumericRuleFormatter).
local Up = Enum.NumericRuleFormatRounding.Up
local TIME = C_StringUtil.CreateNumericRuleFormatter()
TIME:SetBreakpoints({
    { threshold = 0, step = 1, rounding = Up, format = "|cffff3333%ds|r" },
    { threshold = 60, format = "|cffff3333%dm|r", components = { { div = 60, step = 1, rounding = Up } } },
    { threshold = 120, format = "%dm", components = { { div = 60, step = 1, rounding = Up } } },
    { threshold = 3600, format = "%dh", components = { { div = 3600, step = 1, rounding = Up } } },
})

-- The parts on a button: a small icon in its ring in the lower right, the label over it.
local function Parts(b)
    if b.poison then return b.poison end
    local p = CreateFrame("Frame", nil, b)
    p:SetAllPoints(b)
    p:SetFrameLevel(b:GetFrameLevel() + 3)
    p.icon = p:CreateTexture(nil, "OVERLAY")
    p.icon:SetSize(21, 21)
    p.icon:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -3, 3)
    p.ring = CreateFrame("Frame", nil, p)
    p.ring:SetPoint("TOPLEFT", p.icon, "TOPLEFT", -2, 2)
    p.ring:SetPoint("BOTTOMRIGHT", p.icon, "BOTTOMRIGHT", 2, -2)
    p.ring:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 2 })
    p.text = p:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    p.text:SetFont("Fonts\\ARIALN.TTF", 14, "THICKOUTLINE") -- clearer over the icon (the user)
    p.text:SetPoint("TOPLEFT", b, "TOPLEFT", 1, -1)
    p.left = C_DurationUtil.CreateDuration()
    p.time = C_DurationUtil.CreateDurationTextBinding()
    p.time:SetFontString(p.text)
    p.time:SetDuration(p.left)
    p.time:SetFormatter(TIME)
    b.poison = p
    return p
end

-- Draws `b` for the item at `location`; with none, hides it and stops its time.
function GR.DrawPoison(b, location)
    local has, ms, charges, enchantID
    if location then has, ms, charges, enchantID = C_Item.GetItemTempEnchantInfo(location) end
    if not has then
        if b.poison then b.poison.time:SetEnabled(false); b.poison:Hide() end
        return
    end
    local p = Parts(b)
    local look = Look(enchantID)
    p.icon:SetTexture(look[1])
    p.ring:SetBackdropBorderColor(look[2], look[3], look[4])
    if charges > 0 and charges <= 10 then
        p.time:SetEnabled(false)
        p.text:SetText(charges .. "c")
        p.text:SetTextColor(1, charges <= 5 and 0.4 or 0.7, charges <= 5 and 0.1 or 0.2)
    else
        p.text:SetTextColor(1, 1, 1)
        p.left:SetTimeFromStart(GetTime(), ms / 1000)
        p.time:SetEnabled(true)
    end
    p:Show()
end

-- The bar's weapon buttons; at login GR.Layout draws them.
local worn = {}
local function Draw()
    for _, b in ipairs(GR.buttons) do
        if b.slot == 16 or b.slot == 17 or b.slot == 18 then
            worn.equipmentSlotIndex = b.slot
            GR.DrawPoison(b, worn)
        end
    end
end
GR.Poisons = Draw

local events = CreateFrame("Frame")
events:RegisterEvent("WEAPON_ENCHANT_CHANGED")
events:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
events:SetScript("OnEvent", function()
    if event == "PLAYER_EQUIPMENT_CHANGED" and arg1 ~= 16 and arg1 ~= 17 and arg1 ~= 18 then return end
    Draw()
end)
