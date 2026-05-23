extends Camera3D

# ---------------------------------------------------------------
# Pan Settings
# ---------------------------------------------------------------
@export_group("Pan Settings")
@export var pan_speed_keys : float = 25.0
@export var pan_speed_edge : float = 25.0
@export var pan_speed_drag : float = 0.35
@export var edge_margin    : int   = 20

# ---------------------------------------------------------------
# Zoom Settings
# ---------------------------------------------------------------
@export_group("Zoom Settings")
@export var zoom_speed    : float = 3.0
@export var zoom_y_min    : float = 10.0
@export var zoom_y_max    : float = 150.0  # camera can now go up to 150m

# Pitch only adjusts between these two Y values — above pitch_lock_y it stays fixed
@export var pitch_y_min   : float = 10.0   # Y where shallowest pitch is applied
@export var pitch_y_max   : float = 80.0   # Y where steepest pitch is applied — locked beyond this

@export var pitch_shallow_deg : float = -25.0
@export var pitch_steep_deg   : float = -65.0

# ---------------------------------------------------------------
# Bounds
# ---------------------------------------------------------------
@export_group("Bounds")
@export var x_min : float = -60.0
@export var x_max : float = 60.0
@export var z_min : float = -15.0
@export var z_max : float =  75.0

# ---------------------------------------------------------------
# Internal state
# ---------------------------------------------------------------
var _zoom_target : float   = 40.0
var _dragging    : bool    = false
var _drag_origin : Vector2 = Vector2.ZERO
var _rig_origin  : Vector3 = Vector3.ZERO

# ---------------------------------------------------------------
func _ready() -> void:
	global_position = Vector3(64.0, 40.0, 0.0)
	_zoom_target    = 40.0
	_apply_pitch_for_zoom(40.0)
	print("Camera start position: ", global_position)
	print("Camera rotation: ", rotation_degrees)

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

# Pitch only responds to Y between pitch_y_min and pitch_y_max.
# Above pitch_y_max the angle locks at pitch_steep_deg and never changes.
func _apply_pitch_for_zoom(current_y: float) -> void:
	var clamped_y : float = clamp(current_y, pitch_y_min, pitch_y_max)
	var t         : float = inverse_lerp(pitch_y_min, pitch_y_max, clamped_y)
	var pitch     : float = lerp(pitch_shallow_deg, pitch_steep_deg, t)
	rotation_degrees.x    = pitch

# ---------------------------------------------------------------
# Clamp X/Z to map bounds — Y is never clamped here
# ---------------------------------------------------------------
func _clamp_to_bounds() -> void:
	global_position.x = clamp(global_position.x, x_min, x_max)
	global_position.z = clamp(global_position.z, z_min, z_max)
