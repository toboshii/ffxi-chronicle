# Controller support: handoff

This is for an agent continuing this work. It records what was built, where it is, what has and has
not been verified, and what is left. Read it with `docs/controller-support.md`, the original plan with
the research behind it. That plan's "Status" header records which decisions changed during the build.

Last updated 2026-11-25.

## 1. State in one paragraph

The work is done and pushed. It has run in game once: the user confirmed that controller mode and
navigation "work great". The only issue they reported was that the L3 + R3 chord also made the
character sit and switched the camera. That is fixed in nui 1.4.0 (the hook keeps the chord from the
game), but **the fix has not been confirmed in game yet**. nui 1.4.1 adds the user's HD texture-pack
fix, and Chronicle vendors 1.4.1. Nothing is merged into either repo's `main`, and no pull request is
open. The user asked for nui's `main` to stay clean.

## 2. Repositories, branches, commits

| Repo | Branch | Head | Notes |
|---|---|---|---|
| `toboshii/ffxi-chronicle` | `claude/controller-support-plan-yjc276` | `8f0c9a5`, then this document's commit | The user's fork of `jintawk/ffxi-chronicle`. |
| `toboshii/nui` | `claude/controller-support-plan-yjc276` | `cf75bf8` | The user's fork of `jintawk/nui`, the drawing library Chronicle vendors. |
| `toboshii/nui` | `main` | `7b566ed` (nui 1.2.10) | **Keep it clean.** The user merged PR #1 (the HD fix) there, then asked for it undone. It was force-pushed back to `7b566ed` with a lease. Do not push to `main` without being asked. |
| `toboshii/nui` | `claude/hd-dat-texture-mod-error-jobvma` | `5a8b5e1` | The user's HD texture-pack fix (only `src/assets.cpp`). It is merged into the controller branch and released as 1.4.1. |

On the nui controller branch, newest first:

- `cf75bf8` test: the pure logic on 32-bit Linux (`test/pad_linux/`)
- `2dae3a5` nui 1.4.1 (release: the HD fix together with the pad hook)
- `6862a70` merge of main (the HD fix)
- `294b75a` nui 1.4.0 (the chord)
- `32e8138` nui 1.3.0 (the pad hook)

On the Chronicle branch, newest first:

- `8f0c9a5` sync nui 1.4.1, `_chronicle.dll` 2.1.2
- `550e5a1` the hook keeps L3 + R3 from the game
- `58b6c16` the controller feature
- `5fa0ddd` the plan

The base is `f9fb5b6`.

Versions now: nui **1.4.1**, `_chronicle.dll` **2.1.2** (`plugin/ChronicleModule.cpp` kConfig),
Chronicle **2.2.0** (`core/ident.lua`), PadHook ABI **1**, revision **2**.

## 3. Architecture

### Native, in nui: `src/PadHook/PadHook.h` and `src/pad.cpp`

- **Why native.** Windower 4 gives Lua no controller input at all. FFXI reads an XInput pad with
  `xinput1_3.dll!XInputGetState` when its "Enable XInput" setting is on. Otherwise it uses DirectInput8,
  which is not hooked yet.
- **The bus.** One shared hook per process, `Local\FFXiPadHook_v1_<pid>`, 4 KB, built the same way as
  nui's existing UiHook. The live module with the highest revision "drives" (its dispatcher is the one
  called). A module hands the dispatch on in `DllMain`. The thunk is in VirtualAlloc'd memory and is
  never freed. With nobody driving, it is a pure pass-through.
- **The patch.** The Windows hot-patch form. `E9 rel32` goes into the 5 padding bytes before the entry,
  then `8B FF` becomes `EB F9` in one locked 16-bit compare-and-exchange. The original function is
  `site + 2`. Anything else at the entry ("not hot-patchable", or "already hooked") is refused for good
  (`blocked`), and the bytes found are reported. If `xinput1_3.dll` is not loaded, `pad_start` asks to
  be retried. nui never loads it itself, and pins it once found.
- **What the dispatcher does** (`dispatch`, `record`, `apply_chord`, `apply_mask`):
  1. Calls the original.
  2. Records the raw state per user index behind a seqlock.
  3. Applies the chord step. This is revision 2, and it runs only for the user index that last read a
     connected pad.
  4. Applies the shared mask:
     - While any live client holds the pad, new presses are hidden, the sticks are zeroed, and the
       triggers are zeroed unless they were held from before.
     - "Held from before" means what the game's last output already showed as pressed (`last_out`).
     - A hidden press stays hidden until it is released, even after the pad is given back.
     - `dwPacketNumber` is renumbered, so it changes exactly when the output changes.
     - A hold lapses if the client does not renew it for 250 ms (`PADHOOK_HEARTBEAT_MS`).
- **The chord** (revision 2, `PadChord` in the bus header's reserved tail; `PadClient.chord`):
  - While nobody holds the pad, the first chord button down is held back for up to
    `PADHOOK_CHORD_MS` (150 ms).
  - If its partner arrives in time, that is the chord: both are hidden until released.
  - If it is released alone in time, the game is shown the press for `PADHOOK_REPLAY_READS` (2) reads.
  - If it is still held alone after 150 ms, the game gets it.
  - A chord forms only from buttons still held back, never one the game already has. That bug was
    found and fixed.
- **Lua API** (`pad.hpp`, registered in `host.cpp`'s table):
  - `pad_start([flags])`
  - `pad()`, which returns 10 numbers (no table) and also renews the hold
  - `pad_capture(on)`
  - `pad_chord(mask)`
  - `pad_config()`, which reads `padmode000` and `padsin000` from
    `HKLM\SOFTWARE\PlayOnline{US,EU,}\SquareEnix\FinalFantasyXI` (32-bit view)
  - `pad_status()`
  - `pad_stop()`. `stop()` calls `pad_release()`, and `host_detach` calls `pad_detach()`.
- **Frozen layout.**
  - `test/layout_padhook.txt` is the live layout, and `test/frozen/layout_padhook.1.3.0.txt` is frozen.
    `test/frozen_check.py` checks the pair.
  - Revision 2 only added fields into reserved tails, so only `reserved*` lines moved.
  - Keep that rule: append only, and zero means the old behaviour.
- **DirectInput later.** `PadState::source` reserves `PADHOOK_SRC_DINPUT`. The mask works on one
  button word in XInput's layout, with LT and RT as bits `0x10000` and `0x20000`.

### Lua, in Chronicle

| File | Role |
|---|---|
| `ui/pad.lua` | A pure decoder. Its fast path costs nothing on idle frames. Raw state becomes actions: directions (D-pad or left stick, with hysteresis and auto-repeat), Confirm/Cancel (from `pad.from_config`, so a game layout with Confirm on B swaps them), `tab_prev`/`tab_next`, `page_up`/`page_down`, `sort`, `filter`, `settings`, `collapse`, `top`, `toggle`. It also returns a right-stick scroll amount. `latch()` makes buttons held at take-over act only after their release. |
| `ui/nav.lua` | Pure spatial navigation over the hits screens already register. Head targets are chrome hits plus the sticky tab bar; body targets are content hits. Resize grips, `noop` and `sticky_bar` are skipped, and a wrapped link (one `span`) is one target. `nav.key` gives a hit's identity without coordinates. Target lists are memoized per builder in a weak table. |
| `ui/window.lua` | The cursor, the bottom of the file's "controller" section. `pad_mode`, `cursor`, `cursor_key`, `cursor_zone`. The cursor is the hover, so existing hover drawing shows it. `pad_draw` adds a frame and the hint line is in the bottom margin. `pad_refind` runs after each layout. `pad_move` is spatial, crosses between head and body at the edges, and steps by a third of the viewport on sparse pages (`PAD_REACH`, `PAD_STEP`). The rest: `pad_activate`, `pad_back` (returns `'root'` when there is nowhere to go back to), `pad_click` (synthetic hits), `pad_scroll`, `pad_follow`. A mouse move of more than 3 px over the window gives the hover back to the mouse. |
| `core/app.lua` | `App:go` pushes `cursor = win.cursor_key` onto the stack, and `App:back` passes it to `on_change`, then `set_screen`. |
| `chronicle.lua` | The section "The controller", with `padc`, `pad_join`, `pad_take`, `pad_give`, `pad_act` and `pad_tick` (run from `prerender`). See the list after this table. |
| `ui/screens/settings.lua` | The row "Controller (L3+R3)". |
| `README.md` | The section "With a controller". |

`chronicle.lua`'s controller code does this:
- **Joining:** joins on the first frame, retries every 5 s while `xinput1_3.dll` is not loaded, then
  calls `pad_chord(L3+R3)`.
- **Taking and giving back:** without the pad, it only watches for the chord edge. With it, it
  dispatches actions. It gives the pad back on Cancel at the root, on hide, logout and lose focus, and
  on `//cr pad`.
- **After a stall:** a hold that lapsed is taken again, with the held buttons latched.
- **Setting:** `pad = true` by default.
- **Command:** `//cr pad [on|off|status]`. Status lines are also added to `//cr status`.

Button layout: D-pad or left stick moves the cursor. A is Confirm and B is Cancel, unless the game's
config says otherwise. LB/RB change section, LT/RT page, the right stick scrolls, X is Sort, Y is Show,
Start is Settings, Back collapses, R3 alone goes to the top, and L3+R3 takes or gives back the pad.

## 4. Verification status

| What | Status |
|---|---|
| In game: navigation, taking and giving back the pad | **Works**, by the user's report (nui 1.3.0 build) |
| In game: the chord no longer sits the player or changes the camera (1.4.0+) | **Not yet confirmed** |
| In game: the HD fix together with the pad (1.4.1) | **Not yet confirmed** |
| `test/test_pad.lua` (Chronicle) | 86 passed, 0 failed |
| `test/test_input.lua`, `test_doc`, `test_roe`, `test_progress_ui`, `test_progress_lists`, `test_mission_words`, `test_complete_strip` | All pass, unchanged |
| `test/test_screens.lua` | 18,395 passed, 4 failed. The **same 4 fail on the base commit `f9fb5b6`**, because of the Linux environment: "resize saved the place", "place restored", "pictures in view to check", "a texture freed under a layout...". |
| `test_core`, `test_data`, `test_load`, `test_progress` | Fail or error on this Linux setup before any change (they need a v1 worktree, the real DLL, or Windows). Not re-checked. |
| nui `test/pad_linux/run.sh` (the mask, chord, heartbeat and thunk logic, 32-bit Linux) | 19 + 19 passed. The thunk disassembles correctly. |
| nui `test/build_pad_test.sh` (the real hook on a stand-in `xinput1_3` with the real entry shape; foreign hook; not hot-patchable; a revision 3 module handover; 5 fault builds) | **Builds; never run.** Wine fails at startup in this container (`free(): invalid pointer`). Run on Windows: `sh test/build_pad_test.sh --self-test`. |
| nui's full `test/build_test.sh` and Chronicle's QA render (`test/qa_render.lua`) | Not run. They need Windows and an unpacked `FFXiMain.dll`. No QA frames were added for controller mode. With the controller off, frames should be unchanged. |

## 5. Working here (a Linux cloud container)

- **Toolchain.** Installed with apt: `g++-mingw-w64-i686`, `lua5.1`, `g++-multilib`. Wine was installed
  but does not work.
- **The DLL.** `cd ffxi-chronicle && sh plugin/build.sh`. Check it with
  `cd nui && python3 sync.py check --dll ../ffxi-chronicle/libs/_chronicle.dll`.
- **Lua tests.** `export TEMP=<scratch dir>` first, then `lua5.1 test/<name>.lua` from the Chronicle
  root. The harness's Windows-only `>nul` leaves a file named `nul` in the repo root: delete it, and
  never commit it.
- **Syncing nui into Chronicle.** `sync.py` resolves consumer paths from `HERE.parents[1]`, which is
  `/home` here, not the directory you run it in. So add `user/ffxi-chronicle/plugin/nui` to
  `consumers.txt`, run `python3 sync.py sync`, then `git checkout consumers.txt`. Never commit that
  entry.
- **Releasing nui.** `python3 sync.py release <x.y.z>` writes `VERSION`, `RELEASES` and
  `src/nui_version.h`. Sync and rebuild the DLL after.
- **Pushing nui** (a shallow clone): `git -c push.negotiate=true push`. Tracking for the branch was set
  up by hand.
- **A stray directory.** `/ffxi-chronicle/plugin/nui` is left over from a sync with the wrong path.
  The safety check would not let it be deleted. It is harmless; the user can remove it.
- **A test zip for the user.** `git archive --format=zip --prefix=chronicle/ -o <zip> HEAD` from the
  Chronicle root. The user unzips it over `Windower/addons/chronicle`. The DLL and the Lua files must
  go together.
- **Commit style.** Both repos use "area: a plain sentence" subjects (`pad:`, `nui 1.x.y:`, `docs:`),
  wrapped bodies that say why, and the session's attribution lines. `docs/` is in Chronicle's
  `.gitignore`, so files there are force-added (`git add -f`).

## 6. What is left, in rough order

1. **Confirm in game** with the nui 1.4.1 build:
   - L3 + R3 takes and gives back the pad without sitting or changing the camera.
   - An L3 tap still sits the player; R3 held still switches the view, about 150 ms late.
   - HD texture-pack art draws correctly.
   - `//cr pad status` reports `live`.
   - If 150 ms feels slow, tune `PADHOOK_CHORD_MS`. That is a source change, so it means a new nui
     release.
2. **Run nui's Windows pad tests** (`sh test/build_pad_test.sh --self-test`), and fix anything they
   find. They have never run.
3. **Pull requests**, only when the user asks: nui `claude/controller-support-plan-yjc276` into
   `main`, and Chronicle's branch into its `main`. The user wants nui's `main` left alone for now.
4. **QA frames for controller mode** (cursor on home, an area list, a walkthrough with path tabs,
   Records, Settings), with `test/qa_render.lua` on Windows.
5. **Optional, from the plan:**
   - DirectInput as a second PadHook source: a vtable hook on the game's joystick device,
     `GetDeviceState`/`GetDeviceData`, filtered by device. Windower wraps the keyboard device, whose
     vtable is the same one.
   - Keyboard navigation (the plan's Phase 1 driver): the nav core is input-agnostic, and
     `W:pad_move`/`pad_activate`/`pad_back` would take keyboard events as they are.
   - Window move and resize from the pad.

## 7. Facts from the research worth keeping

These are sourced in `docs/controller-support.md` §3.

- `padsin000` has 27 slots, and in XInput mode the values are button ids:
  - slot 5 Cancel, 6 Main menu, 7 Confirm, 8 Active window
  - ids 0 B, 1 X, 2 Y, 3 A, 10 L3, 13 R3
  - `padmode000`'s sixth flag is Enable XInput.
- The user's game maps L3 to sit/heal and R3 to the camera view. The defaults may be the same.
- Ashita v4 hooks `XInputGetState` and DirectInput itself. If this DLL were ever loaded under Ashita,
  the hook would find the entry already patched and refuse ("already hooked").
- Steam Input can remap the pad behind the game's back. Players should turn it off for FFXI.
