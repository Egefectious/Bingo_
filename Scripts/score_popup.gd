extends Node3D

# --- INSTRUCTIONS ---
# 1. Attach this to a Node3D.
# 2. Add a Label3D child named "ScoreLabel".
# 3. Add a Label3D child named "FlavorLabel" (optional).

@onready var score_label: Label3D = $ScoreLabel
@onready var flavor_label: Label3D = get_node_or_null("FlavorLabel")

var velocity: Vector3 = Vector3(0, 1.5, 0) # Moves up
var lifetime: float = 1.5
var time_alive: float = 0.0

func setup(score_amount: int, flavor_text: String = "", color: Color = Color.GOLD) -> void:
	if not score_label: return
	
	score_label.text = str(score_amount)
	score_label.modulate = color
	score_label.font_size = 96
	score_label.outline_size = 24
	score_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	score_label.no_depth_test = true # Always visible
	
	if flavor_label:
		flavor_label.text = flavor_text
		flavor_label.modulate = color.lightened(0.5)
		flavor_label.visible = (flavor_text != "")
	
	# Randomize drift slightly so they don't stack perfectly
	velocity.x = randf_range(-0.5, 0.5)
	velocity.z = randf_range(-0.2, 0.2)
	
	# Start invisible/small
	scale = Vector3.ZERO

func _process(delta: float) -> void:
	time_alive += delta
	
	# 1. Move
	global_position += velocity * delta
	
	# 2. Friction (Slow down drift)
	velocity = velocity.move_toward(Vector3.ZERO, delta * 0.5)
	
	# 3. Animation Curve (Pop up -> Hang -> Fade)
	if time_alive < 0.2:
		# Pop in (Elastic bounce)
		var t = time_alive / 0.2
		scale = Vector3.ONE * ease_elastic_out(t)
	elif time_alive > (lifetime - 0.5):
		# Fade out
		var t = (time_alive - (lifetime - 0.5)) / 0.5
		scale = Vector3.ONE.lerp(Vector3.ZERO, t)
		if score_label: score_label.modulate.a = 1.0 - t
	
	if time_alive >= lifetime:
		queue_free()

# Custom Elastic Ease for that "Game Feel" pop
func ease_elastic_out(x: float) -> float:
	var c4 = (2.0 * PI) / 3.0
	if x == 0.0: return 0.0
	if x == 1.0: return 1.0
	return pow(2.0, -10.0 * x) * sin((x * 10.0 - 0.75) * c4) + 1.0
