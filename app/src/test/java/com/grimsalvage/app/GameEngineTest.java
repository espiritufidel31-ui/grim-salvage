package com.grimsalvage.app;

import org.junit.Test;

import static org.junit.Assert.*;

public class GameEngineTest {
    @Test public void damageRulesStayBounded() {
        assertEquals(1, GameEngine.applyDefense(4, 99));
        assertEquals(8, GameEngine.applyDefense(10, 4));
        assertEquals(12, GameEngine.applyCritical(8, true));
        assertEquals(8, GameEngine.applyCritical(8, false));
    }

    @Test public void upgradePurchasesDeductGoldAndChangeStats() {
        GameEngine game = new GameEngine(1);
        int originalAttack = game.getAttack();
        assertTrue(game.buyUpgrade(0));
        assertEquals(5, game.coins);
        assertEquals(originalAttack + 2, game.getAttack());
        assertFalse(game.buyUpgrade(0));
        assertEquals(1, game.attackLevel);
    }

    @Test public void materialsCanBeSoldAndCraftedGearChangesStats() {
        GameEngine game = new GameEngine(2);
        game.coins = 1_000;
        game.addMaterial("bone_fragments", 5);
        assertTrue(game.sellMaterial("bone_fragments", 1));
        assertEquals(1_004, game.coins);
        assertEquals(4, game.materialCount("bone_fragments"));
        assertTrue(game.toggleGear("bone_sword"));
        assertTrue(game.ownsGear("bone_sword"));
        assertEquals(14, game.getAttack());
        assertFalse(game.toggleGear("silk_vest"));
        game.addMaterial("spider_silk", 3);
        int hp = game.getMaxHp();
        assertTrue(game.toggleGear("silk_vest"));
        assertEquals(hp + 35, game.getMaxHp());
    }

    @Test public void graftTradeoffsAffectCombatStats() {
        GameEngine game = new GameEngine(3);
        int baseAttack = game.getAttack();
        float baseSpeed = game.getAttackSpeed();
        game.addMaterial("reinforced_muscle", 1);
        assertTrue(game.hasGraft("reinforced_muscle"));
        assertTrue(game.toggleGraft(1));
        assertTrue(game.getAttack() > baseAttack);
        assertTrue(game.getAttackSpeed() < baseSpeed);
        game.addMaterial("iron_bone", 1);
        assertTrue(game.toggleGraft(1));
        assertTrue(game.toggleGraft(4));
        assertEquals(7, game.getDefense());
    }

    @Test public void waveProgressionComesFromCombat() {
        GameEngine game = new GameEngine(4);
        game.attackLevel = 10;
        for (int i = 0; i < 90 * 20; i++) game.update(0.05f);
        assertTrue(game.totalKills > 0);
        assertTrue(game.wave >= 2);
    }

    @Test public void enemiesDamageTheHunterAndAutomaticRevivalKeepsProgress() {
        GameEngine game = new GameEngine(4);
        game.attackLevel = 2;
        for (int i = 0; i < 240 * 20; i++) game.update(0.05f);
        assertTrue(game.deaths > 0);
        assertTrue(game.hp > 0f);
        assertTrue(game.totalKills > 0);
        assertEquals(2, game.attackLevel);
    }

    @Test public void tenthWaveBossDropsGuaranteedCore() {
        GameEngine game = new GameEngine(9);
        game.attackLevel = 50;
        game.hpLevel = 50;
        game.defenseLevel = 50;
        game.speedLevel = 50;
        game.coins = 999_999;
        for (int i = 0; i < 240 * 20; i++) game.update(0.05f);
        assertTrue(game.wave >= 11);
        assertTrue(game.materialCount("matriarch_core") >= 1);
        assertEquals(1, game.contractAt(2).progress);
    }

    @Test public void contractsTrackCollectedMaterialsAndRewardOncePerStage() {
        GameEngine game = new GameEngine(5);
        game.coins = 20;
        game.addMaterial("spider_silk", 10);
        assertEquals(10, game.contractAt(1).progress);
        assertTrue(game.claimContract(1));
        assertEquals(170, game.coins);
        assertEquals(15, game.contractAt(1).target);
        assertEquals(11, game.materialCount("spider_silk"));
    }

    @Test public void saveRestoreKeepsProgressAndRejectsCorruption() {
        GameEngine game = new GameEngine(6);
        game.coins = 900;
        game.wave = 12;
        game.attackLevel = 4;
        game.addMaterial("bone_fragments", 8);
        game.addMaterial("predator_eye", 1);
        assertTrue(game.toggleGraft(3));
        game.maleAppearance = true;
        game.lowPerformance = true;
        GameEngine restored = GameEngine.decode(game.encode());
        assertEquals(900, restored.coins);
        assertEquals(12, restored.wave);
        assertEquals(4, restored.attackLevel);
        assertEquals(8, restored.materialCount("bone_fragments"));
        assertTrue(restored.maleAppearance);
        assertTrue(restored.lowPerformance);
        assertTrue(restored.isGraftEquipped("predator_eye"));
        assertEquals(1, GameEngine.decode("not-a-save").wave);
    }

    @Test public void offlineRewardsAreCappedClaimedOnceAndDoNotAdvanceWaves() {
        GameEngine game = new GameEngine(7);
        game.checkpoint(1_000_000L);
        assertTrue(game.prepareOfflineRewards(1_000_000L + 24 * 60 * 60 * 1000L));
        assertEquals(7200, game.offlineSeconds);
        long reward = game.offlineRewardCoins;
        assertTrue(reward > 0);
        assertEquals(1, game.wave);
        assertTrue(game.claimOfflineRewards());
        assertEquals(30 + reward, game.coins);
        assertFalse(game.claimOfflineRewards());
        assertEquals(1, game.wave);
    }
}
