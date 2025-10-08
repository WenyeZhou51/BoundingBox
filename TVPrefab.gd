extends BasePrefab

var is_on: bool = false
var has_been_turned_on: bool = false
var news_audio: AudioStreamPlayer3D

func _ready():
	object_label = "TV"
	confidence = 0.92
	is_interactable = true
	interaction_text = "Turn on"
	
	# Get the audio player
	news_audio = $NewsAudio
	
	super._ready()  # Call parent's _ready function

func interact():
	if has_been_turned_on:
		# TV is stuck after first use, do nothing
		print("TV is stuck - cannot interact")
		return
	
	if not is_on:
		turn_on()

func turn_on():
	is_on = true
	has_been_turned_on = true
	interaction_text = "Stuck"
	
	# Play news sound
	if news_audio:
		print("Playing TV news sound...")
		news_audio.play()
	else:
		print("Error: news_audio is null!")
	
	print("TV turned on - playing news, now stuck")
