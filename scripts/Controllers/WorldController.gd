extends Node2D
"""
World controller.  A resource run by the Main controller.
Should handle world-related functions such as:
	Placing objects or enemies in the world
	Grouping said objects/enemies
	Switching out areas/tilesets when the player moves to a different location
"""

#listeners
const LISTENER_PLAYER_SHOT = "_on_player_shot";
const LISTENER_ON_AREA_ENTERED = "_on_area_entered";
const LISTENER_ON_AREA_EXITED = "_on_area_exited";
const LISTENER_ON_CHANGED_ENTITY_POSITION = "_on_changed_entity_position";
const LISTENER_ON_FELL_BELOW_THRESHOLD = "_on_fell_below_threshold";
const LISTENER_ON_FINISHED_FALLING = "_on_finished_falling";

#module loading
var damage_control = preload("res://scripts/Controllers/DamageController.gd").new();

#constants, dictionaries and their const string names
#############################################################################################################
var entity_z_tracker : Dictionary = {};
const CURRENT_Z = "Current_Z"; #int. We store the z index layer that the entity is standing ON TOP OF, NOT the layer we're IN
const QUEUE = "Queue"; #Array. really shitty name. when entity enters a tilemap area, the tilemap is pushed to queue. 
							  #if entity leaves tilemap area, tilemap is popped from queue. used to check if an entity can 
							  #fall off an edge (because solely using entity position for this means you can fall off the
							  #edge with some of your 'body' still on the ledge)
#############################################################################################################

#############################################################################################################
var entity_tile_tracker : Dictionary = {}; #tracks positions of tiles adjacent to entity.  
										   #can pick tiles on a lower z-index. 
										   #will pick the tile with the HIGHEST z index possible.
const CURRENT_TILE = "Current_Tile"; #Vector2 #the tile we stand ON TOP OF.
const NORTH_TILE = "North_Tile"; #Vector2. north is top right btw
const EAST_TILE = "East_Tile"; #Vector2
const SOUTH_TILE = "South_Tile"; #Vector2
const WEST_TILE = "West_Tile"; #Vector2
#if there is no tile N/E/S/W tile, we make it equal to CURRENT_TILE.
#############################################################################################################

#############################################################################################################
var entity_colliders : Dictionary = {}; #handles the four personal colliders surrounding an entity
const STATIC_BODY = "Static_Body"; #StaticBody2D. the static body node that contains all four colliders
const NORTH_WALL = "North_Wall"; #CollisionPolygon2D. as usual, north = top-right.
const EAST_WALL = "East_Wall"; #CollisionPolygon2D
const SOUTH_WALL = "South_Wall"; #CollisionPolygon2D
const WEST_WALL = "West_Wall"; #CollisionPolygon2D
#############################################################################################################

#############################################################################################################
var entity_redraw_tracker : Dictionary = {}; #handles info required to 'redraw' an entity's sprite when
											 #the entity is falling between two tiles of different z-indexes
											 #which normally results in the top half of the sprite being BEHIND
											 #the higher tile which also drives me nuts
const REDRAW = "Redraw"; #bool. whether or not we need to redraw entity. activates when entity is falling between
							   #two tiles. deactivates when not falling between two tiles.
const NORTH_MASK = "North_Mask"; #bool. as usual, north = top right.
const EAST_MASK = "East_Mask"; #bool
const SOUTH_MASK = "South_Mask"; #bool
const WEST_MASK = "West_Mask"; #bool
const ABOVE_MASK = "Above_Mask"; #Vector2. can you believe i need to store this, only thing stopping me going to 3d is that i don't understand 3d

#mask preloading
const FALLING_SPRITE_MASK = preload("res://assets/shaders/falling_sprite_mask.tres"); #shader that hides the parts of the sprite we're not supposed to see
const TEXTURE_NORTH_MASK = preload("res://assets/masks/template_block_hider_N.png");
const TEXTURE_WEST_MASK = preload("res://assets/masks/template_block_hider_W.png");
const TEXTURE_NO_MASK = preload("res://assets/masks/template_block_nomask.png"); #used for directions that don't need a mask
const TEXTURE_ALL_MASK = preload("res://assets/masks/template_block_hider.png"); #used for east, south, and above tiles

var NORTH_LINE_MASK_A : Vector2 = Vector2(0, - Globals.TILE_HEIGHT/2);
var NORTH_LINE_MASK_B : Vector2 = Vector2(Globals.TILE_WIDTH/2, 0);
var EAST_LINE_MASK_A : Vector2 = Vector2(0, - Globals.TILE_HEIGHT/2);
var EAST_LINE_MASK_B : Vector2 = Vector2(Globals.TILE_WIDTH/2, - Globals.TILE_HEIGHT);
var SOUTH_LINE_MASK_A : Vector2 = Vector2(- Globals.TILE_WIDTH/2, - Globals.TILE_HEIGHT);
var SOUTH_LINE_MASK_B : Vector2 = Vector2(0, - Globals.TILE_HEIGHT/2);
var WEST_LINE_MASK_A : Vector2 = Vector2(- Globals.TILE_WIDTH/2, 0);
var WEST_LINE_MASK_B : Vector2 = Vector2(0, - Globals.TILE_HEIGHT/2);


#shader parameter names
const TEXTURE_PARAM = "mask_texture_"; #append N/E/S/W/A for direction
const DIST_PARAM = "mask_to_sprite_dist_"; #append N/E/S/W/A for direction
const LINE_PARAM = "line_"; #append N/E/S/W, then a or b
const BOOL_PARAM = "is_adj_"; #append N/E/S/W
const SPRITE_POS_PARAM = "sprite_pos";
const SPRITE_SCALE_PARAM = "sprite_scale";
#############################################################################################################

#edge directions for sprite border box. currently not needed unless i want to relive the moment where i fall off an edge and my fps drops from 120 to 40
const DIRECTION = "Direction";
const POINT = "Point"; #intersection point
enum dir {NONE = -1, LEFT = 0, BOT = 1, RIGHT = 2, TOP = 3, EXTEND = 4};

var tilemaps : Dictionary = {}; #stores all tilemaps. key is their z-index.
var walls : Dictionary = {}; #stores all WALL colliders. key is their z-index.
var ledges : Dictionary = {}; #stores all LEDGE colliders. key is z-index.
var sprites_to_delete : Array = []; #stores sprites to delete in the next iteration of _physics_process. 
									#if it gets too laggy i have to change this to re-use the sprite AHHHH

"""
Initialises the Z tracker dictionary, which contains:
	An entity as its key, and another dictionary as its value.
	The second dictionary contains:
		Current Z Index
		Queue of other 'floor' areas that the entity is in
		Current tile
		North/East/South/West Adjacent tiles.
"""
func init_z_tracker(world : Node2D):
	#should try to take a signal whenever an entity is added or removed from the world (but that's for later!)
	
	for world_child in world.get_children():
		if (world_child is TileMap):
			var index = world_child.z_index; 
			for tilemap_child in world_child.get_children():
				if (tilemap_child is Entity):
					init_entity_dict(tilemap_child, index, world);
					
			tilemaps[index] = world_child;
			walls[index] = world_child.find_node(Globals.STATIC_BODY_WALLS_NAME, false, false);
			ledges[index] = world_child.find_node(Globals.STATIC_BODY_LEDGES_NAME, false, false);
			
	for key in entity_z_tracker:
		manage_colliders(key);
		manage_personal_colliders(key);
		key.connect(key.SIGNAL_CHANGED_ENTITY_POSITION, self, self.LISTENER_ON_CHANGED_ENTITY_POSITION);
		key.connect(key.SIGNAL_FELL_BELOW_THRESHOLD, self, self.LISTENER_ON_FELL_BELOW_THRESHOLD);
		key.connect(key.SIGNAL_FINISHED_FALLING, self, self.LISTENER_ON_FINISHED_FALLING);
		_on_changed_entity_position(key, key.position);

"""
Called every process by parent, Main. 
Checks what entities need to be 'redrawn', then does that.
Entities need to be redrawn if they are BETWEEN TWO TILES OF DIFFERENT HEIGHTS.

Redrawing used to duplicate the top portion of the entity's sprite so it didn't 
appear behind tiles when it should be in front.  It also dropped by fps by about 80

now i use shaders, which instead of manually erasing pixels off the sprite, masks said pixels instead
"""
func _physics_process(delta):
	while (sprites_to_delete.size() > 0):
		var sprite = sprites_to_delete.pop_front();
		sprite.free();
	
	for entity in entity_redraw_tracker.keys():

		if (not entity_redraw_tracker[entity][REDRAW]):
			continue;

		#print(entity.name + " falling at : " + str(entity_tile_tracker[entity][CURRENT_TILE]));

		var dummy_node : Node2D = Node2D.new();
		var sprite_copy : Sprite = entity.sprite.duplicate();
		for n in sprite_copy.get_children():
			n.queue_free();

		var z_index : int = entity_z_tracker[entity][CURRENT_Z];
		dummy_node.position = entity.position - Vector2(0, Globals.TILE_HEIGHT);
		sprite_copy.position = entity.sprite.position + Vector2(0, Globals.TILE_HEIGHT);


		var tilemap : TileMap = tilemaps[z_index];
		var centre_pos = tilemap.map_to_world(tilemap.world_to_map(entity.position)) + Vector2(0, Globals.TILE_HEIGHT/2);

		set_shader_param(entity, centre_pos, NORTH_MASK, LINE_PARAM + "N_" , 
				BOOL_PARAM + "N", NORTH_LINE_MASK_A, NORTH_LINE_MASK_B);
		set_shader_param(entity, centre_pos, EAST_MASK, LINE_PARAM + "E_" , 
				BOOL_PARAM + "E", EAST_LINE_MASK_A, EAST_LINE_MASK_B);
		set_shader_param(entity, centre_pos, SOUTH_MASK, LINE_PARAM + "S_" , 
				BOOL_PARAM + "S", SOUTH_LINE_MASK_A, SOUTH_LINE_MASK_B);
		set_shader_param(entity, centre_pos, WEST_MASK, LINE_PARAM + "W_" , 
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
func set_shader_param(entity : Entity, centre_pos : Vector2, direction : String, line_param : String, bool_param : String, line_a : Vector2, line_b : Vector2):
	if (entity_redraw_tracker[entity][direction] == true):
		FALLING_SPRITE_MASK.set_shader_param(line_param + "a", centre_pos + line_a);
		FALLING_SPRITE_MASK.set_shader_param(line_param + "b", centre_pos + line_b);
		FALLING_SPRITE_MASK.set_shader_param(bool_param, true);
	else:
		FALLING_SPRITE_MASK.set_shader_param(bool_param, false);

	
"""
Listener function that runs when an entity changes position.
Updates what tile the entity is on, calculates adjacent tiles, and makes colliders.

TODO: change to only run fully if the entity has changed what isometric tile it's on, instead of running every single time we make a small movement
"""
func _on_changed_entity_position(entity : Entity, pos : Vector2):
	var z_index = entity_z_tracker[entity][CURRENT_Z];
	var tilemap = tilemaps[z_index - 1];
	var current_tile = tilemap.world_to_map(pos) + Vector2(1,1);
						
	if (entity_tile_tracker[entity][CURRENT_TILE] != current_tile or not entity_z_tracker[entity][QUEUE].has(z_index - 1)): #only need to do recalculations if we change our current tile OR we're not in the 'tilemap' that we should be in
		#print("changed tile: " + str(current_tile) + ", layer: " + str(tilemap.name) + " pos: " + str(pos));
		entity_tile_tracker[entity][CURRENT_TILE] = current_tile;
		fill_adjacent_tiles(entity);
		#fill_personal_colliders(entity, current_tile, tilemap);
	
		if (!entity.falling): #NOT FALLING
			if (tilemap.get_cellv(current_tile) == -1): #AND THERE'S NO TILE WHERE WE'RE STANDING
				if (!entity_z_tracker[entity][QUEUE].has(z_index - 1)): #AND NO PART OF OUR COLLISION AREA IS TOUCHING THE FLOOR
					trigger_falling(entity, pos);
		
		elif (entity.falling): 
			fill_mask_booleans(entity, tilemaps[z_index], current_tile + Vector2(-1, -1));
	
"""
Listener function that runs when an entity falls 'below' the special case threshold where the entity's
sprite is between tiles of different heights. At this point we can reparent the entity because there is 
no longer a need to compensate for ysorting.
"""
func _on_fell_below_threshold(entity : Entity):
	entity_redraw_tracker[entity][REDRAW] = false;

"""
Listener function that runs when an entity finishes falling.
If they are still on an empty tile, then they continue to fall.
"""
func _on_finished_falling(entity : Entity):
	var tilemap = tilemaps[entity_z_tracker[entity][CURRENT_Z] - 1];
	var current_tile = entity_tile_tracker[entity][CURRENT_TILE];
	entity_redraw_tracker[entity][REDRAW] = false;
	
	if (tilemap.get_cellv(current_tile) == -1): #AND THERE'S NO TILE WHERE WE'RE STANDING
		trigger_falling(entity, entity.position);

"""
Listener function that runs when a layer's floor area is entered by an entity.
Adds the layer's z index to a queue. Used to keep track of whether an entity is standing on the 'edge'
of a tile.
"""
func _on_area_entered(floor_area : Area2D, entity : Entity):
	var tilemap_index = floor_area.get_parent().z_index;
	if (!entity_z_tracker[entity][QUEUE].has(tilemap_index)):
		entity_z_tracker[entity][QUEUE].push_back(tilemap_index);
	
"""
Listener function that runs when an entity leaves a layer's floor area.
Removes the layer's z index to a queue. Used to keep track of whether an entity is standing on the 'edge'
of a tile.
"""
func _on_area_exited(floor_area : Area2D, entity : Entity):
	var tilemap_index = floor_area.get_parent().z_index;	
	if (entity_z_tracker[entity][QUEUE].has(tilemap_index)):
		entity_z_tracker[entity][QUEUE].erase(tilemap_index);

"""
Listener function for player shot signals.  Creates an instance of the player shot in the world.
"""
func _on_player_shot(shooter : Player, shot_type, goal : Vector2):
	var tilemap = shooter.get_parent(); 
	if (!tilemap):
		print("Shooter has no parent, unable to place shooting instance.");
	else:
		var shot_instance = shot_type.instance();
		if (shot_instance is Bullet):
			tilemap.add_child(shot_instance);
			shot_instance.init(shooter.position, goal);
			shot_instance.connect(shot_instance.SIGNAL_HIT_ENTITY, damage_control, damage_control.LISTENER_DAMAGE_ENTITY);
		
"""
Initialises an entity's dictionary entities so this resource can store relevant info about each entity.
"""
func init_entity_dict(entity : Entity, z_index : int, world : Node2D):
	entity_z_tracker[entity] = {CURRENT_Z: z_index, QUEUE: []};
	entity_tile_tracker[entity] = 	{CURRENT_TILE: Vector2(0, 0), 
									 NORTH_TILE: Vector2(0, 0), EAST_TILE: Vector2(0, 0),
									 SOUTH_TILE: Vector2(0, 0), WEST_TILE: Vector2(0, 0)};
			
	var static_body = StaticBody2D.new(); world.add_child(static_body);
#	var north_wall = CollisionPolygon2D.new(); static_body.add_child(north_wall);
#	var east_wall = CollisionPolygon2D.new(); static_body.add_child(east_wall);
#	var south_wall = CollisionPolygon2D.new(); static_body.add_child(south_wall);
#	var west_wall = CollisionPolygon2D.new(); static_body.add_child(west_wall);
			
	static_body.set_collision_layer(64);
	static_body.set_collision_mask(12);
			
#	entity_colliders[entity] = {STATIC_BODY: static_body, 
#			NORTH_WALL: north_wall, EAST_WALL: east_wall,
#			SOUTH_WALL: south_wall, WEST_WALL: west_wall};
			
	entity_redraw_tracker[entity] = 	{REDRAW: false, NORTH_MASK: Vector2(INF, INF), 
										 EAST_MASK: Vector2(INF, INF), SOUTH_MASK: Vector2(INF, INF),
										 WEST_MASK: Vector2(INF, INF), ABOVE_MASK: Vector2(INF, INF)};
		
"""
Sets exclusion of world colliders to ignore or not ignore certain entities,
based off where they are on the tilemap.  For example, players on ground level shouldn't be
hitting walls that are a level up.
"""
func manage_colliders(entity : Entity):
	var exclusion_index = entity_z_tracker[entity][CURRENT_Z] - 1;
	
	for i in range(tilemaps.size()):
		if (walls[i]):
			if (i == exclusion_index):
				walls[i].remove_collision_exception_with(entity);
			else:
				walls[i].add_collision_exception_with(entity);
				
		if (ledges[i]):
			if (i == exclusion_index):
				ledges[i].remove_collision_exception_with(entity);
			else:
				ledges[i].add_collision_exception_with(entity);
	
"""
Iterates through each entity's personal colliders and excludes other entities.
"""
func manage_personal_colliders(entity : Entity):
	var entities : Array = entity_colliders.keys();
	for each in entities:
		if (each != entity):
			entity_colliders[each][STATIC_BODY].add_collision_exception_with(entity);
			entity_colliders[entity][STATIC_BODY].add_collision_exception_with(each);
	
"""
Moves entity across tilemaps so they're YSorted properly.
Deferred call.
"""
func reparent_entity(entity : Entity, new_parent : TileMap):
	var current_parent = entity.get_parent();
	current_parent.remove_child(entity);
	new_parent.add_child(entity);
	entity_z_tracker[entity][CURRENT_Z] = new_parent.z_index;
	_on_changed_entity_position(entity, entity.position);
	manage_colliders(entity);
	
"""
Sets an entity to fall to a tile below them. Runs at the 'start' of falling.
Because the entity will be 'between' tiles for a short while, we set the REDRAW tag to true
so that the top of the entity is does not appear to be drawn behind the 'higher' of the 
two tiles it is between.
"""
func trigger_falling(entity : Entity, pos : Vector2):
	var current_z : int = entity_z_tracker[entity][CURRENT_Z] - 1;
	entity.falling_checkpoint = pos.y;
	entity.position = entity.position + Vector2(0, Globals.TILE_HEIGHT);
	entity.sprite.position.y = -Globals.TILE_HEIGHT;
	entity.falling = true;
	entity.falling_threshold = false;
	reparent_entity(entity, tilemaps[current_z]);
	entity_redraw_tracker[entity][REDRAW] = true;
		
"""
Attempts to find the four adjacent tiles of where a specific entity is, then writes these into
	the entity_z_tracker dictionary.
	
Searches the layer above (for jumping), the same layer, and all layers below (for ledge dropping).
If there is no adjacent tile in a specific direction (etc no tile to the North), the function instead
fills in the entity_z_tracker with the entity's CURRENT_TILE.
"""
func fill_adjacent_tiles(entity : Entity):
	#INCLUDE LAYER ABOVE LATER WHEN JUMPING IS IMPLEMENTED
	
	var current_layer = entity_z_tracker[entity][CURRENT_Z] - 1;
	
	#reset tiles to current tile. we use these as a conditional check to see if we've found the adj tile already.
	var current_tile = entity_tile_tracker[entity][CURRENT_TILE];
	entity_tile_tracker[entity][NORTH_TILE] = current_tile;
	entity_tile_tracker[entity][EAST_TILE] = current_tile;
	entity_tile_tracker[entity][SOUTH_TILE] = current_tile;
	entity_tile_tracker[entity][WEST_TILE] = current_tile;
	
	for i in range(current_layer, -1, -1): #ok so i don't hate pythonic languages but this is the dumbest syntax i've ever seen. i may be biased.
		var tilemap = tilemaps[i];
		
		var offset : Vector2 = (current_layer - i) * Vector2.ONE;
		var layer_centre = current_tile + offset;
		var north_coords = layer_centre + Vector2(0, -1);
		var east_coords = layer_centre + Vector2(1, 0);
		var south_coords = layer_centre + Vector2(0, 1);
		var west_coords = layer_centre + Vector2(-1, 0);
		
		set_adjacent_tile(entity, tilemap, current_tile, north_coords, NORTH_TILE);
		set_adjacent_tile(entity, tilemap, current_tile, east_coords, EAST_TILE);
		set_adjacent_tile(entity, tilemap, current_tile, south_coords, SOUTH_TILE);
		set_adjacent_tile(entity, tilemap, current_tile, west_coords, WEST_TILE);
		
"""
Sets the position of a tile adjacent to an entity in a certain direction (only if there is 
actually an adjacent tile there)
"""
func set_adjacent_tile(entity : Entity, tilemap : TileMap, current_tile : Vector2, coords : Vector2, direction : String):
	if (entity_tile_tracker[entity][direction] == current_tile):
		if (tilemap.get_cellv(coords) != tilemap.INVALID_CELL):
			entity_tile_tracker[entity][direction] = coords;

"""
Defines the personal colliders of an entity, then disables/enables them based on the
entity's adjacent tiles.
Currently this function assumes that every shape has four sides only, and may be expanded in the future
to include stuff like circular tables/tiles, etc.
"""
func fill_personal_colliders(entity : Entity, current_tile : Vector2, tilemap : TileMap):
	var coordinates : Vector2 = tilemap.map_to_world(current_tile) + Vector2(0, -tilemap.cell_size.y);
	
	var top = coordinates; #this is a pretty flawed method if we ever change tile shapes
	var right = coordinates + Vector2(tilemap.cell_size.x/2, tilemap.cell_size.y/2); 
	var bot = coordinates + Vector2(0, tilemap.cell_size.y);
	var left = coordinates + Vector2(-tilemap.cell_size.x/2, tilemap.cell_size.y/2); 

	entity_colliders[entity][NORTH_WALL].set_polygon(PoolVector2Array([top, right]));
	entity_colliders[entity][EAST_WALL].set_polygon(PoolVector2Array([right, bot]));
	entity_colliders[entity][SOUTH_WALL].set_polygon(PoolVector2Array([bot, left]));
	entity_colliders[entity][WEST_WALL].set_polygon(PoolVector2Array([left, top]));
	
	set_personal_collider(entity, NORTH_TILE, NORTH_WALL, current_tile);
	set_personal_collider(entity, EAST_TILE, EAST_WALL, current_tile);
	set_personal_collider(entity, SOUTH_TILE, SOUTH_WALL, current_tile);
	set_personal_collider(entity, WEST_TILE, WEST_WALL, current_tile);
	
"""
Sets a personal collider to enabled or disabled based on whether its entity has 
an adjacent tile in that direction or not
"""
func set_personal_collider(entity : Entity, tile_direction : String, wall_direction : String, current_tile : Vector2):
	if (entity_tile_tracker[entity][tile_direction] == current_tile):
		entity_colliders[entity][wall_direction].set_disabled(false);
	else:
		entity_colliders[entity][wall_direction].set_disabled(true);
		
"""
For falling entities only.  Checks if there is a tiles around the entity's
current position, and stores their positions to use as a shader mask (for sprite redrawing).
If there is no tile in a specific direction, stores their value as Vector2(INF, INF)
"""
func fill_mask_booleans(entity : Entity, tilemap : TileMap, current_tile : Vector2):
	var north_tile_pos = current_tile + Vector2(0, -1);
	var east_tile_pos = current_tile + Vector2(1, 0);
	var south_tile_pos = current_tile + Vector2(0, 1);
	var west_tile_pos = current_tile + Vector2(-1, 0);
#	var above_tile_pos = current_tile + Vector2(-1, -1);
	
	set_mask_boolean(entity, tilemap, north_tile_pos, NORTH_MASK);
	set_mask_boolean(entity, tilemap, east_tile_pos, EAST_MASK);
	set_mask_boolean(entity, tilemap, south_tile_pos, SOUTH_MASK);
	set_mask_boolean(entity, tilemap, west_tile_pos, WEST_MASK);
	
#	if (tilemaps.size() > tilemap.z_index + 2):
#		var above_tilemap : TileMap = tilemaps[tilemap.z_index + 1];
#		set_mask_position(entity, above_tilemap, above_tile_pos, ABOVE_MASK);
		
	#print(entity.name + " is at : " + str(current_tile) + ", layer: " + tilemap.name + ", nmask: " + str(entity_redraw_tracker[entity][NORTH_MASK]) + ", wmask: " + str(entity_redraw_tracker[entity][WEST_MASK])  + ", emask: " + str(entity_redraw_tracker[entity][EAST_MASK])  + ", smask: " + str(entity_redraw_tracker[entity][SOUTH_MASK])); 
	
"""
Sets the position of an entity's personal shader mask if there is a tile adjacent
to the entity in a certain direction.  If there is no tile adjacent, sets position to Vector2(INF, INF).
"""
func set_mask_boolean(entity : Entity, tilemap : TileMap, tile_pos : Vector2, mask_direction : String):
	if (tilemap.get_cellv(tile_pos) != tilemap.INVALID_CELL): #if there is a tile in a certan direction
		#var mask_pos : Vector2 = tilemap.map_to_world(tile_pos);
		#entity_redraw_tracker[entity][mask_direction] = mask_pos;
		entity_redraw_tracker[entity][mask_direction] = true;
	else:
		#entity_redraw_tracker[entity][mask_direction] = Vector2(INF, INF);
		entity_redraw_tracker[entity][mask_direction] = false;
