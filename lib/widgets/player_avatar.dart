import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../models/player_state.dart';

class PlayerAvatar extends StatelessWidget {
  final PlayerState player;
  final double size;
  final bool showName;

  const PlayerAvatar({
    super.key,
    required this.player,
    this.size = 48.0,
    this.showName = true,
  });

  static const List<IconData> thematicIcons = [
    Icons.local_fire_department, // Flame
    Icons.visibility,            // Eye / Paranoid
    Icons.vpn_key,               // Key / Secret
    Icons.casino,                // Dice / Gambling
    Icons.dark_mode,             // Moon / Night
    Icons.lightbulb_outline,     // Light / Idea
  ];

  static IconData getIconForIndex(int index) {
    return thematicIcons[index % thematicIcons.length];
  }

  static Widget buildChip({
    required int colorValue,
    required int avatarIndex,
    required double size,
  }) {
    final chipColor = Color(colorValue);
    final borderColor = AppColors.brass; // Antique Gold
    
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: borderColor, width: max(3.0, size / 12)),
        gradient: RadialGradient(
          colors: [
            chipColor.withOpacity(0.4),
            chipColor.withOpacity(0.9),
            Colors.black.withOpacity(0.7),
          ],
          stops: const [0.2, 0.7, 1.0],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.7),
            blurRadius: 8,
            offset: const Offset(2, 6),
          )
        ]
      ),
      child: Container(
        margin: EdgeInsets.all(max(2.0, size / 20)),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: borderColor.withOpacity(0.5), width: 1.5),
        ),
        child: Center(
          child: Icon(
            getIconForIndex(avatarIndex),
            color: borderColor,
            size: size * 0.45,
            shadows: [
              Shadow(
                color: Colors.black.withOpacity(0.8),
                blurRadius: 4,
                offset: const Offset(1, 1),
              )
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            buildChip(
              colorValue: player.colorValue,
              avatarIndex: player.avatarIndex,
              size: size,
            ),
            if (player.lobbyReady)
              Positioned(
                right: -4,
                bottom: -4,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    color: AppColors.verdigris,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check,
                    color: Colors.white,
                    size: 12,
                  ),
                ),
              ),
            if (player.isHost)
              Positioned(
                left: -4,
                top: -4,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    color: AppColors.brass,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.star,
                    color: Colors.white,
                    size: 12,
                  ),
                ),
              ),
          ],
        ),
        if (showName) ...[
          const SizedBox(height: 8),
          Text(
            player.name,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: max(12, size / 4),
              shadows: const [Shadow(color: Colors.black, blurRadius: 4)],
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ]
      ],
    );
  }
}

double max(double a, double b) => a > b ? a : b;
