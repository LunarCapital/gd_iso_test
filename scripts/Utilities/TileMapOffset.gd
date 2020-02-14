tool
extends TileMap

var offset = Vector2(0, -Globals.TILE_HEIGHT);

func _ready():
	var navpoly : NavigationPolygon;

	for tile in tile_set.get_tiles_ids().size():
		tile_set.tile_set_texture_offset(tile, offset);
		
		if (tile == 0):
			navpoly = tile_set.tile_get_navigation_polygon(tile);
		else:
			tile_set.tile_set_navigation_polygon(tile, navpoly);
