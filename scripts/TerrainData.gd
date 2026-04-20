## TerrainData.gd
## Two-layer terrain system.
##
## LAYER 0 — Base terrain (the ground):
##   FLAT | HILLY | MOUNTAIN | WATER
##
## LAYER 1 — Overlay (object on the ground):
##   NONE | FOREST | BUILDING | WALL
##
## Movement cost for a cell = max(base_move_cost, overlay_move_cost).
## This means the most restrictive layer always wins:
##   forest (2) on a mountain (99) → 99  (still impassable)
##   wall   (99) on flat (1)       → 99  (wall blocks completely)
##   forest (2) on flat (1)        → 2   (forest is the bottleneck)
##
## No isometric offset is applied — tiles are flat and will be
## replaced by PNG sprites. z_bias is driven only by overlay
## visual_height so tall sprites (buildings, walls) sort correctly.

class_name TerrainData

# ── Base terrain ──────────────────────────────────────────────────────
enum Base {
	FLAT,
	HILLY,
	MOUNTAIN,
	WATER,
}

# ── Overlay ───────────────────────────────────────────────────────────
enum Overlay {
	NONE,
	FOREST,
	BUILDING,
	WALL,
}

# ─────────────────────────────────────────────────────────────────────
# Base terrain data
# ─────────────────────────────────────────────────────────────────────
const BASE_DATA: Dictionary = {
	Base.FLAT: {
		"name":      "Flat",
		"color":     Color(0.25, 0.55, 0.12),
		"symbol":    "",
		"move_cost": 1,
	},
	Base.HILLY: {
		"name":      "Hilly",
		"color":     Color(0.45, 0.60, 0.20),
		"symbol":    "~",
		"move_cost": 2,
	},
	Base.MOUNTAIN: {
		"name":      "Mountain",
		"color":     Color(0.40, 0.32, 0.26),
		"symbol":    "▲",
		"move_cost": 99,
	},
	Base.WATER: {
		"name":      "Water",
		"color":     Color(0.10, 0.35, 0.70),
		"symbol":    "≈",
		"move_cost": 99,
	},
}

# ─────────────────────────────────────────────────────────────────────
# Overlay data
# ─────────────────────────────────────────────────────────────────────
## move_cost: standalone cost for this overlay (not additive).
##   The cell uses max(base, overlay) so the worse layer always wins.
## visual_height: pixels above tile centre the sprite extends upward,
##   used only for z_index sorting (no pixel offset applied to geometry).
const OVERLAY_DATA: Dictionary = {
	Overlay.NONE: {
		"name":          "None",
		"symbol":        "",
		"move_cost":     1,
		"visual_height": 0,
	},
	Overlay.FOREST: {
		"name":          "Forest",
		"symbol":        "♣",
		"move_cost":     2,
		"visual_height": 40,
	},
	Overlay.BUILDING: {
		"name":          "Building",
		"symbol":        "⌂",
		"move_cost":     99,
		"visual_height": 60,
	},
	Overlay.WALL: {
		"name":          "Wall",
		"symbol":        "█",
		"move_cost":     99,
		"visual_height": 50,
	},
}

# ─────────────────────────────────────────────────────────────────────
# HexCell — value object stored per tile
# ─────────────────────────────────────────────────────────────────────
class HexCell:
	var base:    TerrainData.Base    = TerrainData.Base.FLAT
	var overlay: TerrainData.Overlay = TerrainData.Overlay.NONE

	func _init(b: TerrainData.Base    = TerrainData.Base.FLAT,
			   o: TerrainData.Overlay = TerrainData.Overlay.NONE) -> void:
		base    = b
		overlay = o

	## Movement cost = max(base, overlay).
	## The most restrictive layer always wins.
	func move_cost() -> int:
		var bc: int = TerrainData.BASE_DATA[base]["move_cost"]
		var oc: int = TerrainData.OVERLAY_DATA[overlay]["move_cost"]
		return maxi(bc, oc)

	## True when the cell can be entered at all.
	func is_passable() -> bool:
		return move_cost() < 99

	## Z-sort bias — only overlay height matters (no isometric elevation).
	func z_bias() -> int:
		return TerrainData.OVERLAY_DATA[overlay]["visual_height"]

	func duplicate() -> HexCell:
		return HexCell.new(base, overlay)

# ─────────────────────────────────────────────────────────────────────
# Static helpers
# ─────────────────────────────────────────────────────────────────────
static func base_info(b: Base) -> Dictionary:
	return BASE_DATA[b]

static func overlay_info(o: Overlay) -> Dictionary:
	return OVERLAY_DATA[o]

static func base_name(b: Base) -> String:
	return BASE_DATA[b]["name"]

static func overlay_name(o: Overlay) -> String:
	return OVERLAY_DATA[o]["name"]

static func base_color(b: Base) -> Color:
	return BASE_DATA[b]["color"]
