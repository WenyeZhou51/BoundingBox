extends Control

@onready var black_screen: ColorRect = $BlackScreen
@onready var ascii_art_label: Label = $AsciiArtLabel
@onready var credits_label: RichTextLabel = $CreditsLabel
@onready var incoming_message_audio: AudioStreamPlayer = $IncomingMessageAudio
@onready var confirm_sound_audio: AudioStreamPlayer = $ConfirmSoundAudio

signal end_sequence_complete

var sequence_active: bool = false

func _ready():
	# Initially hide everything
	visible = false
	black_screen.visible = false
	ascii_art_label.visible = false
	credits_label.visible = false
	
	# Set up the ASCII art (same as from intro sequence)
	ascii_art_label.text = """███╗   ███╗    ██╗    ██████╗     ██████╗     ██████╗     ██████╗ 
████╗ ████║    ██║    ██╔══██╗    ██╔══██╗    ██╔═══██╗    ██╔══██╗
██╔████╔██║    ██║    ██████╔╝    ██████╔╝    ██║   ██║    ██████╔╝
██║╚██╔╝██║    ██║    ██╔══██╗    ██╔══██╗    ██║   ██║    ██╔══██╗
██║ ╚═╝ ██║    ██║    ██║  ██║    ██║  ██║    ╚██████╔╝    ██║  ██║
╚═╝     ╚═╝    ╚═╝    ╚═╝  ╚═╝    ╚═╝  ╚═╝     ╚═════╝     ╚═╝  ╚═╝"""
	
	# Set up the credits text (already set in scene file with BBCode)
	# credits_label.text = "[center][b][color=#00ff00]Produced by Wenye Zhou[/color][/b][/center]"

func start_end_sequence():
	if sequence_active:
		return
		
	sequence_active = true
	print("EndSequence: Starting end sequence...")
	
	# Wait 5 seconds before starting
	await get_tree().create_timer(5.0).timeout
	
	# Show the control and black screen
	visible = true
	black_screen.visible = true
	
	# Play confirm sound for logo
	if confirm_sound_audio:
		confirm_sound_audio.play()
	
	# Show ASCII art in center of screen
	ascii_art_label.visible = true
	print("EndSequence: Showing ASCII art")
	
	# Wait 3 seconds
	await get_tree().create_timer(3.0).timeout
	
	# Hide ASCII art and show credits
	ascii_art_label.visible = false
	credits_label.visible = true
	print("EndSequence: Showing credits")
	
	# Play confirm sound for credits
	if confirm_sound_audio:
		confirm_sound_audio.play()
	
	# Wait 5 seconds then quit the game
	await get_tree().create_timer(5.0).timeout
	print("EndSequence: Quitting game...")
	get_tree().quit()
