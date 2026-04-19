## BattleManager.gd
## Manages a full battle session on top of an existing hex map.
##
## TURN FLOW:
##   Player Phase → player clicks to select/move/attack → presses "End Turn"
##   Enemy Phase  → each enemy runs A* toward nearest player, attacks if adjacent
##   Repeat until all of one side is dead.
##
## USAGE:
##   Attach to a Node2D sibling of the grid.
##   Call setup() with the tile map, terrain map, and HEX_SIZE.
##   Call start_battle() to spawn units and begin.

class_name BattleManager
extends Node2D

const HEX_SIZE: float = 44.0

# ── External references (set by caller) ──────────────────────────────
var tiles: Dictionary = {}        # Vector2i → HexTile
var terrain_map: Dictionary = {}  # Vector2i → TerrainData.Type
var unit_layer: Node2D = null
var status_label: Label = null

# ── Unit tracking ────────────────────────────────────────────────────
var player_units: Array[BaseUnit] = []
var enemy_units: Array[BaseUnit] = []
var all_units: Array[BaseUnit] = []   # for fast "is hex occupied?" checks

# ── Turn state ───────────────────────────────────────────────────────
enum Phase { PLAYER, ENEMY, VICTORY, DEFEAT }
var phase: Phase = Phase.PLAYER

var selected_unit: BaseUnit = null   # currently selected player unit
var reachable_hexes: Dictionary = {} # Vector2i → cost (from Dijkstra)
var attackable_hexes: Array[Vector2i] = []

# ── Signals ──────────────────────────────────────────────────────────
signal battle_ended(victory: bool)
signal status_changed(text: String)
signal phase_changed(new_phase: Phase)


# ════════════════════════════════════════════════════════════════════
# Setup
# ════════════════════════════════════════════════════════════════════

func setup(p_tiles: Dictionary, p_terrain: Dictionary,
		p_unit_layer: Node2D, p_status: Label) -> void:
	tiles       = p_tiles
	terrain_map = p_terrain
	unit_layer  = p_unit_layer
	status_label = p_status


func start_battle(player_placements: Array = [], enemy_placements: Array = []) -> void:
	if player_placements.is_empty():
		_spawn_player_units()
	else:
		for entry in player_placements:
			var u: BaseUnit = _make_unit(entry[0], entry[1])
			player_units.append(u)
			all_units.append(u)
	if enemy_placements.is_empty():
		_spawn_enemy_units()
	else:
		for entry in enemy_placements:
			var u: BaseUnit = _make_unit(entry[0], entry[1])
			enemy_units.append(u)
			all_units.append(u)
	_begin_player_phase()


# ════════════════════════════════════════════════════════════════════
# Unit spawning
# ════════════════════════════════════════════════════════════════════

func _spawn_player_units() -> void:
	var placements: Array = [
		[UnitData.Type.KNIGHT, Vector2i(1, 4)],
		[UnitData.Type.ARCHER, Vector2i(1, 6)],
		[UnitData.Type.MAGE,   Vector2i(2, 5)],
	]
	for entry in placements:
		var u: BaseUnit = _make_unit(entry[0], entry[1])
		player_units.append(u)
		all_units.append(u)


func _spawn_enemy_units() -> void:
	var cols: int = tiles.keys().map(func(v: Vector2i) -> int: return v.x).max()
	var placements: Array = [
		[UnitData.Type.ORC,    Vector2i(cols - 1, 3)],
		[UnitData.Type.GOBLIN, Vector2i(cols - 2, 5)],
		[UnitData.Type.TROLL,  Vector2i(cols - 1, 7)],
	]
	for entry in placements:
		var u: BaseUnit = _make_unit(entry[0], entry[1])
		enemy_units.append(u)
		all_units.append(u)


func _make_unit(type: UnitData.Type, hex: Vector2i) -> BaseUnit:
	var u := BaseUnit.new()
	u.setup(type)
	u.place_at(hex, HEX_SIZE)
	u.z_index = 10
	u.died.connect(_on_unit_died)
	unit_layer.add_child(u)
	return u


# ════════════════════════════════════════════════════════════════════
# Phase management
# ════════════════════════════════════════════════════════════════════

func _begin_player_phase() -> void:
	phase = Phase.PLAYER
	for u in player_units:
		if u.is_alive:
			u.reset_turn()
	_deselect()
	_set_status("Your turn — select a unit")
	phase_changed.emit(phase)


func end_player_turn() -> void:
	if phase != Phase.PLAYER:
		return
	_deselect()
	_clear_highlights()
	phase = Phase.ENEMY
	phase_changed.emit(phase)
	_set_status("Enemy turn…")
	# Slight delay so the player can see the status change before AI runs
	get_tree().create_timer(0.4).timeout.connect(_run_enemy_phase)


func _run_enemy_phase() -> void:
	# Move and attack with each living enemy, one after another with delays
	var living: Array[BaseUnit] = enemy_units.filter(func(u: BaseUnit) -> bool: return u.is_alive)
	_process_enemy(living, 0)


func _process_enemy(living: Array[BaseUnit], idx: int) -> void:
	if idx >= living.size():
		# All enemies done — check defeat then start player turn
		if _check_game_over():
			return
		get_tree().create_timer(0.3).timeout.connect(_begin_player_phase)
		return

	var enemy: BaseUnit = living[idx]
	enemy.reset_turn()
	_ai_move_and_attack(enemy)

	get_tree().create_timer(0.55).timeout.connect(
		func() -> void: _process_enemy(living, idx + 1)
	)


# ════════════════════════════════════════════════════════════════════
# Player input (called from MapEditor / BattleScene)
# ════════════════════════════════════════════════════════════════════

func handle_hex_click(hex: Vector2i) -> void:
	if phase != Phase.PLAYER:
		return

	var clicked_unit: BaseUnit = _unit_at(hex)

	# ── Case 1: click a friendly unit → select it ────────────────────
	if clicked_unit != null and clicked_unit.faction == UnitData.Faction.PLAYER \
			and clicked_unit.is_alive:
		_select_unit(clicked_unit)
		return

	# ── Case 2: click an attackable enemy → attack ───────────────────
	if selected_unit != null and hex in attackable_hexes:
		if clicked_unit != null and clicked_unit.faction == UnitData.Faction.ENEMY:
			_do_attack(selected_unit, clicked_unit)
			return

	# ── Case 3: click a reachable empty hex → move ───────────────────
	if selected_unit != null and reachable_hexes.has(hex) \
			and _unit_at(hex) == null:
		_do_move(selected_unit, hex)
		return

	# ── Case 4: click empty / unreachable → deselect ─────────────────
	_deselect()


func _select_unit(u: BaseUnit) -> void:
	_deselect()
	selected_unit = u
	_highlight_for(u)
	_set_status("%s selected — HP %d/%d  Moves %d  ATK %d" % [
		u.unit_name, u.hp, u.hp_max, u.moves_left, u.attack
	])
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
	_clear_highlights()
	# Recompute highlights from new position after tween lands
	get_tree().create_timer(0.25).timeout.connect(func() -> void:
		_select_unit(u)
	)


## Cost function for a given unit type on the current terrain map
func _cost_fn(unit_type: UnitData.Type) -> Callable:
	return func(hex: Vector2i) -> int:
		if not terrain_map.has(hex):
			return 99  # out of bounds
		# A hex occupied by ANY unit is blocked for movement
		if _unit_at(hex) != null:
			return 99
		var t: int = terrain_map[hex]
		return UnitData.move_cost(unit_type, t)


func _highlight_for(u: BaseUnit) -> void:
	_clear_highlights()
	attackable_hexes.clear()

	if u.moves_left > 0:
		reachable_hexes = HexGrid.reachable_weighted(u.hex_pos, u.moves_left, _cost_fn(u.unit_type))
		reachable_hexes.erase(u.hex_pos)  # don't highlight own hex
		for hex in reachable_hexes:
			if tiles.has(hex):
				tiles[hex].set_reachable(true)

	# Adjacent enemies are attackable even if unit already moved
	if not u.has_attacked:
		for nb in HexGrid.neighbors(u.hex_pos):
			var t: BaseUnit = _unit_at(nb)
			if t != null and t.faction == UnitData.Faction.ENEMY and t.is_alive:
				attackable_hexes.append(nb)
				if tiles.has(nb):
					tiles[nb].set_attack_target(true)


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
	attacker.has_attacked = true
	var dmg: int = attacker.attack
	defender.take_damage(dmg)
	_set_status("%s attacks %s for %d damage! (%d HP left)" % [
		attacker.unit_name, defender.unit_name, dmg, defender.hp
	])
	_clear_highlights()
	if selected_unit != null:
		_highlight_for(selected_unit)
	_check_game_over()


# ════════════════════════════════════════════════════════════════════
# Enemy AI — A* chase and attack
# ════════════════════════════════════════════════════════════════════

func _ai_move_and_attack(enemy: BaseUnit) -> void:
	# 1. Find closest living player unit (by hex distance)
	var target: BaseUnit = _closest_player(enemy)
	if target == null:
		return

	# 2. If already adjacent — attack immediately
	if HexGrid.distance(enemy.hex_pos, target.hex_pos) == 1:
		_ai_attack(enemy, target)
		return

	# 3. A* toward target, respecting terrain costs and unit blocking
	# The goal is the target's hex, but we can't enter it (occupied).
	# Find the path and move as far as the move budget allows, stopping
	# one hex away from any unit.
	var cost_fn: Callable = func(hex: Vector2i) -> int:
		if not terrain_map.has(hex):
			return 99
		# Allow passing through the target hex only as the last step check;
		# treat other allied-enemy hexes as blocked
		if hex != target.hex_pos and _unit_at(hex) != null:
			return 99
		return UnitData.move_cost(enemy.unit_type, terrain_map[hex])

	var path: Array[Vector2i] = HexGrid.astar_path(enemy.hex_pos, target.hex_pos, cost_fn)
	if path.is_empty():
		return  # trapped or unreachable

	# Walk as many steps as the move budget allows
	var spent: int = 0
	var last_valid: Vector2i = enemy.hex_pos

	for step_hex in path:
		if step_hex == target.hex_pos:
			break  # don't step onto the target — stop adjacent
		var t_cost: int = UnitData.move_cost(enemy.unit_type, terrain_map.get(step_hex, 0))
		if spent + t_cost > enemy.moves_left:
			break
		spent += t_cost
		last_valid = step_hex

	if last_valid != enemy.hex_pos:
		enemy.move_to(last_valid, HEX_SIZE, spent)

	# 4. Attack if now adjacent (after move)
	if HexGrid.distance(last_valid, target.hex_pos) == 1:
		# Small delay so move animation finishes first
		get_tree().create_timer(0.22).timeout.connect(
			func() -> void: _ai_attack(enemy, target)
		)


func _ai_attack(enemy: BaseUnit, target: BaseUnit) -> void:
	if not target.is_alive:
		return
	var dmg: int = enemy.attack
	target.take_damage(dmg)
	_set_status("%s attacks %s for %d! (%d HP)" % [
		enemy.unit_name, target.unit_name, dmg, target.hp
	])


func _closest_player(enemy: BaseUnit) -> BaseUnit:
	var best: BaseUnit = null
	var best_dist: int = 999999
	for u in player_units:
		if not u.is_alive:
			continue
		var d: int = HexGrid.distance(enemy.hex_pos, u.hex_pos)
		if d < best_dist:
			best_dist = d
			best = u
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
	var players_alive: bool = player_units.any(func(u: BaseUnit) -> bool: return u.is_alive)
	var enemies_alive: bool = enemy_units.any(func(u: BaseUnit) -> bool: return u.is_alive)

	if not enemies_alive:
		phase = Phase.VICTORY
		_set_status("⚔ Victory! All enemies defeated.")
		phase_changed.emit(phase)
		battle_ended.emit(true)
		return true

	if not players_alive:
		phase = Phase.DEFEAT
		_set_status("💀 Defeat. All your units have fallen.")
		phase_changed.emit(phase)
		battle_ended.emit(false)
		return true

	return false


func _on_unit_died(unit: BaseUnit) -> void:
	# Remove visual presence — hide the node after a brief moment
	get_tree().create_timer(0.5).timeout.connect(func() -> void:
		if is_instance_valid(unit):
			unit.visible = false
	)


func _set_status(msg: String) -> void:
	status_changed.emit(msg)
	if status_label != null:
		status_label.text = msg
