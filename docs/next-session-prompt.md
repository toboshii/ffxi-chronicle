# Prompt: a keyboard hook in nui, then the rest

You continue the work on two repositories: `toboshii/ffxi-chronicle` (Chronicle, a Windower 4 addon for Final
Fantasy XI) and `toboshii/nui` (the drawing library that Chronicle vendors in `plugin/nui`). Both are forks of
`jintawk/*`. The controller support and the keyboard driver are built, tested and confirmed in game. Your first
job is a keyboard hook in nui, so that Chronicle hides only its own keys from the game. After it, do the items in
section 6.

## 1. Read these first, in this order

1. `docs/controller-handoff.md` (Chronicle). It is the current state: branches, commits, the architecture,
   every test result, how to work in the container and on the user's Windows machine, and what is left. Read §3
   (the keyboard driver and the pad hook), §4 and §7 closely.
2. `docs/controller-support.md` (Chronicle): §3 is the research on how the game reads its input, and §4 is the
   navigation model.
3. `docs/test-findings-plan.md` §5 (Chronicle). It is the design of PadHook revision 3, the closest model for a
   keyboard hook: a signature in `FFXiMain.dll`, one patched instruction, a shared bus, and fail-closed checks.
4. In nui: `src/PadHook/PadHook.h`, `src/pad.cpp`, `src/host.cpp` (the Lua table), `abi.md`, and the Linux tests
   in `test/pad_linux/`.
5. In Chronicle's `chronicle.lua`: the "The keyboard" section (`kbd`, `kbd_down`, `kbd_block`, `kbd_want_block`,
   `kbd_set_block`) and the `keyboard` event.

## 2. Where things stand

| Repo | Branch | Head | What it holds |
|---|---|---|---|
| Chronicle | `ccr-bfbc0043-hhlj8v`, `ccr-d3a8994b-5t63ba`, `claude/chronicle-workstreams-review-dp0k36` | the commit that adds this prompt (on `ccr-bfbc0043-hhlj8v`). The other two are at `b24f027`, one commit behind. | The controller, the keyboard driver, the choosable nav key and controller chord, auto-hide, nui 1.5.0 vendored, `_chronicle.dll` 2.1.4, the docs. On upstream `master` `338643d`. |
| nui | the same three branches | `6b821c8` | PadHook revisions 1 to 3 (fork releases 1.3.0 to 1.5.0) and the HD texture pack work. On upstream `main` `8b2e53c`. |
| nui | `controller-pad-hook` | `79bb531` | Open PR on `jintawk/nui`: "Read and hold the controller the game reads". |
| nui | `hd-texture-packs` | `871a167` | Open PR on `jintawk/nui`: "Read the UI art from an HD texture pack". |

Continue from `ccr-bfbc0043-hhlj8v`'s head in both repositories. If your session assigns a different branch,
create it from that head. Do not change `controller-pad-hook` or `hd-texture-packs` unless the user asks.

## 3. Rules for this work

- Commit as `Toboshii Nakama <toboshii@gmail.com>`. Set `user.name` and `user.email` in both repositories
  first. Add no `Co-Authored-By` or session lines to commits, and no attribution or session links to PR text.
- Use the `ste80-humanizer` skill for all text a person reads: commit messages, docs, PR descriptions and
  prompts. Run its checker (`scripts/ste_check.py`) on docs and PR text. Write short sentences in the active
  voice, with no em dashes and no semicolons in prose.
- Commit subjects are "area: a plain sentence" (`keys:`, `pad:`, `docs:`, `test:`). Wrapped bodies say why.
- A nui release is one commit named `nui x.y.z: ...` with the code, `VERSION`, `RELEASES` and
  `src/nui_version.h`. A Chronicle sync is one commit named `nui x.y.z: ...` with the vendored copy and the
  rebuilt DLL.
- Frozen layouts: a new bus gets its own frozen layout from its first release. Add new fields to any bus only in
  its reserved tail, and zero must mean the old behaviour. `python3 test/frozen_check.py` must pass.
- Never push to nui `main` or Chronicle `master`. Open no PR unless the user asks. An upstream PR branch has no
  `claude/` or `agent/` prefix, names its purpose, and carries no plans or handoffs (`docs/`).
- Rewrite pushed history only with the user's permission, and then with `--force-with-lease` on the exact old head.
- Do not put model names in commits, docs or PR text.
- The user likes work they can test in game: give a test zip and a short checklist for each build.

## 4. The work: a keyboard hook in nui

### Why

Chronicle's keyboard driver has to keep the keys it uses from the game. In game, a `true` return from
Windower's `keyboard` event keeps no key from the game. A tap of an arrow turns the camera, and Page Up and Page
Down zoom it. A letter typed in Chronicle's search box opens the game's menu for that letter. So Chronicle sends
Windower's `keyboard_blockinput 1` while it holds the keys or the search box has focus, and `0` after. That works,
and the user tested it. It has three costs:

1. No key reaches the game, so the player cannot chat, use a macro or press an F-key in nav mode.
2. Windower runs no bind under the block. That is why the nav key is Chronicle's own setting.
3. The block is global Windower state. Another addon, or the player, may use it too.

A hook that hides only Chronicle's keys (the nav keys, the nav key itself, and the search box's keys while it has
focus) removes all three.

### What is known

- Windower 4 wraps DirectInput8, and the game reads the keyboard through DirectInput8. Windower 4's core is
  closed source. Fenestra, its open successor, wraps the DirectInput keyboard device, and its source may show
  how such a wrapper works.
- Windower's `keyboard` event still fires under `keyboard_blockinput 1`, and a bind keeps its key from the game.
  So Windower sees the keys before the game does.
- PadHook revision 3 hooks the game's own XInput wrapper in `FFXiMain.dll`, found by a 44-byte signature, and
  changes one instruction there. That pattern worked on every client build tried, and it chains through
  whatever the game calls.
- The test reports name `FUN_10124b70`, which writes the game's input mask from sixteen places, and
  `Input_GetAxisValueMerged`. They may matter for the keyboard too.
- Nobody knows yet whether the game reads the keyboard with `GetDeviceState` (a 256-byte array), with
  `GetDeviceData` (buffered events), or both. A tap moved the camera, so the game also acts on a key's press.

### Phase 0: research, then decide with the user

Answer these before you write hook code. The cloud container has no copy of the client. Do the research on the
user's Windows machine ("Lego"), through its "Remote control" session (§5). Use the plain copy of `FFXiMain.dll`
there and the 32-bit MSYS2 tools (`objdump`). Ask that session to check with the user before it
installs anything new, such as a disassembler.

1. How does `FFXiMain.dll` get its keyboard device? Find the `DirectInput8Create` import or `GetProcAddress`, the
   `CreateDevice` call with `GUID_SysKeyboard`, and where the game keeps the device pointer.
2. Where does the game read it? Find the calls through the device's vtable at `GetDeviceState` (offset `0x24`) and
   `GetDeviceData` (offset `0x28`) for that device. Which one, or both, how often, and from which thread?
3. Is there one small wrapper or call site, like the XInput wrapper, that a signature can find and one instruction
   can redirect? Give its bytes for the 2026-11-02 build, and a signature with its wildcards.
4. With Windower loaded, is the device the game calls Windower's wrapper object? A hook at the game's call site
   would then sit after Windower. Windower's events and binds would keep working, because Windower has already
   seen the key.
5. Does `FUN_10124b70`'s input mask offer a simpler, sanctioned way to stop the game acting on a key?

Write the answers into a short research note in Chronicle's `docs/` (force-added). Then use the `AskUserQuestion`
tool to agree on these, with a recommendation for each:
- **Where to hook:** the game's call site (recommended if question 3 finds one), the device vtable filtered by
  `this`, or the input mask.
- **Which keys to hide:** the nav keys while nav mode holds them, and the nav key itself. While the search box has
  focus: every key, or only the keys it types.
- **What Chronicle does when nui refuses the hook, or the DLL has none:** fall back to `keyboard_blockinput` (recommended), or no
  blocking at all.

### Phase 1: build it in nui

Model it on PadHook. A likely shape, to confirm against the research:
- **A shared bus**, `Local\FFXiKeyHook_v1_<pid>`, built the way PadHook's is. There is one patch per process,
  and the live module with the highest revision drives. The thunks are in a block that nui never frees. With
  nobody driving, the thunks pass every call through.
- **Per-client masks** of DirectInput key codes to hide (256 bits), set from Lua, with a heartbeat. A hold that
  Lua does not renew within 250 ms lapses, so a stalled or crashed Lua never leaves keys hidden.
- **The press rules in native code,** as for the pad:
  - A key the game already saw go down stays the game's until its release.
  - A key hidden at its press stays hidden until its release, even after Lua stops hiding it.
  - For `GetDeviceState`, clear the hidden keys' bytes. For `GetDeviceData`, drop or rewrite the hidden keys'
    events, with care for the buffer count.
- **Fail-closed checks:** exactly one signature match, the expected bytes, a writable slot. Otherwise
  patch nothing and say why in the status.
- **A Lua API** in `host.cpp`'s table, for example `key_start()`, `key_hide(list of codes or a mask string)` (also
  the heartbeat), `key_status()` and `key_stop()`, with `stop()` and `host_detach` releasing it.
- **A frozen layout** for the new bus from its first release (`test/layout_keyhook.txt` and
  `test/frozen/layout_keyhook.<version>.txt`).
- **Tests:** a Linux stand-in like `test/pad_linux`, for the logic and the patch on 32-bit Linux. Also a Windows
  test against stand-ins for the device and the game's call site, with fault builds, run on Lego.
- **A nui release**, for example 1.6.0, then the Chronicle sync with a rebuilt `_chronicle.dll` (for example
  2.1.5). Check the DLL with `python3 sync.py check --dll ../ffxi-chronicle/libs/_chronicle.dll` from nui.

### Phase 2: use it in Chronicle

- When `key_start` succeeds, `kbd_block` hides only the keys it wants through the hook, and sends no
  `keyboard_blockinput`. When nui refuses the hook, or the DLL has none, it falls back to `keyboard_blockinput` as now.
- Chat, macros and Windower binds then work in nav mode. Decide with the user whether the chat-open rule and the
  Ctrl or Alt rule stay as they are.
- `//cr nav status`, or a line in `//cr status`, says how Chronicle keeps the keys: the hook, or the block, and why.
- `test/test_keys.lua` keeps its BLOCK-* checks for the fallback, and gains named checks for the hook path. The
  fake DLL in `test/harness.lua` needs the new functions. Each new rule's check must fail on the code without it.
- The README's "With a keyboard" section says what changes for the player: chat, macros and binds work in nav
  mode, and a bind for `//cr nav` can end it again.

### Tests and verification

- nui: the new Linux test, `python3 test/frozen_check.py` and its `--self-test`, the existing pad and HD Linux
  tests, and `NUI_GXX=i686-w64-mingw32-g++ sh example/build.sh`. On Lego: the new Windows test with its fault
  builds, the existing pad test, and `test/hook_test.exe`.
- Chronicle: the CI suites in `.github/workflows/tests.yml` (`test_doc`, `test_input`, `test_keys`, `test_chord`,
  `test_autohide`, `test_mission_words`, `test_steps`, `test_roe`, `test_complete_strip`, `test_progress_ui`,
  `test_progress_lists`, `test_pages`), plus `test_pad` and `test/syntax_check.lua`. `test_screens` has 4 known
  Linux-only failures and takes over 10 minutes, so run it in the background.
- The QA frames, if the drawing changes. The handoff §4 says how the last comparison ran on Lego.
- In game: a test zip and a checklist. Check at least these:
  - In nav mode, the arrows, Page Up and Page Down do not move the camera.
  - In nav mode, the player can open the chat line with a key Chronicle does not use, and type.
  - In nav mode, a macro key and a Windower bind work.
  - A letter typed in the search box opens no game menu.
  - The game gets the keys back when the player gives them back, switches window, or unloads the addon.

## 5. Working here and on Lego

- Install the toolchain first: `apt-get update`, then `apt-get install -y g++-mingw-w64-i686 lua5.1
  g++-multilib`. Wine does not start in the container. Do not spend time on it.
- Lua tests: `export TEMP=<scratch dir>`, then `lua5.1 test/<name>.lua` from the Chronicle root. Delete the file
  named `nul` that the harness leaves, and never commit it.
- Build the DLL with `sh plugin/build.sh` from the Chronicle root. Compare the `NUI-TAG` string and the git
  blobs, never the bytes.
- `sync.py` resolves consumer paths from the directory above the nui checkout's parent. Add
  `user/ffxi-chronicle/plugin/nui` to `consumers.txt`, run `python3 sync.py release <v>` or `sync`, then
  `git checkout consumers.txt`. Never commit that line.
- Push nui with `git -c push.negotiate=true push`. The proxy refuses branch deletes with a 403. Report that to the
  user instead of trying again.
- Chronicle's `docs/` is in `.gitignore`, so add files there with `git add -f`.
- A test zip: `git archive --format=zip --prefix=chronicle/ -o <zip> HEAD` from the Chronicle root. Send it to the
  user with `SendUserFile`.
- The session cannot reach `jintawk/nui` or `jintawk/ffxi-chronicle`. The user opens upstream PRs. Give them the
  compare URL and the description as a file.
- Lego runs a Claude Code session named "Remote control". Find it with `list_sessions` and message it with
  `send_message`. The user may need to allow your session to reach their computers first. The refusal tells you
  how. That session can build and run the Windows tests, draw the QA frames, read the client's code, and install a
  test build into `C:\Windower4\addons\chronicle` (it backs up the old one first). Its setup is in the handoff §5.
- You may hand a well-scoped piece to a sub-agent, as the last session did for the controller chord and for
  auto-hide. Brief it fully, have it commit locally without pushing, and review and rerun its tests before you
  push.

## 6. After the keyboard hook

In rough order. The handoff §6 has the detail.

1. **The two nui PRs.** Whichever merges second needs a rebase onto upstream `main`, because both add a CI step
   and a README paragraph in the same place. Do it when the user asks. The keyboard hook could become a third PR
   later, from its own branch.
2. **After both merge:** Chronicle vendors an upstream nui release, and the fork's release numbers give way.
   Agree on that with the user. Then a Chronicle PR, only when the user asks.
3. **The player's own key bindings** and **a main menu item** (`docs/test-findings-plan.md` §7). Each needs
   research first, and some need native code. The bindings matter less once the hook hides only Chronicle's keys,
   but the nav key can still clash with a key the player bound in the game.
4. **Optional:** DirectInput pads (a second PadHook source), QA frames for controller mode, moving and resizing
   the window from the pad, and the small loose ends in the handoff's §6.
