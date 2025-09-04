extends BasePrefab

# Physics properties for the ball
@export var ball_mass: float = 0.5
@export var linear_damping: float = 0.1
@export var angular_damping: float = 0.1

var rigid_body: RigidBody3D

func _ready():
	object_label = "Ball"
	confidence = 0.95
	is_interactable = false  # Not interactable in terms of UI, but affected by physics
	
	# Get reference to the RigidBody3D
	rigid_body = $RigidBody3D
	if rigid_body:
		rigid_body.mass = ball_mass
		rigid_body.linear_damp = linear_damping
		rigid_body.angular_damp = angular_damping
		# For bounce and friction, these need to be set in the scene file
		# or through a PhysicsMaterial resource created in the editor
	
	super._ready()  # Call parent's _ready function
