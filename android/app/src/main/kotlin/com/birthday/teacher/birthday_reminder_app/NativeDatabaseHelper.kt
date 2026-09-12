package com.birthday.teacher.birthday_reminder_app

import android.content.Context
import android.database.sqlite.SQLiteDatabase
import java.io.File
import java.util.Calendar

data class StudentBirthday(
    val id: Int,
    val name: String,
    val rollNo: String?,
    val groupClass: String?,
    val phone: String?,
    val dob: String
)

class NativeDatabaseHelper(private val context: Context) {

    fun getTodayBirthdays(): List<StudentBirthday> {
        val list = mutableListOf<StudentBirthday>()
        val dbFile = context.getDatabasePath("birthdays.db")
        if (!dbFile.exists()) {
            return list
        }

        var db: SQLiteDatabase? = null
        try {
            db = SQLiteDatabase.openDatabase(
                dbFile.absolutePath,
                null,
                SQLiteDatabase.OPEN_READONLY
            )

            val calendar = Calendar.getInstance()
            val currentMonth = calendar.get(Calendar.MONTH) + 1 // 1-12
            val currentDay = calendar.get(Calendar.DAY_OF_MONTH) // 1-31

            val query = "SELECT id, name, roll_no, group_class, phone, dob FROM students WHERE dob_month = ? AND dob_day = ?"
            val cursor = db.rawQuery(query, arrayOf(currentMonth.toString(), currentDay.toString()))

            if (cursor.moveToFirst()) {
                do {
                    val id = cursor.getInt(cursor.getColumnIndexOrThrow("id"))
                    val name = cursor.getString(cursor.getColumnIndexOrThrow("name"))
                    val rollNo = if (cursor.isNull(cursor.getColumnIndexOrThrow("roll_no"))) null else cursor.getString(cursor.getColumnIndexOrThrow("roll_no"))
                    val groupClass = if (cursor.isNull(cursor.getColumnIndexOrThrow("group_class"))) null else cursor.getString(cursor.getColumnIndexOrThrow("group_class"))
                    val phone = if (cursor.isNull(cursor.getColumnIndexOrThrow("phone"))) null else cursor.getString(cursor.getColumnIndexOrThrow("phone"))
                    val dob = cursor.getString(cursor.getColumnIndexOrThrow("dob"))

                    list.add(
                        StudentBirthday(
                            id = id,
                            name = name,
                            rollNo = rollNo,
                            groupClass = groupClass,
                            phone = phone,
                            dob = dob
                        )
                    )
                } while (cursor.moveToNext())
            }
            cursor.close()
        } catch (e: Exception) {
            e.printStackTrace()
        } finally {
            db?.close()
        }

        return list
    }
}
