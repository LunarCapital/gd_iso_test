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
onready var ledges_array_builder = $LedgesArrayBuilder;
onready var ledge_superimposer = $LedgeSuperimposer;

#globals
var tilemaps : Array = [];

#constants
enum {UNCONNECTED = 0, CONNECTED = 1}
const DEFAULT_2D_ARRAY_SIZE : int = 5;

func init(world_children):
	tilemaps.resize(world_children.size());
	fill_tilemaps_array(world_children);

"""
Iterates through all child nodes of the world and adds tilemaps to the global array.
"""
func fill_tilemaps_array(world_children : Array):
	for child in world_children:
		if (child.get_class() != "TileMap"):
			continue;
			
		tilemaps[child.z_index] = child; #assumes that all tilemaps have differing z-indexes

func setup_world_tiles():
	var tilemaps_to_edges : Dictionary = edges_array_builder.build_edges(tilemaps);
	var tilemaps_to_smoothed_edges : Dictionary = edge_smoother.build_smoothed_edges(tilemaps_to_edges);
	
	create_tilemap_area2d(tilemaps_to_smoothed_edges);
	create_tilemap_walls(tilemaps_to_smoothed_edges);
	var tilemaps_to_ledges : Dictionary = ledges_array_builder.build_ledges(tilemaps_to_edges, edge_smoother);
	tilemaps_to_ledges = ledge_superimposer.superimpose_ledges(tilemaps_to_ledges);
	build_tilemap_ledges(tilemaps_to_ledges);

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
Constructs the ledges 3d array (and tilemaps_to_ledges dictionary) into usable collisionpolygon2ds.
A separate function because there's so many damn ledge groups.
"""
func build_tilemap_ledges(tilemaps_to_ledges):
	for n in range(tilemaps.size() -1, -1, -1):
		var tilemap = tilemaps[n];
		if (tilemap):
			
			var staticbody2d_ledges = StaticBody2D.new();
			staticbody2d_ledges.name = Globals.STATIC_BODY_LEDGES_NAME;
			staticbody2d_ledges.set_collision_mask(28);
			tilemap.add_child(staticbody2d_ledges);
			
			for m in range(tilemap.z_index, tilemaps.size() -1):
				var tilemap_m = tilemaps[m]; #wanted to call this superimposed_tilemap but doesn't make sense for when tilemap_m = tilemap
				var ledges = tilemaps_to_ledges[tilemap][tilemap_m];
	
				for i in range(ledges.size()): #edge group
					var ledge_group_array = ledges[i]; 
	
					for j in range(ledge_group_array.size()): #ledge group
						if (ledge_group_array[j].size() > 0):
							var cp2d_ledges = construct_collision_poly(ledge_group_array[j]);
													
							if (ledge_group_array[j][0].a != ledge_group_array[j][ledge_group_array[j].size() - 1].b): #NOT A LOOP
								cp2d_ledges = make_palindrome(cp2d_ledges); #we do this because godot cannot handle non-loop colliders any other way (that i know of)
								
							cp2d_ledges.build_mode = CollisionPolygon2D.BUILD_SEGMENTS;
							
							if (tilemap == tilemap_m):
								staticbody2d_ledges.add_child(cp2d_ledges);
							else:
								var staticbody2d_superimposed_ledges = tilemap_m.find_node(Globals.STATIC_BODY_LEDGES_NAME, false, false);
								if (staticbody2d_superimposed_ledges):
									staticbody2d_superimposed_ledges.add_child(cp2d_ledges);
				

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
	
