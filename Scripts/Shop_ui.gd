extends Control

# --- CONFIGURATION ---
# Drag your ItemCard.tscn here!
@export var card_scene: PackedScene 
# Drag your MainGame.tscn here!
@export_file("*.tscn") var next_level_scene_path: String

# --- NODE REFERENCES (Updated for new layout) ---
@onready var cards_container: HBoxContainer = $MainLayout/CardsContainer
@onready var cash_label: Label = $MainLayout/BottomBar/CashLabel
@onready var feedback_label: Label = $MainLayout/FeedbackLabel
@onready var next_button: Button = $MainLayout/BottomBar/NextLevelButton

func _ready() -> void:
	# 1. Connect the button signal via code (Fail-safe)
	if next_button and not next_button.pressed.is_connected(_on_next_level_pressed):
		next_button.pressed.connect(_on_next_level_pressed)
	
	update_cash_display()
	generate_shop_items()

func generate_shop_items() -> void:
	if not cards_container or not card_scene: return
	
	# Clear old cards
	for child in cards_container.get_children():
		child.queue_free()
	
	# Fetch items from GameManager
	var gm = get_node_or_null("/root/GameManager")
	if not gm: return
	
	var items_to_sell = gm.generate_shop_items()
	
	for item_data in items_to_sell:
		var card = card_scene.instantiate()
		cards_container.add_child(card)
		card.setup(item_data)
		# Listen for when the player clicks the card
		card.item_clicked.connect(_on_card_clicked)

func _on_card_clicked(item_data: Dictionary) -> void:
	var gm = get_node_or_null("/root/GameManager")
	if not gm: return

	if gm.buy_item(item_data):
		_show_feedback("PURCHASED!", Color.GREEN)
		update_cash_display()
		# Refresh to remove the bought item (optional)
		generate_shop_items() 
	else:
		_show_feedback("TOO EXPENSIVE!", Color.RED)

func _on_next_level_pressed() -> void:
	if next_level_scene_path != "":
		get_tree().change_scene_to_file(next_level_scene_path)
	else:
		# Fallback
		get_tree().change_scene_to_file("res://Scenes/MainGame.tscn")

func update_cash_display() -> void:
	var gm = get_node_or_null("/root/GameManager")
	if gm and cash_label:
		cash_label.text = "$ " + str(gm.run_score)

func _show_feedback(text: String, color: Color = Color.WHITE) -> void:
	if feedback_label:
		feedback_label.text = text
		feedback_label.modulate = color
		
		# Simple "Pop" animation
		var tween = create_tween()
		feedback_label.scale = Vector2(1.5, 1.5)
		tween.tween_property(feedback_label, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BOUNCE)
		
		# Clear text after 2 seconds
		await get_tree().create_timer(2.0).timeout
		if is_instance_valid(feedback_label):
			feedback_label.text = "Select an Upgrade"
			feedback_label.modulate = Color.WHITE
