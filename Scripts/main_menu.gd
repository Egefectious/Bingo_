extends Control

@export_file("*.tscn") var game_scene_path: String = "res://Scenes/shop.tscn" # Start at Shop for setup

func _ready() -> void:
	$VBoxContainer/BtnPlay.pressed.connect(_on_play_pressed)
	$VBoxContainer/BtnDev.pressed.connect(_on_dev_pressed)

func _on_play_pressed() -> void:
	var gm = get_node_or_null("/root/GameManager")
	if gm:
		gm.dev_mode = false
		gm.start_new_run() # Resets everything to standard start
	get_tree().change_scene_to_file(game_scene_path)

func _on_dev_pressed() -> void:
	var gm = get_node_or_null("/root/GameManager")
	if gm:
		gm.dev_mode = true
		gm.start_new_run() 
		
		gm.currency_obols = 9999
		gm.currency_essence = 9999
		gm.currency_fate = 9999
		
		# FIX: Add Dictionaries, not Strings!
		gm.owned_balls.clear()
		for i in range(10): 
			gm.owned_balls.append({ "id": "B-" + str(i), "type": "ball_god" })
		for i in range(10): 
			gm.owned_balls.append({ "id": "W-" + str(i), "type": "ball_wild" })
		   
		get_tree().change_scene_to_file(game_scene_path)
