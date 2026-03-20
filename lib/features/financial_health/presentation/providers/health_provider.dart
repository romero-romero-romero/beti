import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:betty_app/core/enums/health_level.dart';
import 'package:betty_app/core/providers/core_providers.dart';
import 'package:betty_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:betty_app/features/financial_health/data/datasources/health_engine.dart';

final healthEngineProvider = Provider<HealthEngine>((ref) {
  return HealthEngine(ref.watch(isarProvider));
});

final healthProvider = FutureProvider<HealthResult>((ref) async {
  final authState = ref.watch(authProvider);
  if (authState is! AuthAuthenticated) {
    return const HealthResult(
      score: 50,
      level: HealthLevel.stable,
      message: 'Inicia sesión para ver tu salud financiera',
      totalIncome: 0,
      totalExpenses: 0,
      expenseToIncomeRatio: 0,
      totalDebt: 0,
      overduePayments: 0,
      creditUtilizationRatio: 0,
      goalProgressAvg: 0,
    );
  }

  return await ref.read(healthEngineProvider).calculate(authState.user.supabaseId);
});
