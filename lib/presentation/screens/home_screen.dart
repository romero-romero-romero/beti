import 'package:flutter/material.dart';
import 'package:betty_app/presentation/screens/login_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Betty App'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await Supabase.instance.client.auth.signOut();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              }
            },
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              '¡Bienvenido!',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            if (user != null) ...[
              Text(
                'Usuario: ${user.email}',
                style: const TextStyle(fontSize: 16),
              ),
              if (user.userMetadata?['full_name'] != null) ...[
                const SizedBox(height: 10),
                Text(
                  'Nombre: ${user.userMetadata?['full_name']}',
                  style: const TextStyle(fontSize: 16),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
