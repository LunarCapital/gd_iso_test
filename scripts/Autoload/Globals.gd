extends Node
"""
Autoloaded script.
Contains easily accessible constants/variables.
"""

#constant vars
enum {BACKLINE = -1, FRONTLINE = 1}
const side = {MERGED = -1, NORTH = 0, EAST = 1, SOUTH = 2, WEST = 3}; #Tile sides. as always north is top-right direction
const Z_LIMIT = 20; #assume for now we will never have more than 20 Z layers of tilemaps. CURRENTLY UNUSED.
const TILE_WIDTH = 64;
const TILE_HEIGHT = 32;

#constant names
const STATIC_BODY_LEDGES_NAME : String = "LayerLedges";
const STATIC_BODY_WALLS_NAME : String = "LayerWalls"; 
const DONUT_OUT : String = "DonutOut";
const DONUT_IN : String = "DonutIn"; #these two refer to the inner and outer edges of a donut polygon
