# Handoff: the remaining controller and HD texture work

> Done, 2026-11-26: the session this prompt started built sections 4.1 to 4.3, on the branch
> `ccr-d3a8994b-5t63ba` in both repositories. `docs/controller-handoff.md` has the state now. The items
> in section 4.4 still wait on the user.

Paste everything below the line into a new session that has `toboshii/ffxi-chronicle` and `toboshii/nui`
attached.

---

You are continuing work on two repositories: `toboshii/ffxi-chronicle` (Chronicle, a Windower 4 addon for
Final Fantasy XI) and `toboshii/nui` (the drawing library that Chronicle vendors in `plugin/nui`). Both are
forks of `jintawk/*`. Two work streams are in flight: controller support, and UI art from HD texture packs.
A previous session reviewed two test reports, fixed what they found, rebased both branches and prepared an
upstream PR. Your job is the work that is left, listed in section 4.

## 1. Read these first, in this order

1. `docs/test-findings-plan.md` (Chronicle). This is the current plan and the source of truth. Section 5 is
   the design for step 3. Section 9 lists the decisions, which are all taken. Section 10 maps old commit
   hashes to new ones.
2. `docs/controller-handoff.md` (Chronicle). It describes the controller architecture and the working
   environment. Its hashes name commits on the old branch `claude/controller-support-plan-yjc276`, which
   still exists. Use the map in the plan to find them on the review branch.
3. `docs/controller-support.md` (Chronicle). The original research and plan.
4. `src/PadHook/PadHook.h`, `src/pad.cpp` and `src/UiHook/UiHook.h` (nui). UiHook already finds a wrapper
   in `FFXiMain.dll` by signature and patches it with one locked 8-byte write (`write_site`). Reuse that
   approach.

## 2. Where things stand

| Repo | Branch | Head | What it holds |
|---|---|---|---|
| Chronicle | `claude/chronicle-workstreams-review-dp0k36` | `3a7fa21` | The controller feature, nui 1.4.2 vendored, `_chronicle.dll` 2.1.3, the pad config fix, and the docs. Rebased onto upstream `master` (`338643d`, Chronicle 2.1.1 with the mouse fix). Addon version 2.2.0. |
| nui | `claude/chronicle-workstreams-review-dp0k36` | `d8d94e5` | PadHook revisions 1 and 2 (nui 1.3.0 and 1.4.0), the HD decode (1.4.1), the atlas format 3 (1.4.2). Rebased onto upstream `main` (`8b2e53c`, nui 1.2.10 plus CI and docs). |
| nui | `hd-texture-packs` | `871a167` | The upstream PR branch for the HD work, on upstream `main`, with four commits and no release commit. The PR is not open yet. The user opens it. |
| nui | `claude/hd-texture-packs` | `871a167` | A stale copy. The user deletes it, because the proxy refuses branch deletes. Do not use it. |

Continue on `claude/chronicle-workstreams-review-dp0k36` in both repositories. If your session assigns a
different branch, create it from that head.

Test build 1 (steps 1 and 2 plus the mouse fix) went to the user as a zip. Nobody has run it in game yet.

## 3. Rules for this work

- Commit as `Toboshii Nakama <toboshii@gmail.com>`. Set `user.name` and `user.email` in both repositories
  first. Add no `Co-Authored-By` or session lines to commits, and no attribution or session links to PR text.
- Use the `ste80-humanizer` skill for all text a person reads: commit messages, docs, PR descriptions.
  Write short sentences in the active voice, with no em dashes and no semicolons in prose.
- Commit subjects are "area: a plain sentence" (`pad:`, `docs:`, `cache:`, `test:`). A nui release is one
  commit named `nui x.y.z: ...` with the code, `VERSION`, `RELEASES` and `src/nui_version.h`. A Chronicle
  sync is one commit named `nui x.y.z: ...` with the vendored copy and the rebuilt DLL.
- Frozen layouts: add new bus fields only in the reserved tails, and zero must mean the old behaviour.
  `python3 test/frozen_check.py` must pass.
- Never push to nui `main` or Chronicle `master`. Open no PR unless the user asks. Rewrite pushed history
  only with the user's permission, and then with `--force-with-lease` on the exact old head.
- Do not put model names in commits, docs or PR text.

## 4. The work left

### 4.1 Step 3: hook the client's XInput wrapper (PadHook revision 3, nui 1.5.0)

The design is in the plan's section 5, and the user approved it (D1). Read 5a first: putting PadHook's
current thunk into the client's pointer crashes the game. The client calls that pointer as `__cdecl`, but
the dispatcher is `__stdcall`.

The facts below come from the test agent's second report. The new session does not have that report, so
they are repeated here.

- The client loads its own shim, `xinputdll.dll`, from the game folder (6,656 bytes). It exports
  `XInputEnable_` (ordinal 1), `XInputGetState_` (2) and `XInputSetState_` (3). It imports `XINPUT1_3.dll`
  by ordinal: 5, 3 and 2. Its functions are `__cdecl`.
- The client stores the shim's handle and the three functions in four slots in a row:

  | Build | Handle | GetState | SetState | Enable |
  |---|---|---|---|---|
  | November 2026-11-02 | `0x104576fc` | `0x10457700` | `0x10457704` | `0x10457708` |
  | October 2026-10-13 | `0x1045654c` | `0x10456550` | | |

- One wrapper reads the GetState slot. It is at `0x10008ea0` in both builds. November bytes:

  ```
  A1 FC 76 45 10 85 C0 74 1B A1 00 77 45 10 85 C0
  74 12 8B 4C 24 08 8B 54 24 04 51 52 FF D0 83 C4
  08 C2 08 00 B8 01 00 00 00 C2 08 00 90 90 90 90
  ```

  The October bytes are the same apart from `4C 65 45 10` and `50 65 45 10` in place of the two slot
  addresses.
- The signature is
  `A1 ?? ?? ?? ?? 85 C0 74 1B A1 ?? ?? ?? ?? 85 C0 74 12 8B 4C 24 08 8B 54 24 04 51 52 FF D0 83 C4 08 C2 08 00`.
  It matches the GetState wrapper (+0x00) and the SetState wrapper (+0x30). The Enable wrapper (+0x60) has
  another shape. In the GetState match, the second address (F) is the first (H) plus 4. In the SetState
  match, it is H plus 8.
- The client writes all four slots in its pad setup (`0x100083d0`), when Enable XInput (`0x10456de8`) is
  on. That happens at input init, on each device re-enumeration, and about every 1.5 seconds while no pad
  is attached. The values are the same each time. The unloader (`0x10008e70`) frees the shim and zeros
  only the handle. Every wrapper tests the handle first.

These are the bytes the previous session verified by running the real November wrapper on 32-bit Linux:

```
patch at wrapper + 9:  A1 <F>  ->  B8 <thunk>        written by one InterlockedCompareExchange64 on wrapper + 8 (8-aligned)

thunk (26 bytes):      A1 <&dispatch>                mov eax, [dispatch]
                       85 C0 74 0B                   test eax, eax / jz pass
                       FF 74 24 08 FF 74 24 08       push [esp+8] twice
                       FF D0 C3                      call eax / ret
                       FF 25 <F>                     pass: jmp [F]

adapter (20 bytes),    FF 74 24 08 FF 74 24 08       push [esp+8] twice
bus->original:         FF 15 <F>                     call [F]
                       83 C4 08 C2 08 00             add esp, 8 / ret 8
```

In that run, the stack stayed balanced in every case: nobody driving, a dispatcher driving, F rewritten
between calls, and a zero handle. The current revision 2 thunk in the slot crashed as soon as a dispatcher
drove. The probe file was in that session's scratch space and is gone, so rebuild it as a test in
`test/pad_linux/`.

What to build, all in nui on the review branch:

1. In `PadHook.h`:
   - The signature search over FFXiMain's code sections, with exactly one GetState match.
   - The slot checks: both slots writable; once H is non-zero, H holds the handle of `xinputdll.dll` and F
     holds `GetProcAddress(H, "XInputGetState_")`.
   - The patch, the thunk and the adapter, with the block grown to 128 bytes.
   - `route` in `PadBus::reserved_hdr`.
   - The pin of `xinputdll.dll` once H is non-zero, done from `pad()`.
   - The fallback to the current export hot patch.
   - The new `describe` text.
   - The rule for `blocked` from plan 5.
2. In `src/pad.cpp`: `pad_status().route`, and the pin.
3. Tests:
   - `test/pad_linux`: the signature over both builds, and the real wrapper bytes executed through the
     thunk, the real `dispatch()` (add a `GetCurrentThreadId` stub) and a `__cdecl` stand-in shim, with
     stack checks. Also the old thunk, which must crash in a child process.
   - `test/build_pad_test.sh`: a stand-in game DLL with the exact wrapper bytes, a stand-in `__cdecl`
     `xinputdll.dll` over `pad_fake_nohot.dll`, the handover test moved to revision 4, and new fault
     builds.
4. Also in 1.5.0:
   - Cherry-pick `3259cf9` (the box filter keeps a clear block's colour) and `871a167` (`test/hd_linux`, its
     CI step and README paragraph) from `hd-texture-packs`. `README.md` is CRLF and `.gitattributes` is
     `* -text`, so keep the CRLF endings.
   - Then set `kFmtAtlas` to 4, with `golden_fmt.json` and the `abi.md` rule to match. Testers already have
     1.4.2 with format 3, and the fix changes HD pixels. The user did not object to this, but confirm it
     with them before you release.
   - Correct the comment above `l_screen` in `src/host.cpp`. Mouse pixels are UI pixels, not window
     pixels. Upstream fixed the same sentence in `docs/lua-api.md`.
5. `python3 sync.py release 1.5.0`. Then sync into Chronicle and rebuild `_chronicle.dll` as 2.1.4. That
   includes the version strings in `plugin/ChronicleModule.cpp`, `test/harness.lua` and
   `test/test_load.lua`.

### 4.2 Step 4: documentation

The list is in plan section 6. In short:

- `docs/controller-support.md`: the Status header and the research.
- `docs/controller-handoff.md`: a full refresh for the review branch.
- nui: the PadHook sections of `PadHook.h`, `docs/abi.md`, `docs/lua-api.md` and the README.
- Chronicle's README: the controller paragraph.

The nui README says nui "never writes to the game". With this route, nui patches two places in the
client's code, and the README must say that plainly.

### 4.3 Test build 2

Make it with `git archive --format=zip --prefix=chronicle/ -o <zip> HEAD` from the Chronicle root and send
it to the user. The retest list is in plan section 10.

### 4.4 Waiting on the user, not on you

- Open the HD PR at `https://github.com/jintawk/nui/compare/main...toboshii:nui:hd-texture-packs`. The user
  has the description, and the title is "Read the UI art from an HD texture pack". If they ask you for the
  text again, rebuild it from the four commits' messages.
- Delete `claude/hd-texture-packs` on the fork.
- Run build 1 in game, and run `sh test/build_render_test.sh` and `sh test/build_pad_test.sh --self-test`
  on Windows.
- After the HD PR merges upstream, rebase the review branch onto upstream `main`. Git should skip the HD
  decode commit as already applied. The 1.4.2 commit will conflict in `cache.hpp` and `abi.md`. The fork's
  release numbers (1.3.0 to 1.5.0) will not match upstream's, so agree that with the user then.

### 4.5 Not in this round

The keyboard driver (D5) and the rest of plan section 7.

## 5. Working in the container

- Install the toolchain first: `apt-get install -y g++-mingw-w64-i686 lua5.1 g++-multilib`. Wine does not
  start in this container. Try it for no more than half an hour, then leave the Windows runs to the user.
- Build the DLL with `sh plugin/build.sh` from the Chronicle root. Check it with
  `python3 sync.py check --dll ../ffxi-chronicle/libs/_chronicle.dll` from nui. Two builds of the same
  source differ in many bytes, so compare the `NUI-TAG` string and the git blobs, never the bytes.
- `sync.py` resolves consumer paths from the directory above the nui checkout's parent. Add
  `user/ffxi-chronicle/plugin/nui` to `consumers.txt`, run `python3 sync.py release <v>` or `sync`, then
  `git checkout consumers.txt`. Never commit that line.
- Lua tests: `export TEMP=<scratch dir>`, then `lua5.1 test/<name>.lua` from the Chronicle root. Delete the
  file named `nul` that the harness leaves, and never commit it. Upstream CI runs `test/syntax_check.lua`
  and nine suites, listed in `.github/workflows/tests.yml`. `test_screens` has 4 known Linux-only failures.
  `test_load` cannot load the Windows DLL on Linux.
- nui tests here: `sh test/pad_linux/run.sh`, `sh test/hd_linux/run.sh`,
  `NUI_GXX=i686-w64-mingw32-g++ sh example/build.sh`, and `python3 test/frozen_check.py` with and without
  `--self-test`.
- Push nui with `git -c push.negotiate=true push`. The proxy refuses branch deletes with a 403. Report that
  to the user instead of trying again.
- Chronicle's `docs/` is in `.gitignore`, so add files there with `git add -f`.
- `jintawk/nui` cannot be attached next to `toboshii/nui`, because both check out to `nui`. The GitHub
  connection cannot reach it either. The user opens upstream PRs.
