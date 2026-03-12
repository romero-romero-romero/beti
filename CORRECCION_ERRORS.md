# Betty — Corrección de errores de flutter analyze

## Archivos corregidos (reemplazar en tu proyecto)

### 9 Modelos Isar (enums locales para isar_generator)
Cada modelo ahora declara sus enums localmente con prefijos únicos:
- `lib/features/auth/data/models/user_model.dart`
- `lib/features/transactions/data/models/transaction_model.dart`
- `lib/features/transactions/data/models/category_model.dart`
- `lib/features/financial_health/data/models/health_snapshot_model.dart`
- `lib/features/cards_credits/data/models/credit_card_model.dart`
- `lib/features/cards_credits/data/models/credit_model.dart`
- `lib/features/budgets_goals/data/models/budget_model.dart`
- `lib/features/budgets_goals/data/models/goal_model.dart`
- `lib/features/sync/data/models/sync_queue_model.dart`

### Core
- `lib/core/database/isar_instance.dart` — sin cambios funcionales, mismo archivo
- `lib/core/errors/failures.dart` — `///` → `//` para fix dangling_library_doc_comments
- `lib/core/errors/exceptions.dart` — `///` → `//` para fix dangling_library_doc_comments
- `lib/core/enums/enums.dart` — añadida tabla de mapeo Isar ↔ Core

### Test
- `test/widget_test.dart` — reemplazado smoke test (MyApp ya no existe)

## Después de reemplazar, ejecuta:
```bash
dart run build_runner build --delete-conflicting-outputs
flutter analyze
```

## ¿Por qué enums duplicados?
isar_generator 3.x no soporta enums importados desde archivos externos.
Los enums en `core/enums/` siguen siendo la referencia canónica para
Use Cases, Providers y UI. Los modelos Isar usan copias locales con
prefijos (`TxType`, `CcNetwork`, etc.) para evitar colisiones de nombres.
El mapeo entre ambos se hará en los Repositories (Fase 2).
