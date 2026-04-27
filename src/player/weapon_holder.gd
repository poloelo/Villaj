extends Node3D

@export var weapon: PackedScene
@onready var current_weapon: Node3D

func _ready() -> void:
	if not weapon:
		print("Erreur : Aucune scène d'arme assignée au porte-armes.")
		return

	var instance = weapon.instantiate()
	if not instance:
		print("Erreur : Impossible d'instancier l'arme.")
		return
	add_child(instance)
	current_weapon = instance
	print("Arme instanciée avec succès :", instance)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("attack"):
		if current_weapon and current_weapon.has_method("shoot"):
			var raycast = $"../../Pivot/x_pivot/Camera3D/RayCast3D"
			if raycast:
				current_weapon.shoot(raycast)
			else:
				print("RayCast3D introuvable.")
		else:
			print("current_weapon est null ou n'a pas la méthode 'shoot'.")
