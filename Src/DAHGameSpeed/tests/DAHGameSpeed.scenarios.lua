-- Scenarios for Destroy All Humans Game Speed 1.0.0 (otc_dah 1.0). Fake world: Src\_shared\dah_fake.lua, extended here with
-- what this mod touches (names from the UE4SS dump 2026-09-30): World:K2_GetWorldSettings, AWorldSettings TimeDilation /
-- MatineeTimeDilation / DemoPlayTimeDilation / Min-MaxGlobalTimeDilation, GameplayStatics Set/GetGlobalTimeDilation,
-- GetRealTimeSeconds, GetUnpausedTimeSeconds. The fake engine advances the game clock by real time x the product of the
-- three factors, like UWorld::Tick (AWorldSettings::GetEffectiveTimeDilation).
local here = (debug.getinfo(1, "S").source:gsub("^@", "")):match("^(.*[/\\])") or "./"
local F = dofile(here .. "../../_shared/dah_fake.lua")
local W, X
local GS_PATH = "/Script/Engine.Default__GameplayStatics"

-- opts: ignore_factor (the engine doesn't use DemoPlayTimeDilation), game_resets_td (the game sets TimeDilation back to 1
--       every frame), game_td (the game's own slow motion value)
local function new_ws(H)
    local ws = H.obj("WorldSettings_" .. H.world_gen, { TimeDilation = X.o.game_td or 1.0, MatineeTimeDilation = 1.0, DemoPlayTimeDilation = 1.0,
        MinGlobalTimeDilation = 0.0001, MaxGlobalTimeDilation = 20.0 }, { class = H.class("WorldSettings", "Actor", "/Script/Engine.WorldSettings") })
    H.poke(W.world, "K2_GetWorldSettings", function() return ws end)
    X.ws, X.real, X.unpaused = ws, 0.0, 0.0
    return ws
end

local function extend(H, o)
    X = { o = o, set_global = 0 }
    new_ws(H)
    H.statics[GS_PATH] = H.obj("Default__GameplayStatics", {
        SetGlobalTimeDilation = function(_, wc, v)
            X.set_global = X.set_global + 1
            local ws = X.ws
            local lo, hi = H.peek(ws, "MinGlobalTimeDilation"), H.peek(ws, "MaxGlobalTimeDilation")
            H.poke(ws, "TimeDilation", math.max(lo, math.min(hi, v)))
        end,
        GetGlobalTimeDilation = function() return H.peek(X.ws, "TimeDilation") end,
        GetRealTimeSeconds = function() return X.real end,
        GetUnpausedTimeSeconds = function() return X.unpaused end,
    }, { persistent = true, find = false, path = GS_PATH })
    H.on_frame(function()
        local ws = X.ws
        if not H.is_alive(ws) then return end
        local dt = H.config.tick_ms / 1000
        local eff = H.peek(ws, "TimeDilation") * H.peek(ws, "MatineeTimeDilation") * (X.o.ignore_factor and 1.0 or H.peek(ws, "DemoPlayTimeDilation"))
        X.real = X.real + dt
        X.unpaused = X.unpaused + dt * eff
        if X.o.game_resets_td then H.poke(ws, "TimeDilation", 1.0) end
    end)
end

local function setup(cfg, opts)
    return function(H)
        package.loaded["config"] = cfg
        W = F.build(H, opts)
        extend(H, opts or {})
    end
end
local function factor(H) return H.peek(X.ws, "DemoPlayTimeDilation") end
local function timer_rate()
    for _, t in ipairs(W.timers) do if not t.dead then return t.rate end end
    return nil
end
local function near(a, b) return type(a) == "number" and math.abs(a - b) < 1e-6 end
local function press(H, key, ctrl) W.press(H, key, ctrl) end

local OTC_SPEC = {
    scenarios = {
        { name = "Numpad +: x1.5 (factor read back, clock measured x1.5, key timer 0.075 s); Numpad 9: back to x1",
          setup = setup(nil),
          run = function(H)
            W.spawn(H); H.run(3.0)
            H.eq(factor(H), 1.0, "nothing changed at load (start x1)")
            press(H, "Add")
            H.eq(factor(H), 1.5, "factor x1.5")
            H.eq(H.peek(X.ws, "TimeDilation"), 1.0, "the game's own TimeDilation untouched")
            H.eq(H.log_count("Game speed x1.5 (key ADD; extra time factor 1.50)", true), 1, "line")
            H.eq(H.log_count("[SELFCHECK] DAHGameSpeed speed_faster PASS", true), 1, "faster PASS")
            H.check(near(timer_rate(), 0.075), "key timer 0.05 x 1.5 (got " .. tostring(timer_rate()) .. ")")
            H.run(2.5)
            H.eq(H.log_count("[SELFCHECK] DAHGameSpeed speed_clock PASS game clock x1.50 vs real clock", true), 1, "clock PASS")
            press(H, "NumPadNine")
            H.eq(factor(H), 1.0, "back to x1")
            H.eq(H.log_count("[SELFCHECK] DAHGameSpeed speed_normal PASS", true), 1, "normal PASS")
            H.check(near(timer_rate(), 0.05), "key timer back to 0.05")
            H.eq(X.set_global, 0, "SetGlobalTimeDilation never needed")
            H.eq(H.calls.RegisterKeyBind, 0, "no RegisterKeyBind")
            H.eq(H.log_count("WARN", true), 0, "no warnings")
          end },
        { name = "Numpad -: x0.75 (read back, clock x0.75, key timer 0.0375 s)",
          setup = setup(nil),
          run = function(H)
            W.spawn(H); H.run(3.0)
            press(H, "Subtract")
            H.eq(factor(H), 0.75, "x0.75")
            H.eq(H.log_count("[SELFCHECK] DAHGameSpeed speed_slower PASS", true), 1, "slower PASS")
            H.check(near(timer_rate(), 0.0375), "key timer 0.0375")
            H.run(2.5)
            H.eq(H.log_count("[SELFCHECK] DAHGameSpeed speed_clock PASS game clock x0.75", true), 1, "clock PASS")
          end },
        { name = "steps: Numpad + to the top (x5, then 'fastest' line), Numpad - to the bottom (x0.1, 'slowest')",
          setup = setup(nil),
          run = function(H)
            W.spawn(H); H.run(3.0)
            for _ = 1, 5 do press(H, "Add") end
            H.eq(factor(H), 5.0, "x5 after 4 presses + 1 extra")
            H.eq(H.log_count("Game speed: already at the fastest step (x5)", true), 1, "fastest line")
            for _ = 1, 9 do press(H, "Subtract") end
            H.eq(factor(H), 0.1, "x0.1 at the bottom")
            H.eq(H.log_count("Game speed: already at the slowest step (x0.1)", true), 1, "slowest line")
            H.check(near(timer_rate(), 0.005), "key timer 0.005 (still 0.05 s of real time)")
            press(H, "NumPadNine"); H.eq(factor(H), 1.0, "normal")
          end },
        { name = "keys still work at x0.1 (the timer follows the speed)",
          setup = setup({ start_speed = 0.1 }),
          run = function(H)
            W.spawn(H); H.run(3.0)
            H.eq(factor(H), 0.1, "start x0.1")
            press(H, "Add"); H.eq(factor(H), 0.25, "next step up")
          end },
        { name = "the game's own slow motion (TimeDilation 0.5) stays: both multiply, clock x1.0 = PASS",
          setup = setup(nil, { game_td = 0.5 }),
          run = function(H)
            W.spawn(H); H.run(3.0)
            press(H, "Add"); press(H, "Add")
            H.eq(factor(H), 2.0, "x2")
            H.run(2.5)
            H.eq(H.peek(X.ws, "TimeDilation"), 0.5, "game's slow motion untouched")
            H.eq(H.log_count("speed_clock PASS game clock x1.00 vs real clock (wanted x2, game's own time x0.50, extra time factor)", true), 1, "PASS")
          end },
        { name = "the engine ignores the extra factor: switch to SetGlobalTimeDilation, measured again, PASS",
          setup = setup(nil, { ignore_factor = true }),
          run = function(H)
            W.spawn(H); H.run(3.0)
            press(H, "Add")
            H.run(2.5)
            H.eq(H.log_count("did not follow the extra time factor (ran x1.00, wanted x1.50) - switching to the engine's global time dilation", true), 1, "switch line")
            H.eq(factor(H), 1.0, "factor back to 1")
            H.eq(H.peek(X.ws, "TimeDilation"), 1.5, "global time dilation x1.5")
            H.run(2.5)
            H.eq(H.log_count("[SELFCHECK] DAHGameSpeed speed_clock PASS game clock x1.50 vs real clock (wanted x1.5, TimeDilation 1.50, global time dilation)", true), 1, "PASS after the switch")
            press(H, "NumPadNine")
            H.eq(H.peek(X.ws, "TimeDilation"), 1.0, "x1 through the global path")
          end },
        { name = "nothing works (factor ignored, the game resets the global one): speed_clock FAIL, no crash",
          setup = setup(nil, { ignore_factor = true, game_resets_td = true }),
          run = function(H)
            W.spawn(H); H.run(3.0)
            press(H, "Add")
            H.run(6.0)
            H.eq(H.log_count("[SELFCHECK] DAHGameSpeed speed_clock FAIL", true), 1, "FAIL")
          end },
        { name = "level change at x2: new WorldSettings, re-applied 2 s after you take control, key timer set again",
          setup = setup(nil),
          run = function(H)
            W.spawn(H); H.run(3.0)
            press(H, "Add"); press(H, "Add")
            H.change_world(function(H2) W.make_world(H2) end); new_ws(H)
            W.spawn(H); H.run(0.5)
            H.check(near(timer_rate(), 0.1), "key timer set back to 0.1 after the engine reset it (got " .. tostring(timer_rate()) .. ")")
            H.eq(factor(H), 1.0, "not yet (2 s delay)")
            H.run(2.0)
            H.eq(factor(H), 2.0, "x2 again")
            H.eq(H.log_count("Game speed x2 (re-applied after loading", true), 1, "line")
          end },
        { name = "a new area resets the factor without a restart: re-applied within 2 s",
          setup = setup(nil),
          run = function(H)
            W.spawn(H); H.run(3.0)
            press(H, "Subtract")
            H.poke(X.ws, "DemoPlayTimeDilation", 1.0); H.run(2.2)
            H.eq(factor(H), 0.75, "x0.75 again")
            H.eq(H.log_count("re-applied: a new area loaded", true), 1, "line")
          end },
        { name = "start_speed 2: applied 2 s after you take control, measured",
          setup = setup({ start_speed = 2.0 }),
          run = function(H)
            W.spawn(H); H.run(1.0); H.eq(factor(H), 1.0, "not inside ClientRestart / not before 2 s")
            H.run(1.5); H.eq(factor(H), 2.0, "x2")
            H.eq(H.log_count("Game speed x2 (start setting", true), 1, "start line")
            H.run(2.5); H.eq(H.log_count("speed_clock PASS", true), 1, "clock PASS")
          end },
        { name = "bad settings: 50 -> 20, non-number skipped, x1 added, start_speed 0 -> 0.01",
          setup = setup({ speeds = { 0.5, 50, "x", 2 }, start_speed = 0 }),
          run = function(H)
            W.spawn(H); H.run(3.0)
            H.eq(H.log_count("config: speeds[2] = 50 is outside 0.01..20", true), 1, "clamp line")
            H.eq(H.log_count("config: 1 entry in speeds is not a number; skipped", true), 1, "skip line")
            H.eq(H.log_count("config: start_speed = 0 is outside 0.01..20", true), 1, "start clamp")
            H.eq(H.log_count("steps x0.5 x1 x2 x20; start x0.01", true), 1, "steps with x1 added")
            H.eq(factor(H), 0.01, "start x0.01")
            press(H, "Add"); H.eq(factor(H), 0.5, "first step up")
          end },
        { name = "custom keys: CTRL+F6 faster, no slower key",
          setup = setup({ faster_key = "CTRL+F6", slower_key = "" }),
          run = function(H)
            W.spawn(H); H.run(3.0)
            press(H, "Add"); H.eq(factor(H), 1.0, "Numpad + is not the key now")
            press(H, "F6"); H.eq(factor(H), 1.0, "plain F6 nothing")
            press(H, "F6", true); H.eq(factor(H), 1.5, "Ctrl+F6 faster")
            H.eq(H.log_count("speed_slower WAITING", true), 0, "no slower check without a key")
          end },
        { name = "main menu: nothing happens",
          setup = setup(nil, { menus = true }),
          run = function(H) W.spawn(H); H.run(3.0); press(H, "Add"); H.eq(factor(H), 1.0, "nothing"); H.eq(W.calls.K2_SetTimer or 0, 0, "no timer") end },
        { name = "quit at x3: nothing left running",
          setup = setup(nil),
          run = function(H)
            W.spawn(H); H.run(3.0); press(H, "Add"); press(H, "Add"); press(H, "Add"); H.quit("menu")
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
