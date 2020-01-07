extends Node2D

#signals
signal _players_moved_too_far(move);
const SIGNAL_PLAYERS_MOVED_TOO_FAR = "_players_moved_too_far";
signal _players_moved_closer();
const SIGNAL_PLAYERS_MOVED_CLOSER = "_players_moved_closer";

#listeners
const LISTENER_UPDATE_PLAYER_POS = "_update_player_pos";
const LISTENER_UPDATE_PLAYER_HP = "_update_player_hp";

#vars
onready var sun_pos : Vector2 = Vector2(0, 0); #'real' position, not accounting for Z axis, for checking if 
onready var moon_pos : Vector2 = Vector2(0, 0); #players are too far
onready var sun_cam_pos : Vector2 = Vector2(0, 0); #'cam' position, so the camera is smooth even when
onready var moon_cam_pos : Vector2 = Vector2(0, 0); #players are falling ('real' pos teleports which is jumpy)
onready var sun_role : int = Globals.BACKLINE;
onready var moon_role : int = Globals.FRONTLINE;

#game stats
onready var sun_max_hp : int = 50; #temp
onready var sun_hp : int = sun_max_hp;
onready var moon_max_hp : int = 50; #temp, have some level scaling thing or store in db
onready var moon_hp : int = moon_max_hp;

func _update_player_pos(emitter_name : String, pos : Vector2, cam_pos : Vector2, role : int):
	if (emitter_name == "Sun"): #not sure if i should change "Sun" and "Moon" to constants becaues hardcoding irks me but also seems like a small issue
		sun_pos = pos;
		sun_cam_pos = pos + cam_pos;
		sun_role = role;
	elif (emitter_name == "Moon"):
		moon_pos = pos;
		moon_cam_pos = pos + cam_pos;
		moon_role = role;
		
func _update_player_hp(emitter_name : String, hp : int):
	if (emitter_name == "Sun"):
		sun_hp = hp;
	elif (emitter_name == "Moon"):
		moon_hp = hp;

func _physics_process(_delta):
	correct_distance_apart();
	self.update(); #can't remember if i need this
		
"""
Prevents players from moving too far from each other.
Generally, the backline is 'anchored' to the frontline and cannot move too far away from them.
Consequently, if the frontline moves too far away from the backline, the backline is 'dragged' along.
NEED TO IMPLEMENT: if the backline is behind a wall, and the frontline tries to move too far
"""
func correct_distance_apart():
	var distance_apart = (sun_pos - moon_pos).length();
	var max_distance = get_viewport().get_visible_rect().size.length()/2;
	if (distance_apart > max_distance):
		var move_toward : Vector2 = Vector2(0, 0);
		if (sun_role == Globals.BACKLINE):
			move_toward = sun_pos - moon_pos;
			move_toward = move_toward.normalized() * max_distance + moon_pos;
		elif (moon_role == Globals.BACKLINE):
			move_toward = moon_pos - sun_pos;
			move_toward = move_toward.normalized() * max_distance + sun_pos;
		emit_signal(SIGNAL_PLAYERS_MOVED_TOO_FAR, move_toward);
	else:
		emit_signal(SIGNAL_PLAYERS_MOVED_CLOSER);
