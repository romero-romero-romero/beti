import 'package:betty_app/presentation/screens/home_screen.dart';
import 'package:betty_app/presentation/screens/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");

  String supabaseUrl = dotenv.env['SUPABASE_URL'] ?? '';
  String supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'] ?? '';

  try {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
      debug: true,
    );
  } catch (e) {
    debugPrint('Error initializing Supabase: $e');
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Betty App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.lightGreenAccent),
        useMaterial3: true,
      ),
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  final SupabaseClient supabase = Supabase.instance.client;
  bool _initializing = true;

  @override
  void initState() {
    super.initState();
    _checkAuthState();
  }

  Future<void> _checkAuthState() async {
    try {
      final session = supabase.auth.currentSession;
      if (session != null) {
        _navigateToHome();
      } else {
        setState(() {
          _initializing = false;
        });
      }
    } catch (e) {
      debugPrint('Error checking auth state: $e');
      setState(() {
        _initializing = false;
      });
    }
  }

  void _navigateToHome() {
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return _initializing
        ? const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          )
        : const LoginScreen();
  }
}
