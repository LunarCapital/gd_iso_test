extends Camera2D

#signals
signal camera_initialised(node);

#constants
enum {ZOOM_IN = -1, NO_ZOOM = 0, ZOOM_OUT = 1}
const CAM_MIN = 1;
const CAM_MAX = 3;
const ANIM_STEP = 0.1; #'animated' step
const ZOOM_STEP = 0.5;
var CAM_MIN_VECT = Vector2(CAM_MIN, CAM_MIN);
var CAM_MAX_VECT = Vector2(CAM_MAX, CAM_MAX);
var ANIM_STEP_VECT = Vector2(ANIM_STEP, ANIM_STEP);

#globals
var sun; #player
var moon; #player
var cam_zoom;
var cam_goal;

func _ready():
	emit_signal("camera_initialised", self);
	cam_zoom = NO_ZOOM;
	cam_goal = self.zoom.x;

func _physics_process(delta):
	if (sun != null): #update camera position
		self.position = (sun.position + moon.position)/2;
		#zoom out automatically?
			#if sun&moon are ? distance apart, zoom out.
			#OR if sun&moon are going outside the camera, zoom out?
	if (cam_zoom == ZOOM_IN): #zoom in camera
		if (self.zoom.x > cam_goal):
			self.zoom = CAM_MIN_VECT if (self.zoom.x < (CAM_MIN + ANIM_STEP)) else self.zoom - ANIM_STEP_VECT;
		elif (self.zoom.x <= cam_goal):
			cam_zoom = NO_ZOOM;
	if (cam_zoom == ZOOM_OUT): #zoom out camera
		if (self.zoom.x < cam_goal):
			self.zoom = CAM_MAX_VECT if (self.zoom.x > (CAM_MAX - ANIM_STEP)) else self.zoom + ANIM_STEP_VECT;
		elif (self.zoom.x >= cam_goal):
			cam_zoom = NO_ZOOM;
	
#cam zoom in and zoom out
func _input(event):
	if event is InputEventMouseButton:
		if event.is_pressed():
			if event.button_index == BUTTON_WHEEL_UP:
				if (cam_goal > CAM_MIN && cam_goal > CAM_MIN):
					cam_zoom = ZOOM_IN;
					cam_goal = CAM_MIN if (cam_goal <= (CAM_MIN + ZOOM_STEP)) else cam_goal - ZOOM_STEP;
		if event.button_index == BUTTON_WHEEL_DOWN:
				if (cam_goal < CAM_MAX && cam_goal < CAM_MAX):
					cam_zoom = ZOOM_OUT;
					cam_goal = CAM_MAX if (cam_goal >= (CAM_MAX - ZOOM_STEP)) else cam_goal + ZOOM_STEP;
				
#signal from player to update player position
func set_player(node):
	if (node.name == "Sun"):
		sun = node;
	elif (node.name == "Moon"):
		moon = node;
