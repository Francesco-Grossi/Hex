## HexTile.gd
## A single hexagonal tile — pure colour fill + highlight overlays.
## No isometric offsets, no decorative details: those will come from PNG sprites.
##
## DRAW ORDER (bottom → top):
##   1. Base terrain colour fill
##   2. Border
##   3. State overlays  — reachable (yellow) / attack (red) / selected (white)
##   4. Hover flash     — always topmost
##   5. Coord label     — faint text child node
##
## Z-INDEX POLICY
##   z_index = row * 10 + cell.z_bias()
##   Overlay sprites (added externally) should use z_index + 1..4.
##   Units should use tile.unit_z() = z_index + 5.

class_name HexTile
extends Node2D

const HEX_SIZE: float = 44.0
const BORDER_W: float = 1.2

var hex_coord: Vector2i       = Vector2i.ZERO
var cell: TerrainData.HexCell = TerrainData.HexCell.new()

var is_hovered:       bool = false
var is_reachable:     bool = false
var is_selected:      bool = false
var is_attack_target: bool = false

var _corners: PackedVector2Array
var _label:   Label


func _ready() -> void:
	_corners = HexGrid.hex_corners(HEX_SIZE)
	_build_label()
	_refresh_z()


# ════════════════════════════════════════════════════════════════════
# Public API
# ════════════════════════════════════════════════════════════════════

func set_cell(new_cell: TerrainData.HexCell) -> void:
	cell = new_cell
	_update_label()
	_refresh_z()
	queue_redraw()

func set_base(b: TerrainData.Base) -> void:
	cell.base = b
	_update_label()
	_refresh_z()
	queue_redraw()

func set_overlay(o: TerrainData.Overlay) -> void:
	cell.overlay = o
	_update_label()
	_refresh_z()
	queue_redraw()

func set_hovered(v: bool) -> void:
	if is_hovered != v:
		is_hovered = v
		queue_redraw()

func set_reachable(v: bool) -> void:
	if is_reachable != v:
		is_reachable = v
		queue_redraw()

func set_selected(v: bool) -> void:
	if is_selected != v:
		is_selected = v
		queue_redraw()

func set_attack_target(v: bool) -> void:
	if is_attack_target != v:
		is_attack_target = v
		queue_redraw()


# ════════════════════════════════════════════════════════════════════
# Z-index
# ════════════════════════════════════════════════════════════════════

func _refresh_z() -> void:
	z_index = hex_coord.y * 10 + cell.z_bias()

## z_index a unit standing on this tile should use.
func unit_z() -> int:
	return z_index + 5


# ════════════════════════════════════════════════════════════════════
# Drawing
# ════════════════════════════════════════════════════════════════════

func _draw() -> void:
	var closed := PackedVector2Array(_corners)
	closed.append(_corners[0])

	# 1. Base colour fill
	draw_colored_polygon(_corners, TerrainData.base_color(cell.base))

	# 2. Border
	draw_polyline(closed, Color(0, 0, 0, 0.28), BORDER_W, true)

	# 3. State overlays (mutually exclusive, priority: selected > attack > reachable)
	if is_selected:
		draw_colored_polygon(_corners, Color(1.0, 1.0, 1.0, 0.18))
		draw_polyline(closed, Color(1.0, 1.0, 1.0, 0.90), 2.5, true)
	elif is_attack_target:
		draw_colored_polygon(_corners, Color(1.0, 0.15, 0.10, 0.25))
		draw_polyline(closed, Color(1.0, 0.20, 0.10, 0.85), 2.2, true)
	elif is_reachable:
		draw_colored_polygon(_corners, Color(1.0, 0.88, 0.15, 0.22))
		draw_polyline(closed, Color(1.0, 0.85, 0.10, 0.70), 1.8, true)

	# 4. Hover
	if is_hovered:
		draw_colored_polygon(_corners, Color(1.0, 1.0, 1.0, 0.12))
		draw_polyline(closed, Color(1.0, 1.0, 1.0, 0.60), 1.5, true)


# ════════════════════════════════════════════════════════════════════
# Label
# ════════════════════════════════════════════════════════════════════

func _build_label() -> void:
	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	_label.size     = Vector2(HEX_SIZE * 2.0, HEX_SIZE * 2.0)
	_label.position = Vector2(-HEX_SIZE, -HEX_SIZE)
	_label.add_theme_font_size_override("font_size", 12)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)
	_update_label()

func _update_label() -> void:
	if not is_instance_valid(_label):
		return
	var b_sym: String = TerrainData.BASE_DATA[cell.base]["symbol"]
	var o_sym: String = TerrainData.OVERLAY_DATA[cell.overlay]["symbol"]
	var sym: String   = o_sym if o_sym != "" else b_sym
	var coord: String = "%d,%d" % [hex_coord.x, hex_coord.y]
	_label.text = (sym + "\n" if sym != "" else "") + coord
	_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.30))
