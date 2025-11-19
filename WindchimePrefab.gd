extends BasePrefab

@onready var pivot = $PivotPoint

var swing_amount = 15.0  # degrees
var swing_speed = 2.0  # oscillations per second
var time_offset = 0.0  # Random offset for variety

func _ready():
	object_label = "Windchime"
	confidence = 0.92
	is_interactable = false
	is_shootable = true
	super._ready()
	
	# Randomize the starting phase for variety
	time_offset = randf() * TAU

func _physics_process(delta):
	# Simple pendulum motion using sine wave
	if pivot:
		var time = Time.get_ticks_msec() / 1000.0
		var angle = sin(time * swing_speed + time_offset) * deg_to_rad(swing_amount)
		pivot.rotation.z = angle

