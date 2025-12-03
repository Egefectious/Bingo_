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
		visible = false # Hide until properly setup
		freeze = true
	else:
		setup_ball(ball_id, type_id)

func setup_ball(new_id, type):
	ball_id = new_id
	type_id = type
	visible = true # Reveal when ready
	freeze = false
	sleeping = false
	update_visuals()

func update_visuals() -> void:
	if not label or not mesh: return
	
	if ball_id == "": 
		return
	
	var data = BallDatabase.get_data(type_id)
	
	# LIMBO COLOR SCHEME
	var letter_color = Color.BLACK
	match ball_id[0]:
		"L": letter_color = Color(0.6, 0.2, 0.8) # Purple
		"I": letter_color = Color(0.3, 0.0, 0.5) # Indigo/Dark Purple
		"M": letter_color = Color(0.8, 0.0, 0.4) # Magenta
		"B": letter_color = Color(0.0, 0.2, 0.8) # Blue
		"O": letter_color = Color(1.0, 0.5, 0.0) # Orange
	
	label.text = ball_id
	if data["tags"].has("wild"): label.text = "WILD"
	
	label.font_size = 96
	label.pixel_size = 0.003
	label.outline_size = 24
	label.outline_modulate = Color.BLACK
	label.no_depth_test = true
	
	var mat = StandardMaterial3D.new()
	var base_col = data["visual_color"]
	
	if type_id == "ball_standard":
		mat.albedo_color = base_col 
		label.modulate = letter_color 
	else:
		mat.albedo_color = base_col
		if type_id in ["ball_red", "ball_blue", "ball_green", "ball_wild"]:
			label.modulate = Color.WHITE
			label.outline_modulate = Color.BLACK
		else:
			label.modulate = Color.BLACK
			label.outline_modulate = Color.WHITE
		
	if data["rarity"] == "blessed":
		mat.emission_enabled = true
		mat.emission = base_col
		mat.emission_energy_multiplier = 0.2
	elif data["rarity"] == "divine" or data["rarity"] == "godly":
		mat.metallic = 1.0
		mat.roughness = 0.2
		mat.emission_enabled = true
		mat.emission = base_col
		mat.emission_energy_multiplier = 0.5
		
	mesh.material_override = mat

# ... Drag and Drop logic remains identical ...
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
