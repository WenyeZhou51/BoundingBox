extends BasePrefab

func _ready():
	object_label = "Bed"
	confidence = 0.88
	is_interactable = false
	super._ready()  # Call parent's _ready function
