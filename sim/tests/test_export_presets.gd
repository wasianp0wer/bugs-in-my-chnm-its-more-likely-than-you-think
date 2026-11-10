extends GutTest

# Exported builds must ship every file the baked meshes depend on (their textures),
# while still leaving out the source models.


func _exclude_patterns() -> Array[String]:
	var cfg := ConfigFile.new()
	assert_eq(cfg.load("res://export_presets.cfg"), OK, "export_presets.cfg should load")
	var patterns: Array[String] = []
	for section in cfg.get_sections():
		if not section.begins_with("preset.") or section.ends_with(".options"):
			continue
		for p in String(cfg.get_value(section, "exclude_filter", "")).split(",", false):
			var pat := p.strip_edges()
			if pat != "":
				patterns.append(pat)
	return patterns


func _matching_pattern(path: String, patterns: Array[String]) -> String:
	for pat in patterns:
		if path.match(pat):
			return pat
	return ""


func _dep_path(dep: String) -> String:
	# Godot 4 may return "uid://...::Type::res://path" or a plain path.
	var parts := dep.split("::")
	return parts[parts.size() - 1].trim_prefix("res://")


func test_mesh_dependencies_are_not_excluded_from_export() -> void:
	var patterns := _exclude_patterns()
	assert_gt(patterns.size(), 0, "presets should have exclude patterns")
	var checked := 0
	for s in SpeciesDB.load_all():
		for dep in ResourceLoader.get_dependencies(s["mesh_path"]):
			var path := _dep_path(dep)
			for candidate in [path, path + ".import"]:
				var pat := _matching_pattern(candidate, patterns)
				assert_eq(pat, "", "%s: dependency %s is excluded by '%s'" % [s["id"], candidate, pat])
			checked += 1
	assert_gt(checked, 0, "some species meshes should have dependencies")


func test_source_models_are_still_excluded() -> void:
	var patterns := _exclude_patterns()
	assert_ne(_matching_pattern("assets/animals/src/deer.glb", patterns), "",
		"source GLBs should not be shipped")
