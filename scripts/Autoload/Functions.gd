extends Node
"""
Autoloaded script.
Contains functions that are useful to have globally.
"""

###########################
###########################
######GENERAL UTILITY######
###########################
###########################

"""
Init an empty 2D array of some size. 
"""
func init_2d_array(size : int):
	var array2d : Array = [];
	array2d.resize(size);
	for i in range(array2d.size()):
		array2d[i] = [];
	return array2d;

"""
Init an empty 3D array of some size. 
"""
func init_3d_array(size : int):
	var array3d : Array = [];
	array3d.resize(size);
	for i in range(array3d.size()):
		array3d[i] = init_2d_array(size);
	return array3d;

###########################
###########################
#######TILE UTILITY########
###########################
###########################

"""
Given some tile coords on a tilemap layer, find the coords of the tile directly above it on an observed layer.
"""
func get_above_tile_coords(current_tile : Vector2, current_layer : int, observed_layer : int) -> Vector2:
	var offset : Vector2 = (current_layer - observed_layer) * Vector2.ONE;
	var tile_above = current_tile + offset;
			
	return tile_above;

"""
Given some tile coords, find the coordinates of the tile directly adjacent to it in a certain direction.
The direction parameter works as follows:
	NORTH = 0
	EAST = 1
	SOUTH = 2
	WEST = 3
If the direction parameter is not applicable, returns the coords of the current tile.
"""
func get_adjacent_tile_coords(current_tile : Vector2, direction : int) -> Vector2:
	var adjacent_coords : Vector2 = current_tile;
	
	match direction:
		Globals.side.NORTH: #(top-right)
			adjacent_coords = current_tile + Vector2(0, -1);
		Globals.side.EAST: 
			adjacent_coords = current_tile + Vector2(1, 0);
		Globals.side.SOUTH: 
			adjacent_coords = current_tile + Vector2(0, 1);
		Globals.side.WEST:
			adjacent_coords = current_tile + Vector2(-1, 0);
			
	return adjacent_coords;
