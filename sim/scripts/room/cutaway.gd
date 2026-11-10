class_name Cutaway

## Show full-height walls except those facing the camera, which drop to stubs.
static func apply(room: Node3D, facing: PackedInt32Array) -> void:
	for i in RoomData.OUTLINE.size():
		var wall := room.get_node_or_null("Wall_%d" % i)
		if wall == null:
			continue
		var is_facing := facing.has(i)
		(wall.get_node("Full") as Node3D).visible = not is_facing
		(wall.get_node("Stub") as Node3D).visible = is_facing
