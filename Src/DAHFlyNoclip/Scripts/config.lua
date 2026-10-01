-- Fly and Noclip settings. Save this file and restart the game to apply.
-- Keys: a key name in quotes, like "NUM_SEVEN" (Numpad 7), "NUM_EIGHT", "F6", "INS", or a combination like "CTRL+F6".
-- "" switches a key off. Numpad keys need Num Lock on. The game itself binds letters, Space, Tab, Esc, Home, Left Shift,
-- the mouse, 1-4 and Numpad 1-4 (and F11 = fullscreen); our other Destroy All Humans mods use F4, F5, F7-F10,
-- Ctrl+F1/F2/F3, Page Up, Page Down and End. Numpad 5, 7, 8, 9, + and - are free.
return {
    -- Key that switches Fly on (Crypto floats and flies freely; walls still stop you). Press again to walk.
    fly_key = "NUM_SEVEN",
    -- Key that switches Noclip on (fly through walls, floors and buildings). Press again to walk.
    noclip_key = "NUM_EIGHT",

    -- While flying: hold this key to rise. Numpad 5 is free in the game. Not Space: Space is the game's jump/jetpack
    -- key, and holding it while flying starts the jetpack (it burns fuel and pulls Crypto out of flying; seen in game).
    up_key = "NUM_FIVE",
    -- While flying: hold this key to sink. Left Ctrl is not used by the game on foot.
    down_key = "LEFT_CONTROL",

    -- Fly speed as a multiplier of the game's own fly speed, 0.1 to 100. 1 = the game's value (unchanged).
    -- Higher = faster flying; above about 20 you can outrun the world loading in (you fly past empty ground for
    -- a moment). Only changes flying speed; walking and the jetpack are untouched.
    fly_speed = 1.0,

    -- false (default) = the mod sets Crypto's movement mode itself (always works).
    -- true = try the developers' own FlyMode cheat first and use the mod's own way only if it doesn't fly you.
    -- What the dev cheat does exactly is not known, so it is off by default.
    use_game_fly_cheat = false,
}
