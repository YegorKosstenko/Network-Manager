extends Camera2D

# Время, оставшееся до конца тряски
var shake_time_left: float = 0.0
# Максимальная сила тряски (в пикселях)
var shake_intensity: float = 0.0
# Изначальная длительность (нужна для расчета затухания)
var shake_duration_total: float = 0.0


func _process(delta: float) -> void:
	if get_parent().get_parent().can_shake:
		if shake_time_left > 0.0:
			# Уменьшаем оставшееся время
			shake_time_left -= delta
			
			# Вычисляем текущую силу тряски (затухание от 1.0 до 0.0)
			# Чем меньше времени осталось, тем слабее тряска
			var decay = shake_time_left / shake_duration_total
			var current_intensity = shake_intensity * decay
			
			# Генерируем случайное смещение
			# randf_range(-1, 1) дает число от -1 до 1
			var random_offset = Vector2(
				randf_range(-1, 1), 
				randf_range(-1, 1)
			).normalized() * current_intensity
			
			# Применяем смещение к камере
			offset = random_offset
		else:
			# Когда тряска закончилась, сбрасываем смещение в ноль
			offset = Vector2.ZERO

# Функция для запуска тряски
# duration: сколько секунд трясти
# intensity: насколько сильно трясти (пиксели)
func start_shake(duration: float, intensity: float) -> void:
	shake_time_left = duration
	shake_duration_total = duration
	shake_intensity = intensity
