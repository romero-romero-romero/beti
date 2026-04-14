import 'package:betty_app/core/enums/category_type.dart';
import 'package:betty_app/core/enums/input_method.dart';
import 'package:betty_app/core/enums/transaction_type.dart';
import 'package:betty_app/core/enums/payment_method.dart';

/// Entidad de transacción del dominio.
/// Independiente de Isar — los Repositories mapean hacia/desde aquí.
class TransactionEntity {
  final String uuid;
  final String userId;
  final TransactionType type;
  final double amount;
  final String description;
  final CategoryType category;
  final bool categoryAutoAssigned;
  final InputMethod inputMethod;
  final DateTime transactionDate;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? ticketImagePath;
  final String? rawInputText;
  final String? creditCardUuid;
  final String? notes;
  final PaymentMethod? paymentMethod;
  final bool isDeleted;

  const TransactionEntity({
    required this.uuid,
    required this.userId,
    required this.type,
    required this.amount,
    required this.description,
    required this.category,
    this.categoryAutoAssigned = false,
    this.inputMethod = InputMethod.manual,
    required this.transactionDate,
    required this.createdAt,
    required this.updatedAt,
    this.ticketImagePath,
    this.rawInputText,
    this.creditCardUuid,
    this.notes,
    this.paymentMethod,
    this.isDeleted = false,
  });

  /// Crea una copia con campos modificados.
  TransactionEntity copyWith({
    String? uuid,
    String? userId,
    TransactionType? type,
    double? amount,
    String? description,
    CategoryType? category,
    bool? categoryAutoAssigned,
    InputMethod? inputMethod,
    DateTime? transactionDate,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? ticketImagePath,
    String? rawInputText,
    String? creditCardUuid,
    String? notes,
    PaymentMethod? paymentMethod,
    bool? isDeleted,
  }) {
    return TransactionEntity(
      uuid: uuid ?? this.uuid,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      description: description ?? this.description,
      category: category ?? this.category,
      categoryAutoAssigned: categoryAutoAssigned ?? this.categoryAutoAssigned,
      inputMethod: inputMethod ?? this.inputMethod,
      transactionDate: transactionDate ?? this.transactionDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      ticketImagePath: ticketImagePath ?? this.ticketImagePath,
      rawInputText: rawInputText ?? this.rawInputText,
      creditCardUuid: creditCardUuid ?? this.creditCardUuid,
      notes: notes ?? this.notes,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }
}
