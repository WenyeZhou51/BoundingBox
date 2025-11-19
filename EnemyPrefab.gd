extends CharacterBody3D
class_name EnemyPrefab

## Enemy AI that chases the player using pathfinding
## Only moves horizontally (X, Z axes), maintains Y position with gravity

# ============================================================================
# PERFORMANCE OPTIMIZATIONS APPLIED:
# ============================================================================
# 1. Path Update Interval: Increased from 0.5s to 1.0s
#    - Reduces pathfinding calculations by 50%
# 2. Player Movement Tracking: Only update path if player moved >2.0 units
#    - Eliminates unnecessary path recalculations when player is stationary
# 3. Combined Optimization: Path updates reduced from 2/sec to ~0.5-1/sec
#    - Significant reduction in navigation system overhead
# ============================================================================

@export var move_speed: float = 3.0  # Movement speed (slightly slower than player)
@export var detection_range: float = 100.0  # How far the enemy can detect the player
@export var path_update_interval: float = 1.0  # How often to recalculate path (OPTIMIZED: increased from 0.5 to 1.0 seconds)

@onready var navigation_agent: NavigationAgent3D = $NavigationAgent3D

var player: CharacterBody3D = null
var path_update_timer: float = 0.0
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

# OPTIMIZATION: Track player position to avoid unnecessary path updates
var last_player_position: Vector3 = Vector3.ZERO
var player_move_threshold: float = 2.0  # Only update path if player moved this much

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
	# OPTIMIZED: Only update if player has moved significantly
	if player and is_instance_valid(player) and navigation_agent:
		var current_player_pos = player.global_position
		
		# Check if player moved enough to warrant a path update
		if last_player_position == Vector3.ZERO:
			# First update
			navigation_agent.target_position = current_player_pos
			last_player_position = current_player_pos
		else:
			var distance_moved = current_player_pos.distance_to(last_player_position)
			if distance_moved > player_move_threshold:
				navigation_agent.target_position = current_player_pos
				last_player_position = current_player_pos
			# else: player hasn't moved enough, skip path update

func _on_navigation_agent_velocity_computed(safe_velocity: Vector3):
	# This is called by NavigationAgent3D if using velocity-based movement
	# We're doing direct movement, so this is optional
	velocity = safe_velocity

