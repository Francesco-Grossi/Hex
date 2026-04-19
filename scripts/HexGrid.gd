## HexGrid.gd
## Pure hex grid math — no nodes, no drawing.
## Uses AXIAL coordinates (q, r) with pointy-top orientation.
##
## MATH REFERENCE:
##   Pointy-top hex pixel center from axial (q, r):
##     x = size * (√3 * q  +  √3/2 * r)
##     y = size * (           3/2   * r)
##
##   Inverse (pixel → axial), then cube-round:
##     q_frac = (√3/3 * x  -  1/3 * y) / size
##     r_frac = (              2/3 * y) / size
##     Then snap to nearest cube coordinate.
##
##   6 neighbor directions in axial space: E, NE, NW, W, SW, SE
##
##   Cube distance:  dist = max(|Δq|, |Δr|, |Δs|)
##
## NEW — A* pathfinding (astar_path):
##   Uses cube-distance as the admissible heuristic (never over-estimates).
##   `cost_fn` returns the movement-point cost to enter a hex (int, 99=blocked).
##   Returns the shortest path as an Array[Vector2i] from origin to goal,
##   NOT including the origin itself.  Returns [] if unreachable.

class_name HexGrid

## The 6 axial direction vectors (pointy-top)
const DIRECTIONS: Array[Vector2i] = [
	Vector2i(1,  0),   # East
	Vector2i(1, -1),   # North-East
	Vector2i(0, -1),   # North-West
	Vector2i(-1, 0),   # West
	Vector2i(-1, 1),   # South-West
	Vector2i(0,  1),   # South-East
]

const DIRECTION_NAMES: Array[String] = ["E", "NE", "NW", "W", "SW", "SE"]


## Convert axial hex coord → world pixel position (center of hex)
static func axial_to_world(hex: Vector2i, hex_size: float) -> Vector2:
	var x: float = hex_size * (sqrt(3.0) * hex.x  +  sqrt(3.0) / 2.0 * hex.y)
	var y: float = hex_size * (3.0 / 2.0 * hex.y)
	return Vector2(x, y)


## Convert world pixel position → axial hex coord (rounded)
static func world_to_axial(world: Vector2, hex_size: float) -> Vector2i:
	var q_frac: float = (sqrt(3.0) / 3.0 * world.x  -  1.0 / 3.0 * world.y) / hex_size
	var r_frac: float = (2.0 / 3.0 * world.y) / hex_size
	return _axial_round(q_frac, r_frac)


## Round fractional axial coords to nearest hex (via cube rounding)
static func _axial_round(q_frac: float, r_frac: float) -> Vector2i:
	var s_frac: float = -q_frac - r_frac
	var q: int = roundi(q_frac)
	var r: int = roundi(r_frac)
	var s: int = roundi(s_frac)
	var dq: float = abs(q - q_frac)
	var dr: float = abs(r - r_frac)
	var ds: float = abs(s - s_frac)
	if dq > dr and dq > ds:
		q = -r - s
	elif dr > ds:
		r = -q - s
	return Vector2i(q, r)


## Cube distance between two axial hexes
static func distance(a: Vector2i, b: Vector2i) -> int:
	var dq: int = a.x - b.x
	var dr: int = a.y - b.y
	var ds: int = -dq - dr
	return maxi(maxi(absi(dq), absi(dr)), absi(ds))


## Get all 6 neighbors of a hex
static func neighbors(hex: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for dir in DIRECTIONS:
		result.append(hex + dir)
	return result


## BFS flood fill — returns all hexes reachable within `moves` movement points.
## `blocked` callable: func(hex: Vector2i) -> bool
## (For terrain-cost-aware movement use reachable_weighted below.)
static func reachable(origin: Vector2i, moves: int, blocked: Callable) -> Array[Vector2i]:
	var visited: Dictionary = {}
	var frontier: Array[Vector2i] = [origin]
	visited[origin] = 0

	while not frontier.is_empty():
		var next_frontier: Array[Vector2i] = []
		for hex in frontier:
			var cost: int = visited[hex]
			if cost >= moves:
				continue
			for nb in neighbors(hex):
				if nb in visited:
					continue
				if blocked.call(nb):
					continue
				visited[nb] = cost + 1
				next_frontier.append(nb)
		frontier = next_frontier

	var result: Array[Vector2i] = []
	for hex in visited:
		result.append(hex)
	return result


## Dijkstra flood fill — terrain-cost-aware version.
## `cost_fn` callable: func(hex: Vector2i) -> int  (99 = impassable)
## Returns Dictionary[Vector2i → int] of all reachable hexes with their costs.
static func reachable_weighted(origin: Vector2i, move_budget: int,
		cost_fn: Callable) -> Dictionary:
	# cost_so_far maps hex → total movement points spent to reach it
	var cost_so_far: Dictionary = { origin: 0 }
	# Simple priority queue via sorted array of [cost, hex]
	var frontier: Array = [[0, origin]]

	while not frontier.is_empty():
		# Pop the entry with the smallest cost
		frontier.sort_custom(func(a, b): return a[0] < b[0])
		var entry: Array = frontier.pop_front()
		var curr_cost: int = entry[0]
		var curr: Vector2i = entry[1]

		if curr_cost > cost_so_far.get(curr, INF):
			continue  # stale entry

		for nb in neighbors(curr):
			var step_cost: int = cost_fn.call(nb)
			if step_cost >= 99:
				continue  # impassable
			var new_cost: int = curr_cost + step_cost
			if new_cost > move_budget:
				continue  # out of budget
			if new_cost < cost_so_far.get(nb, 9999):
				cost_so_far[nb] = new_cost
				frontier.append([new_cost, nb])

	return cost_so_far


## A* pathfinding — finds the cheapest path from `origin` to `goal`.
## `cost_fn` callable: func(hex: Vector2i) -> int  (99 = impassable/blocked)
## Returns Array[Vector2i] of steps NOT including origin; empty if unreachable.
##
## Heuristic: hex distance (cube distance) — admissible because each step
## costs at least 1 movement point and covers exactly 1 hex of hex-distance.
static func astar_path(origin: Vector2i, goal: Vector2i,
		cost_fn: Callable) -> Array[Vector2i]:
	if origin == goal:
		return []

	# g_score: cheapest known cost from origin to each hex
	var g_score: Dictionary = { origin: 0 }
	# came_from: for path reconstruction
	var came_from: Dictionary = {}
	# Open set as [[f_score, hex]]
	var open_set: Array = [[distance(origin, goal), origin]]

	while not open_set.is_empty():
		open_set.sort_custom(func(a, b): return a[0] < b[0])
		var current: Vector2i = open_set.pop_front()[1]

		if current == goal:
			# Reconstruct path
			var path: Array[Vector2i] = []
			var node: Vector2i = goal
			while node != origin:
				path.push_front(node)
				node = came_from[node]
			return path

		for nb in neighbors(current):
			var step: int = cost_fn.call(nb)
			if step >= 99:
				continue  # blocked
			var tentative_g: int = g_score.get(current, 9999999) + step
			if tentative_g < g_score.get(nb, 9999999):
				came_from[nb] = current
				g_score[nb] = tentative_g
				var f: int = tentative_g + distance(nb, goal)
				open_set.append([f, nb])

	return []  # unreachable


## Get all hexes within a ring of exactly `radius` distance
static func ring(center: Vector2i, radius: int) -> Array[Vector2i]:
	if radius == 0:
		return [center]
	var results: Array[Vector2i] = []
	var hex: Vector2i = center + DIRECTIONS[4] * radius
	for i in range(6):
		for _j in range(radius):
			results.append(hex)
			hex = hex + DIRECTIONS[i]
	return results


## Get the polygon points for a pointy-top hex centered at (0,0)
static func hex_corners(hex_size: float) -> PackedVector2Array:
	var corners := PackedVector2Array()
	for i in range(6):
		var angle_deg: float = 60.0 * i - 30.0
		var angle_rad: float = deg_to_rad(angle_deg)
		corners.append(Vector2(hex_size * cos(angle_rad), hex_size * sin(angle_rad)))
	return corners
