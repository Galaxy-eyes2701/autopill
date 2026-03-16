package com.example.autopill

import android.content.Intent
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    companion object {
        const val ALARM_CHANNEL = "com.example.autopill/alarm"
    }

    private var methodChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        methodChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            ALARM_CHANNEL
        )

        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {

                "scheduleAlarm" -> {
                    val notifId      = call.argument<Int>("notifId")      ?: 0
                    val scheduleId   = call.argument<Int>("scheduleId")   ?: 0
                    val medicineName = call.argument<String>("medicineName") ?: ""
                    val doseLabel    = call.argument<String>("doseLabel")    ?: ""
                    val time         = call.argument<String>("time")         ?: ""
                    // Long có thể được gửi từ Dart dưới dạng Int hoặc Long
                    val triggerAtMs: Long = when (val raw = call.argument<Any>("triggerAtMs")) {
                        is Long -> raw
                        is Int  -> raw.toLong()
                        else    -> 0L
                    }

                    AlarmScheduler.schedule(
                        context      = this,
                        notifId      = notifId,
                        scheduleId   = scheduleId,
                        medicineName = medicineName,
                        doseLabel    = doseLabel,
                        time         = time,
                        triggerAtMs  = triggerAtMs,
                    )
                    result.success(true)
                }

                "cancelAlarm" -> {
                    val notifId = call.argument<Int>("notifId") ?: 0
                    AlarmScheduler.cancel(this, notifId)
                    result.success(true)
                }

                "stopAlarm" -> {
                    // Stop the alarm sound by calling the static method
                    AlarmActivity.stopCurrentAlarm()
                    result.success(true)
                }

                "canScheduleExactAlarms" -> {
                    val am = getSystemService(ALARM_SERVICE) as android.app.AlarmManager
                    val can = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                        am.canScheduleExactAlarms()
                    } else {
                        true
                    }
                    result.success(can)
                }

                else -> result.notImplemented()
            }
        }
    }

    // Nhận alarm_action từ AlarmActionReceiver khi user tap "Đã uống"
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        val action     = intent.getStringExtra("alarm_action")  ?: return
        val scheduleId = intent.getIntExtra("schedule_id", 0)

        methodChannel?.invokeMethod(
            "onAlarmAction",
            mapOf("action" to action, "scheduleId" to scheduleId)
        )
    }
}