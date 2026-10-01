--[[
  otc_dah.lua (Off the Clock) v1.0 - shared engine of the Destroy All Humans! (2020) mods.
  Target: DH-Win64-Shipping.exe (Unreal Engine 4.22, Steam build 6184983, unpatched since 2022).
  Framework: UE4SS v3.0.1 experimental, build e3ba1016 (2026-09-29) - f08dfdf crashes in its own shutdown here. UE4SS-settings.ini: nothing required.
  Master copy: Src\_shared\otc_dah.lua. Every mod ships its own copy next to main.lua;
  main.lua refuses to run with an older copy.

  What it uses (all found in this game's own reflection data, UE4SS dump 2026-09-30, and checked in game):
    * The developers' own cheat manager, UBFGCheatManager (/Script/BFGCore), kept in
      ABFGPlayerController.m_pCheatManager. Its toggles flip the game's console variables Cheat.Invulnerability,
      Cheat.Immortality, Cheat.InfiniteAmmo, Cheat.InfiniteCharge, Cheat.InfiniteConcentration, Cheat.Invisibility,
      Cheat.ToggleHUD. A toggle is only called when the variable is not already in the wanted state (read with
      KismetSystemLibrary:GetConsoleVariableIntValue), so two of our mods never undo each other.
    * Jetpack: the dev "infinite hover" cheat is an empty function in this build, so the jetpack component
      (ABFGPlayerCharacter.m_pJetpackPilotComponent, UBFGActorComponent_JetpackPilot) is topped up with its own
      AddFuel whenever GetCurrentFuelRatio drops below full.
    * DNA: UBFGCheatManager:AddDNA, read back from ABFGPlayerState.m_iDNA.
    * Unlocks: UBFGCheatManager:UnlockAllWeapons / UnlockAlAbilities (the typo is the game's), read back from the
      unlocked-tag list of UBFGPlayerState_Unlocks.
  Threading (project rule): everything runs inside game-thread hook callbacks. When you take control
  (PlayerController:ClientRestart) the mod asks the ENGINE to call the controller's own Actor:ForceNetUpdate
  every 0.05 s (KismetSystemLibrary:K2_SetTimer, looping; ForceNetUpdate takes no parameters and does nothing in
  single player). The hook on ForceNetUpdate is the mod's game-thread "tick": keys are read there with
  PlayerController:IsInputKeyDown (otc_keys.lua), and all game work happens there. The timer belongs to the
  controller, so it dies with it (quit, map change) and setting it again replaces it (never doubles; all our
  DAH mods share the one timer). No RegisterKeyBind, LoopAsync, ExecuteWithDelay or ExecuteInGameThread.
]]
local M = { VERSION = "1.0" }

local unpack = table.unpack or unpack
local TICK_S = 0.05             -- engine timer rate (all our DAH mods use the same value)
local APPLY_DELAY_S = 2.0       -- start states are applied this long after you take control (never inside ClientRestart)
local RECHECK_S = 5.0           -- read-back of the wanted states (log/self-check only, never re-toggles)
local PC_CLASS_HINT = "BFGPlayerController"   -- the in-game controller (the menus use BFGPlayerController_Menus)
local CHEAT_CLASS = "/Script/BFGCore.BFGCheatManager"
local KISMET = "/Script/Engine.Default__KismetSystemLibrary"
local RESTART = "/Script/Engine.PlayerController:ClientRestart"
local TICK_FN = "ForceNetUpdate"
local TICK_HOOK = "/Script/Engine.Actor:ForceNetUpdate"
local QUIT_HOOK = "/Script/Engine.KismetSystemLibrary:QuitGame"
M.TICK_S, M.TICK_HOOK, M.RESTART, M.CHEAT_CLASS = TICK_S, TICK_HOOK, RESTART, CHEAT_CLASS

-- The game's cheat variables and the cheat-manager function that flips each one.
M.CHEATS = {
    invulnerable  = { cvar = "Cheat.Invulnerability",       fn = "ToggleInvulnerability" },
    immortal      = { cvar = "Cheat.Immortality",           fn = "ToggleImmortality" },
    ammo          = { cvar = "Cheat.InfiniteAmmo",          fn = "ToggleInfiniteAmmo" },
    charge        = { cvar = "Cheat.InfiniteCharge",        fn = "ToggleInfiniteCharge" },
    concentration = { cvar = "Cheat.InfiniteConcentration", fn = "ToggleInfiniteConcentration" },
    invisibility  = { cvar = "Cheat.Invisibility",          fn = "ToggleInvisibility" },
    hud           = { cvar = "Cheat.ToggleHUD",             fn = "ToggleHUD" },
}

-- ------------------------------------------------------------------ loaders (require, then dofile next to this file)
local function here()
    local src = debug and debug.getinfo and debug.getinfo(1, "S").source or ""
    return (src:gsub("^@", "")):match("^(.*[/\\])") or ""
end
local function load_lib(name)
    local ok, m = pcall(require, name)
    if ok and type(m) == "table" then return m end
    local ok2, m2 = pcall(dofile, here() .. name .. ".lua")
    if ok2 and type(m2) == "table" then return m2 end
    return nil, tostring(m)
end

-- ------------------------------------------------------------------ config helpers
-- "F5", "CTRL+F1", "SHIFT+PAGEUP" -> key name + modifier list; "" / "NONE" / "OFF" -> nil.
function M.parse_key(s)
    if s == nil or s == false then return nil end
    s = tostring(s):gsub("%s+", "")
    if s == "" or s:upper() == "NONE" or s:upper() == "OFF" then return nil end
    local parts = {}
    for p in s:gmatch("[^+]+") do parts[#parts + 1] = p end
    local key = parts[#parts]
    local mods = nil
    for i = 1, #parts - 1 do
        local m = parts[i]:upper()
        if m == "CTRL" then m = "CONTROL" end
        mods = mods or {}
        mods[#mods + 1] = m
    end
    return key, mods
end

local function new_config(S, cfg)
    local C = {}
    function C.bool(name, default)
        local v = cfg[name]
        if v == nil then return default end
        if type(v) ~= "boolean" then
            S:warn_once("cfg:" .. name, "config: %s must be true or false; using %s", name, tostring(default))
            return default
        end
        return v
    end
    function C.num(name, default, lo, hi, why)
        local v = cfg[name]
        if v == nil then return default end
        if type(v) ~= "number" or v ~= v then
            S:warn_once("cfg:" .. name, "config: %s must be a number; using %s", name, tostring(default))
            return default
        end
        if v < lo or v > hi then
            local c = v < lo and lo or hi
            S:warn_once("cfg:" .. name, "config: %s = %s is outside %s..%s (%s); using %s", name, tostring(v), tostring(lo), tostring(hi), why or "limit", tostring(c))
            return c
        end
        return v
    end
    function C.str(name, default, allowed)
        local v = cfg[name]
        if v == nil then return default end
        if type(v) ~= "string" then
            S:warn_once("cfg:" .. name, "config: %s must be text in quotes; using \"%s\"", name, tostring(default))
            return default
        end
        if allowed then
            for _, a in ipairs(allowed) do if a == v:lower() then return a end end
            S:warn_once("cfg:" .. name, "config: %s = \"%s\" is not one of %s; using \"%s\"", name, v, table.concat(allowed, "/"), tostring(default))
            return default
        end
        return v
    end
    function C.key(name, default)
        local v = cfg[name]
        if v == nil then v = default end
        if type(v) ~= "string" then
            S:warn_once("cfg:" .. name, "config: %s must be a key name in quotes (like \"F5\" or \"CTRL+F1\"); using \"%s\"", name, tostring(default))
            v = default
        end
        return v
    end
    return C
end

-- ------------------------------------------------------------------ one-shot key actions (run on the game thread)
local function ps_of(pc)
    local ps = nil
    pcall(function() ps = pc.PlayerState end)
    local ok, v = pcall(function() return ps:IsValid() end)
    if ok and v == true then return ps end
    return nil
end
local function dna_of(pc)
    local ps = ps_of(pc)
    if not ps then return nil end
    local ok, v = pcall(function() return ps.m_iDNA end)
    if ok and type(v) == "number" then return v end
    return nil
end
M.dna_of = dna_of
M.DNA_MAX = 2000000000   -- the game keeps DNA in an int32 (max 2147483647); we stop below it

-- Number of permanently unlocked gameplay tags (weapons, abilities, tiers) in your save data, or nil.
local function unlock_count(pc)
    local ps = ps_of(pc)
    if not ps then return nil end
    local n = nil
    pcall(function() n = ps.m_pUnlocks.m_gameplayTagsUnlocked.GameplayTags:GetArrayNum() end)
    if type(n) == "number" then return n end
    return nil
end
M.unlock_count = unlock_count

-- Add DNA (the Pox Lab currency) through the cheat manager's own AddDNA; read back from your PlayerState.
function M.action_dna(amount, key)
    return { id = "dna", label = "Add DNA", key = key, sc_id = "dna_added", sc_how = "press " .. tostring(key) .. " once (DNA counter goes up)",
        run = function(E, pc, cm)
            local before = dna_of(pc)
            if before == nil then E.S:log("Add DNA: your DNA can't be read here (main menu or loading?)") return end
            local add = amount
            if before + add > M.DNA_MAX then add = M.DNA_MAX - before end     -- never past the game's 32-bit counter
            if add <= 0 then E.S:log("Add DNA: you have %d DNA, the safe maximum (2 billion); nothing added", before) return end
            local ok, err = pcall(function() cm:AddDNA(add) end)
            local after = dna_of(pc)
            if ok and after and after - before == add then
                E.S:log("Add DNA: +%d (now %d)", add, after)
                if E.SC:want("dna_added") then E.SC:pass("dna_added", "m_iDNA %d -> %d (+%d)", before, after, add) end
            elseif ok and after and after > before then
                E.S:log("Add DNA: +%d (now %d; the game capped it)", after - before, after)
                if E.SC:want("dna_added") then E.SC:pass("dna_added", "m_iDNA %d -> %d (capped)", before, after) end
            else
                E.S:log("Add DNA failed: %s (DNA %s -> %s)", ok and "no change" or tostring(err), tostring(before), tostring(after))
                if E.SC:want("dna_added") then E.SC:fail("dna_added", "m_iDNA %s -> %s, call ok=%s", tostring(before), tostring(after), tostring(ok)) end
            end
        end }
end

-- Unlock all weapons / abilities with the cheat manager's own functions (permanent = written to your save).
function M.action_unlock(what, key)
    local fn = (what == "weapons") and "UnlockAllWeapons" or "UnlockAlAbilities"   -- "UnlockAlAbilities": the game's spelling
    local label = (what == "weapons") and "Unlock all weapons" or "Unlock all psychic abilities"
    local id = "unlock_" .. what
    return { id = id, label = label, key = key, sc_id = id, sc_how = "press " .. tostring(key) .. " once",
        run = function(E, pc, cm)
            local before = unlock_count(pc)
            local ok, err = pcall(function() cm[fn](cm, true) end)
            local after = unlock_count(pc)
            if ok and before and after and after > before then
                E.S:log("%s: done (%d new unlocks, %d in total). The game saves it at its next save.", label, after - before, after)
                if E.SC:want(id) then E.SC:pass(id, "unlocked tags %d -> %d", before, after) end
            elseif ok and before and after then
                E.S:log("%s: nothing new to unlock (%d unlocks already).", label, after)
                if E.SC:want(id) then E.SC:pass(id, "unlocked tags %d -> %d (everything was already unlocked)", before, after) end
            else
                E.S:log("%s failed: %s", label, ok and "unlock list not readable" or tostring(err))
                if E.SC:want(id) then E.SC:fail(id, "call ok=%s, unlocked tags %s -> %s", tostring(ok), tostring(before), tostring(after)) end
            end
        end }
end

-- A cheat-manager function without parameters (nuke, call saucer, respawn) or with one number.
function M.action_call(id, label, fn, key, arg)
    return { id = id, label = label, key = key,
        run = function(E, pc, cm)
            local ok, err
            if arg ~= nil then ok, err = pcall(function() cm[fn](cm, arg) end)
            else ok, err = pcall(function() cm[fn](cm) end) end
            E.S:log("%s: %s", label, ok and "done" or ("failed: " .. tostring(err)))
        end }
end

-- The game's own mission-step skip (BFGQuest_Manager:CheatCompleteMissionStep) for a broken mission script.
function M.action_skip_step(key)
    return { id = "skip_step", label = "Skip mission step", key = key,
        run = function(E, pc, cm)
            local qm = nil
            pcall(function() qm = FindFirstOf("BFGQuest_Manager") end)
            local okV, v = pcall(function() return qm:IsValid() end)
            if not (okV and v == true) then E.S:log("Skip mission step: no mission manager here (main menu or loading?)") return end
            local ok, err = pcall(function() qm:CheatCompleteMissionStep() end)
            E.S:log("Skip mission step: %s", ok and "done (the current objective was completed)" or ("failed: " .. tostring(err)))
        end }
end

-- ------------------------------------------------------------------ engine
--[[ spec = {
    mod = "DAHGodMode", version = "1.0.0", core_min = "1.0",
    config = <table from config.lua or {}>,
    switches = { { id = "god", label = "God Mode", cheats = {"invulnerable"} or function(C) ... end,
                   start = <bool>, key = "F5", sc_how = "..." }, ... },        -- toggled states (start state + key)
    jetpack = { start = <bool>, key = "F10" } or nil,                          -- jetpack switch
    actions = { { id = "dna", label = "Add DNA", key = "F4", run = function(E, pc, cm) ... end, sc_how = "..." }, ... },
  } ]]
function M.run(spec)
    local MOD = spec.mod
    local Safe = load_lib("otc_safe")
    if not Safe then print("[" .. MOD .. "] otc_safe.lua missing or broken; mod disabled (copy every file from the download).\n") return nil end
    local S = Safe.new("[" .. MOD .. "]", { verbose = false })
    local unwrap, is_valid = Safe.unwrap, Safe.is_valid

    local SC
    do
        local m = load_lib("otc_selfcheck")
        if m and type(m.new) == "function" then SC = m.new(MOD)
        else SC = setmetatable({}, { __index = function() return function() return false end end }) end
    end
    local Keys = load_lib("otc_keys")
    if not (type(Keys) == "table" and (tonumber(Keys.VERSION) or 0) >= 1.1) then     -- otc_keys 1.1+: Keys.new / start / poll
        Keys = nil
        S:log("WARN otc_keys.lua missing or older than 1.1: hotkeys are off (copy every file from the download)")
    end

    -- Declared before every function that reads them.
    local E = { S = S, SC = SC, mod = MOD }
    local IsQuitting = false
    local PcAddr = nil              -- address of the in-game controller we set the timer on (no UObject kept)
    local ApplyAt = nil             -- os.clock() when the start states are applied
    local NextRecheck = 0
    local Started = false           -- start states applied once in this session (later loads keep the key state)
    local TickLogged = false
    local Kismet = nil
    local Disabled = false
    local Want = {}                 -- switch id -> wanted on/off
    local CheckAt = {}              -- switch id -> os.clock() of the pending read-back
    local JetFails = 0

    local function now() return os.clock() end

    local function disable(why)
        if Disabled then return end
        Disabled = true
        S:log("feature disabled: whole mod - %s (a game update may have changed this)", why)
        SC:fail_open("the mod switched itself off: %s", why)
    end

    local function K()
        if not is_valid(Kismet) then
            Kismet = nil
            local ok, k = pcall(StaticFindObject, KISMET)
            if ok and is_valid(k) then Kismet = k end
        end
        return Kismet
    end

    -- Console variable as a number, or nil when it can't be read.
    local function cvar(name)
        local k = K()
        if not k then return nil end
        local ok, v = pcall(function() return k:GetConsoleVariableIntValue(name) end)
        if ok and type(v) == "number" then return v end
        return nil
    end
    E.cvar = cvar

    local function fullname(o) local s = ""; pcall(function() s = tostring(o:GetFullName()) end) return s or "" end
    local function addr(o) local a = nil; pcall(function() a = o:GetAddress() end) return a end

    local function is_game_pc(pc)
        if not is_valid(pc) then return false end
        local okL, l = pcall(function() return pc:IsLocalPlayerController() end)
        if not (okL and l == true) then return false end
        local n = fullname(pc)
        return n:find(PC_CLASS_HINT, 1, true) ~= nil and n:find("_Menus", 1, true) == nil
    end

    -- The developers' cheat manager on your controller; created (as the game's own class) when it is missing.
    local CMLogged = false
    local function cheat_manager(pc)
        local cm = nil
        pcall(function() cm = unwrap(pc.m_pCheatManager) end)
        if is_valid(cm) then return cm end
        local okG, r = pcall(function() return pc:GetCheatManager() end)
        if okG and is_valid(r) then return r end
        local cls = nil
        pcall(function() cls = unwrap(pc.m_CheatClass) end)
        if not is_valid(cls) then
            local okS, c2 = pcall(StaticFindObject, CHEAT_CLASS)
            cls = (okS and is_valid(c2)) and c2 or nil
        end
        if not cls then S:warn_once("nocmclass", "cheat manager class not found"); return nil end
        local okC, created = pcall(StaticConstructObject, cls, pc)
        if not (okC and is_valid(created)) then S:warn_once("nocm", "could not create the cheat manager (%s)", tostring(created)); return nil end
        pcall(function() pc.m_pCheatManager = created end)        -- the controller keeps it (and the GC sees it)
        local back = nil
        pcall(function() back = unwrap(pc.m_pCheatManager) end)
        if not CMLogged then
            CMLogged = true
            S:log("cheat manager ready (%s)", is_valid(back) and "the game's own class, kept by your controller" or "temporary")
        end
        return created
    end
    E.cheat_manager = cheat_manager

    -- Bring one cheat variable to the wanted state. Returns true when the read-back matches.
    local function set_cheat(pc, def, want)
        local cur = cvar(def.cvar)
        if cur == nil then S:warn_once("cv:" .. def.cvar, "%s can't be read (game update?)", def.cvar); return false end
        if (cur ~= 0) == want then return true end
        local cm = cheat_manager(pc)
        if not cm then return false end
        local ok, err = pcall(function() cm[def.fn](cm) end)
        if not ok then S:warn_once("fn:" .. def.fn, "%s failed: %s", def.fn, tostring(err)); return false end
        local after = cvar(def.cvar)
        return after ~= nil and (after ~= 0) == want
    end
    E.set_cheat = set_cheat

    -- ---------------------------------------------------------------- switches
    local switches = {}
    for _, sw in ipairs(spec.switches or {}) do
        local list = {}
        for _, id in ipairs(sw.cheats) do
            if M.CHEATS[id] then list[#list + 1] = M.CHEATS[id] end
        end
        if #list > 0 then
            switches[#switches + 1] = { id = sw.id, label = sw.label, cheats = list, start = sw.start, key = sw.key, how = sw.sc_how }
        end
    end
    local Jet = spec.jetpack and { id = "jetpack", label = "Unlimited Jetpack", start = spec.jetpack.start, key = spec.jetpack.key } or nil

    local function sw_apply(pc, sw, want, why)
        Want[sw.id] = want
        local ok = true
        for _, def in ipairs(sw.cheats) do
            if not set_cheat(pc, def, want) then ok = false end
        end
        if ok then
            S:log("%s %s (%s)", sw.label, want and "ON" or "OFF", why)
        else
            S:log("%s: could not switch %s (%s) - see the line above", sw.label, want and "on" or "off", why)
        end
        CheckAt[sw.id] = now() + 1.0
        return ok
    end

    -- Read-back of a switch's cheat variables (log/self-check only).
    local function sw_check(sw)
        local want = Want[sw.id]
        if want == nil then return end
        local parts, ok = {}, true
        for _, def in ipairs(sw.cheats) do
            local v = cvar(def.cvar)
            parts[#parts + 1] = def.cvar .. "=" .. tostring(v)
            if v == nil or (v ~= 0) ~= want then ok = false end
        end
        local id = sw.id .. (want and "_on" or "_off")
        if SC:want(id) then SC:check(id, ok, "%s (wanted %s)", table.concat(parts, " "), want and "on" or "off") end
        return ok, table.concat(parts, " ")
    end

    -- ---------------------------------------------------------------- jetpack
    local function jet_component(pc)
        local pawn, jet = nil, nil
        pcall(function() pawn = unwrap(pc.Pawn) end)
        if not is_valid(pawn) then return nil end
        pcall(function() jet = unwrap(pawn.m_pJetpackPilotComponent) end)      -- only Crypto on foot has one (not the saucer)
        if is_valid(jet) then return jet end
        return nil
    end
    local JetLogged = false
    local function jet_tick(pc)
        if not (Jet and Want.jetpack) then return end
        local jet = jet_component(pc)
        if not jet then
            if SC:want("jetpack_full") then SC:wait("jetpack_full", "not on foot (in the saucer, a menu or loading)") end
            return
        end
        local okR, r = pcall(function() return jet:GetCurrentFuelRatio() end)
        if not (okR and type(r) == "number") then
            JetFails = JetFails + 1
            if JetFails == 20 then S:log("Unlimited Jetpack: the fuel can't be read (game update?) - jetpack part off") end
            return
        end
        if r < 0.999 then
            local okA = pcall(function() jet:AddFuel(1000000.0) end)
            local r2 = nil
            pcall(function() r2 = jet:GetCurrentFuelRatio() end)
            if okA and type(r2) == "number" and r2 >= 0.999 then
                if not JetLogged then JetLogged = true; S:log("Unlimited Jetpack: fuel topped up (%.0f%% -> full)", r * 100) end
                if SC:want("jetpack_full") then SC:pass("jetpack_full", "fuel %.0f%% -> %.0f%% after the top-up", r * 100, r2 * 100) end
            elseif SC:want("jetpack_full") then
                SC:check("jetpack_full", false, "fuel %.0f%% stayed below full after AddFuel (now %s)", r * 100, tostring(r2))
            end
        end
    end

    local function jet_set(want, why)
        Want.jetpack = want
        S:log("Unlimited Jetpack %s (%s)", want and "ON" or "OFF", why)
    end

    -- ---------------------------------------------------------------- start states (2 s after you take control)
    local function apply_start(pc)
        local cm = cheat_manager(pc)
        if not cm then disable("the game's cheat manager is not available") return end
        -- First load: the config's start state. Later loads/respawns: whatever your keys left it at.
        -- Only "on" is ever applied here; "off" is never forced (so it can't undo another mod or the game).
        for _, sw in ipairs(switches) do
            local want = Want[sw.id]
            if want == nil then want = sw.start == true end
            if want then sw_apply(pc, sw, true, Started and "re-applied after loading" or "start setting") end
        end
        if Jet and Want.jetpack == nil then
            if Jet.start then jet_set(true, "start setting") else Want.jetpack = false end
        end
        Started = true
    end

    -- ---------------------------------------------------------------- keys
    local KeyList = {}
    local function add_key(keystr, label, fn)
        local key, mods = M.parse_key(keystr)
        if not key then return end
        if not Keys then return end
        if not Keys.unreal_name(key) then
            S:warn_once("key:" .. label, "unknown key name '%s' for %s - no key (use a name like F5, PAGEUP or CTRL+F1)", tostring(keystr), label)
            return
        end
        KeyList[#KeyList + 1] = { name = key, mods = mods, what = label, on_press = function(pc)
            if Disabled or IsQuitting then return end
            if not is_game_pc(pc) then return end
            local ok, err = pcall(fn, pc)
            if not ok then S:warn_once("keyerr:" .. label, "%s key error: %s", label, tostring(err)) end
        end }
    end

    for _, sw in ipairs(switches) do
        local swr = sw
        add_key(sw.key, sw.label, function(pc)
            local want = not (Want[swr.id] == true)
            sw_apply(pc, swr, want, "key " .. tostring(swr.key))
        end)
    end
    if Jet then
        add_key(Jet.key, Jet.label, function(pc) jet_set(not (Want.jetpack == true), "key " .. tostring(Jet.key)) end)
    end
    for _, a in ipairs(spec.actions or {}) do
        local ar = a
        add_key(a.key, a.label, function(pc)
            local cm = cheat_manager(pc)
            if not cm then S:log("%s: the game's cheat manager is not available", ar.label) return end
            ar.run(E, pc, cm)
        end)
    end
    local KeyReader = (Keys and #KeyList > 0) and Keys.new(S, KeyList) or nil
    if KeyReader then KeyReader:set_hooked(true) end     -- polled from our own tick below

    -- ---------------------------------------------------------------- self-check registrations
    local function keytext(k) local key, mods = M.parse_key(k); if not key then return nil end return (mods and (table.concat(mods, "+") .. "+") or "") .. key:upper() end
    for _, sw in ipairs(switches) do
        local kt = keytext(sw.key)
        if sw.start then SC:expect(sw.id .. "_on", "load a save and wait 3 s")
        elseif kt and sw.how then SC:expect(sw.id .. "_on", "press " .. kt .. " once (" .. sw.label .. " on)") end
        if kt and sw.how then SC:expect(sw.id .. "_off", sw.how, { optional = true }) end
    end
    if Jet and Jet.start then SC:expect("jetpack_full", "on foot, fly with the jetpack for 2 s")
    elseif Jet and keytext(Jet.key) then SC:expect("jetpack_full", "press " .. keytext(Jet.key) .. ", then fly with the jetpack for 2 s") end
    for _, a in ipairs(spec.actions or {}) do
        if a.sc_id and a.key and M.parse_key(a.key) then SC:expect(a.sc_id, a.sc_how or ("press " .. tostring(a.key)), { optional = a.sc_optional == true }) end
    end

    -- ---------------------------------------------------------------- the game-thread tick (engine timer -> ForceNetUpdate)
    local function set_timer(pc)
        local k = K()
        if not k then disable("KismetSystemLibrary not found") return false end
        local ok, err = pcall(function() k:K2_SetTimer(pc, TICK_FN, TICK_S, true) end)
        if not ok then disable("K2_SetTimer failed: " .. tostring(err)) return false end
        return true
    end

    local function tick(pc)
        if not TickLogged then
            TickLogged = true
            S:log("game-thread tick running (engine timer every %.2f s); keys: %s", TICK_S, KeyReader and KeyReader:describe() or "none")
        end
        if KeyReader then KeyReader:poll(pc) end
        local t = now()
        if ApplyAt and t >= ApplyAt then ApplyAt = nil; apply_start(pc) end
        if Disabled then return end
        for _, sw in ipairs(switches) do
            if CheckAt[sw.id] and t >= CheckAt[sw.id] then CheckAt[sw.id] = nil; sw_check(sw) end
        end
        if t >= NextRecheck then
            NextRecheck = t + RECHECK_S
            for _, sw in ipairs(switches) do
                if Want[sw.id] == true then
                    local ok, parts = sw_check(sw)
                    if ok == false then S:warn_once("drift:" .. sw.id, "%s: the game changed it back (%s); press %s to set it again", sw.label, tostring(parts), tostring(sw.key)) end
                end
            end
        end
        jet_tick(pc)
    end

    local hooked = S:safe_hook(RESTART, function() end, "ClientRestart", function(ctx)
        if IsQuitting or Disabled then return end
        local pc = unwrap(ctx)
        if not is_game_pc(pc) then return end
        PcAddr = addr(pc)
        if set_timer(pc) then ApplyAt = now() + APPLY_DELAY_S end
    end)
    if not hooked then disable("could not hook PlayerController:ClientRestart") end

    local tickHooked = S:safe_hook(TICK_HOOK, function(ctx)
        if IsQuitting or PcAddr == nil then return end
        local obj = unwrap(ctx)
        if addr(obj) ~= PcAddr then return end              -- only our own timer on your controller
        if not is_game_pc(obj) then return end
        tick(obj)
    end, "tick")
    if not tickHooked then disable("could not hook Actor:ForceNetUpdate") end

    pcall(function()
        RegisterHook(QUIT_HOOK, function() IsQuitting = true; if KeyReader then KeyReader:stop() end end)
    end)

    E.log = function(_, f, ...) S:log(f, ...) end
    return E
end

return M
