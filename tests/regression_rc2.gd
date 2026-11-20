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
	game.campaign.set_physics_process(false)
	for enemy in get_nodes_in_group("enemies"): enemy.set_physics_process(false)
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
	check(not is_instance_valid(kit) and player.medkit_charges==1, "Kit coletado com vida cheia fica guardado")
	player.health = 70
	player.use_medkit()
	check(player.health == 100 and player.medkit_charges==0, "Reserva cura e consome apenas uma carga")
	player.global_position = Vector2(150, 660)
	player.velocity = Vector2.ZERO
	player.invulnerability = 0.15
	game._spawn_hazard(Vector2(150, 640), Vector2(1200, 40), "acid")
	var acid: Node = game.get_child(game.get_child_count() - 1)
	await frames(85)
	check(player.health <= 64, "Ácido continua causando dano após a invulnerabilidade inicial")
	acid.queue_free()
	player.invulnerability = 0.0
	player.can_control=false
	for post in game.get_children():
		if not is_instance_valid(post) or post.get_script()!=load("res://scripts/checkpoint.gd"): continue
		var sector: int=preload("res://scripts/campaign_data.gd").sector_at(post.position.x)
		session.run_data["sector"]=sector
		game.campaign.current_sector=sector
		post.interact(player)
		player.position=player.spawn_position
		player.velocity=Vector2.ZERO
		player.invulnerability=0
		await frames(100)
		check(player.health==100 and player.is_on_floor(),"Posto reaparece em chão seguro: "+post.checkpoint_name)
	player.can_control=true
	game.campaign.current_sector=0
	# Validação dos checkpoints inclui sala e tipo dos campos novos.
	player.set_checkpoint(Vector2(150,660),"Teste")
	session.run_data["sector"]=0
	session.run_data["in_dungeon"]=false
	check(session.save_checkpoint(player) and session.has_save(),"Salvamento inicial válido")
	var original := FileAccess.get_file_as_string(session.SAVE_PATH)
	for bad in [{"sector":9},{"in_dungeon":true},{"medkits":-1},{"memories":[]},{"spawn":[12080,660]}]:
		var data: Dictionary=JSON.parse_string(original)
		for key in bad: data.checkpoint[key]=bad[key]
		var file := FileAccess.open(session.SAVE_PATH,FileAccess.WRITE)
		file.store_string(JSON.stringify(data))
		file.close()
		check(not session.has_save(),"Rejeita save incompatível "+str(bad))
	var file := FileAccess.open(session.SAVE_PATH,FileAccess.WRITE)
	file.store_string(original)
	file.close()
	# Uma lembrança vista após o posto deve reaparecer no retorno.
	session.seen["LEMBRANCA // DIA 34"]=true
	session.run_data["memories"]={}
	var old_count := 0
	for c in game.get_children():
		if c.get_script()==load("res://scripts/memory_trigger.gd"): old_count+=1
	game._spawn_memory(Vector2(2500,660),"LEMBRANCA // DIA 34","Teste","res://assets/cutscenes/memory_day34.png")
	var new_count := 0
	for c in game.get_children():
		if c.get_script()==load("res://scripts/memory_trigger.gd"): new_count+=1
	check(new_count==old_count+1,"Memória reaparece se não estava salva, mesmo já lida")
	# Todos os slots de animação apontam para quadros completos selecionados.
	var rejected := ["scientist/jump_02","scientist/attack_02","scientist/attack_03","scientist/shoot_02","scientist/shoot_03","scientist/walk_00","mutant/jump_01","mutant/jump_05","mutant/run_04","mutant/run_05","mutant/fall_02","mutant/fall_04"]
	var mutant := CharacterBody2D.new()
	mutant.set_script(load("res://scripts/enemy.gd"))
	for resource in [player._build_player_frames(),mutant._build_mutant_frames()]:
		for animation in resource.get_animation_names():
			var clean := true
			for i in range(resource.get_frame_count(animation)):
				var path: String=resource.get_frame_texture(animation,i).resource_path
				for fragment in rejected:
					if path.contains(fragment): clean=false
			check(clean,"Sequência sem quadros cortados: "+str(animation))
	mutant.free()
	print("REGRESSION: %d verificações, %d falhas" % [checks, failures])
	quit(1 if failures > 0 else 0)
