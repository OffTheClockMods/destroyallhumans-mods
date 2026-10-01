-- Scenarios for Destroy All Humans Cheat Menu 1.0.0 (otc_dah 1.0). Fake world: Src\_shared\dah_fake.lua.
local here = (debug.getinfo(1, "S").source:gsub("^@", "")):match("^(.*[/\\])") or "./"
local F = dofile(here .. "../../_shared/dah_fake.lua")
local W

local function setup(cfg, opts)
    return function(H)
        package.loaded["config"] = cfg
        W = F.build(H, opts)
    end
end
local function cv(n) return W.cvars[n] end

local OTC_SPEC = {
    scenarios = {
        { name = "load in (all start off): engine timer set with 4 args, nothing switched, keys live",
          setup = setup({}),
          run = function(H)
            W.spawn(H); H.run(3.0)
            H.eq(W.calls.K2_SetTimer, 1, "one engine timer")
            H.eq(W.active_timers(), 1, "timer active")
            H.eq(cv("Cheat.Invulnerability"), 0, "god mode not switched on by itself")
            H.eq(W.calls.StaticConstructObject or 0, 1, "cheat manager created once (the game has none)")
            H.eq(H.log_count("game-thread tick running", true), 1, "tick line once")
            H.eq(H.calls.RegisterKeyBind, 0, "no RegisterKeyBind")
            H.check(H.calls.IsInputKeyDown > 0, "keys read with IsInputKeyDown")
          end },

        { name = "F5 God Mode on/off with read-back + self-checks",
          setup = setup({}),
          run = function(H)
            W.spawn(H); H.run(3.0)
            W.press(H, "F5"); H.run(1.5)
            H.eq(cv("Cheat.Invulnerability"), 1, "invulnerable after F5")
            H.eq(H.log_count("God Mode ON (key F5)", true), 1, "ON line")
            H.eq(H.log_count("[SELFCHECK] DAHCheatMenu god_on PASS", true), 1, "god_on PASS")
            W.press(H, "F5"); H.run(1.5)
            H.eq(cv("Cheat.Invulnerability"), 0, "off after second F5")
            H.eq(H.log_count("[SELFCHECK] DAHCheatMenu god_off PASS", true), 1, "god_off PASS")
            H.eq(cv("Cheat.Immortality"), 0, "immortality untouched")
          end },

        { name = "F7 F8 F9 PageDown: ammo+charge, concentration, invisibility, hide HUD",
          setup = setup({}),
          run = function(H)
            W.spawn(H); H.run(3.0)
            W.press(H, "F7"); W.press(H, "F8"); W.press(H, "F9"); W.press(H, "PageDown"); H.run(1.5)
            H.eq(cv("Cheat.InfiniteAmmo"), 1, "ammo"); H.eq(cv("Cheat.InfiniteCharge"), 1, "charge")
            H.eq(cv("Cheat.InfiniteConcentration"), 1, "concentration"); H.eq(cv("Cheat.Invisibility"), 1, "invisible")
            H.eq(cv("Cheat.ToggleHUD"), 1, "HUD hidden")
            H.eq(cv("Cheat.Invulnerability"), 0, "god mode untouched")
          end },

        { name = "config: everything on at start -> applied 2 s after load, never inside ClientRestart",
          setup = setup({ god_mode = true, weapons = true, concentration = true, invisibility = true, jetpack = true }),
          run = function(H)
            W.spawn(H)
            H.eq(cv("Cheat.Invulnerability"), 0, "not inside ClientRestart")
            H.run(1.0); H.eq(cv("Cheat.Invulnerability"), 0, "not before 2 s")
            H.run(2.0)
            for _, n in ipairs({ "Cheat.Invulnerability", "Cheat.InfiniteAmmo", "Cheat.InfiniteCharge", "Cheat.InfiniteConcentration", "Cheat.Invisibility" }) do
                H.eq(cv(n), 1, n .. " on")
            end
            H.run(1.5)
            H.eq(H.log_count("[SELFCHECK] DAHCheatMenu weapons_on PASS", true), 1, "weapons PASS")
          end },

        { name = "god_mode_style = immortal uses Cheat.Immortality",
          setup = setup({ god_mode = true, god_mode_style = "immortal" }),
          run = function(H)
            W.spawn(H); H.run(3.0)
            H.eq(cv("Cheat.Immortality"), 1, "immortal"); H.eq(cv("Cheat.Invulnerability"), 0, "not invulnerable")
          end },

        { name = "weapons_charge = false: F7 only switches ammo",
          setup = setup({ weapons_charge = false }),
          run = function(H)
            W.spawn(H); H.run(3.0); W.press(H, "F7"); H.run(0.5)
            H.eq(cv("Cheat.InfiniteAmmo"), 1, "ammo"); H.eq(cv("Cheat.InfiniteCharge"), 0, "charge untouched")
          end },

        { name = "already on (another mod or the game): no toggle call, stays on",
          setup = setup({ god_mode = true }, { cvars = { ["Cheat.Invulnerability"] = 1 } }),
          run = function(H)
            W.spawn(H); H.run(3.5)
            H.eq(cv("Cheat.Invulnerability"), 1, "still on")
            H.eq(W.calls["Cheat.Invulnerability"] or 0, 0, "toggle never called")
          end },

        { name = "F10 jetpack: fuel topped up on foot; in the saucer it waits without errors",
          setup = setup({}, { ufo = true }),
          run = function(H)
            W.spawn(H); H.run(3.0)
            W.press(H, "F10"); H.run(1.0)
            H.eq(H.log_count("Unlimited Jetpack ON (key F10)", true), 1, "ON line")
            H.eq(H.log_count("[SELFCHECK] DAHCheatMenu jetpack_full WAITING not on foot", true), 1, "waiting in the saucer")
            W.to_foot(H); H.run(0.5)
            W.jet_state.fuel = 35; H.run(0.2)
            H.eq(W.jet_state.fuel, 100, "topped up to full")
            H.eq(H.log_count("[SELFCHECK] DAHCheatMenu jetpack_full PASS", true), 1, "jetpack PASS")
            W.press(H, "F10"); W.jet_state.fuel = 40; H.run(1.0)
            H.eq(W.jet_state.fuel, 40, "off: fuel drains normally")
          end },

        { name = "F4 Add DNA: +1000 read back; config amount; never past the 32-bit limit",
          setup = setup({ dna_amount = 5 }, { dna = 1999999998 }),
          run = function(H)
            W.spawn(H); H.run(3.0)
            W.press(H, "F4")
            H.eq(W.ps_fields().m_iDNA, 2000000000, "capped at the safe maximum")
            W.press(H, "F4")
            H.eq(W.ps_fields().m_iDNA, 2000000000, "nothing added at the maximum")
            H.eq(H.log_count("the safe maximum", true), 1, "max line")
          end },

        { name = "F4 Add DNA default 1000 + self-check",
          setup = setup({}),
          run = function(H)
            W.spawn(H); H.run(3.0); W.press(H, "F4"); W.press(H, "F4")
            H.eq(W.ps_fields().m_iDNA, 2250, "250 + 2 x 1000")
            H.eq(H.log_count("Add DNA: +1000 (now 1250)", true), 1, "logged with total")
            H.eq(H.log_count("[SELFCHECK] DAHCheatMenu dna_added PASS", true), 1, "PASS")
          end },

        { name = "extras: Ctrl+F3 nuke (plain F3 does nothing), PageUp saucer, End unstuck; mission skip off by default",
          setup = setup({}),
          run = function(H)
            W.spawn(H); H.run(3.0)
            W.press(H, "F3"); H.eq(W.calls.NukeEnemies or 0, 0, "plain F3: nothing")
            W.press(H, "F3", true); H.eq(W.calls.NukeEnemies, 1, "Ctrl+F3: nuke")
            W.press(H, "PageUp"); H.eq(W.calls.CallUFO, 1, "saucer called")
            W.press(H, "End"); H.eq(W.calls.RespawnPlayer, 1, "respawned")
            W.press(H, "Insert"); H.eq(H.log_count("Skip mission step", true), 0, "skip step has no key by default")
          end },

        { name = "skip_mission_step_key = INSERT: the game's own CheatCompleteMissionStep",
          setup = function(H)
            package.loaded["config"] = { skip_mission_step_key = "INSERT" }
            W = F.build(H)
            W.qm_calls = 0
            H.obj("BFGQuest_Manager_0", { CheatCompleteMissionStep = function() W.qm_calls = W.qm_calls + 1 end })
          end,
          run = function(H)
            W.spawn(H); H.run(3.0); W.press(H, "Insert")
            H.eq(W.qm_calls, 1, "mission step completed")
          end },

        { name = "main menu controller: no timer, keys ignored",
          setup = setup({}, { menus = true }),
          run = function(H)
            W.spawn(H); H.run(3.0); W.press(H, "F5")
            H.eq(W.calls.K2_SetTimer or 0, 0, "no timer in the menus")
            H.eq(cv("Cheat.Invulnerability"), 0, "nothing switched")
          end },

        { name = "respawn / saucer <-> foot: timer replaced (never doubled), states kept",
          setup = setup({ god_mode = true }),
          run = function(H)
            W.spawn(H); H.run(3.0)
            W.to_foot(H); H.run(3.0); W.to_ufo(H); H.run(3.0)
            H.eq(W.active_timers(), 1, "one timer")
            H.eq(cv("Cheat.Invulnerability"), 1, "god mode still on")
            H.eq(W.calls["Cheat.Invulnerability"], 1, "toggled exactly once")
          end },

        { name = "key state survives a level change (God Mode switched off stays off)",
          setup = setup({ god_mode = true }),
          run = function(H)
            W.spawn(H); H.run(3.0); W.press(H, "F5"); H.run(0.5)
            H.eq(cv("Cheat.Invulnerability"), 0, "off by key")
            H.change_world(function(H2) W.make_world(H2) end)
            W.spawn(H); H.run(3.0)
            H.eq(cv("Cheat.Invulnerability"), 0, "still off after the level change")
            H.eq(W.active_timers(), 1, "timer on the new controller")
          end },

        { name = "toggle does nothing (game update): clear line + self-check FAIL, no crash",
          setup = setup({ god_mode = true }, { toggle_broken = true }),
          run = function(H)
            W.spawn(H); H.run(4.0)
            H.eq(H.log_count("God Mode: could not switch on", true), 1, "clear line")
            H.eq(H.log_count("[SELFCHECK] DAHCheatMenu god_on FAIL", true), 1, "FAIL")
          end },

        { name = "cheat manager class gone (game update): one line, mod idle",
          setup = setup({ god_mode = true }, { no_cheat_class = true }),
          run = function(H)
            H.statics["/Script/BFGCore.BFGCheatManager"] = nil
            W.spawn(H); H.run(4.0); W.press(H, "F5")
            H.eq(H.log_count("feature disabled: whole mod - the game's cheat manager is not available", true), 1, "disabled once")
            H.eq(cv("Cheat.Invulnerability"), 0, "nothing switched")
          end },

        { name = "K2_SetTimer missing (game update): disabled line, no tick",
          setup = setup({}, { no_timer_api = true }),
          run = function(H)
            W.spawn(H); H.run(2.0)
            H.eq(H.log_count("feature disabled: whole mod - K2_SetTimer failed", true), 1, "one line")
          end },

        { name = "ForceNetUpdate hook missing: one clear line",
          setup = function(H) H.missing_hooks[F.TICK] = true; package.loaded["config"] = {}; W = F.build(H) end,
          run = function(H)
            H.run(0.5)
            H.eq(H.log_count("feature disabled: whole mod - could not hook Actor:ForceNetUpdate", true), 1, "line")
          end },

        { name = "the hook ignores other actors' ForceNetUpdate calls",
          setup = setup({}),
          run = function(H)
            W.spawn(H); H.run(3.0)
            local other = H.obj("SomeActor_0", {})
            local n0 = H.calls.IsInputKeyDown
            H.fire_hook(F.TICK, other)
            H.eq(H.calls.IsInputKeyDown, n0, "no key read for another actor")
          end },

        { name = "broken config.lua: defaults, one warning",
          setup = function(H)
            package.loaded["config"] = nil
            package.preload["config"] = function() error("config.lua:3: unexpected symbol near '}'") end
            W = F.build(H)
          end,
          run = function(H)
            W.spawn(H); H.run(3.0); W.press(H, "F5")
            H.eq(cv("Cheat.Invulnerability"), 1, "default key works")
            H.eq(H.log_count("Warning: Scripts\\config.lua could not be loaded", true), 1, "one warning")
          end },

        { name = "unknown key name: warning, other keys still work",
          setup = setup({ god_mode_key = "F55" }),
          run = function(H)
            W.spawn(H); H.run(3.0); W.press(H, "F7")
            H.eq(H.log_count("unknown key name 'F55'", true), 1, "warning")
            H.eq(cv("Cheat.InfiniteAmmo"), 1, "F7 still works")
          end },

        { name = "quit: nothing left running, nothing touched after teardown",
          setup = setup({ god_mode = true, jetpack = true }),
          run = function(H)
            W.spawn(H); H.run(3.0)
            H.quit("menu")
            local r = H.quit_report(1.0)
            H.eq(#r.alive, 0, "no Lua timers or loops")
            H.eq(r.access_after_teardown, 0, "nothing touched after teardown")
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
