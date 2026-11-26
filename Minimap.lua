-- GearRack: two minimap buttons (K18). The purple gear opens Gear sets, the
-- PvP trinket opens Trinkets; right-click opens the settings page; a drag
-- moves a button round the minimap, and its place is saved per character.
-- AutoLazy's tray takes them in like any other minimap button.
local _, GR = ...
local db = GearRackDB

local RADIUS = 80 -- UNVERIFIED with a square minimap (Tweaks): there the tray holds them
local buttons = {}

local function Place(b)
    local angle = math.rad(db.angles[b.key] or b.angle)
    b:ClearAllPoints()
    b:SetPoint("CENTER", Minimap, "CENTER", RADIUS * math.cos(angle), RADIUS * math.sin(angle))
end

-- While dragged only: the angle from the minimap's centre to the pointer.
local function Drag()
    local x, y = GetCursorPosition()
    local scale, cx, cy = Minimap:GetEffectiveScale(), Minimap:GetCenter()
    db.angles[this.key] = math.floor(math.deg(math.atan2(y / scale - cy, x / scale - cx)) + 0.5)
    Place(this)
end

local function Make(name, key, angle, icon, title, open)
    local b = CreateFrame("Button", name, Minimap)
    b.key, b.angle = key, angle
    b:SetSize(32, 32)
    b:SetFrameStrata("MEDIUM")
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b:RegisterForDrag("LeftButton")
    local t = b:CreateTexture(nil, "BACKGROUND")
    t:SetSize(20, 20)
    t:SetPoint("CENTER", b, "CENTER", 0, 1)
    t:SetTexture(icon)
    local border = b:CreateTexture(nil, "OVERLAY")
    border:SetSize(54, 54)
    border:SetPoint("TOPLEFT", b, "TOPLEFT", 0, 0)
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    b:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    b:SetScript("OnClick", function() if arg1 == "RightButton" then GR.OpenPage() else open() end end)
    b:SetScript("OnEnter", function()
        GameTooltip:SetOwner(this, "ANCHOR_LEFT")
        GameTooltip:SetText(title)
        GameTooltip:AddLine("Click: open. Right-click: settings. Drag: move.", 1, 1, 1)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    b:SetScript("OnDragStart", function() GameTooltip:Hide(); this:SetScript("OnUpdate", Drag) end)
    b:SetScript("OnDragStop", function() this:SetScript("OnUpdate", nil) end)
    b:SetScript("OnHide", function() this:SetScript("OnUpdate", nil) end)
    Place(b)
    buttons[#buttons + 1] = b
end
Make("GearRackMinimapGear", "gear", 200, GR.MEDIA .. "GearRack-Icon", "Gear sets", function() GR.ToggleWindow() end)
Make("GearRackMinimapTrinkets", "trinkets", 225, "Interface\\Icons\\INV_Jewelry_TrinketPVP_02", "Trinkets",
    function() GR.ToggleTrinkets(13) end)

-- The page's switch.
function GR.MinimapButtons()
    for _, b in ipairs(buttons) do b:SetShown(db.minimap) end
end
GR.MinimapButtons()
