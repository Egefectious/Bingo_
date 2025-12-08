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
var glow_light: OmniLight3D = null

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
		if glow_light: glow_light.visible = false
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
# VISUALS - MODERN NEON STYLE
# ========================================

func _create_visuals() -> void:
	"""Create Victorian slot appearance"""
	
	# Base (wood inlay)
	if not base_mesh:
		base_mesh = MeshInstance3D.new()
		add_child(base_mesh)
		base_mesh.name = "BaseMesh"
	
	var base = CylinderMesh.new()
	base.top_radius = 0.45
	base.bottom_radius = 0.48
	base.height = 0.15
	base_mesh.mesh = base
	base_mesh.position = Vector3(0, 0.075, 0)
	
	var base_mat = StandardMaterial3D.new()
	base_mat.albedo_color = Color(0.12, 0.09, 0.07)
	base_mat.roughness = 0.7
	base_mat.metallic = 0.1
	base_mesh.material_override = base_mat
	
	# Rim (brass/bronze ring)
	if not rim_mesh:
		rim_mesh = MeshInstance3D.new()
		add_child(rim_mesh)
		rim_mesh.name = "RimMesh"
	
	var rim = TorusMesh.new()
	rim.inner_radius = 0.45
	rim.outer_radius = 0.52
	rim.rings = 32
	rim.ring_segments = 32
	rim_mesh.mesh = rim
	rim_mesh.position = Vector3(0, 0.15, 0)
	
	var rim_mat = StandardMaterial3D.new()
	rim_mat.albedo_color = Color(0.6, 0.5, 0.3)  # Brass
	rim_mat.metallic = 0.8
	rim_mat.roughness = 0.3
	rim_mat.emission_enabled = true
	rim_mat.emission = _get_column_color() * 0.3
	rim_mat.emission_energy_multiplier = 0.5
	rim_mesh.material_override = rim_mat
	
	# Soft glow
	glow_light = OmniLight3D.new()
	add_child(glow_light)
	glow_light.light_color = _get_column_color()
	glow_light.light_energy = 0.8
	glow_light.omni_range = 1.2
	glow_light.omni_attenuation = 2.0
	glow_light.position = Vector3(0, 0.3, 0)
	
	# Collision
	var collision = CollisionShape3D.new()
	var shape = CylinderShape3D.new()
	shape.radius = 0.5
	shape.height = 0.4
	collision.shape = shape
	collision.position = Vector3(0, 0.2, 0)
	add_child(collision)
	
	# Number label
	_create_label()
	
	# Subtle pulse
	_add_idle_pulse()

func _get_column_color() -> Color:
	"""Get neon color based on column"""
	if grid_x == -1:
		return Color.WHITE
	
	match grid_x:
		0: return Color(1.0, 0.2, 0.8)  # L - Hot Pink
		1: return Color(0.2, 0.8, 1.0)  # I - Cyan
		2: return Color(0.2, 1.0, 0.4)  # M - Green
		3: return Color(0.8, 0.2, 1.0)  # B - Purple
		4: return Color(1.0, 0.6, 0.0)  # O - Orange
	
	return Color.WHITE

func _create_label() -> void:
	if not number_label:
		number_label = Label3D.new()
		add_child(number_label)
	
	# FIX: Lower it closer to the wood so it doesn't float
	number_label.position = Vector3(0, 0.2, 0) 
	
	number_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	number_label.font_size = 96
	
	# CRITICAL FIX: Turn OFF no_depth_test so it respects 3D space
	number_label.no_depth_test = false 
	
	number_label.outline_size = 16
	number_label.modulate = Color.WHITE

func _update_label() -> void:
	"""Update number display"""
	if not number_label or target_id == "": return
	
	var parts = target_id.split("-")
	var display_text = ""
	
	if parts.size() > 1:
		display_text = parts[1]
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
	var base_color = _get_column_color()
	
	if permanent_multiplier > 1.0:
		number_label.modulate = Color.GOLD
		number_label.outline_modulate = Color(0.3, 0.2, 0.0)
	elif permanent_bonus > 0 or line_bonus > 0:
		number_label.modulate = Color(0.4, 1.0, 0.4)
		number_label.outline_modulate = Color(0.0, 0.3, 0.0)
	else:
		number_label.modulate = base_color.lightened(0.5)
		number_label.outline_modulate = base_color.darkened(0.5)

func _update_visuals() -> void:
	"""Update colors based on upgrades"""
	if not base_mesh or not rim_mesh: return
	
	var base_mat = base_mesh.material_override
	var rim_mat = rim_mesh.material_override
	
	if permanent_multiplier > 1.0:
		# Gold glow for multipliers
		base_mat.albedo_color = Color(0.2, 0.15, 0.05)
		base_mat.emission = Color(0.4, 0.3, 0.1)
		base_mat.emission_energy_multiplier = 1.5
		
		rim_mat.emission = Color(1.0, 0.8, 0.0)
		rim_mat.emission_energy_multiplier = 4.0
		
		if glow_light:
			glow_light.light_color = Color.GOLD
			glow_light.light_energy = 3.0
		
	elif permanent_bonus > 0 or line_bonus > 0:
		# Green glow for bonuses
		base_mat.albedo_color = Color(0.05, 0.15, 0.08)
		base_mat.emission = Color(0.1, 0.4, 0.2)
		base_mat.emission_energy_multiplier = 1.2
		
		rim_mat.emission = Color(0.4, 1.0, 0.5)
		rim_mat.emission_energy_multiplier = 3.5
		
		if glow_light:
			glow_light.light_color = Color(0.4, 1.0, 0.5)
			glow_light.light_energy = 2.5
	else:
		# Default column color
		var col = _get_column_color()
		base_mat.albedo_color = Color(0.08, 0.06, 0.1)
		base_mat.emission = col * 0.3
		base_mat.emission_energy_multiplier = 0.5
		
		rim_mat.emission = col
		rim_mat.emission_energy_multiplier = 2.0
		
		if glow_light:
			glow_light.light_color = col
			glow_light.light_energy = 1.5

func _add_idle_pulse() -> void:
	"""Subtle breathing animation"""
	if not glow_light: return
	
	var tween = create_tween().set_loops()
	var base_energy = glow_light.light_energy
	
	tween.tween_property(glow_light, "light_energy", base_energy * 1.3, 2.0 + randf() * 0.5).set_trans(Tween.TRANS_SINE)
	tween.tween_property(glow_light, "light_energy", base_energy * 0.7, 2.0 + randf() * 0.5).set_trans(Tween.TRANS_SINE)

# ========================================
# BALL MANAGEMENT
# ========================================

func assign_ball(ball: RigidBody3D) -> void:
	held_ball = ball
	if number_label:
		number_label.visible = false
	if glow_light:
		glow_light.light_energy *= 0.3

func remove_ball() -> void:
	held_ball = null
	if number_label:
		number_label.visible = true
	if glow_light:
		_add_idle_pulse()

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
	"""Pulse effect when hovering"""
	if not rim_mesh or not rim_mesh.material_override: return
	if not glow_light: return
	
	# Don't override upgrade colors
	if permanent_multiplier > 1.0 or permanent_bonus > 0 or line_bonus > 0:
		return
	
	var rim_mat = rim_mesh.material_override
	var col = _get_column_color()
	
	if active:
		# Bright pulse
		rim_mat.emission = col * 1.5
		rim_mat.emission_energy_multiplier = 4.0
		glow_light.light_energy = 3.0
		
		# Scale pulse
		var tween = create_tween()
		tween.tween_property(rim_mesh, "scale", Vector3(1.1, 1.1, 1.1), 0.1).set_trans(Tween.TRANS_ELASTIC)
	else:
		# Return to normal
		rim_mat.emission = col
		rim_mat.emission_energy_multiplier = 2.0
		glow_light.light_energy = 1.5
		
		var tween = create_tween()
		tween.tween_property(rim_mesh, "scale", Vector3.ONE, 0.2).set_trans(Tween.TRANS_BACK)
