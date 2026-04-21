## UnitInspectPanel.gd
## A fixed right-side panel that shows full details for a unit when
## the player right-clicks it.  It lives inside a CanvasLayer so it
## always renders on top of the map.
##
## Usage (from MapEditor or BattleManager):
##   var panel := UnitInspectPanel.new()
##   canvas_layer.add_child(panel)
##   panel.show_unit(some_base_unit)
##   panel.hide_panel()

class_name UnitInspectPanel
extends Control

# ── Layout constants ─────────────────────────────────────────────────
const PANEL_WIDTH: float = 220.0

# ── Internal nodes ───────────────────────────────────────────────────
var _bg:            ColorRect
var _close_btn:     Button
var _portrait:      TextureRect
var _portrait_bg:   ColorRect
var _name_lbl:      Label
var _faction_lbl:   Label
var _divider:       ColorRect
var _hp_bar_bg:     ColorRect
var _hp_bar_fill:   ColorRect
var _hp_lbl:        Label
var _stats_grid:    GridContainer
var _terrain_title: Label
var _terrain_grid:  GridContainer

# ── Tracked unit ─────────────────────────────────────────────────────
var _unit: BaseUnit = null


func _ready() -> void:
	# Panel fills the full viewport height, anchored to the right edge
	set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	custom_minimum_size = Vector2(PANEL_WIDTH, 0)
	size = Vector2(PANEL_WIDTH, 0)          # height set in _notification
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false

	_build()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED or what == NOTIFICATION_READY:
		# Keep panel pinned to the right, full height
		var vp := get_viewport_rect() if get_viewport() else Rect2()
		if vp.size.y > 0:
			size = Vector2(PANEL_WIDTH, vp.size.y)
			position = Vector2(vp.size.x - PANEL_WIDTH, 0)


# ════════════════════════════════════════════════════════════════════
# Build UI
# ════════════════════════════════════════════════════════════════════

func _build() -> void:
	# ── Dark background ──────────────────────────────────────────────
	_bg = ColorRect.new()
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg.color = Color(0.06, 0.06, 0.09, 0.97)
	add_child(_bg)

	# Left accent strip
	var accent := ColorRect.new()
	accent.size = Vector2(3, 0)
	accent.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	accent.color = Color(0.35, 0.55, 1.0, 0.85)
	add_child(accent)

	# ── Close button (×) ─────────────────────────────────────────────
	_close_btn = Button.new()
	_close_btn.text = "×"
	_close_btn.flat = true
	_close_btn.size = Vector2(30, 30)
	_close_btn.position = Vector2(PANEL_WIDTH - 36, 6)
	_close_btn.add_theme_font_size_override("font_size", 20)
	_close_btn.add_theme_color_override("font_color", Color(0.55, 0.55, 0.60))
	_close_btn.add_theme_color_override("font_color_hover", Color(1.0, 0.4, 0.4))
	_close_btn.pressed.connect(hide_panel)
	add_child(_close_btn)

	# ── Portrait area ────────────────────────────────────────────────
	_portrait_bg = ColorRect.new()
	_portrait_bg.position = Vector2(14, 14)
	_portrait_bg.size = Vector2(80, 80)
	_portrait_bg.color = Color(0.12, 0.12, 0.18)
	add_child(_portrait_bg)

	# Portrait border
	var pborder := _make_border(Rect2(13, 13, 82, 82), Color(0.30, 0.30, 0.45))
	add_child(pborder)

	_portrait = TextureRect.new()
	_portrait.position = Vector2(14, 14)
	_portrait.size = Vector2(80, 80)
	_portrait.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	add_child(_portrait)

	# ── Name + faction (right of portrait) ───────────────────────────
	_name_lbl = Label.new()
	_name_lbl.position = Vector2(104, 18)
	_name_lbl.size = Vector2(PANEL_WIDTH - 112, 32)
	_name_lbl.add_theme_font_size_override("font_size", 18)
	_name_lbl.add_theme_color_override("font_color", Color(0.92, 0.85, 0.60))
	_name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_name_lbl)

	_faction_lbl = Label.new()
	_faction_lbl.position = Vector2(104, 52)
	_faction_lbl.size = Vector2(PANEL_WIDTH - 112, 20)
	_faction_lbl.add_theme_font_size_override("font_size", 11)
	add_child(_faction_lbl)

	# ── HP section ───────────────────────────────────────────────────
	var hp_title := _make_section_label("HIT POINTS", Vector2(14, 106))
	add_child(hp_title)

	_hp_lbl = Label.new()
	_hp_lbl.position = Vector2(14, 120)
	_hp_lbl.size = Vector2(PANEL_WIDTH - 28, 18)
	_hp_lbl.add_theme_font_size_override("font_size", 12)
	_hp_lbl.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
	add_child(_hp_lbl)

	_hp_bar_bg = ColorRect.new()
	_hp_bar_bg.position = Vector2(14, 140)
	_hp_bar_bg.size = Vector2(PANEL_WIDTH - 28, 10)
	_hp_bar_bg.color = Color(0.15, 0.15, 0.18)
	add_child(_hp_bar_bg)

	_hp_bar_fill = ColorRect.new()
	_hp_bar_fill.position = Vector2(14, 140)
	_hp_bar_fill.size = Vector2(PANEL_WIDTH - 28, 10)
	_hp_bar_fill.color = Color(0.15, 0.80, 0.30)
	add_child(_hp_bar_fill)

	# HP bar border
	var hpborder := _make_border(Rect2(13, 139, PANEL_WIDTH - 26, 12), Color(0.25, 0.25, 0.30))
	add_child(hpborder)

	# ── Divider ──────────────────────────────────────────────────────
	_divider = ColorRect.new()
	_divider.position = Vector2(14, 162)
	_divider.size = Vector2(PANEL_WIDTH - 28, 1)
	_divider.color = Color(0.22, 0.22, 0.30)
	add_child(_divider)

	# ── Combat stats grid ────────────────────────────────────────────
	var stats_title := _make_section_label("COMBAT STATS", Vector2(14, 172))
	add_child(stats_title)

	_stats_grid = GridContainer.new()
	_stats_grid.columns = 2
	_stats_grid.position = Vector2(14, 190)
	_stats_grid.size = Vector2(PANEL_WIDTH - 28, 0)
	_stats_grid.add_theme_constant_override("h_separation", 8)
	_stats_grid.add_theme_constant_override("v_separation", 6)
	add_child(_stats_grid)

	# ── Divider 2 ────────────────────────────────────────────────────
	var div2 := ColorRect.new()
	div2.position = Vector2(14, 290)
	div2.size = Vector2(PANEL_WIDTH - 28, 1)
	div2.color = Color(0.22, 0.22, 0.30)
	add_child(div2)

	# ── Terrain costs grid ───────────────────────────────────────────
	_terrain_title = _make_section_label("TERRAIN COSTS", Vector2(14, 300))
	add_child(_terrain_title)

	_terrain_grid = GridContainer.new()
	_terrain_grid.columns = 2
	_terrain_grid.position = Vector2(14, 318)
	_terrain_grid.size = Vector2(PANEL_WIDTH - 28, 0)
	_terrain_grid.add_theme_constant_override("h_separation", 8)
	_terrain_grid.add_theme_constant_override("v_separation", 6)
	add_child(_terrain_grid)

	# ── Status strip at bottom ───────────────────────────────────────
	var status_bg := ColorRect.new()
	status_bg.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	status_bg.size = Vector2(0, 32)
	status_bg.color = Color(0.04, 0.04, 0.07)
	add_child(status_bg)


# ════════════════════════════════════════════════════════════════════
# Public API
# ════════════════════════════════════════════════════════════════════

## Populate and show the panel for the given unit.
func show_unit(unit: BaseUnit) -> void:
	_unit = unit
	_populate(unit)
	visible = true
	# Re-pin size in case viewport changed
	var vp := get_viewport_rect()
	size = Vector2(PANEL_WIDTH, vp.size.y)
	position = Vector2(vp.size.x - PANEL_WIDTH, 0)


## Hide the panel without destroying it.
func hide_panel() -> void:
	visible = false
	_unit = null


## Refresh displayed data (call after take_damage / reset_turn).
func refresh() -> void:
	if _unit != null and visible:
		_populate(_unit)


# ════════════════════════════════════════════════════════════════════
# Populate
# ════════════════════════════════════════════════════════════════════

func _populate(unit: BaseUnit) -> void:
	# ── Portrait ─────────────────────────────────────────────────────
	var type_name := UnitData.get_unit_name(unit.unit_type).to_lower()
	var path := "res://assets/units/%s.png" % type_name
	if ResourceLoader.exists(path):
		_portrait.texture = load(path)
	else:
		_portrait.texture = null

	# ── Portrait + badge bg tint by faction ──────────────────────────
	if unit.faction == UnitData.Faction.PLAYER:
		_portrait_bg.color = Color(0.08, 0.10, 0.20)
		_faction_lbl.text  = "▲  PLAYER"
		_faction_lbl.add_theme_color_override("font_color", Color(0.40, 0.65, 1.0))
	else:
		_portrait_bg.color = Color(0.20, 0.08, 0.08)
		_faction_lbl.text  = "▼  ENEMY"
		_faction_lbl.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35))

	# ── Name ─────────────────────────────────────────────────────────
	_name_lbl.text = unit.unit_name

	# ── HP bar ───────────────────────────────────────────────────────
	var ratio: float = float(unit.hp) / float(unit.hp_max)
	_hp_lbl.text = "%d / %d" % [unit.hp, unit.hp_max]
	var bar_max_w: float = PANEL_WIDTH - 28.0
	_hp_bar_fill.size.x = bar_max_w * ratio
	# Colour shifts red→yellow→green
	var t := ratio
	_hp_bar_fill.color = Color(1.0 - t, t * 0.85, 0.0).lerp(Color(0.10, 0.85, 0.25), t * 0.6)

	# ── Combat stats ─────────────────────────────────────────────────
	for child in _stats_grid.get_children():
		child.queue_free()

	var stats: Array = [
		["⚔  Attack",    str(unit.attack)],
		["🏃 Move range", str(unit.move_range)],
		["👣 Moves left", str(unit.moves_left)],
		["🗡 Has attacked", "Yes" if unit.has_attacked else "No"],
		["📍 Position",   "(%d, %d)" % [unit.hex_pos.x, unit.hex_pos.y]],
	]
	for row in stats:
		var key_lbl := _make_key_label(row[0])
		var val_lbl := _make_val_label(row[1])
		_stats_grid.add_child(key_lbl)
		_stats_grid.add_child(val_lbl)

	# ── Terrain costs ─────────────────────────────────────────────────
	for child in _terrain_grid.get_children():
		child.queue_free()

	var costs: Dictionary = UnitData.UNITS[unit.unit_type]["base_costs"]
	var terrain_names := ["Flat", "Hilly", "Mountain", "Water"]
	var terrain_icons := ["🌿", "⛰", "🗻", "🌊"]
	for i in costs.size():
		var cost_val: int = costs[i]
		var label_txt := "%s %s" % [terrain_icons[i], terrain_names[i]]
		var cost_txt  := "∞" if cost_val >= 99 else str(cost_val)
		var key_lbl := _make_key_label(label_txt)
		var val_lbl := _make_val_label(cost_txt)
		if cost_val >= 99:
			val_lbl.add_theme_color_override("font_color", Color(0.80, 0.25, 0.25))
		elif cost_val == 1:
			val_lbl.add_theme_color_override("font_color", Color(0.35, 0.85, 0.40))
		else:
			val_lbl.add_theme_color_override("font_color", Color(0.90, 0.75, 0.25))
		_terrain_grid.add_child(key_lbl)
		_terrain_grid.add_child(val_lbl)


# ════════════════════════════════════════════════════════════════════
# Widget helpers
# ════════════════════════════════════════════════════════════════════

func _make_section_label(txt: String, pos: Vector2) -> Label:
	var lbl := Label.new()
	lbl.text = txt
	lbl.position = pos
	lbl.add_theme_font_size_override("font_size", 10)
	lbl.add_theme_color_override("font_color", Color(0.40, 0.45, 0.60))
	return lbl


func _make_key_label(txt: String) -> Label:
	var lbl := Label.new()
	lbl.text = txt
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", Color(0.55, 0.58, 0.65))
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return lbl


func _make_val_label(txt: String) -> Label:
	var lbl := Label.new()
	lbl.text = txt
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", Color(0.90, 0.88, 0.80))
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return lbl


func _make_border(rect: Rect2, color: Color) -> Control:
	# Thin 1-px border drawn as a ColorRect with draw_rect would need a
	# CanvasItem subclass; simplest approach is a NinePatchRect-free border
	# via a transparent ColorRect on top — we use a Panel instead.
	var p := Panel.new()
	p.position = rect.position
	p.size = rect.size
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)
	sb.border_color = color
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(0)
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p
