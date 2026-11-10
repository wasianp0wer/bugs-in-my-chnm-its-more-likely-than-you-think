class_name SwarmManager
extends Node3D
## Owns every SwarmBatch. Each add is queued as one {sp, remaining} entry; up to
## BATCH_MAX animals are carved off it per frame into a new batch, so even an absurd
## count costs nothing up front and the UI stays responsive. Counts include the queue.

const BATCH_MAX := 100_000

var _params: Dictionary = {}
var _batches: Array[SwarmBatch] = []
var _pending: Array[Dictionary] = []  # {sp, remaining}; one batch carved off per frame
var _next_seed := 1


func configure(world: CollisionWorld) -> void:
	_params = world.to_shader_params()
	for b in _batches:
		b.set_world_params(_params)


## Queues `count` animals of species `sp`; the first batch is created right away.
func add(sp: Dictionary, count: int) -> void:
	assert(not _params.is_empty(), "SwarmManager.configure() first")
	if count > 0:
		_pending.append({"sp": sp, "remaining": count})
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
		out[id] = int(out.get(id, 0)) + int(p["remaining"])
	return out


func batch_count() -> int:
	return _batches.size()


func _process(_delta: float) -> void:
	_spawn_next()


func _spawn_next() -> void:
	if _pending.is_empty():
		return
	var p: Dictionary = _pending[0]
	var n := mini(int(p["remaining"]), BATCH_MAX)
	p["remaining"] = int(p["remaining"]) - n
	if p["remaining"] == 0:
		_pending.pop_front()
	var b := SwarmBatch.create(p["sp"], n, _params, _next_seed)
	_next_seed += 1
	add_child(b)
	_batches.append(b)
