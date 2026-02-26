extends Control


@export_group("Buttons")
@export var start_create_room_button_path : NodePath
@export var create_button_path : NodePath
@export var start_button_path : NodePath
@export var leave_button_path : NodePath
@export var back_from_create_room_button_path : NodePath
@export var minus_30_sec_button_path : NodePath
@export var plus_30_sec_button_path : NodePath
@export var minus_one_player_button_path : NodePath
@export var plus_one_player_button_path : NodePath

@export_group("LineEdits")
@export var name_player_line_edit_path : NodePath
@export var name_room_line_edit_path : NodePath
@export var search_line_edit_path : NodePath

@export_group("MarginContainers")
@export var create_room_screen_path : NodePath
@export var menu_screen_path : NodePath
@export var room_screen_path : NodePath

@export_group("VBoxContainers")
@export var list_players_path : NodePath
@export var list_rooms_path : NodePath

@export_group("Labels")
@export var time_label_path : NodePath
@export var room_time_label_path : NodePath
@export var max_players_label_path : NodePath

@export_category("Others")
@export var error_dialog_path : NodePath


@onready var start_create_room_button : Button = get_node(start_create_room_button_path)
@onready var create_button : Button = get_node(create_button_path)
@onready var leave_button : Button = get_node(leave_button_path)
@onready var start_button : Button = get_node(start_button_path)
@onready var back_from_create_room_button : Button = get_node(back_from_create_room_button_path)
@onready var minus_30_sec_button : Button = get_node(minus_30_sec_button_path)
@onready var plus_30_sec_button : Button = get_node(plus_30_sec_button_path)
@onready var minus_one_player_button : Button = get_node(minus_one_player_button_path)
@onready var plus_one_player_button : Button = get_node(plus_one_player_button_path)

@onready var name_player_line_edit : LineEdit = get_node(name_player_line_edit_path)
@onready var name_room_line_edit : LineEdit = get_node(name_room_line_edit_path)
@onready var search_line_edit : LineEdit = get_node(search_line_edit_path)

@onready var create_room_screen : MarginContainer = get_node(create_room_screen_path)
@onready var menu_screen : MarginContainer = get_node(menu_screen_path)
@onready var room_screen : MarginContainer = get_node(room_screen_path)

@onready var list_players : VBoxContainer = get_node(list_players_path)
@onready var list_rooms : VBoxContainer = get_node(list_rooms_path)

@onready var time_label : Label = get_node(time_label_path)
@onready var room_time_label : Label = get_node(room_time_label_path)
@onready var max_players_label : Label = get_node(max_players_label_path)

@onready var error_dialog : AcceptDialog = get_node(error_dialog_path)


var time = 300: 
	set(new_value):
		time = clampi(new_value, 30, 900)
		@warning_ignore("integer_division")
		time_label.text = "Time: %02d:%02d" % [time / 60, time % 60]

var max_players = 6:
	set(new_value):
		max_players = clampi(new_value, 2, 6)
		max_players_label.text = "Max. players: %d" % max_players

var self_id = null
var temp_room_id = 0
var error_texts = [
	"Ups... The room has been deleted",
	"The line for filling in\nthe name is empty", 
	"The room name entry line is empty",
	"The room is full",
	]


func _ready() -> void:
	start_create_room_button.pressed.connect(_on_start_create_room_pressed)
	create_button.pressed.connect(_on_create_pressed)
	leave_button.pressed.connect(_on_leave_pressed)
	start_button.pressed.connect(_on_start_pressed)
	search_line_edit.text_changed.connect(_on_search_text_changed)
	back_from_create_room_button.pressed.connect(_on_back_from_create_room)
	minus_30_sec_button.pressed.connect(func(): time -= 30)
	plus_30_sec_button.pressed.connect(func(): time += 30)
	minus_one_player_button.pressed.connect(func(): max_players -= 1)
	plus_one_player_button.pressed.connect(func(): max_players += 1)
	
	@warning_ignore("integer_division")
	time_label.text = "Time: %02d:%02d" % [time / 60, time % 60]
	
	Network.update_rooms.connect(_update_rooms)
	Network.update_players.connect(_update_players)
	Network.leave.connect(_leave_end)
	Network.error.connect(_call_error_dialog)
	
	menu_screen.visible = true
	room_screen.visible = false
	
	self_id = multiplayer.get_unique_id()


func _on_start_create_room_pressed() -> void:
	if name_player_line_edit.text == "":
		_call_error_dialog(1)
		return
	
	create_room_screen.visible = true


func _on_create_pressed() -> void:
	if name_room_line_edit.text == "":
		_call_error_dialog(2)
		return
	
	Network.create_room.rpc_id(1, self_id, name_room_line_edit.text, name_player_line_edit.text, time, max_players)
	menu_screen.visible = false
	room_screen.visible = true
	create_room_screen.visible = false
	temp_room_id = self_id


func _update_rooms(rooms_data: Dictionary) -> void:
	if visible:
		for i in list_rooms.get_children():
			i.queue_free()
		
		for i in rooms_data:
			var room = rooms_data[i]
			
			var b = Button.new()
			b.name = str(i)
			b.text = "%s (%d/%d) - Host: %s" % [room["Name_room"], room["Players"].size(), room["Max_players"], room["Name_host"]]
			b.alignment = 0
			b.disabled = room["Gaming"]
			b.pressed.connect(_join_room.bind(int(b.name)))
			list_rooms.add_child(b)


func _join_room(room_id):
	if name_player_line_edit.text == "":
		_call_error_dialog(1)
		return
	
	Network.join_room.rpc_id(1, room_id, name_player_line_edit.text, self_id)
	temp_room_id = room_id


func _update_players(room_data):
	menu_screen.visible = false
	room_screen.visible = true
	
	var time_in_room = room_data["Time"]
	
	room_time_label.text = "Time: %02d:%02d" % [time_in_room / 60, time_in_room % 60]
	
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


func _on_leave_pressed():
	Network.leave_room.rpc_id(1, temp_room_id, self_id)


func _leave_end():
	menu_screen.visible = true
	room_screen.visible = false


func _on_start_pressed():
	Network.start_game.rpc_id(1, self_id)


func _on_search_text_changed(new_text):
	for room in list_rooms.get_children():
		room.visible = room.text.containsn(new_text)
		if new_text == "":
			room.visible = true


func _on_back_from_create_room() -> void:
	create_room_screen.visible = false


func _call_error_dialog(number_text: int):
	error_dialog.dialog_text = error_texts[number_text]
	error_dialog.popup_centered()
