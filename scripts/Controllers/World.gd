extends Resource
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
const LISTENER_ON_CHANGED_ENTITY_VELOCITY = "_on_changed_entity_velocity";

#module loading
var damage_control = preload("res://scripts/Controllers/Damage.gd").new();

#constants
##### Dictionary Constants
#####:Z TRACKER
const CURRENT_Z = "Current_Z"; #int. We store the z index layer that the entity is standing on top of.
const QUEUE = "Queue"; #Array

#####TILE TRACKER
const CURRENT_TILE = "Current_Tile"; #Vector2
	  ########## For these, if there is no adjacent tile, it should be the same as CURRENT_TILE.
const NORTH_TILE = "North_Tile"; #Vector2
const EAST_TILE = "East_Tile"; #Vector2
const SOUTH_TILE = "South_Tile"; #Vector2
const WEST_TILE = "West_Tile"; #Vector2

#####COLLIDERS
const STATIC_BODY = "Static_Body";
const NORTH_WALL = "North";
const EAST_WALL = "East";
const SOUTH_WALL = "South";
const WEST_WALL = "West";

#globals
var entity_z_tracker : Dictionary = {};
var entity_tile_tracker : Dictionary = {};
var entity_colliders : Dictionary = {};
var tilemaps : Dictionary = {};
var colliders : Dictionary = {};

#DEBUG
var moon;
var layer_floor;
var prev_iso_pos;

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
			colliders[index] = world_child.find_node(Globals.STATIC_BODY_WALLS_NAME, false, false);
			
	for key in entity_z_tracker:
		manage_colliders(key);
		manage_personal_colliders(key);
		key.connect(key.SIGNAL_CHANGED_ENTITY_POSITION, self, self.LISTENER_ON_CHANGED_ENTITY_POSITION);
		key.connect(key.SIGNAL_CHANGED_ENTITY_VELOCITY, self, self.LISTENER_ON_CHANGED_ENTITY_VELOCITY);
		_on_changed_entity_position(key, key.position);

	#DEBUG
	moon = world.find_node("Moon");
	layer_floor = world.find_node("Layer0");

#DEBUG
func print_moon_pos():
	var moon_pos = layer_floor.world_to_map(moon.position);
	if (moon_pos != prev_iso_pos):
		prev_iso_pos = moon_pos;
#		print("Moon moved to: (" + str(entity_tile_tracker[moon][CURRENT_TILE]) + ")");
#		print("North: " + str(entity_tile_tracker[moon][NORTH_TILE]));
#		print("East: " + str(entity_tile_tracker[moon][EAST_TILE]));
#		print("South: " + str(entity_tile_tracker[moon][SOUTH_TILE]));
#		print("West: " + str(entity_tile_tracker[moon][WEST_TILE]));
#		print("cartesian coords: " + str(layer_floor.map_to_world(moon_pos)));

"""
Listener function that runs when an entity changes position.
Updates what tile the entity is on, calculates adjacent tiles, and makes colliders.

TODO: change to only run fully if the entity has changed what isometric tile it's on, instead of running every single time we make a small movement
"""
func _on_changed_entity_position(entity : Entity, pos : Vector2):
	var tilemap = tilemaps[entity_z_tracker[entity][CURRENT_Z]];
	var current_tile = tilemap.world_to_map(pos) + Vector2(1, 1);
	
	if (entity_tile_tracker[entity][CURRENT_TILE] != current_tile): #only need to do recalculations if we change our current tile
		print("changed tile: " + str(current_tile));
		entity_tile_tracker[entity][CURRENT_TILE] = current_tile;
		fill_adjacent_tiles(entity);
		fill_personal_colliders(entity, current_tile, tilemap);
	
		#DEBUG STUFF BELOW
		if (!entity.falling): #NOT FALLING
			if (tilemap.get_cellv(current_tile) == -1): #AND THERE'S NO TILE WHERE WE'RE STANDING
				trigger_falling(entity, tilemap, current_tile, pos);
		
		elif (entity.falling): #remember this! if falling, we can't collide with normal walls.
			return;		
		#DEBUG STUFF ABOVE
	
"""
Listener function that runs when an entity changes velocity.
MAY NO LONGER NEED AFTER CHANGES. COME BACK TO THIS.
"""
func _on_changed_entity_velocity(entity : Entity, velocity : Vector2):
	#print("velocity: " + str(velocity));
	var dx = velocity.x;
	var dy = velocity.y;
	
#	if (dy < 0): #NORTH
#		handle_velocity_collision(entity, NORTH_TILE);
#	elif (dy > 0): #SOUTH
#		handle_velocity_collision(entity, SOUTH_TILE);
#	if (dx > 0): #EAST
#		handle_velocity_collision(entity, EAST_TILE);
#	elif (dx < 0): #WEST
#		handle_velocity_collision(entity, WEST_TILE);
#	#Note that the above iS EXTREMELY FLAWED code. Just for testing.

"""
Listener function that runs when a layer's floor area is entered by an entity.
Adds the layer's z index to a queue that is supposed to come into effect if the entity leaves
the layer that it was previously on.
MAY NO LONGER NEED AFTER CHANGES. COME BACK TO THIS.
"""
func _on_area_entered(floor_area : Area2D, entity_area : Area2D):
	print(entity_area.get_parent().name + " entered " + floor_area.name);
	print(floor_area.z_index);
	var tilemap_index = floor_area.get_parent().z_index;
	var entity = entity_area.get_parent();

	var entity_index = entity_z_tracker[entity][CURRENT_Z];
	if (entity_index != tilemap_index):
		if (!entity_z_tracker[entity][QUEUE].has(tilemap_index)):
			entity_z_tracker[entity][QUEUE].push_back(tilemap_index);
	#call_deferred("reparent_entity", entity, tilemaps[index+1]);
	
func _on_area_exited(floor_area : Area2D, entity_area : Area2D):
	print(entity_area.get_parent().name + " exited " + floor_area.name);
	#INCOMPLETE, COME BACK TO THIS AFTER LEDGE DROPPING IS IMPLEMENTED

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
	entity_z_tracker[entity] = {CURRENT_Z: z_index - 1, QUEUE: []}
	entity_tile_tracker[entity] = {CURRENT_TILE: Vector2(0, 0), 
			NORTH_TILE: Vector2(0, 0), EAST_TILE: Vector2(0, 0),
			SOUTH_TILE: Vector2(0, 0), WEST_TILE: Vector2(0, 0)};
			
	var static_body = StaticBody2D.new(); world.add_child(static_body);
	var north_wall = CollisionPolygon2D.new(); static_body.add_child(north_wall);
	var east_wall = CollisionPolygon2D.new(); static_body.add_child(east_wall);
	var south_wall = CollisionPolygon2D.new(); static_body.add_child(south_wall);
	var west_wall = CollisionPolygon2D.new(); static_body.add_child(west_wall);
			
	static_body.set_collision_layer(64);
	static_body.set_collision_mask(12);
			
	entity_colliders[entity] = {STATIC_BODY: static_body, 
			NORTH_WALL: north_wall, EAST_WALL: east_wall,
			SOUTH_WALL: south_wall, WEST_WALL: west_wall};
		
"""
Sets exclusion of world colliders to ignore or not ignore certain entities,
based off where they are on the tilemap.  For example, players on ground level shouldn't be
hitting walls that are a level up.
"""
func manage_colliders(entity : Entity):
	var exclusion_index = entity_z_tracker[entity][CURRENT_Z];
	
	for i in range(colliders.size()):
		if (colliders[i]):
			if (i == exclusion_index):
				colliders[i].remove_collision_exception_with(entity);
			else:
				colliders[i].add_collision_exception_with(entity);
				print("granted exception on layer " + str(i) + " to " + entity.name);
	
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
	entity_z_tracker[CURRENT_Z] = new_parent.z_index;
	
"""
Sets an entity to fall to a tile below them.
"""
func trigger_falling(entity : Entity, tilemap : TileMap, current_tile : Vector2, pos : Vector2):
	var coordinates : Vector2 = tilemap.map_to_world(current_tile);
	var current_z : int = entity_z_tracker[entity][CURRENT_Z];
	for i in range(current_z - 1, -1, -1): #SEARCH FOR A TILE TO DROP TO.
		var offset = Vector2(1, 1) * (current_z - i);
		var lower_current_tile = current_tile + offset;
		if (tilemaps[i].get_cellv(lower_current_tile) != -1): #found tile
			entity.falling = true;
			entity.falling_checkpoint = pos.y;
			entity.falling_goal = (pos.y + (64 * (current_z - i)));
			#make exception to personal collisions
			entity_colliders[entity][NORTH_WALL].set_disabled(true);
			entity_colliders[entity][EAST_WALL].set_disabled(true);
			entity_colliders[entity][SOUTH_WALL].set_disabled(true);
			entity_colliders[entity][WEST_WALL].set_disabled(true);
			reparent_entity(entity, tilemaps[current_z]); ######TWEAK THIS#####
			break;
	
"""
Attempts to find the four adjacent tiles of where a specific entity is, then writes these into
	the entity_z_tracker dictionary.
	
Searches the layer above (for jumping), the same layer, and all layers below (for ledge dropping).
If there is no adjacent tile in a specific direction (etc no tile to the North), the function instead
fills in the entity_z_tracker with the entity's CURRENT_TILE.
"""
func fill_adjacent_tiles(entity : Entity):
	#INCLUDE LAYER ABOVE LATER WHEN JUMPING IS IMPLEMENTED
	
	var current_layer = entity_z_tracker[entity][CURRENT_Z];
	
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
		
		if (entity_tile_tracker[entity][NORTH_TILE] == current_tile):
			if (tilemap.get_cellv(north_coords) != tilemap.INVALID_CELL):
				entity_tile_tracker[entity][NORTH_TILE] = north_coords;
				
		if (entity_tile_tracker[entity][EAST_TILE] == current_tile):
			if (tilemap.get_cellv(east_coords) != tilemap.INVALID_CELL):
				entity_tile_tracker[entity][EAST_TILE] = east_coords;
			
		if (entity_tile_tracker[entity][SOUTH_TILE] == current_tile):
			if (tilemap.get_cellv(south_coords) != tilemap.INVALID_CELL):
				entity_tile_tracker[entity][SOUTH_TILE] = south_coords;	
			
		if (entity_tile_tracker[entity][WEST_TILE] == current_tile):
			if (tilemap.get_cellv(west_coords) != tilemap.INVALID_CELL):
				entity_tile_tracker[entity][WEST_TILE] = west_coords;

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
	if (entity.falling):
		entity_colliders[entity][wall_direction].set_disabled(true);
	else:
		if (entity_tile_tracker[entity][tile_direction] == current_tile):
			entity_colliders[entity][wall_direction].set_disabled(false);
		else:
			entity_colliders[entity][wall_direction].set_disabled(true);

"""
Checks if the velocity an entity is going in has an adjacent tile in that direction.
If it does, excludes the entity from colliding with any edges in the way.
"""
func handle_velocity_collision(entity : Entity, direction : String):
	var z_index = entity_z_tracker[entity][CURRENT_Z];
	if (entity_tile_tracker[entity][direction] != entity_tile_tracker[entity][CURRENT_TILE]): #ADJ TILE EXISTS
		colliders[z_index].add_collision_exception_with(entity);
	else: #NO ADJ TILE
		colliders[z_index].remove_collision_exception_with(entity);
		#print("xmod: " + str(fmod(entity.position.x, 128)));
		#print("ymod " + str(fmod(entity.position.y, 64)));