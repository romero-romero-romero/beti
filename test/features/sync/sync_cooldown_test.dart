// test/features/sync/sync_cooldown_test.dart
//
// ════════════════════════════════════════════════════════════════════════
// SyncCooldown — política de cooldown para sync automático.
// ════════════════════════════════════════════════════════════════════════
//
// Lógica pura sin dependencias. Tests deterministas inyectando `now`
// explícitamente para evitar flakiness por timing real.
//
// QUÉ VALIDAMOS:
//
// 1. PRIMER TRIGGER siempre pasa (no hay "última" registrada).
//
// 2. FULL SYNC WINDOW de 2 minutos:
//    - Antes de 2 min → bloqueado.
//    - Justo en 2 min → permitido (boundary inclusivo).
//    - Después de 2 min → permitido.
//
// 3. CONNECTIVITY DEBOUNCE de 5 segundos:
//    - Rebote wifi↔celular dentro de 5s → ignorado.
//    - Tras 5s → procesado.
//
// 4. INDEPENDENCIA: ambos cooldowns son independientes — markear uno no
//    afecta al otro.
//
// 5. RESET: utilidad para tests del consumer.
//
// ════════════════════════════════════════════════════════════════════════

import 'package:beti_app/features/sync/presentation/providers/sync_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late SyncCooldown cooldown;

  setUp(() {
    cooldown = SyncCooldown();
  });

  // ══════════════════════════════════════════════════════════════════════
  // CONSTANTES PUBLICADAS
  // ══════════════════════════════════════════════════════════════════════

  group('constantes', () {
    test('fullSyncWindow es 2 minutos', () {
      expect(SyncCooldown.fullSyncWindow, const Duration(minutes: 2));
    });

    test('connectivityDebounce es 5 segundos', () {
      expect(SyncCooldown.connectivityDebounce, const Duration(seconds: 5));
    });
  });

  // ══════════════════════════════════════════════════════════════════════
  // FULL SYNC — primer trigger
  // ══════════════════════════════════════════════════════════════════════

  group('shouldRunFullSync — sin estado previo', () {
    test('primer trigger siempre pasa', () {
      expect(cooldown.shouldRunFullSync(), isTrue);
    });

    test('primer trigger pasa incluso con `now` arbitrario', () {
      final t = DateTime(2026, 5, 7, 10, 0, 0);
      expect(cooldown.shouldRunFullSync(now: t), isTrue);
    });
  });

  // ══════════════════════════════════════════════════════════════════════
  // FULL SYNC — ventana de 2 minutos
  // ══════════════════════════════════════════════════════════════════════

  group('shouldRunFullSync — ventana de 2 min', () {
    test('1 segundo después → bloqueado', () {
      final t0 = DateTime(2026, 5, 7, 10, 0, 0);
      cooldown.markFullSyncCompleted(now: t0);
      final t1 = t0.add(const Duration(seconds: 1));
      expect(cooldown.shouldRunFullSync(now: t1), isFalse);
    });

    test('30 segundos después → bloqueado', () {
      final t0 = DateTime(2026, 5, 7, 10, 0, 0);
      cooldown.markFullSyncCompleted(now: t0);
      final t1 = t0.add(const Duration(seconds: 30));
      expect(cooldown.shouldRunFullSync(now: t1), isFalse);
    });

    test('1 min 59 seg después → bloqueado (justo antes del límite)', () {
      final t0 = DateTime(2026, 5, 7, 10, 0, 0);
      cooldown.markFullSyncCompleted(now: t0);
      final t1 = t0.add(const Duration(minutes: 1, seconds: 59));
      expect(cooldown.shouldRunFullSync(now: t1), isFalse);
    });

    test('2 min exactos → permitido (boundary inclusivo)', () {
      final t0 = DateTime(2026, 5, 7, 10, 0, 0);
      cooldown.markFullSyncCompleted(now: t0);
      final t1 = t0.add(const Duration(minutes: 2));
      expect(cooldown.shouldRunFullSync(now: t1), isTrue);
    });

    test('5 minutos después → permitido', () {
      final t0 = DateTime(2026, 5, 7, 10, 0, 0);
      cooldown.markFullSyncCompleted(now: t0);
      final t1 = t0.add(const Duration(minutes: 5));
      expect(cooldown.shouldRunFullSync(now: t1), isTrue);
    });

    test('un nuevo markCompleted RESETEA la ventana', () {
      final t0 = DateTime(2026, 5, 7, 10, 0, 0);
      cooldown.markFullSyncCompleted(now: t0);

      // 3 minutos después: permitido.
      final t1 = t0.add(const Duration(minutes: 3));
      expect(cooldown.shouldRunFullSync(now: t1), isTrue);
      cooldown.markFullSyncCompleted(now: t1);

      // 1 minuto después de eso: bloqueado (porque la última fue en t1).
      final t2 = t1.add(const Duration(minutes: 1));
      expect(cooldown.shouldRunFullSync(now: t2), isFalse);
    });
  });

  // ══════════════════════════════════════════════════════════════════════
  // CONNECTIVITY DEBOUNCE
  // ══════════════════════════════════════════════════════════════════════

  group('shouldHandleConnectivityChange', () {
    test('primer trigger sin estado previo → permitido', () {
      expect(cooldown.shouldHandleConnectivityChange(), isTrue);
    });

    test('rebote dentro de 5s → ignorado', () {
      final t0 = DateTime(2026, 5, 7, 10, 0, 0);
      cooldown.markConnectivityTriggered(now: t0);
      final t1 = t0.add(const Duration(seconds: 2));
      expect(cooldown.shouldHandleConnectivityChange(now: t1), isFalse);
    });

    test('4 segundos después → ignorado', () {
      final t0 = DateTime(2026, 5, 7, 10, 0, 0);
      cooldown.markConnectivityTriggered(now: t0);
      final t1 = t0.add(const Duration(seconds: 4));
      expect(cooldown.shouldHandleConnectivityChange(now: t1), isFalse);
    });

    test('5 segundos exactos → permitido', () {
      final t0 = DateTime(2026, 5, 7, 10, 0, 0);
      cooldown.markConnectivityTriggered(now: t0);
      final t1 = t0.add(const Duration(seconds: 5));
      expect(cooldown.shouldHandleConnectivityChange(now: t1), isTrue);
    });

    test('10 segundos después → permitido', () {
      final t0 = DateTime(2026, 5, 7, 10, 0, 0);
      cooldown.markConnectivityTriggered(now: t0);
      final t1 = t0.add(const Duration(seconds: 10));
      expect(cooldown.shouldHandleConnectivityChange(now: t1), isTrue);
    });

    test(
        'múltiples rebotes en serie: solo el primero pasa, el resto se ignora',
        () {
      final t0 = DateTime(2026, 5, 7, 10, 0, 0);
      // wifi → celular en t0
      expect(cooldown.shouldHandleConnectivityChange(now: t0), isTrue);
      cooldown.markConnectivityTriggered(now: t0);

      // celular → wifi 1s después: rebote, debe ignorarse.
      final t1 = t0.add(const Duration(seconds: 1));
      expect(cooldown.shouldHandleConnectivityChange(now: t1), isFalse);

      // wifi → celular 2s después: rebote, debe ignorarse.
      final t2 = t0.add(const Duration(seconds: 2));
      expect(cooldown.shouldHandleConnectivityChange(now: t2), isFalse);

      // 6s después: la red estabilizada, permite.
      final t3 = t0.add(const Duration(seconds: 6));
      expect(cooldown.shouldHandleConnectivityChange(now: t3), isTrue);
    });
  });

  // ══════════════════════════════════════════════════════════════════════
  // INDEPENDENCIA DE LAS DOS VENTANAS
  // ══════════════════════════════════════════════════════════════════════

  group('independencia de cooldowns', () {
    test('marcar fullSync NO afecta al cooldown de connectivity', () {
      final t0 = DateTime(2026, 5, 7, 10, 0, 0);
      cooldown.markFullSyncCompleted(now: t0);
      // Inmediatamente después, connectivity debe seguir disponible.
      expect(cooldown.shouldHandleConnectivityChange(now: t0), isTrue);
    });

    test('marcar connectivity NO afecta al cooldown de fullSync', () {
      final t0 = DateTime(2026, 5, 7, 10, 0, 0);
      cooldown.markConnectivityTriggered(now: t0);
      // Inmediatamente después, fullSync debe seguir disponible.
      expect(cooldown.shouldRunFullSync(now: t0), isTrue);
    });
  });

  // ══════════════════════════════════════════════════════════════════════
  // RESET
  // ══════════════════════════════════════════════════════════════════════

  group('reset', () {
    test('reset libera ambos cooldowns', () {
      final t0 = DateTime(2026, 5, 7, 10, 0, 0);
      cooldown.markFullSyncCompleted(now: t0);
      cooldown.markConnectivityTriggered(now: t0);

      // Inmediatamente bloqueados.
      final t1 = t0.add(const Duration(seconds: 1));
      expect(cooldown.shouldRunFullSync(now: t1), isFalse);
      expect(cooldown.shouldHandleConnectivityChange(now: t1), isFalse);

      // Reset.
      cooldown.reset();

      // Mismo tiempo, ambos liberados.
      expect(cooldown.shouldRunFullSync(now: t1), isTrue);
      expect(cooldown.shouldHandleConnectivityChange(now: t1), isTrue);
    });
  });

  // ══════════════════════════════════════════════════════════════════════
  // ESCENARIOS REALES
  // ══════════════════════════════════════════════════════════════════════

  group('escenarios reales', () {
    test('app sale-vuelve en 30s tras una sync: la 2da se bloquea', () {
      // T=0: usuario abre la app, sync exitoso.
      final t0 = DateTime(2026, 5, 7, 10, 0, 0);
      expect(cooldown.shouldRunFullSync(now: t0), isTrue);
      cooldown.markFullSyncCompleted(now: t0);

      // T+30s: usuario va al lockscreen y vuelve. resumed dispara
      // _triggerFullSync, pero el cooldown lo ignora.
      final t30 = t0.add(const Duration(seconds: 30));
      expect(cooldown.shouldRunFullSync(now: t30), isFalse);
    });

    test('app sale-vuelve en 3 min tras una sync: la 2da pasa', () {
      final t0 = DateTime(2026, 5, 7, 10, 0, 0);
      cooldown.markFullSyncCompleted(now: t0);

      // T+3min: ya pasó el cooldown. La 2da sync se ejecuta.
      final t3min = t0.add(const Duration(minutes: 3));
      expect(cooldown.shouldRunFullSync(now: t3min), isTrue);
    });

    test(
        'subway scenario: rebotes en ráfaga (≤4s) se ignoran tras el primero',
        () {
      final t0 = DateTime(2026, 5, 7, 10, 0, 0);
      var triggers = 0;

      // 4 rebotes en una ráfaga corta (0s, 1s, 2s, 3s) — todos dentro
      // de la ventana de 5s desde t=0.
      for (int i = 0; i < 4; i++) {
        final t = t0.add(Duration(seconds: i));
        if (cooldown.shouldHandleConnectivityChange(now: t)) {
          cooldown.markConnectivityTriggered(now: t);
          triggers++;
        }
      }

      expect(triggers, 1,
          reason: 'la ráfaga de 4 eventos en ≤3s → solo el primero pasa');
    });

    test(
        'rolling debounce: tras 5s estabilizada, una NUEVA ráfaga sí dispara',
        () {
      final t0 = DateTime(2026, 5, 7, 10, 0, 0);
      var triggers = 0;

      // Ráfaga 1 en t=0,1,2 → solo el primero pasa.
      for (final s in [0, 1, 2]) {
        final t = t0.add(Duration(seconds: s));
        if (cooldown.shouldHandleConnectivityChange(now: t)) {
          cooldown.markConnectivityTriggered(now: t);
          triggers++;
        }
      }
      expect(triggers, 1);

      // Tras 6 segundos, una nueva ráfaga: el primero pasa de nuevo.
      // Esto es semántica deseada — si la red sigue cambiando tras
      // estabilizarse, queremos saber del último estado real.
      final tAfter = t0.add(const Duration(seconds: 6));
      if (cooldown.shouldHandleConnectivityChange(now: tAfter)) {
        cooldown.markConnectivityTriggered(now: tAfter);
        triggers++;
      }
      expect(triggers, 2,
          reason: 'tras la ventana, un nuevo cambio reactiva el listener');
    });
  });
}