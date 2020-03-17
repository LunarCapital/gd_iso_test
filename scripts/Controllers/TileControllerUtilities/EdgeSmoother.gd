extends Node2D
"""
A class dedicated to sorting AND 'smoothing' an edge array.  Smoothing in this context refers to
a process that combines collinear edges into a single edge.

For example, pre-smoothing, a 2x1 group of square tiles will have 6 edges.
Post-smoothing, the 2x1 group of square tiles will have 4 edges.

I have no idea if doing this actually saves on processing power/speeds things up,
but i spent more time than i'm willing to admit writing this code and might as well use it
since it doesn't take that long to run
"""

var tilemap_to_edges : Dictionary = {};
	
func build_smoothed_edges(tilemap_to_edges : Dictionary):
	self.tilemap_to_edges = tilemap_to_edges;
	
	var tilemaps_to_smoothed_edges : Dictionary = {};
	var tilemaps : Array = tilemap_to_edges.keys();
	
	for tilemap in tilemaps:
		var edges : Array = tilemap_to_edges[tilemap];
		var sorted_edges : Array = sort_edges(edges);
		var smoothed_edges : Array = fill_smoothed_edges(sorted_edges);
		tilemaps_to_smoothed_edges[tilemap] = smoothed_edges;
		
	return tilemaps_to_smoothed_edges;
		
###########################
###########################
##UTILITY FUNCTIONS BELOW##
###########################
###########################

"""
Sorts an array of edges so that the edges are in order.
Prioritises CCW.  Will sort CW if there is no other choice, but this will
only ever happen for ledges that have edges which do not form a loop.
"""
func sort_edges(edges: Array) -> Array:
	var sorted_edges : Array = Functions.init_2d_array(edges.size());
	reset_checked_edges(edges);
	
	print("sort edges run");
	for i in range(edges.size()):
		var count = 0;
		for edge in edges[i]:
			print(str(i) + ", " + str(count) + ": " + str(edge.a) + ", " + str(edge.b));
	
	for i in range(edges.size()): 
		var unchecked_edges : Array = get_unchecked_edges(edges[i]);
		var reversed : bool = false;
		while (unchecked_edges.size() > 0): #WHILE THERE ARE STILL UNCHECKED EDGES
			var grabbed_edge : Edge;
			var previous_edge : Edge;

			if (sorted_edges[i].size() == 0): #grab any edge if smoothed_edges[i] is empty
				grabbed_edge = unchecked_edges[0];
				check_edge(edges, i, grabbed_edge);
				sorted_edges[i].append(grabbed_edge);
			else: #ELSE grab an edge that SHARES a coordinate with previously grabbed edge;
				previous_edge = sorted_edges[i].back() if not reversed else sorted_edges[i].front();
				grabbed_edge = grab_shared_edge(unchecked_edges, previous_edge);
				check_edge(edges, i, grabbed_edge);
				
#				print("prev edge: " + str(previous_edge.a) + ", " + str(previous_edge.b));
#				print("grab edge: " + str(grabbed_edge.a) + ", " + str(grabbed_edge.b));
#				var count = 0;
##				for sorted_edge in sorted_edges[i]:
##					print("sorted edge #" + str(count) + ": " + str(sorted_edge.a) + ", " + str(sorted_edge.b));
##					count += 1;
#				for edge in edges[i]:
#					print("edge #" + str(count) + ": " + str(edge.a) + ", " + str(edge.b));
#					count += 1;

				if (grabbed_edge == previous_edge): #no more edges to grab that extend off polygon in CCW direction					
					#attempt to go in reverse direction.
					var reversed_previous_edge = previous_edge.get_reverse_edge();
					grabbed_edge = grab_shared_edge(unchecked_edges, reversed_previous_edge);
					check_edge(edges, i, grabbed_edge);
					
					if (grabbed_edge == previous_edge): #we have an inner loop. extend algorithm to fix this.
						print("FAILED TO EXTEND EDGE");
						print("previous edge: " + str(previous_edge.a) + ", " + str(previous_edge.b));
						print("grabbed edge: " + str(grabbed_edge.a) + ", " + str(grabbed_edge.b));
						break;
					else:
						sorted_edges[i].push_front(grabbed_edge);
				else:
					sorted_edges[i].append(grabbed_edge);
				
			unchecked_edges = get_unchecked_edges(edges[i]); #why can't i assign vars in the while loop condition AHHHHHHHH
				
	return sorted_edges;
	

"""
Fills and returns an array that contains all the OUTER, PERIMETER edges of every GROUP OF TILES.
In other words, collinear edges are merged into a singular edge.
"""
func fill_smoothed_edges(sorted_edges : Array):
	var smoothed_edges : Array = Functions.init_2d_array(sorted_edges.size());
				
	for i in range(sorted_edges.size()):
		for j in sorted_edges[i].size():
			var grabbed_edge = sorted_edges[i][j];
					
			if (smoothed_edges[i].size() == 0):
				smoothed_edges[i].append(grabbed_edge);
			else:
				var previous_edge = smoothed_edges[i].back();
					
				var slope0 : Vector2 = (smoothed_edges[i][0].b - smoothed_edges[i][0].a).normalized();
				var slope1 : Vector2 = (previous_edge.b - previous_edge.a).normalized();
				var slope2 : Vector2 = (
						(grabbed_edge.b - grabbed_edge.a).normalized() if 
						(grabbed_edge.a == previous_edge.b) else
						(grabbed_edge.a - grabbed_edge.b).normalized());
				
				if (slope1 != slope2): #NOT COLLINEAR. APPEND.
					if (j < sorted_edges[i].size() - 1): #there are more edges to grab
						append_smoothed_edge(smoothed_edges, i, previous_edge, grabbed_edge);
					else: #we grabbed last edge
						if (slope0 != slope2): #NOT COLLINEAR with first edge. APPEND.
							append_smoothed_edge(smoothed_edges, i, previous_edge, grabbed_edge);
						else: #COLLINEAR WITH FIRST EDGE. EXTEND FIRST EDGE.
							extend_smoothed_edge(smoothed_edges, i, smoothed_edges[i][0], grabbed_edge);
				else: #COLLINEAR. EXTEND.
					if (j < sorted_edges[i].size() - 1): #there are more edges to grab
						extend_smoothed_edge(smoothed_edges, i, previous_edge, grabbed_edge);
					else: #we grabbed last edge
						if (slope0 != slope2): #NOT COLLINEAR WITH FIRST EDGE. ignore first edge. EXTEND PREVIOUS&GRABBED.
							extend_smoothed_edge(smoothed_edges, i, previous_edge, grabbed_edge);
						else: #COLLINEAR WITH FIRST EDGE. EXTEND FIRST&PREVIOUS. REMOVE PREVIOUS EDGE FROM SMOOTHED_EDGES.
							var previous_and_grabbed_edge = previous_edge.get_extended_edge(grabbed_edge);	
							extend_smoothed_edge(smoothed_edges, i, smoothed_edges[i][0], previous_and_grabbed_edge);

	return smoothed_edges;

"""
Unchecks edges in array (in case sorting or smoothing is required again)
"""
func reset_checked_edges(edges : Array):
	for i in edges.size():
		for edge in edges[i]:
			edge.checked = false;

"""
Returns an array of unchecked edges.
"""
func get_unchecked_edges(edges : Array):
	var unchecked_edges : Array = [];
	for i in range(edges.size()):
		if (!edges[i].checked && !edges[i].intersection):
			unchecked_edges.append(edges[i]);
	return unchecked_edges;

"""
Finds an edge within an array (god help me) and marks it as checked.
"""
func check_edge(edges : Array, group_index : int, edge : Edge):
	var edge_index = edges[group_index].find(edge);
	if (edge_index != -1):
		edges[group_index][edge_index].checked = true;

"""
Returns the first edge that shares a coordinate with some reference edge.
Ignores identical edges.  We always use point B of the reference edge.
If no edge of this condition is found, returns the reference edge (maybe a bad idea?)
"""
func grab_shared_edge(unchecked_edges : Array, reference_edge : Edge):
	for i in range(unchecked_edges.size()):
		if (unchecked_edges[i].is_identical(reference_edge)): #ignore self
			continue;
		elif (	   unchecked_edges[i].a == reference_edge.b
				or unchecked_edges[i].b == reference_edge.b):
			return unchecked_edges[i];
	return reference_edge;

"""
Appends a new edge to the smoothed_edges array.
Attempts to do this in the 'correct' order, by having the first point of the appended edge
be the same as the last point of the previous edge.
"""
func append_smoothed_edge(smoothed_edges : Array, index : int, previous_edge : Edge, grabbed_edge : Edge):
	if (previous_edge.b == grabbed_edge.a):
		smoothed_edges[index].append(grabbed_edge);
	else: #reverse edge if it is in the wrong 'order'
		smoothed_edges[index].append(grabbed_edge.get_reverse_edge());

"""
Extends the previous edge using the points of the grabbed edge.
"""
func extend_smoothed_edge(smoothed_edges : Array, index : int, previous_edge : Edge, grabbed_edge : Edge):
	var previous_edge_index = smoothed_edges[index].find(previous_edge);
	if (previous_edge_index != -1):
		smoothed_edges[index][previous_edge_index] = previous_edge.get_extended_edge(grabbed_edge);	
