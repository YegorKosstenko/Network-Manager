extends Node2D

@export var timer_path : NodePath
@export var label_timer_path : NodePath

@onready var timer : Timer = get_node(timer_path) 
@onready var label_timer : Label = get_node(label_timer_path)

var host 
var game : bool = true
var time : int


func _ready() -> void:
	if host:
		timer.timeout.connect(_end_game)
		timer.wait_time = time
		timer.start()


func _process(_delta: float) -> void:
	if host:
		for i in Network.rooms[int(self.name)]["Players"].keys():
			if game:
				update_timer_remote.rpc_id(i, timer.time_left)


@rpc("any_peer", "call_local")
func update_timer_remote(new_time_left):
	label_timer.text = "%02d:%02d" % [int(new_time_left / 60), int(new_time_left) % 60]


func _end_game():
	game = false
	if host:
		Network.end_game.rpc_id(1, self.name)
