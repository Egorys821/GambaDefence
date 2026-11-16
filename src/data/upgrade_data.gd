class_name UpgradeData
extends Resource
## An upgrade that adds `value_per_level` to a stat (see Stats) for each level owned.
##
## META upgrades are bought in the Time Forge with Chrono Shards and are kept
## forever. RUN upgrades are sold by the merchant for gold and last one run.
## Instances live in res://data/upgrades/meta/ and res://data/upgrades/run/.

enum Scope { META, RUN }
enum Category { MACHINE, CASTLE, ARMY }

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
@export var max_level: int = 1

@export_group("Tree")
## Must own `requires_level` levels of this upgrade first (Time Forge tree parent).
@export var requires: UpgradeData
@export var requires_level: int = 1
## Grid cell in the Time Forge tree (column, row). Fractions are fine.
@export var tree_position: Vector2

@export_group("Cost")
## Price of level 1. Each further level costs `cost_per_level` more.
## Chrono Shards for META upgrades, gold for RUN upgrades.
@export var base_cost: int = 10
@export var cost_per_level: int = 5
## RUN only: first night the merchant may offer it.
@export var min_night: int = 1


func cost_at(current_level: int) -> int:
	return base_cost + cost_per_level * current_level


func is_maxed(current_level: int) -> bool:
	return current_level >= max_level


func value_text(levels: int = 1) -> String:
	var value := value_per_level * levels
	if percent:
		return "%d%%" % roundi(value * 100.0)
	if is_equal_approx(value, roundf(value)):
		return "%d" % roundi(absf(value))
	return "%.1f" % absf(value)


func describe() -> String:
	return description.format({"value": value_text()})
