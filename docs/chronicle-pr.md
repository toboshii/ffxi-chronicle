# Controller and keyboard navigation

## Summary

Players can now use Chronicle without a mouse. A controller or the keyboard moves a cursor over the same places that a
click reaches.

- **Controller.** L3 + R3 takes the pad and gives it back. The D-pad moves the cursor. Confirm clicks and Cancel goes
  back. LB and RB change the section, LT and RT turn the page, and the right stick scrolls. Confirm and Cancel follow
  the game's own pad config. While Chronicle holds the pad, the game does not see the presses, or the chord itself.
- **Keyboard.** K takes the arrows, Enter, Backspace, Escape, Tab, Page Up and Page Down, and Home and End. Chronicle
  hides only those keys and K from the game. The player can still chat, use macros and run Windower binds. If the DLL
  cannot hide single keys, Chronicle falls back to `keyboard_blockinput` and says so in `//cr nav status`.
- **Choices.** The player chooses the controller chord and the nav key, in Settings or with `//cr pad chord` and
  `//cr nav key`. A new setting, "Hide on Back" (`//cr autohide`), lets Cancel at a section's home hide the window.
- **Macro.** The README says how to open Chronicle from a game macro with `/con cr show`.

With the controller and the keyboard off, every frame draws as before.

## Depends on three nui pull requests

The native side comes from three open pull requests on `jintawk/nui`:

1. "Read the UI art from an HD texture pack" (`hd-texture-packs`)
2. "Read and hold the controller the game reads" (`controller-pad-hook`)
3. "Keep single keys from the game" (`keyboard-key-hook`, which builds on 2)

Upstream merged none of them yet, so I open this as a draft.

`plugin/nui` is upstream `main` (1.2.10) with the three branches merged on top. Only the CI file and the README
conflicted, and the merge keeps both sides of each. I labelled the copy **nui 1.3.0**, the release I expect when the three merge. I rebuilt `_chronicle.dll` as 2.1.0. It carries
`NUI-TAG:1.3.0:81709b33c6c75939`. Chronicle goes to 2.2.0.

When nui releases, I will replace the first commit with a sync to the real release. If its number is not 1.3.0, the
same commit changes the version strings and the comments that name 1.3.0. The Lua side uses only the functions in
those three pull requests.

## Commits

The first commit is the nui sync. Each later commit is one feature or fix, and each says why in its body. The last
commit changes only comments and one README line.

## Tests

- New suites: `test_pad` (100 checks), `test_keys` (180), `test_chord` (99) and `test_autohide` (94). Each rule has a
  named check that fails on the code without that rule.
- `test_keys`, `test_chord` and `test_autohide` join the CI loop. All CI suites and the syntax check pass on Linux.
- `test_pad` is not in the CI loop yet. It passes locally.
- `test_load` needs Windows and the built DLL. It checks for version 2.1.0.
- In game: the same Lua, on a fork build of the same nui code, works on Windows. That covers the controller on the
  client's own XInput wrapper, the chord, the keyboard with the key hook, the choosable chord and nav key, and auto-hide.
  This exact branch also works in game, with its own DLL.

## Not in this pull request

- DirectInput pads. Only XInput pads work.
- Window moves and resizes from the pad or the keyboard. Only the mouse does that today.
- The search box still blocks the whole keyboard while it has focus. Typed text reaches the chat line as window
  messages, and the key hook does not see those.
