extends Control

# --- CONFIGURATION ---
@export var card_scene: PackedScene 
@export_file("*.tscn") var next_level_scene_path: String

# --- NODE REFERENCES ---
@onready var container_balls: HBoxContainer = $MainLayout/TabContent/BallsScroll/HBox
@onready var container_dabbers: HBoxContainer = $MainLayout/TabContent/DabbersScroll/HBox
@onready var container_artifacts: HBoxContainer = $MainLayout/TabContent/ArtifactsScroll/HBox

@onready var lbl_obols: Label = $MainLayout/Header/Currencies/ObolsLabel
@onready var lbl_essence: Label = $MainLayout/Header/Currencies/EssenceLabel
@onready var lbl_fate: Label = $MainLayout/Header/Currencies/FateLabel
@onready var feedback_label: Label = $MainLayout/FeedBackLabel

@onready var btn_tab_balls: Button = $MainLayout/Tabs/BtnBalls
@onready var btn_tab_dabbers: Button = $MainLayout/Tabs/BtnDabbers
@onready var btn_tab_artifacts: Button = $MainLayout/Tabs/BtnArtifacts

# NEW: Deck Management & Reroll
@onready var deck_scroll: ScrollContainer = $MainLayout/TabContent/DeckScroll
@onready var deck_container: HBoxContainer = $MainLayout/TabContent/DeckScroll/HBox
@onready var btn_tab_deck: Button = $MainLayout/Tabs/BtnDeck
@onready var btn_reroll: Button = $MainLayout/BottomBar/RerollButton

var current_tab: String = "balls"
var shop_inventory: Dictionary = {
	"balls": [],
	"dabbers": [],
	"artifacts": []
}

func _ready() -> void:
	btn_tab_balls.pressed.connect(func(): _switch_tab("balls"))
	btn_tab_dabbers.pressed.connect(func(): _switch_tab("dabbers"))
	btn_tab_artifacts.pressed.connect(func(): _switch_tab("artifacts"))
	btn_tab_deck.pressed.connect(func(): _switch_tab("deck"))
	btn_reroll.pressed.connect(_on_reroll_pressed)
	
	_check_unlocks()
	_update_currency_display()
	_generate_all_shops()
	_switch_tab("balls")

func _switch_tab(tab_name: String) -> void:
	current_tab = tab_name
	
	# Toggle visibility
	$MainLayout/TabContent/BallsScroll.visible = (tab_name == "balls")
	$MainLayout/TabContent/DabbersScroll.visible = (tab_name == "dabbers")
	$MainLayout/TabContent/ArtifactsScroll.visible = (tab_name == "artifacts")
	$MainLayout/TabContent/DeckScroll.visible = (tab_name == "deck")
	
	# Refresh deck view when clicked
	if tab_name == "deck":
		_refresh_deck_view()
	
	# 2. Button Highlight (Optional visuals)
	btn_tab_balls.modulate = Color.WHITE if tab_name == "balls" else Color.GRAY
	btn_tab_dabbers.modulate = Color.CYAN if tab_name == "dabbers" else Color.GRAY
	btn_tab_artifacts.modulate = Color.GOLD if tab_name == "artifacts" else Color.GRAY

func _generate_all_shops() -> void:
	# 1. Generate Balls (Cost: Obols)
	_populate_container(container_balls, _get_random_balls(), "obols")
	
	# 2. Generate Dabbers (Cost: Essence)
	_populate_container(container_dabbers, _get_random_dabbers(), "essence")
	
	# 3. Generate Artifacts (Cost: Fate)
	_populate_container(container_artifacts, _get_random_artifacts(), "fate")

func _populate_container(container: Control, items: Array, currency_type: String) -> void:
	# Clear old
	for child in container.get_children():
		child.queue_free()
		
	for item_data in items:
		var card = card_scene.instantiate()
		container.add_child(card)
		
		# Inject the currency type so the card knows what to display
		item_data["currency_type"] = currency_type
		card.setup(item_data)
		card.item_clicked.connect(_on_item_purchased)

# --- TRANSACTION LOGIC ---
func _on_item_purchased(item_data: Dictionary) -> void:
	var gm = get_node_or_null("/root/GameManager")
	if not gm: return
	
	var type = item_data["currency_type"]
	var success = false
	
	match type:
		"obols":
			# Call the new buy function that handles the dictionary
			success = gm.buy_ball_item(item_data)
		"essence":
			success = gm.buy_dabber(item_data["id"], item_data["cost"])
		"fate":
			success = gm.buy_artifact(item_data["id"], item_data["cost"])
	
	if success:
		_show_feedback("Acquired: " + item_data["name"], Color.GREEN)
		_update_currency_display()
		_generate_all_shops() # Refresh stock
		if current_tab == "deck": _refresh_deck_view() # Refresh deck if we removed something
	else:
		_show_feedback("Not enough " + type.capitalize() + "!", Color.RED)

# --- DATA GENERATORS (Placeholders for Step 5) ---
func _get_random_balls() -> Array:
	var db = get_node("/root/BallDatabase")
	var shop_balls = []
	var letters = ["L", "I", "M", "B", "O"]
	
	for i in range(3):
		# 1. Pick a Type
		var type_id = db.get_random_by_rarity("mortal") 
		if randf() > 0.8: type_id = db.get_random_by_rarity("blessed")
		
		var db_data = db.get_data(type_id)
		
		# 2. Pick a Specific Number (ID)
		var l = letters.pick_random()
		var n = randi_range(1, 15)
		var specific_id = l + "-" + str(n)
		
		# 3. Construct Shop Item
		var data = db_data.duplicate()
		data["type_id"] = type_id
		data["ball_id"] = specific_id # Store the ID
		
		# Update Name to show the number
		data["name"] = data["name"] + " (" + specific_id + ")"
		
		data["cost"] = 50 # Base Price
		if data["rarity"] == "blessed": data["cost"] = 100
		
		shop_balls.append(data)
		
	return shop_balls
	
func _get_random_dabbers() -> Array:
	# Placeholder until we implement DabberDatabase
	return [
		{ "id": "dab_corner", "name": "Corner Stone", "desc": "Corners x2 Multiplier", "cost": 5, "rarity": "blessed" },
		{ "id": "dab_center", "name": "Bullseye", "desc": "Center Slot +50 Pts", "cost": 3, "rarity": "mortal" }
	]

func _get_random_artifacts() -> Array:
	# Placeholder until we implement ArtifactDatabase
	return [
		{ "id": "art_draw", "name": "Loaded Die", "desc": "Draw more 1-5s", "cost": 30, "rarity": "divine" },
		{ "id": "art_luck", "name": "Fate's Coin", "desc": "Reroll one hand", "cost": 15, "rarity": "blessed" }
	]

func _update_currency_display() -> void:
	var gm = get_node_or_null("/root/GameManager")
	if gm:
		lbl_obols.text = "Ø " + str(gm.currency_obols)
		lbl_essence.text = "₳ " + str(gm.currency_essence)
		lbl_fate.text = "₪ " + str(gm.currency_fate)

func _show_feedback(text: String, color: Color) -> void:
	feedback_label.text = text
	feedback_label.modulate = color
	var tween = create_tween()
	tween.tween_property(feedback_label, "scale", Vector2(1.2, 1.2), 0.1)
	tween.tween_property(feedback_label, "scale", Vector2.ONE, 0.1)
	
func _on_next_level_pressed() -> void:
	# Visual Feedback
	_show_feedback("ENTERING LIMBO...", Color.RED)
	
	# Wait a split second for effect
	await get_tree().create_timer(0.5).timeout
	
	# Change Scene to the Game Board
	if next_level_scene_path != "":
		get_tree().change_scene_to_file(next_level_scene_path)
	else:
		print("ERROR: Next level scene path not set in Shop UI Inspector!")
		
# Fix for Line 41 error
func _check_unlocks() -> void:
	# Placeholder: logic to hide tabs if the player hasn't unlocked them yet.
	# For now, we leave it empty so the game doesn't crash.
	pass

# Fix for Line 39 error
func _on_reroll_pressed() -> void:
	# 1. Check if player has enough money to reroll (Optional logic)
	# var reroll_cost = 5
	# if game_manager.currency_obols < reroll_cost: return
	
	# 2. Regenerate the shop items
	_generate_all_shops()
	
	# 3. specific feedback
	_show_feedback("Shop Rerolled!", Color.YELLOW)
		
func _on_btn_balls_pressed() -> void:
	pass # Replace with function body.


func _on_btn_dabbers_pressed() -> void:
	pass # Replace with function body.


func _on_btn_artifacts_pressed() -> void:
	pass # Replace with function body.


func _on_btn_deck_pressed() -> void:
	pass # Replace with function body.


func _on_reroll_button_pressed() -> void:
	pass # Replace with function body.


func _on_btn_reroll_pressed() -> void:
	pass # Replace with function body.

# ========================================
# DECK MANAGEMENT
# ========================================

func _refresh_deck_view() -> void:
	var gm = get_node_or_null("/root/GameManager")
	if not gm: return
	
	# Clear old cards
	for child in deck_container.get_children():
		child.queue_free()
	
	var db = get_node("/root/BallDatabase")
	
	# Iterate through the ACTUAL deck
	for i in range(gm.owned_balls.size()):
		var ball_entry = gm.owned_balls[i]
		var type_id = ball_entry["type"]
		var ball_id = ball_entry["id"]
		
		var data = db.get_data(type_id).duplicate()
		
		# Setup for Display
		data["name"] = data["name"] + " (" + ball_id + ")"
		data["desc"] = "Remove this ball from your bag."
		data["cost"] = gm.get_removal_cost()
		data["currency_type"] = "obols"
		
		# Store index for removal logic
		data["deck_index"] = i
		data["is_removal"] = true # Flag for the card button
		
		var card = card_scene.instantiate()
		deck_container.add_child(card)
		card.setup(data)
		# We hijack the signal to call a specific removal function
		card.item_clicked.disconnect(_on_item_purchased) 
		card.item_clicked.connect(_on_deck_ball_removed)

func _on_deck_ball_removed(item_data: Dictionary) -> void:
	var gm = get_node_or_null("/root/GameManager")
	if not gm: return
	
	var idx = item_data["deck_index"]
	
	if gm.remove_ball_from_deck(idx):
		_show_feedback("Removed " + item_data["name"], Color.ORANGE)
		_update_currency_display()
		_refresh_deck_view() # Re-render to update indices
	else:
		_show_feedback("Not enough Obols to remove!", Color.RED)
