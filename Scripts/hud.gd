# hud.gd
# Attach to a CanvasLayer node called "HUD" in your Main scene.
# Add the following node structure under HUD:
#
# CanvasLayer "HUD"
# └── Control "HUDRoot"
#     └── Panel "BottomBar"             ← dark stone background, anchored bottom-center
#         ├── Label "RoundLabel"        ← shows "Round 1"
#         ├── Button "BuildButton"      ← toggles build mode
#         └── Panel "GemPanel"          ← hidden until all 5 gems placed
#             ├── HBoxContainer "GemRow"   ← holds 5 gem orb buttons
#             └── Button "ConfirmButton"   ← appears after gem selected

extends CanvasLayer

# ---------------------------------------------------------------
# Node references — set up in _ready via $path
# ---------------------------------------------------------------
@onready var round_label    : Label   = $HUDRoot/BottomBar/RoundLabel
@onready var build_button   : Button  = $HUDRoot/BottomBar/BuildButton
@onready var gem_panel      : Panel   = $HUDRoot/BottomBar/GemPanel
@onready var gem_row        : HBoxContainer = $HUDRoot/BottomBar/GemPanel/GemRow
@onready var confirm_button : Button  = $HUDRoot/BottomBar/GemPanel/ConfirmButton

# ---------------------------------------------------------------
func _ready() -> void:
	_setup_panel_style()
	_connect_signals()
	gem_panel.visible      = false
	confirm_button.visible = false
	_update_round_label()

# ---------------------------------------------------------------
# Connect GemSystem signals
# ---------------------------------------------------------------
func _connect_signals() -> void:
	GemSystem.build_mode_entered.connect(_on_build_mode_entered)
	GemSystem.all_gems_placed.connect(_on_all_gems_placed)
	GemSystem.gem_selected.connect(_on_gem_selected)
	GemSystem.build_phase_complete.connect(_on_build_phase_complete)
	build_button.pressed.connect(_on_build_button_pressed)
	confirm_button.pressed.connect(_on_confirm_button_pressed)

# ---------------------------------------------------------------
# Button callbacks
# ---------------------------------------------------------------
func _on_build_button_pressed() -> void:
	if GemSystem.is_build_active():
		return  # already in build mode
	GemSystem.enter_build_mode()
	build_button.release_focus()

func _on_confirm_button_pressed() -> void:
	GemSystem.confirm_selection()

# ---------------------------------------------------------------
# GemSystem signal handlers
# ---------------------------------------------------------------
func _on_build_mode_entered() -> void:
	build_button.text     = "Placing... (0/5)"
	build_button.disabled = true

func _on_all_gems_placed(placed_gems: Array) -> void:
	gem_panel.visible = true
	_populate_gem_row(placed_gems)

func _on_gem_selected(gem_data: Dictionary) -> void:
	# Show only the selected gem in the row, reveal confirm button
	for child in gem_row.get_children():
		child.queue_free()

	_add_gem_orb(gem_data, true)
	confirm_button.visible = true
	confirm_button.text    = "Keep " + gem_data.color.capitalize() + " Lv." + str(gem_data.level)

func _on_build_phase_complete() -> void:
	gem_panel.visible      = false
	confirm_button.visible = false
	build_button.text      = "Build"
	build_button.disabled  = false
	_update_round_label()
	# Clear gem row
	for child in gem_row.get_children():
		child.queue_free()

# ---------------------------------------------------------------
# Called every time a gem is placed — updates build button counter
# ---------------------------------------------------------------
func update_gem_counter(placed: int, total: int) -> void:
	if placed < total:
		build_button.text = "Placing... (" + str(placed) + "/" + str(total) + ")"

# ---------------------------------------------------------------
# Populate gem row with 5 orb buttons
# ---------------------------------------------------------------
func _populate_gem_row(placed_gems: Array) -> void:
	for child in gem_row.get_children():
		child.queue_free()

	for gem in placed_gems:
		_add_gem_orb(gem, false)

func _add_gem_orb(gem_data: Dictionary, is_selected: bool) -> void:
	var container : VBoxContainer = VBoxContainer.new()
	container.alignment = BoxContainer.ALIGNMENT_CENTER

	# Orb button
	var orb : Button = Button.new()
	orb.custom_minimum_size = Vector2(64, 64)
	orb.tooltip_text        = gem_data.color.capitalize() + " Lv." + str(gem_data.level)

	# Style the orb with the gem color
	var gem_color : Color   = GemSystem.get_gem_color(gem_data.color)
	var style     : StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color        = gem_color
	style.corner_radius_top_left     = 32
	style.corner_radius_top_right    = 32
	style.corner_radius_bottom_left  = 32
	style.corner_radius_bottom_right = 32
	style.border_width_top    = 3
	style.border_width_bottom = 3
	style.border_width_left   = 3
	style.border_width_right  = 3
	style.border_color = Color.WHITE if is_selected else gem_color.lightened(0.3)

	# Hover style — brighter
	var style_hover : StyleBoxFlat = style.duplicate()
	style_hover.bg_color = gem_color.lightened(0.25)
	style_hover.border_color = Color.WHITE

	orb.add_theme_stylebox_override("normal", style)
	orb.add_theme_stylebox_override("hover",  style_hover)
	orb.add_theme_stylebox_override("pressed", style_hover)

	# Level label inside orb
	var lv_label : Label = Label.new()
	lv_label.text                                   = "Lv." + str(gem_data.level)
	lv_label.horizontal_alignment                   = HORIZONTAL_ALIGNMENT_CENTER
	lv_label.add_theme_color_override("font_color", Color.WHITE)
	lv_label.add_theme_font_size_override("font_size", 11)
	orb.add_child(lv_label)
	lv_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)

	# Color name label below orb
	var name_label : Label = Label.new()
	name_label.text                                   = gem_data.color.capitalize()
	name_label.horizontal_alignment                   = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_color_override("font_color", gem_color.lightened(0.3))
	name_label.add_theme_font_size_override("font_size", 11)

	container.add_child(orb)
	container.add_child(name_label)
	gem_row.add_child(container)

	# Connect click — only allow selection if not already selected
	if not is_selected:
		var captured_gem : Dictionary = gem_data
		orb.pressed.connect(func(): GemSystem.select_gem(captured_gem))

# ---------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------
func _update_round_label() -> void:
	round_label.text = "Round " + str(GemSystem.current_round)

# ---------------------------------------------------------------
# Style the dark stone panel
# ---------------------------------------------------------------
func _setup_panel_style() -> void:
	var bottom_bar : Panel = $HUDRoot/BottomBar

	var style : StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color              = Color(0.10, 0.09, 0.08, 0.92)
	style.border_width_top      = 2
	style.border_width_bottom   = 2
	style.border_width_left     = 2
	style.border_width_right    = 2
	style.border_color          = Color(0.35, 0.28, 0.18, 1.0)
	style.corner_radius_top_left     = 6
	style.corner_radius_top_right    = 6
	style.corner_radius_bottom_left  = 0
	style.corner_radius_bottom_right = 0
	bottom_bar.add_theme_stylebox_override("panel", style)

	# Style build button
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
