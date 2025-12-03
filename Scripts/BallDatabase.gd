extends Node

# THE LIMBO LODGE CATALOG


const DB = {
	# --- MORTAL (Common - 60%) ---

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
		"visual_color": Color(0.8, 0.1, 0.1), # Crimson
		"desc": "+10 bonus points when placed.", # [cite: 20]
		"base_bonus": 10,
		"multiplier": 1.0,
		"tags": [],
		"effects": []
	},
	"ball_blue": {
		"name": "Blue Ball",
		"rarity": "mortal",
		"visual_color": Color(0.1, 0.2, 0.9), # Deep Ocean
		"desc": "+15 points if placed in L or O column.", # [cite: 25] (Adapted for LIMBO)
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
		"visual_color": Color(0.1, 0.6, 0.1), # Forest Green
		"desc": "+20 points if adjacent to another ball.", # [cite: 30]
		"base_bonus": 0,
		"multiplier": 1.0,
		"tags": [],
		"effects": [
			{"trigger": "check_adjacency", "bonus": 20}
		]
	},
	"ball_yellow": {
		"name": "Yellow Ball",
		"rarity": "mortal",
		"visual_color": Color(1.0, 0.9, 0.2), # Sunny Yellow
		"desc": "Next ball drawn has +5 bonus points.", # [cite: 35]
		"base_bonus": 0,
		"multiplier": 1.0,
		"tags": ["buff_next_draw"],
		"effects": [
			{"trigger": "on_play_buff", "amount": 5}
		]
	},
	"ball_purple": {
		"name": "Purple Ball",
		"rarity": "mortal",
		"visual_color": Color(0.6, 0.2, 0.8),
		"desc": "+5 points per ball in same column.",
		"base_bonus": 0,
		"multiplier": 1.0,
		"tags": [],
		"effects": [
			{"trigger": "count_column_balls", "bonus_per_ball": 5}
		]
	},
	"ball_orange": {
		"name": "Orange Ball",
		"rarity": "mortal",
		"visual_color": Color(1.0, 0.6, 0.0),
		"desc": "+15 points if placed in center row.",
		"base_bonus": 0,
		"multiplier": 1.0,
		"tags": [],
		"effects": [
			{"trigger": "check_row", "row": 2, "bonus": 15}
		]
	},

	# --- BLESSED (Uncommon - 25%) ---
	
	"ball_silver": {
		"name": "Silver Ball",
		"rarity": "blessed",
		"visual_color": Color(0.75, 0.75, 0.75), # Polished Silver
		"desc": "x2 Multiplier to base score.", # [cite: 67]
		"base_bonus": 0,
		"multiplier": 2.0,
		"tags": [],
		"effects": []
	},
	"ball_lucky": {
		"name": "Lucky Ball",
		"rarity": "blessed",
		"visual_color": Color(0.2, 0.8, 0.2), # Clover Green
		"desc": "50% Chance to score double points.", # [cite: 102]
		"base_bonus": 0,
		"multiplier": 1.0,
		"tags": ["luck"],
		"effects": [
			{"trigger": "on_calc", "chance": 0.5, "mult_add": 1.0} 
		]
	},
	"ball_fire": {
		"name": "Fire Ball",
		"rarity": "blessed",
		"visual_color": Color(1.0, 0.3, 0.0), # Orange-Red
		"desc": "Burns adjacent spaces (x1.5 score).", # [cite: 72]
		"base_bonus": 0,
		"multiplier": 1.0,
		"tags": ["burn_neighbors"],
		"effects": [
			{"trigger": "modify_neighbors", "stat": "multiplier", "amount": 0.5} # Adds +0.5 to neighbors
		]
	},
	"ball_chain": {
		"name": "Chain Ball",
		"rarity": "blessed",
		"visual_color": Color(0.4, 0.4, 0.5), # Silver Links
		"desc": "+10 points per ball already on the grid.", # Adapted from [cite: 97]
		"base_bonus": 0,
		"multiplier": 1.0,
		"tags": [],
		"effects": [
			{"trigger": "count_grid_balls", "bonus_per_ball": 10}
		]
	},
	"ball_wild": {
		"name": "Wild Ball",
		"rarity": "blessed", # [cite: 403]
		"visual_color": Color(0.6, 0.0, 0.8), # Rainbow/Chaos
		"desc": "Counts as a Perfect Match anywhere.", # [cite: 405]
		"base_bonus": 20,
		"multiplier": 1.0,
		"tags": ["wild"],
		"effects": []
	},

	# --- DIVINE (Rare - 10%) ---
	# 
	"ball_gold": {
		"name": "Golden Ball",
		"rarity": "divine",
		"visual_color": Color(1.0, 0.84, 0.0), # Brilliant Gold
		"desc": "x5 Multiplier to base score.", # [cite: 119]
		"base_bonus": 0,
		"multiplier": 5.0,
		"tags": [],
		"effects": []
	},
	"ball_prism": {
		"name": "Prism Ball",
		"rarity": "divine",
		"visual_color": Color(0.8, 1.0, 1.0, 0.7), # Crystal Clear
		"desc": "Wild + x2 Multiplier.", # [cite: 129]
		"base_bonus": 0,
		"multiplier": 2.0,
		"tags": ["wild"],
		"effects": []
	},
	"ball_halo": {
		"name": "Halo Ball",
		"rarity": "divine",
		"visual_color": Color(1.0, 1.0, 0.9), # Glowing White
		"desc": "Always triggers Essence generation (Perfect).", # [cite: 154]
		"base_bonus": 10,
		"multiplier": 1.0,
		"tags": ["force_essence"],
		"effects": []
	},
	
	# --- GODLY (Legendary - 1%) ---
	"ball_god": {
		"name": "God Ball",
		"rarity": "godly",
		"visual_color": Color(5.0, 5.0, 5.0), # HDR White
		"desc": "1,000 Points. x10 Multiplier. Perfection.", # [cite: 223]
		"base_bonus": 1000,
		"multiplier": 10.0,
		"tags": ["wild", "force_essence"],
		"effects": []
	}
}

func get_data(type_id: String) -> Dictionary:
	if DB.has(type_id):
		return DB[type_id]
	return DB["ball_standard"]

func get_random_by_rarity(rarity_tier: String) -> String:
	var candidates = []
	for key in DB:
		if DB[key]["rarity"] == rarity_tier:
			# Check unlocked status via GameManager if needed
			# var gm = get_node_or_null("/root/GameManager")
			# if gm and gm.is_ball_unlocked(key):
			candidates.append(key)
			
	if candidates.is_empty(): return "ball_standard"
	return candidates.pick_random()
