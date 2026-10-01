# Cheat Menu - God Mode, Ammo, DNA (Destroy All Humans! 2020)

A cheat menu for Destroy All Humans! (2020 remake): the developers' own cheats on keys, without a console or an unlocker.
Also known as: cheats, trainer, cheat codes for PC.

## What it does
- **God Mode** (F5): nothing hurts Crypto. Optional "immortal" style in the config: you take hits but can't die
- **Infinite Ammo and Charge** (F7): ammo weapons never run out, energy weapons never run dry, on foot and in the saucer
- **Unlimited Concentration** (F8): Psychokinesis, Hypnotize and the Holobob disguise never drain
- **Invisibility** (F9): humans and agents can't see you
- **Unlimited Jetpack** (F10): the jetpack never runs out of fuel
- **Add DNA** (F4): +1,000 DNA per press for Pox Lab upgrades (amount in the config)
- **Extras**: Ctrl+F3 destroys enemies around you, Page Up calls your saucer, End respawns you if you get stuck, Page Down hides the HUD for screenshots
- Everything starts off; press a key to switch it on. Start states, keys and the DNA amount are in `Scripts\config.lua`
- Every change is read back from the game and written to the UE4SS log, so you can see it worked

## Keys
- F5 God Mode, F7 Infinite Ammo and Charge, F8 Unlimited Concentration, F9 Invisibility, F10 Unlimited Jetpack (each on/off)
- F4 Add DNA, Ctrl+F3 nuke enemies nearby, Page Up call the saucer, End unstuck, Page Down hide/show the HUD
- These keys are free in the game (it only uses F11, for fullscreen). Change any key in `Scripts\config.lua`

## Requirements
- Destroy All Humans! (2020 remake, Steam). Not Destroy All Humans! 2 - Reprobed
- UE4SS v3.0.1 experimental, build e3ba1016 (the build we test on): https://github.com/UE4SS-RE/RE-UE4SS/releases/tag/experimental-latest

## Install
1. Install UE4SS into `...\Destroy All Humans!\DH\Binaries\Win64` (dwmapi.dll and the ue4ss folder go next to DH-Win64-Shipping.exe).
2. Copy the `DAHCheatMenu` folder into `...\DH\Binaries\Win64\ue4ss\Mods\`. The included enabled.txt switches it on.
3. Launch the game and load a save.

## Side effects
- The cheats are the game's own switches. They are not saved: remove the mod and the game plays normally again
- DNA you add is saved with your game and stays after you remove the mod
- Unstuck respawns you like a normal respawn. Skip mission step (off by default, no key) completes the current objective and can skip story moments
- Single player only. We have not checked whether Steam achievements still unlock while a cheat is on

## Compatibility
- Use either this Cheat Menu or our single God Mode / Infinite Ammo / Unlimited DNA mods, not both together (same keys)
- Works with Unlock All Weapons and Abilities (different keys)

## Changelog
- **1.0.1** - Smoother memory cleanup, fewer micro-stutters: the mod's script memory is freed in small steps instead of occasional big sweeps.
- **1.0.0** - First release

Made by Off the Clock. Free to use.
