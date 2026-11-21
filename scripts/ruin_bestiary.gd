extends RefCounted

# id -> atlas index, maximum health, movement and attack profile.
const CREATURES := {
	"shale_beetle": [0, 8, 86.0, 115.0, 0.66, 0.58, 1.05, "roll"],
	"dust_hare": [1, 4, 165.0, 139.0, 0.58, 0.66, 0.62, "double"],
	"mirror_eel": [2, 7, 126.0, 187.0, 0.62, 0.63, 0.90, "leap"],
	"root_mole": [3, 9, 80.0, 170.0, 0.88, 0.40, 0.94, "burrow"],
	"reed_leech": [4, 5, 96.0, 100.0, 0.50, 0.52, 0.78, "latch"],
	"silt_ray": [5, 7, 79.0, 153.0, 0.82, 0.50, 0.88, "mud"],
	"sluice_snail": [6, 10, 57.0, 250.0, 0.83, 0.49, 1.30, "shell"],
	"tide_salamander": [7, 8, 112.0, 229.0, 0.75, 0.48, 0.84, "spray"],
	"thorn_archer": [8, 9, 94.0, 310.0, 0.86, 0.43, 0.84, "arrow"],
	"shield_heron": [9, 10, 110.0, 142.0, 0.72, 0.63, 0.96, "shield"],
	"key_jackal": [10, 8, 146.0, 138.0, 0.54, 0.73, 0.91, "double"],
	"ash_scribe": [11, 9, 67.0, 267.0, 1.02, 0.45, 1.18, "rune"],
	"shard_warden": [12, 13, 83.0, 115.0, 0.75, 0.54, 0.82, "shards"],
	"copper_cicada": [13, 7, 110.0, 146.0, 0.70, 0.48, 1.08, "shock"],
	"burial_ram": [14, 12, 102.0, 172.0, 0.86, 0.72, 1.19, "ram"],
}

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


static func profile(id: String) -> Dictionary:
	var data: Array = CREATURES[id]
	return {"speed": data[2], "sight": 400.0, "leash": 470.0, "jump": 525.0,
		"reach": data[3], "tell": data[4], "strike": data[5], "recover": data[6]}
