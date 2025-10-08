extends BasePrefab

func _ready():
	object_label = "Thermometer"
	confidence = 0.74
	is_interactable = false
	super._ready()  # Call parent's _ready function
