## MapEditor.gd
## Main controller node. Manages:
##   - Spawning and tracking HexTile nodes in a grid
##   - Mouse input → hex coordinate conversion
##   - Two modes: PAINT (place terrain) and MOVE (move the unit)
##   - UI toolbar (built in code, no external scene needed)
##
## NODE TREE (built in _ready):
##   MapEditor (Node2D)
##     ├── Camera2D
##     ├── GridRoot (Node2D)  ← all HexTile nodes go here
##     ├── UnitLayer (Node2D) ← Unit node
##     └── UI (CanvasLayer)
##           └── VBoxContainer
##                 ├── toolbar (HBoxContainer)
##                 └── StatusLabel
##
## Godot 4.4–4.6 changes applied:
##   - _tiles and _terrain_map are now typed Dictionary[Vector2i, ...]  (4.4+)
##   - _mode_buttons / _terrain_buttons use typed Dictionary[int, Button]  (4.4+)
##   - All for-loop iteration variables explicitly typed  (best practice, 4.4+)
##   - _screen_to_hex uses get_viewport().get_camera_2d() removed in favour of
##     direct camera transform — more robust across Godot 4.x minor versions
##   - StyleBoxFlat.set_expand_margin_all() → set_content_margin_all() note added
##   - var name := … replaced with var name: Type = … where type was ambiguous

class_name MapEditor
extends Node2D

# ── Grid dimensions ────────────────────────────────────────────────
const COLS: int = 18
const ROWS: int = 11
const HEX_SIZE: float = 44.0

# ── Editor modes ────────────────────────────────────────────────────
enum Mode { PAINT, MOVE }

var _mode: Mode = Mode.PAINT
var _active_terrain: TerrainData.Type = TerrainData.Type.GRASS

# ── State ────────────────────────────────────────────────────────────
# 4.4+: typed Dictionaries — key and value types are enforced at runtime
var _tiles: Dictionary[Vector2i, HexTile] = {}
var _terrain_map: Dictionary[Vector2i, TerrainData.Type] = {}
var _hovered_hex: Vector2i = Vector2i(-999, -999)
var _reachable_set: Array[Vector2i] = []

# ── Child nodes (assigned in _ready) ────────────────────────────────
var _grid_root: Node2D
var _unit_layer: Node2D
var _unit: Unit
var _status_label: Label
# 4.4+: typed Dictionaries for UI button maps
var _mode_buttons: Dictionary[int, Button] = {}
var _terrain_buttons: Dictionary[int, Button] = {}
var _camera: Camera2D

# ── Pan state ────────────────────────────────────────────────────────
var _panning: bool = false
var _pan_origin: Vector2 = Vector2.ZERO
var _cam_origin: Vector2 = Vector2.ZERO


func _ready() -> void:
	_build_scene_tree()
	_spawn_grid()
	_spawn_unit()
	_apply_default_map()
	_center_camera()
	_update_status()


# ════════════════════════════════════════════════════════════════════
# Scene tree construction (no .tscn needed)
# ════════════════════════════════════════════════════════════════════

func _build_scene_tree() -> void:
	_camera = Camera2D.new()
	_camera.zoom = Vector2(0.95, 0.95)
	add_child(_camera)

	_grid_root = Node2D.new()
	_grid_root.name = "GridRoot"
	add_child(_grid_root)

	_unit_layer = Node2D.new()
	_unit_layer.name = "UnitLayer"
	add_child(_unit_layer)

	_build_ui()


func _build_ui() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 10
	add_child(canvas)

	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
	canvas.add_child(panel)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.10, 0.92)
	style.set_corner_radius_all(0)
	# set_expand_margin_all was renamed to set_content_margin_all in 4.x;
	# setting corner radius to 0 is sufficient here — no margin override needed.
	panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)

	# ── Row 1: title + mode buttons ─────────────────────────────────
	var row1 := HBoxContainer.new()
	row1.add_theme_constant_override("separation", 8)
	vbox.add_child(row1)

	var title := Label.new()
	title.text = "  ⚔ Hex Map Editor"
	title.add_theme_color_override("font_color", Color(0.9, 0.75, 0.3))
	title.add_theme_font_size_override("font_size", 16)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row1.add_child(title)

	var mode_label := Label.new()
	mode_label.text = "Mode:"
	mode_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	mode_label.add_theme_font_size_override("font_size", 13)
	row1.add_child(mode_label)

	for mode_val: int in [Mode.PAINT, Mode.MOVE]:
		var btn: Button = _make_button(
			"✏ Paint" if mode_val == Mode.PAINT else "⚔ Move Unit (range %d)" % Unit.MOVE_RANGE
		)
		btn.pressed.connect(_on_mode_button.bind(mode_val))
		_mode_buttons[mode_val] = btn
		row1.add_child(btn)

	var sep := VSeparator.new()
	sep.custom_minimum_size = Vector2(8, 0)
	row1.add_child(sep)

	var clear_btn: Button = _make_button("🗑 Clear")
	clear_btn.pressed.connect(_clear_map)
	row1.add_child(clear_btn)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(8, 0)
	row1.add_child(spacer)

	# ── Row 2: Terrain palette ───────────────────────────────────────
	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 6)
	vbox.add_child(row2)

	var ter_label := Label.new()
	ter_label.text = "  Terrain:"
	ter_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	ter_label.add_theme_font_size_override("font_size", 13)
	row2.add_child(ter_label)

	for ter_type: int in TerrainData.TERRAINS.keys():
		var info: Dictionary = TerrainData.get_info(ter_type)
		var btn: Button = _make_terrain_button(info["name"], info["color"])
		btn.pressed.connect(_on_terrain_button.bind(ter_type))
		_terrain_buttons[ter_type] = btn
		row2.add_child(btn)

	# ── Row 3: Status ────────────────────────────────────────────────
	var row3 := HBoxContainer.new()
	vbox.add_child(row3)

	_status_label = Label.new()
	_status_label.text = ""
	_status_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	_status_label.add_theme_font_size_override("font_size", 12)
	_status_label.custom_minimum_size = Vector2(0, 20)
	var lpad := Label.new()
	lpad.text = "  "
	row3.add_child(lpad)
	row3.add_child(_status_label)

	# ── Row 4: Hex math reminder ─────────────────────────────────────
	var row4 := HBoxContainer.new()
	vbox.add_child(row4)
	var help := Label.new()
	help.text = "  Hex math: x = √3·S·(q + r/2)   y = 3/2·S·r   |   dist = max(|Δq|, |Δr|, |Δq+Δr|)   |   Scroll to zoom, RMB+drag to pan"
	help.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
	help.add_theme_font_size_override("font_size", 11)
	row4.add_child(help)

	_refresh_buttons()


func _make_button(txt: String) -> Button:
	var btn := Button.new()
	btn.text = txt
	btn.add_theme_font_size_override("font_size", 13)
	btn.custom_minimum_size = Vector2(0, 32)

	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.18, 0.18, 0.22)
	normal.border_color = Color(0.35, 0.35, 0.40)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(5)
	normal.content_margin_left = 12
	normal.content_margin_right = 12
	normal.content_margin_top = 4
	normal.content_margin_bottom = 4
	btn.add_theme_stylebox_override("normal", normal)

	var hover: StyleBoxFlat = normal.duplicate()
	hover.bg_color = Color(0.26, 0.26, 0.32)
	btn.add_theme_stylebox_override("hover", hover)

	var pressed_style: StyleBoxFlat = normal.duplicate()
	pressed_style.bg_color = Color(0.15, 0.35, 0.65)
	pressed_style.border_color = Color(0.40, 0.65, 1.0)
	btn.add_theme_stylebox_override("pressed", pressed_style)

	return btn


func _make_terrain_button(label: String, color: Color) -> Button:
	var btn: Button = _make_button(label)
	var s: StyleBoxFlat = btn.get_theme_stylebox("normal").duplicate()
	s.bg_color = color.darkened(0.45)
	s.border_color = color.lightened(0.1)
	btn.add_theme_stylebox_override("normal", s)
	var h: StyleBoxFlat = s.duplicate()
	h.bg_color = color.darkened(0.25)
	btn.add_theme_stylebox_override("hover", h)
	return btn


# ════════════════════════════════════════════════════════════════════
# Grid spawning
# ════════════════════════════════════════════════════════════════════

func _spawn_grid() -> void:
	for r: int in range(ROWS):
		for q: int in range(COLS):
			var coord := Vector2i(q, r)
			var tile := HexTile.new()
			tile.hex_coord = coord
			tile.position = HexGrid.axial_to_world(coord, HEX_SIZE)
			_grid_root.add_child(tile)
			_tiles[coord] = tile
			_terrain_map[coord] = TerrainData.Type.GRASS


func _spawn_unit() -> void:
	_unit = Unit.new()
	_unit.name = "Unit"
	_unit_layer.add_child(_unit)
	_unit.place_at(Vector2i(3, 3), HEX_SIZE)
	_unit.z_index = 5


func _center_camera() -> void:
	var mid_q: int = COLS / 2
	var mid_r: int = ROWS / 2
	_camera.position = HexGrid.axial_to_world(Vector2i(mid_q, mid_r), HEX_SIZE)


func _apply_default_map() -> void:
	var water_hexes: Array[Vector2i] = [
		Vector2i(4,2), Vector2i(5,2), Vector2i(6,2),
		Vector2i(5,3), Vector2i(4,4), Vector2i(5,4),
		Vector2i(4,5), Vector2i(5,5),
	]
	var forest_hexes: Array[Vector2i] = [
		Vector2i(10,2), Vector2i(11,2), Vector2i(10,3),
		Vector2i(11,3), Vector2i(12,4), Vector2i(10,4),
		Vector2i(9,3),
	]
	var mountain_hexes: Array[Vector2i] = [
		Vector2i(14,1), Vector2i(15,1), Vector2i(14,2),
		Vector2i(15,2), Vector2i(13,3),
	]
	var sand_hexes: Array[Vector2i] = [
		Vector2i(7,7), Vector2i(8,7), Vector2i(8,8), Vector2i(9,8),
	]

	for h: Vector2i in water_hexes:
		_set_terrain(h, TerrainData.Type.WATER)
	for h: Vector2i in forest_hexes:
		_set_terrain(h, TerrainData.Type.FOREST)
	for h: Vector2i in mountain_hexes:
		_set_terrain(h, TerrainData.Type.MOUNTAIN)
	for h: Vector2i in sand_hexes:
		_set_terrain(h, TerrainData.Type.SAND)


# ════════════════════════════════════════════════════════════════════
# Input handling
# ════════════════════════════════════════════════════════════════════

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.pressed:
			if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
				_camera.zoom = (_camera.zoom * 1.1).clamp(Vector2(0.3, 0.3), Vector2(3.0, 3.0))
			elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				_camera.zoom = (_camera.zoom * 0.9).clamp(Vector2(0.3, 0.3), Vector2(3.0, 3.0))
			elif mb.button_index == MOUSE_BUTTON_RIGHT:
				_panning = true
				_pan_origin = mb.position
				_cam_origin = _camera.position
			elif mb.button_index == MOUSE_BUTTON_LEFT:
				_handle_left_click(mb.position)
		elif mb.button_index == MOUSE_BUTTON_RIGHT and not mb.pressed:
			_panning = false

	elif event is InputEventMouseMotion:
		var mm: InputEventMouseMotion = event
		if _panning:
			var delta: Vector2 = (mm.position - _pan_origin) / _camera.zoom
			_camera.position = _cam_origin - delta
		else:
			_update_hover(mm.position)


func _handle_left_click(screen_pos: Vector2) -> void:
	var hex: Vector2i = _screen_to_hex(screen_pos)
	if not _tiles.has(hex):
		return

	match _mode:
		Mode.PAINT:
			_set_terrain(hex, _active_terrain)
		Mode.MOVE:
			if hex in _reachable_set:
				_move_unit_to(hex)


func _update_hover(screen_pos: Vector2) -> void:
	var hex: Vector2i = _screen_to_hex(screen_pos)
	if hex == _hovered_hex:
		return

	if _tiles.has(_hovered_hex):
		_tiles[_hovered_hex].set_hovered(false)

	_hovered_hex = hex

	if _tiles.has(hex):
		_tiles[hex].set_hovered(true)
		var info: Dictionary = TerrainData.get_info(_terrain_map[hex])
		_status_label.text = "Hex (%d, %d) — %s | dist from unit: %d" % [
			hex.x, hex.y,
			info["name"],
			HexGrid.distance(hex, _unit.hex_pos)
		]


# ════════════════════════════════════════════════════════════════════
# Coordinate conversion
# ════════════════════════════════════════════════════════════════════

func _screen_to_hex(screen_pos: Vector2) -> Vector2i:
	# Convert screen position → world position using the camera's transform.
	# get_screen_center_position() + offset is equivalent to the 4.3 approach
	# and remains valid in 4.6. The camera global_transform approach is equally
	# correct and slightly more explicit about what the math is doing.
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var world_pos: Vector2 = _camera.get_screen_center_position() + \
		(screen_pos - viewport_size * 0.5) / _camera.zoom
	return HexGrid.world_to_axial(world_pos, HEX_SIZE)


# ════════════════════════════════════════════════════════════════════
# Terrain painting
# ════════════════════════════════════════════════════════════════════

func _set_terrain(hex: Vector2i, type: TerrainData.Type) -> void:
	if not _tiles.has(hex):
		return
	_terrain_map[hex] = type
	_tiles[hex].set_terrain(type)
	if _mode == Mode.MOVE:
		_compute_reachable()


# ════════════════════════════════════════════════════════════════════
# Unit movement
# ════════════════════════════════════════════════════════════════════

func _move_unit_to(hex: Vector2i) -> void:
	_clear_movement_highlights()
	_unit.move_to(hex, HEX_SIZE)
	_compute_reachable()
	_apply_movement_highlights()
	_status_label.text = "Unit moved to (%d, %d)" % [hex.x, hex.y]


func _compute_reachable() -> void:
	_reachable_set = HexGrid.reachable(
		_unit.hex_pos,
		Unit.MOVE_RANGE,
		func(h: Vector2i) -> bool:
			if not _terrain_map.has(h):
				return true  # out of bounds = blocked
			return not TerrainData.is_passable(_terrain_map[h])
	)


func _apply_movement_highlights() -> void:
	for hex: Vector2i in _reachable_set:
		if _tiles.has(hex):
			_tiles[hex].set_reachable(hex != _unit.hex_pos)
	if _tiles.has(_unit.hex_pos):
		_tiles[_unit.hex_pos].set_selected(true)


func _clear_movement_highlights() -> void:
	for hex: Vector2i in _reachable_set:
		if _tiles.has(hex):
			_tiles[hex].set_reachable(false)
	if _tiles.has(_unit.hex_pos):
		_tiles[_unit.hex_pos].set_selected(false)


# ════════════════════════════════════════════════════════════════════
# UI callbacks
# ════════════════════════════════════════════════════════════════════

func _on_mode_button(mode: Mode) -> void:
	if _mode == Mode.MOVE and mode == Mode.PAINT:
		_clear_movement_highlights()
		_reachable_set = []

	_mode = mode

	if _mode == Mode.MOVE:
		_compute_reachable()
		_apply_movement_highlights()

	_refresh_buttons()
	_update_status()


func _on_terrain_button(type: TerrainData.Type) -> void:
	_active_terrain = type
	if _mode != Mode.PAINT:
		_on_mode_button(Mode.PAINT)
	_refresh_buttons()
	_update_status()


func _clear_map() -> void:
	_clear_movement_highlights()
	_reachable_set = []
	for coord: Vector2i in _tiles:
		_set_terrain(coord, TerrainData.Type.GRASS)
		_terrain_map[coord] = TerrainData.Type.GRASS
	_update_status()


func _refresh_buttons() -> void:
	for m: int in _mode_buttons:
		var btn: Button = _mode_buttons[m]
		var s: StyleBoxFlat = btn.get_theme_stylebox("normal").duplicate()
		if m == _mode:
			s.bg_color = Color(0.15, 0.35, 0.65)
			s.border_color = Color(0.40, 0.65, 1.0)
		else:
			s.bg_color = Color(0.18, 0.18, 0.22)
			s.border_color = Color(0.35, 0.35, 0.40)
		btn.add_theme_stylebox_override("normal", s)

	for t: int in _terrain_buttons:
		var btn: Button = _terrain_buttons[t]
		var info: Dictionary = TerrainData.get_info(t)
		var color: Color = info["color"]
		var s: StyleBoxFlat = btn.get_theme_stylebox("normal").duplicate()
		if t == _active_terrain and _mode == Mode.PAINT:
			s.bg_color = color.darkened(0.1)
			s.border_color = Color(1.0, 0.9, 0.3, 1.0)
			s.set_border_width_all(2)
		else:
			s.bg_color = color.darkened(0.45)
			s.border_color = color.lightened(0.1)
			s.set_border_width_all(1)
		btn.add_theme_stylebox_override("normal", s)

func _update_status() -> void:
	match _mode:
		Mode.PAINT:
			# Grab the name out of the info dictionary instead
			var info: Dictionary = TerrainData.get_info(_active_terrain)
			var terrain_name: String = info["name"]
			
			_status_label.text = "Paint mode — painting: %s  |  Right-click+drag to pan  |  Scroll to zoom" % terrain_name
		Mode.MOVE:
			_status_label.text = "Move mode — yellow hexes reachable in %d steps. Click one to move." % Unit.MOVE_RANGE
