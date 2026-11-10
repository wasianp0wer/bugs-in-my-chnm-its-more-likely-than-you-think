extends GutTest

const MAIN := "res://scenes/main.tscn"

func _main() -> Main:
	var m := (load(MAIN) as PackedScene).instantiate() as Main
	add_child_autofree(m)
	return m

func _stubbed(m: Main, wall: int) -> bool:
	return (m.room.get_node("Wall_%d/Stub" % wall) as Node3D).visible

func test_main_wires_add() -> void:
	var m := _main()
	m.hud.add_requested.emit("flea", 10)
	await wait_process_frames(3)
	assert_eq(m.population.counts().get("flea", 0), 10)
	assert_eq(m.swarms.count_by_species().get("flea", 0), 10)
	assert_string_contains((m.hud.get_node("%TotalLabel") as Label).text, "10")

func test_add_clear_spam() -> void:
	var m := _main()
	for i in 20:
		if i % 2 == 0:
			m.hud.add_requested.emit("flea", 250_000)  # several queued batches
		else:
			m.hud.clear_requested.emit()
		await wait_process_frames(1)
	await wait_process_frames(3)
	assert_eq(m.swarms.batch_count(), 0)
	assert_eq(m.swarms.count_by_species(), {})
	assert_eq(m.population.counts(), {})
	assert_eq(m.population.total(), 0)
	assert_eq(m.swarms.get_child_count(), 0, "batch nodes freed")

func test_cutaway_initial_view_stubs_south_walls() -> void:
	var m := _main()
	await wait_process_frames(2)
	assert_true(_stubbed(m, 6), "south wall faces the default camera")
	assert_false(_stubbed(m, 2), "north mural wall stays full")

func test_cutaway_follows_camera() -> void:
	var m := _main()
	await wait_process_frames(2)
	var c := RoomGeometry.bounds().get_center()
	m.camera.set_view(Vector3(c.x, 0.5, c.y), PI, deg_to_rad(50.0), 30.0)  # north of the room
	assert_true(_stubbed(m, 2), "north wall stubbed")
	assert_false(_stubbed(m, 6), "south wall back to full height")

func test_credits_loads() -> void:
	var m := _main()
	m.hud.credits_requested.emit()
	var want := FileAccess.get_file_as_string("res://CREDITS.md")
	assert_gt(want.length(), 0)
	assert_eq((m.hud.get_node("%CreditsText") as RichTextLabel).text, want)
	assert_true((m.hud.get_node("%CreditsPanel") as Control).visible)

func test_hud_lists_species() -> void:
	var m := _main()
	var opt := m.hud.get_node("%SpeciesOption") as OptionButton
	assert_eq(opt.item_count, SpeciesDB.load_all().size())

func test_world_has_columns_and_furniture() -> void:
	var m := _main()
	var n := RoomGeometry.column_boxes().size() + FurnitureFactory.all_boxes().size()
	assert_eq(m.world.boxes.size(), n)
	assert_eq(m.world.rects.size(), RoomData.RECTS.size())
	assert_eq(m.world.ceiling, RoomData.CEILING)
	assert_not_null(m.get_node_or_null("Room"))
	assert_not_null(m.get_node_or_null("Furniture"))

func test_swarms_at_world_origin() -> void:
	var m := _main()
	assert_eq(m.swarms.global_transform, Transform3D.IDENTITY)

func test_pick_point_lands_on_furniture() -> void:
	var m := _main()
	var top := FurnitureFactory.all_boxes()[0]
	for b in FurnitureFactory.all_boxes():
		if b.end.y > top.end.y and b.end.y < 1.0:
			top = b
	var c := top.get_center()
	var hit: Variant = m.camera.pick_point.call(Vector3(c.x, 10.0, c.z), Vector3.DOWN)
	assert_true(hit is Vector3)
	assert_gt((hit as Vector3).y, 0.1, "lands on furniture, not the floor")

func test_fps_readout_updates() -> void:
	var m := _main()
	var label := m.hud.get_node("%FpsLabel") as Label
	label.text = "stale"
	await wait_seconds(0.7)
	assert_string_starts_with(label.text, "FPS ")
