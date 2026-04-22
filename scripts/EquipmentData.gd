## EquipmentData.gd
## Central registry for all equippable items.
##
## DATA SOURCE
## ───────────
##   All item definitions live in  res://data/equipment.json
##   and are loaded once on first access (lazy singleton pattern).
##
##   JSON projectile_kind values:  0 = ARROW,  1 = ARC,  -1 = none/melee
##   JSON base_costs / steed base_costs keys are strings ("0".."3") because
##   JSON only allows string keys — they are converted to int on load.
##
## ENUMS
##   The enums below are kept in GDScript so the rest of the codebase can
##   continue to use  EquipmentData.WeaponType.SWORD  etc.  The string keys
##   in the JSON match the enum member names exactly.

class_name EquipmentData

# ═══════════════════════════════════════════════════════════════════
# Enums  (names must match JSON keys exactly)
# ═══════════════════════════════════════════════════════════════════

enum WeaponType {
	NONE,
	SWORD, AXE, DAGGER, SPEAR, WARHAMMER,
	SHORT_BOW, LONG_BOW, CROSSBOW, JAVELIN, FIREBALL_STAFF, THUNDER_STAFF, WIND_STAFF,
}

enum ArmorType {
	NONE,
	LEATHER,
	CHAIN,
	PLATE,
}

enum HelmetType {
	NONE,
	CAP,
	COIF,
	GREAT_HELM,
}

enum SteedType {
	NONE,
	HORSE,
	WARHORSE,
	WOLF,
	BEAR,
	EAGLE,
}

# ═══════════════════════════════════════════════════════════════════
# Data file path
# ═══════════════════════════════════════════════════════════════════

const DATA_PATH := "res://data/equipment.json"

# ═══════════════════════════════════════════════════════════════════
# Runtime cache  (populated once, then reused)
# ═══════════════════════════════════════════════════════════════════

# Typed lookup tables keyed by enum int value.
# Populated lazily on the first call to any public accessor.
static var WEAPONS:  Dictionary = {}   # WeaponType  (int) → Dictionary
static var ARMORS:   Dictionary = {}   # ArmorType   (int) → Dictionary
static var HELMETS:  Dictionary = {}   # HelmetType  (int) → Dictionary
static var STEEDS:   Dictionary = {}   # SteedType   (int) → Dictionary

static var _loaded: bool = false


# ═══════════════════════════════════════════════════════════════════
# Loader
# ═══════════════════════════════════════════════════════════════════

## Load and parse equipment.json into the four lookup tables.
## Safe to call multiple times — returns immediately if already loaded.
static func ensure_loaded() -> void:
	if _loaded:
		return

	var file := FileAccess.open(DATA_PATH, FileAccess.READ)
	if file == null:
		push_error("EquipmentData: cannot open %s" % DATA_PATH)
		return

	var json  := JSON.new()
	var err   := json.parse(file.get_as_text())
	file.close()

	if err != OK:
		push_error("EquipmentData: JSON parse error in %s — %s" % [DATA_PATH, json.get_error_message()])
		return

	var root: Dictionary = json.get_data()

	# ── Weapons ──────────────────────────────────────────────────
	var wpn_names := WeaponType.keys()   # ["NONE","SWORD","AXE",…]
	var raw_wpns: Dictionary = root.get("weapons", {})
	for key in raw_wpns:
		var idx: int = wpn_names.find(key)
		if idx == -1:
			push_warning("EquipmentData: unknown weapon key '%s'" % key)
			continue
		WEAPONS[idx] = raw_wpns[key].duplicate(true)

	# ── Armors ───────────────────────────────────────────────────
	var armor_names := ArmorType.keys()
	var raw_armor: Dictionary = root.get("armors", {})
	for key in raw_armor:
		var idx: int = armor_names.find(key)
		if idx == -1:
			push_warning("EquipmentData: unknown armor key '%s'" % key)
			continue
		ARMORS[idx] = raw_armor[key].duplicate(true)

	# ── Helmets ──────────────────────────────────────────────────
	var helmet_names := HelmetType.keys()
	var raw_helm: Dictionary = root.get("helmets", {})
	for key in raw_helm:
		var idx: int = helmet_names.find(key)
		if idx == -1:
			push_warning("EquipmentData: unknown helmet key '%s'" % key)
			continue
		HELMETS[idx] = raw_helm[key].duplicate(true)

	# ── Steeds ───────────────────────────────────────────────────
	var steed_names := SteedType.keys()
	var raw_steed: Dictionary = root.get("steeds", {})
	for key in raw_steed:
		var idx: int = steed_names.find(key)
		if idx == -1:
			push_warning("EquipmentData: unknown steed key '%s'" % key)
			continue
		var entry: Dictionary = raw_steed[key].duplicate(true)
		# Convert string keys in base_costs back to int
		var int_costs: Dictionary = {}
		for k in entry.get("base_costs", {}):
			int_costs[int(k)] = int(entry["base_costs"][k])
		entry["base_costs"] = int_costs
		STEEDS[idx] = entry

	_loaded = true


# ═══════════════════════════════════════════════════════════════════
# Public accessors
## All functions call ensure_loaded() first so callers need not worry
## about init order.
# ═══════════════════════════════════════════════════════════════════

static func weapon_info(w: WeaponType) -> Dictionary:
	ensure_loaded()
	return WEAPONS.get(int(w), {})

static func armor_info(a: ArmorType) -> Dictionary:
	ensure_loaded()
	return ARMORS.get(int(a), {})

static func helmet_info(h: HelmetType) -> Dictionary:
	ensure_loaded()
	return HELMETS.get(int(h), {})

static func steed_info(s: SteedType) -> Dictionary:
	ensure_loaded()
	return STEEDS.get(int(s), {})

## Total passive damage reduction from armor + helmet combined.
static func total_reduction(armor: ArmorType, helmet: HelmetType) -> int:
	ensure_loaded()
	var a: int = ARMORS.get(int(armor), {}).get("damage_reduction", 0)
	var h: int = HELMETS.get(int(helmet), {}).get("damage_reduction", 0)
	return a + h
