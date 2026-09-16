@tool
class_name HandVisuals
extends Node3D

signal tracking_mode_changed(is_hand_tracking: bool)

@export_enum("left", "right") var hand: String = "right"

var _controller: XRController3D = null
var _xr_origin: XROrigin3D = null
var _hand_tracker: XRHandTracker = null
var _is_hand_tracking: bool = false
var _fb_hand_mesh: Node3D = null

# Visual elements
var _thumb_mesh: MeshInstance3D = null
var _index_mesh: MeshInstance3D = null
var _pinch_indicator: MeshInstance3D = null
var _pinch_mat: StandardMaterial3D = null


func _enter_tree() -> void:
	var p = get_parent()
	if p is XRController3D:
		_controller = p
		var anc = p.get_parent()
		while anc:
			if anc is XROrigin3D:
				_xr_origin = anc
				break
			anc = anc.get_parent()


func _ready() -> void:
	if not _xr_origin:
		var anc = get_parent()
		while anc:
			if anc is XROrigin3D:
				_xr_origin = anc
				break
			anc = anc.get_parent()

	_setup_visuals()
	_try_setup_fb_mesh()


func _setup_visuals() -> void:
	# Material for joint / fingertip dots
	var joint_mat = StandardMaterial3D.new()
	joint_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	joint_mat.albedo_color = Color(0.0, 0.9, 1.0, 0.6)
	joint_mat.no_depth_test = true
	joint_mat.render_priority = 10

	var sphere_mesh = SphereMesh.new()
	sphere_mesh.radius = 0.005
	sphere_mesh.height = 0.010
	sphere_mesh.material = joint_mat

	_thumb_mesh = MeshInstance3D.new()
	_thumb_mesh.mesh = sphere_mesh
	_thumb_mesh.visible = false
	add_child(_thumb_mesh)

	_index_mesh = MeshInstance3D.new()
	_index_mesh.mesh = sphere_mesh
	_index_mesh.visible = false
	add_child(_index_mesh)

	# Dynamic pinch connection indicator
	_pinch_mat = StandardMaterial3D.new()
	_pinch_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_pinch_mat.albedo_color = Color(0.0, 1.0, 0.8, 0.0)
	_pinch_mat.no_depth_test = true
	_pinch_mat.render_priority = 11

	var ring_mesh = TorusMesh.new()
	ring_mesh.inner_radius = 0.008
	ring_mesh.outer_radius = 0.012
	ring_mesh.material = _pinch_mat

	_pinch_indicator = MeshInstance3D.new()
	_pinch_indicator.mesh = ring_mesh
	_pinch_indicator.visible = false
	add_child(_pinch_indicator)


func _try_setup_fb_mesh() -> void:
	if ClassDB.class_exists("OpenXRFbHandTrackingMesh"):
		var mesh_inst = ClassDB.instantiate("OpenXRFbHandTrackingMesh")
		if mesh_inst and mesh_inst is Node3D:
			mesh_inst.set("hand", 0 if hand == "left" else 1)
			_fb_hand_mesh = mesh_inst
			add_child(_fb_hand_mesh)


func is_hand_tracking_active() -> bool:
	return _is_hand_tracking


func get_wrist_transform() -> Transform3D:
	var tracker_path = "/user/hand_tracker/" + hand
	var tracker = XRServer.get_tracker(tracker_path) as XRHandTracker
	if tracker and tracker.has_tracking_data and _xr_origin:
		var wrist_tf = tracker.get_hand_joint_transform(XRHandTracker.HAND_JOINT_WRIST)
		return _xr_origin.global_transform * wrist_tf
	elif _controller:
		return _controller.global_transform
	return global_transform


func get_palm_transform() -> Transform3D:
	var tracker_path = "/user/hand_tracker/" + hand
	var tracker = XRServer.get_tracker(tracker_path) as XRHandTracker
	if tracker and tracker.has_tracking_data and _xr_origin:
		var palm_tf = tracker.get_hand_joint_transform(XRHandTracker.HAND_JOINT_PALM)
		return _xr_origin.global_transform * palm_tf
	elif _controller:
		return _controller.global_transform
	return global_transform


func get_aim_transform() -> Transform3D:
	var tracker_path = "/user/hand_tracker/" + hand
	var tracker = XRServer.get_tracker(tracker_path) as XRHandTracker
	if tracker and tracker.has_tracking_data and _xr_origin:
		var thumb_tf = tracker.get_hand_joint_transform(XRHandTracker.HAND_JOINT_THUMB_TIP)
		var index_tf = tracker.get_hand_joint_transform(XRHandTracker.HAND_JOINT_INDEX_FINGER_TIP)
		var wrist_tf = tracker.get_hand_joint_transform(XRHandTracker.HAND_JOINT_WRIST)

		var origin_tf = _xr_origin.global_transform
		var pinch_pt = origin_tf * ((thumb_tf.origin + index_tf.origin) * 0.5)
		var wrist_pt = origin_tf * wrist_tf.origin
		var forward = (pinch_pt - wrist_pt).normalized()

		var up = (origin_tf.basis * wrist_tf.basis.y).normalized()
		var right = forward.cross(up).normalized()
		up = right.cross(forward).normalized()

		return Transform3D(Basis(right, up, -forward), pinch_pt)
	elif _controller:
		return _controller.global_transform
	return global_transform


func _process(_delta: float) -> void:
	var tracker_path = "/user/hand_tracker/" + hand
	var tracker = XRServer.get_tracker(tracker_path) as XRHandTracker

	var currently_hand_tracking = (tracker != null and tracker.has_tracking_data)

	if currently_hand_tracking != _is_hand_tracking:
		_is_hand_tracking = currently_hand_tracking
		tracking_mode_changed.emit(_is_hand_tracking)
		if _thumb_mesh:
			_thumb_mesh.visible = _is_hand_tracking
		if _index_mesh:
			_index_mesh.visible = _is_hand_tracking
		if _fb_hand_mesh:
			_fb_hand_mesh.visible = _is_hand_tracking

	if not _is_hand_tracking or not tracker or not _xr_origin:
		if _pinch_indicator:
			_pinch_indicator.visible = false
		return

	# Update fingertip transforms
	var origin_tf = _xr_origin.global_transform
	var thumb_tf: Transform3D = tracker.get_hand_joint_transform(XRHandTracker.HAND_JOINT_THUMB_TIP)
	var index_tf: Transform3D = tracker.get_hand_joint_transform(XRHandTracker.HAND_JOINT_INDEX_FINGER_TIP)

	var thumb_pos = origin_tf * thumb_tf.origin
	var index_pos = origin_tf * index_tf.origin

	if _thumb_mesh:
		_thumb_mesh.global_position = thumb_pos
	if _index_mesh:
		_index_mesh.global_position = index_pos

	# Calculate thumb-to-index distance for pinch visualization
	var pinch_dist = thumb_pos.distance_to(index_pos)
	# Distance typically ranges from ~0.08m (open) down to ~0.015m (pinched)
	var pinch_factor = clampf(inverse_lerp(0.06, 0.02, pinch_dist), 0.0, 1.0)

	if _pinch_indicator and _pinch_mat:
		if pinch_factor > 0.1:
			_pinch_indicator.visible = true
			var mid_point = (thumb_pos + index_pos) * 0.5
			_pinch_indicator.global_position = mid_point
			_pinch_indicator.scale = Vector3.ONE * lerpf(1.2, 0.6, pinch_factor)
			_pinch_mat.albedo_color = Color(0.0, 1.0, 0.8, pinch_factor * 0.9)
		else:
			_pinch_indicator.visible = false
