import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:betty_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:betty_app/features/sync/presentation/providers/sync_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final syncState = ref.watch(syncProvider);
    final pendingAsync = ref.watch(pendingSyncCountProvider);
    final theme = Theme.of(context);

    final user = authState is AuthAuthenticated ? authState.user : null;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const SizedBox(height: 20),
              // Avatar
              CircleAvatar(
                radius: 40,
                backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
                child: Text(
                  (user?.displayName?.isNotEmpty == true ? user!.displayName![0] : user?.email[0] ?? 'B').toUpperCase(),
                  style: TextStyle(fontSize: 32, color: theme.colorScheme.primary, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 16),
              Text(user?.displayName ?? 'Usuario', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              Text(user?.email ?? '', style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey)),
              const SizedBox(height: 32),

              // Sync status
              Card(
                child: ListTile(
                  leading: Icon(
                    syncState == SyncState.syncing ? Icons.sync : Icons.cloud_done_outlined,
                    color: syncState == SyncState.syncing ? Colors.orange : Colors.green,
                  ),
                  title: Text(syncState == SyncState.syncing ? 'Sincronizando...' : 'Sincronizado'),
                  subtitle: pendingAsync.when(
                    data: (count) => Text(count > 0 ? '$count cambios pendientes' : 'Todo al día'),
                    loading: () => const Text('Verificando...'),
                    error: (_, __) => const Text('Error'),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: () => ref.read(syncProvider.notifier).forceSync(),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Settings cards
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.currency_exchange),
                      title: const Text('Moneda'),
                      trailing: Text(user?.currency.toUpperCase() ?? 'MXN', style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.notifications_outlined),
                      title: const Text('Notificaciones'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Configuración de notificaciones próximamente')),
                        );
                      },
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.palette_outlined),
                      title: const Text('Apariencia'),
                      subtitle: const Text('Sigue la configuración del sistema'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {},
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Info
              Card(
                child: Column(
                  children: [
                    const ListTile(
                      leading: Icon(Icons.info_outline),
                      title: Text('Betty MVP'),
                      subtitle: Text('Versión 1.0.0'),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.shield_outlined),
                      title: const Text('Privacidad'),
                      subtitle: const Text('Todos tus datos se procesan en tu dispositivo'),
                      onTap: () {},
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Logout
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (c) => AlertDialog(
                        title: const Text('Cerrar sesión'),
                        content: const Text('Tus datos locales se conservarán.'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
                          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Cerrar sesión')),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      ref.read(authProvider.notifier).signOut();
                    }
                  },
                  icon: const Icon(Icons.logout, color: Colors.red),
                  label: const Text('Cerrar sesión', style: TextStyle(color: Colors.red)),
                  style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red)),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
