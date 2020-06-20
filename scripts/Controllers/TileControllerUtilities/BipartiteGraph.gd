extends Node
class_name BipartiteGraph
"""
Representation of a bipartite graph.

left and right are arrays that contain nodes of each side of the graph respectively.

left_edges and right_edges are formatted as so:
	left_edges[left[i]] => edges : Array = [edge1, edge2, edge3...]
"""

#VARIABLES
var left_nodes : Array = [];
var right_nodes : Array = [];
var left_edges : Dictionary = {};
var right_edges : Dictionary = {};

func _init(left_input_nodes : Array, right_input_nodes : Array):
	left_nodes = left_input_nodes;
	right_nodes = right_input_nodes;
	
	for node in left_nodes:
		left_edges[node] = [];
	for node in right_nodes:
		right_edges[node] = [];

"""
Runs DFS across bipartite graph using some input start nodes.
Outputs an array containing all nodes spanned by the DFS.
"""
func dfs(start_nodes : Array) -> Array:
	var visited : Array = [];
	var stack : Array = [];
	visited += start_nodes;
	stack += start_nodes;
	
	while stack.size() > 0:
		var node = stack.pop_back();
		var neighbours : Array = left_edges[node] if left_edges.has(node) else right_edges[node];
		
		for neighbour in neighbours:
			if !visited.has(neighbour):
				stack.push_back(neighbour);
	
	return visited;

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
