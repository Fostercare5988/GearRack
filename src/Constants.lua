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

-- Set bindings are stored per character with the set they equip.
-- To add more, raise .MaxKeyBindings and add matching _EQUIPSET entries here and in Bindings.xml.
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
GearRackUIText.CONTROL_ROTATE_TOOLTIP	= "Switch the bar between horizontal and vertical."
GearRackUIText.CONTROL_LOCK_TEXT = "Lock"
GearRackUIText.CONTROL_LOCK_TOOLTIP = "Lock the bar in place. While locked, hold Alt over the bar to show its rotate, lock and settings buttons."
GearRackUIText.CONTROL_OPTIONS_TEXT = "Settings"
GearRackUIText.CONTROL_OPTIONS_TOOLTIP = "Open Gear sets."
GearRackUIText.OPT_TOOLTIPFOLLOW_TEXT = "Tooltips at pointer"
GearRackUIText.OPT_TOOLTIPFOLLOW_TOOLTIP = "Show tooltips beside the item instead of in the default spot."
GearRackUIText.OPT_SOULBOUND_TEXT = "Hide tradables"
GearRackUIText.OPT_SOULBOUND_TOOLTIP = "Item lists skip items you could still trade, so fresh dungeon loot stays out of them. Quest and conjured items still show."
GearRackUIText.OPT_BINDINGS_TEXT = "Show key bindings"
GearRackUIText.OPT_BINDINGS_TOOLTIP = "Show each bar button's key binding on it."
GearRackUIText.OPT_MENUSHIFT_TEXT = "Menu on Shift only"
GearRackUIText.OPT_MENUSHIFT_TOOLTIP = "Item lists only open while you hold Shift."
GearRackUIText.OPT_CLOSE_TEXT = "Close Options"
GearRackUIText.OPT_CLOSE_TOOLTIP = "Close equipment options. /gr bar shows or hides the bar."
GearRackUIText.INVFRAME_RESIZE_TEXT = "Resize"
GearRackUIText.INVFRAME_RESIZE_TOOLTIP = "Drag to resize the bar."
GearRackUIText.OPT_SHOWEMPTY_TEXT = "Allow empty slots"
GearRackUIText.OPT_SHOWEMPTY_TOOLTIP = "Item lists also offer an empty slot, to take the item off (needs a free bag slot). Not in trinket lists while Trinket click mapping is on."
GearRackUIText.OPT_FLIPMENU_TEXT = "Flip menu"
GearRackUIText.OPT_FLIPMENU_TOOLTIP = "Item lists open on the other side of the bar."
GearRackUIText.OPT_RIGHTCLICK_TEXT = "Trinket click mapping"
GearRackUIText.OPT_RIGHTCLICK_TOOLTIP = "In a trinket list, left-click puts the trinket in the top slot and right-click in the bottom slot. Two trinket buttons side by side share one list."
GearRackUIText.OPT_SHOWTOOLTIPS_TEXT = "Show tooltips"
GearRackUIText.OPT_SHOWTOOLTIPS_TOOLTIP = "Show tooltips."
GearRackUIText.OPT_NOTIFY_TEXT = "Notify when ready"
GearRackUIText.OPT_NOTIFY_TOOLTIP = "Tell you when an item you used is ready again."
GearRackUIText.OPT_ROTATEMENU_TEXT = "Rotate menu"
GearRackUIText.OPT_ROTATEMENU_TOOLTIP = "Item lists run along the bar instead of sticking out from it."
GearRackUIText.OPT_SHOWICON_TEXT = "Minimap buttons"
GearRackUIText.OPT_SHOWICON_TOOLTIP = "Show separate minimap buttons for Gear sets and Trinkets."
GearRackUIText.OPT_DISABLETOGGLE_TEXT = "Shift-click opens gear sets"
GearRackUIText.OPT_DISABLETOGGLE_TOOLTIP = "Shift-click the purple minimap button for a list of your sets. Off: Shift-click shows or hides the equipment bar."
GearRackUIText.OPT_FLIPBAR_TEXT = "Flip bar growth"
GearRackUIText.OPT_FLIPBAR_TOOLTIP = "New bar buttons are added to the left or upward instead of right or downward."
GearRackUIText.OPT_ENABLEEVENTS_TEXT = "Enable Events"
GearRackUIText.OPT_ENABLEEVENTS_TOOLTIP = "Let the events enabled below change gear. Off stops all events."
GearRackUIText.OPT_SHOWALLEVENTS_TEXT = "Show All"
GearRackUIText.OPT_SHOWALLEVENTS_TOOLTIP = "List every class's events, not only yours."
GearRackUIText.OPT_COMPACTLIST_TEXT = "Compact"
GearRackUIText.OPT_COMPACTLIST_TOOLTIP = "Smaller rows, so more sets fit."
GearRackUIText.OPT_SAVEDSETSCLOSE_TEXT = "Cancel"
GearRackUIText.OPT_SAVEDSETSCLOSE_TOOLTIP = "Cancel choosing a set."
GearRackUIText.OPT_NOTIFYTHIRTY_TEXT = "Notify at 30 secs"
GearRackUIText.OPT_NOTIFYTHIRTY_TOOLTIP = "Notify 30 seconds before the cooldown ends instead of when it ends."
GearRackUIText.OPT_ALLOWHIDDEN_TEXT = "Allow hidden items"
GearRackUIText.OPT_ALLOWHIDDEN_TOOLTIP = "Alt-click an item in a list to hide it there. To get it back, hold Alt while opening the list and Alt-click it again."
GearRackUIText.OPT_LARGEFONT_TEXT = "Large Font"
GearRackUIText.OPT_LARGEFONT_TOOLTIP = "Bigger text in the script editor."
GearRackUIText.OPT_SQUAREMINIMAP_TEXT = "Square minimap"
GearRackUIText.OPT_SQUAREMINIMAP_TOOLTIP = "For a square minimap: the buttons move along its edge."
GearRackUIText.OPT_SETLABELS_TEXT = "Show set icon labels"
GearRackUIText.OPT_SETLABELS_TOOLTIP = "Write the set's name on set icons."
GearRackUIText.OPT_AUTOTOGGLE_TEXT = "Click again to restore gear"
GearRackUIText.OPT_AUTOTOGGLE_TOOLTIP = "Pick a set you are already wearing from the Sets button to put your previous gear back on. Out of combat only. Shift-click does this even with the option off."
GearRackUIText.OPT_CHARSHEETMENU_TEXT = "Character sheet flyouts"
GearRackUIText.OPT_CHARSHEETMENU_TOOLTIP = "Hover an item on your character window to see your other items for that slot and swap."

GearRackUIText.SETS_CLOSE_TEXT = "Close Set Builder"
GearRackUIText.SETS_CLOSE_TOOLTIP = "Close Gear sets. Use /gr bar to show or hide the equipment bar."
GearRackUIText.SETS_NAMELABEL_TEXT = "Choose a name and icon:"
GearRackUIText.SETS_HIDESET_TEXT = "Hide"
GearRackUIText.SETS_HIDESET_TOOLTIP = "Leave this set out of the Sets button's list.\n\nTo see hidden sets, hold Alt while opening the list; Alt-click a set to hide or unhide it."
GearRackUIText.SETS_BINDBUTTON_TEXT = "Bind Key"
GearRackUIText.SETS_BINDBUTTON_TOOLTIP = "Bind a key to this set."
GearRackUIText.SETS_SAVEBUTTON_TEXT = "Save"
GearRackUIText.SETS_SAVEBUTTON_TOOLTIP = "Save the set under this name. Edits to a saved set count only after saving (key bindings apply at once)."
GearRackUIText.SETS_REMOVEBUTTON_TEXT = "Remove"
GearRackUIText.SETS_REMOVEBUTTON_TOOLTIP = "Delete this set. To keep it out of the menu instead, tick Hide and save."
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
GearRackUIText.UNDEFINEDEVENT_TOOLTIP = "Click to choose the set this event equips. An event needs a set before it can run."
GearRackUIText.ENABLEEVENT_TEXT = "Enable Event"
GearRackUIText.ENABLEEVENT_TOOLTIP = "Turn this event on or off. Enable Events above turns all of them on or off."

GearRackUIText.EVENTSDELETE_TEXT = "Delete Event"
GearRackUIText.EVENTSDELETE_TOOLTIP = "Delete this event. If other characters on this account use it, it only loses this character's set."
GearRackUIText.EVENTSEDIT_TEXT = "Edit Event"
GearRackUIText.EVENTSEDIT_TOOLTIP = "Edit this event's script. Choose its set with the icon in the list."
GearRackUIText.EVENTSNEW_TEXT = "New Event"
GearRackUIText.EVENTSNEW_TOOLTIP = "Create a new event. Scripts are Lua, like macros."

GearRackUIText.EVENTSSAVE_TEXT = "Save Event"
GearRackUIText.EVENTSSAVE_TOOLTIP = "Save this event. Unfinished events can be saved; give them a set when they are ready.\n\nSaving under a new name makes a copy."
GearRackUIText.EVENTSTEST_TEXT = "Test Script"
GearRackUIText.EVENTSTEST_TOOLTIP = "Run the script once now to catch errors. It does not check the trigger or the result."
GearRackUIText.EVENTSCANCEL_TEXT = "Return to Events"
GearRackUIText.EVENTSCANCEL_TOOLTIP = "Drop unsaved changes and go back to the events list."
GearRackUIText.EVENTNAME_TEXT = "Event Name"
GearRackUIText.EVENTNAME_TOOLTIP = "The name in the events list, such as \"Riding\".\n\nStart it with a class, such as \"Priest:Shadowform\", so Show All can filter it."
GearRackUIText.EVENTTRIGGER_TEXT = "Event Trigger"
GearRackUIText.EVENTTRIGGER_TOOLTIP = "The game event that runs the script. Common ones:\nPLAYER_AURAS_CHANGED: buffs or forms change\nPLAYER_REGEN_DISABLED: you enter combat\nPLAYER_REGEN_ENABLED: you leave combat"
GearRackUIText.EVENTDELAY_TEXT = "Event Delay"
GearRackUIText.EVENTDELAY_TOOLTIP = "Seconds to wait after the last trigger. 0 runs at once. A delay runs the script once after a burst of triggers, such as BAG_UPDATE."

GearRackUIText.RESETBUTTON_TEXT = "Reset Bar"
GearRackUIText.RESETBUTTON_TOOLTIP = "Put the bar back at its default place and size, for when it is off screen or too small. Sets, events and bar buttons stay."
GearRackUIText.RESETEVENTSBUTTON_TEXT = "Reset Events"
GearRackUIText.RESETEVENTSBUTTON_TOOLTIP = "Restore the included events (Mount, Plaguelands and others). Removes your own events."

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
