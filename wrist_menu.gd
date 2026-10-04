class_name WristMenu
extends Node3D

signal passthrough_toggled()
signal cad_toggled()
signal tape_toggled()
signal undo_measurement()
signal menu_toggled()
signal cycle_color()
signal toggle_hand()

@export var glance_threshold: float = 0.40
@export var is_glance_active: bool = true
var tracking_hand: String = "left"

@onready var viewport_panel: Node3D = $Viewport2Din3D

var xr_camera: XRCamera3D = null
var is_menu_visible: bool = false
var _panel_ui: Control = null


func _ready() -> void:
	_setup_ui()


func _setup_ui() -> void:
	if not viewport_panel:
		return

	var ui = viewport_panel.get_scene_root() if viewport_panel.has_method("get_scene_root") else null
	if not ui:
		await get_tree().process_frame
		if viewport_panel and viewport_panel.has_method("get_scene_root"):
			ui = viewport_panel.get_scene_root()

	if ui:
		_panel_ui = ui
		if not ui.passthrough_toggled.is_connected(_on_passthrough):
			ui.passthrough_toggled.connect(_on_passthrough)
		if not ui.cad_toggled.is_connected(_on_cad):
			ui.cad_toggled.connect(_on_cad)
		if not ui.tape_toggled.is_connected(_on_tape):
			ui.tape_toggled.connect(_on_tape)
		if not ui.undo_measurement.is_connected(_on_undo):
			ui.undo_measurement.connect(_on_undo)
		if not ui.menu_toggled.is_connected(_on_menu):
			ui.menu_toggled.connect(_on_menu)
		if not ui.cycle_color.is_connected(_on_cycle_color):
			ui.cycle_color.connect(_on_cycle_color)
		if not ui.toggle_hand.is_connected(_on_toggle_hand):
			ui.toggle_hand.connect(_on_toggle_hand)


func _on_passthrough() -> void:
	passthrough_toggled.emit()


func _on_cad() -> void:
	cad_toggled.emit()


func _on_tape() -> void:
	tape_toggled.emit()


func _on_undo() -> void:
	undo_measurement.emit()


func _on_menu() -> void:
	menu_toggled.emit()


func _on_cycle_color() -> void:
	cycle_color.emit()


func _on_toggle_hand() -> void:
	toggle_hand.emit()


func set_layout_info(layout_name: String, anchor_count: int) -> void:
	if _panel_ui and _panel_ui.has_method("set_layout_info"):
		_panel_ui.set_layout_info(layout_name, anchor_count)


func set_metrics_info(total_dist: float, use_imperial: bool, segment_count: int) -> void:
	if _panel_ui and _panel_ui.has_method("set_metrics_info"):
		_panel_ui.set_metrics_info(total_dist, use_imperial, segment_count)


func set_tape_active(active: bool) -> void:
	if _panel_ui and _panel_ui.has_method("set_tape_active"):
		_panel_ui.set_tape_active(active)


func set_active_color(col: Color) -> void:
	if _panel_ui and _panel_ui.has_method("set_active_color"):
		_panel_ui.set_active_color(col)


func set_dominant_hand(hand: String) -> void:
	tracking_hand = "left" if hand == "right" else "right"
	if _panel_ui and _panel_ui.has_method("set_dominant_hand"):
		_panel_ui.set_dominant_hand(hand)


func _process(_delta: float) -> void:
	if not is_glance_active or not xr_camera or not is_inside_tree():
		return

	# Determine if the watch / palm normal is pointing toward the player's head
	var glance_normal = global_transform.basis.y
	var tracker = XRServer.get_tracker("/user/hand_tracker/" + tracking_hand) as XRHandTracker
	if tracker and tracker.has_tracking_data:
		var palm_tf = tracker.get_hand_joint_transform(XRHandTracker.HAND_JOINT_PALM)
		# Palm Y or -Z represents palm face normal
		glance_normal = (global_transform.basis * palm_tf.basis.y).normalized()

	var to_cam = (xr_camera.global_position - global_position).normalized()
	var dot = glance_normal.dot(to_cam)

	# Strict >= 0.20 hysteresis buffer prevents edge jitter
	if dot > glance_threshold:
		if not is_menu_visible:
			is_menu_visible = true
			visible = true
	elif dot < (glance_threshold - 0.22):
		if is_menu_visible:
			is_menu_visible = false
			visible = false
