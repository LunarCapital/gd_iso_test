extends Reference
class_name EdgeCollection
"""
Edge Collection class.
A collection of edges that may or may not form a closed loop.

Holds functions specifically for a collection of edges, such as sorting them in order,
'smoothing' them (merging collinear edges), etc.
"""

#constants
const COLLECTION = "_collection";

#variables
var _collection : Array = [];
# I can't actually extend an array due to gdscript limitations

func _init(var edge_collection : Array) -> void:
	_collection = edge_collection;

func get_size() -> int:
	return _collection.size();
	
func get_collection() -> Array:
	return _collection;
	
func set_collection(collection : Array) -> void:
	_collection = collection;

"""
Prints edges. Primarily for debug use.
"""
func print_collection() -> void:
	for edge in _collection:
		print(str(edge.a) + ", " + str(edge.b));
	print("end of collection");

"""
Returns an array of edges that appear in _collection, but with no intersections/duplicates.
"""
func get_set_of_collection() -> Array:
	var edges_without_intersections : Array = [];
	for edge in _collection:
		if (!edge.intersection):
			edges_without_intersections.append(edge);
	
	return edges_without_intersections;

"""
Returns an array of edges that appear in _collection, but ordered counter-clockwise.
"""
func get_ordered_collection() -> Array:
	var ordered_edges : Array = [];
	_reset_checked_edges(_collection);
	var unordered_edges : Array = _get_unchecked_edges(_collection);
	
	if (_collection.size() == 0):
		return _collection;
	else:
		ordered_edges.append(unordered_edges[0]);
		_check_edge(unordered_edges, unordered_edges[0]);
	
	while (_is_any_unchecked(unordered_edges)):
		var back_edge : Edge= ordered_edges.back();
		var front_edge : Edge = ordered_edges.front().get_reverse_edge(); #because _grab_shared_edge ALWAYS uses reference edge's .b value
		var grab_edge_from_back : Edge = _grab_shared_edge(unordered_edges, back_edge);
		var grab_edge_from_front : Edge = _grab_shared_edge(unordered_edges, front_edge);
		
		if not grab_edge_from_back.is_identical(back_edge):
			ordered_edges.push_back(grab_edge_from_back);
			_check_edge(unordered_edges, grab_edge_from_back);
		
		if not grab_edge_from_front.is_identical(front_edge):
			if not grab_edge_from_front.is_identical(grab_edge_from_back): # don't add edge if we grabbed it already (occurs if odd # edges and there's one edge left)
				ordered_edges.push_front(grab_edge_from_front);
				_check_edge(unordered_edges, grab_edge_from_front);
			
		if grab_edge_from_back.is_identical(back_edge) and grab_edge_from_front.is_identical(front_edge): # no new edges grabbed
			break; # no longer possible to order edges as there is a disconnection somewhere

	_reset_checked_edges(ordered_edges);
	return ordered_edges;

"""
Fills and returns an array that contains all the OUTER, PERIMETER edges of every COLLECTION OF TILES.
In other words, collinear edges are merged into a singular edge.
"""
func get_smoothed_collection() -> Array:
	var smoothed_edges : Array = [];
				
	for i in _collection.size():
		var grabbed_edge = _collection[i];
				
		if (smoothed_edges.size() == 0):
			smoothed_edges.append(grabbed_edge);
		else:
			smoothed_edges = _process_grabbed_edge(smoothed_edges, grabbed_edge, i);

	return smoothed_edges;

#############################
#############################
##'PRIVATE' FUNCTIONS BELOW##
#############################
#############################

"""
Unchecks edges in array (in case ordering or smoothing is required again)
"""
func _reset_checked_edges(edges : Array) -> void:
	for edge in edges:
		edge.checked = false;

"""
Checks if there are any unchecked edges in an array of edges.
"""
func _is_any_unchecked(edges : Array) -> bool:
	for edge in edges:
		if not edge.checked:
			return true;
	return false;

"""
Returns an array of unchecked edges.
"""
func _get_unchecked_edges(edges : Array) -> Array:
	var unchecked_edges : Array = [];
	for i in range(edges.size()):
		if (!edges[i].checked && !edges[i].intersection):
			unchecked_edges.append(edges[i]);
	return unchecked_edges;

"""
Finds an edge within an array and marks it as checked.
"""
func _check_edge(edges : Array, edge : Edge) -> void:
	var edge_index = edges.find(edge);
	if (edge_index != -1):
		edges[edge_index].checked = true;

"""
Returns the first edge that shares a coordinate with some reference edge.
Ignores identical edges.  We always use point B of the reference edge.
If no edge of this condition is found, returns the reference edge (maybe a bad idea?)
"""
func _grab_shared_edge(unchecked_edges : Array, reference_edge : Edge) -> Edge:
	for i in range(unchecked_edges.size()):
		if unchecked_edges[i].checked or unchecked_edges[i].is_identical(reference_edge): #ignore self and checked edges
			continue;
		elif (	   unchecked_edges[i].a == reference_edge.b
				or unchecked_edges[i].b == reference_edge.b):
			return unchecked_edges[i];
	return reference_edge;

"""
Processes what to do with a grabbed edge based off slope gradients of:
	slopes[0] = First edge
	slopes[1] = Previous Edge
	slopes[2] = Grabbed Edge
The grabbed edge is either appended to the array, or made to be an extension of another
edge based on conditionals.  Note that we also need to take into account the scenario where
the grabbed edge is the last edge, because if it is collinear with the first edge then it
becomes an extension of the first edge.
"""
func _process_grabbed_edge(smoothed_edges : Array, grabbed_edge : Edge, index : int) -> Array:
	var previous_edge = smoothed_edges.back();
	var slopes : PoolVector2Array = _calculate_slopes(smoothed_edges[0], previous_edge, grabbed_edge);
	
	if (slopes[1] != slopes[2]): #NOT COLLINEAR. APPEND.
		if (index < _collection.size() - 1): #there are more edges to grab
			_append_smoothed_edge(smoothed_edges, previous_edge, grabbed_edge);
		else: #we grabbed last edge
			if (slopes[0] != slopes[2]): #NOT COLLINEAR with first edge. SIMPLY APPEND.
				_append_smoothed_edge(smoothed_edges, previous_edge, grabbed_edge);
			else: #COLLINEAR WITH FIRST EDGE. EXTEND FIRST EDGE.
				_extend_smoothed_edge(smoothed_edges, smoothed_edges[0], grabbed_edge);
	else: #COLLINEAR. EXTEND.
		if (index < _collection.size() - 1): #there are more edges to grab
			_extend_smoothed_edge(smoothed_edges, previous_edge, grabbed_edge);
		else: #we grabbed last edge
			if (slopes[0] != slopes[2]): #NOT COLLINEAR WITH FIRST EDGE. ignore first edge. EXTEND PREVIOUS&GRABBED.
				_extend_smoothed_edge(smoothed_edges, previous_edge, grabbed_edge);
			else: #COLLINEAR WITH FIRST EDGE. EXTEND FIRST&PREVIOUS. REMOVE PREVIOUS EDGE FROM SMOOTHED_EDGES.
				var previous_and_grabbed_edge = previous_edge.get_extended_edge(grabbed_edge);	
				_extend_smoothed_edge(smoothed_edges, smoothed_edges[0], previous_and_grabbed_edge);
				smoothed_edges.pop_back();
				
	return smoothed_edges;

"""
Calculates the slopes/gradients of three provided edges and returns them as an array.
"""
func _calculate_slopes(first_edge : Edge, previous_edge : Edge, grabbed_edge : Edge) -> PoolVector2Array:
	var slope0 : Vector2 = (first_edge.b - first_edge.a).normalized();
	var slope1 : Vector2 = (previous_edge.b - previous_edge.a).normalized();
	var slope2 : Vector2 = (
			(grabbed_edge.b - grabbed_edge.a).normalized() if 
			(grabbed_edge.a == previous_edge.b) else
			(grabbed_edge.a - grabbed_edge.b).normalized()); #just in case edge.a and edge.b are the wrong way round
	
	var slopes : PoolVector2Array = [slope0, slope1, slope2];
	return slopes;

"""
Appends a new edge to the smoothed_edges array.
Attempts to do this in the 'correct' order, by having the first point of the appended edge
be the same as the last point of the previous edge.
"""
func _append_smoothed_edge(smoothed_edges : Array, previous_edge : Edge, grabbed_edge : Edge) -> void:
	if (previous_edge.b == grabbed_edge.a):
		smoothed_edges.append(grabbed_edge);
	else: #reverse edge if it is in the wrong 'order'
		smoothed_edges.append(grabbed_edge.get_reverse_edge());

"""
Extends the previous edge using the points of the grabbed edge.
"""
func _extend_smoothed_edge(smoothed_edges : Array, previous_edge : Edge, grabbed_edge : Edge) -> void:
	var previous_edge_index = smoothed_edges.find(previous_edge);
	if (previous_edge_index != -1):
		smoothed_edges[previous_edge_index] = previous_edge.get_extended_edge(grabbed_edge);	
