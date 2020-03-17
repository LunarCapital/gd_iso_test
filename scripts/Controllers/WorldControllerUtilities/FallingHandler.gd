extends Node2D
"""
Handles the mechanics behind entities falling, such as:
	Checking if an entity is eligible to fall (and commencing the fall process)
	Redrawing falling entitites to be depth sorted correctly.
"""
#signals
signal _request_reparent(entity, tilemap);
const SIGNAL_REQUEST_REPARENT = "_request_reparent";

#############################################################################################################
#entity_redraw_tracker value names
#############################################################################################################
const REDRAW = "Redraw"; #bool. whether or not we need to redraw entity. activates when entity is falling between
							   #two tiles. deactivates when not falling between two tiles.
const NORTH_MASK = "North_Mask"; #bool. as usual, north = top right.
const EAST_MASK = "East_Mask"; #bool
const SOUTH_MASK = "South_Mask"; #bool
const WEST_MASK = "West_Mask"; #bool
const ABOVE_MASK = "Above_Mask"; #Vector2. can you believe i need to store this, only thing stopping me going to 3d is that i don't understand 3d
#############################################################################################################

#############################################################################################################
#mask specifications. hardcoded because every tile will ALWAYS be the same shape/size.
#############################################################################################################
var NORTH_LINE_MASK_A : Vector2 = Vector2(0, - Globals.TILE_HEIGHT/2);
var NORTH_LINE_MASK_B : Vector2 = Vector2(Globals.TILE_WIDTH/2, 0);
var EAST_LINE_MASK_A : Vector2 = Vector2(0, - Globals.TILE_HEIGHT/2);
var EAST_LINE_MASK_B : Vector2 = Vector2(Globals.TILE_WIDTH/2, - Globals.TILE_HEIGHT);
var SOUTH_LINE_MASK_A : Vector2 = Vector2(- Globals.TILE_WIDTH/2, - Globals.TILE_HEIGHT);
var SOUTH_LINE_MASK_B : Vector2 = Vector2(0, - Globals.TILE_HEIGHT/2);
var WEST_LINE_MASK_A : Vector2 = Vector2(- Globals.TILE_WIDTH/2, 0);
var WEST_LINE_MASK_B : Vector2 = Vector2(0, - Globals.TILE_HEIGHT/2);
#############################################################################################################

#############################################################################################################
#shader and its parameter names
#############################################################################################################
const FALLING_SPRITE_MASK = preload("res://assets/shaders/falling_sprite_mask.tres"); #shader that hides the parts of the sprite we're not supposed to see
const TEXTURE_PARAM = "mask_texture_"; #append N/E/S/W/A for direction
const DIST_PARAM = "mask_to_sprite_dist_"; #append N/E/S/W/A for direction
const LINE_PARAM = "line_"; #append N/E/S/W, then a or b
const BOOL_PARAM = "is_adj_"; #append N/E/S/W
const SPRITE_POS_PARAM = "sprite_pos";
const SPRITE_SCALE_PARAM = "sprite_scale";
#############################################################################################################

#globals
var sprites_to_delete : Array = []; #stores sprites to delete in the next iteration of _physics_process. 
									#if it gets too laggy i have to change this to re-use the sprite AHHHH


func init_redraw_tracker(entity_redraw_tracker : Dictionary, entity : Entity):
	entity_redraw_tracker[entity] = 	{REDRAW: false, NORTH_MASK: Vector2(INF, INF), 
										 EAST_MASK: Vector2(INF, INF), SOUTH_MASK: Vector2(INF, INF),
										 WEST_MASK: Vector2(INF, INF), ABOVE_MASK: Vector2(INF, INF)};
		
"""
Listener function that runs when an entity falls 'below' the special case threshold where the entity's
sprite is between tiles of different heights. At this point we can reparent the entity because there is 
no longer a need to compensate for ysorting.
"""
func on_fell_below_threshold(entity_redraw_tracker, entity : Entity):
	entity_redraw_tracker[entity][REDRAW] = false;

"""
Listener for when an entity has finished falling. Updates tracking dictionaries.
"""
func on_finished_falling(entity_redraw_tracker : Dictionary, tilemaps : Dictionary, entity_pos_tracker : Dictionary, CURRENT_Z : String, CURRENT_TILE : String, entity : Entity):
	var tilemap = tilemaps[entity_pos_tracker[entity][CURRENT_Z] - 1];
	var current_tile = entity_pos_tracker[entity][CURRENT_TILE];
	entity_redraw_tracker[entity][REDRAW] = false;
	
	if (tilemap.get_cellv(current_tile) == -1): #AND THERE'S NO TILE WHERE WE'RE STANDING
		trigger_falling(entity_redraw_tracker, entity_pos_tracker, CURRENT_Z, entity, entity.position, tilemaps);

"""
Checks what entities need to be 'redrawn', then does that.
Entities need to be redrawn if they are BETWEEN TWO TILES OF DIFFERENT HEIGHTS.
Works by duplicating a sprite on a higher z-level, and masking pixels via shader
"""
func redraw_falling_sprite(entity_redraw_tracker : Dictionary, entity_pos_tracker : Dictionary, CURRENT_Z : String, tilemaps : Dictionary):
	while (sprites_to_delete.size() > 0):
		var sprite = sprites_to_delete.pop_front();
		sprite.free();
	
	for entity in entity_redraw_tracker.keys():

		if (not entity_redraw_tracker[entity][REDRAW]):
			continue;

		var dummy_node : Node2D = Node2D.new();
		var sprite_copy : Sprite = entity.sprite.duplicate();
		for n in sprite_copy.get_children():
			n.queue_free();

		var z_index : int = entity_pos_tracker[entity][CURRENT_Z];
		dummy_node.position = entity.position - Vector2(0, Globals.TILE_HEIGHT);
		sprite_copy.position = entity.sprite.position + Vector2(0, Globals.TILE_HEIGHT);

		var tilemap : TileMap = tilemaps[z_index];
		var centre_pos = tilemap.map_to_world(tilemap.world_to_map(entity.position)) + Vector2(0, Globals.TILE_HEIGHT/2);

		set_shader_param(entity_redraw_tracker, entity, centre_pos, NORTH_MASK, LINE_PARAM + "N_" , 
						 BOOL_PARAM + "N", NORTH_LINE_MASK_A, NORTH_LINE_MASK_B);
		set_shader_param(entity_redraw_tracker, entity, centre_pos, EAST_MASK, LINE_PARAM + "E_" , 
						 BOOL_PARAM + "E", EAST_LINE_MASK_A, EAST_LINE_MASK_B);
		set_shader_param(entity_redraw_tracker, entity, centre_pos, SOUTH_MASK, LINE_PARAM + "S_" , 
						 BOOL_PARAM + "S", SOUTH_LINE_MASK_A, SOUTH_LINE_MASK_B);
		set_shader_param(entity_redraw_tracker, entity, centre_pos, WEST_MASK, LINE_PARAM + "W_" , 
						 BOOL_PARAM + "W", WEST_LINE_MASK_A, WEST_LINE_MASK_B);

		FALLING_SPRITE_MASK.set_shader_param(SPRITE_POS_PARAM, dummy_node.position + sprite_copy.position + sprite_copy.offset*sprite_copy.scale);
		FALLING_SPRITE_MASK.set_shader_param(SPRITE_SCALE_PARAM, sprite_copy.scale);

		sprite_copy.set_material(FALLING_SPRITE_MASK);
		dummy_node.add_child(sprite_copy);
		tilemaps[z_index + 1].add_child(dummy_node);
		sprites_to_delete.append(dummy_node);

"""
Sets the shader params for a specific direction (North, East, West, South, Above).
Uses the stored vector2 for an entity's 'personal masks'. Recall that the vec2 being (INF, INF) means NO mask
is required (because there's no tile in that direction). 
"""
func set_shader_param(entity_redraw_tracker : Dictionary, entity : Entity, centre_pos : Vector2, direction : String, line_param : String, bool_param : String, line_a : Vector2, line_b : Vector2):
	if (entity_redraw_tracker[entity][direction] == true):
		FALLING_SPRITE_MASK.set_shader_param(line_param + "a", centre_pos + line_a);
		FALLING_SPRITE_MASK.set_shader_param(line_param + "b", centre_pos + line_b);
		FALLING_SPRITE_MASK.set_shader_param(bool_param, true);
	else:
		FALLING_SPRITE_MASK.set_shader_param(bool_param, false);

"""
Sets an entity to fall to a tile below them. Runs at the 'start' of falling.
Because the entity will be 'between' tiles for a short while, we set the REDRAW tag to true
so that the top of the entity is does not appear to be drawn behind the 'higher' of the 
two tiles it is between.
"""
func trigger_falling(entity_redraw_tracker : Dictionary, entity_pos_tracker : Dictionary, CURRENT_Z : String, entity : Entity, pos : Vector2, tilemaps : Dictionary):
	var current_z : int = entity_pos_tracker[entity][CURRENT_Z] - 1;
	entity.falling_checkpoint = pos.y;
	entity.position = entity.position + Vector2(0, Globals.TILE_HEIGHT);
	entity.sprite.position.y = -Globals.TILE_HEIGHT;
	entity.falling = true;
	entity.falling_threshold = false;
	emit_signal(SIGNAL_REQUEST_REPARENT, entity, tilemaps[current_z]);
	entity_redraw_tracker[entity][REDRAW] = true;
	
"""
For falling entities only.  Checks if there is a tiles around the entity's
current position, and stores their positions to use as a shader mask (for sprite redrawing).
If there is no tile in a specific direction, stores their value as Vector2(INF, INF)
"""
func fill_mask_booleans(entity_redraw_tracker : Dictionary, entity : Entity, tilemap : TileMap, current_tile : Vector2):
	var north_tile_pos = current_tile + Vector2(0, -1);
	var east_tile_pos = current_tile + Vector2(1, 0);
	var south_tile_pos = current_tile + Vector2(0, 1);
	var west_tile_pos = current_tile + Vector2(-1, 0);
#	var above_tile_pos = current_tile + Vector2(-1, -1);
	
	set_mask_boolean(entity_redraw_tracker, entity, tilemap, north_tile_pos, NORTH_MASK);
	set_mask_boolean(entity_redraw_tracker, entity, tilemap, east_tile_pos, EAST_MASK);
	set_mask_boolean(entity_redraw_tracker, entity, tilemap, south_tile_pos, SOUTH_MASK);
	set_mask_boolean(entity_redraw_tracker, entity, tilemap, west_tile_pos, WEST_MASK);
	
#	if (tilemaps.size() > tilemap.z_index + 2):
#		var above_tilemap : TileMap = tilemaps[tilemap.z_index + 1];
#		set_mask_position(entity, above_tilemap, above_tile_pos, ABOVE_MASK);
		
	#print(entity.name + " is at : " + str(current_tile) + ", layer: " + tilemap.name + ", nmask: " + str(entity_redraw_tracker[entity][NORTH_MASK]) + ", wmask: " + str(entity_redraw_tracker[entity][WEST_MASK])  + ", emask: " + str(entity_redraw_tracker[entity][EAST_MASK])  + ", smask: " + str(entity_redraw_tracker[entity][SOUTH_MASK])); 
	
"""
Sets the position of an entity's personal shader mask if there is a tile adjacent
to the entity in a certain direction.  If there is no tile adjacent, sets position to Vector2(INF, INF).
"""
func set_mask_boolean(entity_redraw_tracker : Dictionary, entity : Entity, tilemap : TileMap, tile_pos : Vector2, mask_direction : String) -> void:
	if (tilemap.get_cellv(tile_pos) != tilemap.INVALID_CELL): #if there is a tile in a certan direction
		entity_redraw_tracker[entity][mask_direction] = true;
	else:
		entity_redraw_tracker[entity][mask_direction] = false;
