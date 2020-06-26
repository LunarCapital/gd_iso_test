extends Reference
class_name Graph
"""
Generic graph interface, to be extended by other classes.
"""

var vertices_id_map : Dictionary = {}; # bi-dict, maps vertices <-> ids & vice-versa.
var adj_matrix : Array = [];

"""
Given an array of some vertices, returns an array of those vertices' IDs
(IFF they exist in vertices_id_map).
"""
func convert_verts_to_ids(some_vertices : Array):
	var some_ids : Array = [];
	for vertex in some_vertices:
		if vertices_id_map.has(vertex):
			some_ids.append(vertices_id_map[vertex]);
	return some_ids;

"""
Given an array of some vertices' IDs, returns an array of their vertices (IFF
they exist in vertice_id_map).
"""
func convert_ids_to_verts(some_ids : Array):
	var some_vertices : Array = [];
	for id in some_ids:
		if id is int and vertices_id_map.has(id):
			some_vertices.append(vertices_id_map[id]);
	return some_ids;

"""
Runs DFS with input starting nodes and returns all visited nodes.  Input array
SHOULD use node IDs, and output array contains node IDs.
"""
func dfs_and_get_visited(start_nodes : Array) -> Array:
	var visited : Array = [];
	var stack : Array = [];
	visited += start_nodes;
	stack += start_nodes;
	
	while stack.size() > 0:
		var node = stack.pop_back();
		var neighbours : Array = adj_matrix[node];
		
		for neighbour in neighbours:
			if !visited.has(neighbour):
				stack.push_back(neighbour);
	
	return visited;
