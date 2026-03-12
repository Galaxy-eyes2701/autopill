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

  Medicine({
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
    this.status = "active",
    this.instructions,
    this.createdAt,
    this.updatedAt,
  });

}