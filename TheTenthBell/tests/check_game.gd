extends SceneTree
const Run=preload("res://game/run.gd")
const Book=preload("res://data/roster.gd")
var failures=[]
func check(ok,message):
	if not ok:failures.append(message);push_error(message)
func drive(m,limit=180.0):
	var ticks=0
	while m.phase=="battle" and ticks<limit*45:
		if not m.living().is_empty():m.signature()
		for e in m.living():
			if e.wind>=0 and e.wind<=.43:m.ring();break
		m.tick(1.0/45);ticks+=1
	return ticks/45.0
func upgrades(m,branch=1):
	while m.picks>0:
		if m.rank==1:m.choose_upgrade("signature")
		elif m.rank==2:m.choose_upgrade("evo1" if branch==1 else "evo2")
		elif m.hp<m.max_hp*.7:m.choose_upgrade("vital")
		else:m.choose_upgrade("might")
func _initialize():call_deferred("run_tests")
func run_tests():
	for id in 18:
		var m=Run.new();m.new_run(id,Run.default_meta(),0,1843)
		var elapsed=0.0
		for w in range(1,11):
			elapsed+=drive(m);check(m.phase in ["between","shop"],"Hero %d failed wave %d at HP %.1f"%[id,w,m.hp])
			if m.phase=="dead":break
			upgrades(m,1 if id%2==0 else 2)
			if w<10:m.next_wave()
		check(m.wave==10 and m.phase=="shop","Merchant did not arrive for hero "+str(id))
		print("HERO ",id," ",Book.HEROES[id][0]," wave=",m.wave," phase=",m.phase," hp=",roundi(m.hp)," time=",roundi(elapsed))
		m.dispose()
	for id in 18:
		for branch in [1,2]:
			var m=Run.new();m.new_run(id,Run.default_meta(),0,92);m.wave=24;m.rank=3;m.evo=branch;m.max_hp=10000;m.hp=10000;m.begin_wave()
			for side in [-1,1]:
				for kind in [2,3,0,5]:
					var e=m.spawn({"kind":kind,"side":side,"elite":false});e.p=.88-kind*.035;e.wind=.4;e.windmax=1.0
			check(m.signature(),"Signature did not cast %d/%d"%[id,branch]);check(m.actors[0].skillcd>0,"Signature missing cooldown")
			for tick in 450:
				m.tick(1.0/45)
				if tick==60:m.ring()
			var damaged=m.kills>0
			for foe in m.enemies:
				if foe.hp<foe.max:damaged=true
			check(damaged,"Combat did not reach foes %d/%d"%[id,branch]);m.dispose()
	print("ALL 36 EVOLUTION COMBAT PATHS EXECUTED")
	# Shared marks must be consumed by a different party member, once.
	var passives=Run.new();passives.new_run(7,Run.default_meta(),0,4)
	var target=passives.spawn({"kind":0,"side":1,"elite":false});target.hp=1000;target.max=1000;target.p=.8
	var partner=passives.actor_data(0,0)
	Run.Arts.basic_hit(passives,passives.actors[0],target,10.0,true,false)
	check(target.marked,"Owlet failed to mark a new target")
	var before=target.hp;Run.Arts.basic_hit(passives,partner,target,10.0,true,false)
	check(is_equal_approx(before-target.hp,12.5) and not target.marked,"Owlet's mark did not empower a teammate once")
	var gilt=passives.actor_data(16,1);Run.Arts.basic_hit(passives,gilt,target,10.0,true,false)
	before=target.hp;Run.Arts.basic_hit(passives,partner,target,10.0,true,false)
	check(is_equal_approx(before-target.hp,14.5) and not target.outline,"Gilt's outline did not empower a teammate once")
	var fire=passives.actor_data(15,1);var other=passives.spawn({"kind":0,"side":-1,"elite":false});other.hp=1000;other.max=1000
	for foe in [target,other,target,other,target]:Run.Arts.basic_hit(passives,fire,foe,10.0,true,false)
	check(target.burn>0 and other.burn==0,"Paint ignition is not tracked per target")
	passives.dispose()
	print("SHARED MARKS, OUTLINES AND PER-TARGET FIRE PASSED")

	var m=Run.new();var meta=Run.default_meta();m.new_run(12,meta,0,1843)
	for w in range(1,11):
		drive(m);upgrades(m)
		if w<10:m.next_wave()
	check(meta.rescued,"Iris rescue never completed")
	var gold=m.gold;var free=m.shop.offers[0];check(m.recruit(free),"Free recruit failed");check(m.gold==gold,"Free recruit charged money")
	var paid=m.shop.offers[0];var price=m.recruit_cost();check(m.recruit(paid),"Paid recruit failed");check(m.gold==gold-price,"Paid recruit charged wrong amount")
	check(not m.recruit(paid),"Duplicate hire accepted")
	var snapshot=JSON.parse_string(JSON.stringify(m.checkpoint()));var restored=Run.new();restored.restore(snapshot,meta)
	check(restored.gold==m.gold and restored.slots==m.slots and not restored.shop.voucher,"Shop persistence failed")
	check(restored.recruit(18),"Rescued Iris not recruitable");restored.assign(18,1);check(restored.slots[1]==18 and restored.slots[0]==free,"Crew assignment failed")
	check(restored.feed(),"Meal failed");check(meta.bond==1 and not restored.feed(),"Bond or repeat meal failed")
	restored.assign(paid,1);restored.next_wave();check(restored.wave==11 and restored.plan.size()>10,"Wave 11 escalation missing")
	drive(restored);check(restored.phase=="between" and restored.assist_hits>0,"Allies did not fight in wave 11")
	print("MERCHANT, RECRUITMENT, SAVE, CREW AI, RESCUE AND BOND PASSED; ally hits=",restored.assist_hits)
	var wave_save=restored.checkpoint();restored.dispose();restored=Run.new();restored.restore(wave_save,meta);check(restored.wave==11,"Restore moved wave")
	m.dispose();restored.dispose()
	for w in [21,31,60,102]:
		var high=Run.new();high.new_run(17,Run.default_meta(),0,89);high.wave=w;high.strength=1+w*.13;high.max_hp=2000;high.hp=2000;high.owned=[3,9];high.slots=[3,9];high.trained={"3":4,"9":4};high.rank=3;high.evo=2;high.begin_wave()
		check(high.plan.size()>0,"Endless wave plan empty");drive(high,240);check(high.phase in ["between","shop"],"Endless wave stuck "+str(w));high.dispose()
	var death=Run.new();death.new_run(0,Run.default_meta(),0,89);var foe=death.spawn({"kind":5,"side":1,"elite":true});death.take_hit(foe,10000);check(death.phase=="dead" and death.hp==0,"Death transition failed");death.dispose()
	if failures.is_empty():print("BELL TESTS PASSED");quit(0)
	else:print("FAILED: ",failures);quit(1)
