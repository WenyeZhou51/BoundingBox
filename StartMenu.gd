extends CanvasLayer

# References to UI elements
var start_button_container: Control
var options_button_container: Control
var quit_button_container: Control
var options_label: Label

# Audio player reference
@onready var hover_sound_audio: AudioStreamPlayer = $HoverSoundAudio

# Flash timer for "NOne" text
var options_flash_timer: float = 0.0
var options_flash_active: bool = false
var options_flash_count: int = 0

func _ready():
	# Set up the UI
	setup_ui()

func _process(delta):
	# Handle options button flashing
	if options_flash_active:
		options_flash_timer += delta
		# Flash 3 times (on/off cycles)
		if options_flash_timer >= 0.3:  # Flash every 0.3 seconds
			options_flash_timer = 0.0
			options_flash_count += 1
			
			# Toggle visibility
			if options_label:
				options_label.visible = !options_label.visible
			
			# Stop after 6 flashes (3 on, 3 off)
			if options_flash_count >= 6:
				options_flash_active = false
				options_flash_count = 0
				if options_label:
					options_label.visible = false

func setup_ui():
	# Create main container that fills the screen
	var main_container = Control.new()
	main_container.name = "MainContainer"
	main_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main_container.mouse_filter = Control.MOUSE_FILTER_IGNORE  # Let clicks pass through to buttons
	add_child(main_container)
	
	# Black background
	var black_bg = ColorRect.new()
	black_bg.color = Color.BLACK
	black_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	black_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	main_container.add_child(black_bg)
	
	# Get viewport size for scaling
	var viewport_size = get_viewport().get_visible_rect().size
	
	# Title bounding box (large, at top) - scaled based on screen size
	var title_container = Control.new()
	title_container.set_anchors_preset(Control.PRESET_CENTER_TOP)
	# Use percentage-based positioning and sizing
	var title_width = viewport_size.x * 0.5  # 50% of screen width
	var title_height = viewport_size.y * 0.15  # 15% of screen height
	title_container.position = Vector2(-title_width / 2, viewport_size.y * 0.1)  # 10% from top
	title_container.size = Vector2(title_width, title_height)
	main_container.add_child(title_container)
	create_title_box(title_container)
	
	# Button bounding boxes (centered with scaled dimensions)
	var button_width = viewport_size.x * 0.35  # 35% of screen width
	var button_height = viewport_size.y * 0.08  # 8% of screen height
	var button_spacing = viewport_size.y * 0.12  # 12% of screen height for spacing
	
	# Start button
	var start_container = Control.new()
	start_container.set_anchors_preset(Control.PRESET_CENTER)
	start_container.position = Vector2(-button_width / 2, -button_spacing)
	start_container.size = Vector2(button_width, button_height)
	main_container.add_child(start_container)
	start_button_container = create_button_box(start_container, "Start", 0.94, _on_start_clicked)
	
	# Options button
	var options_container = Control.new()
	options_container.set_anchors_preset(Control.PRESET_CENTER)
	options_container.position = Vector2(-button_width / 2, 0)
	options_container.size = Vector2(button_width, button_height)
	main_container.add_child(options_container)
	options_button_container = create_button_box(options_container, "Options", 0.87, _on_options_clicked)
	
	# Quit button
	var quit_container = Control.new()
	quit_container.set_anchors_preset(Control.PRESET_CENTER)
	quit_container.position = Vector2(-button_width / 2, button_spacing)
	quit_container.size = Vector2(button_width, button_height)
	main_container.add_child(quit_container)
	quit_button_container = create_button_box(quit_container, "Quit", 0.91, _on_quit_clicked)

func create_title_box(parent: Control):
	var size = parent.size
	
	# Create hollow green border
	create_hollow_border(parent, size, Color.GREEN)
	
	# Create label with confidence score
	var label_text = "Stylized Title ASCII Art: 0.99"
	# Scale font size based on screen height (smaller)
	var viewport_height = get_viewport().get_visible_rect().size.y
	var scaled_font_size = max(12, int(viewport_height * 0.018))  # 1.8% of screen height, minimum 12
	var label = create_label(label_text, Color.GREEN, scaled_font_size)
	
	# Position label at top-left of box
	var label_offset = scaled_font_size * 1.4
	label.position = Vector2(5, -label_offset + 2)
	
	# Create background for label
	var label_bg = ColorRect.new()
	label_bg.color = Color.GREEN
	label_bg.position = Vector2(0, -label_offset)
	
	# Measure text size
	var font = label.get_theme_default_font()
	var text_size = font.get_string_size(label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, scaled_font_size)
	label_bg.size = Vector2(text_size.x + 10, label_offset - 5)
	
	parent.add_child(label_bg)
	parent.add_child(label)

func create_button_box(parent: Control, button_label: String, confidence: float, callback: Callable) -> Control:
	var size = parent.size
	
	# Create hollow green border
	create_hollow_border(parent, size, Color.GREEN)
	
	# Create label with confidence score
	var label_text = button_label + ": " + str(confidence)
	# Scale font size based on screen height (smaller)
	var viewport_height = get_viewport().get_visible_rect().size.y
	var scaled_font_size = max(12, int(viewport_height * 0.018))  # 1.8% of screen height, minimum 12
	var label = create_label(label_text, Color.GREEN, scaled_font_size)
	
	# Position label at top-left of box
	var label_offset = scaled_font_size * 1.4
	label.position = Vector2(5, -label_offset + 2)
	
	# Create background for label
	var label_bg = ColorRect.new()
	label_bg.color = Color.GREEN
	label_bg.position = Vector2(0, -label_offset)
	
	# Measure text size
	var font = label.get_theme_default_font()
	var text_size = font.get_string_size(label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, scaled_font_size)
	label_bg.size = Vector2(text_size.x + 10, label_offset - 5)
	
	parent.add_child(label_bg)
	parent.add_child(label)
	
	# Create invisible button for clicking
	var button = Button.new()
	button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	button.flat = true
	button.modulate = Color(1, 1, 1, 0)  # Invisible
	button.pressed.connect(callback)
	button.mouse_entered.connect(_on_button_hover)
	parent.add_child(button)
	
	# Store reference to label for options button
	if button_label == "Options":
		# Create "NOne" flash label (initially hidden) - scaled font (smaller)
		var none_font_size = max(24, int(viewport_height * 0.04))  # 4% of screen height, minimum 24
		options_label = Label.new()
		options_label.text = "NOne"
		options_label.add_theme_color_override("font_color", Color.GREEN)
		options_label.add_theme_font_size_override("font_size", none_font_size)
		options_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		options_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		options_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		options_label.visible = false
		parent.add_child(options_label)
	
	return parent

func create_hollow_border(container: Control, box_size: Vector2, color: Color):
	var border_width = 2
	
	# Top border
	var top_border = ColorRect.new()
	top_border.color = color
	top_border.position = Vector2(0, 0)
	top_border.size = Vector2(box_size.x, border_width)
	container.add_child(top_border)
	
	# Bottom border
	var bottom_border = ColorRect.new()
	bottom_border.color = color
	bottom_border.position = Vector2(0, box_size.y - border_width)
	bottom_border.size = Vector2(box_size.x, border_width)
	container.add_child(bottom_border)
	
	# Left border
	var left_border = ColorRect.new()
	left_border.color = color
	left_border.position = Vector2(0, 0)
	left_border.size = Vector2(border_width, box_size.y)
	container.add_child(left_border)
	
	# Right border
	var right_border = ColorRect.new()
	right_border.color = color
	right_border.position = Vector2(box_size.x - border_width, 0)
	right_border.size = Vector2(border_width, box_size.y)
	container.add_child(right_border)

func create_label(text: String, color: Color, font_size: int = 20) -> Label:
	var label = Label.new()
	label.text = text
	label.add_theme_color_override("font_color", Color.BLACK)
	label.add_theme_font_size_override("font_size", font_size)
	return label

func _on_start_clicked():
	print("Start button clicked!")
	# Load the main game scene
	get_tree().change_scene_to_file("res://TestScene.tscn")

func _on_options_clicked():
	print("Options button clicked!")
	# Flash "NOne" text
	options_flash_active = true
	options_flash_timer = 0.0
	options_flash_count = 0
	if options_label:
		options_label.visible = true

func _on_quit_clicked():
	print("Quit button clicked!")
	get_tree().quit()

func _on_button_hover():
	# Play hover sound when mouse enters button
	if hover_sound_audio:
		hover_sound_audio.play()

