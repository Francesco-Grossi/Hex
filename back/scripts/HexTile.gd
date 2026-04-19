## HexTile.gd
## A single hexagonal tile drawn with Godot's draw_polygon / draw_polyline.
## Attached to a Node2D that sits at the hex's world-space center.
##
## Visual layers (drawn in _draw() order, bottom → top):
##   1. Filled polygon  — terrain color
##   2. Border polyline — subtle edge
##   3. Highlight overlay — reachable / selected / hovered states
##   4. Symbol label    — terrain glyph (drawn via Label child)
##
## Godot 4.4–4.6 changes applied:
##   - for-loop iteration variables are now explicitly typed (: Type)
##   - No API removals affect this file

class_name HexTile
extends Node2D

const HEX_SIZE: float = 44.0
const BORDER_WIDTH: float = 1.2

## Which axial coordinate this tile occupies
var hex_coord: Vector2i = Vector2i.ZERO

## Current terrain
var terrain_type: TerrainData.Type = TerrainData.Type.GRASS

## Visual state flags
var is_hovered: bool = false
var is_reachable: bool = false   # lit up during unit movement mode
var is_selected: bool = false    # the hex the unit stands on

## Cached polygon points (computed once)
var _corners: PackedVector2Array

## Label child for coordinate / symbol display
var _label: Label


func _ready() -> void:
	_corners = HexGrid.hex_corners(HEX_SIZE)
	_build_label()


func _build_label() -> void:
	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.size = Vector2(HEX_SIZE * 2.0, HEX_SIZE * 2.0)
	_label.position = Vector2(-HEX_SIZE, -HEX_SIZE)
	_label.add_theme_font_size_override("font_size", 14)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)
	_update_label()


func _update_label() -> void:
	if _label == null:
		return
	var info: Dictionary = TerrainData.get_info(terrain_type)
	var sym: String = info["symbol"]
	var coord_str: String = "%d,%d" % [hex_coord.x, hex_coord.y]
	_label.text = (sym + "\n" if sym != "" else "") + coord_str
	_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.35))


func set_terrain(type: TerrainData.Type) -> void:
	terrain_type = type
	_update_label()
	queue_redraw()


func set_hovered(value: bool) -> void:
	if is_hovered != value:
		is_hovered = value
		queue_redraw()


func set_reachable(value: bool) -> void:
	if is_reachable != value:
		is_reachable = value
		queue_redraw()


func set_selected(value: bool) -> void:
	if is_selected != value:
		is_selected = value
		queue_redraw()


func _draw() -> void:
	var info: Dictionary = TerrainData.get_info(terrain_type)
	var base_color: Color = info["color"]

	# --- 1. Terrain fill ---
	draw_colored_polygon(_corners, base_color)

	# --- 2. Hex border ---
	var border_color := Color(0.0, 0.0, 0.0, 0.25)
	# close the polyline by appending first point
	var closed_corners := PackedVector2Array(_corners)
	closed_corners.append(_corners[0])
	draw_polyline(closed_corners, border_color, BORDER_WIDTH, true)

	# --- 3. Highlight overlays (drawn on top of fill) ---
	if is_selected:
		# The unit stands here — bright white ring
		draw_colored_polygon(_corners, Color(1.0, 1.0, 1.0, 0.18))
		draw_polyline(closed_corners, Color(1.0, 1.0, 1.0, 0.9), 2.5, true)

	elif is_reachable:
		# Reachable — warm yellow tint
		draw_colored_polygon(_corners, Color(1.0, 0.88, 0.15, 0.22))
		draw_polyline(closed_corners, Color(1.0, 0.85, 0.10, 0.7), 1.8, true)

	if is_hovered:
		# Hover — light overlay on top of everything
		draw_colored_polygon(_corners, Color(1.0, 1.0, 1.0, 0.12))
		draw_polyline(closed_corners, Color(1.0, 1.0, 1.0, 0.6), 1.5, true)
