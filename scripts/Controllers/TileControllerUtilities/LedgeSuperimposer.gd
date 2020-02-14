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

func superimpose_ledges(tilemap_to_ledges : Dictionary) -> Dictionary:
	
	#tilemaps_to_ledges[tilemap][superimposed_tilemap] = 3d array of ledges.
	
	#for every tilemap
		#for every superimposed_tilemap of a higher z_index
		
			#var ledges = tilemaps_to_ledges[tilemap][superimposed_tilemap];
			#var superimposed_ledges = new_3d_array(ledges.size());
			#tilemaps_to_ledges[tilemap][superimposed_tilemap] = superimposed_ledges;
			
			#for each edge group
				#var superimposed_ledge_count = 0;
				#for each ledge group 
					#check if ledge is valid.
						#if valid, superimposed_ledges[edge_group][superimposed_ledge_count].append(ledge);
						#else superimposed_ledge_count++;
	
	return tilemap_to_ledges;

###########################
###########################
##UTILITY FUNCTIONS BELOW##
###########################
###########################

func is_ledge_valid() -> bool:
	#get vector2 of tile directly above
	#get vector2 of adjacent tile
	
	#if either exists return false, else return true;

	return false;
