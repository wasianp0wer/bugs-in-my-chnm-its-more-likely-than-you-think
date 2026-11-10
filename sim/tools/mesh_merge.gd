class_name MeshMerge
extends RefCounted
## Merges every MeshInstance3D under a scene root into one ArrayMesh (root space),
## applying node transforms and rest-pose skinning, keeping materials.


static func merge_raw(root: Node3D) -> ArrayMesh:
	var out := ArrayMesh.new()
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.mesh == null:
			continue
		var skel := _skeleton_of(mi)
		var skin: Skin = mi.skin
		if skin == null and mi.get_skin_reference() != null:
			skin = mi.get_skin_reference().get_skin()
		var xf := _xf_to(mi, root)
		if skel != null and skin != null:
			xf = _xf_to(skel, root)
		for i in mi.mesh.get_surface_count():
			var arrays := _clean(mi.mesh.surface_get_arrays(i))
			var bones: Variant = mi.mesh.surface_get_arrays(i)[Mesh.ARRAY_BONES]
			var weights: Variant = mi.mesh.surface_get_arrays(i)[Mesh.ARRAY_WEIGHTS]
			if skel != null and skin != null and bones is PackedInt32Array and weights is PackedFloat32Array and not (bones as PackedInt32Array).is_empty():
				arrays = _skin_arrays(arrays, bones, weights, skel, skin)
			arrays = _xf_arrays(arrays, xf)
			out.add_surface_from_arrays(mi.mesh.surface_get_primitive_type(i), arrays)
			var mat := mi.get_surface_override_material(i)
			if mat == null:
				mat = mi.mesh.surface_get_material(i)
			if mat == null:
				mat = StandardMaterial3D.new()
			out.surface_set_material(out.get_surface_count() - 1, mat)
	return out


## Copy of `mesh` with every vertex/normal transformed by `xf`. Materials kept.
static func transformed(mesh: ArrayMesh, xf: Transform3D) -> ArrayMesh:
	var out := ArrayMesh.new()
	for i in mesh.get_surface_count():
		var arrays := _xf_arrays(_clean(mesh.surface_get_arrays(i)), xf)
		out.add_surface_from_arrays(mesh.surface_get_primitive_type(i), arrays)
		out.surface_set_material(i, mesh.surface_get_material(i))
	return out


## Yaw (degrees about +Y), then scale so the Z extent is 1, min y = 0, centred in x/z.
static func normalised(mesh: ArrayMesh, yaw_deg: int) -> ArrayMesh:
	var rot := Transform3D(Basis(Vector3.UP, deg_to_rad(float(yaw_deg))), Vector3.ZERO)
	var rotated := transformed(mesh, rot)
	var bb := rotated.get_aabb()
	var k := 1.0 / maxf(bb.size.z, 0.000001)
	var c := bb.get_center()
	var xf := Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * k), Vector3(-c.x, -bb.position.y, -c.z) * k)
	return transformed(rotated, xf)


static func _clean(arrays: Array) -> Array:
	for k in [Mesh.ARRAY_TANGENT, Mesh.ARRAY_BONES, Mesh.ARRAY_WEIGHTS, Mesh.ARRAY_CUSTOM0, Mesh.ARRAY_CUSTOM1, Mesh.ARRAY_CUSTOM2, Mesh.ARRAY_CUSTOM3]:
		arrays[k] = null
	return arrays


static func _xf_arrays(arrays: Array, xf: Transform3D) -> Array:
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var nv := PackedVector3Array()
	nv.resize(verts.size())
	for k in verts.size():
		nv[k] = xf * verts[k]
	arrays[Mesh.ARRAY_VERTEX] = nv
	var norms: Variant = arrays[Mesh.ARRAY_NORMAL]
	if norms is PackedVector3Array:
		var nb := xf.basis.inverse().transposed()
		var nn := PackedVector3Array()
		nn.resize((norms as PackedVector3Array).size())
		for k in nn.size():
			nn[k] = (nb * norms[k]).normalized()
		arrays[Mesh.ARRAY_NORMAL] = nn
	return arrays


static func _skin_arrays(arrays: Array, bones: PackedInt32Array, weights: PackedFloat32Array, skel: Skeleton3D, skin: Skin) -> Array:
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var norms: Variant = arrays[Mesh.ARRAY_NORMAL]
	var stride := bones.size() / maxi(verts.size(), 1)
	var mats: Array[Transform3D] = []
	for b in skin.get_bind_count():
		var bone := skin.get_bind_bone(b)
		if bone < 0:
			bone = skel.find_bone(skin.get_bind_name(b))
		mats.append(skel.get_bone_global_rest(bone) * skin.get_bind_pose(b) if bone >= 0 else Transform3D.IDENTITY)
	var nv := PackedVector3Array()
	nv.resize(verts.size())
	var nn := PackedVector3Array()
	if norms is PackedVector3Array:
		nn.resize(verts.size())
	for v in verts.size():
		var p := Vector3.ZERO
		var n := Vector3.ZERO
		var wsum := 0.0
		for j in stride:
			var w := weights[v * stride + j]
			if w <= 0.0:
				continue
			var m: Transform3D = mats[bones[v * stride + j]]
			p += (m * verts[v]) * w
			if norms is PackedVector3Array:
				n += (m.basis * norms[v]) * w
			wsum += w
		if wsum <= 0.0:
			p = verts[v]
			if norms is PackedVector3Array:
				n = norms[v]
		else:
			p /= wsum
		nv[v] = p
		if norms is PackedVector3Array:
			nn[v] = n.normalized()
	arrays[Mesh.ARRAY_VERTEX] = nv
	if norms is PackedVector3Array:
		arrays[Mesh.ARRAY_NORMAL] = nn
	return arrays


static func _skeleton_of(mi: MeshInstance3D) -> Skeleton3D:
	if mi.skeleton == NodePath():
		return null
	return mi.get_node_or_null(mi.skeleton) as Skeleton3D


static func _xf_to(n: Node3D, stop: Node) -> Transform3D:
	var t := Transform3D.IDENTITY
	var cur: Node = n
	while cur != null and cur != stop:
		if cur is Node3D:
			t = (cur as Node3D).transform * t
		cur = cur.get_parent()
	return t
