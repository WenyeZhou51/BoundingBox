extends CharacterBody3D
class_name EnemyPrefab

## Enemy AI that chases the player using pathfinding
## Only moves horizontally (X, Z axes), maintains Y position with gravity

@export var move_speed: float = 3.0  # Movement speed (slightly slower than player)
@export var detection_range: float = 100.0  # How far the enemy can detect the player
@export var path_update_interval: float = 0.5  # How often to recalculate path (seconds)

@onready var navigation_agent: NavigationAgent3D = $NavigationAgent3D

var player: CharacterBody3D = null
var path_update_timer: float = 0.0
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

func _ready():
	# Find the player in the scene
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player = players[0]
		print("Enemy: Found player at ", player.global_position)
	else:
		print("Enemy: WARNING - No player found in scene!")
	
	# Configure the navigation agent
	navigation_agent.path_desired_distance = 0.5
	navigation_agent.target_desired_distance = 0.5
	navigation_agent.max_speed = move_speed
	
	# Wait for navigation to be ready
	call_deferred("setup_navigation")

func setup_navigation():
	# Make sure navigation is ready before using it
	await get_tree().physics_frame
	
	# Set initial target to player position if player exists
	if player:
		navigation_agent.target_position = player.global_position

func _physics_process(delta):
	# Apply gravity
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0.0
	
	# Check if we have a player to chase
	if not player or not is_instance_valid(player):
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return
	
	# Update path periodically
	path_update_timer += delta
	if path_update_timer >= path_update_interval:
		path_update_timer = 0.0
		update_target_location()
	
	# Check if player is within detection range
	var distance_to_player = global_position.distance_to(player.global_position)
	if distance_to_player > detection_range:
		# Player too far, stop moving
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return
	
	# Move towards the next position in the path
	if navigation_agent.is_navigation_finished():
		# Reached target or no path available
		velocity.x = 0.0
		velocity.z = 0.0
	else:
		# Get the next position on the path
		var next_path_position = navigation_agent.get_next_path_position()
		
		# Calculate direction to next waypoint (horizontal only)
		var direction = Vector3(
			next_path_position.x - global_position.x,
			0.0,  # Ignore vertical component
			next_path_position.z - global_position.z
		).normalized()
		
		# Set velocity (horizontal movement only)
		velocity.x = direction.x * move_speed
		velocity.z = direction.z * move_speed
		
		# Rotate to face movement direction
		if direction.length() > 0.01:
			var target_rotation = atan2(direction.x, direction.z)
			rotation.y = lerp_angle(rotation.y, target_rotation, delta * 10.0)
	
	# Move the enemy
	move_and_slide()

func update_target_location():
	# Update the navigation target to the player's current position
	if player and is_instance_valid(player) and navigation_agent:
		navigation_agent.target_position = player.global_position

func _on_navigation_agent_velocity_computed(safe_velocity: Vector3):
	# This is called by NavigationAgent3D if using velocity-based movement
	# We're doing direct movement, so this is optional
	velocity = safe_velocity

