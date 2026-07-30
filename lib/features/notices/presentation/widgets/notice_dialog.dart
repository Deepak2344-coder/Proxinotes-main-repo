import 'package:flutter/material.dart';
import 'package:notes_app/core/models/notice_model.dart';
import 'package:notes_app/core/theme/app_theme.dart';

class NoticeDialog extends StatelessWidget {
  final Notice notice;
  final String appVersion;
  final VoidCallback? onAction;

  const NoticeDialog({
    super.key,
    required this.notice,
    required this.appVersion,
    this.onAction,
  });

  static Future<void> show(
    BuildContext context, {
    required Notice notice,
    required String appVersion,
    VoidCallback? onAction,
  }) {
    final isUndmissable = _isUndmissable(notice, appVersion);
    return showGeneralDialog(
      context: context,
      barrierDismissible: !isUndmissable,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (ctx, _, _) => NoticeDialog(
        notice: notice,
        appVersion: appVersion,
        onAction: onAction,
      ),
    );
  }

  static bool _isUndmissable(Notice notice, String appVersion) {
    if (notice.isUrgent) return true;
    if (notice.isUpdate && notice.isForcedForVersion(appVersion)) return true;
    return false;
  }

  IconData _getIcon() {
    switch (notice.type) {
      case 'urgent':
        return Icons.warning_amber_rounded;
      case 'update':
        return Icons.system_update;
      case 'info':
      default:
        return Icons.info_outline;
    }
  }

  Color _getIconColor() {
    switch (notice.type) {
      case 'urgent':
        return AppTheme.error;
      case 'update':
        return AppTheme.warning;
      case 'info':
      default:
        return AppTheme.navy;
    }
  }

  Color _getButtonColor() {
    switch (notice.type) {
      case 'urgent':
        return AppTheme.error;
      case 'update':
        return AppTheme.warning;
      case 'info':
      default:
        return AppTheme.navy;
    }
  }

  @override
  Widget build(BuildContext context) {
    final iconColor = _getIconColor();
    final buttonColor = _getButtonColor();
    final isUndmissable = _isUndmissable(notice, appVersion);

    return PopScope(
      canPop: !isUndmissable,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: iconColor.withAlpha(20),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _getIcon(),
                  color: iconColor,
                  size: 32,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                notice.title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                notice.body,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppTheme.textSecondary,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              if (notice.minAppVersion != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.warning.withAlpha(20),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Requires version ${notice.minAppVersion} or later',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.warning,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isUndmissable && notice.isUpdate
                      ? () {
                          if (notice.linkUrl != null) {
                            onAction?.call();
                          }
                        }
                      : () {
                          Navigator.of(context).pop();
                          if (!isUndmissable) {
                            onAction?.call();
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: buttonColor,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(
                    notice.isUpdate
                        ? (notice.isForcedForVersion(appVersion)
                            ? (notice.linkLabel ?? 'Update Now')
                            : 'Got it')
                        : notice.isUrgent
                            ? 'I understand'
                            : 'Got it',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
