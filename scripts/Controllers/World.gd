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
const LISTENER_ON_FELL_BELOW_THRESHOLD = "_on_fell_below_threshold";
const LISTENER_ON_FINISHED_FALLING = "_on_finished_falling";

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

#for entities to redraw dict
const REDRAW = "Redraw"; #bool
const CURRENT_PIXEL = "Current_Pixel"; #Vector2

#edge directions for sprite border box
const DIRECTION = "Direction";
const POINT = "Point"; #intersection point
enum dir {NONE = -1, LEFT = 0, BOT = 1, RIGHT = 2, TOP = 3, EXTEND = 4};

#globals
var entity_z_tracker : Dictionary = {};
var entity_tile_tracker : Dictionary = {};
var entity_colliders : Dictionary = {};
var tilemaps : Dictionary = {};
var colliders : Dictionary = {};
var entities_to_redraw : Dictionary = {};
var sprites_to_delete : Array = [];

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
			colliders[index] = world_child.find_node(Globals.STATIC_BODY_LOWER_WALLS_NAME, false, false);
			
	for key in entity_z_tracker:
		manage_colliders(key);
		manage_personal_colliders(key);
		key.connect(key.SIGNAL_CHANGED_ENTITY_POSITION, self, self.LISTENER_ON_CHANGED_ENTITY_POSITION);
		key.connect(key.SIGNAL_CHANGED_ENTITY_VELOCITY, self, self.LISTENER_ON_CHANGED_ENTITY_VELOCITY);
		key.connect(key.SIGNAL_FELL_BELOW_THRESHOLD, self, self.LISTENER_ON_FELL_BELOW_THRESHOLD);
		key.connect(key.SIGNAL_FINISHED_FALLING, self, self.LISTENER_ON_FINISHED_FALLING);
		_on_changed_entity_position(key, key.position);

"""
Called every physics process by parent, Main. 
Checks what entities need to be 'redrawn', then does that.
Entities need to be redrawn if they are BETWEEN TWO TILES OF DIFFERENT HEIGHTS.
Redrawing duplicates the top portion of the entity's sprite so it doesn't 
appear behind tiles when it should be in front.
"""
func redraw_entities():
	while (sprites_to_delete.size() > 0):
		var sprite = sprites_to_delete.pop_front();
		sprite.free();
	
	for entity in entities_to_redraw.keys():

		if (	not entities_to_redraw[entity][REDRAW] 
				or entity.position == entities_to_redraw[entity][CURRENT_PIXEL]):
			continue;
		
		entities_to_redraw[entity][CURRENT_PIXEL] = entity.position;

		var sprite_centre = entity.position + entity.sprite.position + entity.sprite.offset;
		var sprite_size = entity.sprite.scale * entity.sprite.texture.get_size();
		var top = sprite_centre.y - sprite_size.y/2;
		var left = sprite_centre.x - sprite_size.x/2;
		var bot = sprite_centre.y + sprite_size.y/2;
		var right = sprite_centre.x + sprite_size.x/2;
		var sprite_border : PoolVector2Array = [Vector2(left, top), Vector2(left, bot), 
				Vector2(right, bot), Vector2(right, top)];

		var z_index = entity_z_tracker[entity][CURRENT_Z];

		#sprite cloning/redrawing section
		for collision_node in colliders[z_index].get_children():
			var poly = collision_node.get_polygon();
			for i in range(poly.size()):
				var edge_a = poly[i];
				var edge_b = poly[(i+1)%poly.size()];
				if (edge_a.x < edge_b.x): #if we're checking a segment at the 'front' (rather than 'back') of wall
					var intersection1 : Dictionary = {DIRECTION: dir.NONE};
					var intersection2 : Dictionary = {DIRECTION: dir.NONE};
					for j in range(sprite_border.size()):
						var edge_c = sprite_border[j];
						var edge_d = sprite_border[(j+1)%sprite_border.size()];
						
						if (intersection1[DIRECTION] == dir.NONE): #haven't yet found a first intersection
							intersection1[POINT] = Geometry.segment_intersects_segment_2d(edge_a, edge_b, edge_c, edge_d);
							intersection1[DIRECTION] = j if intersection1[POINT] else dir.NONE;
						elif (intersection2[DIRECTION] == dir.NONE): #haven't yet found a second intersection
							var temp_intersect = Geometry.segment_intersects_segment_2d(edge_a, edge_b, edge_c, edge_d);
							if (temp_intersect and temp_intersect != intersection1[POINT]):
								intersection2[POINT] = temp_intersect;
								intersection2[DIRECTION] = j if intersection2[POINT] else dir.NONE;
								break;
						
					if (intersection1[DIRECTION] != dir.NONE): 
						var temp_sprite : Sprite = entity.sprite.duplicate();
						
						if (intersection2[DIRECTION] == dir.NONE): #make other intersection the point of the line segment inside the sprite box
							intersection2[DIRECTION] = dir.EXTEND;
							if (edge_a.x >= left and edge_a.x <= right and edge_a.y >= top and edge_a.y <= bot):
								intersection2[POINT] = edge_a;
							else:
								intersection2[POINT] = edge_b;
							
						var img : Image = temp_sprite.texture.get_data();
						var modifier : float = entity.sprite.scale;
						
						var shifted_point1 : Vector2 = (intersection1[POINT] - sprite_centre + sprite_size/2)/modifier;
						var shifted_point2 : Vector2 = (intersection2[POINT] - sprite_centre + sprite_size/2)/modifier;
						
						var left_point : Vector2 = shifted_point1 if (shifted_point1.x < shifted_point2.x) else shifted_point2;
						var right_point : Vector2 = shifted_point1 if (shifted_point1 != left_point) else shifted_point2;
						var ratio : float = (right_point.y - left_point.y)/(right_point.x - left_point.x);
						var img_width = img.get_width();
						var img_height = img.get_height();
						#god help me this feels very messy
						
						img.lock();
						for x in range(img_width):
							for y in range(img_height):
								if (x < left_point.x):
									img.set_pixel(x, y, Color(0, 0, 0, 0));
								elif (y > ratio * (x - left_point.x) + left_point.y):
									img.set_pixel(x, y, Color(0, 0, 0, 0)); 
						img.unlock();
						
						var itex : ImageTexture = ImageTexture.new();
						itex.set_storage(itex.STORAGE_RAW);
						itex.create_from_image(img);
						temp_sprite.texture = itex;
						
						temp_sprite.position = sprite_centre - entity.sprite.offset;
						tilemaps[z_index + 1].add_child(temp_sprite);
						sprites_to_delete.append(temp_sprite);
						
						#next step is to be selective with what poly collider edge we use.
						#we should only bother with the poly edge that corresponds to where the entity is.
					
				
"""
Listener function that runs when an entity changes position.
Updates what tile the entity is on, calculates adjacent tiles, and makes colliders.

TODO: change to only run fully if the entity has changed what isometric tile it's on, instead of running every single time we make a small movement
"""
func _on_changed_entity_position(entity : Entity, pos : Vector2):
	var z_index = entity_z_tracker[entity][CURRENT_Z];
	var tilemap = tilemaps[z_index - 1];
	var current_tile = tilemap.world_to_map(pos) + Vector2(1, 1);	
	
	if (entity_tile_tracker[entity][CURRENT_TILE] != current_tile or not entity_z_tracker[entity][QUEUE].has(z_index - 1)): #only need to do recalculations if we change our current tile OR we're not in the 'tilemap' that we should be in
		#print("changed tile: " + str(current_tile));
		entity_tile_tracker[entity][CURRENT_TILE] = current_tile;
		fill_adjacent_tiles(entity);
		fill_personal_colliders(entity, current_tile, tilemap);
	
		#DEBUG STUFF BELOW
		if (!entity.falling): #NOT FALLING
			if (tilemap.get_cellv(current_tile) == -1): #AND THERE'S NO TILE WHERE WE'RE STANDING
				if (!entity_z_tracker[entity][QUEUE].has(z_index - 1)): #AND NO PART OF OUR COLLISION AREA IS TOUCHING THE FLOOR
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

"""
Listener function that runs when an entity falls 'below' the special case threshold where the entity's
sprite is between tiles of different heights. At this point we can reparent the entity because there is 
no longer a need to compensate for ysorting.
"""
func _on_fell_below_threshold(entity : Entity):
	entities_to_redraw[entity][REDRAW] = false;

"""
Listener function that runs when an entity finishes falling.
If they are still on an empty tile, then they continue to fall.
"""
func _on_finished_falling(entity : Entity):
	var tilemap = tilemaps[entity_z_tracker[entity][CURRENT_Z] - 1];
	var current_tile = entity_tile_tracker[entity][CURRENT_TILE];
	
	if (tilemap.get_cellv(current_tile) == -1): #AND THERE'S NO TILE WHERE WE'RE STANDING
		trigger_falling(entity, tilemap, current_tile, entity.position);

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
			
	entities_to_redraw[entity] = {REDRAW: false, CURRENT_PIXEL: Vector2(0, 0)};
		
"""
Sets exclusion of world colliders to ignore or not ignore certain entities,
based off where they are on the tilemap.  For example, players on ground level shouldn't be
hitting walls that are a level up.
"""
func manage_colliders(entity : Entity):
	var exclusion_index = entity_z_tracker[entity][CURRENT_Z] - 1;
	
	for i in range(colliders.size()):
		if (colliders[i]):
			if (i == exclusion_index):
				colliders[i].remove_collision_exception_with(entity);
			else:
				colliders[i].add_collision_exception_with(entity);
	
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
We set the entity to follow the collisions of the tilemap one Z level below, but
don't actually drop the entity down into the lower tilemap for the sake of sorting purposes.
This is because the entity will be 'between' tiles for a short while.
"""
func trigger_falling(entity : Entity, tilemap : TileMap, current_tile : Vector2, pos : Vector2):
	var current_z : int = entity_z_tracker[entity][CURRENT_Z] - 1;
	entity.falling_checkpoint = pos.y;
	entity.position = entity.position + Vector2(0, Globals.TILE_HEIGHT);
	entity.sprite.position.y = -Globals.TILE_HEIGHT;
	entity.falling = true;
	entity.falling_threshold = false;
	reparent_entity(entity, tilemaps[current_z]);
	entities_to_redraw[entity][REDRAW] = true;
	entities_to_redraw[entity][CURRENT_PIXEL] = Vector2(0, 0); #reset current pixel
	
	
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
	if (entity_tile_tracker[entity][tile_direction] == current_tile):
		entity_colliders[entity][wall_direction].set_disabled(false);
	else:
		entity_colliders[entity][wall_direction].set_disabled(true);

"""
Checks if the velocity an entity is going in has an adjacent tile in that direction.
If it does, excludes the entity from colliding with any edges in the way.
"""
func handle_velocity_collision(entity : Entity, direction : String):
	var z_index = entity_z_tracker[entity][CURRENT_Z] - 1;
	if (entity_tile_tracker[entity][direction] != entity_tile_tracker[entity][CURRENT_TILE]): #ADJ TILE EXISTS
		colliders[z_index].add_collision_exception_with(entity);
	else: #NO ADJ TILE
		colliders[z_index].remove_collision_exception_with(entity);
		#print("xmod: " + str(fmod(entity.position.x, 128)));
		#print("ymod " + str(fmod(entity.position.y, 64)));