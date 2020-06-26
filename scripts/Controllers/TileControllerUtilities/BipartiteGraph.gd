extends Graph
class_name BipartiteGraph
"""
Representation of a bipartite graph.

left/right_nodes are arrays that store info on which nodes are on the left/right side
respectively.  They should contain the node and NOT its ID.
"""

#VARIABLES
var left_nodes : Array = [];
var right_nodes : Array = [];

"""
Initialises bipartite graph based on input left and right nodes.
"""
func _init(left_input_nodes : Array, right_input_nodes : Array):
	left_nodes = left_input_nodes;
	right_nodes = right_input_nodes;
	
	var total_nodes : int = left_nodes.size() + right_nodes.size();
	var empty_array : Array = [];
	var id : int = 0;
	
	for i in range(total_nodes):
		empty_array.append(0);
	
	for node in left_nodes:
		vertices_id_map[node] = id;
		id += 1;
		adj_matrix.append(empty_array.duplicate());
	for node in right_nodes:
		vertices_id_map[node] = id;
		id += 1;
		adj_matrix.append(empty_array.duplicate());

"""
Given the results of a DFS on the bipartite graph that covers some nodes, returns
the maximum vertex cover, which is defined as:
	1. the left side node which are NOT in the DFS cover
	2. the right sides which are IN the DFS cover
"""
func get_MVC(dfs_cover : Array) -> Array:
	var dfs_cover_left : Array = []; #nodes in dfs_cover that are LEFT nodes
	var dfs_cover_right : Array = [];
	
	for node in dfs_cover:
		if left_nodes.has(node):
			dfs_cover_left.append(node);
		elif right_nodes.has(node):
			dfs_cover_right.append(node);
			
	var unvisited_left_nodes : Array = Functions.set_difference(left_nodes, dfs_cover_left);
	var mvc : Array = unvisited_left_nodes + dfs_cover_right;
	
	return mvc;

"""
Given the max vertex cover, returns the max independent set.
The MIS is a conjugate of the MVC.
"""
func get_MIS(mvc : Array) -> Array:
	var all_nodes : Array = left_nodes + right_nodes;
	var mis : Array = Functions.set_difference(all_nodes, mvc);
	return mis;
