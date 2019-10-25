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
onready var front_bar = find_node("TextureFrontline");
onready var back_bar = find_node("TextureBackline");
onready var front_label = find_node("LabelFrontline");
onready var back_label = find_node("LabelBackline");
onready var tween = $Tween
onready var fps_label = find_node("FPSLabel");

#constants
const HP_CHANGE_TIME = 0.25;

#vars
onready var front_hp : int = 0; #temp?
onready var front_max_hp : int = 50; #temp

# Called when the node enters the scene tree for the first time.
func _ready():
	self.rect_size.x = ProjectSettings.get_setting("display/window/size/width");
	self.rect_size.y = ProjectSettings.get_setting("display/window/size/height");
	update_health(front_bar, 100); #TEMP
	front_label.set_align(HALIGN_CENTER);
	front_label.set_valign(VALIGN_CENTER);
	
func _update_cam_pos(pos, cam_zoom):
	self.rect_position = pos - (self.rect_size/2)*cam_zoom.x;
	self.rect_scale = cam_zoom;
	
func _process(_delta):
	front_bar.value = round(front_hp);
	
	fps_label.set_text(str(Performance.get_monitor(Performance.TIME_FPS)));
	
func update_health(bar, value):
	front_label.set_text(str(front_hp) + "/" + str(front_max_hp));
	
	tween.interpolate_property(self, "front_hp", front_hp, value, HP_CHANGE_TIME, Tween.TRANS_LINEAR, Tween.EASE_IN);
	if (not tween.is_active()):
		tween.start();
