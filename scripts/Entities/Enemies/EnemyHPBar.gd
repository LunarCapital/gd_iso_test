extends ProgressBar

#constants
const TIME_BEFORE_HIDE = 2;

#variables
var time_before_hide;

func _ready():
	time_before_hide = 0;

func _physics_process(delta):
	if (self.value < self.max_value):
		time_before_hide = TIME_BEFORE_HIDE;
		self.visible = true;
	else:
		time_before_hide -= delta;
		
	if (time_before_hide <= 0):
		self.visible = false;
	
func setup_hpbar(maxhp):
	self.max_value = maxhp;
	self.value = maxhp;
