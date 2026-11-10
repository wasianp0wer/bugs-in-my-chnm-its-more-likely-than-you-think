class_name SwarmManager
extends Node3D
## Owns every SwarmBatch. Large adds are split into batches of at most BATCH_MAX and
## created one per frame so the UI stays responsive. Counts include queued batches.

const BATCH_MAX := 100_000

var _params: Dictionary = {}
var _batches: Array[SwarmBatch] = []
var _pending: Array[Dictionary] = []  # {sp, count}, created one per frame
var _next_seed := 1


func configure(world: CollisionWorld) -> void:
	_params = world.to_shader_params()
	for b in _batches:
		b.set_world_params(_params)


## Queues `count` animals of species `sp`; the first batch is created right away.
func add(sp: Dictionary, count: int) -> void:
	assert(not _params.is_empty(), "SwarmManager.configure() first")
	var left := count
	while left > 0:
		var n := mini(left, BATCH_MAX)
		_pending.append({"sp": sp, "count": n})
		left -= n
	_spawn_next()


func clear() -> void:
	for b in _batches:
		b.queue_free()
	_batches.clear()
	_pending.clear()


func count_by_species() -> Dictionary:
	var out := {}
	for b in _batches:
		out[b.species_id] = int(out.get(b.species_id, 0)) + b.amount
	for p in _pending:
		var id: String = p["sp"]["id"]
		out[id] = int(out.get(id, 0)) + int(p["count"])
	return out


func batch_count() -> int:
	return _batches.size()


func _process(_delta: float) -> void:
	_spawn_next()


func _spawn_next() -> void:
	if _pending.is_empty():
		return
	var p: Dictionary = _pending.pop_front()
	var b := SwarmBatch.create(p["sp"], p["count"], _params, _next_seed)
	_next_seed += 1
	add_child(b)
	_batches.append(b)
