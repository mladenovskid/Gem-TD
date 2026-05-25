# hud.gd
# Attach to a CanvasLayer node called "HUD" in your Main scene.
#
# CanvasLayer "HUD"
# └── Control "HUDRoot"
#     └── Panel "BottomBar"
#         ├── Label "RoundLabel"
#         ├── Button "BuildButton"
#         └── Button "ConfirmButton"

extends CanvasLayer

@onready var round_label    : Label  = $HUDRoot/BottomBar/RoundLabel
@onready var build_button   : Button = $HUDRoot/BottomBar/BuildButton
@onready var confirm_button : Button = $HUDRoot/BottomBar/ConfirmButton

func _ready() -> void:
	_setup_panel_style()
	_connect_signals()
	confirm_button.visible = false
	_update_round_label()

func _connect_signals() -> void:
	BuildSystem.build_mode_entered.connect(_on_build_mode_entered)
	BuildSystem.all_towers_placed.connect(_on_all_towers_placed)
	BuildSystem.build_phase_complete.connect(_on_build_phase_complete)
	build_button.pressed.connect(_on_build_button_pressed)
	confirm_button.pressed.connect(_on_confirm_button_pressed)

func _on_build_button_pressed() -> void:
	if BuildSystem.is_build_active():
		return
	BuildSystem.enter_build_mode()
	build_button.release_focus()

func _on_confirm_button_pressed() -> void:
	BuildSystem.confirm_selection()

func _on_build_mode_entered() -> void:
	build_button.text     = "Placing... (0/5)"
	build_button.disabled = true

func _on_all_towers_placed(_placed_towers: Array) -> void:
	# All 5 towers placed — show confirm button so player can keep their choice
	confirm_button.visible = true
	confirm_button.text    = "Confirm"

func _on_build_phase_complete() -> void:
	confirm_button.visible = false
	build_button.text      = "Build"
	build_button.disabled  = false
	_update_round_label()

func update_tower_counter(placed: int, total: int) -> void:
	build_button.text = "Placing... (" + str(placed) + "/" + str(total) + ")"

func _update_round_label() -> void:
	round_label.text = "Round " + str(BuildSystem.current_round)

func _setup_panel_style() -> void:
	var bottom_bar : Panel = $HUDRoot/BottomBar

	var style : StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color            = Color(0.10, 0.09, 0.08, 0.92)
	style.border_width_top    = 2
	style.border_width_bottom = 2
	style.border_width_left   = 2
	style.border_width_right  = 2
	style.border_color        = Color(0.35, 0.28, 0.18, 1.0)
	style.corner_radius_top_left     = 6
	style.corner_radius_top_right    = 6
	style.corner_radius_bottom_left  = 0
	style.corner_radius_bottom_right = 0
	bottom_bar.add_theme_stylebox_override("panel", style)

	var btn_style : StyleBoxFlat = StyleBoxFlat.new()
	btn_style.bg_color     = Color(0.22, 0.18, 0.10, 1.0)
	btn_style.border_color = Color(0.6, 0.45, 0.2, 1.0)
	btn_style.border_width_top    = 2
	btn_style.border_width_bottom = 2
	btn_style.border_width_left   = 2
	btn_style.border_width_right  = 2
	btn_style.corner_radius_top_left     = 4
	btn_style.corner_radius_top_right    = 4
	btn_style.corner_radius_bottom_left  = 4
	btn_style.corner_radius_bottom_right = 4
	build_button.add_theme_stylebox_override("normal", btn_style)
	build_button.add_theme_color_override("font_color", Color(0.9, 0.78, 0.45))
	build_button.add_theme_font_size_override("font_size", 15)
