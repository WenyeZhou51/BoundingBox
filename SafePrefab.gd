extends BasePrefab

@export var correct_passcode: String = "0000"

var is_door_open: bool = false
var is_safe_opened: bool = false  # Track if safe has ever been opened
var gun_prefab: BasePrefab

# UI reference
var safe_ui: Control

# Audio
var confirm_audio: AudioStreamPlayer
var wrong_code_audio: AudioStreamPlayer

# 3D elements
var safe_door: Node3D
var gun_container: Node3D
var door_collision: CollisionShape3D

func _ready():
	object_label = "Safe"
	confidence = 0.92
	is_interactable = true
	interaction_text = "OPEN"
	
	# Get references to child nodes
	safe_door = $SafeDoor
	gun_container = $GunContainer
	confirm_audio = $ConfirmAudio
	wrong_code_audio = $ScareAudio  # Reuse scare sound for wrong code
	
	# Find the door collision shape (it's in StaticBody3D with door position)
	var static_body = $StaticBody3D
	for child in static_body.get_children():
		if child is CollisionShape3D:
			var collision = child as CollisionShape3D
			# Check if this collision is at the door position
			if collision.transform.origin.x < 0:  # Door is at negative X
				door_collision = collision
				break
	
	# Initially hide the gun
	if gun_container:
		gun_container.visible = false
	
	# Load and setup UI scene
	var safe_ui_scene = preload("res://SafeUI.tscn")
	safe_ui = safe_ui_scene.instantiate()
	
	# Connect UI signals
	safe_ui.code_entered.connect(_on_code_entered)
	safe_ui.ui_closed.connect(_on_ui_closed)
	
	super._ready()  # Call parent's _ready function

func interact():
	if is_safe_opened:
		return  # Don't allow interaction once safe has been opened
	
	show_number_pad()

func show_number_pad():
	# Get the player and add UI to their overlay
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		print("Error: Could not find player")
		return
	
	var ui_overlay = player.get_node("UIOverlay")
	if not ui_overlay:
		print("Error: Could not find UIOverlay")
		return
	
	# Add UI to overlay and show it
	if safe_ui.get_parent() == null:
		ui_overlay.add_child(safe_ui)
	
	safe_ui.show_ui()

func hide_number_pad():
	if safe_ui:
		safe_ui.hide_ui()

func _on_code_entered(code: String):
	# Play confirm sound for button press
	if confirm_audio:
		confirm_audio.play()
	
	if code == correct_passcode:
		# Correct code entered
		safe_ui.show_success()
		
		# Play confirm sound
		if confirm_audio:
			confirm_audio.play()
		
		# Open safe door after a brief delay
		await get_tree().create_timer(1.0).timeout
		open_safe_door()
		hide_number_pad()
	else:
		# Wrong code entered
		safe_ui.show_error()
		
		# Play wrong code sound
		if wrong_code_audio:
			wrong_code_audio.play()

func _on_ui_closed():
	hide_number_pad()

func open_safe_door():
	is_door_open = true
	is_safe_opened = true
	is_interactable = false  # Disable further interaction
	
	# Make the door disappear completely
	if safe_door:
		safe_door.visible = false
	
	# Disable the door collision so players can access the gun
	if door_collision:
		door_collision.disabled = true
		
	show_gun_inside()

func show_gun_inside():
	# Show the gun inside the safe
	if gun_container:
		gun_container.visible = true
		
		# Find the gun prefab and make it interactable
		var gun = gun_container.get_child(0) if gun_container.get_child_count() > 0 else null
		if gun and gun is BasePrefab:
			gun_prefab = gun as BasePrefab
			gun_prefab.is_interactable = true
			
			# Add the gun to detected objects so it shows up in vision mode
			var player = get_tree().get_first_node_in_group("player")
			if player and player.has_method("add_detected_object"):
				player.add_detected_object(gun_prefab)
	
	print("Safe opened permanently! Gun is now accessible.")

# Override the vision mode visibility function
func should_be_visible_in_vision_mode() -> bool:
	return true  # Safe is always visible in vision mode
