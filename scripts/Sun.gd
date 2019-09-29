extends KinematicBody2D

#signals
signal player_initialised(node);
signal health_changed(value);

#constants
enum {BACKLINE = -1, FRONTLINE = 1}
const DEST_THRESHOLD = 3;
const MOTION_SPEED = 200 # Pixels/second
const DASH_DELAY = 0.1; #P control
const DASH_MAX_DIST = 250;
const DASH_EPSILON = 50;
const DASH_CD = 3; #seconds

#globals
var player_role : int;
var walk_goal : Vector2;
var dashing : bool;
var dash_goal : Vector2;
var dash_cd : float;

func _ready():
	emit_signal("player_initialised", self);
	walk_goal = self.position;
	dashing = false;
	dash_goal = self.position;
	dash_cd = 0;	

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
		if (dashing):
			if ((self.position - dash_goal).abs().length() > DASH_EPSILON):
				var dash_diff = dash_goal - self.position;
				motion = (dash_diff)/DASH_DELAY;
			else: #doesn't account for if we collide
				dashing = false;
		else: #not dashing
			var dest_epsilon = (walk_goal - self.position).abs();
			if (Input.is_action_pressed("move_mouse")):
				walk_goal = get_global_mouse_position();
			if (dest_epsilon.x > DEST_THRESHOLD || dest_epsilon.y > DEST_THRESHOLD):
				motion = (walk_goal - self.position);
			motion = motion.normalized() * MOTION_SPEED;

	var velocity = move_and_slide(motion);
	if (dashing and velocity.length() < 1): #hit a wall while dashing
		dashing = false;
		
	cycle_cooldowns(delta);


func _input(event):
	if event is InputEventMouseButton:
		if event.is_pressed():
			if event.button_index == BUTTON_WHEEL_UP:
				pass; #block
			if (event.button_index == BUTTON_WHEEL_DOWN and dash_cd <= 0): #dash
				var dash_dest = get_global_mouse_position();
				if (self.position.distance_to(dash_dest) > DASH_MAX_DIST):
					var dash_diff = (dash_dest - self.position).normalized();
					dash_dest = self.position + dash_diff*DASH_MAX_DIST;
				walk_goal = dash_dest;
				dash_goal = dash_dest;
				dashing = true;
				dash_cd = DASH_CD;
	
func cycle_cooldowns(delta):
	if (dash_cd > 0):
		dash_cd -= delta;

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
