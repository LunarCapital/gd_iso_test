extends Node2D
"""
A class dedicated to building 2d arrays of ledges and storing them into a 
dictionary that takes a size 5 tuple as a key.  The dictionary's format:
{Key: [[
	tilemap : TileMap,
	superimposed_tilemap : TileMap,
	edge_group : int,
	hole_group : int,
	ledge_group : int
]] => Value: [EdgeGroup class]}

Additionally:
{Key: [tilemap] => Value: int of edge groups in a tilemap}
{Key: [[tilemap, superimposed_tilemap, edge_group]] => Value: int of hole groups in edge group}

{Key: [[
	tilemap : TileMap,
	superimposed_tilemap : TileMap,
	edge_group : int,
	hole_group : int,
]] => Value: int of ledge groups for this tilemap to superimposed tilemap's edge group}

Explanation of parameters:
	tilemap : TileMap => refers to the tilemap whose edges we want to look at
	superimposed_tilemap : TileMap => refers to the tilemap in which ledges are superimposed to
									  (explanation on this later)
	edge_group : int => refers to the tile group 'island'.  
	hole_group => the inner or outer edges. 0 = polygon perimeter, 1 and above are hole perimeters.
	ledge_group : int => refers to how ledges can be separated (more explanation)

We need 'groups' of ledges because not every edge of a tile group's perimeter may be a ledge.
Consider a 3x3 island with a 5x5 island BELOW it. There are zero ledges in this case
because you can drop down from all sides. Now if we cut the 5x5 island into a 5x3 island
by shaving off two 1x5 rectangles from two opposite sides, we can now only drop down 
the 3x3 island from TWO sides, because the ledges have been split into two groups.  

Ledge superimposition refers to how a ledge on one tilemap needs to be copied and 
'brought up' to all higher tilemaps.  Consider just two tiles, one is much higher
than the other but they are isometrically 'next' to each other so you can fall from
one to the other.  In this case, the higher tile has one ledge that spans 3 out of
its 4 edges, and the lower tile has one ledge that takes up all its edges.  
Without superimposition, there are no ledges between the two, so you could drop
off the higher tile, hold, say, the W key, which moves you south continuously until
you are way out of bounds and far away from the two tiles, then you fall into the void
and the game crashes. 
If, instead, we copied the lower tile's 4-edge-long ledge upwards for all tilemaps 
higher than it, then the player would not be able to fall out of bounds.

Of course, because the lower tile's ledge spans all around it, if we copied it 
upwards it would also block the player from dropping off the higher tile (because
the superimposed tile would be in the way).  Thus, we need to cut off edges from
superimposed ledges that 'touch' tiles on the layer it is superimposed to.

For example, consider two tiles separated by a one tile distance.  Inbetween the 
two is a single tile on a much lower height level, so you could drop off from
EITHER tile and land on the one below.  If we superimposed the lower tile's 4-edge
ledge upwards, it would eventually reach the tilemap containing the two separated tiles.
In this case, two edges would be cut off from the superimposed ledge on opposite sides,
so the one 4-edge ledge would be split into two 1-edge ledges. 

This means that superimposed ledges may have a different ledge group count than
their originals, adding another layer of complexity to this project!

This script's comment is fairly long, confusing, and attempts
to explain what could be done visually very easily, making me wish I could 
draw in comments.  However, I also expect that nobody else on the planet 
will ever read this, and thank god for that because this dictionary is basically
a 5D array with ''''more readable'''' indexes but it's still disgusting and I have
no other choice of data structure.

"""

func build_ledges(tilemaps_to_edges : Dictionary, tilemaps : Array) -> Dictionary:
	var tilemaps_to_ledges : Dictionary = create_tilemap_ledges(tilemaps_to_edges, tilemaps);
	
	#sort all EdgeGroup objects
	for value in tilemaps_to_ledges.values():
		if (value is EdgeCollection):
			value.set_collection(value.get_ordered_collection());
	
	return tilemaps_to_ledges;

"""
Constructs the dictionary described in this script's initial comment.  
In this function we do not worry about the superimposed tilemap index yet.
"""
func create_tilemap_ledges(tilemaps_to_edges : Dictionary, tilemaps : Array) -> Dictionary:
	var tilemaps_to_ledges : Dictionary = {};
	
	for n in range(tilemaps.size()):
		var tilemap = tilemaps[n];
		if (tilemap):
			var edge_groups : int = tilemaps_to_edges[tilemap];
			for i in range(edge_groups): #build edge groups one by one
				var hole_groups : int = tilemaps_to_edges[[tilemap, i]];
				
				var outer_edges : EdgeCollection = tilemaps_to_edges[[tilemap, i, Globals.DONUT_OUT]];
				var inner_edges : EdgeCollection = tilemaps_to_edges[[tilemap, i, Globals.DONUT_IN]];
				
				tilemaps_to_ledges = _fill_ledges_for_edgegroup(	tilemaps_to_ledges, outer_edges, 
																tilemaps, tilemap, i, Globals.DONUT_OUT);
				tilemaps_to_ledges = _fill_ledges_for_edgegroup(	tilemaps_to_ledges, inner_edges, 
																tilemaps, tilemap, i, Globals.DONUT_IN);
			tilemaps_to_ledges[tilemap] = edge_groups;

	return tilemaps_to_ledges;

###########################
###########################
##PRIVATE FUNCTIONS BELOW##
###########################
###########################

"""
Given some EdgeGroup, fills the dictionary tilemaps_to_ledges for that EdgeGroup
following the convention outlined in this class's description.  DOES NOT SUPERIMPOSE.
(That's for later.)
"""
func _fill_ledges_for_edgegroup(	tilemaps_to_ledges : Dictionary, 
								edges : EdgeCollection, 
								tilemaps : Array, 
								tilemap : TileMap, 
								edge_group : int, 
								donut_in_out : String
								)-> Dictionary:
	var ledges : Array = [];
	var ledge_group = 0;

	for edge in edges.get_collection():
		if (edge.intersection): #ignore intersections
			continue;
		
		var current_tile : Vector2 = edge.tile;
		var current_layer = tilemap.z_index;
		var adjacent_tile : Vector2 = _get_adjacent_tile(tilemaps, edge, current_layer);
		# will stay equal to current_tile if no adj_tile exists.
				
		if (adjacent_tile == current_tile): #AKA NO adj tile exists, simply add ledge
			ledges.append(edge);
		else:
			if (ledges.size() > 0): #finish current ledge group and move to next if there is a 'gap'
				tilemaps_to_ledges[[tilemap, tilemap, edge_group, donut_in_out, ledge_group]] = EdgeCollection.new(ledges);
				ledge_group += 1;
				ledges = [];
	
	if (ledges.size() > 0): #store ledges array if not done already
		tilemaps_to_ledges[[tilemap, tilemap, edge_group, donut_in_out, ledge_group]] = EdgeCollection.new(ledges);
		ledge_group += 1;
	
	tilemaps_to_ledges[[tilemap, tilemap, edge_group, donut_in_out]] = ledge_group;
	return tilemaps_to_ledges;

"""
From the current layer, attempts to check if an adjacent tile exists ANY LAYER EQUAL OR BELOW
in some specified direction stored in the Edge class (edge.tile_side).  If no adjacent tile
exists, returns the coordinates of current_tile.
"""
func _get_adjacent_tile( tilemaps : Array, edge : Edge, current_layer : int) -> Vector2:
	var current_tile : Vector2 = edge.tile;
	var adjacent_tile : Vector2 = current_tile;

	for i in range(current_layer - 1, -1, -1): #check for adjacent tiles on same&lower levels
		var adjacent_coords = _get_adjacent_coords(current_tile, current_layer, i, edge.tile_side);
		var lower_tilemap = tilemaps[i];
	
		if 	   (adjacent_coords != current_tile and 
				lower_tilemap.get_cellv(adjacent_coords) != lower_tilemap.INVALID_CELL):
			adjacent_tile = adjacent_coords;
			break; #because we want the 'highest' adjacent tile
		
	return adjacent_tile;

"""
Given some edge's tile and the direction of the edge, attempts to find the coordinates for
the adjacent tile on a given height.  
If the tile side is invalid, returns the coords of the current tile.
"""
func _get_adjacent_coords(current_tile : Vector2, current_layer : int, observed_layer : int, tile_side : int) -> Vector2:
	var above_tile = Functions.get_above_tile_coords(current_tile, current_layer, observed_layer);
	var adjacent_coords = Functions.get_adjacent_tile_coords(above_tile, tile_side);
	
	return adjacent_coords;
