extends Node2D

@onready var timer : Timer = get_node("CanvasLayer/BackGround/Timer") 


var host 


func _ready() -> void:
	if host:
		timer.timeout.connect(_end_game)
		timer.wait_time = 301
		timer.start()


func _process(_delta: float) -> void:
	if host:
		for i in Network.rooms[int(self.name)]["Players"].keys():
			update_timer_remote.rpc_id(i, timer.time_left)
#

@rpc("any_peer", "call_local")
func update_timer_remote(new_time_left):
	$CanvasLayer/BackGround/Label.text = "%02d:%02d" % [int(new_time_left / 60), int(new_time_left) % 60]


func _end_game():
	if host:
		Network.end_game.rpc_id(1, self.name)
		set_process(false)
