# How FFXiMain.dll reads the keyboard (2026-11-02 build)

Static analysis only. No running game was read. Nothing was installed or changed.

- Client: `FFXiMain.dll`, SHA-256 `d809ebe3…7d48fb`, PE timestamp `0x6AE818B4`. The copy and the installed file are the same.
- Image: the loaded image that an earlier session saved (base `0x10000000`, 12,677,120 bytes, no unreadable pages).
- Tools: MSYS2 `objdump` (i686) and Python. They are all in
  `C:\Users\user\AppData\Local\Temp\claude\0da306cefa400ea0\ee20c906-83af-4eec-8dff-4004f279444c\scratchpad\kbd_re\`
  (`dump\`, `tools\`, `text.asm`, `bindings.txt`, `sigs.txt`).
- Addresses: VA = `0x10000000` + RVA, so RVA = VA − `0x10000000`. For example, `0x10005A86` is RVA `0x5A86`.
- POL1 section: it holds the packed copy of `.text`. Its hits on the GUID and IID are compressed bytes, not a
  second code path.

## Summary

- The client imports `DirectInput8Create` directly. One input object holds the keyboard device at
  `[[0x10456DD0]+0x88]`.
- One function, `0x10005A40`, reads the keyboard once per frame on the main thread. It calls
  **`GetDeviceState` once and `GetDeviceData` once**, and both calls are in that function. No other code reads
  the keyboard device.
- The function turns both results into a 256-byte key-state object at `0x104E2DF8`. All game actions, the
  camera and the menus read that object.
- Window messages feed only the chat line (text object `[0x10663EF8]`). A DirectInput-level hook does not stop
  `WM_KEYDOWN` and `WM_CHAR`.
- Windower 4 already wraps the keyboard device (`windower::direct_input_keyboard`). It filters single keys in
  the same two methods.
- The input mask (`FUN_10124b70`) gates game actions by category, not by key. It cannot hide one key.

## 1. The keyboard device (confidence: high)

- **Import:** `DINPUT8.dll!DirectInput8Create` is a normal import. The IAT slot is `0x1032A030`, the thunk is
  `jmp [0x1032A030]` at `0x1030F572`, and the name string appears once. The client does not use
  `GetProcAddress` for it.
- **Input object:** `0x10001BB0` allocates `0xDC4` bytes, runs the constructor `0x10005660`, and stores the
  pointer in the global **`0x10456DD0`**.
- **Init** (`0x100058F0`, thiscall, called from `0x10001BD8`):
  `DirectInput8Create(hInst, 0x800, &IID_IDirectInput8A /*0x10343064*/, &input[+0x84], NULL)` at `0x1000590E`.
  Then it sets up the keyboard (`0x10007E20`), the mouse (`0x10007EF0`), the pad (`0x100083D0`) and `0x10008020`.
- **Keyboard setup `0x10007E20`** (thiscall, `ecx` = input):
  1. `CreateDevice` (+0x0C) with `GUID_SysKeyboard` (`0x10342EF4`). The device goes to **`input+0x88`**.
  2. `SetProperty` (+0x18) with `DIPROP_BUFFERSIZE` (1) and `DIPROPDWORD {0x14, 0x10, 0, DIPH_DEVICE, 320}`.
     The buffer holds **320** events.
  3. `SetDataFormat` (+0x2C) with `c_dfDIKeyboard` (`0x1034AE2C`).
  4. `SetCooperativeLevel` (+0x34). The window is `[[0x103D4D64]+0x18]`. The flags are **`0x16`**
     (NONEXCLUSIVE, FOREGROUND, NOWINKEY) when the dword `[0x10457C2C]` is 0, and `0x06` otherwise.
  5. `Acquire` (+0x1C). The result is ignored.
- **The pointer can change.** The read function releases the device and calls `0x10007E20` again on the first
  `DIERR_INPUTLOST` (`0x8007001E`), `DIERR_NOTACQUIRED` (`0x8007000C`) or `0x800700AA`. The calls are at
  `0x10005ABE` and `0x10005B55`.
- **Other uses:**
  - On `WM_ACTIVATE`, `0x100087D0` calls Acquire or Unacquire.
  - Teardown `0x10005780` calls Unacquire and Release, then writes 0 to `+0x88`.
- **Other devices:**
  - The mouse is at `+0x8C` (`GUID_SysMouse` `0x10342F04`, `c_dfDIMouse` `0x1034B034`). It exists only when
    `[0x10457C2C]` is 0.
  - The DirectInput pad is at `+0x90`.

## 2. The reads (confidence: high)

Both reads are in **`0x10005A40`**, the input update (thiscall, `esi` = input).

| Call | Address | Arguments |
|---|---|---|
| `GetDeviceState` (+0x24) | `0x10005A86` | `(kbd, 0x100, input+0x98)` |
| `GetDeviceData` (+0x28) | `0x10005B1D` | `(kbd, 0x14, input+0x79C, &n, 0)` |

- `n` is the dword at `input+0x8DC`. The client sets it to **16** before each call.
- The flags are 0, with no `DIGDD_PEEK`. So the client takes at most 16 events per frame, and the rest wait in
  the 320-event buffer.
- **Errors:** INPUTLOST, NOTACQUIRED or `0x800700AA` re-create the device once (flag `0x104576F8`), then
  Acquire, then zero the buffer. Any other error also zeroes it.
- **How often:** once per main-loop tick. `0x10005A40` has one caller, `0x1001287B`, which is in the tick
  function `0x10011A00`. The main loop calls the tick at `0x10001B74` (in `0x10001B50`). The same thread pumps
  the messages (`0x100015E4`). After the update, the tick calls `0x10125320` (clears the lock byte, see §6) and
  the pad update `0x100088F0`.
- **What the update does with the data:**
  1. For keyboard layouts 2 and 3 (`[[0x10457BD8]+8]`), it remaps the DIK codes through `0x10007830` and the
     tables `0x103509B4` and `0x103509D4`. The remapped state goes to `input+0x198`.
  2. It marks each buffered **press** (`dwData & 0x80`, `dwOfs < 0x100`) in a local 256-byte array.
     It ignores release events.
  3. For each DIK `i` from 0 to 255, the key counts as down when `state[i] & 0x80` is set or `i` had a press
     event. The update then writes the key-state object **`0x104E2DF8`**. It has one byte per DIK:

     | Bit | Meaning | Write | Read |
     |---|---|---|---|
     | 0x01 | press or auto-repeat | `0x10125410` | `0x10125560`, take `0x10125580` |
     | 0x02 | press edge | `0x101253D0` | `0x10125500`, take `0x10125520` |
     | 0x04 | held | `0x10125450` | `0x101255C0` |
     | 0x08 | release edge | `0x101253F0` | `0x10125540` |
     | 0x10 | lock toggle | `0x10125470` | `0x101255A0` |

     - `+0x100` means "a key went down". `0x10125490` clears a key, and `0x101254A0` clears its edges.
     - The repeat counter for each key is a dword at `input+0x398+4*i`. The repeat delay is `input+0x94`.
     - On each new press, the update also calls `vtbl+0x4C(0, dik, 0, 0)` on `[0x10663928]` and
       `[0x1066392C]`.
  4. When Enter or NumEnter has a press edge, the update calls `TextObj->OnKeyDown(VK_RETURN, 0)`
     (`0x101B3FC0`). Esc does the same with `VK_ESCAPE`. If the call returns nonzero, the update clears those
     edges.
  5. It calls `GetKeyboardState(input+0x298)` and copies only the low (toggle) bit of NumLock and of left and
     right Alt, Shift and Ctrl into bit 0x10.
- **What this means for hiding a key.** A tap shorter than a frame reaches the game only through
  `GetDeviceData`. A hold reaches it through `GetDeviceState`. To hide a key, zero its state byte **and** drop
  its press events, or zero their `dwData`.

## 3. One place (confidence: high)

There is one function, with two call sites `0x97` bytes apart. Both site signatures below match exactly once in
`.text`.

Function start `0x10005A40` (64 bytes):
```
10005A40: 81 EC 90 01 00 00 53 55 56 8B F1 57 89 74 24 34
10005A50: E8 9B F2 00 00 E8 12 D8 30 00 0F BF C0 89 44 24
10005A60: 40 8B 86 88 00 00 00 DB 44 24 40 85 C0 D9 5C 24
10005A70: 40 0F 84 61 04 00 00 8B 08 8D BE 98 00 00 00 57
```
GetDeviceState site `0x10005A61` (64 bytes; the call `FF 51 24` is at `0x10005A86`):
```
10005A61: 8B 86 88 00 00 00 DB 44 24 40 85 C0 D9 5C 24 40
10005A71: 0F 84 61 04 00 00 8B 08 8D BE 98 00 00 00 57 68
10005A81: 00 01 00 00 50 FF 51 24 3D AA 00 07 80 7F 55 74
10005A91: 0E 3D 0C 00 07 80 74 07 3D 1E 00 07 80 75 49 A0
```
GetDeviceData site `0x10005AFB` (64 bytes; the call `FF 52 28` is at `0x10005B1D`):
```
10005AFB: 8B 86 88 00 00 00 8D AE DC 08 00 00 8D 9E 9C 07
10005B0B: 00 00 6A 00 55 C7 45 00 10 00 00 00 8B 10 53 6A
10005B1B: 14 50 FF 52 28 3D AA 00 07 80 7F 55 74 0E 3D 0C
10005B2B: 00 07 80 74 07 3D 1E 00 07 80 75 49 A0 F8 76 45
```
Signatures. The wildcards cover the struct offsets, the stack offsets and the call targets:
```
GDS (45 bytes, 1 match at 0x10005A61):
8B 86 ?? ?? ?? ?? DB 44 24 ?? 85 C0 D9 5C 24 ?? 0F 84 ?? ?? ?? ?? 8B 08 8D BE ?? ?? ?? ?? 57 68 00 01 00 00 50 FF 51 24 3D AA 00 07 80
GDD (42 bytes, 1 match at 0x10005AFB):
8B 86 ?? ?? ?? ?? 8D AE ?? ?? ?? ?? 8D 9E ?? ?? ?? ?? 6A 00 55 C7 45 00 10 00 00 00 8B 10 53 6A 14 50 FF 52 28 3D AA 00 07 80
FN (78 bytes, 1 match at 0x10005A40; the function start through the GetDeviceState call):
81 EC 90 01 00 00 53 55 56 8B F1 57 89 74 24 34 E8 ?? ?? ?? ?? E8 ?? ?? ?? ?? 0F BF C0 89 44 24 40 8B 86 ?? ?? ?? ?? DB 44 24 40 85 C0 D9 5C 24 40 0F 84 ?? ?? ?? ?? 8B 08 8D BE ?? ?? ?? ?? 57 68 00 01 00 00 50 FF 51 24
KSETUP (24 bytes, 1 match at 0x10007E2A; CreateDevice with GUID_SysKeyboard):
8B 89 ?? ?? ?? ?? 6A 00 56 68 ?? ?? ?? ?? 8B 01 51 FF 50 0C 85 C0 7D 0D
```
The 8-byte tail `FF 5x 2x 3D AA 00 07 80` alone matches 4 times. The other two matches are the mouse reads
(`0x10006197`, `0x10008A0C`). So use the tail only inside GDS or GDD.

**Patch shapes that fit** (facts for the design, not tested):
- The calls are only 3 bytes long (`FF 51 24`, `FF 52 28`). Each is followed by `cmp eax,0x800700AA`
  (`3D AA 00 07 80`). Together they are 8 bytes: room for a 5-byte `call rel32` to a thunk that makes the COM
  call, filters, runs the `cmp` again and returns. `ret` keeps the flags.
- Each site starts with the 6-byte load `8B 86 88 00 00 00` (`mov eax,[esi+0x88]`) at `0x10005A61` and
  `0x10005AFB`. That is the PadHook revision 3 pattern. `mov eax, imm32` plus a `nop` can point the game at a
  proxy object. The proxy's `+0x24` and `+0x28` forward to the real `[esi+0x88]` and filter. The error paths load
  `[esi+0x88]` again themselves (`0x10005AB0`, `0x10005ACE`, `0x10005B47`, `0x10005B5C`), so Release, Acquire
  and re-create still reach the real device.
  - Site A tests the loaded pointer for null (`0x10005A6B`) and skips the whole keyboard block when it is null.
    A proxy is never null, so it must return an error when the real device is null.
- Registers at the calls: `esi` is the input object. At site A, `edi` is the state buffer. At site B, `ebx` is
  the event buffer and `ebp` points to the count.

## 4. Windower (confidence: high for the wrapper and its overrides, medium for the claim that the game holds it)

`C:\Windower4\Hook.dll` has PE timestamp `0x6AF1F654` and preferred base `0x10000000`. It cannot load there,
so the addresses below are RVAs.

- **Imports:** neither `dinput8` nor `d3d8`. It does import `SetWindowLongA`, `SetWindowsHookExA`,
  `CallNextHookEx`, `MapVirtualKeyA` and `VkKeyScanA`.
- **Strings:** `dinput8.dll`, `DirectInput8Create`, `Direct3DCreate8`, `SetWindowsHookExA`/`W`, `GetKeyboardState`,
  `polhook.dll`, and the commands `keyboard_blockinput`, `keyboard_bind`, `key_send` and `mouse_blockinput`.
  There is a trampoline hook library (`hooklib::trampoline`). So it hooks those functions by name.
- **RTTI classes:** `windower::direct_input` (`IDirectInput8A`), `direct_input_device` (`IDirectInputDevice8A`),
  **`direct_input_keyboard`**, `direct_input_mouse`, `direct_input_generic`, `input_manager`.
- **The keyboard wrapper's vtable** is at RVA `0x1861AC`. It overrides only three methods:
  `+0x24 GetDeviceState` (RVA `0x61BA0`), `+0x28 GetDeviceData` (RVA `0x61E50`) and
  `+0x34 SetCooperativeLevel` (RVA `0x62090`). The other methods pass through to the base class. The real
  device is at `wrapper+4`.
  - **GetDeviceState:**
    1. It calls the real device first.
    2. It records Shift, Ctrl, Alt, the Win keys (`0xDB`, `0xDC`) and Apps (`0xDD`).
    3. When input is blocked (an input-manager virtual call at +4, or the wrapper byte `+0x112`), it **copies
       Windower's own 256-byte state over the result** (as Fenestra does).
    4. When input is not blocked, it rewrites each byte to `0x80` or `0`. The key counts as down if the real
       state or Windower's own state (from `key_send`) has it down. Bind handling follows.
  - **GetDeviceData:**
    1. It calls the real device first. Then it handles each event:
       - Under the block, it drops the event.
       - The console key (byte `+0x10C`, with no modifiers) toggles the console, and the event is dropped.
       - Otherwise, when not blocked, it looks up a bind (RVA `0x33C60`). A bound key runs its command, and the
         event is dropped.
    2. It moves the remaining events down and writes the new count.
  - So Windower 4 already hides single keys (binds) in the same two methods the game calls.
- **Not checked at run time:** whether `[[0x10456DD0]+0x88]` is this wrapper. Checking it needs a read of a
  running game. The class exists, and Windower hooks `DirectInput8Create` by name, so it very likely is.
- If so, a hook at the game's call sites runs **after** Windower. Binds and the console key are already gone
  from the events. The state that the game gets already carries Windower's own changes.

## 5. Window messages and Win32 key APIs (confidence: high, except where noted)

- **Message pump** (`0x100015E4`): `PeekMessageA` with `PM_REMOVE`.
  - It drops `WM_IME_SETCONTEXT` (0x281) and `WM_ACTIVATEAPP` (0x1C) and does not dispatch them.
  - PrintScreen (`WM_SYSKEYDOWN` or `WM_KEYUP` with `VK_SNAPSHOT`) saves a screenshot to the clipboard
    (`0x10001CC0`).
  - It passes every other message to **`0x100016C0`**, then calls `TranslateMessage` and `DispatchMessageA`.
- **`0x100016C0`** (it sees the raw message before dispatch):
  - `WM_KEYDOWN` → `TextObj->OnKeyDown(vk, lParam)` (`0x101B3FC0`), except `VK_RETURN`, `VK_ESCAPE` and
    `VK_SEPARATOR`. Those three come from the DirectInput path. `VK_PROCESSKEY` goes through `ImmGetVirtualKey`.
  - `WM_CHAR` → `0x10007860` → `TextObj->OnChar(ch)` (`0x101B4CC0`). A debug console also uses it when the
    globals `0x1057964C` and `0x10622AF4` are set.
  - `WM_IME_STARTCOMPOSITION` → `0x101B3DD0`. `WM_IME_COMPOSITION` → `0x101B36B0`
    (`ImmGetCompositionStringA`). `0x281` to `0x286` go through a table to `0x101B3DC0` and `0x101B3CE0`.
    `WM_SYSKEYDOWN` with F10 goes to `0x101B36B0` under a condition.
  - `WM_ACTIVATE` → `0x100087D0` (Acquire or Unacquire).
- **WndProc** `0x10016870` (`RegisterClassA` at `0x1001665F`):
  - `WM_KEYDOWN` and `WM_KEYUP` only track `VK_SHIFT` (`0x10457BE0`), for aspect-ratio resizing.
  - It swallows `WM_IME_STARTCOMPOSITION`, `WM_IME_ENDCOMPOSITION`, `WM_IME_CONTROL` and some `WM_IME_NOTIFY`
    messages, and it filters some `WM_SYSCOMMAND` messages.
  - **No game input goes through it.**
- **GetKeyboardState:** once per frame (`0x10005E39`), for the toggle bits only (see §2).
- **GetAsyncKeyState:** only in the low-level hook, for `VK_CONTROL`.
- **GetKeyState:** not imported.
- **WH_KEYBOARD_LL hook** `0x10001100` (installed at `0x100012B4`):
  - It works only when `[0x10457C2C]` is 0.
  - It swallows the Win keys, Apps, Ctrl+Esc, Alt+Tab and Alt+Esc, VK `0xA6` to `0xB9` (browser, media and
    launch keys), `0x5E`, `VK_SLEEP` and VK `0x74`.
  - It does not feed the game.
- **The chat line** is the text object at `[0x10663EF8]`. `HasFocus` (`0x101B7260`) is true when state
  `+0xF108` is 4 or 5.
  - **Space opens it** as `WM_CHAR ' '` when the game mode `[[0x10457BD8]]` is `0x60` (`0x101B4D5F`).
  - **`/`** (`VK_OEM_2`) opens it as `WM_KEYDOWN` and types the slash (`0x101B5830`).
  - **Letters, digits and OEM keys** open it as `WM_KEYDOWN` only when `[[0x10663924]+0x44]` is 0
    (`0x101B94B0`, `0x101B5840`, `0x1025F680`). The client then re-injects the key with
    `MapVirtualKeyA` and `keybd_event` (`0x101B426D` to `0x101B4291`). With the value 1 or 2, letters do not
    open the line, so they fall through to the action bindings. That matches "a letter opens a menu".
    Which game option sets the value: **not found**.
  - **Its text** comes from `WM_CHAR` (`0x101B4CC0` → `0x101B7DE0`) and from IME composition. The edit keys come
    from `WM_KEYDOWN` (switch at `0x101B42EB`). Enter and Esc come from the DirectInput press edges (§2.4).
  - **Enter opening the line:** no such path exists in the text object while the line is closed. Enter and
    NumEnter are bound to actions 14, 66, 143, 145 and 147 (`bindings.txt`). If Enter opens the chat line in
    game, it does so through an action handler, which I did not trace. Confidence: medium.
- **Result:** a DirectInput-level hook stops the action bindings, the camera, the menu letters, and Enter and Esc
  reaching the text object. It does **not** stop `WM_KEYDOWN` or `WM_CHAR`, so Space and `/` can still open the
  chat line. Typed characters still reach a line that has focus. While Chronicle's search box has focus, those
  messages need a filter too.

## 6. The input mask (confidence: high for the mechanism, medium for the names)

- **`FUN_10124b70`** is `mov eax,[esp+4]; mov [0x1036F3D8],eax; ret`. It sets a 32-bit context mask.
  - The getter is `0x10124B80` (no callers). The test `0x101252E0` returns `mask & arg`.
  - The 16 writers set `0xFFFF`, `0x42` or `0x3E`, or restore a saved value. So menus and modes set the mask and
    put it back.
- **Category table:** one WORD per action id at `0x1036DF98`. There are 188 action ids.
- **Readers:**
  - **`0x10124E00`** (41 callers) is the axis getter, most likely `Input_GetAxisValueMerged`. It returns 0.0
    when `category & mask` is 0. Otherwise it calls up to two source functions from the table `0x1036E110`
    (two per axis) and returns the value with the larger magnitude.
  - **`0x10124F00`** (216 callers) is the action query. It returns false when:
    - `category & mask` is 0, or
    - the lock byte `0x104E2DF4` is set (except in mode 4). `0x10125330` sets the byte, and `0x10125320` clears
      it each frame. Six places set it.
    - Category bit `0x41` is set and the chat line has focus.

    Otherwise it walks up to three keyboard bindings for the action at `0x1036E6E8`. Each binding is a WORD:
    DIK code, plus a flags byte. The flag `0x40` means "not while the chat line has focus", and other flags set
    the Shift, Ctrl and Alt rules. It tests each binding with `0x10124810(dik, mode)`, where the modes are
    0 trigger, 1 press, 2 take trigger, 3 take press, 4 release and 5 held.
  - `0x10124B90` turns held keys into a 64-bit movement mask through a table at `0x1036F128`. It returns nothing
    while the chat line has focus or some menus are open.
- **Can the mask stop one key?** No.
  - It works on game actions by category. Clearing a bit turns off every action in that category, for the
    keyboard and the pad alike.
  - The game rewrites the mask from 16 places, so an outside writer would fight it.
  - Many key reads never check the mask. Examples: the direct key-state reads in the text object, the
    `0x10008830` wrappers on the arrow keys, and the listeners for new presses in §2.3.
  - A per-key filter at the two DirectInput reads (§3) is the place that fits.

## What I did not find or did not check

- That the device at `+0x88` is Windower's wrapper at run time. Checking it needs a read of a live process.
- What the press listeners at `[0x10663928]` and `[0x1066392C]` are (`vtbl+0x4C`).
- What `[0x10457C2C]` means. It gates `DISCL_NOWINKEY`, the low-level hook's filter and the DirectInput mouse.
  It is likely the window mode.
- Which game option sets `[[0x10663924]+0x44]`, the mode that decides whether letters open the chat line.
- Whether Enter opens the chat line in game, and through which action (ids 14, 66, 143, 145 and 147 are bound to
  Enter).
- Where Windower raises its Lua `keyboard` event. It is not in the two methods above, and it may be in a
  subclassed WndProc (`SetWindowLongA`).
