extends CanvasLayer

# ---------------------------------------------------------------
# Node references — set up in _ready via $path
# ---------------------------------------------------------------
@onready var round_label    : Label   = $HUDRoot/BottomBar/RoundLabel
@onready var build_button   : Button  = $HUDRoot/BottomBar/BuildButton
@onready var confirm_button : Button  = $HUDRoot/BottomBar/GemPanel/ConfirmButton

# ---------------------------------------------------------------
# Connect GemSystem signals
# ---------------------------------------------------------------
func _ready() -> void:
	pass

# ---------------------------------------------------------------
# Connect GemSystem signals
# ---------------------------------------------------------------
func _connect_signals() -> void:
	pass


func _build_enabled() -> void:
	if 
