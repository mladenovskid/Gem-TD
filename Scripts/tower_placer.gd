# tower_placer.gd
# Attach this script to a Node3D in your main scene.
# It handles clicking to place Tower_Template on valid grid tiles.
#
# Requirements:
#   - GridManager is registered as an Autoload
#   - Your main Camera3D is in a group called "main_camera"
#     (or assign it directly via the @export below)
#   - Tower_Template.glb (or a .tscn wrapping it) is in res://Blender/

extends Node3D

# ---------------------------------------------------------------
# Exports — set these in the Godot Inspector
# ---------------------------------------------------------------
@export var tower_scene: PackedScene                    # drag Tower_Template.glb here
@export var camera: Camera3D                            # drag your Camera3D here
@export var ground_plane_y: float = 0.0                 # Y height of your ground plane

# ---------------------------------------------------------------
# Internal state
# ---------------------------------------------------------------
var _ghost: Node3D = null          # semi-transparent preview tower
var _ghost_tile: Vector2i = Vector2i(-1, -1)
var _can_place: bool = false

# Materials for the ghost preview
var _mat_ok:  StandardMaterial3D
var _mat_bad: StandardMaterial3D

# ---------------------------------------------------------------
func _ready() -> void:
	_build_ghost_materials()
	_spawn_ghost()

# ---------------------------------------------------------------
# Every frame: raycast from mouse → snap ghost to grid → colour it
# ---------------------------------------------------------------
func _process(_delta: float) -> void:
	if camera == null or _ghost == null:
		return

	var mouse_pos := get_viewport().get_mouse_position()
	var tile := _raycast_to_tile(mouse_pos)

	if tile != _ghost_tile:
		_ghost_tile = tile
		_can_place   = GridManager.is_empty(tile)
		# Move ghost to tile centre, keep it slightly above ground
		_ghost.global_position = GridManager.grid_to_world(tile) + Vector3(0, 0.01, 0)
		_apply_ghost_material(_can_place)

# ---------------------------------------------------------------
# Left-click to place, right-click to cancel
# ---------------------------------------------------------------
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				if _can_place:
					_place_tower(_ghost_tile)
			MOUSE_BUTTON_RIGHT:
				pass  # future: cancel / deselect

# ---------------------------------------------------------------
# Place the real tower, mark the tile occupied
# ---------------------------------------------------------------
func _place_tower(tile: Vector2i) -> void:
	if not GridManager.is_empty(tile):
		return

	var tower: Node3D = tower_scene.instantiate()
	get_parent().add_child(tower)
	tower.global_position = GridManager.grid_to_world(tile)

	# Mark tile as occupied
	GridManager.set_tile(tile, GridManager.TileState.TOWER)

	print("Tower placed at grid %s  world %s" % [tile, tower.global_position])

# ---------------------------------------------------------------
# Raycast helpers
# ---------------------------------------------------------------

# Cast a ray from the camera through the mouse position.
# Returns the grid tile the ray hits on the ground plane.
func _raycast_to_tile(mouse_pos: Vector2) -> Vector2i:
	var ray_origin    := camera.project_ray_origin(mouse_pos)
	var ray_direction := camera.project_ray_normal(mouse_pos)

	# Intersect with the horizontal ground plane (y = ground_plane_y)
	var hit: Vector2i := _intersect_ground_plane(ray_origin, ray_direction, ground_plane_y)
	if hit == null:
		return Vector2i(0, 0)   # ray is parallel to ground — return origin tile

	return GridManager.world_to_grid(hit)

# Returns the Vector3 intersection of a ray with a horizontal plane at height y,
# or null if the ray is parallel to the plane.
func _intersect_ground_plane(origin: Vector3, direction: Vector3, plane_y: float):
	if abs(direction.y) < 0.0001:
		return null
	var t := (plane_y - origin.y) / direction.y
	if t < 0:
		return null   # intersection is behind the camera
	return origin + direction * t

# ---------------------------------------------------------------
# Ghost (preview) tower
# ---------------------------------------------------------------
func _spawn_ghost() -> void:
	if tower_scene == null:
		push_warning("TowerPlacer: tower_scene is not set in the Inspector.")
		return
	_ghost = tower_scene.instantiate()
	add_child(_ghost)
	_apply_ghost_material(false)

func _apply_ghost_material(valid: bool) -> void:
	if _ghost == null:
		return
	var mat := _mat_ok if valid else _mat_bad
	# Apply to every MeshInstance3D in the ghost hierarchy
	for mesh in _get_all_meshes(_ghost):
		for i in mesh.get_surface_override_material_count():
			mesh.set_surface_override_material(i, mat)

func _get_all_meshes(node: Node) -> Array:
	var result: Array = []
	if node is MeshInstance3D:
		result.append(node)
	for child in node.get_children():
		result.append_array(_get_all_meshes(child))
	return result

func _build_ghost_materials() -> void:
	_mat_ok = StandardMaterial3D.new()
	_mat_ok.albedo_color       = Color(0.2, 1.0, 0.2, 0.45)   # green tint
	_mat_ok.transparency       = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat_ok.flags_no_depth_test = false

	_mat_bad = StandardMaterial3D.new()
	_mat_bad.albedo_color       = Color(1.0, 0.15, 0.15, 0.45) # red tint
	_mat_bad.transparency       = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat_bad.flags_no_depth_test = false
