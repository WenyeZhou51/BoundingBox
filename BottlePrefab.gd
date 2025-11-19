extends BasePrefab

@export var bottle_type: String = "Shampoo"  # Can be "Shampoo" or "Conditioner"

func _ready():
	object_label = bottle_type
	confidence = 0.82
	is_interactable = false
	
	super._ready()

