-- GearRack: the poison on each weapon (the user's two "very important" 1.x
-- features after the third play). A weapon button shows its temporary
-- enchant's icon and time left, or its charges when 10 or fewer are left;
-- a weapon in a menu shows the same. Applying a poison: use it, then click
-- the weapon on the bar (Bars.lua). ### C_Item.GetItemTempEnchantInfo,
-- ### C_Item.GetEnchantInfo, ### WEAPON_ENCHANT_CHANGED event.
local _, GR = ...

local FALLBACK = "Interface\\Icons\\Ability_Poisons" -- an enchant whose spell has no icon
local icons = {} -- enchantID -> the bottle's icon, once found

-- The poison's own bottle as the bags show it (the user: OctoWoW's spell icon
-- for Crippling Poison is a green one). Found by name with the rank left off
-- (### C_Container.GetContainerItemInfo); else the spell's icon.
local slotInfo = {}
local function Base(name) return (string.gsub(name or "", "%s+[IVX]+$", "")) end
local function Bottle(name)
    local base = Base(name)
    if base == "" then return end
    for bag = 0, 4 do
        for s = 1, C_Container.GetContainerNumSlots(bag) do
            local info = C_Container.GetContainerItemInfo(bag, s, slotInfo)
            local itemName = info and info.hyperlink and string.match(info.hyperlink, "%[(.-)%]")
            if itemName and info.iconFileID and Base(itemName) == base then return info.iconFileID end
        end
    end
end

local function Icon(enchantID)
    if icons[enchantID] then return icons[enchantID] end
    local info = C_Item.GetEnchantInfo(enchantID)
    local bottle = info and Bottle(info.name)
    if bottle then icons[enchantID] = bottle; return bottle end
    return info and info.spellID and C_Spell.GetSpellTexture(info.spellID) or FALLBACK -- looked for again next time
end

-- "28m", "2h", "45s", or "7c"; and the seconds until the label changes.
local function Label(ms, charges)
    if charges and charges > 0 and charges <= 5 then return charges .. "c", 1, 0.4, 0.1 end
    if charges and charges > 0 and charges <= 10 then return charges .. "c", 1, 0.7, 0.2 end
    local s = (ms or 0) / 1000
    if s <= 0 then return "", 1, 1, 1 end
    local step = s > 3600 and 3600 or s > 60 and 60 or 1
    local n = math.ceil(s / step)
    local text = n .. (step == 3600 and "h" or step == 60 and "m" or "s")
    local red = s < 120 and 0.2 or 1
    return text, 1, red, red, s - (n - 1) * step
end

-- The parts on a button: a small icon in the lower right and the label over it.
local function Parts(b)
    if b.poison then return b.poison end
    local p = CreateFrame("Frame", nil, b)
    p:SetAllPoints(b)
    p:SetFrameLevel(b:GetFrameLevel() + 3)
    p.icon = p:CreateTexture(nil, "OVERLAY")
    p.icon:SetSize(16, 16)
    p.icon:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -1, 1)
    p.text = p:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
    p.text:SetPoint("TOPLEFT", b, "TOPLEFT", 2, -2)
    b.poison = p
    return p
end

-- Draws `b` for the item at `location`; returns the seconds until its label changes.
function GR.DrawPoison(b, location)
    local has, ms, charges, enchantID = C_Item.GetItemTempEnchantInfo(location)
    if not has then
        if b.poison then b.poison:Hide() end
        return
    end
    local p = Parts(b)
    local text, r, g, bl, next = Label(ms, charges)
    p.icon:SetTexture(Icon(enchantID))
    p.text:SetText(text)
    p.text:SetTextColor(r, g, bl)
    p:Show()
    return next
end

-- The bar's weapon buttons, and one timer for the next label change; at login
-- GR.Layout draws them.
local worn, timer = {}, nil
local function Draw()
    if timer then timer:Cancel(); timer = nil end
    local soonest
    for _, b in ipairs(GR.buttons) do
        if b.slot == 16 or b.slot == 17 or b.slot == 18 then
            worn.equipmentSlotIndex = b.slot
            local next = GR.DrawPoison(b, worn)
            if next and (not soonest or next < soonest) then soonest = next end
        end
    end
    if soonest then timer = C_Timer.NewTimer(soonest + 0.05, Draw) end
end
GR.Poisons = Draw

local events = CreateFrame("Frame")
events:RegisterEvent("WEAPON_ENCHANT_CHANGED")
events:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
events:SetScript("OnEvent", function()
    if event == "PLAYER_EQUIPMENT_CHANGED" and arg1 ~= 16 and arg1 ~= 17 and arg1 ~= 18 then return end
    Draw()
end)
