-- Scenarios for Destroy All Humans Unlimited DNA 1.0.0 (otc_dah 1.0). Fake world: Src\_shared\dah_fake.lua.
local here = (debug.getinfo(1, "S").source:gsub("^@", "")):match("^(.*[/\\])") or "./"
local F = dofile(here .. "../../_shared/dah_fake.lua")
local W
local function setup(cfg, opts) return function(H) package.loaded["config"] = cfg; W = F.build(H, opts) end end
local function dna() return W.ps_fields().m_iDNA end

local OTC_SPEC = {
    scenarios = {
        { name = "F4 adds 1000 each press, read back + self-check",
          setup = setup(nil),
          run = function(H)
            W.spawn(H); H.run(1.0)
            W.press(H, "F4"); W.press(H, "F4"); W.press(H, "F4")
            H.eq(dna(), 3250, "250 + 3 x 1000")
            H.eq(H.log_count("Add DNA: +1000 (now 3250)", true), 1, "total logged")
            H.eq(H.log_count("[SELFCHECK] DAHUnlimitedDNA dna_added PASS", true), 1, "PASS")
            H.eq(W.calls.AddDNA, 3, "the game's own AddDNA")
          end },
        { name = "holding F4 adds once (no repeat)",
          setup = setup(nil),
          run = function(H)
            W.spawn(H); H.run(1.0)
            H.key_down("F4", true); H.run(2.0); H.key_down("F4", false); H.run(0.2)
            H.eq(dna(), 1250, "one press")
          end },
        { name = "amount from config, clamped to 1..10000000",
          setup = setup({ amount = 99999999, hotkey = "PAGEUP" }),
          run = function(H)
            W.spawn(H); H.run(1.0); W.press(H, "PageUp")
            H.eq(dna(), 10000250, "capped at 10 million per press")
            H.eq(H.log_count("Initializing v1.0.1 (10000000 DNA per press of PAGEUP)", true), 1, "init line")
          end },
        { name = "never past the game's 32-bit counter",
          setup = setup(nil, { dna = 1999999500 }),
          run = function(H)
            W.spawn(H); H.run(1.0); W.press(H, "F4"); W.press(H, "F4")
            H.eq(dna(), 2000000000, "stopped at 2 billion")
          end },
        { name = "AddDNA does nothing (game update): FAIL line",
          setup = function(H)
            package.loaded["config"] = nil
            W = F.build(H)
            H.on_write = nil
          end,
          run = function(H)
            W.spawn(H); H.run(1.0)
            -- break the game's function after the world exists
            local cm = nil
            W.press(H, "F4")                       -- first press creates the manager and adds
            for _, p in ipairs(H.all_objects) do if H._D[p] and H._D[p].name:find("BFGCheatManager_", 1, true) then cm = p end end
            H.poke(cm, "AddDNA", function() end)
            local before = dna()
            W.press(H, "F4")
            H.eq(dna(), before, "no change")
            H.eq(H.log_count("Add DNA failed: no change", true), 1, "failure line")
          end },
        { name = "no key: nothing registered",
          setup = setup({ hotkey = "" }),
          run = function(H)
            H.eq(H.log_count("No key set in config.lua: nothing to do.", true), 1, "line")
            H.eq(H.calls.RegisterHook, 0, "no hooks")
          end },
        { name = "main menu: F4 ignored",
          setup = setup(nil, { menus = true }),
          run = function(H) W.spawn(H); H.run(1.0); W.press(H, "F4"); H.eq(dna(), 250, "unchanged") end },
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
