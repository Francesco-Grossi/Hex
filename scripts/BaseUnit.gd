## BaseUnit.gd
## Universal unit node for players and enemies.
##
## EQUIPMENT MODEL
## ───────────────
##   primary_weapon   — first weapon slot (determines attack / range / projectile)
##   secondary_weapon — second weapon slot (alternative attack option)
##   active_weapon    — which slot is currently selected (PRIMARY or SECONDARY)
##   armor            — body armour (passive damage reduction)
##   helmet           — head armour (passive damage reduction)
##   steed            — mount (overrides move_range and terrain costs when set)
##
## DAMAGE
##   incoming damage = max(1, raw_damage − total_protection)
##   total_protection = armor.damage_reduction + helmet.damage_reduction
##
## MOVEMENT
##   If a steed is equipped:
##     move_range  = steed.move_range
##     base_costs  = steed.base_costs   (overlay costs still use unit's own table)
##   Otherwise use UnitData defaults.

class_name BaseUnit
extends Node2D

# ── Identity ──────────────────────────────────────────────────────
var unit_type: UnitData.Type = UnitData.Type.KNIGHT
var faction:   UnitData.Faction = UnitData.Faction.PLAYER
var unit_name: String = "Unit"

# ── Base stats (from UnitData) ────────────────────────────────────
var hp_max: int = 10
var hp: int     = 10

# ── Equipment ─────────────────────────────────────────────────────
enum WeaponSlot { PRIMARY, SECONDARY }

var primary_weapon:   EquipmentData.WeaponType = EquipmentData.WeaponType.NONE
var secondary_weapon: EquipmentData.WeaponType = EquipmentData.WeaponType.NONE
var active_weapon:    WeaponSlot = WeaponSlot.PRIMARY

var armor:   EquipmentData.ArmorType  = EquipmentData.ArmorType.NONE
var helmet:  EquipmentData.HelmetType = EquipmentData.HelmetType.NONE
var steed:   EquipmentData.SteedType  = EquipmentData.SteedType.NONE

# ── Derived combat stats (recomputed by _refresh_stats) ───────────
var attack:      int = 1   # damage of active weapon
var attack_range: int = 1  # range of active weapon
var move_range:   int = 4  # on-foot or steed value
var protection:   int = 0  # total damage reduction

# ── Runtime state ─────────────────────────────────────────────────
var hex_pos:     Vector2i = Vector2i.ZERO
var moves_left:  int      = 0
var has_attacked: bool    = false
var is_alive:    bool     = true

# ── Visuals ───────────────────────────────────────────────────────
var body_color: Color = Color.WHITE
var trim_color: Color = Color.GRAY
var _tween: Tween = null
var _sprite: Sprite2D = null
const SPRITE_SIZE: float = 36.0

# ── Signals ───────────────────────────────────────────────────────
signal moved(new_hex: Vector2i)
signal died(unit: BaseUnit)
signal inspect_requested(unit: BaseUnit)


# ════════════════════════════════════════════════════════════════════
# Initialisation
# ════════════════════════════════════════════════════════════════════

func setup(type: UnitData.Type) -> void:
	unit_type  = type
	var info: Dictionary = UnitData.get_info(type)
	faction    = info["faction"]
	hp_max     = info["hp_max"]
	hp         = hp_max
	unit_name  = info["name"]
	body_color = info["body_color"]
	trim_color = info["trim_color"]

	# Apply default equipment from UnitData
	primary_weapon   = info["default_primary"]
	secondary_weapon = info["default_secondary"]
	armor            = info["default_armor"]
	helmet           = info["default_helmet"]
	steed            = info["default_steed"]
	active_weapon    = WeaponSlot.PRIMARY

	_refresh_stats()
	_setup_sprite(type)
	queue_redraw()


## Recompute all derived stats from current equipment.
func _refresh_stats() -> void:
	# 1. Active weapon drives attack and range
	var wpn := _active_weapon_info()
	# Use .get() to provide safe defaults (0 damage, 1 range) if data is missing
	attack       = wpn.get("damage", 0)
	attack_range = wpn.get("attack_range", 1)

	# 2. Steed drives movement
	if steed != EquipmentData.SteedType.NONE:
		# Use steed_info() instead of direct STEEDS[] access to ensure data is loaded
		var s_info = EquipmentData.steed_info(steed)
		move_range = s_info.get("move_range", 3)
	else:
		# Use get_info() instead of direct UNITS[] access to ensure data is loaded
		var u_info = UnitData.get_info(unit_type)
		move_range = u_info.get("move_range", 3)

	# 3. Armor stacks
	protection = EquipmentData.total_reduction(armor, helmet)


func _active_weapon_info() -> Dictionary:
	# Corrected variable name from 'weapon_id' to 'wpn_type'
	var wpn_type := primary_weapon if active_weapon == WeaponSlot.PRIMARY \
				  else secondary_weapon
	
	# Calls the safe accessor which handles the lazy loading and missing keys
	return EquipmentData.weapon_info(wpn_type)


## Switch which weapon slot is active. Refreshes stats.
func switch_weapon() -> void:
	active_weapon = WeaponSlot.SECONDARY if active_weapon == WeaponSlot.PRIMARY \
				  else WeaponSlot.PRIMARY
	_refresh_stats()
	queue_redraw()


## Equip a new item and refresh stats. Call before or between turns.
func equip_primary(w: EquipmentData.WeaponType) -> void:
	primary_weapon = w
	if active_weapon == WeaponSlot.PRIMARY:
		_refresh_stats()

func equip_secondary(w: EquipmentData.WeaponType) -> void:
	secondary_weapon = w
	if active_weapon == WeaponSlot.SECONDARY:
		_refresh_stats()

func equip_armor(a: EquipmentData.ArmorType) -> void:
	armor = a
	_refresh_stats()

func equip_helmet(h: EquipmentData.HelmetType) -> void:
	helmet = h
	_refresh_stats()

func equip_steed(s: EquipmentData.SteedType) -> void:
	steed = s
	_refresh_stats()


# ════════════════════════════════════════════════════════════════════
# Terrain cost — honours steed if mounted
# ════════════════════════════════════════════════════════════════════

## Cost for THIS unit to enter `cell`, accounting for its current steed.
func terrain_cost(cell: TerrainData.HexCell) -> int:
	if steed != EquipmentData.SteedType.NONE:
		var steed_costs: Dictionary = EquipmentData.STEEDS[steed]["base_costs"]
		var bc: int = steed_costs.get(int(cell.base), 99)
		# Steed base cost; still blocked by walls/buildings (overlay cost from unit)
		var oc: int = UnitData.UNITS[unit_type]["overlay_costs"].get(int(cell.overlay), 99)
		if bc >= 99 or oc >= 99:
			return 99
		return bc + oc
	else:
		return UnitData.move_cost(unit_type, cell)


# ════════════════════════════════════════════════════════════════════
# Sprite
# ════════════════════════════════════════════════════════════════════

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
# Input
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


## Apply incoming damage after subtracting protection. Minimum 1.
func take_damage(amount: int) -> void:
	var actual: int = maxi(1, amount - protection)
	hp = maxi(0, hp - actual)
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

	# Body circle
	draw_circle(Vector2.ZERO, 18.0, Color(body_color, alpha))
	draw_arc(Vector2.ZERO, 18.0, 0.0, TAU, 32, Color(trim_color, alpha), 2.5)

	# Steed indicator — small horseshoe arc at bottom when mounted
	if steed != EquipmentData.SteedType.NONE:
		var steed_col := Color(0.85, 0.65, 0.10, alpha)
		draw_arc(Vector2(0, 6), 14.0, deg_to_rad(30), deg_to_rad(150), 12, steed_col, 3.0)

	# Faction badge
	var badge_col: Color = Color(0.20, 0.50, 1.0, alpha) \
		if faction == UnitData.Faction.PLAYER \
		else Color(0.85, 0.20, 0.20, alpha)
	draw_circle(Vector2(11, -11), 5.0, badge_col)
	draw_arc(Vector2(11, -11), 5.0, 0.0, TAU, 16, Color(1, 1, 1, alpha * 0.6), 1.0)

	# Armor pip — small shield icon bottom-left when armored
	if protection > 0:
		var prot_col := Color(0.60, 0.70, 0.85, alpha)
		var shield := PackedVector2Array([
			Vector2(-16, 2), Vector2(-11, 2),
			Vector2(-11, 8), Vector2(-13.5, 11),
			Vector2(-16, 8),
		])
		draw_colored_polygon(shield, prot_col)

	# HP bar
	_draw_hp_bar(alpha)

	# Exhausted overlay
	if dimmed:
		draw_line(Vector2(-10, -10), Vector2(10, 10), Color(1, 0.2, 0.2, 0.6), 2.0)
		draw_line(Vector2(10, -10), Vector2(-10, 10), Color(1, 0.2, 0.2, 0.6), 2.0)


func _draw_hp_bar(alpha: float = 1.0) -> void:
	const BAR_W: float = 32.0
	const BAR_H: float = 4.0
	const BAR_Y: float = 22.0
	var ratio: float = float(hp) / float(hp_max)
	draw_rect(Rect2(-BAR_W * 0.5, BAR_Y, BAR_W, BAR_H), Color(0.15, 0.15, 0.15, 0.85 * alpha))
	var bar_col := Color(1.0 - ratio, ratio, 0.0).lerp(Color(0.1, 0.9, 0.1), ratio * 0.5)
	bar_col.a = alpha
	draw_rect(Rect2(-BAR_W * 0.5, BAR_Y, BAR_W * ratio, BAR_H), bar_col)
	draw_rect(Rect2(-BAR_W * 0.5, BAR_Y, BAR_W, BAR_H), Color(0, 0, 0, 0.5 * alpha), false, 0.8)


# ════════════════════════════════════════════════════════════════════
# Movement
# ════════════════════════════════════════════════════════════════════

func move_to(new_hex: Vector2i, hex_size: float, terrain_cost_val: int = 1) -> void:
	hex_pos = new_hex
	moves_left -= terrain_cost_val
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
