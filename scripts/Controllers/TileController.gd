extends Node2D
"""
A class that builds Area2Ds, walls, and edges for a world based off its tilemaps.

The purpose of each:
	
	Area2D: Used to help check what 'floor' the player is on. 
			Also lets player stand on a floor even if their centre is 'off' the floor.
	Walls: 	Separators between floors of different heights.  
			The bottom of a tile that you cannot pass through.
			EXAMPLE: Think of 3x3 ground floor tiles. In the centre is a 1x1 'first floor' tile.
			If you were on the 3x3 ground floor, you would not be able to walk into the centre 
			because of the four walls in the way.  
	Ledges: Separators between tiles and the void (and the hardest to build).

Should store tilemaps in an array IN ORDER of increasing Z level.
"""
const walkable_area_script = preload("res://scripts/Controllers/TileControllerUtilities/WalkableArea.gd")

#utility nodes
onready var edges_array_builder = $EdgesArrayBuilder;
onready var edge_smoother = $EdgeSmoother

#globals
var tilemaps : Array = [];

#constants
enum {UNCONNECTED = 0, CONNECTED = 1}
const DEFAULT_2D_ARRAY_SIZE : int = 5;

func init(world_children):
	tilemaps.resize(world_children.size());
	fill_tilemaps_array(world_children);
	
	#also init our utility nodes
	edges_array_builder.init(tilemaps);

"""
Iterates through all child nodes of the world and adds tilemaps to the global array.
"""
func fill_tilemaps_array(world_children : Array):
	for child in world_children:
		if (child.get_class() != "TileMap"):
			continue;
			
		tilemaps[child.z_index] = child; #assumes that all tilemaps have differing z-indexes

func setup_world_tiles():
	var tilemaps_to_edges : Dictionary = edges_array_builder.build_edges();
	var tilemaps_to_smoothed_edges : Dictionary = edge_smoother.build_smoothed_edges(tilemaps_to_edges);
	
	create_tilemap_area2d(tilemaps_to_smoothed_edges);
	create_tilemap_walls(tilemaps_to_smoothed_edges);
	var tilemaps_to_ledges : Dictionary = create_tilemap_ledges(tilemaps_to_edges);
	build_tilemap_ledges(tilemaps_to_ledges);
	
	var testbody : StaticBody2D = StaticBody2D.new();
	var testpoly : CollisionPolygon2D = CollisionPolygon2D.new();
	testpoly.build_mode = testpoly.BUILD_SEGMENTS;
	var testpool : PoolVector2Array = [];
	testpool.append(Vector2(0, 0));
	testpool.append(Vector2(64, 0));
	testpool.append(Vector2(64, -32));
	testpool.append(Vector2(64, 0)); 
	testpoly.set_polygon(testpool);
	testbody.add_child(testpoly);
	tilemaps[0].add_child(testbody);
	testbody.set_collision_mask(28);
	#ALL DEBUG

"""
Creates an area2D based off a tilemap's walkable tile areas.
"""
func create_tilemap_area2d(tilemaps_to_smoothed_edges : Dictionary):
	for n in range(tilemaps.size()):
		var tilemap = tilemaps[n];
		if (tilemap):
			var area2d = Area2D.new();
			area2d.name = ("Area" + str(n));
			tilemap.add_child(area2d);
			
			var smoothed_edges : Array = tilemaps_to_smoothed_edges[tilemap]; #THIS IS FOR LOWERWALLS

			for i in range(smoothed_edges.size()): #make collisionpoly2d for each tile group
				var cp2d_area = construct_collision_poly(smoothed_edges[i]); #floor area
				area2d.add_child(cp2d_area);

			area2d.set_script(walkable_area_script);
			area2d.connect("body_entered", area2d, area2d.LISTENER_ON_BODY_ENTERED);
			area2d.connect("body_exited", area2d, area2d.LISTENER_ON_BODY_EXITED);
			area2d.collision_layer = (2);
			area2d.collision_mask = (12);

func create_tilemap_walls(tilemaps_to_smoothed_edges : Dictionary):
	for n in range(tilemaps.size()):
		var tilemap = tilemaps[n];
		if (tilemap):
			var staticbody2d_lowwalls = StaticBody2D.new();
			staticbody2d_lowwalls.name = Globals.STATIC_BODY_WALLS_NAME;
			staticbody2d_lowwalls.set_collision_mask(28);
			tilemap.add_child(staticbody2d_lowwalls);
			
			var smoothed_edges : Array = tilemaps_to_smoothed_edges[tilemap]; #THIS IS FOR LOWERWALLS

			for i in range(smoothed_edges.size()): #make collisionpoly2d for each tile group
				var cp2d_walls = construct_collision_poly(smoothed_edges[i]); #floor edges. NOT lower walls.
				cp2d_walls.build_mode = CollisionPolygon2D.BUILD_SEGMENTS;
				
				if (n > 0): #If we're NOT on the floor layer
					var cp2d_lower_walls = cp2d_walls.duplicate();
					var lower_walls_poly = cp2d_walls.get_polygon();
					for j in range(lower_walls_poly.size()): #shift wall position down to convert from floor edges to lower walls
						lower_walls_poly[j] += Vector2(0, Globals.TILE_HEIGHT);
					cp2d_lower_walls.set_polygon(lower_walls_poly);
					tilemaps[n-1].find_node(Globals.STATIC_BODY_WALLS_NAME, false, false).add_child(cp2d_lower_walls);

"""
Constructs an unholy dictionary that maps tilemaps to ledges, except its a 3D dictionary.
Indexes are: [tilemap][superimposed tilemap][ledges array].  In this function we do not 
worry about the superimposed tilemap index yet.

The ledges array itself is also 3D with the following indexes:
[edge group][ledge group][edge].
Recall that edge groups denote that groups of polygons within the same tilemap can be separated.
Ledge groups in this case denote that groups of LEDGES can be separated too.
For example, a group of 3x3 tiles with four 1x1 tiles on a lower level adjacent to the four 
MIDDLE tiles of each of the 3x3's sides would have EIGHT LEDGES, separated into four groups of 
two ledges each (which would take up the corners). 
"""
func create_tilemap_ledges(tilemaps_to_edges : Dictionary) -> Dictionary:
	var tilemaps_to_ledges : Dictionary = {};
	
	for n in range(tilemaps.size()):
		var tilemap = tilemaps[n];
		if (tilemap):
			var edges = tilemaps_to_edges[tilemap];

			var ledges : Array = Functions.init_3d_array(edges.size());

			#FILL 3D ARRAY OF LEDGES
			for edge_group in edges.size():
				var ledge_group = 0;
				for edge_index in edges[edge_group].size():
					var edge = edges[edge_group][edge_index];
					if (edge.intersection):
						continue;
					
					var current_tile : Vector2 = edge.tile;
					var current_layer = tilemap.z_index;
					var adjacent_tile : Vector2 = current_tile; #will stay equal to current_tile if no adj_tile exists.
					
					for i in range(current_layer - 1, -1, -1):
						var adjacent_coords = get_adjacent_coords(current_tile, current_layer, i, edge.tile_side);
						var lower_tilemap = tilemaps[i];

						if (adjacent_coords != current_tile and 
								lower_tilemap.get_cellv(adjacent_coords) != lower_tilemap.INVALID_CELL):
							adjacent_tile = adjacent_coords;
							break;
							
					if (ledge_group >= ledges[edge_group].size()):
							ledges[edge_group].append([]);
					if (adjacent_tile == current_tile): #AKA NO adj tile exists
						ledges[edge_group][ledge_group].append(edge);
					else:
						if (ledges[edge_group][ledge_group].size() > 0): #finish current ledge group and move to next if there is a 'gap'
							ledge_group += 1;

			tilemaps_to_ledges[tilemap] = {};
			tilemaps_to_ledges[tilemap][tilemap] = ledges; #storing 3d array in 2d dictionary my brain is so big, thankfully nobody will ever see this
	
	return tilemaps_to_ledges;

"""
Constructs the ledges 3d array (and tilemaps_to_ledges dictionary) into usable collisionpolygon2ds.
A separate function because there's so many damn ledge groups.
"""
func build_tilemap_ledges(tilemaps_to_ledges):
	for n in range(tilemaps.size()):
		var tilemap = tilemaps[n];
		if (tilemap):
			
			var staticbody2d_ledges = StaticBody2D.new();
			staticbody2d_ledges.name = Globals.STATIC_BODY_LEDGES_NAME;
			staticbody2d_ledges.set_collision_mask(28);
			tilemap.add_child(staticbody2d_ledges);
			
			var ledges = tilemaps_to_ledges[tilemap][tilemap]; #eventually do for raised tilemaps too

			for i in range(ledges.size()): #edge group
				var ledge_group_array = ledges[i]; #...we cut it down to a 2d array because in my infinite foresight i made the sort function only work on 2d arrays
				
				for j in range(ledge_group_array.size()):
					for k in range(ledge_group_array[j].size()):
						ledge_group_array[j][k].checked = false; #uncheck so sorting can happen again
				
				ledge_group_array = edge_smoother.sort_edges(ledge_group_array);

				for j in range(ledge_group_array.size()): #ledge group
					if (ledge_group_array[j].size() > 0):
						var cp2d_ledges = construct_collision_poly(ledge_group_array[j]);
												
						if (ledge_group_array[j][0].a != ledge_group_array[j][ledge_group_array[j].size() - 1].b): #NOT A LOOP
							cp2d_ledges = make_palindrome(cp2d_ledges); #we do this because godot cannot handle non-loop colliders any other way (that i know of)
							
						cp2d_ledges.build_mode = CollisionPolygon2D.BUILD_SEGMENTS;
						staticbody2d_ledges.add_child(cp2d_ledges);
				

###########################
###########################
##UTILITY FUNCTIONS BELOW##
###########################
###########################

func construct_collision_poly(smoothed_edges : Array):
	var cp2d = CollisionPolygon2D.new();
	cp2d.name = "CollisionPolygon2D";
	var polygon_vertices : PoolVector2Array = [];
	for i in range(smoothed_edges.size()):
		polygon_vertices.append(smoothed_edges[i].a);
		
	if (smoothed_edges[0].a != smoothed_edges[smoothed_edges.size() - 1].b):
		polygon_vertices.append(smoothed_edges[smoothed_edges.size() - 1].b);
		
	cp2d.set_polygon(polygon_vertices);
	
	return cp2d;

func make_palindrome(cp2d : CollisionPolygon2D):
	var polygon_vertices : PoolVector2Array = cp2d.get_polygon();
	var size = polygon_vertices.size();
	
	if (size < 2): #already palindrome
		return cp2d;
	
	for i in range(size - 2, -1, -1):
		polygon_vertices.append(polygon_vertices[i]);
	
	cp2d.set_polygon(polygon_vertices);
	return cp2d;
	
"""
Given some edge's tile and the direction of the edge, attempts to find the coordinates for
the adjacent tile on a given height.  
If the tile side is invalid, returns the coords of the current tile.
"""
func get_adjacent_coords(current_tile : Vector2, current_layer : int, observed_layer : int, tile_side : int) -> Vector2:
	var adjacent_coords : Vector2 = current_tile; 
	var offset : Vector2 = (current_layer - observed_layer) * Vector2.ONE;
	var layer_centre = current_tile + offset;
	
	match tile_side:
		0: #NORTH (top-right)
			adjacent_coords = layer_centre + Vector2(0, -1);
		1: #EAST
			adjacent_coords = layer_centre + Vector2(1, 0);
		2: #SOUTH
			adjacent_coords = layer_centre + Vector2(0, 1);
		3: #WEST
			adjacent_coords = layer_centre + Vector2(-1, 0);
			
	return adjacent_coords;
