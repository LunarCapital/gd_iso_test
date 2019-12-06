extends Camera2D
"""
Camera2D node.  
Follows both players by tracking the position in the middle of them.
Also can peek in eight directions if the player moves the mouse to the edges of the screen.
"""

#signals
signal _changed_position(pos, zoom);
const SIGNAL_CHANGED_POSITION = "_changed_position";

#constants
const CAM_DELAY = 10;
const EDGE_THRESHOLD = 50;
const PEEK_LIMIT = 300;

#variables
onready var cam_goal : Vector2 = Vector2(0, 0);

func _process(_delta):
	var cam_peek_modifier = Vector2(PEEK_LIMIT, PEEK_LIMIT);
	var cam_peek_direction = get_peek_direction();
	cam_goal = (PlayerStats.sun_pos + PlayerStats.moon_pos)/2;
	cam_goal += cam_peek_modifier * cam_peek_direction;

	if (self.position != cam_goal): #move towards cam goal.
		var move_direction = cam_goal - self.position;
		self.position += (move_direction/CAM_DELAY); #will move faster based off how far
		self.align();
		
	emit_signal(SIGNAL_CHANGED_POSITION, get_camera_screen_center(), self.zoom);
		
func get_peek_direction():
	var mouse_pos = get_viewport().get_mouse_position();
	var screen_width = ProjectSettings.get_setting("display/window/size/width");
	var screen_height = ProjectSettings.get_setting("display/window/size/height");
	
	if (mouse_pos.x < EDGE_THRESHOLD && mouse_pos.y < EDGE_THRESHOLD): #topleft
		return Vector2(-1, -1);
	elif(mouse_pos.x > (screen_width - EDGE_THRESHOLD) && mouse_pos.y < EDGE_THRESHOLD): #topright
		return Vector2(1, -1);
	elif (mouse_pos.x < EDGE_THRESHOLD && mouse_pos.y > (screen_height - EDGE_THRESHOLD)): #bottomleft
		return Vector2(-1, 1);
	elif (mouse_pos.x > (screen_width - EDGE_THRESHOLD) && mouse_pos.y > (screen_height - EDGE_THRESHOLD)): #bottomright
		return Vector2(1, 1);
	elif (mouse_pos.x < EDGE_THRESHOLD): #left
		return Vector2(-1, 0);
	elif (mouse_pos.x > (screen_width - EDGE_THRESHOLD)): #right
		return Vector2(1, 0);
	elif (mouse_pos.y < EDGE_THRESHOLD): #top
		return Vector2(0, -1);
	elif (mouse_pos.y > (screen_height - EDGE_THRESHOLD)): #bot
		return Vector2(0, 1);
	else: #centre
		return Vector2(0, 0);
				
