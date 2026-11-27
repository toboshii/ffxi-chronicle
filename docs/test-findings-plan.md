# Test findings: the plan for the fixes

Status, 2026-11-26:
- Steps 1 and 2 are built, which is test build 1: nui 1.4.2 (`d8d94e5`), `_chronicle.dll` 2.1.3
  (`1fd1bb6`) and the config read (`8591a96`).
- The test agent answered section 8 in a second report (`handover-controller-2.md`). Step 3 is
  redesigned after it, because the first design would have crashed the game (section 5a). You approved
  the new design (D1).
- Both branches are rebased onto the synced forks (D6, §4b). Chronicle now carries 2.1.1's mouse fix.
- Steps 3 and 4 are built, which is test build 2: nui 1.5.0 (`50d18a6`), `_chronicle.dll` 2.1.4 (`c8ac1c6`),
  the `//cr pad` message (`dec423c`) and the docs. They are on the branch `ccr-d3a8994b-5t63ba` in both
  repositories, which continues from the review branch's heads. Section 5b lists what the build changed
  from the design in section 5.
- Test build 2 works in game, by your report of 2026-11-27: every check of the retest list below passes.
  nui's Windows pad and render suites pass on your machine too (§5b and the handoff's §4).

This plan answers the test agent's first report of 2026-11-25 (`handover-controller-1.md`). Those tests
ran on Windows 11 at 3840x2160, window type 6, with an HD `19.DAT`. Read this plan with
`docs/controller-handoff.md`, which describes the two work streams: HD texture packs in nui, and
controller support in nui and Chronicle.

Work happens on `claude/chronicle-workstreams-review-dp0k36` in both repositories. It started from the
same commits as `claude/controller-support-plan-yjc276` (Chronicle `867e46a`, nui `cf75bf8`). On
2026-11-26 it was rebased onto the synced forks, so its commits have new hashes. Section 10 maps the old
hashes to the new ones. The old branch is unchanged, and the hashes in `docs/controller-handoff.md`
still name its commits.

## 1. The findings, and what this plan does with each

| Report | Finding | Verdict | Action |
|---|---|---|---|
| 1, §1 | Mouse coordinates are correct on Windows, at 4K, with the HD art | Agreed. Hit tests use only layout and never read the atlas. | None |
| 1, §2 | The atlas cache key stayed the same when the HD decode changed the pixels. A nui 1.2.10 addon and Chronicle then share one atlas. | Confirmed in the code | Step 1 (built) |
| 1, §4 | The game's pad config is read only after the hook succeeds | Confirmed in the code | Step 2 (built) |
| 1, §3 | That machine's `xinput1_3.dll` is not hot-patchable, so the pad hook refuses | Confirmed in the code | Step 3 |
| 1, §5 | Research: Windower and DirectInput, the game's input merge and mask, a keyboard driver, key bindings, a main menu item | Useful. None of it blocks the fixes. | Step 4 records it. Section 7 proposes what comes next. |
| 2, A | At a UI scale above 1, the mouse lands down and to the right of the window's buttons. Fixed upstream and released as Chronicle 2.1.1. | Accepted as reported | §4b: rebased onto 2.1.1 (done) |
| 2, B | The answers to Q1, Q2 and Q3 | They change step 3 | Section 5, rewritten |

## 2. Which build was tested

The cache status line in the first report names `chronicle 2.1.1`. On the old branch, `_chronicle.dll`
2.1.1 is commit `550e5a1`, which vendors nui 1.4.0. nui 1.4.0 has no HD decode. The branch head at the
time, `8f0c9a5`, shipped `_chronicle.dll` 2.1.2 with nui 1.4.1.

The window drew HD art after a zone, so the DLL that ran must have had the HD fix in it. A local build
that merged the fix without a version bump would explain both facts. I cannot confirm that from here.

The findings still hold, because `src/cache.hpp` is the same in all of these versions. For the retest,
use the build from this plan. Its status line names the new DLL version, which makes the build easy to
identify.

## 3. Step 1: a new atlas format number (nui 1.4.2), built

### Why

An atlas's cache key is the window type, a hash of the install folder, and `kFmtAtlas`. The HD commit
(`5a8b5e1`, now `3dc8da1`) changed what `Assets::load` produces on an HD install, but `kFmtAtlas` stayed at 2. So nui
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

- Here: build the DLL (`sh plugin/build.sh`) and run `python3 sync.py check --dll`. Done, and current.
- On Windows: `sh test/build_render_test.sh` (it needs an unpacked `FFXiMain.dll`). It must pass with
  `atlas.fmt` 3 and the old hashes. Run on 2026-11-27, at format 4 (nui 1.5.0): the atlas hashes match,
  so the HD work changed no stock pixel.
- If the stock hashes moved, the HD commit also changed the stock decode. One candidate: it now keeps
  the first `font    font` chunk, where 1.2.10 kept the last. In that case, look at the frames, then run
  `--update-golden`.
- In game, with the 1.2.10 addon also loaded: Chronicle draws its window body at login, before any zone.
  The cache line in `//cr status` shows `own` above 0. Not run yet.

## 4. Step 2: read the pad config before the hook (Chronicle), built

### Why

`pad_read_config()` runs only in the success branch of `pad_join()`. When `pad_start()` refuses for
good, `retry_at` becomes `math.huge`, so nothing reads the config. The hint line then falls back to
Confirm A and Cancel B, and status says `game pad config: not found`. The registry read does not need
the hook.

### Changes, in `chronicle.lua`

1. `pad_join()` reads the config on its first call, before `pad_start()`. A flag keeps it to one read
   per load.
2. `pad_status_lines()` reads the config if nothing has read it yet.
3. The `//cr pad` message for "not loaded" uses the config. With Enable XInput off, it says so.
   Otherwise the message stays as it is.

No nui change.

### Tests

`test/test_pad.lua` has 8 new checks that use the harness's existing `pad_fail` and `pad_config`
options. On the old code, 5 of them fail and print the report's line exactly. All other Lua suites pass,
apart from the 4 `test_screens` failures the base commit also has on Linux.

## 4b. Chronicle 2.1.1's mouse fix: rebased, done

The second report's Part A: at a UI scale above 1, Windower's mouse event counts in UI pixels, and
Chronicle read it as window pixels. Upstream fixed it and released it as Chronicle 2.1.1. The fix is in
`core/nui.lua`, four lines of `chronicle.lua`, and `test/test_input.lua`, with the harness's fake
Windower taking a UI size.

You synced both forks and chose a rebase (D6). This is what happened.

### Chronicle

- Upstream had re-committed the last three commits of our base. The new `5dffdfa` has the same tree as
  our old base `f9fb5b6`, but `f9fb5b6` is not in the new `master`. So the rebase moved only our own
  twelve commits, onto `master` at `338643d`.
- Two conflicts, both in the first pad commit. `core/ident.lua` keeps 2.2.0. In `chronicle.lua`,
  `//cr status` keeps upstream's new UI scale and mouse factor, followed by the branch's pad lines.
- The result differs from the old branch only by upstream's own changes. Every added and removed line
  matches upstream's diff. `plugin/`, `libs/` and the UI code are unchanged, and `_chronicle.dll` is the
  same blob.
- The mouse is converted in exactly one place, `chronicle.lua:468`. Nothing in `ui/`, `ui/nav.lua` or
  the pad code divides by the view factor again. The 3 px rule that gives the hover back to the mouse
  compares coordinates after that one conversion.
- Upstream's CI steps pass here: every Lua file compiles (3,112 files), and the nine suites pass.
  `test_input` has the report's 85 checks. `test_pad` has 94. `test_screens` has the same 4 Linux-only
  failures as before.

### nui

- `main` gained four upstream commits: CI, badges, and the corrected `screen()` text in
  `docs/lua-api.md`. Our old base `7b566ed` is still in it, so this was a plain rebase.
- The two merge commits (`2745771`, `6862a70`) are gone. The HD commit is now an ordinary commit, with
  its authorship.
- One conflict, in `README.md`. The 1.3.0 commit had saved the file with LF line endings, but upstream
  keeps it CRLF, and `.gitattributes` stores the bytes as they are. So that commit rewrote all 524
  lines. The rebase merged it with the CRs taken out and wrote the result back as CRLF. The 1.3.0
  commit now changes the 11 README lines it means to.
- `src/`, `test/`, `RELEASES` and `VERSION` are identical to the old branch, so the vendored tree hash
  and the 1.4.2 release line still hold. Upstream's CI steps pass: the demo module builds, the frozen
  layouts are unchanged, and the frozen check's self-test passes. The Linux pad tests pass.

## 5. Step 3: hook the game's XInput wrapper (PadHook revision 3, nui 1.5.0), built

Rewritten on 2026-11-26 after the second report. Section 5a says why the first version had to go.

### Why

Today the hook needs the hot-patch form at `xinput1_3.dll!XInputGetState`. Which build of that DLL a
player has depends on which DirectX redistributable installed it. On the test machine the function
starts with `55 8B EC`, so the hook refuses there. It will refuse on every machine with that build.

### What the client does (second report, Q1 and Q2)

- The client does not load Microsoft's DLL. It loads its own shim, `xinputdll.dll`, from the game
  folder. The shim exports `XInputGetState_`, `XInputSetState_` and `XInputEnable_`. It calls
  `xinput1_3.dll` by ordinal.
- The client keeps the shim's handle and its three functions in four slots in a row. In the November
  build they start at `0x104576fc`.
- One wrapper reads the GetState slot, at `0x10008ea0` in both builds. Its bytes are the same in the
  October and November builds, apart from the two slot addresses.
- The wrapper calls the shim as `__cdecl`: `push ecx; push edx; call eax; add esp, 8`.
- While no pad is attached, the client loads the shim again and rewrites all four slots about every
  1.5 seconds. It does the same on each device re-enumeration. The values are the same each time.
- The client's unloader frees the shim and zeros only the handle. Every wrapper tests the handle first.

### 5a. Why the first version would have crashed

The first version put PadHook's thunk in the GetState slot. That thunk jumps to the dispatcher, which is
`__stdcall` and pops its own 8 bytes of arguments. The wrapper then pops the same 8 bytes again. The
stack is off by 8, and the wrapper's `ret 8` returns to a wrong address.

A test on 32-bit Linux ran the real November wrapper bytes. With nobody driving, the old thunk passed
the call through without harm. With a dispatcher driving, the process died with a segmentation fault. A
dispatcher drives as soon as Chronicle joins. The second report's signature route puts the same thunk
in the same slot, so it would crash the same way.

The first version had two more problems. Its value scan used `xinput1_3.dll`, so it would have found
nothing, as the second report says. And each rewrite by the client would have taken the thunk out until
the next check in `pad()`, which would let a frame of presses reach the game.

### The design

1. **Find the wrapper by its signature**, over the code sections of `FFXiMain.dll`, as UiHook finds its
   own:

   ```
   A1 ?? ?? ?? ?? 85 C0 74 1B A1 ?? ?? ?? ?? 85 C0 74 12
   8B 4C 24 08 8B 54 24 04 51 52 FF D0 83 C4 08 C2 08 00
   ```

   It matches the GetState and SetState wrappers. Each match gives two slot addresses: H, the handle,
   and F, the function. The GetState wrapper is the match where F is H + 4. nui needs exactly one such
   match, and both slots must be in a writable section of `FFXiMain.dll`.
2. **Check the slots** when the shim is loaded. H must hold the handle of `xinputdll.dll`, and F must
   hold `GetProcAddress(handle, "XInputGetState_")`. When H is zero, the client has not loaded the shim
   yet: Enable XInput is off, or the pad setup has not run. Then the signature and the slot layout
   decide alone.
3. **Patch the wrapper, not the slot.** The instruction `A1 <F>` (`mov eax, [F]`) at wrapper + 9
   becomes `B8 <thunk>` (`mov eax, thunk`). It has the same length and stays one instruction. One locked
   8-byte compare-and-exchange on the aligned bytes at wrapper + 8 writes it, the way UiHook writes its
   patch. nui refuses if wrapper + 8 is not 8-byte aligned. In both builds it is.
4. **A thunk for a `__cdecl` call:**

   ```
   mov eax, [dispatch]
   test eax, eax
   jz pass
   push [esp+8]        ; copy the two arguments
   push [esp+8]
   call eax            ; the __stdcall dispatcher pops the copies
   ret                 ; the wrapper pops its own
   pass: jmp [F]       ; the client's current function
   ```

   The dispatcher of any revision works through it unchanged.
5. **`bus->original` is a `__stdcall` adapter** in the same block: `push [esp+8]; push [esp+8];
   call [F]; add esp, 8; ret 8`. The dispatcher calls it the same way it calls `XInputGetState` today.
6. **nui pins `xinputdll.dll`** once the client has loaded it. The client's unloader then cannot unload
   it while a call is on its way through the dispatcher. `pad()` does this the first time it finds H
   non-zero.

What this design gets:

- The client's rewrites change nothing. The patch is in code, and the client writes only data.
- No saved pointer can go stale. The pass-through and the adapter read F on every call, and the wrapper
  tests the handle before it calls.
- `pad()` needs no check of the slot, only the one pin.
- The hook installs before the client loads the shim. In DirectInput mode it does nothing, because the
  wrapper returns before its call.

The same 32-bit Linux test ran this design on the real November bytes. The stack stayed balanced in
all four cases: nobody driving, a dispatcher driving, the client rewriting F between calls, and a zero
handle.

### When the wrapper route fails

The wrapper route fails in any of these cases:

- no unique match
- a slot outside a writable section
- wrong values in the slots
- bytes that changed while nui patched them

nui then tries the current export hot patch, with its current refusals, and status gives both reasons.
The 5-byte detour from the first report stays out of the plan.

### Unloading

The patch is never undone, like UiHook's. With nobody driving, the thunk passes every call through.
Decision D3 no longer applies, because there is no pointer to write back.

### Changes to the bus (ABI 1, revision 3)

- `PadBus::reserved_hdr` gets `route`: 0 for the export hot patch, 1 for the client's wrapper. On route
  1, `site` holds the wrapper's address and `original` holds the adapter. Zero means the revision 2
  behaviour.
- The thunk block grows from 64 to 128 bytes for the adapter. The block is not part of the frozen
  layout.
- `test/layout_padhook.txt` changes only in its `reserved*` lines, and `test/frozen_check.py` must pass.
- A revision 2 module that joins later registers as before. Its `__stdcall` dispatcher works through
  the new thunk, and it calls the adapter as its original.
- `blocked`: a revision 3 module tries the wrapper route even when a revision 2 module has set it, and
  clears it on success.

### Status and wording

- `describe` reads, for example: `live at FFXiMain's XInput wrapper 10008EA0; 1 client: chronicle r3
  (drives)`. While H is zero, it adds that the client has not loaded `xinputdll.dll` yet.
- The nui README says that nui "never writes to the game". With this route nui patches two places in
  the client's code: the EndScene wrapper (UiHook) and the XInput wrapper (PadHook). The README and
  `docs/abi.md` will say that plainly.

### Tests

Here, on 32-bit Linux (`test/pad_linux/run.sh`), with the real bytes from the second report:

- The signature over both builds, with the three wrappers laid out at +0x00, +0x30 and +0x60. It picks
  GetState by F = H + 4. It refuses no match, two GetState matches, and a wrapper + 8 that is not
  aligned.
- The patched November wrapper, executed. Calls go through the thunk and PadHook's own `dispatch()`
  into a `__cdecl` stand-in for the shim. The cases: nobody driving, a dispatcher driving, the mask and
  chord rules, a rewrite of F between calls, and a zero handle. Every call checks that the stack is
  balanced. The stand-in `windows.h` gets a `GetCurrentThreadId` stub for this.
- The old thunk in the slot, run in a child process. It must crash. That keeps the reason for this
  design in the tests.

On Windows (`test/build_pad_test.sh`, which builds here):

- A stand-in for the game. It carries the exact wrapper bytes and its own four slots, and a stand-in
  `xinputdll.dll` (`__cdecl`, underscore names) that calls `pad_fake_nohot.dll`. That fake is not
  hot-patchable, which is the field case.
- Every existing mask, chord and heartbeat check runs through the stand-in's wrapper. The export's
  bytes must stay as they were.
- A stand-in with no matching wrapper: the export route runs on `pad_fake_xinput.dll` and refuses on
  `pad_fake_nohot.dll`, as today.
- The handover test for a higher revision moves from revision 3 to revision 4.
- New fault builds for `--self-test`: the old thunk on this route, and a scan that takes the first
  match.

Wine did not start in this container last time. The build session will try it again, for no more than
half an hour. After that, the Windows run is yours.

In game, on the machine that refused:

1. `//cr pad status` says `live at FFXiMain's XInput wrapper`.
2. Start the game with no pad attached, then plug one in. The hook must still hold the pad, because the
   client re-enumerates and rewrites its slots then.
3. The open checks from `docs/controller-handoff.md` §6: the chord, an L3 tap, R3 held, the HD art.

### Release

`python3 sync.py release 1.5.0`. It is a new minor version because PadHook gains a revision. Then, in
Chronicle: sync and rebuild `_chronicle.dll` as 2.1.4.

The release also corrects the comment above `l_screen` in `src/host.cpp`. It says that `w` and `h` are
"mouse / Windower pixels", and the second report shows that mouse pixels are UI pixels. A vendored
source change belongs in a release, so it waits for this one. Upstream already corrected the same
sentence in `docs/lua-api.md`.

## 5b. What the build changed from this design

A review of the change found no crash path, and the Linux tests pass. These points differ from the
design above:

- **The thunk and the adapter test F for zero.** The patch takes away the wrapper's own test of F. If
  the client had written H but not F yet, the first design would have called address zero. Both now
  return 1 then, as the wrapper itself does.
- **The signature is 44 bytes.** It runs through the wrapper's fail path (`B8 01 00 00 00 C2 08 00`), so
  the value the thunk returns without F is the client's own by construction.
- **The `blocked` rule.** To revision 3, `blocked` means only that route 0 is refused for good.
  `pad_start()` stops asking for a retry only when route 1 is refused for good as well. Before this, a
  route 1 failure that can pass (the client writing its slots at that moment) could block the hook for
  the whole session. Slots that hold other values on three tries count as refused for good.
- **The pin is retried.** A handle that was not the shim is checked again once a second, so a read
  between the client's FreeLibrary and its zeroing of H cannot stop the pin for good.
- **`//cr pad` needs a Chronicle change** (`dec423c`). On route 1, `pad_start()` succeeds also in
  DirectInput mode. `//cr pad` now checks `pad_status().shim` and says why it cannot take the pad,
  instead of taking a pad that sends nothing.
- **More in 1.5.0 than planned.** It carries `3259cf9` and `871a167` from `hd-texture-packs` (as
  `d386009` and `4c5d3a1`). The box filter fix changes HD pixels, so the atlas format moves to 4. You
  confirmed that. CI runs `test/pad_linux` and builds `test/build_pad_test.sh`.
- **Wine still does not start** in this container (`free(): invalid pointer`, in the 32-bit and the
  64-bit wineserver). A session on your Windows machine ran the Windows pad suite instead, on
  2026-11-27. Its first run found two bugs in the tests and none in PadHook. After the fix (`6b821c8`,
  `test/` only), all 7 modes pass and all 8 faults are caught.

## 6. Step 4: documentation, built

- `docs/controller-support.md`: the Status header records the new route. §8 records that Windower wraps
  DirectInput8 and has no XInput code. That closes the chaining risk for the XInput route. The risk
  stays open for Phase 5, the DirectInput route.
- The research from both reports goes into `docs/controller-support.md` §3. Addresses are marked with
  their build, to be found by signature and never by address. That includes the client's shim, its
  reload every 91 polls, and the calling convention.
- `docs/controller-handoff.md`: versions, commits, the verification table, and what is left.
- nui: the header comment in `src/PadHook/PadHook.h`, the PadHook 1 section of `docs/abi.md`,
  `docs/lua-api.md` (`pad_status().route`), and the README's pad paragraphs.
- Chronicle README, "With a controller": the paragraph that names the hot patch.

## 7. Not in this round: the first report's §5

Each item is worth doing. None is needed for the fixes. My recommended order:

1. **A keyboard driver, in Lua only. Built on 2026-11-27** (`d4417ad`). K takes the keys and gives them back
   (`docs/controller-handoff.md` §3). This is Phase 1 of the original plan. Windower's `keyboard` event
   can already keep a key from the game, and `ui/nav.lua` works with any input. It needs no native
   code. It also covers players whose pad Steam Input, DS4Windows or reWASD maps to keys.

   It needs a key or chord that takes control and gives it back. The first report lists D, G, K and O
   as free in the stock English menu bindings. I recommend it as the next piece of work after these
   fixes.
2. **Avoid the player's key bindings** with the keyboard's chord. The second report (Q3) found that ids
   74 to 137 are not in the registry or in `cnf.dat`, only in memory. Reading them needs native code and
   a signature. The report adds that the retail client may offer no keyboard remapping at all. In that
   case a fixed table of the stock bindings is enough. Nobody has confirmed that from the game's menus
   yet.
3. **The game's logical axes and input mask** (`Input_GetAxisValueMerged`, and `FUN_10124b70`, which
   writes the mask). One path would cover every device. It is a larger change. The game writes that
   mask itself from sixteen places, so nui would have to share it with the game. It deserves a design
   note before Phase 5 starts.
4. **A "Chronicle" item in the game's main menu.** Two things are unknown: whether the element array can
   take a sixteenth item, and whether `Cmd_ExecuteLine` reaches a Windower command. Both need a test in
   game first.

The mouse offset is no longer an open question. It was not Wine. §4b brings in the fix.

## 8. Questions for the test agent: answered

The second report (2026-11-26) answered all three.

- **Q1.** The client loads its own `xinputdll.dll`, not `xinput1_3.dll`. It rewrites all four slots at
  input init, on each re-enumeration, and about every 1.5 seconds while no pad is attached. Nothing
  zeros the function slots. The unloader zeros only the handle.
- **Q2.** The wrapper's bytes for both builds, and a signature that gives both slots. The code address
  is the same in both builds.
- **Q3.** The key bindings are not in the registry or in `cnf.dat`.

One new question, for the second report's author: does `xinputdll.dll` do anything besides call
`xinput1_3.dll`? The new design always calls through the shim, so the answer does not block step 3.

## 9. Decisions

| | Decision | State |
|---|---|---|
| D1 | How step 3 hooks the client | **Changed, and approved.** It was "find the pointer by value". The second report showed that this finds nothing, and section 5a shows that a thunk in the slot crashes the game. Now: find the wrapper by its signature, and patch its load of the slot. |
| D2 | Keep the export hot patch as a fallback, or remove it and keep one route | Keep it. Unchanged. |
| D3 | On unload, leave the thunk in the game's pointer, or write the old pointer back | No longer applies. The patch is in code and is never undone, like UiHook's. |
| D4 | Two test builds (steps 1 and 2, then step 3), or one build with all three | Two. Build 1 is ready. Build 2 gets step 3 and the mouse fix. |
| D5 | The keyboard driver: after this round, or in it | After. Unchanged. |
| D6 | Bring in Chronicle 2.1.1 by a merge or a rebase, and from a synced fork or from the upstream repository | A rebase, onto the synced forks. Done (§4b). |

## 10. Commits, and the retest

All new commits use the author Toboshii Nakama, with no trailers. The rebase kept every commit's author.

nui, on `claude/chronicle-workstreams-review-dp0k36`, then on `ccr-d3a8994b-5t63ba`:

1. `nui 1.4.2: ...` (step 1), `d8d94e5`. Done.
2. `assets: a clear block keeps its colour ...`, `d386009`, and `test: an HD texture pack loads as the
   stock art, on Linux`, `4c5d3a1`. Picked from `hd-texture-packs`. Done.
3. `nui 1.5.0: ...` (step 3: PadHook revision 3, its tests, the docs, the `l_screen` comment, the
   release), `50d18a6`. Done.
4. `test: the stand-in shim reads the fake that the pad test pressed`, `6b821c8`. Done.

Chronicle, on the same branch names:

1. `nui 1.4.2: ...` (the sync, `_chronicle.dll` 2.1.3), `1fd1bb6`. Done.
2. `pad: ...` (step 2), `8591a96`. Done.
3. The rebase onto Chronicle 2.1.1 (§4b). Done.
4. `nui 1.5.0: ...` (the sync, `_chronicle.dll` 2.1.4), `c8ac1c6`. Done.
5. `pad: //cr pad says why when the game is not reading XInput`, `dec423c`. Done.
6. `docs: ...` (step 4). Done.

### Old and new hashes after the rebase

| Repo | Old | New | Commit |
|---|---|---|---|
| nui | `7b566ed` | `8b2e53c` | the base: upstream `main` |
| nui | `32e8138` | `06bb59c` | nui 1.3.0 |
| nui | `294b75a` | `6a81de5` | nui 1.4.0 |
| nui | `5a8b5e1` | `3dc8da1` | assets: the HD texture pack |
| nui | `2745771`, `6862a70` | none | the two merge commits, dropped |
| nui | `2dae3a5` | `edaab6a` | nui 1.4.1 |
| nui | `cf75bf8` | `429c39a` | test: PadHook on 32-bit Linux |
| nui | `6e72c8b` | `d8d94e5` | nui 1.4.2 |
| Chronicle | `f9fb5b6` | `338643d` | the base: upstream `master` (2.1.1, CI, badges) |
| Chronicle | `646ca78` | `dab42fe` | docs: the controller plan |
| Chronicle | `58b6c16` | `034d2ef` | pad: the controller |
| Chronicle | `550e5a1` | `861c03f` | pad: L3 + R3 kept from the game |
| Chronicle | `8f0c9a5` | `889017e` | nui 1.4.1 |
| Chronicle | `f9fd254` | `6a5a178` | docs: the handoff |
| Chronicle | `867e46a` | `92e6990` | docs: the plan's hash in the handoff |
| Chronicle | `8d47c38` | `5f03c0a` | docs: this plan |
| Chronicle | `4f5b545` | `1fd1bb6` | nui 1.4.2 |
| Chronicle | `7749b0f` | `f3f1806` | docs: decisions, step 1 |
| Chronicle | `851707f` | `8591a96` | pad: the config read |
| Chronicle | `7f76a66` | `ac2a3f5` | docs: steps 1 and 2 |
| Chronicle | `5771205` | `8fc37ec` | docs: step 3 redesigned |

Older commit messages still name old hashes, for example nui 1.4.1's mention of `5a8b5e1`. A rebase
cannot change them without rewriting the messages, so this table is the key.

### Retest with build 1 (steps 1 and 2)

1. Log in with both nui addons loaded. Chronicle draws its window body and the HD art at login.
2. `//cr status`: the cache line names `chronicle 2.1.3` and shows `own` above 0.
3. `//cr pad status`, with the hook still refused: the config line names the registry key and the
   player's real Confirm and Cancel.

### Retest with build 2 (step 3 and the mouse fix)

Done, 2026-11-27. Items 1 to 7 work in game, by your report. Item 8 is in the handoff's §4.

1. `//cr pad status`: `live at FFXiMain's XInput wrapper`.
2. Start with no pad attached, then plug one in. Chronicle still takes the pad with L3 + R3.
3. The open checks in `docs/controller-handoff.md` §6.
4. At UI Scale 1.5, clicks, drags and resizes land where the cursor is.
5. Mouse and keyboard still work while the pad is held and after it is given back.
6. `//cr status`: the cache line names `chronicle 2.1.4`. With the 1.2.10 addon loaded, Chronicle still
   draws its window body and the HD art at login.
7. With Enable XInput off in the FFXI Config: `//cr pad` says so, and does not take the pad.
8. On Windows, from nui: `sh test/build_pad_test.sh --self-test` (passes, 2026-11-27) and
   `sh test/build_render_test.sh --self-test` (run 2026-11-27: every golden atlas, icon and picture hash
   matches at format 4, and all 40 faults are caught. `wt`'s frame crops differ on that machine with
   upstream's own code too, and `pd`'s timing misses on a cold first run. See the handoff's §4).
