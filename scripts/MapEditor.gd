## MapEditor.gd
## Root scene script. Two top-level modes:
##   EDIT   — paint terrain on the hex grid
##   BATTLE — spawns units, runs turn-based combat via BattleManager
##
## Attach to the Main node in Main.tscn (Node2D, no children needed).
## No class_name — referenced only by scene file, never by other scripts.

extends Node2D

# ── Grid config ──────────────────────────────────────────────────────
const COLS: int       = 18
const ROWS: int       = 11
const HEX_SIZE: float = 44.0

# ── App modes ────────────────────────────────────────────────────────
enum AppMode  { EDIT, BATTLE }
enum EditMode { PAINT, MOVE_PREVIEW }

var _app_mode:  AppMode  = AppMode.EDIT
var _edit_mode: EditMode = EditMode.PAINT
var _active_terrain: TerrainData.Type = TerrainData.Type.GRASS

# ── Grid state ───────────────────────────────────────────────────────
var _tiles:       Dictionary = {}   # Vector2i → HexTile
var _terrain_map: Dictionary = {}   # Vector2i → TerrainData.Type

# ── Edit-mode preview ────────────────────────────────────────────────
var _preview_pos:       Vector2i        = Vector2i(3, 3)
var _preview_reachable: Array[Vector2i] = []

# ── Hover ────────────────────────────────────────────────────────────
var _hovered_hex: Vector2i = Vector2i(-999, -999)

# ── Child nodes ──────────────────────────────────────────────────────
var _camera:       Camera2D
var _grid_root:    Node2D
var _unit_layer:   Node2D
var _status_label: Label
var _turn_btn:     Button
var _battle_btn:   Button
var _edit_panel:   HBoxContainer
var _mode_buttons:    Dictionary = {}
var _terrain_buttons: Dictionary = {}

# ── Battle ───────────────────────────────────────────────────────────
var _battle: BattleManager = null

# ── Pan ──────────────────────────────────────────────────────────────
var _panning:    bool    = false
var _pan_origin: Vector2 = Vector2.ZERO
var _cam_origin: Vector2 = Vector2.ZERO


func _ready() -> void:
	_build_camera()
	_build_grid_nodes()
	_build_ui()
	# Defer grid spawn by one frame so viewport size is known
	# and the camera is properly active before we center on it.
	call_deferred("_deferred_start")


func _deferred_start() -> void:
	_spawn_grid()
	_apply_default_map()
	_center_camera()
	_update_status()


# ════════════════════════════════════════════════════════════════════
# Scene tree bootstrap
# ════════════════════════════════════════════════════════════════════

func _build_camera() -> void:
	_camera = Camera2D.new()
	_camera.zoom = Vector2(1.0, 1.0)
	# make_current() ensures this is the active camera even if
	# other Camera2D nodes exist (e.g. from previous runs in editor).
	add_child(_camera)
	_camera.make_current()


func _build_grid_nodes() -> void:
	# Dark background so we never see the default gray void
	var bg := ColorRect.new()
	bg.color = Color(0.10, 0.10, 0.12)
	# Very large rect — it scrolls with the world via Node2D, stays behind grid
	bg.size     = Vector2(8000, 8000)
	bg.position = Vector2(-4000, -4000)
	bg.z_index  = -10
	add_child(bg)

	_grid_root = Node2D.new()
	_grid_root.name = "GridRoot"
	add_child(_grid_root)

	_unit_layer = Node2D.new()
	_unit_layer.name = "UnitLayer"
	add_child(_unit_layer)


func _build_ui() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 10
	add_child(canvas)

	# ── Also put a solid background on the CanvasLayer so the top bar
	#    always has a dark backdrop regardless of world content.
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(0.08, 0.08, 0.10, 1.0)
	ps.set_corner_radius_all(0)
	ps.set_expand_margin_all(0)
	panel.add_theme_stylebox_override("panel", ps)
	canvas.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	panel.add_child(vbox)

	# ── Row 1 ────────────────────────────────────────────────────────
	var row1 := HBoxContainer.new()
	row1.add_theme_constant_override("separation", 6)
	vbox.add_child(row1)

	var title := Label.new()
	title.text = "  ⚔ Hex Map"
	title.add_theme_color_override("font_color", Color(0.9, 0.75, 0.3))
	title.add_theme_font_size_override("font_size", 16)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row1.add_child(title)

	for ev: int in [EditMode.PAINT, EditMode.MOVE_PREVIEW]:
		var lbl := "✏ Paint" if ev == EditMode.PAINT else "👣 Preview Move"
		var btn := _make_btn(lbl)
		btn.pressed.connect(_on_edit_mode.bind(ev))
		_mode_buttons[ev] = btn
		row1.add_child(btn)

	row1.add_child(_vsep())

	var clear_btn := _make_btn("🗑 Clear")
	clear_btn.pressed.connect(_clear_map)
	row1.add_child(clear_btn)

	row1.add_child(_vsep())

	_turn_btn = _make_btn("⏭ End Turn")
	_turn_btn.pressed.connect(_on_end_turn)
	_turn_btn.visible = false
	row1.add_child(_turn_btn)

	_battle_btn = _make_btn("⚔ Start Battle")
	_battle_btn.pressed.connect(_on_toggle_battle)
	_tint_btn(_battle_btn, Color(0.55, 0.12, 0.12))
	row1.add_child(_battle_btn)

	# ── Row 2: terrain palette ───────────────────────────────────────
	_edit_panel = HBoxContainer.new()
	_edit_panel.add_theme_constant_override("separation", 5)
	vbox.add_child(_edit_panel)

	var tl := Label.new()
	tl.text = "  Terrain:"
	tl.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55))
	tl.add_theme_font_size_override("font_size", 13)
	_edit_panel.add_child(tl)

	for tt: int in TerrainData.TERRAINS.keys():
		var info: Dictionary = TerrainData.get_info(tt)
		var btn := _make_terrain_btn(info["name"], info["color"])
		btn.pressed.connect(_on_terrain.bind(tt))
		_terrain_buttons[tt] = btn
		_edit_panel.add_child(btn)

	# ── Row 3: status ────────────────────────────────────────────────
	var row3 := HBoxContainer.new()
	vbox.add_child(row3)
	var pad := Label.new()
	pad.text = "  "
	row3.add_child(pad)
	_status_label = Label.new()
	_status_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	_status_label.add_theme_font_size_override("font_size", 12)
	_status_label.custom_minimum_size = Vector2(0, 20)
	row3.add_child(_status_label)

	# ── Row 4: hint ──────────────────────────────────────────────────
	var row4 := HBoxContainer.new()
	vbox.add_child(row4)
	var hint := Label.new()
	hint.text = "  Scroll=zoom  RMB+drag=pan  |  Battle: click unit → yellow=move  red=attack → End Turn"
	hint.add_theme_color_override("font_color", Color(0.35, 0.35, 0.35))
	hint.add_theme_font_size_override("font_size", 11)
	row4.add_child(hint)

	_refresh_buttons()


# ════════════════════════════════════════════════════════════════════
# Grid
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


func _center_camera() -> void:
	# Place camera at world-center of the grid
	_camera.position = HexGrid.axial_to_world(
		Vector2i(COLS / 2, ROWS / 2), HEX_SIZE)


func _apply_default_map() -> void:
	var water: Array[Vector2i] = [
		Vector2i(4,2), Vector2i(5,2), Vector2i(6,2), Vector2i(5,3),
		Vector2i(4,4), Vector2i(5,4), Vector2i(4,5), Vector2i(5,5),
	]
	var forest: Array[Vector2i] = [
		Vector2i(10,2), Vector2i(11,2), Vector2i(10,3), Vector2i(11,3),
		Vector2i(12,4), Vector2i(10,4), Vector2i(9,3),
	]
	var mountain: Array[Vector2i] = [
		Vector2i(14,1), Vector2i(15,1), Vector2i(14,2),
		Vector2i(15,2), Vector2i(13,3),
	]
	var sand: Array[Vector2i] = [
		Vector2i(7,7), Vector2i(8,7), Vector2i(8,8), Vector2i(9,8),
	]
	for h: Vector2i in water:    _set_terrain(h, TerrainData.Type.WATER)
	for h: Vector2i in forest:   _set_terrain(h, TerrainData.Type.FOREST)
	for h: Vector2i in mountain: _set_terrain(h, TerrainData.Type.MOUNTAIN)
	for h: Vector2i in sand:     _set_terrain(h, TerrainData.Type.SAND)


# ════════════════════════════════════════════════════════════════════
# Battle
# ════════════════════════════════════════════════════════════════════

func _on_toggle_battle() -> void:
	if _app_mode == AppMode.EDIT:
		_enter_battle()
	else:
		_exit_battle()


func _enter_battle() -> void:
	_app_mode = AppMode.BATTLE
	_edit_panel.visible = false
	_turn_btn.visible   = true
	_battle_btn.text    = "✎ Back to Edit"
	_tint_btn(_battle_btn, Color(0.15, 0.20, 0.55))
	_clear_preview()

	_battle = BattleManager.new()
	_battle.setup(_tiles, _terrain_map, _unit_layer, _status_label)
	_battle.status_changed.connect(
		func(t: String) -> void: _status_label.text = t)
	_battle.phase_changed.connect(_on_phase_changed)
	add_child(_battle)
	_battle.start_battle()


func _exit_battle() -> void:
	_app_mode = AppMode.EDIT
	_edit_panel.visible = true
	_turn_btn.visible   = false
	_battle_btn.text    = "⚔ Start Battle"
	_tint_btn(_battle_btn, Color(0.55, 0.12, 0.12))

	if _battle != null:
		_battle.queue_free()
		_battle = null

	for child in _unit_layer.get_children():
		child.queue_free()

	_update_status()


func _on_end_turn() -> void:
	if _battle != null:
		_battle.end_player_turn()


func _on_phase_changed(p: BattleManager.Phase) -> void:
	match p:
		BattleManager.Phase.PLAYER:
			_turn_btn.text     = "⏭ End Turn"
			_turn_btn.disabled = false
		BattleManager.Phase.ENEMY:
			_turn_btn.text     = "⏳ Enemy…"
			_turn_btn.disabled = true
		BattleManager.Phase.VICTORY:
			_turn_btn.text     = "🏆 Victory!"
			_turn_btn.disabled = true
		BattleManager.Phase.DEFEAT:
			_turn_btn.text     = "💀 Defeat"
			_turn_btn.disabled = true


# ════════════════════════════════════════════════════════════════════
# Input
# ════════════════════════════════════════════════════════════════════

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.pressed:
			match mb.button_index:
				MOUSE_BUTTON_WHEEL_UP:
					_camera.zoom = (_camera.zoom * 1.1).clamp(
						Vector2(0.3, 0.3), Vector2(3.0, 3.0))
				MOUSE_BUTTON_WHEEL_DOWN:
					_camera.zoom = (_camera.zoom * 0.9).clamp(
						Vector2(0.3, 0.3), Vector2(3.0, 3.0))
				MOUSE_BUTTON_RIGHT:
					_panning    = true
					_pan_origin = mb.position
					_cam_origin = _camera.position
				MOUSE_BUTTON_LEFT:
					_handle_click(mb.position)
		elif mb.button_index == MOUSE_BUTTON_RIGHT:
			_panning = false

	elif event is InputEventMouseMotion:
		var mm: InputEventMouseMotion = event
		if _panning:
			_camera.position = _cam_origin \
				- (mm.position - _pan_origin) / _camera.zoom
		else:
			_update_hover(mm.position)


func _handle_click(screen_pos: Vector2) -> void:
	var hex := _screen_to_hex(screen_pos)

	if _app_mode == AppMode.BATTLE:
		if _battle != null:
			_battle.handle_hex_click(hex)
		return

	if not _tiles.has(hex):
		return
	match _edit_mode:
		EditMode.PAINT:
			_set_terrain(hex, _active_terrain)
		EditMode.MOVE_PREVIEW:
			if hex in _preview_reachable:
				_move_preview(hex)


func _update_hover(screen_pos: Vector2) -> void:
	var hex := _screen_to_hex(screen_pos)
	if hex == _hovered_hex:
		return
	if _tiles.has(_hovered_hex):
		_tiles[_hovered_hex].set_hovered(false)
	_hovered_hex = hex
	if _tiles.has(hex):
		_tiles[hex].set_hovered(true)
		if _app_mode == AppMode.EDIT:
			var info := TerrainData.get_info(_terrain_map[hex])
			_status_label.text = "Hex (%d, %d) — %s" % [
				hex.x, hex.y, info["name"]]


func _screen_to_hex(screen_pos: Vector2) -> Vector2i:
	# Use the camera's own transform to convert screen → world.
	# This is the most reliable approach across all Godot 4.x versions.
	var vp_size := get_viewport().get_visible_rect().size
	var world := _camera.global_position + \
		(screen_pos - vp_size * 0.5) / _camera.zoom
	return HexGrid.world_to_axial(world, HEX_SIZE)


# ════════════════════════════════════════════════════════════════════
# Terrain
# ════════════════════════════════════════════════════════════════════

func _set_terrain(hex: Vector2i, type: TerrainData.Type) -> void:
	if not _tiles.has(hex):
		return
	_terrain_map[hex] = type
	_tiles[hex].set_terrain(type)


# ════════════════════════════════════════════════════════════════════
# Edit preview movement
# ════════════════════════════════════════════════════════════════════

func _move_preview(hex: Vector2i) -> void:
	_clear_preview()
	_preview_pos = hex
	_compute_preview()
	_apply_preview()
	_status_label.text = "Preview unit at (%d, %d)" % [hex.x, hex.y]


func _compute_preview() -> void:
	_preview_reachable = HexGrid.reachable(
		_preview_pos, 4,
		func(h: Vector2i) -> bool:
			if not _terrain_map.has(h): return true
			return not TerrainData.is_passable(_terrain_map[h])
	)


func _apply_preview() -> void:
	for hex: Vector2i in _preview_reachable:
		if _tiles.has(hex):
			_tiles[hex].set_reachable(hex != _preview_pos)
	if _tiles.has(_preview_pos):
		_tiles[_preview_pos].set_selected(true)


func _clear_preview() -> void:
	for hex: Vector2i in _preview_reachable:
		if _tiles.has(hex):
			_tiles[hex].set_reachable(false)
	if _tiles.has(_preview_pos):
		_tiles[_preview_pos].set_selected(false)
	_preview_reachable.clear()


# ════════════════════════════════════════════════════════════════════
# UI callbacks
# ════════════════════════════════════════════════════════════════════

func _on_edit_mode(mode: EditMode) -> void:
	if _edit_mode == EditMode.MOVE_PREVIEW and mode == EditMode.PAINT:
		_clear_preview()
	_edit_mode = mode
	if _edit_mode == EditMode.MOVE_PREVIEW:
		_compute_preview()
		_apply_preview()
	_refresh_buttons()
	_update_status()


func _on_terrain(type: TerrainData.Type) -> void:
	_active_terrain = type
	if _edit_mode != EditMode.PAINT:
		_on_edit_mode(EditMode.PAINT)
	_refresh_buttons()
	_update_status()


func _clear_map() -> void:
	_clear_preview()
	for coord: Vector2i in _tiles:
		_set_terrain(coord, TerrainData.Type.GRASS)
		_terrain_map[coord] = TerrainData.Type.GRASS
	_update_status()


func _update_status() -> void:
	if _app_mode == AppMode.BATTLE:
		return
	match _edit_mode:
		EditMode.PAINT:
			_status_label.text = "Paint — %s  |  RMB+drag=pan  |  Scroll=zoom" % \
				TerrainData.get_name(_active_terrain)
		EditMode.MOVE_PREVIEW:
			_status_label.text = "Move preview — click yellow hex to move marker"


func _refresh_buttons() -> void:
	for m: int in _mode_buttons:
		var btn: Button = _mode_buttons[m]
		var s := btn.get_theme_stylebox("normal").duplicate() as StyleBoxFlat
		if m == _edit_mode and _app_mode == AppMode.EDIT:
			s.bg_color     = Color(0.15, 0.35, 0.65)
			s.border_color = Color(0.40, 0.65, 1.0)
		else:
			s.bg_color     = Color(0.18, 0.18, 0.22)
			s.border_color = Color(0.35, 0.35, 0.40)
		btn.add_theme_stylebox_override("normal", s)

	for t: int in _terrain_buttons:
		var btn: Button = _terrain_buttons[t]
		var info := TerrainData.get_info(t)
		var col: Color = info["color"]
		var s := btn.get_theme_stylebox("normal").duplicate() as StyleBoxFlat
		if t == _active_terrain and _edit_mode == EditMode.PAINT:
			s.bg_color     = col.darkened(0.10)
			s.border_color = Color(1.0, 0.9, 0.3)
			s.set_border_width_all(2)
		else:
			s.bg_color     = col.darkened(0.45)
			s.border_color = col.lightened(0.1)
			s.set_border_width_all(1)
		btn.add_theme_stylebox_override("normal", s)


# ════════════════════════════════════════════════════════════════════
# UI factories
# ════════════════════════════════════════════════════════════════════

func _make_btn(txt: String) -> Button:
	var btn := Button.new()
	btn.text = txt
	btn.add_theme_font_size_override("font_size", 13)
	btn.custom_minimum_size = Vector2(0, 32)
	var n := StyleBoxFlat.new()
	n.bg_color            = Color(0.18, 0.18, 0.22)
	n.border_color        = Color(0.35, 0.35, 0.40)
	n.set_border_width_all(1)
	n.set_corner_radius_all(5)
	n.content_margin_left   = 10
	n.content_margin_right  = 10
	n.content_margin_top    = 4
	n.content_margin_bottom = 4
	btn.add_theme_stylebox_override("normal", n)
	var h := n.duplicate() as StyleBoxFlat
	h.bg_color = Color(0.26, 0.26, 0.32)
	btn.add_theme_stylebox_override("hover", h)
	var p := n.duplicate() as StyleBoxFlat
	p.bg_color     = Color(0.15, 0.35, 0.65)
	p.border_color = Color(0.40, 0.65, 1.0)
	btn.add_theme_stylebox_override("pressed", p)
	return btn


func _make_terrain_btn(lbl: String, color: Color) -> Button:
	var btn := _make_btn(lbl)
	var s := btn.get_theme_stylebox("normal").duplicate() as StyleBoxFlat
	s.bg_color     = color.darkened(0.45)
	s.border_color = color.lightened(0.1)
	btn.add_theme_stylebox_override("normal", s)
	var h := s.duplicate() as StyleBoxFlat
	h.bg_color = color.darkened(0.25)
	btn.add_theme_stylebox_override("hover", h)
	return btn


func _tint_btn(btn: Button, color: Color) -> void:
	var s := btn.get_theme_stylebox("normal").duplicate() as StyleBoxFlat
	s.bg_color     = color.darkened(0.3)
	s.border_color = color.lightened(0.2)
	btn.add_theme_stylebox_override("normal", s)
	var h := s.duplicate() as StyleBoxFlat
	h.bg_color = color
	btn.add_theme_stylebox_override("hover", h)


func _vsep() -> VSeparator:
	var s := VSeparator.new()
	s.custom_minimum_size = Vector2(4, 0)
	return s
