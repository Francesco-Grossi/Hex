## UnitData.gd
## Defines every unit archetype in one place.
##
## Per-unit move_costs key on TerrainData.Base (the ground layer):
##   0 = FLAT  |  1 = HILLY  |  2 = MOUNTAIN  |  3 = WATER
##
## The static move_cost() function takes the MAX of:
##   • the unit's own cost for the base terrain
##   • the cell's overlay move_cost (from TerrainData.OVERLAY_DATA)
## so the most restrictive layer always wins — a wall on flat ground
## is impassable even for a unit with flat-cost 1.

class_name UnitData

enum Faction { PLAYER, ENEMY }

enum Type {
	KNIGHT,
	ARCHER,
	MAGE,
	ORC,
	GOBLIN,
	TROLL,
}

const UNITS: Dictionary = {

	Type.KNIGHT: {
		"name":       "Knight",
		"faction":    Faction.PLAYER,
		"hp_max":     12,
		"attack":     4,
		"move_range": 4,
		"body_color": Color(0.20, 0.40, 0.80),
		"trim_color": Color(0.85, 0.75, 0.20),
		"move_costs": {
			0: 1,   # FLAT
			1: 2,   # HILLY
			2: 99,  # MOUNTAIN
			3: 99,  # WATER
		},
	},

	Type.ARCHER: {
		"name":       "Archer",
		"faction":    Faction.PLAYER,
		"hp_max":     8,
		"attack":     3,
		"move_range": 5,
		"body_color": Color(0.15, 0.55, 0.20),
		"trim_color": Color(0.75, 0.55, 0.20),
		"move_costs": {
			0: 1,
			1: 1,   # rangers are nimble on hills
			2: 3,   # mountains: slow but passable
			3: 99,
		},
	},

	Type.MAGE: {
		"name":       "Mage",
		"faction":    Faction.PLAYER,
		"hp_max":     6,
		"attack":     5,
		"move_range": 3,
		"body_color": Color(0.55, 0.15, 0.70),
		"trim_color": Color(0.90, 0.85, 1.00),
		"move_costs": {
			0: 1,
			1: 2,
			2: 99,
			3: 99,
		},
	},

	Type.ORC: {
		"name":       "Orc",
		"faction":    Faction.ENEMY,
		"hp_max":     10,
		"attack":     4,
		"move_range": 4,
		"body_color": Color(0.25, 0.45, 0.10),
		"trim_color": Color(0.60, 0.20, 0.10),
		"move_costs": {
			0: 1,
			1: 2,
			2: 3,
			3: 99,
		},
	},

	Type.GOBLIN: {
		"name":       "Goblin",
		"faction":    Faction.ENEMY,
		"hp_max":     5,
		"attack":     2,
		"move_range": 6,
		"body_color": Color(0.30, 0.50, 0.10),
		"trim_color": Color(0.80, 0.70, 0.10),
		"move_costs": {
			0: 1,
			1: 1,
			2: 2,
			3: 99,
		},
	},

	Type.TROLL: {
		"name":       "Troll",
		"faction":    Faction.ENEMY,
		"hp_max":     18,
		"attack":     5,
		"move_range": 3,
		"body_color": Color(0.40, 0.35, 0.30),
		"trim_color": Color(0.20, 0.20, 0.20),
		"move_costs": {
			0: 1,
			1: 2,
			2: 2,
			3: 3,   # trolls can wade
		},
	},
}


static func get_info(type: Type) -> Dictionary:
	return UNITS[type]

static func get_name(type: Type) -> String:
	return UNITS[type]["name"]

static func get_faction(type: Type) -> Faction:
	return UNITS[type]["faction"]

## Cost for this unit type to enter a hex cell.
##
## Result = max(unit's base-terrain cost, overlay's move_cost).
## Both layers must be satisfied; the worst one decides.
static func move_cost(unit_type: Type, cell: TerrainData.HexCell) -> int:
	var unit_base_cost: int    = UNITS[unit_type]["move_costs"].get(int(cell.base), 99)
	var overlay_cost:   int    = TerrainData.OVERLAY_DATA[cell.overlay]["move_cost"]
	return maxi(unit_base_cost, overlay_cost)
