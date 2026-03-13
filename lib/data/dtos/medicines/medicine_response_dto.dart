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
      stockCurrent: json["stock_current"] ?? 0,
      stockThreshold: json["stock_threshold"] ?? 5,
      status: json["status"] ?? 'active',
      instructions: json["instructions"],
      createdAt: json["created_at"],
      updatedAt: json["updated_at"],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "id": id,
      "user_id": userId,
      "name": name,
      "category": category,
      "active_ingredient": activeIngredient,
      "registration_number": registrationNumber,
      "dosage_amount": dosageAmount,
      "dosage_unit": dosageUnit,
      "form_type": formType,
      "stock_current": stockCurrent,
      "stock_threshold": stockThreshold,
      "status": status,
      "instructions": instructions,
      "created_at": createdAt,
      "updated_at": updatedAt,
    };
  }
}
