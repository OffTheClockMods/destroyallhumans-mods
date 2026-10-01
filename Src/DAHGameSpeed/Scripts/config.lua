-- Game Speed settings. Save this file and restart the game to apply.
-- Keys: a key name in quotes, like "ADD" (Numpad +), "SUBTRACT" (Numpad -), "NUM_NINE" (Numpad 9), or a combination
-- like "CTRL+F6". "" switches a key off. Numpad keys need Num Lock on. The game itself binds letters, Space, Tab, Esc,
-- Home, Left Shift, the mouse, 1-4 and Numpad 1-4 (and F11 = fullscreen); our other Destroy All Humans mods use F4, F5,
-- F7-F10, Ctrl+F1/F2/F3, Page Up, Page Down and End, and Fly and Noclip uses Numpad 7 and 8.
return {
    -- Key for the next faster speed step.
    faster_key = "ADD",
    -- Key for the next slower speed step.
    slower_key = "SUBTRACT",
    -- Key that goes straight back to normal speed (x1).
    normal_key = "NUM_NINE",

    -- The speed steps the two keys walk through, as multipliers of normal game speed (1 = normal).
    -- Each step 0.01 to 20. Below 1 = slow motion, above 1 = fast forward. x1 is always added if missing.
    -- Above about x2 physics objects (ragdolls, debris, thrown cars) fall behind the rest of the game: the game
    -- limits each physics step, so they move slower than everything else. At high speeds fast objects move in
    -- bigger steps per frame, so a shot can occasionally miss. 20 is Unreal's own upper limit for game speed.
    speeds = { 0.1, 0.25, 0.5, 0.75, 1.0, 1.5, 2.0, 3.0, 5.0 },

    -- Speed when you load a save. 1 = normal (the mod changes nothing until you press a key).
    -- Any other value is applied 2 seconds after you take control, every time you load.
    start_speed = 1.0,
}
