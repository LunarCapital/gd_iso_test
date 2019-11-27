extends Reference
class_name Polygon
"""
Polygon class.
Used to describe the 'floor' of a SINGLE tile.  This is done via an array of edges that describe the point-to-point lines
of its perimeter.  
"""

var edges : Array = [];
var color : int = UNCOLORED;
var id : int = -1;

enum {UNCOLORED = -1}

"""
Checks if two polygons share an intersecting edge.
"""
func is_polygon_adjacent(compare_poly : Polygon):
	for edge1 in self.edges:
		for edge2 in compare_poly.edges:
			if (edge1.is_identical(edge2)):
				return true;
	return false;