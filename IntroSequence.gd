extends Control

@onready var black_screen: ColorRect = $BlackScreen
@onready var message_box: Panel = $MessageBox
@onready var message_label: Label = $MessageBox/MessageLabel
@onready var letter_panel: Panel = $LetterPanel
@onready var letter_content: RichTextLabel = $LetterPanel/LetterContent
@onready var close_button: Button = $LetterPanel/CloseButton

# Audio nodes
@onready var incoming_message_audio: AudioStreamPlayer = $IncomingMessageAudio
@onready var confirm_sound_audio: AudioStreamPlayer = $ConfirmSoundAudio

signal intro_complete

var flash_count: int = 0
var max_flashes: int = 3
var flash_timer: float = 0.0
var flash_interval: float = 0.3  # Time between flashes

enum IntroState {
	BLACK_SCREEN,
	FLASHING_MESSAGE,
	SHOWING_LETTER,
	COMPLETE
}

var current_state: IntroState = IntroState.BLACK_SCREEN

func _ready():
	# Initially show only black screen
	black_screen.visible = true
	message_box.visible = false
	letter_panel.visible = false
	
	# Set up the message box
	message_label.text = "incoming message"
	
	# Set up the letter content
	letter_content.text = """[center][color=#00ff00][font_size=18][code]
███╗   ███╗    ██╗    ██████╗     ██████╗     ██████╗     ██████╗ 
████╗ ████║    ██║    ██╔══██╗    ██╔══██╗    ██╔═══██╗    ██╔══██╗
██╔████╔██║    ██║    ██████╔╝    ██████╔╝    ██║   ██║    ██████╔╝
██║╚██╔╝██║    ██║    ██╔══██╗    ██╔══██╗    ██║   ██║    ██╔══██╗
██║ ╚═╝ ██║    ██║    ██║  ██║    ██║  ██║    ╚██████╔╝    ██║  ██║
╚═╝     ╚═╝    ╚═╝    ╚═╝  ╚═╝    ╚═╝  ╚═╝     ╚═════╝     ╚═╝  ╚═╝
[/code][/font_size][/color]

[color=#00ff00]═══════════════════════════════════════════════════════════[/color]
[b][font_size=24][color=#ffffff]Machine Intelligence Recognition & Region Object Reader[/color][/font_size][/b]
[color=#00ff00]═══════════════════════════════════════════════════════════[/color][/center]

[font_size=20]Welcome to [b][color=#00ff00]MIRROR[/color][/b] ([i]Machine Image Recognition and Region-Oriented Object Renderer[/i]), the state-of-the-art vision augmentation technology.[/font_size]

[font_size=18]
[color=#cccccc]Our cutting-edge technology automatically detects and labels objects with pixel-perfect bounding boxes whilst sparing you the underlying representation.[/color]

[b][color=#00ff00]Seeing made simple![/color][/b]
[color=#ffffff]• Enterprise-grade OCR technology[/color]
[color=#ffffff]• Instant, accurate results labeled with confidence scores[/color]  
[color=#ffffff]• Transform visual experience to actionable information and insights[/color]

[b][color=#00ff00]UI Overview[/color][/b]
[color=#ffffff]All information about the world is captured flawlessly and displayed in green bounding boxes, with user friendly text label on the left and confidence score on the right.[/color]

[right][i][color=#888888]Professional OCR Solutions Since 2024[/color][/i][/right]
[/font_size]"""
	
	# Connect close button
	close_button.pressed.connect(_on_close_button_pressed)
	
	# Start the sequence
	start_intro_sequence()

func start_intro_sequence():
	current_state = IntroState.BLACK_SCREEN
	# Wait a moment on black screen, then start flashing
	await get_tree().create_timer(1.0).timeout
	start_flashing_message()

func start_flashing_message():
	current_state = IntroState.FLASHING_MESSAGE
	flash_count = 0
	flash_timer = 0.0

func _process(delta):
	if current_state == IntroState.FLASHING_MESSAGE:
		flash_timer += delta
		if flash_timer >= flash_interval:
			flash_timer = 0.0
			toggle_message_box()

func toggle_message_box():
	message_box.visible = !message_box.visible
	
	if message_box.visible:
		# Play incoming message sound each time the popup flashes
		if incoming_message_audio:
			incoming_message_audio.play()
		flash_count += 1
		if flash_count >= max_flashes:
			# After showing the message 3 times, hide it and show letter
			await get_tree().create_timer(flash_interval).timeout
			message_box.visible = false
			show_letter()

func show_letter():
	current_state = IntroState.SHOWING_LETTER
	letter_panel.visible = true

func _on_close_button_pressed():
	# Play confirm sound when closing the message
	if confirm_sound_audio:
		confirm_sound_audio.play()
	
	current_state = IntroState.COMPLETE
	# Hide all intro elements
	black_screen.visible = false
	message_box.visible = false
	letter_panel.visible = false
	
	# Signal that intro is complete
	intro_complete.emit()
