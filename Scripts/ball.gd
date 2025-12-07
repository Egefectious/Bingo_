extends RigidBody3D
class_name BallEnhanced

@export var ball_id: String = ""
@export var type_id: String = "ball_standard"

@onready var mesh: MeshInstance3D = $MeshInstance3D

var current_state: int = 0  # 0=free, 1=dragging, 2=placed
var current_slot_ref = null

# Label is now embedded in the ball material
var label_texture: ImageTexture = null

func _ready() -> void:
	add_to_group("Balls")
	
	# Physics setup
	axis_lock_linear_y = true
	axis_lock_angular_x = true
	axis_lock_angular_z = true
	linear_damp = 5.0
	mass = 1.0
	
	if ball_id == "":
		visible = false
		freeze = true
	else:
		setup_ball(ball_id, type_id)

func setup_ball(new_id: String, new_type: String) -> void:
	ball_id = new_id
	type_id = new_type
	visible = true
	freeze = false
	sleeping = false
	
	_update_appearance()

func _update_appearance() -> void:
	"""Create ball material with embedded text"""
	if not mesh: return
	
	var data = BallDatabase.get_data(type_id)
	var base_color = data["visual_color"]
	
	# Create material
	var mat = StandardMaterial3D.new()
	mat.albedo_color = base_color
	
	# Emission based on rarity
	mat.emission_enabled = true
	mat.emission = base_color * 1.5
	
	match data["rarity"]:
		"mortal":
			mat.emission_energy_multiplier = 0.5
			mat.metallic = 0.2
			mat.roughness = 0.6
		
		"blessed":
			mat.emission_energy_multiplier = 2.0
			mat.metallic = 0.4
			mat.roughness = 0.4
			_add_pulse_animation(1.0)
		
		"divine":
			mat.emission_energy_multiplier = 3.0
			mat.metallic = 0.6
			mat.roughness = 0.3
			mat.clearcoat_enabled = true
			mat.clearcoat = 0.5
			_add_pulse_animation(1.5)
		
		"godly":
			mat.emission_energy_multiplier = 5.0
			mat.metallic = 0.8
			mat.roughness = 0.2
			mat.clearcoat_enabled = true
			mat.clearcoat = 1.0
			mat.grow_enabled = true
			mat.grow_amount = 0.05
			_add_pulse_animation(2.0)
	
	# Rim lighting
	mat.rim_enabled = true
	mat.rim = 0.5
	mat.rim_tint = 0.3
	
	# Create text texture
	_create_text_label(mat)
	
	mesh.material_override = mat

func _create_text_label(material: StandardMaterial3D) -> void:
	"""Create a label that wraps around the ball"""
	# Get the existing Label3D child if it exists
	var label = get_node_or_null("Label3D")
	
	if not label:
		label = Label3D.new()
		add_child(label)
		label.name = "Label3D"
	
	# Configure label
	var data = BallDatabase.get_data(type_id)
	
	# Determine text
	var text = ball_id
	if data["tags"].has("wild"):
		text = "WILD"
	
	label.text = text
	label.font_size = 64
	label.pixel_size = 0.0025  # Smaller to fit ball better
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.position = Vector3(0, 0, 0)
	
	# Color based on letter
	var letter_color = Color.WHITE
	if ball_id.length() > 0:
		match ball_id[0]:
			"L": letter_color = Color(1.0, 0.2, 0.8) # Pink
			"I": letter_color = Color(0.2, 0.8, 1.0) # Cyan
			"M": letter_color = Color(0.2, 1.0, 0.4) # Green
			"B": letter_color = Color(0.8, 0.2, 1.0) # Purple
			"O": letter_color = Color(1.0, 0.6, 0.0) # Orange
	
	# INVERTED COLORS FOR READABILITY
	label.modulate = Color.BLACK           # Text is Black
	label.outline_modulate = letter_color  # Outline is Colored
	label.outline_size = 12                # Thicker outline

func _add_pulse_animation(intensity: float) -> void:
	"""Add subtle pulsing animation"""
	var tween = create_tween().set_loops()
	var base_scale = Vector3.ONE
	var pulse_scale = Vector3.ONE * (1.0 + 0.05 * intensity)
	
	tween.tween_property(mesh, "scale", pulse_scale, 0.8 + randf() * 0.4).set_trans(Tween.TRANS_SINE)
	tween.tween_property(mesh, "scale", base_scale, 0.8 + randf() * 0.4).set_trans(Tween.TRANS_SINE)

# ========================================
# DRAG AND DROP
# ========================================

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
	tween.tween_property(self, "global_position", pos, 0.15).set_trans(Tween.TRANS_BACK)

func release_from_slot() -> void:
	current_state = 0
	current_slot_ref = null
	freeze = false
	sleeping = false
