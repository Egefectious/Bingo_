extends Control
class_name GameUI

@onready var round_label: Label = $TopBar/LeftPanel/RoundLabel
@onready var score_label: Label = $TopBar/LeftPanel/ScoreLabel
@onready var deck_label: Label = $TopBar/RightPanel/DeckLabel
@onready var score_button: Button = $BottomBar/ScoreButton
@onready var deal_button: Button = $BottomBar/DealButton

# Tooltip References
@onready var info_panel: Control = $InfoPanel
@onready var info_name: Label = $InfoPanel/VBox/NameLbl
@onready var info_type: Label = $InfoPanel/VBox/TypeLbl
@onready var info_desc: Label = $InfoPanel/VBox/DescLbl

# Rolling Score
var displayed_score: float = 0.0
var target_displayed_score: float = 0.0
var score_tween: Tween

func _ready() -> void:
	add_to_group("UI")
	if info_panel:
		info_panel.visible = false
	
	# Score button is now "Cash Out" and always visible
	score_button.text = "SCORE HAND"

func _process(delta: float) -> void:
	# Update the text every frame for the rolling effect
	if score_label:
		var score_str = _format_number(int(displayed_score))
		
		# Get target safely (GameManager might not exist in test scenes)
		var target_val = 500
		var gm = get_node_or_null("/root/GameManager")
		if gm: target_val = gm.get_current_target()
		
		var target_str = _format_number(target_val)
		score_label.text = "Score: " + score_str + " / " + target_str

func _on_deal_button_pressed() -> void:
	get_tree().call_group("Board", "deal_ball")

func _on_score_button_pressed() -> void:
	get_tree().call_group("Board", "cash_out")

# --- ROLLING SCORE LOGIC ---
func update_score(current: int, target: int) -> void:
	target_displayed_score = float(current)
	
	if score_tween: score_tween.kill()
	
	score_tween = create_tween()
	# Animate the number over 0.5 seconds
	score_tween.tween_property(self, "displayed_score", target_displayed_score, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func update_deck_count(remaining: int, total: int):
	if deck_label:
		deck_label.text = "Deck: " + str(remaining) + "/" + str(total)

func update_round_info(round_num: int, max_rounds: int, dealt: int, max_dealt: int) -> void:
	if round_label:
		round_label.text = "Round: " + str(round_num) + "/" + str(max_rounds) + " | Balls: " + str(dealt) + "/" + str(max_dealt)
	
	# Button logic
	if deal_button:
		if dealt >= max_dealt:
			if round_num < max_rounds:
				deal_button.disabled = false
				deal_button.text = "NEXT ROUND"
			else:
				deal_button.disabled = true
				deal_button.text = "NO BALLS"
		else:
			deal_button.disabled = false
			deal_button.text = "DEAL BALL"
	
	# Score button logic
	if score_button:
		var gm = get_node_or_null("/root/GameManager")
		if gm and gm.current_encounter_index == 3:
			score_button.text = "SCORE (Round " + str(round_num) + "/" + str(max_rounds) + ")"
			score_button.disabled = (round_num < max_rounds or dealt < max_dealt)
		else:
			if round_num == 1:
				score_button.text = "Score now? (30 Fate)"
			elif round_num == 2:
				score_button.text = "Score now? (10 Fate)"
			else:
				score_button.text = "Score now? (5 Fate)"
			score_button.disabled = false

func toggle_input(enabled: bool) -> void:
	if deal_button: deal_button.disabled = not enabled
	if score_button: score_button.disabled = not enabled

# --- TOOLTIP LOGIC ---
func show_ball_tooltip(ball_node) -> void:
	if not info_panel: return
	
	# Fetch Data from the Database
	var data = BallDatabase.get_data(ball_node.type_id)
	
	# Set Text
	if info_name: info_name.text = data["name"]
	if info_type: info_type.text = data["rarity"].capitalize()
	
	# Handle Description
	var desc = data["desc"]
	if data["tags"].has("wild"):
		desc += "\n(Wild: Matches Any Number)"
	if info_desc: info_desc.text = desc
	
	# Set Colors based on rarity
	if info_name:
		match data["rarity"]:
			"mortal": info_name.modulate = Color.WHITE
			"blessed": info_name.modulate = Color.CYAN
			"divine": info_name.modulate = Color.GOLD
			"godly": info_name.modulate = Color.MAGENTA
	
	info_panel.visible = true

func hide_tooltip() -> void:
	if info_panel:
		info_panel.visible = false

# Helper to add commas (e.g. 1,000)
func _format_number(n: int) -> String:
	var s = str(n)
	var len = s.length()
	if len <= 3: return s
	var res = ""
	for i in range(len):
		if i > 0 and (len - i) % 3 == 0:
			res += ","
		res += s[i]
	return res
