package com.hyouka.clock

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import org.json.JSONArray

class AlarmBootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action ?: return
        if (action !in setOf(Intent.ACTION_BOOT_COMPLETED, Intent.ACTION_MY_PACKAGE_REPLACED, Intent.ACTION_TIME_CHANGED, Intent.ACTION_TIMEZONE_CHANGED, "android.intent.action.QUICKBOOT_POWERON", "com.htc.intent.action.QUICKBOOT_POWERON")) return
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val saved = prefs.getString("flutter.clock_alarms_v1", null) ?: return
        try {
            val items = JSONArray(saved)
            for (index in 0 until items.length()) {
                val item = items.optJSONObject(index) ?: continue
                if (!item.optBoolean("enabled", true)) continue
                val id = item.optInt("id", -1)
                val hour = item.optInt("hour", -1)
                val minute = item.optInt("minute", -1)
                if (id < 0 || hour !in 0..23 || minute !in 0..59) continue
                val dayArray = item.optJSONArray("days")
                val days = mutableListOf<Int>()
                if (dayArray != null) {
                    for (dayIndex in 0 until dayArray.length()) {
                        val day = dayArray.optInt(dayIndex, -1)
                        if (day in 1..7) days.add(day)
                    }
                }
                try {
                    ClockAlarmScheduler.scheduleAlarm(context, id, hour, minute, days, item.optString("label", ""))
                } catch (_: Exception) { }
            }
        } catch (_: Exception) { }
    }
}
