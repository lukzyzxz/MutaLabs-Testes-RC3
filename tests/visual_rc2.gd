extends SceneTree
var game: Node
func _initialize() -> void: call_deferred("run")
func ticks(n: int) -> void:
	for i in range(n): await process_frame
func capture(filename: String) -> void:
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	image.save_png("res://previews_rc2/"+filename+".png")
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
	game.campaign.set_physics_process(false)
	game.menus.set_process_unhandled_input(false)
	for e in get_nodes_in_group("enemies"): e.set_physics_process(false)
	game.player.invulnerability=999
	session.flashes_enabled=false
	game.player.position=Vector2(2000,660)
	game.player.velocity=Vector2.ZERO
	await ticks(230)
	await capture("01_porta_fechada")
	game.campaign.tracker.hide()
	game.hud.show_sector_story(preload("res://scripts/campaign_data.gd").SCENES[0],preload("res://scripts/campaign_data.gd").IMAGES[0])
	await ticks(55)
	await capture("02_cutscene")
	game.hud.story_cutscene_overlay.hide()
	game.campaign.tracker.show()
	paused=false
	for i in range(4):
		var c: Node=game.campaign
		c.current_sector=i
		c.in_dungeon=true
		c.phase="dungeon"
		c._build_dungeon()
		c._teleport(Vector2(12550,660),preload("res://scripts/campaign_data.gd").ANNEXES[i])
		game.player.invulnerability=999
		c._configure_room()
		c._update_tracker()
		var mini: Node=c.miniboss
		mini.position=Vector2(800,660)
		mini.set_physics_process(false)
		mini.state="windup"
		mini.attack_kind=["sweep","roots","surge","charge"][i]
		mini.target_x=12700
		mini.facing=-1
		mini.timer=0.65
		mini.sprite.play("attack")
		mini.sprite.flip_h=true
		mini.queue_redraw()
		await ticks(100)
		await capture("0%d_anexo_%d"%[i+3,i])
		c.dungeon.queue_free()
		await ticks(3)
	quit()
