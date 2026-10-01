-- Scenarios for Destroy All Humans Fly and Noclip 1.0.0 (otc_dah 1.0). Fake world: Src\_shared\dah_fake.lua, extended here
-- with what this mod touches (names from the UE4SS dump 2026-09-30): Crypto's CharacterMovement
-- (UBFGActorComponent_PlayerCharacterMovement: MovementMode, SetMovementMode(mode, custom), bCheatFlying, MaxFlySpeed,
-- Velocity), Actor:SetActorEnableCollision/GetActorEnableCollision/K2_GetActorLocation, ABFGPlayerController:IsGroundMode,
-- m_bIsCurrentlyEnteringOrLeavingUFO and UBFGCheatManager:FlyMode.
local here = (debug.getinfo(1, "S").source:gsub("^@", "")):match("^(.*[/\\])") or "./"
local F = dofile(here .. "../../_shared/dah_fake.lua")
local W, X

-- opts: smm_one_arg_only (SetMovementMode ignores everything: only a direct write works), smm_broken (nothing sticks),
--       no_collision_off (SetActorEnableCollision(false) is ignored), fly_cheat ("works" / "nothing"), max_fly (game value)
local function body(H, name, o)
    local st = { z = 1000.0, col = true }
    local m
    local fields = {
        MovementMode = 1, MaxFlySpeed = o.max_fly or 600, bCheatFlying = false, Velocity = { X = 0, Y = 0, Z = 0 },
        SetMovementMode = function(self, mode, custom)
            X.smm_calls = X.smm_calls + 1
            if custom == nil then return end                              -- UE4SS 3.0.1: one argument = silently nothing
            if o.smm_one_arg_only or o.smm_broken then return end
            H.poke(self, "MovementMode", mode)
        end,
    }
    m = H.obj(name .. "_CharMoveComp", fields, { class = H.class("BFGActorComponent_PlayerCharacterMovement", nil, "/Script/BFGCore.BFGActorComponent_PlayerCharacterMovement") })
    if o.smm_broken then
        H.on_write = function(p, k, v) if p == m and k == "MovementMode" then H.poke(m, "MovementMode", 1) end end
    end
    return m, st
end

local function extend(H, o)
    X = { smm_calls = 0, o = o }
    local function fit(pawn)
        local m, st = body(H, "Crypto" .. H.world_gen, o)
        H.poke(pawn, "CharacterMovement", m)
        H.poke(pawn, "m_bIsCurrentlyEnteringOrLeavingUFO", false)
        H.poke(pawn, "SetActorEnableCollision", function(_, on) if on == false and o.no_collision_off then return end st.col = on end)
        H.poke(pawn, "GetActorEnableCollision", function() return st.col end)
        H.poke(pawn, "K2_GetActorLocation", function() return { X = 0, Y = 0, Z = st.z } end)
        X.m, X.st, X.pawn = m, st, pawn
    end
    if not o.ufo then fit(W.pawn) end
    X.fit = fit
    H.poke(W.pc, "IsGroundMode", function() return not o.ufo end)
    local orig = H.on_construct
    H.on_construct = function(cls, outer)
        local cm = orig(cls, outer)
        H.poke(cm, "FlyMode", function()
            X.flymode = (X.flymode or 0) + 1
            if o.fly_cheat == "works" and X.m then H.poke(X.m, "MovementMode", 5) end
        end)
        return cm
    end
    -- the game: a flying body moves by its velocity (Z only is enough here)
    H.on_frame(function()
        if X.m and H.is_alive(X.m) and H.peek(X.m, "MovementMode") == 5 then
            X.st.z = X.st.z + (H.peek(X.m, "Velocity").Z or 0) * H.config.tick_ms / 1000
        end
    end)
end

local function setup(cfg, opts)
    return function(H)
        package.loaded["config"] = cfg
        W = F.build(H, opts)
        extend(H, opts or {})
    end
end
local function press(H, key, ctrl) W.press(H, key, ctrl) end

local function new_world(H, opts)
    H.change_world(function(H2) W.make_world(H2) end)
    extend(H, opts or {})
end

-- to the saucer (new body, same controller), like the game's SwitchToUFOMode
local function to_ufo(H)
    local ufo = H.obj("BP_PlayerUFO_C_x", {}, { class = "BP_PlayerUFO_C" })
    H.poke(W.pc, "Pawn", ufo)
    H.poke(W.pc, "IsGroundMode", function() return false end)
    W.spawn(H)
end

local OTC_SPEC = {
    scenarios = {
        { name = "Fly: Numpad 7 on (flying, collision on, read back), stays on 3 s, Numpad 7 again = walking",
          setup = setup(nil),
          run = function(H)
            W.spawn(H); H.run(3.0)
            press(H, "NumPadSeven")
            H.eq(H.peek(X.m, "MovementMode"), 5, "flying")
            H.eq(H.peek(X.m, "bCheatFlying"), true, "bCheatFlying on (stops when you let go)")
            H.eq(X.st.col, true, "collision on")
            H.eq(H.log_count("Fly ON (key NUM_SEVEN): flying via SetMovementMode (was Walking), fly speed 600 (the game's), collision on", true), 1, "ON line")
            H.run(1.0)
            H.eq(H.log_count("[SELFCHECK] DAHFlyNoclip fly_on PASS", true), 1, "fly_on PASS")
            H.run(2.2)
            H.eq(H.log_count("[SELFCHECK] DAHFlyNoclip fly_holds PASS still Flying 3 s later (the game switched it back 0 times)", true), 1, "fly_holds PASS")
            press(H, "NumPadSeven")
            H.eq(H.peek(X.m, "MovementMode"), 3, "falling (lands normally)")
            H.eq(H.peek(X.m, "bCheatFlying"), false, "bCheatFlying back to the game's value")
            H.eq(H.log_count("Fly OFF (key NUM_SEVEN): walking again (MovementMode Falling, collision on)", true), 1, "OFF line")
            H.run(1.2)
            H.eq(H.log_count("[SELFCHECK] DAHFlyNoclip fly_off PASS", true), 1, "fly_off PASS")
            H.eq(H.calls.RegisterKeyBind, 0, "no RegisterKeyBind")
            H.eq(H.log_count("WARN", true), 0, "no warnings")
          end },
        { name = "Noclip: Numpad 8 on (flying + collision OFF), Numpad 8 again = collision on, walking",
          setup = setup(nil),
          run = function(H)
            W.spawn(H); H.run(3.0)
            press(H, "NumPadEight")
            H.eq(H.peek(X.m, "MovementMode"), 5, "flying"); H.eq(X.st.col, false, "collision off")
            H.run(1.2)
            H.eq(H.log_count("[SELFCHECK] DAHFlyNoclip noclip_on PASS MovementMode=Flying collision=false", true), 1, "noclip_on PASS")
            press(H, "NumPadEight")
            H.eq(X.st.col, true, "collision on again"); H.eq(H.peek(X.m, "MovementMode"), 3, "falling")
            H.run(1.2)
            H.eq(H.log_count("[SELFCHECK] DAHFlyNoclip noclip_off PASS", true), 1, "noclip_off PASS")
          end },
        { name = "Fly -> Noclip -> Fly switches directly (collision follows), then off",
          setup = setup(nil),
          run = function(H)
            W.spawn(H); H.run(3.0)
            press(H, "NumPadSeven"); press(H, "NumPadEight")
            H.eq(X.st.col, false, "noclip: collision off"); H.eq(H.peek(X.m, "MovementMode"), 5, "still flying")
            H.eq(H.log_count("Noclip ON (key NUM_EIGHT): flying via SetMovementMode (was Fly)", true), 1, "switch line")
            press(H, "NumPadSeven")
            H.eq(X.st.col, true, "fly: collision on"); H.eq(H.peek(X.m, "MovementMode"), 5, "flying")
            press(H, "NumPadSeven")
            H.eq(H.peek(X.m, "MovementMode"), 3, "walking again"); H.eq(X.st.col, true, "collision on")
            H.run(1.5)
            H.eq(H.log_count("[SELFCHECK] DAHFlyNoclip fly_off PASS", true), 1, "fly_off PASS")
            H.eq(H.log_count("FAIL", true), 0, "no FAIL")
          end },
        { name = "in the saucer: refused with a log line, nothing changed",
          setup = setup(nil, { ufo = true }),
          run = function(H)
            W.spawn(H); H.run(3.0)
            press(H, "NumPadSeven"); press(H, "NumPadEight")
            H.eq(H.log_count("Fly: only on foot as Crypto - you are in the saucer (or not playing as Crypto). Nothing changed.", true), 1, "fly refused")
            H.eq(H.log_count("Noclip: only on foot as Crypto", true), 1, "noclip refused")
            H.eq(X.smm_calls, 0, "no movement change")
          end },
        { name = "entering/leaving the saucer right now: refused",
          setup = setup(nil),
          run = function(H)
            W.spawn(H); H.run(3.0)
            H.poke(W.pawn, "m_bIsCurrentlyEnteringOrLeavingUFO", true)
            press(H, "NumPadSeven")
            H.eq(H.log_count("Fly: only on foot as Crypto - you are entering or leaving the saucer", true), 1, "refused")
            H.eq(H.peek(X.m, "MovementMode"), 1, "still walking")
          end },
        { name = "rise with Numpad 5 (velocity up, height grows, fly_up PASS), let go = stop; sink with Left Ctrl",
          setup = setup(nil),
          run = function(H)
            W.spawn(H); H.run(3.0)
            press(H, "NumPadSeven")
            local z0 = X.st.z
            H.key_down("NumPadFive", true); H.run(1.0)
            H.eq(H.peek(X.m, "Velocity").Z, 600, "rising at the fly speed")
            H.eq(H.peek(X.m, "bCheatFlying"), false, "bCheatFlying off while a key is held")
            H.check(X.st.z - z0 > 300, "height grew while holding Numpad 5")
            H.eq(H.log_count("[SELFCHECK] DAHFlyNoclip fly_up PASS", true), 1, "fly_up PASS")
            H.key_down("NumPadFive", false); H.run(0.2)
            H.eq(H.peek(X.m, "Velocity").Z, 0, "stops when you let go")
            H.eq(H.peek(X.m, "bCheatFlying"), true, "bCheatFlying back on")
            H.key_down("LeftControl", true); H.run(0.5)
            H.eq(H.peek(X.m, "Velocity").Z, -600, "sinking")
            H.key_down("LeftControl", false); H.run(0.2)
            H.eq(H.peek(X.m, "Velocity").Z, 0, "stopped")
          end },
        { name = "rise/sink keys do nothing while walking",
          setup = setup(nil),
          run = function(H)
            W.spawn(H); H.run(3.0)
            H.key_down("NumPadFive", true); H.run(1.0); H.key_down("NumPadFive", false)
            H.eq(H.peek(X.m, "Velocity").Z, 0, "velocity untouched"); H.eq(X.smm_calls, 0, "no movement change")
          end },
        { name = "SetMovementMode doesn't stick: direct MovementMode write + one WARN line",
          setup = setup(nil, { smm_one_arg_only = true }),
          run = function(H)
            W.spawn(H); H.run(3.0)
            press(H, "NumPadSeven")
            H.eq(H.peek(X.m, "MovementMode"), 5, "flying via direct write")
            H.eq(H.log_count("SetMovementMode(5, 0) did not stick - used a direct MovementMode write", true), 1, "WARN once")
            H.eq(H.log_count("flying via direct write", true), 1, "ON line says how")
          end },
        { name = "flying can't be set at all: failed line, nothing left changed, fly_on FAIL",
          setup = setup(nil, { smm_broken = true }),
          run = function(H)
            W.spawn(H); H.run(3.0)
            press(H, "NumPadEight")
            H.eq(H.peek(X.m, "MovementMode"), 1, "walking"); H.eq(X.st.col, true, "collision still on")
            H.eq(H.log_count("Noclip failed: Crypto could not be switched to flying", true), 1, "failed line")
            H.eq(H.log_count("[SELFCHECK] DAHFlyNoclip noclip_on FAIL", true), 1, "FAIL")
          end },
        { name = "collision can't be switched off: Noclip falls back to Fly, noclip_on FAIL",
          setup = setup(nil, { no_collision_off = true }),
          run = function(H)
            W.spawn(H); H.run(3.0)
            press(H, "NumPadEight")
            H.eq(H.peek(X.m, "MovementMode"), 5, "flying")
            H.eq(H.log_count("you are in Fly mode instead", true), 1, "says so")
            H.eq(H.log_count("[SELFCHECK] DAHFlyNoclip noclip_on FAIL", true), 1, "FAIL")
            press(H, "NumPadSeven")
            H.eq(H.peek(X.m, "MovementMode"), 3, "Numpad 7 = off (it was in Fly)")
          end },
        { name = "the game switches Crypto out of flying (jetpack): set again on the next tick",
          setup = setup(nil),
          run = function(H)
            W.spawn(H); H.run(3.0)
            press(H, "NumPadSeven")
            H.poke(X.m, "MovementMode", 3); H.run(0.1)
            H.eq(H.peek(X.m, "MovementMode"), 5, "flying again")
            H.run(3.5)
            H.eq(H.log_count("[SELFCHECK] DAHFlyNoclip fly_holds PASS still Flying 3 s later (the game switched it back 1 time)", true), 1, "holds PASS, counted")
            H.eq(H.log_count("keeps switching", true), 0, "no fight hint for one switch")
          end },
        { name = "the game fights every tick: one hint line, never turns itself off, fly_holds FAIL",
          setup = setup(nil),
          run = function(H)
            W.spawn(H); H.run(3.0)
            press(H, "NumPadSeven")
            H.on_frame(function() if X.m and H.is_alive(X.m) and H.peek(X.m, "MovementMode") == 5 then H.poke(X.m, "MovementMode", 3) end end)
            H.run(6.0)
            H.eq(H.log_count("Fly: the game keeps switching Crypto out of flying", true), 1, "hint once")
            H.eq(H.log_count("[SELFCHECK] DAHFlyNoclip fly_holds FAIL", true), 1, "holds FAIL")
            H.eq(H.log_count("Fly OFF", true), 0, "not turned off by itself")
          end },
        { name = "cutscene holds Crypto still (MOVE_None): the mod waits, then continues",
          setup = setup(nil),
          run = function(H)
            W.spawn(H); H.run(3.0)
            press(H, "NumPadEight")
            H.poke(X.m, "MovementMode", 0); H.run(1.0)
            H.eq(H.peek(X.m, "MovementMode"), 0, "not forced during the cutscene")
            H.eq(H.log_count("Noclip paused: the game holds Crypto still", true), 1, "paused once")
            H.poke(X.m, "MovementMode", 1); H.run(0.2)
            H.eq(H.peek(X.m, "MovementMode"), 5, "flying again afterwards")
            H.eq(H.log_count("Noclip continues", true), 1, "continues line")
          end },
        { name = "into the saucer while in Noclip: old body restored (collision on, game values), no FAIL",
          setup = setup({ fly_speed = 2 }),
          run = function(H)
            W.spawn(H); H.run(3.0)
            press(H, "NumPadEight")
            H.eq(H.peek(X.m, "MaxFlySpeed"), 1200, "x2 fly speed")
            local m, st = X.m, X.st
            to_ufo(H); H.run(0.3)
            H.eq(st.col, true, "Crypto's collision back on")
            H.eq(H.peek(m, "MaxFlySpeed"), 600, "game fly speed back")
            H.eq(H.peek(m, "bCheatFlying"), false, "bCheatFlying back")
            H.eq(H.peek(m, "MovementMode"), 3, "not left flying")
            H.eq(H.log_count("Noclip OFF (you left Crypto's body: saucer, respawn or loading)", true), 1, "OFF line")
            H.run(2.0)
            H.eq(H.log_count("noclip_off FAIL", true), 0, "no read-back on the saucer")
            press(H, "NumPadEight")
            H.eq(H.log_count("Noclip: only on foot as Crypto", true), 1, "refused in the saucer")
          end },
        { name = "level change / respawn while flying: off, new body untouched, works again on the new body",
          setup = setup(nil),
          run = function(H)
            W.spawn(H); H.run(3.0)
            press(H, "NumPadSeven")
            new_world(H, {}); W.spawn(H); H.run(3.0)
            H.eq(H.log_count("Fly OFF (you left Crypto's body", true), 1, "off on the body change")
            H.eq(H.peek(X.m, "MovementMode"), 1, "new body walking")
            press(H, "NumPadSeven")
            H.eq(H.peek(X.m, "MovementMode"), 5, "flies on the new body")
          end },
        { name = "fly_speed x3: MaxFlySpeed 1800 + self-check, restored on walk",
          setup = setup({ fly_speed = 3 }),
          run = function(H)
            W.spawn(H); H.run(3.0)
            press(H, "NumPadSeven")
            H.eq(H.peek(X.m, "MaxFlySpeed"), 1800, "x3")
            H.eq(H.log_count("fly speed 1800 (game 600 x3)", true), 1, "ON line names it")
            H.run(1.0)
            H.eq(H.log_count("[SELFCHECK] DAHFlyNoclip fly_speed PASS MaxFlySpeed 1800", true), 1, "PASS")
            press(H, "NumPadSeven")
            H.eq(H.peek(X.m, "MaxFlySpeed"), 600, "game value back")
          end },
        { name = "bad settings: fly_speed 500 -> 100 with one line; unknown up key -> off with one line",
          setup = setup({ fly_speed = 500, up_key = "BANANA" }),
          run = function(H)
            W.spawn(H); H.run(3.0)
            H.eq(H.log_count("config: fly_speed = 500 is outside 0.1..100", true), 1, "clamp line")
            H.eq(H.log_count("config: unknown key name 'BANANA' for up_key - that key is off", true), 1, "key line")
            press(H, "NumPadSeven")
            H.eq(H.peek(X.m, "MaxFlySpeed"), 60000, "x100")
          end },
        { name = "custom keys: CTRL+F6 fly, NUM_FIVE rise",
          setup = setup({ fly_key = "CTRL+F6", up_key = "NUM_FIVE" }),
          run = function(H)
            W.spawn(H); H.run(3.0)
            press(H, "NumPadSeven"); H.eq(H.peek(X.m, "MovementMode"), 1, "Numpad 7 is not the fly key now")
            press(H, "F6"); H.eq(H.peek(X.m, "MovementMode"), 1, "plain F6 does nothing")
            press(H, "F6", true); H.eq(H.peek(X.m, "MovementMode"), 5, "Ctrl+F6 flies")
            H.key_down("NumPadFive", true); H.run(0.5)
            H.eq(H.peek(X.m, "Velocity").Z, 600, "Numpad 5 rises"); H.key_down("NumPadFive", false)
          end },
        { name = "use_game_fly_cheat: the dev FlyMode cheat flies you -> used",
          setup = setup({ use_game_fly_cheat = true }, { fly_cheat = "works" }),
          run = function(H)
            W.spawn(H); H.run(3.0)
            press(H, "NumPadSeven")
            H.eq(X.flymode, 1, "FlyMode called once"); H.eq(H.peek(X.m, "MovementMode"), 5, "flying")
            H.eq(H.log_count("flying via the game's own FlyMode cheat", true), 1, "says so")
          end },
        { name = "use_game_fly_cheat: the dev cheat does nothing -> the mod's own way",
          setup = setup({ use_game_fly_cheat = true }, { fly_cheat = "nothing" }),
          run = function(H)
            W.spawn(H); H.run(3.0)
            press(H, "NumPadSeven")
            H.eq(H.peek(X.m, "MovementMode"), 5, "flying")
            H.eq(H.log_count("Fly: the game's FlyMode cheat left Crypto in Walking - using the mod's own way", true), 1, "fallback line")
          end },
        { name = "default: the dev FlyMode cheat is never called",
          setup = setup(nil, { fly_cheat = "works" }),
          run = function(H)
            W.spawn(H); H.run(3.0); press(H, "NumPadSeven")
            H.eq(X.flymode, nil, "not called"); H.eq(H.peek(X.m, "MovementMode"), 5, "flying")
          end },
        { name = "main menu: nothing happens",
          setup = setup(nil, { menus = true }),
          run = function(H) W.spawn(H); H.run(3.0); press(H, "NumPadSeven"); H.eq(X.smm_calls, 0, "nothing"); H.eq(W.calls.K2_SetTimer or 0, 0, "no timer") end },
        { name = "quit while in noclip: nothing left running",
          setup = setup(nil),
          run = function(H)
            W.spawn(H); H.run(3.0); press(H, "NumPadEight"); H.quit("menu")
            local r = H.quit_report(1.0)
            H.eq(#r.alive, 0, "nothing alive"); H.eq(r.access_after_teardown, 0, "nothing after teardown")
          end },
    },
}

-- 2026-10-01 GC rollout (High on Life smoke A/B 20261001-003327 vs 004517: minute-2 hitches 12 -> 1): generational Lua GC.
-- UE4SS creates its Lua states in Lua's default incremental mode; the standalone lua.exe running this harness starts
-- in generational mode, so switch back first or the check proves nothing. Uses the first scenario's world.
do
    local list = OTC_SPEC.scenarios or OTC_SPEC
    local base = list[1]
    list[#list + 1] = { name = "Lua GC is switched to generational mode at load",
        setup = function(H) collectgarbage("incremental"); if base and base.setup then base.setup(H) end end,
        run = function(H)
            H.run(0.5)
            local prev = collectgarbage("incremental")          -- returns the mode that was active
            collectgarbage("generational")
            H.eq(prev, "generational", "GC mode after the mod loaded")
        end }
end
return OTC_SPEC
