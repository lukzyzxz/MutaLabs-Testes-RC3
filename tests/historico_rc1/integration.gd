extends SceneTree

var game: Node
var session: Node
var failures := 0
var checks := 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, description: String) -> void:
	checks += 1
	if condition:
		print("PASS: " + description)
	else:
		failures += 1
		push_error("FAIL: " + description)

func frames(count: int) -> void:
	for index in range(count):
		await physics_frame
		await process_frame

func start_game() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	await process_frame
	game.hud.intro_overlay.visible = false
	paused = false
	for enemy in get_nodes_in_group("enemies"):
		enemy.set_physics_process(false)
	await frames(3)

func run() -> void:
	session = root.get_node("Session")
	session.run_data.clear()
	session.checkpoint_data.clear()
	session.seen.clear()
	session.journal.clear()
	session.sound_volume = 0.0
	await start_game()
	check(get_nodes_in_group("enemies").size() == 14, "Inicialização: 13 inimigos e um chefe")
	var player: Node2D = game.player
	player.global_position = Vector2(150, 660)
	player.velocity = Vector2.ZERO
	await frames(3)
	game._spawn_enemy(Vector2(222, 660), "crawler")
	var target: Node2D = get_nodes_in_group("enemies").back()
	target.set_physics_process(false)
	player.attack()
	check(target.health == 70, "Soco não aplica dano antes do quadro de impacto")
	await frames(12)
	check(target.health == 35, "Quadro de impacto aplica um único dano de 35")
	await frames(20)
	player.global_position = Vector2(150, 660)
	player.velocity = Vector2.ZERO
	target.global_position = Vector2(230, 660)
	game._add_static_rect(Vector2(192, 620), Vector2(12, 110), Color.TRANSPARENT)
	var wall: Node = game.get_child(game.get_child_count() - 1)
	await frames(2)
	player.attack()
	await frames(12)
	check(target.health == 35, "Parede bloqueia o soco")
	wall.queue_free()
	await frames(20)
	player.global_position = Vector2(150, 660)
	player.velocity = Vector2.ZERO
	target.global_position = Vector2(350, 660)
	player.facing = 1.0
	player.fire_syringe()
	await frames(30)
	check(not is_instance_valid(target), "Projétil acerta inimigo baixo sem atravessar sua colisão")
	player.syringe_ammo = 2
	player.syringe_reload_remaining = 0.0
	player._start_syringe_reload()
	check(player.syringe_reload_remaining > 6.9, "Recarga manual funciona com munição parcial")
	player.on_enemy_killed()
	check(player.syringe_reload_remaining <= 5.51, "Abate reduz a recarga em 1,5 segundo")
	player.syringe_reload_remaining = 0.01
	await frames(2)
	check(player.syringe_ammo == 3, "Recarga termina com três disparos")
	player.apply_powerup("shield")
	player.apply_powerup("catalyst")
	player._update_powerup(25.0)
	check(player.shield_charges == 2 and player.active_powerup == "", "Escudo não expira nem é substituído pelo catalisador")
	player.health = 100
	player.invulnerability = 0.0
	player.take_damage(28, 0)
	check(player.health == 100 and player.shield_charges == 1, "Escudo absorve impacto e consome uma carga")
	player.invulnerability = 0.0
	player.take_damage(28, 0)
	check(player.health == 100 and player.shield_charges == 0, "Segundo impacto esgota o escudo")
	player.global_position = Vector2(150, 660)
	player.velocity = Vector2.ZERO
	player.health = 100
	game._spawn_pickup(Vector2(150, 630), "medkit")
	var kit: Node = game.get_child(game.get_child_count() - 1)
	await frames(4)
	check(is_instance_valid(kit), "Kit não é consumido com vida cheia")
	player.health = 70
	await frames(4)
	check(player.health == 100 and not is_instance_valid(kit), "Kit cura ao precisar, mesmo sem sair da área")
	player.global_position = Vector2(150, 660)
	player.velocity = Vector2.ZERO
	player.invulnerability = 0.15
	game._spawn_hazard(Vector2(150, 640), Vector2(1200, 40), "acid")
	var acid: Node = game.get_child(game.get_child_count() - 1)
	await frames(85)
	check(player.health <= 64, "Ácido continua causando dano após a invulnerabilidade inicial")
	acid.queue_free()
	player.invulnerability = 0.0
	player.set_checkpoint(Vector2(2460, 660), "Entrada do Biojardim")
	session.mark("flags", "first_door")
	session.mark("flags", "reactor")
	session.mark("pickups", "cell_1450_500")
	session.mark("documents", "doc_b01")
	player.power_cells = 3
	check(session.save_checkpoint(player), "Posto grava um salvamento válido em disco")
	session.remember("TESTE", "Entrada do diário")
	session.mark("pickups", "medkit_after_checkpoint")
	session.run_data = session.checkpoint_data.duplicate(true)
	check(not session.marked("pickups", "medkit_after_checkpoint"), "Tentativa restaura itens ao estado do posto")
	check(session.has_save(), "Salvamento pode ser lido novamente")
	game._restore_progress()
	check(player.global_position.x == 2460 and player.power_cells == 3 and game.first_door.is_open and game.reactor_gate.is_open, "Restauração integra posição, células e portas")
	game._on_document_collected("PROTOCOLO ZERO", "texto", "res://assets/cutscenes/doc_protocol_zero.png", "texto")
	check(not game.hud.objective_label.text.contains("reuna") and not game.hud.objective_label.text.contains("encontre 3"), "Documento fora de ordem não regride o objetivo")
	game.hud.story_cutscene_overlay.visible = false
	paused = false
	game.menus.open_menu(true)
	check(paused and game.menus.journal_text.get_parsed_text().contains("Entrada do diário"), "Diário pausa o mundo e mostra registros")
	game.menus.close_menu()
	check(not paused, "Menu retoma o jogo")
	var boss: Node2D = game.boss_node
	boss.take_damage(42, 1)
	check(boss.health == 520, "Chefe não recebe dano antes de entrar na arena")
	player.global_position = Vector2(8450, 660)
	player.velocity = Vector2.ZERO
	player.health = 100
	await frames(3)
	check(game.arena_started and game.arena_door.battle_locked and boss.active, "Entrada salva o posto, fecha a arena e ativa o chefe")
	check(session.checkpoint_data.get("checkpoint_name") == "Camara Zero", "Tentativa do chefe tem checkpoint próprio")
	boss.take_damage(270, 1)
	check(boss.phase_two, "Chefe muda de fase abaixo de metade da vida")
	boss.take_damage(999, 1)
	await frames(2)
	check(game.boss_defeated and not game.final_gate.is_open and not game.arena_door.battle_locked, "Derrota desbloqueia arena e aguarda encerramento do protocolo")
	game.protocol_console.interact(player)
	await frames(2)
	check(game.protocol_closed and game.final_gate.is_open, "Terminal encerra protocolo e abre saída")
	game._on_exit_entered(player)
	check(game.hud.end_overlay.visible and paused, "Elevador encerra a fase após o chefe")
	print("RESULT: %d verificações, %d falhas" % [checks, failures])
	quit(1 if failures > 0 else 0)
