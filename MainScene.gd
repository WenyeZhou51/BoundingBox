extends Node

@onready var start_menu: Control = null
@onready var game_scene: Node3D = null

func _ready():
	# Load and show start menu first
	var start_menu_scene = load("res://StartMenu.tscn")
	start_menu = start_menu_scene.instantiate()
	add_child(start_menu)
	
	# Connect to start game and quit game signals
	start_menu.start_game.connect(_on_start_game)
	start_menu.quit_game.connect(_on_quit_game)

func _on_start_game():
	print("Starting game...")
	
	# Remove start menu
	if start_menu:
		start_menu.queue_free()
		start_menu = null
	
	# Load and start the actual game scene (PlayerUI contains the full game)
	var game_scene_packed = load("res://PlayerUI.tscn")
	game_scene = game_scene_packed.instantiate()
	add_child(game_scene)

func _on_quit_game():
	print("Quitting game...")
	get_tree().quit()
