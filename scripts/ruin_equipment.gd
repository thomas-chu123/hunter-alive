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
	"ember_staff": preload("res://assets/items/weapon/ember_staff.svg"),
	"fang_dagger": preload("res://assets/items/weapon/fang_dagger.tres"),
	"gate_halberd": preload("res://assets/items/weapon/gate_halberd.tres"),
	"hunter_bow": preload("res://assets/items/weapon/hunter_bow.png"),
	"hunter_knife": preload("res://assets/items/weapon/hunter_knife.png"),
	"root_blade": preload("res://assets/items/weapon/root_blade.png"),
	"scribe_staff": preload("res://assets/items/weapon/scribe_staff.tres"),
	"sluice_spear": preload("res://assets/items/weapon/sluice_spear.tres"),
	"thorn_bow": preload("res://assets/items/weapon/thorn_bow.tres"),
	"tide_hammer": preload("res://assets/items/weapon/tide_hammer.tres"),

	"ash_cowl": preload("res://assets/items/armor/ash_cowl.png"),
	"bowstring_gloves": preload("res://assets/items/armor/bowstring_gloves.png"),
	"cinder_greaves": preload("res://assets/items/armor/cinder_greaves.png"),
	"cliff_boots": preload("res://assets/items/armor/cliff_boots.png"),
	"copper_helm": preload("res://assets/items/armor/copper_helm.png"),
	"earthen_armor": preload("res://assets/items/armor/earthen_armor.png"),
	"eel_greaves": preload("res://assets/items/armor/eel_greaves.png"),
	"hardroot_bracers": preload("res://assets/items/armor/hardroot_bracers.png"),
	"hunter_wraps": preload("res://assets/items/armor/hunter_wraps.png"),
	"linen_hood": preload("res://assets/items/armor/linen_hood.png"),
	"moss_vest": preload("res://assets/items/armor/moss_vest.png"),
	"ram_boots": preload("res://assets/items/armor/ram_boots.png"),
	"reed_coat": preload("res://assets/items/armor/reed_coat.png"),
	"rune_gloves": preload("res://assets/items/armor/rune_gloves.png"),
	"scaleveil_hood": preload("res://assets/items/armor/scaleveil_hood.png"),
	"sealed_cap": preload("res://assets/items/armor/sealed_cap.png"),
	"silt_shell": preload("res://assets/items/armor/silt_shell.png"),
	"sluice_boots": preload("res://assets/items/armor/sluice_boots.png"),
	"stonegrip_gloves": preload("res://assets/items/armor/stonegrip_gloves.png"),
	"wing_cape": preload("res://assets/items/armor/wing_cape.png"),
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


static func icon(id: String) -> Texture2D:
	return ICONS.get(id) as Texture2D



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
