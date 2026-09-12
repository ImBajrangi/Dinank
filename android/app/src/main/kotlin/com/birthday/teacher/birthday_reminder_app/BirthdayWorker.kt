package com.birthday.teacher.birthday_reminder_app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.work.CoroutineWorker
import androidx.work.WorkerParameters

class BirthdayWorker(
    private val context: Context,
    params: WorkerParameters
) : CoroutineWorker(context, params) {

    companion object {
        const val CHANNEL_ID = "TEACHER_BIRTHDAY_CHANNEL"
        const val CHANNEL_NAME = "Student Birthday Reminders"
        const val NOTIFICATION_ID = 8801
    }

    override suspend fun doWork(): Result {
        try {
            val dbHelper = NativeDatabaseHelper(context)
            val todayBirthdays = dbHelper.getTodayBirthdays()

            if (todayBirthdays.isNotEmpty()) {
                showBirthdayNotification(todayBirthdays)
            }
            return Result.success()
        } catch (e: Exception) {
            e.printStackTrace()
            return Result.retry()
        }
    }

    private fun showBirthdayNotification(students: List<StudentBirthday>) {
        val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        // Create Notification Channel for Android O and above
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                CHANNEL_NAME,
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Daily reminders for student birthdays to help teachers send wishes"
                enableVibration(true)
                enableLights(true)
            }
            notificationManager.createNotificationChannel(channel)
        }

        val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)?.apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }

        val pendingIntent = PendingIntent.getActivity(
            context,
            0,
            launchIntent,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
            } else {
                PendingIntent.FLAG_UPDATE_CURRENT
            }
        )

        val count = students.size
        val title = if (count == 1) {
            "🎂 Today is ${students.first().name}'s Birthday!"
        } else {
            "🎂 $count Students Celebrating Birthday Today!"
        }

        val namesSummary = students.joinToString(", ") { student ->
            if (!student.groupClass.isNullOrEmpty()) {
                "${student.name} (${student.groupClass})"
            } else {
                student.name
            }
        }

        val bigText = buildString {
            append("Wish your students on their special day:\n")
            students.forEachIndexed { index, s ->
                val rollInfo = if (!s.rollNo.isNullOrEmpty()) " [Roll #${s.rollNo}]" else ""
                val classInfo = if (!s.groupClass.isNullOrEmpty()) " - ${s.groupClass}" else ""
                append("${index + 1}. ${s.name}$rollInfo$classInfo\n")
            }
            append("\nTap to open and send WhatsApp greetings or make a call!")
        }

        val smallIconRes = context.resources.getIdentifier("ic_launcher", "mipmap", context.packageName)
        val icon = if (smallIconRes != 0) smallIconRes else android.R.drawable.ic_dialog_info

        val builder = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(icon)
            .setContentTitle(title)
            .setContentText(namesSummary)
            .setStyle(NotificationCompat.BigTextStyle().bigText(bigText))
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_REMINDER)
            .setContentIntent(pendingIntent)
            .setAutoCancel(true)
            .setDefaults(NotificationCompat.DEFAULT_ALL)

        notificationManager.notify(NOTIFICATION_ID, builder.build())
    }
}
