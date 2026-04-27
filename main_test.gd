extends Node3D
@export var time : int
@onready var timer = $Timer
@onready var timer_label = $BasePersonnage/CharacterUi/ClockPanel/ClockLabel

func _process(delta: float) -> void:
	
	timer_label.text = str(int(timer.time_left))
	var cadran = 360/time
	if timer.is_stopped() == false :
		$LaunchButton.disabled = true
		$LaunchButton/FkgOz98xeai8Ok82.rotate(deg_to_rad(delta*cadran))
	else : 
		$LaunchButton.disabled = false


func _on_launch_button_pressed() -> void:
	timer.wait_time = float(time)
	timer.start()
