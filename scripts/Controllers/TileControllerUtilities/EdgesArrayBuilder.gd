extends Node2D
"""
A class that is dedicated to 'building' a 2D array of edges based off a world's tilemaps 
for EACH tilemap.  As such, a dictionary is used to store the edges array 
for each tilemap(or floor).

The edge array is 2D because the first index stores the 'group' of edges, while the second
stores the edges themselves (in order, so edges of incrementing indexes will be adjacent in 
cartesian space).

We need 'groups' of edges because a tilemap can have 'groups' of tiles that do not
necessarily touch each other. Say, two 2x2 islands of squares separated by the void.  
They are separate, and thus their edges are separate, and must be put into different groups.

I only write comments with these bootleg examples because i know i'll forget in a few weeks
and have to check 'why is this array 2d again'
"""

var tilemaps : Array = []; #pass in the tilemaps array from TileController
var tilemap_to_edges: Dictionary = {}; 

enum {UNCONNECTED = 0, CONNECTED = 1}

func init(tilemaps):
	self.tilemaps = tilemaps;

func build_edges():
	for n in range(tilemaps.size()):
		var tilemap = tilemaps[n];
		if (tilemap):	

			var adj_matrix : Array = init_adj_matrix(tilemap.get_used_cells().size());
			var polygons = fill_polygons(tilemap, adj_matrix);

			#recursive flood fill to find 'groups' of tiles (by coloring them)
			var color_max = 0;
			for polygon in polygons:
				if (polygon.color == Polygon.UNCOLORED):
					flood_fill(adj_matrix, polygons, polygon, color_max);
					color_max += 1;
	
			var edges : Array = fill_edges(polygons, color_max);
			tilemap_to_edges[tilemap] = edges;
			
	return tilemap_to_edges;

###########################
###########################
##UTILITY FUNCTIONS BELOW##
###########################
###########################

"""
Init an empty adjacency matrix.
"""
func init_adj_matrix(size : int):
	var adj_matrix : Array = [];
	adj_matrix.resize(size);
	for i in range(adj_matrix.size()):
		adj_matrix[i] = [];
		adj_matrix[i].resize(size);
		for j in range(adj_matrix[i].size()):
			adj_matrix[i][j] = UNCONNECTED;
	return adj_matrix;
	
"""
Creates and fills a polygon array based off all the tiles present on a tilemap node
"""
func fill_polygons(tilemap : TileMap, adj_matrix : Array):
	var polygons : Array = [];
	var tileset = tilemap.tile_set;
	var cells = tilemap.get_used_cells();
	for cell in cells:
		var top_point = tilemap.map_to_world(cell);
		var cell_id = tilemap.get_cell(cell.x, cell.y);
		var origin = top_point - Vector2(Globals.TILE_WIDTH/2 , 0) + tileset.tile_get_texture_offset(cell_id);
		var navpoly = tileset.tile_get_navigation_polygon(cell_id);

		if (navpoly):
			#Need to shift tile's vertexes to get its coords in scene space
			var vertices = shift_vertices(navpoly.get_vertices(), origin);
			var new_polygon = Polygon.new();

			for i in range(vertices.size()): #fill polygon edges
				var new_edge = Edge.new();
				new_edge.a = vertices[i];
				new_edge.b = vertices[(i+1)%vertices.size()];
				new_edge.tile = Vector2(cell.x, cell.y);
				new_edge.tile_side = (3 - i)%4; #always west edge first. CCW. if you ever decide to use non-square tiles, this will break spectacularly
				new_polygon.edges.append(new_edge);

			for i in range(polygons.size()): #fill adjacency matrix
				if (polygons[i].is_polygon_adjacent(new_polygon)):
					adj_matrix[i][polygons.size()] = CONNECTED;
					adj_matrix[polygons.size()][i] = CONNECTED;

			new_polygon.id = polygons.size();
			polygons.append(new_polygon);

	return polygons;

"""
Shifts vertices based off some origin.  
"""	
func shift_vertices(tile_vertices : Array, origin : Vector2):
	var vertices = [];
	for vertex in tile_vertices:
		vertices.append(origin + vertex);
	return vertices;

"""
Recursively flood fills tile polygons, coloring them, to find what group they belong to.
"""
func flood_fill(adj_matrix : Array, polygons : Array, polygon : Polygon, color : int):
	polygon.color = color;
	for i in range(adj_matrix[polygon.id].size()):
		if (adj_matrix[polygon.id][i] == CONNECTED && polygons[i].color == Polygon.UNCOLORED):
			flood_fill(adj_matrix, polygons, polygons[i], color);

"""
Fills and returns an array that contains all the edges of every tile polygon, 
of every GROUP OF TILES in a single tilemap.
"""
func fill_edges(polygons : Array, color_max : int):
	var edges : Array = Functions.init_2d_array(color_max);
	for current_color in range(color_max):
		for polygon in polygons:
			if (polygon.color == current_color):
				for edge in polygon.edges:
					var duplicate_edges = get_duplicate_edges(edges[current_color], edge);				
					if (!duplicate_edges):
						edges[current_color].append(edge);
					else:
						edge.intersection = true;
						edges[current_color].append(edge);
						for duplicate_edge in duplicate_edges:
							duplicate_edge.intersection = true;
	return edges;

"""
Returns an array of duplicate edges.
"""
func get_duplicate_edges(edges : Array, original_edge : Edge):
	var duplicate_edges : Array = [];
	for edge in edges:
		if (edge.is_identical(original_edge)):
			duplicate_edges.append(edge);

	return duplicate_edges;
