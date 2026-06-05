extends Node


var multiplayer_peer : ENetMultiplayerPeer = ENetMultiplayerPeer.new()
var self_id : int = -1

const MAX_PLAYERS_ROOM : int = 6
const IP_ADDRESS : String = "127.0.0.1"
const PORT : int = 9090

var rooms : Dictionary = {}
var is_server : bool = false

signal update_rooms(data)
signal update_players(data)
signal leave
signal error(number_text)


func _ready() -> void:
	multiplayer.peer_disconnected.connect(_on_player_disconnected)
	multiplayer.peer_connected.connect(_on_player_connected)
	multiplayer.connected_to_server.connect(_connected_to_server)
	multiplayer.connection_failed.connect(_connection_failed)
	
	if "--server" in OS.get_cmdline_args():
		server_init()


#func _input(_event: InputEvent) -> void:
	#if Input.is_action_just_pressed("ui_cancel"):
		#get_tree().quit()


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
	
	for room_id in rooms.keys():
		for i in multiplayer.get_peers():
			if i != id:
				leave_room.rpc_id(1, room_id, id)
	
	if rooms.has(id):
		rooms.erase(id)


func _on_player_connected(id):
	if not is_server:
		return
	
	give_id.rpc_id(id, id, rooms)


func _connected_to_server():
	self_id = multiplayer.get_unique_id()
	get_node("/root/Menu/Menu").visible = true
	get_node("/root/Menu/BeginPanel").visible = false


func _connection_failed():
	error.emit(4)


@rpc("any_peer", "call_local", "reliable")
func give_id(new_id, new_rooms):
	self_id = new_id
	get_node("/root/Menu").self_id = self_id
	update_rooms.emit(new_rooms)


@rpc("any_peer", "call_remote", "reliable")
func create_room(id_host, name_room, name_host, time, max_players):
	if not is_server:
		return
	
	if max_players < 2 or max_players > MAX_PLAYERS_ROOM:
		return
	
	if name_room.length() > 30 or not name_room:
		return
	
	if rooms.has(id_host):
		rooms.erase(id_host)
	
	rooms[id_host] = {
		"Name_room" = name_room, 
		"Players" = {},
		"Max_players" = max_players,
		"Name_host" = name_host,
		"Time" = time,
		"Gaming" = false
	}
	
	_update_rooms.rpc(rooms)
	join_room(id_host, name_host, id_host)
	#print("Rooms in server: \n[" + str("%02d:%02d:%02d" % [Time.get_time_dict_from_system().hour, Time.get_time_dict_from_system().minute, Time.get_time_dict_from_system().second]) + "] %d: " % id_host + "
			#Name: {Name_room}; 
			#Players: {Players};
			#Max. players: {Max_players};
			#Name host: {Name_host};
			#Time: {Time}".format(rooms[id_host]))


@rpc("any_peer", "call_remote", "reliable")
func join_room(room_id, name_player, player_id):
	if not is_server:
		return
	
	if rooms.has(room_id):
		if rooms[room_id]["Players"].size() == rooms[room_id]["Max_players"]:
			_error.rpc_id(player_id, 3)
			return
	
	var player_data : Dictionary = {
		"Name" = name_player,
		"skin_id" = 0
	}
	
	rooms[room_id]["Players"][player_id] = player_data
	
	for i in rooms[room_id]["Players"].keys():
		_update_players.rpc_id(i, room_id, rooms)
	
	_update_rooms.rpc(rooms)


@rpc("any_peer", "call_local", "reliable")
func _update_rooms(new_rooms):
	update_rooms.emit(new_rooms)


@rpc("any_peer", "call_local", "reliable")
func _update_players(room_id, new_rooms):
	if new_rooms.has(room_id):
		update_players.emit(new_rooms[room_id])


@rpc("any_peer", "call_local", "reliable")
func leave_room(room_id, player_id):
	if not is_server:
		return
	
	if rooms.has(room_id):
		if room_id == player_id:
			var players_in_room = rooms[room_id]["Players"].duplicate()
			
			rooms.erase(player_id)
			
			for i in players_in_room.keys():
				if i in multiplayer.get_peers():
					abort_game.rpc_id(i, room_id)
					_update_players.rpc_id(i, room_id, rooms)
					_leave_room.rpc_id(i)
					if i != room_id:
						_error.rpc_id(i, 0)
		else:
			if rooms.has(room_id):
				if rooms[room_id]["Players"].has(player_id):
					rooms[room_id]["Players"].erase(player_id)
					delete_player.rpc(player_id, room_id)
				
				if player_id in multiplayer.get_peers():
					_leave_room.rpc_id(player_id)
				
				for i in rooms[room_id]["Players"].keys():
					_update_players.rpc_id(i, room_id, rooms)
						
		_update_rooms.rpc(rooms)


@rpc("authority", "call_remote", "reliable")
func delete_player(player_id, room_id):
	if has_node("/root/" + str(room_id)):
		get_node("/root/" + str(room_id) + "/Players/" + str(player_id)).queue_free()


@rpc("any_peer", "call_remote", "reliable")
func _leave_room():
	leave.emit()


@rpc("any_peer" ,"call_remote", "reliable")
func _error(number_text: int):
	error.emit(number_text)


@rpc("any_peer", "call_remote", "reliable")
func start_game(room_id):
	if not is_server:
		return
	
	rooms[room_id]["Gaming"] = true
	
	if rooms.has(room_id):
		for i in rooms[room_id]["Players"].keys():
			if i in multiplayer.get_peers():
				load_world.rpc_id(i, room_id, rooms)
	
	_update_rooms.rpc(rooms)


@rpc("any_peer", "call_local", "reliable")
func load_world(room_id, new_rooms):
	if has_node("/root/" + str(room_id)):
		return
	
	var world = load("res://World.tscn").instantiate()
	
	get_node("/root/Menu").hide()
	
	world.name = str(room_id)
	world.time = new_rooms[room_id]["Time"]
	
	if room_id == self_id:
		world.host = true
		
	get_node("/root").add_child(world)
	
	for i in new_rooms[room_id]["Players"].keys():
		if has_node("/root/" + str(room_id)):
			get_node("/root/" + str(room_id) + "/HUI/ListPlayers").add_player(i, new_rooms[room_id]["Players"][i]["Name"])
	
	var spawn_points = {}
	var spawn_point_idx = 1
	
	for p in new_rooms[room_id]["Players"].keys():
		spawn_points[p] = spawn_point_idx
		spawn_point_idx += 1
	
	for i in spawn_points:
		var spawn_pos = world.get_node("SpawnPoints/" + str(spawn_points[i])).position
		var player = load("res://Player.tscn").instantiate()
		player.position = spawn_pos
		player.name = str(i)
		player.get_node("NameLabel").text = new_rooms[room_id]["Players"][i]["Name"]
		world.get_node("Players").call_deferred("add_child", player)


@rpc("any_peer", "call_remote", "reliable")
func end_game(room_id):
	if not is_server:
		return
	
	if rooms.has(room_id):
		for i in rooms[room_id]["Players"].keys():
			if i in multiplayer.get_peers():
				end_game_remote.rpc_id(i, room_id)
		await get_tree().create_timer(6.0).timeout
		rooms[room_id]["Gaming"] = false
	
	_update_rooms.rpc(rooms)


@rpc("authority", "call_remote", "reliable")
func end_game_remote(room_id):
	if has_node("/root/" + str(room_id)):
		get_node("/root/" + str(room_id))._end_game()


@rpc("authority", "call_remote", "reliable")
func abort_game(room_id):
	if has_node("/root/" + str(room_id)):
		get_node("/root/" + str(room_id)).queue_free()
		get_node("/root/Menu").show()


@rpc("any_peer", "call_remote", "unreliable")
func update_timer_on_server(new_time : int, room_id : int):
	if not is_server:
		return
	
	var string_time : String = "%02d:%02d" % [int(new_time / 60.0), int(new_time) % 60]
	
	for i in rooms[room_id]["Players"].keys():
		if i in multiplayer.get_peers():
			update_timer_on_clients.rpc_id(i, string_time, room_id)


@rpc("authority", "call_remote", "unreliable")
func update_timer_on_clients(new_string_time, room_id):
	if has_node("/root/" + str(room_id)):
		get_node("/root/" + str(room_id)).label_timer.text = new_string_time


@rpc("any_peer", "call_local", "reliable")
func menu_show():
	get_node("/root/Menu").show()


@rpc("any_peer", "call_remote", "unreliable")
func update_player_for_server(new_position : Vector2, new_weapon_rotation : float, new_skin_rotation : float, new_skin_flip_h : bool, player_id : int, room_id : int):
	if not is_server:
		return
	
	for i in rooms[room_id]["Players"].keys():
		if i in multiplayer.get_peers():
			if i != player_id:
				update_player_for_clients.rpc_id(i, new_position, new_weapon_rotation, new_skin_rotation, new_skin_flip_h, player_id, room_id)


@rpc("authority", "call_remote", "unreliable")
func update_player_for_clients(new_position : Vector2, new_weapon_rotation : float, new_skin_rotation : float, new_skin_flip_h : bool, player_id : int, room_id : int):
	var world = get_node("/root/" + str(room_id))
	
	if has_node("/root/" + str(room_id)):
		if has_node("/root/" + str(room_id) + "/Players/" + str(player_id)):
			var player = world.get_node("Players/" + str(player_id))
			player.target_position = new_position
			player.skin.rotation = new_skin_rotation
			player.skin.flip_h = new_skin_flip_h
			player.target_weapon_rotation = new_weapon_rotation
			#player.get_node("WeaponNode").rotation = new_weapon_rotation
			
			#print("Player ID: " + str(player_id) + ": Update Data")


@rpc("any_peer", "call_remote", "reliable")
func call_fire_on_server(player_id : int, room_id : int, spawn_bullet):
	if not is_server:
		return
	
	for i in rooms[room_id]["Players"].keys():
		if i in multiplayer.get_peers():
			call_fire_on_clients.rpc_id(i, player_id, room_id, spawn_bullet)


@rpc("authority", "call_remote", "reliable")
func call_fire_on_clients(player_id : int, room_id : int, spawn_bullet):
	if has_node("/root/" + str(room_id)):
		var bullet_inst = load("res://Resources/Bullets/Scn/BulletScene.tscn").instantiate()
		var _player = get_node("/root/" + str(room_id) + "/Players/" + str(player_id))
		var anim = _player.get_node("WeaponNode/AnimationPlayer")
		bullet_inst.global_transform = spawn_bullet
		bullet_inst.id_killer = player_id
		_player.get_node("WeaponNode/Weapon/Fire").restart()
		get_node("/root/" + str(room_id)).add_child(bullet_inst)
		if anim.is_playing():
			anim.stop()
		anim.play("fire")


@rpc("any_peer", "call_remote", "reliable")
func damage_player_on_server(player_id : int, room_id : int, damage : float):
	if not is_server: 
		return
	
	if player_id in multiplayer.get_peers():
		damage_player_on_client.rpc_id(player_id, player_id, room_id, damage)


@rpc("authority", "call_remote", "reliable")
func damage_player_on_client(player_id : int, room_id : int, damage : float):
	if has_node("/root/" + str(room_id)):
		get_node("/root/" + str(room_id) + "/Players/" + str(player_id)).health -= damage


@rpc("any_peer", "call_remote", "reliable")
func death_player_on_server(player_id : int, room_id : int, killer_id : int):
	if not is_server:
		return
	
	for i in rooms[room_id]["Players"].keys():
		if i in multiplayer.get_peers():
			death_player_on_clients.rpc_id(i, player_id, room_id, killer_id)


@rpc("authority", "call_remote", "reliable")
func death_player_on_clients(player_id : int, room_id : int, killer_id : int):
	if has_node("/root/" + str(room_id)):
		var player = get_node("/root/" + str(room_id) + "/Players/" + str(player_id))
		var explosion = load("res://Explosion.tscn").instantiate()
		explosion.global_position = player.global_position
		get_node("/root/" + str(room_id)).add_child(explosion)
		get_node("/root/" + str(room_id) + "/HUI/ListPlayers").increase_score(killer_id)
		player.get_node("CollisionShape2D").disabled = true
		player.skin.visible = false
		player.get_node("WeaponNode").visible = false
		player.get_node("NameLabel").visible = false


@rpc("any_peer", "call_remote", "reliable")
func respawn_player_on_server(player_id : int, room_id : int):
	if not is_server:
		return
	
	var random_spawn = randi_range(0, 5)
	
	for i in rooms[room_id]["Players"].keys():
		if i in multiplayer.get_peers():
			respawn_player_on_clients.rpc_id(i, player_id, room_id, random_spawn)


@rpc("authority", "call_remote", "reliable")
func respawn_player_on_clients(player_id : int, room_id : int, random_spawn : int):
	if has_node("/root/" + str(room_id)):
		var player = get_node("/root/" + str(room_id) + "/Players/" + str(player_id))
		player.get_node("CollisionShape2D").disabled = false
		player.skin.visible = true
		player.get_node("WeaponNode").visible = true
		player.get_node("NameLabel").visible = true
		player.global_position = get_node("/root/" + str(room_id) + "/SpawnPoints/" + str(random_spawn)).global_position
		
		if player_id == self_id:
			get_node("/root/" + str(room_id) + "/HUI/Control").visible = true
			get_node("/root/" + str(room_id) + "/HUI/ScreenWait").visible = false
			player.health = 100.0
			player.dead = false
			player.get_node("NameLabel").visible = false
