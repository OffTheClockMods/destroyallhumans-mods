# Infinite Ammo and Charge (Destroy All Humans! 2020)

Infinite ammo for Destroy All Humans! (2020 remake): ammo weapons never run out and energy weapons never run dry.
Also known as: unlimited ammo, no reload.

## What it does
- Infinite ammo: the Disintegrator Ray, Ion Detonator, Anal Probe and the saucer's ammo weapons never run out
- Infinite charge: the Zap-O-Matic and the saucer's death ray never run dry
- Uses the game's own developer cheats (Cheat.InfiniteAmmo and Cheat.InfiniteCharge), on the moment you load in
- F7 switches both off and on. Either part can be switched off in `Scripts\config.lua`
- The game's own values are read back after every change and written to the UE4SS log

## Keys
- F7: Infinite Ammo and Charge off/on (the game itself uses no F-keys except F11, fullscreen)

## Requirements
- Destroy All Humans! (2020 remake, Steam). Not Destroy All Humans! 2 - Reprobed
- UE4SS v3.0.1 experimental, build e3ba1016 (the build we test on): https://github.com/UE4SS-RE/RE-UE4SS/releases/tag/experimental-latest

## Install
1. Install UE4SS into `...\Destroy All Humans!\DH\Binaries\Win64`.
2. Copy the `DAHInfiniteAmmo` folder into `...\DH\Binaries\Win64\ue4ss\Mods\`. The included enabled.txt switches it on.
3. Launch the game and load a save.

## Side effects
- Nothing is saved: remove the mod and ammo works normally again
- Single player only. We have not checked whether Steam achievements still unlock while it is on

## Compatibility
- Don't use it together with our Cheat Menu (it has the same cheat on the same key)
- Works with God Mode, Unlimited DNA and Unlock All Weapons and Abilities

## Changelog
- **1.0.1** - Smoother memory cleanup, fewer micro-stutters: the mod's script memory is freed in small steps instead of occasional big sweeps.
- **1.0.0** - First release

Made by Off the Clock. Free to use.
