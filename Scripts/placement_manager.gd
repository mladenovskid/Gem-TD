# placement_manager.gd
# Attach to a Node3D called "PlacementManager" in your Main scene.
#
# Dependencies:
#   - GridManager registered as Autoload
#   - GemSystem registered as Autoload
#
# Controls (test):
#   - T key        → enter tower placement mode (cycles colors)
#   - B key        → enter block placement mode
#   - Left click   → confirm placement
#   - Right click  → cancel
#   - Escape       → cancel

extends Node3D

const BLOCK_SCENE_PATH : String = "res://Scenes/Blocks/Block1.tscn"

const TOWER_SCENE_PATHS : Dictionary = {
	"blue"   : "res://Scenes/Towers/Tower_Blue.tscn",
	"green"  : "res://Scenes/Towers/Tower_Green.tscn",
	"purple" : "res://Scenes/Towers/Tower_Purple.tscn",
	"red"    : "res://Scenes/Towers/Tower_Red.tscn",
	"yellow" : "res://Scenes/Towers/Tower_Yellow.tscn",
}

const TOWER_COLOR_ORDER : Array = ["blue", "green", "purple", "red", "yellow"]

@export var grid_overlay : Node
@export var ground_y     : float = 1.0

enum PlacementType { NONE, TOWER, BLOCK, GEM }

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

# ---------------------------------------------------------------
func _ready() -> void:
	_build_ghost_materials()
	_load_scenes()
	_camera = get_viewport().get_camera_3d()
	if _camera == null:
		push_error("PlacementManager: No active Camera3D found.")

	GemSystem.build_mode_entered.connect(_on_build_mode_entered)
	GemSystem.build_phase_complete.connect(_on_build_phase_complete)

	var hud := get_tree().get_first_node_in_group("hud")
	if hud:
		print("HUD found: ", hud.name)
	else:
		print("HUD NOT found — check group is set to 'hud'")

func _load_scenes() -> void:
	if ResourceLoader.exists(BLOCK_SCENE_PATH):
		_block_scene = load(BLOCK_SCENE_PATH)

	for color in TOWER_SCENE_PATHS:
		var path : String = TOWER_SCENE_PATHS[color]
		if ResourceLoader.exists(path):
			_tower_scenes[color] = load(path)

	print("PlacementManager: scenes loaded — ", _tower_scenes.keys())

# ---------------------------------------------------------------
func _process(_delta: float) -> void:
	if _placement_type == PlacementType.NONE:
		return
	_update_ghost()

# ---------------------------------------------------------------
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_T:
				if _placement_type == PlacementType.TOWER:
					_color_index  = (_color_index + 1) % TOWER_COLOR_ORDER.size()
					_active_color = TOWER_COLOR_ORDER[_color_index]
					_destroy_ghost()
					_spawn_ghost(_tower_scenes[_active_color])
					print("Tower color → ", _active_color.to_upper())
				else:
					_switch_mode(PlacementType.TOWER)
				return
			KEY_B:
				_switch_mode(PlacementType.BLOCK)
				return
			KEY_ESCAPE:
				if _placement_type != PlacementType.NONE:
					_exit_placement_mode()
				return

	if _placement_type == PlacementType.NONE:
		return

	if event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				if _can_place:
					_confirm_placement(_hovered_tile)
			MOUSE_BUTTON_RIGHT:
				_exit_placement_mode()

# ---------------------------------------------------------------
# GemSystem callbacks
# ---------------------------------------------------------------
func _on_build_mode_entered() -> void:
	_switch_mode(PlacementType.GEM)

func _on_build_phase_complete() -> void:
	_exit_placement_mode()

# ---------------------------------------------------------------
func _switch_mode(type: PlacementType) -> void:
	if _placement_type == type and type == PlacementType.BLOCK:
		_exit_placement_mode()
		return

	var scene : PackedScene
	match type:
		PlacementType.TOWER:
			_active_color = TOWER_COLOR_ORDER[_color_index]
			scene = _tower_scenes.get(_active_color, null)
		PlacementType.BLOCK:
			scene = _block_scene
		PlacementType.GEM:
			scene = _tower_scenes.get("blue", null)

	if scene == null:
		push_error("PlacementManager: No scene for type: " + str(type))
		return

	_exit_placement_mode()
	_placement_type = type
	_spawn_ghost(scene)

	if grid_overlay and grid_overlay.has_method("enter_placement_mode"):
		grid_overlay.enter_placement_mode()

func _exit_placement_mode() -> void:
	_placement_type = PlacementType.NONE
	_destroy_ghost()
	if grid_overlay and grid_overlay.has_method("exit_placement_mode"):
		grid_overlay.exit_placement_mode()

# ---------------------------------------------------------------
# Ghost
# ---------------------------------------------------------------
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

# ---------------------------------------------------------------
# Confirm placement
# ---------------------------------------------------------------
func _confirm_placement(tile: Vector2i) -> void:
	if not GridManager.is_empty(tile):
		return

	match _placement_type:
		PlacementType.GEM:
			_place_gem(tile)
		PlacementType.TOWER:
			_place_named_tower(tile, _active_color)
		PlacementType.BLOCK:
			_place_block(tile)

func _place_gem(tile: Vector2i) -> void:
	if not GemSystem.is_build_active():
		return

	var gem_data  : Dictionary  = GemSystem._generate_gem()
	var color     : String      = gem_data.color
	var scene     : PackedScene = GemSystem.get_tower_scene(color)

	if scene == null:
		push_error("PlacementManager: No scene for gem color: " + color)
		return

	var tower     : Node3D  = scene.instantiate()
	var world_pos : Vector3 = GridManager.grid_to_world(tile)
	get_parent().add_child(tower)
	tower.global_position = Vector3(world_pos.x, ground_y, world_pos.z)

	gem_data["tile"]       = tile
	gem_data["tower_node"] = tower
	GemSystem.placed_gems.append(gem_data)
	GemSystem.gems_placed += 1

	GridManager.set_tile(tile, GridManager.TileState.TOWER)

	var hud : Node = get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("update_gem_counter"):
		hud.update_gem_counter(GemSystem.gems_placed, GemSystem.MAX_GEMS)

	print("Gem placed [", color, " Lv.", gem_data.level, "] at ", tile,
		  "  (", GemSystem.gems_placed, "/", GemSystem.MAX_GEMS, ")")

	if GemSystem.gems_placed >= GemSystem.MAX_GEMS:
		GemSystem.emit_signal("all_gems_placed", GemSystem.placed_gems)
		_exit_placement_mode()

func _place_named_tower(tile: Vector2i, color: String) -> void:
	var scene : PackedScene = _tower_scenes.get(color, null)
	if scene == null:
		return
	var tower     : Node3D  = scene.instantiate()
	var world_pos : Vector3 = GridManager.grid_to_world(tile)
	get_parent().add_child(tower)
	tower.global_position = Vector3(world_pos.x, ground_y, world_pos.z)
	GridManager.set_tile(tile, GridManager.TileState.TOWER)
	print("Tower [", color.to_upper(), "] placed → grid: ", tile)

func _place_block(tile: Vector2i) -> void:
	if _block_scene == null:
		return
	var block     : Node3D  = _block_scene.instantiate()
	var world_pos : Vector3 = GridManager.grid_to_world(tile)
	get_parent().add_child(block)
	block.global_position = Vector3(world_pos.x, ground_y, world_pos.z)
	GridManager.set_tile(tile, GridManager.TileState.ROCK)
	print("Block placed → grid: ", tile)

# ---------------------------------------------------------------
# Raycast
# ---------------------------------------------------------------
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

# ---------------------------------------------------------------
# Ghost materials
# ---------------------------------------------------------------
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
