extends Control
#

signal item_clicked(item_data)
var data: Dictionary = {}

@onready var name_lbl: Label = $NameLabel
@onready var desc_lbl: Label = $DescLabel
@onready var cost_lbl: Label = $CostLabel
@onready var bg: ColorRect = $RarityColor
@onready var btn: Button = $Button
@onready var info_box: Panel = $InfoBox

# Reference the container we just made
@onready var viewport_container: SubViewportContainer = $SubViewportContainer
@onready var sub_viewport: SubViewport = $SubViewportContainer/SubViewport

func setup(item_data: Dictionary) -> void:
	data = item_data
	name_lbl.text = data["name"]
	desc_lbl.text = data["desc"]
	
	# --- 3D PREVIEW SETUP ---
	_setup_3d_preview()
	
	# --- BUTTON CONFIG ---
	if data.get("is_removal", false):
		btn.text = "SELL"
		btn.modulate = Color(1.0, 0.4, 0.4) # Red for selling
	else:
		btn.text = "BUY"
		btn.modulate = Color.WHITE

	# --- CURRENCY & COLOR ---
	# (Keep your existing currency/rarity logic here...)
	var cost = data.get("cost", 0)
	cost_lbl.text = str(cost)
	
	# Reuse your existing rarity color logic
	var r_str = data.get("rarity", "mortal")
	match r_str:
		"mortal": bg.color = Color(0.2, 0.2, 0.2)
		"blessed": bg.color = Color(0.1, 0.3, 0.5)
		"divine": bg.color = Color(0.4, 0.1, 0.4)
		"godly": bg.color = Color(0.6, 0.4, 0.0)

func _setup_3d_preview() -> void:
	# Clear old preview
	for child in sub_viewport.get_children():
		if child is RigidBody3D: child.queue_free()
		
	# Only show preview if it's a ball
	if data.has("type_id"):
		viewport_container.visible = true
		
		# Load Ball Scene
		var ball_scene = load("res://Scenes/ball.tscn")
		var ball = ball_scene.instantiate()
		sub_viewport.add_child(ball)
		
		# Strip Physics (Visual only)
		ball.freeze = true
		ball.collision_layer = 0
		ball.collision_mask = 0
		
		# Setup Appearance
		# If it's a shop item, it might not have a specific number ID yet (e.g. "L-?"), 
		# unless you generated specific IDs in Shop_ui.gd.
		var b_id = data.get("ball_id", "B-?") 
		ball.setup_ball(b_id, data["type_id"])
		
		# Animate Spinning
		var tween = create_tween().set_loops()
		tween.tween_property(ball, "rotation_degrees:y", 360.0, 6.0).from(0.0)
	else:
		viewport_container.visible = false

func _on_button_pressed() -> void:
	item_clicked.emit(data)

func _on_button_mouse_entered() -> void:
	if info_box: info_box.visible = true

func _on_button_mouse_exited() -> void:
	if info_box: info_box.visible = false
