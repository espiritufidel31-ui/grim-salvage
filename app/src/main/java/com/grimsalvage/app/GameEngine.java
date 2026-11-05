package com.grimsalvage.app;

import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.io.DataInputStream;
import java.io.DataOutputStream;
import java.io.IOException;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashSet;
import java.util.List;
import java.util.Random;
import java.util.Set;
import java.util.Base64;

/** The deterministic, Android-free rules and save model for Grim Salvage. */
public final class GameEngine {
    public static final int ROTLING = 0;
    public static final int BONECRAWLER = 1;
    public static final int VENOM_SPIDER = 2;
    public static final int HOLLOW_HOUND = 3;
    public static final int IRON_BRUTE = 4;
    public static final int VENOM_MATRIARCH = 5;

    public static final int EVENT_NONE = 0;
    public static final int EVENT_HIT = 1;
    public static final int EVENT_KILL = 2;
    public static final int EVENT_RARE_LOOT = 3;
    public static final int EVENT_BOSS = 4;
    public static final int EVENT_UPGRADE = 5;
    public static final int EVENT_CRAFT = 6;

    private static final int SAVE_VERSION = 3;
    private static final int MAX_OFFLINE_SECONDS = 2 * 60 * 60;
    private static final int MAX_SAVE_CHARS = 32_000;
    private static final int MAX_ENEMIES = 4;

    public static final MaterialInfo[] MATERIALS = {
            new MaterialInfo("rotten_flesh", "Rotten Flesh", Rarity.COMMON, "A foul, sellable scrap.", 3),
            new MaterialInfo("mutated_heart", "Mutated Heart", Rarity.UNCOMMON, "A pulsing organ with strange vitality.", 12),
            new MaterialInfo("bone_fragments", "Bone Fragments", Rarity.COMMON, "Useful for rough weapons.", 4),
            new MaterialInfo("hardened_skull", "Hardened Skull", Rarity.UNCOMMON, "A dense armored trophy.", 13),
            new MaterialInfo("spider_silk", "Spider Silk", Rarity.UNCOMMON, "Tough fiber for light armor.", 8),
            new MaterialInfo("venom_gland", "Venom Gland", Rarity.RARE, "Can graft a venomous attack.", 18),
            new MaterialInfo("sharp_fang", "Sharp Fang", Rarity.COMMON, "A polished predator's tooth.", 6),
            new MaterialInfo("beast_heart", "Beast Heart", Rarity.RARE, "A stubborn, regenerative organ.", 22),
            new MaterialInfo("iron_bone", "Iron Bone", Rarity.EPIC, "A metal-rich bone, prized by smiths.", 28),
            new MaterialInfo("reinforced_muscle", "Reinforced Muscle", Rarity.EPIC, "A dense bundle of monster tissue.", 32),
            new MaterialInfo("predator_eye", "Predator Eye", Rarity.EPIC, "A keen eye that can be grafted.", 35),
            new MaterialInfo("matriarch_core", "Matriarch Core", Rarity.LEGENDARY, "The Venom Matriarch's guaranteed core.", 125)
    };

    public static final GearInfo[] GEAR = {
            new GearInfo("bone_sword", "Bone Sword", "weapon", "ATK +5", "bone_fragments", 3, 80),
            new GearInfo("silk_vest", "Silk Vest", "armor", "MAX HP +35", "spider_silk", 3, 100),
            new GearInfo("fang_necklace", "Fang Necklace", "accessory", "CRIT +8%", "sharp_fang", 2, 125)
    };

    public static final GraftInfo[] GRAFTS = {
            new GraftInfo("venom_gland", "Venom Gland", "20% chance to poison for 3 seconds."),
            new GraftInfo("reinforced_muscle", "Reinforced Muscle", "ATK +25%; attack speed -10%."),
            new GraftInfo("beast_heart", "Hollow Heart", "Restore 5% max HP after each kill."),
            new GraftInfo("predator_eye", "Predator Eyes", "Critical chance +10%."),
            new GraftInfo("iron_bone", "Iron Bone", "DEF +5; attack speed -5%.")
    };

    private final Random random;
    private final ArrayList<Enemy> enemies = new ArrayList<>();
    private final FloatingText[] floatingTexts = new FloatingText[12];
    private final int[] materialCounts = new int[MATERIALS.length];
    private final boolean[] ownedGear = new boolean[GEAR.length];
    private final boolean[] unlockedGrafts = new boolean[GRAFTS.length];
    private final Contract[] contracts = new Contract[3];

    public long coins = 30;
    public int wave = 1;
    public long totalKills;
    public int level = 1;
    public int deaths;
    public int attackLevel;
    public int hpLevel;
    public int defenseLevel;
    public int speedLevel;
    public int critLevel;
    public boolean maleAppearance;
    public boolean soundEnabled = true;
    public boolean musicEnabled;
    public boolean lowPerformance;
    public float hp;
    public String recentLoot = "";
    public int recentLootRarity;
    public float lootNoticeSeconds;
    public String equippedWeapon = "";
    public String equippedArmor = "";
    public String equippedAccessory = "";
    public int equippedGraft = -1;
    public long lastSavedAtMillis;
    public boolean offlinePending;
    public long offlineRewardCoins;
    public int offlineSeconds;
    public int[] offlineRewardMaterials = new int[MATERIALS.length];

    private int waveKills;
    private int bossDefeatedAtWave;
    private int deathsWhenBossSpawned;
    private float spawnTimer = 1.0f;
    private float attackTimer;
    private float reviveTimer;
    private float attackPulse;
    private float poisonTimer;
    private int poisonDamage;
    private int eventCode;
    private int eventSerial;
    private int textCursor;
    private float simTime;

    public GameEngine() { this(System.nanoTime()); }

    public GameEngine(long seed) {
        random = new Random(seed);
        hp = getMaxHp();
        contracts[0] = new Contract("rotlings", "Cull the Rot", "Defeat Rotlings", 30, 120);
        contracts[1] = new Contract("silk", "Silk Harvest", "Collect Spider Silk", 10, 150);
        contracts[2] = new Contract("boss", "No Loose Ends", "Defeat a boss without dying", 1, 250);
        for (int i = 0; i < floatingTexts.length; i++) floatingTexts[i] = new FloatingText();
    }

    public int enemyCount() { return enemies.size(); }
    public Enemy enemyAt(int index) { return enemies.get(index); }
    public FloatingText floatingTextAt(int index) { return floatingTexts[index]; }
    public Contract contractAt(int index) { return contracts[index]; }
    public int materialCount(String id) { int i = materialIndex(id); return i < 0 ? 0 : materialCounts[i]; }
    public boolean ownsGear(String id) { int i = gearIndex(id); return i >= 0 && ownedGear[i]; }
    public boolean hasGraft(String id) { int i = graftIndex(id); return i >= 0 && unlockedGrafts[i]; }
    public boolean isGraftEquipped(String id) { int i = graftIndex(id); return equippedGraft == i; }
    public int getEventCode() { return eventCode; }
    public int getEventSerial() { return eventSerial; }
    public float getAttackPulse() { return attackPulse; }
    public float getSimTime() { return simTime; }

    public int getMaxHp() {
        int value = 100 + hpLevel * 25;
        if ("silk_vest".equals(equippedArmor)) value += 35;
        return value;
    }

    public int getAttack() {
        int value = 9 + attackLevel * 2;
        if ("bone_sword".equals(equippedWeapon)) value += 5;
        if (equippedGraft == graftIndex("reinforced_muscle")) value = Math.round(value * 1.25f);
        return value;
    }

    public int getDefense() {
        int value = 2 + defenseLevel;
        if (equippedGraft == graftIndex("iron_bone")) value += 5;
        return value;
    }

    public float getAttackSpeed() {
        float value = Math.min(2.8f, 0.95f + speedLevel * 0.08f);
        if (equippedGraft == graftIndex("reinforced_muscle")) value *= 0.90f;
        if (equippedGraft == graftIndex("iron_bone")) value *= 0.95f;
        return Math.max(0.35f, value);
    }

    public float getCritChance() {
        float value = Math.min(0.60f, 0.05f + critLevel * 0.02f);
        if ("fang_necklace".equals(equippedAccessory)) value += 0.08f;
        if (equippedGraft == graftIndex("predator_eye")) value += 0.10f;
        return Math.min(0.75f, value);
    }

    public int getCritDamagePercent() { return 150; }
    public int getWaveKillsNeeded() { return 7 + Math.min(10, wave / 3); }

    public static int applyDefense(int rawDamage, int defense) {
        return Math.max(1, rawDamage - Math.max(0, defense) / 2);
    }

    public static int applyCritical(int attack, boolean critical) {
        return critical ? Math.max(1, Math.round(Math.max(1, attack) * 1.5f)) : Math.max(1, attack);
    }

    public static long upgradeCost(int type, int level) {
        long[] base = {25, 30, 35, 40, 50};
        if (type < 0 || type >= base.length) return Long.MAX_VALUE;
        double price = base[type] * Math.pow(1.24, Math.max(0, level));
        return Math.max(1L, Math.round(price));
    }

    public String upgradeStatValue(int type, boolean next) {
        int level = getUpgradeLevel(type) + (next ? 1 : 0);
        switch (type) {
            case 0: return String.valueOf(9 + level * 2 + ("bone_sword".equals(equippedWeapon) ? 5 : 0));
            case 1: return String.valueOf(100 + level * 25 + ("silk_vest".equals(equippedArmor) ? 35 : 0));
            case 2: return String.valueOf(2 + level + (equippedGraft == graftIndex("iron_bone") ? 5 : 0));
            case 3: return String.format(java.util.Locale.US, "%.2f/s", Math.min(2.8f, 0.95f + level * 0.08f));
            case 4: return String.format(java.util.Locale.US, "%.0f%%", Math.min(0.60f, 0.05f + level * 0.02f) * 100f);
            default: return "—";
        }
    }

    public int getUpgradeLevel(int type) {
        switch (type) {
            case 0: return attackLevel;
            case 1: return hpLevel;
            case 2: return defenseLevel;
            case 3: return speedLevel;
            case 4: return critLevel;
            default: return 0;
        }
    }

    public boolean buyUpgrade(int type) {
        if (type < 0 || type > 4 || getUpgradeLevel(type) >= 50) return false;
        long cost = upgradeCost(type, getUpgradeLevel(type));
        if (coins < cost) return false;
        coins -= cost;
        switch (type) {
            case 0: attackLevel++; break;
            case 1: hpLevel++; hp = Math.min(getMaxHp(), hp + 25); break;
            case 2: defenseLevel++; break;
            case 3: speedLevel++; break;
            case 4: critLevel++; break;
        }
        raiseEvent(EVENT_UPGRADE);
        return true;
    }

    public boolean toggleGear(String id) {
        int index = gearIndex(id);
        if (index < 0) return false;
        GearInfo info = GEAR[index];
        if (ownedGear[index]) {
            String current = gearForSlot(info.slot);
            if (id.equals(current)) setGearForSlot(info.slot, "");
            else setGearForSlot(info.slot, id);
            hp = Math.min(hp, getMaxHp());
            return true;
        }
        if (coins < info.goldCost || materialCount(info.materialId) < info.materialCount) return false;
        coins -= info.goldCost;
        removeMaterial(info.materialId, info.materialCount);
        ownedGear[index] = true;
        setGearForSlot(info.slot, id);
        if ("silk_vest".equals(id)) hp = Math.min(getMaxHp(), hp + 35);
        raiseEvent(EVENT_CRAFT);
        return true;
    }

    public boolean toggleGraft(int index) {
        if (index < 0 || index >= GRAFTS.length || !unlockedGrafts[index]) return false;
        equippedGraft = equippedGraft == index ? -1 : index;
        return true;
    }

    public boolean sellMaterial(String id, int amount) {
        int index = materialIndex(id);
        if (index < 0 || amount <= 0 || materialCounts[index] < amount) return false;
        MaterialInfo info = MATERIALS[index];
        materialCounts[index] -= amount;
        long value = (long) info.sellValue * amount;
        coins = safeAdd(coins, value);
        return true;
    }

    public boolean claimContract(int index) {
        if (index < 0 || index >= contracts.length) return false;
        Contract c = contracts[index];
        if (c.claimed || c.progress < c.target) return false;
        coins = safeAdd(coins, c.rewardCoins);
        if ("rotlings".equals(c.id)) addMaterial("bone_fragments", 2);
        else if ("silk".equals(c.id)) addMaterial("spider_silk", 1);
        else if ("boss".equals(c.id)) addMaterial("matriarch_core", 1);
        c.claimed = true;
        c.stage++;
        c.progress = 0;
        c.target = contractTarget(c.id, c.stage);
        c.claimed = false;
        return true;
    }

    public int getMaterialCountAt(int index) { return index < 0 || index >= materialCounts.length ? 0 : materialCounts[index]; }
    public MaterialInfo getMaterialInfoAt(int index) { return MATERIALS[index]; }
    public GearInfo getGearInfoAt(int index) { return GEAR[index]; }
    public GraftInfo getGraftInfoAt(int index) { return GRAFTS[index]; }
    public boolean isGearOwnedAt(int index) { return index >= 0 && index < ownedGear.length && ownedGear[index]; }
    public boolean isGraftUnlockedAt(int index) { return index >= 0 && index < unlockedGrafts.length && unlockedGrafts[index]; }
    public int materialCountSize() { return MATERIALS.length; }
    public int gearCount() { return GEAR.length; }
    public int graftCount() { return GRAFTS.length; }
    public String gearEquippedId(String slot) { return gearForSlot(slot); }

    /** Adds materials through the same path used by combat drops. */
    public void addMaterial(String id, int amount) {
        if (amount <= 0) return;
        int index = materialIndex(id);
        if (index < 0) return;
        materialCounts[index] = Math.min(999_999, materialCounts[index] + amount);
        int graft = graftIndex(id);
        if (graft >= 0) unlockedGrafts[graft] = true;
        if (MATERIALS[index].rarity.ordinal() >= Rarity.RARE.ordinal()) {
            recentLoot = MATERIALS[index].name;
            recentLootRarity = MATERIALS[index].rarity.ordinal();
            lootNoticeSeconds = 2.4f;
            raiseEvent(EVENT_RARE_LOOT);
        }
        if ("spider_silk".equals(id)) {
            Contract c = contractById("silk");
            if (c != null && !c.claimed) c.progress = Math.min(c.target, c.progress + amount);
        }
    }

    public void update(float deltaSeconds) {
        float dt = Math.max(0f, Math.min(0.05f, deltaSeconds));
        if (dt <= 0f) return;
        simTime += dt;
        attackPulse = Math.max(0f, attackPulse - dt * 2.8f);
        for (FloatingText text : floatingTexts) {
            if (text.life > 0f) {
                text.life = Math.max(0f, text.life - dt);
                text.y -= dt * 0.10f;
            }
        }
        if (lootNoticeSeconds > 0f) lootNoticeSeconds = Math.max(0f, lootNoticeSeconds - dt);
        if (poisonTimer > 0f && hp > 0f) {
            poisonTimer -= dt;
            poisonTickTimer -= dt;
            if (poisonTickTimer <= 0f && poisonTimer > 0f) {
                hp = Math.max(0f, hp - Math.max(1, poisonDamage));
                poisonTickTimer = 1f;
                addFloatingText(0.50f, 0.78f, "-" + Math.max(1, poisonDamage), false);
            }
        }
        if (hp <= 0f) {
            if (reviveTimer <= 0f) {
                deaths++;
                reviveTimer = 3.0f;
                raiseEvent(EVENT_HIT);
            } else {
                reviveTimer -= dt;
                if (reviveTimer <= 0f) {
                    hp = Math.max(1, Math.round(getMaxHp() * 0.55f));
                    poisonTimer = 0f;
                    addFloatingText(0.50f, 0.78f, "REVIVED", true);
                }
            }
            return;
        }

        spawnTimer -= dt;
        if (spawnTimer <= 0f && enemies.size() < MAX_ENEMIES) {
            spawnEnemy();
            spawnTimer = 1.8f + random.nextFloat() * 0.7f;
        }

        attackTimer -= dt;
        if (attackTimer <= 0f && !enemies.isEmpty()) {
            Enemy target = closestEnemy();
            if (target != null && distance(target.x, target.y, 0.50f, 0.78f) <= 0.48f) {
                attack(target);
                attackTimer = 1f / getAttackSpeed();
            } else {
                attackTimer = 0.12f;
            }
        }

        for (int i = enemies.size() - 1; i >= 0; i--) {
            Enemy e = enemies.get(i);
            if (e.hp <= 0f) {
                defeatEnemy(i, e);
                continue;
            }
            if (e.poisonTime > 0f) {
                e.poisonTime -= dt;
                e.poisonTick -= dt;
                if (e.poisonTick <= 0f && e.poisonTime > 0f) {
                    e.hp -= e.poisonDps;
                    e.poisonTick = 1f;
                    addFloatingText(e.x, e.y - 0.04f, String.valueOf(e.poisonDps), false);
                }
            }
            if (e.hitFlash > 0f) e.hitFlash -= dt;
            float dx = 0.50f - e.x;
            float dy = 0.78f - e.y;
            float dist = Math.max(0.001f, (float) Math.sqrt(dx * dx + dy * dy));
            if (dist > 0.16f) {
                float move = e.moveSpeed * dt;
                e.x += dx / dist * move;
                e.y += dy / dist * move;
            } else {
                e.attackTimer -= dt;
                if (e.attackTimer <= 0f) {
                    int raw = e.attack + (e.type == IRON_BRUTE || e.boss ? 2 : 0);
                    int damage = applyDefense(raw, getDefense());
                    hp = Math.max(0f, hp - damage);
                    addFloatingText(0.50f, 0.75f, "-" + damage, false);
                    e.attackTimer = e.attackInterval;
                    if (e.type == VENOM_SPIDER || e.boss) {
                        poisonTimer = Math.max(poisonTimer, 3.2f);
                        poisonDamage = Math.max(1, Math.round(raw * 0.28f));
                    }
                }
            }
            if (e.hp <= 0f) defeatEnemy(i, e);
        }
    }

    private float poisonTickTimer = 1f;

    private void spawnEnemy() {
        boolean bossWave = wave > 0 && wave % 10 == 0 && bossDefeatedAtWave < wave;
        if (bossWave) {
            for (Enemy e : enemies) if (e.boss) return;
            spawnEnemyType(VENOM_MATRIARCH, true);
            deathsWhenBossSpawned = deaths;
            raiseEvent(EVENT_BOSS);
            return;
        }
        int maxType = Math.min(4, (wave + 1) / 3);
        int type = random.nextInt(Math.max(1, maxType + 1));
        spawnEnemyType(type, false);
    }

    private void spawnEnemyType(int type, boolean boss) {
        float scale = (float) Math.pow(1.105, Math.max(0, wave - 1));
        String[] names = {"Rotling", "Bonecrawler", "Venom Spider", "Hollow Hound", "Iron Brute", "Venom Matriarch"};
        int[] baseHp = {22, 36, 30, 26, 56, 460};
        int[] baseAttack = {4, 5, 6, 5, 9, 17};
        float[] speed = {0.055f, 0.044f, 0.048f, 0.075f, 0.035f, 0.043f};
        int[] baseGold = {9, 13, 12, 11, 19, 160};
        int ix = Math.min(type, names.length - 1);
        float hpScale = boss ? scale * (1f + wave * 0.025f) : scale;
        Enemy e = new Enemy(type, names[ix], boss, baseHp[ix] * hpScale,
                Math.max(1, Math.round(baseAttack[ix] * Math.max(1f, scale * 0.55f))),
                speed[ix], baseGold[ix] + Math.max(0, wave - 1) * 2);
        e.x = 0.18f + random.nextFloat() * 0.64f;
        e.y = 0.18f + random.nextFloat() * 0.23f;
        e.attackTimer = 0.6f + random.nextFloat() * 0.6f;
        enemies.add(e);
    }

    private void attack(Enemy target) {
        boolean critical = random.nextFloat() < getCritChance();
        int damage = applyCritical(getAttack(), critical);
        target.hp -= damage;
        target.hitFlash = 0.16f;
        attackPulse = 1f;
        addFloatingText(target.x, target.y - 0.07f, String.valueOf(damage), critical);
        raiseEvent(EVENT_HIT);
        if (equippedGraft == graftIndex("venom_gland") && random.nextFloat() < 0.20f) {
            target.poisonTime = Math.max(target.poisonTime, 3f);
            target.poisonDps = Math.max(2, Math.round(getAttack() * 0.24f));
            target.poisonTick = 1f;
        }
    }

    private void defeatEnemy(int index, Enemy e) {
        enemies.remove(index);
        totalKills++;
        level = 1 + (int) (totalKills / 25);
        waveKills++;
        coins = safeAdd(coins, e.gold);
        addFloatingText(e.x, e.y - 0.12f, "+" + e.gold + "g", false);
        if (e.type == ROTLING) {
            Contract c = contractById("rotlings");
            if (c != null && !c.claimed) c.progress = Math.min(c.target, c.progress + 1);
        }
        if (equippedGraft == graftIndex("beast_heart")) hp = Math.min(getMaxHp(), hp + Math.max(1, Math.round(getMaxHp() * 0.05f)));
        dropLoot(e);
        if (e.boss) {
            bossDefeatedAtWave = wave;
            if (deaths == deathsWhenBossSpawned) {
                Contract c = contractById("boss");
                if (c != null && !c.claimed) c.progress = Math.min(c.target, c.progress + 1);
            }
            addMaterial("matriarch_core", 1);
            raiseEvent(EVENT_RARE_LOOT);
        } else {
            raiseEvent(EVENT_KILL);
        }
        if (waveKills >= getWaveKillsNeeded()) {
            wave++;
            waveKills = 0;
            spawnTimer = 0.8f;
            addFloatingText(0.50f, 0.40f, "WAVE " + wave, true);
        }
    }

    private void dropLoot(Enemy e) {
        String common;
        String rare;
        switch (e.type) {
            case BONECRAWLER: common = "bone_fragments"; rare = "hardened_skull"; break;
            case VENOM_SPIDER: common = "spider_silk"; rare = "venom_gland"; break;
            case HOLLOW_HOUND: common = "sharp_fang"; rare = random.nextFloat() < 0.45f ? "predator_eye" : "beast_heart"; break;
            case IRON_BRUTE: common = "iron_bone"; rare = "reinforced_muscle"; break;
            case VENOM_MATRIARCH: common = "spider_silk"; rare = "venom_gland"; break;
            default: common = "rotten_flesh"; rare = "mutated_heart"; break;
        }
        if (random.nextFloat() < 0.88f) addMaterial(common, 1 + (e.boss ? 4 : 0));
        if (random.nextFloat() < (e.boss ? 0.85f : 0.16f)) {
            addMaterial(rare, 1);
            raiseEvent(EVENT_RARE_LOOT);
        }
    }

    private Enemy closestEnemy() {
        Enemy nearest = null;
        float best = Float.MAX_VALUE;
        for (int i = 0; i < enemies.size(); i++) {
            Enemy e = enemies.get(i);
            float d = distance(e.x, e.y, 0.50f, 0.78f);
            if (d < best) { best = d; nearest = e; }
        }
        return nearest;
    }

    private void addFloatingText(float x, float y, String value, boolean critical) {
        FloatingText t = floatingTexts[textCursor++ % floatingTexts.length];
        t.x = x;
        t.y = y;
        t.value = value;
        t.life = 0.9f;
        t.critical = critical;
    }

    private void raiseEvent(int code) { eventCode = code; eventSerial++; }

    private static float distance(float x1, float y1, float x2, float y2) {
        float dx = x1 - x2, dy = y1 - y2;
        return (float) Math.sqrt(dx * dx + dy * dy);
    }

    public String getEnemyName(int type) {
        switch (type) {
            case ROTLING: return "Rotling";
            case BONECRAWLER: return "Bonecrawler";
            case VENOM_SPIDER: return "Venom Spider";
            case HOLLOW_HOUND: return "Hollow Hound";
            case IRON_BRUTE: return "Iron Brute";
            default: return "Venom Matriarch";
        }
    }

    public boolean prepareOfflineRewards(long nowMillis) {
        if (offlinePending) return true;
        if (lastSavedAtMillis <= 0L) { lastSavedAtMillis = nowMillis; return false; }
        long elapsed = nowMillis - lastSavedAtMillis;
        lastSavedAtMillis = nowMillis;
        if (elapsed < 60_000L) return false;
        int seconds = (int) Math.min(MAX_OFFLINE_SECONDS, Math.max(0L, elapsed / 1000L));
        if (seconds <= 0) return false;
        offlineSeconds = seconds;
        float powerFactor = Math.max(0.7f, Math.min(2.8f, (getAttack() * getAttackSpeed()) / 12f));
        int estimatedKills = Math.min(500, Math.max(1, Math.round(seconds / 60f * 3.1f * powerFactor)));
        offlineRewardCoins = Math.max(0L, Math.round(estimatedKills * (8 + wave * 1.4f)));
        Arrays.fill(offlineRewardMaterials, 0);
        offlineRewardMaterials[materialIndex("rotten_flesh")] = estimatedKills / 3;
        offlineRewardMaterials[materialIndex("bone_fragments")] = estimatedKills / 7;
        if (wave >= 4) offlineRewardMaterials[materialIndex("spider_silk")] = estimatedKills / 12;
        offlinePending = true;
        return true;
    }

    public boolean claimOfflineRewards() {
        if (!offlinePending) return false;
        coins = safeAdd(coins, offlineRewardCoins);
        for (int i = 0; i < offlineRewardMaterials.length; i++) if (offlineRewardMaterials[i] > 0) addMaterial(MATERIALS[i].id, offlineRewardMaterials[i]);
        offlinePending = false;
        offlineRewardCoins = 0;
        offlineSeconds = 0;
        Arrays.fill(offlineRewardMaterials, 0);
        return true;
    }

    public void checkpoint(long nowMillis) { lastSavedAtMillis = nowMillis; }

    public String encode() {
        try {
            ByteArrayOutputStream bytes = new ByteArrayOutputStream(512);
            DataOutputStream out = new DataOutputStream(bytes);
            out.writeInt(SAVE_VERSION);
            out.writeLong(clampCoins(coins));
            out.writeInt(clampInt(wave, 1, 1_000_000));
            out.writeLong(Math.max(0, totalKills));
            out.writeInt(clampInt(level, 1, 1_000_000));
            out.writeInt(clampInt(deaths, 0, 1_000_000));
            out.writeInt(clampInt(attackLevel, 0, 50));
            out.writeInt(clampInt(hpLevel, 0, 50));
            out.writeInt(clampInt(defenseLevel, 0, 50));
            out.writeInt(clampInt(speedLevel, 0, 50));
            out.writeInt(clampInt(critLevel, 0, 50));
            out.writeBoolean(maleAppearance);
            out.writeBoolean(soundEnabled);
            out.writeBoolean(musicEnabled);
            out.writeBoolean(lowPerformance);
            out.writeFloat(Math.max(0f, Math.min(getMaxHp(), hp)));
            out.writeUTF(equippedWeapon);
            out.writeUTF(equippedArmor);
            out.writeUTF(equippedAccessory);
            out.writeInt(equippedGraft);
            out.writeInt(waveKills);
            out.writeInt(bossDefeatedAtWave);
            out.writeInt(deathsWhenBossSpawned);
            out.writeLong(lastSavedAtMillis);
            out.writeBoolean(offlinePending);
            out.writeLong(offlineRewardCoins);
            out.writeInt(offlineSeconds);
            for (int i = 0; i < materialCounts.length; i++) out.writeInt(Math.max(0, materialCounts[i]));
            for (boolean b : ownedGear) out.writeBoolean(b);
            for (boolean b : unlockedGrafts) out.writeBoolean(b);
            for (Contract c : contracts) {
                out.writeInt(Math.max(0, c.progress));
                out.writeInt(Math.max(1, c.target));
                out.writeInt(Math.max(0, c.stage));
            }
            for (int v : offlineRewardMaterials) out.writeInt(Math.max(0, v));
            out.flush();
            return Base64.getEncoder().encodeToString(bytes.toByteArray());
        } catch (IOException ignored) {
            return "";
        }
    }

    public static GameEngine decode(String encoded) {
        if (encoded == null || encoded.isEmpty() || encoded.length() > MAX_SAVE_CHARS) return new GameEngine();
        try {
            byte[] bytes = Base64.getDecoder().decode(encoded);
            if (bytes.length > 24_000) return new GameEngine();
            DataInputStream in = new DataInputStream(new ByteArrayInputStream(bytes));
            int version = in.readInt();
            if (version < 2 || version > SAVE_VERSION) return new GameEngine();
            GameEngine g = new GameEngine();
            g.coins = clampCoins(in.readLong());
            g.wave = clampInt(in.readInt(), 1, 1_000_000);
            g.totalKills = Math.max(0, in.readLong());
            g.level = clampInt(in.readInt(), 1, 1_000_000);
            g.deaths = clampInt(in.readInt(), 0, 1_000_000);
            g.attackLevel = clampInt(in.readInt(), 0, 50);
            g.hpLevel = clampInt(in.readInt(), 0, 50);
            g.defenseLevel = clampInt(in.readInt(), 0, 50);
            g.speedLevel = clampInt(in.readInt(), 0, 50);
            g.critLevel = clampInt(in.readInt(), 0, 50);
            g.maleAppearance = in.readBoolean();
            g.soundEnabled = in.readBoolean();
            g.musicEnabled = in.readBoolean();
            g.lowPerformance = version >= 3 && in.readBoolean();
            float loadedHp = in.readFloat();
            g.hp = Float.isNaN(loadedHp) || Float.isInfinite(loadedHp)
                    ? g.getMaxHp() : Math.max(1f, Math.min(g.getMaxHp(), loadedHp));
            g.equippedWeapon = g.safeGear(in.readUTF(), "weapon");
            g.equippedArmor = g.safeGear(in.readUTF(), "armor");
            g.equippedAccessory = g.safeGear(in.readUTF(), "accessory");
            g.equippedGraft = clampInt(in.readInt(), -1, GRAFTS.length - 1);
            g.waveKills = clampInt(in.readInt(), 0, 100_000);
            g.bossDefeatedAtWave = clampInt(in.readInt(), 0, g.wave);
            g.deathsWhenBossSpawned = clampInt(in.readInt(), 0, g.deaths);
            g.lastSavedAtMillis = Math.max(0L, in.readLong());
            g.offlinePending = in.readBoolean();
            g.offlineRewardCoins = clampCoins(in.readLong());
            g.offlineSeconds = clampInt(in.readInt(), 0, MAX_OFFLINE_SECONDS);
            for (int i = 0; i < g.materialCounts.length; i++) g.materialCounts[i] = clampInt(in.readInt(), 0, 999_999);
            for (int i = 0; i < g.ownedGear.length; i++) g.ownedGear[i] = in.readBoolean();
            for (int i = 0; i < g.unlockedGrafts.length; i++) g.unlockedGrafts[i] = in.readBoolean();
            for (Contract c : g.contracts) {
                c.progress = clampInt(in.readInt(), 0, 1_000_000);
                c.target = clampInt(in.readInt(), 1, 1_000_000);
                c.stage = clampInt(in.readInt(), 0, 1_000_000);
                c.progress = Math.min(c.progress, c.target);
            }
            for (int i = 0; i < g.offlineRewardMaterials.length; i++) g.offlineRewardMaterials[i] = clampInt(in.readInt(), 0, 999_999);
            if (g.equippedGraft >= 0 && !g.unlockedGrafts[g.equippedGraft]) g.equippedGraft = -1;
            g.hp = Math.min(g.hp, g.getMaxHp());
            return g;
        } catch (IOException | IllegalArgumentException | IndexOutOfBoundsException ex) {
            return new GameEngine();
        }
    }

    private String safeGear(String id, String slot) {
        int i = gearIndex(id);
        return i >= 0 && GEAR[i].slot.equals(slot) && ownedGear[i] ? id : "";
    }

    private Contract contractById(String id) {
        for (Contract c : contracts) if (c.id.equals(id)) return c;
        return null;
    }

    private static int contractTarget(String id, int stage) {
        if ("rotlings".equals(id)) return 30 + stage * 15;
        if ("silk".equals(id)) return 10 + stage * 5;
        return 1;
    }

    private String gearForSlot(String slot) {
        if ("weapon".equals(slot)) return equippedWeapon;
        if ("armor".equals(slot)) return equippedArmor;
        return equippedAccessory;
    }

    private void setGearForSlot(String slot, String id) {
        if ("weapon".equals(slot)) equippedWeapon = id;
        else if ("armor".equals(slot)) equippedArmor = id;
        else equippedAccessory = id;
    }

    private void removeMaterial(String id, int amount) {
        int i = materialIndex(id);
        if (i >= 0 && amount > 0) materialCounts[i] -= amount;
    }

    private static int materialIndex(String id) {
        if (id == null) return -1;
        for (int i = 0; i < MATERIALS.length; i++) if (MATERIALS[i].id.equals(id)) return i;
        return -1;
    }

    private static int gearIndex(String id) {
        if (id == null) return -1;
        for (int i = 0; i < GEAR.length; i++) if (GEAR[i].id.equals(id)) return i;
        return -1;
    }

    private static int graftIndex(String id) {
        if (id == null) return -1;
        for (int i = 0; i < GRAFTS.length; i++) if (GRAFTS[i].id.equals(id)) return i;
        return -1;
    }

    private static long clampCoins(long value) { return Math.max(0L, Math.min(9_000_000_000_000L, value)); }
    private static long safeAdd(long a, long b) { return clampCoins(a > Long.MAX_VALUE - b ? Long.MAX_VALUE : a + b); }
    private static int clampInt(int value, int min, int max) { return Math.max(min, Math.min(max, value)); }

    public enum Rarity { COMMON, UNCOMMON, RARE, EPIC, LEGENDARY }

    public static final class MaterialInfo {
        public final String id, name, description;
        public final Rarity rarity;
        public final int sellValue;
        MaterialInfo(String id, String name, Rarity rarity, String description, int sellValue) {
            this.id = id; this.name = name; this.rarity = rarity; this.description = description; this.sellValue = sellValue;
        }
    }

    public static final class GearInfo {
        public final String id, name, slot, bonus, materialId;
        public final int materialCount;
        public final long goldCost;
        GearInfo(String id, String name, String slot, String bonus, String materialId, int materialCount, long goldCost) {
            this.id = id; this.name = name; this.slot = slot; this.bonus = bonus; this.materialId = materialId;
            this.materialCount = materialCount; this.goldCost = goldCost;
        }
    }

    public static final class GraftInfo {
        public final String id, name, effect;
        GraftInfo(String id, String name, String effect) { this.id = id; this.name = name; this.effect = effect; }
    }

    public static final class Enemy {
        public final int type;
        public final String name;
        public final boolean boss;
        public final float maxHp;
        public final int attack, gold;
        public final float moveSpeed, attackInterval;
        public float x, y, hp, attackTimer, hitFlash, poisonTime, poisonTick;
        public int poisonDps;
        Enemy(int type, String name, boolean boss, float hp, int attack, float moveSpeed, int gold) {
            this.type = type; this.name = name; this.boss = boss; this.maxHp = hp; this.hp = hp;
            this.attack = attack; this.moveSpeed = moveSpeed; this.gold = gold;
            this.attackInterval = boss ? 1.2f : (type == HOLLOW_HOUND ? 0.85f : 1.45f);
        }
    }

    public static final class FloatingText {
        public float x, y, life;
        public String value = "";
        public boolean critical;
    }

    public static final class Contract {
        public final String id, title, objective;
        public int progress, target, stage;
        public final int rewardCoins;
        public boolean claimed;
        Contract(String id, String title, String objective, int target, int rewardCoins) {
            this.id = id; this.title = title; this.objective = objective; this.target = target; this.rewardCoins = rewardCoins;
        }
        public boolean complete() { return progress >= target; }
    }
}
