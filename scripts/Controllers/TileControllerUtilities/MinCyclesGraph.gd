extends Node
class_name MinCyclesGraph

#VARIABLES
var vertices_id_map : Dictionary = {}; # bi-dict. SHOULD hold both [vertices]->id AND [id]->vertices
var adjacency_matrix : Array = []; # 2D array, built on initialisation
var vertices_lives : Array = [];

#should return cycle as array of vertices [A B C D ... E]

"""
Initialises given an input:
	arr_perims, an 2D array of Vector2s that describe the vertices (in order) 
	of the perim of the polygon and its holes
	drawn_chords, an array of Chord objects that should be added to the adj
	matrix
	
"""
func _init(polygon_perims : Array, drawn_chords : Array) -> void:
	var vertices : Array = [];
	for perim in polygon_perims: #for each shape/hole perim
		for vertex in perim:
			if !vertices.has(vertex):
				vertices.append(vertex);
				adjacency_matrix.append([]);
	
	#SORT VERTICES
	#vertices.sort_custom()
	
	for i in vertices.size():
		var vertex : Vector2 = vertices[i];
		vertices_id_map[vertex] = i;
		vertices_id_map[i] = vertex;
		
	#build basic adj matrix
	for perim in polygon_perims: 
		for i in perim.size():
			var vertex_id = vertices_id_map[perim[i]];
			var prev_vertex_id = vertices_id_map[perim[i-1]];
			var next_vertex_id = vertices_id_map[perim[i+1]];
			adjacency_matrix[vertex_id][prev_vertex_id] = 1;
			adjacency_matrix[vertex_id][next_vertex_id] = 1;
			
	#add chords to adj matrix, and init the vertices_live array
