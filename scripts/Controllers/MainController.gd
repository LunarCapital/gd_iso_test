extends Node
"""
Main controller node.
Handles signal connections between its children.  

Any extended behaviour should be placed in separate scripts and called by this one.
For example, damage calculations for when the bullet instance emits a signal alerting that it hit an enemy.
"""

#module loading
onready var world_control = $Controllers/WorldController
onready var tile_control = $Controllers/TileController
onready var world_node = find_node("World");

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

	tile_control.init(world_node.get_children());
	tile_control.setup_world_tiles();
	world_control.call_deferred("init", world_node);
	
	setup_base_signals();
	setup_level_signals();
	
	#DEBUG
	print("\n\nDEBUG\n\n")
	var test : Dictionary = {};
	test[["tilemap1", "In"]] = 5;
	print(test[["tilemap1", "In"]]);
	print(test.keys());
	print("\n\nEND DEBUG\n\n")
	#END DEBUG
	
func setup_base_signals():
	var _connect;
	_connect = sun.connect(sun.SIGNAL_CHANGED_PLAYER_POSITION, PlayerStats, PlayerStats.LISTENER_UPDATE_PLAYER_POS);
	_connect = moon.connect(moon.SIGNAL_CHANGED_PLAYER_POSITION, PlayerStats, PlayerStats.LISTENER_UPDATE_PLAYER_POS);
	_connect = sun.connect(sun.SIGNAL_CHANGED_HEALTH, PlayerStats, PlayerStats.LISTENER_UPDATE_PLAYER_HP);
	_connect = moon.connect(moon.SIGNAL_CHANGED_HEALTH, PlayerStats, PlayerStats.LISTENER_UPDATE_PLAYER_HP);
	_connect = PlayerStats.connect(PlayerStats.SIGNAL_PLAYERS_MOVED_TOO_FAR, sun, sun.LISTENER_CLOSE_PLAYER_DISTANCE);
	_connect = PlayerStats.connect(PlayerStats.SIGNAL_PLAYERS_MOVED_TOO_FAR, moon, moon.LISTENER_CLOSE_PLAYER_DISTANCE);
	_connect = PlayerStats.connect(PlayerStats.SIGNAL_PLAYERS_MOVED_CLOSER, sun, sun.LISTENER_PLAYERS_CLOSE_ENOUGH);
	_connect = PlayerStats.connect(PlayerStats.SIGNAL_PLAYERS_MOVED_CLOSER, moon, moon.LISTENER_PLAYERS_CLOSE_ENOUGH);
	
	_connect = camera2d.connect(camera2d.SIGNAL_CHANGED_POSITION, gui, gui.LISTENER_UPDATE_CAM_POS);
	
	_connect = sun.connect(sun.SIGNAL_SHOT_BULLET, world_control, world_control.LISTENER_PLAYER_SHOT);

"""
Sets up signals for the level's Area2D floors and wall colliders if needed.
"""
func setup_level_signals():
	var area2ds : Array = [];
	for tilemap in world_node.get_children():
		if tilemap is TileMap:
			for child in tilemap.get_children():
				if child is Area2D:
					area2ds.append(child);
					
	var _connect;
	for i in range(area2ds.size()):
		_connect = area2ds[i].connect(area2ds[i].SIGNAL_ENTITY_ENTERED_AREA, world_control, world_control.LISTENER_ON_AREA_ENTERED);
		_connect = area2ds[i].connect(area2ds[i].SIGNAL_ENTITY_EXITED_AREA, world_control, world_control.LISTENER_ON_AREA_EXITED);
