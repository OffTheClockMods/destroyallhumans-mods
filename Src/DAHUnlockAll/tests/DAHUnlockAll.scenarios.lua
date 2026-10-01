-- Scenarios for Destroy All Humans Unlock All Weapons and Abilities 1.0.0 (otc_dah 1.0). Fake: Src\_shared\dah_fake.lua.
local here = (debug.getinfo(1, "S").source:gsub("^@", "")):match("^(.*[/\\])") or "./"
local F = dofile(here .. "../../_shared/dah_fake.lua")
local W
local function setup(cfg, opts) return function(H) package.loaded["config"] = cfg; W = F.build(H, opts) end end

local OTC_SPEC = {
    scenarios = {
        { name = "loading in changes nothing",
          setup = setup(nil),
          run = function(H)
            W.spawn(H); H.run(5.0)
            H.eq(W.calls.UnlockAllWeapons or 0, 0, "no weapons unlock"); H.eq(W.calls.UnlockAlAbilities or 0, 0, "no abilities unlock")
          end },
        { name = "plain F1 / F2 do nothing (Ctrl needed)",
          setup = setup(nil),
          run = function(H)
            W.spawn(H); H.run(1.0); W.press(H, "F1"); W.press(H, "F2")
            H.eq(W.calls.UnlockAllWeapons or 0, 0, "F1 alone: nothing"); H.eq(W.calls.UnlockAlAbilities or 0, 0, "F2 alone: nothing")
          end },
        { name = "Ctrl+F1 weapons, Ctrl+F2 abilities: permanent, counted, self-checks PASS",
          setup = setup(nil),
          run = function(H)
            W.spawn(H); H.run(1.0)
            W.press(H, "F1", true)
            H.eq(W.calls.UnlockAllWeapons, 1, "weapons"); H.eq(W.last_perm, true, "permanent")
            H.eq(H.log_count("Unlock all weapons: done (12 new unlocks, 15 in total)", true), 1, "count line")
            W.press(H, "F2", true)
            H.eq(W.calls.UnlockAlAbilities, 1, "abilities (the game's spelling UnlockAlAbilities)")
            H.eq(H.log_count("[SELFCHECK] DAHUnlockAll unlock_weapons PASS", true), 1, "weapons PASS")
            H.eq(H.log_count("[SELFCHECK] DAHUnlockAll unlock_abilities PASS", true), 1, "abilities PASS")
          end },
        { name = "everything already unlocked: says so",
          setup = setup(nil, { weapons_to_unlock = 0 }),
          run = function(H)
            W.spawn(H); H.run(1.0); W.press(H, "F1", true)
            H.eq(H.log_count("Unlock all weapons: nothing new to unlock", true), 1, "line")
          end },
        { name = "unlock list unreadable (game update): failure line, no crash",
          setup = function(H) package.loaded["config"] = nil; W = F.build(H); H.poke(W.ps, "m_pUnlocks", H.invalid) end,
          run = function(H)
            W.spawn(H); H.run(1.0); W.press(H, "F1", true)
            H.eq(H.log_count("Unlock all weapons failed: unlock list not readable", true), 1, "line")
            H.eq(H.log_count("[SELFCHECK] DAHUnlockAll unlock_weapons FAIL", true), 1, "FAIL")
          end },
        { name = "custom keys from config",
          setup = setup({ weapons_key = "SHIFT+F1", abilities_key = "" }),
          run = function(H)
            W.spawn(H); H.run(1.0)
            W.press(H, "F1", true); H.eq(W.calls.UnlockAllWeapons or 0, 0, "Ctrl+F1 no longer")
            H.key_down("LeftShift", true); W.press(H, "F1"); H.key_down("LeftShift", false)
            H.eq(W.calls.UnlockAllWeapons, 1, "Shift+F1")
            W.press(H, "F2", true); H.eq(W.calls.UnlockAlAbilities or 0, 0, "abilities key off")
          end },
        { name = "quit: nothing left running",
          setup = setup(nil),
          run = function(H)
            W.spawn(H); H.run(1.0); H.quit("menu")
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
