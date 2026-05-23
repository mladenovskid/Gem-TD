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
# Scroll DOWN → camera moves UP   + steeper angle   (less field of view)
#
# Y never changes from anything except the scroll wheel.
# ---------------------------------------------------------------
@export_group("Zoom Settings")
@export var zoom_speed        : float = 3.0
@export var zoom_y_min        : float = 20.0
@export var zoom_y_max        : float = 200.0
@export var pitch_shallow_deg : float = -15.0
@export var pitch_steep_deg   : float = -60.0

# ---------------------------------------------------------------
# Bounds
# Derived automatically from the "Black Brick" MeshInstance3D at startup.
# bound_margin adds extra world units of padding around the mesh edge
# so the camera can see the map borders without sitting exactly on them.
# ---------------------------------------------------------------
@export_group("Bounds")
@export var bound_margin : float = 5.0   # padding around the mesh edge in world units

# Computed at runtime — not set manually
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
	print("Camera pos: ", global_position)
	print("Camera rotation: ", rotation_degrees)
	print("Starting Y: ", global_position.y)
	print("zoom_y_min: ", zoom_y_min, " zoom_y_max: ", zoom_y_max)

# ---------------------------------------------------------------
# Derive X/Z bounds from the "Black Brick" MeshInstance3D AABB.
# Falls back to hardcoded defaults if the node is not found.
# ---------------------------------------------------------------
func _compute_bounds_from_map() -> void:
	# Walk up to the scene root then find Map/Black Brick
	var root       : Node          = get_tree().root
	var black_brick : MeshInstance3D = _find_node_by_name(root, "Black Brick") as MeshInstance3D

	if black_brick == null:
		push_warning("CameraRig: Could not find 'Black Brick' MeshInstance3D — using default bounds.")
		return

	# get_aabb() returns the local-space bounding box.
	# Multiplying by the global transform gives world-space bounds.
	var aabb       : AABB    = black_brick.get_aabb()
	var world_aabb : AABB    = black_brick.global_transform * aabb

	_x_min = world_aabb.position.x - bound_margin
	_x_max = world_aabb.end.x      + bound_margin
	_z_min = world_aabb.position.z - bound_margin
	_z_max = world_aabb.end.z      + bound_margin

# Recursive depth-first search for a node by name
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
# WASD / Arrow keys — X/Z only, never touches Y
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
# Edge-of-screen pan — X/Z only, never touches Y
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
# Middle-click drag — X/Z only, never touches Y
# ---------------------------------------------------------------
func _handle_drag_pan() -> void:
	if not _dragging:
		return
	var delta_px: Vector2 = get_viewport().get_mouse_position() - _drag_origin
	global_position.x = _rig_origin.x + (-delta_px.x * pan_speed_drag)
	global_position.z = _rig_origin.z + (-delta_px.y * pan_speed_drag)

# ---------------------------------------------------------------
# Zoom: smoothly move Y toward target, adjust pitch to match
# ---------------------------------------------------------------
func _smooth_zoom(delta: float) -> void:
	var new_y: float = lerp(global_position.y, _zoom_target, 12.0 * delta)
	global_position.y = new_y
	_apply_pitch_for_zoom(new_y)

func _apply_pitch_for_zoom(current_y: float) -> void:
	var t: float     = inverse_lerp(zoom_y_min, zoom_y_max, current_y)
	var pitch: float = lerp(pitch_shallow_deg, pitch_steep_deg, t)
	rotation_degrees.x = pitch

# ---------------------------------------------------------------
# Clamp X/Z to map bounds — Y is never clamped here
# ---------------------------------------------------------------
func _clamp_to_bounds() -> void:
	global_position.x = clamp(global_position.x, _x_min, _x_max)
	global_position.z = clamp(global_position.z, _z_min, _z_max)
