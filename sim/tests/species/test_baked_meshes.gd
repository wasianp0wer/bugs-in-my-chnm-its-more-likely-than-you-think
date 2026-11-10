extends GutTest


func test_baked_meshes() -> void:
	for s in SpeciesDB.load_all():
		var m := load(s["mesh_path"]) as Mesh
		assert_not_null(m, "%s loads" % s["id"])
		if m == null:
			continue
		assert_true(m is ArrayMesh, "%s is ArrayMesh" % s["id"])
		var bb := m.get_aabb()
		assert_almost_eq(bb.size.z, 1.0, 0.01, "%s z extent" % s["id"])
		assert_almost_eq(bb.position.y, 0.0, 0.001, "%s min y" % s["id"])
		var c := bb.get_center()
		assert_lt(absf(c.x), 0.01, "%s cx" % s["id"])
		assert_lt(absf(c.z), 0.01, "%s cz" % s["id"])
		for i in m.get_surface_count():
			assert_not_null(m.surface_get_material(i), "%s surf %d material" % [s["id"], i])


func test_credits_lists_every_species() -> void:
	var f := FileAccess.open("res://CREDITS.md", FileAccess.READ)
	assert_not_null(f)
	var text := f.get_as_text()
	for s in SpeciesDB.load_all():
		assert_true(text.contains(s["credit"]["url"]), "%s url" % s["id"])
		assert_true(text.contains(s["credit"]["author"]), "%s author" % s["id"])


func _box_mesh(size: Vector3) -> ArrayMesh:
	var bm := BoxMesh.new()
	bm.size = size
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, bm.get_mesh_arrays())
	am.surface_set_material(0, StandardMaterial3D.new())
	return am


func test_mesh_merge_transformed_applies_xf_and_keeps_material() -> void:
	var m := MeshMerge.transformed(_box_mesh(Vector3(2, 1, 4)), Transform3D(Basis(Vector3.UP, PI / 2.0), Vector3.ZERO))
	var bb := m.get_aabb()
	assert_almost_eq(bb.size, Vector3(4, 1, 2), Vector3(0.001, 0.001, 0.001))
	assert_not_null(m.surface_get_material(0))


func test_mesh_merge_normalise_z_extent_and_floor() -> void:
	var m := MeshMerge.normalised(_box_mesh(Vector3(8, 1, 2)), 90)
	var bb := m.get_aabb()
	assert_almost_eq(bb.size.z, 1.0, 0.001)
	assert_almost_eq(bb.size.x, 0.25, 0.001)
	assert_almost_eq(bb.position.y, 0.0, 0.001)
	assert_almost_eq(bb.get_center().x, 0.0, 0.001)
	assert_almost_eq(bb.get_center().z, 0.0, 0.001)
