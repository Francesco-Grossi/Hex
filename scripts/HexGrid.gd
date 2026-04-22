class_name HexGrid

## HexGrid.gd (Updated for Flat-Top)

# Directions for Flat-top axial neighbors
const DIRECTIONS: Array[Vector2i] = [
	Vector2i(1, 0),  # Right
	Vector2i(1, -1), # Top Right
	Vector2i(0, -1), # Top Left
	Vector2i(-1, 0), # Left
	Vector2i(-1, 1), # Bottom Left
	Vector2i(0, 1)   # Bottom Right
]

## Convert axial hex coord → world pixel position (Flat-top math)
static func axial_to_world(hex: Vector2i, hex_size: float) -> Vector2:
	var x: float = hex_size * (3.0 / 2.0 * hex.x)
	var y: float = hex_size * (sqrt(3.0) / 2.0 * hex.x + sqrt(3.0) * hex.y)
	return Vector2(x, y)

## Convert world pixel position → axial hex coord (Flat-top math)
static func world_to_axial(world: Vector2, hex_size: float) -> Vector2i:
	var q_frac: float = (2.0 / 3.0 * world.x) / hex_size
	var r_frac: float = (-1.0 / 3.0 * world.x + sqrt(3.0) / 3.0 * world.y) / hex_size
	return _axial_round(q_frac, r_frac)

## Generate corners for a Flat-top hex (Starts at 0 degrees)
static func hex_corners(hex_size: float) -> PackedVector2Array:
	var corners = PackedVector2Array()
	for i in range(6):
		var angle_deg = 60 * i
		var angle_rad = deg_to_rad(angle_deg)
		corners.append(Vector2(
			hex_size * cos(angle_rad),
			hex_size * sin(angle_rad)
		))
	return corners


static func _axial_round(q_frac: float, r_frac: float) -> Vector2i:
	var s_frac: float = -q_frac - r_frac
	var q: int = roundi(q_frac)
	var r: int = roundi(r_frac)
	var s: int = roundi(s_frac)
	var dq: float = abs(q - q_frac)
	var dr: float = abs(r - r_frac)
	var ds: float = abs(s - s_frac)
	if dq > dr and dq > ds: q = -r - s
	elif dr > ds: r = -q - s
	return Vector2i(q, r)

## Distance between two axial hexes
static func distance(a: Vector2i, b: Vector2i) -> int:
	var dq: int = a.x - b.x
	var dr: int = a.y - b.y
	return maxi(maxi(absi(dq), absi(dr)), absi(-dq - dr))

static func neighbors(hex: Vector2i) -> Array[Vector2i]:
	var res: Array[Vector2i] = []
	for d in DIRECTIONS: res.append(hex + d)
	return res

## BFS flood fill — Used by the Editor preview
static func reachable(origin: Vector2i, moves: int, blocked: Callable) -> Array[Vector2i]:
	var visited: Dictionary = { origin: 0 }
	var frontier: Array[Vector2i] = [origin]
	
	while not frontier.is_empty():
		var next_frontier: Array[Vector2i] = []
		for hex in frontier:
			var cost: int = visited[hex]
			if cost >= moves: continue
			for nb in neighbors(hex):
				if nb in visited: continue
				if blocked.call(nb): continue
				visited[nb] = cost + 1
				next_frontier.append(nb)
		frontier = next_frontier
	
	var result: Array[Vector2i] = []
	for hex in visited: result.append(hex)
	return result

## Dijkstra flood fill — terrain-cost-aware (used in Battle)
static func reachable_weighted(origin: Vector2i, budget: int, cost_fn: Callable) -> Dictionary:
	var cost_so_far: Dictionary = { origin: 0 }
	var frontier: Array = [[0, origin]]
	while not frontier.is_empty():
		frontier.sort_custom(func(a, b): return a[0] < b[0])
		var current = frontier.pop_front()
		var curr_cost: int = current[0]
		var curr_hex: Vector2i = current[1]
		if curr_cost > cost_so_far.get(curr_hex, 99999): continue
		for nb in neighbors(curr_hex):
			var step: int = cost_fn.call(nb)
			if step >= 99: continue
			var new_cost: int = curr_cost + step
			if new_cost <= budget and new_cost < cost_so_far.get(nb, 99999):
				cost_so_far[nb] = new_cost
				frontier.append([new_cost, nb])
	return cost_so_far

## A* pathfinding
static func astar_path(origin: Vector2i, goal: Vector2i, cost_fn: Callable) -> Array[Vector2i]:
	if origin == goal: return []
	var g_score: Dictionary = { origin: 0 }
	var came_from: Dictionary = {}
	var open_set: Array = [[distance(origin, goal), origin]]
	while not open_set.is_empty():
		open_set.sort_custom(func(a, b): return a[0] < b[0])
		var current: Vector2i = open_set.pop_front()[1]
		if current == goal:
			var path: Array[Vector2i] = []
			while current != origin:
				path.push_front(current)
				current = came_from[current]
			return path
		for nb in neighbors(current):
			var step: int = cost_fn.call(nb)
			if step >= 99: continue
			var tentative_g: int = g_score.get(current, 99999) + step
			if tentative_g < g_score.get(nb, 99999):
				came_from[nb] = current
				g_score[nb] = tentative_g
				open_set.append([tentative_g + distance(nb, goal), nb])
	return []

## Get a ring of hexes at specific radius
static func ring(center: Vector2i, radius: int) -> Array[Vector2i]:
	if radius == 0: return [center]
	var results: Array[Vector2i] = []
	var hex: Vector2i = center + DIRECTIONS[4] * radius
	for i in range(6):
		for _j in range(radius):
			results.append(hex)
			hex = hex + DIRECTIONS[i]
	return results


## hex_line — returns the ordered list of hex coordinates that a straight
## line from `a` to `b` passes through, INCLUSIVE of both endpoints.
##
## Uses linear interpolation in cube coordinates with a tiny nudge to
## avoid landing exactly on hex edges (which causes ambiguity).
## The result is always length == distance(a, b) + 1.
static func hex_line(a: Vector2i, b: Vector2i) -> Array[Vector2i]:
	var n: int = distance(a, b)
	if n == 0:
		return [a]

	var result: Array[Vector2i] = []
	# Cube coords
	var ax: float = a.x;  var ay: float = a.y;  var az: float = -a.x - a.y
	var bx: float = b.x;  var by: float = b.y;  var bz: float = -b.x - b.y

	# Tiny nudge pushes points off hex boundaries consistently
	const NUDGE: float = 1e-6
	ax += NUDGE; ay += NUDGE; az = -ax - ay
	bx -= NUDGE; by -= NUDGE; bz = -bx - by

	for i in range(n + 1):
		var t: float = float(i) / float(n)
		var lx: float = ax + (bx - ax) * t
		var ly: float = ay + (by - ay) * t
		result.append(_cube_round(lx, ly))
	return result


## Round fractional cube coordinates to the nearest hex.
static func _cube_round(fx: float, fy: float) -> Vector2i:
	var fz: float = -fx - fy
	var rx: int   = roundi(fx)
	var ry: int   = roundi(fy)
	var rz: int   = roundi(fz)
	var dx: float = absf(rx - fx)
	var dy: float = absf(ry - fy)
	var dz: float = absf(rz - fz)
	if dx > dy and dx > dz:
		rx = -ry - rz
	elif dy > dz:
		ry = -rx - rz
	return Vector2i(rx, ry)
