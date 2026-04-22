## BattleManager.gd
## Into-the-Breach style AI: intents frozen at player-phase start.
## Path stored per-intent so the overlay draws the real route, not a straight line.
## Execution walks the stored path to find the last unoccupied tile.

class_name BattleManager
extends Node2D

const HEX_SIZE: float = 72.0

# ── External references ───────────────────────────────────────────────
var tiles:        Dictionary = {}
var terrain_map:  Dictionary = {}
var unit_layer:   Node2D     = null
var status_label: Label      = null

# ── Unit tracking ────────────────────────────────────────────────────
var player_units: Array[BaseUnit] = []
var enemy_units:  Array[BaseUnit] = []
var all_units:    Array[BaseUnit] = []

# ── Turn state ───────────────────────────────────────────────────────
enum Phase { PLAYER, ENEMY, VICTORY, DEFEAT }
var phase: Phase = Phase.PLAYER

var selected_unit:    BaseUnit        = null
var reachable_hexes:  Dictionary      = {}
var attackable_hexes: Array[Vector2i] = []

# ── AI intent ────────────────────────────────────────────────────────
## Each intent: {
##   "unit":       BaseUnit,
##   "origin":     Vector2i,   ← where the unit was when planned
##   "path":       Array[Vector2i],  ← full A* waypoints (excludes origin)
##   "move_to":    Vector2i,   ← last reachable step on path
##   "attack":     Vector2i or null
## }
var _ai_intents: Array   = []
var _intent_overlay: Node2D = null

signal battle_ended(victory: bool)
signal status_changed(text: String)
signal phase_changed(new_phase: Phase)


# ════════════════════════════════════════════════════════════════════
# Setup
# ════════════════════════════════════════════════════════════════════

func setup(p_tiles: Dictionary, p_terrain: Dictionary,
		p_unit_layer: Node2D, p_status: Label) -> void:
	tiles        = p_tiles
	terrain_map  = p_terrain
	unit_layer   = p_unit_layer
	status_label = p_status

	_intent_overlay          = Node2D.new()
	_intent_overlay.name     = "AIIntentOverlay"
	_intent_overlay.z_index  = 200
	unit_layer.add_child(_intent_overlay)
	_intent_overlay.set_script(_make_intent_draw_script())


func start_battle(player_placements: Array = [],
				  enemy_placements:  Array = []) -> void:
	if player_placements.is_empty():
		_spawn_player_units()
	else:
		for entry in player_placements:
			var u := _make_unit(entry[0], entry[1])
			player_units.append(u)
			all_units.append(u)

	if enemy_placements.is_empty():
		_spawn_enemy_units()
	else:
		for entry in enemy_placements:
			var u := _make_unit(entry[0], entry[1])
			enemy_units.append(u)
			all_units.append(u)

	_begin_player_phase()


# ════════════════════════════════════════════════════════════════════
# Spawning
# ════════════════════════════════════════════════════════════════════

func _spawn_player_units() -> void:
	var placements: Array = [
		[UnitData.Type.KNIGHT, Vector2i(1, 4)],
		[UnitData.Type.ARCHER, Vector2i(1, 6)],
		[UnitData.Type.MAGE,   Vector2i(2, 5)],
	]
	for e in placements:
		var u := _make_unit(e[0], e[1])
		player_units.append(u)
		all_units.append(u)


func _spawn_enemy_units() -> void:
	var cols: int = tiles.keys().map(func(v: Vector2i) -> int: return v.x).max()
	var placements: Array = [
		[UnitData.Type.ORC,    Vector2i(cols - 1, 3)],
		[UnitData.Type.GOBLIN, Vector2i(cols - 2, 5)],
		[UnitData.Type.TROLL,  Vector2i(cols - 1, 7)],
	]
	for e in placements:
		var u := _make_unit(e[0], e[1])
		enemy_units.append(u)
		all_units.append(u)


func _make_unit(type: UnitData.Type, hex: Vector2i) -> BaseUnit:
	var u := BaseUnit.new()
	u.setup(type)
	u.place_at(hex, HEX_SIZE)
	_apply_unit_z(u, hex)
	u.died.connect(_on_unit_died)
	unit_layer.add_child(u)
	return u


func _apply_unit_z(u: BaseUnit, hex: Vector2i) -> void:
	if tiles.has(hex):
		u.z_index = tiles[hex].unit_z() + 5
	else:
		u.z_index = hex.y * 10 + 5


# ════════════════════════════════════════════════════════════════════
# AI Intent — computed once, frozen all player turn
# ════════════════════════════════════════════════════════════════════

func _compute_ai_intents() -> void:
	_ai_intents.clear()
	_clear_intent_highlights()

	var claimed: Dictionary = {}  # Vector2i → true  (reserved destinations)

	for enemy in enemy_units:
		if not enemy.is_alive:
			continue
		# Pre-claim every enemy's current tile so others route around them
		claimed[enemy.hex_pos] = true

	# Now plan each enemy, un-claiming self before planning, re-claiming dest after
	for enemy in enemy_units:
		if not enemy.is_alive:
			continue
		# Temporarily remove own tile from claimed so we can leave it
		claimed.erase(enemy.hex_pos)
		var intent := _plan_enemy_action(enemy, claimed)
		_ai_intents.append(intent)
		# Claim destination (may be same as origin if blocked)
		claimed[intent["move_to"]] = true

	_apply_intent_highlights()
	_push_overlay()


func _plan_enemy_action(enemy: BaseUnit, claimed: Dictionary) -> Dictionary:
	var target: BaseUnit = _closest_player(enemy)
	if target == null:
		return { "unit": enemy, "origin": enemy.hex_pos,
				 "path": [], "move_to": enemy.hex_pos, "attack": null }

	var atk_range: int = enemy.attack_range
	var kind: int      = EquipmentData.WEAPONS[
		enemy.primary_weapon if enemy.active_weapon == BaseUnit.WeaponSlot.PRIMARY
		else enemy.secondary_weapon]["projectile_kind"]
	var dist: int      = HexGrid.distance(enemy.hex_pos, target.hex_pos)

	# Already in attack range → stay and attack
	# For ARROW: also check LOS; for ARC and melee: distance is enough
	var in_range: bool = dist <= atk_range
	if in_range and kind == ProjectileData.Kind.ARROW:
		in_range = (_arrow_reaches(enemy.hex_pos, target.hex_pos) == target.hex_pos)

	if in_range:
		return { "unit": enemy, "origin": enemy.hex_pos,
				 "path": [], "move_to": enemy.hex_pos, "attack": target.hex_pos }

	# Cost function for A*: impassable terrain, occupied tiles, claimed destinations
	# The target hex itself is allowed through (we stop one step before)
	var cost_fn: Callable = func(hex: Vector2i) -> int:
		if not terrain_map.has(hex):
			return 99
		var base_cost: int = enemy.terrain_cost(terrain_map[hex])
		if base_cost >= 99:
			return 99
		if hex == target.hex_pos:
			return base_cost   # passable for routing, we won't land here
		if _unit_at(hex) != null:
			return 99          # blocked by any living unit (friend or foe)
		if claimed.has(hex):
			return 99          # another enemy already claimed this spot
		return base_cost

	var full_path: Array[Vector2i] = HexGrid.astar_path(
		enemy.hex_pos, target.hex_pos, cost_fn)

	if full_path.is_empty():
		return { "unit": enemy, "origin": enemy.hex_pos,
				 "path": [], "move_to": enemy.hex_pos, "attack": null }

	# Walk the path up to move_range budget, stopping before target or claimed tiles
	var spent: int      = 0
	var dest: Vector2i  = enemy.hex_pos
	var path_to_dest: Array[Vector2i] = []

	for step_hex in full_path:
		if step_hex == target.hex_pos:
			break
		var t_cost: int = enemy.terrain_cost(terrain_map.get(step_hex, TerrainData.HexCell.new()))
		if t_cost >= 99:
			break
		if spent + t_cost > enemy.move_range:
			break
		if claimed.has(step_hex):
			break
		spent += t_cost
		dest   = step_hex
		path_to_dest.append(step_hex)

	# Will attack if within range after moving
	var will_attack = null
	var new_dist: int = HexGrid.distance(dest, target.hex_pos)
	var new_in_range: bool = new_dist <= atk_range
	if new_in_range and kind == ProjectileData.Kind.ARROW:
		new_in_range = (_arrow_reaches(dest, target.hex_pos) == target.hex_pos)
	if new_in_range:
		will_attack = target.hex_pos

	return {
		"unit":    enemy,
		"origin":  enemy.hex_pos,
		"path":    path_to_dest,
		"move_to": dest,
		"attack":  will_attack
	}


func _apply_intent_highlights() -> void:
	for intent in _ai_intents:
		var unit: BaseUnit = intent["unit"]
		var dest: Vector2i = intent["move_to"]
		if dest != unit.hex_pos and tiles.has(dest):
			tiles[dest].set_enemy_intent(true)
		var atk = intent["attack"]
		if atk != null and tiles.has(atk):
			tiles[atk].set_attack_target(true)


func _clear_intent_highlights() -> void:
	for intent in _ai_intents:
		var dest: Vector2i = intent["move_to"]
		if tiles.has(dest):
			tiles[dest].set_enemy_intent(false)
		var atk = intent["attack"]
		if atk != null and tiles.has(atk):
			tiles[atk].set_attack_target(false)


func _push_overlay() -> void:
	if not is_instance_valid(_intent_overlay):
		return
	_intent_overlay.set_meta("intents",  _ai_intents)
	_intent_overlay.set_meta("hex_size", HEX_SIZE)
	_intent_overlay.queue_redraw()


# ════════════════════════════════════════════════════════════════════
# Overlay draw script — traces the real path, not a straight line
# ════════════════════════════════════════════════════════════════════

func _make_intent_draw_script() -> GDScript:
	var src := """
extends Node2D

func _draw() -> void:
	if not has_meta("intents"):
		return
	var intents  = get_meta("intents")
	var hex_size: float = get_meta("hex_size") if has_meta("hex_size") else 72.0

	for intent in intents:
		var unit = intent["unit"]
		if not is_instance_valid(unit) or not unit.is_alive:
			continue

		var origin_hex: Vector2i       = intent["origin"]
		var path: Array                = intent["path"]
		var dest_hex: Vector2i         = intent["move_to"]
		var atk_hex                    = intent["attack"]

		var origin_w: Vector2 = HexGrid.axial_to_world(origin_hex, hex_size)

		# ── Movement path: trace every waypoint ─────────────────────
		if path.size() > 0:
			var prev_w: Vector2 = origin_w
			for i in range(path.size()):
				var step_hex: Vector2i = path[i]
				var step_w: Vector2    = HexGrid.axial_to_world(step_hex, hex_size)
				var is_last: bool      = (i == path.size() - 1)
				_draw_segment(prev_w, step_w,
					Color(1.0, 0.18, 0.18, 0.95), 3.5, false, is_last)
				prev_w = step_w

		# ── Attack arrow from destination to target ──────────────────
		if atk_hex != null:
			var dest_w: Vector2 = HexGrid.axial_to_world(dest_hex, hex_size)
			var atk_w:  Vector2 = HexGrid.axial_to_world(atk_hex,  hex_size)
			_draw_segment(dest_w, atk_w,
				Color(1.0, 0.0, 0.0, 1.0), 2.5, true, true)


## Draw one segment of the path, optionally solid and with arrowhead.
func _draw_segment(from: Vector2, to: Vector2, col: Color,
		width: float, solid: bool, arrowhead: bool) -> void:
	var delta: Vector2 = to - from
	var length: float  = delta.length()
	if length < 2.0:
		return
	var dir:  Vector2 = delta / length
	var perp: Vector2 = Vector2(-dir.y, dir.x)

	var pad_start: float = 22.0   # clear the origin unit circle
	var pad_end:   float = 22.0   # clear the destination circle
	var f: Vector2 = from + dir * pad_start
	var t: Vector2 = to   - dir * pad_end

	if (t - f).length() < 2.0:
		return

	if solid:
		draw_line(f, t, col, width, true)
	else:
		var dash: float = 11.0
		var gap:  float =  6.0
		var total: float = (t - f).length()
		var cursor: Vector2 = f
		var on: bool = true
		var travelled: float = 0.0
		while travelled < total:
			var step: float = minf(dash if on else gap, total - travelled)
			if on:
				draw_line(cursor, cursor + dir * step, col, width, true)
			cursor     += dir * step
			travelled  += step
			on          = not on

	if arrowhead:
		var tip: Vector2    = t
		var sz:  float      = 11.0
		draw_line(tip, tip - dir * sz + perp * sz * 0.5, col, width, true)
		draw_line(tip, tip - dir * sz - perp * sz * 0.5, col, width, true)
"""
	var s := GDScript.new()
	s.source_code = src
	s.reload()
	return s


# ════════════════════════════════════════════════════════════════════
# Phase management
# ════════════════════════════════════════════════════════════════════

func _begin_player_phase() -> void:
	phase = Phase.PLAYER
	for u in player_units:
		if u.is_alive:
			u.reset_turn()
	_deselect()
	_compute_ai_intents()
	_set_status("Your turn — select a unit  (red arrows = enemy plans)")
	phase_changed.emit(phase)


func end_player_turn() -> void:
	if phase != Phase.PLAYER:
		return
	_deselect()
	_clear_highlights()
	_clear_intent_highlights()
	if is_instance_valid(_intent_overlay):
		_intent_overlay.set_meta("intents", [])
		_intent_overlay.queue_redraw()
	phase = Phase.ENEMY
	phase_changed.emit(phase)
	_set_status("Enemy turn…")
	get_tree().create_timer(0.4).timeout.connect(_run_enemy_phase)


func _run_enemy_phase() -> void:
	var living: Array[BaseUnit] = enemy_units.filter(
		func(u: BaseUnit) -> bool: return u.is_alive)
	_process_enemy(living, 0)


func _process_enemy(living: Array[BaseUnit], idx: int) -> void:
	if idx >= living.size():
		if _check_game_over():
			return
		get_tree().create_timer(0.3).timeout.connect(_begin_player_phase)
		return
	var enemy: BaseUnit = living[idx]
	if not enemy.is_alive:
		_process_enemy(living, idx + 1)
		return
	enemy.reset_turn()
	var intent: Dictionary = {}
	for i in _ai_intents:
		if i["unit"] == enemy:
			intent = i
			break
	_execute_intent(enemy, intent)
	get_tree().create_timer(0.55).timeout.connect(
		func() -> void: _process_enemy(living, idx + 1))


# ════════════════════════════════════════════════════════════════════
# Player input
# ════════════════════════════════════════════════════════════════════

func handle_hex_click(hex: Vector2i) -> void:
	if phase != Phase.PLAYER:
		return
	var clicked_unit: BaseUnit = _unit_at(hex)

	if clicked_unit != null and clicked_unit.faction == UnitData.Faction.PLAYER \
			and clicked_unit.is_alive:
		_select_unit(clicked_unit)
		return

	if selected_unit != null and hex in attackable_hexes:
		if clicked_unit != null and clicked_unit.faction == UnitData.Faction.ENEMY:
			_do_attack(selected_unit, clicked_unit)
			return
		# Ranged unit clicking an attackable hex with no enemy — fire anyway (miss)
		if selected_unit.attack_range > 1 and not selected_unit.has_attacked:
			_do_ranged_attack_at(selected_unit, hex)
			return

	if selected_unit != null and reachable_hexes.has(hex) \
			and _unit_at(hex) == null:
		_do_move(selected_unit, hex)
		return

	_deselect()


func _select_unit(u: BaseUnit) -> void:
	_deselect()
	selected_unit = u
	_highlight_for(u)
	_set_status("%s selected — HP %d/%d  Moves %d  ATK %d" % [
		u.unit_name, u.hp, u.hp_max, u.moves_left, u.attack])
	if tiles.has(u.hex_pos):
		tiles[u.hex_pos].set_selected(true)


func _deselect() -> void:
	if selected_unit != null and tiles.has(selected_unit.hex_pos):
		tiles[selected_unit.hex_pos].set_selected(false)
	selected_unit = null
	_clear_highlights()


# ════════════════════════════════════════════════════════════════════
# Movement
# ════════════════════════════════════════════════════════════════════

func _do_move(u: BaseUnit, target_hex: Vector2i) -> void:
	var cost: int = reachable_hexes.get(target_hex, 0)
	if tiles.has(u.hex_pos):
		tiles[u.hex_pos].set_selected(false)
	u.move_to(target_hex, HEX_SIZE, cost)
	_apply_unit_z(u, target_hex)
	_clear_highlights()
	get_tree().create_timer(0.25).timeout.connect(
		func() -> void: _select_unit(u))


func _cost_fn(unit: BaseUnit) -> Callable:
	return func(hex: Vector2i) -> int:
		if not terrain_map.has(hex):
			return 99
		if _unit_at(hex) != null:
			return 99
		return unit.terrain_cost(terrain_map[hex])


func _highlight_for(u: BaseUnit) -> void:
	_clear_highlights()
	attackable_hexes.clear()

	if u.moves_left > 0:
		reachable_hexes = HexGrid.reachable_weighted(
			u.hex_pos, u.moves_left, _cost_fn(u))
		reachable_hexes.erase(u.hex_pos)
		for hex in reachable_hexes:
			if tiles.has(hex):
				tiles[hex].set_reachable(true)

	if not u.has_attacked:
		var atk_range: int = u.attack_range
		var kind: int      = EquipmentData.WEAPONS[
			u.primary_weapon if u.active_weapon == BaseUnit.WeaponSlot.PRIMARY
			else u.secondary_weapon]["projectile_kind"]

		if atk_range <= 1:
			# Melee — only adjacent enemies
			for nb in HexGrid.neighbors(u.hex_pos):
				var t: BaseUnit = _unit_at(nb)
				if t != null and t.faction == UnitData.Faction.ENEMY and t.is_alive:
					attackable_hexes.append(nb)
					if tiles.has(nb):
						tiles[nb].set_attack_target(true)
		else:
			# Ranged — all enemy hexes within attack_range with valid LOS/arc
			for r in range(1, atk_range + 1):
				for hex in HexGrid.ring(u.hex_pos, r):
					var t: BaseUnit = _unit_at(hex)
					if t == null or t.faction != UnitData.Faction.ENEMY or not t.is_alive:
						continue
					if kind == ProjectileData.Kind.ARC or _arrow_reaches(u.hex_pos, hex) == hex:
						attackable_hexes.append(hex)
						if tiles.has(hex):
							tiles[hex].set_attack_target(true)


func _clear_highlights() -> void:
	for hex in reachable_hexes:
		if tiles.has(hex):
			tiles[hex].set_reachable(false)
	for hex in attackable_hexes:
		if tiles.has(hex):
			tiles[hex].set_attack_target(false)
	reachable_hexes.clear()
	attackable_hexes.clear()


# ════════════════════════════════════════════════════════════════════
# Combat
# ════════════════════════════════════════════════════════════════════

func _do_attack(attacker: BaseUnit, defender: BaseUnit) -> void:
	if attacker.has_attacked:
		_set_status("%s already attacked this turn!" % attacker.unit_name)
		return
 
	var atk_range: int = attacker.attack_range

	if atk_range <= 1:
		# Melee — instant
		attacker.has_attacked = true
		defender.take_damage(attacker.attack)
		_set_status("%s attacks %s for %d! (%d HP left)" % [
			attacker.unit_name, defender.unit_name, attacker.attack, defender.hp])
		_clear_highlights()
		if selected_unit != null:
			_highlight_for(selected_unit)
		_check_game_over()
	else:
		# Ranged — fire projectile, damage on landing
		_do_ranged_attack_at(attacker, defender.hex_pos)

# ════════════════════════════════════════════════════════════════════
# Combat — ranged
# ════════════════════════════════════════════════════════════════════
 
## Fire a projectile from `attacker` toward `target_hex`.
## For ARROW: compute where the line is blocked and land there.
## For ARC:   always land on target_hex.
func _do_ranged_attack_at(attacker: BaseUnit, target_hex: Vector2i) -> void:
	if attacker.has_attacked:
		return
	attacker.has_attacked = true
	_clear_highlights()
 
	var kind: int      = EquipmentData.WEAPONS[
		attacker.primary_weapon if attacker.active_weapon == BaseUnit.WeaponSlot.PRIMARY
		else attacker.secondary_weapon]["projectile_kind"]
	var landed_hex: Vector2i
 
	if kind == ProjectileData.Kind.ARC:
		landed_hex = target_hex                        # always reaches
	else:
		# ARROW: find first blocking hex on the line
		var blocked := _arrow_reaches(attacker.hex_pos, target_hex)
		landed_hex = blocked
 
	var from_world: Vector2 = HexGrid.axial_to_world(attacker.hex_pos, HEX_SIZE)
	var to_world:   Vector2 = HexGrid.axial_to_world(landed_hex, HEX_SIZE)
 
	var proj := Projectile.new()
	proj.position = Vector2.ZERO   # drawn relative to world origin via _from offset
	unit_layer.add_child(proj)
 
	var proj_color: Color = UnitData.UNITS[attacker.unit_type]["trim_color"]
	proj.fire(from_world, to_world,
			  kind as ProjectileData.Kind,
			  proj_color,
			  landed_hex if landed_hex != target_hex else Vector2i(-1, -1))
 
	var attacker_ref := attacker   # capture for lambda
	var landed_ref   := landed_hex
	proj.landed.connect(func(blocked_hex: Vector2i) -> void:
		_on_projectile_landed(attacker_ref, landed_ref))
 

## Variant used by AI: fire_origin can differ from attacker.hex_pos (phantom attacks)
func _do_ranged_attack_at_from(attacker: BaseUnit, target_hex: Vector2i, fire_origin: Vector2i) -> void:
	var kind: int = EquipmentData.WEAPONS[
		attacker.primary_weapon if attacker.active_weapon == BaseUnit.WeaponSlot.PRIMARY
		else attacker.secondary_weapon]["projectile_kind"]
	var landed_hex: Vector2i
	if kind == ProjectileData.Kind.ARC:
		landed_hex = target_hex
	else:
		landed_hex = _arrow_reaches(fire_origin, target_hex)

	var from_world: Vector2 = HexGrid.axial_to_world(fire_origin, HEX_SIZE)
	var to_world:   Vector2 = HexGrid.axial_to_world(landed_hex, HEX_SIZE)

	var proj := Projectile.new()
	proj.position = Vector2.ZERO
	unit_layer.add_child(proj)

	var proj_color: Color = UnitData.UNITS[attacker.unit_type]["trim_color"]
	proj.fire(from_world, to_world,
			  kind as ProjectileData.Kind,
			  proj_color,
			  landed_hex if landed_hex != target_hex else Vector2i(-1, -1))

	var attacker_ref := attacker
	var landed_ref   := landed_hex
	proj.landed.connect(func(_blocked: Vector2i) -> void:
		_on_projectile_landed(attacker_ref, landed_ref))


func _on_projectile_landed(attacker: BaseUnit, landed_hex: Vector2i) -> void:
	var target: BaseUnit = _unit_at(landed_hex)
	if target != null and target.faction != attacker.faction and target.is_alive:
		target.take_damage(attacker.attack)
		_set_status("%s fires at %s for %d! (%d HP left)" % [
			attacker.unit_name, target.unit_name, attacker.attack, target.hp])
	else:
		_set_status("%s fires — no target at destination." % attacker.unit_name)
 
	if selected_unit != null:
		_highlight_for(selected_unit)
	_check_game_over()
 
 
## Walk the hex line from `origin` (exclusive) to `goal` (inclusive).
## Return the first hex that is blocked by terrain or a unit.
## If nothing blocks, return `goal`.
func _arrow_reaches(origin: Vector2i, goal: Vector2i) -> Vector2i:
	var line: Array[Vector2i] = HexGrid.hex_line(origin, goal)
	# Skip index 0 (that's the shooter's own hex)
	for i in range(1, line.size()):
		var hex: Vector2i = line[i]
		# Blocked by a unit on an intermediate hex (not the final target)
		if i < line.size() - 1:
			if _unit_at(hex) != null:
				return hex
		# Blocked by terrain overlay (forest/building/wall) on any intermediate hex
		if i < line.size() - 1 and terrain_map.has(hex):
			if ProjectileData.overlay_blocks_arrow(int(terrain_map[hex].overlay)):
				return hex
	return goal
 

# ════════════════════════════════════════════════════════════════════
# Enemy execution — follows frozen path, finds last free tile
# ════════════════════════════════════════════════════════════════════

func _execute_intent(enemy: BaseUnit, intent: Dictionary) -> void:
	if intent.is_empty():
		return

	var planned_dest: Vector2i      = intent["move_to"]
	var path: Array                 = intent["path"]   # Array[Vector2i]
	var atk                         = intent["attack"] # Vector2i or null

	# Walk the stored path and find the last tile that is still free.
	# This handles the case where the player moved into a tile during their turn.
	var actual_dest: Vector2i = enemy.hex_pos   # stay by default
	if planned_dest != enemy.hex_pos:
		# Try tiles along path from end toward start until we find a free one
		# First try the planned destination
		if _unit_at(planned_dest) == null:
			actual_dest = planned_dest
		else:
			# Walk path in order, take last free step
			for step_hex in path:
				if step_hex == planned_dest:
					break
				if _unit_at(step_hex) == null:
					actual_dest = step_hex
				else:
					break   # blocked earlier on path, stop here

	if actual_dest != enemy.hex_pos:
		var cost: int = enemy.terrain_cost(terrain_map.get(actual_dest, TerrainData.HexCell.new()))
		enemy.move_to(actual_dest, HEX_SIZE, cost)
		_apply_unit_z(enemy, actual_dest)

	# Attack: execute if target is still in range from wherever enemy ended up
	if atk != null:
		var atk_hex: Vector2i = atk
		get_tree().create_timer(0.24).timeout.connect(func() -> void:
			var defender: BaseUnit = _unit_at(atk_hex)
			if defender == null or not defender.is_alive:
				return
			if defender.faction != UnitData.Faction.PLAYER:
				return
			var atk_range: int  = enemy.attack_range
			var kind: int       = EquipmentData.WEAPONS[
				enemy.primary_weapon if enemy.active_weapon == BaseUnit.WeaponSlot.PRIMARY
				else enemy.secondary_weapon]["projectile_kind"]
			var actual_dist: int = HexGrid.distance(enemy.hex_pos, atk_hex)
			var origin_dist: int = HexGrid.distance(intent["origin"], atk_hex)
			# Fire from actual position if in range, else phantom-fire from origin
			var fire_from: Vector2i = enemy.hex_pos if actual_dist <= atk_range \
									 else intent["origin"] if origin_dist <= atk_range \
									 else Vector2i(-1, -1)
			if fire_from == Vector2i(-1, -1):
				return
			_ai_attack(enemy, defender, fire_from)
		)


func _ai_attack(enemy: BaseUnit, target: BaseUnit, fire_from: Vector2i = Vector2i(-1, -1)) -> void:
	if not target.is_alive or enemy.has_attacked:
		return
	enemy.has_attacked = true
	var atk_range: int = enemy.attack_range
	if atk_range <= 1:
		# Melee — instant damage
		target.take_damage(enemy.attack)
		_set_status("%s attacks %s for %d! (%d HP)" % [
			enemy.unit_name, target.unit_name, enemy.attack, target.hp])
	else:
		# Ranged — fire projectile from fire_from (or enemy.hex_pos as fallback)
		var origin: Vector2i = fire_from if fire_from != Vector2i(-1, -1) else enemy.hex_pos
		_do_ranged_attack_at_from(enemy, target.hex_pos, origin)


func _closest_player(enemy: BaseUnit) -> BaseUnit:
	var best: BaseUnit = null
	var best_dist: int = 999999
	for u in player_units:
		if not u.is_alive:
			continue
		var d: int = HexGrid.distance(enemy.hex_pos, u.hex_pos)
		if d < best_dist:
			best_dist = d
			best      = u
	return best


# ════════════════════════════════════════════════════════════════════
# Helpers
# ════════════════════════════════════════════════════════════════════

func _unit_at(hex: Vector2i) -> BaseUnit:
	for u in all_units:
		if u.is_alive and u.hex_pos == hex:
			return u
	return null


func _check_game_over() -> bool:
	var players_alive: bool = player_units.any(
		func(u: BaseUnit) -> bool: return u.is_alive)
	var enemies_alive: bool = enemy_units.any(
		func(u: BaseUnit) -> bool: return u.is_alive)

	if not enemies_alive:
		phase = Phase.VICTORY
		_clear_intent_highlights()
		_set_status("⚔ Victory! All enemies defeated.")
		phase_changed.emit(phase)
		battle_ended.emit(true)
		return true

	if not players_alive:
		phase = Phase.DEFEAT
		_clear_intent_highlights()
		_set_status("💀 Defeat. All your units have fallen.")
		phase_changed.emit(phase)
		battle_ended.emit(false)
		return true

	return false


func _on_unit_died(unit: BaseUnit) -> void:
	get_tree().create_timer(0.5).timeout.connect(func() -> void:
		if is_instance_valid(unit):
			unit.visible = false)


func _set_status(msg: String) -> void:
	status_changed.emit(msg)
	if status_label != null:
		status_label.text = msg
