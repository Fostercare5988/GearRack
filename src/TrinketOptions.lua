if not GearRack.enabled then return end

local _, ns = ...
local UI = ns.UI

--[[ TrinketOptions.lua : Options and sort window for GearRackTrinkets ]]

GearRackTrinkets.CheckOptInfo = {
{"TooltipFollow","OFF","Beside Item","Show tooltips beside the item instead of in the default spot.","ShowTooltips"},
{"KeepOpen","OFF","Keep Menu Open","Keep the trinket list open all the time."},
{"KeepDocked","ON","Keep Menu Docked","Keep the trinket list attached to the trinket buttons."},
{"Notify","OFF","Notify When Ready","Show a message on screen when a trinket is ready again."},
{"NotifyChatAlso","OFF","Notify Chat Also","Also send these messages to chat."},
{"Locked","OFF","Lock Windows","Stop the windows from being moved, resized or rotated."},
{"ShowTooltips","ON","Show Tooltips","Show tooltips."},
{"NotifyThirty","OFF","Notify At 30 sec","Show a message when a trinket has 30 seconds of cooldown left."},
{"MenuOnShift","OFF","Menu On Shift","The trinket list only opens while you hold Shift."},
{"SetColumns","OFF","Set Menu Columns","Choose how many trinkets show per row in the trinket list. Off: GearRack chooses."},
{"ShowHotKeys","ON","Show key labels","Show the keys from the game's Key Bindings menu on your worn trinkets."},
{"StopOnSwap","OFF","Stop Queue On Swap","Picking a trinket yourself turns that slot's automatic order off. Trinkets without a use effect always do."},
{"HideOnLoad","OFF","Close On Profile Load","Close this window when you load a profile."}
}

GearRackTrinkets.TooltipInfo = {
{"GearRackTrinkets_LockButton","Lock Windows","Stop the windows from being moved, resized or rotated."},
{"GearRackTrinkets_Trinket0Check","Top trinket priority queue","Automatic order for this slot: GearRack puts on the best ready trinket from the list. A trinket you pick yourself pauses it (with Keep manual choices on). Tick this or Alt-click the worn trinket to resume."},
{"GearRackTrinkets_Trinket1Check","Bottom trinket priority queue","Automatic order for this slot: GearRack puts on the best ready trinket from the list. A trinket you pick yourself pauses it (with Keep manual choices on). Tick this or Alt-click the worn trinket to resume."},
{"GearRackTrinkets_SortPriority","High Priority","Put this trinket on as soon as it is ready, even if the worn one is ready too. Off: it only replaces a worn trinket that is on cooldown."},
{"GearRackTrinkets_SortDelay","Swap Delay","Seconds to keep this trinket on after using it, such as 20 for Earthstrike's 20-second buff."},
{"GearRackTrinkets_SortKeepEquipped","Pause Queue","No automatic swaps while this trinket is worn, such as Carrot on a Stick."},
{"GearRackTrinkets_Profiles","Profiles","Save or load trinket orders."},
{"GearRackTrinkets_Delete","Delete","Remove this trinket from the list. Trinkets in your bags come back at the bottom later; keep them below the stop line so they are never picked."},
{"GearRackTrinkets_ProfilesDelete","Delete Profile","Delete this profile."},
{"GearRackTrinkets_ProfilesLoad","Load Profile","Load this order into the open slot. Double-clicking a profile does the same."},
{"GearRackTrinkets_ProfilesSave","Save Profile","Save the open slot's order. Either slot can load it."},
{"GearRackTrinkets_ProfileName","Profile Name","Name for the profile. Either slot can load it."},
}

function GearRackTrinkets.InitOptions()
	local item
	for i=1,#GearRackTrinkets.CheckOptInfo do
		item = _G["GearRackTrinkets_Opt"..GearRackTrinkets.CheckOptInfo[i][1].."Text"]
		if item then
			item:SetText(GearRackTrinkets.CheckOptInfo[i][3])
			UI.Color(item,"text")
		end
	end
	GearRackTrinkets.Tab_OnClick(1)
	table.insert(UISpecialFrames,"GearRackTrinkets_OptFrame")
	GearRackTrinkets_Title:SetText("GearRack: Trinkets")

	if GearRackTrinkets.QueueInit then
		GearRackTrinkets.QueueInit()
		GearRackTrinkets_Tab1:Show()
		GearRackTrinkets_OptFrame:SetHeight(326)
		GearRackTrinkets_SubOptFrame:SetPoint("TOPLEFT",GearRackTrinkets_OptFrame,"TOPLEFT",8,-50)
	else
		GearRackTrinkets_OptStopOnSwap:Hide() -- remove StopOnSwap option if queue not loaded
		GearRackTrinkets_Tab1:Hide() -- hide options tab if it's only tab
		GearRackTrinkets_OptFrame:SetHeight(300)
		GearRackTrinkets_SubOptFrame:SetPoint("TOPLEFT",GearRackTrinkets_OptFrame,"TOPLEFT",8,-24)
	end
	GearRackTrinkets_OptColumnsSlider:SetValue(GearRackDB.trinketOptions.Columns)
	GearRackTrinkets.ReflectLock()
	GearRackTrinkets.ReflectCooldownFont()
	GearRackTrinkets.ReflectKeyBindings()
end

function GearRackTrinkets.ToggleFrame(frame)
	if frame:IsVisible() then
		frame:Hide()
	else
		frame:Show()
	end
end

function GearRackTrinkets.OptFrame_OnShow()
	GearRackTrinkets.ValidateChecks()
	if GearRackShowTrinkets then
		GearRackShowTrinkets:SetChecked(GearRackCharDB.trinkets.Visible=="ON")
		GearRackHoldTrinkets:SetChecked(GearRackCharDB.KeepManualTrinkets)
	end
	if GearRackTrinkets.CurrentlySorting then
		GearRackTrinkets.PopulateSort(GearRackTrinkets.CurrentlySorting)
	end
end

--[[ Minimap button ]]

function GearRackTrinkets.ValidateChecks()
	local check,button
	for i=1,#GearRackTrinkets.CheckOptInfo do
		check = GearRackTrinkets.CheckOptInfo[i]
		button = _G["GearRackTrinkets_Opt"..check[1]]
		if button then
			button:SetChecked(GearRackDB.trinketOptions[check[1]]=="ON")
			if check[5] then
				local enabled = GearRackDB.trinketOptions[check[5]]=="ON"
				if enabled then button:Enable() else button:Disable() end
				UI.Color(_G["GearRackTrinkets_Opt"..check[1].."Text"],enabled and "text" or "hint")
			end
		end
	end
	GearRackTrinkets_OptColumnsSlider:SetAlpha((GearRackDB.trinketOptions.SetColumns=="ON") and 1 or .5)
	GearRackTrinkets_OptColumnsSlider:EnableMouse((GearRackDB.trinketOptions.SetColumns=="ON") and 1 or 0)
	GearRackTrinkets_OptColumnsSlider:SetValue(GearRackDB.trinketOptions.Columns)
end

function GearRackTrinkets.OptColumnsSlider_OnValueChanged()
	if GearRackDB.trinketOptions then
		GearRackDB.trinketOptions.Columns = this:GetValue()
		GearRackTrinkets_OptColumnsSliderText:SetText(GearRackDB.trinketOptions.Columns.." trinkets")
		if GearRackTrinkets_MenuFrame:IsVisible() then
			GearRackTrinkets.BuildMenu()
		end
	end
end

function GearRackTrinkets.CheckButton_OnClick()
	local _,_,var = string.find(this:GetName(),"GearRackTrinkets_Opt(.+)")
	if GearRackDB.trinketOptions[var] then
		GearRackDB.trinketOptions[var] = this:GetChecked() and "ON" or "OFF"
		PlaySound(this:GetChecked() and "igMainMenuOptionCheckBoxOn" or "igMainMenuOptionCheckBoxOff")
		GearRackTrinkets.ValidateChecks()
	end

	if this==GearRackTrinkets_OptLocked then
		GearRackTrinkets.DockWindows()
		GearRackTrinkets.ReflectLock()
	elseif this==GearRackTrinkets_OptKeepOpen or this==GearRackTrinkets_OptSetColumns then
		if GearRackDB.trinketOptions.KeepOpen=="ON" then
			GearRackTrinkets.BuildMenu()
		end
	elseif this==GearRackTrinkets_OptKeepDocked then
		GearRackTrinkets.DockWindows()
	elseif this==GearRackTrinkets_OptShowHotKeys then
		GearRackTrinkets.ReflectKeyBindings()
	end
end

function GearRackTrinkets.ReflectLock()
	local c = GearRackDB.trinketOptions.Locked=="ON" and 0 or .5
	if c==0 then
		GearRackTrinkets_MainFrame:StopMovingOrSizing()
		GearRackTrinkets_MenuFrame:StopMovingOrSizing()
		GearRackTrinkets_OptFrame:StopMovingOrSizing()
		GearRackTrinkets.StopTimer("DockingMenu")
		GearRackTrinkets.StopScalingFrame(GearRackTrinkets.FrameToScale)
		GearRackTrinkets.ClearDocking()
	end
	GearRackTrinkets_MainFrame:SetBackdropColor(c,c,c,c)
	GearRackTrinkets_MainFrame:SetBackdropBorderColor(c,c,c,c*2)
	GearRackTrinkets_MenuFrame:SetBackdropColor(c,c,c,c)
	GearRackTrinkets_MenuFrame:SetBackdropBorderColor(c,c,c,c*2)
	GearRackTrinkets_MenuFrame:EnableMouse(c*2)
	GearRackTrinkets_OptLocked:SetChecked(1-c*2)
	local normalTexture = GearRackTrinkets_LockButton:GetNormalTexture()
	local pushedTexture = GearRackTrinkets_LockButton:GetPushedTexture()
	if c==0 then
		GearRackTrinkets_MainResizeButton:Hide()
		GearRackTrinkets_MenuResizeButton:Hide()
		normalTexture:SetTexCoord(.875,1,.125,.25)
		pushedTexture:SetTexCoord(.75,.875,.125,.25)
	else
		GearRackTrinkets_MainResizeButton:Show()
		GearRackTrinkets_MenuResizeButton:Show()
		normalTexture:SetTexCoord(.75,.875,.125,.25)
		pushedTexture:SetTexCoord(.875,1,.125,.25)
	end
end

function GearRackTrinkets.ReflectCooldownFont()
	GearRackTrinkets.SetCooldownFont("GearRackTrinkets_Trinket0")
	GearRackTrinkets.SetCooldownFont("GearRackTrinkets_Trinket1")
	for i=1,30 do
		GearRackTrinkets.SetCooldownFont("GearRackTrinkets_Menu"..i)
	end
end

function GearRackTrinkets.SetCooldownFont(button)
    GearRack.StyleCooldownNumbers(_G[button.."Time"],button)
end


--[[ Titlebar buttons ]]

function GearRackTrinkets.SmallButton_OnClick()
	PlaySound("igMainMenuOptionCheckBoxOn")
	if this==GearRackTrinkets_CloseButton then
		GearRack.CloseMenus()
	elseif this==GearRackTrinkets_LockButton then
		GearRackDB.trinketOptions.Locked = (GearRackDB.trinketOptions.Locked=="ON") and "OFF" or "ON"
		GearRackTrinkets.DockWindows()
		GearRackTrinkets.ReflectLock()
	end
end

--[[ Tabs ]]

function GearRackTrinkets.Tab_OnClick(override)
	PlaySound("GAMEGENERICBUTTONPRESS")
	local id = override or this:GetID()
	GearRackTrinkets.SelectedTab=id
	if GearRackTrinkets_ProfilesFrame then
		GearRackTrinkets_ProfilesFrame:Hide()
	end
	for i=1,3 do
		ns.SelectPill(_G["GearRackTrinkets_Tab"..i],i==id)
	end
	if id==1 then
		GearRackTrinkets_SubOptFrame:Show()
		if GearRackTrinkets_SubQueueFrame then
			GearRackTrinkets_SubQueueFrame:Hide()
		end
	else
		GearRackTrinkets_SubOptFrame:Hide()
		GearRackTrinkets_SubQueueFrame:Show()
		GearRackTrinkets.OpenSort(3-id)
	end
end
