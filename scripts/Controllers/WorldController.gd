extends Node2D
"""
World controller.  A resource run by the Main controller.
Should handle world-related functions such as:
	Placing objects or enemies in the world
	Grouping said objects/enemies
	Switching out areas/tilesets when the player moves to a different location
	
...But we need to redefine what this controller does and split its functionality up into sub-nodes.
Currently this controller does the following:
	
	Track entity z indexes (pos tracking)
	Track entity tiles (pos tarcking)
	Track entity masks (falling?)
	Manage entity shaders for falling (falling)
	Manage whether a player interacts with colliders based on z index (stay here?)
	Reparents player to diff tilemaps (stay here?)
	Has player fall (falling)
	receive signals for:
		changing pos (post tracking)
		finishing falling (falling)
		falling to the point where the shader kicks in (falling)
		entering/exiting walkable areas (pos tracking? or falling?)
		when a player shoots (shooting)
		
	Split up into:
		Pos tracking
		Falling (includes masking)
		Shooting?
	
	..but store the globals in this node for easy access!
	
"""

#listeners
#INTERNAL LISTENERS (from scene child-nodes)
const LISTENER_FALLING_TRIGGERED = "_on_falling_triggered";
const LISTENER_REQUEST_FALLING_MASK = "_on_request_falling_mask";
const LISTENER_REQUEST_REPARENT = "_on_request_reparent";
#EXTERNAL LISTENERS
const LISTENER_PLAYER_SHOT = "_on_player_shot";
const LISTENER_ON_AREA_ENTERED = "_on_area_entered";
const LISTENER_ON_AREA_EXITED = "_on_area_exited";
const LISTENER_ON_CHANGED_ENTITY_POSITION = "_on_changed_entity_position";
const LISTENER_ON_FELL_BELOW_THRESHOLD = "_on_fell_below_threshold";
const LISTENER_ON_FINISHED_FALLING = "_on_finished_falling";

#module loading
var damage_control = preload("res://scripts/Controllers/DamageController.gd").new();

#utility nodes
onready var position_tracker = $PositionTracker;
onready var falling_handler = $FallingHandler;

var entity_pos_tracker : Dictionary = {};
var entity_redraw_tracker : Dictionary = {}; #handles info required to 'redraw' an entity's sprite when
											 #the entity is falling between two tiles of different z-indexes
											 #which normally results in the top half of the sprite being BEHIND
											 #the higher tile which also drives me nuts

var tilemaps : Dictionary = {}; #stores all tilemaps. key is their z-index.
var walls : Dictionary = {}; #stores all WALL colliders. key is their z-index.
var ledges : Dictionary = {}; #stores all LEDGE colliders. key is z-index.

func init(world : Node2D) -> void:
	#should try to take a signal whenever an entity is added or removed from the world (but that's for later!)
	for world_child in world.get_children():
		if (world_child is TileMap):
			var index = world_child.z_index; 
			for tilemap_child in world_child.get_children():
				if (tilemap_child is Entity):
					position_tracker.init_pos_tracker(entity_pos_tracker, tilemap_child, index);
					falling_handler.init_redraw_tracker(entity_redraw_tracker, tilemap_child);
					
			tilemaps[index] = world_child;
			walls[index] = world_child.find_node(Globals.STATIC_BODY_WALLS_NAME, false, false);
			ledges[index] = world_child.find_node(Globals.STATIC_BODY_LEDGES_NAME, false, false);
			
	for key in entity_pos_tracker:
		manage_colliders(key);
		key.connect(key.SIGNAL_CHANGED_ENTITY_POSITION, self, self.LISTENER_ON_CHANGED_ENTITY_POSITION);
		key.connect(key.SIGNAL_FELL_BELOW_THRESHOLD, self, self.LISTENER_ON_FELL_BELOW_THRESHOLD);
		key.connect(key.SIGNAL_FINISHED_FALLING, self, self.LISTENER_ON_FINISHED_FALLING);
		position_tracker.on_changed_entity_position(entity_pos_tracker, key, key.position, tilemaps);
		
	connect_internal_signals();
	
func connect_internal_signals():
	position_tracker.connect(position_tracker.SIGNAL_FALLING_TRIGGERED, self, self.LISTENER_FALLING_TRIGGERED);
	position_tracker.connect(position_tracker.SIGNAL_REQUEST_FALLING_MASK, self, self.LISTENER_REQUEST_FALLING_MASK);
	falling_handler.connect(falling_handler.SIGNAL_REQUEST_REPARENT, self, self.LISTENER_REQUEST_REPARENT);

func _physics_process(_delta):
	falling_handler.redraw_falling_sprite(entity_redraw_tracker, entity_pos_tracker, position_tracker.CURRENT_Z, tilemaps);

#############################################################################################################
#INTERNAL SIGNALS
#############################################################################################################
func _on_falling_triggered(entity : Entity, pos : Vector2):
	falling_handler.trigger_falling(entity_redraw_tracker, entity_pos_tracker, position_tracker.CURRENT_Z, entity, pos , tilemaps);
	
func _on_request_falling_mask(entity : Entity, tilemap : TileMap, current_tile : Vector2):
	falling_handler.fill_mask_booleans(entity_redraw_tracker, entity, tilemap, current_tile);
	
func _on_request_reparent(entity : Entity, tilemap : TileMap):
	reparent_entity(entity, tilemap);
#############################################################################################################


#############################################################################################################
#PASSED OFF EXTERNAL SIGNALS
#############################################################################################################
func _on_changed_entity_position(entity : Entity, pos : Vector2):
	position_tracker.on_changed_entity_position(entity_pos_tracker, entity, pos, tilemaps);

func _on_area_entered(floor_area : Area2D, entity : Entity, state : int):
	print("area entered");
	position_tracker.on_area_entered(entity_pos_tracker, floor_area, entity, state);
	
func _on_area_exited(floor_area : Area2D, entity : Entity, state : int):
	position_tracker.on_area_exited(entity_pos_tracker, floor_area, entity, state);

func _on_fell_below_threshold(entity : Entity):
	falling_handler.on_fell_below_threshold(entity_redraw_tracker, entity);

func _on_finished_falling(entity : Entity):
	falling_handler.on_finished_falling(entity_redraw_tracker, tilemaps, entity_pos_tracker, position_tracker.CURRENT_Z, position_tracker.CURRENT_TILE, entity);
#############################################################################################################


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
Moves entity across tilemaps so they're YSorted properly.
"""
func reparent_entity(entity : Entity, new_parent : TileMap):
	var current_parent = entity.get_parent();
	current_parent.remove_child(entity);
	new_parent.add_child(entity);
	entity_pos_tracker[entity][position_tracker.CURRENT_Z] = new_parent.z_index;
	position_tracker.on_changed_entity_position(entity_pos_tracker, entity, entity.position, tilemaps);
	manage_colliders(entity);

"""
Sets exclusion of world colliders to ignore or not ignore certain entities,
based off where they are on the tilemap.  For example, players on ground level shouldn't be
hitting walls that are a level up.
"""
func manage_colliders(entity : Entity):
	var exclusion_index = entity_pos_tracker[entity][position_tracker.CURRENT_Z] - 1;
	
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
