extends Node3D

@export var mouse_sensitivity: float = 30.0
@export var min_pitch: float = -45.0
@export var max_pitch: float = 60.0
@export var smoothing_speed: float = 25.0
# Lissage de la position pour éviter le jitter (0 = collé, 20 = très lisse)
@export var position_smoothing: float = 15.0

@onready var character: CharacterBody3D = $"../CharacterBody3D"
@onready var x_pivot: Node3D = $x_pivot

var _target_yaw: float = 0.0
var _target_pitch: float = 0.0
var _current_yaw: float = 0.0
var _current_pitch: float = 0.0
var _smoothed_position: Vector3 = Vector3.ZERO

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	# Initialise la position pour éviter un jump au premier frame
	_smoothed_position = character.global_position + Vector3(0.0, 0.3, 0.0)
	global_position = _smoothed_position

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
				Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
			else:
				Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		return

	if not event is InputEventMouseMotion:
		return
	if Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
		return

	var sensitivity := mouse_sensitivity * 0.001
	_target_yaw   -= event.relative.x * sensitivity
	_target_pitch  = clamp(
		_target_pitch - event.relative.y * sensitivity,
		deg_to_rad(min_pitch),
		deg_to_rad(max_pitch)
	)

func _process(delta: float) -> void:
	var target_pos := character.global_position + Vector3(0.0, 0.3, 0.0)
	_smoothed_position = _smoothed_position.lerp(target_pos, clamp(position_smoothing * delta, 0.0, 1.0))
	global_position = _smoothed_position

	var t: float = clamp(smoothing_speed * delta, 0.0, 1.0)
	_current_yaw   = lerpf(_current_yaw,   _target_yaw,   t)
	_current_pitch = lerpf(_current_pitch, _target_pitch, t)

	# Yaw sur le parent (rotation horizontale)
	rotation.y = _current_yaw
	# Pitch aussi sur le parent mais sur X (rotation verticale)
	rotation.x = -_current_pitch
