extends Node3D
class_name BoardV4

# --- Configuration ---
@export_group("References")
@export var slot_scene: PackedScene 
@export var ball_scene: PackedScene 
@export var bench_container: Node3D 
@export var score_popup_scene: PackedScene

@export_group("Game Rules")
@export var balls_per_round: int = 8
@export var grid_spacing: float = 1.2 
@export_group("Audio")
@export var sound_score: AudioStream 
@export var sound_line_win: AudioStream 
@export var win_beam_scene: PackedScene
@export_group("Navigation")
@export_file("*.tscn") var shop_scene_path: String

# --- State ---
var grid: Array = [] 
const GRID_SIZE = 5

var current_round: int = 1
var max_rounds: int = 3
var balls_dealt_this_round: int = 0
var total_score: int = 0
var target_score: int = 500
var dealt_ball_ref: RigidBody3D = null 

var ball_deck: Array = [] 

var pot_obols: int = 0
var pot_essence: int = 0
var pot_fate: int = 0

var screen_tally_label: Label3D = null
var current_tally: int = 0
var last_milestone_passed: int = 0
# ========================================
# SCREEN CENTER TALLY SYSTEM FUNCTIONS
# ========================================

func _create_screen_tally() -> void:
	screen_tally_label = Label3D.new()
	add_child(screen_tally_label)
	screen_tally_label.global_position = Vector3(0, 3, 0)
	screen_tally_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	screen_tally_label.no_depth_test = true
	screen_tally_label.font_size = 200
	screen_tally_label.outline_size = 40
	screen_tally_label.outline_modulate = Color.BLACK
	screen_tally_label.modulate = Color.GOLD
	screen_tally_label.visible = false

func _show_screen_tally(value: int) -> void:
	if not screen_tally_label: return
	screen_tally_label.text = str(value)
	screen_tally_label.visible = true
	screen_tally_label.modulate = Color.WHITE
	screen_tally_label.scale = Vector3.ONE

func _update_screen_tally(value: int, is_big: bool) -> void:
	if not screen_tally_label: return
	screen_tally_label.text = str(value)
	
	if is_big:
		var tween = create_tween()
		tween.tween_property(screen_tally_label, "scale", Vector3(1.5, 1.5, 1.5), 0.1)
		tween.tween_property(screen_tally_label, "scale", Vector3.ONE, 0.1)
		screen_tally_label.modulate = Color.GOLD

func _hide_screen_tally() -> void:
	if not screen_tally_label: return
	var tween = create_tween()
	tween.tween_property(screen_tally_label, "modulate:a", 0.0, 0.5)
	tween.tween_callback(func(): screen_tally_label.visible = false)

func _check_milestone(current_val: int) -> void:
	var gm = get_node_or_null("/root/GameManager")
	if not gm: return
	
	for threshold in gm.SCORE_THRESHOLDS:
		if current_val >= threshold and last_milestone_passed < threshold:
			last_milestone_passed = threshold
			_trigger_milestone_celebration(threshold)
			break

func _trigger_perfect_explosion(pos: Vector3) -> void:
	ParticleManager.play_perfect_burst(pos)
	ParticleManager.play_essence_sparkle(pos + Vector3(0, 0.5, 0))
	
	var cam = get_tree().get_first_node_in_group("Camera")
	if cam and cam.has_method("shake_camera"):
		cam.shake_camera(0.1, 0.2)

func _ready() -> void:
	randomize()
	add_to_group("Board") 
	
	var gm = get_node_or_null("/root/GameManager")
	if gm:
		target_score = gm.get_current_target()
		max_rounds = gm.get_max_rounds_for_encounter()
		print("=== %s - Encounter %s ===" % [gm.get_caller_name(), gm.current_encounter_index])
		print("Target: %s | Rounds: %s" % [target_score, max_rounds])
		
		total_score = 0
		pot_obols = 0
		pot_essence = 0
		pot_fate = 0
		current_round = 1
		balls_dealt_this_round = 0
	
	# Generate Grid & Apply Items
	_generate_limbo_grid()
	_setup_free_space()
	_apply_active_dabbers()
	_setup_bench()
	
	
	# Setup Deck & Apply Artifacts
	_initialize_smart_deck()
	_apply_active_artifacts()
	
	# Update UI
	_update_ui()
	
	# Create Screen Center Tally Label
	_create_screen_tally()
	
	# === CREATE NEON SIGNS (FIXED) ===
	_create_neon_signs()
	
	# === ADD ATMOSPHERIC ELEMENTS ===
	_create_atmosphere()
	
	# Opening flavor text
	if gm: 
		var center = Vector3(0, 2, 0)
		_spawn_floating_text(center, gm.get_caller_name(), 1.5, Color.RED)

# ========================================
# NEON SIGN SYSTEM - FIXED
# ========================================

func _create_neon_signs() -> void:
	"""Creates the iconic LIMBO header with neon letter signs"""
	var letters = ["L", "I", "M", "B", "O"]
	var colors = [
		Color(1.0, 0.2, 0.8),  # L - Hot Pink
		Color(0.2, 0.8, 1.0),  # I - Cyan  
		Color(0.2, 1.0, 0.4),  # M - Green
		Color(0.8, 0.2, 1.0),  # B - Purple
		Color(1.0, 0.6, 0.0)   # O - Orange
	]
	
	print("Creating LIMBO neon signs...")
	
	for i in range(5):
		var sign = _create_letter_sign(letters[i], colors[i])
		add_child(sign)
		
		# --- ALIGNMENT FIX ---
		# Use 1.2 spacing to match your grid spacing (so L sits over column 1, I over col 2...)
		var x_pos = (i - 2) * 1.2  
		
		# Position: Y=1.5 (Lowered), Z=-3.5 (Closer)
		sign.position = Vector3(x_pos, 1.5, -3.5)
		
		# Rotation: Angle them up slightly to face the camera at Y=8
		sign.rotation_degrees.x = 25
		
		# Re-enable the sway for atmosphere
		_animate_sign_sway(sign, i)

func _create_letter_sign(letter: String, glow_color: Color) -> Node3D:
	var container = Node3D.new()
	container.name = "NeonSign_" + letter
	
	# 1. Background Panel
	var panel = MeshInstance3D.new()
	panel.mesh = BoxMesh.new()
	panel.mesh.size = Vector3(1.0, 1.2, 0.1) # Slightly tighter backing
	
	var panel_mat = StandardMaterial3D.new()
	panel_mat.albedo_color = Color(0.1, 0.05, 0.02)
	panel_mat.roughness = 0.8
	panel.material_override = panel_mat
	container.add_child(panel)
	
	# 2. The Letter (High Visibility Config)
	var label = Label3D.new()
	label.text = letter
	label.font_size = 200
	label.pixel_size = 0.005
	label.position = Vector3(0, 0, 0.15) 
	
	# Visibility Settings
	label.double_sided = true
	label.no_depth_test = true
	label.render_priority = 100
	label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	
	# HDR GLOW: Multiply RGB by 3, keep Alpha 1.0
	label.modulate = Color(glow_color.r * 3.0, glow_color.g * 3.0, glow_color.b * 3.0, 1.0)
	
	# Contrast Outline
	label.outline_size = 12
	label.outline_modulate = Color(glow_color.r * 0.5, glow_color.g * 0.5, glow_color.b * 0.5, 1.0)
	
	container.add_child(label)
	
	# 3. Ambient Light (Restored)
	var light = OmniLight3D.new()
	light.light_color = glow_color
	light.light_energy = 1.5
	light.omni_range = 2.0
	light.position = Vector3(0, 0, 0.5)
	container.add_child(light)
	
	# Flicker Effect (Restored)
	_setup_flicker_timer(light, label)
	
	return container
	
func _animate_sign_glow(light: OmniLight3D, label: Label3D, base_color: Color) -> void:
	"""Make the neon sign pulse like real neon tubes"""
	var tween = create_tween().set_loops()
	
	# Light energy pulse - slower, more dramatic
	tween.tween_property(light, "light_energy", 5.5, 2.0 + randf() * 0.8).set_trans(Tween.TRANS_SINE)
	tween.tween_property(light, "light_energy", 3.5, 2.0 + randf() * 0.8).set_trans(Tween.TRANS_SINE)
	
	# Use call_deferred to add timer after sign is in scene tree
	call_deferred("_setup_flicker_timer", light, label)

func _setup_flicker_timer(light: OmniLight3D, label: Label3D) -> void:
	var flicker_timer = Timer.new()
	light.add_child(flicker_timer)
	
	# Randomize timing so they don't all blink in unison
	flicker_timer.wait_time = randf_range(3.0, 10.0) 
	flicker_timer.one_shot = false
	
	# CRITICAL FIX: Use autostart to avoid "not in scene tree" errors
	flicker_timer.autostart = true 
	
	flicker_timer.timeout.connect(func():
		# 1. Light Flicker
		var flicker = create_tween()
		flicker.tween_property(light, "light_energy", 0.5, 0.05)
		flicker.tween_property(light, "light_energy", 3.0, 0.05)
		flicker.tween_property(light, "light_energy", 0.0, 0.1) # Brief blackout
		flicker.tween_interval(0.1)
		flicker.tween_property(light, "light_energy", 1.5, 0.2) # Return to normal
		
		# 2. Text Flicker (Matching the light)
		var label_flicker = create_tween()
		label_flicker.tween_property(label, "modulate:a", 0.5, 0.05)
		label_flicker.tween_property(label, "modulate:a", 1.0, 0.05)
		label_flicker.tween_property(label, "modulate:a", 0.1, 0.1)
		label_flicker.tween_interval(0.1)
		label_flicker.tween_property(label, "modulate:a", 1.0, 0.2)
	)

func _animate_sign_sway(sign: Node3D, index: int) -> void:
	"""Subtle hanging chain sway effect - more dramatic"""
	var tween = create_tween().set_loops()
	var sway_amount = 0.08
	var phase_offset = index * 0.5
	
	# Rotation sway
	tween.tween_property(sign, "rotation:z", deg_to_rad(3.0 * sway_amount), 2.5 + phase_offset).set_trans(Tween.TRANS_SINE)
	tween.tween_property(sign, "rotation:z", deg_to_rad(-3.0 * sway_amount), 2.5 + phase_offset).set_trans(Tween.TRANS_SINE)
	
	# Subtle vertical bob
	var bob_tween = create_tween().set_loops()
	bob_tween.tween_property(sign, "position:y", sign.position.y + 0.1, 1.8 + phase_offset * 0.3).set_trans(Tween.TRANS_SINE)
	bob_tween.tween_property(sign, "position:y", sign.position.y - 0.1, 1.8 + phase_offset * 0.3).set_trans(Tween.TRANS_SINE)

func _create_atmosphere() -> void:
	"""Add hanging chains, smoke effects, and ambient details"""
	
	# Create hanging chains from ceiling (visual only)
	for i in range(5):
		var chain_start = Vector3((i - 2) * 1.8, 6.0, -3.5)
		_create_chain_visual(chain_start)
	
	# Add subtle spotlights pointing at the board
	for i in range(4):
		var angle = (TAU / 4.0) * i
		var pos = Vector3(cos(angle) * 4.5, 5.0, sin(angle) * 4.5)
		_create_spotlight(pos, Vector3.ZERO)
	
	# Create ambient fog patches with lights
	_create_fog_patches()

func _create_chain_visual(start_pos: Vector3) -> void:
	"""Create a simple chain hanging from ceiling using cylinders"""
	var chain_links = 8
	var link_height = 0.25
	
	for i in range(chain_links):
		var link = CSGCylinder3D.new()
		link.radius = 0.03
		link.height = link_height
		link.sides = 8
		add_child(link)
		link.position = start_pos - Vector3(0, i * link_height, 0)
		
		var mat = StandardMaterial3D.new()
		mat.albedo_color = Color(0.2, 0.2, 0.25)
		mat.metallic = 0.8
		mat.roughness = 0.4
		link.material = mat
		
		# Subtle sway
		var sway = create_tween().set_loops()
		var offset = randf() * TAU
		sway.tween_property(link, "rotation:z", deg_to_rad(5), 2.0 + offset).set_trans(Tween.TRANS_SINE)
		sway.tween_property(link, "rotation:z", deg_to_rad(-5), 2.0 + offset).set_trans(Tween.TRANS_SINE)

func _create_spotlight(pos: Vector3, target: Vector3) -> void:
	"""Create dramatic spotlights aimed at the board"""
	var spot = SpotLight3D.new()
	add_child(spot)
	spot.position = pos
	spot.look_at(target)
	
	spot.light_color = Color(1.0, 0.95, 0.8)
	spot.light_energy = 2.0
	spot.spot_range = 10.0
	spot.spot_angle = 35.0
	spot.spot_attenuation = 2.0
	spot.shadow_enabled = true
	
	# Subtle flicker
	var flicker = create_tween().set_loops()
	flicker.tween_property(spot, "light_energy", 2.5, randf_range(1.0, 2.0)).set_trans(Tween.TRANS_SINE)
	flicker.tween_property(spot, "light_energy", 1.8, randf_range(1.0, 2.0)).set_trans(Tween.TRANS_SINE)

func _create_fog_patches() -> void:
	"""Create localized fog effects with colored lights"""
	var fog_positions = [
		Vector3(-3, 0.5, -2),
		Vector3(3, 0.5, -2),
		Vector3(-3, 0.5, 2),
		Vector3(3, 0.5, 2)
	]
	
	var fog_colors = [
		Color(0.8, 0.2, 1.0, 0.3),  # Purple
		Color(0.2, 0.8, 1.0, 0.3),  # Cyan
		Color(1.0, 0.5, 0.2, 0.3),  # Orange
		Color(1.0, 0.2, 0.6, 0.3)   # Magenta
	]
	
	for i in range(fog_positions.size()):
		var light = OmniLight3D.new()
		add_child(light)
		light.position = fog_positions[i]
		light.light_color = fog_colors[i]
		light.light_energy = 1.5
		light.omni_range = 2.5
		light.omni_attenuation = 2.5
		
		# Slow pulse
		var pulse = create_tween().set_loops()
		pulse.tween_property(light, "light_energy", 2.0, 3.0 + i * 0.5).set_trans(Tween.TRANS_SINE)
		pulse.tween_property(light, "light_energy", 1.0, 3.0 + i * 0.5).set_trans(Tween.TRANS_SINE)

func _create_neon_letters() -> void:
	var letters = ["L", "I", "M", "B", "O"]
	var colors = [
		Color(0.8, 0.2, 1.0),  # Purple
		Color(0.4, 0.0, 0.8),  # Indigo
		Color(1.0, 0.2, 0.6),  # Magenta
		Color(0.2, 0.4, 1.0),  # Blue
		Color(1.0, 0.6, 0.0)   # Orange
	]
	
	for i in range(5):
		var sign = _create_letter_sign(letters[i], colors[i])
		add_child(sign)
		sign.position = Vector3((i - 2) * 1.5, 4, -3)


func _setup_free_space() -> void:
	# Place a Wild Ball in the center (2,2)
	var center_slot = grid[2][2]
	if center_slot:
		var free_ball = ball_scene.instantiate()
		add_child(free_ball)
		# Use "FREE" as text, logic behaves like a Wild
		free_ball.setup_ball("FREE", "ball_wild") 
		free_ball.snap_to_slot(center_slot.global_position, center_slot)
		center_slot.assign_ball(free_ball)
		# Lock it so it can't be moved? (Optional, but usually Free Space is static)
		free_ball.freeze = true
		
# --- DEALING LOGIC ---
func deal_ball() -> void:
	if dealt_ball_ref != null: return

	# RISK CHECK: If we are out of balls or rounds, we can't deal
	if balls_dealt_this_round >= balls_per_round:
		if current_round < max_rounds:
			_start_next_round()
		else:
			print("Encounter Ending... Checking Score...")
			# This was the typo: _check_encounter_end -> _check_encounter_state
			_check_encounter_state() 
		return
	
	var new_ball = ball_scene.instantiate()
	add_child(new_ball)
	new_ball.global_position = Vector3(0, 2, 4) 
	
	if ball_deck.is_empty():
		# Fallback to random Limbo ball
		var r_col = ["L", "I", "M", "B", "O"].pick_random()
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

# --- THE CASH OUT SYSTEM ---
func cash_out() -> void:
	# 1. Lock Interaction
	get_tree().call_group("UI", "toggle_input", false) 
	SoundManager.reset_pitch()
	
	var processed_balls: Array = [] 
	var round_essence = 0
	var round_score = 0
	
	# --- PHASE 1: IDENTIFY PATTERNS ---
	var active_lines = _detect_paylines() 
	for line_data in active_lines:
		for slot in line_data["slots"]:
			if not processed_balls.has(slot): processed_balls.append(slot)

	# --- PHASE 2: SCORE SINGLES ---
	var singles_to_score = []
	for x in range(GRID_SIZE):
		for y in range(GRID_SIZE):
			var slot = grid[x][y]
			if slot.held_ball and not processed_balls.has(slot):
				var res = _calculate_full_result(slot)
				singles_to_score.append({"slot": slot, "result": res})
	
	singles_to_score.sort_custom(func(a, b): return a["result"]["points"] < b["result"]["points"])
	
	var delay_speed = 0.5 
	
	for entry in singles_to_score:
		var slot = entry["slot"]
		var points = entry["result"]["points"]
		var is_perfect = entry["result"]["is_perfect"]
		var events = entry["result"]["events"]
		
		if points > 0:
			# Trigger Visual Events
			for evt_text in events:
				var col = Color.WHITE
				if "PERFECT" in evt_text: col = Color.CYAN
				elif "LUCKY" in evt_text: col = Color.GREEN
				elif "WILD" in evt_text: col = Color.MAGENTA
				elif "CHAIN" in evt_text: col = Color.ORANGE
				_spawn_floating_text(slot.global_position, evt_text, 0.8, col)
				await get_tree().create_timer(0.15).timeout

			await _animate_score_event(slot, points, delay_speed)
			
			if is_perfect:
				round_essence += 1
				_spawn_floating_text(slot.global_position + Vector3(0,0.5,0), "+1 ESSENCE", 0.5, Color.CYAN)
			
			round_score += points
			total_score += points
			_update_ui_score(total_score)
			delay_speed = max(0.05, delay_speed * 0.8)
	
	# --- PHASE 3: SCORE PAYLINES ---
	for line_data in active_lines:
		var line_slots = line_data["slots"]
		var line_type = line_data["type"] 
		var line_subtotal = 0
		
		# +10 Essence per Line
		round_essence += 10
		
		# VISUALS
		var start_slot = line_slots[0]
		var end_slot = line_slots[-1]
		_spawn_win_beam(start_slot.global_position, end_slot.global_position)
		await _animate_line_ready(line_slots)
		
		var line_pop_speed = 0.15
		
		for slot in line_slots:
			var res = _calculate_full_result(slot)
			var points = res["points"]
			
			if slot.line_bonus > 0:
				points += slot.line_bonus
				_spawn_floating_text(slot.global_position, "BONUS +" + str(slot.line_bonus), 0.5, Color.GREEN)
				
			if res["is_perfect"]: round_essence += 1
			
			if slot.permanent_multiplier > 1.0:
				await _animate_score_event(slot, points, 0.2)
				points = int(points * slot.permanent_multiplier)
			
			line_subtotal += points
			await _animate_score_event(slot, points, line_pop_speed)
			line_pop_speed = max(0.02, line_pop_speed * 0.9)
		
		var line_mult = _get_line_multiplier(line_type, line_slots)
		
		await _animate_line_win(line_slots, line_subtotal, line_mult)
		
		var final_line_score = line_subtotal * line_mult
		round_score += final_line_score
		total_score += final_line_score
		_update_ui_score(total_score)
		
		_reset_line_positions(line_slots)
	
	# --- PHASE 4: BANK CURRENCY ---
	var round_obols = floor(round_score * 0.10)
	
	pot_obols += round_obols
	pot_essence += round_essence
	
	print("HARVEST: %s Score | %s Obols | %s Essence" % [round_score, round_obols, round_essence])
	
	await get_tree().create_timer(1.0).timeout
	_cleanup_board()
	_check_encounter_state()

# --- ENCOUNTER LOGIC ---
func _check_encounter_state() -> void:
	# 1. Calculate Potential Fate (for display/logic)
	var potential_fate = 0
	if current_round == 1: potential_fate = 30
	elif current_round == 2: potential_fate = 10
	elif current_round == 3: potential_fate = 5
	
	# 2. Check Win Condition
	if total_score >= target_score:
		pot_fate = potential_fate
		print("TARGET MET! Depart now to keep %s Fate?" % pot_fate)
		_handle_win_departure()
	else:
		# --- FIX IS HERE ---
		# Previously, this checked "if balls_dealt_this_round >= balls_per_round".
		# We removed that check. Now, if you cash out (end the round), 
		# it naturally progresses to the next round regardless of how many balls you used.
		if current_round < max_rounds:
			_start_next_round()
		else:
			_handle_loss()
		# -------------------

func _handle_win_departure() -> void:
	print("DEPARTING LIMBO...")
	var gm = get_node_or_null("/root/GameManager")
	if gm:
		gm.encounter_won(pot_obols, pot_essence, pot_fate)
		if shop_scene_path != "":
			await get_tree().create_timer(1.0).timeout
			get_tree().change_scene_to_file(shop_scene_path)

func _handle_loss() -> void:
	print("LOST IN LIMBO.")
	var gm = get_node_or_null("/root/GameManager")
	if gm: gm.game_over()
	# Restart run
	if gm: gm.start_new_run()
	await get_tree().create_timer(2.0).timeout
	get_tree().change_scene_to_file(shop_scene_path)

func _start_next_round() -> void:
	current_round += 1
	balls_dealt_this_round = 0
	_update_ui() 
	get_tree().call_group("UI", "toggle_input", true)
	var center_pos = grid[2][2].global_position + Vector3(0, 2, 0)
	_spawn_floating_text(center_pos, "ROUND " + str(current_round), 1.5, Color.WHITE)

func _calculate_full_result(slot) -> Dictionary:
	var total_balls = 0
	var column_balls = 0
	for x in range(GRID_SIZE):
		for y in range(GRID_SIZE):
			if grid[x][y].held_ball != null: 
				total_balls += 1
				if x == slot.grid_x:
					column_balls += 1

	var result = EffectProcessor.calculate(
		slot.held_ball.ball_id,
		slot.held_ball.type_id,
		{ 
			"target_id": slot.target_id, 
			"grid_x": slot.grid_x, 
			"grid_y": slot.grid_y, 
			"permanent_bonus": slot.permanent_bonus, 
			"permanent_multiplier": slot.permanent_multiplier 
		},
		{ 
			"has_neighbor": _check_neighbors(slot),
			"total_balls_on_grid": total_balls,
			"column_balls": column_balls
		}
	)
	
	# === NEW: TRIGGER SPECIAL PARTICLES FOR PERFECTS ===
	if result["is_perfect"]:
		ParticleManager.play_perfect_burst(slot.global_position)
		ParticleManager.play_essence_sparkle(slot.global_position + Vector3(0, 0.8, 0))
	
	return result

# --- GENERATION & SETUP ---
func _generate_limbo_grid() -> void:
	grid.resize(GRID_SIZE)
	var offset = (GRID_SIZE * grid_spacing) / 2.0 - (grid_spacing / 2.0)
	var letters = ["L", "I", "M", "B", "O"]
	
	var grid_numbers = [] 
	for x in range(GRID_SIZE):
		var col_nums = []
		while col_nums.size() < GRID_SIZE:
			var n = randi_range(1, 15)
			if n in col_nums: continue
			
			var current_row_idx = col_nums.size()
			var row_conflict = false
			for prev_x in range(grid_numbers.size()):
				if grid_numbers[prev_x][current_row_idx] == n:
					row_conflict = true
					break
			if not row_conflict: col_nums.append(n)
		grid_numbers.append(col_nums)
	
	for x in range(GRID_SIZE):
		grid[x] = []
		grid[x].resize(GRID_SIZE)
		for y in range(GRID_SIZE):
			var new_slot = slot_scene.instantiate()
			add_child(new_slot)
			var pos_x = (x * grid_spacing) - offset
			var pos_z = (y * grid_spacing) - offset
			new_slot.position = Vector3(pos_x, 0.05, pos_z)
			var id = letters[x] + "-" + str(grid_numbers[x][y])
			new_slot.setup_slot(id, x, y)
			grid[x][y] = new_slot

# --- MISSING HELPER FUNCTIONS RESTORED BELOW ---

func _setup_bench() -> void:
	if bench_container:
		for child in bench_container.get_children():
			if child.has_method("setup_slot"): child.setup_slot("BENCH", -1, -1)

func _spawn_labels() -> void:
	var offset = (GRID_SIZE * grid_spacing) / 2.0
	var letters = ["L", "I", "M", "B", "O"]
	for x in range(GRID_SIZE):
		var lbl = Label3D.new()
		add_child(lbl)
		lbl.text = letters[x]
		lbl.font_size = 64
		lbl.outline_size = 12
		lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lbl.position = Vector3((x * grid_spacing) - (offset - (grid_spacing/2.0)), 0.5, -offset - 0.8)
		match x:
			0: lbl.modulate = Color(0.6, 0.2, 0.8) # L
			1: lbl.modulate = Color(0.3, 0.0, 0.5) # I
			2: lbl.modulate = Color(0.8, 0.0, 0.4) # M
			3: lbl.modulate = Color(0.0, 0.2, 0.8) # B
			4: lbl.modulate = Color(1.0, 0.5, 0.0) # O

func _initialize_smart_deck() -> void:
	ball_deck.clear()
	var gm = get_node_or_null("/root/GameManager")
	
	if gm:
		print("Loading Persistent Deck: " + str(gm.owned_balls.size()) + " balls.")
		# Create a deep copy so we don't delete balls from the save file when we deal them
		ball_deck = gm.owned_balls.duplicate(true)
	else:
		# Fallback if testing scene directly
		var letters = ["L", "I", "M", "B", "O"]
		for l in letters:
			for n in range(1, 16):
				ball_deck.append({ "id": l + "-" + str(n), "type": "ball_standard" })

	ball_deck.shuffle()
	
# --- ITEM APPLICATION ---
func _apply_active_dabbers() -> void:
	var gm = get_node_or_null("/root/GameManager")
	if not gm: return
	for dab_id in gm.active_dabbers:
		var data = ItemDatabase.get_dabber(dab_id)
		match data["target"]:
			"corners":
				_buff_slot(0, 0, data); _buff_slot(0, 4, data);
				_buff_slot(4, 0, data); _buff_slot(4, 4, data)
			"center":
				# SPECIAL HANDLING FOR CENTER
				if data["stat"] == "bonus":
					var slot = grid[2][2]
					slot.line_bonus += int(data["value"])
					slot.update_indicator()
				else:
					_buff_slot(2, 2, data)
			"rows":
				if data.has("rows"):
					for row_idx in data["rows"]:
						for x in range(GRID_SIZE): _buff_slot(x, row_idx, data)
						
func _buff_slot(x: int, y: int, data: Dictionary) -> void:
	if x < 0 or x >= GRID_SIZE or y < 0 or y >= GRID_SIZE: return
	var slot = grid[x][y]
	if data["stat"] == "multiplier":
		slot.permanent_multiplier += (data["value"] - 1.0)
		slot.update_indicator()
	elif data["stat"] == "bonus":
		slot.permanent_bonus += int(data["value"])
		slot.update_indicator()

func _apply_active_artifacts() -> void:
	var gm = get_node_or_null("/root/GameManager")
	if not gm: return
	for art_id in gm.active_artifacts:
		var data = ItemDatabase.get_artifact(art_id)
		match data["effect"]:
			"deck_skew":
				var min_v = data["range"][0]; var max_v = data["range"][1]; var count = data["amount"]
				for i in range(count):
					var r_num = randi_range(min_v, max_v)
					var r_col = ["L", "I", "M", "B", "O"].pick_random()
					var insert_idx = randi() % (ball_deck.size() + 1)
					ball_deck.insert(insert_idx, {"id": r_col + "-" + str(r_num), "type": "ball_standard"})
			"deck_add_type":
				var type = data["ball_type"]; var count = data["amount"]
				for i in range(count):
					var r_num = randi_range(1, 15)
					var r_col = ["L", "I", "M", "B", "O"].pick_random()
					ball_deck.insert(0, {"id": r_col + "-" + str(r_num), "type": type})

# --- UTILS ---
func _update_ui() -> void:
	get_tree().call_group("UI", "update_round_info", current_round, max_rounds, balls_dealt_this_round, balls_per_round)
	get_tree().call_group("UI", "update_score", total_score, target_score)

func _update_ui_score(val: int) -> void:
	get_tree().call_group("UI", "update_score", val, target_score)

func _check_neighbors(slot) -> bool:
	var neighbors = [Vector2(0,1), Vector2(0,-1), Vector2(1,0), Vector2(-1,0)]
	for n in neighbors:
		var nx = slot.grid_x + n.x
		var ny = slot.grid_y + n.y
		if nx >= 0 and nx < GRID_SIZE and ny >= 0 and ny < GRID_SIZE:
			if grid[nx][ny].held_ball != null: return true
	return false

func _detect_paylines() -> Array:
	var found_lines = []
	for i in range(GRID_SIZE):
		var row_slots = []; var col_slots = []
		var row_full = true; var col_full = true
		for j in range(GRID_SIZE):
			if grid[j][i].held_ball: row_slots.append(grid[j][i])
			else: row_full = false
			if grid[i][j].held_ball: col_slots.append(grid[i][j])
			else: col_full = false
		if row_full: found_lines.append({"type": "Row", "slots": row_slots})
		if col_full: found_lines.append({"type": "Col", "slots": col_slots})
	var d1 = []; var d2 = []
	var d1_full = true; var d2_full = true
	for i in range(GRID_SIZE):
		if grid[i][i].held_ball: d1.append(grid[i][i])
		else: d1_full = false
		if grid[GRID_SIZE-1-i][i].held_ball: d2.append(grid[GRID_SIZE-1-i][i])
		else: d2_full = false
	if d1_full: found_lines.append({"type": "Diag", "slots": d1})
	if d2_full: found_lines.append({"type": "Diag", "slots": d2})
	return found_lines

func _get_line_multiplier(type: String, _slots: Array) -> int:
	match type:
		"Row", "Col", "Diag": return 5
	return 2

func _spawn_floating_text(pos: Vector3, text: String, duration: float = 1.0, col: Color = Color.GOLD) -> void:
	if score_popup_scene:
		var popup = score_popup_scene.instantiate()
		add_child(popup)
		popup.global_position = pos + Vector3(0, 0.5, 0)
		# Assuming text is just a number, but handling flavor text too:
		if text.is_valid_int():
			popup.setup(int(text), "", col)
		else:
			popup.setup(0, text, col) # Flavor text only

func _animate_score_event(slot, points, wait) -> void:
	var ball = slot.held_ball
	if ball:
		var tween = create_tween()
		tween.tween_property(ball, "position:y", 1.5, 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(ball, "position:y", 0.0, 0.1)
	
	SoundManager.play_score_sound(sound_score)
	_spawn_floating_text(slot.global_position, str(points))
	
	# === ENHANCED: Scale particle effect based on score ===
	var particle_scale = 1.0
	if points > 100: particle_scale = 1.5
	if points > 200: particle_scale = 2.0
	if points > 500: particle_scale = 2.5
	
	ParticleManager.play_pop_at(slot.global_position, particle_scale)
	
	await get_tree().create_timer(wait).timeout

func _animate_line_ready(slots) -> void:
	var tween = create_tween().set_parallel(true)
	for slot in slots:
		if slot.held_ball: tween.tween_property(slot.held_ball, "position:y", 0.5, 0.3)
	await tween.finished

func _animate_line_win(slots, sub, mult) -> void:
	await get_tree().create_timer(0.2).timeout
	SoundManager.play_mult_sound(sound_line_win)
	
	# === NEW: Line Explosion Effect ===
	var start_slot = slots[0]
	var end_slot = slots[-1]
	ParticleManager.play_line_explosion(start_slot.global_position, end_slot.global_position)
	
	var center_slot = slots[slots.size() / 2]
	var text = str(sub) + " x " + str(mult) + "!"
	_spawn_floating_text(center_slot.global_position + Vector3(0, 1, 0), text, 2.0, Color.RED)
	
	await get_tree().create_timer(0.8).timeout


# 4. ADD THIS NEW FUNCTION for milestone celebrations:
func _trigger_milestone_celebration(milestone: int) -> void:
	var cam = get_tree().get_first_node_in_group("Camera")
	if cam and cam.has_method("shake_camera"):
		cam.shake_camera(0.3, 0.5)
	
	_spawn_floating_text(Vector3(0, 3.5, 0), str(milestone) + "!", 2.0, Color.GOLD)
	
	# === NEW: Massive particle explosion ===
	for i in range(8):
		var angle = (TAU / 8.0) * i
		var radius = 2.0
		var pos = Vector3(cos(angle) * radius, 1.5, sin(angle) * radius)
		ParticleManager.play_pop_at(pos, 2.5)
		await get_tree().create_timer(0.05).timeout
	
	print("🎉 MILESTONE: " + str(milestone) + " 🎉")

func _spawn_win_beam(start_pos: Vector3, end_pos: Vector3) -> void:
	if not win_beam_scene: return
	var beam = win_beam_scene.instantiate()
	add_child(beam)
	var mid_point = (start_pos + end_pos) / 2.0
	beam.global_position = mid_point
	beam.look_at(end_pos, Vector3.UP)
	var distance = start_pos.distance_to(end_pos)
	beam.scale.z = distance + 0.5 
	beam.scale.x = 0.0; beam.scale.y = 0.0
	var tween = create_tween()
	tween.tween_property(beam, "scale:x", 1.0, 0.2).set_trans(Tween.TRANS_ELASTIC)
	tween.parallel().tween_property(beam, "scale:y", 1.0, 0.2).set_trans(Tween.TRANS_ELASTIC)
	tween.tween_interval(0.5)
	tween.tween_property(beam, "scale:x", 0.0, 0.2)
	tween.tween_callback(beam.queue_free)

func _reset_line_positions(slots: Array) -> void:
	var tween = create_tween().set_parallel(true)
	for slot in slots:
		if slot.held_ball: tween.tween_property(slot.held_ball, "position:y", 0.0, 0.2)
	await tween.finished

func _cleanup_board() -> void:
	for x in range(GRID_SIZE):
		for y in range(GRID_SIZE):
			var slot = grid[x][y]
			if slot.held_ball:
				if slot.held_ball == dealt_ball_ref: dealt_ball_ref = null
				slot.held_ball.queue_free()
				slot.remove_ball()
				var letters = ["L", "I", "M", "B", "O"]
				var new_id = letters[slot.grid_x] + "-" + str(randi_range(1, 15))
				slot.refresh_id(new_id)

func get_score_prediction(ball_id: String, type_id: String, slot_node) -> int:
	# Keep helper for the Ghost Label feature
	var has_neighbor = _check_neighbors(slot_node)
	var total_balls = 0
	for x in range(GRID_SIZE):
		for y in range(GRID_SIZE):
			if grid[x][y].held_ball != null: total_balls += 1

	var result = EffectProcessor.calculate(
		ball_id, type_id,
		{ "target_id": slot_node.target_id, "grid_x": slot_node.grid_x, "grid_y": slot_node.grid_y, "permanent_bonus": slot_node.permanent_bonus, "permanent_multiplier": slot_node.permanent_multiplier },
		{ "has_neighbor": has_neighbor, "total_balls_on_grid": total_balls }
	)
	return result["points"]
