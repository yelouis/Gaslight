import 'package:flutter/material.dart';
import 'package:gaslight/widgets/shared_ui.dart';

/// Displays the rules and game manual modal dialog.
void showGameInstructionsDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (context) => const GameInstructionsDialog(),
  );
}

/// The complete multi-section instruction manual for Gaslight.
class GameInstructionsDialog extends StatelessWidget {
  const GameInstructionsDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 800),
        child: ParchmentCard(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Text(
                  'HOW TO PLAY',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'Lora',
                    letterSpacing: 2,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              Divider(color: theme.colorScheme.primary.withOpacity(0.5), thickness: 2),
              const SizedBox(height: 12),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(12.0, 0, 12.0, 24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInstructionSection(
                        theme,
                        'THE OBJECTIVE',
                        [
                          _highlightItem('Mimicry: ', 'Every player receives a secret card with a prompt. You are the "Target" of your card.'),
                          _highlightItem('Forgery: ', 'Cards rotate. You will receive others\' cards to write believable lies (Forgeries) on their behalf.'),
                        ],
                      ),
                      _buildInstructionSection(
                        theme,
                        'THE PHASES',
                        [
                          _highlightItem('Forgery: ', 'Write deceptive answers for the cards you hold. These will be mixed with the real Target\'s truth.'),
                          _highlightItem('Truth: ', 'You get your own card back. Write the cold, hard biological truth.'),
                          _highlightItem('The Vote: ', 'A Reader presents all answers (1 Truth + Several Forgeries). Voters must find the Truth.'),
                        ],
                      ),
                      _buildInstructionSection(
                        theme,
                        '3. SCORING (Dynamic)',
                        [
                          _highlightItem('Finding Truth: ', 'Earn points for identifying the real truth. The bounty scales with difficulty — the fewer forgeries to hide behind and the more players in the game, the higher the reward.*'),
                          _highlightItem('Believable Target: ', 'Targets earn +1 point for every player who correctly identifies their real answer.'),
                          _highlightItem('Successful Forgery: ', 'Earn +1 point for every player fooled into voting for your lie.'),
                          _highlightItem('Sharp Eye: ', 'Spot the truth on a card you also forged? Earn +1 bonus point.'),
                          _highlightItem('Unmask Revenge: ', 'Fooled by a forgery? Accuse the author during the unmask window. Correct = +1 to you, -1 to them.'),
                          _highlightItem('Round Multiplier: ', 'Later rounds raise the stakes — card points are multiplied by the round number (Round 1: 1×, Round 2: 2×, Round 3: 3×).'),
                          _highlightItem('* Formula: ', 'ceil((Players - 1) / (Forgeries + 1))'),
                        ],
                      ),
                      _buildInstructionSection(
                        theme,
                        '4. CUSTOM DECKS',
                        [
                          _highlightItem('Contribute: ', 'Write up to 3 custom prompts in the lobby to play on your own decks.'),
                          _highlightItem('Fair Play: ', 'You will never be dealt a prompt you authored yourself.'),
                        ],
                      ),
                      _buildInstructionSection(
                        theme,
                        '5. PROMPT INTEGRITY',
                        [
                          _highlightItem('AI Filter: ', 'The game uses semantic analysis to reject answers too similar to existing ones. Be original!'),
                        ],
                      ),
                      _buildInstructionSection(
                        theme,
                        '6. SOUND SETTINGS',
                        [
                          _highlightItem('Mute Toggle: ', 'Toggle the handbell icon in the lobby or reveal screens to mute/unmute game sound effects.'),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: const Color(0xFFF5EEDB),
                  minimumSize: const Size(double.infinity, 55),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(color: theme.colorScheme.secondary, width: 2),
                  ),
                  elevation: 4,
                ),
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('GOT IT', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 2.0)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  TextSpan _highlightItem(String boldPart, String normalPart) {
    return TextSpan(
      children: [
        TextSpan(text: boldPart, style: const TextStyle(fontWeight: FontWeight.w900)),
        TextSpan(text: normalPart, style: const TextStyle(fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildInstructionSection(ThemeData theme, String title, List<TextSpan> bulletPoints) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceTint.withOpacity(0.1),
              border: Border(left: BorderSide(color: theme.colorScheme.secondary, width: 4)),
            ),
            child: Text(
              title,
              style: TextStyle(
                color: theme.colorScheme.primary,
                fontSize: 20,
                fontWeight: FontWeight.w900,
                fontFamily: 'Lora',
                letterSpacing: 1.2,
              ),
            ),
          ),
          const SizedBox(height: 12),
          ...bulletPoints.map((span) => Padding(
            padding: const EdgeInsets.only(bottom: 10.0, left: 8.0, right: 8.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('• ', style: TextStyle(color: theme.colorScheme.secondary, fontSize: 18, fontWeight: FontWeight.bold)),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: TextStyle(
                        color: theme.colorScheme.onSurface,
                        fontSize: 16,
                        height: 1.5,
                      ),
                      children: [span],
                    ),
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }
}
