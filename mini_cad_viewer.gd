class_name MiniCADViewer
extends Node3D

signal closed()
signal scale_changed(new_scale: float)
signal view_mode_changed(mode_name: String)

const CAD_SURFACE_SHADER = preload("res://assets/cad_blueprint_surface.gdshader")
const CAD_GRID_SHADER = preload("res://assets/cad_blueprint_grid.gdshader")

# Architectural Scale Presets: [Ratio label, float multiplier]
const SCALE_PRESETS = [
	{"label": "1:10", "scale": 0.10},
	{"label": "1:20", "scale": 0.05},
	{"label": "1:25", "scale": 0.04},
	{"label": "1:50", "scale": 0.02},
	{"label": "1:100", "scale": 0.01}
]

var current_preset_idx: int = 2 # Default 1:25 (0.04x)
var current_scale: float = 0.04
var is_turntable_active: bool = false
var turntable_speed: float = 0.6

# Grabbing / Movement
var is_grabbed: bool = false
var grabbing_controller: Node3D = null
var grab_local_transform: Transform3D = Transform3D()

# References to world managers
var scene_manager: OpenXRFbSceneManager = null
var spatial_anchor_manager: OpenXRFbSpatialAnchorManager = null
var saved_scenes_cache: Dictionary = {}
var active_scene_name: String = "Default"

# Node references
@onready var baseplate_mesh: MeshInstance3D = $Baseplate
@onready var model_rotator: Node3D = $ModelRotator
@onready var content_pivot: Node3D = $ModelRotator/ContentPivot
@onready var room_surfaces_container: Node3D = $ModelRotator/ContentPivot/RoomSurfaces
@onready var anchors_container: Node3D = $ModelRotator/ContentPivot/Anchors
@onready var grab_handle_area: Area3D = $GrabHandle/Area3D
@onready var info_label: Label3D = $InfoLabel
@onready var title_label: Label3D = $TitleLabel
@onready var controls_panel: Node3D = $ControlsBar


func _ready() -> void:
	_setup_baseplate()
	_setup_controls()
	_update_info_display()


func _setup_controls() -> void:
	if not controls_panel:
		return
	var ui = controls_panel.get_scene_root() if controls_panel.has_method("get_scene_root") else null
	if not ui:
		await get_tree().process_frame
		if controls_panel and controls_panel.has_method("get_scene_root"):
			ui = controls_panel.get_scene_root()

	if ui:
		if ui.has_signal("scale_down_requested") and not ui.scale_down_requested.is_connected(_on_ctrl_scale_down):
			ui.scale_down_requested.connect(_on_ctrl_scale_down)
		if ui.has_signal("scale_up_requested") and not ui.scale_up_requested.is_connected(_on_ctrl_scale_up):
			ui.scale_up_requested.connect(_on_ctrl_scale_up)
		if ui.has_signal("view_iso_requested") and not ui.view_iso_requested.is_connected(_on_ctrl_view_iso):
			ui.view_iso_requested.connect(_on_ctrl_view_iso)
		if ui.has_signal("view_topdown_requested") and not ui.view_topdown_requested.is_connected(_on_ctrl_view_topdown):
			ui.view_topdown_requested.connect(_on_ctrl_view_topdown)
		if ui.has_signal("turntable_toggle_requested") and not ui.turntable_toggle_requested.is_connected(_on_ctrl_turntable):
			ui.turntable_toggle_requested.connect(_on_ctrl_turntable)
		if ui.has_signal("refresh_requested") and not ui.refresh_requested.is_connected(rebuild_cad_model):
			ui.refresh_requested.connect(rebuild_cad_model)
		if ui.has_signal("close_requested") and not ui.close_requested.is_connected(_on_ctrl_close):
			ui.close_requested.connect(_on_ctrl_close)


func _on_ctrl_scale_down() -> void:
	cycle_scale(-1)


func _on_ctrl_scale_up() -> void:
	cycle_scale(1)


func _on_ctrl_view_iso() -> void:
	set_view_mode("isometric")


func _on_ctrl_view_topdown() -> void:
	set_view_mode("top_down")


func _on_ctrl_turntable() -> void:
	is_turntable_active = not is_turntable_active
	view_mode_changed.emit("turntable" if is_turntable_active else "paused")


func _on_ctrl_close() -> void:
	visible = false
	closed.emit()


func _setup_baseplate() -> void:
	if baseplate_mesh:
		var mat = ShaderMaterial.new()
		mat.shader = CAD_GRID_SHADER
		baseplate_mesh.set_surface_override_material(0, mat)


func initialize_managers(p_scene_mgr: OpenXRFbSceneManager, p_anchor_mgr: OpenXRFbSpatialAnchorManager) -> void:
	scene_manager = p_scene_mgr
	spatial_anchor_manager = p_anchor_mgr
	rebuild_cad_model()


func set_saved_scenes_data(scenes_dict: Dictionary, current_active: String) -> void:
	saved_scenes_cache = scenes_dict
	active_scene_name = current_active
	_update_info_display()


func _process(delta: float) -> void:
	if is_turntable_active and model_rotator:
		model_rotator.rotate_y(turntable_speed * delta)

	if is_grabbed and is_instance_valid(grabbing_controller):
		global_transform = grabbing_controller.global_transform * grab_local_transform


## Grab and drag repositioning
func start_grab(controller: Node3D) -> void:
	if not controller:
		return
	is_grabbed = true
	grabbing_controller = controller
	grab_local_transform = controller.global_transform.affine_inverse() * global_transform


func end_grab() -> void:
	is_grabbed = false
	grabbing_controller = null


## Geometry Rebuilding
func rebuild_cad_model(preview_scene_name: String = "") -> void:
	if not is_inside_tree():
		return

	# Clear previous mini meshes
	for child in room_surfaces_container.get_children():
		child.queue_free()
	for child in anchors_container.get_children():
		child.queue_free()

	var target_scene = preview_scene_name if not preview_scene_name.is_empty() else active_scene_name

	# Calculate room bounding center to normalize miniature to center of grid
	var bounds_center := Vector3.ZERO
	var room_extents := Vector3.ONE
	var children_count: int = 0

	if scene_manager:
		var children = scene_manager.get_children()
		var min_pt = Vector3(INF, INF, INF)
		var max_pt = Vector3(-INF, -INF, -INF)
		var found_any = false

		for c in children:
			if c is Node3D:
				var pos = c.global_position
				min_pt.x = minf(min_pt.x, pos.x)
				min_pt.y = minf(min_pt.y, pos.y)
				min_pt.z = minf(min_pt.z, pos.z)
				max_pt.x = maxf(max_pt.x, pos.x)
				max_pt.y = maxf(max_pt.y, pos.y)
				max_pt.z = maxf(max_pt.z, pos.z)
				found_any = true

		if found_any and min_pt.x != INF:
			bounds_center = (min_pt + max_pt) * 0.5
			room_extents = max_pt - min_pt
			# Keep mini base on the grid floor
			bounds_center.y = min_pt.y

	# Populate mini surfaces
	if scene_manager:
		for c in scene_manager.get_children():
			if not (c is Node3D):
				continue
			children_count += 1

			# Determine semantic category
			var lbl_node = c.get_node_or_null("Label3D")
			var lbl_text = lbl_node.text.to_lower() if lbl_node else ""

			# Search for meshes in this surface anchor
			var meshes = c.find_children("*", "MeshInstance3D", true, false)
			for m in meshes:
				if m is MeshInstance3D and m.mesh:
					var mini_mesh = MeshInstance3D.new()
					mini_mesh.mesh = m.mesh
					
					# Transform relative to normalized room center
					var rel_transform = m.global_transform
					rel_transform.origin -= bounds_center
					mini_mesh.transform = rel_transform

					# Apply CAD Blueprint Shader
					var cad_mat = ShaderMaterial.new()
					cad_mat.shader = CAD_SURFACE_SHADER
					var color_info = _get_cad_color_for_label(lbl_text)
					cad_mat.set_shader_parameter("albedo_color", color_info["albedo"])
					cad_mat.set_shader_parameter("edge_color", color_info["edge"])
					cad_mat.set_shader_parameter("fresnel_power", 2.2)
					cad_mat.set_shader_parameter("edge_intensity", 2.0)
					mini_mesh.material_override = cad_mat

					room_surfaces_container.add_child(mini_mesh)

	# Populate mini spatial anchors
	var anchor_count: int = 0
	if not preview_scene_name.is_empty() and saved_scenes_cache.has(preview_scene_name):
		# Reconstruct anchors from saved scene json
		var scene_info = saved_scenes_cache[preview_scene_name]
		var anchors_dict = scene_info.get("anchors", {})
		for uuid in anchors_dict:
			anchor_count += 1
			var data = anchors_dict[uuid]
			var col = Color(data.get("color", "#00FFFF"))
			_spawn_mini_anchor(Vector3.ZERO, col, uuid)
	elif spatial_anchor_manager:
		# Use live world anchors
		for c in spatial_anchor_manager.get_children():
			if c is XRAnchor3D:
				anchor_count += 1
				var rel_pos = c.global_position - bounds_center
				var col = Color(0, 1, 1)
				var anchor_script_node = c.get_node_or_null("SpatialAnchor")
				if anchor_script_node and "color" in anchor_script_node:
					col = anchor_script_node.color
				_spawn_mini_anchor(rel_pos, col, c.name)

	# Apply current scale
	content_pivot.scale = Vector3(current_scale, current_scale, current_scale)
	_update_info_display(target_scene, children_count, anchor_count, room_extents)


func _spawn_mini_anchor(rel_pos: Vector3, col: Color, anchor_name: String) -> void:
	var anchor_node = Node3D.new()
	anchor_node.position = rel_pos

	var cube = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = Vector3(0.12, 0.12, 0.12)
	cube.mesh = box

	var mat = StandardMaterial3D.new()
	mat.albedo_color = col
	mat.emission_enabled = true
	mat.emission = col
	mat.emission_energy_multiplier = 2.0
	cube.material_override = mat
	anchor_node.add_child(cube)

	var pin_stem = MeshInstance3D.new()
	var cyl = CylinderMesh.new()
	cyl.top_radius = 0.01
	cyl.bottom_radius = 0.01
	cyl.height = 0.15
	pin_stem.mesh = cyl
	pin_stem.position = Vector3(0, -0.075, 0)
	pin_stem.material_override = mat
	anchor_node.add_child(pin_stem)

	anchors_container.add_child(anchor_node)


func _get_cad_color_for_label(semantic_text: String) -> Dictionary:
	if "floor" in semantic_text:
		return {
			"albedo": Color(0.03, 0.12, 0.22, 0.6),
			"edge": Color(0.1, 0.6, 0.9, 0.9)
		}
	elif "ceiling" in semantic_text:
		return {
			"albedo": Color(0.04, 0.08, 0.15, 0.3),
			"edge": Color(0.3, 0.5, 0.7, 0.6)
		}
	elif "wall" in semantic_text:
		return {
			"albedo": Color(0.05, 0.25, 0.5, 0.75),
			"edge": Color(0.0, 0.95, 1.0, 1.0)
		}
	elif "door" in semantic_text or "window" in semantic_text:
		return {
			"albedo": Color(0.4, 0.1, 0.1, 0.7),
			"edge": Color(1.0, 0.3, 0.3, 1.0)
		}
	elif "table" in semantic_text or "desk" in semantic_text or "couch" in semantic_text:
		return {
			"albedo": Color(0.05, 0.35, 0.2, 0.8),
			"edge": Color(0.2, 1.0, 0.5, 1.0)
		}
	return {
		"albedo": Color(0.1, 0.2, 0.35, 0.7),
		"edge": Color(0.4, 0.8, 1.0, 0.9)
	}


## Scaling & Resizing
func set_scale_ratio(new_ratio: float) -> void:
	current_scale = clampf(new_ratio, 0.005, 0.25)
	if content_pivot:
		var tween = create_tween()
		tween.tween_property(content_pivot, "scale", Vector3.ONE * current_scale, 0.15).set_trans(Tween.TRANS_QUAD)
	_update_info_display()
	scale_changed.emit(current_scale)


func cycle_scale(direction: int = 1) -> void:
	current_preset_idx = (current_preset_idx + direction) % SCALE_PRESETS.size()
	if current_preset_idx < 0:
		current_preset_idx = SCALE_PRESETS.size() - 1
	var preset = SCALE_PRESETS[current_preset_idx]
	set_scale_ratio(preset["scale"])


## View Orientations
func set_view_mode(mode: String) -> void:
	is_turntable_active = false
	if not model_rotator:
		return

	var tween = create_tween().set_parallel(true)
	match mode:
		"top_down":
			# 2D Floorplan CAD plan view (looking straight down)
			tween.tween_property(model_rotator, "rotation_degrees", Vector3(90, 0, 0), 0.3).set_trans(Tween.TRANS_QUAD)
		"isometric":
			# Classic 3D architectural axonometric / isometric CAD view
			tween.tween_property(model_rotator, "rotation_degrees", Vector3(32, -45, 0), 0.3).set_trans(Tween.TRANS_QUAD)
		"front":
			# Front elevation view
			tween.tween_property(model_rotator, "rotation_degrees", Vector3(0, 0, 0), 0.3).set_trans(Tween.TRANS_QUAD)
		"turntable":
			is_turntable_active = true
	view_mode_changed.emit(mode)


func _update_info_display(scene_name: String = "", surface_cnt: int = -1, anchor_cnt: int = -1, extents: Vector3 = Vector3.ZERO) -> void:
	var active_name = scene_name if not scene_name.is_empty() else active_scene_name
	var preset_label = SCALE_PRESETS[current_preset_idx]["label"]

	if title_label:
		title_label.text = "CAD Blueprint: %s" % active_name

	if info_label:
		var info_text = "Scale: %s (%.1f%%)\n" % [preset_label, current_scale * 100.0]
		if extents != Vector3.ZERO:
			info_text += "Real Size: %.2fm W × %.2fm L × %.2fm H\n" % [extents.x, extents.z, extents.y]
		if surface_cnt >= 0:
			info_text += "Surfaces: %d | Anchors: %d" % [surface_cnt, anchor_cnt]
		info_label.text = info_text
