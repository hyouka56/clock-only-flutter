package com.hyouka.clock

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import java.util.Calendar

internal object ClockAlarmScheduler {
    fun canScheduleExactAlarms(context: Context): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return true
        val manager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        return manager.canScheduleExactAlarms()
    }

    fun scheduleAlarm(context: Context, id: Int, hour: Int, minute: Int, days: List<Int>, label: String) {
        if (!canScheduleExactAlarms(context)) {
            throw SecurityException("Exact alarm access is not enabled")
        }
        val manager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        cancelRegularOccurrences(context, manager, id)
        if (days.isEmpty()) {
            val requestCode = id * 10 + 8
            scheduleInstance(context, requestCode, id, hour, minute, 0, label, nextTriggerAt(hour, minute, 0))
        } else {
            days.distinct().filter { it in 1..7 }.sorted().forEach { day ->
                val requestCode = id * 10 + day
                scheduleInstance(context, requestCode, id, hour, minute, day, label, nextTriggerAt(hour, minute, day))
            }
        }
    }

    fun scheduleNextOccurrence(context: Context, requestCode: Int, id: Int, hour: Int, minute: Int, day: Int, label: String) {
        if (day !in 1..7 || !canScheduleExactAlarms(context)) return
        scheduleInstance(context, requestCode, id, hour, minute, day, label, nextTriggerAt(hour, minute, day))
    }

    fun scheduleSnooze(context: Context, id: Int, label: String): Boolean {
        if (!canScheduleExactAlarms(context)) return false
        val requestCode = snoozeRequestCode(id)
        val triggerAt = System.currentTimeMillis() + 5 * 60 * 1000L
        scheduleInstance(context, requestCode, id, 0, 0, 0, label, triggerAt)
        return true
    }

    fun cancelAlarm(context: Context, id: Int) {
        val manager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        cancelRegularOccurrences(context, manager, id)
        cancelPendingIntent(context, manager, snoozeRequestCode(id))
    }

    private fun cancelRegularOccurrences(context: Context, manager: AlarmManager, id: Int) {
        for (day in 1..8) {
            cancelPendingIntent(context, manager, id * 10 + day)
        }
    }

    private fun cancelPendingIntent(context: Context, manager: AlarmManager, requestCode: Int) {
        val intent = Intent(context, AlarmActivity::class.java).apply {
            action = alarmAction(context, requestCode)
        }
        val pending = PendingIntent.getActivity(
            context, requestCode, intent,
            PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE
        )
        if (pending != null) {
            manager.cancel(pending)
            pending.cancel()
        }
    }

    private fun snoozeRequestCode(id: Int): Int = id * 100 + 99

    private fun scheduleInstance(context: Context, requestCode: Int, id: Int, hour: Int, minute: Int, day: Int, label: String, triggerAt: Long) {
        val manager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val intent = Intent(context, AlarmActivity::class.java).apply {
            action = alarmAction(context, requestCode)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
            putExtra(AlarmActivity.EXTRA_ALARM_ID, id)
            putExtra(AlarmActivity.EXTRA_REQUEST_CODE, requestCode)
            putExtra(AlarmActivity.EXTRA_HOUR, hour)
            putExtra(AlarmActivity.EXTRA_MINUTE, minute)
            putExtra(AlarmActivity.EXTRA_REPEAT_DAY, day)
            putExtra(AlarmActivity.EXTRA_LABEL, label)
        }
        val operation = PendingIntent.getActivity(context, requestCode, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
        val showIntent = if (launchIntent != null) {
            PendingIntent.getActivity(context, 0, launchIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        } else operation
        manager.setAlarmClock(AlarmManager.AlarmClockInfo(triggerAt, showIntent), operation)
    }

    private fun alarmAction(context: Context, requestCode: Int): String = "${context.packageName}.ALARM.$requestCode"

    private fun nextTriggerAt(hour: Int, minute: Int, day: Int): Long {
        val calendar = Calendar.getInstance()
        val now = calendar.timeInMillis
        calendar.set(Calendar.HOUR_OF_DAY, hour)
        calendar.set(Calendar.MINUTE, minute)
        calendar.set(Calendar.SECOND, 0)
        calendar.set(Calendar.MILLISECOND, 0)
        if (day in 1..7) {
            val targetDay = if (day == 7) Calendar.SUNDAY else day + 1
            while (calendar.get(Calendar.DAY_OF_WEEK) != targetDay || calendar.timeInMillis <= now) {
                calendar.add(Calendar.DAY_OF_YEAR, 1)
            }
        } else if (calendar.timeInMillis <= now) {
            calendar.add(Calendar.DAY_OF_YEAR, 1)
        }
        return calendar.timeInMillis
    }
}
