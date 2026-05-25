# build_system.gd
# Autoload as "BuildSystem" in Project > Project Settings > Autoload
# Handles tower placement tracking and selection logic during the build phase.

extends Node

# ---------------------------------------------------------------
# Tower colors mapped to their scene paths
# ---------------------------------------------------------------
const TOWER_COLORS : Dictionary = {
	"blue"   : "res://Scenes/Towers/Tower_Blue.tscn",
	"green"  : "res://Scenes/Towers/Tower_Green.tscn",
	"purple" : "res://Scenes/Towers/Tower_Purple.tscn",
	"red"    : "res://Scenes/Towers/Tower_Red.tscn",
	"yellow" : "res://Scenes/Towers/Tower_Yellow.tscn",
}

const TOWER_TINTS : Dictionary = {
	"blue"   : Color(0.2, 0.4, 1.0),
	"green"  : Color(0.1, 0.9, 0.2),
	"purple" : Color(0.7, 0.1, 1.0),
	"red"    : Color(1.0, 0.1, 0.1),
	"yellow" : Color(1.0, 0.9, 0.0),
}

const MAX_TOWERS      : int = 5
const MAX_TOWER_LEVEL : int = 5

# ---------------------------------------------------------------
# Signals
# ---------------------------------------------------------------
signal build_mode_entered
signal tower_placed(tower_data: Dictionary, tile: Vector2i, tower_node: Node3D)
signal all_towers_placed(placed_towers: Array)
signal tower_selected(tower_data: Dictionary)
signal build_phase_complete

# ---------------------------------------------------------------
# State
# ---------------------------------------------------------------
var current_round    : int  = 1
var build_mode_active: bool = false
var towers_placed    : int  = 0

# Array of { color, level, tile, tower_node }
var placed_towers : Array = []

# The tower the player has chosen to keep
var selected_tower : Dictionary = {}

# Loaded tower scenes cache
var _tower_scenes : Dictionary = {}

# ---------------------------------------------------------------
func _ready() -> void:
	_load_tower_scenes()

func _load_tower_scenes() -> void:
	for color in TOWER_COLORS:
		var path : String = TOWER_COLORS[color]
		if ResourceLoader.exists(path):
			_tower_scenes[color] = load(path)
		else:
			push_warning("BuildSystem: Tower scene missing for color: " + color)

# ---------------------------------------------------------------
# Enter build mode — called by the Build button
# ---------------------------------------------------------------
func enter_build_mode() -> void:
	if build_mode_active:
		return
	build_mode_active = true
	towers_placed     = 0
	placed_towers.clear()
	selected_tower.clear()
	emit_signal("build_mode_entered")
	print("BuildSystem: Build mode ON — place ", MAX_TOWERS, " towers")

# ---------------------------------------------------------------
# Called when the player selects a tower to keep
# ---------------------------------------------------------------
func select_tower(tower_data: Dictionary) -> void:
	selected_tower = tower_data
	emit_signal("tower_selected", tower_data)
	print("BuildSystem: Tower selected → [", tower_data.color, " Lv.", tower_data.level, "]")

# ---------------------------------------------------------------
# Called when the player confirms their tower choice.
# Converts all other placed towers to rock blocks.
# ---------------------------------------------------------------
func confirm_selection() -> void:
	if selected_tower.is_empty():
		push_warning("BuildSystem: No tower selected to confirm.")
		return

	for tower in placed_towers:
		if tower == selected_tower:
			continue  # keep this one as a tower

		var node : Node3D = tower["tower_node"]
		if is_instance_valid(node):
			_apply_stone_material(node)
			GridManager.set_tile(tower["tile"], GridManager.TileState.ROCK)

	GridManager.set_tile(selected_tower["tile"], GridManager.TileState.TOWER)

	build_mode_active = false
	current_round    += 1
	emit_signal("build_phase_complete")
	print("BuildSystem: Build phase complete. Round → ", current_round)

# ---------------------------------------------------------------
# Tower generation — equal 20% chance per color and per level
# ---------------------------------------------------------------
func generate_tower() -> Dictionary:
	var color : String = _roll_tower_color()
	var level : int    = (randi() % MAX_TOWER_LEVEL) + 1
	print("BuildSystem: Generated [", color, " Lv.", level, "]")
	return { "color": color, "level": level }

func _roll_tower_color() -> String:
	const COLOR_TABLE : Array = [
		[ 0,  19, "blue"   ],
		[ 20, 39, "green"  ],
		[ 40, 59, "purple" ],
		[ 60, 79, "red"    ],
		[ 80, 99, "yellow" ],
	]
	var roll : int = randi() % 100
	for entry in COLOR_TABLE:
		if roll >= entry[0] and roll <= entry[1]:
			return entry[2]
	return "blue"

# ---------------------------------------------------------------
# Apply a grey stone material (tower rejected — becomes rock)
# ---------------------------------------------------------------
func _apply_stone_material(node: Node3D) -> void:
	var mat : StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.45, 0.42, 0.40)
	mat.roughness    = 0.9
	mat.metallic     = 0.0
	for mesh in _collect_meshes(node):
		for i in mesh.get_surface_override_material_count():
			mesh.set_surface_override_material(i, mat)

func _collect_meshes(node: Node) -> Array:
	var result : Array = []
	if node is MeshInstance3D:
		result.append(node)
	for child in node.get_children():
		result.append_array(_collect_meshes(child))
	return result

# ---------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------
func get_tower_color(color: String) -> Color:
	return TOWER_TINTS.get(color, Color.WHITE)

func get_tower_scene(color: String) -> PackedScene:
	return _tower_scenes.get(color, null)

func is_build_active() -> bool:
	return build_mode_active

func towers_remaining() -> int:
	return MAX_TOWERS - towers_placed
