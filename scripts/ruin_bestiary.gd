extends RefCounted

const DATA_PATH := "res://data/monsters.json"
static var creatures: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))

const DROPS := {
	"shale_beetle": "stonegrip_gloves", "mirror_eel": "eel_greaves",
	"root_mole": "hardroot_bracers", "sluice_snail": "silt_shell",
	"ash_scribe": "rune_gloves", "copper_cicada": "copper_helm", "burial_ram": "ram_boots",
}

const ENCOUNTERS := [
	[["shale_beetle", 1580], ["dust_hare", 243]],
	[["lantern_crab", 1180], ["reed_leech", 670], ["mirror_eel", 1590],
		["root_mole", 1775], ["silt_ray", 2190], ["sluice_snail", 2640], ["tide_salamander", 2930]],
	[["thorn_archer", 690], ["shield_heron", 1020], ["key_jackal", 1320],
		["ash_scribe", 1600], ["shard_warden", 1960], ["copper_cicada", 2260], ["burial_ram", 2550]],
]
