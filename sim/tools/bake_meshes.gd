extends SceneTree
## Bakes assets/animals/src/<id>.glb into assets/animals/<id>.res.
## Run: godot --headless --path sim -s res://tools/bake_meshes.gd
## Output: one ArrayMesh (node transforms + rest-pose skinning applied, materials kept),
## yawed by the species' bake_yaw_deg so the head faces +Z, scaled so the Z extent is 1.0,
## min y 0, centred in x/z.

const SRC_DIR := "res://assets/animals/src/"
const OUT_DIR := "res://assets/animals/"


func _init() -> void:
	var failures := 0
	for s in SpeciesDB.load_all():
		if not _bake(s):
			failures += 1
	quit(1 if failures > 0 else 0)


func _bake(s: Dictionary) -> bool:
	var id := String(s["id"])
	var scene := load(SRC_DIR + id + ".glb") as PackedScene
	if scene == null:
		printerr("bake: cannot load GLB for %s" % id)
		return false
	var root := scene.instantiate() as Node3D
	var merged := MeshMerge.merge_raw(root)
	root.free()
	if merged.get_surface_count() == 0:
		printerr("bake: no meshes in %s" % id)
		return false
	var out := MeshMerge.normalised(merged, SpeciesDB.bake_yaw(s))
	out.resource_name = id
	var err := ResourceSaver.save(out, OUT_DIR + id + ".res")
	if err != OK:
		printerr("bake: save failed for %s (%d)" % [id, err])
		return false
	print("baked %s yaw=%d surfaces=%d aabb=%s" % [id, SpeciesDB.bake_yaw(s), out.get_surface_count(), out.get_aabb()])
	return true
