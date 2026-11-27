# Controller support: handoff

This is for an agent who continues this work. It records what was built, where it is, what has and has
not been checked, and what is left. Read it with `docs/controller-support.md`, the original plan with the
research behind it, and `docs/test-findings-plan.md`, the fixes from the two test reports.

Last updated 2026-11-27.

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
frame comparison on Lego finds only the new Settings row (§4). The in-game test is next (§6).

## 2. Repositories, branches, commits

| Repo | Branch | Head | What it holds |
|---|---|---|---|
| both | `ccr-bfbc0043-hhlj8v` | Chronicle: this document's commit. nui: `6b821c8` | The 2026-11-27 session's branch, made from `ccr-d3a8994b-5t63ba`'s heads (Chronicle `36a7467`). It adds the keyboard driver. nui is unchanged. |
| `toboshii/ffxi-chronicle` | `ccr-d3a8994b-5t63ba` | `36a7467` | The controller feature, nui 1.5.0 vendored, `_chronicle.dll` 2.1.4, the docs. On upstream `master` `338643d` (Chronicle 2.1.1). |
| `toboshii/nui` | `ccr-d3a8994b-5t63ba` | `6b821c8` | PadHook revisions 1 to 3, the HD decode and its fixes. On upstream `main` `8b2e53c` (nui 1.2.10 plus CI and docs). |
| both | `claude/chronicle-workstreams-review-dp0k36` | `ccr-d3a8994b-5t63ba`'s heads when last fast-forwarded | The review branch. The 2026-11-26 session worked on `ccr-d3a8994b-5t63ba`, from the review branch's heads then (Chronicle `e42d0c8`, nui `d8d94e5`). The user has the review branch fast-forwarded to `ccr-d3a8994b-5t63ba` in both repositories when they ask, last on 2026-11-27. Compare the two heads before you rely on either. |
| `toboshii/nui` | `hd-texture-packs` | `871a167` | The upstream PR for the HD work: four commits, no release. Open on `jintawk/nui`, waiting for review. |
| `toboshii/nui` | `controller-pad-hook` | `79bb531` | The upstream PR for the pad hook, "Read and hold the controller the game reads", on upstream `main` `8b2e53c`. Four commits: revision 1, revision 2, the Linux tests, revision 3. It has no release commit, no HD work and no `l_screen` comment fix. It names PadHook revisions instead of the fork's release numbers, and its frozen layout is `test/frozen/layout_padhook.rev1.txt`. Open on `jintawk/nui`, waiting for review. |
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
| this commit | docs: the keyboard driver |

Versions now: nui **1.5.0**, `_chronicle.dll` **2.1.4** (`plugin/ChronicleModule.cpp`, `kConfig`), Chronicle
**2.2.0** (`core/ident.lua`), PadHook ABI **1**, revision **3**, atlas format **4**.

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

### Lua, in Chronicle

| File | Role |
|---|---|
| `ui/pad.lua` | A pure decoder. Its fast path costs nothing on idle frames. Raw state becomes actions: directions (D-pad or left stick, with hysteresis and auto-repeat), Confirm/Cancel (from `pad.from_config`, so a game layout with Confirm on B swaps them), `tab_prev`/`tab_next`, `page_up`/`page_down`, `sort`, `filter`, `settings`, `collapse`, `top`, `toggle`. It also returns a right-stick scroll amount. `latch()` makes buttons held at take-over act only after their release. |
| `ui/nav.lua` | Pure spatial navigation over the hits that screens already register. Head targets are chrome hits plus the sticky tab bar. Body targets are content hits. Resize grips, `noop` and `sticky_bar` are skipped, and a wrapped link (one `span`) is one target. `nav.key` gives a hit's identity without coordinates. Target lists are memoized per builder in a weak table. |
| `ui/window.lua` | The cursor, in the "controller" section at the bottom of the file: `pad_mode`, `cursor`, `cursor_key`, `cursor_zone`. The cursor is the hover, so the existing hover drawing shows it. `pad_draw` adds a frame, and the hint line is in the bottom margin. `pad_refind` runs after each layout. `pad_move` is spatial, crosses between head and body at the edges, and steps by a third of the viewport on sparse pages. A mouse move of more than 3 px over the window gives the hover back to the mouse. |
| `core/app.lua` | `App:go` pushes `cursor = win.cursor_key` onto the stack, and `App:back` passes it to `on_change`, then `set_screen`. |
| `chronicle.lua` | The section "The controller": `padc`, `pad_read_config`, `pad_join`, `pad_take`, `pad_give`, `pad_act`, `pad_tick` (run from `prerender`), `pad_no_shim`. |
| `ui/screens/settings.lua` | The rows "Controller (L3+R3)" and "Keyboard (K)". |
| `ui/keys.lua` | Also tracks Ctrl and Alt (`keys.shift()`, `keys.ctrl_alt()`), for the keyboard driver. |
| `chronicle.lua`, "The keyboard" | `kbd`, `KEY_ACT`, `kbd_take`, `kbd_give`, `kbd_down`, `kbd_tick`, `kbd_reset`. The `keyboard` event runs the search box first, then the driver. |
| `README.md` | The section "With a controller", and the controller paragraph of "The native layer". |

`chronicle.lua`'s controller code does this:
- **Joining:** it reads the game's pad config once, then joins on the first frame. On route 1 that works at
  once. On route 0 it retries every 5 s while `xinput1_3.dll` is not loaded. Then it calls
  `pad_chord(L3+R3)`. Since `dec423c`, `//cr pad` does not take the pad while route 1 is live and the client
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
- **Repeat:** a held arrow repeats on Chronicle's own clock, with the pad's delay and rate. Windower's repeated
  key-downs, if any, move nothing.

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
| In game: build 4 (`fb65dc1`), the choosable key | Not tried yet. The test zip is `chronicle-keys-test4.zip`. `test_keys` has 139 checks, and each rule of the key was removed in turn and caught. |
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
4. **After both merge,** Chronicle should vendor an upstream nui release instead of the fork's 1.5.0. The fork's
   release numbers (1.3.0 to 1.5.0) give way to upstream's then, so agree on that with the user. DLLs built
   on the fork's revisions 1 to 3 stay compatible with upstream's, because the bus and its frozen layout are
   the same.
5. **A Chronicle pull request** to `jintawk/ffxi-chronicle`, only when the user asks, and only once Chronicle
   can vendor an upstream nui release that has the pad hook. Use a new branch with no `claude/` or `agent/`
   prefix, and leave the plans and handoffs (`docs/`) off it, as for nui.
6. **The keyboard driver: built** (`d4417ad`). The QA frame comparison passed (§4). Build 1's in-game test
   found that Windower does not block a single key, and build 2 (`5a47e40`) blocks the whole keyboard. Left: the
   in-game test of build 2, and a QA run at `5a47e40` if wanted (its drawing code did not change). Later, a native
   keyboard hook in nui could hide only the nav keys, so chat and macros keep working. After it, from
   `docs/test-findings-plan.md` §7: the player's own key bindings, the game's input mask, and a main menu
   item. The key bindings matter more now: the driver uses fixed keys, and it cannot see a binding
   the player made in the game.
7. **Optional:** DirectInput as a second PadHook source, QA frames for controller mode, and moving and
   resizing the window from the pad.
8. **Small loose ends:**
   - With Enable XInput off, the first field of the controller line in `//cr status` still reads "ready
     (L3+R3)". `//cr pad` gives the right message, so this is cosmetic.
   - nui's `example/README.md` says a straight copy of `FFXiMain.dll` will not do as `NUI_FFXI_COPY`. A plain
     copy works for the 2026-11-02 client.
   - The `l_screen` comment fix in `src/host.cpp` is only in the fork's 1.5.0, not in either pull request.
   - `claude/hd-texture-packs` is stale. The user deletes it, because the proxy refuses branch deletes.

## 7. Facts from the research worth keeping

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
