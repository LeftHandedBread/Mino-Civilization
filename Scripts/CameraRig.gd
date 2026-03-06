extends Camera3D

@export var target_path: NodePath = "../ActivePiece"

# Follow / aim smoothing
@export var follow_speed := 6.0
@export var rotate_speed := 10.0

# Default camera placement relative to target (this is the “snap back” position)
@export var offset := Vector3(0, 10, 14)

# 90° snap rotation feature (persistent)
@export var yaw_step_degrees := 90.0

# RMB drag feature (temporary)
@export var drag_sensitivity := 0.001          # radians per pixel
@export var pitch_limit_degrees := 40.0       # clamp up/down
@export var snap_back_time := 0.15            # seconds
@export var capture_mouse_on_drag := true    # optional

@onready var target: Node3D = get_node(target_path)

var _base_yaw_step := 0            # 0..3 (90° increments)
var _dragging := false
var _drag_yaw := 0.0               # radians
var _drag_pitch := 0.0             # radians
var _snap_tween: Tween

func _unhandled_input(event: InputEvent) -> void:
	# --- RMB drag start/stop ---
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		_dragging = event.pressed

		if _dragging:
			if capture_mouse_on_drag:
				Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
			if _snap_tween and _snap_tween.is_running():
				_snap_tween.kill()
		else:
			if capture_mouse_on_drag:
				Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
			_start_snap_back()

	# --- RMB drag motion ---
	if event is InputEventMouseMotion and _dragging:
		_drag_yaw   -= event.relative.x * drag_sensitivity
		_drag_pitch -= event.relative.y * drag_sensitivity

		var lim := deg_to_rad(pitch_limit_degrees)
		_drag_pitch = clamp(_drag_pitch, -lim, lim)

	# --- 90° snap yaw (pick keys that DON'T conflict with your piece controls) ---
	# I used , and . by default. Change these if you want.
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_COMMA:
			_rotate_base_yaw(-1)
		elif event.keycode == KEY_PERIOD:
			_rotate_base_yaw(1)

func _rotate_base_yaw(dir: int) -> void:
	_base_yaw_step = (_base_yaw_step + dir) % 4

func _start_snap_back() -> void:
	if _snap_tween and _snap_tween.is_running():
		_snap_tween.kill()

	_snap_tween = create_tween()
	_snap_tween.set_trans(Tween.TRANS_SINE)
	_snap_tween.set_ease(Tween.EASE_IN_OUT)
	_snap_tween.tween_method(Callable(self, "_set_drag_yaw"), _drag_yaw, 0.0, snap_back_time)
	_snap_tween.parallel().tween_method(Callable(self, "_set_drag_pitch"), _drag_pitch, 0.0, snap_back_time)

func _set_drag_yaw(v: float) -> void:
	_drag_yaw = v

func _set_drag_pitch(v: float) -> void:
	_drag_pitch = v

func _process(delta: float) -> void:
	if not is_instance_valid(target):
		return

	# --- compute orbit rotation (base snapped yaw + temporary drag yaw/pitch) ---
	var base_yaw := deg_to_rad(_base_yaw_step * yaw_step_degrees)
	var yaw := base_yaw + _drag_yaw
	var pitch := _drag_pitch

	var yaw_basis := Basis(Vector3.UP, yaw)
	var right_axis := yaw_basis * Vector3.RIGHT    # pitch around the yawed right axis
	var pitch_basis := Basis(right_axis, pitch)

	# Apply yaw, then pitch
	var orbit_basis := pitch_basis * yaw_basis
	var desired_pos := target.global_position + orbit_basis * offset

	# --- smooth position ---
	var pt := 1.0 - exp(-follow_speed * delta)
	global_position = global_position.lerp(desired_pos, pt)

	# --- smooth rotation (look at target without being jarring) ---
	var aim_point := target.global_position + Vector3(0, 0.5, 0) # small lift helps
	var desired_basis := Basis.looking_at((aim_point - global_position).normalized(), Vector3.UP)

	var rt := 1.0 - exp(-rotate_speed * delta)
	basis = basis.slerp(desired_basis, rt)
