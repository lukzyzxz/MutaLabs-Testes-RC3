extends SceneTree
var game: Node
var session: Node
var checks := 0
var failures := 0
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	print(("PASS: " if ok else "FAIL: ")+label)
	if not ok: failures += 1
func ticks(n: int) -> void:
	for i in range(n):
		await physics_frame
		await process_frame
func press(action: String) -> void:
	Input.action_press(action)
	await ticks(2)
	Input.action_release(action)
	await ticks(2)
func go(pos: Vector2) -> void:
	game.player.position = pos
	game.player.velocity = Vector2.ZERO
	game.player.dash_time = 0
	game.player.hurt_lock = 0
	game.player.can_control = true
	game.player.invulnerability = 9999
	await ticks(5)
func close_reader() -> void:
	await ticks(50)
	if game.hud.story_cutscene_overlay.visible: await press("interact")
	await ticks(20)
	if game.hud.document_panel.visible: await press("interact")
	await ticks(20)
func run() -> void:
	session = root.get_node("Session")
	session.run_data.clear()
	session.checkpoint_data.clear()
	session.seen.clear()
	session.journal.clear()
	session.sound_volume = 0
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	game.hud.intro_overlay.hide()
	paused = false
	for e in get_nodes_in_group("enemies"): e.set_physics_process(false)
	await ticks(5)
	# All 4 actual records must be reachable/readable and close via the real input path.
	for pos in [Vector2(990,443),Vector2(3420,373),Vector2(5450,443),Vector2(7420,513)]:
		await go(pos)
		await press("interact")
		check(game.hud.story_cutscene_overlay.visible,"Documento acessivel com E em %d"%pos.x)
		await close_reader()
		check(not paused and not game.hud.document_panel.visible,"Leitura fecha e devolve controle em %d"%pos.x)
	check(game.player.documents==4,"Quatro documentos coletados sem duplicacao")
	# All three required cells must be collected by physical overlap.
	for pos in [Vector2(1450,538),Vector2(3420,373),Vector2(4380,413)]:
		await go(pos)
	check(game.player.power_cells==3,"Tres celulas obrigatorias acessiveis")
	# Doors tested through the same interaction selection as normal gameplay.
	await go(Vector2(2110,660))
	await press("interact")
	check(game.first_door.is_open,"Porta B01 responde a E apos registro")
	await go(Vector2(4710,660))
	await press("interact")
	check(game.reactor_gate.is_open,"Comporta responde a E com tres celulas")
	# Player contact no longer forces a cutscene, explicit action still works.
	await go(Vector2(2500,660))
	var memory: Node = null
	for c in game.get_children():
		if c.get_script()==load("res://scripts/memory_trigger.gd") and c.position.x==2500: memory=c
	check(not paused and not memory.consumed,"Encostar na lembranca nao interrompe a exploracao")
	await press("interact")
	check(paused and memory.consumed,"E inicia a lembranca por escolha do jogador")
	await close_reader()
	for x in [5150,6280,7870]:
		await go(Vector2(x,660))
		await press("interact")
		check(game.hud.story_cutscene_overlay.visible,"Lembranca acessivel em %d"%x)
		await close_reader()
	# Personal objects, journal and rereading.
	for pos in [Vector2(320,660),Vector2(3560,660),Vector2(7390,513)]:
		await go(pos)
		await press("interact")
		check(game.hud.document_panel.visible,"Objeto narrativo examinavel em %d"%pos.x)
		await close_reader()
	check(session.marked("story","photo") and session.marked("story","recorder") and session.marked("story","drawing"),"Tres objetos pessoais registrados")
	game.menus.open_menu(true)
	check(game.menus.journal_text.get_parsed_text().contains("3 / 3") and game.menus.journal_text.get_parsed_text().contains("DESENHO DE ELISA"),"Diario apresenta objetos e conteudo")
	game.menus.close_menu()
	await ticks(20)
	# Each checkpoint returns outside geometry and retains inventory.
	for x in [2390,5080,6480,8100]:
		await go(Vector2(x,660))
		await press("interact")
		check(absf(game.player.spawn_position.x-(x+70))<1,"Posto interativo %d salva retorno previsto"%x)
		await go(game.player.spawn_position)
		check(game.player.is_on_floor() and absf(game.player.position.y-660)<2,"Retorno do posto %d tem piso e espaco"%x)
	# Interaction cannot cross a solid wall.
	await go(Vector2(150,660))
	var object: Node = game._story_object(Vector2(235,660),"blocked","photo","Teste","Teste","")
	game._add_static_rect(Vector2(195,620),Vector2(4,80),Color.TRANSPARENT)
	var wall: Node = game.get_child(game.get_child_count()-1)
	await ticks(3)
	game.player._update_interaction()
	check(game.player.current_interactable!=object,"Interacao nao atravessa parede")
	# Muzzle segment must stop at a wall even when spawn position would be beyond it.
	game._spawn_enemy(Vector2(245,660),"crawler")
	var target: Node = get_nodes_in_group("enemies").back()
	target.set_physics_process(false)
	wall.position.x = 184
	await ticks(3)
	game.player.facing = 1
	game.player.syringe_ammo = 3
	game.player.syringe_reload_remaining = 0
	game.player.syringe_shot_cooldown = 0
	game.player.fire_syringe()
	await ticks(15)
	check(target.health==70,"Boca da arma nao nasce depois da parede")
	wall.position.x=205
	await ticks(3)
	var projectile := Area2D.new()
	projectile.set_script(load("res://scripts/syringe_projectile.gd"))
	game.add_child(projectile)
	projectile.position=Vector2(150,616)
	projectile.set_physics_process(false)
	projectile._physics_process(0.20)
	check(projectile.already_hit and projectile.position.x<210,"Varredura do tiro detecta parede fina mesmo em passo longo")
	wall.queue_free()
	object.queue_free()
	# Final sequence: boss -> console -> save/reload -> elevator -> final pages.
	await go(Vector2(8450,660))
	game.boss_node.take_damage(999,1)
	await ticks(3)
	check(game.boss_defeated and session.checkpoint_data.flags.get("boss_defeated",false),"Vitoria salva estado sem exigir novo combate")
	game._on_exit_entered(game.player)
	check(not game.hud.end_overlay.visible and not game.final_gate.is_open,"Final bloqueado antes do encerramento do protocolo")
	await go(Vector2(9440,660))
	await press("interact")
	check(game.protocol_closed and game.final_gate.is_open,"Terminal de encerramento acessivel com E")
	session.retry_checkpoint()
	await ticks(8)
	game=current_scene
	check(game.boss_defeated and game.protocol_closed and game.final_gate.is_open,"Continuacao preserva vitoria e protocolo encerrado")
	check(game.protocol_console.inspected and session.marked("story","drawing"),"Retorno preserva objetos e terminal")
	await go(Vector2(9910,660))
	check(not game.hud.end_overlay.visible,"Entrar no elevador nao dispara final automaticamente")
	await press("interact")
	check(game.hud.end_overlay.visible and paused,"E no elevador inicia encerramento")
	check(game.hud.ending_pages[2].contains("fotografia") and game.hud.ending_pages[2].contains("desenho"),"Epilogo reconhece objetos encontrados")
	for i in range(4):
		await ticks(45)
		await press("interact")
	check(game.hud.ending_finished,"Todas as paginas do final podem ser avancadas")
	# Bad numeric save fields cannot reach gameplay. Preserve the original save bytes.
	var save_path: String = session.SAVE_PATH
	var original := FileAccess.get_file_as_string(save_path)
	var bad: Dictionary = JSON.parse_string(original)
	bad.checkpoint.cells = "broken"
	var f := FileAccess.open(save_path,FileAccess.WRITE)
	f.store_string(JSON.stringify(bad)); f.close()
	check(not session.has_save(),"Save com celulas invalidas e rejeitado sem crash")
	f=FileAccess.open(save_path,FileAccess.WRITE)
	f.store_string(original); f.close()
	# Confirmed new game also resets disk, not only the running scene.
	game.hud.end_overlay.hide()
	game.hud.intro_overlay.show()
	game.hud.intro_input_lock = 0
	await press("interact")
	await ticks(8)
	check(session._read_save().checkpoint.cells==0 and session.journal.is_empty(),"Nova partida pela tela inicial reinicia salvamento e diario")
	print("ACCEPTANCE: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
