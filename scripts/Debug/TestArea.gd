extends Area2D

#listeners
const LISTENER_ON_BODY_ENTERED = "_on_body_entered";
const LISTENER_ON_BODY_EXITED = "_on_body_exited";

func _ready():
	self.connect("body_entered", self, self.LISTENER_ON_BODY_ENTERED);
	self.connect("body_exited", self, self.LISTENER_ON_BODY_EXITED);

func _on_body_entered(body : PhysicsBody2D):
	print("IT IS I");
	
func _on_body_exited(body : PhysicsBody2D):
	print("AHH");
	
