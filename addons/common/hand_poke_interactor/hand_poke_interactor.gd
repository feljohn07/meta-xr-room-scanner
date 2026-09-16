@tool
class_name HandPokeInteractor
extends Node3D

signal direct_touch_started(object: Node3D)
signal direct_touch_ended(object: Node3D)

@export_enum("left", "right") var hand: String = "right"
@export var enabled: bool = true
@export var poke_radius: float = 0.012

@onready var touch_area: Area3D = $TouchArea
@onready var tip_mesh: MeshInstance3D = $TipMesh

var _controller: XRController3D = null
var _xr_origin: XROrigin3D = null
var _current_ui_layer = null
var _is_pressing: bool = false
var _hovering_object: Node3D = null


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

	if touch_area:
		touch_area.area_entered.connect(_on_area_entered)
		touch_area.area_exited.connect(_on_area_exited)
		touch_area.body_entered.connect(_on_body_entered)
		touch_area.body_exited.connect(_on_body_exited)


func _process(_delta: float) -> void:
	if not enabled or not is_inside_tree():
		if _current_ui_layer:
			_current_ui_layer.poke_leave()
			_current_ui_layer = null
		return

	_update_fingertip_position()
	_update_ui_poke()


func _update_fingertip_position() -> void:
	var tracker_name = "/user/hand_tracker/" + hand
	var tracker = XRServer.get_tracker(tracker_name) as XRHandTracker

	if tracker and tracker.has_tracking_data and _xr_origin:
		# Query standard OpenXR index fingertip joint
		var tip_tf: Transform3D = tracker.get_hand_joint_transform(XRHandTracker.HAND_JOINT_INDEX_FINGER_TIP)
		global_transform = _xr_origin.global_transform * tip_tf
		if tip_mesh:
			tip_mesh.visible = true
	elif _controller:
		# Fallback to controller pointer offset
		global_transform = _controller.global_transform * Transform3D(Basis(), Vector3(0.0, 0.0, -0.06))
		if tip_mesh:
			tip_mesh.visible = true


func _update_ui_poke() -> void:
	var ui_layers = get_tree().get_nodes_in_group("ui_layer")
	var hit_layer = null

	for layer in ui_layers:
		if not is_instance_valid(layer) or not layer.visible:
			continue
		if layer.has_method("poke_at"):
			var handled = layer.poke_at(global_position)
			if handled:
				hit_layer = layer
				break

	if hit_layer != _current_ui_layer:
		if _current_ui_layer and is_instance_valid(_current_ui_layer) and _current_ui_layer.has_method("poke_leave"):
			_current_ui_layer.poke_leave()
		_current_ui_layer = hit_layer

	# Visual glow intensity based on proximity to active UI
	if tip_mesh and tip_mesh.get_surface_override_material(0):
		var mat = tip_mesh.get_surface_override_material(0) as StandardMaterial3D
		if mat:
			mat.albedo_color = Color(0.2, 1.0, 0.6, 0.9) if hit_layer else Color(0.0, 0.85, 1.0, 0.65)


func _on_area_entered(area: Area3D) -> void:
	_hovering_object = area
	direct_touch_started.emit(area)


func _on_area_exited(area: Area3D) -> void:
	if _hovering_object == area:
		_hovering_object = null
	direct_touch_ended.emit(area)


func _on_body_entered(body: Node3D) -> void:
	_hovering_object = body
	direct_touch_started.emit(body)


func _on_body_exited(body: Node3D) -> void:
	if _hovering_object == body:
		_hovering_object = null
	direct_touch_ended.emit(body)
