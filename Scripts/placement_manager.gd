# placement_manager.gd
extends Node3D

const BLOCK_SCENE_PATH : String = "res://Scenes/Blocks/Block1.tscn"

const TOWER_SCENE_PATHS : Dictionary = {
	"blue"   : "res://Scenes/Towers/Tower_Blue.tscn",
	"green"  : "res://Scenes/Towers/Tower_Green.tscn",
	"purple" : "res://Scenes/Towers/Tower_Purple.tscn",
	"red"    : "res://Scenes/Towers/Tower_Red.tscn",
	"yellow" : "res://Scenes/Towers/Tower_Yellow.tscn",
}

#const TOWER_COLOR_ORDER : Array = ["blue", "green", "purple", "red", "yellow"]

@export var grid_overlay : Node
@export var ground_y     : float = 1.0

enum PlacementType { NONE, TOWER, BLOCK, GEM}

var _mat_valid   : StandardMaterial3D
var _mat_invalid : StandardMaterial3D
var _block_scene  : PackedScene
var _tower_scenes : Dictionary = {}
var _placement_type : PlacementType = PlacementType.NONE
var _ghost          : Node3D        = null
var _hovered_tile   : Vector2i      = Vector2i(-1, -1)
var _can_place      : bool          = false
var _camera         : Camera3D      = null
var _active_color   : String        = "blue"
var _color_index    : int           = 0

func _ready() -> void:
	_build_ghost_materials()
	_load_scenes()
	_camera = get_viewport().get_camera_3d()
	if _camera == null:
		push_error("PlacementManager: No active Camera3D found.")
	BuildSystem.build_mode_entered.connect(_on_build_mode_entered)
	BuildSystem.build_phase_complete.connect(_on_build_phase_complete)
	var hud := get_tree().get_first_node_in_group("hud")
	if hud:
		print("HUD found: ", hud.name)
	else:
		print("HUD NOT found")

func _load_scenes() -> void:
	if ResourceLoader.exists(BLOCK_SCENE_PATH):
		_block_scene = load(BLOCK_SCENE_PATH)
	for color in TOWER_SCENE_PATHS:
		var path : String = TOWER_SCENE_PATHS[color]
		if ResourceLoader.exists(path):
			_tower_scenes[color] = load(path)
	print("PlacementManager: scenes loaded - ", _tower_scenes.keys())

func _process(_delta: float) -> void:
	if _placement_type == PlacementType.NONE:
		return
	_update_ghost()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE and _placement_type != PlacementType.NONE:
			_exit_placement_mode()
		return
	if event is InputEventMouseButton and event.pressed:
		if _placement_type == PlacementType.NONE:
			return
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				if _can_place:
					_confirm_placement(_hovered_tile)
			MOUSE_BUTTON_RIGHT:
				_exit_placement_mode()

func _on_build_mode_entered() -> void:
	_switch_mode(PlacementType.GEM)

func _on_build_phase_complete() -> void:
	_exit_placement_mode()

func _switch_mode(type: PlacementType) -> void:
	var scene : PackedScene
	match type:
		PlacementType.GEM:
			scene = _tower_scenes.get("blue", null)
	if scene == null:
		push_error("PlacementManager: No scene for type: " + str(type))
		return
	_exit_placement_mode(false)
	_placement_type = type
	_spawn_ghost(scene)
	if grid_overlay and grid_overlay.has_method("enter_placement_mode"):
		grid_overlay.enter_placement_mode()

func _exit_placement_mode(cancel_build: bool = true) -> void:
	_placement_type = PlacementType.NONE
	_destroy_ghost()
	if grid_overlay and grid_overlay.has_method("exit_placement_mode"):
		grid_overlay.exit_placement_mode()
	if cancel_build and BuildSystem.is_build_active():
		BuildSystem.build_mode_active  = false
		BuildSystem.towers_placed      = 0
		BuildSystem.placed_towers.clear()
		BuildSystem.selected_tower.clear()
		var hud : Node = get_tree().get_first_node_in_group("hud")
		if hud:
			var btn = hud.get_node_or_null("HUDRoot/BottomBar/BuildButton")
			if btn:
				btn.text     = "Build"
				btn.disabled = false
	print("Placement mode OFF")

func _spawn_ghost(scene: PackedScene) -> void:
	_ghost = scene.instantiate()
	add_child(_ghost)
	_ghost.global_position = Vector3(-9999, ground_y, -9999)
	_apply_ghost_material(_mat_invalid)

func _destroy_ghost() -> void:
	if is_instance_valid(_ghost):
		_ghost.queue_free()
	_ghost        = null
	_hovered_tile = Vector2i(-1, -1)

func _update_ghost() -> void:
	if not is_instance_valid(_ghost) or _camera == null:
		return
	var tile : Vector2i = _raycast_to_tile()
	if tile == _hovered_tile:
		return
	_hovered_tile = tile
	_can_place    = GridManager.is_empty(tile)
	var world_pos : Vector3 = GridManager.grid_to_world(tile)
	_ghost.global_position  = Vector3(world_pos.x, ground_y, world_pos.z)
	_apply_ghost_material(_mat_valid if _can_place else _mat_invalid)

func _confirm_placement(tile: Vector2i) -> void:
	if not GridManager.is_empty(tile):
		return
	match _placement_type:
		PlacementType.GEM:
			_place_tower_in_build_mode(tile)

func _place_tower_in_build_mode(tile: Vector2i) -> void:
	if not BuildSystem.is_build_active():
		return
	var tower_data : Dictionary  = BuildSystem.generate_tower()
	var color      : String      = tower_data.color
	var scene      : PackedScene = BuildSystem.get_tower_scene(color)
	if scene == null:
		push_error("PlacementManager: No scene for tower color: " + color)
		return
	var tower     : Node3D  = scene.instantiate()
	var world_pos : Vector3 = GridManager.grid_to_world(tile)
	get_parent().add_child(tower)
	tower.global_position = Vector3(world_pos.x, ground_y, world_pos.z)
	tower_data["tile"]       = tile
	tower_data["tower_node"] = tower
	BuildSystem.placed_towers.append(tower_data)
	BuildSystem.towers_placed += 1
	GridManager.set_tile(tile, GridManager.TileState.TOWER)
	var hud : Node = get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("update_tower_counter"):
		hud.update_tower_counter(BuildSystem.towers_placed, BuildSystem.MAX_TOWERS)
	print("Tower placed [", color, " Lv.", tower_data.level, "] at ", tile,
		  "  (", BuildSystem.towers_placed, "/", BuildSystem.MAX_TOWERS, ")")
	if BuildSystem.towers_placed >= BuildSystem.MAX_TOWERS:
		BuildSystem.emit_signal("all_towers_placed", BuildSystem.placed_towers)
		_exit_placement_mode()

func _raycast_to_tile() -> Vector2i:
	var mouse     : Vector2 = get_viewport().get_mouse_position()
	var origin    : Vector3 = _camera.project_ray_origin(mouse)
	var direction : Vector3 = _camera.project_ray_normal(mouse)
	var hit       : Vector3 = _intersect_ground(origin, direction, ground_y)
	return GridManager.world_to_grid(hit)

func _intersect_ground(origin: Vector3, direction: Vector3, plane_y: float) -> Vector3:
	if abs(direction.y) < 0.0001:
		return Vector3.ZERO
	var t : float = (plane_y - origin.y) / direction.y
	if t < 0.0:
		return Vector3.ZERO
	return origin + direction * t

func _apply_ghost_material(mat: StandardMaterial3D) -> void:
	if not is_instance_valid(_ghost):
		return
	for mesh in _collect_meshes(_ghost):
		for i in mesh.get_surface_override_material_count():
			mesh.set_surface_override_material(i, mat)

func _collect_meshes(node: Node) -> Array:
	var result : Array = []
	if node is MeshInstance3D:
		result.append(node)
	for child in node.get_children():
		result.append_array(_collect_meshes(child))
	return result

func _build_ghost_materials() -> void:
	_mat_valid = StandardMaterial3D.new()
	_mat_valid.albedo_color               = Color(0.0, 1.0, 0.4, 0.5)
	_mat_valid.transparency               = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat_valid.emission_enabled           = true
	_mat_valid.emission                   = Color(0.0, 0.6, 0.3)
	_mat_valid.emission_energy_multiplier = 1.5
	_mat_invalid = StandardMaterial3D.new()
	_mat_invalid.albedo_color               = Color(1.0, 0.1, 0.1, 0.5)
	_mat_invalid.transparency               = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat_invalid.emission_enabled           = true
	_mat_invalid.emission                   = Color(0.6, 0.0, 0.0)
	_mat_invalid.emission_energy_multiplier = 1.5
