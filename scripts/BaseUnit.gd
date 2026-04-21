## BaseUnit.gd
## Universal unit node used for both players and enemies.
## Sprites are loaded from res://assets/units/<type_name>.png
## HP bar and faction badge are still drawn via _draw() on top.
## Call `setup(type)` right after add_child() to initialise.
##
## Right-clicking the unit emits `inspect_requested(unit)` so the
## parent scene can open a detail panel.

class_name BaseUnit
extends Node2D

# ── Identity ─────────────────────────────────────────────────────────
var unit_type: UnitData.Type = UnitData.Type.KNIGHT
var faction: UnitData.Faction = UnitData.Faction.PLAYER

# ── Stats (populated by setup()) ────────────────────────────────────
var hp_max: int    = 10
var hp: int        = 10
var attack: int    = 3
var move_range: int = 4
var unit_name: String = "Unit"

# ── Runtime state ────────────────────────────────────────────────────
var hex_pos: Vector2i = Vector2i.ZERO
var moves_left: int   = 0
var has_attacked: bool = false
var is_alive: bool = true

# ── Visuals ──────────────────────────────────────────────────────────
var body_color: Color = Color.WHITE
var trim_color: Color = Color.GRAY
var _tween: Tween = null
var _sprite: Sprite2D = null

# ── Sprite size (fits inside the 36px diameter body circle) ──────────
const SPRITE_SIZE: float = 44.0

# ── Signals ──────────────────────────────────────────────────────────
signal moved(new_hex: Vector2i)
signal died(unit: BaseUnit)
signal inspect_requested(unit: BaseUnit)   ## emitted on right-click


# ════════════════════════════════════════════════════════════════════
# Initialisation
# ════════════════════════════════════════════════════════════════════

func setup(type: UnitData.Type) -> void:
	unit_type = type
	var info: Dictionary = UnitData.get_info(type)
	faction    = info["faction"]
	hp_max     = info["hp_max"]
	hp         = hp_max
	attack     = info["attack"]
	move_range = info["move_range"]
	moves_left = move_range
	unit_name  = info["name"]
	body_color = info["body_color"]
	trim_color = info["trim_color"]

	_setup_sprite(type)
	queue_redraw()


func _setup_sprite(type: UnitData.Type) -> void:
	if _sprite != null:
		_sprite.queue_free()
		_sprite = null

	var type_name: String = UnitData.get_unit_name(type).to_lower()
	var path: String = "res://assets/units/%s.png" % type_name

	_sprite = Sprite2D.new()
	_sprite.centered = true
	_sprite.position = Vector2.ZERO
	_sprite.z_index  = 0

	if ResourceLoader.exists(path):
		var tex: Texture2D = load(path)
		_sprite.texture = tex
		var tex_size: Vector2 = tex.get_size()
		var scale_factor: float = SPRITE_SIZE / maxf(tex_size.x, tex_size.y)
		_sprite.scale = Vector2(scale_factor, scale_factor)
	else:
		push_warning("BaseUnit: sprite not found at %s" % path)

	add_child(_sprite)
	_refresh_sprite_modulate()


func _refresh_sprite_modulate() -> void:
	if _sprite == null:
		return
	var dimmed: bool = (moves_left == 0 and has_attacked)
	_sprite.modulate = Color(1.0, 1.0, 1.0, 0.45 if dimmed else 1.0)


# ════════════════════════════════════════════════════════════════════
# Input — detect right-click within the unit's radius
# ════════════════════════════════════════════════════════════════════

func _input(event: InputEvent) -> void:
	if not is_alive:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_RIGHT:
			var local_pos: Vector2 = to_local(get_global_mouse_position())
			if local_pos.length() <= 20.0:
				inspect_requested.emit(self)
				get_viewport().set_input_as_handled()


# ════════════════════════════════════════════════════════════════════
# Turn management
# ════════════════════════════════════════════════════════════════════

func reset_turn() -> void:
	moves_left   = move_range
	has_attacked = false
	_refresh_sprite_modulate()
	queue_redraw()


func take_damage(amount: int) -> void:
	hp = maxi(0, hp - amount)
	queue_redraw()
	if hp == 0:
		is_alive = false
		died.emit(self)


# ════════════════════════════════════════════════════════════════════
# Drawing  (body circle + faction badge + HP bar + exhausted X)
# The sprite child node draws the unit artwork underneath.
# ════════════════════════════════════════════════════════════════════

func _draw() -> void:
	if not is_alive:
		return

	var dimmed: bool = (moves_left == 0 and has_attacked)
	var alpha: float = 0.45 if dimmed else 1.0

	# ── Body circle (background behind sprite) ───────────────────────
	draw_circle(Vector2.ZERO, 18.0, Color(body_color, alpha))
	draw_arc(Vector2.ZERO, 18.0, 0.0, TAU, 32, Color(trim_color, alpha), 2.5)

	# ── Faction badge (top-right pip) ────────────────────────────────
	var badge_col: Color = Color(0.20, 0.50, 1.0, alpha) \
		if faction == UnitData.Faction.PLAYER \
		else Color(0.85, 0.20, 0.20, alpha)
	draw_circle(Vector2(11, -11), 5.0, badge_col)
	draw_arc(Vector2(11, -11), 5.0, 0.0, TAU, 16, Color(1, 1, 1, alpha * 0.6), 1.0)

	# ── HP bar ───────────────────────────────────────────────────────
	_draw_hp_bar()

	# ── "Exhausted" X overlay ────────────────────────────────────────
	if dimmed:
		draw_line(Vector2(-10, -10), Vector2(10, 10), Color(1, 0.2, 0.2, 0.6), 2.0)
		draw_line(Vector2(10, -10), Vector2(-10, 10), Color(1, 0.2, 0.2, 0.6), 2.0)


func _draw_hp_bar() -> void:
	const BAR_W: float = 32.0
	const BAR_H: float = 4.0
	const BAR_Y: float = 22.0
	var ratio: float = float(hp) / float(hp_max)
	draw_rect(Rect2(-BAR_W * 0.5, BAR_Y, BAR_W, BAR_H), Color(0.15, 0.15, 0.15, 0.85))
	var bar_col := Color(1.0 - ratio, ratio, 0.0).lerp(Color(0.1, 0.9, 0.1), ratio * 0.5)
	draw_rect(Rect2(-BAR_W * 0.5, BAR_Y, BAR_W * ratio, BAR_H), bar_col)
	draw_rect(Rect2(-BAR_W * 0.5, BAR_Y, BAR_W, BAR_H), Color(0, 0, 0, 0.5), false, 0.8)


# ════════════════════════════════════════════════════════════════════
# Movement
# ════════════════════════════════════════════════════════════════════

func move_to(new_hex: Vector2i, hex_size: float, terrain_cost: int = 1) -> void:
	hex_pos = new_hex
	moves_left -= terrain_cost
	var target: Vector2 = HexGrid.axial_to_world(new_hex, hex_size)

	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.set_ease(Tween.EASE_OUT)
	_tween.set_trans(Tween.TRANS_CUBIC)
	_tween.tween_property(self, "position", target, 0.20)
	_tween.tween_callback(func() -> void:
		_refresh_sprite_modulate()
		queue_redraw())

	moved.emit(new_hex)


func place_at(hex: Vector2i, hex_size: float) -> void:
	hex_pos = hex
	position = HexGrid.axial_to_world(hex, hex_size)
	queue_redraw()
