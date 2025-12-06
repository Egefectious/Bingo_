extends Node

var pool: Array[GPUParticles3D] = []
var pool_size: int = 40  # Increased for more simultaneous effects

func _ready() -> void:
	# Create particle pool
	for i in range(pool_size):
		var p = GPUParticles3D.new()
		p.emitting = false
		p.one_shot = true
		p.amount = 30
		p.lifetime = 1.5
		p.explosiveness = 0.9
		p.visibility_aabb = AABB(Vector3(-2, -2, -2), Vector3(4, 4, 4))
		
		# === ENHANCED MATERIAL ===
		var mat = ParticleProcessMaterial.new()
		
		# Emission shape - sphere burst
		mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		mat.emission_sphere_radius = 0.15
		
		# Spread & velocity
		mat.spread = 180.0
		mat.flatness = 0.3  # Some vertical bias
		mat.initial_velocity_min = 2.0
		mat.initial_velocity_max = 5.0
		
		# Physics
		mat.gravity = Vector3(0, -8, 0)
		mat.damping_min = 1.5
		mat.damping_max = 3.0
		
		# === COLOR GRADIENT (Yellow → Orange → Red → Fade) ===
		var gradient = Gradient.new()
		gradient.add_point(0.0, Color(1.0, 1.0, 0.5, 1.0))   # Bright yellow
		gradient.add_point(0.3, Color(1.0, 0.7, 0.2, 1.0))   # Orange
		gradient.add_point(0.6, Color(1.0, 0.3, 0.1, 0.8))   # Red-orange
		gradient.add_point(1.0, Color(0.8, 0.1, 0.0, 0.0))   # Dark red fade
		mat.color_ramp = gradient
		
		# === SIZE CURVE (Start big, shrink to nothing) ===
		var size_curve = Curve.new()
		size_curve.add_point(Vector2(0.0, 1.2))  # Start large
		size_curve.add_point(Vector2(0.5, 0.8))  # Maintain
		size_curve.add_point(Vector2(1.0, 0.0))  # Fade to nothing
		mat.scale_curve = size_curve
		
		# Turbulence for swirly motion
		mat.turbulence_enabled = true
		mat.turbulence_noise_strength = 2.0
		mat.turbulence_noise_scale = 3.0
		mat.turbulence_influence_min = 0.1
		mat.turbulence_influence_max = 0.3
		
		p.process_material = mat
		
		# === MESH (Sphere for round particles) ===
		var sphere = SphereMesh.new()
		sphere.radius = 0.08
		sphere.height = 0.16
		p.draw_pass_1 = sphere
		
		add_child(p)
		p.global_position = Vector3(0, -100, 0)  # Hide offscreen
		pool.append(p)

func play_pop_at(pos: Vector3, scale_factor: float = 1.0) -> void:
	"""Play a particle burst at position with size scaling"""
	for p in pool:
		if not p.emitting:
			p.global_position = pos
			p.amount = int(30 * scale_factor)
			p.scale = Vector3.ONE * scale_factor
			
			# Adjust velocity for bigger pops
			var mat = p.process_material as ParticleProcessMaterial
			if mat:
				mat.initial_velocity_max = 5.0 * scale_factor
			
			p.emitting = true
			return

func play_line_explosion(start_pos: Vector3, end_pos: Vector3) -> void:
	"""Create particles along a line (for LIMBO wins)"""
	var steps = 10
	for i in range(steps):
		var t = float(i) / float(steps)
		var pos = start_pos.lerp(end_pos, t)
		
		# Stagger the bursts
		await get_tree().create_timer(0.05).timeout
		play_pop_at(pos, 1.5)

func play_perfect_burst(pos: Vector3) -> void:
	"""Special effect for perfect matches"""
	# Triple burst with increasing size
	for i in range(3):
		play_pop_at(pos + Vector3(randf_range(-0.3, 0.3), 0, randf_range(-0.3, 0.3)), 1.0 + i * 0.5)
		await get_tree().create_timer(0.1).timeout

func play_essence_sparkle(pos: Vector3) -> void:
	"""Cyan sparkle effect when essence is gained"""
	for p in pool:
		if not p.emitting:
			p.global_position = pos
			p.amount = 20
			
			# Override color to cyan temporarily
			var mat = p.process_material as ParticleProcessMaterial
			if mat:
				var temp_gradient = Gradient.new()
				temp_gradient.add_point(0.0, Color(0.2, 1.0, 1.0, 1.0))  # Cyan
				temp_gradient.add_point(0.5, Color(0.4, 0.8, 1.0, 0.8))  # Light blue
				temp_gradient.add_point(1.0, Color(0.2, 0.4, 0.8, 0.0))  # Fade
				mat.color_ramp = temp_gradient
			
			p.emitting = true
			
			# Reset gradient after particle finishes
			await get_tree().create_timer(1.5).timeout
			if mat:
				var default_gradient = Gradient.new()
				default_gradient.add_point(0.0, Color(1.0, 1.0, 0.5, 1.0))
				default_gradient.add_point(0.3, Color(1.0, 0.7, 0.2, 1.0))
				default_gradient.add_point(0.6, Color(1.0, 0.3, 0.1, 0.8))
				default_gradient.add_point(1.0, Color(0.8, 0.1, 0.0, 0.0))
				mat.color_ramp = default_gradient
			return
