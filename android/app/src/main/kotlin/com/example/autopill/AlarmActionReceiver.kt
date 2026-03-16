package com.example.autopill

import android.app.NotificationManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

class AlarmActionReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        val scheduleId = intent.getIntExtra("schedule_id", 0)
        val action     = intent.action ?: return

        Log.d("AutoPill", "AlarmAction: $action for schedule $scheduleId")

        // Dismiss notification
        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE)
                as NotificationManager
        nm.cancel(scheduleId)

        // Stop alarm sound using the static instance
        AlarmActivity.stopCurrentAlarm()

        when (action) {
            "ACTION_TAKEN" -> {
                // Mở app để ghi nhận đã uống
                // Dùng string class name để tránh Unresolved reference
                val flutterIntent = Intent().apply {
                    setClassName(context, "com.example.autopill.MainActivity")
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                            Intent.FLAG_ACTIVITY_SINGLE_TOP
                    putExtra("alarm_action",  action)
                    putExtra("schedule_id",   scheduleId)
                }
                context.startActivity(flutterIntent)
            }
            "ACTION_DISMISS" -> {
                // Chỉ dismiss notification và tắt alarm, không mở app
                Log.d("AutoPill", "Dismissed alarm for schedule $scheduleId")
            }
        }
    }
}