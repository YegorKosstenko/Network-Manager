extends Control

@export var create_button_path: NodePath
@export var scan_button_path: NodePath
@export var name_player_line_edit_path: NodePath
@export var name_lobby_line_edit_path: NodePath
@export var list_players_path: NodePath
@export var list_rooms_path: NodePath
@export var menu_screen_path: NodePath
@export var lobby_screen_path: NodePath
@export var leave_button_path: NodePath
@export var start_button_path: NodePath

@onready var create_button = get_node(create_button_path)
@onready var scan_button = get_node(scan_button_path)
@onready var name_player_line_edit = get_node(name_player_line_edit_path)
@onready var name_lobby_line_edit = get_node(name_lobby_line_edit_path)
@onready var list_players = get_node(list_players_path)
@onready var list_rooms = get_node(list_rooms_path)
@onready var menu_screen = get_node(menu_screen_path)
@onready var lobby_screen = get_node(lobby_screen_path)
@onready var leave_button = get_node(leave_button_path)
@onready var start_button = get_node(start_button_path)

var self_id = null
var temp_room_id = 0


func _ready() -> void:
	create_button.pressed.connect(_on_create_pressed)
	scan_button.pressed.connect(_on_scan_pressed)
	leave_button.pressed.connect(_on_leave_pressed)
	start_button.pressed.connect(_on_start_pressed)
	
	Network.update_rooms.connect(_update_rooms)
	Network.update_players.connect(_update_players)
	Network.leave.connect(_leave_end)
	
	menu_screen.visible = true
	lobby_screen.visible = false
	
	self_id = multiplayer.get_unique_id()


func _on_create_pressed() -> void:
	if name_lobby_line_edit.text == "":
		return
	
	if name_player_line_edit.text == "":
		return
	
	Network.create_room.rpc_id(1, self_id, name_lobby_line_edit.text, name_player_line_edit.text)
	menu_screen.visible = false
	lobby_screen.visible = true
	temp_room_id = self_id


func _on_scan_pressed() -> void:
	print(Network.rooms)


func _update_rooms(rooms_data: Dictionary) -> void:
	for i in list_rooms.get_children():
		i.queue_free()
	
	for i in rooms_data:
		var room = rooms_data[i]
		
		var b = Button.new()
		b.name = str(i)
		b.text = "%s (%d/%d) - Host: %s" % [room["Name_lobby"], room["Players"].size(), room["Max_players"], room["Name_host"]]
		b.alignment = 0
		b.disabled = room["Gaming"]
		b.pressed.connect(_join_room.bind(int(b.name)))
		list_rooms.add_child(b)


func _join_room(room_id):
	Network.join_room.rpc_id(1, room_id, name_player_line_edit.text, self_id)
	temp_room_id = room_id


func _update_players(room_data):
	menu_screen.visible = false
	lobby_screen.visible = true
	
	for i in list_players.get_children():
		i.queue_free()
	
	for i in room_data["Players"]:
		var l = Label.new()
		
		if i == self_id:
			l.text = room_data["Players"][i]["Name"] + " (You)"
			list_players.add_child(l)
		else:
			l.text = room_data["Players"][i]["Name"]
			list_players.add_child(l)
	
	###
	if room_data.has("Name_host"):
		var host_id = null
		for player_id in room_data["Players"]:
			if room_data["Players"][player_id]["Name"] == room_data["Name_host"]:
				host_id = player_id
				break
		
		if host_id == self_id:
			leave_button.text = "Delete"
			start_button.visible = true
		else:
			leave_button.text = "Leave"
			start_button.visible = false
	###


func _on_leave_pressed():
	Network.leave_room.rpc_id(1, temp_room_id, self_id)


func _leave_end():
	menu_screen.visible = true
	lobby_screen.visible = false


func _on_start_pressed():
	Network.start_game.rpc(self_id)
