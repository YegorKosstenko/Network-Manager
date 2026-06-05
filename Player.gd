extends CharacterBody2D 


@export var camera_path : NodePath 
@export var aim_path : NodePath
@export var spawn_bullet_path : NodePath
@export var camera_position_path : NodePath
@export var skin_path : NodePath
@export var weapon_path : NodePath
@export var timer_path : NodePath
@export var audio_damage_path : NodePath

@onready var camera = get_node(camera_path)
@onready var aim : Node = get_node(aim_path)
@onready var spawn_bullet = get_node(spawn_bullet_path)
@onready var camera_position = get_node(camera_position_path)
@onready var skin = get_node(skin_path)
@onready var weapon = get_node(weapon_path)
@onready var timer = get_node(timer_path)
@onready var audio_damage = get_node(audio_damage_path)

@onready var joystick_right = get_parent().get_parent().get_node("HUI/Control/JoystickRight")
@onready var joystick_left = get_parent().get_parent().get_node("HUI/Control/JoystickLeft")
@onready var health_progress = get_parent().get_parent().get_node("HUI/Control/HealthProgressBar")
@onready var list_players = get_parent().get_parent().get_node("HUI/ListPlayers")
@onready var list_players_label = get_parent().get_parent().get_node("HUI/Control/ActionPanel/HBC/ListPlayersLabel")

const NETWORK_UPDATE_INTERVAL : float = 1.0 / 16.0

var speed : float = 800.0
var its_me
var network_time : float = 0.0
var _last_sent_position: Vector2 = Vector2.ZERO
var _last_sent_rotation: float = 0.0
var _last_sent_flip: bool = false
var _last_sent_weapon_rotation : float = 0.0
var timer_fire : float = 0.5
var can_fire : bool = true
var can_shake : bool = false
var shake_time : float = 0.2
var id_killer : int = -1
var room_id : int = -1
var game : bool = true
var dead : bool = false
var weapon_rotation_lerp : float = 0.0
var target_position : Vector2
var target_weapon_rotation : float


var seconds = 0.0:
	set(new_value):
		seconds = new_value
		get_parent().get_parent().get_node("HUI/ScreenWait/TimeWaitLabel").text = "Wait %d seconds" % [int(seconds)]


var direction : Vector2 = Vector2():
	set(new_value):
		direction = clamp(new_value, Vector2(-1, -1), Vector2(1, 1))


var health : float = 100:
	set(new_value):
		health = clamp(new_value, 0.0, 100.0)
		
		if health == 0.0:
			death()
		
		health_progress.value = health


func _ready() -> void:
	
	target_position = position
	list_players_label.gui_input.connect(open_list_players)
	list_players.gui_input.connect(touch_list_players)
	its_me = str(multiplayer.get_unique_id()) == str(name)
	room_id = get_parent().get_parent().name.to_int()
	
	if its_me:
		z_index = 1
		camera.enabled = true
		aim.visible = true
		$NameLabel.visible = false
	
	var _tween = create_tween()
	_tween.tween_property(camera, "offset", Vector2.ZERO, 1.0).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.finished.connect(
		func(): 
			can_shake = true
	)


func _process(delta: float) -> void:
	if its_me:
		network_time += delta
		timer_fire -= delta
		direction = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down").normalized()
		
		seconds = timer.time_left
		
		if network_time >= NETWORK_UPDATE_INTERVAL:
			if (position != _last_sent_position or skin.rotation != _last_sent_rotation or skin.flip_h != _last_sent_flip or weapon.rotation != _last_sent_weapon_rotation):
				_last_sent_position = position
				_last_sent_rotation = skin.rotation
				_last_sent_flip = skin.flip_h
				_last_sent_weapon_rotation = weapon.rotation
				Network.update_player_for_server.rpc_id(1, position, weapon.rotation, skin.rotation, skin.flip_h, name.to_int(), room_id)
			
			if Input.is_action_pressed("action_fire") and timer_fire <= 0.0:
				Network.call_fire_on_server.rpc_id(1, name.to_int(), room_id, spawn_bullet.global_transform)
				timer_fire = 0.5
			
			network_time = 0.0
	else:
		position = lerp(position, target_position, 20.0 * delta)
		weapon.rotation = lerp_angle(weapon.rotation, target_weapon_rotation, 20.0 * delta)


func _physics_process(delta: float) -> void:
	if its_me:
		move_player(direction, delta)


func move_player(new_direction, new_delta):
	if !dead:
		if joystick_right and joystick_right.is_pressed:
			weapon_rotation_lerp = joystick_right.output.angle()
		
		weapon.rotation = lerp_angle(weapon.rotation, weapon_rotation_lerp, 10.0 * new_delta)
		camera.global_position = lerp(camera_position.global_position, camera_position.global_position, new_delta)
		
		if new_direction != Vector2.ZERO:
			velocity = velocity.move_toward(new_direction * speed, 1000 * new_delta)
			
			skin.flip_h = new_direction.x < 0
			
			if new_direction.x != 0:
				var target_rotation = 0.5 * new_direction.x
				skin.rotation = lerp(skin.rotation, target_rotation, 0.5)
		else:
			velocity = velocity.move_toward(Vector2.ZERO, 1000 * new_delta)
			
			skin.rotation = lerp(skin.rotation, 0.0, 0.5)
		
		move_and_slide()


func damage(dmg : float, new_position : Vector2):
	if its_me:
		Network.damage_player_on_server.rpc_id(1, name.to_int(), get_parent().get_parent().name.to_int(), dmg)
		camera.start_shake(0.2, 20.0)
		velocity = lerp(new_position / 6, Vector2.ZERO, 0.5)
	
	audio_damage.play()
	skin.modulate = Color(100.0, 100.0, 100.0)
	await get_tree().create_timer(0.1).timeout
	skin.modulate = Color.WHITE


func death():
	if its_me:
		dead = true
		timer.start()
		Network.death_player_on_server.rpc_id(1, name.to_int(), get_parent().get_parent().name.to_int(), id_killer)
		get_parent().get_parent().get_node("HUI/Control").visible = false
		list_players.visible = false
		get_parent().get_parent().get_node("HUI/ScreenWait").visible = true
		joystick_right._reset()
		joystick_left._reset()
		timer.timeout.connect(
			func(): 
				Network.respawn_player_on_server.rpc_id(1, name.to_int(), get_parent().get_parent().name.to_int())
		)


func touch_list_players(event: InputEvent):
	if its_me:
		if !get_parent().get_parent().begin_end:
			if event is InputEventScreenTouch:
				if event.pressed:
					list_players.visible = false
					list_players.get_parent().get_node("Control").visible = true


func open_list_players(event: InputEvent):
	if its_me: 
		if !get_parent().get_parent().begin_end:
			if event is InputEventScreenTouch:
				if event.pressed and !list_players.visible:
					list_players.visible = true
					list_players.get_parent().get_node("Control").visible = false
