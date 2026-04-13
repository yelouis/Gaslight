import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'firebase_options.dart';

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
        scaffoldBackgroundColor:
            const Color(0xFF141A17), // Deep dark fantasy tavern/ruins
        textTheme: GoogleFonts.loraTextTheme(ThemeData.dark().textTheme).apply(
          bodyColor: const Color(0xFFF5EEDB), // Antique ivory text
          displayColor: const Color(0xFFD4AF37), // Gold headers
        ),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF8B0000), // Deep Burgundy/Crimson
          secondary: Color(0xFFD4AF37), // Antique Gold
          tertiary: Color(0xFF1B5E20), // Emerald Green
          surface: Color(0xFFF4EBD8), // Parchment/Warm wood for cards
          onSurface: Color(0xFF2C1E16), // Dark brown ink on parchment
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
