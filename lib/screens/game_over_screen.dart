import 'dart:io';
import 'dart:async';
import 'dart:ui' as ui;
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../services/game_service.dart';
import '../services/audio_service.dart';
import '../models/player_state.dart';
import '../widgets/player_avatar.dart';
import '../widgets/lobby_background.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/gaslight_route.dart';
import '../theme/app_icons.dart';
import '../theme/app_motion.dart';
import '../widgets/lamp_loading.dart';
import '../widgets/shared_ui.dart';
import '../widgets/raven_mascot.dart';

class GameOverScreen extends StatefulWidget {
  const GameOverScreen({super.key});

  @override
  State<GameOverScreen> createState() => _GameOverScreenState();
}

class _GameOverScreenState extends State<GameOverScreen> {
  final GlobalKey _globalKey = GlobalKey();
  bool _isSharing = false;
  bool _ceremonyComplete = false;
  bool _timerStarted = false;
  final Set<int> _soundedIndices = {};
  Timer? _ceremonyTimer;
  RavenState _ravenState = RavenState.fly;
  Timer? _ravenFlyTimer;

  @override
  void initState() {
    super.initState();
    _ravenFlyTimer = Timer(const Duration(milliseconds: 900), () {
      if (mounted) {
        setState(() {
          _ravenState = RavenState.idle;
        });
      }
    });
  }

  @override
  void dispose() {
    _ceremonyTimer?.cancel();
    _ravenFlyTimer?.cancel();
    super.dispose();
  }

  void _startCeremonyTimer(int totalCount) {
    if (AppMotion.reduce(context)) {
      setState(() {
        _ceremonyComplete = true;
      });
      return;
    }

    final delayMs = 400 + AppMotion.ceremonyStep.inMilliseconds * (totalCount - 1) + 400;
    _ceremonyTimer = Timer(Duration(milliseconds: delayMs), () {
      if (mounted) {
        setState(() {
          _ceremonyComplete = true;
        });
      }
    });
  }

  void _playHonorSound(int index, int totalCount) {
    if (AppMotion.reduce(context)) return;
    if (_soundedIndices.contains(index)) return;
    _soundedIndices.add(index);
    if (index == totalCount - 1) {
      AudioService.instance.playReveal();
    } else {
      AudioService.instance.playUnmaskSuccess();
    }
  }

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
      return const Scaffold(backgroundColor: AppColors.ground, body: Center(child: LampLightingIndicator()));
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

    int totalCount = 1 + (trickster != null ? 1 : 0) + (runnerUp != null ? 1 : 0) + (gullible != null ? 1 : 0);
    if (!_timerStarted) {
      _timerStarted = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _startCeremonyTimer(totalCount);
        }
      });
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
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24.0, 24.0, 24.0, 12.0),
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
                            RavenMascot(
                              state: _ravenState,
                              size: 72,
                            ),
                            const SizedBox(height: 12),
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
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        key: const Key('game_over_bottom_bar'),
        decoration: BoxDecoration(
          color: AppColors.ground,
          border: Border(
            top: BorderSide(color: AppColors.brass.withOpacity(0.25), width: 1),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          minimum: const EdgeInsets.fromLTRB(24, 12, 24, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              PrimaryButton(
                icon: _isSharing
                    ? null
                    : const ThematicIcon(type: ThematicIconType.envelope, color: AppColors.ivory),
                text: !_ceremonyComplete
                    ? 'Engraving…'
                    : (_isSharing ? 'Generating dossier...' : 'Share Case File'),
                loading: _isSharing,
                showTextOnLoading: true,
                onPressed: (!_ceremonyComplete || _isSharing) ? null : _shareCaseFile,
              ),
              const SizedBox(height: 8),
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
    );
  }

  Widget _buildHonorCards(
    ThemeData theme, 
    PlayerState mastermind, 
    PlayerState? trickster, 
    PlayerState? runnerUp, 
    PlayerState? gullible
  ) {
    final honorsSequence = <String>[];
    if (gullible != null) honorsSequence.add('gullible');
    if (runnerUp != null) honorsSequence.add('runnerUp');
    if (trickster != null) honorsSequence.add('trickster');
    honorsSequence.add('mastermind');

    final totalCount = honorsSequence.length;
    int getIndex(String type) => honorsSequence.indexOf(type);

    List<Widget> cards = [];

    cards.add(
      StaggeredPlaque(
        index: getIndex('mastermind'),
        onComplete: () => _playHonorSound(getIndex('mastermind'), totalCount),
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
          index: getIndex('trickster'),
          onComplete: () => _playHonorSound(getIndex('trickster'), totalCount),
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
          index: getIndex('runnerUp'),
          onComplete: () => _playHonorSound(getIndex('runnerUp'), totalCount),
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
          index: getIndex('gullible'),
          onComplete: () => _playHonorSound(getIndex('gullible'), totalCount),
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
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    title,
                    maxLines: 1,
                    style: const TextStyle(
                      fontFamily: 'CormorantGaramond',
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: AppColors.ink,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    subtitle,
                    maxLines: 1,
                    style: TextStyle(
                      fontFamily: 'Lora',
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink.withOpacity(0.7),
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Player Name & Metric Value
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    player.name,
                    maxLines: 1,
                    style: const TextStyle(
                      fontFamily: 'Lora',
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.ink,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    metricText,
                    maxLines: 1,
                    style: const TextStyle(
                      fontFamily: 'CormorantGaramond',
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: AppColors.oxblood,
                    ),
                  ),
                ),
              ],
            ),
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
  final VoidCallback? onComplete;

  const StaggeredPlaque({
    super.key,
    required this.index,
    required this.child,
    this.onComplete,
  });

  @override
  State<StaggeredPlaque> createState() => _StaggeredPlaqueState();
}

class _StaggeredPlaqueState extends State<StaggeredPlaque> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _rotationAnimation;
  late final Animation<double> _fadeAnimation;
  Timer? _startTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.15, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );
    _rotationAnimation = Tween<double>(begin: -0.03, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onComplete?.call();
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (AppMotion.reduce(context)) {
        // under reduce-motion we return child directly in build
      } else {
        final delay = 400 + AppMotion.ceremonyStep.inMilliseconds * widget.index;
        _startTimer = Timer(Duration(milliseconds: delay), () {
          if (mounted) {
            _controller.forward();
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _startTimer?.cancel();
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
          child: Transform(
            transform: Matrix4.identity()
              ..scale(_scaleAnimation.value)
              ..rotateZ(_rotationAnimation.value),
            alignment: Alignment.center,
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}
