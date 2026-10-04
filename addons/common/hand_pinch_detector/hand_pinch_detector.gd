@tool
extends Node3D

## Signal emitted when pinch was tapped[br]
## This signal is not emitted if [signal pinch_held] was emitted some time after pinch started
signal pinch_tapped

## Signal emitted when pinch was held[br]
## This signal is not emitted if [signal pinch_tapped] was emitted some time after pinch started
signal pinch_held

## Signal emitted when pinch is released[br]
## This signal is always emitted some time after pinch started, and always after [signal
## pinch_tapped] or [signal pinch_held] if they were emitted too.[br]
signal pinch_released

## Emitted whenever the continuous pinch strength (0.0 to 1.0) updates
signal pinch_strength_changed(strength: float)

## Emitted when pinch enters the pre-pinch latching band (0.65 to 0.85) to lock aim
signal pinch_latching(strength: float)

## Secondary pinch signals (Thumb + Middle Finger chord)
signal secondary_pinch_tapped
signal secondary_pinch_held
signal secondary_pinch_released
signal secondary_pinch_strength_changed(strength: float)

## The primary pinch action (supports "trigger", "pinch_value", "index_pinch_strength", etc.)
@export var pinch_action: String = "trigger"

## The maximum time, in milliseconds, to detect pinch-then-release (or "pinch tap")
@export var pinch_tap_duration := 300:
	set = set_pinch_tap_duration

## The minimum time, in seconds, to detect pinch-then-hold; must be > pinch_tap_duration
@export var pinch_held_duration := 0.8:
	set = set_pinch_held_duration

# true when fingers are pinched
var _pinching := false

# true when fingers have been pinched for a long time
var _pinching_held := false

# true when in the pre-pinch stabilization band (locks ray aim)
var _is_latching := false

# current pinch strength (0.0 to 1.0)
var _current_strength: float = 0.0

# the timestamp when [param _pinching] changed from false->true
var _timestamp_when_pinch_detected := 0

# Secondary pinch state (Thumb to Middle finger)
var _sec_pinching := false
var _sec_pinching_held := false
var _sec_current_strength: float = 0.0
var _sec_timestamp_when_pinch_detected := 0

# the parent controller
var _controller: XRController3D
var _tracker_name: String = ""

# This Timer is started when _pinching changes from false->true, to detect if fingers have been
# pinched for a long time.
@onready var _pinching_held_timer: Timer = $Timer


func is_pinching() -> bool:
	return _pinching


func is_latching() -> bool:
	return _is_latching


func get_pinch_strength() -> float:
	return _current_strength


func is_secondary_pinching() -> bool:
	return _sec_pinching


func get_secondary_pinch_strength() -> float:
	return _sec_current_strength


func _enter_tree() -> void:
	var parent_node = get_parent()
	if !(parent_node is XRController3D):
		push_error("Unable to find XRController3D; it must be the immediate parent of this node!")
		return

	_controller = parent_node
	_tracker_name = "/user/hand_tracker/" + ("left" if _controller.tracker == &"left_hand" else "right")
	_controller.input_float_changed.connect(_on_input_float_changed)
	if not _controller.button_pressed.is_connected(_on_button_pressed):
		_controller.button_pressed.connect(_on_button_pressed)
	if not _controller.button_released.is_connected(_on_button_released):
		_controller.button_released.connect(_on_button_released)


func _process(_delta: float) -> void:
	if _tracker_name.is_empty():
		return

	var tracker = XRServer.get_tracker(_tracker_name) as XRHandTracker
	if tracker and tracker.has_tracking_data:
		var thumb_tf: Transform3D = tracker.get_hand_joint_transform(XRHandTracker.HAND_JOINT_THUMB_TIP)
		var index_tf: Transform3D = tracker.get_hand_joint_transform(XRHandTracker.HAND_JOINT_INDEX_FINGER_TIP)
		var dist: float = thumb_tf.origin.distance_to(index_tf.origin)

		var optical_strength: float = clampf(inverse_lerp(0.055, 0.022, dist), 0.0, 1.0)
		_current_strength = optical_strength
		pinch_strength_changed.emit(_current_strength)

		# 1. Pre-pinch aim latching zone (0.65 to 0.85) to lock distant reticle
		if not _pinching:
			if optical_strength >= 0.65 and optical_strength < 0.85:
				if not _is_latching:
					_is_latching = true
				pinch_latching.emit(optical_strength)
			elif optical_strength < 0.50 and _is_latching:
				_is_latching = false
				pinch_latching.emit(0.0)

		# 2. Primary Pinch trigger threshold (0.85 to contact)
		if not _pinching:
			if optical_strength > 0.85:
				_is_latching = false
				_pinching = true
				_timestamp_when_pinch_detected = Time.get_ticks_msec()
				if _pinching_held_timer:
					_pinching_held_timer.start(pinch_held_duration)
		else:
			if optical_strength < 0.40:
				_end_pinch()

		# 3. Secondary Pinch detection (Thumb to Middle finger tip)
		var middle_tf: Transform3D = tracker.get_hand_joint_transform(XRHandTracker.HAND_JOINT_MIDDLE_FINGER_TIP)
		var sec_dist: float = thumb_tf.origin.distance_to(middle_tf.origin)
		var sec_strength: float = clampf(inverse_lerp(0.055, 0.024, sec_dist), 0.0, 1.0)
		_sec_current_strength = sec_strength
		secondary_pinch_strength_changed.emit(_sec_current_strength)

		if not _sec_pinching:
			if sec_strength > 0.85:
				_sec_pinching = true
				_sec_timestamp_when_pinch_detected = Time.get_ticks_msec()
		else:
			if sec_strength < 0.40:
				_end_secondary_pinch()
			elif not _sec_pinching_held and (Time.get_ticks_msec() - _sec_timestamp_when_pinch_detected) >= int(pinch_held_duration * 1000.0):
				_sec_pinching_held = true
				secondary_pinch_held.emit()


func _exit_tree() -> void:
	if _pinching_held_timer:
		_pinching_held_timer.stop()

	if _controller:
		if _controller.input_float_changed.is_connected(_on_input_float_changed):
			_controller.input_float_changed.disconnect(_on_input_float_changed)
		if _controller.button_pressed.is_connected(_on_button_pressed):
			_controller.button_pressed.disconnect(_on_button_pressed)
		if _controller.button_released.is_connected(_on_button_released):
			_controller.button_released.disconnect(_on_button_released)
		_controller = null


func set_pinch_tap_duration(new_pinch_tap_duration: int) -> void:
	if (pinch_held_duration * 1000.0) <= float(new_pinch_tap_duration):
		push_error("Pinch tap duration must be < pinch held duration")
		return

	pinch_tap_duration = new_pinch_tap_duration


func set_pinch_held_duration(new_pinch_held_duration: float) -> void:
	if (new_pinch_held_duration * 1000.0) <= float(pinch_tap_duration):
		push_error("Pinch held duration must be > pinch tap duration")
		return

	pinch_held_duration = new_pinch_held_duration


func _is_pinch_float_action(action_name: String) -> bool:
	return (
		action_name == pinch_action
		or action_name == "trigger"
		or action_name == "pinch_value"
		or action_name == "index_pinch_strength"
		or action_name == "pinch"
	)


func _is_pinch_button_action(action_name: String) -> bool:
	return (
		action_name == "trigger_click"
		or action_name == "index_pinch"
		or action_name == "pinch"
		or action_name == "select_button"
	)


func _on_input_float_changed(action_name: String, value: float) -> void:
	if not _is_pinch_float_action(action_name):
		return

	_current_strength = clampf(value, 0.0, 1.0)
	pinch_strength_changed.emit(_current_strength)

	if !_pinching:
		# started pinching?
		if 0.75 < value:
			_pinching = true
			_timestamp_when_pinch_detected = Time.get_ticks_msec()
			_pinching_held_timer.start(pinch_held_duration)
		return

	# stopped pinching?
	if value < 0.35:
		_end_pinch()


func _on_button_pressed(action_name: String) -> void:
	if not _is_pinch_button_action(action_name):
		return
	if not _pinching:
		_current_strength = 1.0
		pinch_strength_changed.emit(1.0)
		_pinching = true
		_timestamp_when_pinch_detected = Time.get_ticks_msec()
		_pinching_held_timer.start(pinch_held_duration)


func _on_button_released(action_name: String) -> void:
	if not _is_pinch_button_action(action_name):
		return
	if _pinching:
		_end_pinch()


func _end_pinch() -> void:
	_is_latching = false
	_pinching = false
	_current_strength = 0.0
	pinch_strength_changed.emit(0.0)
	pinch_latching.emit(0.0)
	_pinching_held_timer.stop()

	# don't emit pinch-tap if pinch-held was already emitted
	if _pinching_held:
		_pinching_held = false
	# emit pinch-tap if was released fast enough
	elif Time.get_ticks_msec() - _timestamp_when_pinch_detected < pinch_tap_duration:
		pinch_tapped.emit()

	pinch_released.emit()


func _end_secondary_pinch() -> void:
	_sec_pinching = false
	_sec_current_strength = 0.0
	secondary_pinch_strength_changed.emit(0.0)

	if _sec_pinching_held:
		_sec_pinching_held = false
	elif Time.get_ticks_msec() - _sec_timestamp_when_pinch_detected < pinch_tap_duration:
		secondary_pinch_tapped.emit()

	secondary_pinch_released.emit()


func _on_timer_timeout() -> void:
	_pinching_held = true
	pinch_held.emit()
