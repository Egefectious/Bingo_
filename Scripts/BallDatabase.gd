extends Node

# The Master Catalog of All Balls
# Each entry defines:
# - Visuals (Name, Color, Rarity)
# - Stats (Base Bonus, Multiplier)
# - Logic (Tags array for boolean flags, Effects array for complex logic)

const DB = {
	# --- MORTAL (Common) ---
	"ball_standard": {
		"name": "Standard Ball",
		"rarity": "mortal",
		"visual_color": Color(0.9, 0.9, 0.9),
		"desc": "The basics never fail.",
		"base_bonus": 0,
		"multiplier": 1.0,
		"tags": [],
		"effects": [] 
	},
	"ball_red": {
		"name": "Red Ball",
		"rarity": "mortal",
		"visual_color": Color(0.8, 0.1, 0.1),
		"desc": "+10 Bonus Points.",
		"base_bonus": 10,
		"multiplier": 1.0,
		"tags": [],
		"effects": []
	},
	"ball_blue": {
		"name": "Blue Ball",
		"rarity": "mortal",
		"visual_color": Color(0.1, 0.2, 0.9),
		"desc": "+15 Points in B or O columns.",
		"base_bonus": 0,
		"multiplier": 1.0,
		"tags": [],
		"effects": [
			{"trigger": "check_column", "cols": [0, 4], "bonus": 15}
		]
	},
	"ball_green": {
		"name": "Green Ball",
		"rarity": "mortal",
		"visual_color": Color(0.1, 0.6, 0.1),
		"desc": "+20 Points if adjacent to another ball.",
		"base_bonus": 0,
		"multiplier": 1.0,
		"tags": [],
		"effects": [
			{"trigger": "check_adjacency", "bonus": 20}
		]
	},

	# --- BLESSED (Uncommon) ---
	"ball_silver": {
		"name": "Silver Ball",
		"rarity": "blessed",
		"visual_color": Color(0.75, 0.75, 0.75),
		"desc": "x2 Multiplier.",
		"base_bonus": 0,
		"multiplier": 2.0,
		"tags": [],
		"effects": []
	},
	"ball_glass": {
		"name": "Glass Ball",
		"rarity": "blessed",
		"visual_color": Color(0.6, 0.8, 1.0, 0.5),
		"desc": "x3 Multiplier, but breaks after scoring.",
		"base_bonus": 0,
		"multiplier": 3.0,
		"tags": ["break_on_score"],
		"effects": [
			{"trigger": "after_score", "action": "break_slot"} # Custom action
		]
	},
	"ball_lucky": {
		"name": "Lucky Ball",
		"rarity": "blessed",
		"visual_color": Color(0.2, 0.8, 0.2),
		"desc": "50% Chance for x2 Multiplier.",
		"base_bonus": 0,
		"multiplier": 1.0,
		"tags": ["chance_mult_2_50"],
		"effects": [
			{"trigger": "on_calc", "chance": 0.5, "mult_add": 1.0} # Adds +1x to mult (total 2x)
		]
	},

	# --- DIVINE (Rare) ---
	"ball_gold": {
		"name": "Golden Ball",
		"rarity": "divine",
		"visual_color": Color(1.0, 0.84, 0.0),
		"desc": "x5 Multiplier.",
		"base_bonus": 0,
		"multiplier": 5.0,
		"tags": [],
		"effects": []
	},
	"ball_wild": {
		"name": "Wild Ball",
		"rarity": "divine",
		"visual_color": Color(0.6, 0.0, 0.8),
		"desc": "Counts as a Perfect Match anywhere.",
		"base_bonus": 0,
		"multiplier": 1.0,
		"tags": ["wild"],
		"effects": [
			{"trigger": "force_perfect_match"}
		]
	},
	
	# --- GODLY (Legendary) ---
	"ball_god": {
		"name": "God Ball",
		"rarity": "godly",
		"visual_color": Color(10, 10, 10), # HDR White (Glowing)
		"base_bonus": 1000,
		"multiplier": 10.0,
		"tags": ["wild"],
		"effects": [
			{"trigger": "force_perfect_match"}
		]
	}
}

func get_data(type_id: String) -> Dictionary:
	if DB.has(type_id):
		return DB[type_id]
	return DB["ball_standard"]

func get_random_by_rarity(rarity_tier: String) -> String:
	# Helper for shop generation later
	var candidates = []
	for key in DB:
		if DB[key]["rarity"] == rarity_tier:
			candidates.append(key)
	if candidates.is_empty(): return "ball_standard"
	return candidates.pick_random()
