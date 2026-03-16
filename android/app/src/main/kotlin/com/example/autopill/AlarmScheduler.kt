package com.example.autopill

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log

object AlarmScheduler {

    fun schedule(
        context:      Context,
        notifId:      Int,
        scheduleId:   Int,
        medicineName: String,
        doseLabel:    String,
        time:         String,
        triggerAtMs:  Long,
    ) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE)
                as AlarmManager

        val intent = Intent(context, AlarmReceiver::class.java).apply {
            action = "AUTOPILL_ALARM"
            putExtra("schedule_id",   scheduleId)
            putExtra("medicine_name", medicineName)
            putExtra("dose_label",    doseLabel)
            putExtra("time",          time)
        }

        val pendingIntent = PendingIntent.getBroadcast(
            context, notifId, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                if (alarmManager.canScheduleExactAlarms()) {
                    alarmManager.setExactAndAllowWhileIdle(
                        AlarmManager.RTC_WAKEUP, triggerAtMs, pendingIntent
                    )
                    Log.d("AutoPill", "Exact alarm scheduled: notifId=$notifId")
                } else {
                    alarmManager.setAndAllowWhileIdle(
                        AlarmManager.RTC_WAKEUP, triggerAtMs, pendingIntent
                    )
                    Log.d("AutoPill", "Inexact alarm scheduled: notifId=$notifId")
                }
            } else {
                alarmManager.setExactAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP, triggerAtMs, pendingIntent
                )
                Log.d("AutoPill", "Alarm scheduled: notifId=$notifId")
            }
        } catch (e: SecurityException) {
            alarmManager.setAndAllowWhileIdle(
                AlarmManager.RTC_WAKEUP, triggerAtMs, pendingIntent
            )
            Log.w("AutoPill", "SecurityException, using inexact: ${e.message}")
        }
    }

    fun cancel(context: Context, notifId: Int) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE)
                as AlarmManager

        val intent = Intent(context, AlarmReceiver::class.java)
        val pendingIntent = PendingIntent.getBroadcast(
            context, notifId, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        alarmManager.cancel(pendingIntent)
        Log.d("AutoPill", "Alarm cancelled: notifId=$notifId")
    }
}