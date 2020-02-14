extends Node
"""
Autoloaded script.
Contains functions that are useful to have globally.
"""

"""
Init an empty 2D array of some size. 
"""
func init_2d_array(size : int):
	var array2d : Array = [];
	array2d.resize(size);
	for i in range(array2d.size()):
		array2d[i] = [];
	return array2d;

"""
Init an empty 3D array of some size. 
"""
func init_3d_array(size : int):
	var array3d : Array = [];
	array3d.resize(size);
	for i in range(array3d.size()):
		array3d[i] = init_2d_array(size);
	return array3d;
