extends Node

var pool: Array[GPUParticles3D] = []
var pool_size: int = 20

# Assign a "Score Pop" particle material in Inspector
var score_particle_material: ParticleProcessMaterial 
var score_mesh: QuadMesh # Or SphereMesh

func _ready() -> void:
	# create hidden pool
	for i in range(pool_size):
		var p = GPUParticles3D.new()
		p.emitting = false
		p.one_shot = true
		p.process_material = score_particle_material
		p.draw_pass_1 = score_mesh
		add_child(p)
		p.global_position = Vector3(0, -100, 0) # Hide under map
		pool.append(p)

func play_pop_at(pos: Vector3, scale_factor: float = 1.0) -> void:
	for p in pool:
		if not p.emitting:
			p.global_position = pos
			p.scale = Vector3.ONE * scale_factor
			p.emitting = true
			return
