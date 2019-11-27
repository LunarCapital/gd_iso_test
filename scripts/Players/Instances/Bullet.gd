extends KinematicBody2D
class_name Bullet
"""
Bullet instance.
Created when the player left clicks with the Sun in the backline. 
Moves towards the mouse.  Disappears upon hitting walls or enemies.
Goes through players and other player-created instances.  
Damage should be handled elsewhere (due to damage formula).
"""

#signals
signal hit_entity(entity);
const SIGNAL_HIT_ENTITY = "hit_entity";

#constants
const SPEED = 1000;

#variables
var direction : Vector2;

func init(start_pos : Vector2, goal_pos : Vector2):
	self.position = start_pos;
	direction = (goal_pos - start_pos).normalized();
	
func _physics_process(delta):
	var collision = move_and_collide(direction * SPEED * delta);
	if (collision):
		var collider = collision.get_collider();
		emit_signal(SIGNAL_HIT_ENTITY, collider);
		queue_free();
		
func _on_VisibilityNotifier2D_screen_exited():
    queue_free()