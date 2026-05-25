import 'package:flutter/material.dart';

class CrimsonShadowCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double? width;

  const CrimsonShadowCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(24),
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: width,
      padding: padding,
      decoration: BoxDecoration(
        color: const Color(0xFF1A1F1C), // Deep dark coal background
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.primary.withOpacity(0.8), // Crimson outline
          width: 2.0,
        ),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withOpacity(0.35), // Vibrant crimson glow shadow
            blurRadius: 20,
            offset: const Offset(0, 10),
            spreadRadius: 1,
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ]
      ),
      child: child,
    );
  }
}

class ParchmentCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double? width;

  const ParchmentCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(24),
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: width,
      padding: padding,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface, // Parchment
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.secondary, width: 3), // Gold
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.6),
            blurRadius: 30,
            offset: const Offset(0, 15),
          ),
          BoxShadow(
            color: theme.colorScheme.secondary.withOpacity(0.1),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ]
      ),
      child: child,
    );
  }
}

class PrimaryButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final double fontSize;
  final Widget? icon;
  
  const PrimaryButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.fontSize = 20,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withOpacity(0.4),
            blurRadius: 12,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: theme.colorScheme.primary, // Burgundy
          foregroundColor: const Color(0xFFF5EEDB), // Ivory
          minimumSize: const Size(double.infinity, 58),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: theme.colorScheme.primary.withOpacity(0.5), width: 1.5), // Crimson
          ),
          elevation: 6,
          shadowColor: Colors.black.withOpacity(0.5),
        ),
        onPressed: onPressed,
        child: icon == null
            ? Text(text, style: TextStyle(fontWeight: FontWeight.bold, fontSize: fontSize, letterSpacing: 2))
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  icon!,
                  const SizedBox(width: 8),
                  Text(text, style: TextStyle(fontWeight: FontWeight.bold, fontSize: fontSize, letterSpacing: 2)),
                ],
              ),
      ),
    );
  }
}

class SecondaryButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  
  const SecondaryButton({
    super.key,
    required this.text,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 3),
          )
        ],
      ),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: theme.colorScheme.tertiary, // Emerald
          foregroundColor: const Color(0xFFF5EEDB), // Ivory
          minimumSize: const Size(200, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: theme.colorScheme.primary.withOpacity(0.4), width: 1.5), // Crimson
          ),
          elevation: 6,
        ),
        onPressed: onPressed,
        child: Text(
          text, 
          style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5),
        ),
      ),
    );
  }
}
