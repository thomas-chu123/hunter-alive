extends RefCounted


static var tables := {}


static func read(name: String) -> Dictionary:
	if tables.has(name):
		return tables[name]
	var path := "res://data/%s.json" % name
	var document := JSON.new()
	if document.parse(FileAccess.get_file_as_string(path)) != OK or not document.data is Dictionary:
		push_error("Invalid configuration %s (line %d): %s" % [path, document.get_error_line(), document.get_error_message()])
		return {}
	tables[name] = document.data
	return document.data


static func resources(paths: Dictionary) -> Dictionary:
	var result := {}
	for id: String in paths:
		result[id] = load(paths[id])
	return result


static func vector(values: Array) -> Vector2:
	return Vector2(values[0], values[1])
