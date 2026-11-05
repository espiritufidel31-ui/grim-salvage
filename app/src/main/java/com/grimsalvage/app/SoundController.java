package com.grimsalvage.app;

import android.content.Context;
import android.media.AudioAttributes;
import android.media.MediaPlayer;
import android.media.SoundPool;

final class SoundController {
    private final SoundPool pool;
    private final int hit, coin, rare, boss;
    private final MediaPlayer music;
    private boolean resumed;
    private boolean musicEnabled;
    private boolean effectsEnabled = true;

    SoundController(Context context) {
        AudioAttributes attributes = new AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_GAME)
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .build();
        pool = new SoundPool.Builder().setMaxStreams(5).setAudioAttributes(attributes).build();
        hit = pool.load(context, R.raw.sfx_hit, 1);
        coin = pool.load(context, R.raw.sfx_coin, 1);
        rare = pool.load(context, R.raw.sfx_rare, 1);
        boss = pool.load(context, R.raw.sfx_boss, 1);
        music = MediaPlayer.create(context, R.raw.ambient);
        if (music != null) music.setLooping(true);
    }

    void setSettings(boolean effects, boolean musicOn) {
        effectsEnabled = effects;
        musicEnabled = musicOn;
        syncMusic();
    }

    void setResumed(boolean value) {
        resumed = value;
        syncMusic();
    }

    void playEvent(int event) {
        if (!effectsEnabled) return;
        switch (event) {
            case GameEngine.EVENT_HIT: play(hit, 0.42f); break;
            case GameEngine.EVENT_KILL: play(coin, 0.55f); break;
            case GameEngine.EVENT_RARE_LOOT: play(rare, 0.8f); break;
            case GameEngine.EVENT_BOSS: play(boss, 0.72f); break;
            case GameEngine.EVENT_UPGRADE:
            case GameEngine.EVENT_CRAFT: play(coin, 0.75f); break;
            default: break;
        }
    }

    private void play(int id, float volume) {
        if (id != 0) pool.play(id, volume, volume, 1, 0, 1f);
    }

    private void syncMusic() {
        if (music == null) return;
        if (resumed && musicEnabled) {
            if (!music.isPlaying()) music.start();
        } else if (music.isPlaying()) {
            music.pause();
            music.seekTo(0);
        }
    }

    void release() {
        if (music != null) music.release();
        pool.release();
    }
}
