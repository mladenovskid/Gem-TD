# grid_manager.gd
# Autoload this as "GridManager" in Project > Project Settings > Autoload
# Tracks the state of every tile on the 33x33 grid.
# Map is 264x264 metres, each tile is 8x8 metres.

extends Node

# --- Grid Configuration ---
const GRID_WIDTH  := 33    # number of tiles along X (264 / 8)
const GRID_HEIGHT := 33    # number of tiles along Z (264 / 8)
const TILE_SIZE   := 8.0   # each tile is 8x8 metres

# Tile states
enum TileState {
	EMPTY,
	TOWER,
	ROCK,
	PATH,
	SPAWN,
	CASTLE,
	CHECKPOINT,
}

# Internal grid storage: grid[x][z] = TileState
var grid: Array = []

# ---------------------------------------------------------------
func _ready() -> void:
	_init_grid()

# Fills every tile with EMPTY on startup
func _init_grid() -> void:
	grid.clear()
	for x in range(GRID_WIDTH):
		var column: Array = []
		for z in range(GRID_HEIGHT):
			column.append(TileState.EMPTY)
		grid.append(column)
	print("GridManager ready — ", GRID_WIDTH, "x", GRID_HEIGHT, " tiles at ", TILE_SIZE, "m each")

# ---------------------------------------------------------------
# Coordinate helpers
# ---------------------------------------------------------------

# Convert a world position (Vector3) to grid coords (Vector2i)
func world_to_grid(world_pos: Vector3) -> Vector2i:
	var gx : int = int(floor(world_pos.x / TILE_SIZE))
	var gz : int = int(floor(world_pos.z / TILE_SIZE))
	gx = clamp(gx, 0, GRID_WIDTH  - 1)
	gz = clamp(gz, 0, GRID_HEIGHT - 1)
	return Vector2i(gx, gz)

# Convert grid coords to the world-space centre of that tile
func grid_to_world(grid_pos: Vector2i) -> Vector3:
	var wx : float = (grid_pos.x + 0.5) * TILE_SIZE
	var wz : float = (grid_pos.y + 0.5) * TILE_SIZE
	return Vector3(wx, 0.0, wz)

# Snap any world position to the nearest tile centre
func snap_to_grid(world_pos: Vector3) -> Vector3:
	return grid_to_world(world_to_grid(world_pos))

# ---------------------------------------------------------------
# Tile state queries and setters
# ---------------------------------------------------------------

func is_valid_coord(grid_pos: Vector2i) -> bool:
	return (grid_pos.x >= 0 and grid_pos.x < GRID_WIDTH
		and grid_pos.y >= 0 and grid_pos.y < GRID_HEIGHT)

func get_tile(grid_pos: Vector2i) -> TileState:
	if not is_valid_coord(grid_pos):
		return TileState.ROCK
	return grid[grid_pos.x][grid_pos.y]

func set_tile(grid_pos: Vector2i, state: TileState) -> void:
	if is_valid_coord(grid_pos):
		grid[grid_pos.x][grid_pos.y] = state

func is_empty(grid_pos: Vector2i) -> bool:
	return get_tile(grid_pos) == TileState.EMPTY
