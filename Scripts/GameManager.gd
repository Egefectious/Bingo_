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

# Player Deck & Stats (Persists)
var owned_balls: Array = [] # Now stores type_id strings
var active_dabbers: Array = [] 
var active_artifacts: Array = []

# Shop State (Resets per Caller)
var reroll_cost: int = 10
var ball_removal_cost: int = 20
var balls_removed_this_caller: int = 0

# --- SETTINGS ---
var target_score_base: int = 500

func _ready() -> void:
	start_new_run()

func start_new_run() -> void:
	currency_obols = 50 # Freebie for first shop
	currency_essence = 0
	currency_fate = 0
	
	current_caller_index = 1
	current_encounter_index = 1
	run_active = true
	
	# Reset Deck
	owned_balls = ["ball_standard", "ball_standard", "ball_standard", "ball_standard", "ball_standard"]
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
	match current_encounter_index:
		1: return 3
		2: return 2
		3: return 1
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
func buy_ball(id: String, cost: int) -> bool:
	if currency_obols >= cost:
		currency_obols -= cost
		owned_balls.append(id)
		return true
	return false

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
# Placeholder for Shop UI generation (Step 3 logic calls this)
func generate_shop_items() -> Array: return []
