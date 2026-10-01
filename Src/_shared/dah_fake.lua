--[[ dah_fake.lua - fake Destroy All Humans! (2020) world for the offline harness (tests only, never shipped).
  Modelled on the real game (UE4SS dump + in-game probes 2026-09-30):
    * in-game controller BP_BFGPlayerController_C (menus: BFGPlayerController_Menus), IsLocalPlayerController,
      m_pCheatManager (empty until created), m_CheatClass, GetCheatManager(), PlayerState (m_iDNA, m_pUnlocks), Pawn
    * KismetSystemLibrary: K2_SetTimer(obj, fn, rate, looping) with FOUR parameters (UE 4.22; 6 = error, like the
      real "UFunction expected 5 parameters"), K2_ClearTimer, GetConsoleVariableIntValue, ExecuteConsoleCommand
      (does NOT change cheat variables, like the shipping game), QuitGame
    * the engine fires our looping timer by calling Actor:ForceNetUpdate on its object (the hook) on the game thread
    * UBFGCheatManager: Toggle* flip the Cheat.* variables; AddDNA; UnlockAllWeapons/UnlockAlAbilities(bPermanent);
      NukeEnemies, CallUFO, RespawnPlayer (calls recorded)
    * Crypto on foot (BP_CharacterPlayer_C) has m_pJetpackPilotComponent (fuel 0..100, AddFuel clamps);
      the saucer (BP_PlayerUFO_C) has none
]]
local F = {}
F.RESTART = "/Script/Engine.PlayerController:ClientRestart"
F.TICK = "/Script/Engine.Actor:ForceNetUpdate"
F.QUIT = "/Script/Engine.KismetSystemLibrary:QuitGame"

-- opts: menus (menu controller), no_cheat_class, ufo (start in the saucer), dna (start DNA), cvars (start values),
--       toggle_broken (toggles do nothing), no_timer_api, unlocks (start count), weapons_to_unlock, abilities_to_unlock
function F.build(H, opts)
    opts = opts or {}
    local W = { calls = {}, timers = {}, cvars = {} }
    for _, n in ipairs({ "Cheat.Invulnerability", "Cheat.Immortality", "Cheat.InfiniteAmmo", "Cheat.InfiniteCharge",
                         "Cheat.InfiniteConcentration", "Cheat.Invisibility", "Cheat.ToggleHUD" }) do W.cvars[n] = 0 end
    for k, v in pairs(opts.cvars or {}) do W.cvars[k] = v end
    local function call(n) W.calls[n] = (W.calls[n] or 0) + 1 end

    local kfields = {
        GetConsoleVariableIntValue = function(_, name)
            local v = W.cvars[type(name) == "table" and name.s or name]
            return v or 0
        end,
        ExecuteConsoleCommand = function() call("ExecuteConsoleCommand") end,
        K2_ClearTimer = function(_, obj, fn) for _, t in ipairs(W.timers) do if t.obj == obj and t.fn == fn then t.dead = true end end end,
        QuitGame = function() end,
    }
    if not opts.no_timer_api then
        kfields.K2_SetTimer = function(self, obj, fn, rate, loop, extra1)
            if extra1 ~= nil then error("[UFunction::setup_metamethods -> __call] UFunction expected 5 parameters, received 6") end
            call("K2_SetTimer")
            for _, t in ipairs(W.timers) do if t.obj == obj and t.fn == fn then t.dead = true end end   -- same object+function: replaced
            W.timers[#W.timers + 1] = { obj = obj, fn = fn, rate = rate, loop = loop, next = H.now + rate }
        end
    end
    H.statics["/Script/Engine.Default__KismetSystemLibrary"] = H.obj("Default__KismetSystemLibrary", kfields,
        { persistent = true, find = false, path = "/Script/Engine.Default__KismetSystemLibrary" })

    W.cm_class = H.class("BFGCheatManager", nil, "/Script/BFGCore.BFGCheatManager")
    W.unlocks_arr, W.unlocks_list = H.array({})
    for i = 1, (opts.unlocks or 3) do W.unlocks_list[#W.unlocks_list + 1] = "Tag" .. i end
    W.unlocks = H.obj("BFGPlayerState_Unlocks_0", { m_gameplayTagsUnlocked = { GameplayTags = W.unlocks_arr } })

    local function flip(cv) return function() call(cv); if not opts.toggle_broken then W.cvars[cv] = (W.cvars[cv] ~= 0) and 0 or 1 end end end
    local function new_cm(outer)
        W.cm_made = (W.cm_made or 0) + 1
        return H.obj("BFGCheatManager_" .. W.cm_made, {
            ToggleInvulnerability = flip("Cheat.Invulnerability"), ToggleImmortality = flip("Cheat.Immortality"),
            ToggleInfiniteAmmo = flip("Cheat.InfiniteAmmo"), ToggleInfiniteCharge = flip("Cheat.InfiniteCharge"),
            ToggleInfiniteConcentration = flip("Cheat.InfiniteConcentration"), ToggleInvisibility = flip("Cheat.Invisibility"),
            ToggleHUD = flip("Cheat.ToggleHUD"),
            AddDNA = function(_, n) call("AddDNA"); W.ps_fields().m_iDNA = W.ps_fields().m_iDNA + n end,
            UnlockAllWeapons = function(_, perm) call("UnlockAllWeapons"); W.last_perm = perm
                for i = 1, (opts.weapons_to_unlock or 12) do W.unlocks_list[#W.unlocks_list + 1] = "W" .. i .. "_" .. (W.calls.UnlockAllWeapons) end
                opts.weapons_to_unlock = 0 end,
            UnlockAlAbilities = function(_, perm) call("UnlockAlAbilities"); W.last_perm = perm
                for i = 1, (opts.abilities_to_unlock or 10) do W.unlocks_list[#W.unlocks_list + 1] = "A" .. i end
                opts.abilities_to_unlock = 0 end,
            NukeEnemies = function() call("NukeEnemies") end,
            CallUFO = function() call("CallUFO") end,
            RespawnPlayer = function() call("RespawnPlayer") end,
        }, { class = W.cm_class, outer = outer })
    end
    H.on_construct = function(cls, outer)
        call("StaticConstructObject")
        if cls == W.cm_class then return new_cm(outer) end
        return H.obj("Constructed", {}, { class = cls, outer = outer })
    end

    W.jet_state = { fuel = 100, max = 100 }
    function W.new_jet()
        local s = W.jet_state
        return H.obj("Jetpack_Pilot_" .. H.world_gen, {
            GetCurrentFuelRatio = function() return s.fuel / s.max end,
            GetCurrentFuel = function() return s.fuel end,
            AddFuel = function(_, n) call("AddFuel"); s.fuel = math.min(s.max, s.fuel + n) end,
            ConsumeFuel = function(_, n) s.fuel = math.max(0, s.fuel - n) end,
        }, { class = H.class("BFGActorComponent_JetpackPilot", nil, "/Script/BFGCore.BFGActorComponent_JetpackPilot") })
    end

    function W.make_world(H2)
        local ps_fields = { m_iDNA = opts.dna or 250, m_pUnlocks = W.unlocks }
        W.ps_fields = function() return ps_fields end
        W.ps = H2.obj("BP_PlayerState_C_" .. H2.world_gen, ps_fields)
        local pawn_fields = {}
        local pawn_class = "BP_CharacterPlayer_C"
        if opts.ufo then pawn_class = "BP_PlayerUFO_C" else W.jet = W.new_jet(); pawn_fields.m_pJetpackPilotComponent = W.jet end
        local pcf = {
            PlayerState = W.ps,
            m_CheatClass = (not opts.no_cheat_class) and W.cm_class or H2.invalid,
            m_pCheatManager = H2.invalid,
        }
        pcf.GetCheatManager = function(self) local cm = H2.peek(W.pc, "m_pCheatManager"); return cm or H2.invalid end
        local w = H2.player_world({ pc_class = opts.menus and "BFGPlayerController_Menus" or "BP_BFGPlayerController_C",
                                    pawn_class = pawn_class, pc_fields = pcf, pawn_fields = pawn_fields })
        W.pc, W.pawn, W.world = w.pc, w.pawn, w.world
        return w
    end
    W.make_world(H)

    -- the engine: due looping timers call ForceNetUpdate on their object (= our hook), on the game thread
    H.on_frame(function()
        if H.quit_state == "torn_down" then return end
        for _, t in ipairs(W.timers) do
            if not t.dead and H.now + 1e-9 >= t.next then
                if not H.is_alive(t.obj) then t.dead = true
                else
                    t.next = H.now + t.rate
                    if not t.loop then t.dead = true end
                    H.fire_hook(F.TICK, t.obj)
                end
            end
        end
    end)

    function W.spawn(H2) H2.fire_hook(F.RESTART, W.pc, W.pawn) end
    -- move to Crypto on foot / into the saucer (same controller; ClientRestart fires like in the game)
    function W.to_foot(H2)
        W.jet = W.new_jet()
        W.pawn = H2.obj("BP_CharacterPlayer_C_x", { m_pJetpackPilotComponent = W.jet }, { class = "BP_CharacterPlayer_C" })
        H2.poke(W.pc, "Pawn", W.pawn); W.spawn(H2)
    end
    function W.to_ufo(H2)
        W.pawn = H2.obj("BP_PlayerUFO_C_x", {}, { class = "BP_PlayerUFO_C" })
        H2.poke(W.pc, "Pawn", W.pawn); W.spawn(H2)
    end
    function W.press(H2, key, ctrl)
        if ctrl then H2.key_down("LeftControl", true) end
        H2.key_down(key, true); H2.run(0.2); H2.key_down(key, false); H2.run(0.2)
        if ctrl then H2.key_down("LeftControl", false) end
    end
    function W.active_timers() local n = 0; for _, t in ipairs(W.timers) do if not t.dead then n = n + 1 end end return n end
    return W
end

return F
