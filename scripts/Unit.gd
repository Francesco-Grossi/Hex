## Unit.gd
## The player-controlled creature drawn as a simple polygon figure.
## Drawn entirely with Godot 2D draw calls — no sprites needed.
## Movement range = 4 hexes (configurable).
##
## Godot 4.4–4.6 changes applied:
##   - emit_signal("moved", new_hex) → moved.emit(new_hex)
##     emit_signal() still works but is deprecated; the signal-object
##     syntax is the idiomatic Godot 4.x style and avoids string lookup.

class_name Unit
extends Node2D

const MOVE_RANGE: int = 4

## Current position in axial hex coordinates
var hex_pos: Vector2i = Vector2i(2, 2)

## Tween reference for smooth movement animation
var _tween: Tween = null

signal moved(new_hex: Vector2i)


func _draw() -> void:
	# --- Body circle ---
	draw_circle(Vector2.ZERO, 20.0, Color(0.78, 0.42, 0.08))
	draw_arc(Vector2.ZERO, 20.0, 0, TAU, 32, Color(1, 1, 1, 0.4), 2.0)

	# --- Inner shield circle ---
	draw_circle(Vector2.ZERO, 12.0, Color(0.55, 0.15, 0.08))

	# --- Sword (simple lines) ---
	# Blade
	draw_line(Vector2(6, -6), Vector2(18, -18), Color(0.85, 0.85, 0.85), 3.0, true)
	# Cross-guard
	draw_line(Vector2(8, -14), Vector2(16, -10), Color(0.85, 0.85, 0.85), 2.0, true)

	# --- Shield (small polygon offset to the left) ---
	var shield_pts := PackedVector2Array([
		Vector2(-14, -8), Vector2(-8, -8),
		Vector2(-8, 2),   Vector2(-11, 6),
		Vector2(-14, 2),
	])
	draw_colored_polygon(shield_pts, Color(0.2, 0.3, 0.7))
	draw_polyline(shield_pts, Color(1, 1, 1, 0.5), 1.0)

	# --- Helmet (arc above) ---
	draw_arc(Vector2(0, -12), 10.0, PI, TAU, 16, Color(0.78, 0.42, 0.08), 14.0)
	draw_arc(Vector2(0, -12), 10.0, PI, TAU, 16, Color(1, 1, 1, 0.35), 2.0)


## Move unit to a new hex position with smooth tweened animation
func move_to(new_hex: Vector2i, hex_size: float) -> void:
	hex_pos = new_hex
	var target_world: Vector2 = HexGrid.axial_to_world(new_hex, hex_size)

	if _tween:
		_tween.kill()

	_tween = create_tween()
	_tween.set_ease(Tween.EASE_OUT)
	_tween.set_trans(Tween.TRANS_CUBIC)
	_tween.tween_property(self, "position", target_world, 0.22)

	# 4.4+: use signal-object emit() instead of deprecated emit_signal()
	moved.emit(new_hex)


## Instantly place unit (no animation) — used for initial placement
func place_at(hex: Vector2i, hex_size: float) -> void:
	hex_pos = hex
	position = HexGrid.axial_to_world(hex, hex_size)
