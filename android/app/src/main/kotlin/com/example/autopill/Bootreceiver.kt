package com.example.autopill

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

// Receiver này được gọi sau khi máy khởi động lại.
// AlarmManager bị xoá khi tắt máy → cần reschedule từ DB.
// Hiện tại log để xác nhận boot received.
// TODO: đọc schedules từ SQLite và gọi AlarmScheduler.schedule() lại cho từng cái.
class BootReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action ?: return
        if (action == Intent.ACTION_BOOT_COMPLETED ||
            action == "android.intent.action.QUICKBOOT_POWERON" ||
            action == "com.htc.intent.action.QUICKBOOT_POWERON") {

            Log.d("AutoPill", "Boot completed — reschedule alarms here")
            // Việc reschedule alarm sau boot cần chạy trong WorkManager hoặc
            // foreground service vì BroadcastReceiver có thời gian chạy giới hạn.
            // Cách đơn giản: mở app lần đầu sau boot sẽ tự reschedule qua Flutter.
        }
    }
}