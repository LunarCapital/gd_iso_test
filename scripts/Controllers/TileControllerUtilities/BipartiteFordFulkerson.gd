extends Node2D
"""
Dedicated to using Ford Fulkerson to find the maximum matching of an input
bipartite graph that represents the intersection between vertical and horizontal
chords of an irregular rectilinear polygon (possibly with holes).
"""

#consts
const SOURCE = "source";
const SINK = "sink";

"""
Runs FF on the input bipartite graph and outputs a dictionary containing info
on the maximum matching of the graph.  The dictionary is formatted as follows:
	
	max_matching[left_node] => right_node;
"""
func run_bipartite_ff(bipart_graph : BipartiteGraph) -> Dictionary:
	var max_matching : Dictionary = {};
	var nodes_to_ids : Dictionary = _fill_nodes_ids_dict(bipart_graph);
	var capacity_network : Array = _init_capacity_network(bipart_graph, nodes_to_ids);
	print(capacity_network);
	var flow_network : Array = _init_flow_network(nodes_to_ids);
	var residual_network : Array = capacity_network.duplicate(); # initial residual network is same as capacity network
	
	var path : Array = _get_augmenting_path(residual_network);
	while path.size() > 1: # 1 (instead of 0) just in case.  
		var residual_capacity : int = _get_residual_capacity(path, capacity_network);
		flow_network = _update_flow_network(path, residual_capacity, flow_network);
		residual_network = _update_residual_network(capacity_network, flow_network, residual_network); 
		path = _get_augmenting_path(residual_network);
		#print("path size: " + str(path.size()));
		#print(path);
	
	max_matching = _get_max_matching(flow_network, nodes_to_ids);
	return max_matching;
	
###########################
###########################
##PRIVATE FUNCTIONS BELOW##
###########################
###########################

"""
Based off some input bipartite graph, attaches an ID to each node and returns
a 2-way dictionary containing info of what a node's id is and what an id's node
is like so:
	nodes_to_ids[node] => id
	nodes_to_ids[id] => node
"""
func _fill_nodes_ids_dict(bipart_graph : BipartiteGraph) -> Dictionary:
	var nodes_to_ids : Dictionary = {};
	nodes_to_ids[SOURCE] = 0;
	nodes_to_ids[0] = SOURCE;
	var id : int = 1;
	
	for left_node in bipart_graph.left_nodes:
		nodes_to_ids[left_node] = id;
		nodes_to_ids[id] = left_node;
		id += 1;
	for right_node in bipart_graph.right_nodes:
		nodes_to_ids[right_node] = id;
		nodes_to_ids[id] = right_node;
		id += 1;
	
	nodes_to_ids[SINK] = id;
	nodes_to_ids[id] = SINK;
	
	return nodes_to_ids;

"""
Initialises the capacity network as a 2D integer array with the following format:
	capacity_network[u][v] => capacity from u to v.
"""
func _init_capacity_network(bipart_graph : BipartiteGraph, nodes_to_ids : Dictionary) -> Array:
	var capacity_network : Array = [];
	var num_of_nodes : int = nodes_to_ids.keys().size()/2; # "bi-dict" so we halve it
	
	for node in nodes_to_ids.keys():
		var capacities : Array = _init_array_of_zeroes(num_of_nodes);
		if node is String: #if key is source or sink. we do nothing if sink, because sink has no connections
			if node == SOURCE:
				for left_node in bipart_graph.left_nodes: # conn to all left nodes
					capacities[nodes_to_ids[left_node]] = 1; 
				
		if node is Chord: #node is left or right bipartite nodes
			if bipart_graph.left_nodes.has(node):
				for conn_node in bipart_graph.left_edges[node]:
					capacities[nodes_to_ids[conn_node]] = 1; # conn to any connected right nodes
			elif bipart_graph.right_nodes.has(node):
				capacities[-1] = 1; # conn to sink
			
		if not node is int:	#make sure we don't append on node_ids
			capacity_network.append(capacities);
			
	return capacity_network;
	
"""
Initialises the flow network, which is simple because all nodes initially have
0 flow to each other.  Formatted as a 2D integer array:
	flow_network[u][v] => Flow from u to v.
"""
func _init_flow_network(nodes_to_ids : Dictionary) -> Array:
	var flow_network : Array = [];
	var num_of_nodes : int = nodes_to_ids.keys().size()/2; 
	
	for _i in range(num_of_nodes):
		var flows : Array = _init_array_of_zeroes(num_of_nodes);
		flow_network.append(flows);
	
	return flow_network;
	
"""
Updates the flow network by iterating along the input path and adding the residual_capacity
to the flow along said path.  
"""
func _update_flow_network(path : Array, residual_capacity : int, flow_network : Array) -> Array:
	var updated_flow_network : Array = flow_network.duplicate();
	
	for i in range(1, path.size()):
		updated_flow_network[i-1][i] += residual_capacity;
	
	return updated_flow_network;
	
"""
Updates the residual network based on the capacity network and current flow network.
Forward edges are equal to (capacity - flow),
backward edges are equal to (flow).
"""
func _update_residual_network(capacity_network : Array, flow_network : Array, residual_network : Array) -> Array:
	var updated_residual_network : Array = residual_network.duplicate();
	var num_of_nodes : int = updated_residual_network.size();
	
	for i in range(num_of_nodes):
		for j in range(num_of_nodes):
			var residual : int = capacity_network[i][j] - flow_network[i][j];
			updated_residual_network[i][j] = residual if (residual > 0) else 0;
	
	return updated_residual_network;

"""
Uses BFS to check if an augmenting path exists in the residual network and returns
it as an array of node IDs in order.  If no path exists, returns an empty array.
"""
func _get_augmenting_path(residual_network : Array) -> Array:
	var num_of_nodes : int = residual_network.size();
	var goal : int = num_of_nodes - 1;
	
	var queue : Array = [];
	var discovered : Array = []; # array of booleans to check if nodes have already been discovered
	var parent : Array = [];
	for _i in range(num_of_nodes):
		discovered.append(false);
		parent.append(-1);
	
	queue.push_back(0); # push source
	discovered[0] = true;
	
	while (queue.size() > 0): # bfs loop
		var node_id : int = queue.pop_front();
		if node_id == goal:
			break;
		for i in range(num_of_nodes):
			if residual_network[node_id][i] > 0: # if there is a path from node_id -> i
				if !discovered[i]:
					discovered[i] = true;
					parent[i] = node_id;
					queue.push_back(i);

	return _extract_path_from_BFS(parent, goal);

"""
Extracts the path from the BFS function's 'parent' array.  Done by recursively
checking the goal's parent, then the goal's parent's parent, and so on.  Finally,
reverses the results to get the nodes in order for the FORWARD path.
"""
func _extract_path_from_BFS(parent : Array, goal : int) -> Array:
	var path : Array = [];
	path.push_front(goal);
	
	var prev : int = parent[goal];
	while prev != -1:
		path.push_front(prev);
		prev = parent[prev];
		
	if path.size() > 1:
		return path;
	else:
		return [];

"""
Returns the minimum residual capacity on a path.  Even though I already know that
for bipartite it's going to be 1, this is here on the off chance i ever need ford-fulk
for anything else and have to drag this node out and make it usable for more 'generic' cases
"""
func _get_residual_capacity(path : Array, capacity_network : Array) -> int:
	var residual_capacity : int = INF;
	for i in range(1, path.size()):
		var path_capacity = capacity_network[i-1][i];
		if path_capacity < residual_capacity:
			residual_capacity = path_capacity;
	return residual_capacity;

"""
Inits an array of input size and fills with zeroes.
"""
func _init_array_of_zeroes(size : int) -> Array:
	var array : Array = [];
	for _i in range(size):
		array.append(0);
	return array;
	
"""
Runs after Ford-Fulkerson is complete to get the max matching of
the original bipartite graph.  Checks what nodes flow to what in 
the flow network and returns the results in a dictionary formatted 
as follows:
	max_matching[v_node] => u_node;
"""
func _get_max_matching(flow_network : Array, nodes_to_ids) -> Dictionary:
	var max_matching : Dictionary = {};
	var num_of_nodes : int = flow_network.size();
	
	for i in range(1, num_of_nodes - 1):
		for j in range(1, num_of_nodes - 1):
			if flow_network[i][j] > 0: # bipartite u-v connection detected
				var v_node = nodes_to_ids[i];
				var u_node = nodes_to_ids[j];
				max_matching[v_node] = u_node;
	return max_matching;
