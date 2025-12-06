extends Area3D
class_name SlotV4

@export var grid_x: int
@export var grid_y: int
@export var target_id: String = "B-1" 

var held_ball: RigidBody3D = null
var is_highlighted: bool = false 
var target_label: Label3D = null 

var is_bench_slot: bool = false 
var permanent_bonus: int = 0
var permanent_multiplier: float = 1.0
var line_bonus: int = 0

@onready var mesh: MeshInstance3D = $MeshInstance3D
@onready var frame: MeshInstance3D = $Frame
@onready var corner_gems: Node3D = $CornerGems

signal slot_hovered(slot)
signal slot_unhovered(slot)

func _ready() -> void:
	add_to_group("Slots")
	monitoring = true
	monitorable = true
	collision_mask = 2 
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_setup_material()

func setup_slot(new_id: String, x: int, y: int) -> void:
	target_id = new_id
	grid_x = x
	grid_y = y
	
	if new_id == "BENCH":
		is_bench_slot = true
		target_label = null
		# Hide decorative elements on bench
		if frame: frame.visible = false
		if corner_gems: corner_gems.visible = false
	else:
		is_bench_slot = false
		_create_or_update_label()
		# Ensure decorations are visible
		if frame: frame.visible = true
		if corner_gems: corner_gems.visible = true

func refresh_id(new_id: String) -> void:
	target_id = new_id
	_create_or_update_label()

func update_indicator() -> void:
	_create_or_update_label()
	_update_visual_effects()
	
func _update_visual_effects() -> void:
	"""Update frame and base materials based on buffs"""
	if not mesh: return
	
	# Update base slot material
	if mesh.material_override:
		var base_mat = mesh.material_override
		
		if permanent_multiplier > 1.0:
			# Gold glow for multipliers
			base_mat.albedo_color = Color(0.3, 0.25, 0.1)
			base_mat.emission = Color(0.8, 0.6, 0.2)
			base_mat.emission_energy_multiplier = 0.8
			
		elif permanent_bonus > 0 or line_bonus > 0:
			# Green glow for bonuses
			base_mat.albedo_color = Color(0.1, 0.25, 0.15)
			base_mat.emission = Color(0.2, 0.6, 0.3)
			base_mat.emission_energy_multiplier = 0.6
		else:
			# Default dark wood
			base_mat.albedo_color = Color(0.12, 0.08, 0.06)
			base_mat.emission = Color(0.15, 0.1, 0.08)
			base_mat.emission_energy_multiplier = 0.2
	
	# Update frame glow
	if frame and frame.material_override:
		var frame_mat = frame.material_override
		
		if permanent_multiplier > 1.0:
			frame_mat.emission = Color(1.0, 0.8, 0.0) # Bright gold
			frame_mat.emission_energy_multiplier = 2.5
		elif permanent_bonus > 0 or line_bonus > 0:
			frame_mat.emission = Color(0.3, 1.0, 0.4) # Bright green
			frame_mat.emission_energy_multiplier = 2.0
		else:
			frame_mat.emission = Color(1.0, 0.5, 0.2) # Default orange
			frame_mat.emission_energy_multiplier = 1.5
	
	# Pulse corner gems if buffed
	if permanent_multiplier > 1.0 or permanent_bonus > 0 or line_bonus > 0:
		_add_corner_pulse()
			
func _create_or_update_label() -> void:
	if not target_label:
		target_label = Label3D.new()
		add_child(target_label)
		target_label.position = Vector3(0, 0.11, 0)
		target_label.rotation_degrees.x = -90
	
	var text_parts = target_id.split("-")
	var display_text = ""
	if text_parts.size() > 1: display_text = text_parts[1]
	else: display_text = target_id

	# Append Bonus Info visually
	if permanent_multiplier > 1.0:
		display_text += "\nx" + str(permanent_multiplier)
		target_label.modulate = Color.GOLD
		target_label.outline_modulate = Color(0.4, 0.3, 0.0)
	elif permanent_bonus > 0:
		display_text += "\n+" + str(permanent_bonus)
		target_label.modulate = Color(0.3, 1.0, 0.3)
		target_label.outline_modulate = Color(0.0, 0.3, 0.0)
	elif line_bonus > 0:
		display_text += "\nL+" + str(line_bonus)
		target_label.modulate = Color(0.5, 1.0, 0.5)
		target_label.outline_modulate = Color(0.0, 0.4, 0.0)
	else:
		target_label.modulate = Color.WHITE
		target_label.outline_modulate = Color.BLACK

	target_label.text = display_text
	target_label.font_size = 96
	target_label.pixel_size = 0.005
	target_label.outline_size = 12
	target_label.no_depth_test = true

func _setup_material() -> void:
	"""Initialize base materials - they get modified later"""
	if mesh:
		var current_mat = mesh.get_active_material(0)
		if current_mat: 
			mesh.material_override = current_mat.duplicate()
		else: 
			mesh.material_override = StandardMaterial3D.new()
	
	# Setup frame material if it exists
	if frame:
		var frame_mat = frame.get_active_material(0)
		if frame_mat:
			frame.material_override = frame_mat.duplicate()

func set_highlight(active: bool) -> void:
	is_highlighted = active
	
	# Only change appearance if no permanent buffs
	if permanent_multiplier <= 1.0 and permanent_bonus <= 0 and line_bonus <= 0:
		if mesh and mesh.material_override:
			if active:
				# Cyan highlight when dragging ball over
				mesh.material_override.emission = Color(0.2, 0.8, 1.0)
				mesh.material_override.emission_energy_multiplier = 1.5
			else:
				# Return to normal
				mesh.material_override.emission = Color(0.15, 0.1, 0.08)
				mesh.material_override.emission_energy_multiplier = 0.2
		
		if frame and frame.material_override:
			if active:
				frame.material_override.emission_energy_multiplier = 3.0
			else:
				frame.material_override.emission_energy_multiplier = 1.5
	
	if target_label: 
		target_label.visible = (held_ball == null)

func _add_corner_pulse() -> void:
	"""Animate corner gems when slot has buffs"""
	if not corner_gems: return
	
	for child in corner_gems.get_children():
		if child is CSGSphere3D:
			var tween = create_tween().set_loops()
			tween.tween_property(child, "radius", 0.08, 0.6).set_trans(Tween.TRANS_SINE)
			tween.tween_property(child, "radius", 0.05, 0.6).set_trans(Tween.TRANS_SINE)

func assign_ball(ball: RigidBody3D) -> void:
	held_ball = ball
	if target_label: target_label.visible = false 

func remove_ball() -> void:
	held_ball = null
	if target_label: target_label.visible = true
	set_highlight(false) 

func is_available() -> bool:
	return held_ball == null

func _on_body_entered(body: Node3D) -> void:
	if body.get("current_state") == 1: 
		slot_hovered.emit(self)

func _on_body_exited(body: Node3D) -> void:
	if body.has_method("start_drag"):
		slot_unhovered.emit(self)
