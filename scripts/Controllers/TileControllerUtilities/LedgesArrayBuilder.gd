extends Node2D
"""
A class dedicated to building 3d arrays of ledges (one per tilemap) with the format:
	ledges[edge_group][ledge_group][ledge]
These arrays are placed in 3d dictionaries with the format:
	tilemaps_to_ledges[tilemap][superimposed_tilemap][ledges]
"""

func build_ledges(tilemaps_to_edges : Dictionary, edge_smoother) -> Dictionary:
	var tilemaps_to_ledges : Dictionary = create_tilemap_ledges(tilemaps_to_edges);
	var tilemaps = tilemaps_to_ledges.keys();
	
	#SORT LEDGES
	for tilemap in tilemaps:
		
		var ledges : Array = tilemaps_to_ledges[tilemap][tilemap];
		
		for edge_group in ledges.size():
			for ledge_group in ledges[edge_group].size():
				var single_ledge_group : Array = ledges[edge_group][ledge_group];
				ledges[edge_group][ledge_group] = edge_smoother.sort_edges(single_ledge_group);
			
		tilemaps_to_ledges[tilemap][tilemap] = ledges;
	
	return tilemaps_to_ledges;

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
	var tilemaps : Array = tilemaps_to_edges.keys();
	
	for n in range(tilemaps.size()):
		var tilemap = tilemaps[n];
		if (tilemap):
			var edges = tilemaps_to_edges[tilemap];
			var ledges : Array = Functions.init_3d_array(edges.size());

			#FILL 3D ARRAY OF LEDGES
			for edge_group in edges.size():
				var ledge_group = 0;
				print("new edge group loop");
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

###########################
###########################
##UTILITY FUNCTIONS BELOW##
###########################
###########################

"""
Given some edge's tile and the direction of the edge, attempts to find the coordinates for
the adjacent tile on a given height.  
If the tile side is invalid, returns the coords of the current tile.
"""
func get_adjacent_coords(current_tile : Vector2, current_layer : int, observed_layer : int, tile_side : int) -> Vector2:
	var above_tile = Functions.get_above_tile_coords(current_tile, current_layer, observed_layer);
	var adjacent_coords = Functions.get_adjacent_tile_coords(above_tile, tile_side);
	
	return adjacent_coords;
