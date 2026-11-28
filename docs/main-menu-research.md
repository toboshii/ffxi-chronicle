# A "Chronicle" item in the game's main menu: research

Static analysis of the 2026-11-02 client, from the saved image in `toboshii/ffxi-private`, plus one check in game by
the user. No running game was read.

## Summary

- **A line the client runs itself reaches Windower** when it starts with `/con` (or `/console`). The user checked it
  in game: `/con cr show` in a game macro shows Chronicle. A plain `//cr show` in a macro does not work.
- **The client has one general line runner,** `0x10080DC0` (`line, flags`), with 51 callers. The main menu, the chat
  helpers and other windows build a line, often with `sprintf`, and run it there. It is very likely the function the
  user's macro test went through. That is not proven yet.
- **The main menu has 15 items.** Its handler switches on the item number 1 to 15, and any other number does nothing.
  Some items open a menu by name, and some run a command line through `0x10080DC0`.
- **The items are not in a code table.** The handler object is 20 bytes and holds no item list. The window, its
  items and their labels come from the client's menu resources, which the client loads by name (`menu    menuwind`
  and so on). So a sixteenth item needs a change to the loaded menu resource as well as to the handler.

## 1. The line runner (confidence: high for the function, medium for the Windower link)

- `0x10080DC0` takes a line and a flags word. It copies the line into a 512-byte buffer through
  `[0x10663F5C]` (`0x101AEA80`), then parses and runs it against the command table.
- **The command table:** `0x10356404`, 277 entries of 24 bytes: a WORD id, a WORD of flags, then the name (`/emote`,
  `/echo`, `/macro`, `/target`, `/equip` ...). `0x10077B40` looks a name up.
- **Callers:** 51. The main menu's items (`0x1014FE2C`, `0x1014FE60`, `0x1014FF63`), menus that build lines with
  `sprintf` (`0x10313631`), and `0x100778CE`, which runs a line with flags.
- **Windower:** `Hook.dll` knows the commands `/con` and `/console`. The user's test shows that Windower sees a
  macro's lines. Which client function Windower hooks to see them is not found. If the menu's own calls to
  `0x10080DC0` pass the same hook, a menu item that runs `/con cr show` would work. A test in game can settle it
  only with a patched client, so it waits for a design.

## 2. The main menu (confidence: high for the handler, medium that it is the main menu)

- **The handler object:** 20 bytes, vtable `0x10337520`, built at `0x10166B61`, kept in `[0x10579624]`. Its slot 6
  (`0x1014FD80`) acts on a selection.
- **The selection:** slot 6 switches on a kind (3 to 28). For kind 4, while logged in (`[0x104E0F48]`), it switches
  on the item number: `dec eax; cmp eax, 0xE; ja <nothing>; jmp [eax*4 + 0x10150058]`. So items 1 to 15 have a case,
  and 16 goes to the "nothing" path at `0x10150026`.
- **The cases:** each case calls one function and then `0x10037B90`. Examples:

  | Item | What it does |
  |---|---|
  | 1, 5, 6, 7, 9 | Opens a menu by name: `0x1015F920(name, 1, 0)` on the menu manager `0x106229F0` |
  | 2 | Runs `/quest` through `0x10080DC0` |
  | 3 | Runs `/keyitem` through `0x10080DC0` |
  | 10 | Runs `/clock` through `0x10080DC0` |
  | 4, 8, 11, 12 | Call their own functions (`0x101CD640`, `0x10218AD0`, `0x10161F30`, `0x10161FC0`) |

  The item names are a guess from the commands. The game's own order is a check for the user.
- **Opening a menu by name** is one call: `0x1015F920` with a 16-character name such as `menu    menuwind`.

## 3. What a sixteenth item needs

1. **A sixteenth element in the window.** The window and its items come from a menu resource, not from code. The
   resource format and where the client keeps it after loading are not traced yet.
2. **A label.** The labels come from the client's string resources.
3. **An action.** A hook in slot 6, or on the "nothing" path, that runs `/con cr show` through `0x10080DC0` for item
   16. That is a small code patch, of the same kind as the pad and key hooks.
4. **Navigation.** The cursor, the pad and the keyboard move over the window's elements. A new element must take
   part in that, or the pad cannot reach it.

Items 1 and 4 are a patch of the client's UI data, which is bigger than the pad and key hooks. They need more research
before anyone can say the patch fails closed.

## 4. The menu resources (the second pass, 2026-11-28)

- **The menu manager** is the object at `0x106229F0`. Its list at `+0x1C` holds the loaded menu resources. Each
  resource has its 16-character name at `+0x46`, and `0x1015F600` finds one by name with a 16-byte compare.
- **Opening a menu** (`0x1015F920`): it finds the resource, reuses an open window or builds a new one (a 0xD4-byte
  window, class `0x10118750`), and builds it from the resource with `0x101193D0`.
- **The resource's shape**, as `0x101193D0` and its accessors read it:

  | Offset | What |
  |---|---|
  | `+0x04` | Pointer to the element array: entries of 20 bytes. Entry `i` (from 1) is at `+0x04 + (i - 1) * 20`. |
  | `+0x08` | The frame element (the window's background and size) |
  | `+0x0C` | One more element (built last, after the items, likely the cursor) |
  | `+0x18` | WORD: the number of entries |

  An entry's first DWORD points to the element's data, and the element's id is the WORD at data `+0x12`
  (`0x1011C730` finds an entry by id). The entry's DWORD at `+0x10` is a second pointer.
- **The window** builds one 0x60-byte object (`0x1011AD60`) per entry, counts them at window `+0x58`, and keeps them
  in its list at `+0x14`. The entry whose id matches the window's `+0x4C` becomes the selected one.
- **Where the resources come from:** the client loads them from its data files at run time, into its own heap. They
  are not in the image, so the saved image cannot show the main menu's entries.

## 5. What a sixteenth item would take

1. Find the `menu    menuwind` resource in the manager's list (after the client loads it, and again whenever the
   client loads it again).
2. Allocate a new entry array of 16 entries with the client's own allocator (`0x103131FB`), because the client may
   free the old one itself. Copy the 15 entries, add one, and set the count.
3. Make the new entry's element data: a copy of item 15's data with a new id, a new place and a new label. The format
   of that data (the label, the place, the links that the cursor follows) is not known yet. Lego could read it from
   the live game, but that needs a read of a running client.
4. Make the frame taller, so the window draws the sixteenth row.
5. Patch the handler: item 16 runs `/con cr show` through `0x10080DC0`.

Steps 1 to 4 change the client's UI data in its heap, and they depend on a data format nobody has read yet. Each
change can fail in ways the pad and key hooks cannot: a wrong link can strand the cursor, and a wrong size can draw
the window wrong. A fail-closed check can confirm the resource's shape before any change, but it cannot confirm that
the result draws and navigates well. Only many test builds in game can do that.

## What works today

A game macro with the line `/con cr show` opens Chronicle. The macro bar also works from the pad, through the
game's own macro palette.
