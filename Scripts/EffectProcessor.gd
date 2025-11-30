extends Node
class_name EffectProcessor

static func calculate(ball_id: String, type_id: String, slot_data: Dictionary, grid_context: Dictionary) -> Dictionary:
	
	# 1. Fetch Ball Data
	var data = BallDatabase.get_data(type_id)
	var tags = data["tags"]
	
	# --- SAFETY CHECK ---
	# If this is a Bench slot or invalid ID, return 0 (don't score)
	if not "-" in ball_id or not "-" in slot_data["target_id"]:
		return { "points": 0, "break_slot": false, "is_perfect": false }
	# --------------------

	# Parse IDs (e.g., "B-5" -> "B", 5)
	var b_parts = ball_id.split("-")
	var b_let = b_parts[0]
	var b_num = int(b_parts[1])
	
	var s_parts = slot_data["target_id"].split("-")
	var s_let = s_parts[0]
	var s_num = int(s_parts[1])
	
	# 2. Base Points (The "Chips")
	# Value comes purely from the ball number (1-15) + any special bonus from the ball type
	var points = b_num + data["base_bonus"]
	var multiplier = data["multiplier"]
	var break_slot_flag = false
	var is_perfect = false
	
	# 3. Match Logic
	var is_wild = tags.has("wild")
	
	if is_wild:
		points += 20 # Wilds give a nice flat bonus
		is_perfect = true
		
	elif b_let == s_let: # SAME LETTER (e.g. "B" on "B" column)
		if b_num == s_num: 
			# PERFECT MATCH (B-5 on B-5)
			points += 50 # Reward: Moderate (Wait for the line mult to make it huge!)
			is_perfect = true
		else: 
			# COLOR MATCH (B-5 on B-10)
			points += 10 # Reward: Small but feels good
	
	# (Note: If letter doesn't match, you just get the 'points' from Step 2)

	# 4. Complex Effects Loop (Unchanged)
	for effect in data["effects"]:
		var trigger = effect.get("trigger")
		match trigger:
			"check_column":
				if effect["cols"].has(slot_data["grid_x"]):
					points += effect["bonus"]
			"check_adjacency":
				if grid_context.get("has_neighbor", false):
					points += effect["bonus"]
			"on_calc":
				if effect.has("chance"):
					if randf() < effect["chance"]:
						multiplier += effect.get("mult_add", 0.0)
			"after_score":
				if effect.get("action") == "break_slot":
					break_slot_flag = true

	# 5. Slot Upgrades (Context)
	points += slot_data.get("permanent_bonus", 0)
	points = int(points * slot_data.get("permanent_multiplier", 1.0))
	
	# 6. Final Calculation
	var final_score = int(points * multiplier)
	
	# FAILSAFE: Ensure we never return 0 for a valid ball, or it might look invisible
	if final_score < 1: final_score = 1
	
	return {
		"points": final_score,
		"break_slot": break_slot_flag,
		"is_perfect": is_perfect
	}
