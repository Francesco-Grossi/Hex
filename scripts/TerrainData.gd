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
		"texture":   preload("res://assets/tile/grass/grass.png"),
		"move_cost": 1
	},
	Base.HILLY: {
		"name":      "Hilly",
		"color":     Color(0.4, 0.5, 0.3),
		"texture":   preload("res://assets/tile/hill/hill.png"),
		"move_cost": 2
	},
	Base.MOUNTAIN: {
		"name":      "Mountain",
		"color":     Color(0.40, 0.32, 0.26),
		"texture":   preload("res://assets/tile/mountain/mountain.png"),
		"move_cost": 99,
	},
	Base.WATER: {
		"name":      "Water",
		"color":     Color(0.10, 0.35, 0.70),
		"texture":   preload("res://assets/tile/water/water.png"),
		"move_cost": 99,
	},
	
}

# ─────────────────────────────────────────────────────────────────────
# Overlay data
# ─────────────────────────────────────────────────────────────────────
const OVERLAY_DATA: Dictionary = {
	Overlay.NONE: {
		"name":          "None",
		"texture":       null, # No sprite for empty overlay
		"move_cost":     0
	},
	Overlay.FOREST: {
		"name":          "Forest",
		"texture":       preload("res://assets/tile/forest/forest.png"), # ADD THIS
		"move_cost":     2
	},
	Overlay.BUILDING: {
		"name":          "Building",
		"texture":       preload("res://assets/tile/building/building.png"),
		"move_cost":     99
	},
	Overlay.WALL: {
		"name":          "Wall",
		"texture":       preload("res://assets/tile/wall/wall.png"),
		"move_cost":     99
	},
}

# ─────────────────────────────────────────────────────────────────────
# Overlay data
# ─────────────────────────────────────────────────────────────────────
## move_cost: standalone cost for this overlay (not additive).
##   The cell uses max(base, overlay) so the worse layer always wins.
## visual_height: pixels above tile centre the sprite extends upward,
##   used only for z_index sorting (no pixel offset applied to geometry).

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
