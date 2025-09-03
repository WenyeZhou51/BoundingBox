extends BasePrefab

@export var open_angle: float = 90.0  # Degrees to rotate when opening
@export var animation_duration: float = 1.0  # Duration of open/close animation

var is_open: bool = false
var is_animating: bool = false
var tween: Tween
var initial_rotation: Vector3
var door_pivot: Node3D

func _ready():
	object_label = "Door"
	confidence = 0.95
	is_interactable = true
	door_pivot = $DoorPivot
	initial_rotation = door_pivot.rotation_degrees
	super._ready()  # Call parent's _ready function

func interact():
	if is_animating:
		return  # Don't allow interaction while animating
	
	if is_open:
		close_door()
	else:
		open_door()

func open_door():
	if is_animating or is_open:
		return
	
	is_animating = true
	
	# Create tween if it doesn't exist
	if tween:
		tween.kill()
	tween = create_tween()
	
	var target_rotation = initial_rotation + Vector3(0, open_angle, 0)
	
	tween.tween_property(door_pivot, "rotation_degrees", target_rotation, animation_duration)
	tween.tween_callback(_on_door_opened)

func close_door():
	if is_animating or !is_open:
		return
	
	is_animating = true
	
	# Create tween if it doesn't exist
	if tween:
		tween.kill()
	tween = create_tween()
	
	tween.tween_property(door_pivot, "rotation_degrees", initial_rotation, animation_duration)
	tween.tween_callback(_on_door_closed)

func _on_door_opened():
	is_open = true
	is_animating = false
	print("Door opened")

func _on_door_closed():
	is_open = false
	is_animating = false
	print("Door closed")
