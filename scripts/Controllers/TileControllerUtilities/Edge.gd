extends Reference
class_name Edge
"""
Edge class.
Consists of two points, A and B, which describe its line.

It exists solely for another world-related script that constructs Area2Ds based off walkable 'floor' for tilemaps.
Due to this, it also has two booleans, which describe whether the edge has been checked off being added to the Area2D's
CollisionPolygon2D, and whether the edge is an intersection (as opposed to being part of the perimeter). 

Its last variable, tile, describes the coordinates of the edge's corresponding tile in ISOMETRIC space, 
unless the edge is a merged edge, in which case the tile variable will be set to Vector2(INF, INF);
"""

#VARIABLES
var a : Vector2;
var b : Vector2;
var checked : bool = false;
var intersection : bool = false; 
var tile : Vector2;
var tile_side : int;

func print_edge() -> void:
	print(str(a) + ", " + str(b));

"""
Returns the reverse of an edge.
Note that it doesn't change the edge itself.
"""
func get_reverse_edge():
	var reversed_edge = get_script().new();
	reversed_edge.a = self.b;
	reversed_edge.b = self.a;
	reversed_edge.checked = self.checked;
	reversed_edge.intersection = self.intersection;
	reversed_edge.tile = self.tile;
	reversed_edge.tile_side = self.tile_side;
	return reversed_edge;

"""
Returns the extension of this edge extended with another edge.
Only extendable if and only if the two edges share a point.
If extension is not possible, returns this edge, unextended.
"""
func get_extended_edge(edge):
	var extended_edge = get_script().new();
	extended_edge.a = self.a;
	extended_edge.b = self.b;
	extended_edge.checked = self.checked;
	extended_edge.intersection = self.intersection;
	extended_edge.tile = Vector2(INF, INF);
	extended_edge.tile_side = Globals.side.MERGED;
	
	var middle : Vector2;
	
	if (self.a == edge.a or self.a == edge.b):
		middle = self.a;
		var extension = edge.a if edge.b == middle else edge.b;
		extended_edge.a = extension;
		return extended_edge;
	elif (self.b == edge.a or self.b == edge.b):
		middle = self.b;
		var extension = edge.a if edge.b == middle else edge.b;
		extended_edge.b = extension;
		return extended_edge;
	else: #impossible to extend, edges do not share a point.
		return self;

func duplicate():
	var duplicate_edge = get_script().new();
	duplicate_edge.a = self.a;
	duplicate_edge.b = self.b;
	duplicate_edge.checked = self.checked;
	duplicate_edge.intersection = self.intersection;
	duplicate_edge.tile = self.tile;
	duplicate_edge.tile_side = self.tile_side;
	return duplicate_edge;

"""
Checks if two edges are identical.
"""
func is_identical(compare_edge : Edge):
	if (self.a == compare_edge.a && self.b == compare_edge.b):
		return true;
	elif (self.a == compare_edge.b && self.b == compare_edge.a):
		return true;
	return false;
