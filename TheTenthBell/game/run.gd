extends RefCounted
## Combat runs in fixed ticks. Checkpoints contain primitive data only.
const Book=preload("res://data/roster.gd")
const Arts=preload("res://game/arts.gd")
signal checkpoint_changed
signal cue(kind)
var rng=RandomNumberGenerator.new()
var meta={}
var phase="ready"
var lead=0
var wave=1
var hp=100.0
var max_hp=100.0
var barrier=0.0
var gold=0
var xp=0
var level=1
var picks=0
var strength=1.0
var speed_bonus=1.0
var rank=1
var evo=0
var weapon=0
var charm=0
var weapons=[0]
var charms=[0]
var owned=[]
var slots=[-1,-1]
var trained={}
var shop={}
var seed_number=1
var last_form=-1
var formation=0
var enemies=[]
var actors=[]
var shots=[]
var events=[]
var effects=[]
var areas=[]
var plan=[]
var clock=0.0
var spawn_i=0
var kills=0
var next_id=1
var focus=-1
var bell_cd=0.0
var guard_source=-1
var guard_time=0.0
var next_melee_guard=false
var ward_time=0.0
var ward_mode=0
var caught_shot=0.0
var decoy=0
var team_haste=0.0
var breach=0
var gust_time=0.0
var rescue_wave=false
var rescue_health=3
var rescue_elapsed=0.0
var rescue_done=false
var rescue_spawned=false
var kill_name=""
var report=""
var drop_text=""
var earned=0
var last_start={}
var assist_hits=0
var recent_message=""
var message_time=0.0

static func default_meta():
	return {"best":[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],"rescued":false,"bond":0}
func new_run(id,profile,first_charm=0,run_seed=0):
	meta=profile;lead=id
	seed_number=run_seed if run_seed else int(Time.get_unix_time_from_system())^randi()
	charm=first_charm
	if charm:charms.append(charm)
	begin_wave()
func progress_data():
	return {"phase":phase,"lead":lead,"wave":wave,"hp":hp,"max_hp":max_hp,"gold":gold,"xp":xp,"level":level,"picks":picks,"strength":strength,"speed_bonus":speed_bonus,"rank":rank,"evo":evo,"weapon":weapon,"charm":charm,"weapons":weapons.duplicate(),"charms":charms.duplicate(),"owned":owned.duplicate(),"slots":slots.duplicate(),"trained":trained.duplicate(true),"shop":shop.duplicate(true),"seed_number":seed_number,"last_form":last_form,"report":report,"drop_text":drop_text,"earned":earned}
func checkpoint():
	return last_start.duplicate(true) if phase=="battle" else progress_data()
func restore(data,profile):
	meta=profile
	for key in progress_data().keys():
		if data.has(key):set(key,data[key])
	lead=int(lead);wave=int(wave);rank=int(rank);evo=int(evo);level=int(level);picks=int(picks)
	for arr in [slots,owned,charms,weapons]:
		for i in arr.size():arr[i]=int(arr[i])
	if shop.has("offers"):
		for i in shop.offers.size():shop.offers[i]=int(shop.offers[i])
	if phase in ["battle","ready"]:begin_wave()
	else:form_party()
func enemy_pos(e):
	var p=clampf(e.p,0,1.04)
	return Vector2(round(180+e.side*(174-150*p)),round(203+132*p))
func actor_pos(a):
	return Vector2(180,346) if a.slot<0 else Vector2(180+a.side*48,342)
func actor_data(id,slot):
	var k=int(id);var tr=int(trained.get(str(k),0))
	return {"id":k,"kit":14 if k==18 else k,"slot":slot,"side":1 if slot!=0 else -1,"face":1 if slot!=1 else -1,"cd":0.15,"skillcd":0.0 if slot<0 else 1.0,"anim":0.0,"anim_len":0.0,"state":"idle","hits":0,"last_side":0,"last_id":-1,"chain":0,"haste":0.0,"rank":rank if slot<0 else mini(3,1+tr),"evo":evo if slot<0 else (1 if tr>=2 else 0),"mult":1.0 if slot<0 else 0.72+0.12*tr}
func form_party():
	actors=[actor_data(lead,-1)]
	for i in 2:
		if int(slots[i])>=0:actors.append(actor_data(slots[i],i))
func _append_spawn(at,side,kind,elite=false):
	plan.append({"at":at,"side":side,"kind":kind,"elite":elite})
func build_plan():
	plan.clear();rng.seed=int(seed_number)+wave*7919
	var tier=int((wave-1)/10.0);var phase_wave=(wave-1)%10+1
	formation=(int(rng.randi_range(0,3))+wave)%5
	if formation==last_form:formation=(formation+1)%5
	if wave==1:formation=0
	if phase_wave==1 and tier>0:formation=[2,3,4][(tier-1)%3]
	last_form=formation
	if phase_wave==10:
		_append_spawn(0.4,-1 if tier%2==0 else 1,5,true)
		for i in 3+mini(tier,6):_append_spawn(6+i*4,1 if i%2==0 else -1,[0,1,2,3][(i+tier)%4])
		return
	if phase_wave==1 and tier>0:
		match tier%3:
			1:
				_append_spawn(0.3,-1,2);_append_spawn(1.3,-1,3);_append_spawn(2.6,1,1);_append_spawn(3.4,1,1)
			2:
				_append_spawn(0.3,1,2);_append_spawn(1.1,1,4);_append_spawn(2.2,-1,2)
			0:
				_append_spawn(0.3,-1,6,true);_append_spawn(1.6,1,6,true)
	var count=4+mini(phase_wave,8)+mini(12,tier*2)
	for i in count:
		var side=-1 if (i+formation)%2==0 else 1
		if formation in [2,3]:side=-1 if (i%4)<2 else 1
		var kind=0
		if wave>=2 and i%3==1:kind=1
		if wave>=4 and i%4==2:kind=2
		if wave>=6 and i%5==2:kind=3
		if wave>=14 and i%7==3:kind=4
		if wave>=23 and i%8==5:kind=6
		if formation==4 and wave>=7 and i%5==0:kind=3
		var spacing=maxf(1.05,(2.75 if phase_wave<4 else 3.15)-0.105*tier)
		_append_spawn((5.6 if phase_wave==1 and tier>0 else 0.4)+i*spacing+rng.randf_range(0,0.5),side,kind,phase_wave in [7,9] and i==count-1)
	plan.sort_custom(func(a,b):return a.at<b.at)
func begin_wave():
	phase="battle";last_start=progress_data()
	clock=0;spawn_i=0;kills=0;next_id=1;focus=-1;bell_cd=0;barrier=0;message_time=0
	guard_source=-1;guard_time=0;next_melee_guard=false;ward_time=0;ward_mode=0;caught_shot=0;decoy=0;team_haste=0;breach=0;gust_time=0
	enemies.clear();shots.clear();events.clear();effects.clear();areas.clear()
	rescue_wave=not meta.get("rescued",false) and (wave==7 or (wave>10 and wave%10==4))
	rescue_health=3;rescue_elapsed=0;rescue_done=false;rescue_spawned=false
	form_party();build_plan();report="";drop_text=""
	checkpoint_changed.emit();cue.emit("start")
func next_wave():
	if phase not in ["between","shop"] or picks>0:return false
	wave+=1;shop={};begin_wave();return true
func spawn(ticket):
	var k=int(ticket.kind);var tier=int((wave-1)/10.0)
	var health=[13,10,22,15,20,105,26][k]*(1.0+0.058*(wave-1)+0.15*tier)
	if ticket.elite and k!=5:health*=1.5
	var e={"uid":next_id,"kind":k,"side":ticket.side,"p":0.0,"hp":health,"max":health,"armor":4.0+0.6*tier if k in [2,5,6] else 0.0,"shield":9.0+2*tier if k==2 else 0.0,"elite":ticket.elite,"wind":-1.0,"windmax":1.0,"cd":0.15+0.19*(next_id%3),"flash":0.0,"root":0.0,"slow":0.0,"stun":0.0,"expose":0.0,"silence":0.0,"burn":0.0,"burn_d":0.0,"burn_tick":0.6,"burn_spread":false,"pushed":0.0,"marked":false,"seen_owlet":false,"outline":false,"book":0,"ink":0,"detain":false,"sticky":0.0,"sticky_mode":0,"feint":false,"attack_no":0,"rescue_hit":false}
	next_id+=1;enemies.append(e);return e
func alive(e):return e!=null and e.hp>0
func find_enemy(uid):
	for e in enemies:
		if e.uid==uid and e.hp>0:return e
	return null
func living(side=0):
	var out=[]
	for e in enemies:
		if alive(e) and (not side or e.side==side):out.append(e)
	out.sort_custom(func(a,b):return a.p>b.p)
	return out
func target(a,unlimited=false):
	var reach=0.0 if unlimited or a.kit in Book.RANGED else (0.56 if a.slot<0 else 0.44)
	var marked=find_enemy(focus)
	if a.slot<0 and marked!=null and marked.p>=reach:return marked
	var best=null;var score=-99.0
	for e in enemies:
		if e.hp<=0 or e.p<reach:continue
		var val=e.p+(1.0 if a.slot>=0 and e.side==a.side else 0.0)
		if val>score:score=val;best=e
	return best
func focus_on(p):
	var best=null;var dist=32.0
	for e in enemies:
		var d=(enemy_pos(e)-Vector2(0,14)).distance_to(p)
		if alive(e) and d<dist:best=e;dist=d
	if best!=null:focus=best.uid;cue.emit("tap")
func animate(a,state,duration,side):
	a.state=state;a.anim=duration;a.anim_len=duration;a.face=side
func later(delay,callback):events.append({"left":delay,"call":callback})
func fly(start,end,kind,owner,life,on_land,enemy=false,uid=-1):
	shots.append({"a":start,"b":end,"kind":kind,"owner":owner,"age":0.0,"life":maxf(0.06,life),"call":on_land,"enemy":enemy,"uid":uid})
func fx(pos,kind,color,life=0.35,label="",other=Vector2.ZERO):
	if effects.size()>=100:effects.pop_front()
	effects.append({"p":pos,"q":other,"kind":kind,"color":color,"life":life,"age":0.0,"text":label})
func say(msg):recent_message=msg;message_time=2.4
func heal(amount):hp=minf(max_hp,hp+amount)
func interrupt(e,seconds=0.9):
	if not alive(e):return false
	if e.kind==5 and (e.wind<0 or e.wind>0.53):return false
	e.wind=-1.0;e.stun=maxf(e.stun,seconds);e.cd=maxf(e.cd,0.9);return true
func push(e,amount):
	if not alive(e):return
	e.p=maxf(0.03,e.p-amount*(0.32 if e.kind==5 else 1.0));e.pushed=1.3
func hurt(e,power,owner=-1,pierce=false):
	if not alive(e):return
	var value=maxf(1.0,power-(0.0 if pierce else e.armor*0.48))
	if e.expose>0:value*=1.38
	if e.shield>0 and not pierce:
		var absorb=minf(e.shield,value*0.7);e.shield-=absorb;value-=absorb
	e.hp-=value;e.flash=0.13
	if owner>=0 and owner!=lead:assist_hits+=1
	var pos=enemy_pos(e)-Vector2(0,19)
	fx(pos,"hit","ffe2a0",0.21)
	if value>9:fx(pos+Vector2((e.uid%3-1)*4,-3),"number","ffdc99",0.42,str(roundi(value)))
	if e.sticky>0:
		var damage=e.sticky;var mode=int(e.sticky_mode);e.sticky=0.0
		if mode==2:e.armor=0;e.shield=0
		fx(pos,"burst","f58abc",0.48)
		if alive(e):hurt(e,damage,6,true)
		for other in living(e.side):
			if other.uid==e.uid or absf(other.p-e.p)>0.36:continue
			hurt(other,damage*0.55,6)
			if mode==1 and alive(other):other.sticky=damage*0.35;other.sticky_mode=0
	if e.hp<=0 and not e.get("counted",false):
		e.counted=true;kills+=1;fx(pos,"dust","d4af85",0.54)
		if e.burn_spread:
			for other in living(e.side):
				if absf(other.p-e.p)<0.46:other.burn=2.8;other.burn_d=maxf(other.burn_d,e.burn_d)
		cue.emit("kill" if e.kind!=5 else "boss")
func take_hit(e,amount,projectile=false):
	if phase!="battle":return
	if projectile and (ward_time>0 or decoy>0 or gust_time>0):
		if gust_time>0 and alive(e):hurt(e,amount*1.6,11,true)
		elif ward_time>0:
			caught_shot=amount
			if ward_mode==2:heal(amount*0.8)
		else:decoy-=1
		fx(Vector2(180,320),"burst","8ae7db",0.35);return
	if guard_time>0:
		guard_time=0
		var a=actors[maxi(0,guard_source)];var enemy=e if alive(e) else target(a,true)
		if enemy!=null:
			hurt(enemy,attack_power(a)*2.9,a.id,true)
			if a.evo==1:
				for other in living(-enemy.side):hurt(other,attack_power(a)*1.1,a.id)
		if a.evo==2:heal(16)
		guard_source=-1;say("COUNTER");cue.emit("perfect");return
	if next_melee_guard and not projectile:amount*=0.52;next_melee_guard=false
	var absorb=minf(amount,barrier);barrier-=absorb;amount-=absorb;hp=maxf(0,hp-amount)
	fx(Vector2(180,308),"number","ff927e",0.6,"-"+str(ceili(amount)));cue.emit("hurt")
	if hp<=0:phase="dead";kill_name=Book.TYPES[int(e.kind)];checkpoint_changed.emit()
func attack_power(a):
	return float(Book.DAMAGE[a.kit])*strength*a.mult*(1.0+[0.0,0.12,0.22,0.35][int(weapon)])
func ring():
	if phase!="battle" or bell_cd>0:return false
	bell_cd=8.0;var perfect=false
	for e in living():
		var close=e.p>0.43
		if e.wind>=0 and e.wind<=0.46 and (close or e.kind in [3,4,5]):
			if interrupt(e,1.25):perfect=true;e.expose=2.6;hurt(e,7*strength,lead,true)
		if close:push(e,0.18)
	for zone in areas:
		if zone.kind=="fire" and zone.mode==2:
			for e in living(zone.side):hurt(e,zone.strength*1.6,15,true)
			zone.left=0.0
	if perfect:
		if charm==1:bell_cd-=2
		say("PERFECT RING");cue.emit("perfect")
	else:cue.emit("bell")
	fx(Vector2(180,319),"ring","ffe0a2" if perfect else "99ded0",0.67);return true
func signature():
	if phase!="battle" or actors.is_empty():return false
	return Arts.cast(self,actors[0])
func tick(dt):
	if phase!="battle":return
	clock+=dt;message_time-=dt;bell_cd=maxf(0,bell_cd-dt);guard_time=maxf(0,guard_time-dt)
	team_haste=maxf(0,team_haste-dt);gust_time=maxf(0,gust_time-dt)
	if ward_time>0:
		ward_time-=dt
		if ward_time<=0 and ward_mode==1 and caught_shot>0 and not living().is_empty():
			hurt(living()[0],caught_shot*2,14,true);caught_shot=0
	while spawn_i<plan.size() and plan[spawn_i].at<=clock:spawn(plan[spawn_i]);spawn_i+=1
	for job in events.duplicate():
		job.left-=dt
		if job.left<=0:events.erase(job);job.call.call()
	for shot in shots.duplicate():
		shot.age+=dt
		if shot.uid>=0:
			var track=find_enemy(shot.uid)
			if track!=null:shot.b=enemy_pos(track)-Vector2(0,18)
		if shot.age>=shot.life:shots.erase(shot);shot.call.call()
	for zone in areas.duplicate():
		zone.left-=dt;zone.tick-=dt
		if zone.left<=0:areas.erase(zone);continue
		if zone.tick<=0:zone.tick=0.68;Arts.zone_tick(self,zone)
	for item in effects.duplicate():
		item.age+=dt
		if item.age>=item.life:effects.erase(item)
	for a in actors:
		a.cd-=dt*(1.46 if team_haste>0 or a.haste>0 else 1.0)*speed_bonus
		a.haste=maxf(0,a.haste-dt);a.skillcd=maxf(0,a.skillcd-dt);a.anim=maxf(0,a.anim-dt)
		if a.slot>=0 and a.skillcd<=0 and not living().is_empty():Arts.cast(self,a)
		if a.cd<=0 and a.anim<0.11:
			var e=target(a)
			if e!=null:Arts.basic(self,a,e);a.cd=Book.SPEEDS[a.kit]
	var boosted={-1:false,1:false}
	for e in enemies:
		if alive(e) and e.kind==4 and e.silence<=0 and e.stun<=0:boosted[e.side]=true
	for e in enemies.duplicate():
		if not alive(e):enemies.erase(e);continue
		e.flash=maxf(0,e.flash-dt)
		for status in ["stun","root","slow","expose","pushed","silence"]:e[status]=maxf(0,e[status]-dt)
		if e.burn>0:
			e.burn-=dt;e.burn_tick-=dt
			if e.burn_tick<=0:e.burn_tick=0.7;hurt(e,e.burn_d,15,true)
		if not alive(e) or e.stun>0:continue
		enemy_tick(e,dt,boosted[e.side])
		if phase=="dead":return
	if rescue_wave and not rescue_done and clock>2.5:
		rescue_spawned=true;rescue_elapsed+=dt
		for e in living(-1):
			if not e.rescue_hit and e.p>.75:e.rescue_hit=true;rescue_health-=1
		if rescue_elapsed>=11 or rescue_health<=0:rescue_done=true
	if spawn_i==plan.size() and living().is_empty() and phase=="battle":clear_wave()
func enemy_tick(e,dt,boosted):
	var ranged=e.kind in [3,4]
	var movement=[0.103,0.173,0.083,0.094,0.091,0.077,0.105][e.kind]
	var stop=0.62 if ranged else 1.0
	if e.wind>=0:
		if e.silence>0 and ranged:e.wind=-1.0;e.cd=1.0;return
		e.wind-=dt
		if e.wind<=0:
			e.wind=-1.0;e.attack_no+=1
			if e.kind==5 and e.hp<e.max*0.5 and not e.feint:
				e.feint=true;e.wind=0.78;e.windmax=0.78;say("FEINT - WATCH THE STAIR");return
			var dmg=[5,4,7,8,4,15,10][e.kind]*(1.0+0.042*(wave-1))
			if e.kind==5 and wave>=20 and e.attack_no%2==0:dmg*=1.15
			if ranged:fly(enemy_pos(e)-Vector2(0,22),Vector2(180,322),"hostile",-1,0.72,func():take_hit(e,dmg,true),true)
			else:take_hit(e,dmg)
			e.cd=(2.8 if e.kind in [3,5,6] else 2.15)*(0.76 if boosted else 1.0)
		return
	if e.root<=0 and e.p<stop:
		var wall=false
		for z in areas:
			if z.kind=="wall" and z.side==e.side and e.p>=0.70:wall=true;break
		if not wall:e.p=minf(stop,e.p+dt*movement*(0.59 if e.slow>0 else 1.0)*(1.33 if boosted else 1.0))
	if e.p>=stop-0.012:
		e.cd-=dt
		if e.cd<=0 and (not ranged or e.silence<=0):
			e.windmax=1.23 if e.kind in [3,5,6] else 0.76;e.wind=e.windmax
			if e.kind in [3,5]:cue.emit("warn")
func clear_wave():
	earned=4+kills+int(wave/3.0)+(14 if wave%10==0 else 0)
	if charm==3:earned=roundi(earned*1.3)
	gold+=earned;xp+=8+kills*3+(18 if wave%10==0 else 0)
	while xp>=level_cost():xp-=level_cost();level+=1;picks+=1
	heal(7+(9 if charm==2 else 0));meta.best[lead]=maxi(int(meta.best[lead]),wave)
	if rescue_wave and rescue_spawned and rescue_health>0:meta.rescued=true;report="IRIS RESCUED - a seat at every cart."
	else:report="Both stairs are quiet."
	drop_text=""
	if wave%7==0 or wave%10==0:
		var item=mini(3,1+int(wave/15.0))
		if not weapons.has(item):weapons.append(item);drop_text=Book.WEAPONS[item]
		elif not charms.has(1+int(wave/10.0)%3):
			item=1+int(wave/10.0)%3;charms.append(item);drop_text=Book.CHARMS[item]
	if wave%10==0:phase="shop";make_shop()
	else:phase="between"
	cue.emit("clear");checkpoint_changed.emit()
func level_cost():return 24+5*(level-1)
func choose_upgrade(choice):
	if phase not in ["between","shop"] or picks<=0:return false
	if choice=="signature" and rank==1:rank=2
	elif choice in ["evo1","evo2"] and rank==2:rank=3;evo=1 if choice=="evo1" else 2
	elif choice=="might":strength+=0.12
	elif choice=="vital":max_hp+=12;heal(24)
	elif choice=="tempo" and rank==3:speed_bonus+=0.07
	else:return false
	picks-=1;checkpoint_changed.emit();cue.emit("gain");return true
func make_shop():
	var options=[]
	var recommended=[17,3,1,4] if wave%30==10 else ([3,10,12,1] if wave%30==20 else [0,14,5,9])
	for id in recommended:
		if id!=lead and not owned.has(id):options.append(id)
		if options.size()>=(2 if lead==12 and wave==10 else 1):break
	var deck=[]
	for j in 18:
		if j!=lead and not owned.has(j) and not options.has(j):deck.append(j)
	for j in range(deck.size()-1,0,-1):
		var k=rng.randi_range(0,j);var tmp=deck[j];deck[j]=deck[k];deck[k]=tmp
	while options.size()<3 and not deck.is_empty():options.append(deck.pop_back())
	shop={"offers":options,"voucher":wave==10,"fed":false}
func recruit_cost():return 0 if shop.get("voucher",false) else 46+3*int(wave/10.0)
func recruit(id):
	if phase!="shop" or picks>0 or owned.has(id) or id==lead:return false
	var guest=id==18 and meta.rescued
	if not guest and not shop.offers.has(id):return false
	var price=0 if guest else recruit_cost()
	if gold<price:return false
	gold-=price
	if not guest:shop.voucher=false;shop.offers.erase(id)
	owned.append(id)
	for i in 2:
		if slots[i]<0:slots[i]=id;break
	form_party();checkpoint_changed.emit();cue.emit("gain");return true
func assign(id,slot_index):
	if phase!="shop" or not owned.has(id) or slot_index not in [0,1]:return
	var previous=slots.find(id)
	if previous>=0:slots[previous]=slots[slot_index]
	slots[slot_index]=id;form_party();checkpoint_changed.emit();cue.emit("tap")
func train(id):
	if phase!="shop" or not owned.has(id):return false
	var n=int(trained.get(str(id),0));var price=28+14*n
	if n>=4 or gold<price:return false
	gold-=price;trained[str(id)]=n+1;form_party();checkpoint_changed.emit();cue.emit("gain");return true
func feed():
	if phase!="shop" or not meta.rescued or shop.fed or gold<12:return false
	gold-=12;shop.fed=true;meta.bond=int(meta.bond)+1;checkpoint_changed.emit();cue.emit("gain");return true
func equip(is_weapon,item):
	if phase not in ["shop","between"]:return
	if is_weapon and weapons.has(item):weapon=item
	elif not is_weapon and charms.has(item):charm=item
	else:return
	checkpoint_changed.emit();cue.emit("tap")
func dispose():
	events.clear();shots.clear();areas.clear();effects.clear();enemies.clear();actors.clear()
