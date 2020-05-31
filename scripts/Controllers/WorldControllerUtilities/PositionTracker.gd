extends Node2D
"""
Tracks and records world-related data of all entities such as:
	Current Z-index (tilemap)
	Current Tile (and adjacent tiles)
	
"""

#signals
signal _falling_triggered(entity, pos);
const SIGNAL_FALLING_TRIGGERED = "_falling_triggered";
signal _request_falling_mask(entity, tilemap, pos);
const SIGNAL_REQUEST_FALLING_MASK = "_request_falling_mask";

#############################################################################################################
#entity_pos_tracker value names
#############################################################################################################
const CURRENT_Z = "Current_Z"; #int. We store the z index layer that the entity is standing ON TOP OF, NOT the layer we're IN
const CURRENT_TILE = "Current_Tile"; #Vector2 #the tile we stand ON TOP OF.
const NORTH_TILE = "North_Tile"; #Vector2. north is top right btw
const EAST_TILE = "East_Tile"; #Vector2
const SOUTH_TILE = "South_Tile"; #Vector2
const WEST_TILE = "West_Tile"; #Vector2
const AREA_SET = "Area_Set"; #Array. maintains a set of what tilemap walkable_areas an entity is currently in.
							 #areas are added/removed from set via the walkable_area signals.
							 #used so you can stand on the edge of a tile without falling off.
#if there is no tile N/E/S/W tile, we make it equal to CURRENT_TILE.
#############################################################################################################


func init_pos_tracker(entity_pos_tracker : Dictionary, entity : Entity, z_index : int):
	entity_pos_tracker[entity] = {CURRENT_Z: z_index, AREA_SET: [], CURRENT_TILE: Vector2(0, 0), 
								  NORTH_TILE: Vector2(0, 0), EAST_TILE: Vector2(0, 0),
								  SOUTH_TILE: Vector2(0, 0), WEST_TILE: Vector2(0, 0)};

"""
Listener function that runs when an entity changes position.
Updates what tile the entity is on, calculates adjacent tiles, and makes colliders.
"""
func on_changed_entity_position(entity_pos_tracker : Dictionary, entity : Entity, pos : Vector2, tilemaps : Dictionary):
	var z_index = entity_pos_tracker[entity][CURRENT_Z];
	var tilemap = tilemaps[z_index - 1];
	var current_tile = tilemap.world_to_map(pos) + Vector2(1,1);
						
	if (entity_pos_tracker[entity][CURRENT_TILE] != current_tile or not entity_pos_tracker[entity][AREA_SET].has(z_index - 1)): #only need to do recalculations if we change our current tile OR we're not in the 'tilemap' that we should be in
		#print("changed tile: " + str(current_tile) + ", layer: " + str(tilemap.name) + " pos: " + str(pos));
		entity_pos_tracker[entity][CURRENT_TILE] = current_tile;
		fill_adjacent_tiles(entity_pos_tracker, entity, tilemaps);
	
		if (!entity.falling): #NOT FALLING
			if (tilemap.get_cellv(current_tile) == -1): #AND THERE'S NO TILE WHERE WE'RE STANDING
				if (!entity_pos_tracker[entity][AREA_SET].has(z_index - 1)): #AND NO PART OF OUR COLLISION AREA IS TOUCHING THE FLOOR
					emit_signal(SIGNAL_FALLING_TRIGGERED, entity, pos);
		
		elif (entity.falling): 
			emit_signal(SIGNAL_REQUEST_FALLING_MASK, entity, tilemaps[z_index], current_tile + Vector2(-1, -1));
	
"""
Listener function that runs when a layer's floor area is entered by an entity.
Adds the layer's z index to a queue. Used to keep track of whether an entity is standing on the 'edge'
of a tile.
"""
func on_area_entered(entity_pos_tracker : Dictionary, floor_area : Area2D, entity : Entity, state : int):
	if (state == floor_area.WALKABLE):
		var tilemap_index = floor_area.get_parent().z_index;
		if (!entity_pos_tracker[entity][AREA_SET].has(tilemap_index)):
			entity_pos_tracker[entity][AREA_SET].push_back(tilemap_index);
	
"""
Listener function that runs when an entity leaves a layer's floor area.
Removes the layer's z index to a queue. Used to keep track of whether an entity is standing on the 'edge'
of a tile.
"""
func on_area_exited(entity_pos_tracker : Dictionary, floor_area : Area2D, entity : Entity, state : int):
	if (state == floor_area.WALKABLE):
		print(entity.name + " exited " + floor_area.name);
		print(entity_pos_tracker[entity][AREA_SET]);
		var tilemap_index = floor_area.get_parent().z_index;	
		if (entity_pos_tracker[entity][AREA_SET].has(tilemap_index)):
			entity_pos_tracker[entity][AREA_SET].erase(tilemap_index);
	
"""
Attempts to find the four adjacent tiles of where a specific entity is, then writes these into
	the entity_pos_tracker dictionary.
	
Searches all layers below (for ledge dropping).
If there is no adjacent tile in a specific direction (etc no tile to the North), 
the function instead fills in the entity_pos_tracker with the entity's CURRENT_TILE.
"""
func fill_adjacent_tiles(entity_pos_tracker : Dictionary, entity : Entity, tilemaps : Dictionary):
	#INCLUDE LAYER ABOVE LATER WHEN JUMPING IS IMPLEMENTED
	
	var current_layer = entity_pos_tracker[entity][CURRENT_Z] - 1;
	
	#reset tiles to current tile. we use these as a conditional check to see if we've found the adj tile already.
	var current_tile = entity_pos_tracker[entity][CURRENT_TILE];
	entity_pos_tracker[entity][NORTH_TILE] = current_tile;
	entity_pos_tracker[entity][EAST_TILE] = current_tile;
	entity_pos_tracker[entity][SOUTH_TILE] = current_tile;
	entity_pos_tracker[entity][WEST_TILE] = current_tile;
	
	for i in range(current_layer, -1, -1): #ok so i don't hate pythonic languages but this is the dumbest syntax i've ever seen. i may be biased.
		var tilemap = tilemaps[i];
		var above_coords = Functions.get_above_tile_coords(current_tile, current_layer, i);
		var north_coords = Functions.get_adjacent_tile_coords(above_coords, Globals.side.NORTH);
		var east_coords = Functions.get_adjacent_tile_coords(above_coords, Globals.side.EAST);
		var south_coords = Functions.get_adjacent_tile_coords(above_coords, Globals.side.SOUTH);
		var west_coords = Functions.get_adjacent_tile_coords(above_coords, Globals.side.WEST);
		set_adjacent_tile(entity_pos_tracker, entity, tilemap, current_tile, north_coords, NORTH_TILE);
		set_adjacent_tile(entity_pos_tracker, entity, tilemap, current_tile, east_coords, EAST_TILE);
		set_adjacent_tile(entity_pos_tracker, entity, tilemap, current_tile, south_coords, SOUTH_TILE);
		set_adjacent_tile(entity_pos_tracker, entity, tilemap, current_tile, west_coords, WEST_TILE);
		
"""
Sets the position of a tile adjacent to an entity in a certain direction (only if there is 
actually an adjacent tile there)
"""
func set_adjacent_tile(entity_pos_tracker : Dictionary, entity : Entity, tilemap : TileMap, current_tile : Vector2, coords : Vector2, direction : String) -> void:
	if (entity_pos_tracker[entity][direction] == current_tile):
		if (tilemap.get_cellv(coords) != tilemap.INVALID_CELL):
			entity_pos_tracker[entity][direction] = coords;
		
