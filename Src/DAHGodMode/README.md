# God Mode (Destroy All Humans! 2020)

God mode for Crypto in Destroy All Humans! (2020 remake): enemy fire, explosions and attacks deal no damage to you.
Also known as: invincible, no damage.

## What it does
- Uses the game's own developer cheat (Cheat.Invulnerability), switched on the moment you load in
- F5 switches it off and on, for example to fight a boss the normal way
- Optional `style = "immortal"` in `Scripts\config.lua`: you still take hits and lose health, but you can't die
- `start_on = false` starts with God Mode off. The key can be changed in the config
- The game's own value is read back after every change and written to the UE4SS log

## Keys
- F5: God Mode off/on (the game itself uses no F-keys except F11, fullscreen)

## Requirements
- Destroy All Humans! (2020 remake, Steam). Not Destroy All Humans! 2 - Reprobed
- UE4SS v3.0.1 experimental, build e3ba1016 (the build we test on): https://github.com/UE4SS-RE/RE-UE4SS/releases/tag/experimental-latest

## Install
1. Install UE4SS into `...\Destroy All Humans!\DH\Binaries\Win64`.
2. Copy the `DAHGodMode` folder into `...\DH\Binaries\Win64\ue4ss\Mods\`. The included enabled.txt switches it on.
3. Launch the game and load a save.

## Side effects
- Nothing is saved: remove the mod and you take damage again
- Single player only. We have not checked whether Steam achievements still unlock while God Mode is on
- Not checked yet: whether the saucer is also protected (Crypto on foot is)

## Compatibility
- Don't use it together with our Cheat Menu (it has God Mode on the same key)
- Works with Infinite Ammo and Charge, Unlimited DNA and Unlock All Weapons and Abilities

## Changelog
- **1.0.1** - Smoother memory cleanup, fewer micro-stutters: the mod's script memory is freed in small steps instead of occasional big sweeps.
- **1.0.0** - First release

Made by Off the Clock. Free to use.
