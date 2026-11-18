-- GearRack's pages in ClassicAPI's Settings window (AddOn Options, or /gr):
-- GearRack, Automatic sets and Sets by target.
local _, GR = ...
local db = GearRackDB
local String = Settings.VarType.String

local category

-- "Off" and every set by name; a saved set that is gone stays listed as gone.
local function SetChoices(tbl, key)
    return function()
        local choices = Settings.CreateControlTextContainer()
        choices:Add("", "Off")
        local ids, names = GR.Sets()
        local known = tbl[key] == ""
        for _, id in ipairs(ids) do
            choices:Add(names[id], names[id])
            if names[id] == tbl[key] then known = true end
        end
        if not known then choices:Add(tbl[key], tbl[key] .. " (deleted)") end
        return choices:GetData()
    end
end

local function BarChoices()
    local choices = Settings.CreateControlTextContainer()
    choices:Add("ACROSS", "Across")
    choices:Add("DOWN", "Down")
    choices:Add("OFF", "Off")
    return choices:GetData()
end

SettingsRegistrar:AddRegistrant(function()
    local layout
    category, layout = Settings.RegisterVerticalLayoutCategory("GearRack")
    layout:AddInitializer(CreateSettingsListSectionHeaderInitializer("Bars"))
    for _, bar in ipairs({
        { "gearBar", "Gear bar", "The gear you chose, then your sets. Alt-click a slot on your character window to add or remove it." },
        { "trinketBar", "Trinket bar", "Your two trinkets." },
    }) do
        local setting = Settings.RegisterAddOnSetting(category, "GearRack_" .. bar[1], bar[1], db, String, bar[2],
            GR.DEFAULTS[bar[1]])
        setting:SetValueChangedCallback(GR.Layout)
        Settings.CreateDropdown(category, setting, BarChoices,
            bar[3] .. " Hover a button for the other items; hold Ctrl and Shift to move the bar.")
    end
    for _, action in ipairs({ "GEARRACK_USE_TOP_TRINKET_ITEM", "GEARRACK_USE_BOTTOM_TRINKET_ITEM" }) do
        local row = CreateKeybindingEntryInitializer(C_KeyBindings.GetBindingIndex(action), true)
        row:AddSearchTags(GetBindingName(action))
        layout:AddInitializer(row)
    end
    layout:AddInitializer(CreateSettingsListSectionHeaderInitializer("Alerts"))
    Settings.CreateCheckbox(category, Settings.RegisterAddOnSetting(category, "GearRack_readyAlert", "readyAlert", db,
        Settings.VarType.Boolean, "Ready alert", GR.DEFAULTS.readyAlert),
        "When a worn item you used is ready in 30 seconds, and when it is ready: a sound, on screen and in chat.")
    layout:AddInitializer(CreateSettingsListSectionHeaderInitializer("Windows"))
    layout:AddInitializer(CreateSettingsButtonInitializer("Gear sets", "Open",
        function() GR.ToggleWindow() end, "Make, save, equip and delete your sets.", true))
    layout:AddInitializer(CreateSettingsButtonInitializer("Trinkets", "Open",
        function() GR.OpenTrinkets(13) end, "The order your trinkets are worn in, and the automatic swap.", true))
    local minimap = Settings.RegisterAddOnSetting(category, "GearRack_minimap", "minimap", db, Settings.VarType.Boolean,
        "Minimap buttons", GR.DEFAULTS.minimap)
    minimap:SetValueChangedCallback(GR.MinimapButtons)
    Settings.CreateCheckbox(category, minimap,
        "The gear opens Gear sets, the trinket opens Trinkets; right-click either for this page. Drag to move.")
    Settings.RegisterAddOnCategory(category)

    -- Automatic sets: the switch, then a set per situation, in the order they win.
    local auto, rows = Settings.RegisterVerticalLayoutSubcategory(category, "Automatic sets")
    local switch = Settings.RegisterAddOnSetting(auto, "GearRack_auto", "auto", db, Settings.VarType.Boolean,
        "Automatic sets", GR.DEFAULTS.auto)
    switch:SetValueChangedCallback(GR.AutoWatch)
    local parent = Settings.CreateCheckbox(auto, switch,
        "Put on a set while something below is true, and the gear from before when it ends. "
        .. "Higher rows win. Nothing changes while the Gear sets window is open.")
    local function On() return db.auto end
    local function Choice(cat, tbl, key, label, tooltip)
        local setting = Settings.RegisterAddOnSetting(cat, "GearRack_" .. (tbl == db.when and "when_" or "target_") .. key,
            key, tbl, String, label, "")
        setting:SetValueChangedCallback(GR.AutoWatch)
        return Settings.CreateDropdown(cat, setting, SetChoices(tbl, key), tooltip)
    end
    local header
    for _, row in ipairs(GR.Rows()) do
        local now = row.where and "Where" or "While"
        if now ~= header then
            header = now
            rows:AddInitializer(CreateSettingsListSectionHeaderInitializer(now))
        end
        Choice(auto, db.when, row.key, row.label):SetParentInitializer(parent, On)
    end

    -- Sets by target: its own switch, then a set per enemy type.
    local target = Settings.RegisterVerticalLayoutSubcategory(category, "Sets by target")
    local byTarget = Settings.RegisterAddOnSetting(target, "GearRack_byTarget", "byTarget", db, Settings.VarType.Boolean,
        "Sets by target", GR.DEFAULTS.byTarget)
    byTarget:SetValueChangedCallback(GR.AutoWatch)
    local targetParent = Settings.CreateCheckbox(target, byTarget,
        "Put on a set when you target an enemy, chosen by its type below. A type left Off wears the "
        .. "Any other enemy set. Nothing changes back afterwards.")
    local function TargetOn() return db.byTarget end
    local tip = "The set to wear when you target an enemy of this type."
    for _, kind in ipairs(GR.TYPES) do
        Choice(target, db.target, kind, kind, tip):SetParentInitializer(targetParent, TargetOn)
    end
    Choice(target, db.target, "other", "Any other enemy", tip):SetParentInitializer(targetParent, TargetOn)
end)

function GR.OpenPage()
    if category then Settings.OpenToCategory(category:GetID()) end
end
