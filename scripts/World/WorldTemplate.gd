extends Node2D
"""
A template (and also a test).

Should store tilemaps in an array IN ORDER of increasing Z level.
Also attempts to automatically create Area2Ds with CollisionPolygon2Ds to help detect what tilemap the player should be
drawn on.
"""
const walkable_area_script = preload("res://scripts/World/WorldUtilities/WalkableArea.gd")

#globals
var tilemaps : Array = [];

#constants
enum {UNCONNECTED = 0, CONNECTED = 1}

func _ready():
	tilemaps.resize(20); #replace with some global 'max_z_lvl' later
	fill_tilemaps_array();
	create_tilemap_area2d();

"""
Iterates through all child nodes and adds tilemaps to the global array.
"""
func fill_tilemaps_array():
	var all_children = self.get_children();
	for child in all_children:
		if (child.get_class() != "TileMap"):
			continue;

		if (child.name == "Floor"): #a bit of hardcoding still triggers me
			tilemaps[0] = child;
		else: #if name contains a number
			var child_name = child.name;
			var regex = RegEx.new();
			regex.compile("\\d+");
			var child_result = regex.search(child_name);
			if (child_result):
				var child_number = int(child_result.get_string());
				tilemaps[child_number+1] = child;

"""
Creates an area2D based off a tilemap's walkable tile areas.
"""
func create_tilemap_area2d():
	for n in range(tilemaps.size()):
		var tilemap = tilemaps[n];
		if (tilemap):
			var area2d = Area2D.new();
			area2d.name = "AreaFloor" if tilemap.name == "Floor" else ("Area" + str(n-1));
			tilemap.add_child(area2d);

			#get vertices
			if (tilemap.name != "Floor"): #just for floor at first
				continue;
				
			var adj_matrix : Array = init_adj_matrix(tilemap.get_used_cells().size());
			var polygons = fill_polygons(tilemap, adj_matrix);

			#recursive flood fill
			var color_max = 0;
			for polygon in polygons:
				if (polygon.color == Polygon.UNCOLORED):
					flood_fill(adj_matrix, polygons, polygon, color_max);
					color_max += 1;

			var edges : Array = fill_edges(polygons, color_max);

			var smoothed_edges : Array = fill_smoothed_edges(edges); #Create smoothed edges array in same format of edges array

			for i in range(smoothed_edges.size()): #make collisionpoly2d for each tile group
				var cp2d = CollisionPolygon2D.new();
				cp2d.name = "CollisionPolygon2D";
				var polygon_vertices : PoolVector2Array = [];
				for j in range(smoothed_edges[i].size()):
					polygon_vertices.append(smoothed_edges[i][j].a);
				cp2d.set_polygon(polygon_vertices);
				area2d.add_child(cp2d);
				
			area2d.set_script(walkable_area_script);
			area2d.connect("area_entered", area2d, area2d.LISTENER_ON_AREA_ENTERED);
			area2d.collision_layer = (2);
			area2d.collision_mask = (12);

###########################
###########################
##UTILITY FUNCTIONS BELOW##
###########################
###########################

"""
Shifts vertices based off some origin.  
Used to obtain a tile's vertexes in a scene's space using its origin and tileset vertex coordinates.
"""	
func shift_vertices(tile_vertices : Array, origin : Vector2):
	var vertices = [];
	for vertex in tile_vertices:
		vertices.append(origin + vertex);
	return vertices;

"""
Returns an array of duplicate edges.
"""
func get_duplicate_edges(edges : Array, original_edge : Edge):
	var duplicate_edges : Array = [];
	for edge in edges:
		if (edge.is_identical(original_edge)):
			duplicate_edges.append(edge);

	return duplicate_edges;

"""
Creates and fills a polygon array based off all the tiles present on a tilemap node
"""
func fill_polygons(tilemap : TileMap, adj_matrix : Array):
	var polygons : Array = [];
	var tileset = tilemap.tile_set;
	var cells = tilemap.get_used_cells();
	for cell in cells:
		var top_point = tilemap.map_to_world(cell);
		var origin = top_point - Vector2(tilemap.get_cell_size().x/2 , 0);
		var cell_id = tilemap.get_cell(cell.x, cell.y);
		var navpoly = tileset.tile_get_navigation_polygon(cell_id);

		if (navpoly):
			print(tileset.tile_get_name(cell_id));
			var vertices = shift_vertices(navpoly.get_vertices(), origin);
			var new_polygon = Polygon.new();

			for i in range(vertices.size()): #fill polygon edges
				var new_edge = Edge.new();
				new_edge.a = vertices[i];
				new_edge.b = vertices[(i+1)%vertices.size()];
				new_polygon.edges.append(new_edge);

			for i in range(polygons.size()): #fill adjacency matrix
				if (polygons[i].is_polygon_adjacent(new_polygon)):
					adj_matrix[i][polygons.size()] = CONNECTED;
					adj_matrix[polygons.size()][i] = CONNECTED;

			new_polygon.id = polygons.size();
			polygons.append(new_polygon);

	return polygons;

"""
Fills and returns an array that contains all the edges of every tile polygon, of every GROUP OF TILES.
Edges is a 2D array. Its first dimension is the 'group' of tiles, while the second dimension is all the group's edges.
"""
func fill_edges(polygons : Array, color_max : int):
	var edges : Array = init_2d_array(color_max);
	for current_color in range(color_max):
		for polygon in polygons:
			if (polygon.color == current_color):
				for edge in polygon.edges:
					var duplicate_edges = get_duplicate_edges(edges[current_color], edge);
					if (!duplicate_edges):
						edges[current_color].append(edge);
					else:
						edge.intersection = true;
						edges[current_color].append(edge);
						for duplicate_edge in duplicate_edges:
							duplicate_edge.intersection = true;
	return edges;

"""
Fills and returns an array that contains all the OUTER, PERIMETER edges of every GROUP OF TILES.
These edges are in order.
"""
func fill_smoothed_edges(edges : Array):
	var smoothed_edges : Array = init_2d_array(edges.size());

	for i in range(edges.size()): 
		var unchecked_edges : Array = get_unchecked_edges(edges[i]);
		while (unchecked_edges.size() > 0): #WHILE THERE ARE STILL UNCHECKED EDGES
			var grabbed_edge : Edge;
			var previous_edge : Edge;

			if (smoothed_edges[i].size() == 0): #grab any edge if smoothed_edges[i] is empty
				grabbed_edge = unchecked_edges[0];
				check_edge(edges, i, grabbed_edge);
				smoothed_edges[i].append(grabbed_edge);
			else: #ELSE grab an edge that SHARES a coordinate with previously grabbed edge;
				previous_edge = smoothed_edges[i].back();
				grabbed_edge = grab_shared_edge(unchecked_edges, previous_edge);
				check_edge(edges, i, grabbed_edge);
				var grabbed_edge_index = edges[i].find(grabbed_edge);
				if (grabbed_edge == previous_edge): #something's gone wrong
					print("FAILED TO EXTEND EDGE");
					print("previous edge: " + str(previous_edge.a) + ", " + str(previous_edge.b));
					print("grabbed edge: " + str(grabbed_edge.a) + ", " + str(grabbed_edge.b));
					break;
				
				var slope0 : Vector2 = (smoothed_edges[i][0].b - smoothed_edges[i][0].a).normalized();
				var slope1 : Vector2 = (previous_edge.b - previous_edge.a).normalized();
				var slope2 : Vector2 = (
						(grabbed_edge.b - grabbed_edge.a).normalized() if 
						(grabbed_edge.a == previous_edge.b) else
						(grabbed_edge.a - grabbed_edge.b).normalized());
				
				if (slope1 != slope2): #NOT COLLINEAR. APPEND.
					if (unchecked_edges.size() > 1): #there are more edges to grab
						append_smoothed_edge(smoothed_edges, i, previous_edge, grabbed_edge);
					else: #we grabbed last edge
						if (slope0 != slope2): #NOT COLLINEAR with first edge. APPEND.
							append_smoothed_edge(smoothed_edges, i, previous_edge, grabbed_edge);
						else: #COLLINEAR WITH FIRST EDGE. EXTEND FIRST EDGE.
							extend_smoothed_edge(smoothed_edges, i, smoothed_edges[i][0], grabbed_edge);
				else: #COLLINEAR. EXTEND.
					if (unchecked_edges.size() > 1): #there are more edges to grab
						extend_smoothed_edge(smoothed_edges, i, previous_edge, grabbed_edge);
					else: #we grabbed last edge
						if (slope0 != slope2): #NOT COLLINEAR WITH FIRST EDGE. ignore first edge. EXTEND PREVIOUS&GRABBED.
							extend_smoothed_edge(smoothed_edges, i, previous_edge, grabbed_edge);
						else: #COLLINEAR WITH FIRST EDGE. EXTEND FIRST&PREVIOUS. REMOVE PREVIOUS EDGE FROM SMOOTHED_EDGES.
							var previous_and_grabbed_edge = previous_edge.get_extended_edge(grabbed_edge);	
							extend_smoothed_edge(smoothed_edges, i, smoothed_edges[i][0], previous_and_grabbed_edge);

			unchecked_edges = get_unchecked_edges(edges[i]); #why can't i assign vars in the while loop condition AHHHHHHHH
			
	return smoothed_edges;

"""
Recursive flood fill of tile polygons in a group.
"""
func flood_fill(adj_matrix : Array, polygons : Array, polygon : Polygon, color : int):
	polygon.color = color;
	for i in range(adj_matrix[polygon.id].size()):
		if (adj_matrix[polygon.id][i] == CONNECTED && polygons[i].color == Polygon.UNCOLORED):
			flood_fill(adj_matrix, polygons, polygons[i], color);

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

"""
Finds an edge within an array (god help me) and marks it as checked.
"""
func check_edge(edges : Array, group_index : int, edge : Edge):
	var edge_index = edges[group_index].find(edge);
	if (edge_index != -1):
		edges[group_index][edge_index].checked = true;

"""
Init an empty 2D array of some size. 
"""
func init_2d_array(size : int):
	var array2d : Array = [];
	array2d.resize(size);
	for i in range(array2d.size()):
		array2d[i] = [];
	return array2d;

"""
Init an empty adjacency matrix.
"""
func init_adj_matrix(size : int):
	var adj_matrix : Array = [];
	adj_matrix.resize(size);
	for i in range(adj_matrix.size()):
		adj_matrix[i] = [];
		adj_matrix[i].resize(size);
		for j in range(adj_matrix[i].size()):
			adj_matrix[i][j] = UNCONNECTED;
	return adj_matrix;