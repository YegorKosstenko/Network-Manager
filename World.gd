extends Node2D

@export var timer_path : NodePath
@export var label_timer_path : NodePath

@onready var timer : Timer = get_node(timer_path) 
@onready var label_timer : Label = get_node(label_timer_path)

const NETWORK_UPDATE_INTERVAL : float = 1.0 / 1.0

var network_time : float = 0.0
var host 
var game : bool = true
var time : int
var begin_end : bool = false


func _ready() -> void:
	if has_node("/root/Menu"):
		get_node("/root/Menu/AudioStreamPlayer").playing = false
	
	if host:
		timer.timeout.connect(func(): Network.end_game.rpc_id(1, self.name.to_int()))
		timer.wait_time = time
		timer.start()


func _process(_delta: float) -> void:
	if host:
		if game:
			network_time += _delta
			if network_time >= NETWORK_UPDATE_INTERVAL:
				Network.update_timer_on_server.rpc_id(1, int(timer.time_left), self.name.to_int())
				network_time = 0.0


func _end_game():
	for i in get_node("HUI").get_children():
		i.visible = false
	begin_end = true
	get_node("HUI/ListPlayers").visible = true
	get_node("HUI/Control/JoystickLeft")._reset()
	get_node("HUI/Control/JoystickRight")._reset()
	await get_tree().create_timer(6.0).timeout
	game = false
	if has_node("/root/Menu"):
		get_node("/root/Menu/AudioStreamPlayer").playing = true
	get_node("/root/Menu").show()
	queue_free()
