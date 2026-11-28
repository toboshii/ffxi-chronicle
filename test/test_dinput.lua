--[[
    test_dinput.lua - DirectInput pads (nui 1.8.0): the layouts in ui/pad.lua (by maker, the conversion to XInput's terms, the
    chord's DirectInput buttons, the names, the game's own Confirm and Cancel), then chronicle.lua on the real addon through
    test/harness.lua with the fake DLL's DirectInput pad (opts.dinput, N.distate, N.di_chord): the chord, the cursor and the
    buttons, the hint, the layout setting, the Settings row and the command, the way back to XInput, a torn read, the messages
    and the status lines, and an older DLL. Each rule has its own named check (DIN-1 ...), and each fails on the code without it.

        cd addons/chronicle && "/c/Program Files (x86)/Lua/5.1/lua.exe" test/test_dinput.lua
]]

local H = dofile('test/harness.lua')

local pass, fail = 0, 0
local function check(name, cond, detail)
    if cond then pass = pass + 1 else
        fail = fail + 1
        print('FAIL ' .. name .. (detail ~= nil and (': ' .. tostring(detail)) or ''))
    end
end

local KEEP = {'data/places_berrant.lua', 'data/pages_berrant.lua', 'data/places.lua', 'data/pages.lua'}
local restore = H.protect(KEEP)

package.path = './?.lua;' .. package.path
local pad = require('ui/pad')
local B = pad.B
local PS, XB, NS, GEN = pad.LAYOUTS.playstation, pad.LAYOUTS.xbox, pad.LAYOUTS.nintendo, pad.LAYOUTS.generic
local SONY, MS, NINTENDO = 0x054C, 0x045E, 0x057E
local function bit(i) return 2 ^ i end
local function has(b, m) return pad.band(b, m) ~= 0 end

---------------------------------------------------------------------------------------------------------------------------
-- the layouts, pure
do
    check('DIN-1: a Sony pad is a PlayStation pad', pad.layout_for(SONY) == 'playstation')
    check('DIN-1: a Microsoft pad is an Xbox pad', pad.layout_for(MS) == 'xbox')
    check('DIN-1: a Nintendo pad', pad.layout_for(NINTENDO) == 'nintendo')
    check('DIN-1: any other maker, or none known: generic', pad.layout_for(0x2DC8) == 'generic' and pad.layout_for(0) == 'generic'
        and pad.layout_for(nil) == 'generic')

    local function conv(L, b, pov, x, y, z, rx, ry, rz) return pad.from_dinput(L, b, pov or -1, x or 0, y or 0, z or 0, rx or 0, ry or 0, rz or 0) end
    -- PlayStation: Square, Cross, Circle, Triangle, L1, R1, L2, R2, Share, Options, L3, R3
    local want = {B.x, B.a, B.b, B.y, B.lb, B.rb, B.lt, B.rt, B.back, B.start, B.l3, B.r3}
    local ok = true
    for i = 0, 11 do ok = ok and conv(PS, bit(i)) == want[i + 1] end
    check('DIN-2: PlayStation buttons 0..11 are Square, Cross, Circle, Triangle, L1, R1, L2, R2, Share, Options, L3, R3', ok)
    local b, lt, rt = conv(PS, bit(6) + bit(7))
    check('DIN-2: L2 and R2 are LT and RT, fully pressed', b == B.lt + B.rt and lt == 255 and rt == 255)
    check('DIN-2: buttons the layout does not name do nothing (PS, touchpad)', conv(PS, bit(12) + bit(13)) == 0)
    -- Xbox through DirectInput: A, B, X, Y, LB, RB, Back, Start, L3, R3, and the triggers on Z
    want = {B.a, B.b, B.x, B.y, B.lb, B.rb, B.back, B.start, B.l3, B.r3}
    ok = true
    for i = 0, 9 do ok = ok and conv(XB, bit(i)) == want[i + 1] end
    check('DIN-2: Xbox buttons 0..9 are A, B, X, Y, LB, RB, Back, Start, L3, R3', ok)
    b, lt, rt = conv(XB, 0, -1, 0, 0, 127)
    check('DIN-2: Xbox: Z up is LT', b == B.lt and lt == 255 and rt == 0, b)
    b, lt, rt = conv(XB, 0, -1, 0, 0, -127)
    check('DIN-2: Xbox: Z down is RT', b == B.rt and rt == 255 and lt == 0, b)
    b, lt = conv(XB, 0, -1, 0, 0, 10)
    check('DIN-2: Xbox: a light touch is no press', b == 0 and lt > 0 and lt <= 30, lt)
    -- Nintendo, by place: bottom (B) is A's role, right (A) is B's, left (Y) is X's, top (X) is Y's
    want = {B.a, B.b, B.x, B.y, B.lb, B.rb, B.lt, B.rt, B.back, B.start, B.l3, B.r3}
    ok = true
    for i = 0, 11 do ok = ok and conv(NS, bit(i)) == want[i + 1] end
    check('DIN-2: Nintendo buttons 0..11 by place: B, A, Y, X, L, R, ZL, ZR, Minus, Plus, LS, RS', ok)
    -- the POV is the D-pad, a diagonal two directions
    local P = {[0] = B.up, [4500] = B.up + B.right, [9000] = B.right, [13500] = B.right + B.down, [18000] = B.down,
               [22500] = B.down + B.left, [27000] = B.left, [31500] = B.left + B.up, [-1] = 0}
    ok = true
    for pov, w in pairs(P) do ok = ok and conv(PS, 0, pov) == w end
    check('DIN-2: the POV in 8 directions, and centred', ok)
    -- the sticks: -127..127 to XInput's range, y the other way up; the right stick on each layout's axes
    local _, _, _, lx, ly, sx, sy = conv(PS, 0, -1, 127, -127, 64, 99, 99, -64)
    check('DIN-2: the left stick, up positive as XInput', lx == 32766 and ly == 32766, lx .. ' ' .. ly)
    check('DIN-2: PlayStation: the right stick on Z and Rz', sx == 64 * 258 and sy == 64 * 258, sx .. ' ' .. sy)
    _, _, _, _, _, sx, sy = conv(XB, 0, -1, 0, 0, 77, 50, -50, 99)
    check('DIN-2: Xbox: the right stick on Rx and Ry', sx == 50 * 258 and sy == 50 * 258, sx .. ' ' .. sy)

    check('DIN-3: the chord in DirectInput buttons: PlayStation L3+R3 is 10 and 11', pad.di_mask(PS, B.l3 + B.r3) == bit(10) + bit(11))
    check('DIN-3: Xbox L3+R3 is 8 and 9', pad.di_mask(XB, B.l3 + B.r3) == bit(8) + bit(9))
    check('DIN-3: PlayStation LB+RB is 4 and 5', pad.di_mask(PS, B.lb + B.rb) == bit(4) + bit(5))
    check('DIN-3: Xbox Back+Start is 6 and 7', pad.di_mask(XB, B.back + B.start) == bit(6) + bit(7))

    check('DIN-6: names on the pad', pad.label(PS, 'a') == 'Cross' and pad.label(PS, 'lb') == 'L1' and pad.label(NS, 'a') == 'B'
        and pad.label(NS, 'r3') == 'RS' and pad.label(XB, 'a') == 'A' and pad.label(XB, 'lb') == 'LB')
    check('DIN-6: a generic pad by number', pad.label(GEN, 'a') == '#2' and pad.label(GEN, 'l3') == '#11')
    check('DIN-6: XInput names without a layout', pad.label(nil, 'a') == 'A' and pad.label(nil, 'rt') == 'RT')
    check('DIN-6: chord labels', pad.chord_label(NS, {name = 'l3+r3'}) == 'LS+RS' and pad.chord_label(GEN, {name = 'lb+rb'}) == '#5+#6'
        and pad.chord_label(nil, {name = 'l3+r3'}) == 'L3+R3')

    -- padsin000 in DirectInput mode holds button numbers: slot 7 Confirm, slot 5 Cancel
    local cfg = {padsin = '0,0,0,0,0,1,0,2'}                     -- Cancel on button 1, Confirm on button 2
    local c, x = pad.from_config_dinput(cfg, PS)
    check('DIN-5: PlayStation: Confirm on Circle, Cancel on Cross', c == 'b' and x == 'a', tostring(c) .. ' ' .. tostring(x))
    c, x = pad.from_config_dinput(cfg, XB)
    check('DIN-5: the same numbers on an Xbox pad: Confirm on X, Cancel on B', c == 'x' and x == 'b')
    c, x = pad.from_config_dinput({padsin = '0,0,0,0,0,9,0,9'}, PS)
    check('DIN-5: not a face button, or one button for both: A and B', c == 'a' and x == 'b')
    check('DIN-5: no config: A and B', pad.from_config_dinput(nil, PS) == 'a')

    check('DIN-7: layout names', pad.parse_layout('PlayStation') == 'playstation' and pad.parse_layout('ds4') == nil
        and pad.parse_layout('dualsense') == 'playstation' and pad.parse_layout('Switch') == 'nintendo'
        and pad.parse_layout('auto') == 'auto' and pad.parse_layout(' xbox ') == 'xbox')
    local k, why = pad.parse_layout('gamecube')
    check('DIN-7: an unknown layout is refused, and why', k == nil and tostring(why):find('not a layout', 1, true))
    local conf = pad.chord_conflicts_dinput({padsin = '10,0,0,0,0,0,0,0,0,0,0,11'}, PS, B.l3 + B.r3)
    check('DIN-12: the game also maps the chord: slots 0 and 11', #conf == 2 and conf[1] == 0 and conf[2] == 11)
end

---------------------------------------------------------------------------------------------------------------------------
-- the addon
-- fake: the fake DLL's options (dinput on unless said otherwise); settings: the saved settings
local function shown(fake, settings)
    fake = fake or {}
    if fake.dinput == nil then fake.dinput = true end
    local env = H.load({fake = fake, settings = settings or {visible_on_load = false}})
    env.cmd('show')
    env.packets(H.fixture_packets(530))
    env.frame()
    return env, env.win(), env.app
end

-- the game reads a DirectInput pad: N.distate, bumped
local function di(env, buttons, fields)
    local d = env.N.distate or {seq = 0, vendor = SONY, product = 0x09CC, name = 'Wireless Controller'}
    env.N.distate = d
    d.buttons, d.pov, d.torn, d.conn = buttons or 0, -1, nil, true
    for k, v in pairs(fields or {}) do d[k] = v end
    d.seq = d.seq + 1
    env.frame()
end
local function di_tap(env, buttons, fields) di(env, buttons, fields) di(env, 0, fields) end
local function di_chord(env, a, b, fields) di(env, a, fields) di(env, a + b, fields) di(env, 0, fields) end
local function hint(env) return env.N.layers[3] and env.N.layers[3].text or '' end
local function chat_has(env, s)
    for _, l in ipairs(env.chat) do if l:find(s, 1, true) then return true end end
    return false
end
local function said_since(env, n, s)
    for i = n + 1, #env.chat do if env.chat[i]:find(s, 1, true) then return true end end
    return false
end
local settings_screen = require('ui/screens/settings')
local function row(app, k)
    for _, r in ipairs(settings_screen.rows(app)) do if r.key == k then return r end end
end
local function rowv(app, k) local r = row(app, k) return r and r.value end

do  -- DIN-3, DIN-4, DIN-6: a PlayStation pad, the default layout setting (auto)
    local env, win, app = shown()
    local N = env.N
    check('DIN-3: joined: the chord in generic numbering until a pad is read', N.chord == B.l3 + B.r3 and N.di_chord == bit(10) + bit(11),
        tostring(N.di_chord))
    di(env, 0)
    check('DIN-4: a DirectInput pad read: not held yet', not N.pad_holding and not win.pad_mode)
    di_chord(env, bit(10), bit(11))
    check('DIN-4: L3 + R3 (buttons 10 and 11) takes the pad', N.pad_holding and win.pad_mode)
    check('DIN-6: the hint names the PlayStation buttons', hint(env):find('Cross Open  Circle Back  L1 R1 Section  L2 R2 Page  L3+R3 Done', 1, true) ~= nil,
        hint(env))
    local first = win.cursor
    di(env, 0, {pov = 9000})
    di(env, 0)
    check('DIN-4: the POV right moves the cursor', win.cursor and first and win.cursor ~= first and win.cursor.x0 > first.x0,
        win.cursor and win.cursor.id)
    local area = win.cursor and win.cursor.area
    di_tap(env, bit(1))                                            -- Cross
    check('DIN-4: Cross confirms: the card opens its area', app.view.name == 'area' and app.view.params.area == area, app.view.name)
    di_tap(env, bit(2))                                            -- Circle
    check('DIN-4: Circle goes back', app.view.name == 'home')
    local tab = app.settings.active_tab
    di_tap(env, bit(5))                                            -- R1
    check('DIN-4: R1 is the next section', app.settings.active_tab ~= tab)
    di_tap(env, bit(4))
    check('DIN-4: L1 the one before', app.settings.active_tab == tab)
    local y0 = win.scroll_y or 0
    di(env, 0, {rz = 127})
    env.frame(0.1)
    env.frame(0.1)
    di(env, 0, {rz = 0})
    check('DIN-4: the right stick (Rz) scrolls', (win.scroll_y or 0) ~= y0 or app.view.name == 'home', win.scroll_y)
    di_tap(env, bit(9))                                            -- Options
    check('DIN-4: Options is Settings', app.view.name == 'settings')
    di_tap(env, bit(2))
    di_chord(env, bit(10), bit(11))
    check('DIN-4: the chord again gives the pad back', not N.pad_holding and not win.pad_mode)
end

do  -- DIN-3 and DIN-6: the maker decides the layout once the pad is read
    local env, win = shown()
    local N = env.N
    di(env, 0, {vendor = MS, product = 0x028E, name = 'Controller (Xbox 360)'})
    check('DIN-3: an Xbox pad read: the chord as its buttons 8 and 9', N.di_chord == bit(8) + bit(9), tostring(N.di_chord))
    di_chord(env, bit(8), bit(9))
    check('DIN-6: Xbox: L3 + R3 takes the pad, the hint as XInput', N.pad_holding
        and hint(env):find('A Open  B Back  LB RB Section  LT RT Page  L3+R3 Done', 1, true) ~= nil, hint(env))
    local acts = {}
    local real_act = win.pad_scroll
    win.pad_scroll = function(self, dy, abs) acts[#acts + 1] = dy return real_act(self, dy, abs) end
    di(env, 0, {z = -127})                                         -- RT
    di(env, 0, {z = 0})
    di(env, 0, {z = 127})                                          -- LT
    di(env, 0, {z = 0})
    win.pad_scroll = real_act
    check('DIN-4: Xbox: RT (Z down) pages down, LT (Z up) pages up', #acts == 2 and acts[1] > 0 and acts[2] < 0,
        #acts .. ' ' .. tostring(acts[1]) .. ' ' .. tostring(acts[2]))
    env = shown()
    di(env, 0, {vendor = NINTENDO, name = 'Pro Controller'})
    di_chord(env, bit(10), bit(11))
    check('DIN-6: Nintendo: the hint names its buttons', hint(env):find('B Open  A Back  L R Section  ZL ZR Page  LS+RS Done', 1, true) ~= nil,
        hint(env))
    env = shown()
    di(env, 0, {vendor = 0x0079, name = 'USB Gamepad'})
    di_chord(env, bit(10), bit(11))
    check('DIN-6: a generic pad: the hint by number', hint(env):find('#2 Open  #3 Back  #5 #6 Section  #7 #8 Page  #11+#12 Done', 1, true) ~= nil,
        hint(env))
end

do  -- DIN-5: the game's own Confirm and Cancel for a DirectInput pad
    local env, _, app = shown({pad_config = {key = 'k', padmode = '1,0,0,0,1,0', padsin = '0,0,0,0,0,1,0,2'}})
    di(env, 0)
    di_chord(env, bit(10), bit(11))
    check('DIN-5: Confirm on Circle (button 2): the hint says so', hint(env):find('Circle Open  Cross Back', 1, true) ~= nil, hint(env))
    di_tap(env, bit(2))
    check('DIN-5: Circle confirms', app.view.name == 'area', app.view.name)
    di_tap(env, bit(1))
    check('DIN-5: Cross goes back', app.view.name == 'home')
end

do  -- DIN-7: the layout setting, the command and the Settings row
    local env, win, app = shown()
    local N = env.N
    di(env, 0)
    check('DIN-7: auto, a Sony pad: the row says Auto (PlayStation)', rowv(app, 'pad_layout') == 'Auto (PlayStation)',
        rowv(app, 'pad_layout'))
    env.cmd('pad', 'layout', 'xbox')
    check('DIN-7: //cr pad layout xbox: set and saved', app.settings.pad_layout == 'xbox' and chat_has(env, 'layout Xbox (the setting)'))
    check('DIN-7: the chord goes again in Xbox numbering', N.di_chord == bit(8) + bit(9), tostring(N.di_chord))
    check('DIN-7: the row names it', rowv(app, 'pad_layout') == 'Xbox')
    di_chord(env, bit(8), bit(9))
    check('DIN-7: Xbox numbering on a Sony pad: buttons 8 and 9 take it', N.pad_holding)
    di_chord(env, bit(8), bit(9))
    local n = #env.chat
    env.cmd('pad', 'layout', 'gamecube')
    check('DIN-7: an unknown layout: refused, kept', app.settings.pad_layout == 'xbox' and said_since(env, n, 'not a layout'))
    app.prefs.change('pad_layout')
    check('DIN-7: the Settings row: Xbox then Nintendo', app.settings.pad_layout == 'nintendo' and N.di_chord == bit(10) + bit(11))
    app.prefs.change('pad_layout')
    app.prefs.change('pad_layout')
    check('DIN-7: then Generic, then Auto', app.settings.pad_layout == 'auto' and rowv(app, 'pad_layout') == 'Auto (PlayStation)')
    n = #env.chat
    env.cmd('pad', 'layout')
    check('DIN-7: //cr pad layout says what is in use', said_since(env, n, 'layout PlayStation (auto'))
    local env2 = shown(nil, {visible_on_load = false, pad_layout = 'nintendo'})
    check('DIN-7: a saved layout: the chord in its numbering at once', env2.N.di_chord == bit(10) + bit(11))
end

do  -- DIN-8: back to XInput, DIN-9: a torn read
    local env, win = shown()
    local N = env.N
    di(env, 0)
    di_chord(env, bit(10), bit(11))
    check('DIN-8: held through DirectInput', N.pad_holding and hint(env):find('Cross Open', 1, true) ~= nil)
    N.distate.torn = true
    N.distate.seq = N.distate.seq + 1
    local cur = win.cursor
    env.frame()
    env.frame()
    check('DIN-9: a torn read: nothing changes', N.pad_holding and win.cursor == cur and hint(env):find('Cross Open', 1, true) ~= nil)
    N.distate.torn, N.distate.conn = nil, false
    N.distate.seq = N.distate.seq + 1
    env.frame()
    check('DIN-8: no DirectInput pad read any more: XInput\'s names again', hint(env):find('A Open  B Back  LB RB', 1, true) ~= nil,
        hint(env))
    local p = N.padstate
    p.buttons, p.seq = B.l3, p.seq + 1
    env.frame()
    p.buttons, p.seq = B.l3 + B.r3, p.seq + 1
    env.frame()
    p.buttons, p.seq = 0, p.seq + 1
    env.frame()
    check('DIN-8: the XInput pad works again: its chord gives the pad back', not N.pad_holding)
end

do  -- DIN-13: the DirectInput values are turned over only when they change
    local env = shown()
    local P = package.loaded['ui/pad']                             -- the addon's own copy (the harness loads it afresh)
    local calls, real = 0, P.from_dinput
    P.from_dinput = function(...) calls = calls + 1 return real(...) end
    di(env, bit(3))
    local after = calls
    env.frame()
    env.frame()
    env.frame()
    check('DIN-13: three frames of the same read: no new conversion', calls == after and after >= 1, calls)
    di(env, 0)
    check('DIN-13: a change: one more', calls == after + 1, calls)
    P.from_dinput = real
end

do  -- DIN-11: //cr pad, and the messages
    local env, win = shown({pad_route = 'wrapper', pad_shim = false,
                            pad_config = {key = 'k', padmode = '1,0,0,0,1,0', padsin = '0,0,0,0,0,0,0,0'}})
    local N = env.N
    local n = #env.chat
    env.cmd('pad')
    check('DIN-11: no pad read yet, DirectInput live: says the game has read no controller',
        not N.pad_holding and said_since(env, n, 'has not read a controller yet'), env.chat[#env.chat])
    check('DIN-11: and not the old XInput-off message', not said_since(env, n, 'cannot read'))
    di(env, 0)
    env.cmd('pad')
    check('DIN-11: a DirectInput pad read: //cr pad takes it', N.pad_holding and win.pad_mode)
    env.cmd('pad')
    check('DIN-11: and gives it back', not N.pad_holding)
    env = shown({pad_route = 'wrapper', pad_shim = false, di_state = 'blocked', di_describe = 'blocked: not found',
                 pad_config = {key = 'k', padmode = '1,0,0,0,1,0', padsin = '0'}})
    n = #env.chat
    env.cmd('pad')
    check('DIN-11: DirectInput refused, XInput off: says so, with the reason', said_since(env, n, 'Enable XInput is off')
        and said_since(env, n, 'DirectInput: blocked: not found'))
end

do  -- DIN-12: the status lines
    local env = shown()
    di(env, 0)
    local n = #env.chat
    env.cmd('pad', 'status')
    check('DIN-12: the DirectInput line names the pad and the layout', said_since(env, n, 'controller DirectInput: fake DirectInput')
        and said_since(env, n, 'the game reads Wireless Controller (054C:09CC), layout PlayStation (auto)'))
    env = shown()
    n = #env.chat
    env.cmd('pad', 'status')
    check('DIN-12: no DirectInput pad read: says so', said_since(env, n, 'the game reads no DirectInput pad'))
end

do  -- DIN-10: an older DLL (no pad_dinput): XInput as before, and the old message
    local env, win = shown({dinput = false, pad_route = 'wrapper', pad_shim = false,
                            pad_config = {key = 'k', padmode = '1,0,0,0,1,0', padsin = '0'}})
    local N = env.N
    check('DIN-10: an older DLL: no DirectInput chord argument needed', N.chord == B.l3 + B.r3)
    local n = #env.chat
    env.cmd('pad')
    check('DIN-10: XInput off: the old message', said_since(env, n, 'which this _chronicle.dll cannot read') and not N.pad_holding)
    n = #env.chat
    env.cmd('pad', 'status')
    check('DIN-10: no DirectInput status line', not said_since(env, n, 'controller DirectInput'))
end

do  -- DIN-14: the help names the command
    local env = shown()
    env.cmd('help')
    check('DIN-14: //cr help lists pad layout', chat_has(env, 'pad layout [auto | playstation | xbox | nintendo | generic]'))
end

restore()
print(('test_dinput: %d passed, %d failed'):format(pass, fail))
os.exit(fail == 0 and 0 or 1)
