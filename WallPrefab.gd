extends BasePrefab

func _ready():
	object_label = "Wall"
	confidence = 0.95
	is_interactable = false
	super._ready()  # Call parent's _ready function
