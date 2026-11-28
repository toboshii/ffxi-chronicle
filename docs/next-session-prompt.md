# Prompt: continue Chronicle and nui

You continue the work on two repositories: `toboshii/ffxi-chronicle` (Chronicle, a Windower 4 addon for Final
Fantasy XI) and `toboshii/nui` (the drawing library that Chronicle vendors in `plugin/nui`). Both are forks of
`jintawk/*`. A third repository, `toboshii/ffxi-private`, holds the client's saved image and the research tools. Keep
it private.

The big pieces work in game. They are the controller, the keyboard driver, nui's key hook, and a warning when the
player's nav key is also a game key. Nothing is urgent. Most of what is left waits on upstream or on the user, so
**ask the user what they want first.** Start only the work they choose.

## 1. Read these first, in this order

1. `docs/controller-handoff.md` (Chronicle). It gives the current state: branches, commits, the architecture and
   every test result. It also says how to work in the container and on the user's Windows machine, and what is left
   (§6).
2. `docs/key-bindings-research.md` and `docs/main-menu-research.md`, the two research notes of the last session.
3. For the work the user picks: the files that §3 and §6 of the handoff name.

## 2. Where things stand

| Repo | Branch | Head | What it holds |
|---|---|---|---|
| Chronicle | `claude/new-session-07e3om` | the commit that updates this prompt | Everything so far: nui 1.7.0 vendored, `_chronicle.dll` 2.1.6, Chronicle 2.2.0, the docs. On upstream `master` `338643d`. |
| nui | `claude/new-session-07e3om` | `8895b87` | PadHook revisions 1 to 3, the HD texture pack work, KeyHook 1, `key_bindings()` (fork releases 1.3.0 to 1.7.0). On upstream `main` `8b2e53c`. |
| nui | `keyboard-bindings` | `563dcc4` | **Not raised, by the user's choice.** A PR branch for `key_bindings()`, stacked on `keyboard-key-hook`. |
| nui | `keyboard-key-hook` | `db02f6c` | Open PR on `jintawk/nui`: "Keep single keys from the game", stacked on `controller-pad-hook`. |
| nui | `controller-pad-hook` | `79bb531` | Open PR on `jintawk/nui`: "Read and hold the controller the game reads". |
| nui | `hd-texture-packs` | `871a167` | Open PR on `jintawk/nui`: "Read the UI art from an HD texture pack". |

Continue from `claude/new-session-07e3om`'s heads. If your session assigns a different branch, create it from those
heads. Do not change the four PR branches unless the user asks.

## 3. What is left (the handoff's §6 has the detail)

1. **The nui PRs, when the user asks.** The HD and pad PRs add a CI step and a README paragraph in the same place, so
   whichever merges second needs a rebase onto upstream `main`. `keyboard-key-hook` shows the pad commits until the
   pad PR merges. If the pad PR is squash-merged, rebase `keyboard-key-hook` onto `main`. The session cannot read
   `jintawk/nui`, so the user pastes review comments.
2. **`key_bindings()` stays out of upstream, by the user's choice.** It is only in the fork's nui 1.7.0. Its PR
   branch `keyboard-bindings` is built and pushed, but the user chose not to raise it. They think it is too complex
   for a warning about a key the player can easily change. They may raise it later, or never. Do not open it unless
   the user asks. Build all new work so that it does not need `key_bindings()`. Chronicle already works without it,
   and its tests check that. The handoff's §6 item 4 has the rules.
3. **After upstream merges:** Chronicle vendors an upstream nui release, and the fork's release numbers (1.3.0 to
   1.7.0) give way. Agree on that with the user. Then a Chronicle PR, only when the user asks.
4. **Optional, only if the user asks for one:**
   - DirectInput pads (a second PadHook source).
   - QA frames for controller mode.
   - The window's place and size from the pad or the keyboard. Today only the mouse can move or resize the window. The
     handoff's §6 item 6 describes the idea.
   - A message filter for the search box, so it can use the key hook instead of blocking the whole keyboard.
   - The small loose ends in the handoff's §6 item 8.
5. **Stopped by the user's choice:** a "Chronicle" item in the game's main menu. A game macro line `/con cr show`
   opens Chronicle, and the README says so. Do not restart it unless the user asks. If they do,
   `docs/main-menu-research.md` says where to begin.

## 4. Rules for this work

- Commit as `Toboshii Nakama <toboshii@gmail.com>`. Set `user.name` and `user.email` in each repository first. Add no
  `Co-Authored-By` or session lines to commits, and no attribution or session links to PR text.
- Use the `ste80-humanizer` skill for all text a person reads: commit messages, docs, PR descriptions and prompts.
  Run its checker (`scripts/ste_check.py`) on docs and PR text. Write short sentences in the active voice, with no em
  dashes and no semicolons in prose.
- Commit subjects are "area: a plain sentence" (`keys:`, `pad:`, `docs:`, `test:`). Wrapped bodies say why.
- A nui release is one commit named `nui x.y.z: ...` with the code, `VERSION`, `RELEASES` and `src/nui_version.h`. A
  Chronicle sync is one commit named `nui x.y.z: ...` with the vendored copy, the rebuilt DLL and the version strings
  (`plugin/ChronicleModule.cpp`, `test/harness.lua`, `test/test_load.lua`).
- Frozen layouts: a new bus gets its own frozen layout from its first release. Add new fields to any bus only in its
  reserved tail, and zero must mean the old behaviour. `python3 test/frozen_check.py` must pass.
- Native code fails closed: signatures that must match once, checks on what they find, a refusal with a reason in
  the status, and the game keeps working.
- Never push to nui `main` or Chronicle `master`. Open no PR unless the user asks.
- Rewrite pushed history only with the user's permission, and then with `--force-with-lease` on the exact old head.
- Do not put model names in commits, docs or PR text.
- Each new rule gets a named test check that fails on the code without the rule. Remove each rule in turn to prove it.
- The user likes work they can test in game: give a test zip and a short checklist for each build.
- Decide with the user before you build: use the `AskUserQuestion` tool for each choice that changes what you build,
  with a recommendation first.

## 5. Working here and on Lego

- Toolchain: `apt-get update`, then `apt-get install -y g++-mingw-w64-i686 lua5.1 g++-multilib`. Wine does not start
  in the container. Do not spend time on it.
- Lua tests: `export TEMP=<scratch dir>`, then `lua5.1 test/<name>.lua` from the Chronicle root. Delete the file named
  `nul` that the harness leaves, and never commit it. The syntax check reads file names on stdin:
  `git ls-files '*.lua' | lua5.1 test/syntax_check.lua`.
- Build the DLL with `sh plugin/build.sh` from the Chronicle root. Compare the `NUI-TAG` string and the git blobs,
  never the bytes.
- `sync.py` resolves consumer paths from the directory above the nui checkout's parent. Add
  `user/ffxi-chronicle/plugin/nui` to `consumers.txt`, run `python3 sync.py release <v>` or `sync`, then
  `git checkout consumers.txt`. Never commit that line. nui's `README.md` has CRLF line ends: keep them.
- Push nui with `git -c push.negotiate=true push`. The proxy refuses branch deletes with a 403. Report that to the
  user instead of trying again.
- Chronicle's `docs/` is in `.gitignore`, so add files there with `git add -f`.
- A test zip: `git archive --format=zip --prefix=chronicle/ -o <zip> HEAD` from the Chronicle root. Send it with
  `SendUserFile`.
- Client research: clone `toboshii/ffxi-private` next to the other two. Its README explains the saved image and the
  tools. In the container, run `OBJDUMP=i686-w64-mingw32-objdump sh tools/disasm.sh`, and point `tools/img.py`'s
  `OBJDUMP` and `DUMP` at the Linux paths in a scratch copy.
- Windows runs: the user's machine "Lego" runs a Claude Code session named "Remote control". Find it with
  `list_sessions` and message it with `send_message`. The user may need to allow your session to reach their computers
  first, and the refusal tells you how. That session cannot message a cloud session back: read its answers with
  `list_events` (kinds `assistant`), and ask it to end each turn with a plain summary. Tell it the context plainly: an
  interoperability analysis of the user's own licensed install, for a Windower addon. Its setup is in the handoff §5.
- You may hand a well-scoped piece to a sub-agent. Brief it fully, have it commit locally without pushing, and review
  and rerun its tests before you push.
