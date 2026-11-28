--[[
    The game's own uses of a key, from nui's key_bindings() (nui 1.7.0): a copy of the client's action table, its
    movement table, its keyboard mode and its layout. Pure: no Windower, no DLL. docs/key-bindings-research.md has the
    research.

    A binding WORD holds the DIK code in its low byte and the rules in its high byte. All rules must hold:
        0x01 Shift held      0x02 Ctrl held        0x04 Alt held            0x08 Ctrl and Alt held
        0x10 Ctrl or Alt     0x20 Shift not held   0x40 not in the chat line 0x80 neither Ctrl nor Alt
    Chronicle never hides a key while the chat line is open, so 0x40 changes nothing here. 0x10 also needs the
    client's shortcut switch, which is on unless the game's key-assignment menu is open.

    A movement entry (key | rule << 8 | context << 16) acts only in keyboard modes 1 and 2. Its rule: 0 no modifier
    (also with Ctrl or Alt, unless the key is a shortcut key), 1 Ctrl, 2 Alt, 4 Shift, 8 not Shift, 7 any.

    Keyboard layouts 2 and 3 remap some DIK codes before the game reads them, through two fixed tables in the client.
]]

local keybinds = {}

local function bit(v, b) return math.floor(v / b) % 2 == 1 end

-- The client's remap tables, as from -> to (FFXiMain.dll 2026-11-02: layout 2 at 0x103509D4, layout 3 at 0x103509B4).
keybinds.REMAP = {
    [2] = {[0x28] = 0xF0, [0x1A] = 0xF1, [0x27] = 0xF2, [0x0C] = 0xF3, [0x1B] = 0x1A, [0x2B] = 0x1B, [0x0D] = 0x28,
           [0x35] = 0x0C, [0x29] = 0x90, [0x15] = 0x2C, [0x2C] = 0x15},
    [3] = {[0x28] = 0xF8, [0x1B] = 0xF9, [0x2B] = 0xFA, [0x29] = 0xFB, [0x0C] = 0xFC, [0x35] = 0xFD, [0x1A] = 0x90,
           [0x11] = 0x2C, [0x10] = 0x1E, [0x1E] = 0x10, [0x27] = 0x32, [0x34] = 0x00, [0x33] = 0x27, [0x32] = 0x33,
           [0x2C] = 0x11},
}

-- the code the game's tables use for a key the player presses (Windower's DIK code)
function keybinds.game_code(dik, layout)
    local t = keybinds.REMAP[layout or 0]
    if t and t[dik] ~= nil then return t[dik] end
    return dik
end

-- Does binding WORD w act on key k ({dik = game code, ctrl, alt, shift})?
function keybinds.action_hits(w, k)
    local d, r = w % 256, math.floor(w / 256) % 256
    if d == 0 or d ~= k.dik then return false end
    local ca = k.ctrl or k.alt
    if bit(r, 0x80) and ca then return false end
    if bit(r, 0x01) and not k.shift then return false end
    if bit(r, 0x02) and not k.ctrl then return false end
    if bit(r, 0x04) and not k.alt then return false end
    if bit(r, 0x08) and not (k.ctrl and k.alt) then return false end
    if bit(r, 0x10) and not ca then return false end
    if bit(r, 0x20) and k.shift then return false end
    return true
end

-- Is the key a shortcut key (the first binding of an action, with rule 0x10)? The movement reader leaves a rule 0 key
-- with Ctrl or Alt to the shortcut then.
local function shortcut(b, dik)
    local a = b.actions or {}
    for i = 1, #a, 3 do
        local w = a[i] or 0
        if w % 256 == dik and bit(math.floor(w / 256) % 256, 0x10) then return true end
    end
    return false
end

-- Does movement entry m act on key k, in the client's own order of tests?
function keybinds.move_hits(m, k, is_shortcut)
    local d, r = m % 256, math.floor(m / 256) % 256
    if d == 0 or d ~= k.dik then return false end
    if r == 7 then return true end
    if k.ctrl or k.alt then
        if k.ctrl and not k.alt and r == 1 then return true end
        if k.alt and not k.ctrl and r == 2 then return true end
        return r == 0 and not is_shortcut
    end
    if r == 0 then return true end
    if k.shift then return r == 4 end
    return r == 8
end

-- Names for the actions the code shows (docs/key-bindings-research.md). The rest stay numbers.
local NAMES = {[14] = 'Confirm', [15] = 'Cancel'}
for i = 0, 9 do                                    -- ids 98 and 108 are the 0 key (macro 10), then 1 to 9
    NAMES[98 + i] = 'Alt macro ' .. (i == 0 and 10 or i)
    NAMES[108 + i] = 'Ctrl macro ' .. (i == 0 and 10 or i)
end
keybinds.NAMES = NAMES

-- The keyboard mode is the game's "Keyboard size" (Config, Misc. 2). Compact 1 adds the movement keys for keyboards with no
-- number pad, and Compact 2 adds mouse support to it. Only the two compact sizes let the player reassign keys.
keybinds.MODE_NAMES = {[0] = 'Full', [1] = 'Compact 1', [2] = 'Compact 2'}

-- b: key_bindings()'s table. k: keys.parse's key ({dik, ctrl, alt, shift}, Windower's code).
-- -> a list of what the game does with that key (strings, the actions first in id order), or nil when b is nil
function keybinds.uses(b, k)
    if type(b) ~= 'table' or type(k) ~= 'table' then return nil end
    local g = {dik = keybinds.game_code(k.dik, b.layout), ctrl = k.ctrl == true, alt = k.alt == true, shift = k.shift == true}
    local out, seen = {}, {}
    local a = b.actions or {}
    for i = 1, #a do
        local id = math.floor((i - 1) / 3)
        if not seen[id] and keybinds.action_hits(a[i] or 0, g) then
            seen[id] = true
            out[#out + 1] = NAMES[id] and (NAMES[id] .. ' (game action ' .. id .. ')') or ('game action ' .. id)
        end
    end
    if b.mode == 1 or b.mode == 2 then
        local sc = shortcut(b, g.dik)
        for _, m in ipairs(b.moves or {}) do
            if keybinds.move_hits(m, g, sc) then
                out[#out + 1] = 'a movement or camera key (keyboard size ' .. (keybinds.MODE_NAMES[b.mode] or tostring(b.mode)) .. ')'
                break
            end
        end
    end
    return out
end

return keybinds
