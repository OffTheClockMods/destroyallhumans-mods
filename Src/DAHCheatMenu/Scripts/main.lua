-- =======================================================================
-- Destroy All Humans! (2020): Cheat Menu v1.0.1
-- Target: DH-Win64-Shipping (Unreal Engine 4.22, Steam build 6184983)
-- Framework: UE4SS v3.0.1 experimental (commit e3ba1016, 2026-09-29; tested in game. Build f08dfdf runs the mods too but crashes when the game closes)
-- UE4SS-settings.ini: nothing required.
--
-- What it does: the developers' own cheats on keys, no console or unlocker needed:
--   F5 God Mode, F7 Infinite Ammo and Charge, F8 Unlimited Concentration (psychic powers, Holobob),
--   F9 Invisibility, F10 Unlimited Jetpack, F4 Add DNA, Ctrl+F3 nuke enemies nearby, Page Up call the saucer,
--   End unstuck (respawn), Page Down hide HUD. Start states, keys and amounts in Scripts\config.lua.
-- How: otc_dah.lua (shipped next to this file; see its header). Cheats are the game's own console variables,
-- switched with the game's own cheat manager (UBFGCheatManager) and read back after every change; the jetpack is
-- topped up with the jetpack component's own AddFuel. Everything runs on the game thread from an engine timer
-- on your controller; keys are read with PlayerController:IsInputKeyDown. Nothing runs off the game thread.
-- =======================================================================
-- Self-checks (registered by otc_dah.lua with the default keys; listed here for our test tooling sheet):
-- SC:expect("god_on", "press F5 once (God Mode on)")
-- SC:expect("weapons_on", "press F7 once (Infinite Ammo and Charge on)")
-- SC:expect("concentration_on", "press F8 once (Unlimited Concentration on)")
-- SC:expect("invisibility_on", "press F9 once (Invisibility on)")
-- SC:expect("jetpack_full", "press F10, then fly with the jetpack for 2 s")
-- SC:expect("dna_added", "press F4 once (DNA counter goes up)")
-- SC:expect("god_off", "press the God Mode key twice (off, then on again)", { optional = true })
local ModName = "DAHCheatMenu"
local ModVersion = "1.0.1"
-- Lua garbage collector in generational mode (1.0.1, 2026-10-01). The game-thread tick (engine timer every 0.05 s -> Actor:ForceNetUpdate) runs 20 times a second and every call leaves
-- short-lived objects in this mod's own Lua state; generational GC frees them in small minor collections instead
-- of periodic full incremental cycles (High on Life smoke A/B: frames over 50 ms in minute 2 went 12 -> 1).
-- Lua 5.4 only (UE4SS ships 5.4); on any other version this line does nothing. Touches no game object.
pcall(collectgarbage, "generational")
local CORE_MIN = 1.0

local function load_core()
    local ok, m = pcall(require, "otc_dah")
    if not (ok and type(m) == "table") then
        local src = debug and debug.getinfo and debug.getinfo(1, "S").source or ""
        local dir = (src:gsub("^@", "")):match("^(.*[/\\])") or ""
        ok, m = pcall(dofile, dir .. "otc_dah.lua")
    end
    if ok and type(m) == "table" and type(m.run) == "function" and (tonumber(m.VERSION) or 0) >= CORE_MIN then return m end
    return nil
end
local Core = load_core()
if not Core then
    print(string.format("[%s] otc_dah.lua missing or older than %.1f; mod disabled (copy every file from the download).\n", ModName, CORE_MIN))
    return
end

local okc, config = pcall(require, "config")
if not okc or type(config) ~= "table" then
    local why = tostring(config):match("^[^\n]*") or ""
    if okc or not why:find("not found", 1, true) then
        print(string.format("[%s] Warning: Scripts\\config.lua could not be loaded (%s); using the default settings.\n", ModName, why))
    end
    config = {}
end

local function cfgv(name, default)
    local v = config[name]
    if v == nil then return default end
    return v
end
local bool = function(name, default) local v = cfgv(name, default); if type(v) ~= "boolean" then return default end return v end
local key = function(name, default) local v = cfgv(name, default); if type(v) ~= "string" then return default end return v end

local style = tostring(cfgv("god_mode_style", "invulnerable")):lower()
if style ~= "immortal" then style = "invulnerable" end
local weaponCheats = {}
if bool("weapons_ammo", true) then weaponCheats[#weaponCheats + 1] = "ammo" end
if bool("weapons_charge", true) then weaponCheats[#weaponCheats + 1] = "charge" end
local dna = cfgv("dna_amount", 1000)
if type(dna) ~= "number" or dna ~= dna then dna = 1000 end
if dna < 1 then dna = 1 elseif dna > 10000000 then dna = 10000000 end   -- cap: the game stores DNA as a 32-bit number
dna = math.floor(dna)

print(string.format("[%s] Initializing v%s (God Mode style: %s, DNA per press: %d).\n", ModName, ModVersion, style, dna))

Core.run({
    mod = ModName, version = ModVersion,
    switches = {
        { id = "god", label = "God Mode", cheats = { style }, start = bool("god_mode", false), key = key("god_mode_key", "F5"),
          sc_how = "press the God Mode key twice (off, then on again)" },
        { id = "weapons", label = "Infinite Ammo and Charge", cheats = weaponCheats, start = bool("weapons", false), key = key("weapons_key", "F7"),
          sc_how = "press the Infinite Ammo key twice" },
        { id = "concentration", label = "Unlimited Concentration", cheats = { "concentration" }, start = bool("concentration", false),
          key = key("concentration_key", "F8"), sc_how = "press the Concentration key twice" },
        { id = "invisibility", label = "Invisibility", cheats = { "invisibility" }, start = bool("invisibility", false),
          key = key("invisibility_key", "F9"), sc_how = "press the Invisibility key twice" },
        { id = "hud", label = "Hide HUD", cheats = { "hud" }, start = false, key = key("hide_hud_key", "PAGEDOWN") },
    },
    jetpack = { start = bool("jetpack", false), key = key("jetpack_key", "F10") },
    actions = {
        Core.action_dna(dna, key("dna_key", "F4")),
        Core.action_call("nuke", "Nuke enemies nearby", "NukeEnemies", key("nuke_key", "CTRL+F3")),
        Core.action_call("call_saucer", "Call the saucer", "CallUFO", key("call_saucer_key", "PAGEUP")),
        Core.action_call("unstuck", "Unstuck (respawn)", "RespawnPlayer", key("unstuck_key", "END")),
        Core.action_skip_step(key("skip_mission_step_key", "")),
    },
})
