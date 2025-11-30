extends Control

signal item_clicked(item_data)

var data: Dictionary = {}

# Make sure these nodes exist in your ItemCard.tscn!
@onready var name_lbl: Label = $NameLabel
@onready var desc_lbl: Label = $DescLabel
@onready var cost_lbl: Label = $CostLabel
@onready var bg: ColorRect = $RarityColor
@onready var info_box: Panel = $InfoBox # Optional hover tooltip

func setup(item_data: Dictionary) -> void:
	data = item_data
	
	# Display Logic
	name_lbl.text = data["name"]
	desc_lbl.text = data["desc"]
	cost_lbl.text = data["cost_text"]
	
	# Rarity Color Coding
	match data["rarity"]:
		0: bg.color = Color.GRAY # Common
		1: bg.color = Color(0.2, 0.6, 1.0) # Uncommon (Blue)
		2: bg.color = Color(0.8, 0.2, 0.8) # Rare (Purple)
		3: bg.color = Color(1.0, 0.6, 0.0) # Legendary (Orange)
	
	# Hide tooltip by default
	if info_box: info_box.visible = false

# Link the Button node to this function
func _on_button_pressed() -> void:
	# Pass the data back to the Shop UI to handle the purchase
	item_clicked.emit(data)

# Optional: Hover effects
func _on_button_mouse_entered() -> void:
	if info_box: info_box.visible = true

func _on_button_mouse_exited() -> void:
	if info_box: info_box.visible = false
