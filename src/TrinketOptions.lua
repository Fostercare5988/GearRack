if not GearRack.enabled then return end

--[[ TrinketOptions.lua : Options and sort window for GearRackTrinkets ]]

GearRackTrinkets.CheckOptInfo = {
{"TooltipFollow","OFF","Beside Item","Place tooltips beside the hovered item instead of using the default tooltip position.","ShowTooltips"},
{"KeepOpen","OFF","Keep Menu Open","Keep menu open at all times."},
{"KeepDocked","ON","Keep Menu Docked","Keep menu docked at all times."},
{"Notify","OFF","Notify When Ready","Sends an overhead notification when a trinket's cooldown is complete."},
{"NotifyChatAlso","OFF","Notify Chat Also","Sends notifications through chat also."},
{"Locked","OFF","Lock Windows","Prevents the windows from being moved, resized or rotated."},
{"ShowTooltips","ON","Show Tooltips","Shows tooltips."},
{"NotifyThirty","OFF","Notify At 30 sec","Sends an overhead notification when a trinket has 30 seconds left on cooldown."},
{"MenuOnShift","OFF","Menu On Shift","Check this to prevent the menu appearing unless Shift is held."},
{"SetColumns","OFF","Set Menu Columns","Define how many trinkets before the menu will wrap to the next row.\n\nUncheck to let GearRack choose how to wrap the menu."},
{"ShowHotKeys","ON","Show key labels","Display the keys assigned in the game's Key Bindings menu on your equipped trinkets."},
{"StopOnSwap","OFF","Stop Queue On Swap","Stop this slot's priority queue whenever you manually choose a trinket in the drawer. Passive trinkets always stop the queue."},
{"HideOnLoad","OFF","Close On Profile Load","Check this to dismiss this window when you load a profile."}
}

-- table.insert(GearRackTrinkets.CheckOptInfo,)

GearRackTrinkets.TooltipInfo = {
{"GearRackTrinkets_LockButton","Lock Windows","Prevents the windows from being moved, resized or rotated."},
{"GearRackTrinkets_Trinket0Check","Top trinket priority queue","Check to enable or resume this slot. Manual choices pause it when Keep manual choices is enabled. Alt-click the worn trinket to resume or toggle."},
{"GearRackTrinkets_Trinket1Check","Bottom trinket priority queue","Check to enable or resume this slot. Manual choices pause it when Keep manual choices is enabled. Alt-click the worn trinket to resume or toggle."},
{"GearRackTrinkets_SortPriority","High Priority","When checked, this trinket will be swapped in as soon as possible, whether the equipped trinket is on cooldown or not.\n\nWhen unchecked, this trinket will not equip over one already worn that's not on cooldown."},
{"GearRackTrinkets_SortDelay","Swap Delay","This is the time (in seconds) before a trinket will be swapped out.  ie, for Earthstrike you want 20 seconds to get the full 20 second effect of the buff."},
{"GearRackTrinkets_SortKeepEquipped","Pause Queue","Check this to suspend the auto queue while this trinket is equipped. ie, for Carrot on a Stick if you have a mod to auto-equip it to a slot with Auto Queue active."},
{"GearRackTrinkets_Profiles","Profiles","Here you can load or save auto queue profiles."},
{"GearRackTrinkets_Delete","Delete","Remove this trinket from the list. Carried trinkets return to the end when the list is refreshed. Move Stop Queue Here to control which trinkets can be selected automatically."},
{"GearRackTrinkets_ProfilesDelete","Delete Profile","Remove this profile."},
{"GearRackTrinkets_ProfilesLoad","Load Profile","Load a queue order for the selected trinket slot.  You can double-click a profile to load it also."},
{"GearRackTrinkets_ProfilesSave","Save Profile","Save the queue order from the selected trinket slot.  Either trinket slot can use saved profiles."},
{"GearRackTrinkets_ProfileName","Profile Name","Enter a name to call the profile.  When saved, you can load this profile to either trinket slot."},
}

function GearRackTrinkets.InitOptions()
	local item
	for i=1,#GearRackTrinkets.CheckOptInfo do
		item = _G["GearRackTrinkets_Opt"..GearRackTrinkets.CheckOptInfo[i][1].."Text"]
		if item then
			item:SetText(GearRackTrinkets.CheckOptInfo[i][3])
			item:SetTextColor(.95,.95,.95)
		end
	end
	GearRackTrinkets.Tab_OnClick(1)
	table.insert(UISpecialFrames,"GearRackTrinkets_OptFrame")
	GearRackTrinkets_Title:SetText("GearRack: Trinkets")

	GearRackTrinkets_OptFrame:SetBackdropBorderColor(.3,.3,.3,1)
	GearRackTrinkets_SubOptFrame:SetBackdropBorderColor(.3,.3,.3,1)
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
				if GearRackDB.trinketOptions[check[5]]=="ON" then
					button:Enable()
					_G["GearRackTrinkets_Opt"..check[1].."Text"]:SetTextColor(.95,.95,.95)
				else
					button:Disable()
					_G["GearRackTrinkets_Opt"..check[1].."Text"]:SetTextColor(.5,.5,.5)
				end
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
	GearRackTrinkets_OptFrame:SetBackdropBorderColor(c,c,c,1)
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
	local tab
	if GearRackTrinkets_ProfilesFrame then
		GearRackTrinkets_ProfilesFrame:Hide()
	end
	for i=1,3 do
		tab = _G["GearRackTrinkets_Tab"..i]
		if tab then
			tab:UnlockHighlight()
		end
	end
	_G["GearRackTrinkets_Tab"..id]:LockHighlight()
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
