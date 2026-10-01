import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_icons.dart';

/// The Parlour Remembers rivalry ledger, displayed on waiting screens.
///
/// Shows match-long rivalry pairs split into FOOLED and SPOTTED groups.
/// Each row is keyed by pair identity and can expand to show the card prompts
/// and lies behind the occurrences.
class ParlourLedger extends StatefulWidget {
  final Map<String, dynamic>? runningRivalries;

  const ParlourLedger({
    super.key,
    required this.runningRivalries,
  });

  @override
  State<ParlourLedger> createState() => _ParlourLedgerState();
}

class _ParlourLedgerState extends State<ParlourLedger> {
  final Set<String> _expandedKeys = <String>{};

  void _toggleRow(String key) {
    setState(() {
      if (_expandedKeys.contains(key)) {
        _expandedKeys.remove(key);
      } else {
        _expandedKeys.add(key);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final rivalries = widget.runningRivalries;
    if (rivalries == null) return const SizedBox.shrink();

    final foolsRaw = rivalries['fools'];
    final readsRaw = rivalries['reads'];

    final fools = (foolsRaw is List ? foolsRaw : const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    final reads = (readsRaw is List ? readsRaw : const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();

    if (fools.isEmpty && reads.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      key: const ValueKey('parlour_ledger'),
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 400),
      margin: const EdgeInsets.only(top: 20),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.groundRaised,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppColors.brass.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Row(
            children: [
              ThematicIcon(
                type: ThematicIconType.ledger,
                size: 18,
                color: AppColors.brass,
              ),
              SizedBox(width: 8),
              Flexible(
                child: Text(
                  'THE PARLOUR REMEMBERS',
                  style: TextStyle(
                    fontFamily: 'CormorantGaramond',
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.brass,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
            ],
          ),
          if (fools.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildGroupHeader(
              title: 'FOOLED',
              subtitle: 'picked their lie as the truth',
            ),
            const SizedBox(height: 6),
            for (final pair in fools) _buildFoolRow(pair),
          ],
          if (reads.isNotEmpty) ...[
            if (fools.isNotEmpty) const SizedBox(height: 14),
            _buildGroupHeader(
              title: 'SPOTTED',
              subtitle: 'named the liar on their own card',
            ),
            const SizedBox(height: 6),
            for (int i = 0; i < reads.length; i++)
              _buildReadRow(reads[i], isClosest: i == 0),
          ],
        ],
      ),
    );
  }

  Widget _buildGroupHeader({required String title, required String subtitle}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontFamily: 'CormorantGaramond',
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: AppColors.brass,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: const TextStyle(
            fontFamily: 'Lora',
            fontStyle: FontStyle.italic,
            fontSize: 11,
            color: AppColors.ivory,
          ),
        ),
      ],
    );
  }

  Widget _buildFoolRow(Map<String, dynamic> pair) {
    final deceiverId = pair['deceiverId']?.toString() ?? '';
    final victimId = pair['victimId']?.toString() ?? '';
    final rowKey = 'fools:$deceiverId:$victimId';

    final deceiverName = pair['deceiverName']?.toString() ?? 'Unknown';
    final victimName = pair['victimName']?.toString() ?? 'Unknown';
    final count = pair['count'] ?? 1;

    final occurrences = (pair['occurrences'] as List<dynamic>? ?? [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();

    final isExpanded = _expandedKeys.contains(rowKey);
    final hasOccurrences = occurrences.isNotEmpty;

    return Padding(
      key: ValueKey(rowKey),
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: hasOccurrences ? () => _toggleRow(rowKey) : null,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '$deceiverName fooled $victimName',
                    style: const TextStyle(
                      fontFamily: 'Lora',
                      fontSize: 13,
                      color: AppColors.ivory,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '×$count',
                  style: const TextStyle(
                    fontFamily: 'Lora',
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.brass,
                  ),
                ),
                if (hasOccurrences) ...[
                  const SizedBox(width: 6),
                  Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    size: 16,
                    color: AppColors.brass,
                  ),
                ],
              ],
            ),
          ),
          if (isExpanded && hasOccurrences)
            _buildOccurrencesList(occurrences, isFool: true),
        ],
      ),
    );
  }

  Widget _buildReadRow(Map<String, dynamic> pair, {required bool isClosest}) {
    final readerId = pair['readerId']?.toString() ?? '';
    final forgerId = pair['forgerId']?.toString() ?? '';
    final rowKey = 'reads:$readerId:$forgerId';

    final readerName = pair['readerName']?.toString() ?? 'Unknown';
    final forgerName = pair['forgerName']?.toString() ?? 'Unknown';
    final count = pair['count'] ?? 1;

    final occurrences = (pair['occurrences'] as List<dynamic>? ?? [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();

    final isExpanded = _expandedKeys.contains(rowKey);
    final hasOccurrences = occurrences.isNotEmpty;

    return Padding(
      key: ValueKey(rowKey),
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: hasOccurrences ? () => _toggleRow(rowKey) : null,
            child: Row(
              children: [
                Expanded(
                  child: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    children: [
                      Text(
                        '$readerName spotted $forgerName\'s lie',
                        style: const TextStyle(
                          fontFamily: 'Lora',
                          fontSize: 13,
                          color: AppColors.ivory,
                        ),
                      ),
                      if (isClosest)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.ground,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: AppColors.brass,
                              width: 1,
                            ),
                          ),
                          child: const Text(
                            'CLOSEST',
                            style: TextStyle(
                              fontFamily: 'CormorantGaramond',
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.0,
                              color: AppColors.brass,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '×$count',
                  style: const TextStyle(
                    fontFamily: 'Lora',
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.brass,
                  ),
                ),
                if (hasOccurrences) ...[
                  const SizedBox(width: 6),
                  Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    size: 16,
                    color: AppColors.brass,
                  ),
                ],
              ],
            ),
          ),
          if (isExpanded && hasOccurrences)
            _buildOccurrencesList(occurrences, isFool: false),
        ],
      ),
    );
  }

  Widget _buildOccurrencesList(
    List<Map<String, dynamic>> occurrences, {
    required bool isFool,
  }) {
    return Padding(
      padding: const EdgeInsets.only(left: 12, top: 6, bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final occ in occurrences) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isFool
                        ? 'ROUND ${occ['round']} · ${occ['cardOwnerName'] ?? 'Unknown'}\'s card'
                        : 'ROUND ${occ['round']} · ${occ['cardOwnerName'] ?? 'Unknown'}\'s own card',
                    style: const TextStyle(
                      fontFamily: 'Lora',
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppColors.brass,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    occ['promptText']?.toString() ?? '',
                    style: const TextStyle(
                      fontFamily: 'Lora',
                      fontStyle: FontStyle.italic,
                      fontSize: 12,
                      color: AppColors.ivory,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '“${occ['lieText']?.toString() ?? ''}”',
                    style: const TextStyle(
                      fontFamily: 'CormorantGaramond',
                      fontSize: 14,
                      color: AppColors.ivory,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
