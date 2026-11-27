package dev.amirzr.singbox.service

import android.content.Context

internal object ServiceConfigStore {

    private const val PREFS_NAME = "singbox_service_state"
    private const val KEY_ACTIVE_CONFIG = "active_session_options_json"

    fun save(context: Context, configJson: String) {
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .putString(KEY_ACTIVE_CONFIG, configJson)
            .apply()
    }

    fun load(context: Context): String? {
        return context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .getString(KEY_ACTIVE_CONFIG, null)
    }

    fun clear(context: Context) {
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .remove(KEY_ACTIVE_CONFIG)
            .apply()
    }
}
