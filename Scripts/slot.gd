extends Area3D
class_name SlotV4

@export var grid_x: int
@export var grid_y: int
@export var target_id: String = "B-1" 

var held_ball: RigidBody3D = null
var is_highlighted: bool = false 
var target_label: Label3D = null 

# Track if this is a bench slot
var is_bench_slot: bool = false 
var permanent_bonus: int = 0
var permanent_multiplier: float = 1.0

@onready var mesh: MeshInstance3D = $MeshInstance3D

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
	else:
		is_bench_slot = false
		_create_or_update_label()

func refresh_id(new_id: String) -> void:
	target_id = new_id
	_create_or_update_label()

# --- THE MISSING FUNCTION CAUSING THE CRASH ---
func update_indicator() -> void:
	# Refresh the text label to show bonuses
	_create_or_update_label()
	
	# Color code the slot base based on buffs
	if mesh and mesh.material_override:
		if permanent_multiplier > 1.0:
			# Gold Tint for Multipliers
			mesh.material_override.albedo_color = Color(0.6, 0.5, 0.1) 
		elif permanent_bonus > 0:
			# Green Tint for Bonuses
			mesh.material_override.albedo_color = Color(0.2, 0.5, 0.2) 

func _create_or_update_label() -> void:
	if not target_label:
		target_label = Label3D.new()
		add_child(target_label)
		target_label.position = Vector3(0, 0.11, 0)
		target_label.rotation_degrees.x = -90
	
	var text_parts = target_id.split("-")
	var display_text = ""
	
	if text_parts.size() > 1:
		display_text = text_parts[1]
	else:
		display_text = target_id

	# Append Bonus Info visually
	if permanent_multiplier > 1.0:
		display_text += "\nx" + str(permanent_multiplier)
		target_label.modulate = Color.GOLD
	elif permanent_bonus > 0:
		display_text += "\n+" + str(permanent_bonus)
		target_label.modulate = Color.GREEN
	else:
		target_label.modulate = Color.WHITE

	target_label.text = display_text
	target_label.font_size = 96
	target_label.pixel_size = 0.005
	target_label.outline_size = 12
	target_label.outline_modulate = Color.BLACK
	target_label.no_depth_test = true

func _setup_material() -> void:
	if mesh:
		var current_mat = mesh.get_active_material(0)
		if current_mat: mesh.material_override = current_mat.duplicate()
		else: mesh.material_override = StandardMaterial3D.new()

func set_highlight(active: bool) -> void:
	is_highlighted = active
	# Only override color if we don't have permanent buffs
	if permanent_multiplier <= 1.0 and permanent_bonus <= 0:
		if mesh and mesh.material_override:
			if active:
				mesh.material_override.albedo_color = Color.GREEN
			else:
				mesh.material_override.albedo_color = Color(0.2, 0.2, 0.2) 
	
	if target_label: 
		target_label.visible = (held_ball == null)

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
