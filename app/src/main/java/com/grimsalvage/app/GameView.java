package com.grimsalvage.app;

import android.content.Context;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.Paint;
import android.graphics.Path;
import android.graphics.RectF;
import android.graphics.Typeface;
import android.view.MotionEvent;
import android.view.View;

/** Lightweight Canvas interface and foreground-only battle loop. */
public final class GameView extends View {
    public interface SaveListener {
        void saveCheckpoint();
        void onAudioSettingsChanged();
    }

    private static final int TAB_BATTLE = 0;
    private static final int TAB_UPGRADES = 1;
    private static final int TAB_INVENTORY = 2;
    private static final int TAB_GRAFTS = 3;
    private static final int TAB_CONTRACTS = 4;
    private static final int TARGET_NAV = 1;
    private static final int TARGET_APPEARANCE = 2;
    private static final int TARGET_SFX = 3;
    private static final int TARGET_MUSIC = 4;
    private static final int TARGET_UPGRADE = 5;
    private static final int TARGET_INVENTORY_MODE = 6;
    private static final int TARGET_PAGE = 7;
    private static final int TARGET_SELL_ONE = 8;
    private static final int TARGET_SELL_ALL = 9;
    private static final int TARGET_GEAR = 10;
    private static final int TARGET_GRAFT = 11;
    private static final int TARGET_CONTRACT = 12;
    private static final int TARGET_CLAIM_OFFLINE = 13;
    private static final int TARGET_FPS = 14;

    private final GameEngine engine;
    private final SoundController sounds;
    private final SaveListener saveListener;
    private final Paint paint = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Paint textPaint = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Paint boldPaint = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Paint faintPaint = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Path path = new Path();
    private final RectF rect = new RectF();
    private final HitTarget[] targets = new HitTarget[40];
    private int targetCount;
    private float density;
    private float widthDp;
    private float heightDp;
    private float navTop;
    private float contentTop;
    private float contentBottom;
    private boolean loopActive;
    private long lastFrameNanos;
    private float secondsSinceSave;
    private int seenEventSerial;
    private int tab = TAB_BATTLE;
    private boolean forgeMode;
    private int materialPage;
    private String toast = "";
    private float toastSeconds;

    private final int colorBackground = Color.rgb(8, 10, 15);
    private final int colorPanel = Color.rgb(17, 21, 29);
    private final int colorPanelLight = Color.rgb(24, 29, 39);
    private final int colorRed = Color.rgb(189, 47, 64);
    private final int colorRedBright = Color.rgb(255, 75, 91);
    private final int colorCyan = Color.rgb(97, 219, 226);
    private final int colorText = Color.rgb(236, 237, 240);
    private final int colorMuted = Color.rgb(144, 152, 164);
    private final int colorGreen = Color.rgb(116, 218, 151);
    private final int colorGold = Color.rgb(242, 191, 90);

    public GameView(Context context, GameEngine engine, SoundController sounds, SaveListener saveListener) {
        super(context);
        this.engine = engine;
        this.sounds = sounds;
        this.saveListener = saveListener;
        density = getResources().getDisplayMetrics().density;
        setFocusable(true);
        setClickable(true);
        textPaint.setTypeface(Typeface.create("sans-serif", Typeface.NORMAL));
        boldPaint.setTypeface(Typeface.create("sans-serif-condensed", Typeface.BOLD));
        faintPaint.setTypeface(Typeface.create("sans-serif", Typeface.NORMAL));
        for (int i = 0; i < targets.length; i++) targets[i] = new HitTarget();
        seenEventSerial = engine.getEventSerial();
    }

    public void startLoop() {
        if (loopActive) return;
        loopActive = true;
        lastFrameNanos = 0L;
        postInvalidateOnAnimation();
    }

    public void stopLoop() {
        loopActive = false;
        lastFrameNanos = 0L;
        invalidate();
    }

    @Override protected void onDraw(Canvas canvas) {
        super.onDraw(canvas);
        widthDp = getWidth() / density;
        heightDp = getHeight() / density;
        canvas.save();
        canvas.scale(density, density);
        if (loopActive) updateLoop();
        canvas.drawColor(colorBackground);
        drawHeader(canvas);
        navTop = heightDp - 70f;
        contentTop = 132f;
        contentBottom = navTop - 12f;
        targetCount = 0;
        switch (tab) {
            case TAB_UPGRADES: drawUpgrades(canvas); break;
            case TAB_INVENTORY: drawInventory(canvas); break;
            case TAB_GRAFTS: drawGrafts(canvas); break;
            case TAB_CONTRACTS: drawContracts(canvas); break;
            default: drawBattle(canvas); break;
        }
        drawNavigation(canvas);
        if (engine.offlinePending) {
            targetCount = 0;
            drawOfflineOverlay(canvas);
        }
        if (toastSeconds > 0f) {
            toastSeconds = Math.max(0f, toastSeconds - (loopActive ? 0.016f : 0f));
            drawToast(canvas);
        }
        canvas.restore();
        if (loopActive) {
            if (engine.lowPerformance) postInvalidateDelayed(34L);
            else postInvalidateOnAnimation();
        }
    }

    private void updateLoop() {
        long now = System.nanoTime();
        float dt = lastFrameNanos == 0L ? 0f : Math.min(0.05f, (now - lastFrameNanos) / 1_000_000_000f);
        lastFrameNanos = now;
        if (dt > 0f) {
            engine.update(dt);
            secondsSinceSave += dt;
            if (toastSeconds > 0f) toastSeconds = Math.max(0f, toastSeconds - dt);
            int serial = engine.getEventSerial();
            if (serial != seenEventSerial) {
                seenEventSerial = serial;
                sounds.playEvent(engine.getEventCode());
            }
            if (secondsSinceSave >= 12f) {
                secondsSinceSave = 0f;
                saveListener.saveCheckpoint();
            }
        }
    }

    private void drawHeader(Canvas c) {
        fill(c, 0, 0, widthDp, 132, colorBackground);
        text(c, "THE ENDLESS HUNT", 18, 20, 10, colorCyan, true, Paint.Align.LEFT);
        text(c, "GRIM SALVAGE", 17, 50, 25, colorText, true, Paint.Align.LEFT);
        text(c, "WAVE " + engine.wave, widthDp - 20, 27, 12, colorRedBright, true, Paint.Align.RIGHT);
        text(c, "LV " + engine.level + "   " + compact(engine.coins) + " G", widthDp - 20, 49, 12, colorGold, true, Paint.Align.RIGHT);

        float barX = 18, barY = 63, barW = widthDp - 36, barH = 13;
        rounded(c, barX, barY, barX + barW, barY + barH, 7, Color.rgb(38, 41, 48));
        float hpFraction = Math.max(0f, Math.min(1f, engine.hp / Math.max(1f, engine.getMaxHp())));
        if (hpFraction > 0f) rounded(c, barX, barY, barX + barW * hpFraction, barY + barH, 7, hpFraction < 0.28f ? colorRedBright : colorGreen);
        text(c, "HP " + Math.max(0, Math.round(engine.hp)) + " / " + engine.getMaxHp(), barX + 5, barY + 11, 9, colorText, true, Paint.Align.LEFT);

        float y = 88, h = 29, gap = 7;
        float w1 = Math.min(99, (widthDp - 50) * 0.34f);
        button(c, TARGET_APPEARANCE, 0, 18, y, 18 + w1, y + h,
                engine.maleAppearance ? "MALE HUNTER" : "FEMALE HUNTER", true, colorPanelLight, colorText, 9);
        float toggleW = Math.min(72, (widthDp - 60) * 0.25f);
        float sx = 18 + w1 + gap;
        button(c, TARGET_SFX, 0, sx, y, sx + toggleW, y + h,
                engine.soundEnabled ? "SFX ON" : "SFX OFF", true, engine.soundEnabled ? Color.rgb(38, 51, 59) : colorPanelLight,
                engine.soundEnabled ? colorCyan : colorMuted, 9);
        float mx = sx + toggleW + gap;
        button(c, TARGET_MUSIC, 0, mx, y, mx + toggleW, y + h,
                engine.musicEnabled ? "MUSIC ON" : "MUSIC OFF", true, engine.musicEnabled ? Color.rgb(38, 51, 59) : colorPanelLight,
                engine.musicEnabled ? colorCyan : colorMuted, 8);
        float fpsLeft = widthDp - 66;
        button(c, TARGET_FPS, 0, fpsLeft, y, widthDp - 18, y + h,
                engine.lowPerformance ? "FPS 30" : "FPS 60", true, colorPanelLight,
                engine.lowPerformance ? colorGold : colorCyan, 8);
    }

    private void drawBattle(Canvas c) {
        float left = 14, right = widthDp - 14;
        float top = contentTop, bottom = contentBottom;
        rounded(c, left, top, right, bottom, 20, colorPanel);
        drawArena(c, left + 1, top + 1, right - 1, bottom - 1);
        text(c, "AUTO HUNT  ·  " + engine.getWaveKillsNeeded() + " KILLS TO ADVANCE", widthDp / 2, top + 24, 9, colorMuted, true, Paint.Align.CENTER);
        float fieldX = left + 12;
        float fieldY = top + 20;
        float fieldW = right - left - 24;
        float fieldH = bottom - top - 38;
        for (int i = 0; i < engine.enemyCount(); i++) {
            GameEngine.Enemy enemy = engine.enemyAt(i);
            float x = fieldX + enemy.x * fieldW;
            float y = fieldY + enemy.y * fieldH;
            drawEnemy(c, enemy, x, y, enemy.boss ? 37 : 25);
        }
        float heroX = fieldX + 0.5f * fieldW;
        float heroY = fieldY + 0.78f * fieldH;
        if (engine.getAttackPulse() > 0.25f && engine.enemyCount() > 0) {
            int nearest = 0;
            float best = Float.MAX_VALUE;
            for (int i = 0; i < engine.enemyCount(); i++) {
                GameEngine.Enemy enemy = engine.enemyAt(i);
                float dx = enemy.x - 0.5f, dy = enemy.y - 0.78f;
                float d = dx * dx + dy * dy;
                if (d < best) { best = d; nearest = i; }
            }
            GameEngine.Enemy enemy = engine.enemyAt(nearest);
            paint.setColor(colorCyan);
            paint.setAlpha((int) (engine.getAttackPulse() * 150));
            paint.setStrokeWidth(2.2f);
            c.drawLine(heroX, heroY - 7, fieldX + enemy.x * fieldW, fieldY + enemy.y * fieldH, paint);
            paint.setAlpha(255);
        }
        drawHero(c, heroX, heroY, engine.maleAppearance, engine.getAttackPulse());
        for (int i = 0; i < 12; i++) {
            GameEngine.FloatingText t = engine.floatingTextAt(i);
            if (t.life <= 0f) continue;
            float x = fieldX + t.x * fieldW;
            float y = fieldY + t.y * fieldH;
            text(c, t.value, x, y, t.critical ? 16 : 12, t.critical ? colorGold : colorText, true, Paint.Align.CENTER);
        }
        if (engine.hp <= 0f) {
            rounded(c, widthDp / 2 - 66, bottom - 64, widthDp / 2 + 66, bottom - 38, 13, 0xDD220E17);
            text(c, "REVIVING…", widthDp / 2, bottom - 47, 11, colorRedBright, true, Paint.Align.CENTER);
        }
        if (engine.lootNoticeSeconds > 0f) {
            int rarity = rarityColor(engine.recentLootRarity);
            float noticeW = Math.min(widthDp - 44, 245);
            rounded(c, widthDp / 2 - noticeW / 2, top + 38, widthDp / 2 + noticeW / 2, top + 72, 16, 0xEE161B24);
            text(c, "RARE SALVAGE  ·  " + engine.recentLoot, widthDp / 2, top + 60, 10, rarity, true, Paint.Align.CENTER);
        }
    }

    private void drawArena(Canvas c, float left, float top, float right, float bottom) {
        paint.setColor(Color.rgb(16, 20, 28));
        paint.setStyle(Paint.Style.FILL);
        c.drawRoundRect(left, top, right, bottom, 18, 18, paint);
        paint.setColor(Color.rgb(37, 44, 55));
        paint.setStrokeWidth(1f);
        for (int i = 0; i < 5; i++) {
            float x = left + 25 + i * (right - left - 40) / 4f;
            c.drawLine(x, top + 45, x - 6, bottom - 15, paint);
        }
        for (int i = 0; i < 4; i++) {
            float x = left + 10 + i * 83;
            float h = 50 + (i % 3) * 22;
            paint.setColor(Color.rgb(21, 26, 35));
            c.drawRect(x, bottom - h - 20, x + 22 + (i % 2) * 12, bottom - 18, paint);
            paint.setColor(0xFF36303A);
            c.drawRect(x + 6, bottom - h - 8, x + 8, bottom - h - 20, paint);
        }
        paint.setColor(0x5539A9B3);
        c.drawLine(left + 16, bottom - 20, right - 16, bottom - 20, paint);
    }

    private void drawHero(Canvas c, float x, float y, boolean male, float pulse) {
        float bob = (float) Math.sin(engine.getSimTime() * 3.2f) * 2.0f;
        float s = 1f + pulse * 0.05f;
        paint.setColor(0x66000000);
        c.drawOval(x - 21, y + 17, x + 21, y + 26, paint);
        paint.setColor(0xFFFFD5BC);
        c.drawCircle(x, y - 24 + bob, 10 * s, paint);
        paint.setColor(Color.rgb(30, 26, 38));
        if (male) {
            path.reset(); path.moveTo(x - 10, y - 27 + bob); path.lineTo(x - 8, y - 37 + bob);
            path.lineTo(x + 8, y - 37 + bob); path.lineTo(x + 10, y - 25 + bob); path.lineTo(x + 3, y - 30 + bob);
            path.lineTo(x - 3, y - 29 + bob); path.close(); c.drawPath(path, paint);
        } else {
            path.reset(); path.moveTo(x - 10, y - 27 + bob); path.lineTo(x - 12, y - 38 + bob);
            path.lineTo(x - 5, y - 43 + bob); path.lineTo(x + 7, y - 39 + bob); path.lineTo(x + 12, y - 26 + bob);
            path.lineTo(x + 10, y - 6 + bob); path.lineTo(x + 6, y - 20 + bob); path.lineTo(x - 7, y - 18 + bob);
            path.lineTo(x - 9, y - 5 + bob); path.close(); c.drawPath(path, paint);
        }
        paint.setColor(colorCyan);
        c.drawCircle(x - 3, y - 23 + bob, 1.2f, paint); c.drawCircle(x + 3, y - 23 + bob, 1.2f, paint);
        paint.setColor(Color.rgb(81, 30, 43));
        path.reset(); path.moveTo(x - 13, y - 13 + bob); path.lineTo(x + 12, y - 13 + bob);
        path.lineTo(x + 17, y + 10 + bob); path.lineTo(x, y + 19 + bob); path.lineTo(x - 17, y + 10 + bob); path.close(); c.drawPath(path, paint);
        paint.setColor(Color.rgb(188, 57, 69));
        c.drawRect(x - 3, y - 14 + bob, x + 3, y + 10 + bob, paint);
        paint.setColor(Color.rgb(46, 51, 65));
        c.drawRect(x - 9, y + 15 + bob, x - 2, y + 27 + bob, paint); c.drawRect(x + 2, y + 15 + bob, x + 9, y + 27 + bob, paint);
        paint.setColor(0xFFBBC8CF);
        paint.setStrokeWidth(2.4f);
        c.drawLine(x + 12, y - 8 + bob, x + 28, y - 31 + bob, paint);
        paint.setStrokeWidth(1f);
        paint.setColor(colorCyan);
        c.drawLine(x + 26, y - 28 + bob, x + 30, y - 34 + bob, paint);
    }

    private void drawEnemy(Canvas c, GameEngine.Enemy e, float x, float y, float size) {
        paint.setColor(e.hitFlash > 0f ? Color.WHITE : enemyColor(e.type));
        if (e.boss) {
            paint.setColor(0xAA6B1F38); c.drawCircle(x, y, size + 13, paint);
            paint.setColor(e.hitFlash > 0f ? Color.WHITE : Color.rgb(113, 40, 72));
            c.drawCircle(x, y, size, paint);
            paint.setColor(Color.rgb(230, 80, 125)); c.drawCircle(x - 11, y - 2, 4, paint); c.drawCircle(x + 11, y - 2, 4, paint);
            paint.setColor(Color.rgb(28, 15, 27)); c.drawCircle(x - 11, y - 2, 1.5f, paint); c.drawCircle(x + 11, y - 2, 1.5f, paint);
            for (int i = -1; i <= 1; i++) {
                paint.setColor(Color.rgb(157, 56, 99));
                c.drawLine(x + i * 11, y + 22, x + i * 20, y + 39, paint);
            }
        } else if (e.type == GameEngine.VENOM_SPIDER) {
            paint.setColor(e.hitFlash > 0f ? Color.WHITE : Color.rgb(94, 105, 76));
            c.drawOval(x - size * .55f, y - size * .3f, x + size * .55f, y + size * .4f, paint);
            c.drawCircle(x, y - size * .45f, size * .34f, paint);
            paint.setColor(colorRedBright); c.drawCircle(x - 4, y - size * .45f, 2.5f, paint); c.drawCircle(x + 4, y - size * .45f, 2.5f, paint);
            paint.setColor(Color.rgb(129, 142, 108)); paint.setStrokeWidth(2f);
            for (int i = 0; i < 4; i++) { float side = (i % 2 == 0) ? -1 : 1; float oy = -7 + i * 5; c.drawLine(x + side * 8, y + oy, x + side * 20, y + oy - 8, paint); }
        } else if (e.type == GameEngine.BONECRAWLER) {
            paint.setColor(e.hitFlash > 0f ? Color.WHITE : Color.rgb(181, 183, 168));
            c.drawCircle(x, y - 4, size * .65f, paint);
            paint.setColor(Color.rgb(31, 34, 39)); c.drawCircle(x - 6, y - 6, 3.5f, paint); c.drawCircle(x + 6, y - 6, 3.5f, paint);
            paint.setColor(Color.rgb(161, 165, 152)); c.drawRoundRect(x - 9, y + 3, x + 9, y + 17, 4, 4, paint);
        } else {
            paint.setColor(e.hitFlash > 0f ? Color.WHITE : enemyColor(e.type));
            c.drawRoundRect(x - size * .58f, y - size * .5f, x + size * .58f, y + size * .43f, size * .33f, size * .33f, paint);
            paint.setColor(colorText); c.drawCircle(x - 5, y - 5, 2.4f, paint); c.drawCircle(x + 5, y - 5, 2.4f, paint);
            paint.setColor(Color.rgb(20, 20, 24)); c.drawCircle(x - 5, y - 5, 1.1f, paint); c.drawCircle(x + 5, y - 5, 1.1f, paint);
            if (e.type == GameEngine.IRON_BRUTE) {
                paint.setColor(Color.rgb(192, 128, 72)); c.drawRect(x - size * .48f, y - 3, x + size * .48f, y + 6, paint);
            }
        }
        float barW = e.boss ? 94 : 64;
        float barY = y - size - 16;
        text(c, e.name, x, barY - 4, e.boss ? 10 : 8, e.boss ? colorRedBright : colorText, true, Paint.Align.CENTER);
        rounded(c, x - barW / 2, barY, x + barW / 2, barY + 5, 3, Color.rgb(44, 28, 37));
        float ratio = Math.max(0, Math.min(1, e.hp / Math.max(1f, e.maxHp)));
        if (ratio > 0) rounded(c, x - barW / 2, barY, x - barW / 2 + barW * ratio, barY + 5, 3, e.boss ? colorRedBright : colorRed);
    }

    private void drawUpgrades(Canvas c) {
        drawSectionTitle(c, "HUNTER GROWTH", "Permanent upgrades · next level applies immediately");
        String[] names = {"Attack Damage", "Maximum HP", "Defense", "Attack Speed", "Critical Chance"};
        float rowH = Math.min(62f, (contentBottom - contentTop - 58f) / 5f);
        float y = contentTop + 48;
        for (int i = 0; i < names.length; i++) {
            float rowY = y + i * (rowH + 5);
            card(c, 17, rowY, widthDp - 17, rowY + rowH, colorPanel);
            text(c, names[i], 29, rowY + 23, 14, colorText, true, Paint.Align.LEFT);
            text(c, "Lv " + engine.getUpgradeLevel(i) + "   " + engine.upgradeStatValue(i, false) + "  →  " + engine.upgradeStatValue(i, true),
                    29, rowY + 43, 10, colorMuted, false, Paint.Align.LEFT);
            long cost = GameEngine.upgradeCost(i, engine.getUpgradeLevel(i));
            float bx = widthDp - 108;
            button(c, TARGET_UPGRADE, i, bx, rowY + rowH / 2 - 17, widthDp - 27, rowY + rowH / 2 + 17,
                    engine.getUpgradeLevel(i) >= 50 ? "MAX" : compact(cost) + " G", engine.coins >= cost && engine.getUpgradeLevel(i) < 50,
                    colorPanelLight, engine.coins >= cost ? colorCyan : colorMuted, 10);
        }
    }

    private void drawInventory(Canvas c) {
        drawSectionTitle(c, forgeMode ? "THE FORGE" : "SALVAGE CACHE", forgeMode ? "Shape monster remains into useful gear" : "Sell parts for coin · keep organs to graft or forge");
        float y = contentTop + 43;
        float tabW = (widthDp - 48) / 2f;
        button(c, TARGET_INVENTORY_MODE, 0, 18, y, 18 + tabW, y + 32, "MATERIALS", !forgeMode,
                !forgeMode ? Color.rgb(49, 30, 39) : colorPanelLight, !forgeMode ? colorRedBright : colorMuted, 10);
        button(c, TARGET_INVENTORY_MODE, 1, 24 + tabW, y, widthDp - 18, y + 32, "FORGE", forgeMode,
                forgeMode ? Color.rgb(49, 30, 39) : colorPanelLight, forgeMode ? colorRedBright : colorMuted, 10);
        if (forgeMode) drawForge(c, y + 43); else drawMaterials(c, y + 43);
    }

    private void drawMaterials(Canvas c, float y) {
        int perPage = 6;
        int pages = (engine.materialCountSize() + perPage - 1) / perPage;
        float rowH = Math.min(49f, (contentBottom - y - 42) / perPage);
        for (int row = 0; row < perPage; row++) {
            int index = materialPage * perPage + row;
            if (index >= engine.materialCountSize()) break;
            GameEngine.MaterialInfo info = engine.getMaterialInfoAt(index);
            int count = engine.getMaterialCountAt(index);
            float top = y + row * (rowH + 4);
            card(c, 18, top, widthDp - 18, top + rowH, colorPanel);
            paint.setColor(rarityColor(info.rarity.ordinal())); c.drawCircle(30, top + rowH / 2, 4, paint);
            text(c, info.name, 42, top + rowH / 2 - 2, 11, colorText, true, Paint.Align.LEFT);
            text(c, "x" + count + " · " + info.sellValue + " G each", 42, top + rowH / 2 + 12, 8, colorMuted, false, Paint.Align.LEFT);
            float sellW = 53;
            float allW = 58;
            float allX = widthDp - 27 - allW;
            float oneX = allX - 5 - sellW;
            button(c, TARGET_SELL_ONE, index, oneX, top + 6, oneX + sellW, top + rowH - 6,
                    "SELL 1", count > 0, colorPanelLight, count > 0 ? colorGold : colorMuted, 8);
            button(c, TARGET_SELL_ALL, index, allX, top + 6, allX + allW, top + rowH - 6,
                    "SELL ALL", count > 0, colorPanelLight, count > 0 ? colorGold : colorMuted, 8);
        }
        float footerY = contentBottom - 31;
        text(c, "PART " + (materialPage + 1) + " / " + pages, widthDp / 2, footerY + 18, 9, colorMuted, true, Paint.Align.CENTER);
        button(c, TARGET_PAGE, -1, widthDp / 2 - 102, footerY + 1, widthDp / 2 - 47, footerY + 30,
                "‹", materialPage > 0, colorPanelLight, colorText, 17);
        button(c, TARGET_PAGE, 1, widthDp / 2 + 47, footerY + 1, widthDp / 2 + 102, footerY + 30,
                "›", materialPage + 1 < pages, colorPanelLight, colorText, 17);
    }

    private void drawForge(Canvas c, float y) {
        float available = contentBottom - y - 4;
        float rowH = Math.min(100f, (available - 12f) / 3f);
        for (int i = 0; i < engine.gearCount(); i++) {
            GameEngine.GearInfo gear = engine.getGearInfoAt(i);
            boolean owned = engine.isGearOwnedAt(i);
            boolean equipped = gear.id.equals(engine.gearEquippedId(gear.slot));
            int count = engine.materialCount(gear.materialId);
            boolean canCraft = engine.coins >= gear.goldCost && count >= gear.materialCount;
            float top = y + i * (rowH + 6);
            card(c, 18, top, widthDp - 18, top + rowH, colorPanel);
            text(c, gear.name, 29, top + 23, 14, colorText, true, Paint.Align.LEFT);
            text(c, gear.slot.toUpperCase() + " · " + gear.bonus, 29, top + 43, 9, colorCyan, true, Paint.Align.LEFT);
            text(c, gear.materialCount + " " + findMaterialName(gear.materialId) + "  +  " + gear.goldCost + " G  (" + count + ")",
                    29, top + 61, 8, colorMuted, false, Paint.Align.LEFT);
            String label = !owned ? "FORGE" : equipped ? "UNEQUIP" : "EQUIP";
            boolean enabled = owned || canCraft;
            float bx = widthDp - 95;
            button(c, TARGET_GEAR, i, bx, top + rowH - 38, widthDp - 27, top + rowH - 8, label, enabled,
                    colorPanelLight, enabled ? colorCyan : colorMuted, 9);
        }
    }

    private void drawGrafts(Canvas c) {
        drawSectionTitle(c, "MONSTER GRAFTS", "One slot · meaningful power always comes with a price");
        float rowH = Math.min(65f, (contentBottom - contentTop - 56f) / 5f);
        float y = contentTop + 48;
        for (int i = 0; i < engine.graftCount(); i++) {
            GameEngine.GraftInfo graft = engine.getGraftInfoAt(i);
            boolean unlocked = engine.isGraftUnlockedAt(i);
            boolean equipped = engine.isGraftEquipped(graft.id);
            float rowY = y + i * (rowH + 5);
            card(c, 18, rowY, widthDp - 18, rowY + rowH, colorPanel);
            text(c, graft.name, 29, rowY + 24, 13, unlocked ? colorText : colorMuted, true, Paint.Align.LEFT);
            text(c, unlocked ? graft.effect : "LOCKED · harvest this organ to unlock", 29, rowY + 44, 9, colorMuted, false, Paint.Align.LEFT);
            float bx = widthDp - 106;
            button(c, TARGET_GRAFT, i, bx, rowY + rowH / 2 - 16, widthDp - 27, rowY + rowH / 2 + 16,
                    !unlocked ? "LOCKED" : equipped ? "REMOVE" : "IMPLANT", unlocked,
                    colorPanelLight, equipped ? colorRedBright : (unlocked ? colorCyan : colorMuted), 8);
        }
    }

    private void drawContracts(Canvas c) {
        drawSectionTitle(c, "HUNTER CONTRACTS", "Small goals · claim rewards when each mark is filled");
        float available = contentBottom - contentTop - 58;
        float rowH = Math.min(113f, (available - 14f) / 3f);
        float y = contentTop + 48;
        for (int i = 0; i < 3; i++) {
            GameEngine.Contract contract = engine.contractAt(i);
            float top = y + i * (rowH + 7);
            card(c, 18, top, widthDp - 18, top + rowH, colorPanel);
            text(c, contract.title, 30, top + 25, 15, colorText, true, Paint.Align.LEFT);
            text(c, contract.objective, 30, top + 45, 10, colorMuted, false, Paint.Align.LEFT);
            float barX = 30, barY = top + 57, barW = widthDp - 60;
            rounded(c, barX, barY, barX + barW, barY + 8, 4, Color.rgb(42, 44, 52));
            float ratio = Math.max(0f, Math.min(1f, contract.progress / (float) Math.max(1, contract.target)));
            if (ratio > 0) rounded(c, barX, barY, barX + barW * ratio, barY + 8, 4, colorCyan);
            text(c, Math.min(contract.progress, contract.target) + " / " + contract.target + "     REWARD " + contract.rewardCoins + " G",
                    30, top + 80, 9, colorMuted, false, Paint.Align.LEFT);
            button(c, TARGET_CONTRACT, i, widthDp - 111, top + rowH - 35, widthDp - 29, top + rowH - 7,
                    contract.complete() ? "CLAIM" : "HUNT", contract.complete(), colorPanelLight,
                    contract.complete() ? colorGold : colorMuted, 9);
        }
    }

    private void drawSectionTitle(Canvas c, String title, String subtitle) {
        text(c, title, 20, contentTop + 19, 15, colorText, true, Paint.Align.LEFT);
        text(c, subtitle, 20, contentTop + 36, 9, colorMuted, false, Paint.Align.LEFT);
    }

    private void drawNavigation(Canvas c) {
        fill(c, 0, navTop, widthDp, heightDp, Color.rgb(11, 14, 20));
        paint.setColor(Color.rgb(42, 48, 58)); paint.setStrokeWidth(1); c.drawLine(0, navTop, widthDp, navTop, paint);
        String[] labels = {"HUNT", "UPGRADES", "SALVAGE", "GRAFTS", "OATHS"};
        String[] icons = {"✦", "＋", "◇", "◈", "≋"};
        float itemW = widthDp / 5f;
        for (int i = 0; i < labels.length; i++) {
            float center = itemW * (i + 0.5f);
            boolean selected = tab == i;
            int col = selected ? colorCyan : colorMuted;
            if (selected) {
                rounded(c, itemW * i + 9, navTop + 8, itemW * (i + 1) - 9, navTop + 10, 1, colorRed);
            }
            text(c, icons[i], center, navTop + 34, 17, col, true, Paint.Align.CENTER);
            text(c, labels[i], center, navTop + 55, 8, col, true, Paint.Align.CENTER);
            addTarget(TARGET_NAV, i, itemW * i, navTop, itemW * (i + 1), heightDp);
        }
    }

    private void drawOfflineOverlay(Canvas c) {
        paint.setColor(0xDD05070B); c.drawRect(0, 0, widthDp, heightDp, paint);
        float mw = Math.min(widthDp - 34, 340);
        float mh = 340;
        float x = (widthDp - mw) / 2f;
        float y = Math.max(130, (heightDp - mh) / 2f);
        card(c, x, y, x + mw, y + mh, Color.rgb(19, 23, 32));
        text(c, "THE HUNT CONTINUED", widthDp / 2, y + 39, 10, colorCyan, true, Paint.Align.CENTER);
        text(c, "SALVAGE RECOVERED", widthDp / 2, y + 70, 21, colorText, true, Paint.Align.CENTER);
        text(c, "AWAY FOR " + duration(engine.offlineSeconds), widthDp / 2, y + 95, 10, colorMuted, false, Paint.Align.CENTER);
        text(c, "+" + compact(engine.offlineRewardCoins) + " G", widthDp / 2, y + 144, 27, colorGold, true, Paint.Align.CENTER);
        int shown = 0;
        for (int i = 0; i < engine.materialCountSize() && shown < 4; i++) {
            int count = engine.offlineRewardMaterials[i];
            if (count <= 0) continue;
            GameEngine.MaterialInfo material = engine.getMaterialInfoAt(i);
            text(c, "+" + count + "  " + material.name, widthDp / 2, y + 176 + shown * 20, 10,
                    rarityColor(material.rarity.ordinal()), true, Paint.Align.CENTER);
            shown++;
        }
        if (shown == 0) text(c, "No monster parts found this time.", widthDp / 2, y + 186, 10, colorMuted, false, Paint.Align.CENTER);
        button(c, TARGET_CLAIM_OFFLINE, 0, x + 27, y + mh - 62, x + mw - 27, y + mh - 22,
                "CLAIM SALVAGE", true, colorRed, colorText, 12);
    }

    private void drawToast(Canvas c) {
        float w = Math.min(widthDp - 40, 300);
        float y = navTop - 48;
        rounded(c, widthDp / 2 - w / 2, y, widthDp / 2 + w / 2, y + 34, 16, 0xEE202630);
        text(c, toast, widthDp / 2, y + 22, 10, colorText, true, Paint.Align.CENTER);
    }

    private void drawEnemyLabel(Canvas c, float x, float y, String label, int color) {
        text(c, label, x, y, 10, color, true, Paint.Align.CENTER);
    }

    private void card(Canvas c, float l, float t, float r, float b, int color) {
        rounded(c, l, t, r, b, 14, color);
        paint.setColor(0x223D4C5C); paint.setStyle(Paint.Style.STROKE); paint.setStrokeWidth(1);
        c.drawRoundRect(l, t, r, b, 14, 14, paint); paint.setStyle(Paint.Style.FILL);
    }

    private void button(Canvas c, int kind, int arg, float l, float t, float r, float b,
                        String label, boolean enabled, int fillColor, int textColor, float size) {
        int bg = enabled ? fillColor : Color.rgb(28, 31, 38);
        rounded(c, l, t, r, b, Math.min(12, (b - t) / 2f), bg);
        paint.setColor(enabled ? 0x334C6374 : 0x222E333D); paint.setStyle(Paint.Style.STROKE); paint.setStrokeWidth(1);
        c.drawRoundRect(l, t, r, b, Math.min(12, (b - t) / 2f), Math.min(12, (b - t) / 2f), paint); paint.setStyle(Paint.Style.FILL);
        text(c, label, (l + r) / 2f, (t + b) / 2f + size * 0.34f, size, enabled ? textColor : colorMuted, true, Paint.Align.CENTER);
        addTarget(kind, arg, l, t, r, b);
        targets[targetCount - 1].enabled = enabled;
    }

    private void addTarget(int kind, int arg, float l, float t, float r, float b) {
        if (targetCount >= targets.length) return;
        HitTarget target = targets[targetCount++];
        target.kind = kind; target.arg = arg; target.enabled = true;
        target.rect.set(l, t, r, b);
    }

    private void rounded(Canvas c, float l, float t, float r, float b, float radius, int color) {
        paint.setColor(color); paint.setStyle(Paint.Style.FILL); paint.setShader(null); paint.setAlpha(Color.alpha(color));
        c.drawRoundRect(l, t, r, b, radius, radius, paint); paint.setAlpha(255);
    }

    private void fill(Canvas c, float l, float t, float r, float b, int color) {
        paint.setColor(color); paint.setStyle(Paint.Style.FILL); paint.setShader(null); c.drawRect(l, t, r, b, paint);
    }

    private void text(Canvas c, String value, float x, float y, float size, int color, boolean bold, Paint.Align align) {
        Paint p = bold ? boldPaint : textPaint;
        p.setColor(color); p.setTextSize(size); p.setTextAlign(align); p.setAlpha(Color.alpha(color));
        c.drawText(value, x, y, p); p.setAlpha(255);
    }

    private int rarityColor(int rarity) {
        switch (rarity) {
            case 1: return Color.rgb(103, 205, 146);
            case 2: return Color.rgb(89, 172, 255);
            case 3: return Color.rgb(189, 117, 255);
            case 4: return Color.rgb(255, 190, 74);
            default: return Color.rgb(182, 189, 198);
        }
    }

    private int enemyColor(int type) {
        switch (type) {
            case GameEngine.BONECRAWLER: return Color.rgb(174, 176, 161);
            case GameEngine.VENOM_SPIDER: return Color.rgb(115, 142, 94);
            case GameEngine.HOLLOW_HOUND: return Color.rgb(152, 93, 89);
            case GameEngine.IRON_BRUTE: return Color.rgb(132, 103, 76);
            default: return Color.rgb(111, 122, 74);
        }
    }

    private String findMaterialName(String id) {
        for (int i = 0; i < engine.materialCountSize(); i++) if (engine.getMaterialInfoAt(i).id.equals(id)) return engine.getMaterialInfoAt(i).name;
        return id;
    }

    private String compact(long number) {
        if (number >= 1_000_000) return String.format(java.util.Locale.US, "%.1fM", number / 1_000_000.0);
        if (number >= 10_000) return String.format(java.util.Locale.US, "%.1fk", number / 1_000.0);
        return String.valueOf(number);
    }

    private String duration(int seconds) {
        int hours = seconds / 3600;
        int minutes = (seconds % 3600) / 60;
        if (hours > 0) return hours + "H " + minutes + "M";
        return Math.max(1, minutes) + " MINUTES";
    }

    private void notifyUser(String message) {
        toast = message;
        toastSeconds = 2.3f;
    }

    private void handleTarget(HitTarget t) {
        switch (t.kind) {
            case TARGET_NAV:
                tab = t.arg;
                if (tab == TAB_INVENTORY) materialPage = 0;
                break;
            case TARGET_APPEARANCE:
                engine.maleAppearance = !engine.maleAppearance;
                notifyUser(engine.maleAppearance ? "Male hunter selected" : "Female hunter selected");
                break;
            case TARGET_SFX:
                engine.soundEnabled = !engine.soundEnabled;
                saveListener.onAudioSettingsChanged();
                saveListener.saveCheckpoint();
                notifyUser(engine.soundEnabled ? "Sound effects on" : "Sound effects off");
                break;
            case TARGET_MUSIC:
                engine.musicEnabled = !engine.musicEnabled;
                saveListener.onAudioSettingsChanged();
                saveListener.saveCheckpoint();
                notifyUser(engine.musicEnabled ? "Ambient music on" : "Ambient music off");
                break;
            case TARGET_FPS:
                engine.lowPerformance = !engine.lowPerformance;
                saveListener.saveCheckpoint();
                notifyUser(engine.lowPerformance ? "Reduced rendering enabled · 30 FPS" : "Full rendering enabled · 60 FPS");
                break;
            case TARGET_UPGRADE:
                if (engine.buyUpgrade(t.arg)) {
                    saveListener.saveCheckpoint();
                    notifyUser("Upgrade purchased · stats improved");
                } else notifyUser(engine.getUpgradeLevel(t.arg) >= 50 ? "That stat is already maxed" : "Not enough gold");
                break;
            case TARGET_INVENTORY_MODE:
                forgeMode = t.arg == 1;
                break;
            case TARGET_PAGE:
                materialPage = Math.max(0, Math.min(1, materialPage + t.arg));
                break;
            case TARGET_SELL_ONE:
                if (engine.sellMaterial(engine.getMaterialInfoAt(t.arg).id, 1)) {
                    saveListener.saveCheckpoint(); notifyUser("Material sold");
                } else notifyUser("No parts available to sell");
                break;
            case TARGET_SELL_ALL:
                int count = engine.getMaterialCountAt(t.arg);
                if (count > 0 && engine.sellMaterial(engine.getMaterialInfoAt(t.arg).id, count)) {
                    saveListener.saveCheckpoint(); notifyUser("Parts sold · " + count + " recovered");
                } else notifyUser("No parts available to sell");
                break;
            case TARGET_GEAR:
                GameEngine.GearInfo gear = engine.getGearInfoAt(t.arg);
                if (engine.toggleGear(gear.id)) {
                    saveListener.saveCheckpoint();
                    notifyUser(engine.isGearOwnedAt(t.arg) ? (gear.id.equals(engine.gearEquippedId(gear.slot)) ? gear.name + " equipped" : gear.name + " unequipped") : "Forged " + gear.name);
                } else notifyUser("Missing gold or monster parts");
                break;
            case TARGET_GRAFT:
                if (engine.toggleGraft(t.arg)) {
                    saveListener.saveCheckpoint();
                    notifyUser(engine.isGraftEquipped(engine.getGraftInfoAt(t.arg).id) ? "Mutation implanted" : "Mutation removed");
                } else notifyUser("Harvest this organ first");
                break;
            case TARGET_CONTRACT:
                if (engine.claimContract(t.arg)) {
                    saveListener.saveCheckpoint(); notifyUser("Contract claimed · reward recovered");
                } else notifyUser("Contract objective is not complete yet");
                break;
            case TARGET_CLAIM_OFFLINE:
                if (engine.claimOfflineRewards()) {
                    saveListener.saveCheckpoint(); notifyUser("Offline salvage claimed");
                }
                break;
            default: break;
        }
        invalidate();
    }

    @Override public boolean onTouchEvent(MotionEvent event) {
        if (event.getAction() == MotionEvent.ACTION_UP) {
            performClick();
            float x = event.getX() / density;
            float y = event.getY() / density;
            for (int i = targetCount - 1; i >= 0; i--) {
                HitTarget t = targets[i];
                if (t.enabled && t.rect.contains(x, y)) {
                    handleTarget(t);
                    return true;
                }
            }
            return true;
        }
        return true;
    }

    @Override public boolean performClick() {
        super.performClick();
        return true;
    }

    @Override protected void onDetachedFromWindow() {
        stopLoop();
        super.onDetachedFromWindow();
    }

    private static final class HitTarget {
        final RectF rect = new RectF();
        int kind, arg;
        boolean enabled;
    }
}
