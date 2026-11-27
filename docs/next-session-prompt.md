# Prompt: after the keyboard hook

You continue the work on two repositories: `toboshii/ffxi-chronicle` (Chronicle, a Windower 4 addon for Final
Fantasy XI) and `toboshii/nui` (the drawing library that Chronicle vendors in `plugin/nui`). Both are forks of
`jintawk/*`. The controller support and the keyboard driver work in game. nui 1.6.0 adds a keyboard hook that hides
only the keys Chronicle names, and Chronicle uses it. Its tests pass, and it works in game. Your job is the items in
section 6.

## 1. Read these first, in this order

1. `docs/controller-handoff.md` (Chronicle). It is the current state: branches, commits, the architecture,
   every test result, how to work in the container and on the user's Windows machine, and what is left. Read §3
   (the key hook, the keyboard driver and the pad hook), §4 and §6 closely.
2. `docs/keyboard-hook-research.md` (Chronicle): how the client reads the keyboard, and what that means for the
   hook. `docs/keyboard-client-report.md` has every address and byte.
3. In nui: `src/KeyHook/KeyHook.h` (its header comment is the design), `src/key.cpp`, `docs/abi.md` (KeyHook 1), and
   the tests in `test/key_linux/` and `test/key_test.cpp`.
4. In Chronicle's `chronicle.lua`: the "The keyboard" section (`kbd_hook_join`, `kbd_hide_want`, `kbd_hide_sync`,
   `kbd_want_block`, `kbd_status_lines`), and the HOOK checks in `test/test_keys.lua`.

## 2. Where things stand

| Repo | Branch | Head | What it holds |
|---|---|---|---|
| Chronicle | `claude/new-session-1xkqpc` | the commit that adds this prompt | Everything before, the keyboard research, nui 1.6.0 vendored, `_chronicle.dll` 2.1.5, Chronicle on the key hook. On upstream `master` `338643d`. |
| nui | `claude/new-session-1xkqpc` | `8820af0` | PadHook revisions 1 to 3 (fork releases 1.3.0 to 1.5.0), the HD texture pack work, KeyHook 1 (1.6.0). On upstream `main` `8b2e53c`. |
| both | `ccr-bfbc0043-hhlj8v` | Chronicle `652a620`, nui `6b821c8` | The session before this one. |
| nui | `controller-pad-hook` | `79bb531` | Open PR on `jintawk/nui`: "Read and hold the controller the game reads". |
| nui | `hd-texture-packs` | `871a167` | Open PR on `jintawk/nui`: "Read the UI art from an HD texture pack". |

Continue from `claude/new-session-1xkqpc`'s head in both repositories. If your session assigns a different branch,
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

## 4. The work: section 6

Keyboard hook test build 1 works in game (the handoff §4). The user chose to keep one rule as it is. A nav key held
when K takes the keys stays the game's until its release. So a held arrow keeps turning the camera until the player
lets go of it. Do not change that unless the user asks. Start with section 6, and ask the user which item comes
first.

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
  how. That session cannot message a cloud session back: read its answers with `list_events` (kinds
  `assistant`), and ask it to end each turn with a plain summary. Tell it the context plainly: an interoperability
  analysis of the user's own licensed install, for a Windower addon. A safety check stopped its first, shorter
  brief. Never describe the client as anything it is not. That session can build and run the Windows tests, draw the QA frames, read the client's code, and install a
  test build into `C:\Windower4\addons\chronicle` (it backs up the old one first). Its setup is in the handoff §5.
- You may hand a well-scoped piece to a sub-agent, as the last session did for the controller chord and for
  auto-hide. Brief it fully, have it commit locally without pushing, and review and rerun its tests before you
  push.

## 6. After the keyboard hook

In rough order. The handoff §6 has the detail.

1. **The nui PRs.** Whichever of the two open PRs merges second needs a rebase onto upstream `main`, because both
   add a CI step and a README paragraph in the same place. Do it when the user asks. The keyboard hook could be a
   third PR, after the pad hook, because it shares the pad hook's style and the frozen check.
2. **After they merge:** Chronicle vendors an upstream nui release, and the fork's release numbers (1.3.0 to
   1.6.0) give way. Agree on that with the user. Then a Chronicle PR, only when the user asks.
3. **The player's own key bindings** and **a main menu item** (`docs/test-findings-plan.md` §7). The research found
   the action bindings table, which helps with the first.
4. **Optional:** DirectInput pads (a second PadHook source), QA frames for controller mode, and a message filter
   for the search box. Also the window's place and size from the pad, and the small loose ends in the handoff's §6.
