## TerrainData.gd
## Defines terrain types and their properties.
## In a real game you'd load these from JSON/resources,
## but we keep it simple and self-contained here.
##
## Godot 4.6 notes:
##   TERRAINS uses untyped Dictionary intentionally — typed Dictionary[Type, Dictionary]
##   is possible in 4.4+ but the inner Dictionary value type is heterogeneous,
##   so untyped is still the correct choice here.

class_name TerrainData

enum Type {
	GRASS,
	WATER,
	FOREST,
	MOUNTAIN,
	SAND,
	SNOW,
}

## Per-terrain configuration
const TERRAINS: Dictionary = {
	Type.GRASS: {
		"name": "Grass",
		"color": Color(0.25, 0.55, 0.12),
		"hover_color": Color(0.35, 0.70, 0.18),
		"movement_cost": 1,        # moves spent to enter
		"passable": true,
		"symbol": "",
	},
	Type.WATER: {
		"name": "Water",
		"color": Color(0.10, 0.35, 0.70),
		"hover_color": Color(0.15, 0.45, 0.85),
		"movement_cost": 99,       # effectively impassable for land units
		"passable": false,
		"symbol": "~",
	},
	Type.FOREST: {
		"name": "Forest",
		"color": Color(0.10, 0.38, 0.10),
		"hover_color": Color(0.15, 0.50, 0.15),
		"movement_cost": 2,
		"passable": true,
		"symbol": "♣",
	},
	Type.MOUNTAIN: {
		"name": "Mountain",
		"color": Color(0.40, 0.32, 0.26),
		"hover_color": Color(0.52, 0.42, 0.34),
		"movement_cost": 99,
		"passable": false,
		"symbol": "▲",
	},
	Type.SAND: {
		"name": "Sand",
		"color": Color(0.65, 0.52, 0.18),
		"hover_color": Color(0.78, 0.63, 0.25),
		"movement_cost": 2,
		"passable": true,
		"symbol": "·",
	},
	Type.SNOW: {
		"name": "Snow",
		"color": Color(0.55, 0.68, 0.78),
		"hover_color": Color(0.68, 0.80, 0.90),
		"movement_cost": 2,
		"passable": true,
		"symbol": "*",
	},
}

static func get_info(type: Type) -> Dictionary:
	return TERRAINS[type]

static func is_passable(type: Type) -> bool:
	return TERRAINS[type]["passable"]

static func get_color(type: Type) -> Color:
	return TERRAINS[type]["color"]

static func get_name(type: Type) -> String:
	return TERRAINS[type]["name"]
