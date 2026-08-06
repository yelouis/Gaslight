import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/game_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_icons.dart';

class HouseRulesDialog extends StatelessWidget {
  const HouseRulesDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (context) => const HouseRulesDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final gs = context.watch<GameService>();
    final room = gs.gameState;
    final isHost = gs.currentPlayer?.isHost ?? false;

    final selectedRounds = room?.sabotageAnswersCount ?? 2;
    final isTimerDisabled = room?.isTimerDisabled ?? false;

    final roundsControl = DropdownButtonFormField<int>(
      value: selectedRounds,
      style: const TextStyle(
        color: AppColors.ivory,
        fontWeight: FontWeight.bold,
        fontFamily: 'Lora',
        fontSize: 16,
      ),
      decoration: InputDecoration(
        labelText: 'Number of Rounds',
        labelStyle: TextStyle(
          color: AppColors.ivory.withOpacity(0.7),
          fontWeight: FontWeight.bold,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: AppColors.oxblood.withOpacity(0.4)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.oxblood, width: 2),
        ),
        filled: true,
        fillColor: Colors.black.withOpacity(0.5),
        prefixIcon: ThematicIcon(
          type: ThematicIconType.redraw,
          size: 20,
          color: AppColors.oxblood.withOpacity(0.8),
        ),
      ),
      dropdownColor: const Color(0xFF161C19),
      items: [1, 2, 3, 4, 5].map((int value) {
        return DropdownMenuItem<int>(
          value: value,
          child: Text(
            '$value Round${value > 1 ? 's' : ''}',
            style: const TextStyle(color: AppColors.ivory),
          ),
        );
      }).toList(),
      onChanged: isHost
          ? (int? v) {
              if (v != null) {
                gs.updateLobbySettings(sabotageAnswersCount: v);
              }
            }
          : null,
    );

    final timerControl = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.4),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.oxblood.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                ThematicIcon(
                  type: ThematicIconType.timer,
                  color: AppColors.oxblood.withOpacity(0.8),
                  size: 20,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Disable Game Timers',
                    style: TextStyle(
                      color: AppColors.ivory,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: isTimerDisabled,
            activeColor: AppColors.oxblood,
            activeTrackColor: AppColors.oxblood.withOpacity(0.4),
            inactiveThumbColor: Colors.grey,
            inactiveTrackColor: Colors.grey.withOpacity(0.3),
            onChanged: isHost
                ? (val) {
                    gs.updateLobbySettings(isTimerDisabled: val);
                  }
                : null,
          ),
        ],
      ),
    );

    return Dialog(
      backgroundColor: AppColors.groundRaised,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.brass, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const ThematicIcon(type: ThematicIconType.ledger, size: 22),
                const SizedBox(width: 10),
                Text('HOUSE RULES', style: AppTextStyles.sectionLabel),
              ],
            ),
            const SizedBox(height: 16),
            isHost ? roundsControl : Opacity(opacity: 0.5, child: roundsControl),
            const SizedBox(height: 12),
            isHost ? timerControl : Opacity(opacity: 0.5, child: timerControl),
            if (!isHost) ...[
              const SizedBox(height: 12),
              Text(
                'Only the host may set the house rules. Changes appear here as they are made.',
                style: TextStyle(
                  fontFamily: 'Lora',
                  fontStyle: FontStyle.italic,
                  fontSize: 12,
                  color: AppColors.ivory.withOpacity(0.6),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
