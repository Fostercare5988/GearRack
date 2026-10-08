# GearRack

**v1.0.0** · Equipment sets, trinket priorities and weapon swapping for **WoW 1.12.1, build 5875**.

- Save full or partial gear sets and assign keys to equip them.
- Choose carried equipment from a customizable bar.
- Queue weapon choices through casts, global cooldowns and temporary item locks.
- Manage two trinket slots with separate priority lists, profiles and swap delays.
- Read large gold cooldown numbers, rarity borders and weapon-enchant countdowns.
- Enable optional gear changes for mounts, forms and other events.

## Requirements

GearRack requires these client DLLs:

| Extension | Minimum version |
| --- | --- |
| [ClassicAPI](https://github.com/brues-code/ClassicAPI) | 1.15.16 |
| [SuperWoW](https://github.com/balakethelock/SuperWoW) | 2.2 |
| [NamPower](https://github.com/Emyrk/nampower) | 4.6.2 |

Follow each extension's installation instructions and restart the client after changing DLLs. GearRack prints a message if a required extension is missing.

## Install

1. Download the ZIP from [Releases](https://github.com/Fostercare5988/GearRack/releases).
2. With WoW closed, extract **GearRack** into `Interface/AddOns`. The folder must contain `Interface/AddOns/GearRack/GearRack.toc`.
3. Enable **GearRack** in the character-screen addon list.

## Getting started

Click the **purple gear** minimap button for **Gear sets** or the **yellow PvP trinket** for **Trinkets**. Right-click either button for its options.

The initial equipment bar contains main-hand, off-hand, ranged and Sets buttons. Hover a slot to choose an item. Alt-click a character-sheet slot to add or remove its button. Open **Gear sets → Bar layout** to reorder buttons or hide Sets.

Save and bind equipment sets in **Gear sets**. Assign trinket-use keys in **Key Bindings → GearRack**. Open **Trinkets** to configure each slot's priority list and manual-choice options.

A saved set takes priority for its selected slots. Armor and trinkets wait for combat to end; eligible weapons can swap during combat. **Keep manual choices** is enabled by default: included trinket queues stay paused until you resume them. Turn it off to allow automatic queues to continue after the full set finishes. Omitted slots keep their current queue state.

**Back** or **Escape** returns from Bar layout to the previous Gear sets tab. Escape closes a primary editor; **X** closes GearRack menus. Text fields and set-key capture handle Escape first.

## Commands

`/gearrack` is an alias for `/gr`.

| Command | Action |
| --- | --- |
| `/gr` | Open or close Gear sets |
| `/gr sets` | Open Gear sets |
| `/gr layout` | Open Bar layout |
| `/gr queues` | Open trinket priorities |
| `/gr trinkets` | Show or hide the equipped trinket buttons |
| `/gr trinkets opt` | Open trinket options |
| `/gr keys` | Open Key Bindings |
| `/gr equip <set>` | Equip a saved set |
| `/gr toggle <set>` | Equip a set or restore the gear it replaced |
| `/gr bar` | Show or hide the equipment bar |
| `/gr lock`, `/gr unlock`, `/gr scale .85` | Adjust the equipment bar |
| `/gr trinkets load top <profile>` | Load a priority profile; use `bottom` for the other slot |

Set and profile names may contain spaces and retain their case.

[Equipment and macros](docs/USER_GUIDE.md) · [Trinkets](docs/TRINKETS.md) · [Optional automation](docs/EVENTS.md)
