extends SceneTree
var game: Node
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	print(("PASS " if ok else "FAIL ")+label)
	if not ok: failures+=1
func ticks(n: int) -> void:
	for i in range(n):
		await physics_frame
		await process_frame
func run() -> void:
	var session := root.get_node("Session")
	session.run_data={}
	session.checkpoint_data={}
	session.sound_volume=0
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene=game
	game.hud.intro_overlay.hide()
	paused=false
	await ticks(8)
	var c: Node=game.campaign
	c.set_physics_process(false)
	var p: Node=game.player
	p.set_physics_process(false)
	for variant in range(4):
		c.current_sector=variant
		c.in_dungeon=true
		c.phase="dungeon"
		c._build_dungeon()
		c._configure_room()
		var mini: Node=c.miniboss
		mini.global_position=Vector2(12800,660)
		p.position=Vector2(12700,660)
		p.health=100
		p.invulnerability=0
		mini._prepare_attack()
		await ticks(20)
		check(p.health==100 and mini.state=="windup","Aviso legível antes do dano: variante %d"%variant)
		await ticks(70)
		check(p.health<100,"Ataque aplica dano de verdade: variante %d"%variant)
		# Pulo alto fica fora das investidas, varreduras e raízes; descarga permite fuga lateral.
		mini.pulses.clear()
		mini.global_position=Vector2(12800,660)
		p.position=Vector2(12700,660)
		p.health=100
		p.invulnerability=0
		mini._prepare_attack()
		p.position=Vector2(12400,660) if variant==2 else Vector2(12700,500)
		await ticks(90)
		check(p.health==100,"Ataque evitável sem sofrer dano: variante %d"%variant)
		if variant==3:
			await ticks(50)
			check(mini.state=="recover","Investida dupla termina em recuperação")
		# Não há corpo sólido extra bloqueando o corredor; é possível atravessar correndo.
		check(mini.collision_mask==1 and mini.collision_layer==4,"Miniboss não prende fisicamente jogador %d"%variant)
		mini.global_position=Vector2(13490,660)
		await ticks(2)
		check(mini.global_position.x<=13340,"Miniboss permanece dentro do anexo %d"%variant)
		c.dungeon.queue_free()
		await ticks(4)
	print("MINIBOSS: %d verificações, %d falhas"%[checks,failures])
	quit(1 if failures else 0)
