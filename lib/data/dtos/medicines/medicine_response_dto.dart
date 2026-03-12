class MedicineResponseDto {
  final int id;
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

  MedicineResponseDto({
    required this.id,
    required this.userId,
    required this.name,
    this.category,
    this.activeIngredient,
    this.registrationNumber,
    this.dosageAmount,
    this.dosageUnit,
    this.formType,
    required this.stockCurrent,
    required this.stockThreshold,
    required this.status,
    this.instructions,
    this.createdAt,
    this.updatedAt,
  });

  factory MedicineResponseDto.fromJson(Map<String, dynamic> json) {
    return MedicineResponseDto(
      id: json["id"],
      userId: json["user_id"],
      name: json["name"],
      category: json["category"],
      activeIngredient: json["active_ingredient"],
      registrationNumber: json["registration_number"],
      dosageAmount: json["dosage_amount"]?.toDouble(),
      dosageUnit: json["dosage_unit"],
      formType: json["form_type"],
      stockCurrent: json["stock_current"],
      stockThreshold: json["stock_threshold"],
      status: json["status"],
      instructions: json["instructions"],
      createdAt: json["created_at"],
      updatedAt: json["updated_at"],
    );
  }
}