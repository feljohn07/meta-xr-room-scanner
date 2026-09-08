extends Control

signal scale_down_requested()
signal scale_up_requested()
signal view_iso_requested()
signal view_topdown_requested()
signal turntable_toggle_requested()
signal refresh_requested()
signal close_requested()

@onready var scale_down_btn: Button = %ScaleDownBtn
@onready var scale_up_btn: Button = %ScaleUpBtn
@onready var view_iso_btn: Button = %ViewIsoBtn
@onready var view_topdown_btn: Button = %ViewTopDownBtn
@onready var turntable_btn: Button = %TurntableBtn
@onready var refresh_btn: Button = %RefreshBtn
@onready var close_btn: Button = %CloseBtn
@onready var status_lbl: Label = %StatusLabel


func _ready() -> void:
	if scale_down_btn:
		scale_down_btn.pressed.connect(func(): scale_down_requested.emit())
	if scale_up_btn:
		scale_up_btn.pressed.connect(func(): scale_up_requested.emit())
	if view_iso_btn:
		view_iso_btn.pressed.connect(func(): view_iso_requested.emit())
	if view_topdown_btn:
		view_topdown_btn.pressed.connect(func(): view_topdown_requested.emit())
	if turntable_btn:
		turntable_btn.pressed.connect(func(): turntable_toggle_requested.emit())
	if refresh_btn:
		refresh_btn.pressed.connect(func(): refresh_requested.emit())
	if close_btn:
		close_btn.pressed.connect(func(): close_requested.emit())


func set_status_text(text: String) -> void:
	if status_lbl:
		status_lbl.text = text
