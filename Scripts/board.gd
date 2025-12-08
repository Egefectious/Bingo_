extends Node3D
class_name BoardEnhanced

# === REFERENCES ===
@export_group("Scenes")
@export var slot_scene: PackedScene 
@export var ball_scene: PackedScene 
@export var score_popup_scene: PackedScene
@export var win_beam_scene: PackedScene

@export_group("Containers")
@export var bench_container: Node3D 

@export_group("Navigation")
@export_file("*.tscn") var shop_scene_path: String

@export_group("Audio")
@export var sound_score: AudioStream 
@export var sound_line_win: AudioStream 

# === STATE ===
var grid: Array = [] 
const GRID_SIZE = 5
const GRID_SPACING = 1.2

var current_round: int = 1
var max_rounds: int = 3
var balls_dealt_this_round: int = 0
var balls_per_round: int = 8
var total_score: int = 0
var target_score: int = 500

var ball_deck: Array = [] 
var dealt_ball_ref: RigidBody3D = null 

# Currency earned this encounter
var pot_obols: int = 0
var pot_essence: int = 0
var pot_fate: int = 0

# Visual feedback
var score_tally_label: Label3D = null
var is_scoring: bool = false

func _ready() -> void:
	add_to_group("Board")
	
	# 1. EASEL POSITIONING
	# Lift it up so the center is at eye level
	position = Vector3(0, 3.0, 0)
	
	# Rotate -70 degrees (Almost standing straight up, leaning back slightly)
	rotation_degrees = Vector3(-70, 0, 0)
	
	# 2. HIDE OLD TABLE
	var table = get_node_or_null("../Environment/TableSurface")
	if table: table.visible = false
	
	# 3. BUILD
	_create_board_frame()
	_generate_grid()
	_setup_free_space()
	_apply_dabber_upgrades()
	_setup_bench()
	_create_neon_header()
	_create_ambient_lighting()
	
	_initialize_deck()
	_update_ui()

func _create_board_frame() -> void:
	# Create the Dark Wood Backing
	var board_mesh = MeshInstance3D.new()
	var box = BoxMesh.new()
	
	# Size: Wide enough for 5 columns, Tall enough for 5 rows + Header
	box.size = Vector3(7.5, 0.5, 9.0) 
	board_mesh.mesh = box
	
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.15, 0.1, 0.05) # Dark Oak
	mat.roughness = 0.8
	board_mesh.material_override = mat
	
	# Shift it down (Y) so it's behind slots
	# Shift it up (Z) slightly so there's room for the "LIMBO" header at the top
	board_mesh.position = Vector3(0, -0.5, -0.5) 
	add_child(board_mesh)

func _create_neon_header() -> void:
	var letters = ["L", "I", "M", "B", "O"]
	var colors = [Color("#ff33cc"), Color("#33ccff"), Color("#33ff66"), Color("#cc33ff"), Color("#ff9933")]
	
	# Center X position
	var start_x = -((GRID_SIZE - 1) * GRID_SPACING) / 2.0
	
	for i in range(5):
		var sign_node = _create_letter_sign(letters[i], colors[i])
		add_child(sign_node)
		
		var x_pos = start_x + (i * GRID_SPACING)
		
		# Position ABOVE the top row (Local Z negative is "Up" on the board surface)
		# Grid top is roughly -2.4, so we put this at -3.8
		sign_node.position = Vector3(x_pos, 0.5, -3.8)
		
		# Tilt it -20 so it faces the player directly, counteracting the board tilt slightly
		sign_node.rotation_degrees.x = -20
		
func _create_letter_sign(letter: String, glow_color: Color) -> Node3D:
	var container = Node3D.new()
	
	# Background panel
	var panel = CSGBox3D.new()
	panel.size = Vector3(0.9, 1.0, 0.1)
	var panel_mat = StandardMaterial3D.new()
	panel_mat.albedo_color = Color(0.08, 0.05, 0.03)
	panel_mat.roughness = 0.9
	panel.material = panel_mat
	container.add_child(panel)
	
	# Letter label
	var label = Label3D.new()
	label.text = letter
	label.font_size = 180
	label.pixel_size = 0.004
	label.position = Vector3(0, 0, 0.1)
	label.modulate = glow_color * 2.5  # HDR glow
	label.outline_size = 10
	label.outline_modulate = glow_color * 0.5
	label.no_depth_test = true
	container.add_child(label)
	
	# Light
	var light = OmniLight3D.new()
	light.light_color = glow_color
	light.light_energy = 2.0
	light.omni_range = 2.5
	light.position = Vector3(0, 0, 0.3)
	container.add_child(light)
	
	# Flicker effect
	var flicker_timer = Timer.new()
	flicker_timer.wait_time = randf_range(3.0, 8.0)
	flicker_timer.autostart = true
	container.add_child(flicker_timer)
	
	flicker_timer.timeout.connect(func():
		var flicker = create_tween()
		flicker.tween_property(light, "light_energy", 0.5, 0.05)
		flicker.tween_property(light, "light_energy", 2.0, 0.05)
		flicker.tween_property(light, "light_energy", 0.1, 0.08)
		flicker.tween_interval(0.08)
		flicker.tween_property(light, "light_energy", 2.0, 0.15)
	)
	
	return container

func _create_ambient_lighting() -> void:
	"""Creates colored spotlights around the board"""
	var positions = [
		Vector3(-3, 4, -3),
		Vector3(3, 4, -3),
		Vector3(-3, 4, 3),
		Vector3(3, 4, 3)
	]
	
	var colors = [
		Color(0.8, 0.2, 1.0),  # Purple
		Color(0.2, 0.8, 1.0),  # Cyan
		Color(1.0, 0.6, 0.2),  # Orange
		Color(1.0, 0.2, 0.6)   # Magenta
	]
	
	for i in range(4):
		var spot = SpotLight3D.new()
		add_child(spot)
		spot.position = positions[i]
		spot.look_at(Vector3.ZERO)
		spot.light_color = colors[i]
		spot.light_energy = 1.5
		spot.spot_range = 8.0
		spot.spot_angle = 40.0
		spot.spot_attenuation = 1.5
		spot.shadow_enabled = true

# ========================================
# GRID GENERATION
# ========================================

func _generate_grid() -> void:
	grid.resize(GRID_SIZE)
	var offset = (GRID_SIZE * GRID_SPACING) / 2.0 - (GRID_SPACING / 2.0)
	var letters = ["L", "I", "M", "B", "O"]
	
	# Generate unique numbers per column (no row duplicates)
	var grid_numbers = []
	for x in range(GRID_SIZE):
		var col_nums = []
		while col_nums.size() < GRID_SIZE:
			var n = randi_range(1, 15)
			if n in col_nums: continue
			
			# Check row conflict
			var row_idx = col_nums.size()
			var conflict = false
			for prev_x in range(grid_numbers.size()):
				if grid_numbers[prev_x][row_idx] == n:
					conflict = true
					break
			
			if not conflict:
				col_nums.append(n)
		
		grid_numbers.append(col_nums)
	
	# Create slots
	for x in range(GRID_SIZE):
		grid[x] = []
		for y in range(GRID_SIZE):
			var slot = slot_scene.instantiate()
			add_child(slot)
			
			var pos_x = (x * GRID_SPACING) - offset
			var pos_z = (y * GRID_SPACING) - offset
			slot.position = Vector3(pos_x, 0, pos_z)
			
			var id = letters[x] + "-" + str(grid_numbers[x][y])
			slot.setup_slot(id, x, y)
			
			grid[x].append(slot)

func _setup_free_space() -> void:
	"""Place a wild ball in center that can't be moved"""
	var center_slot = grid[2][2]
	if center_slot:
		var free_ball = ball_scene.instantiate()
		add_child(free_ball)
		free_ball.setup_ball("FREE", "ball_wild")
		free_ball.snap_to_slot(center_slot.global_position, center_slot)
		center_slot.assign_ball(free_ball)
		free_ball.freeze = true
		free_ball.collision_layer = 0  # Can't be picked up

func _setup_bench() -> void:
	"""Initialize bench slots"""
	if bench_container:
		for child in bench_container.get_children():
			if child.has_method("setup_slot"):
				child.setup_slot("BENCH", -1, -1)

# ========================================
# DECK & ITEMS
# ========================================

func _initialize_deck() -> void:
	ball_deck.clear()
	var gm = get_node_or_null("/root/GameManager")
	
	if gm and not gm.owned_balls.is_empty():
		ball_deck = gm.owned_balls.duplicate(true)
	else:
		# Fallback deck
		var letters = ["L", "I", "M", "B", "O"]
		for l in letters:
			for n in range(1, 16):
				ball_deck.append({"id": l + "-" + str(n), "type": "ball_standard"})
	
	ball_deck.shuffle()

func _apply_dabber_upgrades() -> void:
	"""Apply slot upgrades from purchased dabbers"""
	var gm = get_node_or_null("/root/GameManager")
	if not gm: return
	
	for dab_id in gm.active_dabbers:
		var data = ItemDatabase.get_dabber(dab_id)
		
		match data["target"]:
			"corners":
				_upgrade_slot(0, 0, data)
				_upgrade_slot(0, 4, data)
				_upgrade_slot(4, 0, data)
				_upgrade_slot(4, 4, data)
			
			"center":
				if data["stat"] == "bonus":
					grid[2][2].line_bonus += int(data["value"])
				else:
					_upgrade_slot(2, 2, data)
			
			"rows":
				if data.has("rows"):
					for row_idx in data["rows"]:
						for x in range(GRID_SIZE):
							_upgrade_slot(x, row_idx, data)

func _upgrade_slot(x: int, y: int, data: Dictionary) -> void:
	if x < 0 or x >= GRID_SIZE or y < 0 or y >= GRID_SIZE: return
	
	var slot = grid[x][y]
	
	if data["stat"] == "multiplier":
		slot.permanent_multiplier *= data["value"]
	elif data["stat"] == "bonus":
		slot.permanent_bonus += int(data["value"])
	
	slot.update_indicator()

func _apply_artifact_modifiers() -> void:
	"""Apply deck modifications from artifacts"""
	var gm = get_node_or_null("/root/GameManager")
	if not gm: return
	
	for art_id in gm.active_artifacts:
		var data = ItemDatabase.get_artifact(art_id)
		
		match data["effect"]:
			"deck_skew":
				var min_v = data["range"][0]
				var max_v = data["range"][1]
				for i in range(data["amount"]):
					var num = randi_range(min_v, max_v)
					var col = ["L", "I", "M", "B", "O"].pick_random()
					ball_deck.insert(randi() % ball_deck.size(), {
						"id": col + "-" + str(num),
						"type": "ball_standard"
					})
			
			"deck_add_type":
				for i in range(data["amount"]):
					var num = randi_range(1, 15)
					var col = ["L", "I", "M", "B", "O"].pick_random()
					ball_deck.insert(0, {
						"id": col + "-" + str(num),
						"type": data["ball_type"]
					})

# ========================================
# GAMEPLAY
# ========================================

func deal_ball() -> void:
	if dealt_ball_ref != null or is_scoring:
		return
	
	# Check if round is over
	if balls_dealt_this_round >= balls_per_round:
		if current_round < max_rounds:
			_start_next_round()
		else:
			_check_encounter_end()
		return
	
	# Create new ball
	var new_ball = ball_scene.instantiate()
	add_child(new_ball)
	new_ball.global_position = Vector3(0, 2, 4)
	
	if ball_deck.is_empty():
		# Emergency fallback
		var col = ["L", "I", "M", "B", "O"].pick_random()
		var num = randi_range(1, 15)
		new_ball.setup_ball(col + "-" + str(num), "ball_standard")
	else:
		var data = ball_deck.pop_front()
		new_ball.setup_ball(data["id"], data["type"])
	
	dealt_ball_ref = new_ball
	balls_dealt_this_round += 1
	_update_ui()

func on_ball_snapped(ball: RigidBody3D) -> void:
	"""Called when a ball is placed in a slot"""
	if ball == dealt_ball_ref:
		dealt_ball_ref = null

func cash_out() -> void:
	"""Score all balls on the board"""
	if is_scoring:
		return
	
	is_scoring = true
	get_tree().call_group("UI", "toggle_input", false)
	
	if score_tally_label:
		score_tally_label.text = "0"
		score_tally_label.visible = true
		score_tally_label.modulate = Color.WHITE
	
	var round_score = 0
	var round_essence = 0
	
	# Phase 1: Detect winning lines
	var winning_lines = _detect_paylines()
	var scored_slots = []
	
	# Mark all slots in winning lines
	for line_data in winning_lines:
		for slot in line_data["slots"]:
			if not scored_slots.has(slot):
				scored_slots.append(slot)
	
	# Phase 2: Score single balls (not in lines)
	var singles = []
	for x in range(GRID_SIZE):
		for y in range(GRID_SIZE):
			var slot = grid[x][y]
			if slot.held_ball and not scored_slots.has(slot):
				singles.append(slot)
	
	# Sort by score (lowest first for dramatic buildup)
	singles.sort_custom(func(a, b):
		var a_result = _calculate_score(a)
		var b_result = _calculate_score(b)
		return a_result["points"] < b_result["points"]
	)
	
	# Score singles with visual feedback
	for slot in singles:
		var result = _calculate_score(slot)
		var points = result["points"]
		
		if points > 0:
			await _animate_single_score(slot, points, result["is_perfect"])
			
			round_score += points
			total_score += points
			
			if result["is_perfect"]:
				round_essence += 1
			
			_update_tally(total_score)
	
	# Phase 3: Score winning lines
	for line_data in winning_lines:
		round_essence += 10  # Bonus essence per line
		
		await _animate_line_score(line_data)
		
		var line_score = 0
		for slot in line_data["slots"]:
			var result = _calculate_score(slot)
			line_score += result["points"]
			
			if result["is_perfect"]:
				round_essence += 1
		
		# Apply line multiplier
		var multiplier = _get_line_multiplier(line_data["type"])
		var final_line_score = line_score * multiplier
		
		round_score += final_line_score
		total_score += final_line_score
		
		_update_tally(total_score)
		
		await get_tree().create_timer(0.5).timeout
	
	# Phase 4: Calculate rewards
	var round_obols = int(round_score * 0.1)
	pot_obols += round_obols
	pot_essence += round_essence
	
	print("Round complete: %d score, %d obols, %d essence" % [round_score, round_obols, round_essence])
	
	await get_tree().create_timer(1.0).timeout
	
	if score_tally_label:
		score_tally_label.visible = false
	
	_cleanup_board()
	_check_encounter_end()

# ========================================
# SCORING CALCULATIONS
# ========================================

func _calculate_score(slot) -> Dictionary:
	"""Calculate score for a ball in a slot"""
	if not slot.held_ball:
		return {"points": 0, "is_perfect": false}
	
	var ball_id = slot.held_ball.ball_id
	var type_id = slot.held_ball.type_id
	var data = BallDatabase.get_data(type_id)
	
	# Base calculation
	var b_parts = ball_id.split("-")
	var s_parts = slot.target_id.split("-")
	
	if b_parts.size() < 2 or s_parts.size() < 2:
		return {"points": 0, "is_perfect": false}
	
	var b_num = int(b_parts[1]) if b_parts[1].is_valid_int() else 0
	var s_num = int(s_parts[1]) if s_parts[1].is_valid_int() else 0
	
	var points = b_num + data["base_bonus"] + slot.permanent_bonus
	var is_perfect = false
	
	# Check match
	var is_wild = data["tags"].has("wild")
	
	if is_wild:
		points += 20
		is_perfect = true
	elif b_parts[0] == s_parts[0]:  # Letter match
		if b_num == s_num:  # Perfect match
			points += 50
			is_perfect = true
		else:
			points += 10
	
	# Apply slot multiplier
	if slot.permanent_multiplier > 1.0:
		points = int(points * slot.permanent_multiplier)
	
	# Apply ball multiplier
	points = int(points * data["multiplier"])
	
	return {
		"points": max(1, points),
		"is_perfect": is_perfect or data["tags"].has("force_essence")
	}

func _detect_paylines() -> Array:
	"""Find all complete lines (rows, columns, diagonals)"""
	var lines = []
	
	# Rows
	for y in range(GRID_SIZE):
		var slots = []
		var complete = true
		
		for x in range(GRID_SIZE):
			if grid[x][y].held_ball:
				slots.append(grid[x][y])
			else:
				complete = false
				break
		
		if complete:
			lines.append({"type": "Row", "slots": slots})
	
	# Columns
	for x in range(GRID_SIZE):
		var slots = []
		var complete = true
		
		for y in range(GRID_SIZE):
			if grid[x][y].held_ball:
				slots.append(grid[x][y])
			else:
				complete = false
				break
		
		if complete:
			lines.append({"type": "Column", "slots": slots})
	
	# Diagonal 1 (top-left to bottom-right)
	var diag1 = []
	var diag1_complete = true
	for i in range(GRID_SIZE):
		if grid[i][i].held_ball:
			diag1.append(grid[i][i])
		else:
			diag1_complete = false
			break
	
	if diag1_complete:
		lines.append({"type": "Diagonal", "slots": diag1})
	
	# Diagonal 2 (top-right to bottom-left)
	var diag2 = []
	var diag2_complete = true
	for i in range(GRID_SIZE):
		if grid[GRID_SIZE - 1 - i][i].held_ball:
			diag2.append(grid[GRID_SIZE - 1 - i][i])
		else:
			diag2_complete = false
			break
	
	if diag2_complete:
		lines.append({"type": "Diagonal", "slots": diag2})
	
	return lines

func _get_line_multiplier(line_type: String) -> int:
	match line_type:
		"Row", "Column": return 3
		"Diagonal": return 5
	return 2

# ========================================
# VISUAL EFFECTS
# ========================================

func _create_score_display() -> void:
	"""Create floating score tally display"""
	score_tally_label = Label3D.new()
	add_child(score_tally_label)
	score_tally_label.position = Vector3(0, 3.5, 0)
	score_tally_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	score_tally_label.no_depth_test = true
	score_tally_label.font_size = 150
	score_tally_label.outline_size = 30
	score_tally_label.outline_modulate = Color.BLACK
	score_tally_label.visible = false

func _update_tally(value: int) -> void:
	"""Update the floating tally with animation"""
	if not score_tally_label: return
	
	score_tally_label.text = str(value)
	
	# Pulse effect
	var tween = create_tween()
	tween.tween_property(score_tally_label, "scale", Vector3(1.3, 1.3, 1.3), 0.1)
	tween.tween_property(score_tally_label, "scale", Vector3.ONE, 0.1)
	
	# Color based on progress
	var progress = float(value) / float(target_score)
	if progress >= 1.0:
		score_tally_label.modulate = Color.GOLD
	elif progress >= 0.75:
		score_tally_label.modulate = Color.GREEN
	elif progress >= 0.5:
		score_tally_label.modulate = Color.YELLOW
	else:
		score_tally_label.modulate = Color.WHITE

func _animate_single_score(slot, points: int, is_perfect: bool) -> void:
	"""Animate scoring a single ball"""
	var ball = slot.held_ball
	if ball:
		# Bounce up
		var tween = create_tween()
		tween.tween_property(ball, "position:y", 0.8, 0.15).set_trans(Tween.TRANS_BACK)
		tween.tween_property(ball, "position:y", 0.0, 0.15).set_trans(Tween.TRANS_BOUNCE)
	
	# Show points
	_spawn_popup(slot.global_position, "+" + str(points), Color.YELLOW if is_perfect else Color.WHITE)
	
	# Particle effect
	if is_perfect:
		ParticleManager.play_perfect_burst(slot.global_position)
	else:
		ParticleManager.play_pop_at(slot.global_position, 1.0)
	
	# Sound
	if sound_score:
		SoundManager.play_score_sound(sound_score)
	
	await get_tree().create_timer(0.3).timeout

func _animate_line_score(line_data: Dictionary) -> void:
	"""Animate scoring a complete line"""
	var slots = line_data["slots"]
	
	# Highlight all balls in line
	for slot in slots:
		if slot.held_ball:
			var tween = create_tween()
			tween.tween_property(slot.held_ball, "position:y", 1.0, 0.2)
	
	# Show win beam
	if win_beam_scene and slots.size() > 0:
		var beam = win_beam_scene.instantiate()
		add_child(beam)
		
		var start = slots[0].global_position
		var end = slots[-1].global_position
		var mid = (start + end) / 2.0
		
		beam.global_position = mid
		beam.look_at(end)
		beam.scale.z = start.distance_to(end)
		
		# Beam animation
		var tween = create_tween()
		tween.tween_property(beam, "scale:x", 1.5, 0.3).from(0.0).set_trans(Tween.TRANS_ELASTIC)
		tween.parallel().tween_property(beam, "scale:y", 1.5, 0.3).from(0.0).set_trans(Tween.TRANS_ELASTIC)
		tween.tween_interval(1.0)
		tween.tween_property(beam, "scale:x", 0.0, 0.2)
		tween.tween_callback(beam.queue_free)
	
	# Show line type
	var center_slot = slots[slots.size() / 2]
	_spawn_popup(center_slot.global_position + Vector3(0, 1.5, 0), line_data["type"] + "!", Color.GOLD)
	
	# Sound
	if sound_line_win:
		SoundManager.play_mult_sound(sound_line_win)
	
	# Particle trail
	ParticleManager.play_line_explosion(slots[0].global_position, slots[-1].global_position)
	
	await get_tree().create_timer(1.5).timeout
	
	# Return balls to normal position
	for slot in slots:
		if slot.held_ball:
			var tween = create_tween()
			tween.tween_property(slot.held_ball, "position:y", 0.0, 0.2)

func _spawn_popup(pos: Vector3, text: String, color: Color) -> void:
	"""Spawn a floating text popup"""
	if not score_popup_scene: return
	
	var popup = score_popup_scene.instantiate()
	add_child(popup)
	popup.global_position = pos
	
	if popup.has_method("setup"):
		if text.begins_with("+"):
			popup.setup(int(text.substr(1)), "", color)
		else:
			popup.setup(0, text, color)

# ========================================
# ROUND MANAGEMENT
# ========================================

func _start_next_round() -> void:
	"""Advance to next round"""
	current_round += 1
	balls_dealt_this_round = 0
	is_scoring = false
	
	_update_ui()
	get_tree().call_group("UI", "toggle_input", true)
	
	# Show round announcement
	_spawn_popup(Vector3(0, 2, 0), "ROUND " + str(current_round), Color.CYAN)

func _check_encounter_end() -> void:
	"""Check if encounter is won or lost"""
	is_scoring = false
	
	var potential_fate = 0
	if current_round == 1: potential_fate = 30
	elif current_round == 2: potential_fate = 10
	elif current_round == 3: potential_fate = 5
	
	if total_score >= target_score:
		# WIN!
		pot_fate = potential_fate
		_handle_victory()
	else:
		# Check if we have more rounds
		if current_round < max_rounds:
			_start_next_round()
		else:
			_handle_defeat()

func _handle_victory() -> void:
	"""Player won the encounter"""
	print("VICTORY! Banking rewards...")
	_spawn_popup(Vector3(0, 2.5, 0), "ESCAPED!", Color.GOLD)
	
	var gm = get_node_or_null("/root/GameManager")
	if gm:
		gm.encounter_won(pot_obols, pot_essence, pot_fate)
	
	await get_tree().create_timer(2.0).timeout
	
	if shop_scene_path != "":
		get_tree().change_scene_to_file(shop_scene_path)

func _handle_defeat() -> void:
	"""Player lost the encounter"""
	print("DEFEATED...")
	_spawn_popup(Vector3(0, 2.5, 0), "LOST IN LIMBO", Color.RED)
	
	var gm = get_node_or_null("/root/GameManager")
	if gm:
		gm.game_over()
		gm.start_new_run()
	
	await get_tree().create_timer(2.0).timeout
	
	if shop_scene_path != "":
		get_tree().change_scene_to_file(shop_scene_path)

func _cleanup_board() -> void:
	"""Remove all balls from grid and refresh slot IDs"""
	for x in range(GRID_SIZE):
		for y in range(GRID_SIZE):
			var slot = grid[x][y]
			
			if slot.held_ball:
				# Free the ball
				if slot.held_ball == dealt_ball_ref:
					dealt_ball_ref = null
				
				slot.held_ball.queue_free()
				slot.remove_ball()
				
				# Generate new random number for this slot
				var letters = ["L", "I", "M", "B", "O"]
				var new_num = randi_range(1, 15)
				var new_id = letters[slot.grid_x] + "-" + str(new_num)
				slot.refresh_id(new_id)

# ========================================
# UI UPDATES
# ========================================

func _update_ui() -> void:
	"""Update all UI elements"""
	get_tree().call_group("UI", "update_round_info", 
		current_round, max_rounds, 
		balls_dealt_this_round, balls_per_round
	)
	get_tree().call_group("UI", "update_score", total_score, target_score)
	get_tree().call_group("UI", "update_deck_count", ball_deck.size(), ball_deck.size() + balls_dealt_this_round)

# ========================================
# SCORE PREDICTION (For Ghost Label)
# ========================================

func get_score_prediction(ball_id: String, type_id: String, slot_node) -> int:
	"""Calculate what score a ball would get if placed in this slot"""
	var result = _calculate_score(slot_node)
	
	# This is a simplified prediction - full context would require
	# temporarily placing the ball, but that's expensive
	return result["points"] if slot_node.held_ball else 0
