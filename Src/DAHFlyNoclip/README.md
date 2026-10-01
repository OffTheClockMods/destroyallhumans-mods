# Fly Mode and Noclip (Destroy All Humans! 2020)

Fly mode and noclip for Crypto in Destroy All Humans! (2020 remake): fly freely over Rockwell, Santa Modesta and the rest, or fly straight through walls, floors and buildings.
Also known as: fly cheat, ghost mode, no clip, free flight.

## What it does
- Numpad 7 = Fly: Crypto floats and flies wherever you steer; walls and the ground still stop you. Press Numpad 7 again to walk
- Numpad 8 = Noclip: the same, but you pass through walls, floors, rocks and buildings. Press Numpad 8 again to walk
- Numpad 7 and Numpad 8 switch between Fly and Noclip directly
- While flying: hold Numpad 5 to rise and Left Ctrl to sink. Let go of every key and Crypto stops in mid-air
- Optional fly speed multiplier (`fly_speed`, default 1 = the game's own fly speed)
- On foot as Crypto only (also in the Holobob disguise). In the saucer the keys do nothing and the log says why
- Going back to walking: collision on, the game's own values back, Crypto drops and lands normally
- Every change is read back from the game and written to the UE4SS log

## Keys
- Numpad 7: Fly on/off
- Numpad 8: Noclip on/off
- Numpad 5 (hold): rise while flying. Left Ctrl (hold): sink while flying
- Numpad keys need Num Lock on. The game uses no Numpad key except Numpad 1-4. All keys can be changed in `Scripts\config.lua`

## Config
Edit `DAHFlyNoclip\Scripts\config.lua`, save, restart the game:
- `fly_key` (default `"NUM_SEVEN"`), `noclip_key` (default `"NUM_EIGHT"`): the two switches. `""` = no key
- `up_key` (default `"NUM_FIVE"`), `down_key` (default `"LEFT_CONTROL"`): hold to rise / sink while flying
- `fly_speed` (default `1.0`, range 0.1 to 100): multiplier of the game's fly speed. 1 = unchanged. Above about 20 you can outrun the world loading in (you fly past empty ground for a moment)
- `use_game_fly_cheat` (default `false`): true = try the developers' own FlyMode cheat first; the mod's own way takes over if it doesn't fly you

## Requirements
- Destroy All Humans! (2020 remake, Steam). Not Destroy All Humans! 2 - Reprobed
- UE4SS v3.0.1 experimental, build e3ba1016 (the build we test on): https://github.com/UE4SS-RE/RE-UE4SS/releases/tag/experimental-latest

## Install
1. Install UE4SS into `...\Destroy All Humans!\DH\Binaries\Win64`.
2. Copy the `DAHFlyNoclip` folder into `...\DH\Binaries\Win64\ue4ss\Mods\`. The included enabled.txt switches it on.
3. Launch the game and load a save.

## Uninstall
Delete the `DAHFlyNoclip` folder from `ue4ss\Mods`. Nothing stays in your save.

## Side effects
- Nothing is saved: flying and collision are not part of the save. Quit or remove the mod and Crypto walks normally
- Turn Noclip off in open air. Switching it off inside a wall or under the ground can leave Crypto stuck; switch Noclip on again and fly out (or use the Cheat Menu's End key, unstuck)
- Landing from high up after Fly works like any fall in the game
- Entering the saucer, dying, respawning or loading switches Fly and Noclip off by itself
- The game may briefly take Crypto out of flying (for example the jetpack if you hold Space while flying, which also burns jetpack fuel): the mod sets flying again right away. Rise with Numpad 5, not Space. During cutscenes it waits and continues afterwards
- Single player game, no online mode. We have not checked whether Steam achievements still unlock while flying

## Compatibility
- Works with our Cheat Menu, God Mode, Infinite Ammo and Charge, Unlimited DNA, Unlock All and Game Speed (different keys)
- Shares the game-thread timer of our Destroy All Humans mods (no extra cost)

## Changelog
- **1.0.0** - First release

Made by Off the Clock. Free to use.
