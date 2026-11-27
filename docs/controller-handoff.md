# Controller support: handoff

This is for an agent who continues this work. It records what was built, where it is, what has and has
not been checked, and what is left. Read it with `docs/controller-support.md`, the original plan with the
research behind it, and `docs/test-findings-plan.md`, the fixes from the two test reports.

Last updated 2026-11-27 (the keyboard hook).

## 1. State in one paragraph

The controller works in game on nui 1.3.0, by the user's report: controller mode and navigation "work
great". Since then the work answered two test reports. nui 1.4.0 keeps the L3 + R3 chord from the game.
nui 1.4.2 gives an HD texture pack's atlas its own cache key. nui 1.5.0 moves the pad hook to the client's
own XInput wrapper, because the old hot patch of `xinput1_3.dll!XInputGetState` refused on the test
machine. Chronicle vendors nui 1.5.0 in `_chronicle.dll` 2.1.4, and carries upstream's Chronicle 2.1.1
mouse fix. **Test build 2 works in game**, by the user's report of 2026-11-27, on the machine where the old
hot patch refused: the hook reads through the client's wrapper, the chord no longer sits the player or turns
the camera, and every check on the retest list passes. Two pull requests are open on `jintawk/nui`: the HD
texture pack work (`hd-texture-packs`) and the pad hook (`controller-pad-hook`). Upstream has merged neither yet. The
Chronicle side has no pull request. The keyboard driver is built (`d4417ad`, §3). It passes its tests here, and the QA
frame comparison on Lego finds only the new Settings row (§4). The player can now choose the controller chord
(`1954955`, §3), and Cancel at the root can hide the window (`cffc161`, auto-hide, §3). Both work in game, by the
user's report of 2026-11-27, and so does the choosable nav key (`fb65dc1`). **The nui keyboard hook is built** (nui
1.6.0, `dc45e56`, §3). It hides only the keys Chronicle names, after Windower's wrapper sees them, so chat, macros
and binds work in nav mode. Chronicle uses it from `9c0ab84` (`_chronicle.dll` 2.1.5). The search box still blocks the
whole keyboard, and so does nav mode when the hook is missing or refused. Its Linux and Windows tests pass, and
**keyboard hook test build 1 works in game**, by the user's report of 2026-11-27 (§4).

## 2. Repositories, branches, commits

| Repo | Branch | Head | What it holds |
|---|---|---|---|
| both | `claude/new-session-1xkqpc` | Chronicle: this document's commit. nui: `8820af0` | The keyboard hook session (2026-11-27), from `ccr-bfbc0043-hhlj8v`'s heads (Chronicle `652a620`, nui `6b821c8`). It adds the research note, nui 1.6.0 and its use in Chronicle. |
| both | `ccr-bfbc0043-hhlj8v` | Chronicle: `652a620`. nui: `6b821c8` | The 2026-11-27 session's branch, made from `ccr-d3a8994b-5t63ba`'s heads (Chronicle `36a7467`). It adds the keyboard driver, the choosable nav key, the choosable controller chord and auto-hide. nui is unchanged. |
| `toboshii/ffxi-chronicle` | `ccr-d3a8994b-5t63ba` | `b24f027` (fast-forwarded on 2026-11-27) | The controller feature, nui 1.5.0 vendored, `_chronicle.dll` 2.1.4, the keyboard work, the docs. On upstream `master` `338643d` (Chronicle 2.1.1). |
| `toboshii/nui` | `ccr-d3a8994b-5t63ba` | `6b821c8` | PadHook revisions 1 to 3, the HD decode and its fixes. On upstream `main` `8b2e53c` (nui 1.2.10 plus CI and docs). |
| both | `claude/chronicle-workstreams-review-dp0k36` | `ccr-d3a8994b-5t63ba`'s heads when last fast-forwarded | The review branch. The 2026-11-26 session worked on `ccr-d3a8994b-5t63ba`, from the review branch's heads then (Chronicle `e42d0c8`, nui `d8d94e5`). The user has the review branch fast-forwarded when they ask. On 2026-11-27 Chronicle's review branch and `ccr-d3a8994b-5t63ba` both went to `b24f027`. In nui all three branches are at `6b821c8`. Compare the heads before you rely on any of them. |
| `toboshii/nui` | `hd-texture-packs` | `871a167` | The upstream PR for the HD work: four commits, no release. Open on `jintawk/nui`, waiting for review. |
| `toboshii/nui` | `controller-pad-hook` | `79bb531` | The upstream PR for the pad hook, "Read and hold the controller the game reads", on upstream `main` `8b2e53c`. Four commits: revision 1, revision 2, the Linux tests, revision 3. It has no release commit, no HD work and no `l_screen` comment fix. It names PadHook revisions instead of the fork's release numbers, and its frozen layout is `test/frozen/layout_padhook.rev1.txt`. Open on `jintawk/nui`, waiting for review. |
| `toboshii/nui` | `keyboard-key-hook` | `db02f6c` | The upstream PR for the key hook, "Keep single keys from the game", stacked on `controller-pad-hook` (`79bb531`): its first four commits are that PR. Two commits of its own: the hook with its docs and Windows tests (`f66b72c`), and the Linux suite (`db02f6c`). Like the pad PR, it names KeyHook revisions instead of the fork's release numbers, has no release commit, and freezes `test/frozen/layout_keyhook.rev1.txt`. Its hook sources and tests match nui `8820af0` byte for byte. The user opens it on `jintawk/nui`. |
| `toboshii/nui` | `claude/hd-texture-packs` | `871a167` | A stale copy. The user deletes it. Do not use it. |
| both | `claude/controller-support-plan-yjc276` | Chronicle `867e46a`, nui `cf75bf8` | The branch before the rebase. Unchanged. `docs/test-findings-plan.md` §10 maps its hashes to the new ones. |

nui commits on the branch, oldest first:

| Commit | What |
|---|---|
| `06bb59c` | nui 1.3.0: the pad hook (PadHook 1, revision 1) |
| `6a81de5` | nui 1.4.0: the hook keeps the chord from the game (revision 2) |
| `3dc8da1` | assets: read the UI art from an HD texture pack (the user's fix) |
| `edaab6a` | nui 1.4.1: the HD decode, released with the pad hook |
| `429c39a` | test: PadHook's pure logic on 32-bit Linux |
| `d8d94e5` | nui 1.4.2: the HD atlas gets its own cache key (atlas format 3) |
| `d386009` | assets: a clear block keeps its colour when HD art is boxed down (picked from `hd-texture-packs` `3259cf9`) |
| `4c5d3a1` | test: `test/hd_linux`, the HD decode on Linux (picked from `hd-texture-packs` `871a167`) |
| `50d18a6` | nui 1.5.0: the client's XInput wrapper (revision 3), atlas format 4, the `l_screen` comment |
| `6b821c8` | test: two fixes in the Windows pad tests, found by their first run (only `test/` changes) |
| `dc45e56` | nui 1.6.0: keep single keys from the game (KeyHook 1, revision 1) |
| `8820af0` | test: the key test's status check names the exe it runs in (found by its first Windows run) |

Chronicle commits on the branch after test build 1:

| Commit | What |
|---|---|
| `c8ac1c6` | nui 1.5.0: the vendored copy and `_chronicle.dll` 2.1.4 |
| `dec423c` | pad: `//cr pad` says why when the game is not reading XInput |
| `9756f36` | docs: step 4 |
| `d4417ad` | keys: K drives the cursor from the keyboard (on `ccr-bfbc0043-hhlj8v`) |
| `5a47e40` | keys: keep the whole keyboard from the game while Chronicle holds it (test build 2 of the keyboard) |
| `542afb6` | keys: lift the keyboard block before the frame's other work (test build 3) |
| `fb65dc1` | keys: the player chooses the nav key (test build 4) |
| `62edb9f` | docs: the choosable nav key |
| `1954955` | pad: the player chooses the controller chord |
| `30f58e7` | docs: the choosable controller chord |
| `cffc161` | ui: Cancel at the root can hide the window (auto-hide) |
| `acad148` | docs: auto-hide |
| `b24f027` | docs: builds 4 to 6 work in game |
| `652a620` | docs: the handoff and the prompt for the nui keyboard hook |
| `89b0de8` | docs: how the client reads the keyboard (the research note and Lego's report) |
| `22cb958` | nui 1.6.0: the vendored copy and `_chronicle.dll` 2.1.5 |
| `9c0ab84` | keys: hide only Chronicle's keys from the game, with nui's key hook (keyboard hook test build 1) |
| this commit | docs: the keyboard hook |

Versions now: nui **1.6.0**, `_chronicle.dll` **2.1.5** (`plugin/ChronicleModule.cpp`, `kConfig`), Chronicle
**2.2.0** (`core/ident.lua`), PadHook ABI **1**, revision **3**, KeyHook ABI **1**, revision **1**, atlas format **4**.

## 3. Architecture

### Native, in nui: `src/PadHook/PadHook.h` and `src/pad.cpp`

- **Why native.** Windower 4 gives Lua no controller input at all. With its "Enable XInput" setting on,
  FFXI reads an XInput pad through its own shim, `xinputdll.dll`, which calls `xinput1_3.dll`. Otherwise it
  uses DirectInput8, which is not hooked yet.
- **The bus.** One shared hook per process, `Local\FFXiPadHook_v1_<pid>`, 4 KB, built the same way as nui's
  UiHook. The live module with the highest revision drives (its dispatcher is the one called). A module
  hands the dispatch on in `DllMain`. The thunks are in one 128-byte VirtualAlloc block that is never
  freed. With nobody driving, they pass every call through.
- **Route 1, the client's XInput wrapper (revision 3, nui 1.5.0).** The header comment of `PadHook.h` has
  the bytes.
  - The client keeps the shim's handle (H) and its `XInputGetState_` (F) in two slots in a row. One
    wrapper in `FFXiMain.dll` reads both and calls F as `__cdecl`.
  - nui finds the wrapper by a 44-byte signature, through the wrapper's fail path. It needs exactly one
    match with F = H + 4, both slots in a writable section, and wrapper + 8 on an 8-byte boundary. Once
    the client has loaded the shim, H must hold `xinputdll.dll` and F its `XInputGetState_`.
  - The patch changes `mov eax, [F]` at wrapper + 9 to `mov eax, thunk`, in one locked 8-byte
    compare-and-exchange. The client writes only its slots, so it never undoes the patch.
  - The thunk copies the two arguments and calls the `__stdcall` dispatcher. Its pass-through jumps to F.
    The dispatcher's original is a `__stdcall` adapter at block + 64, which calls F. Both read F on every
    call and test it for zero.
  - `pad()` pins `xinputdll.dll` (`padhook_pin`) the first time it finds H set. The client's unloader
    zeros only H, and the wrapper tests H before it reaches the patch.
  - The patch goes in before the client loads the shim, and also in DirectInput mode, where it does
    nothing.
- **Route 0, the fallback (revisions 1 and 2).** The Windows hot-patch form at
  `xinput1_3.dll!XInputGetState`: `E9 rel32` into the 5 bytes of padding, then `8B FF` becomes `EB F9` in
  one locked 16-bit compare-and-exchange. The original is `site + 2`. Any other entry is refused, and the
  bytes found are reported. nui never loads `xinput1_3.dll` itself.
- **Which route.** A revision 3 module tries route 1, then route 0. `PadBus::route` says which one is live
  (zero is route 0, which is what a revision 2 module leaves). `bus->blocked` means route 0 is refused for
  good. Revision 3 reports `blocked` only when route 1 is refused for good too. Until then `pad_start()`
  asks to be retried. A revision 3 module clears `blocked` when route 1 succeeds, also when a revision 2
  module set it.
- **What the dispatcher does** (`dispatch`, `record`, `apply_chord`, `apply_mask`), unchanged since
  revision 2:
  1. It calls the original.
  2. It records the raw state per user index behind a seqlock.
  3. It applies the chord step. This runs only for the user index that last read a connected pad.
  4. It applies the shared mask:
     - While any live client holds the pad, new presses are hidden, the sticks are zeroed, and the
       triggers are zeroed unless they were held from before.
     - "Held from before" means what the game's last output already showed as pressed (`last_out`).
     - A hidden press stays hidden until it is released, even after the pad is given back.
     - `dwPacketNumber` is renumbered, so it changes exactly when the output changes.
     - A hold lapses if the client does not renew it for 250 ms (`PADHOOK_HEARTBEAT_MS`).
- **The chord** (revision 2, `PadChord` in the bus header's reserved tail, `PadClient.chord`):
  - While nobody holds the pad, the first chord button down is held back for up to `PADHOOK_CHORD_MS`
    (150 ms).
  - If its partner arrives in time, that is the chord: both are hidden until released.
  - If it is released alone in time, the game sees the press for `PADHOOK_REPLAY_READS` (2) reads.
  - If it is still held alone after 150 ms, the game gets it.
- **Lua API** (`pad.hpp`, registered in `host.cpp`'s table): `pad_start([flags])`, `pad()` (10 numbers,
  no table, and the heartbeat), `pad_capture(on)`, `pad_chord(mask)`, `pad_config()` (`padmode000` and
  `padsin000` from `HKLM\SOFTWARE\PlayOnline{US,EU,}\SquareEnix\FinalFantasyXI`, 32-bit view),
  `pad_status()` (since 1.5.0 with `route`, `shim` and `pinned`), and `pad_stop()`. `stop()` calls
  `pad_release()`, and `host_detach` calls `pad_detach()`.
- **Frozen layout.** `test/layout_padhook.txt` is the live layout, and `test/frozen/layout_padhook.1.3.0.txt`
  is frozen. `test/frozen_check.py` checks the pair. Revisions 2 and 3 only added fields into reserved
  tails, so only `reserved*` lines moved. Keep that rule: append only, and zero means the old behaviour.
- **DirectInput later.** `PadState::source` reserves `PADHOOK_SRC_DINPUT`. The mask works on one button
  word in XInput's layout, with LT and RT as bits `0x10000` and `0x20000`.

### Native, in nui: `src/KeyHook/KeyHook.h` and `src/key.cpp` (nui 1.6.0)

- **Why native.** Windower's `keyboard` event cannot keep a key from the game, and `keyboard_blockinput` keeps every key
  and stops Windower's binds. The research is `docs/keyboard-hook-research.md`, and Lego's report with every byte is
  `docs/keyboard-client-report.md`.
- **The client.** One function reads the DirectInput keyboard once per main loop tick on the main thread:
  `GetDeviceState` (256 bytes) at `0x10005A86`, then `GetDeviceData` (16 events, no peek) at `0x10005B1D`, in the
  2026-11-02 build. A key counts as down from its state byte or a press event. With Windower, the device is Windower's
  keyboard wrapper (`Hook.dll`, `windower::direct_input_keyboard`), which applies its block, console key and binds
  first.
- **The bus.** `Local\FFXiKeyHook_v1_<pid>`, 4 KB, frozen as `test/frozen/layout_keyhook.1.6.0.txt`. The same rules as
  PadHook: one patch per process, the live module with the highest revision drives, a module hands the dispatch on in
  `DllMain`, and the thunks are in one 128-byte block that is never freed.
- **The sites.** The instruction after each read is `cmp eax, 0x800700AA`. Two signatures (45 and 42 bytes, from the device
  load to the `cmp`) must each match once in `FFXiMain.dll`'s code. Both must load the device from the same offset,
  the event read must follow within 1 KB, and each `cmp` must lie in one aligned 8-byte block (`0x10005A89` is 8n+1,
  `0x10005B20` is 8n+0). Lego checked both signatures against the real image: one match each, in `.text`.
- **The patch.** Each `cmp` becomes `call thunk` (same length), in one locked 8-byte compare-and-exchange. The thunk
  saves eax, ecx and edx, calls the dispatcher with `(kind, hr, data, count, asked, device)` (`__stdcall`), restores
  them, runs the client's own `cmp` and returns with `ret`, which keeps the flags. The device is `[esi+disp]`, the
  state buffer `edi`, the events `ebx`, the count `ebp`: the signatures fix those registers. The thunk chains
  nothing, because the read has already run.
- **The press rules** (`apply_state`, `apply_events`), one record per key for both reads (`saw`, `hid`):
  - The dispatcher decides a new press once, at the first read that shows it, from the union of the live clients'
    masks.
  - A press the game saw stays the game's, and a hidden press stays hidden, until its release event.
  - A lost release ends a press once the state shows the key up and an event read returns fewer events than asked.
  - When a module starts to drive after nobody did (`set_owner`), the next state read gives every held key to the game
    (`KeyState.primed`).
  - A mask lapses 250 ms after its last `key_hide` (the heartbeat).
- **Lua API** (`key.hpp`): `key_start([flags])`, `key_hide(code, ...)` (the codes as arguments, because nui binds no
  `lua_rawgeti`, so Lua passes `unpack(list)`), `key_status()` (with `device`, the module of the device's vtable) and
  `key_stop()`. `stop()` calls `key_release()`, and `host_detach` calls `key_detach()`.
- **What it does not see.** The chat line reads Space, `/` and typed text from `WM_KEYDOWN` and `WM_CHAR`.

### Lua, in Chronicle

| File | Role |
|---|---|
| `ui/pad.lua` | A pure decoder. Its fast path costs nothing on idle frames. Raw state becomes actions: directions (D-pad or left stick, with hysteresis and auto-repeat), Confirm/Cancel (from `pad.from_config`, so a game layout with Confirm on B swaps them), `tab_prev`/`tab_next`, `page_up`/`page_down`, `sort`, `filter`, `settings`, `collapse`, `top`, `toggle`. It also returns a right-stick scroll amount. `latch()` makes buttons held at take-over act only after their release. |
| `ui/nav.lua` | Pure spatial navigation over the hits that screens already register. Head targets are chrome hits plus the sticky tab bar. Body targets are content hits. Resize grips, `noop` and `sticky_bar` are skipped, and a wrapped link (one `span`) is one target. `nav.key` gives a hit's identity without coordinates. Target lists are memoized per builder in a weak table. |
| `ui/window.lua` | The cursor, in the "controller" section at the bottom of the file: `pad_mode`, `cursor`, `cursor_key`, `cursor_zone`. The cursor is the hover, so the existing hover drawing shows it. `pad_draw` adds a frame, and the hint line is in the bottom margin. `pad_refind` runs after each layout. `pad_move` is spatial, crosses between head and body at the edges, and steps by a third of the viewport on sparse pages. A mouse move of more than 3 px over the window gives the hover back to the mouse. |
| `core/app.lua` | `App:go` pushes `cursor = win.cursor_key` onto the stack, and `App:back` passes it to `on_change`, then `set_screen`. |
| `chronicle.lua` | The section "The controller": `padc`, `pad_read_config`, `pad_join`, `pad_take`, `pad_give`, `pad_act`, `pad_tick` (run from `prerender`), `pad_no_shim`. |
| `ui/screens/settings.lua` | The rows "Controller", "Controller buttons", "Keyboard", "Keyboard key" and "Hide on Back". |
| `ui/keys.lua` | Also tracks Ctrl and Alt (`keys.shift()`, `keys.ctrl_alt()`), for the keyboard driver. |
| `chronicle.lua`, "The keyboard" | `kbd`, `KEY_ACT`, `kbd_take`, `kbd_give`, `kbd_down`, `kbd_tick`, `kbd_reset`. The `keyboard` event runs the search box first, then the driver. |
| `README.md` | The section "With a controller", and the controller paragraph of "The native layer". |

`chronicle.lua`'s controller code does this:
- **Joining:** it reads the game's pad config once, then joins on the first frame. On route 1 that works at
  once. On route 0 it retries every 5 s while `xinput1_3.dll` is not loaded. Then it calls
  `pad_chord(mask)` with the player's chord (L3 + R3 by default). Since `dec423c`, `//cr pad` does not take the pad while route 1 is live and the client
  has not loaded its shim. It says why instead: Enable XInput is off, or the shim is not loaded yet.
- **Taking and giving back:** without the pad, it only watches for the chord edge. With it, it dispatches
  actions. It gives the pad back on Cancel at the root, on hide, logout and lose focus, and on `//cr pad`.
- **After a stall:** a hold that lapsed is taken again, with the held buttons latched.
- **Setting:** `pad = true` by default.
- **Command:** `//cr pad [on|off|status]`. Status lines are also added to `//cr status`.

The keyboard driver (`d4417ad`) does this:
- **One cursor, two holds.** `W:pad_enter(hint, who)` and `W:pad_leave(who, other_hint)` keep a holder per input
  (`'pad'`, `'keys'`). The cursor goes only when neither holds it. `nav_act(a, give, hint)` is the action map for
  both inputs, so Cancel at the root gives back only the input that pressed it. The hint line follows the input
  that acted last (`W:pad_hint_for`).
- **Taking and giving back:** K, or `//cr nav`. K shows the window if it is hidden, as the chord does. The keys go
  back on K, on Escape or Backspace at the root, on hide, logout, unload and lose focus, on `//cr nav`, and when the
  setting goes off (`nav = true` by default, `//cr nav on|off`).
- **The keys:** the arrows move, and Enter opens. Backspace and Escape go back. Tab and Shift + Tab change section.
  Page Up and Page Down page. Home and End go to the top and the bottom (`bottom` is a new action).
- **A press:** `kbd.game` records each press the game saw. Its repeats and its release stay the game's.
  `kbd.took` records each press the driver took. Its repeats and its release stay Chronicle's, even after the keys
  go back or the search box takes focus. The driver clears both on lose focus and gain focus, because a key released
  elsewhere never sends its key-up.
- **What is never taken:** a new press while the chat line is open (`get_info().chat_open`), with Ctrl or Alt held,
  or while the module does not draw (review LIFE-4). The focused search box comes first.
- **Keeping keys from the game (`5a47e40`).** In game, on 2026-11-27, returning `true` from the `keyboard` event
  kept no key from the game. The arrows turned the camera even on a tap, and Page Up and Page Down zoomed it. Home
  and End do nothing in the game. Letters typed in the search box opened the game's menus, so the search box had
  this bug before the driver too. Two things did keep keys from the game: `keyboard_blockinput 1` (all keys), and
  a Windower bind (its key only). Under `keyboard_blockinput 1` the `keyboard` event still fires, and the cursor
  moves. The user chose the whole-keyboard block, because Chronicle cannot read or restore a player's own binds.
  `kbd_block` turns it on while the keys are held or the search box has focus, on a window that draws. It
  changes only while no key is down (`kbd.down`, `kbd.ndown`). It waits at most 0.5 s to start
  (`BLOCK_WAIT_ON`) and 2 s to end (`BLOCK_WAIT_OFF`). Losing focus and unloading lift it at once.
- **The nav key (`fb65dc1`).** `settings.nav_key` (default `'k'`) names it, and `keys.parse` reads names such as
  `ctrl+n`, `f10` and Windower's `^n`. Ctrl and Alt must match exactly. Shift may be held for a key without Shift.
  A key that moves the cursor needs a modifier. The Settings row "Keyboard key" sets `kbd.capture`, and the next
  key pressed becomes the key. Escape cancels, and the keyboard is blocked while Chronicle waits. `//cr nav key
  <name>` sets it too. A bind for `//cr nav` cannot end nav mode under the block, so this is the way to use another
  key.
- **The key hook (`9c0ab84`).** `kbd_hook_join` joins on the first frame. `kbd_hide_sync` sends the list every frame
  while it holds keys, and after every key event, so a change made by a key (K, Ctrl, Alt) is in place for the game's
  next read. The list (`kbd_hide_want`, as bits): the nav key when its own Ctrl and Alt match, the nav keys while
  `kbd.held` with neither Ctrl nor Alt on a window that draws, and Escape while `padc.wait`. Nothing new while the chat
  line is open (`kbd_chat`, asked on each key and at most every 0.1 s from prerender). With the hook, `kbd_want_block`
  blocks only for the search box and `kbd.capture`. Without it (no `key_start`, or a refusal), it blocks as before.
  `kbd_status_lines` (`//cr nav status`, and in `//cr status`) names the way and the reason. Lose focus empties the
  list at once.
- **Repeat:** a held arrow repeats on Chronicle's own clock, with the pad's delay and rate. Windower's repeated
  key-downs, if any, move nothing.

The controller chord (`1954955`) does this:
- **The setting.** `settings.pad_chord` (default `'l3+r3'`, per character) names two buttons. `pad.parse_chord` in
  `ui/pad.lua` reads names such as `lb+rb` and `back+start`, and gives the mask, a fixed-order name and a label
  (`LB+RB`). `pad_chord()` in `chronicle.lua` parses it again whenever the setting changes. A name that does not
  parse falls back to L3 + R3. A new chord goes to the decoder (`D:set_chord`), to `pad.chord_conflicts`, and, once
  joined, to `nui.N.pad_chord(mask)`.
- **What nui's hook can hold.** `l_pad_chord` takes any mask in `0x3FFFF` (18 bits), and `apply_chord` takes any
  number of bits. But `apply_mask` applies the chord step's `hide` and `force` only to the low 16 bits (the XInput
  button word). A trigger (`0x10000`, `0x20000`) is never held back, so the game would see it go down before its
  partner. So the parser refuses LT and RT. It also refuses the D-pad (it moves the cursor), a button twice, and
  anything but two buttons. Guide is not in what `XInputGetState` reports, so it has no name. Allowed: L3, R3, LB, RB,
  Back, Start, A, B, X, Y. Nothing under `plugin/` changed.
- **The decoder.** The toggle is the edge of both chord buttons held. A chord button alone acts on its release, and
  not at all once its partner is held (the old `r3_alone` rule, for both buttons). So with L3 + R3, R3 alone is
  still Top on release and L3 alone does nothing, exactly as before. With LB + RB, LB alone is `tab_prev` on its
  release. R3 out of the chord is Top on press.
- **Text.** The hint line, the first-take chat line, `pad_status_lines` ("ready (LB+RB)", "LB/RB also mapped") and
  the old-DLL conflict line name the chord. `pad.chord_conflicts(cfg, mask)` checks the padsin ids that are known
  (0 B, 1 X, 2 Y, 3 A, 10 L3, 13 R3). The ids of LB, RB, Start and Back are not confirmed, so a chord with them is
  not checked.
- **The Settings row "Controller buttons".** A click, or Confirm on it, calls `pad_wait_start`. It says so and does
  not wait when the controller is off or not joined. Otherwise it sets `padc.wait` and calls `pad_capture(true)`.
  `pad_tick` then feeds `pad_wait_tick` instead of the decoder. Buttons held at the start (the Confirm that chose the
  row) count only once released. The first frame with two new buttons held ends the wait: the pair becomes the chord,
  or chat says why it is refused and names the old chord. Three at once are refused. Escape (kept from the game, and
  the keyboard is blocked while it waits), Cancel pressed and released alone, a second click, or `PAD_WAIT_S` (5 s)
  with no press keeps the old chord. A press starts the 5 s again. `pad_give` (hide, lose focus, off) ends the wait.
- **Held buttons around the wait.** The hook's rules do the work, as for `pad_take` and `pad_give`: a press the game
  saw stays the game's, and a press made under the capture stays hidden until released, also after
  `pad_capture(false)`. `pad_wait_end` gives the pad back only if Chronicle does not hold it for the cursor. If it
  does, it latches what is held, so the new chord's buttons do not act on release. `padc.prev` takes the held
  buttons, so the chord still held does not take the pad. A lapsed hold is taken again during the wait.
- **Command:** `//cr pad chord [name]` names the chord, or sets it.

Auto-hide (`cffc161`) does this:
- **The setting.** `settings.auto_hide` (default `false`, per character). With it off, nothing changes.
- **Where it acts.** Only in `nav_act`'s `cancel` branch, where `win:pad_back()` returns `'root'`. That is the pad's
  Cancel (B, or the game's own Cancel from its pad config), or Escape or Backspace from the keyboard. With the setting
  on, that branch calls `hide()` instead of the input's own `give`. `hide()` calls `pad_give` and `kbd_give`, so both
  inputs go back, also when only one of them pressed Cancel. No window stays to hold them, so both must go back.
- **What does not hide.** A Cancel that closes a picture, leaves the search box or goes back a screen (`pad_back`
  returns nil). The chord and the nav key (`toggle`, `kbd_give`), `//cr pad`, `//cr nav`, and Escape or Cancel while a
  Settings row waits for a key or for two buttons. Those paths never reach the `cancel` branch.
- **The pad's press rule.** Nothing new in Lua. `pad_give` calls `pad_capture(false)` while Cancel is still down. The
  hook keeps a press made under the capture hidden until its release, so the game never sees that Cancel. The hook
  must stay installed for this, so the hide must not call `pad_stop`.
- **The keyboard's press rule.** Nothing new in Lua either. `kbd_give` calls `kbd_block`, which waits while a key is
  down (`kbd.ndown`). So `keyboard_blockinput 0` goes out with the Escape or Backspace release, not at the hide.
- **After the hide.** The chord and the nav key show a hidden window and take their input, as before.
- **The row and the command.** The Settings row "Hide on Back" (On or Off) follows "Keyboard key", at the end of the
  input rows. So only "Place and size" moves down 34 px. "Back" is the word the hint line uses for Cancel ("B Back",
  "Bksp Back"). `//cr autohide` toggles it, and `//cr autohide on|off` sets it. No other command had that name.

Button layout: the D-pad or left stick moves the cursor. A is Confirm and B is Cancel, unless the game's
config says otherwise. LB/RB change section, LT/RT page, the right stick scrolls, X is Sort, Y is Show,
Start is Settings, Back collapses, R3 alone goes to the top, and L3 + R3 takes or gives back the pad.

## 4. Verification status

| What | Status |
|---|---|
| In game: navigation, taking and giving back the pad | **Works**, by the user's report (nui 1.3.0 build) |
| In game, test build 2 (`_chronicle.dll` 2.1.4, nui 1.5.0), on the machine where route 0 refused | **Works**, by the user's report of 2026-11-27. `//cr pad status` says `live at FFXiMain's XInput wrapper`, at a different address on each launch (the client module moves, and the signature finds it). With Enable XInput off, it adds that the client has not loaded `xinputdll.dll` yet, and `//cr pad` says so. With a controller, `reads` goes up and the controller works. L3 + R3 takes the pad without sitting the player or moving the camera. An L3 tap still sits, and R3 held still changes the view. A pad plugged in after the start still works. The mouse lands right at UI Scale 1.5. The HD art draws at login with an addon on nui 1.2.10 loaded. |
| Chronicle `test/test_pad.lua` | 100 passed, 0 failed (also at `d4417ad`) |
| Chronicle `test/test_keys.lua` (new at `d4417ad`, in CI) | 112 passed, 0 failed at `5a47e40` (90 at `d4417ad`). Build 2 adds BLOCK-0 to BLOCK-11, one per rule of the block, and each fails without its rule. Each rule has named checks (KEYS-R1 a press the game saw, KEYS-R2 a press Chronicle took, KEYS-S the search box, KEYS-C the chat line and Ctrl, KEYS-E the ways out, KEYS-T two holds, KEYS-D not drawing). Each rule was removed in turn, and its checks failed each time. |
| Chronicle `test/qa_render.lua`, `36a7467` against `d4417ad` (the keyboard driver) | **Only the Settings shots differ**, on 2026-11-27 on Lego, with the same inputs and the same 12-page sample as the run below. Both trees drew 220 shots (660 raw frames). 654 of 660 frames are identical. The 6 that differ are `settings.*.full` and `.content`, inside y 270 to 357. There the new row "Keyboard (K)" sits at y 270, and "Place and size" moves from y 270 to 304. In the manifests, only the 3 Settings shots differ: `content_h` goes from 280 to 314, and the Settings text has 2 more entries. Both trees hold the same `_chronicle.dll` (`NUI-TAG:1.5.0:0452179ed6c4`). |
| In game: the keyboard driver, build 1 (`d4417ad`) | K takes and gives back the keys, and the cursor moves. **But the game still got every key**, as above. |
| Chronicle `test/test_chord.lua` (new at `1954955`, in CI) | 99 passed, 0 failed. CHORD-1 the setting and the command, CHORD-2 the parser, CHORD-3 its refusals, CHORD-4 the fallback, CHORD-5 the edge test and the decoder's toggle, CHORD-6 the hook's mask, CHORD-7 the hint, status, chat and Settings text and the conflict check, CHORD-8 R3 and Top, CHORD-9 to CHORD-14 the Settings row (two buttons, Escape, Cancel, the timeout, a refused pair, not joined), CHORD-15 the held-button rules around the wait. 39 rules were removed in turn, and each made a named check fail. Removing the D-pad, trigger or unknown-name refusal also stops the run in the command check, because the sort then compares a nil rank. `test_pad` 100 and `test_keys` 139 still pass unchanged. |
| In game: the choosable controller chord (`1954955`, test build 5) | **Works**, by the user's report of 2026-11-27. Every check on the agent's list passes. |
| Chronicle `test/test_autohide.lua` (new at `cffc161`, in CI) | 94 passed, 0 failed. HIDE-1 the setting, its default, the row and a saved value, HIDE-2 off as before, HIDE-3 the pad's Cancel hides (also the game's own Cancel on A), HIDE-4 Escape and Backspace hide, HIDE-5 a Cancel that goes back, closes a picture or leaves the search box does not, HIDE-6 the chord, the nav key, the commands and the waiting Settings rows do not, HIDE-7 the pad's Cancel stays from the game until its release (the test models the hook's rule), HIDE-8 the keyboard block lifts only with the key's release, HIDE-9 both inputs held, HIDE-10 showing again, HIDE-11 the command and the help line. 22 rules were removed or broken in turn, and each made a named check fail. `test_pad` 100, `test_keys` 139 and `test_chord` 99 still pass unchanged. `test_screens` gives 18,395 passed and the same 4 Linux failures as before. |
| In game: auto-hide (`acad148`, test build 6) | **Works**, by the user's report of 2026-11-27. Every check on the list passes. |
| nui `sh test/key_linux/run.sh --self-test` (32-bit Linux, `dc45e56`) | logic 53, sites 36: all pass, with the client's real read bytes executed through the patch, and the stack, registers, eax and flags checked after each `cmp`. 8 faults caught (NO_HEARTBEAT, TAKE_HELD, LEAK_HELD, NO_EVENTS, NO_DRAIN, NO_PRIME, NO_CMP, FIRST_MATCH). |
| nui `sh test/build_key_test.sh --self-test` (Windows, on Lego, `dc45e56`) | main 35/0, nomatch 6/0, all 6 faults caught. The run found one test bug: the STATUS check failed in every fault build, so a fault that changes nothing would also have counted as caught (fixed in `8820af0`, test only). Each fault was caught by its own checks as well. The pad suite (7 modes, 8 faults) and `hook_test.exe` (101/0) are unchanged. **At `8820af0`:** main 35/0, nomatch 6/0, all 6 faults caught by their own checks (NO_HEARTBEAT by KEY-13, TAKE_HELD by KEY-3 and KEY-15, LEAK_HELD by KEY-4 and R2, NO_EVENTS by KEY-2, KEY-4, KEY-5 and R2, NO_CMP by JOIN and LEAVE, NO_PRIME by KEY-15 and R2), and a build with no fault named `key_fault.exe` passes 35/0. |
| Lego: the two signatures over the real 2026-11-02 image | One match each, in `.text`. Device offset `0x88`, 16 events asked, the `cmp`s at `0x10005A89` (8n+1) and `0x10005B20` (8n+0), each inside one aligned block. |
| Chronicle `test/test_keys.lua` at `9c0ab84` | 179 passed. HOOK-0 to HOOK-17 cover the hook path, and the BLOCK checks the fallback (the fake DLL refuses the hook unless a test asks for it). 18 rules were removed in turn, and each made a named check fail. The CI suites, `test_pad` and `syntax_check` (3,115 files) pass. `test_screens`: 18,395 passed, the same 4 Linux failures. |
| In game: keyboard hook test build 1 (`9c0ab84`) | **Works**, by the user's report of 2026-11-27. Every check on the 14-step list passes but one, and that one was a test of the other order. The user held Down outside nav mode, so the camera was already turning, and then pressed K. The camera kept turning until Down was let go, and then Down moved Chronicle's cursor. That is the designed rule: a press the game saw stays the game's until its release, as the README says and as for the pad's buttons. The user chose to keep it (nui could give held nav keys to the game as released, as the pad hook centres the sticks, in a KeyHook revision 2). The checklist's own order works too, by the user's report: start in nav mode, hold Down, press K, let go, and the camera never moves. Passed: the hook is live with `device Hook.dll`, the arrows and Page Up/Down move only the cursor, Enter opens nothing in the game, Space and `/` open the chat line and Enter sends it, macros, F keys and a bind for `//cr nav` work, the search box opens no menu and no chat line, and switching window and unloading give the keys back. |
| QA frames after builds 4 to 6 | Not run, by the user's choice. Builds 4 to 6 add Settings rows ("Keyboard key", "Controller buttons", "Hide on Back") and rename two ("Keyboard", "Controller"). So the Settings frames differ from the last comparison, and no other screen's drawing changed. |
| In game: build 4 (`fb65dc1`), the choosable key | **Works**, by the user's report of 2026-11-27. Ctrl+N set from the Settings row takes and gives back the keys under the block, and Escape keeps the old key. `test_keys` has 139 checks, and each rule of the key was removed in turn and caught. |
| In game: the keyboard driver, build 2 (`5a47e40`) and build 3 (`542afb6`, on a second machine) | **Works**, by the user's report of 2026-11-27. Every check passes: the arrows and Page Up/Down no longer move the camera, a letter typed in the search box opens no game menu, and the game gets its keys back as soon as Chronicle gives them back. One limit: under the block, Windower runs no bind, so a bind for `//cr nav` starts nav mode but cannot end it. K, and Escape or Backspace at the root, still end it. The README says so. |
| Chronicle's CI suites at `d4417ad` (`test_doc`, `test_input`, `test_keys`, `test_mission_words`, `test_steps`, `test_roe`, `test_complete_strip`, `test_progress_ui`, `test_progress_lists`, `test_pages`) and `test/syntax_check.lua` | All pass (3,113 files compile) |
| `test/test_screens.lua` (also at `d4417ad`) | 18,395 passed, 4 failed. The same 4 fail on the base commit, because of the Linux environment: "resize saved the place", "place restored", "pictures in view to check", "a texture freed under a layout...". |
| `test_core`, `test_data`, `test_load`, `test_progress` | Not run here. They need a v1 worktree, the real DLL, or Windows. |
| nui `sh test/pad_linux/run.sh --self-test` (32-bit Linux) | logic 19, chord 19, wrapper 54: all pass. The route 0 thunk in the client's slot dies with SIGSEGV once a dispatcher drives, as it must. Both route 1 faults are caught. |
| nui `sh test/hd_linux/run.sh` | 84 passed |
| nui `python3 test/frozen_check.py` and `--self-test` | Pass |
| nui `NUI_GXX=i686-w64-mingw32-g++ sh example/build.sh` | Builds |
| nui `sh test/build_pad_test.sh --self-test` (Windows: both routes, a stand-in client and shim, a real revision 2 module, 8 fault builds) | **Passes on Windows**, on 2026-11-27 at `6b821c8`, with MSYS2's 32-bit gcc 16.2: main 73, nomatch 6, both 8, r2first 9, foreign 6, nohot 10, wrapper 96, all 0 failed, and all 8 faults caught. A session on the user's Windows machine ran it, because Wine fails at startup in the cloud container. Its first run, at `50d18a6`, found two bugs in the tests and none in PadHook. |
| nui `test/hook_test.exe` (from `test/build_test.sh`) on a plain copy of the installed `FFXiMain.dll` | **Passes on Windows**, 101 of 101, on 2026-11-27 at `6b821c8`. The copy's own DllMain decrypts its code when the test loads it, and the `EndScene` wrapper is at rva `0x9740`, as in game. So for this client build (2,905,680 bytes, SHA-256 `d809ebe3...48fb`) a plain copy in a scratch folder is the "unpacked copy" the suites need. |
| nui `sh test/build_render_test.sh --self-test` (Windows, stock install, at `6b821c8`) | **22 or 23 of 24 tests pass, and the 40 faults are all caught.** Every atlas, icon and picture golden hash matches, at atlas format 4, so the HD work changed no stock pixel. Two tests fail, and neither is the branch's doing. (1) `wt`: 7 of the 8 window frame crops differ from golden on every run. Upstream's `8b2e53c` gives the same 7 hashes on the same machine, so golden's frame hashes do not hold on that hardware (AMD Radeon Phoenix iGPU, driver 32.0.23044.19, Windows 11 IoT LTSC 24H2, `d3d8.dll` 10.0.26100.9278). (2) `pd`: its first-load timing check missed its limit on 2 of 3 cold first runs (11.0 and 11.8 ms against about 10.5 ms), and passes on reruns. The self-test ran from a local copy of the script that does not stop at the normal run's failure. |
| nui `sh test/build_test.sh --self-test` (Windows, at `6b821c8`) | **Every suite passes but render**, whose failures are the machine's `wt` hashes and `pd` timing above. The script stops at render (`set -e`), so the build-path suite and the pad suite ran directly. sync check ok, frozen layouts unchanged, `hook_test` 101/0, `hook_matrix` 79,980/0 over 9 scenarios, cache 13 of 13 tests, build path all pass, pad 7 modes pass. Self-tests: frozen pass, UiHook 11 of 11 faults caught, cache 19 of 19, build path 17 of 17. No CRASH, NOT CAUGHT or WRONG CHECK line in any run. |
| Chronicle `test/qa_render.lua`, upstream `338643d` against the branch `fc19479` | **Only the Settings shots differ**, on 2026-11-27 on the user's Windows machine. `qa.py` and the approved frames are not in the repository, so the approval gate could not run. Instead both trees drew the same 220 shots (12 pages, every screen, 3 window sizes, 660 raw frames) through the real DLL, and the frames were compared byte for byte. 654 of 660 are identical. The 6 that differ are `settings.*.full` and `.content`, where the branch adds the row "Controller (L3+R3)" and the rows below it move down 34 px. The manifests differ only in those 3 shots. Not covered: pages with pictures, because the offline harness has no picture cache (301 of 1,915 pages have one). |

## 5. Working here (a Linux cloud container)

- **Toolchain.** `apt-get update`, then `apt-get install -y g++-mingw-w64-i686 lua5.1 g++-multilib`.
- **The DLL.** `sh plugin/build.sh` from the Chronicle root. Check it with
  `python3 sync.py check --dll ../ffxi-chronicle/libs/_chronicle.dll` from nui. Two builds of the same
  source differ in many bytes, so compare the `NUI-TAG` string and the git blobs, never the bytes.
- **Lua tests.** `export TEMP=<scratch dir>` first, then `lua5.1 test/<name>.lua` from the Chronicle root.
  The harness's Windows-only `>nul` leaves a file named `nul` in the repo root. Delete it, and never commit
  it.
- **Syncing nui into Chronicle.** `sync.py` resolves consumer paths from the directory above the nui
  checkout's parent (`/home` here). So add `user/ffxi-chronicle/plugin/nui` to `consumers.txt`, run
  `python3 sync.py release <v>` or `sync`, then `git checkout consumers.txt`. Never commit that line.
- **Releasing nui.** `python3 sync.py release <x.y.z>` writes `VERSION`, `RELEASES` and
  `src/nui_version.h`, then syncs. Rebuild the DLL after, and bump the version strings in
  `plugin/ChronicleModule.cpp`, `test/harness.lua` and `test/test_load.lua`.
- **Pushing nui:** `git -c push.negotiate=true push`. The proxy refuses branch deletes with a 403.
- **A test zip for the user.** `git archive --format=zip --prefix=chronicle/ -o <zip> HEAD` from the
  Chronicle root. The user unzips it over `Windower/addons/chronicle`. The DLL and the Lua files must go
  together.
- **Windows runs.** Wine does not start in the cloud container. The user's Windows machine ("Lego") runs a
  Claude Code session named "Remote control". A cloud session can message it with `send_message`, after the
  user allows that cloud session to reach their own computers (`confirm_repository_trust`). Lego has MSYS2
  at `C:\msys64` with the 32-bit gcc 16.2 (`pacman -S mingw-w64-i686-gcc`), Lua 5.1.5 from LuaBinaries at
  `C:\Program Files (x86)\Lua\5.1\` (it ships `lua5.1.exe`, so set `NUI_LUA` to it), and a plain copy of
  `FFXiMain.dll` for `NUI_FFXI_COPY`. Windower 4 is at `C:\Windower4`, and the game install is stock. Ask
  that session to check with the user before it installs anything.
- **Commit style.** Both repositories use "area: a plain sentence" subjects (`pad:`, `nui 1.x.y:`,
  `docs:`), and wrapped bodies that say why. The author is Toboshii Nakama, with no trailers. `docs/` is
  in Chronicle's `.gitignore`, so files there are force-added (`git add -f`).

## 6. What is left, in rough order

1. **Test build 2 in game: done.** Every check on the retest list works, by the user's report (§4).
2. **Upstream's render test, for jintawk.** These come from the Windows run and are in upstream's test code,
   not in this branch:
   - `wt`'s frame crop hashes depend on the machine. 7 of 8 differ on the user's AMD iGPU with upstream's
     own code.
   - `pd`'s first-load timing sits at its limit on a cold first run on that machine.
   - `pd` fails (4 checks, decode time 0) when `wt` or `fr` runs before it in the same process
     (`--only wt,pd`, `--only fr,pd`). It passes alone and in the full run.
   - gcc 16 warns "null character(s) preserved in literal" at `test_render.cpp:1783`, where the literal
     holds raw NUL bytes. `"\0\0\0\0IDAT"` would say the same.
   - gcc 16 warns that `random_merge_list` (`test_build.cpp:450`) and `check_merge` (`test_build.cpp:354`)
     are defined but not used. The merge checks still run, so they look like dead code.
3. **The two nui pull requests, both open.** Both add a CI step and a README test paragraph in the same place
   (`.github/workflows/build.yml` and `README.md`). Whichever merges second needs a rebase onto upstream
   `main`, and `abi.md` merges cleanly. If the HD PR merges first, rebase `controller-pad-hook`. Answer
   review comments on the user's behalf only when the user asks.
4. **After both merge,** Chronicle should vendor an upstream nui release instead of the fork's 1.6.0. The fork's
   release numbers (1.3.0 to 1.6.0) give way to upstream's then, so agree on that with the user. DLLs built
   on the fork's revisions 1 to 3 stay compatible with upstream's, because the bus and its frozen layout are
   the same.
5. **A Chronicle pull request** to `jintawk/ffxi-chronicle`, only when the user asks, and only once Chronicle
   can vendor an upstream nui release that has the pad hook. Use a new branch with no `claude/` or `agent/`
   prefix, and leave the plans and handoffs (`docs/`) off it, as for nui.
6. **The keyboard driver: built and works in game**, with the choosable nav key, the choosable controller chord
   and auto-hide (§4). The QA frames matched at `d4417ad`. The user chose not to run them again after builds 4 to
   6, which change only Settings rows.
7. **The keyboard hook: built and works in game** (§3, §4). A held arrow keeps turning the camera when K takes the
   keys, until it is let go. The user chose to keep that rule. The upstream PR branch is `keyboard-key-hook`, stacked
   on `controller-pad-hook`. GitHub cannot stack a PR on a branch of the fork, so the upstream PR shows the pad
   commits until the pad PR merges. If the pad PR is squash-merged, rebase `keyboard-key-hook` onto `main`.
8. **After it,** from `docs/test-findings-plan.md` §7: the player's own key bindings and a main menu item. The
   research settled the input mask: it gates action categories, not keys (`docs/keyboard-hook-research.md` §1.6).
   The key bindings matter less now that the hook hides only Chronicle's keys, but the nav key can still clash with a
   key the player bound in the game. The research found the action bindings table (`0x1036E6E8`, up to three
   bindings per action), which is a start.
9. **Optional:** DirectInput as a second PadHook source, QA frames for controller mode, and moving and
   resizing the window from the pad.
10. **Small loose ends:**
   - With Enable XInput off, the first field of the controller line in `//cr status` still reads "ready
     (L3+R3)", or the chosen chord. `//cr pad` gives the right message, so this is cosmetic.
   - nui's `example/README.md` says a straight copy of `FFXiMain.dll` will not do as `NUI_FFXI_COPY`. A plain
     copy works for the 2026-11-02 client.
   - The `l_screen` comment fix in `src/host.cpp` is only in the fork's 1.5.0, not in either pull request.
   - `claude/hd-texture-packs` is stale. The user deletes it, because the proxy refuses branch deletes.
   - `test_pad` is not in Chronicle's CI loop. `test_keys`, `test_chord` and `test_autohide` are.
   - The chat line reads typed text from window messages. A filter there (a message hook on the game's thread)
     would let the search box use the key hook instead of `keyboard_blockinput`. The user chose to keep the block
     for the search box for now. Where Windower raises its `keyboard` event is not known, and a message filter
     must not hide a key from it.

## 7. Facts from the research worth keeping

From the keyboard research (2026-11-27, `docs/keyboard-hook-research.md`):
- The client reads the keyboard in one function, once per tick: `GetDeviceState` then `GetDeviceData` (16 events).
  It ignores release events.
- Windower 4's `Hook.dll` wraps the keyboard device and filters the same two reads (block, console key, binds).
- The chat line takes Space (`WM_CHAR`), `/` (`WM_KEYDOWN`) and typed text from window messages. Enter and Escape
  come from the DirectInput press edges.
- `FUN_10124b70` sets a mask of action categories. It cannot hide one key.

Found in game on 2026-11-27, with test builds 1 to 3 of the keyboard driver:
- A `true` return from Windower's `keyboard` event keeps no key from the game. A tap of an arrow turns the camera,
  and Page Up and Page Down zoom it. A letter typed in the search box opens the game's menu for it.
- `keyboard_blockinput 1` keeps every key from the game, and the `keyboard` event still sees each key.
- A Windower `bind` keeps its own key from the game. Under `keyboard_blockinput 1`, Windower runs no bind.
- Home and End do nothing in the game with the stock bindings.


Sourced in `docs/controller-support.md` §3.

- `padsin000` has 27 slots, and in XInput mode the values are button ids: slot 5 Cancel, 6 Main menu,
  7 Confirm, 8 Active window. Ids: 0 B, 1 X, 2 Y, 3 A, 10 L3, 13 R3. `padmode000`'s sixth flag is Enable
  XInput.
- The user's game maps L3 to sit or heal and R3 to the camera view. The defaults may be the same.
- The client reads XInput through `xinputdll.dll` and one wrapper at `0x10008ea0` (the 2026-10-13 and
  2026-11-02 builds). It rewrites its slots about every 1.5 s while no pad is attached. nui never uses
  that address. It finds the wrapper by signature.
- Windower wraps DirectInput8 and has no XInput code.
- Ashita v4 hooks `XInputGetState` and DirectInput itself. Under Ashita, route 0 would find the entry
  already patched and refuse. Route 1 calls through the client's shim, so it would chain through Ashita's
  hook.
- Steam Input can remap the pad behind the game's back. Players should turn it off for FFXI.
