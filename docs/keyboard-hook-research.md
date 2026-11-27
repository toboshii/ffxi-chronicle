# The keyboard hook: research

Phase 0 of the nui keyboard hook (`docs/next-session-prompt.md` §4). A session on Lego read a loaded copy of the
2026-11-02 client (`FFXiMain.dll`, SHA-256 `d809ebe3...48fb`) and Windower's `Hook.dll`, offline. It read no
running game. Its full report, with every address and byte, is `docs/keyboard-client-report.md`.

This note gives the answers and what they mean for the design. Addresses are for the image at `0x10000000`.
nui never uses an address. It finds code by signature.

Last updated 2026-11-27.

## 1. The answers

1. **The device.** The client imports `DINPUT8.dll!DirectInput8Create`. One input object, at the global
   `0x10456DD0`, holds the keyboard device at `+0x88`. Its setup (`0x10007E20`) creates the device with
   `GUID_SysKeyboard`, sets a buffer of 320 events and `c_dfDIKeyboard`, and uses the cooperative level
   NONEXCLUSIVE, FOREGROUND and NOWINKEY. The client creates the device again after `DIERR_INPUTLOST` or
   `DIERR_NOTACQUIRED`, so the pointer can change.
2. **The reads.** One function, the input update at `0x10005A40`, reads the keyboard once per main loop tick on
   the main thread. It makes exactly two calls on the device:
   - `GetDeviceState(kbd, 0x100, input+0x98)` at `0x10005A86`.
   - `GetDeviceData(kbd, 0x14, input+0x79C, &n, 0)` at `0x10005B1D`, with `n` set to 16 before each call and no
     `DIGDD_PEEK`.

   The update counts a key as down when its state byte has `0x80`, or when a press event for it came in this
   tick. It ignores release events. It writes the result to the key-state object at `0x104E2DF8`, which the
   camera, the menus and every game action read. A tap shorter than a tick reaches the game only as an event. A
   hold reaches it through the state. So a hook must hide both.
3. **One place.** Both reads are in that one function, `0x97` bytes apart, and no other code reads the keyboard
   device. The instruction after each call is `cmp eax, 0x800700AA` (`3D AA 00 07 80`). Two signatures (45 and 42 bytes)
   each match exactly once in `.text`, and each ends with the call and that `cmp`.
4. **Windower.** `Hook.dll` has a keyboard wrapper class (`windower::direct_input_keyboard`), and it hooks
   `DirectInput8Create` by name. The wrapper overrides `GetDeviceState`, `GetDeviceData` and
   `SetCooperativeLevel`. It calls the real device first, then applies the block, the console key and the binds.
   Nobody checked at run time that the client's device at `+0x88` is this wrapper, but it very likely is. A
   hook at the client's call sites then runs after Windower, so Windower's events, binds and console keep
   working.
5. **Window messages.** The client's message pump passes each message to `0x100016C0` before it dispatches it.
   `WM_KEYDOWN` and `WM_CHAR` there feed only the chat line:
   - Space opens the chat line as `WM_CHAR`, in one game mode.
   - `/` opens it as `WM_KEYDOWN`.
   - Letters, digits and other character keys open it as `WM_KEYDOWN` when one value in the client is 0. With
     that value at 1 or 2, letters go to the action bindings instead, which matches "a letter opens a menu".
     Which game option sets the value is not known.
   - The chat line's text comes from `WM_CHAR` and the IME, and its edit keys from `WM_KEYDOWN`.
   - Enter and Escape are the exception: the chat line gets them from the DirectInput press edges, not from
     messages.

   So a DirectInput hook stops the camera, the menus, the action bindings, and Enter and Escape. It does
   not stop Space, `/` or typed letters from opening the chat line.
6. **The input mask.** `FUN_10124b70` sets a 32-bit mask of action categories. The action query (216 callers)
   and the axis getter (`Input_GetAxisValueMerged`, 41 callers) test an action's category against it. It cannot
   hide one key. A cleared bit turns off every action in that category, on the keyboard and the pad alike. The
   client rewrites the mask from 16 places, and many key reads never test it.

## 2. What this means for the hook

- **The place to patch is the `cmp` after each read.** It is one 5-byte instruction. A `call rel32` to a thunk
  has the same length. The thunk filters the buffer that the read just filled, runs the same `cmp` on the
  unchanged `eax`, and returns with `ret`, which keeps the flags. In this build, each `cmp` lies inside one
  aligned 8-byte block (`0x10005A88` and `0x10005B20`). So one locked 8-byte compare-and-exchange can write it,
  as PadHook writes its patch. nui refuses a build where a `cmp` does not fit in one aligned block.
- **Why the `cmp` and not the call.** The call (`FF 51 24`) is only 3 bytes. A patch over the call and the `cmp`
  together would leave a game thread that is inside the read returning into the middle of the new bytes. A
  thread can never be inside the `cmp`.
- **Why not the load of the device.** The `mov eax, [esi+0x88]` before each read could point the client at a
  proxy object, as PadHook does with the XInput slot. The load of the second read crosses an 8-byte boundary
  (`0x10005AFB` to `0x10005B00`), so one aligned write cannot change it.
- **The signatures fix the registers.** After the state read, `edi` holds the state buffer. After the
  event read, `ebx` holds the events and `ebp` the count. Both are callee-saved, so the read leaves them as
  they were.
- **Nothing to chain.** The read has already run when the thunk runs. With nobody driving, the thunk only runs
  the `cmp`.
- **The press rules fit both reads.** The state read comes first in each tick, then the event read. One
  per-key record serves both: the game saw this press, or this press is hidden. The hook decides a new press
  once, at the first read that sees it. It uses the keys to hide at that moment.
- **A press ends at its release.** A press stays the game's, or stays hidden, until the event read sees its
  release. If that release is lost, the press ends when the state shows the key up and the event read empties
  the buffer (it returns fewer than 16 events).
- **The search box needs more than this hook.** A key typed there also sends `WM_CHAR`, and Space or `/` can
  open the chat line. Only `keyboard_blockinput`, or a filter on window messages, stops that.
- **The nav key.** Some clients open the chat line on letters. There, a nav key that is a letter can still
  open the chat line through its `WM_KEYDOWN`. The default K does not open it on the user's client.

## 3. Not checked

- That the device at `+0x88` is Windower's wrapper at run time. The hook can report it: the thunk can pass the
  device, and `key_status()` can name the module of its vtable.
- What the press listeners at `[0x10663928]` and `[0x1066392C]` are. The input update calls them for each new
  press. They run after the reads, so the hook hides from them too.
- If Enter opens the chat line in game, and through which action.
- Where Windower raises its Lua `keyboard` event. It is not in the wrapper's two reads.
