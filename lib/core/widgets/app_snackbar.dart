import 'package:flutter/material.dart';

/// Professional floating snackbar presenter that matches Ridin's obsidian theme
/// and respects system bottom navigation insets (Rule 5).
class AppSnackBar {
  static void showError(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 4),
  }) {
    _show(
      context: context,
      message: message,
      icon: Icons.error_outline_rounded,
      iconColor: const Color(0xFFEF4444),
      borderColor: const Color(0xFFEF4444).withValues(alpha: 0.4),
      backgroundColor: const Color(0xFF1E293B),
      duration: duration,
    );
  }

  static void showSuccess(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
  }) {
    _show(
      context: context,
      message: message,
      icon: Icons.check_circle_outline_rounded,
      iconColor: const Color(0xFF10B981),
      borderColor: const Color(0xFF10B981).withValues(alpha: 0.4),
      backgroundColor: const Color(0xFF1E293B),
      duration: duration,
    );
  }

  static void showWarning(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 4),
  }) {
    _show(
      context: context,
      message: message,
      icon: Icons.warning_amber_rounded,
      iconColor: const Color(0xFFF59E0B),
      borderColor: const Color(0xFFF59E0B).withValues(alpha: 0.4),
      backgroundColor: const Color(0xFF1E293B),
      duration: duration,
    );
  }

  static void _show({
    required BuildContext context,
    required String message,
    required IconData icon,
    required Color iconColor,
    required Color borderColor,
    required Color backgroundColor,
    required Duration duration,
  }) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();

    final bottomPadding = MediaQuery.of(context).viewInsets.bottom > 0
        ? MediaQuery.of(context).viewInsets.bottom + 12
        : MediaQuery.of(context).padding.bottom + 12;

    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.transparent,
        elevation: 0,
        duration: duration,
        margin: EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: bottomPadding,
        ),
        padding: EdgeInsets.zero,
        content: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor, width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(icon, color: iconColor, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: Color(0xFFF8FAFC),
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                    height: 1.35,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => messenger.hideCurrentSnackBar(),
                child: const Icon(
                  Icons.close_rounded,
                  color: Color(0xFF94A3B8),
                  size: 18,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
