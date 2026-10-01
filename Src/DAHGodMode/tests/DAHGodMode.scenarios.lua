-- Scenarios for Destroy All Humans God Mode 1.0.0 (otc_dah 1.0). Fake world: Src\_shared\dah_fake.lua.
local here = (debug.getinfo(1, "S").source:gsub("^@", "")):match("^(.*[/\\])") or "./"
local F = dofile(here .. "../../_shared/dah_fake.lua")
local W
local function setup(cfg, opts) return function(H) package.loaded["config"] = cfg; W = F.build(H, opts) end end
local function cv(n) return W.cvars[n] end

local OTC_SPEC = {
    scenarios = {
        { name = "load in: God Mode on 2 s later (not inside ClientRestart), self-check PASS",
          setup = setup(nil),
          run = function(H)
            W.spawn(H); H.eq(cv("Cheat.Invulnerability"), 0, "not inside ClientRestart")
            H.run(3.5)
            H.eq(cv("Cheat.Invulnerability"), 1, "invulnerable")
            H.eq(H.log_count("God Mode ON (start setting)", true), 1, "ON line")
            H.eq(H.log_count("[SELFCHECK] DAHGodMode god_on PASS", true), 1, "PASS")
            H.eq(H.calls.RegisterKeyBind, 0, "no RegisterKeyBind")
          end },
        { name = "F5 off and on again (+ optional self-check)",
          setup = setup(nil),
          run = function(H)
            W.spawn(H); H.run(3.0)
            W.press(H, "F5"); H.run(1.2)
            H.eq(cv("Cheat.Invulnerability"), 0, "off")
            H.eq(H.log_count("[SELFCHECK] DAHGodMode god_off PASS", true), 1, "off PASS")
            W.press(H, "F5"); H.eq(cv("Cheat.Invulnerability"), 1, "on again")
          end },
        { name = "style immortal + start_on false + custom key CTRL+F5",
          setup = setup({ style = "immortal", start_on = false, hotkey = "CTRL+F5" }),
          run = function(H)
            W.spawn(H); H.run(3.0)
            H.eq(cv("Cheat.Immortality"), 0, "starts off")
            W.press(H, "F5"); H.eq(cv("Cheat.Immortality"), 0, "plain F5 does nothing")
            W.press(H, "F5", true); H.eq(cv("Cheat.Immortality"), 1, "Ctrl+F5 switches immortality on")
            H.eq(cv("Cheat.Invulnerability"), 0, "invulnerability untouched")
          end },
        { name = "survives death/level change: re-applied on the new controller",
          setup = setup(nil),
          run = function(H)
            W.spawn(H); H.run(3.0)
            W.cvars["Cheat.Invulnerability"] = 0        -- as if the game had reset it
            H.change_world(function(H2) W.make_world(H2) end)
            W.spawn(H); H.run(3.0)
            H.eq(cv("Cheat.Invulnerability"), 1, "on again after the level change")
          end },
        { name = "the game resets it while playing: one hint line, no fight with other mods",
          setup = setup(nil),
          run = function(H)
            W.spawn(H); H.run(3.0)
            W.cvars["Cheat.Invulnerability"] = 0; H.run(6.0)
            H.eq(H.log_count("God Mode: the game changed it back", true), 1, "hint once")
            H.eq(cv("Cheat.Invulnerability"), 0, "not forced back (F5 does that)")
          end },
        { name = "Cheat Menu also installed and already switched it on: no double toggle",
          setup = setup(nil, { cvars = { ["Cheat.Invulnerability"] = 1 } }),
          run = function(H)
            W.spawn(H); H.run(3.5)
            H.eq(cv("Cheat.Invulnerability"), 1, "on"); H.eq(W.calls["Cheat.Invulnerability"] or 0, 0, "not toggled")
          end },
        { name = "main menu: nothing happens",
          setup = setup(nil, { menus = true }),
          run = function(H) W.spawn(H); H.run(3.0); H.eq(cv("Cheat.Invulnerability"), 0, "off"); H.eq(W.calls.K2_SetTimer or 0, 0, "no timer") end },
        { name = "toggle broken by a game update: FAIL line, no crash",
          setup = setup(nil, { toggle_broken = true }),
          run = function(H)
            W.spawn(H); H.run(4.0)
            H.eq(H.log_count("[SELFCHECK] DAHGodMode god_on FAIL", true), 1, "FAIL")
          end },
        { name = "quit: nothing left running",
          setup = setup(nil),
          run = function(H)
            W.spawn(H); H.run(3.0); H.quit("menu")
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
