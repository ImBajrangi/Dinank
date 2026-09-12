import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

enum ToastType {
  birthday,
  success,
  whatsapp,
  info,
  warning,
  error,
  copied,
}

class AppToast {
  static OverlayEntry? _currentEntry;
  static Timer? _dismissTimer;

  static void show(
    BuildContext context, {
    required String title,
    String? message,
    String? badgeTag,
    ToastType type = ToastType.info,
    IconData? icon,
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = const Duration(milliseconds: 3400),
  }) {
    HapticFeedback.mediumImpact();

    // Dismiss existing toast immediately if active
    _dismissTimer?.cancel();
    _currentEntry?.remove();
    _currentEntry = null;

    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return;

    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (ctx) => _ToastWidget(
        title: title,
        message: message,
        badgeTag: badgeTag,
        type: type,
        icon: icon,
        actionLabel: actionLabel,
        onAction: onAction,
        duration: duration,
        onDismiss: () {
          _dismissTimer?.cancel();
          if (_currentEntry == entry) {
            entry.remove();
            _currentEntry = null;
          }
        },
      ),
    );

    _currentEntry = entry;
    overlay.insert(entry);

    _dismissTimer = Timer(duration + const Duration(milliseconds: 600), () {
      if (_currentEntry == entry) {
        entry.remove();
        _currentEntry = null;
      }
    });
  }

  /// Show a vibrant birthday alert toast
  static void showBirthday(
    BuildContext context, {
    required String studentName,
    String? groupClass,
    VoidCallback? onWish,
  }) {
    show(
      context,
      title: "Birthday Celebration",
      badgeTag: "DAY MAKER",
      message: "$studentName ${groupClass != null ? '($groupClass)' : ''} is celebrating today! Send a warm wish.",
      type: ToastType.birthday,
      icon: Icons.cake_rounded,
      actionLabel: onWish != null ? "Wish Now" : null,
      onAction: onWish,
      duration: const Duration(milliseconds: 4500),
    );
  }

  /// Show WhatsApp action toast
  static void showWhatsApp(
    BuildContext context, {
    required String title,
    String? message,
    IconData? icon,
  }) {
    show(
      context,
      title: title,
      badgeTag: "WHATSAPP",
      message: message,
      type: ToastType.whatsapp,
      icon: icon ?? Icons.chat_rounded,
    );
  }

  /// Show success toast
  static void showSuccess(
    BuildContext context, {
    required String title,
    String? message,
    String? badgeTag,
    IconData? icon,
    String? actionLabel,
    VoidCallback? onAction,
    Duration? duration,
  }) {
    show(
      context,
      title: title,
      badgeTag: badgeTag ?? "SUCCESS",
      message: message,
      type: ToastType.success,
      icon: icon ?? Icons.check_circle_rounded,
      actionLabel: actionLabel,
      onAction: onAction,
      duration: duration ?? const Duration(milliseconds: 3400),
    );
  }

  /// Show clipboard copied toast
  static void showCopied(
    BuildContext context, {
    required String text,
    String title = "Copied to Clipboard",
    Duration? duration,
  }) {
    show(
      context,
      title: title,
      badgeTag: "CLIPBOARD",
      message: text,
      type: ToastType.copied,
      icon: Icons.copy_rounded,
      duration: duration ?? const Duration(milliseconds: 2500),
    );
  }

  /// Show info toast
  static void showInfo(
    BuildContext context, {
    required String title,
    String? message,
    String? badgeTag,
    IconData? icon,
    Duration? duration,
  }) {
    show(
      context,
      title: title,
      badgeTag: badgeTag ?? "INFO",
      message: message,
      type: ToastType.info,
      icon: icon ?? Icons.info_outline_rounded,
      duration: duration ?? const Duration(milliseconds: 3400),
    );
  }

  /// Show warning toast
  static void showWarning(
    BuildContext context, {
    required String title,
    String? message,
    String? badgeTag,
    IconData? icon,
    Duration? duration,
  }) {
    show(
      context,
      title: title,
      badgeTag: badgeTag ?? "ATTENTION",
      message: message,
      type: ToastType.warning,
      icon: icon ?? Icons.warning_amber_rounded,
      duration: duration ?? const Duration(milliseconds: 3600),
    );
  }

  /// Show error toast
  static void showError(
    BuildContext context, {
    required String title,
    String? message,
    String? badgeTag,
    IconData? icon,
    Duration? duration,
  }) {
    show(
      context,
      title: title,
      badgeTag: badgeTag ?? "ERROR",
      message: message,
      type: ToastType.error,
      icon: icon ?? Icons.error_outline_rounded,
      duration: duration ?? const Duration(milliseconds: 4000),
    );
  }
}

class _ToastWidget extends StatefulWidget {
  final String title;
  final String? message;
  final String? badgeTag;
  final ToastType type;
  final IconData? icon;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Duration duration;
  final VoidCallback onDismiss;

  const _ToastWidget({
    required this.title,
    this.message,
    this.badgeTag,
    required this.type,
    this.icon,
    this.actionLabel,
    this.onAction,
    required this.duration,
    required this.onDismiss,
  });

  @override
  State<_ToastWidget> createState() => _ToastWidgetState();
}

class _ToastWidgetState extends State<_ToastWidget> with TickerProviderStateMixin {
  late AnimationController _animController;
  late AnimationController _progressController;
  late Animation<double> _slideAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  Timer? _autoHideTimer;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );

    _progressController = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    _slideAnimation = Tween<double>(begin: -1.0, end: 0.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutBack),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );

    _scaleAnimation = Tween<double>(begin: 0.88, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutBack),
    );

    _animController.forward();
    _progressController.forward();

    _autoHideTimer = Timer(widget.duration, () {
      _dismissWithAnimation();
    });
  }

  void _dismissWithAnimation() {
    if (!mounted) return;
    _animController.reverse().then((_) {
      widget.onDismiss();
    });
  }

  @override
  void dispose() {
    _autoHideTimer?.cancel();
    _animController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final config = _getToastConfig(widget.type, isDark);

    return Positioned(
      top: topPadding + 10,
      left: 14,
      right: 14,
      child: Material(
        color: Colors.transparent,
        child: AnimatedBuilder(
          animation: _animController,
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(0, _slideAnimation.value * 70),
              child: Transform.scale(
                scale: _scaleAnimation.value,
                child: Opacity(
                  opacity: _fadeAnimation.value.clamp(0.0, 1.0),
                  child: child,
                ),
              ),
            );
          },
          child: Dismissible(
            key: UniqueKey(),
            direction: DismissDirection.horizontal,
            onDismissed: (_) => widget.onDismiss(),
            child: GestureDetector(
              onVerticalDragUpdate: (details) {
                if (details.primaryDelta != null && details.primaryDelta! < -4) {
                  _dismissWithAnimation();
                }
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: config.gradientColors,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: config.borderColor, width: 1.3),
                      boxShadow: [
                        BoxShadow(
                          color: config.shadowColor,
                          blurRadius: 20,
                          spreadRadius: 1,
                          offset: const Offset(0, 8),
                        ),
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.2),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // Native Vector Icon Pill
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: config.iconBgColor,
                                  borderRadius: BorderRadius.circular(13),
                                  border: Border.all(
                                    color: config.borderColor.withValues(alpha: 0.6),
                                    width: 1.2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: config.shadowColor.withValues(alpha: 0.4),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                alignment: Alignment.center,
                                child: Icon(
                                  widget.icon ?? config.defaultIcon,
                                  color: config.iconColor,
                                  size: 21,
                                ),
                              ),
                              const SizedBox(width: 12),

                              // Content & Micro-badge
                              Expanded(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        if (widget.badgeTag != null) ...[
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: config.badgeBgColor,
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(
                                                color: config.badgeTextColor.withValues(alpha: 0.4),
                                                width: 0.8,
                                              ),
                                            ),
                                            child: Text(
                                              widget.badgeTag!,
                                              style: GoogleFonts.plusJakartaSans(
                                                color: config.badgeTextColor,
                                                fontSize: 9,
                                                fontWeight: FontWeight.w800,
                                                letterSpacing: 0.8,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                        ],
                                        Expanded(
                                          child: Text(
                                            widget.title,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: GoogleFonts.plusJakartaSans(
                                              color: Colors.white,
                                              fontSize: 13.5,
                                              fontWeight: FontWeight.w800,
                                              letterSpacing: 0.1,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (widget.message != null && widget.message!.isNotEmpty) ...[
                                      const SizedBox(height: 3),
                                      Text(
                                        widget.message!,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.plusJakartaSans(
                                          color: Colors.white.withValues(alpha: 0.88),
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w500,
                                          height: 1.3,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),

                              // Action Button or Close Icon
                              if (widget.actionLabel != null && widget.onAction != null) ...[
                                const SizedBox(width: 8),
                                InkWell(
                                  onTap: () {
                                    HapticFeedback.lightImpact();
                                    _dismissWithAnimation();
                                    widget.onAction!();
                                  },
                                  borderRadius: BorderRadius.circular(14),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          Colors.white.withValues(alpha: 0.3),
                                          Colors.white.withValues(alpha: 0.15),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          widget.actionLabel!,
                                          style: GoogleFonts.plusJakartaSans(
                                            color: Colors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        const SizedBox(width: 3),
                                        const Icon(Icons.arrow_forward_ios_rounded, size: 9, color: Colors.white),
                                      ],
                                    ),
                                  ),
                                ),
                              ] else ...[
                                const SizedBox(width: 4),
                                InkWell(
                                  onTap: _dismissWithAnimation,
                                  borderRadius: BorderRadius.circular(16),
                                  child: Padding(
                                    padding: const EdgeInsets.all(4.0),
                                    child: Icon(
                                      Icons.close_rounded,
                                      size: 16,
                                      color: Colors.white.withValues(alpha: 0.6),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),

                        // Animated Micro Progress Bar at bottom
                        AnimatedBuilder(
                          animation: _progressController,
                          builder: (context, _) {
                            return ClipRRect(
                              borderRadius: const BorderRadius.only(
                                bottomLeft: Radius.circular(22),
                                bottomRight: Radius.circular(22),
                              ),
                              child: LinearProgressIndicator(
                                value: 1.0 - _progressController.value,
                                minHeight: 2.2,
                                backgroundColor: Colors.transparent,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  config.progressColor,
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  _ToastConfig _getToastConfig(ToastType type, bool isDark) {
    switch (type) {
      case ToastType.birthday:
        return _ToastConfig(
          gradientColors: [
            const Color(0xFF4A044E).withValues(alpha: 0.94), // Deep Fuchsia
            const Color(0xFF831843).withValues(alpha: 0.94), // Rose
            const Color(0xFF1E1B4B).withValues(alpha: 0.94), // Indigo
          ],
          borderColor: const Color(0xFFF472B6).withValues(alpha: 0.7),
          shadowColor: const Color(0xFFEC4899).withValues(alpha: 0.4),
          iconBgColor: const Color(0xFFBE185D).withValues(alpha: 0.45),
          badgeBgColor: const Color(0xFFF472B6).withValues(alpha: 0.25),
          badgeTextColor: const Color(0xFFFBCFE8),
          progressColor: const Color(0xFFF472B6).withValues(alpha: 0.8),
          defaultIcon: Icons.cake_rounded,
          iconColor: const Color(0xFFFBCFE8),
        );
      case ToastType.whatsapp:
        return _ToastConfig(
          gradientColors: [
            const Color(0xFF064E3B).withValues(alpha: 0.94), // Emerald Deep
            const Color(0xFF047857).withValues(alpha: 0.94), // WhatsApp Emerald
            const Color(0xFF0F172A).withValues(alpha: 0.94), // Slate
          ],
          borderColor: const Color(0xFF34D399).withValues(alpha: 0.7),
          shadowColor: const Color(0xFF10B981).withValues(alpha: 0.4),
          iconBgColor: const Color(0xFF059669).withValues(alpha: 0.45),
          badgeBgColor: const Color(0xFF34D399).withValues(alpha: 0.25),
          badgeTextColor: const Color(0xFFA7F3D0),
          progressColor: const Color(0xFF34D399).withValues(alpha: 0.8),
          defaultIcon: Icons.chat_bubble_rounded,
          iconColor: const Color(0xFFA7F3D0),
        );
      case ToastType.copied:
        return _ToastConfig(
          gradientColors: [
            const Color(0xFF0F172A).withValues(alpha: 0.94), // Slate
            const Color(0xFF1E293B).withValues(alpha: 0.94),
            const Color(0xFF334155).withValues(alpha: 0.94),
          ],
          borderColor: const Color(0xFF38BDF8).withValues(alpha: 0.7),
          shadowColor: const Color(0xFF0284C7).withValues(alpha: 0.35),
          iconBgColor: const Color(0xFF0284C7).withValues(alpha: 0.4),
          badgeBgColor: const Color(0xFF38BDF8).withValues(alpha: 0.25),
          badgeTextColor: const Color(0xFFBAE6FD),
          progressColor: const Color(0xFF38BDF8).withValues(alpha: 0.8),
          defaultIcon: Icons.content_copy_rounded,
          iconColor: const Color(0xFFBAE6FD),
        );
      case ToastType.success:
        return _ToastConfig(
          gradientColors: [
            const Color(0xFF064E3B).withValues(alpha: 0.94),
            const Color(0xFF0F172A).withValues(alpha: 0.94),
          ],
          borderColor: const Color(0xFF10B981).withValues(alpha: 0.7),
          shadowColor: const Color(0xFF10B981).withValues(alpha: 0.35),
          iconBgColor: const Color(0xFF10B981).withValues(alpha: 0.4),
          badgeBgColor: const Color(0xFF10B981).withValues(alpha: 0.25),
          badgeTextColor: const Color(0xFFA7F3D0),
          progressColor: const Color(0xFF10B981).withValues(alpha: 0.8),
          defaultIcon: Icons.check_circle_rounded,
          iconColor: const Color(0xFFA7F3D0),
        );
      case ToastType.warning:
        return _ToastConfig(
          gradientColors: [
            const Color(0xFF78350F).withValues(alpha: 0.94), // Amber Deep
            const Color(0xFF451A03).withValues(alpha: 0.94),
          ],
          borderColor: const Color(0xFFFBBF24).withValues(alpha: 0.7),
          shadowColor: const Color(0xFFF59E0B).withValues(alpha: 0.35),
          iconBgColor: const Color(0xFFF59E0B).withValues(alpha: 0.4),
          badgeBgColor: const Color(0xFFFBBF24).withValues(alpha: 0.25),
          badgeTextColor: const Color(0xFFFDE68A),
          progressColor: const Color(0xFFFBBF24).withValues(alpha: 0.8),
          defaultIcon: Icons.warning_amber_rounded,
          iconColor: const Color(0xFFFDE68A),
        );
      case ToastType.error:
        return _ToastConfig(
          gradientColors: [
            const Color(0xFF7F1D1D).withValues(alpha: 0.94), // Crimson Deep
            const Color(0xFF450A0A).withValues(alpha: 0.94),
          ],
          borderColor: const Color(0xFFF87171).withValues(alpha: 0.7),
          shadowColor: const Color(0xFFEF4444).withValues(alpha: 0.4),
          iconBgColor: const Color(0xFFDC2626).withValues(alpha: 0.4),
          badgeBgColor: const Color(0xFFF87171).withValues(alpha: 0.25),
          badgeTextColor: const Color(0xFFFECACA),
          progressColor: const Color(0xFFF87171).withValues(alpha: 0.8),
          defaultIcon: Icons.error_outline_rounded,
          iconColor: const Color(0xFFFECACA),
        );
      case ToastType.info:
        return _ToastConfig(
          gradientColors: [
            const Color(0xFF1E1B4B).withValues(alpha: 0.94), // Deep Indigo
            const Color(0xFF312E81).withValues(alpha: 0.94),
            const Color(0xFF0F172A).withValues(alpha: 0.94),
          ],
          borderColor: const Color(0xFF818CF8).withValues(alpha: 0.7),
          shadowColor: const Color(0xFF6366F1).withValues(alpha: 0.4),
          iconBgColor: const Color(0xFF4F46E5).withValues(alpha: 0.4),
          badgeBgColor: const Color(0xFF818CF8).withValues(alpha: 0.25),
          badgeTextColor: const Color(0xFFC7D2FE),
          progressColor: const Color(0xFF818CF8).withValues(alpha: 0.8),
          defaultIcon: Icons.info_outline_rounded,
          iconColor: const Color(0xFFC7D2FE),
        );
    }
  }
}

class _ToastConfig {
  final List<Color> gradientColors;
  final Color borderColor;
  final Color shadowColor;
  final Color iconBgColor;
  final Color badgeBgColor;
  final Color badgeTextColor;
  final Color progressColor;
  final IconData defaultIcon;
  final Color iconColor;

  const _ToastConfig({
    required this.gradientColors,
    required this.borderColor,
    required this.shadowColor,
    required this.iconBgColor,
    required this.badgeBgColor,
    required this.badgeTextColor,
    required this.progressColor,
    required this.defaultIcon,
    required this.iconColor,
  });
}
