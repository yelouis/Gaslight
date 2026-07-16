import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../theme/app_colors.dart';
import '../theme/app_motion.dart';
import '../theme/app_icons.dart';
import '../services/audio_service.dart';

class RoomCodePlaque extends StatefulWidget {
  final String code;

  const RoomCodePlaque({super.key, required this.code});

  @override
  State<RoomCodePlaque> createState() => _RoomCodePlaqueState();
}

class _RoomCodePlaqueState extends State<RoomCodePlaque> {
  double _scale = 1.0;

  void _copyToClipboard() async {
    await Clipboard.setData(ClipboardData(text: widget.code));
    
    setState(() {
      _scale = 0.96;
    });
    
    await Future.delayed(AppMotion.fast);
    if (mounted) {
      setState(() {
        _scale = 1.0;
      });
    }
    
    HapticFeedback.selectionClick();
    AudioService.instance.playVote(); // thunk sound
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Code ${widget.code} copied — summon your suspects.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AnimatedScale(
        scale: _scale,
        duration: AppMotion.fast,
        child: Container(
          width: 320,
          height: 84,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFFD8B460),
                AppColors.brass,
                Color(0xFF8A6D2F),
              ],
            ),
            border: Border.all(
              color: const Color(0xFF6E571F),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: _copyToClipboard,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'ROOM CODE',
                            style: TextStyle(
                              fontFamily: 'Lora',
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xB22C1E16), // ink @ 0.7
                              letterSpacing: 3,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Padding(
                            padding: const EdgeInsets.only(left: 12.0), // Offset the letterSpacing on the end
                            child: Text(
                              widget.code,
                              style: const TextStyle(
                                fontFamily: 'CormorantGaramond',
                                fontSize: 40,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 12,
                                color: AppColors.ink,
                                shadows: [
                                  Shadow(
                                    color: Color(0x59F5EEDB), // ivory @ 0.35
                                    offset: Offset(0, 1),
                                  ),
                                  Shadow(
                                    color: Color(0x66000000), // black @ 0.4
                                    offset: Offset(0, -1),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(4),
                    onTap: () {
                      Share.share('Join my Gaslight game! Room code: ${widget.code}');
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(6.0),
                      child: ThematicIcon(
                        type: ThematicIconType.envelope,
                        size: 22,
                        color: AppColors.ink.withOpacity(0.7),
                      ),
                    ),
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
