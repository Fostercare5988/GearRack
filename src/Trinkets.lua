if not GearRack.enabled then return end

-- Trinket buttons, carried-item drawer and notifications.
GearRackTrinkets = {}

function GearRackTrinkets.LoadDefaults()

	local defaults = {
		TooltipFollow = "OFF",		-- whether tooltips follow the mouse
		KeepOpen = "OFF",			-- whether menu hides after use
		KeepDocked = "ON",			-- whether to keep menu docked at all times
		Notify = "OFF",				-- whether a message appears when a trinket is ready
		NotifyChatAlso="OFF",		-- whether to send notify to chat also
		Locked = "OFF",				-- whether windows can be moved/scaled/rotated
		ShowTooltips = "ON",		-- whether to display tooltips at all
		NotifyThirty = "OFF",		-- whether to notify cooldowns at 30 seconds instead of 0
		MenuOnShift = "OFF",		-- whether menu requires Shift to display
		SetColumns = "OFF",			-- whether number of columns in menu is chosen automatically
		Columns = 4,				-- if SetColumns "ON", number of columns before menu wraps
		ShowHotKeys = "ON",		-- whether hotkeys show on trinkets
		HideOnLoad = "OFF",
		StopOnSwap = "OFF"			-- whether to stop auto queue on all manual swaps
	}

	local displayDefaults = {
		MainDock = "BOTTOMRIGHT",	-- corner of main window docked to
		MenuDock = "BOTTOMLEFT",	-- corner menu window is docked from
		MainOrient = "HORIZONTAL",	-- direction of main window
		MenuOrient = "VERTICAL",	-- direction of menu window
		XPos = 400,					-- left edge of main window
		YPos = 400,					-- top edge of main window
		MainScale = 1,				-- scaling of main window
		MenuScale = 1,				-- scaling of menu window
		Visible="ON",				-- whether to display the trinkets
		ItemsUsed = {},				-- table of trinkets used and their cooldown status
	}
	GearRackDB.trinketOptions = type(GearRackDB.trinketOptions)=="table" and GearRackDB.trinketOptions or {}
	GearRackCharDB.trinkets = type(GearRackCharDB.trinkets)=="table" and GearRackCharDB.trinkets or {}
	local options, per = GearRackDB.trinketOptions, GearRackCharDB.trinkets
	for key,value in pairs(defaults) do
		if options[key]==nil or (type(value)=="string" and options[key]~="ON" and options[key]~="OFF") then options[key]=value end
	end
	for key,value in pairs(displayDefaults) do
		if per[key]==nil then per[key]=value end
	end
	local function number(value, default, minimum, maximum)
		value = tonumber(value)
		if not value or value~=value or value==math.huge or value==-math.huge
			or (minimum and value<minimum) or (maximum and value>maximum) then return default end
		return value
	end
	options.Columns = math.floor(number(options.Columns, 4, 1, 30))
	per.MainScale = number(per.MainScale, 1, 0)
	per.MenuScale = number(per.MenuScale, 1, 0)
	if per.MainScale==0 then per.MainScale=1 end
	if per.MenuScale==0 then per.MenuScale=1 end
	per.XPos = number(per.XPos, 400)
	per.YPos = number(per.YPos, 400)
	for _,key in ipairs({"MainOrient","MenuOrient"}) do
		if per[key]~="HORIZONTAL" and per[key]~="VERTICAL" then per[key]=displayDefaults[key] end
	end
	if per.Visible~="ON" and per.Visible~="OFF" then per.Visible=displayDefaults.Visible end
	per.ItemsUsed = type(per.ItemsUsed)=="table" and per.ItemsUsed or {}
	for name, count in pairs(per.ItemsUsed) do
		if type(name)~="string" or number(count, -1, 0)==-1 then
			per.ItemsUsed[name] = nil
		else
			per.ItemsUsed[name] = tonumber(count)
		end
	end
	if not GearRackTrinkets.DockStats[tostring(per.MainDock or "")..tostring(per.MenuDock or "")] then
		per.MainDock, per.MenuDock = "BOTTOMRIGHT", "BOTTOMLEFT"
	end

end

--[[ Misc Variables ]]--

GearRackTrinkets_Version = GearRack.version

GearRackTrinkets.MaxTrinkets = 30 -- add more to GearRackTrinkets_MenuFrame if this changes
GearRackTrinkets.BaggedTrinkets = {} -- indexed by number, 1-30 of trinkets in the menu
GearRackTrinkets.NumberOfTrinkets = 0 -- number of trinkets in the menu
GearRackTrinkets.CombatQueue = {} -- [0] or [1] = name of trinket queued for slot 0 or 1
GearRackTrinkets.QueueItemIDs = {} -- runtime identities; names remain display/API input
GearRackTrinkets.Corners = { "TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT" }
GearRackTrinkets.WatchItem = {} -- table of items being watched for cooldowns

-- Modern Rarity Borders
local QUALITY_BORDER_BACKDROP = {
	edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
	tile = true,
	tileSize = 8,
	edgeSize = 12,
	insets = { left = 0, right = 0, top = 0, bottom = 0 }
}

local ENHANCED_QUALITY_COLORS = {
	[2] = { r = 0.05, g = 1.00, b = 0.15 }, -- Vibrant Emerald Green
	[3] = { r = 0.00, g = 0.70, b = 1.00 }, -- Radiant Electric Sky Blue
	[4] = { r = 0.85, g = 0.20, b = 1.00 }, -- Vivid Neon Purple / Magenta
	[5] = { r = 1.00, g = 0.55, b = 0.00 }, -- Flaming Orange
	[6] = { r = 0.95, g = 0.85, b = 0.40 }, -- Radiant Gold
}

local function GetBorderQualityColor(quality)
	local color = ENHANCED_QUALITY_COLORS[quality]
	if color then
		return color.r, color.g, color.b
	end
	return GetItemQualityColor(quality)
end

local function get_or_create_quality_border(btn)
	if not btn then return nil end
	if not btn.qualityBorder then
		local name = btn:GetName()
		local qBorder = CreateFrame("Frame", name and (name .. "QualityBorder") or nil, btn)
		qBorder:SetPoint("TOPLEFT", btn, "TOPLEFT", -2, 2)
		qBorder:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", 2, -2)
		qBorder:SetBackdrop(QUALITY_BORDER_BACKDROP)
		qBorder:EnableMouse(false)
		if btn.GetFrameLevel then
			qBorder:SetFrameLevel(btn:GetFrameLevel() + 1)
		end
		qBorder:Hide()
		btn.qualityBorder = qBorder
	end
	return btn.qualityBorder
end

local function apply_trinket_quality_border(btn, quality)
	if not btn then return end
	local qBorder = get_or_create_quality_border(btn)
	if not qBorder then return end

	if type(quality) == "number" and quality > 1 then
		local r, g, b = GetBorderQualityColor(quality)
		qBorder:SetBackdropBorderColor(r, g, b, 1.0)
		if btn.GetFrameLevel then
			qBorder:SetFrameLevel(btn:GetFrameLevel() + 1)
		end
		qBorder:Show()
	else
		qBorder:Hide()
	end
end

--[[ Local functions ]]--

-- dock-dependant offset and directions: MainDock..MenuDock
-- x/yoff   = offset MenuFrame is positioned to MainFrame
-- x/ydir   = direction trinkets are added to menu
-- x/ystart = starting offset when building a menu, relativePoint MenuDock
GearRackTrinkets.DockStats = { ["TOPRIGHTTOPLEFT"] =		 { xoff=-4, yoff=0,  xdir=1,  ydir=-1, xstart=8,   ystart=-8 },
					 ["BOTTOMRIGHTBOTTOMLEFT"] = { xoff=-4, yoff=0,  xdir=1,  ydir=1,  xstart=8,   ystart=44 },
					 ["TOPLEFTTOPRIGHT"] =		 { xoff=4,  yoff=0,  xdir=-1, ydir=-1, xstart=-44, ystart=-8 },
					 ["BOTTOMLEFTBOTTOMRIGHT"] = { xoff=4,  yoff=0,  xdir=-1, ydir=1,  xstart=-44, ystart=44 },
					 ["TOPRIGHTBOTTOMRIGHT"] =   { xoff=0,  yoff=-4, xdir=-1, ydir=1,  xstart=-44,  ystart=44 },
					 ["BOTTOMRIGHTTOPRIGHT"] =   { xoff=0,  yoff=4,	 xdir=-1, ydir=-1, xstart=-44,  ystart=-8 },
					 ["TOPLEFTBOTTOMLEFT"] =	 { xoff=0,  yoff=-4, xdir=1,  ydir=1,  xstart=8,   ystart=44 },
					 ["BOTTOMLEFTTOPLEFT"] =	 { xoff=0,  yoff=4,  xdir=1,  ydir=-1, xstart=8,   ystart=-8 } }

-- returns offset and direction depending on current docking. ie: GearRackTrinkets.DockInfo("xoff")
function GearRackTrinkets.DockInfo(arg1)
	local anchor = GearRackCharDB.trinkets.MainDock..GearRackCharDB.trinkets.MenuDock
	if GearRackTrinkets.DockStats[anchor] and arg1 and GearRackTrinkets.DockStats[anchor][arg1] then
		return GearRackTrinkets.DockStats[anchor][arg1]
	else
		return 0
	end
end

-- hide the docking markers
function GearRackTrinkets.ClearDocking()
	for i=1,4 do
		getglobal("GearRackTrinkets_MainDock_"..GearRackTrinkets.Corners[i]):Hide()
		getglobal("GearRackTrinkets_MenuDock_"..GearRackTrinkets.Corners[i]):Hide()
	end
end

-- returns true if the two values are close to each other
function GearRackTrinkets.Near(arg1,arg2)
	return (math.max(arg1,arg2)-math.min(arg1,arg2))<15
end

-- moves the MenuFrame to the dock position against MainFrame
function GearRackTrinkets.DockWindows()
	GearRackTrinkets.ClearDocking()
	if GearRackDB.trinketOptions.KeepDocked=="ON" then
		GearRackTrinkets_MenuFrame:ClearAllPoints()
		if GearRackDB.trinketOptions.Locked=="OFF" then
			GearRackTrinkets_MenuFrame:SetPoint(GearRackCharDB.trinkets.MenuDock,"GearRackTrinkets_MainFrame",GearRackCharDB.trinkets.MainDock,GearRackTrinkets.DockInfo("xoff"),GearRackTrinkets.DockInfo("yoff"))
		else
			GearRackTrinkets_MenuFrame:SetPoint(GearRackCharDB.trinkets.MenuDock,"GearRackTrinkets_MainFrame",GearRackCharDB.trinkets.MainDock,GearRackTrinkets.DockInfo("xoff")*3,GearRackTrinkets.DockInfo("yoff")*3)
		end
	end
	if GearRackTrinkets_MenuFrame:IsVisible() then
		GearRackTrinkets.BuildMenu()
	end
end

-- displays windows vertically or horizontally
function GearRackTrinkets.OrientWindows()
	if GearRackCharDB.trinkets.MainOrient=="HORIZONTAL" then
		GearRackTrinkets_MainFrame:SetWidth(92)
		GearRackTrinkets_MainFrame:SetHeight(52)
	else
		GearRackTrinkets_MainFrame:SetWidth(52)
		GearRackTrinkets_MainFrame:SetHeight(92)
	end
end

-- scan inventory and build MenuFrame
function GearRackTrinkets.BuildMenu()

	if not IsShiftKeyDown() and GearRackDB.trinketOptions.MenuOnShift=="ON" then
		return
	end

	local idx,i,j,k,texture = 1
	local itemLink,itemID,itemName,equipSlot,itemTexture

    for _,entry in ipairs(GearRack.GetCarriedItems()) do
        if entry.equipLoc=="INVTYPE_TRINKET" then
            GearRackTrinkets.BaggedTrinkets[idx]={bag=entry.bag,slot=entry.slot,name=entry.name,
                texture=entry.texture,quality=entry.quality,id=entry.baseID,guid=entry.guid}
            idx=idx+1
        end
    end
	GearRackTrinkets.NumberOfTrinkets = math.min(idx-1,GearRackTrinkets.MaxTrinkets)

	if GearRackTrinkets.NumberOfTrinkets<1 then
		-- user has no bagged trinkets :(
		GearRackTrinkets_MenuFrame:Hide()
	else
		-- display trinkets outward from docking point
		local col,row,xpos,ypos = 0,0,GearRackTrinkets.DockInfo("xstart"),GearRackTrinkets.DockInfo("ystart")
		local max_cols = 1

		if GearRackTrinkets.NumberOfTrinkets>24 then
			max_cols = 5
		elseif GearRackTrinkets.NumberOfTrinkets>18 then
			max_cols = 4
		elseif GearRackTrinkets.NumberOfTrinkets>12 then
			max_cols = 3
		elseif GearRackTrinkets.NumberOfTrinkets>4 then
			max_cols = 2
		end
		if GearRackDB.trinketOptions.SetColumns=="ON" and GearRackDB.trinketOptions.Columns then
			max_cols = GearRackDB.trinketOptions.Columns
		end

		for i=1,GearRackTrinkets.NumberOfTrinkets do
			local item = getglobal("GearRackTrinkets_Menu"..i)
			getglobal("GearRackTrinkets_Menu"..i.."Icon"):SetTexture(GearRackTrinkets.BaggedTrinkets[i].texture)
			apply_trinket_quality_border(item, GearRackTrinkets.BaggedTrinkets[i].quality)
			item:SetPoint("TOPLEFT","GearRackTrinkets_MenuFrame",GearRackCharDB.trinkets.MenuDock,xpos,ypos)

			if GearRackCharDB.trinkets.MenuOrient=="VERTICAL" then
				xpos = xpos + GearRackTrinkets.DockInfo("xdir")*40
				col = col + 1
				if col==max_cols then
					xpos = GearRackTrinkets.DockInfo("xstart")
					col = 0
					ypos = ypos + GearRackTrinkets.DockInfo("ydir")*40
					row = row + 1
				end
				item:Show()
			else
				ypos = ypos + GearRackTrinkets.DockInfo("ydir")*40
				col = col + 1
				if col==max_cols then
					ypos = GearRackTrinkets.DockInfo("ystart")
					col = 0
					xpos = xpos + GearRackTrinkets.DockInfo("xdir")*40
					row = row + 1
				end
				item:Show()
			end
		end
		for i=(GearRackTrinkets.NumberOfTrinkets+1),GearRackTrinkets.MaxTrinkets do
			local mBtn = getglobal("GearRackTrinkets_Menu"..i)
			if mBtn then
				mBtn:Hide()
				if mBtn.qualityBorder then
					mBtn.qualityBorder:Hide()
				end
			end
		end
		if col==0 then
			row = row-1
		end

		if GearRackCharDB.trinkets.MenuOrient=="VERTICAL" then
			GearRackTrinkets_MenuFrame:SetWidth(12+(max_cols*40))
			GearRackTrinkets_MenuFrame:SetHeight(12+((row+1)*40))
		else
			GearRackTrinkets_MenuFrame:SetWidth(12+((row+1)*40))
			GearRackTrinkets_MenuFrame:SetHeight(12+(max_cols*40))
		end
		GearRackTrinkets.UpdateMenuCooldowns()
		GearRackTrinkets_MenuFrame:Show()
		GearRackTrinkets.StartTimer("MenuMouseover")
	end

end

function GearRackTrinkets.Initialize()

	if GearRackCharDB.trinkets.XPos and GearRackCharDB.trinkets.YPos then
		GearRackTrinkets_MainFrame:SetPoint("TOPLEFT","UIParent","BOTTOMLEFT",GearRackCharDB.trinkets.XPos,GearRackCharDB.trinkets.YPos)
	end
	if GearRackCharDB.trinkets.MainScale then
		GearRackTrinkets_MainFrame:SetScale(GearRackCharDB.trinkets.MainScale)
	end
	if GearRackCharDB.trinkets.MenuScale then
		GearRackTrinkets_MenuFrame:SetScale(GearRackCharDB.trinkets.MenuScale)
	end

	GearRackTrinkets.CreateTimer("UpdateWornTrinkets",GearRackTrinkets.UpdateWornTrinkets,.75)
	GearRackTrinkets.CreateTimer("DockingMenu",GearRackTrinkets.DockingMenu,.2,1)
	GearRackTrinkets.CreateTimer("MenuMouseover",GearRackTrinkets.MenuMouseover,.25,1)
	GearRackTrinkets.CreateTimer("Scaling",GearRackTrinkets.Scaling,.1,1)
	GearRackTrinkets.CreateTimer("TooltipUpdate",GearRackTrinkets.TooltipUpdate,1,1)
	GearRackTrinkets.CreateTimer("CooldownUpdate",GearRackTrinkets.CooldownUpdate,1,1)

	-- Rule C8: Child Cooldown Mouse Passthrough
	local cd0 = GearRackTrinkets_Trinket0Cooldown
	if cd0 and cd0.EnableMouse then cd0:EnableMouse(false) end
	local cd1 = GearRackTrinkets_Trinket1Cooldown
	if cd1 and cd1.EnableMouse then cd1:EnableMouse(false) end
	for i = 1, 30 do
		local mcd = getglobal("GearRackTrinkets_Menu" .. i .. "Cooldown")
		if mcd and mcd.EnableMouse then
			mcd:EnableMouse(false)
		end
	end

	GearRackTrinkets.InitOptions()

	GearRackTrinkets.UpdateWornTrinkets()
	GearRackTrinkets.DockWindows()
	GearRackTrinkets.OrientWindows()
	GearRackTrinkets.StartTimer("CooldownUpdate")

	if GearRackCharDB.trinkets.Visible=="ON" and (GetInventoryItemLink("player",13) or GetInventoryItemLink("player",14)) then
		GearRackTrinkets_MainFrame:Show()
	end
end

-- returns true if the player is really dead or ghost, not merely FD
function GearRackTrinkets.IsPlayerReallyDead() return GearRackEngine.IsPlayerReallyDead() end

function GearRackTrinkets.ItemInfo(slot)
	local link,id,name,equipLoc,texture = GetInventoryItemLink("player",slot)
	if link then
		local _,_,id = string.find(link,"item:(%d+)")
		name,_,_,_,_,_,_,equipLoc,texture = GetItemInfo(id)
	else
		_,texture = GetInventorySlotInfo("Trinket"..(slot-13).."Slot")
	end
	return texture,name,equipLoc
end

-- IDs select queue items; name-only macro inputs require an exact name.
function GearRackTrinkets.FindItem(name,includeInventory,itemID)
    return GearRack.FindLocation(tonumber(itemID),name,true,includeInventory)
end

--[[ Frame Scripts ]]--

function GearRackTrinkets.UpdateWornTrinkets()
	GearRackTrinkets_Trinket0Icon:SetTexture(GearRackTrinkets.ItemInfo(13))
	GearRackTrinkets_Trinket1Icon:SetTexture(GearRackTrinkets.ItemInfo(14))
	GearRackTrinkets_Trinket0Icon:SetDesaturated(0)
	GearRackTrinkets_Trinket0:SetChecked(0)
	GearRackTrinkets_Trinket1Icon:SetDesaturated(0)
	GearRackTrinkets_Trinket1:SetChecked(0)

	local q0 = GetInventoryItemQuality("player", 13)
	if not q0 then
		local l0 = GetInventoryItemLink("player", 13)
		if l0 then local _, _, q = GetItemInfo(l0); q0 = q end
	end
	apply_trinket_quality_border(GearRackTrinkets_Trinket0, q0)

	local q1 = GetInventoryItemQuality("player", 14)
	if not q1 then
		local l1 = GetInventoryItemLink("player", 14)
		if l1 then local _, _, q = GetItemInfo(l1); q1 = q end
	end
	apply_trinket_quality_border(GearRackTrinkets_Trinket1, q1)

	GearRackTrinkets.UpdateWornCooldowns()
	local name
	for i=13,14 do
		_,_,name = string.find(GetInventoryItemLink("player",i) or "","%[(.+)%]")
		if name then
			GearRackTrinkets.AddWatchItem(name,i)
		end
	end
	if GearRackTrinkets_MenuFrame:IsVisible() then
		GearRackTrinkets.BuildMenu()
	end
	local owner=GearRackTrinkets.TooltipOwner
	if GearRackTrinkets.TooltipType=="INVENTORY" and owner and owner:IsVisible()
		and GameTooltip:GetOwner()==owner and MouseIsOver(owner) then
		GearRackTrinkets.TooltipUpdate()
	end
end

function GearRackTrinkets.SlashHandler(msg)

	msg = msg or ""
	local _,_,command,which,profile = string.find(msg,"^%s*(%S+)%s+(%S+)%s+(.+)$")

	if string.lower(command or "")=="load" and profile and GearRackTrinkets.SetQueue then
		profile = string.gsub(profile,"%s+$","")
		which = string.lower(which)
		if which=="top" or which=="0" then
			which = 0
		elseif which=="bottom" or which=="1" then
			which = 1
		end
		if type(which)=="number" then
			GearRackTrinkets.SetQueue(which,"SORT",profile)
			return
		end
	end

	msg = string.lower(msg)

	if not msg or msg=="" then
		GearRackTrinkets.ToggleFrame(GearRackTrinkets_MainFrame)
	elseif string.find(msg,"^opt") or string.find(msg,"^config") then
		GearRackTrinkets.ToggleFrame(GearRackTrinkets_OptFrame)
	elseif msg=="lock" then
		GearRackDB.trinketOptions.Locked="ON"
		GearRackTrinkets.DockWindows()
		GearRackTrinkets.ReflectLock()
	elseif msg=="unlock" then
		GearRackDB.trinketOptions.Locked="OFF"
		GearRackTrinkets.DockWindows()
		GearRackTrinkets.ReflectLock()
	elseif msg=="reset" then
		GearRackTrinkets.ResetSettings()
	elseif string.find(msg,"scale") then
		local _,_,menuscale = string.find(msg,"scale menu (.+)")
		if tonumber(menuscale) then
			GearRackTrinkets.FrameToScale = GearRackTrinkets_MenuFrame
			GearRackTrinkets.ScaleFrame(menuscale)
		end
		local _,_,mainscale = string.find(msg,"scale main (.+)")
		if tonumber(mainscale) then
			GearRackTrinkets.FrameToScale = GearRackTrinkets_MainFrame
			GearRackTrinkets.ScaleFrame(mainscale)
		end
		if not tonumber(menuscale) and not tonumber(mainscale) then
			DEFAULT_CHAT_FRAME:AddMessage("|cFFFFFF00GearRackTrinkets scale:")
			DEFAULT_CHAT_FRAME:AddMessage("/gr trinkets scale main (number) : set exact main scale")
			DEFAULT_CHAT_FRAME:AddMessage("/gr trinkets scale menu (number) : set exact menu scale")
			DEFAULT_CHAT_FRAME:AddMessage("ie, /gr trinkets scale menu 0.85")
			DEFAULT_CHAT_FRAME:AddMessage("Note: You can drag the lower-right corner of either window to scale.  This slash command is for those who want to set an exact scale.")
		end
		GearRackTrinkets.FrameToScale = nil
		GearRackCharDB.trinkets.MainScale = GearRackTrinkets_MainFrame:GetScale()
		GearRackCharDB.trinkets.MenuScale = GearRackTrinkets_MenuFrame:GetScale()
	elseif string.find(msg,"load") then
		DEFAULT_CHAT_FRAME:AddMessage("|cFFFFFF00GearRackTrinkets load:")
		DEFAULT_CHAT_FRAME:AddMessage("/gr trinkets load (top|bottom) profilename\nie: /gr trinkets load bottom PvP")
	else
		DEFAULT_CHAT_FRAME:AddMessage("|cFFFFFF00GearRackTrinkets usage:")
		DEFAULT_CHAT_FRAME:AddMessage("/gr trinkets : toggle trinket buttons")
		DEFAULT_CHAT_FRAME:AddMessage("/gr trinkets reset : reset trinket settings, positions and profiles (confirmation)")
		DEFAULT_CHAT_FRAME:AddMessage("/gr trinkets opt : summon options window")
		DEFAULT_CHAT_FRAME:AddMessage("/gr trinkets lock|unlock : toggles window lock")
		DEFAULT_CHAT_FRAME:AddMessage("/gr trinkets scale main|menu (number) : sets an exact scale")
		DEFAULT_CHAT_FRAME:AddMessage("/gr trinkets load top|bottom profilename : loads a profile to top or bottom trinket")
	end
end

function GearRackTrinkets.ResetSettings()
	StaticPopupDialogs["GEARRACKTRINKETSRESET"] = {
		text = "Reset trinket settings, positions, priority lists and profiles, then reload the UI?",
		button1 = "Yes", button2 = "No", showAlert=1, timeout = 0, whileDead = 1,
		OnAccept = function()
            GearRackDB.trinketOptions=nil;GearRackCharDB.trinkets=nil;GearRackCharDB.queues=nil
            table.wipe(GearRackCharDB.HeldQueues)
            ReloadUI()
        end,
	}
	StaticPopup_Show("GEARRACKTRINKETSRESET")
end

--[[ Window Movement ]]--

function GearRackTrinkets.MainFrame_OnMouseUp()
	if arg1=="LeftButton" then
		this:StopMovingOrSizing()
		GearRackCharDB.trinkets.XPos = GearRackTrinkets_MainFrame:GetLeft()
		GearRackCharDB.trinkets.YPos = GearRackTrinkets_MainFrame:GetTop()
	elseif GearRackDB.trinketOptions.Locked=="OFF" then
		if GearRackCharDB.trinkets.MainOrient=="VERTICAL" then
			GearRackCharDB.trinkets.MainOrient = "HORIZONTAL"
		else
			GearRackCharDB.trinkets.MainOrient = "VERTICAL"
		end
		GearRackTrinkets.OrientWindows()
	end

end

function GearRackTrinkets.MainFrame_OnMouseDown(arg1)
	if arg1=="LeftButton" and GearRackDB.trinketOptions.Locked=="OFF" then
		this:StartMoving()
	end
end

--[[ Timers (Native C++ C_Timer Architecture) ]]

-- Timer names are scoped to the trinket view in the single GearRackEngine timer owner.

local function timerName(name)
    return name=="CooldownUpdate" and name or ("Trinkets:"..name)
end
function GearRackTrinkets.CreateTimer(name,func,delay,rep)
    if name~="CooldownUpdate" then GearRackEngine.CreateTimer(timerName(name),func,delay,rep) end
end
function GearRackTrinkets.IsTimerActive(name) return GearRackEngine.TimerEnabled(timerName(name)) end
function GearRackTrinkets.StartTimer(name,delay) GearRackEngine.StartTimer(timerName(name),delay) end
function GearRackTrinkets.StopTimer(name) GearRackEngine.StopTimer(timerName(name)) end

--[[ OnClicks ]]

function GearRackTrinkets.MainTrinket_OnClick()
	if IsShiftKeyDown() and ChatFrameEditBox:IsVisible() then
		this:SetChecked(0)
		ChatFrameEditBox:Insert(GetInventoryItemLink("player",this:GetID()))
	elseif IsAltKeyDown() and GearRackTrinkets.QueueInit then
		local which = this:GetID()-13
		local held = GearRackCharDB.HeldQueues[which] or GearRackTrinkets.PausedQueue[which]
		GearRack.ResumeTrinketQueue(which)
		GearRackTrinkets.PausedQueue[which]=nil
		this:SetChecked(0)
		if GearRackCharDB.queues.Enabled[which] and not held then
			GearRack.CancelAutomaticTrinket(which)
			GearRackCharDB.queues.Enabled[which] = nil
		else
			GearRackCharDB.queues.Enabled[which] = 1
		end
--		GearRackCharDB.queues.Enabled[which] = not GearRackCharDB.queues.Enabled[which]
		GearRackTrinkets.ReflectQueueEnabled()
		GearRackTrinkets.UpdateCombatQueue()
		-- toggle queue
	elseif arg1=="RightButton" then
		this:SetChecked(0)
		GearRack.OpenTrinketPriorities(this:GetID())
	else
		UseInventoryItem(this:GetID())
	end
end

function GearRackTrinkets.MenuTrinket_OnClick()
	this:SetChecked(0)
	if IsShiftKeyDown() and ChatFrameEditBox:IsVisible() then
		ChatFrameEditBox:Insert(GetContainerItemLink(GearRackTrinkets.BaggedTrinkets[this:GetID()].bag,GearRackTrinkets.BaggedTrinkets[this:GetID()].slot))
	else
		local slot = (arg1=="LeftButton") and 13 or 14
		local chosen=GearRackTrinkets.BaggedTrinkets[this:GetID()]
		local _,liveID=GearRackEngine.GetItemInfo(chosen.bag,chosen.slot)
		if C_Item.GetItemGUID({bagID=chosen.bag,slotIndex=chosen.slot})~=chosen.guid then GearRack.InvalidateBag(chosen.bag);return end
		if GearRackTrinkets.QueueInit then
			local _,_,canCooldown = GetContainerItemCooldown(GearRackTrinkets.BaggedTrinkets[this:GetID()].bag,GearRackTrinkets.BaggedTrinkets[this:GetID()].slot)
			if canCooldown==0 or GearRackDB.trinketOptions.StopOnSwap=="ON" then -- if incoming trinket can't go on cooldown
				GearRackCharDB.queues.Enabled[slot-13]=nil -- turn off autoqueue
				GearRackTrinkets.ReflectQueueEnabled()
			end
		end
		GearRack.RequestItem(slot,{id=liveID,name=chosen.name,texture=chosen.texture,guid=chosen.guid},nil,true)
		if not IsShiftKeyDown() and GearRackDB.trinketOptions.KeepOpen=="OFF" then
			GearRackTrinkets_MenuFrame:Hide()
		end
	end
end

--[[ Docking ]]

function GearRackTrinkets.MenuFrame_OnMouseDown()
	if arg1=="LeftButton" and GearRackDB.trinketOptions.Locked=="OFF" then
		GearRackTrinkets_MenuFrame:StartMoving()

		if GearRackDB.trinketOptions.KeepDocked=="ON" then
			GearRackTrinkets.StartTimer("DockingMenu")
		end
	end
end

function GearRackTrinkets.MenuFrame_OnMouseUp()
	if arg1=="LeftButton" then
		GearRackTrinkets.StopTimer("DockingMenu")
		GearRackTrinkets_MenuFrame:StopMovingOrSizing()
		if GearRackDB.trinketOptions.KeepDocked=="ON" then
			GearRackTrinkets.DockWindows()
		end
	elseif GearRackDB.trinketOptions.Locked=="OFF" then
		if GearRackCharDB.trinkets.MenuOrient=="VERTICAL" then
			GearRackCharDB.trinkets.MenuOrient="HORIZONTAL"
		else
			GearRackCharDB.trinkets.MenuOrient="VERTICAL"
		end
		GearRackTrinkets.BuildMenu()
	end
end

function GearRackTrinkets.DockingMenu()

	local main = GearRackTrinkets_MainFrame
	local menu = GearRackTrinkets_MenuFrame
	local mainscale = GearRackTrinkets_MainFrame:GetScale()
	local menuscale = GearRackTrinkets_MenuFrame:GetScale()
	local near = GearRackTrinkets.Near

	if near(main:GetRight()*mainscale,menu:GetLeft()*menuscale) then
		if near(main:GetTop()*mainscale,menu:GetTop()*menuscale) then
			GearRackCharDB.trinkets.MainDock = "TOPRIGHT"
			GearRackCharDB.trinkets.MenuDock = "TOPLEFT"
		elseif near(main:GetBottom()*mainscale,menu:GetBottom()*menuscale) then
			GearRackCharDB.trinkets.MainDock = "BOTTOMRIGHT"
			GearRackCharDB.trinkets.MenuDock = "BOTTOMLEFT"
		end
	elseif near(main:GetLeft()*mainscale,menu:GetRight()*menuscale) then
		if near(main:GetTop()*mainscale,menu:GetTop()*menuscale) then
			GearRackCharDB.trinkets.MainDock = "TOPLEFT"
			GearRackCharDB.trinkets.MenuDock = "TOPRIGHT"
		elseif near(main:GetBottom()*mainscale,menu:GetBottom()*menuscale) then
			GearRackCharDB.trinkets.MainDock = "BOTTOMLEFT"
			GearRackCharDB.trinkets.MenuDock = "BOTTOMRIGHT"
		end
	elseif near(main:GetRight()*mainscale,menu:GetRight()*menuscale) then
		if near(main:GetTop()*mainscale,menu:GetBottom()*menuscale) then
			GearRackCharDB.trinkets.MainDock = "TOPRIGHT"
			GearRackCharDB.trinkets.MenuDock = "BOTTOMRIGHT"
		elseif near(main:GetBottom()*mainscale,menu:GetTop()*menuscale) then
			GearRackCharDB.trinkets.MainDock = "BOTTOMRIGHT"
			GearRackCharDB.trinkets.MenuDock = "TOPRIGHT"
		end
	elseif near(main:GetLeft()*mainscale,menu:GetLeft()*menuscale) then
		if near(main:GetTop()*mainscale,menu:GetBottom()*menuscale) then
			GearRackCharDB.trinkets.MainDock = "TOPLEFT"
			GearRackCharDB.trinkets.MenuDock = "BOTTOMLEFT"
		elseif near(main:GetBottom()*mainscale,menu:GetTop()*menuscale) then
			GearRackCharDB.trinkets.MainDock = "BOTTOMLEFT"
			GearRackCharDB.trinkets.MenuDock = "TOPLEFT"
		end
	end
	GearRackTrinkets.ClearDocking()
	getglobal("GearRackTrinkets_MainDock_"..GearRackCharDB.trinkets.MainDock):Show()
	getglobal("GearRackTrinkets_MenuDock_"..GearRackCharDB.trinkets.MenuDock):Show()
end

function GearRackTrinkets.MenuMouseover()
	if not GearRackTrinkets_MenuFrame:IsVisible() then
		GearRackTrinkets.StopTimer("MenuMouseover")
	elseif (not MouseIsOver(GearRackTrinkets_MainFrame)) and (not MouseIsOver(GearRackTrinkets_MenuFrame)) and not IsShiftKeyDown() and (GearRackDB.trinketOptions.KeepOpen=="OFF") and not GearRackTrinkets.IsTimerActive("Scaling") then
		GearRackTrinkets.StopTimer("MenuMouseover")
		GearRackTrinkets_MenuFrame:Hide()
	end
end

--[[ Scaling ]]

function GearRackTrinkets.StartScaling()
	if arg1=="LeftButton" and GearRackDB.trinketOptions.Locked=="OFF" then
		GearRackTrinkets.StopScalingFrame(GearRackTrinkets.FrameToScale)
		this:LockHighlight()
		GearRackTrinkets.ScalingButton = this
		GearRackTrinkets.FrameToScale = this:GetParent()
		GearRackTrinkets.ScalingWidth = this:GetParent():GetWidth()
		GearRackTrinkets.StartTimer("Scaling")
	end
end

function GearRackTrinkets.StopScaling()
	if arg1=="LeftButton" and GearRackTrinkets.ScalingButton==this then
		GearRackTrinkets.StopScalingFrame(this:GetParent())
	end
end

function GearRackTrinkets.StopScalingFrame(frame)
	if not frame or GearRackTrinkets.FrameToScale~=frame then return end
	GearRackTrinkets.StopTimer("Scaling")
	if GearRackTrinkets.ScalingButton then GearRackTrinkets.ScalingButton:UnlockHighlight() end
	GearRackTrinkets.ScalingButton = nil
	GearRackTrinkets.FrameToScale = nil
	if frame==GearRackTrinkets_MainFrame then
		GearRackCharDB.trinkets.MainScale = frame:GetScale()
	else
		GearRackCharDB.trinkets.MenuScale = frame:GetScale()
	end
end

function GearRackTrinkets.ScaleFrame(scale)
	scale = tonumber(scale)
	if not scale or scale~=scale or scale<=0 or scale==math.huge then return end
	local frame = GearRackTrinkets.FrameToScale
	local oldscale = frame:GetScale() or 1
	local framex = (frame:GetLeft() or GearRackCharDB.trinkets.XPos)* oldscale
	local framey = (frame:GetTop() or GearRackCharDB.trinkets.YPos)* oldscale

	frame:SetScale(scale)
	if frame:GetName() == "GearRackTrinkets_MainFrame" then
		GearRackTrinkets_MainFrame:SetPoint("TOPLEFT","UIParent","BOTTOMLEFT",framex/scale,framey/scale)
		GearRackCharDB.trinkets.XPos = GearRackTrinkets_MainFrame:GetLeft()
		GearRackCharDB.trinkets.YPos = GearRackTrinkets_MainFrame:GetTop()
	elseif GearRackDB.trinketOptions.KeepDocked=="OFF" then
		GearRackTrinkets_MenuFrame:ClearAllPoints()
		GearRackTrinkets_MenuFrame:SetPoint("TOPLEFT","UIParent","BOTTOMLEFT",framex/scale,framey/scale)
	end
end

function GearRackTrinkets.Scaling()
	local frame = GearRackTrinkets.FrameToScale
	if not frame or not frame:IsVisible() then
		GearRackTrinkets.StopTimer("Scaling")
		GearRackTrinkets.StopScalingFrame(frame)
		return
	end
	local oldscale = frame:GetEffectiveScale()
	local framex, framey, cursorx, cursory = frame:GetLeft()*oldscale, frame:GetTop()*oldscale, GetCursorPosition()
	if (cursorx-framex)>32 then
		local newscale = (cursorx-framex)/GearRackTrinkets.ScalingWidth
		GearRackTrinkets.ScaleFrame(newscale)
	end
end

--[[ Cooldowns ]]

function GearRackTrinkets.UpdateWornCooldowns(maybeGlobal)
	local start,duration,enable = GearRack.GetInventoryCooldown(13)
	CooldownFrame_SetTimer(GearRackTrinkets_Trinket0Cooldown,start,duration,enable)
	start,duration,enable = GearRack.GetInventoryCooldown(14)
	CooldownFrame_SetTimer(GearRackTrinkets_Trinket1Cooldown,start,duration,enable)
	if not maybeGlobal then
		GearRackTrinkets.WriteWornCooldowns()
	end
end

function GearRackTrinkets.UpdateMenuCooldowns()
	local start,duration,enable
	for i=1,GearRackTrinkets.NumberOfTrinkets do
		start,duration,enable = GetContainerItemCooldown(GearRackTrinkets.BaggedTrinkets[i].bag,GearRackTrinkets.BaggedTrinkets[i].slot)
		CooldownFrame_SetTimer(getglobal("GearRackTrinkets_Menu"..i.."Cooldown"),start,duration,enable)
	end
	GearRackTrinkets.WriteMenuCooldowns()
end

--[[ Item use ]]

-- Compatibility entry point: item-use identity and hooks have one owner.
function GearRackTrinkets.OnUseAction(slot) GearRackUI.OnUseAction(slot) end

function GearRackTrinkets.ReflectTrinketUse(slot)
	getglobal("GearRackTrinkets_Trinket"..(slot-13)):SetChecked(1)
	GearRackTrinkets.StartTimer("UpdateWornTrinkets")
	local _,_,id,trinket = string.find(GetInventoryItemLink("player",slot) or "","item:(%d+).+%[(.+)%]")
	if trinket then
		GearRackCharDB.trinkets.ItemsUsed[trinket] = 0 -- 0 is an indeterminate state, cooldown will figure if it's worth watching
		GearRackTrinkets.AddWatchItem(trinket,slot)
		GearRackTrinkets.WatchItem[trinket].rackUsed=GearRackDB.settings.Notify=="ON" or nil
	end
end

--[[ Tooltips ]]

function GearRackTrinkets.WornTrinketTooltip()
	local id = this:GetID()
	if GearRackTrinkets.IsTimerActive("Scaling") or GearRackDB.trinketOptions.ShowTooltips=="OFF" then
		return
	end
	GearRackTrinkets.TooltipOwner = this
	GearRackTrinkets.TooltipType = "INVENTORY"
	GearRackTrinkets.TooltipSlot = id
	GearRackTrinkets.TooltipBag = GearRackTrinkets.CombatQueue[id-13]
	GearRackTrinkets.AnchorTooltip(this)
	GearRackTrinkets.StartTimer("TooltipUpdate",0)
end

function GearRackTrinkets.MenuTrinketTooltip()
	local id = this:GetID()
	if GearRackTrinkets.IsTimerActive("Scaling") or GearRackDB.trinketOptions.ShowTooltips=="OFF" then
		return
	end
	GearRackTrinkets.TooltipOwner = this
	GearRackTrinkets.TooltipType = "BAG"
	GearRackTrinkets.TooltipBag = GearRackTrinkets.BaggedTrinkets[id].bag
	GearRackTrinkets.TooltipSlot = GearRackTrinkets.BaggedTrinkets[id].slot
	GearRackTrinkets.AnchorTooltip(this)
	GearRackTrinkets.StartTimer("TooltipUpdate",0)
end

function GearRackTrinkets.ClearTooltip()
	local owner=GearRackTrinkets.TooltipOwner
	if owner and GameTooltip:GetOwner()==owner then GameTooltip:Hide() end
	GearRackTrinkets.StopTimer("TooltipUpdate")
	GearRackTrinkets.TooltipType = nil
	GearRackTrinkets.TooltipOwner = nil
	GearRackTrinkets.TooltipBag = nil
	GearRackTrinkets.TooltipSlot = nil
end

local function clear_view_tooltip(frame)
	local owner=GearRackTrinkets.TooltipOwner
	while owner do
		if owner==frame then GearRackTrinkets.ClearTooltip();return end
		owner=owner:GetParent()
	end
end

function GearRackTrinkets.AnchorTooltip(owner)
	owner = owner or this
	if GearRackDB.trinketOptions.TooltipFollow=="ON" then
		if owner.GetLeft and owner:GetLeft() and owner:GetLeft()<400 then
			GameTooltip:SetOwner(owner,"ANCHOR_RIGHT")
		else
			GameTooltip:SetOwner(owner,"ANCHOR_LEFT")
		end
	else
		GameTooltip_SetDefaultAnchor(GameTooltip,owner)
	end
end

-- updates the tooltip created in the functions above
function GearRackTrinkets.TooltipUpdate()
	if GearRackTrinkets.TooltipType then
		local owner=GearRackTrinkets.TooltipOwner
		if not owner or not owner:IsVisible() or GameTooltip:GetOwner()~=owner then
			GearRackTrinkets.ClearTooltip()
			return
		end
		local cooldown
		GearRackTrinkets.AnchorTooltip(GearRackTrinkets.TooltipOwner)
		if GearRackTrinkets.TooltipType=="BAG" then
			GameTooltip:SetBagItem(GearRackTrinkets.TooltipBag,GearRackTrinkets.TooltipSlot)
			cooldown = GetContainerItemCooldown(GearRackTrinkets.TooltipBag,GearRackTrinkets.TooltipSlot)
		else
			GameTooltip:SetInventoryItem("player",GearRackTrinkets.TooltipSlot)
			cooldown = GearRack.GetInventoryCooldown(GearRackTrinkets.TooltipSlot)
		end
		if GearRackTrinkets.TooltipType=="INVENTORY" and GearRackTrinkets.TooltipBag then
			GameTooltip:AddLine("Queued: "..GearRackTrinkets.TooltipBag)
		end
		if GearRackTrinkets.TooltipType=="INVENTORY" then
			GameTooltip:AddLine("Right-click: trinkets",.78,.65,1)
		end
		GameTooltip:Show()
		if cooldown==0 then
			-- Keep the owned source for event-driven item changes, without polling.
			GearRackTrinkets.StopTimer("TooltipUpdate")
		elseif not GearRackTrinkets.IsTimerActive("TooltipUpdate") then
			GearRackTrinkets.StartTimer("TooltipUpdate")
		end
	end

end

-- normal tooltip for options
function GearRackTrinkets.OnTooltip(line1,line2)
	if GearRackDB.trinketOptions.ShowTooltips=="ON" then
		GearRackTrinkets.AnchorTooltip()
		if line1 then
			GameTooltip:AddLine(line1)
			GameTooltip:AddLine(line2,.8,.8,.8,1)
			GameTooltip:Show()
		else
			local name = this:GetName() or ""
			for i=1,#GearRackTrinkets.CheckOptInfo do
				if name=="GearRackTrinkets_Opt"..GearRackTrinkets.CheckOptInfo[i][1] and GearRackTrinkets.CheckOptInfo[i][3] then
					GearRackTrinkets.OnTooltip(GearRackTrinkets.CheckOptInfo[i][3],GearRackTrinkets.CheckOptInfo[i][4])
				end
			end
			for i=1,#GearRackTrinkets.TooltipInfo do
				if GearRackTrinkets.TooltipInfo[i][1]==name and GearRackTrinkets.TooltipInfo[i][2] then
					GearRackTrinkets.OnTooltip(GearRackTrinkets.TooltipInfo[i][2],GearRackTrinkets.TooltipInfo[i][3])
				end
			end
		end
	end
end

--[[ Combat Queue ]]

-- Optional read-only integration for tooltip addons. The queue stays owned here.
function GearRackTrinkets.GetQueuedSlotForItem(link)
	local _, _, id = string.find(link or "", "item:(%d+)")
	id = tonumber(id)
	if not id then return end
	for which=0,1 do
		if (GearRackTrinkets.CombatQueue[which] and GearRackTrinkets.QueueItemIDs[which]==id)
            or GearRack.BaseID(GearRackEngine.CombatQueue[13+which])==id then return 13+which end
	end
end

function GearRackTrinkets.EquipTrinketByName(name,slot,itemID,automatic)
    if slot~=13 and slot~=14 then return end
    local _,_,_,entry=GearRack.FindLocation(tonumber(itemID),name,true,true)
    if entry then GearRack.RequestItem(slot,entry,automatic,not automatic) end
end

-- Kept for macro callers; execution belongs entirely to the common equipment engine.
function GearRackTrinkets.ProcessCombatQueue() GearRack.Pump() end

function GearRackTrinkets.ReflectQueueState(which,state)
	local icon = getglobal("GearRackTrinkets_Trinket"..which.."Queue")
	local delayed,paused = state=="delay",state=="pause"
	if icon.gearRackDelayed~=delayed then
		icon.gearRackDelayed = delayed
		icon:SetDesaturated(delayed)
	end
	if icon.gearRackPaused~=paused then
		icon.gearRackPaused = paused
		icon:SetVertexColor(1,paused and .5 or 1,paused and .5 or 1)
	end
end

function GearRackTrinkets.UpdateCombatQueue()
	local bag,slot
	for which=0,1 do
		local trinket = GearRackTrinkets.CombatQueue[which]
		local icon = getglobal("GearRackTrinkets_Trinket"..which.."Queue")
		icon:Hide()
		local held = not trinket and GearRackCharDB.queues and GearRackCharDB.queues.Enabled[which]
			and (GearRackCharDB.HeldQueues[which] or GearRackTrinkets.PausedQueue[which])
		GearRackTrinkets.ReflectQueueState(which,held and "pause" or nil)
		if trinket then
			_,bag,slot = GearRackTrinkets.FindItem(trinket,nil,GearRackTrinkets.QueueItemIDs[which])
			if bag then
				icon:SetTexture(GetContainerItemInfo(bag,slot))
				icon:Show()
			end
		elseif GearRackTrinkets.QueueInit and GearRackCharDB.queues and GearRackCharDB.queues.Enabled[which] then
			icon:SetTexture("Interface\\AddOns\\GearRack\\media\\Trinket-Queue")
			icon:Show()
		end
	end
end

--[[ Notify ]]

function GearRackTrinkets.Notify(msg)
	PlaySound("GnomeExploration")
	if SCT_Display then -- send via SCT if it exists
		SCT_Display(msg,{r=.2,g=.7,b=.9})
	elseif SHOW_COMBAT_TEXT=="1" then
		CombatText_AddMessage(msg, CombatText_StandardScroll, .2, .7, .9) -- or default UI's SCT
	else
		-- send vis UIErrorsFrame if neither SCT exists
		UIErrorsFrame:AddMessage(msg,.2,.7,.9,1,UIERRORS_HOLD_TIME)
	end
	if GearRackDB.trinketOptions.NotifyChatAlso=="ON" then
		DEFAULT_CHAT_FRAME:AddMessage("|cff33b2e5"..msg)
	end
end

-- adds location of the name to a watch table for fast lookups
-- pass inv bag slot to override the search
function GearRackTrinkets.AddWatchItem(name,inv,bag,slot)
	GearRackTrinkets.WatchItem[name] = GearRackTrinkets.WatchItem[name] or {}
	if not inv and not bag then
		inv = GearRackTrinkets.WatchItem[name].inv
		bag = GearRackTrinkets.WatchItem[name].bag
		slot = GearRackTrinkets.WatchItem[name].slot
		local link = (inv and GetInventoryItemLink("player",inv)) or (bag and GetContainerItemLink(bag,slot)) or ""
		local _,_,currentName = string.find(link,"%[(.+)%]")
		if currentName~=name then
			inv,bag,slot = GearRackTrinkets.FindItem(name,1)
		end
	end
	GearRackTrinkets.WatchItem[name].inv = inv
	GearRackTrinkets.WatchItem[name].bag = bag
	GearRackTrinkets.WatchItem[name].slot = slot
end

function GearRackTrinkets.CooldownUpdate()
	local inv,bag,slot,start,duration,name,remain
	local watch = GearRackTrinkets.WatchItem
	for i in pairs(GearRackCharDB.trinkets.ItemsUsed) do
		start,name = nil
		if not watch[i] then GearRackTrinkets.AddWatchItem(i) end -- if not on watch table, add it
		inv,bag,slot = watch[i].inv,watch[i].bag,watch[i].slot
		if inv then -- if it was last seen in an inv slot, get name in that slot
			_,_,name = string.find(GetInventoryItemLink("player",inv) or "","%[(.+)%]")
		end
		if bag then -- if it was last seen in a container slot, get name in that slot
			_,_,name = string.find(GetContainerItemLink(bag,slot) or "","%[(.+)%]")
		end
		if name~=i then -- item has moved
			inv,bag,slot = GearRackTrinkets.FindItem(i,1)
			watch[i].inv,watch[i].bag,watch[i].slot = inv,bag,slot
		end
		if inv then
			start,duration = GearRack.GetInventoryCooldown(inv)
		elseif bag then
			start,duration = GetContainerItemCooldown(bag,slot)
		else
			GearRackCharDB.trinkets.ItemsUsed[i] = nil
		end
		if start and GearRackCharDB.trinkets.ItemsUsed[i]<3 then
			GearRackCharDB.trinkets.ItemsUsed[i] = GearRackCharDB.trinkets.ItemsUsed[i] + 1 -- count for 3 seconds before seeing if this is a real cooldown
		elseif start then
			if start>0 then
				remain = duration - (GetTime()-start)
				if GearRackCharDB.trinkets.ItemsUsed[i]<5 then
					if remain>29 then
						GearRackCharDB.trinkets.ItemsUsed[i] = 30 -- first actual cooldown greater than 30 seconds, tag it for 30+0 notify
					elseif remain>5 then
						GearRackCharDB.trinkets.ItemsUsed[i] = 5 -- first actual cooldown less than 30 but greater than 5, tag for 0 notify
						if watch[i].rackUsed and GearRackDB.settings.NotifyThirty=="ON" then GearRack.TrinketReady(i,true) end
					end
				end
			end
			if GearRackCharDB.trinkets.ItemsUsed[i]==30 and start>0 and remain<30 then
				GearRack.TrinketReady(i,true)
				GearRackCharDB.trinkets.ItemsUsed[i]=5 -- tag for just 0 notify now
			elseif GearRackCharDB.trinkets.ItemsUsed[i]==5 and start==0 then
				GearRack.TrinketReady(i,false)
			end
			if start==0 then
				GearRackCharDB.trinkets.ItemsUsed[i] = nil
			end
		end
	end

    -- GearRack permanently owns cooldown numbers; only visible views need updates.
    if GearRackTrinkets_MainFrame:IsVisible() then
        GearRackTrinkets.WriteWornCooldowns()
    end
    if GearRackTrinkets_MenuFrame:IsVisible() then
        GearRackTrinkets.WriteMenuCooldowns()
    end

	if GearRackTrinkets.PeriodicQueueCheck then
		GearRackTrinkets.PeriodicQueueCheck()
	end
end

function GearRackTrinkets.WriteWornCooldowns()
	local start, duration
	start, duration = GearRack.GetInventoryCooldown(13)
	GearRackTrinkets.WriteCooldown(GearRackTrinkets_Trinket0Time,start,duration)
	start, duration = GearRack.GetInventoryCooldown(14)
	GearRackTrinkets.WriteCooldown(GearRackTrinkets_Trinket1Time,start,duration)
end

function GearRackTrinkets.WriteMenuCooldowns()
	local start, duration
	for i=1,GearRackTrinkets.NumberOfTrinkets do
		start, duration = GetContainerItemCooldown(GearRackTrinkets.BaggedTrinkets[i].bag,GearRackTrinkets.BaggedTrinkets[i].slot)
		GearRackTrinkets.WriteCooldown(getglobal("GearRackTrinkets_Menu"..i.."Time"),start,duration)
	end
end

function GearRackTrinkets.WriteCooldown(where,start,duration)
	local cooldown = duration - (GetTime()-start)
	local previous,text = where:GetText(),""
	if start==0 or cooldown<=0 then
		text = ""
	elseif cooldown<3 and (not previous or previous=="") then
		-- this is a global cooldown. don't display it. not accurate but at least not annoying
	else
		text = (cooldown<60 and math.floor(cooldown+.5).." s") or (cooldown<3600 and math.ceil(cooldown/60).." m") or math.ceil(cooldown/3600).." h"
	end
	if (previous or "")~=text then where:SetText(text) end
end

function GearRackTrinkets.OnShow()
	GearRackCharDB.trinkets.Visible = "ON"
	if GearRackDB.trinketOptions.KeepOpen=="ON" then
		GearRackTrinkets.BuildMenu()
	end
end

function GearRackTrinkets.OnHide()
	-- Ancestor hides deliver OnHide without clearing this frame's shown bit.
	if not GearRackTrinkets_MainFrame:IsShown() then GearRackCharDB.trinkets.Visible = "OFF" end
	GearRackTrinkets_MainFrame:StopMovingOrSizing()
	GearRackTrinkets.StopScalingFrame(GearRackTrinkets_MainFrame)
	clear_view_tooltip(GearRackTrinkets_MainFrame)
	GearRackTrinkets_MenuFrame:Hide()
end

function GearRackTrinkets.MenuFrame_OnHide()
	GearRackTrinkets.StopTimer("MenuMouseover")
	GearRackTrinkets.StopTimer("DockingMenu")
	GearRackTrinkets_MenuFrame:StopMovingOrSizing()
	GearRackTrinkets.StopScalingFrame(GearRackTrinkets_MenuFrame)
	GearRackTrinkets.ClearDocking()
	clear_view_tooltip(GearRackTrinkets_MenuFrame)
end

--[[ Key bindings ]]

function GearRackTrinkets.ReflectKeyBindings()
	local show=GearRackDB.trinketOptions.ShowHotKeys=="ON"
	for which=0,1 do
		local label=_G["GearRackTrinkets_Trinket"..which.."HotKey"]
		local command=which==0 and "GEARRACK_USE_TOP_TRINKET_ITEM" or "GEARRACK_USE_BOTTOM_TRINKET_ITEM"
		local key=show and GetBindingKey(command)
		label:SetText(key and GetBindingText(key,"KEY_",1) or "")
		label:SetTextColor(1,0.95,0.8)
		if key then label:Show() else label:Hide() end
	end
end
