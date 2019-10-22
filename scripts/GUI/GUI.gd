extends Control
"""
GUI control.
Consists of two HP bars, date/time, and possibly special resource bars.  Follows camera.

I strongly recommend to myself in the future of splitting up the above elements into their own nodes,
and using this node as some 'parent communication' node that passes information to them (and also follows the camera).
"""

#listeners
const LISTENER_UPDATE_CAM_POS = "_update_cam_pos";

#GUI Elements
onready var front_bar = find_node("HBoxFrontline").TextureProgress
onready var back_bar = find_node("HBoxBackline").TextureProgress
onready var tween = $Tween
onready var fps_label = find_node("FPSLabel");

#constants
const HP_CHANGE_TIME = 0.25;

#vars
onready var sun_anim_hp : int = 0; #temp?

# Called when the node enters the scene tree for the first time.
func _ready():
	self.rect_size.x = ProjectSettings.get_setting("display/window/size/width");
	self.rect_size.y = ProjectSettings.get_setting("display/window/size/height");
	update_health(front_bar, 100); #TEMP
	
func _update_cam_pos(pos, cam_zoom):
	self.rect_position = pos - (self.rect_size/2)*cam_zoom.x;
	self.rect_scale = cam_zoom;
	
func _process(_delta):
	front_bar.value = round(sun_anim_hp);
	
	fps_label.set_text(str(Performance.get_monitor(Performance.TIME_FPS)));
	
func update_health(bar, value):
	tween.interpolate_property(self, "sun_anim_hp", sun_anim_hp, value, HP_CHANGE_TIME, Tween.TRANS_LINEAR, Tween.EASE_IN);
	if (not tween.is_active()):
		tween.start();
