# ActivePiece.gd (Godot 4)
extends Node3D

signal locked_in_place

@export var gridmap_path: NodePath = "../GridMap"
@export var item_id: int = 0

@export var pivot_cell: Vector3i = Vector3i(5, 10, 5)

# Define the piece as offsets from pivot_cell
@export var offsets: Array[Vector3i] = [
	Vector3i(-1, 0, 0),
	Vector3i( 0, 0, 0),
	Vector3i( 1, 0, 0),
	Vector3i( 2, 0, 0),
]

# Playfield bounds (inclusive)
@export var use_bounds := false
@export var min_cell := Vector3i(0, 0, 0)
@export var max_cell := Vector3i(9, 20, 9)

# Gravity
@export var fall_interval := 0.6
@export var gravity_dir: Vector3i = Vector3i(0, -1, 0)

@onready var gridmap: GridMap = get_node(gridmap_path)

var _fall_accum := 0.0
var _locked := false

func _ready() -> void:
	_place_piece(pivot_cell, offsets)

func _physics_process(delta: float) -> void:
	if _locked:
		return

	_fall_accum += delta
	while _fall_accum >= fall_interval:
		_fall_accum -= fall_interval
		if not _try_move(gravity_dir):
			_locked = false
			emit_signal("locked_in_place")
			return

func _unhandled_input(event: InputEvent) -> void:
	if _locked:
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return

	# Movement (arrow keys)
	if event.is_action_pressed("ui_up"):
		_try_move(Vector3i(0, 0, -1))   # forward (-Z)
	elif event.is_action_pressed("ui_down"):
		_try_move(Vector3i(0, 0,  1))   # back (+Z)
	elif event.is_action_pressed("ui_left"):
		_try_move(Vector3i(-1, 0, 0))   # left (-X)
	elif event.is_action_pressed("ui_right"):
		_try_move(Vector3i( 1, 0, 0))   # right (+X)

	# Rotation (direct keycodes so you don't have to add InputMap actions)
	elif event.keycode == KEY_Q:
		_try_rotate(Vector3i(0, 1, 0), -1) # Y CCW
	elif event.keycode == KEY_E:
		_try_rotate(Vector3i(0, 1, 0),  1) # Y CW

	# Optional extra axes for true 3D tetris pieces:
	elif event.keycode == KEY_R:
		_try_rotate(Vector3i(1, 0, 0),  1) # X CW
	elif event.keycode == KEY_F:
		_try_rotate(Vector3i(1, 0, 0), -1) # X CCW
	elif event.keycode == KEY_Z:
		_try_rotate(Vector3i(0, 0, 1),  1) # Z CW
	elif event.keycode == KEY_C:
		_try_rotate(Vector3i(0, 0, 1), -1) # Z CCW

func _try_move(delta: Vector3i) -> bool:
	var target_pivot := pivot_cell + delta
	if not _can_place(target_pivot, offsets):
		return false

	_erase_piece(pivot_cell, offsets)
	pivot_cell = target_pivot
	_place_piece(pivot_cell, offsets)
	return true

func _try_rotate(axis: Vector3i, dir: int) -> bool:
	# dir: +1 or -1 (90 degrees)
	var rotated: Array[Vector3i] = []
	rotated.resize(offsets.size())
	for i in offsets.size():
		rotated[i] = _rot90(offsets[i], axis, dir)

	# Simple wall-kicks: try rotation in place, then tiny shifts
	var kicks: Array[Vector3i] = [
		Vector3i.ZERO,
		Vector3i( 1, 0, 0), Vector3i(-1, 0, 0),
		Vector3i( 0, 0, 1), Vector3i( 0, 0,-1),
		Vector3i( 1, 0, 1), Vector3i( 1, 0,-1),
		Vector3i(-1, 0, 1), Vector3i(-1, 0,-1),
		Vector3i( 0, 1, 0), # small "up" kick (helps near floors/stack)
	]

	for k in kicks:
		var new_pivot := pivot_cell + k
		if _can_place(new_pivot, rotated):
			_erase_piece(pivot_cell, offsets)
			pivot_cell = new_pivot
			offsets = rotated
			_place_piece(pivot_cell, offsets)
			return true

	return false

func _rot90(v: Vector3i, axis: Vector3i, dir: int) -> Vector3i:
	# dir: +1 or -1 (90 degrees)
	# Right-handed grid axes: X right, Y up, Z back

	if axis == Vector3i(0, 1, 0):
		# rotate around Y: (x,z) -> ( z,-x ) or (-z, x)
		if dir > 0:
			return Vector3i(v.z, v.y, -v.x)
		else:
			return Vector3i(-v.z, v.y, v.x)

	elif axis == Vector3i(1, 0, 0):
		# rotate around X: (y,z) -> (-z, y) or (z,-y)
		if dir > 0:
			return Vector3i(v.x, -v.z, v.y)
		else:
			return Vector3i(v.x, v.z, -v.y)

	elif axis == Vector3i(0, 0, 1):
		# rotate around Z: (x,y) -> (-y, x) or (y,-x)
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

func _can_place(pivot: Vector3i, offs: Array[Vector3i]) -> bool:
	# Cells currently occupied by THIS active piece (so we can ignore them during checks)
	var current := {}
	for c in _piece_cells(pivot_cell, offsets):
		current[c] = true

	for c in _piece_cells(pivot, offs):
		if use_bounds and (c.x < min_cell.x or c.y < min_cell.y or c.z < min_cell.z
			or c.x > max_cell.x or c.y > max_cell.y or c.z > max_cell.z):
			return false

		var occ := gridmap.get_cell_item(c)
		if occ != -1 and not current.has(c):
			return false

	return true

func _place_piece(pivot: Vector3i, offs: Array[Vector3i]) -> void:
	for c in _piece_cells(pivot, offs):
		gridmap.set_cell_item(c, item_id)

func _erase_piece(pivot: Vector3i, offs: Array[Vector3i]) -> void:
	for c in _piece_cells(pivot, offs):
		gridmap.set_cell_item(c, -1)
