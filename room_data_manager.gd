class_name RoomDataManager
extends RefCounted

const ROOMS_DIR = "user://room_scans"
const INDEX_FILE = "user://room_scans/rooms_index.json"

const SQM_TO_SQFT = 10.7639
const M_TO_FT = 3.28084
const CBM_TO_CBFT = 35.3147


## Ensures the room scans storage directory exists
static func ensure_storage_dir() -> void:
	if not DirAccess.dir_exists_absolute(ROOMS_DIR):
		DirAccess.make_dir_recursive_absolute(ROOMS_DIR)


## Extracts and computes a structured Room Spec from OpenXRFbSceneManager anchors
static func extract_room_spec(scene_manager: OpenXRFbSceneManager, room_name: String = "Scanned Room") -> Dictionary:
	var spec := {
		"version": "1.0",
		"room_name": room_name,
		"scanned_at": Time.get_datetime_string_from_system(),
		"metrics": {
			"width": 0.0,
			"length": 0.0,
			"height": 0.0,
			"floor_elevation": 0.0,
			"ceiling_elevation": 2.5,
			"floor_area_sqm": 0.0,
			"floor_area_sqft": 0.0,
			"wall_area_sqm": 0.0,
			"wall_area_sqft": 0.0,
			"perimeter_m": 0.0,
			"perimeter_ft": 0.0,
			"volume_cbm": 0.0,
			"volume_cbft": 0.0,
			"wall_count": 0,
			"door_count": 0,
			"window_count": 0,
			"furniture_count": 0
		},
		"bounds": {
			"min": [0.0, 0.0, 0.0],
			"max": [0.0, 0.0, 0.0],
			"center": [0.0, 0.0, 0.0]
		},
		"floor": {},
		"ceiling": {},
		"walls": [],
		"openings": [],
		"detected_furniture": [],
		"reimagined_items": []
	}

	if not scene_manager:
		return spec

	var children = scene_manager.get_children()
	if children.is_empty():
		return spec

	var min_x = INF
	var max_x = -INF
	var min_y = INF
	var max_y = -INF
	var min_z = INF
	var max_z = -INF

	var ceiling_y = -INF
	var floor_y = INF
	var found_ceiling = false
	var found_floor = false

	var wall_index = 0
	var opening_index = 0
	var furniture_index = 0
	var total_wall_area_sqm = 0.0

	for child in children:
		if not (child is Node3D):
			continue

		var lbl_node = child.get_node_or_null("Label3D")
		var lbl_text = lbl_node.text.to_lower() if lbl_node else ""
		var child_pos = child.global_position

		# Extract surface dimensions from meshes or collision shapes
		var dims = _extract_element_dimensions(child)
		var elem_w = dims.x
		var elem_h = dims.y
		var elem_d = dims.z

		# Update room bounding extremes
		var corners = _get_transformed_corners(child, dims)
		for pt in corners:
			min_x = minf(min_x, pt.x)
			max_x = maxf(max_x, pt.x)
			min_y = minf(min_y, pt.y)
			max_y = maxf(max_y, pt.y)
			min_z = minf(min_z, pt.z)
			max_z = maxf(max_z, pt.z)

		# Semantic classification
		if "floor" in lbl_text:
			found_floor = true
			floor_y = minf(floor_y, child_pos.y)
			spec["floor"] = {
				"elevation": child_pos.y,
				"center": [child_pos.x, child_pos.y, child_pos.z],
				"dimensions": [elem_w, elem_d]
			}
		elif "ceiling" in lbl_text:
			found_ceiling = true
			ceiling_y = maxf(ceiling_y, child_pos.y)
			spec["ceiling"] = {
				"elevation": child_pos.y,
				"center": [child_pos.x, child_pos.y, child_pos.z],
				"dimensions": [elem_w, elem_d]
			}
		elif "wall" in lbl_text:
			wall_index += 1
			var normal = -child.global_transform.basis.z.normalized()
			var wall_area = elem_w * elem_h
			if wall_area <= 0.0:
				wall_area = elem_w * 2.5 # fallback ceiling height
			total_wall_area_sqm += wall_area

			var wall_data := {
				"id": "wall_" + str(wall_index),
				"type": "wall_face",
				"position": [child_pos.x, child_pos.y, child_pos.z],
				"rotation": [child.global_rotation.x, child.global_rotation.y, child.global_rotation.z],
				"normal": [normal.x, normal.y, normal.z],
				"dimensions": {
					"width": elem_w,
					"height": elem_h
				},
				"surface_area_sqm": snappedf(wall_area, 0.01)
			}
			spec["walls"].append(wall_data)
		elif "door" in lbl_text or "window" in lbl_text:
			opening_index += 1
			var op_type = "door_frame" if "door" in lbl_text else "window_frame"
			var op_data := {
				"id": op_type + "_" + str(opening_index),
				"type": op_type,
				"position": [child_pos.x, child_pos.y, child_pos.z],
				"rotation": [child.global_rotation.x, child.global_rotation.y, child.global_rotation.z],
				"dimensions": {
					"width": elem_w,
					"height": elem_h
				}
			}
			spec["openings"].append(op_data)
		elif (
			"couch" in lbl_text
			or "table" in lbl_text
			or "bed" in lbl_text
			or "storage" in lbl_text
			or "screen" in lbl_text
			or "lamp" in lbl_text
			or "plant" in lbl_text
		):
			furniture_index += 1
			var furn_data := {
				"id": "item_" + str(furniture_index),
				"label": lbl_text,
				"position": [child_pos.x, child_pos.y, child_pos.z],
				"rotation": [child.global_rotation.x, child.global_rotation.y, child.global_rotation.z],
				"dimensions": {
					"width": elem_w,
					"height": elem_h,
					"depth": elem_d
				}
			}
			spec["detected_furniture"].append(furn_data)

	# Aggregate measurements
	var width = max_x - min_x if max_x > min_x and min_x != INF else 0.0
	var length = max_z - min_z if max_z > min_z and min_z != INF else 0.0
	var height = 0.0

	if found_ceiling and found_floor and ceiling_y > floor_y:
		height = ceiling_y - floor_y
	elif max_y > min_y and min_y != INF:
		height = max_y - min_y
	else:
		height = 2.5 # Default architectural room height

	var floor_area = width * length
	var perimeter = (width + length) * 2.0
	var volume = floor_area * height

	spec["metrics"]["width"] = snappedf(width, 0.01)
	spec["metrics"]["length"] = snappedf(length, 0.01)
	spec["metrics"]["height"] = snappedf(height, 0.01)
	spec["metrics"]["floor_elevation"] = snappedf(floor_y if found_floor else min_y, 0.01)
	spec["metrics"]["ceiling_elevation"] = snappedf(ceiling_y if found_ceiling else max_y, 0.01)
	spec["metrics"]["floor_area_sqm"] = snappedf(floor_area, 0.01)
	spec["metrics"]["floor_area_sqft"] = snappedf(floor_area * SQM_TO_SQFT, 0.01)
	spec["metrics"]["wall_area_sqm"] = snappedf(total_wall_area_sqm if total_wall_area_sqm > 0.0 else (perimeter * height), 0.01)
	spec["metrics"]["wall_area_sqft"] = snappedf(spec["metrics"]["wall_area_sqm"] * SQM_TO_SQFT, 0.01)
	spec["metrics"]["perimeter_m"] = snappedf(perimeter, 0.01)
	spec["metrics"]["perimeter_ft"] = snappedf(perimeter * M_TO_FT, 0.01)
	spec["metrics"]["volume_cbm"] = snappedf(volume, 0.01)
	spec["metrics"]["volume_cbft"] = snappedf(volume * CBM_TO_CBFT, 0.01)

	spec["metrics"]["wall_count"] = spec["walls"].size()
	spec["metrics"]["door_count"] = spec["openings"].filter(func(x): return x["type"] == "door_frame").size()
	spec["metrics"]["window_count"] = spec["openings"].filter(func(x): return x["type"] == "window_frame").size()
	spec["metrics"]["furniture_count"] = spec["detected_furniture"].size()

	spec["bounds"]["min"] = [snappedf(min_x, 0.01), snappedf(min_y, 0.01), snappedf(min_z, 0.01)]
	spec["bounds"]["max"] = [snappedf(max_x, 0.01), snappedf(max_y, 0.01), snappedf(max_z, 0.01)]
	spec["bounds"]["center"] = [
		snappedf((min_x + max_x) * 0.5, 0.01),
		snappedf((min_y + max_y) * 0.5, 0.01),
		snappedf((min_z + max_z) * 0.5, 0.01)
	]

	return spec


## Extracts width, height, depth from a scene node's meshes or collision shapes
static func _extract_element_dimensions(node: Node3D) -> Vector3:
	var meshes = node.find_children("*", "MeshInstance3D", true, false)
	for m in meshes:
		if m is MeshInstance3D and m.mesh:
			var aabb = m.get_aabb()
			return aabb.size

	var shapes = node.find_children("*", "CollisionShape3D", true, false)
	for cs in shapes:
		if cs is CollisionShape3D and cs.shape:
			if cs.shape is BoxShape3D:
				return cs.shape.size

	return Vector3(1.0, 1.0, 0.1)


## Returns all 8 corner points of an element's bounding box transformed to world space
static func _get_transformed_corners(node: Node3D, dims: Vector3) -> Array[Vector3]:
	var corners: Array[Vector3] = []
	var half = dims * 0.5
	var tf = node.global_transform

	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				corners.append(tf * Vector3(sx * half.x, sy * half.y, sz * half.z))

	return corners


## Saves room spec to disk and updates rooms index
static func save_room_spec(room_name: String, spec: Dictionary) -> bool:
	ensure_storage_dir()
	var clean_name = _sanitize_filename(room_name)
	var file_path = ROOMS_DIR + "/" + clean_name + ".json"

	spec["room_name"] = room_name
	spec["updated_at"] = Time.get_datetime_string_from_system()

	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if not file:
		printerr("RoomDataManager: Failed to open file for writing: ", file_path)
		return false

	file.store_string(JSON.stringify(spec, "\t"))
	file.close()

	_update_rooms_index(room_name, clean_name, spec)
	print("RoomDataManager: Room saved successfully to: ", file_path)
	return true


## Loads room spec from disk by room name or clean file key
static func load_room_spec(room_name_or_key: String) -> Dictionary:
	var clean_name = _sanitize_filename(room_name_or_key)
	var file_path = ROOMS_DIR + "/" + clean_name + ".json"

	if not FileAccess.file_exists(file_path):
		printerr("RoomDataManager: Room file does not exist: ", file_path)
		return {}

	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		return {}

	var json = JSON.new()
	if json.parse(file.get_as_text()) == OK and json.data is Dictionary:
		file.close()
		return json.data

	file.close()
	return {}


## Returns a list of all saved room summaries
static func list_saved_rooms() -> Array[Dictionary]:
	ensure_storage_dir()
	var list: Array[Dictionary] = []

	if FileAccess.file_exists(INDEX_FILE):
		var file = FileAccess.open(INDEX_FILE, FileAccess.READ)
		if file:
			var json = JSON.new()
			if json.parse(file.get_as_text()) == OK and json.data is Dictionary:
				var index_dict: Dictionary = json.data
				for key in index_dict:
					list.append(index_dict[key])
			file.close()

	return list


## Deletes a saved room profile from disk
static func delete_room_spec(room_name: String) -> bool:
	var clean_name = _sanitize_filename(room_name)
	var file_path = ROOMS_DIR + "/" + clean_name + ".json"

	if FileAccess.file_exists(file_path):
		DirAccess.remove_absolute(file_path)

	# Remove from index
	if FileAccess.file_exists(INDEX_FILE):
		var file = FileAccess.open(INDEX_FILE, FileAccess.READ)
		var index_dict: Dictionary = {}
		if file:
			var json = JSON.new()
			if json.parse(file.get_as_text()) == OK and json.data is Dictionary:
				index_dict = json.data
			file.close()

		if index_dict.has(clean_name):
			index_dict.erase(clean_name)
			var w_file = FileAccess.open(INDEX_FILE, FileAccess.WRITE)
			if w_file:
				w_file.store_string(JSON.stringify(index_dict, "\t"))
				w_file.close()

	return true


static func _update_rooms_index(room_name: String, clean_name: String, spec: Dictionary) -> void:
	var index_dict: Dictionary = {}

	if FileAccess.file_exists(INDEX_FILE):
		var file = FileAccess.open(INDEX_FILE, FileAccess.READ)
		if file:
			var json = JSON.new()
			if json.parse(file.get_as_text()) == OK and json.data is Dictionary:
				index_dict = json.data
			file.close()

	var metrics = spec.get("metrics", {})
	index_dict[clean_name] = {
		"room_name": room_name,
		"key": clean_name,
		"saved_at": spec.get("updated_at", Time.get_datetime_string_from_system()),
		"floor_area_sqm": metrics.get("floor_area_sqm", 0.0),
		"ceiling_height": metrics.get("height", 0.0),
		"walls_count": metrics.get("wall_count", 0),
		"doors_count": metrics.get("door_count", 0),
		"windows_count": metrics.get("window_count", 0)
	}

	var w_file = FileAccess.open(INDEX_FILE, FileAccess.WRITE)
	if w_file:
		w_file.store_string(JSON.stringify(index_dict, "\t"))
		w_file.close()


static func _sanitize_filename(name: String) -> String:
	var clean = name.to_lower().strip_edges()
	clean = clean.replace(" ", "_")
	var regex = RegEx.new()
	regex.compile("[^a-z0-9_]")
	clean = regex.sub(clean, "", true)
	return clean if not clean.is_empty() else "room_scan"


## Smart query helper: returns exact floor plane elevation
static func get_floor_elevation(spec: Dictionary) -> float:
	var metrics = spec.get("metrics", {})
	return float(metrics.get("floor_elevation", 0.0))


## Smart query helper: returns exact ceiling plane elevation
static func get_ceiling_elevation(spec: Dictionary) -> float:
	var metrics = spec.get("metrics", {})
	return float(metrics.get("ceiling_elevation", 2.5))


## Smart query helper: finds closest wall surface and normal for flush snapping
static func get_nearest_wall(point: Vector3, spec: Dictionary) -> Dictionary:
	var walls: Array = spec.get("walls", [])
	if walls.is_empty():
		return {}

	var best_wall: Dictionary = {}
	var min_dist: float = INF

	for w in walls:
		if not (w is Dictionary) or not w.has("position"):
			continue
		var pos_arr: Array = w["position"]
		if pos_arr.size() < 3:
			continue
		var w_pos = Vector3(pos_arr[0], pos_arr[1], pos_arr[2])
		var dist = point.distance_to(w_pos)
		if dist < min_dist:
			min_dist = dist
			best_wall = w

	return best_wall
