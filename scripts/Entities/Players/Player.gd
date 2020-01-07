extends Entity
class_name Player
"""
Generic player class.
Considering breaking up into smaller scripts, aka:
	Input handling
	Movement
	Actions
"""

#signals 
signal _changed_health(my_name, value);
const SIGNAL_CHANGED_HEALTH = "_changed_health";
signal _changed_player_position(my_name, pos, my_role);
const SIGNAL_CHANGED_PLAYER_POSITION = "_changed_player_position";

#listeners
const LISTENER_CLOSE_PLAYER_DISTANCE = "_close_player_distance";
const LISTENER_PLAYERS_CLOSE_ENOUGH = "_players_close_enough";

#constants
const DEST_THRESHOLD = 3;
const MOBILITY_EPSILON = 10;
const MOBILITY_END_VELOCITY = 15;
export(float) var MOBILITY_DELAY = 0.1; #P control
export(int) var MOTION_SPEED = 200 # Pixels/second
export(int) var MOBILITY_MAX_DIST = 250;
export(float) var MOBILITY_CD = 3.00; #seconds

#globals
var player_role : int;
onready var walk_goal : Vector2 = self.position;
onready var mobility : bool = false; 
onready var mobility_goal : Vector2 = self.position;
onready var mobility_cd : float = 0;
onready var close_distance : bool  = false;
onready var close_distance_goal : Vector2 = self.position;
onready var close_distance_velocity : Vector2 = Vector2(0, 0);
	
func _close_player_distance(_move_to):
	if (self.player_role == Globals.BACKLINE):
		close_distance = true;
		close_distance_goal = _move_to;
			
func _players_close_enough():
	close_distance = false;
	
func _physics_process(delta):
	var _motion = Vector2()
	
	if (!mobility):
		if (player_role == Globals.FRONTLINE): #frontline uses WASD movement
			_motion = get_front_walk_motion();
		elif (player_role == Globals.BACKLINE): #backline uses mouse movement
			_motion = get_back_walk_motion();
		
		_motion = _motion.normalized() * MOTION_SPEED;
		
		_motion = move_and_slide(_motion); 
	
	if (self.player_role == Globals.BACKLINE and close_distance == true):
		_motion = close_distance_to_partner();
		close_distance_velocity = move_and_slide(_motion);
		
		
	emit_signal(SIGNAL_CHANGED_PLAYER_POSITION, self.name, self.position, self.sprite.position, self.player_role);
	cycle_cooldowns(delta);

func get_front_walk_motion():
	var motion = Vector2(0, 0);
	if Input.is_action_pressed("move_up"):
		motion += Vector2(0, -1)
	if Input.is_action_pressed("move_bottom"):
		motion += Vector2(0, 1)
	if Input.is_action_pressed("move_left"):
		motion += Vector2(-1, 0)
	if Input.is_action_pressed("move_right"):
		motion += Vector2(1, 0)
	
	if (Input.is_action_pressed("move_dash") && mobility_cd <= 0):
		get_front_dash_motion(motion);
	
	return motion;

func get_front_dash_motion(motion : Vector2):
	if (motion.length() > 0):
		var mobility_dest = motion.normalized() * MOBILITY_MAX_DIST + self.position;
		mobility_goal = mobility_dest;
		mobility = true;
		mobility_cd = MOBILITY_CD;

func get_back_walk_motion():
	var motion = Vector2(0, 0);
	var dest_epsilon = (walk_goal - self.position).abs();
	if (Input.is_action_pressed("move_mouse")):
		walk_goal = get_global_mouse_position();
	if (dest_epsilon.x > DEST_THRESHOLD || dest_epsilon.y > DEST_THRESHOLD):
		motion = (walk_goal - self.position);
	return motion;

func get_back_mobility_motion():
	var mobility_dest = get_global_mouse_position();
	if (self.position.distance_to(mobility_dest) > MOBILITY_MAX_DIST):
		var mobility_diff = (mobility_dest - self.position).normalized();
		mobility_dest = self.position + mobility_diff * MOBILITY_MAX_DIST;
	walk_goal = mobility_dest;
	mobility_goal = mobility_dest;
	mobility = true;
	mobility_cd = MOBILITY_CD;

func _input(event):
	if (self.player_role == Globals.BACKLINE):
		if event is InputEventMouseButton:
			if event.is_pressed():
				if event.button_index == BUTTON_WHEEL_UP:
					pass; #block
				if (event.button_index == BUTTON_WHEEL_DOWN and mobility_cd <= 0): #dash
					get_back_mobility_motion();
					
func close_distance_to_partner():
	var motion = Vector2(0, 0);
	if ((self.position - close_distance_goal).abs().length() > MOBILITY_EPSILON):
		var dist_diff = close_distance_goal - self.position;
		motion = dist_diff/0.1;
	else:
		close_distance = false;
	return motion;
					
func cycle_cooldowns(delta : float):
	if (mobility_cd > 0):
		mobility_cd -= delta;