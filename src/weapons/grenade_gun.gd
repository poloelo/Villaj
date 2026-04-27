extends Node3D
class_name Weapon

@export var ammo_scene : PackedScene

func shoot(raycast: RayCast3D) -> void:
	if not ammo_scene:
		print("Pas de scène de munition assignée !")
		return

	var ammo = ammo_scene.instantiate()

	# Calcule la direction de tir (devant la caméra)
	var shoot_dir = -raycast.global_transform.basis.y.normalized()
	var shoot_force = 10.0

	# Nouvelle position : point de départ + 1 mètre dans la direction de tir
	var start_pos = raycast.global_transform.origin + shoot_dir * 1.0

	# Place le node racine de la grenade à la bonne position
	ammo.global_transform.origin = start_pos
	get_tree().current_scene.add_child(ammo)

	# Trouve le RigidBody3D enfant
	var rigid: RigidBody3D = null
	for child in ammo.get_children():
		if child is RigidBody3D:
			rigid = child
			break

	if rigid == null:
		print("Aucun RigidBody3D trouvé dans la scène grenade !")
		return

	# Place le rigid exactement au même endroit que la racine, au cas où
	rigid.global_transform.origin = start_pos

	# Applique la vélocité
	rigid.linear_velocity = shoot_dir * shoot_force

	print("Grenade lancée 1m devant toi !")
