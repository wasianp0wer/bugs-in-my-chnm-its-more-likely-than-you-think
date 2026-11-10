class_name RoomData
const CEILING := 2.9
# Union of axis-aligned rects (x, z, w, d) in metres
const RECTS: Array[Rect2] = [
	Rect2(0.0, 5.9, 2.9, 4.8),     # 461 notch (west, by pantry)
	Rect2(2.9, 0.0, 10.2, 10.7),   # 462/472 block
	Rect2(13.1, 3.9, 18.4, 6.8),   # 479/470/478 band
	Rect2(20.3, 10.7, 11.2, 4.1),  # SE extension (470/478 lower)
]
# Outline, clockwise from the notch's NW corner
const OUTLINE: PackedVector2Array = [
	Vector2(0,5.9), Vector2(2.9,5.9), Vector2(2.9,0), Vector2(13.1,0),
	Vector2(13.1,3.9), Vector2(31.5,3.9), Vector2(31.5,14.8), Vector2(20.3,14.8),
	Vector2(20.3,10.7), Vector2(0,10.7)]
const EXTERIOR_EDGES := [2, 5]   # OUTLINE edge i = OUTLINE[i]→OUTLINE[i+1]: north of 462/472, east of 478
const MURAL_EDGE := 2
const COLUMNS: Array[Vector2] = [Vector2(8.0,5.5), Vector2(13.1,7.3), Vector2(20.3,7.3), Vector2(26.0,7.3)]
const COLUMN_SIZE := 0.6
const DOORS := [ {"edge": 8, "center": 16.5}, {"edge": 9, "center": 8.3} ]  # edge index, coordinate along that edge's axis
