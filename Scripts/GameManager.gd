extends Node

# --- PERSISTENT DATA (Carries over between scenes) ---
var run_score: int = 0          # Total Cash/Score
var current_level: int = 1      # Difficulty tracking
var max_rounds_per_level: int = 3

# The Player's Deck 
# We will implement persistent deck building later, 
# for now, the Board generates it based on this config.
var deck_config = {
	"size": 35,
	"specials": 3
}

# Active Relics (Dabbers)
# Stores IDs like "starter_dabber", "row_master"
var active_dabbers: Array = ["starter_dabber"]

# --- SETTINGS ---
var balls_per_round: int = 8
var target_score_base: int = 500

func _ready() -> void:
	start_new_run()

func start_new_run() -> void:
	run_score = 0
	current_level = 1
	active_dabbers = ["starter_dabber"]
	# Reset difficulty
	target_score_base = 500

# Called when we finish a Level
func level_complete(money_earned: int) -> void:
	run_score += money_earned
	current_level += 1
	
	# Increase difficulty for next level
	target_score_base += 500 * current_level
	print("Level Complete! Total Cash: ", run_score)

# Helper to check if we own a specific dabber
func has_dabber(id: String) -> bool:
	return active_dabbers.has(id)

func add_dabber(id: String) -> void:
	if not has_dabber(id):
		active_dabbers.append(id)
