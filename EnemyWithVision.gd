extends CharacterBody3D
class_name EnemyWithVision

## Enemy AI that chases player + shows up in bounding box vision
## This is an enhanced version of EnemyPrefab that integrates with your vision system

@export var move_speed: float = 3.0
@export var detection_range: float = 100.0
@export var path_update_interval: float = 0.5

# Vision system integration
@export var object_label: String = "Enemy"
@export var confidence: float = 0.95

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
		
		# Register with player's detection system if available
		if player.has_method("add_detected_enemy"):
			player.add_detected_enemy(self)
	else:
		print("Enemy: WARNING - No player found in scene!")
	
	# Configure the navigation agent
	navigation_agent.path_desired_distance = 0.5
	navigation_agent.target_desired_distance = 0.5
	navigation_agent.max_speed = move_speed
	
	# Wait for navigation to be ready
	call_deferred("setup_navigation")

func setup_navigation():
	await get_tree().physics_frame
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
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return
	
	# Move towards the next position in the path
	if navigation_agent.is_navigation_finished():
		velocity.x = 0.0
		velocity.z = 0.0
	else:
		var next_path_position = navigation_agent.get_next_path_position()
		var direction = Vector3(
			next_path_position.x - global_position.x,
			0.0,
			next_path_position.z - global_position.z
		).normalized()
		
		velocity.x = direction.x * move_speed
		velocity.z = direction.z * move_speed
		
		if direction.length() > 0.01:
			var target_rotation = atan2(direction.x, direction.z)
			rotation.y = lerp_angle(rotation.y, target_rotation, delta * 10.0)
	
	move_and_slide()

func update_target_location():
	if player and is_instance_valid(player) and navigation_agent:
		navigation_agent.target_position = player.global_position

# Vision system compatibility methods (optional - for bounding box integration)
func should_be_visible_in_vision_mode() -> bool:
	return true  # Always visible in vision mode

func get_mesh_instances() -> Array:
	# Return mesh instances for bounding box calculation
	var meshes = []
	_find_mesh_instances_recursive(self, meshes)
	return meshes

func _find_mesh_instances_recursive(node: Node, mesh_instances: Array):
	if node is MeshInstance3D:
		mesh_instances.append(node)
	for child in node.get_children():
		_find_mesh_instances_recursive(child, mesh_instances)

