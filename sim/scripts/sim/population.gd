class_name Population
extends RefCounted
## Bookkeeping of how many animals of each species were requested.

var _counts: Dictionary = {}

func add(id: String, count: int) -> void:
	if count <= 0:
		return
	_counts[id] = int(_counts.get(id, 0)) + count

func clear() -> void:
	_counts.clear()

## A copy, so callers cannot change the bookkeeping.
func counts() -> Dictionary:
	return _counts.duplicate()

func total() -> int:
	var n := 0
	for id in _counts:
		n += int(_counts[id])
	return n
