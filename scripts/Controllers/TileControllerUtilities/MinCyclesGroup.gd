extends Reference
class_name MinCyclesGroup
"""
A class related to MinCyclesGraph.
Stores a 'group' of nodes that are connected to each other in MinCyclesGraph 
(which is found via DFS).  
"""

#CONSTANTS
const SORT_FUNC = "_sort_by_area_descending";

#VARIABLES
var nodes : Array = []; # stores the group as NODE IDs (not their Vector2s).
var perim : Array = []; # stores the group's outer perim as node IDs.
var area : float = 0;

func _init(node_group : Array, adj_matrix : Array, vertices_id_map : Dictionary):
	nodes = node_group;
	perim = _fill_perim(nodes, adj_matrix, vertices_id_map);
	area = _calc_area(perim, vertices_id_map);
	
	
"""
Given an input of connected groups, finds their perimeters and returns them
as an Array that stores the group IDs in order.
Returned array stored as:
	group_perim = [0 3 1 5] or something. Vertices are CCW order.
Method is as follows:
	1. get node with smallest x. if multiple exist, pick node with smallest y.
	2. define bearing as being in the negative Y direction as there are no 
		available nodes in that direction
	3. out of valid edges from current node, pick the one with the least positive
		CCW angle change from the bearing
	4. new bearing = direction from NEW node TO OLD node
	5. repeat until we get back to start node
"""
func _fill_perim(local_nodes : Array, adj_matrix : Array, vertices_id_map : Dictionary) -> Array:
	var group_perim : Array = [];
	var start_node : int = local_nodes.min(); # nodes are sorted by minx then miny so this lowest index = start. christ for weakly typed script min() is dangerous thsi makes me very nerovus
	var bearing : Vector2 = Vector2(0, -1);
	var current_node : int = start_node;
	while current_node != start_node and group_perim.size() > 1: # you see if we had do->while loops i wouldn't need the 2nd condition
		var neighbours : Array = adj_matrix[current_node];
		var valid_neighbours : Array = Functions.set_and(neighbours, local_nodes); # ensure we only choose neighbours that are also in the same group
		var next_neighbour : int  = _choose_next_neighbour(current_node, bearing, valid_neighbours, vertices_id_map);
		bearing = (vertices_id_map[next_neighbour] - vertices_id_map[current_node]).normalized();
		group_perim.append(current_node);
		current_node = next_neighbour;	
	return group_perim;

"""
A function used to draw the perimeter of a bunch of edges (and vertices).  Given
the current node, bearing (for direction) and a list of its valid neighbours, 
picks the 'next' neighbour which is the one with the LEAST positive CCW angle
change from the bearing.  Excludes angle of 0 degrees because that means we'd
just be going back to the previous node.

This ensures that given multiple valid neighbours we always pick the 'outermost'
one.
"""
func _choose_next_neighbour(current_node, bearing, valid_neighbours, vertices_id_map) -> int:
	var min_angle : float = 360;
	var current_solution : int = valid_neighbours[0];
	for neighbour in valid_neighbours:
		var neighbour_direction : Vector2 = vertices_id_map[neighbour] - vertices_id_map[current_node];
		neighbour_direction = neighbour_direction.normalized();
		var angle_diff : float = abs(rad2deg(atan2(bearing.y, bearing.x) - atan2(neighbour_direction.y, neighbour_direction.x))); # get angle difference CCW 
		if angle_diff < min_angle:
			min_angle = angle_diff;
			current_solution = neighbour;
	
	return current_solution;

"""
Calculates the area of the node groups outer perimeter.
"""
func _calc_area(local_perim : Array, vertices_id_map : Dictionary) -> float:
	var poly_of_edges : Array = [];
	for i in range(local_perim.size()):
		var a : Vector2 = local_perim[i-1];
		var b : Vector2 = local_perim[i];
		var edge : Edge = Edge.new();
		poly_of_edges.append(edge);
	return Functions.get_area_of_polygon(poly_of_edges);
		

"""
Sorts an array of MinCycleGroups based on area in descending order.
"""
func _sort_by_area_descending(var a : MinCyclesGroup, var b : MinCyclesGroup) -> bool:
	if a.area > b.area:
		return true;
	else:
		return false;
