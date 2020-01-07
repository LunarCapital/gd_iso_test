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
signal _fell_below_threshold(entity);
const SIGNAL_FELL_BELOW_THRESHOLD = "_fell_below_threshold";
signal _finished_falling(entity);
const SIGNAL_FINISHED_FALLING = "_finished_falling";

#constants
const FALL_SPEED = 1 # Pixels/frame
onready var sprite = $Sprite;

#globals
var prev_position : Vector2 = Vector2(0, 0);
var prev_velocity : Vector2 = Vector2(0, 0);
var falling : bool = false;
var falling_threshold : bool = false;
var falling_checkpoint : float = 0;

func _physics_process(delta):
	var velocity = ((self.position - prev_position)/delta).normalized();
	if (prev_velocity != velocity):
		emit_signal(SIGNAL_CHANGED_ENTITY_VELOCITY, self, velocity);
		prev_velocity = velocity;
	
	if (prev_position != self.position):
		emit_signal(SIGNAL_CHANGED_ENTITY_POSITION, self, self.position);
		prev_position = self.position;
		
	if (falling):
		if (self.sprite.position.y < 0):
			self.sprite.position.y += FALL_SPEED;
			if (self.sprite.position.y >= (-Globals.TILE_HEIGHT + 
					(self.sprite.texture.get_size().y * self.sprite.scale.y * 0.5))
					and not falling_threshold):
				falling_threshold = true;
				emit_signal(SIGNAL_FELL_BELOW_THRESHOLD, self);
				print(-Globals.TILE_HEIGHT + (self.sprite.texture.get_size().y * self.sprite.scale.y * 0.5));
		else:
			#UPDATE LAYER
			falling = false;
			self.sprite.position.y = 0;
			emit_signal(SIGNAL_FINISHED_FALLING, self);
