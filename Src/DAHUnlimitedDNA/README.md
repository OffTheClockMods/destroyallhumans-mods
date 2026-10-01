# Unlimited DNA (Destroy All Humans! 2020)

Unlimited DNA for Destroy All Humans! (2020 remake): press F4 for 1,000 DNA, as often as you like, and buy every Pox Lab upgrade.
Also known as: infinite DNA, DNA cheat.

## What it does
- F4 adds 1,000 DNA through the game's own developer function (AddDNA)
- The new total is read back from the game and written to the UE4SS log
- Amount (1 to 10,000,000 per press) and key in `Scripts\config.lua`
- Stops at 2 billion DNA, below the game's number limit

## Keys
- F4: add DNA (the game itself uses no F-keys except F11, fullscreen)

## Requirements
- Destroy All Humans! (2020 remake, Steam). Not Destroy All Humans! 2 - Reprobed
- UE4SS v3.0.1 experimental, build e3ba1016 (the build we test on): https://github.com/UE4SS-RE/RE-UE4SS/releases/tag/experimental-latest

## Install
1. Install UE4SS into `...\Destroy All Humans!\DH\Binaries\Win64`.
2. Copy the `DAHUnlimitedDNA` folder into `...\DH\Binaries\Win64\ue4ss\Mods\`. The included enabled.txt switches it on.
3. Launch the game and load a save.

## Side effects
- DNA is saved with your game: what you add stays in your save, also after you remove the mod
- Single player only. We have not checked whether Steam achievements still unlock

## Compatibility
- Don't use it together with our Cheat Menu (it has Add DNA on the same key)
- Works with God Mode, Infinite Ammo and Charge and Unlock All Weapons and Abilities

## Changelog
- **1.0.1** - Smoother memory cleanup, fewer micro-stutters: the mod's script memory is freed in small steps instead of occasional big sweeps.
- **1.0.0** - First release

Made by Off the Clock. Free to use.
