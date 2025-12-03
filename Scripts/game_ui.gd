extends Control
class_name GameUI

@onready var round_label: Label = $RoundLabel
@onready var score_label: Label = $ScoreLabel
@onready var deck_label: Label = $DeckLabel
# --- TOOLTIP REFERENCES ---
# These paths match the hierarchy we built in Step 1
@onready var info_panel: Control = $InfoPanel
@onready var info_name: Label = $InfoPanel/VBox/NameLbl
@onready var info_type: Label = $InfoPanel/VBox/TypeLbl
@onready var info_desc: Label = $InfoPanel/VBox/DescLbl

# --- ROLLING SCORE VARIABLES ---
var displayed_score: float = 0.0
var target_displayed_score: float = 0.0
var score_tween: Tween

func _ready() -> void:
	add_to_group("UI")
	if info_panel:
		info_panel.visible = false # Hide tooltip at start

func _process(delta: float) -> void:
	# Update the text every frame for the rolling effect
	if score_label:
		var score_str = _format_number(int(displayed_score))
		
		# Get target safely (GameManager might not exist in test scenes)
		var target_val = 500
		var gm = get_node_or_null("/root/GameManager")
		if gm: target_val = gm.target_score_base
		
		var target_str = _format_number(target_val)
		score_label.text = "Score: " + score_str + " / " + target_str

func _on_deal_button_pressed() -> void:
	get_tree().call_group("Board", "deal_ball")

func _on_score_button_pressed() -> void:
	get_tree().call_group("Board", "cash_out")

# --- NEW: ROLLING SCORE LOGIC ---
func update_score(current: int, target: int) -> void:
	target_displayed_score = float(current)
	
	if score_tween: score_tween.kill()
	
	score_tween = create_tween()
	# Animate the number over 0.5 seconds
	score_tween.tween_property(self, "displayed_score", target_displayed_score, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func update_deck_count(remaining: int, total: int):
	deck_label.text = "Deck: " + str(remaining) + "/" + str(total)

func update_round_info(round_num: int, max_rounds: int, dealt: int, max_dealt: int) -> void:
	round_label.text = "Round: " + str(round_num) + "/" + str(max_rounds) + "\nBalls: " + str(dealt) + "/" + str(max_dealt)

# --- NEW: TOOLTIP LOGIC ---
func show_ball_tooltip(ball_node) -> void:
	if not info_panel: return
	
	# Fetch Data from the Database
	var data = BallDatabase.get_data(ball_node.type_id)
	
	# Set Text
	info_name.text = data["name"]
	info_type.text = data["rarity"].capitalize()
	
	# Handle Description
	var desc = data["desc"]
	if data["tags"].has("wild"):
		desc += "\n(Wild: Matches Any Number)"
	info_desc.text = desc
	
	# Set Colors based on rarity
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
