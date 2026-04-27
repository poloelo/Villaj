extends Control

@onready var player = $"../CharacterBody3D"

func _ready() -> void:
	self.hide()


func _on_pickup_area_body_entered(body: Node3D) -> void:
	if body.has_method("get") and body.get("item_name") != null:
		$Panel/Label.text = body.get("item_name")
		self.show()
	else:
		pass
		
func _on_pickup_area_body_exited(body: Node3D) -> void:
	self.hide()
	$Panel/Label.text = ""
