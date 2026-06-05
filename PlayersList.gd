extends Control


@export var player_scene : PackedScene

var player_labels = {}


func increase_score(for_who):
	assert(for_who in player_labels)
	var pl = player_labels[for_who]
	pl.score += 1
	reload_players()


func minus_score(for_who):
	assert(for_who in player_labels)
	var pl = player_labels[for_who]
	pl.score -= 1
	reload_players()


func add_player(id, player_name):
	var player = player_scene.instantiate()
	player.get_node("NameLabel").text = player_name
	get_node("VBoxContainer").add_child(player)
	
	player_labels[id] = {name = player_name, label = player.get_node("NameLabel"), score = 0, ScoreLabel = player.get_node("ScoreLabel")}


func reload_players():
	for i in get_node("VBoxContainer").get_children():
		i.queue_free()
	
	var sorted_players = []
	
	for player in player_labels.values():
		sorted_players.append(player)
	
	sorted_players.sort_custom(compare_sort)
	
	for i in sorted_players:
		var player = player_scene.instantiate()
		player.get_node("NameLabel").text = i["name"]
		player.get_node("ScoreLabel").text = str(i["score"])
		get_node("VBoxContainer").add_child(player)


func compare_sort(a, b):
	return a["score"] > b["score"]
