extends Node

# Pool of audio players to allow overlapping sounds
var score_players: Array[AudioStreamPlayer] = []
var mult_players: Array[AudioStreamPlayer] = []
var current_pitch: float = 1.0

func _ready() -> void:
	_create_pool(score_players, 10)
	_create_pool(mult_players, 5)

func _create_pool(array: Array, count: int) -> void:
	for i in count:
		var p = AudioStreamPlayer.new()
		add_child(p)
		array.append(p)

# Call this at the start of cash_out to reset the excitement
func reset_pitch() -> void:
	current_pitch = 1.0

# Call this on every "pop"
func play_score_sound(base_stream: AudioStream) -> void:
	var p = _get_available_player(score_players)
	if p:
		p.stream = base_stream
		p.pitch_scale = current_pitch
		p.play()
		# Increase pitch for next time, capped at 2.0 (chipmunk speed)
		current_pitch = min(current_pitch + 0.05, 3.0)

func play_mult_sound(base_stream: AudioStream) -> void:
	var p = _get_available_player(mult_players)
	if p:
		p.stream = base_stream
		p.pitch_scale = 1.0 # Multipliers usually sound heavy/bassy
		p.play()

func _get_available_player(pool: Array) -> AudioStreamPlayer:
	for p in pool:
		if not p.playing:
			return p
	# If all busy, steal the oldest one (index 0)
	return pool[0]
