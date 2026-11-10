class_name Main
extends Node3D
## Playable app: the CHNM office room, its furniture, the dollhouse camera, the HUD and
## the GPU swarms.
##
## Coordinates: room-local metres ARE world metres. The room, the furniture and the
## SwarmManager all sit at the world origin with an identity transform, because the
## particle shader simulates in world space against CollisionWorld's room-local boxes.

const CREDITS_PATH := "res://CREDITS.md"
const FPS_INTERVAL := 0.5

@onready var camera: DollhouseCamera = $Camera
@onready var swarms: SwarmManager = $Swarms
@onready var hud: Hud = $UI/Hud

var room: Node3D
var furniture: Node3D
var world: CollisionWorld
var population := Population.new()

var _species_by_id: Dictionary = {}
var _names: Dictionary = {}
var _fps_timer := 0.0


func _ready() -> void:
	room = RoomBuilder.build()
	add_child(room)
	furniture = FurnitureFactory.build_all()
	add_child(furniture)

	var boxes: Array[AABB] = FurnitureFactory.all_boxes()
	world = CollisionWorld.new(RoomData.RECTS, boxes, RoomData.CEILING)
	assert(swarms.global_transform == Transform3D.IDENTITY, "particles are simulated in world space")
	swarms.configure(world)

	assert(camera.room_bounds.is_equal_approx(RoomGeometry.bounds()), "camera bounds must match the room")
	camera.pick_point = func(origin: Vector3, dir: Vector3) -> Variant:
		return BoxPicker.pick(origin, dir, boxes)
	# The camera emitted `moved` in its own _ready, before this connect; its deferred
	# emit will arrive later, but apply once now so the first frame is already cut away.
	camera.moved.connect(_on_camera_moved)
	_on_camera_moved(camera.global_position)

	var species := SpeciesDB.load_all()
	for sp in species:
		_species_by_id[sp["id"]] = sp
		_names[sp["id"]] = sp["name"]
	hud.set_species(species)
	hud.add_requested.connect(add_animals)
	hud.clear_requested.connect(clear_animals)
	hud.credits_requested.connect(_on_credits)
	_refresh_counts()


func add_animals(species_id: String, count: int) -> void:
	if count <= 0 or not _species_by_id.has(species_id):
		return
	swarms.add(_species_by_id[species_id], count)
	population.add(species_id, count)
	_refresh_counts()


func clear_animals() -> void:
	swarms.clear()
	population.clear()
	_refresh_counts()


func _process(delta: float) -> void:
	_fps_timer += delta
	if _fps_timer >= FPS_INTERVAL:
		_fps_timer = 0.0
		hud.set_fps(Engine.get_frames_per_second())


func _on_camera_moved(cam_pos: Vector3) -> void:
	Cutaway.apply(room, RoomGeometry.walls_facing_camera(cam_pos))


func _on_credits() -> void:
	hud.show_credits(FileAccess.get_file_as_string(CREDITS_PATH))


func _refresh_counts() -> void:
	hud.set_counts(population.counts(), _names)
