extends Node2D
"""
The unholy:
	DECOMPOSITION OF AN IRREGULAR RECTILINEAR POLYGON WITH HOLES INTO 
	THE MINIMAL SET OF RECTANGLES
	
Credit to: https://nanoexplanations.wordpress.com/2011/12/02/polygon-rectangulation-part-1-minimum-number-of-rectangles/
for the explanation.

This script is dedicated to taking an edge group's perimeter along with all of its
holes' perimeters as an input, breaking the shape up into the minimum number of
rectangles, and returning an array of Area2Ds that represent those rectangles.

Note that it is necessary to transform from isometric coordinates to cartesian
coordinates.
"""

#utility nodes
onready var bipartite_ford_fulkerson = $BipartiteFordFulkerson;

"""
Black box function. Throw in the perimeters of a polygon and its holes, obtain
the perimeters of the minimum number of rectangles the polygon can be broken into.

Note that array_of_isometric_perimeters is an array of arrays of edges, not an array
of EdgeCollections.

NOTE TO SELF:
	For testing, do:
		chord-less shape that is already a rectangle
		chord-less shape that isn't a rectangle
		chord shape
		chord-less shape with hole(s)
		chord shape with holes
"""
func decompose_into_rectangles(arr_iso_perims : Array) -> Array:
	var arr_area2Ds : Array = [];
	
	#transform to cartesian coordinates
#	for arr in arr_iso_perims:
#		for edge in arr:
#			edge.print_edge();
#		print("\n");
	
	var arr_carte_perims : Array = _convert_to_cartesian(arr_iso_perims); # index 0 = polygon perim, index 1-inf = holes perims
	#run chord-splitting algorithm to get array of arrays (array of perimeters and holes if exist)
	var arr_chordless_polygons : Array = _split_into_chordless_polygons(arr_carte_perims); # arr_chordless_polygons is an array of cartesian perims
	#run basic rectangulation on result of previous algo
	#transform all rectangles back to isometric
	#make rectangles into area2Ds
	
	return arr_area2Ds;

###########################
###########################
##PRIVATE FUNCTIONS BELOW##
###########################
###########################

"""
Converts the coordinates in the input array from isometric to cartesian
coordinates.  The output array no longer contains edges (as they are unneeded
for this script's purpose).
"""
func _convert_to_cartesian(arr_iso_perims : Array) -> Array:
	var arr_carte_perims : Array = [];
	
	for edges in arr_iso_perims:
		arr_carte_perims.append([]);
		for edge in edges:
			var isoX = edge.a.x;
			var isoY = edge.a.y;
			var carteX = isoX + 2*isoY;
			var carteY = 2*isoY - isoX;
			
			arr_carte_perims.back().append(Vector2(carteX, carteY));
	
	return arr_carte_perims;

"""
Accepts the base polygon (with holes if they exist) as an input.  Checks if the
polygon contains any chords (non-edge horizontal/vertical lines between CONVEX 
vertices), and divides the base polygon into smaller polygons that DO NOT contain
chords.  A breakdown of this method is as follows:
	1. Find chords
	2. Make bipartite graph of chords (horizontal and vertical)
	3. Find max matching of bipartite graph
	4. Find max vertex cover using max matching
		4.1 Take left side nodes excluded from max match
		4.2 DFS on those nodes to get a 'dfs node cover'
		4.3 Of the 'dfs node cover', take UNVISITED left nodes and VISITED right nodes
	5. Find max independent set which is conjugate of max vertex cover
	6. MIS corresponds to the 'min num of chords that DON'T intersect'
	7. Draw chords in MIS and split the polygon accordingly
"""
func _split_into_chordless_polygons(arr_carte_perims : Array) -> Array:
	var arr_chords : Array = _find_chords(arr_carte_perims);
	var bipart_graph : BipartiteGraph = _create_bipartite(arr_chords);
	var max_matching : Dictionary = _get_max_matching(bipart_graph);
	var excluded_left_nodes : Array = _get_left_nodes_excluded(bipart_graph, max_matching);
	var dfs_cover : Array = bipart_graph.dfs_and_get_visited(bipart_graph.convert_verts_to_ids(excluded_left_nodes));
	var max_vertex_cover : Array = bipart_graph.get_MVC(bipart_graph.convert_ids_to_verts(dfs_cover));
	var max_independent_set : Array = bipart_graph.get_MIS(max_vertex_cover);
	
	var arr_chordless_polygons : Array = _split_polygon_into_chordless(arr_carte_perims, max_independent_set);
	
	#set S contains chords that we 'keep' or draw, 

	#Use M to find a maximum independent set S of vertices of the bipartite graph.  (This set corresponds to a maximum set of nonintersecting chords of P.)
	#Draw the chords corresponding to S in P.  This subdivides P into |S|+1 smaller polygons, none of which contains a chord.
	#Using Algorithm 1, rectangulate each of the chordless polygons.
	#Output the union of the rectangulations of the previous step.
	
	return arr_chordless_polygons;

"""
Given an array describing the perimeter (and holes if they exist) of an irregular
rectilinear polygon, returns an array containing the chords of said polygon.
"""
func _find_chords(arr_carte_perims : Array) -> Array:
	var arr_chords : Array = [];
	for arr_vertexes_a in arr_carte_perims:	
		for vertex_a in arr_vertexes_a: # lord forgive me for the sin i am about to commit
			for arr_vertexes_b in arr_carte_perims:
				for vertex_b in arr_vertexes_b:
					if _is_chord_valid(vertex_a, vertex_b, arr_carte_perims, arr_chords):
						var new_chord = Chord.new();
						new_chord.a = vertex_a;
						new_chord.b = vertex_b;
						new_chord.direction = new_chord.VERTICAL if (vertex_a.x == vertex_b.x) else new_chord.HORIZONTAL;
						arr_chords.append(new_chord);
			
	return arr_chords;

"""
Checks if a segment between two vertexes is a valid chord.  Segment = chord IFF
0. not already in the chords array (but with reversed points) (i didn't do 0. to be pedantic, i did it because this one's kind of a non-geometry reason)
1. the vertexes are different
2. the segment is vertical or horizontal
3. the segment does not CONTAIN a part of the polygon's perimeter
"""
func _is_chord_valid(vertex_a : Vector2, vertex_b : Vector2, arr_carte_perims : Array, arr_chords : Array) -> bool:
	for chord in arr_chords: # IF NOT ALREADY IN CHORDS ARRAY
		if (chord.a == vertex_a and chord.b == vertex_b) or (chord.a == vertex_b and chord.b == vertex_a):
			return false;
	
	var chord_contains_perimeter : bool = false;
	
	if vertex_a != vertex_b: # IF VERTEXES ARE NOT THE SAME
		if vertex_a.x == vertex_b.x or vertex_a.y == vertex_b.y: # IF VERTICAL/HORIZONTAL LINE
			for arr_vertexes in arr_carte_perims: #IF SEGMENT DOES NOT CONTAIN PERIMETER
				for i in range(arr_vertexes.size()):
					var edge_a = arr_vertexes[i-1];
					var edge_b = arr_vertexes[i];
					
					var orientations_identical : bool = _are_orientations_identical(vertex_a, vertex_b, edge_a, edge_b);
					var segments_intersect : bool = Functions.line_line(vertex_a, vertex_b, edge_a, edge_b);
					if orientations_identical and segments_intersect:
						chord_contains_perimeter = true;
					
			if not chord_contains_perimeter:
				return true;
	return false;

"""
Using chords, creates a bipartite graph where one side of the graph is vertical
chords while the other side is horizontal chords.  An edge between two nodes signifies
an intersection between a vertical&horizontal chord.
"""
func _create_bipartite(arr_chords : Array) -> BipartiteGraph:
	var vert_nodes : Array = [];
	var hori_nodes : Array = [];
	for chord in arr_chords:
		if chord.direction == chord.VERTICAL:
			vert_nodes.append(chord);
		elif chord.direction == chord.HORIZONTAL:
			hori_nodes.append(chord);
	var bipart_graph : BipartiteGraph = BipartiteGraph.new(vert_nodes, hori_nodes);
	
	for left_node in bipart_graph.left_nodes:
		for right_node in bipart_graph.right_nodes:
			if _do_chords_intersect(left_node, right_node):
				var left_node_id = bipart_graph.vertices_id_map[left_node];
				var right_node_id = bipart_graph.vertices_id_map[right_node];
				bipart_graph.adj_matrix[left_node_id][right_node_id] = 1;
				bipart_graph.adj_matrix[right_node_id][left_node_id] = 1;
	
	return bipart_graph;

"""
Checks if two chords intersect. Returns true if they do and false if otherwise.
"""
func _do_chords_intersect(chord1 : Chord, chord2: Chord) -> bool:
	var line1_a : Vector2 = Vector2(chord1.a.x, chord1.a.y);
	var line1_b : Vector2 = Vector2(chord1.b.x, chord1.b.y);
	var line2_a : Vector2 = Vector2(chord2.a.x, chord2.a.y);
	var line2_b : Vector2 = Vector2(chord2.b.x, chord2.b.y);
	
	return Functions.line_line(line1_a, line1_b, line2_a, line2_b);

"""
Checks if orientations (or slope) for two lines are identical.
In this case lines are either horizontal or vertical which makes things simpler.
"""	
func _are_orientations_identical(line1_a : Vector2, line1_b : Vector2, line2_a : Vector2, line2_b : Vector2) -> bool:
	var run1 : float = line1_b.x - line1_a.x;
	var rise1 : float = line1_b.y - line1_a.y;
	var run2 : float = line2_b.x - line2_a.x;
	var rise2 : float = line2_b.y - line2_a.y;
	
	if (run1 == 0 and run2 == 0) or (rise1 == 0 and rise2 == 0):
		return true;
	else:
		return false;

"""
Finds the maximum matching of the input bipartite graph via treating it like a 
flow network and running ford-fulkerson.  I know this doesn't need to be a separate
function but just made it so to match convention
"""
func _get_max_matching(bipart_graph : BipartiteGraph) -> Dictionary:
	var max_matching : Dictionary = bipartite_ford_fulkerson.run_bipartite_ff(bipart_graph);	
	return max_matching;
	
"""
From bipartite graph, get the left nodes that are excluded from the maximum matching.
Returns array containing excluded left nodes.
"""
func _get_left_nodes_excluded(bipart_graph, max_matching) -> Array:
	var excluded_left_nodes : Array = [];
	excluded_left_nodes = Functions.set_difference(bipart_graph.left_nodes, max_matching.keys());
	return excluded_left_nodes;

"""
Given a 2D array 'arr_carte_perims' describing the perimeters (in cartesian coords) 
of an irregular polygon and its holes, and a 1D array 'max_independent_set', the 
minimum set of size S non-intersecting chords..

..SPLIT the original polygon described by 'arr_carte_perims' into S + 1 new
CHORDLESS polygons by using the non-intersecting chords as 'additional' edges.
"""
func _split_polygon_into_chordless(arr_carte_perims : Array, max_independent_set : Array) -> Array:
	var arr_chordless_polygons : Array = [];
	
	#begin with base polygon with drawn chords
	#make graph with vertices as vertexes and edges as... edges
	#find the SMALLEST cycles until ALL EDGES are used
		#can do this by assigning vertices 'lives' which are equal to (conn edges - 1)
	#any smallest cycles which are holes should be discarded (or marked as such)
	#IF there are remaining edges, they are 'holes' of the split polygons, so:
	#out of the remaining edges, find the OUTERMOST edges of the hole(s), then try and find
		#which of the previously split-polygons they belong to (are inside of)
	#once the polygon-hole pairs are made, we have found split polygons (and holes)
	#however the 'holes' may still have edges inside them, so we need to repeat from the
		#'SMALLEST cycles' stage for them too.
	#repeat until no more edges/vertexes are left, now we have found all polygon-hole
		#pairs (ofc some are hole-less)
		
	var min_cycles_graph : MinCyclesGraph = MinCyclesGraph.new(arr_carte_perims, max_independent_set);
	
	
	
	return arr_chordless_polygons;
