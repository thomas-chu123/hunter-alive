extends RefCounted

const Armory := preload("res://scripts/game/ruin_armory.gd")


static var ITEMS: Dictionary = Armory.catalog.items
static var STARTING_WEAPONS: Array = Armory.catalog.starting_weapons


static func _entry(id: String) -> Dictionary:
	return ITEMS.get(id, Armory.WEAR.get(id, Armory.WEAPONS.get(id, {})))


static func item(id: String) -> Array:
	var entry := _entry(id)
	return [] if entry.is_empty() else [entry.name, entry.get("slot", "武器"), entry.description]


static func icon(id: String) -> Texture2D:
	var entry := _entry(id)
	return null if entry.is_empty() else load(entry.icon) as Texture2D


const Progression := preload("res://scripts/game/ruin_progression.gd")
const ICON_SIZE := 64
static var ranked_icons := {}


static func catalog_ids() -> Array[String]:
	var ids: Array[String] = []
	ids.assign(ITEMS.keys() + Armory.WEAR.keys() + Armory.WEAPONS.keys())
	return ids


static func ranked_icon(id: String, rank: int) -> Texture2D:
	if id.is_empty():
		return null
	var key := "%s:%d" % [id, rank]
	if ranked_icons.has(key):
		return ranked_icons[key]
	var texture := icon(id)
	if texture == null:
		return null
	var artwork := texture.get_image()
	var size := Vector2(artwork.get_size())
	var fitted := Vector2i((size * (54.0 / maxf(size.x, size.y))).round())
	artwork.convert(Image.FORMAT_RGBA8)
	artwork.resize(maxi(1, fitted.x), maxi(1, fitted.y), Image.INTERPOLATE_LANCZOS)
	var framed := Image.create_empty(ICON_SIZE, ICON_SIZE, false, Image.FORMAT_RGBA8)
	framed.fill(Progression.COLORS[rank])
	framed.fill_rect(Rect2i(3, 3, 58, 58), Color("#102120"))
	var icon_offset := Vector2i((Vector2.ONE * ICON_SIZE - Vector2(artwork.get_size())) * 0.5)
	framed.blend_rect(artwork, Rect2i(Vector2i.ZERO, artwork.get_size()), icon_offset)
	var result := ImageTexture.create_from_image(framed)
	ranked_icons[key] = result
	return result
