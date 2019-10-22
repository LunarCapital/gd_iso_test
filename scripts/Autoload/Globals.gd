extends Node
"""
Autoloaded script.
Contains easily accessible constants/variables.
"""

#class loading
const Enemy = preload("res://scripts/Enemies/Enemy.gd");
const Player = preload("res://scripts/Players/Player.gd");
const Sun = preload("res://scripts/Players/Sun.gd");
const Moon = preload("res://scripts/Players/Moon.gd");

#instance class loading
const Bullet = preload("res://scripts/Players/Instances/Bullet.gd");

#constants
enum {BACKLINE = -1, FRONTLINE = 1}