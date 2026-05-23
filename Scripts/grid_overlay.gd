# grid_overlay.gd
# Attach to a MeshInstance3D (flat QuadMesh or PlaneMesh covering 100x100 map)
# sitting just above the ground plane (Y = 0.01).
#
# This script:
#   - Updates the shader cursor position every frame via raycasting
#   - Smoothly fades the grid in/out when placement mode changes
#   - Exposes enter_placement_mode() / exit_placement_mode() for other systems to call

extends MeshInstance3D

# ---------------------------------------------------------------
# Settings
# ---------------------------------------------------------------
@export var camera          : Camera3D           # drag your Camera3D here
@export var fade_speed      : float = 4.0        # how fast the grid fades in/out
@export var ground_y        : float = 0.0        # Y height of the ground plane

# ---------------------------------------------------------------
# Internal state
# ---------------------------------------------------------------
var _in_placement_mode : bool  = false
var _target_opacity    : float = 0.0
var _current_opacity   : float = 0.0
var _shader_mat        : ShaderMaterial

# ---------------------------------------------------------------
func _ready() -> void:
	# Grab the ShaderMaterial so we can set uniforms
	_shader_mat = material_override as ShaderMaterial
	if _shader_mat == null:
		push_error("GridOverlay: material_override must be a ShaderMaterial using grid_overlay.gdshader")
		return

	# Start fully invisible
	_shader_mat.set_shader_parameter("grid_opacity", 0.0)

# ---------------------------------------------------------------
func _process(delta: float) -> void:
	if _shader_mat == null:
		return

	# Smoothly animate opacity toward target
	_current_opacity = move_toward(_current_opacity, _target_opacity, fade_speed * delta)
	_shader_mat.set_shader_parameter("grid_opacity", _current_opacity)

	# Only update cursor position while visible (saves raycasting when hidden)
	if _current_opacity > 0.001:
		_update_cursor_position()

# ---------------------------------------------------------------
# Call this when the player enters tower/rock placement mode
# ---------------------------------------------------------------
func enter_placement_mode() -> void:
	_in_placement_mode = true
	_target_opacity    = 1.0

# ---------------------------------------------------------------
# Call this when placement mode ends (wave starts, cancel, etc.)
# ---------------------------------------------------------------
func exit_placement_mode() -> void:
	_in_placement_mode = false
	_target_opacity    = 0.0

# ---------------------------------------------------------------
# Raycast mouse → ground plane → pass world pos to shader
# ---------------------------------------------------------------
func _update_cursor_position() -> void:
	if camera == null:
		return

	var mouse_pos  : Vector2 = get_viewport().get_mouse_position()
	var ray_origin : Vector3 = camera.project_ray_origin(mouse_pos)
	var ray_dir    : Vector3 = camera.project_ray_normal(mouse_pos)

	var hit : Vector3 = _intersect_ground(ray_origin, ray_dir, ground_y)
	_shader_mat.set_shader_parameter("cursor_world_pos", hit)

# ---------------------------------------------------------------
func _intersect_ground(origin: Vector3, direction: Vector3, plane_y: float) -> Vector3:
	if abs(direction.y) < 0.0001:
		return Vector3.ZERO
	var t : float = (plane_y - origin.y) / direction.y
	if t < 0.0:
		return Vector3.ZERO
	return origin + direction * t
