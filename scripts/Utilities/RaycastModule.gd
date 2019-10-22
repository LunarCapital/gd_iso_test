extends Node2D

func repeated_raycast(space_state, hits, exclude, source_node, source_pos, goal_pos, collision_mask):
	exclude.append(source_node);
	
	var result = space_state.intersect_ray(source_pos, goal_pos, exclude, collision_mask, false, true);
	if (result): 
		hits.append(result.collider)
		repeated_raycast(space_state, hits, exclude, result.collider, result.position, goal_pos, collision_mask);
	return hits;

func get_query_z_area(querent, initial_pos, goal_pos, collision_mask):
	var segment = SegmentShape2D.new();
	var query_z_area = Physics2DShapeQueryParameters.new();
	
	segment.set_a(initial_pos);
	segment.set_b(goal_pos);
	query_z_area.set_shape(segment);
	query_z_area.set_exclude([querent]); #thank you english stack exchange for the noun of query
	query_z_area.set_collision_layer(collision_mask);
	query_z_area.set_collide_with_areas(true);
	query_z_area.set_collide_with_bodies(false);
	
	return query_z_area;