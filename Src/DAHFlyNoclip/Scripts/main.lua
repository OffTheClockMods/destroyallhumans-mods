-- =======================================================================
-- Destroy All Humans! (2020): Fly and Noclip v1.0.0
-- Target: DH-Win64-Shipping (Unreal Engine 4.22, Steam build 6184983)
-- Framework: UE4SS v3.0.1 experimental (commit e3ba1016, 2026-09-29; our DAH mods are tested on it. Build f08dfdf runs the mods too but crashes when the game closes)
-- UE4SS-settings.ini: nothing required.
--
-- What it does: Numpad 7 = Fly (Crypto flies freely, walls still stop you), Numpad 8 = Noclip (fly through walls
-- and floors). The same key again = walk. While flying, hold Numpad 5 to rise and Left Ctrl to sink. Optional fly speed
-- multiplier (default 1 = the game's own fly speed). Only on foot as Crypto; in the saucer the keys do nothing and
-- say so in the log.
-- How: Crypto's own movement component (UBFGActorComponent_PlayerCharacterMovement, an Unreal
-- CharacterMovementComponent): SetMovementMode(MOVE_Flying, 0) with both parameters (UE4SS needs the second one),
-- bCheatFlying = true (stop when you let go of the keys), MaxFlySpeed x your multiplier; Noclip also switches the
-- body's collision off (Actor:SetActorEnableCollision(false)). Walk = collision on, the game's values back,
-- SetMovementMode(MOVE_Falling, 0) so Crypto drops and lands normally. Every change is read back.
-- The game may switch Crypto out of flying (jetpack, landing); the mod sets flying again on the next tick and never
-- fights a cutscene (MOVE_None = the game holds Crypto still: the mod waits). Changing body (saucer, respawn,
-- loading) ends fly/noclip and restores the old body.
-- The developers' UBFGCheatManager:FlyMode is real code in the shipping exe (not a stub), but what it does is not
-- known: it is only used with use_game_fly_cheat = true, and the mod's own way takes over if it doesn't fly you.
-- Threading: otc_dah.lua (shipped next to this file; see its header) runs an engine timer on your controller that
-- calls Actor:ForceNetUpdate every 0.05 s; this mod's work runs in hooks on that call (game thread) and in the
-- engine's key actions. Nothing runs off the game thread.
-- Nothing is saved: movement mode and collision are not part of the save.
-- =======================================================================
-- Self-checks (registered below; listed here for our test tooling sheet):
-- SC:expect("fly_on", "on foot, press NUM_SEVEN once (Fly on)")
-- SC:expect("fly_holds", "stay in Fly for 3 s")
-- SC:expect("fly_off", "press NUM_SEVEN again (walk)")
-- SC:expect("noclip_on", "on foot, press NUM_EIGHT once (Noclip on)")
-- SC:expect("noclip_off", "press NUM_EIGHT again (walk)")
-- SC:expect("fly_up", "in Fly, hold NUM_FIVE for 1 s", { optional = true })
local ModName = "DAHFlyNoclip"
local ModVersion = "1.0.0"
-- Lua garbage collector in generational mode (as in every DAH mod since 1.0.1): the 20-per-second tick leaves short-lived
-- objects that generational GC frees in small steps. Lua 5.4 only; touches no game object.
pcall(collectgarbage, "generational")
local CORE_MIN = 1.0

local function script_dir()
    local src = debug and debug.getinfo and debug.getinfo(1, "S").source or ""
    return (src:gsub("^@", "")):match("^(.*[/\\])") or ""
end
local function load_lib(name)
    local ok, m = pcall(require, name)
    if ok and type(m) == "table" then return m end
    local ok2, m2 = pcall(dofile, script_dir() .. name .. ".lua")
    if ok2 and type(m2) == "table" then return m2 end
    return nil
end
local Core = load_lib("otc_dah")
if not (type(Core) == "table" and type(Core.run) == "function" and (tonumber(Core.VERSION) or 0) >= CORE_MIN) then
    print(string.format("[%s] otc_dah.lua missing or older than %.1f; mod disabled (copy every file from the download).\n", ModName, CORE_MIN))
    return
end
local Keys = load_lib("otc_keys")

local okc, config = pcall(require, "config")
if not okc or type(config) ~= "table" then
    local why = tostring(config):match("^[^\n]*") or ""
    if okc or not why:find("not found", 1, true) then
        print(string.format("[%s] Warning: Scripts\\config.lua could not be loaded (%s); using the default settings.\n", ModName, why))
    end
    config = {}
end

-- ------------------------------------------------------------------ settings (bad values -> default + one log line)
local Notes = {}
local function cfgv(name, default)
    local v = config[name]
    if v == nil then return default end
    return v
end
local function key(name, default)
    local v = cfgv(name, default)
    if type(v) ~= "string" then Notes[#Notes + 1] = string.format("config: %s must be a key name in quotes; using \"%s\"", name, default); return default end
    return v
end
local function num(name, default, lo, hi, why)
    local v = cfgv(name, default)
    if type(v) ~= "number" or v ~= v then Notes[#Notes + 1] = string.format("config: %s must be a number; using %s", name, tostring(default)); return default end
    if v < lo or v > hi then
        local c = v < lo and lo or hi
        Notes[#Notes + 1] = string.format("config: %s = %s is outside %s..%s (%s); using %s", name, tostring(v), tostring(lo), tostring(hi), why, tostring(c))
        return c
    end
    return v
end
local function bool(name, default)
    local v = cfgv(name, default)
    if type(v) ~= "boolean" then Notes[#Notes + 1] = string.format("config: %s must be true or false; using %s", name, tostring(default)); return default end
    return v
end

local FlyKey = key("fly_key", "NUM_SEVEN")
local NoclipKey = key("noclip_key", "NUM_EIGHT")
local UpKeyName = key("up_key", "NUM_FIVE")
local DownKeyName = key("down_key", "LEFT_CONTROL")
local FlyMult = num("fly_speed", 1.0, 0.1, 100, "slower than x0.1 barely moves; faster than x100 is far beyond the world's loading speed")
local UseGameCheat = bool("use_game_fly_cheat", false)

-- Held keys (rise/sink) are read directly with IsInputKeyDown; names otc_keys doesn't know are mapped here.
local HELD = { LEFT_CONTROL = "LeftControl", LEFTCONTROL = "LeftControl", LCTRL = "LeftControl", CTRL = "LeftControl",
               CONTROL = "LeftControl", RIGHT_CONTROL = "RightControl", RIGHTCONTROL = "RightControl",
               LEFT_SHIFT = "LeftShift", LEFTSHIFT = "LeftShift", RIGHT_SHIFT = "RightShift", RIGHTSHIFT = "RightShift",
               LEFT_ALT = "LeftAlt", LEFTALT = "LeftAlt", RIGHT_ALT = "RightAlt", RIGHTALT = "RightAlt",
               SPACEBAR = "SpaceBar" }
local function held_key(name, what)
    local s = tostring(name or ""):gsub("%s+", "")
    if s == "" or s:upper() == "NONE" or s:upper() == "OFF" then return nil, "none" end
    local ue = HELD[s:upper()]
    if not ue and Keys and Keys.unreal_name then ue = Keys.unreal_name(s) end
    if not ue then Notes[#Notes + 1] = string.format("config: unknown key name '%s' for %s - that key is off", s, what); return nil, "none" end
    return { KeyName = FName(ue) }, s:upper()
end
local UpKey, UpText = held_key(UpKeyName, "up_key")
local DownKey, DownText = held_key(DownKeyName, "down_key")

print(string.format("[%s] Initializing v%s (fly %s, noclip %s, rise %s, sink %s, fly speed x%s%s).\n", ModName, ModVersion,
    FlyKey ~= "" and FlyKey or "no key", NoclipKey ~= "" and NoclipKey or "no key", UpText, DownText, tostring(FlyMult),
    UseGameCheat and ", dev FlyMode cheat first" or ""))

-- ------------------------------------------------------------------ game facts (UE4SS dump 2026-09-30, DAH 1 build 6184983)
local MOVE_NONE, MOVE_WALKING, MOVE_FALLING, MOVE_FLYING = 0, 1, 3, 5      -- Engine EMovementMode (Engine_enums.hpp)
local MODE_NAMES = { [0] = "None", "Walking", "NavWalking", "Falling", "Swimming", "Flying", "Custom" }
local LABEL = { fly = "Fly", noclip = "Noclip" }
local FIGHT_WINDOW_S, FIGHT_COUNT = 5.0, 20         -- re-applies in this window -> one hint line (never turns itself off)

local E                                             -- otc_dah engine handle (set below)
local S, SC
local unwrap, is_valid = nil, nil

-- state (declared before every function that reads it)
local Mode = "walk"           -- "walk" / "fly" / "noclip"
local ModPawn = nil           -- the body we changed (only used after an IsValid check)
local PawnAddr = nil
local Orig = nil              -- the game's own values of that body: { fly_speed, cheat_flying }
local PcAddr = nil            -- your in-game controller (address only)
local Pending = {}            -- self-check read-backs: { at, id, mode, kind }
local Reapplied = {}          -- os.clock() of each "set flying again"
local FightLogged = false
local HeldStill = false
local Vert = nil              -- nil / 1 (rising) / -1 (sinking)
local VertStart = nil         -- { z, t } when rising started
local IsQuitting = false

local function now() return os.clock() end
local function mode_name(m) return MODE_NAMES[m] or tostring(m) end
local function addr(o) local a = nil; pcall(function() a = o:GetAddress() end) return a end
local function fullname(o) local s = ""; pcall(function() s = tostring(o:GetFullName()) end) return s or "" end

local function is_game_pc(pc)
    if not is_valid(pc) then return false end
    local okL, l = pcall(function() return pc:IsLocalPlayerController() end)
    if not (okL and l == true) then return false end
    local n = fullname(pc)
    return n:find("BFGPlayerController", 1, true) ~= nil and n:find("_Menus", 1, true) == nil
end

local function pawn_of(pc)
    local p = nil
    pcall(function() p = unwrap(pc.Pawn) end)
    if is_valid(p) then return p end
    return nil
end

-- Crypto on foot: only his body has a jetpack component (the saucer has none); not while entering/leaving the saucer.
local function on_foot(pc, pawn)
    if not pawn then return false, "no body (menu or loading)" end
    local jet = nil
    pcall(function() jet = unwrap(pawn.m_pJetpackPilotComponent) end)
    if not is_valid(jet) then return false, "you are in the saucer (or not playing as Crypto)" end
    local okU, u = pcall(function() return pawn.m_bIsCurrentlyEnteringOrLeavingUFO end)
    if okU and u == true then return false, "you are entering or leaving the saucer" end
    local okG, g = pcall(function() return pc:IsGroundMode() end)
    if okG and g == false then return false, "the game is in saucer mode" end
    return true
end

local function cmc_of(pawn)
    local m = nil
    pcall(function() m = unwrap(pawn.CharacterMovement) end)
    if is_valid(m) then return m end
    return nil
end

local function movement_mode(m)
    local ok, v = pcall(function() return m.MovementMode end)
    if ok and type(v) == "number" then return v end
    return nil
end

-- SetMovementMode(mode, 0) - BOTH parameters (one argument fails silently on UE4SS 3.0.1, Grounded 1.0.3 lesson);
-- direct write of MovementMode only if the call doesn't stick. Returns true/false, how.
local function set_mode_verified(m, want)
    local okCall, err = pcall(function() m:SetMovementMode(want, 0) end)
    local cur = movement_mode(m)
    if okCall and cur == want then return true, "SetMovementMode" end
    local okW = pcall(function() m.MovementMode = want end)
    cur = movement_mode(m)
    if okW and cur == want then
        S:warn_once("smm" .. want, "SetMovementMode(%d, 0) %s - used a direct MovementMode write", want, okCall and "did not stick" or ("failed: " .. tostring(err)))
        return true, "direct write"
    end
    return false, string.format("MovementMode is %s (SetMovementMode %s)", mode_name(cur), okCall and "had no effect" or tostring(err))
end

local function set_cheat_flying(m, on)
    pcall(function() m.bCheatFlying = on end)
end

local function collision(pawn)
    local ok, v = pcall(function() return pawn:GetActorEnableCollision() end)
    if ok and type(v) == "boolean" then return v end
    return nil
end
local function set_collision(pawn, on)
    pcall(function() pawn:SetActorEnableCollision(on) end)
    return collision(pawn) == on
end

local function height(pawn)
    local z = nil
    pcall(function() z = pawn:K2_GetActorLocation().Z end)
    if type(z) == "number" then return z end
    return nil
end

local function key_down(pc, fkey)
    if not fkey then return false end
    local ok, d = pcall(function() return pc:IsInputKeyDown(fkey) end)
    return ok and d == true
end

-- Vertical speed while a rise/sink key is held: the body's velocity Z (X/Y kept). bCheatFlying is off while
-- the key is held (it would zero the velocity whenever you don't also walk) and on again when you let go.
local function set_vz(m, vz)
    local v = nil
    pcall(function() v = m.Velocity end)
    local x, y = 0, 0
    pcall(function() x, y = v.X, v.Y end)
    local ok = pcall(function() m.Velocity = { X = x or 0, Y = y or 0, Z = vz } end)
    if not ok then ok = pcall(function() m.Velocity.Z = vz end) end
    return ok
end

local function schedule(id, delay, kind)
    Pending[#Pending + 1] = { at = now() + delay, id = id, mode = Mode, kind = kind }
end

-- ------------------------------------------------------------------ back to walking
local function restore_body(pawn, why_mode)
    local m = cmc_of(pawn)
    set_collision(pawn, true)
    if m then
        set_cheat_flying(m, Orig and Orig.cheat_flying or false)
        if Orig and type(Orig.fly_speed) == "number" then pcall(function() m.MaxFlySpeed = Orig.fly_speed end) end
        if movement_mode(m) == MOVE_FLYING then set_mode_verified(m, MOVE_FALLING) end
    end
    return m
end

local function walk(why, by_key)
    local was = Mode
    if was == "walk" then return end
    local pawn = (ModPawn and is_valid(ModPawn)) and ModPawn or nil
    local detail = "the body is gone (nothing to restore)"
    if pawn then
        local m = restore_body(pawn, was)
        detail = string.format("MovementMode %s, collision %s", m and mode_name(movement_mode(m)) or "?", collision(pawn) == false and "OFF (could not switch it on!)" or "on")
    end
    Mode, ModPawn, PawnAddr, Orig = "walk", nil, nil, nil
    Vert, VertStart, HeldStill, FightLogged, Reapplied = nil, nil, false, false, {}
    S:log("%s OFF (%s): walking again (%s)", LABEL[was], why, detail)
    if pawn and by_key then schedule(was .. "_off", 1.0, "off") end       -- read-back only on the same body
end

-- ------------------------------------------------------------------ fly / noclip on
local function enter(pc, cm, want, why)
    local pawn = pawn_of(pc)
    local okFoot, whyNot = on_foot(pc, pawn)
    if not okFoot then
        S:log("%s: only on foot as Crypto - %s. Nothing changed.", LABEL[want], whyNot)
        if SC:want(want .. "_on") then SC:wait(want .. "_on", "not on foot (%s)", whyNot) end
        return
    end
    local m = cmc_of(pawn)
    if not m then S:log("%s: Crypto's movement component was not found (game update?). Nothing changed.", LABEL[want]) return end
    if Mode == "walk" then
        local fs, cf = nil, nil
        pcall(function() fs = m.MaxFlySpeed end)
        pcall(function() cf = m.bCheatFlying end)
        Orig = { fly_speed = type(fs) == "number" and fs or nil, cheat_flying = cf == true }
    end
    local before = movement_mode(m)
    local ok, via = false, nil
    if UseGameCheat and Mode == "walk" and cm then
        local okF, errF = pcall(function() cm:FlyMode() end)
        if okF and movement_mode(m) == MOVE_FLYING then ok, via = true, "the game's own FlyMode cheat"
        else S:log("%s: the game's FlyMode cheat %s - using the mod's own way", LABEL[want], okF and ("left Crypto in " .. mode_name(movement_mode(m))) or ("failed: " .. tostring(errF))) end
    end
    if not ok then ok, via = set_mode_verified(m, MOVE_FLYING) end
    if not ok then
        set_collision(pawn, true)
        S:log("%s failed: Crypto could not be switched to flying (%s). Nothing changed.", LABEL[want], tostring(via))
        if SC:want(want .. "_on") then SC:fail(want .. "_on", "could not switch to flying: %s", tostring(via)) end
        if Mode == "walk" then Orig = nil end
        return
    end
    set_cheat_flying(m, true)
    local speed = Orig and Orig.fly_speed
    if speed and FlyMult ~= 1 then pcall(function() m.MaxFlySpeed = speed * FlyMult end) end
    local colOk = set_collision(pawn, want ~= "noclip")
    if want == "noclip" and not colOk then
        S:log("Noclip: flying works, but collision could not be switched off - you are in Fly mode instead")
        if SC:want("noclip_on") then SC:fail("noclip_on", "SetActorEnableCollision(false) did not stick (GetActorEnableCollision=%s)", tostring(collision(pawn))) end
        want = "fly"
    end
    local was = Mode
    Mode, ModPawn, PawnAddr = want, pawn, addr(pawn)
    Vert, VertStart, HeldStill, FightLogged, Reapplied = nil, nil, false, false, {}
    local cur = nil
    pcall(function() cur = m.MaxFlySpeed end)
    S:log("%s ON (%s): flying via %s (was %s), fly speed %s%s, collision %s. Rise %s, sink %s.", LABEL[want], why, via,
        was == "walk" and mode_name(before) or LABEL[was],
        type(cur) == "number" and string.format("%.0f", cur) or "?",
        (speed and FlyMult ~= 1) and string.format(" (game %.0f x%s)", speed, tostring(FlyMult)) or " (the game's)",
        want == "noclip" and "OFF" or "on", UpText, DownText)
    schedule(want .. "_on", 1.0, "on")
    if want == "fly" then schedule("fly_holds", 3.0, "holds") end
    if speed and FlyMult ~= 1 then schedule("fly_speed", 0.5, "speed") end
end

local function toggle(pc, cm, which)
    if Mode == which then walk("key " .. (which == "fly" and FlyKey or NoclipKey), true) return end
    enter(pc, cm, which, "key " .. (which == "fly" and FlyKey or NoclipKey))
end

-- ------------------------------------------------------------------ self-check read-backs (log only, never change anything)
local function run_check(c, pc)
    local pawn = pawn_of(pc)
    if c.kind == "on" or c.kind == "holds" or c.kind == "speed" then
        if Mode ~= c.mode or not pawn or addr(pawn) ~= PawnAddr then return end      -- state changed meanwhile: no verdict
        local m = cmc_of(pawn)
        local mm = m and movement_mode(m)
        local col = collision(pawn)
        if c.kind == "on" then
            local wantCol = c.mode ~= "noclip"
            if SC:want(c.id) then SC:check(c.id, mm == MOVE_FLYING and col == wantCol, "MovementMode=%s collision=%s (wanted Flying, collision %s)", mode_name(mm), tostring(col), wantCol and "on" or "off") end
        elseif c.kind == "holds" then
            local n = #Reapplied
            if SC:want(c.id) then SC:check(c.id, mm == MOVE_FLYING and n < FIGHT_COUNT, "still %s 3 s later (the game switched it back %d time%s)", mode_name(mm), n, n == 1 and "" or "s") end
        else
            local v = nil
            pcall(function() v = m.MaxFlySpeed end)
            local want = Orig and Orig.fly_speed and Orig.fly_speed * FlyMult
            if SC:want(c.id) then SC:check(c.id, type(v) == "number" and want and math.abs(v - want) < 0.5, "MaxFlySpeed %s (wanted %s)", tostring(v), tostring(want)) end
        end
    elseif c.kind == "off" then
        if Mode ~= "walk" then return end
        if not pawn then return end
        local m = cmc_of(pawn)
        local mm = m and movement_mode(m)
        local col = collision(pawn)
        if SC:want(c.id) then SC:check(c.id, mm ~= nil and mm ~= MOVE_FLYING and col == true, "MovementMode=%s collision=%s (wanted not Flying, collision on)", mode_name(mm), tostring(col)) end
    end
end

-- ------------------------------------------------------------------ the tick (engine timer -> ForceNetUpdate, game thread)
local function maintain(pc, t)
    local pawn = pawn_of(pc)
    local okFoot = pawn and on_foot(pc, pawn)
    if not pawn or addr(pawn) ~= PawnAddr or not okFoot then
        walk("you left Crypto's body: saucer, respawn or loading")
        return
    end
    local m = cmc_of(pawn)
    if not m then walk("Crypto's movement component is gone") return end
    local mm = movement_mode(m)
    if mm == nil then S:warn_once("mmread", "MovementMode can't be read (game update?)") return end
    if mm ~= MOVE_FLYING then
        if mm == MOVE_NONE then                     -- the game holds Crypto still (cutscene, grab, interaction): wait
            if not HeldStill then HeldStill = true; S:log("%s paused: the game holds Crypto still (cutscene or interaction); it continues afterwards", LABEL[Mode]) end
            return
        end
        local ok = set_mode_verified(m, MOVE_FLYING)
        set_cheat_flying(m, Vert == nil)
        Reapplied[#Reapplied + 1] = t
        while Reapplied[1] and Reapplied[1] < t - FIGHT_WINDOW_S do table.remove(Reapplied, 1) end
        if HeldStill then HeldStill = false; S:log("%s continues (the game let go of Crypto)", LABEL[Mode]) end
        if not ok then S:warn_once("reflyfail", "%s: the game switched Crypto to %s and flying could not be set again", LABEL[Mode], mode_name(mm)) end
        if #Reapplied >= FIGHT_COUNT and not FightLogged then
            FightLogged = true
            S:log("%s: the game keeps switching Crypto out of flying (%d times in %.0f s, last to %s). If it happens while you hold %s, set up_key to another key in config.lua",
                LABEL[Mode], #Reapplied, FIGHT_WINDOW_S, mode_name(mm), UpText)
        end
    else
        HeldStill = false
    end
    if Mode == "noclip" and collision(pawn) == true then        -- the game switched collision back on (e.g. after an interaction)
        set_collision(pawn, false)
        S:warn_once("colback", "Noclip: the game switched collision back on; switched it off again")
    end
    -- rise / sink while a key is held
    local dir = (key_down(pc, UpKey) and 1 or 0) - (key_down(pc, DownKey) and 1 or 0)
    if dir ~= 0 then
        local sp = nil
        pcall(function() sp = m.MaxFlySpeed end)
        if type(sp) ~= "number" or sp <= 0 then sp = 600 end
        if Vert ~= dir then
            Vert = dir
            set_cheat_flying(m, false)
            VertStart = (dir == 1) and { z = height(pawn), t = t } or nil
        end
        if not set_vz(m, dir * sp) then S:warn_once("vz", "rise/sink: the body's velocity can't be written (game update?)") end
        if VertStart and VertStart.z and t - VertStart.t >= 0.5 and SC:want("fly_up") then
            local z = height(pawn)
            if z then SC:check("fly_up", z - VertStart.z > 20, "height %+.0f cm after %.1f s holding %s", z - VertStart.z, t - VertStart.t, UpText) end
        end
    elseif Vert then
        Vert, VertStart = nil, nil
        set_vz(m, 0)
        set_cheat_flying(m, true)
    end
end

local function tick(pc)
    if IsQuitting then return end
    local t = now()
    if Mode ~= "walk" then maintain(pc, t) end
    if #Pending > 0 then
        local keep = {}
        for _, c in ipairs(Pending) do
            if t >= c.at then run_check(c, pc) else keep[#keep + 1] = c end
        end
        Pending = keep
    end
end

-- ------------------------------------------------------------------ engine + hooks (registration only at load)
E = Core.run({
    mod = ModName, version = ModVersion,
    actions = {
        { id = "fly", label = "Fly", key = FlyKey, run = function(_, pc, cm) toggle(pc, cm, "fly") end },
        { id = "noclip", label = "Noclip", key = NoclipKey, run = function(_, pc, cm) toggle(pc, cm, "noclip") end },
    },
})
if not E then return end
S, SC = E.S, E.SC
local Safe = load_lib("otc_safe")
unwrap = (Safe and Safe.unwrap) or function(v) return v end
is_valid = (Safe and Safe.is_valid) or function(o) local ok, v = pcall(function() return o:IsValid() end) return ok and v == true end
for _, n in ipairs(Notes) do S:log("WARN %s", n) end

local function keytext(k) local kk, mods = Core.parse_key(k); if not kk then return nil end return (mods and (table.concat(mods, "+") .. "+") or "") .. kk:upper() end
local FlyKT, NoclipKT = keytext(FlyKey), keytext(NoclipKey)
if FlyKT then
    SC:expect("fly_on", "on foot, press " .. FlyKT .. " once (Fly on)")
    SC:expect("fly_holds", "stay in Fly for 3 s")
    SC:expect("fly_off", "press " .. FlyKT .. " again (walk)")
    if UpKey then SC:expect("fly_up", "in Fly, hold " .. UpText .. " for 1 s", { optional = true }) end
    if FlyMult ~= 1 then SC:expect("fly_speed", "press " .. FlyKT .. " on foot (fly speed x" .. tostring(FlyMult) .. ")", { optional = true }) end
end
if NoclipKT then
    SC:expect("noclip_on", "on foot, press " .. NoclipKT .. " once (Noclip on)")
    SC:expect("noclip_off", "press " .. NoclipKT .. " again (walk)")
end

S:safe_hook(Core.RESTART, function() end, "fly restart", function(ctx)
    if IsQuitting then return end
    local pc = unwrap(ctx)
    if not is_game_pc(pc) then return end
    PcAddr = addr(pc)
end)
S:safe_hook(Core.TICK_HOOK, function(ctx)
    if IsQuitting or PcAddr == nil then return end
    local obj = unwrap(ctx)
    if addr(obj) ~= PcAddr then return end
    if not is_game_pc(obj) then return end
    tick(obj)
end, "fly tick")
pcall(function() RegisterHook("/Script/Engine.KismetSystemLibrary:QuitGame", function() IsQuitting = true end) end)
