extends BasePrefab
class_name SusStepPrefab

func _ready():
	# Set the sus step properties - looks like a step but with different label/confidence
	object_label = "step"
	confidence = 0.34
	
	# Call parent ready
	super._ready()
