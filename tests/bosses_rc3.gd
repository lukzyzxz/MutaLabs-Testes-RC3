extends SceneTree
var game: Node
var session: Node
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
func reset_player(pos: Vector2) -> void:
	game.player.global_position=pos
	game.player.velocity=Vector2.ZERO
	game.player.health=100
	game.player.invulnerability=0
	game.player.shield_charges=0
	game.player.can_control=true
func wait_state(actor: Node,key: String,target: String,maximum: int=300) -> bool:
	for i in range(maximum):
		if actor.get(key)==target: return true
		await ticks(1)
	return false
func run() -> void:
	session=root.get_node("Session")
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
	p.set_physics_process(false)
	for variant in range(4):
		var c: Node=game.campaign
		c.in_dungeon=true
		c.current_sector=variant
		c.phase="dungeon"
		c._build_dungeon()
		c._configure_room()
		var m: Node=c.miniboss
		m.global_position=Vector2(12800,660)
		reset_player(Vector2(12700,660))
		m._recover(0.2)
		check(m.max_health>[180,220,250,280][variant],"Vida ampliada no miniboss %d"%variant)
		m.take_damage(m.max_health/2,1)
		check(m.phase_pending and not m.phase_two,"Mudança de fase aguarda abertura %d"%variant)
		check(await wait_state(m,"state","enrage"),"Fase 2 inicia com aviso %d"%variant)
		var before: int=p.health
		await ticks(35)
		check(p.health==before and m.phase_two,"Transição de fase não causa dano instantâneo %d"%variant)
		check(await wait_state(m,"state","recover"),"Transição devolve abertura %d"%variant)
		m.global_position=Vector2(12800,660)
		reset_player(Vector2(12700,660))
		m.cycle=0
		m._prepare_attack()
		var locked_facing: float=m.facing
		await ticks(20)
		check(p.health==100 and m.state=="windup" and m.sprite.frame==0,"Antecipação sem quadro de impacto precoce %d"%variant)
		check(m.sprite.scale.y<m.base_scale.y,"Corpo prepara o golpe %d"%variant)
		await ticks(70)
		check(p.health<100,"Fase 2 causa dano real %d"%variant)
		if variant==3: check(m.charges<3,"Vigia progride dentro da investida tripla")
		# Preparação fixa lado e alvo mesmo se o jogador cruzar o inimigo.
		m.pulses.clear()
		m.global_position=Vector2(12800,660)
		reset_player(Vector2(12700,660))
		m._prepare_attack()
		var x: float=m.target_x
		locked_facing=m.facing
		p.global_position.x=12900
		await ticks(8)
		check(m.target_x==x and m.facing==locked_facing,"Ataque não persegue jogador durante aviso %d"%variant)
		if variant==1: check(m.attack_kind=="bloom" and m.targets.size()==3,"Raiz alterna para três espinhos na fase 2")
		if variant==2: check(m.targets.size()==3,"Condutor marca três áreas com intervalos")
		# Percorrer uma combinação completa e achar janela finita de recuperação.
		reset_player(Vector2(12150,500))
		check(await wait_state(m,"state","recover",300),"Combo termina e permite contra-ataque %d"%variant)
		check(m.timer>=0.90,"Janela de recuperação preservada %d"%variant)
		# Parar/pausar não deve avançar avisos, efeitos ou projéteis.
		m._prepare_attack()
		var held: float=m.timer
		paused=true
		await ticks(20)
		check(is_equal_approx(m.timer,held),"Pausa congela ataque de miniboss %d"%variant)
		paused=false
		c.dungeon.queue_free()
		await ticks(4)
		check(get_nodes_in_group("boss_fx").is_empty(),"Efeitos removidos junto com anexo %d"%variant)
	# Alfa: vida/barra, ativação, fases, ataques e zonas seguras.
	var c: Node=game.campaign
	c.in_dungeon=false
	c.current_sector=4
	c._configure_room()
	var b: Node=game.boss_node
	b.set_physics_process(false)
	reset_player(Vector2(8700,660))
	b.global_position=Vector2(8800,660)
	b.begin_battle()
	game.arena_started=true
	check(b.MAX_HEALTH==820 and game.hud.boss_fill.size.x==464,"Alfa começa com 820 e barra cheia")
	for stage in [2,3]:
		b.health=440 if stage==2 else 200
		b.take_damage(1,1)
		b._recover(0.01)
		b.set_physics_process(true)
		check(await wait_state(b,"state","enrage"),"Alfa anuncia fase %d"%stage)
		check(b.phase==stage and b.phase_two,"Alfa entra na fase %d"%stage)
		check(await wait_state(b,"state","recover"),"Alfa encerra transição de fase %d"%stage)
		b.set_physics_process(false)
	b.global_position=Vector2(8800,660)
	reset_player(Vector2(8700,660))
	b.combo_left=3
	b._prepare_claw(false)
	b.set_physics_process(true)
	await ticks(20)
	check(p.health==100 and b.state=="melee","Garras do Alfa avisam antes de acertar")
	check(b.visual_sprite.position.x!=0 and b.visual_sprite.scale.y<b.visual_base_scale.y,"Alfa recua e comprime antes da garra")
	check(await wait_state(b,"state","claw_strike"),"Garra tem estado de impacto próprio")
	check(p.health<100 and not get_nodes_in_group("boss_fx").is_empty(),"Dano e efeito da garra no mesmo impacto")
	reset_player(Vector2(8350,500))
	check(await wait_state(b,"state","recover",250),"Combo triplo do Alfa acaba em abertura")
	b.set_physics_process(false)
	# O anel da fase 3 protege o centro, mas pune ficar entre os dois raios.
	b.global_position=Vector2(8800,660)
	b.wave_origin=Vector2(8800,625)
	b.wave_inner=125
	reset_player(Vector2(8820,660))
	b._wave_impact()
	check(p.health==100,"Centro do eco é seguro")
	reset_player(Vector2(8980,660))
	b._wave_impact()
	check(p.health==78,"Anel do eco aplica dano na faixa anunciada")
	reset_player(Vector2(9140,660))
	b._wave_impact()
	check(p.health==100,"Exterior do eco é seguro")
	# Salto chega à marca fixa, produz onda apenas ao pousar e não prende no ar.
	b.ground_waves.clear()
	reset_player(Vector2(9160,660))
	b._prepare_leap()
	var landing_x: float=b.leap_target
	p.position.x=8350
	b.set_physics_process(true)
	check(await wait_state(b,"state","leap"),"Salto sai da preparação")
	check(b.ground_waves.is_empty(),"Salto não cria dano no chão antes de pousar")
	check(await wait_state(b,"state","recover",200),"Salto pousa e recupera")
	check(absf(b.position.x-landing_x)<18 and b.ground_waves.size()==2,"Pouso coincide com a marca e lança duas ondas")
	b.set_physics_process(false)
	# Rajada em leque e colisão varrida em um quadro lento.
	b.global_position=Vector2(8800,660)
	b.direction=-1
	b.volley_direction=Vector2.LEFT
	b.bullets.clear()
	b._release_volley()
	check(b.bullets.size()==5,"Fase 3 dispara cinco projéteis")
	b.bullets.clear()
	reset_player(Vector2(8700,660))
	b.bullets.append({"position":Vector2(8750,625),"velocity":Vector2(-1000,0),"life":1.0})
	b._update_hazards(0.1)
	check(p.health==76 and b.bullets.is_empty(),"Projétil não atravessa jogador em quadro lento")
	reset_player(Vector2(8700,660))
	p.invulnerability=0.2
	b.bullets.append({"position":Vector2(8750,625),"velocity":Vector2(-1000,0),"life":1.0})
	b._update_hazards(0.1)
	check(p.health==100,"Invulnerabilidade do dash protege da rajada")
	# A morte apaga perigos e a barra final, mantendo o terminal obrigatório.
	b.take_damage(9999,1)
	await ticks(4)
	check(game.boss_defeated and not game.final_gate.is_open and not game.hud.boss_panel.visible,"Vitória limpa o combate e mantém encerramento narrativo")
	print("RC3 BOSSES: %d verificações, %d falhas"%[checks,failures])
	quit(1 if failures else 0)
