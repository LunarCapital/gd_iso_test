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
then fills in the rest.
"""
func superimpose_ledges(tilemaps_to_ledges : Dictionary) -> Dictionary:
	
	var tilemaps = tilemaps_to_ledges.keys();
	
	for tilemap in tilemaps:
		for t in range (1, tilemaps.size()):
			var superimposed_tilemap = tilemaps[t];
			var superimposed_tilemap_predecessor = tilemaps[t - 1]; #ALWAYS use this to superimpose to the next tilemap (aka superimposed_tilemap)
			
			if (superimposed_tilemap.z_index <= tilemap.z_index): #ignore tilemaps 'beneath' the current one
				continue;
		
			var ledges : Array = tilemaps_to_ledges[tilemap][superimposed_tilemap_predecessor];
			var superimposed_ledges : Array = Functions.init_3d_array(ledges.size());
			tilemaps_to_ledges[tilemap][superimposed_tilemap] = superimposed_ledges;
			
			for edge_group in ledges.size():
				var superimposed_ledge_count = 0;
				for ledge_group in ledges[edge_group].size():
					for ledge_index in ledges[edge_group][ledge_group].size():
						var ledge : Edge = ledges[edge_group][ledge_group][ledge_index];
						if (is_ledge_valid(ledge, superimposed_tilemap_predecessor, superimposed_tilemap)):
							var superimposed_ledge = ledge.duplicate(); #have to change superimposed ledge coords positions to 'gain' height
							superimposed_ledge.a += Vector2(0, -Globals.TILE_HEIGHT);
							superimposed_ledge.b += Vector2(0, -Globals.TILE_HEIGHT);
							superimposed_ledge.tile += Vector2(-1, -1);
							while (superimposed_ledge_count >= superimposed_ledges[edge_group].size()):
								superimposed_ledges[edge_group].append([]);
							superimposed_ledges[edge_group][superimposed_ledge_count].append(superimposed_ledge);
						else:
							superimposed_ledge_count += 1;
	
	return tilemaps_to_ledges;

###########################
###########################
##UTILITY FUNCTIONS BELOW##
###########################
###########################

"""
Checks if a ledge when superimposed to a higher layer by checking if the superimposed tilemap has a tile 
either directly above, or directly and adjacent in the ledge direction.  
"""
func is_ledge_valid(ledge : Edge, ledge_tilemap : TileMap, superimposed_tilemap : TileMap) -> bool:
	var above_tile : Vector2 = Functions.get_above_tile_coords(ledge.tile, ledge_tilemap.z_index, superimposed_tilemap.z_index);
	var adjacent_tile : Vector2 = Functions.get_adjacent_tile_coords(above_tile, ledge.tile_side);
	
	if (superimposed_tilemap.get_cellv(above_tile) == superimposed_tilemap.INVALID_CELL 
			and superimposed_tilemap.get_cellv(adjacent_tile)  == superimposed_tilemap.INVALID_CELL):
		
		return true;
	else:
		return false;
