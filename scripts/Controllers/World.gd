extends Node2D
"""
World controller.
Should handle world-related functions such as:
	Placing objects or enemies in the world
	Grouping said objects/enemies
	Switching out areas/tilesets when the player moves to a different location
"""

#listeners
const LISTENER_PLAYER_SHOT = "_on_player_shot";

#module loading
var damage_control = preload("res://scripts/Controllers/Damage.gd").new();

func _on_player_shot(shooter : Player, shot_type, goal : Vector2):
	var tileset = shooter.get_parent(); 
	if (!tileset):
		print("Shooter has no parent, unable to place shooting instance.");
	else:
		var shot_instance = shot_type.instance();
		if (shot_instance is Globals.Bullet):
			tileset.add_child(shot_instance);
			shot_instance.init(shooter.position, goal);
			shot_instance.connect(shot_instance.SIGNAL_HIT_ENTITY, damage_control, damage_control.LISTENER_DAMAGE_ENTITY);
			