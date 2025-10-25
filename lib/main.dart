import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'package:musicapp/models/song.dart';
import 'package:musicapp/providers/music_provider.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

import 'screens/onboarding_screen.dart';
import 'screens/artist_detail_screen.dart';
import 'screens/player_screen.dart';
import 'screens/add_song.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables from .env file
  try {
    await dotenv.load(fileName: ".env");
    debugPrint('✅ Environment variables loaded successfully');
  } catch (e) {
    debugPrint('⚠️ Error loading .env file: $e');
    debugPrint('Make sure .env file exists in the project root');
  }

  // Initialize Firebase with environment variables
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint('✅ Firebase initialized successfully');
  } catch (e) {
    debugPrint('❌ Firebase initialization error: $e');
  }

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  static final ThemeData _appTheme = _buildAppTheme();

  static ThemeData _buildAppTheme() {
    final colorScheme = const ColorScheme.dark(
      primary: Color(0xFF27C77A),
      secondary: Color(0xFF27C77A),
      surface: Color(0xFF171A1C),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colorScheme.surface,
      textTheme: GoogleFonts.poppinsTextTheme().apply(
        bodyColor: Colors.white,
        displayColor: Colors.white,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: Colors.black,
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    // Add app lifecycle observer to handle app state changes
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    // Remove app lifecycle observer
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    // Get music provider without listening for changes
    final musicProvider = Provider.of<MusicProvider>(context, listen: false);

    switch (state) {
      case AppLifecycleState.paused:
        // App is in background - pause if playing to save resources
        debugPrint('🔵 App paused - managing audio resources');
        if (musicProvider.isPlaying) {
          musicProvider.pause();
        }
        break;
      case AppLifecycleState.resumed:
        // App is back in foreground
        debugPrint('🟢 App resumed');
        // Don't auto-resume - let user control playback
        break;
      case AppLifecycleState.inactive:
        // App is inactive (e.g., phone call, notification panel)
        debugPrint('🟡 App inactive');
        break;
      case AppLifecycleState.detached:
        // App is being destroyed - clean up properly
        debugPrint('🔴 App detached - cleaning up resources');
        musicProvider.cleanup();
        break;
      case AppLifecycleState.hidden:
        // App is hidden (iOS specific)
        debugPrint('⚫ App hidden');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => MusicProvider()..initialize()),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: dotenv.env['APP_NAME'] ?? 'MusicApp',
        theme: _appTheme,
        routes: {
          '/': (_) => const OnboardingScreen(),
          ArtistDetailScreen.routeName: (_) => const ArtistDetailScreen(),
          PlayerScreen.routeName: (context) {
            final arguments = ModalRoute.of(context)?.settings.arguments;

            if (arguments is Song) {
              return PlayerScreen(song: arguments, albumSongs: const []);
            }

            return Scaffold(
              appBar: AppBar(title: const Text('Navigation Error')),
              body: const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    'Could not load song data. Please go back and try again.',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            );
          },
          AddSongScreen.routeName: (_) => const AddSongScreen(),
        },
      ),
    );
  }
}