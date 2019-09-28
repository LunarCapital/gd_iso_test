extends Area2D

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass

func _on_z_area_entered(area):
	var new_parent = self.get_parent();
	var entity = area.get_parent();
	var entity_parent = entity.get_parent();
	
	if new_parent != entity_parent:
		call_deferred('move_child_across_parents', entity, new_parent, entity_parent);

func move_child_across_parents(child, new_parent, old_parent):
	var child_dupl = child.duplicate();
	new_parent.add_child(child_dupl);
	old_parent.remove_child(child);