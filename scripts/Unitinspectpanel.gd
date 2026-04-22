## UnitInspectPanel.gd
## Right-side panel showing full unit details including equipment.
##
## Layout: VBoxContainer fills the whole panel.
##   - Fixed header (portrait, name, faction, HP bar)
##   - ScrollContainer expands to fill remaining space

class_name UnitInspectPanel
extends Control

const PANEL_WIDTH: float = 240.0

var _bg:          ColorRect
var _close_btn:   Button
var _portrait:    TextureRect
var _name_lbl:    Label
var _faction_lbl: Label
var _hp_bar_bg:   ColorRect
var _hp_bar_fill: ColorRect
var _hp_lbl:      Label

var _scroll:  ScrollContainer
var _content: VBoxContainer

var _unit: BaseUnit = null


func _ready() -> void:
	set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	custom_minimum_size = Vector2(PANEL_WIDTH, 0)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_build()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED or what == NOTIFICATION_READY:
		var vp := get_viewport_rect() if get_viewport() else Rect2()
		if vp.size.y > 0:
			size     = Vector2(PANEL_WIDTH, vp.size.y)
			position = Vector2(vp.size.x - PANEL_WIDTH, 0)


func _build() -> void:
	_bg = ColorRect.new()
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg.color = Color(0.06, 0.06, 0.09, 0.97)
	add_child(_bg)

	var accent := ColorRect.new()
	accent.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	accent.size.x = 3
	accent.color = Color(0.35, 0.55, 1.0, 0.85)
	add_child(accent)

	# Root VBoxContainer: header shrinks, scroll expands
	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 0)
	add_child(root)

	# Header margin wrapper
	var hm := MarginContainer.new()
	hm.add_theme_constant_override("margin_left",   12)
	hm.add_theme_constant_override("margin_right",  12)
	hm.add_theme_constant_override("margin_top",    10)
	hm.add_theme_constant_override("margin_bottom", 6)
	hm.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	root.add_child(hm)

	var header := VBoxContainer.new()
	header.add_theme_constant_override("separation", 4)
	hm.add_child(header)

	# Portrait row
	var portrait_row := HBoxContainer.new()
	portrait_row.add_theme_constant_override("separation", 10)
	header.add_child(portrait_row)

	var port_panel := PanelContainer.new()
	port_panel.custom_minimum_size = Vector2(72, 72)
	var port_style := StyleBoxFlat.new()
	port_style.bg_color     = Color(0.12, 0.12, 0.18)
	port_style.border_color = Color(0.30, 0.30, 0.45)
	port_style.set_border_width_all(1)
	port_panel.add_theme_stylebox_override("panel", port_style)
	portrait_row.add_child(port_panel)

	_portrait = TextureRect.new()
	_portrait.expand_mode  = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait.set_anchors_preset(Control.PRESET_FULL_RECT)
	port_panel.add_child(_portrait)

	var info_col := VBoxContainer.new()
	info_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_col.add_theme_constant_override("separation", 4)
	portrait_row.add_child(info_col)

	_name_lbl = Label.new()
	_name_lbl.add_theme_font_size_override("font_size", 17)
	_name_lbl.add_theme_color_override("font_color", Color(0.92, 0.85, 0.60))
	_name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_col.add_child(_name_lbl)

	_faction_lbl = Label.new()
	_faction_lbl.add_theme_font_size_override("font_size", 11)
	_faction_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_col.add_child(_faction_lbl)

	_close_btn = Button.new()
	_close_btn.text = "× Close"
	_close_btn.flat = true
	_close_btn.add_theme_font_size_override("font_size", 11)
	_close_btn.add_theme_color_override("font_color", Color(0.55, 0.55, 0.60))
	_close_btn.add_theme_color_override("font_color_hover", Color(1.0, 0.4, 0.4))
	_close_btn.pressed.connect(hide_panel)
	info_col.add_child(_close_btn)

	var hp_title := Label.new()
	hp_title.text = "HIT POINTS"
	hp_title.add_theme_font_size_override("font_size", 10)
	hp_title.add_theme_color_override("font_color", Color(0.40, 0.45, 0.60))
	header.add_child(hp_title)

	_hp_lbl = Label.new()
	_hp_lbl.add_theme_font_size_override("font_size", 11)
	_hp_lbl.add_theme_color_override("font_color", Color(0.70, 0.70, 0.70))
	header.add_child(_hp_lbl)

	var bar_wrap := Control.new()
	bar_wrap.custom_minimum_size = Vector2(0, 10)
	bar_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(bar_wrap)

	_hp_bar_bg = ColorRect.new()
	_hp_bar_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hp_bar_bg.color = Color(0.15, 0.15, 0.18)
	bar_wrap.add_child(_hp_bar_bg)

	_hp_bar_fill = ColorRect.new()
	_hp_bar_fill.set_anchor(SIDE_LEFT,   0.0)
	_hp_bar_fill.set_anchor(SIDE_TOP,    0.0)
	_hp_bar_fill.set_anchor(SIDE_BOTTOM, 1.0)
	_hp_bar_fill.set_anchor(SIDE_RIGHT,  1.0)
	_hp_bar_fill.color = Color(0.15, 0.80, 0.30)
	bar_wrap.add_child(_hp_bar_fill)

	# Divider between header and scroll
	var div := ColorRect.new()
	div.custom_minimum_size = Vector2(0, 1)
	div.color = Color(0.22, 0.22, 0.30)
	root.add_child(div)

	# Scroll area fills all remaining space
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(_scroll)

	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 2)
	_scroll.add_child(_content)


# ════════════════════════════════════════════════════════════════════
# Public API
# ════════════════════════════════════════════════════════════════════

func show_unit(unit: BaseUnit) -> void:
	_unit = unit
	_populate(unit)
	visible = true


func hide_panel() -> void:
	visible = false
	_unit = null


func refresh() -> void:
	if _unit != null and visible:
		_populate(_unit)


# ════════════════════════════════════════════════════════════════════
# Populate
# ════════════════════════════════════════════════════════════════════

func _populate(unit: BaseUnit) -> void:
	var type_name := UnitData.get_unit_name(unit.unit_type).to_lower()
	var path := "res://assets/units/%s.png" % type_name
	_portrait.texture = load(path) if ResourceLoader.exists(path) else null

	if unit.faction == UnitData.Faction.PLAYER:
		_portrait.modulate = Color(0.85, 0.95, 1.0)
		_faction_lbl.text  = "▲  PLAYER"
		_faction_lbl.add_theme_color_override("font_color", Color(0.40, 0.65, 1.0))
	else:
		_portrait.modulate = Color(1.0, 0.85, 0.85)
		_faction_lbl.text  = "▼  ENEMY"
		_faction_lbl.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35))

	_name_lbl.text = unit.unit_name

	var ratio: float = float(unit.hp) / float(unit.hp_max)
	_hp_lbl.text = "%d / %d" % [unit.hp, unit.hp_max]
	_hp_bar_fill.anchor_right = ratio
	var t := ratio
	_hp_bar_fill.color = Color(1.0 - t, t * 0.85, 0.0).lerp(Color(0.10, 0.85, 0.25), t * 0.6)

	for child in _content.get_children():
		child.queue_free()

	_add_weapons_section(unit)
	_add_divider()
	_add_protection_section(unit)
	_add_divider()
	_add_steed_section(unit)
	_add_divider()
	_add_combat_stats_section(unit)
	_add_divider()
	_add_terrain_section(unit)


# ════════════════════════════════════════════════════════════════════
# Sections
# ════════════════════════════════════════════════════════════════════

func _add_weapons_section(unit: BaseUnit) -> void:
	_content.add_child(_section_title("⚔  WEAPONS"))

	var pw: Dictionary = EquipmentData.WEAPONS[unit.primary_weapon]
	var sw: Dictionary = EquipmentData.WEAPONS[unit.secondary_weapon]
	var is_primary_active := unit.active_weapon == BaseUnit.WeaponSlot.PRIMARY

	var p_label := "▶ PRIMARY" if is_primary_active else "   PRIMARY"
	var p_color := Color(0.95, 0.85, 0.30) if is_primary_active else Color(0.50, 0.50, 0.55)
	_content.add_child(_weapon_row(p_label, pw, p_color))

	var s_label := "▶ SECONDARY" if not is_primary_active else "   SECONDARY"
	var s_color := Color(0.95, 0.85, 0.30) if not is_primary_active else Color(0.50, 0.50, 0.55)
	_content.add_child(_weapon_row(s_label, sw, s_color))


func _weapon_row(slot_label: String, wpn: Dictionary, label_color: Color) -> Control:
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 1)

	var slot_lbl := Label.new()
	slot_lbl.text = slot_label
	slot_lbl.add_theme_font_size_override("font_size", 10)
	slot_lbl.add_theme_color_override("font_color", label_color)
	vb.add_child(slot_lbl)

	var name_lbl := Label.new()
	name_lbl.text = "    %s" % wpn["name"]
	name_lbl.add_theme_font_size_override("font_size", 13)
	name_lbl.add_theme_color_override("font_color", Color(0.88, 0.85, 0.78))
	vb.add_child(name_lbl)

	var range_str := "Melee (range 1)" if wpn["attack_range"] <= 1 \
				   else "Ranged (range %d)" % wpn["attack_range"]
	var kind_str := ""
	if wpn["projectile_kind"] >= 0:
		kind_str = "  •  " + ("Arrow" if wpn["projectile_kind"] == ProjectileData.Kind.ARROW else "Arc")

	var stats_lbl := Label.new()
	stats_lbl.text = "    DMG %d  •  %s%s" % [wpn["damage"], range_str, kind_str]
	stats_lbl.add_theme_font_size_override("font_size", 11)
	stats_lbl.add_theme_color_override("font_color", Color(0.60, 0.70, 0.60))
	vb.add_child(stats_lbl)

	var desc_lbl := Label.new()
	desc_lbl.text = "    %s" % wpn["description"]
	desc_lbl.add_theme_font_size_override("font_size", 10)
	desc_lbl.add_theme_color_override("font_color", Color(0.38, 0.38, 0.42))
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.custom_minimum_size = Vector2(PANEL_WIDTH - 20, 0)
	vb.add_child(desc_lbl)

	var pad := Control.new()
	pad.custom_minimum_size = Vector2(0, 4)
	vb.add_child(pad)

	return vb


func _add_protection_section(unit: BaseUnit) -> void:
	_content.add_child(_section_title("🛡  PROTECTION"))

	var a_info: Dictionary = EquipmentData.ARMORS[unit.armor]
	var h_info: Dictionary = EquipmentData.HELMETS[unit.helmet]

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 4)
	_content.add_child(grid)

	_grid_row(grid, "Armor",  "%s  (−%d)" % [a_info["name"], a_info["damage_reduction"]])
	_grid_row(grid, "Helmet", "%s  (−%d)" % [h_info["name"], h_info["damage_reduction"]])

	var total_lbl_k := _make_key_label("Total reduction")
	var total_lbl_v := _make_val_label("-%d per hit" % unit.protection)
	if unit.protection == 0:
		total_lbl_v.add_theme_color_override("font_color", Color(0.60, 0.30, 0.30))
	else:
		total_lbl_v.add_theme_color_override("font_color", Color(0.35, 0.85, 0.50))
	grid.add_child(total_lbl_k)
	grid.add_child(total_lbl_v)

	var note := Label.new()
	note.text = "  Min 1 damage always dealt."
	note.add_theme_font_size_override("font_size", 10)
	note.add_theme_color_override("font_color", Color(0.35, 0.35, 0.40))
	_content.add_child(note)


func _add_steed_section(unit: BaseUnit) -> void:
	_content.add_child(_section_title("🐎  MOUNT"))

	var s_info: Dictionary = EquipmentData.STEEDS[unit.steed]
	var mounted := unit.steed != EquipmentData.SteedType.NONE

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 4)
	_content.add_child(grid)

	_grid_row(grid, "Mount", s_info["name"])

	if mounted:
		_grid_row(grid, "Move range", str(s_info["move_range"]) + " (mounted)")
		_grid_row(grid, "Foot range", str(UnitData.UNITS[unit.unit_type]["move_range"]) + " (dismounted)")
		var note := Label.new()
		note.text = "  " + s_info["description"]
		note.add_theme_font_size_override("font_size", 10)
		note.add_theme_color_override("font_color", Color(0.70, 0.65, 0.30))
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		note.custom_minimum_size = Vector2(PANEL_WIDTH - 20, 0)
		_content.add_child(note)
	else:
		_grid_row(grid, "Move range", str(UnitData.UNITS[unit.unit_type]["move_range"]) + " (on foot)")


func _add_combat_stats_section(unit: BaseUnit) -> void:
	_content.add_child(_section_title("📊  TURN STATE"))

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 4)
	_content.add_child(grid)

	var slot_name := "Primary" if unit.active_weapon == BaseUnit.WeaponSlot.PRIMARY else "Secondary"
	_grid_row(grid, "Active weapon", slot_name)
	_grid_row(grid, "Attack damage", str(unit.attack))
	_grid_row(grid, "Attack range",  str(unit.attack_range))
	_grid_row(grid, "Moves left",    str(unit.moves_left) + " / " + str(unit.move_range))
	_grid_row(grid, "Has attacked",  "Yes" if unit.has_attacked else "No")
	_grid_row(grid, "Position",      "(%d, %d)" % [unit.hex_pos.x, unit.hex_pos.y])


func _add_terrain_section(unit: BaseUnit) -> void:
	var mounted := unit.steed != EquipmentData.SteedType.NONE
	var title := "🗺  TERRAIN COSTS" + (" (mounted)" if mounted else " (on foot)")
	_content.add_child(_section_title(title))

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 4)
	_content.add_child(grid)

	var terrain_names := ["Flat", "Hilly", "Mountain", "Water"]
	var terrain_icons := ["🌿", "⛰", "🗻", "🌊"]
	var dummy_cell := TerrainData.HexCell.new()

	for i in range(4):
		dummy_cell.base    = i as TerrainData.Base
		dummy_cell.overlay = TerrainData.Overlay.NONE
		var cost: int = unit.terrain_cost(dummy_cell)

		var key_lbl := _make_key_label("%s %s" % [terrain_icons[i], terrain_names[i]])
		var val_lbl := _make_val_label("inf" if cost >= 99 else str(cost))
		if cost >= 99:
			val_lbl.add_theme_color_override("font_color", Color(0.80, 0.25, 0.25))
		elif cost == 1:
			val_lbl.add_theme_color_override("font_color", Color(0.35, 0.85, 0.40))
		else:
			val_lbl.add_theme_color_override("font_color", Color(0.90, 0.75, 0.25))
		grid.add_child(key_lbl)
		grid.add_child(val_lbl)


# ════════════════════════════════════════════════════════════════════
# Widget helpers
# ════════════════════════════════════════════════════════════════════

func _section_title(txt: String) -> Control:
	var vb := VBoxContainer.new()
	var pad := Control.new()
	pad.custom_minimum_size = Vector2(0, 6)
	vb.add_child(pad)
	var lbl := Label.new()
	lbl.text = txt
	lbl.add_theme_font_size_override("font_size", 10)
	lbl.add_theme_color_override("font_color", Color(0.40, 0.45, 0.60))
	vb.add_child(lbl)
	return vb


func _add_divider() -> void:
	var div := ColorRect.new()
	div.custom_minimum_size = Vector2(PANEL_WIDTH - 28, 1)
	div.color = Color(0.20, 0.20, 0.28)
	_content.add_child(div)


func _grid_row(grid: GridContainer, key: String, val: String) -> void:
	grid.add_child(_make_key_label(key))
	grid.add_child(_make_val_label(val))


func _make_key_label(txt: String) -> Label:
	var lbl := Label.new()
	lbl.text = "  " + txt
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
