## BaseUnit.gd
## Universal unit node used for both players and enemies.
## All visuals are drawn with _draw() — no sprites needed.
## Stats are driven by UnitData based on the assigned `unit_type`.
##
## HP bar, faction badge, and icon are all drawn on top of the body circle.
## Call `setup(type)` right after add_child() to initialise.

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
var moves_left: int   = 0     # remaining movement budget this turn
var has_attacked: bool = false
var is_alive: bool = true

# ── Visuals ──────────────────────────────────────────────────────────
var body_color: Color = Color.WHITE
var trim_color: Color = Color.GRAY
var _tween: Tween = null

# ── Signals ──────────────────────────────────────────────────────────
signal moved(new_hex: Vector2i)
signal died(unit: BaseUnit)


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
	queue_redraw()


func reset_turn() -> void:
	moves_left   = move_range
	has_attacked = false
	queue_redraw()


func take_damage(amount: int) -> void:
	hp = maxi(0, hp - amount)
	queue_redraw()
	if hp == 0:
		is_alive = false
		died.emit(self)


# ════════════════════════════════════════════════════════════════════
# Drawing
# ════════════════════════════════════════════════════════════════════

func _draw() -> void:
	if not is_alive:
		return

	var dimmed: bool = (moves_left == 0 and has_attacked)
	var alpha: float = 0.45 if dimmed else 1.0

	# ── Body circle ──────────────────────────────────────────────────
	var bc := Color(body_color, alpha)
	draw_circle(Vector2.ZERO, 18.0, bc)
	draw_arc(Vector2.ZERO, 18.0, 0.0, TAU, 32, Color(trim_color, alpha), 2.5)

	# ── Faction badge (top-right corner pip) ────────────────────────
	var badge_col: Color = Color(0.20, 0.50, 1.0, alpha) if faction == UnitData.Faction.PLAYER \
						 else Color(0.85, 0.20, 0.20, alpha)
	draw_circle(Vector2(11, -11), 5.0, badge_col)
	draw_arc(Vector2(11, -11), 5.0, 0.0, TAU, 16, Color(1, 1, 1, alpha * 0.6), 1.0)

	# ── Unit-type icon (simple geometric shapes) ─────────────────────
	_draw_icon(alpha)

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
	# Background
	draw_rect(Rect2(-BAR_W * 0.5, BAR_Y, BAR_W, BAR_H), Color(0.15, 0.15, 0.15, 0.85))
	# Fill — colour shifts red→yellow→green
	var bar_col := Color(1.0 - ratio, ratio, 0.0).lerp(Color(0.1, 0.9, 0.1), ratio * 0.5)
	draw_rect(Rect2(-BAR_W * 0.5, BAR_Y, BAR_W * ratio, BAR_H), bar_col)
	# Border
	draw_rect(Rect2(-BAR_W * 0.5, BAR_Y, BAR_W, BAR_H), Color(0, 0, 0, 0.5), false, 0.8)


func _draw_icon(alpha: float) -> void:
	match unit_type:
		UnitData.Type.KNIGHT:
			# Sword
			draw_line(Vector2(-6, 6), Vector2(6, -6), Color(0.9, 0.9, 0.9, alpha), 3.0, true)
			draw_line(Vector2(-2, -1), Vector2(2, 3), Color(0.9, 0.9, 0.9, alpha), 1.5, true)
		UnitData.Type.ARCHER:
			# Bow arc + arrow
			draw_arc(Vector2(-2, 0), 8.0, -PI * 0.5, PI * 0.5, 12, Color(0.8, 0.6, 0.3, alpha), 2.0)
			draw_line(Vector2(-2, -8), Vector2(-2, 8), Color(0.8, 0.6, 0.3, alpha), 1.0)
			draw_line(Vector2(-2, 0), Vector2(9, 0), Color(0.9, 0.9, 0.9, alpha), 1.5, true)
		UnitData.Type.MAGE:
			# Star-ish shape: 4 lines radiating
			for angle in [0.0, PI * 0.5, PI, PI * 1.5]:
				var d := Vector2(cos(angle), sin(angle)) * 9.0
				draw_line(Vector2.ZERO, d, Color(trim_color, alpha), 1.5, true)
			draw_circle(Vector2.ZERO, 4.0, Color(trim_color, alpha * 0.8))
		UnitData.Type.ORC:
			# Axe silhouette
			draw_line(Vector2(0, 7), Vector2(0, -5), Color(0.7, 0.7, 0.7, alpha), 2.5, true)
			var blade := PackedVector2Array([Vector2(-5,-5), Vector2(5,-5), Vector2(3,-1), Vector2(-3,-1)])
			draw_colored_polygon(blade, Color(0.75, 0.75, 0.75, alpha))
		UnitData.Type.GOBLIN:
			# Dagger (short diagonal line + crossguard)
			draw_line(Vector2(-5, 5), Vector2(5, -5), Color(0.8, 0.8, 0.8, alpha), 2.0, true)
			draw_line(Vector2(-2, -2), Vector2(2, 2), Color(0.8, 0.6, 0.2, alpha), 1.5)
		UnitData.Type.TROLL:
			# Club (thick line + oval top)
			draw_line(Vector2(0, 8), Vector2(0, -2), Color(0.5, 0.35, 0.20, alpha), 5.0, true)
			draw_circle(Vector2(0, -6), 6.0, Color(0.45, 0.30, 0.18, alpha))


# ════════════════════════════════════════════════════════════════════
# Movement
# ════════════════════════════════════════════════════════════════════

## Animate movement to new hex, deduct terrain cost from moves_left
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
	_tween.tween_callback(queue_redraw)

	moved.emit(new_hex)


## Instant placement (no animation)
func place_at(hex: Vector2i, hex_size: float) -> void:
	hex_pos = hex
	position = HexGrid.axial_to_world(hex, hex_size)
	queue_redraw()
