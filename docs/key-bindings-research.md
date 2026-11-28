# The player's key bindings: research

Static analysis of the 2026-11-02 client (`FFXiMain.dll`, SHA-256 `d809ebe3…7d48fb`), from the saved image in
`toboshii/ffxi-private` (`dump/FFXiMain_20261102.bin`, base `0x10000000`). No running game was read. The work ran in
the cloud container with the mingw `objdump` and the helpers in `ffxi-private/tools`.

## Summary

- The keyboard bindings are **not constant**. Both tables are in `.data`, and the client writes them at run time.
- The player can change two sets of keys. The client keeps them as **config values**: ids 74 to 105 for the
  movement keys and ids 106 to 137 for the shortcut keys. A change of a value runs a callback that rewrites the
  tables at once.
- A key-assignment object has open, OK, cancel and "reset to defaults" methods. That is very likely a game menu.
  The user can confirm it in the game's Config menu.
- Config id 66 is the **keyboard mode** (0, 1 or 2). The movement keys work only in modes 1 and 2. In those modes
  a letter does not open the chat line.
- In modes 1 and 2 the default movement keys use **K without Shift**. So the default nav key K is a game key there.
- A read-only scan from nui can find every table and value by signature. Each signature matches once.

## 1. The action table

- **Where:** `0x1036E6E8`, in `.data` (writable). 188 actions, 3 bindings each, one WORD per binding:
  188 × 3 × 2 = `0x468` bytes, up to `0x1036EB50`. The pad table starts there.
- **The category table:** `0x1036DF98`, 188 WORDs, up to `0x1036E110`.
- **A binding WORD:** the low byte is the DIK code. The high byte holds the rules. The action query
  (`0x10124F00`) tests them in this order. A binding with DIK 0 is empty.

  | Bit | Rule |
  |---|---|
  | `0x01` | Shift is held |
  | `0x02` | Ctrl is held |
  | `0x04` | Alt is held |
  | `0x08` | Ctrl and Alt are held |
  | `0x10` | Ctrl or Alt is held, and the shortcut switch `0x1036DF94` is on |
  | `0x20` | Shift is not held |
  | `0x40` | The chat line does not have focus |
  | `0x80` | Neither Ctrl nor Alt is held |

  A WORD with no rule bits matches the key with any modifiers. The DIK codes `0x1D`, `0x2A` and `0x38` (Ctrl, Shift
  and Alt alone) have their own tests.
- **The shortcut switch** `0x1036DF94` is 1. The key-assignment object sets it to 0 while its menu is open and back
  to 1 on OK or cancel.
- **The macro keys fit the decode:** ids 108 to 117 are Ctrl + `0`, then Ctrl + `1` to `9` (`0x02`). Ids 98 to 107
  are the same keys with Alt (`0x04`).
- **Who writes it:** three small functions.
  - `0x10124B00` returns the first binding's DIK code (signature below).
  - `0x10124B10` sets the first binding to `dik | 0x1000` (rule `0x10`), or to 0.
  - `0x10124B40` sets it to `dik | 0x8000` (rule `0x80`), or to 0.
- **The static image** holds the values that `research/bindings.txt` lists. The game changes the first binding of
  the shortcut actions and of actions 169 and 170 at start, so a fixed copy of the image is not enough.

## 2. The shortcut keys (config ids 106 to 137)

- **The object:** `[0x1066392C]`, vtable `0x10338170`, built at `0x101AA727`. It holds 32 key bytes at `+0x29`.
- **The groups:** a table at `0x1037B358`, 29 rows of 5 WORDs (action ids, `0xFFFF` ends a row). On a change,
  `0x1019E570` sets the first binding of each action in a row to the row's key with rule `0x10`.
- **The callback:** `0x1019EB10` runs when config ids 106 to 134 change. It stores the byte and runs `0x1019E570`.
  The game registers it for each id at `0x101AB122` to `0x101AB3D3` (`0x10194DD0(id, callback, object)`).
- **The defaults** (`0x1019E440`, vtable slot 18, "reset to defaults"), with the actions of each row:

  | Row | Key | Actions | Row | Key | Actions |
  |---|---|---|---|---|---|
  | 0 | A | 59 | 15 | none | 129 |
  | 1 | I | 57 | 16 | none | 130 |
  | 2 | M | 65 | 17 | E | 54 |
  | 3 | J | 127 | 18 | V | 64, 16 |
  | 4 | W | 128 | 19 | H | 61 |
  | 5 | B | 159 | 20 | C | 63 |
  | 6 | Y | 14, 66, 143, 145, 147 | 21 | S | 60 |
  | 7 | N | 15, 144, 146, 148, 149 | 22 | P | 58 |
  | 8 | `-` | 24 | 23 | T | 56 |
  | 9 | F | 120, 17 | 24 | L | 62 |
  | 10 | `]` | 86 | 25 | R | 55 |
  | 11 | `[` | 85 | 26 | U | 173 |
  | 12 | Z | 69 | 27 | X | 174 |
  | 13 | `.` | 79, 164 | 28 | Q | 180 |
  | 14 | `,` | 80, 165 | | | |

  So the stock shortcut letters leave D, G, K and O free, as the first test report found. Rows 6 and 7 add Y and N
  to the Enter and Escape actions (Yes and No).
- **Keyboard layouts** 2 and 3 change some defaults. Layout 2 swaps Y and Z and moves `-`, `,` and `.` (a German
  layout). Layout 3 changes `-`, `,`, `.` and `[`.
- **Rule `0x10` needs Ctrl or Alt.** By the code, a shortcut letter acts only with Ctrl or Alt held. The first test
  report says a plain letter opened a menu. This needs a check in game (question 3 below).

## 3. The movement keys (config ids 74 to 105)

- **The object:** `[0x10663928]`, vtable `0x103381D8`, built at `0x101AA702`. 32 key bytes at `+0x29`. The groups
  are at `0x1037B268` (28 rows of up to 4 entry numbers).
- **The table:** `0x1036F128`, in `.data`. 43 entries of 16 bytes, up to the input mask at `0x1036F3D8`.

  | Byte | Meaning |
  |---|---|
  | 0 | DIK code (0 is empty) |
  | 1 | Modifier rule: 0 none, 1 Ctrl, 2 Alt, 4 Shift, 8 no Shift, 7 any. A rule 0 key also acts with Ctrl or Alt held, unless that key is a shortcut key. |
  | 2 | Context: 4 always, 5 or 6 by a game state (`0x10160380` on `0x106229F0`) |
  | 8 to 15 | Movement and camera bits |

- **The reader** `0x10124B90` reads this table only when the keyboard mode is 1 or 2 (`0x101B94B0`). It skips the
  table while the chat line has focus.
- **The defaults** (`0x1019E790`): W, S, A, D move. I, K, J and L have four entries each: with Shift and without
  Shift, in contexts 5 and 6. `-`, `,`, `.`, `[` and `]` act with any modifier. Q and E are entries 40 and 41.
- **Mode 2 only:** `0x1019E8F0` also binds actions 170 and 169 to key bytes 28 and 29 (E and Q by default)
  with rule `0x80`. `0x1025F730` and `0x1025F7A0` read them as an axis.

## 4. The keyboard mode and the layout

- **The mode:** `[[0x10663924]+0x44]`, set from config id 66 (`0x1019CBB0`). 0: a letter opens the chat line, and
  the movement keys do nothing. 1 and 2: letters do not open the chat line, and the movement keys work.
- **The layout:** `[[0x10457BD8]+8]`. Layouts 2 and 3 remap DIK codes through `0x103509B4` and `0x103509D4`. Where
  the client gets it is not traced.
- **Where the game keeps them:** config values, not the registry and not `cnf.dat` (the second test report). FFXI keeps
  many config values on the server for each character. That fits "they exist only in memory".

## 5. A read-only scan from nui

Each signature matches once in the image. Each holds the address as its 32-bit operand.

| What | Function | Signature | Operand |
|---|---|---|---|
| Action table | `0x10124B00` | `0F BF 44 24 04 8D 04 40 8A 04 45 ?? ?? ?? ?? C3` | +11 |
| Action table (check) | `0x10124FC6` | `66 8B 04 55 ?? ?? ?? ?? 8D 34 55 ?? ?? ?? ??` | +4 and +11, equal |
| Movement table | `0x10124AD0` | `0F BE 44 24 04 C1 E0 04 8A 80 ?? ?? ?? ?? C3` | +10 |
| Keyboard mode | `0x101B94B0` | `A1 ?? ?? ?? ?? 85 C0 74 11 8B 40 44 83 E8 00 74 09 48 74 03 48 75 03 B0 01 C3` | +1 |
| Layout | `0x1019E4C3`, `0x1019E80E` | `A1 ?? ?? ?? ?? 8B 40 08 83 E8 02` | +1, two matches, equal |

The checks that make the read safe:

1. Each signature matches exactly once in `FFXiMain.dll`'s code. The layout signature matches twice, and both operands must be equal.
2. The two action-table operands are equal.
3. Each table lies inside one writable section of `FFXiMain.dll`, and the whole table fits in it.
4. The pad table follows the action table, and the mask follows the movement table, at the offsets above. The
   movement table ends 43 × 16 bytes after its start.
5. The mode and the layout pointers point inside a writable section. A pointer that holds null gives no value, and
   the read reports the mode or the layout as unknown.
6. Each mode value is 0, 1 or 2. Any other value means "unknown".
7. The read copies bytes. It patches nothing, takes no lock and calls no client code. The game writes the tables on
   its own thread. A torn read can give one stale binding, and the next read fixes it.

## Open questions for the game

1. Does the Config menu have a screen to change keys (shortcut keys, movement keys, or both)? Does the FFXI Config
   tool have one?
2. Which keyboard mode does the player use? The code calls it config id 66, with three values.
3. With the stock keys, does a plain I open the item menu, or only Ctrl + I or Alt + I?
4. In the mode with the movement keys, what does K do? The code shows K without Shift as a movement or camera key.

## Decisions (agreed with the user, 2026-11-28)

- **Where Chronicle learns the bindings:** a native read of the live tables. nui 1.7.0 adds `key_bindings()`, a
  read-only copy, and `_chronicle.dll` 2.1.6 carries it. `ui/keybinds.lua` decodes the copy.
- **On a clash:** Chronicle warns and keeps the key, as it does for the controller chord.
- **When it warns:** only when the key is set, from the Settings row "Keyboard key" or `//cr nav key <name>`. Not
  in the status and not at load.

Found while testing: with the stock bindings, F10 is game action 82 (F1 to F10 are actions 70 to 78 and 82, rule
`0x80`). Ctrl + N is Cancel (action 15, rule `0x10`). So the README's old examples `f10` and `ctrl+n` were game keys.
