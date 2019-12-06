extends Player
"""
Moon player class.
Has different actions to the default player class.  Refer to doc for a full list.
"""


#constants
const PLAYER_Z_AREA_NAME = "PlayerArea";
const Z_AREA_GROUP_NAME = "ZAreas";

#TEMP DEBUG
export (NodePath) var path_floor;
export (NodePath) var path_wall0;
export (NodePath) var path_wall1;

func _physics_process(_delta):
	var motion = Vector2()
		
	if (player_role == Globals.FRONTLINE): #frontline uses WASD movement
		if (mobility):
			motion = get_dash_motion(); 
			var velocity = move_and_slide(motion);
			if (velocity.length() < MOBILITY_END_VELOCITY): #hit a wall while dashing
				mobility = false;
	elif (player_role == Globals.BACKLINE): #backline uses mouse movement
		pass;

	if Input.is_action_pressed("move_jump"): #currently a debug key
		emit_signal(SIGNAL_CHANGED_HEALTH, self.name, PlayerStats.moon_hp - 10);
		pass;
		

func get_dash_motion():
	var motion = Vector2(0, 0);
	if ((self.position - mobility_goal).abs().length() > MOBILITY_EPSILON):
		var mobility_diff = mobility_goal - self.position;
		motion = (mobility_diff)/MOBILITY_DELAY;
	else: 
		mobility = false;
	return motion;
	
#	var hits = [];
#	var exclude = [];
#	var result_wall = space_state.intersect_ray(self.position, mobility_goal, [self], collision_mask, true, false);
#
#	if (result_wall): #found a wall
#		mobility_goal = result_wall.position;
#
#	var result_z_area = raycast_module.repeated_raycast(space_state, hits, exclude, self, self.position, mobility_goal, collision_mask);
#
#	self.position = mobility_goal;
#	mobility = false;
#
#	if (result_z_area): #change z level
#		var last_z_area;
#		for area in result_z_area:
#			print(area.name);
#			if (area.is_in_group(Z_AREA_GROUP_NAME)):
#				last_z_area = area;
#
#		if (last_z_area != null):
#			var player_z_area = self.get_node(PLAYER_Z_AREA_NAME);
#			last_z_area.call_deferred("move_child_across_parents", $PlayerArea);	
	
#jumping mechanics:
	#jumping allows players to move through colliders that are ONE Z LEVEL HIGHER THAN THE PLAYER'S Z LEVEL.
	#Player will gain a certain height, then drop a certain height.
	#keep in mind of z levels.
	#raising player z level reduces height drop by 64(?)
	#lowering player z level increases height drop by 64(?)
	#...only works for assumptions where we never have half/quarter blocks, etc.  
	
	#keep in mind of jumping between same z-level platforms with lower z-level floor between them.
	#for example, jumping from --__-- left to right.
	#how to keep track of z level?  player's y coordinate?  Seems expensive, because need area2Ds for EVERY floor level.  
	#Alternatively, track entering+exiting colliders, which may be better.
	#This method requires you to put colliders around walls in its HIGHEST Z LEVEL TILE.
	#For example, a 2 pillar high wall will have a collider down at the bottom, but it will be placed in the highest tilemap.
	
	#current problem: CHANGING the player z level.  
	#if we jump up from floor to 1-height wall, we are entering then leaving a z:0 collider.
	#if we go down from a 1-height wall to the floor, we are also entering then leaving a z:0 collider.
	#if we are on a 1-height wall, jump over the floor to another 1-height wall, we are entering+leaving TWO z:0 colliders.
	#We go through the colliders with no indication of WHICH WAY we are going.
	
#falling mechanics:
	#you can drop from higher z levels to lower z levels.  not sure how to program this.
	#its hard to say "you can go through colliders one way" because geometry is hard. 
	#i may make it that you can't drop off ledges, but you can jump off them.
	#how about you can move through colliders that are of a lower z level than you?
		#this still matches up with the entering+leaving collider that helps with raising/lowering jump height.
