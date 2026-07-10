import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'firebase_options.dart';
import 'theme/app_colors.dart';

// Screens
import 'screens/lobby_screen.dart';
import 'screens/phase2_craft.dart';
import 'screens/phase3_vote.dart';
import 'screens/phase4_reveal.dart';
import 'screens/game_over_screen.dart';
import 'services/game_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  try {
    await FirebaseAuth.instance.signInAnonymously();
  } catch (e) {
    debugPrint('Error signing in anonymously: $e');
  }

  runApp(
    ChangeNotifierProvider(
      create: (context) => GameService(),
      child: const GaslightApp(),
    ),
  );
}

class GaslightApp extends StatelessWidget {
  const GaslightApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gaslight',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.ground,
        fontFamily: 'Lora',
        textTheme: ThemeData.dark().textTheme.apply(
          fontFamily: 'Lora',
          bodyColor: AppColors.ivory,
          displayColor: AppColors.brass,
        ),
        colorScheme: const ColorScheme.dark(
          primary: AppColors.oxblood,
          secondary: AppColors.brass,
          tertiary: AppColors.verdigris,
          surface: AppColors.parchment,
          onSurface: AppColors.ink,
        ),
        useMaterial3: true,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const LobbyScreen(),
        '/craft': (context) => const Phase2CraftScreen(),
        '/vote': (context) => const Phase3VoteScreen(),
        '/reveal': (context) => const Phase4RevealScreen(),
        '/game-over': (context) => const GameOverScreen(),
      },
    );
  }
}
