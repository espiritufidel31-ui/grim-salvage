extends RefCounted
const B=preload("res://data/roster.gd")
static func basic(m,a,e,bonus=false,inherit=true):
	if not m.alive(e):return
	m.animate(a,"attack" if a.hits%3!=2 else "alt",0.47 if a.kit in [1,12] else 0.35,e.side)
	var power=m.attack_power(a)
	m.later(0.19 if a.kit in [1,12] else 0.14,func():
		if not m.alive(e):return
		if a.kit in B.RANGED:
			var p=m.actor_pos(a)-Vector2(0,27);var q=m.enemy_pos(e)-Vector2(0,19)
			m.fly(p,q,"basic",a.kit,clampf(p.distance_to(q)/365.0,0.12,0.45),func():basic_hit(m,a,e,power,inherit,bonus),false,e.uid)
		else:basic_hit(m,a,e,power,inherit,bonus))
static func basic_hit(m,a,e,power,inherit,bonus):
	if not m.alive(e):return
	if e.marked:power*=1.25;e.marked=false
	if e.outline:power*=1.45;e.outline=false
	if inherit:
		a.hits+=1
		if m.breach>0:e.armor=maxf(0,e.armor-4);e.shield=0;m.breach-=1
		match int(a.kit):
			0:if a.hits%3==0:m.next_melee_guard=true
			1:power*=1.0+(1.0-e.p)*0.48
			3:if e.wind>=0:power*=1.65
			4:if a.hits%3==0:m.interrupt(e,0.6)
			5:
				if a.last_side!=0 and a.last_side!=e.side:
					m.later(0.16,func():m.hurt(e,power*0.5,a.id))
			6:
				if e.pushed>0:m.later(0.1,func():m.hurt(e,power*0.65,a.id))
			7:
				if not e.seen_owlet:e.seen_owlet=true;e.marked=true
			8:m.push(e,0.035)
			9:if a.hits%3==0:m.heal(2.4)
			10:
				a.chain=int(a.chain)+1 if a.last_id==e.uid else 1
				if a.chain>=3:power*=1.65;a.chain=0;m.fx(m.enemy_pos(e),"burst","c5afff",0.3)
			11:
				if e.hp<e.max*0.5:
					for other in m.living(e.side):
						if other.uid!=e.uid and other.p<e.p:m.hurt(other,power*0.4,a.id);break
			12:e.book=mini(2,e.book+1)
			13:if e.pushed>0:a.haste=2.5
			14:if not e.detain:e.detain=true;e.slow=2.3
			15:
				e.ink+=1
				if e.ink%3==0:e.burn=2.8;e.burn_d=power*0.22
			16:e.outline=true
			17:e.armor=maxf(0,e.armor-1.4);e.shield=maxf(0,e.shield-2.5)
		a.last_side=e.side;a.last_id=e.uid
	m.hurt(e,power,a.id);m.cue.emit("hit")
	if inherit and a.kit==2 and a.hits%4==0 and not bonus:
		var allies=m.actors.duplicate();allies.erase(a)
		if allies.is_empty():allies=[a]
		for ally in allies:
			var t=m.target(ally)
			if t!=null:basic(m,ally,t,true)
static func flight_line(m,a,group,power,kind,owner=-1,after=Callable(),reverse=false):
	if group.is_empty():return
	var start=m.actor_pos(a)-Vector2(0,26)
	var end=m.enemy_pos(group.back())-Vector2(0,20)
	m.fly(end if reverse else start,start if reverse else end,kind,a.kit if owner<0 else owner,0.42,func():pass)
	for i in group.size():
		var e=group[i]
		var delay=0.06+0.32*float(group.size()-1-i if reverse else i)/maxi(1,group.size()-1)
		m.later(delay,func():
			if not m.alive(e):return
			m.hurt(e,power*(1.55 if kind=="bookback" and e.book>=2 else 1.0),a.id,kind in ["arrow","gust"])
			if after.is_valid():after.call(e))
static func zone(m,kind,side,power,mode,time,owner):
	m.areas.append({"kind":kind,"side":side,"strength":power,"mode":mode,"left":time,"tick":0.15,"owner":owner})
static func zone_tick(m,z):
	match z.kind:
		"fire":
			for e in m.living(z.side):
				if e.p>0.15:e.burn=2.4;e.burn_d=z.strength*0.19;e.burn_spread=z.mode==1;m.hurt(e,z.strength*0.22,15,true)
		"roots":
			for e in m.living(z.side):
				if e.root>0:m.hurt(e,z.strength*0.19,9,true)
			if z.mode==1:m.heal(1.6)
		"copy":
			if m.actors.is_empty():return
			var group=m.living(z.side)
			if not group.is_empty():basic(m,m.actors[0],group[0],true,z.mode==2)
static func cast(m,a):
	if a.skillcd>0:return false
	var e=m.target(a,true)
	if e==null and a.kit not in [0,2,14]:return false
	var side=int(e.side) if e!=null else a.face
	var power=m.attack_power(a)*(2.06 if a.rank>=2 else 1.78)
	var evolution=int(a.evo)
	a.skillcd=(7.5 if a.rank>=2 else 9.0)*(1.18 if a.slot>=0 else 1.0)
	m.animate(a,"special",0.7,side);m.cue.emit("skill")
	var group=m.living(side)
	match int(a.kit):
		0:m.guard_source=m.actors.find(a);m.guard_time=4.0 if evolution else 3.2;m.fx(m.actor_pos(a)-Vector2(0,25),"ring","a5e6d7",0.5)
		1:
			flight_line(m,a,group,power,"arrow")
			if evolution==1:
				for delay in [0.2,0.4]:m.later(delay,func():flight_line(m,a,m.living(side),power*0.63,"arrow"))
			elif evolution==2 and not group.is_empty():
				var last=group.back();m.later(0.5,func():
					if m.alive(last):last.root=3;m.interrupt(last,1.6))
		2:
			m.team_haste=5.5 if evolution else 4.5
			if evolution==1:m.barrier+=15
			elif evolution==2:m.breach=m.actors.size()*2
			m.fx(Vector2(180,317),"ring","ffd277",0.65)
		3:
			var back=group.back()
			for foe in group:
				if foe.kind in [3,4]:back=foe;break
			m.fx(m.enemy_pos(back),"shadow","baafff",0.45)
			m.later(0.19,func():
				if not m.alive(back):return
				m.interrupt(back,2.4);back.silence=2.6;m.hurt(back,power*1.4,a.id,true)
				if evolution==1 and not m.alive(back):
					var rest=m.living()
					if not rest.is_empty():m.hurt(rest.back(),power,a.id,true);m.interrupt(rest.back(),1.8))
			if evolution==2:m.decoy=1
		4:
			if evolution==2:e.armor=0;e.shield=0
			m.interrupt(e,1.5);m.push(e,0.21);m.hurt(e,power*1.4,a.id)
			if evolution==1:
				m.later(0.36,func():
					for other in m.living(side):
						if absf(other.p-e.p)<0.45:m.hurt(other,power*0.65,a.id);m.interrupt(other,0.6))
		5:
			if evolution==2:
				flight_line(m,a,group,power*1.52,"wave")
				m.later(0.36,func():flight_line(m,a,m.living(side),power*0.6,"wave"))
			else:
				for flank in [-1,1]:flight_line(m,a,m.living(flank),power*0.85,"wave")
				if evolution==1:m.later(0.46,func():
					for flank in [-1,1]:flight_line(m,a,m.living(flank),power*0.72,"wave",-1,Callable(),true))
		6:
			m.fly(m.actor_pos(a)-Vector2(0,30),m.enemy_pos(e)-Vector2(0,15),"stone",6,0.29,func():
				if m.alive(e):e.sticky=power*1.7;e.sticky_mode=evolution;m.fx(m.enemy_pos(e),"ring","f98abb",0.3),false,e.uid)
		7,10:
			var route=m.living() if a.kit==7 and evolution==1 else group.duplicate()
			if route.is_empty():return true
			var targets=[]
			for i in 3:
				if i<route.size():targets.append(route[i])
				elif a.kit==7 and evolution==2:targets.append(route[0])
			for i in targets.size():
				var hit=targets[i];var origin=m.actor_pos(a)-Vector2(0,24) if i==0 else m.enemy_pos(targets[i-1])-Vector2(0,20)
				m.later(i*0.16,func():m.fly(origin,m.enemy_pos(hit)-Vector2(0,20),"arc" if a.kit==10 else "stone",a.kit,0.17,func():
					m.hurt(hit,power*(0.9 if i==0 else 0.7),a.id)
					if a.kit==10 and evolution==1 and i==targets.size()-1 and m.alive(hit):hit.silence=3;m.interrupt(hit,1.0),false,hit.uid))
			if a.kit==10 and evolution==2:m.later(0.6,func():m.hurt(route[0],power*0.8,a.id,true))
		8:
			flight_line(m,a,group,power,"stone",-1,func(hit):m.push(hit,0.17))
			if evolution==1:zone(m,"wall",side,power,0,3.6,a.id)
			elif evolution==2 and not group.is_empty():m.later(0.5,func():m.hurt(group.back(),power*1.3,a.id))
		9:
			for flank in ([-1,1] if evolution==2 else [side]):
				for hit in m.living(flank):hit.root=4.2 if evolution else 3.0;m.hurt(hit,power*0.74,a.id)
				zone(m,"roots",flank,power,evolution,4.2 if evolution else 3.0,a.id)
		11:
			for hit in group:
				if evolution==1:hit.p=(group[0].p+group.back().p)*0.45
				else:m.push(hit,0.27)
				hit.slow=2.4
			flight_line(m,a,group,power,"gust")
			if evolution==2:m.gust_time=3.5
		12:
			flight_line(m,a,group,power*0.7,"book")
			m.later(0.55,func():flight_line(m,a,m.living(side),power*0.84,"bookback",-1,func(hit):
				if evolution==1:hit.silence=3.1;m.interrupt(hit,1.0)
				elif evolution==2:
					for other in m.living(-side):
						if other.book>=2:m.hurt(other,power*0.5,a.id,true);break
			,true))
		13:
			if evolution==2:e.armor=0;e.shield=0
			m.push(e,0.22);m.interrupt(e,1.1);m.hurt(e,power,a.id);a.haste=3
			for i in mini(group.size()-1,3 if evolution==1 else 1):
				var hit=group[i+1]
				m.later(0.13*(i+1),func():m.hurt(hit,power*0.8,a.id);m.push(hit,0.13);m.interrupt(hit,0.7))
		14:
			m.ward_time=4.6 if evolution else 3.4;m.ward_mode=evolution;m.caught_shot=0
			if a.id==18:m.heal(5+2*int(m.meta.bond))
			m.fx(Vector2(180,320),"ring","f6da94",0.6)
		15:zone(m,"fire",side,power,evolution,4.7 if evolution else 3.7,a.id)
		16:
			for flank in ([-1,1] if evolution==1 else [side]):zone(m,"copy",flank,power,evolution,4.4,a.id)
		17:
			var fragments=e.shield;e.shield=0;e.armor=0;m.hurt(e,power*1.15,a.id,true)
			for other in group:
				if other.uid!=e.uid:m.hurt(other,power*0.68+(fragments if evolution==1 else 0),a.id)
			if evolution==2:m.barrier+=6+fragments
	return true
