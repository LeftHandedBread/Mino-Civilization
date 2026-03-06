# ActivePiece.gd (Godot 4)
extends Node3D

signal locked_in_place

@export var gridmap_path: NodePath = "../GridMap"
@export var camera_path: NodePath = "../Camera3D"
@onready var cam: Node = get_node_or_null(camera_path)
@export var item_id: int = 1

@export var spawn_cell: Vector3i = Vector3i(0, 5, 0)
@export var pivot_cell: Vector3i = Vector3i(0, 5, 0)

# If false, it will keep using whatever "offsets" is set to in the inspector.
@export var use_random_pieces := true

# Define the piece as offsets from pivot_cell
@export var offsets: Array[Vector3i] = [
	Vector3i(-1, 0, 0),
	Vector3i( 0, 0, 0),
	Vector3i( 1, 0, 0),
	Vector3i( 0, 0, 1),
]

# Gravity
@export var fall_interval := 0.6
@export var gravity_dir: Vector3i = Vector3i(0, -1, 0)
@onready var gridmap: GridMap = get_node(gridmap_path)

var _fall_accum := 0.0
var _locked := false
var _rng := RandomNumberGenerator.new()

const PIECES = [
	# I
	[Vector3i(-1,0,0), Vector3i(0,0,0), Vector3i(1,0,0), Vector3i(2,0,0)],
	# O
	[Vector3i(0,0,0), Vector3i(1,0,0), Vector3i(0,0,1), Vector3i(1,0,1)],
	# T
	[Vector3i(-1,0,0), Vector3i(0,0,0), Vector3i(1,0,0), Vector3i(0,0,1)],
	# L
	[Vector3i(-1,0,0), Vector3i(0,0,0), Vector3i(1,0,0), Vector3i(1,0,1)],
	# J
	[Vector3i(-1,0,0), Vector3i(0,0,0), Vector3i(1,0,0), Vector3i(-1,0,1)],
	# S
	[Vector3i(0,0,0), Vector3i(1,0,0), Vector3i(0,0,1), Vector3i(-1,0,1)],
	# Z
	[Vector3i(0,0,0), Vector3i(-1,0,0), Vector3i(0,0,1), Vector3i(1,0,1)],
]

func _ready() -> void:
	_rng.randomize()
	spawn_new_piece()

func _physics_process(delta: float) -> void:
	if _locked:
		return
	_fall_accum += delta
	while _fall_accum >= fall_interval:
		_fall_accum -= fall_interval
		_try_move(gravity_dir)

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var step := _cam_step()
	
	if event.keycode == KEY_W:
		_try_move(_rot_y_steps(Vector3i(0, 0, -1), step))
	elif event.keycode == KEY_S:
		_try_move(_rot_y_steps(Vector3i(0, 0, 1), step))
	elif event.keycode == KEY_A:
		_try_move(_rot_y_steps(Vector3i(-1, 0, 0), step))
	elif event.keycode == KEY_D:
		_try_move(_rot_y_steps(Vector3i( 1, 0, 0), step))
	elif event.keycode == KEY_Q:
		if _try_rotate(Vector3i(0, 1, 0), -1): # Y CCW
			_cam_snap_yaw(-1)
	elif event.keycode == KEY_E:
		if _try_rotate(Vector3i(0, 1, 0),  1): # Y CW
			_cam_snap_yaw(1)
	elif event.keycode == KEY_R:
		var d := _clockwise_world_dir()
		_try_rotate(Vector3i(0, 0, 1), d)
	elif event.keycode == KEY_F:
		var d := _clockwise_world_dir()
		_try_rotate(Vector3i(0, 0, 1), -d)
	elif event.keycode == KEY_X:
		_lock_and_spawn()

func _cam_step() -> int:
	if cam and cam.has_method("get_base_yaw_step"):
		return int(cam.call("get_base_yaw_step"))
	return 0

func _rot_y_steps(v: Vector3i, steps: int) -> Vector3i:
	var s := ((steps % 4) + 4) % 4
	var x := v.x
	var z := v.z
	match s:
		0: return v
		1: return Vector3i(z, v.y, -x)     # +90° around Y
		2: return Vector3i(-x, v.y, -z)    # 180°
		3: return Vector3i(-z, v.y, x)     # -90°
		_: return v

func _clockwise_world_dir() -> int:
	# Returns +1 or -1 such that rotating around WORLD +Y by that dir
	# looks "clockwise" from the camera's perspective.

	var cam3d: Camera3D = cam as Camera3D
	if cam3d == null:
		return -1

	var f: Vector3 = -cam3d.global_transform.basis.z # camera forward
	var r: Vector3 =  cam3d.global_transform.basis.x # camera right

	# Project to XZ plane
	f.y = 0.0
	r.y = 0.0
	if f.length() < 0.001 or r.length() < 0.001:
		return -1

	f = f.normalized()
	r = r.normalized()

	# Compare which 90° rotation maps forward closer to right
	var f_plus:  Vector3 = Vector3( f.z, 0.0, -f.x) # +90° around Y
	var f_minus: Vector3 = Vector3(-f.z, 0.0,  f.x) # -90° around Y

	return 1 if f_plus.dot(r) > f_minus.dot(r) else -1

func _cam_snap_yaw(dir: int) -> void:
	# Only works if your Camera script has snap_yaw(dir)
	if cam and cam.has_method("snap_yaw"):
		cam.call("snap_yaw", dir)

func _lock_and_spawn() -> void:
	_locked = true
	emit_signal("locked_in_place")
	call_deferred("spawn_new_piece")

func spawn_new_piece() -> void:
	_fall_accum = 0.0
	_locked = false
	var new_offsets: Array[Vector3i]

	if use_random_pieces:
		var idx := _rng.randi_range(0, PIECES.size() - 1)
		new_offsets = _to_vec3i_array(PIECES[idx])
	else:
		new_offsets = _to_vec3i_array(offsets)
	var new_pivot := spawn_cell
	
	if not _can_place(new_pivot, new_offsets, false):
		_locked = true
		print("GAME OVER: spawn blocked at ", new_pivot)
		return
	
	pivot_cell = new_pivot
	offsets = new_offsets
	_place_piece(pivot_cell, offsets)
	_sync_anchor_to_pivot()
	
func _cell_to_world(c: Vector3i) -> Vector3:
	return gridmap.to_global(gridmap.map_to_local(c))

func _sync_anchor_to_pivot() -> void:
	global_position = _cell_to_world(pivot_cell)

func _to_vec3i_array(raw: Array) -> Array[Vector3i]:
	var out: Array[Vector3i] = []
	out.resize(raw.size())
	for i in raw.size():
		out[i] = raw[i] as Vector3i
	return out

func _try_move(delta: Vector3i) -> bool:
	var target_pivot := pivot_cell + delta
	if not _can_place(target_pivot, offsets, true):
		return false

	_erase_piece(pivot_cell, offsets)
	pivot_cell = target_pivot
	_place_piece(pivot_cell, offsets)
	return true

func _try_rotate(axis: Vector3i, dir: int) -> bool:
	var rotated: Array[Vector3i] = []
	rotated.resize(offsets.size())
	for i in offsets.size():
		rotated[i] = _rot90(offsets[i], axis, dir)

	var kicks: Array[Vector3i] = [
		Vector3i.ZERO,
		Vector3i( 1, 0, 0), Vector3i(-1, 0, 0),
		Vector3i( 0, 0, 1), Vector3i( 0, 0,-1),
		Vector3i( 1, 0, 1), Vector3i( 1, 0,-1),
		Vector3i(-1, 0, 1), Vector3i(-1, 0,-1),
		Vector3i( 0, 1, 0),
	]

	for k in kicks:
		var new_pivot := pivot_cell + k
		if _can_place(new_pivot, rotated, true):
			_erase_piece(pivot_cell, offsets)
			pivot_cell = new_pivot
			offsets = rotated
			_place_piece(pivot_cell, offsets)
			return true
	return false

func _rot90(v: Vector3i, axis: Vector3i, dir: int) -> Vector3i:
	if axis == Vector3i(0, 1, 0):
		if dir > 0:
			return Vector3i(v.z, v.y, -v.x)
		else:
			return Vector3i(-v.z, v.y, v.x)
	elif axis == Vector3i(1, 0, 0):
		if dir > 0:
			return Vector3i(v.x, -v.z, v.y)
		else:
			return Vector3i(v.x, v.z, -v.y)
	elif axis == Vector3i(0, 0, 1):
		if dir > 0:
			return Vector3i(-v.y, v.x, v.z)
		else:
			return Vector3i(v.y, -v.x, v.z)
	return v

func _piece_cells(pivot: Vector3i, offs: Array[Vector3i]) -> Array[Vector3i]:
	var cells: Array[Vector3i] = []
	cells.resize(offs.size())
	for i in offs.size():
		cells[i] = pivot + offs[i]
	return cells

func _can_place(pivot: Vector3i, offs: Array[Vector3i], ignore_current: bool) -> bool:
	var current := {}
	if ignore_current:
		for c in _piece_cells(pivot_cell, offsets):
			current[c] = true
	
	for c in _piece_cells(pivot, offs):
		var occ := gridmap.get_cell_item(c)
		if occ != -1 and not current.has(c):
			return false
	return true

func _place_piece(pivot: Vector3i, offs: Array[Vector3i]) -> void:
	for c in _piece_cells(pivot, offs):
		gridmap.set_cell_item(c, item_id)
	if pivot == pivot_cell:
		_sync_anchor_to_pivot()

func _erase_piece(pivot: Vector3i, offs: Array[Vector3i]) -> void:
	for c in _piece_cells(pivot, offs):
		gridmap.set_cell_item(c, -1)
