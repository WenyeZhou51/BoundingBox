extends BasePrefab

func _ready():
	object_label = "Handle"
	confidence = 0.80
	is_interactable = false
	super._ready()  # Call parent's _ready function
