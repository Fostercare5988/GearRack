# GearRack [Fostercare5988]

Gear sets, a trinket queue, sets that put themselves on, and two small bars of
the gear you wear. For World of Warcraft 1.12.1 with ClassicAPI.

## What it does

- **Gear sets window.** Open it with the purple gear on the minimap, the Sets
  button on the gear bar, or `/gr sets`. It shows your 20 slots (with the shirt and the ammo) around your
  sets. A lit slot is saved in the set; click a slot to leave it out or take
  it in, hover it to put another item in it. Type a name, pick an icon and
  press Save; Click a set in the list to put it on (its slots then show
  its items); Equip and Delete work on the set whose name is in the box. New
  starts a set with every slot lit. "Hide from the Sets menu" keeps a set out
  of the bar's menu (hold Alt to see it). The set you last put on is shown
  when the window opens, and its name sits under the Sets button. A set remembers the exact copy of each
  item, so two identical daggers with different poisons are two items, and
  it remembers your ammo. Drag a set from the list onto an action bar to make
  a set button. Item tooltips name the sets an item is in.
- **Equip a set** from the window, the Sets button's menu, `/gr equip <name>`
  or a set button on an action bar. In combat your weapons change at once and
  the rest follows when combat ends. A choice made while you are dead waits
  until you are alive.
- **The gear bar and the trinket bar.** Hover a gear button for the other
  items that fit that slot; click one to put it on (right-click: the other
  ring or trinket slot). The empty button takes the item off. Hover a trinket
  (on the bar, the character window or Gear sets) for every trinket in your
  bags: left-click puts it in the upper slot, right-click in the lower. Click a bar button to use the item, Shift-click
  to link it. Alt-click a slot on your character window to add it to the gear
  bar or take it off. Hold Ctrl and Shift and drag a bar to move it.
- **Trinkets window and automatic swap.** Open it with the trinket on the
  minimap, a right-click on a trinket button, or `/gr trinkets`. Each slot has
  its own list in priority order with a stop line; turn on "Swap
  automatically" (or Alt-click the trinket button) and GearRack wears the
  first ready trinket above the line when the worn one is used. Per trinket:
  High priority (put on even when the worn one is ready), Pause the queue
  while worn, and a swap delay (kept on so many seconds after a use). It never
  swaps in combat, while you are dead or casting, or while the worn trinket's
  own buff is on you. Choosing a trinket or a set by hand turns the slot's
  swap off. A small gear on the trinket button shows it is on (grey while it
  waits).
- **Poisons.** Each weapon button shows its poison (or oil, stone or imbue):
  the icon and the time left, or the charges when 10 or fewer are left. Each
  poison has its own icon and ring colour: Instant gold, Dissolvent teal,
  Crippling purple, Mind-numbing blue, Deadly green, Corrosive orange, Wound
  red, Agitating pink. The weapons in the menus show theirs too. To apply a poison, use it from your
  bags or an action bar, then click the weapon on the gear bar.
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
- **Events.** The button after Sets on the gear bar turns Automatic sets and
  Sets by target on or off together; it is lit while they are on. Also a key
  and `/gr events`. Right-click it for their settings.
- **Keys.** Use Trinket 1, Use Trinket 2 and Events on or off, under GearRack
  in Key Bindings or on the settings page.

`/gr` opens the settings: GearRack, Automatic sets and Sets by target.
Right-click a minimap button for the same page.

## What it calls

ClassicAPI does the work: the sets are its own (`C_EquipmentSet`: create,
save, delete, the slots a set leaves out, equipping, the set button on an
action bar), items are moved without the cursor (`C_Item.EquipItemByName`)
and named by their GUIDs (`C_Item.GetItemGUID`, `IsLocked`,
`IsItemGUIDInInventory`, `GameTooltip:SetItemByGUID`), the menus list
`GetInventoryItemsForSlot` and `C_PlayerInfo.CanUseItem`, and the bars count
down with a native `Cooldown`; a poison's time counts down in a
`C_DurationUtil` text binding. The trinket queue reads `GetItemCooldown` by
item ID, `C_Item.GetItemSpell` with `C_UnitAuras.GetAuraDataBySpellName` for
a trinket's own buff, and `C_Spell.CastingInfo` / `ChannelInfo`. Situations
come from their own events (`PLAYER_MOUNT_DISPLAY_CHANGED`,
`UPDATE_SHAPESHIFT_FORM`, `UNIT_AURA`, `UNIT_POWER_UPDATE`,
`GetInstanceInfo`), and only while a row uses them. Nothing runs while nothing
changes: the queue wakes on events and at one timer, the moment a listed
trinket gets ready.

Taking an item off is the one job no DLL does yet: the empty button picks the
item up and drops it into a free bag. A set's ammo is kept by GearRack, since
ClassicAPI's sets hold slots 1 to 19.

## Installation

Needs ClassicAPI (the latest release). Put the `GearRack` folder in
`Interface\AddOns`.
