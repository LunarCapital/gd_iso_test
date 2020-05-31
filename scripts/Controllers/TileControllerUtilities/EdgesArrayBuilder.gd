extends Node2D
"""
A class that is dedicated to 'building' a 2D array of edges based off a world's tilemaps 
for EACH tilemap.  As such, a dictionary is used to store the edges array 
for each tilemap (AKA floor).

The dictionary takes an array as a key (because tuples don't exist in GDscript) with the format:
{Key: [[tilemap : TileMap, edge_group : int, hole_group : int]] => Value: [EdgeGroup class]}

Additionally:
{Key: [tilemap] => Value: int of edge groups in tilemap}
{Key: [tilemap, edge_group] => Value: int of hole groups in edge group}

Explanation of parameters:
	tilemap : TileMap => refers to the tilemap whose edges we want to look at
	edge_group : int => refers to the tile group 'island'.  
	hole_group => outer and inner edges.  The one outer edge = 0, inner edges are 1 and above.

We need 'groups' (or islands) of edges because a tilemap can have 'groups' of tiles that do not
necessarily touch each other. Say, two 2x2 islands of squares separated by the void.  
They are separate, and thus their edges are separate, and must be put into different groups.

i really wish i knew a better way to document dictionaries, i don't like having a 
3-size array for a dict key (and i'll be using an unholy 5-size array dict key later)
but it's so much cleaner than the previous solution which was a disgusting:
	dict maps tilemap to 2d array, first index is 'edge group', second index is 'tile index'
"""

enum {UNCONNECTED = 0, CONNECTED = 1}

"""
Builds the tilemaps_to_edges dictionary, given an array of all Tilemaps in a scene.
(requires edge_smoother to be passed in so we can use its sorting function.)
"""
func build_edges(tilemaps : Array):
	var tilemap_to_edges: Dictionary = {}; 
	
	for n in range(tilemaps.size()):
		var tilemap = tilemaps[n];
		if (tilemap):	
			var adj_matrix : Array = _init_adj_matrix(tilemap.get_used_cells().size());
			var tiles = _fill_tiles(tilemap, adj_matrix);

			#recursive flood fill to find 'groups' of tiles (by coloring them)
			var color_max = 0;
			for tile in tiles:
				if (tile.color == TilePerimeter.UNCOLORED):
					_flood_fill(adj_matrix, tiles, tile, color_max);
					color_max += 1;
	
			var edge_collections_array : Array = _fill_edges(tiles, color_max);
			tilemap_to_edges[tilemap] = edge_collections_array.size(); #store edge_groups for each tilemap
			
			tilemap_to_edges = _fill_dict_with_edge_collections(tilemap_to_edges, edge_collections_array, tilemap);
			
	return tilemap_to_edges;

###########################
###########################
##UTILITY FUNCTIONS BELOW##
###########################
###########################

"""
Init an empty adjacency matrix.
"""
func _init_adj_matrix(size : int):
	var adj_matrix : Array = [];
	adj_matrix.resize(size);
	for i in range(adj_matrix.size()):
		adj_matrix[i] = [];
		adj_matrix[i].resize(size);
		for j in range(adj_matrix[i].size()):
			adj_matrix[i][j] = UNCONNECTED;
	return adj_matrix;
	
"""
Creates and fills an array based off all the tiles present on a tilemap node
"""
func _fill_tiles(tilemap : TileMap, adj_matrix : Array):
	var tiles : Array = [];
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
			var new_tile_perim = TilePerimeter.new();

			for i in range(vertices.size()): #fill tile perimeters
				var new_edge = Edge.new();
				new_edge.a = vertices[i];
				new_edge.b = vertices[(i+1)%vertices.size()];
				new_edge.tile = Vector2(cell.x, cell.y);
				new_edge.tile_side = (3 - i)%4; #always west edge first. CCW. if you ever decide to use non-square tiles, this will break spectacularly
				new_tile_perim.edges.append(new_edge);

			for i in range(tiles.size()): #fill adjacency matrix
				if (tiles[i].is_tile_adjacent(new_tile_perim)):
					adj_matrix[i][tiles.size()] = CONNECTED;
					adj_matrix[tiles.size()][i] = CONNECTED;

			new_tile_perim.id = tiles.size();
			tiles.append(new_tile_perim);

	return tiles;

"""
Shifts vertices based off some origin.  
"""	
func shift_vertices(tile_vertices : Array, origin : Vector2):
	var vertices = [];
	for vertex in tile_vertices:
		vertices.append(origin + vertex);
	return vertices;

"""
Recursively flood fills tiles, coloring them, to find what group they belong to.
"""
func _flood_fill(adj_matrix : Array, tiles : Array, tile_perim : TilePerimeter, color : int):
	tile_perim.color = color;
	for i in range(adj_matrix[tile_perim.id].size()):
		if (adj_matrix[tile_perim.id][i] == CONNECTED && tiles[i].color == TilePerimeter.UNCOLORED):
			_flood_fill(adj_matrix, tiles, tiles[i], color);

"""
Fills and returns an array that contains all the edges of every tile, 
of every GROUP OF TILES in a single tilemap.
"""
func _fill_edges(tiles : Array, color_max : int) -> Array:
	var edges : Array = [];
	for current_color in range(color_max):
		var edge_collection : EdgeCollection = EdgeCollection.new([]);
		for tile in tiles:
			if (tile.color == current_color):
				for edge in tile.edges:
					var duplicate_edges = _get_duplicate_edges(edge_collection._collection, edge);				
					if (!duplicate_edges):
						edge_collection._collection.append(edge);
					else:
						edge.intersection = true;
						edge_collection._collection.append(edge);
						for duplicate_edge in duplicate_edges:
							duplicate_edge.intersection = true;
		edges.append(edge_collection);
							
	return edges;
	
"""
Given the edge groups from a tilemap, fills the tilemaps_to_edges dictionary with
ordered edge collections.  Also handles donut polygons by splitting an edge group into
the outside and inside edges (and ordering both). 
"""
func _fill_dict_with_edge_collections(tilemap_to_edges : Dictionary, edge_collections_array : Array, tilemap : TileMap) -> Dictionary:
	for i in edge_collections_array.size():	
		var edge_collection : EdgeCollection = edge_collections_array[i];
		var perimeters : Array = []; # array of arrays (of edges), contains perimeters of polygon and ALL holes
		edge_collection.set_collection(edge_collection.get_set_of_collection()); #remove intersections
		var remaining_edges : Array = edge_collection.get_collection().duplicate();
		var sorted_edges : Array = edge_collection.get_ordered_collection();
		
		while (sorted_edges.size() > 0):
			perimeters.append(sorted_edges.duplicate());
			remaining_edges = Functions.set_difference(remaining_edges, perimeters.back());
			var remaining_collection : EdgeCollection = EdgeCollection.new(remaining_edges);
			sorted_edges = remaining_collection.get_ordered_collection();
		
		perimeters.sort_custom(self, "_sort_by_area_descending");
		
		for j in perimeters.size():
			var perimeter : Array = perimeters[j];
			tilemap_to_edges[[tilemap, i, j]] = EdgeCollection.new(perimeter);
		tilemap_to_edges[[tilemap, i]] = perimeters.size();
	
	return tilemap_to_edges;
	
"""
Check some array 'edges' for any duplicates of 'original_edge' and 
returns a new array containing them.
"""
func _get_duplicate_edges(edges : Array, original_edge : Edge) -> Array:
	var duplicate_edges : Array = [];
	for edge in edges:
		if (edge.is_identical(original_edge)):
			duplicate_edges.append(edge);

	return duplicate_edges;

"""
Sorting func for an array of arrays (of edges) that sorts by area size
in descending order.
"""
func _sort_by_area_descending(a : Array, b : Array) -> bool:
	var a_area : float = Functions.get_area_of_polygon(a);
	var b_area : float = Functions.get_area_of_polygon(b);
	
	if (a_area > b_area):
		return true;
	else:
		return false;
