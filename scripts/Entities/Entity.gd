extends KinematicBody2D
class_name Entity
"""
Entity class. 
Inherited by both players and enemies.
Necessary for the world controller to keep track of all entitites and check if their
movement is valid, or handle ledge drops/collisions if required.

Should be used to handle all the isometric jumping/ledge dropping/other shenanigans so we don't have to look
at it anywhere else.
"""

#signals
signal _changed_entity_position(entity, pos);
const SIGNAL_CHANGED_ENTITY_POSITION = "_changed_entity_position";
signal _changed_entity_velocity(entity, velocity);
const SIGNAL_CHANGED_ENTITY_VELOCITY = "_changed_entity_velocity";

#constants
const FALL_SPEED = 300 # Pixels/second

#globals
var prev_position : Vector2 = Vector2(0, 0);
var prev_velocity : Vector2 = Vector2(0, 0);
var falling : bool = false;
var falling_checkpoint : float = 0;
var falling_goal : float = 0;

func _physics_process(delta):
	var velocity = ((self.position - prev_position)/delta).normalized();
	if (prev_velocity != velocity):
		emit_signal(SIGNAL_CHANGED_ENTITY_VELOCITY, self, velocity);
		prev_velocity = velocity;
	
	if (prev_position != self.position):
		emit_signal(SIGNAL_CHANGED_ENTITY_POSITION, self, self.position);
		prev_position = self.position;
		
	if (falling):
		if (self.position.y < falling_goal):
			var fall_motion : int = falling_goal - self.position.y;
			var _motion = move_and_slide(Vector2(0, fall_motion).normalized() * FALL_SPEED);
			print("checkpoint check: " + str(falling_checkpoint - self.position.y));
		else:
			print("stopped falling");
			#UPDATE LAYER
			falling = false;
