if not GearRack.enabled then return end

--[[ Constants.lua - UI copy, text definitions, and static assets for GearRackUI ]]

GearRackUI = GearRackUI or {}
GearRackUIText = GearRackUIText or {}

-- Native bag type and optional Goblin Brainwashing Device integration.
GearRackUIText.INVTYPE_CONTAINER = "Bag"

--Goblin Brainwashing Device (GBD) integration
GearRackUIText.GBD = "Goblin Brainwashing Device"

--ignore "Save..." lines
GearRackUIText.GBDSave = "Save"

--spec number pattern "Activate ..." line
GearRackUIText.GBDSpec = "Activate (%d).. Specialization"

--[[ Key bindings ]]--

-- Bindings are created dynamically in the mod and are stored per-character with the binding attached to the set.
-- To add more bindings, change .MaxKeyBindings to the desired amount and add more _EQUIPSET here and in Bindings.xml
-- The key bindings is arguably the most complex part of the mod -- localize with care or hold off localizing until last
GearRackUIText.BINDINGFORMAT = "Equip Set: %s"
GearRackUIText.BINDINGSEARCH = "Equip Set: (.+)"
GearRackUIText.MaxKeyBindings = 10
BINDING_HEADER_GEARRACK = "GearRack"
BINDING_NAME_GEARRACK_EQUIPSET1 = "Equip Set: 1" -- these values change to string.format of BINDINGFORMAT on the binding owner's set
BINDING_NAME_GEARRACK_EQUIPSET2 = "Equip Set: 2"
BINDING_NAME_GEARRACK_EQUIPSET3 = "Equip Set: 3"
BINDING_NAME_GEARRACK_EQUIPSET4 = "Equip Set: 4"
BINDING_NAME_GEARRACK_EQUIPSET5 = "Equip Set: 5"
BINDING_NAME_GEARRACK_EQUIPSET6 = "Equip Set: 6"
BINDING_NAME_GEARRACK_EQUIPSET7 = "Equip Set: 7"
BINDING_NAME_GEARRACK_EQUIPSET8 = "Equip Set: 8"
BINDING_NAME_GEARRACK_EQUIPSET9 = "Equip Set: 9"
BINDING_NAME_GEARRACK_EQUIPSET10 = "Equip Set: 10"

-- options text. none of the text below will affect how the mod runs.  It's just displayed text.

GearRackUIText.CONTROL_ROTATE_TEXT = "Rotate"
GearRackUIText.CONTROL_ROTATE_TOOLTIP	= "Change the bar between vertical and horizontal."
GearRackUIText.CONTROL_LOCK_TEXT = "Lock"
GearRackUIText.CONTROL_LOCK_TOOLTIP = "Lock or unlock the window.  While locked, hold ALT and move the mouse over the bar to access controls."
GearRackUIText.CONTROL_OPTIONS_TEXT = "Settings"
GearRackUIText.CONTROL_OPTIONS_TOOLTIP = "Open Gear Sets for equipment and trinkets."
GearRackUIText.OPT_TOOLTIPFOLLOW_TEXT = "Tooltips at pointer"
GearRackUIText.OPT_TOOLTIPFOLLOW_TOOLTIP = "Check this to make tooltips follow the pointer instead of displaying at the default location."
GearRackUIText.OPT_SOULBOUND_TEXT = "Hide tradables"
GearRackUIText.OPT_SOULBOUND_TOOLTIP = "Check this to only display soulbound, quest or conjured items in the menus.  Bind-On-Equip and tradable items will be ignored to prevent showing up as you loot through an instance."
GearRackUIText.OPT_BINDINGS_TEXT = "Show key bindings"
GearRackUIText.OPT_BINDINGS_TOOLTIP = "Check this to display any key bindings on the bar."
GearRackUIText.OPT_MENUSHIFT_TEXT = "Menu on Shift only"
GearRackUIText.OPT_MENUSHIFT_TOOLTIP = "Check this to prevent the menu from appearing unless you're holding the Shift key."
GearRackUIText.OPT_CLOSE_TEXT = "Close Options"
GearRackUIText.OPT_CLOSE_TOOLTIP = "Close equipment options. Use /gr bar to show or hide the equipment bar."
GearRackUIText.INVFRAME_RESIZE_TEXT = "Resize"
GearRackUIText.INVFRAME_RESIZE_TOOLTIP = "Drag the 'grip' in the lower right corner to resize the window."
GearRackUIText.OPT_SHOWEMPTY_TEXT = "Allow empty slots"
GearRackUIText.OPT_SHOWEMPTY_TOOLTIP = "Add an empty-slot choice to equipment flyouts. Removing an item requires free bag space. Trinket click mapping hides this choice in trinket flyouts."
GearRackUIText.OPT_FLIPMENU_TEXT = "Flip menu"
GearRackUIText.OPT_FLIPMENU_TOOLTIP = "The menu grows towards the middle of the screen by default.  Check this to make the menu grow from the opposite side that it automatically chooses."
GearRackUIText.OPT_RIGHTCLICK_TEXT = "Trinket click mapping"
GearRackUIText.OPT_RIGHTCLICK_TOOLTIP = "Check this to make left-clicking a trinket go to the top trinket slot (as displayed on your character screen), and right-click to go to the bottom trinket slot.  Trinket pairs on the bar together will share one menu as well."
GearRackUIText.OPT_SHOWTOOLTIPS_TEXT = "Show tooltips"
GearRackUIText.OPT_SHOWTOOLTIPS_TOOLTIP = "Check this to show tooltips."
GearRackUIText.OPT_NOTIFY_TEXT = "Notify when ready"
GearRackUIText.OPT_NOTIFY_TOOLTIP = "Check this to display a message when a used item has finished cooldown."
GearRackUIText.OPT_ROTATEMENU_TEXT = "Rotate menu"
GearRackUIText.OPT_ROTATEMENU_TOOLTIP = "The menu grows perpendicular to the bar by default.  Check this to make it grow parallel to the bar."
GearRackUIText.OPT_SHOWICON_TEXT = "Minimap buttons"
GearRackUIText.OPT_SHOWICON_TOOLTIP = "Show separate minimap buttons for Gear sets and Trinkets."
GearRackUIText.OPT_DISABLETOGGLE_TEXT = "Shift-click opens gear sets"
GearRackUIText.OPT_DISABLETOGGLE_TOOLTIP = "Shift-click the minimap button to choose a gear set. Uncheck to toggle the equipment bar with Shift-click. A normal click always opens settings."
GearRackUIText.OPT_FLIPBAR_TEXT = "Flip bar growth"
GearRackUIText.OPT_FLIPBAR_TOOLTIP = "The bar grows down or to the right by default.  Check this to make it grow leftwards or upwards."
GearRackUIText.OPT_ENABLEEVENTS_TEXT = "Enable Events"
GearRackUIText.OPT_ENABLEEVENTS_TOOLTIP = "Check this to allow automated events enabled below to swap gear based on conditions defined within the events.\n\nUncheck to stop all event processing."
GearRackUIText.OPT_SHOWALLEVENTS_TEXT = "Show All"
GearRackUIText.OPT_SHOWALLEVENTS_TOOLTIP = "Check this to show all events for all classes.\n\nUncheck to prevent sets for other classes from listing."
GearRackUIText.OPT_COMPACTLIST_TEXT = "Compact"
GearRackUIText.OPT_COMPACTLIST_TOOLTIP = "Check this to list sets in a more compact form to see more at once."
GearRackUIText.OPT_SAVEDSETSCLOSE_TEXT = "Cancel"
GearRackUIText.OPT_SAVEDSETSCLOSE_TOOLTIP = "Cancel choosing a set."
GearRackUIText.OPT_NOTIFYTHIRTY_TEXT = "Notify at 30 secs"
GearRackUIText.OPT_NOTIFYTHIRTY_TOOLTIP = "Check this to notify at the 30-second mark instead of when an item's cooldown ends."
GearRackUIText.OPT_ALLOWHIDDEN_TEXT = "Allow hidden items"
GearRackUIText.OPT_ALLOWHIDDEN_TOOLTIP = "Check this to allow menu items to be hidden with ALT+click.  To recover a hidden item on the menu, hold ALT as you enter the bar and ALT+click the item again."
GearRackUIText.OPT_LARGEFONT_TEXT = "Large Font"
GearRackUIText.OPT_LARGEFONT_TOOLTIP = "Check this to use a bigger font in the script edit window below."
GearRackUIText.OPT_SQUAREMINIMAP_TEXT = "Square minimap"
GearRackUIText.OPT_SQUAREMINIMAP_TOOLTIP = "Check this to have the minimap button drag around the full square of the minimap."
GearRackUIText.OPT_SETLABELS_TEXT = "Show set icon labels"
GearRackUIText.OPT_SETLABELS_TOOLTIP = "Check this to show set labels on set icons."
GearRackUIText.OPT_AUTOTOGGLE_TEXT = "Click again to restore gear"
GearRackUIText.OPT_AUTOTOGGLE_TOOLTIP = "Selecting an equipped set from the flyout restores the gear it replaced. Other sets equip normally. Works while alive and out of combat. Shift-click does the same without enabling this option."
GearRackUIText.OPT_CHARSHEETMENU_TEXT = "Character sheet flyouts"
GearRackUIText.OPT_CHARSHEETMENU_TOOLTIP = "Check this to display an equipment swap flyout menu when hovering over worn items on your character sheet."

GearRackUIText.SETS_CLOSE_TEXT = "Close Set Builder"
GearRackUIText.SETS_CLOSE_TOOLTIP = "Close Gear sets. Use /gr bar to show or hide the equipment bar."
GearRackUIText.SETS_NAMELABEL_TEXT = "Choose a name and icon:"
GearRackUIText.SETS_HIDESET_TEXT = "Hide"
GearRackUIText.SETS_HIDESET_TOOLTIP = "When checked, this set will not appear in the popup menu on the rack.  Note: The set icon on the rack will always reflect the last set equipped, hidden or not.\n\nHold ALT while you mouseover sets on the bar to see hidden sets.  You can ALT+click sets in the menu to toggle their hidden status."
GearRackUIText.SETS_BINDBUTTON_TEXT = "Bind Key"
GearRackUIText.SETS_BINDBUTTON_TOOLTIP = "Bind a key to this set."
GearRackUIText.SETS_SAVEBUTTON_TEXT = "Save"
GearRackUIText.SETS_SAVEBUTTON_TOOLTIP = "Save this set as the name given above.  Except for key bindings, changes made to an existing set are not permanent until you save."
GearRackUIText.SETS_REMOVEBUTTON_TEXT = "Remove"
GearRackUIText.SETS_REMOVEBUTTON_TOOLTIP = "Remove this set definition.  To keep a set but prevent it from showing on the menu, check Hide below the set's icon and then save."
GearRackUIText.SETS_LOADBUTTON_TEXT = "Equip"
GearRackUIText.SETS_LOADBUTTON_TOOLTIP = "Equip the selected set."

GearRackUIText.READY = "%s ready!"
GearRackUIText.READYTHIRTY = "%s ready soon!"
GearRackUIText.QUEUED = "Queued: %s"
GearRackUIText.SAVED = "Set %s saved with %d items."
GearRackUIText.BINDCLEAR = "Binding cleared for this set."
GearRackUIText.BINDSET = "Set bound to key %s"

GearRackUIText.ERROR_MISSING = "GearRack: Some items were not found: "
GearRackUIText.ERROR_NOROOM = "GearRack: Not enough free bag space to complete swap."

GearRackUIText.COUNTFORMAT = "%d/20"
GearRackUIText.NOSAVEDSETS = "No saved sets."
GearRackUIText.SETTOOLTIPFORMAT = "Set: %s"
GearRackUIText.SETREMOVE = "Set %s removed."
GearRackUIText.EMPTYSET = ""
GearRackUIText.EVENTSSUSPENDED = "Note: Event processing is suspended\nwhile this window is up."

GearRackUIText.UNDEFINEDEVENT_TEXT = "Not Defined Yet"
GearRackUIText.UNDEFINEDEVENT_TOOLTIP = "Click here to associate a set with this event.  You can edit the event to use multiple sets per event, but all events must have one set associated with it before it can be used."
GearRackUIText.ENABLEEVENT_TEXT = "Enable Event"
GearRackUIText.ENABLEEVENT_TOOLTIP = "Check this to enable this particular event.  Uncheck to disable the event.  Use the 'Enable' checkbox at the top as a master on/off for events."

GearRackUIText.EVENTSDELETE_TEXT = "Delete Event"
GearRackUIText.EVENTSDELETE_TOOLTIP = "Delete this event.  If any other characters on this account use this event, it will revert to an undefined state for this character."
GearRackUIText.EVENTSEDIT_TEXT = "Edit Event"
GearRackUIText.EVENTSEDIT_TOOLTIP = "Edit this event.\n\nSome knowledge of lua or WoW macros helps immensely in dealing with events.\n\nYou cannot associate a set with this event by editing it.  Click the set icon in the list above to associate a set."
GearRackUIText.EVENTSNEW_TEXT = "New Event"
GearRackUIText.EVENTSNEW_TOOLTIP = "Create a new event.\n\nSome knowledge of lua or WoW macros helps immensely in dealing with events."

GearRackUIText.EVENTSSAVE_TEXT = "Save Event"
GearRackUIText.EVENTSSAVE_TOOLTIP = "Save this event.  You can save unfinished events, just be sure not to associate them with any set until it's ready.\n\nIf the name of an existing event is changed, a COPY is made under the new name."
GearRackUIText.EVENTSTEST_TEXT = "Test Script"
GearRackUIText.EVENTSTEST_TOOLTIP = "Test the above script by running it once now.  This is mostly to catch syntax or other errors that would produce a red error window.  It can't test the trigger or ensure the script will have desired results."
GearRackUIText.EVENTSCANCEL_TEXT = "Return to Events"
GearRackUIText.EVENTSCANCEL_TOOLTIP = "This will cancel any unsaved changes and return to the events list."
GearRackUIText.EVENTNAME_TEXT = "Event Name"
GearRackUIText.EVENTNAME_TOOLTIP = "This is the name of the event as listed in the previous window.  ie, \"Riding\", \"Warrior:Berserker\", etc\n\nPrefix a name with Class: to let the 'Show All' option filter events by classes, ie, \"Priest:Shadowform\""
GearRackUIText.EVENTTRIGGER_TEXT = "Event Trigger"
GearRackUIText.EVENTTRIGGER_TOOLTIP = "This is the trigger fired from WoW when you want the event to occur.\n\nSome common ones:\nPLAYER_AURAS_CHANGED : When your buffs or forms change.\nPLAYER_REGEN_DISABLED : When you enter combat mode.\nPLAYER_REGEN_ENABLED : When you leave combat mode.\n\nwww.wowwiki.com/Events lists them all."
GearRackUIText.EVENTDELAY_TEXT = "Event Delay"
GearRackUIText.EVENTDELAY_TOOLTIP = "This is the time (in seconds) after the latest trigger before performing this event.  A zero here will immediately perform the event each trigger.  Some triggers can happen many times in a flurry, such as BAG_UPDATE.  A delay here will ensure the event runs a single time once the flurry of triggers are over."

GearRackUIText.RESETBUTTON_TEXT = "Reset Bar"
GearRackUIText.RESETBUTTON_TOOLTIP = "Click this to restore the windows and scales to a default state in the event you lose them off the screen or shrink them too small to resize.  Events, sets and items on the bar are not affected."
GearRackUIText.RESETEVENTSBUTTON_TEXT = "Reset Events"
GearRackUIText.RESETEVENTSBUTTON_TOOLTIP = "Click this to restore events (Mount, Plaguelands, etc) to their default state.  Custom events will be removed.  NOTE: THIS WILL REMOVE CUSTOM EVENTS"

GearRackUIText.DisableToggleText = {
	["ON"] = "Left-click: gear sets\nRight-click: equipment options\nShift-left-click: saved-set menu\nDrag: move icon",
	["OFF"] = "Left-click: gear sets\nRight-click: equipment options\nShift-left-click: equipment bar\nDrag: move icon"
}

GearRackUIText.HELP = "GEAR SETS\nSave selected equipment slots in Sets. Bind a key there, or use /gr equip <set>. Automation is optional in Events.\n\nWEAPONS\nMain-hand, off-hand and ranged buttons are enabled by default. Hover and click a carried weapon. A blocked choice stays queued; the newest choice wins for that slot.\n\nTRINKETS\nAssign equipped trinket keys in the game's Key Bindings menu. Open /gr queues for priority lists, profiles and delays. Manual choices pause that slot by default. Enable its queue or Alt-click its trinket button to resume.\n\nBAR CONTROLS\nOpen Bar layout inside Gear sets to order the buttons. Alt-click a character-sheet slot to add or remove it. Alt-click the character model to add Sets. Alt-drag to move the bar. /gr opens Gear sets.\n\nPOISONS\n/run GearRack.SwapPoison() chooses a differently poisoned copy for your off hand; pass 16 for main hand.\n\nRESET\nReset Bar restores equipment position and scale while keeping sets. /gr trinkets reset clears trinket settings and priorities."



--[[ Extra Icons

	Here you can add more icons available for use in the set builder.
	There are two ways to add an icon:

	1. Draw your own 64x64 uncompressed 32-bit TGA file and put it into Interface\Icons

	2. Use a "built-in" icon by adding its exact path/name to the list below.

	The icons below will list immediately after the icons for the worn gear in the order
	they are listed here.  If you draw your own icon and put it into Interface\Icons,
	you do not need to list it here.  They will be picked up automatically.

]]

GearRackUIExtraIcons = {
	"Interface\\Icons\\INV_Banner_02",
	"Interface\\Icons\\INV_Banner_03",
	-- add new icons here in this format: "Interface\\Icons\\(ExactIconName)",
}

BINDING_NAME_GEARRACK_TOGGLE_BAR = "Toggle equipment bar"

BINDING_NAME_GEARRACK_TOGGLE_EVENTS = "Toggle Events"

BINDING_NAME_GEARRACK_USE_HEAD_ITEM = "Use Head Item"

BINDING_NAME_GEARRACK_USE_NECK_ITEM = "Use Neck Item"

BINDING_NAME_GEARRACK_USE_SHOULDER_ITEM = "Use Shoulder Item"

BINDING_NAME_GEARRACK_USE_CHEST_ITEM = "Use Chest Item"

BINDING_NAME_GEARRACK_USE_WAIST_ITEM = "Use Waist Item"

BINDING_NAME_GEARRACK_USE_LEGS_ITEM = "Use Legs Item"

BINDING_NAME_GEARRACK_USE_FEET_ITEM = "Use Feet Item"

BINDING_NAME_GEARRACK_USE_WRIST_ITEM = "Use Wrist Item"

BINDING_NAME_GEARRACK_USE_HANDS_ITEM = "Use Hands Item"

BINDING_NAME_GEARRACK_USE_TOP_FINGER_ITEM = "Use Top Finger Item"

BINDING_NAME_GEARRACK_USE_BOTTOM_FINGER_ITEM = "Use Bottom Finger Item"

BINDING_NAME_GEARRACK_USE_TOP_TRINKET_ITEM = "Use Trinket 1 (Upper slot)"

BINDING_NAME_GEARRACK_USE_BOTTOM_TRINKET_ITEM = "Use Trinket 2 (Lower slot)"

BINDING_NAME_GEARRACK_USE_BACK_ITEM = "Use Back Item"

BINDING_NAME_GEARRACK_USE_MAIN_HAND_ITEM = "Use Main-Hand Item"

BINDING_NAME_GEARRACK_USE_OFF_HAND_ITEM = "Use Off-Hand Item"

BINDING_NAME_GEARRACK_USE_RANGE_ITEM = "Use ranged item"

BINDING_NAME_GEARRACK_TOGGLETRINKETS = "Toggle Trinkets"

BINDING_NAME_GEARRACK_TOGGLE_SETTINGS = "Open Gear Sets"
