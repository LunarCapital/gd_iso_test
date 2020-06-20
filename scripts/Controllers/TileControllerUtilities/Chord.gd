extends Node
class_name Chord
"""
A class that describes a chord in some irregular rectilinear polygon (possibly with
holes).  As a refresher, a chord in this case is a vertical or horizontal line
between two convex vertices.
"""

enum {VERTICAL = 0, HORIZONTAL = 1}

#VARIABLES
var a : Vector2;
var b : Vector2;
var direction : int;

