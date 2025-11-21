extends BasePrefab

@export var cabinet_type: String = "upper"  # "upper" or "lower"
@export var loading_duration: float = 1.0

var is_loading: bool = false
var loading_progress: float = 0.0
var loading_timer: float = 0.0
var is_open: bool = false

# UI elements
var ui_panel: Panel
var loading_bar: ProgressBar
var content_label: RichTextLabel
var close_button: Button

# Audio
var cabinet_open_audio: AudioStreamPlayer

func _ready():
	object_label = "Cabinet"
	confidence = 0.92
	is_interactable = true
	interaction_text = "Open"
	
	# Get the audio player
	cabinet_open_audio = $CabinetOpenAudio
	
	super._ready()
	
	# Create UI elements
	create_ui_elements()

func _process(delta):
	if is_loading:
		loading_timer += delta
		loading_progress = min(loading_timer / loading_duration, 1.0)
		
		if loading_bar:
			loading_bar.value = loading_progress * 100
		
		if loading_progress >= 1.0:
			is_loading = false
			if cabinet_open_audio and cabinet_open_audio.playing:
				cabinet_open_audio.stop()
			show_content()

func interact():
	if is_loading or (ui_panel and ui_panel.visible):
		return
	
	if is_open:
		# Cabinet is already open, just show the contents again
		show_ui()
	else:
		# First time opening, start loading
		start_loading()

func start_loading():
	is_loading = true
	loading_timer = 0.0
	loading_progress = 0.0
	
	# Play cabinet open sound
	if cabinet_open_audio:
		print("Playing cabinet open sound...")
		cabinet_open_audio.play()
	
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

func show_ui():
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return
	
	var ui_overlay = player.get_node("UIOverlay")
	if not ui_overlay:
		return
	
	if ui_panel.get_parent() != ui_overlay:
		ui_overlay.add_child(ui_panel)
	
	ui_panel.visible = true
	loading_bar.visible = false
	content_label.visible = true
	close_button.visible = true
	
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func show_content():
	is_open = true
	loading_bar.visible = false
	content_label.visible = true
	close_button.visible = true
	
	# Update interaction text
	interaction_text = "Inspect"

func close_panel():
	if ui_panel and ui_panel.get_parent():
		ui_panel.get_parent().remove_child(ui_panel)
	
	ui_panel.visible = false
	
	# Capture mouse cursor again
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func create_ui_elements():
	# Create main panel
	ui_panel = Panel.new()
	ui_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	ui_panel.size = Vector2(800, 600)
	ui_panel.position = Vector2(-400, -300)
	ui_panel.visible = false
	
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = Color.BLACK
	style_box.border_color = Color.GREEN
	style_box.border_width_left = 2
	style_box.border_width_right = 2
	style_box.border_width_top = 2
	style_box.border_width_bottom = 2
	ui_panel.add_theme_stylebox_override("panel", style_box)
	
	# Create loading bar
	loading_bar = ProgressBar.new()
	loading_bar.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	loading_bar.size = Vector2(400, 30)
	loading_bar.position = Vector2(-200, -15)
	loading_bar.min_value = 0
	loading_bar.max_value = 100
	loading_bar.value = 0
	
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
	
	# Create content label
	content_label = RichTextLabel.new()
	content_label.position = Vector2(20, 20)
	content_label.size = Vector2(760, 530)
	content_label.bbcode_enabled = true
	
	# Set content based on cabinet type
	if cabinet_type == "upper":
		content_label.text = get_upper_cabinet_content()
	else:
		content_label.text = get_lower_cabinet_content()
	
	content_label.visible = false
	content_label.add_theme_color_override("default_color", Color.GREEN)
	content_label.add_theme_font_size_override("normal_font_size", 18)
	
	ui_panel.add_child(content_label)
	
	# Create close button
	close_button = Button.new()
	close_button.text = "Close"
	close_button.size = Vector2(80, 30)
	close_button.position = Vector2(710, 560)
	close_button.pressed.connect(close_panel)
	close_button.visible = false
	
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

func get_upper_cabinet_content() -> String:
	return """[color=green][font_size=20]UPPER CABINET CONTENTS[/font_size]

[font_size=18]A variety of condiments, cups, plates, dishes, organized neatly into a grid. The surface is impeccably clean[/font_size][/color]"""

func get_lower_cabinet_content() -> String:
	return """[color=green][font_size=20]LOWER CABINET CONTENTS[/font_size]

[font_size=18]A variety of condiments, cups, plates, dishes, organized neatly into a grid. The surface is impeccably clean

Behind the items, tucked in the back corner, you notice a small piece of paper. You pull it out:

[font_size=16]═══════════════════════════════════════════

[center][b]MEDICAL NOTE[/b][/center]

Procedure success, subject health stable, psychological stability to be observed
Watch for 4 weeks.

Ottis Underwood

═══════════════════════════════════════════[/font_size]

The note sends a chill down your spine. What procedure? What subject?[/font_size][/color]"""

