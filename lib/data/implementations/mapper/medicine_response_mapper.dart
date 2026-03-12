import 'package:autopill/data/dtos/medicines/medicine_response_dto.dart';
import 'package:autopill/data/interfaces/mapper/imapper.dart';
import 'package:autopill/domain/entities/medicine.dart';

class MedicineResponseMapper implements Imapper<Medicine,MedicineResponseDto>{
  @override
  MedicineResponseDto map(Medicine input) {
    return MedicineResponseDto(
      id: input.id!,
      userId: input.userId,
      name: input.name,
      category: input.category,
      activeIngredient: input.activeIngredient,
      registrationNumber: input.registrationNumber,
      dosageAmount: input.dosageAmount,
      dosageUnit: input.dosageUnit,
      formType: input.formType,
      stockCurrent: input.stockCurrent,
      stockThreshold: input.stockThreshold,
      status: input.status,
      instructions: input.instructions,
      createdAt: input.createdAt,
      updatedAt: input.updatedAt,
    );
  }

}