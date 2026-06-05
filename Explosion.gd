extends GPUParticles2D


func _ready() -> void:
	emitting = true
	finished.connect(_finished)


func _on_area_2d_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		body.get_node("cam/Camera2D").start_shake(0.5, 100.0)


func _finished():
	if is_instance_valid(self):
		queue_free()
