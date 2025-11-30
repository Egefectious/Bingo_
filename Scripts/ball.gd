extends RigidBody3D
class_name BallV4

# Defines the specific number (e.g. "B-5")
@export var ball_id: String = "B-5"
# Defines the special type (e.g. "ball_gold")
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

func setup_ball(new_id: String, new_type_id: String = "ball_standard") -> void:
	ball_id = new_id
	type_id = new_type_id
	update_visuals()

func update_visuals() -> void:
	if not label or not mesh: return
	
	# 1. Fetch Data from Database
	var data = BallDatabase.get_data(type_id)
	
	# 2. Determine Text Color based on Letter (Classic Bingo Look)
	var letter_color = Color.BLACK
	match ball_id[0]:
		"B": letter_color = Color(0.2, 0.6, 1.0) # Blue Text
		"I": letter_color = Color(0.9, 0.2, 0.2) # Red Text
		"N": letter_color = Color(0.2, 0.2, 0.2) # Black/Dark Gray Text
		"G": letter_color = Color(0.2, 0.8, 0.2) # Green Text
		"O": letter_color = Color(1.0, 0.6, 0.0) # Orange Text
	
	# 3. Label Settings
	label.text = ball_id
	if data["tags"].has("wild"): label.text = "WILD"
	
	label.font_size = 96
	label.pixel_size = 0.003
	label.outline_size = 24
	label.outline_modulate = Color.BLACK
	label.no_depth_test = true
	
	# 4. Apply Materials
	var mat = StandardMaterial3D.new()
	var base_col = data["visual_color"]
	
	# LOGIC CHANGE: 
	# Previously, we tinted the ball body by letter. 
	# Now, we use the Database color for the body, and Letter color for the text.
	
	if type_id == "ball_standard":
		# Standard balls = White/Cream Body + Colored Text
		mat.albedo_color = base_col # Uses the (0.9, 0.9, 0.9) from DB
		label.modulate = letter_color # Text gets the B/I/N/G/O color
	else:
		# Special balls = Colored Body + White/Black Text
		mat.albedo_color = base_col
		
		# For dark special balls (Red/Blue), make text White to pop
		# For bright special balls (Gold/Silver), make text Black
		if type_id in ["ball_red", "ball_blue", "ball_green", "ball_wild"]:
			label.modulate = Color.WHITE
			label.outline_modulate = Color.BLACK
		else:
			label.modulate = Color.BLACK
			label.outline_modulate = Color.WHITE
		
	# Special Shader Properties based on Rarity
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

# --- MOVEMENT LOGIC (Unchanged) ---
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
	current_state = 2 # SNAPPED
	current_slot_ref = slot_node 
	freeze = true
	var tween = create_tween()
	tween.tween_property(self, "global_position", pos, 0.15)
	
func release_from_slot() -> void:
	current_state = 0 # FREE
	current_slot_ref = null 
	freeze = false
	sleeping = false
