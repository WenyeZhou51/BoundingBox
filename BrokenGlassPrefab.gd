extends BasePrefab

@export var glass_lifetime: float = 10.0  # How long glass pieces stay before disappearing
@export var bounce_damping: float = 0.3   # How much bounce is reduced on impact

var rigid_body: RigidBody3D
var initial_velocity: Vector3
var has_bounced: bool = false

func _ready():
	# Broken glass pieces have high confidence and are labeled as "Broken Glass"
	object_label = "Broken Glass"
	confidence = 1.0
	is_interactable = false
	
	# Find the RigidBody3D component
	rigid_body = get_node("RigidBody3D")
	if rigid_body:
		# Connect to collision signals to handle bouncing
		rigid_body.body_entered.connect(_on_collision)
	
	# Set up automatic cleanup after lifetime expires
	var timer = Timer.new()
	timer.wait_time = glass_lifetime
	timer.one_shot = true
	timer.timeout.connect(_cleanup_glass)
	add_child(timer)
	timer.start()
	
	super._ready()

func _on_collision(body):
	# Reduce velocity on collision to simulate energy loss
	if rigid_body and not has_bounced:
		has_bounced = true
		var current_velocity = rigid_body.linear_velocity
		rigid_body.linear_velocity = current_velocity * bounce_damping

func set_initial_velocity(velocity: Vector3):
	initial_velocity = velocity
	if rigid_body:
		rigid_body.linear_velocity = velocity

func _cleanup_glass():
	# Fade out and remove the glass piece
	print("Cleaning up broken glass piece: ", object_label)
	queue_free()

# Override to make broken glass visible in vision mode
func should_be_visible_in_vision_mode() -> bool:
	return true

