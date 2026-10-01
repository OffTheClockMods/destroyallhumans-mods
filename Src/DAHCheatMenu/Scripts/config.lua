-- Destroy All Humans Cheat Menu settings. Save this file and restart the game to apply.
-- Keys: a key name in quotes, like "F5", "PAGEUP", "END", or a combination like "CTRL+F3" or "SHIFT+F7".
-- "" switches a key off. The game itself uses no F-keys except F11 (fullscreen) and F12 is Steam's screenshot key,
-- so don't use those two. Numpad 1-4 and Home are used by the game too.
return {
    -- God Mode at start: true = on as soon as you load a save. false = off until you press the key.
    god_mode = false,
    -- Key that switches God Mode off and on.
    god_mode_key = "F5",
    -- "invulnerable" = nothing hurts you at all. "immortal" = you still take hits and lose health, but you can't die (closer to normal play).
    god_mode_style = "invulnerable",

    -- Infinite Ammo and Charge at start (one key switches both): true = on when you load a save.
    weapons = false,
    -- Key that switches Infinite Ammo and Charge off and on.
    weapons_key = "F7",
    -- true = ammo weapons (Disintegrator Ray, Ion Detonator, Anal Probe, saucer ammo weapons) never run out.
    weapons_ammo = true,
    -- true = energy weapons (Zap-O-Matic, the saucer's death ray) never run dry.
    weapons_charge = true,

    -- Unlimited Concentration at start: Psychokinesis, Hypnotize and the Holobob disguise never drain.
    concentration = false,
    -- Key that switches Unlimited Concentration off and on.
    concentration_key = "F8",

    -- Invisibility at start: humans and agents can't see you.
    invisibility = false,
    -- Key that switches Invisibility off and on.
    invisibility_key = "F9",

    -- Unlimited Jetpack at start: the jetpack fuel is topped up while you fly.
    jetpack = false,
    -- Key that switches Unlimited Jetpack off and on.
    jetpack_key = "F10",

    -- Key that adds DNA (the Pox Lab upgrade currency).
    dna_key = "F4",
    -- DNA added per press, 1 to 10000000. DNA is saved with your game, so what you add is kept.
    dna_amount = 1000,

    -- Extra: destroys enemies and humans around you (about 20 m on foot, 30 m in the saucer).
    nuke_key = "CTRL+F3",
    -- Extra: calls your flying saucer to you.
    call_saucer_key = "PAGEUP",
    -- Extra: unstuck - respawns you, for when you fall through the world or get stuck.
    unstuck_key = "END",
    -- Extra: hides the whole HUD for screenshots; press again to show it.
    hide_hud_key = "PAGEDOWN",
    -- Extra: completes the current mission step. Only for a broken mission (an objective that never finishes): it can skip story moments, so it has no key by default. Set a key like "INSERT" to use it.
    skip_mission_step_key = "",
}
