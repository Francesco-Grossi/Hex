## EquipmentData.gd
## Central registry for all equippable items.
##
## WEAPONS  — held in two slots (primary / secondary).
##            Each weapon has damage, attack range, and projectile kind.
##            Melee weapons: range 1, no projectile.
##            Ranged weapons: range > 1, ARROW or ARC projectile kind.
##
## ARMOR    — worn on body. Reduces incoming damage by `damage_reduction`.
##
## HELMETS  — worn on head. Reduces incoming damage by `damage_reduction`.
##            Armor + Helmet reductions stack additively.
##
## STEEDS   — mounted animal. While mounted the unit uses the steed's
##            move_range and base_costs instead of its own.

class_name EquipmentData

# ═══════════════════════════════════════════════════════════════════
# Enums
# ═══════════════════════════════════════════════════════════════════

enum WeaponType {
	NONE,
	# Melee
	SWORD, AXE, DAGGER, SPEAR, WARHAMMER,
	# Ranged
	SHORT_BOW, LONG_BOW, CROSSBOW, JAVELIN, FIREBALL_STAFF, THUNDER_STAFF,
}

enum ArmorType {
	NONE,
	LEATHER,   # -1 dmg
	CHAIN,     # -2 dmg
	PLATE,     # -3 dmg
}

enum HelmetType {
	NONE,
	CAP,        # -1 dmg
	COIF,       # -1 dmg
	GREAT_HELM, # -2 dmg
}

enum SteedType {
	NONE,
	HORSE,      # fast on flat
	WARHORSE,   # heavy cavalry
	WOLF,       # goblin mount, good in forests/mountains
	BEAR,       # slow, all-terrain
	EAGLE,      # aerial, all terrain cost 1
}

# ═══════════════════════════════════════════════════════════════════
# Weapon data
# ═══════════════════════════════════════════════════════════════════

const WEAPONS: Dictionary = {
	WeaponType.NONE: {
		"name": "Unarmed", "damage": 1, "attack_range": 1,
		"projectile_kind": -1, "description": "No weapon equipped.",
	},
	WeaponType.SWORD: {
		"name": "Sword", "damage": 3, "attack_range": 1,
		"projectile_kind": -1, "description": "Reliable one-handed blade.",
	},
	WeaponType.AXE: {
		"name": "Axe", "damage": 5, "attack_range": 1,
		"projectile_kind": -1, "description": "Heavy chopping weapon. Hits hard.",
	},
	WeaponType.DAGGER: {
		"name": "Dagger", "damage": 2, "attack_range": 1,
		"projectile_kind": -1, "description": "Light and fast. Low damage.",
	},
	WeaponType.SPEAR: {
		"name": "Spear", "damage": 3, "attack_range": 2,
		"projectile_kind": ProjectileData.Kind.ARROW,
		"description": "Reach weapon. Attacks 2 hexes away.",
	},
	WeaponType.WARHAMMER: {
		"name": "Warhammer", "damage": 6, "attack_range": 1,
		"projectile_kind": -1, "description": "Massive bludgeon. Crushes armour.",
	},
	WeaponType.SHORT_BOW: {
		"name": "Short Bow", "damage": 2, "attack_range": 3,
		"projectile_kind": ProjectileData.Kind.ARROW,
		"description": "Compact bow. Short range, quick draw.",
	},
	WeaponType.LONG_BOW: {
		"name": "Long Bow", "damage": 3, "attack_range": 5,
		"projectile_kind": ProjectileData.Kind.ARROW,
		"description": "Tall bow with excellent range.",
	},
	WeaponType.CROSSBOW: {
		"name": "Crossbow", "damage": 5, "attack_range": 4,
		"projectile_kind": ProjectileData.Kind.ARROW,
		"description": "Mechanically powerful. High damage.",
	},
	WeaponType.JAVELIN: {
		"name": "Javelin", "damage": 3, "attack_range": 2,
		"projectile_kind": ProjectileData.Kind.ARROW,
		"description": "Thrown spear. Short range.",
	},
	WeaponType.FIREBALL_STAFF: {
		"name": "Fireball Staff", "damage": 4, "attack_range": 3,
		"projectile_kind": ProjectileData.Kind.ARC,
		"description": "Magical staff. Lobs fireballs over terrain.",
	},
	WeaponType.THUNDER_STAFF: {
		"name": "Thunder Staff", "damage": 6, "attack_range": 4,
		"projectile_kind": ProjectileData.Kind.ARC,
		"description": "Powerful arcane staff. High damage arc shots.",
	},
}

# ═══════════════════════════════════════════════════════════════════
# Armor data
# ═══════════════════════════════════════════════════════════════════

const ARMORS: Dictionary = {
	ArmorType.NONE:    { "name": "No Armor",     "damage_reduction": 0, "description": "Unarmored." },
	ArmorType.LEATHER: { "name": "Leather Armor", "damage_reduction": 1, "description": "Light protection. −1 damage." },
	ArmorType.CHAIN:   { "name": "Chainmail",     "damage_reduction": 2, "description": "Medium protection. −2 damage." },
	ArmorType.PLATE:   { "name": "Plate Armor",   "damage_reduction": 3, "description": "Heavy plate. −3 damage." },
}

# ═══════════════════════════════════════════════════════════════════
# Helmet data
# ═══════════════════════════════════════════════════════════════════

const HELMETS: Dictionary = {
	HelmetType.NONE:       { "name": "No Helmet",    "damage_reduction": 0, "description": "No head protection." },
	HelmetType.CAP:        { "name": "Leather Cap",  "damage_reduction": 1, "description": "Basic head cover. −1 damage." },
	HelmetType.COIF:       { "name": "Chain Coif",   "damage_reduction": 1, "description": "Chain hood. −1 damage." },
	HelmetType.GREAT_HELM: { "name": "Great Helm",   "damage_reduction": 2, "description": "Full face helmet. −2 damage." },
}

# ═══════════════════════════════════════════════════════════════════
# Steed data
# ═══════════════════════════════════════════════════════════════════

## "move_range"  — movement budget while mounted
## "base_costs"  — terrain entry costs (keys = TerrainData.Base int)
const STEEDS: Dictionary = {
	SteedType.NONE: {
		"name": "Unmounted", "move_range": 0, "base_costs": {},
		"description": "On foot.",
	},
	SteedType.HORSE: {
		"name": "Horse", "move_range": 6,
		"base_costs": { 0: 1, 1: 2, 2: 99, 3: 99 },
		"description": "Fast on open ground. Poor in rough terrain.",
	},
	SteedType.WARHORSE: {
		"name": "Warhorse", "move_range": 5,
		"base_costs": { 0: 1, 1: 2, 2: 99, 3: 99 },
		"description": "Armoured destrier. Slower but sturdier than a horse.",
	},
	SteedType.WOLF: {
		"name": "Wolf", "move_range": 6,
		"base_costs": { 0: 1, 1: 1, 2: 2, 3: 99 },
		"description": "Goblin mount. Nimble across all land terrain.",
	},
	SteedType.BEAR: {
		"name": "Bear", "move_range": 4,
		"base_costs": { 0: 1, 1: 1, 2: 2, 3: 2 },
		"description": "Slow but handles nearly any terrain.",
	},
	SteedType.EAGLE: {
		"name": "Eagle", "move_range": 7,
		"base_costs": { 0: 1, 1: 1, 2: 1, 3: 1 },
		"description": "Aerial mount. Ignores all terrain costs.",
	},
}

# ═══════════════════════════════════════════════════════════════════
# Static helpers
# ═══════════════════════════════════════════════════════════════════

static func weapon_info(w: WeaponType) -> Dictionary:
	return WEAPONS[w]

static func armor_info(a: ArmorType) -> Dictionary:
	return ARMORS[a]

static func helmet_info(h: HelmetType) -> Dictionary:
	return HELMETS[h]

static func steed_info(s: SteedType) -> Dictionary:
	return STEEDS[s]

## Total passive damage reduction from armor + helmet combined.
static func total_reduction(armor: ArmorType, helmet: HelmetType) -> int:
	return ARMORS[armor]["damage_reduction"] + HELMETS[helmet]["damage_reduction"]
