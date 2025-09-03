extends CharacterBody3D

@export var speed: float = 5.0
@export var jump_velocity: float = 4.5
@export var sensitivity: float = 0.002
@export var max_detection_distance: float = 50.0
@export var interaction_distance: float = 3.0  # Reasonable interaction distance

@onready var camera: Camera3D = $Camera3D
@onready var ui_overlay: Control = $UIOverlay
@onready var black_screen: ColorRect = $UIOverlay/BlackScreen
@onready var bounding_box_container: Control = $UIOverlay/BoundingBoxContainer

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var vision_mode: bool = false
var detected_objects: Array[BasePrefab] = []
var interactable_objects_in_range: Array[BasePrefab] = []

func _ready():
	# Capture the mouse cursor
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	# Find all BasePrefab objects in the scene
	find_all_prefabs()
	
	# Initialize UI
	black_screen.visible = false
	bounding_box_container.visible = false

func _input(event):
	# Handle mouse look
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * sensitivity)
		camera.rotate_x(-event.relative.y * sensitivity)
		camera.rotation.x = clampf(camera.rotation.x, -PI/2, PI/2)
	
	# Toggle mouse capture with Escape
	if event.is_action_pressed("ui_cancel"):
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	# Toggle vision mode with F key
	if event is InputEventKey and event.keycode == KEY_F and event.pressed:
		toggle_vision_mode()
	
	# Handle mouse click for interaction
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			handle_interaction()

func _physics_process(delta):
	# Add the gravity.
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Handle jump.
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = jump_velocity

	# Handle movement with WASD
	var input_dir = Vector2()
	if Input.is_action_pressed("ui_up") or Input.is_key_pressed(KEY_W):
		input_dir.y -= 1
	if Input.is_action_pressed("ui_down") or Input.is_key_pressed(KEY_S):
		input_dir.y += 1
	if Input.is_action_pressed("ui_left") or Input.is_key_pressed(KEY_A):
		input_dir.x -= 1
	if Input.is_action_pressed("ui_right") or Input.is_key_pressed(KEY_D):
		input_dir.x += 1
	
	# Calculate movement direction relative to the player's rotation
	var direction = Vector3()
	if input_dir != Vector2.ZERO:
		direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	if direction:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)

	move_and_slide()
	
	# Update bounding boxes in vision mode
	if vision_mode:
		update_interactable_objects()  # Update interactables for yellow highlighting
		update_bounding_boxes()
	else:
		# In normal mode, hide any bounding boxes
		bounding_box_container.visible = false

func find_all_prefabs():
	detected_objects.clear()
	var scene_root = get_tree().current_scene
	_find_prefabs_recursive(scene_root)
	print("Found ", detected_objects.size(), " prefab objects:")
	for obj in detected_objects:
		print("  - ", obj.object_label, " (Interactable: ", obj.is_interactable, ")")

func _find_prefabs_recursive(node: Node):
	if node is BasePrefab:
		detected_objects.append(node as BasePrefab)
	
	for child in node.get_children():
		_find_prefabs_recursive(child)

func toggle_vision_mode():
	vision_mode = !vision_mode
	black_screen.visible = vision_mode
	
	if vision_mode:
		# In vision mode, show the container and update with all detected objects
		bounding_box_container.visible = true
		update_bounding_boxes()
	else:
		# In normal mode, clear vision boxes and let interactable highlighting take over
		clear_bounding_boxes()
		# Don't set bounding_box_container.visible here - let update_interactable_highlighting control it

func clear_bounding_boxes():
	for child in bounding_box_container.get_children():
		child.queue_free()

func update_bounding_boxes():
	clear_bounding_boxes()
	
	for obj in detected_objects:
		if obj == null or !is_instance_valid(obj):
			continue
			
		# Check if object is within detection range
		var distance_to_object = camera.global_position.distance_to(get_object_center(obj))
		if distance_to_object > max_detection_distance:
			continue
			
		# Check if object's center is in line of sight
		if !is_object_center_in_line_of_sight(obj):
			continue
			
		var bbox = calculate_screen_bounding_box(obj)
		if bbox != Rect2():
			var is_interactable_in_range = obj in interactable_objects_in_range
			create_bounding_box_ui(obj, bbox, is_interactable_in_range)

func calculate_screen_bounding_box(obj: BasePrefab) -> Rect2:
	var camera_3d = camera
	var viewport = get_viewport()
	
	# Get object bounds in world space
	var aabb = get_object_aabb(obj)
	if aabb.size == Vector3.ZERO:
		return Rect2()
	
	# Get all 8 corners of the AABB
	var corners = [
		aabb.position,
		aabb.position + Vector3(aabb.size.x, 0, 0),
		aabb.position + Vector3(0, aabb.size.y, 0),
		aabb.position + Vector3(0, 0, aabb.size.z),
		aabb.position + Vector3(aabb.size.x, aabb.size.y, 0),
		aabb.position + Vector3(aabb.size.x, 0, aabb.size.z),
		aabb.position + Vector3(0, aabb.size.y, aabb.size.z),
		aabb.position + aabb.size
	]
	
	var min_screen = Vector2(INF, INF)
	var max_screen = Vector2(-INF, -INF)
	var any_in_front = false
	
	for corner in corners:
		# Check if point is in front of camera
		var local_pos = camera_3d.to_local(corner)
		if local_pos.z < 0:  # In front of camera
			any_in_front = true
			var screen_pos = camera_3d.unproject_position(corner)
			min_screen.x = min(min_screen.x, screen_pos.x)
			min_screen.y = min(min_screen.y, screen_pos.y)
			max_screen.x = max(max_screen.x, screen_pos.x)
			max_screen.y = max(max_screen.y, screen_pos.y)
	
	if !any_in_front:
		return Rect2()
	
	# Clamp to screen bounds
	var screen_size = viewport.get_visible_rect().size
	min_screen.x = max(0, min_screen.x)
	min_screen.y = max(0, min_screen.y)
	max_screen.x = min(screen_size.x, max_screen.x)
	max_screen.y = min(screen_size.y, max_screen.y)
	
	if min_screen.x >= max_screen.x or min_screen.y >= max_screen.y:
		return Rect2()
	
	return Rect2(min_screen, max_screen - min_screen)

func get_object_aabb(obj: BasePrefab) -> AABB:
	var aabb = AABB()
	
	# Find all MeshInstance3D nodes in the object
	var mesh_instances = []
	_find_mesh_instances_recursive(obj, mesh_instances)
	
	if mesh_instances.is_empty():
		return AABB()
	
	var first = true
	for mesh_instance in mesh_instances:
		var mesh = mesh_instance.mesh
		if mesh != null:
			var local_aabb = mesh.get_aabb()
			var global_aabb = mesh_instance.global_transform * local_aabb
			
			if first:
				aabb = global_aabb
				first = false
			else:
				aabb = aabb.merge(global_aabb)
	
	return aabb

func _find_mesh_instances_recursive(node: Node, mesh_instances: Array):
	if node is MeshInstance3D:
		mesh_instances.append(node)
	
	for child in node.get_children():
		_find_mesh_instances_recursive(child, mesh_instances)

func get_object_center(obj: BasePrefab) -> Vector3:
	# Get the AABB of the object and return its center
	var aabb = get_object_aabb(obj)
	if aabb.size == Vector3.ZERO:
		# If no mesh found, use the object's global position
		return obj.global_position
	return aabb.get_center()

func is_object_center_in_line_of_sight(obj: BasePrefab) -> bool:
	var camera_pos = camera.global_position
	var object_center = get_object_center(obj)
	
	# Create a ray from camera to object center
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(camera_pos, object_center)
	
	# Exclude the player from the raycast
	query.exclude = [self]
	
	var result = space_state.intersect_ray(query)
	
	# If no collision, object is in line of sight
	if result.is_empty():
		return true
	
	# If the collision is with the target object itself, it's in line of sight
	var hit_object = result.collider
	
	# Check if the hit object is the target object or a child of it
	var current_node = hit_object
	while current_node != null:
		if current_node == obj:
			return true
		current_node = current_node.get_parent()
	
	# If we hit something else, the object is occluded
	return false

func create_bounding_box_ui(obj: BasePrefab, bbox: Rect2, is_interactable_in_range: bool = false):
	# Create container for this bounding box
	var container = Control.new()
	container.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	container.position = bbox.position
	container.size = bbox.size
	bounding_box_container.add_child(container)
	
	# Choose color based on interactability and range
	var border_color = Color.GREEN
	var label_color = Color.GREEN
	if is_interactable_in_range:
		border_color = Color.YELLOW
		label_color = Color.YELLOW
	
	# Create hollow border using 4 ColorRect nodes
	create_hollow_border(container, bbox.size, border_color)
	
	# Create label background
	var label_bg = ColorRect.new()
	label_bg.color = Color(0, 0, 0, 0.8)
	label_bg.position = Vector2(0, -30)
	var label_text = obj.object_label + ": " + str(obj.confidence)
	if is_interactable_in_range:
		label_text += " [INTERACT]"
	label_bg.size = Vector2(max(100, label_text.length() * 8 + 20), 25)
	container.add_child(label_bg)
	
	# Create label with appropriate color
	var label = Label.new()
	label.text = label_text
	label.position = Vector2(5, -28)
	label.add_theme_color_override("font_color", label_color)
	container.add_child(label)

func create_hollow_border(container: Control, box_size: Vector2, color: Color = Color.GREEN):
	var border_width = 2
	
	# Top border
	var top_border = ColorRect.new()
	top_border.color = color
	top_border.position = Vector2(0, 0)
	top_border.size = Vector2(box_size.x, border_width)
	container.add_child(top_border)
	
	# Bottom border
	var bottom_border = ColorRect.new()
	bottom_border.color = color
	bottom_border.position = Vector2(0, box_size.y - border_width)
	bottom_border.size = Vector2(box_size.x, border_width)
	container.add_child(bottom_border)
	
	# Left border
	var left_border = ColorRect.new()
	left_border.color = color
	left_border.position = Vector2(0, 0)
	left_border.size = Vector2(border_width, box_size.y)
	container.add_child(left_border)
	
	# Right border
	var right_border = ColorRect.new()
	right_border.color = color
	right_border.position = Vector2(box_size.x - border_width, 0)
	right_border.size = Vector2(border_width, box_size.y)
	container.add_child(right_border)

# Handle interaction when mouse is clicked
func handle_interaction():
	print("Attempting interaction...")
	# Cast a ray from the camera forward to detect what the player is looking at
	var space_state = get_world_3d().direct_space_state
	var camera_pos = camera.global_position
	var camera_forward = -camera.global_transform.basis.z
	var ray_end = camera_pos + camera_forward * interaction_distance
	
	var query = PhysicsRayQueryParameters3D.create(camera_pos, ray_end)
	query.exclude = [self]
	
	var result = space_state.intersect_ray(query)
	
	if not result.is_empty():
		var hit_object = result.collider
		
		# Find the BasePrefab parent of the hit object
		var prefab = find_prefab_parent(hit_object)
		if prefab and prefab.is_interactable:
			print("Interacting with: ", prefab.object_label)
			prefab.interact()
		else:
			print("Hit non-interactable object")
	else:
		print("No object in interaction range")

# Find the BasePrefab parent of a node
func find_prefab_parent(node: Node) -> BasePrefab:
	var current_node = node
	while current_node != null:
		if current_node is BasePrefab:
			return current_node as BasePrefab
		current_node = current_node.get_parent()
	return null

# Update list of interactable objects in range
func update_interactable_objects():
	interactable_objects_in_range.clear()
	
	var player_pos = global_position
	var camera_forward = -camera.global_transform.basis.z
	
	for obj in detected_objects:
		if obj == null or !is_instance_valid(obj) or !obj.is_interactable:
			continue
		
		var obj_center = get_object_center(obj)
		var distance_to_object = player_pos.distance_to(obj_center)
		
		# Check if object is within interaction distance
		if distance_to_object <= interaction_distance:
			# Check if object is roughly in front of the player
			var direction_to_object = (obj_center - player_pos).normalized()
			var dot_product = camera_forward.dot(direction_to_object)
			
			# If dot product is positive, object is in front of player
			if dot_product > 0.3:  # Allow some tolerance for "in front"
				interactable_objects_in_range.append(obj)
	
	# Only print in vision mode when we have interactables
	if vision_mode and interactable_objects_in_range.size() > 0:
		print("Found ", interactable_objects_in_range.size(), " interactable(s) in range")
	
	# Update yellow highlighting for interactable objects
	update_interactable_highlighting()

# Update yellow highlighting for interactable objects in range
func update_interactable_highlighting():
	# Yellow highlighting only appears in vision mode, not normal mode
	if !vision_mode:
		# In normal mode, hide bounding boxes completely
		bounding_box_container.visible = false
		return
	
	# We're in vision mode - show yellow boxes for interactables in range
	# This will be handled by update_bounding_boxes() which calls create_bounding_box_ui
	# with the is_interactable_in_range parameter
