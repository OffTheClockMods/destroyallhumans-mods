-- Scenarios for Destroy All Humans Infinite Ammo and Charge 1.0.0 (otc_dah 1.0). Fake world: Src\_shared\dah_fake.lua.
local here = (debug.getinfo(1, "S").source:gsub("^@", "")):match("^(.*[/\\])") or "./"
local F = dofile(here .. "../../_shared/dah_fake.lua")
local W
local function setup(cfg, opts) return function(H) package.loaded["config"] = cfg; W = F.build(H, opts) end end
local function cv(n) return W.cvars[n] end

local OTC_SPEC = {
    scenarios = {
        { name = "load in: ammo + charge on 2 s later, self-check PASS",
          setup = setup(nil),
          run = function(H)
            W.spawn(H); H.run(3.5)
            H.eq(cv("Cheat.InfiniteAmmo"), 1, "ammo"); H.eq(cv("Cheat.InfiniteCharge"), 1, "charge")
            H.eq(H.log_count("[SELFCHECK] DAHInfiniteAmmo weapons_on PASS", true), 1, "PASS")
            H.eq(cv("Cheat.Invulnerability"), 0, "god mode untouched")
          end },
        { name = "F7 switches both off and on",
          setup = setup(nil),
          run = function(H)
            W.spawn(H); H.run(3.0)
            W.press(H, "F7"); H.eq(cv("Cheat.InfiniteAmmo"), 0, "ammo off"); H.eq(cv("Cheat.InfiniteCharge"), 0, "charge off")
            W.press(H, "F7"); H.eq(cv("Cheat.InfiniteAmmo"), 1, "ammo on"); H.eq(cv("Cheat.InfiniteCharge"), 1, "charge on")
          end },
        { name = "charge = false: only ammo",
          setup = setup({ charge = false }),
          run = function(H)
            W.spawn(H); H.run(3.5)
            H.eq(cv("Cheat.InfiniteAmmo"), 1, "ammo"); H.eq(cv("Cheat.InfiniteCharge"), 0, "charge untouched")
          end },
        { name = "both false: the mod says so and does nothing",
          setup = setup({ ammo = false, charge = false }),
          run = function(H)
            W.spawn(H); H.run(3.5)
            H.eq(H.log_count("nothing to do", true), 1, "line")
            H.eq(W.calls.K2_SetTimer or 0, 0, "no timer")
          end },
        { name = "works in the saucer and on foot (one timer)",
          setup = setup(nil, { ufo = true }),
          run = function(H)
            W.spawn(H); H.run(3.0); W.to_foot(H); H.run(3.0)
            H.eq(cv("Cheat.InfiniteAmmo"), 1, "still on"); H.eq(W.active_timers(), 1, "one timer")
          end },
        { name = "hotkey \"\": no key, still on at start",
          setup = setup({ hotkey = "" }),
          run = function(H)
            W.spawn(H); H.run(3.5); W.press(H, "F7")
            H.eq(cv("Cheat.InfiniteAmmo"), 1, "F7 does nothing, stays on")
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
