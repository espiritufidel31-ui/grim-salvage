package com.grimsalvage.app;

import android.content.Context;
import android.content.SharedPreferences;

final class SaveRepository {
    private static final String PREFS = "grim_salvage_save";
    private static final String STATE = "state_v2";

    private SaveRepository() { }

    static GameEngine load(Context context) {
        SharedPreferences preferences = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE);
        return GameEngine.decode(preferences.getString(STATE, ""));
    }

    static void save(Context context, GameEngine engine) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                .edit()
                .putString(STATE, engine.encode())
                .commit();
    }
}
