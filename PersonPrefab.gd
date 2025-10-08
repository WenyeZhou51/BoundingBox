extends BasePrefab

func _ready():
	object_label = "Man"
	confidence = 0.50
	is_interactable = false
	super._ready()  # Call parent's _ready function
