## MainMenu.gd
## Minimal entry screen: "New Map" and "Load Map".
## Switches to the MapEditor scene when a choice is made.
## Built entirely in code — no .tscn required.

extends Node2D

const MAP_EDITOR_SCENE: String = "res://scenes/MapEditor.tscn"
const SAVE_DIR: String = "user://maps/"


func _ready() -> void:
	_build_ui()


func _build_ui() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)

	# Full-screen dark background
	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.07, 0.09)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(bg)

	# Centered VBox
	var center := VBoxContainer.new()
	center.set_anchors_preset(Control.PRESET_CENTER)
	center.grow_horizontal = Control.GROW_DIRECTION_BOTH
	center.grow_vertical = Control.GROW_DIRECTION_BOTH
	center.add_theme_constant_override("separation", 20)
	canvas.add_child(center)

	# Title
	var title := Label.new()
	title.text = "⚔  Hex Map Editor"
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color(0.9, 0.75, 0.25))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center.add_child(title)

	var sub := Label.new()
	sub.text = "Battle for Wesnoth — style"
	sub.add_theme_font_size_override("font_size", 14)
	sub.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center.add_child(sub)

	# Spacer
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 24)
	center.add_child(gap)

	# New Map button
	var btn_new: Button = _make_btn("✦  New Map", Color(0.15, 0.38, 0.70))
	btn_new.pressed.connect(_on_new_map)
	center.add_child(btn_new)

	# Load Map button
	var btn_load: Button = _make_btn("📂  Load Map", Color(0.20, 0.38, 0.20))
	btn_load.pressed.connect(_on_load_map)
	center.add_child(btn_load)

	# Status label (shows errors / file-not-found)
	var status := Label.new()
	status.name = "Status"
	status.text = ""
	status.add_theme_font_size_override("font_size", 12)
	status.add_theme_color_override("font_color", Color(0.75, 0.35, 0.35))
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center.add_child(status)


func _make_btn(txt: String, tint: Color) -> Button:
	var btn := Button.new()
	btn.text = txt
	btn.custom_minimum_size = Vector2(280, 52)
	btn.add_theme_font_size_override("font_size", 18)

	var sn := StyleBoxFlat.new()
	sn.bg_color = tint.darkened(0.3)
	sn.border_color = tint.lightened(0.2)
	sn.set_border_width_all(1)
	sn.set_corner_radius_all(8)
	sn.content_margin_left = 16
	sn.content_margin_right = 16
	btn.add_theme_stylebox_override("normal", sn)

	var sh: StyleBoxFlat = sn.duplicate()
	sh.bg_color = tint
	btn.add_theme_stylebox_override("hover", sh)

	var sp: StyleBoxFlat = sn.duplicate()
	sp.bg_color = tint.darkened(0.1)
	btn.add_theme_stylebox_override("pressed", sp)

	return btn


func _on_new_map() -> void:
	# Go straight to the editor with no save file path set
	get_tree().change_scene_to_file(MAP_EDITOR_SCENE)


func _on_load_map() -> void:
	# Show a native file dialog to pick a .hexmap file
	var dialog := FileDialog.new()
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	dialog.access = FileDialog.ACCESS_USERDATA
	dialog.current_dir = SAVE_DIR
	dialog.filters = PackedStringArray(["*.hexmap ; Hex Map Files"])
	dialog.title = "Load Map"
	dialog.confirmed.connect(_load_chosen.bind(dialog))
	dialog.file_selected.connect(_load_file)
	add_child(dialog)
	dialog.popup_centered(Vector2(700, 500))


func _load_chosen(dialog: FileDialog) -> void:
	dialog.queue_free()


func _load_file(path: String) -> void:
	if not FileAccess.file_exists(path):
		_set_status("File not found: " + path)
		return
	# Store path so MapEditor can pick it up on _ready
	MapEditorBridge.pending_load_path = path
	get_tree().change_scene_to_file(MAP_EDITOR_SCENE)


func _set_status(msg: String) -> void:
	var s: Label = get_node_or_null("CanvasLayer/ColorRect/../Status") as Label
	if s:
		s.text = msg
