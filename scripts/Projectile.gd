## Projectile.gd
## Animated projectile drawn entirely with _draw().
##
## Two visual modes driven by ProjectileData.Kind:
##   ARROW — thin straight shaft with arrowhead, flies in a flat line,
##            slight cosine dip/rise for readability.
##   ARC   — heavier bolt/ball that follows a high parabolic bezier,
##            rotates to always face its velocity direction.
##
## Lifecycle:
##   1. Instantiate, add to a Node2D layer above the map.
##   2. Call fire(from_world, to_world, kind, color).
##   3. Wait for signal landed(blocked_at_hex) — Vector2i(-1,-1) means hit.
##   4. The node auto-queues itself free after landing + a short pause.

class_name Projectile
extends Node2D

signal landed(blocked_hex: Vector2i)   ## Vector2i(-1,-1) = reached target

# ── Tuning ────────────────────────────────────────────────────────────
const ARROW_SPEED : float = 520.0   # px / sec
const ARC_DURATION: float = 0.72    # seconds for full arc flight
const ARC_HEIGHT  : float = 130.0   # peak rise above the straight line

# ── State ─────────────────────────────────────────────────────────────
var _kind:        ProjectileData.Kind = ProjectileData.Kind.ARROW
var _color:       Color               = Color(0.90, 0.82, 0.45)
var _from:        Vector2             = Vector2.ZERO
var _to:          Vector2             = Vector2.ZERO
var _travel:      float               = 0.0   # 0..1 normalised progress
var _total_dist:  float               = 1.0
var _duration:    float               = 1.0
var _elapsed:     float               = 0.0
var _blocked_hex: Vector2i            = Vector2i(-1, -1)
var _in_flight:   bool                = false
var _done:        bool                = false

# Current draw position (updated each _process frame)
var _cur_pos:   Vector2 = Vector2.ZERO
var _cur_angle: float   = 0.0   # radians, facing direction


# ════════════════════════════════════════════════════════════════════
# Public API
# ════════════════════════════════════════════════════════════════════

## Fire the projectile.
##   from_world / to_world — world-space pixel positions
##   kind                  — ARROW or ARC
##   color                 — tint (use attacker's trim_color)
##   blocked_hex           — for ARROW: the hex that blocks it early
##                           (Vector2i(-1,-1) = unblocked, reaches target)
func fire(from_world: Vector2, to_world: Vector2,
		  kind: ProjectileData.Kind, color: Color,
		  blocked_hex: Vector2i = Vector2i(-1, -1)) -> void:
	_from        = from_world
	_to          = to_world
	_kind        = kind
	_color       = color
	_blocked_hex = blocked_hex
	_in_flight   = true
	_elapsed     = 0.0
	_travel      = 0.0

	position     = from_world
	_cur_pos     = from_world
	_cur_angle   = (_to - _from).angle()

	_total_dist  = _from.distance_to(_to)
	_duration    = _total_dist / ARROW_SPEED if kind == ProjectileData.Kind.ARROW \
				 else ARC_DURATION

	set_process(true)


# ════════════════════════════════════════════════════════════════════
# Process
# ════════════════════════════════════════════════════════════════════

func _ready() -> void:
	set_process(false)
	z_index = 100   # always above map and units


func _process(delta: float) -> void:
	if _done or not _in_flight:
		return

	_elapsed  += delta
	_travel    = clampf(_elapsed / _duration, 0.0, 1.0)

	match _kind:
		ProjectileData.Kind.ARROW:
			_tick_arrow()
		ProjectileData.Kind.ARC:
			_tick_arc()

	queue_redraw()

	if _travel >= 1.0:
		_land()


func _tick_arrow() -> void:
	# Straight lerp with tiny perpendicular cosine wobble for visual interest
	var base: Vector2   = _from.lerp(_to, _travel)
	var perp: Vector2   = (_to - _from).normalized().rotated(PI * 0.5)
	var wobble: float   = sin(_travel * PI) * 4.0
	_cur_pos   = base + perp * wobble
	_cur_angle = (_to - _from).angle()


func _tick_arc() -> void:
	# Quadratic bezier: P0=_from, P1=midpoint raised by ARC_HEIGHT, P2=_to
	var mid: Vector2  = _from.lerp(_to, 0.5)
	# Lift perpendicular to the screen (upward in 2D = negative Y)
	var p1: Vector2   = mid + Vector2(0, -ARC_HEIGHT)

	var t: float       = _travel
	var prev_pos       = _cur_pos
	# B(t) = (1-t)^2 * P0 + 2(1-t)t * P1 + t^2 * P2
	_cur_pos = (1.0 - t) * (1.0 - t) * _from \
			 + 2.0 * (1.0 - t) * t * p1 \
			 + t * t * _to

	# Face direction of travel
	var vel: Vector2 = _cur_pos - prev_pos
	if vel.length_squared() > 0.001:
		_cur_angle = vel.angle()


# ════════════════════════════════════════════════════════════════════
# Landing
# ════════════════════════════════════════════════════════════════════

func _land() -> void:
	_in_flight = false
	_done      = true
	set_process(false)
	queue_redraw()
	landed.emit(_blocked_hex)
	# Auto-free after a short linger so the impact flash is visible
	get_tree().create_timer(0.30).timeout.connect(queue_free)


# ════════════════════════════════════════════════════════════════════
# Drawing
# ════════════════════════════════════════════════════════════════════

func _draw() -> void:
	if _done:
		return

	# Draw relative to Node2D's own origin — we keep position = Vector2.ZERO
	# and translate manually so the projectile sits at _cur_pos in world space.
	# Actually we set position = Vector2.ZERO and draw at _cur_pos offset
	# from the parent's origin. Simpler: draw at (_cur_pos - _from) so the
	# node origin stays at _from.
	var local: Vector2 = _cur_pos - _from

	match _kind:
		ProjectileData.Kind.ARROW:
			_draw_arrow(local)
		ProjectileData.Kind.ARC:
			_draw_arc_bolt(local)


func _draw_arrow(at: Vector2) -> void:
	# Shaft — 18 px long behind the tip
	var shaft_len: float = 18.0
	var dir: Vector2     = Vector2(cos(_cur_angle), sin(_cur_angle))
	var tail: Vector2    = at - dir * shaft_len

	# Shaft
	draw_line(tail, at, Color(_color, 0.92), 2.0, true)

	# Arrowhead triangle (3 pts)
	var tip:  Vector2 = at + dir * 7.0
	var left: Vector2 = at + Vector2(cos(_cur_angle + 2.5), sin(_cur_angle + 2.5)) * 5.0
	var right:Vector2 = at + Vector2(cos(_cur_angle - 2.5), sin(_cur_angle - 2.5)) * 5.0
	var pts := PackedVector2Array([tip, left, right])
	draw_colored_polygon(pts, _color)

	# Fletching (two short lines at tail)
	var perp: Vector2 = dir.rotated(PI * 0.5) * 4.0
	draw_line(tail, tail - dir * 5.0 + perp, Color(_color, 0.70), 1.2)
	draw_line(tail, tail - dir * 5.0 - perp, Color(_color, 0.70), 1.2)


func _draw_arc_bolt(at: Vector2) -> void:
	# Spinning dark ball with a glowing halo and a tail streak
	var radius: float  = 7.0
	var dir: Vector2   = Vector2(cos(_cur_angle), sin(_cur_angle))

	# Tail (fading streak behind)
	var tail_len: float = 22.0
	var tail_col        = Color(_color.r, _color.g, _color.b, 0.0)
	draw_line(at - dir * tail_len, at,
		Color(_color, 0.55), 5.0, true)

	# Outer glow
	draw_circle(at, radius + 3.0, Color(_color.r, _color.g, _color.b, 0.22))
	# Core
	draw_circle(at, radius, _color)
	# Inner highlight
	draw_circle(at + Vector2(-2, -2), radius * 0.4, Color(1, 1, 1, 0.45))
