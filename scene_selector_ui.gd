extends Control

signal load_scene_requested(scene_name: String)
signal save_scene_requested(scene_name: String)
signal delete_scene_requested(scene_name: String)
signal clear_anchors_requested()
signal request_room_capture()
signal close_requested()

signal toggle_tape_measure_requested(enabled: bool)
signal clear_measurements_requested()
signal refresh_room_dimensions_requested()
signal unit_preference_changed(use_imperial: bool)
signal toggle_cad_view_requested()

@onready var tab_layouts_btn: Button = %TabLayoutsBtn
@onready var tab_measure_btn: Button = %TabMeasureBtn
@onready var tab_cad_btn: Button = %TabCadBtn
@onready var layouts_view: VBoxContainer = %LayoutsView
@onready var measure_view: VBoxContainer = %MeasureView

@onready var active_label: Label = %ActiveLabel
@onready var scene_list_container: VBoxContainer = %SceneListContainer
@onready var scene_name_input: LineEdit = %SceneNameInput
@onready var save_button: Button = %SaveButton
@onready var clear_button: Button = %ClearButton
@onready var capture_button: Button = %CaptureButton
@onready var close_button: Button = %CloseButton
@onready var status_label: Label = %StatusLabel

# Measurement UI
@onready var height_label: Label = %HeightLabel
@onready var width_label: Label = %WidthLabel
@onready var length_label: Label = %LengthLabel
@onready var area_label: Label = %AreaLabel
@onready var volume_label: Label = %VolumeLabel
@onready var surfaces_label: Label = %SurfacesLabel
@onready var refresh_bounds_button: Button = %RefreshBoundsButton
@onready var toggle_tape_button: Button = %ToggleTapeButton
@onready var clear_tape_button: Button = %ClearTapeButton
@onready var unit_toggle_button: Button = %UnitToggleButton
@onready var tape_instructions: Label = %TapeInstructions

var _current_active_scene: String = "Default"
var _scenes_cache: Dictionary = {}
var _room_dims_cache: Dictionary = {}
var _tape_measure_active := false
var _use_imperial := false

const PRESET_NAMES = ["Living Room", "Office", "Workspace", "Play Area", "Custom Layout"]


func _ready() -> void:
	if save_button:
		save_button.pressed.connect(_on_save_pressed)
		_register_hover_effect(save_button, "Save currently placed room anchors")
	if clear_button:
		clear_button.pressed.connect(_on_clear_pressed)
		_register_hover_effect(clear_button, "Remove all active anchors from room")
	if capture_button:
		capture_button.pressed.connect(_on_capture_pressed)
		_register_hover_effect(capture_button, "Run Meta Room Space Setup capture")
	if close_button:
		close_button.pressed.connect(_on_close_pressed)
		_register_hover_effect(close_button, "Dismiss this floating menu")

	# Tab Switching
	if tab_layouts_btn:
		tab_layouts_btn.pressed.connect(func(): _switch_tab(0))
		_register_hover_effect(tab_layouts_btn, "View saved layouts")
	if tab_measure_btn:
		tab_measure_btn.pressed.connect(func():
			_switch_tab(1)
			show_status("Calculating room dimensions from Meta Room scan...")
			refresh_room_dimensions_requested.emit()
		)
		_register_hover_effect(tab_measure_btn, "View room dimensions and 3D tape measure")
	if tab_cad_btn:
		tab_cad_btn.pressed.connect(func():
			toggle_cad_view_requested.emit()
			show_status("Toggled 3D CAD Blueprint Dollhouse View")
		)
		_register_hover_effect(tab_cad_btn, "Spawn/Toggle 3D Miniature CAD Blueprint Model")

	# Measurement Controls
	if refresh_bounds_button:
		refresh_bounds_button.pressed.connect(_on_refresh_bounds_pressed)
		_register_hover_effect(refresh_bounds_button, "Recalculate dimensions from scanned walls and floor")
	if toggle_tape_button:
		toggle_tape_button.pressed.connect(_on_toggle_tape_pressed)
		_register_hover_effect(toggle_tape_button, "Toggle point-to-point 3D tape measure")
	if clear_tape_button:
		clear_tape_button.pressed.connect(_on_clear_tape_pressed)
		_register_hover_effect(clear_tape_button, "Clear placed measurement lines")
	if unit_toggle_button:
		unit_toggle_button.pressed.connect(_on_unit_toggle_pressed)
		_register_hover_effect(unit_toggle_button, "Switch between Meters and Feet")

	_setup_preset_buttons()
	_switch_tab(0)


func _switch_tab(tab_index: int) -> void:
	if layouts_view and measure_view:
		layouts_view.visible = (tab_index == 0)
		measure_view.visible = (tab_index == 1)

	if tab_layouts_btn:
		tab_layouts_btn.modulate = Color(0.3, 0.9, 1.0) if tab_index == 0 else Color(0.7, 0.75, 0.85)
	if tab_measure_btn:
		tab_measure_btn.modulate = Color(0.3, 0.9, 1.0) if tab_index == 1 else Color(0.7, 0.75, 0.85)


func _register_hover_effect(btn: Button, hint_text: String = "") -> void:
	if not btn:
		return

	btn.mouse_entered.connect(func():
		btn.pivot_offset = btn.size / 2.0
		var tween = create_tween()
		tween.tween_property(btn, "scale", Vector2(1.05, 1.05), 0.08)
		if not hint_text.is_empty() and status_label:
			status_label.text = "▶ " + hint_text
			status_label.modulate = Color(0.3, 0.85, 1.0)
	)

	btn.mouse_exited.connect(func():
		var tween = create_tween()
		tween.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.08)
		if status_label and status_label.text == ("▶ " + hint_text):
			status_label.text = ""
	)


func _setup_preset_buttons() -> void:
	var preset_container = %PresetContainer
	if not preset_container:
		return

	for child in preset_container.get_children():
		child.queue_free()

	for preset_name in PRESET_NAMES:
		var btn = Button.new()
		btn.text = preset_name
		btn.custom_minimum_size = Vector2(0, 36)
		btn.pressed.connect(func():
			if scene_name_input:
				scene_name_input.text = preset_name
				show_status("Selected preset '%s'" % preset_name)
		)
		_register_hover_effect(btn, "Choose preset: " + preset_name)
		preset_container.add_child(btn)


func set_scenes_data(scenes_dict: Dictionary, active_scene: String, current_anchor_count: int) -> void:
	_scenes_cache = scenes_dict
	_current_active_scene = active_scene

	if active_label:
		active_label.text = "Active Layout: %s (%d anchors in room)" % [active_scene, current_anchor_count]

	if scene_name_input and scene_name_input.text.is_empty():
		scene_name_input.text = active_scene

	_refresh_scene_list()


func set_room_dimensions(dims: Dictionary) -> void:
	_room_dims_cache = dims
	_update_dimensions_display()


func _update_dimensions_display() -> void:
	var h = _room_dims_cache.get("height", 0.0)
	var w = _room_dims_cache.get("width", 0.0)
	var l = _room_dims_cache.get("length", 0.0)
	var surfaces_count = _room_dims_cache.get("surfaces_count", 0)

	var area = w * l
	var vol = area * h

	if _use_imperial:
		var ft_h = h * 3.28084
		var ft_w = w * 3.28084
		var ft_l = l * 3.28084
		var sq_ft = area * 10.7639
		var cu_ft = vol * 35.3147

		if height_label:
			height_label.text = "Height: %.2f ft" % ft_h if h > 0.0 else "Height: Not Detected"
		if width_label:
			width_label.text = "Width: %.2f ft" % ft_w if w > 0.0 else "Width: Not Detected"
		if length_label:
			length_label.text = "Length: %.2f ft" % ft_l if l > 0.0 else "Length: Not Detected"
		if area_label:
			area_label.text = "Floor Area: %.1f sq ft" % sq_ft if area > 0.0 else "Floor Area: --"
		if volume_label:
			volume_label.text = "Volume: %.1f cu ft" % cu_ft if vol > 0.0 else "Volume: --"
	else:
		if height_label:
			height_label.text = "Height: %.2f m" % h if h > 0.0 else "Height: Not Detected"
		if width_label:
			width_label.text = "Width: %.2f m" % w if w > 0.0 else "Width: Not Detected"
		if length_label:
			length_label.text = "Length: %.2f m" % l if l > 0.0 else "Length: Not Detected"
		if area_label:
			area_label.text = "Floor Area: %.1f m²" % area if area > 0.0 else "Floor Area: --"
		if volume_label:
			volume_label.text = "Volume: %.1f m³" % vol if vol > 0.0 else "Volume: --"

	if surfaces_label:
		if surfaces_count > 0:
			surfaces_label.text = "Surfaces: %d scanned" % surfaces_count
		else:
			surfaces_label.text = "Surfaces: 0 scanned (Run 'Capture Room' to scan)"
			if status_label and status_label.text.is_empty():
				show_status("No Meta Room scan detected yet. Click 'Capture Room' below.", true)


func set_tape_measure_state(active: bool, has_point_a: bool = false) -> void:
	_tape_measure_active = active
	if toggle_tape_button:
		if active:
			toggle_tape_button.text = "⏹ Stop Tape Measure"
			toggle_tape_button.modulate = Color(1.0, 0.4, 0.4)
		else:
			toggle_tape_button.text = "📏 Start Tape Measure"
			toggle_tape_button.modulate = Color(1.0, 1.0, 1.0)

	if tape_instructions:
		if not active:
			tape_instructions.text = "1. Click 'Start Tape Measure'.\n2. Aim laser at wall/floor & press Trigger for Point A.\n3. Move laser to Point B & press Trigger again."
			tape_instructions.modulate = Color(0.8, 0.85, 0.95)
		elif not has_point_a:
			tape_instructions.text = "🟢 Point A: Aim at wall/floor and press Trigger!"
			tape_instructions.modulate = Color(0.3, 0.9, 1.0)
		else:
			tape_instructions.text = "🟡 Point B: Point A set! Aim at end point and press Trigger to lock!"
			tape_instructions.modulate = Color(0.4, 1.0, 0.5)


func show_status(msg: String, is_error: bool = false) -> void:
	if status_label:
		status_label.text = msg
		status_label.modulate = Color(1.0, 0.35, 0.35) if is_error else Color(0.35, 1.0, 0.5)


func _refresh_scene_list() -> void:
	if not scene_list_container:
		return

	for child in scene_list_container.get_children():
		child.queue_free()

	var scene_names = _scenes_cache.keys()
	scene_names.sort()

	if scene_names.is_empty():
		var empty_lbl = Label.new()
		empty_lbl.text = "No saved layouts yet. Save current layout below!"
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_lbl.modulate = Color(0.7, 0.75, 0.85)
		scene_list_container.add_child(empty_lbl)
		return

	for scene_name in scene_names:
		var scene_info: Dictionary = _scenes_cache.get(scene_name, {})
		var count: int = 0
		if scene_info.has("anchors") and scene_info["anchors"] is Dictionary:
			count = scene_info["anchors"].size()
		elif scene_info is Dictionary:
			count = scene_info.size()

		var is_active = (scene_name == _current_active_scene)

		var row = PanelContainer.new()
		var row_box = HBoxContainer.new()
		row_box.add_theme_constant_override("separation", 12)

		var name_lbl = Label.new()
		name_lbl.text = "%s  (%d anchors)" % [scene_name, count]
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if is_active:
			name_lbl.text = "● " + name_lbl.text + " [ACTIVE]"
			name_lbl.modulate = Color(0.25, 1.0, 0.6)
		row_box.add_child(name_lbl)

		var load_btn = Button.new()
		load_btn.text = "Switch To"
		load_btn.custom_minimum_size = Vector2(110, 36)
		load_btn.disabled = is_active
		load_btn.pressed.connect(func():
			show_status("Switching to layout '%s'..." % scene_name)
			load_scene_requested.emit(scene_name)
		)
		_register_hover_effect(load_btn, "Load layout: " + scene_name)
		row_box.add_child(load_btn)

		var del_btn = Button.new()
		del_btn.text = "Delete"
		del_btn.custom_minimum_size = Vector2(80, 36)
		del_btn.pressed.connect(func():
			show_status("Deleted layout '%s'" % scene_name)
			delete_scene_requested.emit(scene_name)
		)
		_register_hover_effect(del_btn, "Delete layout: " + scene_name)
		row_box.add_child(del_btn)

		row.add_child(row_box)
		scene_list_container.add_child(row)


func _on_save_pressed() -> void:
	var name_to_save = scene_name_input.text.strip_edges() if scene_name_input else ""
	if name_to_save.is_empty():
		show_status("Please enter or pick a layout name!", true)
		return

	show_status("Saving layout '%s'..." % name_to_save)
	save_scene_requested.emit(name_to_save)


func _on_clear_pressed() -> void:
	show_status("Cleared current room anchors.")
	clear_anchors_requested.emit()


func _on_capture_pressed() -> void:
	show_status("Requesting Meta Room capture...")
	request_room_capture.emit()


func _on_close_pressed() -> void:
	close_requested.emit()


func _on_refresh_bounds_pressed() -> void:
	show_status("Recalculating room dimensions...")
	refresh_room_dimensions_requested.emit()


func _on_toggle_tape_pressed() -> void:
	_tape_measure_active = not _tape_measure_active
	set_tape_measure_state(_tape_measure_active, false)
	toggle_tape_measure_requested.emit(_tape_measure_active)


func _on_clear_tape_pressed() -> void:
	show_status("Cleared tape measurements.")
	clear_measurements_requested.emit()


func _on_unit_toggle_pressed() -> void:
	_use_imperial = not _use_imperial
	if unit_toggle_button:
		unit_toggle_button.text = "Unit: Feet (ft)" if _use_imperial else "Unit: Meters (m)"
	_update_dimensions_display()
	unit_preference_changed.emit(_use_imperial)
