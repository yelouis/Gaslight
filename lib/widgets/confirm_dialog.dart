import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// The one confirmation dialog for every action a player cannot undo or that
/// ends something for the table: leaving a room or a game, removing a player,
/// ending the vote. Every such dialog goes through this widget (Issue 181).
///
/// Actions are ivory (cancel) and brass (confirm) on `groundRaised`, because
/// colour tokens name a SURFACE: unstyled `TextButton`s take `colorScheme.primary`,
/// which is oxblood, and measured 1.78 : 1 here. Do not add another `AlertDialog`
/// for a confirmation; `test/confirm_dialog_routing_test.dart` fails if one appears.
class GaslightConfirmDialog extends StatelessWidget {
  const GaslightConfirmDialog({
    super.key,
    required this.title,
    required this.body,
    required this.cancelLabel,
    required this.confirmLabel,
    required this.onConfirm,
  });

  final String title;
  final String body;
  final String cancelLabel;
  final String confirmLabel;

  /// Receives the dialog's own BuildContext; the caller pops it, exactly as today.
  final void Function(BuildContext dialogContext) onConfirm;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.groundRaised,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.brass, width: 1),
      ),
      title: Text(title, style: AppTextStyles.cardHeader.copyWith(color: AppColors.brass)),
      content: Text(body, style: AppTextStyles.bodyIvory),
      actions: [
        TextButton(
          key: const ValueKey('confirm_dialog_cancel'),
          onPressed: () => Navigator.of(context).pop(),
          style: TextButton.styleFrom(minimumSize: const Size(64, 48)),
          child: Text(
            cancelLabel,
            style: AppTextStyles.bodyIvory.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        TextButton(
          key: const ValueKey('confirm_dialog_confirm'),
          onPressed: () => onConfirm(context),
          style: TextButton.styleFrom(minimumSize: const Size(64, 48)),
          child: Text(
            confirmLabel,
            style: AppTextStyles.bodyIvory.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.brass,
            ),
          ),
        ),
      ],
    );
  }
}
