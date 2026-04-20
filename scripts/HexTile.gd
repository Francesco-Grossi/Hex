## HexTile.gd
##
## DRAW ORDER (bottom → top):
##   1. Base terrain colour fill
##   2. Border
##   3. State overlays  — reachable (yellow) / attack (red) / selected (white)
##   4. Hover flash     — always topmost
##
## Z-INDEX POLICY
##   z_index = row * 10 + cell.z_bias()
##   Overlay sprites (added externally) should use z_index + 1..4.
##   Units should use tile.unit_z() = z_index + 5.
class_name HexTile
extends Node2D

const HEX_SIZE: float = 72
const BORDER_W: float = 1.2
const HEX_WIDTH:  float = 124.708  # sqrt(3) * 72
const HEX_HEIGHT: float = 144.0    # 2 * 72

var hex_coord: Vector2i       = Vector2i.ZERO
var cell: TerrainData.HexCell = TerrainData.HexCell.new()

var is_hovered:       bool = false
var is_reachable:     bool = false
var is_selected:      bool = false
var is_attack_target: bool = false

var _corners: PackedVector2Array

# --- Sprite variables ---
var _base_sprite: Sprite2D
var _overlay_sprite: Sprite2D

func _ready() -> void:
	_corners = HexGrid.hex_corners(HEX_SIZE)
 
	_base_sprite          = Sprite2D.new()
	_base_sprite.centered = true
	_base_sprite.position = Vector2.ZERO
	_base_sprite.z_index  = 0
	add_child(_base_sprite)
 
	_overlay_sprite          = Sprite2D.new()
	_overlay_sprite.centered = true
	_overlay_sprite.position = Vector2.ZERO
	_overlay_sprite.z_index  = 0
	add_child(_overlay_sprite)
 
	z_index = 0
 
	refresh_sprites()
	
	
## HexTile.gd (Excerpts)

func refresh_sprites() -> void:
	# ─── BASE SPRITE ─────────────────────────────────────────────
	var b_info = TerrainData.base_info(cell.base)
	if b_info.has("texture") and b_info["texture"] != null:
		_base_sprite.texture = b_info["texture"]
		
		# SET ROTATION TO 0: The grid math now matches the image orientation
		_base_sprite.rotation_degrees = 0 
		
		var tex_size = _base_sprite.texture.get_size()
		# For Flat-top, width is HEX_SIZE * 2.0
		var target_width = HEX_SIZE * 2.0 
		var scale_factor = target_width / tex_size.x
		_base_sprite.scale = Vector2(scale_factor, scale_factor)
	
	# ─── OVERLAY SPRITE ──────────────────────────────────────────
	var o_info = TerrainData.overlay_info(cell.overlay)
	if o_info.has("texture") and o_info["texture"] != null:
		_overlay_sprite.texture = o_info["texture"]
		
		# ALL OVERLAYS STAY UPRIGHT
		_overlay_sprite.rotation_degrees = 0
		
		var tex_size = _overlay_sprite.texture.get_size()
		var target_width = HEX_SIZE * 2.0
		var scale_factor = target_width / tex_size.x
		_overlay_sprite.scale = Vector2(scale_factor, scale_factor)

# Function to apply textures based on current cell state


# ════════════════════════════════════════════════════════════════════
# Draw (Highlights and Borders ONLY)
# ════════════════════════════════════════════════════════════════════
func _draw() -> void:
	var closed := _corners.duplicate()
	closed.append(_corners[0])
 
	# State overlays (mutually exclusive priority: selected > attack > reachable)
	if is_selected:
		draw_colored_polygon(_corners, Color(1.0, 1.0, 1.0, 0.22))
		draw_polyline(closed, Color(1.0, 1.0, 1.0, 0.90), 2.5, true)
	elif is_attack_target:
		draw_colored_polygon(_corners, Color(1.0, 0.15, 0.10, 0.28))
		draw_polyline(closed, Color(1.0, 0.20, 0.10, 0.85), 2.2, true)
	elif is_reachable:
		draw_colored_polygon(_corners, Color(1.0, 0.88, 0.15, 0.22))
		draw_polyline(closed, Color(1.0, 0.85, 0.10, 0.70), 1.8, true)
 
	# Hover — always on top
	if is_hovered:
		draw_colored_polygon(_corners, Color(1.0, 1.0, 1.0, 0.12))
		draw_polyline(closed, Color(1.0, 1.0, 1.0, 0.55), 1.5, true)


# ════════════════════════════════════════════════════════════════════
# Public API
# ════════════════════════════════════════════════════════════════════

func set_cell(new_cell: TerrainData.HexCell) -> void:
	cell = new_cell
	refresh_sprites()
	queue_redraw()
 
func set_base(b: TerrainData.Base) -> void:
	cell.base = b
	refresh_sprites()
	queue_redraw()
 
func set_overlay(o: TerrainData.Overlay) -> void:
	cell.overlay = o
	refresh_sprites()
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
 
func unit_z() -> int:
	return 0
 
