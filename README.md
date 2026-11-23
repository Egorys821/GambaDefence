# Gamba Defence

A medieval roguelike made in Godot 4.6 (GDScript). A time traveller finds a magic slot machine in a castle cellar.

- **Day:** spin the 5x3 slot machine. Lines of 3+ matching symbols (counted from the left reel) pay out: coins give gold, swords and bows summon troops in front of the castle, hammers repair it. Spend gold at the merchant on new symbols, symbol upgrades, new paylines and extra spins.
- **Night:** the camera zooms out. Evil spirits rise from the graveyards and march to the castle, walking around rivers, cliffs, groves and walls (flying spirits go straight over). Your troops and the castle towers fight them. Survive 10 nights. The last one ends with the castle's boss.

- **Castles:** the Kingdom Map has 10 castles, each with its own battlefield in front of it: Willowdale Keep (open field), Riverford (river with two bridges), Frostpeak Citadel (mountain pass), Thornwood Hollow (winding forest lanes), Sunken Marsh (bog pools and causeways), Highwater Bridge (one bridge over a deep river), Iron Crypt (crypt walls), Hollowmere (graveyards on both flanks), Stormcrag (a pass, then a river bridged at its ends) and Ashen Throne (lava channels). Each also has its own spirits, boss, troops and payline shapes, and some favour different builds: flying spirits (only ranged troops and towers hit them) and armored spirits (weak hits barely hurt). Winning one opens the next.
- **The curse:** Tombstones are bad symbols. Each one that lands adds a spirit to tonight's wave; a line of them adds a group. From a castle's `curse_start_night`, every dawn adds more Tombstones to the reels. Banish them at the merchant.
- **Roguelike loop:** you are expected to lose. Each run earns **Chrono Shards** (nights survived, spirits destroyed, victory bonus). Spend them in the **Time Forge** on permanent upgrades, then try again.
- **Time Forge:** four windows (tabs) of skills: **Slot Machines** (upgrades for every machine on the left; on the right one column per machine, starting with the Gamba Machine, whose upgrades only work on that machine), **Castle**, **Troops** and **Merchant**, 61 skills in all. Most cost shards. The big **crown nodes** (gold double frame, little crown on top) cost **Crowns**: new slot machines and the keys that open whole subtrees (Fortified Towers → Arcane/Ballista towers, Bastion → castle armor, Recruit Crossbowmen → Clerics, Trading Charter → Fair Trades, Elite Training, Extra Row, Magic Rune, Legendary Favor).
- **Crowns:** won the first time each castle is conquered (castles 1-3: 1, 4-7: 2, 8-10: 3; 20 in all). Crown nodes cost 27, so the player has to choose. Crowns aren't saved: they are the crowns of the conquered castles minus the crowns spent, so "Refund all" gives them back too.

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
  castles/*.tres   CastleData: map order, starting reels, merchant symbols, spirits, boss, difficulty, layout
  layouts/*.tres   BattleLayout: the battlefield per castle (terrain, graveyards, tower slots, rally points)
  machines/*.tres  MachineStyle: the slot machine styles (layout, how they pay, bonus feature)
  upgrades/meta/   UpgradeData: permanent Time Forge upgrades (Chrono Shards, or Crowns for crown nodes)
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
  battle/          Battlefield (camera, formation, night), Unit, Castle, Projectile, WaveGenerator,
				   BattleNav (walking grid + A* paths), LayoutView (draws a BattleLayout)
  fx/              Fx helper: particle bursts, flying icons, shakes, pops
  ui/              HUD, night panel, message screen, floating text
tools/
  generate_art.py  Generates all sprites from ASCII pixel maps (Python + Pillow)
  generate_audio.py Generates all chiptune sounds and music (plain Python)
  debug/           smoke_test.tscn plays a run by itself, rules_test.tscn unit-tests the slot
				   rules, slot_sim.tscn simulates every machine for balancing,
				   machine_gallery.tscn screenshots every machine with its feature forced
```

## Upgrade system

Every number an upgrade can change is a **stat** listed in `src/data/stats.gd` with its base value.
Code reads it with `GameState.stat(Stats.TOWER_DAMAGE)`, which returns base + permanent upgrades + this run's upgrades.

- New upgrade for an existing stat: duplicate a `.tres` in `data/upgrades/meta/` (Time Forge) or `data/upgrades/merchant/` (merchant, set its `rarity`) and edit it. It appears automatically.
- Merchant rarity: every offer is Common (gray), Rare (blue), Mythic (red) or Legendary (gold). Each offer slot draws a token from a hidden bag (`MerchantRarity.BAG_CONTENTS`, 20/10/3/1, refilled when empty), then a random ware of that rarity; if none is for sale it falls back to a lower rarity. The main menu's **Merchant Wares** screen lists everything by rarity.
- Machine symbols: a machine's special symbols (its `start_symbols` and `merchant_symbols`: Crown, Jester, Hoard chest, Tome) only ever appear while playing that machine. `GameState.is_other_machine_symbol()` keeps them out of starting reels, merchant offers, trades and `add_symbol()`. Shared symbols such as the Magic Rune are not affected.
- Trading Post (`TradeRules`): bought once per run at the bottom of the merchant column. Then three trade buttons, usable any number of times a day at a fixed price. The merchant picks the symbol each one takes at random (shown on the button, re-picked after every trade and every day); the player then picks what to get from a row of symbols that opens above the buttons: **Swap Up** (2 copies -> 1 symbol of the next rarity, e.g. 2 Bows -> 1 Crossbow), **Swap** (1 -> 1 other symbol of the same rarity) and **Remove** (1 copy off the reels, never below `MIN_REEL_SYMBOLS`). You can only pick symbols already on your reels this run (of the right rarity), never another machine's signature symbol (Jester, Crown, Hoard chest, Tome).
- Time Forge tree: set `category` (which window: MACHINE/MACHINES = Slot Machines, CASTLE, ARMY = Troops, MERCHANT), `requires` (parent upgrade, in the same window), `requires_level` and `tree_position` (column, row in that window) on a meta upgrade. Set `crown_cost` to make it a crown node (paid with Crowns instead of shards) and `requires_castle` if a castle must be conquered first.
- New kind of effect: add a key to `Stats`, read it where it matters, then make a `.tres` for it.

Progress is saved to `user://meta_progress.cfg` (the Time Forge has a reset button). Saves from before the four-window Time Forge (no `version`) get every shard they spent back, once (`MetaProgress._migrate_to_crowns`). Debug tools (anything started from `res://tools/`) never write the save.

## Slot machine styles

Conquering every other castle lets the player buy a new slot machine with Crowns (1 Willowdale Keep → Old Cellar, 1 crown; 3 Frostpeak Citadel → Jester's 81, 2; 5 Sunken Marsh → Dragon's Hoard, 2; 7 Iron Crypt → Tome of Ages, 3; 9 Stormcrag → Shifting Halls, 3). The player buys and picks it in the Time Forge's Slot Machines window with **Use machine**; each machine has a column of 3 shard upgrades below it, bought top to bottom. The design and research behind them is in `docs/SLOT_MACHINE_STYLES.md`.

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
- A machine's unlock node is a crown node (`crown_cost`) with `requires_castle` set (`GameState.machine_unlock`, `machine_castle`). Its 3 upgrades are ordinary META upgrades (`category = MACHINES`) chained below it; their stats are in the "Machine styles" part of `src/data/stats.gd`.
- Feature symbols have a `max_copies` cap (Jester 2, Crown 1, Tome 1, Chest 3) so buying them can't make the feature trigger every spin.
- An upgrade with `UpgradeData.machine` set only counts while that machine is used (`GameState.applies`): the Gamba Machine's Ancient Blueprints and Extra Row do nothing on the other machines. A node with `machine` but no `stat` is the machine itself (the Gamba Machine's node, owned from the start, `max_level = 0`).

## Adding a castle

Duplicate a file in `data/castles/` (files are numbered `01_` … `10_` in map order), give it a new `id`, a higher `order` and a `map_position` (the map area is 400x210). Then set its starting reels, merchant symbols, spirit roster (`enemies`), `boss`, difficulty numbers and `layout` (its battlefield, see below). It appears on the map after the previous castle. A player who conquered a castle keeps it open even if new castles are inserted before it.

Difficulty ramps across the map: night power (`power_base` + `power_per_night`), threat budget, spawn speed, curse start and Chrono Shard multiplier all grow with the order, and the rules test checks that night 10 gets harder and pays more from castle to castle. Watch the ghost breakpoint: castle bolts hit for 6 and a ghost has 18 HP, so a `power_base` above 1.0 makes every ghost take a fourth bolt.

Balance target (checked with the autoplay bot, `smoke_test.tscn -- --nights=10 --castle=N --shards=S`): each castle is played with the shards a player has when they reach it (two lost runs and one win per earlier castle, plus two lost runs there) and the Crowns of the castles before it. Roughly: castle 1: 0 → falls around night 5-6, 100 → about half the runs win; castle 2: 230; 3: 440; 4: 680; 5: 930; 6: 1210; 7: 1520; 8: 1860; 9: 2230; 10: 2660. At those budgets the bot should win about half the time, and the Ashen Throne should be the hardest. The whole Time Forge costs about 3550 shards, so it is never maxed before the last castle. Raise `power_*` to make spirits tougher (night 10 must keep rising from castle to castle) and cut `budget_*` to send fewer of them.

## Battlefield layouts

Each castle's `layout` is a `BattleLayout` in `data/layouts/` (open one in the Inspector):

- `features`: `LayoutFeature`s. `kind` is MOUNTAIN, WATER, FOREST, WALL or LAVA (all block walking) or BRIDGE (walkable, carves a crossing through the others). The shape is a polygon (`closed = true`) or a polyline drawn `width` pixels wide (`closed = false`, for rivers, walls and bridges). `roughness` wobbles the edges. Coordinates are battlefield pixels: the field is 640x360, the castle wall spans x 262-378 at y 40-104, the gate is at (320, 108). Points may run past the edges.
- `spawn_zones`: where spirits rise (a graveyard is drawn in each). Empty = the band along the bottom.
- `tower_slots`: watchtower spots in build order. Empty = the four default spots beside the castle.
- `rally_points`: named `RallyPoint`s (gate, chokepoint, overwatch, forward, flank) with a position and radius.

How it plays: `BattleNav` turns the layout into an 8 px walking grid with A* paths (`find_path`, `is_clear_line`, `nearest_free`). Walking units follow those paths and slide along edges, and melee units only engage targets they can walk straight at (no fighting across a river). Arrows, spells, castle bolts and flying spirits ignore terrain. `LayoutView` draws everything from the same outlines: graveyards, dirt trails along the real routes to the gate, terrain tiles and props (generated by `tools/generate_art.py`, `environment/terrain/`). The formation snaps onto open ground.

Rules the rules test enforces for every layout: the courtyard `BattleLayout.KEEP_CLEAR` (where the army forms up) and the tower slots are open; every graveyard can reach the gate; rally points are on open ground, reachable from the gate, with unique ids and a `gate` point; only the first castle is an open field, and terrain bends the march on all the others.

**Troop orders (planned):** rally points are the hook for splitting the army into groups and sending each to a spot. `Battlefield.rally_points()` lists them; a group order would set each troop's `home_position` around a point (the way `_assign_formation` lays out rows around the gate), and `Unit` already paths there and holds the spot. To see the spots, run the smoke test with `--layouts`.
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
| Battlefield terrain, graveyards, tower spots, rally points | `data/layouts/*.tres` |
| Pathing grid size and edge clearance | `src/battle/battle_nav.gd` |
| Castle tower range | `src/battle/castle.gd` |
| Watchtower / Mage / Ballista stats | `src/battle/watchtower.gd` (`KINDS`) |
| Curse strength and when it spreads | `data/symbols/tombstone.tres`, castle `curse_start_night` |
| Troop formation, camera zoom, night colour | `src/battle/battlefield.gd` |
| Spin speed, suspense time, win presentation | `src/slot_machine/slot_machine.gd` |
| A machine's cabinet look (colours, ornaments, side panels) | `src/slot_machine/machine_skin.gd`, `machine_cabinet.gd`, art in `tools/generate_art.py` (`SKIN_COLORS`) |
| Attack / death sound per unit | `data/units/*.tres` (Sound group) |
| Default volumes (players change them in Settings) | `src/autoload/audio.gd` |

To add a new symbol: draw it in `tools/generate_art.py`, run the script, then duplicate a `.tres` in `data/symbols/` and change its fields. GameState loads every symbol in that folder automatically.

## Art and audio

```bash
python tools/generate_art.py
```

`python tools/generate_art.py ui` only rewrites the button and panel kit (`assets/sprites/ui/kit/`) that `assets/theme/main_theme.tres` uses: wooden buttons, gold `AccentButton`s for the main action of a screen (set `theme_type_variation`), and grey ones the machines tint for their SPIN button. `python tools/generate_art.py machines` only rewrites the machine symbols and cabinet skins (`assets/sprites/machines/`). Each machine style has a frame, reel strip, marquee, side panel and crest there; `MachineSkin` picks them by the style's id and lists the ornaments `MachineCabinet` animates (lever, bulbs, candles, runes, dragon wings...).

```bash
python tools/generate_audio.py
```

Play any sound from code with `Audio.play(&"coin")`, where the name is a file in `assets/audio/sfx/`.

## Smoke test

```bash
godot --path . res://tools/debug/smoke_test.tscn -- --nights=10
```

Flags: `--machine=<id>` (play a machine style, e.g. `jester_81`), `--castle=N` (which castle; earlier ones count as conquered), `--shards=N` (start with shards and buy Time Forge upgrades), `--idle` (no spins or shopping, so only the castle defends), `--shots=<folder>` (save screenshots; needs a window, so don't use `--headless`), `--layouts` (with `--shots`: just screenshot every castle's battlefield, plain and with the blocked cells and rally points, then quit).

To check how every machine looks, with its feature forced on (nudge arrows, gamble card, hoard round, free spins and an expanding symbol, cascades) and the Time Forge preview:

```bash
godot --path . res://tools/debug/machine_gallery.tscn -- --shots=<folder>
```

Flags: `--machine=<id>` (only one machine), `--rows=N` (row upgrades, for the tallest layouts).

## Rules tests and balance simulator

```bash
godot --headless --path . res://tools/debug/rules_test.tscn
```

Unit tests for the slot rules: lines, ways, wilds, group wins, cascades, nudges, expansions, the hoard, reward caps and every machine's setup, plus the castles (machine unlocks, difficulty ramp) and every battlefield layout (see above). Exits with code 1 on a failure.

```bash
godot --headless --path . res://tools/debug/slot_sim.tscn -- --spins=20000
```

Spins every machine many times with the same pure rules and prints the average value per daily spin (gold + troops + repairs; curse threat has its own column), how it compares with the Gamba Machine, hit rate, feature rate and the biggest spins. Flags: `--castle=N` or `--castle=all` (starting reels), `--night=N` (reels grown by a simulated merchant and curse), `--upgrades` (max the shared slot upgrades and each machine's own branch), `--machine=<id>`.
