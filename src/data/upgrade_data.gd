class_name UpgradeData
extends Resource
## An upgrade that adds `value_per_level` to a stat (see Stats) for each level owned.
##
## META upgrades are bought in the Time Forge with Chrono Shards (or, for the
## big "crown" nodes, with Crowns won by conquering castles) and are kept
## forever. RUN upgrades are the merchant's own upgrade tree: sold for gold,
## they last one run and each has a rarity (see MerchantRarity).
## Instances live in res://data/upgrades/meta/ and res://data/upgrades/merchant/.

enum Scope { META, RUN }
## Time Forge window. MACHINE and MACHINES (other slot machines, see
## MachineStyle, and their own upgrades) share the "Slot Machines" window.
enum Category { MACHINE, CASTLE, ARMY, MACHINES, MERCHANT }

@export var id: StringName
@export var display_name: String
@export var icon: Texture2D
## Use {value} for the bonus per level, e.g. "+{value} castle HP".
@export_multiline var description: String
@export var scope: Scope = Scope.META
@export var category: Category = Category.CASTLE

@export_group("Effect")
## Key from Stats, e.g. &"castle_max_hp".
@export var stat: StringName
@export var value_per_level: float = 1.0
## Show the value as a percentage (0.1 -> "10%").
@export var percent: bool = false
## 0 = nothing to buy: the node is owned from the start (a machine's own node).
@export var max_level: int = 1
## Machine style id this upgrade belongs to: it only counts while that machine
## is used. Empty = every machine. With no `stat`, the node is the machine
## itself (the Gamba Machine, which needs no unlock).
@export var machine: StringName

@export_group("Tree")
## Must own `requires_level` levels of this upgrade first (Time Forge tree parent).
@export var requires: UpgradeData
@export var requires_level: int = 1
## Grid cell in its Time Forge window (column, row). Fractions are fine.
@export var tree_position: Vector2
## If set, this castle must be conquered before the upgrade can be bought
## (slot machine unlocks open one by one along the kingdom map).
@export var requires_castle: CastleData

@export_group("Cost")
## Price of level 1. Each further level costs `cost_per_level` more.
## Chrono Shards for META upgrades, gold for RUN upgrades.
@export var base_cost: int = 10
@export var cost_per_level: int = 5
## META only: if above 0, each level costs this many Crowns instead of shards.
## Crown nodes are the big ones: new machines and the keys to whole subtrees.
@export var crown_cost: int = 0
## RUN only: first night the merchant may offer it.
@export var min_night: int = 1

@export_group("Merchant")
## RUN only: which rarity token from the merchant's bag can bring this offer.
@export var rarity: MerchantRarity.Tier = MerchantRarity.Tier.COMMON


## Paid with Crowns instead of Chrono Shards.
func is_crown_node() -> bool:
	return crown_cost > 0


## Price of the next level, in shards (or Crowns for crown nodes).
func cost_at(current_level: int) -> int:
	if is_crown_node():
		return crown_cost
	return base_cost + cost_per_level * current_level


func is_maxed(current_level: int) -> bool:
	return current_level >= max_level


## A node that stands for a machine and is owned from the start.
func is_machine_node() -> bool:
	return stat == &"" and machine != &""


func value_text(levels: int = 1) -> String:
	var value := value_per_level * levels
	if percent:
		return "%d%%" % roundi(value * 100.0)
	if is_equal_approx(value, roundf(value)):
		return "%d" % roundi(absf(value))
	return "%.1f" % absf(value)


func describe() -> String:
	return description.format({"value": value_text()})
