class MedicineRequestDto {
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

  MedicineRequestDto({
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
  });

  Map<String, dynamic> toJson() {
    return {
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
    };
  }
}