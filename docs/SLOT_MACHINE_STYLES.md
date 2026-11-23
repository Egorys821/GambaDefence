# Slot Machine Styles: Design and Implementation Brief

**Who this is for:** Claude (or any developer) adding new slot machine *styles* to Gamba Defence.
**What it contains:** five slot styles based on real casino slot genres. Each one has its exact rules, how it fits this game's rewards (gold, troops, repair, curse), the code changes it needs, and tests that prove it works.

> Read this whole file first. Then read `src/slot_machine/slot_machine.gd`, `reel.gd`, `line_evaluator.gd`,
> `src/data/paylines.gd` and `src/data/symbol_data.gd` before writing any code. Build **Part 1 (the shared
> foundation)** before any machine. Then build the machines in the order given in Part 3.

---

## Part 0: How the current machine works (as of this doc)

| Piece | File | What it does today |
|---|---|---|
| Spin flow | `src/slot_machine/slot_machine.gd` | `REEL_COUNT := 5` (a constant), rows come from `GameState.machine_rows` (3 to 5). Rolls a grid, stops the reels left to right with a tease, evaluates, then presents each win. |
| Reel | `src/slot_machine/reel.gd` | One column. Its strip holds `rows + 1` cells. `stop_on(symbols)` lands it with a bounce. |
| Rules | `src/slot_machine/line_evaluator.gd` | Pure static functions. Left-to-right run length along each `Payline`. Wilds come from `SymbolData.wild_for`. |
| Lines | `src/data/paylines.gd`, `payline.gd` | Shapes are **5 offsets long** (one per reel). A shape pays at every height where it fits. `MIN_MATCH = 3`, `MATCH_MULTIPLIER = {3:1, 4:2, 5:4}`. |
| Win | `src/slot_machine/line_win.gd` | `payline`, `symbol`, `count`. Presentation reads `win.payline.rows[reel]`. |
| Rewards | `src/day/day_phase.gd` | Listens to `symbols_landed`, `line_won` and `spin_finished`, then pays gold, spawns troops, repairs and adds curse threat. |
| Symbol odds | `GameState.roll_symbol()` | Weighted by copies in `GameState.pool`. **There are no fixed reel strips**: every cell is an independent roll from the pool. Keep it that way, because the merchant economy (buy or banish symbols) depends on it. |
| Symbol effects | `SymbolData.Effect` | `NONE, GOLD, SPAWN_UNIT, REPAIR, WILD, CURSE`, plus `passive_gold` and `passive_threat` per landed copy. |

Hard rules for every style:
- A **style changes the rules and layout, never the economy model.** Payouts still go through `SymbolData.reward_amount()` and DayPhase. Do not invent a separate currency.
- **Tombstones (CURSE) are never substituted by wilds** (`is_wild_for` already blocks this). Every new evaluator must respect that.
- Wilds and scatters **never pay as a curse**.
- Keep the 16px pixel-art look (cell sizes in multiples of 8) and the existing juice: `Fx.pop`, `Fx.burst`, tease glow, `Audio.play`.
- Every number a Time Forge or merchant upgrade could change goes in `src/data/stats.gd` (see README, "Upgrade system").

---

## Part 1: Shared foundation (build this first)

### 1.1 `MachineStyle` resource

Create `src/data/machine_style.gd` (`class_name MachineStyle extends Resource`) and one `.tres` per machine in `data/machines/`. Load them in `GameState` the same way symbols and castles are loaded (`_load_resources`).

```gdscript
class_name MachineStyle
extends Resource

enum Eval {
	LINES,          ## Paylines, left to right (current behaviour).
	WAYS,           ## Every adjacent-reel combination, left to right, any row.
	LINES_OR_WAYS,  ## LINES normally; WAYS on any spin where a trigger symbol is visible (Jester's 81).
}

@export var id: StringName
@export var display_name: String
@export_multiline var description: String
@export var reel_count: int = 5
## Fixed rows. Ignored when variable_rows is on.
@export var rows: int = 3
## Megaways-style: each reel rolls its own height every spin.
@export var variable_rows: bool = false
@export var min_rows: int = 2
@export var max_rows: int = 7
@export var eval_mode: Eval = Eval.LINES
## Line shapes for this machine (row offsets, length == reel_count).
## Empty = use the shared Paylines.SHAPES (5-reel machines only).
@export var line_shapes: Array[PackedInt32Array] = []
@export var min_match: int = 3
## Match length -> multiplier. Must have a key for every length from min_match to reel_count.
@export var match_multiplier: Dictionary = {3: 1, 4: 2, 5: 4}
## Symbol that turns on WAYS for LINES_OR_WAYS (e.g. the Jester).
@export var ways_trigger: SymbolData

@export_group("Features")
@export var cascades: bool = false
@export var gamble: bool = false
@export var book_free_spins: bool = false
@export var scatter: SymbolData          ## Book: the Tome. Hold & Win: unused.
@export var free_spins_award: int = 10
@export var hold_and_win: bool = false
@export var bonus_symbol: SymbolData     ## Hold & Win: the Treasure Chest.
@export var hold_trigger_count: int = 6
@export var hold_respins: int = 3

@export_group("Look")
@export var frame_color: Color = Color("#c08820")
@export var bg_color: Color = Color("#3a2414")
@export var reel_colors: PackedColorArray = [Color("#e8d8b0"), Color("#dccaa0")]
```

`GameState` gets `var machine_style: MachineStyle`, chosen per castle (`CastleData.machine_style`) or bought or unlocked in the Time Forge. The current 5x3 machine becomes `data/machines/0_standard.tres` with `eval_mode = LINES` and empty `line_shapes`, so nothing changes for existing castles.

### 1.2 Generalise the win object

`LineWin` assumes a payline. Replace it with `SlotWin` (keep `LineWin` as a thin subclass or alias until every caller has moved over):

```gdscript
class_name SlotWin
extends RefCounted
var symbol: SymbolData
var count: int                    ## Reels matched from the left (or chest count, or cluster size).
var cells: Array[Vector2i] = []   ## (reel, row) of every cell that is part of the win.
var ways: int = 1                 ## WAYS: number of combinations. Reward = base * ways.
var payline: Payline              ## Null for ways, scatter and hold wins.
var label: String                 ## "Row 2", "81 ways", "Tome x3", "Vault"...
var multiplier: int = 1           ## Comes from style.match_multiplier[count].
var extra_mult: int = 1           ## Gamble, cascade chain or other feature multipliers.
func color() -> Color: ...        ## payline colour, or a fixed colour per win kind.
```

- `SlotMachine._present_win()` loops over `win.cells`, not `payline.rows`.
- `LineOverlay` draws a polyline when `payline != null`, otherwise boxes around `cells`.
- `SymbolData.reward_amount(count, level)` reads the multiplier from the active style. Pass it in: `reward_amount(count, level, style)`. **Gold and repair** scale with `ways * extra_mult`. **Troops** scale with `ways` but are **capped** (`Stats.MAX_TROOPS_PER_WIN`, start at 8), so an 81-ways spin cannot flood the battlefield.

### 1.3 Evaluators

Keep `LineEvaluator` as it is, but make it take `min_match` and the reel count from the style. Add:

- `WaysEvaluator.evaluate(grid, style) -> Array[SlotWin]`. Algorithm (works for fixed and variable heights):
  ```
  for each candidate symbol S that appears on reel 0 (or is covered by a wild on reel 0):
      ways = 1; count = 0; cells = []
      for reel in reel_count:
          hits = cells in grid[reel] where cell == S or cell.is_wild_for(S)
          if hits.is_empty(): break
          ways *= hits.size(); count += 1; cells += hits
      if count >= style.min_match and S.effect not in [NONE]:
          win(S, count, ways, cells)
  ```
  A column of only universal wilds counts as wild hits for every candidate. If reel 0 is all wilds, the candidates are every non-wild, non-curse symbol on reel 1 (repeat for later reels as needed), plus the wild itself (a full wild run pays as the wild).
  Curses: a CURSE symbol is its own candidate and wilds never join it. Tombstones form "curse ways" only from their own copies, which keeps them dangerous but never wild-boosted.
- `ScatterEvaluator.count(grid, symbol) -> int`, for Book scatters and Hold & Win chests.
- `MachineRules.evaluate(grid, style)` picks the evaluator from `eval_mode`. `SlotMachine.spin()` calls this instead of `LineEvaluator.evaluate`.

Update `is_building_big_win` (the tease) for WAYS: tease when the first `reel` reels already form a win for some symbol.

### 1.4 Variable reel count and heights

- Remove `const REEL_COUNT` from `SlotMachine`. Use `style.reel_count`.
- `configure(style)` rebuilds reels when the style changes. `Reel.setup()` already takes `rows`.
- For `variable_rows`, add `Reel.resize(rows, cell_size)`. All reels keep the **same pixel height**, so each reel's cell size = `floor(area_h / rows / 8) * 8` (minimum 16). Call it while the reel is blurred and spinning, before `stop_on`, so the size change is hidden.
- `_roll_grid()` becomes `MachineRules.roll_grid(style)`: it rolls heights first, then cells.

### 1.5 Feature state machine

Bonus features (free spins, hold & win, gamble, cascades) run **inside one press of SPIN**, so DayPhase still sees one `spin_finished`. Add a second signal for UI: `feature_started(kind: StringName)` / `feature_ended(kind, total)`. Free spins do **not** consume `GameState` daily spins. Curses landed during features **still count**. That is the price of the bonus, and it keeps the defence half of the game honest.

### 1.6 Balancing tool (required)

Write `tools/debug/slot_sim.gd` (a headless SceneTree script). It takes a style and a pool, runs 100,000 spins with `MachineRules`, and prints the average gold, troops, repair and curse threat per spin, the hit frequency, the feature trigger rate and the largest win. **Every new style must land within ±15% of the standard machine's average value per spin** with the same starting pool, unless the design says otherwise. Real slots tune RTP the same way. In this game, "return" means value per daily spin.

---

## Part 2: The five machines

Each machine below is written as: **Real-world reference → Our version → Layout → Symbols → Rules → Features → Presentation → Balance → Tests.**

Names: our in-game names are our own. Use the genre mechanics freely, but do not copy real games' names, logos, art or sound. (*Megaways* is a Big Time Gaming trademark, so never put that word in the UI.)

---

### Machine 1: "Jester's 81" (the Joker 81 style) ⭐ the user's pick

**Real-world reference:** *Joker 81* by Kajot. A retro fruit slot on **4 reels × 3 rows**. In the base state it pays on **7 paylines**. When a **Joker** (wild) lands, the game switches to **81 ways to win** (3×3×3×3 = 81: any symbol on each of the 4 reels, adjacent from the left). The Joker substitutes for every other symbol and is the top-paying symbol (about 120× bet for four). Sevens pay about 60×, and fruits pay from about 1× (cherries, lemons) up to about 10× (grapes). Some reviews say **three of a kind does not pay at all**, so only full 4-reel matches pay. There are no free spins and no respins. One review describes an optional **gamble** after a win: guess red or black to double or lose. Medium volatility, RTP about 95–96%. The sources disagree on the reel count (most say 4×3), release date, max win and whether the gamble exists. The design below takes the majority reading.

**Our version:** a compact, punchy machine. Most spins play like a tight 7-line game. Whenever the **Jester** appears, the machine "opens up" to 81 ways and every adjacent match on any row pays.

**Layout**
- `reel_count = 4`, `rows = 3` (fixed: the 81 math needs exactly 3 rows; ignore `Stats.MACHINE_ROWS` for this style and show "Fixed 4×3" in the Time Forge tooltip).
- `eval_mode = LINES_OR_WAYS`, `ways_trigger = jester`.
- `min_match = 3`, `match_multiplier = {3: 1, 4: 3}`. Real Joker 81 pays only on 4. We keep 3-of-a-kind because the base hit rate matters for a defence game, but we make 4 worth a lot more.
- Cell size 48 (4 reels leave room). Frame: deep red `#5a1020` with a gold `#e0b030` border and alternating reel colours `#f0e0c0` / `#e4d0a8`.

**The 7 paylines** (row offsets for 4 reels; our design, because the real line shapes are not published):

| # | Name | Offsets |
|---|---|---|
| 1 | Top | `[0,0,0,0]` |
| 2 | Middle | `[1,1,1,1]` |
| 3 | Bottom | `[2,2,2,2]` |
| 4 | Valley | `[0,1,1,0]` |
| 5 | Hill | `[2,1,1,2]` |
| 6 | Zig | `[0,1,2,2]` |
| 7 | Zag | `[2,1,0,0]` |

Put these in `jester_81.tres` → `line_shapes`. All 7 are active from the start (the machine does not use the merchant's payline shop; instead the merchant can sell **"Jester copy"** offers to raise the 81-ways chance).

**Symbols**
- Uses the player's normal pool (swords, bows, coins, hammers, tombstones...).
- **New symbol `data/symbols/jester.tres`:** `effect = WILD`, `wild_for = []` (universal), `power = 12` (pays gold if a full 4-Jester run lands; this is the top symbol, like the real Joker), `in_shop = true`, `shop_cost = 9`, and `min_night = 1` only on Jester's 81 castles. Art: a 16×16 jester head with a two-colour hat (red/gold) and bells. Generate it with `tools/generate_art.py` in the existing ASCII-map style.
- The castle that uses this machine starts with **2 Jesters** in the pool.

**Rules**
1. Roll a 4×3 grid from the pool.
2. If **no Jester is visible**: evaluate the 7 lines with `LineEvaluator` (left to right, at least 3).
3. If **at least one Jester is visible anywhere**: evaluate with `WaysEvaluator` across all 81 ways. The Jester is wild in both modes.
4. Reward = `reward_amount(count, level) * ways` (troops capped, see 1.2).
5. Tombstones: line or ways wins of tombstones still trigger (wilds never help them), and per-copy `passive_threat` still applies.

**Feature: "Fool's Gamble" (optional, `gamble = true`)**
After a spin whose total **gold** is above 0, show two buttons: **Collect** and **Gamble**. Gamble shows a card face down. The player picks **Red** or **Black**: right doubles the gold of this spin (`extra_mult *= 2`), wrong loses it. They can gamble up to 5 times in a row. Troops and repair are never gambled, so only gold is at risk. Use a separate `randf() < 0.5` (no house edge; the risk itself is the fun). Put a stat `Stats.GAMBLE_MAX_STEPS` (default 5) behind it. Collect is the default for Space, so speed players never lose gold by accident.

**Presentation**
- When the first Jester lands, play `Audio.play(&"tease")`, flash the frame gold, and show a banner **"81 WAYS!"** with a small `Fx.pop` over the reels. Swap the line overlay to cell boxes.
- In ways mode, label wins as `"Sword ×4 · 9 ways"`.
- Tease rule: in ways mode, tease reel 4 when reels 1 to 3 already hold a ways win.

**Balance targets** (check with `slot_sim.gd`)
- 81-ways spins: about 25–35% of spins with 2 Jesters in a 30-symbol pool.
- Average value per spin within ±15% of the standard 5×3 machine with 3 starting lines. If it runs hot, lower `match_multiplier[4]` before touching the Jester count.

**Tests (add to `tools/debug/smoke_test.gd` or a new unit test scene)**
- Grid with no Jester, three Swords on the Middle row → exactly 1 line win, count 3.
- Grid with 1 Jester on reel 2 and Swords at (0,0), (2,1), (3,2) → a ways win for Sword, count 4, ways = 1.
- Grid with 2 Swords on each reel → ways = 16.
- Jester next to Tombstones → **no** curse win made bigger by the wild.
- A full grid of Jesters → one win paying as Jester, ways 81, gold = 12 × 3 × 81, which hits the per-spin gold cap if one exists. Add `Stats.MAX_GOLD_PER_SPIN` if the simulation shows outliers.

---

### Machine 2: "Old Cellar" (the classic 3-reel fruit machine)

**Real-world reference:** the original electromechanical fruit machines and their online versions. **3 reels × 1 or 3 rows**, usually **1 payline** (sometimes 3 to 5). Symbols: cherries, lemons, oranges, plums, bells, single, double and triple **BAR**, and **7**. Cherries are the low, frequent pay, and a **single cherry often pays a small consolation** on its own. Sevens or a special symbol are the jackpot. There is often a **"mixed BAR"** pay (any 3 BARs of different kinds) and sometimes a 2× or 3× wild that **multiplies** the line. Only the highest win per line pays. Fast, simple, high frequency, low feature count.

**Our version:** the starter machine for a "purist" castle and a cheap mode the player can switch into. Every spin resolves in under a second. It feels mechanical and loud.

**Layout**
- `reel_count = 3`, `rows = 3`, `eval_mode = LINES`, `min_match = 3`, `match_multiplier = {3: 1}`.
- `line_shapes`: start with the middle row `[1,1,1]`. The merchant can sell top `[0,0,0]`, bottom `[2,2,2]` and the two diagonals `[0,1,2]` / `[2,1,0]` (5 lines maximum, like classic 5-line fruit games).
- Big 56px cells, chunky chrome frame (`#a0a8b0` border, `#202428` background). Show a **payout window** strip under the reels where the win scrolls up as a counter.

**Symbols and rules**
- **Group pays ("mixed"):** add `@export var group: StringName` to `SymbolData`. Swords, Pikes and Helms get `group = &"melee"`, while Bows and Crossbows get `group = &"ranged"`. Three different symbols of the same group on a line pay a **mixed win**: it uses the cheapest symbol's reward at `count = 3` and spawns that symbol's troop. This is the "any BAR" rule. Implement it as a fallback in `LineEvaluator` when no exact match exists, behind `style.allow_group_pays`.
- **Consolation coin:** a Coin on **reel 1 of an active line** pays `Stats.CONSOLATION_GOLD` (default 1) even with no match. This is the "single cherry" rule. It keeps the 3-reel hit rate high.
- **Multiplier wild:** new symbol `data/symbols/crown_x2.tres`, `effect = WILD`, plus a new export `wild_multiplier = 2`. Each crown on a winning line multiplies it (two crowns = ×4). Three crowns pay as the top symbol. This is the classic "Double/Triple Diamond" rule. Add `wild_multiplier` to `SymbolData` (default 1). LineEvaluator multiplies `extra_mult` by the product of the wild multipliers on the matched cells.

**Feature: "Nudge" (classic UK fruit machine)**
After a losing spin, there is a `Stats.NUDGE_CHANCE` (default 15%) that a **Nudge** button lights up. The player taps a reel to shift it **one row down** (the hidden top cell scrolls in). Re-evaluate. Use at most 1 nudge per spin. Implement it with `Reel.nudge(new_top_symbol)`, which reuses the stop and land animation for 1 cell.

**Presentation:** mechanical `reel_stop` clunks at a lower pitch, a bell chime on wins, and a coin-counter roll-up. No tease (only 3 reels).

**Balance:** low variance. Hit rate around 35–45% of spins (including consolation). Average value about 90% of the standard machine, but the player gets **+1 spin per day** on this machine (`Stats.SPINS_PER_DAY` modifier on the style) to make up for it.

**Tests:** a mixed melee line pays; a consolation coin pays only on reel 1 of an active line; one crown in a winning line doubles the reward; two crowns ×4; a nudge changes exactly one reel by one row.

---

### Machine 3: "Tome of Ages" (the book-style expanding-symbol slot)

**Real-world reference:** the "Book" genre (*Book of Ra*, *Book of Dead* and hundreds of clones). **5 reels × 3 rows, 10 paylines.** One **Book** symbol is **both wild and scatter**. **3 or more Books anywhere** trigger **10 free spins**. At the start of free spins, **one regular symbol is chosen at random** to be the **expanding symbol** (never the Book itself). During free spins, whenever that symbol lands, it **expands to fill its whole reel** (only when that makes a win) and **pays on every line, even on reels that are not adjacent**. 3+ Books during free spins **retrigger** another 10 spins with the same expanding symbol. High volatility: long dry stretches, then huge free-spin rounds. RTP about 96%.

**Our version:** fits the time-traveller theme (an ancient tome in the castle cellar). A **high-volatility** machine for players who like to gamble on one big day.

**Layout:** `reel_count = 5`, `rows = 3` (rows upgrades allowed: 4 to 5 rows make the expansion even stronger), `eval_mode = LINES`, empty `line_shapes` (uses the shared `Paylines.SHAPES` and the merchant line shop), `book_free_spins = true`, `scatter = tome`, `free_spins_award = 10`. Frame: dark brown leather `#2a1a10`, aged-gold border `#b89040`, parchment reels.

**Symbols**
- **New symbol `tome.tres`:** `effect = WILD` (universal) **and** acts as the scatter for this style. Add `@export var is_scatter := false` to `SymbolData`. `power = 10` (5 Tomes on a line pay gold like a top symbol). Art: an open glowing book.
- All other symbols come from the pool.

**Rules: base game**
1. Normal line evaluation. The Tome substitutes.
2. **Scatter pay:** count Tomes anywhere (`ScatterEvaluator`). 3+ → trigger free spins. Also pay `power × (count − 2)` gold as a scatter win (this is how real book slots pay scatters).

**Rules: free spins ("Tome Reading")**
1. Pick the **expanding symbol**: random from the **symbol types currently in the pool**, weighted equally per type (not by copies), excluding Tome, Skull and Tombstone. **Tombstones can never expand.** Show the choice with a page-flip animation that cycles through symbols and lands on one (about 1.5 s).
2. Spin `free_spins_award` times automatically (about 0.8 s apart, Space skips). These do not use daily spins.
3. Each free spin: evaluate the lines normally first. Then the **expansion pass**: count how many **reels** contain the expanding symbol at least once (any row, wilds do **not** count for this). If the count ≥ 3 (or ≥ 2 if it is a "premium" symbol with `power ≥ 8`), visually fill those reels with it, then pay it on **every active payline** as `count` matches, **ignoring adjacency** (`SlotWin.cells` = every cell of the expanded reels on that line). Expansion wins are added to the normal wins (real book slots pay both).
4. 3+ Tomes during free spins → +`free_spins_award` spins, same expanding symbol, shown with a "+10" banner.
5. At the end, show a total panel ("Tome Reading: 340 gold, 12 Swordsmen") → `feature_ended`.

**Presentation:** Tomes landing on reels 1 and 2 → tease the remaining reels for the 3rd (reuse `set_tease`). The expansion is a column-wide golden wipe from the cell up and down, then `Fx.burst` per reel. Use a slower, choral version of the win jingle during free spins.

**Balance:** trigger about 1 in 60–90 spins with 1 Tome in a 30-symbol pool (real slots are about 1 in 150–250; ours is higher because a run only has about 60–100 spins). Base game value about 70% of standard; the free spins make up the rest. Check in the simulator that a free-spin round's **median** is about 8–15 base spins of value, and that the **troop cap** keeps one round from deciding a night by itself. Curses during free spins still add threat, so the bonus can also backfire.

**Tests:** 3 Tomes → exactly 10 free spins queued; the expanding symbol is never Tome or Tombstone; expansion pays with reels 1, 3 and 5 holding the symbol (non-adjacent); retrigger adds 10 without re-picking; free spins do not decrease `GameState` daily spins.

---

### Machine 4: "Shifting Halls" (the Megaways-style variable-reel slot)

**Real-world reference:** the *Megaways* engine (invented by Big Time Gaming in 2015, *Bonanza*, and licensed to many studios since). **6 reels**, and **each reel shows a random 2 to 7 symbols every spin**. Wins are **ways**: matching symbols on adjacent reels from the left, any row. Ways per spin = the product of the reel heights. A 3-4-5-6-7-2 spin = 5,040 ways, and all 7s = **117,649 ways**. Almost always paired with **cascades** (winning symbols disappear, new ones drop in, and the board re-evaluates until nothing wins) and often with a free-spins mode where an **unlimited multiplier** rises by +1 each cascade. Some versions add a horizontal reel above reels 2 to 5 for extra symbols. High volatility.

**Our version:** the late-game "chaos" machine (good for the Ashen Throne castle or a Time Forge unlock). Huge numbers of ways, chained cascades and a ways counter that ticks every spin.

**Layout:** `reel_count = 6`, `variable_rows = true`, `min_rows = 2`, `max_rows = 7`, `eval_mode = WAYS`, `min_match = 3`, `match_multiplier = {3: 1, 4: 2, 5: 3, 6: 5}`, `cascades = true`. The reel window is a fixed **168px** tall area. Cell size = `floor(168 / rows / 8) * 8`, which gives 24px at 7 rows and 80px at 2 rows (clamp it to 56px). `Stats.MACHINE_ROWS` upgrades raise `min_rows` (3 → 4) instead of rows. Frame: dark stone `#1c1c28` with a cyan glow border `#40d8f0`. Show a **"WAYS: 5,040"** counter above the reels that rolls up as the reels land.

**Rules**
1. Roll a height per reel (uniform in `[min_rows, max_rows]`; skew toward the middle with the sum of 2 rolls if the simulation shows too many extreme spins). Then roll every cell from the pool.
2. Evaluate with `WaysEvaluator`. Reward per win = `reward_amount(count) × ways × cascade_mult`. **This can explode**: always apply the gold and troop caps, and also cap the ways used **for troops** at `Stats.MAX_TROOPS_PER_WIN`.
3. **Cascade loop:**
   ```
   chain = 0
   loop:
       wins = WaysEvaluator.evaluate(grid, style)
       if wins.is_empty(): break
       present wins (with cascade_mult = 1 + chain); emit line_won for each
       remove every cell in any win's cells (curse wins too: tombstones that formed a curse win also explode)
       drop the remaining symbols down in each reel, roll new symbols in from the top (reel height stays the same)
       chain += 1
   ```
   `symbols_landed` fires **only for the first drop** so `passive_gold` and `passive_threat` count once per spin, or once per new symbol if you pass the new cells. Pick one way and document it. Recommended: count passive effects for **every symbol that lands**, including cascaded ones. Cascades then also bring more tombstones, which balances them.
4. Hard cap: `Stats.MAX_CASCADES` (default 8), to keep spins short.

**Reel changes:** `Reel.resize(rows, cell)` (1.4) and `Reel.cascade(removed_rows: Array[int], new_symbols: Array)`: tween the remaining cells down (0.18 s, `TRANS_QUAD`) and the new ones in from above, then a small bounce. Removed cells play `Fx.burst` in the win colour first.

**Feature: "Echoing Halls" (free spins, optional):** 4+ **Hourglass** scatters (new symbol, `is_scatter = true`, `effect = NONE`) → 8 free spins with a multiplier that **never resets**: it starts at ×1 and goes +1 on every cascade across the whole round. Real *Bonanza*-style games use an unlimited multiplier. Cap ours at `Stats.MAX_FREE_SPIN_MULT` (default 10) for balance.

**Presentation:** per-reel height changes hidden under motion blur, the ways counter rolling up, and the chain number "×3" popping over the board on each cascade with a rising pitch (`Audio.play(&"win", 1.0 + chain * 0.1)`).

**Balance:** the most volatile style. Target the same **mean** value as the standard machine, with a much wider spread. The simulator must report the 99th-percentile spin. If a single spin ever pays more than about 15 days of the standard machine's average, lower `match_multiplier` or tighten the caps.

**Tests:** heights [3,4,5,6,7,2] → displayed ways 5,040; a sword on every reel 1 to 3 (one per reel) → ways = 1, count 3; a cascade removes exactly the winning cells and refills to the same height; the chain stops at `MAX_CASCADES`; wilds never join tombstone ways.

---

### Machine 5: "Dragon's Hoard" (the Hold & Win / Link-style slot)

**Real-world reference:** the Hold & Win family (*Lightning Link*, *Dragon Link* and countless "Hold and Spin", "Cash Collect" and "Link & Win" games). A normal **5×3** base game, plus **bonus coin symbols that carry a visible prize value**. **6 or more coins** trigger the feature: the coins **lock in place**, every other cell becomes blank, and the player gets **3 respins**. Each respin, only the empty cells spin. **Any new coin locks and resets the respins to 3.** The round ends when the respins run out or the grid is full. Then all coin values are added up. Some coins show named jackpots (**Mini / Minor / Major**), and **filling all 15 cells pays the Grand**. Studios differ in trigger counts, prize values and reset rules, but this loop is the core.

**Our version:** a treasure-vault machine. It mixes well with the defence theme because the coins can carry **gold, troops or repair**, not just cash.

**Layout:** `reel_count = 5`, `rows = 3` (rows upgrades allowed; 4 to 5 rows make the grid bigger and the Grand harder but the feature richer), `eval_mode = LINES` for the base game with the shared shapes, `hold_and_win = true`, `bonus_symbol = treasure_chest`, `hold_trigger_count = 6`, `hold_respins = 3`. Frame: dark green `#102a1c` with an emerald border `#30c070`. Feature background: black with gold dust.

**Symbols**
- **New symbol `treasure_chest.tres`:** `effect = NONE` on lines (does not pay on paylines), `is_bonus = true` (new export). Each landed chest **rolls a prize** when it lands (store it in a parallel `prize_grid`, not on the shared resource):

  | Prize | Weight | Value |
  |---|---|---|
  | Small gold | 55 | `coin.power × 1..3` gold (scales with the Coin level) |
  | Big gold | 20 | `coin.power × 5` gold |
  | Troops | 12 | 2 troops of a random **unit symbol in the pool** |
  | Repair | 8 | 15 castle HP |
  | **MINI** | 4 | 25 gold |
  | **MINOR** | 0.9 | 60 gold + 4 troops |
  | **MAJOR** | 0.1 | 150 gold + castle full repair |
  | **GRAND** | n/a | only for filling every cell: 300 gold + 10 troops + full repair |

  Put these numbers in a `HoardPrizes` table (`src/data/hoard_prizes.gd`) so they are easy to tune.
- The chest shows its prize as small pixel text or an icon on the chest (draw it with a `Label` child on the reel cell, using the theme's pixel font).

**Rules: base game**
1. Normal lines with the player's pool.
2. Chests landed in the base game but fewer than 6 → nothing (they only show a teasing shimmer). Optional "Collector" variant: a chest on reel 5 collects every chest on screen. Leave it out for v1.

**Rules: Hold & Win ("Hoard Run")**
1. Trigger: `ScatterEvaluator.count(grid, chest) >= hold_trigger_count`.
2. Lock every chest cell (gold border plus a gentle bob). Every non-chest cell becomes empty (dark).
3. `respins = hold_respins`. Loop:
   - Spin **only unlocked cells**. Each empty cell independently becomes a chest with probability `Stats.HOARD_CHEST_CHANCE` (default ~**0.10** on 15 cells; scale it down with more cells: `0.10 × 15 / cell_count`). **Do not** roll from the pool here: the feature uses its own odds so tombstones cannot appear. Optionally, at `curse_start_night` and later, a cell can land a **Ghost** that locks an empty cell, blocks the Grand and adds 1 threat. This keeps the curse theme. Keep it off by default (`Stats.HOARD_GHOST_CHANCE = 0`).
   - New chest(s) landed → lock them and set `respins = hold_respins`. Otherwise `respins -= 1`.
   - All cells filled → GRAND, end.
   - `respins == 0` → end.
4. Payout: add up every chest's prize (gold total, troops grouped by unit, repair total), plus the Grand if the grid is full. Emit as one `SlotWin` per prize kind so DayPhase's existing gold, troop and repair handlers do the work. Cap troops at the hoard-specific `Stats.MAX_HOARD_TROOPS` (default 16).

**Implementation notes**
- Add `Reel.spin_cells(mask: Array[bool])` / `Reel.stop_cells(mask, symbols)` so a reel can spin some rows and hold others. Simplest approach: for the feature, swap the reel area for a **grid of 15 independent one-cell "mini reels"** (`Reel` with `rows = 1`). That is how real Hold & Win games do it, and it reuses `Reel` unchanged.
- Show a **respin counter** with 3 pips that refill with a flash on reset.
- Tease: when only 1 or 2 cells remain empty, give those cells a long spin and a heartbeat sound.

**Balance:** trigger about 1 in 70 spins with 3 chests in a 30-symbol pool (simulate it). Average feature value about 12–20 standard spins. The Grand should hit in fewer than 1% of features. Base game about 75% of standard value.

**Tests:** 5 chests → no feature; 6 → feature; a new chest resets respins to 3; no new chest decrements; a full grid pays the Grand plus every chest; the feature never rolls a Tombstone; troops are capped.

---

## Part 3: Build order and checklist

1. **Foundation** (Part 1): `MachineStyle`, `SlotWin`, `MachineRules` + `WaysEvaluator` + `ScatterEvaluator`, variable `reel_count`, `slot_sim.gd`. Port the current machine to `0_standard.tres` and confirm that **the smoke test still passes and the simulator matches the old values**.
2. **Jester's 81**: proves `reel_count = 4`, per-style line shapes, WAYS and the LINES_OR_WAYS switch. Smallest risk, and it is the user's top pick.
3. **Old Cellar**: proves 3 reels, group pays, multiplier wilds and nudge.
4. **Tome of Ages**: proves the feature state machine (free spins, symbol expansion, non-adjacent pays).
5. **Dragon's Hoard**: proves locked cells, respins, prize values and the mini-reel grid.
6. **Shifting Halls**: the hardest (variable heights + cascades). Build it last, when everything else is stable.

For each machine:
- [ ] `data/machines/<n>_<id>.tres` with every field set
- [ ] new symbols in `data/symbols/` + art in `tools/generate_art.py`
- [ ] new stats in `src/data/stats.gd` with base values
- [ ] Paytable panel (`src/day/paytable.gd`) explains the style's rules in one or two lines (e.g. "Jester on screen → 81 WAYS")
- [ ] tutorial text (`src/ui/tutorial.gd`) for the first time a style is used
- [ ] unit cases from the machine's **Tests** section
- [ ] simulator results pasted into the PR description
- [ ] README updated (project layout + "Adding a machine style" section)

## Part 4: Glossary (casino terms → this codebase)

| Term | Meaning | Here |
|---|---|---|
| Payline | A fixed path across the reels | `Payline`, `Paylines.SHAPES`, `MachineStyle.line_shapes` |
| Ways | Every adjacent left-to-right combo, any row; ways = product of the matching counts per reel | `WaysEvaluator`, `SlotWin.ways` |
| Wild | Substitutes for other symbols | `Effect.WILD`, `wild_for`, never for CURSE |
| Scatter | Pays or triggers anywhere, no line needed | `SymbolData.is_scatter`, `ScatterEvaluator` |
| Expanding symbol | Fills its whole reel in free spins | Tome of Ages |
| Cascade / tumble | Wins vanish, new symbols drop, re-evaluate | Shifting Halls |
| Hold & Win | Bonus symbols lock, respins reset on new ones | Dragon's Hoard |
| RTP | Long-run % of stake returned | Here: **average value per daily spin** from `slot_sim.gd` |
| Volatility | How spread out the wins are | 99th-percentile spin vs the mean in the simulator |
| Hit frequency | % of spins with any win | Simulator output |
| Gamble | Double-or-nothing after a win | Fool's Gamble (gold only) |
| Nudge | Shift a reel one step after a loss | Old Cellar |

## Sources (research, November 2026)

- Joker 81 (Kajot): [SlotCatalog](https://slotcatalog.com/en/slots/Joker-81), [VegasSlotsOnline](https://www.vegasslotsonline.com/kajot/joker-81), [Sigma](https://sigma.world/play/games/kajot/joker-81/). Not to be confused with *Respin Joker 81* / *81 Joker Fruits* (Synot) or *81 Joker Hot Reels* (Playtech), which are different games.
- Megaways: [Racing Post](https://www.racingpost.com/online-casino/articles/what-are-megaways-slots/), [Hard Rock Bet](https://www.hardrock.bet/casino/how-to-play-slots/megaways/)
- Hold & Win: [CCN](https://www.ccn.com/education/gambling/hold-and-spin/), [Track360 operator guide](https://track360.io/blog/hold-and-win-respin-slots-operator-guide-2026)
- Book-style expanding symbols: [game-cave Book of Dead summary](https://game-cave-com.pages.dev/slots/book-of-dead)
- Classic fruit machines: [iGaming Business, 777 Fruity Classic](https://igamingbusiness.com/company-news/3-oaks-gaming-revives-retro-gaming-experience-with-777-fruity-classic/), [Gambling.com, Lucky 7](https://www.gambling.com/us/online-casinos/slots/lucky-7)

Many slot-review sites disagree on details (paytables, RTP, max win). Where they did, this doc took the majority reading and marked our own design choices as ours.

---

## Part 5: As built (November 2026)

All five machines are implemented. Balancing with `tools/debug/slot_sim.tscn` (first castle's starting reels, 40,000 spins) changed some numbers from Part 2. The starting reels hold only a few symbol kinds, so ways and scatter machines hit far more often than in a real casino. The fixes below bring every machine to within about ±15% of the Gamba Machine's value per daily spin.

| Machine | What changed from the design | Value / spin (standard = 2.3) |
|---|---|---|
| Old Cellar | 3 in a row pays x1 (not x2). The lucky coin counts only in the middle of reel 1, once, on a losing spin. No free Crown and no extra daily spin. | 2.0 |
| Jester's 81 | Ways spins pay only 4 of a kind, like the real Joker 81. Multipliers are x0.6, ways never multiply a reward (`ways_cap = 1`). Starts with 1 Jester and the 3 straight rows; the merchant sells the other 4 shapes. | 2.0 |
| Dragon's Hoard | 2 starting chests. Respin chest chance is 8% per cell (for 15 cells). | 2.6 |
| Tome of Ages | Tomes count once per reel (3 reels needed). 3 free spins, capped at 20 per feature. The expanding symbol needs 4 reels. Base wins are low (x0.4 / x0.8 / x1.6). | 2.7 |
| Shifting Halls | Reels are 2-4 rows tall. 5+ adjacent reels pay (x0.5, x1). The chain multiplier starts at x1. At most 5 cascades. | 2.6 |

Other choices:
- **Rewards:** ways, chains and multiplier wilds are capped in `SlotWin` (troops at most x3, gold and repairs at most x12). Ways multiply a reward only up to `MachineStyle.ways_cap`.
- **Upgrades:** the upgrades that would add feature symbols (chests, Tomes) made features trigger 40% of the time on small reels. They became Golden Hoard (+15% Hoard gold) and Scholar's Tome (gold per Tome). With every machine upgrade maxed, value per spin is about 5 (Cellar, Jester, Tome) to 9.5 (Hoard, Halls).
- **Machine choice:** it lives in the Time Forge, as a "Slot Machines" branch with a "Use machine" button. The choice is saved in `MetaProgress.selected_machine`. A machine that is no longer unlocked (after a refund) falls back to the Gamba Machine.

### Balance pass 2 (November 2026)

Machines are now **castle rewards**: conquering castle 1 to 5 unlocks Old Cellar, Jester's 81, Dragon's Hoard, Tome of Ages and Shifting Halls in that order. They can't be bought with shards; their 3 upgrades still cost shards.

The simulator now checks every castle's starting reels, mid-run reels (`--night=6`: 2 random merchant buys a day, curse spread, 1 banish a day) and end-game upgrades (`--upgrades`, including the shared slot upgrades). Fixes:
- **Symbol caps (`SymbolData.max_copies`):** Jester 2, Crown 1, Tome 1 (not sold), Chest 3. Without caps, bought feature symbols made Hoard and Tome trigger on 30-40% of spins (10-30x standard).
- **Old Cellar:** mixed wins need 3 *different* symbols of one group and no wilds, like a classic "any BAR", and pay half. Nudge chance is 15% (Sticky Reels +10% per level).
- **Fixed-row machines** (Cellar, Jester, Halls) get +30% rewards per row upgrade, so the shared row upgrades help them too.
- **Dragon's Hoard:** chests needed grow 20% per extra row. Respin chest chance is 7%. Gold chests pay 1-2x coin, with a lower 4x big chest. Jackpots are 15 / 40+3 troops / 100+repair / 200+8 troops+repair. Dragon's Nose became Treasure Map (+1 starting chest).
- **Tome of Ages:** x0.4 / x0.7 / x1.4, Long Chapter +1 spin. Scholar's Tome replaced the extra-Tome upgrade.
- **Jester's 81:** x0.6 / x0.5. Full House adds +50% per level.

Value vs the Gamba Machine (5,000 spins per cell):

| Scenario | Cellar | Jester | Hoard | Tome | Halls |
|---|---|---|---|---|---|
| Night 1, castle 1 | 84% | 85% | 100% | 108% | 111% |
| Night 1, castles 2-5 | 102-115% | 124-127% | 139-169% | 118-140% | 81-97% |
| Night 6, all castles | 147-213% | 110-189% | 95-144% | 63-97% | 81-115% |
| Night 6, all upgrades | 76-113% | 90-151% | 87-99% | 120-158% | 100-181% |

Machines unlocked by later castles are mostly a little stronger there, on purpose: those castles are harder. The night-6 baseline is pessimistic for line machines, because the simulated merchant buys random symbols where a real player would focus on a few.
