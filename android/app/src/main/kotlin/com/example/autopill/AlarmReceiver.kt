package com.example.autopill

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat

class AlarmReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        val medicineName = intent.getStringExtra("medicine_name") ?: "Thuốc"
        val doseLabel    = intent.getStringExtra("dose_label")    ?: ""
        val time         = intent.getStringExtra("time")          ?: ""
        val scheduleId   = intent.getIntExtra("schedule_id", 0)

        // ── Full-screen intent → mở AlarmActivity khi màn hình tắt ─────
        val fullScreenIntent = Intent(context, AlarmActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_CLEAR_TOP or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP
            putExtra("medicine_name", medicineName)
            putExtra("dose_label",    doseLabel)
            putExtra("time",          time)
            putExtra("schedule_id",   scheduleId)
        }
        val fullScreenPendingIntent = PendingIntent.getActivity(
            context, scheduleId,
            fullScreenIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // ── Tap notification → mở MainActivity ──────────────────────────
        val tapIntent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val tapPendingIntent = PendingIntent.getActivity(
            context, scheduleId + 10000, tapIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // ── Nút "Bỏ qua" ────────────────────────────────────────────────
        val dismissIntent = Intent(context, AlarmActionReceiver::class.java).apply {
            action = "ACTION_DISMISS"
            putExtra("schedule_id", scheduleId)
        }
        val dismissPendingIntent = PendingIntent.getBroadcast(
            context, scheduleId + 30000, dismissIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // ── Tạo Notification Channel ─────────────────────────────────────
        val channelId = "autopill_alarm"
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                channelId,
                "Báo thức uống thuốc",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Nhắc uống thuốc kiểu báo thức"
                // Dùng setter method đúng cú pháp Kotlin
                setShowBadge(true)
                lockscreenVisibility = NotificationCompat.VISIBILITY_PUBLIC
            }
            // enableVibration phải dùng method call, không phải property
            channel.enableVibration(true)
            channel.vibrationPattern = longArrayOf(0, 1000, 500, 1000)

            val nm = context.getSystemService(Context.NOTIFICATION_SERVICE)
                    as NotificationManager
            nm.createNotificationChannel(channel)
        }

        // ── Build Notification ────────────────────────────────────────────
        val body = if (doseLabel.isNotEmpty()) "$doseLabel lúc $time" else "lúc $time"

        val notification = androidx.core.app.NotificationCompat.Builder(context, channelId)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentTitle("💊 Đến giờ uống thuốc!")
            .setContentText("$medicineName — $body")
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setAutoCancel(false)
            .setOngoing(true)
            .setFullScreenIntent(fullScreenPendingIntent, true)
            .setContentIntent(tapPendingIntent)
            .addAction(android.R.drawable.ic_menu_close_clear_cancel, "Bỏ qua", dismissPendingIntent)
            .build()

        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE)
                as NotificationManager
        nm.notify(scheduleId, notification)
    }
}