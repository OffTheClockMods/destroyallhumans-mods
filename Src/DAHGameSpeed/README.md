# Game Speed - Slow Motion, Fast Forward (Destroy All Humans! 2020)

Game speed for Destroy All Humans! (2020 remake): slow motion and fast forward on the numpad, from x0.1 to x5 or your own steps.
Also known as: speed hack, time scale, speedhack, slow mo.

## What it does
- Numpad + = next faster speed, Numpad - = next slower speed, Numpad 9 = back to normal speed (x1)
- Steps x0.1, x0.25, x0.5, x0.75, x1, x1.5, x2, x3, x5 by default; set your own steps from x0.01 to x20 in the config
- Starts at x1 = the game's own speed: nothing changes until you press a key (or set a start speed)
- The game's own slow-motion moments (the weapon wheel, the Temporal Distortionator upgrade) keep working: your speed multiplies with them instead of replacing them
- Each new speed is read back, and the mod measures the game clock against the real clock to confirm it (in the UE4SS log)
- After loading or entering a new area the speed is set again by itself
- Hotkeys of all our Destroy All Humans mods stay responsive at any speed

## Keys
- Numpad +: faster
- Numpad -: slower
- Numpad 9: normal speed
- Numpad keys need Num Lock on. The game uses no Numpad key except Numpad 1-4. All keys can be changed in `Scripts\config.lua`

## Config
Edit `DAHGameSpeed\Scripts\config.lua`, save, restart the game:
- `faster_key` (default `"ADD"`), `slower_key` (default `"SUBTRACT"`), `normal_key` (default `"NUM_NINE"`). `""` = no key
- `speeds` (default `{ 0.1, 0.25, 0.5, 0.75, 1.0, 1.5, 2.0, 3.0, 5.0 }`): the steps, each from 0.01 to 20. x1 is always added
- `start_speed` (default `1.0`): the speed when you load a save. 1 = normal
- Why x20 at most: it is Unreal's own upper limit for game speed. Below x0.01 the game is practically frozen

## Requirements
- Destroy All Humans! (2020 remake, Steam). Not Destroy All Humans! 2 - Reprobed
- UE4SS v3.0.1 experimental, build e3ba1016 (the build we test on): https://github.com/UE4SS-RE/RE-UE4SS/releases/tag/experimental-latest

## Install
1. Install UE4SS into `...\Destroy All Humans!\DH\Binaries\Win64`.
2. Copy the `DAHGameSpeed` folder into `...\DH\Binaries\Win64\ue4ss\Mods\`. The included enabled.txt switches it on.
3. Launch the game and load a save.

## Uninstall
Delete the `DAHGameSpeed` folder from `ue4ss\Mods`. Nothing stays in your save.

## Side effects
- Nothing is saved: the speed is gone when you quit, and the game runs at normal speed without the mod
- Sound and voices are not sped up or slowed down. Cutscenes play at your speed while their voices don't, so switch back to x1 (Numpad 9) for cutscenes
- Above about x2, physics objects (ragdolls, debris, thrown cars and cows) fall behind the rest of the game: the game limits each physics step. Nothing breaks, it just looks slower
- At high speeds fast objects move in bigger steps per frame, so a shot can occasionally miss what it would have hit
- Mission timers and enemy reinforcements run at your speed too
- Single player game, no online mode. We have not checked whether Steam achievements still unlock with a changed speed

## Compatibility
- Works with our Cheat Menu, God Mode, Infinite Ammo and Charge, Unlimited DNA, Unlock All and Fly Mode and Noclip (different keys)
- Don't combine it with a trainer's speed option (both change the game speed)

## Changelog
- **1.0.0** - First release

Made by Off the Clock. Free to use.
