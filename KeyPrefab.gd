extends BasePrefab

func _ready():
	object_label = "Key"
	confidence = 0.95
	is_interactable = false
	interaction_text = "Snapped"  # This will appear in brackets
	super._ready()


