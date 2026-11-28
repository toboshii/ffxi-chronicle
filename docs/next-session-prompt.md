# Prompt: the player's key bindings, then the rest

You continue the work on two repositories: `toboshii/ffxi-chronicle` (Chronicle, a Windower 4 addon for Final
Fantasy XI) and `toboshii/nui` (the drawing library that Chronicle vendors in `plugin/nui`). Both are forks of
`jintawk/*`. The controller, the keyboard driver and nui's keyboard hook are built and work in game. Three nui pull
requests are open upstream.

Your first job is the player's own key bindings: Chronicle should know when its nav key is a key the game uses.
Then a "Chronicle" item in the game's main menu. Then the items in section 8.

## 1. Read these first, in this order

1. `docs/controller-handoff.md` (Chronicle). It is the current state: branches, commits, the architecture, every
   test result, how to work in the container and on the user's Windows machine, and what is left. Read §3 (the key
   hook and the keyboard driver), §6 item 1 and §7 closely.
2. `docs/keyboard-client-report.md` (Chronicle), §2 (the input update and the key-state object) and §6 (the action
   query and the bindings table). `docs/keyboard-hook-research.md` gives the short version.
3. `docs/controller-support.md` §3, "Other findings", and `docs/test-findings-plan.md` §7 items 2 and 4.
4. In Chronicle: `ui/keys.lua` (`keys.parse`, the key names), the "The keyboard" section of `chronicle.lua`
   (`kbd_key`, `kbd_set_key`, `kbd_capture`, `kbd_status_lines`), and the Settings row "Keyboard key" in
   `ui/screens/settings.lua`. For the model to follow: `pad.chord_conflicts` in `ui/pad.lua`, and how
   `chronicle.lua` reports it (`pad_read_config`, `pad_status_lines`).
5. In nui: `src/pad.cpp` (`pad_config`, a read-only native read in the module table), and the signature scan in
   `src/KeyHook/KeyHook.h` (`scan_sites`, `scan_verdict`, `for_each_game_section`).

## 2. Where things stand

| Repo | Branch | Head | What it holds |
|---|---|---|---|
| Chronicle | `claude/new-session-1xkqpc` | the commit that adds this prompt | Everything so far: the controller, the keyboard driver, the key hook in use, nui 1.6.0 vendored, `_chronicle.dll` 2.1.5, the docs. On upstream `master` `338643d`. |
| nui | `claude/new-session-1xkqpc` | `8820af0` | PadHook revisions 1 to 3, the HD texture pack work, KeyHook 1 (fork releases 1.3.0 to 1.6.0). On upstream `main` `8b2e53c`. |
| nui | `keyboard-key-hook` | `db02f6c` | Open PR on `jintawk/nui`: "Keep single keys from the game", stacked on `controller-pad-hook`. |
| nui | `controller-pad-hook` | `79bb531` | Open PR on `jintawk/nui`: "Read and hold the controller the game reads". |
| nui | `hd-texture-packs` | `871a167` | Open PR on `jintawk/nui`: "Read the UI art from an HD texture pack". |

Continue from `claude/new-session-1xkqpc`'s head in both repositories. If your session assigns a different branch,
create it from that head. Do not change the three PR branches unless the user asks.

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

## 4. The work: the player's key bindings

### Why

The key hook hides the nav key (K by default) whenever nav is on and the chat line is closed. If the game uses that
key for an action, the player loses the action, and nothing tells them why. A player can also choose a nav key
that the game uses, in the Settings row "Keyboard key" or with `//cr nav key <name>`. Chronicle should say so, as
`//cr status` already says "L3/R3 also mapped in the game" for a controller chord.

### What is known

- The stock English menu bindings leave D, G, K and O free (the first test report). Nobody confirmed that from the
  game's own menus.
- The bindings with ids 74 to 137 are not in the registry or in `cnf.dat`. They exist only in memory (the second
  test report). The retail client may offer no keyboard remapping at all.
- The action query (`0x10124F00`, 216 callers) walks up to three keyboard bindings per action, in a table at
  `0x1036E6E8` (the 2026-11-02 build). Each binding is a WORD: the DIK code and a flags byte. Flag `0x40` means
  "not while the chat line has focus", and other bits set the Shift, Ctrl and Alt rules. There are 188 action ids.
- The keyboard layout is `[[0x10457BD8]+8]`. Layouts 2 and 3 remap the DIK codes through the tables at
  `0x103509B4` and `0x103509D4`.
- Lego's `kbd_re\bindings.txt` decodes the table. Enter and NumEnter are bound to actions 14, 66, 143, 145 and 147.

### Phase 0: research, then decide with the user

Do the research on Lego, from its saved image of the client, with the same plain context as before. Ask the user
what they can see in the game, because some answers are quicker there.

1. **The table.** Is `0x1036E6E8` in a read-only or a writable section? If writable, which code writes it, from
   what, and when (at start, on a change of the keyboard layout, from a menu)?
2. **Changes.** Can the player change a keyboard binding at all: in a game menu, in the FFXI Config tool, or in a
   file? Ask the user to look in the game's Config menus and in the Config tool.
3. **The layouts.** Which layout values exist, which one the user's client uses, and where the setting lives (the
   registry next to `padmode000`, or `cnf.dat`)?
4. **What each binding does.** For the stock layout the user plays: every bound DIK code, with its modifiers and
   flags. Name the action in words where the code or the game shows it: a menu, a target key, the camera, a macro
   bar. Unknown actions stay as numbers.
5. **A run-time read.** If the table can change, a signature that finds it, and the checks that make a read-only
   scan from nui safe.

Write a short research note, `docs/key-bindings-research.md` (force-added). Then use the `AskUserQuestion` tool
to agree on these, with a recommendation for each:
- **Where Chronicle learns the bindings:** a fixed table in Lua, per layout (recommended if the table is constant
  and nothing remaps it), or a native read of the live table (a new `key_bindings()` in nui, recommended if it can
  change).
- **What Chronicle does on a clash:** warn and keep the key (recommended, as for the chord), refuse the key, or
  stop hiding that key from the game.
- **When it warns:** when the key is set (the Settings row and `//cr nav key`), in `//cr nav status`, and once at
  load if the current nav key clashes.

### Phase 1: build it

- **A Lua table:** a pure module, for example `ui/keybinds.lua`. It holds the stock bindings per layout. One
  function names the game actions on a key with its modifiers. If the layout must come from the registry, add it to a
  native read that the DLL already makes, and agree on that first, because it changes the DLL.
- **A native read:** a nui release (1.7.0) with a read-only `key_bindings()`. It finds the table by signature and
  checks it (one match, values in range), and it patches nothing. Lua gets a table: nui binds `createtable`,
  `rawseti` and `setfield`. It needs a Linux test against the real bytes and a Windows test with a stand-in. Then
  the Chronicle sync, with `_chronicle.dll` 2.1.6.
- **In Chronicle:** `kbd_set_key` and `kbd_capture` say when the new key is also a game action, and still set it if
  that is the decision. `kbd_status_lines` names a clash. The README's "With a keyboard" section says how to choose a
  free key.
- **Tests:** named checks in `test/test_keys.lua` (for example BIND-1 ...), and each must fail on the code without
  its rule. If native, the fake DLL in `test/harness.lua` gains `key_bindings`.
- **In game:** a test zip and a checklist. Set the nav key to a key the game uses and see the warning. Set it to a
  free key and see none. Check the default K. Check `//cr nav status`.

## 5. Then: a "Chronicle" item in the game's main menu

The player would open Chronicle from the game's own main menu, which also works from the pad. Two things are unknown:

1. Can the main menu's element array take a sixteenth item? Where does the client build the menu, and how does it
   draw an item and act on it?
2. Does the client's `Cmd_ExecuteLine` reach a Windower command (a line such as `//cr show`)? Windower reads the
   chat line's input. A line the client runs itself may never pass through Windower.

Research both on Lego first, and write the answers into a note in `docs/`. An item in the menu means a patch of the
client's menu code or data: a bigger change than the key hook. Agree the design with the user before any code, with
the same fail-closed rules as the pad and key hooks. If the answer is "not safely possible", say so, and stop there.

## 6. Decide before you build

Use the `AskUserQuestion` tool for each decision that changes what you build, with a recommendation first. Do not
ask about what the code or a sensible default already settles.

## 7. Working here and on Lego

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
  how.
- That session cannot message a cloud session back: read its answers with `list_events` (kinds
  `assistant`), and ask it to end each turn with a plain summary. Tell it the context plainly: an interoperability
  analysis of the user's own licensed install, for a Windower addon. A safety check stopped its first, shorter
  brief. Never describe the client as anything it is not.
- That session can build and run the Windows tests, draw the QA frames, read the client's code, and install a test
  build into `C:\Windower4\addons\chronicle` (it backs up the old one first). It keeps a loaded copy of the
  2026-11-02 client and its tools in its scratch folder, under `kbd_re\` (`dump\`, `tools\`, `bindings.txt`). Reuse
  them. Its setup is in the handoff §5.
- You may hand a well-scoped piece to a sub-agent, as the last session did for the controller chord and for
  auto-hide. Brief it fully, have it commit locally without pushing, and review and rerun its tests before you
  push.

## 8. After those

In rough order. The handoff §6 has the detail.

1. **The nui PRs.** The HD and pad PRs add a CI step and a README paragraph in the same place, so whichever merges
   second needs a rebase onto upstream `main`. `keyboard-key-hook` shows the pad commits until the pad PR merges. If
   the pad PR is squash-merged, rebase `keyboard-key-hook` onto `main`. Do each when the user asks. This session
   cannot read `jintawk/nui`, so the user pastes review comments.
2. **After they merge:** Chronicle vendors an upstream nui release, and the fork's release numbers (1.3.0 to 1.6.0)
   give way. Agree on that with the user. Then a Chronicle PR, only when the user asks.
3. **Optional:** DirectInput pads (a second PadHook source), QA frames for controller mode, and the window's place
   and size from the pad. Also a message filter for the search box, and the small loose ends in the handoff's §6.
