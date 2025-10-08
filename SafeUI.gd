extends Control

signal code_entered(code: String)
signal ui_closed

@onready var panel: Panel = $Panel
@onready var title_label: Label = $Panel/TitleLabel
@onready var status_label: Label = $Panel/StatusLabel
@onready var display_label: Label = $Panel/DisplayLabel
@onready var number_pad: GridContainer = $Panel/NumberPad
@onready var action_buttons: HBoxContainer = $Panel/ActionButtons
@onready var clear_button: Button = $Panel/ActionButtons/ClearButton
@onready var enter_button: Button = $Panel/ActionButtons/EnterButton
@onready var close_button: Button = $Panel/ActionButtons/CloseButton

var current_input: String = ""
var correct_passcode: String = "0000"

func _ready():
	# Style the panel with green border
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = Color.BLACK
	style_box.border_color = Color.GREEN
	style_box.border_width_left = 3
	style_box.border_width_right = 3
	style_box.border_width_top = 3
	style_box.border_width_bottom = 3
	panel.add_theme_stylebox_override("panel", style_box)
	
	# Style display label background
	var display_bg = StyleBoxFlat.new()
	display_bg.bg_color = Color(0.1, 0.1, 0.1, 1)
	display_bg.border_color = Color.GREEN
	display_bg.border_width_left = 2
	display_bg.border_width_right = 2
	display_bg.border_width_top = 2
	display_bg.border_width_bottom = 2
	display_label.add_theme_stylebox_override("normal", display_bg)
	
	# Connect number pad buttons
	for i in range(number_pad.get_child_count()):
		var button = number_pad.get_child(i) as Button
		if button:
			if button.text.is_valid_int():
				button.pressed.connect(func(): on_number_pressed(button.text))
			elif button.text == "CLEAR":
				button.pressed.connect(on_clear_pressed)
			elif button.text == "ENTER":
				button.pressed.connect(on_enter_pressed)
	
	# Connect action buttons
	clear_button.pressed.connect(on_clear_pressed)
	enter_button.pressed.connect(on_enter_pressed)
	close_button.pressed.connect(on_close_pressed)
	
	# Style all buttons
	style_all_buttons()
	
	# Initialize display
	update_display()
	
	# Initially hide the UI
	visible = false

func style_all_buttons():
	# Style number pad buttons
	for button in number_pad.get_children():
		if button is Button:
			style_button(button as Button)
	
	# Style action buttons
	for button in action_buttons.get_children():
		if button is Button:
			style_button(button as Button)

func style_button(button: Button):
	# Normal state
	var button_style_normal = StyleBoxFlat.new()
	button_style_normal.bg_color = Color.BLACK
	button_style_normal.border_color = Color.GREEN
	button_style_normal.border_width_left = 2
	button_style_normal.border_width_right = 2
	button_style_normal.border_width_top = 2
	button_style_normal.border_width_bottom = 2
	button.add_theme_stylebox_override("normal", button_style_normal)
	
	# Hover state
	var button_style_hover = StyleBoxFlat.new()
	button_style_hover.bg_color = Color.GREEN
	button_style_hover.border_color = Color.GREEN
	button_style_hover.border_width_left = 2
	button_style_hover.border_width_right = 2
	button_style_hover.border_width_top = 2
	button_style_hover.border_width_bottom = 2
	button.add_theme_stylebox_override("hover", button_style_hover)
	
	# Font colors
	button.add_theme_color_override("font_color", Color.GREEN)
	button.add_theme_color_override("font_hover_color", Color.BLACK)

func show_ui():
	visible = true
	current_input = ""
	update_display()
	status_label.text = "Enter 4-digit code:"
	status_label.modulate = Color.GREEN
	
	# Release mouse cursor
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func hide_ui():
	visible = false
	
	# Capture mouse cursor again
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func on_number_pressed(number: String):
	if current_input.length() < 4:
		current_input += number
		update_display()

func on_clear_pressed():
	current_input = ""
	update_display()
	status_label.text = "Enter 4-digit code:"
	status_label.modulate = Color.GREEN

func on_enter_pressed():
	if current_input.length() != 4:
		status_label.text = "Code must be 4 digits!"
		status_label.modulate = Color.YELLOW
		return
	
	# Emit signal with the entered code
	code_entered.emit(current_input)

func on_close_pressed():
	hide_ui()
	ui_closed.emit()

func update_display():
	var display_text = ""
	for i in range(4):
		if i < current_input.length():
			display_text += "*"
		else:
			display_text += "_"
		if i < 3:
			display_text += " "
	display_label.text = display_text

func show_success():
	status_label.text = "ACCESS GRANTED"
	status_label.modulate = Color.GREEN

func show_error():
	status_label.text = "WRONG CODE"
	status_label.modulate = Color.RED
	
	# Clear input after showing error
	await get_tree().create_timer(1.5).timeout
	current_input = ""
	update_display()
	status_label.text = "Enter 4-digit code:"
	status_label.modulate = Color.GREEN
