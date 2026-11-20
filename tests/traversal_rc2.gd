extends SceneTree
var game: Node
var failures := 0
var checks := 0
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	print(("PASS " if ok else "FAIL ")+label)
	if not ok: failures += 1
func ticks(n: int) -> void:
	for i in range(n):
		await physics_frame
		await process_frame
func run() -> void:
	var session := root.get_node("Session")
	session.run_data.clear()
	session.checkpoint_data.clear()
	session.sound_volume = 0
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	game.hud.intro_overlay.hide()
	paused = false
	for c in game.get_children():
		if c is Area2D or c.get_script() == load("res://scripts/checkpoint.gd"):
			c.queue_free()
	for e in get_nodes_in_group("enemies"): e.set_physics_process(false)
	game.first_door.force_open()
	game.reactor_gate.force_open()
	await ticks(3)
	game.campaign.set_physics_process(false)
	for e in get_nodes_in_group("enemies"): e.set_physics_process(false)
	var p: Node = game.player
	p.invulnerability = 1000
	# Uma cápsula de 70px não cabia sob esta plataforma e sobre a divisória.
	for direction in [1,-1]:
		p.position = Vector2(7860 if direction == 1 else 8060, 660)
		p.velocity = Vector2.ZERO
		await ticks(4)
		var action := "move_right" if direction == 1 else "move_left"
		Input.action_press(action)
		Input.action_press("jump")
		await ticks(52)
		Input.action_release("jump")
		Input.action_release(action)
		check(p.position.x > 7990 if direction == 1 else p.position.x < 7910, "Divisoria 7940 atravessavel sentido %d" % direction)
	# Saltos entre as passarelas que levam a itens obrigatórios.
	var routes := [[600,565,230,990,455,250],[3030,500,250,3420,385,235],[4160,455,180,4380,425,240]]
	for r in routes:
		for direction in [1,-1]:
			var sx: float = r[0] if direction==1 else r[3]
			var sy: float = r[1] if direction==1 else r[4]
			var sw: float = r[2] if direction==1 else r[5]
			var tx: float = r[3] if direction==1 else r[0]
			var ty: float = r[4] if direction==1 else r[1]
			var tw: float = r[5] if direction==1 else r[2]
			p.position = Vector2(sx+direction*(sw/2-22), sy-12)
			p.velocity = Vector2.ZERO
			await ticks(3)
			p.velocity.x = direction*285
			var action := "move_right" if direction==1 else "move_left"
			Input.action_press(action)
			Input.action_press("jump")
			var landed := false
			for i in range(65):
				await ticks(1)
				if (p.position.x-tx)*direction > -28:
					Input.action_release(action)
				if p.is_on_floor() and absf(p.position.y-(ty-12))<3 and absf(p.position.x-tx)<tw/2+16:
					landed = true
					break
			Input.action_release(action)
			Input.action_release("jump")
			check(landed,"Salto %d -> %d" % [sx,tx])
	# Passagem pela parte inferior de cada plataforma móvel em ambos os sentidos.
	for platform in get_nodes_in_group("traversal_platforms"):
		if not platform is AnimatableBody2D: continue
		for direction in [1,-1]:
			var cx: float = platform.position.x
			p.position = Vector2(cx-direction*145,660)
			p.velocity = Vector2.ZERO
			await ticks(3)
			var action := "move_right" if direction==1 else "move_left"
			Input.action_press(action)
			await ticks(66)
			Input.action_release(action)
			check((p.position.x-cx)*direction>120,"Passagem sob movel %d sentido %d" % [cx,direction])
	# Pular por baixo não bate a cabeça; o jogador pousa na face superior.
	p.position = Vector2(600,660)
	p.velocity = Vector2.ZERO
	await ticks(3)
	Input.action_press("jump")
	await ticks(50)
	Input.action_release("jump")
	check(p.is_on_floor() and absf(p.position.y-553)<3,"Subida por baixo e pouso na passarela")
	for platform in get_nodes_in_group("traversal_platforms"):
		if not platform is AnimatableBody2D: continue
		p.position = platform.position + Vector2(0,-12)
		p.velocity = Vector2.ZERO
		await ticks(120)
		# Sobreposições com outras passarelas podem mudar o apoio; não devem prender.
		Input.action_press("jump")
		await ticks(10)
		Input.action_release("jump")
		check(p.velocity.y < -100,"Salto apos transporte na plataforma movel %d" % platform.position.x)
	print("TRAVERSAL: %d checks / %d failures" % [checks,failures])
	quit(1 if failures else 0)
