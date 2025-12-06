extends Area3D
class_name SlotEnhanced

@export var grid_x: int = -1
@export var grid_y: int = -1
@export var target_id: String = ""

var held_ball: RigidBody3D = null
var is_bench_slot: bool = false

# Upgrades
var permanent_bonus: int = 0
var permanent_multiplier: float = 1.0
var line_bonus: int = 0

# Visual components
@onready var base_mesh: MeshInstance3D = $BaseMesh
@onready var rim_mesh: MeshInstance3D = $RimMesh
var number_label: Label3D = null

func _ready() -> void:
	add_to_group("Slots")
	monitoring = true
	monitorable = true
	collision_mask = 2
	
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	_create_visuals()

func setup_slot(new_id: String, x: int, y: int) -> void:
	target_id = new_id
	grid_x = x
	grid_y = y
	
	if new_id == "BENCH":
		is_bench_slot = true
		if rim_mesh: rim_mesh.visible = false
		if number_label: number_label.visible = false
	else:
		is_bench_slot = false
		_update_label()

func refresh_id(new_id: String) -> void:
	target_id = new_id
	_update_label()

func update_indicator() -> void:
	_update_label()
	_update_visuals()

# ========================================
# VISUALS
# ========================================

func _create_visuals() -> void:
	"""Create the slot appearance"""
	# Base (recessed surface)
	if not base_mesh:
		base_mesh = MeshInstance3D.new()
		add_child(base_mesh)
		base_mesh.name = "BaseMesh"
	
	var base = BoxMesh.new()
	base.size = Vector3(1.0, 0.05, 1.0)
	base_mesh.mesh = base
	base_mesh.position = Vector3(0, -0.025, 0)
	
	var base_mat = StandardMaterial3D.new()
	base_mat.albedo_color = Color(0.1, 0.07, 0.05)  # Dark wood
	base_mat.roughness = 0.8
	base_mat.metallic = 0.1
	base_mat.emission_enabled = true
	base_mat.emission = Color(0.08, 0.05, 0.03)
	base_mat.emission_energy_multiplier = 0.3
	base_mesh.material_override = base_mat
	
	# Rim (glowing border)
	if not rim_mesh:
		rim_mesh = MeshInstance3D.new()
		add_child(rim_mesh)
		rim_mesh.name = "RimMesh"
	
	var rim = BoxMesh.new()
	rim.size = Vector3(1.05, 0.03, 1.05)
	rim_mesh.mesh = rim
	rim_mesh.position = Vector3(0, 0, 0)
	
	var rim_mat = StandardMaterial3D.new()
	rim_mat.albedo_color = Color(0.3, 0.2, 0.15)
	rim_mat.metallic = 0.7
	rim_mat.roughness = 0.3
	rim_mat.emission_enabled = true
	rim_mat.emission = Color(1.0, 0.6, 0.2)
	rim_mat.emission_energy_multiplier = 1.0
	rim_mesh.material_override = rim_mat
	
	# Collision shape
	var collision = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(1.1, 0.3, 1.1)
	collision.shape = shape
	collision.position = Vector3(0, 0.15, 0)
	add_child(collision)
	
	# Number label
	_create_label()

func _create_label() -> void:
	"""Create number display"""
	if not number_label:
		number_label = Label3D.new()
		add_child(number_label)
	
	number_label.position = Vector3(0, 0.08, 0)
	number_label.rotation_degrees.x = -90
	number_label.font_size = 72
	number_label.pixel_size = 0.004
	number_label.outline_size = 8
	number_label.outline_modulate = Color.BLACK
	number_label.no_depth_test = true

func _update_label() -> void:
	"""Update the number display"""
	if not number_label or target_id == "": return
	
	var parts = target_id.split("-")
	var display_text = ""
	
	if parts.size() > 1:
		display_text = parts[1]  # Just the number
	else:
		display_text = target_id
	
	# Add upgrade indicators
	if permanent_multiplier > 1.0:
		display_text += "\n×" + str(permanent_multiplier)
	elif permanent_bonus > 0:
		display_text += "\n+" + str(permanent_bonus)
	elif line_bonus > 0:
		display_text += "\nL+" + str(line_bonus)
	
	number_label.text = display_text
	
	# Color based on upgrades
	if permanent_multiplier > 1.0:
		number_label.modulate = Color.GOLD
		number_label.outline_modulate = Color(0.3, 0.2, 0.0)
	elif permanent_bonus > 0 or line_bonus > 0:
		number_label.modulate = Color(0.4, 1.0, 0.4)
		number_label.outline_modulate = Color(0.0, 0.2, 0.0)
	else:
		number_label.modulate = Color.WHITE
		number_label.outline_modulate = Color.BLACK

func _update_visuals() -> void:
	"""Update colors based on upgrades"""
	if not base_mesh or not rim_mesh: return
	
	var base_mat = base_mesh.material_override
	var rim_mat = rim_mesh.material_override
	
	if permanent_multiplier > 1.0:
		# Gold glow for multipliers
		base_mat.albedo_color = Color(0.2, 0.15, 0.05)
		base_mat.emission = Color(0.4, 0.3, 0.1)
		base_mat.emission_energy_multiplier = 0.8
		
		rim_mat.emission = Color(1.0, 0.8, 0.0)
		rim_mat.emission_energy_multiplier = 2.0
		
	elif permanent_bonus > 0 or line_bonus > 0:
		# Green glow for bonuses
		base_mat.albedo_color = Color(0.05, 0.15, 0.08)
		base_mat.emission = Color(0.1, 0.3, 0.15)
		base_mat.emission_energy_multiplier = 0.6
		
		rim_mat.emission = Color(0.4, 1.0, 0.5)
		rim_mat.emission_energy_multiplier = 1.8
	else:
		# Default dark wood
		base_mat.albedo_color = Color(0.1, 0.07, 0.05)
		base_mat.emission = Color(0.08, 0.05, 0.03)
		base_mat.emission_energy_multiplier = 0.3
		
		rim_mat.emission = Color(1.0, 0.6, 0.2)
		rim_mat.emission_energy_multiplier = 1.0

# ========================================
# BALL MANAGEMENT
# ========================================

func assign_ball(ball: RigidBody3D) -> void:
	held_ball = ball
	if number_label:
		number_label.visible = false

func remove_ball() -> void:
	held_ball = null
	if number_label:
		number_label.visible = true

func is_available() -> bool:
	return held_ball == null

# ========================================
# HOVER EFFECTS
# ========================================

func _on_body_entered(body: Node3D) -> void:
	if body.get("current_state") == 1:  # Being dragged
		_set_highlight(true)

func _on_body_exited(body: Node3D) -> void:
	if body.has_method("start_drag"):
		_set_highlight(false)

func _set_highlight(active: bool) -> void:
	"""Highlight slot when ball is hovering"""
	if not rim_mesh or not rim_mesh.material_override: return
	
	# Don't override upgrade colors
	if permanent_multiplier > 1.0 or permanent_bonus > 0 or line_bonus > 0:
		return
	
	var rim_mat = rim_mesh.material_override
	
	if active:
		rim_mat.emission = Color(0.2, 0.8, 1.0)  # Cyan highlight
		rim_mat.emission_energy_multiplier = 2.5
	else:
		rim_mat.emission = Color(1.0, 0.6, 0.2)  # Default orange
		rim_mat.emission_energy_multiplier = 1.0
