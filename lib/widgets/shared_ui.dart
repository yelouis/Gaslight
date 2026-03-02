import 'package:flutter/material.dart';

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
        border: Border.all(color: theme.colorScheme.secondary, width: 4), // Gold
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.8),
            blurRadius: 40,
            offset: const Offset(0, 20),
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
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: theme.colorScheme.primary, // Burgundy
        foregroundColor: const Color(0xFFF5EEDB), // Ivory
        minimumSize: const Size(double.infinity, 56),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: theme.colorScheme.secondary, width: 2), // Gold
        ),
        elevation: 8,
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
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: theme.colorScheme.tertiary, // Emerald
        foregroundColor: const Color(0xFFF5EEDB), // Ivory
        minimumSize: const Size(200, 50),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: theme.colorScheme.secondary, width: 2), // Gold
        ),
        elevation: 8,
      ),
      onPressed: onPressed,
      child: Text(
        text, 
        style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5),
      ),
    );
  }
}
