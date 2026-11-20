extends SceneTree
var failures := 0
var session: Node
func _initialize() -> void:
	call_deferred("run")
func check(value: bool, label: String) -> void:
	print(("PASS: " if value else "FAIL: ") + label)
	if not value:
		failures += 1
func ticks(count: int) -> void:
	for i in range(count):
		await physics_frame
		await process_frame
func run() -> void:
	session = root.get_node("Session")
	session.run_data.clear()
	session.checkpoint_data.clear()
	session.sound_volume = 0.0
	var game: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	game.hud.intro_overlay.visible = false
	paused = false
	game.player.set_checkpoint(Vector2(2460, 660), "Entrada do Biojardim")
	session.mark("flags", "first_door")
	session.mark("documents", "doc_b01")
	session.mark("pickups", "cell_1450_500")
	session.mark("defeated", "enemy_790_620")
	game.player.power_cells = 1
	session.save_checkpoint(game.player)
	game.player.invulnerability = 0.0
	game.player.take_damage(999, 0)
	check(game.hud.death_overlay.visible and paused, "Morte abre tela e pausa")
	Input.action_press("restart")
	await process_frame
	await process_frame
	Input.action_release("restart")
	await ticks(5)
	game = current_scene
	check(is_instance_valid(game) and game.player.health == 100, "R recarrega cena e restaura vida")
	check(game.player.spawn_position.x == 2460 and game.player.power_cells == 1, "R preserva posição de retorno e célula do posto")
	check(game.first_door.is_open and game.player.documents == 1, "R restaura porta e documento")
	check(not game.hud.intro_overlay.visible, "R não repete abertura")
	# Uma memória pode pausar imediatamente ao reaparecer; confirmar e continuar.
	if game.hud.story_cutscene_overlay.visible:
		game.hud.story_cutscene_overlay.visible = false
		paused = false
	check(get_nodes_in_group("enemies").size() == 13, "Inimigo derrotado antes do posto não reaparece")
	session.run_data.clear()
	session.checkpoint_data.clear()
	session.continue_saved()
	await ticks(3)
	game = current_scene
	check(game.player.power_cells == 1 and game.first_door.is_open, "Continuar carrega o snapshot gravado em disco")
	# Expor os comportamentos novos ao loop de física real.
	game.hud.story_cutscene_overlay.visible = false
	paused = false
	game.player.global_position = Vector2(8750, 660)
	game.player.invulnerability = 100.0
	await ticks(3)
	var boss: Node = game.boss_node
	boss.state = "wave"
	boss.state_time = 0.1
	await ticks(10)
	check(boss.state == "recover" and boss.state_time > 0.0, "Onda termina em abertura real de contra-ataque")
	game.player.global_position.x = 9300
	boss.state = "chase"
	boss.leap_cooldown = 0.0
	await ticks(150)
	check(boss.global_position.x >= boss.arena_left and boss.global_position.x <= boss.arena_right, "Salto e perseguição respeitam a arena")
	print("RETRY RESULT: %d falhas" % failures)
	quit(1 if failures else 0)
