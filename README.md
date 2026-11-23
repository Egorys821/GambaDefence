# Gamba Defence

A medieval roguelike made in Godot 4.6 (GDScript). A time traveller finds a magic slot machine in a castle cellar.

- **Day:** spin the 5x3 slot machine. Lines of 3+ matching symbols (counted from the left reel) pay out: coins give gold, swords and bows summon troops in front of the castle, hammers repair it. Spend gold at the merchant on new symbols, symbol upgrades, new paylines and extra spins.
- **Night:** the camera zooms out. Evil spirits rise from the graveyard at the bottom and march up to the castle. Your troops and the castle towers fight them. Survive 10 nights. The last one ends with the Lich King.

- **Castles:** the Kingdom Map has 5 castles (Willowdale Keep, Frostpeak Citadel, Sunken Marsh, Iron Crypt, Ashen Throne). Each has its own spirits, boss, troops and payline shapes, and some favour different builds: flying spirits (only ranged troops and towers hit them) and armored spirits (weak hits barely hurt). Winning one opens the next.
- **The curse:** Tombstones are bad symbols. Each one that lands adds a spirit to tonight's wave; a line of them adds a group. From a castle's `curse_start_night`, every dawn adds more Tombstones to the reels. Banish them at the merchant.
- **Roguelike loop:** you are expected to lose. Each run earns **Chrono Shards** (nights survived, spirits destroyed, victory bonus). Spend them in the **Time Forge** on permanent upgrades for the slot machine, the castle and the army, then try again.

Controls: mouse; **Space** spins, and once spins run out it highlights "Face the Night" (press again to start). Use the speed button at night to fast-forward.

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
  machines/*.tres  MachineStyle: the slot machine styles (layout, how they pay, bonus feature)
  upgrades/meta/   UpgradeData: permanent Time Forge upgrades (cost in Chrono Shards)
  upgrades/merchant/ UpgradeData: the merchant's upgrade tree, sold for one run (gold, with a `rarity`)
src/
  autoload/        GameState (run state + stat()), MetaProgress (shards, saved upgrades), Audio
  meta/            Main menu, Kingdom Map, Time Forge, Preview (codex)
  data/            Resource classes (SymbolData, UnitData, MachineStyle) and Paylines tables
  main/            main.tscn: day/night loop, intro and end screens
  day/             DayPhase (layout + rewards), Paytable (left panel), payline diagrams
  slot_machine/    SlotMachine (spin flow), Reel (one column), MachineRules + LineEvaluator +
				   WaysEvaluator (rules), GridOps, SlotWin, Payline, LineOverlay (win drawing)
	features/     MachineFeature + one class per bonus (gamble, nudge, free spins, hoard, cascade)
  shop/            Merchant UI, offer cards, ShopCatalog (prices and offers)
  battle/          Battlefield (camera, formation, night), Unit, Castle, Projectile, WaveGenerator
  fx/              Fx helper: particle bursts, flying icons, shakes, pops
  ui/              HUD, night panel, message screen, floating text
tools/
  generate_art.py  Generates all sprites from ASCII pixel maps (Python + Pillow)
  generate_audio.py Generates all chiptune sounds and music (plain Python)
  debug/           smoke_test.tscn plays a run by itself, rules_test.tscn unit-tests the slot
				   rules, slot_sim.tscn simulates every machine for balancing
```

## Upgrade system

Every number an upgrade can change is a **stat** listed in `src/data/stats.gd` with its base value.
Code reads it with `GameState.stat(Stats.TOWER_DAMAGE)`, which returns base + permanent upgrades + this run's upgrades.

- New upgrade for an existing stat: duplicate a `.tres` in `data/upgrades/meta/` (Time Forge) or `data/upgrades/merchant/` (merchant, set its `rarity`) and edit it. It appears automatically.
- Merchant rarity: every offer is Common (gray), Rare (blue), Mythic (red) or Legendary (gold). Each offer slot draws a token from a hidden bag (`MerchantRarity.BAG_CONTENTS`, 20/10/3/1, refilled when empty), then a random ware of that rarity; if none is for sale it falls back to a lower rarity. The main menu's **Merchant Wares** screen lists everything by rarity.
- Time Forge tree: set `requires` (parent upgrade), `requires_level` and `tree_position` (column, row) on a meta upgrade.
- New kind of effect: add a key to `Stats`, read it where it matters, then make a `.tres` for it.

Progress is saved to `user://meta_progress.cfg` (the Time Forge has a reset button).

## Slot machine styles

Conquering a castle unlocks a new slot machine (Willowdale Keep → Old Cellar, Frostpeak Citadel → Jester's 81, Sunken Marsh → Dragon's Hoard, Iron Crypt → Tome of Ages, Ashen Throne → Shifting Halls). The player picks it in the Time Forge ("Slot Machines" branch) with **Use machine**; each machine has 3 shard upgrades of its own below it. The design and research behind them is in `docs/SLOT_MACHINE_STYLES.md`.

| Machine | Style | Bonus |
|---|---|---|
| Gamba Machine | 5 reels, paylines (the original) | none |
| Old Cellar | 3-reel classic fruit machine | mixed weapon wins, lucky coin, x2 Crown wilds, nudge |
| Jester's 81 | 4x3, lines; a Jester turns the spin into 81 ways | gamble gold on a card |
| Dragon's Hoard | 5 reels, lines | 6+ chests: hold-and-win respins with jackpots |
| Tome of Ages | 5 reels, lines, low base wins | Tome scatters: free spins with an expanding symbol |
| Shifting Halls | 6 reels of 2-4 rows, ways | cascades with a chain multiplier |

- A machine is a `data/machines/*.tres` (`MachineStyle`): reels, rows, `eval_mode` (lines / ways / lines-or-ways), line table (`src/data/paylines.gd`), match multipliers (fractions allowed), feature, starting and merchant symbols, colours.
- A feature is a `MachineFeature` subclass in `src/slot_machine/features/`; it runs after the base spin through the SlotMachine's feature API (`spin_to`, `present`, `ask`, `announce`...). The pure rules it uses (`BookExpansion`, `HoardRound`, `GridOps.collapse`) are what the tests and the simulator check.
- A machine's unlock node is a META upgrade with `unlock_castle` set: it can't be bought and counts as owned once that castle is conquered (`MetaProgress.level_of`). Its 3 upgrades are ordinary META upgrades (`category = MACHINES`) that `require` it; their stats are in the "Machine styles" part of `src/data/stats.gd`.
- Feature symbols have a `max_copies` cap (Jester 2, Crown 1, Tome 1, Chest 3) so buying them can't make the feature trigger every spin.
- Machines with fixed rows turn each row upgrade into +30% rewards (`GameState.ROW_REWARD_BONUS`).

## Adding a castle

Duplicate a file in `data/castles/`, give it a new `id`, a higher `order` and a `map_position`. Then set its starting reels, merchant symbols, spirit roster (`enemies`), `boss` and difficulty numbers. It appears on the map after the previous castle.
New pattern shapes go in `src/data/paylines.gd` (`SHAPES`, with a `"tier"`). A shape pays at every height it fits on the machine, so a 3-row-tall shape gives 1 line on 3 rows and 3 lines on 5 rows. A castle sells shapes up to its `payline_tier`.

## Where to tweak things

| What | Where |
|---|---|
| Symbol rewards, shop price, unlock night | `data/symbols/*.tres` |
| Troop / spirit stats, flying, armor | `data/units/*.tres` |
| Base gold, spins, rows, castle HP, tower stats | `src/data/stats.gd` |
| Starting reel symbols | `src/autoload/game_state.gd` |
| Chrono Shard rewards | `src/autoload/meta_progress.gd` |
| Pattern shapes per machine | `src/data/paylines.gd` |
| Machine layout, multipliers, feature numbers | `data/machines/*.tres` |
| Hoard prizes and jackpots | `src/slot_machine/features/hoard_prize.gd` |
| Win caps for ways, chains and multiplier wilds | `src/slot_machine/slot_win.gd` |
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

Flags: `--machine=<id>` (play a machine style, e.g. `jester_81`), `--castle=N` (which castle; earlier ones count as conquered), `--shards=N` (start with shards and buy Time Forge upgrades), `--idle` (no spins or shopping, so only the castle defends), `--shots=<folder>` (save screenshots; needs a window, so don't use `--headless`).

## Rules tests and balance simulator

```bash
godot --headless --path . res://tools/debug/rules_test.tscn
```

Unit tests for the slot rules: lines, ways, wilds, group wins, cascades, nudges, expansions, the hoard, reward caps and every machine's setup. Exits with code 1 on a failure.

```bash
godot --headless --path . res://tools/debug/slot_sim.tscn -- --spins=20000
```

Spins every machine many times with the same pure rules and prints the average value per daily spin (gold + troops + repairs; curse threat has its own column), how it compares with the Gamba Machine, hit rate, feature rate and the biggest spins. Flags: `--castle=N` or `--castle=all` (starting reels), `--night=N` (reels grown by a simulated merchant and curse), `--upgrades` (max the shared slot upgrades and each machine's own branch), `--machine=<id>`.
