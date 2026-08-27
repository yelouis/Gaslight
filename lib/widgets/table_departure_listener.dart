import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/game_service.dart';

class TableDepartureListener extends StatefulWidget {
  final Widget child;

  const TableDepartureListener({super.key, required this.child});

  @override
  State<TableDepartureListener> createState() => _TableDepartureListenerState();
}

class _TableDepartureListenerState extends State<TableDepartureListener> {
  GameService? _gameService;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final gs = Provider.of<GameService>(context, listen: false);
    if (_gameService != gs) {
      _gameService?.removeListener(_onServiceUpdate);
      _gameService = gs;
      _gameService?.addListener(_onServiceUpdate);
    }
  }

  @override
  void dispose() {
    _gameService?.removeListener(_onServiceUpdate);
    super.dispose();
  }

  void _onServiceUpdate() {
    final msgs = _gameService?.consumeDepartureMessages() ?? const [];
    if (msgs.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      for (final msg in msgs) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
