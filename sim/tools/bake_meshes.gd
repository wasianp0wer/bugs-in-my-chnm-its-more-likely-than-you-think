extends SceneTree
## Bakes assets/animals/src/<id>.glb into assets/animals/<id>.res.
## Run: godot --headless --path sim -s res://tools/bake_meshes.gd
## Output mesh: one ArrayMesh, node transforms applied, materials kept, longest
## horizontal extent 1.0 along +Z, min y 0, centred in x/z.

const SRC_DIR := "res://assets/animals/src/"
const OUT_DIR := "res://assets/animals/"


func _init() -> void:
	var failures := 0
	for s in SpeciesDB.load_all():
		if not _bake(String(s["id"])):
			failures += 1
	quit(1 if failures > 0 else 0)


func _bake(id: String) -> bool:
	var scene := load(SRC_DIR + id + ".glb") as PackedScene
	if scene == null:
		printerr("bake: cannot load GLB for %s" % id)
		return false
	var root := scene.instantiate()
	var parts: Array = []  # [Mesh, Transform3D]
	_collect(root, Transform3D.IDENTITY, parts)
	root.free()
	if parts.is_empty():
		printerr("bake: no meshes in %s" % id)
		return false

	# Pass 1: bounds in model space, to pick the forward axis.
	var bounds := _bounds(parts, Transform3D.IDENTITY)
	# Rotate so the longest horizontal axis lies along Z (90 deg about Y if X is longer).
	var rot := Basis.IDENTITY
	if bounds.size.x > bounds.size.z:
		rot = Basis(Vector3.UP, PI / 2.0)
	var rotated := _bounds(parts, Transform3D(rot, Vector3.ZERO))
	var scale_f := 1.0 / maxf(rotated.size.z, 0.000001)
	var c := rotated.get_center()
	var offset := Vector3(-c.x, -rotated.position.y, -c.z) * scale_f
	var xf := Transform3D(rot.scaled(Vector3.ONE * scale_f), offset)

	var out := ArrayMesh.new()
	for p in parts:
		var mesh: Mesh = p[0]
		var t: Transform3D = xf * (p[1] as Transform3D)
		for i in mesh.get_surface_count():
			var arrays := mesh.surface_get_arrays(i)
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var nv := PackedVector3Array()
			nv.resize(verts.size())
			for k in verts.size():
				nv[k] = t * verts[k]
			arrays[Mesh.ARRAY_VERTEX] = nv
			var norms: Variant = arrays[Mesh.ARRAY_NORMAL]
			if norms is PackedVector3Array:
				var nn := PackedVector3Array()
				nn.resize(norms.size())
				var nb := t.basis.inverse().transposed()
				for k in norms.size():
					nn[k] = (nb * norms[k]).normalized()
				arrays[Mesh.ARRAY_NORMAL] = nn
			arrays = _clean(arrays)
			out.add_surface_from_arrays(mesh.surface_get_primitive_type(i), arrays)
			var mat := mesh.surface_get_material(i)
			if mat == null:
				mat = StandardMaterial3D.new()
			out.surface_set_material(out.get_surface_count() - 1, mat)
	out.resource_name = id
	var err := ResourceSaver.save(out, OUT_DIR + id + ".res")
	if err != OK:
		printerr("bake: save failed for %s (%d)" % [id, err])
		return false
	var bb := out.get_aabb()
	print("baked %s surfaces=%d aabb=%s" % [id, out.get_surface_count(), bb])
	return true


func _collect(node: Node, parent_xf: Transform3D, parts: Array) -> void:
	var xf := parent_xf
	if node is Node3D:
		xf = parent_xf * (node as Node3D).transform
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		var mi := node as MeshInstance3D
		var mesh := mi.mesh
		# Per-instance material overrides win over mesh materials.
		var copy := ArrayMesh.new()
		for i in mesh.get_surface_count():
			copy.add_surface_from_arrays(mesh.surface_get_primitive_type(i), _clean(mesh.surface_get_arrays(i)))
			var mat := mi.get_surface_override_material(i)
			if mat == null:
				mat = mesh.surface_get_material(i)
			copy.surface_set_material(i, mat)
		parts.append([copy, xf])
	for ch in node.get_children():
		_collect(ch, xf, parts)


func _bounds(parts: Array, extra: Transform3D) -> AABB:
	var have := false
	var box := AABB()
	for p in parts:
		var t: Transform3D = extra * (p[1] as Transform3D)
		var mesh: Mesh = p[0]
		for i in mesh.get_surface_count():
			var verts: PackedVector3Array = mesh.surface_get_arrays(i)[Mesh.ARRAY_VERTEX]
			for v in verts:
				var w := t * v
				if not have:
					box = AABB(w, Vector3.ZERO)
					have = true
				else:
					box = box.expand(w)
	return box


## Drops data that is useless without a skeleton, or that breaks re-adding the surface.
func _clean(arrays: Array) -> Array:
	arrays[Mesh.ARRAY_TANGENT] = null
	arrays[Mesh.ARRAY_BONES] = null
	arrays[Mesh.ARRAY_WEIGHTS] = null
	for k in [Mesh.ARRAY_CUSTOM0, Mesh.ARRAY_CUSTOM1, Mesh.ARRAY_CUSTOM2, Mesh.ARRAY_CUSTOM3]:
		arrays[k] = null
	return arrays
