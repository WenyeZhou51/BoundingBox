extends Node3D
class_name BasePrefab

@export var object_label: String = ""
@export var confidence: float = 0.0
@export var is_interactable: bool = false

func _ready():
	print("Prefab initialized - Label: ", object_label, ", Confidence: ", confidence)

# Virtual function to be overridden by interactable objects
func interact():
	if is_interactable:
		print("Interacting with: ", object_label)
	else:
		print("This object is not interactable")

# Virtual function to be overridden by objects that can control their vision mode visibility
func should_be_visible_in_vision_mode() -> bool:
	return true  # By default, all objects are visible in vision mode
