class_name SpeciesDB
extends RefCounted
## Species table loaded from res://data/species.json.

const DATA_PATH := "res://data/species.json"
const MESH_DIR := "res://assets/animals/"
const GRAVITY := 9.8


static func load_all() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var f := FileAccess.open(DATA_PATH, FileAccess.READ)
	if f == null:
		push_error("SpeciesDB: cannot open %s" % DATA_PATH)
		return result
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if not (parsed is Array):
		push_error("SpeciesDB: %s is not a JSON array" % DATA_PATH)
		return result
	for entry in parsed:
		var s: Dictionary = (entry as Dictionary).duplicate(true)
		s["mesh_path"] = "%s%s.res" % [MESH_DIR, s["id"]]
		result.append(s)
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return String(a["name"]) < String(b["name"]))
	return result


static func get_species(id: String) -> Dictionary:
	for s in load_all():
		if s["id"] == id:
			return s
	return {}


static func hop_speed(s: Dictionary) -> float:
	if s.get("motion", "") != "hopper":
		return 0.0
	return sqrt(2.0 * GRAVITY * float(s.get("hop_height_m", 0.0)))
