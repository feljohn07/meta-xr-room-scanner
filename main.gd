extends StartXR

const ENVIRONMENT_DEPTH_MATERIAL = preload("res://environment_depth_material.tres")
const BLUE_MATERIAL = preload("res://blue_material.tres")
const MEASUREMENT_LINE_SCENE = preload("res://measurement_line.tscn")

const SAVED_SCENES_FILE = "user://saved_anchor_scenes.json"
const LEGACY_SPATIAL_ANCHORS_FILE = "user://openxr_fb_spatial_anchors.json"

var passthrough_enabled: bool = false
var scene_and_spatial_anchors_displayed: bool = true
var selected_spatial_anchor_node: Node3D = null
var global_environment_depth_enabled: bool = true

var active_scene_name: String = "Default"
var saved_scenes: Dictionary = {}
var _is_switching_layout: bool = false
var _setup := false

# Measurement System
var tape_measure_active: bool = false
var tape_measure_point_a: Vector3 = Vector3.ZERO
var tape_measure_has_point_a: bool = false
var tape_measure_preview_line: Node3D = null
var placed_measurements: Array[Node3D] = []
var use_imperial_units: bool = false
var _last_trigger_press_msec: int = 0
var hovered_measurement_line: Node3D = null

# Dominant Hand & Customization
var dominant_hand: String = "right"
var active_anchor_color_index: int = 4 # Default Cyan (#00FFFF)
var active_anchor_color: Color = Color("#00FFFF")
var active_anchor_label: String = ""

@onready var left_hand: XRController3D = $XROrigin3D/LeftHand
@onready var right_hand: XRController3D = $XROrigin3D/RightHand
@onready var xr_camera: XRCamera3D = $XROrigin3D/XRCamera3D
@onready var right_hand_pointer: XRController3D = $XROrigin3D/RightHandPointer
@onready var right_hand_pointer_raycast: RayCast3D = $XROrigin3D/RightHandPointer/RayCast3D
@onready var scene_pointer_mesh: MeshInstance3D = $XROrigin3D/RightHandPointer/ScenePointerMesh
@onready var scene_colliding_mesh: MeshInstance3D = $XROrigin3D/RightHandPointer/SceneCollidingMesh
@onready var function_pointer = $XROrigin3D/RightHandPointer/FunctionPointer
@onready var right_reticle_ring: MeshInstance3D = get_node_or_null("XROrigin3D/RightHandPointer/SceneCollidingMesh/ReticleRing")

@onready var left_hand_pointer: XRController3D = $XROrigin3D/LeftHandPointer
@onready var left_hand_pointer_raycast: RayCast3D = $XROrigin3D/LeftHandPointer/RayCast3D
@onready var left_scene_pointer_mesh: MeshInstance3D = $XROrigin3D/LeftHandPointer/ScenePointerMesh
@onready var left_scene_colliding_mesh: MeshInstance3D = $XROrigin3D/LeftHandPointer/SceneCollidingMesh
@onready var left_function_pointer = $XROrigin3D/LeftHandPointer/FunctionPointer
@onready var left_reticle_ring: MeshInstance3D = get_node_or_null("XROrigin3D/LeftHandPointer/SceneCollidingMesh/ReticleRing")

@onready var wrist_menu: WristMenu = %WristMenu
@onready var world_environment: WorldEnvironment = $WorldEnvironment
@onready var scene_manager: OpenXRFbSceneManager = $XROrigin3D/OpenXRFbSceneManager
@onready var spatial_anchor_manager: OpenXRFbSpatialAnchorManager = $XROrigin3D/OpenXRFbSpatialAnchorManager
# Don't statically type this as `OpenXRMetaEnvironmentDepth` because it doesn't exist on Godot 4.4.
@onready var environment_depth_node = $XROrigin3D/XRCamera3D/OpenXRMetaEnvironmentDepth
@onready var depth_testing_mesh: MeshInstance3D = $XROrigin3D/RightHand/DepthTestingMesh
@onready var scene_menu_viewport = %SceneMenuViewport
@onready var mini_cad_viewer: MiniCADViewer = %MiniCADViewer

const COLORS = [
	"#FF0000",  # Red
	"#00FF00",  # Green
	"#0000FF",  # Blue
	"#FFFF00",  # Yellow
	"#00FFFF",  # Cyan
	"#FF00FF",  # Magenta
	"#FF8000",  # Orange
	"#800080",  # Purple
]


func get_active_pointer() -> XRController3D:
	return right_hand_pointer if dominant_hand == "right" else left_hand_pointer


func get_active_raycast() -> RayCast3D:
	return right_hand_pointer_raycast if dominant_hand == "right" else left_hand_pointer_raycast


func get_active_pointer_mesh() -> MeshInstance3D:
	return scene_pointer_mesh if dominant_hand == "right" else left_scene_pointer_mesh


func get_active_colliding_mesh() -> MeshInstance3D:
	return scene_colliding_mesh if dominant_hand == "right" else left_scene_colliding_mesh


func get_active_function_pointer() -> Node:
	return function_pointer if dominant_hand == "right" else left_function_pointer


func get_active_reticle_ring() -> MeshInstance3D:
	return right_reticle_ring if dominant_hand == "right" else left_reticle_ring


func set_dominant_hand(hand: String) -> void:
	dominant_hand = hand
	var is_right = (dominant_hand == "right")

	if right_hand_pointer:
		right_hand_pointer.visible = is_right and scene_and_spatial_anchors_displayed
	if right_hand_pointer_raycast:
		right_hand_pointer_raycast.enabled = is_right and scene_and_spatial_anchors_displayed
	if left_hand_pointer:
		left_hand_pointer.visible = (not is_right) and scene_and_spatial_anchors_displayed
	if left_hand_pointer_raycast:
		left_hand_pointer_raycast.enabled = (not is_right) and scene_and_spatial_anchors_displayed

	if selected_spatial_anchor_node:
		selected_spatial_anchor_node.set_selected(false)
		selected_spatial_anchor_node = null
	if right_reticle_ring:
		right_reticle_ring.visible = false
	if left_reticle_ring:
		left_reticle_ring.visible = false

	if wrist_menu:
		var target_parent = left_hand if is_right else right_hand
		if target_parent and wrist_menu.get_parent() != target_parent:
			wrist_menu.get_parent().remove_child(wrist_menu)
			target_parent.add_child(wrist_menu)
		if is_right:
			wrist_menu.transform = Transform3D(Basis(Vector3(1, 0, 0), Vector3(0, 0.866025, 0.5), Vector3(0, -0.5, 0.866025)), Vector3(0.05, 0.04, 0.06))
		else:
			wrist_menu.transform = Transform3D(Basis(Vector3(1, 0, 0), Vector3(0, 0.866025, 0.5), Vector3(0, -0.5, 0.866025)), Vector3(-0.05, 0.04, 0.06))
		wrist_menu.set_dominant_hand(dominant_hand)

	if scene_menu_viewport and scene_menu_viewport.visible:
		anchor_menu_to_hand()


func _ready() -> void:
	super._ready()
	if xr_interface and xr_interface.is_initialized():
		if not xr_interface.session_begun.is_connected(_on_openxr_session_begun):
			xr_interface.session_begun.connect(_on_openxr_session_begun)

	for render_model in [%LeftControllerFbRenderModel, %RightControllerFbRenderModel]:
		render_model.openxr_fb_render_model_loaded.connect(_on_openxr_fb_render_model_loaded.bind(render_model))

	if scene_manager and not scene_manager.child_entered_tree.is_connected(_on_scene_anchor_child_entered):
		scene_manager.child_entered_tree.connect(_on_scene_anchor_child_entered)

	if right_hand_pointer:
		if not right_hand_pointer.button_released.is_connected(_on_pointer_button_released.bind(right_hand_pointer)):
			right_hand_pointer.button_released.connect(_on_pointer_button_released.bind(right_hand_pointer))
		if not right_hand_pointer.button_pressed.is_connected(_on_pointer_button_pressed.bind(right_hand_pointer)):
			right_hand_pointer.button_pressed.connect(_on_pointer_button_pressed.bind(right_hand_pointer))

	if left_hand_pointer:
		if not left_hand_pointer.button_released.is_connected(_on_pointer_button_released.bind(left_hand_pointer)):
			left_hand_pointer.button_released.connect(_on_pointer_button_released.bind(left_hand_pointer))
		if not left_hand_pointer.button_pressed.is_connected(_on_pointer_button_pressed.bind(left_hand_pointer)):
			left_hand_pointer.button_pressed.connect(_on_pointer_button_pressed.bind(left_hand_pointer))

	if right_hand and not right_hand.button_pressed.is_connected(_on_right_hand_controller_button_pressed):
		right_hand.button_pressed.connect(_on_right_hand_controller_button_pressed)

	if wrist_menu:
		wrist_menu.xr_camera = xr_camera
		if not wrist_menu.passthrough_toggled.is_connected(_on_wrist_passthrough_toggled):
			wrist_menu.passthrough_toggled.connect(_on_wrist_passthrough_toggled)
		if not wrist_menu.cad_toggled.is_connected(_on_wrist_cad_toggled):
			wrist_menu.cad_toggled.connect(_on_wrist_cad_toggled)
		if not wrist_menu.tape_toggled.is_connected(_on_wrist_tape_toggled):
			wrist_menu.tape_toggled.connect(_on_wrist_tape_toggled)
		if not wrist_menu.undo_measurement.is_connected(undo_last_measurement):
			wrist_menu.undo_measurement.connect(undo_last_measurement)
		if not wrist_menu.menu_toggled.is_connected(toggle_scene_menu):
			wrist_menu.menu_toggled.connect(toggle_scene_menu)
		if not wrist_menu.cycle_color.is_connected(cycle_anchor_color):
			wrist_menu.cycle_color.connect(cycle_anchor_color)
		if not wrist_menu.toggle_hand.is_connected(_on_wrist_toggle_hand):
			wrist_menu.toggle_hand.connect(_on_wrist_toggle_hand)

	if depth_testing_mesh:
		depth_testing_mesh.set_surface_override_material(0, ENVIRONMENT_DEPTH_MATERIAL if global_environment_depth_enabled else BLUE_MATERIAL)

	_setup_scene_menu()
	set_dominant_hand(dominant_hand)
	if wrist_menu:
		wrist_menu.set_active_color(active_anchor_color)
		_update_measurement_metrics()


func _setup_scene_menu() -> void:
	if not scene_menu_viewport:
		return

	scene_menu_viewport.visible = false

	# Allow a frame for SubViewport and Control node initialization if needed
	var ui = scene_menu_viewport.get_scene_root()
	if not ui:
		await get_tree().process_frame
		ui = scene_menu_viewport.get_scene_root()

	if ui:
		if not ui.load_scene_requested.is_connected(switch_to_layout):
			ui.load_scene_requested.connect(switch_to_layout)
		if not ui.save_scene_requested.is_connected(save_current_layout):
			ui.save_scene_requested.connect(save_current_layout)
		if not ui.delete_scene_requested.is_connected(delete_layout):
			ui.delete_scene_requested.connect(delete_layout)
		if not ui.clear_anchors_requested.is_connected(_on_ui_clear_anchors):
			ui.clear_anchors_requested.connect(_on_ui_clear_anchors)
		if not ui.request_room_capture.is_connected(_on_ui_request_room_capture):
			ui.request_room_capture.connect(_on_ui_request_room_capture)
		if not ui.close_requested.is_connected(_on_ui_close_requested):
			ui.close_requested.connect(_on_ui_close_requested)

		# Measurement connections
		if not ui.toggle_tape_measure_requested.is_connected(_on_ui_toggle_tape_measure):
			ui.toggle_tape_measure_requested.connect(_on_ui_toggle_tape_measure)
		if not ui.clear_measurements_requested.is_connected(clear_tape_measurements):
			ui.clear_measurements_requested.connect(clear_tape_measurements)
		if not ui.refresh_room_dimensions_requested.is_connected(refresh_and_send_room_dimensions):
			ui.refresh_room_dimensions_requested.connect(refresh_and_send_room_dimensions)
		if not ui.unit_preference_changed.is_connected(_on_ui_unit_preference_changed):
			ui.unit_preference_changed.connect(_on_ui_unit_preference_changed)
		if ui.has_signal("toggle_cad_view_requested") and not ui.toggle_cad_view_requested.is_connected(toggle_cad_viewer):
			ui.toggle_cad_view_requested.connect(toggle_cad_viewer)

	if mini_cad_viewer:
		mini_cad_viewer.initialize_managers(scene_manager, spatial_anchor_manager)

	_update_scene_ui()


func _on_ui_clear_anchors() -> void:
	clear_all_anchors(true)


func _on_ui_request_room_capture() -> void:
	if scene_manager:
		scene_manager.request_scene_capture()


func _on_ui_close_requested() -> void:
	toggle_scene_menu(false)


func _on_ui_toggle_tape_measure(enabled: bool) -> void:
	tape_measure_active = enabled
	tape_measure_has_point_a = false
	if not enabled and tape_measure_preview_line:
		tape_measure_preview_line.visible = false
	_update_tape_ui_state()


func _on_ui_unit_preference_changed(use_imperial: bool) -> void:
	use_imperial_units = use_imperial
	for line in placed_measurements:
		if is_instance_valid(line) and line.has_method("update_points"):
			line.update_points(line.point_a, line.point_b, use_imperial_units)
	if tape_measure_preview_line and tape_measure_preview_line.visible:
		tape_measure_preview_line.use_imperial = use_imperial_units
	_update_measurement_metrics()


func clear_tape_measurements() -> void:
	for line in placed_measurements:
		if is_instance_valid(line):
			line.queue_free()
	placed_measurements.clear()
	hovered_measurement_line = null
	tape_measure_has_point_a = false
	if tape_measure_preview_line:
		tape_measure_preview_line.visible = false
	_update_tape_ui_state()
	_update_measurement_metrics()


func get_cumulative_measurement_distance() -> float:
	var total := 0.0
	for line in placed_measurements:
		if is_instance_valid(line) and "distance" in line:
			total += line.distance
	return total


func _update_measurement_metrics() -> void:
	var total_dist = get_cumulative_measurement_distance()
	var count = placed_measurements.size()
	if wrist_menu:
		wrist_menu.set_metrics_info(total_dist, use_imperial_units, count)


func undo_last_measurement() -> void:
	if placed_measurements.is_empty():
		return
	var last_line = placed_measurements.pop_back()
	if hovered_measurement_line == last_line:
		hovered_measurement_line = null
	if is_instance_valid(last_line):
		last_line.queue_free()
	_update_measurement_metrics()
	var active_ptr = get_active_pointer()
	if active_ptr:
		trigger_haptic(active_ptr, 100.0, 0.4, 0.05)


func delete_measurement(line_node: Node3D) -> void:
	if line_node in placed_measurements:
		placed_measurements.erase(line_node)
	if hovered_measurement_line == line_node:
		hovered_measurement_line = null
	if is_instance_valid(line_node):
		line_node.queue_free()
	_update_measurement_metrics()


func cycle_anchor_color() -> void:
	active_anchor_color_index = (active_anchor_color_index + 1) % COLORS.size()
	active_anchor_color = Color(COLORS[active_anchor_color_index])
	if wrist_menu:
		wrist_menu.set_active_color(active_anchor_color)
	var active_ptr = get_active_pointer()
	if active_ptr:
		trigger_haptic(active_ptr, 120.0, 0.35, 0.04)


func _on_wrist_passthrough_toggled() -> void:
	enable_passthrough(not passthrough_enabled)


func _on_wrist_cad_toggled() -> void:
	toggle_cad_viewer()


func _on_wrist_tape_toggled() -> void:
	_on_ui_toggle_tape_measure(not tape_measure_active)


func _on_wrist_toggle_hand() -> void:
	set_dominant_hand("left" if dominant_hand == "right" else "right")


func trigger_haptic(controller: XRController3D, frequency: float = 100.0, amplitude: float = 0.5, duration: float = 0.05) -> void:
	if controller:
		controller.trigger_haptic_pulse("haptic", frequency, amplitude, duration, 0.0)


func _update_tape_ui_state() -> void:
	if scene_menu_viewport:
		var ui = scene_menu_viewport.get_scene_root()
		if ui and ui.has_method("set_tape_measure_state"):
			ui.set_tape_measure_state(tape_measure_active, tape_measure_has_point_a)
	if wrist_menu:
		wrist_menu.set_tape_active(tape_measure_active)
	_update_measurement_metrics()


func _on_openxr_session_begun() -> void:
	if _setup:
		return
	_setup = true

	load_all_saved_scenes()
	enable_passthrough(true)

	if scene_manager and not scene_manager.are_scene_anchors_created():
		scene_manager.create_scene_anchors()

	var environment_depth = Engine.get_singleton("OpenXRMetaEnvironmentDepthExtension")
	if environment_depth:
		print("Supports environment depth: ", environment_depth.is_environment_depth_supported())
		print("Supports hand removal: ", environment_depth.is_hand_removal_supported())
		if environment_depth.is_environment_depth_supported():
			environment_depth.start_environment_depth()
			print("Environment depth started: ", environment_depth.is_environment_depth_started())

	refresh_and_send_room_dimensions()
	get_tree().create_timer(1.0).timeout.connect(refresh_and_send_room_dimensions)
	get_tree().create_timer(2.5).timeout.connect(refresh_and_send_room_dimensions)


func _on_scene_anchor_child_entered(_child: Node) -> void:
	# Give the spawned anchor a frame or two to run setup_scene()
	await get_tree().create_timer(0.2).timeout
	refresh_and_send_room_dimensions()
	if mini_cad_viewer and mini_cad_viewer.visible:
		mini_cad_viewer.rebuild_cad_model()


func calculate_room_dimensions() -> Dictionary:
	var dims := {
		"height": 0.0,
		"width": 0.0,
		"length": 0.0,
		"surfaces_count": 0
	}

	if not scene_manager:
		return dims

	var children = scene_manager.get_children()
	dims["surfaces_count"] = children.size()

	if children.is_empty():
		return dims

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

	for child in children:
		if child is Node3D:
			var pos = child.global_position

			# Check semantic labels if available
			var lbl_node = child.get_node_or_null("Label3D")
			var lbl_text = lbl_node.text.to_lower() if lbl_node else ""
			if "floor" in lbl_text:
				found_floor = true
				floor_y = minf(floor_y, pos.y)
			elif "ceiling" in lbl_text:
				found_ceiling = true
				ceiling_y = maxf(ceiling_y, pos.y)

			# Calculate bounding extents from meshes
			var meshes = child.find_children("*", "MeshInstance3D", true, false)
			var has_mesh = false
			for m in meshes:
				if m is MeshInstance3D and m.mesh:
					has_mesh = true
					var aabb = m.get_aabb()
					var tf = m.global_transform
					for i in range(8):
						var corner = tf * aabb.get_endpoint(i)
						min_x = minf(min_x, corner.x)
						max_x = maxf(max_x, corner.x)
						min_y = minf(min_y, corner.y)
						max_y = maxf(max_y, corner.y)
						min_z = minf(min_z, corner.z)
						max_z = maxf(max_z, corner.z)
						if found_floor and "floor" in lbl_text:
							floor_y = minf(floor_y, corner.y)
						if found_ceiling and "ceiling" in lbl_text:
							ceiling_y = maxf(ceiling_y, corner.y)

			if not has_mesh:
				# Fallback: check collision shapes
				var col_shapes = child.find_children("*", "CollisionShape3D", true, false)
				for cs in col_shapes:
					if cs is CollisionShape3D and cs.shape:
						var tf = cs.global_transform
						if cs.shape is BoxShape3D:
							var h_size = cs.shape.size * 0.5
							for sx in [-1, 1]:
								for sy in [-1, 1]:
									for sz in [-1, 1]:
										var pt = tf * Vector3(sx * h_size.x, sy * h_size.y, sz * h_size.z)
										min_x = minf(min_x, pt.x)
										max_x = maxf(max_x, pt.x)
										min_y = minf(min_y, pt.y)
										max_y = maxf(max_y, pt.y)
										min_z = minf(min_z, pt.z)
										max_z = maxf(max_z, pt.z)
				min_x = minf(min_x, pos.x)
				max_x = maxf(max_x, pos.x)
				min_y = minf(min_y, pos.y)
				max_y = maxf(max_y, pos.y)
				min_z = minf(min_z, pos.z)
				max_z = maxf(max_z, pos.z)

	if found_ceiling and found_floor and ceiling_y > floor_y:
		dims["height"] = ceiling_y - floor_y
	elif max_y > min_y and min_y != INF:
		dims["height"] = max_y - min_y

	if max_x > min_x and min_x != INF:
		dims["width"] = max_x - min_x

	if max_z > min_z and min_z != INF:
		dims["length"] = max_z - min_z

	return dims


func refresh_and_send_room_dimensions() -> void:
	if scene_manager and not scene_manager.are_scene_anchors_created():
		scene_manager.create_scene_anchors()

	if not scene_menu_viewport:
		return
	var ui = scene_menu_viewport.get_scene_root()
	if ui and ui.has_method("set_room_dimensions"):
		var dims = calculate_room_dimensions()
		ui.set_room_dimensions(dims)


func load_all_saved_scenes() -> void:
	saved_scenes = {}
	var file := FileAccess.open(SAVED_SCENES_FILE, FileAccess.READ)
	if file:
		var json := JSON.new()
		if json.parse(file.get_as_text()) == OK and json.data is Dictionary:
			var data: Dictionary = json.data
			if data.has("scenes") and data["scenes"] is Dictionary:
				saved_scenes = data["scenes"]
				active_scene_name = data.get("current_scene", "Default")
			else:
				saved_scenes = data
				active_scene_name = "Default"
		file.close()

	# Fallback to legacy single-file if no scenes saved yet
	if saved_scenes.is_empty():
		var legacy_file := FileAccess.open(LEGACY_SPATIAL_ANCHORS_FILE, FileAccess.READ)
		if legacy_file:
			var legacy_json := JSON.new()
			if legacy_json.parse(legacy_file.get_as_text()) == OK and legacy_json.data is Dictionary:
				saved_scenes["Default"] = {
					"anchors": legacy_json.data,
					"updated_at": Time.get_datetime_string_from_system()
				}
				active_scene_name = "Default"
			legacy_file.close()

	# Default empty layout if still empty
	if saved_scenes.is_empty():
		saved_scenes["Default"] = {
			"anchors": {},
			"updated_at": Time.get_datetime_string_from_system()
		}
		active_scene_name = "Default"

	if not saved_scenes.has(active_scene_name):
		active_scene_name = saved_scenes.keys()[0]

	_load_anchors_for_scene(active_scene_name)
	_write_scenes_to_disk()
	_update_scene_ui()


func _load_anchors_for_scene(scene_name: String) -> void:
	if not spatial_anchor_manager:
		return

	var scene_entry = saved_scenes.get(scene_name, {})
	var anchor_data: Dictionary = {}
	if scene_entry is Dictionary:
		if scene_entry.has("anchors") and scene_entry["anchors"] is Dictionary:
			anchor_data = scene_entry["anchors"]
		else:
			anchor_data = scene_entry

	if anchor_data.size() > 0:
		spatial_anchor_manager.load_anchors(anchor_data.keys(), anchor_data, OpenXRFbSpatialEntity.STORAGE_LOCAL, true)


func _write_scenes_to_disk() -> void:
	var file := FileAccess.open(SAVED_SCENES_FILE, FileAccess.WRITE)
	if not file:
		print("ERROR: Unable to open file for writing: ", SAVED_SCENES_FILE)
		return

	var root_data := {
		"current_scene": active_scene_name,
		"scenes": saved_scenes
	}
	file.store_string(JSON.stringify(root_data, "\t"))
	file.close()


func save_current_layout(scene_name: String) -> void:
	if not spatial_anchor_manager:
		return

	var anchor_data := {}
	for uuid in spatial_anchor_manager.get_anchor_uuids():
		var entity: OpenXRFbSpatialEntity = spatial_anchor_manager.get_spatial_entity(uuid)
		if entity:
			var custom_data = entity.custom_data
			var color_str = "#00FFFF"
			var label_str = ""
			if custom_data is Dictionary:
				color_str = custom_data.get("color", "#00FFFF")
				label_str = custom_data.get("label", "")

			var pos_arr := [0.0, 0.0, 0.0]
			var rot_arr := [0.0, 0.0, 0.0]
			for child in spatial_anchor_manager.get_children():
				if child is XRAnchor3D and (str(child.tracker) == str(uuid) or child.name == str(uuid)):
					pos_arr = [child.global_position.x, child.global_position.y, child.global_position.z]
					rot_arr = [child.global_rotation.x, child.global_rotation.y, child.global_rotation.z]
					break

			anchor_data[uuid] = {
				"color": color_str,
				"label": label_str,
				"pos": pos_arr,
				"rot": rot_arr
			}

	saved_scenes[scene_name] = {
		"anchors": anchor_data,
		"updated_at": Time.get_datetime_string_from_system()
	}
	active_scene_name = scene_name
	_write_scenes_to_disk()
	_update_scene_ui()


func switch_to_layout(scene_name: String) -> void:
	if not saved_scenes.has(scene_name):
		return

	_is_switching_layout = true
	clear_all_anchors(false)
	active_scene_name = scene_name
	_load_anchors_for_scene(scene_name)
	_is_switching_layout = false

	_write_scenes_to_disk()
	_update_scene_ui()


func delete_layout(scene_name: String) -> void:
	if saved_scenes.has(scene_name):
		saved_scenes.erase(scene_name)

	if active_scene_name == scene_name:
		if saved_scenes.is_empty():
			saved_scenes["Default"] = {
				"anchors": {},
				"updated_at": Time.get_datetime_string_from_system()
			}
			active_scene_name = "Default"
		else:
			active_scene_name = saved_scenes.keys()[0]
		switch_to_layout(active_scene_name)
	else:
		_write_scenes_to_disk()
		_update_scene_ui()


func clear_all_anchors(persist_to_active: bool = false) -> void:
	if not spatial_anchor_manager:
		return

	for child in spatial_anchor_manager.get_children():
		if child is XRAnchor3D:
			spatial_anchor_manager.untrack_anchor(child.tracker)

	if persist_to_active:
		save_current_layout(active_scene_name)
	else:
		_update_scene_ui()


func _update_scene_ui() -> void:
	var count: int = 0
	if spatial_anchor_manager:
		count = spatial_anchor_manager.get_anchor_uuids().size()

	if scene_menu_viewport:
		var ui = scene_menu_viewport.get_scene_root()
		if ui:
			if ui.has_method("set_scenes_data"):
				ui.set_scenes_data(saved_scenes, active_scene_name, count)
			if ui.has_method("set_room_dimensions"):
				ui.set_room_dimensions(calculate_room_dimensions())
			if ui.has_method("set_tape_measure_state"):
				ui.set_tape_measure_state(tape_measure_active, tape_measure_has_point_a)

	if wrist_menu:
		wrist_menu.set_layout_info(active_scene_name, count)
		wrist_menu.set_tape_active(tape_measure_active)
		wrist_menu.set_active_color(active_anchor_color)
		wrist_menu.set_dominant_hand(dominant_hand)
		wrist_menu.set_metrics_info(get_cumulative_measurement_distance(), use_imperial_units, placed_measurements.size())

	if mini_cad_viewer and mini_cad_viewer.visible:
		mini_cad_viewer.set_saved_scenes_data(saved_scenes, active_scene_name)
		mini_cad_viewer.rebuild_cad_model()


func toggle_scene_menu(enable = null) -> void:
	if not scene_menu_viewport:
		return

	if enable == null:
		enable = not scene_menu_viewport.visible

	scene_menu_viewport.visible = enable
	if enable:
		anchor_menu_to_hand()
		_update_scene_ui()


func anchor_menu_to_hand() -> void:
	if not scene_menu_viewport:
		return

	var is_right = (dominant_hand == "right")
	var target_hand: XRController3D = left_hand if is_right else right_hand
	if not target_hand:
		return

	if scene_menu_viewport.get_parent() != target_hand:
		scene_menu_viewport.get_parent().remove_child(scene_menu_viewport)
		target_hand.add_child(scene_menu_viewport)

	scene_menu_viewport.pixel_size = 0.0005

	var x_offset = 0.04 if is_right else -0.04
	var local_pos = Vector3(x_offset, 0.18, -0.12)
	var local_rot = Vector3(deg_to_rad(-40.0), 0.0, 0.0)
	scene_menu_viewport.transform = Transform3D(Basis.from_euler(local_rot), local_pos)


func toggle_cad_viewer(enable = null) -> void:
	if not mini_cad_viewer:
		return

	if enable == null:
		enable = not mini_cad_viewer.visible

	mini_cad_viewer.visible = enable
	if enable:
		position_cad_viewer_in_front_of_player()
		mini_cad_viewer.set_saved_scenes_data(saved_scenes, active_scene_name)
		mini_cad_viewer.rebuild_cad_model()


func position_cad_viewer_in_front_of_player() -> void:
	if not xr_camera or not mini_cad_viewer:
		return

	var cam_tf = xr_camera.global_transform
	var forward = -cam_tf.basis.z
	forward.y = 0.0
	if forward.is_zero_approx():
		forward = Vector3.FORWARD
	else:
		forward = forward.normalized()

	# Position 0.95m forward, 0.35m below eye level (tabletop height)
	var cad_pos = cam_tf.origin + forward * 0.95
	cad_pos.y = cam_tf.origin.y - 0.35
	mini_cad_viewer.global_position = cad_pos
	mini_cad_viewer.look_at(cam_tf.origin, Vector3.UP)
	mini_cad_viewer.rotate_y(PI)


func position_menu_in_front_of_player() -> void:
	if not xr_camera or not scene_menu_viewport:
		return

	var cam_tf = xr_camera.global_transform
	var forward = -cam_tf.basis.z
	forward.y = 0.0
	if forward.is_zero_approx():
		forward = Vector3.FORWARD
	else:
		forward = forward.normalized()

	var menu_pos = cam_tf.origin + forward * 1.2
	menu_pos.y = cam_tf.origin.y
	scene_menu_viewport.global_position = menu_pos
	scene_menu_viewport.look_at(cam_tf.origin, Vector3.UP)
	scene_menu_viewport.rotate_y(PI)


func _on_spatial_anchor_tracked(_anchor_node: XRAnchor3D, _spatial_entity: OpenXRFbSpatialEntity, is_new: bool) -> void:
	if is_new and not _is_switching_layout:
		save_current_layout(active_scene_name)
	_update_scene_ui()


func _on_spatial_anchor_untracked(_anchor_node: XRAnchor3D, _spatial_entity: OpenXRFbSpatialEntity) -> void:
	if not _is_switching_layout:
		save_current_layout(active_scene_name)
	_update_scene_ui()


func _on_openxr_fb_render_model_loaded(render_model: OpenXRFbRenderModel) -> void:
	for mesh_instance in render_model.find_children("*", "MeshInstance3D", true, false):
		for i in range(mesh_instance.mesh.get_surface_count()):
			var material: Material = mesh_instance.mesh.surface_get_material(i)
			# Make sure these render before the depth buffer is filled with environment depth info.
			material.render_priority = -100


func enable_passthrough(enable: bool) -> void:
	if passthrough_enabled == enable:
		return

	var supported_blend_modes = xr_interface.get_supported_environment_blend_modes()
	if XRInterface.XR_ENV_BLEND_MODE_ALPHA_BLEND in supported_blend_modes and XRInterface.XR_ENV_BLEND_MODE_OPAQUE in supported_blend_modes:
		if enable:
			# Switch to passthrough.
			xr_interface.environment_blend_mode = XRInterface.XR_ENV_BLEND_MODE_ALPHA_BLEND
			get_viewport().transparent_bg = true
			world_environment.environment.background_color = Color(0.0, 0.0, 0.0, 0.0)
		else:
			# Switch back to VR.
			xr_interface.environment_blend_mode = XRInterface.XR_ENV_BLEND_MODE_OPAQUE
			get_viewport().transparent_bg = false
			world_environment.environment.background_color = Color(0.3, 0.3, 0.3, 1.0)
		passthrough_enabled = enable


func display_scene_and_spatial_anchors(value: bool) -> void:
	if scene_and_spatial_anchors_displayed == value:
		return

	scene_manager.visible = value
	spatial_anchor_manager.visible = value
	scene_and_spatial_anchors_displayed = value

	var active_ptr = get_active_pointer()
	var active_rc = get_active_raycast()
	if active_ptr:
		active_ptr.visible = value
	if active_rc:
		active_rc.enabled = value


func _physics_process(_delta: float) -> void:
	var active_pointer = get_active_pointer()
	var active_raycast = get_active_raycast()
	var active_colliding_mesh = get_active_colliding_mesh()
	var active_pointer_mesh = get_active_pointer_mesh()
	var active_reticle_ring = get_active_reticle_ring()

	if not active_pointer or not active_pointer.visible:
		if active_reticle_ring:
			active_reticle_ring.visible = false
		return

	var previous_selected_spatial_anchor_node = selected_spatial_anchor_node
	var previous_hovered_line = hovered_measurement_line
	hovered_measurement_line = null

	# Check if pointing at floating UI menu, CAD controls, or wrist menu
	var pointing_at_menu := false
	if scene_menu_viewport and scene_menu_viewport.visible:
		var hit = scene_menu_viewport.intersects_ray(active_pointer.global_position, -active_pointer.global_transform.basis.z)
		if hit != Vector2(-1.0, -1.0):
			pointing_at_menu = true

	if not pointing_at_menu and mini_cad_viewer and mini_cad_viewer.visible and mini_cad_viewer.controls_panel:
		var hit = mini_cad_viewer.controls_panel.intersects_ray(active_pointer.global_position, -active_pointer.global_transform.basis.z)
		if hit != Vector2(-1.0, -1.0):
			pointing_at_menu = true

	if not pointing_at_menu and wrist_menu and wrist_menu.visible and wrist_menu.viewport_panel:
		var hit = wrist_menu.viewport_panel.intersects_ray(active_pointer.global_position, -active_pointer.global_transform.basis.z)
		if hit != Vector2(-1.0, -1.0):
			pointing_at_menu = true

	if pointing_at_menu:
		# Clear world anchor and line highlights and hide reticles
		selected_spatial_anchor_node = null
		if active_colliding_mesh:
			active_colliding_mesh.visible = false
		if active_reticle_ring:
			active_reticle_ring.visible = false
		if previous_selected_spatial_anchor_node:
			previous_selected_spatial_anchor_node.set_selected(false)
		if previous_hovered_line and is_instance_valid(previous_hovered_line) and previous_hovered_line.has_method("set_highlight"):
			previous_hovered_line.set_highlight(false)
		return

	# Update live tape measure preview if Point A is placed
	if tape_measure_active and tape_measure_has_point_a and tape_measure_preview_line:
		var current_aim_point := Vector3.ZERO
		if active_raycast and active_raycast.is_colliding():
			current_aim_point = active_raycast.get_collision_point()
		else:
			current_aim_point = active_pointer.global_position - active_pointer.global_transform.basis.z * 3.0
		tape_measure_preview_line.update_points(tape_measure_point_a, current_aim_point, use_imperial_units)

	if active_raycast and active_raycast.is_colliding():
		var collision_point: Vector3 = active_raycast.get_collision_point()
		var collision_normal: Vector3 = active_raycast.get_collision_normal()
		if active_colliding_mesh:
			active_colliding_mesh.global_position = collision_point

		if active_pointer_mesh and active_pointer_mesh.mesh:
			var pointer_length: float = (collision_point - active_pointer.global_position).length()
			active_pointer_mesh.mesh.size.z = pointer_length
			active_pointer_mesh.position.z = -pointer_length / 2.0

		# Surface-normal snapping reticle ring
		if active_reticle_ring:
			active_reticle_ring.visible = true
			var norm = collision_normal.normalized()
			var up = Vector3.FORWARD if absf(norm.dot(Vector3.UP)) > 0.99 else Vector3.UP
			var x_axis = norm.cross(up).normalized()
			var z_axis = x_axis.cross(norm).normalized()
			active_reticle_ring.global_transform = Transform3D(Basis(x_axis, norm, z_axis), collision_point + norm * 0.003)

		var collider: CollisionObject3D = active_raycast.get_collider()
		if collider:
			# Anchor hit detection (Layer 3)
			if collider.get_collision_layer_value(3):
				selected_spatial_anchor_node = collider
			else:
				selected_spatial_anchor_node = null

			# Measurement badge hover detection
			if collider.name == "BadgeArea" or (collider.get_parent() and collider.get_parent().has_method("set_highlight")):
				var line = collider.get_parent()
				if is_instance_valid(line) and line.has_method("set_highlight"):
					hovered_measurement_line = line
		else:
			selected_spatial_anchor_node = null
	else:
		if active_pointer_mesh and active_pointer_mesh.mesh:
			active_pointer_mesh.mesh.size.z = 5.0
			active_pointer_mesh.position.z = -2.5
		selected_spatial_anchor_node = null
		if active_reticle_ring:
			active_reticle_ring.visible = false

	if previous_selected_spatial_anchor_node != selected_spatial_anchor_node:
		if previous_selected_spatial_anchor_node:
			previous_selected_spatial_anchor_node.set_selected(false)
		if selected_spatial_anchor_node:
			selected_spatial_anchor_node.set_selected(true)
			if active_colliding_mesh:
				active_colliding_mesh.visible = false
		else:
			if active_colliding_mesh:
				active_colliding_mesh.visible = true

	if previous_hovered_line != hovered_measurement_line:
		if is_instance_valid(previous_hovered_line) and previous_hovered_line.has_method("set_highlight"):
			previous_hovered_line.set_highlight(false)
		if is_instance_valid(hovered_measurement_line) and hovered_measurement_line.has_method("set_highlight"):
			hovered_measurement_line.set_highlight(true)
			trigger_haptic(active_pointer, 80.0, 0.2, 0.02)


func _handle_pointer_trigger(active_pointer: XRController3D) -> void:
	var now = Time.get_ticks_msec()
	if now - _last_trigger_press_msec < 250:
		return
	_last_trigger_press_msec = now

	if not active_pointer or not active_pointer.visible:
		return

	var active_raycast = get_active_raycast()
	var active_fptr = get_active_function_pointer()

	# 1. Floating UI menu click
	if scene_menu_viewport and scene_menu_viewport.visible:
		var hit = scene_menu_viewport.intersects_ray(active_pointer.global_position, -active_pointer.global_transform.basis.z)
		if hit != Vector2(-1.0, -1.0):
			if active_fptr and active_fptr.has_method("_do_select"):
				active_fptr._do_select(true)
			trigger_haptic(active_pointer, 150.0, 0.25, 0.03)
			return

	# 2. Wrist HUD click
	if wrist_menu and wrist_menu.visible and wrist_menu.viewport_panel:
		var hit = wrist_menu.viewport_panel.intersects_ray(active_pointer.global_position, -active_pointer.global_transform.basis.z)
		if hit != Vector2(-1.0, -1.0):
			if active_fptr and active_fptr.has_method("_do_select"):
				active_fptr._do_select(true)
			trigger_haptic(active_pointer, 150.0, 0.25, 0.03)
			return

	# 3. CAD viewer controls bar click
	if mini_cad_viewer and mini_cad_viewer.visible and mini_cad_viewer.controls_panel:
		var hit = mini_cad_viewer.controls_panel.intersects_ray(active_pointer.global_position, -active_pointer.global_transform.basis.z)
		if hit != Vector2(-1.0, -1.0):
			if active_fptr and active_fptr.has_method("_do_select"):
				active_fptr._do_select(true)
			trigger_haptic(active_pointer, 150.0, 0.25, 0.03)
			return

	# 4. Mini CAD Viewer grab handle
	if active_raycast and active_raycast.is_colliding():
		var collider = active_raycast.get_collider()
		if mini_cad_viewer and mini_cad_viewer.visible and mini_cad_viewer.grab_handle_area and collider == mini_cad_viewer.grab_handle_area:
			mini_cad_viewer.start_grab(active_pointer)
			trigger_haptic(active_pointer, 100.0, 0.5, 0.06)
			return

	# 5. Measurement badge individual deletion
	if hovered_measurement_line and is_instance_valid(hovered_measurement_line):
		var line_to_delete = hovered_measurement_line
		hovered_measurement_line = null
		delete_measurement(line_to_delete)
		trigger_haptic(active_pointer, 140.0, 0.6, 0.08)
		return

	# 6. Tape measure placement
	if tape_measure_active:
		var hit_point := Vector3.ZERO
		if active_raycast and active_raycast.is_colliding():
			hit_point = active_raycast.get_collision_point()
		else:
			hit_point = active_pointer.global_position - active_pointer.global_transform.basis.z * 3.0

		if not tape_measure_has_point_a:
			tape_measure_point_a = hit_point
			tape_measure_has_point_a = true
			if not tape_measure_preview_line:
				tape_measure_preview_line = MEASUREMENT_LINE_SCENE.instantiate()
				add_child(tape_measure_preview_line)
			tape_measure_preview_line.visible = true
			tape_measure_preview_line.update_points(tape_measure_point_a, hit_point, use_imperial_units)
			_update_tape_ui_state()
			trigger_haptic(active_pointer, 120.0, 0.45, 0.05)
		else:
			var final_line = MEASUREMENT_LINE_SCENE.instantiate()
			add_child(final_line)
			final_line.update_points(tape_measure_point_a, hit_point, use_imperial_units)
			if final_line.has_signal("delete_requested"):
				final_line.delete_requested.connect(delete_measurement)
			placed_measurements.append(final_line)

			tape_measure_has_point_a = false
			if tape_measure_preview_line:
				tape_measure_preview_line.visible = false
			_update_tape_ui_state()
			_update_measurement_metrics()
			trigger_haptic(active_pointer, 160.0, 0.7, 0.08)
		return

	# 7. Spatial Anchor deletion or creation
	if active_raycast and active_raycast.is_colliding():
		if selected_spatial_anchor_node:
			var anchor_parent = selected_spatial_anchor_node.get_parent()
			if anchor_parent is XRAnchor3D:
				spatial_anchor_manager.untrack_anchor(anchor_parent.tracker)
				trigger_haptic(active_pointer, 100.0, 0.5, 0.06)
		else:
			var anchor_transform := Transform3D()
			anchor_transform.origin = active_raycast.get_collision_point()

			var collision_normal: Vector3 = active_raycast.get_collision_normal()
			if collision_normal.is_equal_approx(Vector3.UP):
				anchor_transform.basis = anchor_transform.basis.rotated(Vector3(1.0, 0.0, 0.0), PI / 2.0)
			elif collision_normal.is_equal_approx(Vector3.DOWN):
				anchor_transform.basis = anchor_transform.basis.rotated(Vector3(1.0, 0.0, 0.0), -PI / 2.0)
			else:
				anchor_transform.basis = Basis.looking_at(collision_normal)

			var custom_data = {
				"color": active_anchor_color.to_html(false),
				"label": active_anchor_label
			}
			spatial_anchor_manager.create_anchor(anchor_transform, custom_data)
			trigger_haptic(active_pointer, 120.0, 0.6, 0.07)


func _handle_pointer_release(active_pointer: XRController3D) -> void:
	if mini_cad_viewer and mini_cad_viewer.is_grabbed:
		mini_cad_viewer.end_grab()
		trigger_haptic(active_pointer, 80.0, 0.3, 0.04)
	var active_fptr = get_active_function_pointer()
	if active_fptr and active_fptr.has_method("_do_select"):
		active_fptr._do_select(false)


func _on_pointer_button_pressed(name: String, pointer: XRController3D) -> void:
	if pointer != get_active_pointer():
		return

	if name == "trigger_click" or name == "trigger":
		_handle_pointer_trigger(pointer)
	elif name == "ax_button":
		var target_hand: XRController3D = right_hand if dominant_hand == "right" else left_hand
		var anchor_transform: Transform3D = target_hand.transform
		var custom_data = {
			"color": active_anchor_color.to_html(false),
			"label": active_anchor_label
		}
		spatial_anchor_manager.create_anchor(anchor_transform, custom_data)
		trigger_haptic(target_hand, 140.0, 0.6, 0.07)
	elif name == "by_button":
		if dominant_hand == "right":
			global_environment_depth_enabled = not global_environment_depth_enabled
			environment_depth_node.visible = global_environment_depth_enabled
			depth_testing_mesh.set_surface_override_material(0, ENVIRONMENT_DEPTH_MATERIAL if global_environment_depth_enabled else BLUE_MATERIAL)
			trigger_haptic(right_hand, 110.0, 0.35, 0.04)
		else:
			enable_passthrough(not passthrough_enabled)
			trigger_haptic(left_hand, 110.0, 0.35, 0.04)
	elif name == "menu_button":
		toggle_scene_menu()


func _on_pointer_button_released(name: String, pointer: XRController3D) -> void:
	if pointer != get_active_pointer():
		return

	if name == "trigger_click" or name == "trigger":
		_handle_pointer_release(pointer)


func _on_left_hand_button_pressed(name: String) -> void:
	trigger_haptic(left_hand, 120.0, 0.3, 0.04)
	if name == "ax_button":
		display_scene_and_spatial_anchors(not scene_and_spatial_anchors_displayed)
	elif name == "by_button":
		enable_passthrough(not passthrough_enabled)
	elif name == "menu_button":
		toggle_scene_menu()


func _on_right_hand_controller_button_pressed(name: String) -> void:
	if dominant_hand == "left":
		trigger_haptic(right_hand, 120.0, 0.3, 0.04)
		if name == "ax_button":
			var anchor_transform: Transform3D = right_hand.transform
			var custom_data = {
				"color": active_anchor_color.to_html(false),
				"label": active_anchor_label
			}
			spatial_anchor_manager.create_anchor(anchor_transform, custom_data)
			trigger_haptic(right_hand, 140.0, 0.6, 0.07)
		elif name == "by_button":
			global_environment_depth_enabled = not global_environment_depth_enabled
			environment_depth_node.visible = global_environment_depth_enabled
			depth_testing_mesh.set_surface_override_material(0, ENVIRONMENT_DEPTH_MATERIAL if global_environment_depth_enabled else BLUE_MATERIAL)
			trigger_haptic(right_hand, 110.0, 0.35, 0.04)


# Backward compatibility wrappers
func _on_right_hand_button_pressed(name: String) -> void:
	_on_pointer_button_pressed(name, right_hand_pointer)


func _on_right_hand_button_released(name: String) -> void:
	_on_pointer_button_released(name, right_hand_pointer)


func _on_scene_manager_scene_capture_completed(success: bool) -> void:
	if success:
		# Recreate scene anchors since the user may have changed them.
		if scene_manager.are_scene_anchors_created():
			scene_manager.remove_scene_anchors()
		scene_manager.create_scene_anchors()
		refresh_and_send_room_dimensions()
		if mini_cad_viewer and mini_cad_viewer.visible:
			mini_cad_viewer.rebuild_cad_model()


func _on_scene_manager_scene_data_missing() -> void:
	scene_manager.request_scene_capture()
