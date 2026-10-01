-- =======================================================================
-- Destroy All Humans! (2020): Infinite Ammo and Charge v1.0.1
-- Target: DH-Win64-Shipping (Unreal Engine 4.22, Steam build 6184983)
-- Framework: UE4SS v3.0.1 experimental (commit e3ba1016, 2026-09-29; tested in game. Build f08dfdf runs the mods too but crashes when the game closes)
-- UE4SS-settings.ini: nothing required.
--
-- What it does: ammo weapons never run out (Cheat.InfiniteAmmo) and energy weapons never run dry
-- (Cheat.InfiniteCharge): on foot and in the saucer, on from the moment you load a save. F7 switches both.
-- How: otc_dah.lua (shipped next to this file; see its header): the developers' cheat manager flips the game's
-- own cheat variables, read back after every change. Game thread only (engine timer on your controller).
-- =======================================================================
-- Self-checks (registered by otc_dah.lua with the default keys; listed here for our test tooling sheet):
-- SC:expect("weapons_on", "load a save and wait 3 s")
-- SC:expect("weapons_off", "press F7 twice (off, then on again)", { optional = true })
local ModName = "DAHInfiniteAmmo"
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
local function bool(name, default) local v = config[name]; if type(v) ~= "boolean" then return default end return v end
local hotkey = config.hotkey
if type(hotkey) ~= "string" then hotkey = "F7" end
local cheats = {}
if bool("ammo", true) then cheats[#cheats + 1] = "ammo" end
if bool("charge", true) then cheats[#cheats + 1] = "charge" end

print(string.format("[%s] Initializing v%s (ammo %s, charge %s, starts %s, key %s).\n", ModName, ModVersion,
    bool("ammo", true) and "on" or "off", bool("charge", true) and "on" or "off", bool("start_on", true) and "on" or "off", hotkey ~= "" and hotkey or "none"))
if #cheats == 0 then
    print(string.format("[%s] Both ammo and charge are set to false in config.lua: nothing to do.\n", ModName))
    return
end

Core.run({
    mod = ModName, version = ModVersion,
    switches = {
        { id = "weapons", label = "Infinite Ammo and Charge", cheats = cheats, start = bool("start_on", true), key = hotkey,
          sc_how = "press " .. (hotkey ~= "" and hotkey or "the key") .. " twice (off, then on again)" },
    },
})
