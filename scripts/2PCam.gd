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
		#cam behaviour plan
			#if sun&moon are going out of camera, zoom out
			#if sun&moon are trying to go a certain distance from each other, ?
				#prevent them from going further. problem if one of them is off-ledge.
				#pull the two together?
				#maybe some backline to frontline TP
			#if player mouses to the edge of the screen, camera 'peeks' in that direction but will snap back later
		print(get_viewport().get_mouse_position());
		#if ~50 from any edge, peek in that direction
		#if ~50 from corner, peek in corner
		#PEEK BY MODIFYING SELF.POSITION
			#important, i'm pretty sure other ways will break functionality by, for example:
			#peek top, then quickly peek right, and camera doesn't fix itself
			
		#also think about if peeking affects the zoomout when players are on the edge
		
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
