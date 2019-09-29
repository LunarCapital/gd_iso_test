extends Camera2D

#signals
signal camera_initialised(node);

#constants
const CAM_DELAY = 10;
	#peek
const EDGE_THRESHOLD = 50;
const PEEK_LIMIT = 300;
	#zoom
const ZOOM_MIN = 1;
const ZOOM_MAX = 3;
const ZOOM_STEP = 0.5;

#globals
var sun; #player
var moon; #player
var cam_goal;
var zoom_goal;

func _ready():
	emit_signal("camera_initialised", self);
	zoom_goal = self.zoom.x;

func _physics_process(delta):
	if (sun != null): #update camera position
		var cam_peek_modifier = Vector2(PEEK_LIMIT, PEEK_LIMIT);
		var cam_peek_direction = get_peek_direction();
		cam_goal = (sun.position + moon.position)/2;
		cam_goal += cam_peek_modifier * cam_peek_direction;

	if (self.zoom.x != zoom_goal):
		var zoom_diff = Vector2(zoom_goal - self.zoom.x, zoom_goal - self.zoom.x);
		self.zoom += zoom_diff/CAM_DELAY;
			
	if (self.position != cam_goal): #move towards cam goal.
		var move_direction = cam_goal - self.position;
		self.position += (move_direction/CAM_DELAY); #will move faster based off how far
		self.align();
	
#cam zoom in and zoom out
func _input(event):
	if event is InputEventMouseButton:
		if event.is_pressed():
			if event.button_index == BUTTON_WHEEL_UP:
				if (zoom_goal > ZOOM_MIN):
					zoom_goal = ZOOM_MIN if (zoom_goal <= (ZOOM_MIN + ZOOM_STEP)) else zoom_goal - ZOOM_STEP;
			if event.button_index == BUTTON_WHEEL_DOWN:
				if (zoom_goal < ZOOM_MAX):
					zoom_goal = ZOOM_MAX if (zoom_goal >= (ZOOM_MAX - ZOOM_STEP)) else zoom_goal + ZOOM_STEP;
				
	
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
				
#signal from player to update player position
func set_player(node):
	if (node.name == "Sun"):
		sun = node;
	elif (node.name == "Moon"):
		moon = node;
