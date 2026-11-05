extends SceneTree

# Exercise complete fights, projectiles and purchases with a simple deterministic
# strategy. This complements the focused rule tests in test_game.gd.
func _initialize():
    call_deferred("run_test")

func run_test():
    DirAccess.remove_absolute(ProjectSettings.globalize_path("user://last_bastion_v1.json"))
    var game = load("res://scripts/game.gd").new()
    root.add_child(game)
    await process_frame
    game.rng.seed = 123456
    var preferred_pads = [5, 6, 9, 10, 1, 2, 4, 7, 8, 11, 0, 3]
    var won = true
    for round_number in range(1, 11):
        if game.bastion_hp <= 70 and game.gold >= 25:
            game._repair()
        for pad in preferred_pads:
            if game.gold >= 50 and game._tower_on_pad(pad).is_empty():
                game.selected_pad = pad
                game._build("archer")
        for t in game.towers:
            game.selected_pad = t.pad
            if t.level < 3 and game.gold >= game._upgrade_cost(t):
                game._upgrade()
        game._start_wave()
        var steps = 0
        while game.state == "battle" and steps < 4000:
            var most_dangerous = {}
            for enemy in game.enemies:
                if enemy.alive and (most_dangerous.is_empty() or enemy.y > most_dangerous.y):
                    most_dangerous = enemy
            if not most_dangerous.is_empty() and most_dangerous.y > 320:
                game.hero_lane = most_dangerous.lane
            if game.skill_cooldown <= 0 and not game._find_target(Vector2(game.hero_x, game.hero_y), 95).is_empty():
                game._use_skill()
            game._tick_battle(0.05)
            steps += 1
        print("Wave %d: state=%s, base=%d, gold=%d, towers=%d, ticks=%d" % [round_number, game.state, game.bastion_hp, game.gold, game.towers.size(), steps])
        if game.state == "failed" or game.state == "battle":
            won = false
            break
    if game.state != "victory":
        won = false
    game.queue_free()
    await process_frame
    DirAccess.remove_absolute(ProjectSettings.globalize_path("user://last_bastion_v1.json"))
    print("FULL REGION TEST: ", "PASS" if won else "FAIL")
    quit(0 if won else 1)
