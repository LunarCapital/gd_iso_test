extends KinematicBody2D
class_name Enemy
"""
Generic enemy class for inheritance.
Has a floating HP bar.  
"""


#resources
onready var hp_bar = $ProgressBar;

#constants
export(int) var HEALTH = 10

func _ready():
	hp_bar.setup_hpbar(HEALTH);
	
func take_damage(damage : int):
	hp_bar.value -= damage;