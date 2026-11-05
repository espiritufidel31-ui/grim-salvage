extends SceneTree

var failures = 0

func check(condition, description):
    if condition:
        print("PASS: ", description)
    else:
        push_error("FAIL: " + description)
        failures += 1

func _initialize():
    call_deferred("run_tests")

func run_tests():
    DirAccess.remove_absolute(ProjectSettings.globalize_path("user://last_bastion_v1.json"))
    var script = load("res://scripts/game.gd")
    check(script != null, "game script parses")
    if script == null:
        quit(1)
        return
    var game = script.new()
    root.add_child(game)
    await process_frame
    check(game.gold == 160 and game.state == "prep", "fresh game starts in preparation")
    game.selected_pad = 0
    game._build("archer")
    check(game.gold == 110 and game.towers.size() == 1, "archer costs 50 gold")
    game._upgrade()
    check(game.towers[0].level == 2 and game.gold == 55, "tower upgrades and charges the listed cost")
    game._sell()
    check(game.towers.is_empty() and game.gold == 128, "selling refunds 70 percent of total cost")
    game.selected_pad = 5
    game._build("frost")
    check(game.gold == 58 and game.towers[0].kind == "frost", "frost tower placement")
    game._save_game()
    game.queue_free()
    await process_frame
    game = script.new()
    root.add_child(game)
    await process_frame
    check(game.gold == 58 and game.towers.size() == 1 and game.towers[0].kind == "frost", "save reload restores resources and towers")
    game.gold = 1000
    for pad in [0, 1, 2]:
        game.selected_pad = pad
        game._build("archer")
    var gold_at_limit = game.gold
    game.selected_pad = 3
    game._build("archer")
    check(game.towers.size() == game.MAX_TOWERS and game.gold == gold_at_limit, "tower limit prevents purchases without charging gold")
    game.towers = [game.towers[0]]
    game.gold = 58
    game._start_wave()
    game.hero_lane = 0
    var previous_x = game.hero_x
    game._tick_battle(0.05)
    check(game.hero_x < previous_x and game.hero_x > game.LANES[0], "knight moves between lanes instead of teleporting")
    game._spawn_enemy()
    check(game.state == "battle" and game.enemies.size() == 1, "wave spawns an actual enemy")
    var enemy = game.enemies[0]
    enemy.x = game.hero_x
    enemy.y = game.hero_y - 30
    enemy.lane = game.hero_lane
    var enemy_hp = enemy.hp
    game._use_skill()
    check(enemy.hp == enemy_hp, "shield strike has anticipation before impact")
    game._tick_battle(0.30)
    check(enemy.hp < enemy_hp, "shield strike deals damage at impact")
    var gold_before = game.gold
    game._damage_enemy(enemy, 9999, "test")
    check(not enemy.alive and game.gold > gold_before and game.xp == 1, "defeating enemy grants rewards exactly once")
    var gold_after = game.gold
    game._damage_enemy(enemy, 9999, "test")
    check(game.gold == gold_after, "a defeated enemy cannot pay twice")
    game.enemies.clear()
    game.spawned = game.spawn_goal
    game._tick_battle(0.01)
    check(game.state == "prep" and game.wave == 2, "clearing a wave advances progress")
    game._start_wave()
    game._spawn_enemy()
    game.enemies[0].y = 501
    game.bastion_hp = 1
    game._tick_battle(0.01)
    check(game.state == "failed" and game.bastion_hp == 0, "Bastion loss transitions to retry state")
    game._wave_button()
    check(game.state == "prep" and game.bastion_hp == 100 and game.wave == 2, "retry restores base without skipping wave")
    game.wave = 10
    game.state = "battle"
    game._win_wave()
    check(game.state == "victory", "wave ten completes the region")
    game.queue_free()
    await process_frame
    DirAccess.remove_absolute(ProjectSettings.globalize_path("user://last_bastion_v1.json"))
    print("TEST RESULT: %d failure(s)" % failures)
    quit(1 if failures else 0)
