extends SceneTree
var game: Node
var frame_id:=0
var folder: String
func _initialize() -> void: call_deferred("run")
func ticks(n: int) -> void:
	for i in range(n):
		await physics_frame
		await process_frame
func capture() -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(folder+"/%04d.png"%frame_id)
	frame_id+=1
func run() -> void:
	folder=OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size()>0 else "user://rc3_frames"
	DirAccess.make_dir_recursive_absolute(folder)
	var session:=root.get_node("Session")
	session.run_data={}
	session.checkpoint_data={}
	session.sound_volume=0
	session.flashes_enabled=false
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene=game
	game.hud.intro_overlay.hide()
	paused=false
	await ticks(8)
	game.campaign.set_physics_process(false)
	var p: Node=game.player
	p.set_physics_process(false)
	p.invulnerability=999
	var label:=Label.new()
	label.position=Vector2(350,355)
	label.size=Vector2(580,25)
	label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size",16)
	label.text="RC3 • DEMONSTRAÇÃO DAS ANIMAÇÕES"
	game.hud.add_child(label)
	for variant in range(4):
		var c: Node=game.campaign
		c.current_sector=variant
		c.in_dungeon=true
		c.phase="dungeon"
		c._build_dungeon()
		c._configure_room()
		p.global_position=Vector2(12650,660)
		p.facing=1
		p._update_camera(1)
		p.game_camera.reset_smoothing()
		var m: Node=c.miniboss
		m.global_position=Vector2(12800,660)
		m.phase_two=true
		m.health=m.max_health/2
		m._recover(0.5)
		m.health_changed.emit(m.health,m.max_health)
		c._update_tracker()
		game.hud.update_checkpoint(preload("res://scripts/campaign_data.gd").ANNEXES[variant])
		await ticks(10)
		m._prepare_attack()
		for i in range(60):
			await ticks(3)
			await capture()
			if (variant==0 and i==15) or (variant==2 and i==18):
				root.get_texture().get_image().save_png("res://previews_rc3/mini_%d.png"%variant)
		c.dungeon.queue_free()
		await ticks(4)
	var c: Node=game.campaign
	c.in_dungeon=false
	c.current_sector=4
	c.phase="explore"
	c._configure_room()
	c._update_tracker()
	var b: Node=game.boss_node
	b.global_position=Vector2(8900,660)
	p.position=Vector2(8770,660)
	p._update_camera(1)
	p.game_camera.reset_smoothing()
	b.begin_battle()
	game.arena_started=true
	b.phase=3
	b.phase_two=true
	b.pending_phase=3
	b.health=200
	b.health_changed.emit(b.health,b.MAX_HEALTH)
	b.combo_left=3
	b._prepare_claw(false)
	for i in range(60):
		await ticks(3)
		await capture()
		if i==12: root.get_texture().get_image().save_png("res://previews_rc3/alfa_garras.png")
	b.global_position=Vector2(8900,660)
	p.position=Vector2(8720,660)
	b.wave_origin=Vector2(8900,625)
	b.wave_inner=0
	b._set_state("wave",0.95)
	for i in range(60):
		await ticks(3)
		await capture()
		if i==30: root.get_texture().get_image().save_png("res://previews_rc3/alfa_eco.png")
	print("VISUAL RC3: %d frames"%frame_id)
	quit()
