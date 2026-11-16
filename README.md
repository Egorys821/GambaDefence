# Gamba Defence

A medieval roguelike made in Godot 4.6 (GDScript). A time traveller finds a magic slot machine in a castle cellar.

- **Day:** spin the 5x3 slot machine. Lines of 3+ matching symbols (counted from the left reel) pay out: coins give gold, swords and bows summon troops in front of the castle, hammers repair it. Spend gold at the merchant on new symbols, symbol upgrades, new paylines and extra spins.
- **Night:** the camera zooms out. Evil spirits rise from the graveyard at the bottom and march up to the castle. Your troops and the castle towers fight them. Survive 10 nights. The last one ends with the Lich King.

- **Castles:** the Kingdom Map has 5 castles (Willowdale Keep, Frostpeak Citadel, Sunken Marsh, Iron Crypt, Ashen Throne). Each has its own spirits, boss, troops and payline shapes, and some favour different builds: flying spirits (only ranged troops and towers hit them) and armored spirits (weak hits barely hurt). Winning one opens the next.
- **Lucky Clover:** a line of clovers gives 1 / 2 / 3 free spins that play automatically.
- **The curse:** Tombstones are bad symbols. Each one that lands adds a spirit to tonight's wave; a line of them adds a group. From a castle's `curse_start_night`, every dawn adds more Tombstones to the reels. Banish them at the merchant.
- **Roguelike loop:** you are expected to lose. Each run earns **Chrono Shards** (nights survived, spirits destroyed, victory bonus). Spend them in the **Time Forge** on permanent upgrades for the slot machine, the castle and the army, then try again.

Controls: mouse, plus **Space** to spin. Use the speed button at night to fast-forward.

## Project layout

```
assets/            Art, audio and theme (sprites and sounds are generated, see tools/)
  sprites/         symbols, units, enemies, projectiles, environment, ui
  audio/           sfx/*.wav sound effects, music/*.wav day and night loops
  theme/           main_theme.tres: fonts, buttons, panels
data/              Game content as editable resources (open in the Inspector)
  symbols/*.tres   SymbolData: reel symbols, effects, shop prices
  units/*.tres     UnitData: troop and spirit stats (healers, bosses too)
  castles/*.tres   CastleData: map order, starting reels, merchant symbols, spirits, boss, difficulty
  upgrades/meta/   UpgradeData: permanent Time Forge upgrades (cost in Chrono Shards)
  upgrades/run/    UpgradeData: upgrades the merchant sells for one run (cost in gold)
src/
  autoload/        GameState (run state + stat()), MetaProgress (shards, saved upgrades), Audio
  meta/            Main menu, Kingdom Map, Time Forge, Preview (codex)
  data/            Resource classes (SymbolData, UnitData) and Paylines table
  main/            main.tscn: day/night loop, intro and end screens
  day/             DayPhase (layout + rewards), Paytable (left panel), payline diagrams
  slot_machine/    Scrolling reels, suspense, payline evaluation, win line drawing
  shop/            Merchant UI, offer cards, ShopCatalog (prices and offers)
  battle/          Battlefield (camera, formation, night), Unit, Castle, Projectile, WaveGenerator
  fx/              Fx helper: particle bursts, flying icons, shakes, pops
  ui/              HUD, night panel, message screen, floating text
tools/
  generate_art.py  Generates all sprites from ASCII pixel maps (Python + Pillow)
  generate_audio.py Generates all chiptune sounds and music (plain Python)
  debug/           smoke_test.tscn plays a run by itself (for testing)
```

## Upgrade system

Every number an upgrade can change is a **stat** listed in `src/data/stats.gd` with its base value.
Code reads it with `GameState.stat(Stats.TOWER_DAMAGE)`, which returns base + permanent upgrades + this run's upgrades.

- New upgrade for an existing stat: duplicate a `.tres` in `data/upgrades/meta/` (Time Forge) or `data/upgrades/run/` (merchant) and edit it. It appears automatically.
- Time Forge tree: set `requires` (parent upgrade), `requires_level` and `tree_position` (column, row) on a meta upgrade.
- New kind of effect: add a key to `Stats`, read it where it matters, then make a `.tres` for it.

Progress is saved to `user://meta_progress.cfg` (the Time Forge has a reset button).

## Adding a castle

Duplicate a file in `data/castles/`, give it a new `id`, a higher `order` and a `map_position`. Then set its starting reels, merchant symbols, spirit roster (`enemies`), `boss` and difficulty numbers. It appears on the map after the previous castle.
New payline shapes go in `src/data/paylines.gd` with a `"tier"`. A castle sells shapes up to its `payline_tier`.

## Where to tweak things

| What | Where |
|---|---|
| Symbol rewards, shop price, unlock night | `data/symbols/*.tres` |
| Troop / spirit stats, flying, armor | `data/units/*.tres` |
| Base gold, spins, rows, castle HP, tower stats | `src/data/stats.gd` |
| Starting reel symbols | `src/autoload/game_state.gd` |
| Chrono Shard rewards | `src/autoload/meta_progress.gd` |
| Payline shapes, 4/5-of-a-kind multipliers | `src/data/paylines.gd` |
| Shop prices for upgrades, paylines, spins, repair | `src/shop/shop_catalog.gd` |
| Night difficulty, enemy mix, boss | `data/castles/*.tres` |
| Castle tower range | `src/battle/castle.gd` |
| Watchtower / Mage / Ballista stats | `src/battle/watchtower.gd` (`KINDS`) |
| Curse strength and when it spreads | `data/symbols/tombstone.tres`, castle `curse_start_night` |
| Troop formation, camera zoom, night colour | `src/battle/battlefield.gd` |
| Spin speed, suspense time, win presentation | `src/slot_machine/slot_machine.gd` |
| Attack / death sound per unit | `data/units/*.tres` (Sound group) |
| Default volumes (players change them in Settings) | `src/autoload/audio.gd` |

To add a new symbol: draw it in `tools/generate_art.py`, run the script, then duplicate a `.tres` in `data/symbols/` and change its fields. GameState loads every symbol in that folder automatically.

## Art and audio

```bash
python tools/generate_art.py
```

```bash
python tools/generate_audio.py
```

Play any sound from code with `Audio.play(&"coin")`, where the name is a file in `assets/audio/sfx/`.

## Smoke test

```bash
godot --path . res://tools/debug/smoke_test.tscn -- --nights=10
```

Flags: `--castle=N` (which castle; earlier ones count as conquered), `--shards=N` (start with shards and buy Time Forge upgrades), `--idle` (no spins or shopping, so only the castle defends), `--shots=<folder>` (save screenshots; needs a window, so don't use `--headless`).
