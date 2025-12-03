extends Control

signal item_clicked(item_data)

var data: Dictionary = {}

@onready var name_lbl: Label = $NameLabel
@onready var desc_lbl: Label = $DescLabel
@onready var cost_lbl: Label = $CostLabel
@onready var bg: ColorRect = $RarityColor
@onready var info_box: Panel = $InfoBox 

func setup(item_data: Dictionary) -> void:
	data = item_data
	
	name_lbl.text = data["name"]
	desc_lbl.text = data["desc"]
	
	# NEW: Currency Formatting
	var symbol = "$"
	var color = Color.WHITE
	
	match data.get("currency_type", "obols"):
		"obols": 
			symbol = "Ø " # Obol Symbol
			color = Color.GREEN
		"essence": 
			symbol = "₳ " # Essence Symbol
			color = Color.CYAN
		"fate": 
			symbol = "₪ " # Fate Symbol
			color = Color.GOLD
			
	cost_lbl.text = symbol + str(data["cost"])
	cost_lbl.modulate = color
	
	# Rarity Colors
	var r_str = data.get("rarity", "mortal")
	match r_str:
		"mortal": bg.color = Color(0.5, 0.5, 0.5)
		"blessed": bg.color = Color(0.2, 0.6, 1.0)
		"divine": bg.color = Color(0.8, 0.2, 0.8)
		"godly": bg.color = Color(1.0, 0.6, 0.0)
		_: bg.color = Color.GRAY
	
	if info_box: info_box.visible = false

func _on_button_pressed() -> void:
	item_clicked.emit(data)

func _on_button_mouse_entered() -> void:
	if info_box: info_box.visible = true

func _on_button_mouse_exited() -> void:
	if info_box: info_box.visible = false
