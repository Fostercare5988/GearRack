if not GearRack.enabled then return end

-- Equipment bar, set editor and shared transaction engine.

GearRackUI.DefaultSettings = {			-- These settings are for all users:
	TooltipFollow = "OFF",		-- whether tooltip shows at pointer or default position
	Soulbound = "OFF",			-- whether menu limits items to soulbound only
	Bindings = "OFF",			-- whether key bindings is displayed
	MenuShift = "OFF",			-- whether Shift key needs held to open the menu
	Notify = "OFF",				-- whether to notify when cooldowns finished on used items
	ShowEmpty = "ON",			-- whether to show empty slot in the menu
	FlipMenu = "OFF",			-- whether to display menu on the opposite side
	RightClick = "OFF",			-- whether right click sends to second slot
	ShowTooltips = "ON",		-- whether to display tooltip at all
	RotateMenu = "OFF",			-- whether menu is rotated (temporary setting)
	ShowIcon = "ON",			-- whether to show the minimap button
	DisableToggle = "ON",		-- Shift-click opens sets (OFF toggles the equipment bar)
	FlipBar = "OFF",			-- whether control appears on bottom or right bar grows other direction
	EnableEvents = "OFF",		-- whether automated event scrips run
	CompactList = "OFF",		-- whether saved sets list is compacted or not
	NotifyThirty = "ON",		-- whether notify happens at 30 seconds
	ShowAllEvents = "OFF",		-- whether to show all classes' events
	AllowHidden = "OFF",		-- whether to hide menu items with ALT+click
	LargeFont = "OFF",			-- whether event script font is large or small
	SquareMinimap = "OFF",		-- whether minimap button should go around square minimap
	SetLabels = "ON",			-- whether labels show on set icons
	AutoToggle = "OFF",			-- whether sets automatically toggle when chosen
	CharSheetMenu = "ON",		-- whether to display swap flyout when hovering character sheet slots
}

--[[ Local Variables ]]--
local _G = _G or getfenv(0)
local _, ns = ...
local UI = ns.UI
-- Tooltip lines that name a click action use the ForgeUI heading color.
local ACTION = UI.heading

local function apply_inv_quality_border(button, slot)
	GearRack.SetQualityBorder(button, slot ~= 20 and GetInventoryItemQuality("player", slot), 16)
end

local function get_or_create_enchant_overlay(btn)
	if not btn then return nil end
	if not btn.enchantOverlay then
		local name = btn:GetName()
		local overlay = CreateFrame("Frame", name and (name .. "EnchantOverlay") or nil, btn)
		overlay:SetAllPoints(btn)
		overlay:EnableMouse(false)
		overlay:SetFrameLevel(btn:GetFrameLevel() + 3)

		local iconFrame = CreateFrame("Frame", nil, overlay)
		iconFrame:SetWidth(14)
		iconFrame:SetHeight(14)
		iconFrame:SetPoint("TOPRIGHT", overlay, "TOPRIGHT", -1, -1)

		local iconBg = iconFrame:CreateTexture(nil, "BACKGROUND")
		iconBg:SetPoint("TOPLEFT", iconFrame, "TOPLEFT", 0, 0)
		iconBg:SetPoint("BOTTOMRIGHT", iconFrame, "BOTTOMRIGHT", 0, 0)
		iconBg:SetTexture(0, 0, 0, 0.85)

		local icon = iconFrame:CreateTexture(nil, "ARTWORK")
		icon:SetPoint("TOPLEFT", iconFrame, "TOPLEFT", 1, -1)
		icon:SetPoint("BOTTOMRIGHT", iconFrame, "BOTTOMRIGHT", -1, 1)
		icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
		overlay.icon = icon
		overlay.iconFrame = iconFrame

		local duration = overlay:CreateFontString(nil, "OVERLAY")
		duration:SetFont("Fonts\\FRIZQT__.TTF", 9, "OUTLINE")
		duration:SetPoint("TOPRIGHT", iconFrame, "BOTTOMRIGHT", 0, -1)
		duration:SetShadowOffset(1, -1)
		duration:SetShadowColor(0, 0, 0, 1)
		duration:SetTextColor(1.0, 1.0, 1.0)
		overlay.duration = duration

		overlay:Hide()
		btn.enchantOverlay = overlay
	end
	return btn.enchantOverlay
end

local function format_enchant_duration(expirationMs, charges)
	local s = (type(expirationMs) == "number" and expirationMs > 0) and expirationMs / 1000 or 0
	-- The native enchant display rounds remaining minutes upward. Keep its
	-- localized units and boundary behavior, compacted for an item button.
	local timeStr = s > 0 and string.gsub(SecondsToTimeAbbrev(s), "%s+", "") or ""

	local text = timeStr
	local r, g, b = 1.0, 1.0, 1.0
	if charges and type(charges) == "number" and charges > 0 and charges <= 5 then
		text = charges .. "c"
		r, g, b = 1.0, 0.4, 0.1
	elseif charges and type(charges) == "number" and charges > 0 and charges <= 10 then
		text = (timeStr ~= "") and (timeStr .. "/" .. charges) or (charges .. "c")
		r, g, b = 1.0, 0.7, 0.2
	elseif s > 0 and s < 120 then
		r, g, b = 1.0, 0.2, 0.2
	end

	return text, r, g, b
end

local function get_enchant_texture(info)
	local name = info and info.name
	if name then
		-- UNVERIFIED: test in game. Poisons whose spell has no icon of its own.
		local lower = string.lower(name)
		if string.find(lower, "dissolvent") then
			return "Interface\\Icons\\Spell_Nature_SlowPoison"
		elseif string.find(lower, "corrosive") then
			return "Interface\\Icons\\INV_Corrosive_01"
		end
	end
	return info and info.spellID and C_Spell.GetSpellTexture(info.spellID)
		or "Interface\\Icons\\INV_Misc_QuestionMark"
end

-- Resolved icon art is static by enchant ID; remaining time/charges stay live.
-- Do not retain an unresolved placeholder: cold metadata must be able to recover.
local enchantTextures = {}

-- Temporary enchants are instance state, not localized tooltip text. Since
-- ClassicAPI 1.17 the time left counts down for worn and bagged weapons alike.
local function update_enchant(btn, location)
	if not btn then return end
	local overlay = btn.enchantOverlay or get_or_create_enchant_overlay(btn)
	local hasEnchant, expirationMs, charges, enchantID = C_Item.GetItemTempEnchantInfo(location)
	if not hasEnchant then
		overlay:Hide()
		return
	end
	local texture = enchantTextures[enchantID]
	if not texture then
		texture = get_enchant_texture(C_Item.GetEnchantInfo(enchantID))
		if enchantID and texture ~= "Interface\\Icons\\INV_Misc_QuestionMark" then
			enchantTextures[enchantID] = texture
		end
	end
	if overlay.texture ~= texture then
		overlay.texture = texture
		overlay.icon:SetTexture(texture)
	end
	local text, r, g, b = format_enchant_duration(expirationMs, charges)
	if overlay.text ~= text then overlay.text = text; overlay.duration:SetText(text) end
	if overlay.red ~= r or overlay.green ~= g or overlay.blue ~= b then
		overlay.red, overlay.green, overlay.blue = r, g, b
		overlay.duration:SetTextColor(r, g, b)
	end
	if not overlay:IsShown() then
		overlay.iconFrame:Show()
		overlay.duration:Show()
		overlay:Show()
	end
end

local equippedEnchantLocations = { [16] = {equipmentSlotIndex=16}, [17] = {equipmentSlotIndex=17} }

local function update_equipped_enchant(slotID, btn)
	if slotID == 16 or slotID == 17 then
		update_enchant(btn, equippedEnchantLocations[slotID])
	elseif btn and btn.enchantOverlay then
		btn.enchantOverlay:Hide()
	end
end

local menuEnchantLocation = {}
local function update_menu_weapon_enchant(btn, baggedItem)
	if baggedItem and baggedItem.bag and baggedItem.slot then
		menuEnchantLocation.bagID, menuEnchantLocation.slotIndex = baggedItem.bag, baggedItem.slot
		update_enchant(btn, menuEnchantLocation)
	elseif btn and btn.enchantOverlay then
		btn.enchantOverlay:Hide()
	end
end


-- defaults for GearRackDB.bars
local GearRackUIOpt_Defaults = {
	MainOrient = "HORIZONTAL",  -- direction of main bar, "HORIZONTAL" or "VERTICAL", menu orient always opposite
	MainScale = 1,				-- scale 0-1 of main bar and menu bar
	XPos = 400,					-- left position of main bar
	YPos = 350,					-- top position of main bar
	Locked = "OFF",				-- lock status of main bar (for all intents menu always locked)
	Visible = "ON"				-- whether the bar should be drawn on the screen
}

local user -- GearRack.CharacterKey(), set at PLAYER_LOGIN

GearRackUI = GearRackUI or {}

GearRackUI.FrameToScale = nil -- holds frame being scaled for ScaleUpdate

GearRackUI.BaggedItems = {} -- table containing items in bags to show in menu
GearRackUI.NumberOfItems = 0 -- number of items in the menu
GearRackUI.MaxItems = 0 -- maximum number of items that can display in the menu
GearRackUI.InvOpen = nil -- which inventory slot has its menu open

GearRackUI.TooltipOwner = nil -- (this) when tooltip created
GearRackUI.TooltipType = nil -- "BAG" or "INVENTORY"
GearRackUI.TooltipBag = nil -- bag number
GearRackUI.TooltipSlot = nil -- bag or inventory slot number

GearRackUI.MainDock = "" -- "TOPLEFT" "BOTTOMRIGHT" etc
GearRackUI.MenuDock = ""

GearRackUI.NotifyList = {} -- [itemID] = { name=, bag=0-4, slot=1-x, inv=0-19, hadcooldown=true/nil }
GearRackUI.AmmoCounts = {} -- ["Heavy Shot"]=200, ["Thorium Arrow"]=982, etc
GearRackUI.TrinketsPaired = false -- true if the two trinkets are next to each other

GearRackUI.KeyBindingsSettled = false

GearRackUI.MenuDockedTo = nil -- "SET" for set window, "CHARACTERSHEET" for PaperDollFrame, nil for rack

GearRackUI.SelectedEvent = 0 -- index in list of event selected

GearRackUI.Buffs = {} -- table indexed by buff names, whether a buff is on or not
GearRackUI.BankedItems = {} -- items in the bank indexed by itemID
GearRackUI.BankSlots = { -1,5,6,7,8,9,10 }

local eventList = {} -- note the departure from using the table for local values
local eventListSize = 1

local scratchTable = { {}, {} } -- for secondary sorts
local scratchTableSize = { 1, 1 }

--[[ reference tables ]]--

GearRackUI.OptInfo = {
	["GearRackUI_Control_Rotate"] = { text=GearRackUIText.CONTROL_ROTATE_TEXT, tooltip=GearRackUIText.CONTROL_ROTATE_TOOLTIP },
	["GearRackUI_Control_Lock"] = { text=GearRackUIText.CONTROL_LOCK_TEXT, tooltip=GearRackUIText.CONTROL_LOCK_TOOLTIP },
	["GearRackUI_Control_Options"] = { text=GearRackUIText.CONTROL_OPTIONS_TEXT, tooltip=GearRackUIText.CONTROL_OPTIONS_TOOLTIP },
	["GearRackUI_Opt_TooltipFollow"] = { text=GearRackUIText.OPT_TOOLTIPFOLLOW_TEXT, tooltip=GearRackUIText.OPT_TOOLTIPFOLLOW_TOOLTIP, type="Check", info="TooltipFollow" },
	["GearRackUI_Opt_Soulbound"] = { text=GearRackUIText.OPT_SOULBOUND_TEXT, tooltip=GearRackUIText.OPT_SOULBOUND_TOOLTIP, type="Check", info="Soulbound" },
	["GearRackUI_Opt_Bindings"] = { text=GearRackUIText.OPT_BINDINGS_TEXT, tooltip=GearRackUIText.OPT_BINDINGS_TOOLTIP, type="Check", info="Bindings" },
	["GearRackUI_Opt_MenuShift"] = { text=GearRackUIText.OPT_MENUSHIFT_TEXT, tooltip=GearRackUIText.OPT_MENUSHIFT_TOOLTIP, type="Check", info="MenuShift" },
	["GearRackUI_InvFrame_Resize"] = { text=GearRackUIText.INVFRAME_RESIZE_TEXT, tooltip=GearRackUIText.INVFRAME_RESIZE_TOOLTIP },
	["GearRackUI_Opt_ShowEmpty"] = { text=GearRackUIText.OPT_SHOWEMPTY_TEXT, tooltip=GearRackUIText.OPT_SHOWEMPTY_TOOLTIP, type="Check", info="ShowEmpty" },
	["GearRackUI_Opt_FlipMenu"] = { text=GearRackUIText.OPT_FLIPMENU_TEXT, tooltip=GearRackUIText.OPT_FLIPMENU_TOOLTIP, type="Check", info="FlipMenu" },
	["GearRackUI_Opt_RightClick"] = { text=GearRackUIText.OPT_RIGHTCLICK_TEXT, tooltip=GearRackUIText.OPT_RIGHTCLICK_TOOLTIP, type="Check", info="RightClick" },
	["GearRackUI_Opt_ShowTooltips"] = { text=GearRackUIText.OPT_SHOWTOOLTIPS_TEXT, tooltip=GearRackUIText.OPT_SHOWTOOLTIPS_TOOLTIP, type="Check", info="ShowTooltips" },
	["GearRackUI_Opt_Notify"] = { text=GearRackUIText.OPT_NOTIFY_TEXT, tooltip=GearRackUIText.OPT_NOTIFY_TOOLTIP, type="Check", info="Notify" },
	["GearRackUI_Opt_RotateMenu"] = { text=GearRackUIText.OPT_ROTATEMENU_TEXT, tooltip=GearRackUIText.OPT_ROTATEMENU_TOOLTIP, type="Check", info="RotateMenu" },
	["GearRackUI_Sets_Close"] = { text=GearRackUIText.SETS_CLOSE_TEXT, tooltip=GearRackUIText.SETS_CLOSE_TOOLTIP },
	["GearRackUI_Sets_NameLabel"] = { text=GearRackUIText.SETS_NAMELABEL_TEXT, type="Label" },
	["GearRackUI_Sets_HideSet"] = { text=GearRackUIText.SETS_HIDESET_TEXT, tooltip=GearRackUIText.SETS_HIDESET_TOOLTIP, type="Check" },
	["GearRackUI_Opt_ShowIcon"] = { text=GearRackUIText.OPT_SHOWICON_TEXT, tooltip=GearRackUIText.OPT_SHOWICON_TOOLTIP, type="Check", info="ShowIcon" },
	["GearRackUI_Opt_DisableToggle"] = { text=GearRackUIText.OPT_DISABLETOGGLE_TEXT, tooltip=GearRackUIText.OPT_DISABLETOGGLE_TOOLTIP, type="Check", info="DisableToggle" },
	["GearRackUI_Sets_Lock"] = { text=GearRackUIText.CONTROL_LOCK_TEXT, tooltip=GearRackUIText.CONTROL_LOCK_TOOLTIP },
	["GearRackUI_Sets_BindButton"] = { text=GearRackUIText.SETS_BINDBUTTON_TEXT, tooltip=GearRackUIText.SETS_BINDBUTTON_TOOLTIP, type="Label" },
	["GearRackUI_Sets_SaveButton"] = { text=GearRackUIText.SETS_SAVEBUTTON_TEXT, tooltip=GearRackUIText.SETS_SAVEBUTTON_TOOLTIP, type="Label" },
	["GearRackUI_Sets_RemoveButton"] = { text=GearRackUIText.SETS_REMOVEBUTTON_TEXT, tooltip=GearRackUIText.SETS_REMOVEBUTTON_TOOLTIP, type="Label" },
	["GearRackUI_Opt_FlipBar"] = { text=GearRackUIText.OPT_FLIPBAR_TEXT, tooltip=GearRackUIText.OPT_FLIPBAR_TOOLTIP, type="Check", info="FlipBar" },
	["GearRackUI_Opt_EnableEvents"] = { text=GearRackUIText.OPT_ENABLEEVENTS_TEXT, tooltip=GearRackUIText.OPT_ENABLEEVENTS_TOOLTIP, type="Check", info="EnableEvents" },
	["GearRackUI_Opt_CompactList"] = { text=GearRackUIText.OPT_COMPACTLIST_TEXT, tooltip=GearRackUIText.OPT_COMPACTLIST_TOOLTIP, type="Check", info="CompactList" },
	["GearRackUI_SavedSets_Close"] = { text=GearRackUIText.OPT_SAVEDSETSCLOSE_TEXT, tooltip=GearRackUIText.OPT_SAVEDSETSCLOSE_TOOLTIP },
	["GearRackUI_Events_DeleteButton"] = { text=GearRackUIText.EVENTSDELETE_TEXT, tooltip=GearRackUIText.EVENTSDELETE_TOOLTIP },
	["GearRackUI_Events_EditButton"] = { text=GearRackUIText.EVENTSEDIT_TEXT, tooltip=GearRackUIText.EVENTSEDIT_TOOLTIP },
	["GearRackUI_Events_NewButton"] = { text=GearRackUIText.EVENTSNEW_TEXT, tooltip=GearRackUIText.EVENTSNEW_TOOLTIP },
	["GearRackUI_EditEvent_Save"] = { text=GearRackUIText.EVENTSSAVE_TEXT, tooltip=GearRackUIText.EVENTSSAVE_TOOLTIP },
	["GearRackUI_EditEvent_Test"] = { text=GearRackUIText.EVENTSTEST_TEXT, tooltip=GearRackUIText.EVENTSTEST_TOOLTIP },
	["GearRackUI_EditEvent_Cancel"] = { text=GearRackUIText.EVENTSCANCEL_TEXT, tooltip=GearRackUIText.EVENTSCANCEL_TOOLTIP },
	["GearRackUI_EventName"] = { text=GearRackUIText.EVENTNAME_TEXT, tooltip=GearRackUIText.EVENTNAME_TOOLTIP },
	["GearRackUI_EventTrigger"] = { text=GearRackUIText.EVENTTRIGGER_TEXT, tooltip=GearRackUIText.EVENTTRIGGER_TOOLTIP },
	["GearRackUI_EventDelay"] = { text=GearRackUIText.EVENTDELAY_TEXT, tooltip=GearRackUIText.EVENTDELAY_TOOLTIP },
	["GearRackUI_Opt_NotifyThirty"] = { text=GearRackUIText.OPT_NOTIFYTHIRTY_TEXT, tooltip=GearRackUIText.OPT_NOTIFYTHIRTY_TOOLTIP, type="Check", info="NotifyThirty" },
	["GearRackUI_Opt_ShowAllEvents"] = { text=GearRackUIText.OPT_SHOWALLEVENTS_TEXT, tooltip=GearRackUIText.OPT_SHOWALLEVENTS_TOOLTIP, type="Check", info="ShowAllEvents" },
	["GearRackUI_ResetButton"] = { text=GearRackUIText.RESETBUTTON_TEXT, tooltip=GearRackUIText.RESETBUTTON_TOOLTIP },
	["GearRackUI_Opt_AllowHidden"] = { text=GearRackUIText.OPT_ALLOWHIDDEN_TEXT, tooltip=GearRackUIText.OPT_ALLOWHIDDEN_TOOLTIP, type="Check", info="AllowHidden" },
	["GearRackUI_Opt_LargeFont"] = { text=GearRackUIText.OPT_LARGEFONT_TEXT, tooltip=GearRackUIText.OPT_LARGEFONT_TOOLTIP, type="Check", info="LargeFont" },
	["GearRackUI_ResetEventsButton"] = { text=GearRackUIText.RESETEVENTSBUTTON_TEXT, tooltip=GearRackUIText.RESETEVENTSBUTTON_TOOLTIP },
	["GearRackUI_Opt_SquareMinimap"] = { text=GearRackUIText.OPT_SQUAREMINIMAP_TEXT, tooltip=GearRackUIText.OPT_SQUAREMINIMAP_TOOLTIP, info="SquareMinimap" },
	["GearRackUI_ShowHelmText"] = { text="Show helm", type="Label" },
	["GearRackUI_ShowCloakText" ] = { text="Show cloak", type="Label" },
	["GearRackUI_Opt_SetLabels"] = { text=GearRackUIText.OPT_SETLABELS_TEXT, tooltip=GearRackUIText.OPT_SETLABELS_TOOLTIP, info="SetLabels" },
	["GearRackUI_Opt_AutoToggle"] = { text=GearRackUIText.OPT_AUTOTOGGLE_TEXT, tooltip=GearRackUIText.OPT_AUTOTOGGLE_TOOLTIP, info="AutoToggle" },
	["GearRackUI_Opt_CharSheetMenu"] = { text=GearRackUIText.OPT_CHARSHEETMENU_TEXT, tooltip=GearRackUIText.OPT_CHARSHEETMENU_TOOLTIP, type="Check", info="CharSheetMenu" },
}

-- numerically indexed list of options for scrollable options window
GearRackUI.OptScroll = {
	{ idx="GearRackUI_Opt_ShowIcon" },
	{ idx="GearRackUI_Opt_DisableToggle", dependency="GearRackUI_Opt_ShowIcon" },
	{ idx="GearRackUI_Opt_SquareMinimap", dependency="GearRackUI_Opt_ShowIcon" },
	{ idx="GearRackUI_Opt_Bindings" },
	{ idx="GearRackUI_Opt_SetLabels" },
	{ idx="GearRackUI_Opt_Notify" },
	{ idx="GearRackUI_Opt_NotifyThirty", dependency="GearRackUI_Opt_Notify" },
	{ idx="GearRackUI_Opt_MenuShift" },
	{ idx="GearRackUI_Opt_AutoToggle" },
	{ idx="GearRackUI_Opt_CharSheetMenu" },
	{ idx="GearRackUI_Opt_ShowEmpty" },
	{ idx="GearRackUI_Opt_AllowHidden" },
	{ idx="GearRackUI_Opt_Soulbound" },
	{ idx="GearRackUI_Opt_RightClick" },
	{ idx="GearRackUI_Opt_FlipMenu" },
	{ idx="GearRackUI_Opt_RotateMenu" },
	{ idx="GearRackUI_Opt_FlipBar" },
	{ idx="GearRackUI_Opt_ShowTooltips" },
	{ idx="GearRackUI_Opt_TooltipFollow", dependency="GearRackUI_Opt_ShowTooltips" }
}

-- paperdoll_slot=frame name of the slot on the paperdoll frame (for alt+click purposes)
-- ["SlotName"]=1 for each allowable slot
-- swappable=1 for slots that can be swapped in combat
-- ignore_soulbound = ignore soulbound flag for this slot
GearRackUI.Indexes = {
	[0] = { name=AMMOSLOT, paperdoll_slot="CharacterAmmoSlot", ignore_soulbound=1, swappable=1, INVTYPE_AMMO=1 },
	[1] = { name=INVTYPE_HEAD, paperdoll_slot="CharacterHeadSlot", keybind="GEARRACK_USE_HEAD_ITEM", INVTYPE_HEAD=1 },
	[2] = { name=INVTYPE_NECK, paperdoll_slot="CharacterNeckSlot", keybind="GEARRACK_USE_NECK_ITEM", INVTYPE_NECK=1 },
	[3] = { name=INVTYPE_SHOULDER, paperdoll_slot="CharacterShoulderSlot", keybind="GEARRACK_USE_SHOULDER_ITEM", INVTYPE_SHOULDER=1 },
	[4] = { name=INVTYPE_BODY, paperdoll_slot="CharacterShirtSlot", ignore_soulbound=1, INVTYPE_BODY=1 },
	[5] = { name=INVTYPE_CHEST, paperdoll_slot="CharacterChestSlot", keybind="GEARRACK_USE_CHEST_ITEM", INVTYPE_CHEST=1, INVTYPE_ROBE=1 },
	[6] = { name=INVTYPE_WAIST, paperdoll_slot="CharacterWaistSlot", keybind="GEARRACK_USE_WAIST_ITEM", INVTYPE_WAIST=1 },
	[7] = { name=INVTYPE_LEGS, paperdoll_slot="CharacterLegsSlot", keybind="GEARRACK_USE_LEGS_ITEM", INVTYPE_LEGS=1 },
	[8] = { name=INVTYPE_FEET, paperdoll_slot="CharacterFeetSlot", keybind="GEARRACK_USE_FEET_ITEM", INVTYPE_FEET=1 },
	[9] = { name=INVTYPE_WRIST, paperdoll_slot="CharacterWristSlot", keybind="GEARRACK_USE_WRIST_ITEM", INVTYPE_WRIST=1 },
	[10]= { name=INVTYPE_HAND, paperdoll_slot="CharacterHandsSlot", keybind="GEARRACK_USE_HANDS_ITEM", INVTYPE_HAND=1 },
	[11]= { name=INVTYPE_FINGER, paperdoll_slot="CharacterFinger0Slot", keybind="GEARRACK_USE_TOP_FINGER_ITEM", INVTYPE_FINGER=1 },
	[12]= { name=INVTYPE_FINGER, paperdoll_slot="CharacterFinger1Slot", keybind="GEARRACK_USE_BOTTOM_FINGER_ITEM", INVTYPE_FINGER=1 },
	[13]= { name=INVTYPE_TRINKET, paperdoll_slot="CharacterTrinket0Slot", ignore_soulbound=1, keybind="GEARRACK_USE_TOP_TRINKET_ITEM", INVTYPE_TRINKET=1 },
	[14]= { name=INVTYPE_TRINKET, paperdoll_slot="CharacterTrinket1Slot", ignore_soulbound=1, keybind="GEARRACK_USE_BOTTOM_TRINKET_ITEM", INVTYPE_TRINKET=1 },
	[15]= { name=INVTYPE_CLOAK, paperdoll_slot="CharacterBackSlot", keybind="GEARRACK_USE_BACK_ITEM", INVTYPE_CLOAK=1 },
	[16]= { name=INVTYPE_WEAPONMAINHAND, paperdoll_slot="CharacterMainHandSlot", keybind="GEARRACK_USE_MAIN_HAND_ITEM", swappable=1, INVTYPE_WEAPONMAINHAND=1, INVTYPE_2HWEAPON=1, INVTYPE_WEAPON=1 },
	[17]= { name=INVTYPE_WEAPONOFFHAND, paperdoll_slot="CharacterSecondaryHandSlot", keybind="GEARRACK_USE_OFF_HAND_ITEM", swappable=1, INVTYPE_WEAPONOFFHAND=1, INVTYPE_SHIELD=1, INVTYPE_HOLDABLE=1, INVTYPE_WEAPON=1 },
	[18]= { name=INVTYPE_RANGED, paperdoll_slot="CharacterRangedSlot", keybind="GEARRACK_USE_RANGE_ITEM", swappable=1, INVTYPE_RANGED=1, INVTYPE_RANGEDRIGHT=1, INVTYPE_THROWN=1, INVTYPE_RELIC=1 },
	[19]= { name=INVTYPE_TABARD, paperdoll_slot="CharacterTabardSlot", ignore_soulbound=1, INVTYPE_TABARD=1 }
}

-- returns info depending on current docking. ie: dock_info("xoff")
local function dock_info(which)

	local stats = GearRack.DockStats[GearRackUI.MainDock..GearRackUI.MenuDock]
	return stats and stats[which] or 0
end

-- returns info depending on where the window is currently
-- since frame scales and positions can be nil at the most inconvenient times, it approximates
-- its corner based on settings and makes no assumptions that even UIParent exists
-- no argument : return corner window is in
-- "LEFTRIGHT" : return "LEFT" or "RIGHT"
-- "TOPBOTTOM" : return "TOP" or "BOTTOM"
local function corner_info(which)

	local length,cx,cy,xpoint,ypoint
	local vertside,horzside = "TOP","LEFT"
	local info

	if #GearRackDB.bars[user].Bar>0 then
		length = #GearRackDB.bars[user].Bar*40 + 32
		if GearRackDB.bars[user].MainOrient=="HORIZONTAL" then
			cx = length
			cy = 55
		else
			cx = 55
			cy = length
		end
		xpoint = cx/2+(GearRackDB.bars[user].XPos*GearRackDB.bars[user].MainScale)
		ypoint = (GearRackDB.bars[user].YPos*GearRackDB.bars[user].MainScale)-cy/2

		if xpoint<(UIParent and UIParent:GetWidth()/2 or 512) then
			horzside = "LEFT"
		else
			horzside = "RIGHT"
		end

		if ypoint<(UIParent and UIParent:GetHeight()/2 or 386) then
			vertside = "BOTTOM"
		else
			vertside = "TOP"
		end
	end

	if which=="LEFTRIGHT" then
		info = horzside
	elseif which=="TOPBOTTOM" then
		info = vertside
	else
		info = vertside..horzside
	end

	return info

end

local inv_dock = {
	[0]  = { maindock="BOTTOMLEFT", menudock="TOPLEFT" },
	[1]  = { maindock="TOPLEFT", menudock="TOPRIGHT" },
	[2]  = { maindock="TOPLEFT", menudock="TOPRIGHT" },
	[3]  = { maindock="TOPLEFT", menudock="TOPRIGHT" },
	[4]  = { maindock="TOPLEFT", menudock="TOPRIGHT" },
	[5]  = { maindock="TOPLEFT", menudock="TOPRIGHT" },
	[6]  = { maindock="TOPRIGHT", menudock="TOPLEFT" },
	[7]  = { maindock="TOPRIGHT", menudock="TOPLEFT" },
	[8]  = { maindock="TOPRIGHT", menudock="TOPLEFT" },
	[9]  = { maindock="TOPLEFT", menudock="TOPRIGHT" },
	[10]  = { maindock="TOPRIGHT", menudock="TOPLEFT" },
	[11]  = { maindock="TOPRIGHT", menudock="TOPLEFT" },
	[12]  = { maindock="TOPRIGHT", menudock="TOPLEFT" },
	[13]  = { maindock="TOPRIGHT", menudock="TOPLEFT" },
	[14]  = { maindock="TOPRIGHT", menudock="TOPLEFT" },
	[15] = { maindock="TOPLEFT", menudock="TOPRIGHT" },
	[16] = { maindock="BOTTOMLEFT", menudock="TOPLEFT" },
	[17] = { maindock="BOTTOMLEFT", menudock="TOPLEFT" },
	[18] = { maindock="BOTTOMLEFT", menudock="TOPLEFT" },
	[19] = { maindock="TOPLEFT", menudock="TOPRIGHT" }
}

-- places the menu against the invslot
-- setframe = true when docking to set frame
function GearRackUI_DockMenu(invslot,relativeTo)

	local attachTo = ((not relativeTo) and "GearRackUIInv"..invslot) or (relativeTo=="SET" and "GearRackUI_Sets_Inv"..invslot) or (relativeTo=="MINIMAP" and "GearRackMinimapButton") or GearRackUI.Indexes[invslot].paperdoll_slot
	local noflip = GearRackDB.settings.FlipMenu=="OFF"
	local corner=corner_info()
	local mainorient = GearRackDB.bars[user].MainOrient
	local ynudge -- amount if any to nudge the y offset

	GearRackUI.MenuDockedTo = relativeTo

	if relativeTo=="MINIMAP" then
		if (GearRackMinimapButton:GetTop() or 0)<(UIParent:GetHeight() or 0)/2 then
			GearRackUI.MainDock = "TOPLEFT"
			GearRackUI.MenuDock = "BOTTOMLEFT"
			ynudge = -12
		else
			GearRackUI.MainDock = "BOTTOMRIGHT"
			GearRackUI.MenuDock = "TOPRIGHT"
			ynudge = 12
		end
	elseif mainorient=="HORIZONTAL" then
		if corner=="BOTTOMLEFT" then
			GearRackUI.MainDock = noflip and "TOPLEFT" or "BOTTOMLEFT"
			GearRackUI.MenuDock = noflip and "BOTTOMLEFT" or "TOPLEFT"
		elseif corner=="BOTTOMRIGHT" then
			GearRackUI.MainDock = noflip and "TOPRIGHT" or "BOTTOMRIGHT"
			GearRackUI.MenuDock = noflip and "BOTTOMRIGHT" or "TOPRIGHT"
		elseif corner=="TOPLEFT" then
			GearRackUI.MainDock = noflip and "BOTTOMLEFT" or "TOPLEFT"
			GearRackUI.MenuDock = noflip and "TOPLEFT" or "BOTTOMLEFT"
		else -- "TOPRIGHT"
			GearRackUI.MainDock = noflip and "BOTTOMRIGHT" or "TOPRIGHT"
			GearRackUI.MenuDock = noflip and "TOPRIGHT" or "BOTTOMRIGHT"
		end
	else
		if corner=="BOTTOMLEFT" then
			GearRackUI.MainDock = noflip and "BOTTOMRIGHT" or "BOTTOMLEFT"
			GearRackUI.MenuDock = noflip and "BOTTOMLEFT" or "BOTTOMRIGHT"
		elseif corner=="BOTTOMRIGHT" then
			GearRackUI.MainDock = noflip and "BOTTOMLEFT" or "BOTTOMRIGHT"
			GearRackUI.MenuDock = noflip and "BOTTOMRIGHT" or "BOTTOMLEFT"
		elseif corner=="TOPLEFT" then
			GearRackUI.MainDock = noflip and "TOPRIGHT" or "TOPLEFT"
			GearRackUI.MenuDock = noflip and "TOPLEFT" or "TOPRIGHT"
		else -- "TOPRIGHT"
			GearRackUI.MainDock = noflip and "TOPLEFT" or "TOPRIGHT"
			GearRackUI.MenuDock = noflip and "TOPRIGHT" or "TOPLEFT"
		end
	end

	if relativeTo=="SET" then
		GearRackUI_MenuFrame:SetScale(GearRackUI_SetsFrame:GetScale())
		GearRackUI.MainDock = inv_dock[invslot].maindock
		GearRackUI.MenuDock = inv_dock[invslot].menudock
	elseif relativeTo=="CHARACTERSHEET" then
		GearRackUI_MenuFrame:SetScale(_G[GearRackUI.Indexes[1].paperdoll_slot]:GetScale())
		GearRackUI.MainDock = inv_dock[invslot].maindock
		GearRackUI.MenuDock = inv_dock[invslot].menudock
		if GearRackUI.MainDock == "TOPLEFT" then
			-- horizontal menus always go to right on character sheet
			GearRackUI.MainDock = "TOPRIGHT"
			GearRackUI.MenuDock = "TOPLEFT"
		end
	else
		GearRackUI_MenuFrame:SetScale(GearRackDB.bars[user].MainScale)
	end

	local xoffset = dock_info("mx")
	local yoffset = dock_info("my") + (ynudge or 0)
	if relativeTo == "CHARACTERSHEET" then
		if invslot == 16 or invslot == 17 or invslot == 18 or invslot == 0 then
			xoffset = -8
			yoffset = -2
		else
			xoffset = 0
			yoffset = 8
		end
	end

	GearRackUI_MenuFrame:ClearAllPoints()
	GearRackUI_MenuFrame:SetPoint(GearRackUI.MenuDock,attachTo,GearRackUI.MainDock,xoffset,yoffset)
end

-- CanUseItem checks proficiency, level, class/race, skill and other requirements.
local function player_can_wear(bag,slot,invslot,entry)
	local itemID = entry and entry.baseID or C_Container.GetContainerItemID(bag,slot)
	if not itemID or not C_PlayerInfo.CanUseItem(itemID) then return false end
	local itemType=entry and entry.equipLoc
	if not entry then _,_,_,itemType=GearRackEngine.GetItemInfo(bag,slot) end
	-- ClassicAPI reads the learned Dual Wield spell, so level and server rules apply.
	return not (itemType=="INVTYPE_WEAPON" and invslot==17 and not CanDualWield())
end

-- the old central info gatherer, now a wrapper to GearRackEngine.GetItemInfo
local itemLocation = {}
local function get_item_info(bag,slot,entry)

	local texture,itemID,name,equipslot,soulbound,count,quality

	if bag==20 then
		-- if querying set slot, return current set texture and name
		name = GearRackEngine.CurrentSet()
		texture = "Interface\\AddOns\\GearRack\\media\\GearRack-Icon.tga"
		if name and GearRackDB.sets[user].Sets[name] and not string.find(name,"^GearRackUI") and not string.find(name,"^GearRackEngine-") then
			texture = GearRackDB.sets[user].Sets[name].icon
		else
			name = nil
		end
		return texture,name
	end

	if entry then
		texture,itemID,name,equipslot,quality=entry.texture,entry.id,entry.name,entry.equipLoc,entry.quality
	else texture,itemID,name,equipslot,quality = GearRackEngine.GetItemInfo(bag,slot) end
	if slot then
		_,count = GetContainerItemInfo(bag,slot)
	end
	if GearRackDB.settings.Soulbound=="ON" and name then
		-- Keep the existing filter's quest/conjured exceptions.
		-- flags is ItemStats metadata, not the item's instance flag word.
		local location = itemLocation
		location.bagID, location.slotIndex = slot and bag, slot
		location.equipmentSlotIndex = not slot and bag or nil
		local data = C_Item.GetItemData(location)
		soulbound = C_Item.IsBound(location)
			or (data and (data.bindType==4 or bit.band(data.flags,2)~=0))
	end

	return texture,itemID,name,equipslot,soulbound,count,quality
end

local function cursor_empty()
	return GetCursorInfo()==nil
end

-- updates cooldown spinners in the menu
local function update_menu_cooldowns()

	local start, duration, enable

	if GearRackUI.InvOpen then
		for i=1,GearRackUI.NumberOfItems do
			if GearRackUI.BaggedItems[i].bag then
				start, duration, enable = GetContainerItemCooldown(GearRackUI.BaggedItems[i].bag,GearRackUI.BaggedItems[i].slot)
				CooldownFrame_SetTimer(_G["GearRackUIMenu"..i.."Cooldown"], start, duration, enable)
			else
				_G["GearRackUIMenu"..i.."Time"]:SetText("")
			end
		end
	end
end

-- updates cooldown spinners in the main bar
local function update_inv_cooldowns()

	local start, duration, enable

	if #GearRackDB.bars[user].Bar>0 then
		for i=1,#GearRackDB.bars[user].Bar do
			start, duration, enable = GearRack.GetInventoryCooldown(GearRackDB.bars[user].Bar[i])
			CooldownFrame_SetTimer(_G["GearRackUIInv"..GearRackDB.bars[user].Bar[i].."Cooldown"], start, duration, enable)
		end
	end

	update_menu_cooldowns()
end

-- call this when window has changed and cooldowns need redrawn
local function cooldowns_need_updating()
	GearRackEngine.StartTimer("CooldownUpdate",.25)
	GearRackUI.CooldownsNeedUpdating = true
end

local function populate_baggeditems(idx,bag,slot,name,texture,id,quality,guid)

	if not GearRackUI.BaggedItems[idx] then
		GearRackUI.BaggedItems[idx] = {}
	end
	GearRackUI.BaggedItems[idx].bag = bag
	GearRackUI.BaggedItems[idx].slot = slot
	GearRackUI.BaggedItems[idx].name = name
	GearRackUI.BaggedItems[idx].texture = texture
	GearRackUI.BaggedItems[idx].id = id
	GearRackUI.BaggedItems[idx].quality = quality
	GearRackUI.BaggedItems[idx].guid = guid
end

-- to minimize garbage creation, tables are manipulated by copying values instead of tables
local function copy_baggeditems(source,dest)

	if not GearRackUI.BaggedItems[dest] then
		GearRackUI.BaggedItems[dest] = {}
	end
	GearRackUI.BaggedItems[dest].bag = GearRackUI.BaggedItems[source].bag
	GearRackUI.BaggedItems[dest].slot = GearRackUI.BaggedItems[source].slot
	GearRackUI.BaggedItems[dest].name = GearRackUI.BaggedItems[source].name
	GearRackUI.BaggedItems[dest].texture = GearRackUI.BaggedItems[source].texture
	GearRackUI.BaggedItems[dest].id = GearRackUI.BaggedItems[source].id
	GearRackUI.BaggedItems[dest].quality = GearRackUI.BaggedItems[source].quality
	GearRackUI.BaggedItems[dest].guid = GearRackUI.BaggedItems[source].guid
end

-- sorts menu up to stop_point, which is idx+1 usually (sort uses stop_point as a temp spot for swapping)
local function sort_menu(stop_point)

	local done=false

	if stop_point>2 then
		while not done do
			done = true
			for i=1,stop_point-2 do
				if GearRackUI.BaggedItems[i].name > GearRackUI.BaggedItems[i+1].name then
					copy_baggeditems(i,stop_point)
					copy_baggeditems(i+1,i)
					copy_baggeditems(stop_point,i+1)

					done = false
				end
			end
		end
	end

end

function GearRackUI_CurrentSet()
	return GearRackEngine.CurrentSet()
end

-- builds a menu outward from invslot (0-19)
-- setframe = true if this is to dock to the set frame
local cacheInvalid = true
local menuCache = {}
local idx = 1
function GearRackUI_BuildMenu(invslot,relativeTo)
	local carried=invslot<20 and GearRack.GetCarriedItems()
	if carried and menuCache.inventoryRevision~=GearRack.inventoryRevision then
		cacheInvalid=true;menuCache.inventoryRevision=GearRack.inventoryRevision
	end
	local altDown = IsAltKeyDown() and true or false
	if menuCache.slot ~= invslot or menuCache.origin ~= relativeTo
		or menuCache.altDown ~= altDown or menuCache.bankOpen ~= GearRackUI.BankIsOpen
		or menuCache.soulbound ~= GearRackDB.settings.Soulbound
		or menuCache.allowHidden ~= GearRackDB.settings.AllowHidden
		or menuCache.showEmpty ~= GearRackDB.settings.ShowEmpty
		or menuCache.rightClick ~= GearRackDB.settings.RightClick then
		cacheInvalid = true
		menuCache.slot = invslot
		menuCache.origin = relativeTo
		menuCache.altDown = altDown
		menuCache.bankOpen = GearRackUI.BankIsOpen
		menuCache.soulbound = GearRackDB.settings.Soulbound
		menuCache.allowHidden = GearRackDB.settings.AllowHidden
		menuCache.showEmpty = GearRackDB.settings.ShowEmpty
		menuCache.rightClick = GearRackDB.settings.RightClick
	end

	local item,itemID,texture,name,equipslot,soulbound,found,count,quality

	if invslot==0 and cacheInvalid then
		-- if this is an ammo slot, clear totals
		for i in pairs(GearRackUI.AmmoCounts) do
			GearRackUI.AmmoCounts[i] = 0
		end
	end

	if invslot<20 then
		-- the following block is very expensive, do it when cache is invalid
		if cacheInvalid then
			idx = 1
			local function include(bag,slot,entry)
				if entry and not GearRackUI.Indexes[invslot][entry.equipLoc] then return end
				texture,itemID,name,equipslot,soulbound,count,quality = get_item_info(bag,slot,entry)
				soulbound = soulbound or GearRackUI.Indexes[invslot].ignore_soulbound
				if not equipslot or not GearRackUI.Indexes[invslot][equipslot]
					or not (soulbound or GearRackDB.settings.Soulbound=="OFF") then return end
				if GearRackDB.settings.AllowHidden=="ON" and GearRackDB.bars[user].Ignore[name] and not IsAltKeyDown() then return end
				if not player_can_wear(bag,slot,invslot,entry) then return end
				if invslot==0 and count then
					GearRackUI.AmmoCounts[name]=(GearRackUI.AmmoCounts[name] or 0)+count
					for k=1,idx-1 do if GearRackUI.BaggedItems[k].name==name then return end end
				end
				local guid=entry and entry.guid or GearRack.BagGUID(bag,slot)
				populate_baggeditems(idx,bag,slot,name,texture,itemID,quality,guid)
				idx=idx+1
			end
			for _,entry in ipairs(carried) do include(entry.bag,entry.slot,entry) end
			-- Bank discovery remains in the bank owner; carried bags are already cached.
			if GearRackUI.BankIsOpen then
				for _,bag in ipairs(GearRackUI.BankSlots) do
					for slot=1,GetContainerNumSlots(bag) do include(bag,slot) end
				end
			end
			sort_menu(idx)

			if GearRackDB.settings.ShowEmpty=="ON" and GetInventoryItemLink("player",invslot) and (relativeTo=="CHARACTERSHEET" or not (GearRackDB.settings.RightClick=="ON" and (invslot==13 or invslot==14))) then
				-- add an empty slot to the menu
				local _,id = GetInventorySlotInfo(string.gsub(GearRackUI.Indexes[invslot].paperdoll_slot,"Character",""))
				populate_baggeditems(idx,nil,nil,"(empty)",id)
				idx = idx + 1
			end
			cacheInvalid = false
		end
	else
		idx = 1
		-- this is a menu for sets
		-- go through sets and gather them into .BaggedItems
		for i in pairs(GearRackDB.sets[user].Sets) do
			if not string.find(i,"^GearRackUI") and not string.find(i,"^GearRackEngine-") and (not GearRackDB.sets[user].Sets[i].hide or IsAltKeyDown()) then
				populate_baggeditems(idx,nil,nil,i,GearRackDB.sets[user].Sets[i].icon)
				idx = idx + 1
			end
		end
		sort_menu(idx)
	end

	GearRackUI.NumberOfItems = idx-1

	if GearRackUI.NumberOfItems<1 then
		-- user has no bagged items for this type
		GearRackUI_MenuFrame:Hide()
		return
	end

	local mainorient = GearRackDB.bars[user].MainOrient

	if relativeTo=="SET" or relativeTo=="CHARACTERSHEET" then
		-- if displaying to a set, then
		mainorient = "VERTICAL"
		if invslot==0 or invslot==16 or invslot==17 or invslot==18 then
			mainorient = "HORIZONTAL"
		end
	elseif relativeTo=="MINIMAP" then
		mainorient = "HORIZONTAL"
	end
	GearRackUI_DockMenu(invslot,relativeTo)

	for i=1,#GearRackDB.bars[user].Bar do
		if invslot~=GearRackDB.bars[user].Bar[i] then
			_G["GearRackUIInv"..GearRackDB.bars[user].Bar[i]]:UnlockHighlight()
		else
			_G["GearRackUIInv"..GearRackDB.bars[user].Bar[i]]:LockHighlight()
		end
	end

	-- display items outward from docking point
	local col,row,xpos,ypos = 0,0,dock_info("xstart"),dock_info("ystart")
	local max_cols = 1

	if GearRackUI.NumberOfItems>24 then
		max_cols = 5
	elseif GearRackUI.NumberOfItems>18 then
		max_cols = 4
	elseif GearRackUI.NumberOfItems>12 then
		max_cols = 3
	elseif GearRackUI.NumberOfItems>4 then
		max_cols = 2
	end

	for i=1,GearRackUI.NumberOfItems do
		local item = _G["GearRackUIMenu"..i]
		if not item then
			item = CreateFrame("CheckButton", "GearRackUIMenu"..i, GearRackUI_MenuFrame, "GearRackUIMenuTemplate")
			item:SetID(i)
			GearRackUI_SetCooldownFont("GearRackUIMenu"..i)
			_G["GearRackUIMenu"..i.."Border"]:SetVertexColor(.15,.25,1,1)
			_G["GearRackUIMenu"..i.."Border"]:Hide()
			GearRack.AddSetMacroHandle(item)
			GearRackUI.MaxItems = GearRackUI.MaxItems + 1
		end
		local icon = _G["GearRackUIMenu"..i.."Icon"]
		item:SetPoint("TOPLEFT","GearRackUI_MenuFrame",GearRackUI.MenuDock,xpos,ypos)
		icon:SetTexture(GearRackUI.BaggedItems[i].texture)
		-- grey menu item if it's on the ignore list (ALT key is down if it made it to BaggedItems)
		if GearRackDB.settings.AllowHidden=="ON" and (GearRackDB.bars[user].Ignore[GearRackUI.BaggedItems[i].name] or (GearRackDB.sets[user].Sets[GearRackUI.BaggedItems[i].name] and GearRackDB.sets[user].Sets[GearRackUI.BaggedItems[i].name].hide)) then
			SetDesaturation(icon,1)
		else
			SetDesaturation(icon,nil)
		end

		if (mainorient=="HORIZONTAL" and GearRackDB.settings.RotateMenu=="OFF") or (mainorient=="VERTICAL" and GearRackDB.settings.RotateMenu=="ON") then
			xpos = xpos + dock_info("xdir")*40
			col = col + 1
			if col==max_cols then
				xpos = dock_info("xstart")
				col = 0
				ypos = ypos + dock_info("ydir")*40
				row = row + 1
			end
			item:Show()
		else
			ypos = ypos + dock_info("ydir")*40
			col = col + 1
			if col==max_cols then
				ypos = dock_info("ystart")
				col = 0
				xpos = xpos + dock_info("xdir")*40
				row = row + 1
			end
			item:Show()
		end
	end
	for i=(GearRackUI.NumberOfItems+1),GearRackUI.MaxItems do
		local mBtn = _G["GearRackUIMenu"..i]
		if mBtn then
			mBtn:Hide()
			if mBtn.enchantOverlay then
				mBtn.enchantOverlay:Hide()
			end
		end
	end
	if col==0 then
		row = row-1
	end

	if (mainorient=="HORIZONTAL" and GearRackDB.settings.RotateMenu=="OFF") or (mainorient=="VERTICAL" and GearRackDB.settings.RotateMenu=="ON") then
		GearRackUI_MenuFrame:SetWidth(12+(max_cols*40))
		GearRackUI_MenuFrame:SetHeight(12+((row+1)*40))
	else
		GearRackUI_MenuFrame:SetWidth(12+((row+1)*40))
		GearRackUI_MenuFrame:SetHeight(12+(max_cols*40))
	end

	-- apply slot-dependant overlays, ammo count, set name and key bindings
	if invslot==0 then -- if this is an ammo slot, show counts
		for i=1,GearRackUI.NumberOfItems do
			if GearRackUI.AmmoCounts[GearRackUI.BaggedItems[i].name] then
				_G["GearRackUIMenu"..i.."Count"]:SetText(GearRackUI.AmmoCounts[GearRackUI.BaggedItems[i].name])
			end
			local menuBtn = _G["GearRackUIMenu"..i]
			GearRack.SetQualityBorder(menuBtn, GearRackUI.BaggedItems[i].quality, 16)
			if menuBtn.enchantOverlay then
				menuBtn.enchantOverlay:Hide()
			end
		end
	elseif invslot==20 then -- if this is a set slot, show names and bindings
		for i=1,GearRackUI.NumberOfItems do
			name = GearRackUI.BaggedItems[i].name
			if GearRackUI.BankIsOpen and GearRackEngine.SetHasBanked(name) then
				_G["GearRackUIMenu"..i.."Border"]:Show()
				_G["GearRackUIMenu"..i.."Icon"]:SetVertexColor(.5,.5,.5)
			else
				_G["GearRackUIMenu"..i.."Border"]:Hide()
				_G["GearRackUIMenu"..i.."Icon"]:SetVertexColor(1,1,1)
			end
			-- Set icons carry no item quality or enchant.
			local menuBtn = _G["GearRackUIMenu"..i]
			GearRack.SetQualityBorder(menuBtn, nil)
			if menuBtn.enchantOverlay then
				menuBtn.enchantOverlay:Hide()
			end

			item = _G["GearRackUIMenu"..i.."Name"]
			if GearRackDB.settings.SetLabels=="ON" then
				item:SetText(name)
				item:Show()
			else
				item:Hide()
			end
			item = _G["GearRackUIMenu"..i.."HotKey"]
			if GearRackDB.sets[user].Sets[name].key and GearRackDB.settings.Bindings=="ON" then
				local _,_,j,k = string.find(GearRackDB.sets[user].Sets[name].key or "","(.).+(-.)")
				item:SetText((j or "")..(k or ""))
				item:Show()
			else
				item:Hide()
			end
		end
	else -- normal slot (1-19)
		for i=1,GearRackUI.NumberOfItems do
			_G["GearRackUIMenu"..i.."Name"]:SetText("")
			_G["GearRackUIMenu"..i.."Count"]:SetText("")
			_G["GearRackUIMenu"..i.."HotKey"]:SetText("")

			local itemBag = GearRackUI.BaggedItems[i].bag
			if itemBag and (itemBag == -1 or (itemBag >= 5 and itemBag <= 10)) then
				_G["GearRackUIMenu"..i.."Border"]:Show()
				_G["GearRackUIMenu"..i.."Icon"]:SetVertexColor(.5,.5,.5)
			else
				_G["GearRackUIMenu"..i.."Border"]:Hide()
				_G["GearRackUIMenu"..i.."Icon"]:SetVertexColor(1,1,1)
			end

			-- quality border & weapon enchant overlay
			local menuBtn = _G["GearRackUIMenu"..i]
			GearRack.SetQualityBorder(menuBtn, GearRackUI.BaggedItems[i].quality, 16)
			if invslot == 16 or invslot == 17 then
				update_menu_weapon_enchant(menuBtn, GearRackUI.BaggedItems[i])
			elseif menuBtn.enchantOverlay then
				menuBtn.enchantOverlay:Hide()
			end
		end
	end

	GearRackUI.InvOpen = invslot
	GearRackUI_MenuFrame:Show()
	update_menu_cooldowns()
	GearRackEngine.StartTimer("CooldownUpdate",0) -- immediate cooldown update
	GearRackEngine.StartTimer("MenuFrame")
end

-- for use with main/menu frames with UIParent parent when relocated by the mod, to register for layout-cache.txt
local function really_setpoint(frame,point,relativeTo,relativePoint,xoff,yoff)
	frame:SetPoint(point,relativeTo,relativePoint,xoff,yoff)
	GearRackDB.bars[user].XPos = xoff
	GearRackDB.bars[user].YPos = yoff
end

-- draws the inventory bar
local function draw_inv()

	local oldx = GearRackUI_InvFrame:GetLeft() or GearRackDB.bars[user].XPos
	local oldy = GearRackUI_InvFrame:GetTop() or GearRackDB.bars[user].YPos
	local oldcx = GearRackUI_InvFrame:GetWidth() or 0
	local oldcy = GearRackUI_InvFrame:GetHeight() or 0
	local bar = GearRackDB.bars[user].Bar

	if not oldx or not oldy then
		return -- frame isn't fully defined yet, leave now
	end

	-- for a left-to-right horizontal configuration
	local cx,cy,item,xspacer,yspacer = 56,56
	local xdir,ydir,corner,cornerTo,cornerStart,xdirStart,ydirStart,xadd,yadd
	if GearRackDB.bars[user].MainOrient=="HORIZONTAL" then
		-- horizontal from left to right
		xdir,ydir,corner,cornerTo,cornerStart,xdirStart,ydirStart,xadd,yadd = 4,0,"TOPRIGHT","TOPLEFT","TOPLEFT",10,-10,40,0

		if GearRackDB.settings.FlipBar=="ON" then
			-- horizontal from right to left
			xdir,ydir,corner,cornerTo,cornerStart,xdirStart,ydirStart,xadd,yadd = -4,0,"TOPLEFT","TOPRIGHT","TOPRIGHT",-10,-10,-40,0
		end

	else
		-- vertical from top to bottom
		xdir,ydir,corner,cornerTo,cornerStart,xdirStart,ydirStart,xadd,yadd = 0,-4,"BOTTOMLEFT","TOPLEFT","TOPLEFT",10,-10,0,40

		if GearRackDB.settings.FlipBar=="ON" then
			-- vertical from bottom to top
			xdir,ydir,corner,cornerTo,cornerStart,xdirStart,ydirStart,xadd,yadd = 0,4,"TOPLEFT","BOTTOMLEFT","BOTTOMLEFT",10,10,0,-40
		end
	end

	for i=0,20 do
		local slotBtn = _G["GearRackUIInv"..i]
		if slotBtn then
			slotBtn:Hide()
			if slotBtn.enchantOverlay then
				slotBtn.enchantOverlay:Hide()
			end
		end
	end
	GearRackUI.TrinketsPaired = false -- changes to true if two trinkets are beside each other

	if #bar>0 then
		item = _G["GearRackUIInv"..bar[1]]
		item:ClearAllPoints()
		item:SetPoint(cornerStart,"GearRackUI_InvFrame",cornerStart,xdirStart,ydirStart)
		_G["GearRackUIInv"..bar[1].."Icon"]:SetTexture(get_item_info(bar[1]))
		apply_inv_quality_border(item, bar[1])
		update_equipped_enchant(bar[1], item)
		item:Show()
		if GearRackDB.settings.RightClick=="ON" and (bar[1]==13 and bar[2]==14) then
			GearRackUI.TrinketsPaired = true
		end
		for i=2,#bar do
			xspacer,yspacer = 0,0
			if GearRackDB.settings.RightClick=="ON" and ((bar[i]==13 and bar[i+1] and bar[i+1]==14) or
				(bar[i-1]==14 and bar[i-2] and bar[i-2]==13)) then
				GearRackUI.TrinketsPaired = true
			end
			if GearRackDB.bars[user].Spaces[bar[i-1]] then
				xspacer = xdir*2
				yspacer = ydir*2
			end
			item = _G["GearRackUIInv"..bar[i]]
			item:ClearAllPoints()
			item:SetPoint(cornerTo,"GearRackUIInv"..bar[i-1],corner,xdir+xspacer,ydir+yspacer)
			_G["GearRackUIInv"..bar[i].."Icon"]:SetTexture(get_item_info(bar[i]))
			apply_inv_quality_border(item, bar[i])
			update_equipped_enchant(bar[i], item)
			item:Show()
			cx = cx + math.abs(xadd) + math.abs(xspacer)
			cy = cy + math.abs(yadd) + math.abs(yspacer) -- was minus yspacer
		end
		GearRackUI_InvFrame:SetWidth(cx)
		GearRackUI_InvFrame:SetHeight(cy)

		if GearRackDB.settings.FlipBar=="ON" and oldcx>32 and oldcy>32 then
			-- if bar size changed (after being drawn before), and we're flipped, we need to shift it over
			GearRackUI_InvFrame:ClearAllPoints()
			if GearRackDB.bars[user].MainOrient=="HORIZONTAL" then
				oldx = oldx + (oldcx-cx)
			else
				oldy = oldy + (cy-oldcy)
			end
			really_setpoint(GearRackUI_InvFrame,"TOPLEFT","UIParent","BOTTOMLEFT",oldx,oldy)
		end

		if GearRackDB.bars[user].Visible~="OFF" then
			GearRackUI_InvFrame:Show()
		end
		GearRackUI.CooldownsNeedUpdating = true
		GearRackEngine.StartTimer("CooldownUpdate",0)

		if GearRackDB.settings.SetLabels=="ON" then
			local currentset = GearRackEngine.CurrentSet()
			if currentset and GearRackDB.sets[user].Sets[currentset] then
				GearRackUIInv20Name:SetText(currentset)
			else
				GearRackUIInv20Name:SetText(GearRackUIText.EMPTYSET)
			end
		else
			GearRackUIInv20Name:SetText("")
		end
	else
		GearRackDB.bars[user].Visible="OFF"
		GearRackUI_InvFrame:Hide()
	end
end

local function unlocked()
	return GearRackDB.bars[user].Locked~="ON"
end

-- sets window lock "ON" or "OFF"
local function set_lock(arg1)

	GearRackDB.bars[user].Locked = arg1

	if arg1=="ON" then
		GearRackUI_InvFrame:SetBackdropColor(0,0,0,0)
		GearRackUI_InvFrame:SetBackdropBorderColor(0,0,0,0)
		GearRackUI_InvFrame_Resize:Hide()
		GearRackUI_Control_Rotate:SetAlpha(.4)
		GearRackUI_Control_Rotate:Disable()
		-- The controls stay while Alt is held, then hide.
		GearRackEngine.StartTimer("ControlFrame")
	else
		GearRackUI_InvFrame:SetBackdropColor(1,1,1,1)
		GearRackUI_InvFrame:SetBackdropBorderColor(1,1,1,1)
		GearRackUI_InvFrame_Resize:Show()
		GearRackUI_Control_Rotate:SetAlpha(1)
		GearRackUI_Control_Rotate:Enable()
		GearRackUI_ControlFrame:Show()
	end
end

-- called at startup, UPDATE_BINDINGS and option change to show/hide key bindings
local function update_keybindings()

	local text

	-- update bindings for inventory slots
	for i=0,19 do
		if GearRackUI.Indexes[i].keybind and GearRackDB.settings.Bindings=="ON" then
			text = GetBindingKey(GearRackUI.Indexes[i].keybind)
			if not text and (i==13 or i==14) then
				text = GetBindingKey(i==13 and "GEARRACK_USE_TOP_TRINKET_ITEM" or "GEARRACK_USE_BOTTOM_TRINKET_ITEM")
			end
			_G["GearRackUIInv"..i.."HotKey"]:SetText(text and GetBindingText(text,"KEY_",1) or "")
		else
			_G["GearRackUIInv"..i.."HotKey"]:SetText("")
		end
	end

	-- update bindings for items on the rack
	GearRackUI_AgreeOnKeyBindings()

end

local function move_control()

	GearRackUI_Control_Rotate:ClearAllPoints()
	GearRackUI_Control_Lock:ClearAllPoints()
	GearRackUI_Control_Options:ClearAllPoints()

	if GearRackDB.bars[user].MainOrient=="HORIZONTAL" then

		if GearRackDB.settings.FlipBar=="OFF" then
			GearRackUI_Control_Rotate:SetPoint("TOPLEFT","GearRackUI_InvFrame","TOPRIGHT",-2,-3)
		else
			GearRackUI_Control_Rotate:SetPoint("TOPRIGHT","GearRackUI_InvFrame","TOPLEFT",2,-3)
		end
		GearRackUI_Control_Lock:SetPoint("TOPLEFT","GearRackUI_Control_Rotate","BOTTOMLEFT")
		GearRackUI_Control_Options:SetPoint("TOPLEFT","GearRackUI_Control_Lock","BOTTOMLEFT")
	else
		if GearRackDB.settings.FlipBar=="OFF" then
			GearRackUI_Control_Rotate:SetPoint("BOTTOMLEFT","GearRackUI_InvFrame","TOPLEFT",3,-2)
		else
			GearRackUI_Control_Rotate:SetPoint("TOPLEFT","GearRackUI_InvFrame","BOTTOMLEFT",3,2)
		end
		GearRackUI_Control_Lock:SetPoint("TOPLEFT","GearRackUI_Control_Rotate","TOPRIGHT")
		GearRackUI_Control_Options:SetPoint("TOPLEFT","GearRackUI_Control_Lock","TOPRIGHT")
	end
end

local function move_icon()
    GearRack.RefreshMinimapButtons()
end

local function initialize_data()

	GearRack.NormalizeSavedData()

	-- create new user if one doesn't exist
	if not GearRackDB.bars[user] then
		GearRackDB.bars[user] = {} -- create new per-user setting
		GearRackDB.bars[user].Inv = {[16]=1,[17]=1,[18]=1,[20]=1} -- nil or 1, whether inv slot visible
		GearRackDB.bars[user].Bar = {16,17,18,20} -- 1-number of inventory bars on screen at once
		GearRackDB.bars[user].Spaces = {} -- nil or true, whether a space should appear after this slot
		GearRackDB.bars[user].Ignore = {}
		GearRackDB.bars[user].Events = {} -- list of items to ignore on bar
		for i in pairs(GearRackUIOpt_Defaults) do
			GearRackDB.bars[user][i] = GearRackUIOpt_Defaults[i]
		end
	end
	-- Old/manual numeric settings must not reach native frame setters unchanged.
	local profile = GearRackDB.bars[user]
	for _,key in ipairs({"Inv","Bar","Spaces","Ignore","Events"}) do
		if type(profile[key])~="table" then profile[key]={} end
	end
	for key,value in pairs(GearRackUIOpt_Defaults) do
		if profile[key]==nil then profile[key]=value end
	end
	for _, key in ipairs({"MainScale", "XPos", "YPos"}) do
		local value = tonumber(profile[key])
		if not value or value ~= value or value == math.huge or value == -math.huge or (key == "MainScale" and value <= 0) then
			value = GearRackUIOpt_Defaults[key]
		end
		profile[key] = value
	end
end

local function initialize_display()

	-- set scale and position to last saved setting
	GearRackUI_InvFrame:SetScale(GearRackDB.bars[user].MainScale or 1)
	GearRackUI_MenuFrame:SetScale(GearRackDB.bars[user].MainScale or 1)
	GearRackUI_InvFrame:ClearAllPoints()
	really_setpoint(GearRackUI_InvFrame,"TOPLEFT","UIParent","BOTTOMLEFT",GearRackDB.bars[user].XPos,GearRackDB.bars[user].YPos)
	set_lock(GearRackDB.bars[user].Locked)
	update_keybindings()

	GearRackUIInv0Count:SetText(CharacterAmmoSlotCount:IsShown() and CharacterAmmoSlotCount:GetText() or "")

	for i in pairs(GearRackUI.OptInfo) do
		if GearRackUI.OptInfo[i].type=="Check" and _G[i] then
			local item = _G[i.."Text"]
			item:SetText(GearRackUI.OptInfo[i].text)
			UI.Color(item,"text")
			if GearRackUI.OptInfo[i].info and GearRackDB.settings[GearRackUI.OptInfo[i].info]=="ON" then
				_G[i]:SetChecked(1)
			else
				_G[i]:SetChecked(0)
			end
		end
		if GearRackUI.OptInfo[i].type=="Label" then
			_G[i]:SetText(GearRackUI.OptInfo[i].text)
		end
	end

	if GearRackDB.bars[user].Visible=="OFF" then
		GearRackUI_InvFrame:Hide()
	end

	move_control() -- docks control buttons on edge of bar
	move_icon() -- moves minimap button


	GearRack.SetEscapable("GearRackUI_SetsFrame",true)

	GearRackUI_ChangeEventFont()

	draw_inv() -- construct the bar
	GearRackUI_SetAllCooldownFonts()
	GearRackEngine.StartTimer("CooldownUpdate")
end

-- Public redraw for the merged settings entry; keeps existing user positions.
function GearRackUI_RefreshBar() draw_inv() end

-- displays a quick tooltip note under the sets window
local function sets_message(msg)

	local tooltip = GearRackUI_Sets_Message

	tooltip:SetOwner(GearRackUI_SetsFrame, "ANCHOR_NONE")
	tooltip:SetPoint("TOP", "GearRackUI_SetsFrame", "BOTTOM", 0, 0)
	tooltip:AddLine(msg)
	tooltip:Show()
	tooltip:FadeOut()
end


--[[ Frame functions ]]--

function GearRackUI_OnLoad()

	-- hook for ALT+click of inventory slots (to add inventory slots to rack)
	oldGearRackUI_PaperDollItemSlotButton_OnClick = PaperDollItemSlotButton_OnClick
	PaperDollItemSlotButton_OnClick = newGearRackUI_PaperDollItemSlotButton_OnClick

	-- hook for ALT+click of character model (to add set slot to rack)
	oldGearRackUI_CharacterModelFrame_OnMouseUp = CharacterModelFrame_OnMouseUp
	CharacterModelFrame_OnMouseUp = newGearRackUI_CharacterModelFrame_OnMouseUp

	-- hook for mouseover of character sheet item slots (to display menu)
	oldGearRackUI_PaperDollItemSlotButton_OnEnter = PaperDollItemSlotButton_OnEnter
	PaperDollItemSlotButton_OnEnter = newGearRackUI_PaperDollItemSlotButton_OnEnter

	-- hook for character sheet hiding (to hide menu)
	oldGearRackUI_PaperDollFrame_OnHide = PaperDollFrame_OnHide
	PaperDollFrame_OnHide = newGearRackUI_PaperDollFrame_OnHide

	-- hook for character sheet showing (to refresh weapon enchant overlays)
	oldGearRackUI_PaperDollFrame_OnShow = PaperDollFrame_OnShow
	PaperDollFrame_OnShow = newGearRackUI_PaperDollFrame_OnShow

	hooksecurefunc("UseInventoryItem", GearRackUI.OnUseInventoryItem)
	hooksecurefunc("UseAction", GearRackUI.OnUseAction)

	GearRack_OriginalGossipTitleButton_OnClick = GossipTitleButton_OnClick
	GossipTitleButton_OnClick = GearRack_GossipTitleButton_OnClick

	this:RegisterEvent("PLAYER_LOGIN")
end

local function initialize_events(v1)

	GearRackUI_DisableAllEvents()

	-- A reset replaces every event with the included ones; sets keep their restore data.
	if v1 then
		GearRackDB.events = {}
		GearRackDB.eventsInitialized=nil
	end

	-- Fresh definitions are seeded once. User-edited scripts are never overwritten.
	if not GearRackDB.eventsInitialized then
		for name,definition in pairs(GearRackUI_DefaultEvents) do
			if not GearRackDB.events[name] then
				GearRackDB.events[name]={trigger=definition.trigger,delay=definition.delay,script=definition.script}
			end
		end
		GearRackDB.eventsInitialized=true
	end

	-- if an event is removed, remove the associated sets from the user
	for i in pairs(GearRackDB.bars) do
		if GearRackDB.bars[i].Events then
			for j in pairs(GearRackDB.bars[i].Events) do
				if not GearRackDB.events[j] then
					GearRackDB.bars[i].Events[j] = nil
				end
			end
		end
	end

	GearRackUI_Events_ScrollFrameScrollBar:SetValue(0)
	GearRackUI_Build_eventList()
	GearRackUI_EnableAllEvents()
end

-- One redraw per burst of changes: a pending redraw is kept, not restarted.
local function inventory_changed()
	cacheInvalid = true
	GearRackEngine.StartTimer("InvUpdate",nil,true)
end

function GearRackUI_OnEvent(ev)
	local f, a1, a2, a3 = GearRackUIFrame, arg1, arg2, arg3

	local dataChanged,bankChanged=GearRack.UIEvent(ev,a1,a2,a3)
	if GearRackEngine.BankTransfer and (ev=="BAG_UPDATE" or ev=="PLAYERBANKSLOTS_CHANGED") then
		GearRackEngine.ReconcileBankTransfer()
	end

	if ev=="UNIT_INVENTORY_CHANGED" then
		-- The ammo count is the one view that changes without a new item.
		if a1=="player" and (dataChanged or GearRackDB.bars[user].Inv[0]) then
			inventory_changed()
		end
	elseif ev=="PLAYER_AURAS_CHANGED" then
		GearRackUI_BuffsChanged()

	elseif ev=="UPDATE_BINDINGS" then
		update_keybindings()

	elseif ev=="BANKFRAME_OPENED" then
		GearRackEngine.BankOpened()
		inventory_changed()
	elseif ev=="PLAYERBANKSLOTS_CHANGED" then
		GearRackEngine.PopulateBank()
		inventory_changed()

	elseif ev=="BANKFRAME_CLOSED" then
		cacheInvalid = true
		GearRackEngine.BankClosed()

	elseif ev=="GET_ITEM_INFO_RECEIVED" then
		if dataChanged then
			if bankChanged then GearRackEngine.PopulateBank() end
			inventory_changed()
		end

	elseif ev=="BAG_UPDATE" then
		if dataChanged then
			if bankChanged then GearRackEngine.PopulateBank() end
			inventory_changed()
		end

	elseif ev=="PLAYER_LOGIN" then

		user = GearRack.CharacterKey()

		GearRack.NormalizeSavedData()
		GearRackEngine.Initialize()

		initialize_data()
		initialize_events()

		GearRackUI_InitializeKeyBindings() -- create key bindings for this user
		initialize_display()
		GearRack.Initialize()

		f:RegisterEvent("UNIT_INVENTORY_CHANGED")
		f:RegisterEvent("UPDATE_BINDINGS")
		f:RegisterEvent("BAG_UPDATE")
		f:RegisterEvent("GET_ITEM_INFO_RECEIVED")
		f:RegisterEvent("PLAYERBANKSLOTS_CHANGED")

		GearRackEngineFrame:RegisterEvent("PLAYER_REGEN_ENABLED") -- leaving combat
		GearRackEngineFrame:RegisterEvent("PLAYER_UNGHOST") -- leaving ghost
		GearRackEngineFrame:RegisterEvent("PLAYER_ALIVE") -- leaving death

		f:RegisterEvent("BANKFRAME_OPENED")
		f:RegisterEvent("BANKFRAME_CLOSED")

	end
end

-- Equipment commands routed by GearRack.SlashHandler.
function GearRackUI_SlashHandler(input)
	local command,argument=string.match(input,"^%s*(%S+)%s*(.-)%s*$")
	command=string.lower(command)
	if command=="equip" then
		GearRackUI_EquipSet(argument)
	elseif command=="toggle" then
		GearRackUI_ToggleSet(argument)
	elseif command=="scale" then
		if not tonumber(argument) then
			DEFAULT_CHAT_FRAME:AddMessage("GearRack: /gr scale 0.85 sets the bar's scale.")
		else
			GearRackUI.FrameToScale = GearRackUI_InvFrame
			GearRackUI_ScaleFrame(argument)
			GearRackDB.bars[user].MainScale = GearRackUI_InvFrame:GetScale()
			cooldowns_need_updating()
		end
	elseif command=="lock" then
		set_lock("ON")
	elseif command=="unlock" then
		set_lock("OFF")
	elseif string.lower(input)=="reset bar" then
		GearRackUI_Reset()
	else
		GearRackUI_ConfirmResetEvents()
	end
end

-- Resetting events deletes the player's own events, so it always asks first.
function GearRackUI_ConfirmResetEvents()
	StaticPopupDialogs["GEARRACK_RESETEVENTS"] = StaticPopupDialogs["GEARRACK_RESETEVENTS"] or {
		text = "Restore the included events? Your own events are deleted.",
		button1 = "Reset", button2 = "Cancel", showAlert = 1, timeout = 0, whileDead = 1, hideOnEscape = 1,
		OnAccept = function()
			initialize_events("reset")
			if GearRackUI_SetsFrame:IsVisible() then sets_message("Included events restored.") end
		end,
	}
	StaticPopup_Show("GEARRACK_RESETEVENTS")
end

--[[ Main bar add/remove functions ]]--

function GearRackUI_Reset()
	-- restore user settings to default (but keep bar contents)
	for i in pairs(GearRackUIOpt_Defaults) do
		GearRackDB.bars[user][i] = GearRackUIOpt_Defaults[i]
	end
	initialize_data()
	initialize_display()
	initialize_events()
	GearRackUI_SetsFrame:ClearAllPoints()
	GearRackUI_SetsFrame:SetPoint("CENTER","UIParent","CENTER")
end

local function remove_inv(id)
	_G["GearRackUIInv"..id]:Hide()
	GearRackDB.bars[user].Inv[id] = nil
	for i=1,#GearRackDB.bars[user].Bar do
		if GearRackDB.bars[user].Bar[i]==id then
			table.remove(GearRackDB.bars[user].Bar,i)
		end
	end
	draw_inv()
end

--[[ Hooked functions ]]--

-- Observe item use without replacing the client's UseAction.
function GearRackUI.OnUseAction(slot, checkCursor, onSelf)
	local actionType, actionID = GetActionInfo(slot)
	if actionType~="item" and actionType~="macro" then return end
	if not IsEquippedAction(slot) or not cursor_empty() then return end
	if actionType=="macro" then
		local _,link = GetMacroItem(actionID)
		actionID = link and tonumber(string.match(link,"item:(%d+)"))
	end
	if not actionID then return end
	for i=1,19 do
		if GetInventoryItemID("player",i)==actionID then
			if GetActionCooldown(slot)==0 then GearRackUI_ReactUseInventoryItem(i) end
			return
		end
	end
end

-- Inv slots are added by ALT+clicking the paper doll
function newGearRackUI_PaperDollItemSlotButton_OnClick(button, ignoreShift)

	if IsAltKeyDown() then
		local item = string.gsub(tostring(this:GetName()),"Character","")
		local id,texture = GetInventorySlotInfo(item)

		if GearRackDB.bars[user].Inv[id] then
			remove_inv(id)
		else
			GearRackDB.bars[user].Visible="ON"
			GearRackDB.bars[user].Inv[id] = 1
			_G["GearRackUIInv"..id.."Icon"]:SetTexture(texture)
			table.insert(GearRackDB.bars[user].Bar,id)
			draw_inv()
		end
	else
		oldGearRackUI_PaperDollItemSlotButton_OnClick(button, ignoreShift)
	end

end

-- set slot is added by ALT+clicking the paper doll character model
function newGearRackUI_CharacterModelFrame_OnMouseUp(button)

	if IsAltKeyDown() then
		local visible = not GearRackDB.bars[user].Inv[20]
		if visible then
			GearRackDB.bars[user].Visible="ON"
		end
		GearRack.SetSetButtonVisible(visible)
	else
		oldGearRackUI_CharacterModelFrame_OnMouseUp(button)
	end

end

function newGearRackUI_PaperDollItemSlotButton_OnEnter()

	local id = this:GetID()

	oldGearRackUI_PaperDollItemSlotButton_OnEnter()

	if id and not InRepairMode() and not CursorHasItem() then
		if GearRackDB.settings.CharSheetMenu ~= "OFF" then
			GearRackUI_BuildMenu(id,"CHARACTERSHEET")
			if GearRackUI_MenuFrame:IsVisible() and GameTooltip:IsVisible() then
				if id == 16 or id == 17 or id == 18 or id == 0 then
					GameTooltip:ClearAllPoints()
					GameTooltip:SetPoint("BOTTOMLEFT", this, "TOPLEFT", 0, 5)
				else
					GameTooltip:ClearAllPoints()
					GameTooltip:SetPoint("TOPLEFT", GearRackUI_MenuFrame, "TOPRIGHT", 6, 0)
					if GameTooltip:GetRight() and UIParent:GetWidth() and GameTooltip:GetRight() > UIParent:GetWidth() then
						GameTooltip:ClearAllPoints()
						GameTooltip:SetPoint("TOPRIGHT", this, "TOPLEFT", -6, 0)
					end
				end
			end
		end
	end
end

function newGearRackUI_PaperDollFrame_OnShow()
	oldGearRackUI_PaperDollFrame_OnShow()
	update_equipped_enchant(16, CharacterMainHandSlot)
	update_equipped_enchant(17, CharacterSecondaryHandSlot)
end

function newGearRackUI_PaperDollFrame_OnHide()

	if GearRackUI.MenuDockedTo=="CHARACTERSHEET" then
		GearRackUI_MenuFrame:Hide()
	end

	oldGearRackUI_PaperDollFrame_OnHide()
end

-- Activating a Goblin Brainwashing Device specialization fires GEARRACK_GBD
-- with the spec number. The device's other options pass through untouched.
function GearRack_GossipTitleButton_OnClick()
	if GearRackDB.settings.EnableEvents=="ON" and this.type~="Available" and this.type~="Active"
		and GossipFrameNpcNameText:GetText()==GearRackUIText.GBD then
		local _,_,spec = string.find(this:GetText() or "",GearRackUIText.GBDSpec)
		if spec then GearRackUI_RegisterFrame_OnEvent("GEARRACK_GBD",spec) end
	end
	GearRack_OriginalGossipTitleButton_OnClick()
end

--[[ Inv Movement ]]--

function GearRackUI_InvFrame_OnMouseDown(arg1)

	if arg1=="LeftButton" and GearRackDB.bars[user].Locked=="OFF" then
		this:StartMoving()
	end
end

function GearRackUI_InvFrame_OnMouseUp(arg1)

	if arg1=="LeftButton" then
		this:StopMovingOrSizing()
		GearRackDB.bars[user].XPos = GearRackUI_InvFrame:GetLeft()
		GearRackDB.bars[user].YPos = GearRackUI_InvFrame:GetTop()
		cooldowns_need_updating()
	end
end

function GearRackUI_Toggle()
	if GearRackUI_InvFrame:IsVisible() then
		GearRackDB.bars[user].Visible="OFF"
		GearRackUI_InvFrame:Hide()
	else
		GearRackDB.bars[user].Visible="ON"
		GearRackUI_InvFrame:Show()
	end
end

--[[ Inventory changes ]]--

-- any inventory changes will cause this OnUpdate to start counting.  After InvUpdateLimit, it processes the inventory change
function GearRackUI_InvUpdate_OnUpdate()

	if SpellIsTargeting() then
		-- if we're in disenchant/enchant/applying poison/sharpening stone/etc, check back later. do nothing for now
		GearRackEngine.StartTimer("InvUpdate",1)
	else
		GearRackEngine.StopTimer("InvUpdate")

		draw_inv()
		if GearRackUI.TooltipType=="INVENTORY" and GearRackUI.TooltipOwner then
			GearRackEngine.TooltipUpdate()
		end

		if GearRackDB.bars[user].Inv[0] then
			-- update ammo count
			GearRackUIInv0Count:SetText(CharacterAmmoSlotCount:IsShown() and CharacterAmmoSlotCount:GetText() or "")
		end

		if #GearRackDB.bars[user].Bar>0 then
			for i=1,#GearRackDB.bars[user].Bar do
				_G["GearRackUIInv"..GearRackDB.bars[user].Bar[i]]:SetChecked(0)
				SetDesaturation(_G["GearRackUIInv"..GearRackDB.bars[user].Bar[i].."Icon"],nil)
			end
		end

		-- if set builder is up, change the inventory to reflect the change
		if GearRackUI_SetsFrame:IsVisible() then
			for i=0,19 do
				SetDesaturation(_G["GearRackUI_Sets_Inv"..i.."Icon"],nil)
			end
			GearRackUI_Sets_UpdateInventory()
		end

		if GearRackUI.InvOpen then
			if GearRackDB.settings.RightClick=="ON" and GearRackUI.InvOpen==13 then
				GearRackUI.InvOpen = 14
			end
			GearRackUI_BuildMenu(GearRackUI.InvOpen, GearRackUI.MenuDockedTo)
			if GearRackUI_MenuFrame:IsVisible() then
				if GearRackUI.InvOpen==20 then
					local id = GetMouseFocus() and GetMouseFocus():GetID() or ""
					local menuItem = GearRackUI.BaggedItems[id or ""]
					if menuItem and menuItem.name and GearRackDB.sets[user].Sets[menuItem.name] then
						GearRackUI_Sets_Tooltip(menuItem.name)
					end
				end
			end
		end
	end
end

--[[ Scaling ]]--

function GearRackUI_StartScaling(arg1)
	if arg1=="LeftButton" and unlocked() then
		local frame = this:GetParent()
		local width = frame:GetWidth()
		if not frame:IsVisible() or not width or width<=0 or width~=width or width==math.huge then return end
		GearRackUI_StopScalingFrame(GearRackUI.FrameToScale)
		this:LockHighlight()
		GearRackUI.ScalingGrip = this
		GearRackUI.FrameToScale = frame
		GearRackUI.ScalingWidth = width
		GearRackUI_MenuFrame:Hide()
		GearRackEngine.StartTimer("ScaleUpdate")
	end
end

function GearRackUI_StopScalingFrame(frame)
	if GearRackUI.FrameToScale~=frame then return end
	GearRackEngine.StopTimer("ScaleUpdate")
	if GearRackUI.ScalingGrip then GearRackUI.ScalingGrip:UnlockHighlight() end
	GearRackUI.FrameToScale, GearRackUI.ScalingGrip, GearRackUI.ScalingWidth = nil, nil, nil
	if frame then
		if frame==GearRackUI_InvFrame then GearRackDB.bars[user].MainScale = frame:GetScale() end
		cooldowns_need_updating()
	end
end

function GearRackUI_StopScaling(arg1)
	if arg1=="LeftButton" and this==GearRackUI.ScalingGrip and this:GetParent()==GearRackUI.FrameToScale then
		GearRackUI_StopScalingFrame(GearRackUI.FrameToScale)
	end
end

function GearRackUI_ScaleFrame(scale)
	local frame = GearRackUI.FrameToScale
	if not frame then return end
	local x,y = GearRack.ScaleFrame(frame,scale,GearRackDB.bars[user].XPos,GearRackDB.bars[user].YPos)
	if x then GearRackDB.bars[user].XPos, GearRackDB.bars[user].YPos = x, y end
end

--[[ Clicks ]]--

-- uses inventory slot v1 (0-19) can be called from key binding and slot doesn't need to be on the bar
function GearRackUI_UseItem(v1)

	if SpellIsTargeting() and v1~=0 then -- if poison or sharpening stone being applied (and not an ammo slot)
		PickupInventoryItem(v1)
	elseif v1 and not MerchantFrame:IsVisible() then
		UseInventoryItem(v1)
	end
end

function GearRackUI_ReactUseInventoryItem(slot)

	-- A macro can reach both native use hooks in the same frame. Observe its
	-- item once so it cannot fire automation twice or restart the same timers.
	local itemID,time=GetInventoryItemID("player",slot),GetTime()
	GearRackUI.RecentUses=GearRackUI.RecentUses or {}
	local observed=GearRackUI.RecentUses[slot]
	if itemID and observed and observed.id==itemID and observed.time==time then return end
	if itemID then
		if not observed then observed={};GearRackUI.RecentUses[slot]=observed end
		observed.id,observed.time=itemID,time
	end
	if GearRackDB.bars[user].Inv[slot] then
		_G["GearRackUIInv"..slot]:SetChecked(1)
	end
	if GearRack.initialized and (slot==13 or slot==14) then GearRackTrinkets.ReflectTrinketUse(slot) end
	GearRackEngine.StartTimer("InvUpdate",1.5) -- extra long wait

	local item = itemID and GetItemInfo(itemID)
	-- Trinkets have their own watcher (Trinkets.lua).
	if GearRackDB.settings.Notify=="ON" and item and slot~=13 and slot~=14 then
		local watch = GearRackUI.NotifyList[itemID] or {}
		GearRackUI.NotifyList[itemID] = watch
		watch.name, watch.inv, watch.bag, watch.slot, watch.hadcooldown = item, slot, nil, nil, nil
	end
	if GearRackDB.settings.EnableEvents=="ON" and item then
		GearRackUI_RegisterFrame_OnEvent("GEARRACK_ITEMUSED", item, slot)
	end
end

-- Non-destructive handler for UseInventoryItem
function GearRackUI.OnUseInventoryItem(slot)
	if slot and slot >= 0 and slot <= 19 then
		GearRackUI_ReactUseInventoryItem(slot)
	end
end

function GearRackUI_Inv_OnClick(arg1)

	local id = this:GetID()

	this:SetChecked(0)

	if id==20 and not IsAltKeyDown() then
		if arg1=="RightButton" then
			GearRack.OpenGearSets()
		else
			local setname = GearRackEngine.CurrentSet()
			if setname and GearRackDB.sets[user].Sets[setname] then
				if IsShiftKeyDown() then
					GearRackEngine.UnequipSet(setname)
				else
					GearRackUI_EquipSet(setname)
				end
			else
				GearRack.OpenGearSets()
			end
		end
	elseif arg1=="RightButton" and IsAltKeyDown() and GearRackDB.bars[user].Locked=="OFF" then
		-- toggle space after item
		GearRackDB.bars[user].Spaces[id] = not GearRackDB.bars[user].Spaces[id]
		draw_inv()
	elseif arg1=="LeftButton" and IsAltKeyDown() and GearRackDB.bars[user].Locked=="OFF" then
		-- if Alt is down, remove the item from the bar
		if GearRackDB.bars[user].Inv[id] then
			remove_inv(id)
			GearRackUI_MenuFrame:Hide()
		end
	elseif arg1=="LeftButton" and IsShiftKeyDown() and ChatFrameEditBox:IsVisible() and id < 20 then
		-- if Shift is down, link the item to chat
		ChatFrameEditBox:Insert(GetInventoryItemLink("player",id))
	elseif arg1=="RightButton" and not IsAltKeyDown() and (id==13 or id==14) then
		GearRack.OpenTrinketPriorities(id)
	else
		-- otherwise use the item
		GearRackUI_UseItem(id)
	end
end

--[[ Menu ]]--

function GearRackUI_Inv_OnEnter()
	local id = this:GetID()

	GearRackUI_Inv_Tooltip()

	GearRackUI.MenuDockedTo = nil
	if not GearRackEngine.TimerEnabled("ScaleUpdate") then
		if IsShiftKeyDown() or GearRackDB.settings.MenuShift=="OFF" then
			if GearRackDB.settings.RightClick=="ON" and (id==13 or id==14) and GearRackUI.TrinketsPaired then
				if GearRackDB.bars[user].MainOrient=="HORIZONTAL" and corner_info("LEFTRIGHT")=="LEFT" then
					id = 13
				elseif GearRackDB.bars[user].MainOrient=="HORIZONTAL" and corner_info("LEFTRIGHT")=="RIGHT" then
					id = 14
				elseif GearRackDB.bars[user].MainOrient=="VERTICAL" and corner_info("TOPBOTTOM")=="TOP" then
					id = 13
				else
					id = 14
				end
			end
			GearRackUI_BuildMenu(id)
		end
		if IsAltKeyDown() then
			GearRackUI_ControlFrame:Show()
			GearRackEngine.StartTimer("ControlFrame")
		end
	end
end

function GearRackUI_Menu_OnClick(arg1)

	local id = this:GetID()
	local name = GearRackUI.BaggedItems[id].name
	local itemID = GearRackUI.BaggedItems[id].id
	this:SetChecked(0)


	if GearRackUI.BankIsOpen then
		if SpellIsTargeting() or GetCursorInfo() then return end
		if GearRackUI.InvOpen~=20 then
			if GearRackEngine.IsEquipmentSwapActive() then return end
			if not itemID then return end
			local sourceBag,sourceSlot = GearRackUI.BaggedItems[id].bag,GearRackUI.BaggedItems[id].slot
			if not sourceBag or not sourceSlot then return end
			local _,currentID = GearRackEngine.GetItemInfo(sourceBag,sourceSlot)
			if currentID ~= itemID then
				cacheInvalid = true
				GearRackUI_BuildMenu(GearRackUI.InvOpen,GearRackUI.MenuDockedTo)
				return
			end
			if not GearRackEngine.BeginBankTransfer() then return end
			local bag,slot
			if sourceBag == -1 or (sourceBag >= 5 and sourceBag <= 10) then
				-- swap from bank to bag
				bag,slot = GearRackEngine.FindSpace()
				if bag then
					GearRackEngine.SendBankItem({bagID=sourceBag,slotIndex=sourceSlot},
						{bagID=bag,slotIndex=slot},itemID,GearRackUI.BaggedItems[id].guid)
				else
					GearRackEngine.NoMoreRoom()
				end
			else
				-- swap from bag to bank
				bag,slot = GearRackEngine.FindSpace(1)
				if bag then
					GearRackEngine.SendBankItem({bagID=sourceBag,slotIndex=sourceSlot},
						{bagID=bag,slotIndex=slot},itemID,GearRackUI.BaggedItems[id].guid)
				else
					GearRackEngine.NoMoreRoom()
				end
			end
			GearRackEngine.EndBankTransfer()
		else
			if GearRackEngine.SetHasBanked(name) then
				GearRackEngine.PullSetFromBank(name)
			else
				GearRackEngine.PushSetToBank(name)
			end
		end
		return
	end

	if GearRackUI.MenuDockedTo ~= "CHARACTERSHEET" then
		if GearRackDB.settings.RightClick=="ON" and arg1=="LeftButton" and GearRackUI.InvOpen==14 then
			GearRackUI.InvOpen = 13
		elseif GearRackDB.settings.RightClick=="ON" and arg1=="RightButton" and GearRackUI.InvOpen==13 then
			GearRackUI.InvOpen = 14
		end
	end

	if (GearRackDB.settings.AllowHidden=="ON" or GearRackUI.InvOpen==20) and IsAltKeyDown() and GearRackUI.MenuDockedTo~="CHARACTERSHEET" then

		if GearRackUI.InvOpen==20 then
			-- sets ignore flag is with the set
			if GearRackDB.sets[user].Sets[name].hide then
				GearRackDB.sets[user].Sets[name].hide = nil
			else
				GearRackDB.sets[user].Sets[name].hide = 1
			end
		elseif not GearRackUI.BaggedItems[id].bag then
			-- empty slot, do nothing
		elseif GearRackDB.bars[user].Ignore[GearRackUI.BaggedItems[id].name] then
			GearRackDB.bars[user].Ignore[GearRackUI.BaggedItems[id].name] = nil
		else
			GearRackDB.bars[user].Ignore[GearRackUI.BaggedItems[id].name] = 1
		end
		cacheInvalid = true
		GearRackUI_BuildMenu(GearRackUI.InvOpen,GearRackUI.MenuDockedTo)

	elseif arg1=="LeftButton" and IsShiftKeyDown() and ChatFrameEditBox:IsVisible() and GearRackUI.InvOpen < 20 then
		-- if linking a menu item with shift+left click
		ChatFrameEditBox:Insert(GetContainerItemLink(GearRackUI.BaggedItems[id].bag,GearRackUI.BaggedItems[id].slot))

	elseif GearRackUI.InvOpen==20 then
		-- if selecting a set menu item
		if GearRackUI.BaggedItems[id].name then
			if (not UnitAffectingCombat("player") and not GearRackEngine.IsPlayerReallyDead()) and (IsShiftKeyDown() or GearRackDB.settings.AutoToggle=="ON") then
				-- toggle set if shift key is down or AutoToggle on
				GearRackUI_ToggleSet(GearRackUI.BaggedItems[id].name)
			else -- otherwise equip it
				GearRackUI_EquipSet(GearRackUI.BaggedItems[id].name)
			end
			GearRackUI_MenuFrame:Hide()
			GearRackEngine.StartTimer("InvUpdate",1) -- extra long wait, force an update, set may not swap
		end

	elseif GearRackUI.InvOpen then
        local source=GearRackUI.BaggedItems[id]
        local chosen={id=source.id or 0,name=source.name,texture=source.texture}
        if source.bag then
            local texture,liveID,liveName=GearRackEngine.GetItemInfo(source.bag,source.slot)
            local liveGUID=GearRack.BagGUID(source.bag,source.slot)
            if liveID~=source.id or (source.guid and source.guid~=liveGUID) then
                GearRack.InvalidateBag(source.bag);return
            end
            chosen.id,chosen.name,chosen.texture=liveID,liveName,texture
            chosen.guid=liveGUID
        end
        GearRack.RequestItem(GearRackUI.InvOpen,chosen)
        if not IsShiftKeyDown() or GearRackDB.settings.RightClick=="OFF" then GearRackUI_MenuFrame:Hide() end
	end
end

function GearRackUI_MenuFrame_OnShow()
	GearRackEngine.StartTimer("MenuFrame")
end

function GearRackUI_MenuFrame_OnHide()

	GearRackEngine.StopTimer("MenuFrame")
	for i=0,20 do
		_G["GearRackUIInv"..i]:UnlockHighlight()
	end
	GearRackUI.InvOpen = nil
	GearRackUI.MenuDockedTo = nil
	if GearRackUI.TooltipOwner and not GearRackUI.TooltipOwner:IsVisible() then
		GearRackUI_StopTooltip(true)
	end
end

--[[ Tooltips ]]--

function GearRackUI_StopTooltip(hide)
	GearRackEngine.StopTimer("TooltipUpdate")
	local owner = GearRackUI.TooltipOwner
	if hide and owner and GameTooltip:GetOwner()==owner then GameTooltip:Hide() end
	GearRackUI.TooltipOwner, GearRackUI.TooltipType = nil, nil
	GearRackUI.TooltipBag, GearRackUI.TooltipSlot, GearRackUI.TooltipPending = nil, nil, nil
end

local function set_tooltip_anchor(owner)

	if GearRackUI.MenuDockedTo=="CHARACTERSHEET" and GearRackUI.InvOpen then
		-- if this is a tooltip of an item docked to character sheet, anchor it to the paperdoll_slot
		GameTooltip:SetOwner(owner,"ANCHOR_RIGHT")
	elseif GearRackDB.settings.TooltipFollow=="ON" then
		if (owner:GetLeft() or 0)<400 then
			GameTooltip:SetOwner(owner,"ANCHOR_RIGHT")
		else
			GameTooltip:SetOwner(owner,"ANCHOR_LEFT")
		end
	else
		GameTooltip_SetDefaultAnchor(GameTooltip,owner)
	end
end

function GearRackUI_Inv_Tooltip()

	local id = this:GetID()

	if GearRackEngine.TimerEnabled("ScaleUpdate") or GearRackDB.settings.ShowTooltips=="OFF" then
		return
	end
	GearRackUI_StopTooltip(false)
	GearRackUI.TooltipOwner = this

	if id==20 then
		local setname=GearRackEngine.CurrentSet()
		if setname and GearRackDB.sets[user].Sets[setname] then
			GearRackUI_Sets_Tooltip(setname)
		else
			set_tooltip_anchor(this)
			GameTooltip:ClearLines()
			GameTooltip:AddLine("Gear sets",ACTION[1],ACTION[2],ACTION[3])
			GameTooltip:AddLine("Hover to pick a saved set. Click to make a new one.",1,1,1)
			GameTooltip:AddLine("Right-click: gear-set editor",ACTION[1],ACTION[2],ACTION[3])
			GameTooltip:Show()
		end
	else
		-- otherwise set up tooltip for an inventory item
		GearRackUI.TooltipType = "INVENTORY"
		GearRackUI.TooltipSlot = id

		GearRackUI.TooltipBag = GearRackEngine.GetNameByID(GearRackEngine.CombatQueue[id])

		set_tooltip_anchor(this)
		GearRackUI.TooltipPending = true
		GearRackEngine.StartTimer("TooltipUpdate",0)
	end
end

function GearRackUI_Menu_Tooltip()

	local id = this:GetID()

	if GearRackEngine.TimerEnabled("ScaleUpdate") or GearRackDB.settings.ShowTooltips=="OFF" then
		return
	end
	GearRackUI_StopTooltip(false)
	GearRackUI.TooltipOwner = this

	if GearRackUI.InvOpen==20 then
		-- if a sets menu, display set tooltip
		GearRackUI_Sets_Tooltip(GearRackUI.BaggedItems[id].name)

	elseif GearRackUI.BaggedItems[id].bag then
		-- otherwise set up tooltip for a bagged item
		GearRackUI.TooltipType = "BAG"
		GearRackUI.TooltipBag = GearRackUI.BaggedItems[id].bag
		GearRackUI.TooltipSlot = GearRackUI.BaggedItems[id].slot

		set_tooltip_anchor(this)
		GearRackUI.TooltipPending = true
		GearRackEngine.StartTimer("TooltipUpdate",0)
	elseif GearRackUI.BaggedItems[id].name == "(empty)" then
		set_tooltip_anchor(this)
		GameTooltip:ClearLines()
		GameTooltip:AddLine("Unequip", 1, 1, 1)
		GameTooltip:AddLine("Click to take the item off (needs a free bag slot).", 0.7, 0.7, 0.7)
		GameTooltip:Show()
	end
end

function GearRackUI_ClearTooltip()

	if GearRackUI.TooltipOwner==this then GearRackUI_StopTooltip(true) end
	if not GearRackUI.InvOpen then
		GearRackUI_MenuFrame_OnHide()
	end
end

--[[ Cooldowns ]]--

-- Ready alert for a used item; also fires GEARRACK_NOTIFY for events.
local function notify(name)
	GearRack.Alert(string.format((GearRackDB.settings.NotifyThirty=="OFF") and GearRackUIText.READY or GearRackUIText.READYTHIRTY,name))
	if GearRackDB.settings.EnableEvents=="ON" then
		GearRackUI_RegisterFrame_OnEvent("GEARRACK_NOTIFY",name)
	end
end
GearRackUI_Notify = notify

-- Refresh only visible cooldown numbers, including immediately after an option change.
function GearRackUI_UpdateCooldownNumbers()
	local start,duration
	if GearRackUI_InvFrame:IsVisible() then
		for _,slot in ipairs(GearRackDB.bars[user].Bar) do
			if slot < 20 then
				start, duration = GearRack.GetInventoryCooldown(slot)
				GearRack.WriteCooldown(_G["GearRackUIInv"..slot.."Time"],start,duration)
			end
		end
	end
	if GearRackUI_MenuFrame:IsVisible() and GearRackUI.InvOpen then
		for i=1,GearRackUI.NumberOfItems do
			local item = GearRackUI.BaggedItems[i]
			if item.bag then
				start, duration = GetContainerItemCooldown(item.bag,item.slot)
				GearRack.WriteCooldown(_G["GearRackUIMenu"..i.."Time"],start,duration)
			end
		end
	end
end

-- Notify list: a used item is tracked by ID wherever it moves on the player.
local function notify_cooldown(itemID,watch)
	local location
	if watch.inv then location = GetInventoryItemID("player",watch.inv)
	elseif watch.bag then location = C_Container.GetContainerItemID(watch.bag,watch.slot) end
	if location ~= itemID then
		watch.inv,watch.bag,watch.slot = GearRack.FindLocation(itemID,nil,true,true)
		if not watch.inv and not watch.bag then return true end
	end
	local start,duration
	if watch.inv then start,duration = GearRack.GetInventoryCooldown(watch.inv)
	else start,duration = GetContainerItemCooldown(watch.bag,watch.slot) end
	local left = start==0 and 0 or duration-(GetTime()-start)
	if left>3 then watch.hadcooldown = true end
	if watch.hadcooldown and (left<=0 or (GearRackDB.settings.NotifyThirty=="ON" and left<30)) then
		notify(watch.name)
		return true
	end
end

function GearRackUI_CooldownUpdate_OnUpdate()
	if GearRackUI.CooldownsNeedUpdating then
		GearRackUI.CooldownsNeedUpdating = false
		update_inv_cooldowns()
	end
	GearRackUI_UpdateCooldownNumbers()
	if GearRackUI_InvFrame:IsVisible() then
		for slot=16,17 do
			local button = _G["GearRackUIInv"..slot]
			if button:IsVisible() then update_equipped_enchant(slot, button) end
		end
	end
	if PaperDollFrame:IsVisible() then
		update_equipped_enchant(16, CharacterMainHandSlot)
		update_equipped_enchant(17, CharacterSecondaryHandSlot)
	end
	if GearRackUI_MenuFrame:IsVisible() and (GearRackUI.InvOpen == 16 or GearRackUI.InvOpen == 17) then
		for i=1,GearRackUI.NumberOfItems do
			if GearRackUI.BaggedItems[i].bag then
				update_menu_weapon_enchant(_G["GearRackUIMenu"..i], GearRackUI.BaggedItems[i])
			end
		end
	end
	if GearRackDB.settings.Notify=="ON" then
		for itemID,watch in pairs(GearRackUI.NotifyList) do
			if notify_cooldown(itemID,watch) then GearRackUI.NotifyList[itemID] = nil end
		end
	end
end

-- Apply the permanent large gold style to an equipment counter.
function GearRackUI_SetCooldownFont(button)
    GearRack.StyleCooldownNumbers(_G[button.."Time"],button)
end

-- changes all cooldown fonts
function GearRackUI_SetAllCooldownFonts()

	for i=0,19 do
		GearRackUI_SetCooldownFont("GearRackUIInv"..i)
	end
	-- Flyout buttons are created lazily; new ones receive the current font on creation.
	for i=1,GearRackUI.MaxItems do
		GearRackUI_SetCooldownFont("GearRackUIMenu"..i)
	end
end

--[[ Options ]]--

function GearRackUI_OnTooltip(v1,v2)

	if GearRackDB.settings.ShowTooltips=="ON" then
		set_tooltip_anchor(this)
		GameTooltip:AddLine(v1)
		GameTooltip:AddLine(v2,.8,.8,.8,1)
		GameTooltip:Show()
	end
end

function GearRackUI_Opt_OnEnter()

	local id = this:GetName()

	if GearRackUI.OptInfo[id] and not GearRackEngine.TimerEnabled("ScaleUpdate") then
		GearRackUI_OnTooltip(GearRackUI.OptInfo[id].text,GearRackUI.OptInfo[id].tooltip)
	end
end

function GearRackUI_Control_OnClick()

	local id = this:GetName()

	if id=="GearRackUI_Control_Rotate" and GearRackDB.bars[user].Locked=="OFF" then
		-- rotate the window
		GearRackDB.bars[user].MainOrient = GearRackDB.bars[user].MainOrient=="HORIZONTAL" and "VERTICAL" or "HORIZONTAL"
		GearRackUI_MenuFrame:Hide()
		draw_inv()
		move_control()
	elseif id=="GearRackUI_Control_Lock" or id=="GearRackUI_Sets_Lock" then
		-- lock/unlock the window
		GearRackDB.bars[user].Locked = GearRackDB.bars[user].Locked=="ON" and "OFF" or "ON"
		set_lock(GearRackDB.bars[user].Locked)
	elseif id=="GearRackUI_Control_Options" then
		GearRack.ToggleSettings()
	end
end

function GearRackUI_Opt_OnClick(overrideID)

	local id = overrideID or this:GetName()

	if GearRackUI.OptInfo[id] and GearRackUI.OptInfo[id].info then
		local info = GearRackUI.OptInfo[id].info

		if this:GetChecked() then
			GearRackDB.settings[info] = "ON"
			PlaySound("igMainMenuOptionCheckBoxOn")
		else
			GearRackDB.settings[info] = "OFF"
			PlaySound("igMainMenuOptionCheckBoxOff")
		end

		if id=="GearRackUI_Opt_Bindings" then
			update_keybindings()
		elseif id=="GearRackUI_Opt_RightClick" then
			draw_inv()
		elseif id=="GearRackUI_Opt_ShowIcon" then
			GearRack.RefreshMinimapButtons()
		elseif id=="GearRackUI_Opt_FlipBar" then
			move_control()
			draw_inv()
		elseif id=="GearRackUI_Opt_CompactList" then
			GearRackUI_Sets_SavedScrollFrameScrollBar:SetValue(0)
			GearRackUI_Sets_SavedScrollFrame_Update()
		elseif id=="GearRackUI_Opt_EnableEvents" then
			if GearRackDB.settings.EnableEvents=="OFF" then
				GearRackUI_DisableAllEvents()
			end
			sets_message((GearRackDB.settings.EnableEvents=="ON") and "Events enabled" or "Events disabled")
		elseif id=="GearRackUI_Opt_ShowAllEvents" then
			GearRackUI_Events_ScrollFrameScrollBar:SetValue(0)
			GearRackUI_Build_eventList()
		elseif id=="GearRackUI_Opt_LargeFont" then
			GearRackUI_ChangeEventFont()
		elseif id=="GearRackUI_Opt_SquareMinimap" then
			move_icon()
		elseif id=="GearRackUI_Opt_SetLabels" then
			draw_inv()
		end
		if info=="Soulbound" or info=="AllowHidden" or info=="ShowEmpty" or info=="RightClick" then
			cacheInvalid = true
			if GearRackUI.InvOpen and GearRackUI_MenuFrame:IsVisible() then
				GearRackUI_BuildMenu(GearRackUI.InvOpen,GearRackUI.MenuDockedTo)
			end
		end
	end
end

function GearRackUI_OptList_ScrollFrame_Update()

	local idx, item, optinfo, optscroll, opttext, optbutton
	local offset = FauxScrollFrame_GetOffset(GearRackUI_OptList_ScrollFrame)

	FauxScrollFrame_Update(GearRackUI_OptList_ScrollFrame, #GearRackUI.OptScroll, 11, 19 )

	for i=1,11 do
		item = _G["GearRackUIOptList"..i]
		idx = offset+i
		if idx<=#GearRackUI.OptScroll then
			optscroll = GearRackUI.OptScroll[idx]
			optinfo = GearRackUI.OptInfo[optscroll.idx]
			opttext = _G["GearRackUIOptList"..i.."CheckButtonText"]
			optbutton = _G["GearRackUIOptList"..i.."CheckButton"]
			opttext:SetText(optinfo.text)
			UI.Color(opttext,"text")
			optbutton:Enable()
			if optscroll.dependency then
				item:SetWidth(128)
				if GearRackDB.settings[GearRackUI.OptInfo[optscroll.dependency].info]=="OFF" then
					UI.Color(opttext,"hint")
					optbutton:Disable()
				end
			else
				item:SetWidth(142)
			end
			if GearRackDB.settings[optinfo.info]=="ON" then
				optbutton:SetChecked(1)
			else
				optbutton:SetChecked(0)
			end
			item:Show()
		else
			item:Hide()
		end
	end

end

-- tooltip for scrolling options
function GearRackUI_OptList_OnEnter()
	local idx = FauxScrollFrame_GetOffset(GearRackUI_OptList_ScrollFrame) + this:GetParent():GetID()
	local optinfo = GearRackUI.OptInfo[GearRackUI.OptScroll[idx].idx]
	GearRackUI_OnTooltip(optinfo.text,optinfo.tooltip)
end

-- onclick for scrolling options, gets name of option and sends to _Opt_OnClick to process
function GearRackUI_OptList_OnClick()
	local idx = FauxScrollFrame_GetOffset(GearRackUI_OptList_ScrollFrame) + this:GetParent():GetID()
	GearRackUI_Opt_OnClick(GearRackUI.OptScroll[idx].idx)
	GearRackUI_OptList_ScrollFrame_Update()
end

-- sets the state of a checkbutton to nil, 0 or 1
function GearRackUI_TriStateCheck_SetState(button,value)
	local label = _G[button:GetName().."Text"]
	button.tristate = value
	if not value then
		button:SetCheckedTexture("Interface\\Buttons\\UI-ScrollBar-Knob")
		button:SetChecked(1)
		UI.Color(label,"hint")
	elseif value==0 then
		button:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")
		button:SetChecked(0)
		UI.Color(label,"text")
	elseif value==1 then
		button:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")
		button:SetChecked(1)
		UI.Color(label,"text")
	end
end

-- rotates a checkbutton from indeterminate->unchecked->checked (for show helm/cloak)
function GearRackUI_TriStateCheck_OnClick()
	if not this.tristate then
		GearRackUI_TriStateCheck_SetState(this,0)
	elseif this.tristate==0 then
		GearRackUI_TriStateCheck_SetState(this,1)
	elseif this.tristate==1 then
		GearRackUI_TriStateCheck_SetState(this,nil)
	end
	GearRackUI_TriStateCheck_Tooltip()
end

-- initializes tristate buttons to be indeterminate
function GearRackUI_TriStateCheck_OnLoad()
	GearRackUI_TriStateCheck_SetState(this,nil)
end

function GearRackUI_TriStateCheck_Tooltip()
	local tristate_names = { ["nil"] = "unchanged", ["0"] = "hide", ["1"] = "show" }
	local which = (this==GearRackUI_ShowHelm) and "Show helm" or "Show cloak"
	GearRackUI_OnTooltip(which..": "..tristate_names[tostring(this.tristate)],"When this set equips. Click to switch between unchanged, hide and show.")
end

--[[ Sets ]]--

GearRackUI.SetBuild = {}

local function build_icon()

	local setname = GearRackUI_Sets_Name:GetText()

	GearRackUI_Sets_ChosenIcon:SetNormalTexture(GearRackUI.SelectedIcon)
	GearRackUI_Sets_ChosenIconName:SetText(setname)
	if GearRackDB.sets[user].Sets[setname] then
		local _,_,modifier,basekey = string.find(GearRackDB.sets[user].Sets[setname].key or "","(.).+(-.)")
		GearRackUI_Sets_ChosenIconHotKey:SetText((modifier or "")..(basekey or ""))
	else
		GearRackUI_Sets_ChosenIconHotKey:SetText("")
	end
end

-- initializes .SetIcons mostly, the list of icons for the set
function GearRackUI_Sets_Initialize()

	GearRackUI.SetIcons = {}

	for i=0,19 do
		-- add 20 spaces at start of list - this list is constructed once and only first 20 slots change
		table.insert(GearRackUI.SetIcons,"")
	end

	for i=1,#GearRackUIExtraIcons do
		-- add ExtraIcons defined in GearRackUIExtraIcons.lua
		table.insert(GearRackUI.SetIcons,GearRackUIExtraIcons[i])
	end
	for i=1,GetNumMacroIcons() do
		-- add the macro icons to choose from
		table.insert(GearRackUI.SetIcons,GetMacroIconInfo(i))
	end

end

local function highlight_set_item(v1)

	if GearRackUI.SetBuild[v1]==1 then
		_G["GearRackUI_Sets_Inv"..v1.."Icon"]:SetVertexColor(1,1,1,1)
		_G["GearRackUI_Sets_Inv"..v1]:SetAlpha(1)
		_G["GearRackUI_Sets_Inv"..v1]:LockHighlight()
	else
		_G["GearRackUI_Sets_Inv"..v1.."Icon"]:SetVertexColor(.4,.4,.4,1)
		_G["GearRackUI_Sets_Inv"..v1]:SetAlpha(.5)
		_G["GearRackUI_Sets_Inv"..v1]:UnlockHighlight()
	end
end

function GearRackUI_Sets_UpdateInventory()

	local texture

	if not GearRackUI.SetIcons then
		GearRackUI_Sets_Initialize()
	end

	for i=0,19 do
		texture = GetInventoryItemTexture("player",i)
		if not texture then
			_,texture = GetInventorySlotInfo(string.gsub(GearRackUI.Indexes[i].paperdoll_slot,"Character",""))
		end
		local btn = _G["GearRackUI_Sets_Inv"..i]
		_G["GearRackUI_Sets_Inv"..i.."Icon"]:SetTexture(texture)
		apply_inv_quality_border(btn, i)
		GearRackUI.SetIcons[i+1] = texture
		highlight_set_item(i)
	end
	GearRackUI_Sets_ScrollFrame_Update()
end

function GearRackUI_Sets_NewSet()
	for i=0,19 do
		GearRackUI.SetBuild[i] = GearRackDB.bars[user].Inv[i] or 0
	end
	GearRackUI.SelectedName = ""
	GearRackUI.SelectedIcon = "Interface\\AddOns\\GearRack\\media\\GearRack-Icon.tga"
	GearRackUI_Sets_Name:SetText("")
	GearRackUI_Sets_UpdateInventory()

	GearRackUI_Sets_Saved:Hide()
	GearRackUI_Sets_Icons:Show() -- start out showing icons

	build_icon()

	GearRackUI_TriStateCheck_SetState(GearRackUI_ShowHelm,nil)
	GearRackUI_TriStateCheck_SetState(GearRackUI_ShowCloak,nil)

	for i=1,25 do
		_G["GearRackUI_Sets_Icon"..i]:UnlockHighlight()
	end

	GearRackUI_Sets_NameLabel:SetText(GearRackUIText.SETS_NAMELABEL_TEXT)
	GearRackUI.SetEditorInitialized = true
	GearRackUI_Tab() -- flip to tab 2 (sets)

	GearRackUI_SetsFrame:Show()
	GearRackUI_Sets_Name:ClearFocus()

end

local function validate_set_buttons()

	local setname,found = GearRackUI_Sets_Name:GetText()

	local saved = GearRackDB.sets[user].Sets[setname] and true or false
	UI.SetEnabled(GearRackUI_Sets_RemoveButton,saved)
	UI.SetEnabled(GearRackUI_Sets_BindButton,saved)
	if saved then GearRackUI_Sets_HideSet:Enable() else GearRackUI_Sets_HideSet:Disable() end
	UI.Color(GearRackUI_Sets_HideSetText,saved and "text" or "hint")

	for i=0,19 do
		found = found or (GearRackUI.SetBuild[i]==1)
	end
	setname = (found and setname) or nil

	UI.SetEnabled(GearRackUI_Sets_SaveButton,setname and string.len(setname)>0)

	build_icon()
end

function GearRackUI_Sets_InvToggle()

	local id = this:GetID()

	this:SetChecked(0)
	GearRackUI.SetBuild[id] = 1-(GearRackUI.SetBuild[id] or 0)

	highlight_set_item(id)

	if IsAltKeyDown() then

		if GearRackDB.bars[user].Inv[id] and GearRackUI.SetBuild[id]==0 then
			remove_inv(id)
		elseif not GearRackDB.bars[user].Inv[id] and GearRackUI.SetBuild[id]==1 then
			GearRackDB.bars[user].Visible="ON"
			GearRackDB.bars[user].Inv[id] = 1
			_G["GearRackUIInv"..id.."Icon"]:SetTexture(get_item_info(id))
			table.insert(GearRackDB.bars[user].Bar,id)
			draw_inv()
		end
	end

	if GearRackUI.SetBuild[id]==1 then
		GearRackUI_BuildMenu(id,"SET")
	end

	validate_set_buttons()
end

function GearRackUI_Sets_ScrollFrame_Update()

	local item, texture, idx
	local offset = FauxScrollFrame_GetOffset(GearRackUI_Sets_ScrollFrame)

	FauxScrollFrame_Update(GearRackUI_Sets_ScrollFrame, ceil(#GearRackUI.SetIcons / 5) , 5, 24 )

	for i=1,25 do
		item = _G["GearRackUI_Sets_Icon"..i]
		idx = (offset*5) + i
		if idx<=#GearRackUI.SetIcons then
			texture = GearRackUI.SetIcons[idx]
			item:SetNormalTexture(texture)
			item:SetPushedTexture(texture)
			item:Show()
		else
			item:Hide()
		end
		if GearRackUI.SetIcons[idx]==GearRackUI.SelectedIcon then
			item:LockHighlight()
		else
			item:UnlockHighlight()
		end
	end
end

function GearRackUI_Sets_Icon_OnClick()

	local id = this:GetID()
	local offset = FauxScrollFrame_GetOffset(GearRackUI_Sets_ScrollFrame)
	local idx = offset*5+id

	if idx<=#GearRackUI.SetIcons then
		GearRackUI.SelectedIcon = GearRackUI.SetIcons[idx]
		GearRackUI_Sets_ScrollFrame_Update()
	end
	build_icon()
end

function GearRackUI_Sets_Name_OnTextChanged()

	GearRackUI.SelectedName = GearRackUI_Sets_Name:GetText()
	GearRackUI_Sets_ChosenIconName:SetText(GearRackUI.SelectedName)
	validate_set_buttons()
end

-- save button clicked
function GearRackUI_Sets_Save_OnClick()

	local setname = GearRackUI_Sets_Name:GetText()
	local itemcount, itemname, itemslot = 0
	local oldkey, oldkeyindex, oldmacro

	GearRackUI_Sets_Name:ClearFocus()

	-- With a two-hander worn this save leaves the off hand out (no empty slot
	-- to equip there); the draft keeps its off-hand choice for later saves.
	_,_,_,itemslot = get_item_info(16)
	local twoHand = itemslot=="INVTYPE_2HWEAPON"

	if string.len(setname)>0 then
		if GearRackDB.sets[user].Sets[setname] then
			-- grab old key binding before recreating set
			oldkey = GearRackDB.sets[user].Sets[setname].key
			oldkeyindex = GearRackDB.sets[user].Sets[setname].keyindex
			oldmacro = GearRackDB.sets[user].Sets[setname].macro
		end
		GearRackEngine.ForgetSetUndo(setname)
		GearRackDB.sets[user].Sets[setname] = { icon=GearRackUI.SelectedIcon, key=oldkey, keyindex=oldkeyindex, macro=oldmacro }
		for i=0,19 do
			if GearRackUI.SetBuild[i]==1 and not (twoHand and i==17) then
				GearRackDB.sets[user].Sets[setname][i] = {}
				itemcount = itemcount + 1
				_,_,itemname = get_item_info(i)
				GearRackDB.sets[user].Sets[setname][i].name = itemname or "(empty)"
				_,GearRackDB.sets[user].Sets[setname][i].id = GearRackEngine.GetItemInfo(i)
			end
		end
		sets_message(string.format(GearRackUIText.SAVED,setname,itemcount))
		GearRackDB.sets[user].Sets[setname].hide = GearRackUI_Sets_HideSet:GetChecked()
		GearRackDB.sets[user].Sets[setname].showhelm = GearRackUI_ShowHelm.tristate
		GearRackDB.sets[user].Sets[setname].showcloak = GearRackUI_ShowCloak.tristate
		GearRack.UpdateSetMacro(setname)
	end
	validate_set_buttons()
end

-- equips a set by name, usable in macros. now a wrapper to GearRackEngine.EquipSet()
function GearRackUI_EquipSet(setname)
	setname = setname or GearRackUI.EventSetName
	-- A script tested without a chosen set has nothing to equip.
	if setname then GearRackEngine.EquipSet(setname) end
end

-- hitting the dropdown button toggles between icons and savedsets
function GearRackUI_Sets_DropDownButton_OnClick()

	GearRackUI_Sets_Name:ClearFocus()
	GearRackUI_Sets_Build_Dropdown()
	GearRackUI_Sets_SubFrame2:Hide()
	GearRackUI_Sets_SubFrame4:Hide()
	GearRackUI_Sets_SetSelect:Show()
	GearRackUI_Sets_Saved:Show()
end

-- clicking one of the drop-down saved sets
function GearRackUI_Sets_Saved_OnClick(arg1)

	local id = this:GetID()
	local idx = FauxScrollFrame_GetOffset(GearRackUI_Sets_SavedScrollFrame) + id
	local setname

	GearRackUI_Sets_SetSelect:Hide()

	if GearRackUI.SetsListSize<2 then
		-- do nothing
	elseif GearRackUI.SelectedTab==2 then
		-- chose a set from the Sets tab (SubFrame2)
		setname = GearRackUI.SetsList[idx].Name
		GearRackUI_Sets_Name:SetText(setname)
		GearRackUI.SelectedIcon = GearRackUI.SetsList[idx].Icon
		GearRackUI.SelectedName = setname
		build_icon()
		for i=0,19 do
			GearRackUI.SetBuild[i] = GearRackDB.sets[user].Sets[setname][i] and 1 or 0
			highlight_set_item(i)
		end
		GearRackUI_Sets_HideSet:SetChecked(GearRackDB.sets[user].Sets[setname].hide)
		GearRackUI_TriStateCheck_SetState(GearRackUI_ShowHelm,GearRackDB.sets[user].Sets[setname].showhelm)
		GearRackUI_TriStateCheck_SetState(GearRackUI_ShowCloak,GearRackDB.sets[user].Sets[setname].showcloak)
		GearRackUI_EquipSet(setname)
	elseif GearRackUI.SelectedTab==4 then
		-- chose a set from the Events tab (SubFrame4)
		setname = GearRackUI.SetsList[idx].Name
		GearRackUI.CancelEvent(eventList[GearRackUI.SelectedEvent].name)
		if not GearRackDB.bars[user].Events[eventList[GearRackUI.SelectedEvent].name] then
			GearRackDB.bars[user].Events[eventList[GearRackUI.SelectedEvent].name] = { setname=setname, enabled=1 }
		else
			GearRackDB.bars[user].Events[eventList[GearRackUI.SelectedEvent].name].setname = setname
		end
		GearRackUI_Build_eventList()
	end

end

-- gather all sets into a numerically-indexes list to be used by SavedScrollFrame
function GearRackUI_Sets_Build_Dropdown()

	local idx,count=1

	GearRackUI.SetsList = GearRackUI.SetsList or {}

	for i in pairs(GearRackDB.sets[user].Sets) do
		if not string.find(i,"^GearRackUI-") and not string.find(i,"^GearRackEngine-") then -- skip special sets (GearRackUI-Queue and GearRackUI-Normal)
			count = 0
			GearRackUI.SetsList[idx] = GearRackUI.SetsList[idx] or {}
			GearRackUI.SetsList[idx].Icon = GearRackDB.sets[user].Sets[i].icon
			GearRackUI.SetsList[idx].Name = i
			for j=0,19 do
				if GearRackDB.sets[user].Sets[i][j] then
					count = count + 1
				end
			end
			GearRackUI.SetsList[idx].Count = string.format(GearRackUIText.COUNTFORMAT,count)
			GearRackUI.SetsList[idx].Key = GearRackDB.sets[user].Sets[i].key
			GearRackUI.SetsList[idx].Hide = GearRackDB.sets[user].Sets[i].hide

			idx = idx +1
		end
	end
	GearRackUI.SetsListSize = idx
	for i=idx,#GearRackUI.SetsList do GearRackUI.SetsList[i] = nil end

	-- sort drop-down list alphabetically
	table.sort(GearRackUI.SetsList,function(e1,e2) if e1 and e2 and (e1.Name<e2.Name) then return true else return false end end)
	GearRackUI_Sets_SavedScrollFrameScrollBar:SetValue(0)
	GearRackUI_Sets_SavedScrollFrame_Update()

end

-- scrollbar update for saved sets (dropdown)
function GearRackUI_Sets_SavedScrollFrame_Update()

	local idx
	local offset = FauxScrollFrame_GetOffset(GearRackUI_Sets_SavedScrollFrame)

	local listsize,listheight,liststub,compact = 8,28,"GearRackUI_Sets_Saved",nil

	for i=1,8 do
		_G["GearRackUI_Sets_Saved"..i]:Hide()
	end
	for i=1,11 do
		_G["GearRackUI_Sets_Compact"..i]:Hide()
	end

	if GearRackDB.settings.CompactList=="ON" then
		listsize,listheight,liststub,compact = 11,21,"GearRackUI_Sets_Compact",1
	end

	FauxScrollFrame_Update(GearRackUI_Sets_SavedScrollFrame, GearRackUI.SetsListSize-1, listsize, listheight )

	for i=1,listsize do
		idx = offset + i
		if idx<GearRackUI.SetsListSize then
			_G[liststub..i.."Name"]:SetText(GearRackUI.SetsList[idx].Name)
			_G[liststub..i.."Icon"]:SetTexture(GearRackUI.SetsList[idx].Icon)
			_G[liststub..i.."Count"]:SetText(GearRackUI.SetsList[idx].Count)
			if not compact then
				_G[liststub..i.."Key"]:SetText(GearRackUI.SetsList[idx].Key)
			end
			local role = GearRackDB.sets[user].Sets[GearRackUI.SetsList[idx].Name].hide and "hint" or "text"
			UI.Color(_G[liststub..i.."Name"],role)
			UI.Color(_G[liststub..i.."Count"],role)
			if not compact then
				UI.Color(_G[liststub..i.."Key"],role)
			end
			_G[liststub..i]:Show()
		else
			_G[liststub..i]:Hide()
		end
	end

	if GearRackUI.SetsListSize<=1 then
		GearRackUI_Sets_Saved1Icon:SetTexture("")
		GearRackUI_Sets_Saved1Name:SetText(GearRackUIText.NOSAVEDSETS)
		GearRackUI_Sets_Saved1Count:SetText("")
		GearRackUI_Sets_Saved1Key:SetText("")
		GearRackUI_Sets_Saved1:Show()
		for i=2,8 do
			_G["GearRackUI_Sets_Saved"..i]:Hide()
		end
		for i=1,11 do
			_G["GearRackUI_Sets_Compact"..i]:Hide()
		end
	end

end

-- Displays the complete contents of a saved set.
function GearRackUI_Sets_Tooltip(setname)

	local r,g,b,id,name,inv,bag

	setname = setname or GearRackUI.SelectedName

	if setname and GearRackDB.sets[user].Sets[setname] then

		set_tooltip_anchor(GetMouseFocus())
		GameTooltip:AddLine(string.format(GearRackUIText.SETTOOLTIPFORMAT,setname))
		for i=0,19 do
			if GearRackDB.sets[user].Sets[setname][i] then
				name = GearRackDB.sets[user].Sets[setname][i].name or "(empty)"
				id = GearRackDB.sets[user].Sets[setname][i].id
				inv,bag = GearRackEngine.FindItem(nil,name,"passive")
				if GearRackUI.BankedItems[id] then
					r,g,b = .3,.5,1
				elseif inv or bag or name=="(empty)" then
					r,g,b = .85,.85,.85
				else
					r,g,b = 1,.1,.1 -- mark missing items red
				end
				GameTooltip:AddLine(GearRackUI.Indexes[i].name..": "..tostring(name),r,g,b)
			end
		end
		if this and this==GearRackUIInv20 then
			GameTooltip:AddLine("Right-click: gear-set editor",ACTION[1],ACTION[2],ACTION[3])
		elseif this and this.gearRackDrag then
			GameTooltip:AddLine("Drag: action bar",ACTION[1],ACTION[2],ACTION[3])
		end
		GameTooltip:Show()
	end
end

-- tooltips displaying contents of a set in the dropdown list
function GearRackUI_Sets_Saved_OnEnter()

	if GearRackUI.SetsListSize>1 then
		local id = this:GetID()
		local idx = FauxScrollFrame_GetOffset(GearRackUI_Sets_SavedScrollFrame) + id
		local setname = GearRackUI.SetsList[idx].Name
		GearRackUI_Sets_Tooltip(setname)
	end
end

--[[ Key bindings ]]--

-- returns a number 1-10 (or MaxKeyBindings) of an available key binding, nil if none are free
local function get_free_binding()

	local found,freeindex

	for i=1,GearRackUIText.MaxKeyBindings do
		found = false
		for j in pairs(GearRackDB.sets[user].Sets) do
			if GearRackDB.sets[user].Sets[j].keyindex == i then
				found = true
			end
		end
		if not found then
			freeindex = i
			break
		end
	end

	return freeindex
end

-- removes a key by index, 1-10 (or .MaxKeyBindings)
local function unbind_key_index(idx)

	if idx then
		local command="GEARRACK_EQUIPSET"..idx
		for _,oldkey in ipairs({GetBindingKey(command)}) do
			if GetBindingAction(oldkey)==command then SetBinding(oldkey) end
		end
		_G["BINDING_NAME_"..command] = string.format(GearRackUIText.BINDINGFORMAT,idx)
	end
end

-- Release both native keys of the selected saved set.
local function unbind_keys(setname)
	local settled=GearRackUI.KeyBindingsSettled
	GearRackUI.KeyBindingsSettled=nil
	unbind_key_index(GearRackDB.sets[user].Sets[setname].keyindex)
	GearRackUI.KeyBindingsSettled=settled
	SaveBindings(GetCurrentBindingSet())

end

-- this takes the current key bindings and updates the .Sets info -- usually as a result of user changing bindings outside the mod
function GearRackUI_AgreeOnKeyBindings()
	local oldkey,setname

	if GearRackUI.KeyBindingsSettled then
		-- don't do this at startup, wait until we had a chance to initialize this player's keys

		for i in pairs(GearRackDB.sets[user].Sets) do
			GearRackDB.sets[user].Sets[i].key = nil
			GearRackDB.sets[user].Sets[i].keyindex = nil
		end

		for i=1,10 do
			oldkey = GetBindingKey("GEARRACK_EQUIPSET"..i)
			if oldkey then
				_,_,setname = string.find(_G["BINDING_NAME_GEARRACK_EQUIPSET"..i] or "",GearRackUIText.BINDINGSEARCH)
				if setname and GearRackDB.sets[user].Sets[setname] then
					GearRackDB.sets[user].Sets[setname].key = oldkey
					GearRackDB.sets[user].Sets[setname].keyindex = i
				end
			end
		end
	end
end

-- removes the currently selected set
function GearRackUI_Sets_Remove_OnClick()

	if GearRackDB.sets[user].Sets[GearRackUI.SelectedName] then
		unbind_keys(GearRackUI.SelectedName)
		GearRack.DeleteSetMacro(GearRackUI.SelectedName)
		GearRackEngine.ForgetSetUndo(GearRackUI.SelectedName)
		GearRackDB.sets[user].Sets[GearRackUI.SelectedName] = nil
		if GearRackDB.sets[user].CurrentSet==GearRackUI.SelectedName then GearRackDB.sets[user].CurrentSet=nil end
		sets_message(string.format(GearRackUIText.SETREMOVE,GearRackUI.SelectedName))
		-- if an event has this set, remove the association
		for i in pairs(GearRackDB.bars[user].Events) do
			if GearRackDB.bars[user].Events[i].setname==GearRackUI.SelectedName then
				GearRackUI_DisableEvent(i)
				GearRackDB.bars[user].Events[i] = nil
			end
		end
		GearRackUI.SelectedName=nil
		GearRackUI_Sets_Name:SetText("")
		build_icon()
		validate_set_buttons()
		GearRackUI_Build_eventList()
	end
end

function GearRackUI_UseSetBinding(v1)

	local setname

	-- look for sets with this key index
	for i in pairs(GearRackDB.sets[user].Sets) do
		if GearRackDB.sets[user].Sets[i].keyindex == v1 then
			setname = i
		end
	end

	-- if we found a set with this key index, equip it
	if setname then
		GearRackUI_EquipSet(setname)
	end
end

local function bind_key_to_set(key,setname)
	local set=GearRackDB.sets[user].Sets[setname]
	if not set then return end
	local idx=set.keyindex or get_free_binding()
	if not idx then sets_message("All ten gear-set bindings are in use.");return end
	local command="GEARRACK_EQUIPSET"..idx
	local oldkeys={GetBindingKey(command)}
	-- Native UPDATE_BINDINGS may run inside SetBinding. Commit metadata only
	-- after success, and keep old keys intact if the new assignment is rejected.
	GearRackUI.KeyBindingsSettled=nil
	local success=SetBinding(key,command)
	if success then
		for _,oldkey in ipairs(oldkeys) do
			if oldkey~=key and GetBindingAction(oldkey)==command then SetBinding(oldkey) end
		end
		_G["BINDING_NAME_"..command]=string.format(GearRackUIText.BINDINGFORMAT,setname)
	end
	GearRackUI.KeyBindingsSettled=true
	GearRackUI_AgreeOnKeyBindings()
	if success then
		SaveBindings(GetCurrentBindingSet())
		sets_message(string.format(GearRackUIText.BINDSET,key))
		GearRackUI_KeyBindFrame:Hide()
	else sets_message("The key could not be assigned. Your existing binding is unchanged.") end
end

-- hitting a key when "Press a key" mode up
function GearRackUI_Sets_KeyBind_OnKeyDown(arg1)

	local setname = GearRackUI.SelectedName
	local selected=GearRackDB.sets[user].Sets[setname]
	if not selected or not GearRackUI_KeyBindFrame:IsVisible() then return end

	if arg1=="ESCAPE" then
		sets_message(GearRackUIText.BINDCLEAR)
		GearRackUI_KeyBindFrame:Hide()

		-- if this set has a key, restore its name and release the key binding
		unbind_keys(setname)
		GearRackDB.sets[user].Sets[setname].key = nil
		GearRackDB.sets[user].Sets[setname].keyindex = nil

	elseif arg1~="SHIFT" and arg1~="ALT" and arg1~="CTRL" then
		local key = arg1
		if IsShiftKeyDown() then
			key = "SHIFT-"..key
		end
		if IsControlKeyDown() then
			key = "CTRL-"..key
		end
		if IsAltKeyDown() then key = "ALT-"..key end

		local action
		action = GetBindingAction(key)
		if action and action~="" then
			local profile=GetCurrentBindingSet()
			local revision=GearRackUI.KeyBindRevision
			StaticPopupDialogs["GEARRACKKEYCONFIRM"] = {
				text = key.." is already used for "..tostring(_G["BINDING_NAME_"..action]).."\n\nOverwrite?",
				button1 = "Yes",
				button2 = "No",
				OnAccept = function()
					if GearRackUI_KeyBindFrame:IsVisible() and GearRackUI.KeyBindRevision==revision
						and GearRackUI.SelectedName==setname and GearRackDB.sets[user].Sets[setname]==selected
						and GetCurrentBindingSet()==profile and GetBindingAction(key)==action then
						bind_key_to_set(key,setname)
					end
				end,
				OnCancel = function() sets_message("No key binding set.") end,
				timeout = 0,
				whileDead = 1
			}
			StaticPopup_Show("GEARRACKKEYCONFIRM")
		else
			bind_key_to_set(key,setname)
		end
	end

	build_icon()

end

function GearRackUI_InitializeKeyBindings()
	local changed
	GearRackUI.KeyBindingsSettled=nil
	for name,set in pairs(GearRackDB.sets[user].Sets) do
		local idx=set.keyindex
		if type(idx)=="number" and idx>=1 and idx<=GearRackUIText.MaxKeyBindings and idx==math.floor(idx) then
			local command="GEARRACK_EQUIPSET"..idx
			_G["BINDING_NAME_"..command]=string.format(GearRackUIText.BINDINGFORMAT,name)
			-- Retain both keys and the current native profile. A stale saved key
			-- must never take a key the player has assigned to another action.
			if not GetBindingKey(command) and set.key then
				local action=GetBindingAction(set.key)
				if not action or action=="" or action==command then
					changed=SetBinding(set.key,command) or changed
				end
			end
		end
	end
	GearRackUI.KeyBindingsSettled=true
	GearRackUI_AgreeOnKeyBindings()
	if changed then SaveBindings(GetCurrentBindingSet()) end
end

function GearRackUI_Sets_Inv_OnEnter()

	local id = this:GetID()

	if GearRackUI.SetBuild and GearRackUI.SetBuild[id]==1 then
		GearRackUI_BuildMenu(id,"SET")
	end

end

function GearRackUI_Sets_ChosenIcon_OnClick()

	if IsAltKeyDown() then
		local visible = not GearRackDB.bars[user].Inv[20]
		if visible then
			GearRackDB.bars[user].Visible="ON"
		end
		GearRack.SetSetButtonVisible(visible)
	end

	validate_set_buttons()
end

--[[ Minimap button ]]--

-- when user clicks the minimap button
function GearRackMinimapButton_OnClick(arg1)

	if arg1=="RightButton" then
		GearRack.OpenEquipmentSettings()
	elseif arg1=="LeftButton" and IsShiftKeyDown() then
		if GearRackDB.settings.DisableToggle=="OFF" then
			GearRackUI_Toggle()
		elseif GearRackUI_MenuFrame:IsVisible() then
			GearRackUI_MenuFrame:Hide()
		else
			GearRackUI_BuildMenu(20,"MINIMAP")
			if not GearRackUI_MenuFrame:IsVisible() then GearRack.OpenGearSets() end
		end
	else
		GearRack.ToggleSettings()
	end

end

--[[ Tabs ]]--

function GearRackUI_Tab(v1)

	GearRackUI_Sets_SetSelect:Hide()
	GearRackUI_EditEvent:Hide()
	GearRackUI.SelectedTab = (v1 or GearRackUI.SelectedTab) or 1
	for i=1,4 do
		ns.SelectPill(_G["GearRackUI_Sets_Tab"..i],i==GearRackUI.SelectedTab)
		_G["GearRackUI_Sets_SubFrame"..i]:Hide()
	end
	_G["GearRackUI_Sets_SubFrame"..GearRackUI.SelectedTab]:Show()
end

-- Escape registry restoration is deferred until native CloseWindows finishes
-- its live-table traversal. Neither remove a closing child nor add its parent
-- inside that traversal: both can skip/close another registered window.
local setsEscapeTimer
local function cancel_sets_escape()
	if setsEscapeTimer then setsEscapeTimer:Cancel();setsEscapeTimer=nil end
end

local function restore_sets_escape()
	cancel_sets_escape()
	local handle
	handle=C_Timer.NewTimer(0,function()
		if setsEscapeTimer~=handle then return end
		setsEscapeTimer=nil
		local selectShown=GearRackUI_Sets_SetSelect and GearRackUI_Sets_SetSelect:IsShown()
		local editShown=GearRackUI_EditEvent and GearRackUI_EditEvent:IsShown()
		if not selectShown then GearRack.SetEscapable("GearRackUI_Sets_SetSelect",false) end
		if not editShown then GearRack.SetEscapable("GearRackUI_EditEvent",false) end
		if GearRackUI_SetsFrame:IsVisible() and not selectShown and not editShown then
			GearRack.SetEscapable("GearRackUI_SetsFrame",true)
		end
	end)
	setsEscapeTimer=handle
end

-- when set chooser dropdown shown
function GearRackUI_SetSelect_OnShow()
  -- remove GearRackUI_SetsFrame from UISpecialFrames and add GearRackUI_Sets_SetSelect
	cancel_sets_escape()
	GearRack.SetEscapable("GearRackUI_SetsFrame",false)
	GearRack.SetEscapable("GearRackUI_Sets_SetSelect",true)
end

-- when set chooser dropdown hidden
function GearRackUI_SetSelect_OnHide()
	restore_sets_escape()
	_G["GearRackUI_Sets_SubFrame"..GearRackUI.SelectedTab]:Show()
end

-- when event editor shown
function GearRackUI_EditEvent_OnShow()
	cancel_sets_escape()
	GearRackUI_Sets_SubFrame4:Hide()
	GearRack.SetEscapable("GearRackUI_SetsFrame",false)
	GearRack.SetEscapable("GearRackUI_EditEvent",true)
end

-- when event editor hidden
function GearRackUI_EditEvent_OnHide()
	restore_sets_escape()
	GearRackUI_Sets_SubFrame4:Show()
end

-- when the sets frame is hidden, enable all events if events are on
function GearRackUI_SetsFrame_OnHide()
	GearRackUI_MenuFrame:Hide()
	-- Parent visibility alone does not clear a child's shown bit. Dismiss
	-- temporary editors and keyboard capture so they cannot return on reopen.
	if GearRackUI_KeyBindFrame then GearRackUI_KeyBindFrame:Hide() end
	GearRackUI_Sets_SetSelect:Hide()
	GearRackUI_EditEvent:Hide()
	restore_sets_escape()
	GearRackUI_EnableAllEvents()
end

-- when the sets frame is shown, disable all events
function GearRackUI_SetsFrame_OnShow()
	cancel_sets_escape()
	if not GearRackUI_Sets_SetSelect:IsShown() and not GearRackUI_EditEvent:IsShown() then
		GearRack.SetEscapable("GearRackUI_Sets_SetSelect",false)
		GearRack.SetEscapable("GearRackUI_EditEvent",false)
		GearRack.SetEscapable("GearRackUI_SetsFrame",true)
	end
	-- Every launcher reaches this callback. Build the draft once, then refresh
	-- equipped icons without replacing its name, selected slots or display choices.
	if not GearRackUI.SetEditorInitialized then
		GearRackUI_Sets_NewSet()
	else
		GearRackUI_Sets_UpdateInventory()
	end
	GearRackUI_DisableAllEvents()
	if GearRackDB.settings.EnableEvents=="ON" then
		sets_message(GearRackUIText.EVENTSSUSPENDED)
	end
end

--[[ Events ]]--

-- changes the font size in the event edit window
function GearRackUI_ChangeEventFont()
	if GearRackDB.settings.LargeFont=="ON" then
		GearRackUI_EventScript:SetFont("Fonts\\FRIZQT__.TTF",12)
	else
		GearRackUI_EventScript:SetFont("Fonts\\FRIZQT__.TTF",9)
	end
end

-- builds eventList, a numerically-indexed list of events and their associated sets
function GearRackUI_Build_eventList()

	local class
	eventListSize = 1
	local oldeventname,eventname

	if GearRackUI.SelectedEvent>0 then
		-- remember old selected event, it may move in the list
		oldeventname = eventList[GearRackUI.SelectedEvent].name
	end

	scratchTableSize[1] = 1 -- size of each table for secondary sort
	scratchTableSize[2] = 1
	table.wipe(scratchTable[1])
	table.wipe(scratchTable[2])

	-- problems with secondary sort, so doing one manually - first split events into two tables: ones with a setname, ones without
	for i in pairs(GearRackDB.events) do
		-- first split
		if type(GearRackDB.events[i])=="table" then
			_,_,class = string.find(i,"^(.+)%:")
			if GearRackDB.settings.ShowAllEvents=="ON" or (not class or class==UnitClass("player")) then
				if GearRackDB.bars[user].Events[i] and GearRackDB.sets[user].Sets[GearRackDB.bars[user].Events[i].setname] then
					scratchTable[1][scratchTableSize[1]] = i
					scratchTableSize[1] = scratchTableSize[1] + 1
				else
					scratchTable[2][scratchTableSize[2]] = i
					scratchTableSize[2] = scratchTableSize[2] + 1
				end
			end
		end
	end
	-- sort each half
	table.sort(scratchTable[1],function(e1,e2) return e1 and e2 and e1<e2 end)
	table.sort(scratchTable[2],function(e1,e2) return e1 and e2 and e1<e2 end)

	-- merge the halves
	eventListSize = 1
	for i=1,scratchTableSize[1]-1 do
		eventname = scratchTable[1][i]
		eventList[eventListSize] = eventList[eventListSize] or {}
		eventList[eventListSize].name = eventname
		eventList[eventListSize].trigger = GearRackDB.events[eventname].trigger
		eventList[eventListSize].delay = GearRackDB.events[eventname].delay
		eventList[eventListSize].script = GearRackDB.events[eventname].script
		eventList[eventListSize].setname = GearRackDB.bars[user].Events[eventname].setname
		eventList[eventListSize].texture = GearRackDB.sets[user].Sets[eventList[eventListSize].setname].icon
		eventList[eventListSize].enabled = GearRackDB.bars[user].Events[eventname].enabled
		eventListSize = eventListSize + 1
	end
	for i=1,scratchTableSize[2]-1 do
		eventname = scratchTable[2][i]
		eventList[eventListSize] = eventList[eventListSize] or {}
		eventList[eventListSize].name = eventname
		eventList[eventListSize].trigger = GearRackDB.events[eventname].trigger
		eventList[eventListSize].delay = GearRackDB.events[eventname].delay
		eventList[eventListSize].script = GearRackDB.events[eventname].script
		eventList[eventListSize].setname = nil
		eventList[eventListSize].texture = nil
		eventList[eventListSize].enabled = nil
		eventListSize = eventListSize + 1
	end

	GearRackUI.SelectedEvent=0
	for i=1,eventListSize-1 do
		if eventList[i].name==oldeventname then
			GearRackUI.SelectedEvent = i
		end
	end

	GearRackUI_Validate_EventList_Buttons()
	GearRackUI_Events_ScrollFrame_Update()
end

-- update for the list of events scrollframe
function GearRackUI_Events_ScrollFrame_Update()

	local idx, button, icon, enable, name
	local offset = FauxScrollFrame_GetOffset(GearRackUI_Events_ScrollFrame)

	FauxScrollFrame_Update(GearRackUI_Events_ScrollFrame, eventListSize-1, 7, 26 )

	for i=1,7 do
		idx = offset + i
		button = _G["GearRackUI_Event"..i]
		if idx<eventListSize then
			local eventsNames = _G["GearRackUI_Event"..i.."Name"]
			if GearRackDB.settings.ShowAllEvents=="ON" then
				eventsNames:SetText(eventList[idx].name)
			else
				_,_,name = string.find(eventList[idx].name,"^.+%:(.+)")
				name = name or eventList[idx].name
				eventsNames:SetText(name)
			end
			eventsNames:SetFont("Fonts\\FRIZQT__.TTF",9)

			icon = _G["GearRackUI_Event"..i.."Icon"]
			enable = _G["GearRackUI_Event"..i.."Enable"]
			if eventList[idx].setname then
				icon:SetNormalTexture(eventList[idx].texture)
				icon:SetPushedTexture(eventList[idx].texture)
				enable:SetChecked(eventList[idx].enabled)
				enable:Show()
			else
				icon:SetNormalTexture("Interface\\Icons\\INV_Misc_QuestionMark")
				icon:SetPushedTexture("Interface\\Icons\\INV_Misc_QuestionMark")
				enable:Hide()
			end
			button:Show()
		else
			button:Hide()
		end
		ns.SelectRow(button,idx==GearRackUI.SelectedEvent)
	end
end

-- onclick for events in the list, to lock highlight
function GearRackUI_EventsList_OnClick(arg1)

	local idx = this:GetID() + FauxScrollFrame_GetOffset(GearRackUI_Events_ScrollFrame)

	if idx<eventListSize then
		GearRackUI.SelectedEvent = (GearRackUI.SelectedEvent==idx) and 0 or idx
	end
	GearRackUI_Validate_EventList_Buttons()
	GearRackUI_Events_ScrollFrame_Update()
end

-- returns the eventList index for the *parent* of "this"
local function event_idx()
	return this:GetParent():GetID() + FauxScrollFrame_GetOffset(GearRackUI_Events_ScrollFrame)
end

function GearRackUI_EventsList_EnableOnClick()

	local idx = event_idx()

	if idx<eventListSize then
		local eventname = eventList[idx].name
		GearRackUI.CancelEvent(eventname)
		if not GearRackDB.bars[user].Events[eventname] then
			GearRackDB.bars[user].Events[eventname] = {}
		end
		GearRackDB.bars[user].Events[eventname].enabled = this:GetChecked()
	end
	GearRackUI_Build_eventList()
end

-- onenter of an event icon either a tooltip for an undefined event or the contents of the set
function GearRackUI_EventsListIcon_OnEnter()

	local idx = event_idx()

	if idx<eventListSize then
		local setname = eventList[idx].setname
		if not setname then
			GearRackUI_OnTooltip(GearRackUIText.UNDEFINEDEVENT_TEXT,GearRackUIText.UNDEFINEDEVENT_TOOLTIP)
		else
			GearRackUI_Sets_Tooltip(setname)
		end
	end
end

function GearRackUI_Validate_EventList_Buttons()

	local selected = GearRackUI.SelectedEvent~=0
	UI.SetEnabled(GearRackUI_Events_DeleteButton,selected)
	UI.SetEnabled(GearRackUI_Events_EditButton,selected)
end

-- clicking event icon summons set selection window
function GearRackUI_EventsListIcon_OnClick()

	local idx = event_idx()

	if idx<eventListSize then
		GearRackUI.SelectedEvent = idx
		GearRackUI_Events_ScrollFrame_Update()
		GearRackUI_Validate_EventList_Buttons()
		GearRackUI_Sets_DropDownButton_OnClick()
	end
end

-- handler for buttons clicked in the events pane
function GearRackUI_EventButtons(v1)

	local i
	local others = ""

	if v1=="Delete" then
		local eventname = eventList[GearRackUI.SelectedEvent].name

		GearRackUI_DisableEvent(eventname)

		i = GearRackDB.bars[user].Events[eventname]
		GearRackDB.bars[user].Events[eventname] = nil

		if not i then

			for i in pairs(GearRackDB.bars) do
				if GearRackDB.bars[i].Events and GearRackDB.bars[i].Events[eventname] then
					others = others..i..", "
				end
			end

			if others=="" then
				sets_message("\""..eventname.."\" removed completely.")
				GearRackDB.events[eventname] = nil
			else
				others = string.gsub(others,", $","")
				sets_message("\""..eventname.."\" is used by: "..others)
			end
		else
			sets_message("\""..eventname.."\" disassociated.")
		end
		GearRackUI_Events_ScrollFrameScrollBar:SetValue(0)
	elseif v1=="New" then
		GearRackUI_EventScript:SetText("")
		GearRackUI_EventName:SetText("")
		GearRackUI_EventTrigger:SetText("")
		GearRackUI_EventDelay:SetText("")
		GearRackUI_EditEvent:Show()
		GearRackUI_EventName:SetFocus()
	elseif v1=="Edit" then
		if GearRackUI.SelectedEvent==0 then
			-- if we're here and SelectedEvent==0, it was a double-click to a selected event. Reselect it
			GearRackUI_EventsList_OnClick("LeftButton")
		end
		-- if SelectedEvent defined, then either edit button or double-click to previously unselected event
		local eventname = eventList[GearRackUI.SelectedEvent].name

		GearRackUI_EventScript:SetText(GearRackDB.events[eventname].script or "")
		GearRackUI_EventName:SetText(eventname)
		GearRackUI_EventTrigger:SetText(GearRackDB.events[eventname].trigger or "")
		GearRackUI_EventDelay:SetText(GearRackDB.events[eventname].delay or "")
		GearRackUI_EditEvent:Show()
		GearRackUI_EventScript:SetFocus()

	elseif v1=="Save" then
		local name = GearRackUI_EventName:GetText()
		if name and string.len(name)>0 then
			GearRackUI.CancelEvent(name)
			if not GearRackDB.events[name] then
				GearRackDB.events[name] = {}
			end
			GearRackDB.events[name].script = GearRackUI_EventScript:GetText()
			GearRackDB.events[name].trigger = GearRackUI_EventTrigger:GetText()
			GearRackDB.events[name].delay = tonumber(GearRackUI_EventDelay:GetText()) or 0
			sets_message("Event \""..name.."\" saved.")
			GearRackUI_EditEvent:Hide()
		else
			sets_message("Event not saved.  Need a name at least.")
		end
	elseif v1=="Test" then
		GearRackUI.RunEventScript(GearRackUI_EventScript:GetText(),GearRackUI_EventName:GetText(),nil,arg1,arg2)
	end
	GearRackUI_Build_eventList()
end

--[[ Event Registration ]]--

GearRackUI.Register = {} -- game events (UNIT_AURA, etc) are stored here

-- Cancel both the deadline and its retained payload.
function GearRackUI.CancelEvent(eventname)
	if GearRackUI.EventTimers[eventname] then
		GearRackUI.EventTimers[eventname]:Cancel()
		GearRackUI.EventTimers[eventname] = nil
	end
	GearRackUI.EventQueue[eventname] = nil
	GearRackUI.EventQueueArg1[eventname] = nil
	GearRackUI.EventQueueArg2[eventname] = nil
	GearRackUI.EventQueueSetName[eventname] = nil
end

-- GEARRACK_DODGED rides on the combat log (ClassicAPI 1.17+). Keep the combat-log
-- registration while either trigger still has an event.
local function release_trigger(trigger)
	if trigger~="COMBAT_LOG_EVENT_UNFILTERED" or not GearRackUI.Register.GEARRACK_DODGED then
		GearRackUI_RegisterFrame:UnregisterEvent(trigger)
	end
	if trigger=="GEARRACK_DODGED" and not GearRackUI.Register.COMBAT_LOG_EVENT_UNFILTERED then
		GearRackUI_RegisterFrame:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
	end
end

-- enables a specific eventname ("Riding","Warrior:Berserk",etc)
function GearRackUI_EnableEvent(eventname)

	if not GearRackDB.events[eventname] then return end

	local trigger = GearRackDB.events[eventname].trigger

	if not GearRackUI.Register[trigger] then
		GearRackUI_RegisterFrame:RegisterEvent(trigger)
		GearRackUI.Register[trigger] = {}
		if trigger=="GEARRACK_DODGED" then
			GearRackUI_RegisterFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
		end
	end
	GearRackUI.Register[trigger][eventname] = 1
end

-- disables a sepcific eventname ("Riding","Warrior:Berserk",etc)
function GearRackUI_DisableEvent(eventname)

	GearRackUI.CancelEvent(eventname)
	if not GearRackDB.events[eventname] then return end

	local trigger = GearRackDB.events[eventname].trigger
	local has_event

	if GearRackUI.Register[trigger] then
		GearRackUI.Register[trigger][eventname] = nil
		for i in pairs(GearRackUI.Register[trigger]) do has_event=1 end
		if not has_event then
			GearRackUI.Register[trigger] = nil
			release_trigger(trigger)
		end
	else
		release_trigger(trigger)
	end
end

-- use this to initialize, enable or refresh Register
function GearRackUI_EnableAllEvents()

	if GearRackDB.settings.EnableEvents~="ON" or GearRack.worldSuspended or GearRackUI_SetsFrame:IsShown() then
		GearRackUI_DisableAllEvents()
		return
	end
	GearRackUI.EventsSuspended = nil

	if GearRackDB.settings.Notify=="OFF" then
		-- if notify is off, see if any GEARRACK_NOTIFY events are registered and turn on notify
		for i in pairs(GearRackDB.bars[user].Events) do
			if GearRackDB.bars[user].Events[i].enabled and GearRackDB.events[i].trigger=="GEARRACK_NOTIFY" then
				GearRackDB.settings.Notify="ON"
--				GearRackUI_Opt_Notify:SetChecked(1)
				DEFAULT_CHAT_FRAME:AddMessage("GearRack: Notify has been turned on for Event: |cFFFFFF00"..i)
			end
		end
	end

	if GearRackDB.settings.EnableEvents=="ON" then
		for i in pairs(GearRackDB.bars[user].Events) do
			if GearRackDB.bars[user].Events[i].enabled then
				GearRackUI_EnableEvent(i)
			else
				GearRackUI_DisableEvent(i)
			end
		end
		GearRackUIFrame:RegisterEvent("PLAYER_AURAS_CHANGED")
	else
		GearRackUI_DisableAllEvents()
	end
end

-- Suspend event watching and cancel retained scripts and payloads.
function GearRackUI_DisableAllEvents()
	GearRackUI.EventsSuspended = true
	GearRackUI_RegisterFrame:UnregisterAllEvents()
	table.wipe(GearRackUI.Register)
	for eventname in pairs(GearRackUI.EventQueue) do GearRackUI.CancelEvent(eventname) end
	table.wipe(GearRackUI.EventQueueArg1)
	table.wipe(GearRackUI.EventQueueArg2)
	table.wipe(GearRackUI.EventQueueSetName)
	GearRackUI_RegisterFrame:Hide()
	GearRackUIFrame:UnregisterEvent("PLAYER_AURAS_CHANGED")
end

--[[ Event Processing ]]--

GearRackUI.EventQueue = {} -- deadlines for delayed scripts; never persisted
GearRackUI.EventTimers = {} -- cancellable ClassicAPI handles

-- Retain only the event payload and association used by the script dispatcher.
GearRackUI.EventQueueArg1 = {} -- indexed by events also, values of arg1
GearRackUI.EventQueueArg2 = {} -- indexed by events also, values of arg2
GearRackUI.EventQueueSetName = {} -- association that was active when queued

-- User scripts keep their global environment; only dispatch context is restored.
-- Exact saved definitions own one compiled chunk. Unsaved editor tests bypass it.
local compiledEventScripts = setmetatable({}, {__mode="k"})
function GearRackUI.RunEventScript(script,eventname,setname,a1,a2)
	local chunkName = "GearRack event: "..tostring(eventname)
	local definition = GearRackDB.events[eventname]
	local environment = getfenv(0)
	local func,err,cached,reused
	-- Lua 5.0 can hide/protect environments through __fenv. Fresh loadstring
	-- still works there; cache only the accessible native global environment.
	local cacheable = environment==_G and rawget(_G,"__fenv")==nil
	if cacheable and type(definition)=="table" and type(script)=="string" and script==definition.script then
		cached = compiledEventScripts[definition]
		if cached and cached.active then
			-- A nested dispatch must not change the running chunk's environment.
			cached = nil
			func,err = loadstring(script,chunkName)
		else
			if not cached or cached.source~=script or cached.name~=chunkName then
				func,err = loadstring(script,chunkName)
				cached = {source=script,name=chunkName,func=func,err=err}
				compiledEventScripts[definition] = cached
			else
				reused = true
			end
			func,err = cached.func,cached.err
		end
	else
		func,err = loadstring(script or "",chunkName)
	end
	if func then
		-- An externally retained chunk may have acquired a custom environment.
		-- Recompile instead of changing it. The protected probe also catches a
		-- Lua 5.0 __fenv sentinel that impersonates the native global table.
		if reused and (getfenv(func)~=environment or not pcall(setfenv,func,environment)) then
			func,err = loadstring(script,chunkName)
			cached.func,cached.err = func,err
		end
		if cached then cached.active = true end
		local oldSet,oldName = GearRackUI.EventSetName,GearRackUI.EventEventName
		local oldThis,oldEvent,oldArg1,oldArg2 = this,event,arg1,arg2
		GearRackUI.EventSetName,GearRackUI.EventEventName = setname,eventname
		arg1,arg2 = a1,a2
		local ok
		ok,err = pcall(func)
		this,event,arg1,arg2 = oldThis,oldEvent,oldArg1,oldArg2
		GearRackUI.EventSetName,GearRackUI.EventEventName = oldSet,oldName
		if cached then
			cached.active = nil
			-- A custom environment can retain the weak key through the chunk.
			-- Evict rather than changing an environment the user may have kept.
			if (getfenv(func)~=environment or not pcall(setfenv,func,environment))
				and compiledEventScripts[definition]==cached then
				compiledEventScripts[definition] = nil
			end
		end
		if ok then return end
	end
	DEFAULT_CHAT_FRAME:AddMessage("GearRack event \""..tostring(eventname).."\": "..tostring(err),1,0.2,0.2)
end

local function event_is_enabled(eventname)
	local definition = GearRackDB.events[eventname]
	local association = GearRackDB.bars[user].Events[eventname]
	return GearRackDB.settings.EnableEvents=="ON" and not GearRackUI.EventsSuspended
		and definition and association and association.enabled and association.setname
		and GearRackDB.sets[user].Sets[association.setname]
		and GearRackUI.Register[definition.trigger] and GearRackUI.Register[definition.trigger][eventname]
end

-- runs the eventname script, event = "Riding", "Warrior:Battle", etc
local function run_event_script(eventname,a1,a2)
	if not event_is_enabled(eventname) then return end
	GearRackUI.RunEventScript(GearRackDB.events[eventname].script,eventname,
		GearRackDB.bars[user].Events[eventname].setname,a1,a2)
end

-- events("triggers") defined in game go through here
-- Game events arrive with their payload in arg1/arg2; GearRack's own triggers
-- pass it directly.
function GearRackUI_RegisterFrame_OnEvent(ev, a1, a2)
	if a1==nil then a1, a2 = arg1, arg2 end

	-- A swing, spell or shot of yours was dodged: arg1 is the GUID of the unit that dodged.
	-- Swing suffix values start at arg12; SPELL_ and RANGE_ suffix values at arg15.
	if ev=="COMBAT_LOG_EVENT_UNFILTERED" and GearRackUI.Register.GEARRACK_DODGED then
		local missType
		if arg2=="SWING_MISSED" then
			missType = arg12
		elseif arg2=="SPELL_MISSED" or arg2=="RANGE_MISSED" then
			missType = arg15
		end
		if missType=="DODGE" and arg4==UnitGUID("player") then
			GearRackUI_RegisterFrame_OnEvent("GEARRACK_DODGED", arg8)
		end
	end

	if GearRackUI.Register[ev] then
		for i in pairs(GearRackUI.Register[ev]) do
			if event_is_enabled(i) and GearRackDB.events[i].delay==0 then
				-- EventSetName is the name of the set to use for EquipSet(), it's the set associated with the event
				run_event_script(i,a1,a2)
			elseif event_is_enabled(i) then
				GearRackUI.CancelEvent(i)
				GearRackUI.EventQueue[i] = GetTime()+GearRackDB.events[i].delay
				GearRackUI.EventQueueArg1[i] = a1
				GearRackUI.EventQueueArg2[i] = a2
				GearRackUI.EventQueueSetName[i] = GearRackDB.bars[user].Events[i].setname
				local eventname = i
				local handle
				handle = C_Timer.NewTimer(GearRackDB.events[i].delay,function()
					if GearRackUI.EventTimers[eventname]~=handle then return end
					local payload1,payload2,setname = GearRackUI.EventQueueArg1[eventname],GearRackUI.EventQueueArg2[eventname],GearRackUI.EventQueueSetName[eventname]
					GearRackUI.CancelEvent(eventname)
					if event_is_enabled(eventname) and GearRackDB.bars[user].Events[eventname].setname==setname then
						run_event_script(eventname,payload1,payload2)
					end
				end)
				GearRackUI.EventTimers[i] = handle
			end
		end
	end
end

-- Restore the equipment displaced by the named set or current event.
function GearRackUI_LoadSet(setname)

	if not setname and GearRackUI.EventSetName then
		setname = GearRackUI.EventSetName
	end

	GearRackEngine.UnequipSet(setname)
end

function GearRackUI_ToggleEvents()

	if GearRackDB.settings.EnableEvents=="OFF" then
		GearRackDB.settings.EnableEvents="ON"
		GearRackUI_Opt_EnableEvents:SetChecked(1)
		GearRackUI_EnableAllEvents()
		DEFAULT_CHAT_FRAME:AddMessage("GearRack: events |cFF55FF55on")
	else
		GearRackDB.settings.EnableEvents="OFF"
		GearRackUI_Opt_EnableEvents:SetChecked(nil)
		GearRackUI_DisableAllEvents()
		DEFAULT_CHAT_FRAME:AddMessage("GearRack: events |cFFFF5555off")
	end
end

function GearRackUI_EventsList_OnEnter()
	local idx,notes = this:GetID() + FauxScrollFrame_GetOffset(GearRackUI_Events_ScrollFrame)

	if eventList[idx].name and GearRackDB.settings.ShowTooltips=="ON" then
		set_tooltip_anchor(this)
		GameTooltip:AddLine(eventList[idx].name)
		if eventList[idx].setname then
			GameTooltip:AddLine("Set: "..eventList[idx].setname)
		end
		_,_,notes = string.find(eventList[idx].script or "","--%[%[(.+)%]%]")
		if notes then
			GameTooltip:AddLine(notes,.8,.8,.8,1)
		end
		GameTooltip:Show()
	end
end

-- toggles a set, remembering what it wore previous to equipping the set
function GearRackUI_ToggleSet(setname)
	GearRackEngine.ToggleSet(setname)
end

--Event script helper functions
--These are not necessary.  They can be completely encapsulated in the scripts themselves.  They're here for convenience.

-- returns the name of the form the player is in
function GearRackUI_GetForm()

	local name,form,is_active

	for i=1,GetNumShapeshiftForms() do
		_,name,is_active = GetShapeshiftFormInfo(i)
		if is_active then
			form = name
		end
	end
	return form
end

-- gathers active buffs into GearRackUI.Buffs and sends it via RegisterFrame for events
local buffSlots = {}
function GearRackUI_BuffsChanged()
	table.wipe(GearRackUI.Buffs)
	local _,count = C_UnitAuras.GetAuraSlots("player", "HELPFUL", nil, nil, buffSlots)
	for s = 1, count do
		local name,icon = C_UnitAuras.UnitAuraBySlot("player", buffSlots[s])
		if name then GearRackUI.Buffs[name] = 1 end
		if icon then GearRackUI.Buffs[icon] = 1 end
	end
	local oldarg1 = arg1
	arg1=GearRackUI.Buffs
	GearRackUI_RegisterFrame_OnEvent("GEARRACK_BUFFS_CHANGED")
	arg1 = oldarg1
end

-- returns 1 if all pieces of setname are equipped, nil otherwise
function GearRackUI_IsSetEquipped(setname)
	return GearRackEngine.IsSetEquipped(setname)
end

-- returns three parameters: table of sets, current set name, current set texture
function GearRackUI_GetUserSets()
	local texture = "Interface\\AddOns\\GearRack\\media\\GearRack-Icon.tga"
	local setname = GearRackUI_CurrentSet()
	if setname and GearRackDB.sets[user].Sets[setname] and not string.find(setname,"^GearRackEngine") and not string.find(setname,"^GearRackUI") then
		texture = GearRackDB.sets[user].Sets[setname].icon
	end
	return GearRackDB.sets[user].Sets, setname, texture
end

--[[ Bundled GearRackEngine equipment engine begins here.
	GearRackUI's UI and automation share this file with the GearRackEngine equipment engine. ]]

GearRackEngine = {
	TimerPool = {}, -- runtime timer metadata and cancellable ClassicAPI handles

	SetSwapping = nil, -- name of a set currently being swapped
	SwapList = {}, -- individual item swap details go here
	LockList = {}, -- tables of bags where slots are locked (to be skipped in FindItem and FindSpace)
	CombatQueue = {}, -- table of items to swap in when dropping out of combat/death
	CombatQueueOwner = {} -- request owning each deferred slot (nil for manual queue entries)
}

GearRackEngine.SlotInfo = {
	[0] = { name="AmmoSlot", swappable=1, INVTYPE_AMMO=1 },
	[1] = { name="HeadSlot", INVTYPE_HEAD=1 },
	[2] = { name="NeckSlot", INVTYPE_NECK=1 },
	[3] = { name="ShoulderSlot", INVTYPE_SHOULDER=1 },
	[4] = { name="ShirtSlot", INVTYPE_BODY=1 },
	[5] = { name="ChestSlot", INVTYPE_CHEST=1, INVTYPE_ROBE=1 },
	[6] = { name="WaistSlot", INVTYPE_WAIST=1 },
	[7] = { name="LegsSlot", INVTYPE_LEGS=1 },
	[8] = { name="FeetSlot", INVTYPE_FEET=1 },
	[9] = { name="WristSlot", INVTYPE_WRIST=1 },
	[10] = { name="HandsSlot", INVTYPE_HAND=1 },
	[11] = { name="Finger0Slot", INVTYPE_FINGER=1 },
	[12] = { name="Finger1Slot", INVTYPE_FINGER=1 },
	[13] = { name="Trinket0Slot", INVTYPE_TRINKET=1 },
	[14] = { name="Trinket1Slot", INVTYPE_TRINKET=1 },
	[15] = { name="BackSlot", INVTYPE_CLOAK=1 },
	[16] = { name="MainHandSlot", swappable=1, INVTYPE_WEAPONMAINHAND=1, INVTYPE_2HWEAPON=1, INVTYPE_WEAPON=1 },
	[17] = { name="SecondaryHandSlot", swappable=1, INVTYPE_WEAPON=1, INVTYPE_WEAPONOFFHAND=1, INVTYPE_SHIELD=1, INVTYPE_HOLDABLE=1 },
	[18] = { name="RangedSlot", swappable=1, INVTYPE_RANGED=1, INVTYPE_THROWN=1, INVTYPE_RANGEDRIGHT=1 },
	[19] = { name="TabardSlot", INVTYPE_TABARD=1 },
}

--[[ Initialization ]]

function GearRackEngine.Initialize()

	for i=0,19 do GearRackEngine.SwapList[i]={} end -- create blank SwapList table
	for i=-2,10 do GearRackEngine.LockList[i]={} end -- create a blank Locked table

	if not GearRackDB.sets then
		GearRackDB.sets = {}
	end

	if not GearRackDB.sets[user] then
		GearRackDB.sets[user] = { Sets={}, CurrentSet=nil }
	end

	-- note: these timers are added to a pool, they don't affect processing time unless started
	GearRackEngine.CreateTimer("WaitToIterate",GearRackEngine.IterateWait,1) -- itemlock iterate pause
	GearRackEngine.CreateTimer("IconDragging",GearRackEngine.IconDragging,0,1) -- minimap button dragging
	GearRackEngine.CreateTimer("ScaleUpdate",GearRackEngine.ScaleUpdate,.1,1) -- scaling
	GearRackEngine.CreateTimer("TooltipUpdate",GearRackEngine.TooltipUpdate,1,1) -- tooltip update
	GearRackEngine.CreateTimer("ControlFrame",GearRackEngine.ControlFrame,.75,1) -- controls on bar
	GearRackEngine.CreateTimer("CooldownUpdate",GearRackUI_CooldownUpdate_OnUpdate,1,1) -- cooldown/notify
	GearRackEngine.CreateTimer("MenuFrame",GearRackEngine.MenuFrame,.25,1) -- menu mouseover check
	GearRackEngine.CreateTimer("InvUpdate",GearRackUI_InvUpdate_OnUpdate,.05,1) -- one redraw per burst of changes, a few frames later
	GearRackEngine.CreateTimer("BankTransferCheck",GearRackEngine.ReconcileBankTransfer,.2)
end

function GearRackEngine.OnEvent(ev)
	if GearRack.worldSuspended then return end
	ev = ev or event

	if ev=="ITEM_LOCK_CHANGED" then
		GearRackEngine.ReconcileBankTransfer()
		GearRackEngine.OnItemLockChanged()
		GearRack.Wake()
	elseif ev=="PLAYER_REGEN_ENABLED" or ev=="PLAYER_UNGHOST" or ev=="PLAYER_ALIVE" then
		if GearRackEngine.IsPlayerReallyDead() then return end
		GearRack.Wake()
		-- Finish the active transaction before consuming deferred work.
		if GearRackEngine.SwapRequest then GearRackEngine.IterateSwapQueue();return end
		if UnitAffectingCombat("player") then return end
		local somethingQueued
		local items = {}
		for i=0,19 do
			if GearRackEngine.CombatQueue[i] then
				local owner=GearRackEngine.CombatQueueOwner[i]
				local wanted=owner and owner.items and owner.items[i]
				items[i] = {id=GearRackEngine.CombatQueue[i],name=wanted and wanted.name,guid=wanted and wanted.guid}
				GearRackEngine.CombatQueue[i] = nil
				GearRackEngine.CombatQueueOwner[i] = nil
				somethingQueued = 1
			end
			_G["GearRackUIInv"..i.."Queue"]:Hide()
			_G[GearRackUI.Indexes[i].paperdoll_slot.."Queue"]:Hide()
		end
		if somethingQueued then
			GearRackEngine.EquipSet("GearRackEngine-CombatQueue",nil,{items=items,completionOf=GearRackEngine.PendingCombatRequest})
		end
	end
end

--[[ Item information ]]

-- Returns texture, variant ID, name, equip location, quality and raw base ID.
-- The final value identifies cold container items before their link is available.
function GearRackEngine.GetItemInfo(bag,slot)
	local id,itemLink,itemID,itemSlot,itemTexture,itemName,itemQuality,rawID

	if slot then -- this is a container item
		rawID=C_Container.GetContainerItemID(bag,slot)
		if not rawID then return nil end
		itemLink = GetContainerItemLink(bag,slot)
	else
		itemLink = GetInventoryItemLink("player",bag)
		itemQuality = GetInventoryItemQuality("player",bag)
	end

	if itemLink then
		_,_,id = string.find(itemLink,"(item:%d+:%-?%d+:%-?%d+:%-?%d+)")
		_,_,itemID = string.find(id or "","item:(%d+:%-?%d+:%-?%d+):%-?%d+")
		local q
		itemName,_,q,_,_,_,_,itemSlot,itemTexture = GetItemInfo(id or itemLink)
		itemQuality = itemQuality or q
	elseif not slot then -- if no link and this is an inventory slot, missing or ammo
		_,itemTexture = GetInventorySlotInfo(GearRackEngine.SlotInfo[bag].name) -- get paperdoll texture
		itemID = 0 -- assume empty slot
		-- The ammo slot has no item link. NamPower names the equipped ammo directly;
		-- ammo has no enchant or suffix, so its variant ID is "<id>:0:0".
		local ammoID = bag==0 and GetAmmo()
		if ammoID then
			local q,texture
			itemName,_,q,_,_,_,_,itemSlot,texture = GetItemInfo(ammoID)
			itemID = ammoID..":0:0"
			itemQuality = GetInventoryItemQuality("player",0) or q
			itemTexture = GetInventoryItemTexture("player",0) or texture or itemTexture
		end
	end

	if not itemQuality and slot then
		if rawID then
			local _, _, q = GetItemInfo(rawID)
			itemQuality = q
		end
	end

	return itemTexture, itemID, itemName, itemSlot, itemQuality,rawID
end

-- converts a name to an itemID by searching through inventory, bags and bank for the item
function GearRackEngine.GetItemID(itemName)

	local inv,bag,slot = GearRackEngine.FindItem(nil,itemName)
	local itemID

	if inv then
		_,itemID = GearRackEngine.GetItemInfo(inv)
	elseif bag and slot then
		_,itemID = GearRackEngine.GetItemInfo(bag,slot)
	end

	return itemID
end

-- returns the name and texture of an item by its itemID
function GearRackEngine.GetNameByID(itemID)
	local name,texture
	local _,_,id = string.find(itemID or "","^(%d+):%-?%d+:%-?%d+$")
	name,_,_,_,_,_,_,_,texture = GetItemInfo(id or "")
	if itemID==0 then
		name = "(empty)"
		texture = "Interface\\PaperDoll\\UI-Backpack-EmptySlot"
	end
	return name,texture
end

-- returns true if the bagid (0-4) is a normal "Container", as opposed to quivers and ammo pouches
-- True for a general-purpose bag (not a quiver, ammo pouch or other special bag).
function GearRackEngine.ValidBag(bagid)
	if bagid==0 or bagid==-1 then return true end
	if bagid<=4 then
		local _,bagType = C_Container.GetContainerNumFreeSlots(bagid)
		return bagType==0
	end
	-- Bank bags report no family from GetContainerNumFreeSlots; ask the bag item.
	local link = GetInventoryItemLink("player",ContainerIDToInventoryID(bagid))
	return link and C_Item.GetItemFamily(link)==0 or false
end

function GearRackEngine.FindSpaceInBag(bag)
	if GearRackEngine.ValidBag(bag) then
		for j=1,GetContainerNumSlots(bag) do
			if not GearRackEngine.LockList[bag][j] then
				if not C_Container.HasContainerItem(bag,j) then
					return j
				end
			end
		end
	end
end

-- pass a value for bank to find a free bank slot
function GearRackEngine.FindSpace(bank)
	local slot
	if bank and GearRackUI.BankIsOpen then -- search bank
		for _,i in ipairs(GearRackUI.BankSlots) do
			slot = GearRackEngine.FindSpaceInBag(i)
			if slot then
				GearRackEngine.LockList[i][slot] = 1
				return i,slot
			end
		end
	else
		for i=4,0,-1 do
			slot = GearRackEngine.FindSpaceInBag(i)
			if slot then
				GearRackEngine.LockList[i][slot] = 1
				return i,slot
			end
		end
	end
end

-- clears locks on all bag slots
function GearRackEngine.ClearLockList(bag,slot)
	if not bag then
		for i=-2,10 do
			for j in pairs(GearRackEngine.LockList[i]) do
				GearRackEngine.LockList[i][j] = nil
			end
		end
	else
		GearRackEngine.LockList[bag][slot] = nil
	end
end

-- returns inv,bag,slot of an itemID, or itemName if itemID doesn't exist
function GearRackEngine.FindItem(itemID,itemName,passive)
    local inv,bag,slot=GearRack.FindLocation(itemID,itemName,passive,true)
    if not inv and not bag and itemName then return GearRack.FindLocation(nil,itemName,passive,true) end
    return inv,bag,slot
end

-- performs a FindItem on a set entry ([0]-[19]) and updates itemid if one wasn't there
function GearRackEngine.FindSetItem(setslot)
	local inv,bag,slot
	if setslot.guid then inv,bag,slot=GearRack.FindLocation(setslot.id,setslot.name,nil,true,setslot.guid)
	else inv,bag,slot=GearRackEngine.FindItem(setslot.id,setslot.name) end
	if not setslot.id and setslot.name and (inv or bag or slot) then
		setslot.id = GearRackEngine.GetItemID(setslot.name)
	end
	return inv,bag,slot
end

--[[ Queue maintenance

	To prevent garbage creation in creating/destroying multi-level tables, queue entries are reused and only
	the index to that queue entry is created/destroyed.

	.SwapQueue is where the tables sit, indexed arbitrarily by the first available one returned by GetFreeQueueEntry
	.SwapQueueOrder is a numerically-indexed table of indexes into .SwapQueue in the order the swap should happen
]]

GearRackEngine.SwapQueue = { [1]={ direction = "END" } } -- numerically-indexed queue of swaps to perform
GearRackEngine.SwapQueueOrder = {} -- numerically-indexed queue of numbers in the order they're to be performed

-- Read-only coordination point for addons that must not issue equipment moves
-- while an GearRackUI transaction or deferred combat swap owns the equipment.
function GearRackEngine.IsEquipmentSwapActive()
	return GearRackEngine.BankTransfer~=nil or GearRackEngine.SwapRequest~=nil or GearRackEngine.SetSwapping~=nil or GearRackEngine.SwapIssuing~=nil or #GearRackEngine.SwapQueueOrder>0
		or GearRackEngine.PendingCombatRequest~=nil or next(GearRackEngine.CombatQueue)~=nil or GearRack.HasPending()
end
GearRackEngine.SwapUndo = {} -- implicit weapon-slot changes; never written into saved sets
GearRackEngine.UndoToken = {} -- identifies the successful request whose undo data is retained
GearRackEngine.UndoOwner = {} -- saved definition owning this session's undo history

function GearRackEngine.ForgetSetUndo(setname)
	GearRackEngine.SwapUndo[setname]=nil
	GearRackEngine.UndoToken[setname]=nil
	GearRackEngine.UndoOwner[setname]=nil
end

-- wipes out an entry without creating garbage
function GearRackEngine.ClearQueueEntry(idx)

	GearRackEngine.SwapQueue[idx].direction = nil
	GearRackEngine.SwapQueue[idx].setname = nil
	GearRackEngine.SwapQueue[idx].restoreSetName = nil
	GearRackEngine.SwapQueue[idx].context = nil
	GearRackEngine.SwapQueue[idx].started = nil
	GearRackEngine.SwapQueue[idx].deadline = nil
	GearRackEngine.SwapQueue[idx].lastAttempt = nil
	for i=0,19 do
		GearRackEngine.SwapQueue[idx][i].id = nil
		GearRackEngine.SwapQueue[idx][i].fromBag = nil
		GearRackEngine.SwapQueue[idx][i].fromSlot = nil
		GearRackEngine.SwapQueue[idx][i].guid = nil
	end
end

-- creates a new table and sub-table queue entries, only call when entry didn't exist before
function GearRackEngine.ConstructQueueEntry(idx)
	GearRackEngine.SwapQueue[idx] = {}
	for i=0,19 do
		GearRackEngine.SwapQueue[idx][i] = {}
	end
end

-- get first available index into SwapQueue for use for a set. to avoid garbage creation these are reused
function GearRackEngine.GetFreeQueueEntry()
	local i,found = 1,1

	while found do
		found = GearRackEngine.SwapQueue[i]
		if found and not found.direction then
			return i
		end
		i = i + 1
	end
	i = i - 1 -- backtrack to last available entry

	GearRackEngine.ConstructQueueEntry(i)
	return i
end

-- adds the .SwapQueue idx to the end of the QueueOrder
function GearRackEngine.AddQueueEntry(idx)
	table.insert(GearRackEngine.SwapQueueOrder,idx)
end

-- removes the .SwapQueue idx from QueueOrder and clears the .SwapQueue entry
function GearRackEngine.RemoveQueueEntry(idx)
	for i=1,#GearRackEngine.SwapQueueOrder do
		if GearRackEngine.SwapQueueOrder[i]==idx then
			table.remove(GearRackEngine.SwapQueueOrder,i)
			GearRackEngine.ClearQueueEntry(idx)
			return
		end
	end
end

-- this sorts the queue, moving all NEWSETs to the end
function GearRackEngine.SortQueue()

	if #GearRackEngine.SwapQueueOrder>1 then
		local found,temp = 1
		local queue = GearRackEngine.SwapQueueOrder
		-- simple shell sort (this is a small, 5-6 max typically) table of indexes that must remain in order otherwise
		while found do
			found = nil
			for i=1,(#queue-1) do
				if GearRackEngine.SwapQueue[queue[i]].direction=="NEWSET" and GearRackEngine.SwapQueue[queue[i+1]].direction~="NEWSET" then
					temp = queue[i]
					queue[i] = queue[i+1]
					queue[i+1] = temp
					found = 1
				end
			end
		end
	end
end

--[[ Set Maintenance

	Sets are tables in GearRackDB.sets[user].Sets[setname] structured as:
	{ hide=1/nil, icon="Interface\\Icons\\etc", ["0"]={id=string,name=string,old=string} }
	id = itemID for the item to wear in the set, 0 for (empty) (can be nil)
	name = name of the item to wear in the set, (empty) for empty
	old = itemID for the item worn in this slot prior to this set equipped, usually nil
]]

function GearRackEngine.ClearSwapListEntry(idx)
	GearRackEngine.SwapList[idx].needsSwap = nil
	GearRackEngine.SwapList[idx].sourceInv = nil
	GearRackEngine.SwapList[idx].sourceBag = nil
	GearRackEngine.SwapList[idx].sourceSlot = nil
	GearRackEngine.SwapList[idx].direction = nil
	GearRackEngine.SwapList[idx].desiredName = nil
	GearRackEngine.SwapList[idx].needsEmptied = nil
end

-- returns the currently worn set, or last set worn
function GearRackEngine.CurrentSet()
	return GearRackDB.sets[user].CurrentSet
end

--[[ EquipSet
	This function takes a setname and then equips the set, saving what it's replacing within the set.
]]

-- Unlike IsSetEquipped, completion checks actual equipment, not the combat queue.
function GearRackEngine.SlotMatches(slot,wanted)
    local _,id,name=GearRackEngine.GetItemInfo(slot)
    return (not wanted.id or id==wanted.id) and (wanted.id or name==wanted.name)
        and (not wanted.guid or GearRack.EquippedGUID(slot)==wanted.guid)
end

function GearRackEngine.SwapMatches(items)
	for i=0,19 do
		local wanted = items[i]
		if wanted and (wanted.id or wanted.name) then
			local _,id,name = GearRackEngine.GetItemInfo(i)
			if (wanted.id and id~=wanted.id) or (not wanted.id and name~=wanted.name)
                or (wanted.guid and GearRack.EquippedGUID(i)~=wanted.guid) then
				return false
			end
		end
	end
	return true
end

local function capture_saved_definition(name)
	local definition=GearRackDB.sets[user].Sets[name]
	if not definition then return end
	local items={showhelm=definition.showhelm,showcloak=definition.showcloak}
	for i=0,19 do
		local item=definition[i]
		if item then items[i]={id=item.id,name=item.name,guid=item.guid} end
	end
	return {definition=definition,items=items}
end

local function owns_saved_definition(name,owner)
	local definition=GearRackDB.sets[user].Sets[name]
	if not owner or definition~=owner.definition or definition.showhelm~=owner.items.showhelm
		or definition.showcloak~=owner.items.showcloak then return end
	for i=0,19 do
		local item,wanted=definition[i],owner.items[i]
		if (item and not wanted) or (wanted and not item)
			or (item and (item.id~=wanted.id or item.name~=wanted.name or item.guid~=wanted.guid)) then return end
	end
	return true
end

function GearRackEngine.CompleteSwapRequest(request)
	if not request.cancelled and not request.superseded and not request.missing and GearRackEngine.SwapMatches(request.items) then
		local saved = GearRackDB.sets[user].Sets[request.setname]
		local ownsDefinition=owns_saved_definition(request.setname,request.definitionOwner)
		if request.undo and saved and ownsDefinition and not request.undoOf and request.setname~="GearRackEngine-CombatQueue" then
			for i=0,19 do
				if request.undo[i] and saved[i] then saved[i].old = request.undo[i] end
			end
			saved.oldsetname = request.previousSetName
			GearRackEngine.SwapUndo[request.setname] = request.implicitUndo
			GearRackEngine.UndoToken[request.setname] = request.undoToken
			GearRackEngine.UndoOwner[request.setname] = request.definitionOwner
		end
		if request.undoOf and GearRackEngine.UndoToken[request.undoOf]==request.sourceUndoToken then
			local old = GearRackDB.sets[user].Sets[request.undoOf]
			if old and owns_saved_definition(request.undoOf,request.undoMetadataOwner) then
				for i=0,19 do if old[i] then old[i].old = nil end end
				old.oldsetname = nil
			end
			GearRackEngine.ForgetSetUndo(request.undoOf)
		end
		local name = request.restoreSetName or request.setname
		local nameOwner=request.restoreSetName and request.restoreDefinitionOwner or request.definitionOwner
		if name and owns_saved_definition(name,nameOwner)
			and (not request.restoreSetName or GearRackEngine.SwapMatches(nameOwner.items))
			and not string.find(name,"^GearRackEngine-") and not string.find(name,"^GearRackUI") then
			GearRackDB.sets[user].CurrentSet = name
		end
		if request.completionOf and GearRackEngine.PendingCombatRequest==request.completionOf then
			GearRackEngine.CompleteSwapRequest(request.completionOf)
			GearRackEngine.PendingCombatRequest = nil
		end
		return true
	end
end

-- Cancel only slots still owned by this request; manual queue entries survive.
function GearRackEngine.CancelDeferredRequest(request)
	if not request then return end
	request.cancelled = true
	for i=0,19 do
		if GearRackEngine.CombatQueueOwner[i]==request then
			GearRackEngine.CombatQueue[i] = nil
			GearRackEngine.CombatQueueOwner[i] = nil
			_G["GearRackUIInv"..i.."Queue"]:Hide()
			_G[GearRackUI.Indexes[i].paperdoll_slot.."Queue"]:Hide()
		end
	end
	if GearRackEngine.PendingCombatRequest==request then GearRackEngine.PendingCombatRequest = nil end
end

-- A manual item choice replaces one deferred slot, not the entire set's work.
-- Remaining pieces can equip, but a superseded set must not claim completion.
function GearRackEngine.OverrideDeferredSlot(slot)
    local owner=GearRackEngine.CombatQueueOwner[slot]
    if owner then
        owner.superseded=true
        if GearRackEngine.PendingCombatRequest==owner then GearRackEngine.PendingCombatRequest=nil end
    end
    GearRackEngine.CombatQueue[slot]=nil
    GearRackEngine.CombatQueueOwner[slot]=nil
end

function GearRackEngine.EquipSet(setname,restoreSetName,context)

	local bag,slot,id,swap,idx,inv,sourceEquipSlot,destEquipSlot
	local saved = GearRackDB.sets[user].Sets[setname]
	local definition = context and context.items or saved
	local set = {}
	local hasINVTOBAG, hasINVTOINV, hasBAGTOINV
	local missing = "GearRack could not find: "
	local invStart,invEnd = 1,19 -- changes to 16,18 if in combat

	if not definition then
		DEFAULT_CHAT_FRAME:AddMessage("GearRack: Set \""..setname.."\" doesn't exist.")
		return
	end

	for i=0,19 do
		if definition[i] then set[i] = { id=definition[i].id, name=definition[i].name, guid=definition[i].guid } end
	end
	set.showhelm,set.showcloak = definition.showhelm,definition.showcloak
	-- Accept a set once, when requested. A later item click must survive even
	-- if this set waits behind another transaction before it begins.
	context = context or {items=set}
	if not context.intent and not context.accepted and not string.find(setname,"^GearRackEngine-CombatQueue") then
		context.accepted=true
		context.definitionOwner=capture_saved_definition(setname)
		if context.undoOf then context.undoMetadataOwner=capture_saved_definition(context.undoOf) end
		if restoreSetName then context.restoreDefinitionOwner=capture_saved_definition(restoreSetName) end
		for slot in pairs(set) do
			if type(slot)=="number" then
				GearRack.Requests[slot]=nil
				if GearRack.initialized then GearRack.KeepManualTrinket(slot) end
			end
		end
		if GearRack.initialized then GearRack.UpdateQueuePresentation() end
	end
	-- A repeated click is still a new explicit choice for the set's slots.
	-- Reuse an unchanged active owner only when no later set must run first.
	local active=GearRackEngine.SwapRequest
	if GearRackEngine.SetSwapping==setname and active and not active.superseded and not active.cancelled and not active.missing
		and active.restoreSetName==restoreSetName and owns_saved_definition(setname,active.definitionOwner) then
		local waitingSet
		for _,queuedIndex in ipairs(GearRackEngine.SwapQueueOrder) do
			if GearRackEngine.SwapQueue[queuedIndex].direction=="NEWSET" then waitingSet=true;break end
		end
		if not waitingSet then GearRackEngine.OnItemLockChanged();return end
	end
	if GearRackEngine.SwapRequest or GearRackEngine.BankTransfer then
		-- come back later, an EquipSet is in progress
		idx = GearRackEngine.GetFreeQueueEntry()
		GearRackEngine.AddQueueEntry(idx)
		GearRackEngine.SwapQueue[idx].direction = "NEWSET"
		GearRackEngine.SwapQueue[idx].setname = setname
		GearRackEngine.SwapQueue[idx].restoreSetName = restoreSetName
		GearRackEngine.SwapQueue[idx].context = context or {items=set}
		return
	end

	GearRackEngine.ClearLockList()
	-- Temporary weapon requirements belong to this request, not to the saved set.
	local implicit = {}
	local mainType
	if set[16] and set[16].id~=0 and (set[16].id or set[16].name) then
		inv,bag,slot = GearRackEngine.FindSetItem(set[16])
		if inv or bag then _,_,_,mainType = GearRackEngine.GetItemInfo(inv or bag,slot) end
	end
	if mainType=="INVTYPE_2HWEAPON" then
		implicit[17] = not set[17] or set[17].id~=0
		set[17] = { id=0 }
	elseif set[17] and set[17].id~=0 and (set[17].id or set[17].name) and not (set[16] and (set[16].id or set[16].name)) then
		local _,_,_,wornType = GearRackEngine.GetItemInfo(16)
		if wornType=="INVTYPE_2HWEAPON" then
			implicit[16] = true
			set[16] = { id=0 }
		end
	end
	local request = { setname=setname, restoreSetName=restoreSetName, items=set, deferred={} }
	if context then
		request.undoOf,request.sourceUndoToken = context.undoOf,context.sourceUndoToken
		request.completionOf = context.completionOf
		request.intent,request.persistent = context.intent,context.persistent
		request.definitionOwner=context.definitionOwner
		request.undoMetadataOwner=context.undoMetadataOwner
		request.restoreDefinitionOwner=context.restoreDefinitionOwner
	end
	local _,_,_,wornMainType = GearRackEngine.GetItemInfo(16)
	request.offhandAfterMain = wornMainType=="INVTYPE_2HWEAPON" and set[16] and set[16].id~=0 and set[17] and set[17].id~=0
	local deferredOwner=GearRackEngine.PendingCombatRequest
	if deferredOwner and deferredOwner.setname==setname and not deferredOwner.superseded and not deferredOwner.cancelled
		and owns_saved_definition(setname,deferredOwner.definitionOwner) and GearRackEngine.IsSetEquipped(setname) then
		return -- repeated requests must not toggle off already-deferred equipment
	end
	if setname~="GearRackEngine-CombatQueue" and not request.intent then
		GearRackEngine.CancelDeferredRequest(GearRackEngine.PendingCombatRequest)
	end
	if not GearRackEngine.AnyLocked() and not CursorHasItem() and GearRackEngine.CompleteSwapRequest(request) then
		GearRackEngine.StartTimer("InvUpdate")
		return
	end
	GearRackEngine.SwapRequest = request
	GearRackEngine.SetSwapping = setname
	request.undo,request.implicitUndo,request.undoToken = {},{},{}
	request.previousSetName = GearRackDB.sets[user].CurrentSet

	-- pre-scan for items that don't need to move
	for i=0,19 do
		_,id = GearRackEngine.GetItemInfo(i)

		if set[i] and (set[i].id or set[i].name) then
			GearRackEngine.FindSetItem(set[i])
			if saved and saved[i] and not saved[i].id and not implicit[i]
				and not request.undoOf and setname~="GearRackEngine-CombatQueue"
				and owns_saved_definition(setname,request.definitionOwner) then
				saved[i].id=set[i].id
				request.definitionOwner.items[i].id=set[i].id
			end
			if GearRackEngine.SlotMatches(i,set[i]) then
				GearRackEngine.LockList[-2][i] = 1
			else
				if implicit[i] then
					request.implicitUndo[i] = id
				else
					request.undo[i] = id
				end
			end
		end
		GearRackEngine.ClearSwapListEntry(i)
	end

	if UnitAffectingCombat("player") then -- player is in combat
		for i=1,19 do
			if set[i] and set[i].id and not GearRackEngine.SlotInfo[i].swappable then
				GearRackEngine.AddToCombatQueue(i,set[i].id,request)
				request.deferred[i] = true
			end
		end
		invStart,invEnd = 16,18 -- restrict swap to weapons only
	elseif GearRack.worldSuspended or GearRackEngine.IsPlayerReallyDead() then -- wait for world entry or resurrection
		for i=0,19 do
			if set[i] and set[i].id then
				GearRackEngine.AddToCombatQueue(i,set[i].id,request)
				request.deferred[i] = true
			end
		end
		GearRackEngine.PendingCombatRequest = request
		GearRackEngine.SwapRequest = nil
		GearRackEngine.SetSwapping = nil
		GearRackEngine.ClearLockList()
		return
	end

	-- determine what needs swapped and populate GearRackEngine.SwapList
	-- skipping ammo slot the black sheep of inventory slots
	for i=invStart,invEnd do
		if set[i] and set[i].id then
			_,id = GearRackEngine.GetItemInfo(i)
			if not GearRackEngine.SlotMatches(i,set[i]) then
				swap = GearRackEngine.SwapList[i]
				swap.needsSwap = 1
				swap.desiredName = GearRackEngine.GetNameByID(set[i].id)
				if set[i].id==0 then -- empty slot
					swap.direction="INVTOBAG"
					swap.needsEmptied = 1
					hasINVTOBAG = 1
				else
					inv,bag,slot = GearRackEngine.FindSetItem(set[i])
					if inv then -- found it in another inventory slot
						_,set[i].id = GearRackEngine.GetItemInfo(inv)
						GearRackEngine.LockList[-2][inv] = 1
						_,_,_,sourceEquipSlot = GearRackEngine.GetItemInfo(inv)
						_,_,_,destEquipSlot = GearRackEngine.GetItemInfo(i)
						swap.direction="INVTOINV" -- if the item can exist in both slots
						swap.sourceInv = inv
						hasINVTOINV = 1
						if destEquipSlot and sourceEquipSlot and not (GearRackEngine.SlotInfo[i][sourceEquipSlot] and GearRackEngine.SlotInfo[inv][destEquipSlot]) then
							swap.needsEmptied = 1
							hasINVTOBAG = 1
						end
					elseif bag and slot then -- found it in a bag slot
						_,set[i].id = GearRackEngine.GetItemInfo(bag,slot)
						GearRackEngine.LockList[bag][slot] = 1
						swap.direction="BAGTOINV"
						swap.sourceBag = bag
						swap.sourceSlot = slot
						hasBAGTOINV = 1
					else -- couldn't find it
						missing = missing..tostring(swap.desiredName)..", "
						request.missing = true
						swap.needsSwap = nil
					end
				end
			end
		elseif set[i] and set[i].name then -- item has no id yet, not seen since conversion
			missing = missing..tostring(set[i].name)..", "
			request.missing = true
		end
	end

	if missing~="GearRack could not find: " then
		DEFAULT_CHAT_FRAME:AddMessage(string.gsub(missing,", $",""))
	end

	-- at this stage, GearRackEngine.SwapList[0]-[19] is populated

	-- INVTOBAG and .needsEmptied swaps first
	if hasINVTOBAG then
		idx = GearRackEngine.GetFreeQueueEntry()
		GearRackEngine.AddQueueEntry(idx)
		GearRackEngine.SwapQueue[idx].direction = "INVTOBAG"
		GearRackEngine.SwapQueue[idx].setname = setname
		for i=0,19 do
			if GearRackEngine.SwapList[i].needsEmptied then
				GearRackEngine.SwapQueue[idx][i].id = 0
			end
		end
	end

	-- INVTOINV swaps next
	if hasINVTOINV then
		idx = GearRackEngine.GetFreeQueueEntry()
		GearRackEngine.AddQueueEntry(idx)
		GearRackEngine.SwapQueue[idx].direction = "INVTOINV"
		GearRackEngine.SwapQueue[idx].setname = setname
		for i=0,19 do
			if GearRackEngine.SwapList[i].direction=="INVTOINV" and not (i==17 and request.offhandAfterMain) then
				GearRackEngine.SwapQueue[idx][i].id = set[i].id
				GearRackEngine.SwapQueue[idx][i].guid = set[i].guid
				GearRackEngine.SwapQueue[idx][i].fromSlot = GearRackEngine.SwapList[i].sourceInv
			end
		end
	end

	-- BAGTOINV swaps last (90% of swaps this is only bit that queues)
	if hasBAGTOINV then
		idx = GearRackEngine.GetFreeQueueEntry()
		GearRackEngine.AddQueueEntry(idx)
		GearRackEngine.SwapQueue[idx].direction = "BAGTOINV"
		GearRackEngine.SwapQueue[idx].setname = setname
		for i=0,19 do
			if GearRackEngine.SwapList[i].direction=="BAGTOINV" and not (i==17 and request.offhandAfterMain) then
				GearRackEngine.SwapQueue[idx][i].id = set[i].id
				GearRackEngine.SwapQueue[idx][i].guid = set[i].guid
				GearRackEngine.SwapQueue[idx][i].fromBag = GearRackEngine.SwapList[i].sourceBag
				GearRackEngine.SwapQueue[idx][i].fromSlot = GearRackEngine.SwapList[i].sourceSlot
			end
		end
	end

	-- Observe the replacement main hand before attempting an offhand equip.
	if request.offhandAfterMain and GearRackEngine.SwapList[17].direction then
		idx = GearRackEngine.GetFreeQueueEntry()
		GearRackEngine.AddQueueEntry(idx)
		GearRackEngine.SwapQueue[idx].direction = GearRackEngine.SwapList[17].direction
		GearRackEngine.SwapQueue[idx].setname = setname
		GearRackEngine.SwapQueue[idx][17].id = set[17].id
		GearRackEngine.SwapQueue[idx][17].guid = set[17].guid
		GearRackEngine.SwapQueue[idx][17].fromBag = GearRackEngine.SwapList[17].sourceBag
		GearRackEngine.SwapQueue[idx][17].fromSlot = GearRackEngine.SwapList[17].sourceSlot or GearRackEngine.SwapList[17].sourceInv
	end

	-- Ammo participates in completion even when it is the only requested change.
	bag,slot = nil,nil
	if set[0] and (set[0].id or set[0].name) then
		_,id = GearRackEngine.GetItemInfo(0)
		if id~=set[0].id then
			if set[0].id~=0 then
				_,bag,slot = GearRackEngine.FindSetItem(set[0])
				if bag then _,set[0].id = GearRackEngine.GetItemInfo(bag,slot) end
			end
			if set[0].id==0 or bag then
				idx = GearRackEngine.GetFreeQueueEntry()
				GearRackEngine.AddQueueEntry(idx)
				GearRackEngine.SwapQueue[idx].direction = set[0].id==0 and "INVTOBAG" or "BAGTOINV"
				GearRackEngine.SwapQueue[idx].setname = setname
				GearRackEngine.SwapQueue[idx][0].id = set[0].id
				GearRackEngine.SwapQueue[idx][0].guid = set[0].guid
				GearRackEngine.SwapQueue[idx][0].fromBag = bag
				GearRackEngine.SwapQueue[idx][0].fromSlot = slot
			else
				request.missing = true
			end
		end
	end

	-- Final verification also covers unchanged slots and missing items.
	idx = GearRackEngine.GetFreeQueueEntry()
	GearRackEngine.AddQueueEntry(idx)
	GearRackEngine.SwapQueue[idx].direction = "VERIFY"
	GearRackEngine.SwapQueue[idx].setname = setname
	for i=0,19 do
		if set[i] and not request.deferred[i] then
			GearRackEngine.SwapQueue[idx][i].id = set[i].id
			GearRackEngine.SwapQueue[idx][i].guid = set[i].guid
		end
	end

	if set.showhelm then
		ShowHelm(set.showhelm)
	end
	if set.showcloak then
		ShowCloak(set.showcloak)
	end

	-- Both views reflect deferred set choices through the same presentation.
	if GearRack.initialized then GearRack.UpdateQueuePresentation() end
	-- at last, perform the swaps by iterating over the queue
	GearRackEngine.IterateSwapQueue()

end

-- A real death pauses the active native owner, including its bounded deadline.
-- Record the pause on PLAYER_DEAD and also guard direct lock/inventory calls;
-- resurrection resumes the same request without counting time spent dead.
function GearRackEngine.ReconcileDeathPause()
	local request=GearRackEngine.SwapRequest
	if not request then return end
	if GearRackEngine.IsPlayerReallyDead() then
		request.deathPausedAt=request.deathPausedAt or GetTime()
		if GearRackEngine.TimerEnabled("WaitToIterate") then GearRackEngine.StopTimer("WaitToIterate") end
		return true
	elseif request.deathPausedAt then
		local elapsed=math.max(0,GetTime()-request.deathPausedAt)
		for _,idx in ipairs(GearRackEngine.SwapQueueOrder) do
			local queue=GearRackEngine.SwapQueue[idx]
			if queue.deadline then queue.deadline=queue.deadline+elapsed end
		end
		request.deathPausedAt=nil
	end
end

-- Reconcile once a second while a stage is active, including missed lock events.
function GearRackEngine.IterateWait()
	GearRackEngine.IterateSwapQueue()
end

-- A queued slot names an item, not a permanent bag/equipment position. Check
-- its planned source first, then follow that exact variant/GUID if it moved.
local function resolve_swap_source(wanted,direction)
	local inv,bag,slot
	if direction=="INVTOINV" then inv=wanted.fromSlot
	else bag,slot=wanted.fromBag,wanted.fromSlot end
	local location=inv and {equipmentSlotIndex=inv} or {bagID=bag,slotIndex=slot}
	local _,id=GearRackEngine.GetItemInfo(inv or bag,slot)
	if id~=wanted.id or (wanted.guid and C_Item.GetItemGUID(location)~=wanted.guid) then
		inv,bag,slot=GearRackEngine.FindSetItem(wanted)
		if not inv and not bag then return end
		location=inv and {equipmentSlotIndex=inv} or {bagID=bag,slotIndex=slot}
		_,id=GearRackEngine.GetItemInfo(inv or bag,slot)
	end
	if id~=wanted.id or (wanted.guid and C_Item.GetItemGUID(location)~=wanted.guid) then return end
	if inv then GearRackEngine.LockList[-2][inv]=1
	else GearRackEngine.LockList[bag][slot]=1 end
	return location,inv,bag,slot
end

function GearRackEngine.ShutdownQueue(reason)
	local finished=GearRackEngine.SwapRequest
	local waitingSets={}
	for _,idx in ipairs(GearRackEngine.SwapQueueOrder) do
		if GearRackEngine.SwapQueue[idx].direction=="NEWSET" then
			local queued=GearRackEngine.SwapQueue[idx]
			table.insert(waitingSets,{direction="NEWSET",setname=queued.setname,
				restoreSetName=queued.restoreSetName,context=queued.context})
		end
	end
	if reason then DEFAULT_CHAT_FRAME:AddMessage("GearRack: "..reason) end
	if GearRackEngine.SwapRequest then
		GearRackEngine.CancelDeferredRequest(GearRackEngine.SwapRequest.completionOf)
		GearRackEngine.CancelDeferredRequest(GearRackEngine.SwapRequest)
	end
	GearRackEngine.SwapRequest = nil
	GearRackEngine.SwapIssuing = nil
	GearRackEngineFrame:UnregisterEvent("ITEM_LOCK_CHANGED")
	GearRackEngine.SetSwapping = nil
	GearRackEngine.StopTimer("WaitToIterate")
	while #GearRackEngine.SwapQueueOrder>0 do
		GearRackEngine.RemoveQueueEntry(GearRackEngine.SwapQueueOrder[#GearRackEngine.SwapQueueOrder])
	end
	GearRackEngine.ClearLockList()
	for i=0,19 do GearRackEngine.ClearSwapListEntry(i) end
	GearRack.TransactionFinished(finished,reason)
	if GearRackTrinkets and GearRackTrinkets.UpdateWornTrinkets then GearRackTrinkets.UpdateWornTrinkets() end
	for _,queued in ipairs(waitingSets) do
		local idx=GearRackEngine.GetFreeQueueEntry()
		local entry=GearRackEngine.SwapQueue[idx]
		entry.direction,entry.setname="NEWSET",queued.setname
		entry.restoreSetName,entry.context=queued.restoreSetName,queued.context
		GearRackEngine.AddQueueEntry(idx)
	end
	if #waitingSets>0 then GearRackEngine.IterateSwapQueue() end
end

-- this function grabs the next swap QueueEntry and performs the swap
-- swaps only happen one direction at a time: INVTOBAG->INVTOINV->BAGTOINV
-- complex swaps can require running this a few times
function GearRackEngine.IterateSwapQueue()
	if GearRackEngine.SwapIssuing or GearRackEngine.BankTransfer or GearRack.worldSuspended then return end
	if GearRackEngine.ReconcileDeathPause() then return end
	if GearRackEngine.SwapRequest and GearRackEngine.SwapRequest.cancelled then
		GearRackEngine.ShutdownQueue()
		return
	end
	if #GearRackEngine.SwapQueueOrder<1 then
		GearRackEngine.ShutdownQueue()
		if next(GearRackEngine.CombatQueue) and not GearRackEngine.IsPlayerReallyDead() and not UnitAffectingCombat("player") then
			GearRackEngine.OnEvent("PLAYER_REGEN_ENABLED")
		end
		return
	end

	GearRackEngine.SortQueue()
	local idx = GearRackEngine.SwapQueueOrder[1]
	local queue = GearRackEngine.SwapQueue[idx]
	if queue.direction=="NEWSET" then
		local setname,restoreSetName,context = queue.setname,queue.restoreSetName,queue.context
		GearRackEngine.RemoveQueueEntry(idx)
		GearRackEngine.EquipSet(setname,restoreSetName,context)
		-- An already-equipped or deleted set need not produce any stages.
		if not GearRackEngine.SwapRequest then GearRackEngine.IterateSwapQueue() end
		return
	end

	-- Combat may begin after a saved set was planned but before a stage starts.
	-- Defer its armor through the existing owner instead of submitting a native
	-- move that combat restrictions will reject. Already-issued stages must
	-- retain their native reconciliation/timeout ownership.
	local request=GearRackEngine.SwapRequest
	if request and not request.persistent and not queue.started and UnitAffectingCombat("player") then
		for slot=0,19 do
			local wanted=request.items[slot]
			if wanted and wanted.id and not request.deferred[slot] and not GearRackEngine.SlotInfo[slot].swappable
				and not GearRackEngine.SlotMatches(slot,wanted) then
				GearRackEngine.AddToCombatQueue(slot,wanted.id,request)
				request.deferred[slot]=true
				for _,pendingIdx in ipairs(GearRackEngine.SwapQueueOrder) do
					local pending=GearRackEngine.SwapQueue[pendingIdx]
					if pending.direction~="NEWSET" then pending[slot].id=nil;pending[slot].guid=nil end
				end
			end
		end
	end

	local persistent=GearRackEngine.SwapRequest and GearRackEngine.SwapRequest.persistent
	queue.deadline = queue.deadline or (GetTime()+10)
	if queue.started then
		GearRackEngine.OnItemLockChanged()
		return
	end
	if not persistent and GetTime()>=queue.deadline then
		GearRackEngine.ShutdownQueue("Swap timed out before it could start.")
		return
	end
	GearRackEngine.StartTimer("WaitToIterate",persistent and .2 or 1)
    local intent=GearRackEngine.SwapRequest and GearRackEngine.SwapRequest.intent
    if intent and GearRack.Requests[intent.slot]~=intent then GearRackEngine.ShutdownQueue();return end
	if GearRackEngine.IsPlayerReallyDead() then
        if persistent then GearRackEngine.StopTimer("WaitToIterate") end
        return
    end
	-- Stages with armor wait for casts and the global cooldown; weapon-only
	-- stages go at once (see GearRack.GetEquipDelay). Ordinary set requests
	-- still expire at their stage deadline.
	local weaponsOnly=true
	for slot=0,19 do
		if queue[slot].id and not GearRackEngine.SlotInfo[slot].swappable then weaponsOnly=false;break end
	end
	local delay=GearRack.GetEquipDelay(weaponsOnly)
	if delay>0 then
		if not persistent then delay=math.min(delay,queue.deadline-GetTime()) end
		GearRackEngine.StartTimer("WaitToIterate",delay)
		return
	end
	if SpellIsTargeting() or GetCursorInfo() or GearRackEngine.AnyLocked() then return end
    if persistent and UnitAffectingCombat("player") then
        for slot=0,19 do
            if queue[slot].id and not GearRackEngine.SlotInfo[slot].swappable then GearRackEngine.ShutdownQueue();return end
        end
    end

	GearRackEngineFrame:RegisterEvent("ITEM_LOCK_CHANGED")
	GearRackEngine.SetSwapping = queue.setname
	queue.started = true
	queue.lastAttempt=GetTime()
	GearRackEngine.SwapIssuing = true -- lock events can arrive inside an equip or pickup call
	GearRackEngine.ClearLockList()
	local moved = {}
	for i=0,19 do
		local wanted = queue[i]
		local _,worn = GearRackEngine.GetItemInfo(i)
		if wanted.id and not GearRackEngine.SlotMatches(i,wanted) and not moved[i] and queue.direction~="VERIFY" then
			if SpellIsTargeting() or GetCursorInfo() then
				GearRackEngine.ShutdownQueue("A cursor action interrupted the swap.")
				return
			end
			local bag,slot,id,usedCursor
			if queue.direction=="INVTOBAG" then
				usedCursor = true
				bag,slot = GearRackEngine.FindSpace()
				if not bag then
                    if GearRackEngine.SwapRequest and GearRackEngine.SwapRequest.intent then
                        GearRackEngine.SwapRequest.intent.waitForSpace=GearRack.inventoryRevision
                    end
					GearRackEngine.NoMoreRoom()
					GearRackEngine.ShutdownQueue()
					return
				end
				PickupInventoryItem(i)
				PickupContainerItem(bag,slot)
			elseif queue.direction=="INVTOINV" or queue.direction=="BAGTOINV" then
				local location,sourceInv
				location,sourceInv,bag,slot=resolve_swap_source(wanted,queue.direction)
				if not location then
					GearRackEngine.ShutdownQueue("A requested item is no longer available.")
					return
				end
				if i==17 then
					local _,_,_,mainType = GearRackEngine.GetItemInfo(16)
					if mainType=="INVTYPE_2HWEAPON" then
						GearRackEngine.ShutdownQueue("The main-hand prerequisite did not complete.")
						return
					end
				end
				if i==0 or sourceInv==0 then -- ammo is outside ClassicAPI's destination range 1..19
					usedCursor = true
					if sourceInv then PickupInventoryItem(sourceInv)
					else PickupContainerItem(bag,slot) end
					PickupInventoryItem(i)
				else
					C_Item.EquipItemByName(location,i)
				end
				if sourceInv and queue[sourceInv].fromSlot==i then moved[sourceInv]=true end
			end
			if usedCursor and CursorHasItem() then
				ClearCursor() -- return only an item left by our own pickup pair
				GearRackEngine.ShutdownQueue("An item move could not complete.")
				return
			end
		end
	end
	GearRackEngine.SwapIssuing = nil
	GearRackEngine.OnItemLockChanged()
	if GearRackEngine.SwapRequest and GearRackEngine.SwapRequest.persistent then GearRackEngine.StartTimer("WaitToIterate",.2) end
end

--[[ Locks ]]--

-- returns true if anything is locked
function GearRackEngine.AnyLocked()
	for i=0,19 do
		if IsInventoryItemLocked(i) then return true end
	end
	-- Only occupied slots can be locked: read the cached ones, and every slot
	-- of a bag that changed since the cache was built.
	for bag=0,4 do
		if GearRack.DirtyBags[bag] or not GearRack.Bags[bag] then
			for slot=1,GetContainerNumSlots(bag) do
				local _,_,locked = GetContainerItemInfo(bag,slot)
				if locked then return true end
			end
		else
			for _,entry in ipairs(GearRack.Bags[bag]) do
				local _,_,locked = GetContainerItemInfo(bag,entry.slot)
				if locked then return true end
			end
		end
	end
end

-- when an iteration begins, on each ITEM_LOCK_CHANGED check if the swaps are done
-- if so, remove the current queue entry and go to the next one
-- this is where swaps end
function GearRackEngine.OnItemLockChanged()
	if GearRackEngine.SwapIssuing or GearRack.worldSuspended then return end
	if GearRackEngine.ReconcileDeathPause() then return end
	if GearRackEngine.SwapRequest and GearRackEngine.SwapRequest.cancelled then
		GearRackEngine.ShutdownQueue()
		return
	end
	local idx = GearRackEngine.SwapQueueOrder[1]
	if not idx then return end
	local queue = GearRackEngine.SwapQueue[idx]
	if not queue.started then return end
	if GearRackEngine.SwapRequest and GearRackEngine.SwapRequest.persistent and GearRackEngine.IsPlayerReallyDead() then
		GearRackEngine.StopTimer("WaitToIterate")
		return
	end

	local locked=GearRackEngine.AnyLocked()
	if not CursorHasItem() and not locked and GearRackEngine.SwapMatches(queue) then
		if queue.direction=="VERIFY" then
			local request = GearRackEngine.SwapRequest
			if request.missing then
				GearRackEngine.ShutdownQueue("The requested set is incomplete.")
				return
			end
			if not GearRackEngine.CompleteSwapRequest(request) then
				if next(request.deferred) then
					if not request.superseded then GearRackEngine.PendingCombatRequest = request end
				elseif not request.superseded then
					GearRackEngine.ShutdownQueue("The requested set is incomplete.")
					return
				end
			end
			GearRack.TransactionFinished(request)
			GearRackEngine.SwapRequest = nil
			GearRackEngine.SetSwapping = nil
			GearRack.WarnUnpoisoned(request)
		end
		GearRackEngine.RemoveQueueEntry(idx)
		GearRackEngine.StopTimer("WaitToIterate")
		GearRackEngine.IterateSwapQueue()
	elseif GearRackEngine.SwapRequest and GearRackEngine.SwapRequest.persistent then
        local intent=GearRackEngine.SwapRequest.intent
        if intent and GearRack.Requests[intent.slot]~=intent then
            if GetTime()-(queue.lastAttempt or 0)>=1 and not locked then GearRackEngine.ShutdownQueue()
            else GearRackEngine.StartTimer("WaitToIterate",.2) end
        elseif UnitAffectingCombat("player") and not GearRackEngine.SlotInfo[intent.slot].swappable
            and GetTime()-(queue.lastAttempt or 0)>=2 and not locked then
            GearRackEngine.ShutdownQueue()
        elseif GearRack.GetEquipDelay(GearRackEngine.SlotInfo[intent.slot].swappable)>0 then
            queue.started=nil
            GearRackEngine.StartTimer("WaitToIterate",GearRack.GetEquipDelay())
        elseif not locked and GetTime()-(queue.lastAttempt or 0)>=.3 then
            queue.started=nil
            GearRackEngine.IterateSwapQueue()
        else GearRackEngine.StartTimer("WaitToIterate",.2) end
	elseif GetTime()>=queue.deadline then
		GearRackEngine.ShutdownQueue("Swap timed out before the requested equipment was observed.")
	elseif not locked and not CursorHasItem() and GetTime()-(queue.lastAttempt or 0)>=.3 then
		-- In combat the client can refuse one weapon of a pair. Like single
		-- choices, a set re-issues only the slots that do not match yet, every
		-- 0.3 seconds, until the stage's deadline.
		queue.started=nil
		GearRackEngine.IterateSwapQueue()
	else
		GearRackEngine.StartTimer("WaitToIterate",.25)
	end
end

--[[ Combat/Death Queue Processing ]]

function GearRackEngine.IsPlayerReallyDead()
	local dead = UnitIsDeadOrGhost("player")
	if dead and UnitIsFeignDeath("player") then return nil end
	return dead
end

-- adds an item 'id' to 'slot' queue for post-combat/death swap
function GearRackEngine.AddToCombatQueue(slot,id,owner)
	local button = _G["GearRackUIInv"..slot.."Queue"]
	local paperdoll = _G[GearRackUI.Indexes[slot].paperdoll_slot.."Queue"]
	local _,wornId = GearRackEngine.GetItemInfo(slot)
	local wanted=owner and owner.items and owner.items[slot]
	local alreadyWorn=id==wornId and (not wanted or not wanted.guid
		or GearRack.EquippedGUID(slot)==wanted.guid)
	local toggleOff = not owner and GearRackEngine.CombatQueue[slot]==id
	if not owner then GearRackEngine.CancelDeferredRequest(GearRackEngine.CombatQueueOwner[slot]) end
	if toggleOff or alreadyWorn then
		GearRackEngine.CombatQueue[slot] = nil
		GearRackEngine.CombatQueueOwner[slot] = nil
		button:Hide()
		paperdoll:Hide()
	elseif id then
		GearRackEngine.CombatQueue[slot] = id
		GearRackEngine.CombatQueueOwner[slot] = owner
		local _,texture = GearRackEngine.GetNameByID(id)
		button:SetTexture(texture)
		button:Show()
		paperdoll:SetTexture(texture)
		paperdoll:Show()
	end
end

--[[ EquipSet wrappers ]]--

-- returns true if the entire set is currently worn
function GearRackEngine.IsSetEquipped(setname)

	local set,missing,id = GearRackDB.sets[user].Sets[setname or ""]

	if set then
		for i=0,19 do
			if set[i] then
				-- if item queued, check queued item instead of GetItemInfo
				if GearRackEngine.CombatQueue[i] then
					id = GearRackEngine.CombatQueue[i]
				else
					_,id = GearRackEngine.GetItemInfo(i)
				end
				if set[i].id ~= id then
					missing = 1
				end
			end
		end
	end
	return set and not missing
end

-- equips a set if it's worn, unequips it if not
function GearRackEngine.ToggleSet(setname)

	if GearRackDB.sets[user].Sets[setname or ""] then
		if GearRackEngine.IsSetEquipped(setname) then
			GearRackEngine.UnequipSet(setname)
		else
			GearRackEngine.EquipSet(setname)
		end
	end
end

-- This function creates a set of all the items replaced by setname, and then does does an .EquipSet()
function GearRackEngine.UnequipSet(setname)
	local old = GearRackDB.sets[user].Sets[setname]
	if not old then return end
	local source = GearRackEngine.SwapRequest
	if not source or source.setname~=setname then source = GearRackEngine.PendingCombatRequest end
	if source and source.setname~=setname then source = nil end
	local historyOwner=GearRackEngine.UndoOwner[setname]
	if not source and historyOwner and not owns_saved_definition(setname,historyOwner) then
		if old==historyOwner.definition then
			for i=0,19 do if old[i] then old[i].old=nil end end
			old.oldsetname=nil
		end
		GearRackEngine.ForgetSetUndo(setname)
		return
	end
	local items = {}
	local implicit = source and source.implicitUndo or GearRackEngine.SwapUndo[setname]
	for i=0,19 do
		local id
		if source then id = source.undo[i] elseif old[i] then id = old[i].old end
		if implicit and implicit[i] then id = implicit[i] end
		if id then items[i] = { id=id } end
	end
	local restoreSetName = old.oldsetname
	local token = GearRackEngine.UndoToken[setname]
	if source then restoreSetName,token = source.previousSetName,source.undoToken end
	-- Keep undo data available until this exact restore request succeeds.
	GearRackEngine.EquipSet("GearRackEngine-Unequip-"..setname,restoreSetName,
		{items=items,undoOf=setname,sourceUndoToken=token})
end

--[[ Timer maintenance
	ClassicAPI owns delayed callbacks. OnUpdate is reserved for cursor-following
	render work (IconDragging), whose zero period means once each rendered frame.
	Each timer has one callback for life; a repeating timer runs on one ticker,
	so neither a start nor a tick builds a closure. A cancelled handle never fires.
]]

local function fire_timer(clock)
	if not clock.enabled then return end
	if clock.rep then
		-- A first wait of another length runs on a one-shot; the period then ticks.
		if not clock.ticking then
			clock.ticking = true
			clock.handle = C_Timer.NewTicker(clock.limit,clock.fire)
		end
		clock.deadline = GetTime()+clock.limit
	else
		clock.handle, clock.deadline, clock.enabled = nil, nil, nil
	end
	local generation = clock.generation
	local ok,err = pcall(clock.func)
	if not ok then
		if clock.generation==generation then GearRackEngine.StopTimer(clock.name) end
		DEFAULT_CHAT_FRAME:AddMessage("GearRack timer "..clock.name..": "..tostring(err),1,0.2,0.2)
	end
end

function GearRackEngine.CreateTimer(name,func,limit,rep)
	local clock = {name=name,func=func,limit=limit,rep=rep,generation=0}
	clock.fire = function() fire_timer(clock) end
	GearRackEngine.TimerPool[name] = clock
end

function GearRackEngine.StartTimer(name,delay,keepEarlier)
	local clock = GearRackEngine.TimerPool[name]
	delay = delay or clock.limit
	local deadline=GetTime()+delay
	if keepEarlier and clock.enabled and clock.handle and clock.deadline and clock.deadline<=deadline then return end
	GearRackEngine.StopTimer(name)
	clock.enabled = 1
	if clock.limit==0 and clock.rep then
		GearRackEngineFrame:Show()
		return
	end
	clock.deadline = deadline
	if clock.rep and delay==clock.limit then
		clock.ticking = true
		clock.handle = C_Timer.NewTicker(delay,clock.fire)
	else
		clock.handle = C_Timer.NewTimer(delay,clock.fire)
	end
end

function GearRackEngine.StopTimer(name)
	local clock = GearRackEngine.TimerPool[name]
	if not clock then return end
	clock.generation = clock.generation+1
	if clock.handle then clock.handle:Cancel(); clock.handle = nil end
	clock.deadline, clock.enabled, clock.ticking = nil, nil, nil
	GearRackEngine.ClearStoppedTimers()
end

function GearRackEngine.ClearStoppedTimers()
	for name,clock in pairs(GearRackEngine.TimerPool) do
		if clock.enabled and clock.limit==0 and clock.rep then return end
	end
	GearRackEngineFrame:Hide()
end

function GearRackEngine.TimerEnabled(name)
	return GearRackEngine.TimerPool[name] and GearRackEngine.TimerPool[name].enabled
end

function GearRackEngine.OnUpdate()
	for name,clock in pairs(GearRackEngine.TimerPool) do
		if clock.enabled and clock.limit==0 and clock.rep then clock.func() end
	end
end

--[[ old OnUpdates : now gathered under GearRackEngine.Timers ]]

function GearRackEngine.IconDragging()
    GearRack.UpdateMinimapDrag()
end

-- formerly GearRackUI_ScaleUpdate_OnUpdate
function GearRackEngine.ScaleUpdate()
	local frame = GearRackUI.FrameToScale
	local width = GearRackUI.ScalingWidth
	if not frame or not frame:IsVisible() or not width or width<=0 or width~=width or width==math.huge then
		GearRackUI_StopScalingFrame(frame);return
	end
	local oldscale, left, cursorx = frame:GetEffectiveScale(), frame:GetLeft(), GetCursorPosition()
	if not oldscale or oldscale<=0 or oldscale~=oldscale or oldscale==math.huge or
		not left or left~=left or math.abs(left)==math.huge or
		not cursorx or cursorx~=cursorx or math.abs(cursorx)==math.huge then
		GearRackUI_StopScalingFrame(frame);return
	end
	local framex = left*oldscale

	if (cursorx-framex)>32 then
		local newscale = (cursorx-framex)/width
		GearRackUI_ScaleFrame(newscale)
	end
end

-- formerly GearRackUI_TooltipUpdate_OnUpdate
function GearRackEngine.TooltipUpdate()
	local owner = GearRackUI.TooltipOwner
	if not owner or not owner:IsVisible() or GameTooltip:GetOwner()~=owner or
		GearRackDB.settings.ShowTooltips=="OFF" or not GearRackUI.TooltipType or
		(not GearRackUI.TooltipPending and not GameTooltip:IsVisible()) then
		GearRackUI_StopTooltip(true);return
	end
	GearRackUI.TooltipPending = nil
	if GearRackUI.TooltipType then

		local cooldown

		set_tooltip_anchor(GearRackUI.TooltipOwner)

		if GearRackUI.TooltipType=="BAG" then
			if GearRackUI.TooltipBag==-1 then
				GameTooltip:SetInventoryItem("player",BankButtonIDToInvSlotID(GearRackUI.TooltipSlot))
			else
				GameTooltip:SetBagItem(GearRackUI.TooltipBag,GearRackUI.TooltipSlot)
			end
			cooldown = GetContainerItemCooldown(GearRackUI.TooltipBag,GearRackUI.TooltipSlot)
		elseif GearRackUI.TooltipType=="INVENTORY" then
			GameTooltip:SetInventoryItem("player",GearRackUI.TooltipSlot)
			cooldown = GearRack.GetInventoryCooldown(GearRackUI.TooltipSlot)
			if GearRackUI.TooltipBag then
				GameTooltip:AddLine(string.format(GearRackUIText.QUEUED,GearRackUI.TooltipBag))
			end
			if GearRackUI.TooltipSlot==13 or GearRackUI.TooltipSlot==14 then
				GameTooltip:AddLine("Right-click: trinkets",ACTION[1],ACTION[2],ACTION[3])
			end
		end
		GameTooltip:Show()
		if cooldown==0 then
			-- stop updates if this item has no cooldown
			GearRackEngine.StopTimer("TooltipUpdate")
		elseif cooldown and cooldown>0 and not GearRackEngine.TimerEnabled("TooltipUpdate") then
			-- An inventory redraw can replace a ready item while the mouse stays still.
			GearRackEngine.StartTimer("TooltipUpdate")
		end
	end
end

-- Hides the bar's controls once Alt is released over a locked bar. An unlocked
-- bar always shows them, so there is nothing to watch.
function GearRackEngine.ControlFrame()
	if GearRackDB.bars[user].Locked~="ON" then
		GearRackEngine.StopTimer("ControlFrame")
	elseif not IsAltKeyDown() then
		GearRackEngine.StopTimer("ControlFrame")
		GearRackUI_ControlFrame:Hide()
	end
end

-- Only the current source and its flyout keep a menu open. The small halo
-- bridges the gap between them; ClassicAPI handles each region's own scale.
function GearRackEngine.MenuFrame()
	local dock,slot=GearRackUI.MenuDockedTo,GearRackUI.InvOpen
	local owner=GearRackUI_InvFrame
	if dock=="SET" then
		owner=slot and _G["GearRackUI_Sets_Inv"..slot]
		if not GearRackUI_SetsFrame:IsVisible() or not owner or owner:GetAlpha()<=.5 then
			GearRackUI_MenuFrame:Hide();return
		end
	elseif dock=="CHARACTERSHEET" then
		local info=slot and GearRackUI.Indexes[slot]
		owner=info and _G[info.paperdoll_slot]
		if not PaperDollFrame or not PaperDollFrame:IsVisible() then
			GearRackUI_MenuFrame:Hide();return
		end
	elseif dock=="MINIMAP" then
		owner=GearRackMinimapButton
	end
	if not owner or not owner:IsVisible() or
		(not owner:IsMouseOver(4,-4,-4,4) and not GearRackUI_MenuFrame:IsMouseOver(4,-4,-4,4)) then
		GearRackUI_MenuFrame:Hide()
	end
end

--[[ Bank support ]]

function GearRackEngine.PopulateBank()
	if not GearRackUI.BankIsOpen then return end
	GearRackEngine.UnpopulateBank()
	local itemID,equipLoc,rawID
	for i=1,#GearRackUI.BankSlots do
		local bag=GearRackUI.BankSlots[i]
		local count=GetContainerNumSlots(bag)
		if bag>=5 and count>0 then
			local bagID=GetInventoryItemID("player",BankButtonIDToInvSlotID(bag,1))
			if bagID then GearRackUI.BankItemIDs[bagID]=true end
		end
		for j=1,count do
			_,itemID,_,equipLoc,_,rawID = GearRackEngine.GetItemInfo(bag,j)
			local baseID=rawID or GearRack.BaseID(itemID)
			if baseID then GearRackUI.BankItemIDs[baseID]=true end
			if itemID then
				if equipLoc and equipLoc~="" then
					GearRackUI.BankedItems[itemID] = 1
				end
			end
		end
	end
end

function GearRackEngine.UnpopulateBank()
	table.wipe(GearRackUI.BankedItems)
	GearRackUI.BankItemIDs=GearRackUI.BankItemIDs or {}
	table.wipe(GearRackUI.BankItemIDs)
end

function GearRackEngine.BankOpened()
	GearRackUI.BankIsOpen = 1
	GearRackEngine.PopulateBank()
end

function GearRackEngine.BankClosed()
	GearRackUI.BankIsOpen = nil
	GearRackEngine.CancelBankTransfer()
	GearRackUI_MenuFrame:Hide()
	GearRackEngine.UnpopulateBank()
end

function GearRackEngine.SetHasBanked(setname)
	if not setname or not GearRackDB.sets[user].Sets[setname] then return end
	local item
	for i=0,19 do
		item = GearRackDB.sets[user].Sets[setname][i]
		if item and item.name and GearRackUI.BankedItems[item.id] then
			return 1
		end
	end
end

-- Returns comma-separated list of sets containing the specified item (by link, ID, or name)
function GearRackEngine.GetSetsWithItem(itemIdentifier)
	if not user or not GearRackDB.sets or not GearRackDB.sets[user] or not GearRackDB.sets[user].Sets then return nil end
	if not itemIdentifier then return nil end

	local targetID, targetName
	if type(itemIdentifier) == "number" then
		targetID = tostring(itemIdentifier)
	elseif type(itemIdentifier) == "string" then
		local _, _, linkID = string.find(itemIdentifier, "item:(%d+)")
		if linkID then
			targetID = linkID
		elseif string.find(itemIdentifier, "^%d+$") then
			targetID = itemIdentifier
		else
			targetName = itemIdentifier
		end
	end

	local matchingSets
	for setName, setData in pairs(GearRackDB.sets[user].Sets) do
		if not string.find(setName, "^GearRackUI") and not string.find(setName, "^GearRackEngine-") then
			for slot = 0, 19 do
				local slotData = setData[slot]
				if slotData and slotData.id and slotData.id ~= 0 then
					local matched = false
					if targetID then
						local _, _, slotBaseID = string.find(tostring(slotData.id), "(%d+)")
						if slotBaseID == targetID or tostring(slotData.id) == targetID then
							matched = true
						end
					elseif targetName and slotData.name and slotData.name == targetName then
						matched = true
					end

					if matched then
						matchingSets = matchingSets and (matchingSets .. ", " .. setName) or setName
						break
					end
				end
			end
		end
	end
	return matchingSets
end

function GearRackEngine.FindBankedItem(itemID,itemGUID)
	for _,i in ipairs(GearRackUI.BankSlots) do
		for j=1,GetContainerNumSlots(i) do
			local _, currentID = GearRackEngine.GetItemInfo(i,j)
			if itemID and currentID == itemID and not GearRackEngine.LockList[i][j]
				and (not itemGUID or GearRack.BagGUID(i,j)==itemGUID) then
				return i,j
			end
		end
	end
end

local function bank_item_identity(location)
	local _,id=GearRackEngine.GetItemInfo(location.equipmentSlotIndex or location.bagID,location.slotIndex)
	return id~=0 and id or nil,C_Item.GetItemGUID(location)
end

local function bank_location_locked(location)
	return C_Item.IsLocked(location)
end

-- A native bank send is asynchronous. Own its reservations until the exact
-- destination and emptied source are observed, or a bounded uncertain failure.
function GearRackEngine.BeginBankTransfer()
	if not GearRackUI.BankIsOpen or GearRack.worldSuspended or GearRackEngine.IsPlayerReallyDead()
		or GearRackEngine.IsEquipmentSwapActive() or SpellIsTargeting() or GetCursorInfo() then return end
	GearRackEngine.ClearLockList()
	GearRackEngine.BankTransfer={moves={},deadline=GetTime()+5,issuing=true}
	GearRackEngineFrame:RegisterEvent("ITEM_LOCK_CHANGED")
	GearRackEngine.StartTimer("BankTransferCheck")
	return true
end

function GearRackEngine.CancelBankTransfer(reason)
	local transfer=GearRackEngine.BankTransfer
	if not transfer then return end
	GearRackEngine.BankTransfer=nil
	GearRackEngine.StopTimer("BankTransferCheck")
	GearRackEngineFrame:UnregisterEvent("ITEM_LOCK_CHANGED")
	GearRackEngine.ClearLockList()
	for _,move in ipairs(transfer.moves) do
		for _,location in ipairs({move.source,move.destination}) do
			if location.bagID and location.bagID>=0 and location.bagID<=4 then GearRack.InvalidateBag(location.bagID) end
		end
	end
	if reason then DEFAULT_CHAT_FRAME:AddMessage("GearRack: "..reason) end
	GearRack.Wake()
	if #GearRackEngine.SwapQueueOrder>0 then GearRackEngine.IterateSwapQueue() end
end

function GearRackEngine.ReconcileBankTransfer()
	local transfer=GearRackEngine.BankTransfer
	if not transfer then return end
	if not GearRackUI.BankIsOpen or GearRack.worldSuspended or GearRackEngine.IsPlayerReallyDead() then
		GearRackEngine.CancelBankTransfer()
		return
	end
	if GetTime()>=transfer.deadline then
		GearRackEngine.CancelBankTransfer("Bank transfer could not be confirmed. Check your bags before trying again.")
		return
	end
	if not transfer.issuing then
		local pending=false
		for _,move in ipairs(transfer.moves) do
			local destID,destGUID=bank_item_identity(move.destination)
			if C_Item.DoesItemExist(move.source) or destID~=move.id or (move.guid and destGUID~=move.guid)
				or bank_location_locked(move.source) or bank_location_locked(move.destination) then pending=true;break end
		end
		if not pending then GearRackEngine.CancelBankTransfer();return end
	end
	GearRackEngine.StartTimer("BankTransferCheck",.2)
end

function GearRackEngine.SendBankItem(source,destination,expectedID,expectedGUID)
	local transfer=GearRackEngine.BankTransfer
	if not transfer or not transfer.issuing or not GearRackUI.BankIsOpen
		or GearRack.worldSuspended or SpellIsTargeting() or GetCursorInfo() then return end
	local id,guid=bank_item_identity(source)
	if not id or id~=expectedID or (expectedGUID and guid~=expectedGUID) or C_Item.DoesItemExist(destination)
		or bank_location_locked(source) or bank_location_locked(destination) then return end
	local accepted
	if source.equipmentSlotIndex then
		GearRackEngine.LockList[-2][source.equipmentSlotIndex]=1
		PickupInventoryItem(source.equipmentSlotIndex)
		PickupContainerItem(destination.bagID,destination.slotIndex)
		if CursorHasItem() then ClearCursor();return end
		accepted=true
	else
		GearRackEngine.LockList[source.bagID][source.slotIndex]=1
		accepted=C_Container.SwapItems(source.bagID,source.slotIndex,destination.bagID,destination.slotIndex)
	end
	if accepted then table.insert(transfer.moves,{source=source,destination=destination,id=id,guid=guid}) end
	return accepted
end

function GearRackEngine.EndBankTransfer()
	if GearRackEngine.BankTransfer then
		GearRackEngine.BankTransfer.issuing=nil
		GearRackEngine.ReconcileBankTransfer()
	end
end

function GearRackEngine.PullSetFromBank(setname)
	local set = GearRackDB.sets[user].Sets[setname]
	if not set or not GearRackEngine.BeginBankTransfer() then return end
	local bag,slot,freeBag,freeSlot
	for i=0,19 do
		if not GearRackUI.BankIsOpen or SpellIsTargeting() or GetCursorInfo() then break end
		if set[i] then
			if GearRackUI.BankedItems[set[i].id] then
				bag,slot = GearRackEngine.FindBankedItem(set[i].id,set[i].guid)
				if bag then
					freeBag,freeSlot = GearRackEngine.FindSpace()
					if freeBag then
						if not GearRackEngine.SendBankItem({bagID=bag,slotIndex=slot},
							{bagID=freeBag,slotIndex=freeSlot},set[i].id,set[i].guid) then break end
					else
						GearRackEngine.NoMoreRoom()
						break
					end
				end
			end
		end
	end
	GearRackEngine.EndBankTransfer()
end

function GearRackEngine.PushSetToBank(setname)
	local set = GearRackDB.sets[user].Sets[setname]
	if not set or not GearRackEngine.BeginBankTransfer() then return end
	local inv,bag,slot,freeBag,freeSlot
	for i=0,19 do
		if not GearRackUI.BankIsOpen or SpellIsTargeting() or GetCursorInfo() then break end
		if set[i] and set[i].id ~= 0 then
			freeBag,freeSlot = GearRackEngine.FindSpace(1)
			if freeBag then
				inv,bag,slot = GearRackEngine.FindSetItem(set[i])
				local _, currentID
				if inv then _, currentID = GearRackEngine.GetItemInfo(inv)
				elseif bag then _, currentID = GearRackEngine.GetItemInfo(bag,slot) end
				if set[i].id and currentID ~= set[i].id then break end
				if inv then
					if not GearRackEngine.SendBankItem({equipmentSlotIndex=inv},
						{bagID=freeBag,slotIndex=freeSlot},set[i].id,set[i].guid) then break end
				elseif bag then
					if not GearRackEngine.SendBankItem({bagID=bag,slotIndex=slot},
						{bagID=freeBag,slotIndex=freeSlot},set[i].id,set[i].guid) then break end
				end
			else
				GearRackEngine.NoMoreRoom()
				break
			end
		end
	end
	GearRackEngine.EndBankTransfer()
end

function GearRackEngine.NoMoreRoom()
	DEFAULT_CHAT_FRAME:AddMessage("GearRack: Not enough room to complete the swap.")
end
