extends BasePrefab

@export var loading_duration: float = 0.8  # Loading bar duration in seconds

var is_loading: bool = false
var loading_progress: float = 0.0
var loading_timer: float = 0.0
var current_page: int = 0
var total_pages: int = 3

# UI elements
var ui_panel: Panel
var loading_bar: ProgressBar
var content_label: RichTextLabel
var close_button: Button
var prev_button: Button
var next_button: Button
var page_label: Label

# Journal pages
var pages: Array[String] = [
	"""[color=green][font_size=20][center]LAB JOURNAL - PAGE 1[/center]

[font_size=16]Day 47: The specimen continues to grow 
beyond our expectations. Dr. Chen believes 
we've made a breakthrough, but I have 
concerns about the containment protocols.

The neural patterns are unlike anything 
we've seen before.[/font_size][/color]""",
	
	"""[color=green][font_size=20][center]LAB JOURNAL - PAGE 2[/center]

[font_size=16]Day 52: Something went wrong during the 
last test. The specimen broke through 
reinforced glass. We've had to evacuate 
the lower levels.

I can still hear it moving in the vents. 
This was a mistake.[/font_size][/color]""",
	
	"""[color=green][font_size=20][center]LAB JOURNAL - PAGE 3[/center]

[font_size=16]Day 53: This is my final entry. 
The facility is in lockdown. The specimen 
has adapted beyond our worst fears.

If you're reading this, run. 
Don't try to contain it.[/font_size][/color]"""
]

func _ready():
	object_label = "Lab Journal"
	confidence = 0.92
	is_interactable = true
	interaction_text = "Read"
	
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
			show_content()

func interact():
	if is_loading or (ui_panel and ui_panel.visible):
		return  # Don't allow interaction while loading or panel is already shown
	
	start_loading()

func start_loading():
	is_loading = true
	loading_timer = 0.0
	loading_progress = 0.0
	current_page = 0
	
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
	prev_button.visible = false
	next_button.visible = false
	page_label.visible = false
	
	# Release mouse cursor
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func show_content():
	loading_bar.visible = false
	content_label.visible = true
	close_button.visible = true
	prev_button.visible = true
	next_button.visible = true
	page_label.visible = true
	update_page_display()

func close_panel():
	if ui_panel and ui_panel.get_parent():
		ui_panel.get_parent().remove_child(ui_panel)
	
	ui_panel.visible = false
	
	# Capture mouse cursor again
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func previous_page():
	if current_page > 0:
		current_page -= 1
		update_page_display()

func next_page():
	if current_page < total_pages - 1:
		current_page += 1
		update_page_display()

func update_page_display():
	content_label.text = pages[current_page]
	page_label.text = "Page " + str(current_page + 1) + " / " + str(total_pages)
	prev_button.disabled = (current_page == 0)
	next_button.disabled = (current_page == total_pages - 1)

func create_ui_elements():
	# Create main panel with green border styling to match game
	ui_panel = Panel.new()
	ui_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	ui_panel.size = Vector2(600, 400)
	ui_panel.position = Vector2(-300, -200)
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
	loading_bar.size = Vector2(300, 25)
	loading_bar.position = Vector2(-150, -12)
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
	content_label.size = Vector2(560, 320)
	content_label.bbcode_enabled = true
	content_label.visible = false
	
	# Style the text to match game theme (green text on black background)
	content_label.add_theme_color_override("default_color", Color.GREEN)
	content_label.add_theme_font_size_override("normal_font_size", 16)
	
	ui_panel.add_child(content_label)
	
	# Create page label
	page_label = Label.new()
	page_label.text = "Page 1 / 3"
	page_label.position = Vector2(250, 350)
	page_label.add_theme_color_override("font_color", Color.GREEN)
	page_label.add_theme_font_size_override("font_size", 18)
	page_label.visible = false
	ui_panel.add_child(page_label)
	
	# Create Previous button
	prev_button = Button.new()
	prev_button.text = "< Previous"
	prev_button.size = Vector2(120, 30)
	prev_button.position = Vector2(20, 350)
	prev_button.pressed.connect(previous_page)
	prev_button.visible = false
	style_button(prev_button)
	ui_panel.add_child(prev_button)
	
	# Create Next button
	next_button = Button.new()
	next_button.text = "Next >"
	next_button.size = Vector2(120, 30)
	next_button.position = Vector2(360, 350)
	next_button.pressed.connect(next_page)
	next_button.visible = false
	style_button(next_button)
	ui_panel.add_child(next_button)
	
	# Create close button
	close_button = Button.new()
	close_button.text = "Close"
	close_button.size = Vector2(100, 30)
	close_button.position = Vector2(490, 350)
	close_button.pressed.connect(close_panel)
	close_button.visible = false
	style_button(close_button)
	ui_panel.add_child(close_button)

func style_button(button: Button):
	# Style the button to match game theme
	var button_style_normal = StyleBoxFlat.new()
	button_style_normal.bg_color = Color.BLACK
	button_style_normal.border_color = Color.GREEN
	button_style_normal.border_width_left = 2
	button_style_normal.border_width_right = 2
	button_style_normal.border_width_top = 2
	button_style_normal.border_width_bottom = 2
	button.add_theme_stylebox_override("normal", button_style_normal)
	
	var button_style_hover = StyleBoxFlat.new()
	button_style_hover.bg_color = Color.GREEN
	button_style_hover.border_color = Color.GREEN
	button_style_hover.border_width_left = 2
	button_style_hover.border_width_right = 2
	button_style_hover.border_width_top = 2
	button_style_hover.border_width_bottom = 2
	button.add_theme_stylebox_override("hover", button_style_hover)
	
	var button_style_disabled = StyleBoxFlat.new()
	button_style_disabled.bg_color = Color(0.1, 0.1, 0.1, 1)
	button_style_disabled.border_color = Color(0.2, 0.2, 0.2, 1)
	button_style_disabled.border_width_left = 2
	button_style_disabled.border_width_right = 2
	button_style_disabled.border_width_top = 2
	button_style_disabled.border_width_bottom = 2
	button.add_theme_stylebox_override("disabled", button_style_disabled)
	
	button.add_theme_color_override("font_color", Color.GREEN)
	button.add_theme_color_override("font_hover_color", Color.BLACK)
	button.add_theme_color_override("font_disabled_color", Color(0.3, 0.3, 0.3, 1))
	button.add_theme_font_size_override("font_size", 16)
