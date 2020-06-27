extends Graph
class_name MinCyclesGraph
"""
Extension of graph.
Exists solely for the purpose to extract 'min cycles' in a graph representing 
vertices/edges of a polygon with holes (with chords drawn as extra edges), because
said graph's min cycles equate to inner rectangles that we need to extract.
"""

var vertices_lives : Array = [];

#should return cycle as array of vertices [A B C D ... E]

##########################
##########################
##ALL INIT-RELATED FUNCS##
##########################
##########################

"""
Initialises given an input:
	arr_perims, an 2D array of Vector2s that describe the vertices (in order) 
	of the perim of the polygon and its holes
	drawn_chords, an array of Chord objects that should be added to the adj
	matrix
	
"""
func _init(polygon_perims : Array, drawn_chords : Array) -> void:
	var vertices : Array = _init_vertices(polygon_perims);
	
	#SORT VERTICES
	vertices.sort_custom(self, "_sort_by_x_then_y_ascending");
	
	#fill vertices_id_map
	for i in vertices.size():
		var vertex : Vector2 = vertices[i];
		vertices_id_map[vertex] = i;
		vertices_id_map[i] = vertex;
		
	adj_matrix = _init_adj_matrix(polygon_perims, vertices);
	adj_matrix = _add_chords_to_adj_matrix(adj_matrix, drawn_chords);
	
	vertices_lives = _init_vertices_lives(vertices, drawn_chords);
	
"""
Take all vertices from the polygon (holes included) and append to
an array.
"""
func _init_vertices(polygon_perims : Array) -> Array:
	var vertices : Array = [];
	for perim in polygon_perims:
		for vertex in perim:
			if !vertices.has(vertex):
				vertices.append(vertex);
	return vertices;
	
"""
Based on the polygon's (and its holes') edges, fill in an adj matrice
"""
func _init_adj_matrix(polygon_perims : Array, vertices : Array) -> Array:
	var local_adj_matrix : Array = [];
	for vertex in vertices:
		var empty_array : Array = [];
		for vertex in vertices:
			empty_array.append(0); # god i should just put an array_fill() in the functions autoload or something
		local_adj_matrix.append(empty_array);
	
	for perim in polygon_perims: 
		for i in perim.size():
			var vertex_id : int = vertices_id_map[perim[i]];
			var prev_vertex_id : int = vertices_id_map[perim[i-1]];
			var next_vertex_id : int = vertices_id_map[perim[(i+1)%perim.size()]];
			local_adj_matrix[vertex_id][prev_vertex_id] = 1;
			local_adj_matrix[vertex_id][next_vertex_id] = 1;
	return local_adj_matrix;
	
"""
Using an input array of chords (which are between vertices), adds more
edges to the adjacency matrix.
"""
func _add_chords_to_adj_matrix(local_adj_matrix : Array, drawn_chords : Array) -> Array:
	for chord in drawn_chords:
		var a_id : int = vertices_id_map[chord.a];
		var b_id : int = vertices_id_map[chord.b];
		local_adj_matrix[a_id][b_id] = 1;
		local_adj_matrix[b_id][a_id] = 1;
	
	return local_adj_matrix;
	
"""
Initialise the global vertices_lives array.  All vertices, by default,
have '1' life (AKA can be used in one cycle), but any vertices connected
to a chord have an additional life (up to three).
"""
func _init_vertices_lives(vertices, drawn_chords):
	var local_vertices_lives : Array = [];
	for vertex in vertices:
		local_vertices_lives.append(1);
	
	for chord in drawn_chords:
		var a_id = vertices_id_map[chord.a];
		var b_id = vertices_id_map[chord.b];
		local_vertices_lives[a_id] += 1;
		local_vertices_lives[b_id] += 1;
		
	return local_vertices_lives;
	
"""
Sorting func for an array of Vector2s (representing polygon vertices) 
that sorts by the x coordinate in ascending order.  IF two Vector2s
have the same x coordinate, sorts by y coordinate in ascending order
instead.
"""
func _sort_by_x_then_y_ascending(a : Vector2, b : Vector2) -> bool:		
	if (a.x < b.x):
		return true;
	elif (a.x > b.x):
		return false;
	else: # x coord equal
		if (a.y < b.y):
			return true;
		else:
			return false;
			
#################################
#################################
##END OF ALL INIT-RELATED FUNCS##
#################################
#################################

"""
The entire purpose of this class: To find the minimum cycles of a polygon
(with chords included), AKA to find the smallest rectangles.  
"""
func get_min_cycles() -> Array:
	# wait hang on just realised i haven't yet separated the 
	# largest 'outer loop' with the largest 'inner loop' yet
	
	# maybe it can still work but need to start with outside vertices?
	# AKA select vertices with the lowest 'lives'
	
	# ALGO
	# DFS nodes until we have enough 'covers' for the whole graph
	var connected_groups : Array = _get_connected_groups(); # array of MinCyclesGroups
	connected_groups.sort_custom(self, MinCyclesGroup.SORT_FUNC);
	print(connected_groups.size());
	# find outer perimeter for EACH cover
		# now handled in MinCyclesGroups object
	# try and put covers inside each other (aka check if cover A contains cover B)
		# organise it (consider C inside B and A, B inside A. technically C only needs
		# to be marked as being inside B), AKA make sure covers have at most 1 parent
	var group_contains : Dictionary = _build_group_contains_poly(connected_groups); # dict that stores what groups contain other groups
	group_contains = _simplify_group_contains(group_contains);
	
	
	
	# NEED TO CHANGE HOW "liVES" WORK
	# vertice is made unavailable IFF all its edges are used in min cycles
	# instead of finding cycle of vertex with 1 life, should be
		# finding cycle of vertex with vertex with 2 unused edges
		# need lookup of:
			# vertexes with exactly 2 unused edges
			# vertexes that are no longer available
		# need some way to:
			# store info on edges that have been 'used up'
			
		# duplicate adj matrix, remove edges as we use them?
		# function to iterate over available vertexes and check adj matrix, returns vertices with 2 lives
	
	# for each cover, starting at the biggest
		# while vertices still have lives <= doesn't work in the 1 hole cut corner shape
			# find min cycle C of any vertice with 1 life WITHIN COVER
			# reduce lives of all vertices in C by 1
			# store C in some set of min cycles S
		# if the cover contains other covers, check which MIN CYCLE the contained cover
		# resides in.  this/these cover(s)' outer perims are the min cycles 'holes'.
		# get rid of any cycles that are holes (or mark them as such)
		
	# return 2D array of cycles
	# END ALGO
	
	# what about our four-hole square polygon?
	# above algo will find the outside square, then will solve the 
	# inside polygons
	
	# CONSIDER four-hole square variant which is:
	# square with 8 holes. holes are separated into two sets of 4.
	# each set has same layout as the 4-hole square but 
	# they are placed diagonally from each other so no 
	# chords inbetween.
	
	# IS IT GUARANTEED THAT OUTSIDE EDGES ARE EITHER:
		# CONNECTED TO ALL INSIDE HOLE EDGES
		# ISOLATED FROM ALL INSIDE HOLE EDGES
	# IS THERE NO SCENARIO WHERE OUTSIDE EDGES ARE:
		# CONNECTED TO SOME INSIDE & ISOLATED FROM SOME INSIDE EDGES  
		
	# i've managed to find polygons where the outside edges are connected
	# to some inside edges, but 'connected' inside edges are separate from
	# the other 'non-connected' inside edges?
	
	# can i prove that for some polygon P with drawn chords, if P has some 
	# outside edges O which are disconnected from some inside edges I, no
	# min cycles of O will 'contain' each other?
	
	return [];

"""
Uses DFS to find groups of connected vertices in the graph.  Returns these
groups as a 2D array of MinCyclesGroups, which stores node IDs (and not node
Vector2s).  
"""
func _get_connected_groups() -> Array:
	var connected_groups : Array = [];
	var vertice_visited : Array = []; # boolean array
	for _i in range(vertices_id_map.size()/2): # hope i never read this and ask "why /2?". its a bidict
		vertice_visited.append(false);
	
	for i in range(vertice_visited.size()):
		if !vertice_visited[i]: # if unvisited
			var connected_to_i : Array = dfs_and_get_visited([i]);
			for vertex in connected_to_i: 
				vertice_visited[vertex] = true; # mark as visited
			var new_min_cycles_group : MinCyclesGroup = MinCyclesGroup.new(connected_to_i, adj_matrix, vertices_id_map);
			connected_groups.append(new_min_cycles_group);
	
	return connected_groups;

"""
Forms a dictionary of group INDEXES that map to arrays containing INDEXES of
all groups contained (geometrically) within the key group.  For example, if 
group A (which is a polygon) contains groups B, C and D within it:
	group_contains[A] = [B C D]
"""
func _build_group_contains_poly(groups : Array) -> Dictionary:
	var group_contains : Dictionary = {};
	for i in range(groups.size()):
		group_contains[i] = [];
		for j in range(groups.size()): # check if J is in I
			if i == j:
				continue;
			if _is_poly_in_poly(groups[j].perim, groups[i].perim):
				group_contains[i].append(j);
		
	return group_contains;

"""
Checks if polygon A's outer perimeter is inside polygon B's outer perimeter.
(We ignore holes!)  

Poly-in-poly checking for two polygons is done by line-line checks on EVERY
pair of edges, then seeing if any point of polygon A is inside polygon B.
If no line pair intersects and a point of A is inside B then poly A is inside B.

I would've used bentley-ottmann but gdscript has no PQ nor self-balancing BST
and i really don't want to implement either of them from scratch for one 
job.
"""
func _is_poly_in_poly(poly_A : Array, poly_B : Array) -> bool:
	var is_point_A_in_B : bool = false;
	for i in range(poly_A.size()):
		for j in range(poly_B.size()):
			var line_A_a : Vector2 = poly_A[i-1];
			var line_A_b : Vector2 = poly_A[i];
			var line_B_a : Vector2 = poly_B[j-1];
			var line_B_b : Vector2 = poly_B[j];
			
			if Functions.line_line(line_A_a, line_A_b, line_B_a, line_B_b):
				return false;
				
			if _is_point_in_poly(line_A_a, poly_B):
				is_point_A_in_B = true;
	
	if not is_point_A_in_B:
		return true;
	else:
		return false;

"""
Checks if some point is inside a polygon using the ray-crossing method.
I hope precision is not a problem because I don't want to use the winding
method. 
Assumes polygon is simple (IE, no holes.)
Input for poly is an array of Vector2 points in order (CCW preferred).
"""
func _is_point_in_poly(point : Vector2, poly : Array) -> bool:
	var lowest_y_value; # get lowest y value so i can find where the 'ray' should go to
	for i in range(poly.size()):
		if i == 0:
			lowest_y_value = poly[i].y;
		else:
			if poly[i].y < lowest_y_value:
				lowest_y_value = poly[i].y;
		
	var num_of_crossings = 0;
	for i in range(poly.size()):
		var poly_line_A : Vector2 = poly[i-1];
		var poly_line_B : Vector2 = poly[i];
		if Functions.line_line(point, Vector2(point.x, lowest_y_value - 1), poly_line_A, poly_line_B):
			num_of_crossings += 1;
		
	if num_of_crossings % 2 == 0:
		return false;
	else:
		return true;
		
"""
Simplify the group_contains dictionary, which stores info on which groups are contained
in others, like so:
	group_contains[A] = [B C D]
	where group A contains B, C, and D.
However, if D is also contained within B, then the dictionary is redundant and
should be simplified to:
	group_contains[A] = [B C]
	group_contains[B] = [D]
"""
func _simplify_group_contains(group_contains : Dictionary) -> Dictionary:
	for outside_group in group_contains.keys():
		if group_contains[outside_group].size() > 0:
			for inside_group in group_contains[outside_group]:
				group_contains[outside_group] = Functions.set_difference(group_contains[outside_group], group_contains[inside_group]);
	return group_contains;
