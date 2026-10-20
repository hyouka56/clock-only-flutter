package com.hyouka.clock

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "clock_only/alarm_scheduler")
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "canScheduleExactAlarms" -> result.success(ClockAlarmScheduler.canScheduleExactAlarms(this))
                        "requestExactAlarmAccess" -> {
                            val allowed = ClockAlarmScheduler.canScheduleExactAlarms(this)
                            if (!allowed && Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                                startActivity(Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM, Uri.parse("package:$packageName")))
                            }
                            result.success(allowed)
                        }
                        "scheduleAlarm" -> {
                            val id = call.argument<Int>("id") ?: error("Missing alarm ID")
                            val hour = call.argument<Int>("hour") ?: error("Missing alarm hour")
                            val minute = call.argument<Int>("minute") ?: error("Missing alarm minute")
                            val label = call.argument<String>("label") ?: ""
                            val days = (call.argument<List<*>>("days") ?: emptyList<Any>())
                                .filterIsInstance<Number>().map { it.toInt() }
                            ClockAlarmScheduler.scheduleAlarm(this, id, hour, minute, days, label)
                            result.success(true)
                        }
                        "cancelAlarm" -> {
                            val id = call.argument<Int>("id") ?: error("Missing alarm ID")
                            ClockAlarmScheduler.cancelAlarm(this, id)
                            result.success(null)
                        }
                        else -> result.notImplemented()
                    }
                } catch (error: Exception) {
                    result.error("ALARM_SCHEDULER_ERROR", error.message ?: "Alarm operation failed", null)
                }
            }
    }
}
