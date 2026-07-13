import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_icons.dart';
import '../models/player_state.dart';
import '../services/game_service.dart';

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

  static Widget buildChip({
    required int colorValue,
    required int avatarIndex,
    required double size,
    bool isActiveReader = false,
  }) {
    final chipColor = Color(colorValue);
    final borderColor = AppColors.brass; // Antique Gold
    
    final sigilTypes = [
      ThematicIconType.flame,
      ThematicIconType.moth,
      ThematicIconType.key,
      ThematicIconType.raven,
      ThematicIconType.moon,
      ThematicIconType.hourglass,
    ];
    final sigilType = sigilTypes[avatarIndex % sigilTypes.length];

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: borderColor,
          width: isActiveReader ? max(4.0, size / 10) : max(3.0, size / 12),
        ),
        gradient: RadialGradient(
          colors: [
            chipColor.withOpacity(0.4),
            chipColor.withOpacity(0.9),
            Colors.black.withOpacity(0.7),
          ],
          stops: const [0.2, 0.7, 1.0],
        ),
        boxShadow: [
          if (isActiveReader)
            BoxShadow(
              color: AppColors.brass.withOpacity(0.8),
              blurRadius: 12,
              spreadRadius: 3,
            )
          else
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
          child: ThematicIcon(
            type: sigilType,
            size: size * 0.45,
            color: borderColor,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isActiveReader = false;
    try {
      final gameService = context.watch<GameService>();
      isActiveReader = gameService.gameState?.currentReaderId == player.id;
    } catch (_) {}

    final avatarStack = Stack(
      clipBehavior: Clip.none,
      children: [
        () {
          final chip = buildChip(
            colorValue: player.colorValue,
            avatarIndex: player.avatarIndex,
            size: size,
            isActiveReader: isActiveReader,
          );
          return isActiveReader ? _PulsingHalo(size: size, child: chip) : childChipWrapper(chip);
        }(),
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
    );

    if (!showName) {
      return avatarStack;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        avatarStack,
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
      ],
    );
  }

  Widget childChipWrapper(Widget chip) {
    return chip;
  }
}

class _PulsingHalo extends StatefulWidget {
  final Widget child;
  final double size;

  const _PulsingHalo({required this.child, required this.size});

  @override
  State<_PulsingHalo> createState() => _PulsingHaloState();
}

class _PulsingHaloState extends State<_PulsingHalo> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _glowAnimation = Tween<double>(begin: 0.3, end: 0.85).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.brass.withOpacity(_glowAnimation.value),
                blurRadius: 10 + 6 * _glowAnimation.value,
                spreadRadius: 2 + 2 * _glowAnimation.value,
              )
            ],
          ),
          child: widget.child,
        );
      },
    );
  }
}

double max(double a, double b) => a > b ? a : b;
