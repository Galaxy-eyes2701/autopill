class Medicine {
  final int? id;
  final int userId;
  final String name;
  final String? category;
  final String? activeIngredient;
  final String? registrationNumber;
  final double? dosageAmount;
  final String? dosageUnit;
  final String? formType;
  final int stockCurrent;
  final int stockThreshold;
  final String status;
  final String? instructions;
  final String? createdAt;
  final String? updatedAt;

  const Medicine({
    this.id,
    required this.userId,
    required this.name,
    this.category,
    this.activeIngredient,
    this.registrationNumber,
    this.dosageAmount,
    this.dosageUnit,
    this.formType,
    this.stockCurrent = 0,
    this.stockThreshold = 5,
    this.status = 'active',
    this.instructions,
    this.createdAt,
    this.updatedAt,
  });

  bool get isLowStock => stockCurrent <= stockThreshold;

  Medicine copyWith({
    int? id,
    int? userId,
    String? name,
    String? category,
    String? activeIngredient,
    String? registrationNumber,
    double? dosageAmount,
    String? dosageUnit,
    String? formType,
    int? stockCurrent,
    int? stockThreshold,
    String? status,
    String? instructions,
    String? createdAt,
    String? updatedAt,
  }) {
    return Medicine(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      category: category ?? this.category,
      activeIngredient: activeIngredient ?? this.activeIngredient,
      registrationNumber: registrationNumber ?? this.registrationNumber,
      dosageAmount: dosageAmount ?? this.dosageAmount,
      dosageUnit: dosageUnit ?? this.dosageUnit,
      formType: formType ?? this.formType,
      stockCurrent: stockCurrent ?? this.stockCurrent,
      stockThreshold: stockThreshold ?? this.stockThreshold,
      status: status ?? this.status,
      instructions: instructions ?? this.instructions,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}