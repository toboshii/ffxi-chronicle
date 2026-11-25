# Test findings: the plan for the fixes

Status, 2026-11-25: the five decisions in section 9 are taken, all as recommended. Steps 1 and 2 are
built, which is test build 1: nui 1.4.2 (`6e72c8b`), `_chronicle.dll` 2.1.3 (`4f5b545`) and the config read
(`851707f`). Steps 3 and 4 are not built yet.

This plan answers the test agent's report of 2026-11-25 (`handover-controller-1.md`). The tests ran on
Windows 11 at 3840x2160, window type 6, with an HD `19.DAT`. Read this plan with
`docs/controller-handoff.md`, which describes the two work streams: HD texture packs in nui, and
controller support in nui and Chronicle.

Work happens on `claude/chronicle-workstreams-review-dp0k36` in both repositories. Today that branch is
at the same commits as `claude/controller-support-plan-yjc276` (Chronicle `867e46a`, nui `cf75bf8`).

## 1. The findings, and what this plan does with each

| Report | Finding | Verdict | Action |
|---|---|---|---|
| §1 | Mouse coordinates are correct on Windows, at 4K, with the HD art | Agreed. Hit tests use only layout and never read the atlas. | None |
| §2 | The atlas cache key stayed the same when the HD decode changed the pixels. A nui 1.2.10 addon and Chronicle then share one atlas. | Confirmed in the code | Step 1 |
| §4 | The game's pad config is read only after the hook succeeds | Confirmed in the code | Step 2 |
| §3 | That machine's `xinput1_3.dll` is not hot-patchable, so the pad hook refuses | Confirmed in the code | Step 3 |
| §5 | Research: Windower and DirectInput, the game's input merge and mask, a keyboard driver, key bindings, a main menu item | Useful. None of it blocks the fixes. | Step 4 records it. Section 7 proposes what comes next. |

## 2. Which build was tested

The cache status line in the report names `chronicle 2.1.1`. On the branch, `_chronicle.dll` 2.1.1 is
commit `550e5a1`, which vendors nui 1.4.0. nui 1.4.0 has no HD decode. The branch head, `8f0c9a5`,
ships `_chronicle.dll` 2.1.2 with nui 1.4.1.

The window drew HD art after a zone, so the DLL that ran must have had the HD fix in it. A local build
that merged the fix without a version bump would explain both facts. I cannot confirm that from here.

The findings still hold, because `src/cache.hpp` is the same in all of these versions. For the retest,
use the build from this plan. Its status line names the new DLL version, which makes the build easy to
identify.

## 3. Step 1: a new atlas format number (nui 1.4.2)

### Why

An atlas's cache key is the window type, a hash of the install folder, and `kFmtAtlas`. The HD commit
(`5a8b5e1`) changed what `Assets::load` produces on an HD install, but `kFmtAtlas` stayed at 2. So nui
1.2.10 and nui 1.4.1 use one key for different pixels. The first module to create the entry wins, and
the other module draws those pixels.

The rule is already in `src/cache.hpp` and `docs/abi.md`: bump a kind's format number when a change
alters a single output byte. The golden test (`test/golden_fmt.json`) could not catch this case. It runs
against the stock install on the test machine, and on a stock install the HD commit changes no pixels.

### Changes, in nui

1. `src/cache.hpp`: `kFmtAtlas = 3`. The comment gives the reason: 1.4.2, the HD texture pack decode.
2. The rule in `cache.hpp` and `docs/abi.md` gets one more sentence. A change that makes a load succeed
   where it failed before also changes the output. That is true even when a stock install decodes the
   same.
3. `test/golden_fmt.json`: `atlas.fmt` becomes 3. The hashes stay.
4. `python3 sync.py release 1.4.2`, one commit, as the history does for each release.

Then, in Chronicle: sync nui 1.4.2 and rebuild `_chronicle.dll` as 2.1.3.

### What does not change

The report asks whether the scale detection reaches `kFmtIcon` or `kFmtPicture`. It does not:

- `tex_scale`, `box_down` and `unscale_sheet` are called only from `blit_texture` and `Assets::load`.
  Both build the atlas.
- Item icons come from `textures.cpp`, which reads a fixed 0x800-byte record for each icon.
- Pictures are decoded by stb_image, from the addon's own files.

The HD commit changed only `assets.cpp`. A later change that reads icons from an HD pack must bump
`kFmtIcon`.

### Side effects

Chronicle no longer shares its atlas with an addon on nui 1.2.10 to 1.4.1. This is also true on a stock
install. Each window type in use then costs one more atlas of 1024 x 512 (2 MB). Icons are still shared.

The other addon still draws without window art on an HD install until it moves to nui 1.4.2. That part
of the fix is on its side.

### Tests

- Here: build the DLL (`sh plugin/build.sh`) and run `python3 sync.py check --dll`.
- On Windows: `sh test/build_render_test.sh` (it needs an unpacked `FFXiMain.dll`). It must pass with
  `atlas.fmt` 3 and the old hashes. If the stock hashes moved, the HD commit also changed the stock
  decode. One candidate: it now keeps the first `font    font` chunk, where 1.2.10 kept the last. In that
  case, look at the frames, then run `--update-golden`.
- In game, with the 1.2.10 addon also loaded: Chronicle draws its window body at login, before any zone.
  The cache line in `//cr status` shows `own` above 0.

## 4. Step 2: read the pad config before the hook (Chronicle)

### Why

`pad_read_config()` runs only in the success branch of `pad_join()`. When `pad_start()` refuses for
good, `retry_at` becomes `math.huge`, so nothing reads the config. The hint line then falls back to
Confirm A and Cancel B, and status says `game pad config: not found`. The registry read does not need
the hook.

### Changes, in `chronicle.lua`

1. `pad_join()` reads the config on its first call, before `pad_start()`. A flag keeps it to one read
   per load, as now.
2. `pad_status_lines()` reads the config if nothing has read it yet. With `//cr pad off`, `pad_tick()`
   never runs, so `pad_join()` never runs either.
3. The `//cr pad` message for "not loaded" uses the config. With Enable XInput off, it says to turn it
   on. Otherwise the message stays as it is.

No nui change.

### Tests

`test/test_pad.lua` gets a case that uses the harness's existing `pad_fail` and `pad_config` options.
With the hook refused, the hint line and status show the config's Confirm and Cancel. Status also names
the registry key. Then run the other Lua tests that `docs/controller-handoff.md` §4 lists.

## 5. Step 3: hook the game's XInput pointer (PadHook revision 3, nui 1.5.0)

### Why

Today the hook needs the hot-patch form at `xinput1_3.dll!XInputGetState`. Which build of that DLL a
player has depends on which DirectX redistributable installed it. On the test machine the function
starts with `55 8B EC`, so the hook refuses there. It will refuse on every machine with that build.

The report shows that the client never calls the export directly. It loads the DLL by name, stores the
function's address in its own data, and calls it through one small wrapper. If nui changes that one
pointer, the hook works with any prologue, and it affects only the game's own calls.

### Finding the pointer: by value

Once the game has loaded the DLL, nui can compute the four values that the game stored. In the November
build they sit together:

| Offset | November build | Value |
|---|---|---|
| +0 | `0x104576fc` | the module handle of `xinput1_3.dll` |
| +4 | `0x10457700` | `XInputGetState` |
| +8 | `0x10457704` | `XInputSetState` |
| +12 | `0x10457708` | `XInputEnable` |

nui gets the handle with `GetModuleHandleExA` and the three functions with `GetProcAddress`. Then it
scans the writable sections of the loaded `FFXiMain.dll`, at 4-byte alignment, for that 16-byte block.
It needs exactly one match, as UiHook does for its signature. No match, or more than one, means no
pointer route.

The report suggests a signature over the wrapper at `0x10008ea0` instead. I recommend the value scan:

- It needs no bytes from a particular client build. We have no `FFXiMain.dll` here, and the report
  gives the wrapper's address but not its bytes.
- It does not depend on how the compiler laid out the wrapper. The October and November builds put the
  code at different addresses. The value scan works on both, as long as the game keeps the four values
  together.
- The values prove what the game stored. The report's decompile shows that the wrapper calls through
  `+4` and is its only caller.

A wrapper signature can come later as a second check. It needs the wrapper's bytes (question Q2).

### Installing

1. The thunk goes in the same VirtualAlloc block as now, which is never freed. Its fall-through jumps to
   the saved pointer value instead of `site + 2`.
2. nui checks with `VirtualQuery` that the slot's page is committed and writable. It refuses otherwise,
   and it does not change the page's protection.
3. One `InterlockedCompareExchange` on the aligned slot changes it from the export's address to the
   thunk. If the game changed the value in between, nui writes nothing.
4. nui pins `xinput1_3.dll`, as now, so the saved function can never unload.
5. The dispatcher does not change. It calls `bus->original`, which is now the saved pointer value.

### When the pointer route fails

If the value scan finds nothing, nui tries the current export hot patch, with its current refusals. On
the test machine that still refuses, and the status gives both reasons.

The report also offers a conventional 5-byte detour, which relocates `55 8B EC 6A FF`. It is not in this
plan. It would be a third way to patch a Microsoft export, and the pointer route makes it unnecessary.

### When the game writes the pointer again

We do not know if the game writes the pointer after start (question Q1). `pad()` already runs every
frame, so it gets one cheap check, a read of the slot:

- The slot holds the saved function again, so the game resolved it again. nui writes the thunk back and
  counts it.
- The slot holds zero or any other value. nui leaves it alone, the status says so, and the hook goes
  back to waiting. The next retry scans again.

### Unloading

The thunk stays in the game's pointer, as the hot patch stays in the export today. With nobody driving,
the thunk passes every call through in five instructions.

The report notes that nui could write the old pointer back. That frees nothing: a game thread can still
be inside the thunk, so the block must stay. It would also add a path that installs again. It is not in
this plan (decision D3).

### Changes to the bus (ABI 1, revision 3)

- Two new fields in `PadBus::reserved_hdr`: `route` (0 the export hot patch, 1 the game's pointer) and
  `reswaps`. Zero means the revision 2 behaviour. On the pointer route, `site` holds the slot's address.
- `test/layout_padhook.txt` changes only in its `reserved*` lines, and `test/frozen_check.py` must
  pass.
- A revision 2 module sets `blocked` when the export refuses, and it means "never in this process". A
  revision 3 module tries the pointer route even when `blocked` is set, and clears it on success. A
  revision 2 module that joins later finds `hook_installed` set and registers as before. No revision 2
  module ships outside test builds, but the rule costs nothing.

### Status and wording

- `pad_status()` gets a `route` field. `describe` reads, for example: `live via FFXiMain's XInput pointer
  at 10457700; 1 client: chronicle r3 (drives)`. Chronicle prints it unchanged.
- The nui README says that nui "never writes to the game". UiHook already patches the client's code, so
  the sentence must mean game state. With this route, nui also writes one function pointer in the
  client's data. The README and `docs/abi.md` will say that plainly.

### Tests

Here, on 32-bit Linux (`test/pad_linux/run.sh`):

- The value scan over a made-up section: one match, none, two, a copy that is not aligned, and a block
  with the wrong module handle.
- The pointer route's thunk bytes, disassembled: the fall-through jumps to the saved function.
- The check in `pad()`: the saved function goes back to the thunk, and zero or another value is left
  alone.

On Windows (`test/build_pad_test.sh`, which builds here):

- A stand-in for the game. This DLL loads the fake XInput DLL and stores the four values the way the
  client does. It reads the pad through a wrapper like the client's. It is either named `FFXiMain.dll`
  in the test folder or found through a new `PADHOOK_GAME_DLL` macro.
- The field case, with `pad_fake_nohot.dll`. The pointer route installs, and the export's bytes stay as
  they were. Every existing mask, chord and heartbeat check passes through the stand-in's wrapper.
- A stand-in with no four-value block: the export route runs on `pad_fake_xinput.dll` and refuses on
  `pad_fake_nohot.dll`, as today.
- The stand-in resolves its pointer again: the thunk goes back. The stand-in writes zero: nui leaves it.
- The handover test for a higher revision moves from revision 3 to revision 4.
- `--self-test` gets fault builds for the new route, for example a scan that accepts two matches.

Wine did not start in this container last time. The build session will try it again, for no more than
half an hour. After that, the Windows run is yours.

In game, on the machine that refused: `//cr pad status` says `live via FFXiMain's XInput pointer`.
Then the open checks from `docs/controller-handoff.md` §6: the chord, an L3 tap, R3 held, the HD art.

### Release

`python3 sync.py release 1.5.0`. It is a new minor version because PadHook gains a revision. Then, in
Chronicle: sync and rebuild `_chronicle.dll` as 2.1.4.

## 6. Step 4: documentation

- `docs/controller-support.md`: the Status header records the new route. §8 records that Windower wraps
  DirectInput8 and has no XInput code. That closes the chaining risk for the XInput route. The risk
  stays open for Phase 5, the DirectInput route.
- The report's §5 research goes into `docs/controller-support.md` §3, with its addresses marked as the
  November 2026 build, to be found by signature and never by address.
- `docs/controller-handoff.md`: versions, commits, the verification table, and what is left.
- nui: the header comment in `src/PadHook/PadHook.h`, the PadHook 1 section of `docs/abi.md`,
  `docs/lua-api.md` (`pad_status().route`), and the README's two pad paragraphs.
- Chronicle README, "With a controller": the paragraph that names the hot patch.

## 7. Not in this round: the report's §5

Each item is worth doing. None is needed for the fixes. My recommended order:

1. **A keyboard driver, in Lua only.** This is Phase 1 of the original plan. Windower's `keyboard` event
   can already keep a key from the game, and `ui/nav.lua` works with any input. It needs no native
   code. It also covers players whose pad Steam Input, DS4Windows or reWASD maps to keys.

   It needs a key or chord that takes control and gives it back. The report lists D, G, K and O as free
   in the stock English menu bindings. I recommend it as the next piece of work after these fixes.
2. **Read the player's key bindings**, so that the keyboard's chord avoids a conflict. Where ids 74 to
   137 live decides the cost (question Q3). If they are registry values like `padsin000`, `pad_config()`
   can read them. If they live only in memory, they need native code and a signature.
3. **The game's logical axes and input mask** (`Input_GetAxisValueMerged`, and `FUN_10124b70`, which
   writes the mask). One path would cover every device. It is a larger change. The game writes that
   mask itself from sixteen places, so nui would have to share it with the game. It deserves a design
   note before Phase 5 starts.
4. **A "Chronicle" item in the game's main menu.** Two things are unknown: whether the element array can
   take a sixteenth item, and whether `Cmd_ExecuteLine` reaches a Windower command. Both need a test in
   game first.

The report's §1 says that wrong mouse coordinates on Linux would come from Wine or cursor scaling, not
from the HD path. If you see that on Linux, it needs its own investigation. It is not in this plan.

## 8. Questions for the test agent

- **Q1.** Who calls `Input_GetXInputProcs` (`0x10008e10`) and `Input_LoadXInputDll` (`0x10008d90`), and
  when? Only at start, or also on focus, on a config change, or on a device change? Does anything else
  write `0x10457700`, for example zero at shutdown? Which DLL names can `Input_LoadXInputDll` build?
- **Q2.** For a wrapper signature as a second check: the first 32 bytes of the wrapper at `0x10008ea0`.
  Also the same function's bytes in the October build.
- **Q3.** Are config ids 74 to 137 stored as registry values next to `padmode000`, or only in memory?

Step 3 can start without the answers. Q1 decides how much the check in `pad()` must do.

## 9. Decisions

All five are taken as recommended.

| | Decision | Taken |
|---|---|---|
| D1 | Find the pointer by value, or by a signature over the wrapper. The signature needs Q2 first. | By value |
| D2 | Keep the export hot patch as a fallback, or remove it and keep one route | Keep it |
| D3 | On unload, leave the thunk in the game's pointer, or write the old pointer back when the last module leaves | Leave it |
| D4 | Two test builds (steps 1 and 2 now, step 3 later), or one build with all three | Two. Steps 1 and 2 are small and fix what the tester sees at login. Step 3 needs more testing. |
| D5 | The keyboard driver: after this round, or in it | After |

## 10. Commits, and the retest

All new commits use the author Toboshii Nakama, with no trailers. They go on top of the existing commits,
which keep their authorship, as the report's §6 asks.

nui, on `claude/chronicle-workstreams-review-dp0k36`:

1. `nui 1.4.2: ...` (step 1: the format number, the golden file, the docs, the release)
2. `nui 1.5.0: ...` (step 3: PadHook revision 3, its tests, the docs, the release)

Chronicle, on the same branch name:

1. `nui 1.4.2: ...` (the sync, `_chronicle.dll` 2.1.3)
2. `pad: ...` (step 2)
3. `nui 1.5.0: ...` (the sync, `_chronicle.dll` 2.1.4)
4. `docs: ...` (step 4)

### Retest with build 1 (steps 1 and 2)

1. Log in with both nui addons loaded. Chronicle draws its window body and the HD art at login.
2. `//cr status`: the cache line names `chronicle 2.1.3` and shows `own` above 0.
3. `//cr pad status`, with the hook still refused: the config line names the registry key and the
   player's real Confirm and Cancel.

### Retest with build 2 (step 3)

1. `//cr pad status`: `live via FFXiMain's XInput pointer`.
2. The open checks in `docs/controller-handoff.md` §6.
3. Mouse and keyboard still work while the pad is held and after it is given back.
