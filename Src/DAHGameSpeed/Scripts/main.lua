-- =======================================================================
-- Destroy All Humans! (2020): Game Speed - Slow Motion and Fast Forward v1.0.0
-- Target: DH-Win64-Shipping (Unreal Engine 4.22, Steam build 6184983)
-- Framework: UE4SS v3.0.1 experimental (commit e3ba1016, 2026-09-29; our DAH mods are tested on it. Build f08dfdf runs the mods too but crashes when the game closes)
-- UE4SS-settings.ini: nothing required.
--
-- What it does: Numpad + = next faster speed, Numpad - = next slower speed, Numpad 9 = normal speed (x1).
-- Steps x0.1 ... x5 by default (config.lua: any steps from x0.01 to x20). Starts at x1 = the game's own speed.
-- How: Unreal multiplies three time factors on the level's WorldSettings: TimeDilation (the game's own: its
-- UBFGTimeDilationManager drives it for its slow-motion moments, e.g. the weapon wheel and the Temporal Distortionator
-- upgrade), MatineeTimeDilation (cutscene slow-mo tracks) and DemoPlayTimeDilation (only used by replay playback,
-- which this single-player game never runs). The mod sets DemoPlayTimeDilation, so it never fights the game's own
-- slow motion: both multiply. Every change is read back, and once per change the mod MEASURES the result: the game
-- clock (GameplayStatics:GetUnpausedTimeSeconds) against the real clock (GetRealTimeSeconds) over 1.5 s. If the
-- game clock doesn't follow, the mod switches to the engine's GameplayStatics:SetGlobalTimeDilation (the usual way;
-- the game's own slow-motion moments then reset it) and measures again.
-- A new level has new WorldSettings: the speed is applied again 2 s after you take control, and checked every 2 s.
-- Keys stay responsive at any speed: the shared engine timer of our DAH mods (otc_dah.lua: your controller's
-- Actor:ForceNetUpdate every 0.05 s of GAME time) is set to 0.05 x speed, so it still fires every 0.05 s of real time.
-- Threading: everything runs in game-thread hooks on that timer call and in the engine's key actions.
-- Nothing is saved (the factor is a transient engine value). Single-player game: no online mode to protect.
-- =======================================================================
-- Self-checks (registered below; listed here for our test tooling sheet):
-- SC:expect("speed_faster", "press ADD once (faster)")
-- SC:expect("speed_slower", "press SUBTRACT once (slower)")
-- SC:expect("speed_normal", "press NUM_NINE once (normal speed)")
-- SC:expect("speed_clock", "choose any speed other than x1 and wait 2 s")
local ModName = "DAHGameSpeed"
local ModVersion = "1.0.0"
-- Lua garbage collector in generational mode (as in every DAH mod since 1.0.1): the 20-per-second tick leaves short-lived
-- objects that generational GC frees in small steps. Lua 5.4 only; touches no game object.
pcall(collectgarbage, "generational")
local CORE_MIN = 1.0

local function script_dir()
    local src = debug and debug.getinfo and debug.getinfo(1, "S").source or ""
    return (src:gsub("^@", "")):match("^(.*[/\\])") or ""
end
local function load_lib(name)
    local ok, m = pcall(require, name)
    if ok and type(m) == "table" then return m end
    local ok2, m2 = pcall(dofile, script_dir() .. name .. ".lua")
    if ok2 and type(m2) == "table" then return m2 end
    return nil
end
local Core = load_lib("otc_dah")
if not (type(Core) == "table" and type(Core.run) == "function" and (tonumber(Core.VERSION) or 0) >= CORE_MIN) then
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

-- ------------------------------------------------------------------ settings (bad values -> default + one log line)
local MIN_SPEED, MAX_SPEED = 0.01, 20      -- 20 = Unreal's own MaxGlobalTimeDilation default; 0.01 = 100x slower
local LIMIT_WHY = "x20 is Unreal's own upper limit for game speed; below x0.01 the game is practically frozen"
local Notes = {}
local function cfgv(name, default)
    local v = config[name]
    if v == nil then return default end
    return v
end
local function key(name, default)
    local v = cfgv(name, default)
    if type(v) ~= "string" then Notes[#Notes + 1] = string.format("config: %s must be a key name in quotes; using \"%s\"", name, default); return default end
    return v
end
local function clamp_speed(name, v)
    if type(v) ~= "number" or v ~= v then return nil end
    if v < MIN_SPEED or v > MAX_SPEED then
        local c = v < MIN_SPEED and MIN_SPEED or MAX_SPEED
        Notes[#Notes + 1] = string.format("config: %s = %s is outside %s..%s (%s); using %s", name, tostring(v), tostring(MIN_SPEED), tostring(MAX_SPEED), LIMIT_WHY, tostring(c))
        return c
    end
    return v
end

local FasterKey = key("faster_key", "ADD")
local SlowerKey = key("slower_key", "SUBTRACT")
local NormalKey = key("normal_key", "NUM_NINE")
local DEFAULT_STEPS = { 0.1, 0.25, 0.5, 0.75, 1.0, 1.5, 2.0, 3.0, 5.0 }
local Steps = {}
do
    local raw = cfgv("speeds", DEFAULT_STEPS)
    if type(raw) ~= "table" or #raw == 0 then
        Notes[#Notes + 1] = "config: speeds must be a list of numbers like { 0.5, 1.0, 2.0 }; using the default steps"
        raw = DEFAULT_STEPS
    end
    local seen, bad = {}, 0
    for i, v in ipairs(raw) do
        local c = clamp_speed("speeds[" .. i .. "]", v)
        if c == nil then bad = bad + 1
        else
            local k = string.format("%.4f", c)
            if not seen[k] then seen[k] = true; Steps[#Steps + 1] = c end
        end
    end
    if bad > 0 then Notes[#Notes + 1] = string.format("config: %d entr%s in speeds %s not a number; skipped", bad, bad == 1 and "y" or "ies", bad == 1 and "is" or "are") end
    if not seen[string.format("%.4f", 1.0)] then Steps[#Steps + 1] = 1.0 end
    table.sort(Steps)
end
local StartSpeed = cfgv("start_speed", 1.0)
if type(StartSpeed) ~= "number" or StartSpeed ~= StartSpeed then
    Notes[#Notes + 1] = "config: start_speed must be a number; using 1"
    StartSpeed = 1.0
end
StartSpeed = clamp_speed("start_speed", StartSpeed)

local function fmt_speed(s)
    local t = string.format("%.2f", s):gsub("0+$", ""):gsub("%.$", "")
    return "x" .. t
end
local StepText = {}
for _, s in ipairs(Steps) do StepText[#StepText + 1] = fmt_speed(s) end

print(string.format("[%s] Initializing v%s (faster %s, slower %s, normal %s; steps %s; start %s).\n", ModName, ModVersion,
    FasterKey ~= "" and FasterKey or "no key", SlowerKey ~= "" and SlowerKey or "no key", NormalKey ~= "" and NormalKey or "no key",
    table.concat(StepText, " "), fmt_speed(StartSpeed)))

-- ------------------------------------------------------------------ game facts (UE4SS dump 2026-09-30, DAH 1 build 6184983)
local GS_PATH = "/Script/Engine.Default__GameplayStatics"
local KISMET = "/Script/Engine.Default__KismetSystemLibrary"
local TICK_FN = "ForceNetUpdate"
local TICK_S = Core.TICK_S or 0.05
local EPS = 0.001
local CLOCK_TOLERANCE = 0.15          -- measured game/real clock ratio may be 15 % off (frame timing)
local MEASURE_S = 1.5
local RECHECK_S = 2.0
local APPLY_DELAY_S = 2.0

local E, S, SC
local unwrap, is_valid

-- state (declared before every function that reads it)
local Speed = 1.0                     -- wanted speed
local Method = "factor"               -- "factor" (DemoPlayTimeDilation) or "global" (SetGlobalTimeDilation)
local Started = false                 -- start_speed applied once
local PcAddr = nil
local ApplyAt = nil
local NextRecheck = 0
local NeedTimer = false               -- the shared engine timer was (re)set by a ClientRestart: set our rate again
local TimerRate = TICK_S
local Meas = nil
local GS, Kismet = nil, nil
local IsQuitting = false

local function now() return os.clock() end
local function addr(o) local a = nil; pcall(function() a = o:GetAddress() end) return a end
local function fullname(o) local s = ""; pcall(function() s = tostring(o:GetFullName()) end) return s or "" end

local function is_game_pc(pc)
    if not is_valid(pc) then return false end
    local okL, l = pcall(function() return pc:IsLocalPlayerController() end)
    if not (okL and l == true) then return false end
    local n = fullname(pc)
    return n:find("BFGPlayerController", 1, true) ~= nil and n:find("_Menus", 1, true) == nil
end

local function gs()
    if not is_valid(GS) then
        GS = nil
        local ok, o = pcall(StaticFindObject, GS_PATH)
        if ok and is_valid(o) then GS = o end
    end
    return GS
end
local function kismet()
    if not is_valid(Kismet) then
        Kismet = nil
        local ok, o = pcall(StaticFindObject, KISMET)
        if ok and is_valid(o) then Kismet = o end
    end
    return Kismet
end

local function world_settings(pc)
    local w, ws = nil, nil
    pcall(function() w = unwrap(pc:GetWorld()) end)
    if not is_valid(w) then return nil end
    pcall(function() ws = unwrap(w:K2_GetWorldSettings()) end)
    if is_valid(ws) then return ws end
    return nil
end

local function numprop(o, name)
    local ok, v = pcall(function() return o[name] end)
    if ok and type(v) == "number" then return v end
    return nil
end

-- The value that carries our speed right now (factor or the global time dilation), or nil.
local function current(pc)
    if Method == "factor" then
        local ws = world_settings(pc)
        return ws and numprop(ws, "DemoPlayTimeDilation")
    end
    local g = gs()
    if not g then return nil end
    local ok, v = pcall(function() return g:GetGlobalTimeDilation(pc) end)
    if ok and type(v) == "number" then return v end
    return nil
end

-- Write the wanted speed. Returns ok, read-back.
local function write(pc, s)
    if Method == "factor" then
        local ws = world_settings(pc)
        if not ws then return false, nil, "the level's WorldSettings were not found" end
        local okW, err = pcall(function() ws.DemoPlayTimeDilation = s end)
        local rb = numprop(ws, "DemoPlayTimeDilation")
        if okW and rb and math.abs(rb - s) < EPS then return true, rb end
        return false, rb, okW and "read back " .. tostring(rb) or tostring(err)
    end
    local g = gs()
    if not g then return false, nil, "GameplayStatics not found" end
    local okS, err = pcall(function() g:SetGlobalTimeDilation(pc, s) end)
    local rb = current(pc)
    if okS and rb and math.abs(rb - s) < EPS then return true, rb end
    return false, rb, okS and ("read back " .. tostring(rb) .. " (the engine clamps to the level's MinGlobalTimeDilation..MaxGlobalTimeDilation)") or tostring(err)
end

-- Keep the shared engine timer at 0.05 s of REAL time (keys and every DAH mod stay responsive at any speed).
local function set_timer_rate(pc, force)
    local rate = TICK_S * Speed
    if not force and math.abs(rate - TimerRate) < 1e-6 then return end
    local k = kismet()
    if not k then return end
    local ok, err = pcall(function() k:K2_SetTimer(pc, TICK_FN, rate, true) end)
    if ok then TimerRate = rate else S:warn_once("timer", "could not adjust the key timer (%s); keys may react slowly at low speeds", tostring(err)) end
end

local function start_measure()
    if math.abs(Speed - 1.0) < EPS then Meas = nil return end
    Meas = { at = now() + 0.3, tries = 0, speed = Speed }
end

local function method_text() return Method == "factor" and "extra time factor" or "global time dilation" end

-- Set a new wanted speed (key, start setting) and apply it now.
local function set_speed(pc, s, why, sc_id)
    Speed = s
    local ok, rb, err = write(pc, s)
    if ok then
        S:log("Game speed %s (%s; %s %.2f)", fmt_speed(s), why, method_text(), rb)
    else
        S:log("Game speed %s (%s): could not be applied - %s", fmt_speed(s), why, tostring(err))
    end
    if sc_id and SC:want(sc_id) then SC:check(sc_id, ok, "%s %s (wanted %s)", method_text(), tostring(rb), fmt_speed(s)) end
    set_timer_rate(pc, false)
    start_measure()
end

-- ------------------------------------------------------------------ keys (run by the engine on the game thread)
local function step(dir)
    if dir > 0 then
        for _, v in ipairs(Steps) do if v > Speed + EPS then return v end end
    else
        for i = #Steps, 1, -1 do if Steps[i] < Speed - EPS then return Steps[i] end end
    end
    return nil
end

local function on_faster(pc)
    local s = step(1)
    if not s then S:log("Game speed: already at the fastest step (%s)", fmt_speed(Speed)) return end
    set_speed(pc, s, "key " .. FasterKey, "speed_faster")
end
local function on_slower(pc)
    local s = step(-1)
    if not s then S:log("Game speed: already at the slowest step (%s)", fmt_speed(Speed)) return end
    set_speed(pc, s, "key " .. SlowerKey, "speed_slower")
end
local function on_normal(pc)
    set_speed(pc, 1.0, "key " .. NormalKey, "speed_normal")
end

-- ------------------------------------------------------------------ measurement: the game clock against the real clock
local function measure(pc, t)
    if Meas.speed ~= Speed then Meas = nil return end
    local g, ws = gs(), world_settings(pc)
    local r, u, td, md
    if g and ws then
        pcall(function() r = g:GetRealTimeSeconds(pc) end)
        pcall(function() u = g:GetUnpausedTimeSeconds(pc) end)
        td, md = numprop(ws, "TimeDilation"), numprop(ws, "MatineeTimeDilation")
    end
    if type(r) ~= "number" or type(u) ~= "number" or not td or not md then
        Meas.tries = Meas.tries + 1
        if Meas.tries > 6 then S:warn_once("measure", "Game speed: the game clock can't be read (game update?) - speed set, not measured"); Meas = nil
        else Meas.at = t + 0.5 end
        return
    end
    local cur = current(pc)
    local wsa = addr(ws)
    if not Meas.r0 then
        Meas.r0, Meas.u0, Meas.td, Meas.md, Meas.ws = r, u, td, md, wsa
        Meas.ok0 = cur ~= nil and math.abs(cur - Speed) < EPS
        Meas.at = t + MEASURE_S
        return
    end
    local dr, du = r - Meas.r0, u - Meas.u0
    local same = wsa == Meas.ws
    if Method == "factor" then same = same and Meas.ok0 and cur ~= nil and math.abs(cur - Speed) < EPS end   -- (global: a reset = FAIL below)
    if not same or dr < 1.0 or du < 0 or math.abs(td - Meas.td) > EPS or math.abs(md - Meas.md) > EPS then
        -- too short, a new level, our value was reset (re-applied by the tick), or the game's own slow motion changed
        -- meanwhile: measure again
        Meas.tries = Meas.tries + 1
        Meas.r0 = nil
        if Meas.tries > 6 then
            S:log("Game speed %s: the game kept changing its own time while measuring; not confirmed", fmt_speed(Speed))
            if SC:want("speed_clock") then SC:wait("speed_clock", "the game's own slow motion kept changing while measuring") end
            Meas = nil
        else Meas.at = t + 0.3 end
        return
    end
    local ratio = du / dr
    local expected = (Method == "factor") and Speed * td * md or td * md
    local ok = math.abs(ratio - expected) <= CLOCK_TOLERANCE * expected
    if Method == "global" and math.abs(td - Speed) > EPS then ok = false end
    if ok then
        S:log("Game speed %s confirmed: the game clock ran x%.2f against the real clock over %.1f s (%s)", fmt_speed(Speed), ratio, dr, method_text())
        if SC:want("speed_clock") then
            SC:pass("speed_clock", "game clock x%.2f vs real clock (wanted %s, %s, %s)", ratio, fmt_speed(Speed),
                Method == "factor" and string.format("game's own time x%.2f", td * md) or string.format("TimeDilation %.2f", td), method_text())
        end
        Meas = nil
    elseif Method == "factor" then
        S:log("Game speed %s: the game clock did not follow the extra time factor (ran x%.2f, wanted x%.2f) - switching to the engine's global time dilation",
            fmt_speed(Speed), ratio, expected)
        local ws2 = world_settings(pc)
        if ws2 then pcall(function() ws2.DemoPlayTimeDilation = 1.0 end) end
        Method = "global"
        set_speed(pc, Speed, "switched method", nil)
    else
        S:log("Game speed %s: the game clock runs x%.2f instead of %s (the game resets its time dilation to x%.2f; game update?)", fmt_speed(Speed), ratio, fmt_speed(Speed), td)
        if SC:want("speed_clock") then SC:fail("speed_clock", "game clock x%.2f vs real clock, wanted %s (%s; TimeDilation %.2f)", ratio, fmt_speed(Speed), method_text(), td) end
        Meas = nil
    end
end

-- ------------------------------------------------------------------ the tick (engine timer -> ForceNetUpdate, game thread)
local function tick(pc)
    if IsQuitting then return end
    local t = now()
    if NeedTimer then
        NeedTimer = false
        TimerRate = TICK_S                          -- every DAH mod set the timer back to 0.05 s at ClientRestart
        set_timer_rate(pc, false)
    end
    if ApplyAt and t >= ApplyAt then
        ApplyAt = nil
        if not Started then
            Started = true
            if math.abs(StartSpeed - 1.0) > EPS then set_speed(pc, StartSpeed, "start setting", nil) end
        elseif math.abs(Speed - 1.0) > EPS then
            local cur = current(pc)
            if not cur or math.abs(cur - Speed) > EPS then set_speed(pc, Speed, "re-applied after loading", nil) end
        end
        NextRecheck = t + RECHECK_S
    end
    if ApplyAt == nil and Method == "factor" and math.abs(Speed - 1.0) > EPS and t >= NextRecheck then
        NextRecheck = t + RECHECK_S
        local cur = current(pc)
        if cur and math.abs(cur - Speed) > EPS then set_speed(pc, Speed, "re-applied: a new area loaded", nil) end
    end
    if Meas and t >= Meas.at then measure(pc, t) end
end

-- ------------------------------------------------------------------ engine + hooks (registration only at load)
E = Core.run({
    mod = ModName, version = ModVersion,
    actions = {
        { id = "faster", label = "Faster", key = FasterKey, run = function(_, pc) on_faster(pc) end },
        { id = "slower", label = "Slower", key = SlowerKey, run = function(_, pc) on_slower(pc) end },
        { id = "normal", label = "Normal speed", key = NormalKey, run = function(_, pc) on_normal(pc) end },
    },
})
if not E then return end
S, SC = E.S, E.SC
local Safe = load_lib("otc_safe")
unwrap = (Safe and Safe.unwrap) or function(v) return v end
is_valid = (Safe and Safe.is_valid) or function(o) local ok, v = pcall(function() return o:IsValid() end) return ok and v == true end
for _, n in ipairs(Notes) do S:log("WARN %s", n) end

local function keytext(k) local kk, mods = Core.parse_key(k); if not kk then return nil end return (mods and (table.concat(mods, "+") .. "+") or "") .. kk:upper() end
local FKT, SKT, NKT = keytext(FasterKey), keytext(SlowerKey), keytext(NormalKey)
if FKT then SC:expect("speed_faster", "press " .. FKT .. " once (faster)") end
if SKT then SC:expect("speed_slower", "press " .. SKT .. " once (slower)") end
if NKT then SC:expect("speed_normal", "press " .. NKT .. " once (normal speed)") end
if FKT or SKT or math.abs(StartSpeed - 1.0) > EPS then SC:expect("speed_clock", "choose any speed other than x1 and wait 2 s") end

S:safe_hook(Core.RESTART, function() end, "speed restart", function(ctx)
    if IsQuitting then return end
    local pc = unwrap(ctx)
    if not is_game_pc(pc) then return end
    PcAddr = addr(pc)
    NeedTimer = true
    ApplyAt = now() + APPLY_DELAY_S
end)
S:safe_hook(Core.TICK_HOOK, function(ctx)
    if IsQuitting or PcAddr == nil then return end
    local obj = unwrap(ctx)
    if addr(obj) ~= PcAddr then return end
    if not is_game_pc(obj) then return end
    tick(obj)
end, "speed tick")
pcall(function() RegisterHook("/Script/Engine.KismetSystemLibrary:QuitGame", function() IsQuitting = true end) end)
