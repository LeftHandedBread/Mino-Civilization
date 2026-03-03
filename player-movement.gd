extends Node3D

enum Facing { NORTH, EAST, SOUTH, WEST }

@export var step_size := 1.0

var facing: Facing = Facing.NORTH
const FACING_ORDER := [Facing.NORTH, Facing.EAST, Facing.SOUTH, Facing.WEST]

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return

	if event.is_action_pressed("ui_up"):
		# step forward in the direction we're currently facing
		global_position += forward_vector(facing) * step_size

	elif event.is_action_pressed("ui_down"):
		rotation_handler("back")

	elif event.is_action_pressed("ui_left"):
		rotation_handler("left")

	elif event.is_action_pressed("ui_right"):
		rotation_handler("right")


func rotation_handler(key: String) -> void:
	match key:
		"left":
			_set_facing(_turn(facing, -1))   # -1 = 90° left
		"right":
			_set_facing(_turn(facing, +1))   # +1 = 90° right
		"back":
			_set_facing(_turn(facing, +2))   # +2 = 180°


func _turn(current: Facing, steps: int) -> Facing:
	# Enum values are 0..3, so we can wrap with modulo
	var i := int(current)
	i = (i + steps) % 4
	if i < 0:
		i += 4
	return FACING_ORDER[i]


func _set_facing(new_facing: Facing) -> void:
	facing = new_facing

	# Set absolute yaw (recommended) instead of accumulating rotate_object_local
	match facing:
		Facing.NORTH: rotation.y = deg_to_rad(0)
		Facing.EAST:  rotation.y = deg_to_rad(-90)
		Facing.SOUTH: rotation.y = deg_to_rad(180)
		Facing.WEST:  rotation.y = deg_to_rad(90)


func forward_vector(dir: Facing) -> Vector3:
	match dir:
		Facing.NORTH: return Vector3.FORWARD  # (0,0,-1)
		Facing.SOUTH: return Vector3.BACK     # (0,0, 1)
		Facing.EAST:  return Vector3.RIGHT    # (1,0, 0)
		Facing.WEST:  return Vector3.LEFT     # (-1,0,0)
	return Vector3.ZERO
