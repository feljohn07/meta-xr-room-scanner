extends Control

signal passthrough_toggled()
signal cad_toggled()
signal tape_toggled()
signal undo_measurement()
signal menu_toggled()
signal cycle_color()
signal toggle_hand()

@onready var layout_label: Label = %LayoutLabel
@onready var passthrough_btn: Button = %PassthroughBtn
@onready var cad_btn: Button = %CadBtn
@onready var tape_btn: Button = %TapeBtn
@onready var undo_tape_btn: Button = %UndoTapeBtn
@onready var color_btn: Button = %ColorBtn
@onready var hub_btn: Button = %HubBtn
@onready var hand_btn: Button = %HandBtn
@onready var metrics_label: Label = %MetricsLabel
@onready var color_preview: ColorRect = %ColorPreview


func _ready() -> void:
	if passthrough_btn:
		passthrough_btn.pressed.connect(func(): passthrough_toggled.emit())
	if cad_btn:
		cad_btn.pressed.connect(func(): cad_toggled.emit())
	if tape_btn:
		tape_btn.pressed.connect(func(): tape_toggled.emit())
	if undo_tape_btn:
		undo_tape_btn.pressed.connect(func(): undo_measurement.emit())
	if color_btn:
		color_btn.pressed.connect(func(): cycle_color.emit())
	if hub_btn:
		hub_btn.pressed.connect(func(): menu_toggled.emit())
	if hand_btn:
		hand_btn.pressed.connect(func(): toggle_hand.emit())


func set_layout_info(layout_name: String, anchor_count: int) -> void:
	if layout_label:
		layout_label.text = "%s (%d anchors)" % [layout_name, anchor_count]


func set_metrics_info(total_dist: float, use_imperial: bool, segment_count: int) -> void:
	if metrics_label:
		if segment_count == 0:
			metrics_label.text = "Tape: Inactive"
		elif use_imperial:
			metrics_label.text = "Total: %.2f ft (%d seg)" % [total_dist * 3.28084, segment_count]
		else:
			metrics_label.text = "Total: %.2f m (%d seg)" % [total_dist, segment_count]


func set_tape_active(active: bool) -> void:
	if tape_btn:
		tape_btn.modulate = Color(1.0, 0.4, 0.4) if active else Color(1, 1, 1)
		tape_btn.text = "⏹ Stop Tape" if active else "📏 Tape"


func set_active_color(col: Color) -> void:
	if color_preview:
		color_preview.color = col


func set_dominant_hand(hand: String) -> void:
	if hand_btn:
		hand_btn.text = "✋ Hand: %s" % hand.capitalize()
