extends Node3D
@onready var timer = $RigidBody3D/Timer

func _ready() -> void:
	timer.start()
	
