package com.grimsalvage.app;

import android.app.Activity;
import android.os.Bundle;
import android.view.Window;

public final class MainActivity extends Activity implements GameView.SaveListener {
    private GameEngine engine;
    private GameView gameView;
    private SoundController soundController;

    @Override protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        Window window = getWindow();
        window.setStatusBarColor(0xFF080A0F);
        window.setNavigationBarColor(0xFF080A0F);
        engine = SaveRepository.load(this);
        engine.prepareOfflineRewards(System.currentTimeMillis());
        soundController = new SoundController(this);
        soundController.setSettings(engine.soundEnabled, engine.musicEnabled);
        gameView = new GameView(this, engine, soundController, this);
        setContentView(gameView);
        saveCheckpoint();
    }

    @Override protected void onResume() {
        super.onResume();
        if (gameView != null) gameView.startLoop();
        if (soundController != null) soundController.setResumed(true);
    }

    @Override protected void onPause() {
        if (gameView != null) gameView.stopLoop();
        if (soundController != null) soundController.setResumed(false);
        saveCheckpoint();
        super.onPause();
    }

    @Override protected void onDestroy() {
        if (soundController != null) soundController.release();
        super.onDestroy();
    }

    @Override public void saveCheckpoint() {
        if (engine == null) return;
        engine.checkpoint(System.currentTimeMillis());
        SaveRepository.save(this, engine);
    }

    @Override public void onAudioSettingsChanged() {
        if (soundController != null) soundController.setSettings(engine.soundEnabled, engine.musicEnabled);
    }
}
