extends Area2D

var speed = 4000
var time = 0
var queue = true
var id_killer = -1
var psevdo_velocity : Vector2 = Vector2.ZERO

@onready var line = $Line2D
@onready var particles = $Particles


func _physics_process(delta):
	time += delta
	line.add_point(global_position)
	
	if line.points.size() > 5:
		line.remove_point(0)
	
	psevdo_velocity = transform.x * speed
	position += psevdo_velocity * delta
	
	if time >= 0.5 and queue:
		queue_free()


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		body.id_killer = id_killer
		body.damage(5.0, psevdo_velocity)
	
	speed = 0
	queue = false
	$AudioStreamPlayer2DEnd.play()
	particles.emitting = true
	$CollisionShape2D.queue_free()


func _on_particles_finished() -> void:
	queue_free()
