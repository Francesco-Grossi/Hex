## UnitData.gd
## Defines every unit archetype in one place.
## Both players and enemies use the same data — faction is a separate flag.
##
## Terrain movement costs are PER-STEP costs paid when entering a hex.
## A unit with move_range=4 can enter 4 grass hexes OR 2 forest hexes
## (cost 2 each) before exhausting its budget.
## 99 = impassable for that unit type.

class_name UnitData

# ── Faction ──────────────────────────────────────────────────────────
enum Faction { PLAYER, ENEMY }

# ── Unit archetypes ──────────────────────────────────────────────────
enum Type {
	# Player units
	KNIGHT,
	ARCHER,
	MAGE,
	# Enemy units
	ORC,
	GOBLIN,
	TROLL,
}

# ── Per-type stats ───────────────────────────────────────────────────
# move_costs: Dictionary[TerrainData.Type, int]  (99 = impassable)
const UNITS: Dictionary = {

	Type.KNIGHT: {
		"name":       "Knight",
		"faction":    Faction.PLAYER,
		"hp_max":     12,
		"attack":     4,
		"move_range": 4,
		"body_color": Color(0.20, 0.40, 0.80),   # blue steel
		"trim_color": Color(0.85, 0.75, 0.20),   # gold trim
		"move_costs": {
			# TerrainData.Type int keys
			0: 1,   # GRASS
			1: 99,  # WATER — impassable
			2: 2,   # FOREST
			3: 99,  # MOUNTAIN — impassable
			4: 1,   # SAND
			5: 2,   # SNOW
		},
	},

	Type.ARCHER: {
		"name":       "Archer",
		"faction":    Faction.PLAYER,
		"hp_max":     8,
		"attack":     3,
		"move_range": 5,
		"body_color": Color(0.15, 0.55, 0.20),   # forest green
		"trim_color": Color(0.75, 0.55, 0.20),   # brown trim
		"move_costs": {
			0: 1,   # GRASS
			1: 99,  # WATER
			2: 1,   # FOREST — rangers feel at home
			3: 3,   # MOUNTAIN — slow but passable
			4: 1,   # SAND
			5: 2,   # SNOW
		},
	},

	Type.MAGE: {
		"name":       "Mage",
		"faction":    Faction.PLAYER,
		"hp_max":     6,
		"attack":     5,
		"move_range": 3,
		"body_color": Color(0.55, 0.15, 0.70),   # purple
		"trim_color": Color(0.90, 0.85, 1.00),   # pale glow
		"move_costs": {
			0: 1,
			1: 99,
			2: 2,
			3: 99,
			4: 1,
			5: 1,
		},
	},

	Type.ORC: {
		"name":       "Orc",
		"faction":    Faction.ENEMY,
		"hp_max":     10,
		"attack":     4,
		"move_range": 4,
		"body_color": Color(0.25, 0.45, 0.10),   # dark green
		"trim_color": Color(0.60, 0.20, 0.10),   # rusty red
		"move_costs": {
			0: 1,
			1: 99,
			2: 2,
			3: 3,
			4: 1,
			5: 2,
		},
	},

	Type.GOBLIN: {
		"name":       "Goblin",
		"faction":    Faction.ENEMY,
		"hp_max":     5,
		"attack":     2,
		"move_range": 6,     # fast and sneaky
		"body_color": Color(0.30, 0.50, 0.10),
		"trim_color": Color(0.80, 0.70, 0.10),
		"move_costs": {
			0: 1,
			1: 99,
			2: 1,   # goblins love forests
			3: 2,
			4: 1,
			5: 2,
		},
	},

	Type.TROLL: {
		"name":       "Troll",
		"faction":    Faction.ENEMY,
		"hp_max":     18,
		"attack":     5,
		"move_range": 3,     # slow but tanky
		"body_color": Color(0.40, 0.35, 0.30),
		"trim_color": Color(0.20, 0.20, 0.20),
		"move_costs": {
			0: 1,
			1: 3,   # trolls can wade through shallow water
			2: 2,
			3: 2,
			4: 1,
			5: 1,
		},
	},
}


static func get_info(type: Type) -> Dictionary:
	return UNITS[type]

static func get_name(type: Type) -> String:
	return UNITS[type]["name"]

static func get_faction(type: Type) -> Faction:
	return UNITS[type]["faction"]

## Cost for this unit type to enter a given terrain type (99 = blocked)
static func move_cost(unit_type: Type, terrain_type: int) -> int:
	var costs: Dictionary = UNITS[unit_type]["move_costs"]
	return costs.get(terrain_type, 99)
