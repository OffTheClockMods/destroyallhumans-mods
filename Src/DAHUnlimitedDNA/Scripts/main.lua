-- =======================================================================
-- Destroy All Humans! (2020): Unlimited DNA v1.0.1
-- Target: DH-Win64-Shipping (Unreal Engine 4.22, Steam build 6184983)
-- Framework: UE4SS v3.0.1 experimental (commit e3ba1016, 2026-09-29; tested in game. Build f08dfdf runs the mods too but crashes when the game closes)
-- UE4SS-settings.ini: nothing required.
--
-- What it does: F4 adds 1,000 DNA (the Pox Lab upgrade currency), as often as you like. Amount and key in
-- Scripts\config.lua. Uses the game's own UBFGCheatManager:AddDNA; the new total is read back from your
-- PlayerState (m_iDNA) and logged. Game thread only (engine timer on your controller; otc_dah.lua header).
-- =======================================================================
-- Self-checks (registered by otc_dah.lua with the default keys; listed here for our test tooling sheet):
-- SC:expect("dna_added", "press F4 once (DNA counter goes up)")
local ModName = "DAHUnlimitedDNA"
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
local hotkey = config.hotkey
if type(hotkey) ~= "string" then hotkey = "F4" end
local amount = config.amount
if type(amount) ~= "number" or amount ~= amount then amount = 1000 end
if amount < 1 then amount = 1 elseif amount > 10000000 then amount = 10000000 end   -- the game stores DNA as a 32-bit number
amount = math.floor(amount)

print(string.format("[%s] Initializing v%s (%d DNA per press of %s).\n", ModName, ModVersion, amount, hotkey ~= "" and hotkey or "no key"))
if hotkey == "" then print(string.format("[%s] No key set in config.lua: nothing to do.\n", ModName)) return end

Core.run({
    mod = ModName, version = ModVersion,
    actions = { Core.action_dna(amount, hotkey) },
})
