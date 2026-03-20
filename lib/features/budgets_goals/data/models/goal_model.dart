import 'package:isar/isar.dart';

part 'goal_model.g.dart';

/// Metas de ahorro del usuario.
@collection
class GoalModel {
  Id id = Isar.autoIncrement;

  @Index(unique: true)
  late String uuid;

  @Index()
  late String userId;

  late String name;

  late double targetAmount;

  late double savedAmount;

  DateTime? deadline;

  String? icon;

  /// savedAmount / targetAmount (0.0 a 1.0+).
  late double progress;

  late bool isCompleted;

  late bool isActive;

  late DateTime createdAt;

  late DateTime updatedAt;

  @Enumerated(EnumType.name)
  late GoalSyncStatus syncStatus;
}

enum GoalSyncStatus {
  pending,
  synced,
  conflict,
}
