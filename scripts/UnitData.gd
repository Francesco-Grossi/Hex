## UnitData.gd
## Defines every unit archetype.
##
## DATA SOURCE
## ───────────
##   All archetype definitions live in  res://data/units.json
##
##   Units are loaded ON DEMAND — only the first time a given Type is
##   requested.  This scales to hundreds of unit types: until you spawn
##   a "DRAGON", its data never occupies memory.
##
## JSON CONVENTIONS
##   faction:        "PLAYER" | "ENEMY"
##   body_color /
##   trim_color:     [r, g, b, a]  — four floats in 0–1 range
##   base_costs:     string keys "0"–"3"  →  int cost
##                   (0=FLAT, 1=HILLY, 2=MOUNTAIN, 3=WATER)
##   overlay_costs:  string keys "0"–"3"  →  int cost
##                   (0=NONE, 1=FOREST, 2=BUILDING, 3=WALL)
##   default_*:      string names matching EquipmentData enum members
##
## ENUM NAMES must match JSON keys exactly.

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

const DATA_PATH := "res://data/units.json"

# ── Terrain index constants (mirrors TerrainData / EquipmentData) ──
const BASE_FLAT     := 0
const BASE_HILLY    := 1
const BASE_MOUNTAIN := 2
const BASE_WATER    := 3

const OVL_NONE     := 0
const OVL_FOREST   := 1
const OVL_BUILDING := 2
const OVL_WALL     := 3

# ═══════════════════════════════════════════════════════════════════
# Runtime cache
# ═══════════════════════════════════════════════════════════════════

## Fully-cooked data keyed by  Type (int).
## Entries are created on first access to that Type — not all at startup.
static var UNITS: Dictionary = {}

## Raw JSON root, kept in memory so we can fetch any type on demand
## without re-reading the file.  Freed after all types are cached if
## _all_loaded becomes true.
static var _raw:        Dictionary = {}
static var _file_read:  bool       = false
static var _all_loaded: bool       = false   # set when every Type is cached


# ═══════════════════════════════════════════════════════════════════
# File loader  (reads JSON once, caches raw dict)
# ═══════════════════════════════════════════════════════════════════

static func _read_file() -> void:
	if _file_read:
		return
	_file_read = true

	var file := FileAccess.open(DATA_PATH, FileAccess.READ)
	if file == null:
		push_error("UnitData: cannot open %s" % DATA_PATH)
		return

	var json := JSON.new()
	var err  := json.parse(file.get_as_text())
	file.close()

	if err != OK:
		push_error("UnitData: JSON parse error — %s" % json.get_error_message())
		return

	_raw = json.get_data()


# ═══════════════════════════════════════════════════════════════════
# Per-type lazy loader
# ═══════════════════════════════════════════════════════════════════

## Ensure the data for `type` is cooked and present in UNITS.
static func _ensure_type(type: Type) -> void:
	if UNITS.has(int(type)):
		return          # already loaded

	_read_file()        # no-op if already done

	var key: String = Type.keys()[int(type)]   # e.g. "KNIGHT"
	if not _raw.has(key):
		push_error("UnitData: no entry for '%s' in %s" % [key, DATA_PATH])
		return

	var raw: Dictionary = _raw[key].duplicate(true)
	var cooked: Dictionary = {}

	# ── Scalar fields ────────────────────────────────────────────
	cooked["name"]       = raw.get("name", key)
	cooked["hp_max"]     = int(raw.get("hp_max", 1))
	cooked["move_range"] = int(raw.get("move_range", 3))

	# ── Faction ──────────────────────────────────────────────────
	cooked["faction"] = Faction.PLAYER \
		if raw.get("faction", "PLAYER") == "PLAYER" \
		else Faction.ENEMY

	# ── Colors ───────────────────────────────────────────────────
	cooked["body_color"] = _parse_color(raw.get("body_color", [1, 1, 1, 1]))
	cooked["trim_color"] = _parse_color(raw.get("trim_color", [0.5, 0.5, 0.5, 1]))

	# ── Terrain costs (string → int keys) ────────────────────────
	var bc: Dictionary = {}
	for k in raw.get("base_costs", {}):
		bc[int(k)] = int(raw["base_costs"][k])
	cooked["base_costs"] = bc

	var oc: Dictionary = {}
	for k in raw.get("overlay_costs", {}):
		oc[int(k)] = int(raw["overlay_costs"][k])
	cooked["overlay_costs"] = oc

	# ── Default equipment (string → enum int) ────────────────────
	cooked["default_primary"]   = _weapon_id(raw.get("default_primary",   "NONE"))
	cooked["default_secondary"] = _weapon_id(raw.get("default_secondary", "NONE"))
	cooked["default_armor"]     = _armor_id(raw.get("default_armor",  "NONE"))
	cooked["default_helmet"]    = _helmet_id(raw.get("default_helmet", "NONE"))
	cooked["default_steed"]     = _steed_id(raw.get("default_steed",  "NONE"))

	UNITS[int(type)] = cooked

	# Free raw data if every known type is now cached
	if UNITS.size() == Type.size():
		_all_loaded = true
		_raw.clear()


# ═══════════════════════════════════════════════════════════════════
# Equipment string → enum int helpers
# ═══════════════════════════════════════════════════════════════════

static func _weapon_id(s: String) -> EquipmentData.WeaponType:
	var idx: int = EquipmentData.WeaponType.keys().find(s)
	return EquipmentData.WeaponType.NONE if idx == -1 \
		else idx as EquipmentData.WeaponType

static func _armor_id(s: String) -> EquipmentData.ArmorType:
	var idx: int = EquipmentData.ArmorType.keys().find(s)
	return EquipmentData.ArmorType.NONE if idx == -1 \
		else idx as EquipmentData.ArmorType

static func _helmet_id(s: String) -> EquipmentData.HelmetType:
	var idx: int = EquipmentData.HelmetType.keys().find(s)
	return EquipmentData.HelmetType.NONE if idx == -1 \
		else idx as EquipmentData.HelmetType

static func _steed_id(s: String) -> EquipmentData.SteedType:
	var idx: int = EquipmentData.SteedType.keys().find(s)
	return EquipmentData.SteedType.NONE if idx == -1 \
		else idx as EquipmentData.SteedType

static func _parse_color(arr) -> Color:
	if arr is Array and arr.size() >= 3:
		return Color(float(arr[0]), float(arr[1]), float(arr[2]),
					 float(arr[3]) if arr.size() >= 4 else 1.0)
	return Color.WHITE


# ═══════════════════════════════════════════════════════════════════
# Public API  (mirrors the old static-dict surface exactly)
# ═══════════════════════════════════════════════════════════════════

static func get_info(type: Type) -> Dictionary:
	_ensure_type(type)
	return UNITS.get(int(type), {})

static func get_unit_name(type: Type) -> String:
	_ensure_type(type)
	return UNITS.get(int(type), {}).get("name", "Unknown")

static func get_faction(type: Type) -> Faction:
	_ensure_type(type)
	return UNITS.get(int(type), {}).get("faction", Faction.PLAYER)

static func get_base_move_range(type: Type) -> int:
	_ensure_type(type)
	return UNITS.get(int(type), {}).get("move_range", 3)

static func base_terrain_cost(unit_type: Type, base: int) -> int:
	_ensure_type(unit_type)
	return UNITS.get(int(unit_type), {}).get("base_costs", {}).get(base, 99)

static func overlay_cost(unit_type: Type, overlay: int) -> int:
	_ensure_type(unit_type)
	return UNITS.get(int(unit_type), {}).get("overlay_costs", {}).get(overlay, 99)

## Full cell cost for a unit, accounting for both terrain layers.
static func move_cost(unit_type: Type, cell: TerrainData.HexCell) -> int:
	_ensure_type(unit_type)
	var data: Dictionary = UNITS.get(int(unit_type), {})
	var bc: int = data.get("base_costs",    {}).get(int(cell.base),    99)
	var oc: int = data.get("overlay_costs", {}).get(int(cell.overlay), 99)
	if bc >= 99 or oc >= 99:
		return 99
	return bc + oc

static func can_pass(unit_type: Type, cell: TerrainData.HexCell) -> bool:
	return move_cost(unit_type, cell) < 99


# ═══════════════════════════════════════════════════════════════════
# Batch preload  (optional — call at scene start to warm all types)
# ═══════════════════════════════════════════════════════════════════

## Preloads every Type defined in the enum.
## Not required for correctness, but useful when you want zero
## per-spawn latency (e.g. during a loading screen).
static func preload_all() -> void:
	for t in Type.values():
		_ensure_type(t as Type)
