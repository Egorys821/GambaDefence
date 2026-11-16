class_name Stats
extends RefCounted
## Every tunable number that upgrades can change, with its base value.
##
## The effective value is BASE + bonuses from permanent (Time Forge) upgrades
## + bonuses from upgrades bought during the current run. Read it with
## GameState.stat(Stats.CASTLE_MAX_HP).
##
## To add a new kind of upgrade: add a key + base value here, read it where it
## matters with GameState.stat(), then create an UpgradeData .tres using the key.

# --- Slot machine ---
const MACHINE_ROWS := &"machine_rows"        ## Rows on the reels (3..5).
const SPINS_PER_DAY := &"spins_per_day"
const START_PAYLINES := &"start_paylines"    ## Extra (non-row) paylines owned at run start.
const START_GOLD := &"start_gold"
const STARTING_SKULLS := &"starting_skulls"  ## Cursed Skulls on the reels at run start.
const SHOP_SLOTS := &"shop_slots"            ## Offers the merchant shows each day.
const SHOP_DISCOUNT := &"shop_discount"      ## Fraction off every merchant price (0.1 = 10%).
const COIN_LINE_BONUS := &"coin_line_bonus"  ## Extra gold for every winning gold line.
const CURSE_DELAY := &"curse_delay"          ## Nights the curse starts spreading later.

# --- Castle ---
const CASTLE_MAX_HP := &"castle_max_hp"
const TOWER_DAMAGE := &"tower_damage"        ## Damage of castle and watchtower bolts.
const TOWER_SPEED := &"tower_speed"          ## Bolts per second per tower.
const EXTRA_TOWERS := &"extra_towers"        ## Watchtowers standing on the field.
const MAGE_TOWERS := &"mage_towers"          ## Watchtowers upgraded to Mage Towers (splash).
const BALLISTA_TOWERS := &"ballista_towers"  ## Watchtowers upgraded to Ballistae (heavy, long range).
const DAWN_HEAL := &"dawn_heal"              ## Castle HP repaired every dawn.
const DAWN_GOLD := &"dawn_gold"              ## Gold every dawn (plus the night number).
const KILL_BOUNTY := &"kill_bounty"          ## Extra gold per spirit destroyed.
const TOWER_RANGE := &"tower_range"          ## Range bonus for all towers (0.15 = +15%).
const ENEMY_SLOW := &"enemy_slow"            ## Spirits move this much slower (0.1 = 10%).

# --- Army ---
const TROOP_POWER := &"troop_power"          ## HP/damage multiplier for summoned troops.
const GARRISON := &"garrison"                ## Swordsmen standing guard at run start.
const TROOP_SPEED := &"troop_speed"          ## Troop move-speed bonus (0.15 = +15%).
const FREE_TROOPS := &"free_troops"          ## Troops that cost no upkeep at dawn.
## Troop unlocks (1 = the merchant sells that symbol in every castle).
## Symbols point at these through SymbolData.unlock_stat.
const UNLOCK_PIKEMEN := &"unlock_pikemen"
const UNLOCK_CROSSBOWS := &"unlock_crossbows"
const UNLOCK_CLERICS := &"unlock_clerics"
const UNLOCK_RUNE := &"unlock_rune"

const BASE := {
	MACHINE_ROWS: 3,
	SPINS_PER_DAY: 6,
	START_PAYLINES: 0,
	START_GOLD: 5,
	STARTING_SKULLS: 2,
	SHOP_SLOTS: 3,
	CASTLE_MAX_HP: 100,
	TOWER_DAMAGE: 6,
	TOWER_SPEED: 1.0,
	EXTRA_TOWERS: 0,
	DAWN_HEAL: 0,
	DAWN_GOLD: 3,
	KILL_BOUNTY: 0,
	TROOP_POWER: 1.0,
	GARRISON: 0,
	FREE_TROOPS: 10,
}

## Hard limits so upgrades can never break the game.
const LIMITS := {
	MACHINE_ROWS: Vector2(3, 5),
	SPINS_PER_DAY: Vector2(1, 12),
	SHOP_SLOTS: Vector2(1, 4),
	STARTING_SKULLS: Vector2(0, 10),
	EXTRA_TOWERS: Vector2(0, 4),
	SHOP_DISCOUNT: Vector2(0, 0.6),
	ENEMY_SLOW: Vector2(0, 0.6),
}
