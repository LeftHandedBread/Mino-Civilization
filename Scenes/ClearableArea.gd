# VolumeClearer.gd (Godot 4)
extends Node3D

enum Mode { FIXED_VOLUME, ANY_SUBCUBE }

@export var gridmap_path: NodePath = "../GridMap"
@export var mode: Mode = Mode.FIXED_VOLUME

# N in NxNxN
@export var n: int = 3

# Board bounds (inclusive). Used to limit scanning & prevent out-of-bounds.
@export var board_min: Vector3i = Vector3i(-4, 1, -8)
@export var board_max: Vector3i = Vector3i(3, 8, -8)

# If using FIXED_VOLUME, this is the cube origin (min corner).
@export var fixed_origin: Vector3i = Vector3i(-4, 1, -8)

@onready var gridmap: GridMap = get_node(gridmap_path)



func on_piece_locked(_cells: Array[Vector3i]) -> void:
	# Debug markers (optional) — note these become "occupied" cells too
	gridmap.set_cell_item(board_min, 1)
	gridmap.set_cell_item(board_max, 1)

	if mode == Mode.FIXED_VOLUME:
		if _aabb_is_full(board_min, board_max):
			_clear_aabb(board_min, board_max)
		return

	# ANY_SUBCUBE (unchanged behavior, uses n)
	var candidate_origins := _candidate_cube_origins(_cells)
	for o in candidate_origins:
		if _cube_is_full(o):
			_clear_cube(o)

func _candidate_cube_origins(locked_cells: Array[Vector3i]) -> Array[Vector3i]:
	var origins: Array[Vector3i] = []
	var seen := {}  # origin -> true

	var max_origin := board_max - Vector3i(n - 1, n - 1, n - 1)

	for c in locked_cells:
		# cube origins that would include cell c:
		for ox in range(c.x - (n - 1), c.x + 1):
			for oy in range(c.y - (n - 1), c.y + 1):
				for oz in range(c.z - (n - 1), c.z + 1):
					var o := Vector3i(ox, oy, oz)
					if o.x < board_min.x or o.y < board_min.y or o.z < board_min.z:
						continue
					if o.x > max_origin.x or o.y > max_origin.y or o.z > max_origin.z:
						continue
					if not seen.has(o):
						seen[o] = true
						origins.append(o)

	return origins

func _cube_is_full(origin: Vector3i) -> bool:
	# origin must be within bounds for an NxNxN cube
	var max_origin := board_max
	if origin.x < board_min.x or origin.y < board_min.y or origin.z < board_min.z:
		return false
	if origin.x > max_origin.x or origin.y > max_origin.y or origin.z > max_origin.z:
		return false

	for dx in range(n):
		for dy in range(n):
			for dz in range(n):
				var cell := origin + Vector3i(dx, dy, dz)
				if gridmap.get_cell_item(cell) == -1:
					return false
	return true

func _sorted_min(a: Vector3i, b: Vector3i) -> Vector3i:
	return Vector3i(min(a.x, b.x), min(a.y, b.y), min(a.z, b.z))

func _sorted_max(a: Vector3i, b: Vector3i) -> Vector3i:
	return Vector3i(max(a.x, b.x), max(a.y, b.y), max(a.z, b.z))

func _aabb_is_full(a: Vector3i, b: Vector3i) -> bool:
	var lo := _sorted_min(a, b)
	var hi := _sorted_max(a, b)

	for x in range(lo.x, hi.x + 1):
		for y in range(lo.y, hi.y + 1):
			for z in range(lo.z, hi.z + 1):
				if gridmap.get_cell_item(Vector3i(x, y, z)) == -1:
					return false
	return true

func _clear_aabb(a: Vector3i, b: Vector3i) -> void:
	var lo := _sorted_min(a, b)
	var hi := _sorted_max(a, b)

	for x in range(lo.x, hi.x + 1):
		for y in range(lo.y, hi.y + 1):
			for z in range(lo.z, hi.z + 1):
				gridmap.set_cell_item(Vector3i(x, y, z), -1)
func _clear_cube(origin: Vector3i) -> void:
	for dx in range(n):
		for dy in range(n):
			for dz in range(n):
				gridmap.set_cell_item(origin + Vector3i(dx, dy, dz), -1)
