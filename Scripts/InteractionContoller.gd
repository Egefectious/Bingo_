extends Camera3D

# --- CONFIGURATION ---
@export var lift_height: float = 2.0
@export_group("Audio")
@export var sound_hover: AudioStream
@export var sound_place: AudioStream

# --- INTERNAL REFERENCES ---
const MASK_BALLS = 2
const MASK_SLOTS = 4 

var dragged_object: RigidBody3D = null
var current_hovered_ball = null
var current_hovered_slot = null
var ghost_label: Label3D = null 

var sfx_player: AudioStreamPlayer

func _ready() -> void:
	add_to_group("Camera")
	
	# HARD SET CAMERA POSITION
	# We stand back (Z=7.5) and aim at the center height (Y=3.0)
	global_position = Vector3(0, 3.0, 7.5)
	
	# Look straight at the board (Maybe tilt down slightly)
	rotation_degrees = Vector3(0, 0, 0)
	
	_setup_advanced_camera()
	
	sfx_player = AudioStreamPlayer.new()
	add_child(sfx_player)
	
	ghost_label = Label3D.new()
	add_child(ghost_label)
	ghost_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	ghost_label.no_depth_test = true
	ghost_label.visible = false

func _setup_advanced_camera() -> void:
	"""Configure camera for Victorian parlor atmosphere"""
	
	# Angled view like the reference image
	fov = 60.0
	
	# Camera attributes for atmospheric depth
	var cam_attributes = CameraAttributesPractical.new()
	
	# Subtle DOF for depth
	cam_attributes.dof_blur_far_enabled = true
	cam_attributes.dof_blur_far_distance = 15.0
	cam_attributes.dof_blur_far_transition = 5.0
	cam_attributes.dof_blur_amount = 0.08
	
	cam_attributes.auto_exposure_enabled = false
	
	attributes = cam_attributes
	
	print("✓ Victorian parlor camera configured")

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

# - Updating dragging physics for angled board
func _handle_dragging() -> void:
	var mouse_pos = get_viewport().get_mouse_position()
	
	# --- FIX: DRAG PLANE ---
	# The board is rotated -70 deg. Its normal vector points mostly forward (Z) and up (Y).
	# This creates a plane parallel to the easel face.
	var normal = Vector3(0, 0.34, 0.94).normalized() # Approx matching -70 deg rotation
	var drag_plane = Plane(normal, 2.5) # Offset to match board surface
	
	var ray_origin = project_ray_origin(mouse_pos)
	var ray_normal = project_ray_normal(mouse_pos)
	var intersection = drag_plane.intersects_ray(ray_origin, ray_normal)
	
	if intersection:
		dragged_object.global_position = intersection
		dragged_object.linear_velocity = Vector3.ZERO
		dragged_object.angular_velocity = Vector3.ZERO
	
	# ... (Keep the rest of the raycast/ghost logic the same) ...
	var result = _raycast_from_mouse(MASK_SLOTS, [dragged_object.get_rid()])
	# ...

func _handle_hovering() -> void:
	var result = _raycast_from_mouse(MASK_BALLS, [])
	if result and result.collider is RigidBody3D:
		var ball = result.collider
		
		if ball != current_hovered_ball:
			current_hovered_ball = ball
			_play_sound(sound_hover, 1.0, -10.0) 
			get_tree().call_group("UI", "show_ball_tooltip", ball)
	else:
		if current_hovered_ball:
			current_hovered_ball = null
			get_tree().call_group("UI", "hide_tooltip")
			
func _show_ghost_prediction(slot) -> void:
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
	
	ghost_label.global_position = slot.global_position + Vector3(0, 0.8, 0)
	ghost_label.visible = true
	
	if predicted_score > 50:
		ghost_label.text = "++" + str(predicted_score)
		ghost_label.modulate = Color(0.2, 1.0, 0.2) 
		ghost_label.font_size = 110 
	elif predicted_score == 0:
		ghost_label.text = str(predicted_score)
		ghost_label.modulate = Color(1.0, 0.2, 0.2)
		ghost_label.font_size = 96
	else:
		ghost_label.text = "+" + str(predicted_score)
		ghost_label.modulate = Color.WHITE
		ghost_label.font_size = 96

func _try_grab_ball() -> void:
	var result = _raycast_from_mouse(MASK_BALLS, [])
	if result and result.collider is RigidBody3D:
		var target_ball = result.collider
		
		if target_ball.get("current_state") == 2:
			var slot = target_ball.get("current_slot_ref")
			if slot and slot.get("is_bench_slot") == false:
				return
		
		dragged_object = target_ball
		
		if dragged_object.get("current_slot_ref"):
			dragged_object.current_slot_ref.remove_ball()
		if dragged_object.has_method("start_drag"):
			dragged_object.start_drag()
			
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

func _play_sound(stream: AudioStream, pitch: float = 1.0, volume_db: float = 0.0) -> void:
	if stream and sfx_player:
		sfx_player.stream = stream
		sfx_player.pitch_scale = pitch
		sfx_player.volume_db = volume_db
		sfx_player.play()

# Enhanced effects for cel-shaded visuals
func shake_camera(intensity: float, duration: float) -> void:
	"""Snappier shake for cartoon feel"""
	var original_pos = position
	var shake_count = int(duration * 40)  # Faster shake
	
	var tween = create_tween()
	
	for i in range(shake_count):
		var progress = float(i) / float(shake_count)
		var eased_intensity = intensity * (1.0 - progress)
		
		var offset = Vector3(
			randf_range(-eased_intensity, eased_intensity),
			randf_range(-eased_intensity * 0.3, eased_intensity * 0.3),
			randf_range(-eased_intensity, eased_intensity)
		)
		
		tween.tween_property(self, "position", original_pos + offset, duration / shake_count)
	
	tween.tween_property(self, "position", original_pos, 0.1).set_trans(Tween.TRANS_BACK)

func zoom_pulse(amount: float = 3.0, duration: float = 0.25) -> void:
	"""Snappier zoom for impact"""
	var original_fov = fov
	var target_fov = fov - amount
	
	var tween = create_tween()
	tween.tween_property(self, "fov", target_fov, duration * 0.4).set_trans(Tween.TRANS_BACK)
	tween.tween_property(self, "fov", original_fov, duration * 0.6).set_trans(Tween.TRANS_ELASTIC)

func slow_motion(time_scale: float = 0.3, duration: float = 1.0) -> void:
	"""Dramatic slow-mo for big moments"""
	Engine.time_scale = time_scale
	
	await get_tree().create_timer(duration * time_scale).timeout
	
	var tween = create_tween()
	tween.tween_property(Engine, "time_scale", 1.0, 0.5)
