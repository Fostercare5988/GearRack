if not GearRack.enabled then return end

-- GearRack: one equipment owner for sets, trinkets and manual swaps.

local function message(text)
    DEFAULT_CHAT_FRAME:AddMessage("GearRack: "..text, 1, .82, 0)
end

local function baseID(id)
    return tonumber(string.match(tostring(id or ""), "^(%d+)"))
end
GearRack.BaseID = baseID

-- Called at login, after the client has restored both SavedVariables roots.
function GearRack.NormalizeSavedData()
    GearRackDB=type(GearRackDB)=="table" and GearRackDB or {}
    GearRackCharDB=type(GearRackCharDB)=="table" and GearRackCharDB or {}
    if type(GearRackDB.events)~="table" then GearRackDB.eventsInitialized=nil end
    for _,key in ipairs({"bars","settings","events","sets","trinketOptions"}) do
        if type(GearRackDB[key])~="table" then GearRackDB[key]={} end
    end
    for key,value in pairs(GearRackUI.DefaultSettings or {}) do
        if GearRackDB.settings[key]==nil then GearRackDB.settings[key]=value end
    end
    if type(GearRackCharDB.KeepManualTrinkets)~="boolean" then GearRackCharDB.KeepManualTrinkets=true end
    if type(GearRackCharDB.HeldQueues)~="table" then GearRackCharDB.HeldQueues={} end
    GearRackDB.schema=1
    GearRackCharDB.schema=1
end

-- Narrow public queries used by companion addons. They never perform swaps.
function GearRack.GetSetsWithItem(link) return GearRackEngine.GetSetsWithItem(link) end
function GearRack.GetQueuedSlotForItem(link) return GearRackTrinkets.GetQueuedSlotForItem(link) end
function GearRack.IsEquipmentSwapActive() return GearRackEngine.IsEquipmentSwapActive() end
-- GearRack permanently owns numbers on its equipment and trinket widgets.
function GearRack.HasCooldownNumbers(name)
    if string.match(name or "","^GearRackUIInv%d+Cooldown$") or string.match(name or "","^GearRackUIMenu%d+Cooldown$")
        or string.match(name or "","^GearRackTrinkets_Trinket[01]Cooldown$") or string.match(name or "","^GearRackTrinkets_Menu%d+Cooldown$") then
        return true
    end
end

function GearRack.StyleCooldownNumbers(font,button)
    font:SetFont("Fonts\\FRIZQT__.TTF",16,"OUTLINE")
    font:SetTextColor(1,.82,0,1)
    font:ClearAllPoints()
    font:SetPoint("CENTER",button,"CENTER")
end

function GearRack.EquipSet(name) return GearRackUI_EquipSet(name) end
function GearRack.LoadSet(name) return GearRackUI_LoadSet(name) end
function GearRack.ToggleSet(name) return GearRackUI_ToggleSet(name) end
function GearRack.IsSetEquipped(name) return GearRackUI_IsSetEquipped(name) end
function GearRack.SetTrinketQueue(which,action,...)
    return GearRackTrinkets.SetQueue(which,action,unpack(arg))
end

function GearRack.HasPending()
    return next(GearRack.Requests)~=nil
end

-- Inventory discovery is shared by both flyouts, priority lists and request lookup.
-- Only dirty carried bags are reread; bank ownership stays with the bank subsystem.
function GearRack.InvalidateBag(bag)
    if bag==nil then for i=0,4 do GearRack.DirtyBags[i]=true end
    elseif type(bag)=="number" and bag>=0 and bag<=4 then GearRack.DirtyBags[bag]=true
    else return end
    if GearRack.initialized and not GearRackEngine.TimerEnabled("GearInventory") then
        GearRackEngine.StartTimer("GearInventory")
    end
    return true
end

function GearRack.RefreshInventory()
    if GearRack.initialized then GearRackEngine.StopTimer("GearInventory") end
    if GearRack.inventoryReady and not next(GearRack.DirtyBags) then return end
    GearRack.Bags = GearRack.Bags or {}
    GearRack.BagItemIDs = GearRack.BagItemIDs or {}
    for bag in pairs(GearRack.DirtyBags) do
        local entries,itemIDs = {},{}
        for slot=1,GetContainerNumSlots(bag) do
            local texture,id,name,equipLoc,quality,rawID = GearRackEngine.GetItemInfo(bag,slot)
            local itemID=rawID or baseID(id)
            -- Occupied slots must remain discoverable even before link/static data is cached.
            if itemID then itemIDs[itemID]=true end
            if id then
                local entry = {bag=bag,slot=slot,id=id,baseID=baseID(id),name=name,
                    texture=texture,equipLoc=equipLoc,quality=quality}
                entry.guid = C_Item.GetItemGUID({bagID=bag,slotIndex=slot})
                table.insert(entries,entry)
            end
        end
        GearRack.Bags[bag]=entries
        GearRack.BagItemIDs[bag]=itemIDs
        GearRack.DirtyBags[bag]=nil
    end
    table.wipe(GearRack.Items)
    table.wipe(GearRack.ByID)
    table.wipe(GearRack.ByName)
    table.wipe(GearRack.ByGUID)
    for bag=0,4 do
        for _,entry in ipairs(GearRack.Bags[bag] or {}) do
            table.insert(GearRack.Items,entry)
            for _,key in ipairs({entry.id,entry.baseID}) do
                local list=GearRack.ByID[key] or {}
                GearRack.ByID[key]=list
                table.insert(list,entry)
            end
            if entry.name then
                local list=GearRack.ByName[entry.name] or {}
                GearRack.ByName[entry.name]=list
                table.insert(list,entry)
            end
            if entry.guid then GearRack.ByGUID[entry.guid]=entry end
        end
    end
    GearRack.inventoryReady=true
    GearRack.inventoryRevision=(GearRack.inventoryRevision or 0)+1
    if GearRack.initialized then
        if GearRackTrinkets_MenuFrame:IsVisible() then GearRackTrinkets.BuildMenu() end
        GearRack.Wake()
    end
end

-- Broad inventory notifications include instance-state changes. Compare identity
-- before invalidating carried locations; equal item IDs can be different copies.
function GearRack.RefreshEquippedItemIDs()
    GearRack.EquippedItemIDs=GearRack.EquippedItemIDs or {}
    GearRack.BagContainerIDs=GearRack.BagContainerIDs or {}
    local changed=not GearRack.EquippedGUIDs
    GearRack.EquippedGUIDs=GearRack.EquippedGUIDs or {}
    GearRack.EquippedSlotIDs=GearRack.EquippedSlotIDs or {}
    table.wipe(GearRack.EquippedItemIDs)
    table.wipe(GearRack.BagContainerIDs)
    for slot=1,23 do
        local itemID=GetInventoryItemID("player",slot)
        if GearRack.EquippedSlotIDs[slot]~=itemID then changed=true end
        GearRack.EquippedSlotIDs[slot]=itemID
        if slot>=1 and slot<=19 then
            local guid=C_Item.GetItemGUID({equipmentSlotIndex=slot})
            if GearRack.EquippedGUIDs[slot]~=guid then changed=true end
            GearRack.EquippedGUIDs[slot]=guid
            if itemID and itemID>0 then GearRack.EquippedItemIDs[itemID]=true end
        elseif slot>=20 then GearRack.BagContainerIDs[slot-19]=itemID end
    end
    return changed
end

-- Global cache notifications also cover inspected/vendor/database items.
-- Refresh only owned locations; successful cold-item fills retain their raw ID.
function GearRack.ItemDataReceived(itemID,success)
    itemID=tonumber(itemID)
    if not success or not itemID then return end
    local changed
    for bag=0,4 do
        if (GearRack.BagItemIDs and GearRack.BagItemIDs[bag] and GearRack.BagItemIDs[bag][itemID])
            or (GearRack.BagContainerIDs and GearRack.BagContainerIDs[bag]==itemID) then
            GearRack.InvalidateBag(bag)
            changed=true
        end
    end
    local bank=GearRackUI.BankIsOpen and GearRackUI.BankItemIDs and GearRackUI.BankItemIDs[itemID]
    return changed or (GearRack.EquippedItemIDs and GearRack.EquippedItemIDs[itemID]) or bank,bank
end

function GearRack.GetCarriedItems()
    if not GearRack.inventoryReady or next(GearRack.DirtyBags) then GearRack.RefreshInventory() end
    return GearRack.Items
end

local function matches(entry,id,name)
    return (id and (entry.id==id or entry.baseID==id)) or (not id and entry.name==name)
end

function GearRack.FindLocation(id,name,passive,includeInventory,guid)
    GearRack.GetCarriedItems()
    local list = guid and {GearRack.ByGUID[guid]} or (id and GearRack.ByID[id] or GearRack.ByName[name])
    for _,entry in ipairs(list or {}) do
        if (passive or not GearRackEngine.LockList[entry.bag][entry.slot]) and matches(entry,id,name) then
            local _,liveID=GearRackEngine.GetItemInfo(entry.bag,entry.slot)
            if liveID==entry.id and (not guid or C_Item.GetItemGUID({bagID=entry.bag,slotIndex=entry.slot})==guid) then
                return nil,entry.bag,entry.slot,entry
            end
            GearRack.InvalidateBag(entry.bag)
        end
    end
    if includeInventory then
        for slot=0,19 do
            if passive or not GearRackEngine.LockList[-2][slot] then
                local texture,liveID,liveName,equipLoc,quality=GearRackEngine.GetItemInfo(slot)
                local entry={id=liveID,baseID=baseID(liveID),name=liveName,texture=texture,
                    equipLoc=equipLoc,quality=quality,inv=slot}
                if slot>0 then entry.guid=C_Item.GetItemGUID({equipmentSlotIndex=slot}) end
                if matches(entry,id,name) and (not guid or entry.guid==guid) then return slot,nil,nil,entry end
            end
        end
    end
end

-- One trinket watcher, one message per transition. Retain equipment-bar
-- notification preferences for items actually used through the shared hook.
function GearRack.TrinketReady(name,soon)
    local watched=GearRackTrinkets.WatchItem[name]
    if watched and watched.rackUsed and GearRackDB.settings.Notify=="ON"
        and (soon==(GearRackDB.settings.NotifyThirty=="ON")) then
        GearRackUI_Notify(name)
        watched.rackUsed=nil
        return
    end
    if (soon and GearRackDB.trinketOptions.NotifyThirty=="ON") or (not soon and GearRackDB.trinketOptions.Notify=="ON") then
        GearRackTrinkets.Notify(name..(soon and " ready soon!" or " ready!"))
    end
end

function GearRack.GetInventoryCooldown(slot)
    local cache=GearRack.CooldownRead
    if not cache then return GetInventoryItemCooldown("player",slot) end
    local cd=cache[slot]
    if not cd then cd={};cache[slot]=cd end
    if cd.generation~=GearRack.cooldownGeneration then
        cd[1],cd[2],cd[3]=GetInventoryItemCooldown("player",slot)
        cd.generation=GearRack.cooldownGeneration
    end
    return cd[1],cd[2],cd[3]
end

local function update_cooldown_views()
    GearRackUI_CooldownUpdate_OnUpdate()
    GearRackTrinkets.CooldownUpdate()
end

function GearRack.CooldownUpdate()
    GearRack.CooldownCache=GearRack.CooldownCache or {}
    GearRack.cooldownGeneration=(GearRack.cooldownGeneration or 0)+1
    GearRack.CooldownRead=GearRack.CooldownCache
    local ok,err=pcall(update_cooldown_views)
    GearRack.CooldownRead=nil
    if not ok then error(err) end
end

function GearRack.KeepManualTrinket(slot)
    if slot~=13 and slot~=14 then return end
    if GearRackCharDB.KeepManualTrinkets then
        GearRackCharDB.HeldQueues[slot-13]=true
        GearRackTrinkets.ReflectQueueEnabled()
    end
end

function GearRack.CancelAutomaticTrinket(which)
    local slot=13+which
    if GearRack.Requests[slot] and GearRack.Requests[slot].automatic then
        GearRack.Requests[slot]=nil
        GearRack.UpdateQueuePresentation()
        GearRack.Wake()
    end
end

function GearRack.ResumeTrinketQueue(which)
    GearRackCharDB.HeldQueues[which]=nil
end

function GearRack.UpdateQueuePresentation()
    for slot=0,19 do
        local request=GearRack.Requests[slot]
        local texture=request and request.texture
        local icon=_G["GearRackUIInv"..slot.."Queue"]
        local paper=GearRackUI.Indexes[slot] and _G[GearRackUI.Indexes[slot].paperdoll_slot.."Queue"]
        for _,widget in pairs({icon,paper}) do
            if widget then
                if request then widget:SetTexture(texture);widget:Show()
                elseif not GearRackEngine.CombatQueue[slot] then widget:Hide() end
            end
        end
        if slot==13 or slot==14 then
            local which=slot-13
            local deferred=GearRackEngine.CombatQueue[slot]
            GearRackTrinkets.CombatQueue[which]=request and request.name or (deferred and GearRackEngine.GetNameByID(deferred))
            GearRackTrinkets.QueueItemIDs[which]=request and request.baseID or baseID(deferred)
        end
    end
    GearRackTrinkets.UpdateCombatQueue()
end

function GearRack.RequestItem(slot,item,automatic,toggle)
    automatic=automatic and true or nil
    if not GearRackEngine.SlotInfo[slot] or type(item)~="table" or item.id==nil then return end
    local numericID=baseID(item.id)
    local _,_,_,_,_,_,_,equipLoc=GetItemInfo(numericID or "")
    if item.id~=0 and (not numericID or not C_PlayerInfo.CanUseItem(numericID)
        or (equipLoc and not GearRackEngine.SlotInfo[slot][equipLoc])
        or (slot==17 and equipLoc=="INVTYPE_WEAPON" and not GearRackUI.CanWearOneHandOffHand)) then
        message("That item cannot be equipped in this slot.")
        return
    end
    local previous=GearRack.Requests[slot]
    if previous and previous.id==item.id and previous.guid==item.guid and previous.automatic==automatic then
        if toggle and not automatic then
            GearRack.Requests[slot]=nil
            GearRack.UpdateQueuePresentation()
            GearRack.Wake()
        end
        return
    end
    local _,worn=GearRackEngine.GetItemInfo(slot)
    local active=GearRackEngine.SwapRequest and GearRackEngine.SwapRequest.items[slot]
    for _,idx in ipairs(GearRackEngine.SwapQueueOrder) do
        local queued=GearRackEngine.SwapQueue[idx]
        if queued.direction=="NEWSET" and queued.context.items[slot] then active=true;break end
    end
    active=active or GearRackEngine.CombatQueue[slot]
    if not active and worn==item.id and (not item.guid or C_Item.GetItemGUID({equipmentSlotIndex=slot})==item.guid) then
        GearRack.Requests[slot]=nil
    else
        GearRack.sequence=(GearRack.sequence or 0)+1
        local name,texture=GearRackEngine.GetNameByID(item.id)
        GearRack.Requests[slot]={slot=slot,id=item.id,baseID=baseID(item.id),guid=item.guid,
            name=item.name or name,texture=item.texture or texture,
            automatic=automatic,sequence=GearRack.sequence,equipLoc=equipLoc}
    end
    if not automatic and slot==16 and equipLoc=="INVTYPE_2HWEAPON" then GearRack.Requests[17]=nil end
    if not automatic and slot==17 and item.id~=0 then
        local main=GearRack.Requests[16]
        if main and main.equipLoc=="INVTYPE_2HWEAPON" then GearRack.Requests[16]=nil end
    end
    if item.guid then
        for other,request in pairs(GearRack.Requests) do
            if other~=slot and request.guid==item.guid then GearRack.Requests[other]=nil end
        end
    end
    if not automatic then
        GearRackEngine.OverrideDeferredSlot(slot)
        GearRack.KeepManualTrinket(slot)
    end
    GearRack.UpdateQueuePresentation()
    GearRack.Pump()
end

function GearRack.QueueItem(item,slot)
    slot=tonumber(slot)
    if not slot or not GearRackEngine.SlotInfo[slot] then return end
    local id=type(item)=="number" and item or baseID(string.match(tostring(item),"item:(%d+)"))
    local inv,bag,bagSlot,entry=GearRack.FindLocation(id,id and nil or item,true,true)
    if entry then GearRack.RequestItem(slot,entry) else message("That item is not carried.") end
end

function GearRack.Wake()
    if GearRack.initialized and not GearRack.worldSuspended and not GearRack.pumping
        and not GearRackEngine.IsPlayerReallyDead() then
        if GearRackEngine.SwapRequest then
            GearRackEngine.StartTimer("WaitToIterate",.05,true)
        elseif GearRack.HasPending() then
            GearRackEngine.StartTimer("GearRequests",.05,true)
        end
    end
end

-- Manual clicks outrank automatic trinket proposals. Latest choice wins per slot.
-- One existing GearRackEngine transaction executes all requests; no second equip processor.
function GearRack.Pump()
    if GearRack.pumping or not GearRack.initialized or GearRack.worldSuspended then return end
    GearRack.pumping=true
    GearRackEngine.StopTimer("GearRequests")
    if GearRackEngine.BankTransfer then GearRack.pumping=nil;return end
    if GearRackEngine.SwapRequest then GearRackEngine.IterateSwapQueue() end
    if GearRackEngine.SwapRequest or #GearRackEngine.SwapQueueOrder>0 or GearRackEngine.SwapIssuing then
        GearRack.pumping=nil
        return
    end
    if GearRackEngine.IsPlayerReallyDead() then GearRack.pumping=nil;return end
    local selected
    local inCombat=UnitAffectingCombat("player")
    for slot,request in pairs(GearRack.Requests) do
        if (not inCombat or GearRackEngine.SlotInfo[slot].swappable)
            and request.waitForSpace~=GearRack.inventoryRevision then
            if not selected or (selected.automatic and not request.automatic)
                or (selected.automatic==request.automatic and request.sequence<selected.sequence) then selected=request end
        end
    end
    if selected then
        -- Known cast/GCD blocks need neither item discovery nor lock scans.
        -- Native cast-end/cooldown events wake this timer early when interrupted.
        local delay=GearRack.GetEquipDelay()
        if delay>0 then
            GearRackEngine.StartTimer("GearRequests",delay)
            GearRack.pumping=nil
            return
        end
        if GetCursorInfo() or SpellIsTargeting() or GearRackEngine.AnyLocked() then
            GearRackEngine.StartTimer("GearRequests",.2)
            GearRack.pumping=nil
            return
        end
        if selected.automatic then
            local valid,changed=GearRackTrinkets.ValidateAutomaticRequest(selected)
            if not valid then
                GearRack.pumping=nil
                if changed then GearRack.Wake() end
                return
            end
        end
        local inv,bag=GearRack.FindLocation(selected.id,selected.name,true,true,selected.guid)
        if selected.id~=0 and not inv and not bag then
            if not next(GearRack.DirtyBags) then
                GearRack.Requests[selected.slot]=nil
                message("The queued item is no longer carried.")
                GearRack.UpdateQueuePresentation()
            end
        else
            GearRackEngine.EquipSet("GearRackEngine-Choice-"..selected.slot,nil,
                {items={[selected.slot]={id=selected.id,name=selected.name,guid=selected.guid}},intent=selected,persistent=true})
        end
        if not GearRackEngine.SwapRequest and GearRack.Requests[selected.slot]==selected
            and GearRackEngine.SlotMatches(selected.slot,selected) then
            GearRack.Requests[selected.slot]=nil
            GearRack.UpdateQueuePresentation()
        end
    end
    GearRack.pumping=nil
    if GearRack.HasPending() and not GearRackEngine.SwapRequest and selected then GearRackEngine.StartTimer("GearRequests",.2) end
end

function GearRack.TransactionFinished(request,reason)
    if request and request.intent and GearRack.Requests[request.intent.slot]==request.intent then
        if reason or GearRackEngine.SwapMatches(request.items) then GearRack.Requests[request.intent.slot]=nil end
    end
    if GearRack.initialized then
        GearRack.UpdateQueuePresentation()
        GearRack.Wake()
    end
end

function GearRack.UIEvent(ev,unit,spellID,castType)
    if not GearRack.initialized then return end
    if ev=="BAG_UPDATE" then
        local carried=GearRack.InvalidateBag(unit)
        local bank=GearRackUI.BankIsOpen and type(unit)=="number" and (unit==-1 or (unit>=5 and unit<=10))
        return carried or bank,bank
    elseif ev=="GET_ITEM_INFO_RECEIVED" then return GearRack.ItemDataReceived(unit,spellID)
    elseif ev=="UNIT_INVENTORY_CHANGED" and unit=="player" then
        if GearRack.RefreshEquippedItemIDs() then GearRack.InvalidateBag() end
        GearRackTrinkets.UpdateWornTrinkets()
        if GearRackEngine.SwapRequest then GearRackEngine.OnItemLockChanged() end
        GearRack.Wake()
    elseif ev=="ACTIONBAR_UPDATE_COOLDOWN" then GearRackTrinkets.UpdateWornCooldowns(1);GearRack.Wake()
    elseif ev=="UPDATE_BINDINGS" then
        GearRackTrinkets.ReflectKeyBindings()
    elseif ev=="SPELLCAST_STOP" or ev=="SPELLCAST_INTERRUPTED" or ev=="SPELLCAST_FAILED" or ev=="SPELLCAST_CHANNEL_STOP" then
        GearRack.Wake()
    elseif ev=="PLAYER_ENTERING_WORLD" then
        GearRack.worldSuspended=nil
        GearRack.RefreshEquippedItemIDs()
        GearRack.InvalidateBag()
        GearRackUI_EnableAllEvents()
        if GearRackEngine.SwapRequest or #GearRackEngine.SwapQueueOrder>0 then GearRackEngine.IterateSwapQueue() end
        if next(GearRackEngine.CombatQueue) then GearRackEngine.OnEvent("PLAYER_REGEN_ENABLED") end
        GearRack.Wake()
    elseif ev=="PLAYER_DEAD" then
        GearRackEngine.CancelBankTransfer()
        GearRackEngine.ReconcileDeathPause()
        GearRack.CloseMenus()
        GearRackEngine.StopTimer("GearRequests");GearRackEngine.StopTimer("WaitToIterate")
    elseif ev=="PLAYER_REGEN_DISABLED" then GearRack.Wake()
    elseif ev=="PLAYER_LEAVING_WORLD" then
        GearRack.worldSuspended=true
        GearRackEngine.CancelBankTransfer()
        GearRack.CloseMenus()
        GearRackUI_DisableAllEvents()
        GearRackEngine.StopTimer("GearRequests");GearRackEngine.StopTimer("WaitToIterate")
    elseif ev=="SPELL_CAST_EVENT" and unit==1 and (castType==0 or castType==3 or castType==4) then
        GearRack.lastGCDSpell=spellID
        GearRack.Wake()
    end
end

function GearRack.GetEquipDelay()
    local delay=0
    local cast=GetCastInfo()
    if cast then delay=math.max(cast.castRemainingMs or 0,cast.gcdRemainingMs or 0)/1000 end
    if GearRack.lastGCDSpell then
        local cd=GetSpellIdCooldown(GearRack.lastGCDSpell)
        if cd then delay=math.max(delay,(cd.gcdCategoryRemainingMs or 0)/1000) end
    end
    return delay>0 and (delay+.02) or 0
end

function GearRack.Initialize()
    if GearRack.initialized then return end
    GearRack.NormalizeSavedData()
    GearRackUIFrame:RegisterEvent("SPELL_CAST_EVENT")
    GearRackTrinkets.LoadDefaults()
    GearRackTrinkets.Initialize()
    GearRackEngine.CreateTimer("GearInventory",GearRack.RefreshInventory,.05)
    GearRackEngine.CreateTimer("GearRequests",GearRack.Pump,.2)
    GearRackEngine.StopTimer("CooldownUpdate")
    GearRackEngine.CreateTimer("CooldownUpdate",GearRack.CooldownUpdate,1,1)
    GearRack.initialized=true
    GearRack.RefreshEquippedItemIDs()
    GearRack.InvalidateBag()
    GearRack.RefreshInventory()
    GearRack.CreateSettings()
    GearRackEngine.StartTimer("CooldownUpdate",.05)
    GearRackUIFrame:RegisterEvent("ACTIONBAR_UPDATE_COOLDOWN")
    GearRackUIFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    GearRackUIFrame:RegisterEvent("PLAYER_LEAVING_WORLD")
    GearRackUIFrame:RegisterEvent("PLAYER_DEAD")
    GearRackUIFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
    for _,ev in ipairs({"SPELLCAST_STOP","SPELLCAST_INTERRUPTED","SPELLCAST_FAILED","SPELLCAST_CHANNEL_STOP"}) do
        GearRackUIFrame:RegisterEvent(ev)
    end
end
