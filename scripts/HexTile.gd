## HexTile.gd
##
## DRAW ORDER (bottom → top):
##   1. _base_sprite    (z_index 0)
##   2. _overlay_sprite (z_index 1)
##   3. _hl_node        (z_index 100) — ALL highlight drawing happens here,
##                                      guaranteed above every sprite
##
## Highlights are drawn as independent layers (no elif), so e.g. a tile
## can show both reachable-yellow AND selected-white at once.
## Visibility order bottom→top: reachable → enemy_intent → attack → selected → hover

class_name HexTile
extends Node2D

const HEX_SIZE: float = 72

var hex_coord: Vector2i       = Vector2i.ZERO
var cell: TerrainData.HexCell = TerrainData.HexCell.new()

var is_hovered:       bool = false
var is_reachable:     bool = false
var is_selected:      bool = false
var is_attack_target: bool = false
var is_enemy_intent:  bool = false

var _corners: PackedVector2Array

var _base_sprite:    Sprite2D
var _overlay_sprite: Sprite2D
var _hl_node:        Node2D   # high-z child that owns all highlight _draw calls


func _ready() -> void:
	_corners = HexGrid.hex_corners(HEX_SIZE)
	z_index  = 0

	# ── Base sprite ──────────────────────────────────────────────────
	_base_sprite          = Sprite2D.new()
	_base_sprite.centered = true
	_base_sprite.position = Vector2.ZERO
	_base_sprite.z_index  = 0
	add_child(_base_sprite)

	# ── Overlay sprite ───────────────────────────────────────────────
	_overlay_sprite          = Sprite2D.new()
	_overlay_sprite.centered = true
	_overlay_sprite.position = Vector2.ZERO
	_overlay_sprite.z_index  = 1
	add_child(_overlay_sprite)

	# ── Highlight node — drawn well above sprites ────────────────────
	_hl_node                = Node2D.new()
	_hl_node.z_index        = 100
	_hl_node.z_as_relative  = true
	add_child(_hl_node)
	_hl_node.set_script(_make_hl_script())
	_hl_node.set_meta("tile", self)

	refresh_sprites()


# ════════════════════════════════════════════════════════════════════
# Highlight draw script (runs inside _hl_node)
# ════════════════════════════════════════════════════════════════════

func _make_hl_script() -> GDScript:
	var src := """
extends Node2D

func _draw() -> void:
	var tile = get_meta("tile")
	if not is_instance_valid(tile):
		return

	var corners: PackedVector2Array = tile._corners
	var closed  := corners.duplicate()
	closed.append(corners[0])

	# ── Reachable — bright yellow fill + solid border ────────────────
	if tile.is_reachable:
		draw_colored_polygon(corners, Color(1.0, 0.95, 0.10, 0.50))
		draw_polyline(closed, Color(1.0, 0.92, 0.00, 1.0), 4.0, true)

	# ── Enemy intent destination — orange fill + dashed border ────────
	if tile.is_enemy_intent:
		draw_colored_polygon(corners, Color(1.0, 0.45, 0.00, 0.42))
		_dashed_border(closed, Color(1.0, 0.55, 0.05, 1.0), 4.0)

	# ── Attack target — red fill + thick border ───────────────────────
	if tile.is_attack_target:
		draw_colored_polygon(corners, Color(1.0, 0.08, 0.05, 0.55))
		draw_polyline(closed, Color(1.0, 0.05, 0.05, 1.0), 4.5, true)

	# ── Selected — white fill + bright border ────────────────────────
	if tile.is_selected:
		draw_colored_polygon(corners, Color(1.0, 1.0, 1.0, 0.30))
		draw_polyline(closed, Color(1.0, 1.0, 1.0, 1.0), 4.0, true)

	# ── Hover — always topmost ───────────────────────────────────────
	if tile.is_hovered:
		draw_colored_polygon(corners, Color(1.0, 1.0, 1.0, 0.20))
		draw_polyline(closed, Color(1.0, 1.0, 1.0, 0.85), 2.5, true)


func _dashed_border(pts: PackedVector2Array, col: Color, width: float) -> void:
	var dash := 10.0
	var gap  :=  5.0
	for i in range(pts.size() - 1):
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i + 1]
		var seg: Vector2 = b - a
		var seg_len: float = seg.length()
		if seg_len < 0.01:
			continue
		var dir: Vector2 = seg / seg_len
		var t   := 0.0
		var on  := true
		while t < seg_len:
			var step := minf(dash if on else gap, seg_len - t)
			if on:
				draw_line(a + dir * t, a + dir * (t + step), col, width, true)
			t  += step
			on  = not on
"""
	var s := GDScript.new()
	s.source_code = src
	s.reload()
	return s


# ════════════════════════════════════════════════════════════════════
# Sprites
# ════════════════════════════════════════════════════════════════════

func refresh_sprites() -> void:
	var b_info := TerrainData.base_info(cell.base)
	if b_info.has("texture") and b_info["texture"] != null:
		_base_sprite.texture = b_info["texture"]
		_base_sprite.rotation_degrees = 0
		var tw := HEX_SIZE * 2.0
		_base_sprite.scale = Vector2.ONE * (tw / _base_sprite.texture.get_size().x)

	var o_info := TerrainData.overlay_info(cell.overlay)
	if o_info.has("texture") and o_info["texture"] != null:
		_overlay_sprite.texture = o_info["texture"]
		_overlay_sprite.rotation_degrees = 0
		var tw := HEX_SIZE * 2.0
		_overlay_sprite.scale = Vector2.ONE * (tw / _overlay_sprite.texture.get_size().x)
	else:
		_overlay_sprite.texture = null


# ════════════════════════════════════════════════════════════════════
# Public API
# ════════════════════════════════════════════════════════════════════

func _hl_redraw() -> void:
	if is_instance_valid(_hl_node):
		_hl_node.queue_redraw()

func set_cell(new_cell: TerrainData.HexCell) -> void:
	cell = new_cell
	refresh_sprites()
	_hl_redraw()

func set_base(b: TerrainData.Base) -> void:
	cell.base = b
	refresh_sprites()

func set_overlay(o: TerrainData.Overlay) -> void:
	cell.overlay = o
	refresh_sprites()

func set_hovered(v: bool) -> void:
	if is_hovered != v:
		is_hovered = v
		_hl_redraw()

func set_reachable(v: bool) -> void:
	if is_reachable != v:
		is_reachable = v
		_hl_redraw()

func set_selected(v: bool) -> void:
	if is_selected != v:
		is_selected = v
		_hl_redraw()

func set_attack_target(v: bool) -> void:
	if is_attack_target != v:
		is_attack_target = v
		_hl_redraw()

func set_enemy_intent(v: bool) -> void:
	if is_enemy_intent != v:
		is_enemy_intent = v
		_hl_redraw()

func unit_z() -> int:
	return z_index
