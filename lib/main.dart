import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'firebase_options.dart';
import 'theme/app_colors.dart';
import 'theme/app_text_styles.dart';

// Screens
import 'screens/lobby_screen.dart';
import 'screens/phase2_craft.dart';
import 'screens/phase3_vote.dart';
import 'screens/phase4_reveal.dart';
import 'screens/game_over_screen.dart';
import 'services/game_service.dart';

import 'package:marionette_flutter/marionette_flutter.dart';
import 'widgets/gaslight_route.dart';
import 'widgets/table_departure_listener.dart';

void main() async {
  if (kDebugMode) {
    MarionetteBinding.ensureInitialized();
  } else {
    WidgetsFlutterBinding.ensureInitialized();
  }
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await dotenv.load(fileName: ".env");

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  final useEmulator = const bool.fromEnvironment('USE_EMULATOR', defaultValue: false) || (dotenv.isInitialized && dotenv.env['USE_EMULATOR'] == 'true');
  if (useEmulator) {
    try {
      FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080);
      FirebaseFunctions.instance.useFunctionsEmulator('localhost', 5001);
      FirebaseAuth.instance.useAuthEmulator('localhost', 9099);
    } catch (e) {
      debugPrint('Emulator already initialized in main: $e');
    }
  }

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
        dialogTheme: DialogThemeData(
          backgroundColor: AppColors.groundRaised,
          titleTextStyle: AppTextStyles.cardHeader.copyWith(color: AppColors.brass),
          contentTextStyle: AppTextStyles.bodyIvory,
        ),
        useMaterial3: true,
      ),
      builder: (context, child) {
        final media = MediaQuery.of(context);
        final scale = media.textScaler.clamp(minScaleFactor: 1.0, maxScaleFactor: 1.3);
        return MediaQuery(
          data: media.copyWith(textScaler: scale),
          child: TableDepartureListener(child: child!),
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
