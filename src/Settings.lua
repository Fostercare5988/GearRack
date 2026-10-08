if not GearRack.enabled then return end

-- The primary gear editor is also the existing /gr and binding entry point.
function GearRack.ToggleSettings()
    if GearRackUI_SetsFrame:IsShown() then
        GearRack.CloseMenus()
    else
        GearRack.OpenGearSets()
    end
end

function GearRack.GetBarProfile()
    return GearRackDB.bars[UnitName("player").." of "..GetRealmName()]
end

function GearRack.OpenGearSets()
    GearRackUI_MenuFrame:Hide()
    GearRack.ShowMenuPage(GearRackUI_SetsFrame,2,true)
end

function GearRack.SetSetButtonVisible(visible)
    local saved=GearRack.GetBarProfile()
    local found=false
    for i=#saved.Bar,1,-1 do
        if saved.Bar[i]==20 then
            if not visible then saved.SetButtonPosition=i end
            if not visible or found then table.remove(saved.Bar,i) else found=true end
        end
    end
    if visible and not found then
        local position=tonumber(saved.SetButtonPosition)
        if not position or position~=position or math.abs(position)==math.huge then position=#saved.Bar+1 end
        position=math.max(1,math.min(#saved.Bar+1,math.floor(position)))
        table.insert(saved.Bar,position,20)
        saved.SetButtonPosition=position
    end
    saved.Inv[20]=visible and 1 or nil
    GearRackUI_RefreshBar()
end

function GearRack.SlashHandler(input)
    input=string.match(input or "","^%s*(.-)%s*$")
    local command=string.lower(input)
    if command=="" or command=="opt" or command=="options" then GearRack.ToggleSettings()
    elseif command=="trinkets" then GearRackTrinkets.SlashHandler("")
    elseif string.find(command,"^trinkets%s+") then GearRackTrinkets.SlashHandler(string.match(input,"^%S+%s+(.*)$"))
    elseif command=="queues" then GearRack.OpenTrinketPriorities()
    elseif command=="sets" then GearRack.OpenGearSets()
    elseif command=="layout" then GearRack.OpenBarLayout()
    elseif command=="keys" then GearRack.CloseMenus();KeyBindingFrame_LoadUI();ShowUIPanel(KeyBindingFrame)
    elseif command=="bar" then GearRackUI_Toggle()
    elseif string.find(command,"^equip%s+") or string.find(command,"^toggle%s+") or command=="lock" or command=="unlock"
        or string.find(command,"^scale%s+") or command=="reset bar" or command=="reset event" or command=="reset events" then GearRackUI_SlashHandler(input)
    else
        DEFAULT_CHAT_FRAME:AddMessage("GearRack: /gr opens Gear sets; layout, trinkets, queues or sets.")
    end
end

function GearRack.CreateSettingsPanel(name,titleText,height)
    local frame=CreateFrame("Frame",name,UIParent)
    frame:SetWidth(360)
    frame:SetHeight(height)
    frame:SetPoint("CENTER",UIParent,"CENTER",0,0)
    frame:SetFrameStrata("DIALOG")
    frame:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",
        edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",edgeSize=12,
        insets={left=4,right=4,top=4,bottom=4}})
    frame:SetBackdropColor(0.055,0.045,0.075,0.97)
    frame:SetBackdropBorderColor(0.55,0.43,0.72,1)
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart",function() this:StartMoving() end)
    frame:SetScript("OnDragStop",function() this:StopMovingOrSizing() end)
    frame:SetScript("OnHide",function() this:StopMovingOrSizing() end)
    table.insert(UISpecialFrames,name)
    local title=frame:CreateFontString(nil,"OVERLAY","GameFontNormalLarge")
    local child=name=="GearRackBarLayout"
    title:SetPoint("TOPLEFT",frame,"TOPLEFT",child and 92 or 18,-16)
    title:SetText(titleText)
    title:SetTextColor(0.78,0.65,1)
    local close=CreateFrame("Button",nil,frame,"UIPanelCloseButton")
    close:SetPoint("TOPRIGHT",frame,"TOPRIGHT",-4,-4)
    close:SetScript("OnClick",GearRack.CloseMenus)
    if child then GearRack.CreateSettingsButton(frame,name.."Back","Back",18,-9,GearRack.BackMenu,64) end
    frame:Hide()
    return frame
end

function GearRack.CreateSettingsButton(frame,name,label,x,y,action,width)
    local widget=CreateFrame("Button",name,frame)
    widget:SetWidth(width or 156);widget:SetHeight(32)
    widget:SetPoint("TOPLEFT",frame,"TOPLEFT",x,y)
    widget:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",
        edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",edgeSize=8,
        insets={left=2,right=2,top=2,bottom=2}})
    widget:SetBackdropColor(0.14,0.10,0.20,1)
    widget:SetBackdropBorderColor(0.42,0.33,0.54,1)
    local text=widget:CreateFontString(nil,"OVERLAY","GameFontHighlight")
    text:SetPoint("CENTER",widget,"CENTER",0,0)
    text:SetWidth(widget:GetWidth()-12)
    text:SetHeight(26)
    text:SetText(label)
    widget.label=text
    widget:SetScript("OnEnter",function() this:SetBackdropColor(0.25,0.18,0.35,1) end)
    widget:SetScript("OnLeave",function() this:SetBackdropColor(0.14,0.10,0.20,1) end)
    -- Actions take domain arguments, not ClassicAPI's (button, mouseButton).
    widget:SetScript("OnClick",function() action() end)
    return widget
end

function GearRack.CreateSettings()
    SlashCmdList.GEARRACK=GearRack.SlashHandler
    SLASH_GEARRACK1="/gearrack"
    SLASH_GEARRACK2="/gr"
    BINDING_HEADER_GEARRACK="GearRack"
    GearRack.CreateBarLayout()
    GearRack.CreateNavigation()
    GearRack.CreateMinimapButtons()
end
