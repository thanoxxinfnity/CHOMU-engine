class_name Assets
extends RefCounted
## Central list of asset paths. Drop replacement GLBs into res://assets/custom/
## (see assets/custom/README.md) and they are picked up automatically.

const K := "res://assets/kenney/"

const PLAYER_MODEL := K + "characters/character-male-b.glb"
const PLAYER_CAR := K + "cars/sedan-sports.glb"

const CHARACTERS := [
	K + "characters/character-female-a.glb", K + "characters/character-female-b.glb",
	K + "characters/character-female-c.glb", K + "characters/character-female-d.glb",
	K + "characters/character-female-e.glb", K + "characters/character-female-f.glb",
	K + "characters/character-male-a.glb", K + "characters/character-male-c.glb",
	K + "characters/character-male-d.glb", K + "characters/character-male-e.glb",
	K + "characters/character-male-f.glb",
]

const TRAFFIC_CARS := [
	K + "cars/sedan.glb", K + "cars/taxi.glb", K + "cars/police.glb", K + "cars/suv.glb",
	K + "cars/van.glb", K + "cars/hatchback-sports.glb", K + "cars/delivery.glb",
	K + "cars/suv-luxury.glb", K + "cars/truck.glb",
]

const DOWNTOWN := [
	K + "city/building-skyscraper-a.glb", K + "city/building-skyscraper-b.glb",
	K + "city/building-skyscraper-c.glb", K + "city/building-skyscraper-d.glb",
	K + "city/building-skyscraper-e.glb",
]

const COMMERCIAL := [
	K + "city/building-a.glb", K + "city/building-b.glb", K + "city/building-c.glb",
	K + "city/building-d.glb", K + "city/building-e.glb", K + "city/building-f.glb",
	K + "city/building-g.glb", K + "city/building-h.glb", K + "city/building-i.glb",
	K + "city/building-j.glb", K + "city/building-k.glb", K + "city/building-l.glb",
	K + "city/building-m.glb", K + "city/building-n.glb",
]

const SUBURBAN := [
	K + "suburban/building-type-a.glb", K + "suburban/building-type-c.glb",
	K + "suburban/building-type-f.glb", K + "suburban/building-type-h.glb",
	K + "suburban/building-type-k.glb", K + "suburban/building-type-n.glb",
	K + "suburban/building-type-q.glb", K + "suburban/building-type-t.glb",
]

const STREET_LIGHT := K + "roads/light-square.glb"
const TREE_LARGE := K + "suburban/tree-large.glb"
const TREE_SMALL := K + "suburban/tree-small.glb"
const PLANTER := K + "suburban/planter.glb"
const TRAFFIC_LIGHT := K + "roads/traffic-light.glb"
const DUMPSTER := K + "roads/dumpster.glb"
const CONE := K + "roads/construction-cone.glb"

const SFX := {
	"engine": "res://assets/audio/engine_loop.ogg",
	"engine_start": "res://assets/audio/engine_start.ogg",
	"horn": "res://assets/audio/horn.ogg",
	"door_open": "res://assets/audio/door_open.ogg",
	"door_close": "res://assets/audio/door_close.ogg",
	"ambience": "res://assets/audio/city_ambience.ogg",
}

static func preload_list() -> Array:
	var l: Array = [PLAYER_MODEL, PLAYER_CAR, STREET_LIGHT, TREE_LARGE, TREE_SMALL,
		PLANTER, TRAFFIC_LIGHT, DUMPSTER, CONE]
	l.append_array(CHARACTERS)
	l.append_array(TRAFFIC_CARS)
	l.append_array(DOWNTOWN)
	l.append_array(COMMERCIAL)
	l.append_array(SUBURBAN)
	for k in SFX:
		l.append(SFX[k])
	for i in 5:
		l.append("res://assets/audio/step_%d.ogg" % i)
	return l
