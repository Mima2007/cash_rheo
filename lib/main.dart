import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'pages/login_page.dart';
import 'pages/home_page.dart';
import 'pages/qr_scan_page.dart';
import 'pages/document_scan_page.dart';
import 'pages/register_page.dart';
import 'services/auth_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://vxjrctfjezzmgcrbhvwb.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZ4anJjdGZqZXp6bWdjcmJodndiIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQwOTA0OTcsImV4cCI6MjA4OTY2NjQ5N30.EUZtud0jrOAyiaDvQ4PST0y08aO-q0a3mwvrAVNrZzo',
  );
  await AuthService.loadSavedSession();
  runApp(const CashRheoApp());
}

final supabase = Supabase.instance.client;

class CashRheoApp extends StatelessWidget {
  const CashRheoApp({super.key});
  @override
  Widget build(BuildContext context) {
    final router = GoRouter(
      initialLocation: '/login',
      redirect: (context, state) {
        final supabaseSession = supabase.auth.currentSession;
        final googleSession = AuthService.userEmail != null;
        final isLoggedIn = supabaseSession != null || googleSession;
        final isLogin = state.matchedLocation == '/login' || state.matchedLocation == '/register';
        if (!isLoggedIn && !isLogin) return '/login';
        if (isLoggedIn && isLogin) return '/home';
        return null;
      },
      routes: [
        GoRoute(path: '/login', builder: (c, s) => const LoginPage()),
        GoRoute(path: '/register', builder: (c, s) => const RegisterPage()),
        GoRoute(path: '/home', builder: (c, s) => const HomePage()),
        GoRoute(path: '/qr-scan', builder: (c, s) => const QRScanPage()),
        GoRoute(path: '/document-scan', builder: (c, s) => const DocumentScanPage()),
      ],
    );
    return MaterialApp.router(
      title: 'Cash Rheo',
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF1C1C1E),
        primaryColor: const Color(0xFF6FDDCE),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF6FDDCE),
          secondary: Color(0xFFB0B0B0),
          surface: Color(0xFF2C2C2E),
        ),
        textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF6FDDCE),
            foregroundColor: const Color(0xFF1C1C1E),
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF2C2C2E),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF6FDDCE)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF3A3A3C)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF6FDDCE), width: 2),
          ),
        ),
      ),
    );
  }
}
