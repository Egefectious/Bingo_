extends Node

# --- PERSISTENT DATA ---
var run_score: int = 0          
var current_level: int = 1      
var max_rounds_per_level: int = 3

# Inventory system
var active_dabbers: Array = ["starter_dabber"]

# NEW: Store the actual IDs of balls the player owns
var owned_balls: Array = ["ball_standard", "ball_standard", "ball_standard", "ball_standard", "ball_standard"] 

# --- SETTINGS ---
var balls_per_round: int = 8
var target_score_base: int = 500

func _ready() -> void:
	start_new_run()

func start_new_run() -> void:
	run_score = 500 # Give starting cash for testing
	current_level = 1
	active_dabbers = ["starter_dabber"]
	# Reset deck to basics
	owned_balls = ["ball_standard", "ball_standard", "ball_standard", "ball_standard", "ball_standard"]
	target_score_base = 500

func level_complete(money_earned: int) -> void:
	run_score += money_earned
	current_level += 1
	target_score_base += 500 * current_level
	print("Level Complete! Total Cash: ", run_score)

# --- SHOP LOGIC (FIXES THE CRASH) ---

func generate_shop_items() -> Array:
	var items_for_sale = []
	var ball_db = get_node("/root/BallDatabase") # Access your database script
	
	# Create 3 random items
	for i in range(3):
		# Simple logic: mostly mortal, some blessed
		var roll = randf()
		var rarity = "mortal"
		var cost = 50
		
		if roll > 0.7: 
			rarity = "blessed"
			cost = 150
		if roll > 0.9: 
			rarity = "divine"
			cost = 300
			
		var ball_id = ball_db.get_random_by_rarity(rarity)
		var ball_data = ball_db.get_data(ball_id).duplicate() # Duplicate so we don't mess up the DB
		
		# Add shop-specific data that ItemCard expects
		ball_data["id"] = ball_id
		ball_data["cost"] = cost
		ball_data["cost_text"] = "$ " + str(cost)
		
		items_for_sale.append(ball_data)
		
	return items_for_sale

func buy_item(item_data: Dictionary) -> bool:
	if run_score >= item_data["cost"]:
		run_score -= item_data["cost"]
		
		# Add the ball to our persistent deck
		owned_balls.append(item_data["id"])
		
		print("Bought: ", item_data["name"])
		return true
	else:
		return false
