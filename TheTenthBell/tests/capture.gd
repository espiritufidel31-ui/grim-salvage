extends SceneTree
const Station=preload("res://game/station.gd")
var game
var failed=false
func _initialize():call_deferred("capture")
func snap(name):
	await process_frame;await process_frame;await RenderingServer.frame_post_draw
	var path=OS.get_environment("BELL_CAPTURE_DIR")
	if path=="":path=ProjectSettings.globalize_path("res://../build")
	DirAccess.make_dir_recursive_absolute(path)
	get_root().get_texture().get_image().save_png(path+"/"+name+".png")
func tap(p):
	for down in [true,false]:
		var event=InputEventScreenTouch.new();event.index=0;event.position=p+game.off;event.pressed=down;game._unhandled_input(event)
func check(ok,msg):
	if not ok:failed=true;push_error(msg)
func capture():
	root.size=Vector2i(360,640);game=Station.new();game.sandbox_test=true;root.add_child(game)
	await create_timer(.25).timeout;await snap("01-selection")
	tap(Vector2(262,374));await process_frame;check(game.selection==12,"School tab did not select Mina")
	await snap("02-mina");tap(Vector2(220,602));await create_timer(.2).timeout
	check(game.run!=null and game.run.lead==12,"Touch start did not start Mina")
	game.set_process(false)
	for i in 250:game.run.tick(1.0/45)
	while game.run.living().is_empty():game.run.tick(1.0/45)
	game.queue_redraw();await snap("03-combat")
	tap(Vector2(90,578));check(game.run.actors[0].skillcd>0,"Skill touch failed")
	game.queue_redraw();await process_frame;tap(Vector2(320,38));check(game.overlay=="pause","Pause touch failed")
	var before=game.run.clock;var shot_age=game.run.shots[0].age if not game.run.shots.is_empty() else -1.0
	game.set_process(true);await create_timer(.25).timeout
	check(game.run.clock==before,"Pause advanced simulated time")
	if shot_age>=0:check(game.run.shots[0].age==shot_age,"Pause advanced projectiles")
	await snap("04-pause");tap(Vector2(180,272));check(game.overlay=="","Resume touch failed")
	await create_timer(.15).timeout;check(game.run.clock>before,"Resume did not advance combat")
	game.set_process(false)
	while game.run.phase=="battle":game.run.tick(1.0/45);game.run.signature();game.run.ring()
	game.queue_redraw();await snap("05-upgrade")
	game.run.wave=10;game.run.phase="shop";game.run.picks=0;game.run.gold=160;game.run.meta.rescued=true;game.run.make_shop();game.save_now()
	game.queue_redraw();await snap("06-merchant")
	tap(Vector2(180,538));check(game.run.owned.size()==1,"Recruit touch failed");game.queue_redraw();await process_frame
	tap(Vector2(180,358));game.queue_redraw();await snap("07-crew")
	game.overlay="settings";game.queue_redraw();await snap("08-settings")
	game.overlay="";game.screen="select";root.size=Vector2i(360,800);game.queue_redraw();await snap("09-tall-phone")
	print("BELL SCREEN CHECK ",not failed)
	game.queue_free();await process_frame;quit(1 if failed else 0)
