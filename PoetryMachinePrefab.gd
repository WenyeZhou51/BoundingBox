extends BasePrefab

# Audio node for poetry playback
var poetry_audio: AudioStreamPlayer

func _ready():
	object_label = "Poetry Machine"
	confidence = 0.88
	is_interactable = true
	interaction_text = "Play"
	super._ready()
	
	# Create audio player for poetry
	poetry_audio = AudioStreamPlayer.new()
	add_child(poetry_audio)
	
	# Load the poetry audio file
	var poetry_stream = load("res://Audio/Poetry.mp3")
	if poetry_stream:
		poetry_audio.stream = poetry_stream
		print("Poetry audio loaded successfully")
	else:
		print("Warning: Could not load Poetry.mp3")

func interact():
	# Play the poetry audio
	if poetry_audio and poetry_audio.stream:
		if poetry_audio.playing:
			print("Poetry is already playing")
		else:
			print("Playing poetry audio...")
			poetry_audio.play()
	else:
		print("Error: Poetry audio not available")

