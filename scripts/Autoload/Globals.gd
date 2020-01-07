extends Node
"""
Autoloaded script.
Contains easily accessible constants/variables.
"""

#constant vars
enum {BACKLINE = -1, FRONTLINE = 1}
const Z_LIMIT = 20; #assume for now we will never have more than 20 Z layers of tilemaps
const TILE_WIDTH = 128;
const TILE_HEIGHT = 64;

#constant names
const STATIC_BODY_EDGES_NAME : String = "LayerEdges";
const STATIC_BODY_LOWER_WALLS_NAME : String = "LayerLowWalls"; 