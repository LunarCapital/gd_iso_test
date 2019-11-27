extends Area2D
"""
Z Area control.
Should move entities between Z levels when they touch the Z area in question.
This is done by re-parenting the entity to a different tileset.
"""

func _ready():
	self.connect("area_entered", self, "_on_z_area_entered");

func _on_z_area_entered(area : Area2D):
	call_deferred("move_child_across_parents", area);

func move_child_across_parents(area : Area2D):
	var new_parent = self.get_parent();
	var entity = area.get_parent();
	var old_parent = entity.get_parent();
	
	if new_parent != old_parent:
		old_parent.remove_child(entity);
		new_parent.add_child(entity);
		print("moved " + entity.name + " to " + new_parent.name);
