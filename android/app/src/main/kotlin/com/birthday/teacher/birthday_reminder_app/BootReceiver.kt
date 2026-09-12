package com.birthday.teacher.birthday_reminder_app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import java.util.Calendar
import java.util.concurrent.TimeUnit

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED || intent.action == Intent.ACTION_MY_PACKAGE_REPLACED) {
            scheduleDailyBirthdayWorker(context)
        }
    }

    companion object {
        fun scheduleDailyBirthdayWorker(context: Context, targetHour: Int = 8, targetMinute: Int = 0) {
            val initialDelay = calculateInitialDelay(targetHour, targetMinute)

            val workRequest = PeriodicWorkRequestBuilder<BirthdayWorker>(24, TimeUnit.HOURS)
                .setInitialDelay(initialDelay, TimeUnit.MILLISECONDS)
                .build()

            WorkManager.getInstance(context).enqueueUniquePeriodicWork(
                "TeacherDailyBirthdayWorker",
                ExistingPeriodicWorkPolicy.UPDATE,
                workRequest
            )
        }

        private fun calculateInitialDelay(hour: Int, minute: Int): Long {
            val now = Calendar.getInstance()
            val target = Calendar.getInstance().apply {
                set(Calendar.HOUR_OF_DAY, hour)
                set(Calendar.MINUTE, minute)
                set(Calendar.SECOND, 0)
                set(Calendar.MILLISECOND, 0)
            }

            if (target.before(now)) {
                target.add(Calendar.DAY_OF_YEAR, 1)
            }

            return target.timeInMillis - now.timeInMillis
        }
    }
}
