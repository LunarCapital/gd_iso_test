extends Area2D

#signals
signal _entity_entered_area(self_area, entity_area);
const SIGNAL_ENTITY_ENTERED_AREA = "_entity_entered_area";
signal _entity_exited_area(self_area, entity_area);
const SIGNAL_ENTITY_EXITED_AREA = "_entity_exited_area";

#listeners
const LISTENER_ON_AREA_ENTERED = "_on_area_entered";
const LISTENER_ON_AREA_EXITED = "_on_area_exited";

func _on_area_entered(area : Area2D):
	emit_signal(SIGNAL_ENTITY_ENTERED_AREA, self, area);

func _on_area_exited(area : Area2D):
	emit_signal(SIGNAL_ENTITY_EXITED_AREA, self, area);