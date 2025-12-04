extends Node

var dev_mode: bool = false
# --- PERSISTENT DATA (SAVED) ---
var currency_obols: int = 0
var currency_essence: int = 0  
var currency_fate: int = 0     

# Progression
var current_caller_index: int = 1   # 1 to 8
var current_encounter_index: int = 1 # 1 to 3
var run_active: bool = true

# UPDATED: Stores Dictionaries now: { "id": "L-1", "type": "ball_standard" }
var owned_balls: Array = [] 
var active_dabbers: Array = [] 
var active_artifacts: Array = []

# Shop State (Resets per Caller)
var reroll_cost: int = 10
var ball_removal_cost: int = 50 # Set a price for removal
var balls_removed_this_caller: int = 0

# --- SETTINGS ---
var target_score_base: int = 500
var SCORE_THRESHOLDS = [1000, 2500, 5000, 10000
] # Added for Tally logic
func _ready() -> void:
	start_new_run()

func start_new_run() -> void:
	currency_obols = 100 # A bit more starting cash for deck editing
	currency_essence = 0
	currency_fate = 0
	
	current_caller_index = 1
	current_encounter_index = 1
	run_active = true
	
	# --- NEW: GENERATE FULL 75-BALL DECK ---
	owned_balls.clear()
	var letters = ["L", "I", "M", "B", "O"]
	
	if dev_mode:
		# Dev Deck: Small and powerful
		for i in range(10): 
			owned_balls.append({ "id": "B-10", "type": "ball_god" })
	else:
		# Standard Deck: 1 to 15 for each letter
		for l_idx in range(5):
			for n in range(1, 16):
				var id = letters[l_idx] + "-" + str(n)
				owned_balls.append({ "id": id, "type": "ball_standard" })
	
	active_dabbers = []
	active_artifacts = []

# --- DIFFICULTY SCALING ---
func get_current_target() -> int:
	# Base 500
	# Each Encounter adds 250
	# Each Caller adds 1000
	var encounter_mult = (current_encounter_index - 1) * 250
	var caller_mult = (current_caller_index - 1) * 1000
	
	return 500 + encounter_mult + caller_mult

func get_caller_name() -> String:
	# Placeholder for future flavor text
	var names = ["The Gatekeeper", "The Watcher", "The Judge", "The Warden", "The Hangman", "The Sorrow", "The Void", "The End"]
	return names[current_caller_index - 1]

func get_max_rounds_for_encounter() -> int:
	# User Request: "Each encounter is 3 rounds... not less as you go on"
	return 3
	
# --- PROGRESSION ---
func encounter_won(obols: int, essence: int, fate: int) -> void:
	# 1. Bank Currency
	currency_obols += obols
	currency_essence += essence
	currency_fate += fate
	
	print("Encounter Won! Banking: %s O | %s E | %s F" % [obols, essence, fate])
	
	# 2. Advance State
	current_encounter_index += 1
	if current_encounter_index > 3:
		current_encounter_index = 1
		current_caller_index += 1
		print("CALLER DEFEATED! Approaching Caller %s..." % current_caller_index)
	
	# 3. Check Victory
	if current_caller_index > 8:
		_trigger_victory()

func game_over() -> void:
	print("GAME OVER - SOUL LOST")
	run_active = false
	# Logic to show Game Over screen goes here

func _trigger_victory() -> void:
	print("YOU HAVE ESCAPED LIMBO!")
	# Logic to show Victory screen goes here

# --- SHOP LOGIC ---
# Buy now accepts a full dictionary data packet
func buy_ball_item(ball_data: Dictionary) -> bool:
	var cost = ball_data["cost"]
	if currency_obols >= cost:
		currency_obols -= cost
		# Store the specific ball data (ID + Type)
		owned_balls.append({ "id": ball_data["ball_id"], "type": ball_data["type_id"] })
		return true
	return false

# New Removal Function
func remove_ball_from_deck(index: int) -> bool:
	if index < 0 or index >= owned_balls.size(): return false
	
	if currency_obols >= ball_removal_cost:
		currency_obols -= ball_removal_cost
		owned_balls.remove_at(index)
		return true
	return false

func get_removal_cost() -> int:
	return ball_removal_cost

func buy_dabber(id: String, cost: int) -> bool:
	if currency_essence >= cost:
		currency_essence -= cost
		active_dabbers.append(id)
		return true
	return false

func buy_artifact(id: String, cost: int) -> bool:
	if currency_fate >= cost:
		currency_fate -= cost
		active_artifacts.append(id)
		return true
	return false
