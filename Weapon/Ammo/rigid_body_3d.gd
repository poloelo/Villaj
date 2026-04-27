extends RigidBody3D

@export var explosion_delay := 5.0 # secondes avant explosion
@export var explosion_radius := 5.0 # rayon de l’explosion
@export var explosion_force := 25.0 # force de poussée
@export var explosion_damage := 100 # dégâts infligés

@onready var explosion_area := $Area3D

func _ready():
	# Démarre le timer d’explosion
	await get_tree().create_timer(explosion_delay).timeout
	explode()

func explode():
	
	# 2. Gameplay : dégâts et poussée dans la zone
	for body in explosion_area.get_overlapping_bodies():
		if body == self: continue
		if body.has_method("apply_damage"):
			body.apply_damage(explosion_damage)
		if body is RigidBody3D:
			var dir = (body.global_transform.origin - global_transform.origin).normalized()
			body.apply_impulse(dir * explosion_force)
	
	# 3. Effet sonore optionnel
	# $ExplosionSound.play()
	
	# 4. Supprime la grenade après explosion
	queue_free()
