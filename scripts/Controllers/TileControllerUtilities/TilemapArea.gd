extends Area2D

#signals
signal _entity_entered_area(self_area, entity, state);
const SIGNAL_ENTITY_ENTERED_AREA = "_entity_entered_area";
signal _entity_exited_area(self_area, entity, state);
const SIGNAL_ENTITY_EXITED_AREA = "_entity_exited_area";

#listeners
const LISTENER_ON_BODY_ENTERED = "_on_body_entered";
const LISTENER_ON_BODY_EXITED = "_on_body_exited";

#variables
enum {WALKABLE = 0, NEGATIVE = 1}
var state : int;

func _on_body_entered(body : PhysicsBody2D):
	emit_signal(SIGNAL_ENTITY_ENTERED_AREA, self, body, state);
	print("entered " + self.name + ": " + body.name);

func _on_body_exited(body : PhysicsBody2D):
	emit_signal(SIGNAL_ENTITY_EXITED_AREA, self, body, state);

"""
Modify these to also store edge group (so we can have 'negative' areas that 
cancel out walkable areas (needed for donut polygons))
"""
