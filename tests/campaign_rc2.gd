extends SceneTree
const Data = preload("res://scripts/campaign_data.gd")
var game: Node
var session: Node
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks += 1
	print(("PASS " if ok else "FAIL ")+label)
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
	game.player.position=pos
	game.player.velocity=Vector2.ZERO
	game.player.dash_time=0
	game.player.hurt_lock=0
	game.player.interaction_lock=0
	game.player.invulnerability=999
	await ticks(6)
func close_reader() -> void:
	await ticks(45)
	if game.hud.story_cutscene_overlay.visible: await press("interact")
	await ticks(25)
	if game.hud.document_panel.visible: await press("interact")
	await ticks(20)
func reload_post() -> void:
	session.retry_checkpoint()
	await ticks(12)
	game=current_scene
	game.player.invulnerability=999

func run() -> void:
	session=root.get_node("Session")
	session.run_data.clear()
	session.checkpoint_data.clear()
	session.seen.clear()
	session.journal.clear()
	session.sound_volume=0
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene=game
	game.hud.intro_overlay.hide()
	paused=false
	await ticks(8)
	for sector in range(4):
		var campaign: Node = game.campaign
		check(campaign.current_sector==sector and not campaign.in_dungeon,"Setor %d iniciado em ordem"%sector)
		var isolated := true
		for e in get_nodes_in_group("enemies"):
			if e==game.boss_node:
				isolated=isolated and not e.visible and not e.is_physics_processing()
			else:
				var same: bool = Data.sector_at(e.home_position.x)==sector
				isolated=isolated and e.visible==same and e.is_physics_processing()==same
			e.set_physics_process(false)
		check(isolated,"Monstros restritos ao setor %d"%sector)
		campaign.set_physics_process(false)
		# Porta sólida mesmo com dash + salto: não há fresta de física nem de câmera.
		await go(Vector2(Data.BOUNDS[sector].y-95,660))
		Input.action_press("move_right")
		await press("dash")
		await ticks(35)
		Input.action_release("move_right")
		check(game.player.position.x<Data.BOUNDS[sector].y-45,"Porta bloqueia o dash no setor %d"%sector)
		check(campaign.mask.bounds==Data.BOUNDS[sector] and game.player.game_camera.limit_right==int(Data.BOUNDS[sector].y),"Câmera e máscara escondem próximo setor %d"%sector)
		# Itens físicos; medkits com vida cheia precisam sair do mapa e virar reserva.
		game.player.health=100
		var pickups: Array = []
		for c in game.get_children():
			if c.get_script()==load("res://scripts/pickup.gd") and c.persistent_id in Data.REQUIRED[sector].pickups: pickups.append(c)
		for c in pickups:
			var id: String=c.persistent_id
			await go(c.position+Vector2(0,35))
			check(session.marked("pickups",id),"Coleta física "+id)
		# Documentos e objetos pessoais pelo mesmo E usado no jogo.
		for c in game.get_children():
			if c.get_script()==load("res://scripts/document.gd") and c.persistent_id in Data.REQUIRED[sector].documents:
				await go(c.position+Vector2(0,33))
				await press("interact")
				check(game.hud.story_cutscene_overlay.visible,"Documento acessível setor %d"%sector)
				await close_reader()
		for c in game.get_children():
			if c.get_script()==load("res://scripts/story_object.gd") and c.story_id in Data.REQUIRED[sector].story:
				var id: String=c.story_id
				await go(c.position)
				await press("interact")
				check(session.marked("story",id),"Objeto pessoal acessível "+id)
				await close_reader()
		for c in game.get_children():
			if c.get_script()==load("res://scripts/memory_trigger.gd") and c.memory_title in Data.REQUIRED[sector].memories:
				var title: String=c.memory_title
				await go(c.position)
				await press("interact")
				check(session.marked("memories",title),"Memória persistente "+title)
				await close_reader()
		check(not Data.complete(session.run_data,sector),"Itens sem abates não liberam setor %d"%sector)
		for e in get_nodes_in_group("enemies"):
			if e!=game.boss_node and e.persistent_id in Data.REQUIRED[sector].defeated: e.take_damage(999,1)
		await ticks(2)
		await go(Vector2(Data.BOUNDS[sector].y-120,660))
		campaign.set_physics_process(true)
		await ticks(25)
		check(Data.complete(session.run_data,sector) and paused and game.hud.story_cutscene_mode=="sector","Tudo coletado + abates inicia cutscene %d"%sector)
		await ticks(45)
		await press("interact")
		check(paused and game.hud.sector_page==1,"Cutscene %d conserva segunda página"%sector)
		await ticks(45)
		await press("interact")
		await ticks(65)
		check(campaign.in_dungeon and campaign.phase=="dungeon" and game.player.position.x>12000,"Cutscene leva ao anexo %d"%sector)
		check(not game.arena_started,"Anexo %d não ativa Alfa por coordenada"%sector)
		check(session.has_save() and session.checkpoint_data.get("in_dungeon",false),"Anexo %d salva ponto de retorno válido"%sector)
		await campaign.exit_dungeon()
		check(campaign.in_dungeon,"Saída permanece trancada com miniboss %d vivo"%sector)
		# Morte real, restauração do anexo e preservação de todas as coletas.
		game.player.invulnerability=0
		game.player.shield_charges=0
		game.player.take_damage(999,0)
		check(game.hud.death_overlay.visible,"Morte exibe retorno no anexo %d"%sector)
		await reload_post()
		campaign=game.campaign
		check(campaign.in_dungeon and game.player.can_control and Data.complete(session.run_data,sector) and campaign.miniboss.health==campaign.miniboss.max_health,"Retorno restaura luta e coletas %d"%sector)
		await ticks(130)
		var mini: Node=campaign.miniboss
		mini.set_physics_process(false)
		# A mesma colisão é usada por soco e seringa; impacto só no frame correto.
		await go(Vector2(mini.global_position.x-78,660))
		game.player.facing=1
		mini.state="recover"
		var hp: int=mini.health
		game.player.attack()
		check(mini.health==hp,"Miniboss %d não recebe soco antes do impacto"%sector)
		await ticks(16)
		check(mini.health==hp-35,"Soco causa um impacto no miniboss %d"%sector)
		await ticks(18)
		await go(Vector2(mini.global_position.x-220,660))
		game.player.facing=1
		game.player.syringe_ammo=3
		game.player.syringe_reload_remaining=0
		game.player.fire_syringe()
		await ticks(24)
		check(mini.health==hp-77,"Seringa colide com miniboss %d"%sector)
		mini.take_damage(999,1)
		await ticks(3)
		check(campaign.mini_cleared() and session.has_save(),"Vitória %d persistida e saída liberada"%sector)
		if sector==2:
			await reload_post()
			campaign=game.campaign
			check(campaign.mini_cleared() and get_nodes_in_group("minibosses").is_empty(),"Retorno após vitória não ressuscita miniboss")
		await go(Vector2(13320,660))
		await press("interact")
		await ticks(65)
		check(not campaign.in_dungeon and campaign.current_sector==sector+1,"E na saída avança para setor %d"%(sector+1))
		check(session.has_save(),"Salvamento após transição %d válido"%sector)
	# Reservas não se perdem ao apertar F com vida cheia.
	var p: Node=game.player
	var kits: int=p.medkit_charges
	await press("medkit")
	check(p.medkit_charges==kits and kits>0,"F conserva reserva com vida cheia")
	p.health=50
	await press("medkit")
	check(p.medkit_charges==kits-1 and p.health==85,"F consome um kit e cura 35")
	# Alfa e encerramento continuam independentes dos quatro minibosses.
	await go(Vector2(8450,660))
	await ticks(4)
	check(game.arena_started and game.boss_node.active,"Alfa só ativa na Câmara Zero")
	check(session.has_save() and session.checkpoint_data.spawn[0]>8240,"Checkpoint do Alfa fica do lado correto da porta")
	game.boss_node.set_physics_process(false)
	game.boss_node.take_damage(999,1)
	await ticks(3)
	check(game.boss_defeated and not game.final_gate.is_open,"Alfa derrotado ainda exige terminal")
	await go(Vector2(9430,660))
	await press("interact")
	await close_reader()
	check(game.protocol_closed and game.final_gate.is_open,"Terminal encerra protocolo e libera elevador")
	await go(Vector2(9900,660))
	await press("interact")
	check(game.hud.end_overlay.visible and paused,"Elevador conclui campanha")
	print("RESULT: %d verificações, %d falhas"%[checks,failures])
	quit(1 if failures else 0)
