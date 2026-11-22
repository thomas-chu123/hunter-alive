extends RefCounted

const ITEMS := {
	"linen_hood": ["營火布兜", "頭部", "最大體力增加 1。"],
	"scaleveil_hood": ["鱗紗兜帽", "頭部", "石鐘蛾的鱗粉緩速時間減半。"],
	"moss_vest": ["苔織獵衣", "身體", "每次營火休息後，抵消一次接觸傷害。"],
	"hunter_wraps": ["獵人纏手", "手部", "短刀與木刃的攻擊恢復時間縮短。"],
	"hunter_knife": ["短刀／木刃", "武器", "快速近身攻擊。繳械拾取木刃後提升傷害。"],
	"hunter_bow": ["獵弓", "武器", "沿水平方向射出箭矢。"],
	"ember_staff": ["餘火魔法杖", "武器", "消耗 1 點法力，朝面向水平發射火球，碰到敵人或地形時爆炸。"],
}

const STARTING_WEAPONS := ["hunter_knife", "hunter_bow"]
const ICONS := {
	"hunter_knife": preload("res://assets/items/hunter_knife.png"),
	"hunter_bow": preload("res://assets/items/hunter_bow.png"),
	"linen_hood": preload("res://assets/items/linen_hood.png"),
	"scaleveil_hood": preload("res://assets/items/scaleveil_hood.png"),
	"moss_vest": preload("res://assets/items/moss_vest.png"),
	"hunter_wraps": preload("res://assets/items/hunter_wraps.png"),
	"ember_staff": preload("res://assets/items/ember_staff.svg"),
	"root_blade": preload("res://assets/items/root_blade.png"),
}


const Armory := preload("res://scripts/ruin_armory.gd")


static func item(id: String) -> Array:
	if ITEMS.has(id):
		return ITEMS[id]
	if Armory.WEAR.has(id):
		return Armory.WEAR[id]
	if Armory.WEAPONS.has(id):
		var weapon: Array = Armory.WEAPONS[id]
		return [weapon[0], "武器", weapon[1]]
	return []


const CAMPAIGN_ICONS := [
	preload("res://assets/items/stage3_wear_a.png"),
	preload("res://assets/items/stage3_wear_b.png"),
	preload("res://assets/items/stage3_weapons.png"),
]


static func icon(id: String) -> Texture2D:
	if ICONS.has(id):
		return ICONS[id]
	var index := Armory.WEAR.keys().find(id)
	var atlas: Texture2D
	if index >= 0:
		atlas = CAMPAIGN_ICONS[0 if index < 8 else 1]
		index %= 8
	else:
		index = Armory.WEAPONS.keys().find(id) - 1
		if index < 0:
			return null
		atlas = CAMPAIGN_ICONS[2]
	var cell := atlas.get_size() / Vector2(4, 2)
	var texture := AtlasTexture.new()
	texture.atlas = atlas
	texture.region = Rect2(Vector2(index % 4, 0 if index < 4 else 1) * cell, cell)
	texture.filter_clip = true
	return texture


const Progression := preload("res://scripts/ruin_progression.gd")
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
