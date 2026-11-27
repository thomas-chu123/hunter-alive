extends RefCounted

const Config := preload("res://scripts/game/config_table.gd")
static var catalog := Config.read("equipment/equipment")
static var WEAPONS: Dictionary = catalog.weapons
static var WEAR: Dictionary = catalog.armor
