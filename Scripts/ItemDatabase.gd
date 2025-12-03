extends Node

# --- DABBERS (Grid Modifiers) ---
# Triggers: "corners", "center", "row", "col"
const DABBERS = {
	"dab_corner": {
		"name": "Corner Stone",
		"desc": "Corner slots score x2 Multiplier.",
		"rarity": "blessed",
		"cost": 5,
		"effect": "slot_mod",
		"target": "corners", 
		"stat": "multiplier",
		"value": 2.0
	},
	"dab_bullseye": {
		"name": "Bullseye",
		"desc": "Center slot gives +50 Bonus Points.",
		"rarity": "mortal",
		"cost": 3,
		"effect": "slot_mod",
		"target": "center",
		"stat": "bonus",
		"value": 50
	},
	"dab_edge_lord": {
		"name": "Edge Lord",
		"desc": "Top and Bottom rows get x1.5 Multiplier.",
		"rarity": "divine",
		"cost": 10,
		"effect": "slot_mod",
		"target": "rows",
		"rows": [0, 4], # Top and Bottom indices
		"stat": "multiplier",
		"value": 1.5
	}
}

# --- ARTIFACTS (RNG/Rule Modifiers) ---
# Triggers: "deck_skew"
const ARTIFACTS = {
	"art_low_roll": {
		"name": "Loaded Die (Low)",
		"desc": "Adds 5 extra balls numbered 1-5 to your deck.",
		"rarity": "mortal",
		"cost": 10,
		"effect": "deck_skew",
		"range": [1, 5],
		"amount": 5
	},
	"art_high_roll": {
		"name": "Loaded Die (High)",
		"desc": "Adds 5 extra balls numbered 10-15 to your deck.",
		"rarity": "mortal",
		"cost": 10,
		"effect": "deck_skew",
		"range": [10, 15],
		"amount": 5
	},
	"art_wild_fate": {
		"name": "Fate's Joker",
		"desc": "Adds 2 guaranteed Wild Balls to every deck.",
		"rarity": "divine",
		"cost": 30,
		"effect": "deck_add_type",
		"ball_type": "ball_wild",
		"amount": 2
	}
}

func get_dabber(id: String) -> Dictionary:
	return DABBERS.get(id, DABBERS["dab_bullseye"])

func get_artifact(id: String) -> Dictionary:
	return ARTIFACTS.get(id, ARTIFACTS["art_low_roll"])
	
# Helpers for Shop Generation
func get_random_dabber() -> Dictionary:
	var key = DABBERS.keys().pick_random()
	var data = DABBERS[key].duplicate()
	data["id"] = key
	return data

func get_random_artifact() -> Dictionary:
	var key = ARTIFACTS.keys().pick_random()
	var data = ARTIFACTS[key].duplicate()
	data["id"] = key
	return data
