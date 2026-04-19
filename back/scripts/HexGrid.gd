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
##   6 neighbor directions in axial space:
##     E, NE, NW, W, SW, SE
##
##   Cube distance:
##     convert axial → cube (s = -q - r)
##     dist = max(|Δq|, |Δr|, |Δs|)
##
## Godot 4.4–4.6 changes applied:
##   - reachable() now uses Dictionary[Vector2i, int] (typed dict, new in 4.4)
##   - ring() return type annotation tightened

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
	# Convert axial → cube
	var s_frac: float = -q_frac - r_frac
	# Round all three
	var q: int = roundi(q_frac)
	var r: int = roundi(r_frac)
	var s: int = roundi(s_frac)
	# Fix the component with largest rounding error so q+r+s==0
	var dq: float = absf(q - q_frac)
	var dr: float = absf(r - r_frac)
	var ds: float = absf(s - s_frac)
	if dq > dr and dq > ds:
		q = -r - s
	elif dr > ds:
		r = -q - s
	# s = -q - r (not needed as return value)
	return Vector2i(q, r)


## Cube distance between two axial hexes
static func distance(a: Vector2i, b: Vector2i) -> int:
	var dq: int = a.x - b.x
	var dr: int = a.y - b.y
	var ds: int = -dq - dr  # s = -q - r
	return maxi(maxi(absi(dq), absi(dr)), absi(ds))


## Get all 6 neighbors of a hex
static func neighbors(hex: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for dir: Vector2i in DIRECTIONS:
		result.append(hex + dir)
	return result


## BFS flood fill: returns all hexes reachable within `moves` steps.
## `blocked` is a callable: func(hex: Vector2i) -> bool
##
## 4.4+: internal visited map is now Dictionary[Vector2i, int] (typed).
static func reachable(origin: Vector2i, moves: int, blocked: Callable) -> Array[Vector2i]:
	# Typed Dictionary (Godot 4.4+): key = hex coord, value = BFS cost
	var visited: Dictionary[Vector2i, int] = {}
	var frontier: Array[Vector2i] = [origin]
	visited[origin] = 0

	while not frontier.is_empty():
		var next_frontier: Array[Vector2i] = []
		for hex: Vector2i in frontier:
			var cost: int = visited[hex]
			if cost >= moves:
				continue
			for neighbor: Vector2i in neighbors(hex):
				if visited.has(neighbor):
					continue
				if blocked.call(neighbor):
					continue
				visited[neighbor] = cost + 1
				next_frontier.append(neighbor)
		frontier = next_frontier

	var result: Array[Vector2i] = []
	for hex: Vector2i in visited:
		result.append(hex)
	return result


## Get all hexes within a ring of exactly `radius` distance
static func ring(center: Vector2i, radius: int) -> Array[Vector2i]:
	if radius == 0:
		return [center]
	var results: Array[Vector2i] = []
	var hex: Vector2i = center + DIRECTIONS[4] * radius  # start at SW corner
	for i: int in range(6):
		for _j: int in range(radius):
			results.append(hex)
			hex = hex + DIRECTIONS[i]
	return results


## Get the polygon points for a pointy-top hex centered at (0,0)
static func hex_corners(hex_size: float) -> PackedVector2Array:
	var corners := PackedVector2Array()
	for i: int in range(6):
		var angle_deg: float = 60.0 * i - 30.0   # -30 for pointy-top
		var angle_rad: float = deg_to_rad(angle_deg)
		corners.append(Vector2(hex_size * cos(angle_rad), hex_size * sin(angle_rad)))
	return corners
