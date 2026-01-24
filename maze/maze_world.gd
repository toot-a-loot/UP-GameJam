extends Node3D

# Configuration
@export var width: int = 21
@export var height: int = 21
@export var removal_chance: float = 0.1

@onready var grid_map: GridMap = $GridMap

var map_data: Array = []
var astar: AStarGrid2D

# TODO : CONSIDER CHANGING RANDOMIZATION ALGORITHM
# TODO : IMPLEMENT WALL AND FLOOR MESH CODE IN render_to_gridmap()

func _ready():
	# Initialize map with all walls
	for x in range(width):
		var col = []
		for y in range(height):
			col.append(1)
		map_data.append(col)

	# Generate maze	
	randomize()
	generate_recursive_backtracker()
	
	# Add loops (multiple paths)
	add_loops()
	
	# Render to 3D
	render_to_gridmap()
	
	# Setup A* for optimal path
	setup_astar()
	
	# Print the distance
	var start = Vector2i(1, 1)
	var end = Vector2i(width - 2, height - 2)
	var path = get_optimal_path(start, end)
	print("Optimal Path Length: ", path.size())

func generate_recursive_backtracker():	
	var current = Vector2i(1, 1)
	map_data[current.x][current.y] = 0
	
	var stack: Array[Vector2i] = []
	stack.append(current)
	
	while stack.size() > 0:
		current = stack.back()
		var neighbors = get_unvisited_neighbors(current)
		
		if neighbors.size() > 0:
			var next_cell = neighbors.pick_random()
			
			# Remove wall between current and next
			var wall_to_remove = current + (next_cell - current) / 2
			map_data[wall_to_remove.x][wall_to_remove.y] = 0
			map_data[next_cell.x][next_cell.y] = 0
			
			stack.append(next_cell)
		else:
			stack.pop_back()

func get_unvisited_neighbors(cell: Vector2i) -> Array[Vector2i]:
	var list: Array[Vector2i] = []
	# Check 2 steps away in each direction
	var directions = [Vector2i(0, 2), Vector2i(0, -2), Vector2i(2, 0), Vector2i(-2, 0)]
	
	for dir in directions:
		var neighbor = cell + dir
		# Check bounds
		if neighbor.x > 0 and neighbor.x < width - 1 and neighbor.y > 0 and neighbor.y < height - 1:
			# Check if it is still a wall
			if map_data[neighbor.x][neighbor.y] == 1:
				list.append(neighbor)
	return list

func add_loops():
	# Iterate through the inner walls and randomly remove some
	for x in range(1, width - 1):
		for y in range(1, height - 1):
			if map_data[x][y] == 1:
				# Ensure we don't remove structural pillars
				if randf() < removal_chance:
					map_data[x][y] = 0

func count_floor_neighbors(cell: Vector2i) -> int:
	var count = 0
	var dirs = [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]
	for d in dirs:
		var check = cell + d
		if map_data[check.x][check.y] == 0:
			count += 1
	return count

# VISUALIZATION
func render_to_gridmap():
	grid_map.clear()
	for x in range(width):
		for y in range(height):
			if map_data[x][y] == 1:
				# Set wall mesh 
				grid_map.set_cell_item(Vector3i(x, 0 , y), 0)
			else:
				# Set floor mesh
				grid_map.set_cell_item(Vector3i(x, 0, y), 1)
	
# PATHFINDING
func setup_astar():
	astar = AStarGrid2D.new()
	astar.region = Rect2i(0, 0, width, height)
	astar.cell_size = Vector2(1, 1)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	astar.update()
	
	for x in range(width):
		for y in range(height):
			astar.set_point_solid(Vector2i(x, y), map_data[x][y] == 1)
		
func get_optimal_path(start: Vector2i, end: Vector2i) -> PackedVector2Array:
	return astar.get_id_path(start, end)
