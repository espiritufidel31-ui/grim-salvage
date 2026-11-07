extends "res://game/painter.gd"
const Run=preload("res://game/run.gd")
const Vault=preload("res://game/vault.gd")
var sandbox_test=false
var profile=Run.default_meta()
var settings={"sound":true,"music":true,"reduced":false,"haptic":true}
var disk_run={}
var run
var screen="select"
var overlay=""
var selection=0
var first_charm=0
var detail=false
var preview_left=0.0
var time=0.0
var accumulator=0.0
var input_delay=0.0
var pressed=Vector2(-999,-999)
var evolve=false
var market_tab=0
var offer_index=0
var crew_index=0
var gear_weapon=true
var visit_key=""
var voices=[]
var voice_index=0
var sounds={}
var music
var save_failed=false
func _ready():
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	prepare_art()
	if not sandbox_test:
		var saved=Vault.load_game()
		if not saved.is_empty():
			profile=saved.get("profile",profile);disk_run=saved.get("run",{})
			settings.merge(saved.get("settings",{}),true)
		setup_sound()
	print("TenthBell: station ready")
func setup_sound():
	for cue_name in ["tap","hit","kill","hurt","start","skill","warn","gain","clear","bell","perfect","boss"]:sounds[cue_name]=load("res://art/audio/"+cue_name+".wav")
	for i in 6:
		var player=AudioStreamPlayer.new();add_child(player);voices.append(player)
	music=AudioStreamPlayer.new();music.stream=load("res://art/audio/music.wav");music.volume_db=-22;add_child(music)
	music.finished.connect(func():
		if settings.music and overlay!="pause":music.play())
	if settings.music:music.play()
func play_cue(kind):
	if sandbox_test:return
	if settings.haptic and OS.has_feature("android") and kind in ["hurt","bell","perfect"]:Input.vibrate_handheld(24 if kind!="perfect" else 42)
	if not settings.sound or not sounds.has(kind):return
	var player=voices[voice_index%voices.size()];voice_index+=1
	player.stream=sounds[kind];player.volume_db=-22 if kind=="hit" else (-18 if kind=="kill" else -9);player.play()
func _process(dt):
	time+=dt;input_delay=maxf(0,input_delay-dt);preview_left=maxf(0,preview_left-dt)
	first_charm=mini(first_charm,mini(3,int(best_wave()/10.0)))
	if screen=="play" and run!=null and run.phase=="battle" and overlay=="":
		accumulator+=minf(dt,0.1)
		while accumulator>=1.0/45.0:
			accumulator-=1.0/45.0;run.tick(1.0/45.0)
	else:accumulator=0
	queue_redraw()
func connect_run():
	run.checkpoint_changed.connect(save_now);run.cue.connect(play_cue)
func start_new():
	if run!=null:run.dispose()
	run=Run.new();connect_run();screen="play";overlay="";evolve=false;input_delay=.06
	if music!=null:music.stream_paused=false
	run.new_run(selection,profile,first_charm);print("TenthBell: start hero=",selection," wave=1")
func continue_saved():
	if disk_run.is_empty():return
	if run!=null:run.dispose()
	run=Run.new();connect_run();screen="play";overlay="";evolve=false
	if music!=null:music.stream_paused=false
	run.restore(disk_run.duplicate(true),profile);print("TenthBell: continued wave=",run.wave)
func save_now():
	if run!=null:
		var key=str(run.wave)+"/"+run.phase
		if key!=visit_key:visit_key=key;offer_index=0;crew_index=0;market_tab=0;evolve=false
		disk_run={} if run.phase=="dead" else run.checkpoint()
	if not sandbox_test:save_failed=not Vault.write_game(profile,settings,disk_run)
func pause_game():
	if screen=="play" and overlay=="":overlay="pause";save_now();print("TenthBell: paused")
	if music!=null:music.stream_paused=true
func resume_game():
	overlay="";accumulator=0
	if music!=null:music.stream_paused=false
	print("TenthBell: resumed")
func _notification(what):
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT,NOTIFICATION_APPLICATION_PAUSED]:
		if is_node_ready():pause_game();save_now()
	if what==NOTIFICATION_WM_GO_BACK_REQUEST:
		if overlay=="pause":resume_game()
		elif overlay!="":overlay="pause" if screen=="play" else ""
		else:pause_game()
func _exit_tree():
	if run!=null:run.dispose()
	if music!=null:music.stop()
	for v in voices:v.stop()
func _unhandled_input(event):
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_ESCAPE,KEY_P]:
			if overlay=="pause":resume_game()
			elif overlay!="":overlay="pause" if screen=="play" else ""
			else:pause_game()
		elif overlay=="" and event.keycode==KEY_SPACE:act("start" if screen=="select" else "bell")
		elif overlay=="" and event.keycode==KEY_S:act("skill")
		return
	var p=Vector2.ZERO;var down=false;var valid=false
	if event is InputEventScreenTouch and event.index==0:p=event.position-off;down=event.pressed;valid=true
	elif event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:p=event.position-off;down=event.pressed;valid=true
	if not valid or input_delay>0:return
	if down:pressed=p;return
	var delta=p-pressed
	if screen=="select" and overlay=="" and pressed.y<350 and absf(delta.x)>40:act("prev" if delta.x>0 else "next");return
	if delta.length()>25:return
	for i in range(boundaries.size()-1,-1,-1):
		if boundaries[i][0].has_point(p):act(boundaries[i][1]);return
	if screen=="play" and overlay=="" and run.phase=="battle" and p.y<440:run.focus_on(p)
func act(command):
	play_cue("tap")
	if command.begins_with("group:"):selection=int(command.split(":")[1])*3;return
	if command.begins_with("upgrade:"):
		var choice=command.split(":")[1]
		if choice=="signature" and run.rank==2:evolve=true;return
		run.choose_upgrade(choice);evolve=false;return
	if command.begins_with("tab:"):market_tab=int(command.split(":")[1]);return
	match command:
		"prev":selection=posmod(selection-1,18)
		"next":selection=(selection+1)%18
		"detail":detail=not detail
		"preview":preview_left=.8
		"charm":first_charm=(first_charm+1)%(mini(3,int(best_wave()/10.0))+1)
		"start":
			if screen=="select":
				if not disk_run.is_empty():overlay="confirm"
				else:start_new()
		"new_confirm":start_new()
		"continue":continue_saved()
		"skill":
			if run!=null and overlay=="" and run.signature():print("TenthBell: signature used")
		"bell":
			if run!=null and overlay=="" and run.ring():print("TenthBell: bell used")
		"pause":pause_game()
		"resume":resume_game()
		"settings":overlay="settings"
		"help":overlay="help"
		"credits":overlay="credits"
		"back":overlay="pause" if screen=="play" else ""
		"home":screen="select";overlay="";save_now();selection=run.lead;resume_game()
		"again":screen="select";overlay="";selection=run.lead
		"nextwave":run.next_wave()
		"gear":overlay="gear"
		"gear_done":overlay=""
		"weapon":
			var i=run.weapons.find(int(run.weapon));run.equip(true,run.weapons[(i+1)%run.weapons.size()])
		"trinket":
			var i=run.charms.find(int(run.charm));run.equip(false,run.charms[(i+1)%run.charms.size()])
		"offer_prev":offer_index=posmod(offer_index-1,available_offers().size())
		"offer_next":offer_index=(offer_index+1)%available_offers().size()
		"hire":
			var offers=available_offers()
			if not offers.is_empty():run.recruit(offers[offer_index%offers.size()]);offer_index=0
		"crew_prev":if not run.owned.is_empty():crew_index=posmod(crew_index-1,run.owned.size())
		"crew_next":if not run.owned.is_empty():crew_index=(crew_index+1)%run.owned.size()
		"left","right":if not run.owned.is_empty():run.assign(run.owned[crew_index%run.owned.size()],0 if command=="left" else 1)
		"train":if not run.owned.is_empty():run.train(run.owned[crew_index%run.owned.size()])
		"feed":run.feed()
		"sound","music","reduced","haptic":
			settings[command]=not settings[command];save_now()
			if command=="music" and music!=null:
				if settings.music:music.play()
				else:music.stop()
func best_wave():
	return int(profile.best[selection])
func name_for(id):return "Iris" if id==18 else Book.HEROES[int(id)][0]
func available_offers():
	var offers=run.shop.get("offers",[]).duplicate()
	if profile.rescued and not run.owned.has(18):offers.append(18)
	return offers
func _draw():
	if fonts.is_empty():return
	off=((get_viewport_rect().size-Vector2(360,640))*.5).round();draw_set_transform(off);boundaries.clear()
	var region=int((run.wave-1)/10.0)%4 if screen=="play" and run!=null else 0
	scenery(region,run.clock if screen=="play" and run!=null else time,settings.reduced)
	if screen=="select":draw_selector()
	elif run!=null:
		if run.phase=="shop" and run.picks==0:draw_market()
		else:
			combat_scene(run,settings.reduced)
			draw_hud()
			if run.phase=="battle":draw_controls()
			elif run.phase=="dead":draw_defeat()
			else:draw_intermission()
	if save_failed:plate(Rect2(14,89,332,29),INK,CORAL);mid("Save failed. Keep the game open.",109,13,CORAL)
	if overlay!="":draw_overlay()
func draw_selector():
	mid("GRIM SALVAGE",30,13,MUTED)
	mid("THE TENTH BELL",75,40,CREAM,true)
	mid("18 KEEPERS  /  ONE LAST STATION",99,12,GOLD)
	button(Rect2(306,14,40,37),"=","settings",false,true,24)
	mid("Swipe to browse. Tap a keeper to preview.",126,12,MUTED)
	hero(posmod(selection-1,18),Vector2(75,289),time,"idle",.78,1,Color(.7,.8,.8,.6))
	hero((selection+1)%18,Vector2(285,289),time,"idle",.78,-1,Color(.7,.8,.8,.6))
	draw_ellipse_shadow(Vector2(180,337),29);hero(selection,Vector2(180,337),time,"attack" if preview_left>0 else "idle",1.36,1,Color.WHITE,1-preview_left/.8 if preview_left>0 else -1)
	boundaries.append([Rect2(120,205,120,139),"preview"])
	button(Rect2(14,283,42,43),"<","prev");button(Rect2(304,283,42,43),">","next")
	plate(Rect2(12,350,336,224))
	var labels=["Blade","Ninja","Tiny","Satyr","School","Paint"]
	for i in 6:button(Rect2(18+i*54,356,53,36),labels[i],"group:"+str(i),int(selection/3.0)==i,true,16)
	var h=Book.HEROES[selection];var color=Color(Book.COLORS[int(selection/3.0)])
	words("%02d / 18"%(selection+1),Vector2(24,414),12,MUTED)
	words(h[1].to_upper(),Vector2(106,414),12,color)
	words(h[0],Vector2(24,449),31,CREAM,true)
	words("BEST  "+str(int(profile.best[selection])),Vector2(271,446),11,GOLD)
	words("PASSIVE" if detail else h[3].to_upper(),Vector2(24,477),13,color)
	paragraph(h[2] if detail else h[4],Vector2(24,499),309,13,CREAM,17)
	button(Rect2(24,532,117,31),"Skill / passive","detail",false,true,15)
	if best_wave()>=10:button(Rect2(149,532,187,31),Book.CHARMS[first_charm],"charm",false,true,15)
	else:words("Charms unlock at wave 10",Vector2(151,553),10,MUTED)
	if disk_run.is_empty():
		button(Rect2(12,581,67,48),"How to","help",false,true,17)
		button(Rect2(86,581,262,48),"HOLD THE STATION","start",true,true,24)
	else:
		button(Rect2(12,581,121,48),"New run","start",false,true,22)
		button(Rect2(140,581,208,48),"CONTINUE  /  "+str(int(disk_run.get("wave",1))),"continue",true,true,24)
func draw_hud():
	plate(Rect2(10,10,340,76))
	words("WAVE %02d"%run.wave,Vector2(22,34),23,GOLD,true)
	words("%d G"%run.gold,Vector2(239,33),13,GOLD)
	button(Rect2(298,17,44,44),"II","pause",false,true,23)
	meter(Rect2(22,44,262,9),run.hp/run.max_hp,MINT)
	words("%d / %d HP"%[ceili(run.hp),run.max_hp],Vector2(22,70),11,CREAM)
	words("LV %d"%run.level,Vector2(130,70),11,MUTED)
	var left=run.plan.size()-run.kills
	words("%d remain"%left if run.phase=="battle" else "STATION HELD",Vector2(202,70),11,MUTED)
	mid(Book.REGION[int((run.wave-1)/10.0)%4].to_upper(),108,12,GOLD)
	if run.wave%10==0:mid("TOLLKEEPER APPROACHES",130,15,CORAL,true)
	elif run.message_time>0:mid(run.recent_message,131,16,GOLD,true)
func draw_controls():
	var h=Book.HEROES[run.lead];var a=run.actors[0]
	if run.wave==1 and run.clock<10:
		plate(Rect2(40,378,280,58),INK,RIM)
		mid("Attacks are automatic.",400,14,CREAM)
		mid("Tap a foe to focus. Time the bell!",421,12,MUTED)
	elif run.rescue_done and run.rescue_health>0 and run.rescue_wave:mid("IRIS IS SAFE - finish the wave",413,15,MINT,true)
	else:mid(Book.FORM[run.formation],414,14,MUTED)
	plate(Rect2(12,470,336,57))
	words("YOUR CREW",Vector2(24,488),11,GOLD)
	for i in 2:
		var id=int(run.slots[i]);var x=24+i*166
		words(("L  " if i==0 else "R  ")+(name_for(id) if id>=0 else "Empty seat"),Vector2(x,511),13,CREAM if id>=0 else MUTED)
	button(Rect2(12,539,182,80),"","skill",true,a.skillcd<=0)
	words(h[3],Vector2(24,566),20,CREAM,true)
	words("READY  /  TAP" if a.skillcd<=0 else "%.1fs"%a.skillcd,Vector2(24,592),13,GOLD)
	meter(Rect2(24,605,157,4),1-a.skillcd/9.0,MINT)
	button(Rect2(202,539,146,80),"","bell",false,run.bell_cd<=0)
	words("RING THE BELL",Vector2(214,566),19,CREAM,true)
	words("Interrupt / push" if run.bell_cd<=0 else "%.1fs"%run.bell_cd,Vector2(214,592),12,GOLD)
	meter(Rect2(214,605,122,4),1-run.bell_cd/8.0,GOLD)
func draw_intermission():
	plate(Rect2(12,133,336,429),INK,GOLD)
	mid("THE TENTH BELL" if run.phase=="shop" else "STAIRWAYS CLEAR",167,28,GOLD,true)
	mid("Wave %d held  /  +%d gold"%[run.wave,run.earned],194,14,CREAM)
	paragraph(run.report,Vector2(28,219),304,12,MUTED)
	if run.drop_text!="":mid("FOUND  "+run.drop_text,250,13,MINT)
	if run.picks>0:
		mid("CHOOSE AN UPGRADE  /  %d"%run.picks,276,12,GOLD)
		var h=Book.HEROES[run.lead]
		var options=[]
		if evolve:options=[[h[5],h[6],"evo1"],[h[7],h[8],"evo2"]]
		else:options=[["Signature II" if run.rank==1 else ("Evolve your skill" if run.rank==2 else "Quick hands"),("Cooldown 9s to 7.5s." if run.lead in [0,2,14] else "Skill +16%; cooldown 9s to 7.5s.") if run.rank==1 else ("Choose one of two new powers." if run.rank==2 else "+7% attack speed."),"signature" if run.rank<3 else "tempo"],["Sharpen","+12% base attack damage.","might"],["Catch your breath","+12 max HP and restore 24 HP.","vital"]]
		for i in options.size():
			var o=options[i];var y=287+i*76
			button(Rect2(24,y,312,65),"","upgrade:"+o[2],i==0)
			words(o[0],Vector2(36,y+26),24,CREAM,true);paragraph(o[1],Vector2(36,y+47),288,12,MUTED)
	else:
		mid("LEVEL %d"%run.level,297,30,CREAM,true)
		mid("%d / %d XP"%[run.xp,run.level_cost()],322,13,MUTED)
		meter(Rect2(51,336,258,7),float(run.xp)/run.level_cost(),MINT)
		button(Rect2(24,363,312,56),"Equipment  /  "+Book.WEAPONS[int(run.weapon)],"gear",false,true,20)
		paragraph("Your next foes arrive only when you are ready.",Vector2(38,455),284,14,MUTED,20)
		button(Rect2(24,493,312,52),"START WAVE %d"%(run.wave+1),"nextwave",true,true,24)
func draw_market():
	plate(Rect2(10,10,340,90),INK,GOLD)
	words("THE TRAVELLING CART",Vector2(23,42),28,GOLD,true)
	words("Wave %d held. The next bell changes things."%run.wave,Vector2(23,67),12,MUTED)
	button(Rect2(302,72,36,26),"II","pause",false,true,16)
	plate(Rect2(14,109,332,60))
	words("NEXT: WAVE %d"%(run.wave+1),Vector2(25,129),12,GOLD)
	var threats=["Shields lead. Snipers follow. Hire armor break or a backline interrupt.","A war drummer hastens the convoy. Silence the rear rank.","Mirror guards and elite rushes. Bring control and protection."]
	paragraph(threats[int(run.wave/10.0-1)%3],Vector2(25,147),310,11,CREAM,14)
	cart(time)
	var offers=available_offers()
	for i in mini(3,offers.size()):hero(offers[i],Vector2(185+i*58,287),time,"idle",.8,-1)
	mid("A warm meal. A sharper edge. A second pair of hands.",299,10,MUTED)
	plate(Rect2(12,307,336,315),INK,GOLD)
	words("YOUR PURSE",Vector2(24,329),12,MUTED);words("%d GOLD"%run.gold,Vector2(230,330),19,GOLD,true)
	for i in 3:button(Rect2(20+i*107,339,106,38),["HIRE","CREW","GEAR"][i],"tab:"+str(i),market_tab==i,true,19)
	match market_tab:
		0:
			if not offers.is_empty():
				var id=int(offers[offer_index%offers.size()]);var h=Book.HEROES[14 if id==18 else id]
				button(Rect2(24,389,40,44),"<","offer_prev")
				mid(name_for(id),417,26,CREAM,true)
				button(Rect2(296,389,40,44),">","offer_next")
				mid("HEALER / WARDEN" if id==18 else h[1].to_upper(),445,12,GOLD)
				paragraph("Iris heals on every ward. Meals strengthen her healing." if id==18 else h[4],Vector2(30,469),300,13,CREAM,18)
				var price=0 if id==18 else run.recruit_cost()
				button(Rect2(24,516,312,43),"RECRUIT FREE" if price==0 else "RECRUIT  /  %d GOLD"%price,"hire",true,run.gold>=price,21)
			else:mid("Everyone has found a seat.",445,21,CREAM,true)
		1:
			if run.owned.is_empty():paragraph("Recruit a companion first. Two fight beside you; the rest wait in reserve.",Vector2(31,408),299,14,CREAM,20)
			else:
				var id=int(run.owned[crew_index%run.owned.size()]);var trained=int(run.trained.get(str(id),0))
				button(Rect2(24,389,40,40),"<","crew_prev");button(Rect2(296,389,40,40),">","crew_next")
				mid(name_for(id)+"  +"+str(trained),416,25,CREAM,true)
				button(Rect2(24,439,151,48),"LEFT SEAT","left",run.slots[0]==id,true,18);button(Rect2(184,439,152,48),"RIGHT SEAT","right",run.slots[1]==id,true,18)
				button(Rect2(24,501,151,48),"TRAIN / %dG"%(28+14*trained) if trained<4 else "MAX TRAINING","train",false,trained<4 and run.gold>=28+14*trained,18)
				button(Rect2(184,501,152,48),"IRIS MEAL / 12G","feed",false,profile.rescued and not run.shop.fed and run.gold>=12,17)
				mid("IRIS BOND  %d"%int(profile.bond),566,11,MUTED)
		2:
			mid(Book.WEAPONS[int(run.weapon)],416,25,CREAM,true)
			mid(Book.WEAPON_DESC[int(run.weapon)],442,13,MUTED)
			button(Rect2(24,461,312,41),"CHANGE EQUIPMENT","gear",false,true,20)
			paragraph("Loot arrives on boss clears and every seventh wave. Equipment lasts for this run.",Vector2(32,526),296,12,MUTED,16)
	button(Rect2(24,572,312,40),"DEPART  /  WAVE %d"%(run.wave+1),"nextwave",true,true,22)
func draw_defeat():
	plate(Rect2(16,154,328,390),INK,GOLD)
	mid("THE BELL FALLS SILENT",196,29,GOLD,true)
	mid("WAVE %d"%run.wave,246,43,CREAM,true)
	mid("Stopped by "+run.kill_name,276,14,MUTED)
	paragraph("Every keeper leaves something behind. Your records, rescued friends and bonds remain.",Vector2(35,319),290,14,CREAM,21)
	mid("PERSONAL BEST  /  %d"%int(profile.best[run.lead]),416,17,MINT,true)
	button(Rect2(31,466,298,55),"CHOOSE YOUR NEXT KEEPER","again",true,true,23)
func draw_overlay():
	boundaries.clear();draw_rect(Rect2(-off,get_viewport_rect().size),Color(0.02,0.04,0.07,.86))
	plate(Rect2(16,126,328,423),INK,GOLD)
	match overlay:
		"pause":
			mid("STATION PAUSED",177,34,GOLD,true);mid("Take your time. The stairs can wait.",208,12,MUTED)
			button(Rect2(30,248,300,54),"RESUME","resume",true,true,27)
			button(Rect2(30,316,145,51),"SETTINGS","settings");button(Rect2(185,316,145,51),"HOW TO PLAY","help",false,true,19)
			button(Rect2(30,390,300,50),"RETURN TO SELECTION","home",false,true,23)
			paragraph("Saved at the start of this wave. Returning later replays the wave with your saved gear.",Vector2(33,479),294,12,MUTED,18)
		"settings":
			mid("AT YOUR PACE",171,32,GOLD,true)
			for i in 4:
				var k=["sound","music","reduced","haptic"][i];var label=["Sound effects","Music","Reduced motion","Haptics"][i]
				button(Rect2(30,195+i*57,300,46),label+"  /  "+("ON" if settings[k] else "OFF"),k,false,true,22)
			button(Rect2(30,436,300,38),"Credits","credits",false,true,19)
			button(Rect2(30,486,300,44),"BACK","back",true)
		"help":
			mid("HOLD THE CROSSING",169,31,GOLD,true)
			paragraph("1. Your keeper attacks automatically. Tap an enemy to focus your attacks.",Vector2(32,209),296,14,CREAM,20)
			paragraph("2. Use your signature skill when ready. Ring the bell just before an enemy's strike: the amber ring turns red for a perfect interrupt.",Vector2(32,279),296,14,CREAM,20)
			paragraph("3. After each tenth wave, visit the cart. Recruit two allies, train them and prepare for the next enemy formation.",Vector2(32,390),296,14,CREAM,20)
			button(Rect2(30,486,300,44),"GOT IT","back",true)
		"confirm":
			mid("A NEW DEPARTURE?",178,31,GOLD,true)
			paragraph("Starting a new run replaces your current checkpoint. Your records, rescued Iris and her bond stay with you.",Vector2(34,235),292,15,CREAM,23)
			button(Rect2(30,386,300,54),"START A NEW RUN","new_confirm",true,true,24)
			button(Rect2(30,462,300,54),"KEEP MY CHECKPOINT","back",false,true,23)
		"gear":
			mid("KEEPER'S KIT",173,34,GOLD,true)
			mid("WEAPON",211,12,MUTED);mid(Book.WEAPONS[int(run.weapon)],242,27,CREAM,true)
			mid(Book.WEAPON_DESC[int(run.weapon)],266,13,MUTED)
			button(Rect2(30,283,300,40),"CYCLE WEAPON","weapon",false,run.weapons.size()>1)
			mid(Book.CHARMS[int(run.charm)],371,26,CREAM,true)
			mid(Book.CHARM_DESC[int(run.charm)],398,12,MUTED)
			button(Rect2(30,416,300,40),"CYCLE CHARM","trinket",false,run.charms.size()>1)
			button(Rect2(30,486,300,44),"EQUIPPED  /  BACK","gear_done",true,true,23)
		"credits":
			mid("MADE FOR THE CROSSING",173,28,GOLD,true)
			paragraph("Character sprites: CraftPix.net. Samurai, Shinobi, Tiny Heroes, Satyrs, Schoolgirls and Graffiti Artists. Used under the CraftPix free asset license.",Vector2(32,216),296,14,CREAM,21)
			paragraph("Fonts: Jersey 10 and Pixelify Sans, SIL Open Font License. Scenery, enemy art, music and sound effects made for The Tenth Bell.",Vector2(32,353),296,14,MUTED,21)
			button(Rect2(30,486,300,44),"BACK","settings",true)
