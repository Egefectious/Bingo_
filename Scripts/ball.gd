extends RigidBody3D
class_name BallEnhanced

@export var ball_id: String = ""
@export var type_id: String = "ball_standard"

@onready var mesh: MeshInstance3D = $MeshInstance3D

var current_state: int = 0  # 0=free, 1=dragging, 2=placed
var current_slot_ref = null

# Visual components
var inner_glow: MeshInstance3D = null
var particle_trail: GPUParticles3D = null
var aura_light: OmniLight3D = null

func _ready() -> void:
	add_to_group("Balls")
	
	# Physics setup
	axis_lock_linear_y = true
	axis_lock_angular_x = true
	axis_lock_angular_z = true
	linear_damp = 5.0
	angular_damp = 3.0
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
	"""Create modern ball material"""
	if not mesh: return
	
	var data = BallDatabase.get_data(type_id)
	var base_color = data["visual_color"]
	var rarity = data["rarity"]
	
	# Outer shell
	var mat = StandardMaterial3D.new()
	mat.albedo_color = base_color
	mat.metallic = 0.7
	mat.roughness = 0.3
	
	# Emission glow
	mat.emission_enabled = true
	mat.emission = base_color.lightened(0.3)
	
	match rarity:
		"mortal":
			mat.emission_energy_multiplier = 1.0
			mat.metallic = 0.5
		
		"blessed":
			mat.emission_energy_multiplier = 2.5
			mat.metallic = 0.7
			mat.rim_enabled = true
			mat.rim = 0.5
			_add_glow_layers(base_color, 1.5)
		
		"divine":
			mat.emission_energy_multiplier = 4.0
			mat.metallic = 0.85
			mat.rim_enabled = true
			mat.rim = 1.0
			mat.rim_tint = 0.5
			mat.clearcoat_enabled = true
			mat.clearcoat = 0.8
			_add_glow_layers(base_color, 2.5)
			_add_particle_trail(base_color)
		
		"godly":
			mat.emission_energy_multiplier = 8.0
			mat.metallic = 0.95
			mat.roughness = 0.1
			mat.rim_enabled = true
			mat.rim = 1.0
			mat.clearcoat_enabled = true
			mat.clearcoat = 1.0
			mat.refraction_enabled = true
			mat.refraction_scale = 0.1
			_add_glow_layers(base_color, 4.0)
			_add_particle_trail(base_color)
			_add_aura_light(base_color)
	
	mesh.material_override = mat
	
	# Add label
	_create_text_label(base_color)
	
	# Spin animation
	_add_spin_animation(rarity)

func _add_glow_layers(color: Color, intensity: float) -> void:
	"""Add inner glow shell"""
	if not inner_glow:
		inner_glow = MeshInstance3D.new()
		add_child(inner_glow)
		inner_glow.name = "InnerGlow"
	
	var glow_mesh = SphereMesh.new()
	glow_mesh.radius = 0.28
	glow_mesh.height = 0.56
	inner_glow.mesh = glow_mesh
	
	var glow_mat = StandardMaterial3D.new()
	glow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow_mat.albedo_color = Color(color.r, color.g, color.b, 0.4)
	glow_mat.emission_enabled = true
	glow_mat.emission = color * 2.0
	glow_mat.emission_energy_multiplier = intensity
	glow_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	glow_mat.cull_mode = BaseMaterial3D.CULL_FRONT
	inner_glow.material_override = glow_mat
	
	# Pulse animation
	var tween = create_tween().set_loops()
	tween.tween_property(inner_glow, "scale", Vector3.ONE * 1.15, 1.0).set_trans(Tween.TRANS_SINE)
	tween.tween_property(inner_glow, "scale", Vector3.ONE * 0.95, 1.0).set_trans(Tween.TRANS_SINE)

func _add_particle_trail(color: Color) -> void:
	"""Add particle trail for high rarity balls"""
	if not particle_trail:
		particle_trail = GPUParticles3D.new()
		add_child(particle_trail)
		particle_trail.name = "ParticleTrail"
	
	particle_trail.amount = 20
	particle_trail.lifetime = 0.8
	particle_trail.emitting = true
	particle_trail.explosiveness = 0.0
	particle_trail.visibility_aabb = AABB(Vector3(-1, -1, -1), Vector3(2, 2, 2))
	
	var mat = ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 0.1
	mat.gravity = Vector3(0, -2, 0)
	mat.initial_velocity_min = 0.5
	mat.initial_velocity_max = 1.0
	mat.damping_min = 3.0
	mat.damping_max = 5.0
	
	# Color gradient
	var gradient = Gradient.new()
	gradient.add_point(0.0, color)
	gradient.add_point(1.0, Color(color.r, color.g, color.b, 0.0))
	mat.color_ramp = gradient
	
	# Size curve
	var size_curve = Curve.new()
	size_curve.add_point(Vector2(0.0, 0.5))
	size_curve.add_point(Vector2(1.0, 0.0))
	mat.scale_curve = size_curve
	
	particle_trail.process_material = mat
	
	var sphere = SphereMesh.new()
	sphere.radius = 0.05
	sphere.height = 0.1
	particle_trail.draw_pass_1 = sphere

func _add_aura_light(color: Color) -> void:
	"""Add omni light for godly balls"""
	if not aura_light:
		aura_light = OmniLight3D.new()
		add_child(aura_light)
		aura_light.name = "AuraLight"
	
	aura_light.light_color = color
	aura_light.light_energy = 4.0
	aura_light.omni_range = 2.0
	aura_light.omni_attenuation = 2.0
	
	# Pulse animation
	var tween = create_tween().set_loops()
	tween.tween_property(aura_light, "light_energy", 6.0, 0.8).set_trans(Tween.TRANS_SINE)
	tween.tween_property(aura_light, "light_energy", 2.0, 0.8).set_trans(Tween.TRANS_SINE)

func _create_text_label(base_color: Color) -> void:
	"""Create number label"""
	var label = Label3D.new()
	add_child(label)
	label.name = "NumberLabel"
	
	var data = BallDatabase.get_data(type_id)
	
	# Determine text
	var text = ball_id
	if data["tags"].has("wild"):
		text = "★"
	
	label.text = text
	label.font_size = 72
	label.pixel_size = 0.0025
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.position = Vector3(0, 0, 0)
	
	# Color based on letter
	var letter_color = Color.WHITE
	if ball_id.length() > 0:
		match ball_id[0]:
			"L": letter_color = Color(1.0, 0.2, 0.8)
			"I": letter_color = Color(0.2, 0.8, 1.0)
			"M": letter_color = Color(0.2, 1.0, 0.4)
			"B": letter_color = Color(0.8, 0.2, 1.0)
			"O": letter_color = Color(1.0, 0.6, 0.0)
	
	# High contrast text
	label.modulate = Color.WHITE
	label.outline_modulate = letter_color.darkened(0.5)
	label.outline_size = 16

func _add_spin_animation(rarity: String) -> void:
	"""Add rotation animation"""
	var speed = 1.0
	
	match rarity:
		"blessed": speed = 1.5
		"divine": speed = 2.0
		"godly": speed = 3.0
	
	var tween = create_tween().set_loops()
	tween.tween_property(mesh, "rotation_degrees:y", 360.0, 4.0 / speed).from(0.0)

# ========================================
# DRAG AND DROP
# ========================================

func start_drag() -> void:
	current_state = 1
	current_slot_ref = null
	sleeping = false
	freeze = true
	
	# Visual feedback
	var tween = create_tween()
	tween.tween_property(mesh, "scale", Vector3.ONE * 1.2, 0.1).set_trans(Tween.TRANS_BACK)

func end_drag() -> void:
	if current_state == 1:
		current_state = 0
		freeze = false
		
		var tween = create_tween()
		tween.tween_property(mesh, "scale", Vector3.ONE, 0.2).set_trans(Tween.TRANS_ELASTIC)

func snap_to_slot(pos: Vector3, slot_node) -> void:
	current_state = 2
	current_slot_ref = slot_node
	freeze = true
	
	var tween = create_tween()
	tween.tween_property(self, "global_position", pos, 0.2).set_trans(Tween.TRANS_BACK)
	tween.parallel().tween_property(mesh, "scale", Vector3.ONE, 0.2).set_trans(Tween.TRANS_ELASTIC)

func release_from_slot() -> void:
	current_state = 0
	current_slot_ref = null
	freeze = false
	sleeping = false
