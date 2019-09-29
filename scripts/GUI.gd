extends Control

#Should i have some signal-connection call that runs at the start of every scene?

#GUI Elements
onready var sun_bar = $hbar_test/TextureProgress
onready var tween = $Tween

#constants
enum {BACKLINE = -1, FRONTLINE = 1}
const HP_CHANGE_TIME = 0.25;

#var
var sun;
var moon;
var camera;

var sun_anim_hp = 0; #temp?

# Called when the node enters the scene tree for the first time.
func _ready():
	self.rect_size.x = ProjectSettings.get_setting("display/window/size/width");
	self.rect_size.y = ProjectSettings.get_setting("display/window/size/height");
	update_health(sun_bar, 100); #TEMP
	pass # Replace with function body.

func _physics_process(delta):
	if (camera != null):
		self.rect_position = camera.get_camera_screen_center() - (self.rect_size/2)*camera.zoom.x;
		self.rect_scale = camera.zoom;
	sun_bar.value = round(sun_anim_hp);

func update_health(bar, value):
	tween.interpolate_property(self, "sun_anim_hp", sun_anim_hp, value, HP_CHANGE_TIME, Tween.TRANS_LINEAR, Tween.EASE_IN);
	if (not tween.is_active()):
		tween.start();

#signal from player to update player position
func set_player(node):
	if (node.name == "Sun"):
		if (sun == null): #if initialising sun for first time
			node.player_role = BACKLINE;
		else:
			node.player_role = sun.player_role;
		sun = node;
	elif (node.name == "Moon"):
		if (moon == null): #if initialising for first time
			node.player_role = FRONTLINE;
		else:
			node.player_role = moon.player_role;
		moon = node;

func set_camera(node):
	camera = node;


func sun_health_changed(value):
	update_health(sun_bar, value);
