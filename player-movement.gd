# ActivePiece.gd (Godot 4)
extends Node3D

@onready var gridmap_path = $"../GridMap"
@export var item_id: int = 0              # MeshLibrary item index for your cube/block
@export var pivot_cell: Vector3i = Vector3i(5, 10, 5)

# Offsets (relative to pivot) that define the current piece shape.
# Example: a simple 4-block "I" piece along X:
@export var offsets: Array[Vector3i] = [
	Vector3i(-1, 0, 0),
	Vector3i( 0, 0, 0),
	Vector3i( 1, 0, 0),
	Vector3i( 2, 0, 0),
]

# Optional playfield bounds (inclusive). Turn off by setting use_bounds = false.
@export var use_bounds := true
@export var min_cell := Vector3i(0, 0, 0)
@export var max_cell := Vector3i(9, 20, 9)

@onready var gridmap: GridMap = get_node(gridmap_path)

func _ready() -> void:
	_place_piece(pivot_cell)

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return

	if event.is_action_pressed("ui_up"):
		try_move(Vector3i(0, 0, -1))   # forward (-Z)
	elif event.is_action_pressed("ui_down"):
		try_move(Vector3i(0, 0,  1))   # back (+Z)
	elif event.is_action_pressed("ui_left"):
		try_move(Vector3i(-1, 0, 0))   # left (-X)
	elif event.is_action_pressed("ui_right"):
		try_move(Vector3i( 1, 0, 0))   # right (+X)

func try_move(delta: Vector3i) -> void:
	var target_pivot := pivot_cell + delta
	if not _can_place(target_pivot):
		return

	_erase_piece(pivot_cell)
	pivot_cell = target_pivot
	_place_piece(pivot_cell)

func _piece_cells(pivot: Vector3i) -> Array[Vector3i]:
	var cells: Array[Vector3i] = []
	cells.resize(offsets.size())
	for i in offsets.size():
		cells[i] = pivot + offsets[i]
	return cells

func _can_place(pivot: Vector3i) -> bool:
	var current := {}
	for c in _piece_cells(pivot_cell):
		current[c] = true

	for c in _piece_cells(pivot):
		if use_bounds and (c.x < min_cell.x or c.y < min_cell.y or c.z < min_cell.z
			or c.x > max_cell.x or c.y > max_cell.y or c.z > max_cell.z):
			return false

		var occ := gridmap.get_cell_item(c)
		# allow overlapping our *current* cells (since we erase after validation)
		if occ != -1 and not current.has(c):
			return false

	return true

func _place_piece(pivot: Vector3i) -> void:
	for c in _piece_cells(pivot):
		gridmap.set_cell_item(c, item_id)

func _erase_piece(pivot: Vector3i) -> void:
	for c in _piece_cells(pivot):
		gridmap.set_cell_item(c, -1)
