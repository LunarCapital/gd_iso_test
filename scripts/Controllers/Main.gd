extends Node
"""
Main controller node.
Handles signal connections between its children.  

Any extended behaviour should be placed in separate scripts and called by this one.
For example, damage calculations for when the bullet instance emits a signal alerting that it hit an enemy.
"""

#module loading
onready var world_control = preload("res://scripts/Controllers/World.gd").new();

#resource loading
onready var sun = find_node("Sun");
onready var moon = find_node("Moon");
onready var camera2d = find_node("Camera2D");
onready var gui = find_node("GUI");

func _ready():
	if (!sun || !moon || !camera2d || !gui):
		print("Missing a resource in main controller.  Sun: " + str(sun) + ", Moon: " + str(moon) + ", Cam2D" + str(camera2d) + ", GUI: " + str(gui));
		
	sun.player_role = Globals.BACKLINE;
	moon.player_role = Globals.FRONTLINE;
	
	setup_signals();
	
func setup_signals():
	var _connect;
	_connect = sun.connect(sun.SIGNAL_CHANGED_POSITION, PlayerStats, PlayerStats.LISTENER_UPDATE_PLAYER_POS);
	_connect = moon.connect(moon.SIGNAL_CHANGED_POSITION, PlayerStats, PlayerStats.LISTENER_UPDATE_PLAYER_POS);
	_connect = PlayerStats.connect(PlayerStats.SIGNAL_PLAYERS_MOVED_TOO_FAR, sun, sun.LISTENER_CLOSE_PLAYER_DISTANCE);
	_connect = PlayerStats.connect(PlayerStats.SIGNAL_PLAYERS_MOVED_TOO_FAR, moon, moon.LISTENER_CLOSE_PLAYER_DISTANCE);
	_connect = PlayerStats.connect(PlayerStats.SIGNAL_PLAYERS_MOVED_CLOSER, sun, sun.LISTENER_PLAYERS_CLOSE_ENOUGH);
	_connect = PlayerStats.connect(PlayerStats.SIGNAL_PLAYERS_MOVED_CLOSER, moon, moon.LISTENER_PLAYERS_CLOSE_ENOUGH);
	
	_connect = camera2d.connect(camera2d.SIGNAL_CHANGED_POSITION, gui, gui.LISTENER_UPDATE_CAM_POS);
	
	_connect = sun.connect(sun.SIGNAL_SHOT_BULLET, world_control, world_control.LISTENER_PLAYER_SHOT);