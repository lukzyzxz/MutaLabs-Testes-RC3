extends SceneTree
var game: Node
var checks:=0
var failures:=0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	print(("PASS " if ok else "FAIL ")+label)
	if not ok: failures+=1
func ticks(n: int) -> void:
	for i in range(n):
		await physics_frame
		await process_frame
func setup_player(pos: Vector2) -> void:
	var p: Node=game.player
	p.global_position=pos
	p.velocity=Vector2.ZERO
	p.health=100
	p.hurt_lock=0
	p.invulnerability=0
	p.shield_charges=0
	p.dash_cooldown=0
	p.dash_time=0
	p.can_control=true
	await ticks(5)
func run() -> void:
	var session:=root.get_node("Session")
	session.run_data={}
	session.checkpoint_data={}
	session.sound_volume=0
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene=game
	game.hud.intro_overlay.hide()
	paused=false
	await ticks(8)
	game.campaign.set_physics_process(false)
	var p: Node=game.player
	for variant in [0,1,2,3]:
		var c: Node=game.campaign
		c.current_sector=variant
		c.in_dungeon=true
		c._build_dungeon()
		c._configure_room()
		var m: Node=c.miniboss
		m.set_physics_process(false)
		m.global_position=Vector2(12800,660)
		await setup_player(Vector2(12570 if variant==1 else 12660,660))
		m.phase_two=variant in [1,2,3]
		m.cycle=0
		m._prepare_attack()
		m.set_physics_process(true)
		if variant==0:
			Input.action_press("move_left")
			await ticks(68)
			Input.action_release("move_left")
			check(p.health==100 and p.position.x<12500,"Garra pode ser evitada correndo após aviso")
		elif variant==1:
			# Duas ondas: saltos reais, sem alterar posição no meio do ataque.
			await ticks(62)
			Input.action_press("jump")
			await ticks(38)
			Input.action_release("jump")
			await ticks(25)
			Input.action_press("jump")
			await ticks(40)
			Input.action_release("jump")
			check(p.health==100,"Ondas duplas permitem dois saltos reais")
		elif variant==2:
			Input.action_press("move_left")
			await ticks(21)
			Input.action_release("move_left")
			await ticks(49)
			check(p.health==100,"Há espaço para correr entre descargas marcadas")
		else:
			# Segurar salto sobre a primeira investida; o aviso seguinte é novo.
			await ticks(23)
			Input.action_press("jump")
			await ticks(37)
			Input.action_release("jump")
			check(p.health==100,"Primeira investida é evitável com pulo normal")
			check(m.state in ["charge","windup"],"Vigia sinaliza continuação da sequência")
		c.dungeon.queue_free()
		await ticks(4)
	# Alfa: esquiva andando para fora da marca do salto com física real.
	game.campaign.in_dungeon=false
	game.campaign.current_sector=4
	game.campaign._configure_room()
	var boss: Node=game.boss_node
	boss.set_physics_process(false)
	boss.global_position=Vector2(8800,660)
	await setup_player(Vector2(9100,660))
	game.arena_started=true
	boss.begin_battle()
	boss.phase=1
	boss._prepare_leap()
	boss.set_physics_process(true)
	Input.action_press("move_left")
	await ticks(95)
	Input.action_release("move_left")
	check(p.health==100 and boss.state=="recover","Salto do Alfa permite sair da marca usando movimento")
	boss.set_physics_process(false)
	boss.global_position=Vector2(8800,660)
	await setup_player(Vector2(8700,660))
	boss.phase=3
	boss.wave_origin=Vector2(8800,625)
	boss.wave_inner=0
	boss._set_state("wave",0.95)
	boss.set_physics_process(true)
	Input.action_press("move_left")
	await ticks(120)
	Input.action_release("move_left")
	check(p.health==100,"Onda e eco permitem fugir andando sem dash")
	print("DODGE RC3: %d verificações, %d falhas"%[checks,failures])
	quit(1 if failures else 0)
