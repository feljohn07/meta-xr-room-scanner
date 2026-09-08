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

@onready var left_hand: XRController3D = $XROrigin3D/LeftHand
@onready var right_hand: XRController3D = $XROrigin3D/RightHand
@onready var xr_camera: XRCamera3D = $XROrigin3D/XRCamera3D
@onready var right_hand_pointer: XRController3D = $XROrigin3D/RightHandPointer
@onready var right_hand_pointer_raycast: RayCast3D = $XROrigin3D/RightHandPointer/RayCast3D
@onready var scene_pointer_mesh: MeshInstance3D = $XROrigin3D/RightHandPointer/ScenePointerMesh
@onready var scene_colliding_mesh: MeshInstance3D = $XROrigin3D/RightHandPointer/SceneCollidingMesh
@onready var world_environment: WorldEnvironment = $WorldEnvironment
@onready var scene_manager: OpenXRFbSceneManager = $XROrigin3D/OpenXRFbSceneManager
@onready var spatial_anchor_manager: OpenXRFbSpatialAnchorManager = $XROrigin3D/OpenXRFbSpatialAnchorManager
# Don't statically type this as `OpenXRMetaEnvironmentDepth` because it doesn't exist on Godot 4.4.
@onready var environment_depth_node = $XROrigin3D/XRCamera3D/OpenXRMetaEnvironmentDepth
@onready var depth_testing_mesh: MeshInstance3D = $XROrigin3D/RightHand/DepthTestingMesh
@onready var scene_menu_viewport = %SceneMenuViewport
@onready var function_pointer = $XROrigin3D/RightHandPointer/FunctionPointer

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


func _ready() -> void:
	super._ready()
	if xr_interface and xr_interface.is_initialized():
		if not xr_interface.session_begun.is_connected(_on_openxr_session_begun):
			xr_interface.session_begun.connect(_on_openxr_session_begun)

	for render_model in [%LeftControllerFbRenderModel, %RightControllerFbRenderModel]:
		render_model.openxr_fb_render_model_loaded.connect(_on_openxr_fb_render_model_loaded.bind(render_model))

	if scene_manager and not scene_manager.child_entered_tree.is_connected(_on_scene_anchor_child_entered):
		scene_manager.child_entered_tree.connect(_on_scene_anchor_child_entered)

	if right_hand and not right_hand.button_released.is_connected(_on_right_hand_button_released):
		right_hand.button_released.connect(_on_right_hand_button_released)
	if right_hand_pointer:
		if not right_hand_pointer.button_released.is_connected(_on_right_hand_button_released):
			right_hand_pointer.button_released.connect(_on_right_hand_button_released)
		if not right_hand_pointer.button_pressed.is_connected(_on_right_hand_button_pressed):
			right_hand_pointer.button_pressed.connect(_on_right_hand_button_pressed)

	_setup_scene_menu()


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


func clear_tape_measurements() -> void:
	for line in placed_measurements:
		if is_instance_valid(line):
			line.queue_free()
	placed_measurements.clear()
	tape_measure_has_point_a = false
	if tape_measure_preview_line:
		tape_measure_preview_line.visible = false
	_update_tape_ui_state()


func _update_tape_ui_state() -> void:
	if not scene_menu_viewport:
		return
	var ui = scene_menu_viewport.get_scene_root()
	if ui and ui.has_method("set_tape_measure_state"):
		ui.set_tape_measure_state(tape_measure_active, tape_measure_has_point_a)


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
			anchor_data[uuid] = entity.custom_data

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
	if not scene_menu_viewport:
		return
	var ui = scene_menu_viewport.get_scene_root()
	if ui:
		if ui.has_method("set_scenes_data"):
			var count: int = 0
			if spatial_anchor_manager:
				count = spatial_anchor_manager.get_anchor_uuids().size()
			ui.set_scenes_data(saved_scenes, active_scene_name, count)
		if ui.has_method("set_room_dimensions"):
			ui.set_room_dimensions(calculate_room_dimensions())
		if ui.has_method("set_tape_measure_state"):
			ui.set_tape_measure_state(tape_measure_active, tape_measure_has_point_a)


func toggle_scene_menu(enable = null) -> void:
	if not scene_menu_viewport:
		return

	if enable == null:
		enable = not scene_menu_viewport.visible

	scene_menu_viewport.visible = enable
	if enable:
		position_menu_in_front_of_player()
		_update_scene_ui()


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
	right_hand_pointer.visible = value
	right_hand_pointer_raycast.enabled = value

	scene_and_spatial_anchors_displayed = value


func _physics_process(_delta: float) -> void:
	if right_hand_pointer.visible:
		var previous_selected_spatial_anchor_node = selected_spatial_anchor_node

		# Check if pointing at floating UI menu
		var pointing_at_menu := false
		if scene_menu_viewport and scene_menu_viewport.visible:
			var hit = scene_menu_viewport.intersects_ray(right_hand_pointer.global_position, -right_hand_pointer.global_transform.basis.z)
			if hit != Vector2(-1.0, -1.0):
				pointing_at_menu = true

		if pointing_at_menu:
			# When aiming at menu, clear world anchor highlights and hide world colliding dot
			selected_spatial_anchor_node = null
			scene_colliding_mesh.visible = false
			if previous_selected_spatial_anchor_node:
				previous_selected_spatial_anchor_node.set_selected(false)
			return

		# Update live tape measure preview if Point A is placed
		if tape_measure_active and tape_measure_has_point_a and tape_measure_preview_line:
			var current_aim_point := Vector3.ZERO
			if right_hand_pointer_raycast.is_colliding():
				current_aim_point = right_hand_pointer_raycast.get_collision_point()
			else:
				current_aim_point = right_hand_pointer.global_position - right_hand_pointer.global_transform.basis.z * 3.0
			tape_measure_preview_line.update_points(tape_measure_point_a, current_aim_point, use_imperial_units)

		if right_hand_pointer_raycast.is_colliding():
			var collision_point: Vector3 = right_hand_pointer_raycast.get_collision_point()
			scene_colliding_mesh.global_position = collision_point

			var pointer_length: float = (collision_point - right_hand_pointer.global_position).length()
			scene_pointer_mesh.mesh.size.z = pointer_length
			scene_pointer_mesh.position.z = -pointer_length / 2.0

			var collider: CollisionObject3D = right_hand_pointer_raycast.get_collider()
			if collider and collider.get_collision_layer_value(3):
				selected_spatial_anchor_node = collider
			else:
				selected_spatial_anchor_node = null
		else:
			scene_pointer_mesh.mesh.size.z = 5
			scene_pointer_mesh.position.z = -2.5
			selected_spatial_anchor_node = null

		if previous_selected_spatial_anchor_node != selected_spatial_anchor_node:
			if previous_selected_spatial_anchor_node:
				previous_selected_spatial_anchor_node.set_selected(false)
			if selected_spatial_anchor_node:
				selected_spatial_anchor_node.set_selected(true)
				scene_colliding_mesh.visible = false
			else:
				scene_colliding_mesh.visible = true


func _on_left_hand_button_pressed(name: String) -> void:
	if name == "ax_button":
		display_scene_and_spatial_anchors(not scene_and_spatial_anchors_displayed)
	elif name == "by_button":
		enable_passthrough(not passthrough_enabled)
	elif name == "menu_button":
		toggle_scene_menu()


func _on_right_hand_button_pressed(name: String) -> void:
	if name == "trigger_click" or name == "trigger":
		var now = Time.get_ticks_msec()
		if now - _last_trigger_press_msec < 250:
			return
		_last_trigger_press_msec = now

		if not right_hand_pointer or not right_hand_pointer.visible:
			return

		# If user is pointing at the in-world floating UI menu, forward click to UI and avoid world anchors
		if scene_menu_viewport and scene_menu_viewport.visible:
			var hit = scene_menu_viewport.intersects_ray(right_hand_pointer.global_position, -right_hand_pointer.global_transform.basis.z)
			if hit != Vector2(-1.0, -1.0):
				if function_pointer and function_pointer.has_method("_do_select"):
					function_pointer._do_select(true)
				return

		# If tape measure mode is active, handle Point A and Point B placement
		if tape_measure_active:
			var hit_point := Vector3.ZERO
			if right_hand_pointer_raycast.is_colliding():
				hit_point = right_hand_pointer_raycast.get_collision_point()
			else:
				hit_point = right_hand_pointer.global_position - right_hand_pointer.global_transform.basis.z * 3.0

			if not tape_measure_has_point_a:
				tape_measure_point_a = hit_point
				tape_measure_has_point_a = true
				if not tape_measure_preview_line:
					tape_measure_preview_line = MEASUREMENT_LINE_SCENE.instantiate()
					add_child(tape_measure_preview_line)
				tape_measure_preview_line.visible = true
				tape_measure_preview_line.update_points(tape_measure_point_a, hit_point, use_imperial_units)
				_update_tape_ui_state()
			else:
				# Complete Point B and pin measurement in world
				var final_line = MEASUREMENT_LINE_SCENE.instantiate()
				add_child(final_line)
				final_line.update_points(tape_measure_point_a, hit_point, use_imperial_units)
				placed_measurements.append(final_line)

				tape_measure_has_point_a = false
				if tape_measure_preview_line:
					tape_measure_preview_line.visible = false
				_update_tape_ui_state()
			return

		if right_hand_pointer_raycast.is_colliding():
			if selected_spatial_anchor_node:
				var anchor_parent = selected_spatial_anchor_node.get_parent()
				if anchor_parent is XRAnchor3D:
					spatial_anchor_manager.untrack_anchor(anchor_parent.tracker)
			else:
				var anchor_transform := Transform3D()
				anchor_transform.origin = right_hand_pointer_raycast.get_collision_point()

				var collision_normal: Vector3 = right_hand_pointer_raycast.get_collision_normal()
				if collision_normal.is_equal_approx(Vector3.UP):
					anchor_transform.basis = anchor_transform.basis.rotated(Vector3(1.0, 0.0, 0.0), PI / 2.0)
				elif collision_normal.is_equal_approx(Vector3.DOWN):
					anchor_transform.basis = anchor_transform.basis.rotated(Vector3(1.0, 0.0, 0.0), -PI / 2.0)
				else:
					anchor_transform.basis = Basis.looking_at(right_hand_pointer_raycast.get_collision_normal())

				spatial_anchor_manager.create_anchor(anchor_transform, {color = COLORS[randi() % COLORS.size()]})
	elif name == "ax_button":
		var anchor_transform := right_hand.transform
		spatial_anchor_manager.create_anchor(anchor_transform, {color = COLORS[randi() % COLORS.size()]})
	elif name == "by_button":
		global_environment_depth_enabled = not global_environment_depth_enabled

		environment_depth_node.visible = global_environment_depth_enabled
		depth_testing_mesh.set_surface_override_material(0, BLUE_MATERIAL if global_environment_depth_enabled else ENVIRONMENT_DEPTH_MATERIAL)


func _on_right_hand_button_released(name: String) -> void:
	if name == "trigger_click" or name == "trigger":
		if function_pointer and function_pointer.has_method("_do_select"):
			function_pointer._do_select(false)


func _on_scene_manager_scene_capture_completed(success: bool) -> void:
	if success:
		# Recreate scene anchors since the user may have changed them.
		if scene_manager.are_scene_anchors_created():
			scene_manager.remove_scene_anchors()
		scene_manager.create_scene_anchors()
		refresh_and_send_room_dimensions()


func _on_scene_manager_scene_data_missing() -> void:
	scene_manager.request_scene_capture()
