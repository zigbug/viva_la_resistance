package dev.amirzr.singbox.example

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import dev.amirzr.singbox.receivers.BootReceiver

class BootRestartReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        if (intent?.action != BootReceiver.ACTION_DEVICE_BOOTED) return
        val launch = context.packageManager
            .getLaunchIntentForPackage(context.packageName)
            ?: return
        launch.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        launch.putExtra("boot_restart", true)
        context.startActivity(launch)
    }
}
