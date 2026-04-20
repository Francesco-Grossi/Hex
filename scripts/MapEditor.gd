## MapEditor.gd
## Root scene script — two modes: EDIT and BATTLE.
##
## Terrain is now two-layered:
##   _terrain_map stores Dictionary[Vector2i, TerrainData.HexCell]
##
## The editor palette has two rows:
##   Row A — Base terrain buttons  (Flat / Hilly / Mountain / Water)
##   Row B — Overlay buttons       (None / Forest / Building / Wall)
##
## Active brush paints either the base OR the overlay layer depending
## on which button was last pressed.  Both layers can be painted
## independently without resetting the other.

extends Node2D

const COLS:     int   = 18
const ROWS:     int   = 11
const HEX_SIZE: float = 72

# ── App / edit modes ─────────────────────────────────────────────────
enum AppMode  { EDIT, BATTLE }
enum EditMode { PAINT_BASE, PAINT_OVERLAY, MOVE_PREVIEW }

var _app_mode:       AppMode  = AppMode.EDIT
var _edit_mode:      EditMode = EditMode.PAINT_BASE
var _active_base:    TerrainData.Base    = TerrainData.Base.FLAT
var _active_overlay: TerrainData.Overlay = TerrainData.Overlay.FOREST

# ── Grid state ───────────────────────────────────────────────────────
var _tiles:       Dictionary = {}   # Vector2i → HexTile
var _terrain_map: Dictionary = {}   # Vector2i → TerrainData.HexCell

# ── Edit preview ─────────────────────────────────────────────────────
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
var _edit_panel:   VBoxContainer   # holds both palette rows

var _base_buttons:    Dictionary = {}   # Base    int → Button
var _overlay_buttons: Dictionary = {}   # Overlay int → Button
var _mode_buttons:    Dictionary = {}   # EditMode int → Button

# ── Battle ───────────────────────────────────────────────────────────
var _battle: BattleManager = null
var _player_placements: Array = []
var _enemy_placements:  Array = []

# ── Pan ──────────────────────────────────────────────────────────────
var _panning:    bool    = false
var _pan_origin: Vector2 = Vector2.ZERO
var _cam_origin: Vector2 = Vector2.ZERO


func _ready() -> void:
	_build_camera()
	_build_grid_nodes()
	_build_ui()
	call_deferred("_deferred_start")


func _deferred_start() -> void:
	_spawn_grid()
	_apply_default_map()
	_center_camera()
	_update_status()


# ════════════════════════════════════════════════════════════════════
# Scene bootstrap
# ════════════════════════════════════════════════════════════════════

func _build_camera() -> void:
	_camera = Camera2D.new()
	_camera.zoom = Vector2(1.0, 1.0)
	add_child(_camera)
	_camera.make_current()


func _build_grid_nodes() -> void:
	var bg := ColorRect.new()
	bg.color    = Color(0.10, 0.10, 0.12)
	bg.size     = Vector2(8000, 8000)
	bg.position = Vector2(-4000, -4000)
	bg.z_index  = -10
	add_child(bg)

	_grid_root  = Node2D.new()
	_grid_root.name = "GridRoot"
	add_child(_grid_root)

	_unit_layer = Node2D.new()
	_unit_layer.name = "UnitLayer"
	add_child(_unit_layer)


func _build_ui() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 10
	add_child(canvas)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(0.08, 0.08, 0.10, 1.0)
	ps.set_corner_radius_all(0)
	ps.set_expand_margin_all(0)
	panel.add_theme_stylebox_override("panel", ps)
	canvas.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	panel.add_child(vbox)

	# ── Row 1: toolbar ───────────────────────────────────────────────
	var row1 := HBoxContainer.new()
	row1.add_theme_constant_override("separation", 6)
	vbox.add_child(row1)

	var title := Label.new()
	title.text = "  ⚔ Hex Map"
	title.add_theme_color_override("font_color", Color(0.9, 0.75, 0.3))
	title.add_theme_font_size_override("font_size", 16)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row1.add_child(title)

	# Edit mode buttons
	var mode_defs: Array = [
		[EditMode.PAINT_BASE,    "⛰ Base"],
		[EditMode.PAINT_OVERLAY, "🌲 Overlay"],
		[EditMode.MOVE_PREVIEW,  "👣 Preview"],
	]
	for md in mode_defs:
		var btn := _make_btn(md[1])
		btn.pressed.connect(_on_edit_mode.bind(md[0]))
		_mode_buttons[md[0]] = btn
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

	# ── Edit panel (rows 2 & 3): terrain palettes ────────────────────
	_edit_panel = VBoxContainer.new()
	_edit_panel.add_theme_constant_override("separation", 3)
	vbox.add_child(_edit_panel)

	# Base terrain row
	var base_row := HBoxContainer.new()
	base_row.add_theme_constant_override("separation", 5)
	_edit_panel.add_child(base_row)

	var bl := Label.new()
	bl.text = "  Base:"
	bl.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55))
	bl.add_theme_font_size_override("font_size", 12)
	base_row.add_child(bl)

	for b: int in TerrainData.BASE_DATA.keys():
		var info: Dictionary = TerrainData.BASE_DATA[b]
		var btn := _make_terrain_btn(info["name"], info["color"])
		btn.pressed.connect(_on_base_terrain.bind(b))
		_base_buttons[b] = btn
		base_row.add_child(btn)

	# Overlay row
	var overlay_row := HBoxContainer.new()
	overlay_row.add_theme_constant_override("separation", 5)
	_edit_panel.add_child(overlay_row)

	var ol := Label.new()
	ol.text = "  Overlay:"
	ol.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55))
	ol.add_theme_font_size_override("font_size", 12)
	overlay_row.add_child(ol)

	var overlay_colors: Dictionary = {
		TerrainData.Overlay.NONE:     Color(0.30, 0.30, 0.30),
		TerrainData.Overlay.FOREST:   Color(0.12, 0.45, 0.12),
		TerrainData.Overlay.BUILDING: Color(0.55, 0.42, 0.28),
		TerrainData.Overlay.WALL:     Color(0.40, 0.38, 0.36),
	}
	for o: int in TerrainData.OVERLAY_DATA.keys():
		var info: Dictionary = TerrainData.OVERLAY_DATA[o]
		var btn := _make_terrain_btn(info["name"], overlay_colors[o])
		btn.pressed.connect(_on_overlay.bind(o))
		_overlay_buttons[o] = btn
		overlay_row.add_child(btn)

	# ── Status row ───────────────────────────────────────────────────
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

	# ── Hint row ─────────────────────────────────────────────────────
	var row4 := HBoxContainer.new()
	vbox.add_child(row4)
	var hint := Label.new()
	hint.text = "  Scroll=zoom  RMB+drag=pan  |  Base=ground layer  Overlay=objects on top"
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
			var tile  := HexTile.new()
			tile.hex_coord = coord
			tile.position  = HexGrid.axial_to_world(coord, HEX_SIZE)
			_grid_root.add_child(tile)
			_tiles[coord]       = tile
			_terrain_map[coord] = TerrainData.HexCell.new()   # default FLAT/NONE


func _center_camera() -> void:
	_camera.position = HexGrid.axial_to_world(
		Vector2i(COLS / 2, ROWS / 2), HEX_SIZE)


func _apply_default_map() -> void:
	# Water lake
	for h: Vector2i in [Vector2i(4,2), Vector2i(5,2), Vector2i(6,2),
						 Vector2i(5,3), Vector2i(4,4), Vector2i(5,4),
						 Vector2i(4,5), Vector2i(5,5)]:
		_set_base(h, TerrainData.Base.WATER)

	# Hilly terrain
	for h: Vector2i in [Vector2i(10,2), Vector2i(11,2), Vector2i(10,3),
						 Vector2i(11,3), Vector2i(9,3)]:
		_set_base(h, TerrainData.Base.HILLY)

	# Forest on hills
	for h: Vector2i in [Vector2i(10,2), Vector2i(11,2), Vector2i(10,3)]:
		_set_overlay(h, TerrainData.Overlay.FOREST)

	# Mountains
	for h: Vector2i in [Vector2i(14,1), Vector2i(15,1), Vector2i(14,2),
						 Vector2i(15,2), Vector2i(13,3)]:
		_set_base(h, TerrainData.Base.MOUNTAIN)

	# Forest patch on flat ground
	for h: Vector2i in [Vector2i(12,4), Vector2i(12,5)]:
		_set_overlay(h, TerrainData.Overlay.FOREST)

	# Walled settlement
	for h: Vector2i in [Vector2i(7,7), Vector2i(8,7)]:
		_set_overlay(h, TerrainData.Overlay.WALL)
	for h: Vector2i in [Vector2i(8,8), Vector2i(9,8)]:
		_set_overlay(h, TerrainData.Overlay.BUILDING)


# ════════════════════════════════════════════════════════════════════
# Battle
# ════════════════════════════════════════════════════════════════════

func _on_toggle_battle() -> void:
	if _app_mode == AppMode.EDIT:
		_show_battle_setup()
	else:
		_exit_battle()


func _show_battle_setup() -> void:
	var canvas: CanvasLayer = null
	for child in get_children():
		if child is CanvasLayer:
			canvas = child
			break
	if canvas == null:
		_enter_battle()
		return

	var overlay := ColorRect.new()
	overlay.name    = "BattleSetupOverlay"
	overlay.color   = Color(0, 0, 0, 0.70)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(overlay)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical   = Control.GROW_DIRECTION_BOTH
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(0.10, 0.10, 0.14)
	ps.set_border_width_all(1)
	ps.border_color = Color(0.35, 0.35, 0.50)
	ps.set_corner_radius_all(8)
	ps.set_expand_margin_all(20)
	panel.add_theme_stylebox_override("panel", ps)
	overlay.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	vbox.custom_minimum_size = Vector2(480, 0)
	panel.add_child(vbox)

	var title_lbl := Label.new()
	title_lbl.text = "⚔  Battle Setup"
	title_lbl.add_theme_font_size_override("font_size", 20)
	title_lbl.add_theme_color_override("font_color", Color(0.9, 0.75, 0.25))
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title_lbl)
	vbox.add_child(HSeparator.new())

	var p_enums   := [UnitData.Type.KNIGHT, UnitData.Type.ARCHER, UnitData.Type.MAGE]
	var e_enums   := [UnitData.Type.ORC,    UnitData.Type.GOBLIN,  UnitData.Type.TROLL]
	var p_names   := ["Knight", "Archer", "Mage"]
	var e_names   := ["Orc", "Goblin", "Troll"]
	var p_defs: Array = [Vector2i(1,4), Vector2i(1,6), Vector2i(2,5)]
	var e_defs: Array = [Vector2i(16,3), Vector2i(15,5), Vector2i(16,7)]

	var player_rows: Array = []
	var enemy_rows:  Array = []

	for faction_idx in range(2):
		var is_player := faction_idx == 0
		var header    := Label.new()
		header.text   = "── %s ──" % ("Player Units" if is_player else "Enemy Units")
		header.add_theme_color_override("font_color",
			Color(0.4, 0.6, 1.0) if is_player else Color(1.0, 0.4, 0.4))
		header.add_theme_font_size_override("font_size", 13)
		vbox.add_child(header)

		var names    := p_names if is_player else e_names
		var defaults := p_defs  if is_player else e_defs
		var rows_ref := player_rows if is_player else enemy_rows

		for i in range(3):
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 6)
			vbox.add_child(row)

			var chk := CheckBox.new()
			chk.button_pressed = true
			row.add_child(chk)

			var opt := OptionButton.new()
			opt.custom_minimum_size = Vector2(100, 0)
			for n in names: opt.add_item(n)
			opt.selected = i
			row.add_child(opt)

			var ql := Label.new(); ql.text = "  Q:"
			ql.add_theme_color_override("font_color", Color(0.6,0.6,0.6))
			row.add_child(ql)

			var q_spin := SpinBox.new()
			q_spin.min_value = 0; q_spin.max_value = COLS - 1
			q_spin.value = defaults[i].x
			q_spin.custom_minimum_size = Vector2(65, 0)
			row.add_child(q_spin)

			var rl := Label.new(); rl.text = "  R:"
			rl.add_theme_color_override("font_color", Color(0.6,0.6,0.6))
			row.add_child(rl)

			var r_spin := SpinBox.new()
			r_spin.min_value = 0; r_spin.max_value = ROWS - 1
			r_spin.value = defaults[i].y
			r_spin.custom_minimum_size = Vector2(65, 0)
			row.add_child(r_spin)

			rows_ref.append({"chk": chk, "opt": opt, "q": q_spin, "r": r_spin})

	vbox.add_child(HSeparator.new())

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 16)
	vbox.add_child(btn_row)

	var cancel_btn := _make_btn("Cancel")
	cancel_btn.custom_minimum_size = Vector2(110, 36)
	cancel_btn.pressed.connect(func() -> void: overlay.queue_free())
	btn_row.add_child(cancel_btn)

	var start_btn := _make_btn("▶  Start Battle")
	start_btn.custom_minimum_size = Vector2(150, 36)
	_tint_btn(start_btn, Color(0.10, 0.40, 0.10))
	start_btn.pressed.connect(func() -> void:
		_player_placements.clear()
		_enemy_placements.clear()
		for row in player_rows:
			if row["chk"].button_pressed:
				_player_placements.append([
					p_enums[row["opt"].selected],
					Vector2i(int(row["q"].value), int(row["r"].value))])
		for row in enemy_rows:
			if row["chk"].button_pressed:
				_enemy_placements.append([
					e_enums[row["opt"].selected],
					Vector2i(int(row["q"].value), int(row["r"].value))])
		overlay.queue_free()
		_enter_battle()
	)
	btn_row.add_child(start_btn)


func _enter_battle() -> void:
	_app_mode = AppMode.BATTLE
	_edit_panel.visible = false
	_turn_btn.visible   = true
	_battle_btn.text    = "✎ Back to Edit"
	_tint_btn(_battle_btn, Color(0.15, 0.20, 0.55))
	_clear_preview()

	_battle = BattleManager.new()
	_battle.setup(_tiles, _terrain_map, _unit_layer, _status_label)
	_battle.status_changed.connect(func(t: String) -> void: _status_label.text = t)
	_battle.phase_changed.connect(_on_phase_changed)
	add_child(_battle)
	_battle.start_battle(_player_placements, _enemy_placements)


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
			_turn_btn.text = "⏭ End Turn"; _turn_btn.disabled = false
		BattleManager.Phase.ENEMY:
			_turn_btn.text = "⏳ Enemy…";  _turn_btn.disabled = true
		BattleManager.Phase.VICTORY:
			_turn_btn.text = "🏆 Victory!"; _turn_btn.disabled = true
		BattleManager.Phase.DEFEAT:
			_turn_btn.text = "💀 Defeat";  _turn_btn.disabled = true


# ════════════════════════════════════════════════════════════════════
# Input
# ════════════════════════════════════════════════════════════════════

func _input(event: InputEvent) -> void:
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
	for child in get_children():
		if child is CanvasLayer:
			for ctrl in child.get_children():
				if ctrl is Control and ctrl.get_rect().has_point(screen_pos):
					return
	var hex := _screen_to_hex(screen_pos)

	if _app_mode == AppMode.BATTLE:
		if _battle != null:
			_battle.handle_hex_click(hex)
		return

	if not _tiles.has(hex):
		return
	match _edit_mode:
		EditMode.PAINT_BASE:
			_set_base(hex, _active_base)
		EditMode.PAINT_OVERLAY:
			_set_overlay(hex, _active_overlay)
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
			var cell: TerrainData.HexCell = _terrain_map[hex]
			_status_label.text = "Hex (%d,%d) — %s / %s" % [
				hex.x, hex.y,
				TerrainData.base_name(cell.base),
				TerrainData.overlay_name(cell.overlay)]


func _screen_to_hex(screen_pos: Vector2) -> Vector2i:
	var vp_size     := get_viewport().get_visible_rect().size
	var screen_center := vp_size * 0.5
	var world := _camera.global_position + (screen_pos - screen_center) / _camera.zoom
	return HexGrid.world_to_axial(world, HEX_SIZE)


# ════════════════════════════════════════════════════════════════════
# Terrain setters
# ════════════════════════════════════════════════════════════════════

func _set_base(hex: Vector2i, base: TerrainData.Base) -> void:
	if not _tiles.has(hex):
		return
	_terrain_map[hex].base = base
	_tiles[hex].set_base(base)


func _set_overlay(hex: Vector2i, overlay: TerrainData.Overlay) -> void:
	if not _tiles.has(hex):
		return
	_terrain_map[hex].overlay = overlay
	_tiles[hex].set_overlay(overlay)


# ════════════════════════════════════════════════════════════════════
# Preview movement
# ════════════════════════════════════════════════════════════════════

func _move_preview(hex: Vector2i) -> void:
	_clear_preview()
	_preview_pos = hex
	_compute_preview()
	_apply_preview()
	_status_label.text = "Preview at (%d,%d)" % [hex.x, hex.y]


func _compute_preview() -> void:
	_preview_reachable = HexGrid.reachable(
		_preview_pos, 4,
		func(h: Vector2i) -> bool:
			if not _terrain_map.has(h): return true
			return not _terrain_map[h].is_passable()
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
	if _edit_mode == EditMode.MOVE_PREVIEW and mode != EditMode.MOVE_PREVIEW:
		_clear_preview()
	_edit_mode = mode
	if _edit_mode == EditMode.MOVE_PREVIEW:
		_compute_preview()
		_apply_preview()
	_refresh_buttons()
	_update_status()


func _on_base_terrain(base: TerrainData.Base) -> void:
	_active_base = base
	_on_edit_mode(EditMode.PAINT_BASE)


func _on_overlay(overlay: TerrainData.Overlay) -> void:
	_active_overlay = overlay
	_on_edit_mode(EditMode.PAINT_OVERLAY)


func _clear_map() -> void:
	_clear_preview()
	for coord: Vector2i in _tiles:
		var cell := TerrainData.HexCell.new()
		_terrain_map[coord] = cell
		_tiles[coord].set_cell(cell)
	_update_status()


func _update_status() -> void:
	if _app_mode == AppMode.BATTLE:
		return
	match _edit_mode:
		EditMode.PAINT_BASE:
			_status_label.text = "Paint base — %s  |  RMB+drag=pan  Scroll=zoom" % \
				TerrainData.base_name(_active_base)
		EditMode.PAINT_OVERLAY:
			_status_label.text = "Paint overlay — %s  |  RMB+drag=pan  Scroll=zoom" % \
				TerrainData.overlay_name(_active_overlay)
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

	for b: int in _base_buttons:
		var btn: Button = _base_buttons[b]
		var col: Color  = TerrainData.BASE_DATA[b]["color"]
		var s := btn.get_theme_stylebox("normal").duplicate() as StyleBoxFlat
		if b == _active_base and _edit_mode == EditMode.PAINT_BASE:
			s.bg_color     = col.darkened(0.10)
			s.border_color = Color(1.0, 0.9, 0.3)
			s.set_border_width_all(2)
		else:
			s.bg_color     = col.darkened(0.45)
			s.border_color = col.lightened(0.1)
			s.set_border_width_all(1)
		btn.add_theme_stylebox_override("normal", s)

	var ov_colors: Dictionary = {
		TerrainData.Overlay.NONE:     Color(0.30, 0.30, 0.30),
		TerrainData.Overlay.FOREST:   Color(0.12, 0.45, 0.12),
		TerrainData.Overlay.BUILDING: Color(0.55, 0.42, 0.28),
		TerrainData.Overlay.WALL:     Color(0.40, 0.38, 0.36),
	}
	for o: int in _overlay_buttons:
		var btn: Button = _overlay_buttons[o]
		var col: Color  = ov_colors[o]
		var s := btn.get_theme_stylebox("normal").duplicate() as StyleBoxFlat
		if o == _active_overlay and _edit_mode == EditMode.PAINT_OVERLAY:
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
	n.bg_color   = Color(0.18, 0.18, 0.22)
	n.border_color = Color(0.35, 0.35, 0.40)
	n.set_border_width_all(1)
	n.set_corner_radius_all(5)
	n.content_margin_left = 10; n.content_margin_right  = 10
	n.content_margin_top  =  4; n.content_margin_bottom =  4
	btn.add_theme_stylebox_override("normal", n)
	var h := n.duplicate() as StyleBoxFlat
	h.bg_color = Color(0.26, 0.26, 0.32)
	btn.add_theme_stylebox_override("hover", h)
	var p := n.duplicate() as StyleBoxFlat
	p.bg_color = Color(0.15, 0.35, 0.65); p.border_color = Color(0.40, 0.65, 1.0)
	btn.add_theme_stylebox_override("pressed", p)
	return btn


func _make_terrain_btn(lbl: String, color: Color) -> Button:
	var btn := _make_btn(lbl)
	var s := btn.get_theme_stylebox("normal").duplicate() as StyleBoxFlat
	s.bg_color = color.darkened(0.45); s.border_color = color.lightened(0.1)
	btn.add_theme_stylebox_override("normal", s)
	var h := s.duplicate() as StyleBoxFlat
	h.bg_color = color.darkened(0.25)
	btn.add_theme_stylebox_override("hover", h)
	return btn


func _tint_btn(btn: Button, color: Color) -> void:
	var s := btn.get_theme_stylebox("normal").duplicate() as StyleBoxFlat
	s.bg_color = color.darkened(0.3); s.border_color = color.lightened(0.2)
	btn.add_theme_stylebox_override("normal", s)
	var h := s.duplicate() as StyleBoxFlat
	h.bg_color = color
	btn.add_theme_stylebox_override("hover", h)


func _vsep() -> VSeparator:
	var s := VSeparator.new()
	s.custom_minimum_size = Vector2(4, 0)
	return s
