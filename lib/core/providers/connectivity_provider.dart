import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Emite true cuando hay internet, false cuando no.
/// Usado por el SyncProvider para decidir si despachar la cola.
final connectivityProvider = StreamProvider<bool>((ref) {
  final connectivity = Connectivity();

  // Transformar el stream de ConnectivityResult a un simple bool
  return connectivity.onConnectivityChanged.map((results) {
    return results.any((r) => r != ConnectivityResult.none);
  });
});

/// Provider one-shot para verificar conectividad actual.
final hasInternetProvider = FutureProvider<bool>((ref) async {
  final results = await Connectivity().checkConnectivity();
  return results.any((r) => r != ConnectivityResult.none);
});
