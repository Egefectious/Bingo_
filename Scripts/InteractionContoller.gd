extends Camera3D

# --- CONFIGURATION ---
@export var lift_height: float = 2.0
@export_group("Audio")
@export var sound_hover: AudioStream # Drag a "tick" sound here
@export var sound_place: AudioStream # Drag a "clack" sound here

# --- INTERNAL REFERENCES ---
const MASK_BALLS = 2
const MASK_SLOTS = 4 

var dragged_object: RigidBody3D = null
var current_hovered_ball = null
var current_hovered_slot = null
var ghost_label: Label3D = null 

# Audio Player (Created in code)
var sfx_player: AudioStreamPlayer

func _ready() -> void:
	# 1. Create Audio Player
	sfx_player = AudioStreamPlayer.new()
	add_child(sfx_player)
	
	# 2. Create the "Ghost" Prediction Label
	ghost_label = Label3D.new()
	add_child(ghost_label)
	
	# --- VISUAL UPGRADES ---
	ghost_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	ghost_label.no_depth_test = true # Renders ON TOP of everything (X-Ray)
	ghost_label.render_priority = 100 # Ensures it draws over other transparent items
	
	# Font Styling
	ghost_label.font_size = 96 # Bigger text
	ghost_label.outline_size = 24 # Thick outline
	ghost_label.outline_modulate = Color.BLACK # High contrast black outline
	ghost_label.modulate = Color.WHITE # Default color
	
	ghost_label.visible = false

func _physics_process(delta: float) -> void:
	if dragged_object:
		_handle_dragging()
	else:
		_handle_hovering()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_try_grab_ball()
			else:
				_release_ball()

# --- STATE HANDLERS ---

func _handle_dragging() -> void:
	var mouse_pos = get_viewport().get_mouse_position()
	
	# 1. Move the Ball
	var drag_plane = Plane(Vector3.UP, lift_height)
	var ray_origin = project_ray_origin(mouse_pos)
	var ray_normal = project_ray_normal(mouse_pos)
	var intersection = drag_plane.intersects_ray(ray_origin, ray_normal)
	
	if intersection:
		dragged_object.global_position = intersection
		dragged_object.linear_velocity = Vector3.ZERO
		dragged_object.angular_velocity = Vector3.ZERO
	
	# 2. Raycast for Slot below (Ghost Prediction)
	var result = _raycast_from_mouse(MASK_SLOTS, [dragged_object.get_rid()])
	if result and result.collider is Area3D:
		var slot = result.collider
		if slot != current_hovered_slot:
			current_hovered_slot = slot
			_show_ghost_prediction(slot)
	else:
		if current_hovered_slot:
			current_hovered_slot = null
			ghost_label.visible = false
			
	# Hide standard tooltip while dragging
	get_tree().call_group("UI", "hide_tooltip")

func _handle_hovering() -> void:
	var result = _raycast_from_mouse(MASK_BALLS, [])
	if result and result.collider is RigidBody3D:
		var ball = result.collider
		
		# Only trigger if this is a NEW hover (prevents sound spam)
		if ball != current_hovered_ball:
			current_hovered_ball = ball
			_play_sound(sound_hover, 1.0) # Play "Tick"
			get_tree().call_group("UI", "show_ball_tooltip", ball)
	else:
		if current_hovered_ball:
			current_hovered_ball = null
			get_tree().call_group("UI", "hide_tooltip")

func _show_ghost_prediction(slot) -> void:
	# Don't show score for Bench or invalid slots
	if slot.target_id == "BENCH":
		ghost_label.visible = false
		return
		
	var board = get_tree().get_first_node_in_group("Board")
	if not board: return
	
	var predicted_score = board.get_score_prediction(
		dragged_object.ball_id,
		dragged_object.type_id,
		slot
	)
	
	# Position above the slot
	ghost_label.global_position = slot.global_position + Vector3(0, 0.8, 0)
	ghost_label.visible = true
	
	# --- VISUAL FEEDBACK LOGIC ---
	if predicted_score > 50:
		# Big Score: Bright Green + Bigger Text
		ghost_label.text = "++" + str(predicted_score)
		ghost_label.modulate = Color(0.2, 1.0, 0.2) 
		ghost_label.font_size = 110 
	elif predicted_score == 0:
		# No Score: Red
		ghost_label.text = str(predicted_score)
		ghost_label.modulate = Color(1.0, 0.2, 0.2)
		ghost_label.font_size = 96
	else:
		# Normal Score: White
		ghost_label.text = "+" + str(predicted_score)
		ghost_label.modulate = Color.WHITE
		ghost_label.font_size = 96

# --- GRAB / RELEASE LOGIC ---

func _try_grab_ball() -> void:
	var result = _raycast_from_mouse(MASK_BALLS, [])
	if result and result.collider is RigidBody3D:
		var target_ball = result.collider
		
		# Bench Lock Check
		if target_ball.get("current_state") == 2:
			var slot = target_ball.get("current_slot_ref")
			if slot and slot.get("is_bench_slot") == false:
				return # Board balls are locked
		
		dragged_object = target_ball
		
		# Pickup Logic
		if dragged_object.get("current_slot_ref"):
			dragged_object.current_slot_ref.remove_ball()
		if dragged_object.has_method("start_drag"):
			dragged_object.start_drag()
			
		# Add a slight "Pop" sound on pickup? (Optional: reuse hover sound with higher pitch)
		_play_sound(sound_hover, 1.5)
		
		dragged_object.freeze = true

func _release_ball() -> void:
	if dragged_object:
		var result = _raycast_from_mouse(MASK_SLOTS, [dragged_object.get_rid()])
		var dropped_successfully = false
		
		if result and result.collider is Area3D:
			var target_slot = result.collider
			if target_slot.has_method("is_available") and target_slot.is_available():
				_snap_ball_to_slot(dragged_object, target_slot)
				dropped_successfully = true
		
		if not dropped_successfully:
			_drop_ball_physics(dragged_object)
		
		dragged_object = null
		ghost_label.visible = false

func _snap_ball_to_slot(ball: RigidBody3D, slot: Area3D) -> void:
	ball.snap_to_slot(slot.global_position, slot)
	slot.assign_ball(ball)
	
	# --- PLAY PLACEMENT SOUND ---
	_play_sound(sound_place, 1.0)
	
	get_tree().call_group("Board", "on_ball_snapped", ball)

func _drop_ball_physics(ball: RigidBody3D) -> void:
	if ball.has_method("end_drag"):
		ball.end_drag()
	ball.freeze = false
	ball.sleeping = false

func _raycast_from_mouse(collision_mask: int, exclude_array: Array) -> Dictionary:
	var mouse_pos = get_viewport().get_mouse_position()
	var params = PhysicsRayQueryParameters3D.new()
	params.from = project_ray_origin(mouse_pos)
	params.to = params.from + project_ray_normal(mouse_pos) * 1000.0
	params.collide_with_areas = true
	params.collide_with_bodies = true
	params.collision_mask = collision_mask
	params.exclude = exclude_array
	var space_state = get_world_3d().direct_space_state
	return space_state.intersect_ray(params)

# --- AUDIO HELPER ---
func _play_sound(stream: AudioStream, pitch: float = 1.0) -> void:
	if stream and sfx_player:
		sfx_player.stream = stream
		sfx_player.pitch_scale = pitch
		sfx_player.play()
		
func shake_camera(intensity: float, duration: float):
	var tween = create_tween()
	for i in range(int(duration * 20)):
		var offset = Vector3(
			randf_range(-intensity, intensity),
			0,
			randf_range(-intensity, intensity)
		)
		tween.tween_property(self, "position", position + offset, 0.05)
	tween.tween_property(self, "position", Vector3(0, 8, 5), 0.1)
