extends Control

# The first playable region deliberately keeps the combat rules in one place.
# Sprite sheets are 16 px frames; rows are animation and columns are direction.
const HERO = preload("res://assets/ninja_1.png")
const FLOOR = preload("res://assets/kenney_tiny_dungeon.png")
const SPIDER = preload("res://assets/monster_SpiderRed.png")
const SKULL = preload("res://assets/monster_Skull.png")
const SPIRIT = preload("res://assets/monster_Spirit.png")
const BOSS = preload("res://assets/monster_Cyclope.png")
const SAVE = "user://last_bastion_v1.json"
const MAX_TOWERS = 4
const LANES = [90.0, 180.0, 270.0]
const PADS = [Vector2(48, 176), Vector2(137, 176), Vector2(223, 176), Vector2(312, 176), Vector2(48, 296), Vector2(137, 296), Vector2(223, 296), Vector2(312, 296), Vector2(48, 405), Vector2(137, 405), Vector2(223, 405), Vector2(312, 405)]
const BG = Color("111321")
const PANEL = Color("202236")
const INK = Color("d8d8df")
const GOLD = Color("ffc978")
const CYAN = Color("81ddf3")
const ROSE = Color("f1777d")

var wave = 1
var gold = 160
var bastion_hp = 100
var level = 1
var xp = 0
var hero_lane = 1
var hero_x = LANES[1]
var hero_y = 460.0
var hero_action = 0.0
var hero_hit_applied = true
var hero_skill_pending = false
var hero_target = -1
var hero_cooldown = 0.0
var skill_cooldown = 0.0
var state = "prep"
var paused = false
var elapsed = 0.0
var selected_pad = -1
var towers = []
var enemies = []
var shots = []
var particles = []
var spawned = 0
var spawn_goal = 0
var spawn_timer = 0.0
var next_id = 1
var message = "Choose a glowing pad, build a tower, then start wave 1."
var message_timer = 0.0
var rng = RandomNumberGenerator.new()
var buttons = {}
var previous_state = "prep"

func _ready():
    mouse_filter = Control.MOUSE_FILTER_STOP
    rng.randomize()
    _load_game()
    hero_x = LANES[hero_lane]
    _make_ui()
    queue_redraw()

func _notification(what):
    if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
        if is_inside_tree():
            _save_game()
            paused = true

func _make_button(key, caption, rect, action):
    var b = Button.new()
    b.text = caption
    b.position = rect.position
    b.size = rect.size
    b.focus_mode = Control.FOCUS_NONE
    b.add_theme_font_size_override("font_size", 13)
    b.add_theme_color_override("font_color", INK)
    b.add_theme_color_override("font_disabled_color", Color("777886"))
    var normal = StyleBoxFlat.new()
    normal.bg_color = Color("2f344d")
    normal.border_color = Color("69718f")
    normal.set_border_width_all(1)
    normal.set_corner_radius_all(4)
    b.add_theme_stylebox_override("normal", normal)
    var hover = normal.duplicate()
    hover.bg_color = Color("46516a")
    b.add_theme_stylebox_override("hover", hover)
    var press = normal.duplicate()
    press.bg_color = Color("755755")
    b.add_theme_stylebox_override("pressed", press)
    var disabled = normal.duplicate()
    disabled.bg_color = Color("242634")
    disabled.border_color = Color("393b49")
    b.add_theme_stylebox_override("disabled", disabled)
    b.pressed.connect(action)
    add_child(b)
    buttons[key] = b

func _make_ui():
    _make_button("pause", "Ⅱ", Rect2(307, 8, 45, 36), _toggle_pause)
    _make_button("wave", "START WAVE", Rect2(8, 565, 168, 45), _wave_button)
    _make_button("skill", "SHIELD STRIKE", Rect2(184, 565, 168, 45), _use_skill)
    _make_button("archer", "ARCHER 50", Rect2(8, 618, 109, 44), func(): _build("archer"))
    _make_button("frost", "FROST 70", Rect2(125, 618, 109, 44), func(): _build("frost"))
    _make_button("repair", "REPAIR 25", Rect2(242, 618, 110, 44), _repair)
    _make_button("upgrade", "UPGRADE", Rect2(8, 670, 168, 42), _upgrade)
    _make_button("sell", "SELL TOWER", Rect2(184, 670, 168, 42), _sell)
    _refresh_ui()

func _refresh_ui():
    if buttons.is_empty():
        return
    var selected = _tower_on_pad(selected_pad)
    var prep = state == "prep" and not paused
    buttons.pause.text = "▶" if paused else "Ⅱ"
    buttons.wave.disabled = paused or state == "battle" or state == "victory"
    buttons.wave.text = "RETRY WAVE" if state == "failed" else ("REGION CLEARED" if state == "victory" else "START WAVE %d" % wave)
    buttons.skill.disabled = paused or state != "battle" or skill_cooldown > 0.0
    buttons.skill.text = "SHIELD STRIKE  %ds" % int(ceil(skill_cooldown)) if skill_cooldown > 0.0 else "SHIELD STRIKE"
    buttons.archer.disabled = not prep or selected_pad < 0 or not selected.is_empty() or towers.size() >= MAX_TOWERS or gold < 50
    buttons.frost.disabled = not prep or selected_pad < 0 or not selected.is_empty() or towers.size() >= MAX_TOWERS or gold < 70
    buttons.repair.disabled = not prep or gold < 25 or bastion_hp >= 100
    buttons.upgrade.disabled = not prep or selected.is_empty() or selected.get("level", 0) >= 3 or gold < _upgrade_cost(selected)
    buttons.upgrade.text = "UPGRADE  %d" % _upgrade_cost(selected) if not selected.is_empty() and selected.get("level", 0) < 3 else "UPGRADE"
    buttons.sell.disabled = not prep or selected.is_empty()
    buttons.sell.text = "SELL  +%d" % _sell_value(selected) if not selected.is_empty() else "SELL TOWER"

func _tower_on_pad(pad):
    for t in towers:
        if t.pad == pad:
            return t
    return {}

func _upgrade_cost(t):
    if t.is_empty():
        return 0
    return 35 + 20 * int(t.level)

func _sell_value(t):
    if t.is_empty():
        return 0
    return int(floor(float(t.spent) * 0.7))

func _tell(s):
    message = s
    message_timer = 4.0

func _build(kind):
    if paused or state != "prep" or selected_pad < 0 or not _tower_on_pad(selected_pad).is_empty():
        return
    if towers.size() >= MAX_TOWERS:
        _tell("Tower limit reached. Sell a tower to build elsewhere.")
        return
    var cost = 50 if kind == "archer" else 70
    if gold < cost:
        return
    gold -= cost
    towers.append({"pad": selected_pad, "kind": kind, "level": 1, "cooldown": 0.1, "spent": cost})
    _tell("Archer post built." if kind == "archer" else "Frost obelisk built. Slows nearby enemies.")
    _save_game()
    _refresh_ui()

func _upgrade():
    var t = _tower_on_pad(selected_pad)
    if paused or state != "prep" or t.is_empty() or t.level >= 3:
        return
    var price = _upgrade_cost(t)
    if gold >= price:
        gold -= price
        t.level += 1
        t.spent += price
        _tell("Tower upgraded to level %d." % t.level)
        _save_game()
        _refresh_ui()

func _sell():
    var t = _tower_on_pad(selected_pad)
    if paused or state != "prep" or t.is_empty():
        return
    gold += _sell_value(t)
    towers.erase(t)
    _tell("Tower sold. You received 70% of its cost.")
    _save_game()
    _refresh_ui()

func _repair():
    if paused or state != "prep" or gold < 25 or bastion_hp >= 100:
        return
    gold -= 25
    bastion_hp = min(100, bastion_hp + 30)
    _tell("Bastion repaired by 30 HP.")
    _save_game()
    _refresh_ui()

func _toggle_pause():
    paused = not paused
    _tell("Paused." if paused else "Back to the defense!")
    _refresh_ui()

func _wave_button():
    if state == "failed":
        state = "prep"
        bastion_hp = 100
        _tell("Bastion repaired. Prepare to retry the wave.")
        _save_game()
    elif state == "prep":
        _start_wave()
    _refresh_ui()

func _start_wave():
    if paused or state != "prep":
        return
    state = "battle"
    enemies.clear()
    shots.clear()
    spawned = 0
    spawn_goal = 5 + wave * 2
    spawn_timer = 0.4
    hero_cooldown = 0.0
    skill_cooldown = 0.0
    hero_action = 0.0
    hero_hit_applied = true
    hero_skill_pending = false
    selected_pad = -1
    _tell("Wave %d: defend all three lanes!" % wave)
    _save_game()
    _refresh_ui()

func _use_skill():
    if paused or state != "battle" or skill_cooldown > 0.0:
        return
    skill_cooldown = 12.0
    hero_action = 0.42
    hero_hit_applied = false
    hero_skill_pending = true
    _tell("Shield Strike!")
    _refresh_ui()

func _spawn_enemy():
    var kind = "spider"
    if wave >= 2 and spawned % 3 == 1:
        kind = "skull"
    if wave >= 4 and spawned % 5 == 3:
        kind = "spirit"
    if wave == 10 and spawned == 0:
        kind = "boss"
    var lane = spawned % 3 if wave <= 2 else rng.randi_range(0, 2)
    var hp = 34.0 + wave * 10.0
    var speed = 22.0 + min(wave, 8) * 0.8
    var base_damage = 8
    var reward = 9
    if kind == "skull":
        hp *= 1.75
        speed *= 0.74
        base_damage = 13
        reward = 14
    elif kind == "spirit":
        hp *= 0.78
        speed *= 1.45
        reward = 11
    elif kind == "boss":
        hp *= 7.0
        speed *= 0.52
        base_damage = 35
        reward = 65
    enemies.append({"id": next_id, "kind": kind, "lane": lane, "x": LANES[lane], "y": 78.0, "hp": hp, "max_hp": hp, "speed": speed, "damage": base_damage, "gold": reward, "slow": 0.0, "flash": 0.0, "alive": true})
    next_id += 1
    spawned += 1

func _enemy_by_id(id):
    for e in enemies:
        if e.id == id and e.alive:
            return e
    return {}

func _damage_enemy(e, amount, source):
    if e.is_empty() or not e.alive:
        return
    e.hp -= amount
    e.flash = 0.18
    particles.append({"x": e.x, "y": e.y - 18, "life": 0.65, "text": str(int(amount)), "color": CYAN if source == "frost" else GOLD})
    if e.hp <= 0:
        e.alive = false
        gold += int(e.gold)
        xp += 1
        particles.append({"x": e.x, "y": e.y, "life": 0.9, "text": "+%d" % e.gold, "color": GOLD})
        var next_level = level * 8
        if xp >= next_level:
            xp -= next_level
            level += 1
            _tell("Level %d! Shield Strike and sword attacks are stronger." % level)

func _find_target(pos, distance, only_lane = -1):
    var best = {}
    var furthest = -10000.0
    for e in enemies:
        if e.alive and (only_lane < 0 or e.lane == only_lane) and Vector2(e.x, e.y).distance_to(pos) <= distance and e.y > furthest:
            best = e
            furthest = e.y
    return best

func _fire_tower(t, enemy):
    var pos = PADS[int(t.pad)]
    shots.append({"pos": pos + Vector2(0, -10), "target": enemy.id, "kind": t.kind, "damage": (12 + (t.level - 1) * 7) if t.kind == "archer" else (5 + (t.level - 1) * 3), "level": t.level})
    t.cooldown = max(0.45, (0.95 if t.kind == "archer" else 1.45) - (t.level - 1) * 0.12)

func _process(delta):
    if paused:
        queue_redraw()
        return
    delta = min(delta, 0.05)
    elapsed += delta
    message_timer = max(0.0, message_timer - delta)
    if state == "battle":
        _tick_battle(delta)
    elif state == "prep":
        hero_x = move_toward(hero_x, LANES[hero_lane], 160.0 * delta)
    for p in particles:
        p.life -= delta
        p.y -= delta * 18.0
    particles = particles.filter(func(p): return p.life > 0.0)
    _refresh_ui()
    queue_redraw()

func _tick_battle(delta):
    if spawned < spawn_goal:
        spawn_timer -= delta
        if spawn_timer <= 0.0:
            _spawn_enemy()
            spawn_timer = max(0.48, 1.55 - wave * 0.07)
    skill_cooldown = max(0.0, skill_cooldown - delta)
    hero_cooldown = max(0.0, hero_cooldown - delta)
    if hero_action > 0:
        hero_action -= delta
        if not hero_hit_applied and hero_action <= 0.19:
            hero_hit_applied = true
            if hero_skill_pending:
                hero_skill_pending = false
                var hit_count = 0
                for e in enemies:
                    if e.alive and Vector2(e.x, e.y).distance_to(Vector2(hero_x, hero_y)) < 105:
                        _damage_enemy(e, 32 + level * 3, "skill")
                        hit_count += 1
                particles.append({"x": hero_x, "y": hero_y - 14, "life": 0.42, "text": "STRIKE!", "color": GOLD})
                _tell("Shield Strike hit %d enemies!" % hit_count)
            else:
                var target = _enemy_by_id(hero_target)
                if not target.is_empty() and abs(target.y - hero_y) < 66.0 and abs(target.x - hero_x) < 25.0 and target.lane == hero_lane:
                    _damage_enemy(target, 16 + level * 3, "sword")
    hero_x = move_toward(hero_x, LANES[hero_lane], 160.0 * delta)
    var threat = _find_target(Vector2(LANES[hero_lane], 420), 115, hero_lane)
    var desired_y = 460.0
    if not threat.is_empty():
        desired_y = clamp(threat.y + 36.0, 330.0, 460.0)
    hero_y = move_toward(hero_y, desired_y, 75 * delta)
    if not threat.is_empty() and abs(threat.y - hero_y) < 60 and abs(threat.x - hero_x) < 25.0 and hero_cooldown <= 0.0 and hero_action <= 0.0:
        hero_target = threat.id
        hero_action = 0.42
        hero_hit_applied = false
        hero_cooldown = 0.85
    for e in enemies:
        if not e.alive:
            continue
        e.flash = max(0.0, e.flash - delta)
        e.slow = max(0.0, e.slow - delta)
        e.y += e.speed * (0.55 if e.slow > 0 else 1.0) * delta
        if e.y >= 501.0:
            e.alive = false
            bastion_hp = max(0, bastion_hp - int(e.damage))
            particles.append({"x": e.x, "y": 495.0, "life": 0.8, "text": "-%d" % e.damage, "color": ROSE})
            if bastion_hp <= 0:
                _lose_wave()
                return
    for t in towers:
        t.cooldown = max(0.0, t.cooldown - delta)
        if t.cooldown <= 0:
            var target = _find_target(PADS[int(t.pad)], 125.0 + (t.level - 1) * 8.0)
            if not target.is_empty():
                _fire_tower(t, target)
    for s in shots:
        var target = _enemy_by_id(s.target)
        if target.is_empty():
            s.done = true
            continue
        var target_pos = Vector2(target.x, target.y)
        var next = s.pos.move_toward(target_pos, 230 * delta)
        if next.distance_to(target_pos) < 4.0:
            _damage_enemy(target, s.damage, s.kind)
            if s.kind == "frost" and target.alive:
                target.slow = 2.0 + s.level * 0.4
            s.done = true
        else:
            s.pos = next
    shots = shots.filter(func(s): return not s.get("done", false))
    enemies = enemies.filter(func(e): return e.alive)
    if spawned >= spawn_goal and enemies.is_empty():
        _win_wave()

func _lose_wave():
    state = "failed"
    enemies.clear()
    shots.clear()
    _tell("The Bastion fell! Tap RETRY to repair it and prepare again.")
    _save_game()
    _refresh_ui()

func _win_wave():
    gold += 30 + wave * 3
    if wave == 10:
        state = "victory"
        _tell("REGION CLEARED! Ten waves survived. More is coming.")
    else:
        wave += 1
        state = "prep"
        _tell("Wave cleared! Bonus gold earned. Prepare for wave %d." % wave)
    _save_game()
    _refresh_ui()

func _gui_input(event):
    if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        _handle_tap(event.position)
    elif event is InputEventScreenTouch and event.pressed:
        _handle_tap(event.position)

func _handle_tap(pos):
    if paused or pos.y < 70 or pos.y > 530:
        return
    if state == "prep":
        for i in range(PADS.size()):
            if pos.distance_to(PADS[i]) <= 25.0:
                selected_pad = i
                var t = _tower_on_pad(i)
                if t.is_empty():
                    _tell("Tower limit reached. Sell a tower to build elsewhere." if towers.size() >= MAX_TOWERS else "Empty pad: choose a tower. %d/%d placed." % [towers.size(), MAX_TOWERS])
                else:
                    _tell("%s • level %d • range %d" % [t.kind.capitalize(), t.level, 125 + (t.level - 1) * 8])
                _refresh_ui()
                queue_redraw()
                return
    if pos.y >= 420 and pos.y <= 515 and (state == "battle" or state == "prep"):
        var lane = 0
        var nearest = 999.0
        for i in range(3):
            if abs(pos.x - LANES[i]) < nearest:
                nearest = abs(pos.x - LANES[i])
                lane = i
        hero_lane = lane
        _tell("Knight assigned to lane %d." % (lane + 1))
        if state == "prep":
            _save_game()
        queue_redraw()

func _save_game():
    var data = {"version": 1, "wave": wave, "gold": gold, "bastion_hp": bastion_hp, "level": level, "xp": xp, "hero_lane": hero_lane, "towers": towers, "victory": state == "victory"}
    var file = FileAccess.open(SAVE, FileAccess.WRITE)
    if file:
        file.store_string(JSON.stringify(data))

func _load_game():
    if not FileAccess.file_exists(SAVE):
        return
    var file = FileAccess.open(SAVE, FileAccess.READ)
    if not file:
        return
    var data = JSON.parse_string(file.get_as_text())
    if not data is Dictionary or int(data.get("version", 0)) != 1:
        return
    wave = clampi(int(data.get("wave", 1)), 1, 10)
    gold = maxi(0, int(data.get("gold", 160)))
    bastion_hp = clampi(int(data.get("bastion_hp", 100)), 0, 100)
    level = maxi(1, int(data.get("level", 1)))
    xp = maxi(0, int(data.get("xp", 0)))
    hero_lane = clampi(int(data.get("hero_lane", 1)), 0, 2)
    var saved_towers = data.get("towers", [])
    if saved_towers is Array:
        for t in saved_towers:
            if t is Dictionary and int(t.get("pad", -1)) >= 0 and int(t.get("pad", -1)) < PADS.size() and t.get("kind", "") in ["archer", "frost"]:
                towers.append({"pad": int(t.pad), "kind": t.kind, "level": clampi(int(t.get("level", 1)), 1, 3), "cooldown": 0.1, "spent": maxi(0, int(t.get("spent", 50)))})
    if data.get("victory", false):
        state = "victory"
        message = "Region cleared! Thank you for playing the preview."
    elif bastion_hp <= 0:
        state = "failed"
        message = "The Bastion fell. Tap RETRY to repair it."
    else:
        message = "Welcome back. Prepare for wave %d." % wave

func _draw_tile(index, dst):
    var col = index % 12
    var row = int(index / 12)
    draw_texture_rect_region(FLOOR, dst, Rect2(col * 16, row * 16, 16, 16))

func _draw_sprite(tex, col, row, center, size, tint = Color.WHITE):
    draw_texture_rect_region(tex, Rect2(center.x - size / 2.0, center.y - size / 2.0, size, size), Rect2(col * 16, row * 16, 16, 16), tint)

func _label(pos, text, size = 13, color = INK, width = -1.0, align = HORIZONTAL_ALIGNMENT_LEFT):
    draw_string(ThemeDB.fallback_font, pos, text, align, width, size, color)

func _draw():
    draw_rect(Rect2(0, 0, 360, 720), BG)
    draw_rect(Rect2(0, 0, 360, 64), Color("202335"))
    _label(Vector2(10, 21), "LAST BASTION", 15, GOLD)
    _label(Vector2(10, 43), "WAVE %d/10  •  KNIGHT Lv.%d" % [wave, level], 12, INK)
    _label(Vector2(190, 21), "G  %d" % gold, 14, GOLD)
    _label(Vector2(190, 43), "BASE  %d/100" % bastion_hp, 12, ROSE)
    draw_rect(Rect2(0, 64, 360, 2), Color("80675b"))
    draw_rect(Rect2(0, 66, 360, 469), Color("272a36"))
    # Subtle cobbles and three distinct, continuous enemy routes.
    for y in range(70, 526, 32):
        for x in range(0, 360, 32):
            var col = Color("2e303c") if (int(x / 32) + int(y / 32)) % 2 == 0 else Color("30323e")
            draw_rect(Rect2(x, y, 31, 31), col)
            draw_line(Vector2(x + 5, y + 23), Vector2(x + 12, y + 23), Color("383944"), 1)
    for lane_x in LANES:
        draw_rect(Rect2(lane_x - 25, 68, 50, 435), Color(0.16, 0.17, 0.21, 0.65))
        draw_line(Vector2(lane_x - 25, 68), Vector2(lane_x - 25, 500), Color("48434b"), 1)
        draw_line(Vector2(lane_x + 25, 68), Vector2(lane_x + 25, 500), Color("48434b"), 1)
        _label(Vector2(lane_x - 8, 90), "↓", 16, Color("d68178"))
    # The caravan wall is made of Kenney CC0 dungeon tiles.
    for i in range(12):
        _draw_tile(40, Rect2(i * 32, 502, 32, 32))
    _draw_tile(44, Rect2(164, 492, 32, 32))
    _label(Vector2(127, 528), "THE BASTION", 10, INK)
    for i in range(PADS.size()):
        var p = PADS[i]
        var occupied = _tower_on_pad(i)
        var pcolor = Color("ddb785") if i == selected_pad else Color("768083")
        draw_rect(Rect2(p - Vector2(18, 12), Vector2(36, 24)), Color("333642"))
        draw_rect(Rect2(p - Vector2(18, 12), Vector2(36, 24)), pcolor, false, 1.0)
        if occupied.is_empty():
            if state == "prep":
                _label(p + Vector2(-4, 5), "+", 15, pcolor)
        else:
            var tile_id = 74 if occupied.kind == "archer" else 44
            _draw_tile(tile_id, Rect2(p.x - 18, p.y - 30, 36, 36))
            _label(p + Vector2(-4, 17), str(occupied.level), 10, GOLD)
            if i == selected_pad and state == "prep":
                draw_arc(p, 125 + (occupied.level - 1) * 8, 0, TAU, 42, Color(0.75, 0.85, 0.92, 0.32), 1)
    for e in enemies:
        if not e.alive:
            continue
        var tex = SPIDER
        if e.kind == "skull": tex = SKULL
        if e.kind == "spirit": tex = SPIRIT
        if e.kind == "boss": tex = BOSS
        var spr_size = 52 if e.kind == "boss" else 36
        var walk_row = int(elapsed * 7 + e.id) % 4
        _draw_sprite(tex, 0, walk_row, Vector2(e.x, e.y), spr_size, Color(2, 2, 2) if e.flash > 0 else Color.WHITE)
        draw_rect(Rect2(e.x - 16, e.y - spr_size / 2.0 - 7, 32, 4), Color("412a35"))
        draw_rect(Rect2(e.x - 16, e.y - spr_size / 2.0 - 7, 32 * max(0, e.hp / e.max_hp), 4), CYAN if e.slow > 0 else ROSE)
    var moving_sideways = abs(hero_x - LANES[hero_lane]) > 2.0
    var hrow = int(elapsed * 5) % 4 if moving_sideways or (state == "battle" and abs(hero_y - 460) > 2) else 0
    if hero_action > 0:
        hrow = 4 if hero_action > 0.21 else 5
    var hcol = (3 if hero_x < LANES[hero_lane] else 2) if moving_sideways else 1
    _draw_sprite(HERO, hcol, hrow, Vector2(hero_x, hero_y), 48)
    if hero_action > 0.11 and hero_action < 0.28:
        draw_arc(Vector2(hero_x, hero_y - 8), 26, PI * 1.05, PI * 1.95, 14, Color("f6e7b8"), 3)
    for s in shots:
        draw_circle(s.pos, 4 if s.kind == "frost" else 2, CYAN if s.kind == "frost" else GOLD)
        draw_line(s.pos + Vector2(0, 7), s.pos, CYAN if s.kind == "frost" else GOLD, 2)
    for p in particles:
        _label(Vector2(p.x - 10, p.y), p.text, 12, p.color)
    draw_rect(Rect2(0, 535, 360, 25), Color("1b1d2b"))
    _label(Vector2(7, 552), message, 11, Color("e3d4bc"), 346)
    if paused:
        draw_rect(Rect2(55, 238, 250, 92), Color(0.06, 0.07, 0.1, 0.92))
        _label(Vector2(55, 277), "PAUSED", 24, GOLD, 250, HORIZONTAL_ALIGNMENT_CENTER)
        _label(Vector2(55, 303), "Tap ▶ to resume", 13, INK, 250, HORIZONTAL_ALIGNMENT_CENTER)
    elif state == "victory":
        draw_rect(Rect2(35, 225, 290, 98), Color(0.06, 0.07, 0.1, 0.94))
        _label(Vector2(35, 264), "REGION CLEARED", 22, GOLD, 290, HORIZONTAL_ALIGNMENT_CENTER)
        _label(Vector2(35, 292), "You defended the Bastion!", 13, INK, 290, HORIZONTAL_ALIGNMENT_CENTER)
