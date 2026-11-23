class_name RallyPoint
extends Resource
## A named spot on a battlefield layout where troops could be stationed.
## Nothing sends troops here yet: these are the anchors for the planned army
## orders (split the army into groups, send each group to a spot). Every spot
## is checked by the rules test to be on open ground and reachable from the gate.

enum Kind {
	GATE,  ## In front of the castle gate (where the army forms up today).
	CHOKEPOINT,  ## A bridge, pass or gap that spirits must squeeze through.
	OVERWATCH,  ## Safe ground next to a route, good for archers and casters.
	FORWARD,  ## Far out near the graveyards: catches spirits early, risky.
	FLANK,  ## Side route or alternative path.
}

@export var id: StringName
@export var display_name: String
@export var kind: Kind = Kind.CHOKEPOINT
@export var position: Vector2
## Rough size of the area a group would spread over around `position`.
@export var radius: float = 24.0
