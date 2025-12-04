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
	_generate_shop_stock()
	_switch_tab("balls")

func _switch_tab(tab_name: String) -> void:
	current_tab = tab_name
	
	# 1. Visual Toggle (Show/Hide Containers)
	# Assumes containers are parents of the HBoxes, or you toggle the ScrollContainers
	$MainLayout/TabContent/BallsScroll.visible = (tab_name == "balls")
	$MainLayout/TabContent/DabbersScroll.visible = (tab_name == "dabbers")
	$MainLayout/TabContent/ArtifactsScroll.visible = (tab_name == "artifacts")
	
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
	
	var cost = item_data["cost"]
	var type = item_data["currency_type"]
	var success = false
	
	match type:
		"obols":
			if gm.currency_obols >= cost:
				gm.currency_obols -= cost
				gm.owned_balls.append(item_data["id"])
				success = true
		"essence":
			if gm.currency_essence >= cost:
				gm.currency_essence -= cost
				gm.active_dabbers.append(item_data["id"])
				success = true
		"fate":
			if gm.currency_fate >= cost:
				gm.currency_fate -= cost
				gm.active_artifacts.append(item_data["id"])
				success = true
	
	if success:
		_show_feedback("Acquired: " + item_data["name"], Color.GREEN)
		_update_currency_display()
		# Ideally, remove the card or mark sold. For now, we regenerate to refresh.
		# A better UX is to just disable the specific button.
		_generate_all_shops() 
	else:
		_show_feedback("Not enough " + type.capitalize() + "!", Color.RED)

# --- DATA GENERATORS (Placeholders for Step 5) ---
func _get_random_balls() -> Array:
	# Access BallDatabase to get real data
	var db = get_node("/root/BallDatabase")
	var shop_balls = []
	for i in range(3):
		var id = db.get_random_by_rarity("mortal") # Only mortal for now per rules
		var data = db.get_data(id).duplicate()
		data["id"] = id
		data["cost"] = 50 # Base Obol Cost
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
	
	for child in deck_container.get_children():
		child.queue_free()
	
	var db = get_node("/root/BallDatabase")
	var ball_counts = {}
	for type_id in gm.owned_balls:
		if not ball_counts.has(type_id):
			ball_counts[type_id] = 0
		ball_counts[type_id] += 1
	
	for type_id in ball_counts.keys():
		var data = db.get_data(type_id).duplicate()
		data["id"] = type_id
		data["count"] = ball_counts[type_id]
		data["cost"] = gm.get_removal_cost()
		data["currency_type"] = "obols"
		data["is_shop_item"] = false
		
		var card = card_scene.instantiate()
		deck_container.add_child(card)
		card.setup(data)
		card.item_clicked.connect(_on_deck_ball_removed)

func _on_deck_ball_removed(item_data: Dictionary) -> void:
	var gm = get_node_or_null("/root/GameManager")
	if not gm: return
	
	var idx = gm.owned_balls.find(item_data["id"])
	if idx == -1:
		_show_feedback("Ball not found!", Color.RED)
		return
	
	if gm.remove_ball(idx):
		_show_feedback("Removed " + item_data["name"], Color.ORANGE)
		_update_currency_display()
		_refresh_deck_view()
	else:
		_show_feedback("Not enough Obols!", Color.RED)
