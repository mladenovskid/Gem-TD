# gem_system.gd
# Autoload as "GemSystem" in Project > Project Settings > Autoload
# Handles gem generation, placement tracking, and selection logic.

extends Node

# ---------------------------------------------------------------
# Gem colors mapped to their tower scene paths
# ---------------------------------------------------------------
const GEM_COLORS : Dictionary = {
	"blue"   : "res://Scenes/Towers/Tower_Blue.tscn",
	"green"  : "res://Scenes/Towers/Tower_Green.tscn",
	"purple" : "res://Scenes/Towers/Tower_Purple.tscn",
	"red"    : "res://Scenes/Towers/Tower_Red.tscn",
	"yellow" : "res://Scenes/Towers/Tower_Yellow.tscn",
}

const GEM_TINTS : Dictionary = {
	"blue"   : Color(0.2, 0.4, 1.0),
	"green"  : Color(0.1, 0.9, 0.2),
	"purple" : Color(0.7, 0.1, 1.0),
	"red"    : Color(1.0, 0.1, 0.1),
	"yellow" : Color(1.0, 0.9, 0.0),
}

const MAX_GEMS      : int = 5
const MAX_GEM_LEVEL : int = 5

# ---------------------------------------------------------------
# Signals
# ---------------------------------------------------------------
signal build_mode_entered
signal gem_placed(gem_data: Dictionary, tile: Vector2i, tower_node: Node3D)
signal all_gems_placed(placed_gems: Array)
signal gem_selected(gem_data: Dictionary)
signal build_phase_complete

# ---------------------------------------------------------------
# State
# ---------------------------------------------------------------
var current_round    : int   = 1
var build_mode_active: bool  = false
var gems_placed      : int   = 0

# Array of { color, level, tile, tower_node }
var placed_gems : Array = []

# The gem the player has chosen to keep
var selected_gem : Dictionary = {}

# Loaded tower scenes cache
var _tower_scenes : Dictionary = {}

# ---------------------------------------------------------------
func _ready() -> void:
	_load_tower_scenes()

func _load_tower_scenes() -> void:
	for color in GEM_COLORS:
		var path : String = GEM_COLORS[color]
		if ResourceLoader.exists(path):
			_tower_scenes[color] = load(path)
		else:
			push_warning("GemSystem: Tower scene missing for color: " + color)

# ---------------------------------------------------------------
# Enter build mode — called by the Build button
# ---------------------------------------------------------------
func enter_build_mode() -> void:
	if build_mode_active:
		return
	build_mode_active = true
	gems_placed       = 0
	placed_gems.clear()
	selected_gem.clear()
	emit_signal("build_mode_entered")
	print("GemSystem: Build mode ON — place ", MAX_GEMS, " towers")

# ---------------------------------------------------------------
# Called by PlacementManager when the player clicks a valid tile
# Returns the generated gem data so PlacementManager can spawn it
# ---------------------------------------------------------------
func place_gem(tile: Vector2i, tower_node: Node3D) -> Dictionary:
	if not build_mode_active or gems_placed >= MAX_GEMS:
		return {}

	var gem : Dictionary = _generate_gem()
	gem["tile"]        = tile
	gem["tower_node"]  = tower_node

	placed_gems.append(gem)
	gems_placed += 1

	emit_signal("gem_placed", gem, tile, tower_node)
	print("GemSystem: Gem placed [", gem.color, " Lv.", gem.level, "] at ", tile,
		  "  (", gems_placed, "/", MAX_GEMS, ")")

	if gems_placed >= MAX_GEMS:
		emit_signal("all_gems_placed", placed_gems)
		print("GemSystem: All 5 gems placed — choose one to keep")

	return gem

# ---------------------------------------------------------------
# Called when the player clicks a gem orb to select it
# ---------------------------------------------------------------
func select_gem(gem_data: Dictionary) -> void:
	selected_gem = gem_data
	emit_signal("gem_selected", gem_data)
	print("GemSystem: Gem selected → [", gem_data.color, " Lv.", gem_data.level, "]")

# ---------------------------------------------------------------
# Called when the player confirms their gem choice
# Converts all other placed gems to rock blocks
# ---------------------------------------------------------------
func confirm_selection() -> void:
	if selected_gem.is_empty():
		push_warning("GemSystem: No gem selected to confirm.")
		return

	for gem in placed_gems:
		if gem == selected_gem:
			continue  # keep this one as a tower

		# Convert to rock block — swap the tower node's material to stone
		var node : Node3D = gem["tower_node"]
		if is_instance_valid(node):
			_apply_stone_material(node)
			GridManager.set_tile(gem["tile"], GridManager.TileState.ROCK)

	# Mark the selected gem's tile as a tower
	GridManager.set_tile(selected_gem["tile"], GridManager.TileState.TOWER)

	build_mode_active = false
	current_round    += 1
	emit_signal("build_phase_complete")
	print("GemSystem: Build phase complete. Round → ", current_round)

# ---------------------------------------------------------------
# Gem generation — equal chance per color, equal chance per level
# ---------------------------------------------------------------
func _generate_gem() -> Dictionary:
	var colors : Array  = GEM_COLORS.keys()
	var color  : String = colors[randi() % colors.size()]
	var level  : int    = (randi() % MAX_GEM_LEVEL) + 1
	return { "color": color, "level": level }

# ---------------------------------------------------------------
# Apply a grey stone material to a tower node (gem rejected)
# ---------------------------------------------------------------
func _apply_stone_material(node: Node3D) -> void:
	var mat : StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color     = Color(0.45, 0.42, 0.40)
	mat.roughness        = 0.9
	mat.metallic         = 0.0
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
func get_gem_color(color: String) -> Color:
	return GEM_TINTS.get(color, Color.WHITE)

func get_tower_scene(color: String) -> PackedScene:
	return _tower_scenes.get(color, null)

func is_build_active() -> bool:
	return build_mode_active

func gems_remaining() -> int:
	return MAX_GEMS - gems_placed
