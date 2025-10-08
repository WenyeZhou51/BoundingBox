extends BasePrefab

@export var loading_duration: float = 1.5  # Loading bar duration in seconds

var is_loading: bool = false
var loading_progress: float = 0.0
var loading_timer: float = 0.0

# UI elements
var ui_panel: Panel
var loading_bar: ProgressBar
var content_label: RichTextLabel
var close_button: Button

# Audio
var read_document_audio: AudioStreamPlayer

func _ready():
	object_label = "Document"
	confidence = 0.89
	is_interactable = true
	interaction_text = "Sift through"
	
	# Get the audio player
	read_document_audio = $ReadDocumentAudio
	
	super._ready()  # Call parent's _ready function
	
	# Create UI elements (they will be added to the player's UI when needed)
	create_ui_elements()

func _process(delta):
	if is_loading:
		loading_timer += delta
		loading_progress = min(loading_timer / loading_duration, 1.0)
		
		if loading_bar:
			loading_bar.value = loading_progress * 100
		
		if loading_progress >= 1.0:
			is_loading = false
			# Stop the document reading audio when loading finishes
			if read_document_audio and read_document_audio.playing:
				read_document_audio.stop()
			show_content()

func interact():
	if is_loading or (ui_panel and ui_panel.visible):
		return  # Don't allow interaction while loading or panel is already shown
	
	start_loading()

func start_loading():
	is_loading = true
	loading_timer = 0.0
	loading_progress = 0.0
	
	# Play read document sound
	if read_document_audio:
		print("Playing document read sound...")
		read_document_audio.play()
	else:
		print("Error: read_document_audio is null!")
	
	# Get the player and add UI to their overlay
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		print("Error: Could not find player")
		return
	
	var ui_overlay = player.get_node("UIOverlay")
	if not ui_overlay:
		print("Error: Could not find UIOverlay")
		return
	
	# Add panel to UI overlay
	ui_overlay.add_child(ui_panel)
	ui_panel.visible = true
	loading_bar.visible = true
	content_label.visible = false
	close_button.visible = false
	
	# Release mouse cursor
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func show_content():
	loading_bar.visible = false
	content_label.visible = true
	close_button.visible = true

func close_panel():
	if ui_panel and ui_panel.get_parent():
		ui_panel.get_parent().remove_child(ui_panel)
	
	ui_panel.visible = false
	
	# Capture mouse cursor again (no sound when closing)
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func create_ui_elements():
	# Create main panel with green border styling to match game
	ui_panel = Panel.new()
	ui_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	ui_panel.size = Vector2(700, 500)
	ui_panel.position = Vector2(-350, -250)
	ui_panel.visible = false
	
	# Set panel background to black to match game style
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = Color.BLACK
	style_box.border_color = Color.GREEN
	style_box.border_width_left = 2
	style_box.border_width_right = 2
	style_box.border_width_top = 2
	style_box.border_width_bottom = 2
	ui_panel.add_theme_stylebox_override("panel", style_box)
	
	# Create loading bar with green styling
	loading_bar = ProgressBar.new()
	loading_bar.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	loading_bar.size = Vector2(400, 30)
	loading_bar.position = Vector2(-200, -15)
	loading_bar.min_value = 0
	loading_bar.max_value = 100
	loading_bar.value = 0
	
	# Style the loading bar to match game theme
	var progress_style_bg = StyleBoxFlat.new()
	progress_style_bg.bg_color = Color.BLACK
	progress_style_bg.border_color = Color.GREEN
	progress_style_bg.border_width_left = 2
	progress_style_bg.border_width_right = 2
	progress_style_bg.border_width_top = 2
	progress_style_bg.border_width_bottom = 2
	loading_bar.add_theme_stylebox_override("background", progress_style_bg)
	
	var progress_style_fill = StyleBoxFlat.new()
	progress_style_fill.bg_color = Color.GREEN
	loading_bar.add_theme_stylebox_override("fill", progress_style_fill)
	
	ui_panel.add_child(loading_bar)
	
	# Create content label with green text and proper styling
	content_label = RichTextLabel.new()
	content_label.position = Vector2(20, 20)
	content_label.size = Vector2(660, 420)
	content_label.bbcode_enabled = true
	content_label.text = """[color=green][font_size=16]CLASSIFIED DOCUMENT - ACCESS LEVEL: RESTRICTED

[font_size=20]SUBJECT: ANOMALOUS ENTITY CONTAINMENT PROTOCOL[/font_size]

[font_size=16]Date: [REDACTED]
Location: Site-[REDACTED]
Classification: Level 4 Clearance Required

SUMMARY:
Recent observations indicate increased activity from anomalous entities within the facility. All personnel are advised to maintain standard containment protocols and report any unusual phenomena immediately.

INCIDENT REPORT #[REDACTED]:
At approximately 14:30 hours, security cameras detected movement in Sector 7-B. Investigation revealed no physical presence, yet motion sensors remained active for 47 minutes. 

CONTAINMENT MEASURES:
- All access points to affected sectors have been sealed
- Enhanced surveillance protocols now in effect
- Staff rotations reduced to essential personnel only

ADDENDUM:
Dr. [REDACTED] has requested additional resources for Project Mirror-Break. Approval pending review by Site Director.

[font_size=12]This document contains sensitive information. Unauthorized disclosure is strictly prohibited.[/font_size][/font_size][/color]"""
	content_label.visible = false
	
	# Style the text to match game theme (green text on black background)
	content_label.add_theme_color_override("default_color", Color.GREEN)
	content_label.add_theme_font_size_override("normal_font_size", 16)
	
	ui_panel.add_child(content_label)
	
	# Create close button with green styling
	close_button = Button.new()
	close_button.text = "Close"
	close_button.size = Vector2(80, 30)
	close_button.position = Vector2(610, 460)
	close_button.pressed.connect(close_panel)
	close_button.visible = false
	
	# Style the button to match game theme
	var button_style_normal = StyleBoxFlat.new()
	button_style_normal.bg_color = Color.BLACK
	button_style_normal.border_color = Color.GREEN
	button_style_normal.border_width_left = 2
	button_style_normal.border_width_right = 2
	button_style_normal.border_width_top = 2
	button_style_normal.border_width_bottom = 2
	close_button.add_theme_stylebox_override("normal", button_style_normal)
	
	var button_style_hover = StyleBoxFlat.new()
	button_style_hover.bg_color = Color.GREEN
	button_style_hover.border_color = Color.GREEN
	button_style_hover.border_width_left = 2
	button_style_hover.border_width_right = 2
	button_style_hover.border_width_top = 2
	button_style_hover.border_width_bottom = 2
	close_button.add_theme_stylebox_override("hover", button_style_hover)
	
	close_button.add_theme_color_override("font_color", Color.GREEN)
	close_button.add_theme_color_override("font_hover_color", Color.BLACK)
	close_button.add_theme_font_size_override("font_size", 20)
	
	ui_panel.add_child(close_button)
