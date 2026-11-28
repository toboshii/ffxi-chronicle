# How FFXiMain.dll reads a DirectInput pad (2026-11-02 build)

This is a static analysis of the saved client image in `toboshii/ffxi-private` (`dump/FFXiMain_20261102.bin`, base
`0x10000000`). No running game was read. nui uses no address from this note. It finds the code by signature. This note is the base for
PadHook revision 4 (nui 1.8.0) and Chronicle's DirectInput layouts.

## Summary

- The client reads exactly one pad. It uses XInput when Enable XInput is on and the pad is an XInput device. It reads a
  DirectInput device in every other case: with Enable XInput off, or for a pad that is not an XInput device, such as a
  DualShock without Steam Input.
- The input update `0x10005A40` reads the DirectInput pad once per tick, on the main thread, with `GetDeviceState`
  (a 272-byte `DIJOYSTATE2`) and then `GetDeviceData` (up to 16 events). It is the same function that reads the keyboard.
- The client maps buttons 0 to 31 to game actions through `padsin000`. Each button's state comes from the state read.
  Its press and release edges come only from the events.
- After each read comes one 5-byte instruction in one aligned 8-byte block. After the state read it is
  `cmp eax, 0x800700AA`. On the event read's success branch it is `mov byte [esp+0x13], 1`. nui patches those two.

## 1. The device (confidence: high)

The pad setup is `0x100083D0` (thiscall, `esi` = the input object `[0x10456DD0]`). It runs from the input init and again
when the client re-creates the device.

1. With Enable XInput on (`[0x10456DE8]`), `0x10008D90` checks that `xinputdll.dll` loads from the game folder, and
   `0x10008E10` loads it and fills the four XInput slots (`0x104576FC` to `0x10457708`).
2. `IDirectInput8::EnumDevices` (+0x10) lists game controllers (`DI8DEVCLASS_GAMECTRL`, 4), attached only. With force
   feedback wanted (`[0x10456DE9]`), it lists force feedback devices first, then all of them.
3. The callback `0x100057D0` compares each device's instance GUID with the saved `padguid000` (`0x10456CC0`). With the
   shim loaded, it runs the WMI test `0x10008AB0` (the "IsXInputDevice" sample: `Win32_PNPEntity`, `IG_`, `VID_%4X`,
   `PID_%4X`). An XInput device sets `[input+0xC99]` (read the pad with XInput) and gets no DirectInput device.
   Otherwise `CreateDevice` (+0x0C) puts the device at **`input+0x90`**.
4. `GetCapabilities` (+0x0C): when `DIDC_POLLEDDEVICE` or `DIDC_POLLEDDATAFORMAT` is set, `[input+0xC98]` = 1, and
   the update calls `Poll` before each read.
5. `SetProperty(DIPROP_BUFFERSIZE)`: 320 events.
6. `SetDataFormat` (+0x2C) with `0x1034B23C`, the `c_dfDIJoystick2` format.
7. `SetCooperativeLevel` (+0x34): `DISCL_EXCLUSIVE`, with `DISCL_FOREGROUND`, or `DISCL_BACKGROUND` when the pad works
   while the window is inactive (`[0x10456DE7]`). The client holds the pad exclusively, so another program cannot
   acquire it in exclusive mode. A hook inside the client's own reads does not need to.
8. `SetProperty(DIPROP_RANGE)` on 8 axes by offset (0, 4, 8, 0xC, 0x10, 0x14, 0x18, 0x1C): -127 to 127.
9. `Acquire` (+0x1C), then the force feedback effect (`CreateEffect`, +0x48, kept at `0x10456DD8`).

`padmode000` sets six flags, in this order: the gamepad on (`0x10456DE4`), force feedback (`0x10456DE9`), the sliders
(`0x10456DE6`), the POV hat (`0x10456DE5`), "works in the background" (`0x10456DE7`), and Enable XInput (`0x10456DE8`).

## 2. The reads (confidence: high)

Both reads are in the input update `0x10005A40` (`ebx` = the input object in this part).

| Call | Address | Arguments |
|---|---|---|
| `Poll` (+0x64), when needed | `0x10006178` | `(pad)` |
| `GetDeviceState` (+0x24) | `0x10006197` | `(pad, 0x110, input+0xA44)` |
| `GetDeviceData` (+0x28) | `0x100069E3` | `(pad, 0x14, input+0xB54, input+0xC94, 0)`, with `[input+0xC94]` = 16 first |

- **The state read.** On `DIERR_INPUTLOST`, `DIERR_NOTACQUIRED` or `0x800700AA` the client releases the device and the
  effect, clears its event buffer, and re-creates the device later. Any other failure skips the state. On success:
  - Buttons 0 to 31 (`input+0xA74`): each held button ORs its action bits into `[[0x104E2EFC]+0x220]`. The table is
    `0x10456DF8` (one 64-bit word per button), or `0x104571F8` while a button whose action is the "second set" modifier
    is held. A button whose action is a direction also sets a virtual stick value of +127 or -127.
  - The axes: a table of 12 entries at `0x104575F8` names an axis per analog output: 1 to 6 are lX to lRz, 7 and 8 the
    sliders, 9 and 10 the POV as x and y (`0x100059C0`, `0x10005A00`). A negative code inverts the axis.
  - Each output has a dead zone of 42. The client clamps the two sticks to a circle and writes them to `+0x250` to
    `+0x253` as unsigned bytes (128 is centred). Two more outputs past ±63 make the menu directions, with their own press edges.
- **The event read.** On success (`eax` = 0 exactly, so `DI_BUFFEROVERFLOW` counts as a failure) the client clears two
  flags and runs `mov byte [esp+0x13], 1` at `0x10006A0B`. Only then does it read the events. A press (`dwData` = 0x80,
  `dwOfs` = 0x30 + button) ORs the action bits into `+0x228` (press edge), `+0x238` and `+0x220`. A release
  (`dwData` = 0) ORs them into `+0x230` (release edge) and XORs them out of `+0x220`. The client ignores axis and POV
  events.
  On failure the client clears the buffer and the count and skips the events.
- **What this means for hiding a press.** A held button reaches the game only through the state, and its edges only
  through the events. So a hidden press needs its state byte cleared and both of its events dropped. A press the game
  must still get (a chord button tapped alone) needs a press event and a release event put back. When the hook sets
  every axis to 0, every analog output is centred, because the client's centre is 0.

## 3. `padsin000` in DirectInput mode (confidence: high)

The parser `0x10005130` reads the comma-separated values in order. The value of field `k` goes to action index
`[0x10350930 + 4k]`: 8, 9, 14, 13, 10, 3, 1, 0, 2, 16, 25, 26, 15, 23, 24, 22, 21, 19, 20, 18, 17, 6, 7, 5, 4, 12, 31 to 36.
So field 7 is action 0 (Confirm), field 5 action 3 (Cancel), field 6 action 1 (Main menu), field 8 action 2 (Active
window), as the earlier research found.

- A value below 32 is a DirectInput button number: the button's table entry becomes that action's bit. A button has one
  action, the last one assigned to it.
- A value of 32 or more names an axis for actions 4 to 7 and 17 to 24: the axis code is the value less 31. A negative
  value is the same axis inverted.
- `padexsin000` fills the second-set table `0x104571F8` the same way.

The XInput path reads the same values through a fixed table at `0x1032A818`. That table gives the padsin ids of the
XInput buttons. Chronicle had only some of them confirmed: B 0, X 1, Y 2, A 3, right 4, left 5, up 6, down 7, LB 8, LT 9, L3 10,
RB 11, RT 12, R3 13, Start 14, Back 15.

## 4. The patch sites (confidence: high)

| Site | Signature start | Length | Patched instruction | Its 8-byte block |
|---|---|---|---|---|
| The state read | `0x1000616B` (the Poll test) | 52 bytes | `cmp eax, 0x800700AA` at `0x1000619A` | `0x10006198` to `0x1000619F` |
| The event read | `0x100069AC` (the count's `lea`) | 100 bytes | `mov byte [esp+0x13], 1` at `0x10006A0B` | `0x10006A08` to `0x10006A0F` |

- Each signature matches exactly once in the whole saved image, the packed `POL1` section included.
- Nothing else reaches `0x100069FF` to `0x10006A0F`: one `je` at `0x100069E8` is the only branch there, and no pointer in
  the image points into that range.
- The first design patched `call [edx+0x28]` and the `test` after it. A thread inside `GetDeviceData` while the patch
  went in would then return into the middle of the new instruction. The store on the success branch has no such case:
  every thread reaches it as a whole instruction.
- The thunks need: `ebx` (the input object), `edi` (the events) and `ebp` (the count's address). The signatures fix all
  three.

## 5. Button layouts (from public mappings, not from the client)

DirectInput numbers a pad's buttons in the order its HID report gives them. These are the usual orders, and Chronicle's
layouts. They are not confirmed in game yet.

| Pad | USB vendor | Buttons 0 to 11 | Right stick | Triggers |
|---|---|---|---|---|
| DualShock 4, DualSense | `054C` | Square, Cross, Circle, Triangle, L1, R1, L2, R2, Share, Options, L3, R3 | Z, Rz | buttons 6 and 7 (Rx and Ry give their travel) |
| Xbox pad through DirectInput | `045E` | A, B, X, Y, LB, RB, Back, Start, L3, R3 | Rx, Ry | one axis, Z: LT positive, RT negative |
| Switch Pro | `057E` | B, A, Y, X (bottom, right, left, top), L, R, ZL, ZR, Minus, Plus, LS, RS | Z, Rz (to check) | buttons 6 and 7 |
| Most other pads | | 1 to 12 as the DualShock order (Logitech in D mode: X, A, B, Y, ...) | Z, Rz | buttons 6 and 7 |

## 6. Open questions

- Which axes the Switch Pro's right stick uses. Also, if the Xbox pad's Z axis is positive for LT on the user's machine.
- What the game does with a pad plugged in after the start. The client re-creates its device on a lost device, and nui
  then reads the new device's maker once.
