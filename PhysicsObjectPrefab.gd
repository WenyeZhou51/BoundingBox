extends RigidBody3D
class_name PhysicsObjectPrefab

# BasePrefab properties (copied because we need to extend RigidBody3D)
@export var object_label: String = "Doll"
@export var confidence: float = 0.42
@export var is_interactable: bool = false
@export var interaction_text: String = "PICK UP"
@export var is_shootable: bool = false
@export var is_trash: bool = true  # Can be picked up and dropped

func _ready():
	print("PhysicsObject initialized - Label: ", object_label, ", Confidence: ", confidence, ", Is Trash: ", is_trash)

# Virtual function to be overridden by interactable objects
func interact():
	if is_interactable:
		print("Interacting with: ", object_label)
	else:
		print("This object is not interactable")

# Virtual function to be overridden by objects that can control their vision mode visibility
func should_be_visible_in_vision_mode() -> bool:
	return true  # By default, all objects are visible in vision mode

