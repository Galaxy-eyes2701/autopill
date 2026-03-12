import 'package:autopill/data/dtos/medicines/medicine_request_dto.dart';
import 'package:autopill/data/interfaces/mapper/imapper.dart';
import 'package:autopill/domain/entities/medicine.dart';

class MedicineRequestMapper implements Imapper<MedicineRequestDto,Medicine> {


    @override
    Medicine map(MedicineRequestDto input) {
      return Medicine(
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
      );
    }
  }

