## UnitData.gd
## Defines every unit archetype in one place.
##
## MOVEMENT — terrain cost belongs to the UNIT, not the terrain.
##   "base_costs"    — cost to enter each BASE terrain (key = TerrainData.Base int)
##   "overlay_costs" — extra cost imposed by the OVERLAY  (key = TerrainData.Overlay int)
##   Final cell cost = base_cost + overlay_cost.  Either ≥ 99 → impassable.
##
## COMBAT
##   "attack_range"    — hex radius:  1 = melee only,  2+ = ranged
##   "projectile_kind" — ProjectileData.Kind: ARROW or ARC
##                       Ignored for melee units (attack_range == 1).
##
## Melee units attack only adjacent hexes (no projectile spawned).
## Ranged units can attack any hex within attack_range, subject to
## line-of-sight rules determined by projectile_kind.

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

# Terrain key shorthands (mirror TerrainData.Base / Overlay enums)
const BASE_FLAT     := 0
const BASE_HILLY    := 1
const BASE_MOUNTAIN := 2
const BASE_WATER    := 3

const OVL_NONE     := 0
const OVL_FOREST   := 1
const OVL_BUILDING := 2
const OVL_WALL     := 3

const UNITS: Dictionary = {

	# ── KNIGHT ─────────────────────────────────────────────────────────
	# Heavy melee.  Struggles on rough ground, blocked by water.
	Type.KNIGHT: {
		"name":             "Knight",
		"faction":          Faction.PLAYER,
		"hp_max":           12,
		"attack":           4,
		"move_range":       4,
		"attack_range":     1,                        # melee only
		"projectile_kind":  -1,                       # none
		"body_color":       Color(0.20, 0.40, 0.80),
		"trim_color":       Color(0.85, 0.75, 0.20),
		"base_costs": {
			BASE_FLAT: 1, BASE_HILLY: 2, BASE_MOUNTAIN: 99, BASE_WATER: 99,
		},
		"overlay_costs": {
			OVL_NONE: 0, OVL_FOREST: 2, OVL_BUILDING: 99, OVL_WALL: 99,
		},
	},

	# ── ARCHER ─────────────────────────────────────────────────────────
	# Ranged — shoots arrows (straight, blockable, range 4).
	Type.ARCHER: {
		"name":             "Archer",
		"faction":          Faction.PLAYER,
		"hp_max":           8,
		"attack":           3,
		"move_range":       5,
		"attack_range":     4,                        # ranged, 4 hexes
		"projectile_kind":  ProjectileData.Kind.ARROW,
		"body_color":       Color(0.15, 0.55, 0.20),
		"trim_color":       Color(0.75, 0.55, 0.20),
		"base_costs": {
			BASE_FLAT: 1, BASE_HILLY: 1, BASE_MOUNTAIN: 3, BASE_WATER: 99,
		},
		"overlay_costs": {
			OVL_NONE: 0, OVL_FOREST: 1, OVL_BUILDING: 99, OVL_WALL: 99,
		},
	},

	# ── MAGE ───────────────────────────────────────────────────────────
	# Ranged — lobs magical arcs (parabolic, bypasses terrain, range 3).
	Type.MAGE: {
		"name":             "Mage",
		"faction":          Faction.PLAYER,
		"hp_max":           6,
		"attack":           5,
		"move_range":       3,
		"attack_range":     3,                        # ranged, 3 hexes
		"projectile_kind":  ProjectileData.Kind.ARC,
		"body_color":       Color(0.55, 0.15, 0.70),
		"trim_color":       Color(0.90, 0.85, 1.00),
		"base_costs": {
			BASE_FLAT: 1, BASE_HILLY: 2, BASE_MOUNTAIN: 99, BASE_WATER: 99,
		},
		"overlay_costs": {
			OVL_NONE: 0, OVL_FOREST: 1, OVL_BUILDING: 99, OVL_WALL: 99,
		},
	},

	# ── ORC ────────────────────────────────────────────────────────────
	# Brute melee.  Can push through mountains at a cost.
	Type.ORC: {
		"name":             "Orc",
		"faction":          Faction.ENEMY,
		"hp_max":           10,
		"attack":           4,
		"move_range":       4,
		"attack_range":     1,                        # melee only
		"projectile_kind":  -1,
		"body_color":       Color(0.25, 0.45, 0.10),
		"trim_color":       Color(0.60, 0.20, 0.10),
		"base_costs": {
			BASE_FLAT: 1, BASE_HILLY: 2, BASE_MOUNTAIN: 3, BASE_WATER: 99,
		},
		"overlay_costs": {
			OVL_NONE: 0, OVL_FOREST: 1, OVL_BUILDING: 99, OVL_WALL: 99,
		},
	},

	# ── GOBLIN ─────────────────────────────────────────────────────────
	# Fast skirmisher.  Throws javelins — short arrow range (2 hexes).
	Type.GOBLIN: {
		"name":             "Goblin",
		"faction":          Faction.ENEMY,
		"hp_max":           5,
		"attack":           2,
		"move_range":       6,
		"attack_range":     2,                        # ranged, 2 hexes (javelin)
		"projectile_kind":  ProjectileData.Kind.ARROW,
		"body_color":       Color(0.30, 0.50, 0.10),
		"trim_color":       Color(0.80, 0.70, 0.10),
		"base_costs": {
			BASE_FLAT: 1, BASE_HILLY: 1, BASE_MOUNTAIN: 2, BASE_WATER: 99,
		},
		"overlay_costs": {
			OVL_NONE: 0, OVL_FOREST: 0, OVL_BUILDING: 99, OVL_WALL: 99,
		},
	},

	# ── TROLL ──────────────────────────────────────────────────────────
	# Massive melee.  Hurls boulders in arc (range 2) — and can wade water.
	Type.TROLL: {
		"name":             "Troll",
		"faction":          Faction.ENEMY,
		"hp_max":           18,
		"attack":           5,
		"move_range":       3,
		"attack_range":     2,                        # melee + arc range 2
		"projectile_kind":  ProjectileData.Kind.ARC,
		"body_color":       Color(0.40, 0.35, 0.30),
		"trim_color":       Color(0.20, 0.20, 0.20),
		"base_costs": {
			BASE_FLAT: 1, BASE_HILLY: 2, BASE_MOUNTAIN: 2, BASE_WATER: 3,
		},
		"overlay_costs": {
			OVL_NONE: 0, OVL_FOREST: 1, OVL_BUILDING: 99, OVL_WALL: 3,
		},
	},
}


# ── Static API ────────────────────────────────────────────────────────

static func get_info(type: Type) -> Dictionary:
	return UNITS[type]

static func get_unit_name(type: Type) -> String:
	return UNITS[type]["name"]

static func get_faction(type: Type) -> Faction:
	return UNITS[type]["faction"]

static func is_ranged(type: Type) -> bool:
	return UNITS[type]["attack_range"] > 1

static func get_attack_range(type: Type) -> int:
	return UNITS[type]["attack_range"]

static func get_projectile_kind(type: Type) -> int:
	return UNITS[type]["projectile_kind"]   # -1 for melee


## True cost for a unit to enter a hex cell.
## cost = base_cost + overlay_cost;  either ≥ 99 → returns 99.
static func move_cost(unit_type: Type, cell: TerrainData.HexCell) -> int:
	var data: Dictionary = UNITS[unit_type]
	var bc: int = data["base_costs"].get(int(cell.base), 99)
	var oc: int = data["overlay_costs"].get(int(cell.overlay), 99)
	if bc >= 99 or oc >= 99:
		return 99
	return bc + oc


static func can_pass(unit_type: Type, cell: TerrainData.HexCell) -> bool:
	return move_cost(unit_type, cell) < 99
