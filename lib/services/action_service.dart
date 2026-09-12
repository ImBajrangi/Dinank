import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/student_model.dart';
import 'toast_service.dart';

class ActionService {
  static String formatGreetingTemplate(
    String template,
    StudentModel student, {
    String teacherName = "Teacher",
  }) {
    String text = template;
    text = text.replaceAll('{name}', student.name);
    text = text.replaceAll('{class}', student.groupClass ?? 'our class');
    text = text.replaceAll('{roll}', student.rollNo ?? '');
    text = text.replaceAll('{age}', student.turningAge.toString());
    text = text.replaceAll('{teacher}', teacherName);
    text = text.replaceAll('{teacher_name}', teacherName);
    text = text.replaceAll('{dob}', student.formattedBirthdayDayMonth);
    return text;
  }

  static Future<bool> sendWhatsAppWish(
    StudentModel student, {
    required String template,
    String teacherName = "Teacher",
    BuildContext? context,
  }) async {
    final phone = student.phone;
    final message = formatGreetingTemplate(template, student, teacherName: teacherName);

    if (phone == null || phone.isEmpty) {
      if (context != null) {
        AppToast.showWarning(
          context,
          title: "Missing Phone Number",
          message: "No phone recorded for ${student.name}. Add it to wish via WhatsApp.",
        );
      }
      return false;
    }

    final cleanDigits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    final encodedMessage = Uri.encodeComponent(message);

    // Try custom scheme first then fallback to wa.me
    final nativeUri = Uri.parse("whatsapp://send?phone=$cleanDigits&text=$encodedMessage");
    final webUri = Uri.parse("https://wa.me/$cleanDigits?text=$encodedMessage");

    if (context != null) {
      AppToast.showWhatsApp(
        context,
        title: "Launching WhatsApp...",
        message: "Sending birthday greeting to ${student.name}",
        icon: Icons.chat_bubble_rounded,
      );
    }

    try {
      if (await canLaunchUrl(nativeUri)) {
        return await launchUrl(nativeUri, mode: LaunchMode.externalApplication);
      } else if (await canLaunchUrl(webUri)) {
        return await launchUrl(webUri, mode: LaunchMode.externalApplication);
      } else {
        if (context != null && context.mounted) {
          AppToast.showError(
            context,
            title: "WhatsApp Unavailable",
            message: "WhatsApp is not installed on this device.",
          );
        }
        return false;
      }
    } catch (e) {
      debugPrint("WhatsApp Launch error: $e");
      return false;
    }
  }

  static Future<bool> sendParentWhatsAppWish(
    StudentModel student, {
    required String parentTemplate,
    String teacherName = "Teacher",
    BuildContext? context,
  }) async {
    final phone = student.parentPhone ?? student.phone;
    final message = formatGreetingTemplate(parentTemplate, student, teacherName: teacherName);

    if (phone == null || phone.isEmpty) {
      if (context != null) {
        AppToast.showWarning(
          context,
          title: "Missing Parent Contact",
          message: "No parent phone found for ${student.name}.",
        );
      }
      return false;
    }

    final cleanDigits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    final encodedMessage = Uri.encodeComponent(message);

    final nativeUri = Uri.parse("whatsapp://send?phone=$cleanDigits&text=$encodedMessage");
    final webUri = Uri.parse("https://wa.me/$cleanDigits?text=$encodedMessage");

    if (context != null) {
      AppToast.showWhatsApp(
        context,
        title: "Contacting Parents...",
        message: "Sending warm blessings to ${student.name}'s parents",
        icon: Icons.family_restroom_rounded,
      );
    }

    try {
      if (await canLaunchUrl(nativeUri)) {
        return await launchUrl(nativeUri, mode: LaunchMode.externalApplication);
      } else if (await canLaunchUrl(webUri)) {
        return await launchUrl(webUri, mode: LaunchMode.externalApplication);
      } else {
        return false;
      }
    } catch (e) {
      debugPrint("Parent WhatsApp Launch error: $e");
      return false;
    }
  }

  static Future<bool> makePhoneCall(String? phone, {BuildContext? context}) async {
    if (phone == null || phone.trim().isEmpty) {
      if (context != null) {
        AppToast.showWarning(
          context,
          title: "No Contact Number",
          message: "No phone number recorded for this student.",
        );
      }
      return false;
    }

    final uri = Uri.parse("tel:${phone.trim()}");
    try {
      if (await canLaunchUrl(uri)) {
        return await launchUrl(uri);
      } else {
        return false;
      }
    } catch (e) {
      debugPrint("Phone call error: $e");
      return false;
    }
  }

  static Future<bool> sendSms(String? phone, String message, {BuildContext? context}) async {
    if (phone == null || phone.trim().isEmpty) return false;
    final uri = Uri.parse("sms:${phone.trim()}?body=${Uri.encodeComponent(message)}");
    try {
      if (await canLaunchUrl(uri)) {
        return await launchUrl(uri);
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  static Future<void> shareWishText(StudentModel student, String message) async {
    await SharePlus.instance.share(
      ShareParams(
        text: message,
        subject: "Happy Birthday ${student.name}! 🎂",
      ),
    );
  }
}
