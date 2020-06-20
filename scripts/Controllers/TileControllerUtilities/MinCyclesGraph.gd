extends Node
class_name MinCyclesGraph

#VARIABLES
var vertices_id_map : Dictionary = {}; # bi-dict. SHOULD hold both [vertices]->id AND [id]->vertices
var adj_matrix : Array = []; # 2D array, built on initialisation
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
	var vertices : Array= [];
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
	# while vertices still have lives
		# find min cycle C of any vertice with 1 life
		# reduce lives of all vertices in C by 1
		
	# get rid of any cycles that are holes
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
	
	return [];
