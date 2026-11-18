# GearRack [Fostercare5988]

Gear sets, sets that put themselves on, and two small bars of the gear you
wear. For World of Warcraft 1.12.1 with ClassicAPI.

## What it does

- **Gear sets.** Open your character window and press the gear button at the
  top right of your character, or click the Sets button on the gear bar. Tick
  the slots the set should save, type a name, pick an icon and press Save. A
  set remembers the exact copy of each item, so two identical daggers with
  different poisons are two different items. Equip a set from the panel, from
  the Sets button's menu, with `/gr equip <name>`, or drag it from the panel
  onto an action bar. Item tooltips name the sets an item is in.
- **In combat** your weapons change at once and the rest of the set follows
  when combat ends. A choice made while you are dead waits until you are alive.
- **The gear bar and the trinket bar.** Hover a button for the other items
  that fit that slot; click one to put it on. On a ring or trinket, right-click
  puts it in the other slot. The empty button takes the item off. Click a bar
  button to use the item, Shift-click to link it. Alt-click a slot on your
  character window to add it to the gear bar or take it off. Hold Ctrl and
  Shift and drag a bar to move it.
- **Menus on the character window.** Hover any slot for the same menu.
- **Ready alert.** When a worn item you used is ready in 30 seconds, and when
  it is ready: a sound, a line on screen and in chat.
- **Automatic sets.** One dropdown per situation: mounted, under water, each
  stance or form you have, eating or drinking, Evocation, Spirit Tap, low on
  mana, in a city or inn, in a battleground, a raid or a dungeon. The highest
  row that is true wears its set; when none is left, the gear you wore before
  comes back.
- **Sets by target.** One dropdown per enemy type (Beast, Undead, and so on,
  and Any other enemy): target an enemy and its set goes on. A rogue can keep
  one pair of daggers for undead and another for the rest.
- **Keys.** Use Trinket 1 and Use Trinket 2, under GearRack in Key Bindings
  or on the settings page.

`/gr` opens the settings: GearRack, Automatic sets and Sets by target.

## What it calls

ClassicAPI does the work: the sets are its own (`C_EquipmentSet`: create,
save, delete, the slots a set leaves out, equipping, the set button on an
action bar), items are moved without the cursor (`C_Item.EquipItemByName`)
and named by their GUIDs (`C_Item.GetItemGUID`, `IsLocked`,
`IsItemGUIDInInventory`, `GameTooltip:SetItemByGUID`), the menus list
`GetInventoryItemsForSlot` and `C_PlayerInfo.CanUseItem`, and the bars count
down with a native `Cooldown`. Situations come from their own events
(`PLAYER_MOUNT_DISPLAY_CHANGED`, `UPDATE_SHAPESHIFT_FORM`, `UNIT_AURA` with
`C_UnitAuras.GetAuraDataBySpellName`, `UNIT_POWER_UPDATE`, `GetInstanceInfo`),
and only while a row uses them. Nothing runs while nothing changes.

Taking an item off is the one job no DLL does yet: the empty button picks the
item up and drops it into a free bag.

## Installation

Needs ClassicAPI (the latest release). Put the `GearRack` folder in
`Interface\AddOns`.
