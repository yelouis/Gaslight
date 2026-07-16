import 'dart:io';
import 'dart:ui' as ui;
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../services/game_service.dart';
import '../models/player_state.dart';
import '../widgets/player_avatar.dart';
import '../widgets/lobby_background.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/gaslight_route.dart';
import '../theme/app_icons.dart';
import '../theme/app_motion.dart';

class GameOverScreen extends StatefulWidget {
  const GameOverScreen({super.key});

  @override
  State<GameOverScreen> createState() => _GameOverScreenState();
}

class _GameOverScreenState extends State<GameOverScreen> {
  final GlobalKey _globalKey = GlobalKey();
  bool _isSharing = false;

  Future<void> _shareCaseFile() async {
    if (_isSharing) return;
    setState(() => _isSharing = true);

    try {
      // Small delay to allow setState to build if needed
      await Future.delayed(const Duration(milliseconds: 100));

      final boundary = _globalKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        throw Exception('Could not find render object boundary');
      }

      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        throw Exception('Could not convert image to byte data');
      }
      final pngBytes = byteData.buffer.asUint8List();

      if (kIsWeb) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sharing is only supported on mobile devices.')),
        );
        return;
      }

      final tempDir = await getTemporaryDirectory();
      final file = await File('${tempDir.path}/gaslight_case_file.png').create();
      await file.writeAsBytes(pngBytes);

      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'image/png')],
        text: 'Just finished a match of Gaslight! Check out the night\'s honors.',
      );
    } catch (e) {
      debugPrint('Error sharing case file: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to share: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSharing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final gs = context.watch<GameService>();
    final theme = Theme.of(context);
    final players = gs.players;

    final activePlayers = players.where((p) => p.role != PlayerRole.spectator).toList();

    if (activePlayers.isEmpty) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Determine Superlatives by Metric Honors
    final sortedByScore = List<PlayerState>.from(activePlayers)..sort((a, b) => b.totalScore.compareTo(a.totalScore));
    final mastermind = sortedByScore.first;
    final Set<String> assignedIds = {mastermind.id};

    PlayerState? trickster;
    final remainingForTrickster = activePlayers.where((p) => !assignedIds.contains(p.id)).toList();
    if (remainingForTrickster.isNotEmpty) {
      remainingForTrickster.sort((a, b) {
        final cmp = b.playersDeceived.compareTo(a.playersDeceived);
        if (cmp != 0) return cmp;
        return b.totalScore.compareTo(a.totalScore);
      });
      trickster = remainingForTrickster.first;
      assignedIds.add(trickster.id);
    }

    PlayerState? gullible;
    final remainingForGullible = activePlayers.where((p) => !assignedIds.contains(p.id)).toList();
    if (remainingForGullible.isNotEmpty) {
      remainingForGullible.sort((a, b) {
        final cmp = b.timesFooled.compareTo(a.timesFooled);
        if (cmp != 0) return cmp;
        return a.totalScore.compareTo(b.totalScore); // Tie broken by lowest score
      });
      gullible = remainingForGullible.first;
      assignedIds.add(gullible.id);
    }

    PlayerState? runnerUp;
    final remainingForRunnerUp = activePlayers.where((p) => !assignedIds.contains(p.id)).toList();
    if (remainingForRunnerUp.isNotEmpty) {
      runnerUp = sortedByScore.firstWhere((p) => remainingForRunnerUp.any((rp) => rp.id == p.id));
      assignedIds.add(runnerUp.id);
    }

    return Scaffold(
      backgroundColor: AppColors.ground,
      appBar: AppBar(
        title: TitleSettle(
          text: 'GAME OVER',
          style: AppTextStyles.phaseTitle.copyWith(fontSize: 26),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: Stack(
        children: [
          const EmberBackdrop(),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  RepaintBoundary(
                    key: _globalKey,
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppColors.ground,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.brass, width: 2),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'THE NIGHT\'S HONORS',
                            style: theme.textTheme.headlineMedium?.copyWith(
                              color: theme.colorScheme.secondary, // Gold
                              fontWeight: FontWeight.bold,
                              fontFamily: 'CormorantGaramond',
                              letterSpacing: 3,
                              shadows: [Shadow(color: Colors.black.withOpacity(0.8), blurRadius: 10)],
                            ),
                          ),
                          const SizedBox(height: 30),
                          _buildHonorCards(theme, mastermind, trickster, runnerUp, gullible),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  ElevatedButton.icon(
                    icon: const ThematicIcon(type: ThematicIconType.envelope, color: AppColors.ivory),
                    label: Text(
                      _isSharing ? 'Generating dossier...' : 'Share Case File',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
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
                    onPressed: _isSharing ? null : _shareCaseFile,
                  ),
                  const SizedBox(height: 20),
                  TextButton(
                    onPressed: () async {
                      final navigator = Navigator.of(context);
                      await gs.leaveRoom();
                      navigator.pushNamedAndRemoveUntil('/', (route) => false);
                    },
                    child: Text('RETURN TO LOBBY', style: TextStyle(color: theme.colorScheme.secondary)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHonorCards(
    ThemeData theme, 
    PlayerState mastermind, 
    PlayerState? trickster, 
    PlayerState? runnerUp, 
    PlayerState? gullible
  ) {
    List<Widget> cards = [];
    int animIndex = 0;

    cards.add(
      StaggeredPlaque(
        index: animIndex++,
        child: _plaque(
          theme: theme,
          title: 'THE MASTERMIND',
          subtitle: 'HIGHEST SCORE',
          player: mastermind,
          sigilType: ThematicIconType.host,
          metricText: '${mastermind.totalScore} Pts',
        ),
      ),
    );

    if (trickster != null) {
      cards.add(
        const SizedBox(height: 12),
      );
      cards.add(
        StaggeredPlaque(
          index: animIndex++,
          child: _plaque(
            theme: theme,
            title: 'THE DUPLICITOUS',
            subtitle: 'MOST PLAYERS DECEIVED',
            player: trickster,
            sigilType: ThematicIconType.secret,
            metricText: '${trickster.playersDeceived} Deceptions',
          ),
        ),
      );
    }

    if (runnerUp != null) {
      cards.add(
        const SizedBox(height: 12),
      );
      cards.add(
        StaggeredPlaque(
          index: animIndex++,
          child: _plaque(
            theme: theme,
            title: 'THE RUNNER UP',
            subtitle: 'SECOND HIGHEST SCORE',
            player: runnerUp,
            sigilType: ThematicIconType.ledger,
            metricText: '${runnerUp.totalScore} Pts',
          ),
        ),
      );
    }

    if (gullible != null) {
      cards.add(
        const SizedBox(height: 12),
      );
      cards.add(
        StaggeredPlaque(
          index: animIndex++,
          child: _plaque(
            theme: theme,
            title: 'THE GULLIBLE',
            subtitle: 'MOST TIMES FOOLED',
            player: gullible,
            sigilType: ThematicIconType.observe,
            metricText: '${gullible.timesFooled} Fooled',
          ),
        ),
      );
    }

    return Column(
      children: cards,
    );
  }

  Widget _plaque({
    required ThemeData theme,
    required String title,
    required String subtitle,
    required PlayerState player,
    required ThematicIconType sigilType,
    required String metricText,
  }) {
    return Container(
      height: 88,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFE8D4A0),
            Color(0xFFD8B460),
            Color(0xFF8A6D2F),
          ],
        ),
        border: Border.all(
          color: const Color(0xFF6E571F),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Sigil
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.ground,
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF6E571F), width: 1.5),
            ),
            child: Center(
              child: ThematicIcon(
                type: sigilType,
                size: 24,
                color: AppColors.brass,
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Title / Sub
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'CormorantGaramond',
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: AppColors.ink,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontFamily: 'Lora',
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink.withOpacity(0.7),
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
          // Player Name & Metric Value
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                player.name,
                style: const TextStyle(
                  fontFamily: 'Lora',
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                metricText,
                style: const TextStyle(
                  fontFamily: 'CormorantGaramond',
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: AppColors.oxblood,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class EmberParticle {
  double x;
  double y;
  double speed;
  double radius;
  double initialDrift;
  double opacity;

  EmberParticle({
    required this.x,
    required this.y,
    required this.speed,
    required this.radius,
    required this.initialDrift,
    required this.opacity,
  });
}

class EmberBackdrop extends StatefulWidget {
  const EmberBackdrop({super.key});

  @override
  State<EmberBackdrop> createState() => _EmberBackdropState();
}

class _EmberBackdropState extends State<EmberBackdrop> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  final List<EmberParticle> _particles = [];
  final math.Random _random = math.Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 10),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _initParticles(Size size) {
    if (_particles.isNotEmpty) return;
    for (int i = 0; i < 25; i++) {
      _particles.add(EmberParticle(
        x: _random.nextDouble() * size.width,
        y: _random.nextDouble() * size.height,
        speed: 0.5 + _random.nextDouble() * 1.5,
        radius: 1.5 + _random.nextDouble() * 2.0,
        initialDrift: _random.nextDouble() * 2 * math.pi,
        opacity: 0.2 + _random.nextDouble() * 0.6,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final prefersReducedMotion = AppMotion.reduce(context);

    if (prefersReducedMotion) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);
          return CustomPaint(
            size: size,
            painter: _StaticEmberPainter(),
            child: Container(),
          );
        },
      );
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final Size size = Size(constraints.maxWidth, constraints.maxHeight);
            _initParticles(size);
            
            for (var p in _particles) {
              p.y -= p.speed;
              p.x += math.sin(p.initialDrift + _controller.value * 2 * math.pi * 5) * 0.3;
              if (p.y < 0) {
                p.y = size.height;
                p.x = _random.nextDouble() * size.width;
              }
            }

            return CustomPaint(
              size: size,
              painter: _DynamicEmberPainter(particles: _particles),
            );
          },
        );
      },
    );
  }
}

class _DynamicEmberPainter extends CustomPainter {
  final List<EmberParticle> particles;

  _DynamicEmberPainter({required this.particles});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    for (var p in particles) {
      double fade = 1.0;
      if (p.y < 100) {
        fade = p.y / 100;
      }
      paint.color = Colors.orangeAccent.withOpacity(p.opacity * fade);
      canvas.drawCircle(Offset(p.x, p.y), p.radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _DynamicEmberPainter oldDelegate) => true;
}

class _StaticEmberPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.orangeAccent.withOpacity(0.2)
      ..style = PaintingStyle.fill;
    final r = math.Random(42);
    for (int i = 0; i < 15; i++) {
      double x = r.nextDouble() * size.width;
      double y = r.nextDouble() * size.height;
      double rad = 1.5 + r.nextDouble() * 2.0;
      canvas.drawCircle(Offset(x, y), rad, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _StaticEmberPainter oldDelegate) => false;
}

class StaggeredPlaque extends StatefulWidget {
  final int index;
  final Widget child;

  const StaggeredPlaque({
    super.key,
    required this.index,
    required this.child,
  });

  @override
  State<StaggeredPlaque> createState() => _StaggeredPlaqueState();
}

class _StaggeredPlaqueState extends State<StaggeredPlaque> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _slideAnimation;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _slideAnimation = Tween<double>(begin: 30.0, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    Future.delayed(Duration(milliseconds: 200 * widget.index), () {
      if (mounted) {
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (AppMotion.reduce(context)) {
      return widget.child;
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: _fadeAnimation.value,
          child: Transform.translate(
            offset: Offset(0, _slideAnimation.value),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}
