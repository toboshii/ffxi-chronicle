# Handoff: the keyboard driver, and the controller work after it

Paste everything below the line into a new session that has `toboshii/ffxi-chronicle` and `toboshii/nui`
attached.

---

You continue the work on two repositories: `toboshii/ffxi-chronicle` (Chronicle, a Windower 4 addon for
Final Fantasy XI) and `toboshii/nui` (the drawing library that Chronicle vendors in `plugin/nui`). Both are
forks of `jintawk/*`. The controller support is built, tested and confirmed in game, and its nui part is
open as a pull request upstream. Your job is the next piece of work, a keyboard driver, and then the items
after it in section 5.

## 1. Read these first, in this order

1. `docs/controller-handoff.md` (Chronicle). It is the current state: branches, commits, the architecture,
   every test result, how to work in the container and on the user's Windows machine, and what is left.
2. `docs/controller-support.md` (Chronicle). §4 is the navigation model, which is input-agnostic. §6 Phase 1
   is the keyboard driver as first planned.
3. `docs/test-findings-plan.md` §7 (Chronicle). It is the list of next work, with the keyboard driver first.
4. In Chronicle's code: the "Events" section and the "The controller" section of `chronicle.lua`, the
   keyboard and controller sections of `ui/window.lua`, `ui/keys.lua`, `ui/nav.lua` and `ui/pad.lua`.

## 2. Where things stand

| Repo | Branch | Head | What it holds |
|---|---|---|---|
| Chronicle | `ccr-d3a8994b-5t63ba` | the commit that adds this prompt | The controller feature, nui 1.5.0 vendored, `_chronicle.dll` 2.1.4, the docs. On upstream `master` `338643d` (Chronicle 2.1.1). |
| nui | `ccr-d3a8994b-5t63ba` | `6b821c8` | PadHook revisions 1 to 3 (fork releases 1.3.0 to 1.5.0), the HD texture pack work. On upstream `main` `8b2e53c`. |
| both | `claude/chronicle-workstreams-review-dp0k36` | as `ccr-d3a8994b-5t63ba` when last fast-forwarded | The review branch. The user has it fast-forwarded to `ccr-d3a8994b-5t63ba` when they ask. |
| nui | `controller-pad-hook` | `79bb531` | Open PR on `jintawk/nui`: "Read and hold the controller the game reads". |
| nui | `hd-texture-packs` | `871a167` | Open PR on `jintawk/nui`: "Read the UI art from an HD texture pack". |

Continue on `ccr-d3a8994b-5t63ba` in both repositories. If your session assigns a different branch, create
it from that head. Do not change `controller-pad-hook` or `hd-texture-packs` unless the user asks.

The keyboard driver needs no nui change: it is Lua only, in Chronicle.

## 3. Rules for this work

- Commit as `Toboshii Nakama <toboshii@gmail.com>`. Set `user.name` and `user.email` in both repositories
  first. Add no `Co-Authored-By` or session lines to commits, and no attribution or session links to PR
  text.
- Use the `ste80-humanizer` skill for all text a person reads: commit messages, docs, PR descriptions and
  the prompts you write. Run its checker (`scripts/ste_check.py`) on docs and PR text. Write short sentences
  in the active voice, with no em dashes and no semicolons in prose.
- Commit subjects are "area: a plain sentence" (`pad:`, `keys:`, `docs:`, `test:`). Wrapped bodies say why.
- A nui release is one commit named `nui x.y.z: ...` with the code, `VERSION`, `RELEASES` and
  `src/nui_version.h`. A Chronicle sync is one commit named `nui x.y.z: ...` with the vendored copy and the
  rebuilt DLL. You should not need either for the keyboard driver.
- Frozen layouts: add new bus fields only in the reserved tails, and zero must mean the old behaviour.
  `python3 test/frozen_check.py` must pass.
- Never push to nui `main` or Chronicle `master`. Open no PR unless the user asks. An upstream PR branch
  has no `claude/` or `agent/` prefix, names its purpose, and carries no plans or handoffs (`docs/`).
- Rewrite pushed history only with the user's permission, and then with `--force-with-lease` on the exact
  old head.
- Do not put model names in commits, docs or PR text.

## 4. The work: a keyboard driver (Phase 1 of the plan, decision D5)

### What it is for

A player drives Chronicle's cursor from the keyboard, the way the controller drives it now. That also
covers players whose pad Steam Input, DS4Windows or reWASD maps to keys. It needs no native code.

### What already exists

- **The keyboard event.** `windower.register_event('keyboard', function(dik, down, flags, blocked) ... end)`
  in `chronicle.lua` ("Events" section). If the handler returns `true`, the game does not get the key. Today it calls
  `win:key(dik, down, ch)`, and only while the module draws (`nui.drawing`), apart from key-ups.
- **The search box rule (review UI-4).** `W:key` in `ui/window.lua` takes every key pressed while the search
  box has focus. It swallows a key-up only if it swallowed that key's key-down. So the game gets the
  release of a key that the player held before the box took focus. A key that the box took stays
  swallowed until its release, even after the box loses focus. Keep the same rule for the driver.
- **Key codes.** `ui/keys.lua` turns DirectInput codes into characters and tracks each Shift key on its
  own (review UI-7). `keys.reset()` runs on lose focus and gain focus.
- **The cursor, which is input-agnostic.** In `ui/window.lua`: `W:pad_enter(hint)`, `W:pad_leave()`,
  `W:pad_move(dir)`, `W:pad_activate()`, `W:pad_back()` (returns `'root'` with nowhere to go back to),
  `W:pad_click(hit)`, `W:pad_scroll(dy, absolute)`. `ui/nav.lua` does the spatial moves. The hover is the
  cursor, so the existing hover drawing shows it. A mouse move of more than 3 px gives the hover back to
  the mouse.
- **The controller's own flow**, to mirror. In `chronicle.lua`: `pad_take`, `pad_give`, `pad_act` and
  `pad_tick`, and `//cr pad [on|off|status]`. `pad_act` maps an action name to the window calls above.

### What the plan asked for

`docs/controller-support.md` §6 Phase 1: in a nav mode, the arrows, Enter, Backspace, Tab and PgUp/PgDn
drive the cursor. The `keyboard` event keeps those keys from the game, with the same key-up rules as the
search box. DirectInput codes, for reference: Up `0xC8`, Down `0xD0`, Left `0xCB`, Right `0xCD`, Enter
`0x1C`, Backspace `0x0E`, Tab `0x0F`, Page Up `0xC9`, Page Down `0xD1`, Escape `0x01`, Home `0xC7`, End `0xCF`.

### Facts from the test reports that bear on it

- In the stock English menu bindings, D, G, K and O are free. A key or chord that enters and leaves nav
  mode could use one of them.
- The keyboard bindings with ids 74 to 137 are not in the registry or in `cnf.dat`. They exist only in
  memory, and reading them needs native code. The retail client may offer no keyboard remapping at all.
  Nobody checked that in the game's menus yet. If it offers none, a fixed table of the stock bindings is
  enough to avoid a clash.

### Decide with the user before you build

Use the `AskUserQuestion` tool. Recommend an option for each:

1. How nav mode starts and ends: `//cr nav` (which the player can bind to a key with Windower's `bind`), a
   key or chord in Chronicle itself, or both. If a key, which one.
2. One mode or two: do `//cr pad`, `L3 + R3` and the keyboard share one cursor mode, or does each input get
   its own?
3. Which keys nav mode takes from the game. Does Escape give the keyboard back, as Cancel gives the pad back
   at the root?
4. A Settings row for it, and its default.

### Rules the driver must keep

- When nav mode starts, a key that the player holds then stays the game's until the player lets it go.
- When nav mode ends, a key that nav mode took stays away from the game until the player lets it go. The
  game never sees half a press.
- The focused search box comes first, as now.
- Nav mode ends on the same events that give the pad back: hide, logout, unload, lose focus, and the
  command.
- With nav mode off, every frame stays exactly as it is now. Check that with the QA comparison below.

### Tests

- Lua, in the harness (`test/harness.lua`). `env.fire('keyboard', dik, down, 0, false)` returns `true` when
  Chronicle keeps the key. `test/test_input.lua` already tests UI-4 this way. Name each rule's check, and
  make sure each fails on the code without it.
- The nine CI suites and `test/syntax_check.lua` (`.github/workflows/tests.yml`) must still pass.
  `test_screens` has 4 known Linux-only failures.
- The QA frames: on the user's Windows machine, draw the same `qa_render.lua` shots from the old and the new
  Chronicle tree. Then compare the raw frames byte for byte. `docs/controller-handoff.md` §4 says how the
  last comparison ran: `CR_QA_PAGES_FILE`, `CR_QA_SCREENS=1` and a sample of pages with no pictures. With
  nav mode off, every frame must match, apart from any new Settings row.
- In game: the user runs it. Make a test zip as in section 6, and list what to check.

### Docs

- Chronicle README: a "With a keyboard" section next to "With a controller", and the commands table.
- `docs/controller-support.md`: the Status header, Phase 1 marked as built.
- `docs/controller-handoff.md`: the commits, the verification table, and what is left.

## 5. After the keyboard driver

In rough order. `docs/controller-handoff.md` §6 has the detail.

1. **The two nui PRs.** Whichever merges second needs a rebase onto upstream `main`, because both add a CI
   step and a README paragraph in the same place. Do it when the user asks.
2. **After both merge:** Chronicle vendors an upstream nui release, and the fork's release numbers give way.
   Agree on that with the user. Then a Chronicle PR, only when the user asks.
3. **The player's own key bindings,** the game's input mask, and a main menu item
   (`docs/test-findings-plan.md` §7). Each needs research first, and some need native code.
4. **Optional:** DirectInput pads, QA frames for controller mode, moving and resizing the window from the
   pad, and the small loose ends in the handoff's §6.

## 6. Working in the container

- Install the toolchain first: `apt-get update`, then `apt-get install -y g++-mingw-w64-i686 lua5.1
  g++-multilib`. Wine does not start in this container. Do not spend time on it.
- Lua tests: `export TEMP=<scratch dir>`, then `lua5.1 test/<name>.lua` from the Chronicle root. Delete the
  file named `nul` that the harness leaves, and never commit it.
- Build the DLL with `sh plugin/build.sh` from the Chronicle root, if a change ever needs it. Check it with
  `python3 sync.py check --dll ../ffxi-chronicle/libs/_chronicle.dll` from nui. Compare the `NUI-TAG`
  string and the git blobs, never the bytes.
- `sync.py` resolves consumer paths from the directory above the nui checkout's parent. Add
  `user/ffxi-chronicle/plugin/nui` to `consumers.txt`, run `python3 sync.py release <v>` or `sync`, then
  `git checkout consumers.txt`. Never commit that line.
- Push nui with `git -c push.negotiate=true push`. The proxy refuses branch deletes with a 403. Report that
  to the user instead of trying again.
- Chronicle's `docs/` is in `.gitignore`, so add files there with `git add -f`.
- A test zip: `git archive --format=zip --prefix=chronicle/ -o <zip> HEAD` from the Chronicle root. Send it
  to the user with `SendUserFile`.
- The session cannot reach `jintawk/nui` or `jintawk/ffxi-chronicle`. The user opens upstream PRs. Give
  them the compare URL and the description as a file.
- Windows runs: the user's Windows machine ("Lego") runs a Claude Code session named "Remote control". Find
  it with `list_sessions` and message it with `send_message`. The user may need to allow this session to
  reach their own computers first, and the refusal tells you how. Ask that session to confirm with the
  user before it installs anything. Its setup is in `docs/controller-handoff.md` §5.
