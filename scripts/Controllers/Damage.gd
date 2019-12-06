extends Resource
"""
Damage controller.

Should handle the damaging of entities, incorporating player stats/entity stats
and a damage formula if required.
"""

#listeners
const LISTENER_DAMAGE_ENTITY = "_on_damage_entity";

func _on_damage_entity(entity):
	if (entity is Enemy):
		entity.take_damage(1);