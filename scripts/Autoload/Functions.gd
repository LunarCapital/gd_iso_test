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
func init_2d_array(size : int) -> Array:
	var array2d : Array = [];
	array2d.resize(size);
	for i in range(array2d.size()):
		array2d[i] = [];
	return array2d;

"""
Init an empty 3D array of some size. 
"""
func init_3d_array(size : int) -> Array:
	var array3d : Array = [];
	array3d.resize(size);
	for i in range(array3d.size()):
		array3d[i] = init_2d_array(size);
	return array3d;

"""
Returns an array containing objects that 
appear in the ORIGINAL array but not the COMPARISON array.
"""
func set_difference(original_array : Array, comparison_array : Array) -> Array:
	var difference_array : Array = [];
	for element in original_array:
		if (!comparison_array.has(element)):
			difference_array.append(element);
	return difference_array;

"""
Returns an array containing objects that
appear in both the ORIGINAL array AND the COMPARISON array.
"""
func set_and(original_array : Array, comparison_array : Array) -> Array:
	var and_array : Array = [];
	for element in original_array:
		if comparison_array.has(element):
			and_array.append(element);
	return and_array;

###########################
###########################
#####GEOMETRY UTILITY######
###########################
###########################

"""
Finds the area of a polygon, regular or irregular.  
Requires input 'polygon' to be an array of 
Edges which are sorted in order.
"""
func get_area_of_polygon(polygon : Array) -> float:
	var area : float = 0;
	for edge in polygon:
		area += (edge.b.x * edge.a.y - edge.b.y * edge.a.x);
	area = abs(area/2);
	return area;

"""
Runs line-line algo on two lines.  *_a and *_b are the first and second points of 
line *, respectively.
"""
func line_line(line1_a : Vector2, line1_b : Vector2, line2_a : Vector2, line2_b : Vector2) -> bool:
	if (line1_a == line2_a and line1_b == line2_b) or (line1_a == line2_b and line1_b == line2_a):
		return true; # same line
	
	var x1 : float = line1_a.x;
	var y1 : float = line1_a.y;
	var x2 : float = line1_b.x;
	var y2 : float = line1_b.y;
	var x3 : float = line2_a.x;
	var y3 : float = line2_a.y;
	var x4 : float = line2_b.x;
	var y4 : float = line2_b.y;
	
	var uA : float = 0;
	var uB : float = 0;

	if ((y4-y3)*(x2-x1) - (x4-x3)*(y2-y1)) == 0:
		uA = INF;
		uB = INF;
	else:
		uA = ((x4-x3)*(y1-y3) - (y4-y3)*(x1-x3)) / ((y4-y3)*(x2-x1) - (x4-x3)*(y2-y1));
		uB = ((x2-x1)*(y1-y3) - (y2-y1)*(x1-x3)) / ((y4-y3)*(x2-x1) - (x4-x3)*(y2-y1));
		
	if (uA >= 0 && uA <= 1 && uB >= 0 && uB <= 1):
		return true;
	else:
		return false;	
	

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
