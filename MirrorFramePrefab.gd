extends BasePrefab

func _ready():
	# Mirror frame has 95% confidence as specified
	object_label = "Mirror Frame"
	confidence = 0.95
	is_interactable = false
	
	super._ready()

# Override to make mirror frame visible in vision mode
func should_be_visible_in_vision_mode() -> bool:
	return true

