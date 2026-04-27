extends CharacterBody3D
class_name Player

# ==============================================================================
# CONSTANTES
# ==============================================================================
const LANDING_SPEED_MODIFIER: float = 0.7 # Plus c'est bas, plus il est ralenti
const TRANSITION_SPEED: float = 15.0
const MAX_FALL_SPEED:    float = -30.0

# ==============================================================================
# PROPRIÉTÉS DU JOUEUR
# ==============================================================================
var vie: int = 100

# ==============================================================================
# PARAMÈTRES EXPOSÉS ÉDITEUR
# ==============================================================================
@export var speed: float = 1.0
@export var jump_count: int = 1
@export var jump_height: float = 5.0
@export var gravity_multiplier: float = 1.0
@export var sprint_speed_multiplier: float = 1.8
@export var crouch_speed_multiplier: float = 0.6

# ==============================================================================
# RÉFÉRENCES
# ==============================================================================
@onready var pivot: Node3D       = $"../Pivot"
@onready var camera: Camera3D    = $"../Pivot/x_pivot/Camera3D"
@onready var mesh_pointeur: Node3D = $Mesh_pointeur
@onready var anim_tree: AnimationTree = $Mesh/PF_PolygonPlayer/AnimationTree
@onready var ik: CCDIK3D = $Mesh/PF_PolygonPlayer/PolygonSyntyCharacter/Skeleton3D/CCDIK3D

# ==============================================================================
# VARIABLES INTERNES — ÉTAT
# ==============================================================================
var type_perso: String = "player"

var is_sprinting: bool = false
var is_crouching: bool = false
var is_aiming:    bool = false

var area_overlapping: RigidBody3D = null
var grabbed_object:   RigidBody3D = null
var jumps_remaining:  int = 0
var mouse_captured:   bool = true
var current_weapon:   String = "pistol"

# ==============================================================================
# VARIABLES INTERNES — MOUVEMENT
# ==============================================================================
var target_direction: Vector3 = Vector3.ZERO
var direction:        Vector3 = Vector3.ZERO

# ==============================================================================
# VARIABLES INTERNES — ANIMATIONS
# ==============================================================================
var _sm: AnimationNodeStateMachinePlayback
var _last_anim_state:  String = ""
var _was_in_air:       bool   = false
var _landing:          bool   = false
var _landing_timer:    float  = 0.0
const LANDING_DURATION: float = 0.2  # durée en secondes — ajuste selon ton anim

# ==============================================================================
# READY
# ==============================================================================
func _ready() -> void:
	global_transform.origin = Vector3(11, 11, 11)
	jumps_remaining = jump_count
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	_setup_ik()
	_setup_anim_tree()

func _setup_ik() -> void:
	if ik:
		ik.target_node = $"../Pivot/x_pivot/Camera3D/Pickup_Area/MeshInstance3D".get_path()
	else:
		push_warning("⚠️ [Player] CCDIK3D introuvable")

func _setup_anim_tree() -> void:
	if not anim_tree:
		push_error("❌ [Player] AnimationTree introuvable !")
		return

	anim_tree.active = true

	var sm_raw = anim_tree.get("parameters/StateMachine/playback")
	if sm_raw == null:
		push_error("❌ [Player] StateMachine playback introuvable.")
		return

	_sm = sm_raw

# ==============================================================================
# INPUT
# ==============================================================================
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("exit"):
		toggle_mouse_capture()
		get_viewport().set_input_as_handled()

	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if Input.is_action_just_pressed("grab") and area_overlapping is RigidBody3D:
			grabbed_object = area_overlapping
			grabbed_object.gravity_scale = 0.0
			grabbed_object.freeze = false
		if Input.is_action_just_released("grab") and grabbed_object:
			grabbed_object.gravity_scale = 1.0
			grabbed_object = null

	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and grabbed_object:
		grabbed_object.gravity_scale = 1.0
		grabbed_object = null


# ==============================================================================
# PHYSICS
# ==============================================================================
func _physics_process(delta: float) -> void:
	_update_ik_mesh()
	_update_state()
	handle_movement(delta)
	_handle_aiming()
	_interact()
	move_and_slide()

	_update_mesh_pointeur()
	_handle_grab(delta)
	_update_animations()

func _update_ik_mesh() -> void:
	var ik_target := $"../Pivot/x_pivot/Camera3D/Pickup_Area/MeshInstance3D" as Node3D
	if ik_target:
		$Mesh/PF_PolygonPlayer/MeshPointeur3.global_position = ik_target.global_position

func _update_mesh_pointeur() -> void:
	var offset := -camera.global_transform.basis.z.normalized() * 3.0
	mesh_pointeur.global_transform.origin = camera.global_transform.origin + offset

# ==============================================================================
# ÉTAT
# ==============================================================================
func _update_state() -> void:
	is_sprinting = (
		Input.is_action_pressed("sprint")
		and not is_crouching
		and not is_aiming
	)
	is_crouching = Input.is_action_pressed("crouch")
	is_aiming    = Input.is_action_pressed("aim")

# ==============================================================================
# MOUVEMENT
# ==============================================================================
func handle_movement(delta: float) -> void:
	if not mouse_captured:
		return

	_compute_direction(delta)
	_apply_speed()
	_handle_rotation(delta)
	_handle_jump()
	_apply_gravity(delta)

func _compute_direction(delta: float) -> void:
	var right   := pivot.transform.basis.x
	var forward := right.rotated(Vector3.UP, deg_to_rad(90))
	target_direction = Vector3.ZERO

	if Input.is_action_pressed("move_forward"):
		target_direction -= forward
	if Input.is_action_pressed("move_backward"):
		target_direction += forward
	if Input.is_action_pressed("move_right"):
		target_direction -= right
	if Input.is_action_pressed("move_left"):
		target_direction += right

	if target_direction.length() > 1.0:
		target_direction = target_direction.normalized()

	direction = direction.lerp(target_direction, TRANSITION_SPEED * delta)

func _apply_speed() -> void:
	var current_speed := speed
	
	if is_sprinting:
		current_speed *= sprint_speed_multiplier
	elif is_crouching:
		current_speed *= crouch_speed_multiplier

	# APPLIQUER LE RALENTISSEMENT À L'ATTERRISSAGE
	if _landing:
		current_speed *= LANDING_SPEED_MODIFIER

	velocity.x = direction.x * current_speed
	velocity.z = direction.z * current_speed
func _handle_rotation(delta: float) -> void:
	if direction != Vector3.ZERO and not is_aiming:
		var target_angle := atan2(-direction.x, -direction.z)
		rotation.y = lerp_angle(rotation.y, target_angle, TRANSITION_SPEED * delta)

func _handle_jump() -> void:
	if Input.is_action_just_pressed("jump") and jumps_remaining > 0:
		velocity.y = jump_height
		jumps_remaining -= 1

	if is_on_floor():
		jumps_remaining = jump_count
		if velocity.y < 0.0:
			velocity.y = 0.0
		# SUPPRIMÉ : velocity.x = 0 et velocity.z = 0 ici

func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y = maxf(velocity.y - 9.8 * gravity_multiplier * delta, MAX_FALL_SPEED)

func _handle_aiming() -> void:
	if not is_aiming:
		return
	var cam_forward := pivot.global_transform.basis.z
	cam_forward.y = 0.0
	if cam_forward.length_squared() < 0.001:
		return
	look_at(global_position + cam_forward.normalized(), Vector3.UP)

# ==============================================================================
# ANIMATIONS
# ==============================================================================
func _update_animations() -> void:
	if not _sm:
		return

	var on_floor := is_on_floor()
	var moving   := get_horizontal_velocity() > 0.1

	# Atterrissage en cours — on attend la fin du timer
	if _landing:
		_landing_timer -= get_physics_process_delta_time()
		if _landing_timer <= 0.0:
			_landing = false
		_was_in_air = not on_floor
		return

	var target_state: String

	if not on_floor:
		if velocity.y > 0.0:
			target_state = "A_Jump_Running_Masc"
		else:
			target_state = "A_InAir_FallShort_Masc"
	elif _was_in_air:
		_landing = true
		_landing_timer = LANDING_DURATION
		target_state = "A_Land_IdleMedium_Masc"
	elif is_crouching:
		target_state = "A_Crouch_FwdStrafeF_Masc" if moving else "A_Idle_Crouching_Masc"
	elif is_sprinting and moving:
		target_state = "A_Sprint_F_Masc"
	elif moving:
		target_state = "A_Run_F_Masc"
	else:
		target_state = "A_Idle_Standing_Masc"

	if target_state != _last_anim_state:
		_sm.travel(target_state)
		_last_anim_state = target_state

	_was_in_air = not on_floor

# ==============================================================================
# GRAB (style Half-Life)
# ==============================================================================
func _handle_grab(_delta: float) -> void:
	if not grabbed_object:
		return
	var to_target        := mesh_pointeur.global_transform.origin - grabbed_object.global_transform.origin
	var desired_velocity := to_target * 10.0
	grabbed_object.linear_velocity  = grabbed_object.linear_velocity.lerp(desired_velocity, 0.2)
	grabbed_object.angular_velocity = Vector3.ZERO

# ==============================================================================
# DÉTECTION OBJETS (signaux Area3D)
# ==============================================================================
func _on_pickup_area_body_entered(body: Node3D) -> void:
	if body is RigidBody3D:
		area_overlapping = body

func _on_pickup_area_body_exited(body: Node3D) -> void:
	if area_overlapping == body:
		area_overlapping = null

# ==============================================================================
# INTERACTION
# ==============================================================================
func _interact() -> void:
	if Input.is_action_just_pressed("attack") and area_overlapping != null:
		if area_overlapping.get_parent().has_method("toggle"):
			area_overlapping.get_parent().toggle()

# ==============================================================================
# UTILITAIRES
# ==============================================================================
func toggle_mouse_capture() -> void:
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		mouse_captured = false
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		mouse_captured = true
		
func get_type_perso() -> String:
	return "player"

func get_horizontal_velocity() -> float:
	return Vector3(velocity.x, 0.0, velocity.z).length()
