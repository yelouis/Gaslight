import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTextStyles {
  static const TextStyle gaslightLogo = TextStyle(
    fontFamily: 'CormorantGaramond',
    fontSize: 48,
    fontWeight: FontWeight.w900,
    color: AppColors.brass,
    letterSpacing: 6,
    shadows: [
      Shadow(
        color: Colors.black,
        offset: Offset(2, 2),
        blurRadius: 8,
      ),
    ],
  );

  static const TextStyle phaseTitle = TextStyle(
    fontFamily: 'CormorantGaramond',
    fontSize: 32,
    fontWeight: FontWeight.bold,
    color: AppColors.brass,
    letterSpacing: 3,
    shadows: [
      Shadow(
        color: Colors.black,
        offset: Offset(1.5, 1.5),
        blurRadius: 6,
      ),
    ],
  );

  static const TextStyle cardHeader = TextStyle(
    fontFamily: 'CormorantGaramond',
    fontSize: 22,
    fontWeight: FontWeight.bold,
    color: AppColors.brass,
    letterSpacing: 2,
  );

  static final TextStyle sectionLabel = TextStyle(
    fontFamily: 'Lora',
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: AppColors.brass.withOpacity(0.7),
    letterSpacing: 2,
  );

  static const TextStyle bodyInk = TextStyle(
    fontFamily: 'Lora',
    fontSize: 16,
    color: AppColors.ink,
  );

  static const TextStyle bodyIvory = TextStyle(
    fontFamily: 'Lora',
    fontSize: 16,
    color: AppColors.ivory,
  );
}
