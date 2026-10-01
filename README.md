# Destroy All Humans! Mods by Off the Clock

Source code of the Off the Clock mods for **Destroy All Humans!**: UE4SS Lua mods (Unreal Engine 4.22), Steam PC (2020 remake).

## The mods

| Mod | What it does | Version | Download |
|---|---|---|---|
| **Cheat Menu - God Mode Ammo and DNA** (`Src/DAHCheatMenu`) | Cheat menu with the developers' own cheats on keys: god mode, infinite ammo and charge, unlimited concentration and jetpack, invisibility, add DNA, nuke, call saucer, unstuck, hide HUD. No console or unlocker needed. Destroy All Humans! (2020 remake), not DAH 2 Reprobed + UE4SS. | 1.0.1 | [Nexus Mods](https://www.nexusmods.com/destroyallhumans/mods/32) |
| **Fly Mode and Noclip** (`Src/DAHFlyNoclip`) | Fly mode and noclip for Crypto: Numpad 7 flies you over the map, Numpad 8 flies you through walls, floors and buildings (no clip), the same key again walks. Hold Numpad 5 or Left Ctrl to rise or sink. Optional fly speed. On foot only, no console needed. Destroy All Humans! (2020 remake) + UE4SS. | 1.0.0 | [Nexus Mods](https://www.nexusmods.com/destroyallhumans/mods/36) |
| **Game Speed - Slow Motion and Fast Forward** (`Src/DAHGameSpeed`) | Game speed for Destroy All Humans! (2020 remake): slow motion and fast forward with numpad keys. Numpad + faster, Numpad - slower, Numpad 9 normal, from x0.1 to x5 or your own steps (x0.01 to x20). Time scale that keeps the game's own slow-mo moments. Starts at normal speed. UE4SS. | 1.0.0 | [Nexus Mods](https://www.nexusmods.com/destroyallhumans/mods/37) |
| **God Mode** (`Src/DAHGodMode`) | God mode for Crypto: enemy fire, explosions and attacks deal no damage (invincible). Uses the game's own developer cheat, on as soon as you load a save, F5 switches it off and on. Optional 'immortal' style: take hits but never die. Destroy All Humans! (2020 remake) + UE4SS. | 1.0.1 | [Nexus Mods](https://www.nexusmods.com/destroyallhumans/mods/33) |
| **Infinite Ammo and Charge** (`Src/DAHInfiniteAmmo`) | Infinite ammo and charge: ammo weapons never run out and energy weapons never run dry (unlimited ammo, no reload), on foot and in the saucer. The game's own developer cheats, on from the moment you load in; F7 switches them. Destroy All Humans! (2020 remake) + UE4SS. | 1.0.1 | [Nexus Mods](https://www.nexusmods.com/destroyallhumans/mods/34) |
| **Unlimited DNA - Add DNA Hotkey** (`Src/DAHUnlimitedDNA`) | Unlimited DNA: press F4 for 1,000 DNA (infinite DNA for every Pox Lab upgrade), as often as you like. Amount and key in the config. Uses the game's own AddDNA and shows the new total in the log. Your save keeps the DNA. Destroy All Humans! (2020 remake) + UE4SS. | 1.0.1 | [Nexus Mods](https://www.nexusmods.com/destroyallhumans/mods/35) |
| **Unlock All Weapons and Abilities** (`Src/DAHUnlockAll`) | Unlock all weapons and abilities: Ctrl+F1 unlocks every weapon, Ctrl+F2 every psychic power, with the developers' own unlock functions. Nothing changes until you press a key. Permanent: the game saves it, so back up your save first. Destroy All Humans! (2020 remake) + UE4SS. | 1.0.1 | not released yet |

Download the mods from the pages above. This repository is the source code, so you can see exactly what each mod does.

## Install and build

Nothing to compile: each mod is plain Lua for [UE4SS](https://github.com/UE4SS-RE/RE-UE4SS). Players should install
from the mod pages above (each page has the steps). To run a mod from this source, copy `Src/<Mod>/` (its `Scripts`
folder and `enabled.txt`) to `<game folder>\DH\Binaries\Win64\ue4ss\Mods\<Mod>\`.

**Offline tests** (no game needed): every mod has `tests/<Mod>.scenarios.lua`, run with the fake UE4SS runtime from
[ue4ss-mod-test-kit](https://github.com/offtheclocksoftware/ue4ss-mod-test-kit) and Lua 5.4:

```
lua <ue4ss-mod-test-kit>/harness/run.lua Src/<Mod>/Scripts/main.lua Src/<Mod>/tests/<Mod>.scenarios.lua
```

Rules every mod follows: hooks only on functions the game calls on its game thread (no `LoopAsync`,
`ExecuteWithDelay`, `ExecuteInGameThread` or `RegisterKeyBind`), keys read there through the player controller,
every hook wrapped so an error is logged instead of crashing the game, and `[SELFCHECK]` lines in `UE4SS.log`.

## What the mods do and don't do

- **Only what the mod page says.** Single player; nothing affects other players or online modes.
- **Settings at the game's own values by default**, with wide ranges and a short note beside each setting.
- **Honest side effects**: each mod page and README says what it changes (saves, achievements, cheat flags).

## Bugs and ideas

Open an [issue](https://github.com/OffTheClockMods/destroyallhumans-mods/issues). Please include the mod and version, the game version, what you did and what happened, and
the log lines that mention the mod.

## Licence

[MIT](LICENSE). You may learn from, reuse and adapt this code; keep the copyright notice. A friendly request (not a
licence term): please don't re-upload our mods. Link to our pages instead, so players always get the current version.

Written with AI coding help (Claude). Every release passes our offline tests and an automated in-game check before
it is published; we also play-test the mods by hand.

Destroy All Humans! is a trademark of its owner (THQ Nordic). This project is not affiliated with or endorsed by them.
