extends Node
class_name EffectProcessor

static func calculate(ball_id: String, type_id: String, slot_data: Dictionary, grid_context: Dictionary) -> Dictionary:
	
	var data = BallDatabase.get_data(type_id)
	var tags = data["tags"]
	
	# --- NEW: Output Log for Visuals ---
	var events: Array = []
	
	# Safety Check
	if not "-" in ball_id or not "-" in slot_data["target_id"]:
		return { "points": 0, "is_perfect": false, "events": [] }

	var b_parts = ball_id.split("-")
	var b_let = b_parts[0]
	var b_num = int(b_parts[1])
	var s_parts = slot_data["target_id"].split("-")
	var s_let = s_parts[0]
	var s_num = int(s_parts[1])
	
	# --- BASE SCORING ---
	var points = b_num + data["base_bonus"]
	var multiplier = data["multiplier"]
	var is_perfect = false
	
	# --- MATCH LOGIC ---
	var is_wild = tags.has("wild")
	
	if is_wild:
		points += 20
		is_perfect = true
		events.append("WILD!")
	elif b_let == s_let: 
		if b_num == s_num:
			points += 50
			is_perfect = true
			events.append("PERFECT!")
		else:
			points += 10
	
	if tags.has("force_essence"):
		is_perfect = true
		events.append("DIVINE")
	
	# --- EFFECTS LOOP ---
	for effect in data["effects"]:
		var trigger = effect.get("trigger")
		match trigger:
			"check_column":
				if effect["cols"].has(slot_data["grid_x"]):
					points += effect["bonus"]
					events.append("EDGE +%s" % effect["bonus"])
					
			"check_adjacency":
				if grid_context.get("has_neighbor", false):
					points += effect["bonus"]
					events.append("NEIGHBOR +%s" % effect["bonus"])
					
			"on_calc":
				if effect.has("chance"):
					if randf() < effect["chance"]:
						multiplier += effect.get("mult_add", 0.0)
						events.append("LUCKY x2!")
			
			"count_grid_balls":
				var count = grid_context.get("total_balls_on_grid", 0)
				var bonus = (count * effect["bonus_per_ball"])
				points += bonus
				if bonus > 0: events.append("CHAIN +%s" % bonus)

	# --- SLOT UPGRADES ---
	points += slot_data.get("permanent_bonus", 0)
	var slot_mult = slot_data.get("permanent_multiplier", 1.0)
	if slot_mult > 1.0:
		points = int(points * slot_mult)
		events.append("SLOT x%s" % slot_mult)
	
	# --- FINAL ---
	var final_score = int(points * multiplier)
	if final_score < 1: final_score = 1
	
	return {
		"points": final_score,
		"is_perfect": is_perfect,
		"events": events # <--- This is the key that was missing!
	}
