import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:go_to_gym/screens/forgot_password_screen.dart';
import 'package:go_to_gym/screens/signin_screen.dart';
import 'package:go_to_gym/screens/signup_screen.dart';
import 'package:go_to_gym/screens/chat_screen.dart';

// Firebase options
import 'firebase_options.dart';

// Screens
import 'screens/onboarding_screen.dart';
import 'screens/home_screen.dart';
import 'screens/create_post_screen.dart';

// Theme helper
import 'utils/theme_storage.dart';

final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.dark);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Hanya izinkan orientasi portrait
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Ambil tema tersimpan dari SharedPreferences
  final savedTheme = await ThemeStorage.getThemeMode();
  themeNotifier.value = savedTheme;

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, mode, _) {
        return MaterialApp(
          title: 'Go To Gym',
          debugShowCheckedModeBanner: false,
          themeMode: mode,
          theme: ThemeData.light().copyWith(
            scaffoldBackgroundColor: const Color(0xFFF1F5F9),
            primaryColor: const Color(0xFF38BDF8),
            appBarTheme: const AppBarTheme(
              backgroundColor: Color(0xFFF1F5F9),
              iconTheme: IconThemeData(color: Colors.black),
              titleTextStyle: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
            textTheme: const TextTheme(
              bodyMedium: TextStyle(color: Colors.black87),
            ),
            inputDecorationTheme: const InputDecorationTheme(
              labelStyle: TextStyle(color: Colors.black54),
            ),
          ),
          darkTheme: ThemeData.dark().copyWith(
            scaffoldBackgroundColor: const Color(0xFF0F172A),
            primaryColor: const Color(0xFF38BDF8),
            appBarTheme: const AppBarTheme(
              backgroundColor: Color(0xFF0F172A),
              iconTheme: IconThemeData(color: Colors.white),
              titleTextStyle: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
            inputDecorationTheme: const InputDecorationTheme(
              labelStyle: TextStyle(color: Colors.white70),
            ),
            textTheme: const TextTheme(
              bodyMedium: TextStyle(color: Colors.white),
            ),
          ),
          routes: {
            '/signin': (context) => const SignInScreen(),
            '/signup': (context) => const SignUpScreen(),
            '/home': (context) => const HomeScreen(),
            '/forgot-password': (context) => const ForgotPasswordScreen(),
            '/create-post': (context) => const CreatePostScreen(),
            '/chat': (context) => const ChatScreen(),
          },
          home: StreamBuilder<User?>(
            stream: FirebaseAuth.instance.authStateChanges(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              } else if (snapshot.hasData) {
                return const HomeScreen();
              } else {
                return const OnboardingScreen();
              }
            },
          ),
        );
      },
    );
  }
}
