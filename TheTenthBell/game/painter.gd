extends Node2D
const Book=preload("res://data/roster.gd")
const INK=Color("101d29")
const PANEL=Color("203441")
const RIM=Color("52666c")
const CREAM=Color("f6e7c7")
const GOLD=Color("efb86b")
const MINT=Color("88d6c2")
const MUTED=Color("b8c8c3")
const CORAL=Color("fa9b83")
var off=Vector2.ZERO
var boundaries=[]
var fonts=[]
var atlases=[]
var missiles={}
var frames=[]
var scenes=[]
var foe_sheet
func prepare_art():
	fonts=[load("res://art/fonts/Pixelify.ttf"),load("res://art/fonts/Jersey10.ttf")]
	frames=JSON.parse_string(FileAccess.get_file_as_string("res://cast/frames.json"))
	for id in 18:
		atlases.append(load("res://cast/h%02d.png"%id))
		if ResourceLoader.exists("res://cast/p%02d.png"%id):missiles[id]=load("res://cast/p%02d.png"%id)
	for id in 4:scenes.append(load("res://art/station%d.png"%id))
	foe_sheet=load("res://art/enemies.png")
func plate(r,fill=PANEL,edge=RIM):
	draw_rect(Rect2(r.position+Vector2(0,3),r.size),INK)
	draw_rect(Rect2(r.position+Vector2(2,0),r.size-Vector2(4,0)),edge)
	draw_rect(Rect2(r.position+Vector2(0,2),r.size-Vector2(0,4)),edge)
	draw_rect(Rect2(r.position+Vector2(2,2),r.size-Vector2(4,4)),fill)
	draw_line(r.position+Vector2(5,3),r.position+Vector2(r.size.x-6,3),edge.lightened(0.12))
func words(text,p,size=14,color=CREAM,title=false):
	draw_string(fonts[1 if title else 0],p,str(text),HORIZONTAL_ALIGNMENT_LEFT,-1,size,color)
func mid(text,y,size=18,color=CREAM,title=false,x=180):
	var width=fonts[1 if title else 0].get_string_size(str(text),HORIZONTAL_ALIGNMENT_LEFT,-1,size).x
	words(text,Vector2(round(x-width/2),y),size,color,title)
func paragraph(text,p,width,size=13,color=MUTED,line_height=17):
	var line="";var y=p.y
	for word in str(text).split(" "):
		var candidate=word if line=="" else line+" "+word
		if fonts[0].get_string_size(candidate,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x>width and line!="":words(line,Vector2(p.x,y),size,color);y+=line_height;line=word
		else:line=candidate
	if line!="":words(line,Vector2(p.x,y),size,color)
	return y+line_height
func button(r,label,command,accent=false,enabled=true,size=19):
	plate(r,Color("34564e") if accent else PANEL,GOLD if accent else RIM)
	var color=CREAM if enabled else RIM
	mid(label,r.position.y+r.size.y/2+size*.32,size,color,true,r.position.x+r.size.x/2)
	if enabled:boundaries.append([r,command])
func meter(r,value,color):
	draw_rect(r,INK);draw_rect(Rect2(r.position+Vector2.ONE,r.size-Vector2(2,2)),RIM)
	draw_rect(Rect2(r.position+Vector2.ONE,Vector2(maxf(0,(r.size.x-2)*clampf(value,0,1)),r.size.y-2)),color)
func hero(id,feet,time,state="idle",scale_amount=1.0,face=1,tint=Color.WHITE,progress=-1.0):
	var which=14 if id==18 else int(id)
	if which<0 or which>=atlases.size():return
	var states=frames[which]
	if not states.has(state):state="idle"
	var entry=states[state]
	var n=int(entry[1]);var index=int(entry[0])+clampi(int(progress*n) if progress>=0 else int(time*(8 if state=="idle" else 12))%n,0,n-1)
	draw_set_transform(off+feet,0,Vector2(scale_amount*face,scale_amount))
	draw_texture_rect_region(atlases[which],Rect2(-62,-72,136,84),Rect2((index%8)*136,int(index/8.0)*84,136,84),Color("b1e3e1") if id==18 else tint)
	draw_set_transform(off)
func enemy(e,m,t):
	var p=m.enemy_pos(e);var s=1.24 if e.kind==5 else (0.94 if e.elite else 0.8)
	var cell=int(t*8)%6 if e.wind<0 and e.stun<=0 else 0
	draw_set_transform(off+p,0,Vector2(s*(-e.side),s))
	draw_texture_rect_region(foe_sheet,Rect2(-24,-49,48,58),Rect2(cell*48,int(e.kind)*58,48,58),Color(2,1.5,1.2) if e.flash>0 else Color.WHITE)
	draw_set_transform(off)
	meter(Rect2(p.x-13,p.y-44*s,26,3),e.hp/e.max,CORAL if e.kind!=5 else GOLD)
	if e.shield>0:draw_line(p+Vector2(-13,-47*s),p+Vector2(13,-47*s),MINT,2)
	if e.wind>=0:
		var color=CORAL if e.wind<=.46 else GOLD
		draw_arc(p-Vector2(0,22),20,-PI/2,-PI/2+TAU*(1-e.wind/e.windmax),18,color,2)
		words("!",p+Vector2(-3,-55*s),17,color,true)
	if e.sticky>0:draw_rect(Rect2(p-Vector2(3,32),Vector2(6,6)),Color("f28ab9"))
	if e.book>=2:words("II",p+Vector2(12,-30),11,GOLD)
	if e.root>0:draw_line(p-Vector2(12,1),p+Vector2(12,-1),MINT,3)
	if e.burn>0:draw_line(p+Vector2(-9,-4),p+Vector2(-7,-12),CORAL,3)
	if e.uid==m.focus:draw_arc(p-Vector2(0,20),24,0,TAU,16,CREAM,1)
func scenery(region,t,reduced=false):
	draw_rect(Rect2(-off, get_viewport_rect().size),INK)
	draw_texture(scenes[region%4],Vector2.ZERO)
	if not reduced:
		for i in 9:
			var p=Vector2(fmod(i*43+sin(t*.3+i)*7,350)+5,142+fmod(i*19+t*3,210))
			draw_rect(Rect2(p,Vector2(1,2)),Color(GOLD,.4))
func combat_scene(m,reduced=false):
	var t=m.clock
	for z in m.areas:
		var p=Vector2(180+z.side*94,282)
		match z.kind:
			"fire","roots":
				for i in 8:
					var q=Vector2(180+z.side*(43+i*14),327-i*12)
					draw_line(q,q-Vector2(2,6+int(t*7+i)%5),CORAL if z.kind=="fire" else MINT,3)
			"wall":plate(Rect2(p+Vector2(-14,6),Vector2(29,18)),RIM,GOLD)
			"copy":hero(m.lead,Vector2(180+z.side*70,332),t,"attack",.72, -z.side,Color(1,1,1,.4))
	if m.rescue_spawned and not m.rescue_done:
		hero(18,Vector2(80,278),t,"hurt",.62)
		words("SAVE IRIS",Vector2(43,230),11,GOLD)
		meter(Rect2(52,237,48,4),m.rescue_health/3.0,MINT)
	for e in m.enemies:
		if e.hp>0:enemy(e,m,t)
	for a in m.actors:
		var p=m.actor_pos(a)
		draw_ellipse_shadow(p,15 if a.slot<0 else 10)
		hero(a.id,p,t,a.state if a.anim>0 else "idle",1.0 if a.slot<0 else .78,a.face,Color.WHITE,1.0-a.anim/a.anim_len if a.anim>0 else -1)
	if m.guard_time>0 or m.ward_time>0 or m.barrier>0:draw_arc(Vector2(180,320),30,0,TAU,16,Color(MINT,.6),2)
	for s in m.shots:
		var f=clampf(s.age/s.life,0,1);var p=s.a.lerp(s.b,f)
		if s.kind in ["book","bookback","stone"]:p.y-=sin(f*PI)*16
		if s.kind=="arc":
			draw_polyline(PackedVector2Array([s.a,s.a.lerp(s.b,.4)+Vector2(3,-8),s.a.lerp(s.b,.6)+Vector2(-3,8),p]),Color("c8bbff"),2)
		elif missiles.has(int(s.owner)) and s.kind=="basic":
			var tex=missiles[int(s.owner)];var cells=int(tex.get_width()/36.0)
			draw_texture_rect_region(tex,Rect2(p-Vector2(18,18),Vector2(36,36)),Rect2(int(t*12)%cells*36,0,36,36))
		elif s.kind in ["book","bookback"]:
			draw_set_transform(off+p,(f*TAU if not reduced else 0));plate(Rect2(-6,-5,12,10),GOLD,CREAM);draw_set_transform(off)
		else:
			draw_line(p-(s.b-s.a).normalized()*10,p,CORAL if s.enemy else MINT,3)
			draw_rect(Rect2(p-Vector2(2,2),Vector2(4,4)),CREAM)
	for item in m.effects:
		var f=item.age/item.life;var p=item.p;var c=Color(item.color);c.a=1-f
		match item.kind:
			"number":words(item.text,p-Vector2(0,f*18),14,c,true)
			"ring":draw_arc(p,8+f*76,0,TAU,28,c,2)
			"shadow":hero(3,p,t,"attack",1,1,c)
			_:
				for i in 5:
					var q=p+Vector2.from_angle(i*TAU/5)*(3+f*17)
					draw_rect(Rect2(q,Vector2(3,3)),c)
func draw_ellipse_shadow(p,r):
	draw_rect(Rect2(p-Vector2(r,1),Vector2(r*2,3)),Color(INK,.65))
func cart(t):
	for x in [55,119]:draw_circle(Vector2(x,285),10,INK);draw_circle(Vector2(x,285),6,GOLD);draw_line(Vector2(x-5,285),Vector2(x+5,285),INK,2)
	plate(Rect2(35,251,110,29),Color("6e574b"),GOLD)
	for x in [40,133]:draw_rect(Rect2(x,213,4,40),GOLD)
	for i in 7:draw_rect(Rect2(31+i*17,211,17,14),CORAL if i%2==0 else CREAM)
	draw_line(Vector2(31,209),Vector2(150,209),INK,3)
	hero(18,Vector2(89,264),t,"idle",.82)
