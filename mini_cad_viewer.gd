class_name MiniCADViewer
extends Node3D

signal closed()
signal scale_changed(new_scale: float)
signal view_mode_changed(mode_name: String)

const CAD_SURFACE_SHADER = preload("res://assets/cad_blueprint_surface.gdshader")
const CAD_GRID_SHADER = preload("res://assets/cad_blueprint_grid.gdshader")
const DOLLHOUSE_FROSTED_SHADER = preload("res://assets/dollhouse_frosted.gdshader")

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

# Mode: true = Floating Meta-style Dollhouse Diorama, false = Engineering CAD blueprint grid
var dollhouse_mode: bool = true

# Grabbing / Movement
var is_grabbed: bool = false
var grabbing_controller: Node3D = null
var grab_local_transform: Transform3D = Transform3D()

# References to world managers & XR camera
var scene_manager: OpenXRFbSceneManager = null
var spatial_anchor_manager: OpenXRFbSpatialAnchorManager = null
var xr_camera: XRCamera3D = null
var saved_scenes_cache: Dictionary = {}
var active_scene_name: String = "Default"

# Computed room bounds
var bounds_center: Vector3 = Vector3.ZERO
var room_floor_y: float = 0.0

# Node references
@onready var baseplate_mesh: MeshInstance3D = $Baseplate
@onready var model_rotator: Node3D = $ModelRotator
@onready var content_pivot: Node3D = $ModelRotator/ContentPivot
@onready var room_surfaces_container: Node3D = $ModelRotator/ContentPivot/RoomSurfaces
@onready var anchors_container: Node3D = $ModelRotator/ContentPivot/Anchors
@onready var grab_handle_area: Area3D = $GrabHandle/Area3D
@onready var handle_mesh: MeshInstance3D = get_node_or_null("GrabHandle/HandleMesh")
@onready var handle_label: Label3D = get_node_or_null("GrabHandle/HandleLabel")
@onready var info_label: Label3D = $InfoLabel
@onready var title_label: Label3D = $TitleLabel
@onready var controls_panel: Node3D = $ControlsBar

# Dollhouse subcontainers
var dollhouse_walls_container: Node3D = null
var dollhouse_furniture_container: Node3D = null
var player_pin: Node3D = null


func _ready() -> void:
	_init_dollhouse_containers()
	_setup_baseplate()
	_setup_controls()
	_apply_mode_visibility()
	_update_info_display()


func _init_dollhouse_containers() -> void:
	if not content_pivot:
		return

	dollhouse_walls_container = Node3D.new()
	dollhouse_walls_container.name = "DollhouseWalls"
	content_pivot.add_child(dollhouse_walls_container)

	dollhouse_furniture_container = Node3D.new()
	dollhouse_furniture_container.name = "DollhouseFurniture"
	content_pivot.add_child(dollhouse_furniture_container)

	player_pin = _create_player_pin()
	content_pivot.add_child(player_pin)


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


func _apply_mode_visibility() -> void:
	# In Dollhouse mode, hide the heavy CAD grid, engineering controls bar, and text headers
	# to keep the miniature floating room clean and minimalist like Meta Quest's review screen.
	var cad_visible = not dollhouse_mode

	if baseplate_mesh:
		baseplate_mesh.visible = cad_visible
	if controls_panel:
		controls_panel.visible = cad_visible
	if title_label:
		title_label.visible = cad_visible
	if info_label:
		info_label.visible = cad_visible
	if handle_label:
		handle_label.visible = cad_visible
	if handle_mesh:
		handle_mesh.visible = cad_visible


func set_dollhouse_mode(enabled: bool) -> void:
	dollhouse_mode = enabled
	_apply_mode_visibility()
	rebuild_cad_model()


func set_camera(cam: XRCamera3D) -> void:
	xr_camera = cam


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

	_update_player_pin()


func _update_player_pin() -> void:
	if not player_pin or not is_instance_valid(player_pin):
		return
	if not xr_camera or not is_instance_valid(xr_camera):
		player_pin.visible = false
		return

	player_pin.visible = true
	var cam_pos = xr_camera.global_position

	# Map headset world coordinates into miniature local space inside ContentPivot
	var rel_x = cam_pos.x - bounds_center.x
	var rel_z = cam_pos.z - bounds_center.z

	player_pin.position = Vector3(rel_x, 0.0, rel_z)

	# Rotate pin to match headset yaw orientation
	var cam_yaw = xr_camera.global_rotation.y
	var base_rot = model_rotator.global_rotation.y if model_rotator else 0.0
	player_pin.rotation.y = cam_yaw - base_rot


## Geometry Rebuilding
func rebuild_cad_model(preview_scene_name: String = "") -> void:
	if not is_inside_tree():
		return

	_clear_containers()

	var target_scene = preview_scene_name if not preview_scene_name.is_empty() else active_scene_name

	if dollhouse_mode and scene_manager:
		_build_dollhouse_geometry(target_scene)
	else:
		_build_fallback_cad_geometry(target_scene)

	# Apply scale preset
	content_pivot.scale = Vector3(current_scale, current_scale, current_scale)


func _clear_containers() -> void:
	if dollhouse_walls_container:
		for c in dollhouse_walls_container.get_children():
			c.queue_free()
	if dollhouse_furniture_container:
		for c in dollhouse_furniture_container.get_children():
			c.queue_free()
	if room_surfaces_container:
		for c in room_surfaces_container.get_children():
			c.queue_free()
	if anchors_container:
		for c in anchors_container.get_children():
			c.queue_free()


## Builds the clean extruded cutaway dollhouse matching Meta Quest's review screen
func _build_dollhouse_geometry(target_scene: String) -> void:
	var layout = RoomDataManager.get_parametric_room_layout(scene_manager)
	var obb = layout.get("obb", {})

	if not obb.get("valid", false):
		_build_fallback_cad_geometry(target_scene)
		return

	bounds_center = obb["center"]
	room_floor_y = obb["floor_elevation"]
	bounds_center.y = room_floor_y # Align mini floor plane to Y=0 locally

	var corners: Array = obb.get("corners", [])
	var wall_height: float = obb.get("height", 2.5)
	var cutaway_height: float = wall_height * 0.85 # Cutaway ceiling so user looks down inside

	# 1. Procedural Extruded Walls (4 clean planar boxes connecting corners)
	if corners.size() == 4 and dollhouse_walls_container:
		var frosted_mat = ShaderMaterial.new()
		frosted_mat.shader = DOLLHOUSE_FROSTED_SHADER
		frosted_mat.set_shader_parameter("albedo_color", Color(0.92, 0.95, 1.0, 0.32))
		frosted_mat.set_shader_parameter("edge_color", Color(1.0, 1.0, 1.0, 0.95))
		frosted_mat.set_shader_parameter("fresnel_power", 2.0)
		frosted_mat.set_shader_parameter("edge_intensity", 2.2)

		var wall_thickness = 0.08

		for i in range(4):
			var p1 = corners[i] - bounds_center
			var p2 = corners[(i + 1) % 4] - bounds_center
			p1.y = 0.0
			p2.y = 0.0

			var seg_vec = p2 - p1
			var seg_len = seg_vec.length()
			if seg_len <= 0.01:
				continue

			var wall_box = MeshInstance3D.new()
			var bmesh = BoxMesh.new()
			bmesh.size = Vector3(wall_thickness, cutaway_height, seg_len)
			wall_box.mesh = bmesh
			wall_box.material_override = frosted_mat

			var mid_point = (p1 + p2) * 0.5
			mid_point.y = cutaway_height * 0.5
			wall_box.position = mid_point

			# Align wall box along segment vector
			var angle_y = atan2(seg_vec.x, seg_vec.z)
			wall_box.rotation.y = angle_y

			# Add clean white wireframe outline along wall top/bottom
			var wall_wire = _create_wireframe_box(bmesh.size, Color(1.0, 1.0, 1.0, 0.85))
			wall_box.add_child(wall_wire)

			dollhouse_walls_container.add_child(wall_box)

		# 2. Floor Plane
		var floor_mesh = MeshInstance3D.new()
		var plane = BoxMesh.new()
		plane.size = Vector3(obb.get("width", 3.0), 0.01, obb.get("length", 3.0))
		floor_mesh.mesh = plane
		floor_mesh.position = Vector3(0, -0.005, 0)
		floor_mesh.rotation.y = obb.get("yaw", 0.0)

		var floor_mat = StandardMaterial3D.new()
		floor_mat.albedo_color = Color(0.9, 0.94, 1.0, 0.18)
		floor_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		floor_mesh.material_override = floor_mat
		dollhouse_walls_container.add_child(floor_mesh)

	# 3. Furniture Proxy Bounding Volumes
	var furniture_list: Array = layout.get("furniture", [])
	if dollhouse_furniture_container:
		for item in furniture_list:
			var dims: Vector3 = item.get("dimensions", Vector3(0.8, 0.8, 0.8))
			var pos: Vector3 = item.get("position", Vector3.ZERO) - bounds_center
			var rot: Vector3 = item.get("rotation", Vector3.ZERO)
			var lbl: String = item.get("label", "")

			var furn_mesh = MeshInstance3D.new()
			var f_box = BoxMesh.new()
			f_box.size = dims
			furn_mesh.mesh = f_box

			# Frosted shader with subtle categorical tint
			var furn_mat = ShaderMaterial.new()
			furn_mat.shader = DOLLHOUSE_FROSTED_SHADER
			var colors = _get_dollhouse_furniture_colors(lbl)
			furn_mat.set_shader_parameter("albedo_color", colors["albedo"])
			furn_mat.set_shader_parameter("edge_color", colors["edge"])
			furn_mat.set_shader_parameter("fresnel_power", 2.2)
			furn_mat.set_shader_parameter("edge_intensity", 2.5)
			furn_mesh.material_override = furn_mat

			furn_mesh.position = pos
			furn_mesh.rotation = rot

			# Add crisp wireframe edge box
			var furn_wire = _create_wireframe_box(dims, colors["edge"])
			furn_mesh.add_child(furn_wire)

			dollhouse_furniture_container.add_child(furn_mesh)

	_update_info_display(target_scene, 4, furniture_list.size(), Vector3(obb.get("width", 0), wall_height, obb.get("length", 0)))


## Fallback if raw mesh or legacy saved scene is active
func _build_fallback_cad_geometry(target_scene: String) -> void:
	var children_count: int = 0
	var min_pt = Vector3(INF, INF, INF)
	var max_pt = Vector3(-INF, -INF, -INF)
	var found_any = false

	if scene_manager:
		for c in scene_manager.get_children():
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
		bounds_center.y = min_pt.y
		room_floor_y = min_pt.y

	if scene_manager and room_surfaces_container:
		for c in scene_manager.get_children():
			if not (c is Node3D):
				continue
			children_count += 1
			var lbl_node = c.get_node_or_null("Label3D")
			var lbl_text = lbl_node.text.to_lower() if lbl_node else ""
			var meshes = c.find_children("*", "MeshInstance3D", true, false)
			for m in meshes:
				if m is MeshInstance3D and m.mesh:
					var mini_mesh = MeshInstance3D.new()
					mini_mesh.mesh = m.mesh
					var rel_transform = m.global_transform
					rel_transform.origin -= bounds_center
					mini_mesh.transform = rel_transform

					var cad_mat = ShaderMaterial.new()
					cad_mat.shader = CAD_SURFACE_SHADER
					var color_info = _get_cad_color_for_label(lbl_text)
					cad_mat.set_shader_parameter("albedo_color", color_info["albedo"])
					cad_mat.set_shader_parameter("edge_color", color_info["edge"])
					cad_mat.set_shader_parameter("fresnel_power", 2.2)
					cad_mat.set_shader_parameter("edge_intensity", 2.0)
					mini_mesh.material_override = cad_mat
					room_surfaces_container.add_child(mini_mesh)


## Creates the stylized orange humanoid user locator pin ("You Are Here" marker)
func _create_player_pin() -> Node3D:
	var pin = Node3D.new()
	pin.name = "PlayerPin"

	var pin_mat = StandardMaterial3D.new()
	pin_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pin_mat.albedo_color = Color(1.0, 0.58, 0.05) # Radiant orange/amber matching Meta's pin

	# Torso/body: tapered cylinder
	var body_mesh = MeshInstance3D.new()
	var cyl = CylinderMesh.new()
	cyl.top_radius = 0.035
	cyl.bottom_radius = 0.08
	cyl.height = 0.20
	body_mesh.mesh = cyl
	body_mesh.position = Vector3(0, 0.10, 0)
	body_mesh.material_override = pin_mat
	pin.add_child(body_mesh)

	# Head: sphere
	var head_mesh = MeshInstance3D.new()
	var sph = SphereMesh.new()
	sph.radius = 0.06
	sph.height = 0.12
	head_mesh.mesh = sph
	head_mesh.position = Vector3(0, 0.25, 0)
	head_mesh.material_override = pin_mat
	pin.add_child(head_mesh)

	# Directional pointer/visor facing -Z forward
	var dir_mesh = MeshInstance3D.new()
	var cone = CylinderMesh.new()
	cone.top_radius = 0.005
	cone.bottom_radius = 0.03
	cone.height = 0.09
	dir_mesh.mesh = cone
	dir_mesh.rotation.x = deg_to_rad(-90)
	dir_mesh.position = Vector3(0, 0.25, -0.075)
	dir_mesh.material_override = pin_mat
	pin.add_child(dir_mesh)

	return pin


## Creates clean unshaded wireframe lines around any box volume
func _create_wireframe_box(size: Vector3, color: Color) -> MeshInstance3D:
	var wire = MeshInstance3D.new()
	var im = ImmediateMesh.new()
	var h = size * 0.5

	im.surface_begin(Mesh.PRIMITIVE_LINES)
	var pts = [
		# Bottom 4 edges
		Vector3(-h.x, -h.y, -h.z), Vector3(h.x, -h.y, -h.z),
		Vector3(h.x, -h.y, -h.z), Vector3(h.x, -h.y, h.z),
		Vector3(h.x, -h.y, h.z), Vector3(-h.x, -h.y, h.z),
		Vector3(-h.x, -h.y, h.z), Vector3(-h.x, -h.y, -h.z),
		# Top 4 edges
		Vector3(-h.x, h.y, -h.z), Vector3(h.x, h.y, -h.z),
		Vector3(h.x, h.y, -h.z), Vector3(h.x, h.y, h.z),
		Vector3(h.x, h.y, h.z), Vector3(-h.x, h.y, h.z),
		Vector3(-h.x, h.y, h.z), Vector3(-h.x, h.y, -h.z),
		# 4 vertical corner pillars
		Vector3(-h.x, -h.y, -h.z), Vector3(-h.x, h.y, -h.z),
		Vector3(h.x, -h.y, -h.z), Vector3(h.x, h.y, -h.z),
		Vector3(h.x, -h.y, h.z), Vector3(h.x, h.y, h.z),
		Vector3(-h.x, -h.y, h.z), Vector3(-h.x, h.y, h.z),
	]
	for p in pts:
		im.surface_add_vertex(p)
	im.surface_end()

	wire.mesh = im
	var mat = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	wire.material_override = mat

	return wire


func _get_dollhouse_furniture_colors(label: String) -> Dictionary:
	if "bed" in label:
		return {
			"albedo": Color(0.95, 0.92, 0.98, 0.40),
			"edge": Color(1.0, 1.0, 1.0, 0.95)
		}
	elif "table" in label or "desk" in label:
		return {
			"albedo": Color(0.85, 0.95, 0.98, 0.40),
			"edge": Color(0.9, 1.0, 1.0, 0.95)
		}
	elif "couch" in label:
		return {
			"albedo": Color(0.88, 0.95, 0.90, 0.40),
			"edge": Color(0.95, 1.0, 0.95, 0.95)
		}
	elif "storage" in label:
		return {
			"albedo": Color(0.92, 0.92, 0.96, 0.40),
			"edge": Color(1.0, 1.0, 1.0, 0.95)
		}
	return {
		"albedo": Color(0.90, 0.93, 0.98, 0.35),
		"edge": Color(1.0, 1.0, 1.0, 0.95)
	}


func _setup_baseplate() -> void:
	if baseplate_mesh:
		var mat = ShaderMaterial.new()
		mat.shader = CAD_GRID_SHADER
		baseplate_mesh.set_surface_override_material(0, mat)


## Grab and drag repositioning
func start_grab(controller: Node3D) -> void:
	if not controller:
		return
	is_grabbed = true
	grabbing_controller = controller
	grab_local_transform = controller.global_transform.affine_inverse() * global_transform
	if controller is XRController3D:
		controller.trigger_haptic_pulse("haptic", 100.0, 0.5, 0.06, 0.0)


func end_grab() -> void:
	if is_grabbed and grabbing_controller is XRController3D:
		grabbing_controller.trigger_haptic_pulse("haptic", 80.0, 0.3, 0.04, 0.0)
	is_grabbed = false
	grabbing_controller = null


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


func _get_cad_color_for_label(semantic_text: String) -> Dictionary:
	if "floor" in semantic_text:
		return {"albedo": Color(0.03, 0.12, 0.22, 0.6), "edge": Color(0.1, 0.6, 0.9, 0.9)}
	elif "ceiling" in semantic_text:
		return {"albedo": Color(0.04, 0.08, 0.15, 0.3), "edge": Color(0.3, 0.5, 0.7, 0.6)}
	elif "wall" in semantic_text:
		return {"albedo": Color(0.05, 0.25, 0.5, 0.75), "edge": Color(0.0, 0.95, 1.0, 1.0)}
	elif "door" in semantic_text or "window" in semantic_text:
		return {"albedo": Color(0.4, 0.1, 0.1, 0.7), "edge": Color(1.0, 0.3, 0.3, 1.0)}
	elif "table" in semantic_text or "desk" in semantic_text or "couch" in semantic_text:
		return {"albedo": Color(0.05, 0.35, 0.2, 0.8), "edge": Color(0.2, 1.0, 0.5, 1.0)}
	return {"albedo": Color(0.1, 0.2, 0.35, 0.7), "edge": Color(0.4, 0.8, 1.0, 0.9)}


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


func set_view_mode(mode: String) -> void:
	is_turntable_active = false
	if not model_rotator:
		return
	var tween = create_tween().set_parallel(true)
	match mode:
		"top_down":
			tween.tween_property(model_rotator, "rotation_degrees", Vector3(90, 0, 0), 0.3).set_trans(Tween.TRANS_QUAD)
		"isometric":
			tween.tween_property(model_rotator, "rotation_degrees", Vector3(32, -45, 0), 0.3).set_trans(Tween.TRANS_QUAD)
		"front":
			tween.tween_property(model_rotator, "rotation_degrees", Vector3(0, 0, 0), 0.3).set_trans(Tween.TRANS_QUAD)
		"turntable":
			is_turntable_active = true
	view_mode_changed.emit(mode)


func _update_info_display(scene_name: String = "", surface_cnt: int = -1, anchor_cnt: int = -1, extents: Vector3 = Vector3.ZERO) -> void:
	var active_name = scene_name if not scene_name.is_empty() else active_scene_name
	var preset_label = SCALE_PRESETS[current_preset_idx]["label"]

	if title_label:
		title_label.text = "Dollhouse: %s" % active_name

	if info_label:
		var info_text = "Scale: %s (%.1f%%)\n" % [preset_label, current_scale * 100.0]
		if extents != Vector3.ZERO:
			info_text += "Real Size: %.2fm W × %.2fm L × %.2fm H\n" % [extents.x, extents.z, extents.y]
		if surface_cnt >= 0:
			info_text += "Walls: %d | Items: %d" % [surface_cnt, anchor_cnt]
		info_label.text = info_text
