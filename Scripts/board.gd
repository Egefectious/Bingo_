extends Node3D
class_name BoardV4

# --- Configuration ---
@export_group("References")
@export var slot_scene: PackedScene 
@export var ball_scene: PackedScene 
@export var bench_container: Node3D 

@export_group("Game Rules")
@export var target_score: int = 500 
@export var max_rounds: int = 3
@export var balls_per_round: int = 5
@export var grid_spacing: float = 1.2 
@export var special_ball_count: int = 3 
@export var sound_score: AudioStream # Drag your "pop" sound here
@export var sound_line_win: AudioStream # Drag your "shimmer" sound here
@export var particle_manager: Node # Link to your manager if not autoloaded
@export var win_beam_scene: PackedScene
@export_group("Navigation")
@export_file("*.tscn") var shop_scene_path: String
# --- State ---
var grid: Array = [] 
const GRID_SIZE = 5


var current_round: int = 1
var balls_dealt_this_round: int = 0
var total_score: int = 0
var dealt_ball_ref: RigidBody3D = null 
var singles_to_score = []

# Deck Local Copy
var ball_deck: Array = [] 

func _ready() -> void:
	randomize()
	if not slot_scene or not bench_container: 
		print("ERROR: Assign Slot Scene and Bench Container!")
		return
	
	add_to_group("Board") 
	
	var gm = get_node_or_null("/root/GameManager")
	if gm:
		var level = gm.current_level
		target_score = gm.target_score_base + (level * 250)
		print("Level: ", level, " Target: ", target_score)

	_generate_grid()
	_setup_bench()
	_spawn_labels()
	_initialize_smart_deck()
	_update_ui()

# --- DEALING LOGIC ---
func deal_ball() -> void:
	if dealt_ball_ref != null:
		print("Play the current ball first!")
		return

	if balls_dealt_this_round >= balls_per_round:
		if current_round < max_rounds:
			_start_next_round()
			return
		else:
			print("Final Round! You must Score.")
			return
	
	var new_ball = ball_scene.instantiate()
	add_child(new_ball)
	new_ball.global_position = Vector3(0, 2, 4) 
	
	# Smart Deck Logic
	if ball_deck.is_empty():
		var r_col = ["B", "I", "N", "G", "O"].pick_random()
		var r_num = randi_range(1, 15) 
		new_ball.setup_ball(r_col + "-" + str(r_num), "ball_standard")
	else:
		var data = ball_deck.pop_front()
		new_ball.setup_ball(data["id"], data["type"])
	
	dealt_ball_ref = new_ball
	balls_dealt_this_round += 1
	_update_ui()

func on_ball_snapped(ball: RigidBody3D) -> void:
	if ball == dealt_ball_ref:
		dealt_ball_ref = null

func _start_next_round() -> void:
	print("Round ", current_round, " Finished.")
	
	# 1. Visual Feedback
	var center_pos = grid[2][2].global_position + Vector3(0, 2, 0)
	_spawn_floating_text(center_pos, "NEXT ROUND", 1.5)
	
	# 2. Audio Cue (Optional: Add a specific sound for this later)
	# SoundManager.play_round_change() 
	
	current_round += 1
	balls_dealt_this_round = 0
	_update_ui() 
	
	# 3. Unlock Input
	get_tree().call_group("UI", "toggle_input", true)


# --- HELPER FUNCTIONS ---
func _generate_unique_id_for_col(col_idx: int) -> String:
	var letters = ["B", "I", "N", "G", "O"]
	var letter = letters[col_idx]
	var unique = false
	var new_id = ""
	
	while not unique:
		var r_num = randi_range(1, 15)
		new_id = letter + "-" + str(r_num)
		unique = true
		for x in range(GRID_SIZE):
			for y in range(GRID_SIZE):
				if grid[x][y].target_id == new_id:
					unique = false; break
			if not unique: break
	return new_id

func _check_neighbors(slot) -> bool:
	var neighbors = [Vector2(0,1), Vector2(0,-1), Vector2(1,0), Vector2(-1,0)]
	for n in neighbors:
		var nx = slot.grid_x + n.x
		var ny = slot.grid_y + n.y
		if nx >= 0 and nx < GRID_SIZE and ny >= 0 and ny < GRID_SIZE:
			if grid[nx][ny].held_ball != null:
				return true
	return false

func _count_lines() -> int:
	var lines = 0
	for y in range(GRID_SIZE):
		var c=0; for x in range(GRID_SIZE): if grid[x][y].held_ball: c+=1
		if c == GRID_SIZE: lines += 1
	for x in range(GRID_SIZE):
		var c=0; for y in range(GRID_SIZE): if grid[x][y].held_ball: c+=1
		if c == GRID_SIZE: lines += 1
	return lines

# --- SMART DECK ---
func _initialize_smart_deck() -> void:
	ball_deck.clear()
	var needed_ids = []
	
	for x in range(GRID_SIZE):
		for y in range(GRID_SIZE):
			var id = grid[x][y].target_id
			# Default winning balls are Standard
			ball_deck.append({"id": id, "type": "ball_standard"})
			needed_ids.append(id)
	
	var fillers = 0
	var extra = 10
	while fillers < extra:
		var rid = _generate_unique_id_for_col(randi()%5) 
		if not needed_ids.has(rid):
			ball_deck.append({"id": rid, "type": "ball_standard"})
			fillers += 1
	
	_inject_special_balls()
	ball_deck.shuffle()

func _inject_special_balls() -> void:
	var gm = get_node_or_null("/root/GameManager")
	if not gm: return
	
	# In a real run, read gm.deck_config["special_types"]
	# For testing, we inject a mix:
	var types = ["ball_red", "ball_blue", "ball_green", "ball_glass", "ball_gold"]
	
	for i in range(5):
		if ball_deck.is_empty(): break
		var idx = randi() % ball_deck.size()
		var entry = ball_deck[idx]
		entry["type"] = types.pick_random()
		ball_deck[idx] = entry

# --- SETUP HELPER FUNCTIONS ---
func _generate_grid() -> void:
	grid.resize(GRID_SIZE)
	var offset = (GRID_SIZE * grid_spacing) / 2.0 - (grid_spacing / 2.0)
	var letters = ["B", "I", "N", "G", "O"]
	var used_ids = []
	for x in range(GRID_SIZE):
		grid[x] = []
		grid[x].resize(GRID_SIZE)
		for y in range(GRID_SIZE):
			var new_slot = slot_scene.instantiate()
			add_child(new_slot)
			var pos_x = (x * grid_spacing) - offset
			var pos_z = (y * grid_spacing) - offset
			new_slot.position = Vector3(pos_x, 0.05, pos_z)
			var unique = false; var id = ""
			while not unique:
				id = letters[x] + "-" + str(randi_range(1, 15))
				if not used_ids.has(id): unique = true; used_ids.append(id)
			new_slot.setup_slot(id, x, y)
			grid[x][y] = new_slot

func _setup_bench() -> void:
	for child in bench_container.get_children():
		if child.has_method("setup_slot"): child.setup_slot("BENCH", -1, -1)

func _spawn_labels() -> void:
	var offset = (GRID_SIZE * grid_spacing) / 2.0
	var letters = ["B", "I", "N", "G", "O"]
	for x in range(GRID_SIZE):
		var lbl = Label3D.new()
		add_child(lbl)
		lbl.text = letters[x]
		lbl.font_size = 64
		lbl.outline_size = 12
		lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lbl.position = Vector3((x * grid_spacing) - (offset - (grid_spacing/2.0)), 0.5, -offset - 0.8)
		lbl.modulate = Color.GOLD

func _update_ui() -> void:
	get_tree().call_group("UI", "update_round_info", current_round, max_rounds, balls_dealt_this_round, balls_per_round)
	get_tree().call_group("UI", "update_score", total_score, target_score)
	
# Replace your entire cash_out function with this:
func cash_out() -> void:
	# 1. Lock Interaction and Reset Audio Pitch
	get_tree().call_group("UI", "toggle_input", false) 
	SoundManager.reset_pitch()
	
	var processed_balls: Array = [] 
	
	# --- PHASE 1: IDENTIFY PATTERNS ---
	var active_lines = _detect_paylines() 
	
	# Mark balls in lines as "processed" so they don't score as singles first
	for line_data in active_lines:
		for slot in line_data["slots"]:
			if not processed_balls.has(slot):
				processed_balls.append(slot)

	# --- PHASE 2: SCORE SINGLES (The "Leftovers") ---
	var singles_to_score = []
	for x in range(GRID_SIZE):
		for y in range(GRID_SIZE):
			var slot = grid[x][y]
			# Only score if there is a ball AND it hasn't been scored in a line yet
			if slot.held_ball and not processed_balls.has(slot):
				var score = _calculate_single_score(slot)
				singles_to_score.append({"slot": slot, "score": score})
	
	# Sort singles: Lowest score first for dramatic build-up
	singles_to_score.sort_custom(func(a, b): return a["score"] < b["score"])
	
	# Start Slower to build suspense
	var delay_speed = 0.5 
	
	for entry in singles_to_score:
		var slot = entry["slot"]
		var points = entry["score"]
		
		# VISUAL: Only pop if it's worth points
		if points > 0:
			await _animate_score_event(slot, points, delay_speed)
			
			# LOGIC: Add to total
			total_score += points
			_update_ui_score(total_score)
			
			# SPEED UP: Aggressive acceleration (20% faster each pop)
			delay_speed = max(0.05, delay_speed * 0.8)
	
	# --- PHASE 3: SCORE PAYLINES ---
	for line_data in active_lines:
		# Define variables inside the loop so they exist for this specific line
		var line_slots = line_data["slots"]
		var line_type = line_data["type"] 
		var line_subtotal = 0
		
		# VISUAL: SPAWN WIN BEAM
		var start_slot = line_slots[0]
		var end_slot = line_slots[-1]
		_spawn_win_beam(start_slot.global_position, end_slot.global_position)
		
		# A. Highlight the whole line (Rise up slightly)
		await _animate_line_ready(line_slots)
		
		# B. Pop each ball in the line
		var line_pop_speed = 0.15 # Reset speed for the new line
		
		for slot in line_slots:
			var points = _calculate_single_score(slot)
			
			# Check for Slot-specific Multiplier (e.g. from Shop Upgrades)
			if slot.permanent_multiplier > 1.0:
				await _animate_score_event(slot, points, 0.2)
				await _animate_text_popup(slot, "x" + str(slot.permanent_multiplier), Color.RED)
				points *= slot.permanent_multiplier
			
			line_subtotal += points
			
			# Pop final value for this ball
			await _animate_score_event(slot, points, line_pop_speed)
			
			# Accelerate inside the line too!
			line_pop_speed = max(0.02, line_pop_speed * 0.9)
		
		# C. Apply Line Multiplier
		# Pass BOTH arguments to check for "Perfect" status
		var line_mult = _get_line_multiplier(line_type, line_slots)
		
		# VISUAL: Show the Line Win
		await _animate_line_win(line_slots, line_subtotal, line_mult)
		
		total_score += (line_subtotal * line_mult)
		_update_ui_score(total_score)
		
		# Reset line positions
		_reset_line_positions(line_slots)
	
	# --- CLEANUP ---
	# Wait a moment for player to breathe
	await get_tree().create_timer(1.0).timeout
	_cleanup_board()
	
	# Check Win Condition
	if current_round >= max_rounds and balls_dealt_this_round >= balls_per_round:
		_check_game_over()
	else:
		_start_next_round()
		
func _animate_score_event(slot, points, wait_time) -> void:
	# 1. Physics Jump
	var ball = slot.held_ball
	if ball:
		var tween = create_tween()
		tween.tween_property(ball, "position:y", 1.5, 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(ball, "position:y", 0.0, 0.1)
	
	# 2. Particle Pop (Call your manager)
	ParticleManager.play_pop_at(slot.global_position)
	
	# 3. Sound
	SoundManager.play_score_sound(sound_score)
	
	# 4. Floating Text
	_spawn_floating_text(slot.global_position, str(points))
	
	# 5. Wait
	await get_tree().create_timer(wait_time).timeout

func _animate_line_ready(slots: Array) -> void:
	# Lift the whole line up to show "This is what we are scoring"
	var tween = create_tween().set_parallel(true)
	for slot in slots:
		if slot.held_ball:
			tween.tween_property(slot.held_ball, "position:y", 0.5, 0.3)
	await tween.finished

func _animate_line_win(slots: Array, subtotal: int, mult: int) -> void:
	# Dramatic pause
	await get_tree().create_timer(0.2).timeout
	
	# Play heavy sound
	SoundManager.play_mult_sound(sound_line_win)
	
	# Visual: Maybe shake the camera or flash the screen
	# Spawn a giant text in the middle of the line
	var center_slot = slots[slots.size() / 2]
	var text = str(subtotal) + " x " + str(mult) + "!"
	_spawn_floating_text(center_slot.global_position + Vector3(0, 1, 0), text, 2.0)
	
	await get_tree().create_timer(0.8).timeout

func _spawn_floating_text(pos: Vector3, text: String, scale: float = 1.0) -> void:
	var lbl = Label3D.new()
	add_child(lbl)
	lbl.global_position = pos + Vector3(0, 0.5, 0)
	lbl.text = text
	lbl.font_size = 128
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.modulate = Color.GOLD
	lbl.outline_modulate = Color.BLACK
	lbl.outline_size = 24
	
	var tween = create_tween()
	tween.tween_property(lbl, "position:y", lbl.position.y + 1.0, 0.8)
	tween.parallel().tween_property(lbl, "modulate:a", 0.0, 0.8)
	tween.tween_callback(lbl.queue_free)

# --- HELPER: PATTERN DETECTION ---

func _detect_paylines() -> Array:
	var found_lines = []
	
	# 1. Rows & Cols
	for i in range(GRID_SIZE):
		var row_slots = []; var col_slots = []
		var row_full = true; var col_full = true
		
		for j in range(GRID_SIZE):
			# Row check (i is y, j is x) - Adjust based on your grid structure
			if grid[j][i].held_ball: row_slots.append(grid[j][i])
			else: row_full = false
			
			# Col check (i is x, j is y)
			if grid[i][j].held_ball: col_slots.append(grid[i][j])
			else: col_full = false
			
		if row_full: found_lines.append({"type": "Row", "slots": row_slots})
		if col_full: found_lines.append({"type": "Col", "slots": col_slots})

	# 2. Diagonals
	var d1 = []; var d2 = []
	var d1_full = true; var d2_full = true
	for i in range(GRID_SIZE):
		if grid[i][i].held_ball: d1.append(grid[i][i])
		else: d1_full = false
		
		if grid[GRID_SIZE-1-i][i].held_ball: d2.append(grid[GRID_SIZE-1-i][i])
		else: d2_full = false
	
	if d1_full: found_lines.append({"type": "Diag", "slots": d1})
	if d2_full: found_lines.append({"type": "Diag", "slots": d2})
	
	# 3. Corners (0,0), (0,4), (4,0), (4,4)
	var corners = [grid[0][0], grid[4][0], grid[0][4], grid[4][4]]
	if _are_all_filled(corners):
		found_lines.append({"type": "Corners", "slots": corners})
		
	# 4. The Cross (Row 2 + Col 2)
	# Note: This is specific to a 5x5 grid
	var cross_slots = []
	var cross_valid = true
	# Add Row 2
	for x in range(GRID_SIZE): 
		if not grid[x][2].held_ball: cross_valid = false
		else: cross_slots.append(grid[x][2])
	# Add Col 2 (avoid duplicate center 2,2)
	for y in range(GRID_SIZE):
		if y == 2: continue
		if not grid[2][y].held_ball: cross_valid = false
		else: cross_slots.append(grid[2][y])
		
	if cross_valid: found_lines.append({"type": "Cross", "slots": cross_slots})

	# 5. Full House (All spaces) - The Ultimate Win
	var all_slots = []
	var full = true
	for x in range(GRID_SIZE):
		for y in range(GRID_SIZE):
			if not grid[x][y].held_ball: full = false
			all_slots.append(grid[x][y])
	if full: found_lines.append({"type": "FullHouse", "slots": all_slots})

	return found_lines

func _are_all_filled(slots: Array) -> bool:
	for s in slots:
		if s.held_ball == null: return false
	return true

func _calculate_single_score(slot) -> int:
	# Re-use your existing EffectProcessor here!
	# We just want the number, not the side effects yet
	var result = EffectProcessor.calculate(
		slot.held_ball.ball_id,
		slot.held_ball.type_id,
		{ "target_id": slot.target_id, "grid_x": slot.grid_x, "grid_y": slot.grid_y },
		{ "has_neighbor": _check_neighbors(slot) }
	)
	return result["points"]

func _get_line_multiplier(type: String, slots: Array) -> int:
	var is_perfect_line = true
	
	# 1. Check if every ball in the line matches its slot ID exactly
	for slot in slots:
		var ball = slot.held_ball
		if not ball:
			is_perfect_line = false
			break
		
		# PERFECT CHECK: Ball ID must match Slot ID (e.g. "B-5" == "B-5")
		# Note: We can decide if "Wild" balls count as perfect. 
		# For now, let's say only TRUE matches count for the x50 jackpot.
		if ball.ball_id != slot.target_id:
			# If the ball is Wild, maybe allow it? 
			# If not, the line is valid, but not "Perfect"
			if not ball.type_id == "ball_wild": 
				is_perfect_line = false
	
	# 2. Return Multipliers based on your request
	match type:
		"Row": 
			return 5 if is_perfect_line else 2
		"Col": 
			return 5 if is_perfect_line else 2
		"Diag": 
			return 5 if is_perfect_line else 2
		"Corners": 
			return 4 if is_perfect_line else 2
		"Cross": 
			return 8 if is_perfect_line else 4
		"H": 
			return 8 if is_perfect_line else 4
		"FullHouse": 
			# The Holy Grail
			return 50 if is_perfect_line else 10
			
	return 1
	
# --- MISSING HELPER FUNCTIONS ---

# Updates the score on the UI (wraps your existing logic)
func _update_ui_score(score: int) -> void:
	get_tree().call_group("UI", "update_score", score, target_score)

# Handles the "x2" or "x10" popping up in a different color
func _animate_text_popup(slot, text: String, color: Color) -> void:
	# Reuse the floating text logic but with custom color
	var pos = slot.global_position + Vector3(0, 0.5, 0)
	var lbl = Label3D.new()
	add_child(lbl)
	lbl.global_position = pos
	lbl.text = text
	lbl.font_size = 140 # Slightly bigger than normal score
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.modulate = color
	lbl.outline_modulate = Color.WHITE
	lbl.outline_size = 24
	
	var tween = create_tween()
	# Pop up and fade out
	tween.tween_property(lbl, "position:y", lbl.position.y + 1.5, 1.0).set_trans(Tween.TRANS_ELASTIC)
	tween.parallel().tween_property(lbl, "modulate:a", 0.0, 1.0)
	tween.tween_callback(lbl.queue_free)
	
	# Wait a tiny bit so the animation plays out in the sequence
	await get_tree().create_timer(0.3).timeout

# Lowers the balls back down after the line shows off
func _reset_line_positions(slots: Array) -> void:
	var tween = create_tween().set_parallel(true)
	for slot in slots:
		if slot.held_ball:
			tween.tween_property(slot.held_ball, "position:y", 0.0, 0.2)
	await tween.finished

# The logic to remove balls and reset slots (Taken from your original logic)
func _cleanup_board() -> void:
	# 1. Identify which slots had balls that were scored
	for x in range(GRID_SIZE):
		for y in range(GRID_SIZE):
			var slot = grid[x][y]
			if slot.held_ball:
				var ball = slot.held_ball
				
				# Remove ball
				if ball == dealt_ball_ref: dealt_ball_ref = null
				ball.queue_free()
				slot.remove_ball()
				
				# Generate NEW Unique ID for the slot
				var new_id = _generate_unique_id_for_col(slot.grid_x)
				slot.refresh_id(new_id)

# Game Over / Win Check Logic
func _check_game_over() -> void:
	var gm = get_node_or_null("/root/GameManager")
	
	if total_score >= target_score:
		print("YOU WIN! Loading Shop...")
		
		# 1. Save Data
		if gm: gm.level_complete(total_score)
		
		# 2. Change Scene
	if shop_scene_path != "":
		# Slight delay...
		await get_tree().create_timer(1.0).timeout
		if not is_inside_tree(): return
		get_tree().change_scene_to_file(shop_scene_path)
		return
			
	else:
		print("GAME OVER. Retry?")
		# Wait a moment for the player to realize they lost
		await get_tree().create_timer(2.0).timeout
		
		if not is_inside_tree(): return
		
		get_tree().reload_current_scene()
		return # <--- Stop executing here too.
	
func _spawn_win_beam(start_pos: Vector3, end_pos: Vector3) -> void:
	if not win_beam_scene: return
	
	var beam = win_beam_scene.instantiate()
	add_child(beam)
	
	# Position at the midpoint
	var mid_point = (start_pos + end_pos) / 2.0
	beam.global_position = mid_point
	
	# Look at the end point
	beam.look_at(end_pos, Vector3.UP)
	
	# Scale the Z axis to match the distance
	var distance = start_pos.distance_to(end_pos)
	# Add a little padding (+1.0) so it covers the whole balls
	beam.scale.z = distance + 0.5 
	
	# Animate Appearance
	beam.scale.x = 0.0
	beam.scale.y = 0.0
	
	var tween = create_tween()
	# Expand width
	tween.tween_property(beam, "scale:x", 1.0, 0.2).set_trans(Tween.TRANS_ELASTIC)
	tween.parallel().tween_property(beam, "scale:y", 1.0, 0.2).set_trans(Tween.TRANS_ELASTIC)
	
	# Fade out after a second
	tween.tween_interval(0.5)
	tween.tween_property(beam, "scale:x", 0.0, 0.2)
	tween.tween_callback(beam.queue_free)


# Returns the hypothetical score for a ball in a specific slot
func get_score_prediction(ball_id: String, type_id: String, slot_node) -> int:
	# 1. Check Neighbors
	var has_neighbor = _check_neighbors(slot_node)
	
	# 2. Build Context
	var context = {
		"has_neighbor": has_neighbor
	}
	
	# 3. Build Slot Data
	var slot_data = {
		"target_id": slot_node.target_id,
		"grid_x": slot_node.grid_x,
		"grid_y": slot_node.grid_y,
		"permanent_bonus": slot_node.permanent_bonus,
		"permanent_multiplier": slot_node.permanent_multiplier
	}
	
	# 4. Calculate
	var result = EffectProcessor.calculate(ball_id, type_id, slot_data, context)
	return result["points"]
