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
    layout:AddInitializer(CreateSettingsListSectionHeaderInitializer("Sets"))
    layout:AddInitializer(CreateSettingsButtonInitializer("Gear sets", "Open",
        function() GR.OpenPanel() end, "Make, save and delete sets beside your character window.", true))
    Settings.RegisterAddOnCategory(category)

    -- Automatic sets: the switch, then a set per situation, in the order they win.
    local auto, rows = Settings.RegisterVerticalLayoutSubcategory(category, "Automatic sets")
    local switch = Settings.RegisterAddOnSetting(auto, "GearRack_auto", "auto", db, Settings.VarType.Boolean,
        "Automatic sets", GR.DEFAULTS.auto)
    switch:SetValueChangedCallback(GR.AutoWatch)
    local parent = Settings.CreateCheckbox(auto, switch,
        "Put on a set while something below is true, and the gear from before when it ends. "
        .. "Higher rows win. Nothing changes while the sets panel is open.")
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

    -- Sets by target, under the same switch.
    local target = Settings.RegisterVerticalLayoutSubcategory(category, "Sets by target")
    local tip = "The set to wear when you target an enemy of this type. Needs Automatic sets on."
    for _, kind in ipairs(GR.TYPES) do
        Choice(target, db.target, kind, kind, tip):AddModifyPredicate(On)
    end
    Choice(target, db.target, "other", "Any other enemy", tip):AddModifyPredicate(On)
end)

function GR.OpenPage()
    if category then Settings.OpenToCategory(category:GetID()) end
end
