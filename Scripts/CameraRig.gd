extends Camera3D

@export var target_path: NodePath = "../ActivePiece"
@export var follow_speed := 1.0
@export var rotate_speed := 5.0
@export var offset := Vector3(0, 10, 14)

@onready var target: Node3D = get_node(target_path)

func _process(delta: float) -> void:
	if not is_instance_valid(target):
		return

	# --- smooth position ---
	var desired_pos := target.global_position + offset
	var pt := 1.0 - exp(-follow_speed * delta)
	global_position = global_position.lerp(desired_pos, pt)

	# --- smooth rotation (smooth look_at) ---
	var desired_basis := Basis.looking_at(
		(target.global_position - global_position).normalized(),
		Vector3.UP
	)
	var rt := 1.0 - exp(-rotate_speed * delta)
	basis = basis.slerp(desired_basis, rt)
