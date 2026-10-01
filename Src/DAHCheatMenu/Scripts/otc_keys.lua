--[[
  otc_keys.lua (Off The Clock) v1.1 - hotkeys read on the GAME THREAD for UE4SS Lua mods.
  Built for Palworld 1.0 on UE4SS 3.0.1 build 2281fa31; v1.1 adds Grounded 1 (UE4SS f08dfdf). Master copy:
  our shared master copy of otc_keys.lua; each mod ships its own copy next to main.lua (main.lua refuses to use an older copy).

  v1.1 (2026-09-30), backward compatible (Palworld calls and behaviour unchanged):
    - Grounded frame source: K:start_grounded() hooks /Script/Maine.SurvivalComponent:GetBreathSecondsLeft, a native
      UFunction that BP_SurvivalPlayerCharacter_C's ReceiveTick calls on every frame (unconditional branch of its
      Sequence node; found by disassembling the cooked Blueprint, see our test notes).
      The context is your character's SurvivalComponent -> GetOwner() -> Controller (must be the local one).
      Generic form: K:start(path, { pc_of = fn(obj) -> controller or nil, announce = true, missing = "text" }).
    - Modifiers: a key entry may carry mods = { "CONTROL" } ("CTRL", "SHIFT", "ALT" too): it fires only when a
      left or right modifier of each listed kind is held at the moment the key goes down.
    - announce = true logs ONE line the first time the per-frame hook fires ("hotkeys live: ...").
    - Re-entrancy guard: a key action that makes the game call the hooked function again does not poll twice.

  Why (our test notes):
    On this UE4SS build RegisterKeyBind callbacks run on UE4SS's own UpdateThread, and LoopAsync / ExecuteWithDelay /
    ExecuteAsync callbacks on a per-mod async thread. Both run the mod's Lua state while the same mod's hook callbacks
    run it on the game thread (hook callbacks take no lock), which can corrupt the Lua state and crash the game.
    So: no RegisterKeyBind. The key is read inside a game-thread hook with PlayerController:IsInputKeyDown.

  Use:
    local K = Keys.new(S, {
        { name = KEY_NAME, what = "toggle", on_press = function(pc) ... end },   -- on_press runs on the game thread
                                                              -- (v1.1: pc = the local controller that was read)
    })
    K:start()          -- registers ONE per-frame game-thread hook (PalHUDInGame:TickWorldHUDs), only if a key is set
    K:start_grounded() -- Grounded 1: the same with SurvivalComponent:GetBreathSecondsLeft (v1.1)
    -- key entry option (v1.1): mods = { "CONTROL" } -> Ctrl + key (left or right Ctrl)
    -- or, in a mod that already hooks TickWorldHUDs: call K:on_frame(ctx) from that callback instead of K:start()
    K:poll_ctx(ctx)    -- optional, from a PlayerController hook: fallback when the per-frame hook is missing
    K:poll_pc(pc)      -- the same with an already unwrapped controller
    K:stop()           -- on QuitGame

  Per frame: the hooked function's own object (the in-game HUD) -> HUD.PlayerOwner -> pc:IsInputKeyDown(FKey) for
  each configured key, with edge detection (one press per key-down; holding the key does not repeat; a key already
  held when polling starts does not fire). The hooked function's parameters are never read. Nothing is cached
  between frames. No key configured = no hook at all (zero cost). IsInputKeyDown failing 30 frames in a row = hotkeys
  switch themselves off with one log line.

  Key names: the UE4SS key names our configs always used (NUM_FOUR, DIVIDE, ADD, SUBTRACT, F11, A, ...), mapped to
  Unreal FKey names (NumPadFour, Divide, Add, Subtract, F11, A, ...). Unreal names ("NumPadFour") work too.
  "" / "NONE" / "OFF" = no key.
  Numpad keys need Num Lock on (with Num Lock off Windows sends arrows/Home/End/... instead).
  Keys count only while the game window has focus and the game itself receives keyboard input (not while typing
  in a text box).
]]

local M = { VERSION = "1.1" }
M.__index = M

-- UE4SS Key name -> Unreal FKey name.
local UE = {
    NUM_ZERO = "NumPadZero", NUM_ONE = "NumPadOne", NUM_TWO = "NumPadTwo", NUM_THREE = "NumPadThree",
    NUM_FOUR = "NumPadFour", NUM_FIVE = "NumPadFive", NUM_SIX = "NumPadSix", NUM_SEVEN = "NumPadSeven",
    NUM_EIGHT = "NumPadEight", NUM_NINE = "NumPadNine",
    MULTIPLY = "Multiply", ADD = "Add", SUBTRACT = "Subtract", DECIMAL = "Decimal", DIVIDE = "Divide",
    ZERO = "Zero", ONE = "One", TWO = "Two", THREE = "Three", FOUR = "Four", FIVE = "Five", SIX = "Six",
    SEVEN = "Seven", EIGHT = "Eight", NINE = "Nine",
    F1 = "F1", F2 = "F2", F3 = "F3", F4 = "F4", F5 = "F5", F6 = "F6", F7 = "F7", F8 = "F8", F9 = "F9",
    F10 = "F10", F11 = "F11", F12 = "F12",
    BACKSPACE = "BackSpace", TAB = "Tab", RETURN = "Enter", PAUSE = "Pause", CAPS_LOCK = "CapsLock",
    ESCAPE = "Escape", SPACE = "SpaceBar", PAGE_UP = "PageUp", PAGE_DOWN = "PageDown", END = "End", HOME = "Home",
    LEFT_ARROW = "Left", UP_ARROW = "Up", RIGHT_ARROW = "Right", DOWN_ARROW = "Down", INS = "Insert", DEL = "Delete",
    NUM_LOCK = "NumLock", SCROLL_LOCK = "ScrollLock",
    LEFT_MOUSE_BUTTON = "LeftMouseButton", RIGHT_MOUSE_BUTTON = "RightMouseButton",
    MIDDLE_MOUSE_BUTTON = "MiddleMouseButton", XBUTTON_ONE = "ThumbMouseButton", XBUTTON_TWO = "ThumbMouseButton2",
    OEM_ONE = "Semicolon", OEM_PLUS = "Equals", OEM_COMMA = "Comma", OEM_MINUS = "Hyphen", OEM_PERIOD = "Period",
    OEM_TWO = "Slash", OEM_THREE = "Tilde", OEM_FOUR = "LeftBracket", OEM_FIVE = "Backslash",
    OEM_SIX = "RightBracket", OEM_SEVEN = "Apostrophe",
}
for c in ("ABCDEFGHIJKLMNOPQRSTUVWXYZ"):gmatch(".") do UE[c] = c end
local UNREAL = {}
for _, v in pairs(UE) do UNREAL[v:upper()] = v end

M.FRAME_HOOK = "/Script/Pal.PalHUDInGame:TickWorldHUDs"
M.GROUNDED_FRAME_HOOK = "/Script/Maine.SurvivalComponent:GetBreathSecondsLeft"
local MAX_FAILS = 30

-- Modifier kinds -> the Unreal FKey names that count (left or right).
local MODS = {
    CONTROL = { "LeftControl", "RightControl" }, CTRL = { "LeftControl", "RightControl" },
    SHIFT = { "LeftShift", "RightShift" }, ALT = { "LeftAlt", "RightAlt" },
}

-- Unreal key name for a config value, or nil (no key) plus a reason.
function M.unreal_name(name)
    if name == nil or name == false then return nil, "no key set" end
    local s = tostring(name):gsub("^%s+", ""):gsub("%s+$", "")
    local up = s:upper()
    if up == "" or up == "NONE" or up == "OFF" then return nil, "no key set" end
    if UE[up] then return UE[up] end
    if UNREAL[up] then return UNREAL[up] end
    return nil, "unknown key name '" .. s .. "'"
end

-- Allocation-free helpers (these run every frame).
local function index(o, k) return o[k] end
local function get(p) return p:get() end
local function valid(o)
    if o == nil then return false end
    local t = type(o)
    if t ~= "userdata" and t ~= "table" then return false end
    local ok, f = pcall(index, o, "IsValid")
    if not ok or f == nil then return false end
    local ok2, v = pcall(f, o)
    return ok2 and v == true
end
local function unwrap(p)
    if p == nil then return nil end
    local ok, g = pcall(index, p, "get")
    if ok and type(g) == "function" then
        local ok2, v = pcall(get, p)
        if ok2 then return v end
        return nil
    end
    return p
end
M._valid, M._unwrap = valid, unwrap

-- keys: list of { name = <config value>, what = <short text for the log>, on_press = fn }
function M.new(S, keys)
    local self = setmetatable({ S = S, keys = {}, stopped = false, dead = false, fails = 0, hooked = false }, M)
    for _, k in ipairs(keys or {}) do
        local ue, why = M.unreal_name(k.name)
        local mods, bad = nil, nil
        if ue and type(k.mods) == "table" and #k.mods > 0 then       -- v1.1: modifier keys (Ctrl/Shift/Alt)
            mods = {}
            for _, m in ipairs(k.mods) do
                local pair = MODS[tostring(m):upper()]
                if not pair then bad = tostring(m) break end
                mods[#mods + 1] = { { KeyName = FName(pair[1]) }, { KeyName = FName(pair[2]) } }
            end
        end
        if ue and bad then
            S:warn_once("keymod:" .. tostring(k.name), "unknown modifier '%s' for %s - no key (use CONTROL, SHIFT or ALT)", bad,
                tostring(k.what or "the hotkey"))
        elseif ue then
            local fname = FName(ue)
            local label = tostring(k.name):upper()
            if mods then label = table.concat(k.mods, "+"):upper() .. "+" .. label end
            self.keys[#self.keys + 1] = { name = label, ue = ue, what = k.what or "key",
                                          fkey = { KeyName = fname }, on_press = k.on_press, prev = nil, mods = mods }
        elseif why ~= "no key set" then
            S:warn_once("key:" .. tostring(k.name), "%s for %s - no key (use a UE4SS key name like NUM_FOUR or F11)", why,
                tostring(k.what or "the hotkey"))
        end
    end
    self.active = #self.keys > 0
    return self
end

-- true when, for every modifier kind of the key, its left or right key is held (v1.1).
local function mods_held(fn, pc, mods)
    for _, pair in ipairs(mods) do
        local ok1, d1 = pcall(fn, pc, pair[1])
        local ok2, d2 = pcall(fn, pc, pair[2])
        if not ((ok1 and d1 == true) or (ok2 and d2 == true)) then return false end
    end
    return true
end

-- Read every configured key on the given (game-thread) player controller; fire on_press on a new key-down.
function M:poll(pc)
    if self.stopped or self.dead or not self.active or self.busy then return end
    local ok, fn = pcall(index, pc, "IsInputKeyDown")
    if not ok or fn == nil then return self:_fail(fn) end
    self.busy = true                              -- v1.1: an action that re-enters the hooked function does not re-poll
    for _, k in ipairs(self.keys) do
        local okc, down = pcall(fn, pc, k.fkey)
        if not okc or type(down) ~= "boolean" then self.busy = false return self:_fail(down) end
        self.fails = 0
        if k.prev == nil then
            k.prev = down                         -- first read only arms the key
        elseif down ~= k.prev then
            k.prev = down
            if down and k.on_press and (k.mods == nil or mods_held(fn, pc, k.mods)) then
                local okp, err = pcall(k.on_press, pc)   -- v1.1: the controller that was read (Palworld ignores it)
                if not okp then self.S:warn_once("keycb:" .. k.name, "%s key action failed: %s", k.name, tostring(err)) end
            end
        end
    end
    self.busy = false
end

function M:_fail(err)
    self.fails = self.fails + 1
    if self.fails >= MAX_FAILS and not self.dead then
        self.dead = true
        self.S:log("hotkeys off: PlayerController:IsInputKeyDown failed %d times (%s) - game update?", self.fails, tostring(err))
    end
end

-- From a hook on a function of the in-game HUD (TickWorldHUDs): ctx = the HUD; HUD.PlayerOwner = your controller.
function M:on_frame(ctx)
    if self.stopped or self.dead or not self.active then return end
    local hud = unwrap(ctx)
    if not valid(hud) then return end
    local ok, pc = pcall(index, hud, "PlayerOwner")
    if not ok then return end
    pc = unwrap(pc)
    if not valid(pc) then return end
    self:poll(pc)
end

-- From a hook on a PlayerController function (ctx = the controller): used when the per-frame hook is missing.
function M:poll_ctx(ctx)
    if self.stopped or self.dead or not self.active or self.hooked then return end
    self:poll_pc(unwrap(ctx))
end

-- Same fallback with an already unwrapped player controller (e.g. from otc_safe's on_restart(fn(pc, pawn))).
function M:poll_pc(pc)
    if self.stopped or self.dead or not self.active or self.hooked then return end
    if not valid(pc) then return end
    local ok, lc = pcall(function() return pc:IsLocalController() end)
    if not (ok and lc == true) then return end      -- not a (local) player controller: nothing to read
    self:poll(pc)
end

-- v1.1 Grounded: ctx = your character's SurvivalComponent -> GetOwner() (the character) -> .Controller.
-- Returns the controller only when it is valid and local (remote players' characters tick on a host too).
function M.pc_of_component_owner(comp)
    if not valid(comp) then return nil end
    local ok, f = pcall(index, comp, "GetOwner")
    if not ok or f == nil then return nil end
    local ok2, owner = pcall(f, comp)
    if not ok2 then return nil end
    owner = unwrap(owner)
    if not valid(owner) then return nil end
    local ok3, pc = pcall(index, owner, "Controller")
    if not ok3 then return nil end
    pc = unwrap(pc)
    if not valid(pc) then return nil end
    local ok4, lc = pcall(function() return pc:IsLocalController() end)
    if not (ok4 and lc == true) then return nil end
    return pc
end

-- v1.1: per-frame hook whose object leads to the controller through pc_of(obj) (see start()).
function M:on_frame_pc(ctx, pc_of)
    if self.stopped or self.dead or not self.active or self.busy then return end
    local obj = unwrap(ctx)
    if not valid(obj) then return end
    local pc = pc_of(obj)
    if pc == nil then return end
    if self.announce and not self.announced then
        self.announced = true
        self.S:log("hotkeys live: %s fires on the game thread (%s)", self.frame_path or "per-frame hook", self:describe())
    end
    self:poll(pc)
end

-- Register the per-frame hook (only when a key is configured). Returns true when keys are read every frame.
-- opts (v1.1, optional): pc_of = fn(hooked object) -> local player controller or nil (default: HUD.PlayerOwner);
-- announce = true logs one line at the first frame; missing = log text when the hook is not found.
function M:start(path, opts)
    if not self.active then return false end
    local selfref = self
    path = path or M.FRAME_HOOK
    local fn
    if opts and opts.pc_of then
        local pc_of = opts.pc_of
        self.announce, self.frame_path = opts.announce == true, path
        fn = function(ctx) selfref:on_frame_pc(ctx, pc_of) end
    else
        fn = function(ctx) selfref:on_frame(ctx) end
    end
    local pre = self.S:safe_hook(path, fn, "hotkeys")
    self.hooked = pre ~= nil
    if not self.hooked then
        self.S:warn_once("keyframe", (opts and opts.missing) or
            "per-frame HUD function not found in this game version - hotkeys are only read at your next action")
    end
    return self.hooked
end

-- v1.1 Grounded 1: keys read every frame from BP_SurvivalPlayerCharacter_C's tick (see header).
function M:start_grounded()
    return self:start(M.GROUNDED_FRAME_HOOK, { pc_of = M.pc_of_component_owner, announce = true,
        missing = "per-frame function SurvivalComponent:GetBreathSecondsLeft not found in this game version - hotkeys are off" })
end

-- Mods that already hook the per-frame function themselves call this instead of start().
function M:set_hooked(on) self.hooked = on and true or false end

function M:stop() self.stopped = true end

-- "NUM_FOUR" for the log, or "no key".
function M:describe()
    if not self.active then return "no key" end
    local t = {}
    for _, k in ipairs(self.keys) do t[#t + 1] = k.name end
    return table.concat(t, "/")
end

return M
