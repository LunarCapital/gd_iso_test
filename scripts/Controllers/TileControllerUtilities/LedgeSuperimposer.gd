extends Node2D
"""
Like the name?  I don't.

This class takes ledges and 'superimposes' them onto tilemaps of higher heights.
Consider a 3x3 island on 0 height level.  It has 12 ledges all around its perimetre.
Now consider that the island has a 1-wide tile pillar up to N height in its centre.  You could,
theoretically, as a player, be on top of the pillar and jump off into the void because the 
3x3's ledges only apply to an entity on the SAME HEIGHT LEVEL.  

Thus we need to take those ledges of the 3x3 island and
apply them to EVERY SINGLE TILEMAP OF HIGHER HEIGHT.  

However, we do not superimpose a ledge to a higher tilemap IF, on the higher tilemap, there is
a tile in one of TWO places: 
	1. Directly above the tile that originally spawned the edge
	2. Or adjacent to the above tile in the DIRECTION THAT THE EDGE IS IN.  I wish I could draw in comments.
	
In this case, the ledge is not applied to the higher tilemap.  Additionally, that same ledge
is also not applied to any tilemaps higher than that one either.
"""

"""
Accepts a tilemaps_to_ledges dictionary with only the BASE ledges for each tilemap filled, 
then fills in the rest by iterating 'upwards'.  

For example, consider a map with three tilemaps of different heights, 0, 1, and 2.
First we superimpose TM0 to TM1 (which we can call TM1_from_0), then superimpose TM1_from_0 to TM2.
Next we superimpose TM1 to TM2.
But wait, we superimposed from TM1 to TM2 twice!  That's because both TM0 and TM1 could have 
ledges that need to be superimposed separately to TM2.
"""
func superimpose_ledges(tilemaps_to_ledges : Dictionary, tilemaps : Array) -> Dictionary:
	for base_tilemap in tilemaps:
		for t in range (base_tilemap.z_index + 1, tilemaps.size()): 
			var superimposed_tilemap = tilemaps[t];
			var predecessor_tilemap = tilemaps[t - 1]; #used to superimpose from TM_predecessor_from_base_tilemap to superimposed_tilemap

			for edge_group in tilemaps_to_ledges[base_tilemap]:
				tilemaps_to_ledges = _superimpose_ledge_groups(tilemaps_to_ledges, base_tilemap, predecessor_tilemap, superimposed_tilemap, edge_group, Globals.DONUT_OUT);
				tilemaps_to_ledges = _superimpose_ledge_groups(tilemaps_to_ledges, base_tilemap, predecessor_tilemap, superimposed_tilemap, edge_group, Globals.DONUT_IN);

	return tilemaps_to_ledges;

###########################
###########################
##PRIVATE FUNCTIONS BELOW##
###########################
###########################

"""
A func called by 'superimpose_ledges()' so it isn't 1 billion lines.  
Goes through ledges via ledge group.  Each iteration, pulls all valid ledges
and then attempts to order them properly.  It is possible that via superimposition
that a ledge group on a lower tilemap becomes multiple ledges groups on a higher 
tilemap if some ledges are invalid (thus 'splitting' the group).
"""
func _superimpose_ledge_groups(	tilemaps_to_ledges : Dictionary, 
								base_tilemap : TileMap,
								predecessor_tilemap : TileMap,
								superimposed_tilemap : TileMap,
								edge_group : int, 
								donut_in_out : String
							) -> Dictionary:
	var superimposed_ledge_group : int = 0; #superimposed tilemap does not necessarily share same ledge groups as predecessor
								
	for ledge_group in tilemaps_to_ledges[[base_tilemap, predecessor_tilemap, edge_group, donut_in_out]]:
		var ledge_collection : EdgeCollection = tilemaps_to_ledges[[base_tilemap, predecessor_tilemap, edge_group, donut_in_out, ledge_group]];
		var valid_ledges : Array = []; 

		for ledge in ledge_collection.get_collection():
			if _is_ledge_valid(ledge, predecessor_tilemap, superimposed_tilemap):
				var superimposed_ledge : Edge = _move_ledge_upwards(ledge);
				if not _has_edge(valid_ledges, superimposed_ledge):
					valid_ledges.append(superimposed_ledge);
				
		# repeatedly run ordered_group on valid_ledges until no ledges are left behind
		while valid_ledges.size() > 0:
			var ordered_ledges : Array = EdgeCollection.new(valid_ledges).get_ordered_collection();
			valid_ledges = Functions.set_difference(valid_ledges, ordered_ledges);
			tilemaps_to_ledges[[base_tilemap, superimposed_tilemap, edge_group, donut_in_out, superimposed_ledge_group]] = EdgeCollection.new(ordered_ledges);
			superimposed_ledge_group += 1;
#
	tilemaps_to_ledges[[base_tilemap, superimposed_tilemap, edge_group, donut_in_out]] = superimposed_ledge_group;	
		
	return tilemaps_to_ledges;


"""
Checks if a ledge when superimposed to a higher layer by checking if the superimposed tilemap has a tile 
either directly above, or directly and adjacent in the ledge direction.  
"""
func _is_ledge_valid(ledge : Edge, ledge_tilemap : TileMap, superimposed_tilemap : TileMap) -> bool:
	var above_tile : Vector2 = Functions.get_above_tile_coords(ledge.tile, ledge_tilemap.z_index, superimposed_tilemap.z_index);
	var adjacent_tile : Vector2 = Functions.get_adjacent_tile_coords(above_tile, ledge.tile_side);
	
	if (superimposed_tilemap.get_cellv(above_tile) == superimposed_tilemap.INVALID_CELL 
			and superimposed_tilemap.get_cellv(adjacent_tile)  == superimposed_tilemap.INVALID_CELL):
		
		return true;
	else:
		return false;
		
"""
Changes the params of an edge so that it is a 'tile' higher.
"""
func _move_ledge_upwards(ledge : Edge) -> Edge:
	var new_ledge : Edge = ledge.duplicate();
	new_ledge.a += Vector2(0, -Globals.TILE_HEIGHT);
	new_ledge.b += Vector2(0, -Globals.TILE_HEIGHT); #these three just change params
	new_ledge.tile += Vector2(-1, -1);
	return new_ledge;

"""
Checks if an array of edges already has the comparison edge.
"""
func _has_edge(array : Array, comparison_edge : Edge) -> bool:
	for edge in array:
		if comparison_edge.is_identical(edge):
			return true;
	return false;
