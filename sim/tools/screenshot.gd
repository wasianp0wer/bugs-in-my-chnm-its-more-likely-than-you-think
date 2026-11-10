extends SceneTree
## Windowed visual check of the main scene (needs a GPU; NOT --headless):
##   godot --path sim -s res://tools/screenshot.gd --quit-after 3000
## Adds 5,000 fleas, 200 fireflies, 50 wasps and 2 deer, lets them spread for SETTLE s,
## then saves one PNG per camera preset to <repo>/build/shots/.

const MAIN := "res://scenes/main.tscn"
const SETTLE := 4.0
const SHOT_FRAMES := 12  # frames per preset before the capture (shadows, glow, TAA)
const ANIMALS := [["flea", 5000], ["firefly", 200], ["wasp", 50], ["deer", 2]]
## name: [target, yaw (deg), pitch (deg), distance (m)]
const PRESETS := {
	"overview": [Vector3(15.75, 0.0, 7.4), 0.0, 55.0, 30.0],
	"lounge": [Vector3(6.6, 0.4, 2.2), 0.0, 32.0, 5.5],
	"desk": [Vector3(14.6, 0.75, 4.6), 0.0, 25.0, 0.1],
	"floor_fleas": [Vector3(10.5, 0.0, 6.5), 0.0, 14.0, 0.45],
	"fireflies": [Vector3(18.0, 1.4, 7.0), 0.0, 20.0, 1.5],
}

var _main: Main


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_main = (load(MAIN) as PackedScene).instantiate() as Main
	root.add_child(_main)
	await _frames(2)
	for a in ANIMALS:
		_main.add_animals(a[0], a[1])
	var t := 0.0
	while t < SETTLE:
		await process_frame
		t += root.get_process_delta_time()
	var dir := ProjectSettings.globalize_path("res://").path_join("../build/shots")
	DirAccess.make_dir_recursive_absolute(dir)
	for name in PRESETS:
		var p: Array = PRESETS[name]
		_main.camera.set_view(p[0], deg_to_rad(p[1]), deg_to_rad(p[2]), p[3])
		await _frames(SHOT_FRAMES)
		var path := dir.path_join("%s.png" % name)
		root.get_texture().get_image().save_png(path)
		print("screenshot: %s counts=%s fps=%.0f" % [path, _main.swarms.count_by_species(), Engine.get_frames_per_second()])
	quit()


func _frames(n: int) -> void:
	for i in n:
		await process_frame
