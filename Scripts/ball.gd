extends RigidBody3D
class_name BallV4

@export var ball_id: String = ""
@export var type_id: String = "ball_standard"

@onready var label: Label3D = $Label3D 
@onready var mesh: MeshInstance3D = $MeshInstance3D

var current_state: int = 0
var current_slot_ref = null

func _ready() -> void:
	add_to_group("Balls") 
	axis_lock_linear_y = true
	axis_lock_angular_x = true
	axis_lock_angular_z = true
	linear_damp = 5.0
	mass = 1.0
	setup_ball(ball_id, type_id)
	if ball_id == "":
		visible = false
		freeze = true
	else:
		setup_ball(ball_id, type_id)

func setup_ball(new_id, type):
	ball_id = new_id
	type_id = type
	visible = true
	freeze = false
	sleeping = false
	update_visuals()

func update_visuals() -> void:
	if not label or not mesh: return
	
	if ball_id == "": 
		return
	
	var data = BallDatabase.get_data(type_id)
	
	# LIMBO COLOR SCHEME - Updated for neon tavern aesthetic
	var letter_color = Color.BLACK
	match ball_id[0]:
		"L": letter_color = Color(0.8, 0.2, 1.0) # Bright Purple
		"I": letter_color = Color(0.4, 0.0, 0.8) # Deep Indigo
		"M": letter_color = Color(1.0, 0.2, 0.6) # Hot Magenta
		"B": letter_color = Color(0.2, 0.4, 1.0) # Electric Blue
		"O": letter_color = Color(1.0, 0.6, 0.0) # Warm Orange
	
	label.text = ball_id
	if data["tags"].has("wild"): label.text = "WILD"
	
	label.font_size = 96
	label.pixel_size = 0.003
	label.outline_size = 24
	label.outline_modulate = Color.BLACK
	label.no_depth_test = true
	
	# === UPGRADED MATERIAL SYSTEM ===
	var mat = StandardMaterial3D.new()
	var base_col = data["visual_color"]
	
	# --- STANDARD BALLS: Subtle Glow ---
	if type_id == "ball_standard":
		mat.albedo_color = base_col
		
		# Enable subtle emission
		mat.emission_enabled = true
		mat.emission = base_col * 0.8
		mat.emission_energy_multiplier = 0.5
		
		# Add rim lighting for depth
		mat.rim_enabled = true
		mat.rim = 0.4
		mat.rim_tint = 0.3
		
		mat.roughness = 0.5
		mat.metallic = 0.2
		
		label.modulate = letter_color
		label.outline_modulate = Color.BLACK
	
	# --- SPECIAL BALLS: Enhanced Effects ---
	else:
		# Make the ball itself glow
		mat.albedo_color = base_col
		mat.emission_enabled = true
		mat.emission = base_col * 1.5
		mat.emission_energy_multiplier = 2.0
		
		# Strong rim lighting
		mat.rim_enabled = true
		mat.rim = 0.8
		mat.rim_tint = 0.5
		
		# Slight metallic sheen
		mat.metallic = 0.4
		mat.roughness = 0.3
		
		# Label styling based on ball type
		if type_id in ["ball_red", "ball_blue", "ball_green", "ball_wild"]:
			label.modulate = Color.WHITE
			label.outline_modulate = base_col * 0.5
		else:
			label.modulate = base_col
			label.outline_modulate = Color.WHITE
	
	# --- RARITY-BASED ENHANCEMENTS ---
	match data["rarity"]:
		"blessed":
			mat.emission_energy_multiplier = 2.5
			mat.metallic = 0.5
			mat.rim = 0.9
			# Add pulsing effect
			_add_pulse_animation(mesh)
			
		"divine":
			mat.emission_energy_multiplier = 4.0
			mat.metallic = 0.7
			mat.roughness = 0.2
			mat.rim = 1.2
			# Add sparkle shader effect
			mat.clearcoat_enabled = true
			mat.clearcoat = 0.5
			_add_pulse_animation(mesh, 1.5)
			
		"godly":
			# Ultra bright HDR emission
			mat.emission_energy_multiplier = 6.0
			mat.metallic = 0.9
			mat.roughness = 0.1
			mat.rim = 1.5
			mat.clearcoat_enabled = true
			mat.clearcoat = 1.0
			mat.grow_enabled = true
			mat.grow_amount = 0.05
			# Intense pulsing
			_add_pulse_animation(mesh, 2.0)
	
	mesh.material_override = mat

# Add subtle pulsing animation to special balls
func _add_pulse_animation(target_mesh: MeshInstance3D, intensity: float = 1.0) -> void:
	var tween = create_tween().set_loops()
	var base_scale = Vector3.ONE
	var pulse_scale = Vector3.ONE * (1.0 + 0.05 * intensity)
	
	tween.tween_property(target_mesh, "scale", pulse_scale, 0.8 + randf() * 0.4).set_trans(Tween.TRANS_SINE)
	tween.tween_property(target_mesh, "scale", base_scale, 0.8 + randf() * 0.4).set_trans(Tween.TRANS_SINE)

# Drag and Drop logic remains identical
func start_drag() -> void:
	current_state = 1
	current_slot_ref = null 
	sleeping = false
	freeze = true 

func end_drag() -> void:
	if current_state == 1:
		current_state = 0
		freeze = false 

func snap_to_slot(pos: Vector3, slot_node) -> void:
	current_state = 2
	current_slot_ref = slot_node 
	freeze = true
	var tween = create_tween()
	tween.tween_property(self, "global_position", pos, 0.15)
	
func release_from_slot() -> void:
	current_state = 0
	current_slot_ref = null 
	freeze = false
	sleeping = false
