extends Node2D
"""
The unholy:
	DECOMPOSITION OF AN IRREGULAR RECTILINEAR POLYGON WITH HOLES INTO 
	THE MINIMAL SET OF RECTANGLES
	
Credit to: https://nanoexplanations.wordpress.com/2011/12/02/polygon-rectangulation-part-1-minimum-number-of-rectangles/
for the explanation.

This script is dedicated to taking an edge group's perimeter along with all of its
holes' perimeters as an input, breaking the shape up into the minimum number of
rectangles, and returning an array of Area2Ds that represent those rectangles.

Note that it is necessary to transform from isometric coordinates to cartesian
coordinates.
"""

"""
Black box function. Throw in the perimeters of a polygon and its holes, obtain
the perimeters of the minimum number of rectangles the polygon can be broken into.

Note that array_of_isometric_perimeters is an array of arrays of edges, not an array
of EdgeCollections.
"""
func decompose_into_rectangles(array_of_isometric_perimeters : Array) -> Array:
	var array_of_area2Ds : Array = [];
	
	#transform to cartesian coordinates
	var array_of_cartesian_perimeters : Array = _convert_to_cartesian(array_of_isometric_perimeters);
	#run chord-splitting algorithm to get array of arrays (array of perimeters and holes if exist)
	
	#run basic rectangulation on result of previous algo
	#transform all rectangles back to isometric
	#make rectangles into area2Ds
	
	return array_of_area2Ds;

###########################
###########################
##PRIVATE FUNCTIONS BELOW##
###########################
###########################

"""
Converts the coordinates in the input array from isometric to cartesian
coordinates.  The output array no longer contains edges (as they are unneeded
for this script's purpose).
"""
func _convert_to_cartesian(array_of_isometric_perimeters : Array) -> Array:
	var array_of_cartesian_perimeters : Array = [];
	
	for edges in array_of_isometric_perimeters:
		array_of_cartesian_perimeters.append([]);
		for edge in edges:
			var isoX = edge.a.x;
			var isoY = edge.a.y;
			var carteX = isoX + 2*isoY;
			var carteY = 2*isoY - isoX;
			
			array_of_cartesian_perimeters.back().append(Vector2(carteX, carteY));
	
	return array_of_cartesian_perimeters;
