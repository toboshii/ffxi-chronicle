# DirectInput test build 1: checklist

Chronicle with `_chronicle.dll` 2.1.7 (nui 1.8.0). Unzip it over `Windower/addons/chronicle`, so the DLL and the Lua files
go together. Then load it again with `//lua r chronicle`.

Turn off Steam Input for FFXI for every pad. Send the lines that `//cr pad status` prints for each pad.

## 1. Before any pad

1. `//cr status` names `_chronicle.dll` 2.1.7.
2. `//cr pad status` has a line that starts "controller DirectInput: live at FFXiMain's DirectInput pad reads".

## 2. An Xbox pad with Enable XInput on (nothing should change)

1. L3 + R3 takes the pad, the cursor moves, and L3 + R3 gives it back, as before.
2. `//cr pad status` says "the game reads no DirectInput pad".

## 3. The PlayStation pad

Use either Enable XInput setting. The game reads this pad through DirectInput in both cases.

1. `//cr pad status`: "the game reads Wireless Controller (054C:....), layout PlayStation (auto)".
2. L3 + R3 takes the pad. The game does not sit you down or turn the camera.
3. The hint line reads "Cross Open  Circle Back  L1 R1 Section  L2 R2 Page  L3+R3 Done". If your game config puts
   Confirm on Circle, the first two names swap.
4. The D-pad and the left stick move the cursor. Your character does not move, and the game's menus do not move.
5. The right stick scrolls a long page. The camera does not turn.
6. Cross opens, Circle goes back, L1 and R1 change section, L2 and R2 page, Options opens Settings, Share collapses the
   window, and R3 alone goes to the top.
7. With the pad given back, a tap of L3 alone still does the game's L3 action (sit or heal).
8. Hold the D-pad, then press L3 + R3: the game keeps the D-pad until you let go of it.
9. Press Cross while Chronicle holds the pad, keep it held, and give the pad back with `//cr pad`: the game does not
   see that Cross until you press it again.
10. Switch to another window and back: the pad goes back to the game.

## 4. The Xbox pad with Enable XInput off

Change the setting in the FFXI Config, then start the game again.

1. `//cr pad status`: "the game reads Controller (...) (045E:....), layout Xbox (auto)".
2. L3 + R3 takes the pad, and the hint reads "A Open  B Back  LB RB Section  LT RT Page  L3+R3 Done".
3. LT pages up and RT pages down. If they are the other way round, say so: the layout reads both triggers from one
   axis, and its sign comes from public mappings.
4. The right stick scrolls.

## 5. The other DirectInput pad

1. `//cr pad status`: which name, which ids and which layout.
2. Take the pad with the two buttons the hint line names (`#11+#12` on a generic pad, LS + RS on a Nintendo pad).
3. Say which buttons do the wrong thing. Then try `//cr pad layout playstation`, `xbox`, `nintendo` and `generic`.
   `//cr pad layout auto` goes back.
4. On the Settings screen, "Controller layout" cycles Auto, PlayStation, Xbox, Nintendo, Generic, then Auto.

## 6. The chord on a DirectInput pad

1. On the Settings screen, choose "Controller buttons" and hold L1 + R1 (or LB + RB). The new chord takes and gives back
   the pad, and the game does not see it.
2. `//cr pad chord l3+r3` puts the default back.
