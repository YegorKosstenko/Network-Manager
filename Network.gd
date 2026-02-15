extends Node


var multiplayer_peer : ENetMultiplayerPeer = ENetMultiplayerPeer.new()

const MAX_PLAYERS : int = 9999
const MAX_PLAYERS_ROOM : int = 6
const IP_ADDRESS : String = "127.0.0.1"
const PORT : int = 9090

var rooms : Dictionary = {}
var is_server : bool = false


signal update_rooms(data)
signal update_players(data)
signal leave


func _ready() -> void:
	multiplayer_peer.peer_disconnected.connect(_on_player_disconnected)
	
	if "--server" in OS.get_cmdline_args():
		server_init()
	else:
		client_init()


func server_init():
	is_server = true
	multiplayer_peer.create_server(PORT)
	multiplayer.multiplayer_peer = multiplayer_peer


func client_init():
	is_server = false
	multiplayer_peer.create_client(IP_ADDRESS, PORT)
	multiplayer.multiplayer_peer = multiplayer_peer


func _on_player_disconnected(id):
	if not is_server:
		return
	
	###
	var rooms_to_check = rooms.duplicate()
	
	for room_id in rooms_to_check:
		if rooms.has(room_id) and rooms[room_id]["Players"].has(id):
	###
			for i in multiplayer.get_peers():
				if i != id:
					leave_room_remote.rpc_id(i, room_id, id)
				#else:
					#pass


@rpc("any_peer", "call_remote", "reliable")
func create_room(id_host, name_lobby, name_host):
	if not is_server:
		return
	
	if rooms.has(id_host):
		rooms.erase(id_host)
	
	rooms[id_host] = {
		"Name_lobby" = name_lobby, 
		"Players" = {},
		"Max_players" = 6,
		"Name_host" = name_host,
		"Gaming" = false
	}
	
	create_room_remote.rpc(id_host, name_host, rooms[id_host])


@rpc("authority", "call_remote", "reliable")
func create_room_remote(id_host, name_host, new_room):
	rooms[id_host] = new_room
	
	join_room.rpc_id(1, id_host, name_host, id_host)
	update_rooms.emit(rooms)


@rpc("any_peer", "call_remote", "reliable")
func join_room(room_id, name_player, player_id):
	if not is_server:
		return
	
	if rooms[room_id]["Players"].size() == rooms[room_id]["Max_players"]:
		return
	
	var player_data : Dictionary = {
		"Name" = name_player,
		"skin_id" = 0
	}
	
	rooms[room_id]["Players"][player_id] = player_data
	join_room_remote.rpc(room_id, name_player, player_id)


@rpc("authority", "call_remote", "reliable")
func join_room_remote(room_id, name_player, player_id):
	var player_data : Dictionary = {
		"Name" = name_player,
		"skin_id" = 0
	}
	
	rooms[room_id]["Players"][player_id] = player_data
	
	for i in rooms[room_id]["Players"]:
		if i == multiplayer.get_unique_id():
			_update_players(room_id)
		else:
			_update_players.rpc_id(i, room_id)
	
	update_rooms.emit(rooms)


@rpc("any_peer", "call_remote", "reliable")
func _update_rooms():
	update_rooms.emit(rooms)


@rpc("any_peer", "call_remote", "reliable")
func _update_players(room_id):
	if rooms.has(room_id):
		update_players.emit(rooms[room_id])


@rpc("any_peer", "call_remote", "reliable")
func leave_room(room_id, player_id):
	if not is_server:
		return
		
	if rooms.has(room_id):
		leave_room_remote.rpc(room_id, player_id)


@rpc("authority", "call_remote", "reliable")
func leave_room_remote(room_id, player_id):
	if room_id == player_id:
		var players_in_room = rooms[room_id]["Players"].duplicate()
		
		rooms.erase(player_id)
		
		for i in players_in_room:
			if i == multiplayer.get_unique_id():
				_update_players(room_id)
				leave.emit()
			else:
				_update_players.rpc_id(i, room_id)
				_leave_room.rpc_id(i)
			
		update_rooms.emit(rooms)
		print("Work!")
	
	else:
		if rooms.has(room_id):
			if rooms[room_id]["Players"].has(player_id):
				rooms[room_id]["Players"].erase(player_id)
			
			if player_id == multiplayer.get_unique_id():
				leave.emit()
			
			for i in rooms[room_id]["Players"]:
				if i == multiplayer.get_unique_id():
					_update_players(room_id)
				else:
					_update_players.rpc_id(i, room_id)
	
	update_rooms.emit(rooms)


@rpc("any_peer", "call_remote", "reliable")
func _leave_room():
	leave.emit()


@rpc("any_peer", "call_remote", "reliable")
func start_game(room_id):
	rooms[room_id]["Gaming"] = true
	
	update_rooms.emit(rooms)
