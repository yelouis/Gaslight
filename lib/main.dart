import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

import 'widgets/gaslight_route.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
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
      builder: (context, child) {
        final media = MediaQuery.of(context);
        final scale = media.textScaler.clamp(minScaleFactor: 1.0, maxScaleFactor: 1.3);
        return MediaQuery(
          data: media.copyWith(textScaler: scale),
          child: child!,
        );
      },
      initialRoute: '/',
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/':
            return GaslightPageRoute(child: const LobbyScreen(), settings: settings);
          case '/craft':
            return GaslightPageRoute(child: const Phase2CraftScreen(), settings: settings);
          case '/vote':
            return GaslightPageRoute(child: const Phase3VoteScreen(), settings: settings);
          case '/reveal':
            return GaslightPageRoute(child: const Phase4RevealScreen(), settings: settings);
          case '/game-over':
            return GaslightPageRoute(child: const GameOverScreen(), settings: settings);
          default:
            return null;
        }
      },
    );
  }
}
