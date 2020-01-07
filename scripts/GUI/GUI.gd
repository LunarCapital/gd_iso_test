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
onready var front_bar : TextureProgress = find_node("TextureFrontline");
onready var back_bar : TextureProgress = find_node("TextureBackline");
onready var front_label : Label = find_node("LabelFrontline");
onready var back_label : Label = find_node("LabelBackline");
onready var tween = $Tween
onready var fps_label = find_node("FPSLabel");

#constants
const HP_CHANGE_TIME = 0.25;

var front_max_hp : int = 0;
var front_hp : int = 0;
var back_max_hp : int = 0;
var back_hp : int = 0;

# Called when the node enters the scene tree for the first time.
func _ready():
	self.rect_size.x = ProjectSettings.get_setting("display/window/size/width");
	self.rect_size.y = ProjectSettings.get_setting("display/window/size/height");
	
	front_label.set_align(HALIGN_CENTER);
	front_label.set_valign(VALIGN_CENTER);
	back_label.set_align(HALIGN_CENTER);
	back_label.set_align(VALIGN_CENTER);
	
	update_hp_values()	
	
func _update_cam_pos(pos : Vector2, cam_zoom : Vector2):
	#self.rect_position = pos - (self.rect_size/2)*cam_zoom.x;
	#self.rect_scale = cam_zoom;
	pass;
	
func _process(_delta):
	update_hp_values()
	update_hp_bars(front_bar, front_label, front_hp, front_max_hp);
	update_hp_bars(back_bar, back_label, back_hp, back_max_hp);
	
	fps_label.set_text(str(Performance.get_monitor(Performance.TIME_FPS)));
	
func update_hp_bars(bar : TextureProgress, label : Label, value : int, value_max : int):
	label.set_text(str(value) + "/" + str(value_max));
	bar.value = round(value);
	bar.max_value = round(value_max);
	
	#tween.interpolate_property(self, "front_hp", front_hp, value, HP_CHANGE_TIME, Tween.TRANS_LINEAR, Tween.EASE_IN);
	#if (not tween.is_active()):
	#	tween.start();
		
func update_hp_values():
	front_max_hp = PlayerStats.sun_max_hp if (PlayerStats.sun_role == Globals.FRONTLINE) else PlayerStats.moon_max_hp;
	back_max_hp = PlayerStats.sun_max_hp if (PlayerStats.sun_role == Globals.BACKLINE) else PlayerStats.moon_max_hp;
	front_hp = PlayerStats.sun_hp if (PlayerStats.sun_role == Globals.FRONTLINE) else PlayerStats.moon_hp;
	back_hp = PlayerStats.sun_hp if (PlayerStats.sun_role == Globals.BACKLINE) else PlayerStats.moon_hp;
