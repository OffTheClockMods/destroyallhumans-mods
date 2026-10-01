# Unlock All Weapons and Abilities (Destroy All Humans! 2020)

Unlock all weapons and abilities in Destroy All Humans! (2020 remake): Ctrl+F1 unlocks every weapon, Ctrl+F2 every psychic power.
Also known as: unlock everything, all weapons.

## What it does
- Ctrl+F1 unlocks every weapon, Ctrl+F2 every psychic ability, with the developers' own unlock functions
- Nothing changes until you press a key: install it, press the keys once, done
- The number of unlocked items is read back from the game and written to the UE4SS log
- Keys in `Scripts\config.lua`
- Pox Lab upgrades are not included (our Unlimited DNA mod lets you buy them)

## Keys
- Ctrl+F1: unlock all weapons
- Ctrl+F2: unlock all psychic abilities

## Requirements
- Destroy All Humans! (2020 remake, Steam). Not Destroy All Humans! 2 - Reprobed
- UE4SS v3.0.1 experimental, build e3ba1016 (the build we test on): https://github.com/UE4SS-RE/RE-UE4SS/releases/tag/experimental-latest

## Install
1. Back up your save first: copy `%LOCALAPPDATA%\DH\Saved\SaveGames` somewhere safe.
2. Install UE4SS into `...\Destroy All Humans!\DH\Binaries\Win64`.
3. Copy the `DAHUnlockAll` folder into `...\DH\Binaries\Win64\ue4ss\Mods\`. The included enabled.txt switches it on.
4. Launch the game, load a save and press the keys.

## Side effects
- Permanent: the game writes the unlocks to your save at its next save. Removing the mod does not lock them again
- Single player only. We have not checked whether achievements tied to unlocking weapons still trigger

## Compatibility
- Works with our Cheat Menu, God Mode, Infinite Ammo and Charge and Unlimited DNA (different keys)

## Changelog
- **1.0.1** - Smoother memory cleanup, fewer micro-stutters: the mod's script memory is freed in small steps instead of occasional big sweeps.
- **1.0.0** - First release

Made by Off the Clock. Free to use.
