extends Area2D

const LISTENER_ON_AREA_ENTERED = "_on_area_entered";

func _ready():
	print("test");

func _on_area_entered(area : Area2D):
	print("Area entered: " + self.name);
