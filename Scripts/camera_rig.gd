extends Camera3D

# ---------------------------------------------------------------
# Pan Settings
# ---------------------------------------------------------------
@export_group("Pan Settings")
@export var pan_speed_keys : float = 40.0
@export var pan_speed_edge : float = 40.0
@export var pan_speed_drag : float = 0.15
@export var edge_margin    : int   = 10

# ---------------------------------------------------------------
# Zoom Settings
#
# Scroll UP   → camera moves DOWN + shallower angle (more field of view)
# Scroll DOWN → camera moves UP   + steeper angle (less field of view)
#
# Pitch only adjusts between zoom_y_min and pitch_lock_y.
# Above pitch_lock_y the angle stays fixed at pitch_steep_deg.
# Y never changes from anything except the scroll wheel.
# ---------------------------------------------------------------
@export_group("Zoom Settings")
@export var zoom_speed        : float = 3.0
@export var zoom_y_min        : float = 20.0
@export var zoom_y_max        : float = 300.0  # camera can go up to 300m
@export var pitch_lock_y      : float = 100.0  # angle stops changing above this Y
@export var pitch_shallow_deg : float = -15.0
@export var pitch_steep_deg   : float = -75.0

# ---------------------------------------------------------------
# Bounds
# Derived automatically from the "Black Brick" MeshInstance3D at startup.
# ---------------------------------------------------------------
@export_group("Bounds")
@export var bound_margin : float = 5.0

var _x_min : float = 0.0
var _x_max : float = 100.0
var _z_min : float = 0.0
var _z_max : float = 100.0

# ---------------------------------------------------------------
# Internal state
# ---------------------------------------------------------------
var _zoom_target : float   = 80.0
var _dragging    : bool    = false
var _drag_origin : Vector2 = Vector2.ZERO
var _rig_origin  : Vector3 = Vector3.ZERO

# ---------------------------------------------------------------
func _ready() -> void:
	_compute_bounds_from_map()
	_zoom_target = global_position.y
	_apply_pitch_for_zoom(global_position.y)
	print("Camera start position: ", global_position)
	print("Camera bounds — X: [", _x_min, ", ", _x_max, "]  Z: [", _z_min, ", ", _z_max, "]")
	print("Camera rotation: ", rotation_degrees)
	print("zoom_y_min: ", zoom_y_min, "  zoom_y_max: ", zoom_y_max, "  pitch_lock_y: ", pitch_lock_y)

# ---------------------------------------------------------------
func _compute_bounds_from_map() -> void:
	var root        : Node           = get_tree().root
	var black_brick : MeshInstance3D = _find_node_by_name(root, "Black Brick") as MeshInstance3D

	if black_brick == null:
		push_warning("CameraRig: Could not find 'Black Brick' MeshInstance3D — using default bounds.")
		return

	var aabb       : AABB = black_brick.get_aabb()
	var world_aabb : AABB = black_brick.global_transform * aabb

	_x_min = world_aabb.position.x - bound_margin
	_x_max = world_aabb.end.x      + bound_margin
	_z_min = world_aabb.position.z - bound_margin
	_z_max = world_aabb.end.z      + bound_margin

func _find_node_by_name(node: Node, target_name: String) -> Node:
	if node.name == target_name:
		return node
	for child in node.get_children():
		var result : Node = _find_node_by_name(child, target_name)
		if result != null:
			return result
	return null

# ---------------------------------------------------------------
func _process(delta: float) -> void:
	_handle_key_pan(delta)
	_handle_edge_pan(delta)
	_handle_drag_pan()
	_smooth_zoom(delta)
	_clamp_to_bounds()

# ---------------------------------------------------------------
func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton:
		return

	match event.button_index:
		MOUSE_BUTTON_MIDDLE:
			_dragging    = event.pressed
			_drag_origin = event.position
			_rig_origin  = global_position

		MOUSE_BUTTON_WHEEL_UP:
			_zoom_target = clamp(_zoom_target - zoom_speed, zoom_y_min, zoom_y_max)

		MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_target = clamp(_zoom_target + zoom_speed, zoom_y_min, zoom_y_max)

# ---------------------------------------------------------------
func _handle_key_pan(delta: float) -> void:
	var dir := Vector3.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):    dir.z -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):  dir.z += 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):  dir.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): dir.x += 1.0
	if dir != Vector3.ZERO:
		var move: Vector3 = dir.normalized() * pan_speed_keys * delta
		global_position.x += move.x
		global_position.z += move.z

# ---------------------------------------------------------------
func _handle_edge_pan(delta: float) -> void:
	if _dragging:
		return
	var mouse := get_viewport().get_mouse_position()
	var size  := Vector2(get_viewport().get_visible_rect().size)
	var dir   := Vector3.ZERO
	if mouse.x < edge_margin:             dir.x -= 1.0
	elif mouse.x > size.x - edge_margin: dir.x += 1.0
	if mouse.y < edge_margin:            dir.z -= 1.0
	elif mouse.y > size.y - edge_margin: dir.z += 1.0
	if dir != Vector3.ZERO:
		var move: Vector3 = dir.normalized() * pan_speed_edge * delta
		global_position.x += move.x
		global_position.z += move.z

# ---------------------------------------------------------------
func _handle_drag_pan() -> void:
	if not _dragging:
		return
	var delta_px: Vector2 = get_viewport().get_mouse_position() - _drag_origin
	global_position.x = _rig_origin.x + (-delta_px.x * pan_speed_drag)
	global_position.z = _rig_origin.z + (-delta_px.y * pan_speed_drag)

# ---------------------------------------------------------------
func _smooth_zoom(delta: float) -> void:
	var new_y: float = lerp(global_position.y, _zoom_target, 12.0 * delta)
	global_position.y = new_y
	_apply_pitch_for_zoom(new_y)

# Pitch adjusts between zoom_y_min and pitch_lock_y only.
# Above pitch_lock_y the angle is clamped to pitch_steep_deg and never moves.
func _apply_pitch_for_zoom(current_y: float) -> void:
	var clamped_y : float = clamp(current_y, zoom_y_min, pitch_lock_y)
	var t         : float = inverse_lerp(zoom_y_min, pitch_lock_y, clamped_y)
	var pitch     : float = lerp(pitch_shallow_deg, pitch_steep_deg, t)
	rotation_degrees.x    = pitch

# ---------------------------------------------------------------
func _clamp_to_bounds() -> void:
	global_position.x = clamp(global_position.x, _x_min, _x_max)
	global_position.z = clamp(global_position.z, _z_min, _z_max)
