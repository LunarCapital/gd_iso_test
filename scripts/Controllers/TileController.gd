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

Briefly, the stages this script goes through to build these nodes are:
	Uses EdgesArrayBuilder to iterate through tilemaps one by one, and attempts to
	mark the perimeters of the irregular polygons formed by groups of tiles being
	adjacent to each other.  
	These perimeters are used to form Area2Ds that represent floors.
	
	Uses FloorPartitioner to decompose the irregular polygons (that can have holes)
	into the minimum number of rectangles for simpler geometry checks.
	
	Uses LedgesArrayBuilder to decide where to place colliders separating floors
	with the void, avoiding tiles that should allow you to drop off from (onto an
	adjacent tile on a lower Z level).
	
	Uses LedgeSuperimposer to copy and shift ledges upwards so they are valid on
	higher floors too (because entities only interact with colliders on
	the same tilemap.  If we did not superimpose ledges, you would be able to
	drop off from a very high tile, and while falling move 'over' a ledge).
"""
const AREA_SCRIPT : Script = preload("res://scripts/Controllers/TileControllerUtilities/TilemapArea.gd")

#utility nodes
onready var edges_array_builder = $EdgesArrayBuilder;
onready var floor_partitioner = $FloorPartitioner
onready var ledges_array_builder = $LedgesArrayBuilder;
onready var ledge_superimposer = $LedgeSuperimposer;

#globals
var tilemaps : Array = [];

#constants
enum {UNCONNECTED = 0, CONNECTED = 1}
const DEFAULT_2D_ARRAY_SIZE : int = 5;
const WALKABLE_AREA_NAME : String = "Walkable_Area_";
const NEGATIVE_AREA_NAME : String = "Negative_Area_";
const AREA_CP2D_NAME : String = "CP2D_AREA_";
const WALLS_CP2D_NAME : String = "CP2D_WALLS_";

func init(world_children) -> void:
	tilemaps.resize(world_children.size());
	fill_tilemaps_array(world_children);

"""
Iterates through all child nodes of the world and adds tilemaps to the global array.
"""
func fill_tilemaps_array(world_children : Array) -> void:
	for child in world_children:
		if (child.get_class() != "TileMap"):
			continue;
			
		tilemaps[child.z_index] = child; #assumes that all tilemaps have differing z-indexes

func setup_world_tiles() -> void:
	var tilemaps_to_edges : Dictionary = edges_array_builder.build_edges(tilemaps);
	
	create_tilemap_area2d(tilemaps_to_edges, WALKABLE_AREA_NAME);
	create_tilemap_area2d(tilemaps_to_edges, NEGATIVE_AREA_NAME);
	create_tilemap_walls(tilemaps_to_edges);
	
	var tilemaps_to_ledges : Dictionary = ledges_array_builder.build_ledges(tilemaps_to_edges, tilemaps);
	tilemaps_to_ledges = ledge_superimposer.superimpose_ledges(tilemaps_to_ledges, tilemaps);
	create_tilemap_ledges(tilemaps_to_ledges);

"""
Creates an area2D based off a tilemap's walkable tile areas.
"""
func create_tilemap_area2d(tilemaps_to_edges : Dictionary, area_name : String) -> void:
	for n in range(tilemaps.size()):
		var tilemap = tilemaps[n];
		var area2d : Area2D = Area2D.new();
		area2d.name = area_name + str(n);
		tilemap.add_child(area2d);
		
		var edge_groups : int = tilemaps_to_edges[tilemap];

		for i in range(edge_groups): #make collisionpoly2d for each tile group
			var hole_groups : int = tilemaps_to_edges[[tilemap, i]];
			var array_of_perimeters : Array = []; # index 0 is polygon, 1-inf is holes
			for j in range(hole_groups):
				array_of_perimeters.append(tilemaps_to_edges[[tilemap, i, j]].get_smoothed_collection());

			var cp2d_areas_of_rectangle_decomposition : Array = floor_partitioner.decompose_into_rectangles(array_of_perimeters);
			
			var cp2d_area : CollisionPolygon2D =	(construct_collision_poly(tilemaps_to_edges[[tilemap, i, Globals.DONUT_OUT]].get_collection()) 
													if area_name == WALKABLE_AREA_NAME else	
													construct_collision_poly(tilemaps_to_edges[[tilemap, i, Globals.DONUT_IN]].get_collection()));
			cp2d_area.name = (AREA_CP2D_NAME + Globals.DONUT_OUT + "_" + str(i)
							if area_name == WALKABLE_AREA_NAME else
							AREA_CP2D_NAME + Globals.DONUT_IN + "_" + str(i));
							
			area2d.add_child(cp2d_area); # also pass edge group into each cp2d?

		area2d.set_script(AREA_SCRIPT);
		area2d.connect("body_entered", area2d, area2d.LISTENER_ON_BODY_ENTERED);
		area2d.connect("body_exited", area2d, area2d.LISTENER_ON_BODY_EXITED);
		area2d.collision_layer = (2);
		area2d.collision_mask = (12);
		area2d.state = (area2d.WALKABLE if area_name == WALKABLE_AREA_NAME else area2d.NEGATIVE);

"""
Creates walls for each tilemap based off the tilemap 'above' it.
"""
func create_tilemap_walls(tilemaps_to_edges : Dictionary) -> void:
	for n in range(tilemaps.size()):
		var tilemap = tilemaps[n];
		if (tilemap):
			var staticbody2d_walls = StaticBody2D.new();
			staticbody2d_walls.name = Globals.STATIC_BODY_WALLS_NAME;
			staticbody2d_walls.set_collision_mask(28);
			tilemap.add_child(staticbody2d_walls);
			
			if (n == 0):
				continue; #no need to make walls for the floor tilemap
			
			var edge_groups : int = tilemaps_to_edges[tilemap];

			for i in range(edge_groups): #make collisionpoly2d for each tile group
				var cp2d_walls_out : CollisionPolygon2D = build_cp2d_wall_and_shift(tilemaps_to_edges[[tilemap, i, Globals.DONUT_OUT]]);
				cp2d_walls_out.name = WALLS_CP2D_NAME + Globals.DONUT_OUT + "_" + str(i);
				var cp2d_walls_in : CollisionPolygon2D = build_cp2d_wall_and_shift(tilemaps_to_edges[[tilemap, i, Globals.DONUT_IN]]);
				cp2d_walls_in.name = WALLS_CP2D_NAME + Globals.DONUT_IN + "_" + str(i);
				var staticbody2d_target_walls = tilemaps[n-1].find_node(Globals.STATIC_BODY_WALLS_NAME, false, false);
				
				if (staticbody2d_target_walls):
					staticbody2d_target_walls.add_child(cp2d_walls_out);
					staticbody2d_target_walls.add_child(cp2d_walls_in);

"""
Constructs the ledges 3d array (and tilemaps_to_ledges dictionary) into usable collisionpolygon2ds.
A separate function because there's so many damn ledge groups.
"""
func create_tilemap_ledges(tilemaps_to_ledges : Dictionary) -> void:
	for n in range(tilemaps.size() -1, -1, -1):
		var base_tilemap : TileMap = tilemaps[n];
		var staticbody2d_ledges : StaticBody2D = StaticBody2D.new();
		staticbody2d_ledges.name = Globals.STATIC_BODY_LEDGES_NAME;
		staticbody2d_ledges.set_collision_mask(28);
		base_tilemap.add_child(staticbody2d_ledges);
		
		for m in range(base_tilemap.z_index, tilemaps.size()):
			var superimposed_tilemap : TileMap = tilemaps[m];
			var edge_groups : int = tilemaps_to_ledges[base_tilemap];
			
			for i in range(edge_groups):
				var cp2d_ledges_out_array : Array = build_cp2d_ledges(tilemaps_to_ledges, base_tilemap, superimposed_tilemap, i, Globals.DONUT_OUT);
				var cp2d_ledges_in_array : Array = build_cp2d_ledges(tilemaps_to_ledges, base_tilemap, superimposed_tilemap, i, Globals.DONUT_IN);
				
				add_cp2d_ledges_to_staticbodies(cp2d_ledges_out_array, Globals.DONUT_OUT, superimposed_tilemap, n, i);
				add_cp2d_ledges_to_staticbodies(cp2d_ledges_in_array, Globals.DONUT_IN, superimposed_tilemap, n, i);


###########################
###########################
##UTILITY FUNCTIONS BELOW##
###########################
###########################

"""
Prepares a CollisionPolygon2D based off an EdgeGroup's smoothed edges.  
The CP2D is intended not for the tilemap it originates from, but the 
tilemap 'below' it (in height).  As such, the positions of the walls 
are shifted down by Globals.TILE_HEIGHT.
"""
func build_cp2d_wall_and_shift(edge_collection : EdgeCollection) -> CollisionPolygon2D: #void?
	var cp2d_walls : CollisionPolygon2D = construct_collision_poly(edge_collection.get_smoothed_collection());
	cp2d_walls.build_mode = CollisionPolygon2D.BUILD_SEGMENTS;
	
	var walls_poly : PoolVector2Array = cp2d_walls.get_polygon();
	for j in range(walls_poly.size()): #shift wall position down to convert from floor edges to lower walls
		walls_poly[j] += Vector2(0, Globals.TILE_HEIGHT);
	cp2d_walls.set_polygon(walls_poly);

	return cp2d_walls;

"""
Constructs a CollisionPolygon2D based on an array of edges.
"""
func construct_collision_poly(smoothed_edges : Array) -> CollisionPolygon2D:
	var cp2d = CollisionPolygon2D.new();
	cp2d.name = "CollisionPolygon2D";
	var polygon_vertices : PoolVector2Array = [];
	for i in range(smoothed_edges.size()):
		polygon_vertices.append(smoothed_edges[i].a);
		
	if (smoothed_edges.size() == 0):
		return cp2d;
		
	if (smoothed_edges[0].a != smoothed_edges[smoothed_edges.size() - 1].b):
		polygon_vertices.append(smoothed_edges[smoothed_edges.size() - 1].b);
	
	cp2d.set_polygon(polygon_vertices);
	return cp2d;

"""
Builds cp2d ledges for each ledge group in the superimposed tilemap and returns them all in a single array
(to avoid the potentially bad practice of adding them as child nodes to the tilemap nodes in
this function instead of the one that called it)
"""
func build_cp2d_ledges(tilemaps_to_ledges : Dictionary, base_tilemap : TileMap, superimposed_tilemap : TileMap, edge_group : int, donut_in_out : String) -> Array:
	var cp2d_ledges_array : Array = []; # contains ledges cp2d for EACH ledge group within superimposed tilemap
	var ledge_groups : int = tilemaps_to_ledges[[base_tilemap, superimposed_tilemap, edge_group, donut_in_out]];
	
	for j in range(ledge_groups):
		var ledge_collection : EdgeCollection = tilemaps_to_ledges[[base_tilemap, superimposed_tilemap, edge_group, donut_in_out, j]];
		if ledge_collection.get_size() > 0:
			var cp2d_ledges = construct_collision_poly(ledge_collection.get_collection());
			cp2d_ledges.build_mode = CollisionPolygon2D.BUILD_SEGMENTS;
			
			if ledge_collection.get_collection()[0].a != ledge_collection.get_collection()[-1].b:
				cp2d_ledges = make_palindrome(cp2d_ledges);
			
			cp2d_ledges_array.append(cp2d_ledges);
			
	return cp2d_ledges_array;

"""
Given a CollisionPolygon2D, makes its vertices a palindrome. For example,
a CP2D with points [A B C] would become [A B C B A]. This is because
Godot colliders expect its point to form a closed loop, and this is the
only way I can find to make a non-closed loop wall.
"""
func make_palindrome(cp2d : CollisionPolygon2D) -> CollisionPolygon2D:
	var polygon_vertices : PoolVector2Array = cp2d.get_polygon();
	var size = polygon_vertices.size();
	
	if (size < 2): #already palindrome
		return cp2d;
	
	for i in range(size - 2, -1, -1):
		polygon_vertices.append(polygon_vertices[i]);
	
	cp2d.set_polygon(polygon_vertices);
	return cp2d;
	
"""
Iterates through the array of cp2d ledges obtained from build_cp2d_ledges()
and adds them as children to the TileMap node that needs it.  
"""
func add_cp2d_ledges_to_staticbodies(cp2d_ledges_array : Array, donut_in_out : String, superimposed_tilemap : TileMap, base_index : int, edge_group : int) -> void:
	for j in cp2d_ledges_array.size():
		var cp2d_ledges : CollisionPolygon2D = cp2d_ledges_array[j];
		cp2d_ledges.name = "CP2D_LEDGES_" + donut_in_out + "_B:" + str(base_index) + "_EG:" + str(edge_group) + "_LG" + str(j);
		var staticbody2d_superimposed_ledges = superimposed_tilemap.find_node(Globals.STATIC_BODY_LEDGES_NAME, false, false);
		if (staticbody2d_superimposed_ledges):
			staticbody2d_superimposed_ledges.add_child(cp2d_ledges)
