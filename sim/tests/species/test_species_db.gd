extends GutTest


func test_all_species_present() -> void:
	var all := SpeciesDB.load_all()
	assert_eq(all.size(), 30)
	var ids := {}
	for s in all:
		ids[s["id"]] = true
		assert_true(s["motion"] in ["hopper", "flyer"], "%s motion" % s["id"])
		assert_eq(s["mesh_path"], "res://assets/animals/%s.res" % s["id"])
	assert_eq(ids.size(), 30)


func test_anchor_values() -> void:
	var flea := SpeciesDB.get_species("flea")
	assert_eq(flea["motion"], "hopper")
	assert_eq(flea["body_length_m"], 0.0025)
	assert_eq(flea["hop_height_m"], 0.2)
	assert_eq(flea["speed_mps"], 0.5)
	var deer := SpeciesDB.get_species("deer")
	assert_eq(deer["body_length_m"], 1.8)
	assert_eq(deer["hop_height_m"], 1.2)
	assert_eq(deer["speed_mps"], 3.0)
	assert_almost_eq(SpeciesDB.hop_speed(flea), 1.98, 0.01)
	var wasp := SpeciesDB.get_species("wasp")
	assert_eq(wasp["motion"], "flyer")
	assert_eq(SpeciesDB.hop_speed(wasp), 0.0)
	assert_true(SpeciesDB.get_species("firefly")["emissive"])
	assert_eq(SpeciesDB.get_species("ant")["hop_height_m"], 0.005)
	var chicken := SpeciesDB.get_species("chicken")
	assert_false(chicken.is_empty(), "chicken exists")
	assert_eq(chicken.get("motion"), "hopper")


func test_flyer_set() -> void:
	var flyers := ["firefly", "wasp", "hornet", "bee", "housefly", "moth", "butterfly", "dragonfly", "bat", "crow", "pigeon"]
	for s in SpeciesDB.load_all():
		assert_eq(s["motion"] == "flyer", s["id"] in flyers, s["id"])


func test_get_species_unknown_is_empty() -> void:
	assert_true(SpeciesDB.get_species("nope").is_empty())


func test_sorted_by_name() -> void:
	var names: Array = []
	for s in SpeciesDB.load_all():
		names.append(s["name"])
	var sorted := names.duplicate()
	sorted.sort()
	assert_eq(names, sorted)


func test_no_nc_or_sa_license() -> void:
	for s in SpeciesDB.load_all():
		var lic: String = s["credit"]["license"]
		assert_false(lic.contains("NC"), s["id"])
		assert_false(lic.contains("SA"), s["id"])


func test_bake_yaw_valid_and_defaults_to_zero() -> void:
	assert_eq(SpeciesDB.bake_yaw({"id": "x"}), 0)
	for s in SpeciesDB.load_all():
		assert_true(SpeciesDB.bake_yaw(s) in [0, 90, 180, 270], s["id"])


func test_json_ends_with_newline() -> void:
	var f := FileAccess.open(SpeciesDB.DATA_PATH, FileAccess.READ)
	assert_true(f.get_as_text().ends_with("\n"))


## No species is wider (2 * clearance) than the narrowest room rect span, or it could
## not fit (or spawn) there and would get stuck.
func test_every_species_fits_the_narrowest_rect() -> void:
	var narrowest := INF
	for r in RoomData.RECTS:
		narrowest = minf(narrowest, minf(r.size.x, r.size.y))
	for s in SpeciesDB.load_all():
		assert_lte(2.0 * MotionRules.clearance(s), narrowest, s["id"])
