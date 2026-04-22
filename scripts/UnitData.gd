## UnitData.gd
## Defines every unit archetype.
##
## Stats NO LONGER include attack damage or attack_range — those come
## from the unit's equipped weapons (primary_weapon / secondary_weapon).
##
## Each archetype defines:
##   hp_max        — base hit points
##   move_range    — on-foot movement budget (overridden by steed if mounted)
##   base_costs    — on-foot terrain entry costs
##   overlay_costs — overlay surcharge (stacked with base_cost)
##
## Default equipment loadouts are also defined here.
## These are the starting values; in-game equipment changes go on BaseUnit.

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

const BASE_FLAT     := 0
const BASE_HILLY    := 1
const BASE_MOUNTAIN := 2
const BASE_WATER    := 3

const OVL_NONE     := 0
const OVL_FOREST   := 1
const OVL_BUILDING := 2
const OVL_WALL     := 3

const UNITS: Dictionary = {

	# ── KNIGHT ─────────────────────────────────────────────────────
	Type.KNIGHT: {
		"name":    "Knight",
		"faction": Faction.PLAYER,
		"hp_max":  12,
		"move_range": 4,
		"body_color": Color(0.20, 0.40, 0.80),
		"trim_color": Color(0.85, 0.75, 0.20),
		"base_costs": {
			BASE_FLAT: 1, BASE_HILLY: 2, BASE_MOUNTAIN: 99, BASE_WATER: 99,
		},
		"overlay_costs": {
			OVL_NONE: 0, OVL_FOREST: 2, OVL_BUILDING: 99, OVL_WALL: 99,
		},
		# Default loadout
		"default_primary":   EquipmentData.WeaponType.SWORD,
		"default_secondary": EquipmentData.WeaponType.NONE,
		"default_armor":     EquipmentData.ArmorType.PLATE,
		"default_helmet":    EquipmentData.HelmetType.GREAT_HELM,
		"default_steed":     EquipmentData.SteedType.WARHORSE,
	},

	# ── ARCHER ─────────────────────────────────────────────────────
	Type.ARCHER: {
		"name":    "Archer",
		"faction": Faction.PLAYER,
		"hp_max":  8,
		"move_range": 5,
		"body_color": Color(0.15, 0.55, 0.20),
		"trim_color": Color(0.75, 0.55, 0.20),
		"base_costs": {
			BASE_FLAT: 1, BASE_HILLY: 1, BASE_MOUNTAIN: 3, BASE_WATER: 99,
		},
		"overlay_costs": {
			OVL_NONE: 0, OVL_FOREST: 1, OVL_BUILDING: 99, OVL_WALL: 99,
		},
		"default_primary":   EquipmentData.WeaponType.LONG_BOW,
		"default_secondary": EquipmentData.WeaponType.DAGGER,
		"default_armor":     EquipmentData.ArmorType.LEATHER,
		"default_helmet":    EquipmentData.HelmetType.CAP,
		"default_steed":     EquipmentData.SteedType.NONE,
	},

	# ── MAGE ───────────────────────────────────────────────────────
	Type.MAGE: {
		"name":    "Mage",
		"faction": Faction.PLAYER,
		"hp_max":  6,
		"move_range": 3,
		"body_color": Color(0.55, 0.15, 0.70),
		"trim_color": Color(0.90, 0.85, 1.00),
		"base_costs": {
			BASE_FLAT: 1, BASE_HILLY: 2, BASE_MOUNTAIN: 99, BASE_WATER: 99,
		},
		"overlay_costs": {
			OVL_NONE: 0, OVL_FOREST: 1, OVL_BUILDING: 99, OVL_WALL: 99,
		},
		"default_primary":   EquipmentData.WeaponType.FIREBALL_STAFF,
		"default_secondary": EquipmentData.WeaponType.DAGGER,
		"default_armor":     EquipmentData.ArmorType.NONE,
		"default_helmet":    EquipmentData.HelmetType.NONE,
		"default_steed":     EquipmentData.SteedType.NONE,
	},

	# ── ORC ────────────────────────────────────────────────────────
	Type.ORC: {
		"name":    "Orc",
		"faction": Faction.ENEMY,
		"hp_max":  10,
		"move_range": 4,
		"body_color": Color(0.25, 0.45, 0.10),
		"trim_color": Color(0.60, 0.20, 0.10),
		"base_costs": {
			BASE_FLAT: 1, BASE_HILLY: 2, BASE_MOUNTAIN: 3, BASE_WATER: 99,
		},
		"overlay_costs": {
			OVL_NONE: 0, OVL_FOREST: 1, OVL_BUILDING: 99, OVL_WALL: 99,
		},
		"default_primary":   EquipmentData.WeaponType.AXE,
		"default_secondary": EquipmentData.WeaponType.NONE,
		"default_armor":     EquipmentData.ArmorType.CHAIN,
		"default_helmet":    EquipmentData.HelmetType.COIF,
		"default_steed":     EquipmentData.SteedType.NONE,
	},

	# ── GOBLIN ─────────────────────────────────────────────────────
	Type.GOBLIN: {
		"name":    "Goblin",
		"faction": Faction.ENEMY,
		"hp_max":  5,
		"move_range": 6,
		"body_color": Color(0.30, 0.50, 0.10),
		"trim_color": Color(0.80, 0.70, 0.10),
		"base_costs": {
			BASE_FLAT: 1, BASE_HILLY: 1, BASE_MOUNTAIN: 2, BASE_WATER: 99,
		},
		"overlay_costs": {
			OVL_NONE: 0, OVL_FOREST: 0, OVL_BUILDING: 99, OVL_WALL: 99,
		},
		"default_primary":   EquipmentData.WeaponType.JAVELIN,
		"default_secondary": EquipmentData.WeaponType.DAGGER,
		"default_armor":     EquipmentData.ArmorType.NONE,
		"default_helmet":    EquipmentData.HelmetType.NONE,
		"default_steed":     EquipmentData.SteedType.WOLF,
	},

	# ── TROLL ──────────────────────────────────────────────────────
	Type.TROLL: {
		"name":    "Troll",
		"faction": Faction.ENEMY,
		"hp_max":  18,
		"move_range": 3,
		"body_color": Color(0.40, 0.35, 0.30),
		"trim_color": Color(0.20, 0.20, 0.20),
		"base_costs": {
			BASE_FLAT: 1, BASE_HILLY: 2, BASE_MOUNTAIN: 2, BASE_WATER: 3,
		},
		"overlay_costs": {
			OVL_NONE: 0, OVL_FOREST: 1, OVL_BUILDING: 99, OVL_WALL: 3,
		},
		"default_primary":   EquipmentData.WeaponType.THUNDER_STAFF,
		"default_secondary": EquipmentData.WeaponType.WARHAMMER,
		"default_armor":     EquipmentData.ArmorType.LEATHER,
		"default_helmet":    EquipmentData.HelmetType.NONE,
		"default_steed":     EquipmentData.SteedType.NONE,
	},
}

# ── Static API ────────────────────────────────────────────────────

static func get_info(type: Type) -> Dictionary:
	return UNITS[type]

static func get_unit_name(type: Type) -> String:
	return UNITS[type]["name"]

static func get_faction(type: Type) -> Faction:
	return UNITS[type]["faction"]

## Returns the on-foot move_range (before steed override).
static func get_base_move_range(type: Type) -> int:
	return UNITS[type]["move_range"]

## Cost for a unit to enter a hex using its BASE terrain data only.
## Overlay surcharge is added separately in BaseUnit (steed ignores overlays).
static func base_terrain_cost(unit_type: Type, base: int) -> int:
	return UNITS[unit_type]["base_costs"].get(base, 99)

static func overlay_cost(unit_type: Type, overlay: int) -> int:
	return UNITS[unit_type]["overlay_costs"].get(overlay, 99)

## Full cell cost for a unit, accounting for terrain layers.
static func move_cost(unit_type: Type, cell: TerrainData.HexCell) -> int:
	var data: Dictionary = UNITS[unit_type]
	var bc: int = data["base_costs"].get(int(cell.base), 99)
	var oc: int = data["overlay_costs"].get(int(cell.overlay), 99)
	if bc >= 99 or oc >= 99:
		return 99
	return bc + oc

static func can_pass(unit_type: Type, cell: TerrainData.HexCell) -> bool:
	return move_cost(unit_type, cell) < 99
