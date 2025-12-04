extends Node

var pool: Array[GPUParticles3D] = []
var pool_size: int = 30 # Increased for more particles

# Assign a "Score Pop" particle material in Inspector
var score_particle_material: ParticleProcessMaterial 
var score_mesh: QuadMesh # Or SphereMesh

func _ready() -> void:
	# Create hidden pool
	for i in range(pool_size):
		var p = GPUParticles3D.new()
		p.emitting = false
		p.one_shot = true
		p.amount = 20 # More particles per burst
		p.lifetime = 1.0
		p.explosiveness = 0.8
		
		# Create default material if none assigned
		if not score_particle_material:
			score_particle_material = ParticleProcessMaterial.new()
			score_particle_material.spread = 180.0
			score_particle_material.initial_velocity_min = 2.0
			score_particle_material.initial_velocity_max = 5.0
			score_particle_material.gravity = Vector3(0, -9.8, 0)
		
		p.process_material = score_particle_material
		
		# Create default mesh if none assigned
		if not score_mesh:
			score_mesh = QuadMesh.new()
			score_mesh.size = Vector2(0.1, 0.1)
		
		p.draw_pass_1 = score_mesh
		add_child(p)
		p.global_position = Vector3(0, -100, 0) # Hide under map
		pool.append(p)

func play_pop_at(pos: Vector3, scale_factor: float = 1.0) -> void:
	for p in pool:
		if not p.emitting:
			p.global_position = pos
			p.scale = Vector3.ONE * scale_factor
			p.amount = int(20 * scale_factor) # More particles for bigger pops
			p.emitting = true
			return
