# Controller support: research and plan

Status: **implemented** on branch `claude/controller-support-plan-yjc276`, in both repositories. **Not yet run
in game**: Phase 0's checks below are still open.

Decisions taken:
- **The hook is in nui from the start** (Phase 6 first). It ships as nui 1.3.0 on the toboshii/nui fork:
  `src/PadHook/PadHook.h` (a shared bus, PadHook 1) and `src/pad.cpp` (the Lua functions). Chronicle vendors
  it like the rest of nui.
- **XInput only.** `PadState::source` and the single XInput-layout button word are there so a DirectInput
  source can join the same bus in a later revision.
- **L3 + R3** takes the pad and gives it back.
- **On by default** (`pad = true`). Until something holds it, the hook only records: the game gets exactly
  what it read.

What changed from the plan:
- The patch uses the Windows hot-patch form (`8B FF` becomes `EB F9`, and a long jump goes into the padding),
  not an import-table or detour patch. So Phase 0's question 1 becomes: is `xinput1_3!XInputGetState`
  hot-patchable? If not, the hook refuses and says which bytes it found.
- "Held before the capture" means what the game had already seen pressed (its last output), not what is held
  at the first read after the capture. A press arriving in that same read is Chronicle's.
- Phase 1's keyboard driver was not built.
- If the hold lapses during a stall, Chronicle takes the pad again on the next frame, and the buttons still
  held wait for their release.

Where it was tested:
- `test/test_pad.lua` (84 checks) ran here, with stock Lua 5.1 and the harness's fake DLL.
- The mask rules and the thunk bytes ran on 32-bit Linux, against a stand-in `windows.h`. The thunk was
  disassembled.
- nui's `test/build_pad_test.sh` builds here, but Wine does not start in this container, so its exes were
  not run. Run it on Windows: `sh test/build_pad_test.sh --self-test`.

## 1. What "controller support" has to mean

A player with a gamepad in hand can do everything in Chronicle without the mouse or keyboard:

- show and hide the window, and give the pad back to the game;
- switch between Missions, Quests and Records;
- move between cards, rows, buttons, links, path tabs and requirement rows, and open them;
- go back;
- scroll a long walkthrough, including the stretches that have no links in them;
- change Sort and Show, enlarge a map and close it, change every setting.

While Chronicle has the pad, the game must not also act on the same presses. Mouse and keyboard
users must see no change, and with controller mode off every rendered frame stays exactly as it
is now. That matters because the QA gate approves 12,986 frames.

## 2. How input works today (what the plan builds on)

| Piece | Where | What it does |
|---|---|---|
| Mouse | `chronicle.lua:315` → `W:mouse` (`ui/window.lua:407`) | Windower `mouse` event; returning true blocks the click from the game. Hover = `hit_at` → `self.hover`. |
| Keyboard | `chronicle.lua:321` → `W:key` (`ui/window.lua:633`) | Only the focused search box takes keys; a key-up is swallowed only if its key-down was (review UI-4). |
| Hits | every widget calls `b:hit{...}` (`ui/ops.lua:359`) | Each clickable thing is a rectangle with an `id` plus fields, in the chrome, content or overlay builder. |
| Actions | `S.click(hit, ctx, app)`, `S.right(...)` per screen; `common.click` for the shared chrome | A click is just "this hit was activated". Back is `app:back()`. |
| Hover drawing | `S.overlay` / `S.tooltip` per screen; chrome widgets read `ctx.hover` | The overlay layer (layer 3) is small and cheap to re-send. |
| Per-frame work | `prerender` (`chronicle.lua:337`) → `W:tick` | Already where coalesced drags and the caret blink happen. |
| Native module | `plugin/ChronicleModule.cpp` → `nui::host_open(L, kConfig)` | `host_open` takes an `extra` array of Lua functions (`plugin/nui/host.hpp`), so Chronicle can add functions **without editing the vendored nui library**. |

The key observation: every clickable thing already exists as a hit with its action already
wired. Controller navigation therefore does not need per-screen code. It needs three things:

1. a **cursor**: one hit chosen from the hit lists;
2. a way to **move** the cursor between hits;
3. **activate** = call the screen's existing `S.click(cursor)`, and **back** = `S.right`.

The hover machinery already draws a highlighted hit (`S.overlay`, `kit.button` hover state, tab
hover colour), so "draw the cursor" is mostly "set `self.hover` to the cursor".

## 3. Where controller input can come from

### Findings

| Question | Answer | Confidence |
|---|---|---|
| Does Windower 4 give Lua any controller input? | **No.** None of its 48 events, nor anything in the Lua API definitions, deals with a gamepad. `bind` takes keyboard keys only, and no official plugin handles pads. Windower's own developer said pad buttons are "not possible with Windower alone". | High |
| How does FFXI read the pad? | Two ways, chosen by the game's own **Enable XInput** setting (the 6th flag of `padmode000`). With it on, the game calls `XInputGetState` in `xinput1_3.dll`. With it off, it uses DirectInput8 (`DIJOYSTATE2`, up to 128 buttons). Ashita hooks exactly these two (`XInputGetState`, and `DirectInput8Create` with the devices it creates). | Medium-high |
| What does the game do with each button? | `padsin000` maps 27 game actions to button ids, for example Cancel (slot 5), Main menu (6), Confirm (7), Active window (8), menu movement and targeting (21-24), and the macro-bar modifiers (1, 3). It is stored in the registry next to `padmode000`, and the button ids differ between XInput and DirectInput mode. | High |
| Is Confirm A or B on an Xbox pad? | It depends on the player's config. Reports disagree on the default. **Read it, don't assume it.** | Low (for the default) |
| How do others handle this? | **Ashita v4** hooks `XInputGetState` and DirectInput's `GetDeviceState`/`GetDeviceData`, and lets an addon set `blocked` on a button event. **tCrossBar** blocks a button from its press until the release of the same button. **XIVCrossbar** (Windower 4) uses an AutoHotkey helper that polls `xinput1_3`, sends keys to the game, and blocks nothing: players must clear Confirm, Cancel, Main menu and Active window in the game's pad config. | High |
| Does Windower 4 already hook XInput? | Not confirmed: its core is closed source. Fenestra, its open successor, wraps only the DirectInput **keyboard** and has no XInput hook. No evidence of a Windower 4 XInput hook was found. | Medium |

Sources: Windower/Lua wiki Events page; docs.windower.net (keymapping, plugins, profiles);
AshitaXI/Documentation (`usage/configurations.md` for `padmode000`, `padsin000` and both button-id
tables; `features/_index.md` for the hooked functions); AshitaXI/Ashita-v4beta `plugins/sdk/Ashita.h`;
ThornyFFXI/tCrossBar `controller.lua` and `resources/controllers/xbox.lua`;
AliekberFFXI/xivcrossbar `ffxi_xinput.ahk` and its README; Windower/Fenestra
`core/src/wrappers/direct_input.cpp`; ffxiah.com forum threads 46689, 47705, 48882 and 57877.

### Options

| Option | Reads the pad | Stops the game acting on it | Verdict |
|---|---|---|---|
| A. Windower events | — | — | Does not exist. |
| B. External helper (AutoHotkey, as XIVCrossbar does) | Yes | No: the player must strip the game's pad config | Rejected. It is a second program to install, and Chronicle's whole point is to sit in the game's own windows. |
| C. Poll XInput / open our own DirectInput device from the DLL, read-only | Yes | **No** | Not enough alone: the D-pad would move Chronicle's cursor **and** the game's menu cursor or target. Kept as a fallback reader. |
| D. **Hook the game's own read in `_chronicle.dll`** (what Ashita does) | Yes | **Yes**, per button | **Chosen.** It is the only way to do it in-process without the player re-mapping the game. |

### The decision and how it fits the native layer

The pad reader goes in **Chronicle's own plugin code**, in a new `plugin/pad.cpp`. It reaches Lua
through the `extra` functions of `nui::host_open`, so the vendored `plugin/nui` stays unchanged.
It follows the rules `UiHook` already sets for the native layer:

- **Fail closed for drawing, fail open for the game.** If any check fails (the function is not
  where expected, its first bytes are not the ones expected, another hook already sits there that
  we cannot chain), Chronicle patches nothing and says why in `//cr status`. Mouse and keyboard
  keep working.
- **Patch once, never free.** The patch jumps into a thunk in memory that no module owns. The
  thunk reads a dispatch pointer, and `stop()` and `DllMain` detach set that pointer to null. After
  an unload or reload the thunk passes every call straight through, so the game never calls into
  a freed DLL.
- **A heartbeat.** Every time Lua reads the pad, it renews masking for 250 ms. If Lua stops
  calling (a Lua error, a stuck addon), masking lapses by itself and the game gets the whole pad
  back. A Chronicle bug must never leave the player with a dead controller.
- **Read the game's own config.** The DLL reads `padmode000` and `padsin000` (registry,
  read-only, 32-bit view). From them it knows which API the game uses and which buttons are the
  player's Confirm and Cancel. It can also warn when the chord that enters controller mode is
  mapped to something in the game.

**XInput mode (version 1).** Hook `XInputGetState`:

- Phase 0 decides between patching `FFXiMain.dll`'s import entry, if it imports the function
  statically, and patching the export's entry inline, if the game loads it with `GetProcAddress`.
  Either way, the thunk chains to whatever was there before.
- The game's own call gives us the state, so nothing polls XInput separately. This also avoids
  the known stall of polling a slot with no pad.
- While masking is on, the hook clears the masked buttons, the triggers and the sticks before
  the game sees the state. It also **renumbers `dwPacketNumber`** each time the state it returns
  changes. Otherwise a game that skips unchanged packet numbers would never see a held button
  being masked or unmasked.

**DirectInput mode (later, optional).** The device vtable is shared with the keyboard device
that Windower wraps. A hook there would have to recognise the joystick by its `this` pointer
and pass every other call through untouched. That is riskier, so it is Phase 5. Until then, in
DirectInput mode, controller mode says plainly that it needs **Enable XInput** in the FFXI
Config, and keyboard navigation still works (Phase 1).

## 4. The navigation model (input-agnostic, Lua)

### The cursor

There is one cursor per window, and it is a hit. The targets are:

- chrome hits, except the resize grips (`hit.resize`) and `id = 'noop'`;
- overlay hits: the sticky path-tab bar's tabs, but not `sticky_bar`, the bar's background;
- content hits. Several rects of one wrapped link (the same `span`) count as **one** target.

There are two zones: the **header** (chrome and sticky overlay) and the **content**. A move stays
inside its zone while there is a target in that direction, then crosses to the other zone. So:

- Up from the first row goes to the toolbar (Search, Sort, Show), then to the tabs and controls.
- Down from the header lands on the first content target in view.
- Inside the content, a move uses **content coordinates over all hits**, not only the visible
  ones. Up at the top of the view therefore scrolls to the row above it instead of jumping to the
  header.

### Moving

Moves are spatial, the way TV and console browsers move focus:

- The candidates lie beyond the cursor's edge in the direction pressed.
- The score is the gap along that direction plus about 2 × the offset across it. The offset
  counts as 0 when the two rects overlap across the direction, and ties go to reading order.
- This handles every layout Chronicle has without special cases: the home's two-column card
  grid, rows, the toolbar, Settings' `-` / value / `+`, a walkthrough's path tabs, links in a
  paragraph and requirement rows.

### Sparse pages

A walkthrough can have long stretches of text with no link. If the next target down is more
than about half a viewport beyond the view, a press **scrolls one step** (a third of the
viewport) instead of jumping. The cursor stays where it is while it is still in view, and is
parked otherwise. Links take the cursor as they come within reach. This is how the D-pad reads a
page.

### Keeping the cursor in view

After a move, the view scrolls just enough to show the target with a 24 px margin, or aligns
the target's top if it is taller than the viewport. When something else scrolls the view (the
right stick, the wheel), a cursor that leaves the view moves to the nearest target in view.

### Surviving a re-layout

Hits are rebuilt on every layout. `W.key_of` includes x0/y0, so it breaks on a resize. The cursor
therefore keeps a **semantic key** with no coordinates: `id`, plus whichever of `span`, `group`,
`i`, `area`, `cat`, `ci`, `si`, `oid`, `item.id`, `name`, `file`, `step`, `dir` and `key` the hit
has, plus an ordinal for duplicates. After each content layout the cursor is found again by
that key. Failing that, it goes to the target nearest its old content y.

### Going back lands where you were

`App:go` already pushes `scroll`. It also pushes the cursor key, and `App:back` restores it. B
from an area list returns the cursor to the area's card. `set_screen(S, scroll, cursor)` takes
it.

### Drawing it

- **No new art in mouse mode.** In controller mode `self.hover` follows the cursor, so the
  existing hover drawing (`S.overlay`, `kit.button`'s lift, the tab colour) shows it.
- On top of that, the overlay adds a 1 px `press_edge` frame around the cursor's rect(s), for
  any hit. A link's hover is only an underline, which is too faint for a cursor.
- Content tooltips anchor at `win.mouse_at`. In controller mode it is set to the cursor's
  position, so tooltips still say where a link goes ("opens in BG-wiki").
- A hint line goes in the empty bottom margin (`h - 18` to `h`), in controller mode only, for
  example `A Open   B Back   LB/RB Section   LT/RT Page`. The labels follow the player's own
  Confirm and Cancel.
- With controller mode off, every frame is identical to today's, so the existing 12,986
  approved frames need no re-approval. New frames are added only for controller mode.

### Controller layout (XInput names)

| Input | Action |
|---|---|
| D-pad, left stick | Move the cursor. Repeats after 0.35 s, then every 70 ms. The stick has a deadzone of 0.5 that releases at 0.35. |
| Confirm (the player's, A by default) | Activate: `S.click(cursor)`. On the search box it gives keyboard focus, as a click does today. |
| Cancel (the player's, B by default) | Close the enlarged picture, or leave the search box, or `app:back()`. With nothing to go back to, give the pad back to the game. |
| LB / RB | Previous / next section: Missions, Quests, Records (`common.click` `navtab`). |
| LT / RT | Page up / page down (a viewport less 36 px, the QA step). |
| Right stick | Smooth scroll, its speed growing with the square of the deflection. The cursor follows. |
| X / Y | Sort / Show, on list screens. |
| Start | Settings. |
| Back | Collapse or expand. |
| R3 | Top of the page. |
| Chord (configurable) | Enter or leave controller mode. |

### Entering and leaving controller mode

Chronicle never takes the pad on its own. There are three ways in:

- `//cr pad`, which can be bound to a key with Windower's `bind`;
- the chord;
- Settings → Controller.

There are six ways out: the chord again, Cancel at the root, `//cr pad off`, hiding the window,
logout or unload, and the game losing focus. Losing focus matters because "Always Enable
Gamepad" otherwise sends one pad to every open instance.

Held buttons follow the rules the keyboard and mouse code already follows:

- **Entering:** buttons already held keep reaching the game until they are released, and
  Chronicle ignores them until then. This matches review UI-4, where a key held before the box
  took focus is released to the game.
- **Leaving:** each button still held stays masked until it is released, so the game never sees
  half a press. This matches review LIFE-2, where a release belongs to whoever took the press.

The default chord must not do anything in the game. The macro-bar triggers fire macros when
combined with face buttons, so the chord can't use them. The candidate is **L3 + R3**, to be
confirmed in Phase 0 against preset F's `padsin000`. At run time, Chronicle warns if the
player's own config maps a chord button. If no free pair exists, the chord can **defer** its
first button: hold it back from the game for up to 120 ms waiting for the partner, and release
it late if the partner doesn't come.

### Mouse and keyboard together

The last input wins. Any pad action switches to controller mode's drawing. A mouse move of more
than 3 px over the window switches back to mouse hover; the cursor key is kept for the next pad
press. Typing in the search box is unchanged.

## 5. Modules and API

**Lua (new)**

- `ui/nav.lua`: pure functions over hit lists, with no Windower and no DLL. It covers targets,
  semantic keys, `move(dir)`, scroll-into-view and the sparse-page step. Fast to unit-test.
- `ui/pad.lua`: decodes raw state into actions: edges, auto-repeat, stick deadzone and
  hysteresis, the chord, and the held-button rules. Pure, taking `(seq, buttons, axes, now)`.
- `ui/window.lua`: `self.cursor`, `self.cursor_key`, `self.mode = 'mouse' | 'pad'`;
  `W:pad_action(a)`; the cursor frame and hint line in the overlay section of `W:flush`; the
  re-find after a content layout. Do not reuse `self.focus`, which is the search box's keyboard
  focus.
- `chronicle.lua`: poll `N.pad()` once per `prerender`, with no table allocation (it returns
  numbers). Do nothing unless `seq` changed or a repeat timer is due. Add the release paths to
  `hide`, `logout`, `unload` and `lose focus`; settings defaults (`pad = false`, `pad_chord`);
  `//cr pad [on|off|status]`; HELP lines; the Settings rows.
- `core/app.lua`: the cursor key in the nav stack.

**Native (new, `plugin/pad.cpp`, registered in `ChronicleModule.cpp`)**

| Function | Returns / does |
|---|---|
| `pad_start([mode])` → ok, why | `mode` is `'auto'` (from `padmode000`) or `'xinput'`. Installs the hook, or explains why not. |
| `pad()` → seq, buttons, lt, rt, lx, ly, rx, ry | The last state the game read (raw, before masking). `seq = 0` means no pad. Also the heartbeat. |
| `pad_capture(on)` → ok | Masking on or off, with the held-button rules applied in the hook. |
| `pad_config()` → xinput, confirm, cancel, padsin | The game's own pad settings, from the registry. |
| `pad_status()` → table | api, hooked, how (`iat` / `inline` / `none`), why, calls/s, captured, masked bits. |
| `pad_stop()` | Null the dispatch pointer; the thunk stays. |

The hook runs on whichever game thread calls `XInputGetState` (Phase 0 confirms which), and Lua
runs on the addon worker thread (host.hpp's thread notes). They share one small struct behind a seqlock, so the game thread never waits on
Lua. The module's version goes from 2.0.2 to 2.1.0, and the header comment "Owns no game logic
and no input" changes to describe the pad hook.

## 6. Phases

**Phase 0: in-game spike.** No shipped code. These questions must be answered before Phase 2.

1. Using the `FFXiMain.dll` copy the native tests already use (`CR_FFXI_COPY`), check whether
   the game imports `xinput1_3!XInputGetState` statically or loads it with `GetProcAddress`.
2. In game: which thread calls it, how often, and for which user indexes?
3. With Windower loaded, are the first bytes of `XInputGetState` and the import slot unpatched?
4. Does the game honour a renumbered `dwPacketNumber`? Do masked buttons stop acting?
5. Read `padmode000` and `padsin000` for preset F and a few real configs. Pick the default
   chord, and note which buttons are Confirm and Cancel.

**Phase 1: navigation core and keyboard driver.** Lua only, and can ship on its own.

- `ui/nav.lua`, the window cursor, and cursor restore on back.
- A keyboard driver: in `//cr nav` mode the arrows, Enter, Backspace, Tab and PgUp/PgDn drive
  the cursor and are blocked from the game through the existing `keyboard` event, with the same
  key-up rules as the search box.
- This proves the model in game before any native work. It is also already useful to players
  whose Steam Input, DS4Windows or reWASD maps the pad to keys.

**Phase 2: native reader.** `plugin/pad.cpp` with the XInput hook in **observe-only** mode,
`pad()`, `pad_config()`, `pad_status()`, `ui/pad.lua` decoding, and `//cr status` lines. Usable
behind an unadvertised `//cr pad test`, because nothing is masked yet.

**Phase 3: masking.** `pad_capture`, the heartbeat, packet renumbering, the held-button rules,
the chord, and every exit path. This is the shippable feature, for XInput mode.

**Phase 4: polish.**

- The hint line; Confirm and Cancel taken from the game's config.
- Settings rows: Controller On/Off, the chord.
- README: a "With a controller" section and the commands table. HELP lines.
- QA frames for the cursor on each screen type; perf budgets; release notes.

**Phase 5 (optional): DirectInput mode.** The vtable hook filtered to the game's joystick
device, `GetDeviceState` and `GetDeviceData`. Do it only if PlayStation-pad players without
Steam Input ask for it.

**Phase 6 (optional): share the hook.** If another nui-based addon wants the pad, move the hook
into nui as a shared bus like `UiHook`: one patch per process, the highest revision drives. Until
then a single-client thunk is enough.

## 7. Tests

These follow the existing harness (`test/harness.lua`, fake DLL, `env.frame`, `env.advance`):

- **Fake DLL:** `N.pad` and `N.pad_capture` return scripted states, and `env.pad{...}` sets
  the next one.
- **`test/test_nav.lua` (pure):**
  - From the first card: Right goes to card 2, Down to card 3, Up to the Missions tab.
  - Toolbar ↔ rows.
  - Settings `-` / `+` around the excluded `noop`.
  - A wrapped link is one stop.
  - Path tabs and the sticky bar.
  - A sparse walkthrough scrolls by steps.
  - The semantic key survives a resize.
  - Duplicate names get ordinals.
- **`test/test_pad.lua` (driven through `chronicle.lua`):**
  - Edges and repeat timing; stick hysteresis; the chord.
  - Confirm on a card opens the area; Cancel returns with the cursor on that card.
  - LB/RB change tabs; LT/RT page; the right stick scrolls and the cursor follows.
  - Confirm or Cancel closes the picture; Confirm on Search gives keyboard focus and Cancel
    leaves it.
  - The collapsed window.
  - Mouse move ↔ pad mode switching.
  - Each review-style rule as its own named check, failing on the code without it: buttons
    held on entry pass through; buttons held on exit stay masked; the heartbeat lapses; hide,
    logout, lose focus and unload release the pad.
- **`test/test_perf.lua`:** one `prerender` with no change costs one C call and no allocation; a
  move on the largest walkthrough stays within budget.
- **Native (`plugin/test`):**
  - A fake `xinput1_3.dll` behind the real hook: pass-through, masking, renumbering, the
    heartbeat.
  - Chaining over a pre-existing hook.
  - Unloading `_chronicle.dll` while the thunk is called, then reloading it.
  - The fail-closed checks: wrong bytes give no patch and a status message.
- **`test/qa_render.lua`:** cursor frames for home, an area list, a walkthrough with path tabs,
  Records and Settings. Mouse-mode frames must stay byte-identical.

## 8. Risks and open questions

1. **Windower 4 is closed source.** Phase 0 must check, in game, that Windower does not already
   patch `XInputGetState`. If it does, the thunk chains through it, or the hook refuses and says
   so.
2. **Ashita.** Chronicle is a Windower addon, but if the DLL is ever loaded under Ashita, Ashita
   owns this hook. Detect it and refuse.
3. **The game's default layout is uncertain** (Confirm on A or B, what L3/R3 do). This is why
   Confirm and Cancel come from `padsin000`, and why the chord is configurable and checked.
4. **DirectInput players** (PlayStation pads, Steam Input off) get keyboard navigation only until
   Phase 5. Is that acceptable for version 1?
5. **Design principle change.** `_chronicle.dll` today "owns no game logic and no input". A pad
   hook changes that, carefully. Decide whether that is acceptable in this fork, or whether the
   hook should live upstream in nui from the start (Phase 6 first).
6. **Steam Input** can remap the pad or turn it into keys. Windower does not support running
   through Steam. Document "turn Steam Input off for FFXI", and note that Phase 1's keyboard
   navigation covers players who keep a pad-to-keys mapping.
