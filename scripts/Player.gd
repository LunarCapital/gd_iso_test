extends KinematicBody2D

#signals
signal player_initialised(node);
signal health_changed(value);

#constants
enum {BACKLINE = -1, FRONTLINE = 1}
const DEST_THRESHOLD = 3;
const MOTION_SPEED = 200 # Pixels/second

#globals
var player_role;
var destination : Vector2;

func _ready():
	emit_signal("player_initialised", self);
	destination = self.position;
	

func _physics_process(delta):
	var motion = Vector2()
	
	if (player_role == FRONTLINE): #frontline uses WASD movement
		if Input.is_action_pressed("move_up"):
			motion += Vector2(0, -1)
		if Input.is_action_pressed("move_bottom"):
			motion += Vector2(0, 1)
		if Input.is_action_pressed("move_left"):
			motion += Vector2(-1, 0)
		if Input.is_action_pressed("move_right"):
			motion += Vector2(1, 0)
	elif (player_role == BACKLINE): #backline uses mouse movement
		var dest_epsilon = (destination - self.position).abs();
		if (Input.is_action_pressed("move_mouse")):
			destination = get_global_mouse_position();
		if (dest_epsilon.x > DEST_THRESHOLD || dest_epsilon.y > DEST_THRESHOLD):
			motion = (destination - self.position);

	if Input.is_action_pressed("move_jump"): #currently a debug key
		emit_signal("health_changed", 50);
		pass;
			
	motion = motion.normalized() * MOTION_SPEED

	move_and_slide(motion)

	
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
