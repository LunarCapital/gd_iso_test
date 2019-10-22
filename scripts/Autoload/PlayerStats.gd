extends Node2D

#signals
signal players_moved_too_far(move);
const SIGNAL_PLAYERS_MOVED_TOO_FAR = "players_moved_too_far";
signal players_moved_closer();
const SIGNAL_PLAYERS_MOVED_CLOSER = "players_moved_closer";

#listeners
const LISTENER_UPDATE_PLAYER_POS = "_update_player_pos";

#vars
onready var sun_pos : Vector2 = Vector2(0, 0);
onready var moon_pos : Vector2 = Vector2(0, 0);
onready var sun_role : int = Globals.BACKLINE;
onready var moon_role : int = Globals.FRONTLINE;

func _update_player_pos(pos, name, role):
	if (name == "Sun"):
		sun_pos = pos;
		sun_role = role;
	elif (name == "Moon"):
		moon_pos = pos;
		moon_role = role;

func _physics_process(_delta):
	correct_distance_apart();
	self.update();
		
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